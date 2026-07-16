#!/usr/bin/env bash
# update-task-status.sh - Centralized task status update script
#
# Updates task status atomically across:
#   1. state.json (status field, timestamps, session_id)
#   2. TODO.md (regenerated from state.json via generate-todo.sh)
#   3. Plan file (optional, via update-plan-status.sh)
#
# Usage:
#   .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready]
#
# Arguments:
#   operation     - "preflight" or "postflight"
#   task_number   - Task number (integer)
#   target_status - "research", "plan", "implement", "pr_ready", "partial", or "blocked"
#                    (pr_ready is reserved for task_type == "pr" unless --allow-pr-ready is
#                    passed; partial/blocked are postflight-only task-level termini -- see
#                    map_status() below for the preflight rejection)
#   session_id    - Session identifier string
#
# Exit codes:
#   0 - Success or no-op (already at target status)
#   1 - Validation error (bad arguments)
#   2 - state.json update failed
#   3 - plan file update failed after state.json was written, on implement postflight only
#       (retry after fixing the plan file; the state.json write is idempotent and will no-op
#       on retry, so the plan/phase updates re-fire and the retry is genuinely effective)

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TMP_DIR="$PROJECT_ROOT/specs/tmp"

# --- specs/.scope-lock mutex around the state.json read-modify-write + TODO.md regen below ---
# Brackets the same critical section orchestrator-postflight.sh's Stages 7-8a bracket protects
# (see .claude/context/patterns/task-lock.md's scope-acquire/scope-release section and
# .claude/context/standards/git-staging-scope.md's state-write hazard note) so this script's
# standalone callers (reconcile-task-status.sh, manage-topics.sh, command-gate-out.sh,
# skill-base.sh, and SKILL.md call sites) get the same serialization against concurrent
# state.json writers that postflight's own inline path gets.
#
# The specs/.scope-lock mutex is NOT reentrant. When SCOPE_MUTEX_HELD=1 is already exported by an
# outer holder (e.g. this script invoked as a Stage 7 child of orchestrator-postflight.sh, which
# acquires the same mutex before calling this script), acquire/release below are skipped
# entirely and this script runs as a guest inside the outer holder's critical section — a nested
# acquire here would otherwise self-deadlock the outer holder for 5s and then fail closed on
# every single postflight run.
STATE_MUTEX_TOKEN=""
STATE_MUTEX_OWNED_HERE=false

acquire_state_mutex() {
  # Respect the existing --dry-run path: nothing is written, so nothing needs serializing.
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  if [[ -n "${SCOPE_MUTEX_HELD:-}" ]]; then
    echo "Note: an outer holder already owns the specs/.scope-lock mutex (SCOPE_MUTEX_HELD=1 inherited); running as guest, no nested acquire." >&2
    return 0
  fi
  local token
  if ! token=$("$SCRIPT_DIR/task-lock.sh" scope-acquire "$session_id"); then
    # Mutex is fail-closed as a lock (never silently double-held), but this script's own
    # non-blocking character is preserved: a timeout logs loudly and proceeds unserialized
    # rather than aborting the status update.
    echo "WARNING: failed to acquire specs/.scope-lock mutex for task ${task_number}'s status update; proceeding unserialized (non-blocking)." >&2
    return 0
  fi
  STATE_MUTEX_TOKEN="$token"
  STATE_MUTEX_OWNED_HERE=true
  export SCOPE_MUTEX_HELD=1
  return 0
}

release_state_mutex() {
  if [[ "$STATE_MUTEX_OWNED_HERE" == "true" ]]; then
    "$SCRIPT_DIR/task-lock.sh" scope-release "$STATE_MUTEX_TOKEN" >&2 || true
    STATE_MUTEX_OWNED_HERE=false
    unset SCOPE_MUTEX_HELD
  fi
}

# --- Cleanup trap ---
# Extended (not duplicated) to also release the state mutex on any exit path — including an
# early `set -e` abort mid-critical-section — so a forced early failure never leaves the mutex
# held. release_state_mutex is idempotent (guarded by STATE_MUTEX_OWNED_HERE), so it is safe to
# call again after the explicit release below has already fired.
cleanup() {
  rm -f "$TMP_DIR/state.json.tmp" 2>/dev/null || true
  release_state_mutex
}
trap cleanup EXIT

# --- Parse arguments ---
DRY_RUN=false
ALLOW_PR_READY=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --allow-pr-ready) ALLOW_PR_READY=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

operation="${POSITIONAL_ARGS[0]:-}"
task_number="${POSITIONAL_ARGS[1]:-}"
target_status="${POSITIONAL_ARGS[2]:-}"
session_id="${POSITIONAL_ARGS[3]:-}"

# --- Validation ---
if [[ -z "$operation" || -z "$task_number" || -z "$target_status" || -z "$session_id" ]]; then
  echo "Usage: $0 <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready]" >&2
  echo "  operation:     preflight | postflight" >&2
  echo "  target_status: research | plan | implement | pr_ready | partial | blocked (pr_ready requires task_type==pr unless --allow-pr-ready; partial/blocked are postflight-only)" >&2
  exit 1
fi

if [[ "$operation" != "preflight" && "$operation" != "postflight" ]]; then
  echo "Error: operation must be 'preflight' or 'postflight', got '$operation'" >&2
  exit 1
fi

if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" && "$target_status" != "pr_ready" && "$target_status" != "partial" && "$target_status" != "blocked" ]]; then
  echo "Error: target_status must be 'research', 'plan', 'implement', 'pr_ready', 'partial', or 'blocked', got '$target_status'" >&2
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

# --- Status mapping ---
map_status() {
  local op="$1"
  local target="$2"

  case "${op}:${target}" in
    preflight:research)   STATE_STATUS="researching";   TODO_STATUS="RESEARCHING" ;;
    preflight:plan)       STATE_STATUS="planning";      TODO_STATUS="PLANNING" ;;
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;
    postflight:plan)      STATE_STATUS="planned";       TODO_STATUS="PLANNED" ;;
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    preflight:pr_ready)  STATE_STATUS="pr_ready";      TODO_STATUS="PR READY" ;;
    postflight:pr_ready) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    # partial/blocked are postflight-only task-level termini (state-management.md's permissive
    # transition model admits them from [IMPLEMENTING] on timeout/error). There is deliberately
    # no preflight:partial or preflight:blocked case here -- the catch-all below rejects that
    # nonsensical combination with exit 1, which is the desired fail-loud behavior.
    postflight:partial)  STATE_STATUS="partial";       TODO_STATUS="PARTIAL" ;;
    postflight:blocked)  STATE_STATUS="blocked";       TODO_STATUS="BLOCKED" ;;
    *)
      echo "Error: unknown operation:target_status combination '${op}:${target}'" >&2
      exit 1
      ;;
  esac
}

map_status "$operation" "$target_status"

# --- Validate task exists in state.json ---
task_exists=$(jq -r --arg num "$task_number" \
  '[.active_projects[] | select(.project_number == ($num | tonumber))] | length' \
  "$STATE_FILE")

if [[ "$task_exists" == "0" ]]; then
  echo "Error: task $task_number not found in state.json" >&2
  exit 1
fi

# --- task_type lookup (mirrors the project_name lookup pattern used below) ---
task_type=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .task_type // "general"' \
  "$STATE_FILE")

# --- Guard: pr_ready is reserved for task_type == "pr" unless explicitly overridden ---
if [[ "$target_status" == "pr_ready" && "$task_type" == "pr" ]]; then
  : # allowed: pr-type task transitioning to pr_ready
elif [[ "$target_status" == "pr_ready" && "$ALLOW_PR_READY" == "true" ]]; then
  : # allowed: explicit override flag passed (e.g. skeleton-exhaustion routing in skill-orchestrate-hard)
elif [[ "$target_status" == "pr_ready" ]]; then
  echo "Error: 'pr_ready' is reserved for task_type == 'pr' (task $task_number has task_type '$task_type')." >&2
  echo "       Pass --allow-pr-ready to override this guard." >&2
  exit 1
fi

# --- Idempotency check (scoped to state.json only) ---
# When state.json is already at the target status, the state.json write itself is skipped
# (state_is_noop=true) but PHASE 2 (TODO.md regen) and PHASE 3 (plan/phase file updates) below
# still run unconditionally -- both downstream scripts have their own idempotency checks, so a
# redundant call is a safe no-op. This makes plan/phase updates self-healing on retry instead of
# being silently suppressed by an unrelated state.json no-op.
current_state_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  "$STATE_FILE")

state_is_noop=false
if [[ "$current_state_status" == "$STATE_STATUS" ]]; then
  state_is_noop=true
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Task $task_number already at status '$STATE_STATUS' -- state.json no-op"
  fi
fi

# --- Ensure tmp directory exists ---
mkdir -p "$TMP_DIR"

# ============================================================
# PHASE 1: Update state.json (machine state first) -- skipped when state_is_noop
# ============================================================
update_state_json() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] state.json: task $task_number status '$current_state_status' -> '$STATE_STATUS'"
    echo "[dry-run] state.json: last_updated -> '$ts', session_id -> '$session_id'"
    return 0
  fi

  # Write workflow-active marker on preflight so Stop hook can suppress mid-workflow fires
  if [[ "$operation" == "preflight" ]]; then
    mkdir -p "$SCRIPT_DIR/../tmp"
    echo "$task_number $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SCRIPT_DIR/../tmp/workflow-active"
  fi

  # Use two-step jq pattern to avoid Issue #1132
  # Step 1: Update status and timestamp
  jq --arg num "$task_number" \
     --arg status "$STATE_STATUS" \
     --arg ts "$ts" \
     --arg sid "$session_id" \
    '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    }' "$STATE_FILE" > "$TMP_DIR/state.json.tmp"

  if [[ $? -ne 0 ]]; then
    echo "Error: jq failed to update state.json" >&2
    return 1
  fi

  # Validate the output is valid JSON
  if ! jq empty "$TMP_DIR/state.json.tmp" 2>/dev/null; then
    echo "Error: jq produced invalid JSON for state.json" >&2
    return 1
  fi

  # Atomic move
  mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"
}

# Acquire the specs/.scope-lock mutex before the state.json write below. The critical section
# this brackets is: this write PLUS the TODO.md regen at "Execute TODO.md regeneration" further
# down -- released explicitly right after that call, before PHASE 3's plan-file update (which is
# not part of the state.json/TODO.md hazard this mutex protects).
acquire_state_mutex

if [[ "$state_is_noop" != "true" ]]; then
  if ! update_state_json; then
    echo "Error: failed to update state.json for task $task_number" >&2
    exit 2
  fi
fi

# ============================================================
# PHASE 2: Regenerate TODO.md from state.json
# ============================================================
regenerate_todo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] TODO.md: regenerate from state.json via generate-todo.sh"
    return 0
  fi

  "$SCRIPT_DIR/generate-todo.sh" || {
    echo "Warning: generate-todo.sh failed (state.json was updated successfully)" >&2
  }
}

# ============================================================
# PHASE 3: Plan file status (optional, implement only)
# ============================================================
update_plan_file() {
  # Only update plan file for implement operations
  if [[ "$target_status" != "implement" ]]; then
    return 0
  fi

  local plan_status
  case "$operation" in
    preflight)  plan_status="IMPLEMENTING" ;;
    postflight) plan_status="COMPLETED" ;;
  esac

  # Look up project_name from state.json
  local project_name
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")

  if [[ -z "$project_name" || "$project_name" == "null" ]]; then
    echo "Warning: could not determine project_name for task $task_number" >&2
    return 0
  fi

  local plan_script="$SCRIPT_DIR/update-plan-status.sh"
  if [[ ! -x "$plan_script" ]]; then
    echo "Warning: update-plan-status.sh not found or not executable" >&2
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Plan file: status -> [$plan_status] (via update-plan-status.sh)"
    if [[ "$operation" == "preflight" ]]; then
      echo "[dry-run] Phase status: first [NOT STARTED] phase -> [IN PROGRESS] (via update-phase-status.sh)"
    fi
    return 0
  fi

  # Call existing script. It is already fail-loud on its own diagnostic ("Failed to update
  # status in $plan_file"); do not discard its stderr here. Branch fatal-vs-warn on operation:
  # a failed [COMPLETED] write on implement postflight leaves state.json and the plan file in
  # permanent, externally-invisible disagreement -- generate-todo.sh reads only state.json,
  # never plan files, so no other surface reveals the divergence -- making that path fatal. A
  # failed [IMPLEMENTING] write on preflight is advisory (work is starting either way), so it
  # stays a non-fatal warning.
  cd "$PROJECT_ROOT"
  if ! "$plan_script" "$task_number" "$project_name" "$plan_status"; then
    if [[ "$operation" == "postflight" ]]; then
      echo "Error: failed to update plan file status to [$plan_status] for task $task_number." >&2
      echo "       state.json was already written to '$STATE_STATUS'; this is retryable -- the" >&2
      echo "       state.json write is idempotent and will no-op on retry, while the plan/phase" >&2
      echo "       updates below re-fire until they converge." >&2
      exit 3
    else
      echo "Warning: plan file update failed (non-fatal)" >&2
    fi
  fi

  # Auto-advance the first NOT STARTED phase to IN PROGRESS on implement preflight
  if [[ "$operation" == "preflight" ]]; then
    local phase_script="$SCRIPT_DIR/update-phase-status.sh"
    if [[ -x "$phase_script" ]]; then
      # Resolve plan directory (padded with unpadded fallback)
      local padded_num
      padded_num=$(printf "%03d" "$task_number")
      local plan_dir="$PROJECT_ROOT/specs/${padded_num}_${project_name}/plans"
      if [[ ! -d "$plan_dir" ]]; then
        plan_dir="$PROJECT_ROOT/specs/${task_number}_${project_name}/plans"
      fi

      if [[ -d "$plan_dir" ]]; then
        local plan_file
        # Version-ordered selection (not mtime-ordered), same two-tier rule as
        # update-plan-status.sh and update-phase-status.sh: prefer the MM_{short-slug}.md
        # convention (artifact-formats.md), highest sequence wins; fall back to a plain name
        # sort only when no conforming file exists. Not reusing update-plan-status.sh's
        # stdout here: its idempotent no-op branch exits 0 emitting nothing, so its stdout is
        # empty on a successful no-op and unusable as a path source.
        plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || echo "")
        if [[ -z "$plan_file" ]]; then
          plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || echo "")
        fi
        if [[ -n "$plan_file" ]]; then
          local first_phase
          first_phase=$(grep -m1 "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_file" \
            | sed 's/^### Phase \([0-9]*\):.*/\1/' || echo "")
          if [[ -n "$first_phase" ]]; then
            # Superseded by the base agent owning every per-phase transition directly; this
            # call is a redundant convenience, recoverable via the agent's own explicit calls.
            # Non-fatal, and its stderr is no longer discarded.
            "$phase_script" "$task_number" "$project_name" "$first_phase" "IN_PROGRESS" || {
              echo "Warning: phase status update failed (non-fatal)" >&2
            }
          fi
        fi
      fi
    fi
  fi
}

# Execute TODO.md regeneration
regenerate_todo

# Release the specs/.scope-lock mutex here: the state.json write + TODO.md regen critical
# section (acquired above, before PHASE 1) ends here. PHASE 3's plan-file update below is
# explicitly outside the bracket -- it does not touch state.json or TODO.md.
release_state_mutex

# Execute plan file update
update_plan_file

if [[ "$DRY_RUN" != "true" ]]; then
  if [[ "$state_is_noop" == "true" ]]; then
    echo "OK: task $task_number state.json already at '$STATE_STATUS' (no-op); plan/phase updates re-applied"
  else
    echo "OK: task $task_number status -> $STATE_STATUS"
  fi
fi

exit 0
