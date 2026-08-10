# Implementation Plan: Add Multi-Task + Dependency-Aware Dispatch to /orchestrate

- **Task**: 623 - Add multi-task + dependency-aware dispatch to /orchestrate
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/623_orchestrate_multi_task_dispatch/reports/01_multi-task-orchestrate.md
- **Artifacts**: plans/01_multi-task-orchestrate-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan adds multi-task argument support to the `/orchestrate` command with dependency-aware topological wave dispatch. Unlike `/research`, `/plan`, and `/implement` which run all tasks in pure parallel (since each operates on a single lifecycle phase), `/orchestrate` drives tasks through their entire lifecycle. This means inter-task dependencies must be respected: if task B depends on task A, B must wait for A to complete before launching. The implementation adds STAGE 0 parsing with single-task fallthrough, a MULTI-TASK DISPATCH section with Kahn's-algorithm wave construction, and consolidated output -- all within `orchestrate.md`. The `skill-orchestrate` SKILL.md remains single-task and is not modified.

### Research Integration

Key findings from the research report integrated into this plan:
- The multi-task dispatch pattern from `/research`, `/plan`, `/implement` (STAGE 0 + batch validation + parallel Skill dispatch + consolidated output) is reused with a wave-dispatch wrapper.
- The `dependencies` field in state.json is an array of integer task numbers (`"dependencies": [620]`), already in production use.
- Kahn's algorithm computes dependency waves; tasks within a wave execute in parallel, waves execute sequentially.
- Failed predecessors do NOT block dependent tasks in later waves (the orchestrate skill handles resume from any non-terminal state).
- The `skill-orchestrate` SKILL.md stays single-task; all multi-task coordination lives in `orchestrate.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Enable `/orchestrate N[,N-N] [prompt]` syntax for multi-task batch orchestration
- Implement dependency-aware wave dispatch using Kahn's algorithm on state.json dependencies
- Maintain zero-overhead single-task fallthrough when only one task is specified
- Produce consolidated output and batch commit for multi-task runs
- Document the orchestrate-specific wave dispatch pattern in multi-task-operations.md

**Non-Goals**:
- Modifying `skill-orchestrate/SKILL.md` (stays single-task)
- Adding `--team` flag support to `/orchestrate`
- Per-task focus prompts (single focus prompt applies to all tasks)
- Cross-batch dependency resolution (only intra-batch dependencies are considered for wave assignment)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent skill-orchestrate writes to state.json | M | L | Each skill writes to its own scoped task data; loop guard files use per-task paths -- no collision |
| Wave 1 tasks start before Wave 0 tasks fully commit state | M | L | skill-orchestrate reads live state.json status; Wave 0 tasks update their own status before terminating |
| Circular dependency in batch causes infinite loop | H | L | Kahn's algorithm detects empty ready-set with non-empty remaining-set and aborts with error |
| Focus prompt with special characters breaks shell quoting | M | L | Pass focus_prompt via Skill args string, not raw shell interpolation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update orchestrate.md with multi-task dispatch [COMPLETED]

**Goal**: Add STAGE 0 multi-task parsing, batch validation, dependency graph construction, topological wave dispatch, and consolidated output to the orchestrate command file.

**Tasks**:
- [x] Update the `## Arguments` section to document multi-task syntax: `$1` becomes task number(s) supporting single, comma-separated, and range formats *(completed)*
- [x] Update the `## Constraints` section: replace "Single task only: no multi-task, no `--team` flag in v1" with "Multi-task mode uses dependency-aware wave dispatch. `--team` flag not supported." *(completed)*
- [x] Update the frontmatter `argument-hint` from `TASK_NUMBER [PROMPT]` to `TASK_NUMBERS [PROMPT]` *(completed)*
- [x] Replace STAGE 0 body: use `parse-command-args.sh` with single-task fallthrough decision (if `len(TASK_NUMBERS) == 1` fall through to CHECKPOINT 1, else continue to MULTI-TASK DISPATCH) *(completed)*
- [x] Add `### MULTI-TASK DISPATCH` section after STAGE 0 with five steps:
  - Step 1: Batch Validation -- iterate tasks, check existence and non-terminal status, build `validated_tasks[]` and `skipped_tasks[]`
  - Step 2: Dependency Graph Construction -- for each validated task, read dependencies from state.json, restrict to intra-batch dependencies only
  - Step 3: Topological Wave Assignment -- Kahn's algorithm: repeatedly extract tasks with no remaining intra-batch deps, assign to waves, detect circular dependencies
  - Step 4: Wave Execution -- for each wave sequentially, dispatch all wave tasks in parallel via concurrent Skill tool calls to `skill-orchestrate`, collect results
  - Step 5: Batch Git Commit and Consolidated Output -- commit format adapted for orchestrate (shows lifecycle progression), status table with Succeeded/Failed/Skipped sections *(completed)*
- [x] Add "After consolidated output, STOP. Do not continue to CHECKPOINT 1." guard after the MULTI-TASK DISPATCH section *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/commands/orchestrate.md` - Primary target: add STAGE 0 parsing, MULTI-TASK DISPATCH section, update Arguments/Constraints/frontmatter

**Verification**:
- The file contains both single-task and multi-task code paths
- STAGE 0 uses `parse-command-args.sh` and has the single-task fallthrough decision
- MULTI-TASK DISPATCH section has all 5 steps (validation, graph, waves, execution, output)
- Kahn's algorithm pseudocode includes circular dependency detection
- Consolidated output format matches the pattern from multi-task-operations.md Section 9 adapted for orchestrate

---

### Phase 2: Add Section 13 to multi-task-operations.md [COMPLETED]

**Goal**: Document the orchestrate-specific wave dispatch pattern as a new section in the canonical multi-task operations pattern file.

**Tasks**:
- [x] Add `## 13. Orchestrate-Specific Behavior` section after the existing Section 12 *(completed)*
- [x] Document why `/orchestrate` needs wave-based dispatch instead of pure parallel (lifecycle vs single-phase) *(completed)*
- [x] Include the intra-batch dependency resolution algorithm description *(completed)*
- [x] Document failed predecessor handling: failed tasks do not block dependent tasks in later waves *(completed)*
- [x] Document the `N[,N-N]` syntax compatibility with focus prompt *(completed)*
- [x] Document that `--team` flag is not supported for `/orchestrate` *(completed)*
- [x] Add a comparison table: pure-parallel (research/plan/implement) vs wave-dispatch (orchestrate) *(completed)*
- [x] Update the "See Also" section at the bottom to cross-reference the orchestrate command *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/patterns/multi-task-operations.md` - Add Section 13 after Section 12, update See Also

**Verification**:
- Section 13 exists with title "Orchestrate-Specific Behavior"
- The section explains the wave dispatch rationale (lifecycle vs single-phase)
- The comparison table distinguishes pure-parallel from wave-dispatch
- Failed predecessor handling is documented
- See Also section includes orchestrate.md reference

---

### Phase 3: Update CLAUDE.md command table [COMPLETED]

**Goal**: Update the `/orchestrate` row in the CLAUDE.md command reference table to show the new multi-task argument syntax.

**Tasks**:
- [x] Update the `/orchestrate` command table row: change Usage from `/orchestrate N [prompt]` to `/orchestrate N[,N-N] [prompt]` *(completed)*
- [x] Update the Description from "Drive task autonomously through full lifecycle (no confirmation gates)" to "Drive task(s) autonomously through full lifecycle with dependency-aware wave dispatch" *(completed)*
- [x] Add `/orchestrate` to the "Multi-task syntax" paragraph that currently lists only `/research`, `/plan`, and `/implement`, noting that orchestrate uses dependency-aware dispatch rather than pure parallel *(completed)*

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/CLAUDE.md` - Update command table row and multi-task syntax paragraph

**Verification**:
- The command table shows `N[,N-N]` syntax for `/orchestrate`
- The description mentions dependency-aware wave dispatch
- The multi-task syntax paragraph includes `/orchestrate` with a note about dependency-aware dispatch

## Testing & Validation

- [x] Read the modified `orchestrate.md` and verify it contains both single-task fallthrough and multi-task dispatch paths *(completed)*
- [x] Verify the MULTI-TASK DISPATCH section includes all 5 steps with correct pseudocode *(completed)*
- [x] Verify Kahn's algorithm pseudocode handles: (a) no dependencies (all in wave 0), (b) linear chain (one task per wave), (c) diamond dependency pattern, (d) circular dependency detection *(completed)*
- [x] Read `multi-task-operations.md` and verify Section 13 exists with orchestrate-specific content *(completed)*
- [x] Read `CLAUDE.md` and verify the command table row and multi-task paragraph are updated *(completed)*
- [x] Verify no changes were made to `skill-orchestrate/SKILL.md` *(completed)*

## Artifacts & Outputs

- `specs/623_orchestrate_multi_task_dispatch/plans/01_multi-task-orchestrate-plan.md` (this plan)
- Modified `.claude/commands/orchestrate.md` (primary implementation target)
- Modified `.claude/context/patterns/multi-task-operations.md` (Section 13 addition)
- Modified `.claude/CLAUDE.md` (command table update)

## Rollback/Contingency

All three modified files are tracked in git. If implementation fails, revert the changes with `git checkout` on the three files. The `skill-orchestrate/SKILL.md` is not modified, so no rollback needed there. The changes are purely additive (new sections, updated text) with no destructive modifications to existing single-task flow.
