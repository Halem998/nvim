# Implementation Plan: Update Artifact Formats for Deviation Tracking

- **Task**: 568 - Update artifact formats for deviation tracking
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/568_update_artifact_formats_deviation_tracking/reports/01_artifact-formats-research.md
- **Artifacts**: plans/01_artifact-formats-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add deviation tracking fields to five core artifact format files so that agents record plan deviations (skipped, altered, deferred tasks) at every stage of artifact production. This defines the format-level contract that downstream tasks 569 (general agents) and 570 (extension agents) will implement. The changes include a new `deviations` array in the progress file schema, checklist annotation syntax in the plan format enforcement rule, a new `## Deviations from Plan` section in handoff artifacts, a final checkpoint protocol step in the context exhaustion pattern, and a new `## Plan Deviations` section in implementation summaries.

### Research Integration

The research report (01_artifact-formats-research.md) identified all five target files, documented their current structure, and provided exact proposed additions including section names, field schemas, annotation syntax, and insertion points. All recommendations are integrated into this plan with specific task-level granularity matching the research findings.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Define the exact schema, syntax, and section structure for deviation tracking in all five format files
- Ensure all annotation formats are consistent across files (same `*(deviation: ...)*` syntax)
- Provide a clear contract that tasks 569 and 570 can implement against without ambiguity
- Add the post-phase self-review step to the progress file update protocol

**Non-Goals**:
- Modifying agent instruction files (that is tasks 569 and 570)
- Adding deviation tracking to any files beyond the five identified format/pattern/rule files
- Implementing runtime validation or enforcement tooling
- Changing the existing `approaches_tried` schema in progress-file.md

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Annotation syntax conflicts with existing patterns | M | L | The `*(deviation: ...)*` marker is distinct from `*(completed)*`; no collision possible |
| Adding `deviations` array breaks existing progress files | M | L | The field is optional with default `[]`; existing files remain valid |
| Inconsistent cross-references between the five files | M | M | Phase 4 performs a dedicated consistency verification pass |
| Downstream tasks 569/570 misinterpret format changes | H | L | Exact syntax strings and field names are unambiguous; research report serves as additional reference |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Foundation Formats (progress-file.md + plan-format-enforcement.md) [COMPLETED]

**Goal**: Define the deviation schema and annotation syntax that other format files will reference.

**Tasks**:
- [x] **Task 1.1**: Add `deviations` array field specification to `progress-file.md` schema section (after `approaches_tried`). Include the JSON schema with fields: `task_id` (string), `description` (string), `type` (enum: `"skipped"`, `"altered"`, `"deferred"`), `reason` (string), `annotation` (string). *(completed)*
- [x] **Task 1.2**: Add field specification table for deviation entries to `progress-file.md` (matching the table format used for `objectives` and `approaches_tried` entries). *(completed)*
- [x] **Task 1.3**: Add step 2.5 to the Update Protocol section in `progress-file.md`: "After completing a phase (post-phase self-review): Re-read the phase task checklist in the plan. For each unchecked item that will not be completed, add a deviation entry. Write deviation annotations into the plan file checklist." *(completed)*
- [x] **Task 1.4**: Add a `deviations` entry to the Example section in `progress-file.md` showing a sample deviation in the example JSON block. *(completed)*
- [x] **Task 1.5**: Append "Checklist item annotation format" section to `plan-format-enforcement.md` with completed, completed-with-note, in-progress, and in-progress-at-handoff variants. *(completed)*
- [x] **Task 1.6**: Append "Deviation annotation format" section to `plan-format-enforcement.md` with skipped, altered, and deferred variants using the `*(deviation: ...)*` syntax. *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/progress-file.md` - Add deviations array schema, field table, update protocol step 2.5, and example entry
- `.claude/rules/plan-format-enforcement.md` - Append checklist annotation format and deviation annotation format sections

**Verification**:
- `progress-file.md` contains `"deviations"` field with complete sub-field specification
- `progress-file.md` Update Protocol has numbered step 2.5 between steps 2 and 3
- `progress-file.md` Example section includes a deviation entry
- `plan-format-enforcement.md` contains `*(completed)*`, `*(in progress)*`, `*(in progress -- handoff)*` annotation formats
- `plan-format-enforcement.md` contains `*(deviation: skipped -- ...)*`, `*(deviation: altered -- ...)*`, `*(deviation: deferred to task ...)*` annotation formats

---

### Phase 2: Handoff and Context Exhaustion Formats [COMPLETED]

**Goal**: Add deviation tracking to the handoff artifact template and the context exhaustion protocol.

**Tasks**:
- [x] **Task 2.1**: Add progressive handoff preamble note to `handoff-artifact.md` (near the top, after the Design Principle line): "Handoffs should be written (or updated) at the end of each phase, not only when context exhaustion is detected." *(completed)*
- [x] **Task 2.2**: Insert `## Deviations from Plan` section into the handoff document template in `handoff-artifact.md`, between `## Key Decisions Made` and `## What NOT to Try`. Include template lines for skipped and altered items, plus the `- None` default. *(completed)*
- [x] **Task 2.3**: Update the Section Guidelines in `handoff-artifact.md` to add guidance for the new `## Deviations from Plan` section (purpose, max items, format). *(completed)*
- [x] **Task 2.4**: Insert step 1.5 "Annotate Plan File (Final Checkpoint)" into `context-exhaustion-detection.md` between step 1 (Update Progress File FIRST) and step 2 (Write Handoff Artifact). Include the three sub-steps: mark completed tasks `*(completed)*`, mark in-progress task `*(in progress — handoff)*`, write deviation annotations from progress file. *(completed)*
- [x] **Task 2.5**: Add anti-pattern item 6 to `context-exhaustion-detection.md`: "Skip plan file annotation at handoff — If you hand off without annotating the plan file, successors must re-discover which tasks were completed versus pending. Always annotate the plan before handing off." *(completed)*

**Timing**: 40 minutes

**Depends on**: Phase 1 (annotation syntax defined in plan-format-enforcement.md must exist before referencing it)

**Files to modify**:
- `.claude/context/formats/handoff-artifact.md` - Add preamble note, `## Deviations from Plan` section in template, and section guidelines entry
- `.claude/context/patterns/context-exhaustion-detection.md` - Insert step 1.5 and add anti-pattern item 6

**Verification**:
- `handoff-artifact.md` template contains `## Deviations from Plan` between `## Key Decisions Made` and `## What NOT to Try`
- `handoff-artifact.md` contains progressive handoff note near top
- `handoff-artifact.md` Section Guidelines includes Deviations from Plan guidance
- `context-exhaustion-detection.md` contains step 1.5 with plan annotation sub-steps
- `context-exhaustion-detection.md` Anti-Patterns list includes item 6 about skipping plan annotation

---

### Phase 3: Summary Format [COMPLETED]

**Goal**: Add the plan deviations section to the summary format specification.

**Tasks**:
- [x] **Task 3.1**: Insert `## Plan Deviations` section into the Structure list in `summary-format.md`, immediately after item 3 (Decisions). Renumber subsequent items (Impacts becomes 5, Follow-ups becomes 6, References becomes 7). *(completed)*
- [x] **Task 3.2**: Add the `## Plan Deviations` section to the Example Skeleton in `summary-format.md`, between `## Decisions` and `## Impacts`, with template content showing the skipped/altered format and the `- None (implementation followed plan)` default. *(completed)*

**Timing**: 15 minutes

**Depends on**: Phase 1 (consistency with annotation syntax)

**Files to modify**:
- `.claude/context/formats/summary-format.md` - Add `## Plan Deviations` to structure list and example skeleton

**Verification**:
- `summary-format.md` Structure list includes `Plan Deviations` as item 4 (after Decisions)
- `summary-format.md` Example Skeleton includes `## Plan Deviations` section between Decisions and Impacts
- Structure numbering is consistent (7 items total, no gaps)

---

### Phase 4: Cross-File Consistency Verification [COMPLETED]

**Goal**: Verify all five files are internally consistent and cross-references are correct.

**Tasks**:
- [x] **Task 4.1**: Verify that the deviation annotation syntax in `plan-format-enforcement.md` matches the `annotation` field description in `progress-file.md` and the annotation instructions in `context-exhaustion-detection.md` step 1.5. *(completed)*
- [x] **Task 4.2**: Verify that the `## Deviations from Plan` section heading and field format in `handoff-artifact.md` are consistent with the `## Plan Deviations` section format in `summary-format.md`. *(completed)*
- [x] **Task 4.3**: Verify that all Related Documentation links in the five files still point to valid paths and that new cross-references are not needed. *(completed)*
- [x] **Task 4.4**: Read each of the five modified files end-to-end and confirm no formatting issues (broken markdown, orphaned headings, incorrect numbering). *(completed: also updated handoff example in context-exhaustion-detection.md to include Deviations from Plan section)*

**Timing**: 20 minutes

**Depends on**: Phases 2, 3

**Files to modify**:
- Any of the five files if inconsistencies are found (corrections only)

**Verification**:
- All deviation annotation formats match across files
- Section heading names are consistent where applicable
- No broken links or formatting issues
- All five files pass a manual read-through without issues

## Testing & Validation

- [ ] `progress-file.md` schema section contains the `deviations` array with all five sub-fields documented
- [ ] `progress-file.md` Update Protocol includes step 2.5 for post-phase self-review
- [ ] `plan-format-enforcement.md` contains both checklist annotation format and deviation annotation format sections
- [ ] `handoff-artifact.md` template includes `## Deviations from Plan` in correct position
- [ ] `handoff-artifact.md` preamble includes progressive handoff note
- [ ] `context-exhaustion-detection.md` contains step 1.5 for plan file annotation
- [ ] `context-exhaustion-detection.md` anti-patterns list includes item 6
- [ ] `summary-format.md` structure and example include `## Plan Deviations`
- [ ] Annotation syntax is identical across all files that reference it: `*(deviation: skipped|altered|deferred -- ...)*`

## Artifacts & Outputs

- `.claude/context/formats/progress-file.md` (modified) - Deviations array schema, field table, step 2.5, example
- `.claude/rules/plan-format-enforcement.md` (modified) - Checklist and deviation annotation formats
- `.claude/context/formats/handoff-artifact.md` (modified) - Preamble note, Deviations from Plan section and guidelines
- `.claude/context/patterns/context-exhaustion-detection.md` (modified) - Step 1.5 and anti-pattern 6
- `.claude/context/formats/summary-format.md` (modified) - Plan Deviations section in structure and example

## Rollback/Contingency

All five target files are under git version control. If any change introduces issues, revert the specific file using `git checkout HEAD -- <path>`. Changes are isolated to individual sections within each file and do not affect existing content, so partial rollback is straightforward.
