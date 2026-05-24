---
name: issue-now
description: Add a brand-new item to `issues.md` AND do the work AND mark it `[x]` in one pass — the drive-by-fix workflow. Does NOT commit; user validates first. Use when the user types `/issue-now` or says "do this and log it / drive-by fix / quick fix, record it after / fix and add to Done".
---

# /issue-now

The drive-by combo. The user just thought of something, wants it done,
*and* wants a backlog record of it. This skill assigns the next free
ID, does the work, and writes the item straight into Done with a
resolution note.

Ends with a dirty working tree for review.

## Inputs

- A short description of the fix/feature/change.

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md` and
   parse the next-free pointer from the header.
2. Do the work in the code — read context, make edits, run tests if
   applicable.
3. Draft a resolution paragraph for the new item: 2–6 sentences, files
   in backticks, *why-non-obvious* if relevant.
4. **Pause once.** Show the drafted description (one-liner) and
   resolution note, and ask the user to confirm or edit before touching
   `issues.md`.
5. On confirm:
   - Insert the item directly at the top of Done:
     `- [x] **PREFIX###** — <description>` followed by the resolution
     paragraph (blank line, 6-space indent).
   - Bump the next-free pointer in the header to `PREFIX(###+1)`.
6. Do NOT commit. Report the assigned ID and remind the user to run
   `/issue-commit` (or commit manually) once they've validated.

## What NOT to do

- Don't commit.
- Don't add the item to Active first and then immediately complete it —
  it goes straight to Done in one edit.
- Don't reuse an existing ID.
- Don't skip the resolution note. The whole point of recording a
  drive-by is the *why* surviving in the log.
- Don't combine `[x]` with strikethrough.

## When this skill loads

Auto-load when:

- The user types `/issue-now`.
- The user says "do this and log it / drive-by fix / quick fix, record
  it / fix and add to Done in one go".
