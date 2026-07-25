#!/usr/bin/env bash
# test-self-modifying-gate.sh — deterministic fixture regression suite for the self-modification
# hazard gate added to agent-system/extensions/core/scripts/orchestrate-batch-admit.sh (and
# surfaced by scripts/orchestrate-dry-run-report.sh).
#
# Builds a throwaway scratch deploy tree ($(mktemp -d)/proj/.claude/...) so the scripts' own
# deploy-root-guard.sh is satisfied without ever touching this repository's real .claude/
# directory or specs/state.json. The scratch tree is removed on exit via trap, success or
# failure.
#
# Design note: assertions extract specific fields via jq (self_modifying, decision, defer_reason)
# rather than pinning whole-verdict exact strings, because the fixture state file intentionally
# contains multiple candidates that may also incidentally participate in each other's ordinary
# collision scan (every candidate is compared against every non-terminal task in the WHOLE state
# file, not just the CLI arguments passed) — pinning whole-object strings here would couple
# unrelated assertions to fixture layout accidents. The one exception is the D4 precedence
# assertion, which explicitly checks the ABSENCE of collision-only fields.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORE="$REPO_ROOT/agent-system/extensions/core"
SRC_ADMIT="$CORE/scripts/orchestrate-batch-admit.sh"
SRC_DRYRUN="$CORE/scripts/orchestrate-dry-run-report.sh"
SRC_TRIAGE="$CORE/scripts/orchestrate-triage-classify.sh"
SRC_LOCK="$CORE/scripts/task-lock.sh"
SRC_GUARD="$CORE/scripts/deploy-root-guard.sh"
SRC_CRITICAL="$CORE/context/reference/orchestrator-critical-paths.json"
FIXTURE="$SCRIPT_DIR/../fixtures/state-self-mod.json"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# --- scratch deploy tree(s); MUST NOT write into the repository's real .claude/ or specs/ ---
SCRATCH_ROOTS=()
cleanup() {
  for r in "${SCRATCH_ROOTS[@]:-}"; do
    [ -n "$r" ] && rm -rf "$r"
  done
}
trap cleanup EXIT

new_scratch_deploy() {
  # $1 = path to a specs/state.json to seed the scratch root with
  # $2 = "with_critical" | "without_critical" (whether to copy the critical-paths data file)
  local root proj_dir
  root="$(mktemp -d)"
  SCRATCH_ROOTS+=("$root")
  proj_dir="$root/proj"
  mkdir -p "$proj_dir/.claude/scripts" "$proj_dir/.claude/context/reference" "$proj_dir/specs"
  cp "$SRC_ADMIT" "$proj_dir/.claude/scripts/orchestrate-batch-admit.sh"
  cp "$SRC_DRYRUN" "$proj_dir/.claude/scripts/orchestrate-dry-run-report.sh"
  cp "$SRC_TRIAGE" "$proj_dir/.claude/scripts/orchestrate-triage-classify.sh"
  cp "$SRC_LOCK" "$proj_dir/.claude/scripts/task-lock.sh"
  cp "$SRC_GUARD" "$proj_dir/.claude/scripts/deploy-root-guard.sh"
  if [ "${2:-with_critical}" = "with_critical" ]; then
    cp "$SRC_CRITICAL" "$proj_dir/.claude/context/reference/orchestrator-critical-paths.json"
  fi
  cp "$1" "$proj_dir/specs/state.json"
  echo "$proj_dir"
}

run_admit() {
  # $1 = proj_dir, remaining args = admit.sh args (flags + candidates)
  local proj_dir="$1"
  shift
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-batch-admit.sh "$@" 2>/dev/null)
}

run_admit_capture_stderr() {
  # $1 = proj_dir, $2 = stderr capture file, remaining args = admit.sh args
  local proj_dir="$1" errfile="$2"
  shift 2
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-batch-admit.sh "$@" 2>"$errfile")
}

field() {
  # $1 = verdict json line, $2 = jq field expression (compact, no // fallback tricks needed here)
  printf '%s' "$1" | jq -c "$2" 2>/dev/null
}

FIXTURE_PROJ="$(new_scratch_deploy "$FIXTURE" "with_critical")"

# ============================================================
# 1. Source-store critical path: defer with defer_reason=self_modifying at invocation count > 1
# ============================================================
v1="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 950)"
if [ "$(field "$v1" '.decision')" = '"defer"' ] && \
   [ "$(field "$v1" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v1" '.self_modifying')" = "true" ] && \
   [ "$(field "$v1" '.critical_path')" = '"agent-system/extensions/core/scripts/task-lock.sh"' ]; then
  pass "1. source-store critical path defers with defer_reason=self_modifying at invocation count 2"
else
  fail "1. source-store critical path defer: got: $v1"
fi

# ============================================================
# 2. Same candidate, invocation count 1 -> admit, self_modifying still true
# ============================================================
v2="$(run_admit "$FIXTURE_PROJ" --invocation-count 1 950)"
if [ "$(field "$v2" '.decision')" = '"admit"' ] && [ "$(field "$v2" '.self_modifying')" = "true" ]; then
  pass "2. source-store critical path admits solo at invocation count 1, self_modifying still true"
else
  fail "2. solo admit at invocation count 1: got: $v2"
fi

# ============================================================
# 3. Deploy-tree path (.claude/...) matches the same declared entry
# ============================================================
v3="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 951)"
if [ "$(field "$v3" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v3" '.critical_path')" = '".claude/scripts/skill-base.sh"' ] && \
   [ "$(field "$v3" '.critical_label')" = '"preflight/postflight/completion-claim gate"' ]; then
  pass "3. deploy-tree path (.claude/scripts/skill-base.sh) matches the declared critical entry"
else
  fail "3. deploy-tree path match: got: $v3"
fi

# ============================================================
# 4. Directory-prefix ancestor of a critical path is detected
# ============================================================
v4="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 952)"
if [ "$(field "$v4" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v4" '.critical_path')" = '"agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"' ]; then
  pass "4. directory-prefix ancestor (skills/skill-orchestrate/) matches contained critical file"
else
  fail "4. directory-prefix ancestor match: got: $v4"
fi

# ============================================================
# 5. Explicitly-excluded file (command-gate-in.sh) must NOT be flagged self_modifying
# ============================================================
v5="$(run_admit "$FIXTURE_PROJ" --invocation-count 1 953)"
if [ "$(field "$v5" '.self_modifying')" = "false" ]; then
  pass "5. explicitly-excluded file (command-gate-in.sh) is not flagged self_modifying"
else
  fail "5. excluded file must not be flagged: got: $v5"
fi

# ============================================================
# 6. Ordinary non-critical candidate carries self_modifying=false
#    (960, not 954 -- 954's file_scope is deliberately shared with 959 for test 13's in-batch
#    direction coverage, so 954 is not scope-isolated; 960 is fully isolated in this fixture)
# ============================================================
v6="$(run_admit "$FIXTURE_PROJ" --invocation-count 1 960)"
if [ "$(field "$v6" '.self_modifying')" = "false" ] && [ "$(field "$v6" '.decision')" = '"admit"' ]; then
  pass "6. ordinary candidate admits with self_modifying=false"
else
  fail "6. ordinary candidate: got: $v6"
fi

# ============================================================
# 7. Only the self-modifying candidate is deferred; an ordinary sibling is unaffected
# ============================================================
v7="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 950 960)"
v7_950="$(printf '%s\n' "$v7" | jq -c 'select(.task_number == 950)')"
v7_960="$(printf '%s\n' "$v7" | jq -c 'select(.task_number == 960)')"
if [ "$(field "$v7_950" '.decision')" = '"defer"' ] && [ "$(field "$v7_950" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v7_960" '.decision')" = '"admit"' ] && [ "$(field "$v7_960" '.self_modifying')" = "false" ]; then
  pass "7. only the self-modifying candidate (950) is deferred; ordinary sibling (960) unaffected"
else
  fail "7. sibling isolation: got 950=$v7_950 960=$v7_960"
fi

# ============================================================
# 8. Self-modification precedence over a simultaneous file_scope collision (D4)
# ============================================================
v8="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 957)"
if [ "$(field "$v8" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v8" '.colliding_task_number')" = "null" ] && \
   [ "$(field "$v8" '.collision_scope')" = "null" ]; then
  pass "8. self-modification precedence over a simultaneous collision (D4): collision fields absent"
else
  fail "8. D4 precedence: got: $v8"
fi

# ============================================================
# 9. Degraded: self_modifying: null plus exit 0 when critical-paths data file is absent
# ============================================================
NO_CRIT_PROJ="$(new_scratch_deploy "$FIXTURE" "without_critical")"
errfile="$(mktemp)"
v9="$(run_admit_capture_stderr "$NO_CRIT_PROJ" "$errfile" --invocation-count 2 950)"
ec9=$?
stderr9=$(cat "$errfile" 2>/dev/null)
rm -f "$errfile"
if [ "$ec9" -eq 0 ] && [ "$(field "$v9" '.self_modifying')" = "null" ] && [ -n "$stderr9" ]; then
  pass "9. degraded (data file absent): self_modifying=null, exit 0, non-empty stderr warning"
else
  fail "9. degraded case: exit=$ec9 verdict=$v9 stderr=[$stderr9]"
fi

# ============================================================
# 10. Wave-spanning: the trigger is invocation-scoped, not wave/cycle-scoped
# ============================================================
# 955 is self-modifying and has no dependents in wave 0; 956 depends on 955 (a different wave).
# Calling admit for 955 ALONE (as a live wave-0-only dispatch would) but with
# --invocation-count 2 (the whole invocation's validated-candidate count, per D3) must still
# defer -- proving the check is NOT scoped to "this call's positional argument count" (which
# would default to 1 and incorrectly admit solo).
v10_correct="$(run_admit "$FIXTURE_PROJ" --invocation-count 2 955)"
v10_naive="$(run_admit "$FIXTURE_PROJ" 955)"
if [ "$(field "$v10_correct" '.defer_reason')" = '"self_modifying"' ] && \
   [ "$(field "$v10_naive" '.decision')" = '"admit"' ]; then
  pass "10. wave-spanning: --invocation-count 2 defers 955 even when called alone (wave 0); omitting the flag (naive count=1) would incorrectly admit -- demonstrating why callers MUST pass the full invocation count"
else
  fail "10. wave-spanning invocation-scoped trigger: correct=$v10_correct naive=$v10_naive"
fi

# ============================================================
# 11. Well-formedness: valid JSON, exit codes
# ============================================================
wf_ok=true
for line in "$v1" "$v2" "$v3" "$v4" "$v5" "$v6" "$v7_950" "$v7_960" "$v8" "$v9" "$v10_correct" "$v10_naive"; do
  if ! jq -e . >/dev/null 2>&1 <<< "$line"; then
    wf_ok=false
    echo "  well-formedness: line does not parse as JSON: $line"
  fi
done
out=$(run_admit "$FIXTURE_PROJ" --invocation-count abc 950)
ec=$?
[ "$ec" -eq 2 ] || { wf_ok=false; echo "  well-formedness: non-integer --invocation-count expected exit 2, got exit=$ec"; }
if [ "$wf_ok" = true ]; then
  pass "11. well-formedness (valid JSON, non-integer --invocation-count rejected)"
else
  fail "11. well-formedness"
fi

# ============================================================
# 12. Dry-run report: plain-language exclusion line and solo Note
# ============================================================
dr_together=$(cd "$FIXTURE_PROJ" && bash .claude/scripts/orchestrate-dry-run-report.sh 950 960 2>/dev/null)
excl_line=$(printf '%s\n' "$dr_together" | grep -A3 -- "-- Excluded --" | grep "#950")
if printf '%s\n' "$excl_line" | grep -q "self-modification hazard" && printf '%s\n' "$excl_line" | grep -q "re-run it alone"; then
  pass "12a. dry-run report: self-modifying exclusion line names the hazard and instructs a solo re-run"
else
  fail "12a. dry-run report exclusion line: got: $excl_line"
fi

dr_solo=$(cd "$FIXTURE_PROJ" && bash .claude/scripts/orchestrate-dry-run-report.sh 950 2>/dev/null)
if printf '%s\n' "$dr_solo" | grep -q "admitted with self_modifying=true"; then
  pass "12b. dry-run report: solo admit carries the self_modifying Note"
else
  fail "12b. dry-run report solo Note missing: $dr_solo"
fi

# ============================================================
# 13. Coverage-preservation: in-batch file_scope_collision direction rule, using two
# NON-self-modifying candidates (954, 959 -- identical file_scope, no dependencies[] edge).
#
# Why this test exists here: specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh
# previously demonstrated the in-batch collision-direction rule (lower project_number wins,
# higher defers) using real fixture candidates 900/902. Both of those candidates are themselves
# genuinely self-modifying (they are real tasks whose file_scope legitimately names orchestrator
# machinery), so as of this gate they now demonstrate self-modification precedence (D4) instead
# -- correctly, but that retires their coverage of the plain in-batch collision-direction rule
# with NO self-modification involved. This test restores that coverage using synthetic,
# deliberately non-critical candidates, so the underlying (pre-existing, unchanged) direction
# rule stays under test independent of the new gate.
# ============================================================
v13="$(run_admit "$FIXTURE_PROJ" 954 959)"
v13_954="$(printf '%s\n' "$v13" | jq -c 'select(.task_number == 954)')"
v13_959="$(printf '%s\n' "$v13" | jq -c 'select(.task_number == 959)')"
if [ "$(field "$v13_954" '.decision')" = '"admit"' ] && [ "$(field "$v13_954" '.self_modifying')" = "false" ] && \
   [ "$(field "$v13_959" '.decision')" = '"defer"' ] && [ "$(field "$v13_959" '.defer_reason')" = '"file_scope_collision"' ] && \
   [ "$(field "$v13_959" '.collision_scope')" = '"in_batch"' ] && [ "$(field "$v13_959" '.colliding_task_number')" = "954" ]; then
  pass "13. in-batch collision direction preserved for non-self-modifying candidates (954 admits, 959 defers to lower-numbered 954)"
else
  fail "13. in-batch direction coverage-preservation: 954=$v13_954 959=$v13_959"
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
