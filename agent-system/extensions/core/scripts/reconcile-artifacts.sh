#!/usr/bin/env bash
# reconcile-artifacts.sh - Backfill missing artifact registrations in state.json
#
# Scans all active task directories for .md files in reports/, plans/, and summaries/
# that are not yet registered in state.json, and appends them with append-only semantics.
# Unlike postflight scripts, this does NOT remove existing artifacts of the same type
# (preserves team research with multiple report files).
#
# Usage:
#   .claude/scripts/reconcile-artifacts.sh [--dry-run]
#
# Options:
#   --dry-run  Print what would be backfilled without modifying state.json
#
# Exit codes:
#   0 - Success (no-op or backfill applied)
#   1 - Error (state.json missing or unreadable)

set -uo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Argument parsing ---
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *)
      echo "Usage: $0 [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# --- Validate state.json ---
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

if ! jq empty "$STATE_FILE" 2>/dev/null; then
  echo "Error: state.json is not valid JSON" >&2
  exit 1
fi

# --- Helper: convert filename to human-readable summary text ---
filename_to_summary() {
  local filename="$1"   # e.g. "01_initial-research.md"
  local subdir="$2"     # e.g. "reports"
  local base="${filename%.md}"
  # Remove leading NN_ prefix
  local readable="${base#[0-9][0-9]_}"
  # Replace hyphens and underscores with spaces
  readable="${readable//-/ }"
  readable="${readable//_/ }"
  echo "$readable (backfilled by --sync)"
}

# --- Helper: infer artifact type from subdirectory ---
subdir_to_type() {
  local subdir="$1"
  case "$subdir" in
    reports)   echo "report" ;;
    plans)     echo "plan" ;;
    summaries) echo "summary" ;;
    *)         echo "unknown" ;;
  esac
}

# --- Counters ---
total_backfilled=0
tasks_with_backfill=0

# --- Main loop: iterate over all active tasks ---
while IFS='|' read -r task_num task_slug; do
  [[ -z "$task_num" ]] && continue

  # Resolve task directory (try padded form first, then unpadded)
  PADDED_NUM=$(printf "%03d" "$task_num")
  TASK_DIR=""
  if [[ -d "$PROJECT_ROOT/specs/${PADDED_NUM}_${task_slug}" ]]; then
    TASK_DIR="$PROJECT_ROOT/specs/${PADDED_NUM}_${task_slug}"
  elif [[ -d "$PROJECT_ROOT/specs/${task_num}_${task_slug}" ]]; then
    TASK_DIR="$PROJECT_ROOT/specs/${task_num}_${task_slug}"
  else
    # No directory found for this task — skip silently
    continue
  fi

  task_backfilled=0

  # --- Scan each artifact subdirectory ---
  for subdir in reports plans summaries; do
    artifact_dir="${TASK_DIR}/${subdir}"
    [[ -d "$artifact_dir" ]] || continue

    # Find all .md files in this subdirectory
    while IFS= read -r -d '' artifact_file; do
      [[ -f "$artifact_file" ]] || continue
      filename="$(basename "$artifact_file")"

      # Build relative path from project root
      rel_path="${artifact_file#$PROJECT_ROOT/}"

      # Check if this path is already registered in state.json
      existing=$(jq -r --argjson num "$task_num" \
        '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[].path] | .[]' \
        "$STATE_FILE" 2>/dev/null) || existing=""

      if echo "$existing" | grep -qF "$rel_path"; then
        # Already registered — skip
        continue
      fi

      # Determine artifact type and summary
      artifact_type="$(subdir_to_type "$subdir")"
      summary="$(filename_to_summary "$filename" "$subdir")"

      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Would backfill: task=$task_num type=$artifact_type path=$rel_path"
      else
        # Append-only registration (no remove-by-type step)
        mkdir -p "$PROJECT_ROOT/specs/tmp"
        jq --argjson num "$task_num" \
           --arg path "$rel_path" \
           --arg type "$artifact_type" \
           --arg summary "$summary" \
          '(.active_projects[] | select(.project_number == $num)).artifacts =
            ((.active_projects[] | select(.project_number == $num)).artifacts // []) +
            [{"path": $path, "type": $type, "summary": $summary}]' \
          "$STATE_FILE" > "$PROJECT_ROOT/specs/tmp/state-reconcile.json" \
          && mv "$PROJECT_ROOT/specs/tmp/state-reconcile.json" "$STATE_FILE"
        echo "[reconcile] Backfilled: task=$task_num type=$artifact_type path=$rel_path"
      fi

      task_backfilled=$((task_backfilled + 1))
      total_backfilled=$((total_backfilled + 1))

    done < <(find "$artifact_dir" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
  done

  if [[ "$task_backfilled" -gt 0 ]]; then
    tasks_with_backfill=$((tasks_with_backfill + 1))
  fi

done < <(jq -r '.active_projects[] | "\(.project_number)|\(.project_name)"' "$STATE_FILE")

# --- Report summary ---
if [[ "$total_backfilled" -eq 0 ]]; then
  echo "[reconcile] No artifact gaps found"
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "[reconcile] Dry run: would backfill $total_backfilled artifact(s) for $tasks_with_backfill task(s)"
else
  echo "[reconcile] Backfilled $total_backfilled artifact(s) for $tasks_with_backfill task(s)"
fi

exit 0
