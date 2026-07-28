#!/bin/bash
# deploy-headless.sh - Regenerate a repo's .claude/ deploy tree without an interactive picker.
#
# The interactive path is `<leader>al` -> "Load All" -> "Sync all (replace existing)". That
# route is gated behind a vim.fn.confirm() dialog, which is correct for a human at a terminal
# but unusable from a script, a CI job, or an agent dispatch.
#
# This script drives the SAME code path headlessly. `M.load_all_globally` is an exported entry
# point; the only interactive element is the confirm dialog, which is stubbed to return 1
# ("Sync all (replace existing)" when replacements are pending, "Add all" when only additions
# are -- both the intended full-deploy choice) before the call is made.
#
# See context/patterns/regeneration-is-manual-only.md for why this is a legitimate headless
# equivalent rather than a bypass of a safety contract, and for the merge semantics that no
# regeneration can repair (install-once root files; add-only, object-granularity dedup).
#
# SAFETY: this overwrites deployed files under .claude/ with their source-store versions. It
# must always be invoked deliberately -- never as a silent side effect of an unrelated
# operation. Files listed in .syncprotect are honored by the underlying sync, as they are on
# the interactive path. Exactly one automated caller is sanctioned to invoke this script as
# part of a larger operation: `skill-orchestrate`'s Stage MT-3 step 7 (the inter-cycle redeploy
# checkpoint) -- see context/patterns/regeneration-is-manual-only.md's `## Automated Exception`
# subsection for the full justification and its explicit "does not license any other automated
# caller" boundary.
#
# SELF-OVERWRITE HAZARD: bash reads a script incrementally by byte offset as it executes it, not
# by loading the whole file into memory upfront. `helpers.write_file` (the sync's write path,
# `vim.fn.writefile`) overwrites an existing target file in place -- "An existing file is
# overwritten, if possible" per Neovim's own writefile() documentation, with no temp-then-rename
# indirection. When this script is invoked as `bash .claude/scripts/deploy-headless.sh` from
# inside the very repo it targets (the default: TARGET defaults to $(pwd)), the nvim subprocess
# it launches will overwrite this on-disk file mid-execution. A script whose top-level statements
# are read one at a time would resume reading at a stale byte offset into the NEW file content
# after that overwrite -- undefined behavior, not merely "the rest of the old script still runs."
# The fix: this file's entire executable body is a single `main()` function, defined in full
# (and therefore fully parsed by bash) BEFORE any of it runs, invoked as the file's last physical
# command with nothing following it. Every exit path inside `main` calls `exit` explicitly --
# never `return` followed by further top-level reads -- so no code path depends on bytes read
# after the overwrite could occur. Do not undo this structure by moving logic back to top level.
#
# Usage:
#   deploy-headless.sh [TARGET_REPO]   # defaults to the current working directory
#   deploy-headless.sh --dry-run [...] # report what would run; deploy nothing
#
# Exit codes:
#   0  deploy completed (artifact count reported)
#   1  usage error, target is not a git repository, or nvim unavailable
#   2  the headless Neovim invocation failed or reported no result

set -uo pipefail

SYNC_MODULE="neotex.plugins.ai.claude.commands.picker.operations.sync"

# specs/.deploy-lock/ fail-open mutex, mirroring the acquire/warn-and-proceed shape of
# specs/.commit-lock/ (see scripts/git-commit-scoped.sh). Implemented inline, WITHOUT sourcing
# scripts/task-lock.sh: this script is about to overwrite the deployed copy of task-lock.sh
# itself, so depending on it here would mean depending on the very file being replaced.
DEPLOY_LOCK_STALE_SEC="${DEPLOY_LOCK_STALE_SEC:-120}"

main() {
  local DRY_RUN=false
  local TARGET=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help)
        sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      -*)
        echo "ERROR: unknown flag: $1" >&2
        echo "Usage: deploy-headless.sh [--dry-run] [TARGET_REPO]" >&2
        exit 1
        ;;
      *)
        if [ -n "$TARGET" ]; then
          echo "ERROR: more than one target given: '$TARGET' and '$1'" >&2
          exit 1
        fi
        TARGET="$1"; shift
        ;;
    esac
  done

  TARGET="${TARGET:-$(pwd)}"

  if [ ! -d "$TARGET" ]; then
    echo "ERROR: target is not a directory: $TARGET" >&2
    exit 1
  fi

  TARGET="$(cd "$TARGET" && pwd)"

  # Refuse to deploy into a non-repository. The deploy tree is gitignored-but-repo-scoped; running
  # this in an arbitrary directory would scatter 200+ files somewhere the user did not intend.
  if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not a git repository: $TARGET" >&2
    echo "Refusing to deploy the extension tree outside a repository." >&2
    exit 1
  fi

  if ! command -v nvim >/dev/null 2>&1; then
    echo "ERROR: nvim not found on PATH; cannot run the headless deploy." >&2
    exit 1
  fi

  # --- Mutex acquisition (attempted for both --dry-run and a live deploy; fail-open, non-blocking) ---
  # Ensure the parent specs/ directory exists first (non-atomic, harmless if it races with another
  # mkdir -p) so the leaf directory create below is the sole atomic-on-creation mutex primitive.
  mkdir -p "$TARGET/specs" 2>/dev/null || true
  local deploy_lock_dir="$TARGET/specs/.deploy-lock"
  local mutex_owned_here=false
  local mutex_status=""

  release_deploy_mutex() {
    if [ "$mutex_owned_here" = "true" ]; then
      rm -rf "$deploy_lock_dir" 2>/dev/null || true
      mutex_owned_here=false
    fi
  }
  trap release_deploy_mutex EXIT

  if mkdir "$deploy_lock_dir" 2>/dev/null; then
    { echo "pid=$$"; echo "claimed_at=$(date +%s)"; echo "session=${DEPLOY_SESSION:-unknown}"; } \
      > "$deploy_lock_dir/owner" 2>/dev/null || true
    mutex_owned_here=true
    mutex_status="acquired (this invocation, pid $$)"
  else
    local claimed_at="" age=999999
    claimed_at="$(grep -o 'claimed_at=[0-9]*' "$deploy_lock_dir/owner" 2>/dev/null | cut -d= -f2)"
    if [ -n "$claimed_at" ]; then
      age=$(( $(date +%s) - claimed_at ))
    fi
    if [ "$age" -gt "$DEPLOY_LOCK_STALE_SEC" ]; then
      echo "WARN: reclaiming stale specs/.deploy-lock mutex (age ${age}s > ${DEPLOY_LOCK_STALE_SEC}s threshold)." >&2
      rm -rf "$deploy_lock_dir" 2>/dev/null || true
      if mkdir "$deploy_lock_dir" 2>/dev/null; then
        { echo "pid=$$"; echo "claimed_at=$(date +%s)"; echo "session=${DEPLOY_SESSION:-unknown}"; } \
          > "$deploy_lock_dir/owner" 2>/dev/null || true
        mutex_owned_here=true
        mutex_status="acquired (reclaimed stale lock, age ${age}s)"
      else
        echo "WARNING: failed to acquire specs/.deploy-lock mutex even after stale reclaim attempt; proceeding unserialized (non-blocking, fail-open). A concurrent redeploy racing this one could corrupt the .claude/ tree." >&2
        mutex_status="not acquired (reclaim race lost); proceeding unserialized (fail-open)"
      fi
    else
      echo "WARNING: failed to acquire specs/.deploy-lock mutex (held, age ${age}s <= ${DEPLOY_LOCK_STALE_SEC}s threshold -- another session's deploy appears in progress); proceeding unserialized (non-blocking, fail-open). A concurrent redeploy racing this one could corrupt the .claude/ tree." >&2
      mutex_status="not acquired (held by other, age ${age}s); proceeding unserialized (fail-open)"
    fi
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "[deploy-headless] DRY RUN -- nothing will be written."
    echo "  target repo : $TARGET"
    echo "  deploy tree : $TARGET/.claude"
    if [ -d "$TARGET/.claude" ]; then
      echo "  tree exists : yes ($(find "$TARGET/.claude" -type f 2>/dev/null | wc -l) files present)"
    else
      echo "  tree exists : no (would be created)"
    fi
    echo "  deploy-lock : $mutex_status"
    echo "  would run   : nvim --headless (confirm stubbed) -> ${SYNC_MODULE}.load_all_globally(nil)"
    exit 0
  fi

  echo "[deploy-headless] Deploying extension tree into $TARGET/.claude ..."
  echo "[deploy-headless] deploy-lock: $mutex_status"

  # `load_all_globally` derives its project dir from vim.fn.getcwd(), so cwd must be the target.
  # stderr is kept: a require failure or Lua error must remain visible rather than be swallowed.
  local output
  output=$(cd "$TARGET" && nvim --headless \
    -c "lua vim.fn.confirm = function() return 1 end" \
    -c "lua local ok, sync = pcall(require, '${SYNC_MODULE}'); if not ok then print('DEPLOY_ERROR require: ' .. tostring(sync)) else local ok2, res = pcall(sync.load_all_globally, nil); if ok2 then print('DEPLOY_COUNT=' .. tostring(res)) else print('DEPLOY_ERROR call: ' .. tostring(res)) end end" \
    -c "qa!" 2>&1)

  if echo "$output" | grep -q 'DEPLOY_ERROR'; then
    echo "ERROR: headless deploy failed." >&2
    echo "$output" | grep 'DEPLOY_ERROR' >&2
    exit 2
  fi

  local count
  count=$(echo "$output" | grep -o 'DEPLOY_COUNT=[0-9]*' | head -1 | cut -d= -f2)

  if [ -z "$count" ]; then
    echo "ERROR: headless deploy produced no result count; treating as failure." >&2
    echo "--- nvim output ---" >&2
    echo "$output" >&2
    exit 2
  fi

  echo "[deploy-headless] Deployed $count artifact(s) into $TARGET/.claude"
  echo "[deploy-headless] Verify with: bash $TARGET/.claude/scripts/verify-deploy.sh"
  exit 0
}

main "$@"
