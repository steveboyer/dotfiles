---
name: issue-do
description: Take an existing backlog ID, do the work across the code, then mark the item `[x]` in `issues.md` with a resolution note. Does NOT commit — the user reviews diffs first. Use when the user types `/issue-do` or says "do MS045 / work on MS018 / tackle this issue / let's knock out MS022".
---

# /issue-do

Take an existing item by ID, perform the work, then update `issues.md`
to reflect completion. The skill ends with a dirty working tree — the
user reviews the diff and ships via `/issue-commit` or commits manually.

This is the verb you'll use most.

## Inputs

- The ID to work on (e.g., `MS045`).

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md`, find
   the item by ID, and capture its full text (description + any
   continuation lines).
2. Do the work in the code — read whatever context you need, make edits,
   run tests if applicable.
3. Draft a resolution paragraph: 2–6 sentences covering the *what*
   (files/services touched, in backticks) and the *why-non-obvious*
   (caveats, alternative considered and rejected, follow-ups). Names
   matter — make it useful for future-Claude six months from now.
4. **Pause once.** Show the drafted resolution note and ask the user to
   confirm or edit before touching `issues.md`. This is the only
   interactive step.
5. On confirm:
   - Change `- [ ]` → `- [x]` (no strikethrough).
   - Insert the resolution note as a new paragraph in the same list
     item: blank line, then 6-space indent.
   - Move the item to the top of the Done section.
6. Do NOT commit. Report what was changed and remind the user to run
   `/issue-commit` (or commit manually) once they've validated.

## What NOT to do

- Don't commit. That's the whole point of this verb — the user
  validates first.
- Don't touch the resolution note's indentation rules (6 spaces). They
  matter for renderer compatibility.
- Don't renumber IDs.
- Don't combine `[x]` with strikethrough.
- Don't skip the pause at step 4 — the resolution note is the durable
  artifact and the user should see it before it lands.

## When this skill loads

Auto-load when:

- The user types `/issue-do`.
- The user says "do MS045 / work on MS018 / tackle this issue / let's
  knock out MS022" or otherwise references an existing ID as the target
  of work.
