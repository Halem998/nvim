#!/usr/bin/env bash
# reconcile-task-status.sh - Self-healing reconciliation for stuck tasks
#
# Detects tasks stuck in in-flight states (researching, planning, implementing, partial)
# when artifacts already exist on disk, then replays the missed postflight to promote
# their status. Addresses the failure mode where an agent writes artifacts but crashes
# before postflight runs.
#
# Usage:
#   .claude/scripts/reconcile-task-status.sh <task_number> <session_id> [--dry-run]
#
# Arguments:
#   task_number  - Task number (integer)
#   session_id   - Session identifier string
#   --dry-run    - Print what would be done without modifying state
#
# Artifact-to-phase mapping:
#   reports/*.md    -> research phase   (researching -> researched)
#   plans/*.md      -> planning phase   (planning -> planned)
#   summaries/*.md  -> implement phase  (implementing -> completed)
#   partial state   -> check handoff for continuation_context
#   plans/*.md      -> planning phase   (not_started -> planned)   [mtime-gated, see below]
#   handoffs/*.md   -> partial state    (not_started -> partial)   [mtime-gated, see below]
#
# Why the not_started mappings are mtime-gated:
#   A not_started task with artifacts on disk is ambiguous. It is either a crashed run whose
#   postflight was lost (promote it) or a task deliberately reset with its old artifacts left in
#   place (leave it alone). The Recover Mode in commands/task.md produces the second shape on
#   purpose: it moves an archived task's entire directory -- plans/, reports/, summaries/,
#   handoffs/ -- back into specs/, forces status="not_started", and stamps last_updated to the
#   recovery time in the same jq call. Artifact PRESENCE cannot tell the two apart; artifact
#   RECENCY can. A crashed run necessarily wrote its artifact after the last successful status
#   write, so artifact_mtime > last_updated. A recovered task's artifacts all predate the
#   recovery stamp, so last_updated > artifact_mtime. Promotion therefore requires a strictly
#   newer artifact (see artifact_newer_than_last_update below).
#
#   Do NOT "simplify" this into a bare artifact-presence check. This reconcile runs live and
#   unattended from the orchestrate entry path (no --dry-run, no human), so dropping the guard
#   would silently fast-forward every recovered task past the research or planning it was
#   recovered to redo.
#
# Exit codes:
#   0 - Success or no-op (nothing to reconcile, or reconciliation applied)
#   1 - Validation error (bad arguments or state.json missing)
#   2 - state.json read error

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Parse arguments ---
DRY_RUN=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

task_number="${POSITIONAL_ARGS[0]:-}"
session_id="${POSITIONAL_ARGS[1]:-}"

# --- Validation ---
if [[ -z "$task_number" || -z "$session_id" ]]; then
  echo "Usage: $0 <task_number> <session_id> [--dry-run]" >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Read current task status from state.json ---
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  "$STATE_FILE" 2>/dev/null) || {
  echo "Error: failed to read state.json for task $task_number" >&2
  exit 2
}

if [[ -z "$task_data" ]]; then
  # Task not found — no-op (not an error, task may have been archived)
  exit 0
fi

current_status=$(echo "$task_data" | jq -r '.status // "not_started"')
project_name=$(echo "$task_data" | jq -r '.project_name')

# --- Resolve task directory ---
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DIR="$PROJECT_ROOT/specs/${PADDED_NUM}_${project_name}"

# --- Helper: find latest artifact in a subdirectory ---
find_latest_artifact() {
  local subdir="$1"
  local artifact_dir="${TASK_DIR}/${subdir}"
  if [[ -d "$artifact_dir" ]]; then
    # `|| true`: under `set -e -o pipefail`, an existing-but-empty directory makes the
    # unexpanded `*.md` glob a literal nonexistent filename, so `ls` exits non-zero and
    # pipefail would abort the whole script even though `sort`/`tail` succeed on empty input.
    # An empty artifact directory is a legitimate no-artifact-yet state, not an error.
    ls -1 "${artifact_dir}/"*.md 2>/dev/null | sort -V | tail -1 || true
  fi
}

# --- Helper: check if artifact is already linked in state.json ---
artifact_already_linked() {
  local artifact_path="$1"
  local artifact_type="$2"
  # Normalize to relative path (specs/...)
  local rel_path="${artifact_path#$PROJECT_ROOT/}"
  jq -r --argjson num "$task_number" \
    '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | .path] | .[]' \
    "$STATE_FILE" 2>/dev/null | grep -qF "$rel_path" && return 0 || return 1
}

# --- Helper: link artifact in state.json and TODO.md ---
link_artifact() {
  local artifact_path="$1"
  local artifact_type="$2"    # report | plan | summary
  local artifact_summary="$3"

  # Normalize to relative path for state.json and TODO.md
  local rel_path="${artifact_path#$PROJECT_ROOT/}"

  if artifact_already_linked "$artifact_path" "$artifact_type"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Artifact already linked in state.json: $rel_path — skipping"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would link artifact in state.json: type=$artifact_type path=$rel_path"
  else
    mkdir -p "$PROJECT_ROOT/specs/tmp"
    # Step 1: Remove existing artifacts of same type (Issue #1132-safe pattern)
    jq --arg atype "$artifact_type" \
      --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
      "$STATE_FILE" > "$PROJECT_ROOT/specs/tmp/state.json" \
      && mv "$PROJECT_ROOT/specs/tmp/state.json" "$STATE_FILE"
    # Step 2: Add new artifact entry
    jq --arg path "$rel_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
       --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      "$STATE_FILE" > "$PROJECT_ROOT/specs/tmp/state.json" \
      && mv "$PROJECT_ROOT/specs/tmp/state.json" "$STATE_FILE"
    echo "[reconcile] Linked $artifact_type artifact in state.json: $rel_path"
  fi

  # Step 3: Regenerate TODO.md from state.json
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would regenerate TODO.md via generate-todo.sh"
  else
    "$SCRIPT_DIR/generate-todo.sh" || {
      echo "[reconcile] WARNING: generate-todo.sh failed for $rel_path (non-fatal)" >&2
    }
  fi
}

# --- Helper: does a handoff permit promotion to this phase's success status? ---
# Generalizes the contract the `partial` branch below already implements: if the handoff file is
# absent, permit promotion (preserves pre-existing behavior for tasks with no handoff); if
# present and its `.status` matches the expected success value for this phase, permit; otherwise
# refuse. Returns 0 (permit) or 1 (refuse) via exit status.
handoff_permits_promotion() {
  local expected_status="$1"
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ ! -f "$handoff_file" ]]; then
    return 0
  fi
  local handoff_status
  handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
  [[ "$handoff_status" == "$expected_status" ]]
}

# --- Helper: read the handoff's status field (empty string if no handoff file) ---
handoff_status_value() {
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ -f "$handoff_file" ]]; then
    jq -r '.status // ""' "$handoff_file" 2>/dev/null
  fi
}

# --- Helper: is this artifact newer than the task's last recorded status write? ---
# The false-positive guard for the not_started branches (see the header's "Why the not_started
# mappings are mtime-gated" note). Returns 0 (permit) when the artifact's mtime is strictly
# greater than state.json's last_updated for this task, 1 (refuse) otherwise.
#
# Ties refuse, deliberately: a directory move can land an artifact's mtime on the same whole
# second as the recovery stamp, and the two outcomes are not symmetric. Refusing a tie costs one
# re-run of /plan; permitting one silently skips planning on a task that was reopened to redo it.
#
# Fails OPEN (0) when last_updated is missing or unparseable -- the same "signal absent ->
# permit" philosophy handoff_permits_promotion above already uses, so a task predating the
# last_updated field behaves as it did before. Fails CLOSED (1) when the artifact cannot be
# stat'd, which should not happen: callers only reach here after find_latest_artifact (or an
# equivalent listing) already located the file, so an unreadable path means something is wrong
# and refusing is correct.
#
# stat and date both use the GNU-then-BSD fallback idiom already established elsewhere in this
# codebase (scripts/claude-cleanup.sh for stat, scripts/task-lock.sh for date) rather than
# assuming GNU. A guard that silently degrades to a no-op on a non-Linux host would be worse
# than no guard, because it would look present in review while permitting every promotion.
artifact_newer_than_last_update() {
  local artifact_path="$1"
  local artifact_mtime last_updated_raw last_updated_epoch

  artifact_mtime=$(stat -c %Y "$artifact_path" 2>/dev/null \
    || stat -f %m "$artifact_path" 2>/dev/null) || return 1
  [[ -n "$artifact_mtime" ]] || return 1

  last_updated_raw=$(echo "$task_data" | jq -r '.last_updated // empty' 2>/dev/null)
  [[ -n "$last_updated_raw" ]] || return 0

  last_updated_epoch=$(date -u -d "$last_updated_raw" +%s 2>/dev/null \
    || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_updated_raw" +%s 2>/dev/null) || return 0
  [[ -n "$last_updated_epoch" ]] || return 0

  [[ "$artifact_mtime" -gt "$last_updated_epoch" ]]
}

# --- Helper: record a refused promotion using the sanctioned partial/blocked postflight
# termini — but only when the handoff status maps unambiguously onto one of them. Any other
# handoff status (e.g. "failed", or an empty/missing status field) is already surfaced by the
# caller's refusal line; this is a plain no-op for those cases — never invent a status.
record_refused_promotion() {
  local handoff_status="$1"
  case "$handoff_status" in
    blocked|partial)
      local dry_run_flag=()
      if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag=(--dry-run)
      fi
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "$handoff_status" "$session_id" "${dry_run_flag[@]}"
      ;;
    *)
      : # ambiguous mapping — no recording, the refusal line above is the whole report
      ;;
  esac
}

# --- Helper: map a state.json task-level status to its plan-level marker equivalent. ---
# Plan-level Status uses a narrower 6-marker vocabulary than the full task-level vocabulary (see
# status-markers.md's "Plan-level vs. phase-level markers" section): a plan document is
# not_started, implementing, partial, blocked, abandoned, or completed -- it does not track
# research/planning sub-phases of its own, so statuses like "researching" or "planning" have no
# plan-level equivalent. Echoes the equivalent marker and returns 0 when one exists; returns 1
# (nothing echoed) otherwise.
plan_level_equivalent() {
  local state_status="$1"
  case "$state_status" in
    not_started) echo "NOT STARTED" ;;
    implementing) echo "IMPLEMENTING" ;;
    partial) echo "PARTIAL" ;;
    blocked) echo "BLOCKED" ;;
    abandoned) echo "ABANDONED" ;;
    completed) echo "COMPLETED" ;;
    *) return 1 ;;
  esac
}

# --- Report-only plan-vs-state.json divergence check (optional/stretch scope). Never repairs
# either direction -- unlike "artifact exists, therefore promote", a plan-vs-state mismatch has
# no unambiguous correct side. Compares only the plan-level `- **Status**:` field, never
# phase-heading markers, which are a distinct, narrower grain. No-ops silently (exit status
# unaffected) when the current status has no plan-level equivalent or no plan file exists yet.
check_plan_state_divergence() {
  local expected_plan_status
  expected_plan_status=$(plan_level_equivalent "$current_status") || return 0

  local plan_file
  plan_file=$(find_latest_artifact "plans")
  if [[ -z "$plan_file" ]]; then
    return 0
  fi

  local plan_status
  plan_status=$(grep -m1 '^- \*\*Status\*\*:' "$plan_file" 2>/dev/null | \
    sed -E 's/^- \*\*Status\*\*:\s*\[?([A-Z ]+)\]?.*/\1/')
  if [[ -z "$plan_status" ]]; then
    return 0
  fi

  if [[ "$plan_status" != "$expected_plan_status" ]]; then
    echo "[reconcile] WARNING: task $task_number plan status=$plan_status, state.json status=$current_status"
  fi
}

# --- Main reconciliation dispatch ---
case "$current_status" in

  researching)
    check_plan_state_divergence
    # Check for completed research artifact
    report_file=$(find_latest_artifact "reports")
    if [[ -z "$report_file" ]]; then
      # No artifact — genuine in-progress, no-op
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=researching, no report artifact found — no-op"
      fi
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "researched"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=researching, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    report_basename=$(basename "$report_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=researching, found report $report_basename"
      echo "[reconcile] Would promote: researching -> researched via postflight research"
      link_artifact "$report_file" "report" "Research report: $report_basename"
    else
      echo "[reconcile] Task $task_number: status=researching but report exists ($report_basename) — replaying postflight"
      link_artifact "$report_file" "report" "Research report: $report_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "research" "$session_id"
      echo "[reconcile] Task $task_number: promoted researching -> researched"
    fi
    ;;

  planning)
    check_plan_state_divergence
    # Check for completed plan artifact
    plan_file=$(find_latest_artifact "plans")
    if [[ -z "$plan_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=planning, no plan artifact found — no-op"
      fi
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "planned"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=planning, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    plan_basename=$(basename "$plan_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=planning, found plan $plan_basename"
      echo "[reconcile] Would promote: planning -> planned via postflight plan"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
    else
      echo "[reconcile] Task $task_number: status=planning but plan exists ($plan_basename) — replaying postflight"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id"
      echo "[reconcile] Task $task_number: promoted planning -> planned"
    fi
    ;;

  implementing)
    check_plan_state_divergence
    # Check for completed summary artifact
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=implementing, no summary artifact found — no-op"
      fi
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "implemented"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=implementing, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=implementing, found summary $summary_basename"
      echo "[reconcile] Would promote: implementing -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=implementing but summary exists ($summary_basename) — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted implementing -> completed"
    fi
    ;;

  partial)
    check_plan_state_divergence
    # For partial state, check if there's a summary (stuck after final phase)
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=partial, no summary artifact found — no-op"
      fi
      exit 0
    fi

    # Only promote partial->completed if the handoff indicates "implemented" status
    handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
    if [[ -f "$handoff_file" ]]; then
      handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
      if [[ "$handoff_status" != "implemented" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[reconcile] Task $task_number: status=partial, handoff status=$handoff_status (not 'implemented') — no-op"
        fi
        exit 0
      fi
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=partial, found summary $summary_basename with implemented handoff"
      echo "[reconcile] Would promote: partial -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=partial but summary exists ($summary_basename) with implemented handoff — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted partial -> completed"
    fi
    ;;

  not_started)
    check_plan_state_divergence
    # Case (a): a plan exists and postdates the last recorded status write. The planning
    # postflight was lost mid-run -- replay it and promote not_started -> planned.
    plan_file=$(find_latest_artifact "plans")
    if [[ -n "$plan_file" ]] && artifact_newer_than_last_update "$plan_file"; then
      # Handoff-aware promotion guard (see handoff_permits_promotion above). Note this guard is
      # near-pass-through in standard mode -- .orchestrator-handoff.json is written only by
      # hard-mode dispatch paths -- so it is NOT what disambiguates a recovered task from a
      # stranded one. That is artifact_newer_than_last_update's job, above.
      if ! handoff_permits_promotion "planned"; then
        handoff_status=$(handoff_status_value)
        echo "[reconcile] Task $task_number: status=not_started, plan exists but handoff status=$handoff_status — refusing promotion"
        record_refused_promotion "$handoff_status"
        exit 0
      fi

      plan_basename=$(basename "$plan_file")
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=not_started, found plan $plan_basename"
        echo "[reconcile] Would promote: not_started -> planned via postflight plan"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      else
        echo "[reconcile] Task $task_number: status=not_started but plan exists ($plan_basename) — replaying postflight"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
        "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id"
        echo "[reconcile] Task $task_number: promoted not_started -> planned"
      fi
      exit 0
    fi

    # Case (b), defense in depth: no fresh plan, but handoffs/ holds a phase handoff that
    # postdates the last status write, so an implementation run started and died. Promote to
    # `partial`, never `implementing`: `implementing` asserts work is underway right now, while a
    # cold reconcile pass finding a stalled run is exactly status-markers.md's "implementation
    # partially completed (can resume)". `partial` is also what record_refused_promotion and the
    # `partial` branch above already treat as the resting state for this situation, and the
    # permissive-transition rule lets /implement pick it up unchanged on the next dispatch.
    handoff_dir="${TASK_DIR}/handoffs"
    if [[ -d "$handoff_dir" ]]; then
      # `|| true` for the same pipefail reason documented on find_latest_artifact above: an
      # existing-but-empty directory leaves the glob unexpanded and makes `ls` exit non-zero.
      # `ls -1t` rather than the `sort -V` used there, because the question here is strictly
      # "is any handoff newer than last_updated" -- an mtime question, not a filename-order one.
      latest_handoff=$(ls -1t "${handoff_dir}/"*.md 2>/dev/null | head -1 || true)
      if [[ -n "$latest_handoff" ]] && artifact_newer_than_last_update "$latest_handoff"; then
        if ! handoff_permits_promotion "partial"; then
          handoff_status=$(handoff_status_value)
          echo "[reconcile] Task $task_number: status=not_started, handoffs/ non-empty but handoff status=$handoff_status — refusing promotion"
          record_refused_promotion "$handoff_status"
          exit 0
        fi

        handoff_basename=$(basename "$latest_handoff")
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[reconcile] Task $task_number: status=not_started, found phase handoff $handoff_basename"
          echo "[reconcile] Would promote: not_started -> partial via postflight partial"
        else
          echo "[reconcile] Task $task_number: status=not_started but phase handoff exists ($handoff_basename) — replaying postflight"
          "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "partial" "$session_id"
          echo "[reconcile] Task $task_number: promoted not_started -> partial"
        fi
        exit 0
      fi
    fi

    # Nothing newer than last_updated: either a genuinely new task, or one deliberately reset
    # (Recover Mode in commands/task.md) with its old artifacts intact. not_started is the
    # correct resting state in both cases -- no-op.
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=not_started, no artifact newer than last_updated — no-op"
    fi
    ;;

  *)
    # All other statuses (researched, planned, completed, blocked, abandoned, expanded) are
    # either terminal or already at a stable state — no-op
    exit 0
    ;;
esac

exit 0
