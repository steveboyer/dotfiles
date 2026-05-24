---
name: issue-close
description: Close an existing backlog item without doing the work (won't-do, superseded, can't-repro). Marks `[x]`, writes a resolution paragraph capturing the reason, moves to Done, and commits only the `issues.md` change. Use when the user types `/issue-close` or says "close MS045 / drop this issue / supersede MS018 / won't-fix".
---

# /issue-close

Mark an item complete *without* doing the work. The resolution note
explains why it's closed (no-longer-relevant, superseded, can't-repro,
out-of-scope).

This is the "ship it as won't-do" verb. For closing after work, use
`/issue-commit`.

## Inputs

- The ID to close (e.g., `MS045`).
- A reason, one of:
  - `won't-do` — out of scope, decided against.
  - `superseded by <ID>` — replaced by another item.
  - `can't-repro` — couldn't reproduce after some other change.
  - `obsolete` — overtaken by events; describe.
  - Free-form reason if none of the above fits.

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md`.
2. Find the item by ID. If it's already in Done, stop and report;
   closing a closed item is a no-op.
3. Change `- [ ]` → `- [x]`. Don't add strikethrough.
4. Add a resolution paragraph below the item: blank line, content
   indented 6 spaces, stating the reason. One sentence is usually
   enough; expand only if the context warrants.
5. Move the item to the top of the Done section.

## Confirm + commit

6. Stage `issues.md`: `git add issues.md`.
7. Print the proposed commit message (`Close PREFIX###: <reason>`) and
   `git diff --cached -- issues.md`.
8. Ask once: "commit?"
9. On yes: commit. On no: leave staged, exit.

## What NOT to do

- Don't combine `[x]` with `~~strikethrough~~`.
- Don't touch files other than `issues.md`.
- Don't close items that *did* get work done — use `/issue-commit` for
  that.
- Don't renumber or edit other items' IDs.
- Don't add a `Co-Authored-By` line.

## When this skill loads

Auto-load when:

- The user types `/issue-close`.
- The user says "close MS045 as won't-do / drop this / supersede MS018 /
  mark as can't-repro" — anything that signals closing without work.
