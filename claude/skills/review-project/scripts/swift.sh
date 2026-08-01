#!/usr/bin/env bash
# review-project :: Swift / Xcode / SPM health analyzer
#
# Usage:   swift.sh <project-root> [reports-dir]
# Output:  normalized CSV/JSON reports under a temp dir; prints "REPORTS_DIR=<path>" last.
#
# Design notes:
#   * set -u only (no -e/pipefail) so one tool's failure never aborts the run.
#   * Every check is guarded; a missing tool / un-buildable target degrades to a
#     "<check>.note.txt" rather than a crash.
#   * Resolved against SwiftLint 0.6x, Periphery 2.x, jscpd 4.x, xccov (Xcode 26).
set -u

# ---- thresholds (tunable) --------------------------------------------------
FUNC_LINES=50         # function_body_length
TYPE_LINES=400        # type_body_length
FILE_LINES=400        # file_length / raw line floor
CYCLO=10              # cyclomatic_complexity
CPD_TOKENS=100        # jscpd minimum duplicate tokens
COV_FLOOR=60          # coverage % floor

# ---- args / setup ----------------------------------------------------------
ROOT="${1:-$PWD}"
ROOT="$(realpath "$ROOT" 2>/dev/null || python3 -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$ROOT")"
REPORTS="${2:-$(mktemp -d "${TMPDIR:-/tmp}/review-project-swift.XXXXXX")/reports}"
mkdir -p "$REPORTS"

log() { printf '[swift.sh] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Common build/vendor dirs to ignore everywhere.
IGNORE_GLOBS='**/.build/**,**/DerivedData/**,**/Pods/**,**/Carthage/**,**/.git/**'
PRUNE=( -path '*/.build/*' -o -path '*/DerivedData/*' -o -path '*/Pods/*' -o -path '*/Carthage/*' )

log "project root : $ROOT"
log "reports dir  : $REPORTS"

SPM=0;   [ -f "$ROOT/Package.swift" ] && SPM=1
XCODEPROJ=""; while IFS= read -r p; do XCODEPROJ="$p"; break; done < <(find "$ROOT" -maxdepth 2 -name '*.xcodeproj' 2>/dev/null)
XCWS="";      while IFS= read -r p; do XCWS="$p"; break; done < <(find "$ROOT" -maxdepth 2 -name '*.xcworkspace' 2>/dev/null)
log "spm=$SPM xcodeproj=${XCODEPROJ:-none} xcworkspace=${XCWS:-none}"

# ===========================================================================
# 1. Raw file length  ->  swift-filelength.csv
# ===========================================================================
{
  echo "lines,path,flag"
  find "$ROOT" -type f -name '*.swift' \( "${PRUNE[@]}" \) -prune -o -type f -name '*.swift' -print 2>/dev/null \
    | while IFS= read -r f; do
        n=$(wc -l < "$f" | tr -d ' ')
        flag=""; [ "$n" -gt "$FILE_LINES" ] && flag="OVER_${FILE_LINES}"
        printf '%s,%s,%s\n' "$n" "$f" "$flag"
      done | sort -t, -k1 -nr
} > "$REPORTS/swift-filelength.csv"
log "wrote swift-filelength.csv"

# ===========================================================================
# 2. SwiftLint length + complexity  ->  swift-lint.csv
# ===========================================================================
if have swiftlint; then
  CFG="$REPORTS/swiftlint.yml"
  cat > "$CFG" <<YML
only_rules:
  - function_body_length
  - type_body_length
  - file_length
  - cyclomatic_complexity
function_body_length:
  warning: ${FUNC_LINES}
  error: 100000
type_body_length:
  warning: ${TYPE_LINES}
  error: 100000
file_length:
  warning: ${FILE_LINES}
  error: 100000
cyclomatic_complexity:
  warning: ${CYCLO}
  error: 100000
excluded:
  - .build
  - DerivedData
  - Pods
  - Carthage
YML
  if swiftlint lint --quiet --no-cache --config "$CFG" --reporter json "$ROOT" \
       > "$REPORTS/swift-lint.json" 2>"$REPORTS/swift-lint.err"; then :; fi
  if [ -s "$REPORTS/swift-lint.json" ]; then
    {
      echo "rule,severity,line,reason,file"
      jq -r '.[] | [.rule_id, .severity, (.line//0|tostring), (.reason|gsub(",";";")), .file] | @csv' \
        "$REPORTS/swift-lint.json" 2>/dev/null
    } > "$REPORTS/swift-lint.csv"
    log "wrote swift-lint.csv ($(jq 'length' "$REPORTS/swift-lint.json" 2>/dev/null || echo '?') findings)"
  else
    echo "swiftlint produced no JSON; see swift-lint.err" > "$REPORTS/swift-lint.note.txt"
  fi
  [ -s "$REPORTS/swift-lint.err" ] || rm -f "$REPORTS/swift-lint.err"
  # unused_declaration is an *analyzer* rule needing a compiler log — Periphery
  # (below) covers dead code without one, so we note rather than build twice.
  echo "swiftlint analyzer rule 'unused_declaration' needs a compiler log; dead code is covered by Periphery instead." \
    > "$REPORTS/swift-unused.note.txt"
else
  echo "swiftlint not installed; skipped length/complexity. Install: brew install swiftlint" \
    > "$REPORTS/swift-lint.note.txt"
fi

# ===========================================================================
# 3. Duplication (jscpd)  ->  swift-duplication.csv
# ===========================================================================
if have jscpd; then
  jscpd "$ROOT" --min-tokens "$CPD_TOKENS" --mode strict --silent \
        --ignore "$IGNORE_GLOBS" --reporters json --output "$REPORTS/jscpd" \
        >"$REPORTS/jscpd.log" 2>&1 || true
  if [ -f "$REPORTS/jscpd/jscpd-report.json" ]; then
    {
      echo "tokens,lines,fileA,startA,fileB,startB"
      jq -r '.duplicates[]? | [.fragmentTokens? // .tokens? // 0, .lines,
              .firstFile.name, .firstFile.start, .secondFile.name, .secondFile.start]
              | @csv' "$REPORTS/jscpd/jscpd-report.json" 2>/dev/null | sort -t, -k1 -nr
    } > "$REPORTS/swift-duplication.csv"
    log "wrote swift-duplication.csv"
  else
    echo "jscpd produced no report; see jscpd.log" > "$REPORTS/swift-duplication.note.txt"
  fi
else
  echo "jscpd not installed; skipped duplication. Install: brew install jscpd (or npm i -g jscpd)" \
    > "$REPORTS/swift-duplication.note.txt"
fi

# ===========================================================================
# 4. Dead code (Periphery)  ->  swift-deadcode.csv   [best effort — builds]
# ===========================================================================
if have periphery; then
  PERIPHERY_OK=0
  if [ "$SPM" -eq 1 ]; then
    # Periphery resolves the SPM package from cwd, so run it inside ROOT (subshell restores cwd).
    ( cd "$ROOT" && periphery scan --quiet --format json --relative-results ) \
      > "$REPORTS/swift-deadcode.json" 2>"$REPORTS/periphery.err" && PERIPHERY_OK=1
  elif [ -n "$XCODEPROJ" ] || [ -n "$XCWS" ]; then
    # Need a scheme and (for Xcode projects) target names; read both from xcodebuild -list.
    LISTTARGET=(); [ -n "$XCWS" ] && LISTTARGET=(-workspace "$XCWS") || LISTTARGET=(-project "$XCODEPROJ")
    LISTJSON="$(xcodebuild "${LISTTARGET[@]}" -list -json 2>/dev/null)"
    SCHEME="$(printf '%s' "$LISTJSON" | jq -r '(.project.schemes // .workspace.schemes // [])[0] // empty')"
    # Non-test targets, comma-joined; Periphery requires --targets for Xcode projects.
    TARGETS="$(printf '%s' "$LISTJSON" | jq -r '(.project.targets // []) | map(select(test("Tests?$") | not)) | join(",")')"
    if [ -n "$SCHEME" ]; then
      log "periphery: building scheme '$SCHEME' (heavy; may take a while)"
      PARGS=(scan --quiet --format json --relative-results --schemes "$SCHEME")
      [ -n "$TARGETS" ] && PARGS+=(--targets "$TARGETS")
      [ -n "$XCWS" ] && PARGS+=(--workspace "$XCWS") || PARGS+=(--project "$XCODEPROJ")
      periphery "${PARGS[@]}" > "$REPORTS/swift-deadcode.json" 2>"$REPORTS/periphery.err" && PERIPHERY_OK=1
    else
      echo "Could not resolve a scheme for Periphery; run 'periphery scan --setup' interactively." \
        > "$REPORTS/swift-deadcode.note.txt"
    fi
  fi
  if [ "$PERIPHERY_OK" -eq 1 ] && [ -s "$REPORTS/swift-deadcode.json" ]; then
    {
      echo "kind,name,line,file"
      jq -r '.[]? | [.kind, .name, (.location|split(":")[1]//""), (.location|split(":")[0])] | @csv' \
        "$REPORTS/swift-deadcode.json" 2>/dev/null
    } > "$REPORTS/swift-deadcode.csv"
    log "wrote swift-deadcode.csv"
  elif [ ! -f "$REPORTS/swift-deadcode.note.txt" ]; then
    echo "Periphery scan failed (often needs a build/signing or 'periphery scan --setup'); see periphery.err." \
      > "$REPORTS/swift-deadcode.note.txt"
    log "periphery scan did not produce results"
  fi
  [ -s "$REPORTS/periphery.err" ] || rm -f "$REPORTS/periphery.err"
else
  echo "periphery not installed; skipped dead-code. Install: brew install peripheryapp/periphery/periphery" \
    > "$REPORTS/swift-deadcode.note.txt"
fi

# ===========================================================================
# 5. Coverage (existing .xcresult only)  ->  swift-coverage.csv
# ===========================================================================
XCRESULT=""
while IFS= read -r f; do XCRESULT="$f"; break; done < <(
  find "$ROOT" ~/Library/Developer/Xcode/DerivedData -maxdepth 6 -type d -name '*.xcresult' 2>/dev/null \
    | xargs -I{} stat -f '%m %N' {} 2>/dev/null | sort -nr | awk '{print $2}'
)
if [ -n "$XCRESULT" ] && have xcrun; then
  if xcrun xccov view --report --json "$XCRESULT" > "$REPORTS/xccov.json" 2>"$REPORTS/xccov.err"; then
    {
      echo "coverage_pct,file,flag"
      jq -r --argjson floor "$COV_FLOOR" '
        .targets[]?.files[]? | (.lineCoverage*100) as $p
        | [($p|.*10|round/10|tostring), .path, (if $p < $floor then "UNDER_\($floor)" else "" end)] | @csv' \
        "$REPORTS/xccov.json" 2>/dev/null | sort -t, -k1 -n
    } > "$REPORTS/swift-coverage.csv"
    log "wrote swift-coverage.csv (from $XCRESULT)"
  else
    echo "xccov could not read $XCRESULT; see xccov.err" > "$REPORTS/swift-coverage.note.txt"
  fi
  [ -s "$REPORTS/xccov.err" ] || rm -f "$REPORTS/xccov.err"
else
  echo "No .xcresult found. Run the test suite (Cmd-U / xcodebuild test) to generate coverage, then re-run." \
    > "$REPORTS/swift-coverage.note.txt"
  log "no .xcresult; coverage skipped"
fi

# ===========================================================================
# 6. Cycles (suspected — manual confirmation)  ->  swift-cycles.csv
# ===========================================================================
# Swift has no strong package-cycle tool. We build a module-level import graph
# (SPM dependency graph + per-file `import` scan) and flag SCCs as SUSPECTED.
{
  echo "scope,detail,note"
  if [ "$SPM" -eq 1 ] && have swift; then
    swift package --package-path "$ROOT" show-dependencies --format json > "$REPORTS/spm-deps.json" 2>/dev/null \
      && echo "spm,dependency graph captured -> spm-deps.json,external deps only; check for back-edges manually" \
      || echo "spm,show-dependencies failed,"
  fi
  # Local module names = directory names under Sources/ (SPM) or target groups.
  # Intra-target type cycles are NOT visible to imports; flag for manual review.
  echo "manual,Swift intra-module type cycles are not tool-detectable here,inspect god types & bidirectional references by hand"
} > "$REPORTS/swift-cycles.csv"
# Per-file import adjacency for manual graphing.
{
  echo "file,imports"
  find "$ROOT" -type f -name '*.swift' \( "${PRUNE[@]}" \) -prune -o -type f -name '*.swift' -print 2>/dev/null \
    | while IFS= read -r f; do
        imps=$(grep -hE '^[[:space:]]*import ' "$f" 2>/dev/null | sed -E 's/^[[:space:]]*import +([A-Za-z0-9_.]+).*/\1/' | sort -u | paste -sd';' -)
        [ -n "$imps" ] && printf '%s,%s\n' "$f" "$imps"
      done
} > "$REPORTS/swift-imports.csv"
log "wrote swift-cycles.csv + swift-imports.csv (suspected/manual)"

# ===========================================================================
# 7. Performance smells (heuristic — confirm in code)  ->  swift-performance.csv
# ===========================================================================
# Regex + brace-depth heuristics (no type info). Emits CANDIDATES, not verdicts;
# the review step opens each location and judges. False positives are expected on
# already-bounded @Query / harmless .map chains — that's by design.
python3 - "$ROOT" "$REPORTS/swift-performance.csv" <<'PY'
import os, re, sys, csv

root, out = sys.argv[1], sys.argv[2]
PRUNE = {'.build', 'DerivedData', 'Pods', 'Carthage', '.git'}

def swift_files(base):
    for dp, dns, fns in os.walk(base):
        dns[:] = [d for d in dns if d not in PRUNE]
        for fn in fns:
            if fn.endswith('.swift'):
                yield os.path.join(dp, fn)

rows = []
def add(check, sev, path, lineno, text):
    rows.append((check, sev, path, lineno, text.strip()[:200]))

LOOP   = re.compile(r'\bfor\b.*\bin\b|\.forEach\s*[\({]|\.map\s*[\({]|\.flatMap\s*[\({]|\.compactMap\s*[\({]')
CHAIN  = re.compile(r'\.(map|filter|reduce|sorted|flatMap|compactMap)\b')
FETCHY = re.compile(r'\.fetch\(|modelContext|context\.fetch')
AWAIT  = re.compile(r'\bawait\b')

for path in swift_files(root):
    try:
        lines = open(path, encoding='utf-8', errors='ignore').read().splitlines()
    except OSError:
        continue
    blob   = '\n'.join(lines)
    is_model = '@Model' in blob
    is_view  = re.search(r':\s*View\b|some\s+View', blob) is not None

    # brace depth *before* each line (naive; ignores braces in strings/comments)
    depth_before, d = [], 0
    for ln in lines:
        depth_before.append(d)
        d += ln.count('{') - ln.count('}')

    for i, ln in enumerate(lines):
        lno, s = i + 1, ln.strip()
        if not s or s.startswith('//'):
            continue
        # A. SwiftData query cost
        if '@Query' in ln:
            add('swiftdata-query', 'high', path, lno, s + '  // verify predicate + fetchLimit (else loads all rows on appear)')
        if 'FetchDescriptor' in ln and 'fetchLimit' not in blob:
            add('swiftdata-query', 'high', path, lno, s + '  // FetchDescriptor with no fetchLimit in file')
        elif re.search(r'\.fetch\(', ln):
            add('swiftdata-query', 'medium', path, lno, s)
        # D. inline Data blob on @Model + base64 cost
        if is_model and re.search(r':\s*Data\??(\s|$|=|//)', ln) and 'func ' not in ln:
            add('inline-data-blob', 'high', path, lno, s + '  // Data stored inline on @Model record')
        if re.search(r'base64Encoded(String)?\b', ln):
            add('base64-cost', 'medium', path, lno, s)
        # E. search-as-you-type
        if '.onChange' in ln and re.search(r'search|query', ln, re.I):
            add('search-as-you-type', 'medium', path, lno, s + '  // work on every keystroke? debounce')
        # B. heavy compute in a View file (multi-op collection chain)
        if is_view and len(CHAIN.findall(ln)) >= 2:
            add('heavy-view-compute', 'medium', path, lno, s + '  // multi-op chain re-runs every re-render; cache it')

    # F. onChange cascade (file-level)
    oc = sum(1 for ln in lines if '.onChange' in ln)
    if oc >= 3:
        add('onchange-cascade', 'medium', path, 0, f'{oc} .onChange handlers in this file — re-render cascades')

    # C/E. block-aware: loop body containing a fetch (N+1) or await (sequential)
    for i, ln in enumerate(lines):
        if not LOOP.search(ln):
            continue
        base = depth_before[i]
        body = [lines[j] for j in range(i + 1, len(lines)) if depth_before[j] > base]
        window = ln + '\n' + '\n'.join(body)  # include the header line for single-line closures
        if FETCHY.search(window):
            add('n-plus-1', 'high', path, i + 1, ln.strip() + '  // fetch/relationship access inside a loop; batch into one query')
        if AWAIT.search(window):
            add('main-actor-blocking', 'high', path, i + 1, ln.strip() + '  // sequential await per iteration; batch or parallelize')

rank = {'high': 0, 'medium': 1, 'low': 2}
rows.sort(key=lambda r: (rank.get(r[1], 3), r[0], r[2], r[3]))
with open(out, 'w', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['check', 'severity', 'file', 'line', 'match'])
    if not rows:
        w.writerow(['', '', '', '', 'no performance smells matched the heuristics'])
    for r in rows:
        w.writerow(r)
PY
log "wrote swift-performance.csv"

echo "REPORTS_DIR=$REPORTS"
