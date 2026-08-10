# Implementation Plan: Task #591

- **Task**: 591 - Research Claude Code 2026 orchestration best practices
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md
- **Artifacts**: plans/01_orchestration-research.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 591 is a foundational reshaping task: research is complete, and the implementation phase distills findings into concrete changes across the downstream task suite (592-599). The work involves revising task descriptions, reordering dependencies based on the user's directive to elevate task 598 and make /orchestrate a fire-and-forget loop, creating seed research reports for each downstream task, and resolving tasks 500 and 501 (subsumed by this refactoring). Done when: all 8 downstream tasks have revised descriptions with correct dependencies, each has a seed research report, tasks 500 and 501 are abandoned with successor references, and state.json/TODO.md are consistent.

### Research Integration

Key findings integrated from the 4-teammate research report:

1. **Fork decision matrix**: Forks for same-turn re-dispatch (blocker escalation, team mode); fresh subagents for sequential phases. `dispatch_agent()` abstraction encapsulates this.
2. **User override on /orchestrate**: Fire-and-forget autonomous loop (not confirmation gates). Shares blocker escalation infrastructure with human-in-the-loop commands.
3. **Progressive disclosure**: 4-tier context loading with budget caps. Task 598 must be elevated to Layer 4 (before 594) because it informs what the shared base needs to support.
4. **Safe extraction targets**: `parse_task_args()`, unified `postflight-workflow.sh`, shared GATE templates (~535 lines recoverable).
5. **Extension lifecycle hooks**: Replace full skill duplication with manifest hooks.
6. **Structured handoff objects**: 200-400 tokens vs 2000-5000 token raw artifact injection.
7. **Nested loop resolution**: Orchestrator outer loop exclusive with implementer inner loop.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Revise descriptions and dependencies for tasks 592-599 to reflect research findings and user direction
- Elevate task 598 to Layer 4 (depends on 592 only); make 594, 595, 596 depend on 598
- Update /orchestrate (596) description to specify fire-and-forget autonomous loop, not confirmation gates
- Create seed research reports for all 8 downstream tasks distilling relevant teammate findings
- Abandon tasks 500 and 501 with successor references pointing to tasks 594 and 596 respectively
- Regenerate Task Order section in TODO.md

**Non-Goals**:
- Implementing any of the architectural changes (that is tasks 592-599)
- Modifying any commands, skills, or agents
- Creating full research reports (seed reports are distilled extracts, not comprehensive research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dependency reordering creates circular dependencies | H | L | Validate DAG with topological sort before writing |
| Seed reports inject opinions not supported by research | M | L | Only extract verbatim findings; cite teammate sources |
| Abandoning tasks 500/501 loses valuable research | M | M | Reference their artifacts in successor task descriptions; seed reports include their findings |
| TODO.md Task Order regeneration conflicts with manual edits | L | L | Use generate-task-order.sh for canonical regeneration |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Revise task descriptions and dependencies [COMPLETED]

**Goal**: Update state.json and TODO.md with revised descriptions, dependencies, and ordering for tasks 592-599 that incorporate research findings and user direction.

**Tasks**:
- [x] Read current state.json to capture baseline for all 8 tasks *(completed)*
- [x] Revise task 592 description: add fork decision matrix, dispatch_agent() abstraction, handoff protocol spec, nested loop resolution as explicit design deliverables *(completed)*
- [x] Revise task 593 description: add unified postflight-workflow.sh, shared GATE IN/OUT templates, baseline token measurement methodology as deliverables *(completed)*
- [x] Revise task 594 description: add dependency on 598 (progressive disclosure informs shared base); note extension lifecycle hooks as design goal; reference task 500's research findings on fork incompatibility with named routing *(completed)*
- [x] Revise task 595 description: add dependency on 598; remove "add progressive disclosure" (now handled by 598); focus on command refactoring using shared utilities *(completed)*
- [x] Revise task 596 description: update to fire-and-forget autonomous loop (not confirmation gates); add dependency on 598; add blocker escalation as core capability; reference nested loop resolution pattern; note subsumption of task 501 *(completed)*
- [x] Revise task 597 description: keep dependency on 593 only; add memory harvest automation to /todo decomposition scope *(completed)*
- [x] Revise task 598 description: change dependencies from [595, 596] to [592]; this is now Layer 4, informing what the shared base needs *(completed)*
- [x] Revise task 599 description: update dependencies to [594, 595, 596, 597, 598] to reflect new ordering *(completed)*
- [x] Update all 8 entries in state.json with revised descriptions and dependencies *(completed)*
- [x] Update all 8 entries in TODO.md to match state.json *(completed)*
- [x] Regenerate Task Order section using generate-task-order.sh --update-todo *(deviation: altered — manually updated Task Order due to script bug: cc_union exits 1 under set -e when nodes are same component)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `specs/state.json` - Update descriptions and dependencies for tasks 592-599
- `specs/TODO.md` - Update task entries and regenerate Task Order

**Verification**:
- Dependencies form a valid DAG (no cycles)
- Task 598 depends only on [592], not [595, 596]
- Tasks 594, 595, 596 all depend on 598
- Task 596 description specifies fire-and-forget loop, not confirmation gates
- state.json and TODO.md are consistent
- New dependency wave order: 591 -> 592 -> [593, 598] -> [594, 597] -> [595, 596] -> 599

---

### Phase 2: Create seed research reports for downstream tasks [COMPLETED]

**Goal**: Create a seed research report in each downstream task's reports/ directory that distills the specific findings from the 4-teammate research relevant to that task.

**Tasks**:
- [x] Create reports/ directories for tasks 592-599 *(completed)*
- [x] Create seed report for task 592: extract architecture design findings -- fork decision matrix, dispatch_agent() pattern, handoff protocol, nested loop resolution, extension integration points *(completed)*
- [x] Create seed report for task 593: extract safe extraction targets -- parse_task_args() (90L), flag parsing (75L), unified postflight (130L), GATE templates (240L); baseline measurement methodology *(completed)*
- [x] Create seed report for task 594: extract skill duplication analysis -- intentional vs mechanical duplication, context-collection divergence warning, shared base risks, extension lifecycle hooks pattern *(completed)*
- [x] Create seed report for task 595: extract command deduplication targets -- line counts, progressive disclosure interaction with commands, command-level vs skill-level responsibilities *(completed)*
- [x] Create seed report for task 596: extract /orchestrate design -- fire-and-forget loop pattern, state machine design, blocker escalation flow, fork usage for same-turn re-dispatch, nested loop exclusivity, subsumption of task 501 *(completed)*
- [x] Create seed report for task 597: extract /task, /revise, /todo, /review findings -- memory harvest gap, /todo decomposition targets, component extraction candidates *(completed)*
- [x] Create seed report for task 598: extract progressive disclosure findings -- 4-tier context loading, budget caps by agent type, index entry audit approach, load_when tier system design *(completed)*
- [x] Create seed report for task 599: extract documentation update scope -- extension compatibility gates, manifest schema changes, CLAUDE.md regeneration requirements *(completed)*
- [x] Update state.json artifact entries for tasks 592-599 to reference seed reports *(completed)*
- [x] Update TODO.md task entries to reference seed reports *(completed)*
- [x] Update next_artifact_number for tasks 592-599 in state.json (set to 2 after creating 01_ reports) *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `specs/592_design_unified_workflow_architecture/reports/01_seed-research.md` - Architecture design seed
- `specs/593_extract_shared_workflow_utilities/reports/01_seed-research.md` - Shared utilities seed
- `specs/594_refactor_workflow_skills_shared_base/reports/01_seed-research.md` - Skills refactor seed
- `specs/595_refactor_research_plan_implement_commands/reports/01_seed-research.md` - Commands refactor seed
- `specs/596_create_orchestrate_command_skill_agent/reports/01_seed-research.md` - Orchestrate seed
- `specs/597_refactor_task_revise_todo_review/reports/01_seed-research.md` - Secondary commands seed
- `specs/598_progressive_disclosure_context_system/reports/01_seed-research.md` - Progressive disclosure seed
- `specs/599_update_claudemd_extension_documentation/reports/01_seed-research.md` - Documentation seed
- `specs/state.json` - Add artifact entries and update next_artifact_number

**Verification**:
- Each of the 8 reports/ directories exists and contains 01_seed-research.md
- Each seed report cites specific teammate findings (A, B, C, D) and section numbers from the source report
- state.json artifact entries for each task reference the seed report
- next_artifact_number is 2 for all 8 tasks

---

### Phase 3: Resolve tasks 500 and 501 [COMPLETED]

**Goal**: Abandon tasks 500 and 501 with notes pointing to their successor tasks (594 and 596 respectively), preserving their research artifacts for reference.

**Tasks**:
- [x] Update task 500 status to "abandoned" in state.json with completion note: "Subsumed by task 594 (refactor workflow skills). Fork research findings integrated into task 591 team research and task 594 seed report. Key finding: fork cache sharing is fundamentally incompatible with named agent routing -- use forks only for same-turn re-dispatch." *(completed)*
- [x] Update task 501 status to "abandoned" in state.json with completion note: "Subsumed by task 596 (create /orchestrate). Team-mode fork optimization findings integrated into task 591 team research and task 596 seed report." *(completed)*
- [x] Update task 500 status marker in TODO.md to [ABANDONED] *(completed)*
- [x] Update task 501 status marker in TODO.md to [ABANDONED] *(completed)*
- [x] Remove tasks 500 and 501 from Task Order section (abandoned tasks should not appear) *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `specs/state.json` - Update status and add abandonment notes for tasks 500, 501
- `specs/TODO.md` - Update status markers for tasks 500, 501

**Verification**:
- Tasks 500 and 501 show [ABANDONED] in TODO.md
- state.json has status "abandoned" with descriptive completion notes for both
- Task Order section no longer includes 500 or 501
- No broken dependency references (no other active tasks depend on 500 or 501)

---

### Phase 4: Final validation and commit [COMPLETED]

**Goal**: Verify consistency across all modified files and commit changes.

**Tasks**:
- [x] Verify state.json is valid JSON (parse with jq) *(completed)*
- [x] Verify all task dependencies in state.json form a valid DAG (no circular references) *(completed)*
- [x] Verify TODO.md entries match state.json for tasks 500, 501, 592-599 *(completed)*
- [x] Verify all 8 seed reports exist and are non-empty *(completed)*
- [x] Verify Task Order section reflects new dependency ordering *(completed)*
- [x] Verify the revised dependency wave structure: Wave 1: [591], Wave 2: [592], Wave 3: [593, 598], Wave 4: [594, 597], Wave 5: [595, 596], Wave 6: [599] *(completed)*
- [x] Git commit with message "task 591: revise downstream task suite and create seed reports" *(completed)*

**Timing**: 15 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (validation only, plus git commit of all prior changes)

**Verification**:
- `jq . specs/state.json` succeeds without error
- All 8 seed reports are readable
- Git commit includes all modified files
- No uncommitted changes remain after commit

## Testing & Validation

- [ ] `jq . specs/state.json` parses without error
- [ ] Dependency graph has no cycles (topological sort succeeds)
- [ ] Task 598 depends on [592], not [595, 596]
- [ ] Tasks 594, 595, 596 each list 598 in their dependencies
- [ ] Task 596 description contains "fire-and-forget" or "autonomous loop"
- [ ] Task 596 description does NOT contain "confirmation gates" as the primary mode
- [ ] Tasks 500, 501 are [ABANDONED] in both state.json and TODO.md
- [ ] 8 seed reports exist at specs/{NNN}_*/reports/01_seed-research.md for tasks 592-599
- [ ] Each seed report references the source team research report
- [ ] Task Order section matches revised dependency structure

## Artifacts & Outputs

- `specs/591_research_claude_code_orchestration_practices/plans/01_orchestration-research.md` (this plan)
- `specs/state.json` (revised task entries for 500, 501, 592-599)
- `specs/TODO.md` (revised task entries and Task Order)
- `specs/592_design_unified_workflow_architecture/reports/01_seed-research.md`
- `specs/593_extract_shared_workflow_utilities/reports/01_seed-research.md`
- `specs/594_refactor_workflow_skills_shared_base/reports/01_seed-research.md`
- `specs/595_refactor_research_plan_implement_commands/reports/01_seed-research.md`
- `specs/596_create_orchestrate_command_skill_agent/reports/01_seed-research.md`
- `specs/597_refactor_task_revise_todo_review/reports/01_seed-research.md`
- `specs/598_progressive_disclosure_context_system/reports/01_seed-research.md`
- `specs/599_update_claudemd_extension_documentation/reports/01_seed-research.md`

## Rollback/Contingency

All changes are to task metadata and documentation only. Rollback is straightforward:
- `git checkout HEAD -- specs/state.json specs/TODO.md` to restore pre-revision state
- Delete seed reports: `rm -rf specs/59{2..9}_*/reports/`
- Revert task 500/501 status if needed
- No code changes are made in this task, so no functional rollback is needed
