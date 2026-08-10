# Research Report: Task #126

**Task**: OC_126 - Fix <leader>ao picker to load extensions into correct subdirectory
**Date**: 2026-03-04
**Language**: meta
**Focus**: Extension loader path configuration

## Summary

The `<leader>ao` picker loads extensions into `.opencode/agents/` instead of the correct `.opencode/agents/subagents/` subdirectory. This occurs because the extension system's loader module uses hardcoded category names (e.g., "agents") rather than the configurable subdirectory paths defined in the picker configuration. The fix requires adding `agents_subdir` to the extension configuration and updating loader functions to respect this setting.

## Findings

### 1. Configuration Mismatch Between Picker and Extension Systems

**Picker Config** (`lua/neotex/plugins/ai/shared/picker/config.lua`):
- Claude: `agents_subdir = "agents"`
- OpenCode: `agents_subdir = "agent/subagents"`

**Extension Config** (`lua/neotex/plugins/ai/shared/extensions/config.lua`):
- Missing `agents_subdir` field entirely
- Only has `base_dir`, `config_file`, `section_prefix`, `state_file`, `global_extensions_dir`, `merge_target_key`

### 2. Loader Module Uses Hardcoded Category Names

**File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The `copy_simple_files()` function builds target paths using the category name directly:

```lua
local target_category_dir = target_dir .. "/" .. category
-- For "agents" category: becomes .opencode/agents/ (WRONG)
-- Should be: .opencode/agent/subagents/ (CORRECT)
```

This function is called from `init.lua` with category names from the manifest:
```lua
-- Copy agents (line 229)
local files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "agents", ".md")
-- Copy commands (line 234)
files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "commands", ".md")
```

### 3. Sync Operations Already Handle agents_subdir Correctly

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (lines 173-175)

The sync operation correctly uses the config-provided agents_subdir:
```lua
local agents_subdir = (config and config.agents_subdir) or "agents"
artifacts.agents = sync_scan(agents_subdir, "*.md")
```

This confirms the picker architecture already supports the correct subdirectory structure, but the extension loader does not.

### 4. Extension Manifest Structure

**File**: `.opencode/extensions/formal/manifest.json`

Extensions declare their content in `provides`:
```json
{
  "provides": {
    "agents": ["formal-research-agent.md", ...],
    "skills": ["skill-formal-research", ...],
    "context": ["project/logic", ...]
  }
}
```

These filenames need to be copied to the correct subdirectories based on the system (Claude vs OpenCode).

## Recommendations

1. **Add `agents_subdir` to extension config** (`shared/extensions/config.lua`):
   - Add parameter to `M.create()` function
   - Set Claude default: `"agents"`
   - Set OpenCode default: `"agent/subagents"`

2. **Update loader functions to use subdirectory configuration**:
   - Modify `copy_simple_files()` to accept an optional subdirectory override
   - Pass the correct `agents_subdir` when copying agents
   - Consider doing the same for other categories if they diverge in future

3. **Update extension init.lua to pass subdirectory config**:
   - Thread the agents_subdir from config to the loader functions
   - Call `copy_simple_files()` with the correct target subdirectory for agents

4. **Test both paths**:
   - Verify `.claude/agents/` still works (unchanged)
   - Verify `.opencode/agent/subagents/` now works correctly

## Risks & Considerations

- **Backward compatibility**: Claude extensions must continue to work with `agents/` directory
- **State tracking**: Extension state file (`extensions.json`) tracks installed file paths; changing paths may orphan existing installations
- **Unloading**: The unload mechanism uses tracked paths from state file; path changes won't break existing installations but new loads will go to different locations

## Next Steps

Run `/plan OC_126` to create an implementation plan for:
1. Adding `agents_subdir` to extension configuration
2. Updating loader functions to respect subdirectory settings
3. Testing the fix in both Claude and OpenCode environments
