"""
Maps a Listing to its Google Drive folder path and syncs local files.
"""
from __future__ import annotations

import json
import logging
import re
from pathlib import Path

from src.config import StorageConfig
from src.models.listing import Listing
from src.storage.drive_client import DriveClient

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


async def organise_to_drive(
    listing: Listing,
    drive: DriveClient,
    storage_cfg: StorageConfig,
) -> None:
    """
    Upload all local files for a listing to Google Drive and
    update the listing with Drive folder info.
    """
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


async def upload_master_csv(
    csv_path: Path,
    drive: DriveClient,
    root_folder_name: str,
) -> None:
    """Upload / overwrite the master listings CSV at the root Drive folder."""
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
