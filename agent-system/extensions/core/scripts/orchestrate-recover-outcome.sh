#!/usr/bin/env bash
# orchestrate-recover-outcome.sh — Shared .return-meta.json outcome-recovery helper for /orchestrate.
#
# Purpose: `.orchestrator-handoff.json` is written by exactly one active writer today (the
# hard-mode implementation agent's H9 wrap-up). Base-mode research, plan, and implement
# dispatches never write one — by contractual design for research (Stage 3.6 "Scoping
# Decision"), and simply never implemented for base-mode plan/implement. Before this script,
# Stage 5 (single-task base and hard mode) and Stage MT-4 (multi-task) each treated every missing
# handoff identically as a suspected defect, with no way to tell "this dispatch's writer never
# produces a handoff, and it succeeded anyway" from "something actually broke." This script is
# the ONE place that reads a task's `.return-meta.json` — a file every research/plan/implement
# dispatch writes per its own Stage 7 contract — and turns it into the same outcome fields Stage 5
# already reads from a handoff, so the three call sites (base Stage 5, hard Stage 5, multi-task
# Stage MT-4 step 1) cannot drift into three separately-maintained recovery rules.
#
# Precedent: `scripts/command-gate-out.sh` (the non-orchestrator postflight path used by plain
# `/research`, `/plan`, `/implement`) already reads `.return-meta.json`'s `.status` as its sole
# outcome signal. This script extends the same channel to the orchestrator path.
#
# Usage:
#   orchestrate-recover-outcome.sh <task_dir> <window_start_ts>
#
# where <task_dir> is the task's directory (relative or absolute; this script does not care which,
# it only ever appends "/.return-meta.json") and <window_start_ts> is the Unix epoch second the
# current dispatch started (the same `dispatch_start_ts` Stage 5 already captures via `date -u
# +%s` immediately before the Agent tool call, for its handoff staleness gate).
#
# Forbidden calls (this script is read-only; it must never be the mechanism by which a Stage 5 or
# Stage MT-4 caller mutates anything):
#   - task-lock.sh (acquire/heartbeat/release)
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update,
#     skill_gate_completion_claim, skill_link_artifacts, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
# This script reads ONLY `<task_dir>/.return-meta.json` — never a report, plan, summary, or
# handoff file (Context Flatness Constraint). It performs no writes of any kind.
#
# Staleness check: identical idiom and fail-closed default to the handoff staleness gate Stage 5
# already runs: `stat -c %Y ... || stat -f %m ... || echo 0`, compared against
# `${window_start_ts:-9999999999}`. `meta_mtime -ge window_start` is fresh — an unset or
# unparseable window_start_ts defaults to "never fresh," matching the fail-closed posture callers
# already rely on.
#
# Recoverable statuses: `researched`, `planned`, `implemented` — the same success vocabulary
# Stage 5 already branches on when reading a handoff. Every other outcome sets `recovered=false`
# with a reason token below; callers MUST treat that identically to a missing/stale/unparseable
# file — this script never invents a success where the file itself does not report one.
#
# Output: a single-line compact JSON object on stdout, with these fields:
#   recovered          bool    true only for a present, fresh, parseable file whose `.status` is
#                                researched/planned/implemented.
#   status             string  the file's `.status` when parseable, else "unknown". Populated
#                                even when recovered=false, so callers can log a
#                                partial/failed/blocked/in_progress outcome without acting on it.
#   reason             string  one of: NONE (recovered=true), META_MISSING, META_STALE,
#                                META_UNPARSEABLE, STATUS_IN_PROGRESS, STATUS_NOT_SUCCESS, USAGE.
#   artifact_path       string  .artifacts[0].path, or "" when absent/not recovered.
#   artifact_type       string  .artifacts[0].type, or "".
#   artifact_summary    string  .artifacts[0].summary, or "".
#   phases_completed    int     .metadata.phases_completed // .partial_progress.phases_completed // 0
#   phases_total        int     .metadata.phases_total // .partial_progress.phases_total // 0
#   meta_mtime          int     the file's mtime (0 if missing/unstattable).
#   window_start        int     the window_start_ts actually used (post fail-closed default).
#
# Exit codes:
#   0 — recovered=true; the JSON object above is on stdout.
#   1 — recovered=false (missing, stale, unparseable, in_progress, or non-success status); the
#       JSON object above is still on stdout so callers can log the reason.
#   2 — usage error (wrong argument count) or jq unavailable. Nothing is printed on stdout;
#       callers MUST treat exit 2 identically to exit 1 (fail closed).

set -uo pipefail

task_dir="${1:-}"
window_start_ts="${2:-}"

if [ -z "$task_dir" ] || [ "$#" -ne 2 ]; then
  echo "ERROR: orchestrate-recover-outcome.sh: usage: orchestrate-recover-outcome.sh <task_dir> <window_start_ts>" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-recover-outcome.sh: jq is not available; cannot evaluate recovery." >&2
  exit 2
fi

# Fail-closed default: an empty/non-numeric window_start_ts becomes "never fresh."
case "$window_start_ts" in
  ''|*[!0-9]*) window_start="9999999999" ;;
  *) window_start="$window_start_ts" ;;
esac

meta_file="${task_dir}/.return-meta.json"

emit() {
  # $1=recovered $2=status $3=reason $4=artifact_path $5=artifact_type $6=artifact_summary
  # $7=phases_completed $8=phases_total $9=meta_mtime
  jq -n -c \
    --argjson recovered "$1" \
    --arg status "$2" \
    --arg reason "$3" \
    --arg artifact_path "$4" \
    --arg artifact_type "$5" \
    --arg artifact_summary "$6" \
    --argjson phases_completed "$7" \
    --argjson phases_total "$8" \
    --argjson meta_mtime "$9" \
    --argjson window_start "$window_start" \
    '{recovered: $recovered, status: $status, reason: $reason,
      artifact_path: $artifact_path, artifact_type: $artifact_type,
      artifact_summary: $artifact_summary, phases_completed: $phases_completed,
      phases_total: $phases_total, meta_mtime: $meta_mtime, window_start: $window_start}'
}

if [ ! -f "$meta_file" ]; then
  emit false "unknown" "META_MISSING" "" "" "" 0 0 0
  exit 1
fi

meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)

if [ "$meta_mtime" -lt "$window_start" ]; then
  emit false "unknown" "META_STALE" "" "" "" 0 0 "$meta_mtime"
  exit 1
fi

if ! meta_json=$(jq -c '.' "$meta_file" 2>/dev/null); then
  emit false "unknown" "META_UNPARSEABLE" "" "" "" 0 0 "$meta_mtime"
  exit 1
fi

status=$(echo "$meta_json" | jq -r '.status // "unknown"')
phases_completed=$(echo "$meta_json" | jq -r '.metadata.phases_completed // .partial_progress.phases_completed // 0')
phases_total=$(echo "$meta_json" | jq -r '.metadata.phases_total // .partial_progress.phases_total // 0')
artifact_path=$(echo "$meta_json" | jq -r '.artifacts[0].path // ""')
artifact_type=$(echo "$meta_json" | jq -r '.artifacts[0].type // ""')
artifact_summary=$(echo "$meta_json" | jq -r '.artifacts[0].summary // ""')

case "$status" in
  researched|planned|implemented)
    emit true "$status" "NONE" "$artifact_path" "$artifact_type" "$artifact_summary" \
      "$phases_completed" "$phases_total" "$meta_mtime"
    exit 0
    ;;
  in_progress)
    emit false "$status" "STATUS_IN_PROGRESS" "" "" "" 0 0 "$meta_mtime"
    exit 1
    ;;
  *)
    emit false "$status" "STATUS_NOT_SUCCESS" "" "" "" 0 0 "$meta_mtime"
    exit 1
    ;;
esac
