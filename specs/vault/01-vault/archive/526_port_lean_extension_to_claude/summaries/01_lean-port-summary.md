# Implementation Summary: Task #526

**Task**: 526 - Port lean extension to `.claude/` for parity
**Completed**: 2026-05-04
**Effort**: 1.5 hours
**Plan**: `specs/526_port_lean_extension_to_claude/plans/01_lean-port-plan.md`

## Summary

The `.claude/extensions/lean/` extension already existed and was more complete than `.opencode/extensions/lean/`. This task performed a parity audit and reconciliation, fixing one critical bug and backporting missing context files. All verification checks pass.

## Changes Made

### 1. Fixed Critical Path Bug in `.claude/extensions/lean/opencode-agents.json`

**Problem**: The `opencode-agents.json` file referenced `.opencode/agent/subagents/lean-research-agent.md` and `.opencode/agent/subagents/lean-implementation-agent.md` -- paths that do not exist in the Claude Code system.

**Fix**: Updated both prompt paths to point to the correct locations within the `.claude/` extension tree:
- `lean-research` agent: `{file:.claude/extensions/lean/agents/lean-research-agent.md}`
- `lean-implementation` agent: `{file:.claude/extensions/lean/agents/lean-implementation-agent.md}`

**Verification**: `jq empty` passes; grep for `.opencode/agent/subagents` returns 0 matches.

### 2. Backported Missing Context Files to `.opencode/`

**Problem**: `.claude/extensions/lean/` had two context files that `.opencode/extensions/lean/` lacked:
- `context/project/lean4/tools/blocked-mcp-tools.md` - Reference for blocked Lean MCP tools with alternatives
- `context/project/lean4/patterns/mcp-fallback-table.md` - Lean-specific MCP tool fallback strategies

**Fix**: Copied both files from `.claude/` to `.opencode/` and updated the absolute path reference in `mcp-fallback-table.md` from `.claude/` to `.opencode/`.

### 3. Updated `.opencode/extensions/lean/index-entries.json`

**Problem**: The index did not include entries for the two missing context files.

**Fix**: Added index entries for both files using the minimal `.opencode/` format (path, description, tags, load_when).

**Verification**: Entry count increased from 24 to 26, matching `.claude/`. JSON syntax valid.

## Verification Results

| Check | Result |
|-------|--------|
| `opencode-agents.json` JSON syntax | Valid |
| `index-entries.json` JSON syntax | Valid |
| No `.language` references in `.opencode/` skills | 0 matches |
| No `.language` references in `.claude/` skills | 0 matches |
| No `OC_` prefix references in `.opencode/` skills | 0 matches |
| No `OC_` prefix references in `.claude/` skills | 0 matches |
| `.claude/` manifest routing (`lean4`, `lean4:lake`, `lean4:version`) | Confirmed correct |
| `.opencode/` manifest routing (`lean`, `lean4`) | Confirmed correct |
| File tree cross-reference | Only expected difference is `opencode-agents.json` (Claude Code-specific) |

## File Tree Comparison

After reconciliation, the only difference between the two extension trees is:
- `.claude/extensions/lean/opencode-agents.json` -- This file is specific to the Claude Code merge target (`opencode_json`) and does not belong in `.opencode/`.

All other files are now present in both trees with appropriate path adaptations.

## Notes for Future Work

1. **Systematic `opencode-agents.json` audit**: The nvim extension has the same bug pattern (references `.opencode/agent/subagents/` paths). A future task should audit all `.claude/extensions/*/opencode-agents.json` files for this systematic issue.

2. **Skill structural improvements**: The `.claude/` lean skills have Claude Code-specific improvements (Stage 4b self-execution fallback, explicit Postflight headers, MUST NOT boundaries) that were intentionally not backported to `.opencode/` per this task's non-goals. If strict bidirectional parity is desired later, these could be ported.

3. **README disparity**: `.claude/extensions/lean/README.md` is 192 lines (comprehensive) while `.opencode/extensions/lean/README.md` is only 22 lines (barebones). This was intentionally not addressed per non-goals.

## Commit

```
task 526: fix lean extension parity
```

Files changed: 4 (1 modified in `.claude/`, 1 modified in `.opencode/`, 2 created in `.opencode/`)
