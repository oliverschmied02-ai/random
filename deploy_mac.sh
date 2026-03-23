#!/bin/bash
# ZVG Intelligence — MacBook Server Deployment
# Startet die App lokal und macht sie via ngrok öffentlich erreichbar.
#
# Verwendung:
#   chmod +x deploy_mac.sh
#   ./deploy_mac.sh
#
# Voraussetzungen: macOS mit Homebrew (https://brew.sh)

set -e
cd "$(dirname "$0")"

PORT=8501
APP_DIR="$(pwd)"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ZVG Intelligence — MacBook Deployment  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. ngrok installieren falls nötig ─────────────────────────────────────────
if ! command -v ngrok &>/dev/null; then
    echo "▶ ngrok nicht gefunden. Installiere via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "FEHLER: Homebrew ist nicht installiert."
        echo "Installiere Homebrew zuerst: https://brew.sh"
        exit 1
    fi
    brew install ngrok/ngrok/ngrok
    echo "✓ ngrok installiert"
fi

# ── 2. Python-Umgebung vorbereiten ────────────────────────────────────────────
if [ ! -d ".venv" ]; then
    echo "▶ Erstelle virtuelle Umgebung..."
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "▶ Prüfe Abhängigkeiten..."
pip install -q -r requirements.txt

mkdir -p data reports secrets

# ── 3. Streamlit starten ──────────────────────────────────────────────────────
echo "▶ Starte Streamlit auf Port $PORT..."
streamlit run app.py \
    --server.port "$PORT" \
    --server.headless true \
    --browser.gatherUsageStats false \
    &>/tmp/zvg_streamlit.log &
STREAMLIT_PID=$!

# Warten bis Streamlit bereit ist (max. 30 Sekunden)
echo "▶ Warte auf Streamlit..."
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$PORT/_stcore/health" &>/dev/null; then
        break
    fi
    sleep 1
done

if ! kill -0 "$STREAMLIT_PID" 2>/dev/null; then
    echo "FEHLER: Streamlit konnte nicht gestartet werden."
    echo "Log: /tmp/zvg_streamlit.log"
    cat /tmp/zvg_streamlit.log
    exit 1
fi

echo "✓ Streamlit läuft (PID: $STREAMLIT_PID)"

# ── 4. ngrok-Tunnel starten ───────────────────────────────────────────────────
echo "▶ Starte ngrok Tunnel..."
ngrok http "$PORT" --log=stdout --log-level=warn &>/tmp/zvg_ngrok.log &
NGROK_PID=$!

sleep 3

# Öffentliche URL via ngrok-API holen
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for t in data.get('tunnels', []):
        if t.get('proto') == 'https':
            print(t['public_url'])
            break
except:
    pass
" 2>/dev/null || echo "")

echo ""
echo "╔══════════════════════════════════════════╗"
if [ -n "$NGROK_URL" ]; then
    echo "║  Öffentliche URL:                        ║"
    echo "║  $NGROK_URL"
    echo "║                                          ║"
fi
echo "║  Lokale URL: http://localhost:$PORT      ║"
echo "║  ngrok Dashboard: http://localhost:4040  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [ -z "$NGROK_URL" ]; then
    echo "Hinweis: ngrok URL noch nicht abrufbar."
    echo "Öffne http://localhost:4040 um die aktuelle URL zu sehen."
    echo ""
fi

echo "Logs: /tmp/zvg_streamlit.log | /tmp/zvg_ngrok.log"
echo "Beenden mit Ctrl+C"
echo ""

# Cleanup beim Beenden
cleanup() {
    echo ""
    echo "▶ Beende Prozesse..."
    kill "$STREAMLIT_PID" 2>/dev/null || true
    kill "$NGROK_PID" 2>/dev/null || true
    echo "✓ Beendet."
}
trap cleanup EXIT INT TERM

wait "$STREAMLIT_PID"
