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
#   bash .claude/scripts/check-task-references.sh [--quiet] PATH_SCOPE
#       (scope the scan to a subtree, e.g. agent-system/extensions/core/context -- reports and
#       exits on findings under PATH_SCOPE only. PATH_SCOPE must fall under one of the four
#       TREE_ROOTS below, or the script exits 2. The no-argument and --quiet-only forms are
#       UNCHANGED: all four trees, same per-tree summary lines, same exit codes.)
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh
#       (source-store invocation override -- see check-extension-docs.sh for the same pattern;
#       required because .claude/scripts/check-task-references.sh does not exist until a deploy
#       runs)

set -uo pipefail

QUIET=0
PATH_SCOPE=""
if [[ $# -gt 0 && "$1" == "--quiet" ]]; then
  QUIET=1
  shift
fi
if [[ $# -gt 0 ]]; then
  case "$1" in
    --*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      PATH_SCOPE="${1%/}"
      shift
      ;;
  esac
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

# scan_tree <label> <enum_path>
# <label> is the key TREE_COUNT is reported under; <enum_path> is what is actually passed to
# `git ls-files` for enumeration. For the unscoped (no PATH_SCOPE) case these are identical --
# byte-for-byte the original behavior. PATH_SCOPE mode passes a narrower <enum_path> under the
# same <label> convention so the summary line names the requested subtree.
scan_tree() {
  local label="$1"
  local enum_path="$2"
  local enum_dir="$REPO_ROOT/$enum_path"
  local count=0

  if [[ ! -d "$enum_dir" ]]; then
    info "  [SKIP] $label does not exist under $REPO_ROOT"
    TREE_COUNT["$label"]=0
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
  done < <(git -C "$REPO_ROOT" ls-files "$enum_path" 2>/dev/null)

  TREE_COUNT["$label"]="$count"
}

if [[ -n "$PATH_SCOPE" ]]; then
  # Validate PATH_SCOPE falls under (or equals) one of the four TREE_ROOTS -- a scope outside
  # all four is a usage error, not a silently-empty scan.
  scope_ok=0
  for tree in "${TREE_ROOTS[@]}"; do
    if [[ "$PATH_SCOPE" == "$tree" || "$PATH_SCOPE" == "$tree/"* ]]; then
      scope_ok=1
      break
    fi
  done
  if [[ "$scope_ok" -ne 1 ]]; then
    echo "ERROR: PATH_SCOPE '$PATH_SCOPE' does not fall under any of: ${TREE_ROOTS[*]}" >&2
    exit 2
  fi
  REPORT_KEYS=("$PATH_SCOPE")
  info "Scanning $PATH_SCOPE ..."
  scan_tree "$PATH_SCOPE" "$PATH_SCOPE"
  info ""
else
  REPORT_KEYS=("${TREE_ROOTS[@]}")
  for tree in "${TREE_ROOTS[@]}"; do
    info "Scanning $tree ..."
    scan_tree "$tree" "$tree"
    info ""
  done
fi

TOTAL=0
for key in "${REPORT_KEYS[@]}"; do
  n="${TREE_COUNT[$key]:-0}"
  TOTAL=$((TOTAL + n))
  echo "  $key: $n occurrence(s)"
done

if [[ "$TOTAL" -gt 0 ]]; then
  echo "FAIL: $TOTAL unexempted task-reference occurrence(s) found across ${#REPORT_KEYS[@]} tree(s)"
  exit 1
else
  echo "PASS: 0 unexempted task-reference occurrences across ${#REPORT_KEYS[@]} tree(s)"
  exit 0
fi
