# Implementation Plan: Fix Extension Loader to Copy manifest.json
- **Task**: 533 - fix_extension_loader_manifest
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/533_fix_extension_loader_manifest/reports/01_extension-loader-manifest-research.md
- **Artifacts**: specs/533_fix_extension_loader_manifest/plans/01_fix-extension-loader-manifest.md
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/status-markers.md
  - .opencode/rules/artifact-management.md
  - .opencode/rules/tasks.md
  - specs/533_fix_extension_loader_manifest/reports/01_extension-loader-manifest-research.md
- **Type**: markdown

## Overview

The extension loader in `lua/neotex/plugins/ai/shared/extensions/` copies all declared artifact categories into the target project's `.opencode/` or `.claude/` directory during `manager.load()`, but it omits `manifest.json`. This breaks agent routing in `/implement`, `/research`, and `/plan` commands, which scan `extensions/*/manifest.json` to resolve task-type-to-skill mappings. The fix adds a dedicated `copy_manifest()` function, invokes it during load with proper state tracking, and verifies the copied file on disk.

**Research Integration**: This plan integrates findings from `specs/533_fix_extension_loader_manifest/reports/01_extension-loader-manifest-research.md`, which identified the root cause, the three files requiring modification, and the verification steps needed.

## Goals & Non-Goals

- **Goals**:
  - Add `M.copy_manifest()` to `loader.lua` that copies `manifest.json` from the extension source to `{target_dir}/extensions/{name}/manifest.json`
  - Integrate `copy_manifest()` into `manager.load()` in `init.lua`, recording the file and directory in `all_files` / `all_dirs`
  - Add a verification step in `verify.lua` to confirm the target manifest exists after load
  - Ensure the copied manifest is tracked in `extensions.json` and removed on `manager.unload()`
  - Support both OpenCode (`.opencode/`) and Claude (`.claude/`) target directories without hard-coding either

- **Non-Goals**:
  - NO fallback routing logic will be added (per explicit user requirement)
  - No changes to command shell scripts (they already scan for the manifest; the loader will now provide it)
  - No changes to `state.lua`, `manifest.lua`, `config.lua`, or the OpenCode/Claude facades
  - No changes to merge-target processing or CLAUDE.md/OPENCODE.md generation

## Risks & Mitigations

- **Risk**: Adding the manifest copy inside the existing `pcall` block could cause a load failure if the source manifest is unreadable, triggering a full rollback. Mitigation: `copy_manifest()` already checks `vim.fn.filereadable(source_path) == 1` before copying; if the source is missing it returns empty arrays, which is a no-op.
- **Risk**: If the target `extensions/{name}/` directory already exists with user files, the manifest copy creates only one new file and does not overwrite other content. Mitigation: `copy_manifest()` uses `helpers.ensure_directory()` which is idempotent and only inserts the directory into `created_dirs` if it did not already exist.
- **Risk**: The verification step could fail on legacy projects where the manifest was never copied. Mitigation: Verification runs only after load, and the fix ensures the manifest is always copied during load, so this condition will not occur post-fix.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add `copy_manifest()` to `loader.lua` [COMPLETED]
- **Goal:** Implement the file-copy function for manifest.json.
- **Tasks:**
  - [x] **Task 1.1**: Add `M.copy_manifest(manifest, source_dir, target_dir, extension_name)` after `M.copy_data_dirs()` and before `M.check_conflicts()` in `lua/neotex/plugins/ai/shared/extensions/loader.lua`.
  - [x] **Task 1.2**: The function must compute `source_path = source_dir .. "/manifest.json"` and `target_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"`.
  - [x] **Task 1.3**: Use `vim.fn.filereadable(source_path) == 1` guard; if the source manifest is absent return empty arrays.
  - [x] **Task 1.4**: Create the target `extensions/{name}/` directory via `helpers.ensure_directory()` only when `vim.fn.isdirectory(ext_dir) ~= 1`, and record the directory in `created_dirs`.
  - [x] **Task 1.5**: Copy the file with `copy_file(source_path, target_path, false)` and record the target path in `copied_files` on success.
  - [x] **Task 1.6**: Return `{copied_files, created_dirs}` following the same signature as all other `copy_*()` functions.
- **Timing:** 30 minutes
- **Depends on:** none

### Phase 2: Wire `copy_manifest()` into `manager.load()` in `init.lua` [COMPLETED]
- **Goal:** Ensure manifest.json is copied and tracked during every extension load.
- **Tasks:**
  - [x] **Task 2.1**: Inside the `pcall` block of `manager.load()` in `lua/neotex/plugins/ai/shared/extensions/init.lua`, add a call to `loader_mod.copy_manifest(ext_manifest, source_dir, target_dir, extension_name)` after the existing `copy_root_files()` call and before `copy_data_dirs()`.
  - [x] **Task 2.2**: Extend `all_files` and `all_dirs` with the returned arrays using `vim.list_extend`.
  - [x] **Task 2.3**: Confirm the manifest file is therefore persisted in `extensions.json` via `state_mod.mark_loaded()` and removed on unload via `remove_installed_files()`.
- **Timing:** 30 minutes
- **Depends on:** 1

### Phase 3: Verify target manifest in `verify.lua` and validate [COMPLETED]
- **Goal:** Confirm the copied manifest exists during post-load verification.
- **Tasks:**
  - [x] **Task 3.1**: In `lua/neotex/plugins/ai/shared/extensions/verify.lua`, inside `M.verify_extension()`, add a check after the manifest is read that computes `target_manifest_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"`.
  - [x] **Task 3.2**: If `file_exists(target_manifest_path)` is false, set `verification.status = "failed"` and insert an error message.
  - [x] **Task 3.3**: Add a `manifest` field to the verification report table for consistency.
  - [x] **Task 3.4**: Validate the fix by loading an extension in a test project and confirming `{project}/.opencode/extensions/{name}/manifest.json` exists.
  - [x] **Task 3.5**: Validate unload removes the manifest and the `extensions/{name}/` directory becomes empty and is deleted.
  - [x] **Task 3.6**: Validate the command routing loops in `.opencode/commands/implement.md` (and `.claude/` equivalents) now find the copied manifest.
- **Timing:** 1 hour
- **Depends on:** 2

## Testing & Validation

- [x] Load an extension via `:lua require("neotex.plugins.ai.opencode.extensions").load("core")` in a test project and verify `.opencode/extensions/core/manifest.json` is created.
- [x] Inspect `extensions.json` and confirm `manifest.json` is listed in `installed_files`.
- [x] Unload the same extension and confirm `.opencode/extensions/core/manifest.json` is removed; confirm the `extensions/core/` directory is removed if empty.
- [x] Run `verify_extension` on the loaded extension and confirm it passes the manifest check.
- [x] Confirm no fallback routing logic was added anywhere in the codebase.
- [x] Repeat the load/unload/verify cycle for a `.claude/` target directory.

## Artifacts & Outputs

- `specs/533_fix_extension_loader_manifest/plans/01_fix-extension-loader-manifest.md` (this file)
- Modified `lua/neotex/plugins/ai/shared/extensions/loader.lua`
- Modified `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Modified `lua/neotex/plugins/ai/shared/extensions/verify.lua`

## Rollback/Contingency

- If the changes introduce regressions in load or unload, revert the three modified files using `git checkout --` on each file.
- Because the manifest copy is tracked in `extensions.json`, unloading an extension loaded before the revert will still attempt to remove the manifest file. If the file was never created (because the revert removed `copy_manifest()`), `remove_installed_files()` safely ignores missing files (`vim.fn.delete()` is a no-op on non-existent paths).
- No database or external state is modified; rollback is purely a matter of restoring the three Lua files.
