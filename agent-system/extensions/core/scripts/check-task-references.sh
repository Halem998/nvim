#!/usr/bin/env bash
# check-task-references.sh
#
# Repo-wide lint gate for rules/no-task-references-in-deliverables.md: scans every git-tracked
# file under four deliverable tree roots (agent-system/extensions, .opencode, lua, .memory) for
# unexempted task-number citations, using the SAME shared pattern/exemption library the write-
# time guard hook consumes (scripts/lib/task-reference-patterns.sh). Neither this script nor the
# hook defines TASK_PATTERN, PHASE_PATTERN, or exemption logic locally -- see that library and
# rules/no-task-references-in-deliverables.md's Exemption Taxonomy section for the single source
# of truth both consume.
#
# `specs/**` is the one path-level exemption (task-management artifacts) and is skipped via
# is_exempt_path, matching the taxonomy's category 1.
#
# Exit codes:
#   0 - no unexempted citations found in any scanned tree.
#   1 - one or more unexempted citations found.
#   2 - environment/usage error (shared library missing, git unavailable, unknown flag).
#       Distinct from 1 so a broken script invocation is never mistaken for a clean tree.
#
# Usage:
#   bash .claude/scripts/check-task-references.sh              (verbose: prints every finding)
#   bash .claude/scripts/check-task-references.sh --quiet       (per-tree summary only)
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh
#       (source-store invocation override -- see check-extension-docs.sh for the same pattern;
#       required because .claude/scripts/check-task-references.sh does not exist until a deploy
#       runs)

set -uo pipefail

QUIET=0
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--quiet" ]]; then
    QUIET=1
    shift
  else
    echo "ERROR: unknown flag: $1" >&2
    exit 2
  fi
fi
if [[ $# -gt 0 ]]; then
  echo "ERROR: unexpected extra argument(s): $*" >&2
  exit 2
fi

# ── REPO_ROOT resolution ─────────────────────────────────────────────────────────────────────
# Same convention as check-extension-docs.sh: deploy-root-guard.sh enforces that the computed
# default (SCRIPT_DIR/../..) only resolves from a real deploy tree; a deliberate source-store
# invocation MUST pass REPO_ROOT=$(pwd) explicitly, which bypasses the guard below.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 2
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required and is not on PATH" >&2
  exit 2
fi

# ── Shared library ───────────────────────────────────────────────────────────────────────────
# Sourced from the deployed location first (the ordinary runtime case), falling back to the
# source-store location for REPO_ROOT=$(pwd) source-store invocations where no deploy has
# happened yet (see the "Redeploy checkpoints" note in this task's plan). No patterns or
# exemption logic are defined here -- if the library cannot be found, this is an environment
# error (exit 2), never a silent fall-through to an inline pattern.
LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/task-reference-patterns.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/task-reference-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library task-reference-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

FAILURES=0
info() { [[ $QUIET -eq 0 ]] && echo "$@"; }

TREE_ROOTS=(
  "agent-system/extensions"
  ".opencode"
  "lua"
  ".memory"
)

declare -A TREE_COUNT

scan_tree() {
  local tree="$1"
  local tree_dir="$REPO_ROOT/$tree"
  local count=0

  if [[ ! -d "$tree_dir" ]]; then
    info "  [SKIP] $tree does not exist under $REPO_ROOT"
    TREE_COUNT["$tree"]=0
    return 0
  fi

  local file rel
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    if is_exempt_path "$rel"; then
      continue
    fi

    file="$REPO_ROOT/$rel"
    [[ -f "$file" ]] || continue

    local finding
    while IFS= read -r finding; do
      [[ -z "$finding" ]] && continue
      count=$((count + 1))
      info "  $rel:$finding"
    done < <(strip_exempt_regions < "$file" | grep -nEi "$PHASE_PATTERN|$TASK_PATTERN" 2>/dev/null)
  done < <(git -C "$REPO_ROOT" ls-files "$tree" 2>/dev/null)

  TREE_COUNT["$tree"]="$count"
}

for tree in "${TREE_ROOTS[@]}"; do
  info "Scanning $tree ..."
  scan_tree "$tree"
  info ""
done

TOTAL=0
for tree in "${TREE_ROOTS[@]}"; do
  n="${TREE_COUNT[$tree]:-0}"
  TOTAL=$((TOTAL + n))
  echo "  $tree: $n occurrence(s)"
done

if [[ "$TOTAL" -gt 0 ]]; then
  echo "FAIL: $TOTAL unexempted task-reference occurrence(s) found across ${#TREE_ROOTS[@]} tree(s)"
  exit 1
else
  echo "PASS: 0 unexempted task-reference occurrences across ${#TREE_ROOTS[@]} tree(s)"
  exit 0
fi
