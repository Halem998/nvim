# Phase 4 Results: Sync System Update

**Status**: COMPLETED
**Date**: 2026-04-16

## Summary

Updated the sync system to source core artifact files from `.claude/extensions/core/{category}/` instead of `.claude/{category}/` in the global directory.

## Changes Made

### `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`

Added optional `source_base_dir` parameter to `scan_directory_for_sync()`:
- When provided, this overrides the base dir used for building the **global source path** only
- The **local destination path** still uses the standard `base_dir` (e.g., `.claude/`)
- This enables reading from `extensions/core/{subdir}` while writing to `.claude/{subdir}`

### `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`

Updated `scan_all_artifacts()`:

1. Added `core_source_base` variable: `".claude/extensions/core"` for `.claude` base_dir, `nil` for `.opencode`
2. Added `use_core_source` parameter to `sync_scan()` local function:
   - When `false`: uses standard `base_dir` root as source
   - Otherwise: uses `core_source_base` (nil for .opencode = no change; path for .claude = extensions/core/)
3. Core categories (commands, agents, skills, hooks, templates, docs, scripts, rules, context) now use `core_source_base`
4. Non-core categories use `use_core_source = false`:
   - `systemd`: remains at `.claude/systemd/`
   - `lib`: remains at `.claude/lib/` (empty, not in extensions/core)
   - `tests`: remains at `.claude/tests/` (empty, not in extensions/core)
   - `settings`: remains at `.claude/settings.json`
5. `root_files` (CLAUDE.md, .gitignore, settings.local.json, README.md) unchanged - explicitly build from `base_dir` root

## Verification

- Both modules load in headless Neovim without errors
- Source paths verified against filesystem:
  - `extensions/core/agents/` contains 8 agent files
  - `extensions/core/commands/` contains 14 command files
  - `extensions/core/rules/` contains 6 rule files
  - `extensions/core/context/` contains expected subdirectories
- Root files still correctly sourced from `.claude/` root (CLAUDE.md, .gitignore, etc.)
- Systemd files correctly sourced from `.claude/systemd/` (2 files: .service, .timer)
- Allow-list and blocklist filtering logic unchanged; works with new source paths
- `.syncprotect` mechanism unchanged; relative paths used in protected_paths remain the same
- `docs` category: nested `docs/docs/` structure preserved (source `extensions/core/docs/docs/...` maps to destination `.claude/docs/docs/...`, matching pre-migration layout)

## Notes

- The `.opencode` code path is unaffected: `core_source_base = nil` means `source_base_dir` is nil, which causes `scan_directory_for_sync` to use the standard `base_dir` for the source path (backward-compatible)
- The allow-list post-filter for `context` category uses `/context/(.+)$` pattern to extract the top-level subdirectory from `global_path`; this still works correctly since the path still contains `/context/` as a segment
