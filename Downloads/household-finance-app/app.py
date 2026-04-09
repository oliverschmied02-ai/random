from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials
from google.auth.oauthlib.flow import InstalledAppFlow
from google.api_python_client import discovery
from google.api_core import exceptions as google_exceptions
import pandas as pd
import io
import os
from datetime import datetime
import json
import logging

app = Flask(__name__)
app.secret_key = 'household-finance-secret-key-change-in-production'

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

class GoogleSheetsHandler:
    def __init__(self):
        self.service = None
        self.spreadsheet_id = None

    def authenticate(self):
        """Authenticate with Google Sheets API"""
        creds = None
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)

        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists('credentials.json'):
                    raise FileNotFoundError('credentials.json not found. See SETUP.md for instructions.')
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)

            with open('token.json', 'w') as token:
                token.write(creds.to_json())

        self.service = discovery.build('sheets', 'v4', credentials=creds)
        logger.info('✅ Authenticated with Google Sheets')
        return creds

    def create_spreadsheet(self, title):
        """Create new Google Sheet"""
        spreadsheet_body = {
            'properties': {'title': title},
            'sheets': [
                {'properties': {'title': 'Transaktionen'}},
                {'properties': {'title': 'Debitoren'}},
                {'properties': {'title': 'GuV'}},
                {'properties': {'title': 'Tilgungsplan'}},
                {'properties': {'title': 'Bilanz'}},
                {'properties': {'title': 'Haushaltsrechnung'}},
                {'properties': {'title': 'Dashboard'}}
            ]
        }
        spreadsheet = self.service.spreadsheets().create(body=spreadsheet_body).execute()
        return spreadsheet['spreadsheetId']

    def append_transactions(self, spreadsheet_id, transactions):
        """Append transactions to Transaktionen sheet"""
        values = []
        for tx in transactions:
            values.append([
                tx['Booking Date'],
                tx['Value Date'],
                tx['Partner Name'],
                tx['Category'],
                tx['Amount (EUR)'],
                tx['Type'],
                tx['Payment Reference']
            ])

        body = {'values': values}
        self.service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id,
            range='Transaktionen!A2:G',
            valueInputOption='USER_ENTERED',
            body=body
        ).execute()

    def verify_spreadsheet(self, spreadsheet_id):
        """Verify spreadsheet exists and is accessible"""
        try:
            self.service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
            return True
        except google_exceptions.HttpError as e:
            logger.error(f'Spreadsheet access error: {e}')
            return False

    def get_debitoren_mapping(self, spreadsheet_id):
        """Get existing partner to category mappings"""
        try:
            result = self.service.spreadsheets().values().get(
                spreadsheetId=spreadsheet_id,
                range='Debitoren!A:B'
            ).execute()
            values = result.get('values', [])
            mapping = {}
            for row in values[3:]:  # Skip header rows
                if len(row) >= 2:
                    mapping[row[0]] = row[1] if row[1] else ''
            logger.info(f'Loaded {len(mapping)} debtor mappings')
            return mapping
        except google_exceptions.HttpError as e:
            logger.warning(f'Could not load debitoren: {e}')
            return {}

gs_handler = GoogleSheetsHandler()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login')
def login():
    """Initialize Google authentication"""
    try:
        gs_handler.authenticate()
        session['authenticated'] = True
        logger.info('User authenticated successfully')
        return redirect(url_for('dashboard'))
    except FileNotFoundError as e:
        return f"❌ Setup Error: {str(e)}", 400
    except Exception as e:
        logger.error(f'Authentication failed: {e}')
        return f"❌ Authentication failed: {str(e)}", 500

@app.route('/dashboard')
def dashboard():
    if not session.get('authenticated'):
        return redirect(url_for('login'))
    return render_template('dashboard.html')

@app.route('/api/upload-csv', methods=['POST'])
def upload_csv():
    """Upload and parse N26 CSV"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400

    try:
        df = pd.read_csv(file)

        # Parse N26 CSV format
        transactions = []
        for idx, row in df.iterrows():
            transactions.append({
                'Booking Date': row['Booking Date'],
                'Value Date': row['Value Date'],
                'Partner Name': row['Partner Name'],
                'Amount (EUR)': row['Amount (EUR)'],
                'Type': row['Type'],
                'Payment Reference': row['Payment Reference'],
                'Category': '',  # To be filled by user
                'index': idx
            })

        session['pending_transactions'] = transactions
        return jsonify({
            'success': True,
            'count': len(transactions),
            'transactions': transactions[:10]  # Return first 10 for preview
        })
    except Exception as e:
        return jsonify({'error': f'CSV parsing failed: {str(e)}'}), 400

@app.route('/api/categorize', methods=['POST'])
def categorize():
    """Categorize transactions and save to Google Sheets"""
    data = request.json
    spreadsheet_id = data.get('spreadsheet_id', '').strip()
    categorized = data.get('transactions')

    if not spreadsheet_id or not categorized:
        return jsonify({'error': 'Missing spreadsheet ID or transactions'}), 400

    try:
        # Verify spreadsheet exists
        if not gs_handler.verify_spreadsheet(spreadsheet_id):
            return jsonify({'error': 'Spreadsheet not found. Check your Spreadsheet ID.'}), 400

        gs_handler.append_transactions(spreadsheet_id, categorized)
        session.pop('pending_transactions', None)
        logger.info(f'Saved {len(categorized)} transactions to sheet {spreadsheet_id}')
        return jsonify({'success': True, 'message': f'✅ {len(categorized)} transactions saved to Google Sheets'})
    except google_exceptions.HttpError as e:
        logger.error(f'Google API error: {e}')
        return jsonify({'error': f'Google Sheets error: {e.resp.status}'}), 500
    except Exception as e:
        logger.error(f'Save failed: {e}')
        return jsonify({'error': f'Save failed: {str(e)}'}), 500

@app.route('/api/debitoren', methods=['GET'])
def get_debitoren():
    """Get debtor to category mappings"""
    spreadsheet_id = request.args.get('spreadsheet_id')
    if not spreadsheet_id:
        return jsonify({'error': 'Spreadsheet ID required'}), 400

    try:
        mapping = gs_handler.get_debitoren_mapping(spreadsheet_id)
        return jsonify({'mappings': mapping})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)
