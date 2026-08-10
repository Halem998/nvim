# Research Report: Task #108

**Task**: 108 - Show active/current extensions with '*' indicator in picker
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:10:00Z
**Effort**: 0.5-1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of picker display, extensions module, shared extensions state
**Artifacts**: - specs/108_extension_asterisk_indicator/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `<leader>ac` picker already uses a `*` prefix convention for all other artifact types (commands, skills, hooks, agents, docs, lib, scripts, tests, templates) to indicate locally-available artifacts
- Extensions are the ONLY artifact type in the picker that does NOT use the `*` prefix pattern
- The fix requires modifying a single function: `create_extensions_entries()` in `entries.lua` (lines 585-646)
- An extension should show `*` when its status is `"active"` (loaded AND version matches available), meaning it is both loaded and current

## Context & Scope

The task requests adding a `*` indicator next to extensions in the `<leader>ac` Claude Commands picker (implemented as `ClaudeCommands` user command). The asterisk should appear for extensions that are:
1. Loaded (active status in the extensions state)
2. Current (installed version matches available version, i.e., NOT "update-available")

This matches the existing convention where `*` means the artifact is locally present/active in the project.

## Findings

### Existing `*` Indicator Pattern

Every other artifact type in the picker already uses the `*` prefix pattern. The convention is:

```
*  ├─ artifact-name            Description
   ├─ another-artifact         Description (no * = global only)
```

The `*` prefix is typically determined by `artifact.is_local` (whether the artifact exists in the project's local `.claude/` directory). For extensions, the analogous concept is whether the extension is loaded and current.

**Implementation references for the `*` pattern**:

| Artifact Type | Location in entries.lua | Pattern |
|---------------|------------------------|---------|
| Commands | `format_command()` line 56 | `command.is_local and "*" or " "` |
| Skills | `format_skill()` line 313 | `skill.is_local and "*" or " "` |
| Agents | `format_agent()` line 330 | `agent.is_local and "*" or " "` |
| Hooks | `format_hook_event()` line 27 | `has_local_hook and "*" or " "` |
| Docs | `create_docs_entries()` line 99 | `doc.is_local and "*" or " "` |
| Lib | `create_lib_entries()` line 149 | `lib.is_local and "*" or " "` |
| Templates | `create_templates_entries()` line 195 | `tmpl.is_local and "*" or " "` |
| Scripts | `create_scripts_entries()` line 240 | `script.is_local and "*" or " "` |
| Tests | `create_tests_entries()` line 287 | `test.is_local and "*" or " "` |

### Current Extension Display (No `*`)

The `create_extensions_entries()` function (lines 585-646 of `entries.lua`) currently formats extensions without a `*` prefix:

```lua
local display = string.format(
  "  %s %-28s %-10s %s",
  indent_char,
  ext.name,
  status_indicator,
  ext.description or ""
)
```

Note the leading `"  "` (two spaces) where other artifact types have `"%s "` with the prefix character. This means extensions always have a blank prefix column.

### Extension Status System

The extension status is determined in `shared/extensions/init.lua` at `manager.list_available()` (lines 384-411):

```lua
local status = "inactive"
if state_mod.is_loaded(state, ext.name) then
  if state_mod.needs_update(state, ext.name, ext.manifest.version) then
    status = "update-available"
  else
    status = "active"
  end
end
```

Three possible statuses:
1. `"active"` - Extension is loaded AND version matches (this is the "current" state)
2. `"update-available"` - Extension is loaded BUT version differs
3. `"inactive"` - Extension is not loaded

The `*` indicator should appear when `status == "active"` because this means the extension is both loaded and up-to-date (current).

### Extension State Tracking

State is stored in `.claude/extensions.json` (created per-project when an extension is loaded). The state module (`shared/extensions/state.lua`) tracks:

- `state.extensions[name].version` - Version when loaded
- `state.extensions[name].status` - Always "active" when loaded
- `state.extensions[name].loaded_at` - ISO8601 timestamp

The `needs_update()` function compares the stored version against the current manifest version:
```lua
function M.needs_update(state, extension_name, current_version)
  local ext_info = state.extensions[extension_name]
  if not ext_info then return false end
  return ext_info.version ~= current_version
end
```

### Picker Action on Extension Select

When selecting an extension in the picker (`init.lua` lines 133-145):
- Active or update-available: calls `exts.unload(ext.name, { confirm = true })`
- Inactive: calls `exts.load(ext.name, { confirm = true })`

The `*` indicator will help users quickly see which extensions are loaded/current before toggling.

### Help Text Already Documents `*`

The previewer's help text (lines 160-162 of `previewer.lua`) already documents the `*` indicator:
```
"Indicators:",
"  *       - Artifact defined locally in project (.claude/)",
"            Otherwise a global artifact from " .. global_dir .. "/.claude/",
```

This description is about artifacts being "local", but for extensions the meaning would be slightly different (active/current vs. local on disk). The help text could optionally be updated to mention extensions specifically, but this is not strictly required since the `*` convention is already established.

### Recommendations

**Implementation approach** (single file change in `entries.lua`):

1. Add a `*` prefix to the `display` format string in `create_extensions_entries()`, using `ext.status == "active"` as the condition
2. Adjust the format string column widths to match the other artifact types' pattern

**Specific code change**:

Replace the current display format (around line 615):
```lua
local display = string.format(
  "  %s %-28s %-10s %s",
  indent_char,
  ext.name,
  status_indicator,
  ext.description or ""
)
```

With:
```lua
local prefix = (ext.status == "active") and "*" or " "
local display = string.format(
  "%s %s %-28s %-10s %s",
  prefix,
  indent_char,
  ext.name,
  status_indicator,
  ext.description or ""
)
```

This adds the `*` prefix for active (loaded AND current) extensions, and a space for inactive or update-available extensions. The format is consistent with how all other artifact types display in the picker.

**Lazy loading considerations**: None. The `create_extensions_entries()` function already calls `extensions.list_available()` which computes the status. No additional data is needed.

**Testing approach**: Load Neovim, run `<leader>ac`, verify that:
- Active extensions show `*` prefix
- Inactive extensions show space prefix
- Update-available extensions show space prefix (they have their own `[update]` indicator)
- Column alignment is preserved

## Decisions

- Use `ext.status == "active"` as the condition for `*` (matches the task requirement: "loaded AND do not differ from available version")
- Keep `[active]`, `[update]`, `[inactive]` status indicators as-is (they provide more detail, while `*` is the quick visual indicator)
- Do not modify the help text since the `*` convention is already documented

## Risks & Mitigations

- **Low risk**: This is a display-only change in a single function, no state or logic modification
- **Column alignment**: The format string needs careful width adjustment to match existing patterns. Mitigation: verify visually after implementation.

## Context Extension Recommendations

None - this is a straightforward UI feature within existing patterns.

## Appendix

### Files Examined

| File | Path | Purpose |
|------|------|---------|
| entries.lua | `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` | Display entry creation - **primary change target** |
| init.lua (picker) | `lua/neotex/plugins/ai/claude/commands/picker/init.lua` | Picker orchestration and key mappings |
| previewer.lua | `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` | Preview panel rendering |
| helpers.lua | `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua` | Shared formatting utilities |
| init.lua (extensions) | `lua/neotex/plugins/ai/claude/extensions/init.lua` | Extensions public API |
| init.lua (shared) | `lua/neotex/plugins/ai/shared/extensions/init.lua` | Shared extension manager (list_available, get_status) |
| state.lua (shared) | `lua/neotex/plugins/ai/shared/extensions/state.lua` | Extension state tracking (is_loaded, needs_update) |
| config.lua (shared) | `lua/neotex/plugins/ai/shared/extensions/config.lua` | Configuration presets |
| manifest.lua (shared) | `lua/neotex/plugins/ai/shared/extensions/manifest.lua` | Manifest parsing and validation |
| which-key.lua | `lua/neotex/plugins/editor/which-key.lua` | Keybinding for `<leader>ac` |
