"""
Google Drive API wrapper.

Handles:
- OAuth2 authentication (service account or user credentials)
- Folder creation (idempotent)
- File upload (create or update)
- Generating shareable links
"""
from __future__ import annotations

import logging
import mimetypes
from pathlib import Path
from typing import Optional

from google.oauth2.credentials import Credentials
from google.oauth2 import service_account
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

from src.config import GoogleDriveConfig

logger = logging.getLogger(__name__)

SCOPES = ["https://www.googleapis.com/auth/drive"]


def folder_id_from_link(link: str) -> str:
    """
    Extrahiert die Folder-ID aus einem Google Drive Share-Link.
    Unterstützte Formate:
      https://drive.google.com/drive/folders/1abc...
      https://drive.google.com/drive/u/0/folders/1abc...
    Gibt den Link unverändert zurück wenn kein Folder-Muster erkannt wird.
    """
    import re
    m = re.search(r"/folders/([a-zA-Z0-9_-]+)", link)
    if m:
        return m.group(1)
    return link


class DriveClient:
    """Thin wrapper around the Google Drive v3 API."""

    def __init__(self, config: GoogleDriveConfig) -> None:
        self._config = config
        self._service = None
        self._folder_cache: dict[str, str] = {}  # path → folder_id

    def _get_service(self):
        if self._service:
            return self._service

        creds: Credentials | None = None
        creds_file = self._config.credentials_file
        token_file = self._config.token_file

        # Try service account first
        if creds_file.exists():
            try:
                creds = service_account.Credentials.from_service_account_file(
                    str(creds_file), scopes=SCOPES
                )
                logger.info("Using service account credentials")
            except Exception:
                pass  # fall through to OAuth flow

        # OAuth2 user credentials
        if creds is None:
            if token_file.exists():
                creds = Credentials.from_authorized_user_file(str(token_file), SCOPES)
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                elif creds_file.exists():
                    flow = InstalledAppFlow.from_client_secrets_file(
                        str(creds_file), SCOPES
                    )
                    creds = flow.run_local_server(port=0)
                else:
                    raise FileNotFoundError(
                        f"Google Drive credentials not found: {creds_file}"
                    )
                token_file.parent.mkdir(parents=True, exist_ok=True)
                token_file.write_text(creds.to_json())

        self._service = build("drive", "v3", credentials=creds)
        return self._service

    # ------------------------------------------------------------------
    # Folder operations
    # ------------------------------------------------------------------

    def get_or_create_folder(
        self, name: str, parent_id: Optional[str] = None
    ) -> str:
        """Return folder_id, creating the folder if it does not exist."""
        cache_key = f"{parent_id}:{name}"
        if cache_key in self._folder_cache:
            return self._folder_cache[cache_key]

        service = self._get_service()
        query = (
            f"name = '{name}' and mimeType = 'application/vnd.google-apps.folder'"
            " and trashed = false"
        )
        if parent_id:
            query += f" and '{parent_id}' in parents"

        results = (
            service.files()
            .list(q=query, fields="files(id, name)", spaces="drive")
            .execute()
        )
        files = results.get("files", [])
        if files:
            folder_id = files[0]["id"]
        else:
            meta = {
                "name": name,
                "mimeType": "application/vnd.google-apps.folder",
            }
            if parent_id:
                meta["parents"] = [parent_id]
            folder = service.files().create(body=meta, fields="id").execute()
            folder_id = folder["id"]
            logger.info("Created Drive folder '%s' (id=%s)", name, folder_id)

        self._folder_cache[cache_key] = folder_id
        return folder_id

    def get_or_create_folder_path(self, path_parts: list[str]) -> str:
        """
        Recursively create nested folders and return the deepest folder_id.
        path_parts: ["ZVG_Data", "Bayern", "AG_Muenchen", "12_K_45_24"]
        """
        parent_id: str | None = None
        for part in path_parts:
            parent_id = self.get_or_create_folder(part, parent_id)
        return parent_id  # type: ignore[return-value]

    # ------------------------------------------------------------------
    # File operations
    # ------------------------------------------------------------------

    def upload_file(
        self,
        local_path: Path,
        folder_id: str,
        file_name: Optional[str] = None,
    ) -> str:
        """
        Upload a file to a Drive folder.
        Returns the file_id.
        Skips upload if a file with the same name already exists in the folder.
        """
        service = self._get_service()
        name = file_name or local_path.name
        mime = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"

        # Check if already uploaded
        existing = (
            service.files()
            .list(
                q=f"name = '{name}' and '{folder_id}' in parents and trashed = false",
                fields="files(id)",
                spaces="drive",
            )
            .execute()
            .get("files", [])
        )
        if existing:
            logger.debug("Already on Drive: %s", name)
            return existing[0]["id"]

        media = MediaFileUpload(str(local_path), mimetype=mime, resumable=True)
        meta = {"name": name, "parents": [folder_id]}
        file = (
            service.files()
            .create(body=meta, media_body=media, fields="id")
            .execute()
        )
        logger.info("Uploaded %s to Drive (id=%s)", name, file["id"])
        return file["id"]

    def upload_json(self, data: str, file_name: str, folder_id: str) -> str:
        """Upload a JSON string as a file."""
        import tempfile, os
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as tmp:
            tmp.write(data)
            tmp_path = Path(tmp.name)
        try:
            fid = self.upload_file(tmp_path, folder_id, file_name=file_name)
        finally:
            os.unlink(tmp_path)
        return fid

    def get_folder_url(self, folder_id: str) -> str:
        return f"https://drive.google.com/drive/folders/{folder_id}"
