#!/usr/bin/env bash
# test-validate-state.sh - Fixture-driven regression suite for scripts/validate-state.sh.
#
# Four seeded defect fixtures (stray undocumented field, duplicate project_number, off-schema
# status, dangling dependency), each asserted to produce a nonzero exit and a named error line,
# plus a positive fixture asserting exit 0 on valid state.
#
# Structural model: scripts/tests/test-validate-handoff.sh / test-phase-heading-patterns.sh
# (pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (validate-state.sh not found).

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

VALIDATOR_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
  "$SCRIPT_DIR/../validate-state.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-state.sh not found at any of:" >&2
  for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

# --- D5 (per-type artifact-loss) validator resolution ---
# Deliberately source-store-first (opposite order from VALIDATOR_CANDIDATES above), because the
# D5 fixtures below must exercise the new check without depending on a prior deploy step. Every
# candidate is still verified via grep for the check's identifier ("Check D5") before being
# trusted -- this is what prevents a stale deployed copy from producing a false green, per the
# suite's existing structural precedent (VALIDATOR resolution above).
D5_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
D5_VALIDATOR=""
for candidate in "${D5_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check D5" "$candidate" 2>/dev/null; then
    D5_VALIDATOR="$candidate"
    break
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

# =====================================================================
# Positive fixture: valid state -> exit 0
# =====================================================================
cat > "$WORKDIR/valid-state.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    },
    {
      "project_number": 2,
      "project_name": "beta",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/valid-state.json" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]]; then
  pass "positive fixture: valid state exits 0"
else
  fail "positive fixture: expected exit 0, got $rc"
  info "$out"
fi

out_deep=$(bash "$VALIDATOR" --deep "$WORKDIR/valid-state.json" 2>&1)
rc_deep=$?
if [[ "$rc_deep" -eq 0 ]]; then
  pass "positive fixture: valid state exits 0 under --deep"
else
  fail "positive fixture: expected exit 0 under --deep, got $rc_deep"
  info "$out_deep"
fi

# =====================================================================
# Defect fixture 1: stray undocumented field (top-level)
# =====================================================================
cat > "$WORKDIR/stray-field.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    }
  ],
  "totally_undocumented_field": "should trigger a FAIL"
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/stray-field.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Unknown top-level field: totally_undocumented_field" <<< "$out"; then
  pass "defect fixture: stray top-level field -> nonzero exit with named error"
else
  fail "defect fixture: stray top-level field did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 2: duplicate project_number (--deep)
# =====================================================================
cat > "$WORKDIR/dup-pnum.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    },
    {
      "project_number": 1,
      "project_name": "alpha-dup",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": []
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" --deep "$WORKDIR/dup-pnum.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Duplicate project_number: 1" <<< "$out"; then
  pass "defect fixture: duplicate project_number -> nonzero exit with named error"
else
  fail "defect fixture: duplicate project_number did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 3: off-schema status
# =====================================================================
cat > "$WORKDIR/bad-status.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "foobar",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/bad-status.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "off-schema status 'foobar'" <<< "$out"; then
  pass "defect fixture: off-schema status -> nonzero exit with named error"
else
  fail "defect fixture: off-schema status did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 4: dangling dependency (--deep)
# =====================================================================
cat > "$WORKDIR/dangling-dep.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [999]
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" --deep "$WORKDIR/dangling-dep.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Dangling dependency reference: 1 -> 999" <<< "$out"; then
  pass "defect fixture: dangling dependency -> nonzero exit with named error"
else
  fail "defect fixture: dangling dependency did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Bonus: self-referential dependency and cycle detection (--deep), beyond the four required
# fixtures but exercising the same D3 code path.
# =====================================================================
cat > "$WORKDIR/self-ref.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON
out=$(bash "$VALIDATOR" --deep "$WORKDIR/self-ref.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Self-referential dependencies" <<< "$out"; then
  pass "bonus fixture: self-referential dependency -> nonzero exit with named error"
else
  fail "bonus fixture: self-referential dependency did not produce the expected result (rc=$rc)"
  info "$out"
fi

cat > "$WORKDIR/cycle.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [2]
    },
    {
      "project_number": 2,
      "project_name": "beta",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON
out=$(bash "$VALIDATOR" --deep "$WORKDIR/cycle.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Dependency cycle detected" <<< "$out"; then
  pass "bonus fixture: dependency cycle -> nonzero exit with named error"
else
  fail "bonus fixture: dependency cycle did not produce the expected result (rc=$rc)"
  info "$out"
fi

# =====================================================================
# D5 per-type artifact-loss invariant fixtures (git-backed, both directions of the verification
# bar: rejection and the same write accepted under --allow-artifact-removal), plus regression,
# pure-append, untyped-entry, and scoped-flag cases.
# =====================================================================
if [[ -z "$D5_VALIDATOR" ]]; then
  info "SKIPPING D5 fixtures: no candidate validator (source-store or deployed) contains the D5"
  info "per-type artifact-loss check (grepped for \"Check D5\"). Candidates checked:"
  for candidate in "${D5_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "D5 fixtures running against: $D5_VALIDATOR (confirmed to contain the D5 check)"

  # Creates a fresh git-backed fixture repo under $1 with a committed baseline state.json
  # containing project_number 42 with: 1 report, 1 plan, 5 summaries (mirroring the observed
  # 5-dropped incident shape), and 2 untyped entries (no .type field). Required because D5 reads
  # the *prior committed* version via git show -- a non-git fixture cannot exercise it.
  make_d5_baseline() {
    local repo_dir="$1"
    mkdir -p "$repo_dir/specs"
    cat > "$repo_dir/specs/state.json" <<'JSON'
{
  "next_project_number": 43,
  "active_projects": [
    {
      "project_number": 42,
      "project_name": "d5-fixture",
      "status": "implementing",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [],
      "artifacts": [
        {"path": "specs/042_d5/reports/01_r1.md", "type": "report", "summary": "r1"},
        {"path": "specs/042_d5/plans/01_p1.md", "type": "plan", "summary": "p1"},
        {"path": "specs/042_d5/summaries/01_s1.md", "type": "summary", "summary": "s1"},
        {"path": "specs/042_d5/summaries/02_s2.md", "type": "summary", "summary": "s2"},
        {"path": "specs/042_d5/summaries/03_s3.md", "type": "summary", "summary": "s3"},
        {"path": "specs/042_d5/summaries/04_s4.md", "type": "summary", "summary": "s4"},
        {"path": "specs/042_d5/summaries/05_s5.md", "type": "summary", "summary": "s5"},
        {"path": "specs/042_d5/notes/01_n1.md", "summary": "n1"},
        {"path": "specs/042_d5/notes/02_n2.md", "summary": "n2"}
      ]
    }
  ]
}
JSON
    git -C "$repo_dir" init -q
    git -C "$repo_dir" config user.email "d5-fixture@example.com"
    git -C "$repo_dir" config user.name "D5 Fixture"
    git -C "$repo_dir" add specs/state.json
    git -C "$repo_dir" commit -q -m "baseline"
  }

  # --- Negative fixture (rejection): raw jq-composed write dropping all 5 summaries, adding 2 ---
  # This mirrors the observed 5-dropped/2-added incident shape, and the mutation is a literal,
  # hand-composed `jq '... .artifacts = [...]' > tmp && mv tmp state.json` sequence -- not a
  # helper call -- which is what proves the check is writer-agnostic.
  d5_neg_dir="$WORKDIR/d5-negative"
  make_d5_baseline "$d5_neg_dir"
  d5_neg_state="$d5_neg_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "summary" | not)]
        + [{"path":"specs/042_d5/summaries/06_s6.md","type":"summary","summary":"s6"},
           {"path":"specs/042_d5/summaries/07_s7.md","type":"summary","summary":"s7"}]' \
    "$d5_neg_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_neg_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_neg_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "Artifact loss: project_number 42, type 'summary'" <<< "$out" \
      && grep -q "removed=5 added=2" <<< "$out"; then
    pass "D5 negative fixture: 5-dropped/2-added summary loss (raw jq write) -> FAIL naming project, type, counts, paths"
  else
    fail "D5 negative fixture: expected FAIL naming project 42/type summary/removed=5 added=2 (rc=$rc)"
    info "$out"
  fi

  # --- Positive fixture (opt-in accepted): the IDENTICAL mutated fixture, re-run with the flag ---
  out=$(bash "$D5_VALIDATOR" --deep --allow-artifact-removal 42 "$d5_neg_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "ALLOWED by --allow-artifact-removal" <<< "$out"; then
    pass "D5 positive fixture: identical mutation accepted under --allow-artifact-removal 42, opt-in line logged"
  else
    fail "D5 positive fixture: expected exit 0 with opt-in line under --allow-artifact-removal 42 (rc=$rc)"
    info "$out"
  fi

  # --- Regression fixture (sanctioned supersession): 1-for-1 same-type (report) replacement ---
  d5_reg_dir="$WORKDIR/d5-regression"
  make_d5_baseline "$d5_reg_dir"
  d5_reg_state="$d5_reg_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "report" | not)]
        + [{"path":"specs/042_d5/reports/02_r2.md","type":"report","summary":"r2"}]' \
    "$d5_reg_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_reg_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_reg_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Artifact loss" <<< "$out"; then
    pass "D5 regression fixture: 1-for-1 same-type (report) supersession passes with no finding"
  else
    fail "D5 regression fixture: expected exit 0 with no artifact-loss finding for 1-for-1 report supersession (rc=$rc)"
    info "$out"
  fi

  # --- Pure-append fixture: adding one artifact with nothing removed ---
  d5_app_dir="$WORKDIR/d5-append"
  make_d5_baseline "$d5_app_dir"
  d5_app_state="$d5_app_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts += [{"path":"specs/042_d5/reports/02_r2.md","type":"report","summary":"r2"}]' \
    "$d5_app_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_app_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_app_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Artifact loss" <<< "$out"; then
    pass "D5 pure-append fixture: adding one artifact with nothing removed passes with no finding"
  else
    fail "D5 pure-append fixture: expected exit 0 with no artifact-loss finding (rc=$rc)"
    info "$out"
  fi

  # --- Untyped-entry fixture: dropping both untyped entries, adding none ---
  d5_unt_dir="$WORKDIR/d5-untyped"
  make_d5_baseline "$d5_unt_dir"
  d5_unt_state="$d5_unt_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(has("type"))]' \
    "$d5_unt_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_unt_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_unt_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "type '(untyped)'" <<< "$out" && grep -q "removed=2 added=0" <<< "$out"; then
    pass "D5 untyped-entry fixture: dropping 2 untyped entries with none added -> FAIL under sentinel grouping"
  else
    fail "D5 untyped-entry fixture: expected FAIL naming type (untyped), removed=2 added=0 (rc=$rc)"
    info "$out"
  fi

  # --- Scoped-flag fixture: wrong-type opt-in must not over-permit a different type's loss ---
  d5_scoped_dir="$WORKDIR/d5-scoped"
  make_d5_baseline "$d5_scoped_dir"
  d5_scoped_state="$d5_scoped_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "summary" | not)]
        + [{"path":"specs/042_d5/summaries/06_s6.md","type":"summary","summary":"s6"},
           {"path":"specs/042_d5/summaries/07_s7.md","type":"summary","summary":"s7"}]' \
    "$d5_scoped_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_scoped_state"

  out=$(bash "$D5_VALIDATOR" --deep --allow-artifact-removal 42:report "$d5_scoped_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "Artifact loss: project_number 42, type 'summary'" <<< "$out"; then
    pass "D5 scoped-flag fixture: --allow-artifact-removal 42:report does not over-permit a summary-type loss"
  else
    fail "D5 scoped-flag fixture: expected FAIL for summary loss even with --allow-artifact-removal 42:report (rc=$rc)"
    info "$out"
  fi
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
