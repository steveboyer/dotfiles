#!/usr/bin/env bash
# review-project :: Java / Maven / Gradle health analyzer
#
# Usage:   java.sh <project-root> [reports-dir]
# Output:  normalized CSV reports under a temp dir; prints "REPORTS_DIR=<path>" last.
#
# Design notes:
#   * set -u only (no -e/pipefail) so one tool's failure never aborts the run.
#   * Every check is guarded; a missing tool / un-buildable module degrades to a
#     "<check>.note.txt" file rather than a crash.
#   * Resolved against PMD 7.x (pmd check / pmd cpd CLI) and jdeps 25.
set -u

# ---- thresholds (tunable) --------------------------------------------------
METHOD_NCSS=50        # statements per method before flagged
CLASS_NCSS=400        # statements per class before flagged
FILE_LINES=400        # raw lines per file before flagged
CYCLO_METHOD=10       # cyclomatic complexity per method
CYCLO_CLASS=40        # summed cyclomatic complexity per class
CPD_TOKENS=100        # minimum duplicate token run
COV_FLOOR=60          # coverage % floor

# ---- args / setup ----------------------------------------------------------
ROOT="${1:-$PWD}"
ROOT="$(realpath "$ROOT" 2>/dev/null || python3 -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$ROOT")"
REPORTS="${2:-$(mktemp -d "${TMPDIR:-/tmp}/review-project-java.XXXXXX")/reports}"
mkdir -p "$REPORTS"

log() { printf '[java.sh] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

log "project root : $ROOT"
log "reports dir  : $REPORTS"

# ---- discover source roots & build system ----------------------------------
# All Maven/Gradle main-source roots (skip test sources for length/complexity).
SRC_ROOTS=()
while IFS= read -r d; do SRC_ROOTS+=("$d"); done < <(
  find "$ROOT" -type d -path '*/src/main/java' -not -path '*/target/*' -not -path '*/build/*' 2>/dev/null
)
# Fallback: any dir containing .java if the standard layout isn't used.
if [ "${#SRC_ROOTS[@]}" -eq 0 ]; then
  while IFS= read -r d; do SRC_ROOTS+=("$d"); done < <(
    find "$ROOT" -type f -name '*.java' -not -path '*/target/*' -not -path '*/build/*' 2>/dev/null \
      | xargs -I{} dirname {} 2>/dev/null | sort -u | head -1
  )
fi
log "source roots : ${#SRC_ROOTS[@]}"

BUILD=none
[ -f "$ROOT/pom.xml" ] && BUILD=maven
{ [ -f "$ROOT/build.gradle" ] || [ -f "$ROOT/build.gradle.kts" ]; } && [ "$BUILD" = none ] && BUILD=gradle
log "build system : $BUILD"

# ===========================================================================
# 1. Raw file length  ->  java-filelength.csv
# ===========================================================================
{
  echo "lines,path,flag"
  find "$ROOT" -type f -name '*.java' -not -path '*/target/*' -not -path '*/build/*' 2>/dev/null \
    | while IFS= read -r f; do
        n=$(wc -l < "$f" | tr -d ' ')
        flag=""; [ "$n" -gt "$FILE_LINES" ] && flag="OVER_${FILE_LINES}"
        printf '%s,%s,%s\n' "$n" "$f" "$flag"
      done | sort -t, -k1 -nr
} > "$REPORTS/java-filelength.csv"
log "wrote java-filelength.csv"

# ===========================================================================
# 2. Duplication (CPD)  ->  java-duplication.csv
# ===========================================================================
if have pmd && [ "${#SRC_ROOTS[@]}" -gt 0 ]; then
  CPD_ARGS=(cpd --minimum-tokens "$CPD_TOKENS" --language java --format csv --no-fail-on-violation)
  for s in "${SRC_ROOTS[@]}"; do CPD_ARGS+=(--dir "$s"); done
  if pmd "${CPD_ARGS[@]}" > "$REPORTS/java-duplication.csv" 2>"$REPORTS/java-duplication.err"; then
    log "wrote java-duplication.csv"
  else
    log "cpd exited non-zero (often = duplicates found); report kept"
  fi
  [ -s "$REPORTS/java-duplication.err" ] || rm -f "$REPORTS/java-duplication.err"
else
  echo "pmd not installed or no source roots; skipped CPD duplication." > "$REPORTS/java-duplication.note.txt"
  log "skipped CPD (pmd missing or no sources)"
fi

# ===========================================================================
# 3. Complexity / design (PMD check)  ->  java-pmd.csv
# ===========================================================================
if have pmd && [ "${#SRC_ROOTS[@]}" -gt 0 ]; then
  RULESET="$REPORTS/java-ruleset.xml"
  cat > "$RULESET" <<XML
<?xml version="1.0"?>
<ruleset name="review-project"
    xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0 https://pmd.sourceforge.io/ruleset_2_0_0.xsd">
  <description>review-project Java health thresholds</description>
  <rule ref="category/java/design.xml/CyclomaticComplexity">
    <properties>
      <property name="methodReportLevel" value="${CYCLO_METHOD}"/>
      <property name="classReportLevel" value="${CYCLO_CLASS}"/>
    </properties>
  </rule>
  <rule ref="category/java/design.xml/NcssCount">
    <properties>
      <property name="methodReportLevel" value="${METHOD_NCSS}"/>
      <property name="classReportLevel" value="${CLASS_NCSS}"/>
    </properties>
  </rule>
  <rule ref="category/java/design.xml/CognitiveComplexity"/>
  <rule ref="category/java/design.xml/NPathComplexity"/>
  <rule ref="category/java/design.xml/GodClass"/>
  <rule ref="category/java/design.xml/CouplingBetweenObjects"/>
  <rule ref="category/java/design.xml/ExcessiveImports"/>
  <rule ref="category/java/design.xml/TooManyMethods"/>
  <rule ref="category/java/design.xml/TooManyFields"/>
</ruleset>
XML
  PMD_ARGS=(check --no-cache --no-fail-on-violation -R "$RULESET" -f csv -r "$REPORTS/java-pmd.csv")
  for s in "${SRC_ROOTS[@]}"; do PMD_ARGS+=(-d "$s"); done
  if pmd "${PMD_ARGS[@]}" 2>"$REPORTS/java-pmd.err"; then
    log "wrote java-pmd.csv"
  else
    log "pmd check exited non-zero; report kept if produced"
  fi
  [ -s "$REPORTS/java-pmd.err" ] || rm -f "$REPORTS/java-pmd.err"
else
  echo "pmd not installed or no source roots; skipped PMD complexity check." > "$REPORTS/java-pmd.note.txt"
fi

# ===========================================================================
# 4. Cyclic dependencies (jdeps + Tarjan SCC)  ->  java-cycles.csv
# ===========================================================================
# jdeps needs compiled .class files. Collect target/classes (Maven) or
# build/classes (Gradle); test-compile once if absent (unless REVIEW_NO_BUILD=1).
collect_classes() {
  CLASS_DIRS=()
  while IFS= read -r d; do CLASS_DIRS+=("$d"); done < <(
    find "$ROOT" -type d \( -path '*/target/classes' -o -path '*/build/classes/java/main' \) 2>/dev/null
  )
}
collect_classes
if [ "${#CLASS_DIRS[@]}" -eq 0 ] && [ "$BUILD" = maven ] && [ "${REVIEW_NO_BUILD:-0}" != 1 ] && have mvn; then
  log "no compiled classes; running 'mvn test-compile' (set REVIEW_NO_BUILD=1 to skip)"
  mvn -q -DskipTests -f "$ROOT/pom.xml" test-compile >"$REPORTS/java-build.log" 2>&1 \
    && log "build ok" || log "build failed (see java-build.log)"
  collect_classes
fi

if have jdeps && [ "${#CLASS_DIRS[@]}" -gt 0 ]; then
  # Emit package->package edges, keep only project-internal (both ends are
  # packages we compiled), run SCC; components of size > 1 are cycles.
  jdeps -verbose:package "${CLASS_DIRS[@]}" 2>"$REPORTS/java-jdeps.err" \
    | awk '/->/ {f=$1; t=$3; if (f ~ /\./ && t ~ /\./) print f","t}' \
    | sort -u > "$REPORTS/java-edges.csv"
  python3 - "$REPORTS/java-edges.csv" > "$REPORTS/java-cycles.csv" <<'PY'
import sys, csv
edges_path = sys.argv[1]
adj, internal = {}, set()
with open(edges_path) as fh:
    rows = [r for r in csv.reader(fh) if len(r) == 2]
internal = {a for a, _ in rows}                       # left side = our own packages
for a, b in rows:
    if b in internal:                                  # keep internal->internal only
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set())
# Tarjan SCC
idx = {}; low = {}; onst = {}; stack = []; counter = [0]; sccs = []
import sys as _s; _s.setrecursionlimit(10000)
def strongconnect(v):
    idx[v] = low[v] = counter[0]; counter[0] += 1
    stack.append(v); onst[v] = True
    for w in adj.get(v, ()):
        if w not in idx:
            strongconnect(w); low[v] = min(low[v], low[w])
        elif onst.get(w):
            low[v] = min(low[v], idx[w])
    if low[v] == idx[v]:
        comp = []
        while True:
            w = stack.pop(); onst[w] = False; comp.append(w)
            if w == v: break
        sccs.append(comp)
for v in list(adj):
    if v not in idx: strongconnect(v)
w = csv.writer(sys.stdout)
w.writerow(["cycle_id", "size", "packages"])
cid = 0
for comp in sccs:
    if len(comp) > 1:
        cid += 1
        w.writerow([cid, len(comp), " <-> ".join(sorted(comp))])
if cid == 0:
    w.writerow(["", "0", "no package cycles detected"])
PY
  log "wrote java-cycles.csv ($(wc -l < "$REPORTS/java-edges.csv" | tr -d ' ') internal edges)"
  [ -s "$REPORTS/java-jdeps.err" ] || rm -f "$REPORTS/java-jdeps.err"
else
  {
    echo "Cycle analysis skipped — needs compiled classes."
    [ "${#CLASS_DIRS[@]}" -eq 0 ] && echo "No target/classes found. Run 'mvn test-compile' (or unset REVIEW_NO_BUILD)."
    have jdeps || echo "jdeps not on PATH (ships with the JDK)."
  } > "$REPORTS/java-cycles.note.txt"
  log "skipped cycles (no classes or jdeps missing)"
fi

# ===========================================================================
# 5. Coverage (existing JaCoCo report only)  ->  java-coverage.csv
# ===========================================================================
JACOCO=""
while IFS= read -r f; do JACOCO="$f"; break; done < <(
  find "$ROOT" -type f \( -name 'jacoco.csv' -o -path '*/site/jacoco/jacoco.csv' \) 2>/dev/null
)
if [ -n "$JACOCO" ]; then
  # JaCoCo CSV columns: GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,INSTRUCTION_COVERED,...
  {
    echo "coverage_pct,package,class,flag"
    tail -n +2 "$JACOCO" | awk -F, -v floor="$COV_FLOOR" '
      { miss=$4; cov=$5; tot=miss+cov; pct=(tot>0)?(100*cov/tot):0;
        flag=(pct<floor)?"UNDER_"floor:"";
        printf "%.1f,%s,%s,%s\n", pct, $2, $3, flag }' \
      | sort -t, -k1 -n
  } > "$REPORTS/java-coverage.csv"
  log "wrote java-coverage.csv (from $JACOCO)"
else
  echo "No JaCoCo report found. Add the jacoco-maven-plugin and run 'mvn test' to generate target/site/jacoco/jacoco.csv." \
    > "$REPORTS/java-coverage.note.txt"
  log "no JaCoCo report; coverage skipped"
fi

echo "REPORTS_DIR=$REPORTS"
