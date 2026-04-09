# Household Finance Dashboard

A personal finance management system that syncs N26 bank transactions with Google Sheets, enables easy categorization, and auto-populates financial statements (P&L, balance sheet, loan tracking).

## Features

✅ **N26 CSV Upload** - Import transactions directly from your N26 bank exports  
✅ **Smart Categorization** - Auto-suggest categories based on partner names, with manual override  
✅ **Google Sheets Sync** - All data lives in Google Sheets (cloud, shareable, collaborative)  
✅ **Auto-Formulas** - Your P&L, balance sheet, and dashboards auto-update with every upload  
✅ **Loan Tracking** - Variable repayment schedules for multiple loans  
✅ **Net Worth Tracking** - Balance sheet for assets & liabilities  
✅ **Budget vs. Actual** - Compare budgeted vs actual spending  

## Architecture

```
┌─────────────────┐
│   N26 CSV       │
│   (Download)    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│   Flask Web App             │
│   - Upload CSV              │
│   - Parse N26 format        │
│   - Show categorization UI  │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│   Google Sheets API         │
│   - Write transactions      │
│   - Read existing categories│
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│   Google Sheets                 │
│   ├─ Transaktionen (transactions)
│   ├─ Debitoren (category mapping)
│   ├─ GuV (P&L statement)        │
│   ├─ Tilgungsplan (loan tracking)
│   ├─ Bilanz (balance sheet)     │
│   ├─ Haushaltsrechnung (budget) │
│   └─ Dashboard (summary)        │
└─────────────────────────────────┘
```

## Quick Start

### Prerequisites
- Python 3.8+
- Google Account
- N26 Bank Account (or compatible CSV format)

### Installation

1. **Clone/Download** the app
   ```bash
   cd household-finance-app
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set up Google API** (see [SETUP.md](SETUP.md) for detailed steps)
   - Create Google Cloud Project
   - Enable Google Sheets API
   - Download credentials as `credentials.json`
   - Place in app folder

4. **Run the app**
   ```bash
   python app.py
   ```
   Visit: http://localhost:5000

5. **Create Google Sheet**
   - Run: `python create_sheets_template.py` (auto-creates structure)
   - OR create manually with sheets: Transaktionen, Debitoren, GuV, etc.

6. **Upload your first CSV**
   - Export N26 transactions as CSV
   - Upload via web interface
   - Categorize transactions
   - View in Google Sheets ✅

---

## File Organization

```
household-finance-app/
├── app.py                      # Main Flask application
├── create_sheets_template.py   # Auto-creates Google Sheet structure
├── requirements.txt            # Python dependencies
├── SETUP.md                    # Detailed setup guide
├── README.md                   # This file
├── .env.example               # Environment variables template
├── credentials.json            # Google API credentials (create yourself)
├── token.json                 # Auto-generated auth token (don't touch)
└── templates/
    ├── base.html              # Base HTML layout
    ├── index.html             # Home page
    └── dashboard.html         # Upload & categorize page
```

---

## Usage Workflow

### Monthly Process

1. **Download CSV from N26**
   - N26 App → Accounts → Download → CSV
   - Or Transactions → Select Period → Export

2. **Upload to Dashboard**
   - Go to http://localhost:5000
   - Click "Upload Transactions"
   - Paste your Google Sheet ID
   - Upload CSV file

3. **Review & Categorize**
   - System shows transactions
   - Select category for each (or override defaults)
   - Click "Save to Google Sheets"

4. **View Your Dashboard**
   - Google Sheet auto-updates
   - Formulas in GuV, Bilanz, Dashboard populate
   - Share with partner (optional)

---

## Category Guide

When categorizing transactions, use these common categories:

| Category | Examples |
|----------|----------|
| **Groceries** | ALDI, Rewe, Edeka, grocery stores |
| **Transport** | Bolt, Uber, fuel, public transit |
| **Utilities** | Electricity, water, internet, phone bill |
| **Insurance** | Health insurance, liability, property |
| **Healthcare** | Apotheke (pharmacy), doctor visits |
| **Entertainment** | Cinema, concerts, subscriptions (Netflix) |
| **Dining** | Restaurants, cafes, fast food |
| **Shopping** | Clothing, electronics, Amazon |
| **Salary** | Income from job/freelance |
| **Transfer** | Transfers between your accounts |
| **Other** | Catch-all for uncategorized |

You can add more categories by editing `templates/dashboard.html`.

---

## Google Sheets Setup

### Manual Sheet Creation

If you prefer to create sheets manually instead of running `create_sheets_template.py`:

1. Create new Google Sheet at sheets.google.com
2. Rename default sheet to "Transaktionen"
3. Add headers:
   ```
   A: Booking Date
   B: Value Date
   C: Partner Name
   D: Category
   E: Amount (EUR)
   F: Type
   G: Payment Reference
   ```

4. Add other sheets:
   - Debitoren (Partner Name | Category)
   - GuV (P&L statement - create your own formulas)
   - Tilgungsplan (Loan schedule)
   - Bilanz (Balance sheet)
   - Haushaltsrechnung (Budget tracking)
   - Dashboard (Summary KPIs)

5. Copy Spreadsheet ID from URL:
   ```
   docs.google.com/spreadsheets/d/YOUR_ID_HERE/edit
   ```

### Example Formulas for GuV (P&L)

In Google Sheets, use SUMIFS to calculate by category:

```
=SUMIFS(Transaktionen!E:E, Transaktionen!D:D, "Salary", Transaktionen!A:A, ">="&DATE(2026,1,1), Transaktionen!A:A, "<="&DATE(2026,12,31))
```

This sums all "Salary" amounts in 2026.

---

## Customization

### Add Custom Categories

Edit `templates/dashboard.html`, line ~110:

```html
<option value="Groceries">Groceries</option>
<option value="MyCustomCategory">My Custom Category</option>
```

### Change Port

Run: `python app.py --port 8080`

### Change App Secret

Edit `app.py`, line 14:

```python
app.secret_key = 'your-new-random-secret-key'
```

### Add Claude API Auto-Categorization

1. Get Claude API key from [Anthropic](https://console.anthropic.com)
2. Modify `app.py` to call Claude API for suggestions
3. Return suggested categories in `/api/upload-csv` response

Example:
```python
import anthropic

client = anthropic.Anthropic(api_key='your-key')
message = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": f"Categorize this: {partner_name}"}]
)
```

---

## Troubleshooting

### "Authentication failed"
- Delete `token.json`
- Make sure `credentials.json` exists
- Run `python app.py` and click "Connect" again

### "Cannot find spreadsheet"
- Copy Spreadsheet ID correctly from URL
- Share sheet with your Google account

### "CSV format error"
- Verify CSV is from N26 (columns must match)
- Open in Excel to check formatting

### Port 5000 already in use
```bash
python app.py --port 5001
```

### Python module not found
```bash
pip install -r requirements.txt
```

---

## Security & Privacy

🔒 **Local Processing** - All CSV parsing happens locally, not on servers  
🔒 **Google Sheets** - Data stored in your Google Sheets (Google's encryption)  
🔒 **Credentials** - Credentials file is only for your own Google API access  

⚠️ **Important**:
- Don't share `credentials.json`
- Don't commit credentials to git
- Keep Google Sheet private or share carefully
- Change `app.secret_key` before production deployment

---

## Future Enhancements

- [ ] LLM auto-categorization via Claude API
- [ ] Web UI for updating Tilgungsplan (loan schedules)
- [ ] Multi-account support (multiple N26 accounts)
- [ ] Budget alerts (spending exceeds limit)
- [ ] Monthly/yearly reports
- [ ] Mobile app
- [ ] Cloud deployment (Heroku, Render)
- [ ] Recurring transaction rules

---

## Support

For issues or questions:
1. Check [SETUP.md](SETUP.md) for detailed instructions
2. Check browser console (F12) for errors
3. Check Flask console output
4. Verify `credentials.json` and `token.json` exist

---

**Happy budgeting!** 💰📊
