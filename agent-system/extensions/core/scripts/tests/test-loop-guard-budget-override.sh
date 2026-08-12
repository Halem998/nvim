#!/usr/bin/env bash
# test-loop-guard-budget-override.sh - Regression suite for Defect B: the explicit,
# operator-typed `--continue-budget` override that lets an operator continue a task's work past
# an exhausted MAX_CYCLES work-cycle budget, in BOTH orchestrate engines. Proves the documented
# resume path (`/orchestrate {N} [--hard] --continue-budget`) actually authorizes a fresh budget
# rather than silently no-op looping, while an ORDINARY cross-turn resume (no exhaustion, or a
# differing guard_session_id) is never disturbed by this override -- the exact invariant
# test-session-runtime-files.sh Case 3 already protects, asserted here from a second angle.
#
# Structural model: scripts/tests/test-handoff-dispatch-identity.sh (sentinel-region extraction
# via awk, mktemp -d workdir with an EXIT trap, pass()/fail()/info() helpers, exit 0 all-pass /
# 1 any-fail / 2 environment error, every case run against BOTH engines).
#
# Region scope (HONEST SCOPE LIMIT, matching test-loop-guard-staleness.sh's own convention): each
# extracted region spans from the `budget-continuation-override:begin` sentinel through the
# unique "Resuming — cycle" echo inside the pre-existing resume-read `if` branch, with a
# synthetic `fi` appended to close that intentionally-truncated block. This exercises the full
# override mechanism (peek, archive-or-refuse, reinit) AND the immediately-following resume read
# (cycle_count/dispatch_seq_counter/session_id-mismatch-INFO-log), but deliberately does NOT
# reach the fresh-init `else` branch, which depends on `task-lock.sh init-marker` and is out of
# scope here exactly as it is for the staleness suite's own sibling region.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

BASE_SKILL="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
HARD_SKILL="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md"

for f in "$BASE_SKILL" "$HARD_SKILL"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file not found: $f" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BEGIN_MARKER='budget-continuation-override:begin'
RESUME_ANCHOR_BASE='Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures'
RESUME_ANCHOR_HARD='Resuming — cycle $cycle_count of $MAX_CYCLES (burnout signals so far'

# Plain substring match (index()), not a regex match ($0 ~ pat) -- the anchors contain regex
# metacharacters ($, () that would otherwise need escaping and are fragile to get right.
extract_region() {
  local file="$1" resume_anchor="$2"
  awk -v b="$BEGIN_MARKER" -v r="$resume_anchor" '
    index($0, b) > 0 { flag=1 }
    flag { print }
    index($0, r) > 0 { if (flag) { print "fi"; exit } }
  ' "$file"
}

for f in "$BASE_SKILL" "$HARD_SKILL"; do
  bcount=$(grep -c "$BEGIN_MARKER" "$f")
  label="$(basename "$(dirname "$(dirname "$f")")")/$(basename "$f")"
  if [[ "$bcount" -eq 1 ]]; then
    pass "Exactly one '${BEGIN_MARKER}' marker in $label"
  else
    fail "Expected exactly one '${BEGIN_MARKER}' marker in $label, found ${bcount}"
  fi
done

base_region="$(extract_region "$BASE_SKILL" "$RESUME_ANCHOR_BASE")"
hard_region="$(extract_region "$HARD_SKILL" "$RESUME_ANCHOR_HARD")"

if [[ -z "$base_region" ]]; then
  echo "ERROR: could not extract budget-override region from $BASE_SKILL" >&2
  exit 2
fi
if [[ -z "$hard_region" ]]; then
  echo "ERROR: could not extract budget-override region from $HARD_SKILL" >&2
  exit 2
fi

# =====================================================================
# bash -n: each extracted region must be independently syntax-clean.
# =====================================================================
for pair in "base:$base_region" "hard:$hard_region"; do
  label="${pair%%:*}"; region="${pair#*:}"
  syntax_file="$WORKDIR/syntax-${label}.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'TASK_DIR="/tmp/fixture"'
    echo 'loop_guard_file="/tmp/fixture/.orchestrator-loop-guard"'
    echo 'MAX_CYCLES=13'
    echo 'MAX_INFRA_FAILURES=3'
    echo 'continue_budget_flag=false'
    echo 'task_number=1'
    echo 'session_id="sess_fixture"'
    printf '%s\n' "$region"
  } > "$syntax_file"
  if bash -n "$syntax_file" 2>"$WORKDIR/syntax-${label}.err"; then
    pass "Extracted region ($label engine) is bash -n clean"
  else
    fail "Extracted region ($label engine) failed bash -n: $(cat "$WORKDIR/syntax-${label}.err")"
  fi
done

# ── Region execution harness ────────────────────────────────────────────────────────────────────
# Runs an extracted region (base or hard) in a subshell against a fixture TASK_DIR. `exit 1` in
# the flag-absent branch only exits this SUBSHELL, not the test script itself, so it is safe to
# execute directly -- the caller observes it via $? from the subshell, not process termination.
run_region() {
  local region="$1" task_dir="$2" max_cycles="$3" flag="$4" session_id="$5" out_file="$6" err_file="$7"
  (
    TASK_DIR="$task_dir"
    loop_guard_file="${task_dir}/.orchestrator-loop-guard"
    MAX_CYCLES="$max_cycles"
    MAX_INFRA_FAILURES=3
    continue_budget_flag="$flag"
    task_number=1
    session_id="$session_id"
    eval "$region"
    echo "__EXIT_CODE__=0"
  ) > "$out_file" 2> "$err_file"
  echo $?
}

make_guard() {
  local path="$1" cycle_count="$2" session_id="${3:-sess_fixture_guard_writer}" \
        dispatch_seq_counter="${4:-3}" detected_defects="${5:-[]}"
  jq -n --argjson cc "$cycle_count" --arg sid "$session_id" --argjson dsc "$dispatch_seq_counter" \
    --argjson dd "$detected_defects" \
    '{"session_id":$sid,"cycle_count":$cc,"max_cycles":13,"infra_failures":0,
      "max_infra_failures":3,"current_state":"implementing","started":"2026-01-01T00:00:00Z",
      "last_updated":"2026-01-01T00:00:00Z","dispatch_seq_counter":$dsc,"detected_defects":$dd}' \
    > "$path"
}

count_glob() {
  local dir="$1" pattern="$2"
  # shellcheck disable=SC2012
  ls -1 "${dir}"/${pattern} 2>/dev/null | wc -l | tr -d ' '
}

LIVE_MAX_CYCLES=13

for pair in "base:$base_region" "hard:$hard_region"; do
  engine_label="${pair%%:*}"; region="${pair#*:}"

  # =====================================================================
  # Case 1: cycle_count == MAX_CYCLES, flag ABSENT. Expected: subshell exits 1 (refuses
  # immediately -- never enters the main loop, never a zero-iteration no-op), ERROR names the
  # actual working command, and the guard is left fully in place (not archived, not reset).
  # =====================================================================
  fx="$WORKDIR/case1-${engine_label}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES"
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "false" "sess_current" "$out" "$err")
  if [[ "$exit_code" -eq 1 ]]; then
    pass "case1-flag-absent (${engine_label}): subshell exits 1 (refuses immediately)"
  else
    fail "case1-flag-absent (${engine_label}): expected exit 1, got ${exit_code} -- stderr: $(cat "$err")"
  fi
  if grep -qE -- '--continue-budget' "$err"; then
    pass "case1-flag-absent (${engine_label}): stderr names the --continue-budget resume command"
  else
    fail "case1-flag-absent (${engine_label}): stderr does not name --continue-budget: $(cat "$err")"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    orig_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$orig_cc" -eq "$LIVE_MAX_CYCLES" ]]; then
      pass "case1-flag-absent (${engine_label}): guard left in place, cycle_count unchanged"
    else
      fail "case1-flag-absent (${engine_label}): guard cycle_count unexpectedly changed to ${orig_cc}"
    fi
  else
    fail "case1-flag-absent (${engine_label}): guard file unexpectedly removed"
  fi

  # =====================================================================
  # Case 2: cycle_count == MAX_CYCLES, flag PRESENT. Expected: guard archived (copied) to a
  # dated name, SAME guard path reinitialized at cycle_count=0 with dispatch_seq_counter and
  # detected_defects preserved, loud log emitted naming the exhausted count and the flag.
  # =====================================================================
  fx="$WORKDIR/case2-${engine_label}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" "$LIVE_MAX_CYCLES" "sess_fixture_guard_writer" 7 '["marker"]'
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "true" "sess_current" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case2-flag-present (${engine_label}): subshell exits 0 (continues to resume read)"
  else
    fail "case2-flag-present (${engine_label}): expected exit 0, got ${exit_code} -- stderr: $(cat "$err")"
  fi
  if [[ "$(count_glob "$fx" '.exhausted-loop-guard-*.json')" -eq 1 ]]; then
    pass "case2-flag-present (${engine_label}): exactly one exhausted-guard archive created"
  else
    fail "case2-flag-present (${engine_label}): expected exactly one archive, found $(count_glob "$fx" '.exhausted-loop-guard-*.json')"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    new_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    new_dsc=$(jq -r '.dispatch_seq_counter' "$fx/.orchestrator-loop-guard")
    new_dd=$(jq -c '.detected_defects' "$fx/.orchestrator-loop-guard")
    if [[ "$new_cc" -eq 0 ]]; then
      pass "case2-flag-present (${engine_label}): reinitialized guard has cycle_count=0"
    else
      fail "case2-flag-present (${engine_label}): expected cycle_count=0, got ${new_cc}"
    fi
    if [[ "$new_dsc" -eq 7 ]]; then
      pass "case2-flag-present (${engine_label}): dispatch_seq_counter preserved (7), never reset"
    else
      fail "case2-flag-present (${engine_label}): dispatch_seq_counter expected 7, got ${new_dsc}"
    fi
    if [[ "$new_dd" == '["marker"]' ]]; then
      pass "case2-flag-present (${engine_label}): detected_defects preserved"
    else
      fail "case2-flag-present (${engine_label}): detected_defects expected [\"marker\"], got ${new_dd}"
    fi
  else
    fail "case2-flag-present (${engine_label}): reinitialized guard file missing"
  fi
  if grep -qE 'BUDGET EXHAUSTED' "$err" && grep -qE 'continue-budget' "$err"; then
    pass "case2-flag-present (${engine_label}): stderr names BUDGET EXHAUSTED and the authorizing flag"
  else
    fail "case2-flag-present (${engine_label}): stderr missing expected content: $(cat "$err")"
  fi

  # =====================================================================
  # Case 3: cycle_count BELOW MAX_CYCLES, flag PRESENT. Expected: the flag is INERT when the
  # budget is not exhausted -- no archive, no reinit, ordinary resume proceeds untouched.
  # =====================================================================
  fx="$WORKDIR/case3-${engine_label}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" 2 "sess_fixture_guard_writer" 5
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "true" "sess_current" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case3-below-budget-flag-present (${engine_label}): subshell exits 0"
  else
    fail "case3-below-budget-flag-present (${engine_label}): expected exit 0, got ${exit_code}"
  fi
  if [[ "$(count_glob "$fx" '.exhausted-loop-guard-*.json')" -eq 0 ]]; then
    pass "case3-below-budget-flag-present (${engine_label}): no archive created (flag inert below budget)"
  else
    fail "case3-below-budget-flag-present (${engine_label}): unexpected archive created despite non-exhausted budget"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    unchanged_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$unchanged_cc" -eq 2 ]]; then
      pass "case3-below-budget-flag-present (${engine_label}): cycle_count untouched (2)"
    else
      fail "case3-below-budget-flag-present (${engine_label}): cycle_count unexpectedly changed to ${unchanged_cc}"
    fi
  else
    fail "case3-below-budget-flag-present (${engine_label}): guard file unexpectedly removed"
  fi

  # =====================================================================
  # Case 4: differing guard_session_id, budget NOT exhausted. Expected: still just an INFO log
  # (from the pre-existing, untouched session_id-mismatch block), never a reset -- asserting the
  # test-session-runtime-files.sh Case 3 invariant from a second angle, inside this suite too.
  # =====================================================================
  fx="$WORKDIR/case4-${engine_label}"; mkdir -p "$fx"
  make_guard "$fx/.orchestrator-loop-guard" 2 "sess_a_different_writer" 5
  out="$fx.out"; err="$fx.err"
  exit_code=$(run_region "$region" "$fx" "$LIVE_MAX_CYCLES" "false" "sess_current_caller" "$out" "$err")
  if [[ "$exit_code" -eq 0 ]]; then
    pass "case4-session-id-mismatch (${engine_label}): subshell exits 0"
  else
    fail "case4-session-id-mismatch (${engine_label}): expected exit 0, got ${exit_code}"
  fi
  # The session_id-mismatch INFO log itself is a BASE-ENGINE-ONLY, pre-existing, untouched
  # feature -- skill-orchestrate-hard/SKILL.md's own resume-read block has no guard_session_id
  # check at all (confirmed: zero occurrences of "guard_session_id" in that file). This is not a
  # parity gap this task's scope covers; the invariant this case actually asserts for BOTH
  # engines is "a differing session_id never resets cycle_count", checked below regardless of
  # engine. It is plain `echo` (no `>&2`) in base mode, so it lands on stdout, not stderr.
  if [[ "$engine_label" == "base" ]]; then
    if grep -qE 'INFO: loop guard was last written by a different session_id' "$out"; then
      pass "case4-session-id-mismatch (${engine_label}): INFO log present, never a gate"
    else
      fail "case4-session-id-mismatch (${engine_label}): expected INFO log missing: $(cat "$out")"
    fi
  else
    info "case4-session-id-mismatch (${engine_label}): hard engine has no guard_session_id INFO log (base-only, pre-existing) -- asserting the never-reset invariant only"
  fi
  if [[ -f "$fx/.orchestrator-loop-guard" ]]; then
    mismatch_cc=$(jq -r '.cycle_count' "$fx/.orchestrator-loop-guard")
    if [[ "$mismatch_cc" -eq 2 ]]; then
      pass "case4-session-id-mismatch (${engine_label}): guard untouched despite session_id mismatch"
    else
      fail "case4-session-id-mismatch (${engine_label}): guard unexpectedly reset to ${mismatch_cc}"
    fi
  else
    fail "case4-session-id-mismatch (${engine_label}): guard file unexpectedly removed"
  fi
done

# =====================================================================
# Stage 7 message assertion: both engines' MAX_CYCLES branch names --continue-budget.
# =====================================================================
if grep -A3 'MAX_CYCLES ($MAX_CYCLES) reached for task' "$BASE_SKILL" | grep -q -- '--continue-budget'; then
  pass "skill-orchestrate/SKILL.md Stage 7 MAX_CYCLES message names --continue-budget"
else
  fail "skill-orchestrate/SKILL.md Stage 7 MAX_CYCLES message does not name --continue-budget"
fi
if grep -A3 'MAX_CYCLES ($MAX_CYCLES) reached for task' "$HARD_SKILL" | grep -q -- '--continue-budget'; then
  pass "skill-orchestrate-hard/SKILL.md Stage 7 MAX_CYCLES message names --continue-budget"
else
  fail "skill-orchestrate-hard/SKILL.md Stage 7 MAX_CYCLES message does not name --continue-budget"
fi

# =====================================================================
# test-session-runtime-files.sh Case 3 byte-stability: git diff HEAD must be empty for the base
# engine file, or a recorded justification must exist. This suite runs the check itself rather
# than trusting a hand-authored claim.
# =====================================================================
SESSION_TEST_CANDIDATES=(
  "$SCRIPT_DIR/../test-session-runtime-files.sh"
  "$REPO_ROOT/.claude/scripts/test-session-runtime-files.sh"
)
SESSION_TEST=""
for candidate in "${SESSION_TEST_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SESSION_TEST="$candidate"
    break
  fi
done
if [[ -n "$SESSION_TEST" ]]; then
  if bash "$SESSION_TEST" >"$WORKDIR/session-runtime.out" 2>&1; then
    pass "test-session-runtime-files.sh passes (Case 3 included)"
  else
    fail "test-session-runtime-files.sh FAILED -- see $WORKDIR/session-runtime.out"
    cat "$WORKDIR/session-runtime.out"
  fi
else
  info "test-session-runtime-files.sh not found at any candidate path -- skipping (not this suite's environment error)"
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
