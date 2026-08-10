# Implementation Plan: Task #108

- **Task**: 108 - Show active/current extensions with '*' indicator in picker
- **Status**: [COMPLETED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Add the `*` prefix indicator to extensions in the `<leader>ac` Claude Commands picker, matching the existing pattern used by all other artifact types (commands, skills, agents, hooks, docs, lib, scripts, tests, templates). Extensions with status `"active"` (loaded AND version matches available) will show `*`; all other statuses show a space.

### Research Integration

- Research confirmed extensions are the ONLY artifact type missing the `*` prefix pattern
- The condition maps directly to `ext.status == "active"` (loaded + version matches)
- Single function change in `create_extensions_entries()` with no side effects
- Column alignment must be verified to match other artifact types

## Goals & Non-Goals

**Goals**:
- Add `*` prefix to extensions with status `"active"` in the picker display
- Maintain visual alignment with all other artifact types in the picker
- Preserve existing `[active]`, `[update]`, `[inactive]` status indicators

**Non-Goals**:
- Modifying the help text in `previewer.lua` (already documents `*` convention)
- Changing extension state tracking or status computation logic
- Modifying picker actions or selection behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Column misalignment after format string change | L | L | Verify format string width matches other artifact types |
| Regression in extension display | L | L | Test with active, inactive, and update-available extensions |

## Implementation Phases

### Phase 1: Add asterisk prefix to extension entries [COMPLETED]

**Goal**: Modify `create_extensions_entries()` to include the `*` prefix for active extensions, matching the established pattern used by all other artifact types.

**Tasks**:
- [ ] Add `prefix` variable based on `ext.status == "active"` condition
- [ ] Update `string.format` call to include `%s` prefix field
- [ ] Verify column widths remain aligned with other artifact types

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Modify `create_extensions_entries()` function (lines 615-621) to add `*` prefix

**Steps**:

1. In `create_extensions_entries()` (line ~614), add a prefix variable before the `display` format string:
   ```lua
   local prefix = (ext.status == "active") and "*" or " "
   ```

2. Update the `string.format` call (line ~615-621) from:
   ```lua
   local display = string.format(
     "  %s %-28s %-10s %s",
     indent_char,
     ext.name,
     status_indicator,
     ext.description or ""
   )
   ```
   To:
   ```lua
   local display = string.format(
     "%s %s %-28s %-10s %s",
     prefix,
     indent_char,
     ext.name,
     status_indicator,
     ext.description or ""
   )
   ```

**Verification**:
- Load Neovim and open the picker with `<leader>ac`
- Active extensions display `*` prefix
- Inactive extensions display space prefix
- Update-available extensions display space prefix
- Column alignment matches other artifact types (commands, skills, agents, etc.)
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"`

---

## Testing & Validation

- [ ] Module loads without error via `nvim --headless`
- [ ] Active extensions show `*` prefix in picker
- [ ] Inactive extensions show space prefix in picker
- [ ] Update-available extensions show space prefix in picker
- [ ] Column alignment is consistent with other artifact types

## Artifacts & Outputs

- Modified file: `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`

## Rollback/Contingency

Revert the two-line change in `create_extensions_entries()`: restore the original `"  %s %-28s %-10s %s"` format string and remove the `prefix` variable. No other files are affected.
