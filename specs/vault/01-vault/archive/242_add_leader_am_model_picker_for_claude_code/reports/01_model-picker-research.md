# Research Report: Task #242

**Task**: 242 - add_leader_am_model_picker_for_claude_code
**Started**: 2026-03-19T00:00:00Z
**Completed**: 2026-03-19T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, Claude Code documentation
**Artifacts**: specs/242_add_leader_am_model_picker_for_claude_code/reports/01_model-picker-research.md
**Standards**: report-format.md

## Executive Summary

- The `<leader>ay` yolo mode toggle pattern in which-key.lua provides an excellent template for file modification
- `vim.ui.select` with `format_item` is the established pattern for simple pickers in the codebase
- Claude Code models use short aliases: `opus`, `sonnet`, `haiku` (not full model IDs)
- Current settings.local.json has `"model": "sonnet"`, should default to `"opus"`
- Restart is required after model change (consistent with yolo mode toggle behavior)

## Context & Scope

Research focused on implementing a `<leader>am` keymap to open a model picker for Claude Code. The picker should:
1. Display three Anthropic models (Opus first, then Sonnet, then Haiku)
2. Update `~/.config/.claude/settings.local.json` with the selected model
3. Notify user that restart is required
4. Show currently active model visually
5. Follow existing patterns from `<leader>ay` yolo mode toggle

## Findings

### 1. Existing `<leader>ay` Yolo Mode Toggle Pattern

Location: `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` (lines 308-364)

**Key Pattern Elements**:
```lua
{ "<leader>ay", function()
  local config_path = vim.fn.expand("~/.config/nvim/lua/neotex/plugins/ai/claudecode.lua")

  -- 1. Check file exists
  if vim.fn.filereadable(config_path) ~= 1 then
    notify.editor("Claude Code config not found", notify.categories.ERROR, { config_path = config_path })
    return
  end

  -- 2. Read file as lines
  local lines = vim.fn.readfile(config_path)
  local modified = false
  local yolo_enabled = false

  -- 3. Find and modify target line
  for i, line in ipairs(lines) do
    if line:match('%s*command = "claude') then
      -- Toggle logic here
      modified = true
      break
    end
  end

  -- 4. Handle not found case
  if not modified then
    notify.editor("Could not find command line in config", notify.categories.ERROR, ...)
    return
  end

  -- 5. Write file with pcall error handling
  local write_ok = pcall(vim.fn.writefile, lines, config_path)
  if not write_ok then
    notify.editor("Failed to write config file", notify.categories.ERROR, ...)
    return
  end

  -- 6. Notify user with restart requirement
  notify.editor(
    yolo_enabled and "Yolo mode enabled (restart required)" or "Yolo mode disabled (restart required)",
    notify.categories.USER_ACTION,
    { config_path = config_path, yolo_enabled = yolo_enabled }
  )
end, desc = "toggle yolo mode", icon = "..." },
```

**Adaptation for Model Picker**:
- Use JSON parsing instead of line-by-line text manipulation
- Target file: `~/.config/.claude/settings.local.json`
- Replace `vim.fn.readfile/writefile` with JSON-aware read/write

### 2. vim.ui.select Pattern Analysis

**Found Examples**:

**Simple picker with format_item** (`lua/neotex/util/buffer.lua:188`):
```lua
vim.ui.select({"Yes", "No"}, {
  prompt = prompt,
  kind = "file_deletion",
  format_item = function(item)
    if item == "Yes" then
      return " " .. item  -- Check mark
    else
      return " " .. item  -- X mark
    end
  end,
}, function(choice)
  if choice ~= "Yes" then
    return
  end
  -- Action logic
end)
```

**Worktree type picker** (`lua/neotex/plugins/ai/claude/core/worktree.lua:257`):
```lua
vim.ui.select(M.config.types, {
  prompt = "Select type:",
  format_item = function(item)
    return item:sub(1,1):upper() .. item:sub(2)
  end,
}, function(type)
  if not type then
    vim.notify("Cancelled", vim.log.levels.WARN)
    return
  end
  -- Continue with selection
end)
```

**Recommended Pattern for Model Picker**:
```lua
-- Model definitions with display labels
local models = {
  { id = "opus", label = "Opus 4.6", desc = "Most powerful - complex reasoning" },
  { id = "sonnet", label = "Sonnet 4.6", desc = "Balanced - everyday coding" },
  { id = "haiku", label = "Haiku 4.5", desc = "Fastest - quick tasks" },
}

vim.ui.select(models, {
  prompt = "Select Claude model:",
  format_item = function(item)
    local current_marker = (item.id == current_model) and " [*]" or ""
    return string.format("%s - %s%s", item.label, item.desc, current_marker)
  end,
}, function(choice)
  if not choice then return end
  -- Update settings.local.json with choice.id
end)
```

### 3. Claude Code Model Configuration

**Current settings.local.json** (`~/.config/.claude/settings.local.json`):
```json
{
  "model": "sonnet",
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["lean-lsp"],
  "_comment": "Personal project overrides - not committed to git",
  "permissions": {
    "allow": ["Bash(echo:*)"]
  }
}
```

**Valid Model Values** (short aliases):
- `opus` - Claude Opus 4.6 (most powerful)
- `sonnet` - Claude Sonnet 4.6 (balanced)
- `haiku` - Claude Haiku 4.5 (fastest)

**Special Aliases**:
- `opusplan` - Uses Opus for planning, Sonnet for execution (hybrid mode)

**Model Change Behavior**:
- Changes to `settings.local.json` require Claude Code restart to take effect
- The `/model` command within Claude Code can change models mid-session
- External settings file changes are only read at startup

**Recommended Default Change**:
- Current default: `"sonnet"`
- Recommended: `"opus"` (per task description)

### 4. Existing `<leader>a` Group Structure

**Current AI Group Keymaps** (which-key.lua lines 246-365):

| Keymap | Description | Icon |
|--------|-------------|------|
| `<leader>a` | ai (group) | ... |
| `<leader>ac` | claude commands / send selection | ... |
| `<leader>as` | claude sessions / opencode select | ... |
| `<leader>ab` | opencode buffer context | ... |
| `<leader>ad` | opencode diagnostics | ... |
| `<leader>ah` | opencode history | ... |
| `<leader>ao` | opencode commands | ... |
| `<leader>ay` | toggle yolo mode | ... |

**Keymap Entry Pattern**:
```lua
{ "<leader>am", function()
  -- Implementation
end, desc = "model (claude)", icon = "..." },
```

**Icon Recommendations** (from codebase patterns):
- `...` - Settings/configuration
- `...` - Model/brain
- `...` - Selection/choice

### 5. JSON File Modification Pattern

**Recommended Approach** (safer than line manipulation):
```lua
local function read_json_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  local ok, data = pcall(vim.fn.json_decode, content)
  return ok and data or nil
end

local function write_json_file(path, data)
  local content = vim.fn.json_encode(data)
  -- Pretty print with proper indentation
  content = content:gsub(",", ",\n  ")
  content = content:gsub("{", "{\n  ")
  content = content:gsub("}", "\n}")
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end
```

**Alternative**: Use `vim.json.encode` with options for pretty printing (Neovim 0.10+).

## Decisions

1. **Picker Type**: Use `vim.ui.select` (not Telescope) for simplicity with 3 options
2. **Model Values**: Use short aliases (`opus`, `sonnet`, `haiku`)
3. **Current Model Indicator**: Append `[*]` marker to currently active model
4. **Restart Notification**: Match yolo mode pattern with "(restart required)" message
5. **Default Model**: Change from `sonnet` to `opus` in settings.local.json
6. **Icon**: Use `...` (settings/gear) to match configuration theme

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| JSON parsing errors | Use pcall with error handling and user notification |
| File permissions | Check filereadable/filewritable before operations |
| Invalid model value | Hardcode valid options in picker, no free-text input |
| Settings file missing | Create minimal valid JSON structure if not exists |
| Concurrent modification | Read-modify-write is atomic enough for user-triggered actions |

## Implementation Recommendations

### 1. Add Model Picker Function

Insert after the yolo mode toggle (around line 365):

```lua
-- Model picker - select Claude Code model
{ "<leader>am", function()
  local config_path = vim.fn.expand("~/.config/.claude/settings.local.json")

  -- Model definitions
  local models = {
    { id = "opus", label = "Opus 4.6", desc = "Most powerful - complex reasoning" },
    { id = "sonnet", label = "Sonnet 4.6", desc = "Balanced - everyday coding" },
    { id = "haiku", label = "Haiku 4.5", desc = "Fastest - quick tasks" },
  }

  -- Read current settings
  local file = io.open(config_path, "r")
  local current_model = "sonnet"  -- default
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

    -- Read, modify, write settings
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
end, desc = "model (claude)", icon = "..." },
```

### 2. Update Default Model

In `~/.config/.claude/settings.local.json`, change:
```json
"model": "opus"
```

### 3. Add which-key Entry

Add within the `<leader>a` group block (after `<leader>ay`):
```lua
{ "<leader>am", function() ... end, desc = "model (claude)", icon = "..." },
```

## Appendix

### Search Queries Used
- `vim.ui.select` pattern search in codebase
- `format_item` usage patterns
- `<leader>ay` yolo mode implementation
- Claude Code settings.json documentation (web search)

### References
- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config)
- [Claude Code Settings Reference](https://code.claude.com/docs/en/settings)
- Codebase: `lua/neotex/plugins/editor/which-key.lua`
- Codebase: `lua/neotex/util/buffer.lua`
- Codebase: `lua/neotex/plugins/ai/claude/core/worktree.lua`

### Existing Files to Modify
1. `lua/neotex/plugins/editor/which-key.lua` - Add `<leader>am` keymap
2. `~/.config/.claude/settings.local.json` - Change default model to opus
