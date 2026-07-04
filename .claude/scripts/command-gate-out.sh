#!/usr/bin/env bash
# command-gate-out.sh — CHECKPOINT 2: Defensive status correction after skill delegation
#
# Usage: bash .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$session_id"
#
# This script can be called as a subprocess (not sourced) since it only produces
# side effects (state.json updates, artifact validation) and does not export variables.
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
#   Task 594 (skill-base.sh) may call this script.

set -e

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
meta_file="${task_dir}/.return-meta.json"
if [ ! -f "$meta_file" ]; then
  echo "WARNING: .return-meta.json not found at $meta_file — skill may have failed silently" >&2
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
# but must pass "implement" (not "orchestrate") — this repairs a latent bug where "orchestrate"
# was previously passed verbatim and would have failed update-task-status.sh's validation had
# this branch ever been exercised on a desynced orchestrate run.
case "$operation" in
  research)    expected_status="researched"; status_token="research" ;;
  plan)        expected_status="planned";    status_token="plan" ;;
  implement)   expected_status="completed";  status_token="implement" ;;
  orchestrate) expected_status="completed";  status_token="implement" ;;
  revise)      expected_status="planned";    status_token="plan" ;;
  *)           expected_status="";           status_token="" ;;
esac

if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then

  # Get current status from state.json using safe jq pattern (no != operator per Issue #1132)
  current_status=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .status' \
    "$state_file")

  if [ "$current_status" != "$expected_status" ] && [ "$skill_status" != "partial" ] && [ "$skill_status" != "failed" ]; then
    echo "[gate-out] Defensive correction: status is '$current_status', skill reports '$skill_status'. Applying correction to '$expected_status'."
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" 2>/dev/null || \
      echo "WARNING: update-task-status.sh failed — manual correction may be needed" >&2
  fi
fi

# Non-blocking artifact validation (link repair)
if [ -d "$task_dir" ]; then
  bash .claude/scripts/validate-artifact.sh "$task_dir" --fix 2>/dev/null || true
fi
