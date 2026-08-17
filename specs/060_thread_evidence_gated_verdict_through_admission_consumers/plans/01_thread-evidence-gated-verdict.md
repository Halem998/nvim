# Implementation Plan: Task #60

- **Task**: 60 - Thread the evidence-gated verdict and --allow-scope-collision through admission consumers
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 59 (predicate half — COMPLETED, verified live at schema v5)
- **Research Inputs**: `specs/060_thread_evidence_gated_verdict_through_admission_consumers/reports/01_thread-evidence-gated-verdict.md`
- **Artifacts**: plans/01_thread-evidence-gated-verdict.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The admission *predicate* (`orchestrate-batch-admit.sh`) already emits schema v5 with a fully
implemented `idle_overlap_advisory` field, and `docs/architecture/batch-admit-schema.md` is
already rewritten for v5. This task is purely the consumer-side half: every surface that branches
on the verdict, renders it, or documents it must be brought into agreement with what the predicate
now actually emits, plus a new `--allow-scope-collision` consumer-side override. Definition of
done: all 9 declared consumer files agree with the live v5 predicate, the two orchestrate skill
twins are byte-equivalent in contract, the new flag is threaded parser -> command -> both skills
without ever reaching the predicate script, and a redeploy has been performed and verified.

### Research Integration

The research report supplies exact file/line anchors for all 5 WORK items and is treated as
ground truth for locations. Key integrated findings:

- The predicate half is verified live and **out of scope**: no edits to
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` or
  `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`.
- `--allow-self-modifying` supplies an exact 5-touch-point mirror pattern in
  `scripts/parse-command-args.sh` (doc comment L25-26, default init L86, detection L136-138,
  FOCUS_PROMPT strip L160, export L170) and an exact consumer-side branch shape in
  `skill-orchestrate/SKILL.md` step 4.5 (L1505-1537).
- Class D's suggestion string already exists verbatim in
  `scripts/orchestrate-predispatch-review.sh` (jq computation L386-394, rendered string
  L478-491). It is a **read-only source** for WORK 3; that script is not edited.
- `orchestrate-dry-run-report.sh`'s verdict loop special-cases `self_mod == "true"` on `admit`
  (L336-341) and branches `defer_reason` (L343-374) with no `.idle_overlap_advisory` check
  anywhere.
- `orchestrate-batch-results-template.md` has no idle/advisory subsection at all; its
  `### Deferred (redeploy checkpoint)` subsection is the render-when-non-empty pattern to mirror.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap consultation was
requested; this stage was skipped.

## Goals & Non-Goals

**Goals**:

- Render `idle_overlap_advisory` loudly and distinctly at every consumer surface that acts on or
  reports a verdict: the three dispatch-path warning sites, the batch results template, and
  `orchestrate-dry-run-report.sh`.
- Add `--allow-scope-collision` as a per-invocation, default-off, consumer-side override threaded
  parser -> command -> both orchestrate skills, never passed to `orchestrate-batch-admit.sh`.
- Fold the existing Class D `dependencies[]`-edge suggestion into the `cross_batch` warning
  templates where the exclusion is actually reported, reusing the existing string and ordering
  rule verbatim.
- Make the corpus agree on `cross_batch` self-clearing semantics: the schema doc, both skill
  twins, and `commands/orchestrate.md` state the same thing.
- Eliminate every stale schema-version reference in the consumer files.
- Keep `skill-orchestrate` and `skill-orchestrate-hard` in exact contract lockstep.

**Non-Goals**:

- No changes to `orchestrate-batch-admit.sh` or `batch-admit-schema.md` (upstream, already v5).
- No new suggestion mechanism for WORK 3 — the existing Class D string is reused, not rebuilt.
- No new admission-predicate logic; every change is consumer-side rendering, documentation, or a
  consumer-side decision not to act on an honestly-emitted verdict.
- No change to `orchestrate-predispatch-review.sh` (it is a read-only source for WORK 3).
- No widening of the `--allow-scope-collision` bypass to `in_batch` (see Decisions).

## Decisions

These are binding decisions this plan makes; the implementer executes them rather than
re-litigating them.

**D1 — `--allow-scope-collision` bypasses `cross_batch` ONLY, never `in_batch`.**
The research report recommended bypassing both `collision_scope` values for symmetry with the
unqualified flag name. This plan deliberately chooses the narrower option instead, because the two
scopes are not symmetric hazards:

- An `in_batch` defer means the colliding task is in *this same invocation's* `eligible_tasks` and
  will be dispatched as a live concurrent agent. Bypassing it would put two live agents editing the
  same files in the same cycle — a concurrent-write corruption hazard, not a friction. It also has
  a working, bounded, zero-cost remedy already: `context/patterns/multi-task-operations.md`'s
  Tier 1 (auto-sequence) bounded second pass (L235-257) resolves it by waiting one cycle.
- A `cross_batch` defer means the colliding task is idle and outside `task_numbers`. Post-task-59
  this only fires when execution evidence exists; the residual friction is exactly the
  "batch composition needs human review" exclusion an operator override exists to relieve.

Rejected alternative recorded: bypassing both scopes. Consequence of D1: the flag's `## Options`
row, its parser doc comment, and every bypass notice MUST say "cross-batch" explicitly, so the
unqualified flag name never misleads a reader into expecting `in_batch` coverage. An `in_batch`
defer encountered while the flag is active is handled exactly as today, with no bypass notice.

**D2 — `orchestrate-dry-run-report.sh` is in scope for WORK 1.**
The research flagged this as inferred rather than asserted. It is confirmed in scope: it is in the
task's declared `file_scope`, it is one of the schema doc's four named `defer_reason`-branching
consumers, and it has the identical rendering gap. Phase 6 covers it.

**D3 — the hard twin's stale "schema v4" mention is swept to v5 in the same pass.**
WORK 5's prose names only the two files literally saying "v3", but the co-maintenance mandate
requires the twins to agree and all three must agree with the live predicate. Phase 1 covers all
three.

**D4 — `task-lock.md` and `multi-task-operations.md` get a bounded cross-reference, not silence.**
Both are in the declared `file_scope`. Neither carries stale version prose or a false
self-clearing claim, so neither needs a correction. But D1 creates a new asymmetry
(`cross_batch` overridable, `in_batch` not) that lands squarely on
`multi-task-operations.md`'s Tier 1 auto-sequence discussion, which must name it. If the
implementer finds `task-lock.md` genuinely needs no edit, that is closed with a
`#### Reasoned Exclusions` record in Phase 8, not left unexplained.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Co-maintenance drift between `skill-orchestrate` and `skill-orchestrate-hard` | H | H | Every phase that edits one twin edits the other in the SAME phase and verifies both before closing. Never batch base-skill edits across phases and defer the twin. |
| Redeploy rewrites the running orchestrator's own skill definitions mid-task | H | M | Deploy is deliberately confined to Phase 9, after all source-store edits are committed. `git-snapshot.sh 60` before the deploy; `verify-deploy.sh` after. |
| Hand-editing `.claude/**` instead of the source store — silently wiped on next regeneration | H | M | Every phase's file list names `agent-system/extensions/core/**` paths only. Phase 9's verification greps for any accidental `.claude/**` modification in the diff. |
| Advisory rendering silently merged into an existing WARNING, obscuring one of the two facts | M | M | The advisory line is specified as a separate `[orchestrate] ADVISORY:` line printed independently of the verdict's own warning, on `admit` and `defer` alike. Phase 4's verification reads each template back to confirm two distinct lines. |
| Editing overlapping regions of the same `cross_batch` bullet across phases 2/3/4 causes churn | M | H | Phases 2, 3, 4 are strictly sequential (waves 2, 3, 4) and each fully closes its own semantic change to that bullet before the next opens. |
| `commands/orchestrate.md`'s Step 3/4 block mistaken for executing code | M | M | It is explicitly illustrative. Every phase touching it states edits there are documentation-correctness only; runtime behavior comes from the SKILL.md files. |
| `--allow-scope-collision` accidentally passed to `orchestrate-batch-admit.sh` | H | L | Phase 8's verification greps every `orchestrate-batch-admit.sh` invocation site across the corpus to confirm no new argument was added. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 6, 7 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 8 | 5, 7 |
| 7 | 9 | 1, 2, 3, 4, 5, 6, 7, 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Stale schema-version sweep (WORK 5) [COMPLETED]

**Goal**: Every schema-version reference in the consumer corpus reads v5, matching the live
predicate.

**Tasks**:

- [x] `skills/skill-orchestrate/SKILL.md` ~L1500: change `(schema v3 — every defer verdict carries
      this REQUIRED discriminator...` to `v5`. *(completed)*
- [x] `commands/orchestrate.md` ~L270: change the identical `(schema v3 —` phrase to `v5`. *(completed)*
- [x] `skills/skill-orchestrate-hard/SKILL.md` ~L1566: change `(schema v4 —` to `v5` (per D3). *(completed)*
- [x] Sweep the remaining declared files for any other version reference:
      `grep -rn 'schema v[0-9]\|batch-admit-v[0-9]' ` across all 9 `file_scope` paths. *(completed:
      confirmed exactly 3 stale current-version hits, matching the Scope Hypothesis)*
- [x] Leave `(NEW in v4)` markers on the `session_active` branches alone — those are historical
      "introduced in" annotations, not claims about the current schema version. Confirm each
      remaining `v4` occurrence is of that kind before leaving it. *(completed: all remaining `v4`
      hits in the 3 SKILL/command files plus `orchestrate-dry-run-report.sh` are historical "NEW
      in v4"/"As of v4" annotations, left unchanged)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: exactly 3 stale current-version references exist (two "v3", one "v4"), and
every other `v4` occurrence is a historical `NEW in v4` annotation. Confirm at implementation time
by running the grep above across all 9 declared files and classifying every hit before editing;
if the count differs, fix all of them and record the corrected count.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - version string
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - version string
- `agent-system/extensions/core/commands/orchestrate.md` - version string

**Verification**:

- `grep -rn 'schema v[0-9]' ` across the 9 declared files returns only `v5` for current-version
  claims.
- Diff read-through confirms every changed hunk is a version literal inside prose.

---

### Phase 2: Correct the false self-clearing claim (WORK 4) [COMPLETED]

**Goal**: The corpus states one consistent thing about `cross_batch` self-clearing: it does not
clear on its own within this invocation.

**Tasks**:

- [x] `skills/skill-orchestrate/SKILL.md` L1538-1542: stop asserting "Both branches ... becomes
      eligible again on a later cycle" as a blanket claim. Split the claim by `collision_scope`:
      keep the `in_batch` claim (it is true and load-bearing for the convergence argument
      elsewhere in the file); state for `cross_batch` that the candidate is excluded from this
      invocation, does NOT automatically become eligible again within this run (the colliding task
      is outside `task_numbers` and this loop has no mechanism to advance it), and that a human
      resolves batch composition or a future invocation re-evaluates once the colliding task's
      status independently changes. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md` ~L1841: inspect the second "it becomes eligible again
      next cycle" instance. Determine whether it is scoped to `self_modifying`/`in_batch` (where
      the claim is TRUE — leave it) or is a generalized claim (fix it the same way). Record which.
      *(completed: this instance (now ~L1850) is the task-lock acquire-refusal defer, a distinct
      mechanism from file_scope_collision with no in_batch/cross_batch split of its own — the lock
      is retried every cycle regardless of batch membership, so the claim is true; left unchanged)*
- [x] `skills/skill-orchestrate-hard/SKILL.md` L1578-1584: replace the
      "unchanged from the base skill's handling" pointer with a real transcription that carries
      the same split-by-`collision_scope` claim. Keep the existing Tier 1 cross-reference to
      `task-lock.md`'s "Four-Tier Conflict Response", but attach it to the `in_batch` half only,
      since the cycling-defer-is-Tier-1 claim is what is true of `in_batch`. *(completed)*
- [x] `commands/orchestrate.md` `cross_batch` WARNING bullet (~L307-316): verify it already agrees
      ("Excluding #{task_number} from this run — batch composition needs human review"). Edit only
      if the surrounding prose contradicts the corrected claim; otherwise record no-change.
      *(completed: verified no "eligible again" claim exists on the cross_batch bullet in this
      file at all — no change needed)*
- [x] Read `docs/architecture/batch-admit-schema.md`'s "Deferral-Direction Rule and Caller
      Guidance" section (~L213-225) as the alignment target. Do NOT edit it. *(completed: read;
      corrected claim agrees — "a human resolves batch composition")*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: the false claim occupies one bullet in the base skill (L1538-1542) plus one
bullet in the hard twin (L1578-1584), with one further candidate instance at ~L1841 whose scope
must be determined rather than assumed. Confirm at implementation time via
`grep -n 'eligible again' ` across both SKILL.md files and classify every hit as in_batch-true or
cross_batch-false before editing.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - split the self-clearing claim
  by `collision_scope`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - transcribe the same split
- `agent-system/extensions/core/commands/orchestrate.md` - verify agreement, edit only if needed

**Verification**:

- `grep -n 'eligible again' ` on both SKILL.md files: every remaining hit is scoped to
  `in_batch`, `self_modifying`, or `session_active` — none to `cross_batch`.
- Read the corrected base bullet and the hard twin bullet side by side; they make the same claim.
- Read the corrected claim against the schema doc's "Deferral-Direction Rule" prose; they agree.

---

### Phase 3: Fold the Class D `dependencies[]` suggestion into the `cross_batch` warnings (WORK 3) [COMPLETED]

**Goal**: The `dependencies[]`-edge remedy is printed at the moment of exclusion, not only in the
separate upstream Step 1.5 review surface.

**Tasks**:

- [x] Read `scripts/orchestrate-predispatch-review.sh` L386-394 (the `suggested_dependent` /
      `suggested_predecessor` jq computation) and L478-491 (the rendered string) as the verbatim
      source. This script is NOT edited. *(completed)*
- [x] Extract the ordering rule verbatim: the higher task number becomes the dependent, the lower
      becomes the predecessor. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md` `cross_batch` WARNING template (~L1555-1560): append the
      identical suggestion clause — "suggest adding #{suggested_predecessor} as a dependencies[]
      entry on #{suggested_dependent} to serialize them" — reusing the existing wording, not a
      paraphrase. *(completed)*
- [x] `commands/orchestrate.md` `cross_batch` WARNING template (~L311-316): same append. *(completed)*
- [x] `skills/skill-orchestrate-hard/SKILL.md` `file_scope_collision` bullet: same append, now that
      Phase 2 has turned it into a real transcription. *(completed: appended as prose, matching the
      hard twin's existing template-free style for this bullet)*
- [x] Add a one-line cross-reference in the base skill's `cross_batch` bullet naming
      `orchestrate-predispatch-review.sh`'s Class D as the shared origin of the suggestion, so the
      two surfaces are visibly one mechanism rather than two. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: exactly 3 `cross_batch` warning-template sites need the suggestion clause
(base skill, hard twin, command doc). Confirm at implementation time via
`grep -rn 'batch composition needs human review' ` across the 9 declared files; every hit is a
site requiring the clause.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - append suggestion clause +
  origin cross-reference
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - append suggestion clause
- `agent-system/extensions/core/commands/orchestrate.md` - append suggestion clause

**Verification**:

- Diff the three appended clauses against `orchestrate-predispatch-review.sh` L478-491 character
  by character for the shared substring; wording matches, not merely paraphrases.
- `grep -rn 'suggested_predecessor\|dependencies\[\] entry on' ` shows the clause at all three new
  sites plus the original script.

---

### Phase 4: Render `idle_overlap_advisory` in the dispatch-path warnings (WORK 1a) [COMPLETED]

**Goal**: Whenever a verdict carries `idle_overlap_advisory`, a distinct loud ADVISORY line is
printed at every dispatch-path site, regardless of the verdict's own `decision`.

**Tasks**:

- [x] `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5: add an advisory check that runs
      independently of the `.decision == "defer"` filter — the field appears on `admit` verdicts
      too. Specify it as `jq -e '.idle_overlap_advisory'` on every verdict, printed as its own
      line, never folded into an existing WARNING's text. *(completed)*
- [x] Use the advisory template shape (adapt to the file's existing warning voice):
      `[orchestrate] ADVISORY: Task #{task_number} has file_scope overlapping IDLE (status:
      {colliding_task_status}) out-of-batch task #{colliding_task_number} at {overlapping_path};
      not blocking because no execution evidence exists. Add a dependencies[] edge between
      #{task_number} and #{colliding_task_number} if ordering matters.` *(completed)*
- [x] State explicitly that the advisory is printed IN ADDITION to any `session_active` or
      `file_scope_collision` warning on the same verdict, because the advisory may name a
      *different* colliding task than the verdict's own subject — the two lines must never be
      merged. *(completed)*
- [x] Mirror both additions in `skills/skill-orchestrate-hard/SKILL.md`. *(completed)*
- [x] Mirror in `commands/orchestrate.md` Step 3/4 (documentation-correctness only — this block is
      explicitly illustrative, not executing). *(completed)*
- [x] Confirm the advisory is placed so it fires on `admit` verdicts, which the existing
      `.decision == "defer"` filter would otherwise skip entirely. This is the specific defect
      being fixed; do not nest the new check inside the defer filter. *(completed: verified the
      new block is placed after the defer-branching in all three files, not nested inside it)*

**Timing**: 1.0 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: exactly 3 dispatch-path sites require the advisory rendering (base skill step
4.5, hard twin's transcription, command doc Step 3/4). Confirm at implementation time by grepping
the 9 declared files for `.decision == "defer"` / `defer_reason` branch openings and checking each
is one of the three; `orchestrate-dry-run-report.sh` is deliberately handled separately in Phase 6.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - advisory check + ADVISORY line
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored
- `agent-system/extensions/core/commands/orchestrate.md` - mirrored (illustrative)

**Verification**:

- `grep -n 'idle_overlap_advisory' ` returns hits in all three files.
- Read each site back: the advisory check is OUTSIDE the `.decision == "defer"` filter.
- Read each site back: the ADVISORY line is a separate line from every WARNING template.
- Base skill and hard twin state the same contract.

---

### Phase 5: Render the advisory in the batch results surface (WORK 1b) [COMPLETED]

**Goal**: Advisory-carrying admits appear in the consolidated batch results output.

**Tasks**:

- [x] `context/patterns/orchestrate-batch-results-template.md`: add a new `### Admitted (idle
      overlap advisory)` subsection. Place it near the existing `### Deferred (...)` subsections
      but on the admitted side, since an advisory-carrying verdict is by definition an `admit`.
      *(completed)*
- [x] Columns: `Task | Colliding Task | Colliding Status | Overlapping Path | Note` — mirroring the
      `idle_overlap_advisory` field set. *(completed)*
- [x] Render unconditionally-when-non-empty, following the existing
      `### Deferred (redeploy checkpoint)` subsection's pattern verbatim (read it first; do not
      invent a new conditional-render convention). *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md` Stage MT-3/MT-5: confirm which accumulator structure
      collects per-cycle verdicts for the Stage MT-5 results render. If an accumulator for
      advisory-carrying admits already exists, wire the new subsection to it; if not, add one
      alongside `defer_ledger`, following that field's shape. *(completed: no existing accumulator
      found; added `idle_overlap_ledger` to Stage MT-1's schema, wired its append into step 4.5's
      advisory check, and wired it into Stage MT-5's read/report/write, following `defer_ledger`'s
      shape exactly)*
- [x] Mirror the accumulator addition in `skills/skill-orchestrate-hard/SKILL.md`. *(completed:
      the hard twin's `## Multi-Task Mode` section states multi-task mode is entirely delegated to
      the base skill's Stage MT-1 through MT-5 — the ledger has no separate hard-twin declaration,
      matching how `defer_ledger`/`forward_progress_violated` are already handled; added an
      "Accumulator note" recording this explicitly instead of a duplicate declaration)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: the template needs exactly one new `###` subsection, and the accumulator
either already exists or needs one new field. Confirm at implementation time by reading
`orchestrate-batch-results-template.md` end to end and by grepping both SKILL.md files for
`defer_ledger` to locate the accumulator convention before adding anything.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - new
  `### Admitted (idle overlap advisory)` subsection
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - accumulator wiring
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored

**Verification**:

- The new subsection's render condition and table shape match the `### Deferred (redeploy
  checkpoint)` precedent.
- Both SKILL.md files reference the new subsection by its exact heading text.
- `grep -n 'Admitted (idle overlap advisory)' ` returns the template plus both skill references.

---

### Phase 6: Render the advisory in `orchestrate-dry-run-report.sh` (WORK 1c) [COMPLETED]

**Goal**: The dry-run report surfaces idle-overlap advisories with the same vocabulary as the live
dispatch path.

**Tasks**:

- [x] Read the per-task verdict loop (~L320-375), specifically the `admit` branch's
      `self_mod == "true"` note at L336-341 and the `defer_reason` branches at L343-374, to match
      the file's existing `notes+=(...)` idiom exactly. *(completed)*
- [x] Add an `.idle_overlap_advisory` check that runs on EVERY verdict — the `admit` path and all
      defer paths — not only inside one branch. Follow the file's own existing guard style; note
      the L327-330 comment warning that `//` treats a literal `false` as falsy, and use an explicit
      null test rather than `//` for the advisory presence check. *(completed: placed immediately
      after `verdict` is computed, before the decision/defer_reason branching, so it is never
      skipped by an admit-branch `continue`)*
- [x] Emit a `notes+=("Task #$t: idle overlap advisory — ...")` entry naming the colliding task,
      its status, and the overlapping path, using the same vocabulary as the Phase 4 ADVISORY line
      so the two surfaces read as one mechanism. *(completed)*
- [x] Do not change any exclusion or admission logic in this script — this is reporting only.
      *(completed: verified — only a new `notes+=` entry was added, no existing branch's
      exclusion/admission behavior was touched)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - advisory rendering in the
  per-task verdict loop

**Verification**:

- `bash -n agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` passes. *(confirmed:
  SYNTAX OK)*
- `shellcheck` on the file produces no new findings relative to its pre-edit baseline (capture the
  baseline before editing). *(shellcheck is not installed in this environment; `bash -n` is the
  available syntax-check substitute — recorded as an environment limitation, not skipped silently)*
- Run the dry-run report against a live task set and confirm it completes and that the admitted-set
  and exclusion output is unchanged apart from any new advisory notes. *(the script refuses to run
  from the source-store tree by design — "must run from a deployed scripts/ tree" — and Phase 9 is
  the sole authorized point of redeploy in this task, so this live-invocation check is performed as
  part of Phase 9's post-deploy smoke test instead. Verified here via standalone jq logic testing
  against both the schema doc's documented advisory example verdict and a plain no-advisory
  verdict: the check correctly extracts `colliding_task_number`/`colliding_task_status`/
  `overlapping_path` in the advisory case and correctly evaluates to `null` (no note emitted) in
  the no-advisory case)*

---

### Phase 7: Add `--allow-scope-collision` to the argument parser (WORK 2a) [COMPLETED]

**Goal**: `ALLOW_SCOPE_COLLISION_FLAG` is parsed, defaulted off, stripped from the focus prompt,
and exported.

**Tasks**:

- [x] `scripts/parse-command-args.sh`, mirroring `ALLOW_SELF_MODIFYING_FLAG`'s exact 5 touch
      points: *(completed)*
  - [x] Doc comment block (near L25-26): describe `ALLOW_SCOPE_COLLISION_FLAG` — "true"/"false",
        default off, opt-in consumer-side bypass of the **cross-batch** `file_scope_collision`
        admission gate for this invocation only. State the cross-batch-only scope per D1 so the
        unqualified flag name does not mislead. *(completed)*
  - [x] Default init (near L86): `ALLOW_SCOPE_COLLISION_FLAG="false"`. *(completed)*
  - [x] Detection (near L136-138): `if [[ "$remaining" =~ --allow-scope-collision ]]; then
        ALLOW_SCOPE_COLLISION_FLAG="true"; fi`. *(completed)*
  - [x] FOCUS_PROMPT strip (near L160): add `| sed 's/--allow-scope-collision//g' \` in the
        existing chain. *(completed)*
  - [x] Export list (L170): append `ALLOW_SCOPE_COLLISION_FLAG`. *(completed)*
- [x] Verify the detection regex cannot be matched as a prefix of some other flag and does not
      itself shadow `--allow-self-modifying`. *(completed: `--allow-scope-collision` and
      `--allow-self-modifying` are distinct literal strings, neither a substring of the other;
      smoke-tested both flags together and independently, no cross-shadowing observed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly 5 touch points, at the line anchors above. Confirm at implementation
time by running `grep -n 'self.modifying\|SELF_MODIFYING' scripts/parse-command-args.sh` and
placing one new edit adjacent to each of the 5 hits; if the mirror pattern turns out to have more
or fewer sites, match whatever the grep actually reports.

**Files to modify**:

- `agent-system/extensions/core/scripts/parse-command-args.sh` - 5 touch points

**Verification**:

- `bash -n agent-system/extensions/core/scripts/parse-command-args.sh` passes. *(confirmed: SYNTAX
  OK)*
- Source the parser and confirm: with no flag, `ALLOW_SCOPE_COLLISION_FLAG` is `"false"`; with
  `--allow-scope-collision` present, it is `"true"`; and in both cases the flag text is absent from
  `FOCUS_PROMPT`. *(confirmed via direct sourcing smoke test)*
- Confirm `--allow-self-modifying` parsing is unchanged by the same smoke test. *(confirmed: both
  flags independently and together parse correctly with no interference)*

---

### Phase 8: Thread `--allow-scope-collision` through command and both skills (WORK 2b) [COMPLETED]

**Goal**: The flag reaches both orchestrate skills as delegation context and is acted on as a
consumer-side `cross_batch` bypass, never reaching the predicate script.

**Tasks**:

- [x] `commands/orchestrate.md`: *(completed)*
  - [x] `## Options` table (~L35): add a row mirroring the `--allow-self-modifying` row's voice,
        naming the **cross-batch** scope explicitly (D1), default `false`. *(completed)*
  - [x] STAGE 0 (~L51-56): add `ALLOW_SCOPE_COLLISION_FLAG` to the parser-variable list and to the
        "read here and passed into the Skill delegation context" prose. *(completed)*
  - [x] Step 4 Skill invocation `args:` string (~L394): add
        `allow_scope_collision={ALLOW_SCOPE_COLLISION_FLAG}`. *(completed)*
  - [x] Step 4 delegation-context JSON (~L407): add
        `"allow_scope_collision": "{ALLOW_SCOPE_COLLISION_FLAG}"`. *(completed)*
  - [x] `cross_batch` WARNING bullet (~L307-316): add the "consumer-side override check first"
        framing that `--allow-self-modifying`'s bullet already has, naming `--allow-scope-collision`
        as the bypass and stating that `orchestrate-batch-admit.sh` is NEVER passed the flag.
        *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md`: *(completed)*
  - [x] Stage MT-1 delegation-context field list (~L1217): add `allow_scope_collision`
        (default `"false"`) alongside `allow_self_modifying`. *(completed)*
  - [x] Stage MT-3 step 4.5 `file_scope_collision` -> `cross_batch` branch (~L1552-1562): add the
        consumer-side override check, structurally mirroring the `self_modifying` branch's shape at
        L1505-1537 — check `allow_scope_collision == true`; if so dispatch the candidate this cycle
        anyway with a loud, distinct `[orchestrate] BYPASS:` notice; if not, keep today's behavior
        verbatim. *(completed)*
  - [x] Per D1: the `in_batch` branch is explicitly NOT overridable. State this in the bullet so a
        reader does not infer symmetry from the flag name. *(completed)*
  - [x] Per the `--allow-self-modifying` precedent: the bypass notice logs whether or not the gate
        would otherwise have fired, so a transcript reader can always tell the override was active.
        *(completed)*
  - [x] Per the `self_modifying` branch's precedent: on the bypass path, do NOT append to
        `defer_ledger` — a bypassed defer dispatches and must not be ledgered as a defer.
        *(completed)*
- [x] `skills/skill-orchestrate-hard/SKILL.md`: mirror both edits. Its `file_scope_collision`
      bullet is already a real transcription after Phase 2, so the override logic is added there
      directly. Add the delegation-context field if the hard twin has an equivalent field list; if
      it has none (the base skill's L1217 list has no hard-twin counterpart), the override read at
      its `file_scope_collision` bullet is the mirror, matching how its `self_modifying` bullet
      already reads `allow_self_modifying` without a declared field list. Record which applied.
      *(completed: confirmed the hard twin has no delegation-context field-list declaration at
      all — the `self_modifying` bullet reads `allow_self_modifying` inline with no such list —
      so the override read at the `cross_batch` bullet is the mirror, matching that precedent
      exactly)*
- [x] `context/patterns/multi-task-operations.md` Tier 1 auto-sequence section (~L235-257): add a
      bounded cross-reference stating that `--allow-scope-collision` overrides `cross_batch` only
      and never `in_batch`, so Tier 1's bounded second pass remains the sole `in_batch` remedy
      (D1, D4). *(completed)*
- [x] `context/patterns/task-lock.md`: inspect L141's `in_batch` `file_scope_collision` mention and
      the "Four-Tier Conflict Response" section. Edit only if D1's asymmetry is contradicted there;
      otherwise close with a `#### Reasoned Exclusions` record under this phase (D4). *(completed:
      inspected both — neither claims or contradicts D1's asymmetry; no edit needed. See
      `#### Reasoned Exclusions` below.)*

**Timing**: 1.5 hours

**Depends on**: 5, 7

**Verification Tier**: interface

**Scope Hypothesis**: 5 threading sites in `commands/orchestrate.md`, 2 in the base skill, 2 in the
hard twin, 1 cross-reference in `multi-task-operations.md`, and 0-1 in `task-lock.md`. Confirm at
implementation time by running `grep -n 'allow.self.modifying\|allow_self_modifying\|
ALLOW_SELF_MODIFYING' ` across `commands/orchestrate.md` and both SKILL.md files and placing one
mirrored edit per hit that is a threading site (not a prose mention of the other flag's hazard).

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - Options row, STAGE 0, Step 4 args + JSON,
  cross_batch override framing
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - MT-1 field, step 4.5 override
  branch
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - Tier 1 cross-reference
- `agent-system/extensions/core/context/patterns/task-lock.md` - conditional; exclusion record if
  no change needed

**Verification**:

- `grep -rn 'allow_scope_collision\|allow-scope-collision\|ALLOW_SCOPE_COLLISION' ` across the 9
  declared files shows the flag at every intended threading site. *(confirmed: 24 hits across
  the 5 edited files)*
- **Critical**: `grep -rn 'orchestrate-batch-admit.sh' ` across the corpus — every invocation site's
  argument list is unchanged; the flag appears at none of them. *(confirmed: every literal
  `bash .../orchestrate-batch-admit.sh --invocation-count ...` call site inspected — none carries
  the new flag)*
- The bypass branch does not append to `defer_ledger`. *(confirmed: the no-override path is
  explicitly labelled "no-override path only" before the `defer_ledger` append in both base skill
  and hard twin)*
- The `in_batch` branch is unchanged and explicitly documented as non-overridable. *(confirmed)*
- Base skill and hard twin state the same override contract. *(confirmed: both name D1's
  cross-batch-only scope, the BYPASS notice, and the no-defer_ledger-append rule)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `context/patterns/task-lock.md` — no edit made | Inspected L141's `in_batch` `file_scope_collision` mention and the "Four-Tier Conflict Response" section (Tier 1 row, L912-914). Neither claims or implies that `--allow-scope-collision` (or any override) applies to `in_batch`, and neither states a false self-clearing claim requiring correction under D1/WORK 4. D4 explicitly anticipated this outcome as one of two acceptable branches ("If the implementer finds `task-lock.md` genuinely needs no edit, that is closed with a Reasoned Exclusions record"), so no edit is a plan-conformant outcome, not a deviation. | L130-144 (same-session bypass / fresh-vs-stale lock text, mentions `in_batch` only as an example of the pre-check catching in-batch collisions before lock acquire, no override claim); L905-932 (Four-Tier Conflict Response table and reachability notes, Tier 1 row already correctly attributes auto-sequence to `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 — exactly where the new override logic was added in this phase — with no claim of `--allow-scope-collision` applicability) |

---

### Phase 9: Deploy, full verification sweep, and corpus consistency check [COMPLETED WITH EXCLUSIONS]

**Goal**: All source-store edits are committed, deployed, and verified; the running orchestrator's
own definition is updated deliberately rather than incidentally.

**Tasks**:

- [x] Confirm the working tree contains no hand-edited `.claude/**` files:
      `git status --short` shows source-store paths only (plus `specs/`). *(completed: confirmed
      before the snapshot — no `.claude/**` paths in the dirty-tree listing)*
- [x] Run the corpus consistency greps one final time: schema version (Phase 1), `eligible again`
      (Phase 2), `dependencies[] entry on` (Phase 3), `idle_overlap_advisory` (Phases 4-6),
      `allow_scope_collision` (Phases 7-8). *(completed: all five greps re-run against the source
      store, all self-consistent — see Verification below)*
- [x] Twin diff: read the `skill-orchestrate` step 4.5 section and the `skill-orchestrate-hard`
      transcription side by side and confirm every one of this task's changes landed in both.
      *(completed: `cross_batch` bullets compared side by side — override check, D1 cross-batch-only
      scope, no bypass of `in_batch`, no `defer_ledger` append on bypass, self-clearing claim, and
      suggestion clause all present in both)*
- [x] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and the relevant lint
      scripts under `agent-system/extensions/core/scripts/lint/`. *(completed: ran post-deploy —
      see Reasoned Exclusions below for the doc-lint findings and their disposition; agent
      contracts, routing wiring, postflight boundary, contract compliance, and state-writer
      boundary lints all PASS per `verify-deploy.sh` gates 6/7/9/11/12)*
- [x] `bash .claude/scripts/git-snapshot.sh 60` before deploying. *(completed: ran; working tree
      was dirty with pre-existing unrelated modifications plus this session's own Phase 9 marker
      edit — all stashed as `git-snapshot-1787004036`, recoverable, tree left clean)*
- [x] **Redeploy** — `bash .claude/scripts/deploy-headless.sh`. This rewrites `.claude/` from the
      source store, which changes the running orchestrator's own skill and command definitions.
      That is expected for this self-modifying task, but it means the deploy must be the last
      action, after every source edit is committed. *(completed: ran twice — once initially, and
      once more after fixing the `index-entries.json` line_count drift this phase's own doc-lint
      run surfaced for two of this task's edited files)*
- [x] `bash .claude/scripts/verify-deploy.sh` and confirm the deployed
      `.claude/skills/skill-orchestrate/SKILL.md`, `.claude/skills/skill-orchestrate-hard/SKILL.md`,
      `.claude/commands/orchestrate.md`, `.claude/scripts/parse-command-args.sh`, and
      `.claude/scripts/orchestrate-dry-run-report.sh` carry this task's changes. *(completed: ran —
      3 of 23 gates FAIL, matching the documented pre-existing baseline exactly (see Reasoned
      Exclusions); grep-confirmed all five deployed files carry task 60's content)*
- [x] Post-deploy smoke: run `orchestrate-dry-run-report.sh` from the deployed `.claude/scripts/`
      and confirm it completes without error. *(completed: ran against tasks 65/62, completed
      successfully, exit 0)*
- [x] Post-deploy smoke: source the deployed `parse-command-args.sh` and confirm
      `ALLOW_SCOPE_COLLISION_FLAG` parses as in Phase 7. *(completed: confirmed `true`/`false`
      toggling and `FOCUS_PROMPT` stripping match Phase 7's smoke test exactly)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8

**Verification Tier**: full

**Files to modify**:

- None (verification and deploy only; `.claude/**` changes here are the deploy process writing the
  tree by design, which is the sanctioned exception in `source-store-deploy-boundary.md`)

**Verification**:

- `verify-deploy.sh` passes. *(3 of 23 gates FAIL, all pre-existing per the Reasoned Exclusions
  table below — not a pass in the literal sense, but confirmed non-regressive, matching the
  documented clean-baseline count)*
- All lint scripts pass or produce only pre-existing findings. *(confirmed — see Reasoned
  Exclusions)*
- Both post-deploy smokes succeed. *(confirmed)*
- The final grep sweep shows a self-consistent corpus. *(confirmed: schema version — 3/3 hits
  read `v5`; `eligible again` — every hit correctly scoped to `in_batch`/`self_modifying`/
  `session_active`/task-lock-contention, zero `cross_batch`-scoped; `dependencies[] entry on` —
  present at the script source plus both skill twins and the command doc; `idle_overlap_advisory`
  — present in all 5 declared rendering-site files; `allow_scope_collision` — present across all
  5 threading-site files, absent from every `orchestrate-batch-admit.sh` invocation argument list)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh`: doc-lint (`check-extension-docs.sh`) — 5 remaining `line_count`/index findings | Two of the seven original doc-lint findings (`patterns/multi-task-operations.md`, `patterns/orchestrate-batch-results-template.md`) were genuinely caused by this task's own edits growing those files; both were fixed in-phase by correcting their declared `line_count` in `agent-system/extensions/core/index-entries.json` (674→683, 146→163) and confirmed resolved by a second doc-lint run post-fix. The remaining 5 findings (`architecture/context-layers.md`, `patterns/batch-orchestration-guardrails.md`, `patterns/file-footprint-overlap.md`, `project/literature/domain/literature-index.md`, and the `return-meta-artifacts-template.md` index-registration gap) touch zero files this task's `file_scope` or plan declares, and were already present before this task's first edit. | Full `check-extension-docs.sh` re-run after the fix and redeploy shows zero findings against either of this task's two touched patterns files; the 5 remaining findings name only files this task never wrote to. |
| `verify-deploy.sh`: shell test suite (`tests/run-all.sh`) — 3 of 43 suites fail | `test-roadmap-items-producer.sh`'s contamination-guard sub-case and `test-validate-return-meta.sh`'s `--fix`-roundtrip sub-cases (3 assertions) are the failing set. Neither test exercises `parse-command-args.sh`, `orchestrate-dry-run-report.sh`, either `skill-orchestrate*` file, `commands/orchestrate.md`, `orchestrate-batch-results-template.md`, or `multi-task-operations.md` — the full set of files this task edited. | Suite output inspected directly: failures are in roadmap-completion-summary propagation and return-meta `--fix` repair logic, both unrelated subsystems; delegation context's pre-flagged baseline named this exact gate as pre-existing. |
| `verify-deploy.sh`: `specs/state.json` schema validation (`validate-state.sh --deep`) — 1 FAIL | `Unknown entry field: priority (on project_number(s): 53,66)` — an undocumented field on two OTHER tasks' state entries (tasks 53 and 66), not task 60's. This task made no edit to `specs/state.json` beyond the append-only mechanics of `update-phase-status.sh`/`git-commit-scoped.sh`'s own bookkeeping. | `validate-state.sh --deep` output names `project_number(s): 53,66` explicitly — neither is this task; delegation context's pre-flagged baseline named this exact finding as pre-existing (task 53's undocumented priority field). |

---

## Testing & Validation

- [x] `bash -n` passes on both edited shell scripts. *(confirmed: SYNTAX OK for both
      `parse-command-args.sh` and `orchestrate-dry-run-report.sh`)*
- [x] `shellcheck` produces no new findings on `parse-command-args.sh` or
      `orchestrate-dry-run-report.sh` relative to their pre-edit baselines. *(shellcheck is not
      installed in this environment — `bash -n` used as the available substitute, recorded as an
      environment limitation per Phase 6)*
- [x] Parser smoke: `--allow-scope-collision` toggles `ALLOW_SCOPE_COLLISION_FLAG` and is stripped
      from `FOCUS_PROMPT`; `--allow-self-modifying` behavior is unchanged. *(confirmed, both
      pre-deploy in Phase 7 and post-deploy in Phase 9)*
- [x] `orchestrate-dry-run-report.sh` runs to completion pre- and post-deploy. *(pre-deploy:
      verified via standalone jq-logic testing in Phase 6 since the script refuses to run from the
      source-store tree; post-deploy: ran against tasks 65/62 from the deployed `.claude/scripts/`,
      completed successfully)*
- [x] Corpus greps: zero stale schema versions; zero `cross_batch`-scoped "eligible again" claims;
      the Class D suggestion clause present at all three warning sites; `idle_overlap_advisory`
      present at all five rendering sites; `allow_scope_collision` present at every threading site
      and at zero `orchestrate-batch-admit.sh` invocation sites. *(all confirmed in Phase 9's final
      sweep)*
- [x] Twin equivalence: every change to `skill-orchestrate/SKILL.md` has a matching change in
      `skill-orchestrate-hard/SKILL.md`. *(confirmed via the Phase 9 twin diff)*
- [x] `check-extension-docs.sh` and the `scripts/lint/` suite pass. *(doc-lint produces 5 findings,
      all pre-existing and confirmed unrelated to this task's edited files — this task's own two
      edited docs files were fixed in-phase; the individual lint scripts under `scripts/lint/`
      (agent contracts, routing wiring, postflight boundary, contract compliance, state-writer
      boundary) all PASS per `verify-deploy.sh`'s gates 6/7/9/11/12 — see Reasoned Exclusions)*
- [x] `verify-deploy.sh` passes after redeploy. *(3 of 23 gates FAIL, matching the documented
      pre-existing clean-baseline count exactly — see Reasoned Exclusions)*

## Artifacts & Outputs

- `specs/060_thread_evidence_gated_verdict_through_admission_consumers/plans/01_thread-evidence-gated-verdict.md` (this file)
- `specs/060_thread_evidence_gated_verdict_through_admission_consumers/summaries/01_thread-evidence-gated-verdict-summary.md` (produced at implement time)
- Modified source-store files (9 declared, 8 expected to change; `orchestrate-predispatch-review.sh`
  is read-only for this task):
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  - `agent-system/extensions/core/commands/orchestrate.md`
  - `agent-system/extensions/core/scripts/parse-command-args.sh`
  - `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh`
  - `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
  - `agent-system/extensions/core/context/patterns/multi-task-operations.md`
  - `agent-system/extensions/core/context/patterns/task-lock.md` (conditional — D4)
- Regenerated `.claude/` deploy tree (Phase 9, by the deploy process)

## Rollback/Contingency

- Every phase ends at a committed green state, so rollback is `git revert` of the offending phase
  commit followed by a redeploy. No phase leaves a partially-threaded flag or a half-edited twin.
- If a phase fails mid-edit, the twin-pairing rule means the failure mode to check first is one twin
  edited and the other not. Resolve by completing the pair, not by reverting the completed half.
- If the Phase 9 redeploy produces a broken orchestrator, restore from the
  `git-snapshot.sh 60` snapshot taken immediately before the deploy, then redeploy from the
  restored source store.
- If `--allow-scope-collision` proves to have an unforeseen interaction, it is per-invocation and
  default-off: reverting Phases 7-8 removes it entirely with no persistent state to unwind, and
  leaves Phases 1-6 (all rendering and correctness fixes) intact and independently valuable.
