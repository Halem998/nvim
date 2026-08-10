# Implementation Summary: Task #850

**Completed**: 2026-07-11
**Duration**: ~45 minutes

## Overview

Load Core (`<leader>al`) writes newly-deployed `.claude/` core files to disk but performs no git
operation, so newly-created files land untracked with no signal in the completion notice. This
implementation threads the list of newly-copied file paths from `sync_files` through
`execute_sync`, adds a single git query per sync to detect which of those paths are untracked in
the target repo, and appends an advisory "Newly deployed (untracked in git) - review and commit"
section to the existing completion notification. No `git add`/`git commit` is performed anywhere,
non-git targets are guarded and skipped silently, and all existing sync behavior (counts,
`.syncprotect`, extension section preservation, merge re-injection) is unchanged.

## What Changed

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `sync_files`: added a `copied` accumulator; on each successful write where
    `file.action == "copy"`, appends `file.local_path`. Now returns a third value
    `success_count, protected_count, copied` (LuaDoc `@return` updated).
  - `execute_sync`: added a `newly_copied` accumulator and a small `collect(list)` helper; each of
    the 14 `sync_with_protect(...)` call sites now captures the third return value and folds it
    into `newly_copied`.
  - Added new file-local helper `detect_untracked(project_dir, base_dir, copied_paths)`: returns
    `{}` immediately for empty input; guards non-git targets via
    `git -C <project_dir> rev-parse --is-inside-work-tree` (checked via `vim.v.shell_error`,
    mirroring the existing `vim.fn.system` + `vim.fn.shellescape` pattern at sync.lua:128); runs
    one `git status --porcelain --untracked-files=normal -- <base_dir>` query; parses `?? ` lines
    into an untracked set (with directory-prefix handling for untracked-directory entries);
    intersects with `copied_paths` (converted to project-relative paths) and returns a sorted
    relative-path list.
  - `execute_sync`'s notify block: calls `detect_untracked` after `total_synced` is computed and
    appends a capped section (up to 5 entries, then `"... and N more"`, mirroring the existing
    content-audit capping pattern at sync.lua:1138-1155) to the notification string when the
    result is non-empty. The existing `total_synced > 0 or total_protected > 0` gate was left
    unwidened, since a new untracked file always implies `total_synced > 0`.

## Decisions

- Captured the third `sync_files` return value at each of the 14 call sites individually (rather
  than restructuring `sync_with_protect`'s signature) to minimize the diff and keep the existing
  `counts.X, protect_counts.X = ...` assignments visually intact, per the plan's stated mitigation
  for the "third return value breaks callers" risk.
- Modeled `detect_untracked`'s git guard and subprocess calls directly on the established
  `vim.fn.system(...) ` + `vim.fn.shellescape(...)` + `vim.v.shell_error` pattern already used in
  this file (sync.lua:128), for consistency and to avoid introducing a new subprocess idiom.

## Plan Deviations

- **Task 3.1 (Phase 3 verification harness)** altered: the plan suggested intercepting
  notifications to observe the completion message. Intercepting `vim.notify` directly captured
  zero messages because `helpers.notify` passes level strings (`"INFO"`/`"WARN"`) that do not
  match any key in `notify.categories`, so category resolution falls back to a `debug_only`
  `STATUS` category and `vim.notify` is never invoked outside debug mode -- a pre-existing,
  unrelated quirk in the notification-filtering system, not caused by this change. The test
  harness was altered to intercept `helpers_mod.notify` directly instead, which captures the
  exact message string `sync.lua` constructs and is what this task's verification actually needs.
  See `specs/850_sync_untracked_core_scripts/progress/phase-3-progress.json` for the full
  deviation record.

## Verification

- Build: N/A (Lua/Neovim configuration, no compiled build step)
- Tests: Passed -- headless harness (scratch copy of sync.lua with `_test` exports for
  `execute_sync`/`detect_untracked`/`sync_files`, loaded via `dofile`) exercised:
  1. Git-backed target: a newly-copied `task-lock.sh`-style file is listed under "Newly deployed
     (untracked in git)" by project-relative path (`.claude/scripts/task-lock.sh`).
  2. Non-git target: sync completes with no error, `total_synced == 1`, and no untracked section
     in the notification.
  3. Tracked-file case: a copied file that was subsequently `git add`+committed is excluded from
     `detect_untracked`'s result (empty list).
  4. Empty-input short circuit: `detect_untracked` with an empty `copied_paths` list returns `{}`
     without invoking git.
  - Module load: `nvim --headless -c "luafile sync.lua" -c q` exits 0 with no error after each
    phase.
  - Static checks: `grep -rn 'git add\|git commit\|git stage'` across the picker tree returns no
    hits outside an explanatory comment; `git diff` confirms no added line exceeds 100 columns or
    uses a tab.
- Files verified: Yes

## Notes

- `luacheck` is not installed in this environment; line-length and indentation were verified
  manually via `git diff` against the 100-column / 2-space-indent standard in
  `.claude/rules/neovim-lua.md`.
- Out of scope (per plan Non-Goals, unchanged): no auto-stage/auto-commit, no change to
  `task-lock.sh` or the manifest allow-list, and no fix for the `.claude/scripts/` vs
  `.claude/extensions/core/scripts/` duplication noted in the research report as a secondary,
  separate concern.
