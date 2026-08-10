# Implementation Plan: Port Topic Schema and Rules

- **Task**: 580 - port_topic_schema_rules
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/580_port_topic_schema_rules/reports/01_port-topic-schema.md
- **Artifacts**: plans/01_port-topic-schema.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the topic system schema and rules from ProofChecker to the core agent system. The ProofChecker has two discrete additions: (1) `active_topics` top-level field and per-task `topic` field in `state-management-schema.md`, and (2) a "Task Order Synchronization" section in `state-management.md`. All additions are 100% project-agnostic and can be inserted surgically without modifying existing content.

### Research Integration

The research report (01_port-topic-schema.md) confirmed that all additions are project-agnostic, identified exact insertion points in both files, and provided the verbatim text to insert. The report identified 4 insertions for the schema file and 2 modifications for the rule file, totaling +72 net new lines across both files.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `active_topics` (top-level string[]) field to state-management-schema.md JSON example and field reference
- Add per-task `topic` (string, optional) field to state-management-schema.md JSON example and field reference
- Add "Top-Level Fields" table to state-management-schema.md field reference section
- Add "Task Order Synchronization" section (~49 lines) to state-management.md rule
- Expand the Canonical Sources bullet in state-management.md to mention topic fields

**Non-Goals**:
- Modifying state.json itself (schema documentation only)
- Adding topic values to any project (field definitions only)
- Creating or modifying generate-task-order.sh or update-task-status.sh scripts
- Changing any existing content beyond the one-line Canonical Sources expansion

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit tool ambiguous match on common strings | L | L | Use sufficiently large context strings for unique matching |
| Insertion order matters in schema file | M | L | Follow the research report's recommended insertion order (top-down) |
| update-task-status.sh may not exist in core | L | L | The rule references it generically; absence does not break anything |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Schema Additions (state-management-schema.md) [COMPLETED]

**Goal**: Add topic-related fields to the state management schema documentation

**Tasks**:
- [x] Insert `active_topics` array into the `state.json Full Structure` JSON example block (after the `"next_project_number": 346,` line) *(completed)*
- [x] Insert `"topic": "completeness",` into the per-task entry JSON example block (after the `"task_type": "general",` line) *(completed)*
- [x] Insert the full "Top-Level Fields" table as a new `###` subsection before `### Project Entry Fields` *(completed)*
- [x] Insert `topic` row into the "Project Entry Fields" table (after the `task_type` row) *(completed)*
- [x] Verify all four insertions render correctly by reading the modified file *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - 4 surgical insertions adding topic fields and top-level fields table

**Verification**:
- File contains `"active_topics"` in the JSON example block
- File contains `"topic"` in the per-task JSON example
- File contains `### Top-Level Fields` subsection before `### Project Entry Fields`
- The `### Project Entry Fields` table includes a `topic` row after `task_type`

---

### Phase 2: Rule Additions (state-management.md) [COMPLETED]

**Goal**: Add Task Order Synchronization documentation and expand Canonical Sources

**Tasks**:
- [x] Expand the state.json Canonical Sources bullet to mention `topic` and `active_topics` (replace 1 line with 2 lines) *(completed)*
- [x] Insert the full "Task Order Synchronization" section (~49 lines) after the `## Two-Phase Update Pattern` section and before `## Error Handling` *(completed)*
- [x] Verify the section ordering is: Two-Phase Update Pattern -> Task Order Synchronization -> Error Handling *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/rules/state-management.md` - Expand 1 bullet line, append 1 new section (~49 lines)

**Verification**:
- The Canonical Sources bullet mentions `topic` and `active_topics`
- The file contains `## Task Order Synchronization` section
- Section ordering: Two-Phase Update Pattern, Task Order Synchronization, Error Handling
- The section contains Derivation Relationship table, Regeneration Triggers table, Responsible Scripts table, and Non-Regeneration Events list

## Testing & Validation

- [ ] Read modified state-management-schema.md and confirm all 4 insertions are present and well-formed
- [ ] Read modified state-management.md and confirm both modifications are present and well-formed
- [ ] Verify no existing content was deleted or altered (beyond the 1-line Canonical Sources expansion)
- [ ] Confirm section headings maintain correct hierarchy (## and ### levels)

## Artifacts & Outputs

- `specs/580_port_topic_schema_rules/plans/01_port-topic-schema.md` (this plan)
- `.claude/context/reference/state-management-schema.md` (modified)
- `.claude/rules/state-management.md` (modified)

## Rollback/Contingency

Both files are tracked by git. If any insertion produces incorrect results, revert with `git checkout -- .claude/context/reference/state-management-schema.md .claude/rules/state-management.md` and re-attempt with corrected Edit tool parameters.
