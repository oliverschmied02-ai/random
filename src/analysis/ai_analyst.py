"""
AI analysis of a listing — unterstützt Claude, Ollama (lokal) und OpenRouter.

Für jedes Listing mit Gutachten-PDF:
1. PDF-Text extrahieren
2. KI-Analyse (strukturierter Prompt)
3. Ergebnis in Listing-Felder schreiben:
   - ai_summary, ai_risk_flags, ai_attractiveness_score, ai_recommended_max_bid
"""
from __future__ import annotations

import json
import logging
import re
from pathlib import Path

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
    """Run AI analysis on a listing (in-place mutation).

    Provider wird via config.analysis.ai_provider bestimmt:
      - "claude"      → Anthropic Claude API (kostenpflichtig, hochwertig)
      - "ollama"      → Lokales Modell via Ollama (kostenlos)
      - "openrouter"  → OpenRouter API (günstigere Cloud-Modelle)
    """
    provider = config.analysis.ai_provider.lower()

    if provider == "claude":
        await _analyse_claude(listing, config)
    elif provider == "ollama":
        await _analyse_ollama(listing, config)
    elif provider == "openrouter":
        await _analyse_openrouter(listing, config)
    else:
        logger.warning("Unbekannter ai_provider '%s' — überspringe Analyse", provider)


# ──────────────────────────────────────────────────────────────────────────────
# Provider: Claude (Anthropic API)
# ──────────────────────────────────────────────────────────────────────────────

async def _analyse_claude(listing: Listing, config: AppConfig) -> None:
    if not config.anthropic_api_key:
        logger.info("Kein ANTHROPIC_API_KEY — überspringe KI-Analyse")
        return

    import anthropic

    user_msg = _build_user_message(listing)
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
            "Claude-Analyse: %s — Score: %s",
            listing.aktenzeichen,
            listing.ai_attractiveness_score,
        )
    except Exception as exc:
        logger.error("Claude-Analyse fehlgeschlagen (%s): %s", listing.aktenzeichen, exc)


# ──────────────────────────────────────────────────────────────────────────────
# Provider: Ollama (lokales Modell)
# ──────────────────────────────────────────────────────────────────────────────

async def _analyse_ollama(listing: Listing, config: AppConfig) -> None:
    import httpx

    endpoint = config.analysis.ollama_endpoint.rstrip("/")
    model = config.analysis.ollama_model
    user_msg = _build_user_message(listing)

    # Ollama erwartet: system + user als kombinierter Prompt
    full_prompt = f"{_SYSTEM_PROMPT.strip()}\n\n{user_msg}"

    payload = {
        "model": model,
        "prompt": full_prompt,
        "stream": False,
        "options": {"temperature": 0.2, "num_predict": 1024},
    }

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(f"{endpoint}/api/generate", json=payload)
            resp.raise_for_status()
            raw_json = resp.json().get("response", "").strip()
        _apply_response(listing, raw_json)
        logger.info(
            "Ollama-Analyse (%s): %s — Score: %s",
            model,
            listing.aktenzeichen,
            listing.ai_attractiveness_score,
        )
    except Exception as exc:
        logger.error(
            "Ollama-Analyse fehlgeschlagen (%s): %s — Läuft Ollama? `ollama serve`",
            listing.aktenzeichen,
            exc,
        )


# ──────────────────────────────────────────────────────────────────────────────
# Provider: OpenRouter (günstige Cloud-Modelle)
# ──────────────────────────────────────────────────────────────────────────────

async def _analyse_openrouter(listing: Listing, config: AppConfig) -> None:
    if not config.openrouter_api_key:
        logger.info("Kein OPENROUTER_API_KEY — überspringe KI-Analyse")
        return

    import httpx

    user_msg = _build_user_message(listing)
    model = config.analysis.ai_model  # z.B. "mistralai/mistral-7b-instruct"

    headers = {
        "Authorization": f"Bearer {config.openrouter_api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/zvg-intelligence",
    }
    payload = {
        "model": model,
        "max_tokens": 1024,
        "messages": [
            {"role": "system", "content": _SYSTEM_PROMPT.strip()},
            {"role": "user", "content": user_msg},
        ],
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload,
            )
            resp.raise_for_status()
            raw_json = resp.json()["choices"][0]["message"]["content"].strip()
        _apply_response(listing, raw_json)
        logger.info(
            "OpenRouter-Analyse (%s): %s — Score: %s",
            model,
            listing.aktenzeichen,
            listing.ai_attractiveness_score,
        )
    except Exception as exc:
        logger.error(
            "OpenRouter-Analyse fehlgeschlagen (%s): %s", listing.aktenzeichen, exc
        )


# ──────────────────────────────────────────────────────────────────────────────
# Hilfsfunktionen
# ──────────────────────────────────────────────────────────────────────────────

def _build_user_message(listing: Listing) -> str:
    gutachten_text = _get_gutachten_text(listing)
    return _USER_TEMPLATE.format(
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


def _apply_response(listing: Listing, raw_json: str) -> None:
    raw_json = re.sub(r"^```(?:json)?\s*", "", raw_json)
    raw_json = re.sub(r"\s*```$", "", raw_json)
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as exc:
        logger.warning("KI-Antwort konnte nicht geparst werden: %s\n%s", exc, raw_json[:200])
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
            logger.warning("PDF-Text konnte nicht extrahiert werden: %s", exc)
    return ""
