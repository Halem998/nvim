# Website Opencode Missing Agent Files - Research Report

**Task**: 181 - Fix Website opencode missing agent files
**Date**: 2026-03-10
**Status**: Research Complete
**Language**: meta

## Problem Summary

Opening opencode in `/home/benjamin/Projects/Logos/Website/` fails with:

```
Configuration is invalid at /home/benjamin/Projects/Logos/Website/opencode.json:
bad file reference: "{file:.opencode/agent/subagents/web-research-agent.md}"
/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/web-research-agent.md
does not exist
```

## Root Cause: Incomplete Agent Directory Refactoring

The Website project underwent a refactoring of its `.opencode/` agent structure that was **never completed**:

### Old Structure (deleted from git, staged for removal)
```
.opencode/agents/
├── build-prompt.txt
├── code-reviewer.md
├── document-converter.md
├── general-implementation.md
├── general-research.md
├── meta-builder.md
├── neovim-implementation.md
├── neovim-research.md
├── task-planner.md
├── web-implementation.md
├── web-research.md
└── website-orchestrator.md
```

### New Structure (partially created)
```
.opencode/agent/subagents/
├── code-reviewer-agent.md        [EXISTS]
├── general-implementation-agent.md  [EXISTS]
├── general-research-agent.md     [EXISTS]
├── meta-builder-agent.md         [EXISTS]
├── planner-agent.md              [EXISTS]
├── README.md                     [EXISTS]
├── web-research-agent.md         [MISSING - opencode.json references this]
├── web-implementation-agent.md   [MISSING - opencode.json references this]
├── neovim-research-agent.md      [MISSING - opencode.json references this]
├── neovim-implementation-agent.md [MISSING - opencode.json references this]
└── document-converter-agent.md   [MISSING - opencode.json references this]
```

### Changes Made During Refactoring
- Directory: `.opencode/agents/` → `.opencode/agent/subagents/`
- Naming: `web-research.md` → `web-research-agent.md` (added `-agent` suffix)
- `opencode.json` was updated with new `{file:...}` references for all agents
- **5 of the 11 agents were never created** in the new location

## opencode.json References That Fail

Five agents in `opencode.json` reference missing files:

| Agent Key | File Referenced |
|-----------|-----------------|
| `web-research` | `.opencode/agent/subagents/web-research-agent.md` |
| `web-implementation` | `.opencode/agent/subagents/web-implementation-agent.md` |
| `neovim-research` | `.opencode/agent/subagents/neovim-research-agent.md` |
| `neovim-implementation` | `.opencode/agent/subagents/neovim-implementation-agent.md` |
| `document-converter` | `.opencode/agent/subagents/document-converter-agent.md` |

Note: Opencode validates **all** `{file:...}` references at startup, so even if only
`web-research-agent.md` is reported first, all 5 missing files will cause failures.

## Agent Content Source

The old agent files are available via git history in the Website repo (staged for
deletion but not yet committed). However, the correct approach is to create new
agent files aligned with the current system architecture. The agents that DO exist
in the new location (`general-research-agent.md`, `general-implementation-agent.md`,
`meta-builder-agent.md`, `planner-agent.md`, `code-reviewer-agent.md`) were likely
synced from the neovim config's `.opencode/extensions/` or similar source.

## Relationship to Memory Extension

The memory extension loading is **not the cause** of this problem. The memory
extension correctly provides only:
- 1 command: `learn.md`
- 1 skill: `skill-memory`
- 4 context files
- Obsidian MCP server settings

The agent file gap predates the memory extension load. The refactoring left the
Website project in a broken state independently of the extension system.

## Git Status

The Website repo's working tree shows many changes from a large-scale refactoring
that is uncommitted:
- 13 files deleted from `.opencode/agents/` (old location)
- Many `.opencode/commands/` files modified
- `.opencode/context/` files modified
- New `.opencode/agent/subagents/` partially populated

## Fix Options

### Option A: Create Missing Agent Files (Recommended)
Create the 5 missing agent files in `.opencode/agent/subagents/`. Content for each:
- `web-research-agent.md`: Web research agent prompt for Astro/Tailwind/Cloudflare
- `web-implementation-agent.md`: Web implementation agent for Astro/TypeScript
- `neovim-research-agent.md`: Neovim Lua config research agent
- `neovim-implementation-agent.md`: Neovim Lua config implementation agent
- `document-converter-agent.md`: Document format conversion agent

Can be adapted from:
- Old content in git: `git show HEAD:.opencode/agents/web-research.md`
- Neovim config agents if similar ones exist

### Option B: Remove Broken Agent References from opencode.json
Remove the 5 broken agent entries from `opencode.json`. Simpler but loses
the specialized agent functionality.

### Option C: Restore Old Directory Structure
Revert the refactoring: restore `.opencode/agents/` and update `opencode.json`
back to old path patterns. Avoids having to recreate content.

## Recommendation

**Option A**: Create the missing agent files. The new naming convention
(`*-agent.md` suffix) and directory structure (`agent/subagents/`) is cleaner.
The content can be derived from git history (`git show HEAD:.opencode/agents/web-research.md`
etc.) and updated for the new naming scheme.

## Files to Create

```
/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/
├── web-research-agent.md          # New file
├── web-implementation-agent.md    # New file
├── neovim-research-agent.md       # New file
├── neovim-implementation-agent.md # New file
└── document-converter-agent.md    # New file
```

## Next Steps

1. Retrieve old agent content from git history in Website repo
2. Create 5 missing agent files with appropriate content
3. Verify opencode.json loads without error

---

**Note**: This is a Website repo fix, not a neovim config fix. Implementation
should be done directly in `/home/benjamin/Projects/Logos/Website/`.
