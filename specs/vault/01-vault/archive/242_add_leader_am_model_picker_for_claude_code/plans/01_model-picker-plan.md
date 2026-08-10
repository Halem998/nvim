# Implementation Plan: Task #242

- **Task**: 242 - add_leader_am_model_picker_for_claude_code
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: specs/242_add_leader_am_model_picker_for_claude_code/reports/01_model-picker-research.md
- **Artifacts**: plans/01_model-picker-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Implement a `<leader>am` keymap that opens a model picker for Claude Code using `vim.ui.select`. The picker displays three Anthropic models (Opus, Sonnet, Haiku) with the current model marked, updates `~/.config/.claude/settings.local.json` on selection, and notifies the user that a restart is required. Also change the default model from `sonnet` to `opus`.

### Research Integration

- Yolo mode toggle pattern (lines 308-364 in which-key.lua) provides template for file modification with error handling
- `vim.ui.select` with `format_item` is the established pattern for simple pickers
- Model values use short aliases: `opus`, `sonnet`, `haiku`
- Current model indicator uses `[*]` marker

## Goals & Non-Goals

**Goals**:
- Add `<leader>am` keymap in `<leader>a` (AI) group
- Display picker with three models: Opus 4.6, Sonnet 4.6, Haiku 4.5
- Show currently active model with visual indicator
- Update settings.local.json on selection
- Notify user that restart is required
- Change default model to `opus`

**Non-Goals**:
- Full Telescope picker (overkill for 3 options)
- Auto-restart Claude Code
- Support for custom model aliases (e.g., opusplan)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON parsing errors | M | L | Use pcall with error handling and user notification |
| File permissions | M | L | Check file accessibility before write |
| Invalid model value | H | L | Hardcode valid options in picker |
| Settings file missing | M | L | Create minimal JSON structure if not exists |

## Implementation Phases

### Phase 1: Update Default Model [COMPLETED]

**Goal**: Change default model from `sonnet` to `opus` in settings.local.json

**Tasks**:
- [ ] Read current settings.local.json
- [ ] Change `"model": "sonnet"` to `"model": "opus"`
- [ ] Write updated file
- [ ] Verify change was applied

**Timing**: 10 minutes

**Files to modify**:
- `~/.config/.claude/settings.local.json` - Update model field

**Verification**:
- Read file and confirm `"model": "opus"` is present

---

### Phase 2: Add Model Picker Keymap [COMPLETED]

**Goal**: Implement `<leader>am` keymap with vim.ui.select picker

**Tasks**:
- [ ] Add keymap entry after yolo mode toggle (line 364)
- [ ] Define model options array with id, label, desc
- [ ] Read current model from settings.local.json
- [ ] Implement vim.ui.select with format_item showing current marker
- [ ] On selection: read JSON, update model field, write JSON
- [ ] Notify user with model name and restart requirement

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Add `<leader>am` keymap function

**Implementation Details**:

```lua
-- Model picker - select Claude Code model
{ "<leader>am", function()
  local config_path = vim.fn.expand("~/.config/.claude/settings.local.json")

  -- Model definitions (Opus first per task description)
  local models = {
    { id = "opus", label = "Opus 4.6", desc = "Most powerful - complex reasoning" },
    { id = "sonnet", label = "Sonnet 4.6", desc = "Balanced - everyday coding" },
    { id = "haiku", label = "Haiku 4.5", desc = "Fastest - quick tasks" },
  }

  -- Read current settings
  local current_model = "sonnet"  -- default fallback
  local file = io.open(config_path, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local ok, settings = pcall(vim.fn.json_decode, content)
    if ok and settings and settings.model then
      current_model = settings.model
    end
  end

  -- Show picker
  vim.ui.select(models, {
    prompt = "Select Claude model:",
    format_item = function(item)
      local marker = (item.id == current_model) and " [*]" or ""
      return string.format("%s - %s%s", item.label, item.desc, marker)
    end,
  }, function(choice)
    if not choice then return end

    -- Read current settings (re-read for freshness)
    local settings = {}
    local read_file = io.open(config_path, "r")
    if read_file then
      local content = read_file:read("*all")
      read_file:close()
      local ok, data = pcall(vim.fn.json_decode, content)
      if ok and data then settings = data end
    end

    settings.model = choice.id

    local write_ok, write_err = pcall(function()
      local write_file = io.open(config_path, "w")
      if not write_file then error("Cannot open file for writing") end
      write_file:write(vim.fn.json_encode(settings))
      write_file:close()
    end)

    if not write_ok then
      notify.editor("Failed to write settings: " .. tostring(write_err), notify.categories.ERROR)
      return
    end

    notify.editor(
      string.format("Model set to %s (restart required)", choice.label),
      notify.categories.USER_ACTION,
      { model = choice.id }
    )
  end)
end, desc = "model (claude)", icon = "󰘦" },
```

**Verification**:
- Open Neovim and press `<leader>am`
- Picker should show 3 models with current model marked
- Select different model, verify settings.local.json updated
- Notification appears with restart message

---

### Phase 3: Final Verification [COMPLETED]

**Goal**: End-to-end testing of the implementation

**Tasks**:
- [ ] Restart Neovim to load changes
- [ ] Verify `<leader>a` group shows `m` for "model (claude)"
- [ ] Test picker opens with `<leader>am`
- [ ] Test current model indicator shows correctly
- [ ] Test model selection updates JSON file
- [ ] Test notification appears on selection
- [ ] Test cancellation (ESC) does not modify file

**Timing**: 15 minutes

**Verification**:
- All interactions work as expected
- No Lua errors in `:messages`
- JSON file maintains valid structure after modifications

---

## Testing & Validation

- [ ] Keymap `<leader>am` appears in which-key menu under AI group
- [ ] Picker displays three models in correct order (Opus, Sonnet, Haiku)
- [ ] Current model shows `[*]` marker
- [ ] Selecting model updates `~/.config/.claude/settings.local.json`
- [ ] Notification displays selected model name and restart requirement
- [ ] Cancelling picker does not modify settings
- [ ] Default model is now `opus` in settings.local.json

## Artifacts & Outputs

- `lua/neotex/plugins/editor/which-key.lua` - Modified with new keymap
- `~/.config/.claude/settings.local.json` - Updated default model
- `specs/242_add_leader_am_model_picker_for_claude_code/plans/01_model-picker-plan.md` - This plan
- `specs/242_add_leader_am_model_picker_for_claude_code/summaries/01_model-picker-summary.md` - Execution summary (after completion)

## Rollback/Contingency

- Revert which-key.lua changes via git
- Manually edit settings.local.json to restore `"model": "sonnet"` if needed
- All changes are localized to two files with no external dependencies
