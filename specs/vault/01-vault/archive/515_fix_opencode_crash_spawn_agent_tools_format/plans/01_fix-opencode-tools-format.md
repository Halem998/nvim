# Implementation Plan: Fix OpenCode Crash - Spawn Agent Tools Format

- **Task**: 515 - Fix opencode startup crash caused by spawn-agent.md tools format mismatch
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None (crash fix already committed in 7afea460d)
- **Research Inputs**: reports/01_opencode-crash-tools-format.md
- **Artifacts**: plans/01_fix-opencode-tools-format.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

The opencode startup crash caused by a `tools` YAML array in `spawn-agent.md` has already been fixed (commit 7afea460d). This plan covers the remaining cleanup: updating the opencode frontmatter documentation to accurately reflect runtime behavior (tools field should be omitted from subagent files rather than specified as a YAML array), committing the unrelated-but-concurrent opencode.lua Neovim plugin changes, and verifying opencode launches correctly.

### Research Integration

Research report (01_opencode-crash-tools-format.md) confirmed:
- Root cause was `tools` as YAML array in `.opencode/agent/subagents/spawn-agent.md` -- opencode runtime expects no tools field or an object/record format, not an array.
- The frontmatter documentation (`.opencode/context/formats/frontmatter.md`) says `tools` is a required array field, which contradicts runtime behavior.
- All existing opencode subagents work correctly by omitting the `tools` field entirely.
- The `opencode.lua` plugin was restructured (provider API to server API) during task 514 but remains uncommitted.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task partially advances the "Agent frontmatter validation" roadmap item under Phase 1 > Agent System Quality, by documenting the correct tools field behavior for opencode subagents and adding a warning about format differences between Claude Code and opencode agent files.

## Goals & Non-Goals

**Goals**:
- Update `.opencode/context/formats/frontmatter.md` to document that `tools` should be omitted from subagent frontmatter (runtime uses default tools)
- Add a cross-system porting warning about Claude Code vs opencode frontmatter differences
- Commit the `opencode.lua` Neovim plugin changes (provider API to server API migration)
- Verify opencode starts without crash

**Non-Goals**:
- Building an automated frontmatter validation script (future task)
- Changing the tools field in `.claude/agents/` files (correct for Claude Code)
- Modifying opencode Go source code

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Frontmatter doc changes confuse future agents about tools field | M | L | Add clear "Runtime vs Documentation" note explaining the discrepancy |
| opencode.lua changes cause separate regression | M | L | Test opencode launch from Neovim after committing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update Frontmatter Documentation and Commit opencode.lua [COMPLETED]

**Goal**: Correct the frontmatter documentation to match runtime behavior and commit the opencode.lua plugin changes.

**Tasks**:
- [ ] Edit `.opencode/context/formats/frontmatter.md` Section 9 (tools): change `tools` from "Required" to "Optional" and add a note that omitting it is the recommended practice for subagents (runtime uses default tools)
- [ ] Add a "Cross-System Porting" warning section to frontmatter.md explaining that Claude Code agent files (`.claude/agents/`) use a different frontmatter schema -- `tools` as a YAML array of capitalized names -- and that this field must be stripped or omitted when porting to opencode
- [ ] Review the `opencode.lua` diff to confirm correctness (provider API removed, server functions added)
- [ ] Commit `opencode.lua` changes and frontmatter doc update

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/context/formats/frontmatter.md` - Update tools field documentation, add cross-system porting warning
- `lua/neotex/plugins/ai/opencode.lua` - Commit existing changes (no new edits needed)

**Verification**:
- `tools` field marked as Optional in frontmatter.md
- Cross-system porting warning present
- opencode.lua changes committed

---

### Phase 2: Verification [COMPLETED]

**Goal**: Confirm opencode starts correctly and no regressions exist.

**Tasks**:
- [ ] Launch opencode from Neovim and verify no crash (sidebar opens and stays visible)
- [ ] Verify no other `.opencode/agent/subagents/*.md` files contain a `tools` YAML array field
- [ ] Grep `.opencode/` for any remaining Claude Code-specific frontmatter patterns (capitalized tool names like `Read`, `Write`, `Bash`)

**Timing**: 15 minutes

**Depends on**: 1

**Verification**:
- opencode launches without crash
- No subagent files contain YAML array tools fields
- No Claude Code-specific frontmatter patterns found in opencode directory

## Testing & Validation

- [ ] opencode starts from Neovim without crashing
- [ ] `grep -r "tools:" .opencode/agent/subagents/` returns no results (all tools fields removed)
- [ ] `grep -rn "- Read\|- Write\|- Bash\|- Glob\|- Grep" .opencode/agent/subagents/` returns no matches
- [ ] frontmatter.md tools section reflects "Optional" status

## Artifacts & Outputs

- `specs/515_fix_opencode_crash_spawn_agent_tools_format/plans/01_fix-opencode-tools-format.md` (this file)
- `.opencode/context/formats/frontmatter.md` (updated)
- `lua/neotex/plugins/ai/opencode.lua` (committed)

## Rollback/Contingency

All changes are documentation and configuration only. Revert with `git revert` if any issues arise. The crash fix itself is already committed separately (7afea460d) and unaffected by this plan.
