"""
Scheduler — runs the full pipeline on a cron schedule via APScheduler.
Can also be triggered manually via CLI (runs once immediately).
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
    Full pipeline: scrape → enrich → AI analyse → store → Drive sync → report → alert.
    """
    from src.scraper.session import make_session, fetch_detail_page
    from src.scraper.search import fetch_all_listings
    from src.scraper.listing_parser import parse_listing
    from src.scraper.document_downloader import download_documents
    from src.storage.local_db import ListingDB
    from src.storage.drive_client import DriveClient
    from src.storage.file_organizer import organise_to_drive
    from src.analysis.enricher import enrich_listing
    from src.analysis.ai_analyst import analyse_listing
    from src.analysis.report import generate_reports
    from src.analysis.alerting import send_alerts

    logger.info("Pipeline started at %s", datetime.utcnow().isoformat())
    start = datetime.utcnow()

    db = ListingDB(config.storage.local_db_path)
    db.init()

    # --- Scrape ---
    session = make_session(config.scraper)
    raw_listings = fetch_all_listings(config.scraper.area_of_interest, config.scraper)

    new_listings = []
    for raw in raw_listings:
        # Fetch detail page for richer data
        if raw.get("zvg_id") and raw.get("land_abk"):
            try:
                detail_html = fetch_detail_page(session, raw["zvg_id"], raw["land_abk"])
            except Exception as exc:
                logger.warning("Could not fetch detail for %s: %s", raw.get("aktenzeichen"), exc)
                detail_html = None
        else:
            detail_html = None

        listing = parse_listing(raw, detail_html)
        if db.is_new_or_changed(listing):
            new_listings.append(listing)

    logger.info("%d new/changed listings", len(new_listings))

    # --- Download documents ---
    for listing in new_listings:
        download_documents(listing, config.storage, config.scraper, session)

    # --- Enrich + AI ---
    for listing in new_listings:
        enrich_listing(listing)

    if config.anthropic_api_key and config.analysis.run_after_scrape:
        for listing in new_listings:
            await analyse_listing(listing, config)

    # --- Persist ---
    for listing in new_listings:
        db.upsert(listing)

    # --- Drive sync ---
    creds_file = config.storage.google_drive.credentials_file
    if creds_file.exists():
        drive = DriveClient(config.storage.google_drive)
        for listing in new_listings:
            await organise_to_drive(listing, drive, config.storage)

    # --- Reports + alerts ---
    all_listings = db.get_all()
    generate_reports(all_listings, config)
    send_alerts(new_listings, config)

    elapsed = (datetime.utcnow() - start).total_seconds()
    logger.info(
        "Pipeline complete — %d processed, %.1fs total", len(new_listings), elapsed
    )
    db.log_run(start, datetime.utcnow(), len(new_listings), len(all_listings))


def start_scheduler(config: AppConfig) -> None:
    """Start APScheduler or run once if no cron is configured."""
    cron = config.scraper.schedule_cron
    if not cron:
        logger.info("No schedule_cron configured — running pipeline once")
        asyncio.run(run_pipeline(config))
        return

    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        run_pipeline,
        CronTrigger.from_crontab(cron),
        args=[config],
        id="zvg_pipeline",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started with cron: %s", cron)

    try:
        asyncio.get_event_loop().run_forever()
    except (KeyboardInterrupt, SystemExit):
        scheduler.shutdown()
        logger.info("Scheduler stopped")
