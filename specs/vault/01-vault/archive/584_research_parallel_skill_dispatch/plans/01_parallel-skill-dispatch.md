# Implementation Plan: Parallel Skill Dispatch for Multi-Task Commands

- **Task**: 584 - research_parallel_skill_dispatch
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/584_research_parallel_skill_dispatch/reports/01_parallel-skill-dispatch.md
- **Artifacts**: plans/01_parallel-skill-dispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace parallel Agent tool calls with parallel Skill tool calls in the multi-task dispatch path of `/research`, `/plan`, and `/implement`. The research report (task 584) identified an architecture mismatch: multi-task-operations.md Section 6 describes a "Batch Skill Dispatch (Option B)" pattern that was never implemented, while Section 12 and the actual command files use inline orchestrator loops with direct Agent calls. This plan resolves the conflict by updating all four files to use parallel Skill invocations consistently, and addresses the three design challenges identified in the research: state.json race conditions, skill return value collection, and batch commit conflicts.

Definition of done: All four files describe parallel Skill (not Agent) dispatch for multi-task mode, the Section 6 vs Section 12 conflict is resolved, and the batch commit and result collection patterns account for skill postflight behavior.

### Research Integration

Research report `reports/01_parallel-skill-dispatch.md` (task 584) provided:
- Exact line numbers and content for all four files requiring changes
- Confirmation that Skill tool has no documented constraint against parallel invocation
- Analysis of the Section 6 vs Section 12 architecture mismatch
- State.json race condition scenario and mitigation options
- Skill return format analysis (text summaries, not JSON)
- Batch commit double-commit analysis and resolution options

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is infrastructure work that improves multi-task dispatch correctness.

## Goals & Non-Goals

**Goals**:
- Update multi-task-operations.md Section 6 to describe parallel Skill invocation (removing "Option B" batch-skill framing and resolving the Section 12 conflict)
- Update Step 3 in research.md, plan.md, and implement.md to invoke Skills in parallel instead of Agent tool calls
- Document how skill postflight interacts with batch mode (per-skill commits accepted, batch commit is cleanup)
- Add a note about state.json concurrent write safety (scoped writes are sufficient; no batch_mode flag needed in this iteration)

**Non-Goals**:
- Implementing a `batch_mode` flag for skills to skip their own postflight (deferred to future task if races are observed in practice)
- Implementing a structured text return prefix convention for skills (deferred; `.return-meta.json` files already provide structured data)
- Changing the single-task flow (explicitly out of scope; single-task path is untouched)
- Changing team-mode dispatch (team skills already use Agent parallel calls internally; this change is at the orchestrator level only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parallel Skill calls not supported by runtime | H | L | Document the pattern as "invoke all in a single message"; if runtime serializes, behavior is still correct (just sequential). No functional breakage. |
| State.json read-modify-write race during parallel skill postflight | M | M | Accept as known limitation; scoped jq writes reduce risk. Document that consolidated state update is a future enhancement if races are observed. |
| Double-commit from per-skill postflight + batch commit | L | H | Accept idempotent behavior: batch commit at Step 4 uses `git add -A` and may produce an empty commit (which fails gracefully). Document this explicitly. |
| Section 6 rewrite introduces inconsistency with other multi-task-operations sections | M | L | Phase 1 rewrites Section 6 and verifies consistency with Sections 8, 10, 12 before proceeding to command file changes. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases are sequential because Phase 1 establishes the canonical architecture description that Phases 2-3 reference, and Phase 4 validates the complete set of changes.

### Phase 1: Update multi-task-operations.md Section 6 and Resolve Section 12 Conflict [COMPLETED]

**Goal**: Rewrite Section 6 to describe parallel Skill invocation from the orchestrator loop (not a separate batch skill), resolving the conflict with Section 12. Update Sections 8 and 10 to reflect the new dispatch model.

**Tasks**:
- [x] Rewrite Section 6 heading from "Parallel Agent Spawning" to "Parallel Skill Dispatch" *(completed)*
- [x] Remove the "Architecture: Batch Skill Dispatch (Option B)" framing and the `Command -> Skill(batch dispatch) -> [Task(agent, task 7)...]` diagram *(completed)*
- [x] Replace with orchestrator-loop architecture: `Command -> [Skill(skill-researcher, task 7), Skill(skill-planner, task 22), ...]` showing parallel Skill tool calls *(completed)*
- [x] Update the "Spawning Pattern" subsection to show Skill tool invocations instead of Agent tool invocations, with routing per task_type *(completed)*
- [x] Update the "Result Collection" subsection to describe how skill text returns are collected (each Skill returns brief text; the orchestrator reads `.return-meta.json` files for structured data if needed) *(completed)*
- [x] Update Section 8 (Batch Git Commit): Add a note that per-skill postflight may produce individual commits before the batch commit; the batch commit is a cleanup/consolidation step that may be empty *(completed)*
- [x] Update Section 10 (Concurrent State Safety): Replace the "batch skill collects all results" mitigation with acknowledgment that per-skill postflight writes are scoped by project_number and are sufficient for most cases; a future consolidated-write enhancement can be added if races are observed *(completed)*
- [x] Verify Section 12 now aligns with the rewritten Section 6 (both describe orchestrator-loop with parallel Skill calls) *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/multi-task-operations.md` - Sections 6, 8, 10, 12

**Verification**:
- Section 6 describes parallel Skill tool calls from the orchestrator loop
- Section 12 description is consistent with Section 6
- No references to "Option B" or "batch skill" remain in the document
- The spawning pattern shows `Skill` tool, not `Agent` tool

---

### Phase 2: Update Command File Step 3 Sections (research.md, plan.md, implement.md) [COMPLETED]

**Goal**: Replace "parallel Agent tool calls" with "parallel Skill tool calls" in the MULTI-TASK DISPATCH Step 3 of all three command files. Align the dispatch description with the updated multi-task-operations.md Section 6.

**Tasks**:
- [x] **research.md** (lines ~158-166): Replace Step 3 dispatch description *(completed)*
  - Change "Spawn one agent per task via parallel Agent tool calls" to "Invoke the appropriate research skill per task via parallel Skill tool calls"
  - Update the numbered steps to: (1) extract task_type, (2) route to skill, (3) invoke all skills in a single message, (4) each skill runs full lifecycle (preflight, agent delegation, postflight), (5) collect text results
  - Remove or update the "Note: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill" to say dispatch is via parallel Skill calls from the orchestrator loop
- [x] **plan.md** (lines ~163-174): Same changes as research.md but for planning skills *(completed)*
  - Change "parallel Agent tool calls" to "parallel Skill tool calls"
  - Update dispatch steps to route to planner skills
  - Update the note about orchestrator loop
- [x] **implement.md** (lines ~178-188): Same changes as research.md but for implementation skills *(completed)*
  - Change "parallel Agent tool calls" to "parallel Skill tool calls"
  - Update dispatch steps to route to implementation skills
  - Update the note about orchestrator loop
- [x] Update Step 4 (Batch Git Commit) in all three files to add a note: "Per-skill postflight may have already committed individual task changes. This batch commit captures any remaining unstaged changes and may be empty." *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/research.md` - MULTI-TASK DISPATCH Step 3, Step 4
- `.claude/commands/plan.md` - MULTI-TASK DISPATCH Step 3, Step 4
- `.claude/commands/implement.md` - MULTI-TASK DISPATCH Step 3, Step 4

**Verification**:
- All three files use "parallel Skill tool calls" (not "Agent tool calls") in Step 3
- The routing logic references skills (`skill-researcher`, `skill-planner`, `skill-implementer`) per task_type
- Step 4 acknowledges per-skill commits
- Single-task flow (CHECKPOINT 1 onward) is completely unchanged

---

### Phase 3: Update Skill Lifecycle and Cross-References [COMPLETED]

**Goal**: Update skill-lifecycle.md and any cross-references to reflect that skills may now be invoked in parallel from the orchestrator for multi-task dispatch.

**Tasks**:
- [x] Add a "Parallel Invocation" subsection to skill-lifecycle.md documenting that workflow commands may invoke multiple skills in a single message for multi-task dispatch *(completed)*
- [x] Note that each skill instance runs independently with its own preflight, agent delegation, and postflight *(completed)*
- [x] Note the concurrent state.json write consideration (scoped by project_number, acceptable risk) *(completed)*
- [x] Review multi-task-operations.md "See Also" section to ensure cross-references are current *(completed)*
- [x] Verify that CLAUDE.md multi-task syntax documentation does not reference "Agent" dispatch *(completed: updated to "dispatched to the appropriate skill in parallel")*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/context/patterns/skill-lifecycle.md` - Add parallel invocation subsection
- `.claude/context/patterns/multi-task-operations.md` - Verify cross-references

**Verification**:
- skill-lifecycle.md documents parallel invocation pattern
- Cross-references between multi-task-operations.md and skill-lifecycle.md are bidirectional
- No stale references to "parallel Agent dispatch" remain in context files

---

### Phase 4: Validation and Consistency Audit [COMPLETED]

**Goal**: Verify all changes are internally consistent, grep for stale references, and confirm the single-task flow is untouched.

**Tasks**:
- [x] Grep all `.claude/` files for "parallel Agent tool calls" and "parallel Agent" to find any remaining stale references *(completed: zero matches)*
- [x] Grep for "batch skill" and "Option B" to confirm removal *(completed: zero matches in multi-task-operations.md; remaining "Option B" references are in unrelated lean/present extension files)*
- [x] Read the single-task flow sections of research.md, plan.md, and implement.md to confirm they are unchanged *(completed: CHECKPOINT 1, STAGE 2, CHECKPOINT 2, CHECKPOINT 3 sections verified intact)*
- [x] Verify multi-task-operations.md Section 6, 8, 10, 12 are mutually consistent *(completed: all describe orchestrator-loop with parallel Skill calls)*
- [x] Verify each command file's Step 3 is consistent with multi-task-operations.md Section 6 *(completed: all three use "parallel Skill tool calls")*

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- No files modified (audit only; fixes applied inline if issues found)

**Verification**:
- Zero grep matches for "parallel Agent tool calls" in context/patterns/ and commands/
- Zero grep matches for "Option B" or "batch skill" in multi-task-operations.md
- Single-task checkpoints (CHECKPOINT 1, STAGE 2, etc.) in all three command files match pre-change content

## Testing & Validation

- [ ] Grep `.claude/context/patterns/multi-task-operations.md` for "parallel Agent" -- expect zero matches
- [ ] Grep `.claude/context/patterns/multi-task-operations.md` for "Option B" -- expect zero matches
- [ ] Grep `.claude/commands/research.md` for "parallel Agent tool calls" -- expect zero matches
- [ ] Grep `.claude/commands/plan.md` for "parallel Agent tool calls" -- expect zero matches
- [ ] Grep `.claude/commands/implement.md` for "parallel Agent tool calls" -- expect zero matches
- [ ] Verify `.claude/commands/research.md` CHECKPOINT 1 section is unchanged (diff check)
- [ ] Verify `.claude/commands/plan.md` CHECKPOINT 1 section is unchanged (diff check)
- [ ] Verify `.claude/commands/implement.md` CHECKPOINT 1 section is unchanged (diff check)
- [ ] Read multi-task-operations.md Sections 6 and 12 and confirm they describe the same architecture

## Artifacts & Outputs

- `specs/584_research_parallel_skill_dispatch/plans/01_parallel-skill-dispatch.md` (this plan)
- Modified files:
  - `.claude/context/patterns/multi-task-operations.md` (Sections 6, 8, 10, 12)
  - `.claude/commands/research.md` (Step 3, Step 4)
  - `.claude/commands/plan.md` (Step 3, Step 4)
  - `.claude/commands/implement.md` (Step 3, Step 4)
  - `.claude/context/patterns/skill-lifecycle.md` (new subsection)

## Rollback/Contingency

All changes are to documentation/architecture files in `.claude/`. If the parallel Skill dispatch pattern causes issues:
1. Revert the commits for this task via `git revert`
2. The single-task flow is untouched, so single-task operations are never affected
3. Multi-task operations would fall back to the previous parallel Agent dispatch description
4. No runtime code is changed; these are instruction files that guide agent behavior
