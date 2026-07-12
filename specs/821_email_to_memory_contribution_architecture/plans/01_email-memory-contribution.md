# Implementation Plan: Task #821

- **Task**: 821 - Email-to-memory contribution architecture
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None (research complete; task 822 will consume this design)
- **Research Inputs**: specs/821_email_to_memory_contribution_architecture/reports/01_team-research.md
- **Artifacts**: plans/01_email-memory-contribution.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 821 is a cross-extension **design** task (`email` -> `memory`): route *confirmed*
email-cleanup decisions into the memory vault as sender/domain-aggregated preference memories
that evolve over time. The research phase (4-teammate team research) converged on a single
skeleton and surfaced eight load-bearing gaps (G1-G8) plus scope-completeness omissions that
the design deliverable must resolve before task 822 writes code. This plan's phases produce a
durable, agent-visible **design specification document** that fixes the capture point, the
normalized identity key (empirically verified against a real `email-census`/`email-classify`
sample), the memory schema and topic namespace, the deterministic dedup + tally-based
update/operation strategy, the retrieval/distill guardrails, and the opt-in gate behavior --
then records forward-compatibility decisions, the 822 scope recommendation, and hand-authored
ROADMAP.md entries. Definition of done: a single design artifact resolving G1-G8, a verified
identity-key rule, ROADMAP entries added, and a clear 822 scope handoff.

### Research Integration

The convergent skeleton and every design decision below are drawn directly from
`reports/01_team-research.md`:
- **Capture point** (A/B, Conflict 3/4): in-skill, post-Stage-6-Verify inline opt-in harvest in
  `skill-email-cleanup`; not the unproven `hooks: {}` lifecycle slot; not a deferred
  `/todo`-substrate harvest (`/email` has no `project_number`).
- **Aggregation unit** (A, C2): `--all` Stage 2.5 bucket grouping as the harvest *trigger/start
  key*; the *stored* memory key is a normalized identity that may split heterogeneous senders.
- **Storage** (B, Conflict 5): vault memories via `skill-memory` CREATE/UPDATE/EXTEND under a
  reserved `email/preferences/{key}` topic namespace.
- **Confidence model** (Conflict 2, key synthesis): a per-action tally
  `{delete_count, archive_count, keep_count, last_seen}`; dominant action is *derived*;
  contradiction handling is tally arithmetic -- no bespoke decay engine, no new skill-memory verb.
- **Gaps G1-G8** and the scope-completeness omissions are the substance of this task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` currently has zero memory/email/preference entries (Teammate D). Task 821
opens a new capability lane and must **propose its own ROADMAP entries by hand** (meta tasks do
not auto-annotate). Phase 6 adds: "Preference-memory read-back for email-classify" and
"Generalize confirmed-decision harvest beyond email." This plan itself does not modify
ROADMAP.md; the implementer does so as Phase 6 work.

## Goals & Non-Goals

**Goals**:
- Produce one durable design specification document resolving gaps G1-G8.
- Fix and **empirically verify** the normalized identity key (G2) against a real
  `email-census`/`email-classify` sample -- during design, not deferred to 822.
- Specify the memory schema (per-action tally, `category: preference` field, redaction
  decision), the `email/preferences/{key}` topic namespace, deterministic dedup, and the
  CREATE/UPDATE/EXTEND operation mapping.
- Specify retrieval/distill guardrails (namespace segregation, zero-retrieval purge exemption,
  cross-contamination fix) and feedback-loop guardrails.
- Specify the non-silent, `--clean`-independent opt-in gate behavior.
- Record forward-compat decisions (read-back contract spec G8, deferred generalization notes),
  a concrete 822 scope recommendation, and hand-authored ROADMAP entries.

**Non-Goals**:
- Writing any production code for the harvest, memory writes, or gate (that is task 822).
- Implementing the read-back "preference engine" loop closure (future task 823).
- Building measurement/audit tooling (future task 824, if split out).
- Auto-writing preferences into the `email-classify` binary's static rule table
  (`email-preferences.md` is a distinct layer and must stay separate).
- Adopting speculative angles (notmuch-ruleset export, local-model training data) -- flag only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Identity key chosen on paper fails on real mail (plus-addressing, DMARC rewrites, List-Id vs From) | H | M | Phase 2 verifies the normalization rule against a real `email-census`/`email-classify` sample before committing; document the DMARC caveat as a known limitation |
| Deterministic-key dedup deviates from skill-memory's fuzzy contract and silently double-writes | H | M | Phase 4 specifies exact `topic == email/preferences/{key}` short-circuit *before* fuzzy path, with fuzzy retained only as a near-miss CREATE-default suggestion; document the contract deviation explicitly |
| `/distill` zero-retrieval purge (`retrieval_count==0 AND age>30d`) wrongly reaps email-preference memories (read by email-side, not `memory-retrieve.sh`) | H | H | Phase 5 mandates a topic-prefix exemption OR an email-side retrieval-increment; design doc names the exact mechanism |
| Email-triage preference leaks into unrelated task `<memory-context>` (corpus-wide keyword scoring, proper nouns pass the stopword filter) | H | M | Phase 5 specifies namespace de-weighting/filter in `memory-retrieve.sh` + redaction decision (domain + stable sender-hash vs plaintext PII) |
| Transactional confirms (one receipt) conflated with durable preferences; automation-bias entrenches early mistakes | M | M | Phase 1 evidentiary threshold (uniform batch action or rolling N>=3 at >=80% consistency); Phase 5 feedback-loop cap + evidence-surfacing gate |
| Scope creep: revocation UX, cross-account scoping, success metric silently dropped from the 2-task chain | M | M | Phase 5 makes an explicit fold-into-822 vs spawn-823/824 recommendation; nothing is silently dropped |
| Design doc placed where 822 cannot find it | M | L | Phase 6 writes to a durable extension-context path readable by future email/memory tasks and cross-links it from the task summary |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 4 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture point, harvest trigger, and evidentiary rules [COMPLETED]

**Goal**: Fix exactly where/when the harvest fires and what qualifies a confirm as
preference-worthy (skeleton + G1/C1 + C2).

**Tasks**:
- [x] Specify the capture point: an opt-in harvest step inside `skill-email-cleanup` firing
  **after Stage 6 (Verify)** on *verified confirmed* actions only -- never on raw
  `proposed_action`. Cite the exact SKILL.md stages. *(completed: design doc §1.1)*
- [x] Specify the harvest unit: one candidate per distinct sender/domain touched, derived from
  the `--all` Stage 2.5 bucket grouping (`bulk-bucket-review.md`: domain key, full-address for
  freemail/shared domains, `min()` confidence rollup); in default mode, derive the same key
  post-hoc from the approved manifest's `sender` field. Never one candidate per message.
  *(completed: design doc §1.2)*
- [x] Record the rejected alternatives with rationale: the `hooks: {}` lifecycle slot
  (unproven/unverified failure-isolation in-repo) and the deferred `/todo`-substrate harvest
  (`memory-harvest.sh` keys off `project_number` in `state.json`, absent for ad-hoc `/email`).
  *(completed: design doc §1.3, verified both extensions' manifest.json hooks fields directly)*
- [x] Specify the **evidentiary threshold** (G1/C1): a running per-action tally, plus a promotion
  rule (uniform action across the batch for that sender, OR rolling N>=3 confirms at >=80%
  consistency) before writing/strengthening a preference. *(completed: design doc §1.4)*
- [x] Specify **mixed-sender handling** (C2) as a first-class branch: record the split by
  subject/category token OR decline to aggregate; never average heterogeneous actions into a
  false scalar. Note that the *review* partition and the *memory* partition need not be identical.
  *(completed: design doc §1.5)*

**Timing**: ~1.5 hours

**Depends on**: none

**Files to modify**:
- Design-doc draft (working notes) -- final assembly in Phase 6.

**Verification**:
- Capture point cites concrete `skill-email-cleanup` SKILL.md stage numbers and
  `bulk-bucket-review.md` mechanics.
- Evidentiary threshold and mixed-sender branch are each stated as testable rules.

---

### Phase 2: Identity key normalization + real-sample verification [COMPLETED]

**Goal**: Choose one documented identity key + normalization rule and **verify it against real
mail** (G2) -- the load-bearing empirical step the research insists must happen during design.

**Tasks**:
- [x] Read `wrapper-contracts.md:43-47` to confirm the manifest `sender` is a bare, unnormalized
  string with no case/display-name/plus-addressing/DMARC/List-Id contract. *(completed: design
  doc §2.1 -- confirmed manifest schema has no List-Id field at all)*
- [x] Define one normalization rule: lowercase; strip plus-addressing tag from local-part;
  `local-part@domain` primary key with **domain rollup fallback**; prefer `List-Id` over `From`
  for lists; document the DMARC-rewritten-forwarder caveat as a known limitation. *(completed:
  design doc §2.2; deviation -- List-Id preference documented as not implementable from the
  current manifest schema, see below)*
- [x] Run a real `email-census`/`email-classify` sample (headless, read-only) and check the
  proposed rule against actual senders: freemail vs corporate domains, plus-addressed senders,
  list traffic, and any DMARC-rewritten forwarders present. Record concrete counterexamples.
  *(completed: design doc §2.3 -- ran genuinely read-only `email-classify --emit-tagged` against
  2,128 real tagged messages / 751 unique senders; all 3 observable edge classes confirmed with
  concrete examples, List-Id class confirmed absent from the manifest schema itself)*
- [x] Finalize the key rule, adjusting for what the sample reveals; document residual edge cases.
  *(completed: design doc §2.4-2.5 -- key ships VERIFIED, not provisional-unverified; the
  plan's fallback contingency was not needed)*

**Timing**: ~1.5 hours

**Depends on**: none

**Files to modify**:
- Design-doc draft (identity-key section + verification appendix).

**Verification**:
- The normalization rule is validated against a named real sample, not asserted on paper.
- At least the four edge classes (freemail, plus-addressing, List-Id, DMARC) are each addressed
  with an observed example or an explicit "not present in sample" note.

---

### Phase 3: Memory schema, tally model, and topic namespace [NOT STARTED]

**Goal**: Specify the stored memory's schema, the per-action tally, the redaction decision, and
the reserved namespace (G5, G7, Conflict-2 synthesis).

**Tasks**:
- [ ] Specify the reserved topic namespace `email/preferences/{key}` where `{key}` is the Phase 2
  normalized identity.
- [ ] Specify the per-action tally stored in the memory body:
  `{delete_count, archive_count, keep_count, last_seen}`; dominant action is a *derived* function
  of the tally (not a stored scalar). Reference Mem0's mark-superseded framing for the `## History`
  convention.
- [ ] Make the **redaction decision** (G5): plaintext address vs `domain + stable sender-hash`.
  State the choice and its rationale (PII exposure in `<memory-context>` vs debuggability); this
  choice determines the schema.
- [ ] Specify the forward-compat **`category: preference`** frontmatter field (G7): schema-additive,
  non-breaking, recognized where present by `index.md`/`/distill`, not required. Cross-check
  against the current frontmatter set (`title, created, tags, topic, source, modified`;
  `memory/README.md:151-160`).
- [ ] Define the memory body template (title, tally block, `## History` lines, evidence summary
  "junked N, kept M") consistent with the redaction choice.

**Timing**: ~1 hour

**Depends on**: 2

**Files to modify**:
- Design-doc draft (schema section).

**Verification**:
- Schema fields map 1:1 to what Phase 4's operations read/write.
- Redaction decision is explicit and consistently applied through the body template.

---

### Phase 4: Deterministic dedup + operation mapping [NOT STARTED]

**Goal**: Specify how a harvested candidate maps to CREATE/UPDATE/EXTEND with deterministic dedup
(G3) and tally-based contradiction handling.

**Tasks**:
- [ ] Specify the **deterministic exact-key dedup** short-circuit: look up
  `topic == "email/preferences/{key}"` in `memory-index.json` (jq filter) *before* the existing
  fuzzy keyword-overlap path. Explicitly document this as a sanctioned deviation from
  skill-memory's 60%/30% fuzzy contract.
- [ ] Retain fuzzy search only as a near-miss *suggestion* (`mail.foo.com` vs `foo.com`),
  defaulting to CREATE when no exact key matches.
- [ ] Specify the operation mapping: first sighting -> CREATE; same dominant action reconfirmed
  -> EXTEND (append dated `## History` line, bump the matching counter); contradicting action ->
  UPDATE (increment the opposite counter, which shifts the derived dominant-action ratio; move
  prior summary to `## History`). Emphasize contradiction handling is tally arithmetic -- no new
  skill-memory API verb, no bespoke decay/EWMA math.
- [ ] Specify batch index regeneration after a harvest round (reuse skill-todo's batch-regen
  logic, not its storage substrate).

**Timing**: ~1 hour

**Depends on**: 3

**Files to modify**:
- Design-doc draft (dedup + operation section).

**Verification**:
- Each of CREATE / EXTEND / UPDATE has a stated trigger and a concrete tally effect.
- The exact-key-before-fuzzy ordering and its contract deviation are documented.

---

### Phase 5: Retrieval/distill guardrails, feedback-loop caps, gate, and scope decisions [NOT STARTED]

**Goal**: Close the safety gaps (G4, G6), specify the opt-in gate, and make the explicit 822
scope / follow-on-task recommendation.

**Tasks**:
- [ ] **G4 distill exemption**: specify that `/distill`'s zero-retrieval purge
  (`retrieval_count==0 AND age>30d`) must exempt the `email/preferences/*` topic prefix OR that
  email-side reads increment `retrieval_count`. Name the chosen mechanism.
- [ ] **G4 cross-contamination**: specify a `memory-retrieve.sh` fix -- namespace de-weighting or
  a task-type/topic filter so `email/preferences/*` memories do not leak into unrelated tasks'
  `<memory-context>` (note the >4-char/stopword filter does not drop proper nouns like `github`,
  `google`, `notifications`).
- [ ] **G6 feedback-loop guardrails**: cap the confidence a stored preference may contribute to
  `proposed_action`; require the gate to *surface evidence* ("junked N, kept M") rather than
  pre-selecting an action; note the Phase-4 tally is itself the reversal mechanism.
- [ ] **Gate behavior**: specify the opt-in prompt reusing skill-todo's harvest->dedup->tiered
  `AskUserQuestion`->batch-regen *logic* (not its `state.json` substrate) as one consolidated,
  non-silent prompt adjacent to the just-approved action; independent of `--clean`.
- [ ] **Scope decision**: recommend whether to fold revocation/edit UX, cross-account (gmail vs
  logos) scoping, archive-scope isolation, and a minimal success-signal/test phase into 822, OR
  to keep 822 lean and spawn **task 823** (read-back "preference engine") and **task 824**
  (measurement/audit). State a clear recommendation for the user/`/plan 822` to act on.

**Timing**: ~1.5 hours

**Depends on**: 1, 4

**Files to modify**:
- Design-doc draft (guardrails + gate + scope section).

**Verification**:
- Each of G4 (two parts), G6, and the gate has a named, implementable mechanism.
- The 822-scope recommendation names concrete tasks (fold-in list, or 823/824) -- nothing dropped.

---

### Phase 6: Assemble design deliverable + ROADMAP entries [NOT STARTED]

**Goal**: Consolidate the phase drafts into one durable design specification document and add the
hand-authored ROADMAP entries.

**Tasks**:
- [ ] Assemble Phases 1-5 into a single design specification document at a durable,
  agent-visible location readable by future email/memory tasks, e.g.
  `.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md`
  (create the `design/` subdir lazily). Include the G1-G8 resolution, the verified identity key
  and its verification appendix, the schema, dedup/operation, guardrails, gate, and scope
  sections.
- [ ] Add a **"Future: read-back contract (not in 822)"** section (G8/D1): a named lookup contract
  so 822's write schema is designed lookup-ready (the vault must become a preference *engine*,
  not just a *log*); file as the seed for task 823.
- [ ] Add a **deferred design notes** section (D4/D5): generalize the confirmed-decision->preference
  harvest beyond email only after a second real client justifies extraction; flag notmuch-ruleset
  export and local-model training-data as speculative (do not adopt).
- [ ] Add ROADMAP.md entries by hand (meta tasks do not auto-annotate):
  "Preference-memory read-back for email-classify" and
  "Generalize confirmed-decision harvest beyond email."
- [ ] Note the `email-preferences.md` static classifier rule table as a distinct, parallel layer
  that must never be auto-written by the vault path.

**Timing**: ~0.5 hour

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md` - new design deliverable.
- `specs/ROADMAP.md` - add two hand-authored entries.

**Verification**:
- The design document resolves all of G1-G8 with a locatable section for each.
- Two ROADMAP entries are present.
- The read-back contract and deferred-notes sections are present and marked out-of-822-scope.

---

## Testing & Validation

- [ ] Design document exists at the durable extension-context path and is internally consistent
  (schema fields match the operations that read/write them).
- [ ] Identity-key rule (G2) shows evidence of verification against a real
  `email-census`/`email-classify` sample, with observed edge-case examples.
- [ ] Every gap G1-G8 has an addressable, named resolution in the document.
- [ ] `/distill` zero-retrieval exemption and `memory-retrieve.sh` cross-contamination fix each
  name a concrete mechanism.
- [ ] Two ROADMAP.md entries added; 822 scope recommendation is explicit (fold-in vs 823/824).
- [ ] No production code written; `email-preferences.md` static table untouched.

## Artifacts & Outputs

- `specs/821_email_to_memory_contribution_architecture/plans/01_email-memory-contribution.md` (this plan)
- `.claude/extensions/email/context/project/email/design/email-to-memory-preferences.md` (design deliverable)
- `specs/ROADMAP.md` (two appended entries)
- `specs/821_email_to_memory_contribution_architecture/summaries/01_email-memory-contribution-summary.md` (on /implement)

## Rollback/Contingency

- All changes are documentation-only (design doc + two ROADMAP lines); revert via `git checkout`
  of the two touched files. No runtime surface is modified.
- If the Phase 2 real-sample verification is blocked (no `email-census`/`email-classify` access),
  mark Phase 2 [BLOCKED], document the key rule as *provisional-unverified*, and record the
  verification as a required precondition folded into task 822 -- do not silently ship an
  unverified key.
