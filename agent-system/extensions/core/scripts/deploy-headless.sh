#!/bin/bash
# deploy-headless.sh - Regenerate a repo's .claude/ deploy tree without an interactive picker.
#
# Drives the manifest-driven extension loader (neotex.plugins.ai.shared.extensions.init's
# `manager`) headlessly -- the single deploy engine, reachable both interactively (the picker's
# entries) and from here. This is the ONLY engine as of the deploy-engine consolidation: the
# former glob+allow-list `load_all_globally` path (and the picker's separate "Reload All"
# unload-all/load-all reimplementation) have been retired onto `manager.resync_all` /
# `manager.wipe`, both of which this script now calls.
#
# Two modes:
#   (default, no flag)  Non-destructive resync. Force-loads `core` (bootstrapping it if this is
#                        the first deploy into TARGET_REPO, since a target that has only ever
#                        used the retired glob-based engine has no `core` entry in its
#                        project-root extension state yet -- see the "Bootstrap safety" note
#                        below), then force-resyncs every other currently-active extension via
#                        `manager.resync_all`. Never destructive; never removes anything.
#   --wipe               Full destructive sequence via `manager.wipe`: snapshot
#                        settings.json/settings.local.json/.syncprotect-listed paths -> `rm -rf
#                        .claude` -> reload every formerly-active extension -> restore the
#                        snapshot as the merge base before re-applying settings fragments ->
#                        clear the snapshot staging directory. Refuses (exits 2, .claude left
#                        untouched) if the pre-wipe snapshot itself fails.
#
# Bootstrap safety (why the default mode is NOT a bare `manager.resync_all` call): the
# now-retired `load_all_globally` engine never wrote to a project's extension state file
# (`.claude-extensions.json`) -- it was a stateless glob+copy, not `manager`-driven. Every repo
# that has only ever been deployed via that engine (or via this very script, historically) has
# NO "core" entry in its `.claude-extensions.json`, so `manager.resync_all` alone -- which only
# resyncs extensions the state file already marks active -- would silently deploy nothing on
# such a repo's first post-consolidation run. Force-loading `core` unconditionally first closes
# this gap: it is a no-op-safe re-copy on a repo where core is already active, and a genuine
# bootstrap on one where it isn't.
#
# SAFETY: this overwrites deployed files under .claude/ with their source-store versions (and,
# under --wipe, deletes .claude/ entirely before rebuilding it). It must always be invoked
# deliberately -- never as a silent side effect of an unrelated operation. Files listed in
# .syncprotect are honored by the underlying copy engine and (--wipe only) additionally
# snapshotted/restored across the deletion. Exactly one automated caller is sanctioned to invoke
# this script as part of a larger operation: `skill-orchestrate`'s Stage MT-3 step 7 (the
# inter-cycle redeploy checkpoint) -- see context/patterns/regeneration-is-manual-only.md's
# `## Automated Exception` subsection for the full justification and its explicit "does not
# license any other automated caller" boundary. That subsection also documents this script's
# entry points, which were rewritten as part of the same consolidation this header describes.
#
# SELF-OVERWRITE HAZARD: bash reads a script incrementally by byte offset as it executes it, not
# by loading the whole file into memory upfront. The copy engine's write path overwrites an
# existing target file in place -- with no temp-then-rename indirection. When this script is
# invoked as `bash .claude/scripts/deploy-headless.sh` from inside the very repo it targets (the
# default: TARGET defaults to $(pwd)), the nvim subprocess it launches will overwrite this
# on-disk file mid-execution. A script whose top-level statements are read one at a time would
# resume reading at a stale byte offset into the NEW file content after that overwrite --
# undefined behavior, not merely "the rest of the old script still runs." The fix: this file's
# entire executable body is a single `main()` function, defined in full (and therefore fully
# parsed by bash) BEFORE any of it runs, invoked as the file's last physical command with
# nothing following it. Every exit path inside `main` calls `exit` explicitly -- never `return`
# followed by further top-level reads -- so no code path depends on bytes read after the
# overwrite could occur. Do not undo this structure by moving logic back to top level.
#
# Usage:
#   deploy-headless.sh [TARGET_REPO]         # resync (default): bootstrap-safe, non-destructive
#   deploy-headless.sh --wipe [TARGET_REPO]  # full destructive wipe+regenerate (see above)
#   deploy-headless.sh --dry-run [...]       # report what would run; deploy nothing
#
# Exit codes:
#   0  deploy completed (artifact count reported)
#   1  usage error, target is not a git repository, or nvim unavailable
#   2  the headless Neovim invocation failed, reported no result, or (--wipe only) the pre-wipe
#      snapshot was refused
set -uo pipefail

EXT_CONFIG_MODULE="neotex.plugins.ai.shared.extensions.config"
EXT_INIT_MODULE="neotex.plugins.ai.shared.extensions.init"

# specs/.deploy-lock/ fail-open mutex, mirroring the acquire/warn-and-proceed shape of
# specs/.commit-lock/ (see scripts/git-commit-scoped.sh). Implemented inline, WITHOUT sourcing
# scripts/task-lock.sh: this script is about to overwrite the deployed copy of task-lock.sh
# itself, so depending on it here would mean depending on the very file being replaced.
DEPLOY_LOCK_STALE_SEC="${DEPLOY_LOCK_STALE_SEC:-120}"

main() {
  local DRY_RUN=false
  local WIPE=false
  local TARGET=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --wipe) WIPE=true; shift ;;
      -h|--help)
        sed -n '2,55p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      -*)
        echo "ERROR: unknown flag: $1" >&2
        echo "Usage: deploy-headless.sh [--dry-run] [--wipe] [TARGET_REPO]" >&2
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
    if [ "$WIPE" = "true" ]; then
      echo "  would run   : nvim --headless -> manager.wipe() [DESTRUCTIVE: snapshot -> rm -rf .claude -> regenerate -> restore]"
    else
      echo "  would run   : nvim --headless -> manager.load('core', {force=true}) -> manager.resync_all()"
    fi
    exit 0
  fi

  echo "[deploy-headless] Deploying extension tree into $TARGET/.claude ..."
  echo "[deploy-headless] deploy-lock: $mutex_status"

  # `manager` derives project_dir from the explicit project_dir option below, never from
  # vim.fn.getcwd() implicitly -- cwd is still set to TARGET for module resolution consistency
  # with the rest of the headless invocation. stderr is kept: a require failure or Lua error
  # must remain visible rather than be swallowed.
  local output
  if [ "$WIPE" = "true" ]; then
    output=$(cd "$TARGET" && nvim --headless \
      -c "lua local ok1, ext_config = pcall(require, '${EXT_CONFIG_MODULE}'); local ok2, ext_init = pcall(require, '${EXT_INIT_MODULE}'); if not (ok1 and ok2) then print('DEPLOY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, wok, result = pcall(manager.wipe, {project_dir = '${TARGET}'}); if not pok then print('DEPLOY_ERROR call: ' .. tostring(wok)) elseif not wok then print('DEPLOY_ERROR wipe-refused: ' .. tostring(result)) elseif #result.failed > 0 then local msgs = {}; for _, f in ipairs(result.failed) do table.insert(msgs, f.name .. ': ' .. tostring(f.error)) end; print('DEPLOY_ERROR wipe-partial: ' .. table.concat(msgs, '; ')) else print('DEPLOY_COUNT=' .. tostring(#result.loaded)) end end" \
      -c "qa!" 2>&1)
  else
    output=$(cd "$TARGET" && nvim --headless \
      -c "lua local ok1, ext_config = pcall(require, '${EXT_CONFIG_MODULE}'); local ok2, ext_init = pcall(require, '${EXT_INIT_MODULE}'); if not (ok1 and ok2) then print('DEPLOY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local bok, bsucc, berr = pcall(manager.load, 'core', {confirm = false, force = true, project_dir = '${TARGET}'}); if not bok then print('DEPLOY_ERROR bootstrap-call: ' .. tostring(bsucc)) elseif not bsucc then print('DEPLOY_ERROR bootstrap: ' .. tostring(berr)) else local rok, result = pcall(manager.resync_all, {project_dir = '${TARGET}'}); if not rok then print('DEPLOY_ERROR resync-call: ' .. tostring(result)) elseif #result.failed > 0 then local msgs = {}; for _, f in ipairs(result.failed) do table.insert(msgs, f.name .. ': ' .. tostring(f.error)) end; print('DEPLOY_ERROR resync-partial: ' .. table.concat(msgs, '; ')) else print('DEPLOY_COUNT=' .. tostring(#result.succeeded)) end end end" \
      -c "qa!" 2>&1)
  fi

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

  if [ "$WIPE" = "true" ]; then
    echo "[deploy-headless] Wiped and regenerated $count extension(s) into $TARGET/.claude"
  else
    echo "[deploy-headless] Resynced $count extension(s) into $TARGET/.claude"
  fi
  echo "[deploy-headless] Verify with: bash $TARGET/.claude/scripts/verify-deploy.sh"
  exit 0
}

main "$@"
