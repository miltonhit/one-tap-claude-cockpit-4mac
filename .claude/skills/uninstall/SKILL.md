---
name: uninstall
description: Remove One Tap Claude Cockpit — the menu bar app, its LaunchAgent, the snapshot file and the status line entry in ~/.claude/settings.json. Use when the user runs /uninstall in this repository or asks to remove the cockpit widget.
---

# Uninstall One Tap Claude Cockpit

```bash
./uninstall.sh
```

It stops and unloads the LaunchAgent, deletes `~/Applications/OneTapClaudeCockpit.app` and
`~/.claude/one-tap-claude-cockpit.json`, and removes the `statusLine` entry from
`~/.claude/settings.json` — but only when that entry still points at this project.

## After running it

```bash
pgrep -fl OneTapClaudeCockpit                  # expect no output
/usr/bin/jq -c '.statusLine' ~/.claude/settings.json
```

If `statusLine` survived, the user had chained their own command through the hook. Tell them
so, and offer to restore their original command (it is in `env.COCKPIT_CHAIN`, and there is a
`~/.claude/settings.json.cockpit-backup` from install time) instead of editing blindly.

Never commit or push anything.
