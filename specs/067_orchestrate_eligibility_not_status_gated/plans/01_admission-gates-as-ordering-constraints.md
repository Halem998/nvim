# Implementation Plan: Task #67

- **Task**: 67 - Make /orchestrate admission gates ordering constraints, not exclusions: unstrand in-flight tasks and end solo-only self-modifying dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: `specs/067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md`
- **Artifacts**: plans/01_admission-gates-as-ordering-constraints.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two coupled defects in `/orchestrate`'s multi-task admission predicate turn admission gates into
permanent exclusions rather than ordering constraints. Work Stream A removes the
`{researching, planning}` eligibility exclusion so tasks stranded by a dead prior session are no
longer skipped forever, replacing a status-string proxy with the lock/`dependencies[]`/file_scope
gates that already exist downstream. Work Stream B gives the self-modification gate a
deterministic designated-candidate tie-breaker (ending the N-self-modifying-tasks deadlock and the
"run it solo" operator instruction) and makes it phase-aware, so a research or plan dispatch is
not deferred merely because a task's implementation footprint names a critical path. Definition of
done: both mechanisms land, every co-maintained copy and every safety argument the change
falsifies is corrected in the same phase as the mechanism, the classifier suite gains fixtures that
demonstrably fail against the pre-fix classifier, and a deploy + `verify-deploy.sh` passes.

### Research Integration

The plan is built directly on the research report's decisions and does not re-litigate them:

- **Work Stream B**: adopt Direction 1 (designated-candidate tie-breaker, lowest task number,
  implemented inside `orchestrate-batch-admit.sh`'s existing inline `jq` — `$cands` and the sourced
  `self_mod_match` def are already in scope) and Direction 2 (phase-aware gating via a new
  `--phase-map` argument, with the classifier call relocated earlier in Stage MT-3 step 4.5 and its
  output reused, not re-invoked, by Stage MT-4). **Reject Direction 3** outright — dispatch is
  cycle-synchronous and every task's scoped commit lands before the redeploy checkpoint runs, so
  the hazard it targets is not a real state; record it as a closed question rather than a follow-up
  task.
- **Convergence blast radius is narrow.** The "structurally impossible" safety claims at
  `orchestrate-batch-admit.sh`, `batch-orchestration-guardrails.md` (4 sites),
  `commands/orchestrate.md`, and `batch-admit-schema.md`'s dependency section rest on eligibility
  **item 4** (all predecessors terminal), which Work Stream A does not touch — they survive
  unedited. Only the literal "entering `researching`/`planning`, terminating, or failing"
  convergence-exit phrase depends on the removed **item 3**, at exactly **5 sites**.
- **Single-task engine converges, does not diverge.** `scripts/command-gate-in.sh` runs
  `task-lock.sh acquire-retry` and aborts the whole invocation before Stage 1 is ever entered, so
  by the time Stage 4's `researching`/`planning` handlers execute this session already holds the
  lock — their "being researched in another session" message is provably false in every reachable
  case.
- **Direction (b) defense-in-depth adopted**: a lock-check-gated demotion in
  `reconcile-task-status.sh`, reached only after the existing no-artifact no-op branch.

**Verification performed while planning** (every claim below re-confirmed against current source,
not carried from the report):

| Claim | Status |
|-------|--------|
| `{researching, planning}` exclusion bullet present at Stage MT-3 step 3 | CONFIRMED |
| Self-mod branch is `if ($sm_flag == true) then if ($inv_count > 1) then defer else admit end` | CONFIRMED |
| Classifier's `jq` chain has no `researching`/`planning` arm; both hit the final `else` -> `skip` | CONFIRMED |
| Exactly 5 sites carry the "entering researching/planning" convergence-exit clause | CONFIRMED (`skill-orchestrate/SKILL.md` x3, `skill-orchestrate-hard/SKILL.md` x1, `batch-admit-schema.md` x1) |
| "re-run affected tasks solo" diagnostic still present in the convergence guard | CONFIRMED |
| Test suite covers only the `partial` continuation predicate (fixtures A-D) + one `not_started` sandbox probe | CONFIRMED |
| `reconcile-task-status.sh` is NOT currently in `orchestrator-critical-paths.json` (14 entries) | CONFIRMED |
| `skill-orchestrate-hard/SKILL.md` has NO independent eligibility-rule restatement and NO phase-grouping table | CONFIRMED — it points back to the base skill; its only in-scope MT edits are the step 4.5 admission call site and the single convergence-exit site |

**One correction to the delegation framing** (not to the research report): the dispatch brief
states that the report judges *both* `parse-command-args.sh` and `orchestrator-critical-paths.json`
to need no edits. That is right for `parse-command-args.sh` but only half-right for
`orchestrator-critical-paths.json`: the report's Decision 8 explicitly requires adding
`reconcile-task-status.sh` to `critical_paths` **if Direction (b) lands**, and Decision 1 adopts
Direction (b). Phase 6 therefore edits that file. `parse-command-args.sh` is left untouched — the
tie-breaker is fully automatic and `--phase-map` is derived from the classifier, not from operator
input, so no new flag exists to parse; the existing `--allow-self-modifying` /
`--allow-scope-collision` escape hatches remain valid and unmodified.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Every admission gate in scope degrades to an ORDERING CONSTRAINT (defer to a later cycle) and
  never to a PERMANENT EXCLUSION.
- Eligibility depends on locks, `dependencies[]`, and file_scope overlap — never on an in-flight
  status string.
- N self-modifying tasks in one batch run in sequence via a deterministic tie-breaker; the
  operator is never told to "run it solo".
- The self-modification gate is phase-aware: a `research` or `plan` dispatch is not deferred
  because the task's *implementation* footprint names a critical path.
- Every co-maintained copy and every load-bearing safety argument the change falsifies is
  re-derived or corrected in the SAME phase as the mechanism — no phase boundary leaves a false
  premise asserted.
- The classifier suite gains fixtures for both engines' status-to-group rows, with the two new
  rows demonstrably failing against the pre-fix classifier.

**Non-Goals**:
- `cross_batch` `file_scope_collision` and `deploy_checkpoint` gates — out of scope per research
  Decision 6. `cross_batch`'s residual exclusion is a downstream symptom Work Stream A already
  repairs; `deploy_checkpoint` is a deliberate infra-safety gate whose exclusion is not a defect.
- Direction 3 (redeploy-boundary serialization) — rejected, and no follow-up task is created.
- The `blocked` and `unknown` classifier rows — left unchanged per research Decision 3.
- Any edit to `scripts/parse-command-args.sh`.
- Any edit under the deployed `.claude/**` tree.

## Fresh-Foreign-Lock Acceptance Criterion: The Named Mechanism

Acceptance requires that a task genuinely in flight under a **fresh** foreign lock is still never
concurrently dispatched after the status gate is removed. Two independent, already-existing
mechanisms guarantee this; neither is weakened by any change in this plan, and Phase 5 verifies
both remain intact:

1. **Multi-task engine — Stage MT-4's per-task `task-lock.sh acquire`.** Admission runs *before*
   lock acquisition and is a distinct gate. If `acquire` refuses (exit 1 — a fresh lock held by a
   genuinely different session; same-session re-entry never refuses), the task is removed from
   *this cycle's* dispatch batch and is explicitly NOT added to `failed_tasks`. This is already a
   defer-not-exclude gate with exactly the right semantics: a fresh foreign lock defers (ordering
   constraint), a stale one is reclaimed with a warning. Work Stream A removes a redundant, less
   accurate *proxy* (the status string) for this real mutex, which runs downstream of admission.
2. **Single-task engine — `scripts/command-gate-in.sh`'s `task-lock.sh acquire-retry`.** It
   `return 1`s and aborts the entire single-task `/orchestrate` invocation whenever a fresh foreign
   lock refuses after the bounded retry budget, *before* Stage 1 is ever entered. This is precisely
   why converging Stage 4's `researching`/`planning` handlers is safe: the handlers are only
   reachable once this session already holds the lock.

`task-lock.sh cmd_acquire` never reads `.status` — the lock layer has always been the concurrency
arbiter, independent of the status string being removed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Eligibility removal lands before the classifier maps `researching`/`planning` to real groups: a task becomes eligible, classifies as `skip`, and spins the dispatch batch empty until the convergence guard trips | H | M | Hard phase ordering: Phase 4 (classifier mapping) is a declared dependency of Phase 5 (eligibility removal). Phase 5's verification includes a grep confirming both new classifier arms exist before the bullet is removed. |
| Direction 1 also relaxes the lone-self-modifying-candidate case (admits immediately instead of waiting to be the sole eligible task) — a larger behavioral change than "fix the deadlock only" | M | H | Deliberate and in scope per research Decision 5. Hazard 1's claim (fix verified only in a scratch deploy-tree copy) is true regardless of co-dispatch; the per-task-commit-before-redeploy sequencing guarantee means no sibling dispatch is ever exposed to an unredeployed change. Phase 1 verifies with a dedicated 1-self-mod + 2-ordinary fixture. |
| Relocating the classifier call earlier in Stage MT-3 disturbs an unnamed MT-3 invariant | M | L | Nothing writes `state.json` between the relocated call site and the existing Stage MT-4 site within one cycle, and no other MT-3 step reads classifier output. Phase 2 reuses (never re-invokes) the output and adds a full-cycle phase-map regression check. |
| `reconcile-task-status.sh`'s demotion is a new class of write for that script | M | M | Scoped maximally narrowly: reached only after the existing no-artifact no-op condition, gated strictly on `task-lock.sh check` exit code (demote on 0 or 2 only; never on 1 — a genuinely fresh lock; never on 3 — fail closed on ambiguity), and logged loudly on every demotion. |
| A new test fixture passes both pre- and post-fix, proving nothing | M | M | Mutation-check discipline per `context/standards/shell-script-testing.md`: Phase 4 runs the two new fixtures against `git show HEAD:` of the classifier in the sandbox *before* applying the fix and records the RED output in the phase's commit body. |
| Editing the deployed tree instead of the source store | H | L | Every phase's verification is deploy + `verify-deploy.sh`, never an edit under `.claude/**`. `validate-meta-write.sh` fires advisorily on any `.claude/**` write. |
| A task-number reference leaks into a deliverable outside `specs/**` | M | M | `bash .claude/scripts/check-task-references.sh` is a verification step in every phase that edits a deliverable. |
| Live stranded-task set drifts between research and implementation | L | H | Fixtures are synthetic, per the test suite's existing convention; no live task number is hard-coded. Re-measure `task-lock.sh check` only as evidence, never as a target. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Phases 1 and 3 touch disjoint files
(`scripts/orchestrate-batch-admit.sh` + `docs/architecture/batch-admit-schema.md` vs.
`scripts/tests/test-orchestrate-triage-classify.sh`) and are safe to run concurrently.

---

### Phase 1: Self-modification tie-breaker and phase-aware gating in the admission script [COMPLETED]

**Goal**: `orchestrate-batch-admit.sh` stops deadlocking on 2+ co-dispatched self-modifying
candidates and stops deferring research/plan dispatches on an implementation-phase footprint —
with its own header contract and the schema doc updated in the same change.

**Tasks**:
- [x] Direction 1 — inside the existing single inline `jq` invocation, compute the set of
      candidates in `$cands` for which `self_mod_match($c_scope; $crit)` matches, and bind the
      **lowest task number** in that set as `$designated_sm_candidate`. No new I/O, no second `jq`,
      no change to `scripts/lib/file-scope-overlap.sh`. *(completed)*
- [x] Change the self-mod branch from `if ($inv_count > 1) then defer` to
      `if ($inv_count > 1 and $c != $designated_sm_candidate) then defer`, leaving the `admit` arm
      otherwise unchanged. *(completed)*
- [x] Rewrite the `defer_reason: "self_modifying"` verdict's `reason` string: it must name the
      designated candidate and state that this is an ordering constraint resolving next cycle —
      never an instruction to run anything solo. *(completed)*
- [x] Direction 2 — add `--phase-map task:group[,task:group...]` (and the `--phase-map=` form) to
      the argument scan alongside `--invocation-count` / `--session-id`, with the same
      malformed-value rejection posture those flags already use. The argument is **optional**: an
      absent phase map preserves today's behavior exactly. *(completed)*
- [x] When a phase-map entry names `research` or `plan` for a self-modifying candidate, skip the
      `self_modifying` defer branch regardless of `$inv_count`; keep `self_modifying: true` on the
      verdict (the existing "hazard stays visible even when not deferred" convention) while
      `decision` resolves to `admit`. *(completed)*
- [x] Update the script's own header block: the `--phase-map` argument contract, the revised
      self-mod branch semantics, and the rationale for lowest-task-number determinism (the same
      ascending-`project_number` first-match convention already used by the `in_batch` deferral
      direction and the self-modification first-match rule). *(completed)*
- [x] Update `docs/architecture/batch-admit-schema.md` for the new argument and its effect on the
      verdict schema. Do **not** touch that file's convergence-exit-condition sentence in this
      phase — it belongs to Phase 5. *(completed: no version bump — see the doc's new
      "NOT a version bump" Version History entry for the rationale)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the tie-breaker and phase gate are implementable entirely
within `orchestrate-batch-admit.sh`'s existing inline `jq` with `$cands` and `self_mod_match`
already in scope, and require no change to `scripts/lib/file-scope-overlap.sh`. Confirm at
implementation time by reading the `jq` invocation's full `--arg`/`--argjson` binding list and the
sourced-library block before writing; if either assumption fails, stop and report rather than
widening the edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - tie-breaker, `--phase-map`
  parsing and phase gate, verdict reason text, header contract
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - `--phase-map` argument
  and verdict-schema documentation

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
```
Then, against a synthetic `specs/state.json` in a `mktemp -d` sandbox shaped like the existing
suite's `$WORKDIR/.claude/scripts/` layout:
- **Deadlock fixture**: 3 candidates whose `file_scope` all name a `critical_paths` entry,
  `--invocation-count 3`. Expect exactly one `decision: "admit"` (the lowest task number) and two
  `decision: "defer"`, `defer_reason: "self_modifying"`. Pre-fix this fixture yields three defers.
- **Consequence-A fixture**: 1 self-modifying + 2 ordinary candidates, `--invocation-count 3`.
  Expect the self-modifying candidate to `admit` immediately.
- **Phase-gate fixture**: the same 3 self-modifying candidates with
  `--phase-map "<a>:research,<b>:plan,<c>:implement"`. Expect the `research` and `plan` candidates
  to `admit` with `self_modifying: true` retained, and only the `implement` candidate subject to
  the tie-breaker.
- **No-regression fixture**: omit `--phase-map` entirely; verdicts must match the deadlock fixture
  above (backward compatibility of the optional argument).
- `grep -n "run.*solo\|re-run affected tasks solo" agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` returns nothing.

---

### Phase 2: Wire the phase map and tie-breaker into both orchestration engines [COMPLETED]

**Goal**: Stage MT-3 step 4.5 computes the phase map once and threads it into the admission call
and forward into Stage MT-4; the operator-facing self-mod defer warning and the convergence-guard
diagnostic both stop describing a solo re-run as the remedy.

**Tasks**:
- [x] In `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, relocate the
      `orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"` call to immediately before the
      admission call, and add `--phase-map` (built from the classifier's NDJSON group mapping) to
      the `orchestrate-batch-admit.sh` invocation alongside the existing `--invocation-count` /
      `--session-id`. *(completed)*
- [x] Thread the already-computed group mapping **forward** into Stage MT-4 rather than
      re-invoking the classifier there. State explicitly in the prose why reuse is safe: nothing
      writes `state.json` between the two sites within one cycle. *(completed)*
- [x] Rewrite the self-mod defer operator warning so it names the designated candidate and frames
      the defer as a one-cycle ordering constraint. Remove any implication that the operator must
      intervene; keep `--allow-self-modifying` as a deliberate human-intent bypass. *(completed:
      warning now logs the verdict's own `reason` string directly instead of a separately
      maintained paraphrase)*
- [x] Update the convergence-guard diagnostic (constraint 5): the mutually-colliding
      self-modifying set is no longer a reachable cause once the tie-breaker exists. Reframe the
      likely causes as a tie-breaker bug, a `deploy_checkpoint` exclusion interacting with the
      batch, or an unexpected `file_scope_collision`/`session_active` chain. **Keep the guard
      mechanism and its bound of 3 cycles intact** — only the diagnostic wording changes.
      *(completed: mechanism, counter, reset-on-dispatch rule, and 3-cycle bound left untouched;
      only the diagnostic string changed)*
- [x] Mirror the step 4.5 admission-call and phase-map changes in
      `skill-orchestrate-hard/SKILL.md`'s Multi-Task Mode section, which transcribes this mechanism
      in full. Do not leave it as a bare pointer — that failure mode has already been caught once
      in this file. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts `skill-orchestrate-hard/SKILL.md` needs only the step 4.5
admission-call mirror here (its convergence-exit site is Phase 5's, and it has no independent
eligibility-rule restatement or phase-grouping table). Confirm at implementation time with
`grep -n "eligible_tasks\|orchestrate-batch-admit\|Phase grouping" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`;
if an independent restatement surfaces, correct it in this phase rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-3 step 4.5 classifier
  relocation, phase-map threading, self-mod warning text, convergence-guard diagnostic
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored step 4.5
  admission call and phase-map threading

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
grep -rn "re-run affected tasks solo\|run it solo" agent-system/extensions/core/ ; # expect no matches
grep -n "phase-map" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
bash .claude/scripts/check-task-references.sh
```
- Confirm by reading that the classifier appears exactly once per cycle in
  `skill-orchestrate/SKILL.md`'s MT path (relocated, not duplicated).
- Confirm the `consecutive_no_dispatch_cycles` counter, its reset-on-dispatch rule, and its bound
  of 3 are all still present and unchanged.

---

### Phase 3: Classifier test-coverage baseline for the untested status rows [COMPLETED]

**Goal**: The classifier suite covers every status-to-group row for both engines *except* the two
rows this task changes, giving a green baseline that would catch collateral damage from Phase 4.

**Tasks**:
- [x] Add synthetic state.json fixtures and `check_fixture` assertions, reusing the suite's
      existing sandbox shape and `pass()`/`fail()`/counter conventions, for: `not_started` on the
      `mt` engine (pairing with the existing single-only sandbox probe); `researched` -> `plan`
      (both engines); `planned` -> `implement` (both engines); `implementing` -> `implement` (both
      engines); a terminal status -> `terminal` (both engines); an unrecognized/garbage status
      string -> `skip` (both engines). *(completed: 12 new assertions across 6 status rows)*
- [x] Add the one documented engine-divergent row: `blocked` -> `needs_human` on `single`,
      `blocked` -> `skip` on `mt`. Annotate it in-file as the intentional divergence it is, so a
      future reader does not "fix" it. *(completed: 2 more assertions, 13 new assertions total)*
- [x] Extend the suite's header comment: it currently describes itself as scoped to the `partial`
      continuation-pointer predicate; it is now the full status-to-group regression suite.
      *(completed)*
- [x] Do **not** add `researching`/`planning` fixtures in this phase — those are Phase 4's
      mutation-check fixtures and must be written and run against the pre-fix classifier there.
      *(confirmed: none added)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts roughly 13 new assertions across 7 status rows are needed
and that the existing sandbox shape supports them without a `STATE_FILE` override. Confirm at
implementation time by running the extended suite: if the sandbox probe or any new fixture fails
for a shape reason rather than a behavior reason, stop and report rather than adding an override.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - new fixtures
  and assertions, header scope update

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash -n agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh
bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh
```
- Expect exit 0, `FAILED == 0`, and a PASSED count strictly greater than the pre-phase count.
- All pre-existing fixtures A-D assertions must still pass (no regression).

---

### Phase 4: Classifier maps researching/planning to real phase groups, with all three co-maintained copies [COMPLETED]

**Goal**: `researching` routes to the research group and `planning` to the plan group on both
engines, with the classifier's header table, Stage MT-4's phase-grouping table, and single-task
Stage 4's handlers all changed in this same phase — the script's own header declares these three
artifacts must never change independently.

**Tasks**:
- [x] **Write the two mutation-check fixtures FIRST**: `researching` -> `research` and `planning`
      -> `plan`, both engines. Run them in the sandbox against
      `git show HEAD:agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` and
      capture the RED output (pre-fix both emit `group: "skip"`). Record that output in the phase's
      commit body as the mutation-check evidence required by
      `context/standards/shell-script-testing.md`. *(completed: RED confirmed pre-fix — both
      fixtures failed with `group=skip`, reason "transitional/unknown"; 22 other fixtures
      unaffected — see commit body)*
- [x] Add `elif ($status == "researching")` -> `group: "research"` and
      `elif ($status == "planning")` -> `group: "plan"` arms to the `jq` chain, placed before the
      final `else`, with `reason` strings matching the chain's existing phrasing style. *(completed)*
- [x] Update the script's header engine table: split the
      `| researching, planning, unknown | skip | skip |` row into `researching -> research`,
      `planning -> plan`, and a remaining `unknown -> skip` row, for both engine columns.
      *(completed)*
- [x] Update Stage MT-4's "Phase grouping" table in `skill-orchestrate/SKILL.md`: move
      `researching` into `research_tasks` and `planning` into `plan_tasks`, leaving only
      `blocked`/unknown in the `skip` row. Preserve the existing note that `blocked` is the one
      intentional engine divergence. *(completed)*
- [x] Converge single-task Stage 4's `researching` and `planning` handlers in
      `skill-orchestrate/SKILL.md`: replace the `EXIT (partial)` + "being researched in another
      session" warning with dispatch, mirroring the `not_started` / `researched` handlers. Record
      the justification inline: `command-gate-in.sh`'s `acquire-retry` already aborted the
      invocation if a fresh foreign lock refused, so this session provably holds the lock by the
      time these handlers run. *(completed; also corrected the same false "exit with warning"
      claim in docs/architecture/orchestrate-state-machine.md's state table and added a
      "Convergence: researching/planning No Longer Exit" subsection — found via the phase's
      required census grep, corrected in-phase per the Scope Hypothesis)*
- [x] Mirror the converged handlers in `skill-orchestrate-hard/SKILL.md` — its `researching` and
      `planning` handlers currently read "Same as base skill" over the old exit behavior and would
      otherwise assert a now-false claim. *(completed; `planning` handler cross-references the
      `researched` handler's H4-gated dispatch block immediately above rather than duplicating it,
      since a stranded `planning` task needs identical treatment)*
- [x] Re-run the two mutation-check fixtures post-fix; both must now be GREEN. *(completed: GREEN,
      26 passed, 0 failed)*

**Timing**: 2 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly four co-maintained sites carry the status-to-group
mapping (classifier `jq` chain, classifier header table, Stage MT-4 phase-grouping table,
single-task Stage 4 handlers in both skills). Confirm at implementation time with
`grep -rn "researching" agent-system/extensions/core/skills agent-system/extensions/core/scripts agent-system/extensions/core/docs agent-system/extensions/core/commands`
before declaring the phase complete; any additional site found must be corrected in this phase, not
deferred.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - two new `jq` arms, header
  engine table
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 phase-grouping
  table, single-task Stage 4 `researching`/`planning` handlers
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - mirrored single-task
  `researching`/`planning` handlers
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - two
  mutation-check fixtures

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash -n agent-system/extensions/core/scripts/orchestrate-triage-classify.sh
# Mutation check (run BEFORE applying the jq change; must be RED):
#   copy `git show HEAD:agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`
#   into the sandbox and confirm both new fixtures report group="skip", i.e. FAIL.
bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh   # post-fix: exit 0
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
bash .claude/scripts/check-task-references.sh
```
- The three co-maintained tables must agree row-for-row; verify by reading all three side by side.
- `grep -n "being researched in another session" agent-system/extensions/core/` returns nothing.

---

### Phase 5: Remove the status-gated eligibility exclusion and re-derive every argument it falsifies [COMPLETED]

**Goal**: The `{researching, planning}` eligibility exclusion is gone, and every one of the 5
convergence-exit-condition sites plus both state-machine-doc restatements is corrected in the same
change — no phase boundary leaves a now-false premise asserted.

**Tasks**:
- [x] Remove the `Status is NOT {researching, planning} (in-flight from prior cycle)` bullet from
      Stage MT-3 step 3 in `skill-orchestrate/SKILL.md`. Leave the `deferred_deploy_checkpoint`
      bullet and the dependency-terminal-state bullet (item 4) untouched — item 4 is what the
      surviving "structurally impossible" claims rest on. *(completed)*
- [x] In its place, state the replacement contract: eligibility depends on locks,
      `dependencies[]`, and file_scope overlap; a task genuinely in flight under a fresh foreign
      lock is deferred by Stage MT-4's per-task `task-lock.sh acquire` (exit 1 -> removed from this
      cycle's batch, never added to `failed_tasks`), which is already a defer-not-exclude gate.
      *(completed)*
- [x] Correct all **5** convergence-exit-condition sites to the research report's recommended
      replacement: "...once its co-dispatched sibling leaves `eligible_tasks` by terminating or
      failing (a task no longer leaves `eligible_tasks` merely by entering
      `researching`/`planning` once eligibility is no longer status-gated)." *(completed, all 5;
      census grep confirmed exactly 5 pre-edit and 0 post-edit)*
      - `skills/skill-orchestrate/SKILL.md` — Stage MT-1 `deferred_self_modifying` field doc
      - `skills/skill-orchestrate/SKILL.md` — Stage MT-3 step 4.5 `in_batch` collision branch
        (flagged in-file as load-bearing for the convergence argument elsewhere)
      - `skills/skill-orchestrate/SKILL.md` — Stage MT-3 step 4.5 self-mod convergence-guard
        rationale
      - `skills/skill-orchestrate-hard/SKILL.md` — transcribed `in_batch` branch
      - `docs/architecture/batch-admit-schema.md` — the v3-onward convergence-mechanism paragraph
- [x] At the two self-modifying-specific sites (the `deferred_self_modifying` field doc and the
      convergence-guard rationale, plus the hard-mode mirror), additionally record Phase 1's
      designated-candidate tie-breaker as a **second, independent, per-cycle exit condition that
      depends on no status transition at all** — this is what actually bounds the
      multiple-self-modifying case, and is materially stronger than the status-transition argument
      ever was. *(completed: also added to batch-admit-schema.md's v3-onward paragraph for
      consistency, since that site documents the same self-mod convergence mechanism; no separate
      convergence-guard rationale exists in the hard-mode file to mirror -- confirmed by grep --
      so its `in_batch` branch received only the general template correction)*
- [x] Update `docs/architecture/orchestrate-state-machine.md`: remove clause `(b) not in-flight
      (researching, planning)` from the ASCII eligibility box, and remove item 2 from the
      Dependency Gating Model prose, renumbering the surviving items. *(completed)*
- [x] Do **not** edit the dependency-terminal-state claims at `orchestrate-batch-admit.sh`,
      `batch-orchestration-guardrails.md`, `commands/orchestrate.md`, or
      `batch-admit-schema.md`'s dependency section — they rest on item 4, which is unchanged.
      Verify this by re-reading each before concluding no edit is owed. *(confirmed: git diff
      --stat shows no change to these 3 files in this phase)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly 5 convergence-exit sites and exactly 2
state-machine-doc restatements need correction, and that `commands/orchestrate.md` needs no edit.
Confirm at implementation time with the grep below **before** editing; the count must be 5 (plus
the two `leaves eligible_tasks` occurrences that carry the dependency-edge-connected phrasing
instead and are correctly out of scope). Any additional site is corrected in this phase.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - eligibility bullet removal,
  replacement contract, 3 convergence-exit corrections
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - 1 convergence-exit
  correction
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - 1 convergence-exit
  correction
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - ASCII diagram
  clause and Dependency Gating Model item

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions/core
# Pre-edit census (expect the 5 in-scope sites):
grep -rn "entering \`researching\`/\`planning\`\|enters \`researching\`/\`planning\`" skills docs commands context
# Post-edit: expect ZERO matches for the status-transition exit clause
grep -rn "entering \`researching\`/\`planning\`\|enters \`researching\`/\`planning\`" skills docs commands context
# Post-edit: expect ZERO eligibility-exclusion restatements
grep -rn "NOT \`{researching, planning}\`\|not in-flight (researching" skills docs commands context
# Surviving item-4 claims must be intact and unedited:
git diff --stat -- context/patterns/batch-orchestration-guardrails.md commands/orchestrate.md scripts/orchestrate-batch-admit.sh   # expect no changes in this phase
cd /home/benjamin/.config/nvim
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh
bash .claude/scripts/check-task-references.sh
```
- Read Stage MT-4's `task-lock.sh acquire` contract and confirm verbatim that its exit-1
  defer-not-exclude semantics are untouched — this is the fresh-foreign-lock acceptance criterion.

---

### Phase 6: Lock-aware demotion guard in reconcile-task-status.sh [COMPLETED]

**Goal**: Defense-in-depth — a task stranded in `researching`/`planning` with no artifact and no
live lock is demoted to a re-dispatchable status, giving operator-visible repair independent of
`/orchestrate`.

**Tasks**:
- [x] In `reconcile-task-status.sh`'s `researching)` branch, add a demotion check reached **only
      after** the existing no-artifact no-op condition (the branch that currently logs "no report
      artifact found — no-op"). Call `task-lock.sh check "$task_number"` and demote
      `researching` -> `not_started` **only** on exit 0 (free) or exit 2 (held-stale). Never on
      exit 1 — a genuinely fresh lock must never be demoted. Never on exit 3 — fail closed on a
      resolution error, no demotion. *(completed via a new `demote_stranded_status()` helper;
      also fixed a `set -e` command-substitution pitfall on the lock-check call, mirroring the
      `if VAR=$(cmd); then ... else exit=$?; fi` pattern already used by
      orchestrate-batch-admit.sh/state-write.sh/task-lock.sh/git-commit-scoped.sh)*
- [x] Mirror the same guard in the `planning)` branch: demote `planning` -> `researched` under the
      identical exit-code gate. *(completed)*
- [x] Log loudly on every demotion (and on every refusal, naming the exit code and reason) so the
      new write class is never silent. Honor the script's existing dry-run / "Would promote"
      convention symmetrically for demotions. *(completed: "Would demote"/"DEMOTED"/refusal lines
      naming the lock-check output)*
- [x] Add `scripts/reconcile-task-status.sh` to `orchestrator-critical-paths.json`'s
      `critical_paths` array with a descriptive label. Do **not** add it to the `recursion_guard`
      subset — that subset is scoped to the discrimination/recording pipeline only, which
      explicitly excludes this script. *(completed)*
- [x] Update the script's header comment block, which currently documents only the promotion
      directions, to describe the demotion directions and their lock-check gate. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the demotion can be attached to exactly two existing
no-artifact no-op sites without restructuring either branch, and that
`orchestrator-critical-paths.json` currently has 14 `critical_paths` entries with no
`reconcile-task-status.sh` row. Confirm at implementation time with
`jq '.critical_paths | length, (map(.path) | index("scripts/reconcile-task-status.sh"))' agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
(expect `14` and `null`) before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - demotion guards in the
  `researching` and `planning` branches, header contract
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` - new
  `critical_paths` entry

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash -n agent-system/extensions/core/scripts/reconcile-task-status.sh
jq -e '.critical_paths | map(.path) | index("scripts/reconcile-task-status.sh") != null' \
  agent-system/extensions/core/context/reference/orchestrator-critical-paths.json
jq -e '(.recursion_guard // []) | index("scripts/reconcile-task-status.sh") == null' \
  agent-system/extensions/core/context/reference/orchestrator-critical-paths.json
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
bash .claude/scripts/check-task-references.sh
```
Sandbox matrix (synthetic `specs/state.json` + synthetic `.lock/` directories in a `mktemp -d`
tree), asserting the exit-code gate exactly:

| Status | Artifact | `task-lock.sh check` | Expected |
|--------|----------|----------------------|----------|
| `researching` | none | 0 (free) | demote -> `not_started`, logged |
| `researching` | none | 2 (held-stale) | demote -> `not_started`, logged |
| `researching` | none | 1 (held-fresh) | NO demotion, refusal logged |
| `researching` | none | 3 (resolution error) | NO demotion, fail-closed logged |
| `researching` | report present | any | existing promotion path unchanged |
| `planning` | none | 0 or 2 | demote -> `researched`, logged |
| `planning` | none | 1 or 3 | NO demotion |
| `planning` | plan present | any | existing promotion path unchanged |

---

### Phase 7: Normative guardrails record — gate catalogue, rejected direction, and the two-clause distinction [NOT STARTED]

**Goal**: `batch-orchestration-guardrails.md` states the ordering-constraint-not-exclusion
principle normatively, records Direction 3 as considered-and-already-satisfied so it is not
re-proposed, and distinguishes the eligibility rule's two independent clauses so a future auditor
does not re-derive it from scratch.

**Tasks**:
- [ ] Add a short subsection cataloguing the post-fix admission gates and, for each, whether it is
      an ORDERING CONSTRAINT or a genuine EXCLUSION, with the reason. `deploy_checkpoint` remains
      a deliberate, correct exclusion (a failed deploy genuinely requires human remediation);
      `self_modifying` is now an ordering constraint resolved by the designated-candidate
      tie-breaker; `session_active` and `file_scope_collision` retain their existing
      defer-direction semantics.
- [ ] Add a "considered and found already satisfied" note to the **Inter-Cycle Redeploy
      Checkpoint** subsection recording why redeploy-boundary serialization was rejected: dispatch
      is cycle-synchronous, every dispatched task's scoped commit lands at Stage MT-4 before the
      Stage MT-3 redeploy checkpoint evaluates, and there is no cross-cycle concurrency — so
      "hold the redeploy until in-flight siblings reach a cycle boundary" is already what happens
      by construction. Explicitly state that no follow-up task is owed.
- [ ] Add one sentence to **The Same-Cycle Narrowing and Its Hazard Accounting** distinguishing the
      dependency-terminal-state clause (which no change here touches, and on which the surviving
      "structurally impossible" claims rest) from the former in-flight-status clause (removed).
- [ ] Re-read the four dependency-terminal-state claim sites in this file and confirm each remains
      accurate as written; correct any that turn out to conflate the two clauses.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the guardrails file needs additive content only, and that
its four existing dependency-terminal-state claim sites need no correction. Confirm by reading all
four before closing the phase; if any conflates the two clauses, correct it here rather than
recording it as follow-up work.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - gate
  catalogue subsection, Direction-3-closed note, two-clause distinction sentence

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh
bash .claude/scripts/check-task-references.sh
git diff -- agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md
```
- Diff read-through confirming every changed hunk is prose in the intended subsections.
- Confirm the new catalogue's gate names match the `defer_reason` values actually emitted by
  `orchestrate-batch-admit.sh` (`self_modifying`, `file_scope_collision`, `session_active`,
  `deploy_checkpoint`) — a catalogue naming a gate the script does not emit is a new false premise.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` exits 0
      with `FAILED == 0` and a PASSED count covering every status-to-group row for both engines.
- [ ] The two `researching`/`planning` fixtures are demonstrated RED against the pre-fix classifier
      (`git show HEAD:` copy in the sandbox) and GREEN post-fix; the RED evidence is recorded in
      Phase 4's commit body.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no new failures relative
      to a pre-task baseline captured before Phase 1.
- [ ] `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh` succeeds
      at the close of every phase.
- [ ] `bash .claude/scripts/check-task-references.sh` passes — no task-number references leak into
      any deliverable outside `specs/**`.
- [ ] `bash -n` passes on every edited shell script.
- [ ] Admission-script fixture matrix (Phase 1): deadlock, Consequence-A, phase-gate, and
      no-`--phase-map` regression fixtures all produce the expected verdicts.
- [ ] `reconcile-task-status.sh` exit-code matrix (Phase 6): all 8 rows behave as tabulated, with
      no demotion on exit 1 or exit 3.
- [ ] Repo-wide: `grep -rn "re-run affected tasks solo\|run it solo" agent-system/extensions/core/`
      returns nothing.
- [ ] Repo-wide: `grep -rn "entering \`researching\`/\`planning\`" agent-system/extensions/core/`
      returns nothing.
- [ ] `git diff --stat` confirms no file under `.claude/**` was hand-edited at any point.
- [ ] The declared `file_scope` was sufficient: no file outside it was edited. If implementation
      needs one, **stop and widen `file_scope` via `state-write.sh` naming each additional file
      exactly** (no bare directory roots, no duplicate entries) before making the edit.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (tie-breaker, `--phase-map`)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (two new status rows)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (full
  status-to-group suite incl. mutation-check fixtures)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (lock-aware demotion guard)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- `specs/067_orchestrate_eligibility_not_status_gated/summaries/01_admission-gates-as-ordering-constraints-summary.md`

**Declared-but-untouched** (per research Decisions 8 and the task's own "leave it untouched" rule):
- `agent-system/extensions/core/scripts/parse-command-args.sh` — no new flag exists to parse.
- `agent-system/extensions/core/commands/orchestrate.md` — its eligibility claims rest on the
  unchanged dependency-terminal-state clause. Phase 5 verifies this by reading before concluding.

## Rollback/Contingency

- Each phase is a scoped commit under `task 67 phase {P}: {name}`; reverting a phase is a single
  `git revert` of that commit followed by
  `bash .claude/scripts/deploy-headless.sh && bash .claude/scripts/verify-deploy.sh`.
- **Ordering hazard on partial rollback**: Phase 5 (eligibility removal) must never be live while
  Phase 4 (classifier mapping) is reverted — that combination makes `researching`/`planning` tasks
  eligible but unclassifiable, spinning the dispatch batch empty until the convergence guard trips.
  If Phase 4 must be reverted, revert Phase 5 first.
- Phase 6 is independent defense-in-depth and can be reverted alone with no effect on Work Streams
  A or B.
- Before any destructive git operation on a dirty tree, run
  `bash .claude/scripts/git-snapshot.sh 67` first, per `rules/git-workflow.md`.
- If a phase's verification fails in a way that cannot be fixed forward within the phase, mark the
  phase `[PARTIAL]`, leave the prior phase's commit as the last green state, and escalate rather
  than routing around the friction — do not proceed to a dependent phase on a red boundary.
