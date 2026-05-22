#!/bin/sh
# log-tool-use.sh
# Claude Code PostToolUse hook. Appends one JSONL line per tool call to
# ~/ClaudeLogs/<session_id>.jsonl using the real system clock.
#
# Install: ~/.claude/hooks/log-tool-use.sh   (chmod +x)
# Requires: jq   (brew install jq)
#
# Designed to be invisible and never block a session: any failure exits 0.
# POSIX sh only: no [[ ]], no zsh/bash builtins.

set -u

# No jq, do nothing rather than break the session.
command -v jq >/dev/null 2>&1 || exit 0

logdir="$HOME/ClaudeLogs"
mkdir -p "$logdir" 2>/dev/null || exit 0

# The hook payload arrives once on stdin. Capture it so we can read it twice.
input="$(cat)"
[ -z "$input" ] && exit 0

session="$(printf '%s\n' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
[ -z "$session" ] && session="unknown"

logfile="$logdir/${session}.jsonl"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build the line with jq so all JSON escaping is handled correctly. tool_input
# and the result are stringified and truncated to keep entries small and fast.
printf '%s\n' "$input" | jq -c --arg ts "$ts" '{
  ts:     $ts,
  event:  (.hook_event_name // "PostToolUse"),
  tool:   (.tool_name // "unknown"),
  target: (.tool_input.file_path // .tool_input.command // .tool_input.path // .tool_input.pattern // ""),
  cwd:    (.cwd // ""),
  input:  (.tool_input  | tostring | .[0:800]),
  result: ((.tool_response // .tool_output // "") | tostring | .[0:400])
}' >> "$logfile" 2>/dev/null

exit 0
