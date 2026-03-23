"""
Submit search form on zvg-portal.de and paginate through results.

Returns a list of raw dicts with fields extracted from the result table.
Caller is responsible for converting these to Listing objects via listing_parser.
"""
from __future__ import annotations

import logging
from typing import Any

from bs4 import BeautifulSoup
from playwright.async_api import Page
from tenacity import retry, stop_after_attempt, wait_exponential

from src.config import AreaOfInterest, ScraperConfig
from src.scraper.session import ZVG_SEARCH_URL

logger = logging.getLogger(__name__)

# Mapping of canonical Bundesland names → portal form values
BUNDESLAND_MAP: dict[str, str] = {
    "Baden-Württemberg": "Baden-Württemberg",
    "Bayern": "Bayern",
    "Berlin": "Berlin",
    "Brandenburg": "Brandenburg",
    "Bremen": "Bremen",
    "Hessen": "Hessen",
    "Niedersachsen": "Niedersachsen",
    "Nordrhein-Westfalen": "Nordrhein-Westfalen",
    "Rheinland-Pfalz": "Rheinland-Pfalz",
    "Saarland": "Saarland",
    "Sachsen": "Sachsen",
    "Sachsen-Anhalt": "Sachsen-Anhalt",
    "Schleswig-Holstein": "Schleswig-Holstein",
    "Thüringen": "Thüringen",
    # Hamburg and Mecklenburg-Vorpommern are NOT covered by zvg-portal.de
}


async def fetch_all_listings(
    page: Page,
    area: AreaOfInterest,
    config: ScraperConfig,
) -> list[dict[str, Any]]:
    """
    Navigate the ZVG search form for the given area and return all raw
    listing dicts from every page of results.
    """
    bundesland = BUNDESLAND_MAP.get(area.bundesland, area.bundesland)
    if bundesland not in BUNDESLAND_MAP.values():
        logger.warning(
            "Bundesland '%s' may not be covered by zvg-portal.de", bundesland
        )

    courts = area.amtsgerichte or [""]  # empty = all courts

    all_raw: list[dict[str, Any]] = []
    seen_keys: set[str] = set()

    for gericht in courts:
        for plz in (area.plz_range or [""]):
            raw = await _search_one(
                page=page,
                bundesland=bundesland,
                gericht=gericht,
                plz=plz,
                config=config,
            )
            for item in raw:
                key = f"{item.get('amtsgericht')}::{item.get('aktenzeichen')}"
                if key not in seen_keys:
                    seen_keys.add(key)
                    all_raw.append(item)
            await page.wait_for_timeout(int(config.rate_limit_seconds * 1000))

    logger.info("Total raw listings collected: %d", len(all_raw))
    return all_raw


async def _search_one(
    page: Page,
    bundesland: str,
    gericht: str,
    plz: str,
    config: ScraperConfig,
) -> list[dict[str, Any]]:
    """Submit one search and paginate through all result pages."""
    logger.info(
        "Searching: Bundesland=%s  Gericht=%s  PLZ=%s", bundesland, gericht, plz
    )

    await page.goto(ZVG_SEARCH_URL, wait_until="networkidle", timeout=30_000)

    # --- Fill search form ---
    # Select Bundesland
    await page.select_option('select[name="land"]', label=bundesland)
    await page.wait_for_timeout(500)  # wait for court list to populate via JS

    # Select Gericht if specified
    if gericht:
        try:
            await page.select_option('select[name="gericht"]', label=gericht)
        except Exception:
            logger.warning("Court '%s' not found in dropdown, skipping", gericht)
            return []

    # Fill PLZ field if specified
    if plz:
        plz_field = page.locator('input[name="plz"]')
        if await plz_field.count():
            await plz_field.fill(plz)

    # Submit
    await page.click('input[type="submit"][value="Suchen"]')
    await page.wait_for_load_state("networkidle", timeout=30_000)

    return await _collect_all_pages(page, bundesland, config)


async def _collect_all_pages(
    page: Page,
    bundesland: str,
    config: ScraperConfig,
) -> list[dict[str, Any]]:
    """Iterate through paginated results and collect all rows."""
    results: list[dict[str, Any]] = []
    page_num = 1

    while True:
        html = await page.content()
        rows = _parse_result_table(html, bundesland)
        results.extend(rows)
        logger.debug("  Page %d: %d rows", page_num, len(rows))

        # Check for "next page" link / button
        next_btn = page.locator('a:has-text("weiter"), a:has-text(">>"), input[value="weiter"]')
        if await next_btn.count() == 0:
            break

        await next_btn.first.click()
        await page.wait_for_load_state("networkidle", timeout=30_000)
        await page.wait_for_timeout(int(config.rate_limit_seconds * 1000))
        page_num += 1

    return results


def _parse_result_table(html: str, bundesland: str) -> list[dict[str, Any]]:
    """
    Parse the HTML result table from the ZVG portal search results page.

    The portal renders a <table> where each <tr> represents one listing.
    Typical columns (may vary slightly by Bundesland):
      Aktenzeichen | Amtsgericht | Termin | Objekt | Verkehrswert
    """
    soup = BeautifulSoup(html, "lxml")
    rows: list[dict[str, Any]] = []

    # The results table has id="suchergebnis" or is the main content table
    table = (
        soup.find("table", {"id": "suchergebnis"})
        or soup.find("table", class_="richtig")
        or _find_result_table(soup)
    )
    if not table:
        logger.debug("No result table found on page")
        return rows

    trs = table.find_all("tr")
    header_row = trs[0] if trs else None
    headers = (
        [th.get_text(strip=True).lower() for th in header_row.find_all(["th", "td"])]
        if header_row
        else []
    )

    for tr in trs[1:]:
        cells = tr.find_all("td")
        if len(cells) < 3:
            continue

        raw: dict[str, Any] = {"bundesland": bundesland}

        # Try to map by header names first, fall back to positional
        if headers and len(headers) == len(cells):
            cell_map = {h: c for h, c in zip(headers, cells)}
            raw["aktenzeichen"] = _text(cell_map.get("aktenzeichen") or cells[0])
            raw["amtsgericht"] = _text(cell_map.get("amtsgericht") or cells[1])
            raw["termin_raw"] = _text(cell_map.get("termin") or cells[2])
            raw["objekt_beschreibung"] = _text(
                cell_map.get("objekt") or cell_map.get("objektbeschreibung") or cells[3] if len(cells) > 3 else cells[-1]
            )
            raw["verkehrswert_raw"] = _text(
                cell_map.get("verkehrswert") or (cells[4] if len(cells) > 4 else None)
            )
        else:
            # Positional fallback
            raw["aktenzeichen"] = _text(cells[0])
            raw["amtsgericht"] = _text(cells[1]) if len(cells) > 1 else ""
            raw["termin_raw"] = _text(cells[2]) if len(cells) > 2 else ""
            raw["objekt_beschreibung"] = _text(cells[3]) if len(cells) > 3 else ""
            raw["verkehrswert_raw"] = _text(cells[4]) if len(cells) > 4 else ""

        # Extract detail page link (Aktenzeichen is usually a hyperlink)
        link = cells[0].find("a")
        raw["detail_url"] = link["href"] if link and link.get("href") else None

        if raw["aktenzeichen"]:
            rows.append(raw)

    return rows


def _find_result_table(soup: BeautifulSoup):
    """Heuristic: find the table most likely to be the results table."""
    for table in soup.find_all("table"):
        text = table.get_text()
        if "Aktenzeichen" in text or "aktenzeichen" in text.lower():
            return table
    return None


def _text(tag) -> str:
    if tag is None:
        return ""
    return tag.get_text(separator=" ", strip=True)
