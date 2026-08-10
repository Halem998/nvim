# Implementation Summary: Task #119

**Completed**: 2026-03-03
**Duration**: ~30 minutes

## Changes Made

Replaced 23 hardcoded `.claude/` path segments with config-aware `base_dir` construction across 7 picker modules. This enables the picker system to work correctly for both Claude (`<leader>ac` with `.claude/`) and OpenCode (`<leader>ao` with `.opencode/`) configurations.

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Added `config` parameter to 5 directory-scanning functions (`create_docs_entries`, `create_lib_entries`, `create_templates_entries`, `create_scripts_entries`, `create_tests_entries`) and 5 structure-based functions (`create_skills_entries`, `create_agents_entries`, `create_root_files_entries`, `create_hooks_entries`, `create_commands_entries`). Updated `create_picker_entries` to pass config to all functions. Added `config = config` to all heading entries for previewer access.

- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Updated `preview_heading()` to extract `base_dir` and `global_source_dir` from entry config for README path construction.

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Added `picker_config` parameter to `update_artifact_from_global()`. Renamed local `config` to `type_config` to avoid shadowing. Used `picker_config.base_dir` for path construction.

- `lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua` - Added `picker_config` parameter to `save_artifact_to_global()` and `load_artifact_locally()`. Used `picker_config.base_dir` for global and local path construction.

- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Added `base_dir` parameter to `scan_artifacts_for_picker()`.

- `lua/neotex/plugins/ai/claude/commands/parser.lua` - Added `config` parameter to `get_command_structure()` and used `config.base_dir` and `config.commands_subdir` for path construction.

- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Updated Ctrl-l, Ctrl-u, Ctrl-s handlers to pass `config` to operation functions. Fixed picker refresh calls to pass `config` (was only passing `opts`).

## Verification

- All 7 modified modules load without Lua errors
- No remaining hardcoded `.claude/` in path construction contexts
- Remaining `.claude/` occurrences are only in:
  - Comments/documentation describing the directory structure
  - Default values for backward compatibility (e.g., `commands_dir or ".claude/commands"`)

## Notes

- All new parameters have `or ".claude"` defaults, maintaining backward compatibility
- The `config` object is threaded through heading entries so the previewer can access `base_dir` without additional parameters
- Renamed `config` to `type_config` in sync.lua to avoid variable name shadowing with the picker config
