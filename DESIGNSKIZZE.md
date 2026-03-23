# Designskizze — ZVG Intelligence Platform

## Data Flow (End-to-End)

```
  USER INPUT
  ──────────
  Bundesland: Bayern
  PLZ-Range:  80000–82000
  Schedule:   daily 07:00
       │
       ▼
  ┌────────────────────────────────────────────────────────┐
  │  SCRAPER                                               │
  │                                                        │
  │  1. Open zvg-portal.de with Playwright                │
  │  2. Submit Suche form (Land → Gericht → Filter)       │
  │  3. Parse result table (HTML rows → Listing objects)  │
  │  4. For each Listing: click Aktenzeichen              │
  │     → grab detail page                                │
  │     → collect PDF links (Gutachten, Exposé, Fotos)   │
  │  5. Download all files                                 │
  │  6. Check SQLite: already seen? → skip                │
  └───────────────────┬────────────────────────────────────┘
                      │  new listings only
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │  LOCAL CACHE  (SQLite + /data/files/)                  │
  │                                                        │
  │  listings table                                        │
  │  ┌──────────────┬──────────┬──────────┬─────────────┐ │
  │  │ aktenzeichen │ termin   │ verkehrs │ status      │ │
  │  │ 12 K 45/24  │ 2024-... │  380000  │ active      │ │
  │  │ 8 K 12/24   │ 2024-... │  220000  │ cancelled   │ │
  │  └──────────────┴──────────┴──────────┴─────────────┘ │
  └───────────────────┬────────────────────────────────────┘
                      │  upload delta
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │  GOOGLE DRIVE                                          │
  │                                                        │
  │  ZVG_Data/                                             │
  │  ├── listings_master.csv                               │
  │  └── Bayern/                                           │
  │      └── AG_Muenchen/                                  │
  │          └── 12_K_45_24/                               │
  │              ├── metadata.json   ← all structured data │
  │              ├── gutachten.pdf                         │
  │              ├── expose.pdf                            │
  │              └── fotos/                                │
  │                  ├── 01.jpg                            │
  │                  └── 02.jpg                            │
  └───────────────────┬────────────────────────────────────┘
                      │  trigger analysis
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │  ANALYSIS LAYER                                        │
  │                                                        │
  │  ① PDF Extraction (pdfplumber)                        │
  │     → Wohnfläche, Baujahr, Grundstücksgröße           │
  │     → Mängel / Schäden text blocks                    │
  │     → Grundriss vorhanden? (yes/no)                   │
  │                                                        │
  │  ② Enrichment                                         │
  │     → Geocode PLZ+Ort → lat/lon                       │
  │     → Price per sqm = Verkehrswert / Wohnfläche       │
  │     → Mindestgebot   = Verkehrswert × 0.50            │
  │     → Sicherheitsgrenze = Verkehrswert × 0.70         │
  │                                                        │
  │  ③ AI Analysis (Claude API)                           │
  │     Input:  Gutachten text + metadata                  │
  │     Output:                                            │
  │       - 3-sentence summary                            │
  │       - Risk flags: ["Schäden am Dach", "Altlasten"]  │
  │       - Attractiveness score: 7/10                    │
  │       - Recommended max bid: 310.000 €                │
  │                                                        │
  │  ④ Report Generation                                  │
  │     → listings_report.xlsx  (sortable, color-coded)   │
  │     → dashboard.html        (map + table)             │
  │     → alert email/Telegram  (top picks only)          │
  └───────────────────┬────────────────────────────────────┘
                      │
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │  OUTPUT                                                │
  │                                                        │
  │  Google Drive:  ZVG_Data/reports/2024-11-15_report.*  │
  │  Email alert:   "3 neue interessante Objekte gefunden" │
  │  Dashboard:     localhost:8501 (Streamlit)             │
  └────────────────────────────────────────────────────────┘
```

---

## Folder Structure

```
zvg-intelligence/
├── src/
│   ├── scraper/
│   │   ├── __init__.py
│   │   ├── session.py          # Playwright session + cookie mgmt
│   │   ├── search.py           # Form submission + pagination
│   │   ├── listing_parser.py   # HTML → Listing dataclass
│   │   ├── document_downloader.py
│   │   └── scheduler.py
│   ├── storage/
│   │   ├── __init__.py
│   │   ├── local_db.py         # SQLite ORM
│   │   ├── drive_client.py     # Google Drive API
│   │   └── file_organizer.py
│   ├── analysis/
│   │   ├── __init__.py
│   │   ├── pdf_extractor.py
│   │   ├── enricher.py
│   │   ├── ai_analyst.py       # Claude API calls
│   │   ├── report.py
│   │   └── alerting.py
│   ├── models/
│   │   └── listing.py          # Listing dataclass + Pydantic schema
│   └── config.py               # pydantic-settings config loader
├── tests/
│   ├── test_parser.py
│   ├── test_enricher.py
│   └── fixtures/               # sample HTML + PDF fixtures
├── data/                       # gitignored local cache
│   ├── zvg.db
│   └── files/
├── reports/                    # gitignored output
├── secrets/                    # gitignored credentials
│   └── gdrive_credentials.json
├── config.yaml                 # area + schedule configuration
├── .env                        # API keys
├── requirements.txt
├── Dockerfile
└── README.md
```

---

## Key Decisions & Trade-offs

| Decision | Choice | Rationale |
|---|---|---|
| Scraping engine | Playwright (not requests) | ZVG portal uses session state + form POST that bare requests cannot reliably replicate |
| Storage backend | Google Drive | Directly accessible to non-technical stakeholders; no server needed |
| Local cache | SQLite | Zero-dependency deduplication and run history without a separate DB server |
| PDF parsing | pdfplumber | Best text-layer extraction for scanned German PDFs |
| AI model | Claude claude-opus-4-6 | Long-context Gutachten (often 50–100 pages) benefit from large context window |
| Dashboard | Streamlit (optional) | Fastest path to interactive UI; can be swapped for plain HTML if no server |
| Alerting | Email + Telegram | Telegram bot is free, instant, and easy to set up |

---

## Bietgrenze Quick-Reference

```
Verkehrswert (Gutachtenwert)
         │
         ├── × 0.50 → Mindestgebot       court rejects lower bids automatically
         ├── × 0.70 → Sicherheitsgrenze  creditors can veto the sale below this
         └── × 1.00 → Verkehrswert       starting reference for "fair value"

Ideal purchase range: 50%–70% of Verkehrswert
```

---

## MVP Scope (Phase 1 + 2)

Minimum viable product delivers:

1. `python -m zvg scrape --land Bayern --plz 80000-82000`
2. All listings saved to SQLite + Google Drive CSV
3. Gutachten PDFs downloaded and organized in Drive
4. Delta run: only new/changed listings are uploaded

Everything in Phase 3–5 is additive and can be developed iteratively.
