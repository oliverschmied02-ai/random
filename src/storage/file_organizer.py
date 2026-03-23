"""
Maps a Listing to its Google Drive folder path and syncs local files.
Also supports uploading to Cloudflare R2 (organise_to_r2).
"""
from __future__ import annotations

import json
import logging
import re
from pathlib import Path

from src.config import StorageConfig
from src.models.listing import Listing
from src.storage.drive_client import DriveClient, folder_id_from_link
from src.storage.r2_client import R2Client

logger = logging.getLogger(__name__)


def _safe(s: str) -> str:
    return re.sub(r'[\\/*?:"<>|]', "_", s).strip()


def listing_drive_path(listing: Listing, root: str) -> list[str]:
    """
    Returns the folder path components for a listing on Google Drive.
    e.g. ["ZVG_Data", "Bayern", "AG_Muenchen", "12_K_45_24"]
    """
    return [
        root,
        _safe(listing.bundesland),
        _safe(listing.amtsgericht),
        _safe(listing.aktenzeichen.replace(" ", "_").replace("/", "_")),
    ]


def _get_root_folder_id(drive: DriveClient, storage_cfg: StorageConfig) -> str | None:
    """
    Gibt die Root-Folder-ID zurück.
    Priorität: root_folder_link > root_folder_name (wird dann neu angelegt).
    """
    link = storage_cfg.google_drive.root_folder_link
    if link:
        fid = folder_id_from_link(link)
        logger.info("Nutze vorhandenen Drive-Ordner (ID: %s)", fid)
        return fid
    return None  # file_organizer legt per Name an


async def organise_to_drive(
    listing: Listing,
    drive: DriveClient,
    storage_cfg: StorageConfig,
) -> None:
    """
    Upload all local files for a listing to Google Drive and
    update the listing with Drive folder info.
    """
    root_id = _get_root_folder_id(drive, storage_cfg)

    if root_id:
        # Vorhandenen Ordner nutzen — nur Unterordner für Bundesland/AG/AZ anlegen
        subpath = [
            _safe(listing.bundesland),
            _safe(listing.amtsgericht),
            _safe(listing.aktenzeichen.replace(" ", "_").replace("/", "_")),
        ]
        parent_id = root_id
        for part in subpath:
            parent_id = drive.get_or_create_folder(part, parent_id)
        folder_id = parent_id
    else:
        path_parts = listing_drive_path(
            listing, storage_cfg.google_drive.root_folder_name
        )
        folder_id = drive.get_or_create_folder_path(path_parts)
    listing.drive_folder_id = folder_id
    listing.drive_folder_url = drive.get_folder_url(folder_id)

    # Upload metadata.json
    drive.upload_json(
        json.dumps(listing.to_dict(), ensure_ascii=False, indent=2),
        "metadata.json",
        folder_id,
    )

    # Upload Gutachten PDF
    if listing.gutachten_local_path:
        p = Path(listing.gutachten_local_path)
        if p.exists():
            drive.upload_file(p, folder_id)

    # Upload Exposé PDF
    if listing.expose_local_path:
        p = Path(listing.expose_local_path)
        if p.exists():
            drive.upload_file(p, folder_id)

    # Upload Fotos
    if listing.foto_local_paths:
        foto_folder_id = drive.get_or_create_folder("fotos", folder_id)
        for local_path in listing.foto_local_paths:
            p = Path(local_path)
            if p.exists():
                drive.upload_file(p, foto_folder_id)

    logger.info(
        "Synced %s → Drive %s", listing.aktenzeichen, listing.drive_folder_url
    )


def _r2_prefix(listing: Listing) -> str:
    """R2 key prefix for a listing, e.g. Bayern/AG_Muenchen/12_K_45_24"""
    return "/".join([
        _safe(listing.bundesland),
        _safe(listing.amtsgericht),
        _safe(listing.aktenzeichen.replace(" ", "_").replace("/", "_")),
    ])


def organise_to_r2(listing: Listing, r2: R2Client) -> None:
    """
    Upload all local files for a listing to Cloudflare R2.
    Sets r2_gutachten_url, r2_expose_url, r2_foto_urls on the listing.
    Already-uploaded files are skipped (idempotent).
    """
    prefix = _r2_prefix(listing)

    if listing.gutachten_local_path:
        p = Path(listing.gutachten_local_path)
        if p.exists():
            key = f"{prefix}/{p.name}"
            listing.r2_gutachten_url = r2.upload_file(p, key) or None

    if listing.expose_local_path:
        p = Path(listing.expose_local_path)
        if p.exists():
            key = f"{prefix}/{p.name}"
            listing.r2_expose_url = r2.upload_file(p, key) or None

    listing.r2_foto_urls = []
    for local_path in listing.foto_local_paths:
        p = Path(local_path)
        if p.exists():
            key = f"{prefix}/fotos/{p.name}"
            url = r2.upload_file(p, key)
            if url:
                listing.r2_foto_urls.append(url)

    logger.info("R2 synced: %s", listing.aktenzeichen)


async def upload_master_csv(
    csv_path: Path,
    drive: DriveClient,
    root_folder_name: str,
    root_folder_link: str = "",
) -> None:
    """Upload / overwrite the master listings CSV at the root Drive folder."""
    if root_folder_link:
        root_id = folder_id_from_link(root_folder_link)
    else:
        root_id = drive.get_or_create_folder(root_folder_name)
    # Delete existing master CSV to allow overwrite
    service = drive._get_service()
    existing = (
        service.files()
        .list(
            q=f"name = 'listings_master.csv' and '{root_id}' in parents and trashed = false",
            fields="files(id)",
        )
        .execute()
        .get("files", [])
    )
    for f in existing:
        service.files().delete(fileId=f["id"]).execute()

    drive.upload_file(csv_path, root_id, file_name="listings_master.csv")
    logger.info("Master CSV uploaded to Drive root folder")
