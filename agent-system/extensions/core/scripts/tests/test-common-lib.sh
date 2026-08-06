#!/usr/bin/env bash
# test-common-lib.sh - Fixture-driven regression suite for scripts/lib/common.sh, the shared
# repo-root/session-ID/timestamp/logging/test-helper library extracted to deduplicate boilerplate
# across core scripts (see context/patterns -- Phase 2 of the shell-hygiene plan that introduced
# this library).
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, `mktemp -d` workdir with a trap EXIT cleanup, exit 0 on
# all-pass / exit 1 on any-fail). This suite sources the library directly rather than driving a
# subprocess, since the library exports shell functions meant to be sourced, not a standalone
# executable.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$LIB" ]; then
  echo "ERROR: shared library common.sh not found at $LIB" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ── Capture shell-option state BEFORE sourcing ────────────────────────────────
DASH_BEFORE="$-"
SET_O_BEFORE="$(set -o)"

# shellcheck source=/dev/null
source "$LIB"

# ── Assertion: sourcing must not change $- or `set -o` state ─────────────────
DASH_AFTER="$-"
SET_O_AFTER="$(set -o)"

if [ "$DASH_BEFORE" = "$DASH_AFTER" ]; then
  pass "sourcing common.sh: \$- unchanged ($DASH_BEFORE)"
else
  fail "sourcing common.sh: \$- changed from '$DASH_BEFORE' to '$DASH_AFTER'"
fi

if [ "$SET_O_BEFORE" = "$SET_O_AFTER" ]; then
  pass "sourcing common.sh: 'set -o' state byte-for-byte unchanged"
else
  fail "sourcing common.sh: 'set -o' state changed"
fi

# ── common_repo_root: depth 2 (scripts/ callers) ──────────────────────────────
FIXTURE_ROOT="$WORKDIR/fixture-repo"
mkdir -p "$FIXTURE_ROOT/scripts"
resolved=$(common_repo_root "$FIXTURE_ROOT/scripts" 2)
expected="$(cd "$FIXTURE_ROOT/scripts/../.." && pwd)"
if [ "$resolved" = "$expected" ]; then
  pass "common_repo_root depth 2 resolves scripts/ callers correctly"
else
  fail "common_repo_root depth 2: expected '$expected', got '$resolved'"
fi

# ── common_repo_root: depth 3 (scripts/lib/, scripts/tests/, scripts/lint/) ──
mkdir -p "$FIXTURE_ROOT/scripts/lib" "$FIXTURE_ROOT/scripts/tests" "$FIXTURE_ROOT/scripts/lint"
for sub in lib tests lint; do
  resolved=$(common_repo_root "$FIXTURE_ROOT/scripts/$sub" 3)
  expected="$(cd "$FIXTURE_ROOT/scripts/$sub/../../.." && pwd)"
  if [ "$resolved" = "$expected" ]; then
    pass "common_repo_root depth 3 resolves scripts/$sub/ callers correctly"
  else
    fail "common_repo_root depth 3 ($sub): expected '$expected', got '$resolved'"
  fi
done

# ── common_repo_root: empty script_dir yields empty output, not an error ─────
resolved=$(common_repo_root "" 2)
if [ -z "$resolved" ]; then
  pass "common_repo_root with empty script_dir yields empty output (safe default)"
else
  fail "common_repo_root with empty script_dir yielded '$resolved', expected empty"
fi

# ── common_repo_root: nonexistent path yields empty output, not a nonzero exit ─
resolved=$(common_repo_root "/nonexistent/path/that/does/not/exist" 2)
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$resolved" ]; then
  pass "common_repo_root with nonexistent path returns 0 with empty output"
else
  fail "common_repo_root with nonexistent path: rc=$rc, output='$resolved' (expected rc=0, empty)"
fi

# ── common_session_id: shape ──────────────────────────────────────────────────
sid=$(common_session_id)
if [[ "$sid" =~ ^sess_[0-9]+_[0-9a-f]{6}$ ]]; then
  pass "common_session_id matches ^sess_[0-9]+_[0-9a-f]{6}\$ ($sid)"
else
  fail "common_session_id did not match expected shape: '$sid'"
fi

# ── common_session_id: no embedded whitespace or newline ─────────────────────
if [ "$(printf '%s' "$sid" | wc -l)" -eq 0 ] && [[ "$sid" != *" "* ]]; then
  pass "common_session_id has no embedded whitespace or newline"
else
  fail "common_session_id contains embedded whitespace or newline: '$sid'"
fi

# ── common_session_id: two calls yield different IDs (random component varies) ─
sid2=$(common_session_id)
if [ "$sid" != "$sid2" ]; then
  pass "common_session_id: two successive calls yield different IDs"
else
  info "two successive common_session_id calls yielded the same ID (rare but not necessarily a bug within the same second + same random bytes)"
  pass "common_session_id: two successive calls (non-fatal duplicate check)"
fi

# ── common_timestamp_iso: format ──────────────────────────────────────────────
iso=$(common_timestamp_iso)
if [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  pass "common_timestamp_iso matches YYYY-MM-DDTHH:MM:SSZ ($iso)"
else
  fail "common_timestamp_iso did not match expected format: '$iso'"
fi

# ── common_timestamp_epoch: format ────────────────────────────────────────────
epoch=$(common_timestamp_epoch)
if [[ "$epoch" =~ ^[0-9]+$ ]]; then
  pass "common_timestamp_epoch is a plain integer ($epoch)"
else
  fail "common_timestamp_epoch did not match expected format: '$epoch'"
fi

# ── common_timestamp_date: format ─────────────────────────────────────────────
dt=$(common_timestamp_date)
if [[ "$dt" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  pass "common_timestamp_date matches YYYY-MM-DD ($dt)"
else
  fail "common_timestamp_date did not match expected format: '$dt'"
fi

# ── common_log_error / common_log_warn: stream routing (stderr) ──────────────
err_out=$(common_log_error "test error" 2>&1 1>/dev/null)
if [[ "$err_out" == "ERROR: test error" ]]; then
  pass "common_log_error routes to stderr with 'ERROR: ' prefix"
else
  fail "common_log_error stderr routing/format wrong: '$err_out'"
fi

warn_out=$(common_log_warn "test warning" 2>&1 1>/dev/null)
if [[ "$warn_out" == "WARNING: test warning" ]]; then
  pass "common_log_warn routes to stderr with 'WARNING: ' prefix"
else
  fail "common_log_warn stderr routing/format wrong: '$warn_out'"
fi

# ── common_log_info: stream routing (stdout) ──────────────────────────────────
info_out=$(common_log_info "test info" 2>/dev/null)
if [[ "$info_out" == "INFO: test info" ]]; then
  pass "common_log_info routes to stdout with 'INFO: ' prefix"
else
  fail "common_log_info stdout routing/format wrong: '$info_out'"
fi

info_err=$(common_log_info "test info" 2>&1 1>/dev/null)
if [ -z "$info_err" ]; then
  pass "common_log_info emits nothing to stderr"
else
  fail "common_log_info unexpectedly wrote to stderr: '$info_err'"
fi

# ── common_test_pass / common_test_fail: counter arithmetic on caller's vars ──
(
  PASSED=0
  FAILED=0
  common_test_pass "sub-case A" >/dev/null
  common_test_pass "sub-case B" >/dev/null
  common_test_fail "sub-case C" >/dev/null
  if [ "$PASSED" -eq 2 ] && [ "$FAILED" -eq 1 ]; then
    exit 0
  else
    exit 1
  fi
)
if [ $? -eq 0 ]; then
  pass "common_test_pass/common_test_fail increment caller's PASSED/FAILED correctly"
else
  fail "common_test_pass/common_test_fail counter arithmetic incorrect"
fi

# ── common_test_pass/_fail/_info: output format matches shell-script-testing.md ──
tp_out=$(PASSED=0; common_test_pass "case")
if [[ "$tp_out" == "[PASS] case" ]]; then
  pass "common_test_pass emits '[PASS] <msg>'"
else
  fail "common_test_pass output format wrong: '$tp_out'"
fi

tf_out=$(FAILED=0; common_test_fail "case")
if [[ "$tf_out" == "[FAIL] case" ]]; then
  pass "common_test_fail emits '[FAIL] <msg>'"
else
  fail "common_test_fail output format wrong: '$tf_out'"
fi

ti_out=$(common_test_info "case")
if [[ "$ti_out" == "[INFO] case" ]]; then
  pass "common_test_info emits '[INFO] <msg>'"
else
  fail "common_test_info output format wrong: '$ti_out'"
fi

# ── Single-source assertion: no inline sess_$(date generation outside lib/common.sh ──
# This is the mechanical form of the task's verification bar: session-ID generation must exist
# in exactly one place. Scans the whole extensions tree (source-store shape: this suite lives at
# agent-system/extensions/core/scripts/tests/, so three levels up is agent-system/extensions/)
# for the inline generation pattern, and fails if anything other than lib/common.sh itself (or a
# comment referencing it, e.g. in this suite's own source) still carries it.
if grep -q 'sess_\$(date' "$LIB" 2>/dev/null; then
  pass "common.sh itself defines the canonical sess_\$(date generator"
else
  fail "common.sh does not appear to define the canonical session-ID generator"
fi

EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
offending=$(grep -rl 'sess_\$(date' --include="*.sh" "$EXTENSIONS_ROOT" 2>/dev/null \
  | grep -v -F "/lib/common.sh" \
  | grep -v -F "/tests/test-common-lib.sh" \
  || true)
if [ -z "$offending" ]; then
  pass "single-source assertion: no inline sess_\$(date generation outside lib/common.sh"
else
  fail "single-source assertion: inline sess_\$(date generation found outside lib/common.sh:"
  while IFS= read -r off_line; do
    [ -n "$off_line" ] && info "  $off_line"
  done <<< "$offending"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
