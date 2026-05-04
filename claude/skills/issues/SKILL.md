---
name: issues
description: Maintain a per-project `issues.md` backlog with permanent prefixed IDs (e.g., MS001, FOO042). Use when the user asks to initialize a project's issues file, add a new item, mark an item complete, split an item, reorganize the backlog, or reference work by ID. Auto-invoke whenever a file named `issues.md` is being read, written, or referenced — this skill is the source of truth for that file's conventions.
---

# Issues backlog skill

A repo-resident `issues.md` is the single source of truth for a project's
backlog and history. Every item has a permanent ID. Items move from Active to
Done; IDs never change.

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

### Initialize in a new project

1. Choose a 2–4 letter prefix derived from the project name (e.g., `macrosight`
   → `MS`; `repo-name` → `RN`). Confirm with the user if ambiguous.
2. Create `issues.md` at the repo root using the structure above. Start the
   "next free" pointer at `PREFIX001`.
3. Sections: at minimum `Active backlog` (with at least one area subheading),
   `Future / longer-term`, and `Done`. Add area subheadings as they accrue.
4. Add a short pointer in the project's `CLAUDE.md` (create one if missing):
   "Backlog: see `issues.md` (single source of truth for what's done, in
   progress, and planned)."
5. If superseding existing spec or planning docs, mark them as historical in
   `CLAUDE.md` rather than deleting.

### Add a new item

1. Read `issues.md` to find the current "next free" `PREFIX###` value in the
   header.
2. Pick the right section: `Active backlog > <area>`, or `Future` if it's
   longer-term, or `Done` (with a resolution note) if you're recording
   already-finished work.
3. Add the item: `- [ ] **PREFIX###** — <description>`. Wrap continuation
   lines at the content column (6-space indent).
4. Bump the "next free" pointer in the header to `PREFIX(###+1)`.
5. New items go at the end of the relevant section unless prioritization
   suggests otherwise.

### Mark an item complete

1. Change `- [ ]` → `- [x]`. **Do not** also wrap in strikethrough.
2. Add a resolution note as a new paragraph inside the same list item: blank
   line, then indent to the content column. Briefly cover the *what* (which
   files/feature) and the *why-non-obvious* (caveats, alternative considered
   and rejected, follow-ups).
3. Move the item to the top of the Done section (Done is reverse-chronological;
   most recent at the top).
4. Don't reorder or edit other items' IDs.

### Split an item

When an issue actually contains two distinct concerns:

1. Keep the original ID on one half (whichever feels more "the original").
2. Assign a new ID from the next-free pointer for the other half.
3. Bump next-free.
4. Cross-reference: each item's text should mention the sibling ID in a
   short clause ("split out from MS045").

### Close without doing the work

If an item is no longer relevant or won't be done:

1. Mark `[x]` and move to Done as usual.
2. Resolution note: state *why closed*. ("Couldn't reproduce after MS014
   landed", "superseded by MS018", "out of scope, won't do".)

### Renumber / reassign IDs

Don't. IDs are immutable. If a numbering mistake is made (e.g., two items
got the same ID), prefer to add an explanatory note than to renumber.

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
