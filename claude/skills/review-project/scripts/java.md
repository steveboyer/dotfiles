# Reading the Java reports

`java.sh` writes these into `REPORTS_DIR`. Files ending in `.note.txt` mean the check was skipped —
read them to learn what tool or build step is missing. Files ending in `.err` are captured stderr.

## `java-filelength.csv`
Raw line count per `.java` file, **sorted longest first**.

| column | meaning |
|---|---|
| `lines` | total lines in the file |
| `path`  | absolute file path |
| `flag`  | `OVER_400` when past the type/file threshold |

Length alone isn't a defect — use it to find god-class candidates, then confirm with `java-pmd.csv`.

## `java-duplication.csv` (PMD CPD)
One row per duplicated line within a clone group. PMD's CPD CSV starts with a `lines,tokens`
header for each clone block, followed by the occurrences. Practically: **bigger `tokens`/`lines`
= worse**. Group rows by clone block; report the largest blocks and the files they span.

## `java-pmd.csv` (PMD check)
Standard PMD CSV. Key columns:

| column | meaning |
|---|---|
| `File` | source file |
| `Line` | location |
| `Rule` | which rule fired |
| `Description` | the specific measurement (e.g. "method has NCSS 73") |
| `Priority` | PMD priority 1 (highest) – 5 |

Rule → rubric mapping:
- `CyclomaticComplexity`, `CognitiveComplexity`, `NPathComplexity` → complexity (> 10 method).
- `NcssCount` → method (> 50) / class (> 400) size, measured in statements (NCSS), a proxy for lines.
- `GodClass`, `TooManyMethods`, `TooManyFields` → god-class / SRP signal.
- `CouplingBetweenObjects`, `ExcessiveImports` → coupling signal for the SOLID/KISS judgment.

## `java-cycles.csv` (jdeps → Tarjan SCC)
Each row is one **package cycle** (strongly-connected component of size > 1) among *project-internal*
packages only (JDK/third-party edges are filtered out).

| column | meaning |
|---|---|
| `cycle_id` | sequential id |
| `size` | number of packages in the cycle |
| `packages` | members joined by ` <-> ` |

A single row `0 / no package cycles detected` means clean. **Every cycle is high severity.**
Companion `java-edges.csv` holds the raw internal `from,to` package edges if you need to explain the
path. (Tip the user that ArchUnit can enforce no-cycles as a unit test if they want a permanent gate.)

## `java-coverage.csv` (JaCoCo, if present)
Derived from an existing `jacoco.csv`; sorted **lowest coverage first**.

| column | meaning |
|---|---|
| `coverage_pct` | instruction coverage % |
| `package` / `class` | identity |
| `flag` | `UNDER_60` below the floor |

Absent → `java-coverage.note.txt` (needs `mvn test` with the JaCoCo plugin).
