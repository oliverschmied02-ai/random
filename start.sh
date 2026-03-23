#!/bin/bash
# ZVG Intelligence — one-click launcher (Mac / Linux)

set -e
cd "$(dirname "$0")"

echo "🏠 ZVG Intelligence wird gestartet ..."

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "📦 Erstelle virtuelle Umgebung ..."
    python3 -m venv .venv
fi

# Activate
source .venv/bin/activate

# Install / update dependencies
echo "📦 Prüfe Abhängigkeiten ..."
pip install -q -r requirements.txt

# Create required directories
mkdir -p data reports secrets

# Launch GUI
echo "🚀 Öffne Browser ..."
streamlit run app.py --server.headless false --browser.gatherUsageStats false
