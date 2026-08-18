#!/usr/bin/env bash
# command-gate-out.sh — CHECKPOINT 2: Defensive status correction after skill delegation
#
# Usage: bash .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$session_id"
#
# This script can be called as a subprocess (not sourced) since it only produces
# side effects (state.json updates, artifact validation) and does not export variables.
# (That describes how callers invoke THIS script — it does not restrict what this script may
# itself source internally; it sources skill-base.sh below for skill_validate_task_artifacts,
# following the same precedent orchestrator-postflight.sh already uses.)
#
# Arguments:
#   $1  task_number — The numeric task ID
#   $2  operation   — "research" | "plan" | "implement" | "orchestrate" | "revise"
#   $3  session_id  — The session ID (sess_{timestamp}_{hex}) from gate-in
#
# Note: "operation" is NOT passed verbatim as update-task-status.sh's target_status (which only
# accepts research|plan|implement|pr_ready). A separate "status_token" mapping below translates
# operation -> a valid target_status ("revise" -> "plan", "orchestrate" -> "implement").
#
# Scope: NARROW — only the shared defensive correction pattern (~25 lines).
# Implement-specific steps (completion_summary, plan file verification) stay inline
# in implement.md. Plan-specific steps (plan file status check) stay inline in plan.md.
#
# Exit Codes:
#   0 — Success (correction applied or no correction needed)
#   1 — Fatal error (state.json missing)
#
# Downstream dependencies:
#   skill-base.sh may call this script.

set -e

# Source the shared skill-lifecycle library for skill_validate_task_artifacts (the non-blocking
# artifact validation leg below). Not sourced elsewhere in this script, so it is sourced once
# here at the top, matching orchestrator-postflight.sh's precedent.
source .claude/scripts/skill-base.sh

task_number="$1"
operation="$2"
session_id="$3"
state_file="specs/state.json"

# Task lock: unconditional release, run FIRST so it executes regardless of any downstream
# branch or early exit below (missing state.json, missing .return-meta.json, etc.). Success,
# partial, and failed skill statuses all release — release is idempotent and never conditioned
# on the operation's own outcome. See .claude/context/patterns/task-lock.md for the full
# contract. Uses the SAME session_id the gate-in acquired with.
bash .claude/scripts/task-lock.sh release "$task_number" "$session_id" 2>/dev/null || true

# In-flight session registry: unconditional release, same "runs first, regardless of downstream
# branch" placement as the task-lock release immediately above. Best-effort and non-blocking. See
# .claude/context/patterns/task-lock.md's Session-Registry CLI section.
bash .claude/scripts/task-lock.sh session-release "$session_id" 2>/dev/null || true

if [ ! -f "$state_file" ]; then
  echo "ERROR: $state_file not found" >&2
  exit 1
fi

# Get project name and task directory
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  "$state_file")
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"

# Read skill return metadata (non-blocking if missing)
#
# Absence here is now a meaningful diagnostic signal, not a routine event: skill_cleanup()
# (skill-base.sh) no longer deletes .return-meta.json at the skill's own Stage 9 -- deletion is
# now owned by the calling command's own last step, which runs AFTER this script (each command's
# CHECKPOINT 3 commit block, or for /revise, the step right after this gate-out call). So on
# every normal successful run this file is still present when we get here, and this branch fires
# ONLY on a genuine failure: the skill crashed before writing return metadata, or its Stage 0
# contract was violated. Neither defensive status correction below nor
# skill_validate_task_artifacts can run without this file, so both are skipped for this dispatch.
meta_file="${task_dir}/.return-meta.json"
if [ ! -f "$meta_file" ]; then
  echo "WARNING: .return-meta.json not found at $meta_file — the skill did not write return metadata (crashed before postflight, or violated its Stage 0 early-metadata contract). Defensive status correction and artifact validation cannot run for this dispatch." >&2
  # Non-blocking: continue anyway (defensive correction impossible without metadata)
  exit 0
fi

skill_status=$(jq -r '.status' "$meta_file")

# Defensive status correction: map skill status to task status
# Only applies when skill reports completion but state.json is stale
#
# status_token is the value passed to update-task-status.sh's target_status positional arg,
# which only accepts research|plan|implement|pr_ready. It is deliberately distinct from
# "operation": "revise" produces a "planned" state.json status (expected_status) but must pass
# "plan" (not "revise") as target_status; "orchestrate" produces a "completed" state.json status
# but must pass "implement" (not "orchestrate") — this maps "orchestrate" to a valid
# update-task-status.sh target_status instead of passing it through verbatim.
case "$operation" in
  research)    expected_status="researched"; status_token="research" ;;
  plan)        expected_status="planned";    status_token="plan" ;;
  implement)   expected_status="completed";  status_token="implement" ;;
  orchestrate) expected_status="completed";  status_token="implement" ;;
  revise)      expected_status="planned";    status_token="plan" ;;
  *)           expected_status="";           status_token="" ;;
esac

# skill_status accept-list: the normative enumeration of these three success values is
# context/formats/return-metadata-file.md's status vocabulary for .return-meta.json — keep this
# list and that table in sync rather than letting them drift independently. This branch is live
# for operation=orchestrate (not dead code): once the skill-orchestrate writer emits
# "implemented" instead of the format's forbidden "completed", a desynced state.json correctly
# falls through this accept-list and reaches the correction below.
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then

  # Get current status from state.json using safe jq pattern (no != operator per Issue #1132)
  current_status=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .status' \
    "$state_file")

  if [ "$current_status" != "$expected_status" ] && [ "$skill_status" != "partial" ] && [ "$skill_status" != "failed" ]; then
    echo "[gate-out] Defensive correction: status is '$current_status', skill reports '$skill_status'. Applying correction to '$expected_status'."
    # A defensive corrector has no fresh handoff to trust, so it is exactly the case the
    # script-side backstop is built for: only the implement token gets --phase-check=refuse (the
    # flag is silently ignored elsewhere, but passing it only where it applies keeps intent
    # legible). stderr is deliberately no longer discarded for this call -- swallowing it would
    # hide the refusal's reason, which is the only actionable part of the message.
    gate_out_phase_check=""
    if [ "$status_token" = "implement" ]; then
      gate_out_phase_check="--phase-check=refuse"
    fi
    gate_out_rc=0
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" ${gate_out_phase_check} || gate_out_rc=$?
    if [ "$gate_out_rc" -eq 4 ]; then
      echo "[gate-out] Phase-accounting backstop refused the defensive correction for task $task_number (plan file shows incomplete phases). Leaving status as '$current_status'." >&2
    elif [ "$gate_out_rc" -ne 0 ]; then
      echo "WARNING: update-task-status.sh failed — manual correction may be needed" >&2
    fi
  fi
fi

# Non-blocking artifact validation (link repair)
if [ -d "$task_dir" ]; then
  skill_validate_task_artifacts "$task_dir"
fi

# NOTE: this script MUST NOT delete .return-meta.json. Two reasons: (1) skill-orchestrate never
# calls skill_cleanup and its own postflight stage merges onto .return-meta.json rather than
# deleting it, so deleting it here would regress /orchestrate's completion/resume behavior; (2)
# for /research and /plan, the calling command's own CHECKPOINT 3 commit block runs AFTER this
# script and still needs to read and stage the file -- deleting it here would reintroduce the
# same class of bug this file's lifecycle-ordering fix was written to eliminate. Deletion is
# owned exclusively by each calling command's own last step; see
# context/patterns/skill-postflight-flow.md's reader table for the full per-command mapping.
