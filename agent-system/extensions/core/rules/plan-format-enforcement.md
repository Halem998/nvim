---
paths: specs/**/plans/**
---

# Plan Format Checklist

Full specification: `.claude/context/formats/plan-format.md`

**Required metadata fields**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type (Markdown block, not YAML frontmatter).

**Required sections**: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency.

**Phase heading format**: `### Phase N: {name} [STATUS]` -- status lives ONLY in the heading. Valid markers: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[COMPLETED WITH EXCLUSIONS]`, `[PARTIAL]`, `[BLOCKED]`. No emojis.

These are the **phase-heading** markers, scoped to a single phase within a plan. They are a
distinct, narrower vocabulary from the plan-level `- **Status**:` field documented in
plan-format.md (which uses `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`
and has no `[IN PROGRESS]` value, and no `[COMPLETED WITH EXCLUSIONS]` value). See
plan-format.md's "Plan-level vs. phase-level markers" subsection for the full rationale behind
the asymmetry.

**`[COMPLETED WITH EXCLUSIONS]` record requirement**: a phase heading carrying
`[COMPLETED WITH EXCLUSIONS]` REQUIRES a `#### Reasoned Exclusions` subsection in the phase body,
with minimum columns `Item | Reason | Evidence` — see plan-format.md's `## Reasoned Exclusions`
section for the full format and status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for
the outcome's five-condition admission test. **Current enforcement level for this checklist
item**: advisory prose only, unless and until `scripts/validate-artifact.sh` grows a
corresponding check — the same advisory-first status the `**Verification Tier**` item documents
for itself below, stated honestly rather than implied.

**Required per-phase fields**: `**Verification Tier**` (required, one of `prose`, `local`,
`interface`, `full`), `**Commit Mode**` (optional, default `per-substep`; the other value is
`atomic-batch`), `**Scope Hypothesis**` (conditional — required whenever the phase asserts a
count, an enumerated file list, or a scope estimate). Both `**Field**:` and `**Field:**`
punctuation forms are accepted. See plan-format.md's `## Verification Tiers` section for the
full vocabulary, blind-spot definitions, and the tie-break-upward rule.

**Current enforcement level**: advisory (warn), not error. `scripts/validate-artifact.sh` checks
each phase's `**Verification Tier**` field individually and emits a warning per untiered phase;
default-mode validation still exits 0 on tier warnings alone, so plans authored before this
vocabulary existed continue to pass. `--strict` mode enforces it today. This is deliberate, not
an oversight — see plan-format.md's "Enforcement level" subsection for the promotion criterion.
