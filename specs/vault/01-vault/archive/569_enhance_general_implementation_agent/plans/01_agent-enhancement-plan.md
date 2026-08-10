# Implementation Plan: Enhance General Implementation Agent

- **Task**: 569 - enhance_general_implementation_agent
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 568
- **Research Inputs**: specs/569_enhance_general_implementation_agent/reports/01_agent-enhancement-research.md
- **Artifacts**: plans/01_agent-enhancement-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task adds four behavioral improvements to `.claude/agents/general-implementation-agent.md`: (1) deviation annotation during phase execution, (2) post-phase self-review, (3) progressive handoff updates at phase boundaries, and (4) a final context-exhaustion plan annotation checkpoint. It also updates the Stage 6 summary template and the Phase Checkpoint Protocol to reference the new stages. All six edits target a single file and are purely additive -- no existing behavior is removed.

### Research Integration

The research report (`specs/569_enhance_general_implementation_agent/reports/01_agent-enhancement-research.md`) provides exact insertion points and wording for all six edits. Key findings:

- The agent file uses lettered sub-stages (4A, 4B, 4B-ii, C, D, E) with an existing naming inconsistency (section E is parenthetically labeled "Stage 4C").
- Stage 4B-ii currently supports `*(completed)*` and `*(in progress)*` annotations but not `*(deviation: ...)*`.
- No post-phase self-review or progressive handoff mechanism exists.
- The Stage 6 summary template does not include `## Plan Deviations`.
- The Phase Checkpoint Protocol does not reference self-review or progressive handoff.
- The research recommends inserting 4D-ii and 4D-iii as new sub-stages (matching the existing 4B-ii naming pattern), and leaving the E/"Stage 4C" inconsistency as-is to minimize diff scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the **Agent System Quality** items in Phase 1 of the roadmap, specifically improving agent behavioral completeness and consistency with format contract documents updated in task 568.

## Goals & Non-Goals

**Goals**:
- Add deviation annotation (skipped/altered/deferred format) to Stage 4B-ii as Step 4
- Add post-phase self-review as Stage 4D-ii with deviation discovery and recording
- Add progressive handoff updates as Stage 4D-iii for phase-end recovery points
- Add final plan annotation checkpoint as Step 1.5 in Stage 4E
- Update Stage 6 summary template to include `## Plan Deviations` section
- Update Phase Checkpoint Protocol step 4 to reference 4D-ii and 4D-iii

**Non-Goals**:
- Fixing the existing E/"Stage 4C" naming inconsistency (deferred per research recommendation)
- Modifying any other agent files
- Changing the format contract documents (already updated in task 568)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Insertion at wrong location breaks stage flow | H | L | Research provides exact anchor text for each insertion point; verify with Read before each Edit |
| Stage numbering becomes confusing | M | L | Follow existing 4B-ii naming pattern; 4D-ii and 4D-iii are consistent |
| Template replacement in Stage 6 loses existing content | M | L | Read full Stage 6 section before replacing; compare old and new templates |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases are sequential because all edits target the same file and later phases depend on line positions established by earlier insertions.

---

### Phase 1: Deviation Annotation in Stage 4B-ii [COMPLETED]

**Goal**: Add Step 4 to Stage 4B-ii to support deviation annotations (skipped/altered/deferred) during phase execution.

**Tasks**:
- [x] **Task 1.1**: Read `.claude/agents/general-implementation-agent.md` and locate Stage 4B-ii "Check Off Completed Items in Plan File", specifically the existing Step 3 block and the `**Note**` paragraph that follows it *(completed)*
- [x] **Task 1.2**: Insert Step 4 (deviation annotation format) between Step 3 and the **Note** paragraph, using exact wording from the research report Recommendation 1 *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Add Step 4 to Stage 4B-ii section

**Verification**:
- Step 4 appears after Step 3 and before the **Note** paragraph
- Step 4 contains all three deviation annotation formats (skipped, altered, deferred)
- References `plan-format-enforcement.md` for format documentation

---

### Phase 2: Post-Phase Self-Review and Progressive Handoff [COMPLETED]

**Goal**: Insert two new sub-stages (4D-ii and 4D-iii) between Stage 4D "Mark Phase Complete" and Stage 4E "Handoff on Context Pressure".

**Tasks**:
- [x] **Task 2.1**: Locate the boundary between Stage 4D's closing content and `#### E. Handoff on Context Pressure` *(completed)*
- [x] **Task 2.2**: Insert `#### 4D-ii. Post-Phase Self-Review` section using exact wording from research report (5-step self-review protocol with deviation recording and plan annotation) *(completed)*
- [x] **Task 2.3**: Insert `#### 4D-iii. Progressive Handoff Update` section immediately after 4D-ii, using exact wording from research report (3-step handoff protocol with condensed template) *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Insert 4D-ii and 4D-iii between Stage 4D and Stage 4E

**Verification**:
- 4D-ii appears after Stage 4D content and before 4D-iii
- 4D-iii appears after 4D-ii and before `#### E. Handoff on Context Pressure`
- 4D-ii contains 5 numbered steps including deviation recording and plan annotation
- 4D-iii contains 3 numbered steps including condensed handoff template
- 4D-iii includes the note about omitting trivial last-phase handoffs

---

### Phase 3: Context-Exhaustion Final Checkpoint [COMPLETED]

**Goal**: Insert Step 1.5 into Stage 4E (Handoff on Context Pressure) to ensure the plan file is annotated before writing the handoff document.

**Tasks**:
- [x] **Task 3.1**: Locate Stage 4E's Step 1 ("Update progress file") and Step 2 ("Write handoff artifact") in the agent file *(completed)*
- [x] **Task 3.2**: Insert Step 1.5 ("Annotate plan file (final checkpoint)") between Step 1 and Step 2, using exact wording from research report *(completed)*

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Insert Step 1.5 in Stage 4E

**Verification**:
- Step 1.5 appears between Step 1 and Step 2 in Stage 4E
- Step 1.5 covers three annotation actions: completed tasks, in-progress task, and deviation annotations
- Step numbering is 1, 1.5, 2, 3, 4 (matching context-exhaustion-detection.md pattern)

---

### Phase 4: Summary Template and Protocol Updates [COMPLETED]

**Goal**: Update the Stage 6 summary template to include `## Plan Deviations` and update the Phase Checkpoint Protocol step 4 to reference new stages 4D-ii and 4D-iii.

**Tasks**:
- [x] **Task 4.1**: Locate the markdown code block in Stage 6 containing the summary template and replace it with the updated template from the research report (sections: Overview, What Changed, Decisions, Plan Deviations, Verification, Notes) *(completed)*
- [x] **Task 4.2**: Add instruction text after the template block directing the agent to populate `## Plan Deviations` from progress file `deviations` arrays *(completed)*
- [x] **Task 4.3**: Locate the Phase Checkpoint Protocol section and update step 4 to read: "Update phase status to `[COMPLETED]` (Stage 4D), then perform post-phase self-review (Stage 4D-ii) and write a progressive handoff (Stage 4D-iii)" *(completed)*

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Replace Stage 6 template; update Phase Checkpoint Protocol step 4

**Verification**:
- Stage 6 template contains `## Plan Deviations` section with deviation format examples
- Stage 6 template section names align with summary-format.md (Overview, What Changed, Decisions, Plan Deviations, Verification, Notes)
- Phase Checkpoint Protocol step 4 references both Stage 4D-ii and Stage 4D-iii

---

### Phase 5: Full-File Verification [COMPLETED]

**Goal**: Read the complete agent file end-to-end and verify all insertions are correct, stage numbering is consistent, and cross-references are accurate.

**Tasks**:
- [x] **Task 5.1**: Read the full `.claude/agents/general-implementation-agent.md` file *(completed)*
- [x] **Task 5.2**: Verify stage ordering: 4A -> 4B -> 4B-ii (with Steps 1-4) -> 4C -> 4D -> 4D-ii -> 4D-iii -> 4E (with Steps 1, 1.5, 2, 3, 4) -> Stage 5 -> Stage 6 (updated template) -> Phase Checkpoint Protocol (updated step 4) *(completed)*
- [x] **Task 5.3**: Verify cross-references: 4D-ii references progress-file.md schema; 4D-iii references handoff-artifact.md format; Step 4 in 4B-ii references plan-format-enforcement.md; Stage 6 template aligns with summary-format.md *(completed)*
- [x] **Task 5.4**: Fix any issues found during verification (typos, broken references, inconsistent formatting) *(completed: no issues found)*

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Fix any issues found (if needed)

**Verification**:
- All six insertions are present and correctly placed
- No broken stage ordering or dangling references
- The file reads coherently as a complete agent specification

## Testing & Validation

- [ ] Full file read confirms all six insertions are present
- [ ] Stage numbering is consistent (no gaps, no duplicates)
- [ ] New sections reference correct format documents (progress-file.md, plan-format-enforcement.md, handoff-artifact.md, summary-format.md, context-exhaustion-detection.md)
- [ ] Deviation annotation format is consistent between Stage 4B-ii Step 4 and Stage 4D-ii Step 4
- [ ] Phase Checkpoint Protocol step 4 accurately summarizes the new post-phase workflow

## Artifacts & Outputs

- `specs/569_enhance_general_implementation_agent/plans/01_agent-enhancement-plan.md` (this plan)
- `specs/569_enhance_general_implementation_agent/summaries/01_agent-enhancement-summary.md` (created during implementation)
- `.claude/agents/general-implementation-agent.md` (modified file)

## Rollback/Contingency

All changes are to a single file (`.claude/agents/general-implementation-agent.md`). If implementation introduces issues, revert with `git checkout -- .claude/agents/general-implementation-agent.md` to restore the pre-task-569 version. Each phase's edits are independent enough that partial rollback can be done by reverting specific Edit operations.
