#!/usr/bin/env bash
# orchestrate-dry-run-report.sh — Read-only /orchestrate --dry-run admission report composer.
#
# Purpose: print the same admission analysis a live `/orchestrate` invocation would perform —
# file_scope collisions, lock contention, unmet predecessors, and handoff-triage routing — as a
# report, instead of dispatching anything. This is the dry-run-ONLY composer; the live dispatch
# path (Stage MT-4 in skills/skill-orchestrate/SKILL.md) never calls this script, only the shared
# classifier (`orchestrate-triage-classify.sh`) and the shared admission predicate
# (`orchestrate-batch-admit.sh`) this script also calls — "one code path, two consumers" for both
# of the read-only primitives, so the report cannot silently drift from live behavior.
#
# Usage:
#   orchestrate-dry-run-report.sh [--session <session_id>] <task_number> [<task_number> ...]
#
# `--session` is optional. When supplied, a lock held by that SAME session is never reported as
# contention (self-collision guard) — mirroring how a live `acquire` never blocks its own
# session's re-entry.
#
# Forbidden calls (never present as a call site in this script; only in this comment and header):
#   - task-lock.sh acquire / heartbeat / release — ONLY `task-lock.sh check` is ever invoked
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
# This script never writes state.json, never regenerates TODO.md, never creates a `.lock/`
# directory, and never invokes git. It reads specs/state.json and, via
# orchestrate-triage-classify.sh, each partial-status candidate's own
# .orchestrator-handoff.json — nothing else (Context Flatness Constraint).
#
# Composition (each read-only, called at most once per invocation over the validated set):
#   1. Batch validation — mirrors commands/orchestrate.md MULTI-TASK DISPATCH Step 1: not-found
#      and terminal-status candidates become reported skips, never silent drops.
#   2. MAX_TASKS=8 guard (verbatim from orchestrate.md Step 4) — a trim is reported explicitly,
#      never applied silently.
#   3. Dependency graph + Kahn's-algorithm wave assignment — mirrors orchestrate.md Steps 2-3,
#      intra-batch only. A circular batch is reported as a named error with an empty admitted
#      set, rather than aborting the whole report.
#   4. orchestrate-batch-admit.sh, called ONCE for the validated set with
#      --invocation-count set to the validated set's own size — cross-batch file_scope
#      collisions become exclusions; in-batch collisions become a wave-deferral note. A fourth,
#      self-modification dimension is layered on this SAME call (not a second invocation): a
#      candidate whose file_scope names an orchestrator-critical path becomes a distinct
#      exclusion (`defer_reason == "self_modifying"`, plain-language "deferred out of this
#      invocation — re-run it alone") rather than an ordinary collision exclusion; a solo
#      self-modifying admit is instead surfaced as a Note. See
#      docs/architecture/batch-admit-schema.md for the verdict fields this adds.
#   5. task-lock.sh check, called per validated candidate — a fresh lock held by a DIFFERENT
#      session is an exclusion; held by the SAME session (--session) is not; held-stale is an
#      informational note only, never an exclusion (a live acquire would override it).
#   6. Out-of-batch unmet predecessors (from dependencies[]) become exclusions; in-batch unmet
#      predecessors only affect wave placement (already handled by step 3).
#   7. orchestrate-triage-classify.sh, called ONCE for the validated set with
#      engine=single when exactly one task_number was given, engine=mt otherwise — the identical
#      `len(task_numbers)` test orchestrate.md STAGE 0 uses. `needs_human` becomes an exclusion;
#      `skip` becomes a reported skip; `research`/`plan`/`implement` become admitted, carrying the
#      phase that would be dispatched. `exit_partial` is a reserved verdict value not currently
#      emitted by the classifier (see its header); this reporter still excludes it defensively if
#      it is ever emitted, so an unexpected group value never falls through silently.
#
# Report sections, printed in this order, ALL of them UNCONDITIONALLY (never omitted, never
# collapsed, even when a section's content is empty):
#   1. Header            — invocation, engine + which precedence table it selects, candidate
#                           count, session id if supplied.
#   2. Checks run        — one line per check: "ran" or "SKIPPED (degraded: <reason>)".
#   3. Admitted          — task, status, computed wave, phase that would be dispatched.
#   4. Excluded          — task, reason code, structured detail; an explicit "0 excluded (all N
#                           candidates admitted)" line when empty.
#   5. Notes             — non-excluding informational findings (held-stale locks, in-batch wave
#                           deferrals, MAX_TASKS trim, out-of-batch dependency edges, circular
#                           dependency errors).
#   6. Recommended split — the same wave numbers the live dispatch would use ("Wave N: <tasks>");
#                           "batch of one — no split applicable" for a one-task batch.
#
# Exit codes:
#   0 - a report was printed (regardless of how many exclusions — verdicts are data, not errors,
#       matching orchestrate-batch-admit.sh's and orchestrate-triage-classify.sh's convention).
#   2 - usage error (no task numbers, a non-integer task number, jq missing) or unreadable
#       specs/state.json, or every candidate was not-found/terminal (nothing left to report on).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
MAX_TASKS=8

session_id=""
task_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session)
      session_id="${2:-}"
      shift 2 || shift
      ;;
    --session=*)
      session_id="${1#--session=}"
      shift
      ;;
    *)
      task_args+=("$1")
      shift
      ;;
  esac
done

if [ "${#task_args[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-dry-run-report.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "${task_args[@]}"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-dry-run-report.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-dry-run-report.sh: jq is not available; cannot compose report." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-dry-run-report.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 1: Batch validation (mirrors orchestrate.md MULTI-TASK DISPATCH Step 1)
# ---------------------------------------------------------------------------
declare -a input_order=("${task_args[@]}")
declare -A t_status=()
declare -A t_project=()
declare -A t_skip_reason=()
declare -A t_exclude_reason=()
declare -A t_phase=()
declare -A t_wave=()
declare -a validated_tasks=()
declare -a notes=()

for t in "${input_order[@]}"; do
  data=$(jq -c --argjson num "$t" '.active_projects[] | select(.project_number == $num)' "$STATE_FILE" 2>/dev/null | head -1)
  if [ -z "$data" ] || [ "$data" = "null" ]; then
    t_skip_reason[$t]="not found in state.json"
    continue
  fi
  status=$(echo "$data" | jq -r '.status // ""')
  project_name=$(echo "$data" | jq -r '.project_name // ""')
  t_status[$t]="$status"
  t_project[$t]="$project_name"
  case "$(echo "$status" | tr '[:upper:]' '[:lower:]')" in
    completed|abandoned|expanded)
      t_skip_reason[$t]="terminal status [$status]"
      continue
      ;;
  esac
  validated_tasks+=("$t")
done

if [ "${#validated_tasks[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-dry-run-report.sh: no validated tasks remain (all candidates not-found or terminal)." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2: MAX_TASKS guard (verbatim from orchestrate.md Step 4) — reported, never silent
# ---------------------------------------------------------------------------
validated_count=${#validated_tasks[@]}
if [ "$validated_count" -gt "$MAX_TASKS" ]; then
  trimmed=("${validated_tasks[@]:$MAX_TASKS}")
  for t in "${trimmed[@]}"; do
    t_skip_reason[$t]="trimmed by MAX_TASKS=$MAX_TASKS guard ($validated_count validated tasks exceed the guard; only the first $MAX_TASKS in input order are analyzed)"
  done
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
  notes+=("MAX_TASKS=$MAX_TASKS guard: $validated_count validated candidates exceeds the guard; only the first $MAX_TASKS (in input order) were analyzed, matching the live dispatch trim. Trimmed: ${trimmed[*]}")
fi

# ---------------------------------------------------------------------------
# Step 3: Dependency graph + Kahn's-algorithm wave assignment (intra-batch only)
# ---------------------------------------------------------------------------
declare -A predecessors=()
declare -A in_degree=()
for t in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$t" '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' "$STATE_FILE" 2>/dev/null)
  intra=()
  for d in $deps; do
    if [[ " ${validated_tasks[*]} " == *" $d "* ]]; then
      intra+=("$d")
    fi
  done
  predecessors[$t]="${intra[*]}"
  in_degree[$t]=${#intra[@]}
done

waves=()
circular=false
declare -a circular_tasks=()
remaining=("${validated_tasks[@]}")
wave_num=0
while [ ${#remaining[@]} -gt 0 ]; do
  ready=()
  next_remaining=()
  for t in "${remaining[@]}"; do
    if [ "${in_degree[$t]}" -eq 0 ]; then
      ready+=("$t")
      t_wave[$t]=$wave_num
    else
      next_remaining+=("$t")
    fi
  done

  if [ ${#ready[@]} -eq 0 ]; then
    circular=true
    circular_tasks=("${remaining[@]}")
    break
  fi

  waves+=("${ready[*]}")
  remaining=("${next_remaining[@]}")

  for completed in "${ready[@]}"; do
    for t in "${remaining[@]}"; do
      if [[ " ${predecessors[$t]} " == *" $completed "* ]]; then
        in_degree[$t]=$(( in_degree[$t] - 1 ))
      fi
    done
  done

  wave_num=$(( wave_num + 1 ))
done

if [ "$circular" = true ]; then
  notes+=("CIRCULAR DEPENDENCY ERROR: no wave could be assigned to tasks ${circular_tasks[*]} — an intra-batch dependency cycle exists among them. These tasks are excluded from the admitted set until the cycle is resolved manually.")
  for t in "${circular_tasks[@]}"; do
    t_exclude_reason[$t]="circular intra-batch dependency (cycle members: ${circular_tasks[*]})"
  done
fi

# ---------------------------------------------------------------------------
# Step 4: orchestrate-batch-admit.sh (called once for the validated set)
#
# --invocation-count is passed as the validated set's own size — the report's admitted/excluded
# analysis IS this invocation, so the invocation-scoped self-modification trigger (D3 in the
# originating plan) always sees the correct denominator here, unlike a live per-wave/per-cycle
# caller which must thread in a size from outside its own positional arguments.
#
# Self-modification handling (a fourth admission dimension layered on this same call, not a
# second script invocation): `defer_reason == "self_modifying"` becomes an EXCLUSION with a
# plain-language reason distinct from a file_scope_collision exclusion, so a reader does not
# mistake "orchestrator-critical, solo-only" for an ordinary wave/batch-composition conflict.
# `defer_reason == "file_scope_collision"` retains the exact pre-existing in_batch/cross_batch
# behavior below, byte-for-byte.
# ---------------------------------------------------------------------------
admit_checked=true
admit_degraded_reason=""
admit_output=""
self_mod_degraded=false
if [ "${#validated_tasks[@]}" -gt 0 ]; then
  admit_stderr_file=$(mktemp)
  admit_output=$(bash "$SCRIPT_DIR/orchestrate-batch-admit.sh" --invocation-count "${#validated_tasks[@]}" "${validated_tasks[@]}" 2>"$admit_stderr_file")
  admit_exit=$?
  admit_stderr=$(cat "$admit_stderr_file" 2>/dev/null)
  rm -f "$admit_stderr_file"
  if [ "$admit_exit" -ne 0 ]; then
    admit_checked=false
    admit_degraded_reason="orchestrate-batch-admit.sh exited $admit_exit: ${admit_stderr:-no stderr captured}"
  fi
fi

if [ "$admit_checked" = true ]; then
  for t in "${validated_tasks[@]}"; do
    verdict=$(printf '%s\n' "$admit_output" | jq -c --argjson tn "$t" 'select(.task_number == $tn)' 2>/dev/null | head -1)
    [ -z "$verdict" ] && continue
    # NOTE: `.self_modifying // "null"` would be WRONG here — jq's `//` treats a literal `false`
    # value as falsy too, so a perfectly valid (non-degraded) `self_modifying: false` verdict
    # would be misread as the degraded "null" case. Use `-c` (compact) with no `//` fallback so
    # the true/false/null token comes through exactly as emitted.
    self_mod=$(echo "$verdict" | jq -c '.self_modifying')
    if [ "$self_mod" = "null" ]; then
      self_mod_degraded=true
    fi
    decision=$(echo "$verdict" | jq -r '.decision // ""')
    if [ "$decision" = "admit" ]; then
      if [ "$self_mod" = "true" ]; then
        notes+=("Task #$t: admitted with self_modifying=true — this candidate's file_scope names an orchestrator-critical path. It is admitted only because this invocation carries a single candidate (solo run); alongside any sibling it would instead be excluded and deferred to a solo re-run.")
      fi
      continue
    fi
    [ "$decision" = "defer" ] || continue
    defer_reason=$(echo "$verdict" | jq -r '.defer_reason // ""')
    if [ "$defer_reason" = "self_modifying" ]; then
      crit_path=$(echo "$verdict" | jq -r '.critical_path // empty')
      crit_label=$(echo "$verdict" | jq -r '.critical_label // empty')
      reason="self-modification hazard: file_scope names orchestrator-critical path \"$crit_path\" ($crit_label) — deferred out of this invocation — re-run it alone (orchestrator-critical work runs solo only, never alongside sibling tasks)"
      t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }$reason"
      continue
    fi
    scope=$(echo "$verdict" | jq -r '.collision_scope // ""')
    coll_num=$(echo "$verdict" | jq -r '.colliding_task_number // empty')
    coll_status=$(echo "$verdict" | jq -r '.colliding_task_status // empty')
    ov_path=$(echo "$verdict" | jq -r '.overlapping_path // empty')
    if [ "$scope" = "cross_batch" ]; then
      reason="file_scope collision with out-of-batch task #$coll_num (status: $coll_status) at \"$ov_path\""
      t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }$reason"
    else
      notes+=("Task #$t: in-batch file_scope collision with #$coll_num at \"$ov_path\" — deferred to a later wave, not excluded.")
    fi
  done
fi

# ---------------------------------------------------------------------------
# Step 5: task-lock.sh check (per validated candidate; ONLY the check subcommand)
# ---------------------------------------------------------------------------
lock_checked=true
lock_degraded_tasks=()
for t in "${validated_tasks[@]}"; do
  lock_out=$(bash "$SCRIPT_DIR/task-lock.sh" check "$t" 2>/dev/null)
  lock_exit=$?
  case "$lock_exit" in
    0)
      : # free — no effect
      ;;
    1)
      holder_session=$(printf '%s' "$lock_out" | grep -oE 'session=[^ ]*' | cut -d= -f2-)
      if [ -n "$session_id" ] && [ "$holder_session" = "$session_id" ]; then
        notes+=("Task #$t: lock is held-fresh by the SUPPLIED --session ($session_id) — self-held, not an exclusion.")
      else
        t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }lock held by another session ($lock_out)"
      fi
      ;;
    2)
      notes+=("Task #$t: lock is held-stale ($lock_out) — informational only; a live acquire would override a stale lock, so this is never an exclusion.")
      ;;
    3)
      lock_degraded_tasks+=("$t")
      lock_checked=false
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 6: Out-of-batch unmet predecessors (intra-batch predecessors already
# handled by wave placement in Step 3)
# ---------------------------------------------------------------------------
for t in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$t" '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' "$STATE_FILE" 2>/dev/null)
  for d in $deps; do
    if [[ " ${validated_tasks[*]} " == *" $d "* ]]; then
      continue
    fi
    dep_data=$(jq -c --argjson num "$d" '.active_projects[] | select(.project_number == $num)' "$STATE_FILE" 2>/dev/null | head -1)
    [ -z "$dep_data" ] || [ "$dep_data" = "null" ] && continue
    dep_status=$(echo "$dep_data" | jq -r '.status // ""')
    case "$(echo "$dep_status" | tr '[:upper:]' '[:lower:]')" in
      completed|abandoned|expanded)
        continue
        ;;
    esac
    reason="unmet out-of-batch predecessor #$d (status: $dep_status, cross_batch)"
    t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }$reason"
    notes+=("Task #$t: out-of-batch dependency edge to #$d (status: $dep_status) — excluded, not merely deferred, because #$d is not part of this invocation's batch.")
  done
done

# ---------------------------------------------------------------------------
# Step 7: orchestrate-triage-classify.sh (called once; engine derived from
# len(task_numbers) — the identical test orchestrate.md STAGE 0 uses)
# ---------------------------------------------------------------------------
engine="mt"
if [ "${#validated_tasks[@]}" -eq 1 ]; then
  engine="single"
fi

triage_checked=true
triage_degraded_reason=""
triage_output=""
if [ "${#validated_tasks[@]}" -gt 0 ]; then
  triage_stderr_file=$(mktemp)
  triage_output=$(bash "$SCRIPT_DIR/orchestrate-triage-classify.sh" "$engine" "${validated_tasks[@]}" 2>"$triage_stderr_file")
  triage_exit=$?
  triage_stderr=$(cat "$triage_stderr_file" 2>/dev/null)
  rm -f "$triage_stderr_file"
  if [ "$triage_exit" -ne 0 ]; then
    triage_checked=false
    triage_degraded_reason="orchestrate-triage-classify.sh exited $triage_exit: ${triage_stderr:-no stderr captured}"
  fi
fi

if [ "$triage_checked" = true ]; then
  for t in "${validated_tasks[@]}"; do
    [ -n "${t_exclude_reason[$t]:-}" ] && trow_skip_exclude=true || trow_skip_exclude=false
    trow=$(printf '%s\n' "$triage_output" | jq -c --argjson tn "$t" 'select(.task_number == $tn)' 2>/dev/null | head -1)
    [ -z "$trow" ] && continue
    group=$(echo "$trow" | jq -r '.group // ""')
    case "$group" in
      needs_human)
        bc=$(echo "$trow" | jq -r '.blocker_count // 0')
        age=$(echo "$trow" | jq -r '.handoff_age_min // "null"')
        t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }handoff-triage needs_human (blocker_count=$bc, handoff_age_min=$age)"
        ;;
      exit_partial)
        t_exclude_reason[$t]="${t_exclude_reason[$t]:+${t_exclude_reason[$t]}; }handoff-triage exit_partial (reserved verdict value, not currently emitted by any classifier row; excluded defensively if it is ever emitted)"
        ;;
      skip)
        t_skip_reason[$t]="handoff-triage skip (status ${t_status[$t]:-unknown})"
        ;;
      research|plan|implement)
        t_phase[$t]="$group"
        ;;
      terminal)
        t_skip_reason[$t]="handoff-triage terminal (status ${t_status[$t]:-unknown})"
        ;;
    esac
  done
fi

# ---------------------------------------------------------------------------
# Compose admitted set: validated tasks minus skip-marked minus excluded
# ---------------------------------------------------------------------------
declare -a admitted_tasks=()
for t in "${validated_tasks[@]}"; do
  [ -n "${t_skip_reason[$t]:-}" ] && continue
  [ -n "${t_exclude_reason[$t]:-}" ] && continue
  admitted_tasks+=("$t")
done

# ===========================================================================
# Report output
# ===========================================================================
echo "=== /orchestrate --dry-run admission report ==="
echo ""
echo "-- Header --"
echo "Invocation: ${input_order[*]}"
echo "Engine: $engine ($( [ "$engine" = "single" ] && echo "single-task Stage 4 precedence" || echo "multi-task Stage MT-4 phase-grouping precedence" ))"
echo "Candidate count: ${#input_order[@]} (validated: ${#validated_tasks[@]})"
if [ -n "$session_id" ]; then
  echo "Session: $session_id"
fi
echo ""

echo "-- Checks run --"
echo "file_scope collision: $( [ "$admit_checked" = true ] && echo "ran" || echo "SKIPPED (degraded: $admit_degraded_reason)" )"
if [ "$admit_checked" = true ]; then
  echo "self-modification: $( [ "$self_mod_degraded" = true ] && echo "SKIPPED (degraded: orchestrator-critical-paths.json missing or unparseable — see orchestrate-batch-admit.sh stderr)" || echo "ran" )"
else
  echo "self-modification: SKIPPED (degraded: $admit_degraded_reason)"
fi
echo "lock contention: $( [ "$lock_checked" = true ] && echo "ran" || echo "SKIPPED (degraded: task-lock.sh check exit 3 for: ${lock_degraded_tasks[*]})" )"
echo "predecessor: ran"
echo "handoff triage: $( [ "$triage_checked" = true ] && echo "ran" || echo "SKIPPED (degraded: $triage_degraded_reason)" )"
echo ""

echo "-- Admitted --"
if [ "${#admitted_tasks[@]}" -eq 0 ]; then
  echo "0 admitted."
else
  for t in "${admitted_tasks[@]}"; do
    wave="${t_wave[$t]:-unassigned}"
    phase="${t_phase[$t]:-implement}"
    echo "#$t  status=${t_status[$t]:-unknown}  wave=$wave  dispatch=$phase"
  done
fi
echo ""

echo "-- Excluded --"
excluded_count=0
for t in "${validated_tasks[@]}"; do
  [ -n "${t_exclude_reason[$t]:-}" ] || continue
  excluded_count=$((excluded_count + 1))
  echo "#$t  reason: ${t_exclude_reason[$t]}"
done
for t in "${input_order[@]}"; do
  [ -n "${t_skip_reason[$t]:-}" ] || continue
  echo "#$t  SKIPPED: ${t_skip_reason[$t]}"
done
if [ "$excluded_count" -eq 0 ]; then
  echo "0 excluded (all ${#validated_tasks[@]} validated candidates admitted)"
fi
echo ""

echo "-- Notes --"
if [ "${#notes[@]}" -eq 0 ]; then
  echo "(none)"
else
  for n in "${notes[@]}"; do
    echo "- $n"
  done
fi
echo ""

echo "-- Recommended split --"
if [ "${#admitted_tasks[@]}" -eq 0 ]; then
  echo "no admitted tasks — nothing to split"
elif [ "${#admitted_tasks[@]}" -eq 1 ]; then
  echo "batch of one — no split applicable"
else
  for i in "${!waves[@]}"; do
    wave_tasks_str="${waves[$i]}"
    admitted_in_wave=()
    for w in $wave_tasks_str; do
      for a in "${admitted_tasks[@]}"; do
        if [ "$a" = "$w" ]; then
          admitted_in_wave+=("$a")
        fi
      done
    done
    [ "${#admitted_in_wave[@]}" -eq 0 ] && continue
    echo "Wave $i: ${admitted_in_wave[*]}"
  done
fi

exit 0
