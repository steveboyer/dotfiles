# Reading the Swift reports

`swift.sh` writes these into `REPORTS_DIR`. Files ending in `.note.txt` mean the check was skipped —
read them for the missing tool or build step. Files ending in `.err` are captured stderr.

## `swift-filelength.csv`
Raw line count per `.swift` file, **sorted longest first** (build/vendor dirs excluded).

| column | meaning |
|---|---|
| `lines` | total lines |
| `path`  | absolute file path |
| `flag`  | `OVER_400` past the file threshold |

## `swift-lint.csv` (SwiftLint, focused config)
Only four rules are enabled, each tuned to the rubric thresholds:

| column | meaning |
|---|---|
| `rule` | `function_body_length` (> 50), `type_body_length` (> 400), `file_length` (> 400), `cyclomatic_complexity` (> 10) |
| `severity` | always `warning` here (error level is set absurdly high so everything surfaces as one tier) |
| `line` | location |
| `reason` | the measured value, e.g. "Function body should span 50 lines or less: currently 88" |
| `file` | source file |

`swift-lint.json` is the raw reporter output. `swift-unused.note.txt` explains why the
`unused_declaration` analyzer rule is deferred to Periphery.

## `swift-duplication.csv` (jscpd)
One row per clone pair, **sorted by token count desc** (largest clone first).

| column | meaning |
|---|---|
| `tokens` | duplicated token count (≥ 100) |
| `lines` | duplicated line span |
| `fileA` / `startA` | first occurrence |
| `fileB` / `startB` | second occurrence |

Raw report: `jscpd/jscpd-report.json`.

## `swift-deadcode.csv` (Periphery — best effort)
Periphery **builds the project**, so this can be absent (no resolvable scheme, signing, or a build
failure) → see `swift-deadcode.note.txt` / `periphery.err`.

| column | meaning |
|---|---|
| `kind` | declaration kind (class, function, property, …) |
| `name` | symbol name |
| `line` / `file` | location |

Treat unused *public* API as a stronger signal than unused private helpers.

## `swift-coverage.csv` (xccov, if an .xcresult exists)
From the most recent `.xcresult` (project dir or DerivedData), **sorted lowest first**.

| column | meaning |
|---|---|
| `coverage_pct` | line coverage % |
| `file` | source file |
| `flag` | `UNDER_60` below the floor |

Absent → `swift-coverage.note.txt` (run the test suite first).

## `swift-performance.csv` (heuristic — confirm in code)
Pattern-matched performance smells. **Every row is a candidate, not a confirmed defect** — open the
file at `line` and judge. An empty `no ... matched` row means nothing tripped the heuristics.

| column | meaning |
|---|---|
| `check` | smell category (below) |
| `severity` | heuristic severity hint (high/medium) |
| `file` / `line` | location (`line` 0 = a file-level finding) |
| `match` | the offending line, often with an inline `// hint` |

Checks: `swiftdata-query`, `n-plus-1`, `main-actor-blocking`, `inline-data-blob`, `base64-cost`,
`heavy-view-compute`, `onchange-cascade`, `search-as-you-type`. Detection is regex + brace-depth
(no type info), so already-bounded `@Query` / harmless `.map` chains will surface as false positives —
confirm before reporting. See the SKILL rubric for the fix guidance per check.

## `swift-cycles.csv` + `swift-imports.csv` (SUSPECTED — manual)
There is **no reliable Swift cycle detector**. `swift-cycles.csv` records what *was* obtainable: the
SPM external dependency graph (`spm-deps.json`) and a reminder that intra-target type cycles are
invisible to import analysis. `swift-imports.csv` is a per-file `file → imports` list for hand-graphing
module relationships. **Confirm any suspected cycle by reading the code before reporting it as high
severity.**
