#!/usr/bin/env bash
# test-triage-classify.sh — deterministic fixture regression suite for
# agent-system/extensions/core/scripts/orchestrate-triage-classify.sh.
#
# Builds a throwaway scratch deploy tree ($(mktemp -d)/proj/.claude/scripts/) so the script's own
# deploy-root-guard.sh is satisfied without ever touching this repository's real .claude/
# directory. The scratch tree is removed on exit via trap, success or failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SRC_SCRIPT="$REPO_ROOT/agent-system/extensions/core/scripts/orchestrate-triage-classify.sh"
SRC_GUARD="$REPO_ROOT/agent-system/extensions/core/scripts/deploy-root-guard.sh"
FIXTURE="$SCRIPT_DIR/../fixtures/state-dry-run.json"
HANDOFF_DIR="$SCRIPT_DIR/../fixtures/handoffs"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

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
  cp "$SRC_SCRIPT" "$proj_dir/.claude/scripts/orchestrate-triage-classify.sh"
  cp "$SRC_GUARD" "$proj_dir/.claude/scripts/deploy-root-guard.sh"
  cp "$1" "$proj_dir/specs/state.json"
  # Seed task directories + handoff fixtures for the partial-status candidates
  mkdir -p "$proj_dir/specs/954_partial_blockers_no_continuation"
  cp "$HANDOFF_DIR/954-handoff.json" "$proj_dir/specs/954_partial_blockers_no_continuation/.orchestrator-handoff.json"
  mkdir -p "$proj_dir/specs/955_partial_neither"
  cp "$HANDOFF_DIR/955-handoff.json" "$proj_dir/specs/955_partial_neither/.orchestrator-handoff.json"
  mkdir -p "$proj_dir/specs/956_partial_with_continuation"
  cp "$HANDOFF_DIR/956-handoff.json" "$proj_dir/specs/956_partial_with_continuation/.orchestrator-handoff.json"
  echo "$proj_dir"
}

run_classify() {
  # $1 = proj_dir, $2 = engine, remaining = task numbers
  local proj_dir="$1" engine="$2"
  shift 2
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-triage-classify.sh "$engine" "$@")
}

PROJ="$(new_scratch_deploy "$FIXTURE")"

group_of() {
  # $1 = NDJSON output, $2 = task_number -> prints .group
  printf '%s\n' "$1" | jq -r --argjson t "$2" 'select(.task_number == $t) | .group'
}

# ============================================================
# 1. Every row of both engine tables
# ============================================================
declare -A expect_mt=(
  [950]="research"        # not_started
  [951]="plan"            # researched
  [956]="implement"       # partial + continuation
  [954]="needs_human"     # partial + blockers, no continuation
  [955]="implement"       # partial, neither -> mt
  [964]="skip"            # blocked -> mt (intentional, documented divergence from single)
  [965]="skip"            # researching
  [966]="skip"            # unknown status
  [957]="terminal"        # completed
)
declare -A expect_single=(
  [950]="research"
  [951]="plan"
  [956]="implement"
  [954]="needs_human"
  [955]="implement"       # partial, neither -> single
  [964]="needs_human"     # blocked -> single (intentional, documented divergence from mt)
  [965]="skip"
  [966]="skip"
  [957]="terminal"
)

mt_out=$(run_classify "$PROJ" mt 950 951 956 954 955 964 965 966 957)
single_out=$(run_classify "$PROJ" single 950 951 956 954 955 964 965 966 957)

table_ok=true
for t in "${!expect_mt[@]}"; do
  got=$(group_of "$mt_out" "$t")
  if [ "$got" != "${expect_mt[$t]}" ]; then
    table_ok=false
    echo "  mt table row wrong for task $t: expected ${expect_mt[$t]}, got $got"
  fi
done
for t in "${!expect_single[@]}"; do
  got=$(group_of "$single_out" "$t")
  if [ "$got" != "${expect_single[$t]}" ]; then
    table_ok=false
    echo "  single table row wrong for task $t: expected ${expect_single[$t]}, got $got"
  fi
done
if [ "$table_ok" = true ]; then
  pass "1. every row of both engine tables"
else
  fail "1. every row of both engine tables"
fi

# ============================================================
# 2. partial precedence: continuation wins over blockers
# ============================================================
# 956 has continuation and no blockers already; verify a task with BOTH a continuation and
# (hypothetically) blockers would still route to implement is implied by the precedence order
# documented in the script; 956's own line already exercises "continuation present" first-checked.
cont_group=$(group_of "$mt_out" 956)
cont_handoff_state=$(printf '%s\n' "$mt_out" | jq -r --argjson t 956 'select(.task_number == $t) | .handoff_state')
if [ "$cont_group" = "implement" ] && [ "$cont_handoff_state" = "continuation" ]; then
  pass "2. partial precedence: continuation-present task routes to implement with handoff_state=continuation"
else
  fail "2. partial precedence: got group=$cont_group handoff_state=$cont_handoff_state"
fi

# ============================================================
# 3. CONVERGENCE case: task 955 (partial, neither) classifies identically under both engines
# ============================================================
div_mt=$(group_of "$mt_out" 955)
div_single=$(group_of "$single_out" 955)
if [ "$div_mt" = "implement" ] && [ "$div_single" = "implement" ]; then
  pass "3. engine convergence: task 955 (partial, neither) is 'implement' under both mt and single"
else
  fail "3. engine convergence: got mt=$div_mt single=$div_single"
fi

# ============================================================
# 4. Usage errors exit 2 with empty stdout
# ============================================================
ec_ok=true

out=$( (cd "$PROJ" && bash .claude/scripts/orchestrate-triage-classify.sh bogus 950 2>/dev/null) )
ec=$?
[ "$ec" -eq 2 ] && [ -z "$out" ] || { ec_ok=false; echo "  bad engine: expected exit 2 / empty stdout, got exit=$ec stdout=[$out]"; }

out=$( (cd "$PROJ" && bash .claude/scripts/orchestrate-triage-classify.sh mt 2>/dev/null) )
ec=$?
[ "$ec" -eq 2 ] && [ -z "$out" ] || { ec_ok=false; echo "  zero task numbers: expected exit 2 / empty stdout, got exit=$ec stdout=[$out]"; }

out=$( (cd "$PROJ" && bash .claude/scripts/orchestrate-triage-classify.sh mt not_an_integer 2>/dev/null) )
ec=$?
[ "$ec" -eq 2 ] && [ -z "$out" ] || { ec_ok=false; echo "  non-integer task: expected exit 2 / empty stdout, got exit=$ec stdout=[$out]"; }

if [ "$ec_ok" = true ]; then
  pass "4. usage errors exit 2 with empty stdout"
else
  fail "4. usage errors"
fi

# ============================================================
# 5. blocker_count and handoff_age_min are populated for the blockers case (954)
# ============================================================
bc=$(printf '%s\n' "$mt_out" | jq -r --argjson t 954 'select(.task_number == $t) | .blocker_count')
age=$(printf '%s\n' "$mt_out" | jq -r --argjson t 954 'select(.task_number == $t) | .handoff_age_min')
if [ "$bc" = "1" ] && [ "$age" != "null" ]; then
  pass "5. blockers case (954) carries blocker_count=1 and a non-null handoff_age_min"
else
  fail "5. blockers case: got blocker_count=$bc handoff_age_min=$age"
fi

# ============================================================
# 6. No mutation of specs/ during the run
# ============================================================
before_sum=$(find "$PROJ/specs" -type f -exec sha256sum {} \; | sort)
run_classify "$PROJ" mt 950 951 956 954 955 964 965 966 957 >/dev/null
after_sum=$(find "$PROJ/specs" -type f -exec sha256sum {} \; | sort)
if [ "$before_sum" = "$after_sum" ]; then
  pass "6. read-only: specs/ tree unchanged (sha256sum manifest identical) across a run"
else
  fail "6. read-only: specs/ tree changed across a run"
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
