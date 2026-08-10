# Implementation Plan: Capstone acceptance gate — record findings and spawn follow-ups

- **Task**: 996 - Capstone: end-to-end verification of the refactored agent system
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: 985, 986, 993, 995, 999
- **Research Inputs**: specs/996_capstone_end_to_end_refactor_verification/reports/01_capstone-verification-findings.md
- **Artifacts**: plans/01_capstone-gate-recording.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, errors-format.md, git-workflow.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a RECORDING plan, not a repair plan. The task's own description binds it: the capstone
"fixes nothing structural itself: any failure is recorded (errors.json entry and/or spawned
follow-up task) and the gate re-runs after the fix lands." The research dispatch already
live-executed the DEPLOY and GATES scope and confirmed all six batch leads plus four new defects.
What remains is to make those findings durable, decide their follow-up disposition, write the
closing-bookend review artifact the task's scope item 4 requires, and specify the mechanical
conditions under which the gate re-runs.

No phase in this plan edits `agent-system/**`, `.claude/**`, or `lua/**`. Every recommended
structural fix is handed off, never applied.

### The verdict

**The capstone acceptance gate FAILS.** It is not blocked as a whole — enough live evidence
exists to return a definitive verdict on two of three scopes — but the third scope is blocked and
one of its sub-items is unverifiable as written.

| Scope | Sub-items | Verdict |
|---|---|---|
| 1. DEPLOY | 6 | **FAIL.** 4 PASS; "byte-identical twice" FAILS in three forms (index.json key/array non-determinism, settings.json hook-array non-determinism, and a **content-lossy** settings.local.json merge that silently dropped a `hooks.PreToolUse` block and an `mcpServers` block between two identical runs); "declared-vs-deployed parity for EVERY `provides.*` category" is CONDITIONAL — it passes as implemented (one-directional) and fails under the bidirectional reading the word "parity" invites (4 orphan files present in the live tree, absent from a clean regenerate). |
| 2. GATES | 4 (+ verify-deploy.sh) | **FAIL.** `check-extension-docs.sh`, `validate-state.sh --deep`, and `check-task-references.sh` all PASS at hardened defaults with no env overrides. `tests/run-all.sh` green FAILS: 2 failures from the source-store copy, 7 from the deployed copy. `verify-deploy.sh --findings` reports 22/23, the single failure being the gate-8 test-suite runner. |
| 3. LIVE CYCLE | 4 | **BLOCKED**, with one sub-item additionally **UNVERIFIABLE-AS-WRITTEN.** See below. |
| 4. Review artifact | 1 | Not a verification item — it is this task's own deliverable, produced in Phase 6. |

**Why LIVE CYCLE is blocked, not merely unrun.** `specs/state.json`'s `next_project_number` is
1007, so any scratch task created to exercise a live cycle receives a 4-digit number.
`hooks/validate-handoff-location.sh` matches handoff paths against
`(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$` — a fixed-position `{3}` that
cannot match a 4-digit directory. On a 4-digit task the hook therefore (a) exits 2 with a false
MISPLACED diagnostic and (b) calls `system-defect-record.sh` with
`--defect-class HANDOFF_MISLOCATED`. That second effect is decisive: acceptance sub-item 3
requires "the system-defect recorder emits NO system_defect event on the clean run (the negative
test)". A spurious `HANDOFF_MISLOCATED` emission is structurally guaranteed on every 4-digit
task, so the negative test cannot pass for reasons entirely unrelated to what it is testing.
The live cycle is therefore gated on `err_1786349061492_XpY38x` landing.

Separately, the "deferred-defect surface renders empty" clause already fails on current state:
`specs/events.jsonl` carries 3 pre-existing `system_defect` events dated 2026-08-08, independent
of any new cycle.

**The unverifiable-as-written sub-item.** "Gate-out reports zero format errors and zero
auto-repaired fields" has no instrumentation to report against.
`agent-system/extensions/core/scripts/command-gate-out.sh` (134 lines) contains no counter,
aggregate, or exit-code surface for auto-repairs — its only related line is a comment,
`# Non-blocking artifact validation (link repair)`. The repair count exists one layer down, in
`validate-artifact.sh`'s terminal `[FIXED] $fixes field(s) auto-repaired` line (exit 2), but
`skill-base.sh`'s `skill_validate_task_artifacts` invokes it as
`validate-artifact.sh "$f" "$type" --fix 2>/dev/null` and collapses every non-zero exit into one
generic `WARNING: ... has format issues (non-blocking)`. The `[FIXED] N` line does reach stdout
and so is visible to a human reading a transcript, but nothing counts it, aggregates it, records
it, or lets it affect an exit code. There is no "gate-out reports" surface to assert zero
against. This is a fifth new defect — an acceptance-criterion instrumentation gap — and Phase 3
records it as such.

### Research Integration

The research report is the sole evidence base and every claim in this plan traces to it or to a
re-check named in a phase. Its two explicitly-flagged uncertainties are handled before recording,
not assumed: the settings.local.json lossy merge was observed once on a scratch repo and the
report itself recommends confirming reproducibility before spending fix effort (Phase 1), and the
research deliberately did not run a live cycle (Phase 2 establishes why it cannot yet be run
cleanly rather than attempting it).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

### Already recorded — do not duplicate

These five records exist and are durable. Reference them by id; never re-append them.

| Error id | Type | Severity |
|---|---|---|
| `err_1786349061492_XpY38x` | hook_regex_defect (`validate-handoff-location.sh` 3-digit regex) | high |
| `err_1786349061524_pY97cE` | lock_session_self_contention (`skill-orchestrate/SKILL.md` MT-1/MT-4 session-id mismatch) | critical |
| `err_1786349061556_LuKGif` | deploy_ghost_index_entries | medium |
| `err_1786349061588_fqHbUZ` | defect_vocabulary_gap | medium |
| `err_1786344051474_RcIhk6` | delegation_interrupted (prior interrupted dispatch) | — |

### Scope decision: writes outside `specs/996_*/`

This task's `file_scope` in `specs/state.json` is `null`. Following the convention prior tasks in
this batch used, the out-of-directory writes are declared here explicitly with reasons rather
than discovered at implementation time.

| Path | Writer | Reason |
|---|---|---|
| `specs/errors.json` | `.claude/scripts/errors-append.sh append` | The task description names "errors.json entry" as the sanctioned recording mechanism. Never hand-edited — the script holds `flock` across read/transform/validate/`mv` and validates the merged document. |
| `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` | Write | Scope item 4 requires the dated closing bookend under `specs/reviews/`, matching the opening `review-2026-07-29-agent-system.md`. |
| `specs/state.json`, `specs/TODO.md` | `/task`-equivalent creation path + `generate-todo.sh` | Only if Phase 5 decides to create follow-up tasks. The description sanctions "spawned follow-up task". `state.json` is never hand-edited. |

**Explicitly out of scope, no exceptions**: `agent-system/extensions/**`, `.claude/**`,
`lua/neotex/**`, `.opencode/**`, and every file named in any defect record. If a phase feels like
it wants to fix one of these, that is the signal it has left this task's mandate.

## Goals & Non-Goals

**Goals**:
- Make the four (five, counting the instrumentation gap) new defects durable in `specs/errors.json`.
- Establish and record why the LIVE CYCLE scope is blocked rather than merely unattempted.
- Decide the follow-up disposition of every confirmed defect — errors.json entry alone, or entry plus spawned task.
- Produce the dated `specs/reviews/` closing bookend with the explicit gate verdict.
- Specify a mechanical, copy-pasteable re-run procedure so the gate can be re-executed after fixes land.

**Non-Goals**:
- Fixing the handoff-location regex, the MT-1/MT-4 session-id mismatch, the orphan files, the merge non-determinism, the 7th `run-all.sh` failure, or the defect-class vocabulary gap. All are handed off.
- Adding auto-repair instrumentation to `command-gate-out.sh`. Recorded, not built.
- Re-running the DEPLOY and GATES scopes wholesale — the research already executed them live. Only the two reproducibility-flagged DEPLOY items are re-checked (Phase 1).
- Running a live `/orchestrate` cycle. Phase 2 establishes it cannot run cleanly yet.
- Modifying `specs/events.jsonl` or the 3 pre-existing `system_defect` events.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The settings.local.json lossy merge does not reproduce, and Phase 1 stalls trying to force it | M | M | Phase 1 is time-boxed at 3 wipe-pair runs. Non-reproduction is a RESULT, not a failure: Phase 4 records the entry either way with severity and message adjusted to state the observed reproduction rate. Recording must never be blocked on reproduction. |
| Scratch deploy test touches the live `.claude/` tree | H | L | `deploy-headless.sh --wipe TARGET` takes an explicit target; `global_extensions_dir` is hardcoded independent of TARGET, so a scratch git repo is a valid target. Run only under this session's scratchpad; assert the target path is not the repo root before invoking; never pass a bare `.` or the repo path. |
| Phase 5 creates follow-up tasks that duplicate the 5 already-recorded errors' eventual fix tasks | M | M | Phase 5 opens by reading `specs/errors.json` and `specs/state.json` and reconciling against the five recorded ids in the table above plus every open task title. Creation is a decision point with a written justification per task, not a default. |
| A newly-created follow-up task gets a 4-digit number whose handoff write trips the very regex defect being recorded | M | H | Expected and harmless for task *creation* (the hook fires only on `.orchestrator-handoff.json` writes, which creation does not perform). Phase 5 must not run `/orchestrate` on any task it creates. Note the constraint in each created task's description. |
| An implementer reads "verify the composed system" and starts fixing things | H | M | Every phase carries an explicit no-fix boundary; the scope-decision table above names the forbidden trees; Phase 7's re-run specification exists precisely so the fix work has an obvious home elsewhere. |
| Duplicate errors.json entries for the five already-recorded defects | M | M | Phase 4 greps `specs/errors.json` for each of the five ids and for near-duplicate `type` values before appending anything. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |
| 3 | 5 | 4 |
| 4 | 6 | 4, 5 |
| 5 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Confirm the two reproducibility-flagged DEPLOY defects [NOT STARTED]

**Goal**: Establish whether the settings.local.json content-lossy merge and the
index.json/settings.json ordering non-determinism reproduce, so Phase 4 records them at an
evidenced severity rather than a single-observation one. Also re-confirm the orphan-file count.

**Tasks**:
- [ ] Create a fresh scratch git repo under this session's scratchpad directory; seed it with a copy of the live `.claude-extensions.json`. Assert the target path is under the scratchpad and is not the repo root before proceeding.
- [ ] Run `deploy-headless.sh --wipe <scratch>` twice against the identical target, capturing both resulting `.claude/` trees separately.
- [ ] Diff the two trees. Record, per file: whether `context/index.json` differs beyond the `generated` timestamp; whether `settings.json` hook ordering differs; whether `settings.local.json` differs in *content* (a dropped block) versus ordering only.
- [ ] Repeat the wipe-pair up to 3 times total, or stop early once the lossy settings.local.json difference has both occurred and not occurred. Record the observed rate as a fraction (e.g. "1 of 3 pairs").
- [ ] Diff the live deployed `.claude/` against one clean scratch regenerate; enumerate every file present live and absent from the regenerate. Confirm or correct the 4-file orphan list.
- [ ] Delete the scratch trees.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research asserts (a) exactly 4 orphan files
(`context/orchestration/orchestration-validation.md`, `context/orchestration/subagent-validation.md`,
`docs/architecture/architecture-spec.md`, `docs/README.md`), and (b) that the settings.local.json
difference is content-lossy rather than ordering-only. Both are hypotheses from a single
observation. Confirm by the diff procedure above; if the orphan count differs, the corrected list
is what Phase 4 and Phase 6 record. Do not carry the number 4 forward unverified.

**Files to modify**:
- None in the repository. Scratch trees only, under the session scratchpad, deleted at phase end.

**Verification**:
- Both wipe runs exited 0 and produced a `.claude/` tree.
- A written per-file diff verdict exists for `context/index.json`, `settings.json`, and `settings.local.json`.
- The lossy-merge reproduction rate is stated as an explicit fraction, including `0 of N` if it did not reproduce.
- The orphan-file list is confirmed or corrected, with the live-vs-regenerate diff as evidence.
- No file under the live `.claude/` tree has an mtime later than the phase start.

---

### Phase 2: Establish and evidence the LIVE CYCLE blocking condition [NOT STARTED]

**Goal**: Convert "the live cycle was not run" into an evidenced "the live cycle cannot run
cleanly until the handoff-location regex fix lands," so the gate's re-run condition is mechanical
rather than a judgement call.

**Tasks**:
- [ ] Re-read `next_project_number` from `specs/state.json` and record it. Confirm it is >= 1000.
- [ ] Re-read `hooks/validate-handoff-location.sh` and cite the regex verbatim plus the two consequences on a non-match: `exit 2`, and the `system-defect-record.sh --defect-class HANDOFF_MISLOCATED` call.
- [ ] Confirm the hook is live: it is registered in the deployed `.claude/settings.json`, and its registration source is `agent-system/extensions/core/merge-sources/settings-hooks.json` (so this is a live wiring, not a deploy gap).
- [ ] Write the blocking argument explicitly: a scratch task created now is 4-digit; its handoff write cannot match the regex; the hook therefore emits a spurious `HANDOFF_MISLOCATED` system_defect; acceptance sub-item 3's negative test ("NO system_defect event on the clean run") is thereby structurally unpassable, independent of system health.
- [ ] Count the existing `system_defect` entries in `specs/events.jsonl` and record their dates and messages. Confirm whether the "deferred-defect surface renders empty" clause already fails on current state.
- [ ] Record which of LIVE CYCLE's 4 sub-items are statically covered anyway: routing resolution is effectively verified by `lint-routing-wiring.sh` (verify-deploy.sh gate 7, PASS).

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that exactly 3 pre-existing `system_defect` events exist
in `specs/events.jsonl` and that `next_project_number` is 1007. Both are point-in-time reads that
may have moved. Re-read both at implementation time and use the observed values; the argument
holds for any `next_project_number >= 1000` and any event count `>= 1`, so a changed number does
not change the conclusion — but the recorded figures must be the observed ones.

**Files to modify**:
- None. Read-only investigation; its output feeds Phases 4 and 6.

**Verification**:
- `next_project_number` recorded with its observed value and confirmed `>= 1000`.
- The regex quoted verbatim from the hook, with both non-match consequences named.
- The hook's live registration confirmed in the deployed settings and traced to its source-store merge source.
- The `system_defect` event count and dates recorded.
- A written, one-paragraph blocking argument exists that a reader can check without re-deriving it.

---

### Phase 3: Establish the gate-out auto-repair instrumentation gap [NOT STARTED]

**Goal**: Evidence the claim that acceptance sub-item "gate-out reports zero format errors and
zero auto-repaired fields" is unverifiable as written, so Phase 4 can record it as a defect and
Phase 6 can state it as a criterion defect rather than a system failure.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/command-gate-out.sh` end to end. Record its line count and every occurrence of repair/format-error vocabulary.
- [ ] Trace the actual repair path: `command-gate-out.sh` -> `skill_validate_task_artifacts` (in `skill-base.sh`) -> `validate-artifact.sh "$f" "$type" --fix 2>/dev/null`.
- [ ] Record `validate-artifact.sh`'s terminal accounting: the `[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining` line and its `exit 2`.
- [ ] Record precisely what survives to the caller: the `[FIXED] N` line reaches stdout and is human-readable in a transcript; stderr is discarded; every non-zero exit collapses into one generic non-blocking WARNING; no counter, aggregate, event, or exit-code effect exists at the gate-out layer.
- [ ] State the consequence in one sentence: there is no "gate-out reports" surface against which "zero auto-repaired fields" can be asserted or refuted, so the criterion is unverifiable as written — distinct from being verified-and-failing.
- [ ] Note the secondary hazard for the record: `--fix` mutates the artifact in place, so a repair both happens and goes uncounted.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- None. Read-only; its output feeds Phases 4 and 6.

**Verification**:
- The three-hop call path is traced with the exact invocation string at each hop.
- The `[FIXED]`/exit-2 accounting is quoted from `validate-artifact.sh`.
- A one-sentence statement of the consequence exists, distinguishing unverifiable-as-written from verified-and-failing.

---

### Phase 4: Record every new defect in specs/errors.json [NOT STARTED]

**Goal**: The plan's primary deliverable. Make the new findings durable via the sanctioned writer,
without duplicating the five already-recorded entries.

**Tasks**:
- [ ] Read `specs/errors.json`. Confirm each of the five already-recorded ids is present. Scan every existing entry's `type` and `message` for near-duplicates of what this phase is about to append.
- [ ] Append, one `errors-append.sh append` invocation each, with `--session sess_1786342011_4592c8_996`, `--command /plan`, `--task 996`, `--checkpoint GATE_OUT`, and a `--suggested-action` naming the fix target path:
  - `deploy_merge_content_loss` — severity per Phase 1's reproduction rate (**critical** if it reproduced at all; **high** with the rate stated in the message if `0 of N`). Message: two consecutive identical `--wipe` runs produced `settings.local.json` differing by a whole dropped `hooks.PreToolUse` block and an `mcpServers` block, with no error surfaced. This is the most consequential new finding: a routine redeploy can silently drop a hook or MCP registration.
  - `deploy_nondeterministic_merge` — **low**. Message: `context/index.json` and `settings.json` differ in key and array order between two identical `--wipe` runs, beyond the expected `generated` timestamp. Harmless to JSON consumers today; defeats any future byte-identical-diff verification.
  - `deploy_orphan_files_undercounted` — **medium**. Message: the live tree carries the Phase-1-confirmed orphan list, two of which (`docs/architecture/architecture-spec.md`, `docs/README.md`) were not named by the existing `err_1786349061556_LuKGif`. Cross-reference that id in the message; this entry extends it, it does not replace it.
  - `test_suite_failure_undocumented` — **medium**. Message: `run-all.sh` has a 7th, previously unreported deployed-mode failure, `test-common-lib.sh`, flagging `.opencode/scripts/command-gate-in.sh` for an inline `sess_$(date +%s)_...` generator duplicating `lib/common.sh`'s canonical one. Passes in source-store mode, fails only deployed.
  - `acceptance_criterion_not_instrumented` — **medium**. Message: Phase 3's finding — the "zero auto-repaired fields" acceptance criterion has no reporting surface in `command-gate-out.sh`.
- [ ] After each append, capture the returned error id.
- [ ] Re-read `specs/errors.json` and confirm the document still parses, the new ids are present exactly once each, and no pre-existing entry was mutated.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly 5 new entries. If Phase 1 disconfirms a defect
outright (for example the orphan list turns out empty on a clean re-diff), that entry is dropped
and the drop is recorded with its evidence in Phase 6's review artifact — do not append an entry
for a finding Phase 1 refuted, and do not silently reduce the count without recording why.

**Files to modify**:
- `specs/errors.json` — five appended records, via `errors-append.sh` only. Never hand-edited.

**Verification**:
- `jq -e '.errors | length' specs/errors.json` succeeds and the count increased by exactly the number of appends performed.
- Each new id is retrievable by `jq` and carries all seven required fields.
- The five pre-existing ids are still present and byte-unchanged.
- No entry duplicates an existing `type` + target combination.

---

### Phase 5: Decide and create follow-up tasks [NOT STARTED]

**Goal**: Decide, per defect, whether an errors.json entry alone suffices or a task must be
spawned — and create only those that clear the bar.

**Tasks**:
- [ ] Read `specs/state.json`'s open tasks and `specs/errors.json` in full. Build the disposition table: for each of the ten confirmed defects (5 already-recorded + 5 new), record whether an open task already covers it.
- [ ] Apply the bar: spawn a task only when the fix is structural, has a named target file, and is not already covered by an open task. An entry alone suffices for a finding that is informational, already covered, or whose fix is a one-line change bundled into another task's scope.
- [ ] Recommended dispositions, to be confirmed against the live disposition table rather than assumed:
  - `err_1786349061492_XpY38x` (regex) — **spawn, highest priority**. It is already firing falsely, and it blocks this very gate's LIVE CYCLE scope. Target: `agent-system/extensions/core/hooks/validate-handoff-location.sh`.
  - `err_1786349061524_pY97cE` (MT session-id) — **spawn**. Fully blocks multi-task `/orchestrate`, a documented capability. Target: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, one of the two ID-construction sites.
  - `deploy_merge_content_loss` — **spawn** if Phase 1 reproduced it; **entry only** if `0 of N`, with a re-check noted in Phase 7's re-run procedure.
  - `deploy_orphan_files_undercounted` + `err_1786349061556_LuKGif` — **spawn one task covering both**: either add a subtractive/orphan-detection pass, or decide and document that parity is one-directional by design. Do not spawn two tasks for one decision.
  - `test_suite_failure_undocumented` — **spawn or fold into an existing `run-all.sh` task** if one is open (the batch already recorded a REPO_ROOT path-depth follow-up; prefer folding).
  - `err_1786349061588_fqHbUZ` (defect vocabulary) — **spawn**. Three concrete instances now exist to ground the new classes: lock/session contention, hook-regex/path-depth boundary, deploy orphan drift.
  - `deploy_nondeterministic_merge` — **entry only**. Low impact; fold into whichever deploy task lands first.
  - `acceptance_criterion_not_instrumented` — **entry only**, unless Phase 7 concludes the gate cannot be re-run without it, in which case spawn.
- [ ] Create the tasks that clear the bar, using the sanctioned creation path (never a hand-edit of `specs/state.json`). Each description must carry: the originating error id, the named target file, the SOURCE-STORE RULE, and the DELIVERABLE RULE.
- [ ] Add to each created task's description the constraint that it must not be driven by multi-task `/orchestrate` until `err_1786349061524_pY97cE` is fixed.
- [ ] Do NOT run `/orchestrate` on any task created here.
- [ ] Regenerate `specs/TODO.md` from `specs/state.json` via `generate-todo.sh`. Never hand-edit TODO.md.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: The recommended dispositions above imply roughly 4-5 spawned tasks. That is
a plan-time estimate, not a target. The live disposition table governs: if an open task already
covers a defect, fold rather than spawn, and record the fold. Neither hitting nor missing the
estimate is itself a finding — an unjustified spawn is.

**Files to modify**:
- `specs/state.json` — new task entries, via the sanctioned creation path only.
- `specs/TODO.md` — regenerated, never hand-edited.

**Verification**:
- A written disposition table covers all ten confirmed defects with a spawn/entry-only verdict and a one-line justification each.
- `bash .claude/scripts/validate-state.sh --deep` exits 0 after creation (no dangling or cyclic dependencies introduced).
- Every created task's description contains its originating error id, its target file, and both binding rules.
- `specs/TODO.md` matches `specs/state.json` (regenerated, not edited).
- No task was created for a defect an open task already covers.

---

### Phase 6: Write the dated closing-bookend review artifact [NOT STARTED]

**Goal**: Satisfy the task's scope item 4 — record the results as a dated review artifact under
`specs/reviews/`, closing the bookend opened by `review-2026-07-29-agent-system.md`.

**Tasks**:
- [ ] Read `specs/reviews/review-2026-07-29-agent-system.md` for structure and voice. Match its register: quantified first, tables over prose, no emojis.
- [ ] Write `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` containing:
  - The **verdict**, stated plainly in the opening: the capstone acceptance gate FAILS, with the per-scope partition from this plan's Overview table.
  - Per-scope sub-item accounting: DEPLOY 6, GATES 4 plus `verify-deploy.sh` 22/23, LIVE CYCLE 4 — each marked PASS / FAIL / CONDITIONAL / BLOCKED / UNVERIFIABLE-AS-WRITTEN, each with its evidence.
  - The one CONDITIONAL called out explicitly: "declared-vs-deployed parity" passes as implemented (one-directional) and fails bidirectionally. Name the mechanical reason — `verify.lua`'s result shape has no `extra`/`orphan` field and only ever iterates the declared side; `install-extension.sh`'s `merge_index_entries()` is purely additive with no stale-removal step.
  - The one UNVERIFIABLE-AS-WRITTEN sub-item, with Phase 3's traced call path.
  - The BLOCKED scope with Phase 2's blocking argument.
  - A defect ledger: all ten confirmed defects with their error ids, severities, and Phase 5 dispositions.
  - The closing-bookend framing against the opening review: which of that review's five root causes this refactor batch addressed, and which the capstone's findings show still live. The one-directional-parity and non-deterministic-merge findings are fresh instances of its "verification that silently passes" root cause; say so.
  - A short section stating what this task deliberately did NOT do and why, so a future reader does not mistake the absence of fixes for an oversight.
- [ ] Reference durable anchors only: filenames, section headings, function names, error ids. This artifact lives under `specs/**`, so task numbers are permitted, but prefer the durable anchor where one exists.
- [ ] Do not restate the research report. Link it and summarize its verdicts.

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: prose

**Files to modify**:
- `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` — new file.

**Verification**:
- The file exists, is non-empty, and opens with an unambiguous verdict sentence.
- All 14 verification sub-items (DEPLOY 6 + GATES 4 + LIVE CYCLE 4) appear with an explicit verdict each; none is silently omitted.
- Every defect in the ledger carries a real error id retrievable from `specs/errors.json`.
- Every Phase 5 disposition is reflected.
- No emojis; no fix was applied by this phase.

---

### Phase 7: Specify the gate re-run procedure [NOT STARTED]

**Goal**: The task description says "the gate re-runs after the fix lands." Make that mechanical:
a reader must be able to determine, without judgement, whether the gate is ready to re-run and
exactly what to execute.

**Tasks**:
- [ ] Write a **re-run precondition checklist** into the review artifact: the named, checkable conditions under which each currently-failing or blocked scope becomes re-runnable. At minimum: LIVE CYCLE unblocks when `validate-handoff-location.sh` matches 4-digit task directories (verify by writing a handoff under a 4-digit scratch task dir and confirming no `HANDOFF_MISLOCATED` event is emitted); GATES passes when `verify-deploy.sh --findings` reports 23/23; DEPLOY's byte-identity item passes when two consecutive `--wipe` runs diff clean modulo the `generated` timestamp.
- [ ] Write the **re-run command sequence** verbatim and copy-pasteable: the four gate commands at hardened defaults with no env overrides, `verify-deploy.sh --findings`, both `run-all.sh` copies (source-store and deployed, reported separately — their failure sets differ), and the scratch wipe-pair procedure.
- [ ] State the **verdict rule**: the capstone passes only when all 14 sub-items are PASS, with the CONDITIONAL parity item resolved by an explicit recorded decision (bidirectional check added, or one-directional documented as intended) rather than left ambiguous, and the UNVERIFIABLE-AS-WRITTEN item resolved either by instrumenting the counter or by amending the criterion to something checkable.
- [ ] Record that re-running the gate is a fresh task, not a re-open of this one: this task's mandate ends at recording.
- [ ] If Phase 1 reported `0 of N` for the lossy merge, add an explicit re-check step to the procedure so a non-reproduction does not quietly become a non-finding.

**Timing**: 45 minutes

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:
- `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` — appended re-run section.

**Verification**:
- Every currently-failing or blocked sub-item has a named, checkable unblock precondition.
- The command sequence is copy-pasteable and names both `run-all.sh` copies separately.
- The pass rule states what to do with the CONDITIONAL and UNVERIFIABLE items rather than leaving them undefined.

---

## Testing & Validation

- [ ] `jq -e . specs/errors.json` parses; the five pre-existing ids are intact and unmutated.
- [ ] Every new error id is retrievable and carries all seven required fields (`id`, `timestamp`, `type`, `severity`, `message`, `context`, `fix_status`).
- [ ] `bash .claude/scripts/validate-state.sh --deep` exits 0 after any task creation in Phase 5.
- [ ] `specs/TODO.md` is regenerated from `specs/state.json`, never hand-edited.
- [ ] `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` exists and covers all 14 verification sub-items with an explicit verdict each.
- [ ] `git status --short` shows changes confined to `specs/errors.json`, `specs/state.json`, `specs/TODO.md`, `specs/reviews/`, and `specs/996_capstone_end_to_end_refactor_verification/`. **Any change under `agent-system/**`, `.claude/**`, `lua/**`, or `.opencode/**` is a scope violation and must be reverted before the task closes.**
- [ ] `bash .claude/scripts/check-task-references.sh` still exits 0 (no task-number citations leaked into a deliverable outside `specs/**`).
- [ ] The live `.claude/` tree is unchanged: no file under it has an mtime later than the task start.

## Artifacts & Outputs

- `specs/996_capstone_end_to_end_refactor_verification/plans/01_capstone-gate-recording.md` (this file)
- `specs/996_capstone_end_to_end_refactor_verification/summaries/01_capstone-gate-recording-summary.md`
- `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` — the dated closing bookend
- Up to 5 new `specs/errors.json` records
- 0-5 new follow-up task entries in `specs/state.json`, with `specs/TODO.md` regenerated

## Rollback/Contingency

- **errors.json**: `errors-append.sh` holds `flock` across the whole read/transform/validate/`mv` sequence and validates the merged document before the `mv`; on failure the original is untouched. A wrongly-appended record is corrected via `errors-append.sh update --fix-status`, never by hand-editing or deleting the array element.
- **Spawned tasks**: an unwanted task is retired via `/task --abandon N`, not by deleting its `state.json` entry.
- **Review artifact**: a new file; `git rm` reverts it cleanly.
- **Scratch deploy trees**: live outside the repo under the session scratchpad and are deleted in Phase 1. Nothing to roll back.
- **Global**: this task writes only under `specs/**`. A `git checkout` of `specs/` restores everything, and no structural repository state can be damaged by any phase — which is the point of the no-fix mandate.
