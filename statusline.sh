#!/bin/bash
set -uo pipefail

SNAPSHOT="$HOME/.claude/one-tap-claude-cockpit.json"
JQ=/usr/bin/jq

input=$(cat)

snapshot=$(printf '%s' "$input" | "$JQ" -c '
  (.rate_limits // {}) as $r
  | select(($r.five_hour // $r.seven_day) != null)
  | {updated_at: (now | floor), five_hour: $r.five_hour, seven_day: $r.seven_day}
' 2>/dev/null)

if [ -n "$snapshot" ]; then
  printf '%s\n' "$snapshot" > "$SNAPSHOT.tmp" && mv "$SNAPSHOT.tmp" "$SNAPSHOT"
fi

if [ -n "${COCKPIT_CHAIN:-}" ] && [ -x "${COCKPIT_CHAIN}" ]; then
  printf '%s' "$input" | "$COCKPIT_CHAIN"
fi

exit 0
