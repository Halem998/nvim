# Research Report: Task #130

**Task**: OC_130 - Make .opencode system self-contained
**Date**: 2026-03-04
**Language**: meta
**Focus**: Removal of .claude/ references from .opencode/

## Summary

The `.opencode` directory currently contains numerous references to `.claude/` artifacts, including deprecated format files, documentation links, and configuration pointers. To make `.opencode` self-contained, these references must be updated to point to internal `.opencode` resources, and any missing resources must be migrated. Key findings include the deprecated `plan-format.md`, the `claudemd_suggestions` metadata field, and various path references in documentation and agents.

## Findings

### 1. Deprecated Format Files
- **File**: `.opencode/context/core/formats/plan-format.md`
- **Issue**: Explicitly marked as deprecated and points to `.claude/context/core/formats/plan-format.md`.
- **Action**: Replace content with the active standard from `.claude/` and update internal references to use `.opencode/` paths.

### 2. Metadata Field Naming
- **Field**: `claudemd_suggestions`
- **Locations**: 
  - `.opencode/context/core/formats/return-metadata-file.md`
  - `.opencode/rules/state-management.md`
  - `.opencode/commands/todo.md`
  - `.opencode/agent/subagents/general-implementation-agent.md`
- **Issue**: The field name implies a dependency on `CLAUDE.md`. Since `OPENCODE.md` has been consolidated into `.opencode/README.md` (Task 127), and the system is becoming self-contained, this name is anachronistic.
- **Action**: Rename to `readme_suggestions` or `system_suggestions` to reflect the target (`README.md` or system config). Given the recent migration to `.opencode/README.md`, `readme_suggestions` is the most accurate.

### 3. Documentation & Agent References
Numerous files reference `.claude/` paths that should be updated to `.opencode/`:
- **Agents**: 
  - `planner-agent.md`, `creating-agents.md`: Reference `.claude/context/core/formats/plan-format.md`.
- **Documentation**:
  - `user-guide.md`: Links to `.claude/docs/guides/tts-stt-integration.md`.
  - `index.md`: References `.claude/context/core/formats/plan-format.md`.
- **Commands**:
  - `implement.md`, `research.md`: Mention `.claude/` files.
- **Hooks**:
  - `wezterm-integration.md`: References `.claude/hooks/`. The `.opencode/hooks/` directory does not exist and may need creation or the file should point to where hooks are actually stored.

### 4. External Configuration
- **File**: `~/.claude.json`
- **Locations**: `extensions/lean/scripts/`
- **Issue**: Scripts modify `~/.claude.json` to register MCP servers.
- **Analysis**: This likely configures the underlying CLI tool (Claude Code). Unless OpenCode has replaced the CLI binary or uses a distinct configuration file (`~/.opencode.json`), this reference might need to remain as an external dependency configuration.
- **Action**: Keep `~/.claude.json` references for now unless a specific OpenCode config file is identified.

### 5. Cleanup Scripts
- **File**: `scripts/install-systemd-timer.sh`
- **Status**: Already handles migration from `claude-cleanup` to `opencode-refresh`. No action needed.

## Recommendations

1.  **Migrate Plan Format**: Overwrite `.opencode/context/core/formats/plan-format.md` with the content from `.claude/.../plan-format.md` and update its internal path references.
2.  **Rename Metadata Field**: Rename `claudemd_suggestions` to `readme_suggestions` across all definitions, agents, and consumers (`/todo` command).
3.  **Update Path References**: Systematically replace `@.claude/` and `.claude/` path references with `.opencode/` equivalents in all documentation and agent files.
4.  **Handle Hooks**: Create `.opencode/hooks/` if needed or determine the correct location for hooks and update `wezterm-integration.md`.
5.  **Leave Tool Config**: Retain `~/.claude.json` references for MCP configuration until a distinct OpenCode configuration mechanism is established.

## Risks & Considerations

- **Tool Compatibility**: If the underlying agent runtime strictly expects `.claude` paths for certain context loading (unlikely if we are editing `.opencode` agents), breakage could occur.
- **Migration Completeness**: Missing a `claudemd_suggestions` reference could break the `/todo` command's ability to suggest system updates. Grep must be thorough.

## Next Steps

Run `/plan OC_130` to create an implementation plan for these updates.
