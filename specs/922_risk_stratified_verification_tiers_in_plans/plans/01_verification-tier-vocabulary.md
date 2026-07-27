# Implementation Plan: Task #922

- **Task**: 922 - risk_stratified_verification_tiers_in_plans
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/922_risk_stratified_verification_tiers_in_plans/reports/01_verification-tier-source-store-findings.md
- **Artifacts**: plans/01_verification-tier-vocabulary.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Introduce a risk-stratified verification vocabulary into the plan format so that a phase can
declare how broadly verification must run *during* the phase, matched to what its edit class can
actually break — replacing today's implicit "one strictness for everything" default that made a
comment-only phase pay a full-build-per-file toll. Alongside the tier axis, add an orthogonal
commit-mode axis that makes an atomic multi-file refactor *expressible* (today's
Commit-Per-Green-Substep Mandate structurally forbids one, because every intermediate state of a
cross-file rename is necessarily red). The tier vocabulary lands in `context/formats/plan-format.md`
as the authoritative spec, propagates to all six phase-template restatement sites, gets a
carve-out inside `rules/git-workflow.md`'s mandate section itself, and gains real per-phase
enforcement in `scripts/validate-artifact.sh`. Definition of done: every one of the six template
sites carries the new field, the git rule permits declared atomic batches, the validator iterates
per-phase-block, and the final gate is textually unchanged in strictness.

**Source-store rule**: every edit in this plan targets `agent-system/extensions/core/**`. No phase
writes to `.claude/**` — that tree is a gitignored, disposable deploy artifact.

### Research Integration

- Finding A (confirmed): `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` defines
  a sub-step as "a `progress-file.md` objective transitioning to `status: \"done\"`". This
  definition is already unit-agnostic, so the carve-out is a clarification-plus-permission inside
  that section, not a contradiction of it. Phase 2 edits that section directly.
- Finding B (six sites, not five): `docs/guides/user-guide.md` is a sixth restatement site using a
  third field-naming convention (`**Steps**:` rather than `**Tasks**:`). All six are enumerated as
  explicit touch points across Phases 1, 3, and 4. Decision: update all six.
- Finding C (confirmed and sharpened): `validate-artifact.sh` has only whole-document
  `grep -qF`/`grep -qE` existence checks. Per-phase enforcement needs new
  loop-over-phase-blocks logic. Phase 5 is dedicated to it and is sequenced last among the
  content phases.
- index-entries.json drift: `formats/plan-format.md` records `line_count: 136` against an actual
  222. Phase 6 corrects it and re-checks `workflows/task-breakdown.md` (270, currently accurate)
  and `contracts/reference-grounding.md` (94).
- Tie-break-upward precedent: `context/contracts/reference-grounding.md` already states "When
  uncertain, apply the highest applicable tier (Tier 1 > Tier 2 > Tier 3)." The new rule mirrors
  that sentence shape and its `>`-chain polarity convention rather than inventing new phrasing.
- The research report's 5-tier (0-4) proposal is evaluated and revised below (Decisions D1, D2).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Decisions (made at plan time; implementer follows, does not re-litigate)

**D1 — Named ordered tiers, not numeric tiers.** The research proposal numbers tiers 0-4 with
strictness increasing upward. `context/contracts/reference-grounding.md` already runs a numeric
tier system in the *opposite* polarity (Tier 1 is strictest). Two numeric tier systems of opposite
polarity in the same context tree is a live confusion hazard, and the word "upward" in the
tie-break rule would mean opposite things in each. The tier set is therefore **named and ordered**:

    prose  <  local  <  interface  <  full

The tie-break sentence mirrors reference-grounding's `>`-chain convention exactly, so the leftmost
term in the chain is always the one selected under uncertainty:
*"When uncertain, apply the strictest applicable tier (full > interface > local > prose)."*

**D2 — Atomic multi-file batch is an ORTHOGONAL commit mode, not a tier.** The research report's
own blind-spot cell for its proposed Tier 3 concedes it adds "nothing structurally new vs. Tier 2's
blind spot — it only changes *when* the gate runs." That is the tell: a tier answers *how broad
must the check be*; atomic-batch answers *at what commit boundary may the check be taken*. They are
independent — an atomic batch of comment-only edits is legitimately `prose` + batch, while an
atomic rename batch is `interface` + batch. Folding it into the ordinal set would force a false
coupling and make the ordering non-total (there is no meaningful answer to "is atomic-batch
stricter than interface?"). Therefore two separate per-phase fields:

- `**Verification Tier**:` — required, one of `prose | local | interface | full`
- `**Commit Mode**:` — optional, `per-substep` (default) or `atomic-batch`

This also makes the git-workflow carve-out clean: it keys on `Commit Mode: atomic-batch`, an
explicit declaration, rather than on a tier ordinal.

**D3 — Advisory-first enforcement, with a stated promotion criterion.** Making the per-phase field
a hard `log_error` immediately would fail `validate-artifact.sh` for every existing plan in
`specs/`, and `hooks/validate-plan-write.sh` re-runs the validator on *every* plan Write/Edit —
including edits to in-flight plans authored before this task. That would emit an "ARTIFACT
VALIDATION FAILED" corrective message on legitimate resumption of existing work. So:

- Validator: per-phase tier check emits `log_warn`, not `log_error`. Default mode still exits 0,
  so the hook stays silent for legacy plans; `--strict` mode (which already computes
  `total_issues=$((errors + warnings))`) enforces it today for any caller that opts in. No new
  graduation machinery is needed — the lever already exists in the script.
- Real authoring-time enforcement lives in the planner agent contracts instead: `planner-agent.md`
  Stage 6a already re-reads the plan and verifies required fields before writing success metadata.
  Adding the tier field to that checklist means newly authored plans carry it while legacy plans
  are not invalidated.
- **Promotion criterion** (recorded in `plan-format.md`, executed by a future task, not this one):
  promote the warn to an error once no non-terminal plan under `specs/` lacks the field.

**D4 — Counts-are-hypotheses carrier field.** Per-phase `**Scope Hypothesis**:`, conditionally
required: present whenever a phase asserts any count, file-list enumeration, or scope estimate.
This task delivers only the planner-side obligation and the carrier field. The implementation-side
gate that *consumes* the obligation is an explicitly separate sibling task and is out of scope
here — the plan must not attempt to design that consumer.

**D5 — All six restatement sites are updated**, including `docs/guides/user-guide.md`. A field
present in some generated plans and absent in others depending on which agent or skill produced
them is the exact failure mode the propagation work exists to prevent.

**D6 — A cross-reference note is added to `reference-grounding.md`.** One or two sentences
acknowledging the sibling tier system and the shared tie-break-upward design, so future readers do
not treat the two as unrelated. The vocabulary itself stays in `plan-format.md`; no new context
file is created (keeps `index-entries.json` churn minimal and avoids a third place to look).

**D7 — Field-punctuation tolerance is mandatory in the validator.** The codebase uses two
conventions for phase field labels: `**Goal:**` (colon inside the bold, used in
`plan-format.md` and `task-breakdown.md`) and `**Goal**:` (colon outside, used in
`planner-agent.md`, `skill-team-plan/SKILL.md`, `user-guide.md`). The validator's existing
metadata loop greps `**${field}**:` — the colon-outside form only. A per-phase check written to
match only one form would silently under-enforce against half the generator sites. The new check
MUST accept both `**Verification Tier**:` and `**Verification Tier:**`.

### The tier vocabulary (authoritative content for Phase 1)

Every tier below the top states what it does NOT cover, so a reader can see exactly what the final
gate remains responsible for catching.

| Tier | Applies to | In-phase verification | Does NOT cover (blind spot) |
|------|------------|------------------------|------------------------------|
| `prose` | Edits confined to comments, docstrings, markdown/prose, and other non-code text with zero compile or elaboration surface | Diff read-through confirming every changed hunk lies inside a comment/string/prose region | An edit that crosses out of the comment or string boundary; a doc-comment that is actually load-bearing (doctest, attribute, annotation, pragma) and does compile; broken cross-references or links |
| `local` | Edits confined to one module/file with no change to any externally visible signature | Build or lint of that single module only | Dynamic, untyped, or reflective call sites; behavior changes visible to other modules through unchanged signatures; downstream test failures; anything requiring the full test suite |
| `interface` | Changes a symbol's name, type, arity, or argument order where call sites span multiple files | Build of the changed module plus its enumerated direct dependents | Transitive breakage beyond the enumerated one-hop dependent set; semantic (non-type-level) downstream behavior change; the full test suite; import-graph and init-level checks |
| `full` | Edits that can change runtime, proof, or elaboration behavior anywhere: shared tactics, core types, global config | The complete gate set for the repository | Nothing is deferred past this tier. This is the ceiling |

**Non-negotiable invariant, to be stated verbatim in `plan-format.md`**: tiering governs
GRANULARITY ONLY — how often and how broadly verification runs *during* a phase. The full gate set
still runs before a phase closes and before a task completes, unchanged. `full` is textually
identical in strictness to today's existing requirement; tiers `prose`, `local`, and `interface`
are added *below* it and redefine nothing about it. A tiering scheme that weakens the final gate is
wrong, not a trade-off.

**Commit modes**:

- `per-substep` (default): existing Commit-Per-Green-Substep Mandate applies unchanged.
- `atomic-batch`: the phase's declared file set is ONE `progress-file.md` objective. Intermediate
  per-file states are expected to be red and MUST NOT be committed. The objective's own green
  criterion is the batch-level verification at the phase's declared tier; one commit covers the
  whole batch. The batch must be declared in the plan in advance — an implementer may not
  retroactively widen a batch to avoid committing.

## Goals & Non-Goals

**Goals**:
- Define an ordered, named verification-tier vocabulary with explicit per-tier blind spots in
  `context/formats/plan-format.md`.
- Add `**Verification Tier**:`, `**Commit Mode**:`, and `**Scope Hypothesis**:` to the phase
  template and propagate to all six restatement sites.
- State the tie-break-upward rule in both the format doc and the planner agent contracts.
- Land the atomic-batch carve-out inside `rules/git-workflow.md`'s Commit-Per-Green-Substep
  Mandate section itself.
- Deliver the planner-side counts-are-hypotheses obligation and its carrier field.
- Add genuine per-phase-block iteration to `scripts/validate-artifact.sh` and sync
  `rules/plan-format-enforcement.md`.
- Correct `index-entries.json` line counts for every touched indexed file.

**Non-Goals**:
- Designing or implementing the implementation-side gate that consumes the counts-are-hypotheses
  obligation. That is a separate sibling task.
- Weakening, deferring, or reinterpreting the final gate in any way.
- Creating a new context file for the tier vocabulary (D6).
- Changing `hooks/validate-plan-write.sh` behavior or making it surface warnings.
- Editing anything under `.claude/**`.
- Retrofitting the new field into existing plans under `specs/`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Field lands in only the two most visible sites; generated plans are inconsistent | H | M | Phases 1, 3, 4 enumerate all six sites as named touch points; Phase 6 verification greps all six for the field |
| Carve-out lands only in plan-format.md, so git-workflow still demands intra-batch green commits | H | M | Phase 2 is a dedicated phase that edits the `### Commit-Per-Green-Substep Mandate` section itself; its verification asserts the carve-out text is inside that section's line range |
| Per-phase validator check written as a whole-document grep, silently passing when one phase of five is tiered | H | M | Phase 5 verification includes a negative fixture: a synthetic two-phase plan where only phase 1 carries the tier must produce exactly one warning |
| Validator matches only one field-punctuation convention, under-enforcing against half the generators | M | H | D7; Phase 5 verification includes fixtures using both `**Verification Tier**:` and `**Verification Tier:**` |
| Making the field a hard error invalidates every existing plan and fires the PostToolUse hook on legitimate resumption | H | H | D3 advisory-first: `log_warn`, not `log_error`; `--strict` provides opt-in enforcement today; promotion criterion recorded |
| Tier vocabulary read as a weakening of the final gate | H | L | Non-negotiable invariant stated verbatim in plan-format.md; every sub-top tier carries a stated blind spot; Phase 6 verification greps for the invariant sentence |
| Numeric-tier polarity collision with reference-grounding's Tier 1 > Tier 2 > Tier 3 | M | M | D1 named tiers; D6 cross-reference note in reference-grounding.md |
| Edits accidentally target the gitignored `.claude/**` deploy tree | H | L | Every phase's verification asserts `git status --porcelain` shows changes only under `agent-system/` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1, 3, 4 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint file sets
and may be dispatched concurrently with explicit territory ownership.

Note on the per-phase `**Verification Tier**:` fields below: this plan dogfoods the vocabulary it
introduces. The fields are authored before `plan-format.md` defines them, which is intentional —
`validate-artifact.sh` ignores unrecognized fields, so this is harmless and demonstrates the target
shape to the implementer.

---

### Phase 1: Define the tier vocabulary in plan-format.md [COMPLETED]

**Goal**: Establish `context/formats/plan-format.md` as the authoritative spec for the verification
tier vocabulary, the commit-mode axis, the tie-break-upward rule, the final-gate invariant, and the
three new per-phase fields.

**Tasks**:
- [x] Add a new `## Verification Tiers` section, placed after `## Dependency Analysis (format)`
      and before `## Planned Strategic Sorries (format, ...)`. Contents: the four-row tier table
      from this plan's Decisions section verbatim, including the "Does NOT cover" column for
      `prose`, `local`, and `interface`.
- [x] In that section, state the tie-break-upward rule mirroring
      `context/contracts/reference-grounding.md`'s existing phrasing: "When uncertain, apply the
      strictest applicable tier (full > interface > local > prose)."
- [x] In that section, state the non-negotiable final-gate invariant verbatim (tiering governs
      granularity only; the full gate set still runs before a phase closes and before a task
      completes; `full` is unchanged in strictness).
- [x] In that section, define the two commit modes `per-substep` (default) and `atomic-batch`,
      and cross-reference `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` as the
      authoritative home of the carve-out. Do not restate the git rule's language here — point
      at it, so the two cannot drift into conflict.
- [x] In that section, state the counts-are-hypotheses obligation: any count, file list, or scope
      estimate asserted in a plan is a hypothesis requiring implementation-time confirmation, never
      a fact. Note that the implementation-side consuming gate is out of scope for this document.
- [x] In that section, record the advisory-first enforcement decision and its promotion criterion
      (D3), so a future reader knows the warn level is deliberate and temporary.
- [x] In `## Implementation Phases (format)`, add three bullets to the per-phase field list,
      immediately after `**Depends on:**`:
      `**Verification Tier:**` (required, one of the four values),
      `**Commit Mode:**` (optional, default `per-substep`),
      `**Scope Hypothesis:**` (conditional — required whenever the phase asserts a count, an
      enumerated file list, or a scope estimate).
- [x] Note in the field list that both `**Field**:` and `**Field:**` punctuation forms are
      accepted, since generator sites differ (D7).
- [x] Update the `## Example Skeleton` block so Phase 1 of the skeleton carries
      `**Verification Tier:**` and Phase 2 demonstrates `**Commit Mode:** atomic-batch`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` — new `## Verification Tiers`
  section; three new bullets in `## Implementation Phases (format)`; updated `## Example Skeleton`

**Verification**:
- `grep -c '^## Verification Tiers' agent-system/extensions/core/context/formats/plan-format.md`
  returns 1.
- All four tier names `prose`, `local`, `interface`, `full` appear in the new table, and the table
  has a "Does NOT cover" (or equivalently named blind-spot) column populated for the three
  sub-top tiers.
- The tie-break sentence containing `full > interface > local > prose` is present.
- The final-gate invariant sentence is present.
- `**Verification Tier` appears in both the field list and the Example Skeleton.
- `git status --porcelain` shows changes only under `agent-system/`.

---

### Phase 2: Atomic-batch carve-out in git-workflow.md [COMPLETED]

**Goal**: Make an atomic multi-file refactor expressible by landing the carve-out inside the
`### Commit-Per-Green-Substep Mandate` section itself, so the mandate cannot be read as demanding a
green commit at each intra-batch file edit.

**Tasks**:
- [x] In `rules/git-workflow.md`, inside `### Commit-Per-Green-Substep Mandate`, add a new bullet
      (placed after the `**"Green" means verified, not merely attempted"**` bullet and before
      `**Staging reuses the existing `implement` scope verbatim**`) titled along the lines of
      `**Atomic-batch objectives**`.
- [x] Bullet content must establish: a plan may declare a phase `Commit Mode: atomic-batch`; in
      that case the sub-step IS the whole batch — one `progress-file.md` objective spanning the
      declared file set; intermediate per-file states are expected red and MUST NOT be committed;
      the objective's green criterion is the batch-level verification at the phase's declared tier;
      one commit covers the batch.
- [x] State explicitly that this is consistent with, not an exception to, the existing definition
      of a sub-step as "a `progress-file.md` objective transitioning to `status: \"done\"`" — the
      definition was already unit-agnostic; this bullet makes the multi-file case explicit.
- [x] State the anti-abuse guard: the batch must be declared in the plan in advance; an implementer
      may NOT retroactively widen a batch to avoid committing green work.
- [x] Cross-reference `plan-format.md`'s `## Verification Tiers` section as the home of the
      `Commit Mode` field definition.
- [x] Confirm the existing "Do Not Commit / Partial or incomplete work" bullet does not contradict
      the carve-out; if it reads as forbidding a declared atomic batch, add a one-clause pointer to
      the carve-out rather than rewriting the bullet.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` — new bullet inside
  `### Commit-Per-Green-Substep Mandate`

**Verification**:
- Extract the line range from `### Commit-Per-Green-Substep Mandate` to the next `##`/`###`
  heading, and confirm the string `atomic-batch` appears **inside** that range — not merely
  somewhere in the file. This is the whole point of the phase.
- The words "declared in the plan in advance" (or equivalent anti-retroactive-widening language)
  are present.
- The existing verbatim quotes "Every verified-green sub-step is committed as it happens" and
  "a `progress-file.md` objective transitioning to `status: \"done\"`" are still present and
  unmodified.
- `git status --porcelain` shows changes only under `agent-system/`.

---

### Phase 3: Propagate to the two planner agent contracts [COMPLETED]

**Goal**: Add the new fields to `planner-agent.md` and `planner-hard-agent.md`, and state the
tie-break-upward rule and the counts-are-hypotheses obligation in the planner contracts (scope item
C requires the tie-break in the contracts as well as the format doc, not just one).

**Tasks**:
- [x] In `agents/planner-agent.md`'s Stage 5 plan template, add `**Verification Tier**:`
      immediately before the existing `**Verification**:` field in the Phase 1 block, plus
      `**Commit Mode**:` and `**Scope Hypothesis**:` as noted-optional/conditional lines.
- [x] In `planner-agent.md`, add a Stage 4 (decompose) sub-step instructing the planner to assign a
      tier per phase, including the tie-break-upward sentence "When uncertain, apply the strictest
      applicable tier (full > interface > local > prose)."
- [x] In `planner-agent.md`, add the counts-are-hypotheses obligation to the planning guidance:
      any count, file list, or scope estimate asserted in a plan is a hypothesis requiring
      implementation-time confirmation, never a fact; when a phase asserts one, it carries a
      `**Scope Hypothesis**:` line.
- [x] In `planner-agent.md` Stage 6a (the pre-metadata self-verification checklist), add "each
      phase has a `**Verification Tier**:` field" alongside the existing `**Depends on**:` check.
      This is where authoring-time enforcement actually lives (D3).
- [x] In `agents/planner-hard-agent.md`'s "Required hard-mode additions to plan format" delta list,
      add a numbered item requiring the per-phase `**Verification Tier**:` field, with the same
      tie-break-upward sentence and a note that hard mode's existing "Estimated output: ~N lines"
      figure is itself a scope hypothesis subject to implementation-time confirmation.
- [x] Add the counts-are-hypotheses obligation to `planner-hard-agent.md` as well; do not rely on
      it inheriting from `plan-format.md`.
- [x] In both agent files, add a MUST NOT line: do not weaken the final gate — tiering governs
      in-phase granularity only.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/agents/planner-agent.md` — Stage 4 tier-assignment step, Stage 5
  template fields, Stage 6a checklist entry, counts-are-hypotheses guidance, MUST NOT line
- `agent-system/extensions/core/agents/planner-hard-agent.md` — Stage 5 required-additions item,
  counts-are-hypotheses guidance, MUST NOT line

**Verification**:
- `grep -l 'Verification Tier'` matches both files.
- The tie-break string `full > interface > local > prose` appears in both files.
- `planner-agent.md` Stage 6a section contains a `Verification Tier` check line.
- Both files contain a counts-are-hypotheses statement.
- The existing `**Verification**:` field in `planner-agent.md`'s template is still present and
  unmodified (the new field is additive, not a rename).
- `git status --porcelain` shows changes only under `agent-system/`.

---

### Phase 4: Propagate to the three remaining restatement sites [COMPLETED]

**Goal**: Add the field to `skill-team-plan/SKILL.md`, `context/workflows/task-breakdown.md`, and
`docs/guides/user-guide.md`, respecting each site's distinct field-naming convention so no fourth
naming style is introduced.

**Tasks**:
- [x] In `skills/skill-team-plan/SKILL.md`'s phase template (the block containing `**Objectives**:`
      / `**Steps**:` / `**Verification**:`), add `**Verification Tier**:` immediately before
      `**Verification**:`, matching that site's colon-outside-bold convention.
- [x] In `skill-team-plan/SKILL.md`, add the tie-break-upward sentence to the teammate planning
      instructions so parallel candidate plans converge on the same tier discipline.
- [x] In `context/workflows/task-breakdown.md`, add a phase-level `**Verification Tier:**` line
      immediately after each `**Goal:**` in the template block, matching that site's
      colon-inside-bold convention. Leave the existing per-checklist-item `**Verification:**` lines
      untouched — the tier is phase-level, the item verification is item-level, and they are
      different grains.
- [x] In `task-breakdown.md`, update the worked example phases (Core Authentication, Registration,
      Password Reset) to carry a plausible tier each, so the example demonstrates variation rather
      than a single value everywhere.
- [x] In `task-breakdown.md`'s closing checklist, add a "Verification tier assigned per phase" item.
- [x] In `docs/guides/user-guide.md`, add `**Verification Tier**:` to the phase template block and
      to the bulleted field explanation list (which currently explains `**Steps**` and
      `**Verification**`), with a one-line reader-facing gloss and a pointer to `plan-format.md`.
- [x] Do not propagate the field into heading-format-only consumers (`rules/artifact-formats.md`,
      `context/standards/status-markers.md`, `docs/architecture/handoff-schema.md`,
      `commands/task.md`, the implementer/orchestrate skills, `context/patterns/team-orchestration.md`).
      They consume the `### Phase N: {name} [STATUS]` heading contract only and are out of scope.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md` — phase template field, tie-break
  sentence
- `agent-system/extensions/core/context/workflows/task-breakdown.md` — template phase-level field,
  worked-example tiers, closing checklist item
- `agent-system/extensions/core/docs/guides/user-guide.md` — phase template field, field
  explanation list entry

**Verification**:
- `grep -l 'Verification Tier'` matches all three files.
- `task-breakdown.md` still contains its per-item `**Verification:**` lines (count unchanged from
  before the edit) — confirming the phase-level addition did not replace them.
- `user-guide.md`'s field explanation list contains a Verification Tier entry, not just the
  template block.
- Combined with Phases 1 and 3: all six restatement sites now carry the field. Confirm with a
  single grep over the six paths.
- `git status --porcelain` shows changes only under `agent-system/`.

---

### Phase 5: Per-phase-block enforcement in validate-artifact.sh [COMPLETED]

**Goal**: Add genuinely new loop-over-phase-blocks logic to `scripts/validate-artifact.sh` so
"every phase declares a tier" is actually checked per phase, and sync the checklist in
`rules/plan-format-enforcement.md`. Highest-risk phase; sequenced after the naming has been
exercised across all six generator sites.

**Tasks**:
- [x] In the `# --- Plan-specific checks ---` block, add a per-phase iteration: locate every
      `^### Phase [0-9]+` heading's line number, treat each heading's block as spanning from that
      line to the line before the next `### Phase` heading (or EOF for the last), and search only
      within that range.
- [x] Implement the search with a pattern accepting BOTH punctuation conventions (D7):
      `\*\*Verification Tier\*\*:` and `\*\*Verification Tier:\*\*`.
- [x] Accumulate a per-phase pass/fail and emit one `log_warn` per untiered phase, naming the phase
      number, e.g. "Phase 3 missing **Verification Tier** field". Do NOT emit a single
      document-wide pass/fail.
- [x] Use `log_warn`, not `log_error` (D3). Default mode continues to exit 0 for legacy plans;
      `--strict` callers get enforcement immediately via the existing
      `total_issues=$((errors + warnings))` branch. Add a source comment recording the promotion
      criterion so the deliberate warn level is not mistaken for an oversight.
- [x] Optionally validate the tier VALUE against the allowed set (`prose|local|interface|full`) and
      warn on an unrecognized value; keep this in the same loop.
- [x] Do NOT add "Verification Tier" to the `PLAN_METADATA` array — that array drives the
      whole-document existence loop and would produce exactly the silent under-enforcement this
      phase exists to prevent. Add a source comment at the array saying so.
- [x] Verify `set -euo pipefail` compatibility: the `log_warn` function uses `((warnings++))`,
      which returns non-zero when incrementing from 0. Confirm the existing call sites' behavior
      and match whatever guard pattern they already rely on; do not introduce a new bare
      `((var++))` at a position where a non-zero return would abort the script. *(deviation:
      altered — no existing guard was found; log_error/log_warn/log_fix were all bare
      `((var++))` and equally landmined, silently truncating output and breaking the
      warnings-only exit-0 contract. Fixed all three, not just log_warn, to the safe
      `var=$((var+1))` form; see phase-5 progress file for detail)*
- [x] Update `rules/plan-format-enforcement.md`: add the per-phase required-field line naming
      `**Verification Tier**` (with its four allowed values), plus the optional `**Commit Mode**`
      and conditional `**Scope Hypothesis**` fields, and note the current advisory/warn level.

**Timing**: 1.5 hours

**Depends on**: 1, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes the plan-specific check block is the only place needing
change and that no other caller parses the validator's stdout format. Both are hypotheses —
confirm at implementation time by re-reading the plan-specific block and by checking the callers
identified in the source store (`skill-planner`, `skill-planner-hard`, `skill-reviser`,
`orchestrator-postflight.sh`, `skill-base.sh`, `hooks/validate-plan-write.sh`, and the
`commands/{plan,research,implement,revise}.md` entry points) for stdout-format coupling. The caller
list itself is a hypothesis derived from a grep, not a verified exhaustive set.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` — new per-phase-block iteration in
  the plan-specific check block; source comments at `PLAN_METADATA` and at the new loop
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — per-phase field lines

**Verification** (all four required; this is the `full`-tier phase):
- `bash -n scripts/validate-artifact.sh` passes (syntax).
- Positive fixture: a synthetic plan with three phases, all tiered, produces zero tier warnings.
- **Negative fixture (required)**: a synthetic two-phase plan where ONLY phase 1 carries the tier
  produces exactly ONE tier warning naming phase 2. A run that produces zero warnings here means
  the check is still whole-document and the phase is not done.
- **Punctuation fixtures (required)**: one fixture using `**Verification Tier**:` and one using
  `**Verification Tier:**` both pass with zero tier warnings.
- Regression: run the validator against this plan file itself and against an existing plan under
  `specs/` authored before this task; the pre-existing plan must still exit 0 in default mode
  (advisory-first holds) and must exit 1 under `--strict` (the graduation lever works).
- `git status --porcelain` shows changes only under `agent-system/`.

---

### Phase 6: Index sync, cross-reference note, and whole-task sweep [NOT STARTED]

**Goal**: Correct `index-entries.json` line counts for every touched indexed file, add the
reference-grounding cross-reference note, and run the final whole-task verification sweep.

**Tasks**:
- [ ] Add a short cross-reference note to `context/contracts/reference-grounding.md` (near its
      "Tier Selection" section) acknowledging the sibling verification-tier system in
      `plan-format.md`, noting that both share the tie-break-upward design and that the two tier
      systems answer different questions (reference grounding = what source authority applies;
      verification tiers = how broadly to verify during a phase). Keep it to two or three
      sentences; do not restate either vocabulary.
- [ ] Recompute `wc -l` for every touched file that has an `index-entries.json` row and update its
      `line_count`: `formats/plan-format.md` (currently records 136 against an actual 222 before
      this task's edits — stale regardless), `workflows/task-breakdown.md` (currently 270 and
      accurate before edits), `contracts/reference-grounding.md` (currently 94).
- [ ] Confirm no new context file was created, so no new `index-entries.json` row is needed (D6).
      If the implementer's judgment during Phase 1 produced a separate context file after all, add
      its row here with an accurate `line_count`, `domain`, `subdomain`, and `load_when` block
      matching sibling entries.
- [ ] Confirm the files with no index coverage (`rules/git-workflow.md`,
      `rules/plan-format-enforcement.md`, `agents/planner-agent.md`,
      `agents/planner-hard-agent.md`, `skills/skill-team-plan/SKILL.md`,
      `scripts/validate-artifact.sh`, `docs/guides/user-guide.md`) genuinely have no rows — the
      index only covers the `context/` subtree — and record that as a checked-and-correct
      no-op rather than a silent omission.
- [ ] Run `bash scripts/validate-context-index.sh` (or `--fix` if it supports the drift it finds)
      and confirm it reports no line-count mismatches for the touched entries.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The claim "only three touched files have index-entries.json rows" and the
claim "the index covers only the `context/` subtree" are hypotheses inherited from research, not
verified facts at implementation time. Confirm both by re-running the `jq` query over
`index-entries.json` against the actual set of files modified in Phases 1-5 before concluding the
index work is complete. If the modified-file set differs from what this plan anticipated, the
index work expands accordingly.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/reference-grounding.md` — cross-reference note
- `agent-system/extensions/core/index-entries.json` — `line_count` corrections

**Verification** (whole-task sweep):
- `jq` over `index-entries.json` confirms each touched indexed path's `line_count` equals the
  actual `wc -l`.
- `bash scripts/validate-context-index.sh` reports no mismatch for the touched entries.
- All six restatement sites contain `Verification Tier` (single grep over the six paths, expecting
  six matches).
- `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` section range contains
  `atomic-batch`.
- The final-gate invariant sentence is present in `plan-format.md`.
- The tie-break string `full > interface > local > prose` appears in `plan-format.md`,
  `planner-agent.md`, `planner-hard-agent.md`, and `skill-team-plan/SKILL.md`.
- `bash scripts/validate-artifact.sh <this plan> plan` exits 0 in default mode and produces zero
  tier warnings (this plan tiers every phase).
- `git status --porcelain` shows changes only under `agent-system/` and `specs/`. No path under
  `.claude/` is staged or modified by this task.

---

## Testing & Validation

- [ ] `bash -n agent-system/extensions/core/scripts/validate-artifact.sh` passes.
- [ ] Negative fixture (partially tiered two-phase plan) produces exactly one tier warning.
- [ ] Both field-punctuation conventions are accepted by the new check.
- [ ] A pre-existing plan under `specs/` still exits 0 in default mode and exits 1 under `--strict`.
- [ ] All six phase-template restatement sites carry `Verification Tier`.
- [ ] `atomic-batch` appears inside `git-workflow.md`'s Commit-Per-Green-Substep Mandate section,
      not merely somewhere in the file.
- [ ] Every sub-top tier row in `plan-format.md` has a populated blind-spot cell.
- [ ] The final-gate invariant sentence is present and no tier text weakens it.
- [ ] `bash agent-system/extensions/core/scripts/validate-context-index.sh` reports no line-count
      mismatch for touched entries.
- [ ] No file under `.claude/` was modified.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` (new `## Verification Tiers`
  section; three new per-phase fields; updated Example Skeleton)
- `agent-system/extensions/core/rules/git-workflow.md` (atomic-batch carve-out inside the mandate)
- `agent-system/extensions/core/rules/plan-format-enforcement.md` (per-phase field checklist)
- `agent-system/extensions/core/agents/planner-agent.md`
- `agent-system/extensions/core/agents/planner-hard-agent.md`
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md`
- `agent-system/extensions/core/context/workflows/task-breakdown.md`
- `agent-system/extensions/core/docs/guides/user-guide.md`
- `agent-system/extensions/core/context/contracts/reference-grounding.md` (cross-reference note)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (per-phase-block iteration)
- `agent-system/extensions/core/index-entries.json` (line-count corrections)
- `specs/922_risk_stratified_verification_tiers_in_plans/summaries/01_*-summary.md`

## Rollback/Contingency

All changes are additive text edits to markdown plus one bash script, confined to
`agent-system/extensions/core/`. Rollback is `git revert` of the phase commits — no state
migration, no data transformation, no schema version to unwind. Because enforcement is
advisory-first (D3), a partial landing is safe: if only Phases 1-4 complete, the field exists in
the format doc and generators but is unenforced, which is strictly better than today and breaks
nothing. If Phase 5's per-phase loop proves unstable under `set -euo pipefail`, revert that phase
alone and leave the documentation-level work in place; the enforcement can be re-attempted as a
follow-up without re-doing Phases 1-4. The one change that must not be partially landed is Phase 2:
a `Commit Mode: atomic-batch` field defined in `plan-format.md` without the corresponding
`git-workflow.md` carve-out would advertise an expressiveness that the git rule still forbids — if
Phase 2 is reverted, the commit-mode field text in `plan-format.md` must be reverted with it.
