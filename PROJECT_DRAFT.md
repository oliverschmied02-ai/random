# Zwangsversteigerungen Intelligence Platform — Project Draft

## Vision

Automated pipeline that monitors the official ZVG-Portal (zvg-portal.de),
collects all relevant foreclosure auction listings for a configurable area of
interest, persists every document and data point to Google Drive, and surfaces
investment insights through a structured analysis layer.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CONFIGURATION                                │
│   area_of_interest: [Bundesland, Amtsgericht, PLZ-range, Objekt]   │
│   schedule: cron / on-demand                                        │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────────────┐
│                     LAYER 1 — SCRAPER                              │
│                                                                    │
│   ┌─────────────┐    ┌──────────────┐    ┌──────────────────────┐ │
│   │  Session    │───▶│  Listing     │───▶│  Document            │ │
│   │  Manager   │    │  Scraper     │    │  Downloader          │ │
│   │(cookies,   │    │(search form, │    │(Gutachten PDF,       │ │
│   │ retries)   │    │ pagination)  │    │ Exposé, Fotos)       │ │
│   └─────────────┘    └──────────────┘    └──────────────────────┘ │
│                              │                       │             │
│                      raw listings JSON          binary files       │
└──────────────────────────────┬────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                     LAYER 2 — STORAGE                            │
│                                                                  │
│   ┌─────────────────────┐      ┌──────────────────────────────┐ │
│   │  Local Cache        │      │  Google Drive                │ │
│   │  (SQLite + /files)  │─────▶│  /ZVG_Data/                  │ │
│   │                     │      │    <Bundesland>/             │ │
│   │  deduplication,     │      │      <Aktenzeichen>/         │ │
│   │  delta tracking     │      │        metadata.json         │ │
│   └─────────────────────┘      │        gutachten.pdf         │ │
│                                │        expose.pdf            │ │
│                                │        fotos/                │ │
│                                │    listings.csv  (master)    │ │
│                                └──────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                     LAYER 3 — ANALYSIS                           │
│                                                                  │
│   ┌──────────────────┐   ┌─────────────────┐   ┌─────────────┐ │
│   │  Data Enrichment │   │  PDF Parser     │   │  AI Analyst │ │
│   │  - Geocoding     │   │  - extract      │   │  - LLM      │ │
│   │  - Price/sqm     │   │    Wohnfläche   │   │    summary  │ │
│   │  - Market comps  │   │    Baujahr      │   │  - red/green│ │
│   │  - Bietgrenzen   │   │    Mängel       │   │    flags    │ │
│   │    (50% / 70%)   │   │    Grundriss    │   └─────────────┘ │
│   └──────────────────┘   └─────────────────┘                   │
│                                    │                            │
│                          ┌─────────▼──────────┐                │
│                          │   Report Generator  │                │
│                          │   - Excel/CSV       │                │
│                          │   - HTML dashboard  │                │
│                          │   - Email alert     │                │
│                          └────────────────────┘                │
└──────────────────────────────────────────────────────────────────┘
```

---

## Module Breakdown

### Layer 1 — Scraper (`src/scraper/`)

| Module | Responsibility |
|---|---|
| `session.py` | Manages HTTP session, handles ZVG-portal cookies, retries, rate-limiting |
| `search.py` | Submits search form for configured area, paginates through results |
| `listing_parser.py` | Parses HTML listing rows → structured `Listing` dataclass |
| `document_downloader.py` | Downloads Gutachten PDFs, Exposés, Fotos per Aktenzeichen |
| `scheduler.py` | Cron-based or on-demand execution, tracks last-run state |

**Key search parameters (configurable):**
- `land` — Bundesland (all 16 supported)
- `gericht` — Amtsgericht (optional, narrows results)
- `plz` — Postleitzahl or range
- `objekt` — Property type filter
- `art_der_versteigerung` — Auction type

### Layer 2 — Storage (`src/storage/`)

| Module | Responsibility |
|---|---|
| `local_db.py` | SQLite: listings, run history, dedup by Aktenzeichen |
| `drive_client.py` | Google Drive API wrapper (upload, folder creation, delta sync) |
| `file_organizer.py` | Maps each Aktenzeichen → Drive folder path, manages file naming |

**Drive folder structure:**
```
ZVG_Data/
├── listings_master.csv          # all-time consolidated sheet
├── Bayern/
│   ├── AG_Muenchen/
│   │   ├── 12_K_45_24/
│   │   │   ├── metadata.json
│   │   │   ├── gutachten.pdf
│   │   │   ├── expose.pdf
│   │   │   └── fotos/
│   │   └── ...
│   └── AG_Nuernberg/
└── Baden-Wuerttemberg/
    └── ...
```

### Layer 3 — Analysis (`src/analysis/`)

| Module | Responsibility |
|---|---|
| `pdf_extractor.py` | pdfplumber extraction: Wohnfläche, Baujahr, Grundstücksgröße, Mängel |
| `enricher.py` | Geocoding (Nominatim), price-per-sqm calc, Bietgrenze 50%/70% |
| `ai_analyst.py` | Claude/GPT call: summarize Gutachten, flag risks, rate attractiveness |
| `report.py` | Generate Excel report + HTML dashboard with sortable table + map |
| `alerting.py` | Email/Telegram alert when new high-value listings appear |

---

## Data Schema

### `Listing` (core entity)

```python
@dataclass
class Listing:
    aktenzeichen: str          # "12 K 45/24"
    amtsgericht: str           # "AG München"
    bundesland: str
    termin: datetime           # auction date
    objekt_beschreibung: str   # raw text from portal
    plz: str
    ort: str
    verkehrswert: float        # EUR, cleaned to number
    art_der_versteigerung: str
    status: str                # "active" | "cancelled"
    cancellation_reason: str | None
    gutachten_url: str | None
    expose_url: str | None
    foto_urls: list[str]
    # enriched fields (Layer 3)
    wohnflaeche_sqm: float | None
    grundstueck_sqm: float | None
    baujahr: int | None
    price_per_sqm: float | None
    mindestgebot_50pct: float  # calculated
    sicherheitsgrenze_70pct: float  # calculated
    ai_summary: str | None
    ai_risk_flags: list[str]
    ai_attractiveness_score: int | None  # 1–10
    lat: float | None
    lon: float | None
    drive_folder_id: str | None
    scraped_at: datetime
    last_updated: datetime
```

---

## Tech Stack

| Component | Technology |
|---|---|
| Language | Python 3.11+ |
| HTTP / Scraping | `playwright` (session cookie handling) + `beautifulsoup4` |
| PDF Parsing | `pdfplumber` + `PyMuPDF` |
| Storage | `sqlite3` (local), Google Drive API (`google-api-python-client`) |
| Data Processing | `pandas`, `openpyxl` |
| Geocoding | `geopy` (Nominatim / OpenStreetMap) |
| AI Analysis | Anthropic Claude API (`anthropic` SDK) |
| Scheduling | `APScheduler` or GitHub Actions cron |
| Dashboard | `streamlit` (optional) or static HTML + `folium` map |
| Config | `pydantic-settings` + `.env` file |
| Testing | `pytest` + `pytest-playwright` |

---

## Configuration (`.env` / `config.yaml`)

```yaml
scraper:
  area_of_interest:
    bundesland: Bayern
    amtsgerichte: []              # empty = all courts in Bundesland
    plz_range: ["80000", "82000"] # optional PLZ filter
    objekt_types: []              # empty = all types
  schedule_cron: "0 7 * * *"     # daily at 07:00
  rate_limit_seconds: 2
  max_retries: 3

storage:
  local_db_path: ./data/zvg.db
  files_dir: ./data/files
  google_drive:
    credentials_file: ./secrets/gdrive_credentials.json
    root_folder_name: ZVG_Data

analysis:
  run_after_scrape: true
  ai_model: claude-opus-4-6
  geocoding_provider: nominatim
  alert_threshold_verkehrswert_max: 500000  # only alert below this
  alert_channel: email  # email | telegram | none

reporting:
  output_formats: [csv, excel, html]
  output_dir: ./reports
```

---

## Implementation Phases

### Phase 1 — Scraper MVP
- [ ] Session management + search form submission
- [ ] Listing HTML parser → `Listing` dataclass
- [ ] Pagination handling
- [ ] SQLite deduplication
- [ ] CLI: `python -m zvg scrape --land Bayern`

### Phase 2 — Storage & Documents
- [ ] Google Drive API integration
- [ ] Document downloader (Gutachten PDF, Fotos)
- [ ] Drive folder organizer
- [ ] Delta sync (only upload new/changed)

### Phase 3 — Analysis Layer
- [ ] PDF text extraction (Wohnfläche, Baujahr, Mängel)
- [ ] Geocoding + price-per-sqm
- [ ] Bietgrenze calculation (50% / 70%)
- [ ] Excel + HTML report generation

### Phase 4 — AI Layer
- [ ] Claude API integration for Gutachten summarization
- [ ] Risk flag extraction
- [ ] Attractiveness scoring (1–10)
- [ ] Alerting (email / Telegram) for top picks

### Phase 5 — Dashboard & Automation
- [ ] Streamlit dashboard with map view
- [ ] GitHub Actions / cron scheduling
- [ ] Automated PR/report push to Drive

---

## Key Constraints & Notes

- **No official API** — ZVG-Portal requires session cookies; Playwright is
  necessary to handle the form-based session state.
- **Coverage gap** — Hamburg and Mecklenburg-Vorpommern are not covered by
  zvg-portal.de; supplementary sources (zvg.com, zvg24.net) can be added later.
- **Rate limiting** — Respect the portal (2 s between requests); use exponential
  backoff on errors.
- **Bietgrenzen** — Legally relevant thresholds:
  - 50% of Verkehrswert = Mindestgebot (court will reject lower bids)
  - 70% of Verkehrswert = Sicherheitsgrenze (creditors can refuse sale)
- **PDF availability** — Not all courts publish Gutachten; the downloader must
  handle missing documents gracefully.
