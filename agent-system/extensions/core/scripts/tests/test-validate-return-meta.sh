#!/usr/bin/env bash
# test-validate-return-meta.sh - Fixture suite for validate-return-meta.sh, asserting it enforces
# the strict artifacts-shape contract from context/formats/return-metadata-file.md: bare-string
# artifacts elements FAIL, well-formed object elements PASS, and --fix performs the unambiguous
# repair without ever running implicitly.
#
# Structural model: test-validate-handoff.sh (mktemp -d workdir with an EXIT-trap cleanup,
# deploy-tree-first / source-store-fallback candidate resolution, pass()/fail()/info() helpers
# with integer counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Covers at minimum: a well-formed file (exit 0), a bare-string array (exit 1), a missing file
# (exit 3), an object missing summary (exit 1), a non-resolving path (exit 1), and a --fix
# round-trip that turns a failing file into a passing one.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# validator script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-return-meta.sh"
  "$REPO_ROOT/.claude/scripts/validate-return-meta.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-return-meta.sh not found at any of:" >&2
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

# A path guaranteed to resolve on disk relative to REPO_ROOT, for well-formed fixtures.
EXISTING_PATH="specs/052_return_meta_artifacts_shape_contract/plans/01_return-meta-artifacts-contract.md"

# ─── assert_exit <name> <expected-exit> <json-content> [extra-args...] ────────────────────────
assert_exit() {
  local name="$1" expected="$2" content="$3"
  shift 3
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  local actual
  bash "$VALIDATOR" "$f" "$@" >"$WORKDIR/${name}.out" 2>&1
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    pass "$name: validator exits $expected as expected"
  else
    fail "$name: validator exited $actual (expected $expected) -- see $WORKDIR/${name}.out"
  fi
}

# =====================================================================
# Case 1: well-formed file -> exit 0
# =====================================================================
assert_exit "well-formed" 0 "{
  \"status\": \"implemented\",
  \"artifacts\": [
    {\"type\": \"plan\", \"path\": \"${EXISTING_PATH}\", \"summary\": \"A plan artifact.\"}
  ],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}"

# =====================================================================
# Case 2: bare-string array -> exit 1
# =====================================================================
assert_exit "bare-string" 1 "{
  \"status\": \"implemented\",
  \"artifacts\": [\"${EXISTING_PATH}\"],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}"

# =====================================================================
# Case 3: missing file -> exit 3
# =====================================================================
MISSING_FILE="$WORKDIR/does-not-exist.json"
bash "$VALIDATOR" "$MISSING_FILE" >"$WORKDIR/missing-file.out" 2>&1
missing_exit=$?
if [[ "$missing_exit" -eq 3 ]]; then
  pass "missing-file: validator exits 3 as expected"
else
  fail "missing-file: validator exited $missing_exit (expected 3) -- see $WORKDIR/missing-file.out"
fi

# =====================================================================
# Case 4: object missing summary -> exit 1
# =====================================================================
assert_exit "missing-summary" 1 "{
  \"status\": \"implemented\",
  \"artifacts\": [
    {\"type\": \"plan\", \"path\": \"${EXISTING_PATH}\"}
  ],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}"

# =====================================================================
# Case 5: non-resolving path -> exit 1
# =====================================================================
assert_exit "non-resolving-path" 1 '{
  "status": "implemented",
  "artifacts": [
    {"type": "plan", "path": "specs/does_not_exist_9999/nope.md", "summary": "Bad path."}
  ],
  "metadata": {"session_id": "sess_1", "agent_type": "test-agent", "delegation_depth": 1, "delegation_path": ["a", "b"]}
}'

# =====================================================================
# Case 6: completed status rejected explicitly -> exit 1
# =====================================================================
assert_exit "completed-status-rejected" 1 "{
  \"status\": \"completed\",
  \"artifacts\": [
    {\"type\": \"plan\", \"path\": \"${EXISTING_PATH}\", \"summary\": \"A plan artifact.\"}
  ],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}"

# =====================================================================
# Case 7: empty artifacts legal for in_progress -> exit 0
# =====================================================================
assert_exit "empty-artifacts-in-progress" 0 '{
  "status": "in_progress",
  "artifacts": [],
  "metadata": {"session_id": "sess_1", "agent_type": "test-agent", "delegation_depth": 1, "delegation_path": ["a", "b"]}
}'

# =====================================================================
# Case 8: empty artifacts illegal for implemented -> exit 1
# =====================================================================
assert_exit "empty-artifacts-implemented" 1 '{
  "status": "implemented",
  "artifacts": [],
  "metadata": {"session_id": "sess_1", "agent_type": "test-agent", "delegation_depth": 1, "delegation_path": ["a", "b"]}
}'

# =====================================================================
# Case 9: missing metadata sub-field -> exit 1
# =====================================================================
assert_exit "missing-metadata-field" 1 "{
  \"status\": \"implemented\",
  \"artifacts\": [
    {\"type\": \"plan\", \"path\": \"${EXISTING_PATH}\", \"summary\": \"A plan artifact.\"}
  ],
  \"metadata\": {\"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}"

# =====================================================================
# Case 10: --fix round-trip -- a failing bare-string file becomes passing after --fix
# =====================================================================
FIX_FILE="$WORKDIR/fix-roundtrip.json"
printf '%s' "{
  \"status\": \"implemented\",
  \"artifacts\": [\"${EXISTING_PATH}\"],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}" > "$FIX_FILE"

bash "$VALIDATOR" "$FIX_FILE" >"$WORKDIR/fix-before.out" 2>&1
before_exit=$?
if [[ "$before_exit" -eq 1 ]]; then
  pass "fix-roundtrip: pre-fix file correctly FAILS (exit 1)"
else
  fail "fix-roundtrip: pre-fix file exited $before_exit (expected 1) -- see $WORKDIR/fix-before.out"
fi

bash "$VALIDATOR" "$FIX_FILE" --fix >"$WORKDIR/fix-apply.out" 2>&1
fix_apply_exit=$?
if [[ "$fix_apply_exit" -eq 0 ]]; then
  pass "fix-roundtrip: --fix run itself exits 0 (post-repair re-validation passes)"
else
  fail "fix-roundtrip: --fix run exited $fix_apply_exit (expected 0) -- see $WORKDIR/fix-apply.out"
fi

# Independently re-validate the now-repaired file without --fix, to confirm the repair persisted
# to disk (not just an in-memory re-check during the --fix invocation itself).
bash "$VALIDATOR" "$FIX_FILE" >"$WORKDIR/fix-after.out" 2>&1
after_exit=$?
if [[ "$after_exit" -eq 0 ]]; then
  pass "fix-roundtrip: repaired file independently re-validates as PASS (exit 0)"
else
  fail "fix-roundtrip: repaired file exited $after_exit on independent re-validation (expected 0) -- see $WORKDIR/fix-after.out"
fi

if ! grep -q '"type"' "$FIX_FILE" || grep -q '\["'"$EXISTING_PATH"'"\]' "$FIX_FILE"; then
  fail "fix-roundtrip: on-disk file does not show the promoted object shape"
else
  pass "fix-roundtrip: on-disk file shows the promoted object shape"
fi

# =====================================================================
# Case 11: --fix never runs implicitly (a bare-string file without --fix stays a bare string)
# =====================================================================
NOFIX_FILE="$WORKDIR/no-implicit-fix.json"
printf '%s' "{
  \"status\": \"implemented\",
  \"artifacts\": [\"${EXISTING_PATH}\"],
  \"metadata\": {\"session_id\": \"sess_1\", \"agent_type\": \"test-agent\", \"delegation_depth\": 1, \"delegation_path\": [\"a\", \"b\"]}
}" > "$NOFIX_FILE"
before_content="$(cat "$NOFIX_FILE")"
bash "$VALIDATOR" "$NOFIX_FILE" >/dev/null 2>&1
after_content="$(cat "$NOFIX_FILE")"
if [[ "$before_content" == "$after_content" ]]; then
  pass "no-implicit-fix: file is byte-identical after a non---fix validation run"
else
  fail "no-implicit-fix: file was modified by a validation run that did not pass --fix"
fi

# =====================================================================
# Summary
# =====================================================================
info "Validator resolved to: $VALIDATOR"
echo ""
echo "========================================"
echo "test-validate-return-meta.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
