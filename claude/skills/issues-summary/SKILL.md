---
name: issues-summary
description: Summarize the project's `issues.md` backlog at a glance — counts, the active list grouped by area, recent Done items, and the next-free ID pointer. Invoke when the user types `/issues-summary` or asks "summarize issues / what's open / what's left in the backlog / what'd we ship recently". Pairs with the `issues` skill (which maintains the file).
---

# Issues summary skill

Read `issues.md` at the repo root and print a tight, scannable summary of
the backlog. The point is *speed* — the user wants to see the shape of the
project in seconds, not re-read every paragraph.

## Output structure

Produce these sections in order. Skip a section only if it has zero items.

**Header** — one line: total counts (e.g., `28 active · 3 future · 22 done`)
plus the next-free ID pointer in parens (e.g., `(next: MS067)`).

**Active backlog** — group by the area subheadings used in `issues.md`
(`Tracking & input`, `Visualizations & history`, `Polish & UX`, etc.).
Within each group, one line per item:

```
- MS016 — Add a third "Label" option to AddFoodSheet's segmented control…
```

Truncate descriptions to ~80 characters with an ellipsis. The point is the
ID + the topic, not the full text.

**Future / longer-term** — same one-line treatment.

**Recently shipped** — top 5 most recent Done items, one line each, with
the ID and a *very* short description (≤60 chars). This gives the user a
sense of momentum without scrolling.

**At a glance (optional)** — only include this section if you notice
something the user would want flagged, e.g.:

- Active items that have been open a long time (if dates are present)
- Mismatches in the next-free pointer (e.g., MS067 declared but MS066 is
  still the highest assigned)
- Active items that look stale or duplicated

If nothing stands out, omit this section entirely.

## How to do it

1. Always re-read `issues.md` fresh, even if it was already read earlier in
   the conversation. The file may have changed since the last read, and a
   stale summary defeats the point. Never reuse a prior parse.
2. Parse the next-free pointer from the header line (`currently **MS###** is next`).
3. Walk each `- [ ]` and `- [x]` bullet, capturing the ID and the first
   sentence of the description (up to the first period or line break).
4. Group by the area `### Subheader` immediately above each item.
5. Format and print. No tool calls beyond the single `Read`.

## What NOT to do

- Don't rewrite `issues.md` — this skill is read-only.
- Don't list resolution notes for Done items. The IDs are enough; the user
  can grep for detail.
- Don't list every Done item — only the most recent 5. Older work is
  searchable by `git log --grep`.
- Don't add commentary or recommendations unless explicitly asked. The
  user wants a summary, not a strategy doc.
- Don't truncate Active items so aggressively that the topic is unclear.
  The truncation budget is "enough to identify the issue."

## Tone

Terse. The header is one line. Each issue is one line. The whole summary
should fit on one screen for a moderately-sized backlog (≤30 active items).

## When this skill loads

Auto-load whenever:

- The user types `/issues-summary`.
- The user asks to "summarize issues", "what's left", "what's in the
  backlog", "what'd we ship", or similar.

Don't auto-load just because `issues.md` is being read — the `issues`
skill handles that. Only load when the user is explicitly asking for a
*summary* (the read-only digest) rather than to edit the file.
