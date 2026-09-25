#!/bin/sh
# Reads Claude Code status line JSON on stdin and saves only the rate_limits block
# (plus a timestamp) to ~/.claude/usage-bar.json for the UsageBar menu bar app.
# No tokens or conversation data are written.
out="$HOME/.claude/usage-bar.json"
snap=$(jq -c 'select(.rate_limits != null) | {rate_limits: {five_hour: .rate_limits.five_hour, seven_day: .rate_limits.seven_day}, captured_at: (now | floor)}' 2>/dev/null)
[ -n "$snap" ] || exit 0
tmp="$out.tmp.$$"
printf '%s\n' "$snap" > "$tmp" && mv -f "$tmp" "$out"
