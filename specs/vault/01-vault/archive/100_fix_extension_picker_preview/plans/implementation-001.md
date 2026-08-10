# Implementation Plan: Task #100

- **Task**: 100 - fix_extension_picker_preview
- **Date**: 2026-03-01
- **Feature**: Fix "Unknown entry type" in main picker preview for extension, agent, and root_file entries
- **Status**: [COMPLETED]
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `<leader>ac` main artifact picker displays extension entries under the `[Extensions]` heading, but hovering over them shows "Unknown entry type" because `previewer.lua` lacks handlers for the `"extension"`, `"agent"`, and `"root_file"` entry types. The fix adds three preview functions and wires them into the dispatcher. A reference implementation for extension previews already exists in `extensions/picker.lua:41-106`.

### Research Integration

- Root cause confirmed at `previewer.lua:577-578` (else clause in `create_command_previewer()`)
- Three entry types missing: `"extension"`, `"agent"`, `"root_file"` (all fall through to "Unknown entry type")
- Extension entry data structure carries name, description, status, version, language fields
- `extensions.get_details(name)` provides rich metadata (provides, mcp_servers, installed_files)
- Existing preview functions follow a consistent pattern: build `lines` table, call `nvim_buf_set_lines`, set filetype

## Goals & Non-Goals

**Goals**:
- Fix the "Unknown entry type" preview for extension entries in the main picker
- Add preview support for agent entries
- Add preview support for root_file entries
- Maintain consistency with existing previewer patterns

**Non-Goals**:
- Changing the extension entry creation logic in `entries.lua`
- Modifying the dedicated extension picker at `extensions/picker.lua`
- Adding new entry types or restructuring the dispatch logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `extensions.get_details()` returns nil for unknown extension | L | L | Fall back to basic entry.value fields (name, description, status, version) |
| Extensions module not available (pcall fails) | L | L | Use pcall for lazy require; show basic info from entry.value without get_details() |
| Agent file unreadable | L | L | Follow existing pattern (pcall + fallback like preview_doc) |
| Root file too large for preview | M | L | Reuse MAX_PREVIEW_LINES truncation from preview_doc |

## Implementation Phases

### Phase 1: Add extension preview function and dispatch [COMPLETED]

**Goal**: Fix the primary reported bug -- extension entries showing "Unknown entry type" in the preview pane.

**Tasks**:
- [ ] Add `preview_extension(self, entry)` function to `previewer.lua` before `create_command_previewer()`
- [ ] Use `pcall(require, "neotex.plugins.ai.claude.extensions")` for lazy loading
- [ ] Call `extensions.get_details(entry.value.name)` for rich metadata
- [ ] Display: Name + Version heading, Status, Language, Description
- [ ] Display: Provides section (list agents, skills, commands, rules, context, scripts)
- [ ] Display: MCP Servers section (if present)
- [ ] Display: Installed files count with truncated list (max 10 items)
- [ ] Display: Loaded-at timestamp (if present)
- [ ] Fall back to basic entry.value data if get_details() returns nil
- [ ] Add `elseif entry.value.entry_type == "extension"` branch in `create_command_previewer()` before the else clause
- [ ] Set buffer filetype to "markdown"

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Add preview_extension function and dispatch branch

**Verification**:
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"`
- No lua syntax errors in file

---

### Phase 2: Add agent and root_file preview functions and dispatch [COMPLETED]

**Goal**: Fix the remaining two "Unknown entry type" cases for agent and root_file entries.

**Tasks**:
- [ ] Add `preview_agent(self, entry)` function to `previewer.lua`
- [ ] Display: Agent name heading, Description, File path, Local/Global status
- [ ] Optionally read first lines of agent file for additional context (use pcall + MAX_PREVIEW_LINES pattern)
- [ ] Add `preview_root_file(self, entry)` function to `previewer.lua`
- [ ] Display file metadata header (name, path, local/global status)
- [ ] Read and display file contents using existing preview_doc pattern (pcall + io.open + MAX_PREVIEW_LINES truncation)
- [ ] Handle markdown files (set filetype to "markdown") vs JSON/other files (set filetype appropriately)
- [ ] Add two `elseif` branches in `create_command_previewer()` for "agent" and "root_file" before the else clause
- [ ] Set buffer filetype appropriately for each preview type

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Add preview_agent and preview_root_file functions and dispatch branches

**Verification**:
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"`
- No lua syntax errors in file
- All three new entry types handled (no "Unknown entry type" in dispatch)

---

### Phase 3: Validation and verification [COMPLETED]

**Goal**: Verify the fix works end-to-end without regressions.

**Tasks**:
- [ ] Run headless module load test for previewer.lua
- [ ] Run headless module load test for entries.lua (no changes expected, but verify no dependency issues)
- [ ] Verify the dispatch logic covers all entry types by grep for "Unknown entry type" and confirming only the else clause remains
- [ ] Run any existing picker tests if present
- [ ] Verify extensions module lazy-loading via pcall does not affect startup when no extensions are installed

**Timing**: 0.25 hours

**Files to modify**:
- None (verification only)

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"` exits cleanly
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"` exits cleanly
- grep confirms "Unknown entry type" string exists only in the else fallback (not in any new preview functions)

## Testing & Validation

- [ ] previewer.lua loads without errors in headless Neovim
- [ ] entries.lua loads without errors in headless Neovim
- [ ] Extension preview displays rich metadata (name, version, status, provides)
- [ ] Extension preview gracefully handles missing extensions module
- [ ] Agent preview displays name, description, filepath, and local/global status
- [ ] Root file preview displays file contents with truncation for large files
- [ ] Existing preview functions (skill, command, doc, etc.) unaffected
- [ ] No "Unknown entry type" for extension, agent, or root_file entries

## Artifacts & Outputs

- Modified `previewer.lua` with three new preview functions and updated dispatch logic
- No new files created

## Rollback/Contingency

Revert the single modified file (`previewer.lua`) via `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`. The change is isolated to one file with no external dependencies added.
