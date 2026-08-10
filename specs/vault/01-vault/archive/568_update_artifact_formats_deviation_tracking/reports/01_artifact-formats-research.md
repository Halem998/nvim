# Research Report: Update Artifact Formats for Deviation Tracking

- **Task**: 568 - Update artifact formats for deviation tracking
- **Started**: 2026-05-13T00:00:00Z
- **Completed**: 2026-05-13T00:30:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `/home/benjamin/.config/nvim/.claude/context/formats/handoff-artifact.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/summary-format.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/progress-file.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/plan-format.md`
  - `/home/benjamin/.config/nvim/.claude/context/patterns/context-exhaustion-detection.md`
  - `/home/benjamin/.config/nvim/.claude/context/patterns/subagent-continuation-loop.md`
  - `/home/benjamin/.config/nvim/.claude/rules/plan-format-enforcement.md`
  - `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
- **Artifacts**: specs/568_update_artifact_formats_deviation_tracking/reports/01_artifact-formats-research.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

---

## Executive Summary

- Five format files define the schema contract for agent behavior: `handoff-artifact.md`, `summary-format.md`, `progress-file.md`, `context-exhaustion-detection.md`, and `plan-format-enforcement.md`. None currently include deviation tracking fields.
- The four behaviors to add (post-phase self-review, progressive handoff updates, deviation annotation in plan, final checkpoint protocol) each map clearly to specific format file additions.
- `handoff-artifact.md` needs a new `## Deviations from Plan` section in the template with structured fields for what was skipped and why.
- `progress-file.md` needs a top-level `deviations` array in the JSON schema to capture per-phase deviations alongside the existing `approaches_tried` array.
- `context-exhaustion-detection.md` needs an explicit "Final Checkpoint Protocol" subsection inserted between the handoff writing steps, requiring the agent to also update the plan file before returning partial status.
- `plan-format-enforcement.md` needs a deviation annotation rule specifying the exact inline syntax for marking skipped or altered checklist items.
- `summary-format.md` needs a new `## Plan Deviations` section (after `## Decisions`) to surface deviations that occurred during implementation.

---

## Context & Scope

Task 568 defines the format-level contract that downstream implementation tasks (569 for general agents, 570 for extension agents) will implement in agent instruction files. The five target format files serve as the authoritative schema documents that agents reference when constructing artifacts. Changes here must be concrete enough for agents reading the format files to know exactly what fields to write, where to write them, and in what syntax.

The four improvements being introduced:

1. **Post-phase self-review** — After completing each phase, agent re-reads the subtask list, verifies all items were addressed, and notes any skipped items.
2. **Progressive handoff updates** — Handoff document is kept current after each phase completion, not only when context exhaustion is imminent.
3. **Deviation annotation in plan** — When a plan step is skipped or altered, the checklist item is annotated inline (not just in a separate log).
4. **Final context-exhaustion checkpoint** — When imminent exhaustion is detected, both the progress file AND the plan file are updated before writing the handoff artifact.

---

## Findings

### handoff-artifact.md — Current State & Proposed Changes

**Current Structure (7 sections in template)**:
```
## Immediate Next Action
## Current State
## Key Decisions Made
## What NOT to Try
## Critical Context (max 5 items)
## References (read only if stuck)
```

The current template captures next action, current file location, decisions, failed approaches, facts, and reference paths. It has no field for plan-level deviations — items that were present in the plan but skipped, altered, or deferred. Successors reading a handoff have no way to know which planned steps were intentionally omitted versus not yet reached.

**Gaps**:
- No field to list plan steps that were skipped during this agent's work
- No field to capture the rationale for those skips
- Handoffs are described as written only on context exhaustion, not proactively after each phase

**Proposed Addition** — Insert `## Deviations from Plan` between `## Key Decisions Made` and `## What NOT to Try`:

```markdown
## Deviations from Plan
- **Skipped**: Task {P}.{N} "{description}" — {reason (one sentence)}
- **Altered**: Task {P}.{N} "{description}" — {what changed and why}
```

If no deviations occurred: `- None`

The section is optional content but must be present in the template as a required structural element (even if populated with `- None`). This keeps handoffs honest and prevents successors from silently re-implementing skipped items.

**Progressive Handoff Requirement** — Add to the template preamble:

> Handoffs should be written (or updated) at the end of each phase, not only when context exhaustion is detected. A phase-end handoff ensures that if context exhaustion occurs at any point, the most recent handoff reflects completed work accurately.

**Integration points in general-implementation-agent.md**:
- Stage 4C (Handoff on Context Pressure) — instructs writing the handoff artifact
- Stage 3 (Stage 3.5 for progress tracking) — this is where phase-end handoff update should also be triggered

---

### summary-format.md — Current State & Proposed Changes

**Current Structure (6 sections)**:
```
## Overview
## What Changed
## Decisions
## Impacts
## Follow-ups
## References
```

**Gaps**:
- No section for capturing deviations from the implementation plan
- `## Decisions` captures choices made during implementation, but does not distinguish between plan-aligned decisions and plan-deviating decisions
- A reviewer reading the summary cannot tell whether the implementation followed the plan faithfully

**Proposed Addition** — Insert `## Plan Deviations` immediately after `## Decisions`:

```markdown
## Plan Deviations
- **Task {P}.{N}** skipped: {reason}
- **Task {P}.{N}** altered: {what changed and why}
```

If no deviations occurred: `- None (implementation followed plan)`

This section aggregates deviations logged per-phase in the progress file into a summary-level view suitable for human review.

---

### progress-file.md — Current State & Proposed Changes

**Current Schema (top-level fields)**:
```json
{
  "phase": integer,
  "phase_name": string,
  "started_at": ISO8601,
  "last_updated": ISO8601,
  "objectives": [{ "id", "description", "status", "note?" }],
  "current_objective": integer,
  "approaches_tried": [{ "approach", "result", "reason" }],
  "handoff_count": integer
}
```

**Gaps**:
- `approaches_tried` captures technical attempts that failed, but there is no field for plan-level deviations (items deliberately skipped, reordered, or implemented differently than specified)
- No mechanism to surface which plan steps were omitted versus pending
- The post-phase self-review behavior has no corresponding schema field

**Proposed Addition** — Add `deviations` array as a top-level field alongside `approaches_tried`:

```json
{
  "deviations": [
    {
      "task_id": "3.2",
      "description": "Brief description of the plan step",
      "type": "skipped" | "altered" | "deferred",
      "reason": "One sentence explanation",
      "annotation": "*(deviation: skipped — reason)*"
    }
  ]
}
```

**Field specifications for each deviation entry**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | string | Yes | Plan task ID (e.g., `"3.2"` for Phase 3, Task 2) |
| `description` | string | Yes | Brief description matching the plan checklist text |
| `type` | enum | Yes | `"skipped"`, `"altered"`, or `"deferred"` |
| `reason` | string | Yes | One-sentence explanation |
| `annotation` | string | Yes | The exact inline annotation text written into the plan file |

**Update Protocol addition** — Add step 2.5 to the existing "Teammates should update the progress file" list:

> 2.5. **After completing a phase (post-phase self-review)**: Re-read the phase task checklist in the plan. For each unchecked item that will not be completed, add a deviation entry. Write deviation annotations into the plan file checklist.

---

### context-exhaustion-detection.md — Current State & Proposed Changes

**Current Handoff Writing Protocol (4 steps)**:
```
1. Update Progress File FIRST
2. Write Handoff Artifact
3. Increment Handoff Count
4. Return Partial with Handoff Path
```

**Gaps**:
- Step 1 updates the progress file, but there is no explicit step to also update the plan file with deviation annotations before handing off
- The "Final checkpoint" scenario (imminent exhaustion when mid-phase) requires updating the plan file checklist annotations so the successor can see the state of checked items
- The Anti-Patterns section correctly warns not to skip the progress file, but says nothing about the plan file

**Proposed Addition** — Insert new step 1.5 between current steps 1 and 2:

```
### 1.5. Annotate Plan File (Final Checkpoint)

Before writing the handoff document, update the plan file to reflect exact current state:

1. For each completed task in the current phase: ensure `- [x]` with `*(completed)*` annotation
2. For the in-progress task (if any): append `*(in progress — handoff)*`
3. For each deviation logged in the progress file: write the deviation annotation inline

This ensures the plan file is a reliable resume point for successors even if the handoff artifact is lost.
```

**Also add to Anti-Patterns section**:

> 6. **Skip plan file annotation at handoff** — If you hand off without annotating the plan file, successors must re-discover which tasks were completed versus pending. Always annotate the plan before handing off.

---

### plan-format-enforcement.md — Current State & Proposed Changes

**Current Content (the complete file)**:
```
---
paths: specs/**/plans/**
---

# Plan Format Checklist

Full specification: `.claude/context/formats/plan-format.md`

**Required metadata fields**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type (Markdown block, not YAML frontmatter).

**Required sections**: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency.

**Phase heading format**: `### Phase N: {name} [STATUS]` -- status lives ONLY in the heading. Valid markers: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`. No emojis.
```

**Gaps**:
- No enforcement rule for checklist item completion annotations
- No rule specifying how deviation annotations should look in plan checklist items
- Agents currently annotate plan items with `*(completed)*` and `*(completed: {note})*` (from `general-implementation-agent.md` Stage 4B-ii), but this convention is not formalized in the enforcement rule

**Proposed Addition** — Append two new sections:

```markdown
**Checklist item annotation format** (when implementing):
- Completed: `- [x] **Task {P}.{N}**: {description} *(completed)*`
- Completed with note: `- [x] **Task {P}.{N}**: {description} *(completed: {brief note})*`
- In progress: `- [ ] **Task {P}.{N}**: {description} *(in progress)*`
- In progress at handoff: `- [ ] **Task {P}.{N}**: {description} *(in progress — handoff)*`

**Deviation annotation format** (when deviating from plan):
- Skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
- Altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
- Deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`
```

The deviation annotation format uses the `*(deviation: ...)*` marker to make deviations machine-parseable and visually distinct from normal completion annotations.

---

## Decisions

1. **Deviation annotation uses `*(deviation: ...)*` not `*(skipped)*`** — The longer form is self-documenting. Agents and humans reading the plan can understand the entry without cross-referencing another document. The `*(completed)*` short form is acceptable for completions because completion is the expected case; deviations require more context.

2. **`deviations` array is separate from `approaches_tried`** — These capture different things. `approaches_tried` is about technical implementation attempts that failed (e.g., "tried regex validation, failed due to performance"). `deviations` is about plan-level intentional changes (e.g., "skipped task 3.2 because it was superseded by task 3.4"). Conflating them would make the progress file harder to parse.

3. **Handoff `## Deviations from Plan` section is always present** — Even when empty (`- None`), the section must appear in the template and in written handoffs. This forces agents to actively confirm there are no deviations rather than silently omitting the section.

4. **Post-phase self-review is a protocol step in `progress-file.md`, not a new agent stage** — Adding it to the progress file update protocol (step 2.5) is the correct contract point. The agent instruction files (tasks 569, 570) implement this by following the format contract.

5. **Progressive handoff updates belong in `handoff-artifact.md` preamble** — The handoff template file is the right place to state the "update after each phase" requirement, since that is where the handoff contract is defined.

---

## Recommendations

Listed in priority order (highest first):

**P1 — `progress-file.md`: Add `deviations` array to schema**
- Add the `deviations` field specification with all four sub-fields
- Add step 2.5 (post-phase self-review) to the Update Protocol
- Add deviation entry to the Example section

**P2 — `plan-format-enforcement.md`: Add deviation annotation format rule**
- Append checklist annotation format section (completed, in-progress, in-progress-at-handoff)
- Append deviation annotation format section with `*(deviation: ...)*` syntax
- This formalizes the convention already partially in use by `general-implementation-agent.md`

**P3 — `handoff-artifact.md`: Add `## Deviations from Plan` section**
- Insert section after `## Key Decisions Made`
- Add template language for skipped and altered items
- Add progressive update note to preamble (update after each phase, not only at exhaustion)

**P4 — `context-exhaustion-detection.md`: Add step 1.5 (Final Checkpoint plan annotation)**
- Insert between step 1 (Update Progress File) and step 2 (Write Handoff Artifact)
- Require annotating completed, in-progress, and deviating plan items before writing handoff
- Add anti-pattern item 6 (skipping plan annotation at handoff)

**P5 — `summary-format.md`: Add `## Plan Deviations` section**
- Insert after `## Decisions`
- Specify format for listing deviations (aggregated from progress file `deviations` array)
- Add to the Example Skeleton

---

## Risks & Mitigations

- **Risk**: Deviation annotation syntax conflicts with existing annotation patterns.
  **Mitigation**: The `*(deviation: ...)*` marker is distinct from `*(completed)*` and `*(completed: ...)*`. No collision possible.

- **Risk**: Adding `deviations` to the progress file schema breaks existing progress files (missing field).
  **Mitigation**: The `deviations` array should be optional (default empty `[]`). Existing progress files without it remain valid.

- **Risk**: The "always present `## Deviations from Plan`" requirement makes handoffs longer.
  **Mitigation**: The section is short (`- None` when empty). The handoff maximum size of ~40 lines still holds. One line for the section heading and one for `- None` = 2 lines overhead at most.

- **Risk**: Task 569 (general agent) and task 570 (extension agents) each need to implement these format changes in their instruction files. If format files are ambiguous, implementations will diverge.
  **Mitigation**: The proposed exact syntax strings (field names, annotation formats, section headings) are unambiguous. The planner for tasks 569/570 should cite this report directly.

---

## Appendix

### File Paths

| File | Location |
|------|----------|
| handoff-artifact.md | `/home/benjamin/.config/nvim/.claude/context/formats/handoff-artifact.md` |
| summary-format.md | `/home/benjamin/.config/nvim/.claude/context/formats/summary-format.md` |
| progress-file.md | `/home/benjamin/.config/nvim/.claude/context/formats/progress-file.md` |
| plan-format.md | `/home/benjamin/.config/nvim/.claude/context/formats/plan-format.md` |
| context-exhaustion-detection.md | `/home/benjamin/.config/nvim/.claude/context/patterns/context-exhaustion-detection.md` |
| subagent-continuation-loop.md | `/home/benjamin/.config/nvim/.claude/context/patterns/subagent-continuation-loop.md` |
| plan-format-enforcement.md | `/home/benjamin/.config/nvim/.claude/rules/plan-format-enforcement.md` |
| general-implementation-agent.md | `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` |

### Key Existing Convention (from general-implementation-agent.md Stage 4B-ii)

The implementation agent already partially defines annotation syntax:
```
- [x] **Task {P}.{N}**: {description} *(completed)*
- [x] **Task {P}.{N}**: {description} *(completed: {brief note})*
- [ ] **Task {P}.{N}**: {description} *(in progress)*
```

This research formalizes this into `plan-format-enforcement.md` and extends it with the `*(deviation: ...)*` pattern.

### Current handoff-artifact.md Template Section Order

```
## Immediate Next Action
## Current State
## Key Decisions Made
[INSERT: ## Deviations from Plan]
## What NOT to Try
## Critical Context (max 5 items)
## References (read only if stuck)
```

### Existing context-exhaustion-detection.md Handoff Protocol Step Order

```
1. Update Progress File FIRST
[INSERT: 1.5. Annotate Plan File (Final Checkpoint)]
2. Write Handoff Artifact
3. Increment Handoff Count
4. Return Partial with Handoff Path
```
