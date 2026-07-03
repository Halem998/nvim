#!/bin/bash
# guard-destructive-git.sh
# PreToolUse Bash hook: block destructive git commands when the working tree is dirty,
# unless a fresh git-snapshot.sh marker exists (see .claude/scripts/git-snapshot.sh for
# the marker contract) or the tree is already clean.
#
# Modeled line-for-line on .claude/hooks/block-pr-submission.sh: blocks via exit code 2
# + a stderr message (NOT permissionDecision: deny, which is documented-buggy for
# allow-listed Bash(git:*) commands -- GH issues #4669, #13214, #18312).
#
# Guarded patterns (all git operations that discard uncommitted working-tree changes):
#   - git reset --hard
#   - git checkout -- <path>            (pathspec discard form)
#   - git restore <path>                (without --staged; --staged only unstages, safe)
#   - git clean  -f -d (any flag order/clustering, e.g. -fd, -df, -f -d, -xfd)
#   - git stash drop / git stash clear
#   - forced git checkout / git switch  (-f / --force; can silently overwrite changes)
#
# Exemptions (never blocked):
#   - working tree is already clean (git status --porcelain is empty) -- this also
#     auto-exempts the /todo safety-commit + reset --hard/clean -fd rollback flow
#     (.claude/context/standards/git-safety.md), since the safety commit makes the
#     tree clean before the destructive step runs.
#   - a fresh (<=120s old) .git-snapshot-marker exists under specs/**/ (written by
#     .claude/scripts/git-snapshot.sh); the marker is consumed (deleted) on use so it
#     only authorizes the ONE destructive command it was taken for.
#   - non-Bash tool calls / empty command (parse failure) -- never block.

set -uo pipefail

FRESHNESS_WINDOW=120

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Allow through if command is empty (non-Bash tool or parse failure).
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Clean tree -> nothing to lose. Also exempts /todo's post-safety-commit reset --hard
# and git clean -fd (git-safety.md), since the safety commit makes the tree clean first.
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  exit 0
fi

MATCHED=0
REASON=""

# git reset --hard
if echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*--hard\b'; then
  MATCHED=1
  REASON="git reset --hard discards uncommitted working-tree changes"
fi

# git checkout -- <path>  (pathspec discard form)
if [ "$MATCHED" = "0" ] && echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+checkout[^;&|]*[[:space:]]--([[:space:]]|$)'; then
  MATCHED=1
  REASON="git checkout -- <path> discards uncommitted changes to that path"
fi

# git restore <path>  (without --staged; --staged only unstages and is safe)
if [ "$MATCHED" = "0" ]; then
  RESTORE_SEGMENTS=$(echo "$COMMAND" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+restore[^;&|]*')
  if [ -n "$RESTORE_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      if ! echo "$seg" | grep -q -- '--staged'; then
        MATCHED=1
        REASON="git restore <path> (without --staged) discards uncommitted working-tree changes"
        break
      fi
    done <<< "$RESTORE_SEGMENTS"
  fi
fi

# git clean -f -d (any order/clustering, e.g. -fd, -df, -f -d, -xfd)
if [ "$MATCHED" = "0" ]; then
  CLEAN_SEGMENTS=$(echo "$COMMAND" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+clean[^;&|]*')
  if [ -n "$CLEAN_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      HAS_F=0
      HAS_D=0
      echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force' && HAS_F=1
      echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*d[a-zA-Z]*([[:space:]]|$)' && HAS_D=1
      if [ "$HAS_F" = "1" ] && [ "$HAS_D" = "1" ]; then
        MATCHED=1
        REASON="git clean -f -d permanently deletes untracked files and directories"
        break
      fi
    done <<< "$CLEAN_SEGMENTS"
  fi
fi

# git stash drop / git stash clear
if [ "$MATCHED" = "0" ] && echo "$COMMAND" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+stash[[:space:]]+(drop|clear)\b'; then
  MATCHED=1
  REASON="git stash drop/clear permanently discards stashed changes"
fi

# forced git checkout / git switch (-f / --force) -- can silently overwrite local changes
if [ "$MATCHED" = "0" ]; then
  FORCED_SEGMENTS=$(echo "$COMMAND" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+(checkout|switch)[^;&|]*')
  if [ -n "$FORCED_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      if echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force'; then
        MATCHED=1
        REASON="forced git checkout/switch (-f/--force) can silently overwrite uncommitted changes"
        break
      fi
    done <<< "$FORCED_SEGMENTS"
  fi
fi

if [ "$MATCHED" = "0" ]; then
  exit 0
fi

# Destructive pattern matched on a dirty tree: check for a fresh, unconsumed snapshot marker.
NOW=$(date +%s)
BEST_MARKER=""
BEST_TS=0
MARKERS=$(find specs -maxdepth 3 -name ".git-snapshot-marker" -type f 2>/dev/null)
if [ -n "$MARKERS" ]; then
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    ts=$(grep -m1 '^TIMESTAMP=' "$m" 2>/dev/null | cut -d= -f2)
    if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -gt "$BEST_TS" ]; then
      BEST_TS="$ts"
      BEST_MARKER="$m"
    fi
  done <<< "$MARKERS"
fi

if [ -n "$BEST_MARKER" ]; then
  AGE=$(( NOW - BEST_TS ))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -le "$FRESHNESS_WINDOW" ]; then
    rm -f "$BEST_MARKER"
    exit 0
  fi
fi

echo "BLOCKED: $REASON" >&2
echo "The working tree has uncommitted changes and this command would discard them." >&2
echo "Run 'bash .claude/scripts/git-snapshot.sh' first to take a recoverable snapshot" >&2
echo "(writes a .patch under the task directory + a stash backup), then retry the command." >&2
exit 2
