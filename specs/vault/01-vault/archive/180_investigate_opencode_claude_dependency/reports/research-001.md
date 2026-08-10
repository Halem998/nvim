# Investigation Report: .opencode/ Dependency on .claude/ MCP Server Settings

**Task**: 180 - Investigate .opencode/ dependency on .claude/ MCP server settings  
**Date**: 2026-03-11  
**Status**: Investigation Complete  
**Related**: Task 179 (data directory loading bug), Task 178 (MCP port configuration)

---

## Problem Summary

When loading the opencode system in the Website repository (`/home/benjamin/Projects/Logos/Website/`) using `<leader>ao` to activate the memory extension, the system fails with:

```
Configuration is invalid at /home/benjamin/Projects/Logos/Website/opencode.json: 
bad file reference: "{file:.opencode/agents/web-research.md}" 
/home/benjamin/Projects/Logos/Website/.opencode/agents/web-research.md does not exist
```

## Investigation Steps

### 1. Examined the Website Repository Structure

The Website repo has:
- `opencode.json` - Configuration with agent definitions
- Empty `.opencode/agents/` directory - No agent files present
- References to agents using `{file:...}` syntax

### 2. Examined the Memory Extension

Location: `/home/benjamin/.config/nvim/.opencode/extensions/memory/`

**What it provides** (from `manifest.json`):
```json
"provides": {
  "commands": ["learn.md"],
  "skills": ["skill-memory"],
  "context": ["project/memory"],
  "data": ["memory"],
  "hooks": []
}
```

**What it does NOT provide**:
- `agents/` directory - Does not exist
- No agent files like `web-research.md`, `neovim-research.md`, etc.

### 3. Analyzed the Extension Loader Mechanism

File: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The loader copies files based on the `provides` section in the manifest:
- `copy_simple_files()` - Copies agents, commands, rules
- `copy_skill_dirs()` - Copies skills recursively
- `copy_context_dirs()` - Copies context preserving structure
- `copy_data_dirs()` - Copies data with merge-copy semantics

**Key finding**: The memory extension manifest has NO `agents` in its `provides`, so no agents are copied.

### 4. What the Website Repo Expects

From `Website/opencode.json`:
- `web-research` agent → expects `.opencode/agents/web-research.md`
- `neovim-research` agent → expects `.opencode/agents/neovim-research.md`
- `general-research` agent → expects `.opencode/agents/general-research.md`
- `task-planner` agent → expects `.opencode/agents/task-planner.md`
- `web-implementation` agent → expects `.opencode/agents/web-implementation.md`
- `neovim-implementation` agent → expects `.opencode/agents/neovim-implementation.md`
- `general-implementation` agent → expects `.opencode/agents/general-implementation.md`
- `meta-builder` agent → expects `.opencode/agents/meta-builder.md`
- `document-converter` agent → expects `.opencode/agents/document-converter.md`
- `code-reviewer` agent - defined inline (no file reference)

None of these agent files exist in the Website repo's `.opencode/agents/` directory.

### 5. Examined the nvim Config Structure

The nvim config (`~/.config/nvim/.opencode/`) has:
- `agent/subagents/` - Contains agents like `general-research-agent.md`, `planner-agent.md`, etc.
- `commands/` - Various command definitions
- `skills/` - Various skill definitions

**Note**: The agents are in `agent/subagents/` (OpenCode convention), not `agents/`.

## Root Cause (UPDATED)

**Original analysis was incorrect.** The agents DO exist - the paths in `opencode.json` are wrong.

### The Problem

The `opencode.json` references paths like:
```
{file:.opencode/agents/web-research.md}
```

But agents are actually installed to:
```
.opencode/agent/subagents/web-research-agent.md
```

**Two discrepancies:**
1. **Directory path**: `agents/` vs `agent/subagents/`
2. **Filename**: `web-research.md` vs `web-research-agent.md` (missing `-agent` suffix)

### What's Actually Installed

The Website repo has these agents installed via extensions:
- `web-research-agent.md` (from web extension)
- `web-implementation-agent.md` (from web extension)
- `general-research-agent.md` (core)
- `general-implementation-agent.md` (core)
- `planner-agent.md` (core)
- `meta-builder-agent.md` (core)
- `code-reviewer-agent.md` (core)

The `web` extension IS loaded (per `extensions.json`) and agents ARE present in `.opencode/agent/subagents/`.

### Why Original Analysis Was Wrong

The original research concluded:
> "No extension currently exists that provides the agents the Website repo expects"

This was incorrect because:
1. Multiple extensions DO provide agents (web, nvim, etc.)
2. The `web` extension IS loaded in Website repo
3. The agents ARE installed to the correct OpenCode location
4. The `opencode.json` simply has the **wrong file paths**

## Attempted Solution (Incorrect)

Initially attempted to add `web-research.md` to the memory extension, but this was **incorrect** because:
- Web research has nothing to do with memory functionality
- The memory extension should remain focused on its core purpose
- Adding unrelated agents would bloat the extension

**This change was reverted.**

## Findings

### What Exists in the Memory Extension

**Commands**:
- `learn.md` - Command for memory creation and management

**Skills**:
- `skill-memory/` - Skill for memory operations

**Context**:
- `project/memory/memory-setup.md`
- `project/memory/memory-troubleshooting.md`
- `project/memory/learn-usage.md`
- `project/memory/knowledge-capture-usage.md`
- `project/memory/README.md`

**Data** (vault skeleton):
- `memory/00-Inbox/`
- `memory/10-Memories/`
- `memory/20-Indices/`
- `memory/30-Templates/`

### What the Website Repo Needs But Doesn't Have

All agent files referenced in `opencode.json`:
- `.opencode/agents/web-research.md`
- `.opencode/agents/neovim-research.md`
- `.opencode/agents/general-research.md`
- `.opencode/agents/task-planner.md`
- `.opencode/agents/web-implementation.md`
- `.opencode/agents/neovim-implementation.md`
- `.opencode/agents/general-implementation.md`
- `.opencode/agents/meta-builder.md`
- `.opencode/agents/document-converter.md`

## Resolution (SIMPLIFIED)

### Fix opencode.json Paths

The fix is straightforward - update `Website/opencode.json` to use correct paths:

| Current (Broken) | Correct Path |
|------------------|--------------|
| `.opencode/agents/web-research.md` | `.opencode/agent/subagents/web-research-agent.md` |
| `.opencode/agents/web-implementation.md` | `.opencode/agent/subagents/web-implementation-agent.md` |
| `.opencode/agents/neovim-research.md` | `.opencode/agent/subagents/neovim-research-agent.md` |
| `.opencode/agents/neovim-implementation.md` | `.opencode/agent/subagents/neovim-implementation-agent.md` |
| `.opencode/agents/general-research.md` | `.opencode/agent/subagents/general-research-agent.md` |
| `.opencode/agents/general-implementation.md` | `.opencode/agent/subagents/general-implementation-agent.md` |
| `.opencode/agents/task-planner.md` | `.opencode/agent/subagents/planner-agent.md` |
| `.opencode/agents/meta-builder.md` | `.opencode/agent/subagents/meta-builder-agent.md` |
| `.opencode/agents/document-converter.md` | (needs filetypes extension loaded) |

### Additional Extension Needed

For `neovim-research-agent.md` and `neovim-implementation-agent.md`, the **nvim extension** must be loaded. Currently only `web` and `memory` extensions are active.

### For document-converter

The `filetypes` extension provides `document-agent.md`. Either:
- Load the filetypes extension
- Or change the reference to use the filetypes agent path

## Recommendations

1. **Immediate fix**: Update all path references in `Website/opencode.json` to use `.opencode/agent/subagents/` and add `-agent` suffix to filenames.

2. **Load nvim extension**: If neovim development is needed, load the nvim extension via `<leader>ao`.

3. **Load filetypes extension**: If document conversion is needed, load the filetypes extension.

4. **No new extensions needed**: The architecture is correct - extensions provide agents, they just need to be loaded and referenced correctly.

## Related Issues

- **Task 179**: Memory extension data directory loading bug (data goes to wrong location)
- **Task 178**: MCP port configuration fix (port 3000 vs 27124)

## Files Examined

1. `/home/benjamin/Projects/Logos/Website/opencode.json` - Website repo configuration
2. `/home/benjamin/.config/nvim/.opencode/extensions/memory/manifest.json` - Memory extension manifest
3. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` - Extension loader
4. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua` - Extension configuration
5. `/home/benjamin/.config/nvim/.opencode/agent/subagents/` - Core agents in nvim config

## Conclusion (CORRECTED)

The issue is **NOT** an architectural mismatch - it's a simple **path configuration error** in `opencode.json`.

**What's working correctly:**
- Extension system loads agents to correct location (`.opencode/agent/subagents/`)
- Web extension provides web-research-agent and web-implementation-agent
- Core agents (general-research, planner, meta-builder) are installed

**What's broken:**
- `opencode.json` references wrong directory (`agents/` vs `agent/subagents/`)
- `opencode.json` uses wrong filenames (missing `-agent` suffix)

**Fix Required:**
1. Update path references in `Website/opencode.json`
2. Load additional extensions if needed (nvim, filetypes)

The memory extension IS working as designed. The error message about missing agents is due to incorrect path references, not missing functionality.

---

**Next Steps**:
1. Fix paths in `Website/opencode.json` (10 minutes)
2. Optionally load nvim/filetypes extensions for full agent coverage
