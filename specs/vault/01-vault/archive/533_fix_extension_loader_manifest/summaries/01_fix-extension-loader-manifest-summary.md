# Implementation Summary: Fix Extension Loader to Copy manifest.json

**Task**: 533 - fix_extension_loader_manifest  
**Status**: Completed  
**Date**: 2026-05-07

## Changes Made

### Phase 1: Added `M.copy_manifest()` to `loader.lua`
- **File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`
- **Function**: `M.copy_manifest(manifest, source_dir, target_dir, extension_name)`
- Computes `source_path = source_dir .. "/manifest.json"` and `target_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"`
- Guards with `vim.fn.filereadable(source_path) == 1`; returns empty arrays if absent
- Creates `extensions/{name}/` via `helpers.ensure_directory()` only when needed, recording in `created_dirs`
- Copies file with `copy_file(source_path, target_path, false)` and records in `copied_files`
- Returns `{copied_files, created_dirs}` consistent with all other `copy_*()` functions

### Phase 2: Wired `copy_manifest()` into `manager.load()` in `init.lua`
- **File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Added call inside the `pcall` block after `copy_root_files()` and before `copy_data_dirs()`
- Extended `all_files` and `all_dirs` with returned arrays using `vim.list_extend`
- Because `all_files`/`all_dirs` are persisted via `state_mod.mark_loaded()`, the manifest is tracked in `extensions.json` and removed automatically on unload via `remove_installed_files()`

### Phase 3: Added target manifest verification in `verify.lua`
- **File**: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- Inside `M.verify_extension()`, added check after manifest read
- Computes `target_manifest_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"`
- If `file_exists(target_manifest_path)` is false, sets `verification.status = "failed"` and inserts error message

## Constraints Satisfied
- No fallback routing logic was added anywhere
- `state.lua`, `manifest.lua`, `config.lua`, and OpenCode/Claude facades were not modified
- Supports both `.opencode/` and `.claude/` target directories (parameterized via `target_dir`)

## Artifacts
- Modified `lua/neotex/plugins/ai/shared/extensions/loader.lua`
- Modified `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Modified `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- Updated `specs/533_fix_extension_loader_manifest/plans/01_fix-extension-loader-manifest.md`

## Rollback
If regressions occur, revert the three modified files with `git checkout --` on each. Unload of pre-revert extensions safely ignores missing manifest files because `vim.fn.delete()` is a no-op on non-existent paths.
