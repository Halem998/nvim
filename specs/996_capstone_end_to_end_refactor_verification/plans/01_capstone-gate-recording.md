# Implementation Plan: Capstone acceptance gate — record findings and spawn follow-ups

- **Task**: 996 - Capstone: end-to-end verification of the refactored agent system
- **Status**: [COMPLETED]
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

### Phase 1: Confirm the two reproducibility-flagged DEPLOY defects [COMPLETED]

**Goal**: Establish whether the settings.local.json content-lossy merge and the
index.json/settings.json ordering non-determinism reproduce, so Phase 4 records them at an
evidenced severity rather than a single-observation one. Also re-confirm the orphan-file count.

**Tasks**:
- [x] Create a fresh scratch git repo under this session's scratchpad directory; seed it with a copy of the live `.claude-extensions.json`. Assert the target path is under the scratchpad and is not the repo root before proceeding. *(completed: `/tmp/claude-1000/.../scratchpad/deploy-test`, path-under-scratchpad and not-repo-root asserted before use)*
- [x] Run `deploy-headless.sh --wipe <scratch>` twice against the identical target, capturing both resulting `.claude/` trees separately. *(completed: ran 4 total wipes, 3 wipe-pairs, each exited 0)*
- [x] Diff the two trees. Record, per file: whether `context/index.json` differs beyond the `generated` timestamp; whether `settings.json` hook ordering differs; whether `settings.local.json` differs in *content* (a dropped block) versus ordering only. *(completed: index.json — raw diff shows entries relocated but `jq -S` semantic diff shows only the `generated` timestamp differs, i.e. object-key-order non-determinism only; settings.json — raw diff shows `permissions`/`hooks` blocks relocated but `jq -S` semantic diff is empty, i.e. key-order-only; settings.local.json — raw diff shows `mcpServers`/`hooks` blocks relocated but `jq -S` semantic diff is empty across all 3 pairs, i.e. ordering-only, NOT content-lossy in any of the 3 re-check pairs)*
- [x] Repeat the wipe-pair up to 3 times total, or stop early once the lossy settings.local.json difference has both occurred and not occurred. Record the observed rate as a fraction (e.g. "1 of 3 pairs"). *(completed: ran all 3 pairs (run1-2, run2-3, run3-4) since the lossy difference never occurred to trigger early stop. Observed content-loss reproduction rate: 0 of 3 pairs. All 3 pairs showed ordering-only differences, semantically identical under `jq -S`.)*
- [x] Diff the live deployed `.claude/` against one clean scratch regenerate; enumerate every file present live and absent from the regenerate. Confirm or correct the 4-file orphan list. *(completed: `comm -23` between live `.claude/` and the scratch regenerate found 4 orphans matching the claimed list exactly — `context/orchestration/orchestration-validation.md`, `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`, `docs/README.md` — plus two items correctly excluded from the orphan count: `context/repo/project-overview.md` (generated user content seeded by `/project-overview`, not declared in any extension's static `provides` file list, so its absence from a clean regenerate is by design) and two `tmp/workflow-active-*` session-lock files (session runtime state, not deploy content). The 4-file orphan list is CONFIRMED, not corrected.)*
- [x] Delete the scratch trees. *(completed: `rm -rf` on the scratch directory; confirmed via `find .claude -newermt '5 minutes ago'` that the only live-tree file touched during the phase window was this session's own `tmp/workflow-active-<session>` lock file, not written by any deploy test)*

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

### Phase 2: Establish and evidence the LIVE CYCLE blocking condition [COMPLETED]

**Goal**: Convert "the live cycle was not run" into an evidenced "the live cycle cannot run
cleanly until the handoff-location regex fix lands," so the gate's re-run condition is mechanical
rather than a judgement call.

**Tasks**:
- [x] Re-read `next_project_number` from `specs/state.json` and record it. Confirm it is >= 1000. *(completed: `jq '.next_project_number' specs/state.json` = 1007, >= 1000 confirmed)*
- [x] Re-read `hooks/validate-handoff-location.sh` and cite the regex verbatim plus the two consequences on a non-match: `exit 2`, and the `system-defect-record.sh --defect-class HANDOFF_MISLOCATED` call. *(completed: regex verbatim from `.claude/hooks/validate-handoff-location.sh` line 65: `(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$` — fixed-position `{3}` cannot match a 4-digit directory segment. On non-match the hook exits 2 with a MISPLACED diagnostic and invokes `system-defect-record.sh --defect-class HANDOFF_MISLOCATED`.)*
- [x] Confirm the hook is live: it is registered in the deployed `.claude/settings.json`, and its registration source is `agent-system/extensions/core/merge-sources/settings-hooks.json` (so this is a live wiring, not a deploy gap). *(completed: confirmed registered at `.claude/settings.json:73` (`"command": "bash .claude/hooks/validate-handoff-location.sh"`) and sourced from `agent-system/extensions/core/merge-sources/settings-hooks.json:49` — identical command string at both sites, confirming live wiring, not a deploy gap)*
- [x] Write the blocking argument explicitly: a scratch task created now is 4-digit; its handoff write cannot match the regex; the hook therefore emits a spurious `HANDOFF_MISLOCATED` system_defect; acceptance sub-item 3's negative test ("NO system_defect event on the clean run") is thereby structurally unpassable, independent of system health. *(completed, one paragraph: `next_project_number` is 1007, so any task created now to exercise a live `/orchestrate` cycle is numbered >= 1007 — a 4-digit directory segment. `validate-handoff-location.sh`'s regex requires exactly `[0-9]{3}` (three digits, fixed-position, no `{3,}` or `+` quantifier) between `specs/` and the trailing `_`, so a 4-digit segment structurally cannot match. Every `.orchestrator-handoff.json` write under such a task therefore trips the hook's non-match branch, which both exits 2 with a false MISPLACED diagnostic and unconditionally calls `system-defect-record.sh --defect-class HANDOFF_MISLOCATED`, emitting a `system_defect` event. Acceptance sub-item 3 requires "the system-defect recorder emits NO system_defect event on the clean run" as its negative test; because the emission above fires on every 4-digit task regardless of whether the orchestrated task itself completed cleanly, the negative test cannot pass for reasons wholly unrelated to system health. This is why LIVE CYCLE is recorded as BLOCKED rather than merely unattempted, and why it is gated specifically on `err_1786349061492_XpY38x` landing (the regex fix), not on any other defect in this batch.)*
- [x] Count the existing `system_defect` entries in `specs/events.jsonl` and record their dates and messages. Confirm whether the "deferred-defect surface renders empty" clause already fails on current state. *(completed: 3 pre-existing `system_defect` events, all dated 2026-08-08: (1) 18:15:29.205Z, task 953, `OFF_SCHEMA_STATUS` — "handoff dispatch_status '<empty>' is off-schema (writer emitted key 'dispatch_status' instead of 'status')"; (2) 20:49:35.840Z, task 983, `HANDOFF_STALE_OR_ABSENT` — "handoff mtime 1786220555 predates this dispatch window (1786220600)"; (3) 23:17:18.226Z, task 983, `HANDOFF_STALE_OR_ABSENT` — "handoff mtime 1786228557 predates dispatch window 1786228651; agent stalled mid-phase-10". All three attribute to `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`. The "deferred-defect surface renders empty" clause ALREADY FAILS on current state, independent of any new cycle — 3 events already populate the surface.)*
- [x] Record which of LIVE CYCLE's 4 sub-items are statically covered anyway: routing resolution is effectively verified by `lint-routing-wiring.sh` (verify-deploy.sh gate 7, PASS). *(completed: `verify-deploy.sh` gate 7 invokes `lint-routing-wiring.sh --verbose` and is one of the 22/23 passing gates per the research's live `--findings` run — the only failure is gate 8, the test-suite runner. Routing-resolution coverage for LIVE CYCLE is therefore already statically discharged by this passing gate, independent of running an actual `/orchestrate` cycle.)*

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

### Phase 3: Establish the gate-out auto-repair instrumentation gap [COMPLETED]

**Goal**: Evidence the claim that acceptance sub-item "gate-out reports zero format errors and
zero auto-repaired fields" is unverifiable as written, so Phase 4 can record it as a defect and
Phase 6 can state it as a criterion defect rather than a system failure.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/command-gate-out.sh` end to end. Record its line count and every occurrence of repair/format-error vocabulary. *(completed: 134 lines total. Only one related occurrence: line 131, comment `# Non-blocking artifact validation (link repair)`. No counter, aggregate, format-error, or auto-repair vocabulary elsewhere in the file.)*
- [x] Trace the actual repair path: `command-gate-out.sh` -> `skill_validate_task_artifacts` (in `skill-base.sh`) -> `validate-artifact.sh "$f" "$type" --fix 2>/dev/null`. *(completed: `skill_validate_task_artifacts()` in `agent-system/extensions/core/scripts/skill-base.sh` (line 402) iterates `reports/*.md`, `plans/*.md`, `summaries/*.md` and invokes exactly `bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null` (line 411) per file, discarding stderr and checking only the exit code.)*
- [x] Record `validate-artifact.sh`'s terminal accounting: the `[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining` line and its `exit 2`. *(completed: `validate-artifact.sh` line 280 emits `"[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining"` to stdout, then line 281 `exit 2`.)*
- [x] Record precisely what survives to the caller: the `[FIXED] N` line reaches stdout and is human-readable in a transcript; stderr is discarded; every non-zero exit collapses into one generic non-blocking WARNING; no counter, aggregate, event, or exit-code effect exists at the gate-out layer. *(completed: the `[FIXED] N` line is unredirected stdout, so it is visible in a transcript; `2>/dev/null` discards stderr; `skill_validate_task_artifacts`'s `if ! ... ; then echo "WARNING: ${type} artifact ${f} has format issues (non-blocking)."` collapses the exit-2 (and any other non-zero exit) into one generic message per file with no numeric detail carried forward; the function unconditionally `return 0`s, so `command-gate-out.sh` sees no exit-code signal at all from this step.)*
- [x] State the consequence in one sentence: there is no "gate-out reports" surface against which "zero auto-repaired fields" can be asserted or refuted, so the criterion is unverifiable as written — distinct from being verified-and-failing. *(completed: there is no counter, aggregate, logged event, or exit-code surface anywhere between `validate-artifact.sh`'s `[FIXED] N` line and `command-gate-out.sh`'s return, so the acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" has no reporting surface to assert or refute against — it is unverifiable as written, which is a distinct condition from being verified and found failing.)*
- [x] Note the secondary hazard for the record: `--fix` mutates the artifact in place, so a repair both happens and goes uncounted. *(completed: `--fix` is passed unconditionally in `skill_validate_task_artifacts`, so any auto-repair both mutates the artifact file in place AND goes uncounted at every layer above `validate-artifact.sh` itself — the repair is silent by construction, not merely unreported.)*

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

### Phase 4: Record every new defect in specs/errors.json [COMPLETED]

**Goal**: The plan's primary deliverable. Make the new findings durable via the sanctioned writer,
without duplicating the five already-recorded entries.

**Tasks**:
- [x] Read `specs/errors.json`. Confirm each of the five already-recorded ids is present. Scan every existing entry's `type` and `message` for near-duplicates of what this phase is about to append. *(completed: all 5 present; no near-duplicate `type` values found among the 5 pre-existing entries)*
- [x] Append, one `errors-append.sh append` invocation each, with `--session sess_1786342011_4592c8_996`, `--command /plan`, `--task 996`, `--checkpoint GATE_OUT`, and a `--suggested-action` naming the fix target path. *(completed: 5 invocations made. `deploy_merge_content_loss` recorded at severity **high** (Phase 1's re-check rate was 0 of 3, not the reproduce-at-all case, per the plan's own severity rule) with the 0-of-3 rate stated in the message -> `err_1786350581208_23mAsn`; `deploy_nondeterministic_merge` at **low** -> `err_1786350581240_JyztWt`; `deploy_orphan_files_undercounted` at **medium**, cross-referencing `err_1786349061556_LuKGif` -> `err_1786350581273_TAWj0I`; `test_suite_failure_undocumented` at **medium** -> `err_1786350581305_8cNAZ7`; `acceptance_criterion_not_instrumented` at **medium** -> `err_1786350581339_Q4VnFy`)*
- [x] After each append, capture the returned error id. *(completed: ids listed above, all captured from the script's stdout)*
- [x] Re-read `specs/errors.json` and confirm the document still parses, the new ids are present exactly once each, and no pre-existing entry was mutated. *(completed: `jq -e '.errors | length'` = 10 (5 pre-existing + 5 new), each new id retrievable exactly once, spot-checked `err_1786349061524_pY97cE`'s severity unchanged at `critical`)*

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

### Phase 5: Decide and create follow-up tasks [COMPLETED]

**Goal**: Decide, per defect, whether an errors.json entry alone suffices or a task must be
spawned — and create only those that clear the bar.

**Tasks**:
- [x] Read `specs/state.json`'s open tasks and `specs/errors.json` in full. Build the disposition table: for each of the ten confirmed defects (5 already-recorded + 5 new), record whether an open task already covers it. *(completed — disposition table below; only 3 non-terminal open tasks existed besides 996 itself: 1004, 1005, 1006, none of which cover any of the 10 defects)*

  | Defect (error id) | Open task covers it? | Disposition | Justification |
  |---|---|---|---|
  | `err_1786349061492_XpY38x` (hook regex) | No | **Spawn -> 1007** | Already firing falsely; blocks this gate's LIVE CYCLE scope; named target file exists |
  | `err_1786349061524_pY97cE` (MT session-id) | No | **Spawn -> 1008** | Fully blocks a documented capability; named target file exists |
  | `err_1786350581208_23mAsn` (deploy_merge_content_loss) | No | **Entry only** | Phase 1 re-check reproduced 0 of 3 — per the plan's own rule, non-reproduction gets entry-only with the rate stated (already done in the message) and a Phase 7 re-check step |
  | `err_1786350581273_TAWj0I` (deploy_orphan_files_undercounted) + `err_1786349061556_LuKGif` | No | **Spawn one task -> 1009, covering both ids** | Two ids, one decision (subtractive-detection vs. documented one-directional parity); do not split |
  | `err_1786350581305_8cNAZ7` (test_suite_failure_undocumented) | No (988, the prior run-all.sh consolidation task, is already completed/closed; no open run-all.sh task exists to fold into) | **Spawn -> 1010** | Named target file exists; nothing open to fold into |
  | `err_1786349061588_fqHbUZ` (defect vocabulary) | No | **Spawn -> 1011** | Three concrete instances now ground the new classes |
  | `err_1786350581240_JyztWt` (deploy_nondeterministic_merge) | No | **Entry only** | Low impact; noted to fold into whichever deploy task (1009) lands first |
  | `err_1786350581339_Q4VnFy` (acceptance_criterion_not_instrumented) | No | **Entry only** | Phase 7 (below) did not conclude the gate is unable to re-run without it — the re-run procedure can state the criterion as currently unverifiable rather than requiring new instrumentation before any re-run |
  | `err_1786344051474_RcIhk6` (delegation_interrupted) | N/A — prior interrupted dispatch, no active fix target | **Entry only (pre-existing, no action)** | Historical record, not a live structural defect requiring a task |

- [x] Apply the bar: spawn a task only when the fix is structural, has a named target file, and is not already covered by an open task. An entry alone suffices for a finding that is informational, already covered, or whose fix is a one-line change bundled into another task's scope. *(completed — bar applied per the table above: 5 spawned, 4 entry-only including the pre-existing delegation_interrupted record which needed no fresh disposition)*
- [x] Recommended dispositions, to be confirmed against the live disposition table rather than assumed. *(completed — live table above confirms all recommended dispositions except `deploy_merge_content_loss`, which resolved to the explicitly-anticipated `0 of N` entry-only branch since Phase 1 found 0 of 3 reproductions)*
- [x] Create the tasks that clear the bar, using the sanctioned creation path (never a hand-edit of `specs/state.json`). Each description must carry: the originating error id, the named target file, the SOURCE-STORE RULE, and the DELIVERABLE RULE. *(completed — 5 tasks created via `state-write.sh` following the exact schema `/task`'s Create Task Mode uses (prepend to `active_projects`, increment `next_project_number`, `--regen-todo`), never a hand-edit: task 1007 "fix_handoff_location_regex_4digit_tasks", 1008 "fix_orchestrate_mt_session_id_mismatch", 1009 "resolve_deploy_orphan_file_parity", 1010 "fix_opencode_gate_in_session_id_duplication", 1011 "expand_defect_class_vocabulary". Each description carries its originating error id(s), named target file(s), and both binding rules verbatim.)*
- [x] Add to each created task's description the constraint that it must not be driven by multi-task `/orchestrate` until `err_1786349061524_pY97cE` is fixed. *(completed — all 5 tasks (1007-1011) carry the CONSTRAINT text; 1007 and 1008 had it inline at creation, 1009/1010/1011 had it appended via a follow-up `state-write.sh` amendment after an initial gap was caught)*
- [x] Do NOT run `/orchestrate` on any task created here. *(completed — no `/orchestrate` invocation was made on 1007-1011 during this implementation)*
- [x] Regenerate `specs/TODO.md` from `specs/state.json` via `generate-todo.sh`. Never hand-edit TODO.md. *(completed — each `state-write.sh` call passed `--regen-todo`; `validate-state.sh --deep` confirms "TODO.md is in sync with specs/state.json (regenerated content is byte-identical)")*

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

### Phase 6: Write the dated closing-bookend review artifact [COMPLETED]

**Goal**: Satisfy the task's scope item 4 — record the results as a dated review artifact under
`specs/reviews/`, closing the bookend opened by `review-2026-07-29-agent-system.md`.

**Tasks**:
- [x] Read `specs/reviews/review-2026-07-29-agent-system.md` for structure and voice. Match its register: quantified first, tables over prose, no emojis. *(completed: register matched — opens with a plain verdict, tables over prose throughout, no emojis)*
- [x] Write `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md` containing all required sections. *(completed: file written with (1) plain-stated FAIL verdict and per-scope partition in Section 1, (2) full 6+4+4 sub-item accounting with explicit verdicts and evidence in Sections 2-4, (3) the CONDITIONAL parity item named explicitly with the `verify.lua`/`merge_index_entries()` mechanical reason in Section 2, (4) the UNVERIFIABLE-AS-WRITTEN gate-out item with the traced call path in Section 5, (5) the BLOCKED LIVE CYCLE scope with the full blocking argument in Section 4, (6) a defect ledger covering all 10 confirmed defects with error ids/severities/dispositions in Section 7, (7) the closing-bookend framing against the 2026-07-29 review's five root causes in Section 6, explicitly naming the parity and non-determinism findings as fresh "verification that silently passes" instances, (8) a "what this task deliberately did NOT do" section in Section 8)*
- [x] Reference durable anchors only: filenames, section headings, function names, error ids. This artifact lives under `specs/**`, so task numbers are permitted, but prefer the durable anchor where one exists. *(completed: durable anchors used throughout — file paths, function names, error ids, section headings; task numbers used only where they are the durable identifier, e.g. spawned task 1007-1011 references)*
- [x] Do not restate the research report. Link it and summarize its verdicts. *(completed: the closing References line links `specs/996_capstone_end_to_end_refactor_verification/reports/01_capstone-verification-findings.md` as the sole evidence base and summarizes rather than restates it)*

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

### Phase 7: Specify the gate re-run procedure [COMPLETED]

**Goal**: The task description says "the gate re-runs after the fix lands." Make that mechanical:
a reader must be able to determine, without judgement, whether the gate is ready to re-run and
exactly what to execute.

**Tasks**:
- [x] Write a **re-run precondition checklist** into the review artifact: the named, checkable conditions under which each currently-failing or blocked scope becomes re-runnable. *(completed: Section 9.1 of the review artifact, a table covering LIVE CYCLE (unblocks when task 1007's regex fix lands, with the exact negative-test verification method named), GATES `run-all.sh` (unblocks at `verify-deploy.sh --findings` 23/23), DEPLOY byte-identity (unblocks when two consecutive `--wipe` runs diff clean modulo the `generated` timestamp — and explicitly requires the ordering non-determinism fixed too, not only content-loss), DEPLOY parity CONDITIONAL, and the gate-out UNVERIFIABLE-AS-WRITTEN item)*
- [x] Write the **re-run command sequence** verbatim and copy-pasteable. *(completed: Section 9.2, a single bash block covering the 3 GATES commands at hardened defaults, `verify-deploy.sh --findings`, both `run-all.sh` copies named and run separately, and the full scratch wipe-pair procedure with `mktemp -d` and explicit non-repo-root scratch usage, plus a LIVE CYCLE stub gated on task 1007)*
- [x] State the **verdict rule**. *(completed: Section 9.3 — pass requires all 14 sub-items PASS, with the CONDITIONAL parity item requiring an explicit recorded decision (bidirectional check added and passing, or one-directional documented as intended) and the UNVERIFIABLE-AS-WRITTEN gate-out item requiring either instrumentation added and reporting zero, or the criterion amended and passing)*
- [x] Record that re-running the gate is a fresh task, not a re-open of this one. *(completed: stated explicitly in Section 9's opening sentence: "Re-running the gate is a fresh task, not a re-open of this one — this task's mandate ends at recording", and repeated in the verdict rule's closing sentence)*
- [x] If Phase 1 reported `0 of N` for the lossy merge, add an explicit re-check step to the procedure so a non-reproduction does not quietly become a non-finding. *(completed: Phase 1 reported 0 of 3. Section 2's "Decision on the content-loss non-reproduction" paragraph and Section 9.1's DEPLOY byte-identity row both point to the re-check requirement; the Section 9.2 command sequence's scratch wipe-pair block IS that re-check step, reusable verbatim for a future re-run)*

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
