#!/bin/bash
# PostToolUse hook: reject Write/Edit-tool writes of .orchestrator-handoff.json that land
# outside a specs/{NNN}_{SLUG}/ task directory.
#
# WHY: the handoff is the orchestrator's only channel for learning a dispatch's outcome. A
# handoff written to a bare filename resolves against the ambient working directory at
# Write-tool-call time and strands outside the task directory. The orchestrator then finds no
# handoff at the expected path — or worse, finds the PREVIOUS cycle's file still sitting there
# and reports its status as if it were this dispatch's result.
#
# COVERAGE LIMITATION — DELIBERATE, DO NOT "FIX" BY WIDENING THE MATCHER:
#   This hook reads tool_input.file_path, which only Write and Edit tool calls carry. It
#   therefore catches every agent-direct handoff write (the hard-mode wrap-up path — which is
#   the path that actually broke). It is STRUCTURALLY BLIND to handoff writes performed by
#   Bash redirection, as skill_write_orchestrator_handoff in scripts/skill-base.sh does via
#   `jq -n ... > "$handoff_path"`: a Bash tool_input carries the raw, UNEXPANDED command text,
#   in which "$handoff_path" appears verbatim; its resolved value is not present in the hook
#   input and cannot be recovered by any amount of pattern matching. Adding a Bash matcher
#   would produce false confidence, not coverage.
#   That path is protected instead by (a) skill-base.sh building an absolute path from
#   SKILL_REPO_ROOT, and (b) the mechanism-agnostic stray-handoff sweep in
#   skills/skill-orchestrate/SKILL.md Stage 5, which catches a misplaced handoff regardless of
#   how it was written.
#
# Exit 2 (not advisory additionalContext): PostToolUse runs after the write, so this does not
# prevent the file from existing; it surfaces stderr to the model as an error so the stray is
# actually removed and rewritten, rather than silently ignored.

set -uo pipefail

# Parse file path from stdin (PostToolUse hook input), with env-var fallback.
if [ -t 0 ]; then
  FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
  fi
fi

# Early exit for empty path (~1ms on the overwhelming majority of Write/Edit calls).
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# EXACT basename match only — never a substring or glob. A file merely *containing* the string
# (say, a doc or a test fixture named handoff-example.json) is none of this hook's business.
if [ "$(basename "$FILE")" != ".orchestrator-handoff.json" ]; then
  echo '{}'
  exit 0
fi

# Allowed shapes, absolute or relative:
#   specs/{NNN}_{SLUG}/.orchestrator-handoff.json      (Claude Code tasks)
#   specs/OC_{NNN}_{SLUG}/.orchestrator-handoff.json   (OpenCode tasks)
if printf '%s' "$FILE" | grep -Eq '(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$'; then
  echo '{}'
  exit 0
fi

cat >&2 << EOF
MISPLACED ORCHESTRATOR HANDOFF: $FILE

.orchestrator-handoff.json must be written INSIDE its own task directory:
  specs/{NNN}_{SLUG}/.orchestrator-handoff.json

A handoff written anywhere else is invisible to the orchestrator, which will then either
report a missing handoff or — worse — read the previous cycle's leftover file and report its
status as this dispatch's result.

Remediate now, in this order:
  1. Delete the file you just wrote at $FILE.
  2. Re-write it at the ABSOLUTE path supplied in your delegation context as 'handoff_path'
     (or '{task_dir}/.orchestrator-handoff.json' using the absolute 'task_dir').
  3. If neither field is present in your delegation context, do NOT guess a path — say so
     explicitly in your final message so the orchestrator can detect the gap.

Never write a bare '.orchestrator-handoff.json' filename: it resolves against whatever the
ambient working directory happens to be when the Write tool runs.
EOF

exit 2
