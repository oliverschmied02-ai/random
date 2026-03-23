"""
HTTP session management for zvg-portal.de.

The ZVG portal works with a standard requests.Session (PHP session cookies).
Playwright is kept as an optional fallback for cases where JavaScript rendering
becomes necessary.

Encoding note: all portal responses are latin1 / iso-8859-1, not UTF-8.
"""
from __future__ import annotations

import logging

import requests

from src.config import ScraperConfig

logger = logging.getLogger(__name__)

ZVG_BASE_URL = "https://www.zvg-portal.de"
ZVG_SEARCH_URL = f"{ZVG_BASE_URL}/index.php?button=Termine+suchen"

_DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "de-DE,de;q=0.9",
    "Referer": f"{ZVG_BASE_URL}/index.php?button=Suchen",
}


def make_session(config: ScraperConfig) -> requests.Session:
    """
    Create a requests.Session pre-configured for the ZVG portal.
    Warms up the session to obtain the PHP session cookie.
    """
    session = requests.Session()
    session.headers.update(_DEFAULT_HEADERS)

    # Warm-up request to establish PHP session cookie
    try:
        resp = session.get(
            f"{ZVG_BASE_URL}/index.php?button=Suchen",
            timeout=20,
        )
        resp.raise_for_status()
        logger.debug("ZVG session established (cookies: %s)", dict(session.cookies))
    except requests.RequestException as exc:
        logger.warning("Session warm-up failed: %s", exc)

    return session


def fetch_detail_page(
    session: requests.Session,
    zvg_id: int,
    land_abk: str,
) -> str:
    """
    Fetch the detail page for a single listing.
    Returns decoded HTML string (latin1).
    """
    url = (
        f"{ZVG_BASE_URL}/index.php"
        f"?button=showZvg&zvg_id={zvg_id}&land_abk={land_abk}"
    )
    resp = session.get(url, timeout=30)
    resp.encoding = "latin1"
    return resp.text


def attachment_url(land_abk: str, file_id: int, zvg_id: int) -> str:
    """Build the URL for downloading a PDF or photo attachment."""
    return (
        f"{ZVG_BASE_URL}/?button=showAnhang"
        f"&land_abk={land_abk}&file_id={file_id}&zvg_id={zvg_id}"
    )
