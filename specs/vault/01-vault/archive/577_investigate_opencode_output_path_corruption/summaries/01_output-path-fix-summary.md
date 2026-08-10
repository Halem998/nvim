# Implementation Summary: Task 577 - investigate_opencode_output_path_corruption

- **Task**: 577 - investigate_opencode_output_path_corruption
- **Status**: [COMPLETED]
- **Started**: 2026-05-14T00:00:00Z
- **Completed**: 2026-05-14T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_output-path-fix.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Implemented protections against OpenCode command drift by backporting all active command improvements to the extension source, adding `.syncprotect` awareness to the extension loader, and creating a drift detection script. The root cause of output path corruption was confirmed to be the extension loader's unconditional overwrite of active command files with outdated extension source files that lacked the COMMAND EXECUTION MODE preamble and absolute-path routing fixes.

## What Changed

- `.opencode/extensions/core/commands/*.md` — Overwrote all 15 existing files and added 2 new files (`distill.md`, `learn.md`) with COMMAND EXECUTION MODE preamble and routing fixes already present in active commands
- `.opencode/extensions/core/manifest.json` — Added `distill.md` and `learn.md` to `provides.commands`; added `check-command-drift.sh` to `provides.scripts`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — Added `M.load_syncprotect()` function; updated `copy_file()` to accept and check protected paths; updated all 9 copy functions (`copy_simple_files`, `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`, `copy_hooks`, `copy_systemd`, `copy_docs`, `copy_templates`, `copy_root_files`) to accept and propagate `protected_paths` and return a `skipped_count`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — Updated `manager.load()` to call `loader_mod.load_syncprotect()` before copy operations and pass `protected_paths` through all copy calls; notification message now reports protected file skip count when non-zero
- `.opencode/extensions/core/scripts/check-command-drift.sh` — New drift detection script (exit 0 = no drift, exit 1 = drift, exit 2 = usage error)
- `.opencode/scripts/check-command-drift.sh` — Deployed copy of drift detection script
- `.opencode/output/implement.md` — Deleted (was stale session export from OpenCode, not a real artifact)

## Decisions

- `copy_file()` returns `(success, skipped)` tuple instead of just `success`, allowing callers to distinguish "write failed" from "protected, skipped"
- `load_syncprotect()` is exported as `M.load_syncprotect()` (public) rather than a local, enabling callers to inspect protected paths for reporting or testing
- `check-command-drift.sh` accepts an optional `BASE_DIR` argument for portability; auto-detects from script location when omitted
- The interactive extension reload test (Phase 4) was verified via unit-testing `load_syncprotect()` in headless nvim rather than full UI reload (unfeasible in headless environment)
- `sheet.md` was not added to the extension source or manifest — it does not exist in the active commands directory
- The manifest's `provides.scripts` now includes `check-command-drift.sh` so it is auto-deployed on next extension reload

## Plan Deviations

- **Task 2.7**: Test via interactive extension reload deferred to Phase 4 — instead verified using headless nvim call to `load_syncprotect()`; functional correctness confirmed
- **Task 4.1**: Full interactive extension reload (unload/load via `<leader>al`) skipped — not feasible in headless context; correctness validated by module load tests and syncprotect unit test
- **Task 4.6**: Optional OpenCode `/plan` run skipped — optional step, not feasible in headless context
- **Manifest**: `sheet.md` not added — does not exist in active commands (plan mentioned it but it was not present)

## Impacts

- On next extension reload via `<leader>al`, the extension source files are byte-identical to active files, so no commands will regress
- Protected files listed in `.syncprotect` at the project root will now be skipped during extension load/reload, matching sync.lua behavior
- The `check-command-drift.sh` script enables early detection of future drift via `exit 1` for CI integration
- Notification message now reports skipped file count (e.g., "Loaded extension 'core' (142 files, 2 skipped (.syncprotect))") when `.syncprotect` entries are active

## Follow-ups

- Run a full extension reload from within Neovim after next startup to confirm end-to-end behavior with the UI
- Consider adding `check-command-drift.sh` to a pre-commit hook or CI step to prevent future drift
- The same pattern of unconditional extension source drift may exist in child projects (task mentioned propagating fixes as a follow-up)

## References

- `specs/577_investigate_opencode_output_path_corruption/plans/01_output-path-fix.md`
- `specs/577_investigate_opencode_output_path_corruption/reports/01_output-path-corruption.md`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua`
- `lua/neotex/plugins/ai/shared/extensions/init.lua`
