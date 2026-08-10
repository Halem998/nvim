# Implementation Summary: Task #186

**Completed**: 2026-03-11
**Duration**: ~45 minutes

## Changes Made

Implemented manifest-based blocklist filtering for core sync operations, preventing extension artifacts from leaking into synced projects regardless of what extensions are loaded in the global directory. Also consolidated duplicate picker code and added a self-loading guard.

## Files Modified

- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Added `aggregate_extension_artifacts()` function that reads all extension manifests and builds a category-keyed blocklist (agents, skills, commands, rules, context, etc.) with O(1) lookup via set-based structure.

- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Enhanced `scan_directory_for_sync()` with prefix matching support for directory-based exclusions (e.g., pattern "project/neovim" excludes "project/neovim/domain/api.md") and optional `skip_symlinks` parameter as defense in depth.

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Integrated blocklist filtering into `scan_all_artifacts()`. Now builds blocklist from extension manifests and merges exclusions into each category scan. Updated module docstring to document filtering behavior.

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Added self-loading guard to `manager.load()` that prevents loading extensions into the global source directory (~/.config/nvim), with clear error message and `opts.force` bypass for exceptional cases.

- `lua/neotex/plugins/ai/shared/extensions/picker.lua` - Created new shared picker module with `create(extensions_module, picker_config)` factory function. Extracts 240+ lines of common picker logic, parameterized by extensions module and configuration.

- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Reduced from 245 lines to 10-line thin wrapper using shared picker.

- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Reduced from 245 lines to 10-line thin wrapper using shared picker.

- Removed `lua/neotex/plugins/ai/claude/extensions/state.lua` - 102-line wrapper that served no purpose (no external callers, incomplete passthrough).

- Removed `lua/neotex/plugins/ai/claude/extensions/loader.lua` - 7-line re-export that served no purpose.

## Symlink Cleanup

Removed leftover symlinks from global .claude directories:
- 9 agent symlinks removed
- 11+ skill symlinks removed

These were likely from an older implementation that used symlinks instead of file copies.

## Verification

- All modified Lua modules load successfully in nvim --headless
- manifest.aggregate_extension_artifacts() function exists and is callable
- scan.scan_directory_for_sync() supports new skip_symlinks parameter
- sync.scan_all_artifacts() properly integrates blocklist filtering
- shared.extensions.create() returns manager with self-loading guard
- Shared picker creates working picker instances for both Claude and OpenCode
- No symlinks remain in global .claude directories

## Architecture

The implementation follows the manifest-based blocklist pattern (Pattern A from research):

```
Extension Load -> manifest.json provides -> tracked in state
Core Sync -> aggregate_extension_artifacts() -> build blocklist
            -> scan_all_artifacts() -> apply blocklist per category
            -> only core artifacts synced
```

Key design decisions:
- Blocklist is rebuilt per-sync (no caching) to ensure correctness
- Self-loading guard prevents root cause (contamination of source directory)
- Prefix matching enables directory-based filtering for context (e.g., "project/neovim/*")
- Shared picker reduces 490 lines of duplication to ~15 lines total
