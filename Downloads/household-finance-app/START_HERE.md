# 🚀 START HERE - Household Finance Dashboard

Welcome! This is your personal household finance management tool. Follow this guide to get up and running in **5-10 minutes**.

---

## What This Does

✅ **Upload N26 bank transactions** from CSV  
✅ **Categorize transactions** (groceries, utilities, salary, etc.)  
✅ **Sync with Google Sheets** automatically  
✅ **Auto-calculate P&L, balance sheet, net worth** via formulas  
✅ **Track loan repayments** with custom schedules  

---

## Quick Setup (5 min)

### Step 1: Install Python
- Visit: https://python.org
- Download Python 3.8+
- Install it

Verify:
```bash
python --version
```

### Step 2: Install Dependencies
From the app folder:
```bash
pip install -r requirements.txt
```

### Step 3: Get Google API Credentials
1. Go to: https://console.cloud.google.com/
2. Create a **New Project**
3. Search for **"Google Sheets API"** → **Enable**
4. Go to **Credentials** → **+ Create Credentials**
5. Choose **OAuth 2.0 Desktop Application**
6. Download the JSON file
7. Rename it to `credentials.json`
8. Place in this folder

Your folder should now have:
```
household-finance-app/
├── app.py
├── credentials.json  ✅ (you added this)
├── requirements.txt
└── templates/
```

### Step 4: Create Your Google Sheet
Option A (Automatic - Recommended):
```bash
python create_sheets_template.py
```
This creates the sheet structure automatically.

Option B (Manual):
1. Go to: https://sheets.google.com
2. Create **New Spreadsheet**
3. Name it: `Household Finance 2026`
4. (The app will use it as-is)

### Step 5: Start the App
```bash
python app.py
```

You should see:
```
 * Running on http://127.0.0.1:5000
```

Open in your browser: **http://localhost:5000** ✅

---

## First Use (2 min)

1. **Home page appears** → Click **"Connect Google Sheets"**
2. **Google login** → Sign in and approve access
3. **Dashboard** → You're ready to upload!

---

## Upload Your First Transaction File (2 min)

1. **Export from N26:**
   - N26 App → Accounts → Download → CSV
   - (Or: Transactions → Select dates → Export → CSV)

2. **Upload via web:**
   - Paste your **Google Sheet ID** (from URL: `docs.google.com/spreadsheets/d/YOUR_ID/edit`)
   - Drag-drop your CSV file
   - Select categories for each transaction
   - Click **"Save to Google Sheets"** ✅

3. **Check Google Sheet:**
   - Open your Google Sheet
   - Tab: **"Transaktionen"** - Your transactions are there!
   - Other tabs auto-update with P&L, balance sheet, etc.

---

## That's It! 🎉

Your financial data now syncs with Google Sheets. Every formula (P&L, balance sheet, loan tracking) updates automatically.

---

## Next Steps

### Monthly Routine
1. Download N26 CSV
2. Upload via app
3. Categorize transactions
4. View updated dashboard in Google Sheets

### Customize
- **Add categories**: Edit `templates/dashboard.html`
- **Change app styling**: Edit `templates/base.html`
- **Add LLM auto-categorization**: See README.md

### Share with Partner
- Open your Google Sheet
- Click **Share**
- Enter their email
- They can view (or edit)

---

## Helpful Docs

| Document | Purpose |
|----------|---------|
| **SETUP.md** | Detailed setup instructions |
| **README.md** | Features, architecture, customization |
| **TROUBLESHOOTING.md** | Fix common problems |
| **FILE_MANIFEST.md** | What each file does |

---

## Troubleshooting

### App won't start?
1. Check: `python --version` (must be 3.8+)
2. Check: `pip install -r requirements.txt` succeeded
3. Check: `credentials.json` exists

### Can't connect to Google Sheets?
1. Make sure `credentials.json` is in the folder
2. Delete `token.json` (if it exists)
3. Click "Connect Google Sheets" again

### CSV upload fails?
1. Make sure CSV is from N26 (not manually edited)
2. Check the file isn't corrupted (open in Excel)
3. Try uploading a smaller test file (5-10 transactions)

**Still stuck?** See TROUBLESHOOTING.md

---

## Security Notes

⚠️ **Don't share:**
- `credentials.json` - Your auth key
- `token.json` - Personal session

✅ **Safe to share:**
- Your Google Sheet (with people you trust)
- Source code files
- Documentation

---

## Keyboard Shortcuts

| Action | Command |
|--------|---------|
| Start app | `python app.py` |
| Kill app | `Ctrl + C` |
| Create sheet | `python create_sheets_template.py` |
| Install deps | `pip install -r requirements.txt` |

---

## What Happens Behind the Scenes

1. You upload N26 CSV → Flask app parses it
2. You categorize via web form → App validates
3. You click save → App writes to Google Sheets API
4. Google Sheets → Stores your data & runs formulas
5. Your P&L, balance sheet, dashboard auto-update

All your data lives in Google Sheets (not on a server). You have full control. 🔒

---

## Future Features

The architecture supports easy additions:
- ✨ Claude API auto-categorization
- ✨ Budget alerts
- ✨ Monthly reports
- ✨ Multi-account support
- ✨ Mobile app
- ✨ Cloud hosting

See README.md for details.

---

## Questions?

- **Setup issue?** → See SETUP.md
- **How does it work?** → See README.md
- **Something broken?** → See TROUBLESHOOTING.md
- **What's in each file?** → See FILE_MANIFEST.md

---

**Ready to get started?** Go back to **Step 1** above and follow the Quick Setup! 🚀

Good luck managing your finances! 💰📊
