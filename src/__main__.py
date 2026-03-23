"""
CLI entry point.

Usage:
  python -m src scrape [OPTIONS]
  python -m src analyse [OPTIONS]
  python -m src report [OPTIONS]
  python -m src schedule

Examples:
  python -m src scrape --land Bayern
  python -m src scrape --land Bayern --plz 80000-82000
  python -m src scrape --land "Nordrhein-Westfalen" --gericht "AG Köln"
  python -m src scrape --no-analyse --no-drive
  python -m src analyse --all
  python -m src report --formats csv excel html
  python -m src schedule
"""
from __future__ import annotations

import asyncio
import logging

import click
from rich.logging import RichHandler

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    handlers=[RichHandler(rich_tracebacks=True, show_path=False)],
)
logger = logging.getLogger(__name__)


@click.group()
@click.option("--config", default="config.yaml", show_default=True)
@click.option("--verbose", "-v", is_flag=True)
@click.pass_context
def cli(ctx: click.Context, config: str, verbose: bool) -> None:
    """ZVG Intelligence — Zwangsversteigerungen scraper & analyser."""
    if verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    from src.config import load_config
    ctx.ensure_object(dict)
    ctx.obj["config"] = load_config(config)


@cli.command()
@click.option("--land", help="Bundesland (overrides config.yaml)")
@click.option("--gericht", help="Amtsgericht name (overrides config.yaml)")
@click.option("--plz", help="PLZ or range e.g. '80000-82000'")
@click.option("--no-download", is_flag=True, help="Skip PDF/photo download")
@click.option("--no-drive", is_flag=True, help="Skip Google Drive upload")
@click.option("--no-r2", is_flag=True, help="Skip Cloudflare R2 upload")
@click.option("--no-analyse", is_flag=True, help="Skip AI analysis")
@click.pass_context
def scrape(
    ctx: click.Context,
    land: str | None,
    gericht: str | None,
    plz: str | None,
    no_download: bool,
    no_drive: bool,
    no_r2: bool,
    no_analyse: bool,
) -> None:
    """Scrape ZVG Portal and process listings."""
    config = ctx.obj["config"]

    if land:
        config.scraper.area_of_interest.bundesland = land
    if gericht:
        config.scraper.area_of_interest.amtsgerichte = [gericht]
    if plz:
        if "-" in plz:
            start, end = plz.split("-", 1)
            # Collect representative PLZ values across the range (every 100)
            config.scraper.area_of_interest.plz_range = [
                str(p) for p in range(int(start), int(end) + 1, 100)
            ]
        else:
            config.scraper.area_of_interest.plz_range = [plz]

    asyncio.run(
        _run_scrape(
            config,
            no_download=no_download,
            no_drive=no_drive,
            no_r2=no_r2,
            no_analyse=no_analyse,
        )
    )


@cli.command()
@click.option("--all", "run_all", is_flag=True, help="Re-analyse all listings in DB")
@click.pass_context
def analyse(ctx: click.Context, run_all: bool) -> None:
    """Run PDF extraction + AI analysis on saved listings."""
    config = ctx.obj["config"]
    asyncio.run(_run_analyse(config, run_all=run_all))


@cli.command()
@click.option(
    "--formats", multiple=True,
    default=["csv", "excel", "html"],
    show_default=True,
)
@click.pass_context
def report(ctx: click.Context, formats: tuple[str, ...]) -> None:
    """Generate reports from the local database."""
    config = ctx.obj["config"]
    config.reporting.output_formats = list(formats)
    _run_report(config)


@cli.command()
@click.pass_context
def schedule(ctx: click.Context) -> None:
    """Start the cron scheduler (uses schedule_cron from config.yaml)."""
    from src.scraper.scheduler import start_scheduler
    start_scheduler(ctx.obj["config"])


# ---------------------------------------------------------------------------
# Pipeline helpers
# ---------------------------------------------------------------------------

async def _run_scrape(
    config, no_download: bool, no_drive: bool, no_r2: bool, no_analyse: bool
) -> None:
    from src.scraper.session import make_session, fetch_detail_page
    from src.scraper.search import fetch_all_listings
    from src.scraper.listing_parser import parse_listing
    from src.scraper.document_downloader import download_documents
    from src.storage.local_db import ListingDB
    from src.storage.drive_client import DriveClient
    from src.storage.file_organizer import organise_to_drive, organise_to_r2
    from src.storage.r2_client import R2Client, push_db
    from src.analysis.enricher import enrich_listing
    from src.analysis.ai_analyst import analyse_listing
    from src.analysis.report import generate_reports
    from src.analysis.alerting import send_alerts

    db = ListingDB(config.storage.local_db_path)
    db.init()

    session = make_session(config.scraper)
    raw_listings = fetch_all_listings(config.scraper.area_of_interest, config.scraper)
    logger.info("Scraped %d listings from portal", len(raw_listings))

    new_listings = []
    for raw in raw_listings:
        detail_html = None
        if raw.get("zvg_id") and raw.get("land_abk"):
            try:
                detail_html = fetch_detail_page(session, raw["zvg_id"], raw["land_abk"])
            except Exception as exc:
                logger.warning("Detail fetch failed for %s: %s", raw.get("aktenzeichen"), exc)

        listing = parse_listing(raw, detail_html)
        if db.is_new_or_changed(listing):
            new_listings.append(listing)

    logger.info("%d new/changed listings to process", len(new_listings))

    if not no_download:
        for listing in new_listings:
            download_documents(listing, config.storage, config.scraper, session)
        # Also retry missing downloads for already-known listings
        for listing in db.get_all():
            if (listing.gutachten_url and not listing.gutachten_local_path) or \
               (listing.expose_url and not listing.expose_local_path):
                download_documents(listing, config.storage, config.scraper, session)
                db.upsert(listing)

    for listing in new_listings:
        enrich_listing(listing)

    if not no_analyse and config.anthropic_api_key:
        for listing in new_listings:
            await analyse_listing(listing, config)

    for listing in new_listings:
        db.upsert(listing)

    if not no_drive:
        creds_file = config.storage.google_drive.credentials_file
        if creds_file.exists():
            drive = DriveClient(config.storage.google_drive)
            for listing in new_listings:
                await organise_to_drive(listing, drive, config.storage)
        else:
            logger.info("No Drive credentials found — skipping Drive sync")

    # Cloudflare R2 upload
    r2_cfg = config.storage.r2
    r2: R2Client | None = None
    if not no_r2 and r2_cfg.enabled and r2_cfg.account_id and r2_cfg.access_key_id:
        try:
            r2 = R2Client(
                account_id=r2_cfg.account_id,
                access_key_id=r2_cfg.access_key_id,
                secret_access_key=r2_cfg.secret_access_key,
                bucket_name=r2_cfg.bucket_name,
                public_url_base=r2_cfg.public_url,
            )
            for listing in new_listings:
                organise_to_r2(listing, r2)
                db.upsert(listing)
            logger.info("R2 sync complete")
        except Exception as exc:
            logger.warning("R2 upload failed: %s", exc)
    elif not no_r2 and not r2_cfg.enabled:
        logger.debug("R2 not configured — skipping (set storage.r2.enabled: true in config.yaml)")

    all_listings = db.get_all()
    generate_reports(all_listings, config)
    send_alerts(new_listings, config)

    # Persist DB to R2 for ephemeral servers (Render free tier)
    if r2 is not None:
        try:
            push_db(r2, config.storage.local_db_path)
        except Exception as exc:
            logger.warning("R2 DB backup failed: %s", exc)

    logger.info("Done. Processed %d listings.", len(new_listings))


async def _run_analyse(config, run_all: bool) -> None:
    from src.storage.local_db import ListingDB
    from src.analysis.enricher import enrich_listing
    from src.analysis.ai_analyst import analyse_listing

    db = ListingDB(config.storage.local_db_path)
    db.init()
    listings = db.get_all()

    if not run_all:
        listings = [l for l in listings if l.ai_attractiveness_score is None]

    logger.info("Analysing %d listings", len(listings))
    for listing in listings:
        enrich_listing(listing)
        if config.anthropic_api_key:
            await analyse_listing(listing, config)
        db.upsert(listing)
    logger.info("Analysis complete")


def _run_report(config) -> None:
    from src.storage.local_db import ListingDB
    from src.analysis.report import generate_reports

    db = ListingDB(config.storage.local_db_path)
    db.init()
    listings = db.get_all()
    paths = generate_reports(listings, config)
    for fmt, path in paths.items():
        logger.info("[%s] %s", fmt.upper(), path)


if __name__ == "__main__":
    cli(obj={})
