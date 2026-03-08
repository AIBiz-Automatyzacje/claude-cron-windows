#!/bin/bash
set -e

LABEL="com.claude-cron.scheduler"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "🕹️  CLAUDE-CRON — macOS Autostart Removal"
echo ""

# Unload
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Remove plist
rm -f "$PLIST_PATH"

echo "✅ Autostart removed."
echo "   The server will no longer start on login."
echo "   Your jobs and data are preserved in ~/claude-cron/data/"
