# Plan Artifact Standard

**Scope:** All plan artifacts produced by /plan, /revise, /implement (phase planning), /review (when drafting follow-on work), and related agents.

## Metadata (Markdown block, required)
- Use a single **Status** field with status markers (`[NOT STARTED]`, `[IMPLEMENTING]`, `[PARTIAL]`, `[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]`) per status-markers.md.
- Do **not** use YAML front matter. Use a Markdown metadata block at the top of the plan.
- Required fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type.
- Status timestamps belong where transitions happen (e.g., in phases or a short Started/Completed line under the status). Avoid null placeholder fields.
- Standards must reference this file plus status-markers.md, artifact-management.md, and tasks.md.

### Example Metadata Block
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: markdown
```

## Plan Metadata Schema

Plans may include a `plan_metadata` object in state.json with fields: `phases` (int), `total_effort_hours` (int), `complexity` (simple/medium/complex), `research_integrated` (bool), `plan_version` (int), `dependency_waves` (array of phase-number arrays for parallel execution groups), and `reports_integrated` (array of `{path, integrated_in_plan_version, integrated_date}` objects). Plans without `reports_integrated` use empty array default.

**Hard-mode skeleton fields** (`--hard` plans only, optional otherwise): `skeleton` (bool, default
`false`) — `true` when this plan's critical path ends in one or more planned strategic-sorry
division points instead of covering full scope with more/larger phases; `follow_up_tasks` (array
of int, default `[]`) — the real, allocated (plain-integer, never dotted) task numbers of the
follow-up tasks created to discharge those division points. Both fields are populated by
`skill-planner-hard` postflight after `{{FOLLOWUP:i}}` placeholder-token substitution (see
`planner-hard-agent.md` Stage 4a); the field name `skeleton` reuses `wrap-up.md`'s implement-time
`skeleton` boolean verbatim so plan-time intent and implement-time outcome are diffable.

```json
{
  "phases": 5,
  "total_effort_hours": 8,
  "complexity": "medium",
  "research_integrated": true,
  "plan_version": 1,
  "dependency_waves": [[1], [2, 3], [4, 5]],
  "reports_integrated": [
    {
      "path": "reports/01_{short-slug}.md",
      "integrated_in_plan_version": 1,
      "integrated_date": "2026-01-05"
    }
  ],
  "skeleton": false,
  "follow_up_tasks": []
}
```

## Structure
1. **Overview** – 2-4 sentences: problem, scope, constraints, definition of done. May include "Research Integration" subsection listing integrated reports.
2. **Goals & Non-Goals** – bullets.
3. **Risks & Mitigations** – bullets.
4. **Implementation Phases** – under `## Implementation Phases`, preceded by a **Dependency Analysis** wave table (see below), with each phase at level `###` and including a status marker at the end of the heading.
5. **Planned Strategic Sorries** (hard-mode skeleton plans only) – under `## Planned Strategic Sorries`, present only when `plan_metadata.skeleton: true`; see below.
6. **Testing & Validation** – bullets/tests to run.
7. **Artifacts & Outputs** – enumerate expected outputs with paths.
8. **Rollback/Contingency** – brief plan if changes must be reverted.

## Implementation Phases (format)
- Heading: `### Phase N: {name} [STATUS]`
- Under each phase include:
  - **Goal:** short statement
  - **Tasks:** bullet checklist
  - **Timing:** expected duration or window
  - **Depends on:** phase numbers this phase requires (e.g., `none`, `1`, `1, 3`). Absence means sequential (depends on all prior phases).
  - **Owner:** (optional)
  - **Started/Completed/Blocked/Abandoned:** timestamp lines when status changes (ISO8601). Do not leave null placeholders.

## Dependency Analysis (format)

Place a **Dependency Analysis** wave table immediately after `## Implementation Phases` and before the first `### Phase`. Columns: **Wave** (execution order), **Phases** (can run in parallel within wave), **Blocked by** (prerequisite phases, `--` for none). Generate from per-phase `Depends on` fields. For fully sequential plans, each wave contains one phase.

```
**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.
```

## Planned Strategic Sorries (format, hard-mode skeleton plans only)

Present only when `plan_metadata.skeleton: true` (see Plan Metadata Schema above). Placed
immediately after `## Implementation Phases`. Its columns map field-for-field to the `wrap-up.md`
`sorry_inventory` schema `{file, line, statement, strategic, assumption, why_deferred,
follow_up_task}` — reuse these field names verbatim; do not redefine, rename, or invent a
parallel schema. `strategic` is not a column because every row in this table is, by definition,
a planned strategic-sorry division point (`strategic: true` is implicit for the whole table).

```
## Planned Strategic Sorries

| Division Point | File / Line / Statement | Assumption | Why Deferred | Follow-Up Task |
|-----------------|--------------------------|------------|---------------|----------------|
| {short label}   | TBD (plan-time provisional; confirmed by implementer) | {assumption} | {why_deferred} | {{FOLLOWUP:i}} |
```

- **Division Point**: short label identifying the division point (not a `sorry_inventory` field
  itself; provided for readability/cross-reference from phase text).
- **File / Line / Statement**: plan-time provisional, collapsed into one cell — write `TBD` (or a
  best-guess target file) until the implementer places the actual sorry and fills in `file`/
  `line`/`statement` in the implement-time `sorry_inventory`.
- **Assumption**: maps to `sorry_inventory.assumption` — fixed at plan time.
- **Why Deferred**: maps to `sorry_inventory.why_deferred` — fixed at plan time.
- **Follow-Up Task**: maps to `sorry_inventory.follow_up_task` — a plain-integer task-number
  string once resolved (never dotted, e.g. never `"774.2"`); written as the literal placeholder
  token `{{FOLLOWUP:i}}` by the planning agent and substituted by `skill-planner-hard` postflight
  with the real allocated task number.

**Deviation flag**: An implementer-placed strategic sorry that does NOT correspond to a row on
this table is a plan-unanticipated deviation. It is evaluated under a weaker claim on the
`anti-analysis.md` 5-condition strategic-sorry test's condition 1 (not pre-declared) and MUST be
flagged in the implementation summary, not silently accepted as equivalent to a planned one.

## Status Marker Requirements
- Use markers exactly as defined in status-markers.md.
- Every phase starts as `[NOT STARTED]` and progresses through valid transitions.
- Include timestamps when transitions occur; avoid null/empty metadata fields.
- Do not use emojis in headings or markers.

### Plan-level vs. phase-level markers

The plan-level **Status** field (Metadata block, above) and the per-phase heading marker
(`### Phase N: {name} [STATUS]`, Implementation Phases format, above) are two distinct
vocabularies at two distinct grains, and their divergence is intentional, not an oversight:

- Plan-level Status uses the six markers `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED,
  ABANDONED, COMPLETED}` — a subset of the fuller task-level vocabulary defined in
  status-markers.md.
- `ABANDONED` is deliberately plan/task-level only. No code path abandons a single phase while
  leaving sibling phases active — abandonment is a whole-document decision, so phase headings
  have no `[ABANDONED]` marker.
- Plan-level `[PARTIAL]` is an aggregate "this document is stalled/resumable" signal covering the
  whole plan. It is distinct from, and fully compatible with, any individual phase heading
  simultaneously carrying its own `[PARTIAL]` marker (e.g. a phase interrupted by context
  exhaustion) — the two `PARTIAL`s describe different grains of the same document and do not need
  to move together.

See status-markers.md for the full task-level vocabulary and the cross-reference to this
subsection.

## Writing Guidance
- Keep phases small (1-2 hours each) per task-breakdown guidelines.
- Be explicit about dependencies and external inputs.
- Include lazy directory creation guardrail: commands/agents create the project root and `plans/` only when writing this artifact; do not pre-create `reports/` or `summaries/`.
- Keep language concise and directive; avoid emojis and informal tone.

## Example Skeleton
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md (this file)
- **Standards**: plan.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: markdown

## Overview
{summary}

## Goals & Non-Goals
- **Goals**: ...
- **Non-Goals**: ...

## Risks & Mitigations
- Risk: ... Mitigation: ...

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: {name} [NOT STARTED]
- **Goal:** ...
- **Tasks:**
  - [ ] ...
- **Timing:** ...
- **Depends on:** none

### Phase 2: ... [NOT STARTED]
- **Depends on:** 1
...

## Testing & Validation
- [ ] ...

## Artifacts & Outputs
- plans/MM_{short-slug}.md
- summaries/NN_{short-slug}-summary.md

## Rollback/Contingency
- ...
```
