"""
Download Gutachten PDFs, Exposé PDFs, and Fotos for a listing.

Files are saved to:  <files_dir>/<bundesland>/<amtsgericht>/<aktenzeichen>/
"""
from __future__ import annotations

import asyncio
import logging
import re
from pathlib import Path

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from src.config import ScraperConfig, StorageConfig
from src.models.listing import Listing

logger = logging.getLogger(__name__)

# Reuse a single async client across downloads
_CLIENT: httpx.AsyncClient | None = None


def _safe_name(s: str) -> str:
    """Strip characters unsafe for file/folder names."""
    return re.sub(r'[\\/*?:"<>|]', "_", s).strip()


def listing_local_dir(listing: Listing, files_dir: Path) -> Path:
    parts = [
        _safe_name(listing.bundesland),
        _safe_name(listing.amtsgericht),
        _safe_name(listing.aktenzeichen.replace(" ", "_").replace("/", "_")),
    ]
    return files_dir.joinpath(*parts)


async def download_documents(
    listing: Listing,
    storage_cfg: StorageConfig,
    scraper_cfg: ScraperConfig,
) -> None:
    """Download all available documents for a listing into local storage."""
    dest_dir = listing_local_dir(listing, storage_cfg.files_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    async with httpx.AsyncClient(
        follow_redirects=True,
        timeout=60.0,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        },
    ) as client:
        if listing.gutachten_url:
            path = await _download_file(
                client, listing.gutachten_url, dest_dir / "gutachten.pdf",
                scraper_cfg.max_retries
            )
            if path:
                listing.gutachten_local_path = str(path)

        if listing.expose_url:
            path = await _download_file(
                client, listing.expose_url, dest_dir / "expose.pdf",
                scraper_cfg.max_retries
            )
            if path:
                listing.expose_local_path = str(path)

        foto_dir = dest_dir / "fotos"
        foto_dir.mkdir(exist_ok=True)
        for i, url in enumerate(listing.foto_urls, start=1):
            ext = _ext_from_url(url)
            path = await _download_file(
                client, url, foto_dir / f"{i:02d}{ext}",
                scraper_cfg.max_retries
            )
            if path:
                listing.foto_local_paths.append(str(path))

        await asyncio.sleep(scraper_cfg.rate_limit_seconds)


async def _download_file(
    client: httpx.AsyncClient,
    url: str,
    dest: Path,
    max_retries: int,
) -> Path | None:
    """Download a single file with retry logic."""
    if dest.exists():
        logger.debug("Already downloaded: %s", dest)
        return dest

    for attempt in range(1, max_retries + 1):
        try:
            resp = await client.get(url)
            resp.raise_for_status()
            dest.write_bytes(resp.content)
            logger.info("Downloaded %s → %s", url, dest)
            return dest
        except httpx.HTTPStatusError as exc:
            logger.warning(
                "HTTP %d for %s (attempt %d/%d)",
                exc.response.status_code, url, attempt, max_retries
            )
        except Exception as exc:
            logger.warning("Error downloading %s: %s (attempt %d/%d)", url, exc, attempt, max_retries)

        if attempt < max_retries:
            await asyncio.sleep(2 ** attempt)

    return None


def _ext_from_url(url: str) -> str:
    suffix = Path(url.split("?")[0]).suffix
    return suffix if suffix in {".jpg", ".jpeg", ".png", ".gif", ".webp"} else ".jpg"
