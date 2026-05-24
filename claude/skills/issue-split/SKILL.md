---
name: issue-split
description: Split one backlog item into two with cross-references. Original keeps its ID, the sibling takes the next free ID and bumps the pointer. Commits only the `issues.md` change. Use when the user types `/issue-split` or says "split MS045 / this issue is really two things / fork off the X part of MS018".
---

# /issue-split

When an issue turns out to contain two distinct concerns, split it
cleanly so each half can be tracked independently. Each half mentions
the sibling so the lineage is visible.

## Inputs

- The ID to split (e.g., `MS045`).
- Optional: the user's notes on how to split. If absent, propose a
  split based on the item text and ask the user to confirm before
  editing.

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md`.
2. Find the item by ID. Parse the next-free pointer.
3. Propose the split: which concern stays on the original ID
   (whichever feels most "the original") and what the sibling concern
   is. Wait for confirmation before continuing.
4. On confirm:
   - Rewrite the original item with the narrower scope, appending a
     clause: `(split out PREFIX(###+1))`.
   - Insert a new item in the same section with the sibling concern:
     `- [ ] **PREFIX(###+1)** — <description> (split out from PREFIX###)`.
   - Bump the next-free pointer.

## Confirm + commit

5. Stage `issues.md`.
6. Print the proposed commit message (`Split PREFIX### into PREFIX###
   + PREFIX(###+1)`) and `git diff --cached -- issues.md`.
7. Ask once: "commit?"
8. On yes: commit. On no: leave staged, exit.

## What NOT to do

- Don't renumber the original item — its ID stays.
- Don't split an item that's already in Done; that's history, not work.
- Don't omit the cross-reference clauses — they're the only way the
  split shows up when you grep later.
- Don't split into three at once. If you need three, split once, then
  again.
- Don't add a `Co-Authored-By` line.

## When this skill loads

Auto-load when:

- The user types `/issue-split`.
- The user says "split MS045 / this issue is really two things / fork
  the X part of MS018 into its own item".
