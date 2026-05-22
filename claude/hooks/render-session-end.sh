#!/bin/sh
# render-session-end.sh
# Claude Code SessionEnd hook. Renders this session's JSONL log to a
# self-contained HTML file next to it.
#
# Install: ~/.claude/hooks/render-session-end.sh   (chmod +x)
# Requires: jq, python3 (stdlib only)
# POSIX sh only: no [[ ]], no zsh/bash builtins.

set -u

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
[ -z "$input" ] && exit 0

session="$(printf '%s\n' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
[ -z "$session" ] && exit 0

logfile="$HOME/ClaudeLogs/${session}.jsonl"
[ -f "$logfile" ] || exit 0

python3 "$HOME/.claude/hooks/render-log.py" "$logfile" >/dev/null 2>&1

exit 0
