# Implementation Plan: Task #924

- **Task**: 924 - documented_reasoned_exclusions_phase_outcome
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None (`scripts/skill-base.sh` is owned by a sibling `[PARTIAL]` task and is deliberately NOT in this task's file scope; research proved no edit is needed there)
- **Research Inputs**: specs/924_documented_reasoned_exclusions_phase_outcome/reports/01_documented-reasoned-exclusions.md
- **Artifacts**: plans/01_reasoned-exclusions-phase-outcome.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, plan-format-enforcement.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Introduce `[COMPLETED WITH EXCLUSIONS]` as a third terminal phase-heading outcome — distinct from
`[COMPLETED]` (nothing was excluded) and `[PARTIAL]` (work remains and is resumable) — for a phase
whose remaining items are provably not applicable. The outcome is delivered as a **generalization
of the existing strategic-sorry mechanism**, not as a second mechanism beside it: both are members
of one documented family ("documented incompleteness that still counts as success"), differing on
one axis — a strategic sorry is *deferred with a tracked follow-up*, a reasoned exclusion is
*decided and will not be revisited*. The absence of a `follow_up_task` field is the defining
property, not an omission.

Work spans five phases: define the outcome and its record format in the standards/format layer;
make the write path (`update-phase-status.sh`) and the completion gate (`update-task-status.sh`)
honor it; protect the record from the Stage 5a blind rewrite in both implementation agents;
reconcile the phase-heading regex family this task is already editing; and wire the outcome into
the handoff schema and plan-format enforcement checklist.

### Research Integration

All five research findings are load-bearing here:

1. **`skill_gate_completion_claim()` needs no code change** — it consumes only the agent's
   self-reported `phases_completed`/`phases_total` and never reads the plan file. The lever is an
   *instruction* change (Phase 3) plus a *documentation* change (Phase 5), not a script edit.
   `scripts/skill-base.sh` therefore stays out of file scope, honoring the sibling task's boundary.
2. **`scripts/update-task-status.sh`'s `count_plan_phases()` is the regex that must change** — it
   independently re-derives TOTAL/DONE from the plan file, so no instruction change can reach it.
3. **The Stage 5a alternation is byte-identical in both implementation agents** — every edit in
   Phase 3 must be applied twice, identically.
4. **The marker text is constrained to uppercase letters and spaces** by the existing TOTAL
   character class `[A-Z][A-Z ]*`. A name with a dash, digits, or parentheses would fall out of the
   denominator — a variant of the very trap this task closes.
5. **Five phase-heading regex sites, three divergent shapes, no letter-suffix support anywhere.**

The plan additionally rests on four behaviors **verified empirically at plan time** against a
throwaway fixture (`### Phase 1: Alpha [COMPLETED]` / `### Phase 2: Beta [COMPLETED WITH
EXCLUSIONS]` / `### Phase 3.1: Gamma [PARTIAL]`), using the exact regex strings quoted from the
source store:

| Probe | Result | Consequence for this plan |
|-------|--------|---------------------------|
| Current TOTAL regex vs. the fixture | 2 (admits `[COMPLETED WITH EXCLUSIONS]`, misses `Phase 3.1`) | Marker name is safe as-is; decimal gap is real |
| Current DONE regex vs. the fixture | 1 (misses the exclusion phase) | The denominator-inflation trap, reproduced |
| Proposed decimal TOTAL / alternation DONE | 3 / 2 | The Phase 2 edits are correct |
| Stage 5a alternation vs. the fixture | 1 hit (`Phase 3.1` only) | The exclusion heading is outside the blind rewrite |
| `sed -n 's/.*\[\(.*\)\]$/\1/p'` on the exclusion heading | `COMPLETED WITH EXCLUSIONS` | `update-phase-status.sh`'s status extractor needs no change |

One defect was discovered during that probe and is folded into scope: the Stage 5a alternation
`^### Phase [0-9]+.*\[(NOT STARTED|IN PROGRESS|PARTIAL)\]` **does** match `### Phase 3.1:` (the
`.*` absorbs `.1`), but the companion extraction `grep -oE "Phase [0-9]+" | grep -oE "[0-9]+"`
yields `3`, and `update-phase-status.sh` then fails with "Phase 3 not found". Stage 5a is
therefore already broken for decimal sub-phases today, independent of this task's marker work.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap phases are required.

## Goals & Non-Goals

**Goals**:
- A phase whose remaining items are provably not applicable can be closed honestly, with a
  machine-visible marker that counts as done in every consumer that gates task completion.
- The record of *what* was excluded, *why*, and *what evidence* supports the reason is durable,
  lives with the phase, and cannot be destroyed by an automated marker repair.
- The new outcome reads as one concept with the existing strategic-sorry mechanism — shared family
  name, explicit cross-references in both directions, and a stated distinguishing axis.
- The three divergent notions of "a phase heading" across the sites this task edits converge on
  one canonical form, written down once so future sites copy it.

**Non-Goals**:
- **Letter-suffixed sub-phase headings (`Phase 3a`) are NOT added.** Research confirmed zero
  precedent and zero consumer support anywhere in the codebase; decimal sub-phasing (`Phase 3.1`)
  already has deliberate, documented precedent in two sites and is the form this task converges on.
  Adding letter suffixes would be inventing a feature, not reconciling a family.
- **`scripts/skill-base.sh` is NOT edited.** Owned by a sibling `[PARTIAL]` task; research proved
  no edit is required.
- **The per-objective `deviations` mechanism (`progress-file.md` / `events.jsonl`) is NOT
  extended.** Wrong grain (objective-scoped, transient) and its `skipped|altered|deferred`
  vocabulary has no `excluded` member. Research also found its schema is not documented in
  `progress-file.md` at all — that stale cross-reference is a separate follow-up, not this task's.
- **The `[COMPLETED WITH EXCLUSIONS]` outcome is NOT added to the task-level or plan-level Status
  vocabularies.** It is a phase-heading marker only. A task with an exclusion-closed phase still
  reaches `[COMPLETED]`.
- No changes under `.claude/**` as authored edits. `.claude/` is regenerated from the source store
  by deploy, and deploy is used purely to *execute* verification.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The two Phase 2 script edits drift out of sync (write path accepts the token, count path does not, or vice versa) — the gate then refuses forever or the marker is unwritable | H | M | Phase 2 is declared `Commit Mode: atomic-batch`: one pre-declared batch, one commit, batch-level verification at tier `full`. Research explicitly names these as one atomic edit, not two schedulable items. |
| An implementer parks an exclusion-closed phase at `[PARTIAL]` "to be safe" — Stage 5a then blind-promotes it to `[COMPLETED]`, converting a documented exclusion into a fake full completion | H | M | Phase 3 adds an exclusion-aware branch to Stage 5a (a stale heading whose phase body carries a `#### Reasoned Exclusions` record repairs to the exclusion marker, never to `[COMPLETED]`), plus an explicit instruction that exclusion-close is a *direct* transition. Both are asserted by the negative fixture. |
| A future contributor invents a parallel exclusion mechanism because the family relationship is only implicit | M | M | Phase 1 writes the family name and a two-way cross-reference between the strategic-sorry sections and the new sections; Phase 5's site census confirms no orphaned marker enumeration survives. |
| The marker-vocabulary enumeration exists at more sites than the four this plan names, leaving a stale 5-marker list behind | M | M | Phase 1 carries a `Scope Hypothesis` requiring a full source-store census of marker enumerations before any edit, with an explicit escalate-don't-absorb instruction if the census exceeds the named sites. |
| Making the DONE regex more permissive accidentally weakens the completion gate for genuinely incomplete work | H | L | Every fixture in Phases 2 and 3 includes a **negative control**: a plain `[PARTIAL]` phase must still fail the gate / must still be promoted to plain `[COMPLETED]`. Demonstrating only the positive case is treated as phase failure. |
| Scripts cannot be executed from the source store (`deploy-root-guard.sh` fails closed) | M | H | Every executable-verification phase deploys first via the deployed `deploy-headless.sh`, then exercises the deployed copy. This is expected use of a disposable deploy artifact, not a source-store violation. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 5 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 4 touch disjoint files
(`scripts/update-phase-status.sh` + `scripts/update-task-status.sh` vs.
`scripts/validate-artifact.sh` + `context/formats/plan-format.md`), so the wave-2 pair is
territory-safe.

**Source-store rule (applies to every phase)**: the source of truth is
`agent-system/extensions/core/`. All authored edits target `agent-system/extensions/**`. `.claude/`
is a gitignored, disposable deploy artifact — it is written only by `deploy-headless.sh` and read
only to execute verification.

**No task-number citations** may appear in any file this plan writes: every target file lives
outside `specs/**`. Cite durable anchors (function names, section headings, quoted regex strings)
instead.

---

### Phase 1: Define the outcome, its admission test, and its record format [COMPLETED]

**Goal**: Establish `[COMPLETED WITH EXCLUSIONS]` as a defined phase-heading outcome with stated
semantics, an admission test, a required record format, and an explicit family relationship to the
strategic-sorry mechanism — so that everything downstream has one definition to point at.

**Tasks**:
- [x] Run the marker-enumeration census first (see Scope Hypothesis) and record the site list.
- [x] In `context/standards/status-markers.md`, extend the "Plan-level vs. phase-level markers"
      subsection's phase-heading vocabulary with `[COMPLETED WITH EXCLUSIONS]`. State the three-way
      distinction explicitly: `[COMPLETED]` = nothing was excluded; `[PARTIAL]` = work remains and
      is resumable; `[COMPLETED WITH EXCLUSIONS]` = every remaining item was **decided, justified,
      and will not be revisited**. Note that it is a phase-heading marker only (absent from both
      the task-level vocabulary and the plan-level `- **Status**:` subset), and note the hard
      character-class constraint: the bracket text must be uppercase letters and spaces only,
      because the phase-accounting TOTAL regex is `[A-Z][A-Z ]*`.
- [x] In the same file, add the **admission test** as a direct generalization of the five-condition
      strategic-sorry test in `context/contracts/anti-analysis.md` — mode-neutral and task-type
      neutral: (1) the exclusion is a *decision*, not a stuck or abandoned attempt; (2) it is
      tightly scoped to enumerated items, never "the rest of the phase"; (3) each item carries a
      stated reason; (4) each reason carries evidence; (5) **no residual work** — nothing remains
      that a future dispatch would need to do, which is exactly why no follow-up task is recorded.
      State that failing any condition means the phase is `[PARTIAL]`, not exclusion-closed.
- [x] In `context/formats/plan-format.md`, add `[COMPLETED WITH EXCLUSIONS]` to the phase-heading
      marker set in the Implementation Phases format, and extend the "Plan-level vs. phase-level
      markers" subsection with the same three-way distinction.
- [x] In `context/formats/plan-format.md`, add a new `#### Reasoned Exclusions` record-format
      section, placed adjacent to the existing `## Planned Strategic Sorries` section so a reader
      encounters the family together. Specify: the record is a **per-phase subsection nested at
      `####` inside the phase body** (not a document-level `##` section — exclusions are
      phase-scoped by definition, whereas a skeleton's sorries span phases); it is REQUIRED whenever
      a phase heading carries the marker; and its minimum columns are:

      ```
      #### Reasoned Exclusions

      | Item | Reason | Evidence |
      |------|--------|----------|
      | {the excluded item} | {why it is not applicable} | {what confirms the reason -- command output, quoted match count, diff excerpt, or artifact reference} |
      ```

      Document the field mapping to the `wrap-up.md` `sorry_inventory` schema so the family reads
      as one concept: `Item` generalizes `file`/`line`/`statement` to any domain; `Reason`
      generalizes `assumption` + `why_deferred`; `Evidence` is the new obligation that has no
      sorry-side counterpart (a sorry is *tracked* by `follow_up_task`, an exclusion is *closed* by
      evidence). State that `follow_up_task` is deliberately absent, and that this absence is the
      defining difference between the two family members.
- [x] In `context/formats/plan-format.md`, cross-reference the existing `**Scope Hypothesis**`
      field: a reasoned exclusion is structurally the closing act of a Scope Hypothesis whose
      asserted count turned out to be an overcount, and the Evidence column is where that
      confirmation lands. State that the record may be written at plan time (pre-emptive
      declaration) or at implement time (discovered mid-phase), with implement-time entries
      confirming or superseding plan-time hypotheses.
- [x] In `context/contracts/anti-analysis.md`, add a short cross-reference from the strategic-sorry
      section naming the shared family and pointing at the new sections. Do not restate the
      admission test there — one definition, referenced twice.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that exactly four files enumerate or define the
phase-heading marker vocabulary (`context/standards/status-markers.md`,
`context/formats/plan-format.md`, `rules/plan-format-enforcement.md`, and — as a mirrored copy —
`root-files`/`merge-sources` renderings of the artifact-format rules). Confirm before editing by
running a census over the source store for the marker enumeration, e.g.
`grep -rn 'NOT STARTED.*IN PROGRESS.*COMPLETED\|\[IN PROGRESS\]' agent-system/extensions/core/ --include='*.md'`
and `grep -rln '\[PARTIAL\]' agent-system/extensions/core/`. Record the confirmed site list in the
implementation summary. If the census returns sites beyond those named in this plan and Phase 5,
**escalate rather than absorb**: note the extra sites in the summary and flag them for a follow-up
rather than silently widening this phase.

**Files to modify**:
- `agent-system/extensions/core/context/standards/status-markers.md` — phase-heading vocabulary
  entry, three-way distinction, character-class constraint, admission test
- `agent-system/extensions/core/context/formats/plan-format.md` — marker in the Implementation
  Phases format, extended "Plan-level vs. phase-level markers" subsection, new
  `#### Reasoned Exclusions` record-format section, Scope Hypothesis cross-reference
- `agent-system/extensions/core/context/contracts/anti-analysis.md` — family cross-reference only

**Verification**:
- `grep -n 'COMPLETED WITH EXCLUSIONS'` returns hits in all three files.
- The literal chosen string passes the live TOTAL character class — construct a one-line fixture
  `### Phase 1: X [COMPLETED WITH EXCLUSIONS]` and assert
  `grep -c '^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$'` returns `1`. If it returns
  `0`, the chosen marker text is wrong and the phase fails.
- Both directions of the family cross-reference resolve: `anti-analysis.md` points at the new
  sections and `plan-format.md`'s new section points back at `## Planned Strategic Sorries`.
- The admission test appears exactly once across the source store (`grep -c` on a distinctive
  phrase from it returns 1) — one definition, not two.
- No task-number citation appears in any edited file.

---

### Phase 2: Make the write path and the completion gate honor the marker [COMPLETED]

**Goal**: `update-phase-status.sh` can legally *write* the marker, and `update-task-status.sh`'s
`--phase-check` backstop *counts* an exclusion-closed phase as done — closing both halves of the
two-sided trap on the script side.

**Tasks**:
- [x] In `scripts/update-phase-status.sh`, add a `COMPLETED_WITH_EXCLUSIONS|completed_with_exclusions`
      case branch (and the space-separated input form, matching how `IN_PROGRESS|IN PROGRESS` is
      already handled) normalizing to `new_status_display="COMPLETED WITH EXCLUSIONS"`. Update the
      header-comment `NEW_STATUS values:` line, the usage `STATUS values:` line, and the invalid-value
      error's `Valid values:` line — all three enumerate the accepted set and must stay in sync.
      The existing status extractor `sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p"` and the idempotency
      check need no change (verified at plan time against the multi-word marker).
- [x] In `scripts/update-task-status.sh`'s `count_plan_phases()`, change the DONE regex from the
      literal `\[COMPLETED\]` to a BRE alternation admitting both markers, and apply the canonical
      decimal-sub-phase form to BOTH the TOTAL and DONE regexes so the numerator and denominator
      cannot diverge on phase numbering. Verified-correct forms:
      - TOTAL: `^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[[A-Z][A-Z ]*\][[:space:]]*$`
      - DONE:  `^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[\(COMPLETED\|COMPLETED WITH EXCLUSIONS\)\][[:space:]]*$`
- [x] Update the phase-check log/error messages in `update-task-status.sh` that currently read
      "phases [COMPLETED]" so they no longer imply the literal marker is the only accepted done
      state (e.g. "phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS)"). There are three such
      messages: the proceeding message, the `refuse` error, and the `warn` warning.
- [x] Add a brief comment above `count_plan_phases()` recording the character-class constraint —
      any future done-state marker must be uppercase letters and spaces only, or it silently falls
      out of TOTAL.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the accepted-status set is enumerated in exactly three
places within `scripts/update-phase-status.sh` (header comment, usage block, error message) and
that "phases [COMPLETED]" appears in exactly three messages in `scripts/update-task-status.sh`.
Confirm with `grep -n 'IN_PROGRESS, NOT_STARTED' scripts/update-phase-status.sh` and
`grep -n 'phases \[COMPLETED\]' scripts/update-task-status.sh` before editing; correct the count in
the summary if it differs.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-phase-status.sh` — case branch + three enumeration sites
- `agent-system/extensions/core/scripts/update-task-status.sh` — `count_plan_phases()` TOTAL/DONE
  regexes, three phase-check messages, constraint comment

**Verification** (all assertions required; the negative controls are not optional):
1. Deploy the source store so the scripts are executable:
   `bash .claude/scripts/deploy-headless.sh` (the deploy-root guard makes source-store execution
   fail closed by design).
2. **Regex fixture** — write a fixture plan file containing four headings: `[COMPLETED]`,
   `[COMPLETED WITH EXCLUSIONS]`, a decimal `Phase N.M` heading, and a plain `[PARTIAL]`. Run the
   TOTAL and DONE regexes *as quoted from the edited script* against it and assert the exact
   expected counts, including that the decimal heading is now counted.
3. **NEGATIVE FIXTURE (required)** — a fixture whose only non-done heading is a plain `[PARTIAL]`
   with no exclusion record must still produce `DONE < TOTAL`. Then drive the real gate end-to-end:
   create a throwaway task directory under `specs/` with that fixture as its plan, run
   `update-task-status.sh postflight <n> implement <session> --phase-check=refuse`, and assert it
   still `exit 4`s. Remove the throwaway directory afterward. **A run that demonstrates only the
   positive case fails this phase.**
4. **Positive round-trip** — in a second throwaway task directory, invoke
   `update-phase-status.sh <n> <slug> <phase> COMPLETED_WITH_EXCLUSIONS`, assert the heading is
   rewritten to `[COMPLETED WITH EXCLUSIONS]`, re-invoke it and assert the idempotency no-op path
   fires, then assert `--phase-check=refuse` now passes for that plan. Remove the directory.
5. Assert `update-phase-status.sh` still rejects an unknown status token with its usage error.
6. Paste the fixture command transcripts (commands and their actual output) into the
   implementation summary — the assertion counts are the evidence, not a prose claim that they passed.

---

### Phase 3: Protect the record from the Stage 5a blind rewrite in both implementation agents [NOT STARTED]

**Goal**: An exclusion-closed phase survives Stage 5a's automated marker repair with its marker —
and therefore its record — intact, and a phase left stale-but-documented is repaired *to the
exclusion marker*, never blind-promoted to `[COMPLETED]`.

**Tasks**:
- [ ] In `agents/general-implementation-agent.md` Stage 5a, replace the blind repair loop with an
      exclusion-aware one. Requirements: (a) the `^### Phase ...\[(NOT STARTED|IN PROGRESS|PARTIAL)\]`
      detection alternation is unchanged, so a heading already at `[COMPLETED WITH EXCLUSIONS]`
      remains outside it and is never rewritten; (b) before repairing a stale heading, inspect that
      phase's body for a `#### Reasoned Exclusions` subsection — if present, repair to
      `COMPLETED_WITH_EXCLUSIONS`; if absent, repair to `COMPLETED` exactly as today; (c) fix the
      companion phase-number extraction to the canonical decimal-admitting form
      (`grep -oE 'Phase [0-9]+(\.[0-9]+)?' | grep -oE '[0-9]+(\.[0-9]+)?'`), which today truncates
      `Phase 3.1` to `3` and makes `update-phase-status.sh` fail with "Phase 3 not found".
- [ ] Apply the byte-identical change to `agents/general-implementation-hard-agent.md` Stage 5a.
      Research confirmed the two blocks are byte-identical today; they must remain so afterward.
      The hard variant's additional `plan_markers_verified: true` write and its single-phase
      `phase_number` scoping are untouched.
- [ ] In both agents, add an explicit instruction near the phase-close guidance: closing a phase by
      reasoned exclusion is a **direct** transition performed by the agent via
      `update-phase-status.sh ... COMPLETED_WITH_EXCLUSIONS` at close time. Never park the phase at
      `[PARTIAL]` expecting Stage 5a or a later dispatch to finish it — Stage 5a is a backstop, not
      the intended path, and a phase parked at `[PARTIAL]` without a record stays a fake completion
      risk. Point at the admission test from Phase 1 rather than restating it.
- [ ] In both agents, add the self-report instruction: a phase closed via
      `[COMPLETED WITH EXCLUSIONS]` counts toward the `phases_completed` integer written to the
      handoff, exactly as a `[COMPLETED]` phase does. State why — the completion-claim gate reads
      only that self-report and never reads the plan file, so an under-count here permanently
      refuses task completion.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the Stage 5a block appears exactly once per agent file and
is byte-identical across the two. Confirm before editing with
`grep -n 'stale_total' agents/general-implementation-agent.md agents/general-implementation-hard-agent.md`
and a diff of the two extracted blocks; after editing, re-diff and assert they are still identical.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 5a repair loop,
  direct-transition instruction, `phases_completed` self-report instruction
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — the same three
  changes, byte-identical in the Stage 5a block

**Verification** (all assertions required):
1. Deploy: `bash .claude/scripts/deploy-headless.sh`.
2. **Byte-identity assertion** — extract the Stage 5a bash block from both agent files and `diff`
   them; the diff must be empty.
3. **NEGATIVE FIXTURE (required)** — build a fixture plan with three phases and run the edited
   Stage 5a block *verbatim* against it (extract the block from the deployed agent file and execute
   it, rather than retyping it, so the fixture tests the shipped text):
   - Phase A at `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` table -> assert the
     heading is **byte-identical after the run** and the table is intact. This is the record-survival
     assertion.
   - Phase B at `[PARTIAL]` **with** a `#### Reasoned Exclusions` table -> assert it is repaired to
     `[COMPLETED WITH EXCLUSIONS]`, **not** to `[COMPLETED]`.
   - Phase C at `[PARTIAL]` **without** any record -> assert it is still repaired to `[COMPLETED]`
     (regression guard: the change must not make Stage 5a refuse to do its original job).
   **Demonstrating only Phase A's survival is insufficient — all three assertions are required.**
4. **Decimal extraction assertion** — a `### Phase 4.1: ... [PARTIAL]` heading in the fixture must
   extract as `4.1` and be repaired successfully, not fail with "Phase 4 not found".
5. Run the fixture through `update-task-status.sh --phase-check=refuse` (Phase 2's work) after the
   simulated Stage 5a and assert the gate now passes — the two halves of the trap are closed
   together.
6. Paste the fixture transcripts (before/after heading lines for all four phases) into the summary.
7. No task-number citation appears in either agent file.

---

### Phase 4: Reconcile the remaining phase-heading regex site and record the canonical form [NOT STARTED]

**Goal**: The last digits-only phase-heading site converges on the canonical form, and the canonical
form plus the deliberate no-letter-suffix decision are written down once so future sites copy rather
than re-invent.

**Tasks**:
- [ ] In `scripts/validate-artifact.sh`, bring the three phase-heading regexes to the canonical
      decimal-admitting form: the presence check (`grep -qE '^### Phase [0-9]+'`), the phase-line
      enumeration (`grep -n '^### Phase [0-9]\+'`, BRE), and the phase-number extraction
      (`grep -oE '^### Phase [0-9]+' | grep -oE '[0-9]+'`). Extraction must yield `3.1`, not `3`,
      so the per-phase Verification Tier warnings name the right phase.
- [ ] In `context/formats/plan-format.md`'s Implementation Phases format, document the canonical
      phase-heading shape once: `### Phase {N}: {name} [STATUS]` where `{N}` is an integer with at
      most one optional decimal sub-level (`3`, `3.1`), and state explicitly that **letter-suffixed
      sub-phases (`3a`) are not supported by any consumer and must not be used** — this is a
      deliberate decision, not an unimplemented feature. Give the canonical ERE and BRE forms
      verbatim so a future site can copy them.
- [ ] Note in the same place which sites are consumers of this shape (`update-task-status.sh`'s
      `count_plan_phases`, `validate-artifact.sh`, both implementation agents' Stage 5a,
      `skill-implementer-hard`'s resume scan, `skill-orchestrate`'s recovery grep) so a future
      change knows the blast radius. Reference them by script/skill and function/stage name — never
      by line number.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts `scripts/validate-artifact.sh` is the only remaining
phase-heading regex site not already touched by Phases 2 and 3, and that
`skills/skill-implementer-hard/SKILL.md` and `skills/skill-orchestrate/SKILL.md` already use the
decimal form and need no edit. Confirm with
`grep -rn '### Phase \[0-9\]' agent-system/extensions/core/` before editing; if the census finds an
additional digits-only site, add it to this phase (it is the same one-line change) and record the
correction in the summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` — three phase-heading regexes
- `agent-system/extensions/core/context/formats/plan-format.md` — canonical phase-heading shape,
  no-letter-suffix decision, consumer-site list

**Verification**:
- Deploy, then run `bash .claude/scripts/validate-artifact.sh` against this plan file itself and
  assert it exits 0 with no unexpected warnings (this plan has no decimal sub-phases, so it is the
  regression case).
- Run it against a fixture plan containing a `### Phase 2.1:` heading with a `**Verification Tier**`
  field and assert the phase is enumerated and reported as `2.1`, not `2`, and not skipped.
- Run it against a fixture where the `2.1` phase is *missing* its tier field and assert the warning
  names phase `2.1` — proving the extraction fix reached the message.
- `grep -n 'letter' context/formats/plan-format.md` confirms the no-letter-suffix decision is stated.

---

### Phase 5: Wire the outcome into the handoff schema and the enforcement checklist [NOT STARTED]

**Goal**: The handoff documentation states how an exclusion-closed phase is accounted for, and the
plan-format enforcement checklist knows the marker and the record requirement — so validation and
orchestration both see the outcome.

**Tasks**:
- [ ] In `docs/architecture/handoff-schema.md`, extend the `phases_completed` / `phases_total` field
      definition: a phase closed via `[COMPLETED WITH EXCLUSIONS]` counts toward `phases_completed`
      identically to a `[COMPLETED]` phase. State the reasoning explicitly — the completion-claim
      gate consumes only these self-reported integers and never reads the plan file, so the
      agent-side self-report is the sole lever; under-counting an exclusion-closed phase drives the
      gate's "phase accounting present, incomplete" case and refuses completion forever.
- [ ] In the same file, confirm no new handoff field is introduced. State that deliberately: the
      record lives in the plan artifact, and the handoff carries only the already-existing integer.
      Note the contrast with the strategic-sorry family member, which *does* carry a handoff-side
      `sorry_inventory` — the difference follows from exclusions having no follow-up to track.
- [ ] In `rules/plan-format-enforcement.md`, add `[COMPLETED WITH EXCLUSIONS]` to the "Valid markers"
      list in the Phase heading format bullet, keeping the existing note that these are
      phase-heading markers distinct from the plan-level `- **Status**:` vocabulary.
- [ ] In the same file, add the record requirement to the required-per-phase-fields guidance: a
      `#### Reasoned Exclusions` subsection is REQUIRED whenever a phase heading carries the
      exclusion marker, with the `Item | Reason | Evidence` minimum columns. State the current
      enforcement level honestly — this checklist item is advisory prose unless and until
      `validate-artifact.sh` grows a corresponding check, matching how the existing
      `**Verification Tier**` item documents its own advisory-first status.
- [ ] Run the final cross-file consistency census (see Scope Hypothesis) and fix any site still
      enumerating the pre-existing five-marker set as exhaustive.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that after Phases 1-4, exactly zero sites in the source
store still present the phase-heading marker set as exhaustive without
`[COMPLETED WITH EXCLUSIONS]`. Confirm with a census over the source store for the marker
enumeration pattern and reconcile against the site list recorded in Phase 1. Any residual site is
fixed here if it is a one-line enumeration; escalate to a follow-up if it requires substantive
rewriting.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — `phases_completed`
  accounting rule, explicit no-new-field statement, family contrast
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — valid-marker list, record
  requirement, honest enforcement-level statement

**Verification**:
- `grep -rn 'COMPLETED WITH EXCLUSIONS' agent-system/extensions/core/` returns hits in every file
  this plan touched and in no file it did not.
- The marker-enumeration census returns no site presenting the old five-marker set as exhaustive.
- `bash .claude/scripts/validate-artifact.sh` (after deploy) still passes on this plan file.
- The handoff-schema statement is consistent with the agent-side instruction added in Phase 3
  (same accounting rule stated in both places, cross-referenced, not independently invented).
- No task-number citation appears in either edited file.

---

## Testing & Validation

- [ ] Phase 2's negative fixture demonstrates that a plain `[PARTIAL]` phase still fails
      `--phase-check=refuse` after the DONE-regex change (gate not weakened).
- [ ] Phase 2's positive round-trip demonstrates `update-phase-status.sh` writes the marker,
      is idempotent on re-invocation, and still rejects unknown tokens.
- [ ] Phase 3's negative fixture demonstrates all three Stage 5a outcomes: exclusion marker
      survives untouched; documented `[PARTIAL]` repairs to the exclusion marker; undocumented
      `[PARTIAL]` still repairs to `[COMPLETED]`.
- [ ] Phase 3's decimal assertion demonstrates `Phase N.M` headings repair successfully rather than
      failing with "Phase N not found".
- [ ] The Stage 5a blocks in the two implementation agents are byte-identical before and after.
- [ ] `validate-artifact.sh` passes on this plan file and correctly names decimal sub-phases in its
      warnings.
- [ ] All fixture command transcripts (commands plus their actual output) are pasted into the
      implementation summary. A prose claim that a fixture passed, without its transcript, does not
      satisfy the verification requirement.
- [ ] No file outside `specs/**` written by this plan contains a task-number citation.
- [ ] No authored edit landed under `.claude/**`; `git status` shows changes only under
      `agent-system/extensions/core/` and `specs/`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/status-markers.md` (modified)
- `agent-system/extensions/core/context/formats/plan-format.md` (modified)
- `agent-system/extensions/core/context/contracts/anti-analysis.md` (modified)
- `agent-system/extensions/core/scripts/update-phase-status.sh` (modified)
- `agent-system/extensions/core/scripts/update-task-status.sh` (modified)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (modified)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (modified)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified)
- `agent-system/extensions/core/rules/plan-format-enforcement.md` (modified)
- `specs/924_documented_reasoned_exclusions_phase_outcome/summaries/01_*-summary.md` (new)
- Throwaway fixture task directories under `specs/` are created and **removed** within their phase;
  none may survive into the final commit.

## Rollback/Contingency

Every change is a text edit under `agent-system/extensions/core/`, tracked in git, with no schema
migration and no state mutation. Rollback is `git revert` of the phase commits followed by
`bash .claude/scripts/deploy-headless.sh` to regenerate `.claude/` from the reverted source.

Partial-rollback hazard: Phase 2's two script edits must revert together (that is why the phase is
`Commit Mode: atomic-batch` — one commit reverts cleanly). Reverting only the
`update-task-status.sh` half would leave a writable marker that the gate refuses forever; reverting
only the `update-phase-status.sh` half would leave a countable marker nothing can write.

If Phase 3's negative fixture cannot be made to pass all three assertions, stop and mark that phase
`[PARTIAL]` rather than shipping a Stage 5a change that might silently promote a documented
exclusion to `[COMPLETED]` — a partially-protected record is worse than the current state, because
it would look protected.
