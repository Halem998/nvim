#!/usr/bin/env bash
# test-task-lock-create.sh — Isolated-fixture proof that task-lock.sh's acquire-only
# create-if-missing change is correct and side-effect-free elsewhere.
#
# Task-scoped test (specs/918_task_lock_create_task_dir_before_acquire/tests/), following the
# convention already used elsewhere under specs/*/tests/. Never touches the real specs/ tree:
# every scenario builds its own throwaway root under `mktemp -d` containing a `.claude/scripts/`
# copy of the DEPLOYED task-lock.sh and deploy-root-guard.sh (the guard is a structural path
# check — "*/.claude/scripts" or "*/.opencode/scripts" — so a plain temp directory satisfies it
# without any real deploy tree) plus a synthetic specs/state.json.
#
# Usage: bash test-task-lock-create.sh
# Exit: 0 if all scenarios PASS, non-zero if any FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOYED_LOCK="$REPO_ROOT/.claude/scripts/task-lock.sh"
DEPLOYED_GUARD="$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"

if [ ! -f "$DEPLOYED_LOCK" ]; then
  echo "FAIL: deployed task-lock.sh not found at $DEPLOYED_LOCK — run deploy-headless.sh first." >&2
  exit 1
fi
if [ ! -f "$DEPLOYED_GUARD" ]; then
  echo "FAIL: deployed deploy-root-guard.sh not found at $DEPLOYED_GUARD — run deploy-headless.sh first." >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

# --- new_fixture: build a fresh throwaway root, return its path on stdout ---
new_fixture() {
  local root
  root=$(mktemp -d)
  mkdir -p "$root/.claude/scripts" "$root/specs"
  cp "$DEPLOYED_LOCK" "$root/.claude/scripts/task-lock.sh"
  cp "$DEPLOYED_GUARD" "$root/.claude/scripts/deploy-root-guard.sh"
  chmod +x "$root/.claude/scripts/task-lock.sh"
  echo "$root"
}

# --- write_state: write specs/state.json with the given active_projects JSON array ---
write_state() {
  local root="$1" projects_json="$2"
  printf '{"next_project_number": 999, "active_projects": %s}\n' "$projects_json" \
    > "$root/specs/state.json"
}

# --- lock: run the fixture's task-lock.sh with the given args ---
lock() {
  local root="$1"
  shift
  bash "$root/.claude/scripts/task-lock.sh" "$@"
}

# --- report: print PASS/FAIL for one assertion, tally counts ---
report() {
  local scenario="$1" ok="$2" detail="$3"
  if [ "$ok" = "true" ]; then
    echo "PASS: $scenario"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $scenario -- $detail"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

cleanup_roots=()
cleanup_all() {
  local r
  for r in "${cleanup_roots[@]:-}"; do
    [ -n "$r" ] && [ -d "$r" ] && rm -rf "$r"
  done
}
trap cleanup_all EXIT

# =====================================================================
# Scenario 1: acquire on a task present in state.json with no directory
# -> exit 0; directory exists with reports/, plans/, summaries/, and
#    .lock/holder.json.
# =====================================================================
scenario_1() {
  local root task_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 401, "project_name": "task_alpha"}]'

  local out rc
  out=$(lock "$root" acquire 401 plan sess_test_1 2>&1)
  rc=$?
  task_dir="$root/specs/401_task_alpha"

  if [ "$rc" -ne 0 ]; then
    report "1: acquire creates directory on first use" false "exit=$rc (expected 0); output: $out"
    return
  fi
  if [ ! -d "$task_dir/reports" ] || [ ! -d "$task_dir/plans" ] || [ ! -d "$task_dir/summaries" ]; then
    report "1: acquire creates directory on first use" false "missing reports/plans/summaries under $task_dir"
    return
  fi
  if [ ! -f "$task_dir/.lock/holder.json" ]; then
    report "1: acquire creates directory on first use" false "missing .lock/holder.json under $task_dir"
    return
  fi
  report "1: acquire creates directory on first use" true ""
}

# =====================================================================
# Scenario 2: check on a task present in state.json with no directory
# -> exit 3 and NO directory created (the unbound-$2 defect would abort
#    the shell instead of returning cleanly).
# =====================================================================
scenario_2() {
  local root task_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 402, "project_name": "task_beta"}]'
  task_dir="$root/specs/402_task_beta"

  local out rc
  out=$(lock "$root" check 402 2>&1)
  rc=$?

  if [ "$rc" -ne 3 ]; then
    report "2: check on directoryless task creates nothing, exits 3" false "exit=$rc (expected 3); output: $out"
    return
  fi
  if [ -e "$task_dir" ]; then
    report "2: check on directoryless task creates nothing, exits 3" false "directory $task_dir was created"
    return
  fi
  report "2: check on directoryless task creates nothing, exits 3" true ""
}

# =====================================================================
# Scenario 3: heartbeat on the same -> exit 2, no directory created.
# =====================================================================
scenario_3() {
  local root task_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 403, "project_name": "task_gamma"}]'
  task_dir="$root/specs/403_task_gamma"

  local out rc
  out=$(lock "$root" heartbeat 403 sess_test_3 2>&1)
  rc=$?

  if [ "$rc" -ne 2 ]; then
    report "3: heartbeat on directoryless task creates nothing, exits 2" false "exit=$rc (expected 2); output: $out"
    return
  fi
  if [ -e "$task_dir" ]; then
    report "3: heartbeat on directoryless task creates nothing, exits 2" false "directory $task_dir was created"
    return
  fi
  report "3: heartbeat on directoryless task creates nothing, exits 2" true ""
}

# =====================================================================
# Scenario 4: release on the same -> exit 2, no directory created.
# =====================================================================
scenario_4() {
  local root task_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 404, "project_name": "task_delta"}]'
  task_dir="$root/specs/404_task_delta"

  local out rc
  out=$(lock "$root" release 404 sess_test_4 2>&1)
  rc=$?

  if [ "$rc" -ne 2 ]; then
    report "4: release on directoryless task creates nothing, exits 2" false "exit=$rc (expected 2); output: $out"
    return
  fi
  if [ -e "$task_dir" ]; then
    report "4: release on directoryless task creates nothing, exits 2" false "directory $task_dir was created"
    return
  fi
  report "4: release on directoryless task creates nothing, exits 2" true ""
}

# =====================================================================
# Scenario 5: acquire for a task number absent from state.json AND
# absent from disk -> exit 2, no directory created (the glob fallback
# must never create).
# =====================================================================
scenario_5() {
  local root
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[]'

  local out rc before after
  before=$(ls "$root/specs" 2>/dev/null | wc -l)
  out=$(lock "$root" acquire 405 plan sess_test_5 2>&1)
  rc=$?
  after=$(ls "$root/specs" 2>/dev/null | wc -l)

  if [ "$rc" -ne 2 ]; then
    report "5: acquire for unknown task creates nothing, exits 2" false "exit=$rc (expected 2); output: $out"
    return
  fi
  if [ "$before" != "$after" ]; then
    report "5: acquire for unknown task creates nothing, exits 2" false "specs/ entry count changed ($before -> $after)"
    return
  fi
  report "5: acquire for unknown task creates nothing, exits 2" true ""
}

# =====================================================================
# Scenario 6: slug drift. state.json says {NNN}_alpha while
# {NNN}_beta exists on disk -> acquire resolves and locks {NNN}_beta;
# {NNN}_alpha is not created.
# =====================================================================
scenario_6() {
  local root drifted_dir onDisk_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 406, "project_name": "task_c_alpha"}]'
  drifted_dir="$root/specs/406_task_c_alpha"
  onDisk_dir="$root/specs/406_task_c_beta"
  mkdir -p "$onDisk_dir"

  local out rc
  out=$(lock "$root" acquire 406 plan sess_test_6 2>&1)
  rc=$?

  if [ "$rc" -ne 0 ]; then
    report "6: slug drift resolves existing on-disk directory" false "exit=$rc (expected 0); output: $out"
    return
  fi
  if [ -e "$drifted_dir" ]; then
    report "6: slug drift resolves existing on-disk directory" false "state.json-derived $drifted_dir was created (should not exist)"
    return
  fi
  if [ ! -f "$onDisk_dir/.lock/holder.json" ]; then
    report "6: slug drift resolves existing on-disk directory" false "expected $onDisk_dir/.lock/holder.json to exist"
    return
  fi
  report "6: slug drift resolves existing on-disk directory" true ""
}

# =====================================================================
# Scenario 7: regression. acquire against a task whose directory
# already exists behaves exactly as before (exit 0, holder.json
# written, subdirectories not required to pre-exist).
# =====================================================================
scenario_7() {
  local root task_dir
  root=$(new_fixture)
  cleanup_roots+=("$root")
  write_state "$root" '[{"project_number": 407, "project_name": "task_epsilon"}]'
  task_dir="$root/specs/407_task_epsilon"
  mkdir -p "$task_dir"

  local out rc
  out=$(lock "$root" acquire 407 plan sess_test_7 2>&1)
  rc=$?

  if [ "$rc" -ne 0 ]; then
    report "7: acquire against pre-existing directory is unchanged" false "exit=$rc (expected 0); output: $out"
    return
  fi
  if [ ! -f "$task_dir/.lock/holder.json" ]; then
    report "7: acquire against pre-existing directory is unchanged" false "missing .lock/holder.json under $task_dir"
    return
  fi
  report "7: acquire against pre-existing directory is unchanged" true ""
}

scenario_1
scenario_2
scenario_3
scenario_4
scenario_5
scenario_6
scenario_7

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)) scenarios)"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
