# Shared AI Infrastructure

This directory contains shared infrastructure modules that power both Claude and OpenCode pickers.

## Directory Structure

```
shared/
├── extensions/              # Shared extension management system
│   ├── config.lua          # Extension system configuration (claude/opencode presets)
│   ├── init.lua            # Extension manager factory
│   ├── loader.lua          # File copy/remove operations
│   ├── manifest.lua        # Manifest parsing and discovery
│   ├── merge.lua           # Config file merge operations
│   └── state.lua           # Extension state tracking
└── picker/                 # Unified AI tool picker
    ├── ai-tool-picker.lua  # Two-stage picker with smart toggle and cycle logic
    ├── config.lua          # Picker configuration presets
    └── config_spec.lua     # Tests for picker config
```

## Unified AI Tool Picker (`ai-tool-picker.lua`)

The central coordination module for all AI tool interactions. Provides a two-stage picker, a smart toggle with cycle logic, and centralized active-tool state tracking.

### Entry Points

| Function | Description |
|----------|-------------|
| `M.smart_toggle()` | `<C-CR>` handler — toggle, cycle, or open picker depending on what is running |
| `M.show_tool_picker()` | `<leader>ac` handler — Stage 1 picker: choose ClaudeCode or OpenCode |
| `M.show_commands_picker()` | `<leader>al` handler — pick tool then load its commands/agents |
| `M.show_claude_session_picker()` | Stage 2 for Claude: new / restore / browse sessions |
| `M.show_opencode_session_picker()` | Stage 2 for OpenCode: new / restore / browse sessions |

### Smart Toggle Behavior (`<C-CR>`)

| State | Action |
|-------|--------|
| Neither running | Open Stage 1 picker |
| Only Claude running | Toggle Claude window (show/hide) |
| Only OpenCode running | Toggle OpenCode window (show/hide) |
| Both running — only OpenCode visible | Switch to only Claude |
| Both running — only Claude visible | Hide Claude (→ neither) |
| Both running — neither visible | Show only OpenCode (restart cycle) |
| Both running — both visible | Show only OpenCode (enter cycle) |

When both tools are open, repeated `<C-CR>` presses cycle: **just OpenCode → just Claude → neither → just OpenCode → …**

### Tool Picker Behavior (`<leader>ac`)

Opening a new tool via `<leader>ac` when another is already visible will first hide the visible tool before opening the newly selected one, so only one agent window is shown at a time.

### Active Tool State

`M._active_tool` (`"claude" | "opencode" | nil`) and `M._active_tool_bufnr` track the most recently launched tool. State is cleared automatically via `TermClose`/`BufWipeout` autocmds registered by `_register_tool_cleanup()`.

---

## Shared Picker Architecture

The `config.lua` module is parameterized to support both `.claude/` and `.opencode/` directory structures.

### Configuration Presets

```lua
local config = require("neotex.plugins.ai.shared.picker.config")

-- Claude configuration
local claude_config = config.claude()

-- OpenCode configuration
local opencode_config = config.opencode()
```

### Key Differences

| Aspect | Claude | OpenCode |
|--------|--------|----------|
| Base directory | `.claude` | `.opencode` |
| Agents location | `agents/` | `agent/subagents/` |
| Settings file | `settings.local.json` | `settings.json` |
| Config file | `CLAUDE.md` | `OPENCODE.md` |
| Hooks | Supported | Not used |

## Shared Extensions System

The extension system allows domain-specific capabilities (lean, latex, typst, etc.) to be loaded on-demand.

### Using Extensions

```lua
-- Claude extensions
local claude_ext = require("neotex.plugins.ai.claude.extensions")
claude_ext.load("lean", { confirm = true })

-- OpenCode extensions
local opencode_ext = require("neotex.plugins.ai.opencode.extensions")
opencode_ext.load("lean", { confirm = true })
```

### Extension Locations

- Claude: `~/.config/nvim/agent-system/extensions/`
- OpenCode: `~/.config/nvim/.opencode/extensions/`

## Keymaps

| Keymap | Mode | Description |
|--------|------|-------------|
| `<C-CR>` | n/i/v/t | Smart toggle: picker if nothing open, toggle if one open, cycle if both open |
| `<leader>ac` | Normal | AI agent picker (Stage 1: choose ClaudeCode or OpenCode) |
| `<leader>al` | Normal/Visual | Load AI commands/agents picker |

**Note**: Extension pickers are available via commands (`:ClaudeExtensions`, `:OpencodeExtensions`) but no longer have dedicated keymaps.
