#!/usr/bin/env bash
# literature-create-setup-task.sh - Create a literature sub-index setup task in state.json
#
# Usage: literature-create-setup-task.sh
#
# Creates a new task in specs/state.json to populate specs/literature-index.json by
# scanning the global Literature index and matching doc_ids relevant to this repo.
#
# Outputs the new task number to stdout on success.
# Outputs error messages to stderr.
# Exit 0 on success, exit 1 on failure.
#
# Called from Stage 4a detection block in skill SKILL.md files when --lit is used
# and specs/literature-index.json is missing.

set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Validate state.json exists ---
if [ ! -f "$STATE_FILE" ]; then
  echo "Error: specs/state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Validate jq is available ---
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

# --- Validate state.json is parseable ---
if ! jq empty "$STATE_FILE" 2>/dev/null; then
  echo "Error: specs/state.json is not valid JSON" >&2
  exit 1
fi

# --- Read next task number ---
next_num=$(jq -r '.next_project_number // 1' "$STATE_FILE")
if [ -z "$next_num" ] || [ "$next_num" = "null" ]; then
  echo "Error: Could not read next_project_number from state.json" >&2
  exit 1
fi

# --- Generate task fields ---
task_slug="populate_literature_sub_index"
task_title="Populate literature sub-index for this repo"
task_description="Scan global Literature index (~\/Projects\/Literature\/index.json), analyze this repo's task descriptions and domain keywords, and populate specs\/literature-index.json with relevant doc_ids and relevance annotations. The sub-index schema requires: {\"entries\": [{\"doc_id\": \"<id>\", \"relevance\": \"<note>\", \"source\": \"discover\"}]}. Use project_tags, keywords, and summary fields from the global index entries to determine relevance to this repo's domain."
task_created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Create tmp directory if needed ---
mkdir -p "$PROJECT_ROOT/specs/tmp"

# --- Insert new task into state.json ---
# Use a temp file to avoid corrupting state.json on failure
tmp_file="$PROJECT_ROOT/specs/tmp/state-lit-task.json"

jq --argjson num "$next_num" \
   --arg slug "$task_slug" \
   --arg title "$task_title" \
   --arg desc "$task_description" \
   --arg created "$task_created" \
   '
   .next_project_number = ($num + 1) |
   .active_projects += [{
     "project_number": $num,
     "project_name": $slug,
     "status": "not_started",
     "task_type": "meta",
     "created": $created,
     "last_updated": $created,
     "title": $title,
     "description": $desc,
     "artifacts": [],
     "dependencies": [],
     "next_artifact_number": 1
   }]
   ' "$STATE_FILE" > "$tmp_file"

# --- Validate the output before moving ---
if ! jq empty "$tmp_file" 2>/dev/null; then
  echo "Error: jq produced invalid JSON when inserting task" >&2
  rm -f "$tmp_file"
  exit 1
fi

# --- Atomically replace state.json ---
mv "$tmp_file" "$STATE_FILE"

# --- Sync TODO.md ---
if [ -f "$PROJECT_ROOT/.claude/scripts/generate-todo.sh" ]; then
  bash "$PROJECT_ROOT/.claude/scripts/generate-todo.sh" 2>/dev/null || {
    echo "Warning: generate-todo.sh failed (non-fatal)" >&2
  }
fi

# --- Output new task number to stdout ---
echo "$next_num"
