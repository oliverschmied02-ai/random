"""
SQLite-backed local cache for Listing objects.

Provides:
- init():             create tables if not exists
- upsert(listing):    insert or update by unique key
- is_new_or_changed():  deduplication check
- get_all():          fetch all listings as Listing objects
"""
from __future__ import annotations

import json
import logging
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional

from src.models.listing import Listing

logger = logging.getLogger(__name__)

_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS listings (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_key              TEXT UNIQUE NOT NULL,
    aktenzeichen            TEXT,
    amtsgericht             TEXT,
    bundesland              TEXT,
    termin                  TEXT,
    objekt_beschreibung     TEXT,
    plz                     TEXT,
    ort                     TEXT,
    verkehrswert            REAL,
    art_der_versteigerung   TEXT,
    status                  TEXT,
    cancellation_reason     TEXT,
    gutachten_url           TEXT,
    expose_url              TEXT,
    foto_urls               TEXT,    -- JSON array
    gutachten_local_path    TEXT,
    expose_local_path       TEXT,
    foto_local_paths        TEXT,    -- JSON array
    wohnflaeche_sqm         REAL,
    grundstueck_sqm         REAL,
    baujahr                 INTEGER,
    zimmer                  INTEGER,
    price_per_sqm           REAL,
    mindestgebot_50pct      REAL,
    sicherheitsgrenze_70pct REAL,
    lat                     REAL,
    lon                     REAL,
    full_address            TEXT,
    ai_summary              TEXT,
    ai_risk_flags           TEXT,    -- JSON array
    ai_attractiveness_score INTEGER,
    ai_recommended_max_bid  REAL,
    drive_folder_id         TEXT,
    drive_folder_url        TEXT,
    scraped_at              TEXT,
    last_updated            TEXT
);

CREATE TABLE IF NOT EXISTS run_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at  TEXT,
    finished_at TEXT,
    listings_new    INTEGER,
    listings_total  INTEGER
);
"""


class ListingDB:
    def __init__(self, db_path: Path | str) -> None:
        self._path = Path(db_path)
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._conn: sqlite3.Connection | None = None

    def init(self) -> None:
        conn = self._get_conn()
        conn.executescript(_CREATE_SQL)
        conn.commit()

    def _get_conn(self) -> sqlite3.Connection:
        if self._conn is None:
            self._conn = sqlite3.connect(self._path, check_same_thread=False)
            self._conn.row_factory = sqlite3.Row
        return self._conn

    def is_new_or_changed(self, listing: Listing) -> bool:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT status, verkehrswert FROM listings WHERE unique_key = ?",
            (listing.unique_key(),),
        ).fetchone()
        if row is None:
            return True  # new
        # Changed if status or Verkehrswert differs
        return (
            row["status"] != listing.status
            or row["verkehrswert"] != listing.verkehrswert
        )

    def upsert(self, listing: Listing) -> None:
        conn = self._get_conn()
        now = datetime.utcnow().isoformat()
        data = (
            listing.unique_key(),
            listing.aktenzeichen,
            listing.amtsgericht,
            listing.bundesland,
            listing.termin.isoformat() if listing.termin else None,
            listing.objekt_beschreibung,
            listing.plz,
            listing.ort,
            listing.verkehrswert,
            listing.art_der_versteigerung,
            listing.status,
            listing.cancellation_reason,
            listing.gutachten_url,
            listing.expose_url,
            json.dumps(listing.foto_urls),
            listing.gutachten_local_path,
            listing.expose_local_path,
            json.dumps(listing.foto_local_paths),
            listing.wohnflaeche_sqm,
            listing.grundstueck_sqm,
            listing.baujahr,
            listing.zimmer,
            listing.price_per_sqm,
            listing.mindestgebot_50pct,
            listing.sicherheitsgrenze_70pct,
            listing.lat,
            listing.lon,
            listing.full_address,
            listing.ai_summary,
            json.dumps(listing.ai_risk_flags),
            listing.ai_attractiveness_score,
            listing.ai_recommended_max_bid,
            listing.drive_folder_id,
            listing.drive_folder_url,
            listing.scraped_at.isoformat(),
            now,
        )
        conn.execute(
            """
            INSERT INTO listings (
                unique_key, aktenzeichen, amtsgericht, bundesland, termin,
                objekt_beschreibung, plz, ort, verkehrswert,
                art_der_versteigerung, status, cancellation_reason,
                gutachten_url, expose_url, foto_urls,
                gutachten_local_path, expose_local_path, foto_local_paths,
                wohnflaeche_sqm, grundstueck_sqm, baujahr, zimmer,
                price_per_sqm, mindestgebot_50pct, sicherheitsgrenze_70pct,
                lat, lon, full_address,
                ai_summary, ai_risk_flags, ai_attractiveness_score,
                ai_recommended_max_bid, drive_folder_id, drive_folder_url,
                scraped_at, last_updated
            ) VALUES (
                ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
            )
            ON CONFLICT(unique_key) DO UPDATE SET
                status=excluded.status,
                verkehrswert=excluded.verkehrswert,
                termin=excluded.termin,
                cancellation_reason=excluded.cancellation_reason,
                gutachten_url=excluded.gutachten_url,
                expose_url=excluded.expose_url,
                foto_urls=excluded.foto_urls,
                gutachten_local_path=excluded.gutachten_local_path,
                expose_local_path=excluded.expose_local_path,
                foto_local_paths=excluded.foto_local_paths,
                wohnflaeche_sqm=excluded.wohnflaeche_sqm,
                grundstueck_sqm=excluded.grundstueck_sqm,
                baujahr=excluded.baujahr,
                zimmer=excluded.zimmer,
                price_per_sqm=excluded.price_per_sqm,
                mindestgebot_50pct=excluded.mindestgebot_50pct,
                sicherheitsgrenze_70pct=excluded.sicherheitsgrenze_70pct,
                lat=excluded.lat,
                lon=excluded.lon,
                full_address=excluded.full_address,
                ai_summary=excluded.ai_summary,
                ai_risk_flags=excluded.ai_risk_flags,
                ai_attractiveness_score=excluded.ai_attractiveness_score,
                ai_recommended_max_bid=excluded.ai_recommended_max_bid,
                drive_folder_id=excluded.drive_folder_id,
                drive_folder_url=excluded.drive_folder_url,
                last_updated=excluded.last_updated
            """,
            data,
        )
        conn.commit()

    def get_all(self) -> list[Listing]:
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM listings").fetchall()
        return [_row_to_listing(row) for row in rows]

    def get_by_key(self, unique_key: str) -> Optional[Listing]:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT * FROM listings WHERE unique_key = ?", (unique_key,)
        ).fetchone()
        return _row_to_listing(row) if row else None

    def log_run(
        self, started_at: datetime, finished_at: datetime, new: int, total: int
    ) -> None:
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO run_log (started_at, finished_at, listings_new, listings_total) "
            "VALUES (?,?,?,?)",
            (started_at.isoformat(), finished_at.isoformat(), new, total),
        )
        conn.commit()


def _row_to_listing(row: sqlite3.Row) -> Listing:
    def dt(val: str | None) -> datetime | None:
        return datetime.fromisoformat(val) if val else None

    return Listing(
        aktenzeichen=row["aktenzeichen"] or "",
        amtsgericht=row["amtsgericht"] or "",
        bundesland=row["bundesland"] or "",
        termin=dt(row["termin"]),
        objekt_beschreibung=row["objekt_beschreibung"] or "",
        plz=row["plz"] or "",
        ort=row["ort"] or "",
        verkehrswert=row["verkehrswert"],
        art_der_versteigerung=row["art_der_versteigerung"] or "",
        status=row["status"] or "active",
        cancellation_reason=row["cancellation_reason"],
        gutachten_url=row["gutachten_url"],
        expose_url=row["expose_url"],
        foto_urls=json.loads(row["foto_urls"] or "[]"),
        gutachten_local_path=row["gutachten_local_path"],
        expose_local_path=row["expose_local_path"],
        foto_local_paths=json.loads(row["foto_local_paths"] or "[]"),
        wohnflaeche_sqm=row["wohnflaeche_sqm"],
        grundstueck_sqm=row["grundstueck_sqm"],
        baujahr=row["baujahr"],
        zimmer=row["zimmer"],
        price_per_sqm=row["price_per_sqm"],
        mindestgebot_50pct=row["mindestgebot_50pct"],
        sicherheitsgrenze_70pct=row["sicherheitsgrenze_70pct"],
        lat=row["lat"],
        lon=row["lon"],
        full_address=row["full_address"],
        ai_summary=row["ai_summary"],
        ai_risk_flags=json.loads(row["ai_risk_flags"] or "[]"),
        ai_attractiveness_score=row["ai_attractiveness_score"],
        ai_recommended_max_bid=row["ai_recommended_max_bid"],
        drive_folder_id=row["drive_folder_id"],
        drive_folder_url=row["drive_folder_url"],
        scraped_at=dt(row["scraped_at"]) or datetime.utcnow(),
        last_updated=dt(row["last_updated"]) or datetime.utcnow(),
    )
