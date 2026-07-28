#!/usr/bin/env bash
# test-state-write-concurrency.sh - Isolated-temp-root suite proving state-write.sh's two
# load-bearing safety properties (no lost update, staging-file isolation) plus its fail-closed
# acquire and guest-mode reentrancy contracts.
#
# Never touches the real specs/ tree. Follows test-task-lock-reap.sh's isolated-temp-root
# precedent exactly: build a throwaway $TMPROOT, copy state-write.sh, task-lock.sh,
# generate-todo.sh, and deploy-root-guard.sh byte-for-byte into $TMPROOT/.claude/scripts/, and
# fixture a minimal $TMPROOT/specs/state.json with at least two project entries. No testability
# hooks are added to production code -- every script under test is copied unmodified and never
# learns it is under test.
#
# Interleaving is controlled through the fixture's OWN transform cost (a deliberately heavy jq
# `range` computation), never through a blind wall-clock `sleep` used to fake correctness timing
# -- consistent with the precedent suite's no-sleeping convention. Where this suite polls for a
# condition (e.g. waiting for a background process's staging file to appear), it polls a real
# predicate on a bounded budget, which is a different thing from sleeping to fake an ordering.
#
# Exit 0 when all four cases PASS, exit 1 when any case FAILS.

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

# --- Locate the real scripts to copy into the fixture ---
for f in state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "ERROR: expected $f alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-write-concurrency-test.XXXXXX")"

cleanup_root() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup_root EXIT

mkdir -p "$TMPROOT/.claude/scripts"
mkdir -p "$TMPROOT/specs"
cp "$SCRIPT_DIR/state-write.sh" "$TMPROOT/.claude/scripts/state-write.sh"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/generate-todo.sh" "$TMPROOT/.claude/scripts/generate-todo.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
chmod +x "$TMPROOT/.claude/scripts/"*.sh

SW="$TMPROOT/.claude/scripts/state-write.sh"
TL="$TMPROOT/.claude/scripts/task-lock.sh"
STATE_FILE="$TMPROOT/specs/state.json"

reset_state_json() {
  cat > "$STATE_FILE" << 'EOF'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "case_a", "status": "implementing", "counter": 0},
    {"project_number": 2, "project_name": "case_b", "status": "implementing", "counter": 0}
  ]
}
EOF
}

reset_state_json
info "Fixture built at $TMPROOT"

# =====================================================================
# Case 1: no lost update -- two concurrent writers targeting DIFFERENT project entries
# =====================================================================
# The first writer's filter is deliberately heavy (a large `range` computation) so it holds the
# specs/.scope-lock mutex for a real, measurable window. The second writer is launched
# concurrently and must genuinely wait for the first to release before it can acquire -- proving
# serialization rather than lucky non-overlap. Both mutate DIFFERENT project entries; both must
# land.
(
  cd "$TMPROOT"
  "$SW" '([range(0;20000000)] | length) as $burn | (.active_projects[] | select(.project_number == 1)) |= . + {counter: 1, marker_first: "written"}' \
    --session-id "sess_case1_first" > "$TMPROOT/case1_first.out" 2>&1
  echo $? > "$TMPROOT/case1_first.exit"
) &
PID_FIRST=$!

(
  cd "$TMPROOT"
  "$SW" '(.active_projects[] | select(.project_number == 2)) |= . + {counter: 1, marker_second: "written"}' \
    --session-id "sess_case1_second" > "$TMPROOT/case1_second.out" 2>&1
  echo $? > "$TMPROOT/case1_second.exit"
) &
PID_SECOND=$!

wait "$PID_FIRST"
wait "$PID_SECOND"

case1_first_exit=$(cat "$TMPROOT/case1_first.exit" 2>/dev/null || echo "?")
case1_second_exit=$(cat "$TMPROOT/case1_second.exit" 2>/dev/null || echo "?")

c1_ok=true
[ "$case1_first_exit" = "0" ] || { c1_ok=false; info "case1 first writer exited $case1_first_exit: $(cat "$TMPROOT/case1_first.out" 2>/dev/null)"; }
[ "$case1_second_exit" = "0" ] || { c1_ok=false; info "case1 second writer exited $case1_second_exit: $(cat "$TMPROOT/case1_second.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 1) | .marker_first == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "project 1's mutation (marker_first) missing from final state.json"; }
jq -e '.active_projects[] | select(.project_number == 2) | .marker_second == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "project 2's mutation (marker_second) missing from final state.json"; }
jq empty "$STATE_FILE" >/dev/null 2>&1 || { c1_ok=false; info "final state.json failed jq empty validation"; }

if [ "$c1_ok" = true ]; then
  pass "1: no lost update -- two concurrent mutex-serialized writers to different project entries both land"
else
  fail "1: no-lost-update case failed (see INFO lines above)"
fi

# =====================================================================
# Case 2: staging-file isolation -- one process fails mid-write (fires its own EXIT trap)
# concurrently with a second, successful mid-write process; the second's temp file/write must be
# untouched by the first's cleanup.
# =====================================================================
reset_state_json
rm -f "$TMPROOT/specs/tmp/"state-write.* 2>/dev/null || true

# Both run as guests (SCOPE_MUTEX_HELD=1 exported to the whole subshell tree) so neither blocks
# on the mutex -- this is what makes the two invocations genuinely concurrent at the OS level
# rather than serialized one-after-another, which is what this case needs to exercise: real
# simultaneous mktemp'd staging files under specs/tmp/, proving each process's EXIT trap only
# ever touches its OWN staging path.
export SCOPE_MUTEX_HELD=1

(
  cd "$TMPROOT"
  # Deliberately heavy AND doomed to fail: burns real wall time via `range`, then a guaranteed
  # jq runtime error (tonumber on a non-numeric string) so the process stages, holds its temp
  # file for a real window, then fails and self-cleans via its own EXIT trap.
  "$SW" '([range(0;20000000)] | length) as $burn | ("not-a-number" | tonumber)' \
    --session-id "sess_case2_fail" > "$TMPROOT/case2_fail.out" 2>&1
  echo $? > "$TMPROOT/case2_fail.exit"
) &
PID_FAIL=$!

# Poll (bounded, real-predicate) for the failing process's staging file to appear, so case 2's
# concurrent process is launched once we know a staging file genuinely exists -- not a blind
# sleep, a wait-for-condition with a timeout.
max_seen=0
for _ in $(seq 1 100); do
  n=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
  [ "$n" -gt "$max_seen" ] && max_seen="$n"
  [ "$n" -ge 1 ] && break
  sleep 0.01
done

(
  cd "$TMPROOT"
  "$SW" '(.active_projects[] | select(.project_number == 2)) |= . + {counter: 1, marker_second: "written"}' \
    --session-id "sess_case2_ok" > "$TMPROOT/case2_ok.out" 2>&1
  echo $? > "$TMPROOT/case2_ok.exit"
) &
PID_OK=$!

# Sample staging-dir file count a few more times while both may be in flight (real-predicate
# polling, not a correctness-bearing sleep) to record evidence of genuine overlap.
for _ in $(seq 1 50); do
  n=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
  [ "$n" -gt "$max_seen" ] && max_seen="$n"
  kill -0 "$PID_FAIL" 2>/dev/null || break
done

wait "$PID_FAIL"
wait "$PID_OK"
unset SCOPE_MUTEX_HELD

case2_fail_exit=$(cat "$TMPROOT/case2_fail.exit" 2>/dev/null || echo "?")
case2_ok_exit=$(cat "$TMPROOT/case2_ok.exit" 2>/dev/null || echo "?")

c2_ok=true
[ "$case2_fail_exit" = "3" ] || { c2_ok=false; info "case2 doomed writer exited $case2_fail_exit (expected 3): $(cat "$TMPROOT/case2_fail.out" 2>/dev/null)"; }
[ "$case2_ok_exit" = "0" ] || { c2_ok=false; info "case2 successful writer exited $case2_ok_exit (expected 0): $(cat "$TMPROOT/case2_ok.out" 2>/dev/null)"; }
jq -e '.active_projects[] | select(.project_number == 2) | .marker_second == "written"' "$STATE_FILE" >/dev/null 2>&1 || { c2_ok=false; info "successful writer's mutation missing -- may indicate cross-deletion of its staging file"; }
leftover=$(ls "$TMPROOT/specs/tmp/" 2>/dev/null | grep -c '^state-write\.' || true)
[ "$leftover" -eq 0 ] || { c2_ok=false; info "specs/tmp/ still has $leftover leftover state-write.* staging file(s) after both processes exited"; }
[ "$max_seen" -ge 1 ] || { c2_ok=false; info "never observed a state-write.* staging file at all (fixture failed to exercise staging)"; }

if [ "$c2_ok" = true ]; then
  pass "2: staging-file isolation -- a failing process's own-scoped EXIT trap never touches a concurrent successful process's staging file (max concurrent staging files observed: $max_seen)"
else
  fail "2: staging-file isolation case failed (see INFO lines above)"
fi

# =====================================================================
# Case 3: fail-closed acquire -- specs/.scope-lock pre-claimed and fresh; a non-guest
# state-write.sh invocation must exit non-zero with an ABORT-prefixed message rather than
# proceeding unserialized, and must leave specs/state.json untouched.
# =====================================================================
reset_state_json
mkdir -p "$TMPROOT/specs/.scope-lock"
date -u +%s > "$TMPROOT/specs/.scope-lock/claimed_at"
echo 60 > "$TMPROOT/specs/.scope-lock/stale_sec"
jq -n --arg sid "sess_outer_holder" '{session_id: $sid, pid: 999999, claimed_epoch: 0, token: "sess_outer_holder:999999:0"}' \
  > "$TMPROOT/specs/.scope-lock/owner"

before_hash=$(jq -S . "$STATE_FILE")

(
  cd "$TMPROOT"
  "$SW" '.active_projects[0].counter = 99' --session-id "sess_case3" > "$TMPROOT/case3.out" 2>&1
  echo $? > "$TMPROOT/case3.exit"
)

case3_exit=$(cat "$TMPROOT/case3.exit" 2>/dev/null || echo "?")
after_hash=$(jq -S . "$STATE_FILE")

c3_ok=true
[ "$case3_exit" = "2" ] || { c3_ok=false; info "case3 exited $case3_exit (expected 2)"; }
grep -q "^ABORT:" "$TMPROOT/case3.out" || { c3_ok=false; info "case3 stderr missing ABORT: prefix: $(cat "$TMPROOT/case3.out" 2>/dev/null)"; }
[ "$before_hash" = "$after_hash" ] || { c3_ok=false; info "case3 specs/state.json was modified despite fail-closed acquire refusal"; }

if [ "$c3_ok" = true ]; then
  pass "3: fail-closed acquire -- pre-claimed fresh specs/.scope-lock refuses with ABORT: and leaves state.json untouched"
else
  fail "3: fail-closed acquire case failed (see INFO lines above)"
fi

rm -rf "$TMPROOT/specs/.scope-lock"

# =====================================================================
# Case 4: guest-mode reentrancy -- SCOPE_MUTEX_HELD=1 exported and the mutex already held by a
# simulated outer holder; state-write.sh must complete the write WITHOUT attempting a nested
# acquire (no ~5s acquire-budget stall) and WITHOUT releasing the outer holder's mutex.
# =====================================================================
reset_state_json
mkdir -p "$TMPROOT/specs/.scope-lock"
date -u +%s > "$TMPROOT/specs/.scope-lock/claimed_at"
echo 60 > "$TMPROOT/specs/.scope-lock/stale_sec"
jq -n --arg sid "sess_outer_holder" '{session_id: $sid, pid: 999999, claimed_epoch: 0, token: "sess_outer_holder:999999:0"}' \
  > "$TMPROOT/specs/.scope-lock/owner"
outer_owner_before=$(cat "$TMPROOT/specs/.scope-lock/owner")

start_epoch=$(date -u +%s)
(
  cd "$TMPROOT"
  SCOPE_MUTEX_HELD=1 "$SW" '.active_projects[0].counter = 42' --session-id "sess_case4_guest" > "$TMPROOT/case4.out" 2>&1
  echo $? > "$TMPROOT/case4.exit"
)
end_epoch=$(date -u +%s)
elapsed=$(( end_epoch - start_epoch ))

case4_exit=$(cat "$TMPROOT/case4.exit" 2>/dev/null || echo "?")
outer_owner_after=$(cat "$TMPROOT/specs/.scope-lock/owner" 2>/dev/null || echo "MISSING")

c4_ok=true
[ "$case4_exit" = "0" ] || { c4_ok=false; info "case4 guest-mode write exited $case4_exit (expected 0): $(cat "$TMPROOT/case4.out" 2>/dev/null)"; }
jq -e '.active_projects[0].counter == 42' "$STATE_FILE" >/dev/null 2>&1 || { c4_ok=false; info "case4 guest-mode write did not land"; }
[ "$elapsed" -lt 3 ] || { c4_ok=false; info "case4 took ${elapsed}s (>= 3s), suggesting a nested acquire was attempted against the pre-claimed mutex instead of running as a guest"; }
[ -d "$TMPROOT/specs/.scope-lock" ] || { c4_ok=false; info "case4 outer holder's specs/.scope-lock mutex was removed by the guest"; }
[ "$outer_owner_before" = "$outer_owner_after" ] || { c4_ok=false; info "case4 outer holder's owner file was modified by the guest"; }
grep -q "outer holder already owns" "$TMPROOT/case4.out" && info "case4 confirmed the guest-mode note fired" || { c4_ok=false; info "case4 missing the expected guest-mode stderr note"; }

if [ "$c4_ok" = true ]; then
  pass "4: guest-mode reentrancy -- SCOPE_MUTEX_HELD=1 skips nested acquire, completes the write, and never releases the outer holder's mutex (elapsed ${elapsed}s)"
else
  fail "4: guest-mode reentrancy case failed (see INFO lines above)"
fi

rm -rf "$TMPROOT/specs/.scope-lock"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
