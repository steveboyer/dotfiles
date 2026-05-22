#!/usr/bin/env python3
"""Render a Claude Code tool-use JSONL log into a self-contained HTML file.

Usage:
    render-log.py /path/to/<session>.jsonl   Render one file to a sibling .html
    render-log.py --all                       Render every .jsonl in ~/ClaudeLogs

Stdlib only by design, so it can run from a hook without activating a venv.
"""

from __future__ import annotations

import html
import json
import sys
from datetime import datetime
from pathlib import Path

LOG_DIR = Path.home() / "ClaudeLogs"

# Brand palette. Teal/blue on near-black: high contrast and safe under
# deuteranomaly, no information carried by red vs green.
BG = "#0A0D0F"
PANEL = "#11161A"
LINE = "#1E262C"
TEXT = "#E6EDF0"
MUTED = "#7C8A94"
TEAL = "#00C9C8"
BLUE = "#0087B0"


def parse_local_time(value: str) -> str:
    """Convert a UTC ISO 8601 'Z' timestamp to a local HH:MM:SS string."""
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return dt.astimezone().strftime("%H:%M:%S")
    except (ValueError, AttributeError):
        return value or ""


def parse_local_date(value: str) -> str:
    """Convert a UTC ISO 8601 'Z' timestamp to a local long-form date."""
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return dt.astimezone().strftime("%A, %B %-d, %Y")
    except (ValueError, AttributeError):
        return ""


def load_entries(path: Path) -> list[dict]:
    """Read a JSONL file into a list of records, skipping malformed lines."""
    entries: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return entries


def esc(value: object) -> str:
    """HTML-escape any value for safe insertion into the document."""
    return html.escape("" if value is None else str(value))


def render_row(entry: dict) -> str:
    """Render a single log entry as an HTML row with collapsible detail."""
    time = esc(parse_local_time(entry.get("ts", "")))
    tool = esc(entry.get("tool", "unknown"))
    target = esc(entry.get("target", ""))
    cwd = entry.get("cwd", "")
    cwd_short = esc(Path(cwd).name if cwd else "")
    payload = esc(entry.get("input", ""))
    result = esc(entry.get("result", ""))

    detail = ""
    if payload or result:
        body = ""
        if payload:
            body += f'<div class="k">input</div><pre>{payload}</pre>'
        if result:
            body += f'<div class="k">result</div><pre>{result}</pre>'
        detail = (
            "<details><summary>detail</summary>"
            f'<div class="detail">{body}</div></details>'
        )

    return (
        '<div class="row">'
        f'<span class="time">{time}</span>'
        f'<span class="tool">{tool}</span>'
        f'<span class="target">{target}</span>'
        f'<span class="cwd">{cwd_short}</span>'
        f"{detail}"
        "</div>"
    )


STYLE = f"""
* {{ box-sizing: border-box; }}
body {{
  margin: 0; background: {BG}; color: {TEXT};
  font-family: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, monospace;
  font-size: 13px; line-height: 1.5;
}}
.wrap {{ max-width: 1100px; margin: 0 auto; padding: 40px 24px 80px; }}
header {{ border-bottom: 1px solid {LINE}; padding-bottom: 24px; margin-bottom: 8px; }}
h1 {{
  font-family: "Sora", ui-sans-serif, system-ui, sans-serif;
  font-weight: 600; font-size: 26px; margin: 0 0 4px;
  background: linear-gradient(90deg, {TEAL}, {BLUE});
  -webkit-background-clip: text; background-clip: text; color: transparent;
}}
.meta {{ color: {MUTED}; font-size: 12px; }}
.meta b {{ color: {TEXT}; font-weight: 600; }}
.stats {{ display: flex; gap: 28px; margin-top: 16px; }}
.stat .n {{
  font-family: "Sora", system-ui, sans-serif; font-size: 22px; font-weight: 600; color: {TEAL};
}}
.stat .l {{ color: {MUTED}; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }}
.row {{
  display: grid;
  grid-template-columns: 78px 110px 1fr 140px;
  gap: 12px; align-items: baseline;
  padding: 7px 0; border-bottom: 1px solid {LINE};
}}
.time {{ color: {MUTED}; }}
.tool {{
  color: {TEAL}; font-weight: 600; border-left: 2px solid {BLUE}; padding-left: 8px;
}}
.target {{ color: {TEXT}; word-break: break-all; }}
.cwd {{ color: {MUTED}; text-align: right; word-break: break-all; }}
details {{ grid-column: 1 / -1; margin: 4px 0 2px; }}
summary {{ color: {BLUE}; cursor: pointer; font-size: 12px; width: max-content; }}
.detail {{ margin: 8px 0 4px; padding: 12px; background: {PANEL}; border: 1px solid {LINE}; border-radius: 6px; }}
.k {{ color: {MUTED}; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; margin: 6px 0 2px; }}
pre {{ margin: 0 0 8px; white-space: pre-wrap; word-break: break-word; color: {TEXT}; }}
.empty {{ color: {MUTED}; padding: 40px 0; }}
"""


def render_html(entries: list[dict], session: str) -> str:
    """Build the full HTML document for a session's entries."""
    first_ts = entries[0].get("ts", "") if entries else ""
    date_label = parse_local_date(first_ts)
    cwds = {e.get("cwd", "") for e in entries if e.get("cwd")}
    project = ", ".join(sorted(Path(c).name for c in cwds)) or "unknown"
    tools = {e.get("tool", "") for e in entries if e.get("tool")}

    rows = "\n".join(render_row(e) for e in entries) or (
        '<div class="empty">No entries recorded for this session.</div>'
    )

    return (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>Claude session {esc(session)}</title>"
        '<link rel="preconnect" href="https://fonts.googleapis.com">'
        '<link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600&display=swap" rel="stylesheet">'
        f'<style>{STYLE}</style></head><body><div class="wrap">'
        "<header>"
        "<h1>Claude Code session log</h1>"
        f'<div class="meta"><b>{esc(date_label)}</b> &nbsp; project <b>{esc(project)}</b> &nbsp; session <span>{esc(session)}</span></div>'
        '<div class="stats">'
        f'<div class="stat"><div class="n">{len(entries)}</div><div class="l">actions</div></div>'
        f'<div class="stat"><div class="n">{len(tools)}</div><div class="l">tools used</div></div>'
        "</div>"
        "</header>"
        f"{rows}"
        "</div></body></html>"
    )


def render_file(path: Path) -> Path:
    """Render one JSONL log to a sibling .html file and return its path."""
    if not path.is_file():
        raise FileNotFoundError(f"log file not found: {path}")
    entries = load_entries(path)
    out = path.with_suffix(".html")
    out.write_text(render_html(entries, path.stem), encoding="utf-8")
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2

    arg = argv[0]
    if arg == "--all":
        files = sorted(LOG_DIR.glob("*.jsonl"))
        if not files:
            print(f"no .jsonl logs in {LOG_DIR}", file=sys.stderr)
            return 1
        for f in files:
            out = render_file(f)
            print(out)
        return 0

    out = render_file(Path(arg))
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
