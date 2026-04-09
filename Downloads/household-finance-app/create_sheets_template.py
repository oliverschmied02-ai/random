#!/usr/bin/env python3
"""
Google Sheets Template Creator
Run this script to automatically create the Google Sheet structure with headers and formulas
"""

from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials
from google.auth.oauthlib.flow import InstalledAppFlow
from google.api_python_client import discovery
import os
import sys

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

def authenticate():
    """Authenticate with Google Sheets API"""
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists('credentials.json'):
                print("❌ credentials.json not found!")
                print("Please download it from Google Cloud Console first.")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)

        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    service = discovery.build('sheets', 'v4', credentials=creds)
    return service

def create_sheet(service, title):
    """Create new Google Sheet with structure"""
    spreadsheet_body = {
        'properties': {'title': title},
        'sheets': [
            {'properties': {'title': 'Transaktionen', 'index': 0}},
            {'properties': {'title': 'Debitoren', 'index': 1}},
            {'properties': {'title': 'GuV', 'index': 2}},
            {'properties': {'title': 'Tilgungsplan', 'index': 3}},
            {'properties': {'title': 'Bilanz', 'index': 4}},
            {'properties': {'title': 'Haushaltsrechnung', 'index': 5}},
            {'properties': {'title': 'Dashboard', 'index': 6}}
        ]
    }

    spreadsheet = service.spreadsheets().create(body=spreadsheet_body).execute()
    sheet_id = spreadsheet['spreadsheetId']

    # Add headers to Transaktionen
    requests = [
        {
            'updateCells': {
                'range': {'sheetId': 0, 'rowIndex': 0, 'columnIndex': 0, 'endColumnIndex': 7},
                'rows': [{
                    'values': [
                        {'userEnteredValue': {'stringValue': 'Booking Date'}},
                        {'userEnteredValue': {'stringValue': 'Value Date'}},
                        {'userEnteredValue': {'stringValue': 'Partner Name'}},
                        {'userEnteredValue': {'stringValue': 'Category'}},
                        {'userEnteredValue': {'stringValue': 'Amount (EUR)'}},
                        {'userEnteredValue': {'stringValue': 'Type'}},
                        {'userEnteredValue': {'stringValue': 'Payment Reference'}}
                    ]
                }],
                'fields': 'userEnteredValue'
            }
        }
    ]

    # Add headers to Debitoren
    requests.append({
        'updateCells': {
            'range': {'sheetId': 1, 'rowIndex': 0, 'columnIndex': 0, 'endColumnIndex': 2},
            'rows': [{
                'values': [
                    {'userEnteredValue': {'stringValue': 'Partner Name'}},
                    {'userEnteredValue': {'stringValue': 'Category'}}
                ]
            }],
            'fields': 'userEnteredValue'
        }
    })

    # Execute all requests
    body = {'requests': requests}
    service.spreadsheets().batchUpdate(spreadsheetId=sheet_id, body=body).execute()

    return sheet_id

def main():
    print("🔐 Authenticating with Google...")
    service = authenticate()
    print("✅ Authenticated!")

    title = input("\n📝 Enter a name for your new Google Sheet (default: 'Household Finance 2026'): ").strip()
    if not title:
        title = 'Household Finance 2026'

    print(f"\n📊 Creating '{title}'...")
    sheet_id = create_sheet(service, title)

    print(f"\n✅ Sheet created successfully!")
    print(f"\n📋 Your Spreadsheet ID: {sheet_id}")
    print(f"🔗 Open it: https://docs.google.com/spreadsheets/d/{sheet_id}/edit")
    print(f"\n👉 Use this ID in the app's dashboard to upload transactions!")

if __name__ == '__main__':
    main()
