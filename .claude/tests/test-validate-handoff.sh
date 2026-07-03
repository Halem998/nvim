#!/usr/bin/env bash
# test-validate-handoff.sh — Fixture-based tests for validate-handoff.sh
#
# USAGE:
#   bash .claude/tests/test-validate-handoff.sh
#
# EXITS:
#   0 — All tests pass
#   1 — One or more tests failed
#
# NOTES:
#   - Tests must be run from the project root (where .claude/ is a direct child)
#   - Each fixture is a temp JSON handoff file (mktemp), passed as a path argument to
#     validate-handoff.sh (it communicates via exit code + stdout, not exported variables)
#   - Assertions: exit code AND presence/absence of specific [FAIL]/[PASS]/[WARN]
#     substrings in stdout
#   - Reference: .claude/context/contracts/wrap-up.md (H9 handoff schema, status/skeleton
#     interaction table, 7-field sorry_inventory schema)

set -euo pipefail

PASS=0
FAIL=0
FAILURES=""

VALIDATE_SCRIPT=".claude/scripts/validate-handoff.sh"

# ---------------------------------------------------------------------------
# Helper: run_test <test_name> <json_content> <expected_exit_code>
#
# Reads two global arrays set by the caller before invocation:
#   MUST_CONTAIN     - substrings that must appear in stdout
#   MUST_NOT_CONTAIN - substrings that must NOT appear in stdout
#
# Writes json_content to a temp file, runs validate-handoff.sh against it,
# and asserts the exit code and substring expectations.
# ---------------------------------------------------------------------------
run_test() {
  local test_name="$1"
  local json_content="$2"
  local expected_exit="$3"

  local tmp_file
  tmp_file=$(mktemp --suffix=.json)
  printf '%s' "$json_content" > "$tmp_file"

  local output actual_exit
  output=$(bash "$VALIDATE_SCRIPT" "$tmp_file" 2>&1) && actual_exit=0 || actual_exit=$?
  # Strip ANSI color escape codes so substring assertions match the plain-text
  # message content regardless of the RED/GREEN/YELLOW/NC codes surrounding it.
  output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  rm -f "$tmp_file"

  local test_ok=true

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    test_ok=false
    FAILURES="$FAILURES\n  FAIL [$test_name]: expected exit code $expected_exit, got $actual_exit"
  fi

  local pattern
  for pattern in "${MUST_CONTAIN[@]}"; do
    if ! echo "$output" | grep -qF "$pattern"; then
      test_ok=false
      FAILURES="$FAILURES\n  FAIL [$test_name]: expected output to contain '$pattern'"
    fi
  done

  for pattern in "${MUST_NOT_CONTAIN[@]}"; do
    if echo "$output" | grep -qF "$pattern"; then
      test_ok=false
      FAILURES="$FAILURES\n  FAIL [$test_name]: expected output to NOT contain '$pattern'"
    fi
  done

  if [[ "$test_ok" == "true" ]]; then
    echo "  PASS [$test_name]"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test Suite
# ---------------------------------------------------------------------------

echo "Running validate-handoff.sh fixture tests..."
echo ""

# --- Fixture (a): STANDARD unchanged (skeleton absent, sorry_inventory absent) ---
MUST_CONTAIN=(
  "[PASS] JSON is valid and parsable"
  "[WARN] Optional field absent: sorry_inventory"
  "HANDOFF VALIDATION PASSED WITH WARNINGS"
)
MUST_NOT_CONTAIN=(
  "skeleton"
  "[FAIL]"
)
run_test "standard-unchanged" '{
  "status": "implemented",
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": []
}' 0

# --- Fixture (b): VALID skeleton (well-formed strategic entry) ---
MUST_CONTAIN=(
  "[PASS] skeleton=true paired with status='implemented' (valid combination)"
  "fully tracked"
)
MUST_NOT_CONTAIN=(
  "[FAIL]"
)
run_test "valid-skeleton" '{
  "status": "implemented",
  "skeleton": true,
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": [],
  "sorry_inventory": [
    {
      "file": "Foo.lean",
      "line": 10,
      "statement": "theorem foo : True",
      "strategic": true,
      "assumption": "upstream lemma Bar.baz will be available",
      "why_deferred": "needs upstream lemma not yet in Mathlib",
      "follow_up_task": 900
    }
  ]
}' 0

# --- Fixture (c): skeleton missing sorry_inventory ---
MUST_CONTAIN=(
  "requires non-empty sorry_inventory"
)
MUST_NOT_CONTAIN=()
run_test "missing-inventory" '{
  "status": "implemented",
  "skeleton": true,
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": []
}' 1

# --- Fixture (d): skeleton entry missing follow_up_task ---
MUST_CONTAIN=(
  "follow_up_task is null/missing"
)
MUST_NOT_CONTAIN=()
run_test "missing-follow_up_task" '{
  "status": "implemented",
  "skeleton": true,
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": [],
  "sorry_inventory": [
    {
      "file": "Foo.lean",
      "line": 10,
      "statement": "theorem foo : True",
      "strategic": true,
      "assumption": "upstream lemma Bar.baz will be available",
      "why_deferred": "needs upstream lemma not yet in Mathlib",
      "follow_up_task": null
    }
  ]
}' 1

# --- Fixture (e): skeleton with wrong status ---
MUST_CONTAIN=(
  "Invalid status/skeleton combination"
)
MUST_NOT_CONTAIN=()
run_test "wrong-status" '{
  "status": "partial",
  "skeleton": true,
  "phases_completed": 1,
  "phases_total": 3,
  "blockers": [],
  "continuation_path": "specs/000_example/handoffs/example-handoff.md",
  "sorry_inventory": [
    {
      "file": "Foo.lean",
      "line": 10,
      "statement": "theorem foo : True",
      "strategic": true,
      "assumption": "upstream lemma Bar.baz will be available",
      "why_deferred": "needs upstream lemma not yet in Mathlib",
      "follow_up_task": 900
    }
  ]
}' 1

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "$FAILURES"
  echo ""
  echo "TESTS FAILED"
  exit 1
else
  echo ""
  echo "ALL TESTS PASSED"
  exit 0
fi
