# Implementation Plan: Task #517

- **Task**: 517 - Fix MCP tools (lean-lsp) being unavailable when using opencode to implement Lean tasks
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/517_fix_opencode_mcp_tools_unavailable_lean/reports/01_opencode-mcp-tools.md
- **Artifacts**: plans/01_opencode-mcp-config.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: true

## Overview

The lean-lsp MCP server is configured for Claude Code but completely missing from opencode's configuration. OpenCode uses a different config format (`mcp` key in `opencode.json`) and different tool naming (`servername_toolname` instead of `mcp__servername__toolname`). This plan adds the lean-lsp MCP server to the global opencode config, enables MCP tools for lean agents, and updates any agent prompts that reference the wrong tool naming convention.

### Research Integration

Research identified four key issues: (1) no MCP servers in opencode config at all, (2) the lean extension's settings fragment targets Claude Code format only, (3) lean agents in per-project configs lack MCP tool enablement, and (4) agent prompts reference Claude Code tool names which do not exist in opencode. The fix spans the global opencode config, per-project agent configs, and agent prompt files.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly relate to this task. This is a bug fix for opencode MCP tool availability.

## Goals & Non-Goals

**Goals**:
- Make lean-lsp MCP server available when opencode runs on Lean projects
- Enable lean-lsp tools for opencode lean agents (implementation, research)
- Ensure agent prompts use the correct opencode tool naming convention

**Non-Goals**:
- Rewriting the extension system to natively support opencode MCP format (future work)
- Adding MCP servers beyond lean-lsp
- Modifying Claude Code's MCP configuration

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Global opencode config managed by Home Manager (symlinked) | M | M | Check if symlinked; edit Nix source if so |
| Tool naming differences cause silent failures in prompts | H | H | Audit all opencode lean agent files for tool name references |
| opencode.json schema changes between versions | L | L | Use documented format from official docs |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add lean-lsp MCP Server to Global OpenCode Config [COMPLETED]

**Goal**: Register the lean-lsp MCP server in the global opencode configuration so it is available to all projects.

**Tasks**:
- [ ] Read `~/.config/opencode/opencode.json` to get current content
- [ ] Check if the file is a symlink (Home Manager managed) and identify the source if so
- [ ] Add the `mcp` key with lean-lsp server definition using opencode format:
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
- [ ] Preserve any existing config keys when merging
- [ ] Validate JSON syntax after editing

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `~/.config/opencode/opencode.json` - Add `mcp.lean-lsp` server entry (or Nix source if symlinked)

**Verification**:
- `opencode mcp list` shows lean-lsp server
- JSON file parses without errors

---

### Phase 2: Enable MCP Tools for Lean Agents [COMPLETED]

**Goal**: Update per-project opencode agent configurations to include lean-lsp MCP tools in their allowed tool lists.

**Tasks**:
- [ ] Identify all per-project `opencode.json` files with lean agent definitions (e.g., `~/Projects/ProofChecker/opencode.json`)
- [ ] For each lean agent (lean-implementation, lean-research, etc.), add `"lean-lsp_*": true` to their `tools` object
- [ ] If agents use a different tool enablement mechanism, adapt accordingly
- [ ] Validate JSON syntax after each edit

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `~/Projects/ProofChecker/opencode.json` - Add `lean-lsp_*` tool enablement to lean agents
- Any other project-level opencode configs with lean agents (discover during implementation)

**Verification**:
- Agent configs parse as valid JSON
- Tool glob patterns match the opencode naming convention

---

### Phase 3: Update Agent Prompts for OpenCode Tool Naming [COMPLETED]

**Goal**: Ensure opencode lean agent prompts reference the correct tool names (opencode convention) rather than Claude Code convention.

**Tasks**:
- [ ] Search all files under `.opencode/` for references to `mcp__lean-lsp__` (Claude Code naming)
- [ ] Search opencode lean agent definitions and prompts for tool name references
- [ ] Replace `mcp__lean-lsp__lean_goal` style references with `lean-lsp_lean_goal` style (opencode convention)
- [ ] If prompts use generic references like "use the lean LSP tools", verify they do not hardcode tool names
- [ ] Check if opencode lean extension agent files need updating

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/agents/*.md` - Any lean-related agent prompts (discover during implementation)
- `.opencode/extensions/lean/agents/*.md` - Lean extension agent prompts
- `.opencode/settings.json` - Update `mcp__lean-lsp__*` permission patterns if needed

**Verification**:
- No remaining `mcp__lean-lsp__` references in opencode agent files
- Tool name references match opencode's `servername_toolname` convention

---

### Phase 4: End-to-End Verification [COMPLETED]

**Goal**: Confirm that lean-lsp MCP tools are accessible and functional when opencode runs on a Lean project.

**Tasks**:
- [ ] Run `opencode mcp list` and confirm lean-lsp appears
- [ ] Verify tool names exposed by lean-lsp match the naming used in agent configs
- [ ] If possible, run a lightweight opencode session targeting a Lean file to confirm tools are callable
- [ ] Document any remaining issues or follow-up items

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- None (verification only)

**Verification**:
- `opencode mcp list` shows lean-lsp with expected tools
- Lean agent can invoke lean-lsp tools without "unavailable tool" errors

## Testing & Validation

- [ ] `opencode mcp list` shows lean-lsp server registered
- [ ] JSON syntax valid in all modified config files
- [ ] No `mcp__lean-lsp__` references remain in opencode agent files
- [ ] Lean agents have `lean-lsp_*` in their tool enablement
- [ ] A test invocation of opencode on a Lean file does not produce "unavailable tool" errors

## Artifacts & Outputs

- Modified `~/.config/opencode/opencode.json` (or Nix source) with lean-lsp MCP server
- Modified per-project `opencode.json` files with lean agent tool enablement
- Updated opencode agent prompt files with correct tool naming

## Rollback/Contingency

All changes are to JSON config files and markdown agent prompts. Rollback by reverting the specific files via `git checkout` for repo-tracked files or restoring backups for global config. The global `opencode.json` should be backed up before modification (copy to `opencode.json.bak`).
