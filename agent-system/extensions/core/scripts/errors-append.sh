#!/usr/bin/env bash
# errors-append.sh - Validated writer for the specs/errors.json error-tracking store
#
# Usage:
#   errors-append.sh append --type TYPE --severity SEVERITY --message "..." \
#     [--session SESSION_ID] [--command CMD] [--task N] [--phase N] [--checkpoint NAME] \
#     [--agent NAME] [--file PATH] \
#     [--delegation-path-json '["a","b"]'] [--failed-at-depth N] \
#     [--suggested-action "..."] [--auto-recoverable true|false]
#
#   errors-append.sh update --id ERR_ID --fix-status STATUS \
#     [--fixed-date ISO8601] [--fix-task N]
#
# Single responsibility: build/mutate the specs/errors.json document.
#   append: build one validated error record via `jq -c -n`-shaped construction (never string
#     concatenation) and merge it into the document's `.errors` array, creating the file lazily
#     with `{"errors": []}` on first use.
#   update: locate an existing record by `id` and mutate its `fix_status`/`fixed_date`/`fix_task`,
#     under the SAME `flock` discipline as `append` -- unlike the strictly append-only
#     specs/events.jsonl, errors.json records are living state, mutated in place.
#
# See context/formats/errors-format.md for the full field/CLI contract and
# context/schemas/errors-schema.json for the formal JSON Schema. Both subcommands hold `flock -x`
# across the entire read -> transform -> temp-write -> validate -> atomic-`mv` sequence, and
# validate the MERGED document (not the delta) before the `mv` -- on any failure the original
# file is left untouched and the script exits 1.
#
# Exit codes:
#   0 - Success
#   1 - Error (missing/invalid arguments, invalid enum value, malformed JSON, unmatched id,
#       shape-validation failure, ...)
#
# Outputs:
#   stdout: the id of the appended/updated record
#   stderr: diagnostic/error messages

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: errors-append.sh append --type TYPE --severity SEVERITY --message "..." \
  [--session SESSION_ID] [--command CMD] [--task N] [--phase N] [--checkpoint NAME] \
  [--agent NAME] [--file PATH] \
  [--delegation-path-json '["a","b"]'] [--failed-at-depth N] \
  [--suggested-action "..."] [--auto-recoverable true|false]

       errors-append.sh update --id ERR_ID --fix-status STATUS \
  [--fixed-date ISO8601] [--fix-task N]

append -- create a new error record:
  Required:
    --type TYPE            Open string naming the specific kind of error
    --severity SEVERITY    One of: critical|high|medium|low
    --message "..."        Short human-readable one-line summary
  Optional (context):
    --session SESSION_ID   sess_{timestamp}_{random} value
    --command CMD           Invoking command, e.g. /implement
    --task N                 Bare (unpadded) task/project number
    --phase N                 Implementation phase number
    --checkpoint NAME        Lifecycle checkpoint name
    --agent NAME              Subagent type/name involved
    --file PATH                Relevant file path
  Optional (trajectory):
    --delegation-path-json '[...]'  JSON array of delegation hops
    --failed-at-depth N              0-indexed depth into delegation-path-json
  Optional (recovery):
    --suggested-action "..."  Human-readable suggested next step
    --auto-recoverable true|false  Whether the error is expected to self-resolve

update -- mutate an existing record's fix status:
  Required:
    --id ERR_ID             The target record's id
    --fix-status STATUS     One of: unfixed|in_progress|fixed (NOT resolved -- deprecated,
                             rejected as an input value)
  Optional:
    --fixed-date ISO8601    Defaults to now when --fix-status fixed is given and omitted
    --fix-task N            Bare integer: the fixing task's number
USAGE
  exit 1
}

if [ $# -eq 0 ]; then
  echo "error: missing subcommand (must be 'append' or 'update')" >&2
  usage
fi

subcommand="$1"
shift

case "$subcommand" in
  append|update) ;;
  -h|--help) usage ;;
  *)
    echo "error: unknown subcommand: $subcommand (must be 'append' or 'update')" >&2
    usage
    ;;
esac

# --- Paths (resolved once, shared by both subcommands) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
ERRORS_FILE="$PROJECT_ROOT/specs/errors.json"
LOCK_FILE="$PROJECT_ROOT/specs/.errors.lock"

# =====================================================================================
# append
# =====================================================================================
if [ "$subcommand" = "append" ]; then
  error_type=""
  severity=""
  message=""
  session=""
  command=""
  task=""
  phase=""
  checkpoint=""
  agent=""
  file=""
  delegation_path_json=""
  failed_at_depth=""
  suggested_action=""
  auto_recoverable=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --type) error_type="${2:-}"; shift 2 ;;
      --severity) severity="${2:-}"; shift 2 ;;
      --message) message="${2:-}"; shift 2 ;;
      --session) session="${2:-}"; shift 2 ;;
      --command) command="${2:-}"; shift 2 ;;
      --task) task="${2:-}"; shift 2 ;;
      --phase) phase="${2:-}"; shift 2 ;;
      --checkpoint) checkpoint="${2:-}"; shift 2 ;;
      --agent) agent="${2:-}"; shift 2 ;;
      --file) file="${2:-}"; shift 2 ;;
      --delegation-path-json) delegation_path_json="${2:-}"; shift 2 ;;
      --failed-at-depth) failed_at_depth="${2:-}"; shift 2 ;;
      --suggested-action) suggested_action="${2:-}"; shift 2 ;;
      --auto-recoverable) auto_recoverable="${2:-}"; shift 2 ;;
      -h|--help) usage ;;
      *) echo "error: unknown argument: $1" >&2; usage ;;
    esac
  done

  # --- Validate required arguments (fail loudly, write nothing) ---
  if [ -z "$error_type" ] || [ -z "$severity" ] || [ -z "$message" ]; then
    echo "error: --type, --severity, and --message are all required" >&2
    usage
  fi

  # --- Validate --severity against the closed enum ---
  case "$severity" in
    critical|high|medium|low) ;;
    *)
      echo "error: invalid --severity '$severity' (must be one of: critical|high|medium|low)" >&2
      exit 1
      ;;
  esac

  # --- Validate --task, --phase, --failed-at-depth are bare integers if given ---
  for pair in "task:$task" "phase:$phase" "failed-at-depth:$failed_at_depth"; do
    name="${pair%%:*}"
    value="${pair#*:}"
    if [ -n "$value" ] && ! [[ "$value" =~ ^[0-9]+$ ]]; then
      echo "error: --$name must be a bare integer, got: $value" >&2
      exit 1
    fi
  done

  # --- Validate --auto-recoverable is exactly true or false if given ---
  if [ -n "$auto_recoverable" ] && [ "$auto_recoverable" != "true" ] && [ "$auto_recoverable" != "false" ]; then
    echo "error: --auto-recoverable must be exactly 'true' or 'false', got: $auto_recoverable" >&2
    exit 1
  fi

  # --- Validate --delegation-path-json parses and is a JSON array if given ---
  if [ -n "$delegation_path_json" ]; then
    if ! echo "$delegation_path_json" | jq -e 'type == "array"' > /dev/null 2>&1; then
      echo "error: --delegation-path-json is not valid JSON, or is not a JSON array: $delegation_path_json" >&2
      exit 1
    fi
  fi

  # --- Generate id and timestamp ---
  timestamp_ms=$(date -u +%s%3N)
  random6=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 6 || true)
  if [ -z "$random6" ] || [ "${#random6}" -lt 6 ]; then
    # Fallback if /dev/urandom is unavailable or too slow to yield 6 chars
    random6=$(printf '%06x' "$RANDOM$RANDOM" | tail -c 6)
  fi
  id="err_${timestamp_ms}_${random6}"
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

  trajectory_present=false
  [ -n "$delegation_path_json" ] || [ -n "$failed_at_depth" ] && trajectory_present=true
  recovery_present=false
  [ -n "$suggested_action" ] || [ -n "$auto_recoverable" ] && recovery_present=true

  # --- Build the record via jq -c -n (never string concatenation) ---
  record=$(jq -c -n \
    --arg id "$id" \
    --arg timestamp "$timestamp" \
    --arg type "$error_type" \
    --arg severity "$severity" \
    --arg message "$message" \
    --arg session "$session" \
    --arg command "$command" \
    --arg task "$task" \
    --arg phase "$phase" \
    --arg checkpoint "$checkpoint" \
    --arg agent "$agent" \
    --arg file "$file" \
    --argjson trajectory_present "$trajectory_present" \
    --argjson recovery_present "$recovery_present" \
    --argjson delegation_path "${delegation_path_json:-null}" \
    --arg failed_at_depth "$failed_at_depth" \
    --arg suggested_action "$suggested_action" \
    --arg auto_recoverable "$auto_recoverable" \
    '
    def strOrNull: if . == "" then null else . end;
    def intOrNull: if . == "" then null else (. | tonumber) end;

    ({
      session_id: ($session | strOrNull),
      command: ($command | strOrNull),
      task: ($task | intOrNull),
      phase: ($phase | intOrNull),
      checkpoint: ($checkpoint | strOrNull),
      agent: ($agent | strOrNull),
      file: ($file | strOrNull)
    } | with_entries(select(.value != null))) as $context
    |
    (if $trajectory_present then
      ({
        delegation_path: $delegation_path,
        failed_at_depth: ($failed_at_depth | intOrNull)
      } | with_entries(select(.value != null)))
    else null end) as $trajectory
    |
    (if $recovery_present then
      ({
        suggested_action: ($suggested_action | strOrNull),
        auto_recoverable: (if $auto_recoverable == "" then null else ($auto_recoverable == "true") end)
      } | with_entries(select(.value != null)))
    else null end) as $recovery
    |
    {
      id: $id,
      timestamp: $timestamp,
      type: $type,
      severity: $severity,
      message: $message,
      context: $context
    }
    + (if $trajectory != null then {trajectory: $trajectory} else {} end)
    + (if $recovery != null then {recovery: $recovery} else {} end)
    + {fix_status: "unfixed"}
    ')

  # --- Append under flock -x, holding the lock across the entire read -> merge -> validate ->
  #     mv sequence. Validates the MERGED document (not the delta) before the mv. ---
  (
    flock -x 200

    if [ ! -f "$ERRORS_FILE" ]; then
      printf '%s\n' '{"errors": []}' > "$ERRORS_FILE"
    fi

    current=$(cat "$ERRORS_FILE")
    if ! echo "$current" | jq -e '.errors | type == "array"' > /dev/null 2>&1; then
      echo "error: $ERRORS_FILE does not have the expected {\"errors\": [...]} shape; refusing to write" >&2
      exit 1
    fi

    tmp_file="${ERRORS_FILE%/*}/.errors.json.tmp.$$"
    if ! echo "$current" | jq --argjson rec "$record" '.errors += [$rec]' > "$tmp_file" 2>/dev/null; then
      rm -f "$tmp_file"
      echo "error: failed to build merged errors.json document" >&2
      exit 1
    fi

    if ! jq -e '(.errors | type == "array") and (.errors | length >= 1)' "$tmp_file" > /dev/null 2>&1; then
      rm -f "$tmp_file"
      echo "error: merged document failed shape validation; aborting write" >&2
      exit 1
    fi

    mv "$tmp_file" "$ERRORS_FILE"
  ) 200> "$LOCK_FILE"

  echo "$id"
  exit 0
fi

# =====================================================================================
# update
# =====================================================================================
echo "error: 'update' subcommand not yet implemented" >&2
exit 1
