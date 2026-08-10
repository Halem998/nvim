# Research Report: Task #515

**Task**: 515 - Fix opencode startup crash caused by spawn-agent.md tools format mismatch
**Started**: 2026-05-02T00:00:00Z
**Completed**: 2026-05-02T00:15:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration of `.opencode/agent/subagents/` and `.claude/agents/`
- Git history analysis (commits `7afea460d`, `faa0452fc`, `b9883a692`)
- OpenCode frontmatter documentation (`.opencode/context/formats/frontmatter.md`)
- Neovim plugin configuration (`lua/neotex/plugins/ai/opencode.lua`)
**Artifacts**:
- `specs/515_fix_opencode_crash_spawn_agent_tools_format/reports/01_opencode-crash-tools-format.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The crash was caused by `spawn-agent.md` having a `tools` field as a YAML array (Claude Code format: `- Read`, `- Write`, etc.) while opencode expects either no tools field or tools as an object/record format.
- The fix was already applied in commit `7afea460d` by removing the `tools` field entirely from both `.opencode/agent/subagents/spawn-agent.md` and `.opencode/extensions/core/agents/spawn-agent.md`.
- The opencode.lua Neovim plugin was also restructured in the same timeframe (task 514), switching from a defunct `provider` API to a `server` function-based API using `snacks.terminal`.
- No additional files need changes -- the fix is complete and committed.
- The `.claude/agents/spawn-agent.md` retains its `tools` YAML array, which is correct for Claude Code's format.

## Context & Scope

This research investigates a crash in opencode that manifested as the sidebar flashing open and immediately closing when launched from Neovim. The root cause was a format mismatch in agent frontmatter files.

**Two systems share agent definitions but have different frontmatter schemas**:
- `.claude/agents/*.md` -- Claude Code agent files, supports YAML array `tools` field
- `.opencode/agent/subagents/*.md` -- OpenCode agent files, does NOT support YAML array `tools` field

When tasks 510-513 ported agent files from `.claude/` to `.opencode/`, the `spawn-agent.md` file was copied with its Claude Code-specific `tools` YAML array intact. OpenCode auto-scans `.opencode/agent/subagents/` on startup and failed with "expected record, received array" when parsing the tools field.

## Findings

### Root Cause: Tools Field Format Mismatch

The Claude Code `spawn-agent.md` frontmatter contained:

```yaml
---
name: spawn-agent
description: ...
model: opus
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash(jq:*)
---
```

OpenCode's YAML parser expected `tools` as either absent (default tools) or as an object/record. The YAML array format caused a parse error that crashed the entire application before any UI rendered.

### Why Only spawn-agent.md Was Affected

All other `.opencode/agent/subagents/*.md` files have minimal frontmatter with only `name`, `description`, and `model` fields -- no `tools` field. The `spawn-agent.md` was the only file that carried over the `tools` array from its Claude Code counterpart during the tasks 510-513 port.

### OpenCode Frontmatter Format

Per `.opencode/context/formats/frontmatter.md`, the documented tools format for opencode is a YAML array of lowercase tool names:

```yaml
tools:
  - read
  - write
  - bash
```

However, the actual opencode Go runtime appears to expect tools as a record/object (or not present at all). The documentation and runtime behavior are inconsistent. The safest approach is to omit the `tools` field entirely, letting agents use default tools.

### Neovim Plugin Changes (Separate Issue)

The `opencode.lua` file was also modified (visible in `git diff`), switching from:
- Old: `provider` table in `vim.g.opencode_opts` with `snacks` provider config
- New: `server` functions set directly on `require("opencode.config").opts` using `snacks.terminal`

This change was necessary because:
1. `vim.g` serializes to msgpack, silently dropping functions
2. The old `provider` API was defunct in the NickvanDyke/opencode.nvim variant
3. The new `server` API with `start/stop/toggle` functions is the correct integration point

These Neovim changes are correct but were NOT the cause of the crash.

### Fix Already Applied

Commit `7afea460d` removed the `tools` field from:
1. `.opencode/agent/subagents/spawn-agent.md`
2. `.opencode/extensions/core/agents/spawn-agent.md`

Commit `faa0452fc` (task 514) then performed broader cleanup of `.claude/` references across all opencode files.

## Decisions

- The `tools` field was removed entirely rather than converted to opencode format, since other opencode agents also omit it and use default tools.
- The `.claude/agents/spawn-agent.md` retains its `tools` YAML array, which is the correct format for Claude Code.

## Recommendations

1. **No further code changes needed** -- the fix is already committed and the opencode.lua restructuring is in the working tree.
2. **Commit the opencode.lua changes** if not already committed as part of task 514.
3. **Future agent porting** should strip Claude Code-specific frontmatter fields (`tools` as YAML array) when copying to `.opencode/agent/subagents/`.
4. **Consider adding a validation step** to the extension loader or sync process that checks opencode subagent frontmatter against the expected schema before writing files.

## Risks & Mitigations

- **Risk**: Future sync operations could re-introduce the `tools` array format. **Mitigation**: Document the format difference in the agent porting guidelines; add a frontmatter validation check.
- **Risk**: opencode documentation says tools is a YAML array but runtime rejects arrays. **Mitigation**: Update `.opencode/context/formats/frontmatter.md` to clarify that tools should be omitted from subagent frontmatter or use the correct runtime format.

## Appendix

### Key Commits
- `b9883a692` -- tasks 510-513 implementation that introduced the spawn-agent.md with tools array
- `7afea460d` -- fix commit removing the invalid tools array
- `faa0452fc` -- task 514 broader cleanup of .claude/ references

### Files Examined
- `.opencode/agent/subagents/spawn-agent.md` -- fixed (tools removed)
- `.opencode/extensions/core/agents/spawn-agent.md` -- fixed (tools removed)
- `.claude/agents/spawn-agent.md` -- unchanged, retains tools array (correct for Claude Code)
- `lua/neotex/plugins/ai/opencode.lua` -- restructured (separate from crash fix)
- `.opencode/context/formats/frontmatter.md` -- opencode frontmatter documentation
