@echo off
REM ZVG Intelligence — one-click launcher (Windows)

cd /d "%~dp0"
echo 🏠 ZVG Intelligence wird gestartet ...

REM Create virtual environment if not exists
if not exist ".venv" (
    echo 📦 Erstelle virtuelle Umgebung ...
    python -m venv .venv
)

REM Activate
call .venv\Scripts\activate.bat

REM Install / update dependencies
echo 📦 Prüfe Abhängigkeiten ...
pip install -q -r requirements.txt

REM Create directories
if not exist "data" mkdir data
if not exist "reports" mkdir reports
if not exist "secrets" mkdir secrets

REM Launch GUI
echo 🚀 Öffne Browser ...
streamlit run app.py --server.headless false --browser.gatherUsageStats false

pause
