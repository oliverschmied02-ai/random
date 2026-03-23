"""
Cloudflare R2 storage client (S3-compatible).

Free tier: 10 GB storage, 1 million Class-A operations/month, no egress fees.

Required env vars / config:
  R2_ACCOUNT_ID        — Cloudflare account ID (found in dashboard)
  R2_ACCESS_KEY_ID     — R2 API token key ID
  R2_SECRET_ACCESS_KEY — R2 API token secret
  R2_BUCKET_NAME       — bucket name (create in Cloudflare dashboard)
  R2_PUBLIC_URL        — optional: public bucket URL
                         e.g. https://pub-<hash>.r2.dev  or a custom domain

Key structure used:
  <bundesland>/<amtsgericht>/<aktenzeichen>/gutachten.pdf
  <bundesland>/<amtsgericht>/<aktenzeichen>/expose.jpg
  <bundesland>/<amtsgericht>/<aktenzeichen>/fotos/01.jpg
  state/zvg.db  (DB backup for ephemeral servers)
"""
from __future__ import annotations

import logging
import mimetypes
from pathlib import Path

logger = logging.getLogger(__name__)

try:
    import boto3
    from botocore.config import Config as BotoConfig
    from botocore.exceptions import ClientError
    _BOTO3_AVAILABLE = True
except ImportError:
    _BOTO3_AVAILABLE = False
    logger.warning("boto3 not installed — R2 storage disabled. Run: pip install boto3")


class R2Client:
    def __init__(
        self,
        account_id: str,
        access_key_id: str,
        secret_access_key: str,
        bucket_name: str,
        public_url_base: str = "",
    ) -> None:
        if not _BOTO3_AVAILABLE:
            raise RuntimeError("boto3 is required for R2 storage: pip install boto3")
        self._bucket = bucket_name
        self._public_base = public_url_base.rstrip("/")
        endpoint = f"https://{account_id}.r2.cloudflarestorage.com"
        self._s3 = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            config=BotoConfig(signature_version="s3v4"),
            region_name="auto",
        )

    def public_url(self, key: str) -> str:
        """Return the public URL for a given R2 key."""
        if self._public_base:
            return f"{self._public_base}/{key}"
        return ""

    def file_exists(self, key: str) -> bool:
        try:
            self._s3.head_object(Bucket=self._bucket, Key=key)
            return True
        except ClientError:
            return False

    def upload_file(self, local_path: Path, key: str) -> str:
        """
        Upload a local file to R2.
        Skips if the key already exists.
        Returns the public URL (empty string if no public_url_base configured).
        """
        if self.file_exists(key):
            logger.debug("R2 skip (exists): %s", key)
            return self.public_url(key)
        ct = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"
        self._s3.upload_file(
            str(local_path),
            self._bucket,
            key,
            ExtraArgs={"ContentType": ct},
        )
        url = self.public_url(key)
        logger.info("R2 uploaded: %s → %s", local_path.name, key)
        return url

    def upload_bytes(
        self, data: bytes, key: str, content_type: str = "application/octet-stream"
    ) -> str:
        """Upload raw bytes to R2. Returns public URL."""
        if self.file_exists(key):
            logger.debug("R2 skip (exists): %s", key)
            return self.public_url(key)
        self._s3.put_object(
            Body=data, Bucket=self._bucket, Key=key, ContentType=content_type
        )
        logger.info("R2 uploaded bytes: %s", key)
        return self.public_url(key)

    def download_file(self, key: str, local_path: Path) -> bool:
        """
        Download a file from R2 to a local path.
        Returns True on success, False if the key doesn't exist.
        """
        try:
            local_path.parent.mkdir(parents=True, exist_ok=True)
            self._s3.download_file(self._bucket, key, str(local_path))
            logger.info("R2 downloaded: %s → %s", key, local_path)
            return True
        except ClientError as exc:
            if exc.response["Error"]["Code"] in ("404", "NoSuchKey"):
                return False
            raise


_DB_R2_KEY = "state/zvg.db"


def pull_db(r2: R2Client, db_path: Path) -> bool:
    """
    Download DB from R2 if the local file doesn't exist yet.
    Call this on application startup for ephemeral servers (e.g. Render free tier).
    Returns True if the DB is now available locally.
    """
    if db_path.exists():
        return True
    logger.info("Local DB not found — pulling from R2 (%s)", _DB_R2_KEY)
    return r2.download_file(_DB_R2_KEY, db_path)


def push_db(r2: R2Client, db_path: Path) -> None:
    """
    Upload the local DB to R2 (overwrite).
    Call this after each scrape run to persist state on ephemeral servers.
    """
    if not db_path.exists():
        return
    # Always overwrite — delete first, then re-upload
    try:
        r2._s3.delete_object(Bucket=r2._bucket, Key=_DB_R2_KEY)
    except Exception:
        pass
    r2._s3.upload_file(
        str(db_path),
        r2._bucket,
        _DB_R2_KEY,
        ExtraArgs={"ContentType": "application/x-sqlite3"},
    )
    logger.info("R2 DB backup pushed: %s", _DB_R2_KEY)
