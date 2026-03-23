"""
Enrich a Listing with:
  - Data extracted from PDFs (Wohnfläche, Baujahr, etc.)
  - Geocoding (lat/lon via Nominatim)
  - Derived metrics (price/sqm, Bietgrenzen)
"""
from __future__ import annotations

import logging
import time
from typing import Optional

from src.models.listing import Listing

logger = logging.getLogger(__name__)


def enrich_listing(listing: Listing) -> None:
    """Run all enrichment steps on a listing (in-place)."""
    _enrich_from_pdf(listing)
    _geocode(listing)
    listing.compute_bietgrenzen()
    listing.compute_price_per_sqm()


# ---------------------------------------------------------------------------
# PDF enrichment
# ---------------------------------------------------------------------------

def _enrich_from_pdf(listing: Listing) -> None:
    if not listing.gutachten_local_path:
        return
    try:
        from src.analysis.pdf_extractor import extract_pdf_data
        data = extract_pdf_data(listing.gutachten_local_path)
        if data["wohnflaeche_sqm"] and not listing.wohnflaeche_sqm:
            listing.wohnflaeche_sqm = data["wohnflaeche_sqm"]
        if data["grundstueck_sqm"] and not listing.grundstueck_sqm:
            listing.grundstueck_sqm = data["grundstueck_sqm"]
        if data["baujahr"] and not listing.baujahr:
            listing.baujahr = data["baujahr"]
        if data["zimmer"] and not listing.zimmer:
            listing.zimmer = data["zimmer"]
    except Exception as exc:
        logger.warning("PDF enrichment failed for %s: %s", listing.aktenzeichen, exc)


# ---------------------------------------------------------------------------
# Geocoding
# ---------------------------------------------------------------------------

_GEOCODER = None
_LAST_GEOCODE_TIME = 0.0
_GEOCODE_RATE_LIMIT = 1.1  # Nominatim ToS: max 1 req/s


def _get_geocoder():
    global _GEOCODER
    if _GEOCODER is None:
        try:
            from geopy.geocoders import Nominatim
            _GEOCODER = Nominatim(user_agent="zvg-intelligence/1.0")
        except ImportError:
            logger.warning("geopy not installed — geocoding disabled")
    return _GEOCODER


def _geocode(listing: Listing) -> None:
    if listing.lat and listing.lon:
        return  # already geocoded

    geocoder = _get_geocoder()
    if geocoder is None:
        return

    address = _build_address(listing)
    if not address:
        return

    # Rate limit Nominatim
    global _LAST_GEOCODE_TIME
    elapsed = time.time() - _LAST_GEOCODE_TIME
    if elapsed < _GEOCODE_RATE_LIMIT:
        time.sleep(_GEOCODE_RATE_LIMIT - elapsed)

    try:
        location = geocoder.geocode(address, country_codes="de", timeout=10)
        _LAST_GEOCODE_TIME = time.time()
        if location:
            listing.lat = location.latitude
            listing.lon = location.longitude
            listing.full_address = location.address
            logger.debug("Geocoded %s → (%.4f, %.4f)", address, listing.lat, listing.lon)
    except Exception as exc:
        logger.warning("Geocoding failed for '%s': %s", address, exc)


def _build_address(listing: Listing) -> Optional[str]:
    parts = []
    if listing.plz:
        parts.append(listing.plz)
    if listing.ort:
        parts.append(listing.ort)
    if not parts:
        return None
    return ", ".join(parts) + ", Deutschland"
