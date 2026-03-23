"""
Convert raw dicts (from search.py) and detail-page HTML into Listing objects.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import Any

from bs4 import BeautifulSoup

from src.models.listing import Listing

logger = logging.getLogger(__name__)

# Regex to clean Verkehrswert strings like "380.000,00 €" → 380000.0
_MONEY_RE = re.compile(r"[\d.,]+")


def parse_listing(raw: dict[str, Any], detail_html: str | None = None) -> Listing:
    """Build a Listing from a raw dict and optionally a detail-page HTML."""
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

    # Enrich from detail page if available
    if detail_html:
        _enrich_from_detail(listing, detail_html)

    listing.compute_bietgrenzen()
    return listing


def _enrich_from_detail(listing: Listing, html: str) -> None:
    """
    Parse the Aktenzeichen detail page to extract:
    - PLZ and Ort (often missing in list view)
    - Art der Versteigerung
    - Document download links (Gutachten, Exposé, Fotos)
    - Cancellation status
    """
    soup = BeautifulSoup(html, "lxml")
    full_text = soup.get_text(separator="\n")

    # PLZ + Ort
    if not listing.plz:
        plz_match = re.search(r"\b(\d{5})\s+([A-ZÄÖÜ][^\n,]+)", full_text)
        if plz_match:
            listing.plz = plz_match.group(1)
            listing.ort = plz_match.group(2).strip()

    # Art der Versteigerung
    if not listing.art_der_versteigerung:
        art_match = re.search(
            r"Art der Versteigerung\s*[:\-]?\s*(.+)", full_text, re.IGNORECASE
        )
        if art_match:
            listing.art_der_versteigerung = art_match.group(1).strip()

    # Cancellation
    if re.search(r"aufgehoben|termin aufgehoben|abgesagt", full_text, re.IGNORECASE):
        listing.status = "cancelled"
        reason_match = re.search(
            r"aufgehoben\s*[:\-]?\s*(.+)", full_text, re.IGNORECASE
        )
        if reason_match:
            listing.cancellation_reason = reason_match.group(1).strip()[:200]

    # Verkehrswert (sometimes only on detail page)
    if listing.verkehrswert is None:
        vw_match = re.search(
            r"Verkehrswert\s*[:\-]?\s*([\d.,]+\s*[€EUR]*)",
            full_text,
            re.IGNORECASE,
        )
        if vw_match:
            listing.verkehrswert = _parse_money(vw_match.group(1))
            listing.compute_bietgrenzen()

    # Document links
    for a in soup.find_all("a", href=True):
        href: str = a["href"]
        text = a.get_text(strip=True).lower()
        if "gutachten" in text or "gutachten" in href.lower():
            listing.gutachten_url = _abs_url(href)
        elif "exposé" in text or "expose" in text or "expose" in href.lower():
            listing.expose_url = _abs_url(href)
        elif href.lower().endswith((".jpg", ".jpeg", ".png", ".gif")):
            listing.foto_urls.append(_abs_url(href))
        elif "foto" in text or "foto" in href.lower():
            listing.foto_urls.append(_abs_url(href))


def _parse_termin(raw: str) -> datetime | None:
    """Parse German date/time strings like "15.11.2024 10:00 Uhr"."""
    if not raw:
        return None
    patterns = [
        r"(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})",
        r"(\d{2})\.(\d{2})\.(\d{4})",
    ]
    for pat in patterns:
        m = re.search(pat, raw)
        if m:
            groups = m.groups()
            try:
                if len(groups) == 5:
                    return datetime(
                        int(groups[2]), int(groups[1]), int(groups[0]),
                        int(groups[3]), int(groups[4])
                    )
                else:
                    return datetime(int(groups[2]), int(groups[1]), int(groups[0]))
            except ValueError:
                pass
    return None


def _parse_money(raw: str) -> float | None:
    """Parse German money strings: "380.000,00 €" → 380000.0"""
    if not raw:
        return None
    # Remove currency symbols and spaces
    cleaned = re.sub(r"[€EUR\s]", "", raw)
    # German format: dots as thousands sep, comma as decimal
    if "," in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    else:
        cleaned = cleaned.replace(".", "")
    try:
        return float(cleaned)
    except ValueError:
        return None


def _abs_url(href: str) -> str:
    """Make relative URLs absolute."""
    if href.startswith("http"):
        return href
    return f"https://www.zvg-portal.de/{href.lstrip('/')}"
