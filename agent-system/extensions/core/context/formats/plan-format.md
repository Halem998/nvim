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
- Valid `[STATUS]` values: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`,
  `[COMPLETED WITH EXCLUSIONS]`, `[PARTIAL]`, `[BLOCKED]`. See "Plan-level vs. phase-level
  markers" below for the three-way distinction between `[COMPLETED]`, `[PARTIAL]`, and
  `[COMPLETED WITH EXCLUSIONS]`, and status-markers.md's `[COMPLETED WITH EXCLUSIONS]`
  subsection for the full outcome definition and admission test.
- Under each phase include:
  - **Goal:** short statement
  - **Tasks:** bullet checklist
  - **Timing:** expected duration or window
  - **Depends on:** phase numbers this phase requires (e.g., `none`, `1`, `1, 3`). Absence means sequential (depends on all prior phases).
  - **Verification Tier:** (required) one of `prose`, `local`, `interface`, `full` — see
    `## Verification Tiers` below for the full vocabulary and blind-spot definitions.
  - **Commit Mode:** (optional, default `per-substep`) `per-substep` or `atomic-batch` — see
    `## Verification Tiers` below.
  - **Scope Hypothesis:** (conditional — required whenever the phase asserts a count, an
    enumerated file list, or a scope estimate) — see `## Verification Tiers` below.
  - **Owner:** (optional)
  - **Started/Completed/Blocked/Abandoned:** timestamp lines when status changes (ISO8601). Do not leave null placeholders.

**Field-punctuation tolerance**: generator sites in this codebase use two conventions for phase
field labels — `**Field:**` (colon inside the bold) and `**Field**:` (colon outside the bold).
Both forms are accepted for every per-phase field above, including `**Verification Tier**:` /
`**Verification Tier:**`; do not treat one form as invalid because a generator site used the
other.

**Consumers of this heading contract**: the exact `### Phase N: {name} [STATUS]` shape above is
parsed by three independent mechanisms, so a future change to the format must account for all
three: `update-phase-status.sh` (mutates a single phase's status in place), `update-plan-status.sh`
(the plan-level status-field equivalent), and `update-task-status.sh`'s opt-in `--phase-check`
backstop (counts conforming headings across the whole plan to decide whether an implement
postflight transition may proceed). All three treat this heading — never the `- [ ]`/`- [x]`
task checklist — as the authoritative phase-completion signal.

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

## Verification Tiers

Every phase declares how broadly verification must run *during* the phase, matched to what its
edit class can actually break. This replaces an implicit "one strictness for everything" default
that made a comment-only phase pay a full-build-per-file toll. The tier set is **named and
ordered** — not numeric — so it cannot collide in polarity with the numeric Tier 1/2/3 system in
`context/contracts/reference-grounding.md` (where Tier 1 is strictest; see that file's
cross-reference note for how the two systems relate):

    prose  <  local  <  interface  <  full

Every tier below the top states what it does NOT cover, so a reader can see exactly what the
final gate remains responsible for catching.

| Tier | Applies to | In-phase verification | Does NOT cover (blind spot) |
|------|------------|------------------------|------------------------------|
| `prose` | Edits confined to comments, docstrings, markdown/prose, and other non-code text with zero compile or elaboration surface | Diff read-through confirming every changed hunk lies inside a comment/string/prose region | An edit that crosses out of the comment or string boundary; a doc-comment that is actually load-bearing (doctest, attribute, annotation, pragma) and does compile; broken cross-references or links |
| `local` | Edits confined to one module/file with no change to any externally visible signature | Build or lint of that single module only | Dynamic, untyped, or reflective call sites; behavior changes visible to other modules through unchanged signatures; downstream test failures; anything requiring the full test suite |
| `interface` | Changes a symbol's name, type, arity, or argument order where call sites span multiple files | Build of the changed module plus its enumerated direct dependents | Transitive breakage beyond the enumerated one-hop dependent set; semantic (non-type-level) downstream behavior change; the full test suite; import-graph and init-level checks |
| `full` | Edits that can change runtime, proof, or elaboration behavior anywhere: shared tactics, core types, global config | The complete gate set for the repository | Nothing is deferred past this tier. This is the ceiling |

**Tie-break rule**: When uncertain, apply the strictest applicable tier (full > interface > local > prose).

**Non-negotiable invariant**: tiering governs GRANULARITY ONLY — how often and how broadly
verification runs *during* a phase. The full gate set still runs before a phase closes and before
a task completes, unchanged. `full` is textually identical in strictness to today's existing
requirement; tiers `prose`, `local`, and `interface` are added *below* it and redefine nothing
about it. A tiering scheme that weakens the final gate is wrong, not a trade-off.

### Commit modes

An orthogonal axis: a tier answers *how broad* verification must be; commit mode answers *at
what commit boundary* it is taken. The two fields are independent — `prose` + `atomic-batch` and
`interface` + `atomic-batch` are both legitimate combinations.

- `per-substep` (default): the existing Commit-Per-Green-Substep Mandate applies unchanged. See
  `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` section, the authoritative
  home of this mode's rules.
- `atomic-batch`: the phase's declared file set is one `progress-file.md` objective; intermediate
  per-file states are expected red and MUST NOT be committed. See `rules/git-workflow.md`'s
  `### Commit-Per-Green-Substep Mandate` section for the full carve-out, including the
  anti-abuse guard against retroactively widening a batch — this document does not restate that
  language, so the two cannot drift into conflict.

### Counts-are-hypotheses obligation

Any count, file list, or scope estimate asserted in a plan is a hypothesis requiring
implementation-time confirmation, never a fact. When a phase asserts one, it carries a
**Scope Hypothesis:** line stating the hypothesis and how to confirm it at implementation time.
The implementation-side gate that consumes this obligation (i.e., that mechanically checks a
confirmation happened) is a separate, out-of-scope concern for this document — this section
defines the planner-side carrier field only.

### Enforcement level

Per-phase tier enforcement in `scripts/validate-artifact.sh` is **advisory-first**: a missing
`**Verification Tier**:` field emits a warning, not an error, so default-mode validation of
plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it
today. **Promotion criterion**: promote the warning to an error once no non-terminal plan under
`specs/` lacks the field. This is recorded here for a future task to execute; it is not done by
the task that introduced this vocabulary.

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

## Reasoned Exclusions (format)

Present whenever a phase heading carries `[COMPLETED WITH EXCLUSIONS]` (see
status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for the outcome's semantics and
five-condition admission test). Unlike `## Planned Strategic Sorries` above, this record is a
**per-phase subsection nested at `####` inside the phase body** — not a document-level `##`
section — because exclusions are phase-scoped by definition, whereas a skeleton's sorries span
phases.

```
#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| {the excluded item} | {why it is not applicable} | {what confirms the reason -- command output, quoted match count, diff excerpt, or artifact reference} |
```

**Required**: this subsection is REQUIRED whenever the phase heading carries
`[COMPLETED WITH EXCLUSIONS]`. Its minimum columns are `Item`, `Reason`, `Evidence`.

**Field mapping to `sorry_inventory`**: this table is a field-for-field generalization of the
`wrap-up.md` `sorry_inventory` schema, so the family reads as one concept:
- `Item` generalizes `file`/`line`/`statement` to any domain — not every excluded item is a code
  location.
- `Reason` generalizes `assumption` + `why_deferred` into a single justification column.
- `Evidence` is the new obligation with no sorry-side counterpart: a sorry is *tracked* by a
  `follow_up_task`; an exclusion is *closed* by evidence instead.

`follow_up_task` is deliberately absent from this table. Its absence is the defining difference
between the two family members: a strategic sorry is deferred with a tracked follow-up, a
reasoned exclusion is decided and will not be revisited, so there is nothing to track.

**Relationship to Scope Hypothesis**: a reasoned exclusion is structurally the closing act of a
**Scope Hypothesis** (see "Counts-are-hypotheses obligation" above) whose asserted count turned
out to be an overcount — the Evidence column is where that confirmation lands. The record may be
written at plan time, as a pre-emptive declaration alongside the phase's Scope Hypothesis line, or
discovered mid-phase at implement time, with implement-time entries confirming or superseding any
plan-time hypothesis.

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
- Phase-heading markers additionally include `[COMPLETED WITH EXCLUSIONS]`, a phase-heading-only
  outcome absent from both the task-level vocabulary and the plan-level Status subset above. The
  three-way distinction: `[COMPLETED]` = nothing was excluded; `[PARTIAL]` = work remains and is
  resumable; `[COMPLETED WITH EXCLUSIONS]` = every remaining item was decided, justified, and will
  not be revisited. See status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for the full
  admission test and `## Reasoned Exclusions` above for its required record format.

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
- **Verification Tier:** local

### Phase 2: ... [NOT STARTED]
- **Depends on:** 1
- **Verification Tier:** interface
- **Commit Mode:** atomic-batch
...

## Testing & Validation
- [ ] ...

## Artifacts & Outputs
- plans/MM_{short-slug}.md
- summaries/NN_{short-slug}-summary.md

## Rollback/Contingency
- ...
```
