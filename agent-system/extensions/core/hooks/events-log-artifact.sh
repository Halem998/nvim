#!/bin/bash
# PostToolUse hook: log unified-event-store events for Write/Edit calls that touch a
# task's .return-meta.json or specs/errors.json.
#
# Integration: appended to the existing PostToolUse "Write|Edit" matcher's hooks array in
# root-files/settings.json, alongside validate-plan-write.sh's entry.
#
# Cheap early-exit: file_path is checked against two narrow path patterns BEFORE any
# jq/lock work is paid for, so this hook is near-zero-cost on the vast majority of
# Write/Edit calls it fires for (mirrors validate-plan-write.sh / validate-meta-write.sh).
#
# Never blocks: always echoes {} (never emits a "decision" key). Every events-append.sh
# call is wrapped in `|| true` so a failure here can never surface to the caller or stall
# the session.
#
# See context/formats/events-format.md for the event field contract.

set -uo pipefail

# --- Parse file_path from stdin (PostToolUse hook input), mirroring the stdin-then-env
#     fallback pattern used by validate-plan-write.sh / validate-meta-write.sh ---
if [ -t 0 ]; then
  FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
  fi
fi

# Early exit for empty path (~1ms) -- no jq/lock work paid for below this point unless matched
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Determine match type from the two narrow path patterns this hook cares about. Any other
# path exits immediately without touching jq/flock -- the hot-path cost this hook must
# stay cheap on.
match_type=""
case "$FILE" in
  specs/*/.return-meta.json|*/specs/*/.return-meta.json)
    match_type="return_meta"
    ;;
  specs/errors.json|*/specs/errors.json)
    match_type="errors_json"
    ;;
  *)
    echo '{}'
    exit 0
    ;;
esac

# Guard: file must exist and parse as valid JSON before any field extraction (mirrors
# skill_read_metadata's jq empty guard -- tolerates a mid-write or since-deleted file).
if [ ! -f "$FILE" ] || ! jq empty "$FILE" 2>/dev/null; then
  echo '{}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENTS_APPEND="${SCRIPT_DIR}/scripts/events-append.sh"

if [ ! -x "$EVENTS_APPEND" ]; then
  echo '{}'
  exit 0
fi

if [ "$match_type" = "return_meta" ]; then
  session_id=$(jq -r '.metadata.session_id // empty' "$FILE" 2>/dev/null)
  status=$(jq -r '.status // empty' "$FILE" 2>/dev/null)

  # session_id is required by events-append.sh -- skip silently if absent (e.g. a
  # hand-authored or mid-write metadata file that hasn't reached Stage 0's full write yet)
  if [ -n "$session_id" ]; then
    # Task number is embedded in the directory name, not the file content
    task=""
    if [[ "$FILE" =~ specs/([0-9]+)_[^/]+/\.return-meta\.json$ ]]; then
      task="${BASH_REMATCH[1]}"
    fi

    case "$status" in
      failed|blocked) category="blocker" ;;
      partial) category="deviation" ;;
      in_progress) category="milestone" ;;
      *) category="success" ;;
    esac

    event_args=(--event-type artifact_write --category "$category" --session "$session_id" \
      --message "Artifact metadata written with status '${status:-unknown}'")
    [ -n "$task" ] && event_args+=(--task "$task")

    "$EVENTS_APPEND" "${event_args[@]}" >/dev/null 2>&1 || true
  fi

elif [ "$match_type" = "errors_json" ]; then
  session_id=$(jq -r '.errors[-1].context.session_id // empty' "$FILE" 2>/dev/null)

  if [ -n "$session_id" ]; then
    task=$(jq -r '.errors[-1].context.task // empty' "$FILE" 2>/dev/null)
    error_id=$(jq -r '.errors[-1].id // empty' "$FILE" 2>/dev/null)
    severity=$(jq -r '.errors[-1].severity // empty' "$FILE" 2>/dev/null)

    case "$severity" in
      critical|high) category="blocker" ;;
      *) category="deviation" ;;
    esac

    event_args=(--event-type error_logged --category "$category" --session "$session_id" \
      --message "Error entry logged to specs/errors.json")
    [ -n "$task" ] && [ "$task" != "null" ] && event_args+=(--task "$task")
    [ -n "$error_id" ] && event_args+=(--error-ref "$error_id")

    "$EVENTS_APPEND" "${event_args[@]}" >/dev/null 2>&1 || true
  fi
fi

echo '{}'
exit 0
