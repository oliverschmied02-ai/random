"""
Configuration loader — reads config.yaml + .env via pydantic-settings.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


# ---------------------------------------------------------------------------
# Sub-models
# ---------------------------------------------------------------------------

class AreaOfInterest(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    bundesland: str = "Bayern"
    amtsgerichte: list[str] = []
    plz_range: list[str] = []
    objekt_types: list[str] = []


class ScraperConfig(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    area_of_interest: AreaOfInterest = AreaOfInterest()
    schedule_cron: str = ""
    rate_limit_seconds: float = 2.0
    max_retries: int = 3
    headless: bool = True


class GoogleDriveConfig(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    credentials_file: Path = Path("./secrets/gdrive_credentials.json")
    token_file: Path = Path("./secrets/gdrive_token.json")
    root_folder_name: str = "ZVG_Data"
    # Optional: direkt einen bestehenden Ordner per Share-Link verwenden
    root_folder_link: str = ""  # z.B. https://drive.google.com/drive/folders/1abc...


class StorageConfig(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    local_db_path: Path = Path("./data/zvg.db")
    files_dir: Path = Path("./data/files")
    google_drive: GoogleDriveConfig = GoogleDriveConfig()


class AnalysisConfig(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    run_after_scrape: bool = True
    ai_provider: str = "claude"  # claude | ollama | openrouter
    ai_model: str = "claude-haiku-4-5-20251001"  # Standard: Haiku (günstig)
    ollama_model: str = "llama3.2"
    ollama_endpoint: str = "http://localhost:11434"
    geocoding_provider: str = "nominatim"
    alert_threshold_verkehrswert_max: float = 500_000.0
    alert_channel: str = "none"  # none | email | telegram


class ReportingConfig(BaseSettings):
    model_config = SettingsConfigDict(extra="allow")

    output_formats: list[str] = ["csv", "excel", "html"]
    output_dir: Path = Path("./reports")


class AppConfig(BaseSettings):
    """Root configuration — loaded from config.yaml, overridable via env."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="allow",
    )

    scraper: ScraperConfig = ScraperConfig()
    storage: StorageConfig = StorageConfig()
    analysis: AnalysisConfig = AnalysisConfig()
    reporting: ReportingConfig = ReportingConfig()

    # .env / environment variables
    anthropic_api_key: str = ""
    openrouter_api_key: str = ""
    alert_email_from: str = ""
    alert_email_to: str = ""
    alert_email_smtp_host: str = "smtp.gmail.com"
    alert_email_smtp_port: int = 587
    alert_email_smtp_user: str = ""
    alert_email_smtp_pass: str = ""
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""
    google_geocoding_api_key: str = ""


def load_config(config_path: str | Path = "config.yaml") -> AppConfig:
    """Load config from YAML file, then let env vars override."""
    config_path = Path(config_path)
    raw: dict[str, Any] = {}
    if config_path.exists():
        with open(config_path) as f:
            raw = yaml.safe_load(f) or {}

    # Build nested config objects from raw YAML dict
    scraper_raw = raw.get("scraper", {})
    area_raw = scraper_raw.get("area_of_interest", {})
    storage_raw = raw.get("storage", {})
    drive_raw = storage_raw.get("google_drive", {})
    analysis_raw = raw.get("analysis", {})
    reporting_raw = raw.get("reporting", {})

    return AppConfig(
        scraper=ScraperConfig(
            area_of_interest=AreaOfInterest(**area_raw),
            schedule_cron=scraper_raw.get("schedule_cron", ""),
            rate_limit_seconds=scraper_raw.get("rate_limit_seconds", 2.0),
            max_retries=scraper_raw.get("max_retries", 3),
            headless=scraper_raw.get("headless", True),
        ),
        storage=StorageConfig(
            local_db_path=storage_raw.get("local_db_path", "./data/zvg.db"),
            files_dir=storage_raw.get("files_dir", "./data/files"),
            google_drive=GoogleDriveConfig(**drive_raw),
        ),
        analysis=AnalysisConfig(
            run_after_scrape=analysis_raw.get("run_after_scrape", True),
            ai_provider=analysis_raw.get("ai_provider", "claude"),
            ai_model=analysis_raw.get("ai_model", "claude-haiku-4-5-20251001"),
            ollama_model=analysis_raw.get("ollama_model", "llama3.2"),
            ollama_endpoint=analysis_raw.get("ollama_endpoint", "http://localhost:11434"),
            geocoding_provider=analysis_raw.get("geocoding_provider", "nominatim"),
            alert_threshold_verkehrswert_max=analysis_raw.get("alert_threshold_verkehrswert_max", 500_000.0),
            alert_channel=analysis_raw.get("alert_channel", "none"),
        ),
        reporting=ReportingConfig(**reporting_raw),
    )
