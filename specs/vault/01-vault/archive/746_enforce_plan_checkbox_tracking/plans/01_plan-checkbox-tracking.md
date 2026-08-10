# Implementation Plan: Task #746

- **Task**: 746 - Enforce plan checkbox tracking during implementation and orchestration
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/746_enforce_plan_checkbox_tracking/reports/01_plan-checkbox-tracking.md
- **Artifacts**: plans/01_plan-checkbox-tracking.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses plan checkbox drift by adding three layered enforcement mechanisms. The primary gate is a hardened Stage 4D-ii in `general-implementation-agent.md` that makes it a protocol violation to mark a phase `[COMPLETED]` with unchecked/unannotated items. The secondary safety net is a postflight plan-checkbox scan in `skill-implementer/SKILL.md` that warns and auto-annotates any items the agent missed. The tertiary improvement extends the orchestrator handoff schema with a `subtasks_completed` array for per-subtask visibility, along with fixing a schema inconsistency where `phases_completed`/`phases_total` are read as top-level fields but documented only in `continuation_context`.

### Research Integration

The research report identified exact insertion points in all target files: Stage 4D-ii lines 197-225 in `general-implementation-agent.md`, Stage 6a ending at line 379 in `skill-implementer/SKILL.md`, and the JSON schema at lines 29-75 in `handoff-schema.md`. The report confirmed that reading/editing plan files (task artifacts, not source files) in postflight is acceptable under the postflight boundary restriction. The report also found that `phases_completed`/`phases_total` are read as top-level fields by the orchestrator (line 355-356) but only documented inside `continuation_context` in the schema.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested.

## Goals & Non-Goals

**Goals**:
- Make Stage 4D-ii a blocking gate: no phase can be marked `[COMPLETED]` with unchecked, unannotated checklist items
- Add a postflight safety net in skill-implementer that detects and auto-annotates missed items
- Give the orchestrator per-subtask visibility via `subtasks_completed` in handoff JSON
- Fix the schema inconsistency for `phases_completed`/`phases_total` as top-level fields

**Non-Goals**:
- Changing the plan format itself or the deviation annotation syntax (already well-defined)
- Adding enforcement to hard-mode agents (general-implementation-hard-agent can inherit from the standard agent pattern)
- Adding full per-phase filtering in the postflight scan (simple total count is sufficient as a safety net)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hardened gate causes agents to loop re-reading plan items excessively | M | L | Gate only applies within the current phase block; no full plan re-read required |
| Postflight checkbox scan reads a large plan file, adding context cost | L | M | Non-blocking; simple grep count; limit to warning + annotation |
| `subtasks_completed` array grows large for multi-phase tasks | L | L | Document 20-entry cap in schema; truncate oldest if over budget |
| Schema changes break existing orchestrator handoff reading | H | L | Adding optional fields only; existing `// 0` and `// []` jq defaults ensure backward compatibility |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Harden Self-Review Gate in general-implementation-agent.md [COMPLETED]

**Goal**: Replace advisory language in Stage 4D-ii with a hard requirement that blocks phase completion when unchecked/unannotated items remain, and add a checkpoint before Stage 4D-iii.

**Tasks**:
- [x] **Task 1.1**: Replace Step 2 advisory language (lines 203-205) with HARD REQUIREMENT block that mandates completing or annotating every unchecked item before proceeding *(completed)*
- [x] **Task 1.2**: Add a Checkpoint block before the "Only then proceed" line (line 225) that verifies all `- [ ]` items are either checked or carry deviation annotations, with instruction to loop back to Step 2 if any remain *(completed)*
- [x] **Task 1.3**: Add instruction in Stage 4B-ii to accumulate completed subtask IDs (e.g., "1.1", "1.2") into a running list for later inclusion in the orchestrator handoff metadata *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` - Replace Step 2 text, add checkpoint block, add subtask ID accumulation instruction

**Verification**:
- Stage 4D-ii contains "HARD REQUIREMENT" or "protocol violation" language
- A Checkpoint block exists between Step 5 and Stage 4D-iii
- Stage 4B-ii references accumulating subtask IDs for handoff

---

### Phase 2: Add Postflight Plan-Checkbox Validation in skill-implementer/SKILL.md [COMPLETED]

**Goal**: Insert a non-blocking Stage 6b-checkbox between Stage 6a and Stage 6b that scans the plan for unchecked items in completed phases and auto-annotates any found.

**Tasks**:
- [x] **Task 2.1**: Insert a new `### Stage 6b-checkbox: Plan Checkbox Postflight Scan (Non-Blocking)` section after Stage 6a (line 381) and before Stage 6b (line 385) *(completed)*
- [x] **Task 2.2**: The new stage should: read `plan_path` (known from Stage 4 delegation context), grep for unchecked `- [ ]` items, log a warning count, and for each unchecked item auto-annotate via Edit with `*(postflight: unchecked -- review needed)*` *(completed)*
- [x] **Task 2.3**: Add a guard clause: only run if `plan_path` is set and the file exists; if not, skip silently *(completed)*
- [x] **Task 2.4**: Include note that this is a safety net (non-blocking) and does not fail the postflight even if unchecked items are found *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Insert new Stage 6b-checkbox section

**Verification**:
- A `Stage 6b-checkbox` section exists between Stage 6a and Stage 6b
- The section includes a `plan_path` guard clause
- The section is marked non-blocking
- The section describes auto-annotation behavior

---

### Phase 3: Extend Orchestrator Handoff Schema and Propagation [COMPLETED]

**Goal**: Add `subtasks_completed`, `phases_completed`, and `phases_total` as documented top-level fields in the handoff schema. Update the agent writing contract and orchestrator reading logic.

**Tasks**:
- [x] **Task 3.1**: Update the JSON schema example in `handoff-schema.md` (lines 29-75) to include `subtasks_completed`, `phases_completed`, and `phases_total` as top-level fields alongside `continuation_context` *(completed)*
- [x] **Task 3.2**: Add field definitions for `subtasks_completed` (optional array of "{phase}.{step}" strings, cap 20 entries), `phases_completed` (optional integer), and `phases_total` (optional integer) in the Field Definitions section after `continuation_context` (after line 134) *(completed)*
- [x] **Task 3.3**: Update the Token Budget table (lines 138-156) to add a row for `subtasks_completed` (~30 tokens) *(completed)*
- [x] **Task 3.4**: Update the Writing Contract section to document that the agent should populate `subtasks_completed` from its accumulated list of completed subtask IDs (from Phase 1, Task 1.3), and that `phases_completed`/`phases_total` should be written at the top level (not only inside `continuation_context`) *(completed)*
- [x] **Task 3.5**: Update `skill-orchestrate/SKILL.md` handoff reading section (around line 355) to also read `subtasks_completed` from the handoff JSON and log it for dispatch context *(completed)*
- [x] **Task 3.6**: Update the example handoff objects in `handoff-schema.md` (Successful Implementation and Partial Implementation sections) to include the new fields *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/docs/architecture/handoff-schema.md` - Schema, field definitions, token budget, writing contract, examples
- `.claude/skills/skill-orchestrate/SKILL.md` - Read `subtasks_completed` from handoff

**Verification**:
- `subtasks_completed` appears in the JSON schema example as a top-level field
- `phases_completed` and `phases_total` appear as top-level fields (not only in `continuation_context`)
- Field definitions exist for all three new top-level fields
- Token budget table includes `subtasks_completed`
- `skill-orchestrate/SKILL.md` reads `subtasks_completed` from the handoff
- Example handoff objects include the new fields

## Testing & Validation

- [x] Verify `general-implementation-agent.md` Stage 4D-ii contains hard requirement language and checkpoint *(completed)*
- [x] Verify `skill-implementer/SKILL.md` contains Stage 6b-checkbox between 6a and 6b *(completed)*
- [x] Verify `handoff-schema.md` JSON schema includes `subtasks_completed`, `phases_completed`, `phases_total` as top-level fields *(completed)*
- [x] Verify `handoff-schema.md` Field Definitions section documents all three new fields *(completed)*
- [x] Verify `skill-orchestrate/SKILL.md` reads `subtasks_completed` from handoff *(completed)*
- [x] Grep all modified files for consistency: no references to `phases_completed` exist only inside `continuation_context` *(completed)*

## Artifacts & Outputs

- `.claude/agents/general-implementation-agent.md` - Hardened Stage 4D-ii with checkpoint
- `.claude/skills/skill-implementer/SKILL.md` - New Stage 6b-checkbox postflight scan
- `.claude/docs/architecture/handoff-schema.md` - Extended schema with new top-level fields
- `.claude/skills/skill-orchestrate/SKILL.md` - Updated handoff reading for `subtasks_completed`

## Rollback/Contingency

All changes are additive edits to markdown documentation files. To revert: `git revert` the implementation commit. No runtime code or build artifacts are affected. The existing orchestrator handoff reading uses `// 0` and `// []` jq defaults, so the new optional fields are backward-compatible by construction.
