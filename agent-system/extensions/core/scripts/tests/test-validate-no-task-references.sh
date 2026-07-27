#!/usr/bin/env bash
# test-validate-no-task-references.sh - Fixture-driven regression suite for
# validate-no-task-references.sh's separator-aware task/phase citation regex.
#
# Drives the hook as a real subprocess: copies it byte-for-byte into an isolated
# mktemp -d workdir and pipes a synthetic PostToolUse JSON payload
# ({"tool_input":{"file_path":...,"content":...}}) on stdin for every case, asserting on
# whether the emitted JSON contains an "additionalContext" key. The hook itself is never
# instrumented or modified for testability -- it never learns it is under test.
#
# Follows the core shell-test convention in
# context/standards/shell-script-testing.md: pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and
# exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-no-task-references.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected validate-no-task-references.sh at $HOOK_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PostToolUse payloads and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

HOOK="$WORKDIR/validate-no-task-references.sh"
cp "$HOOK_SRC" "$HOOK"
chmod +x "$HOOK"

# run_hook <file_path> <content>
# Builds a synthetic PostToolUse payload via jq (safe against quotes/parens in content) and
# pipes it to the copied hook. Echoes the hook's stdout.
run_hook() {
  local file_path="$1" content="$2"
  jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_input: {file_path: $fp, content: $c}}' \
    | bash "$HOOK"
}

# assert_triggers <label> <file_path> <content>
assert_triggers() {
  local label="$1" file_path="$2" content="$3" out
  out="$(run_hook "$file_path" "$content")"
  if echo "$out" | jq -e 'has("additionalContext")' >/dev/null 2>&1; then
    pass "$label: triggers additionalContext"
  else
    fail "$label: expected additionalContext, got: $out"
  fi
}

# assert_silent <label> <file_path> <content>
assert_silent() {
  local label="$1" file_path="$2" content="$3" out
  out="$(run_hook "$file_path" "$content")"
  if echo "$out" | jq -e 'has("additionalContext")' >/dev/null 2>&1; then
    fail "$label: expected {} (no additionalContext), got: $out"
  else
    pass "$label: stays silent ({})"
  fi
}

# =====================================================================
# Positive fixtures (must trigger)
# =====================================================================
assert_triggers "positive: task 788"            "lua/foo.lua" "See task 788 for context"
assert_triggers "positive: tasks 788-790"        "lua/foo.lua" "This spans tasks 788-790"
assert_triggers "positive: task-788"             "lua/foo.lua" "See task-788 for context"
assert_triggers "positive: task_788"             "lua/foo.lua" "See task_788 for context"
assert_triggers "positive: Task #788"            "lua/foo.lua" "Per Task #788 this changed"
assert_triggers "positive: task#788"             "lua/foo.lua" "Per task#788 this changed"
assert_triggers "positive: TASK 788 (uppercase)" "lua/foo.lua" "TASK 788 introduced this"
assert_triggers "positive: (task 788) parens"    "lua/foo.lua" "Behavior changed (task 788)"
assert_triggers "positive: task 926 phase 3"     "lua/foo.lua" "See task 926 phase 3 for the fix"
assert_triggers "positive: phase 3 of task 926"  "lua/foo.lua" "Introduced in phase 3 of task 926"

# =====================================================================
# Negative fixtures (must NOT trigger)
# =====================================================================
assert_silent "negative: bare Phase 3 heading"     "lua/foo.lua" "### Phase 3: Something"
assert_silent "negative: ### Phase 12: name"       "lua/foo.lua" "### Phase 12: Registration"
assert_silent "negative: task list (no number)"    "lua/foo.lua" "See the task list for details"
assert_silent "negative: task force (no number)"   "lua/foo.lua" "Formed a task force to fix it"
assert_silent "negative: the tasks are (no number)" "lua/foo.lua" "the tasks are enumerated below"
assert_silent "negative: taskbar788 (no boundary)" "lua/foo.lua" "Uses the taskbar788 widget class"
assert_silent "negative: ordinary sentence"        "lua/foo.lua" "This function returns the sum of two numbers."

# =====================================================================
# Exemption fixtures: specs/** file_path always exits {} even with positive content
# =====================================================================
assert_silent "exemption: relative specs/ path"    "specs/926_foo/plans/01_plan.md" "See task 788 for context"
assert_silent "exemption: absolute-prefixed specs/ path" "/abs/prefix/specs/926_foo/plans/01_plan.md" "See task 788 for context"

# =====================================================================
# Degenerate-input fixtures: empty file_path / empty content both exit {} and 0
# =====================================================================
degenerate_out="$(run_hook "" "See task 788 for context")"
degenerate_exit=$?
if [ "$degenerate_exit" -eq 0 ] && ! echo "$degenerate_out" | jq -e 'has("additionalContext")' >/dev/null 2>&1; then
  pass "degenerate: empty file_path exits {} and 0"
else
  fail "degenerate: empty file_path expected {} and exit 0, got exit=$degenerate_exit out=$degenerate_out"
fi

degenerate_out="$(run_hook "lua/foo.lua" "")"
degenerate_exit=$?
if [ "$degenerate_exit" -eq 0 ] && ! echo "$degenerate_out" | jq -e 'has("additionalContext")' >/dev/null 2>&1; then
  pass "degenerate: empty content exits {} and 0"
else
  fail "degenerate: empty content expected {} and exit 0, got exit=$degenerate_exit out=$degenerate_out"
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
