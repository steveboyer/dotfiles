#!/bin/sh
# log-tool-use.sh
# Claude Code PostToolUse hook. Appends one JSONL line per tool call to
# ~/ClaudeLogs/<folder>_<slug>_<short-uuid>.jsonl, then re-renders the
# sibling .html so it stays current as the session runs (SessionEnd
# isn't reliable on crashes or force-quits).
#
# Filename parts:
#   folder    cwd basename, slugified                  (always known)
#   slug      derived from Claude's aiTitle            (set asynchronously)
#   short     first 8 chars of session UUID            (collision guard)
# Until aiTitle is written, the slug part is omitted. When it later
# appears (or is refined), this hook renames the existing file in place
# so each session ends up with one file at its final path.
#
# Install: ~/.claude/hooks/log-tool-use.sh   (chmod +x)
# Requires: jq        (brew install jq)
#           python3   (stdlib only, used by render-log.py)
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

cwd="$(printf '%s\n' "$input" | jq -r '.cwd // empty' 2>/dev/null)"

# Lowercase, collapse non-alphanumerics to '-', strip leading/trailing '-',
# cap at 60 chars. POSIX sed so it works regardless of GNU/BSD.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' \
    | cut -c1-60
}

short="$(printf '%s' "$session" | cut -d- -f1)"

folder=""
[ -n "$cwd" ] && folder="$(slugify "$(basename "$cwd")")"

# Look up the AI-generated session title from Claude's per-project transcript.
# Path mirrors how Claude encodes cwd: each '/' becomes '-'.
ai_title=""
if [ -n "$cwd" ] && [ "$session" != "unknown" ]; then
  encoded_cwd="$(printf '%s' "$cwd" | sed 's|/|-|g')"
  transcript="$HOME/.claude/projects/${encoded_cwd}/${session}.jsonl"
  if [ -f "$transcript" ]; then
    # Last ai-title wins; Claude can refine the title mid-session.
    ai_title="$(jq -r 'select(.type=="ai-title") | .aiTitle' "$transcript" 2>/dev/null | tail -1)"
  fi
fi

slug=""
[ -n "$ai_title" ] && slug="$(slugify "$ai_title")"

# Compose the basename, skipping any empty segments.
base=""
for part in "$folder" "$slug" "$short"; do
  [ -n "$part" ] || continue
  if [ -z "$base" ]; then
    base="$part"
  else
    base="${base}_${part}"
  fi
done
[ -z "$base" ] && base="$session"   # defensive: shouldn't happen
logfile="$logdir/${base}.jsonl"

# Migrate any earlier file for this session whose name no longer matches
# (cwd discovered late, aiTitle just appeared, or title refined). Match
# either the legacy full-UUID name or any "*_<short>.jsonl" form.
for existing in "$logdir/${session}.jsonl" "$logdir"/*_"${short}".jsonl; do
  [ -f "$existing" ] || continue
  [ "$existing" = "$logfile" ] && continue
  mv "$existing" "$logfile" 2>/dev/null
  old_html="${existing%.jsonl}.html"
  new_html="${logfile%.jsonl}.html"
  [ -f "$old_html" ] && mv "$old_html" "$new_html" 2>/dev/null
done

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

# Re-render the sibling HTML view so it tracks the JSONL in near-real-time.
# render-log.py is stdlib-only, so it runs without a venv. Errors swallowed
# so a render failure can never block the session.
if command -v python3 >/dev/null 2>&1; then
  python3 "$HOME/.claude/hooks/render-log.py" "$logfile" >/dev/null 2>&1 || true
fi

exit 0
