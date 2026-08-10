# Implementation Plan: Task #129

- **Task**: 129 - fix_plan_format_in_implementation_001_md
- **Status**: [PLANNED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: 
  - specs/129_fix_plan_format_in_implementation_001_md/reports/research-001.md
  - specs/129_fix_plan_format_in_implementation_001_md/reports/research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The plan file for Task #128 (`implementation-001.md`) deviates from the standard plan format due to a "Pull" context loading failure in the planner agent. This plan addresses both the immediate symptom (Task 128's file format) and the root cause (planner agent not reliably loading format standards). We will switch to a "Push" model for critical context loading in `skill-planner` and formalize this in a new best practices guide.

## Goals & Non-Goals

**Goals**:
- Fix `specs/128_.../plans/implementation-001.md` to strictly follow `plan-format.md`.
- Implement "Push" context loading in `skill-planner` to prevent future failures.
- Document context loading best practices in `docs/guides/context-loading-best-practices.md`.

**Non-Goals**:
- Modifying other agents (e.g., implementer, researcher) at this time (scope constrained to planner).
- Implementing automated validation scripts (relying on improved prompt context for now).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context window limits | Low | Low | `plan-format.md` is small (~140 lines); impact is negligible. |
| Overwriting Task 128 content | Med | Low | Use careful edits; content is already researched and available. |
| Skill complexity | Low | Low | Keep the "Push" logic simple: Read file -> Append to prompt. |

## Implementation Phases

### Phase 1: Reformat Task 128 Plan File [COMPLETED]

**Goal**: Bring the existing non-compliant plan file into compliance.

**Tasks**:
- [✓] Move status markers from body to phase headers (e.g., `### Phase 1: ... [COMPLETED]`).
- [✓] Remove redundant `**Status**: [STATUS]` lines.
- [✓] Rename `**Objectives**:` to `**Goal**:`, `**Estimated effort**:` to `**Timing**:`.
- [✓] Consolidate `**Steps**:` and `**Verification**:` into `**Tasks**:`.
- [✓] Ensure "Goals & Non-Goals" section exists (if missing).

**Timing**: 30 minutes

**Files to modify**:
- `specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md`

**Verification**:
- [✓] File parses correctly vs `plan-format.md`.
- [✓] All 4 phases present with correct headers.

### Phase 2: Create Context Loading Guide [COMPLETED]

**Goal**: Document the "Push vs Pull" strategy for future reference.

**Tasks**:
- [✓] Create `.opencode/docs/guides/context-loading-best-practices.md`.
- [✓] Define "Push" (critical context injected in prompt) vs "Pull" (reference loaded on demand).
- [✓] Document when to use each (Push for strict formats/rules, Pull for docs/code).
- [✓] Provide examples of how to implement Push in skills.

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/docs/guides/context-loading-best-practices.md` (create)

**Verification**:
- [✓] Guide covers the failure mode observed in Task 128.
- [✓] Guide provides clear examples of Push vs Pull.

**Note**: This was completed as Task OC_132, which created a comprehensive 391-line guide covering Push/Pull models, decision framework, and real examples from 4 core skills.

### Phase 3: Update Planner Skill for Push Loading [COMPLETED]

**Goal**: Ensure `planner-agent` ALWAYS receives the plan format schema.

**Tasks**:
- [✓] Modify `.opencode/skills/skill-planner/SKILL.md` to include context_injection block.
- [✓] Update `Execution Flow` to include reading `plan-format.md` before delegation.
- [✓] Update the `Task` tool invocation to append the content of `plan-format.md` to the prompt.

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/skills/skill-planner/SKILL.md`

**Verification**:
- [✓] Skill execution flow explicitly reads the format file.
- [✓] Prompt construction includes the file content.

**Note**: The skill-planner already has Push context loading implemented with:
- `<context_injection>` block loading plan-format.md, status-markers.md, and task-breakdown.md
- Stage 1 (LoadContext) reading the context files
- Stage 3 (Delegate) injecting context into planner-agent prompt via `{plan_format}`, `{status_markers}`, and `{task_breakdown}` variables

## Testing & Validation

- [ ] **Manual Test**: Run `/plan OC_129` (this task) - *Self-referential test*: The planner agent should naturally follow the format if the context were already pushed (but here we are fixing it).
- [ ] **Verification**: Check `skill-planner` logic by inspection.

## Artifacts & Outputs

- `specs/128_.../plans/implementation-001.md` (Fixed)
- `docs/guides/context-loading-best-practices.md` (New)
- `.opencode/skills/skill-planner/SKILL.md` (Updated)

## Rollback/Contingency

- Revert changes to `SKILL.md` if syntax errors occur.
- Restore `implementation-001.md` from git history if content is lost.
