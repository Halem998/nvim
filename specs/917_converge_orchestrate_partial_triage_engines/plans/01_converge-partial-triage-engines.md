# Implementation Plan: Task #917

- **Task**: 917 - Converge single-task /orchestrate partial triage onto the mt engine
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/917_converge_orchestrate_partial_triage_engines/reports/01_converge-partial-triage-engines.md
- **Artifacts**: plans/01_converge-partial-triage-engines.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md, git-staging-scope.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A task left `[PARTIAL]` by a base-mode dispatch has, by construction, no `.orchestrator-handoff.json`
(base-mode writers never write one). The single-task `/orchestrate` engine treats that normal state
as a permanent dead end (`exit_partial`, exit with a referral to `/implement`), while the multi-task
(`mt`) engine dispatches `implement` for the literal same task in the literal same state. This plan
removes that engine fork so both engines route the `partial`-with-neither row to `implement`, and
brings six source-store files plus one regression test into agreement about it. The definition of
done is the acceptance criterion below plus three-way table agreement (classifier header, Stage 4
prose, Stage MT-4 table) and a green regression suite.

**Acceptance criterion**: `/orchestrate N` on a single task in `partial` state with no handoff and
no blockers dispatches implement and makes forward progress, instead of exiting with a referral to
`/implement` — while `MAX_CYCLES` still terminates a task that cannot progress.

**Binding constraint**: the agent-system SOURCE of truth is `agent-system/extensions/core/`. The
`.claude/` tree is a gitignored, disposable deploy artifact regenerated from the source store. ALL
edits target `agent-system/extensions/**` and NEVER `.claude/**`. The single exception is the
regression test under `specs/901_orchestrate_dry_run_admission_report/tests/`, which is a `specs/**`
test-suite file (see File Scope Expansion below) — and it already reads the source-store script
directly, copying it into a scratch deploy tree, so it never touches the real `.claude/`.

### Research Integration

Every factual claim in the task description was independently re-verified against the source store
by the research phase, and each was confirmed. Findings carried directly into this plan:

- **No new bounding mechanism is required** (scope item G). The outer loop condition
  (`while [ "$cycle_count" -lt "$MAX_CYCLES" ]`) and the existing Stage 7 `MAX_CYCLES reached` exit
  are already the sole and sufficient bound. Once the unconditional `EXIT` is replaced with a
  dispatch, a task that makes no progress simply cycles until that pre-existing exit fires. G is
  satisfied by *verification*, not by new code — adding a second guard would be a redundant
  divergence of its own.
- **Scope item F is doc-conformance, not a doc rewrite**. `docs/architecture/orchestrate-state-machine.md`
  already documents the target semantics (the `partial` no-handoff row exits only at
  `cycle_count >= MAX_CYCLES`). Only a clarifying addition is needed so a reader sees that row is
  reached via the generic end-of-cycle check, not a dedicated early exit.
- **Scope item H needs no weakening**. `commands/orchestrate.md` CHECKPOINT 1's permissive-gate
  claim is *made true* by this fix rather than falsified by it; the change there is a one-line
  strengthening that closes the audit loop, not a correction.
- **A live regression test outside the declared file scope asserts the exact behavior being
  removed** and will fail the moment the classifier is fixed. It is folded into Phase 1 so no
  commit lands with a knowingly red suite.
- **The Stage 4 resume-context read is a genuinely new call shape** for
  `orchestrate-recover-outcome.sh` (its two existing callers are strictly post-dispatch). The
  specific call shape, the staleness-gate disablement, and the required distinct variable name are
  pinned in Phase 3 below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation was requested for this task; no roadmap phases are included.

## Decisions

Both decisions the task requires were evaluated against the research recommendation rather than
rubber-stamped. Both recommendations are **accepted**, with the reasoning recorded here so the
justification lands in the artifacts rather than only in the plan.

### Decision 1 — the `blocked` row: KEEP the divergence, document the justification

**Resolution**: `blocked` continues to route to `skip` under `mt` and `needs_human` under `single`.
Behavior is unchanged. What changes is that the justification is written down in all three places
that state the routing.

**Why this is not the same defect as the `partial` row.** The discriminator is *independent
corroboration*: does the other engine's own handler implement the divergence, or does only the
classifier assert it?

- For the `partial` row, only the classifier and one prose paragraph asserted the divergence, and
  the paragraph cited a decision in an originating plan that is no longer traceable in the doc
  tree. Nothing else in the system independently implemented `exit_partial`. That is an assertion,
  not a design.
- For the `blocked` row, Stage 4's `#### State: blocked` handler contains **no engine conditional at
  all** — it unconditionally reads blockers from `state.json` and invokes blocker escalation, i.e.
  it always behaves as `needs_human`. Stage MT-4's table independently folds `blocked` into the
  generic `skip` group. Two handlers, written separately, already agree with the classifier. That is
  a design.

**Semantic justification to be written into the artifacts**: a solo invocation has no sibling task
to make progress on, so escalation is the only meaningful action; a batch invocation skips the
blocked task so its siblings can proceed. Changing `single` to `skip` would introduce a new defect
(a solo `/orchestrate` on a blocked task would do nothing at all), not fix one.

**Alternative considered and rejected**: converging `blocked` too, for uniformity's sake. Rejected
because uniformity is not the goal — *undocumented* divergence is the defect. Converging here would
regress live behavior to satisfy a symmetry the two engines do not actually share.

**Recurrence guard**: the discriminator above (independent implementation by the other engine's own
handler vs. bare classifier assertion) is recorded next to the `blocked` row so a future auditor can
re-apply the same test instead of re-litigating from scratch.

### Decision 2 — `exit_partial`: RETAIN as an explicitly-reserved schema value, no version bump

**Resolution**: `exit_partial` stays enumerated in the `orchestrate-triage-v1` `group` field
documentation, annotated as reserved and not currently emitted by any row. The schema identifier
stays `orchestrate-triage-v1`. The dry-run reporter's defensive `case` arm stays, with its message
reworded.

**Why not a version bump.** A schema version identifier governs the *field set and field shapes* of
the output objects. This change alters neither: every field, its type, and the field order are
untouched. Only the reachable value domain of one enum shrinks. Shrinking a value domain is not a
breaking change for a *reader* (no reader can be broken by a value it stops receiving) — it is only
breaking for a *writer*, and this repo's classifier is the sole writer. Bumping to `v2` would
therefore invalidate every pin on `v1` to describe a change no `v1` consumer can observe. That is
pure churn.

**Why not retire the string outright.** A repo-wide grep found `exit_partial` in exactly the
classifier, the dry-run reporter, the Stage 4 cross-reference being deleted, and the regression test
— all already in scope. Retiring it is therefore *safe*, but it buys nothing and costs two things:
(1) the dry-run reporter's `case` statement loses a defensive arm and would silently fall through on
an unexpected group value, and (2) a future engine or mode that legitimately wants an
"exit-without-dispatching" verdict distinct from `skip`/`needs_human`/`terminal` would have to
re-derive the exact semantics this name already carries.

**The one outcome explicitly ruled out** is the third, silent option: leaving a now-dead value in
the enum undocumented. The annotation is the whole point of the decision.

## File Scope Expansion (explicit)

The task's declared `file_scope` covers five source-store files. Two additions are required:

| File | Why it is in scope | Status |
|------|--------------------|--------|
| `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` | Contains a live assertion (the case labelled "THE DIVERGENCE") that task-fixture 955's `partial`-with-neither row is `implement` under `mt` and `exit_partial` under `single`. It will fail the instant the classifier is fixed. It is a regression check, not documentation. | **Added** (Phase 1) |
| `specs/state.json` (task 917's own `file_scope` array) | The declared scope must be updated to record the expansion rather than leaving it discovered-at-verification-time. | **Added** (Phase 1) |

The test file lives under `specs/**`, which the no-task-references rule's exception list explicitly
permits, and it reads the source-store script directly (copying it into a `mktemp -d` scratch deploy
tree) rather than the real `.claude/` — so including it does not violate the source-store rule.

`specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` was checked and does
**not** reference `exit_partial`. No change is needed there.

## Goals & Non-Goals

**Goals**:
- Both engines route `partial` with neither continuation nor blockers to `implement`.
- Single-task Stage 4 dispatches implement for that sub-state, sourcing resume context from the
  prior dispatch's `.return-meta.json` in place of the handoff a base-mode run never writes.
- The classifier header verdict table, Stage 4 prose, and the Stage MT-4 phase-grouping table all
  state the same routing at the end of this task.
- Both decisions above are recorded with justifications in the artifacts, not only in this plan.
- The regression suite is green at every commit.
- `MAX_CYCLES` is confirmed — by trace, not by new code — to bound the newly-reachable resume path.

**Non-Goals**:
- Changing the `blocked` row's behavior (Decision 1).
- Bumping the triage output schema version (Decision 2).
- Adding any new cycle counter, resume guard, or bounding mechanism (scope item G is satisfied by
  verification).
- Adding a "plan file missing" guard to the new dispatch branch. A `partial` task with no plan file
  will dispatch implement and likely make no progress — exactly as the `mt` engine already does
  today. Introducing a single-task-only guard here would reintroduce the very class of divergence
  this task removes. `MAX_CYCLES` bounds it. This is a deliberate, recorded acceptance.
- Rewriting `docs/architecture/orchestrate-state-machine.md` beyond the clarifying addition
  described in Phase 5 — the code is being brought up to that doc, not the reverse.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 4's new `orchestrate-recover-outcome.sh` call is a new shape (pre-dispatch, prior cycle's metadata); reusing `dispatch_start_ts` as its window would silently bind it to the wrong semantics | H | M | Pin a distinct variable name `prior_meta_probe_window=0` in Phase 3, with an inline comment stating why the staleness gate is intentionally disabled for this one read. Never reuse `dispatch_start_ts` for it. |
| `orchestrate-recover-outcome.sh` exits 1 for a `partial`/`in_progress` prior status — the common case here — and a naive `set -e`-style caller would treat that as a failure | H | M | Phase 3 specifies the call is made tolerantly (`|| true`) and that `recovered=false` is expected and non-fatal: the probe supplies *context*, never a success claim. |
| Editing the classifier without editing the test in the same commit leaves the suite knowingly red | M | H | Phase 1 bundles classifier + test in one phase and one commit. |
| Editing the classifier without the lockstep dry-run reporter change leaves a stale explanatory string claiming "single-task engine exits partial rather than dispatching" | M | M | Phase 2 is a dedicated lockstep phase gated on Phase 1, with an explicit grep verification for the stale wording. |
| A genuinely stuck base-mode partial task now spends up to `MAX_CYCLES` (5) real dispatches before exiting, instead of exiting on cycle 1 | L | H | Accepted, intentional cost of the fix. Flagged here so it is not later mistaken for a regression. Phase 6 confirms the bound holds. |
| The three tables drift again after this task | M | L | Phase 4 adds an explicit three-artifact agreement note (not just the existing script+table pair) and Phase 4's verification is a literal cross-artifact comparison. |
| Edits land in `.claude/` instead of the source store | H | L | Every phase names source-store paths only. Phase 6 regenerates `.claude/` from source and runs `verify-deploy.sh` to confirm parity. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`orchestrate-dry-run-report.sh` vs. `skill-orchestrate/SKILL.md`) and are parallel-safe. Phases 3
and 4 both edit `SKILL.md` and are therefore strictly sequential.

---

### Phase 1: Converge the classifier, its header table, and the regression test [COMPLETED]

**Goal**: Remove the engine fork so both engines emit `implement` for the `partial`-with-neither
row; bring the script's own header verdict table and schema documentation into agreement in the
same commit; update the regression test that asserts the removed behavior so the suite stays green.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`, replace the
      `partial`/neither branch's engine conditional (`(if $engine == "mt" then "implement" else
      "exit_partial" end)`) with the literal `"implement"`, collapsing the `$grp` binding if it
      becomes a pass-through. *(completed)*
- [x] Flatten that branch's `reason` string to a single engine-agnostic sentence (e.g. `"... is
      partial with neither continuation nor blockers; routes to implement"`), removing the
      `"mt routes to implement"` / `"single exits partial"` fork. *(completed)*
- [x] Leave the `handoff_state` computation in that branch untouched — it does not reference
      `$engine`. *(completed: unchanged)*
- [x] Rewrite the header's "Two-engine rationale" paragraph: it currently claims the
      `partial`-with-neither row is "the one row where the two engines genuinely diverge" and that
      the script "transcribes both engines verbatim rather than picking a winner". Both are now
      false for that row. State instead that the engines are unified on every row except `blocked`,
      and that the engine argument still exists because the two engines are selected by the same
      `len(task_numbers)` test the live path uses. *(completed)*
- [x] Update the header engine table: the `partial, neither` row's `single group` column becomes
      `implement`. *(completed)*
- [x] Add the Decision 1 justification adjacent to the header table's `blocked` row: solo
      invocations have no sibling to make progress on, so escalation is the only meaningful action;
      batch invocations skip so siblings proceed. Include the discriminator (this divergence is
      independently implemented by Stage 4's own unconditional-escalation `blocked` handler and
      Stage MT-4's table, not merely asserted here). *(completed)*
- [x] Apply Decision 2 to the header's `group` field enum documentation: keep `exit_partial` listed,
      annotated as reserved — defined but not currently emitted by any row, retained for schema
      stability and available to a future row or engine that wants an exit-without-dispatch verdict.
      Do not change the `orchestrate-triage-v1` identifier. *(completed)*
- [x] In `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh`, change the
      `expect_single` fixture-955 expectation from `exit_partial` to `implement` and drop the
      `(THE DIVERGENCE)` comment on that line. *(completed)*
- [x] Rewrite test case 3: it currently asserts `div_mt = implement && div_single = exit_partial`.
      Invert it into a convergence assertion (`div_mt = implement && div_single = implement`) and
      rename the case label and its pass/fail strings from engine *divergence* to engine
      *convergence* for the `partial`-with-neither row. *(completed)*
- [x] Leave the test's `blocked` expectations (`964`: `skip` under mt, `needs_human` under single)
      unchanged — Decision 1 keeps that divergence. Add a short comment on those lines noting the
      divergence is intentional and documented. *(completed)*
- [x] Update task 917's `file_scope` array in `specs/state.json` to add
      `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh`, then run
      `bash .claude/scripts/generate-todo.sh`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — remove engine fork in the
  `partial`/neither branch; rewrite header rationale paragraph, engine table row, `blocked`-row
  justification, and `group` enum annotation
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` — converge the
  fixture-955 single-engine expectation and rewrite test case 3
- `specs/state.json` — add the test file to task 917's `file_scope`

**Verification**:
- `bash specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` — all cases
  PASS, zero FAIL.
- `grep -n 'exit_partial' agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` —
  every remaining hit is documentation (header enum / reservation note); zero hits inside the jq
  program body.
- The header engine table's `partial, neither` row reads `implement | implement`.
- `grep -n 'orchestrate-triage-v1' ...` still shows the unbumped identifier.

---

### Phase 2: Lockstep-edit the dry-run reporter [COMPLETED]

**Goal**: Bring `orchestrate-dry-run-report.sh`'s hard-coded `exit_partial` exclusion arm and its
step-7 header comment into agreement with the converged classifier, per the task's explicit
requirement that this file be edited alongside the classifier rather than merely re-run against it.

**Tasks**:
- [x] Reword the `exit_partial)` `case` arm's explanatory string. It currently asserts
      "single-task engine exits partial rather than dispatching", which is now false. Replace with
      wording matching Decision 2 — a reserved verdict value not expected to be emitted, treated as
      an exclusion defensively if it ever is. *(completed)*
- [x] Keep the `case` arm itself (Decision 2: defensive code retained; removing it would let an
      unexpected group value fall through silently). *(completed: unchanged)*
- [x] Reword the step-7 line in the header "Composition" block that reads "`needs_human` and
      `exit_partial` become exclusions" so it no longer implies `exit_partial` is a live outcome of
      the classifier — state that it is excluded if ever emitted. *(completed)*
- [x] Confirm by grep that no other occurrence of `exit_partial` exists in the file (the "Report
      sections" documentation block was verified clean during research; re-confirm rather than
      assume). *(completed: 3 line-matches total across 2 locations — header comment and case arm,
      the case arm containing both the `exit_partial)` label and the reworded message text; no
      other locations found)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — step-7 header comment and
  the `exit_partial` `case` arm message

**Verification**:
- `grep -n 'exit_partial' agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` —
  exactly two hits (header comment, `case` arm), both with the new wording.
- `grep -n 'exits partial rather than dispatching' agent-system/extensions/core/scripts/` — zero
  hits repo-wide in the source store.
- `bash -n agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — parses clean.
- If `specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` exists, run it —
  all cases PASS (it does not reference `exit_partial`, so it should be unaffected; a failure here
  means the edit went beyond its intended scope).

---

### Phase 3: Rewrite Stage 4's no-handoff/no-blockers sub-state as an implement dispatch [COMPLETED]

**Goal**: Replace the unconditional exit with a real implement dispatch that sources resume context
from the prior dispatch's `.return-meta.json`, and delete the now-false cross-reference paragraph
asserting the engines diverge by design.

**Tasks**:
- [x] Delete the "Cross-reference" paragraph immediately above the `partial` sub-state block in
      `skills/skill-orchestrate/SKILL.md` — the one asserting the `single`-engine outcome is
      "intentionally different", that the engines "diverge by design", and citing "Decision D1 in
      this task's originating plan". Replace it with a short pointer stating that
      `scripts/orchestrate-triage-classify.sh single` is the executable form of the same rule and
      that both engines now agree on this row. *(completed)*
- [x] Replace the "Sub-state: no handoff, no blockers" branch body (currently two `echo`s and
      `EXIT (partial, cycle_count)`) with a dispatch that structurally mirrors the "Sub-state:
      continuation available" branch immediately above it. *(completed)*
- [x] Probe the prior dispatch's outcome for resume context, before the dispatch window is opened.
      *(completed)*
- [x] Document inline that `recovered=false` (exit 1) is the EXPECTED and non-fatal outcome here —
      a prior `partial`/`in_progress` status yields `recovered=false` with the JSON still on stdout.
      The probe supplies context (`.status`, `.artifact_path`, `.phases_completed`,
      `.phases_total`), never a success claim, and must never gate the dispatch. *(completed)*
- [x] Add the standard preflight and dispatch-window setup, in this order and after the probe:
      `skill_preflight_update "$task_number" "implement" "$session_id"`, then
      `dispatch_start_ts=$(date -u +%s)` and `dispatch_was_transport_error=false`. *(completed)*
- [x] Resolve `plan_path` with the same idiom the continuation branch uses
      (`ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1`). Add no missing-plan guard
      (see Non-Goals). *(completed)*
- [x] Specify the Agent tool invocation table: `subagent_type` = `$IMPLEMENT_AGENT`; `prompt` =
      "Resume implementation for task $task_number (no continuation handoff; resume context
      recovered from the prior dispatch's return metadata)" with the `. User focus: $focus_prompt`
      append rule; `context` = the continuation branch's context object minus `continuation_context`,
      plus a `resume_context` object carrying the probe's status/artifact/phase fields. *(completed)*
- [x] Carry over verbatim the "After the Agent tool returns" paragraph the sibling branches use
      (infra-failure discrimination, `dispatch_was_transport_error` rule, then fall through to the
      shared Stage 5 handoff read). *(completed)*
- [x] Remove the `EXIT (partial, cycle_count)` line entirely — the branch must fall through to
      Stage 5 and the outer loop. Add no replacement guard. *(completed)*
- [x] Add the Decision 1 justification as a short comment (one or two sentences, not a
      cross-reference paragraph) in the `#### State: blocked` handler: solo invocations have no
      sibling to make progress on, so escalation is the only meaningful action; batch invocations
      skip so siblings proceed. Note the handler is deliberately engine-unconditional. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 4 `partial`
  cross-reference paragraph, the "no handoff, no blockers" sub-state body, and the `blocked` handler
  justification comment

**Verification**:
- `grep -n 'intentionally different\|diverge by design\|Decision D1' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  — zero hits.
- `grep -n 'EXIT (partial, cycle_count)' ...` — zero hits (the generic Stage 7 `EXIT (partial)` on
  the MAX_CYCLES path is a different line and must remain).
- `grep -n 'prior_meta_probe_window' ...` — present; `grep -n 'dispatch_start_ts'` shows it is still
  bound only by `date -u +%s` immediately before each Agent call, never by the probe.
- The new sub-state block contains, in order: probe, `skill_preflight_update`, dispatch-window
  reset, plan-path resolution, Agent invocation table, post-return discrimination paragraph.
- Read the `blocked` handler and confirm the justification comment is present and that no engine
  conditional was introduced.

---

### Phase 4: Reconcile the Stage MT-4 table and audit three-way agreement [NOT STARTED]

**Goal**: Make the Stage MT-4 phase-grouping table's lockstep note cover all three artifacts rather
than only the script-plus-table pair, and verify that the classifier header table, Stage 4 prose,
and the MT-4 table now state identical routing.

**Tasks**:
- [ ] Confirm the MT-4 table's `partial` with no handoff row already reads `implement_tasks` — it
      does; `mt` was never the divergent side. No row value changes.
- [ ] Extend the table's preamble (which currently says the table and the script "MUST be changed
      together, never independently") to name all three artifacts that must agree: the classifier's
      header engine table, Stage 4's single-task `partial` sub-state prose, and this table.
- [ ] Add the Decision 1 justification to the MT-4 table's `blocked` row (which folds `blocked` into
      the generic skip row): batch mode skips so sibling tasks proceed; the single-task engine
      escalates because it has no siblings. Keep the wording consistent with the phrasing used in
      the classifier header and Stage 4.
- [ ] Audit all three artifacts side by side and confirm every row agrees.

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 phase-grouping table
  preamble and `blocked` row annotation

**Verification**:
- Produce a literal three-column comparison (classifier header table row / Stage 4 prose / MT-4
  table row) for each status and confirm agreement; record it in the phase's completion notes.
- `partial` with neither continuation nor blockers reads `implement` in all three.
- `blocked` reads `skip` for mt and `needs_human` for single in all three, each carrying the same
  justification.
- `grep -n 'MUST be changed together' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  — the surviving text names three artifacts, not two.

---

### Phase 5: Bring the state-machine doc and the entry-point contract into line [NOT STARTED]

**Goal**: Make `orchestrate-state-machine.md` describe the now-reachable resume path without
disturbing its exit-on-cycle-limit semantics (which are the target), and close the audit loop on
`commands/orchestrate.md`'s permissive-gate claim.

**Tasks**:
- [ ] In `docs/architecture/orchestrate-state-machine.md`, leave the
      `partial` (no handoff, cycle limit) row's `cycle_count >= MAX_CYCLES` condition and
      "Report state, exit" action unchanged — this is the target semantics the code is being brought
      up to, not something to edit.
- [ ] Add one clarifying sentence in the annotation prose beneath the state table stating that the
      `partial` no-handoff/no-blockers sub-state now dispatches `implement` on every cycle where
      budget remains, and that the cycle-limit row is reached through the same generic end-of-cycle
      check covering every other non-terminating row — not through a dedicated early exit.
- [ ] Adjust only the wording strictly needed for that clarification. Do not restructure the table.
- [ ] In `commands/orchestrate.md` CHECKPOINT 1, add a one-line strengthening to the permissive-gate
      prose confirming that `partial` with no handoff is included in "all non-terminal states"
      without exception. Do not weaken or qualify the existing claim — the fix makes it true.

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — one clarifying
  sentence in the post-table annotation prose
- `agent-system/extensions/core/commands/orchestrate.md` — one-line strengthening in CHECKPOINT 1's
  permissive-gate prose

**Verification**:
- The state table's `partial` (no handoff, cycle limit) row is byte-identical to its pre-change
  form; confirm with `git diff` on that file showing changes only in the prose block.
- The added sentence names both facts: dispatch-while-budget-remains, and cycle-limit-exit via the
  generic end-of-cycle check.
- `commands/orchestrate.md`'s CHECKPOINT 1 still asserts the permissive gate (not weakened) and now
  names the `partial`-no-handoff case explicitly.
- No task-number citations appear in any file touched by this phase (all are outside `specs/**`).

---

### Phase 6: Confirm the MAX_CYCLES bound, trace the acceptance criterion, redeploy [NOT STARTED]

**Goal**: Verify — without adding code — that the newly-reachable resume path is still bounded, walk
the acceptance criterion end to end, and confirm the deploy tree reflects the source store.

**Tasks**:
- [ ] Trace the loop for a task that starts `partial` with no handoff and no blockers and never
      produces a new handoff or a successful `.return-meta.json`: the outer
      `while [ "$cycle_count" -lt "$MAX_CYCLES" ]` admits the cycle, Stage 4 dispatches implement,
      Stage 5 reads no handoff and charges the cycle, and the loop repeats until the Stage 7
      `MAX_CYCLES reached` exit fires. Record the trace.
- [ ] Confirm explicitly that no new counter, guard, or gate was added anywhere in Phases 1-5 — the
      bound is the pre-existing loop condition plus the pre-existing Stage 7 exit.
- [ ] Confirm the infra-failure exemption path is unaffected: an infra-exempt cycle still does not
      increment `cycle_count`, and the `MAX_INFRA_FAILURES` cap still terminates it, leaving the
      documented worst case of `MAX_CYCLES + MAX_INFRA_FAILURES` iterations unchanged.
- [ ] Walk the acceptance criterion: with the converged classifier,
      `orchestrate-triage-classify.sh single <task>` for a `partial`/no-handoff/no-blockers task
      emits `group: "implement"`, and Stage 4's corresponding branch dispatches rather than exits.
- [ ] Regenerate the deploy tree from the source store: `bash .claude/scripts/deploy-headless.sh`
      (deliberate, explicit invocation).
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm source-to-deploy parity.
- [ ] Re-run `bash specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh`
      against the final tree.
- [ ] Confirm no edit in any phase landed under `.claude/` by inspecting the change set: every
      modified path is under `agent-system/extensions/core/` or `specs/`.

**Timing**: 1 hour

**Depends on**: 2, 5

**Files to modify**:
- None (verification and deploy regeneration only). `.claude/**` changes produced by
  `deploy-headless.sh` are regenerated artifacts, not authored edits.

**Verification**:
- The recorded trace shows exactly `MAX_CYCLES` dispatches then the Stage 7 exit for a
  never-progressing task.
- `verify-deploy.sh` exits 0.
- The regression suite exits with zero FAIL.
- `git status --short` shows no authored modifications under `.claude/` beyond regenerated deploy
  output.

---

## Testing & Validation

- [ ] `bash specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` — all
      cases PASS after Phase 1 and again after Phase 6.
- [ ] `bash specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` (if
      present) — all cases PASS after Phase 2.
- [ ] `bash -n` parses clean for both edited shell scripts.
- [ ] Classifier fixture check: `single` and `mt` emit identical `group` values for the
      `partial`-with-neither fixture; they still differ (by design, documented) for the `blocked`
      fixture.
- [ ] Three-way table agreement audit recorded in Phase 4.
- [ ] `grep -rn 'exit_partial' agent-system/extensions/core/` — hits only in documentation
      (classifier header enum/reservation note, dry-run reporter header + defensive `case` arm);
      zero hits in any jq program body or live routing decision.
- [ ] `grep -rn 'task [0-9]' ` over every file touched outside `specs/**` — zero task-number
      citations (no-task-references-in-deliverables rule).
- [ ] `verify-deploy.sh` exits 0.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (converged fork, rewritten
  header rationale, updated engine table, annotated `group` enum, `blocked`-row justification)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (reworded step-7 comment and
  `exit_partial` `case` arm)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 4 sub-state rewritten as a
  dispatch, cross-reference deleted, `blocked` justification added, Stage MT-4 preamble extended)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (clarifying sentence)
- `agent-system/extensions/core/commands/orchestrate.md` (permissive-gate strengthening)
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` (convergence
  assertions)
- `specs/state.json` (task 917 `file_scope` expansion) and regenerated `specs/TODO.md`
- `specs/917_converge_orchestrate_partial_triage_engines/summaries/01_converge-partial-triage-engines-summary.md`

## Rollback/Contingency

Each phase is a separate, independently revertable commit scoped to its named files. The riskiest
change is Phase 3 (Stage 4's new dispatch branch); reverting that single commit restores the
previous exit behavior while leaving the classifier convergence intact — which would reintroduce a
documented inconsistency, so Phase 1 and Phase 3 must be reverted together if a rollback is needed.

If the new dispatch branch proves to cycle unproductively in practice, the correct response is NOT
to restore the early exit (that is the defect being fixed) but to tune `MAX_CYCLES`, which already
bounds it, or to address why the implement dispatch makes no progress.

`.claude/` requires no rollback — it is a disposable deploy artifact regenerated from the source
store by `deploy-headless.sh`.
