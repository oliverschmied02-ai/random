# Troubleshooting Guide

## Common Issues & Solutions

### 1. "credentials.json not found"

**Error Message:**
```
FileNotFoundError: credentials.json not found. See SETUP.md for instructions.
```

**Solution:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable **Google Sheets API**
4. Go to **APIs & Services** → **Credentials**
5. Click **+ Create Credentials** → **OAuth Client ID** → **Desktop application**
6. Download the JSON file
7. Rename it to `credentials.json`
8. Place it in the `household-finance-app` folder

---

### 2. "Spreadsheet not found"

**Error Message:**
```
Spreadsheet not found. Check your Spreadsheet ID.
```

**Solution:**
- Go to your Google Sheet in browser
- The URL looks like:
  ```
  https://docs.google.com/spreadsheets/d/YOUR_ID_HERE/edit
  ```
- Copy the long string between `/d/` and `/edit`
- Paste into the app's Spreadsheet ID field
- Make sure it's shared with your Google account

---

### 3. "CSV parsing failed"

**Error Message:**
```
CSV parsing failed: ...
```

**Solution:**
1. Make sure your CSV is from N26 bank export
2. Download directly from N26 app, don't manually edit
3. Check if CSV opens correctly in Excel/Sheets
4. Make sure columns are: Booking Date, Value Date, Partner Name, Amount, etc.

**To export from N26:**
- N26 App → Accounts → [Select account] → Download → CSV
- OR: Transactions → Select date range → Export → CSV

---

### 4. "Authentication failed"

**Error Message:**
```
❌ Authentication failed: ...
```

**Solution:**
1. Delete `token.json` from the app folder
2. Clear browser cookies for `localhost:5000`
3. Click "Connect Google Sheets" again
4. You'll be prompted to login - approve access

If it persists:
- Make sure `credentials.json` is valid JSON (check with a text editor)
- Delete both `credentials.json` and `token.json`
- Download new credentials from Google Cloud Console

---

### 5. "Port 5000 already in use"

**Error Message:**
```
OSError: [Errno 48] Address already in use
```

**Solution:**

**Option A: Use a different port**
```bash
python app.py --port 8080
```
Then visit: http://localhost:8080

**Option B: Kill the process using port 5000**

**On macOS/Linux:**
```bash
lsof -ti:5000 | xargs kill -9
```

**On Windows:**
```bash
netstat -ano | findstr :5000
taskkill /PID <PID> /F
```

Then start the app normally:
```bash
python app.py
```

---

### 6. "ModuleNotFoundError: No module named 'flask'"

**Error Message:**
```
ModuleNotFoundError: No module named 'flask'
```

**Solution:**
Install Python dependencies:
```bash
pip install -r requirements.txt
```

If that doesn't work:
```bash
python3 -m pip install -r requirements.txt
```

Check your Python installation:
```bash
python --version
```

Must be Python 3.8+

---

### 7. Browser can't connect to localhost:5000

**Problem:**
You see "Can't reach this page" or "Connection refused"

**Solution:**
1. Check if Flask app is running (should show output in terminal)
2. Try opening: http://127.0.0.1:5000 (instead of localhost)
3. Check firewall isn't blocking port 5000
4. Try a different port: `python app.py --port 8080`
5. Restart the app completely

**On Windows:** Make sure you're not using WSL (Windows Subsystem for Linux). Run Python directly.

---

### 8. Transactions not appearing in Google Sheet

**Problem:**
You uploaded CSV and categorized transactions, but they don't show in Google Sheets

**Solution:**
1. Refresh your Google Sheet (F5)
2. Check that you're looking at the correct sheet tab: **Transaktionen**
3. Verify the Spreadsheet ID was correct when you uploaded
4. Check Flask console output for errors
5. Try uploading a fresh CSV with just 2-3 transactions

---

### 9. "Google Sheets API not enabled"

**Error Message:**
```
Google Sheets API is not enabled for project
```

**Solution:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Library**
4. Search for "Google Sheets API"
5. Click it and press **Enable**

Wait a few seconds for the API to activate.

---

### 10. Categories dropdown is empty

**Problem:**
When uploading CSV, the category dropdown has no options

**Solution:**
This shouldn't happen - the categories are hard-coded in `templates/dashboard.html`

If it occurs:
1. Check browser console (F12 → Console tab) for JavaScript errors
2. Verify `templates/dashboard.html` wasn't modified
3. Restart the Flask app: `python app.py`

---

### 11. "Invalid Spreadsheet ID format"

**Problem:**
Getting an error about Spreadsheet ID being invalid

**Solution:**
The Spreadsheet ID must be the long string from the URL:

❌ Wrong:
```
Household Finance 2026
1BxiMVs0XRA5nF
docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMKUVfixWaymRmYr3DhQJYIRiN4tA1s/edit
```

✅ Correct:
```
1BxiMVs0XRA5nFMKUVfixWaymRmYr3DhQJYIRiN4tA1s
```

Copy from your Google Sheet URL and paste exactly.

---

### 12. App crashes on startup

**Error Message:**
```
Traceback (most recent call last):
...
```

**Solution:**
Check what's in the error message:

1. **"config.py not found"** → You're missing the file structure. Re-download the app.
2. **"database locked"** → Delete `token.json` and try again
3. **Other errors** → Check that all files are present:
   - app.py
   - requirements.txt
   - templates/base.html
   - templates/index.html
   - templates/dashboard.html

Try a fresh download if corrupted.

---

### 13. Transactions show but appear duplicated

**Problem:**
After uploading, transactions appear twice in Google Sheet

**Solution:**
This typically means you uploaded the same CSV twice.

To fix:
1. Go to your Google Sheet → **Transaktionen** tab
2. Delete duplicate rows (keep only one copy)
3. Next time, only upload each CSV once per month

You can check which month's transactions were already uploaded by looking at the "Booking Date" column.

---

### 14. Memory error or slow app

**Problem:**
App freezes when uploading large CSV files

**Solution:**
1. Split the CSV into smaller chunks (e.g., by month)
2. Upload one at a time
3. Wait between uploads

Typical limits: ~1000 transactions per upload is fine

---

### 15. Can't share Google Sheet with others

**Problem:**
Trying to share your Google Sheet but getting errors

**Solution:**
1. Open Google Sheet directly (not via the Flask app)
2. Click **Share** (top right)
3. Enter email addresses to share with
4. Set permissions (Viewer, Commenter, Editor)
5. Click **Share**

**Note:** Only the person with the Spreadsheet ID can upload transactions via the app. Others can only view the shared sheet.

---

## Still Having Issues?

### Check These Files Exist:
```
household-finance-app/
├── app.py
├── credentials.json (you create this)
├── requirements.txt
├── SETUP.md
├── README.md
├── templates/
│   ├── base.html
│   ├── index.html
│   └── dashboard.html
```

### Check Flask Console Output:
The Flask terminal will show detailed error messages. Copy the full error and search for it in this guide.

### Last Resort:
1. Delete `token.json`
2. Close Flask app (Ctrl+C)
3. Run: `pip install --upgrade google-auth-oauthlib google-api-python-client`
4. Start Flask again: `python app.py`

---

## Getting More Help

- **SETUP.md** - Initial setup instructions
- **README.md** - Architecture and features overview
- **app.py** - Source code (check console logs)
- **Browser Console** (F12) - JavaScript errors
- **Google Cloud Console** - API configuration issues

---

Good luck! 💪
