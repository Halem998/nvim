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
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
