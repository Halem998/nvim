# Research Report: Task #114

**Task**: 114 - make_leader_ao_identical_to_leader_ac
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:15:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Local config analysis, which-key.lua, keymaps.lua, picker modules
**Artifacts**: - specs/114_make_leader_ao_identical_to_leader_ac/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- `<leader>ac` has dual behavior: normal mode opens the Claude artifact picker (`ClaudeCommands`), visual mode sends selection to Claude with a prompt
- `<leader>ao` is currently a which-key **group** (not a single action) with three subcommands (`aoc`, `aoe`, `aot`)
- `<leader>ae` is **not actually mapped** anywhere; it only appears in a stale comment in `claude/extensions/picker.lua`
- Making `<leader>ao` identical to `<leader>ac` requires replacing the group with direct keymaps and relocating or removing the OpenCode subcommands

## Context & Scope

The user wants `<leader>ao` to behave identically to `<leader>ac` (one keymap for normal mode, one for visual mode) since `<C-g>` already toggles OpenCode directly. The `<leader>ae` picker should be removed entirely.

## Findings

### Current `<leader>ac` Behavior

**File**: `lua/neotex/plugins/editor/which-key.lua` (lines 242-248)

Normal mode:
```lua
{ "<leader>ac", "<cmd>ClaudeCommands<CR>", desc = "claude commands", icon = "..." }
```
- Opens the shared hierarchical Telescope picker that shows commands, skills, agents, hooks, and extensions from the `.claude/` directory
- Registered via `vim.api.nvim_create_user_command("ClaudeCommands", ...)` in `lua/neotex/plugins/ai/claude/init.lua:146`
- Implementation: `neotex.plugins.ai.claude.commands.picker.init.show_commands_picker()`

Visual mode:
```lua
{ "<leader>ac",
  function() require("neotex.plugins.ai.claude.core.visual").send_visual_to_claude_with_prompt() end,
  desc = "send selection to claude with prompt",
  mode = { "v" },
  icon = "..."
}
```
- Gets visual selection text
- Prompts user for a prompt via `vim.ui.input`
- Formats message with file path, filetype, and code block
- Sends to Claude terminal via the event-driven terminal-state module

### Current `<leader>ao` Behavior

**File**: `lua/neotex/plugins/editor/which-key.lua` (lines 261-264)

```lua
{ "<leader>ao", group = "opencode", icon = "..." },
{ "<leader>aoc", "<cmd>OpencodeCommands<CR>", desc = "opencode commands", icon = "..." },
{ "<leader>aoe", "<cmd>OpencodeExtensions<CR>", desc = "opencode extensions", icon = "..." },
{ "<leader>aot", function() require("opencode").toggle() end, desc = "opencode toggle", icon = "..." },
```

- `<leader>ao` is a **which-key group**, not a direct action
- `<leader>aoc` opens the OpenCode artifact picker (same shared picker infrastructure as Claude, parameterized for `.opencode/` directory)
- `<leader>aoe` opens the OpenCode extension management picker
- `<leader>aot` toggles the OpenCode terminal window

### Current `<leader>ae` Behavior

**Not mapped**. The only reference is a stale comment in `lua/neotex/plugins/ai/claude/extensions/picker.lua:2`:
```lua
-- Dedicated extension management picker (<leader>ae)
```

The Claude extensions picker module exists but has no keymap binding. It can be invoked via `require("neotex.plugins.ai.claude.extensions.picker").show()`.

The OpenCode extensions picker is bound to `<leader>aoe` via `OpencodeExtensions` user command.

### Other OpenCode Access Points

- `<C-g>`: Toggle OpenCode terminal (defined in `keymaps.lua:283` for modes `n`, `i`)
- `<leader>ab`: OpenCode buffer context
- `<leader>ad`: OpenCode diagnostics
- `<leader>as`: OpenCode select (CONFLICTS with `<leader>as` = Claude sessions)
- `<leader>ah`: OpenCode history

### Files That Need Modification

1. **`lua/neotex/plugins/editor/which-key.lua`** (PRIMARY)
   - Replace `<leader>ao` group with direct keymaps matching `<leader>ac` behavior
   - Normal mode: `<leader>ao` -> `<cmd>OpencodeCommands<CR>`
   - Visual mode: `<leader>ao` -> send selection to OpenCode with prompt (needs implementation or reuse of Claude visual module)
   - Remove `<leader>aoc` (absorbed into `<leader>ao`)
   - Remove `<leader>aoe` (extension picker removal)
   - Remove `<leader>aot` (user has `<C-g>` already)

2. **`lua/neotex/plugins/ai/claude/extensions/picker.lua`** (MINOR)
   - Update stale comment on line 2 that references `<leader>ae`

3. **`lua/neotex/plugins/ai/opencode/extensions/picker.lua`** (MINOR)
   - Update stale comment on line 2 that references `<leader>aoe`

4. **`docs/MAPPINGS.md`** (DOCUMENTATION)
   - Update `<leader>ao` description from "Open session" to match new behavior
   - Remove any references to `<leader>ae` or `<leader>aoe`
   - Document new `<leader>ao` behavior

5. **`lua/neotex/config/keymaps.lua`** (MINOR)
   - Update comment block header that references `<leader>aoo` (line 24)

### Recommendations

#### Implementation approach

**Option A (Simple - Recommended)**: Make `<leader>ao` in normal mode open the OpenCode Commands picker (same as `<leader>aoc` did), and in visual mode it could either:
- Reuse Claude's `send_visual_to_claude_with_prompt()` (sends to Claude, not OpenCode)
- Be a no-op in visual mode (OpenCode doesn't have a visual selection sender)
- Create a new visual mode handler for OpenCode

Since the user wants `<leader>ao` **identical** to `<leader>ac`, the simplest interpretation is:
- Normal: open the commands picker (OpenCode variant)
- Visual: send selection to OpenCode with prompt (requires checking if OpenCode has `prompt` or `ask` API)

**Option B (Literal clone)**: Make `<leader>ao` literally call the same functions as `<leader>ac`, meaning the OpenCode keymap would open Claude's picker and send to Claude's terminal. This seems unlikely to be what the user wants.

**Recommended**: Option A -- `<leader>ao` opens `OpencodeCommands` in normal mode. For visual mode, check if `opencode.nvim` supports sending text (it has `prompt()` and `select()` APIs).

#### What to remove
- Remove the `<leader>ao` group definition
- Remove `<leader>aoc`, `<leader>aoe`, `<leader>aot` subcommands
- The `OpencodeExtensions` user command and its picker module can remain -- they just won't have a keymap (accessible via `:OpencodeExtensions` command)
- Update stale `<leader>ae` comment in Claude extensions picker

#### OpenCode visual mode support
The `opencode.nvim` plugin provides:
- `require("opencode").prompt(text)` -- prompts with text context
- `require("opencode").select()` -- shows selection UI
- `require("opencode").ask()` -- asks a question

For visual mode parity, `opencode.prompt("@this")` could work (sends current selection context), or a custom handler similar to Claude's `send_visual_to_claude_with_prompt()` could be written that gets the selection, prompts the user, and sends via `opencode.prompt()`.

## Decisions

- `<leader>ao` should become a direct keymap, not a group
- Normal mode `<leader>ao` maps to `<cmd>OpencodeCommands<CR>` (mirrors `<leader>ac` -> `<cmd>ClaudeCommands<CR>`)
- Visual mode `<leader>ao` should send selection to OpenCode (needs implementation decision in planning phase)
- `<leader>aoe` (extension picker) should be removed as a keymap, command remains accessible via `:OpencodeExtensions`
- `<leader>aot` (toggle) should be removed as a keymap since `<C-g>` already toggles OpenCode

## Risks & Mitigations

- **Risk**: Visual mode `<leader>ao` may need a new module similar to `claude/core/visual.lua` for OpenCode
  - **Mitigation**: Check OpenCode's `prompt()` API to see if it accepts arbitrary text; if so, a lightweight wrapper suffices
- **Risk**: Users muscle-memory for `<leader>aoc`, `<leader>aoe`, `<leader>aot` will break
  - **Mitigation**: These are new keymaps (task 113 just added them), so muscle memory impact is minimal
- **Risk**: `<leader>as` conflict (Claude sessions vs OpenCode select) exists but is out of scope
  - **Mitigation**: Note for future cleanup task

## Context Extension Recommendations

None -- this is a straightforward keymap refactoring task.

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` - All leader keymaps
- `/home/benjamin/.config/nvim/lua/neotex/config/keymaps.lua` - Non-leader keymaps including `<C-g>` and `<C-CR>`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/core/visual.lua` - Claude visual selection handler
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/extensions/picker.lua` - Claude extension picker (has stale `<leader>ae` comment)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/extensions/picker.lua` - OpenCode extension picker
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/init.lua` - ClaudeCommands user command registration
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode.lua` - OpencodeCommands and OpencodeExtensions registration
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/picker/config.lua` - Shared picker configuration
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/commands/picker.lua` - OpenCode commands picker facade
- `/home/benjamin/.config/nvim/docs/MAPPINGS.md` - Keymap documentation
