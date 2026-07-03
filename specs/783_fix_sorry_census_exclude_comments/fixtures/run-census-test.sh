#!/usr/bin/env bash
# run-census-test.sh -- fixture harness for lean-sorry-census.sh (task 783)
#
# Validates that the shared census script counts ONLY genuine code sorries in
# SorryCensus.lean, with correct original file:line numbers, and excludes every
# comment/docstring/nested-comment/string-literal false-positive pattern.
#
# Usage:
#   bash run-census-test.sh
#
# Expected fixture facts (see SorryCensus.lean):
#   - Exactly 2 genuine sorries: SorryCensus.lean:10 and SorryCensus.lean:40
#   - 0 sorries from: full-line `--` comment, trailing inline `--` comment,
#     single-line docstring, multi-line docstring (task-431 pattern), nested
#     `/- -/` block comment, commented-out TODO stub (task-431 pattern),
#     string-literal edge case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CENSUS_SCRIPT="$REPO_ROOT/.claude/scripts/lean-sorry-census.sh"
FIXTURE_FILE="$SCRIPT_DIR/SorryCensus.lean"

EXPECTED_COUNT=2
EXPECTED_LINES="SorryCensus.lean:10 SorryCensus.lean:40"

pass=0
fail=0

report_dry_structure() {
  echo "[run-census-test] $CENSUS_SCRIPT not found yet -- reporting dry structure only."
  echo "[run-census-test] Once implemented, this harness will assert:"
  echo "  - total sorry_count == $EXPECTED_COUNT"
  echo "  - reported file:line entries == { $EXPECTED_LINES }"
  echo "  - zero false positives from: full-line comment, trailing inline comment,"
  echo "    single-line docstring, multi-line docstring (task-431 case), nested block"
  echo "    comment, commented-out TODO stub (task-431 case), string-literal edge case"
  exit 2
}

if [[ ! -f "$CENSUS_SCRIPT" ]]; then
  report_dry_structure
fi

echo "[run-census-test] Running census against fixture: $FIXTURE_FILE"
output="$("$CENSUS_SCRIPT" "$FIXTURE_FILE" 2>&1)"
status=$?

echo "$output"

if [[ $status -ne 0 ]]; then
  echo "[run-census-test] FAIL: census script exited non-zero ($status)"
  fail=$((fail + 1))
fi

# Extract the reported total count (line of the form: "sorry_count: N")
actual_count="$(echo "$output" | grep -oE 'sorry_count[:=][[:space:]]*[0-9]+' | grep -oE '[0-9]+' | tail -1)"

if [[ "$actual_count" == "$EXPECTED_COUNT" ]]; then
  echo "[run-census-test] PASS: sorry_count == $EXPECTED_COUNT"
  pass=$((pass + 1))
else
  echo "[run-census-test] FAIL: sorry_count == '$actual_count', expected $EXPECTED_COUNT"
  fail=$((fail + 1))
fi

# Extract reported file:line entries (lines of the form path:line:...)
actual_lines="$(echo "$output" | grep -oE 'SorryCensus\.lean:[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ $//')"
expected_lines_sorted="$(echo "$EXPECTED_LINES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')"

if [[ "$actual_lines" == "$expected_lines_sorted" ]]; then
  echo "[run-census-test] PASS: reported lines == { $expected_lines_sorted }"
  pass=$((pass + 1))
else
  echo "[run-census-test] FAIL: reported lines == '$actual_lines', expected '$expected_lines_sorted'"
  fail=$((fail + 1))
fi

# Explicit false-positive-pattern checks: none of these substrings/lines may appear
# in the inventory output at all (they'd only appear if a comment/string sorry leaked
# through as a reported line).
for bad_line in "SorryCensus.lean:6" "SorryCensus.lean:13" "SorryCensus.lean:16" \
                 "SorryCensus.lean:21" "SorryCensus.lean:26" "SorryCensus.lean:31" \
                 "SorryCensus.lean:36"; do
  if echo "$output" | grep -qE "$bad_line([^0-9]|$)"; then
    echo "[run-census-test] FAIL: false positive reported at $bad_line"
    fail=$((fail + 1))
  fi
done

echo ""
echo "[run-census-test] Results: $pass passed, $fail failed"

if [[ $fail -eq 0 ]]; then
  exit 0
else
  exit 1
fi
