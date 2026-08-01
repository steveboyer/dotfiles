---
name: review-project
description: Whole-project health review. Runs static analyzers, then reviews ranked hotspots for cyclic dependencies, duplication, long classes/functions, missing tests, thin comments, and SOLID/KISS violations.
context: fork
agent: Explore
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(${CLAUDE_SKILL_DIR}/scripts/*) Bash(jdeps *) Bash(pmd *) Bash(swiftlint *) Bash(periphery *) Bash(jscpd *)
---

# review-project

A whole-project code-health review. You drive analyzers via the bundled scripts, read the
**normalized reports** they emit (not the whole source tree), then review the ranked hotspots
against the rubric and produce a prioritized findings list.

## Workflow

### 1. Detect language(s)

Look at the project root (default: current working directory).

- **Java** — a `pom.xml`, `build.gradle`, or `build.gradle.kts` anywhere in the tree.
- **Swift** — a `*.xcodeproj`, `*.xcworkspace`, or `Package.swift`.

A repo can be both; run both analyzers.

### 2. Run the analyzer(s)

Each script takes the project root as `$1` and prints `REPORTS_DIR=<path>` on its **last line**.
Capture that path — every report lives under it.

```
${CLAUDE_SKILL_DIR}/scripts/java.sh  <project-root>
${CLAUDE_SKILL_DIR}/scripts/swift.sh <project-root>
```

The scripts log progress to stderr and never abort on a single tool's failure — a missing tool or
an un-buildable module degrades to a `*.note.txt` file explaining what's missing, not a crash.

### 3. Read the reports, not the source tree

`Read`/`Grep` the files under `REPORTS_DIR`. Column meanings are documented in
`scripts/java.md` and `scripts/swift.md` — consult them so your reading is grounded. Only open an
**individual source file** when a report flags it as a hotspot and you need the surrounding code to
write a concrete fix.

### 4. Review the top offenders against the rubric

On a large multi-module codebase, do **not** enumerate every finding. Prioritize:

1. **Cover the cycle report fully** — every cycle matters.
2. **Cover the performance report fully (Swift)** — unbounded queries, N+1, and main-actor blocking
   are high severity; open each candidate and confirm it in the source before reporting.
3. Then the worst N files by **length**, **complexity**, and **duplication** (start at the top of
   each sorted report; ~the top 10–15 across categories is plenty for one pass).
4. Then test gaps and comment quality on the code you've already surfaced.

### 5. Output: a ranked findings list

Group by category, **lead with architecture**, then duplication, then tests, then comments:

1. **Architecture** — cyclic dependencies, god classes, deep coupling.
2. **Performance (Swift)** — unbounded SwiftData queries, N+1, main-actor blocking, heavy view-body
   recompute, inline data blobs (see rubric).
3. **Duplication** — largest clones first.
4. **Tests** — files under the coverage floor, untested public API.
5. **Comments** — missing rationale on non-obvious code.
6. **SOLID / KISS** — the judgment layer (see rubric).

Each finding: `file:location` · **severity** (high/medium/low) · a **concrete fix** (what to do,
not just what's wrong). Order categories as above; within a category, order by severity.

## Rubric and thresholds (tunable)

| Check | Threshold | Severity |
|---|---|---|
| Cyclic dependency (package/module) | any cycle | **high** |
| Duplication | clones > ~100 tokens | by clone size, largest first |
| Function / method length | > 50 lines | medium |
| Type / class length | > 400 lines | medium (→ high if also a god class) |
| Cyclomatic complexity | > 10 | medium (→ high if > 20) |
| Test coverage | file < 60% | medium; **untested public API = high** |
| Comments | judge **quality** on complex/non-obvious code | low–medium |

- **Comments**: density is not the metric. Missing *rationale* on tricky logic counts; trivial
  getters/setters do not. Don't flag well-named self-documenting code for lacking comments.
- **SOLID / KISS**: this is the **judgment layer, not a tool output**. Use the metrics above as
  signal — high coupling (CouplingBetweenObjects / many imports), god classes (GodClass / long +
  many methods), deep nesting (high cyclomatic/cognitive complexity) — then make the call **in
  prose**. Name the principle, point at the evidence, propose the refactor.

### Performance (Swift)

Heuristic candidates land in `swift-performance.csv` — **confirm each in the source**, then judge.
Detection is regex + brace-depth only (no type info), so expect false positives on already-bounded
queries or harmless `.map` chains.

- **`swiftdata-query`** (high) — `@Query` / `FetchDescriptor` / `.fetch(` with no predicate or
  `fetchLimit`: loads every row on each view appear. Fix: add a predicate + `fetchLimit`, or fetch a
  count/aggregate instead of whole rows.
- **`n-plus-1`** (high) — a fetch or relationship access **inside a loop**. Fix: batch into one fetch
  with an `IN`-style predicate, or preload a dictionary keyed by id before the loop.
- **`main-actor-blocking`** (high) — sequential `await` per loop iteration (e.g. day-by-day
  HealthKit backfill). Fix: one range query (`HKStatisticsCollectionQuery`) or `withTaskGroup`
  parallelism; keep typing-driven network (e.g. USDA search) debounced and off the main actor.
- **`inline-data-blob`** (high) — `Data` stored inline on a `@Model`. Fix: write the file to disk and
  keep only a path/URL on the record. **`base64-cost`** (medium) — base64 of large blobs in
  logs/exports; redact or stream rather than inlining.
- **`heavy-view-compute`** (medium) — multi-op collection chains in a `View` file that re-run on
  every re-render. Fix: hoist to a computed-once value, `@State`, or a view model.
- **`onchange-cascade`** (medium) — many `.onChange` handlers / chart-selection triggering full
  re-renders. **`search-as-you-type`** (medium) — work fired on every keystroke; debounce it.

## Notes

- Thresholds live near the top of each script (`java.sh`, `swift.sh`) and in the PMD ruleset / SwiftLint
  config the scripts generate at runtime. Adjust there if the user wants different limits.
- If a script reports a missing tool, surface it in your output and tell the user the install command —
  **do not install anything yourself**.
- Java cycle detection needs compiled classes; `java.sh` will `test-compile` if needed (set
  `REVIEW_NO_BUILD=1` to skip). Coverage is read from an existing JaCoCo report only — never run tests.
- Swift has no strong package-cycle tool. Cross-module cycles are derived from the SPM graph + import
  scan and **flagged as suspected — confirm manually** before reporting as high severity.
