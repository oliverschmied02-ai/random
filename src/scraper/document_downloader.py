"""
Download Gutachten PDFs, Exposé PDFs, and Fotos for a listing.

Attachment URL format:
  https://www.zvg-portal.de/?button=showAnhang&land_abk=<state>&file_id=<id>&zvg_id=<id>

The portal requires the Referer header to serve attachments.
Files are saved to: <files_dir>/<bundesland>/<amtsgericht>/<aktenzeichen>/
"""
from __future__ import annotations

import logging
import re
import time
from pathlib import Path

import requests

from src.config import ScraperConfig, StorageConfig
from src.models.listing import Listing
from src.scraper.session import ZVG_BASE_URL

logger = logging.getLogger(__name__)

_DOWNLOAD_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Referer": f"{ZVG_BASE_URL}/index.php?button=Suchen",
}


def _safe_name(s: str) -> str:
    return re.sub(r'[\\/*?:"<>|]', "_", s).strip()


def listing_local_dir(listing: Listing, files_dir: Path) -> Path:
    parts = [
        _safe_name(listing.bundesland),
        _safe_name(listing.amtsgericht),
        _safe_name(listing.aktenzeichen.replace(" ", "_").replace("/", "_")),
    ]
    return files_dir.joinpath(*parts)


def download_documents(
    listing: Listing,
    storage_cfg: StorageConfig,
    scraper_cfg: ScraperConfig,
    session: requests.Session | None = None,
) -> None:
    """
    Download all available documents for a listing into local storage.
    Accepts an optional shared requests.Session for cookie reuse.
    """
    dest_dir = listing_local_dir(listing, storage_cfg.files_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    dl_session = session or requests.Session()
    dl_session.headers.update(_DOWNLOAD_HEADERS)

    if listing.gutachten_url:
        path = _download_file(
            dl_session, listing.gutachten_url,
            dest_dir / "gutachten.pdf",
            scraper_cfg.max_retries,
        )
        if path:
            listing.gutachten_local_path = str(path)

    if listing.expose_url:
        path = _download_file(
            dl_session, listing.expose_url,
            dest_dir / "expose.pdf",
            scraper_cfg.max_retries,
        )
        if path:
            listing.expose_local_path = str(path)

    foto_dir = dest_dir / "fotos"
    foto_dir.mkdir(exist_ok=True)
    for i, url in enumerate(listing.foto_urls, start=1):
        ext = _ext_from_url(url)
        path = _download_file(
            dl_session, url,
            foto_dir / f"{i:02d}{ext}",
            scraper_cfg.max_retries,
        )
        if path:
            listing.foto_local_paths.append(str(path))

    time.sleep(scraper_cfg.rate_limit_seconds)


def _download_file(
    session: requests.Session,
    url: str,
    dest: Path,
    max_retries: int,
) -> Path | None:
    """Download a single file with exponential-backoff retry."""
    if dest.exists():
        logger.debug("Already downloaded: %s", dest)
        return dest

    for attempt in range(1, max_retries + 1):
        try:
            resp = session.get(url, timeout=60, stream=True)
            resp.raise_for_status()
            dest.write_bytes(resp.content)
            logger.info("Downloaded %s → %s", url, dest.name)
            return dest
        except requests.HTTPError as exc:
            logger.warning(
                "HTTP %d for %s (attempt %d/%d)",
                exc.response.status_code, url, attempt, max_retries
            )
        except Exception as exc:
            logger.warning(
                "Error downloading %s: %s (attempt %d/%d)", url, exc, attempt, max_retries
            )

        if attempt < max_retries:
            time.sleep(2 ** attempt)

    return None


def _ext_from_url(url: str) -> str:
    suffix = Path(url.split("?")[0]).suffix.lower()
    return suffix if suffix in {".jpg", ".jpeg", ".png", ".gif", ".webp"} else ".jpg"
