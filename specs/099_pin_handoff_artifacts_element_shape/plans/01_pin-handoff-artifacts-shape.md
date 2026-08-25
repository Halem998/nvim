# Implementation Plan: pin_handoff_artifacts_element_shape

- **Task**: 99 - Make the `.orchestrator-handoff.json` `artifacts[]` element shape unambiguous
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: `specs/099_pin_handoff_artifacts_element_shape/reports/01_pin-handoff-artifacts-shape.md`
- **Artifacts**: plans/01_pin-handoff-artifacts-shape.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`.orchestrator-handoff.json`'s `artifacts[]` element shape is asserted only by worked example —
`orchestrator-handoff-schema.json` structurally forbids a bare string via `items.type: "object"`,
but no prose anywhere states the prohibition and no validator checks element-level type, so the
structural rule is decorative. Meanwhile `lean-research-agent.md` and `lean-research-hard-agent.md`
carry no mention of the file at all, which is the literal hole that produced observed bare-string
writes. This plan adds one explicit negative statement in the one normative place, propagates it
by reference (never by restatement) into the agent contracts that can write the file, hardens the
validator to name the defect, and records two deliberately deferred items. Done means: a bare
string is stated as never-valid in prose, every contract that could write the file points at that
statement, and `validate-handoff.sh` fails with a message naming the index and observed type.

### Research Integration

Research established four load-bearing facts this plan is built on:
- `.return-meta.json`'s `artifacts` shape is **already** correctly and strictly pinned in
  `return-metadata-file.md`, `general-research-agent.md`, `lean-research-agent.md`, and
  `lean-research-hard-agent.md`. That guidance is correct and is **not touched** by this plan.
- The gap is `.orchestrator-handoff.json`: implicit-by-required-fields, never
  explicit-by-negative-statement, in `handoff-schema.md`, `wrap-up.md`, and the schema file.
- The two lean research agents have zero mention of the handoff file — the acute, reproducing gap.
- There is **no** consumer-side dual-shape tolerance for this file in this repo today. The
  existing `ARTIFACTS_SHAPE_MISMATCH` wiring probes only the separate `.return-meta.json`.

The element shape is settled as: object `{type, path[, summary]}`, `type` and `path` required,
`summary` optional — matching the existing `orchestrator-handoff-schema.json` exactly. No new
schema file and no new template fragment are introduced; `handoff-schema.md`'s `### artifacts
(required)` section is the single prose home and every other site references it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap phases included.

## Scope Decisions on Flagged Follow-Ups

Research flagged four items outside the declared 5-file scope. Each is decided here rather than
left open:

| Flagged item | Decision | Reason |
|---|---|---|
| `general-research-hard-agent.md` + `general-implementation-agent.md` have the identical gap | **FOLD IN** (Phase 4) | One sentence each, textually identical to the in-scope `general-research-agent.md` edit. Fixing one sibling and not the others guarantees visible divergence on the next read, and the task's own acceptance criterion is phrased over *every* contract that mentions artifacts. |
| `wrap-up.md` H9 prose lacks the explicit prohibition | **FOLD IN** (Phase 5) | `wrap-up.md` is the primary contract for the **one active writer** of this file. Pinning the shape everywhere except the active writer's own contract would defeat the purpose of the task. |
| `validate-handoff.sh` Check 2c should type-check `.artifacts[0]` before indexing | **FOLD IN** (Phase 6) | This is the only change that makes the acceptance clause "a dispatch that emits the non-conforming shape is caught with a clear message" actually achievable. It is small, localized to one already-written check block, and the script's log-only/non-gating posture is left **unchanged** (changing gating is a separate decision, not taken here). |
| Shared loud-normalize-and-record helper for the two `SKILL.md` consumer call sites | **DEFER** (Phase 7 records it) | Genuinely different work: a new shared helper in `skill-base.sh`, defect-record wiring, and edits to both orchestrate engines' live state-machine code, with its own behavioral testing surface. It is a behavior change, not a contract clarification. Deferred to a follow-up task recorded in Phase 7. |

**ACCEPTANCE clause resolution — "the orchestrator's dual-shape tolerance is either removed as no
longer needed or deliberately retained with a recorded reason"**: neither branch applies as
written, because **no such tolerance exists for this file today**. The two direct handoff-artifact
reads (`skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`) are raw unguarded
`jq -r '.artifacts[0].path // ""'`. The clause is therefore resolved by *recording the finding
explicitly* (Phase 1 note + Phase 7 record) so a future reader does not go looking for tolerance
that was never there, plus the deferred follow-up above. This plan does not add tolerance and does
not remove anything.

## Surfaced for Maintainer Decision (NOT resolved by this plan)

`handoff-schema.md`'s "Handoff Writers" section states categorically that research agents "never
write a handoff at all, in any mode." This task's own research dispatch contradicts that: a
base-mode `general-research-agent` was handed `handoff_path` + `dispatch_seq` and explicitly
instructed to write `.orchestrator-handoff.json`. This plan **does not pick a side** — picking one
would either silently rewrite a decided contract or silently bless a practice that contradicts it.
Phase 1 records the contradiction in `handoff-schema.md` as a *named open question* with the
defensive-case paragraphs identified as the interim safety net, and Phase 7 records it as a
maintainer-level decision. Whoever resolves it chooses one of: (a) stop instructing research
agents to write the file, restoring the documented invariant, or (b) expand the documented writer
set to match observed practice. That choice determines whether the defensive-case paragraphs added
by Phases 3-4 stay defensive or become primary contract text — which is exactly why it must not be
decided as a side effect of this task.

## Goals & Non-Goals

**Goals**:
- State, in prose, in exactly one normative place, that a bare-string `artifacts[]` element is
  never valid for `.orchestrator-handoff.json`, in any context.
- Give `lean-research-agent.md` and `lean-research-hard-agent.md` the Defensive case section they
  entirely lack, modeled on the established `general-implementation-agent.md` pattern.
- Extend every existing "Defensive case" paragraph to pin the artifacts element shape **by
  reference**, alongside its existing `dispatch_seq` guidance.
- Disambiguate the two files' parallel-but-not-identical `artifacts` shapes in
  `return-metadata-file.md` (`summary` required there, optional in the handoff).
- Make `validate-handoff.sh` name the defect (index + observed type) instead of jq-erroring or
  silently degrading.

**Non-Goals**:
- Changing anything about `.return-meta.json`'s already-correct `artifacts` guidance.
- Creating a new schema file or a second template fragment. Agent contracts reference
  `handoff-schema.md`; they do not restate the field list.
- Tightening the handoff's `summary` to required, or otherwise changing the element shape.
- Changing `validate-handoff.sh`'s log-only/non-gating invocation posture.
- Adding consumer-side dual-shape tolerance at the two `SKILL.md` call sites (deferred).
- Resolving the "research agents never write a handoff" contradiction.
- Any edit under `.claude/**` — that tree is a disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An edit lands in `.claude/**` instead of the source store and is silently wiped on next regeneration | H | M | Every phase names an `agent-system/extensions/**` path explicitly. Phase 7 greps the working tree for `.claude/**` modifications and fails the phase if any exist. |
| Restating the field list inline in agent contracts creates a second drift source | M | M | All contract edits are reference-only, pointing at `handoff-schema.md`'s `### artifacts (required)` section. Phase 7 verifies no phase introduced a duplicate field table. |
| Fixing 3 of 5 sibling contracts leaves visible divergence | M | H (if not folded in) | Folded in — Phases 3 and 4 cover all five contracts that carry or need a Defensive case. |
| The maintainer contradiction is silently "resolved" by an implementer picking a side while editing `handoff-schema.md` | H | M | Phase 1's note is explicitly non-deciding and its acceptance criterion states so; Phase 7 re-reads the added text to confirm it records an open question rather than a decision. |
| Hardened Check 2c changes validator exit behavior for existing well-formed handoffs | M | L | Phase 6 runs the validator against a known-good real handoff (this task's own) *and* a synthetic bare-string fixture, requiring pass and fail respectively. |
| A task-number reference leaks into a deliverable outside `specs/**` | M | M | Phase 7 runs `check-task-references.sh` (or the equivalent repo lint) over the changed files. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5, 6 | 1 |
| 3 | 7 | 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pin the shape in the one normative place [NOT STARTED]

**Goal**: `handoff-schema.md` states explicitly that a bare-string `artifacts[]` element is never
valid, and visibly connects the categorical "research agents never write a handoff" claim to the
defensive-case paragraphs that exist because it is not always honored.

**Tasks**:
- [ ] In `handoff-schema.md`'s `### artifacts (required)` section, after the existing "Each entry
      requires `type` and `path`" sentence, add an explicit negative statement: a bare-string
      element (`"artifacts": ["path/to/file.md"]`) is never an accepted shorthand, in any context;
      every element MUST be an object carrying `type` and `path`, with `summary` optional.
- [ ] In the same section, state that `orchestrator-handoff-schema.json` remains the sole
      machine-checkable authority and that this sentence closes the
      implicit-by-required-fields gap rather than introducing a second source of truth.
- [ ] In the "Handoff Writers — the settled decision, in one place" section, add one sentence
      cross-referencing the agent contracts' "Defensive case" paragraphs, so the categorical claim
      and its fallback guidance are visibly linked rather than living in unrelated files.
- [ ] In the same section, add a short **non-deciding** note recording (a) that live delegation
      contexts have been observed supplying `handoff_path` + `dispatch_seq` to base-mode research
      agents with an instruction to write, contradicting the categorical claim, and (b) that
      reconciling this is an open maintainer decision, with the defensive-case paragraphs serving
      as the interim safety net. Do NOT change the Handoff Writers table's rows.
- [ ] Add a one-line note recording that no consumer-side dual-shape tolerance exists for this
      file today (the two orchestrate-engine reads are unguarded), so a future reader does not
      search for tolerance that was never implemented.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - explicit bare-string
  prohibition in `### artifacts (required)`; defensive-case cross-reference, non-deciding
  contradiction note, and no-tolerance-today note in "Handoff Writers"

**Verification**:
- `grep -n "never" agent-system/extensions/core/docs/architecture/handoff-schema.md` shows the new
  prohibition sentence inside the `### artifacts (required)` section.
- The Handoff Writers table rows are byte-identical to before (`git diff` shows no change inside
  the table body).
- The added contradiction note contains no decision language ("therefore we will", "the contract
  is now") — it names the open question and the two candidate resolutions only.
- No `.claude/**` path is modified.

---

### Phase 2: Disambiguate the two files' artifacts shapes [NOT STARTED]

**Goal**: `return-metadata-file.md` warns readers that the two files' `artifacts` object shapes are
parallel but not identical, pre-empting the cross-file pattern-matching mistake it already warns
about for `phases_completed`/`phases_total`.

**Tasks**:
- [ ] In `return-metadata-file.md`, immediately after the `### artifacts (required)` section's
      four-layer enforcement table (and before the template-fragment pointer), add a short
      cross-reference paragraph in the style of the existing `### phases_completed / phases_total
      nesting collision (cross-file)` callout.
- [ ] The paragraph must state: `.orchestrator-handoff.json` has its own parallel `artifacts`
      object shape defined in `handoff-schema.md`'s `### artifacts (required)` section; both
      forbid bare strings; they differ in that `.return-meta.json` requires `summary` while
      `.orchestrator-handoff.json` treats it as optional — so a worked example from one file is
      not directly transplantable to the other.
- [ ] Do not modify the existing four-layer enforcement table, the bare-string prohibition
      sentence, or the template-fragment pointer.

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - one cross-reference
  paragraph added under `### artifacts (required)`

**Verification**:
- The paragraph names `handoff-schema.md` and its `### artifacts (required)` section by name.
- `git diff` shows additions only within the `### artifacts (required)` section; the enforcement
  table and template pointer are unchanged.
- The existing `.return-meta.json` bare-string prohibition sentence is untouched.

---

### Phase 3: Give the lean research agents a Defensive case section [NOT STARTED]

**Goal**: `lean-research-agent.md` and `lean-research-hard-agent.md` — which currently have zero
mention of `.orchestrator-handoff.json` — carry the same non-writer-by-design statement plus
defensive-case guidance the general agents already have.

**Tasks**:
- [ ] In `lean-research-agent.md`, add a new `## .orchestrator-handoff.json (research is a
      non-writer by design)` section immediately after the `## Write Final Metadata` section,
      modeled on `general-implementation-agent.md`'s existing
      `### .orchestrator-handoff.json (base-mode implement is a non-writer by design)` section.
- [ ] The section states: this agent does not write `.orchestrator-handoff.json` by contract
      (research agents never do, per `handoff-schema.md`'s "Handoff Writers"); a `handoff_path`
      field in the delegation context is an anchor for the orchestrator's own read, not an
      instruction to write.
- [ ] Add the **Defensive case** paragraph: if a delegation context nonetheless supplies
      `handoff_path` and an instruction to write one, then (a) echo `dispatch_seq` unchanged —
      copy the delegation context's value verbatim, never invent/increment/recompute, and omit it
      entirely when the delegation context omits it; and (b) write `artifacts[]` using only the
      object shape defined in `handoff-schema.md`'s `### artifacts (required)` section — never a
      bare path string.
- [ ] Reference `handoff-schema.md` for the field list; do NOT restate the field table inline.
- [ ] In `lean-research-hard-agent.md`, add the identical section immediately after
      `### Stage 7: Write Metadata File` and before `### Stage 8: Return Brief Text Summary`,
      using `###` heading level to match that file's stage structure.
- [ ] Leave both files' existing `.return-meta.json` `artifacts` shape guidance completely
      untouched — it is already correct.

**Timing**: 40 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase assumes exactly two lean research contracts lack any mention of
`.orchestrator-handoff.json`. Confirm at implementation time with
`grep -rL "orchestrator-handoff" agent-system/extensions/lean/agents/*research*.md` — if the set
is larger or smaller than `{lean-research-agent.md, lean-research-hard-agent.md}`, record the
actual set in the summary and treat any extra file as an explicit include-or-exclude decision
rather than silently widening.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-research-agent.md` - new non-writer + Defensive case
  section after `## Write Final Metadata`
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - identical section after
  Stage 7

**Verification**:
- `grep -c "orchestrator-handoff" ` on each file returns a non-zero count (was zero).
- Each added section contains both the `dispatch_seq` echo instruction and the artifacts-shape
  reference to `handoff-schema.md`.
- Neither file contains a newly-added inline copy of the handoff artifacts field table.
- Each file's existing `.return-meta.json` template block is byte-identical (`git diff` shows no
  change inside the fenced JSON blocks).

---

### Phase 4: Pin the artifacts shape in the three existing Defensive case paragraphs [NOT STARTED]

**Goal**: Every contract that already carries a "Defensive case" paragraph pins the artifacts
element shape alongside its existing `dispatch_seq` guidance, so no sibling contract is left
diverging from the one just fixed.

**Tasks**:
- [ ] In `general-research-agent.md`, extend the existing Stage 3.6 "Defensive case, if this
      scoping decision is ever reversed" paragraph with one added sentence: the handoff's
      `artifacts[]` entries MUST use the object shape defined in `handoff-schema.md`'s
      `### artifacts (required)` section — never a bare path string.
- [ ] In `general-research-hard-agent.md`, make the textually identical addition to its
      corresponding Defensive case paragraph.
- [ ] In `general-implementation-agent.md`, make the same addition to its "Defensive case, if a
      handoff is written anyway" paragraph, alongside the existing `phases_completed`/
      `phases_total` top-level-nesting and `dispatch_seq` instructions.
- [ ] Keep all three additions reference-only; do not restate the field list inline; do not alter
      the existing `dispatch_seq` or nesting sentences.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly three contracts already carry a Defensive case
paragraph. Confirm with `grep -rln "Defensive case" agent-system/extensions/*/agents/*.md` before
editing; if the result set differs from
`{general-research-agent.md, general-research-hard-agent.md, general-implementation-agent.md}`,
record the actual set in the summary and decide per-file whether it is in scope, rather than
editing whatever the grep happens to return.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - one sentence added to Stage
  3.6 Defensive case
- `agent-system/extensions/core/agents/general-research-hard-agent.md` - same sentence
- `agent-system/extensions/core/agents/general-implementation-agent.md` - same sentence

**Verification**:
- All three files match `grep -n "artifacts" ` within their Defensive case paragraph.
- All three additions cite `handoff-schema.md`'s `### artifacts (required)` section by name.
- The existing `dispatch_seq` sentences in all three files are unchanged (`git diff` shows pure
  additions inside those paragraphs).

---

### Phase 5: Pin the shape in the active writer's own contract [NOT STARTED]

**Goal**: `wrap-up.md`'s H9 `artifacts` field-semantics bullet — the prose contract governing the
one *active* writer of `.orchestrator-handoff.json` — carries the explicit prohibition instead of
implying it by worked example.

**Tasks**:
- [ ] In `wrap-up.md`, extend the `- \`artifacts\`: REQUIRED array ...` field-semantics bullet
      with the explicit statement that each element MUST be an object with `type` and `path`
      (`summary` optional) and that a bare path string is never an accepted shorthand.
- [ ] Point at `handoff-schema.md`'s `### artifacts (required)` section as the normative home
      rather than restating the field table.
- [ ] Leave the existing worked-example JSON block unchanged — it is already correct.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/wrap-up.md` - explicit prohibition added to the
  H9 `artifacts` field-semantics bullet

**Verification**:
- The `artifacts` bullet contains the words identifying a bare string as never valid and cites
  `handoff-schema.md`.
- The worked-example JSON block is byte-identical (`git diff` shows no change inside the fence).

---

### Phase 6: Make the validator name the defect [NOT STARTED]

**Goal**: `validate-handoff.sh` Check 2c type-checks `.artifacts[0]` before indexing into it, and
FAILs with a message naming the index and the observed type — instead of jq-erroring or silently
degrading to `__MISSING__` and reporting a generic missing-field failure.

**Tasks**:
- [ ] In `validate-handoff.sh` Check 2c, before the existing `entry0_type`/`entry0_path`/
      `entry0_summary` extractions, add an element-type probe: `jq -r '.artifacts[0] | type'`.
- [ ] If the observed type is not `object`, `log_fail` with a message naming the index (`0`) and
      the observed type, and explicitly stating that a bare-string element is never valid per
      `handoff-schema.md`'s `### artifacts (required)` section. Mirror the message style of
      `validate-return-meta.sh`'s existing `bare_count` check.
- [ ] Skip the per-field extractions when the element is not an object, so the generic
      "missing required field(s)" failure does not mask the real shape defect.
- [ ] Do NOT change the script's log-only / non-gating invocation posture in
      `skill_corroborate_phase_counts()` — that is a separate decision, deliberately not taken.
- [ ] Extend the script's usage/help text (the `Required fields:` block near the top) only if it
      currently misstates the element shape; otherwise leave it alone.

**Timing**: 40 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the element-shape gap is confined to Check 2c's
`.artifacts[0].*` extractions and that no other check in the script indexes into an artifacts
element. Confirm with `grep -n "artifacts\[" agent-system/extensions/core/scripts/validate-handoff.sh`
before editing; if other indexing sites exist, harden them in the same phase and record the actual
site count in the summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-handoff.sh` - Check 2c element-type guard

**Verification**:
- `bash -n` on the modified script passes.
- Running the modified script against this task's own real handoff
  (`specs/099_pin_handoff_artifacts_element_shape/.orchestrator-handoff.json`) produces the same
  pass/fail outcome as before the change.
- Running it against a synthetic fixture whose `artifacts` is `["some/path.md"]` produces a FAIL
  whose message contains both the index `0` and the observed type `string` — and does NOT emit a
  raw jq error.
- Running it against a fixture with a correct object element still passes Check 2c.
- `grep -n "log_only\|non-gating" ` of the caller confirms the invocation posture is unchanged.

---

### Phase 7: Verify, record deferrals, and close [NOT STARTED]

**Goal**: The whole change set is verified as one unit against the repo's own gates, the two
deliberately deferred items are recorded where a future reader will find them, and no source-store
or task-reference rule was violated.

**Tasks**:
- [ ] Run `lint-agent-contracts.sh` (or the repo's current agent-contract lint) and confirm it
      passes — in particular that Check F's `.return-meta.json` template requirement is still
      satisfied for every file touched by Phases 3 and 4.
- [ ] Run the repo's task-reference lint (`check-task-references.sh` or equivalent) over the
      changed files and confirm zero findings outside `specs/**`.
- [ ] Confirm `git status --short` shows **no** modified path under `.claude/**`; every change is
      under `agent-system/extensions/**` (plus this task's own `specs/**` artifacts).
- [ ] Grep the full diff for any newly-added inline copy of the handoff artifacts field table —
      there must be none; every contract site is reference-only.
- [ ] Validate `orchestrator-handoff-schema.json` is unmodified (it was already correct; this plan
      introduces no schema change).
- [ ] Write the execution summary to `specs/099_pin_handoff_artifacts_element_shape/summaries/`
      recording: the settled element shape, the four fold-in/defer decisions from this plan's
      Scope Decisions table with their reasons, the ACCEPTANCE-clause resolution (no dual-shape
      tolerance exists today; nothing removed, nothing retained, finding recorded), and the
      surfaced maintainer contradiction with its two candidate resolutions.
- [ ] Record the deferred consumer-side work as an explicit follow-up item in the summary
      (shared loud-normalize-and-record helper in `skill-base.sh` called by both
      `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`, with
      `ARTIFACTS_SHAPE_MISMATCH` defect recording), naming it as the remaining gap against the
      "caught with a clear message" acceptance criterion on the consumer side.
- [ ] Record the maintainer-level contradiction as a follow-up needing a human decision, not an
      implementation item.

**Timing**: 40 minutes

**Depends on**: 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `specs/099_pin_handoff_artifacts_element_shape/summaries/01_pin-handoff-artifacts-shape-summary.md` -
  execution summary with decisions, deferrals, and surfaced contradiction

**Verification**:
- Agent-contract lint exits 0.
- Task-reference lint reports zero findings outside `specs/**`.
- `git status --short | grep '^.M \.claude/'` returns nothing.
- The summary contains all four scope decisions with reasons, the ACCEPTANCE-clause resolution,
  and the surfaced contradiction.
- Every phase heading in this plan reads `[COMPLETED]`.

---

## Testing & Validation

- [ ] `validate-handoff.sh` FAILs a bare-string-element fixture with a message naming index `0`
      and observed type `string`, with no raw jq error.
- [ ] `validate-handoff.sh` still PASSes a correct object-element handoff, and its exit behavior
      on this task's own real handoff is unchanged from before.
- [ ] `bash -n agent-system/extensions/core/scripts/validate-handoff.sh` passes.
- [ ] Agent-contract lint passes for all five contract files touched.
- [ ] Every file that could write `.orchestrator-handoff.json` either states the object-only rule
      or references `handoff-schema.md`'s `### artifacts (required)` section: verified by
      `grep -L` across the lean and core research/implementation agent contracts.
- [ ] No `.claude/**` file modified.
- [ ] No task-number reference introduced outside `specs/**`.
- [ ] `orchestrator-handoff-schema.json` byte-identical to its pre-change state.

## Artifacts & Outputs

- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (modified)
- `agent-system/extensions/lean/agents/lean-research-agent.md` (modified)
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` (modified)
- `agent-system/extensions/core/agents/general-research-agent.md` (modified)
- `agent-system/extensions/core/agents/general-research-hard-agent.md` (modified, folded in)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified, folded in)
- `agent-system/extensions/core/context/contracts/wrap-up.md` (modified, folded in)
- `agent-system/extensions/core/scripts/validate-handoff.sh` (modified, folded in)
- `specs/099_pin_handoff_artifacts_element_shape/summaries/01_pin-handoff-artifacts-shape-summary.md` (new)

## Rollback/Contingency

Every change is additive prose plus one localized guard in a single non-gating bash script, so
rollback is a plain `git revert` of the phase commits — no data migration, no state change, and no
dependent artifact to unwind. If Phase 6's guard proves to misfire on a real handoff shape not
anticipated here, revert Phase 6 alone: Phases 1-5 are pure documentation and stand independently,
leaving the prose prohibition in place while the validator returns to its prior behavior. If the
maintainer resolves the surfaced writer-set contradiction in favor of "research agents never write
a handoff," the Defensive case sections added by Phases 3-4 remain correct as written — they are
explicitly conditional and cost nothing if the condition never fires.
