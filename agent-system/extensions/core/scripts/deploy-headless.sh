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
# the interactive path.
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

DRY_RUN=false
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
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

if [ "$DRY_RUN" = "true" ]; then
  echo "[deploy-headless] DRY RUN -- nothing will be written."
  echo "  target repo : $TARGET"
  echo "  deploy tree : $TARGET/.claude"
  if [ -d "$TARGET/.claude" ]; then
    echo "  tree exists : yes ($(find "$TARGET/.claude" -type f 2>/dev/null | wc -l) files present)"
  else
    echo "  tree exists : no (would be created)"
  fi
  echo "  would run   : nvim --headless (confirm stubbed) -> ${SYNC_MODULE}.load_all_globally(nil)"
  exit 0
fi

echo "[deploy-headless] Deploying extension tree into $TARGET/.claude ..."

# `load_all_globally` derives its project dir from vim.fn.getcwd(), so cwd must be the target.
# stderr is kept: a require failure or Lua error must remain visible rather than be swallowed.
output=$(cd "$TARGET" && nvim --headless \
  -c "lua vim.fn.confirm = function() return 1 end" \
  -c "lua local ok, sync = pcall(require, '${SYNC_MODULE}'); if not ok then print('DEPLOY_ERROR require: ' .. tostring(sync)) else local ok2, res = pcall(sync.load_all_globally, nil); if ok2 then print('DEPLOY_COUNT=' .. tostring(res)) else print('DEPLOY_ERROR call: ' .. tostring(res)) end end" \
  -c "qa!" 2>&1)

if echo "$output" | grep -q 'DEPLOY_ERROR'; then
  echo "ERROR: headless deploy failed." >&2
  echo "$output" | grep 'DEPLOY_ERROR' >&2
  exit 2
fi

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
