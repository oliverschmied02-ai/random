"""
Convert raw search-result dicts + detail-page HTML into Listing objects.

Portal detail page fields (labels in the HTML table):
  Grundbuch | Art der Versteigerung | Ort der Versteigerung |
  Beschreibung | Informationen zum Gläubiger |
  Gutachten (PDF links) | Exposee (PDF links) | Foto (image links)

Attachment URL pattern:
  ?button=showAnhang&land_abk=<state>&file_id=<id>&zvg_id=<id>
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import Any

from bs4 import BeautifulSoup

from src.models.listing import Listing
from src.scraper.session import ZVG_BASE_URL

logger = logging.getLogger(__name__)

# German date patterns
_TERMIN_PATTERNS = [
    # "Montag, 15. November 2024, 10:00 Uhr"
    r"\w+,\s*(\d{1,2})\.\s*(\w+)\s+(\d{4}),?\s*(\d{2}):(\d{2})",
    # "15.11.2024 10:00"
    r"(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})",
    # "15.11.2024"
    r"(\d{2})\.(\d{2})\.(\d{4})",
]

_GERMAN_MONTHS = {
    "januar": 1, "februar": 2, "märz": 3, "april": 4,
    "mai": 5, "juni": 6, "juli": 7, "august": 8,
    "september": 9, "oktober": 10, "november": 11, "dezember": 12,
}

# Links to ignore on the detail page
_SKIP_LINK_PATTERNS = [
    "index.php?button=",
    "?button=",
    "justiz.de",
    "handelsregister.de",
    "javascript:",
]


def parse_listing(raw: dict[str, Any], detail_html: str | None = None) -> Listing:
    """Build a Listing from a search-result dict and optional detail-page HTML."""
    listing = Listing(
        aktenzeichen=raw.get("aktenzeichen", "").strip(),
        amtsgericht=raw.get("amtsgericht", "").strip(),
        bundesland=raw.get("bundesland", "").strip(),
        termin=_parse_termin(raw.get("termin_raw", "")),
        objekt_beschreibung=raw.get("objekt_beschreibung", "").strip(),
        plz=raw.get("plz", "").strip(),
        ort=raw.get("ort", "").strip(),
        verkehrswert=_parse_money(raw.get("verkehrswert_raw", "")),
        art_der_versteigerung=raw.get("art_der_versteigerung", "").strip(),
        status=raw.get("status", "active"),
        cancellation_reason=raw.get("cancellation_reason"),
        gutachten_url=raw.get("gutachten_url"),
        expose_url=raw.get("expose_url"),
        foto_urls=raw.get("foto_urls") or [],
    )

    if detail_html:
        _enrich_from_detail(listing, detail_html, raw.get("land_abk", ""))

    listing.compute_bietgrenzen()
    return listing


def _enrich_from_detail(listing: Listing, html: str, land_abk: str) -> None:
    """
    Parse the detail page HTML.

    The detail page uses a definition-list style table where the left column
    is the field label and the right column is the value.
    """
    soup = BeautifulSoup(html, "lxml")

    # Extract key-value pairs from the detail table
    kv: dict[str, str] = {}
    for row in soup.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) >= 2:
            key = cells[0].get_text(strip=True).lower()
            val = cells[1].get_text(separator=" ", strip=True)
            kv[key] = val

    # Art der Versteigerung
    art = kv.get("art der versteigerung", "")
    if art and not listing.art_der_versteigerung:
        listing.art_der_versteigerung = art

    # Beschreibung enriches objekt_beschreibung
    beschreibung = kv.get("beschreibung", "")
    if beschreibung and len(beschreibung) > len(listing.objekt_beschreibung):
        listing.objekt_beschreibung = beschreibung

    # Cancellation check
    full_text = soup.get_text()
    if re.search(r"aufgehoben|termin aufgehoben|abgesagt", full_text, re.IGNORECASE):
        listing.status = "cancelled"
        m = re.search(r"(?:aufgehoben|abgesagt)[:\s]+(.{5,200})", full_text, re.IGNORECASE)
        if m:
            listing.cancellation_reason = m.group(1).strip()

    # Collect document/attachment links
    for a in soup.find_all("a", href=True):
        href: str = a["href"]

        # Skip internal navigation links
        if any(p in href for p in _SKIP_LINK_PATTERNS):
            continue
        if href in ("#", ""):
            continue

        abs_href = href if href.startswith("http") else f"{ZVG_BASE_URL}/{href.lstrip('/')}"
        text = a.get_text(strip=True).lower()

        # Attachment links: ?button=showAnhang&...
        if "showanhang" in href.lower():
            if "gutachten" in text:
                listing.gutachten_url = abs_href
            elif "exposé" in text or "expose" in text:
                listing.expose_url = abs_href
            elif any(ext in href.lower() for ext in [".jpg", ".jpeg", ".png", ".gif"]):
                listing.foto_urls.append(abs_href)
            elif "foto" in text or "bild" in text:
                listing.foto_urls.append(abs_href)
            else:
                # Default unknown attachments to Gutachten if none set yet
                if not listing.gutachten_url:
                    listing.gutachten_url = abs_href

        # Direct PDF links
        elif href.lower().endswith(".pdf"):
            if not listing.gutachten_url:
                listing.gutachten_url = abs_href

        # Direct image links
        elif any(href.lower().endswith(ext) for ext in [".jpg", ".jpeg", ".png", ".gif"]):
            listing.foto_urls.append(abs_href)

    # PLZ / Ort — try to extract if not already set
    if not listing.plz:
        m = re.search(r"\b(\d{5})\s+([A-ZÄÖÜ][^\n,]{2,30})", full_text)
        if m:
            listing.plz = m.group(1)
            listing.ort = m.group(2).strip()

    # Verkehrswert — sometimes only on the detail page
    if listing.verkehrswert is None:
        m = re.search(
            r"Verkehrswert\s*[:\-]?\s*([\d.,]+)\s*[€EUReur]*",
            full_text,
            re.IGNORECASE,
        )
        if m:
            listing.verkehrswert = _parse_money(m.group(1))
            listing.compute_bietgrenzen()


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def _parse_termin(raw: str) -> datetime | None:
    if not raw:
        return None

    # Pattern 1: "Montag, 15. November 2024, 10:00 Uhr"
    m = re.search(
        r"\d{1,2}\.\s*(\w+)\s+(\d{4}),?\s*(\d{2}):(\d{2})",
        raw,
        re.IGNORECASE,
    )
    if m:
        month_str = m.group(1).lower()
        month = _GERMAN_MONTHS.get(month_str)
        if month:
            day_m = re.search(r"(\d{1,2})\.", raw)
            day = int(day_m.group(1)) if day_m else 1
            try:
                return datetime(
                    int(m.group(2)), month, day,
                    int(m.group(3)), int(m.group(4))
                )
            except ValueError:
                pass

    # Pattern 2: "15.11.2024 10:00"
    m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})", raw)
    if m:
        try:
            return datetime(
                int(m.group(3)), int(m.group(2)), int(m.group(1)),
                int(m.group(4)), int(m.group(5))
            )
        except ValueError:
            pass

    # Pattern 3: "15.11.2024"
    m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})", raw)
    if m:
        try:
            return datetime(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        except ValueError:
            pass

    return None


def _parse_money(raw: str) -> float | None:
    """
    Parse German money format: "380.000,00 €" → 380000.0
    Portal stores Verkehrswert as European number (. thousands, , decimal).
    """
    if not raw:
        return None
    cleaned = re.sub(r"[€EUReur\s]", "", raw)
    if "," in cleaned:
        # European: 380.000,00
        cleaned = cleaned.replace(".", "").replace(",", ".")
    else:
        # Plain integer or US-style
        cleaned = cleaned.replace(".", "")
    try:
        val = float(cleaned)
        return val if val > 0 else None
    except ValueError:
        return None
