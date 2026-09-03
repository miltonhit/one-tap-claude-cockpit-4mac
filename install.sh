#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OneTapClaudeCockpit"
LABEL="io.github.miltonhit.one-tap-claude-cockpit-4mac"
APP="$HOME/Applications/$APP_NAME.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE="$APP/Contents/Resources/statusline.sh"
RUNNING="$APP_NAME.app/Contents/MacOS/$APP_NAME"

say() { printf '\033[1m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }
fail() { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "This installer is macOS only."
command -v swiftc >/dev/null || fail "swiftc not found. Install the Xcode Command Line Tools: xcode-select --install"
[ -x /usr/bin/jq ] || fail "/usr/bin/jq not found. It ships with macOS 13+; on older systems install jq and edit statusline.sh."

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "$RUNNING" 2>/dev/null || true
for _ in $(seq 1 20); do
  pgrep -f "$RUNNING" >/dev/null || break
  sleep 0.3
done

say "Building ${APP_NAME}..."
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
BUNDLE="$STAGE/$APP_NAME.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Info.plist "$BUNDLE/Contents/Info.plist"
cp statusline.sh "$BUNDLE/Contents/Resources/statusline.sh"
chmod +x "$BUNDLE/Contents/Resources/statusline.sh"
swiftc -O -framework AppKit Cockpit.swift -o "$BUNDLE/Contents/MacOS/$APP_NAME"

TRAY="/Applications/Claude.app/Contents/Resources"
if [ -f "$TRAY/TrayIconTemplate.png" ]; then
  cp "$TRAY/TrayIconTemplate.png" "$BUNDLE/Contents/Resources/ClaudeTemplate.png"
  cp "$TRAY/TrayIconTemplate@2x.png" "$BUNDLE/Contents/Resources/ClaudeTemplate@2x.png" 2>/dev/null || true
  cp "$TRAY/TrayIconTemplate@3x.png" "$BUNDLE/Contents/Resources/ClaudeTemplate@3x.png" 2>/dev/null || true
  say "Using the Claude desktop app's own menu bar glyph."
else
  say "Claude desktop app not found - using the built-in drawn starburst."
fi

codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || warn "Ad-hoc code signing failed; the app still runs."

mkdir -p "$HOME/Applications"
rm -rf "$APP"
mv "$BUNDLE" "$APP"

mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

current=$(/usr/bin/jq -r '.statusLine.command // ""' "$SETTINGS")
if [ -z "$current" ] || [ "$current" = "$STATUSLINE" ]; then
  cp "$SETTINGS" "$SETTINGS.cockpit-backup"
  tmp=$(mktemp)
  /usr/bin/jq --arg cmd "$STATUSLINE" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  say "Registered the status line hook in $SETTINGS (backup: $SETTINGS.cockpit-backup)."
else
  warn "You already have a status line command:"
  warn "  $current"
  warn "Left untouched. To run both, add this to $SETTINGS:"
  warn "  \"env\": { \"COCKPIT_CHAIN\": \"$current\" }"
  warn "  \"statusLine\": { \"type\": \"command\", \"command\": \"$STATUSLINE\" }"
fi

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP/Contents/MacOS/$APP_NAME</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$AGENT"

for _ in $(seq 1 20); do
  pgrep -f "$RUNNING" >/dev/null && break
  sleep 0.3
done
pgrep -f "$RUNNING" >/dev/null || fail "The agent was registered but the app never started. Inspect: launchctl print gui/$(id -u)/$LABEL"

say ""
say "Done. Look at the right side of your menu bar."
say "It shows placeholders until your next Claude Code reply lands - the numbers arrive with the first API response of a session."
