# Implementation Plan: Task #590

- **Task**: 590 - fix_task_number_parsing_display
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/590_fix_task_number_parsing_display/reports/01_task-number-parsing.md
- **Artifacts**: plans/01_task-number-parsing.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `wezterm-task-number.sh` hook currently uses a narrow regex matching only 4 commands (`research|plan|implement|revise`) and a 2-tier set/clear logic that causes stale task number clearing on follow-up prompts. This plan replaces the current logic with a 3-tier pattern (SET/CLEAR/PRESERVE) that supports all task-bearing commands (`/spawn`, `/task --recover`, `/task --expand`, `/task --abandon`, `/task --review`, `/errors --fix`), displays compact multi-task specs (e.g., `7,22-24,59`), and preserves task numbers during free-text follow-up exchanges. The same changes are applied to all 4 identical copies of the hook, and 2 documentation files are updated to reflect the new behavior.

### Research Integration

Research report `reports/01_task-number-parsing.md` provided:
- Complete inventory of all commands that accept task numbers (14 patterns)
- Detailed 3-tier regex implementation with post-processing logic
- Comprehensive test matrix (18 test cases covering SET, CLEAR, and PRESERVE scenarios)
- Edge case analysis (trailing hyphens, leading zeros, very long specs, empty prompts)
- File change table identifying all 6 files requiring modification

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Support all task-number-bearing commands: `/spawn N`, `/task --recover N`, `/task --expand N`, `/task --abandon N`, `/task --review N`, `/errors --fix N`
- Display compact multi-task specs (spaces stripped) for multi-task syntax
- Preserve task number on free-text follow-up prompts (3-tier logic)
- Keep all 4 hook copies in sync with identical content
- Update documentation to reflect 3-tier behavior and expanded command support

**Non-Goals**:
- Modifying `wezterm-clear-task-number.sh` (SessionStart clear is correct)
- Changing `settings.json` hook registration (order is correct)
- Modifying `wezterm.lua` tab formatting (already handles any string value)
- Adding conversation-context awareness to the hook (unnecessary with 3-tier logic)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regex mismatch on edge case prompt patterns | L | L | Research provides 18 verified test cases; post-processing strips `--` flags safely |
| Hook copies drift out of sync after future edits | M | M | Documentation explicitly lists all 4 paths; implementer should copy final content identically |
| Trailing hyphen or comma in task spec | L | L | While-loop trim removes trailing whitespace and commas; `%%--*` strips double-dash suffixes |
| Free text starting with `/` treated as command (Tier 2 false positive) | L | L | Extremely unlikely in practice; acceptable edge case |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement 3-Tier Logic in Hook Scripts [COMPLETED]

**Goal**: Replace the current 2-tier (set/clear) regex with 3-tier (SET/CLEAR/PRESERVE) logic in all 4 copies of `wezterm-task-number.sh`.

**Tasks**:
- [x] Replace the current regex block (lines 34-38) in `.claude/hooks/wezterm-task-number.sh` with the 3-tier pattern: *(completed)*
  - Tier 1a: `research|plan|implement|revise|spawn` + task spec (capture multi-task syntax)
  - Tier 1b: `/task --recover/expand/abandon/review` + task spec
  - Tier 1c: `/errors --fix N`
  - Tier 2: Any other slash command (`^[[:space:]]*/[a-zA-Z]`) clears task number
  - Tier 3: Free text / follow-up preserves task number (implicit else)
- [x] Add post-processing for Tier 1a/1b: strip from first `--` (flags), trim trailing spaces/commas, compact by removing internal spaces *(completed)*
- [x] Replace the if/else block (lines 50-62) with 3-way conditional: set on `SHOULD_SET`, clear on `SHOULD_CLEAR`, no-op otherwise *(completed)*
- [x] Update the header comment (lines 8-9) to describe the expanded command support and 3-tier logic *(completed)*
- [x] Copy the updated script identically to the 3 mirror locations: *(completed)*
  - `.claude/extensions/core/hooks/wezterm-task-number.sh`
  - `.opencode/hooks/wezterm-task-number.sh`
  - `.opencode/extensions/core/hooks/wezterm-task-number.sh`
- [x] Verify all 4 files are byte-identical using `diff` or `md5sum` *(completed: md5sum confirmed identical)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/hooks/wezterm-task-number.sh` - Replace regex and conditional logic with 3-tier pattern
- `.claude/extensions/core/hooks/wezterm-task-number.sh` - Identical copy
- `.opencode/hooks/wezterm-task-number.sh` - Identical copy
- `.opencode/extensions/core/hooks/wezterm-task-number.sh` - Identical copy

**Verification**:
- All 4 files are byte-identical (`md5sum` check)
- Script passes `bash -n` syntax check (no parse errors)
- Manual review confirms Tier 1/2/3 logic matches research report test matrix

---

### Phase 2: Update Documentation [COMPLETED]

**Goal**: Update both documentation files to describe the 3-tier behavior, expanded command list, and multi-task spec display.

**Tasks**:
- [x] In `.claude/context/project/neovim/hooks/wezterm-integration.md`, update the `wezterm-task-number.sh` section (lines ~58-75): *(completed)*
  - Expand the workflow pattern list to include `/spawn N`, `/task --recover N`, `/task --expand N`, `/task --abandon N`, `/task --review N`, `/errors --fix N`
  - Update the behavior description from 2-tier to 3-tier:
    - **Workflow command with task number**: Sets `TASK_NUMBER` to compact spec
    - **Slash command without task number**: Clears `TASK_NUMBER`
    - **Free text / follow-up**: Preserves `TASK_NUMBER` (no change)
  - Update the User Variables table: change `TASK_NUMBER` values from `Numeric string (e.g., "792")` to `Numeric string or compact multi-task spec (e.g., "792", "7,22-24,59")`
- [x] Apply the same documentation updates to `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` *(completed)*
- [x] Verify both documentation files are consistent *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/project/neovim/hooks/wezterm-integration.md` - Update command list, behavior description, user variable values
- `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` - Same updates

**Verification**:
- Documentation lists all 6 additional command patterns
- 3-tier behavior is described accurately
- `TASK_NUMBER` value description includes multi-task spec example

## Testing & Validation

- [ ] All 4 hook script copies pass `bash -n` syntax check
- [ ] All 4 hook copies are byte-identical (or functionally identical via `diff`)
- [ ] Manual test in WezTerm: `/research 7` sets tab to `#7`
- [ ] Manual test in WezTerm: `/research 7, 22-24, 59` sets tab to `#7,22-24,59`
- [ ] Manual test: free-text follow-up (e.g., "yes proceed") does not clear the task number
- [ ] Manual test: `/todo` (no task number) clears the task number
- [ ] Documentation accurately describes the 3-tier logic and all supported commands

## Artifacts & Outputs

- `specs/590_fix_task_number_parsing_display/plans/01_task-number-parsing.md` (this plan)
- `specs/590_fix_task_number_parsing_display/summaries/01_task-number-parsing-summary.md` (after implementation)

## Rollback/Contingency

Git revert the commit containing hook changes. The previous 2-tier logic is functional (just incomplete). No data migration or state changes are involved -- the hook is stateless and the WezTerm user variable resets each session.
