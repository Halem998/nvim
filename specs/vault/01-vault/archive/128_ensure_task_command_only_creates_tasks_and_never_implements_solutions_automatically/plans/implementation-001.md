# Implementation Plan: Task #128

**Task**: OC_128 - Ensure /task command only creates tasks and never implements solutions automatically
**Version**: 001
**Created**: 2026-03-04
**Language**: general

## Overview

The /task command has been incorrectly auto-implementing solutions when users create task entries with problem descriptions. This plan addresses the root cause (agent misinterpretation of user intent) by adding explicit "DO NOT IMPLEMENT" boundaries to the task command specification, clarifying agent role, and documenting workflow phase separation.

## Phases

### Phase 1: Add Critical "DO NOT IMPLEMENT" Warning Header [COMPLETED]

**Goal**: Add prominent warning at the top of task.md

**Tasks**:
- [✓] Add CRITICAL warning block with 4 bullet points
- [✓] Place warning early in file (before mode descriptions)
- [✓] Ensure all bullet points are clearly formatted

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/commands/task.md`

---

### Phase 2: Add Agent Role Clarification [COMPLETED]

**Goal**: Clarify the agent's role when processing /task commands

**Tasks**:
- [✓] Add agent role section defining "task administrator, not problem solver"
- [✓] Differentiate task administration from problem-solving
- [✓] Establish boundaries for task management only

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/commands/task.md`

---

### Phase 3: Add Input Validation Checks [COMPLETED]

**Goal**: Add validation checks in CREATE mode section

**Tasks**:
- [✓] Add 3 validation checks with CHECK/ACTION/WHY format
- [✓] Place checks in CREATE mode section
- [✓] Reinforce "create only, don't implement" rule

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/commands/task.md`

---

### Phase 4: Document Workflow Phase Separation [COMPLETED]

**Goal**: Document clear separation between workflow phases

**Tasks**:
- [✓] Add workflow phases table with all 4 phases
- [✓] Show that /task does NOT create artifacts (only TODO.md/state.json)
- [✓] Add "Key Principle" section stating task creation is independent of implementation
- [✓] Provide example clarifying user intent vs agent action

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/commands/task.md`

---

## Dependencies

- Existing `.opencode/commands/task.md` file (assumed present)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Future agents may still misinterpret intent | Validation checks provide explicit checkpoints before action |
| Documentation bloat | Keep sections concise; use tables and bullet points for scannability |
| Agent ignores warnings | Multiple redundant warnings at different points in the file |
| Backwards compatibility | Changes are additive only; existing functionality preserved |

## Success Criteria

- [ ] `.opencode/commands/task.md` contains a prominent "CRITICAL: DO NOT IMPLEMENT" section
- [ ] Agent role is clearly defined as "task administrator, not problem solver"
- [ ] CREATE mode includes input validation checks
- [ ] Workflow phases are documented with clear separation
- [ ] Task status updated to PLANNED with plan artifact
- [ ] Changes committed to repository
