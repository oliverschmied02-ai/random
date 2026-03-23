#!/bin/bash
# ZVG Intelligence — Autostart bei macOS-Login einrichten
#
# Verwendung:
#   chmod +x install_autostart_mac.sh
#   ./install_autostart_mac.sh
#
# Entfernen:
#   launchctl unload ~/Library/LaunchAgents/com.zvg.streamlit.plist
#   rm ~/Library/LaunchAgents/com.zvg.streamlit.plist

set -e
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.zvg.streamlit"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   ZVG Intelligence — Autostart Setup     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# LaunchAgent-Verzeichnis anlegen
mkdir -p "$HOME/Library/LaunchAgents"

# Plist schreiben
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$APP_DIR/deploy_mac.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardOutPath</key>
    <string>/tmp/zvg_autostart.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/zvg_autostart_error.log</string>
</dict>
</plist>
EOF

echo "✓ LaunchAgent erstellt: $PLIST_PATH"

# Alten Agent entladen falls aktiv
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Neuen Agent laden
launchctl load "$PLIST_PATH"

echo "✓ Autostart aktiviert — ZVG startet automatisch bei jedem Login."
echo ""
echo "Deaktivieren mit:"
echo "  launchctl unload ~/Library/LaunchAgents/$PLIST_NAME.plist"
echo ""
