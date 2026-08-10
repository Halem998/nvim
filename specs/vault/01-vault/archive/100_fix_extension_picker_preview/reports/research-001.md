# Research Report: Task #100

**Task**: 100 - fix_extension_picker_preview
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T00:15:00Z
**Effort**: 1-2 hours
**Dependencies**: Task 99 (extension system - completed)
**Sources/Inputs**: Local codebase analysis (picker display modules, extension modules)
**Artifacts**: - specs/100_fix_extension_picker_preview/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- The "Unknown entry type" message in the `<leader>ac` picker preview is caused by a missing `"extension"` case in the previewer's dispatch logic at `previewer.lua:577`
- Two additional entry types (`"agent"` and `"root_file"`) are also missing from the previewer dispatch, though only extensions were reported as broken
- The fix requires adding three `preview_*` functions to `previewer.lua` and three corresponding `elseif` branches in `create_command_previewer()`
- A reference implementation already exists in the dedicated extension picker at `extensions/picker.lua:41-106` that demonstrates how to render extension details

## Context & Scope

The task 99 implementation added an extension system with:
1. `extensions/init.lua` - Public API including `get_details()` for rich extension info
2. `extensions/manifest.lua` - Extension manifest parsing
3. `display/entries.lua` - Entry creation, including `create_extensions_entries()` at line 585
4. `extensions/picker.lua` - A dedicated extension management picker (`<leader>ae`)

However, extensions also appear in the main artifact picker (`<leader>ac`) under the `[Extensions]` heading. The main picker's previewer at `display/previewer.lua` does not have a handler for the `"extension"` entry type, so it falls through to the `else` clause at line 577-578, displaying "Unknown entry type".

## Findings

### Root Cause Analysis

**File**: `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
**Location**: `create_command_previewer()` function, lines 551-582

The dispatch logic handles these entry types:
- `is_heading` (line 555)
- `is_help` (line 557)
- `is_load_all` (line 559)
- `"skill"` (line 561)
- `"hook_event"` (line 563)
- `"lib"` (line 565)
- `"script"` (line 567)
- `"test"` (line 569)
- `"template"` (line 571)
- `"doc"` (line 573)
- `"command"` (line 575)

**Missing entry types** (all fall through to "Unknown entry type"):
1. `"extension"` - Created by `create_extensions_entries()` (entries.lua:585-646)
2. `"agent"` - Created by `create_agents_entries()` (entries.lua:385-417)
3. `"root_file"` - Created by `create_root_files_entries()` (entries.lua:439-471)

### Extension Entry Data Structure

Extension entries created by `create_extensions_entries()` carry these fields:

```lua
{
  display = "  |-  lean        [active]   Lean 4 theorem prover support...",
  entry_type = "extension",
  name = "lean",                    -- Extension name
  description = "Lean 4 ...",       -- From manifest.description
  status = "active",                -- "active", "inactive", "update-available"
  version = "1.0.0",               -- From manifest.version
  language = "lean4",              -- From manifest.language
  ordinal = "zzzz_extension_lean",
}
```

Additionally, `extensions.get_details(name)` returns:

```lua
{
  name = "lean",
  version = "1.0.0",
  description = "Lean 4 theorem prover support...",
  language = "lean4",
  provides = {
    agents = {"lean-research-agent.md", "lean-implementation-agent.md"},
    skills = {"skill-lean-research", "skill-lean-implementation", ...},
    commands = {"lake.md", "lean.md"},
    rules = {"lean4.md"},
    context = {"project/lean4"},
    scripts = {"setup-lean-mcp.sh", "verify-lean-mcp.sh"},
  },
  merge_targets = { claudemd = {...}, settings = {...}, index = {...} },
  mcp_servers = { ["lean-lsp"] = { command = "npx", args = {...} } },
  status = "active",
  loaded_at = "2026-02-28T...",
  installed_files = { "agents/lean-research-agent.md", ... },
}
```

### Agent Entry Data Structure

Agent entries carry:

```lua
{
  display = "  |- agent-name     Description...",
  entry_type = "agent",
  name = "agent-name",
  description = "Agent description",
  filepath = "/path/to/agent.md",
  is_local = true,
  ordinal = "zzzz_agent_agent-name",
}
```

### Root File Entry Data Structure

Root file entries carry:

```lua
{
  display = "  |- settings.json  Configuration file",
  entry_type = "root_file",
  name = "settings.json",
  description = "Configuration file",
  filepath = "/path/to/settings.json",
  is_local = true,
  ordinal = "zzzz_root_file_settings.json",
}
```

### Reference Implementation

The dedicated extension picker at `extensions/picker.lua:41-106` already has a complete preview renderer. Key sections:
1. Extension name and version (heading)
2. Status and language
3. Description
4. Provides section (lists agents, skills, commands, etc.)
5. MCP Servers section
6. Installed files (truncated at 10)
7. Loaded-at timestamp

This implementation calls `extensions.get_details()` for rich data, which is the same approach the main picker's previewer should use.

### Existing Pattern for Previewer Functions

Each preview function in `previewer.lua` follows a consistent pattern:
1. Accept `(self, entry)` parameters
2. Build a `lines` table with formatted content
3. Call `vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)`
4. Optionally set filetype with `vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")`

### Recommendations

#### Implementation Approach

**Step 1**: Add `preview_extension(self, entry)` function to `previewer.lua`

The function should:
- Call `extensions.get_details(entry.value.name)` for rich metadata
- Display: Name, Version, Status, Language, Description
- Display: Provides section (list what the extension installs)
- Display: MCP Servers (if any)
- Display: Installed files count (if active)
- Fall back gracefully if `get_details()` returns nil (show basic info from entry.value)

**Step 2**: Add `preview_agent(self, entry)` function to `previewer.lua`

The function should mirror `preview_skill()` but for agents:
- Display: Name, Description, File path, Local/Global status
- Optionally read the first few lines of the agent file for additional context

**Step 3**: Add `preview_root_file(self, entry)` function to `previewer.lua`

The function should:
- Read and display file contents (similar to `preview_doc` for .md, or raw for .json)
- Show file metadata (name, path, local/global status)

**Step 4**: Add three `elseif` branches in `create_command_previewer()`

Insert before the `else` clause (line 577):
```lua
elseif entry.value.entry_type == "extension" then
  preview_extension(self, entry)
elseif entry.value.entry_type == "agent" then
  preview_agent(self, entry)
elseif entry.value.entry_type == "root_file" then
  preview_root_file(self, entry)
```

**Step 5**: Add the extensions module require at the top of the file (lazy or inline)

Since `require("neotex.plugins.ai.claude.extensions")` may fail if extensions are not available, use `pcall` or lazy require pattern.

#### Lazy Loading Strategy

The extensions module is already loaded via `pcall` in entries.lua:589. The previewer should use the same pattern:
```lua
local ok, ext_mod = pcall(require, "neotex.plugins.ai.claude.extensions")
```

#### Testing Strategy

1. Headless test: Load previewer module and verify no errors
2. Manual verification: Open `<leader>ac`, navigate to [Extensions] section, hover over entries
3. Edge cases: Test with no extensions loaded, with active extension, with update-available

## Decisions
- Fix all three missing entry types (extension, agent, root_file) in a single implementation
- Reuse the pattern from `extensions/picker.lua` for extension preview rendering
- Use `pcall` for lazy-loading the extensions module in the previewer
- Keep previewer functions consistent with existing patterns (lines table, buf_set_lines, filetype)

## Risks & Mitigations
- **Risk**: `extensions.get_details()` call in previewer could be slow if it reads many manifest files
  - **Mitigation**: The dedicated picker already calls this without issues; manifest files are small JSON
- **Risk**: Agent/root_file file reads could fail
  - **Mitigation**: Follow existing pattern with `pcall` and fallback display (see `preview_doc`, `preview_script`)
- **Risk**: Extensions module not available (pcall fails)
  - **Mitigation**: Fall back to displaying basic entry data (name, description, status, version) without `get_details()`

## Context Extension Recommendations
- none (extension system was just documented in task 99)

## Appendix

### Files Analyzed
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Main previewer with missing handlers (585 lines)
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Entry creation module (764 lines)
- `lua/neotex/plugins/ai/claude/extensions/init.lua` - Extensions public API (438 lines)
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua` - Manifest parsing (251 lines)
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Dedicated extension picker with reference preview (245 lines)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua` - Shared helper utilities (165 lines)
- `.claude/extensions/lean/manifest.json` - Sample manifest for data structure reference

### Key Line References
- **Bug location**: `previewer.lua:577-578` (else clause with "Unknown entry type")
- **Extension entries created**: `entries.lua:585-646` (`create_extensions_entries()`)
- **Agent entries created**: `entries.lua:385-417` (`create_agents_entries()`)
- **Root file entries created**: `entries.lua:439-471` (`create_root_files_entries()`)
- **Dispatch logic**: `previewer.lua:551-582` (`create_command_previewer()`)
- **Reference preview**: `extensions/picker.lua:41-106` (`create_previewer()`)
- **Get details API**: `extensions/init.lua:414-436` (`M.get_details()`)
