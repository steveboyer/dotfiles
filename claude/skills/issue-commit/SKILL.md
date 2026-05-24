---
name: issue-commit
description: Wrap up validated work by committing the staged changes with a message referencing the issue ID(s) in the subject. Verifies each ID is `[x]` in `issues.md` with a resolution note before committing. Use when the user types `/issue-commit` or says "commit this / ship it / commit MS045 / wrap up MS018 / land MS045 + MS046".
---

# /issue-commit

Ship validated work. Partner verb to `/issue-do` and `/issue-now`:
those leave the tree dirty so the user can validate; this one commits.

Also stands alone — if the user did the work manually but didn't
update `issues.md`, this skill fills in the missing pieces (with
confirmation) and then commits.

## Inputs

- One or more IDs being shipped (e.g., `MS045` or `MS045 MS046`).
- Optional: an override commit message. If omitted, this skill drafts
  one in the project's existing style.

## Steps

1. Defer to the `issues` skill for file format. Read `issues.md`.
2. For each ID:
   - Verify the item is in Done with `[x]`. If still `[ ]` in Active,
     prompt the user to confirm the work is actually finished, then
     mark `[x]` and move it to Done.
   - Verify a resolution paragraph is present. If missing, draft one
     from `git diff --cached` + `git diff` and ask the user to confirm
     before adding it.
3. Run `git log -n 10 --oneline` to learn the project's commit-message
   style (subject case, length, verb prefix like "Add"/"Fix"/etc.).
4. Draft a commit message:
   - Subject: short, referencing the ID(s), matching repo style.
     Examples:
     `Fix MS045: quantity not applied when logging from Saved Foods`,
     `Add three-tier data wipe (MS047) under Profile > Danger zone`,
     `Land MS045 + MS046: alert history grouping`.
   - Body: optional; if the work is non-obvious, summarize *why*. The
     full *what* lives in the resolution note in `issues.md`.

## Confirm + commit

5. Stage `issues.md` alongside whatever's already staged.
6. Print the drafted commit message and `git diff --cached --stat`.
7. Ask once: "commit?"
8. On yes: commit using a HEREDOC for the message. On no: leave
   staged, exit.

## What NOT to do

- Don't commit if any ID isn't `[x]` and the user can't confirm the
  work is done.
- Don't pass `--no-verify` or `--no-gpg-sign`.
- Don't add a `Co-Authored-By` line (per global git rules).
- Don't amend an existing commit; always create a new one.
- Don't push.

## When this skill loads

Auto-load when:

- The user types `/issue-commit`.
- The user says "commit MS045 / wrap up MS018 / ship this / land MS045
  + MS046" after work has been done.
