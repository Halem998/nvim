# Implementation Plan: Task #498

- **Task**: 498 - Make /spawn work from any non-terminal state with interactive confirmation
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/498_spawn_any_state_interactive/reports/01_spawn-state-research.md
- **Artifacts**: plans/01_spawn-state-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Update `/spawn` to allow invocation from any non-terminal state by replacing the per-status validation table with the standard terminal-state check. Extend `spawn-agent` to support a new "holistic analysis" mode for non-blocked tasks, with interactive `AskUserQuestion` confirmation before creating tasks. Update `skill-spawn` to preserve `previous_status` and gracefully handle empty task arrays. All changes apply to both `.opencode/` and `.claude/` trees.

### Research Integration

The research report identified that `commands/spawn.md` manually blocks `researching` and `planning` statuses, violating the system-wide permissive rule defined in `status-markers.md` and `state-management.md`. The report also documented the `AskUserQuestion` interactive confirmation patterns used by `/fix-it`, `/review`, and `/meta`, which serve as the model for spawn-agent's new holistic mode. Six files require coordinated changes across both trees.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace spawn.md status validation with terminal-state-only check
- Add `previous_status` preservation in skill-spawn preflight
- Pass `analysis_mode` (blocker|holistic) from skill-spawn to spawn-agent
- Implement dual-mode analysis in spawn-agent: blocker mode (existing) and holistic mode (new)
- Add interactive `AskUserQuestion` with `multiSelect: true` for holistic mode task confirmation
- Handle empty `new_tasks` arrays gracefully in skill-spawn postflight
- Apply all changes to both `.opencode/` and `.claude/` trees

**Non-Goals**:
- Changing the `.spawn-return.json` schema (handle cancellation via empty array or status field)
- Modifying other commands' status validation (only `/spawn`)
- Adding new dependencies or external tools
- Changing terminal state definitions (completed, abandoned, expanded)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Divergence between .opencode and .claude files | High | Medium | Edit both trees for every change; verify byte-for-byte parity after each phase |
| Breaking existing blocked-task spawn workflow | High | Low | Keep existing blocker analysis path fully intact; only add holistic path as conditional branch |
| Status `blocked` semantics confusion | Medium | Low | Document clearly in skill-spawn that `[BLOCKED]` means "has unmet dependencies", not "encountered an error" |
| User cancels spawn after agent analysis | Low | Low | Agent writes `.spawn-return.json` with empty `new_tasks` on cancel; skill handles missing/empty file gracefully |
| Agent timeout during interactive questions | Low | Low | AskUserQuestion is synchronous; timeout risk exists but is consistent with other interactive commands |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update commands/spawn.md Status Validation [COMPLETED]

**Goal**: Replace the per-status validation table with the standard terminal-state check in both trees.

**Tasks**:
- [ ] Read `.opencode/commands/spawn.md` and `.claude/commands/spawn.md` to confirm current content
- [ ] Replace CHECKPOINT 1, Step 4 status table with terminal-state check:
  - ABORT if status in `[completed, abandoned, expanded]`
  - ALLOW all other non-terminal statuses
- [ ] Update rationale text to reference `status-markers.md` and `state-management.md`
- [ ] Add example in "Examples" section for spawning from `researching` state
- [ ] Apply identical changes to `.claude/commands/spawn.md`
- [ ] Verify byte-for-byte parity between the two trees

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/commands/spawn.md` - CHECKPOINT 1, Step 4 status validation
- `.claude/commands/spawn.md` - CHECKPOINT 1, Step 4 status validation

**Verification**:
- Both files contain the terminal-state-only check
- Both files no longer contain `researching` or `planning` in the ABORT row
- Diff between `.opencode/commands/spawn.md` and `.claude/commands/spawn.md` shows only expected path differences (if any)

---

### Phase 2: Update skills/skill-spawn/SKILL.md [COMPLETED]

**Goal**: Add conditional status handling, `previous_status` preservation, `analysis_mode` delegation, and empty-task handling.

**Tasks**:
- [ ] Read `.opencode/skills/skill-spawn/SKILL.md` and `.claude/skills/skill-spawn/SKILL.md`
- [ ] Update Stage 2 (Preflight Status Update):
  - Detect spawn type: blocker-driven (`blocked`, `implementing`, `partial`) vs holistic (all other non-terminal)
  - Preserve `previous_status` in state.json before updating to `blocked`
  - Document that `[BLOCKED]` means "has unmet dependencies"
- [ ] Update Stage 6 (Invoke Subagent):
  - Add `analysis_mode` field to delegation context JSON (`"blocker"` or `"holistic"`)
- [ ] Update Stage 7 (Read Return Metadata / Postflight):
  - Handle empty `new_tasks` array gracefully (exit 0 with informative message)
  - Handle cancelled spawn (empty selection) without error
- [ ] Apply identical changes to `.claude/skills/skill-spawn/SKILL.md`
- [ ] Verify byte-for-byte parity between the two trees

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-spawn/SKILL.md` - Stage 2, Stage 6, Stage 7
- `.claude/skills/skill-spawn/SKILL.md` - Stage 2, Stage 6, Stage 7

**Verification**:
- Stage 2 preserves `previous_status` in state.json
- Stage 6 includes `analysis_mode` in the delegation context
- Stage 7 handles `new_tasks` length of 0 without error
- Both files are identical between trees

---

### Phase 3: Update agents/spawn-agent.md Dual-Mode Analysis [COMPLETED]

**Goal**: Implement mode detection, holistic analysis flow, and interactive confirmation.

**Tasks**:
- [ ] Read `.opencode/extensions/core/agents/spawn-agent.md` and `.claude/agents/spawn-agent.md`
- [ ] Add Stage 1.5: Determine Analysis Mode:
  - `blocker` mode: status is `blocked`, `implementing`, or `partial`, OR `blocker_prompt` is provided
  - `holistic` mode: status is any other non-terminal state AND `blocker_prompt` is empty
- [ ] Refactor Stage 2 into dual paths:
  - **Blocker Mode**: Keep existing Stage 2 content exactly as-is
  - **Holistic Mode**: Add new section for holistic assessment:
    - Read task description, plan, and research reports
    - Identify natural decomposition points (independent components, prerequisites, scope size)
    - Determine if spawning is warranted
    - Propose 2-4 minimal tasks with title, description, effort, task_type, dependencies
- [ ] Add Stage 3.5: Interactive Confirmation (Holistic Mode Only):
  - Use `AskUserQuestion` with `multiSelect: true`
  - Options format: `label` = task title, `description` = effort + rationale summary
  - Empty selection: write `.spawn-return.json` with `new_tasks: []`, set status to `cancelled`, return cancellation message
  - Any selection: filter proposed tasks to selected items, proceed to Stage 4
- [ ] Update Stage 5 (Write `.spawn-return.json`) to handle cancelled state
- [ ] Apply identical changes to `.claude/agents/spawn-agent.md`
- [ ] Verify byte-for-byte parity between the two trees

**Timing**: 60 minutes

**Depends on**: 2

**Files to modify**:
- `.opencode/extensions/core/agents/spawn-agent.md` - Stage 1.5, Stage 2 (refactor), Stage 3.5, Stage 5
- `.claude/agents/spawn-agent.md` - Stage 1.5, Stage 2 (refactor), Stage 3.5, Stage 5

**Verification**:
- Agent correctly detects blocker mode vs holistic mode based on status and blocker_prompt
- Blocker mode path is unchanged from current behavior
- Holistic mode proposes tasks and presents AskUserQuestion
- Empty selection produces valid `.spawn-return.json` with empty `new_tasks`
- Both files are identical between trees

---

### Phase 4: Testing and Validation [COMPLETED]

**Goal**: Verify all changes work correctly across both trees and do not break existing workflows.

**Tasks**:
- [ ] **Static verification**: Confirm all 6 modified files exist and contain expected changes
- [ ] **Cross-tree parity check**: Run `diff` between `.opencode/` and `.claude/` counterparts for each file pair
- [ ] **Blocker mode regression test**: Simulate blocked task spawn and verify existing flow still works
- [ ] **Holistic mode flow test**: Simulate `researching` task spawn and verify:
  - Status validation allows the spawn
  - Agent enters holistic mode
  - AskUserQuestion is presented (manual check of agent definition)
  - Empty selection handling is documented
- [ ] **Empty task handling test**: Verify skill-spawn postflight handles `new_tasks: []` without error
- [ ] **Status preservation test**: Verify `previous_status` is written to state.json during preflight

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only)

**Verification**:
- All 6 files are modified and consistent between trees
- Existing blocker spawn workflow is preserved
- New holistic workflow is documented and functional
- Empty/cancelled spawn does not produce errors

## Testing & Validation

- [ ] Terminal-state check correctly blocks `completed`, `abandoned`, `expanded`
- [ ] All non-terminal statuses (`researching`, `planning`, `implementing`, `partial`, `blocked`, `planned`, `researched`, `not_started`) allow spawn
- [ ] `previous_status` is preserved in state.json when transitioning to `blocked`
- [ ] `analysis_mode` is correctly set to `blocker` for blocked/implementing/partial tasks
- [ ] `analysis_mode` is correctly set to `holistic` for researching/planning/planned/researched/not_started tasks
- [ ] Blocker mode agent flow is unchanged (no regression)
- [ ] Holistic mode presents AskUserQuestion with multiSelect
- [ ] Empty selection in holistic mode produces graceful cancellation
- [ ] Skill-spawn handles empty `new_tasks` array without error
- [ ] `.opencode/` and `.claude/` files remain byte-for-byte identical

## Artifacts & Outputs

- `.opencode/commands/spawn.md` - Updated status validation
- `.claude/commands/spawn.md` - Updated status validation
- `.opencode/skills/skill-spawn/SKILL.md` - Conditional status handling, analysis_mode, empty-task handling
- `.claude/skills/skill-spawn/SKILL.md` - Conditional status handling, analysis_mode, empty-task handling
- `.opencode/extensions/core/agents/spawn-agent.md` - Dual-mode analysis, interactive confirmation
- `.claude/agents/spawn-agent.md` - Dual-mode analysis, interactive confirmation
- `specs/498_spawn_any_state_interactive/plans/01_spawn-state-plan.md` - This plan

## Rollback/Contingency

If implementation introduces regressions:
1. Revert each modified file to its pre-change state using git checkout
2. The changes are localized to 6 files with no schema migrations or external dependencies
3. If only the holistic mode is problematic, revert agent changes while keeping command and skill updates (holistic mode will not be triggered without the agent changes)
4. If status validation causes issues, restore the original per-status table temporarily while debugging
