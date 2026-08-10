#!/usr/bin/env bash
# test-conflict-predicate.sh - Isolated-temp-root suite pinning the converged conflict-detection
# predicate: the shared lib (scripts/lib/file-scope-overlap.sh), task-lock.sh's cmd_acquire
# session pass, and orchestrate-batch-admit.sh's v4 session_active/corroborated_by additions.
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying deploy-root-guard.sh's
# ".claude/scripts/ or .opencode/scripts/, two levels under root" check by copying the real
# task-lock.sh, orchestrate-batch-admit.sh, deploy-root-guard.sh, and
# lib/file-scope-overlap.sh byte-for-byte into $TMPROOT/.claude/scripts/ (and
# $TMPROOT/.claude/scripts/lib/), alongside fixture state.json and specs/.sessions/ entries at
# controlled epoch timestamps -- no sleeping. Modeled directly on test-session-registry.sh's and
# test-task-lock-reap.sh's precedent (temp-root construction, pass/fail/info helpers, cleanup
# trap). No testability hooks are added to production code anywhere in this suite.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# --- Locate the real scripts this suite copies byte-for-byte ---
for req in task-lock.sh orchestrate-batch-admit.sh deploy-root-guard.sh lib/file-scope-overlap.sh lib/common.sh; do
  if [ ! -f "$SCRIPT_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/conflict-predicate-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
mkdir -p "$TMPROOT/.claude/context/reference"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
if [ -f "$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json" ]; then
  cp "$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json" "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json"
fi

TL="$TMPROOT/.claude/scripts/task-lock.sh"
BA="$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
SESSIONS_DIR="$TMPROOT/specs/.sessions"
STATE_FILE="$TMPROOT/specs/state.json"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_session_fixture() {
  # write_session_fixture <session_id> <pid> <covered_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
  local session_id="$1" pid="$2" covered_numbers_json="$3" file_scope_json="$4" mins_ago="$5"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --arg pid_source "test-fixture" \
    --arg command "/test $session_id" \
    --argjson task_numbers "$covered_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg ts "$ts" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $ts, heartbeat_at: $ts}' \
    > "$SESSIONS_DIR/${session_id}.json"
}

reset_sessions() {
  rm -f "$SESSIONS_DIR"/*.json 2>/dev/null || true
}

# Find a definitely-dead pid for dead-pid fixtures.
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

# --- Fixture state.json: each test group gets its OWN isolated scope namespace (g21/, g22/,
# g23/, g4/) so no two groups' candidates ever accidentally collide with each other -- a shared
# "path/a.sh"-style namespace across groups would make the collision scan fire for a candidate a
# LATER group intends to test in isolation (e.g. the session-input tests need a candidate that
# NEVER collides via the state.json scan, so the session pass is the only possible defer signal).
cat > "$STATE_FILE" << 'EOF'
{
  "next_project_number": 1000,
  "active_projects": [
    {"project_number": 830, "project_name": "g21_lower", "status": "not_started", "task_type": "general", "file_scope": ["g21/x"], "dependencies": []},
    {"project_number": 831, "project_name": "g21_higher", "status": "not_started", "task_type": "general", "file_scope": ["g21/x"], "dependencies": []},
    {"project_number": 840, "project_name": "g22_candidate", "status": "not_started", "task_type": "general", "file_scope": ["g22/x"], "dependencies": []},
    {"project_number": 841, "project_name": "g22_cross_batch_collider", "status": "implementing", "task_type": "general", "file_scope": ["g22/x"], "dependencies": []},
    {"project_number": 850, "project_name": "g23_predecessor", "status": "not_started", "task_type": "general", "file_scope": ["g23/x"], "dependencies": []},
    {"project_number": 851, "project_name": "g23_edge_connected", "status": "not_started", "task_type": "general", "file_scope": ["g23/x"], "dependencies": [850]},
    {"project_number": 820, "project_name": "g4_clean_candidate", "status": "not_started", "task_type": "general", "file_scope": ["g4/clean"], "dependencies": []},
    {"project_number": 821, "project_name": "g4_edge_connected", "status": "not_started", "task_type": "general", "file_scope": ["g4/unrelated_scope"], "dependencies": [820]}
  ]
}
EOF

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =============================================================================
# Group 1: Overlap parity -- bash scopes_overlap() vs spliced scopes_overlap_first
# =============================================================================
source "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"

check_parity() {
  local desc="$1" a="$2" b="$3" expected="$4"
  local bash_result
  bash_result=$(scopes_overlap "$a" "$b")
  local prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
scopes_overlap_first(\$a; \$b)"
  local jq_result
  jq_result=$(jq -n -r --argjson a "$a" --argjson b "$b" "$prog" 2>/dev/null)
  [ "$jq_result" = "null" ] && jq_result=""
  if [ "$bash_result" = "$expected" ] && [ "$jq_result" = "$expected" ]; then
    pass "1.$5: $desc (bash=\"$bash_result\" jq=\"$jq_result\")"
  else
    fail "1.$5: $desc -- expected \"$expected\", bash=\"$bash_result\" jq=\"$jq_result\""
  fi
}

check_parity "exact match" '["a/b"]' '["a/b"]' "a/b" "1"
check_parity "either-side directory-prefix" '["a/b"]' '["a/b/c.txt"]' "a/b/c.txt" "2"
check_parity "trailing-slash normalization" '["a/b/"]' '["a/b"]' "a/b" "3"
check_parity "no-overlap" '["x/y"]' '["a/b"]' "" "4"
check_parity "empty scope" '[]' '["a/b"]' "" "5"
check_parity "null scope" 'null' '["a/b"]' "" "6"

# =============================================================================
# Group 2: Bit-for-bit preservation (collision-scan branch, unchanged by the convergence)
# =============================================================================
# Case 2.1: in_batch defers only against a LOWER project_number (#831 sees #830 as a lower
# in-batch collision and defers; #830 does NOT defer against the higher-numbered #831).
v831=$("$BA" 830 831 2>/dev/null | jq -c 'select(.task_number == 831)')
v830=$("$BA" 830 831 2>/dev/null | jq -c 'select(.task_number == 830)')
c21_ok=true
[ "$(echo "$v831" | jq -r '.decision')" = "defer" ] || { c21_ok=false; info "#831 did not defer against lower in-batch #830: $v831"; }
[ "$(echo "$v831" | jq -r '.collision_scope // empty')" = "in_batch" ] || { c21_ok=false; info "#831's collision_scope was not in_batch: $v831"; }
[ "$(echo "$v830" | jq -r '.decision')" = "admit" ] || { c21_ok=false; info "#830 (lower) incorrectly deferred against higher in-batch #831: $v830"; }
if [ "$c21_ok" = true ]; then pass "2.1: in_batch defers only against a LOWER project_number"; else fail "2.1: in_batch direction case failed (see INFO lines above)"; fi

# Case 2.2: cross_batch defers unconditionally (candidate #840 has a LOWER number than #841, the
# out-of-batch colliding candidate -- still defers, since cross_batch ignores ordering entirely).
v840=$("$BA" 840 2>/dev/null | jq -c '.')
c22_ok=true
[ "$(echo "$v840" | jq -r '.decision')" = "defer" ] || { c22_ok=false; info "#840 did not defer against cross_batch #841: $v840"; }
[ "$(echo "$v840" | jq -r '.collision_scope // empty')" = "cross_batch" ] || { c22_ok=false; info "#840's collision_scope was not cross_batch: $v840"; }
[ "$(echo "$v840" | jq -r '.colliding_task_number')" = "841" ] || { c22_ok=false; info "#840 did not collide with #841: $v840"; }
if [ "$c22_ok" = true ]; then pass "2.2: cross_batch defers unconditionally regardless of project_number ordering"; else fail "2.2: cross_batch direction case failed (see INFO lines above)"; fi

# Case 2.3: a dependencies[] edge in EITHER direction excludes the pair entirely (#851 depends on
# #850 -- despite sharing an overlapping file_scope, #851 must NOT defer against #850).
v851=$("$BA" 850 851 2>/dev/null | jq -c 'select(.task_number == 851)')
c23_ok=true
[ "$(echo "$v851" | jq -r '.decision')" = "admit" ] || { c23_ok=false; info "#851 incorrectly deferred against its dependencies[]-edge-connected #850: $v851"; }
if [ "$c23_ok" = true ]; then pass "2.3: a dependencies[] edge in either direction excludes the pair from comparison entirely"; else fail "2.3: dependency-edge exclusion case failed (see INFO lines above)"; fi

# Case 2.4: self-modification runs first and short-circuits the collision scan (only meaningful
# if orchestrator-critical-paths.json is present in the fixture tree; degrade gracefully if not).
if [ -f "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" ]; then
  crit_path=$(jq -r '(.scope_roots[0] // "") as $r | (.critical_paths[0].path // "") as $p | if $r != "" and $p != "" then ($r + "/" + $p) else "" end' "$TMPROOT/.claude/context/reference/orchestrator-critical-paths.json" 2>/dev/null)
  if [ -n "$crit_path" ]; then
    smcand=901
    smjson=$(jq --argjson n "$smcand" --arg cp "$crit_path" '.active_projects += [{"project_number": $n, "project_name": "selfmod_cand", "status": "not_started", "task_type": "meta", "file_scope": [$cp], "dependencies": []}]' "$STATE_FILE")
    echo "$smjson" > "$STATE_FILE"
    v_sm=$("$BA" --invocation-count 2 "$smcand" 830 2>/dev/null | jq -c "select(.task_number == $smcand)")
    c24_ok=true
    [ "$(echo "$v_sm" | jq -r '.defer_reason // empty')" = "self_modifying" ] || { c24_ok=false; info "self-modifying candidate did not defer with defer_reason=self_modifying: $v_sm"; }
    [ "$(echo "$v_sm" | jq 'has("collision_scope")')" = "false" ] || { c24_ok=false; info "self-modifying verdict unexpectedly carries collision_scope (collision scan was not short-circuited): $v_sm"; }
    if [ "$c24_ok" = true ]; then pass "2.4: self-modification runs first and short-circuits the collision scan"; else fail "2.4: self-mod precedence case failed (see INFO lines above)"; fi
    jq --argjson n "$smcand" '.active_projects |= map(select(.project_number != $n))' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  else
    info "2.4: SKIPPED -- orchestrator-critical-paths.json present but empty scope_roots/critical_paths"
  fi
else
  info "2.4: SKIPPED -- orchestrator-critical-paths.json not found in fixture tree"
fi

# =============================================================================
# Group 3: Non-regression -- a file_scope_collision verdict matches the pre-v4 shape exactly,
# modulo $schema and corroborated_by
# =============================================================================
v840_full=$("$BA" 840 2>/dev/null | jq -c '.')
c3_ok=true
[ "$(echo "$v840_full" | jq -r '."$schema"')" = "orchestrate-batch-admit-v4" ] || { c3_ok=false; info "schema is not v4: $v840_full"; }
for f in task_number decision self_modifying defer_reason colliding_task_number colliding_task_status overlapping_path collision_scope reason; do
  echo "$v840_full" | jq -e "has(\"$f\")" >/dev/null 2>&1 || { c3_ok=false; info "v4 collision verdict missing pre-existing field: $f"; }
done
echo "$v840_full" | jq -e 'has("corroborated_by")' >/dev/null 2>&1 || { c3_ok=false; info "v4 collision verdict missing NEW corroborated_by field"; }
[ "$(echo "$v840_full" | jq -r '.corroborated_by | index("non_terminal_status")')" != "null" ] || { c3_ok=false; info "corroborated_by does not name non_terminal_status: $v840_full"; }
if [ "$c3_ok" = true ]; then pass "3: file_scope_collision verdict shape is v3-identical plus \$schema and corroborated_by"; else fail "3: non-regression shape case failed (see INFO lines above)"; fi

# =============================================================================
# Group 4: Session-input cases (D4 exclusions)
# =============================================================================
reset_sessions

# 4.1 live session contends
write_session_fixture "sess_live" "$$" '[899]' '["g4/clean"]' 2
v41=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c41_ok=true
[ "$(echo "$v41" | jq -r '.defer_reason // empty')" = "session_active" ] || { c41_ok=false; info "live session did not produce a session_active defer: $v41"; }
if [ "$c41_ok" = true ]; then pass "4.1: a live session contends"; else fail "4.1: live-session-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.2 dead-pid does not contend
write_session_fixture "sess_dead" "$DEAD_PID" '[899]' '["g4/clean"]' 20
v42=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c42_ok=true
[ "$(echo "$v42" | jq -r '.decision')" = "admit" ] || { c42_ok=false; info "dead-pid session incorrectly contended: $v42"; }
if [ "$c42_ok" = true ]; then pass "4.2: a dead-pid session does not contend"; else fail "4.2: dead-pid-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.2b dead-pid-within-grace (below the SESSION_REGISTRY_DEAD_PID_MIN floor) STILL contends --
# the verdict must be unchanged even though the reason string now differs from pid-alive.
write_session_fixture "sess_dead_grace" "$DEAD_PID" '[899]' '["g4/clean"]' 5
list_42b=$("$TL" session-list 2>/dev/null | jq -c 'select(.session_id=="sess_dead_grace")')
v42b=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c42b_ok=true
[ "$(echo "$list_42b" | jq -r '.liveness_reason')" = "dead-pid-within-grace" ] || { c42b_ok=false; info "sess_dead_grace liveness_reason was not dead-pid-within-grace: $list_42b"; }
[ "$(echo "$list_42b" | jq -r '.live')" = "true" ] || { c42b_ok=false; info "sess_dead_grace live was not true: $list_42b"; }
[ "$(echo "$v42b" | jq -r '.decision')" = "defer" ] || { c42b_ok=false; info "sess_dead_grace (dead-pid-within-grace) did not defer: $v42b"; }
[ "$(echo "$v42b" | jq -r '.defer_reason // empty')" = "session_active" ] || { c42b_ok=false; info "sess_dead_grace defer_reason was not session_active: $v42b"; }
[ "$(echo "$v42b" | jq -r '.session_liveness_reason // empty')" = "dead-pid-within-grace" ] || { c42b_ok=false; info "sess_dead_grace session_liveness_reason was not dead-pid-within-grace: $v42b"; }
if [ "$c42b_ok" = true ]; then pass "4.2b: a dead-pid-within-grace session (below the floor) still contends"; else fail "4.2b: dead-pid-within-grace-still-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.3 stale-heartbeat does not contend
write_session_fixture "sess_stale" "$$" '[899]' '["g4/clean"]' 300
v43=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c43_ok=true
[ "$(echo "$v43" | jq -r '.decision')" = "admit" ] || { c43_ok=false; info "stale-heartbeat session incorrectly contended: $v43"; }
if [ "$c43_ok" = true ]; then pass "4.3: a stale-heartbeat session does not contend"; else fail "4.3: stale-heartbeat-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.4 corrupt DOES contend. NOTE: this property is tested at the jq-harness level (calling
# session_contention() directly with a hand-built $sessions entry), not through the full
# session-list -> batch-admit integration path used by 4.1-4.3/4.5-4.7: a REAL corrupt entry
# (invalid JSON) structurally can never carry file_scope data (session-list forces
# file_scope: [] for it, since nothing can be safely read from unparseable JSON), so it can
# never actually produce an overlap hit through the integration path regardless of whether the
# liveness exclusion correctly lets it through -- that emptiness is a property of "corrupt data
# is unreadable", not of the exclusion logic being tested here. The jq-harness level isolates
# exactly the claim D4 makes: the exclusion logic itself does not filter out a "corrupt"
# liveness_reason the way it filters dead-pid/stale-heartbeat.
c44_prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
session_contention(\$cscope; \$cnum; \$own_sid; \$all; \$sessions)"
c44_all='[{"project_number": 820, "dependencies": []}]'
c44_sessions='[{"session_id": "sess_corrupt_harness", "task_numbers": [899], "file_scope": ["g4/clean"], "live": true, "liveness_reason": "corrupt"}]'
v44=$(jq -n -c --argjson cscope '["g4/clean"]' --argjson cnum 820 --arg own_sid "sess_caller" --argjson all "$c44_all" --argjson sessions "$c44_sessions" "$c44_prog" 2>/dev/null)
c44_ok=true
[ "$v44" != "null" ] && [ -n "$v44" ] || { c44_ok=false; info "session_contention() excluded a corrupt-liveness session (should DO contend, conservative direction): got null"; }
[ "$(echo "$v44" | jq -r '.liveness_reason // empty' 2>/dev/null)" = "corrupt" ] || { c44_ok=false; info "hit's liveness_reason was not corrupt: $v44"; }
if [ "$c44_ok" = true ]; then pass "4.4: session_contention() does not exclude a corrupt-liveness session (conservative direction)"; else fail "4.4: corrupt-contends case failed (see INFO lines above)"; fi
reset_sessions

# 4.5 own-session_id does not contend (self-exclusion)
write_session_fixture "sess_caller" "$$" '[899]' '["g4/clean"]' 2
v45=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c45_ok=true
[ "$(echo "$v45" | jq -r '.decision')" = "admit" ] || { c45_ok=false; info "own session_id incorrectly contended against itself: $v45"; }
if [ "$c45_ok" = true ]; then pass "4.5: a session whose session_id equals the caller's own does not contend"; else fail "4.5: self-exclusion case failed (see INFO lines above)"; fi
reset_sessions

# 4.6 a session covering ONLY edge-connected numbers does not contend (#821 depends on #820)
write_session_fixture "sess_edge_only" "$$" '[821]' '["g4/clean"]' 2
v46=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c46_ok=true
[ "$(echo "$v46" | jq -r '.decision')" = "admit" ] || { c46_ok=false; info "session covering only an edge-connected number incorrectly contended: $v46"; }
if [ "$c46_ok" = true ]; then pass "4.6: a session covering only edge-connected numbers does not contend"; else fail "4.6: edge-only-excluded case failed (see INFO lines above)"; fi
reset_sessions

# 4.7 a session covering one edge-connected AND one unrelated number DOES contend
write_session_fixture "sess_edge_plus" "$$" '[821, 822]' '["g4/clean"]' 2
v47=$("$BA" --session-id "sess_caller" 820 2>/dev/null | jq -c '.')
c47_ok=true
[ "$(echo "$v47" | jq -r '.defer_reason // empty')" = "session_active" ] || { c47_ok=false; info "session covering an edge-connected AND an unrelated number did not contend: $v47"; }
[ "$(echo "$v47" | jq -r '.colliding_task_number')" = "822" ] || { c47_ok=false; info "covered number was not the lowest non-excluded number (822): $v47"; }
if [ "$c47_ok" = true ]; then pass "4.7: a session covering one edge-connected and one unrelated number DOES contend"; else fail "4.7: partial-edge-contends case failed (see INFO lines above)"; fi
reset_sessions

# =============================================================================
# Group 5: Degradation cases
# =============================================================================
write_session_fixture "sess_live2" "$$" '[899]' '["g4/clean"]' 2
d5_out=$("$BA" 820 2>&1 1>/dev/null)
d5_verdict=$("$BA" 820 2>/dev/null | jq -c '.')
c51_ok=true
echo "$d5_out" | grep -qi "session-id not supplied" || { c51_ok=false; info "no stderr degradation line when --session-id omitted: $d5_out"; }
[ "$(echo "$d5_verdict" | jq -r '.decision')" = "admit" ] || { c51_ok=false; info "session verdict fired despite --session-id being omitted: $d5_verdict"; }
if [ "$c51_ok" = true ]; then pass "5.1: --session-id omitted skips the session input and prints the stderr degradation line"; else fail "5.1: D6-degradation case failed (see INFO lines above)"; fi
reset_sessions

rmdir "$SESSIONS_DIR" 2>/dev/null || true
d52_out=$("$BA" --session-id "sess_caller" 820 2>&1)
d52_exit=$?
c52_ok=true
[ "$d52_exit" -eq 0 ] || { c52_ok=false; info "missing specs/.sessions/ directory caused a non-zero exit: $d52_exit"; }
if [ "$c52_ok" = true ]; then pass "5.2: a missing specs/.sessions/ directory is not an error"; else fail "5.2: missing-sessions-dir case failed (see INFO lines above)"; fi
mkdir -p "$SESSIONS_DIR"

# =============================================================================
# Group 6: session-list cases
# =============================================================================
write_session_fixture "sess_list_live" "$$" '[899]' '["path/a.sh"]' 2
echo "not valid json" > "$SESSIONS_DIR/sess_list_corrupt.json"
before_listing=$(find "$SESSIONS_DIR" -type f -name '*.json' -exec md5sum {} \; | sort)
list_out=$("$TL" session-list 2>&1)
list_exit=$?
after_listing=$(find "$SESSIONS_DIR" -type f -name '*.json' -exec md5sum {} \; | sort)

c6_ok=true
[ "$list_exit" -eq 0 ] || { c6_ok=false; info "session-list exit code was $list_exit, expected 0"; }
line_count=$(echo "$list_out" | grep -c '.')
[ "$line_count" -eq 2 ] || { c6_ok=false; info "expected 2 NDJSON lines, got $line_count"; }
while IFS= read -r line; do
  [ -z "$line" ] && continue
  echo "$line" | jq -e . >/dev/null 2>&1 || { c6_ok=false; info "session-list line did not parse as JSON: $line"; }
  echo "$line" | jq -e 'has("live")' >/dev/null 2>&1 || { c6_ok=false; info "session-list line missing 'live': $line"; }
  echo "$line" | jq -e 'has("liveness_reason")' >/dev/null 2>&1 || { c6_ok=false; info "session-list line missing 'liveness_reason': $line"; }
done <<< "$list_out"
echo "$list_out" | grep -q '"liveness_reason":"corrupt"' || { c6_ok=false; info "corrupt entry not present with liveness_reason=corrupt: $list_out"; }
[ "$before_listing" = "$after_listing" ] || { c6_ok=false; info "specs/.sessions/ was modified by session-list"; }
if [ "$c6_ok" = true ]; then pass "6: session-list emits valid NDJSON with live/liveness_reason on every line, corrupt entry included, registry unmodified"; else fail "6: session-list case failed (see INFO lines above)"; fi
reset_sessions

# =============================================================================
# Group 7: Fail-closed case -- lib absent, both consumers exit 2 with a remedy message
# =============================================================================
mv "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh.bak"

tl_fc_out=$("$TL" acquire 820 test sess_fc 2>&1)
tl_fc_exit=$?
c71_ok=true
[ "$tl_fc_exit" -eq 2 ] || { c71_ok=false; info "task-lock.sh acquire with lib absent exited $tl_fc_exit, expected 2: $tl_fc_out"; }
echo "$tl_fc_out" | grep -qi "could not source" || { c71_ok=false; info "task-lock.sh fail-closed message missing remedy text: $tl_fc_out"; }
if [ "$c71_ok" = true ]; then pass "7.1: task-lock.sh acquire fails CLOSED (exit 2, remedy message) when the lib is absent"; else fail "7.1: task-lock.sh fail-closed case failed (see INFO lines above)"; fi

ba_fc_out=$("$BA" 820 2>&1)
ba_fc_exit=$?
c72_ok=true
[ "$ba_fc_exit" -eq 2 ] || { c72_ok=false; info "orchestrate-batch-admit.sh with lib absent exited $ba_fc_exit, expected 2: $ba_fc_out"; }
echo "$ba_fc_out" | grep -qi "could not source" || { c72_ok=false; info "orchestrate-batch-admit.sh fail-closed message missing remedy text: $ba_fc_out"; }
if [ "$c72_ok" = true ]; then pass "7.2: orchestrate-batch-admit.sh fails CLOSED (exit 2, remedy message) when the lib is absent"; else fail "7.2: orchestrate-batch-admit.sh fail-closed case failed (see INFO lines above)"; fi

mv "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh.bak" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"

# =============================================================================
# Group 8: deployed-tree reachability
# =============================================================================
info "8: deployed-tree reachability for scripts/lib/file-scope-overlap.sh and this suite's own file was confirmed directly against .claude/scripts/ during implementation (see the originating plan's Phase 8 completion notes) -- not re-derived here since this suite's own SCRIPT_DIR is ambiguous between a source-store and a deployed invocation and cannot reliably self-locate the deploy root."

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
