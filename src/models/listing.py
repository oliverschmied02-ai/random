"""
Core data model for a single Zwangsversteigerung listing.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class Listing:
    # ------------------------------------------------------------------
    # Fields scraped directly from zvg-portal.de
    # ------------------------------------------------------------------
    aktenzeichen: str                   # e.g. "12 K 45/24"
    amtsgericht: str                    # e.g. "AG München"
    bundesland: str
    termin: Optional[datetime]          # scheduled auction date/time
    objekt_beschreibung: str            # raw text from portal
    plz: str
    ort: str
    verkehrswert: Optional[float]       # EUR — cleaned to float
    art_der_versteigerung: str
    status: str = "active"             # "active" | "cancelled"
    cancellation_reason: Optional[str] = None

    # Document URLs on the portal
    gutachten_url: Optional[str] = None
    expose_url: Optional[str] = None
    foto_urls: list[str] = field(default_factory=list)

    # Local file paths (after download)
    gutachten_local_path: Optional[str] = None
    expose_local_path: Optional[str] = None
    foto_local_paths: list[str] = field(default_factory=list)

    # ------------------------------------------------------------------
    # Enriched fields (set by analysis layer)
    # ------------------------------------------------------------------
    wohnflaeche_sqm: Optional[float] = None
    grundstueck_sqm: Optional[float] = None
    baujahr: Optional[int] = None
    zimmer: Optional[int] = None
    price_per_sqm: Optional[float] = None

    # Bietgrenzen
    mindestgebot_50pct: Optional[float] = None       # Verkehrswert × 0.50
    sicherheitsgrenze_70pct: Optional[float] = None  # Verkehrswert × 0.70

    # Geocoding
    lat: Optional[float] = None
    lon: Optional[float] = None
    full_address: Optional[str] = None

    # AI analysis
    ai_summary: Optional[str] = None
    ai_risk_flags: list[str] = field(default_factory=list)
    ai_attractiveness_score: Optional[int] = None   # 1–10
    ai_recommended_max_bid: Optional[float] = None

    # Google Drive
    drive_folder_id: Optional[str] = None
    drive_folder_url: Optional[str] = None

    # Metadata
    scraped_at: datetime = field(default_factory=datetime.utcnow)
    last_updated: datetime = field(default_factory=datetime.utcnow)

    # ------------------------------------------------------------------
    # Derived helpers
    # ------------------------------------------------------------------

    def compute_bietgrenzen(self) -> None:
        """Calculate Mindestgebot (50%) and Sicherheitsgrenze (70%)."""
        if self.verkehrswert is not None:
            self.mindestgebot_50pct = round(self.verkehrswert * 0.50, 2)
            self.sicherheitsgrenze_70pct = round(self.verkehrswert * 0.70, 2)

    def compute_price_per_sqm(self) -> None:
        """Price per sqm based on Verkehrswert / Wohnfläche."""
        if self.verkehrswert and self.wohnflaeche_sqm:
            self.price_per_sqm = round(
                self.verkehrswert / self.wohnflaeche_sqm, 2
            )

    def unique_key(self) -> str:
        """Stable deduplication key."""
        return f"{self.amtsgericht}::{self.aktenzeichen}"

    def to_dict(self) -> dict:
        """Flat dict for CSV/Excel export."""
        return {
            "aktenzeichen": self.aktenzeichen,
            "amtsgericht": self.amtsgericht,
            "bundesland": self.bundesland,
            "termin": self.termin.isoformat() if self.termin else None,
            "objekt_beschreibung": self.objekt_beschreibung,
            "plz": self.plz,
            "ort": self.ort,
            "verkehrswert": self.verkehrswert,
            "art_der_versteigerung": self.art_der_versteigerung,
            "status": self.status,
            "cancellation_reason": self.cancellation_reason,
            "wohnflaeche_sqm": self.wohnflaeche_sqm,
            "grundstueck_sqm": self.grundstueck_sqm,
            "baujahr": self.baujahr,
            "zimmer": self.zimmer,
            "price_per_sqm": self.price_per_sqm,
            "mindestgebot_50pct": self.mindestgebot_50pct,
            "sicherheitsgrenze_70pct": self.sicherheitsgrenze_70pct,
            "lat": self.lat,
            "lon": self.lon,
            "full_address": self.full_address,
            "ai_summary": self.ai_summary,
            "ai_risk_flags": "; ".join(self.ai_risk_flags),
            "ai_attractiveness_score": self.ai_attractiveness_score,
            "ai_recommended_max_bid": self.ai_recommended_max_bid,
            "gutachten_url": self.gutachten_url,
            "drive_folder_url": self.drive_folder_url,
            "scraped_at": self.scraped_at.isoformat(),
            "last_updated": self.last_updated.isoformat(),
        }
