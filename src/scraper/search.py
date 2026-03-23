"""
Submit search form on zvg-portal.de and paginate through results.

Technical notes (from portal reverse-engineering):
- Endpoint: POST https://www.zvg-portal.de/index.php?button=Suchen&all=1
- State is passed as `land_abk` (2-letter abbreviation, e.g. "by")
- HTML encoding is latin1 / iso-8859-1 — NOT utf-8
- Detail page URL: index.php?button=showZvg&zvg_id=<id>&land_abk=<state>
- PDF/attachment URL: ?button=showAnhang&land_abk=<state>&file_id=<id>&zvg_id=<id>
- Standard requests session works; Playwright only needed if cookies become an issue
"""
from __future__ import annotations

import logging
import time
from typing import Any

import requests
from bs4 import BeautifulSoup
from tenacity import retry, stop_after_attempt, wait_exponential

from src.config import AreaOfInterest, ScraperConfig

logger = logging.getLogger(__name__)

ZVG_BASE = "https://www.zvg-portal.de"
ZVG_SEARCH_URL = f"{ZVG_BASE}/index.php"

# Canonical Bundesland name → portal land_abk code
BUNDESLAND_CODES: dict[str, str] = {
    "Baden-Württemberg": "bw",
    "Bayern": "by",
    "Berlin": "be",
    "Brandenburg": "br",
    "Bremen": "hb",
    "Hamburg": "hh",
    "Hessen": "he",
    "Mecklenburg-Vorpommern": "mv",
    "Niedersachsen": "ni",
    "Nordrhein-Westfalen": "nw",
    "Rheinland-Pfalz": "rp",
    "Saarland": "sl",
    "Sachsen": "sn",
    "Sachsen-Anhalt": "st",
    "Schleswig-Holstein": "sh",
    "Thüringen": "th",
}

# Courts that do NOT publish on zvg-portal.de
_NO_COVERAGE = {"Hamburg", "Mecklenburg-Vorpommern"}

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Referer": f"{ZVG_BASE}/index.php?button=Suchen",
    "Accept-Language": "de-DE,de;q=0.9",
}


def fetch_all_listings(
    area: AreaOfInterest,
    config: ScraperConfig,
) -> list[dict[str, Any]]:
    """
    Collect all raw listing dicts for the configured area.
    Uses a persistent requests.Session to reuse cookies.
    """
    bundesland = area.bundesland
    if bundesland in _NO_COVERAGE:
        logger.warning(
            "%s is not covered by zvg-portal.de — skipping", bundesland
        )
        return []

    land_abk = BUNDESLAND_CODES.get(bundesland)
    if not land_abk:
        raise ValueError(
            f"Unknown Bundesland '{bundesland}'. "
            f"Valid options: {list(BUNDESLAND_CODES.keys())}"
        )

    session = requests.Session()
    session.headers.update(_HEADERS)

    # Warm up session (loads PHP session cookie)
    session.get(
        f"{ZVG_BASE}/index.php?button=Suchen",
        timeout=20,
    )

    courts = area.amtsgerichte or ["-- Alle Amtsgerichte --"]
    plz_values = area.plz_range or [""]

    all_raw: list[dict[str, Any]] = []
    seen: set[str] = set()

    for gericht_name in courts:
        # Resolve court name → ger_id (0 = all courts)
        ger_id = 0

        for plz in plz_values:
            raw = _search_one(
                session=session,
                land_abk=land_abk,
                ger_id=ger_id,
                ger_name=gericht_name,
                plz=plz,
                config=config,
            )
            for item in raw:
                key = f"{item.get('amtsgericht')}::{item.get('aktenzeichen')}"
                if key not in seen:
                    seen.add(key)
                    all_raw.append(item)
            time.sleep(config.rate_limit_seconds)

    logger.info("Total listings collected: %d", len(all_raw))
    return all_raw


def _search_one(
    session: requests.Session,
    land_abk: str,
    ger_id: int,
    ger_name: str,
    plz: str,
    config: ScraperConfig,
) -> list[dict[str, Any]]:
    logger.info(
        "Searching: land_abk=%s  gericht=%s  plz=%s", land_abk, ger_name, plz
    )

    # POST payload — exact parameter names from portal form
    payload = {
        "ger_name": ger_name,
        "order_by": "2",
        "land_abk": land_abk,
        "ger_id": str(ger_id),
        "az1": "",
        "az2": "",
        "az3": "",
        "az4": "",
        "art": "",
        "obj": "",
        "str": "",
        "hnr": "",
        "plz": plz,
        "ort": "",
        "ortsteil": "",
        "vtermin": "",
        "btermin": "",
    }

    all_rows: list[dict[str, Any]] = []
    page_num = 1

    while True:
        try:
            resp = session.post(
                f"{ZVG_BASE}/index.php",
                params={"button": "Suchen", "all": "1"},
                data=payload,
                timeout=30,
            )
            resp.raise_for_status()
        except requests.RequestException as exc:
            logger.error("Search request failed: %s", exc)
            break

        # Portal returns latin1 encoded HTML
        resp.encoding = "latin1"
        html = resp.text

        rows = _parse_result_table(html, land_abk)
        all_rows.extend(rows)
        logger.debug("  Page %d: %d rows", page_num, len(rows))

        # Check for pagination ("weiter" link / next page button)
        soup = BeautifulSoup(html, "lxml")
        next_link = soup.find("a", string=lambda t: t and "weiter" in t.lower())
        if not next_link or not next_link.get("href"):
            break

        # Follow pagination link
        next_url = next_link["href"]
        if not next_url.startswith("http"):
            next_url = f"{ZVG_BASE}/{next_url.lstrip('/')}"
        try:
            resp = session.get(next_url, timeout=30)
            resp.encoding = "latin1"
            html = resp.text
        except requests.RequestException as exc:
            logger.error("Pagination request failed: %s", exc)
            break

        # For subsequent pages, parse directly (payload not needed)
        rows = _parse_result_table(html, land_abk)
        all_rows.extend(rows)
        page_num += 1
        time.sleep(config.rate_limit_seconds)

        # Check for another next-page link
        soup = BeautifulSoup(html, "lxml")
        if not soup.find("a", string=lambda t: t and "weiter" in t.lower()):
            break

    return all_rows


def _parse_result_table(html: str, land_abk: str) -> list[dict[str, Any]]:
    """
    Parse the search results table.

    The portal renders results in a <table> inside #inhalt.
    Each <tr> contains: Aktenzeichen | Amtsgericht | Objekt/Lage | Termin | Verkehrswert
    """
    import re

    soup = BeautifulSoup(html, "lxml")
    rows: list[dict[str, Any]] = []

    # Find the results table inside #inhalt
    inhalt = soup.find(id="inhalt") or soup
    trs = inhalt.find_all("tr")

    for tr in trs:
        cells = tr.find_all("td")
        if len(cells) < 3:
            continue

        cell_texts = [c.get_text(separator=" ", strip=True) for c in cells]

        # Identify Aktenzeichen cell (contains "K" pattern)
        az_cell = None
        az_text = ""
        for i, c in enumerate(cells):
            bold = c.find("b")
            text = bold.get_text(strip=True) if bold else c.get_text(strip=True)
            if re.search(r"K\s*\d+\s*/\s*\d+", text):
                az_cell = c
                az_text = text
                break

        if not az_cell or not az_text:
            continue

        raw: dict[str, Any] = {"land_abk": land_abk, "bundesland": _land_abk_to_name(land_abk)}

        # Aktenzeichen
        raw["aktenzeichen"] = az_text.strip()

        # zvg_id from the link  index.php?button=showZvg&zvg_id=XXX&land_abk=YY
        link = az_cell.find("a", href=True)
        if link:
            m = re.search(r"zvg_id=(\d+)", link["href"])
            raw["zvg_id"] = int(m.group(1)) if m else None
            raw["detail_url"] = (
                f"{ZVG_BASE}/{link['href'].lstrip('/')}"
                if not link["href"].startswith("http")
                else link["href"]
            )

        # Map remaining cells by position (portal is consistent):
        # [0]=Aktenzeichen, [1]=Amtsgericht, [2]=Objekt/Lage, [3]=Termin, [4]=Verkehrswert
        idx = list(cells).index(az_cell)
        raw["amtsgericht"] = _cell_text(cells, idx + 1)
        raw["objekt_beschreibung"] = _cell_text(cells, idx + 2)
        raw["termin_raw"] = _cell_text(cells, idx + 3)
        raw["verkehrswert_raw"] = _cell_text(cells, idx + 4)

        # Extract PLZ + Ort from Objekt/Lage field
        addr = _parse_address(raw["objekt_beschreibung"])
        raw.update(addr)

        # Cancellation flag
        termin_text = raw["termin_raw"].lower()
        if "aufgehoben" in termin_text or "abgesagt" in termin_text:
            raw["status"] = "cancelled"
            raw["cancellation_reason"] = raw["termin_raw"]
        else:
            raw["status"] = "active"

        rows.append(raw)

    return rows


def _parse_address(objekt_text: str) -> dict[str, str]:
    """Extract street, PLZ, Ort from the Objekt/Lage cell."""
    import re

    result = {"plz": "", "ort": "", "strasse": ""}
    if not objekt_text:
        return result

    # Pattern: "Musterstraße 5, 80331 München" or "80331 München"
    # Ort ends at comma, newline, or keywords like "Beschreibung:"
    m = re.search(r"(\d{5})\s+([A-ZÄÖÜa-zäöü][^\n,]{1,40}?)(?:\s*(?:Beschreibung:|letzte\s|$))", objekt_text)
    if m:
        result["plz"] = m.group(1)
        result["ort"] = m.group(2).strip()

    # Street before the PLZ
    street_part = objekt_text[:m.start()].strip().rstrip(",") if m else ""
    # Remove object type description (usually first line)
    lines = street_part.split("\n")
    if len(lines) >= 2:
        result["strasse"] = lines[-1].strip().rstrip(",")

    return result


def _cell_text(cells, idx: int) -> str:
    if 0 <= idx < len(cells):
        return cells[idx].get_text(separator=" ", strip=True)
    return ""


def _land_abk_to_name(abk: str) -> str:
    return {v: k for k, v in BUNDESLAND_CODES.items()}.get(abk, abk)
