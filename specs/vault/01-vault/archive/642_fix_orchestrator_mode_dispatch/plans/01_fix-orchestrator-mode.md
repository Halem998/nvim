# Implementation Plan: Task #642 -- Fix Orchestrator Mode Dispatch

- **Task**: 642 - Fix orchestrator_mode=false for research/plan dispatch
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/642_fix_orchestrator_mode_dispatch/reports/01_orchestrator-mode-dispatch.md
- **Artifacts**: plans/01_fix-orchestrator-mode.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Change four `"orchestrator_mode": false` values to `true` in `.claude/skills/skill-orchestrate/SKILL.md` so that research and plan dispatches write `.orchestrator-handoff.json`, enabling the orchestrator postflight chain (artifact linking, status reading) to work for all lifecycle phases, not just implement. The downstream skills (skill-researcher, skill-planner) already call `skill_write_orchestrator_handoff` and pass through the value -- only the dispatch context needs correction.

### Research Integration

Research report (01_orchestrator-mode-dispatch.md) identified exactly 4 locations needing change: lines 208, 240, 934, 959. It confirmed that blocker/drift/reviser dispatches at lines 459, 494, 542 correctly use `false` and must not be touched. Both skill-researcher and skill-planner already handle `orchestrator_mode=true` correctly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Enable handoff JSON writing for research and plan dispatches in both single-task and multi-task orchestrator modes
- Ensure orchestrator Stage 5 can read handoff artifacts, status, and next_action_hint after research/plan phases

**Non-Goals**:
- Changing blocker escalation, drift inspection, or reviser dispatch contexts (these correctly use `false`)
- Modifying skill-researcher or skill-planner internals (already correctly wired)
- Updating orchestrate-state-machine.md documentation (docs-only, separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wrong line edited (blocker context vs research context) | H | L | Research identified exact lines; verify surrounding context before editing |
| Existing partial orchestration runs missing handoff | L | M | Orchestrator already handles missing handoff gracefully (logs error, continues) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix orchestrator_mode in dispatch contexts [COMPLETED]

**Goal**: Change `"orchestrator_mode": false` to `"orchestrator_mode": true` at all 4 research/plan dispatch locations.

**Tasks**:
- [x] Edit line ~208: single-task research dispatch (`not_started` handler) -- change `false` to `true` *(completed)*
- [x] Edit line ~240: single-task plan dispatch (`researched` handler) -- change `false` to `true` *(completed)*
- [x] Edit line ~934: multi-task research dispatch (Stage MT-4) -- change `false` to `true` *(completed)*
- [x] Edit line ~959: multi-task plan dispatch (Stage MT-4) -- change `false` to `true` *(completed)*
- [x] Verify lines 459, 494, 542 remain `false` (blocker/drift/reviser -- do NOT change) *(completed: 4 false values confirmed at lines 459, 494, 542, 562 — all in blocker/drift/reviser contexts)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` -- 4 edits (false -> true)

**Verification**:
- `grep -n "orchestrator_mode" .claude/skills/skill-orchestrate/SKILL.md` shows `true` at the 4 fixed locations and `false` only at blocker/drift/reviser locations
- Count of `"orchestrator_mode": true` increases from 4 to 8
- Count of `"orchestrator_mode": false` decreases from 7 to 3

## Testing & Validation

- [x] Run `grep -c '"orchestrator_mode": true' .claude/skills/skill-orchestrate/SKILL.md` -- expect 8 *(completed: got 8)*
- [x] Run `grep -c '"orchestrator_mode": false' .claude/skills/skill-orchestrate/SKILL.md` -- expect 3 *(deviation: altered — actual count is 4; line 562 is a 4th reviser dispatch in blocker escalation Step 4, also correctly false)*
- [x] Verify blocker contexts unchanged: lines 459, 494, 542 still show `false` *(completed: lines 459, 494, 542, 562 all false — all blocker/drift/reviser contexts)*
- [x] Spot-check: `grep -B5 -A1 "orchestrator_mode" .claude/skills/skill-orchestrate/SKILL.md` to confirm each context is correct *(completed)*

## Artifacts & Outputs

- `specs/642_fix_orchestrator_mode_dispatch/plans/01_fix-orchestrator-mode.md` (this plan)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified file)

## Rollback/Contingency

Revert with `git checkout -- .claude/skills/skill-orchestrate/SKILL.md`. The change is purely additive (enables handoff writing that was previously skipped) with no destructive side effects.
