#!/bin/bash
# Combined Stop/SubagentStop hook: log a lifecycle event into the unified event store.
#
# Registered under BOTH the Stop and SubagentStop matchers in root-files/settings.json.
# Branches on stdin's `agent_id` field (present only for a SubagentStop payload) to decide
# which correlation path to take -- the same agent_id-presence convention already used by
# memory-nudge.sh and claude-stop-notify.sh to distinguish subagent stops from top-level ones.
#
# Claude Code hook stdin carries no workflow session_id or task number directly, so each
# path reconstructs both via existing correlation mechanisms rather than inventing a new one:
#
#   SubagentStop path: locates the `.postflight-pending` marker file the same way
#     subagent-postflight.sh does (`find specs -maxdepth 3 -name ".postflight-pending"`).
#     The marker itself carries `session_id`/`skill`/`operation`
#     (see skill_create_postflight_marker in scripts/skill-base.sh); the task number is
#     recovered from the marker's parent task directory name.
#
#   Stop path: reads .claude/tmp/workflow-active (written by update-task-status.sh preflight
#     as `"<task_number> <timestamp>"`) for a task number; if absent, falls back to a
#     task-number regex over stdin's last_assistant_message (mirroring memory-nudge.sh's
#     `task [0-9]+` / `Task #[0-9]+` extraction). The session_id itself is never present in
#     either source, so once a task number is recovered it is used to look up that task's
#     current session_id from specs/state.json's active_projects entry (populated by
#     update-task-status.sh on every preflight). If no session_id can be resolved this way,
#     the hook exits {} cleanly rather than emitting a sessionless event.
#
# Accepted trade-off: a SubagentStop may fire more than once per loop-guard continuation
# (see subagent-postflight.sh's MAX_CONTINUATIONS retry loop). This hook does not deduplicate
# repeated fires -- downstream consumers can dedupe by session_id+checkpoint if needed.
#
# Note: this hook deliberately does NOT re-read .return-meta.json -- by Stop/SubagentStop
# time it may already be cleaned up by postflight. Metadata-derived events are the
# PostToolUse hook's job (events-log-artifact.sh), which fires at Write time.
#
# Never blocks: always echoes {} (never emits a "decision" key). The events-append.sh call
# is wrapped in the observable-but-non-fatal helper below so a failure here can never surface
# to the caller or stall the session, while still producing a distinguishable, durable signal
# instead of the prior bare `|| true` silent failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVENTS_APPEND="$SCRIPT_DIR/../scripts/events-append.sh"

exit_success() {
  echo '{}'
  exit 0
}

# Observable-but-non-fatal wrapper around events-append.sh -- see the identical helper in
# scripts/skill-base.sh and scripts/orchestrator-postflight.sh for the full contract comment.
# ALWAYS returns 0; distinguishes "missing" vs "failed (exit N)" in a stderr WARNING plus a
# durable sentinel marker under .claude/tmp/.
_EVENTS_APPEND_OBSERVABLE_WARNED=""
_events_append_observable() {
  local helper_path="$1"
  shift
  local kind="" exit_code=""
  if [ ! -x "$helper_path" ]; then
    kind="missing"
  else
    if "$helper_path" "$@" >/dev/null 2>&1; then
      exit_code=0
    else
      exit_code=$?
      kind="failed"
    fi
  fi
  if [ -n "$kind" ]; then
    if [ -z "$_EVENTS_APPEND_OBSERVABLE_WARNED" ]; then
      if [ "$kind" = "missing" ]; then
        echo "[events-log-lifecycle] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[events-log-lifecycle] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
      fi
      _EVENTS_APPEND_OBSERVABLE_WARNED=1
    fi
    mkdir -p "$SCRIPT_DIR/../tmp" 2>/dev/null
    printf '{"kind":"%s","helper_path":"%s","exit_code":"%s","ts":"%s"}\n' \
      "$kind" "$helper_path" "$exit_code" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >> "$SCRIPT_DIR/../tmp/events-append-observable.log" 2>/dev/null
  fi
  return 0
}

command -v jq &>/dev/null || exit_success
# NOTE: deliberately no early `[ -x "$EVENTS_APPEND" ] || exit_success` bypass here -- that
# used to short-circuit BEFORE the call site could ever signal a missing helper, which is
# exactly the silent-failure defect this wrapper replaces. Missing/failing helper detection now
# happens inside _events_append_observable at each call site below.

# --- Read stdin JSON (hook context) ---
STDIN_JSON=""
if read -t 0.1 -r line; then
  STDIN_JSON="$line"
  while read -t 0.1 -r more; do
    STDIN_JSON="${STDIN_JSON}${more}"
  done
fi
[ -z "$STDIN_JSON" ] && STDIN_JSON='{}'

AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")

if [ -n "$AGENT_ID" ]; then
  # ─────────────────────────────────────────────────────────────────────────
  # SubagentStop path: marker-file correlation
  # ─────────────────────────────────────────────────────────────────────────
  MARKER_FILE=$(find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1)
  [ -z "$MARKER_FILE" ] && exit_success
  jq empty "$MARKER_FILE" 2>/dev/null || exit_success

  session_id=$(jq -r '.session_id // empty' "$MARKER_FILE" 2>/dev/null)
  [ -z "$session_id" ] && exit_success

  skill=$(jq -r '.skill // empty' "$MARKER_FILE" 2>/dev/null)
  operation=$(jq -r '.operation // empty' "$MARKER_FILE" 2>/dev/null)

  task_dir=$(dirname "$MARKER_FILE")
  task=""
  if [[ "$task_dir" =~ specs/([0-9]+)_ ]]; then
    task="${BASH_REMATCH[1]}"
  fi

  event_args=(--event-type subagent_stop --category milestone --checkpoint postflight \
    --session "$session_id" \
    --message "Subagent stop for ${skill:-unknown} (${operation:-unknown})")
  [ -n "$task" ] && event_args+=(--task "$task")

  _events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
  exit_success
fi

# ─────────────────────────────────────────────────────────────────────────
# Stop path: workflow-active marker, else last_assistant_message pattern fallback
# ─────────────────────────────────────────────────────────────────────────
task=""
WORKFLOW_ACTIVE="$SCRIPT_DIR/../tmp/workflow-active"
if [ -f "$WORKFLOW_ACTIVE" ]; then
  task=$(awk '{print $1}' "$WORKFLOW_ACTIVE" 2>/dev/null)
fi

if [ -z "$task" ]; then
  MESSAGE=$(echo "$STDIN_JSON" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
  CHECK="${MESSAGE:0:2000}"
  if [[ "$CHECK" =~ [Tt]ask\ ([0-9]+) ]]; then
    task="${BASH_REMATCH[1]}"
  elif [[ "$CHECK" =~ Task\ \#([0-9]+) ]]; then
    task="${BASH_REMATCH[1]}"
  fi
fi

# No task recovered -- there is no reliable session_id source without it; exit cleanly.
[ -z "$task" ] && exit_success

# Neither correlation source carries session_id directly; recover it from the task's
# current state.json entry (populated by update-task-status.sh on every preflight).
[ -f specs/state.json ] || exit_success
jq empty specs/state.json 2>/dev/null || exit_success

session_id=$(jq -r --argjson num "$task" \
  '.active_projects[]? | select(.project_number == $num) | .session_id // empty' \
  specs/state.json 2>/dev/null)
[ -z "$session_id" ] && exit_success

event_args=(--event-type session_stop --category milestone --session "$session_id" \
  --task "$task" --message "Session stop observed for task ${task}")

_events_append_observable "$EVENTS_APPEND" "${event_args[@]}"
exit_success
