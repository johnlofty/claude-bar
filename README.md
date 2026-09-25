# UsageBar

A macOS menu bar app that shows your Claude subscription usage (5-hour and weekly limits).

It never touches credentials. Claude Code already passes `rate_limits` to your
[status line](https://docs.claude.com/en/docs/claude-code/statusline) command; a small hook saves just those
numbers to `~/.claude/usage-bar.json`, and the app reads that file. No network access, Keychain, or
Accessibility permission.

## Setup

1. Build: `sh scripts/build-app.sh` (creates `build/UsageBar.app`, needs Xcode command line tools and macOS 13+).
2. In your status line script, right after it reads stdin into `input`, add:

   ```sh
   echo "$input" | sh /path/to/claude_usage_bar/scripts/usage-snapshot.sh
   ```

   If you don't have a status line yet, set `"statusLine": {"type": "command", "command": "sh /path/to/claude_usage_bar/scripts/usage-snapshot.sh"}` in `~/.claude/settings.json`.
3. Open `build/UsageBar.app` (optionally move it to `/Applications` and add it to Login Items).

## Display options

Click the menu bar item to choose which windows to show (5h, 7d, or both), the style (`5h 60%`, `60%`,
mini bars, or bars + %), whether to show the ✳︎ icon, and whether to add the time until reset.

## Limitations

Numbers update only while Claude Code is running and only for subscribers (Pro/Max). Usage on claude.ai
counts toward the same limits but shows up the next time Claude Code refreshes. Windows past their reset time
show `–`.
