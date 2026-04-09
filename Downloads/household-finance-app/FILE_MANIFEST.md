# File Manifest & Architecture

Complete breakdown of every file in the Household Finance Dashboard app.

## Core Application Files

### `app.py` (350 lines)
**Main Flask application**
- Handles HTTP routes (upload, categorize, login)
- Google Sheets API integration
- N26 CSV parsing
- Error handling & logging
- Session management

**Key Routes:**
- `GET /` - Home page
- `GET /login` - Google OAuth login
- `GET /dashboard` - Transaction upload page
- `POST /api/upload-csv` - Parse CSV file
- `POST /api/categorize` - Save categorized transactions
- `GET /api/debitoren` - Get category mappings

### `requirements.txt`
Python package dependencies:
- **Flask 3.0.0** - Web framework
- **google-auth-oauthlib 1.2.0** - Google OAuth
- **google-api-python-client 2.104.0** - Google Sheets API
- **pandas 2.0.3** - CSV parsing
- **python-dotenv 1.0.0** - Environment variables

---

## Configuration Files

### `.env.example`
Template for environment variables (optional)
- FLASK_ENV
- FLASK_DEBUG
- SECRET_KEY
- SPREADSHEET_ID
- CATEGORIES

Copy to `.env` and customize if needed.

### `.gitignore`
Prevents accidentally committing sensitive files:
- credentials.json
- token.json
- .env
- __pycache__/
- .vscode/
- *.log

---

## Setup & Documentation

### `SETUP.md` (120 lines)
**Detailed setup guide for first-time users**
- Prerequisites
- Step-by-step installation
- Google API credential setup
- Running the app
- First upload walkthrough
- Category reference
- Troubleshooting

### `README.md` (300+ lines)
**Complete project documentation**
- Features overview
- Architecture diagram
- Installation instructions
- Usage workflow
- Customization options
- Security notes
- Future enhancements

### `TROUBLESHOOTING.md` (400+ lines)
**Problem diagnosis & solutions**
- 15 common issues with solutions
- Error message explanations
- Platform-specific fixes
- Last resort troubleshooting

### `FILE_MANIFEST.md` (this file)
**Complete file documentation**
- Purpose of each file
- Line counts
- Dependencies
- Key functions

---

## HTML Templates

### `templates/base.html` (70 lines)
**Base template for all pages**
- Navigation header
- Styling (CSS)
- Flash message display
- Template blocks for page-specific content

**CSS Classes:**
- `.container` - Main content wrapper
- `.card` - Content card styling
- `.button-group` - Button grouping
- `.table` - Table styling

### `templates/index.html` (50 lines)
**Home page**
- Welcome message
- Feature list
- First-time setup guide
- "Connect Google Sheets" button

### `templates/dashboard.html` (180 lines)
**Transaction upload & categorization**
- Drag-drop file upload
- CSV preview (first 10 transactions)
- Category selection dropdown
- Amount formatting (EUR)
- Save to Google Sheets button
- JavaScript client-side handling

**JavaScript Functions:**
- `handleFileUpload()` - Upload CSV
- `showPreview()` - Display transactions
- `saveTransactions()` - Send to backend
- `showMessage()` - Display status

---

## Utility Scripts

### `create_sheets_template.py` (100 lines)
**Automated Google Sheet creation**
- Authenticates with Google
- Creates new spreadsheet
- Creates 7 sheets (Transaktionen, Debitoren, GuV, etc.)
- Adds headers to Transaktionen & Debitoren
- Prints spreadsheet ID for user

**Run:**
```bash
python create_sheets_template.py
```

### `quick_start.sh` (60 lines)
**Bash script for quick setup (macOS/Linux)**
- Checks Python installation
- Installs dependencies
- Verifies credentials.json
- Offers to create Google Sheet
- Starts Flask app

**Run:**
```bash
chmod +x quick_start.sh
./quick_start.sh
```

---

## Runtime Files (Auto-Generated)

### `token.json`
**Google OAuth2 authentication token**
- Auto-created after first login
- Don't modify or share
- Safe to delete (will regenerate)
- Contains encrypted credentials

### `credentials.json`
**Google API OAuth2 credentials**
- You must create/download this from Google Cloud Console
- Contains OAuth client ID & secret
- Required for authentication
- Safe to share only if it's an OAuth credential (not a service account key)

---

## Data Flow Architecture

```
┌─────────────────┐
│   N26 CSV       │ User downloads from N26 bank
└────────┬────────┘
         │
         ▼
┌──────────────────────────┐
│  Flask App (app.py)      │
│  ├─ Parse CSV            │
│  ├─ Show categorization  │
│  └─ Validate data        │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Google Sheets API       │
│  ├─ Authenticate         │
│  ├─ Verify sheet exists  │
│  └─ Append rows          │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Google Sheets (Cloud)   │
│  ├─ Transaktionen (data) │
│  ├─ Debitoren (mapping)  │
│  ├─ GuV (P&L formulas)   │
│  ├─ Bilanz (formulas)    │
│  └─ Dashboard (summary)  │
└──────────────────────────┘
```

---

## Key Functions

### app.py Functions

**GoogleSheetsHandler class:**
- `authenticate()` - OAuth2 login with Google
- `create_spreadsheet()` - Creates new Google Sheet
- `append_transactions()` - Writes data to sheet
- `verify_spreadsheet()` - Checks sheet exists
- `get_debitoren_mapping()` - Loads category suggestions

**Flask Routes:**
- `index()` - Renders home page
- `login()` - Google OAuth2 flow
- `dashboard()` - Shows upload interface
- `upload_csv()` - Parses CSV file
- `categorize()` - Saves transactions
- `get_debitoren()` - Returns category mappings

### create_sheets_template.py Functions

- `authenticate()` - OAuth2 with Google
- `create_sheet()` - Creates Google Sheet structure
- `main()` - Orchestrates setup

---

## File Sizes & Dependencies

| File | Size | Dependencies |
|------|------|---|
| app.py | ~350 lines | Flask, Google Sheets API, pandas |
| create_sheets_template.py | ~100 lines | Google API |
| templates/dashboard.html | ~180 lines | app.py, Google Sheets |
| templates/index.html | ~50 lines | CSS (base.html) |
| templates/base.html | ~70 lines | None |
| requirements.txt | 6 packages | PyPI |
| SETUP.md | ~120 lines | External links |
| README.md | ~300 lines | External links |
| TROUBLESHOOTING.md | ~400 lines | N/A |

---

## Security Considerations

### Files to Protect
- ⚠️ `credentials.json` - **NEVER share**
- ⚠️ `token.json` - Personal auth token (delete if compromised)

### Files Safe to Share
- ✅ All .py files (source code)
- ✅ All .md files (documentation)
- ✅ templates/*.html (frontend)
- ✅ requirements.txt

### Files to Ignore in Git
All files in `.gitignore`:
- `credentials.json`
- `token.json`
- `.env`
- `__pycache__/`
- `.vscode/`
- `*.log`

---

## Extension Points

### Where to Add Features

**Add new categories:**
```html
<!-- templates/dashboard.html, line ~110 -->
<option value="MyCategory">My Category</option>
```

**Add LLM categorization:**
```python
# app.py - in upload_csv() route
# Call Claude API for suggestions
# Return in response
```

**Add loan tracking:**
```python
# New route in app.py
@app.route('/api/loans', methods=['POST'])
def add_loan():
    # Write to Tilgungsplan sheet
```

**Add balance sheet updates:**
```python
# In categorize() route
# After writing transactions
# Write net worth to Bilanz
```

---

## Testing the App

**Manual Testing Checklist:**

- [ ] Python & dependencies install
- [ ] App starts without errors
- [ ] Home page loads
- [ ] Google OAuth login works
- [ ] CSV upload parses correctly
- [ ] Categories display in dropdown
- [ ] Transactions save to Google Sheet
- [ ] Google Sheet updates in real-time
- [ ] Repeated uploads don't cause duplicates
- [ ] Error messages display correctly

**Test CSV:** Use the sample N26 file provided (f1ad4b25-7cbf-4d35-821d-68a051f4713f (2).csv)

---

End of File Manifest
