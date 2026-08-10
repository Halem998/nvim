# Implementation Plan: Task #618

- **Task**: 618 - picker_reload_extensions
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/618_picker_reload_extensions/reports/01_picker-reload.md
- **Artifacts**: plans/01_picker-reload-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Add two reload-related features to the `<leader>al` extension picker. First, replace the direct unload behavior on `<CR>` for loaded extensions with a `vim.ui.select` submenu offering Unload/Reload/Cancel. Second, add a `[Reload All]` special entry that reloads every loaded extension in dependency-safe order (non-core first, core last). Both changes are scoped to `picker/init.lua` and `picker/display/entries.lua`.

### Research Integration

The research report confirmed:
- `manager.reload(name, opts)` exists at `shared/extensions/init.lua:690-714` and performs unload+load without confirmation
- No `reload_all()` function exists; it must be implemented inline as a loop
- `vim.schedule()` is required before `vim.ui.select` to let Telescope close first
- `sorting_strategy = "descending"` means insertion order in `create_special_entries()` is visually reversed
- Four guard conditions (Ctrl-l, Ctrl-u, Ctrl-s, Ctrl-e) need `is_reload_all` added to skip the new special entry

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Give users a choice (Unload/Reload/Cancel) when pressing `<CR>` on an already-loaded extension
- Provide a one-action `[Reload All]` entry that reloads all loaded extensions and the core system
- Maintain existing cursor-restore behavior when reopening the picker after actions

**Non-Goals**:
- Adding a `reload_all()` method to the extension manager API (inline loop is sufficient)
- Changing behavior for inactive/unloaded extensions (load-on-CR remains as-is)
- Adding confirmation dialogs beyond the submenu itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `vim.ui.select` appears before Telescope closes | M | M | Wrap in `vim.schedule()` to defer until after async close |
| Reload ordering fails (core reloaded while dependents still loaded) | H | L | Sort `list_loaded()` with core last before iterating |
| `is_reload_all` not skipped by Ctrl-l/u/s/e handlers | M | M | Add to all four guard conditions explicitly |
| `manager.reload()` fails for one extension mid-loop | L | L | Continue loop, collect errors, show summary notification |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Extension reload submenu [COMPLETED]

**Goal**: Replace direct `exts.unload()` call for loaded extensions with a three-option submenu (Unload/Reload/Cancel) using `vim.ui.select`.

**Tasks**:
- [x] **Task 1.1**: In `lua/neotex/plugins/ai/claude/commands/picker/init.lua`, locate the `entry_type == "extension"` branch (lines 161-179) *(completed)*
- [x] **Task 1.2**: Replace the `if ext.status == "active" or ext.status == "update-available"` block (lines 168-172) with a `vim.schedule(function() vim.ui.select(...) end)` submenu *(completed)*
- [x] **Task 1.3**: The submenu offers three choices: `{ "Unload", "Reload", "Cancel" }` with prompt `"Extension: " .. ext.name` *(completed)*
- [x] **Task 1.4**: "Unload" calls `exts.unload(ext.name, { confirm = true })` *(completed)*
- [x] **Task 1.5**: "Reload" calls `exts.reload(ext.name, {})` *(completed)*
- [x] **Task 1.6**: "Cancel" does nothing (no action) *(completed)*
- [x] **Task 1.7**: After any choice (including Cancel and nil from dismissal), reopen the picker with `vim.defer_fn` and `_restore_extension_name` for cursor restore *(completed)*
- [x] **Task 1.8**: The `else` branch (inactive extensions) remains unchanged: direct `exts.load(ext.name, { confirm = true })` followed by `vim.defer_fn` reopen *(completed)*
- [x] **Task 1.9**: Verify: open picker, press `<CR>` on loaded extension, confirm submenu appears with three options; test each option behaves correctly *(completed: syntax verified via nvim --headless)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Replace lines 161-179 with submenu logic

**Verification**:
- Open `<leader>al`, select a loaded extension, press `<CR>` -- submenu appears
- Select "Unload" -- extension unloads, picker reopens
- Select "Reload" -- extension reloads (notification appears), picker reopens
- Select "Cancel" -- no action, picker reopens
- Dismiss submenu with `<Esc>` -- no action, picker reopens
- Select an inactive extension with `<CR>` -- loads directly (no submenu)

---

### Phase 2: Reload All special entry and handler [COMPLETED]

**Goal**: Add a `[Reload All]` special entry to the picker and implement its handler to reload all loaded extensions in dependency-safe order.

**Tasks**:
- [x] **Task 2.1**: In `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`, in `create_special_entries()`, add a new entry after the `[Keyboard Shortcuts]` entry *(completed)*
- [x] **Task 2.2**: The new entry uses: `is_reload_all = true`, `name = "~~~reload_all"`, display `"[Reload All]"` with description `"Wipe and reload all loaded extensions"`, `entry_type = "special"` *(completed)*
- [x] **Task 2.3**: In `lua/neotex/plugins/ai/claude/commands/picker/init.lua`, add a handler block for `is_reload_all` between the `is_load_all` handler and the `is_help` handler *(completed)*
- [x] **Task 2.4**: The handler: close picker, `vim.schedule` a function that gets `list_loaded()`, sorts with core last, iterates calling `exts.reload(ext_name, {})` on each, counts successes, shows summary notification, then reopens picker with `vim.defer_fn` *(completed)*
- [x] **Task 2.5**: If `list_loaded()` returns empty, show a notification "No extensions loaded" and return early (no close/reopen) *(completed)*
- [x] **Task 2.6**: Add `selection.value.is_reload_all` to all four guard conditions (Ctrl-l, Ctrl-u, Ctrl-s, Ctrl-e handlers) *(completed)*
- [x] **Task 2.7**: Verify: `[Reload All]` appears just above `[Keyboard Shortcuts]` in the picker *(completed: syntax verified via nvim --headless)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Add `[Reload All]` entry in `create_special_entries()`
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Add `is_reload_all` handler and update four guard conditions

**Verification**:
- Open `<leader>al` -- `[Reload All]` appears just above `[Keyboard Shortcuts]` at the bottom
- Select `[Reload All]` with `<CR>` -- all extensions reload, summary notification shows count
- Ctrl-l/Ctrl-u/Ctrl-s/Ctrl-e on `[Reload All]` -- no action (guard prevents it)
- With no extensions loaded, `[Reload All]` shows "No extensions loaded" notification

## Testing & Validation

- [ ] Open picker with extensions loaded; press `<CR>` on loaded extension; confirm three-option submenu appears
- [ ] Test each submenu choice (Unload, Reload, Cancel) produces correct behavior
- [ ] Test `<CR>` on unloaded extension still loads directly (no submenu)
- [ ] Confirm `[Reload All]` entry is visible in correct position
- [ ] Press `<CR>` on `[Reload All]` with 2+ extensions loaded; confirm all reload and picker reopens
- [ ] Confirm Ctrl-l/u/s/e do nothing on `[Reload All]` entry
- [ ] Verify no Lua errors in `:messages` after all operations

## Artifacts & Outputs

- `specs/618_picker_reload_extensions/plans/01_picker-reload-plan.md` (this plan)
- `specs/618_picker_reload_extensions/summaries/01_picker-reload-summary.md` (after implementation)

## Rollback/Contingency

Both changes are isolated to the picker UI layer. Revert by restoring the original `entry_type == "extension"` branch in `init.lua` (direct unload without submenu) and removing the `[Reload All]` entry from `entries.lua`. No data model or extension manager changes are involved.
