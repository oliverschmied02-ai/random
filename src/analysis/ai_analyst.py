"""
AI analysis of a listing using the Claude API.

For each listing that has a Gutachten PDF, we:
1. Extract the full text (via pdf_extractor)
2. Call Claude with a structured prompt
3. Parse the response into:
   - ai_summary (3 sentences)
   - ai_risk_flags (list of strings)
   - ai_attractiveness_score (1–10)
   - ai_recommended_max_bid (EUR)
"""
from __future__ import annotations

import json
import logging
import re
from pathlib import Path

import anthropic

from src.config import AppConfig
from src.models.listing import Listing

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """
Du bist ein erfahrener Immobiliengutachter und Investmentanalyst, spezialisiert
auf Zwangsversteigerungen in Deutschland. Analysiere das folgende Gutachten
und die Metadaten einer Zwangsversteigerung.

Antworte ausschließlich im folgenden JSON-Format (kein Markdown, kein Prosatext):
{
  "zusammenfassung": "<3 prägnante Sätze über das Objekt und seinen Zustand>",
  "risiken": ["<Risiko 1>", "<Risiko 2>", ...],
  "attraktivitaet": <Ganzzahl 1-10>,
  "empfohlenes_maxgebot": <Zahl in EUR oder null>,
  "begruendung": "<1-2 Sätze warum dieser Score>"
}

Bewertungsskala:
  9–10: Hervorragendes Objekt, kaum Risiken, deutlich unter Marktwert
  7–8:  Gutes Objekt, überschaubare Risiken
  5–6:  Durchschnittlich, einige Risiken
  3–4:  Erhöhte Risiken, nur für erfahrene Investoren
  1–2:  Hohes Risiko, starke Mängel oder rechtliche Probleme
"""

_USER_TEMPLATE = """
## Metadaten
- Aktenzeichen: {aktenzeichen}
- Amtsgericht: {amtsgericht}
- Termin: {termin}
- Objekt: {objekt}
- PLZ / Ort: {plz} {ort}
- Verkehrswert: {verkehrswert} €
- Mindestgebot (50%): {mindestgebot} €
- Sicherheitsgrenze (70%): {sicherheitsgrenze} €
- Wohnfläche: {wohnflaeche} m²
- Grundstück: {grundstueck} m²
- Baujahr: {baujahr}
- Zimmer: {zimmer}

## Gutachten (Auszug, max. 15.000 Zeichen)
{gutachten_text}
"""


async def analyse_listing(listing: Listing, config: AppConfig) -> None:
    """Run Claude analysis on a listing (in-place mutation)."""
    if not config.anthropic_api_key:
        logger.info("No ANTHROPIC_API_KEY — skipping AI analysis")
        return

    gutachten_text = _get_gutachten_text(listing)

    user_msg = _USER_TEMPLATE.format(
        aktenzeichen=listing.aktenzeichen,
        amtsgericht=listing.amtsgericht,
        termin=listing.termin.strftime("%d.%m.%Y %H:%M") if listing.termin else "unbekannt",
        objekt=listing.objekt_beschreibung[:500],
        plz=listing.plz,
        ort=listing.ort,
        verkehrswert=f"{listing.verkehrswert:,.0f}" if listing.verkehrswert else "unbekannt",
        mindestgebot=f"{listing.mindestgebot_50pct:,.0f}" if listing.mindestgebot_50pct else "–",
        sicherheitsgrenze=f"{listing.sicherheitsgrenze_70pct:,.0f}" if listing.sicherheitsgrenze_70pct else "–",
        wohnflaeche=listing.wohnflaeche_sqm or "unbekannt",
        grundstueck=listing.grundstueck_sqm or "unbekannt",
        baujahr=listing.baujahr or "unbekannt",
        zimmer=listing.zimmer or "unbekannt",
        gutachten_text=gutachten_text[:15_000] if gutachten_text else "(kein Gutachten verfügbar)",
    )

    try:
        client = anthropic.AsyncAnthropic(api_key=config.anthropic_api_key)
        response = await client.messages.create(
            model=config.analysis.ai_model,
            max_tokens=1024,
            system=_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )
        raw_json = response.content[0].text.strip()
        _apply_response(listing, raw_json)
        logger.info(
            "AI analysis done for %s — score: %s",
            listing.aktenzeichen,
            listing.ai_attractiveness_score,
        )
    except Exception as exc:
        logger.error("AI analysis failed for %s: %s", listing.aktenzeichen, exc)


def _apply_response(listing: Listing, raw_json: str) -> None:
    # Strip potential markdown code fences
    raw_json = re.sub(r"^```(?:json)?\s*", "", raw_json)
    raw_json = re.sub(r"\s*```$", "", raw_json)
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as exc:
        logger.warning("Could not parse AI response JSON: %s\n%s", exc, raw_json[:200])
        return

    listing.ai_summary = data.get("zusammenfassung", "")
    listing.ai_risk_flags = data.get("risiken", [])
    score = data.get("attraktivitaet")
    if isinstance(score, (int, float)):
        listing.ai_attractiveness_score = max(1, min(10, int(score)))
    listing.ai_recommended_max_bid = data.get("empfohlenes_maxgebot")


def _get_gutachten_text(listing: Listing) -> str:
    if listing.gutachten_local_path:
        try:
            from src.analysis.pdf_extractor import extract_pdf_data
            data = extract_pdf_data(listing.gutachten_local_path)
            return data.get("full_text", "")
        except Exception as exc:
            logger.warning("Could not extract PDF text: %s", exc)
    return ""
