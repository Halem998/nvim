# Research Report: Task 519 - Unified AI Commands Loader Picker

- **Task**: 519 - Add `<leader>al` AI commands loader picker
- **Started**: 2026-05-04T05:12:20Z
- **Completed**: 2026-05-04T05:13:00Z
- **Effort**: < 1 hour
- **Dependencies**: 518 (infrastructure reuse)
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (task 518 output)
  - `lua/neotex/plugins/editor/which-key.lua` lines 246-282 (keymaps)
  - `lua/neotex/plugins/ai/claude/commands/picker.lua` (Claude picker facade)
  - `lua/neotex/plugins/ai/opencode/commands/picker.lua` (OpenCode picker facade)
  - `docs/AI_TOOLING.md` (documentation)
- **Artifacts**: specs/519_add_leader_al_ai_commands_loader_picker/reports/01_commands-loader-picker.md
- **Standards**: report.md

## Executive Summary

- Straightforward extension of task 518's `ai-tool-picker.lua` — same `vim.ui.select` pattern, same `tool-prefs.json` persistence, different downstream action
- Only two files need changing: `ai-tool-picker.lua` (add ~15 lines) and `which-key.lua` (add ~10 lines)
- All infrastructure already exists: persistence, picker pattern, command facades, which-key group
- Must handle both normal mode (command browser: `ClaudeCommands`/`OpencodeCommands`) and visual mode (send selection with prompt)
- Effort estimate: 30 minutes (write + verify)

## Context & Scope

### Current State

Task 518's `ai-tool-picker.lua` provides:

| Component | Function | Purpose |
|-----------|----------|---------|
| Persistence | `load_tool_prefs()` / `save_tool_prefs()` | Read/write `tool-prefs.json`, last-tool-first ordering |
| Stage 1 picker | `show_tool_picker()` | `vim.ui.select` with Claude/OpenCode, reordered by last use |
| Stage 2 Claude | `show_claude_session_picker()` | Delegates to existing session picker |
| Stage 2 OpenCode | `show_opencode_session_picker()` | Telescope dropdown: new/restore/browse |
| Smart toggle | `smart_toggle()` | Direct toggle if one visible, picker otherwise |

Existing which-key bindings:

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>ac` | n | `ClaudeCommands` — browse Claude commands/agents/skills |
| `<leader>ac` | v | `send_visual_to_claude_with_prompt()` |
| `<leader>ao` | n | `OpencodeCommands` — browse OpenCode commands/agents/extensions |
| `<leader>ao` | v | `send_visual_to_opencode_with_prompt()` |

### Scope

**In scope**:
- Add `show_commands_picker()` function to `ai-tool-picker.lua`
- Add `<leader>al` keymap with normal and visual mode variants to `which-key.lua`
- Reuse existing `show_tool_picker()` and persistence

**Out of scope**:
- Session management (already handled by `<C-CR>`)
- New persistence mechanism (reuses `tool-prefs.json` shared with `<C-CR>` picker)
- Modifications to `keymaps.lua` (all changes in which-key.lua)
- Third tool support

## Findings

### Finding 1: Direct Reuse of `show_tool_picker()` Won't Work

`show_tool_picker()` at `ai-tool-picker.lua:134` hardcodes Stage 2 routing to session pickers:
- Claude -> `M.show_claude_session_picker()`
- OpenCode -> `M.show_opencode_session_picker()`

A separate function is needed that routes to commands instead of sessions.

### Finding 2: Visual Mode Requires Context-Aware Dispatch

`<leader>ac` and `<leader>ao` have different actions per mode:
- Normal mode: open commands browser (user command)
- Visual mode: send selection with prompt (function call)

The `<leader>al` picker callback must detect `vim.api.nvim_get_mode().mode` to dispatch correctly:
- Visual mode: call `send_visual_to_{tool}_with_prompt()` then `vim.cmd("ClaudeCommands")` or `vim.cmd("OpencodeCommands")`
- Normal mode: just call the user command

### Finding 3: Persistence is Already Shared

The `tool-prefs.json` file tracks last selected tool regardless of context (session management via `<C-CR>` or commands via `<leader>al>`). This is the correct behavior — if a user last selected Claude for session management, they likely want Claude for commands too.

### Finding 4: Implementation is Two Additions to One File

The entire change fits in `ai-tool-picker.lua`:

```lua
-- Add after show_tool_picker() (line 164):

function M.show_commands_picker()
  ensure_data_dir()
  load_tool_prefs()
  local mode = vim.api.nvim_get_mode().mode

  local items = {
    { label = "Claude Code", value = "claude" },
    { label = "OpenCode", value = "opencode" },
  }
  if tool_prefs.last_tool == "opencode" then
    items = { items[2], items[1] }
  end

  vim.ui.select(items, { prompt = "Select AI commands:" }, function(choice)
    if not choice then return end
    save_tool_prefs(choice.value)
    if mode == "v" or mode == "V" or mode == "\22" then
      if choice.value == "claude" then
        require("neotex.plugins.ai.claude.core.visual").send_visual_to_claude_with_prompt()
      else
        require("neotex.plugins.ai.opencode.core.visual").send_visual_to_opencode_with_prompt()
      end
    else
      vim.cmd(choice.value == "claude" and "ClaudeCommands" or "OpencodeCommands")
    end
  end)
end
```

### Finding 5: Which-key Change is Two Lines

```lua
-- Normal mode (commands browser)
{ "<leader>al", function()
  local ok, picker = pcall(require, "neotex.plugins.ai.shared.picker.ai-tool-picker")
  if not ok then return end
  if not picker._initialized then picker.setup() end
  picker.show_commands_picker()
end, desc = "ai load commands/agents", mode = { "n" }, icon = "󰚩" },

-- Visual mode (send selection with prompt)
{ "<leader>al", function()
  local ok, picker = pcall(require, "neotex.plugins.ai.shared.picker.ai-tool-picker")
  if not ok then return end
  if not picker._initialized then picker.setup() end
  picker.show_commands_picker()
end, desc = "ai send selection with prompt", mode = { "v" }, icon = "󰚩" },
```

The two entries use `mode = { "n" }` and `mode = { "v" }` to disambiguate; which-key handles the collision.

### Finding 6: Documentation Needs Minor Updates

Files to update:
- `docs/AI_TOOLING.md`: add `<leader>al` to keybindings list and picker description
- `docs/MAPPINGS.md`: add `<leader>al` row
- `lua/neotex/config/keymaps.lua` header comments: add `<leader>al` line

## Decisions

- **Separate `show_commands_picker()` function** instead of modifying `show_tool_picker()` — keeps session and commands paths independent
- **Mode detection in callback** rather than two separate functions — simpler, avoids duplication
- **Reuse `tool-prefs.json`** shared with `<C-CR>` picker — user's tool preference is consistent across contexts
- **No docs changes for `<leader>al>` in keymaps.lua body** — which-key.lua handles the binding; header comments only

## Recommendations

### Implementation (single phase, ~30 min)

1. Add `show_commands_picker()` function to `ai-tool-picker.lua` after line 164
2. Add `<leader>al` keymaps to which-key.lua after the `<leader>as` entry (line 265)
3. Update header comments in keymaps.lua (lines 24 and ~78)
4. Update `docs/AI_TOOLING.md` keybindings and picker tables
5. Update `docs/MAPPINGS.md` with new `<leader>al` row
6. Verify: `<leader>al>` in normal mode -> picker -> ClaudeCommands/OpencodeCommands opens
7. Verify: `<leader>al>` in visual mode -> picker -> sends selection with prompt

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `nvim_get_mode().mode` returns wrong value in picker callback | Low | Medium | Tested pattern — mode is captured before `vim.ui.select` runs and is stable |
| `<leader>al>` conflicts with other keymaps | Low | Low | Checked — no `<leader>al>` binding exists in codebase |
| Which-key duplicate keymap collision | Low | Low | Using `mode` field to disambiguate — same pattern used by `<leader>ac>` and `<leader>ao>` lines 250-282 |

## Appendix

### Relevant File Inventory

| File | Lines | Purpose |
|------|-------|---------|
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | 362 | Core picker module — will receive `show_commands_picker()` |
| `lua/neotex/plugins/editor/which-key.lua` | 246-282 | Which-key group — will receive `<leader>al>` entries |
| `lua/neotex/plugins/ai/claude/commands/picker.lua` | 20 | Claude facade — `show_commands_picker()` calls `internal.show_commands_picker()` with Claude config |
| `lua/neotex/plugins/ai/opencode/commands/picker.lua` | 20 | OpenCode facade — `show_commands_picker()` calls `internal.show_commands_picker()` with OpenCode config |
| `docs/AI_TOOLING.md` | 38-60 | AI tooling docs — add `<leader>al>` to tables |
| `docs/MAPPINGS.md` | 123-133 | Mappings reference — add `<leader>al>` row |
| `lua/neotex/config/keymaps.lua` | 23-24, 78 | Header comments — add `<leader>al>` line |

### Persistence File

```
~/.local/share/nvim/neotex-ai/tool-prefs.json
{
  "last_tool": "claude",
  "last_updated": 1777867353
}
```
