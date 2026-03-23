"""
Scheduler — wraps the full scrape pipeline with APScheduler for cron execution.
Can also be triggered manually via the CLI.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from src.config import AppConfig

logger = logging.getLogger(__name__)


async def run_pipeline(config: AppConfig) -> None:
    """
    Full pipeline: scrape → store → analyse.
    Imported here to avoid circular imports.
    """
    from src.scraper.session import ZVGSession
    from src.scraper.search import fetch_all_listings
    from src.scraper.listing_parser import parse_listing
    from src.scraper.document_downloader import download_documents
    from src.storage.local_db import ListingDB
    from src.storage.drive_client import DriveClient
    from src.storage.file_organizer import organise_to_drive
    from src.analysis.enricher import enrich_listing
    from src.analysis.ai_analyst import analyse_listing
    from src.analysis.report import generate_reports

    logger.info("Pipeline started at %s", datetime.utcnow().isoformat())
    start = datetime.utcnow()

    db = ListingDB(config.storage.local_db_path)
    db.init()

    async with ZVGSession(config.scraper) as session:
        page = await session.new_page()
        raw_listings = await fetch_all_listings(
            page, config.scraper.area_of_interest, config.scraper
        )

    listings = []
    for raw in raw_listings:
        listing = parse_listing(raw)
        if db.is_new_or_changed(listing):
            listings.append(listing)

    logger.info("%d new/changed listings to process", len(listings))

    # Download documents
    for listing in listings:
        await download_documents(listing, config.storage, config.scraper)

    # Enrich
    for listing in listings:
        enrich_listing(listing)

    # AI analysis (if API key present)
    if config.anthropic_api_key and config.analysis.run_after_scrape:
        for listing in listings:
            await analyse_listing(listing, config)

    # Persist to local DB
    for listing in listings:
        db.upsert(listing)

    # Sync to Google Drive (if credentials present)
    drive_creds = config.storage.google_drive.credentials_file
    if drive_creds.exists():
        drive = DriveClient(config.storage.google_drive)
        for listing in listings:
            await organise_to_drive(listing, drive, config.storage)

    # Generate reports
    all_listings = db.get_all()
    generate_reports(all_listings, config)

    elapsed = (datetime.utcnow() - start).total_seconds()
    logger.info(
        "Pipeline complete. Processed %d listings in %.1fs", len(listings), elapsed
    )


def start_scheduler(config: AppConfig) -> None:
    """Start APScheduler with the configured cron expression."""
    cron = config.scraper.schedule_cron
    if not cron:
        logger.info("No schedule_cron configured — running once immediately")
        asyncio.run(run_pipeline(config))
        return

    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        run_pipeline,
        CronTrigger.from_crontab(cron),
        args=[config],
        id="zvg_pipeline",
        name="ZVG Scrape Pipeline",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started with cron: %s", cron)

    try:
        asyncio.get_event_loop().run_forever()
    except (KeyboardInterrupt, SystemExit):
        scheduler.shutdown()
        logger.info("Scheduler stopped")
