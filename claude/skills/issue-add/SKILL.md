---
name: issue-add
description: Add a new item to the project's `issues.md` backlog and commit only the `issues.md` change. Use when the user types `/issue-add` or says "add an issue / capture a todo / log this for later / add a backlog item". Does not do the work — just records it.
---

# /issue-add

Append a new item to `issues.md`, assign it the next free ID, bump the
pointer, and commit *only* the `issues.md` change. The work itself happens
later via `/issue-do` (or a manual edit followed by `/issue-commit`).

This skill is for capturing — not doing.

## Inputs

- A short description of the new item (free text).
- Optional: which area subheading it belongs under (e.g., "Tracking & input").
  If omitted, infer from the description; if no area fits, ask.
- Optional: `--future` to drop the item into `Future / longer-term` instead
  of `Active backlog`.

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md` at the
   repo root.
2. Parse the next-free pointer from the header
   (`currently **PREFIX###** is next`).
3. Pick the section:
   - `Active backlog > <area>` by default.
   - `Future / longer-term` if `--future` was passed or the description
     reads as longer-term.
   - If the chosen area subheading doesn't exist yet, ask whether to
     create it or use an existing one.
4. Append the line: `- [ ] **PREFIX###** — <description>`. Wrap
   continuation lines at the 6-space content column.
5. Bump the next-free pointer in the header to `PREFIX(###+1)`.

## Confirm + commit

6. Stage `issues.md`: `git add issues.md`.
7. Print the proposed commit message (`Add PREFIX### to backlog: <short
   desc>`) and the output of `git diff --cached -- issues.md`.
8. Ask once: "commit?"
9. On yes: `git commit -m "<message>"`. On no: leave staged, report the
   ID, exit.

## What NOT to do

- Don't do the work itself. If the user wants the work done now too, use
  `/issue-now` instead.
- Don't touch files other than `issues.md`.
- Don't reuse an existing ID — always take the next free one.
- Don't reorder existing items.
- Don't add a `Co-Authored-By` line.

## When this skill loads

Auto-load when:

- The user types `/issue-add`.
- The user says "add an issue / log a todo / capture this for later /
  add to the backlog" without indicating they want it done now.
