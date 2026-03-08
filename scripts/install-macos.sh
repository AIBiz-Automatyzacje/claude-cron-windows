#!/bin/bash
set -e

LABEL="com.claude-cron.scheduler"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
PROJECT_DIR="$HOME/claude-cron"
NODE_PATH=$(which node)
LOG_DIR="$PROJECT_DIR/data"

echo "🕹️  CLAUDE-CRON — macOS Autostart Setup"
echo ""

# Ensure data dir exists
mkdir -p "$LOG_DIR"

# Unload if already loaded
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Generate plist
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_PATH</string>
    <string>$PROJECT_DIR/server.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$PROJECT_DIR</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$PATH</string>
  </dict>
</dict>
</plist>
PLIST

# Load
launchctl load -w "$PLIST_PATH"

echo "✅ Installed and started!"
echo "   Plist: $PLIST_PATH"
echo "   Logs:  $LOG_DIR/stdout.log"
echo ""
echo "   Server starts automatically on login."
echo "   Open http://localhost:7777"
