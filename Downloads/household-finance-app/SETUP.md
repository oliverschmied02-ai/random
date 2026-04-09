# Household Finance Dashboard - Setup Guide

A personal finance dashboard for managing household finances with N26 bank transactions, Google Sheets integration, and automatic categorization.

## Quick Start (5-10 minutes)

### 1. Install Dependencies

```bash
cd household-finance-app
pip install -r requirements.txt
```

### 2. Get Google Sheets API Credentials

#### Step A: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project: `Household Finance` (or any name)
3. Once created, select your project

#### Step B: Enable Google Sheets API
1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Google Sheets API"
3. Click it and press **Enable**

#### Step C: Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth Client ID**
3. Choose **Desktop application**
4. Download the JSON file
5. Rename it to `credentials.json` and place in the `household-finance-app` folder

Your folder should now look like:
```
household-finance-app/
├── app.py
├── credentials.json    ← Put this here
├── requirements.txt
├── templates/
│   ├── base.html
│   ├── index.html
│   └── dashboard.html
└── SETUP.md
```

### 3. Create Your Google Sheet

1. Go to [Google Sheets](https://sheets.google.com)
2. Click **+ Create new spreadsheet**
3. Name it: `Household Finance 2026` (or whatever)
4. The app will automatically create the sheet structure on first use, OR you can manually create these tabs:
   - Transaktionen (Transactions)
   - Debitoren (Partner mappings)
   - GuV (P&L statement)
   - Tilgungsplan (Loan schedule)
   - Bilanz (Balance sheet)
   - Haushaltsrechnung (Budget tracker)
   - Dashboard (Summary)

5. Get your **Spreadsheet ID** from the URL:
   ```
   docs.google.com/spreadsheets/d/YOUR_ID_HERE/edit
   ```
   Save this ID - you'll need it in the app!

### 4. Run the App

```bash
python app.py
```

You should see:
```
 * Running on http://127.0.0.1:5000
```

Open in your browser: **http://localhost:5000**

### 5. First Time Use

1. Click **"Connect Google Sheets"** on the home page
2. You'll be directed to Google login
3. Approve access to Google Sheets
4. You're authenticated! ✅

### 6. Upload Your First CSV

1. Export N26 transactions as CSV (your bank → Download → CSV)
2. Go to **"Upload Transactions"** on the dashboard
3. Paste your **Google Sheet ID** (from step 3.5)
4. Drag & drop the CSV file
5. Review the transactions and select categories
6. Click **"Save to Google Sheets"**
7. Your transactions are now in Google Sheets! 📊

---

## Category Options

When categorizing, you can use these default categories:

- **Groceries** - Supermarkets, food stores
- **Transport** - Gas, public transit, taxis (Bolt, etc.)
- **Utilities** - Electricity, water, internet, phone
- **Insurance** - Health, liability, property insurance
- **Healthcare** - Doctor visits, pharmacy (Apotheke)
- **Entertainment** - Events, movies, subscriptions
- **Dining** - Restaurants, cafes
- **Shopping** - Clothing, electronics, Amazon
- **Salary** - Income from employment
- **Transfer** - Money transfers between accounts
- **Other** - Everything else

You can add more categories in the dashboard.html file's category select.

---

## Add to Google Sheets (Optional)

The app writes to the **Transaktionen** sheet. Make sure the headers are:

```
| Booking Date | Value Date | Partner Name | Category | Amount (EUR) | Type | Payment Reference |
```

Your existing formulas in **GuV**, **Bilanz**, **Dashboard** etc. will automatically pull from this sheet.

---

## Next Steps

### Add More Sheets
To add P&L, Balance Sheet, Budget tracking formulas, manually create them in Google Sheets with SUMIFS() formulas that reference the Transaktionen sheet.

### Add LLM Auto-Categorization
To enable Claude API auto-categorization (instead of manual dropdown):
1. Get a Claude API key from [Anthropic](https://console.anthropic.com)
2. Modify `app.py` to call the Claude API for category suggestions
3. Return suggested categories in the preview

### Customize App
- Edit `templates/base.html` to change colors/branding
- Edit `templates/dashboard.html` to add/remove category options
- Modify `app.py` to add new features (loan tracking, net worth, etc.)

---

## Troubleshooting

### "Authorization failed" or "credentials.json not found"
- Make sure `credentials.json` is in the `household-finance-app` folder
- Delete `token.json` if it exists and try again

### "Spreadsheet not found"
- Copy your Sheet ID correctly from the URL
- Make sure the Google Sheet is shared with your Google account

### "CSV parsing error"
- Make sure your CSV is from N26 (check the columns match)
- Try opening the CSV in Excel to ensure it's valid

### Port 5000 already in use
```bash
python app.py --port 5001
```

---

## File Structure

```
household-finance-app/
├── app.py                 # Main Flask application
├── credentials.json       # Google API credentials (create manually)
├── token.json            # Auto-generated after first login (don't edit)
├── requirements.txt      # Python dependencies
├── SETUP.md             # This file
└── templates/
    ├── base.html        # Base HTML template
    ├── index.html       # Home page
    └── dashboard.html   # Upload & categorization page
```

---

## Security Notes

- ⚠️ **Don't share `credentials.json`** - it's your auth key
- ⚠️ **Change `app.secret_key` in app.py** to a random string in production
- ⚠️ Keep your Google Sheets private or share only with trusted people
- The app stores financial data in Google Sheets (encrypted in transit by Google)

---

## Getting Help

If you run into issues:
1. Check that Python 3.8+ is installed: `python --version`
2. Make sure all dependencies installed: `pip install -r requirements.txt`
3. Check browser console (F12) for JavaScript errors
4. Check Flask console output for backend errors

---

Enjoy your financial dashboard! 💰
