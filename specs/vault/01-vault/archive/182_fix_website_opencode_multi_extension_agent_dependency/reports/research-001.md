# Website Opencode Multi-Extension Agent Dependency - Research Report

**Task**: 182 - Fix Website opencode multi-extension agent dependency
**Date**: 2026-03-10
**Status**: Research Complete
**Language**: meta

## Problem Summary

The Website project's `opencode.json` references agent files that are installed by
three separate extensions. After reloading the "core agent system", extension-provided
agent files are removed, leaving opencode unable to start. The user must manually
reload `web`, `nvim`, and `memory` extensions every time — and forgetting any one
causes opencode to fail with a "bad file reference" error.

## Architecture of the Problem

### How the Extension System Works

The neovim extension system (`<leader>ao`) manages files in project `.opencode/`
directories. Each extension:
- **Installs** files when loaded (agents, skills, commands, context)
- **Removes** installed files when unloaded

When the "core agent system" is reloaded (unload + reload), all extension-provided
files are removed as part of the unload, then only the core files are reinstalled.

### What opencode.json References

The Website's `opencode.json` uses `{file:...}` references for 5 agent prompts.
These references are validated at startup — if the file doesn't exist, opencode
refuses to start.

| Agent in opencode.json | File Referenced | Providing Extension |
|---|---|---|
| `web-research` | `.opencode/agent/subagents/web-research-agent.md` | `web` |
| `web-implementation` | `.opencode/agent/subagents/web-implementation-agent.md` | `web` |
| `neovim-research` | `.opencode/agent/subagents/neovim-research-agent.md` | `nvim` |
| `neovim-implementation` | `.opencode/agent/subagents/neovim-implementation-agent.md` | `nvim` |
| `document-converter` | `.opencode/agent/subagents/document-converter-agent.md` | `web` (added 2026-03-10) |

### Required Post-Reload Sequence

After every core reload, the user must load:
1. `web` extension — provides 3 agents
2. `nvim` extension — provides 2 agents
3. `memory` extension — provides skills/commands/data

Missing any one causes opencode to fail.

## Root Cause Analysis

The `{file:...}` syntax in opencode.json creates a **hard dependency** on files that
are **dynamically managed** by the extension system. The two systems have no awareness
of each other:

- opencode validates references at startup (hard failure)
- The extension system installs/removes files silently

This mismatch means the Website repo has a fragile startup state that depends on
extension load order and completeness.

## Current State (as of 2026-03-10)

- `document-converter-agent.md` added to `web` extension manifest (task 182 fixes this partially)
- The `web` and `nvim` extensions must still be manually loaded after every core reload
- No mechanism ensures all required extensions are loaded before opencode starts

## Solution Options

### Option A: Static Agent Files (Recommended for Website)

Commit the 5 agent files directly to the Website repo, outside the extension system.
The extension system would no longer manage them.

**Pros**:
- No dependency on extension load order
- opencode always starts correctly
- Agents are version-controlled in the Website repo
- No workflow change needed

**Cons**:
- Agent files diverge from the extension source (must update manually)
- Two copies to maintain (extension source + Website static copy)

**Implementation**:
1. Copy 5 agent files to `.opencode/agent/subagents/` in Website repo
2. Commit them (they become part of the repo, not managed by extensions)
3. Update `.gitignore` if needed to ensure they're tracked
4. Remove `{file:...}` references that can't be static, OR keep them and ensure
   the static files are always present

### Option B: Bundle All Agents in a Single "Website Core" Extension

Create a new extension that provides ALL agents needed by the Website, replacing
the fragmented web + nvim + core model.

**Pros**:
- Single extension load restores all agents
- Clear dependency boundary

**Cons**:
- Duplicates content already in web and nvim extensions
- More extensions to maintain

### Option C: Inline Prompts in opencode.json

Replace `{file:...}` references with inline prompt text in opencode.json.

**Pros**:
- No file dependency at all
- opencode always starts

**Cons**:
- opencode.json becomes very large
- Prompt text harder to maintain in JSON format
- Loses syntax highlighting and editing ergonomics of .md files

### Option D: Extension Load Guard Script

Add a script or hook that checks required extensions are loaded before opencode
starts, and loads missing ones automatically.

**Pros**:
- Keeps current architecture
- Automatic recovery

**Cons**:
- Requires hook/script mechanism
- Adds startup latency
- Complex to implement correctly

## Recommendation

**Option A (Static Agent Files)** is the most robust solution for the Website repo.

The Website's agent definitions are specific to that project's needs (Astro, Tailwind,
Cloudflare). Committing them directly to the repo:
- Eliminates the fragile extension dependency
- Makes the Website self-contained
- Allows project-specific customization of agent prompts
- The extension system can still be used for context, skills, commands, and memory

The `web` and `nvim` extension agent files remain the canonical source — the Website
would periodically sync from them if needed.

## Files Involved

### Website Repo
- `opencode.json` — references 5 agent files via `{file:...}`
- `.opencode/agent/subagents/` — target directory for agent files

### Extension Sources (in nvim config)
- `.opencode/extensions/web/agents/web-research-agent.md`
- `.opencode/extensions/web/agents/web-implementation-agent.md`
- `.opencode/extensions/web/agents/document-converter-agent.md`
- `.opencode/extensions/nvim/agents/neovim-research-agent.md`
- `.opencode/extensions/nvim/agents/neovim-implementation-agent.md`

## Implementation Plan (Option A)

### Phase 1: Copy Agent Files as Static Files
- Copy 5 agent files to `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/`
- Commit them to the Website repo git history

### Phase 2: Ensure Persistence
- Check `.gitignore` to ensure files are not ignored
- Optionally add a note in `.opencode/agent/subagents/README.md` that these are static

### Phase 3: Verify
- Reload core agent system
- Confirm opencode starts without errors (without loading web/nvim extensions)
- Load memory extension
- Confirm memory extension loads cleanly

## Related Tasks

- Task 181: Fix Website opencode missing agent files (completed — temporary fix)
- Task 182: This task — permanent fix

## Next Steps

Implement Option A: commit the 5 agent files as static files in the Website repo.
