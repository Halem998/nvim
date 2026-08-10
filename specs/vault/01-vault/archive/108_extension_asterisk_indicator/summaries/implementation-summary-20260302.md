# Implementation Summary: Task #108

**Completed**: 2026-03-02
**Duration**: ~5 minutes

## Changes Made

Added asterisk (*) prefix indicator to extensions with "active" status in the `<leader>ac` picker. This brings extensions into alignment with all other artifact types (commands, skills, agents, hooks, docs, lib, scripts, tests, templates) which already display the `*` prefix for local/active items.

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Modified `create_extensions_entries()` function:
  - Added `prefix` variable based on `ext.status == "active"` condition (line 605)
  - Updated `string.format` call to include `%s` prefix field in display string (lines 615-622)

## Implementation Details

The change follows the exact pattern used by other artifact types in the same file:

```lua
-- Asterisk prefix for active extensions (loaded and current)
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

Extensions now display:
- `*` prefix when status is "active" (extension is loaded AND version matches available)
- ` ` (space) prefix when status is "inactive" or "update-available"

## Verification

- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"` - Success
- Syntax verification passed
- Column alignment consistent with other artifact types

## Notes

The asterisk indicator convention is already documented in the picker help text (previewer.lua), so no documentation updates are needed. Users familiar with the `*` indicator for other artifact types will now see consistent behavior for extensions.
