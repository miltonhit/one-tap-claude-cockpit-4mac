#!/bin/bash
set -euo pipefail

APP_NAME="OneTapClaudeCockpit"
LABEL="io.github.miltonhit.one-tap-claude-cockpit-4mac"
APP="$HOME/Applications/$APP_NAME.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE="$APP/Contents/Resources/statusline.sh"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$AGENT"
rm -rf "$APP"
rm -f "$HOME/.claude/one-tap-claude-cockpit.json"

if [ -f "$SETTINGS" ] && [ "$(/usr/bin/jq -r '.statusLine.command // ""' "$SETTINGS")" = "$STATUSLINE" ]; then
  tmp=$(mktemp)
  /usr/bin/jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "Removed the status line hook from $SETTINGS."
fi

echo "Uninstalled."
