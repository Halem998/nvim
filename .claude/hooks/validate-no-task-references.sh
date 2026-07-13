#!/bin/bash
# PostToolUse hook: advisory detection of task-number citations in deliverable files
# Triggers on Write/Edit outside specs/**. Never blocks -- additionalContext only.
# Mirrors validate-plan-write.sh / validate-meta-write.sh's input-parsing and output contract.

set -uo pipefail

# Parse file path from stdin (PostToolUse hook input)
if [ -t 0 ]; then
  FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
  fi
fi

if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Skip specs/ paths - task numbers are the allowed use there
case "$FILE" in
  specs/*|*/specs/*)
    echo '{}'
    exit 0
    ;;
esac

# Skip if file doesn't exist (defensive) or isn't a text file we can grep
if [ ! -f "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Scan on-disk content (write has already landed by PostToolUse time)
if grep -Eqi '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE" 2>/dev/null; then
  match=$(grep -Eino '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE" 2>/dev/null | head -3 | tr '\n' ';' )
  cat << EOF
{"additionalContext": "ADVISORY: ${FILE} appears to cite a task number outside specs/** (matches: ${match}). Task numbers are ephemeral work-management metadata and get renumbered during vault operations -- deliverable files should reference durable anchors (sibling doc filenames, section headings, decision-record names) instead. See .claude/rules/no-task-references-in-deliverables.md. This is advisory only; no action is required if this is a false positive."}
EOF
  exit 0
fi

echo '{}'
exit 0
