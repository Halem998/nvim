# Implementation Summary: Task #126

**Completed**: 2026-03-04
**Language**: meta

## Changes Made

Fixed the `<leader>ao` picker to load extension agents into the correct subdirectory. The issue was that OpenCode extensions were placing agent files in `.opencode/agents/` instead of the correct `.opencode/agent/subagents/` location.

## Files Modified

1. **lua/neotex/plugins/ai/shared/extensions/config.lua**
   - Added `agents_subdir` parameter to `M.create()` function with validation
   - Added `agents_subdir` to the returned config table (defaults to "agents" for backward compatibility)
   - Set `agents_subdir = "agents"` in Claude preset
   - Set `agents_subdir = "agent/subagents"` in OpenCode preset

2. **lua/neotex/plugins/ai/shared/extensions/loader.lua**
   - Added optional `agents_subdir` parameter to `copy_simple_files()` function
   - Modified path construction logic to use `agents_subdir` when category is "agents" and subdirectory is provided
   - Other categories continue using category name directly (maintaining backward compatibility)
   - Updated function documentation

3. **lua/neotex/plugins/ai/shared/extensions/init.lua**
   - Modified `manager.load()` function to pass `config.agents_subdir` when calling `loader_mod.copy_simple_files()` for the "agents" category
   - Other categories (commands, rules) continue using default behavior

## How It Works

When an extension is loaded:

1. **For Claude**: Agents are copied to `.claude/agents/` (unchanged behavior)
2. **For OpenCode**: Agents are now copied to `.opencode/agent/subagents/` (fixed behavior)

The source directory structure in extensions remains the same (`{extension}/agents/*.md`), but the target directory is now determined by the configured `agents_subdir` value.

## Verification Steps

To verify the fix works:

1. **Claude Test**: Open a project with `.claude/` directory, load an extension (e.g., `lean`), verify agents appear in `.claude/agents/`

2. **OpenCode Test**: Open a project with `.opencode/` directory, load an extension (e.g., `formal`), verify agents appear in `.opencode/agent/subagents/` (NOT in `agents/`)

3. **State Tracking**: Check that `.opencode/extensions.json` tracks the correct file paths

4. **Unload Test**: Verify unload removes files from the correct locations for both systems

## Notes

- **Backward Compatibility**: Existing Claude extension installations are unaffected (still use `agents/`)
- **State File**: Extension state files track full paths, so existing OpenCode installations loaded before this fix will still unload from their original locations
- **Risk**: Low - only affects new extension loads; existing installations continue to work via tracked paths
