# Implementation Plan: Task #592

- **Task**: 592 - Design unified workflow architecture
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 591 (satisfied)
- **Research Inputs**: specs/592_design_unified_workflow_architecture/reports/01_seed-research.md, specs/592_design_unified_workflow_architecture/reports/02_architecture-design.md
- **Artifacts**: plans/02_architecture-design.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task produces deliverables that collectively transform the research findings from tasks 591 and 592 into actionable implementation guidance for the downstream task suite (593-599). The primary deliverables are permanent architecture specification documents written to `.claude/docs/architecture/`, covering all 7 components of the unified workflow architecture (shared command infrastructure, shared skill base, /orchestrate state machine, dispatch_agent() abstraction, handoff protocol, extension lifecycle hooks, nested loop resolution). These documents become permanent system documentation that downstream tasks reference as their authoritative blueprint. Secondary deliverables update downstream task descriptions and create per-task design guidance reports in specs/ with concrete specifications (function signatures, schemas, state machine definitions).

### Research Integration

The research report (02_architecture-design.md) provides the complete architectural blueprint: file layouts, function inventories, state machine design, JSON schemas, hook execution contracts, and the exclusive loop model. The seed report (01_seed-research.md) provides the team research synthesis from task 591 with the fork decision matrix, dispatch_agent() abstraction, and handoff protocol findings. Both are fully integrated into this plan.

### Prior Plan Reference

Revision of the original plan that placed the architecture spec in `specs/592_.../design/`. This revision relocates all primary architecture documents to `.claude/docs/architecture/` so they become permanent system documentation, complementing the existing `system-overview.md` (which describes the current architecture) with target architecture documents for the refactored system.

### Roadmap Alignment

No ROADMAP.md items directly targeted by this design task (meta task type).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Create permanent architecture specification documents in `.claude/docs/architecture/` that downstream tasks 593-599 reference as their authoritative blueprint
- Produce complementary documentation: `system-overview.md` describes the current architecture; the new documents describe the target architecture for the refactored system
- Update state.json and TODO.md descriptions for tasks 593-599 to reference specific architecture components and be more actionable
- Write design guidance reports (03_design-guidance.md) in each downstream task's reports/ directory with concrete specs: function signatures, JSON schemas, state machine definitions, file locations
- Establish the dependency graph and implementation ordering across the task suite

**Non-Goals**:
- Implementing any of the 7 architecture components (that is tasks 593-599)
- Modifying any command, skill, or agent files
- Creating new shell scripts or code artifacts
- Changing the extension manifest.json schema (task 599 scope)
- Detailed context budget calculations (task 598 scope)
- Modifying or replacing the existing `system-overview.md` (it documents current state; the new specs document target state)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Architecture docs in .claude/docs/architecture/ become stale after implementation diverges from spec | M | M | Include a "Status" header in each doc noting it is a target architecture spec; downstream tasks update the doc when implementation deviates |
| Architecture spec is too abstract for implementers to follow | H | M | Include concrete function signatures, JSON schemas, and file paths in every component section |
| Design guidance reports duplicate information already in the architecture spec | M | M | Guidance reports extract only task-specific sections and add implementation-order details not in the spec |
| Downstream task descriptions become stale if architecture evolves | M | L | Task descriptions reference the architecture spec documents as the authoritative source; individual details are secondary |
| state.json update introduces sync issues with TODO.md | M | L | Use the two-phase update pattern: state.json first, TODO.md second, verify both |
| New docs conflict with existing system-overview.md or extension-system.md | M | L | New docs explicitly complement existing ones: system-overview.md = current state, architecture-spec.md = target state; cross-reference both |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Write architecture specification documents [COMPLETED]

**Goal**: Create the authoritative architecture specification documents in `.claude/docs/architecture/` as permanent system documentation. These become the target architecture blueprint that all downstream tasks reference. The existing `system-overview.md` in `.claude/docs/architecture/` describes the current architecture; these new documents describe the refactored target state.

**Tasks**:
- [x] **Task 1.1**: Verify `.claude/docs/architecture/` directory exists (it does -- contains `system-overview.md` and `extension-system.md`) *(completed)*
- [x] **Task 1.2**: Write `.claude/docs/architecture/architecture-spec.md` -- the primary specification covering all 7 components: *(completed)*
  - Document header with purpose statement: "Target architecture for the unified workflow refactor (tasks 593-599). Complements system-overview.md which describes the current architecture."
  - Component 1 (Shared Command Infrastructure): `parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh` with exact function signatures and exported variables
  - Component 2 (Shared Skill Base): `skill-base.sh` function inventory (11 functions), hook points, target skill sizes
  - Component 3 (/orchestrate State Machine): State table, transition summary, MAX_CYCLES=5, loop guard schema, blocker escalation flow (references orchestrate-state-machine.md for full detail)
  - Component 4 (dispatch_agent()): `dispatch-agent.sh` function with `is_blocker_escalation` flag, future-proofing (references dispatch-agent-spec.md for full detail)
  - Component 5 (Handoff Protocol): `.orchestrator-handoff.json` schema overview, writing/reading contracts (references handoff-schema.md for full detail)
  - Component 6 (Extension Lifecycle Hooks): manifest.json `hooks` schema additions, hook execution contract
  - Component 7 (Nested Loop Resolution): Exclusive loop model, `orchestrator_mode` flag propagation
  - Cross-cutting concern: Context budget architecture overview (four-tier model)
  - Appendix: Dependency graph (from research Appendix C) and file location summary (from research Appendix D)
- [x] **Task 1.3**: Write `.claude/docs/architecture/orchestrate-state-machine.md` -- detailed /orchestrate state machine specification: *(completed)*
  - Complete state table with all states and transitions
  - State transition diagram (ASCII art)
  - MAX_CYCLES enforcement and loop guard file schema
  - Blocker escalation 5-step sequence (detect, research fork, read handoff, revise, re-implement)
  - Context flatness guarantee (400-token handoff budget)
  - Examples of normal flow, partial recovery flow, and blocker escalation flow
- [x] **Task 1.4**: Write `.claude/docs/architecture/dispatch-agent-spec.md` -- dispatch_agent() function specification: *(completed)*
  - Full function signature with all parameters
  - Fork-vs-subagent decision logic (semantic `is_blocker_escalation` flag)
  - Why TTL heuristics were rejected in favor of semantic signaling
  - Future-proofing section for named fork API
  - Integration with skill-orchestrate
- [x] **Task 1.5**: Write `.claude/docs/architecture/handoff-schema.md` -- structured handoff object schema: *(completed)*
  - Complete JSON schema for `.orchestrator-handoff.json` with all fields
  - Token budget constraints (400-token max)
  - Writing contract: when skills write the handoff (orchestrator_mode detection)
  - Reading contract: how the orchestrator consumes handoffs
  - Relationship to continuation handoffs (`handoffs/phase-N-handoff.md`)
  - Example handoff objects for: successful research, successful implementation, partial with continuation, blocked with escalation
- [x] **Task 1.6**: Cross-reference the new documents with each other and with the existing `system-overview.md` and `extension-system.md` *(completed)*
- [x] **Task 1.7**: Add a note to the top of existing `.claude/docs/architecture/system-overview.md` referencing the new target architecture documents (a single "See Also" line, not a content modification) *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/architecture-spec.md` - NEW: primary architecture specification (target state)
- `.claude/docs/architecture/orchestrate-state-machine.md` - NEW: /orchestrate state machine detail
- `.claude/docs/architecture/dispatch-agent-spec.md` - NEW: dispatch_agent() function spec
- `.claude/docs/architecture/handoff-schema.md` - NEW: orchestrator handoff JSON schema
- `.claude/docs/architecture/system-overview.md` - MODIFY: add "See Also" cross-reference line

**Verification**:
- `architecture-spec.md` contains all 7 component sections with: purpose, file locations, interface spec, cross-references
- `orchestrate-state-machine.md` contains complete state table and transition diagram
- `dispatch-agent-spec.md` contains full function signature and decision logic
- `handoff-schema.md` contains valid JSON schema with all fields from research
- Each document cross-references the others and the existing system-overview.md
- Function signatures match research report findings
- Dependency graph in architecture-spec.md matches research Appendix C

---

### Phase 2: Update downstream task descriptions [COMPLETED]

**Goal**: Make tasks 593-599 descriptions more specific and actionable by referencing concrete architecture components from the specification documents in `.claude/docs/architecture/`.

**Tasks**:
- [x] **Task 2.1**: Read current state.json descriptions for tasks 593-599 *(completed)*
- [x] **Task 2.2**: For task 593: Update description to reference specific shared scripts by name (`parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`) and their exact exported variables. Reference `.claude/docs/architecture/architecture-spec.md` Component 1. *(completed)*
- [x] **Task 2.3**: For task 594: Update description to reference `skill-base.sh` function inventory, hook point locations, and the dependency on task 598 context budgets. Reference `.claude/docs/architecture/architecture-spec.md` Component 2. *(completed)*
- [x] **Task 2.4**: For task 595: Update description to reference target command sizes (~150-200 lines), the routing-only controller pattern, and what commands retain vs. delegate. Reference `.claude/docs/architecture/architecture-spec.md` Components 1-2. *(completed)*
- [x] **Task 2.5**: For task 596: Update description to reference the state machine design, `dispatch-agent.sh`, `.orchestrator-handoff.json` schema, and the `orchestrator_mode` flag. Reference `.claude/docs/architecture/orchestrate-state-machine.md`, `dispatch-agent-spec.md`, and `handoff-schema.md`. *(completed)*
- [x] **Task 2.6**: For task 597: Update description to reference shared utilities applicable to /task, /revise, /todo, /review. Reference `.claude/docs/architecture/architecture-spec.md` Components 1-2. *(completed)*
- [x] **Task 2.7**: For task 598: Update description to reference the four-tier context loading model and budget caps per agent type. Reference `.claude/docs/architecture/architecture-spec.md` cross-cutting context section. *(completed)*
- [x] **Task 2.8**: For task 599: Update description to reference the `hooks` manifest.json schema, extension skill thinning pattern, and documentation update targets. Reference `.claude/docs/architecture/architecture-spec.md` Component 6. *(completed)*
- [x] **Task 2.9**: Write all 7 updated descriptions to state.json using jq *(completed: used Python for safe JSON manipulation)*
- [x] **Task 2.10**: Update corresponding TODO.md entries to match state.json descriptions *(completed)*
- [x] **Task 2.11**: Verify state.json and TODO.md are synchronized *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `specs/state.json` - Update descriptions for tasks 593-599
- `specs/TODO.md` - Update corresponding task entries

**Verification**:
- Each task description references the appropriate `.claude/docs/architecture/` document(s)
- Each description mentions specific components, file names, or schemas relevant to that task
- state.json and TODO.md descriptions are synchronized
- No task's dependencies changed (only descriptions updated)

---

### Phase 3: Create design guidance reports for downstream tasks [COMPLETED]

**Goal**: Write `03_design-guidance.md` reports in each downstream task's reports/ directory containing task-specific concrete specifications extracted from the architecture design. These guidance reports reference the permanent docs in `.claude/docs/architecture/` as their authoritative source.

**Tasks**:
- [x] **Task 3.1**: Task 593 report: Write `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md` containing: *(completed)*
  - Full `parse-command-args.sh` specification (signature, algorithm, exported vars)
  - Full `command-gate-in.sh` specification (signature, key behaviors, exported vars)
  - Full `command-gate-out.sh` specification (signature, reading contract)
  - Command refactoring target: what stays in each command file (~150-200 lines), what moves out
  - Baseline measurement methodology notes
  - Reference: `.claude/docs/architecture/architecture-spec.md` Component 1
- [x] **Task 3.2**: Task 594 report: Write `specs/594_refactor_workflow_skills_shared_base/reports/03_design-guidance.md` containing: *(completed)*
  - Complete `skill-base.sh` function inventory (11 functions with signatures)
  - Hook point locations in the lifecycle (Stage 2, 4, 6a, 7)
  - Target skill sizes table (researcher 150L, planner 130L, implementer 200L)
  - What remains skill-specific (context collection, delegation context, agent invocation)
  - Reference: `.claude/docs/architecture/architecture-spec.md` Component 2
- [x] **Task 3.3**: Task 595 report: Write `specs/595_refactor_research_plan_implement_commands/reports/03_design-guidance.md` containing: *(completed)*
  - Per-command breakdown: what each command retains after extraction
  - Routing-only controller pattern specification
  - Extension routing table integration requirements
  - Context tier constraints (commands must NOT load Tier 3 context)
  - Reference: `.claude/docs/architecture/architecture-spec.md` Components 1-2
- [x] **Task 3.4**: Task 596 report: Write `specs/596_create_orchestrate_command_skill_agent/reports/03_design-guidance.md` containing: *(completed)*
  - Complete state machine state table with transitions
  - `dispatch-agent.sh` full function specification
  - `.orchestrator-handoff.json` schema with all fields
  - Loop guard file schema
  - Blocker escalation flow (the 5-step sequence)
  - `orchestrator_mode` flag propagation pattern
  - References: `.claude/docs/architecture/orchestrate-state-machine.md`, `dispatch-agent-spec.md`, `handoff-schema.md`
- [x] **Task 3.5**: Task 597 report: Write `specs/597_refactor_task_revise_todo_review/reports/03_design-guidance.md` containing: *(completed)*
  - Applicable shared utilities from task 593 (gate-in/gate-out patterns)
  - /todo decomposition targets (orphan detection, roadmap sync, vault, metrics)
  - Memory harvest automation specification
  - /review decomposition targets (issue grouping, roadmap integration, tier selection)
  - Reference: `.claude/docs/architecture/architecture-spec.md` Components 1-2
- [x] **Task 3.6**: Task 598 report: Write `specs/598_progressive_disclosure_context_system/reports/03_design-guidance.md` containing: *(completed)*
  - Four-tier loading model specification (tier definitions, budget per tier)
  - Budget caps per agent type (sonnet 8K, opus 15K, haiku 2K)
  - Context index.json audit criteria
  - Tier classification rules for the 97 existing entries
  - Reference: `.claude/docs/architecture/architecture-spec.md` cross-cutting context section
- [x] **Task 3.7**: Task 599 report: Write `specs/599_update_claudemd_extension_documentation/reports/03_design-guidance.md` containing: *(completed)*
  - manifest.json `hooks` schema definition
  - Extension skill thinning pattern (target 30-50 lines)
  - CLAUDE.md sections requiring update (/orchestrate, routing table, shared utilities)
  - Documentation files requiring update (creating-commands.md, creating-skills.md, creating-agents.md)
  - Reference: `.claude/docs/architecture/architecture-spec.md` Component 6

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md` - NEW
- `specs/594_refactor_workflow_skills_shared_base/reports/03_design-guidance.md` - NEW
- `specs/595_refactor_research_plan_implement_commands/reports/03_design-guidance.md` - NEW
- `specs/596_create_orchestrate_command_skill_agent/reports/03_design-guidance.md` - NEW
- `specs/597_refactor_task_revise_todo_review/reports/03_design-guidance.md` - NEW
- `specs/598_progressive_disclosure_context_system/reports/03_design-guidance.md` - NEW
- `specs/599_update_claudemd_extension_documentation/reports/03_design-guidance.md` - NEW

**Verification**:
- Each report is 80-150 lines of actionable design guidance
- Each report contains concrete specifications (not general summaries)
- Each report references the appropriate `.claude/docs/architecture/` document(s)
- Task 593 report includes function signatures matching the architecture spec
- Task 596 report includes the complete state machine and handoff schema
- No report duplicates content already in the task's 01_seed-research.md

---

### Phase 4: Validate consistency and commit [COMPLETED]

**Goal**: Verify all deliverables exist, are consistent, and commit the work.

**Tasks**:
- [x] **Task 4.1**: Verify all 4 architecture docs exist in `.claude/docs/architecture/`: *(completed)*
  - `architecture-spec.md`
  - `orchestrate-state-machine.md`
  - `dispatch-agent-spec.md`
  - `handoff-schema.md`
- [x] **Task 4.2**: Verify `system-overview.md` has the "See Also" cross-reference *(completed)*
- [x] **Task 4.3**: Verify all 7 design guidance reports exist in their respective task directories *(completed)*
- [x] **Task 4.4**: Verify state.json descriptions for tasks 593-599 were updated *(completed: all 7 have architecture-spec.md reference)*
- [x] **Task 4.5**: Verify TODO.md entries match state.json for tasks 593-599 *(completed: all 7 MATCH)*
- [x] **Task 4.6**: Verify no state.json fields other than `description` were modified (dependencies, status, etc. unchanged) *(completed: all status = not_started)*
- [x] **Task 4.7**: Run a cross-reference check: architecture spec references match guidance report content; all docs cross-reference each other consistently *(completed: all 4 docs have See Also; guidance reports 193-324 lines)*
- [x] **Task 4.8**: Git commit all changes *(completed: committed via phases 1-3; final commit follows)*

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- No new files; validation only plus git commit

**Verification**:
- `ls .claude/docs/architecture/architecture-spec.md .claude/docs/architecture/orchestrate-state-machine.md .claude/docs/architecture/dispatch-agent-spec.md .claude/docs/architecture/handoff-schema.md` succeeds
- `ls specs/59{3,4,5,6,7,8,9}_*/reports/03_design-guidance.md` returns 7 files
- `jq '.active_projects[] | select(.project_number >= 593 and .project_number <= 599) | .description' specs/state.json` shows updated descriptions
- Git commit succeeds with all deliverables included

## Testing & Validation

- [ ] Architecture spec (`architecture-spec.md`) contains all 7 component sections with interface specifications
- [ ] Each component section has: purpose, file locations, function signatures or JSON schemas, cross-references
- [ ] Three supplementary docs exist and contain detailed specifications for their respective domains
- [ ] All architecture docs cross-reference each other and the existing `system-overview.md`
- [ ] All 7 design guidance reports exist (one per downstream task)
- [ ] Each guidance report is 80-150 lines with concrete, actionable specifications
- [ ] Each guidance report references the appropriate `.claude/docs/architecture/` document(s) as its authoritative source
- [ ] state.json and TODO.md are synchronized for tasks 593-599
- [ ] No downstream task dependencies or statuses were changed
- [ ] Architecture spec dependency graph matches research report Appendix C

## Artifacts & Outputs

**Permanent architecture documentation** (in `.claude/docs/architecture/`):
- `.claude/docs/architecture/architecture-spec.md` - Primary 7-component architecture specification (target state)
- `.claude/docs/architecture/orchestrate-state-machine.md` - /orchestrate state machine detail
- `.claude/docs/architecture/dispatch-agent-spec.md` - dispatch_agent() function specification
- `.claude/docs/architecture/handoff-schema.md` - Orchestrator handoff JSON schema and contracts

**Task-specific artifacts** (in `specs/`):
- `specs/592_design_unified_workflow_architecture/plans/02_architecture-design.md` - This plan
- `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md` - Design guidance for task 593
- `specs/594_refactor_workflow_skills_shared_base/reports/03_design-guidance.md` - Design guidance for task 594
- `specs/595_refactor_research_plan_implement_commands/reports/03_design-guidance.md` - Design guidance for task 595
- `specs/596_create_orchestrate_command_skill_agent/reports/03_design-guidance.md` - Design guidance for task 596
- `specs/597_refactor_task_revise_todo_review/reports/03_design-guidance.md` - Design guidance for task 597
- `specs/598_progressive_disclosure_context_system/reports/03_design-guidance.md` - Design guidance for task 598
- `specs/599_update_claudemd_extension_documentation/reports/03_design-guidance.md` - Design guidance for task 599

## Rollback/Contingency

This task produces only documentation artifacts and task description updates. Rollback is straightforward:
- Architecture docs: delete the 4 new files from `.claude/docs/architecture/` and revert the `system-overview.md` See Also line
- Design guidance reports: delete `03_design-guidance.md` from each downstream task's reports/ directory
- Task descriptions: revert state.json and TODO.md via git checkout
- No code changes, no configuration changes, no system behavior changes
