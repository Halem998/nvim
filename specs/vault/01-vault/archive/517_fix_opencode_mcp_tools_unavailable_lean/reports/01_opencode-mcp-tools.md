# Research Report: Task #517

**Task**: 517 - Fix MCP tools (lean-lsp) being unavailable when using opencode to implement Lean tasks
**Started**: 2026-05-02T21:30:00Z
**Completed**: 2026-05-02T21:45:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration (opencode and claude extension systems)
- OpenCode official documentation (https://opencode.ai/docs/mcp-servers/, https://opencode.ai/docs/config/, https://opencode.ai/docs/tools/)
- Extension manifests and settings fragments
**Artifacts**:
- specs/517_fix_opencode_mcp_tools_unavailable_lean/reports/01_opencode-mcp-tools.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The lean-lsp MCP server is not configured in opencode at all. Opencode uses a different MCP configuration format (`mcp` key in `opencode.json`) than Claude Code (`mcpServers` in settings files).
- The lean extension exists for opencode (`.opencode/extensions/lean/`) but has never been loaded -- only `core` is loaded in `.opencode/extensions.json`.
- Even if the lean extension were loaded, its `settings-fragment.json` uses Claude Code's `mcpServers` format, which would merge into `.opencode/settings.local.json` -- a Claude Code settings file, not an opencode config file.
- The fix requires two changes: (1) add the lean-lsp MCP server to the global or per-project `opencode.json`, and (2) enable the MCP tools for the lean agents in the agent configuration.
- The agent prompts reference Claude Code tool names (`mcp__lean-lsp__lean_goal`) but opencode uses a different naming convention (`lean-lsp_lean_goal` or similar prefix pattern).

## Context & Scope

The user runs opencode (an alternative AI coding CLI) via a Neovim integration plugin. When opencode attempts to implement Lean 4 tasks, the model tries to call MCP tools like `mcp__lean-lsp__lean_goal` but gets an error because only built-in tools are available. The root cause is that MCP servers are not configured in opencode's config system.

### Key Differences: Claude Code vs OpenCode MCP Configuration

| Aspect | Claude Code | OpenCode |
|--------|-------------|----------|
| Config file | `.claude/settings.local.json`, `~/.claude/settings.json` | `opencode.json` (project root or `~/.config/opencode/opencode.json`) |
| MCP key | `"mcpServers"` | `"mcp"` |
| Server format | `{ "command": "npx", "args": [...] }` | `{ "type": "local", "command": ["npx", ...] }` |
| Tool naming | `mcp__servername__toolname` | `servername_toolname` (with glob patterns like `servername_*`) |
| Tool enablement | `permissions.allow` in settings | `"tools"` object in agent config or top-level |

## Findings

### 1. OpenCode Has No MCP Servers Configured

Running `opencode mcp list` confirms zero MCP servers. The global config at `~/.config/opencode/opencode.json` has no `mcp` key. There is no per-project `opencode.json` or `opencode.jsonc` at the nvim config root.

### 2. Lean Extension Not Loaded for OpenCode

The `.opencode/extensions.json` shows only `core` is loaded. The lean extension exists at `.opencode/extensions/lean/` with a proper manifest and settings fragment, but it was never activated via the extension picker.

### 3. Extension Settings Fragment Targets Wrong Format

The lean extension's `settings-fragment.json` at `.opencode/extensions/lean/settings-fragment.json` contains Claude Code format:
```json
{
  "mcpServers": {
    "lean-lsp": {
      "command": "npx",
      "args": ["-y", "lean-lsp-mcp@latest"]
    }
  },
  "permissions": { "allow": ["mcp__lean-lsp__*", ...] }
}
```

This gets merged into `.opencode/settings.local.json` (a Claude Code-compatible settings file). However, opencode does not read this file. Opencode reads its own `opencode.json` config format.

### 4. OpenCode MCP Configuration Format

Per official docs, opencode expects MCP servers under the `mcp` key:
```json
{
  "mcp": {
    "lean-lsp": {
      "type": "local",
      "command": ["npx", "-y", "lean-lsp-mcp@latest"],
      "environment": {
        "LEAN_LOG_LEVEL": "WARNING"
      }
    }
  }
}
```

Tool enablement for agents uses:
```json
{
  "agent": {
    "lean-implementation": {
      "tools": {
        "lean-lsp_*": true
      }
    }
  }
}
```

### 5. Tool Naming Mismatch in Agent Prompts

The opencode lean agents (and any system prompts referencing lean MCP tools) likely use Claude Code's `mcp__lean-lsp__lean_goal` naming. Opencode names MCP tools as `lean-lsp_lean_goal` (server name + underscore + tool name). Agent prompts that reference the Claude Code naming convention will cause the model to attempt calling non-existent tools.

### 6. Two Potential Config Locations

- **Global**: `~/.config/opencode/opencode.json` -- affects all projects
- **Per-project**: `opencode.json` at project root -- only affects that project

For the nvim config repo (which manages extensions), the global config is more appropriate since lean-lsp should be available whenever opencode runs on Lean projects.

### 7. Existing Setup Scripts Target Claude Code Only

The `setup-lean-mcp.sh` and `verify-lean-mcp.sh` scripts in `.opencode/scripts/` both target `~/.claude.json` (Claude Code user config), not opencode's config. They would need opencode-specific counterparts or modifications.

## Decisions

- The fix should add lean-lsp to the global `~/.config/opencode/opencode.json` config since the user works on Lean projects from different directories.
- Agent definitions in the per-project `opencode.json` files (like ProofChecker's) need their tool lists updated to include the lean-lsp MCP tools.
- The opencode lean extension's settings fragment format may need updating to include an opencode-native config section, but this is a separate concern from the immediate fix.

## Recommendations

### Priority 1: Add lean-lsp to opencode global config

Add to `~/.config/opencode/opencode.json`:
```json
{
  "mcp": {
    "lean-lsp": {
      "type": "local",
      "command": ["npx", "-y", "lean-lsp-mcp@latest"],
      "environment": {
        "LEAN_LOG_LEVEL": "WARNING"
      }
    }
  }
}
```

### Priority 2: Enable MCP tools for lean agents

In the per-project `opencode.json` (e.g., `~/Projects/ProofChecker/opencode.json`), update lean agents to include MCP tools:
```json
{
  "agent": {
    "lean-implementation": {
      "tools": {
        "lean-lsp_*": true
      }
    },
    "lean-research": {
      "tools": {
        "lean-lsp_*": true
      }
    }
  }
}
```

### Priority 3: Update agent prompts for tool naming

Agent prompt files that reference `mcp__lean-lsp__lean_goal` (Claude Code convention) need updating to use `lean-lsp_lean_goal` or just the tool names that opencode exposes. This may require auditing the opencode lean agent definitions.

### Priority 4 (optional): Update extension system for opencode MCP

Consider adding an opencode-specific merge target in the lean extension manifest that generates the correct `mcp` config format for `opencode.json`, separate from the Claude Code `mcpServers` format in `settings-fragment.json`.

## Risks & Mitigations

- **Tool naming divergence**: Agent prompts referencing Claude Code tool names will silently fail in opencode. Mitigation: audit all lean agent prompts for tool name references.
- **Global config managed by Home Manager**: The `~/.config/opencode/opencode.json` may be managed by Home Manager (like `~/.claude/settings.json`). Mitigation: check if it's symlinked and edit the source if so.
- **Extension loader gap**: The current extension system merges settings fragments into Claude Code format only. Adding opencode-native MCP config support requires extension system changes. Mitigation: for now, manually add MCP config to `opencode.json`.

## Appendix

### Files Examined
- `~/.config/opencode/opencode.json` -- Global opencode config (no MCP)
- `~/.config/nvim/.opencode/settings.json` -- Opencode permissions (has `mcp__lean-lsp__*` allow rules but no server definitions)
- `~/.config/nvim/.opencode/extensions.json` -- Only `core` loaded
- `~/.config/nvim/.opencode/extensions/lean/manifest.json` -- Lean extension with MCP server declaration
- `~/.config/nvim/.opencode/extensions/lean/settings-fragment.json` -- Claude Code format MCP config
- `~/.config/nvim/.claude/settings.local.json` -- Claude Code settings with `enabledMcpjsonServers: ["lean-lsp"]`
- `~/Projects/ProofChecker/opencode.json` -- Per-project agent config (no MCP tools in agents)
- `~/Projects/ProofChecker.bak/.mcp.json` -- Claude Code project MCP config (lean-lsp defined)
- `~/.config/nvim/.opencode/scripts/setup-lean-mcp.sh` -- Targets Claude Code only

### Web Sources
- https://opencode.ai/docs/mcp-servers/ -- OpenCode MCP server documentation
- https://opencode.ai/docs/config/ -- OpenCode configuration reference
- https://opencode.ai/docs/tools/ -- OpenCode tools documentation
