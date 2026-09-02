#!/usr/bin/env bash
# manage-topics.sh - Topic management utility for state.json active_topics
#
# Encapsulates mechanical state.json operations for topic management.
# Commands/skills call this script instead of inlining jq snippets.
#
# Usage:
#   manage-topics.sh list
#   manage-topics.sh add TOPIC [--session-id SID]
#   manage-topics.sh remove TOPIC [--session-id SID]
#   manage-topics.sh set TASK_NUM TOPIC [--session-id SID]
#   manage-topics.sh validate TOPIC
#
# Subcommands:
#   list              Print all active topics, one per line
#   add TOPIC         Add TOPIC to active_topics (idempotent; no-op if already present)
#   remove TOPIC      Remove TOPIC from active_topics (idempotent; no-op if already absent).
#                      Does NOT check whether any task still carries this topic -- the caller is
#                      responsible for confirming the topic is genuinely orphaned (no active,
#                      archived, or vaulted task references it) before removing it. Removing a
#                      topic still in use by an active task does not clear the task's own
#                      `topic` field; it only drops the entry from `active_topics`.
#   set TASK_NUM TOPIC  Set topic on task TASK_NUM and ensure TOPIC is in active_topics
#   validate TOPIC    Exit 0 if TOPIC is in active_topics, exit 1 if not (no stdout)
#
# --session-id SID   Optional, accepted by `add`/`remove`/`set` (the three write subcommands).
#                     Attributes the specs/.scope-lock mutex acquisition (via state-write.sh) to
#                     this session. If omitted, a session_id is generated inline using the same
#                     portable pattern command-gate-in.sh uses, so this script remains a
#                     self-contained drop-in for its many existing callers that have no
#                     session_id of their own to pass.
#
# Exit codes:
#   0 - Success (list/add/remove/set) or topic found (validate)
#   1 - Topic not found (validate) or bad arguments
#   2 - state.json not found or read error
#   3 - jq write failure (state-write.sh)
#   4 - Task not found (set subcommand)
#
# Note: write subcommands (add/set) route through state-write.sh, the single mutex-guarded
# specs/state.json writer -- see scripts/state-write.sh's own header for the full serialization
# contract (fail-closed acquire, private mktemp staging, jq empty validation before mv).

set -euo pipefail

# --- Path resolution (matches update-task-status.sh pattern) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Extract an optional --session-id SID anywhere in the argument list, leaving the rest of
# the positional arguments (subcommand + its own args) in order. ---
SESSION_ID=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --session-id=*)
      SESSION_ID="${1#--session-id=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]}"

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="$(common_session_id)"
fi

# --- Guard: state.json must exist ---
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 2
fi

# --- Subcommand dispatch ---
SUBCMD="${1:-}"

case "$SUBCMD" in

  # ------------------------------------------------------------------
  # list: print active topics one per line
  # ------------------------------------------------------------------
  list)
    jq -r '.active_topics // [] | .[]' "$STATE_FILE"
    ;;

  # ------------------------------------------------------------------
  # add TOPIC: idempotent append to active_topics
  # ------------------------------------------------------------------
  add)
    TOPIC="${2:-}"
    if [[ -z "$TOPIC" ]]; then
      echo "Usage: $0 add TOPIC [--session-id SID]" >&2
      exit 1
    fi

    # Use index($t) == null pattern (safe under Claude Code Issue #1132 — no != operator)
    "$SCRIPT_DIR/state-write.sh" \
      'if ((.active_topics // []) | index($t)) == null
       then .active_topics = ((.active_topics // []) + [$t])
       else .
       end' \
      --session-id "$SESSION_ID" \
      --arg t "$TOPIC" \
      || { echo "Error: state-write.sh failed to update active_topics" >&2; exit 3; }
    ;;

  # ------------------------------------------------------------------
  # remove TOPIC: idempotent removal from active_topics
  # ------------------------------------------------------------------
  remove)
    TOPIC="${2:-}"
    if [[ -z "$TOPIC" ]]; then
      echo "Usage: $0 remove TOPIC [--session-id SID]" >&2
      exit 1
    fi

    # Use select(. == $t | not) pattern (safe under Claude Code Issue #1132 -- no != operator),
    # matching the add subcommand's index($t) == null convention above.
    "$SCRIPT_DIR/state-write.sh" \
      '.active_topics = ((.active_topics // []) | map(select(. == $t | not)))' \
      --session-id "$SESSION_ID" \
      --arg t "$TOPIC" \
      || { echo "Error: state-write.sh failed to update active_topics" >&2; exit 3; }
    ;;

  # ------------------------------------------------------------------
  # set TASK_NUM TOPIC: assign topic to task and add to active_topics
  # ------------------------------------------------------------------
  set)
    TASK_NUM="${2:-}"
    TOPIC="${3:-}"
    if [[ -z "$TASK_NUM" || -z "$TOPIC" ]]; then
      echo "Usage: $0 set TASK_NUM TOPIC [--session-id SID]" >&2
      exit 1
    fi

    if ! [[ "$TASK_NUM" =~ ^[0-9]+$ ]]; then
      echo "Error: TASK_NUM must be a positive integer, got '$TASK_NUM'" >&2
      exit 1
    fi

    # Validate task exists
    task_exists=$(jq -r --arg num "$TASK_NUM" \
      '[.active_projects[] | select(.project_number == ($num | tonumber))] | length' \
      "$STATE_FILE")

    if [[ "$task_exists" == "0" ]]; then
      echo "Error: task $TASK_NUM not found in state.json" >&2
      exit 4
    fi

    # Set topic on the task entry + ensure active_topics contains the topic
    "$SCRIPT_DIR/state-write.sh" \
      '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {topic: $t}
       | if ((.active_topics // []) | index($t)) == null
         then .active_topics = ((.active_topics // []) + [$t])
         else .
         end' \
      --session-id "$SESSION_ID" \
      --arg num "$TASK_NUM" \
      --arg t "$TOPIC" \
      || { echo "Error: state-write.sh failed to update task topic" >&2; exit 3; }
    ;;

  # ------------------------------------------------------------------
  # validate TOPIC: exit 0 if present, exit 1 if not; no stdout
  # ------------------------------------------------------------------
  validate)
    TOPIC="${2:-}"
    if [[ -z "$TOPIC" ]]; then
      echo "Usage: $0 validate TOPIC" >&2
      exit 1
    fi

    found=$(jq -r --arg t "$TOPIC" \
      'if ((.active_topics // []) | index($t)) == null then "no" else "yes" end' \
      "$STATE_FILE")

    if [[ "$found" == "yes" ]]; then
      exit 0
    else
      exit 1
    fi
    ;;

  # ------------------------------------------------------------------
  # Unknown subcommand or no args
  # ------------------------------------------------------------------
  *)
    echo "manage-topics.sh — topic management utility for state.json" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  $0 list                    Print all active topics" >&2
    echo "  $0 add TOPIC               Add TOPIC to active_topics (idempotent)" >&2
    echo "  $0 remove TOPIC            Remove TOPIC from active_topics (idempotent)" >&2
    echo "  $0 set TASK_NUM TOPIC      Assign TOPIC to task and add to active_topics" >&2
    echo "  $0 validate TOPIC          Exit 0 if TOPIC exists, exit 1 if not" >&2
    echo "" >&2
    echo "Exit codes: 0=success/found, 1=not-found/bad-args, 2=state.json-error," >&2
    echo "            3=jq-write-failure, 4=task-not-found" >&2
    exit 1
    ;;

esac
