#!/usr/bin/env bash
# test-resume-scan-nonconformance.sh - Fixture-driven regression suite for the resume-scan
# conformance gate wired into the hard-mode per-phase dispatch sites (skill-implementer-hard,
# skill-orchestrate's hard_mode-gated per-phase-dispatch (H1) branch,
# skill-lean-implementation-hard). Exercises the ordering contract
# directly: PHASE_HEADING_ERE-filtered scans MUST run has_nonconforming_phase_headings over the
# whole plan file first, or a non-conforming heading is silently invisible to the scan rather
# than merely unmatched by it -- see scripts/lib/phase-heading-patterns.sh's "Ordering contract
# for filtered scans" header note and context/formats/plan-format.md's "Canonical phase-heading
# shape" subsection.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error,
# deploy-tree-first then source-store-fallback library resolution).
#
# HONEST SCOPE LIMIT: the enclosing markdown fences in the three SKILL.md files below contain
# `Agent tool:` / `EXIT (...)` pseudo-syntax and are NOT valid bash -- this is pre-existing and
# expected, not a defect this suite works around. This suite extracts and executes only the
# sentinel-delimited `resume-scan-conformance-gate:begin`/`:end` regions (pure, executable bash),
# plus structural (grep-based) assertions on the posture branches that immediately follow each
# region, which contain pseudo-syntax and cannot themselves be executed. Site D
# (update-task-status.sh) is covered by `bash -n` and structural grep only in this suite, not by
# execution -- it is a real standalone script; see Phase 4 of the implementation plan this suite
# originally verified. The preflight phase auto-advance convenience Site D used to guard (the
# first_phase_heading path, and its has_nonconforming_phase_headings guard) has since been
# deleted outright -- update_plan_file() no longer writes any per-phase marker, on any path, so
# Site D now asserts the ABSENCE of that deleted path's guard invocation rather than its
# presence, confirming a full deletion rather than a partial edit that left the guard behind
# without its caller.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# or a required SKILL.md file not found, or a sentinel marker pair missing).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/phase-heading-patterns.sh"
  "$SCRIPT_DIR/../lib/phase-heading-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library phase-heading-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

SITE_B_FILE="$REPO_ROOT/agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md"
SITE_A_FILE="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
SITE_C_FILE="$REPO_ROOT/agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md"
SITE_D_FILE="$REPO_ROOT/agent-system/extensions/core/scripts/update-task-status.sh"

for f in "$SITE_B_FILE" "$SITE_A_FILE" "$SITE_C_FILE" "$SITE_D_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file not found: $f" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BEGIN_MARKER='resume-scan-conformance-gate:begin'
END_MARKER='resume-scan-conformance-gate:end'

# ─── Region extraction ─────────────────────────────────────────────────────────────────────────
# Fails loudly (not a silent skip) if a marker pair is missing from a file.
extract_region() {
  local file="$1" label="$2"
  if ! grep -q "$BEGIN_MARKER" "$file"; then
    echo "ERROR: ${BEGIN_MARKER} not found in ${label} (${file})" >&2
    return 1
  fi
  if ! grep -q "$END_MARKER" "$file"; then
    echo "ERROR: ${END_MARKER} not found in ${label} (${file})" >&2
    return 1
  fi
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
    $0 ~ b { flag=1 }
    flag { print }
    $0 ~ e { flag=0 }
  ' "$file"
}

# Note on the library sourcing line: at all three sites, `. .claude/scripts/lib/phase-heading-
# patterns.sh` sits immediately BEFORE the `resume-scan-conformance-gate:begin` marker (per the
# canonical snippet -- see Phase 1 of the implementation plan), so it is deliberately NOT part of
# the extracted region. Rather than textually rewriting an in-region sourcing line that does not
# exist, the harness sources $LIB directly in run_region() below before eval'ing each extracted
# region -- behaviorally identical (the region's own logic never re-sources the library), and
# correct regardless of deploy-tree vs. source-store checkout since $LIB was already resolved
# above.
region_b="$(extract_region "$SITE_B_FILE" "Site B (skill-implementer-hard)")" || exit 2
region_a="$(extract_region "$SITE_A_FILE" "Site A (skill-orchestrate)")" || exit 2
region_c="$(extract_region "$SITE_C_FILE" "Site C (skill-lean-implementation-hard)")" || exit 2

# =====================================================================
# bash -n: every extracted region must be independently syntax-clean.
# =====================================================================
for pair in "B:$region_b" "A:$region_a" "C:$region_c"; do
  site="${pair%%:*}"
  region="${pair#*:}"
  script_file="$WORKDIR/syntax-${site}.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'plan_path="/tmp/fixture.md"'
    echo 'plan_file="/tmp/fixture.md"'
    printf '%s\n' "$region"
  } > "$script_file"
  if bash -n "$script_file" 2>"$WORKDIR/syntax-${site}.err"; then
    pass "Site ${site}: extracted sentinel region is bash -n clean"
  else
    fail "Site ${site}: extracted sentinel region failed bash -n: $(cat "$WORKDIR/syntax-${site}.err")"
  fi
done

# ─── Region execution harness ──────────────────────────────────────────────────────────────────
# Runs an extracted region in a subshell with the given bind variable pointed at a fixture file,
# then reports the region's own result variable and phase_scan_inconclusive via stdout so the
# caller (which only sees the subshell's captured stdout/stderr, not its variable bindings) can
# assert on them. Stdout and stderr are captured to separate files. Sources $LIB and initializes
# the result variable / phase_scan_inconclusive first, mirroring the two lines that precede the
# sentinel-delimited region at each live site (see the note above run_region's siblings).
run_region() {
  local region="$1" bind_var="$2" fixture_path="$3" result_var="$4" out_file="$5" err_file="$6"
  (
    # shellcheck disable=SC1090
    . "$LIB"
    eval "${bind_var}=\"\$fixture_path\""
    eval "${result_var}=\"\""
    phase_scan_inconclusive=false
    eval "$region"
    echo "__RESULT_VALUE__=${!result_var}"
    echo "__RESULT_INCONCLUSIVE__=${phase_scan_inconclusive:-}"
  ) > "$out_file" 2> "$err_file"
}

result_value() { grep '^__RESULT_VALUE__=' "$1" | tail -1 | sed 's/^__RESULT_VALUE__=//'; }
result_inconclusive() { grep '^__RESULT_INCONCLUSIVE__=' "$1" | tail -1 | sed 's/^__RESULT_INCONCLUSIVE__=//'; }

# =====================================================================
# Fixture A: the task's verification bar. A [COMPLETED] conforming phase, then a non-conforming
# "4C" heading IN PROGRESS, then a conforming "5" heading NOT STARTED. Asserts the non-conforming
# heading is named by line number and phase 5 is never silently selected.
# =====================================================================
fixture_a="$WORKDIR/fixture-a.md"
cat > "$fixture_a" <<'EOF'
# Fixture A: verification bar

### Phase 1: Setup [COMPLETED]

Body text for phase 1.

### Phase 4C: Sub-step needing loud detection [IN PROGRESS]

Body text for the non-conforming heading.

### Phase 5: Wrap-up [NOT STARTED]

Body text for phase 5.
EOF
fixture_a_4c_line="$(grep -n '^### Phase 4C:' "$fixture_a" | head -1 | cut -d: -f1)"
info "Fixture A: '### Phase 4C' heading is at line ${fixture_a_4c_line}"

declare -A SITE_REGION=( [B]="$region_b" [A]="$region_a" [C]="$region_c" )
declare -A SITE_BINDVAR=( [B]="plan_path" [A]="plan_path" [C]="plan_file" )
declare -A SITE_RESULTVAR=( [B]="next_phase" [A]="next_phase" [C]="phase_number" )
declare -A SITE_LABEL=( [B]="Site B (skill-implementer-hard)" [A]="Site A (skill-orchestrate)" [C]="Site C (skill-lean-implementation-hard)" )

for site in B A C; do
  region="${SITE_REGION[$site]}"
  bind_var="${SITE_BINDVAR[$site]}"
  result_var="${SITE_RESULTVAR[$site]}"
  label="${SITE_LABEL[$site]}"
  out="$WORKDIR/a-${site}.out"
  err="$WORKDIR/a-${site}.err"
  run_region "$region" "$bind_var" "$fixture_a" "$result_var" "$out" "$err"

  if grep -q '4C' "$err"; then
    pass "${label}: Fixture A stderr names the non-conforming '4C' heading"
  else
    fail "${label}: Fixture A stderr does NOT name '4C' -- got: $(cat "$err")"
  fi

  if grep -q "${fixture_a_4c_line}" "$err"; then
    pass "${label}: Fixture A stderr carries the fixture line number (${fixture_a_4c_line}) of the 4C heading"
  else
    fail "${label}: Fixture A stderr does NOT carry line number ${fixture_a_4c_line} -- got: $(cat "$err")"
  fi

  inconclusive="$(result_inconclusive "$out")"
  if [[ "$inconclusive" == "true" ]]; then
    pass "${label}: Fixture A phase_scan_inconclusive is true"
  else
    fail "${label}: Fixture A phase_scan_inconclusive expected true, got '${inconclusive}'"
  fi

  value="$(result_value "$out")"
  if [[ -z "$value" ]]; then
    pass "${label}: Fixture A result variable (${result_var}) is empty"
  else
    fail "${label}: Fixture A result variable (${result_var}) expected empty, got '${value}'"
  fi
  if [[ "$value" != "5" ]]; then
    pass "${label}: Fixture A result variable is specifically NOT '5'"
  else
    fail "${label}: Fixture A result variable was '5' -- phase 5 was silently selected despite the non-conforming 4C heading"
  fi
done

# =====================================================================
# Fixture B: happy path. A fully conforming plan: phase 1 COMPLETED, phase 2 IN PROGRESS,
# phase 3 NOT STARTED. Required no-behavior-change assertion: next_phase resolves to exactly
# '2', phase_scan_inconclusive is false, and stderr is empty.
# =====================================================================
fixture_b="$WORKDIR/fixture-b.md"
cat > "$fixture_b" <<'EOF'
# Fixture B: happy path

### Phase 1: Setup [COMPLETED]

Body text for phase 1.

### Phase 2: Middle work [IN PROGRESS]

Body text for phase 2.

### Phase 3: Wrap-up [NOT STARTED]

Body text for phase 3.
EOF

for site in B A C; do
  region="${SITE_REGION[$site]}"
  bind_var="${SITE_BINDVAR[$site]}"
  result_var="${SITE_RESULTVAR[$site]}"
  label="${SITE_LABEL[$site]}"
  out="$WORKDIR/b-${site}.out"
  err="$WORKDIR/b-${site}.err"
  run_region "$region" "$bind_var" "$fixture_b" "$result_var" "$out" "$err"

  value="$(result_value "$out")"
  if [[ "$value" == "2" ]]; then
    pass "${label}: Fixture B (happy path) resolves ${result_var}=2"
  else
    fail "${label}: Fixture B (happy path) expected ${result_var}=2, got '${value}'"
  fi

  inconclusive="$(result_inconclusive "$out")"
  if [[ "$inconclusive" == "false" ]]; then
    pass "${label}: Fixture B phase_scan_inconclusive is false"
  else
    fail "${label}: Fixture B phase_scan_inconclusive expected false, got '${inconclusive}'"
  fi

  if [[ ! -s "$err" ]]; then
    pass "${label}: Fixture B stderr is empty (no-behavior-change on the happy path)"
  else
    fail "${label}: Fixture B stderr expected empty, got: $(cat "$err")"
  fi
done

# =====================================================================
# Fixture C: decimal sub-phase. A conforming plan whose open phase is 3.1 -- guards against a
# regression that silently drops decimal support while adding the gate.
# =====================================================================
fixture_c="$WORKDIR/fixture-c.md"
cat > "$fixture_c" <<'EOF'
# Fixture C: decimal sub-phase

### Phase 1: Setup [COMPLETED]

Body text for phase 1.

### Phase 3.1: Decimal sub-phase [IN PROGRESS]

Body text for phase 3.1.

### Phase 4: Wrap-up [NOT STARTED]

Body text for phase 4.
EOF

for site in B A C; do
  region="${SITE_REGION[$site]}"
  bind_var="${SITE_BINDVAR[$site]}"
  result_var="${SITE_RESULTVAR[$site]}"
  label="${SITE_LABEL[$site]}"
  out="$WORKDIR/c-${site}.out"
  err="$WORKDIR/c-${site}.err"
  run_region "$region" "$bind_var" "$fixture_c" "$result_var" "$out" "$err"

  value="$(result_value "$out")"
  if [[ "$value" == "3.1" ]]; then
    pass "${label}: Fixture C (decimal sub-phase) resolves ${result_var}=3.1"
  else
    fail "${label}: Fixture C (decimal sub-phase) expected ${result_var}=3.1, got '${value}'"
  fi
done

# =====================================================================
# Structural assertions on the posture branches (pseudo-syntax; not executable).
# =====================================================================

# Site B: exit 1 guarded by phase_scan_inconclusive, precedes the cascade's first elif.
site_b_guard_line=$(grep -n 'phase_scan_inconclusive" = "true"' "$SITE_B_FILE" | head -1 | cut -d: -f1)
site_b_elif_line=$(grep -n '^[[:space:]]*elif \[' "$SITE_B_FILE" | head -1 | cut -d: -f1)
if [[ -n "$site_b_guard_line" && -n "$site_b_elif_line" && "$site_b_guard_line" -lt "$site_b_elif_line" ]]; then
  pass "Site B: phase_scan_inconclusive guard (line ${site_b_guard_line}) precedes the cascade's first elif (line ${site_b_elif_line})"
else
  fail "Site B: could not confirm phase_scan_inconclusive guard precedes the cascade's first elif (guard=${site_b_guard_line:-MISSING}, elif=${site_b_elif_line:-MISSING})"
fi
if sed -n "${site_b_guard_line},$((site_b_guard_line + 4))p" "$SITE_B_FILE" | grep -q 'exit 1'; then
  pass "Site B: posture branch contains 'exit 1'"
else
  fail "Site B: posture branch does not contain 'exit 1' near line ${site_b_guard_line}"
fi

# Site A: EXIT (partial branch guarded by phase_scan_inconclusive, is the FIRST branch --
# precedes both the next_phase test and the last_skeleton test.
#
# Uniqueness guard: skill-orchestrate/SKILL.md is a large, actively-edited merged file (unlike
# the small, single-purpose skill-orchestrate-hard/SKILL.md this site formerly targeted), so a
# second occurrence of an anchor could silently appear and mis-anchor `head -1` onto the wrong
# line rather than failing. site_a_anchor_line() asserts the grep match count is exactly one
# before taking the line number, calling fail() by anchor name and observed count otherwise. The
# result is assigned via a nameref out-parameter, NOT a `$(...)` command substitution -- a
# substitution runs the function in a subshell, and this function's own fail()/pass() calls (via
# the shared PASSED/FAILED counters) must be visible to the parent shell, not lost when the
# subshell exits.
site_a_anchor_line() {
  local pattern="$1" anchor_name="$2"
  local -n out_var="$3"
  local matches count
  matches="$(grep -n "$pattern" "$SITE_A_FILE")"
  count=$(printf '%s\n' "$matches" | grep -c . || true)
  if [[ "$count" -ne 1 ]]; then
    fail "Site A: anchor '${anchor_name}' expected exactly 1 match in $(basename "$SITE_A_FILE"), found ${count}"
    out_var=""
    return
  fi
  out_var="$(printf '%s\n' "$matches" | cut -d: -f1)"
}
site_a_anchor_line 'phase_scan_inconclusive" = "true"' 'phase_scan_inconclusive guard' site_a_guard_line
site_a_anchor_line 'elif \[ -n "\$next_phase" \]' 'next_phase elif' site_a_nextphase_line
site_a_anchor_line 'elif \[ "\$last_skeleton" = "true" \]' 'last_skeleton elif' site_a_skeleton_line
if [[ -n "$site_a_guard_line" && -n "$site_a_nextphase_line" && -n "$site_a_skeleton_line" \
      && "$site_a_guard_line" -lt "$site_a_nextphase_line" \
      && "$site_a_nextphase_line" -lt "$site_a_skeleton_line" ]]; then
  pass "Site A: branch order is phase_scan_inconclusive (${site_a_guard_line}) < next_phase (${site_a_nextphase_line}) < last_skeleton (${site_a_skeleton_line})"
else
  fail "Site A: branch order assertion failed (guard=${site_a_guard_line:-MISSING}, next_phase=${site_a_nextphase_line:-MISSING}, last_skeleton=${site_a_skeleton_line:-MISSING})"
fi
site_a_branch_body="$(sed -n "${site_a_guard_line},$((site_a_nextphase_line - 1))p" "$SITE_A_FILE")"
if grep -q 'EXIT (partial' <<< "$site_a_branch_body"; then
  pass "Site A: posture branch body contains 'EXIT (partial'"
else
  fail "Site A: posture branch body does not contain 'EXIT (partial'"
fi
if grep -qE 'exit 1|loop_guard_file|update-task-status\.sh' <<< "$site_a_branch_body"; then
  fail "Site A: posture branch body unexpectedly contains 'exit 1', 'loop_guard_file', or 'update-task-status.sh'"
else
  pass "Site A: posture branch body contains neither 'exit 1' nor 'loop_guard_file' nor 'update-task-status.sh'"
fi

# Site C: return error guarded by the sentinel.
site_c_guard_line=$(grep -n 'phase_scan_inconclusive" = "true"' "$SITE_C_FILE" | head -1 | cut -d: -f1)
if [[ -n "$site_c_guard_line" ]] && sed -n "${site_c_guard_line},$((site_c_guard_line + 3))p" "$SITE_C_FILE" | grep -q 'return error'; then
  pass "Site C: posture branch guarded by phase_scan_inconclusive contains 'return error'"
else
  fail "Site C: could not confirm posture branch contains 'return error' near line ${site_c_guard_line:-MISSING}"
fi

# =====================================================================
# Repo-wide assertion: zero occurrences of the racy `nonconforming_phase_headings | grep -q`
# invocation form under agent-system/extensions/. Excludes backtick-quoted doc-comment
# references to the forbidden form (the canonical gate snippet's own header comment
# intentionally quotes the literal forbidden form as documentation, e.g. "the
# `nonconforming_phase_headings | grep -q .` pipe form is forbidden") -- real invocation syntax
# is never backtick-wrapped, so this exclusion cannot hide a genuine violation.
# =====================================================================
forbidden_hits="$(grep -rnE 'nonconforming_phase_headings[[:space:]]*\|[[:space:]]*grep -q' \
  "$REPO_ROOT/agent-system/extensions" 2>/dev/null | grep -v '`' || true)"
if [[ -z "$forbidden_hits" ]]; then
  pass "Repo-wide: zero occurrences of the racy \`nonconforming_phase_headings | grep -q\` invocation form under agent-system/extensions/"
else
  fail "Repo-wide: found racy pipe-form invocation(s):"$'\n'"${forbidden_hits}"
fi

# =====================================================================
# Site D: bash -n only (structural, not executed -- see header note).
# =====================================================================
if bash -n "$SITE_D_FILE" 2>"$WORKDIR/site-d.err"; then
  pass "Site D (update-task-status.sh): bash -n clean"
else
  fail "Site D (update-task-status.sh): bash -n failed: $(cat "$WORKDIR/site-d.err")"
fi
if grep -q 'has_nonconforming_phase_headings "\$plan_file"' "$SITE_D_FILE"; then
  fail "Site D: the first_phase_heading auto-advance convenience (and its has_nonconforming_phase_headings guard) should have been deleted outright, but the guard invocation is still present"
else
  pass "Site D: first_phase_heading auto-advance convenience and its guard were fully deleted -- update_plan_file() writes no per-phase marker on any path"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
