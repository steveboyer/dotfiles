---
name: issues-init
description: Initialize a new `issues.md` in a project that doesn't have one. Picks a 2–4 letter prefix from the repo name, writes the canonical structure, adds a pointer line to `CLAUDE.md` (creating it if missing), and commits both files. Use when the user types `/issues-init` or says "set up an issues file / initialize the backlog / start tracking issues in this repo".
---

# /issues-init

Stand up an `issues.md` in a new project, ready for the verb skills to
use. This is a one-time operation per repo.

## Inputs

- Optional: a desired prefix (2–4 letters). If omitted, derive from the
  repo directory name (e.g., `macrosight` → `MS`, `foo-bar` → `FB`).
  If the derivation is ambiguous, ask.

## Steps

1. Verify `issues.md` does not already exist at the repo root. If it
   does, stop and suggest `/issues-sync` instead.
2. Pick the prefix (see Inputs). Confirm with the user before writing
   if the derivation isn't obvious.
3. Write `issues.md` at the repo root with the canonical structure:
   - Title line: `# <Project> backlog` (derive project name from repo).
   - One-paragraph intro explaining IDs are permanent and naming the
     prefix.
   - Header line: `New items take the next free number (currently
     **PREFIX001** is next).`
   - `## Contents` block with anchor links to the three sections.
   - `## Active backlog` with one placeholder area subheading (e.g.,
     `### General`).
   - `## Future / longer-term`.
   - `## Done` with the note "(Most recent first; ID order is
     reverse-chronological.)".
4. Update `CLAUDE.md` at the repo root:
   - If `CLAUDE.md` exists, append a short pointer line near the top
     (after the existing intro/purpose section): "Backlog: see
     `issues.md` (single source of truth for what's done, in progress,
     and planned)."
   - If `CLAUDE.md` doesn't exist, create a minimal one pointing to
     `issues.md`.

## Confirm + commit

5. Stage `issues.md` and `CLAUDE.md`.
6. Print the proposed commit message (`Initialize issues.md backlog
   (prefix PREFIX)`) and `git diff --cached --stat`.
7. Ask once: "commit?"
8. On yes: commit. On no: leave staged, exit.

## What NOT to do

- Don't overwrite an existing `issues.md` — bail and point to
  `/issues-sync`.
- Don't pre-populate items unless the user asks; an empty backlog is
  the right starting state.
- Don't use phase headers (`Phase 1`, `Phase 2`) — areas only.
- Don't pick a generic prefix like `ID` or `ITEM`; prefer something
  derived from the project.
- Don't add a `Co-Authored-By` line.

## When this skill loads

Auto-load when:

- The user types `/issues-init`.
- The user says "set up an issues file / initialize the backlog /
  start tracking issues in this repo" in a project that doesn't yet
  have one.
