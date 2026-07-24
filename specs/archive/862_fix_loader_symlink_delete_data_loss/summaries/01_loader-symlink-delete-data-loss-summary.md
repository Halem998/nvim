# Implementation Summary: Fix Loader Symlink Delete Data Loss

**Completed**: 2026-07-14
**Duration**: approximately 45 minutes across 6 sequential phases

## Overview

Fixed a live data-loss bug in the extension loader (`loader.lua`'s `remove_installed_files()`):
when a symlink-deployed extension (via `install-extension.sh`) was reloaded through the picker's
copy-based loader, files inside symlinked skill directories were destroyed through the symlink's
ancestor-directory resolution, per standard POSIX `unlink()` semantics. The fix makes both the
remove and copy paths symlink-aware under a single ownership rule (the copy engine owns only
paths it created as regular files; symlinked deployed paths belong to `install-extension.sh` and
are never written through or deleted), makes `.syncprotect` protection symmetric between copy and
remove, and restores the two agent/command files that had already been silently flattened from
symlinks into regular files by the pre-fix code.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — Added `find_symlinked_ancestor()`
  (bounded upward walk); rewrote `M.remove_installed_files()` to skip (not delete) any file-level
  symlink or any file reached through a symlinked ancestor directory, returning a new
  `skipped_count`; added a fail-safe branch for when `opts.project_dir` is absent; made
  `M.copy_simple_files()` and `M.copy_skill_dirs()` check for a pre-existing symlink at the
  deployed target before copying and skip entirely (not recording it as owned) when found,
  returning a new `symlink_skipped_count`; added ownership-invariant LuaDoc on all three
  functions.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `manager.unload` now loads `.syncprotect`
  and filters `installed_files`/`data_skeleton_files`/`installed_dirs` before removal (previously
  never called `load_syncprotect` at all), threads `opts.project_dir` into the
  `remove_installed_files` call so the ancestor walk is bounded, and reports protected/symlink
  skip counts in its notification; the rollback path inside `manager.load` applies the same
  `opts.project_dir` threading plus a defense-in-depth `.syncprotect` filter; `manager.load`'s
  copy sequence now accumulates `total_symlink_skipped` and surfaces it in the load notification.
  This file was outside the task's declared `file_scope` but its expansion was established as
  unavoidable during planning (see the plan's Scope section) and approved by the delegating
  orchestrator.
- `.claude/agents/literature-agent.md`, `.claude/commands/literature.md` — restored from
  flattened regular files back to symlinks pointing at their extension source, after verifying
  byte-identical content. Restored via `rm` + `ln -s` (matching HEAD's recorded relative target)
  rather than `git checkout`, per explicit orchestrator direction, since `git checkout -- <path>`
  is blocked by this repo's `guard-destructive-git.sh` hook without a full-tree `git stash`
  snapshot — avoided here because this session had other tasks' unrelated uncommitted work in
  flight.
- `.claude/context/project/neovim/domain/extension-deploy-modes.md` — new domain context document
  recording the dual-deploy-mechanism architecture (symlink installer vs. copy loader), which
  categories use directory-level vs. file-level symlinks, the `vim.fn.delete()` semantics
  distinctions verified empirically, and the ownership rule as a durable invariant for future
  loader changes.
- `.claude/context/index.json` — registered the new context document with a `load_when` entry
  matching the existing neovim-domain format.

## Decisions

- Followed the plan's design exactly: declined the research report's "unlink the symlinked
  ancestor" recommendation in favor of skip-and-warn, because `loader.lua` has no symlink-creating
  capability (`install-extension.sh` is the sole `ln -s` mechanism in the repository) and
  `manager.reload` is literally `unload()` then `load()` — unlinking on remove would destroy the
  pre-existing-symlink signal the copy-side guard depends on, silently defeating it on the very
  next call.
- `.syncprotect` filtering lives at the `init.lua` call sites (not inside `loader.lua`), while
  symlink safety stays inside `loader.lua` itself — the dangerous primitive (`delete()`) defends
  itself, while the policy filter (`.syncprotect`) lives with the policy data (`rel_path`, already
  in hand at the call sites).
- Phase 5's integration test used a more faithful reproduction than the plan's literal suggestion:
  rather than hand-authoring a scratch `extensions.json`, it called the real `manager.load()`
  first (a genuine copy-based load), then converted the deployed paths to symlinks via `ln -s`
  — exactly mirroring how the real incident actually arose (copy-load, then independent symlink
  conversion by `install-extension.sh`, with `extensions.json` unaware of the conversion).

## Plan Deviations

- **Phase 2**: the plan's suggested method for proving discriminating power ("stashing the Phase 1
  change") was replaced with a `loadfile()`-based shadow-module override, because Neovim's
  runtimepath-based `require()` loader ignores `package.path` ordering for files under
  `~/.config/nvim` even under `-u NONE`, making a simple `package.path` prepend ineffective. The
  substitute achieves the same proof without ever stashing or checking out the tracked file.
- **Phase 5**: substituted the plan's "hand-author extensions.json" approach with load-then-convert
  (see Decisions above) — a scope-neutral methodology change that produces a stronger
  reproduction of the actual failure precondition.
- **Phase 6**: restored the two symlinks via `rm` + `ln -s` instead of `git checkout HEAD --
  <path>`, per explicit orchestrator direction (see What Changed above).

All three deviations are methodology substitutions, not scope or outcome changes; every
plan-specified assertion was still satisfied.

## Verification

- Neovim startup and module loading: `nvim --headless -c "lua
  require('neotex.plugins.ai.shared.extensions.loader')" -c "q"` and the same for `.init` both
  exit clean, re-verified after every phase that touched either file.
- Phase 2 (scratch unit test): Case A (ancestor-symlinked file) source survives post-fix and is
  proven destroyed pre-fix (discriminating power confirmed); Case B (file-level symlink) skipped,
  source untouched; regression case (plain file) still deleted and counted.
- Phase 3 (scratch unit test): `.syncprotect` key derivation matches `copy_file`'s convention; a
  protected file survives removal while its unprotected sibling is deleted.
- Phase 4 (scratch unit test): copy path preserves pre-existing file-level and directory-level
  symlinks without writing through them or recording them as owned; ordinary (non-symlinked)
  targets still copy normally.
- Phase 5 (scratch integration test, real `manager.load`/`manager.unload`/`manager.reload`): a
  symlink-deployed extension survives a full reload with zero data loss and zero flattening; an
  ordinary copy-deployed extension still loads/reloads normally.
- Phase 6: both restored symlinks resolve correctly and `git status` no longer reports
  typechanges for either path; `grep -ri "task 862\|task N"` across `loader.lua`, `init.lua`, and
  the new context document returns no matches.
- Real-tree safety: `git status` was checked after every phase; no loader operation was ever run
  against the real `.claude/` tree at any point, and all destructive testing occurred exclusively
  under the scratchpad directory. Phase 6 is the only phase that touched the real tree, and only
  via `rm`/`ln -s` (file replacement, not a loader operation).

## Notes

**Shared-session side effect (not a task-862 defect)**: the `git add`/`git commit` for Phase 6
picked up a large, unrelated concurrent reformatting of `.claude/context/index.json` (entry count
grew from 155 to 171, whitespace/field-order changes throughout) that another agent in this
shared multi-agent session had written to disk between when this agent's Edit was applied and
when the commit was made. Verified this is not data loss or corruption: the entry count increase
matches the untracked filetypes-extension files visible in this session's initial `git status`
(document-agent, docx-edit-agent, skill-filetypes, etc.), the file remains valid JSON, and this
task's own new entry is present and correctly formatted. No destructive git operation was used to
correct this (per the git safety protocol), so the Phase 6 commit's diff for `index.json` is
larger than this task's own change alone. This is flagged here for transparency, not as a defect
in the loader fix.

**Two dangling symlinks left untouched (per plan's Non-Goals)**: `.claude/skills/skill-zotero`
and `.claude/commands/zotero.md` remain dangling, pointing at the removed `zotero` extension
directory. Confirmed provably inert with respect to this bug (`filereadable()` returns 0 for a
dangling link, and the existing `filereadable(filepath) == 1` guard already skips them) — cleanup
deferred to a follow-up task, per the plan.
