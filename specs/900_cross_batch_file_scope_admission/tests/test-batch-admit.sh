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
# plan itself requires. Test 2 below asserts the behavior a correct implementation actually
# produces: 900 is not deferred BY 902 (proving the in-batch direction rule), but IS still
# correctly deferred by its separate, genuine cross-batch collision with 906. 902's line is
# exactly the plan's original prediction (defer, colliding_task_number 900, in_batch).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC_SCRIPT="$REPO_ROOT/agent-system/extensions/core/scripts/orchestrate-batch-admit.sh"
SRC_GUARD="$REPO_ROOT/agent-system/extensions/core/scripts/deploy-root-guard.sh"
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
  mkdir -p "$proj_dir/.claude/scripts" "$proj_dir/specs"
  cp "$SRC_SCRIPT" "$proj_dir/.claude/scripts/orchestrate-batch-admit.sh"
  cp "$SRC_GUARD" "$proj_dir/.claude/scripts/deploy-root-guard.sh"
  cp "$1" "$proj_dir/specs/state.json"
  echo "$proj_dir"
}

run_admit() {
  # $1 = proj_dir, remaining args = candidate task numbers
  local proj_dir="$1"
  shift
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-batch-admit.sh "$@")
}

FIXTURE_PROJ="$(new_scratch_deploy "$FIXTURE")"

# ============================================================
# 1. Cross-batch defer, exact line (candidate 900 alone)
# ============================================================
expected_1='{"$schema":"orchestrate-batch-admit-v1","task_number":900,"decision":"defer","colliding_task_number":902,"colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #902 (not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}'
actual_1="$(run_admit "$FIXTURE_PROJ" 900)"
if [ "$actual_1" = "$expected_1" ]; then
  pass "1. cross-batch defer exact line (candidate 900 alone)"
else
  fail "1. cross-batch defer exact line (candidate 900 alone): got: $actual_1"
fi

# ============================================================
# 2. In-batch defer preserves existing direction (candidates 900 902)
#    See file-header deviation note: 900's line reflects its genuine, independent
#    cross-batch collision with 906, not the plan's original "admit" prediction.
# ============================================================
expected_2_line1='{"$schema":"orchestrate-batch-admit-v1","task_number":900,"decision":"defer","colliding_task_number":906,"colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/skills/skill-orchestrate/SKILL.md","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #906 (not in this batch) at agent-system/extensions/core/skills/skill-orchestrate/SKILL.md; no dependencies[] edge between them"}'
expected_2_line2='{"$schema":"orchestrate-batch-admit-v1","task_number":902,"decision":"defer","colliding_task_number":900,"colliding_task_status":"implementing","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"in_batch","reason":"file_scope overlap with non-terminal task #900 (in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}'
actual_2="$(run_admit "$FIXTURE_PROJ" 900 902)"
actual_2_line1="$(printf '%s\n' "$actual_2" | sed -n '1p')"
actual_2_line2="$(printf '%s\n' "$actual_2" | sed -n '2p')"
if [ "$actual_2_line1" = "$expected_2_line1" ] && [ "$actual_2_line2" = "$expected_2_line2" ]; then
  pass "2. in-batch direction preserved (candidates 900 902): 900 not deferred by 902, 902 defers to 900"
else
  fail "2. in-batch direction (candidates 900 902): line1=$actual_2_line1 line2=$actual_2_line2"
fi

# ============================================================
# 3. Terminal tasks are excluded (candidate 992, whose only overlap is with terminal task 990)
# ============================================================
actual_3="$(run_admit "$FIXTURE_PROJ" 992)"
if [ "$actual_3" = '{"$schema":"orchestrate-batch-admit-v1","task_number":992,"decision":"admit"}' ]; then
  pass "3. terminal tasks excluded (candidate 992 admits despite overlap with completed task 990)"
else
  fail "3. terminal tasks excluded: got: $actual_3"
fi

# ============================================================
# 4. Edge-linked pairs are excluded (candidate 993, dependencies[] edge to 994)
# ============================================================
actual_4="$(run_admit "$FIXTURE_PROJ" 993)"
if [ "$actual_4" = '{"$schema":"orchestrate-batch-admit-v1","task_number":993,"decision":"admit"}' ]; then
  pass "4. edge-linked pairs excluded (candidate 993 admits despite overlap with dependencies[]-linked 994)"
else
  fail "4. edge-linked pairs excluded: got: $actual_4"
fi

# ============================================================
# 5. Trailing-slash directory prefix is detected (candidate 991, directory scope)
# ============================================================
actual_5="$(run_admit "$FIXTURE_PROJ" 991)"
expected_5='{"$schema":"orchestrate-batch-admit-v1","task_number":991,"decision":"defer","colliding_task_number":900,"colliding_task_status":"implementing","overlapping_path":"agent-system/extensions/core/context/patterns/file-footprint-overlap.md","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #900 (not in this batch) at agent-system/extensions/core/context/patterns/file-footprint-overlap.md; no dependencies[] edge between them"}'
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
  pass "7. exit codes (usage errors, missing state, and successful defer runs)"
else
  fail "7. exit codes"
fi

# ============================================================
# Live smoke check (labelled, exact-value-free by design)
# ============================================================
# Exact-value assertions live ONLY in the frozen fixture above, because live state.json mutates
# as tasks complete. This check asserts only the robust structural fact that a real cross-batch
# collision currently exists for task 900, and prints the full verdict line for human inspection.
echo ""
echo "=== LIVE SMOKE CHECK (against real specs/state.json) ==="
LIVE_PROJ="$(new_scratch_deploy "$REPO_ROOT/specs/state.json")"
live_out="$(run_admit "$LIVE_PROJ" 900)"
echo "Live verdict for candidate 900: $live_out"
live_decision=$(printf '%s\n' "$live_out" | jq -r '.decision')
live_scope=$(printf '%s\n' "$live_out" | jq -r '.collision_scope // empty')
if [ "$live_decision" = "defer" ] && [ "$live_scope" = "cross_batch" ]; then
  pass "live smoke: candidate 900 currently defers with collision_scope=cross_batch"
else
  fail "live smoke: expected decision=defer/collision_scope=cross_batch, got decision=$live_decision collision_scope=$live_scope"
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
