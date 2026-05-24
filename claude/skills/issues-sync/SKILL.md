---
name: issues-sync
description: Migrate an existing `issues.md` to the current canonical format defined by the `issues` skill. Diffs the file against the canonical structure, prints a punch list of what would change, and applies on confirm. Does not commit — the user reviews `git diff` first. Use when the user types `/issues-sync` or says "update issues to the new format / migrate this issues file / bring issues.md up to date".
---

# /issues-sync

When the canonical format for `issues.md` evolves, run this verb to
bring an existing file up to date. This skill is the *migration* verb:
its body explicitly enumerates the current canonical structure so the
comparison is mechanical.

**Re-edit this skill's body whenever the format changes** — the
canonical structure listed below is what the comparison is against.

## Inputs

- None. Operates on `issues.md` at the repo root.

## Steps

1. Defer to the `issues` skill for the format reference (cross-check).
2. Read `issues.md`. If it doesn't exist, stop and point to
   `/issues-init`.
3. Build a punch list by comparing the file against the canonical
   structure (below). Each finding is one line: what's wrong + how it
   would be fixed.
4. Print the punch list. If nothing to change, report "already in
   sync" and stop.
5. Ask once: "apply?"
6. On yes: apply edits in a single pass; do not commit (the user
   commits manually once they've reviewed `git diff`). On no: leave
   the file untouched, exit.

## Canonical structure (current as of the issues skill revision)

A conformant `issues.md` has:

- Title: `# <Project> backlog`.
- Intro paragraph naming the prefix and stating IDs are permanent.
- Header line containing the next-free pointer:
  `currently **PREFIX###** is next`.
- `## Contents` block with anchor links.
- `## Active backlog` with one or more `### <Area>` subheadings
  (area-based, *not* phase-based).
- `## Future / longer-term` (may be empty).
- `## Done` (reverse-chronological).
- Every checkable item: `- [ ] **PREFIX###** — <description>` or
  `- [x] **PREFIX###** — <description>` (3-digit zero-padded ID).
- Completion uses `[x]` only — never combined with `~~strikethrough~~`.
- Resolution notes: blank line below the item, content indented 6
  spaces to render as a stacked paragraph.

## Migrations this skill handles

- Phase-based section headers (`### Phase 1`) → area-based (ask the
  user for the right area names).
- Strikethrough completion (`~~text~~`) collapsed to `[x]` only.
- Resolution notes on the same line as the item → reformatted as a
  blank-line + 6-space-indent paragraph.
- Missing next-free pointer → computed from the highest assigned ID
  and inserted into the header.
- Done items sprinkled through Active → moved to the Done section.
- Missing `## Contents` block → inserted.
- IDs without the bold/em-dash format → reformatted to
  `**PREFIX###** — `.

## What NOT to do

- Don't commit. The user reviews `git diff` and commits manually —
  format migrations can be subtle.
- Don't change item IDs. Even if the numbering is "wrong", IDs are
  immutable.
- Don't delete items. Even if an item looks redundant, leave it; this
  skill is a *format* migration.
- Don't add or remove content beyond what the format requires.

## When this skill loads

Auto-load when:

- The user types `/issues-sync`.
- The user says "update issues to the new format / migrate this
  issues file / bring issues.md up to date".
