# Implementation Plan: Task #119

- **Task**: 119 - Fix hardcoded paths in picker for config-aware directory scanning
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: Task 118 (completed)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false
- **Date**: 2026-03-03
- **Feature**: Replace 23 hardcoded ".claude/" path segments with config.base_dir across 7 picker modules
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

Task 118 established the shared picker config infrastructure (`shared.picker.config`) with `base_dir`, `global_source_dir`, and other fields. However, 23 hardcoded `".claude/"` path segments remain across 7 files in the picker subsystem. This plan threads the `config` parameter to all remaining functions and replaces every hardcoded `".claude/"` with `config.base_dir`, ensuring both the Claude picker (`<leader>ac`) and the OpenCode picker (`<leader>ao`) scan the correct directories.

### Research Integration

The research report (research-001.md) identified all 23 hardcoded path locations across 7 files, mapped the current config threading status, and recommended a phased approach starting from inner modules (entries.lua, scan.lua) and working outward to callers (init.lua). The plan follows this recommendation with one key refinement: grouping entries.lua heading config and previewer.lua into a single phase since they are tightly coupled.

## Goals & Non-Goals

**Goals**:
- Replace all 23 hardcoded `".claude/"` path segments with `config.base_dir`
- Thread `config` parameter through all affected function signatures
- Maintain backward compatibility (all new config params default to `.claude` when nil)
- Ensure both `<leader>ac` (Claude) and `<leader>ao` (OpenCode) pickers work correctly

**Non-Goals**:
- Refactoring the overall picker architecture
- Adding new picker features or sections
- Modifying the shared.picker.config schema (already complete from task 118)
- Changing test fixtures that correctly use `.claude` for Claude-specific tests

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing Claude picker by changing signatures | H | L | All new params have `or ".claude"` defaults, backward compatible |
| Variable name shadowing (`config` used for both picker config and type_config) | M | M | Rename local `config` to `type_config` in sync.lua; document clearly |
| Callers in init.lua not passing config to updated functions | H | M | Systematic audit of every call site in init.lua during phase 3 |
| scan_artifacts_for_picker used by unknown callers | L | L | Add base_dir param with default; search for callers before modifying |

## Implementation Phases

### Phase 1: Thread config to entries.lua directory-scanning functions [COMPLETED]

**Goal**: Add `config` parameter to the 5 directory-scanning entry creator functions and update `create_picker_entries()` to pass config through. Also attach config to heading entries for previewer access.

**Tasks**:
- [ ] Add `config` parameter to `create_docs_entries(config)`
- [ ] Add `config` parameter to `create_lib_entries(config)`
- [ ] Add `config` parameter to `create_templates_entries(config)`
- [ ] Add `config` parameter to `create_scripts_entries(config)`
- [ ] Add `config` parameter to `create_tests_entries(config)`
- [ ] In each function: extract `base_dir` from config with default, use for path construction
- [ ] In each function: extract `global_source_dir` from config or fall back to `scan.get_global_dir()`
- [ ] Update `create_picker_entries()` to pass `config` to all 5 functions
- [ ] Attach `config = config` to all heading entries created in the 5 functions and in commands/skills/agents/hooks/root_files heading entries

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Add config param to 5 functions, update create_picker_entries, add config to headings

**Pattern for each function** (uniform across all 5):
```lua
-- Before:
function M.create_docs_entries()
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()
  local local_docs = scan.scan_directory(project_dir .. "/.claude/docs", "*.md")
  local global_docs = scan.scan_directory(global_dir .. "/.claude/docs", "*.md")

-- After:
function M.create_docs_entries(config)
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"
  local local_docs = scan.scan_directory(project_dir .. "/" .. base_dir .. "/docs", "*.md")
  local global_docs = scan.scan_directory(global_dir .. "/" .. base_dir .. "/docs", "*.md")
```

**Heading entry config attachment pattern**:
```lua
-- Add config to heading entries so previewer can access base_dir
table.insert(entries, {
  is_heading = true,
  name = "~~~docs_heading",
  display = string.format("%-40s %s", "[Docs]", "Integration guides"),
  entry_type = "heading",
  ordinal = "docs",
  config = config,  -- Thread config for previewer
})
```

**Verification**:
- Open Claude picker (`<leader>ac`) and verify all sections (Docs, Lib, Templates, Scripts, Tests) still display correctly
- Verify heading entries carry config field by checking previewer behavior in Phase 2

---

### Phase 2: Thread config to previewer.preview_heading() [COMPLETED]

**Goal**: Update `preview_heading()` to extract config from the entry and use `base_dir` for README path construction instead of hardcoded `".claude/"`.

**Tasks**:
- [ ] In `preview_heading()`: extract config from `entry.value.config`
- [ ] Use `config.base_dir` (with fallback to `.claude`) for README path construction
- [ ] Use `config.global_source_dir` (with fallback to `scan.get_global_dir()`) for global path

**Timing**: 15 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Update preview_heading function

**Pattern**:
```lua
-- Before:
local local_path = vim.fn.getcwd() .. "/.claude/" .. ordinal .. "/README.md"
local global_path = scan_mod.get_global_dir() .. "/.claude/" .. ordinal .. "/README.md"

-- After:
local entry_config = entry.value.config
local base_dir = (entry_config and entry_config.base_dir) or ".claude"
local global_dir = (entry_config and entry_config.global_source_dir) or scan_mod.get_global_dir()
local local_path = vim.fn.getcwd() .. "/" .. base_dir .. "/" .. ordinal .. "/README.md"
local global_path = global_dir .. "/" .. base_dir .. "/" .. ordinal .. "/README.md"
```

**Verification**:
- Navigate to a heading entry in the picker and verify README preview renders correctly
- Verify fallback works when no config is attached (legacy entries)

---

### Phase 3: Thread config to init.lua call sites and fix sync/edit operations [COMPLETED]

**Goal**: Pass config from `init.lua` to `sync.update_artifact_from_global()`, `edit.load_artifact_locally()`, and `edit.save_artifact_to_global()`. Also rename the shadowed `config` variable in sync.lua.

**Tasks**:
- [ ] In `sync.update_artifact_from_global()`: add `picker_config` parameter (4th arg), rename local `config = subdir_map[...]` to `type_config`, use `picker_config.base_dir` for path construction
- [ ] In `edit.save_artifact_to_global()`: add `picker_config` parameter (3rd arg), use `picker_config.base_dir` for global path construction
- [ ] In `edit.load_artifact_locally()`: add `picker_config` parameter (4th arg), use `picker_config.base_dir` for path construction
- [ ] In `init.lua` Ctrl-u handler (line ~193): pass `config` to `sync.update_artifact_from_global()`
- [ ] In `init.lua` Ctrl-l handler (line ~169): pass `config` to `edit.load_artifact_locally()`
- [ ] In `init.lua` Ctrl-s handler (line ~217): pass `config` to `edit.save_artifact_to_global()`
- [ ] In `init.lua` refresh calls after Ctrl-l/u/s: pass `config` to `M.show_commands_picker(opts, config)` (line 174 currently only passes opts)

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Update `update_artifact_from_global()` signature and paths
- `lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua` - Update `save_artifact_to_global()` and `load_artifact_locally()` signatures and paths
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Pass config to all 3 operation calls and picker refresh calls

**sync.lua update_artifact_from_global pattern**:
```lua
-- Before:
function M.update_artifact_from_global(artifact, artifact_type, silent)
  ...
  local config = subdir_map[artifact_type]  -- shadows picker config
  ...
  global_filepath = global_dir .. "/.claude/" .. config.dir .. "/" .. ...
  local_dir = project_dir .. "/.claude/" .. config.dir

-- After:
function M.update_artifact_from_global(artifact, artifact_type, silent, picker_config)
  ...
  local type_config = subdir_map[artifact_type]  -- renamed to avoid shadowing
  local base_dir = (picker_config and picker_config.base_dir) or ".claude"
  ...
  global_filepath = global_dir .. "/" .. base_dir .. "/" .. type_config.dir .. "/" .. ...
  local_dir = project_dir .. "/" .. base_dir .. "/" .. type_config.dir
```

**edit.lua patterns**:
```lua
-- save_artifact_to_global: add picker_config param
function M.save_artifact_to_global(artifact, artifact_type, picker_config)
  local base_dir = (picker_config and picker_config.base_dir) or ".claude"
  ...
  local global_target_dir = global_dir .. "/" .. base_dir .. "/" .. subdir

-- load_artifact_locally: add picker_config param
function M.load_artifact_locally(artifact, artifact_type, parser, picker_config)
  local base_dir = (picker_config and picker_config.base_dir) or ".claude"
  ...
  local local_dir = project_dir .. "/" .. base_dir .. "/" .. subdir
  global_filepath = global_dir .. "/" .. base_dir .. "/" .. subdir .. "/" .. artifact.name
  local dep_global_path = global_dir .. "/" .. base_dir .. "/commands/" .. dep_name .. ".md"
  local dep_local_path = project_dir .. "/" .. base_dir .. "/commands/" .. dep_name .. ".md"
```

**init.lua call site fixes**:
```lua
-- Ctrl-u handler: pass config
sync.update_artifact_from_global(artifact, artifact_type, false, config)

-- Ctrl-l handler: pass config
edit.load_artifact_locally(artifact, artifact_type, parser, config)

-- Ctrl-s handler: pass config
edit.save_artifact_to_global(artifact, artifact_type, config)

-- Picker refresh calls after Ctrl-l/u/s (currently missing config):
M.show_commands_picker(opts, config)
```

**Verification**:
- Test Ctrl-l (load locally) on an artifact from global directory
- Test Ctrl-u (update from global) on a local artifact
- Test Ctrl-s (save to global) on a local artifact
- Verify picker refreshes properly after operations

---

### Phase 4: Fix scan.lua and parser.lua hardcoded paths [COMPLETED]

**Goal**: Update `scan_artifacts_for_picker()` in scan.lua and `get_command_structure()` in parser.lua to accept and use `base_dir` instead of hardcoded `".claude/"`.

**Tasks**:
- [ ] In `scan.scan_artifacts_for_picker()`: add `base_dir` parameter (2nd arg), use for path construction
- [ ] In `parser.get_command_structure()`: add `config` parameter (2nd arg) or extract `base_dir` for default path construction
- [ ] Search for all callers of `scan_artifacts_for_picker()` and verify they pass base_dir or are compatible with the default

**Timing**: 20 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Update `scan_artifacts_for_picker()`
- `lua/neotex/plugins/ai/claude/commands/parser.lua` - Update `get_command_structure()`

**scan.lua pattern**:
```lua
-- Before:
function M.scan_artifacts_for_picker(type_config)
  local dirs = M.get_directories()
  ...
  local local_path = dirs.project_dir .. "/.claude/" .. subdir
  local global_path = dirs.global_dir .. "/.claude/" .. subdir

-- After:
function M.scan_artifacts_for_picker(type_config, base_dir)
  local dirs = M.get_directories()
  base_dir = base_dir or ".claude"
  ...
  local local_path = dirs.project_dir .. "/" .. base_dir .. "/" .. subdir
  local global_path = dirs.global_dir .. "/" .. base_dir .. "/" .. subdir
```

**parser.lua pattern**:
```lua
-- Before:
function M.get_command_structure(commands_dir)
  ...
  local project_dir = vim.fn.getcwd() .. "/.claude/commands"
  local global_dir = scan_mod.get_global_dir() .. "/.claude/commands"

-- After:
function M.get_command_structure(commands_dir, config)
  ...
  local base_dir = (config and config.base_dir) or ".claude"
  local commands_subdir = (config and config.commands_subdir) or "commands"
  local project_dir = vim.fn.getcwd() .. "/" .. base_dir .. "/" .. commands_subdir
  local global_dir = scan_mod.get_global_dir() .. "/" .. base_dir .. "/" .. commands_subdir
```

**Verification**:
- Verify `get_command_structure()` still works when called without config (backward compatible)
- Verify `scan_artifacts_for_picker()` still works without base_dir parameter

---

### Phase 5: End-to-end verification and testing [COMPLETED]

**Goal**: Verify the complete picker system works correctly for both Claude and OpenCode configurations with no remaining hardcoded paths.

**Tasks**:
- [ ] Open Claude picker (`<leader>ac`): verify all sections display, preview renders, Ctrl-l/u/s work
- [ ] Open OpenCode picker (`<leader>ao`): verify all sections display with `.opencode/` paths
- [ ] Verify heading previews show correct README paths for both pickers
- [ ] Run grep across all modified files to confirm no remaining hardcoded `".claude/"` in path construction contexts (exclude comments, string literals that reference the Claude product name, and variable names)
- [ ] Verify no Lua errors in `:messages` after exercising both pickers
- [ ] Test backward compatibility: calling any updated function without config still defaults to `.claude`

**Timing**: 30 minutes

**Verification commands**:
```bash
# Search for remaining hardcoded paths in modified files
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua
grep -n '\.claude/' lua/neotex/plugins/ai/claude/commands/parser.lua

# Verify modules load without errors
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.edit')" -c "q"
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.utils.scan')" -c "q"
nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.parser')" -c "q"
```

**Files verified (not modified)**:
- All 7 files modified in phases 1-4

## Testing & Validation

- [ ] Claude picker (`<leader>ac`) displays all sections with correct paths
- [ ] OpenCode picker (`<leader>ao`) displays all sections with `.opencode/` paths
- [ ] Heading previews show README.md from correct base_dir
- [ ] Ctrl-l (load locally) uses correct base_dir
- [ ] Ctrl-u (update from global) uses correct base_dir
- [ ] Ctrl-s (save to global) uses correct base_dir
- [ ] Load Core Agent System uses correct base_dir (already working from task 118)
- [ ] No remaining hardcoded `".claude/"` in path construction contexts
- [ ] All modules load without Lua errors
- [ ] Backward compatibility: functions called without config default to `.claude`

## Artifacts & Outputs

- Modified files: entries.lua, previewer.lua, sync.lua, edit.lua, scan.lua, parser.lua, init.lua
- 23 hardcoded path segments replaced across 7 files
- All function signatures extended with backward-compatible config/base_dir parameters

## Rollback/Contingency

All changes are purely additive (new optional parameters with defaults). Rolling back requires reverting the commits for phases 1-4. Since each phase is independently committable and the defaults preserve existing behavior, partial rollback is safe.
