# Research Report: Zero-Overlap Extension Architecture

**Task**: 182 - Fix Website opencode multi-extension agent dependency
**Date**: 2026-03-11
**Focus**: Eliminate extension overlap by removing duplicates and clarifying ownership
**Status**: Research Complete

## Summary

Analysis confirms minimal overlap exists and can be eliminated. The `document-converter-agent.md` in web extension should be removed (filetypes already has `document-agent.md`). Neovim agents should remain in nvim extension only. However, the Website's opencode.json must be updated since it references agents from multiple extensions.

## Current Extension Overlap Analysis

### Overlap Found

| Agent | web/ | nvim/ | filetypes/ | Action |
|-------|------|-------|------------|--------|
| document-converter-agent.md | YES | - | - | REMOVE from web |
| document-agent.md | - | - | YES | KEEP (canonical) |
| neovim-research-agent.md | - | YES | - | KEEP in nvim only |
| neovim-implementation-agent.md | - | YES | - | KEEP in nvim only |
| web-research-agent.md | YES | - | - | KEEP |
| web-implementation-agent.md | YES | - | - | KEEP |

### Agent Comparison

**web/document-converter-agent.md** (50 lines):
- Simplified document conversion agent
- Supports: PDF, DOCX, Images, HTML, Markdown
- Tools: markitdown, pandoc, typst

**filetypes/document-agent.md** (341 lines):
- Full-featured document conversion agent
- Same conversion support
- Structured JSON return format
- Comprehensive error handling
- Invoked via filetypes-router-agent pattern

**Verdict**: The filetypes version is more complete. Remove the web version.

## Changes Required for Zero-Overlap

### 1. Remove from web Extension

**Files to delete**:
```
.opencode/extensions/web/agents/document-converter-agent.md
```

**Files to modify**:
```
.opencode/extensions/web/manifest.json
  - Remove "document-converter-agent.md" from provides.agents array
  - Change: ["web-implementation-agent.md", "web-research-agent.md", "document-converter-agent.md"]
  - To: ["web-implementation-agent.md", "web-research-agent.md"]
```

### 2. Filetypes Extension (No Changes Needed)

The filetypes extension already provides document conversion via `document-agent.md`. No changes needed to filetypes.

### 3. Website opencode.json Changes

The Website's `opencode.json` references these extension-provided agents:

| Agent Reference | Extension | Current Status |
|-----------------|-----------|----------------|
| web-research-agent.md | web | Requires web extension |
| web-implementation-agent.md | web | Requires web extension |
| neovim-research-agent.md | nvim | Requires nvim extension |
| neovim-implementation-agent.md | nvim | Requires nvim extension |
| document-converter-agent.md | web | WILL BREAK after removal |

**Required Changes to Website opencode.json**:

Option A: **Remove document-converter from Website**
```json
// DELETE this entire agent definition:
"document-converter": {
  "prompt": "{file:.opencode/agent/subagents/document-converter-agent.md}",
  ...
}
```

Option B: **Change to filetypes' document-agent**
```json
"document-converter": {
  "prompt": "{file:.opencode/agent/subagents/document-agent.md}",
  ...
}
```
Then load filetypes extension which provides this agent.

Option C: **Inline prompt** (no file dependency)
```json
"document-converter": {
  "prompt": "You are a document converter agent. Convert between PDF/DOCX and Markdown using markitdown or pandoc.",
  ...
}
```

## Remaining Extension Dependencies for Website

After removing document-converter overlap, Website still requires:

| Agent | Extension Required |
|-------|-------------------|
| web-research-agent.md | web |
| web-implementation-agent.md | web |
| neovim-research-agent.md | nvim |
| neovim-implementation-agent.md | nvim |

**Two choices**:

1. **Load required extensions**: User must load `web` and `nvim` extensions after core reload
2. **Commit static copies**: Copy these 4 agents directly to Website (Option A from research-001)

## Recommendations

### For This Task (182)

1. **Remove document-converter-agent.md from web extension** (nvim config repo)
2. **Update web/manifest.json** to remove from provides.agents
3. **Update Website opencode.json** to either remove document-converter or use filetypes

### For Neovim Agents

Do NOT add neovim agents to web extension. The zero-overlap approach means:
- Projects needing neovim agents load the nvim extension
- Projects NOT needing neovim agents don't reference them

### For Website Specifically

The Website project currently references BOTH web and neovim agents. Options:
1. **Keep requiring both extensions** - User loads web + nvim + memory after core reload
2. **Remove neovim references** - If Website doesn't actually need neovim config capabilities
3. **Static copies** - Commit the 4 agents to Website repo (independent of extension system)

## Files to Modify

### nvim config repo (.opencode/)

1. **DELETE**: `.opencode/extensions/web/agents/document-converter-agent.md`
2. **EDIT**: `.opencode/extensions/web/manifest.json` - remove agent from provides.agents

### Website repo

1. **EDIT**: `opencode.json` - remove or modify document-converter agent definition
2. **DECISION**: Keep neovim references (requires loading nvim extension) or remove them

## Implementation Plan Update

The revised plan (implementation-002.md) should be abandoned. New approach:

**Phase 1**: Remove document-converter from web extension
- Delete agent file
- Update manifest.json
- Commit to nvim config repo

**Phase 2**: Update Website opencode.json
- Remove document-converter agent definition (or switch to inline prompt)
- Decide on neovim agents: keep (load nvim extension) or remove

**Phase 3**: Verify
- Reload core agent system
- Load web extension only
- Verify opencode starts (it won't need document-converter)
- Load nvim extension if needed for neovim agents

## Next Steps

1. Create revised plan (implementation-003.md) with zero-overlap approach
2. Implement the changes
3. Test in Website repo

## Key Insight

The original problem (task 181/182) was that opencode failed after core reload because agents were missing. The zero-overlap solution changes the approach:

- **Old approach**: Make web extension provide ALL agents Website needs
- **New approach**: Remove overlap, let extensions be focused, and either:
  - Load all required extensions (web + nvim + memory)
  - Or modify Website to not depend on agents it doesn't truly need
