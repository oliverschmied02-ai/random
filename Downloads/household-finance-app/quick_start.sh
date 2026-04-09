#!/bin/bash
# Quick Start Script for Household Finance Dashboard

echo "================================"
echo "Household Finance Dashboard"
echo "Quick Start Setup"
echo "================================"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3.8+ first."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt
echo "✅ Dependencies installed"
echo ""

# Check credentials
if [ ! -f "credentials.json" ]; then
    echo "❌ credentials.json not found!"
    echo ""
    echo "To set up Google API credentials:"
    echo "1. Visit: https://console.cloud.google.com/"
    echo "2. Create a new project"
    echo "3. Enable Google Sheets API"
    echo "4. Create OAuth 2.0 Desktop credentials"
    echo "5. Download the JSON file as 'credentials.json'"
    echo "6. Place it in: $(pwd)"
    echo ""
    read -p "Press Enter once you've added credentials.json..."
fi

if [ ! -f "credentials.json" ]; then
    echo "❌ credentials.json still not found. Exiting."
    exit 1
fi

echo "✅ credentials.json found"
echo ""

# Offer to create Google Sheet
read -p "Create a new Google Sheet? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Creating Google Sheet..."
    python3 create_sheets_template.py
    echo ""
fi

# Start app
echo ""
echo "🎉 Setup complete!"
echo ""
echo "Starting Flask app..."
echo "Open: http://localhost:5000"
echo ""
python3 app.py
