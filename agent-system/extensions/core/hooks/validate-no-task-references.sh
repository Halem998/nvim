#!/bin/bash
# PostToolUse hook: advisory scan for task-number citations in authored deliverables
# Triggers on Write/Edit to any path outside specs/** (task-management artifacts are exempt --
# task numbers are expected there). Non-blocking: always exits 0, never denies the tool call.
#
# Rationale: .claude/rules/no-task-references-in-deliverables.md -- deliverable files (code,
# docs, .claude/ context/standards/etc.) must not cite ephemeral task-management metadata like
# "task N" or "tasks N-M", since task numbers are renumbered during vault operations and are
# meaningless to a future reader with no access to (or interest in) the task tracker. Durable
# anchors (filenames, section headings, decision-record names) should be used instead.

set -uo pipefail

# ─── Parse tool input from stdin (PostToolUse hook input), env-var fallback ──────────────────
# Mirrors validate-plan-write.sh's stdin/env-fallback parsing pattern.

if [ -t 0 ]; then
  # Fallback: try env var
  FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
  CONTENT=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.content // .new_string // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
    CONTENT=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.content // .new_string // empty' 2>/dev/null)
  fi
fi

# Non-file tools (no file_path resolved) -- exit silently.
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Exempt specs/** (task-management artifacts): the rule's own scope exclusion. Mirrors
# validate-plan-write.sh's specs/*/...|*/specs/*/... glob-pair style so both repo-relative and
# absolute-prefixed paths are exempted.
case "$FILE" in
  specs/*|*/specs/*)
    echo '{}'
    exit 0
    ;;
esac

# No content captured (e.g. a Write/Edit variant this hook doesn't recognize) -- nothing to scan.
if [ -z "$CONTENT" ]; then
  echo '{}'
  exit 0
fi

# Task-number citation pattern: "task N", "tasks N-M", "(task N)", case-insensitive on the
# "task(s)" token. Whole-word boundaries via \b to avoid matching inside larger identifiers.
if echo "$CONTENT" | grep -qiE '\b[Tt]asks?[[:space:]]+[0-9]+(-[0-9]+)?\b'; then
  echo "{\"additionalContext\": \"Reminder: ${FILE} appears to cite a task number (e.g. 'task N' or 'tasks N-M'). Per .claude/rules/no-task-references-in-deliverables.md, deliverable files outside specs/** must not cite ephemeral task-management metadata -- task numbers are renumbered during vault operations and are meaningless to a future reader. Reference a durable anchor instead (a sibling document's filename, a section heading, a decision-record name, or a verified fact) rather than the task number. This is advisory only and does not block the write.\"}"
  exit 0
fi

echo '{}'
exit 0
