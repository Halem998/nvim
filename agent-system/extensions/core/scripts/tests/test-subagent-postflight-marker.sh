#!/usr/bin/env bash
# test-subagent-postflight-marker.sh - Fixture-driven regression suite for the
# malformed-postflight-marker fix: subagent-postflight.sh's diagnosable block reason and
# events-log-lifecycle.sh's deviation-event telemetry, both guarded by `jq empty` against a
# marker that fails to parse as JSON.
#
# Structural model: test-guard-destructive-git.sh's SCRIPT_DIR-relative hook path (resolves in
# both source-store and deployed layouts with no branching), pass()/fail()/info() helpers,
# PASSED/FAILED counters, mktemp -d fixtures with trap cleanup EXIT, exit 0 all-pass / 1 any-fail.
#
# subagent-postflight.sh has no dependency on its own script-path depth (it locates markers via
# `find specs ...` against cwd), so its cases run the source-store or deployed hook directly, in
# place, as a real subprocess -- exactly like test-guard-destructive-git.sh does.
#
# events-log-lifecycle.sh is different: events-append.sh (which it shells out to) resolves its
# write target via `deploy-root-guard.sh` + a script-path-depth calculation that (a) REFUSES to
# run at all from a source-store path (deploy-root-guard.sh requires the immediate parent
# directory to be named `.claude` or `.opencode`) and (b) even when deployed, always resolves to
# THIS repo's real specs/events.jsonl regardless of the subprocess's cwd -- there is no way to
# redirect it via cwd alone. Driving it in place would therefore either hard-fail outside a
# deployed tree, or (if deployed) silently append test rows into the real events store. The
# events companion case instead builds an ISOLATED copy of the four files it needs
# (events-log-lifecycle.sh, events-append.sh, deploy-root-guard.sh, lib/common.sh) under a fresh
# mktemp -d tree shaped as <tmp>/.claude/{hooks,scripts,scripts/lib}/ with <tmp>/specs/ as a
# sibling -- satisfying deploy-root-guard.sh's parent-name check while anchoring
# events-append.sh's root resolution entirely inside the disposable fixture, never touching the
# real repo's specs/events.jsonl.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This single relative path resolves to agent-system/extensions/core/hooks/ in source-store mode
# and to .claude/hooks/ in deployed mode, with no branching -- see plan Phase 1/3.
POSTFLIGHT_HOOK="$SCRIPT_DIR/../../hooks/subagent-postflight.sh"
# Source-of-copy paths for the isolated events-companion fixture (see header comment above).
EVENTS_HOOK_SRC="$SCRIPT_DIR/../../hooks/events-log-lifecycle.sh"
EVENTS_APPEND_SRC="$SCRIPT_DIR/../events-append.sh"
DEPLOY_ROOT_GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"
COMMON_LIB_SRC="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

for f in "$POSTFLIGHT_HOOK" "$EVENTS_HOOK_SRC" "$EVENTS_APPEND_SRC" "$DEPLOY_ROOT_GUARD_SRC" "$COMMON_LIB_SRC"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file not found at $f" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixtures and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# subagent-postflight.sh fixtures
# =====================================================================

# make_postflight_fixture <task_num> -- creates a fresh scratch dir with an empty
# specs/<task_num>_test/ task directory (no marker yet). Echoes the fixture dir.
make_postflight_fixture() {
  local task_num="$1" d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/specs/${task_num}_test"
  echo "$d"
}

# run_postflight <fixture_dir> -- runs subagent-postflight.sh as a real subprocess with cwd set
# to <fixture_dir>. Echoes stdout.
run_postflight() {
  local d="$1"
  ( cd "$d" && bash "$POSTFLIGHT_HOOK" 2>/dev/null )
}

# =====================================================================
# Fixture self-check (MUST run first): a broken fixture must fail loudly rather than let every
# later case pass vacuously via the no-marker allow-stop path.
# =====================================================================
self_check_dir="$(make_postflight_fixture 901)"
echo '{"reason":"self-check reason"}' > "$self_check_dir/specs/901_test/.postflight-pending"
self_check_out="$(run_postflight "$self_check_dir")"
rm -rf "$self_check_dir"
if echo "$self_check_out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "fixture self-check: hook reaches the block branch for a well-formed marker"
else
  fail "fixture self-check: expected a block decision, got: $self_check_out"
fi

# =====================================================================
# Case (a): well-formed marker with .reason present -> passthrough unchanged
# =====================================================================
d="$(make_postflight_fixture 902)"
echo '{"reason":"custom pending reason"}' > "$d/specs/902_test/.postflight-pending"
out="$(run_postflight "$d")"
rm -rf "$d"
if echo "$out" | jq -e '.reason == "custom pending reason"' >/dev/null 2>&1; then
  pass "case (a): well-formed .reason passes through unchanged"
else
  fail "case (a): expected reason 'custom pending reason', got: $out"
fi

# =====================================================================
# Case (b): well-formed marker missing .reason -> default "Postflight operations pending" (AC 2)
# =====================================================================
d="$(make_postflight_fixture 903)"
echo '{}' > "$d/specs/903_test/.postflight-pending"
out="$(run_postflight "$d")"
rm -rf "$d"
if echo "$out" | jq -e '.reason == "Postflight operations pending"' >/dev/null 2>&1; then
  pass "case (b): missing .reason falls back to the default (AC 2)"
else
  fail "case (b): expected default reason, got: $out"
fi

# =====================================================================
# Case (c): non-JSON (key=value shaped) marker -> valid JSON stdout, non-empty reason naming
# the marker path and stating a parse failure (AC 1)
# =====================================================================
d="$(make_postflight_fixture 904)"
printf 'session_id=sess_1\nskill=foo\noperation=bar\n' > "$d/specs/904_test/.postflight-pending"
out="$(run_postflight "$d")"
rm -rf "$d"
if ! echo "$out" | jq empty >/dev/null 2>&1; then
  fail "case (c): stdout is not valid JSON: $out"
else
  reason="$(echo "$out" | jq -r '.reason')"
  if [[ "$reason" == *".postflight-pending"* ]] && [[ "$reason" == *"parse"* || "$reason" == *"JSON"* ]]; then
    pass "case (c): non-JSON marker yields a diagnostic reason naming the marker path (AC 1)"
  else
    fail "case (c): reason does not name the marker path / parse failure: $reason"
  fi
  if [ "$reason" != "Postflight operations pending" ]; then
    pass "case (c): parse-failure reason is textually distinct from the missing-.reason default (AC 2)"
  else
    fail "case (c): parse-failure collapsed into the missing-.reason default"
  fi
fi

# =====================================================================
# Case (d): .reason containing a double quote, a backslash, and a literal newline -> stdout
# passes jq empty and .reason round-trips to the original string (AC 3)
# =====================================================================
d="$(make_postflight_fixture 905)"
jq -n '{reason: "line one\nwith \"quotes\" and \\backslash"}' > "$d/specs/905_test/.postflight-pending"
out="$(run_postflight "$d")"
rm -rf "$d"
if ! echo "$out" | jq empty >/dev/null 2>&1; then
  fail "case (d): stdout is not valid JSON: $out"
else
  roundtrip="$(echo "$out" | jq -r '.reason')"
  expected="$(printf 'line one\nwith "quotes" and \\backslash')"
  if [ "$roundtrip" = "$expected" ]; then
    pass "case (d): quote/backslash/newline reason round-trips through valid JSON (AC 3)"
  else
    fail "case (d): round-trip mismatch. Expected: $(printf '%q' "$expected") Got: $(printf '%q' "$roundtrip")"
  fi
fi

# =====================================================================
# Case (e): loop-guard interaction unchanged -- with the guard already at MAX_CONTINUATIONS, a
# malformed marker still allows the stop ({}), confirming the fail-closed decision stays bounded
# =====================================================================
d="$(make_postflight_fixture 906)"
printf 'not=json\n' > "$d/specs/906_test/.postflight-pending"
echo "3" > "$d/specs/906_test/.postflight-loop-guard"
out="$(run_postflight "$d")"
rm -rf "$d"
if [ "$out" = "{}" ]; then
  pass "case (e): loop guard at MAX_CONTINUATIONS allows the stop even with a malformed marker"
else
  fail "case (e): expected {} (stop allowed) at loop-guard cap, got: $out"
fi

# =====================================================================
# events-log-lifecycle.sh companion case (AC 4): isolated deployed-layout fixture (see header
# comment) so events-append.sh's root resolution never touches the real repo's events.jsonl.
# =====================================================================

# make_events_fixture -- builds an isolated <tmp>/.claude/{hooks,scripts,scripts/lib}/ tree
# (copies of the four files under test) plus a sibling <tmp>/specs/ directory. Echoes the tmp
# root.
make_events_fixture() {
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "$d/.claude/hooks" "$d/.claude/scripts/lib" "$d/specs"
  cp "$EVENTS_HOOK_SRC" "$d/.claude/hooks/events-log-lifecycle.sh"
  cp "$EVENTS_APPEND_SRC" "$d/.claude/scripts/events-append.sh"
  cp "$DEPLOY_ROOT_GUARD_SRC" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_LIB_SRC" "$d/.claude/scripts/lib/common.sh"
  chmod +x "$d/.claude/hooks/events-log-lifecycle.sh" "$d/.claude/scripts/events-append.sh" \
    "$d/.claude/scripts/deploy-root-guard.sh"
  echo "$d"
}

# run_events_hook <fixture_root> <agent_id> <cwd_field> <cc_session_id> -- runs the isolated
# copy of events-log-lifecycle.sh as a subprocess with cwd set to <fixture_root>, piping a
# synthetic SubagentStop payload. Echoes stdout.
run_events_hook() {
  local root="$1" agent_id="$2" cwd_field="$3" cc_sid="$4"
  ( cd "$root" && jq -n --arg aid "$agent_id" --arg cwd "$cwd_field" --arg sid "$cc_sid" \
      '{agent_id: $aid, cwd: $cwd, session_id: $sid}' \
    | bash "$root/.claude/hooks/events-log-lifecycle.sh" 2>/dev/null )
}

# --- Sub-case: malformed marker + matching specs/state.json entry -> exactly one deviation
# event with a valid session_id ---
events_root="$(make_events_fixture)"
mkdir -p "$events_root/specs/907_test"
printf 'session_id=sess_1\nskill=foo\n' > "$events_root/specs/907_test/.postflight-pending"
jq -n '{active_projects: [{project_number: 907, session_id: "sess_1_abcdef", task_type: "meta", status: "implementing"}]}' \
  > "$events_root/specs/state.json"
events_out="$(run_events_hook "$events_root" "agent1" "$events_root" "cc-uuid-1")"
event_count=0
if [ -f "$events_root/specs/events.jsonl" ]; then
  event_count="$(wc -l < "$events_root/specs/events.jsonl" | tr -d ' ')"
fi
if [ "$events_out" = "{}" ] && [ "$event_count" = "1" ] \
  && jq -e '.category == "deviation" and (.session_id | test("^sess_[0-9]+_[a-zA-Z0-9]+$")) and .event_type == "malformed_postflight_marker"' \
       "$events_root/specs/events.jsonl" >/dev/null 2>&1; then
  pass "events companion: malformed marker + matching state.json -> exactly one deviation event (AC 4)"
else
  fail "events companion: expected exactly one deviation event and {} stdout. stdout=$events_out count=$event_count"
fi
rm -rf "$events_root"

# --- Sub-case: malformed marker, NO matching specs/state.json entry -> no event appended,
# hook still echoes {} and exits 0 ---
events_root2="$(make_events_fixture)"
mkdir -p "$events_root2/specs/908_test"
printf 'session_id=sess_1\nskill=foo\n' > "$events_root2/specs/908_test/.postflight-pending"
jq -n '{active_projects: []}' > "$events_root2/specs/state.json"
events_out2="$(run_events_hook "$events_root2" "agent1" "$events_root2" "cc-uuid-1")"
if [ "$events_out2" = "{}" ] && [ ! -f "$events_root2/specs/events.jsonl" ]; then
  pass "events companion: no matching state.json entry -> no event, clean {} exit"
else
  fail "events companion: expected no event and {} stdout with no matching state.json entry. stdout=$events_out2"
fi
rm -rf "$events_root2"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
