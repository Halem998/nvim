#!/usr/bin/env bash
# test-dry-run-report.sh — deterministic fixture regression suite for
# agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh.
#
# Builds a throwaway scratch deploy tree ($(mktemp -d)/proj/.claude/scripts/) so the report
# script's transitive deploy-root-guard.sh dependencies are satisfied without ever touching this
# repository's real .claude/ directory. The scratch tree is removed on exit via trap, success or
# failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"
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
  cp "$CORE_SCRIPTS/orchestrate-dry-run-report.sh" "$proj_dir/.claude/scripts/"
  cp "$CORE_SCRIPTS/orchestrate-batch-admit.sh" "$proj_dir/.claude/scripts/"
  cp "$CORE_SCRIPTS/orchestrate-triage-classify.sh" "$proj_dir/.claude/scripts/"
  cp "$CORE_SCRIPTS/task-lock.sh" "$proj_dir/.claude/scripts/"
  cp "$CORE_SCRIPTS/deploy-root-guard.sh" "$proj_dir/.claude/scripts/"
  cp "$1" "$proj_dir/specs/state.json"

  # Seed a task directory for EVERY fixture task_number so task-lock.sh check can resolve a
  # task_dir (a missing task_dir surfaces as check's own exit-3 usage error, which would be
  # mistaken for a genuinely degraded lock check rather than absent test scaffolding).
  for entry in \
    "950:clean_admit_a" "951:clean_admit_b" "952:cross_batch_collision_candidate" \
    "953:out_of_batch_predecessor_candidate" "954:partial_blockers_no_continuation" \
    "955:partial_neither" "956:partial_with_continuation" "957:terminal_task" \
    "958:lock_held_by_other_session" "959:lock_held_by_self_session" "960:lock_held_stale" \
    "961:trim_extra_a" "962:trim_extra_b" "963:in_batch_dependent" \
    "964:blocked_task" "965:researching_task" "966:unknown_status_task" \
    "970:outside_collision_partner" "971:outside_predecessor"; do
    num="${entry%%:*}"; name="${entry#*:}"
    mkdir -p "$proj_dir/specs/${num}_${name}"
  done

  cp "$HANDOFF_DIR/954-handoff.json" "$proj_dir/specs/954_partial_blockers_no_continuation/.orchestrator-handoff.json"
  cp "$HANDOFF_DIR/955-handoff.json" "$proj_dir/specs/955_partial_neither/.orchestrator-handoff.json"
  cp "$HANDOFF_DIR/956-handoff.json" "$proj_dir/specs/956_partial_with_continuation/.orchestrator-handoff.json"

  echo "$proj_dir"
}

write_lock() {
  # $1 = proj_dir, $2 = task_dir_name (NNN_slug), $3 = session_id, $4 = heartbeat_at (ISO8601)
  local proj_dir="$1" task_dir_name="$2" session_id="$3" heartbeat_at="$4"
  local lock_dir="$proj_dir/specs/$task_dir_name/.lock"
  mkdir -p "$lock_dir"
  jq -n --arg s "$session_id" --arg h "$heartbeat_at" \
    '{session_id: $s, task_number: 0, operation: "research", acquired_at: $h, heartbeat_at: $h, command: "test fixture"}' \
    > "$lock_dir/holder.json"
}

run_report() {
  # $1 = proj_dir, remaining = report args
  local proj_dir="$1"
  shift
  (cd "$proj_dir" && bash .claude/scripts/orchestrate-dry-run-report.sh "$@")
}

section_of() {
  # $1 = full report text, $2 = section marker (e.g. "-- Excluded --")
  # Prints ONLY the lines strictly between $2 and the next "-- " marker (or EOF).
  printf '%s\n' "$1" | awk -v marker="$2" '
    $0 == marker { found=1; next }
    found && /^-- .* --$/ { exit }
    found { print }
  '
}

CORE_PROJ="$(new_scratch_deploy "$FIXTURE")"

# ============================================================
# 1. All six sections present on every run (core batch: clean pair + collision +
#    out-of-batch predecessor + 3 partial variants + terminal + in-batch dependent)
# ============================================================
core_out="$(run_report "$CORE_PROJ" 950 951 952 953 954 955 956 957 963)"
core_ec=$?

sections_ok=true
for section in "-- Header --" "-- Checks run --" "-- Admitted --" "-- Excluded --" "-- Notes --" "-- Recommended split --"; do
  if ! printf '%s\n' "$core_out" | grep -qF -- "$section"; then
    sections_ok=false
    echo "  missing section: $section"
  fi
done
if [ "$sections_ok" = true ] && [ "$core_ec" -eq 0 ]; then
  pass "1. all six sections present, exit 0"
else
  fail "1. all six sections present, exit 0 (ec=$core_ec)"
fi

# ============================================================
# 2. Cross-batch collision exclusion names the colliding task and overlapping path (952 vs 970)
# ============================================================
excluded_section="$(section_of "$core_out" "-- Excluded --")"
admitted_section="$(section_of "$core_out" "-- Admitted --")"

if printf '%s\n' "$excluded_section" | grep -q "#952.*970.*shared-conflict.md"; then
  pass "2. cross-batch collision exclusion names colliding task #970 and overlapping path"
else
  fail "2. cross-batch collision exclusion: $excluded_section"
fi

# ============================================================
# 3. Out-of-batch unmet predecessor excludes (953 depends on out-of-batch 971)
# ============================================================
if printf '%s\n' "$excluded_section" | grep -q "#953.*971"; then
  pass "3. out-of-batch unmet predecessor (953 -> 971) is excluded"
else
  fail "3. out-of-batch unmet predecessor: $excluded_section"
fi

# ============================================================
# 4. In-batch unmet predecessor (963 -> 950) only affects wave order, is NOT excluded
# ============================================================
if printf '%s\n' "$admitted_section" | grep -q "#963" \
   && ! printf '%s\n' "$excluded_section" | grep -q "#963"; then
  pass "4. in-batch unmet predecessor (963 -> 950) admitted (wave-deferred), not excluded"
else
  fail "4. in-batch unmet predecessor: admitted=[$admitted_section] excluded=[$excluded_section]"
fi

# ============================================================
# 5. partial-with-blockers (954) is excluded as needs-human
# ============================================================
if printf '%s\n' "$excluded_section" | grep -q "#954.*needs_human"; then
  pass "5. partial-with-blockers (954) excluded as needs_human"
else
  fail "5. partial-with-blockers exclusion: $excluded_section"
fi

# ============================================================
# 6. partial-with-continuation (956) is admitted (dispatch=implement)
# ============================================================
if printf '%s\n' "$admitted_section" | grep -q "#956.*dispatch=implement"; then
  pass "6. partial-with-continuation (956) admitted with dispatch=implement"
else
  fail "6. partial-with-continuation: $admitted_section"
fi

# ============================================================
# 7. Terminal task (957) is reported as SKIPPED, not admitted or excluded-with-reason
# ============================================================
if printf '%s\n' "$excluded_section" | grep -q "#957.*SKIPPED.*terminal"; then
  pass "7. terminal task (957) reported as SKIPPED with terminal status reason"
else
  fail "7. terminal task reporting: $excluded_section"
fi

# ============================================================
# 8. Clean batch (950, 951 alone) still prints the explicit "0 excluded" line
# ============================================================
clean_out="$(run_report "$CORE_PROJ" 950 951)"
if printf '%s\n' "$clean_out" | grep -q "0 excluded (all 2 validated candidates admitted)"; then
  pass "8. clean batch prints explicit '0 excluded' line"
else
  fail "8. clean batch 0-excluded line: $(printf '%s\n' "$clean_out" | sed -n '/-- Excluded --/,/-- Notes --/p')"
fi

# ============================================================
# 9. Lock scenarios: held-fresh-other excludes, held-fresh-self (matching --session) does not,
#    held-stale is a Note not an exclusion.
# ============================================================
LOCK_PROJ="$(new_scratch_deploy "$FIXTURE")"
write_lock "$LOCK_PROJ" "958_lock_held_by_other_session" "sess_other_1234" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_lock "$LOCK_PROJ" "959_lock_held_by_self_session" "sess_self_9999" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# held-stale: heartbeat far in the past (TASK_LOCK_STALE_MIN default 30 min)
stale_ts=$(date -u -d "@$(( $(date -u +%s) - 3600 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -j -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
write_lock "$LOCK_PROJ" "960_lock_held_stale" "sess_stale_0000" "$stale_ts"

lock_out="$(run_report "$LOCK_PROJ" --session sess_self_9999 958 959 960)"

lock_excluded_section="$(section_of "$lock_out" "-- Excluded --")"
lock_admitted_section="$(section_of "$lock_out" "-- Admitted --")"
lock_notes_section="$(section_of "$lock_out" "-- Notes --")"

lock_ok=true
printf '%s\n' "$lock_excluded_section" | grep -q "#958.*lock held by another session" || { lock_ok=false; echo "  958 should be excluded for foreign lock"; }
printf '%s\n' "$lock_excluded_section" | grep -q "#959" && { lock_ok=false; echo "  959 should NOT be excluded (self-held via --session)"; }
printf '%s\n' "$lock_admitted_section" | grep -q "#959" || { lock_ok=false; echo "  959 should be admitted (self-held)"; }
printf '%s\n' "$lock_excluded_section" | grep -q "#960" && { lock_ok=false; echo "  960 should NOT be excluded (held-stale is informational)"; }
printf '%s\n' "$lock_notes_section" | grep -qi "held-stale" || { lock_ok=false; echo "  960's held-stale state should appear in Notes"; }

if [ "$lock_ok" = true ]; then
  pass "9. lock scenarios: foreign-fresh excludes, self-held (matching --session) admits, held-stale is a note only"
else
  fail "9. lock scenarios"
fi

# ============================================================
# 10. MAX_TASKS trim is reported explicitly (9 validated non-terminal candidates)
# ============================================================
trim_out="$(run_report "$CORE_PROJ" 950 951 952 953 954 955 956 961 962)"
if printf '%s\n' "$trim_out" | grep -qi "MAX_TASKS=8"; then
  pass "10. MAX_TASKS trim reported explicitly for a 9-candidate batch"
else
  fail "10. MAX_TASKS trim not reported: $(printf '%s\n' "$trim_out" | sed -n '/-- Notes --/,/-- Recommended split --/p')"
fi

# ============================================================
# 11. Wave numbers match a hand-computed Kahn ordering (950 wave 0, 963 depends on 950 -> wave 1)
# ============================================================
wave_out="$(run_report "$CORE_PROJ" 950 963)"
wave_admitted_section="$(section_of "$wave_out" "-- Admitted --")"
if printf '%s\n' "$wave_admitted_section" | grep -q "#950.*wave=0" \
   && printf '%s\n' "$wave_admitted_section" | grep -q "#963.*wave=1"; then
  pass "11. wave numbers match hand-computed Kahn ordering (950 wave 0, 963 wave 1)"
else
  fail "11. wave ordering: $wave_admitted_section"
fi

# ============================================================
# 12. Degradation assertion: with state.json removed, the report exits 2 loudly
# ============================================================
DEGRADED_PROJ="$(new_scratch_deploy "$FIXTURE")"
rm -f "$DEGRADED_PROJ/specs/state.json"
degraded_stderr_file=$(mktemp)
degraded_out=$( (cd "$DEGRADED_PROJ" && bash .claude/scripts/orchestrate-dry-run-report.sh 950 2>"$degraded_stderr_file") )
degraded_ec=$?
degraded_stderr=$(cat "$degraded_stderr_file")
rm -f "$degraded_stderr_file"
if [ "$degraded_ec" -eq 2 ] && [ -z "$degraded_out" ] && [ -n "$degraded_stderr" ]; then
  pass "12. missing state.json: exit 2, empty stdout, non-empty stderr (no misleading clean report)"
else
  fail "12. missing state.json: exit=$degraded_ec stdout=[$degraded_out] stderr=[$degraded_stderr]"
fi

# ============================================================
# 13. Read-only assertion: sha256sum of every file in scratch specs/ is unchanged, no .lock/
#     directory created for any candidate that did not already have one.
# ============================================================
READONLY_PROJ="$(new_scratch_deploy "$FIXTURE")"
before_sum=$(find "$READONLY_PROJ/specs" -type f -exec sha256sum {} \; | sort)
before_lock_dirs=$(find "$READONLY_PROJ/specs" -type d -name ".lock" | sort)
run_report "$READONLY_PROJ" 950 951 952 953 954 955 956 957 >/dev/null
after_sum=$(find "$READONLY_PROJ/specs" -type f -exec sha256sum {} \; | sort)
after_lock_dirs=$(find "$READONLY_PROJ/specs" -type d -name ".lock" | sort)
if [ "$before_sum" = "$after_sum" ] && [ "$before_lock_dirs" = "$after_lock_dirs" ]; then
  pass "13. read-only: specs/ tree and .lock/ directories unchanged across a run"
else
  fail "13. read-only: specs/ tree or .lock/ directories changed across a run"
fi

# ============================================================
# 14. Forbidden-call grep: only the header comment mentions acquire/status-write helpers
# ============================================================
if grep -n 'task-lock.sh acquire\|update-task-status\|generate-todo\|skill_preflight\|skill_postflight' \
     "$CORE_SCRIPTS/orchestrate-dry-run-report.sh" | grep -qv '^\s*[0-9]*:#'; then
  fail "14. forbidden-call grep found a non-comment call site"
else
  pass "14. forbidden-call grep: only header comments reference acquire/status-write helpers"
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
