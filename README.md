# ZVG Intelligence Platform

Automated pipeline that monitors [zvg-portal.de](https://www.zvg-portal.de),
collects all Zwangsversteigerung listings for a configurable area, persists
every document to Google Drive, and surfaces investment insights via AI analysis.

## Architecture

```
ZVG Portal → Scraper → SQLite Cache → Google Drive
                                  ↓
                          Analysis Layer
                          ├── PDF Extraction (Wohnfläche, Baujahr …)
                          ├── Geocoding (lat/lon)
                          ├── AI Analysis (Claude — summary, score, risk flags)
                          └── Reports (CSV, Excel, HTML dashboard)
```

## Quick Start

### 1. Install dependencies

```bash
pip install -r requirements.txt
playwright install chromium
```

### 2. Configure

```bash
cp .env.example .env
# Edit .env: add ANTHROPIC_API_KEY and optionally alert credentials
# Edit config.yaml: set bundesland, PLZ range, schedule
```

### 3. Run

```bash
# One-time scrape for Bayern
python -m src scrape --land Bayern

# Scrape specific PLZ range
python -m src scrape --land Bayern --plz 80000-82000

# Scrape specific court
python -m src scrape --land Bayern --gericht "AG München"

# Scrape without AI analysis or Drive upload
python -m src scrape --no-analyse --no-drive

# Re-run AI analysis on all saved listings
python -m src analyse --all

# Regenerate reports from local database
python -m src report --formats csv excel html

# Start scheduled scraper (uses cron from config.yaml)
python -m src schedule
```

### 4. Google Drive Setup (optional)

1. Create a Google Cloud project and enable the Drive API
2. Create OAuth2 credentials (or a service account)
3. Download the credentials JSON to `secrets/gdrive_credentials.json`
4. On first run, a browser window will open to authorize access

### 5. Docker

```bash
docker build -t zvg-intelligence .
docker run -v $(pwd)/data:/app/data \
           -v $(pwd)/secrets:/app/secrets \
           -v $(pwd)/reports:/app/reports \
           --env-file .env \
           zvg-intelligence
```

## Output

| Format | Location |
|---|---|
| SQLite DB | `data/zvg.db` |
| Downloaded PDFs | `data/files/<Bundesland>/<Gericht>/<Aktenzeichen>/` |
| CSV report | `reports/listings_master.csv` |
| Excel report | `reports/zvg_report_YYYYMMDD.xlsx` |
| HTML dashboard | `reports/dashboard.html` |
| Google Drive | `ZVG_Data/<Bundesland>/<Gericht>/<Aktenzeichen>/` |

## Configuration

See [`config.yaml`](config.yaml) for all options.
See [`.env.example`](.env.example) for required environment variables.

## Bietgrenzen Reference

| Threshold | Calculation | Meaning |
|---|---|---|
| Mindestgebot | Verkehrswert × 50% | Court rejects lower bids |
| Sicherheitsgrenze | Verkehrswert × 70% | Creditors can veto sale |
| Target range | 50%–70% of Verkehrswert | Ideal buy zone |

## Coverage Note

Hamburg and Mecklenburg-Vorpommern are **not covered** by zvg-portal.de.
