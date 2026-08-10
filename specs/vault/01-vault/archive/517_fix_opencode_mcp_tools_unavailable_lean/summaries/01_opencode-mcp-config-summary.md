# Implementation Summary: Fix OpenCode MCP Tools for Lean

- **Task**: 517 - Fix MCP tools (lean-lsp) being unavailable when using opencode to implement Lean tasks
- **Status**: [COMPLETED]
- **Started**: 2026-05-02T21:50:00Z
- **Completed**: 2026-05-03T04:30:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Artifacts**: [plans/01_opencode-mcp-config.md]
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The lean-lsp MCP server was configured for Claude Code but completely missing from OpenCode's configuration. OpenCode uses a different config format (`mcp` key in `opencode.json` with `command` as array) and a different tool naming convention (`servername_toolname` with single underscore) compared to Claude Code (`mcp__servername__toolname` with double underscores). This implementation added the MCP server to the global config, enabled tools for lean agents, and updated all agent prompts and permissions to use the correct naming.

## What Changed

- Added `lean-lsp` MCP server definition to global OpenCode config at `~/.dotfiles/config/opencode.json` (Home Manager managed, using `uvx lean-lsp-mcp` command)
- Rebuilt Home Manager to apply the symlinked config change
- Added `"lean-lsp_*": true` tool enablement to `lean-research` and `lean-implementation` agents in `~/Projects/ProofChecker/opencode.json`
- Updated all `mcp__lean-lsp__` references to `lean-lsp_` in OpenCode agent prompts (4 agent files, 2 command files, 1 settings file, 2 context files)
- Fixed the MCP server command from `npx -y lean-lsp-mcp@latest` (npm, package not found) to `uvx lean-lsp-mcp` (Python/uv, correct package manager)
- Preserved Claude Code format files (`settings.local.json`, `settings-fragment.json`, `extensions.json` merged_sections) with their original `mcp__lean-lsp__` naming since those target the Claude Code settings system

## Decisions

- Used global `~/.config/opencode/opencode.json` (via dotfiles) rather than per-project config, so lean-lsp is available across all Lean projects
- Left Claude Code format files (`.opencode/settings.local.json`, `.opencode/extensions/lean/settings-fragment.json`) unchanged since they use the correct naming for their target system
- Corrected the research report's assumption that the package is on npm; it is actually a Python package installed via `uvx`

## Impacts

- OpenCode can now access lean-lsp MCP tools when running on Lean projects (verified: `opencode mcp list` shows lean-lsp as connected)
- Lean agents (`lean-research`, `lean-implementation`) now have MCP tool access via `lean-lsp_*` glob pattern
- Agent prompts reference correct tool names (`lean-lsp_lean_goal` instead of `mcp__lean-lsp__lean_goal`)

## Follow-ups

- The opencode extension system's `settings-fragment.json` only generates Claude Code format; a future enhancement could add opencode-native MCP config generation
- The `lean-lsp` server startup may fail in non-Lean project directories (expected behavior, not a bug)
- Consider adding MCP server definitions to per-project `opencode.json` files for projects that need project-specific environment variables (like `LEAN_PROJECT_PATH`)

## References

- `specs/517_fix_opencode_mcp_tools_unavailable_lean/reports/01_opencode-mcp-tools.md`
- `specs/517_fix_opencode_mcp_tools_unavailable_lean/plans/01_opencode-mcp-config.md`
- OpenCode MCP docs: https://opencode.ai/docs/mcp-servers/
- OpenCode source (tool naming): `github.com/opencode-ai/opencode/internal/llm/agent/mcp-tools.go` -- `fmt.Sprintf("%s_%s", b.mcpName, b.tool.Name)`
