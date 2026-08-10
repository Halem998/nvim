#!/usr/bin/env bash
# test-skill-base-lifecycle.sh - Fixture-driven regression suite for scripts/skill-base.sh's
# highest-blast-radius state-mutating lifecycle functions: skill_preflight_update,
# skill_postflight_update, skill_gate_completion_claim, skill_link_artifacts, skill_cleanup.
#
# Of skill-base.sh's 17 top-level functions, only skill_corroborate_phase_counts had dedicated
# coverage prior to this suite (see test-corroborate-phase-counts.sh). This suite closes the
# largest remaining gap by covering the five functions named above; the other 11 remain
# uncovered residuals (see this suite's own header note below and the summary artifact this
# suite's authoring plan produces).
#
# Structural model: test-corroborate-phase-counts.sh (mktemp -d workdir with an EXIT-trap
# cleanup, deploy-tree-first / source-store-fallback candidate resolution, sourced -- not
# subprocessed -- skill-base.sh itself, pass()/fail()/info() helpers with integer counters, exit
# 0 all-pass / 1 any-fail / 2 environment error).
#
# ISOLATION CONTRACT (never touches the real specs/ tree, real state.json, or real task locks):
#   skill_gate_completion_claim and skill_cleanup are pure-logic/pure-filesystem functions tested
#   directly against a mktemp -d WORKDIR.
#   skill_link_artifacts is tested via a SKILL_REPO_ROOT override pointing at an isolated
#   mktemp -d fixture repo (skill_link_artifacts and skill_propagate_completion_summary route
#   every write through "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" -- a
#   SKILL_REPO_ROOT-qualified path, not a bare relative one -- exactly the override this suite
#   relies on).
#   skill_preflight_update and skill_postflight_update hardcode the bare relative path
#   `.claude/scripts/update-task-status.sh` (NOT SKILL_REPO_ROOT-qualified, matching every real
#   SKILL.md call site's assumption that cwd == repo root under a live deploy). This suite
#   therefore builds a full isolated fixture repo under WORKDIR (a real .claude/scripts/ tree
#   copied from the deployed tree, plus a private specs/state.json and task directory) and `cd`s
#   into it before exercising those two functions, so the relative path resolves into the
#   fixture -- never into the real repo's .claude/ or specs/.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library/script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# ─── candidate resolution: deployed tree first, source-store fallback ─────────────────────────
resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE="$(resolve_candidate "skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy update-task-status.sh's dependency" >&2
  echo "       chain (state-write.sh, task-lock.sh, deploy-root-guard.sh, lib/*.sh) from." >&2
  exit 2
fi
for req in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done

# shellcheck disable=SC1090
. "$SKILL_BASE"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

ORIG_PWD="$(pwd)"

# Baseline of the real specs/ tree, captured BEFORE any group runs. The contamination guard at
# the end of this suite compares against this baseline (a delta check), not against an assumed
# "must be empty" absolute state -- the real specs/ tree is routinely non-clean during a live
# session (this suite's own dispatch writes real progress/handoff/events.jsonl entries as a side
# effect of ordinary hook-driven event logging on every real tool call), so an absolute
# emptiness check would false-positive on that ambient, pre-existing dirt.
BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# ─── build_fixture_repo: a full isolated repo shape under $1, real deployed scripts copied in ──
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  for f in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/" 2>/dev/null || true
  cat > "$root/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "researched",
      "task_type": "general",
      "next_artifact_number": 1
    }
  ]
}
EOF
}

# =====================================================================
# Group 1: skill_gate_completion_claim -- pure logic, no I/O. All three cases plus the
# non-integer-input sanitization guard.
# =====================================================================
info "=== skill_gate_completion_claim ==="

if skill_gate_completion_claim 900 3 3 "absent" "[test]" 2>/tmp/sgcc-out.$$; then
  pass "Case 2: phases_completed >= phases_total (3/3) -> ALLOW (return 0)"
else
  fail "Case 2: phases_completed >= phases_total (3/3) -> expected ALLOW, got REFUSE"
fi
rm -f /tmp/sgcc-out.$$

if skill_gate_completion_claim 901 2 3 "absent" "[test]" 2>/dev/null; then
  fail "Case 1: phases_completed < phases_total (2/3) -> expected REFUSE, got ALLOW"
else
  pass "Case 1: phases_completed < phases_total (2/3) -> REFUSE (return 1)"
fi

if skill_gate_completion_claim 902 0 0 "true" "[test]" 2>/dev/null; then
  pass "Case 3 corroborated: phases_total=0, plan_markers_verified=true -> ALLOW (return 0)"
else
  fail "Case 3 corroborated: phases_total=0, plan_markers_verified=true -> expected ALLOW, got REFUSE"
fi

if skill_gate_completion_claim 903 0 0 "false" "[test]" 2>/dev/null; then
  fail "Case 3 uncorroborated: phases_total=0, plan_markers_verified=false -> expected REFUSE, got ALLOW"
else
  pass "Case 3 uncorroborated: phases_total=0, plan_markers_verified=false -> REFUSE (return 1)"
fi

# Failing-input case: non-integer phases_completed/phases_total must sanitize to 0 (fail closed
# to Case 3), never crash the -ge/-gt arithmetic under set -e.
if skill_gate_completion_claim 904 "not-a-number" "also-not-a-number" "false" "[test]" 2>/dev/null; then
  fail "Non-integer inputs sanitize to 0/0, plan_markers_verified=false -> expected REFUSE, got ALLOW"
else
  pass "Non-integer inputs sanitize to 0/0 (fail closed to Case 3) without an arithmetic crash"
fi

# =====================================================================
# Group 2: skill_cleanup -- removes the three lifecycle temp files; must not error when they are
# already absent (the || true guard's own contract).
# =====================================================================
info "=== skill_cleanup ==="

CLEANUP_TASK_DIR="$WORKDIR/specs/002_cleanup_fixture"
mkdir -p "$CLEANUP_TASK_DIR"
touch "$CLEANUP_TASK_DIR/.postflight-pending" \
      "$CLEANUP_TASK_DIR/.postflight-loop-guard" \
      "$CLEANUP_TASK_DIR/.return-meta.json"
( cd "$WORKDIR" && skill_cleanup "002" "cleanup_fixture" )
if [[ ! -f "$CLEANUP_TASK_DIR/.postflight-pending" ]] && \
   [[ ! -f "$CLEANUP_TASK_DIR/.postflight-loop-guard" ]] && \
   [[ ! -f "$CLEANUP_TASK_DIR/.return-meta.json" ]]; then
  pass "skill_cleanup removes all three lifecycle temp files"
else
  fail "skill_cleanup left at least one lifecycle temp file behind"
fi

# Failing/degenerate-input case: calling again on an already-clean directory must not error
# (rm -f ... || true is exactly this contract).
if ( cd "$WORKDIR" && skill_cleanup "002" "cleanup_fixture" ); then
  pass "skill_cleanup on an already-clean directory is a silent no-op (no error)"
else
  fail "skill_cleanup on an already-clean directory unexpectedly returned nonzero"
fi

# =====================================================================
# Group 3: skill_link_artifacts -- routed through SKILL_REPO_ROOT-qualified state-write.sh calls
# plus a generate-todo.sh regen. Isolated via SKILL_REPO_ROOT override; never touches the real
# specs/ tree.
# =====================================================================
info "=== skill_link_artifacts ==="

LINK_ROOT="$WORKDIR/link-fixture"
build_fixture_repo "$LINK_ROOT"
mkdir -p "$LINK_ROOT/specs/001_fixture_task/summaries"
cat > "$LINK_ROOT/specs/001_fixture_task/summaries/01_fixture-summary.md" << 'EOF'
# Implementation Summary: Fixture Task

- **Status**: [COMPLETED]
EOF

SKILL_REPO_ROOT="$LINK_ROOT" skill_link_artifacts 1 \
  "specs/001_fixture_task/summaries/01_fixture-summary.md" "summary" "Fixture summary" \
  "'**Summary**'" "'**Description**'" "sess_test_link" 2>"$WORKDIR/link-stderr.log"
LINK_EXIT=$?

if [[ "$LINK_EXIT" -eq 0 ]]; then
  registered=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$registered" == "1" ]]; then
    pass "skill_link_artifacts registers exactly one artifact entry in state.json"
  else
    fail "skill_link_artifacts: expected 1 artifact entry, found '$registered' (see $WORKDIR/link-stderr.log)"
  fi
  path_written=$(jq -r '.active_projects[0].artifacts[0].path // ""' "$LINK_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$path_written" == "specs/001_fixture_task/summaries/01_fixture-summary.md" ]]; then
    pass "skill_link_artifacts writes the exact artifact path"
  else
    fail "skill_link_artifacts: path mismatch, got '$path_written'"
  fi
else
  fail "skill_link_artifacts exited $LINK_EXIT (see $WORKDIR/link-stderr.log)"
fi

# Failing-input case: empty artifact_path is a documented no-op guard (the `[ -n "$artifact_path" ]`
# gate) -- must not attempt a write or error.
BEFORE_COUNT=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
SKILL_REPO_ROOT="$LINK_ROOT" skill_link_artifacts 1 "" "summary" "" "'**Summary**'" "'**Description**'" "sess_test_link" 2>/dev/null
AFTER_COUNT=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
if [[ "$BEFORE_COUNT" == "$AFTER_COUNT" ]]; then
  pass "skill_link_artifacts with an empty artifact_path is a no-op (artifact count unchanged: $BEFORE_COUNT)"
else
  fail "skill_link_artifacts with an empty artifact_path unexpectedly changed artifact count ($BEFORE_COUNT -> $AFTER_COUNT)"
fi

# =====================================================================
# Group 4: skill_preflight_update / skill_postflight_update -- hardcode the bare relative path
# .claude/scripts/update-task-status.sh, so this group cd's into a full fixture repo.
# =====================================================================
info "=== skill_preflight_update / skill_postflight_update ==="

LIFECYCLE_ROOT="$WORKDIR/lifecycle-fixture"
build_fixture_repo "$LIFECYCLE_ROOT"

cd "$LIFECYCLE_ROOT" || { fail "could not cd into lifecycle fixture repo"; }

skill_preflight_update 1 "plan" "sess_test_preflight" 2>"$WORKDIR/preflight-stderr.log"
PREFLIGHT_EXIT=$?
if [[ "$PREFLIGHT_EXIT" -eq 0 ]]; then
  new_status=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$new_status" == "planning" ]]; then
    pass "skill_preflight_update transitions researched -> planning for a plan preflight"
  else
    fail "skill_preflight_update: expected status 'planning', got '$new_status' (see $WORKDIR/preflight-stderr.log)"
  fi
else
  fail "skill_preflight_update exited $PREFLIGHT_EXIT (see $WORKDIR/preflight-stderr.log)"
fi

skill_postflight_update 1 "plan" "sess_test_preflight" "planned" 2>"$WORKDIR/postflight-stderr.log"
POSTFLIGHT_EXIT=$?
if [[ "$POSTFLIGHT_EXIT" -eq 0 ]]; then
  new_status=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$new_status" == "planned" ]]; then
    pass "skill_postflight_update transitions planning -> planned on a successful plan postflight"
  else
    fail "skill_postflight_update: expected status 'planned', got '$new_status' (see $WORKDIR/postflight-stderr.log)"
  fi
else
  fail "skill_postflight_update exited $POSTFLIGHT_EXIT (see $WORKDIR/postflight-stderr.log)"
fi

# Failing/degenerate-input case: a non-success status must SKIP the update-task-status.sh call
# entirely (the case "$status" in researched|planned|implemented) guard) and never touch
# state.json -- status stays exactly as it was left by the prior postflight above.
BEFORE_STATUS=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
skill_postflight_update 1 "plan" "sess_test_preflight" "blocked" 2>/dev/null
AFTER_STATUS=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
if [[ "$BEFORE_STATUS" == "$AFTER_STATUS" ]]; then
  pass "skill_postflight_update with a non-success status ('blocked') skips the status write (unchanged: $AFTER_STATUS)"
else
  fail "skill_postflight_update with a non-success status unexpectedly changed state.json ($BEFORE_STATUS -> $AFTER_STATUS)"
fi

cd "$ORIG_PWD" || true

# =====================================================================
# Real-tree contamination guard: this suite must never leave a NEW mark on the actual repo's
# specs/ tree relative to the pre-suite baseline, no matter which group ran. Delta check, not an
# absolute-emptiness check -- see the BASELINE_SPECS_STATUS comment above for why.
# =====================================================================
info "=== contamination guard ==="
FINAL_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [[ "$FINAL_SPECS_STATUS" == "$BASELINE_SPECS_STATUS" ]]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status changed during this suite (baseline vs. final differ) -- baseline:
$BASELINE_SPECS_STATUS
-- final:
$FINAL_SPECS_STATUS"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
echo ""
echo "Residual (uncovered by this suite, out of scope per this suite's own authoring plan):"
echo "  skill_get_extension_dir, skill_run_extension_hook, _events_append_observable,"
echo "  skill_validate_input, skill_create_postflight_marker, skill_context_injection,"
echo "  skill_read_artifact_number, skill_read_metadata, skill_validate_artifact,"
echo "  skill_validate_task_artifacts, skill_propagate_completion_summary,"
echo "  skill_corroborate_phase_counts (already covered by test-corroborate-phase-counts.sh)."

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
