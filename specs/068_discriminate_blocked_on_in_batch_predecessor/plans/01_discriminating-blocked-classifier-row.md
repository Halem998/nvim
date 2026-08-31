# Implementation Plan: Task #68

- **Task**: 68 - Make the /orchestrate blocked verdict discriminating: dispatch a task blocked on an in-batch predecessor instead of skipping it forever
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/068_discriminate_blocked_on_in_batch_predecessor/reports/01_discriminate-blocked-classifier-row.md
- **Artifacts**: plans/01_discriminating-blocked-classifier-row.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The multi-task `/orchestrate` classifier's `blocked` arm emits `group: "skip"` for engine `mt`
unconditionally, ignoring everything the Stage MT-3 dependency-graph eligibility gate has already
established about ordering. A task blocked on an in-batch predecessor therefore becomes eligible
each cycle, is re-classified by its stale literal `status` string, and is skipped again — forever,
until `MAX_CYCLES_MT` is spent. This plan makes that arm DISCRIMINATING using signals the
classifier already has in memory (the fully slurped `active_projects` array, plus a scope-widened
read of the candidate's own `.orchestrator-handoff.json`), and then propagates the changed premise
through every co-maintained table, justification paragraph, fixture, and architecture doc that
currently asserts "blocked always skips". Definition of done: a dependency chain submitted as one
batch runs end-to-end in a single invocation with no hand-edited statuses, every co-maintained
copy of the verdict table agrees under grep, and new fixtures for both engines fail against the
pre-fix classifier.

### Research Integration

The research report settles all four Design Direction questions and this plan adopts its findings
in full:

- **Discriminator** (report Recommendation 1, Decisions 1/2/3): the discharge test is a
  conjunction of three conditions — `dependencies[]` non-empty, EVERY listed dependency's own
  `status` in `state.json` exactly `"completed"`, and the candidate's handoff `blockers[]` empty
  or handoff absent. It is resolved by a second `select(.project_number == $dep)` against the
  already-slurped `$all`, NOT by candidate-list membership. The report shows candidate-list
  membership would read FALSE in exactly the reproduction scenario (step 3 drops the terminal
  predecessor from `eligible_tasks` before the successor is first classified), i.e. it would
  reproduce the very defect being fixed. This is the single most important design fact in the
  report and the implementer must not substitute the simpler-looking reading.
- **Routing on discharge**: re-run the candidate's `previous_status` through the same
  not_started / researched / planned-or-implementing / researching / planning routing the script
  already applies to a live status. A missing `previous_status` is `needs_human`, never a guess.
- **No rewrite component** (report Decision 4, confirmed by direct read of `skill_validate_input`
  and `update-task-status.sh`'s preflight write): the verdict alone suffices. The stale `blocked`
  string is overwritten by the dispatched skill's own `skill_preflight_update`, the identical
  mechanism the shipped `researching`/`planning` convergence already relies on. `orchestrator-postflight.sh`
  and `reconcile-task-status.sh` get no new write logic.
- **`/spawn` unchanged** (report Decision 5): `status: "blocked"` is the trigger that tells the
  classifier to run the discrimination logic at all; `dependencies[]` alone cannot distinguish
  "ordering only" from "needs a human".
- **Prior art narrowed, not overturned** (report's Decisions section): the archived
  `orchestrate_eligibility_not_status_gated` report's Decision 3 ("blocked and unknown rows: leave
  unchanged... no argument surfaced") is NARROWED — the `unknown` row stays untouched, and the
  `blocked` row stays unconditional for the non-discharged case. This narrowing must be stated in
  prose in the classifier header, not left implicit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but was not passed as `roadmap_path` in this delegation context, and a
grep of it surfaces no orchestration/classifier item this work advances. No roadmap phases are
added and ROADMAP.md is not modified.

## Goals & Non-Goals

**Goals**:
- Replace the unconditional `blocked` arm in `scripts/orchestrate-triage-classify.sh` with a
  five-branch discriminating arm (empty deps / dependency outstanding / dependency non-completed-
  terminal / handoff blockers present / discharged).
- Widen the existing per-candidate handoff read from `status == "partial"` to also cover
  `status == "blocked"`, reusing the existing `blocker_count` / `age_min` extraction verbatim.
- Converge both engines on the DISCHARGED case (route via `previous_status`); preserve the
  documented `skip` (mt) / `needs_human` (single) divergence for the NON-discharged case.
- Bring every co-maintained assertion into agreement in the same change: the classifier's own
  header verdict table, its justification prose, its verdict-schema field docs, Stage MT-4's
  phase-grouping table and justification, single-task Stage 4's `blocked` handler and its
  `partial` cross-reference sentence, the hard-mode skill's `blocked` handler, the state-machine
  doc, and the guardrails Gate Catalogue.
- Rewrite `fixture_blocked` and its "DOCUMENTED DIVERGENCE ... do NOT fix this" instruction
  comment so the suite stops asserting a claim the code no longer makes, and add fixtures for all
  five discriminated sub-cases across both engines with captured pre-fix RED evidence.
- Ensure the dry-run report predicts the new behavior.

**Non-Goals**:
- The `unknown` classifier row. Research surfaced no argument for it; the prior task's Decision 3
  stands unnarrowed for that row.
- Any change to `skills/skill-spawn/SKILL.md`. It is in `file_scope` but research Decision 5
  concludes its writes are exactly the signals the fix consumes. No edit.
- Any change to `scripts/orchestrator-postflight.sh` or `scripts/reconcile-task-status.sh`. Both
  are in `file_scope` but research Decision 4 concludes no rewrite component is needed. No edit.
- Any change to `scripts/orchestrate-batch-admit.sh`. In `file_scope` because the task is
  self-modifying (it is registered in `orchestrator-critical-paths.json`), not because it needs
  editing. No edit.
- Stage MT-3 step 3's eligibility gate and its failed-predecessor handling. Research confirms the
  gate already discriminates correctly and already routes a failed predecessor's dependents to
  `failed_tasks`; touching it would risk the acceptance criterion it already satisfies.
- Editing the deployed `.claude/**` tree. All edits land in `agent-system/extensions/core/**`;
  verification is by deploy, never by editing the deploy tree.

**Explicit scope decision (research Recommendation 6 / Risks)**: the pre-existing, currently
missing "Unmet predecessor (dependency-graph eligibility)" row in the Gate Catalogue IS folded
into Phase 6. Rationale: same file, same table, same edit session, near-zero marginal cost, and
leaving it out is precisely how the `blocked` row itself came to be silently missing. This is a
recorded plan decision, not an incidental byproduct.

**Explicit scope decision (research Recommendation 7 / Risks)**: the dry-run report DOES get the
classifier's richer `.reason` string threaded through for `blocked` candidates (Phase 7). The
acceptance criteria only require the dry-run to predict the new behavior, but a report that says
"handoff-triage skip (status blocked)" for a task the live path would dispatch, and for a task the
live path would also skip, is indistinguishable between the two — which is the diagnostic gap this
whole task exists to close.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer uses candidate-list membership as the discriminator instead of state.json dependency lookup | H | M | Phase 2 tasks name the mechanism explicitly and Phase 3 fixture (c) is constructed so the dependency is NOT among the classifier's arguments — a membership-based implementation fails it |
| Vacuous-truth discharge on empty `dependencies[]` (`all` over an empty list is true) | H | M | Empty-deps is its own FIRST branch with its own reason string, evaluated before the all-completed check; Phase 3 fixture (e) locks it in |
| `abandoned`/`expanded` predecessor silently promotes a dependent whose precondition can never be met | H | M | Discharge requires literal `"completed"`, never `is_terminal`; non-completed-terminal is its own loud `needs_human` branch (both engines); Phase 3 fixture (d) locks it in |
| Mechanism lands while prose in another file still asserts "blocked always skips" | M | H | Phases 4-6 are mandatory, and Phase 8's grep sweep is the gate that fails the task if any stale assertion survives |
| New fixtures pass against the pre-fix classifier, proving nothing | M | M | Phase 1 captures RED evidence against a `git show HEAD:` scratch copy BEFORE the arms are added, per `context/standards/shell-script-testing.md` mutation-check discipline |
| Classifier file left self-contradicting between commits (mechanism changed, header table not yet) | M | M | Phase 2 is declared `Commit Mode: atomic-batch` — the script's mechanism, header table, justification, and schema docs are one objective |
| `handoff_state` / `blocker_count` semantics silently change for downstream consumers | M | M | Phase 2 updates the verdict-schema field docs in the same objective; Phase 7 verifies the dry-run consumer against the widened value domain |
| Task-number references leak into an edited deliverable outside `specs/**` | M | M | Every doc/script phase states the constraint; Phase 8 runs the repo-wide task-reference lint |
| Editing `.claude/**` instead of the source store | H | L | Every phase's file list is `agent-system/extensions/core/**`-rooted; Phase 8 verifies via deploy, not by editing the deploy tree |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5, 6, 7 | 2 |
| 4 | 8 | 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-measure anchors and capture pre-fix RED evidence [COMPLETED]

**Goal**: Establish a verified green baseline, re-derive every line anchor the research report and
task description cite (both explicitly warn they may have drifted), and capture the mutation-check
RED output for the fixtures Phase 3 will add — all before any production file changes.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`
      and record the green baseline (PASSED/FAILED counts). *(completed: 26 passed, 0 failed)*
- [x] Re-derive current line anchors by grep, not by trusting the report: the `elif $status ==
      "blocked"` arm, the header verdict-table `| blocked |` row, the justification paragraph
      beginning "`blocked` is the one row that still diverges", the `handoff_state` schema field
      description, the `[ "$row_status" = "partial" ] || continue` handoff-read gate, Stage MT-4's
      phase-grouping table row `| \`blocked\`, unknown | skip | — |` and the paragraph beginning
      "`blocked` folding into `skip` here", single-task Stage 4's `#### State: \`blocked\`` handler
      and its "Why this handler stays engine-unconditional" note, the `partial` handler's "both
      engines now agree on every row here except `blocked`" sentence, the hard-mode skill's
      `#### State: \`blocked\`` handler, `orchestrate-state-machine.md`'s `blocked` state-table
      row, and the Gate Catalogue table. Record the measured anchors in the commit body.
      *(completed: anchors re-measured, see commit body of Phase 2)*
- [x] Copy the pre-fix classifier to a scratch location via `git show HEAD:agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`
      and run the ten planned Phase 3 fixture cases against it; capture the RED output verbatim
      for the Phase 3 commit body. Confirm every planned fixture that asserts NEW behavior fails
      pre-fix; a fixture that passes pre-fix is not a regression guard and must be redesigned.
      *(completed: 6 sub-cases (12 assertions, not 10 — deviation: a 6th "missing
      previous_status" sub-case was added beyond the plan's "five discriminated sub-cases" count,
      per the Testing & Validation section's explicit requirement) run against HEAD copy; see
      Phase 2/3 commit bodies for verbatim RED output)*
- [x] Confirm the reproduction premise by direct read rather than assumption: `state.json` entries
      written by `/spawn` carry both `previous_status` and a `dependencies[]` edge (grep
      `skills/skill-spawn/SKILL.md` for the two `state-write.sh` call sites).
      *(completed: confirmed at SKILL.md lines 100-119 (previous_status write) and 415-427
      (dependencies[] write))*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that all thirteen anchors listed above exist and are
each in exactly one place. Confirm by running each grep and recording the hit count; a zero-hit
or multi-hit grep means the anchor drifted or was duplicated and the affected downstream phase's
file list must be widened before proceeding.

**Files to modify**:
- None (measurement and evidence capture only; evidence lands in the Phase 3 commit body).

**Verification**:
- Existing suite reports FAILED == 0 pre-change.
- Every anchor grep returns exactly one hit, recorded.
- RED evidence captured for every new-behavior fixture.

---

### Phase 2: Discriminating classifier arm, widened handoff read, and in-file documentation [COMPLETED]

**Goal**: Make `scripts/orchestrate-triage-classify.sh` discriminate the `blocked` row, and bring
its header verdict table, justification prose, and verdict-schema field docs into agreement in the
same objective so the file is never left self-contradicting.

**Tasks**:
- [x] Widen the per-candidate handoff-read loop's gate from `[ "$row_status" = "partial" ] ||
      continue` to also admit `blocked`, reusing the existing `blocker_count`, `continuation_ok`,
      and `age_min` extraction unchanged. Update the loop's Context-Flatness comment to name both
      statuses. Read nothing but `.orchestrator-handoff.json` — never a plan, report, or summary.
- [x] Replace the `elif $status == "blocked"` arm with the discriminating form. Resolve
      `$deps` as `($all[] | select(.project_number == $c) | .dependencies // [])` and `$prev` as
      `($all[] | select(.project_number == $c) | .previous_status // null)`. Branch order is
      load-bearing:
      1. `($deps | length) == 0` -> `skip` (mt) / `needs_human` (single); reason: no tracked
         dependency, likely externally or manually blocked. MUST precede the all-completed check
         so an empty list never discharges by vacuous truth.
      2. any dependency whose own `status` is `abandoned` or `expanded` -> `needs_human` (BOTH
         engines); reason names the dependency and its non-completed terminal status as a loud
         warning. Discharge requires literal `"completed"`, never the broader `is_terminal`.
      3. not every dependency's own `status` is exactly `"completed"` -> `skip` (mt) /
         `needs_human` (single); reason names which dependency numbers remain outstanding.
      4. handoff `blocker_count > 0` -> `needs_human` (BOTH engines); reason cites the count. This
         reuses the `partial` row's existing continuation > blockers > neither precedence shape
         applied to `blocked`, rather than introducing a new shape.
      5. `$prev == null` -> `needs_human` (BOTH engines); reason: blocked with satisfied
         dependencies but no `previous_status`, cannot determine discharge phase. Never guess.
      6. otherwise (DISCHARGED) -> route `$prev` through the SAME not_started / researched /
         planned-or-implementing / researching / planning mapping the script already applies to a
         live status, emitting the corresponding group for BOTH engines. A `$prev` that is itself
         unrecognized falls to `needs_human` with a reason naming the unrecognized value.
  - Mechanism constraint, restated from the research report because the wrong reading is the
    tempting one: resolve each dependency's status from the already-slurped `$all` array, NOT from
    the candidate list `$candidates`. A dependency that has just completed is no longer in
    `eligible_tasks`, so it is absent from `$@` in exactly the reproduction cycle.
- [x] Emit real `handoff_state` and `blocker_count` values for `blocked` candidates (`absent` /
      `blockers` / `empty`) instead of the current hardcoded `"not_applicable"` / `0`. Keep the
      `$schema` value `orchestrate-triage-v1` — the field domain widens, no field is added or
      removed, and no field's type changes.
- [x] Update the verdict-schema field docs in the header: `handoff_state`'s `"not_applicable"`
      description changes from "status is not partial" to "status is neither partial nor blocked",
      and `blocker_count`'s parenthetical widens correspondingly.
- [x] Rewrite the header verdict table's `| blocked | skip | needs_human |` row into the
      discriminated rows: `blocked, discharged` -> `previous_status`-routed group for both
      engines; `blocked, dependency outstanding or empty deps` -> `skip` / `needs_human`;
      `blocked, dependency abandoned/expanded` -> `needs_human` / `needs_human`;
      `blocked, handoff blockers present` -> `needs_human` / `needs_human`.
- [x] Rewrite the justification paragraph so it no longer asserts unconditional divergence. It
      must: state the new discriminated behavior; NARROW rather than delete the "two independently
      corroborating handlers = design" framing (it remains true for the non-discharged case);
      apply the file's own audit discriminator honestly to the discharged case and record that
      both engines now converge there because a solo invocation escalating a factually-resolved
      block is not a deliberate design; and note that the prior work's Decision 3 is narrowed, not
      overturned, with the `unknown` row untouched.
- [x] Do NOT add any write call. The file's read-only contract and its enumerated forbidden calls
      (`task-lock.sh acquire`, `update-task-status.sh`, `generate-todo.sh`, `skill-base.sh` write
      functions, `reconcile-task-status.sh` without `--dry-run`, Agent/Skill dispatch) stand
      unchanged.
- [x] Cite no task numbers in the file. Reference filenames and section headings only.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the change is confined to one file and six branch arms.
Confirm at implementation time by running `git diff --stat` (expect exactly one file) and by
re-reading the emitted arm count; if the discharged branch requires a helper `def` shared with
another arm, the file list is still one file but note the shared surface in the commit body.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - handoff-read gate
  widening, discriminating `blocked` jq arm, `handoff_state`/`blocker_count` emission for blocked,
  header verdict table, justification prose, verdict-schema field docs.

**Verification**:
- `bash -n` clean; the script runs against the live `specs/state.json` and emits well-formed
  NDJSON for a mixed candidate list.
- The existing test suite still reports FAILED == 0 for every non-`blocked` row (the two
  `fixture_blocked` assertions are expected to fail here and are repaired in Phase 3; note that
  expectation explicitly in the commit body rather than letting it read as an unexplained
  regression).
- Manual spot-check with a synthetic state fixture: a `blocked` candidate whose sole dependency is
  `completed` and which has `previous_status: "planned"` classifies to `implement` for both
  engines.

---

### Phase 3: Rewrite the blocked fixtures and their instruction comment [COMPLETED]

**Goal**: Replace the two `fixture_blocked` assertions and the "DOCUMENTED DIVERGENCE ... do NOT
'fix' this" comment block with fixtures covering all five discriminated sub-cases across both
engines, each demonstrated RED against the pre-fix classifier.

**Tasks**:
- [x] Delete the current `check_fixture "single" 111 ... needs_human` / `check_fixture "mt" 111
      ... skip` pair and the three-line comment above them that instructs the reader not to fix
      the divergence. The comment must be rewritten with the fixtures — leaving it would preserve
      a claim the code no longer makes.
- [x] Add a new state fixture block with the entries needed for the five sub-cases: a discharged
      candidate (non-empty `dependencies[]`, dependency present with `status: "completed"`,
      `previous_status` set, no handoff file); a discharged candidate WITH a handoff carrying
      non-empty `blockers[]`; a non-discharged candidate whose dependency is still in-progress; a
      candidate whose dependency is `abandoned`; and a candidate with empty `dependencies[]`.
      Include a discharged candidate whose `previous_status` is absent if the sixth branch is to
      be covered.
- [x] Construct the discharged fixture so the dependency's task number is NOT passed as a
      classifier argument — this is the fixture that distinguishes the correct state.json-lookup
      mechanism from the incorrect candidate-list-membership mechanism, and it must fail if the
      wrong one was implemented.
- [x] Assert both `group` AND `handoff_state` for every new case (the existing `check_fixture`
      helper already takes both), so the widened `handoff_state` domain for `blocked` is locked in
      rather than left untested.
- [x] Rewrite the suite's header comment where it enumerates which rows the suite covers, so it
      names the discriminated `blocked` sub-cases instead of the retired single divergent row.
- [x] Record the Phase 1 RED evidence in this phase's commit body, per
      `context/standards/shell-script-testing.md`.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts ten new fixture assertions (five sub-cases x two engines).
Confirm by counting `check_fixture` invocations added in the diff; if a sub-case turns out to be
engine-identical and one assertion suffices, record the reduced count and its reason rather than
padding to ten. *(deviation: actual count is 12 assertions across SIX sub-cases, not five/ten --
the Testing & Validation section explicitly requires a sixth "discharged but previous_status
missing" sub-case beyond this Scope Hypothesis's five-sub-case estimate; recorded here rather
than silently padding or dropping the required case)*

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - fixture state
  block, ten discriminated assertions, rewritten instruction comment, updated header scope note.

**Verification**:
- Suite reports FAILED == 0 post-fix.
- Every new-behavior assertion confirmed FAILED against the `git show HEAD:` pre-fix copy captured
  in Phase 1 — a suite that passes unchanged before and after proves nothing.

---

### Phase 4: skill-orchestrate co-maintenance (three sites) [COMPLETED]

**Goal**: Bring `skills/skill-orchestrate/SKILL.md` into agreement with the classifier at all
three sites the classifier's own header names as MUST-change-together.

**Tasks**:
- [x] Stage MT-4 phase-grouping table: split the `| \`blocked\`, unknown | skip | — |` row so
      `unknown` keeps `skip` unchanged and `blocked` becomes the discriminated rows matching the
      classifier's header table byte-for-byte in substance (discharged -> the group
      `previous_status` names; non-discharged -> `skip`; abandoned-dependency or handoff-blockers
      -> `failed_tasks` (mark blocked), consistent with this stage's existing `needs_human` ->
      `failed_tasks` filter).
- [x] Rewrite the paragraph beginning "`blocked` folding into `skip` here is the one row that still
      diverges" so it states the narrowed divergence: the two engines now CONVERGE on the
      discharged case and diverge only on the non-discharged case. Do not delete the Decision 1
      citation — narrow it and say so.
- [x] Single-task Stage 4 `#### State: \`blocked\`` handler: add the discriminating read before
      escalation, delegating to `scripts/orchestrate-triage-classify.sh single $task_number` in
      the manner the adjacent `partial` handler's existing "Cross-reference" precedent already
      establishes. A discharged verdict routes to the phase its group names; every non-discharged
      verdict falls through to the existing Stage 6 blocker escalation unchanged.
- [x] Rewrite the handler's "Why this handler stays engine-unconditional (Decision 1, intentional
      divergence from `mt`)" note to match: it stays engine-unconditional for the NON-discharged
      case only.
- [x] Update the `partial` handler's sentence "both engines now agree on every row here except
      `blocked`" — the exception is now narrower and the sentence as written is false after this
      change.
- [x] Leave Stage MT-3 step 3's eligibility rules and its failed-predecessor handling untouched.
- [x] Cite no task numbers.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly five edit sites in one file. Confirm by grepping
the file for `blocked` after the edit and reading every hit; any hit still asserting unconditional
skip means a sixth site exists and must be handled here, not deferred to Phase 8. *(deviation:
altered — the post-edit grep sweep found a sixth site, Stage 6 Blocker Escalation's opening
"Called when" sentence, asserting the same stale unconditional premise; narrowed in this phase
per this Scope Hypothesis's own instruction)*

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 grouping table and
  its justification paragraph, Stage 4 `blocked` handler and its engine-unconditional note, and
  the `partial` handler's cross-reference sentence.

**Verification**:
- Diff read-through confirms every changed hunk is prose or a markdown table (no executable region
  crossed).
- `grep -n "blocked" skills/skill-orchestrate/SKILL.md` returns no surviving assertion that the
  mt engine skips `blocked` unconditionally.

---

### Phase 5: Hard-mode skill and state-machine doc [COMPLETED]

**Goal**: Apply the same single-task-scope change to the hard-mode engine's own `blocked` handler,
record the determination about whether its Multi-Task Mode pointer genuinely inherits, and sweep
the architecture doc for the now-false premise.

**Tasks**:
- [x] `skills/skill-orchestrate-hard/SKILL.md`: update its compressed `#### State: \`blocked\``
      handler ("Read blockers from state.json. Invoke blocker escalation (Stage 6)") with the same
      discriminating read Phase 4 gives the base skill's single-task handler, so the two engines
      do not drift.
- [x] Record explicitly, in that file, the determination that its Multi-Task Mode "Same as base"
      pointer needs NO MT-specific edit here: research confirms it carries no phase-grouping table
      of its own, so the base skill's Stage MT-4 table is the sole MT authority. State this as a
      checked determination rather than leaving a silent absence, given that file's own stated
      concern that bare pointers demonstrably fail to carry mechanisms forward.
- [x] `docs/architecture/orchestrate-state-machine.md`: update the `blocked` state-table row so it
      reflects the discriminating handler (discharged -> dispatch the phase `previous_status`
      names; otherwise `dispatch_blocker_escalation()` unchanged).
- [x] Sweep that doc's surrounding prose (the failed-predecessor paragraph and the "No eligible
      tasks | partial | Deadlock or all blocked" exit row) and confirm neither asserts the changed
      premise; leave both unchanged if they do not, and record that as a checked result.
- [x] Cite no task numbers.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - single-task `blocked`
  handler and an explicit MT-inheritance determination note.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - `blocked` state
  row; adjacent prose confirmed unchanged.

**Verification**:
- Diff read-through confirms prose/table-only hunks.
- `grep -n "blocked" docs/architecture/orchestrate-state-machine.md` shows no surviving
  "always escalates" or "always skips" assertion.

---

### Phase 6: Gate Catalogue rows in the guardrails pattern [COMPLETED]

**Goal**: Give the `blocked` classifier verdict rows in the Gate Catalogue, and fold in the
adjacent pre-existing "Unmet predecessor" omission per the recorded scope decision above.

**Tasks**:
- [x] Add a row: `blocked` (discharged — dependency `completed`, no handoff blockers) ->
      ORDERING CONSTRAINT. Why: self-clears as soon as the classifier next runs after the
      predecessor's `status` write lands; the dependent is dispatched to the phase its
      `previous_status` names.
- [x] Add a row: `blocked` (not discharged — dependency outstanding, dependency abandoned/expanded,
      empty `dependencies[]`, or handoff blockers present) -> whatever the non-discharged
      classification already is, surfaced loudly with a named reason. Note the documented,
      independently-implemented single/mt divergence for this sub-case explicitly so the row is
      not later read as an accidental exclusion.
- [x] Add the folded-in row: "Unmet predecessor (dependency-graph eligibility)" -> ORDERING
      CONSTRAINT, matching how the Blocking-vs-Advisory table above already classifies it, so the
      two tables stop disagreeing by omission.
- [x] Preserve the note immediately below the table that `defer_reason` values are echoed verbatim
      from what `orchestrate-batch-admit.sh` actually emits — the new rows are classifier verdicts,
      not admit verdicts, so their `defer_reason` cell must read `n/a` with the same parenthetical
      form the existing non-admit rows (held lock, `deploy_checkpoint`) already use. A catalogue
      naming a `defer_reason` the script does not emit would introduce exactly the false premise
      this file exists to prevent.
- [x] Cite no task numbers.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts three new table rows and zero changes to existing rows.
Confirm by diff; any edit to an existing row means the folded-in scope decision has grown beyond
what was recorded and must be re-justified in the commit body.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - three new
  Gate Catalogue rows.

**Verification**:
- Diff read-through confirms markdown-table-only hunks.
- Every new row's `defer_reason` cell follows the existing non-admit-verdict convention.

---

### Phase 7: Dry-run report predicts the new behavior [COMPLETED]

**Goal**: Confirm the dry-run's independent wave and out-of-batch-predecessor computations still
compose correctly with the discriminated verdicts, and thread the classifier's richer `reason`
through for `blocked` candidates per the recorded scope decision.

**Tasks**:
- [x] Trace the report's classifier-consumption path and confirm by execution, not by reading,
      that a `blocked` candidate now classifying to `implement`/`plan`/`research` composes into the
      Admitted set rather than being excluded — the exclusion arms key on
      `skip`/`needs_human`/`terminal`/`exit_partial`, so a discharged verdict should fall through
      to admission with no code change.
- [x] Thread the classifier's `.reason` field into `t_skip_reason` for candidates whose status is
      `blocked`, replacing the templated "handoff-triage skip (status blocked)" for that case only.
      Keep the existing templated form as the fallback for every other status so no other row's
      output changes.
- [x] Confirm the existing static-vs-cycling divergence note remains accurate after the change and
      needs no rewording; record that as a checked result rather than silently leaving it.
- [x] Verify the independent out-of-batch-predecessor exclusion (which keys on `dependencies[]`
      plus the dependency's own status, not the candidate's status) still fires for the case it
      owns and does not double-exclude a discharged candidate.
- [x] Cite no task numbers.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - `blocked`-case skip-reason
  threading; confirmed-unchanged notes recorded in the commit body.

**Verification**:
- `bash -n` clean.
- Run the dry-run against a synthetic state fixture containing a discharged chain and confirm the
  successor appears in Admitted with its wave number, and that a non-discharged successor appears
  in the skipped set with the classifier's specific per-dependency reason rather than the generic
  template.

---

### Phase 8: Cross-file agreement, deploy verification, and acceptance walkthrough [NOT STARTED]

**Goal**: Prove by grep that no co-maintained copy still asserts the changed premise, prove the
change works from the deployed tree rather than the source store, and walk the acceptance criteria
one by one.

**Tasks**:
- [ ] Grep the whole source store for surviving assertions of the old premise: `grep -rn "blocked"
      agent-system/extensions/core/ | grep -i "skip\|diverg\|needs_human\|do NOT"` and read every
      hit. Any hit asserting unconditional mt-skip is a defect this phase must fix, not defer.
- [ ] Verify all co-maintained verdict tables agree: the classifier header table, Stage MT-4's
      grouping table, and the state-machine doc's state row must name the same groups for the same
      sub-cases.
- [ ] Run the repo's task-reference lint (`scripts/check-task-references.sh` or equivalent) and
      confirm zero task-number references were introduced outside `specs/**`.
- [ ] Run the full classifier test suite plus any adjacent orchestrate suites; confirm FAILED == 0.
- [ ] Deploy the source store to `.claude/**` by the normal deploy path and re-run the classifier
      from the deployed location to confirm `deploy-root-guard.sh` and `PROJECT_ROOT` resolution
      still hold. Do not edit the deploy tree.
- [ ] Walk each acceptance criterion explicitly and record the evidence for each: (1) a chain
      batch runs end-to-end with no hand-editing — demonstrate via a synthetic state fixture
      showing each successor classifying to a real dispatch group once its predecessor is
      `completed`; (2) an out-of-batch or unresolved block still skips loudly or escalates, and
      which one is recorded; (3) a failed predecessor still lands its dependents in `failed_tasks`
      — confirm Stage MT-3 step 3's untouched path; (4) all verdict tables agree by grep; (5) new
      fixtures fail pre-fix; (6) the dry-run predicts the new behavior.
- [ ] If any file outside the current `file_scope` turned out to need editing, widen `file_scope`
      deliberately via `state-write.sh`, naming each file exactly — no bare directory roots, no
      duplicate entries.

**Timing**: 1 hour

**Depends on**: 3, 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that exactly seven files were modified across the task
(classifier, its test suite, dry-run report, base skill, hard-mode skill, guardrails pattern,
state-machine doc) and that the four `file_scope` entries listed as Non-Goals were not touched.
Confirm with `git diff --name-only`; any deviation must be reconciled with the Non-Goals section
and the `file_scope` widened deliberately.

**Files to modify**:
- None expected; any file this phase must repair is a Phase 4-7 escapee and should be noted as
  such in the commit body.
- `specs/state.json` only if `file_scope` genuinely needs widening.

**Verification**:
- Full gate set: `bash -n` on every changed script, the full classifier test suite green, the
  task-reference lint clean, the deploy completed and the deployed classifier executing correctly.
- Every acceptance criterion has recorded evidence.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` reports
      FAILED == 0.
- [ ] Every new `blocked` fixture confirmed RED against the pre-fix classifier (mutation-check
      discipline, evidence in the Phase 3 commit body).
- [ ] Discharged case: dependency `completed`, `previous_status` set, no handoff -> routes to the
      group `previous_status` names, for BOTH engines.
- [ ] Discharged-with-blockers case: handoff `blockers[]` non-empty -> `needs_human`, BOTH engines.
- [ ] Non-discharged case: dependency still in-progress -> `skip` (mt) / `needs_human` (single),
      unchanged from today.
- [ ] Abandoned-dependency case: -> `needs_human` with a loud named reason, BOTH engines.
- [ ] Empty `dependencies[]` case: -> `skip` (mt) / `needs_human` (single), never vacuous discharge.
- [ ] Missing `previous_status` on an otherwise-discharged candidate -> `needs_human`, no guessing.
- [ ] The discharged fixture's dependency is NOT in the classifier's argument list and the case
      still passes (proves the state.json-lookup mechanism, not candidate-list membership).
- [ ] `bash -n` clean on the classifier and the dry-run report.
- [ ] Dry-run against a synthetic discharged chain admits the successor and prints its wave.
- [ ] Repo-wide grep shows no surviving "blocked always skips" assertion in the source store.
- [ ] Task-reference lint clean outside `specs/**`.
- [ ] Deploy completed and the deployed classifier runs correctly from `.claude/scripts/`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (discriminating arm,
  widened handoff read, rewritten header table / justification / schema docs)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (rewritten
  blocked fixtures and instruction comment)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (reason threading)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (five co-maintained sites)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (handler + inheritance
  determination)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (three Gate
  Catalogue rows)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (state row)
- `specs/068_discriminate_blocked_on_in_batch_predecessor/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is an independent commit, so rollback is per-phase `git revert`. The mechanism (Phase
2) and its fixtures (Phase 3) are the only pair that must revert together — reverting Phase 2
alone would leave a suite asserting behavior the code no longer has, and reverting Phase 3 alone
would leave the mechanism unguarded. The documentation phases (4-7) are independently revertible,
though reverting any one of them reintroduces a false premise in that file and should be paired
with a corrective note rather than left silent. If the discriminating arm proves unsound in live
use, the minimal safe fallback is to restore the unconditional `elif $status == "blocked"` arm
while KEEPING the widened handoff read and the new fixtures (marked pending), so the next attempt
starts from measured ground rather than from scratch.
