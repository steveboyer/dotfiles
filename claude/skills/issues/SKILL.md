---
name: issues
description: Source of truth for the per-project `issues.md` backlog format — permanent prefixed IDs (e.g., MS001, FOO042), section structure, completion and resolution-note rules. Auto-invoke whenever a file named `issues.md` is being read, written, or referenced. Operational workflows (add, do, close, complete, split, init, sync) live in companion verb skills — see `/issue-add`, `/issue-do`, `/issue-now`, `/issue-commit`, `/issue-close`, `/issue-split`, `/issues-init`, `/issues-sync`.
---

# Issues backlog skill

A repo-resident `issues.md` is the single source of truth for a project's
backlog and history. Every item has a permanent ID. Items move from Active to
Done; IDs never change.

## See also (verb skills)

Standard operations are exposed as single-purpose verb skills. Use these
instead of editing `issues.md` by hand:

- `/issue-add` — add a new backlog item; commit `issues.md` only.
- `/issue-close` — close without doing the work (won't-do / superseded /
  can't-repro); commit `issues.md` only.
- `/issue-do` — work on an existing ID, mark `[x]` with resolution note.
  Doesn't commit (you validate first).
- `/issue-now` — add + do + complete a brand-new item in one pass.
  Doesn't commit.
- `/issue-commit` — ship validated work: confirm `[x]` and resolution,
  then commit with the ID in the subject.
- `/issue-split` — split one item into two with cross-references.
- `/issues-init` — initialize `issues.md` in a new project.
- `/issues-sync` — migrate an existing `issues.md` to the current format.

This skill remains the source of truth for *what the file looks like*; the
verbs are the source of truth for *how operations execute*.

## Quick reference (the rules that matter)

1. **Every checkable item has an ID** — `- [ ] **PREFIX###** — description`.
   The prefix is per-project (e.g., `MS` for MacroSight). IDs are zero-padded
   to 3 digits and assigned in chronological order (oldest = lowest).
2. **IDs are permanent.** Reordering, editing, or completing an item never
   changes its ID. New items take the next free number, tracked in the file's
   header.
3. **Completion is `[x]` only — never combined with `~~strikethrough~~`.**
   Pick one signal.
4. **Resolution notes go in their own paragraph** under the item: blank line,
   then indent to the content column (6 spaces, matching `- [x] `). This is
   the only universally-portable way to render the task and the note as
   stacked paragraphs in a list item across CommonMark/GFM parsers.
5. **Reference items by ID in conversation and commit messages**
   ("Fix MS045: …"). The ID is what travels.

## File structure

```markdown
# <Project> backlog

This file is the single source of truth for <project>'s backlog and history.

Every item has a permanent ID (`PREFIX###`). Refer to items by ID. New items
take the next free number (currently **PREFIX###** is next). IDs never change
once assigned, even if items are reordered, edited, or completed.

## Contents

- [Active backlog](#active-backlog)
- [Future / longer-term](#future--longer-term)
- [Done](#done)

---

## Active backlog

### <Area 1>
- [ ] **PREFIX001** — …

### <Area 2>
- [ ] **PREFIX002** — …

---

## Future / longer-term

- [ ] **PREFIX###** — …

---

## Done

(Most recent first; ID order is reverse-chronological.)

- [x] **PREFIX###** — …

      Resolution paragraph: blank line above, 6-space indent.
```

Section headers under Active should be by **area** (Tracking, Visualization,
Operational, Polish & UX, etc.), **not by build phase or sprint**. Phases age
out; areas don't.

## Workflows

Mechanics live in the verb skills listed above. This section keeps the
guidance that survives across all verbs.

### Renumber / reassign IDs

Don't. IDs are immutable. If a numbering mistake is made (e.g., two items
got the same ID), prefer to add an explanatory note than to renumber.

### Where new items go

- `Active backlog > <area>` for actionable work.
- `Future / longer-term` for ideas that aren't ready.
- `Done` for already-finished work you're back-filling (with a resolution
  note).

Within a section, new items go at the end unless prioritization suggests
otherwise. Done is reverse-chronological (most recent at the top).

## Tone of resolution notes

Notes should be useful to a future contributor (or future-Claude) who is
re-reading the backlog months later. Aim for:

- Names of files/services involved, in backticks.
- One sentence on the *why* if it isn't obvious from the *what*.
- Mention any caveat that survives the change ("HealthKit auth survives the
  wipe — that lives in iOS Settings").
- Brief; usually 2–6 sentences. Long technical detail belongs in the commit
  message, not the tracker.

## Anti-patterns to avoid

- **Phase-based section headers** (Phase 1, Phase 2…). They go stale fast.
  Group by area instead.
- **Done items sprinkled through the Active section** with strikethrough
  formatting. Move them to the Done section so the top of the file is the
  actionable list.
- **Editing IDs.** Use cross-references and resolution notes instead.
- **Resolution notes appended on the same line** as the task text. Renderers
  collapse the soft break to a space, producing run-on text. Always blank
  line + indent.
- **Combining `[x]` with `~~strikethrough~~`.** Pick `[x]`.

## Commit messages

When committing work that completes one or more items, reference the IDs in
the subject or body:

```
Fix MS045: quantity not applied when logging from Saved Foods
```

```
Add three-tier data wipe (MS047) under Profile > Danger zone
```

This makes the commit log searchable by ID and ties code changes back to the
backlog without any extra tooling.

## When this skill loads

Auto-load whenever:

- The user types `/issues` or asks about adding/completing/splitting items.
- A file named `issues.md` is being read, written, or modified.
- The user references an item by ID (e.g., "do MS045", "what's MS018?").
- The user asks to initialize a backlog or "set up an issues file".

Don't load just because a project has an `issues.md` — only when actively
working with it. Avoids context bloat.
