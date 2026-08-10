#!/usr/bin/env bash
# test-postflight-marker-schema.sh - Fixture test asserting skill_create_postflight_marker
# (scripts/skill-base.sh) produces the exact canonical Shape A key set: session_id, skill,
# task_number, operation, reason, created, stop_hook_active -- no more, no fewer.
#
# This closes the schema-drift gap the shared-skill-stage-skeleton effort settled: prior to
# unification, the corpus had six mutually incompatible marker shapes (two empty `touch`
# variants, skill-base.sh's own then-unused 6-key shape, and four JSON heredoc variants).
# Shape A is the fullest observed shape (adds `task_number`, which 38 of 40 live writers already
# emitted, and retains `stop_hook_active`, which the hard-mode variants had dropped by drift).
#
# Structural model: test-skill-base-lifecycle.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, sourced -- not subprocessed -- skill-base.sh
# itself, pass()/fail()/info() helpers, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

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

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE="$(resolve_candidate "skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for this suite" >&2
  exit 2
fi

# shellcheck disable=SC1090
. "$SKILL_BASE"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

ORIG_PWD="$(pwd)"
mkdir -p "$WORKDIR/specs"
cd "$WORKDIR" || exit 2

# =====================================================================
# Case 1: exact Shape A key set (no more, no fewer)
# =====================================================================
info "=== skill_create_postflight_marker: exact key set ==="

skill_create_postflight_marker "042" "fixture_task" "sess_1700000000_abc123" "skill-researcher" "research"

MARKER_FILE="specs/042_fixture_task/.postflight-pending"

if [[ -f "$MARKER_FILE" ]]; then
  pass "marker file created at expected path"
else
  fail "marker file not created at $MARKER_FILE"
fi

if jq empty "$MARKER_FILE" 2>/dev/null; then
  pass "marker file parses as valid JSON"
else
  fail "marker file is not valid JSON"
fi

EXPECTED_KEYS="created operation reason session_id skill stop_hook_active task_number"
ACTUAL_KEYS="$(jq -r 'keys | sort | join(" ")' "$MARKER_FILE" 2>/dev/null)"

if [[ "$ACTUAL_KEYS" == "$EXPECTED_KEYS" ]]; then
  pass "marker key set is exactly the seven Shape A keys: $ACTUAL_KEYS"
else
  fail "marker key set mismatch -- expected [$EXPECTED_KEYS], got [$ACTUAL_KEYS]"
fi

# =====================================================================
# Case 2: task_number is an unpadded integer derived from padded_num
# =====================================================================
info "=== task_number derivation ==="

TASK_NUMBER_VALUE="$(jq -r '.task_number' "$MARKER_FILE")"
TASK_NUMBER_TYPE="$(jq -r '.task_number | type' "$MARKER_FILE")"

if [[ "$TASK_NUMBER_TYPE" == "number" ]]; then
  pass "task_number is a JSON number (not a string)"
else
  fail "task_number has type '$TASK_NUMBER_TYPE', expected 'number'"
fi

if [[ "$TASK_NUMBER_VALUE" == "42" ]]; then
  pass "task_number correctly stripped leading zeros from padded_num '042' -> 42"
else
  fail "task_number expected '42', got '$TASK_NUMBER_VALUE'"
fi

# =====================================================================
# Case 3: field values round-trip correctly
# =====================================================================
info "=== field value fidelity ==="

if [[ "$(jq -r '.session_id' "$MARKER_FILE")" == "sess_1700000000_abc123" ]]; then
  pass "session_id round-trips correctly"
else
  fail "session_id did not round-trip correctly"
fi

if [[ "$(jq -r '.skill' "$MARKER_FILE")" == "skill-researcher" ]]; then
  pass "skill round-trips correctly"
else
  fail "skill did not round-trip correctly"
fi

if [[ "$(jq -r '.operation' "$MARKER_FILE")" == "research" ]]; then
  pass "operation round-trips correctly"
else
  fail "operation did not round-trip correctly"
fi

if [[ "$(jq -r '.stop_hook_active' "$MARKER_FILE")" == "false" ]]; then
  pass "stop_hook_active defaults to false"
else
  fail "stop_hook_active expected 'false', got '$(jq -r '.stop_hook_active' "$MARKER_FILE")'"
fi

# =====================================================================
# Case 4: task_number derivation with a zero-leading, multi-digit padded_num that has no
# leading zero to strip (regression guard against an off-by-one in the 10# arithmetic base).
# =====================================================================
info "=== task_number derivation (no leading zeros) ==="

skill_create_postflight_marker "123" "fixture_task_2" "sess_1700000001_def456" "skill-planner" "plan"
MARKER_FILE_2="specs/123_fixture_task_2/.postflight-pending"
if [[ "$(jq -r '.task_number' "$MARKER_FILE_2" 2>/dev/null)" == "123" ]]; then
  pass "task_number derivation handles a padded_num with no leading zeros (123 -> 123)"
else
  fail "task_number derivation failed for padded_num '123'"
fi

cd "$ORIG_PWD" || true

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
