---
name: install
description: Build and install One Tap Claude Cockpit — the macOS menu bar widget that shows Claude Code's 5-hour and 7-day usage. Sets up the app, the status line hook and the login agent, then verifies everything is live. Use when the user runs /install in this repository or asks to install, reinstall or update the cockpit widget.
---

# Install One Tap Claude Cockpit

Install the menu bar widget from this repository. Work from the repository root.

## 1. Check the prerequisites

Run these and report any that fail — do not proceed past a hard failure.

```bash
uname                                  # must be Darwin
command -v swiftc                      # Xcode Command Line Tools
ls -l /usr/bin/jq                      # ships with macOS 13+
```

If `swiftc` is missing, tell the user to run `xcode-select --install` and stop. That
install opens a GUI dialog and cannot be automated from here.

## 2. Run the installer

```bash
./install.sh
```

It builds the app into `~/Applications/OneTapClaudeCockpit.app`, copies the status line
hook into the bundle, registers a LaunchAgent, and points
`~/.claude/settings.json` at the hook (after backing that file up).

## 3. Handle an existing status line

`install.sh` never overwrites a status line the user already has — it prints a warning and
leaves `settings.json` untouched. If that happens, ask the user which they want:

- **Chain both** (recommended): edit `~/.claude/settings.json` so `statusLine.command`
  points at `~/Applications/OneTapClaudeCockpit.app/Contents/Resources/statusline.sh`, and
  add `env.COCKPIT_CHAIN` with their previous command. The hook feeds the same stdin JSON
  to that command and passes its output through, so their status line keeps working.
- **Keep theirs, skip the widget's data source**: the widget then only ever shows
  placeholders. Say so plainly rather than leaving them with a dead widget.

Only edit `settings.json` with the Edit tool, and only the `statusLine` and `env` keys.
Never rewrite the whole file.

## 4. Verify it is actually running

The installer already fails loudly if the app does not come up, but confirm the rest:

```bash
pgrep -fl OneTapClaudeCockpit
launchctl print "gui/$(id -u)/io.github.miltonhit.one-tap-claude-cockpit-4mac" | grep -E "state|runatload"
/usr/bin/jq -c .statusLine ~/.claude/settings.json
```

Expect a live PID, `state = running` with `runatload`, and a `statusLine.command` pointing
into the app bundle. If any check fails, fix it before reporting success.

## 5. Report

Tell the user:

- The widget is in the menu bar now, and comes back automatically at every login.
- It shows placeholders until their next Claude Code reply — the real numbers arrive with
  the first API response of a session, because that is when Claude Code learns the limits.
- Clicking the widget shows exact reset times; `./uninstall.sh` removes everything.

## Rules

- Never commit or push anything.
- Do not modify files outside this repository, `~/.claude/settings.json`,
  `~/Applications/OneTapClaudeCockpit.app` and the LaunchAgent plist.
- Re-running this skill is safe: the installer tears down the old build and agent first.
