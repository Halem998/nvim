#!/usr/bin/env bash
# test-four-tier-conflict.sh - Isolated-temp-root suite proving the four-tier conflict-response
# ladder (auto-sequence, bounded retry, warn, ask; see context/patterns/task-lock.md's "Four-Tier
# Conflict Response" section):
#
#   - Tier 2 (bounded retry) resolving: a foreign holder's lock released partway through the
#     retry window falls through to a clean acquire, exactly one NOTE: line, no ABORT text.
#   - Tier 3 (warn) exhaustion: a foreign holder kept fresh for the whole retry budget falls
#     through to the SAME ABORT text plain `acquire` would emit for the identical fixture, byte-
#     identical, for all three ABORT variants (own-project holder, cross-project file_scope
#     overlap against a held lock, cross-project overlap against a live registered session).
#   - Same-session re-entry: acquire-retry invoked with the holder's own session_id returns 0
#     immediately, zero NOTE: lines, elapsed wall clock far below one poll interval -- i.e. the
#     retry loop body is never entered.
#   - Budget-bound: the exhaustion case's elapsed wall clock stays close to
#     TASK_LOCK_RETRY_BUDGET_MS, never anywhere near a minutes-scale wait, using a lowered
#     override to keep the suite fast.
#
# Tier 1 (auto-sequence) and the non-convergence-terminates-partial proof are added in this same
# file by a later phase (see context/patterns/task-lock.md and this plan's own phase sequence);
# this revision covers Tier 2/Tier 3 only.
#
# Modeled directly on test-conflict-predicate.sh's, test-session-registry.sh's, and
# test-task-lock-reap.sh's isolated-temp-root precedent: throwaway $TMPROOT/.claude/scripts/
# satisfying deploy-root-guard.sh's two-levels-under-root check, real scripts copied byte-for-
# byte, fixture state.json / .sessions/ / .lock/ at controlled epoch timestamps (no sleeping
# except the deliberate, bounded backgrounded-release case below), pass/fail/info helpers,
# cleanup trap. No testability hooks are added to production code anywhere in this suite.
#
# Never touches the real specs/ tree.
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
for req in task-lock.sh deploy-root-guard.sh lib/file-scope-overlap.sh orchestrate-batch-admit.sh; do
  if [ ! -f "$SCRIPT_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/four-tier-conflict-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/file-scope-overlap.sh" "$TMPROOT/.claude/scripts/lib/file-scope-overlap.sh"
cp "$SCRIPT_DIR/orchestrate-batch-admit.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh" "$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"
BA="$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh"
SESSIONS_DIR="$TMPROOT/specs/.sessions"
STATE_FILE="$TMPROOT/specs/state.json"

# --- Timestamp helpers (no sleeping for fixture setup -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

# write_holder_fixture <lock_dir> <session_id> <project_number> <heartbeat_minutes_ago>
write_holder_fixture() {
  local lock_dir="$1" session_id="$2" project_number="$3" mins_ago="$4"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$lock_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$project_number" \
    --arg operation "implement" \
    --arg acquired_at "$ts" \
    --arg heartbeat_at "$ts" \
    --arg command "/test fixture" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $acquired_at, heartbeat_at: $heartbeat_at, command: $command}' \
    > "$lock_dir/holder.json"
}

# write_session_fixture <session_id> <pid> <covered_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
write_session_fixture() {
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

# Find a definitely-dead pid for fixtures that must NEVER be mistaken for a live process.
DEAD_PID=999999
while kill -0 "$DEAD_PID" 2>/dev/null; do
  DEAD_PID=$(( DEAD_PID - 1 ))
done

# --- Fixture state.json: each group gets its own isolated project + file_scope namespace so no
# group's fixtures accidentally collide with another's. ---
cat > "$STATE_FILE" << EOF
{
  "next_project_number": 1000,
  "active_projects": [
    {"project_number": 501, "project_name": "case_a_resolving", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 502, "project_name": "case_b_exhaustion", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 503, "project_name": "case_c_candidate", "status": "not_started", "task_type": "general", "file_scope": ["case_c/shared.sh"], "dependencies": []},
    {"project_number": 504, "project_name": "case_c_held", "status": "implementing", "task_type": "general", "file_scope": ["case_c/shared.sh"], "dependencies": []},
    {"project_number": 505, "project_name": "case_d_candidate", "status": "not_started", "task_type": "general", "file_scope": ["case_d/shared.sh"], "dependencies": []},
    {"project_number": 506, "project_name": "case_e_reentry", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []},
    {"project_number": 507, "project_name": "case_f_budget", "status": "implementing", "task_type": "general", "file_scope": [], "dependencies": []}
  ]
}
EOF

mkdir -p "$TMPROOT/specs/501_case_a_resolving" "$TMPROOT/specs/502_case_b_exhaustion" \
         "$TMPROOT/specs/503_case_c_candidate" "$TMPROOT/specs/504_case_c_held" \
         "$TMPROOT/specs/505_case_d_candidate" "$TMPROOT/specs/506_case_e_reentry" \
         "$TMPROOT/specs/507_case_f_budget"

info "Fixture built at $TMPROOT (dead pid probe resolved to $DEAD_PID)"

# =============================================================================
# Case 1 (Tier 2, resolving): a foreign holder's lock released partway through the retry
# window by a backgrounded helper.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/501_case_a_resolving/.lock" "sess_case_a_holder" 501 0

(
  sleep 0.3
  rm -rf "$TMPROOT/specs/501_case_a_resolving/.lock"
) &
RELEASER_PID=$!

t0=$(date +%s%N)
out1=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=100 "$TL" acquire-retry 501 implement sess_case_a_waiter 2>&1)
rc1=$?
t1=$(date +%s%N)
wait "$RELEASER_PID" 2>/dev/null || true

note_count1=$(grep -c '^NOTE:' <<<"$out1")
abort_count1=$(grep -c '^ABORT:' <<<"$out1")

if [ "$rc1" -eq 0 ] && [ "$note_count1" -eq 1 ] && [ "$abort_count1" -eq 0 ]; then
  pass "1: Tier-2 resolving -- foreign lock released mid-window, acquire-retry returns 0, exactly one NOTE:, no ABORT text (elapsed $(( (t1 - t0) / 1000000 ))ms)"
else
  fail "1: Tier-2 resolving case -- rc=$rc1 note_count=$note_count1 abort_count=$abort_count1 output=[$out1]"
fi

# =============================================================================
# Case 2 (Tier 3, exhaustion, own-project variant): foreign holder's heartbeat kept fresh for
# the whole retry window. Assert the emitted (post-NOTE) text is byte-identical to plain
# `acquire`'s output for the same fixture.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/502_case_b_exhaustion/.lock" "sess_case_b_holder" 502 0

expected2=$("$TL" acquire 502 implement sess_case_b_waiter 2>&1)
rc_expected2=$?

t0=$(date +%s%N)
out2=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 502 implement sess_case_b_waiter 2>&1)
rc2=$?
t1=$(date +%s%N)
elapsed2_ms=$(( (t1 - t0) / 1000000 ))

# Strip the single leading NOTE: line from acquire-retry's output before comparing.
actual2=$(grep -v '^NOTE:' <<<"$out2")

if [ "$rc_expected2" -eq 1 ] && [ "$rc2" -eq 1 ] && [ "$actual2" = "$expected2" ]; then
  pass "2: Tier-3 exhaustion (own-project variant) -- acquire-retry returns 1 with ABORT text byte-identical to plain acquire's output for the same fixture"
else
  fail "2: Tier-3 exhaustion (own-project variant) -- rc_expected=$rc_expected2 rc2=$rc2 expected=[$expected2] actual=[$actual2]"
fi

# =============================================================================
# Case 3 (Tier 3, field preservation, cross-project file_scope overlap against a HELD lock):
# candidate project 503 overlaps held project 504 via case_c/shared.sh.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/504_case_c_held/.lock" "sess_case_c_holder" 504 0

expected3=$("$TL" acquire 503 implement sess_case_c_waiter 2>&1)
rc_expected3=$?

out3=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 503 implement sess_case_c_waiter 2>&1)
rc3=$?
actual3=$(grep -v '^NOTE:' <<<"$out3")

if [ "$rc_expected3" -eq 1 ] && [ "$rc3" -eq 1 ] && [ "$actual3" = "$expected3" ] && [ -n "$actual3" ]; then
  pass "3: Tier-3 field preservation -- cross-project file_scope overlap against a held lock, ABORT text byte-identical to plain acquire's, all fields intact"
else
  fail "3: Tier-3 field preservation (held-lock overlap) -- rc_expected=$rc_expected3 rc3=$rc3 expected=[$expected3] actual=[$actual3]"
fi

# =============================================================================
# Case 4 (Tier 3, field preservation, cross-project overlap against a LIVE REGISTERED SESSION):
# candidate project 505 overlaps a live registered session's file_scope via case_d/shared.sh.
# The registered session covers an unrelated project number (kept far outside this suite's own
# fixture range) so the hit comes only from the session-registry contention pass, never the
# held-lock scan.
# =============================================================================
# A live pid is required for the session_contention() liveness check to treat this entry as
# live; DEAD_PID would be excluded as a dead-pid hit. Use this suite's own PID (definitely
# alive for the duration of the test).
write_session_fixture "sess_case_d_registered" "$$" '[8899]' '["case_d/shared.sh"]' 0

expected4=$("$TL" acquire 505 implement sess_case_d_waiter 2>&1)
rc_expected4=$?

out4=$(TASK_LOCK_RETRY_BUDGET_MS=800 TASK_LOCK_RETRY_POLL_MS=200 "$TL" acquire-retry 505 implement sess_case_d_waiter 2>&1)
rc4=$?
actual4=$(grep -v '^NOTE:' <<<"$out4")

if [ "$rc_expected4" -eq 1 ] && [ "$rc4" -eq 1 ] && [ "$actual4" = "$expected4" ] && grep -q "registered session sess_case_d_registered" <<<"$actual4"; then
  pass "4: Tier-3 field preservation -- cross-project overlap against a live registered session, ABORT text byte-identical to plain acquire's, all fields intact"
else
  fail "4: Tier-3 field preservation (registered-session overlap) -- rc_expected=$rc_expected4 rc4=$rc4 expected=[$expected4] actual=[$actual4]"
fi

# =============================================================================
# Case 5 (same-session re-entry): acquire-retry invoked with the holder's own session_id.
# Assert return 0, zero NOTE: lines, and elapsed wall-clock well below the poll interval --
# i.e. the retry loop body was never entered (a single cmd_acquire fast-path return).
# =============================================================================
write_holder_fixture "$TMPROOT/specs/506_case_e_reentry/.lock" "sess_case_e_self" 506 0

t0=$(date +%s%N)
out5=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=1000 "$TL" acquire-retry 506 implement sess_case_e_self 2>&1)
rc5=$?
t1=$(date +%s%N)
elapsed5_ms=$(( (t1 - t0) / 1000000 ))
note_count5=$(grep -c '^NOTE:' <<<"$out5")

# The poll interval is 1000ms; the retry loop being entered even once would push elapsed past
# that. A generous 500ms ceiling proves the loop body never ran (single fast cmd_acquire call).
if [ "$rc5" -eq 0 ] && [ "$note_count5" -eq 0 ] && [ "$elapsed5_ms" -lt 500 ]; then
  pass "5: same-session re-entry -- acquire-retry returns 0, zero NOTE: lines, elapsed ${elapsed5_ms}ms (< 500ms poll-interval ceiling), retry loop never entered"
else
  fail "5: same-session re-entry -- rc=$rc5 note_count=$note_count5 elapsed_ms=$elapsed5_ms output=[$out5]"
fi

# =============================================================================
# Case 6 (budget-bound): the exhaustion case's elapsed wall clock stays close to
# TASK_LOCK_RETRY_BUDGET_MS, never anywhere near a minutes-scale wait. Uses a lowered override
# to keep the suite fast.
# =============================================================================
write_holder_fixture "$TMPROOT/specs/507_case_f_budget/.lock" "sess_case_f_holder" 507 0

BUDGET_MS=1000
t0=$(date +%s%N)
out6=$(TASK_LOCK_RETRY_BUDGET_MS=$BUDGET_MS TASK_LOCK_RETRY_POLL_MS=100 "$TL" acquire-retry 507 implement sess_case_f_waiter 2>&1)
rc6=$?
t1=$(date +%s%N)
elapsed6_ms=$(( (t1 - t0) / 1000000 ))

# Tolerance: at least the budget (the loop only checks the bound at the top of each iteration,
# so it can slightly overshoot by up to one poll interval), and well under 2x the budget --
# nowhere near TASK_LOCK_STALE_MIN's minutes-scale window.
if [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]; then
  pass "6: budget-bound -- exhaustion elapsed ${elapsed6_ms}ms within [${BUDGET_MS}ms, $(( BUDGET_MS * 2 ))ms), nowhere near a minutes-scale wait"
else
  fail "6: budget-bound -- rc=$rc6 elapsed_ms=$elapsed6_ms budget_ms=$BUDGET_MS"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
