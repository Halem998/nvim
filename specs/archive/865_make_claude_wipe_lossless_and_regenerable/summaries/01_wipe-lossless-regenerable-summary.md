# Implementation Summary: Task #865

**Completed**: 2026-07-15
**Duration**: single session, 7 phases across 4 waves

## Overview

Closed the remaining wipe-survival gap in the `.claude/ == deploy(store, selection)` model. All
state that must survive an `rm -rf .claude/` (or `.opencode/`) wipe now lives outside `base_dir`:
the extension selection manifest moved to a preset-scoped project-root dotfile, runtime logs moved
to a project-root directory, and the two settings files that cannot move (Claude Code hardcodes
their read path) are protected by install-once semantics plus a backup/restore wrapper. A new
`manager.regenerate` function rebuilds `base_dir` from the surviving manifest without re-picking
extensions. The full wipe-and-regenerate cycle was proven headlessly in scratchpad fake project
dirs — the real `~/.config/nvim/.claude` tree was never touched destructively.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/config.lua` — new `root_state_file` and
  `settings_backup_dir` preset-scoped fields; removed the now-unreferenced `state_file` field
- `lua/neotex/plugins/ai/shared/extensions/state.lua` — `get_state_path` reads the project-root
  manifest; `M.write` no longer mkdir's `base_dir`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — `copy_root_files` install-once guard for
  `settings.json`/`settings.local.json`; exported `INSTALL_ONCE_ROOT_FILES`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — new `manager.regenerate(opts)`;
  `manager.unload` now excludes settings files from removal (closes the reload-clobber gap)
- `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua` — new module: `backup`/`restore`/
  `has_backup` for the settings zero-loss wrapper
- `agent-system/extensions/core/scripts/skill-base.sh`, `validate-wiring.sh` (+ `.claude`/`.opencode`
  deployed copies) — read the relocated, preset-scoped manifest path
- `agent-system/extensions/core/hooks/{post-command,log-session,subagent-postflight}.sh`,
  `scripts/{update-phase-status,generate-todo}.sh` (+ deployed copies) — `LOG_DIR`/`log_dir` point
  at project-root `.agent-logs/`
- Documentation: `EXTENSION.md`, `README.md`, `docs/architecture/extension-system.md` (core),
  `extensions/literature/README.md`, `docs/guides/permission-configuration.md`, plus the 5
  logs-path-reference docs — all path-reference sweeps, no logic changes
- `.gitignore` (project root) — `.agent-logs/`, `.claude-settings-backup/`, `.opencode-settings-backup/`

## Decisions

- **Preset-scoped filenames** (`.claude-extensions.json` / `.opencode-extensions.json`,
  `.claude-settings-backup` / `.opencode-settings-backup`) avoid collision if both presets ever
  deploy into the same project root, following the same rationale for both the manifest and the
  settings-backup staging directory.
- **`manager.regenerate` resets state before reloading**, rather than iterating `manager.load`
  directly: `manager.load`'s own "already loaded" guard would otherwise reject every formerly-active
  extension outright, since the surviving manifest still marks them `active` after a wipe. The reset
  lets `manager.load`'s existing recursive dependency resolution rebuild everything in the correct
  order with no new ordering logic needed.
- **Restore wired into `manager.regenerate`, not the picker's "Load Core" path**: research during
  Phase 2/5 confirmed `sync.load_all_globally` (the picker's "Load Core Agent System" action) does
  not touch `root_files` for `.claude` at all — settings deployment is loader-owned, not sync-owned,
  for that base_dir. This matches the plan's own documented fallback for an entangled-with-picker
  entrypoint.
- **`context/index.json` key-order non-determinism** is a genuine, pre-existing characteristic
  (confirmed via two independent fresh loads with no wipe involved), unrelated to and out of scope
  for this task. Phase 7's verification uses a structural (entry-path-set) comparison for that one
  file instead of a byte hash.

## Plan Deviations

- **Task 1.6** (Phase 1) altered: `config.state_file` was removed entirely rather than left in place,
  since the grep sweep confirmed it was fully unreferenced after the `state.lua` edit.
- **Task 2.2** (Phase 2) altered: `validate-wiring.sh`'s fix implemented as
  `"${system_dir}-extensions.json"` string concatenation (system_dir is always an absolute path
  ending in `/.claude` or `/.opencode`) rather than a branch.
- **Task 2.3** (Phase 2) altered: `.opencode/scripts/skill-base.sh` is an independently-maintained
  variant with no `agent-system/extensions/core` source counterpart; edited directly rather than via
  copy. Also updated a 4th `validate-wiring.sh` deployed copy
  (`.opencode/extensions/core/scripts/`) discovered on disk.
- **Task 3.1** (Phase 3) altered: `manager.regenerate` resets state to empty before reloading (see
  Decisions above) — a design correction discovered during implementation, not present in the
  original plan wording.
- **Task 4** (Phase 4) — post-hoc gap found and closed: `manager.unload` was deleting
  `settings.json`/`settings.local.json` unconditionally before install-once could ever apply on a
  subsequent load, defeating install-once for the `manager.reload` (unload-then-load) cycle. Closed
  by excluding those two files from removal in `manager.unload`, via the newly-exported
  `loader_mod.INSTALL_ONCE_ROOT_FILES`.
- **Task 5.1/5.2** (Phase 5) altered: new `config.settings_backup_dir` field (not in the original
  plan text) for preset-scoped staging directory naming; restore wired into `manager.regenerate`
  per the fallback contingency, not the picker path.
- **Task 6.2** (Phase 6) altered: also converged `.opencode/extensions/core/hooks/*.sh`, which had
  pre-existing drift hardcoding `.claude/logs` instead of `.opencode/logs`, as an incidental side
  effect of the path-constant change.
- **Task 7.2** (Phase 7) altered: discovered and excluded a second volatile field
  (`context/index.json` key ordering) beyond the plan's named `loaded_at`, confirmed pre-existing
  and out of scope.

## Verification

- Headless module load: `config`, `state`, `loader`, `init`, `settings_backup`, `manifest`,
  `merge`, `verify` all load without error after every phase.
- Hard gate: `bash .claude/scripts/check-extension-docs.sh` passes (0 failures) after every phase's
  edits, including the final state.
- Full wipe-and-regenerate cycle (Phase 7, scratchpad-only): 20/20 assertions passed — manifest at
  project root, manifest + settings backup survive a real `rm -rf .claude/`, `manager.regenerate`
  reloads both a dependency (`core`) and its dependent (`memory`) with 0 failures, all 292 pre-wipe
  files reproduce byte-identically post-regenerate (modulo the known `index.json` key-order
  non-determinism), the settings.local.json marker survives the full backup/wipe/regenerate/restore
  cycle, and a separate `manager.reload` regression confirms a hand-edited `settings.json` survives
  an in-place reload.
- No mutation of the real `~/.config/nvim/.claude` tree: confirmed via `git status` after every
  scratch test; all destructive operations ran exclusively under a `/tmp/.../scratchpad/` fake
  project directory, never the real repo.

## Notes

- The pre-existing `.claude/logs/*.log` git-tracking anomaly (tracked despite `.claude/.gitignore`'s
  `logs/` entry) was flagged, not fixed, per the plan's explicit non-goal.
- The pre-existing `skill-base.sh` `.loaded_extensions[]`/`.extensions{}` schema mismatch (the
  function silently no-ops today) was left unfixed per the plan's explicit non-goal; only its path
  constant was updated.
- No literal path move was attempted for `.claude/settings.json` / `.claude/settings.local.json` —
  install-once + backup/restore is the complete fix, per the plan's critical constraint.
