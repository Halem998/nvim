# Implementation Plan: Task #497

- **Task**: 497 - Add per-phase plan item check-off to implementation agent
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 495 (multi-subagent continuation loop) - COMPLETE
- **Research Inputs**: `specs/497_per_phase_plan_item_checkoff/reports/01_checkoff-research.md`
- **Artifacts**: `specs/497_per_phase_plan_item_checkoff/plans/01_checkoff-plan.md` (this file)
- **Standards**: `plan-format.md`, `status-markers.md`, `artifact-management.md`, `tasks.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the general-implementation-agent to check off individual checklist items (`- [ ]` → `- [x]`) within each phase as objectives are completed. The check-off happens in a new Stage 4B-ii sub-stage, immediately after the progress file update (Stage 4B), and supplements the existing JSON progress tracking with human-readable plan file updates. Changes must be applied to all 4 copies of the agent file to maintain consistency.

### Research Integration

Research confirms that plan files consistently use `- [ ] **Task {P}.{N}**: {description}` syntax within phase Tasks sections, but the agent currently only edits phase headings (`[NOT STARTED]` → `[IN PROGRESS]` → `[COMPLETED]`) and never updates individual checklist items. The JSON progress file (`progress/phase-{P}-progress.json`) remains the machine-readable primary tracking mechanism; plan check-off is a human-readable augmentation. The recommended integration point is Stage 4B-ii, after progress file updates and before phase verification.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No ROADMAP.md context loaded for this task.

## Goals & Non-Goals

**Goals**:
- Add Stage 4B-ii to general-implementation-agent.md that converts `- [ ]` to `- [x]` for completed objectives
- Define exact matching pattern: `- [ ] **Task {P}.{N}**: {description}`
- Support optional brief completion notes appended as `*(completed: {note})*`
- Update all 4 file copies of the agent definition
- Document interaction with Task 495 continuation loop and handoff artifacts
- Provide before/after examples of plan file state
- Verify changes across all 4 copies

**Non-Goals**:
- Replace the JSON progress file (it remains primary)
- Add check-off to plans that don't use the standard `- [ ] **Task {P}.{N}**:` syntax
- Modify the skill-implementer continuation loop logic
- Add timestamps or verbose descriptions to completion notes
- Create new tooling or automation scripts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plan file edit conflicts with phase heading edits | Medium | Low | Use precise `old_string` matching on the full checklist line; Edit tool requires exact matches so concurrent edits to different lines are safe |
| Check-off consumes extra tool calls, accelerating context pressure | Low | Medium | Only check off after completing an objective (not every micro-step); ~5-10 Edit calls per phase is negligible |
| Successor confusion about source of truth | Low | Low | Document clearly: progress file is primary, plan check-off is secondary/human-readable |
| Inconsistent syntax across plan styles | Medium | Low | Match exact `- [ ] **Task {P}.{N}**:` pattern; if plan uses different style, skip check-off and fall back to progress file only |
| Mirror copies drift from primary | Medium | Low | Apply identical edits to all 4 copies; verify with grep after each phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Primary Agent File (.opencode/) [COMPLETED]

**Goal**: Add Stage 4B-ii check-off logic and Stage 1 successor guidance to the primary general-implementation-agent.md

**Tasks**:
- [x] **Task 1.1**: Insert Stage 4B-ii subsection after existing Stage 4B "Update Progress File" in `.opencode/agent/subagents/general-implementation-agent.md` *(completed)*
  - Add heading `#### 4B-ii. Check Off Completed Items in Plan File`
  - Document steps: locate current phase Tasks section, edit matching checklist items, append optional notes
  - Specify exact pattern: `- [ ] **Task {P}.{N}**: {description}`
  - Specify conversion: `- [x] **Task {P}.{N}**: {description} *(completed)*`
  - Specify optional note format: `*(completed: {brief note})*`
  - Add fallback: if plan does not use checklist syntax, skip this step
- [x] **Task 1.2**: Update Stage 1 successor behavior to mention optional plan file review *(completed)*
  - Add bullet: "Optionally review the plan file to see checked-off items for human-readable context. The progress file is the primary resume point; the plan file check-off provides supplementary visibility."
- [x] **Task 1.3**: Verify the primary file edits are syntactically correct and preserve existing structure *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/agent/subagents/general-implementation-agent.md` - Add Stage 4B-ii and update Stage 1

**Verification**:
- Read the modified sections to confirm Stage 4B-ii exists between Stage 4B and Stage 4C
- Confirm Stage 1 successor behavior includes optional plan file review
- Confirm no accidental deletions or formatting corruption

---

### Phase 2: Sync to Mirror Copies [COMPLETED]

**Goal**: Apply identical changes to the 3 remaining copies of general-implementation-agent.md

**Tasks**:
- [x] **Task 2.1**: Apply identical Stage 4B-ii insertion to `.opencode/extensions/core/agents/general-implementation-agent.md` *(completed)*
- [x] **Task 2.2**: Apply identical Stage 1 successor update to `.opencode/extensions/core/agents/general-implementation-agent.md` *(completed)*
- [x] **Task 2.3**: Apply identical Stage 4B-ii insertion to `.claude/agents/general-implementation-agent.md` *(completed)*
- [x] **Task 2.4**: Apply identical Stage 1 successor update to `.claude/agents/general-implementation-agent.md` *(completed)*
- [x] **Task 2.5**: Apply identical Stage 4B-ii insertion to `.claude/extensions/core/agents/general-implementation-agent.md` *(completed)*
- [x] **Task 2.6**: Apply identical Stage 1 successor update to `.claude/extensions/core/agents/general-implementation-agent.md` *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/extensions/core/agents/general-implementation-agent.md`
- `.claude/agents/general-implementation-agent.md`
- `.claude/extensions/core/agents/general-implementation-agent.md`

**Verification**:
- Grep for "4B-ii" in all 4 copies — should match in all
- Grep for "Optionally review the plan file" in all 4 copies — should match in all
- Confirm line counts are consistent across copies (within ~5 lines)

---

### Phase 3: Update Context Documentation [COMPLETED]

**Goal**: Update handoff-artifact template and optionally document plan checklist convention

**Tasks**:
- [x] **Task 3.1**: Update `.opencode/context/formats/handoff-artifact.md` Current State section example *(completed)*
  - Add line showing plan file reference with checked-off items: `- **Plan**: `specs/.../plans/01_...md` — Phase 2: Tasks 2.1-2.3 checked off, Task 2.4 in progress`
- [x] **Task 3.2**: Optionally add checklist convention note to `.opencode/context/formats/plan-format.md` *(completed)*
  - Add note under "Implementation Phases (format)" that agents may check off `- [ ]` items during implementation
  - Note that progress file remains primary machine-readable source
- [x] **Task 3.3**: Apply identical handoff-artifact.md update to `.claude/context/formats/handoff-artifact.md` if it exists *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.opencode/context/formats/handoff-artifact.md`
- `.opencode/context/formats/plan-format.md` (optional)
- `.claude/context/formats/handoff-artifact.md` (if exists)

**Verification**:
- Read updated handoff-artifact.md to confirm Current State example includes plan file reference
- Confirm plan-format.md has optional note if modified

---

### Phase 4: Testing & Verification [COMPLETED]

**Goal**: Verify all 4 agent copies are consistent and the new instructions are correct

**Tasks**:
- [x] **Task 4.1**: Run grep across all 4 copies for key strings
  - `grep -r "4B-ii" .opencode/agent/subagents/general-implementation-agent.md .opencode/extensions/core/agents/general-implementation-agent.md .claude/agents/general-implementation-agent.md .claude/extensions/core/agents/general-implementation-agent.md`
  - `grep -r "Task {P}.{N}"` across the 4 files
  - `grep -r "Optionally review the plan file"` across the 4 files *(completed)*
- [x] **Task 4.2**: Spot-check one mirror copy against primary for identical content
  - Read Stage 4 section from primary and one mirror, compare side-by-side *(completed)*
- [x] **Task 4.3**: Verify no broken references or malformed markdown in modified files *(completed)*
- [x] **Task 4.4**: Create test scenario document showing before/after plan state
  - Include example: Phase 2 with Tasks 2.1-2.3 checked off, 2.4 in progress
  - Include example: Phase 2 fully completed with all tasks checked off *(completed)*

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- None (verification only)

**Verification**:
- All 4 copies contain Stage 4B-ii
- All 4 copies contain updated Stage 1 successor guidance
- Grep results show 4 matches for each key phrase
- Before/after examples are clear and match the specified pattern

## Testing & Validation

- [x] All 4 copies of general-implementation-agent.md contain the new Stage 4B-ii section
- [x] All 4 copies contain the updated Stage 1 successor behavior
- [x] Handoff-artifact.md example includes plan file check-off reference
- [x] Grep verification shows consistent content across all copies
- [x] Before/after examples demonstrate correct `- [ ]` → `- [x]` conversion with optional notes
- [x] No malformed markdown or broken references introduced
- [x] Existing Stage 4 structure is preserved (4A, 4B, 4B-ii, 4C, 4D, 4E)

## Artifacts & Outputs

- Modified `.opencode/agent/subagents/general-implementation-agent.md`
- Modified `.opencode/extensions/core/agents/general-implementation-agent.md`
- Modified `.claude/agents/general-implementation-agent.md`
- Modified `.claude/extensions/core/agents/general-implementation-agent.md`
- Modified `.opencode/context/formats/handoff-artifact.md`
- Modified `.opencode/context/formats/plan-format.md` (optional)

## Rollback/Contingency

If changes cause issues during implementation:
1. Revert any single file with `git checkout -- <file>`
2. All changes are text edits to markdown files — no generated code or state mutations
3. The continuation loop from Task 495 is unaffected; progress files remain authoritative
4. If a mirror copy is corrupted, copy from primary and re-apply

## Example: Before/After Plan File State

**Before implementation (Phase 2 in progress, no tasks completed)**:

```markdown
### Phase 2: Build the Core Module [IN PROGRESS]

**Tasks**:
- [ ] **Task 2.1**: Create module skeleton
- [ ] **Task 2.2**: Implement tool preference persistence
- [ ] **Task 2.3**: Implement active terminal detection
- [ ] **Task 2.4**: Implement smart_toggle() entry point
- [ ] **Task 2.5**: Implement setup() function
```

**After completing Tasks 2.1-2.3, with 2.4 in progress**:

```markdown
### Phase 2: Build the Core Module [IN PROGRESS]

**Tasks**:
- [x] **Task 2.1**: Create module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed: both Claude and OpenCode detection working)*
- [ ] **Task 2.4**: Implement smart_toggle() entry point *(in progress)*
- [ ] **Task 2.5**: Implement setup() function
```

**After phase complete**:

```markdown
### Phase 2: Build the Core Module [COMPLETED]

**Tasks**:
- [x] **Task 2.1**: Create module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed)*
- [x] **Task 2.4**: Implement smart_toggle() entry point *(completed)*
- [x] **Task 2.5**: Implement setup() function *(completed)*
```
