#!/bin/bash
# git-snapshot.sh
# Sanctioned snapshot helper for task 780 (agent git-safety: preserve uncommitted work).
#
# Purpose: write a recoverable, durable snapshot of uncommitted working-tree changes
# BEFORE any destructive git operation (git reset --hard, git checkout -- <path>,
# git restore <path>, git clean -fd, git stash drop/clear, forced checkout/switch),
# and refresh a short-lived freshness marker that guard-destructive-git.sh (the
# PreToolUse Bash hook) checks to decide whether to allow the destructive command.
#
# --- Marker contract (read by .claude/hooks/guard-destructive-git.sh) ---
#   Filename: .git-snapshot-marker
#   Location: task-scoped, written under the resolved task directory
#             (specs/{NNN}_{SLUG}/.git-snapshot-marker)
#   Format:   line-oriented KEY=VALUE, always contains at minimum:
#               TIMESTAMP=<epoch seconds when the snapshot was taken>
#               HEAD_SHA=<git rev-parse HEAD at snapshot time>
#               PATCH_PATH=<path to the durable .patch file, or NONE>
#             plus (best-effort, mode-dependent):
#               STASH_REF=<stash@{N} ref, or NONE>
#               BRANCH_NAME=<wip-snapshot-{ts} branch name, or NONE>
#   Freshness window: 120 seconds. The hook treats a marker older than this window
#             as stale and will NOT honor it (a stale marker does not authorize a
#             later, unrelated destructive command).
#   Consumption: single-shot / delete-on-use. The guard hook deletes the marker file
#             the first time it is consumed to authorize a destructive command, so a
#             fresh snapshot only ever unblocks the ONE destructive command it was
#             taken for.
#   Ignored:  the marker filename is gitignored (**/.git-snapshot-marker); the
#             durable working-progress-*.patch file is NOT gitignored and remains
#             tracked under the task directory for manual recovery if needed.
#
# --- Usage ---
#   git-snapshot.sh [--branch] [TASK]
#     TASK        Task number (e.g. 780), a specs/{NNN}_{SLUG} directory path, or
#                 omitted to infer the single task currently in status "implementing"
#                 from specs/state.json.
#     --branch    Instead of the default stash-based snapshot, create a WIP commit
#                 on a scratch branch (wip-snapshot-{ts}) capturing the dirty tree,
#                 then return to the original branch.
#
#   Default mode: writes specs/{NNN}_{SLUG}/working-progress-{ts}.patch (git diff
#   HEAD) AND runs `git stash push -u` (untracked-inclusive, without drop) as a
#   belt-and-suspenders in-repo copy. Both the patch and the marker are written
#   before the function returns success.
#
#   On a clean working tree, this script is a no-op: it prints a message and exits 0
#   without writing a marker (there is nothing to protect).
#
#   On any failure, this script exits non-zero with a clear message so the caller
#   (an agent about to run a destructive git command) does NOT proceed believing a
#   snapshot exists.

set -uo pipefail

MODE="default"
TASK_ARG=""

for arg in "$@"; do
  case "$arg" in
    --branch)
      MODE="branch"
      ;;
    *)
      TASK_ARG="$arg"
      ;;
  esac
done

# resolve_task_dir: turn a task number / path / empty arg into a specs/{NNN}_{SLUG} dir.
resolve_task_dir() {
  local arg="$1"

  if [ -n "$arg" ]; then
    if [ -d "$arg" ]; then
      echo "$arg"
      return 0
    fi
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      local padded dir
      padded=$(printf "%03d" "$arg")
      dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
      if [ -n "$dir" ]; then
        echo "$dir"
        return 0
      fi
    fi
    return 1
  fi

  # No arg given: infer the single task currently in status "implementing".
  if command -v jq >/dev/null 2>&1 && [ -f specs/state.json ]; then
    local nums count
    nums=$(jq -r '.active_projects[] | select(.status=="implementing") | .project_number' specs/state.json 2>/dev/null)
    count=$(printf '%s\n' "$nums" | grep -c '^[0-9]\+$' || true)
    if [ "$count" = "1" ]; then
      local padded dir
      padded=$(printf "%03d" "$nums")
      dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
      if [ -n "$dir" ]; then
        echo "$dir"
        return 0
      fi
    fi
  fi

  return 1
}

TASK_DIR=$(resolve_task_dir "$TASK_ARG")
if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
  echo "git-snapshot.sh: could not resolve a task directory." >&2
  echo "  Pass it explicitly: git-snapshot.sh [--branch] <task-number-or-specs-dir>" >&2
  exit 1
fi

# Clean-tree check: nothing to snapshot.
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "git-snapshot.sh: nothing to snapshot (working tree is clean)"
  exit 0
fi

TS=$(date +%s)
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
PATCH_PATH="${TASK_DIR}/working-progress-${TS}.patch"
MARKER_PATH="${TASK_DIR}/.git-snapshot-marker"

# Capture the diff to a scratch location OUTSIDE the repo first. Writing it directly
# under $TASK_DIR before stashing would make it an untracked file that `git stash
# push -u` immediately sweeps away (and can delete $TASK_DIR itself if it had no
# other tracked contents). It is moved into place after the stash/branch step below.
PATCH_TMP=$(mktemp)
if ! git diff HEAD > "$PATCH_TMP" 2>/dev/null; then
  echo "git-snapshot.sh: failed to compute diff for $PATCH_PATH" >&2
  rm -f "$PATCH_TMP"
  exit 1
fi

STASH_REF="NONE"
BRANCH_NAME="NONE"

if [ "$MODE" = "branch" ]; then
  ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  BRANCH_NAME="wip-snapshot-${TS}"

  if ! git checkout -b "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create scratch branch $BRANCH_NAME" >&2
    exit 1
  fi
  if ! git add -A >/dev/null 2>&1 || ! git commit -m "wip snapshot ${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create WIP commit on $BRANCH_NAME" >&2
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
    exit 1
  fi
  if ! git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to return to original branch $ORIGINAL_BRANCH after WIP commit on $BRANCH_NAME" >&2
    exit 1
  fi
else
  # Default mode: belt-and-suspenders in-repo stash copy (patch above is the primary
  # durable record; -u also captures untracked files the patch cannot represent).
  if ! git stash push -u -m "git-snapshot-${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to stash changes (diff was computed but not yet written to $PATCH_PATH)" >&2
    rm -f "$PATCH_TMP"
    exit 1
  fi
  STASH_REF=$(git stash list | head -1 | cut -d: -f1)
fi

# Recreate $TASK_DIR in case the stash/branch step removed it (e.g. it contained only
# untracked content that `git stash push -u` swept away), then move the patch into place.
mkdir -p "$TASK_DIR"
if ! mv "$PATCH_TMP" "$PATCH_PATH"; then
  echo "git-snapshot.sh: failed to write patch to $PATCH_PATH (snapshot itself succeeded: stash=$STASH_REF branch=$BRANCH_NAME)" >&2
  rm -f "$PATCH_TMP"
  exit 1
fi

cat > "$MARKER_PATH" << EOF
TIMESTAMP=${TS}
HEAD_SHA=${HEAD_SHA}
PATCH_PATH=${PATCH_PATH}
STASH_REF=${STASH_REF}
BRANCH_NAME=${BRANCH_NAME}
EOF

echo "git-snapshot.sh: snapshot complete"
echo "  patch:  ${PATCH_PATH}"
echo "  stash:  ${STASH_REF}"
echo "  branch: ${BRANCH_NAME}"
echo "  marker: ${MARKER_PATH}"
exit 0
