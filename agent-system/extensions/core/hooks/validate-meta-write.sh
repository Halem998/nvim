#!/usr/bin/env bash
# PostToolUse hook: detect direct writes to .claude/ paths during /meta execution
# Triggers on Write/Edit targeting .claude/ system files
# Returns additionalContext (advisory) with corrective message - does NOT block
#
# This mirrors validate-plan-write.sh but for the /meta anti-bypass pattern.

set -euo pipefail

# Parse file path from stdin (PostToolUse hook input)
if [ -t 0 ]; then
  # Fallback: try env var
  FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
else
  INPUT=$(cat) || true
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
  if [ -z "$FILE" ]; then
    FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null) || true
  fi
fi

# Early exit for empty path (~1ms)
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Skip specs/ paths - those are legitimate task management writes
case "$FILE" in
  specs/*|*/specs/*)
    echo '{}'
    exit 0
    ;;
esac

# Check if the path targets .claude/ system files
is_meta_path=false
case "$FILE" in
  .claude/commands/*|*/.claude/commands/*)
    is_meta_path=true
    ;;
  .claude/skills/*|*/.claude/skills/*)
    is_meta_path=true
    ;;
  .claude/agents/*|*/.claude/agents/*)
    is_meta_path=true
    ;;
  .claude/rules/*|*/.claude/rules/*)
    is_meta_path=true
    ;;
  .claude/context/*|*/.claude/context/*)
    is_meta_path=true
    ;;
  .claude/extensions/*|*/.claude/extensions/*)
    is_meta_path=true
    ;;
  .claude/scripts/*|*/.claude/scripts/*)
    is_meta_path=true
    ;;
  .claude/hooks/*|*/.claude/hooks/*)
    is_meta_path=true
    ;;
  */CLAUDE.md)
    is_meta_path=true
    ;;
esac

if [ "$is_meta_path" = "false" ]; then
  echo '{}'
  exit 0
fi

# Path matches a .claude/ system file - inject corrective context
# This is ADVISORY only (additionalContext), not blocking
cat << 'EOF'
{"additionalContext": "WARNING: .claude/ under this repo is a gitignored, disposable deploy artifact regenerated from the source store at agent-system/extensions/**. This write will be silently wiped by the next regeneration. Edit the source store instead: agent-system/extensions/core/** for core system files, or agent-system/extensions/<ext>/** for extension-owned files. See .claude/rules/source-store-deploy-boundary.md for the full rule. This is advisory only and does not block the write."}
EOF

exit 0
