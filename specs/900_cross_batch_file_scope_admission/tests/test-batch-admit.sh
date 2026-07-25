#!/usr/bin/env bash
# test-batch-admit.sh — deterministic fixture regression suite for
# agent-system/extensions/core/scripts/orchestrate-batch-admit.sh.
#
# Builds a throwaway scratch deploy tree ($(mktemp -d)/proj/.claude/scripts/) so the script's
# own deploy-root-guard.sh is satisfied without ever touching this repository's real .claude/
# directory. The scratch tree is removed on exit via trap, success or failure.
#
# Deviation from the plan's original scenario-2 prediction (recorded here, not silently
# "fixed away"): the plan predicted candidates `900 902` would emit `900: admit, 902: defer`.
# Because the fixture is required to copy tasks 900, 902, 906, and 907 verbatim from live
# specs/state.json, and 900 and 906 have a genuine, independent file_scope overlap
# (agent-system/extensions/core/skills/skill-orchestrate/SKILL.md) with no dependencies[] edge
# between them, a correct implementation of the cross-batch predicate does NOT admit 900 in that
# scenario — 906 is a real, out-of-batch collision that exists in the same verbatim data set the
# plan itself requires.
#
# SECOND DEVIATION, added when this suite was updated for the v2 schema (self-modification hazard
# gate): tasks 900, 902, 906, and 907 are all REAL tasks whose file_scope legitimately names
# orchestrator-critical machinery (they are literally about the orchestrator admission/dispatch
# system), so under the v2 self-modification check they are now flagged `self_modifying: true`.
# Per D4 (self-modification precedence, checked FIRST and short-circuiting the collision scan
# entirely), this changes the ACTUAL, CORRECT behavior of tests 1 and 2 below:
#   - Test 1 (candidate 900 alone, default --invocation-count of 1): 900 no longer defers via its
#     real cross-batch collision with 902/906 at all — it is a solo invocation, so the
#     self-modifying candidate is ADMITTED, with `self_modifying: true` still visible. The
#     collision with 902/906 is real and still exists in the fixture data, but self-modification
#     precedence means it is never reached or reported for a self-modifying candidate.
#   - Test 2 (candidates 900 902 together, default --invocation-count of 2): BOTH candidates are
#     self-modifying, so BOTH now defer with `defer_reason: "self_modifying"` — the previously
#     asserted `file_scope_collision`/`in_batch` in-batch-direction behavior for this specific
#     pair no longer surfaces (self-modification precedence reaches both candidates first, and
#     neither one's collision fields are computed at all).
# This is not a bug: it is the new, intended precedence rule (D4) operating correctly on real
# data that happens to independently satisfy the self-modification predicate. The in-batch
# collision-direction rule itself is UNCHANGED code and remains under test — see test 13 in
# specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh, which exercises the
# identical direction rule using two synthetic, deliberately NON-self-modifying candidates,
# preserving coverage that this suite's tests 1/2 no longer provide for real orchestrator-related
# fixture data.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC_SCRIPT="$REPO_ROOT/agent-system/extensions/core/scripts/orchestrate-batch-admit.sh"
SRC_GUARD="$REPO_ROOT/agent-system/extensions/core/scripts/deploy-root-guard.sh"
SRC_CRITICAL="$REPO_ROOT/agent-system/extensions/core/context/reference/orchestrator-critical-paths.json"
FIXTURE="$SCRIPT_DIR/../fixtures/state-cross-batch.json"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# --- scratch deploy tree(s); MUST NOT write into the repository's real .claude/ ---
SCRATCH_ROOTS=()
cleanup() {
  for r in "${SCRATCH_ROOTS[@]:-}"; do
    [ -n "$r" ] && rm -rf "$r"
  done
}
trap cleanup EXIT

new_scratch_deploy() {
  # $1 = path to a specs/state.json to seed the scratch root with
  local root proj_dir
  root="$(mktemp -d)"
  SCRATCH_ROOTS+=("$root")
  proj_dir="$root/proj"
  mkdir -p "$proj_dir/.claude/scripts" "$proj_dir/.claude/context/reference" "$proj_dir/specs"
  cp "$SRC_SCRIPT" "$proj_dir/.claude/scripts/orchestrate-batch-admit.sh"
  cp "$SRC_GUARD" "$proj_dir/.claude/scripts/deploy-root-guard.sh"
  cp "$SRC_CRITICAL" "$proj_dir/.claude/context/reference/orchestrator-critical-paths.json"
  cp "$1" "$proj_dir/specs/state.json"
  echo "$proj_dir"
}

run_admit() {
  # $1 = proj_dir, remaining args = admit.sh args (flags + candidate task numbers)
  local proj_dir="$1"
  shift
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-batch-admit.sh "$@")
}

FIXTURE_PROJ="$(new_scratch_deploy "$FIXTURE")"

# ============================================================
# 1. Candidate 900 alone (default --invocation-count = 1): self-modification precedence (D4)
#    means it is ADMITTED solo, self_modifying=true, DESPITE a real cross-batch collision with
#    902/906 that exists in this same fixture data (see file-header second deviation note).
# ============================================================
expected_1='{"$schema":"orchestrate-batch-admit-v2","task_number":900,"decision":"admit","self_modifying":true}'
actual_1="$(run_admit "$FIXTURE_PROJ" 900)"
if [ "$actual_1" = "$expected_1" ]; then
  pass "1. candidate 900 alone admits solo (self_modifying=true; precedence over its real cross-batch collision)"
else
  fail "1. candidate 900 alone: got: $actual_1"
fi

# ============================================================
# 2. Candidates 900 902 together (default --invocation-count = 2): BOTH are self-modifying, so
#    BOTH defer via defer_reason=self_modifying — the file-scope collision scan (and hence the
#    in-batch direction rule) is never reached for either (see file-header second deviation
#    note; the direction rule itself remains under test via test 13 in
#    specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh).
# ============================================================
expected_2_line1='{"$schema":"orchestrate-batch-admit-v2","task_number":900,"decision":"defer","self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","critical_label":"admission predicate","reason":"candidate #900 file_scope names orchestrator-critical path \"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh\" (admission predicate); deferred out of this invocation because orchestrator-critical work runs solo only — re-run task #900 alone"}'
expected_2_line2='{"$schema":"orchestrate-batch-admit-v2","task_number":902,"decision":"defer","self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","critical_label":"admission predicate","reason":"candidate #902 file_scope names orchestrator-critical path \"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh\" (admission predicate); deferred out of this invocation because orchestrator-critical work runs solo only — re-run task #902 alone"}'
actual_2="$(run_admit "$FIXTURE_PROJ" 900 902)"
actual_2_line1="$(printf '%s\n' "$actual_2" | sed -n '1p')"
actual_2_line2="$(printf '%s\n' "$actual_2" | sed -n '2p')"
if [ "$actual_2_line1" = "$expected_2_line1" ] && [ "$actual_2_line2" = "$expected_2_line2" ]; then
  pass "2. candidates 900 902 together: both defer via self_modifying (real orchestrator-critical file_scope on both)"
else
  fail "2. candidates 900 902 together: line1=$actual_2_line1 line2=$actual_2_line2"
fi

# ============================================================
# 3. Terminal tasks are excluded (candidate 992, whose only overlap is with terminal task 990).
#    992's file_scope names no critical path, so self_modifying=false (unaffected by the gate).
# ============================================================
actual_3="$(run_admit "$FIXTURE_PROJ" 992)"
if [ "$actual_3" = '{"$schema":"orchestrate-batch-admit-v2","task_number":992,"decision":"admit","self_modifying":false}' ]; then
  pass "3. terminal tasks excluded (candidate 992 admits despite overlap with completed task 990)"
else
  fail "3. terminal tasks excluded: got: $actual_3"
fi

# ============================================================
# 4. Edge-linked pairs are excluded (candidate 993, dependencies[] edge to 994). 993's file_scope
#    names no critical path, so self_modifying=false (unaffected by the gate).
# ============================================================
actual_4="$(run_admit "$FIXTURE_PROJ" 993)"
if [ "$actual_4" = '{"$schema":"orchestrate-batch-admit-v2","task_number":993,"decision":"admit","self_modifying":false}' ]; then
  pass "4. edge-linked pairs excluded (candidate 993 admits despite overlap with dependencies[]-linked 994)"
else
  fail "4. edge-linked pairs excluded: got: $actual_4"
fi

# ============================================================
# 5. Trailing-slash directory prefix is detected (candidate 991, directory scope). 991's
#    directory (context/patterns/) contains no critical path, so self_modifying=false and the
#    ordinary collision scan against 900 still runs and still defers, unaffected by the gate.
# ============================================================
actual_5="$(run_admit "$FIXTURE_PROJ" 991)"
expected_5='{"$schema":"orchestrate-batch-admit-v2","task_number":991,"decision":"defer","self_modifying":false,"defer_reason":"file_scope_collision","colliding_task_number":900,"colliding_task_status":"implementing","overlapping_path":"agent-system/extensions/core/context/patterns/file-footprint-overlap.md","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #900 (not in this batch) at agent-system/extensions/core/context/patterns/file-footprint-overlap.md; no dependencies[] edge between them"}'
if [ "$actual_5" = "$expected_5" ]; then
  pass "5. trailing-slash directory prefix detected (candidate 991 defers against 900's contained file)"
else
  fail "5. trailing-slash directory prefix: got: $actual_5"
fi

# ============================================================
# 6. Well-formedness: line counts, valid JSON, task_number order
# ============================================================
wf_ok=true

# 900 alone -> 1 line
n=$(printf '%s\n' "$actual_1" | grep -c .)
[ "$n" -eq 1 ] || { wf_ok=false; echo "  well-formedness: expected 1 line for candidate 900, got $n"; }

# 900 902 -> 2 lines, in input order
n=$(printf '%s\n' "$actual_2" | grep -c .)
[ "$n" -eq 2 ] || { wf_ok=false; echo "  well-formedness: expected 2 lines for candidates 900 902, got $n"; }
tn1=$(printf '%s\n' "$actual_2_line1" | jq -r '.task_number')
tn2=$(printf '%s\n' "$actual_2_line2" | jq -r '.task_number')
[ "$tn1" = "900" ] && [ "$tn2" = "902" ] || { wf_ok=false; echo "  well-formedness: expected task_number order 900,902; got $tn1,$tn2"; }

# every emitted line parses as JSON
for line in "$actual_1" "$actual_2_line1" "$actual_2_line2" "$actual_3" "$actual_4" "$actual_5"; do
  if ! jq -e . >/dev/null 2>&1 <<< "$line"; then
    wf_ok=false
    echo "  well-formedness: line does not parse as JSON: $line"
  fi
done

if [ "$wf_ok" = true ]; then
  pass "6. well-formedness (line counts, valid JSON, input-order task_number)"
else
  fail "6. well-formedness"
fi

# ============================================================
# 7. Exit codes
# ============================================================
ec_ok=true

out=$(run_admit "$FIXTURE_PROJ" 2>/dev/null)
ec=$?
[ "$ec" -eq 2 ] && [ -z "$out" ] || { ec_ok=false; echo "  exit codes: no-args expected exit 2 / empty stdout, got exit=$ec stdout=[$out]"; }

out=$(run_admit "$FIXTURE_PROJ" not_an_integer 2>/dev/null)
ec=$?
[ "$ec" -eq 2 ] || { ec_ok=false; echo "  exit codes: non-integer arg expected exit 2, got exit=$ec"; }

out=$(run_admit "$FIXTURE_PROJ" --invocation-count not_an_integer 900 2>/dev/null)
ec=$?
[ "$ec" -eq 2 ] || { ec_ok=false; echo "  exit codes: non-integer --invocation-count expected exit 2, got exit=$ec"; }

NO_STATE_ROOT="$(mktemp -d)"
SCRATCH_ROOTS+=("$NO_STATE_ROOT")
mkdir -p "$NO_STATE_ROOT/proj/.claude/scripts" "$NO_STATE_ROOT/proj/specs"
cp "$SRC_SCRIPT" "$NO_STATE_ROOT/proj/.claude/scripts/orchestrate-batch-admit.sh"
cp "$SRC_GUARD" "$NO_STATE_ROOT/proj/.claude/scripts/deploy-root-guard.sh"
out=$(cd "$NO_STATE_ROOT/proj" && bash .claude/scripts/orchestrate-batch-admit.sh 900 2>/tmp/batch-admit-stderr.$$)
ec=$?
err_size=$(wc -c < /tmp/batch-admit-stderr.$$)
rm -f "/tmp/batch-admit-stderr.$$"
[ "$ec" -eq 2 ] && [ -z "$out" ] && [ "$err_size" -gt 0 ] || { ec_ok=false; echo "  exit codes: missing state.json expected exit 2 / empty stdout / non-empty stderr, got exit=$ec stdout=[$out] stderr_size=$err_size"; }

out=$(run_admit "$FIXTURE_PROJ" 900 2>/dev/null)
ec=$?
[ "$ec" -eq 0 ] || { ec_ok=false; echo "  exit codes: a run producing defers expected exit 0, got exit=$ec"; }

if [ "$ec_ok" = true ]; then
  pass "7. exit codes (usage errors incl. --invocation-count, missing state, and successful runs)"
else
  fail "7. exit codes"
fi

# ============================================================
# Live smoke check (schema/shape-only, exact-value-free by design)
# ============================================================
# Exact-value assertions live ONLY in the frozen fixture above, because live state.json mutates
# as tasks complete. This section was UPDATED when the v2 schema landed: the original assertion
# pinned candidate 900 to decision=defer/collision_scope=cross_batch, but task 900 itself has
# since reached "completed" status in the real specs/state.json (independent of this gate — pure
# timing drift, the same class of staleness the file's own comment already warned about). Rather
# than re-pin a new specific expectation that will drift again, this check now asserts only the
# robust, version-independent structural facts that hold regardless of live data drift: the
# verdict is valid v2-schema NDJSON, self_modifying is present and boolean-or-null, and decision
# is one of the two valid values.
echo ""
echo "=== LIVE SMOKE CHECK (against real specs/state.json) ==="
LIVE_PROJ="$(new_scratch_deploy "$REPO_ROOT/specs/state.json")"
live_out="$(run_admit "$LIVE_PROJ" 900)"
echo "Live verdict for candidate 900: $live_out"
live_schema=$(printf '%s\n' "$live_out" | jq -r '."$schema" // empty')
live_decision=$(printf '%s\n' "$live_out" | jq -r '.decision // empty')
live_self_mod=$(printf '%s\n' "$live_out" | jq -c '.self_modifying')
if [ "$live_schema" = "orchestrate-batch-admit-v2" ] && \
   { [ "$live_decision" = "admit" ] || [ "$live_decision" = "defer" ]; } && \
   { [ "$live_self_mod" = "true" ] || [ "$live_self_mod" = "false" ] || [ "$live_self_mod" = "null" ]; }; then
  pass "live smoke: candidate 900 verdict is well-formed v2 NDJSON (schema/decision/self_modifying shape only, values not pinned)"
else
  fail "live smoke: malformed verdict shape: schema=$live_schema decision=$live_decision self_modifying=$live_self_mod"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== SUMMARY: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
