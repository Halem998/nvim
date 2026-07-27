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

# Separator group between "task(s)"/"phase" and its number: whitespace (optionally followed by
# "#"), or a single "-", "_", "#". An explicit alternation, NOT a bracket class containing "-"
# (a "-" inside a bracket class can be silently read as a range operator depending on position;
# alternation avoids that trap entirely). Covers "task N", "task-N", "task_N", "task#N", and
# "Task #N" alike (using letter placeholders here rather than a concrete digit sequence, so this
# comment itself does not incidentally match the pattern it describes).
TASK_SEP='([[:space:]]+#?|[-_#])'

# Task-number citation pattern: "task N", "tasks N-M", "task-N", "task_N", "task#N", "Task #N",
# case-insensitive on the "task(s)" token (grep -i handles case; [Tt] kept for readability).
# Whole-word boundaries via \b to avoid matching inside larger identifiers (e.g. "taskbarN").
TASK_PATTERN="\\b[Tt]asks?${TASK_SEP}[0-9]+(-[0-9]+)?\\b"

# Task-qualified compound Phase pattern: "task N phase P" or "phase P of task N" only. A bare
# "Phase N" with no adjacent task reference is deliberately NOT matched here -- it is
# indistinguishable from a document's own internal structure (plan headings, skill pipeline
# stages) and would generate constant false positives. The compound form is unambiguously a
# citation of a specs/-scoped plan's internals. Anchored on the same TASK_SEP separator group so
# a hyphenated compound like "task-N phase-P" is caught too.
PHASE_PATTERN="\\b([Tt]asks?${TASK_SEP}[0-9]+[[:space:]]+[Pp]hase${TASK_SEP}[0-9]+|[Pp]hase${TASK_SEP}[0-9]+[[:space:]]+of[[:space:]]+[Tt]asks?${TASK_SEP}[0-9]+)\\b"

if echo "$CONTENT" | grep -qiE "$PHASE_PATTERN"; then
  echo "{\"additionalContext\": \"Reminder: ${FILE} appears to cite a task-qualified phase reference (e.g. 'task N phase P' or 'phase P of task N'). Per .claude/rules/no-task-references-in-deliverables.md, deliverable files outside specs/** must not cite ephemeral task-management metadata -- task numbers (and phase references scoped to them) are renumbered during vault operations and are meaningless to a future reader. Reference a durable anchor instead (a sibling document's filename, a section heading, a decision-record name, or a verified fact) rather than the task/phase number. This is advisory only and does not block the write.\"}"
  exit 0
fi

if echo "$CONTENT" | grep -qiE "$TASK_PATTERN"; then
  echo "{\"additionalContext\": \"Reminder: ${FILE} appears to cite a task number (e.g. 'task N', 'tasks N-M', 'task-N', 'task_N', or 'Task #N'). Per .claude/rules/no-task-references-in-deliverables.md, deliverable files outside specs/** must not cite ephemeral task-management metadata -- task numbers are renumbered during vault operations and are meaningless to a future reader. Reference a durable anchor instead (a sibling document's filename, a section heading, a decision-record name, or a verified fact) rather than the task number. This is advisory only and does not block the write.\"}"
  exit 0
fi

echo '{}'
exit 0
