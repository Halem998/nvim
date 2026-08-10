# Implementation Plan: Task #765

- **Task**: 765 - Fix multi-task orchestration wave cycling and agent tracking
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/765_fix_mt_orchestration_wave_cycling/reports/01_mt-wave-cycling-research.md
- **Artifacts**: plans/01_mt-wave-cycling-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The MT (multi-task) orchestration mode in `skill-orchestrate/SKILL.md` dispatches tasks correctly for one lifecycle phase but never cycles back to advance tasks through subsequent phases (research -> plan -> implement). The root cause is that Stage MT-3 uses a `for wave_idx` loop that iterates through the pre-computed dependency wave list exactly once, treating waves as a one-pass traversal rather than as a dependency ordering that must be revisited on each lifecycle phase. The fix replaces this one-pass wave iterator with an outer `while [ cycle_count < MAX_CYCLES_MT ]` lifecycle-cycling loop that re-reads task statuses each iteration, builds an eligible-task list, dispatches the appropriate next phase for each task, and exits only when all tasks reach terminal state or the cycle cap is hit.

### Research Integration

The research report (01_mt-wave-cycling-research.md) identified four bugs and five proposed fixes:

1. **Bug 1 (Root Cause)**: Wave loop is a one-pass iterator, not a lifecycle driver -- the `for wave_idx` loop iterates the pre-computed wave list once and exits.
2. **Bug 2**: No lifecycle cycling mechanism comparable to single-task mode's `while [ cycle_count < MAX_CYCLES ]`.
3. **Bug 3**: Parallel Agent completion tracking is implicit-only -- the spec uses echo placeholders and three separate for-loops without explicit batching instructions.
4. **Bug 4**: Within-wave status staleness -- the wave structure encodes dependency order, not lifecycle phases.

All four bugs are addressed in this plan. The research also confirmed that Stage MT-4's phase-aware dispatch logic (grouping tasks into research/plan/implement arrays) is correct and needs only minor clarification, not structural changes.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It fixes a correctness bug in the orchestration infrastructure that is a prerequisite for reliable multi-task operations across all roadmap items.

## Goals & Non-Goals

**Goals**:
- Replace the one-pass `for wave_idx` loop in Stage MT-3 with a lifecycle-cycling `while` loop that drives tasks through all phases (research -> plan -> implement -> completed)
- Add all-terminal detection to exit the loop when every task reaches a terminal state
- Add a no-eligible-tasks circuit breaker to prevent infinite spinning when tasks are stuck
- Clarify parallel Agent dispatch instructions so all Agent calls for a batch are issued in a single message
- Update orchestrate-state-machine.md with MT mode documentation

**Non-Goals**:
- Changing the single-task state machine (Stages 3-5) -- it works correctly
- Modifying the wave/dependency computation in orchestrate.md -- waves correctly encode dependency ordering
- Adding pipelining (Wave 1 starting before Wave 0 fully completes) -- strict dependency gating is correct for now
- Changing Stage MT-4's phase grouping logic -- it is correct as written
- Modifying Stage MT-5's postflight -- it correctly reads multi-state results

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Infinite loop if tasks get stuck in non-terminal, non-dispatchable state | H | L | MAX_CYCLES_MT cap (already exists: task_count * 5, max 25) plus no-eligible-tasks circuit breaker |
| Stale status array causes double-dispatch of same phase | M | M | Re-read all statuses from state.json at top of each cycle iteration, not from in-memory cache |
| Wave dependency gate too strict, blocking eligible tasks | M | L | Use strict gate (predecessor must be in terminal state) matching existing intent; relaxation can be added later |
| Parallel Agent calls not issued in single message, causing sequential execution | L | M | Add explicit instruction in SKILL.md that all Agent calls for a dispatch batch must be in one message |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Replace Stage MT-3 Wave Loop with Lifecycle-Cycling Loop [COMPLETED]

**Goal**: Convert the one-pass `for wave_idx` iterator into a `while [ cycle_count < MAX_CYCLES_MT ]` outer loop that re-reads task statuses each iteration, builds eligible tasks based on dependency satisfaction and non-terminal status, and exits when all tasks are terminal or no eligible tasks remain.

**Tasks**:
- [x] Replace `for wave_idx in $(seq 0 $((wave_count - 1)))` block (lines ~819-868) with `while [ "$cycle_count" -lt "$MAX_CYCLES_MT" ]` outer loop *(completed)*
- [x] Add status refresh block at top of each iteration: re-read all task statuses from state.json into `current_statuses` array and update multi-state file *(completed)*
- [x] Add all-terminal detection: after refreshing statuses, check if every task is in a terminal state (completed, abandoned, expanded, or in failed_tasks); if so, break with success *(completed)*
- [x] Build `eligible_tasks` list using dependency-aware filtering: a task is eligible if (a) it is not in terminal state, (b) it is not in an in-flight state (researching, planning), and (c) all its predecessors (from `dependency_graph_json`) are in terminal state (completed or failed) *(completed)*
- [x] Add no-eligible-tasks circuit breaker: if `eligible_tasks` is empty but not all tasks are terminal, log warning listing stuck tasks and break with partial status *(completed)*
- [x] Pass `eligible_tasks` to Stage MT-4 dispatch (replacing the wave-filtered `active_tasks` array) *(completed)*
- [x] Move the cycle_count increment and MAX_CYCLES guard (lines ~1087-1100) into the while loop's bottom, consistent with single-task loop structure *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage MT-3 rewrite (lines ~815-868, ~1086-1100)

**Verification**:
- The `while` loop structure mirrors single-task Stage 3's pattern
- All-terminal detection is present and breaks the loop
- No-eligible-tasks circuit breaker is present
- Dependency graph is consulted for predecessor completion
- cycle_count increments at loop bottom, guard checks at loop top

---

### Phase 2: Clarify Parallel Agent Dispatch Instructions in Stage MT-4 [COMPLETED]

**Goal**: Add explicit instructions to Stage MT-4 that all Agent tool calls for a dispatch batch (research + plan + implement groups) must be issued in a single orchestrator message to execute concurrently, and that handoff reading occurs only after all parallel agents complete.

**Tasks**:
- [x] Add a dispatch batching instruction block before the three dispatch for-loops (research, plan, implement) in Stage MT-4: "All Agent tool calls for this cycle's dispatch batch MUST be issued in a single message with multiple tool-use content blocks. Do NOT sequentialize across the three dispatch groups within the same cycle iteration." *(completed)*
- [x] Add a parallel completion note after the three dispatch loops and before the handoff-reading loop: "After all parallel Agent tool calls complete (Claude Code processes all Agent calls in a single message before returning control), proceed to read handoffs for every dispatched task." *(completed)*
- [x] Update the max concurrency comment from "concurrent, max 4" to "concurrent, all in one message -- Claude Code handles parallelism automatically when multiple Agent calls are in one message" *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage MT-4 dispatch section (lines ~875-996)

**Verification**:
- Explicit single-message batching instruction is present
- Handoff reading is explicitly sequenced after all Agent completions
- No ambiguity about how parallel dispatch works

---

### Phase 3: Fix Multi-State Status Update Bug in MT-4 Postflight [COMPLETED]

**Goal**: Fix the jq bug in Stage MT-4's postflight where failed task status is set to `$num` (the task number) instead of the actual status string, and ensure the multi-state file's `current_statuses` is consistently updated after each cycle.

**Tasks**:
- [x] Fix the failed-task status update (line ~1076): change `.current_statuses[$num | tostring] = $num` to `.current_statuses[$num | tostring] = "failed"` (or use the actual `$dispatch_status`) *(completed: uses $dispatch_status via --arg status)*
- [x] Add explicit status variable to the failed-task jq command using `--arg status "$dispatch_status"` and `.current_statuses[$num | tostring] = $status` *(completed)*
- [x] Verify the postflight loop correctly handles all dispatch_status values: researched, planned, implemented, partial, failed, blocked *(completed: case statement covers researched/planned/implemented; else clause uses fresh_status; failed/blocked uses $dispatch_status)*

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage MT-4 postflight section (lines ~1062-1084)

**Verification**:
- No jq assignments use `$num` where a status string is expected
- All `current_statuses` updates use the actual status string
- The failed_tasks array and current_statuses are consistent

---

### Phase 4: Update Architecture Documentation [COMPLETED]

**Goal**: Add an MT mode section to `orchestrate-state-machine.md` documenting the lifecycle-cycling loop, dependency gating, and parallel dispatch model. This fills the documentation gap identified in the research report.

**Tasks**:
- [x] Add `## MT Mode: Multi-Task Orchestration` section to orchestrate-state-machine.md after the single-task "Example Flows" section *(completed)*
- [x] Include an ASCII state diagram showing the lifecycle-cycling loop: outer while loop -> refresh statuses -> build eligible tasks -> dependency gate -> phase-aware dispatch -> read handoffs -> postflight -> cycle_count++ -> loop *(completed)*
- [x] Document the dependency gating model: tasks proceed through lifecycle phases independently; a task is eligible when its dependency-graph predecessors are all in terminal state *(completed)*
- [x] Document the all-terminal and no-eligible-tasks exit conditions *(completed)*
- [x] Add an MT example flow showing 2 independent tasks going through research -> plan -> implement across 6 cycles *(completed: shows 4 cycles — 3 dispatch cycles + 1 all-terminal check)*

**Timing**: 45 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/docs/architecture/orchestrate-state-machine.md` - Add MT mode section

**Verification**:
- MT mode section exists with ASCII diagram
- Dependency gating is documented
- Exit conditions are documented
- Example flow shows lifecycle cycling across multiple cycles

## Testing & Validation

- [x] Read the modified SKILL.md and verify the `while` loop structure matches single-task Stage 3's pattern *(verified: while loop at line 822, cycle_count init at 820, increment at 966)*
- [x] Verify all-terminal detection logic: every task in terminal state -> break *(verified: all_terminal flag set to true at cycle start, cleared to false for any non-terminal non-failed task, breaks at line 859)*
- [x] Verify no-eligible-tasks circuit breaker: empty eligible_tasks + non-terminal tasks -> break with warning *(verified: lines 938-956)*
- [x] Verify dependency gating: task only eligible when all predecessors in terminal state *(verified: predecessor_pending logic at lines 900-930)*
- [x] Verify the jq bug fix: no `.current_statuses[$num | tostring] = $num` assignments remain *(verified: grep found 0 matches)*
- [x] Verify parallel dispatch instruction is explicit and unambiguous *(verified: Batching rule and Completion sequencing paragraphs in Stage MT-4 header)*
- [x] Verify orchestrate-state-machine.md has MT mode documentation *(verified: all 8 required elements present)*
- [x] Dry-run mental walkthrough: 3 independent tasks (Wave 0) starting as not_started should cycle through research (cycle 1) -> plan (cycle 2) -> implement (cycle 3) and reach completed *(verified: logic traces correctly through 3 dispatch cycles + 1 all-terminal exit)*

## Artifacts & Outputs

- `specs/765_fix_mt_orchestration_wave_cycling/plans/01_mt-wave-cycling-plan.md` (this file)
- Modified `.claude/skills/skill-orchestrate/SKILL.md` (Stages MT-3, MT-4)
- Modified `.claude/docs/architecture/orchestrate-state-machine.md` (MT mode section)

## Rollback/Contingency

The changes are confined to two files: `skill-orchestrate/SKILL.md` (spec changes) and `orchestrate-state-machine.md` (documentation). Both are version-controlled. To rollback:
- `git checkout HEAD -- .claude/skills/skill-orchestrate/SKILL.md .claude/docs/architecture/orchestrate-state-machine.md`
- No runtime state is affected since these are specification files, not executable scripts
