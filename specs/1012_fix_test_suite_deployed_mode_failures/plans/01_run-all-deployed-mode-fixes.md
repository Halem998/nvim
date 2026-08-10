# Implementation Plan: Make run-all.sh green or justify every residual failure

- **Task**: 1012 - Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (one advisory overlap: the opencode session-id duplication task owns `test-common-lib.sh`)
- **Research Inputs**: specs/1012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md
- **Artifacts**: plans/01_run-all-deployed-mode-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`run-all.sh` measures 26 passed / 8 failed / 34 total in deployed mode. Five of the eight failures
share one root cause: a hardcoded five-level `REPO_ROOT` climb that is correct only from the
source-store test location and overshoots to `$HOME` from the deployed location. A sixth is an
unrelated test-fixture gap; a seventh is out of scope (owned by a concurrent sibling task); the
eighth is a newly discovered order-dependent flake with no diagnosed root cause. This plan
migrates `REPO_ROOT` resolution to the proven depth-independent pattern already in-tree, fixes the
fixture gap, refreshes the deployed tree, time-boxes a diagnostic pass on the flake, and closes
with an honest re-measurement plus a written, evidenced justification for every failure that
remains.

Definition of done: `run-all.sh` reports zero failures, **or** every residual failure carries a
written, evidenced justification recorded in the implementation summary. An unqualified "green"
claim is never acceptable — the measured counts are reported as measured.

### Research Integration

The research report's live re-measurement supersedes the task description's inherited numbers and
is the baseline this plan is written against:

- **Baseline**: 26 passed, 8 failed, 0 skipped, 34 total — stable across two full sequential runs.
- **`REPO_ROOT` defect confirmed in 5 suites**, not 2: `test-skill-base-lifecycle.sh`,
  `test-update-task-status.sh`, `test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`,
  `test-resume-scan-nonconformance.sh`. Eighteen source-store test files carry the same literal;
  thirteen are masked by a `$SCRIPT_DIR`-relative fallback candidate and are only accidentally
  safe.
- **Proven-good replacement pattern** (already in-tree, `test-deploy-propagation.sh`): resolve via
  `git rev-parse --show-toplevel` from `$SCRIPT_DIR`, retaining the five-level literal only as a
  non-git fallback. Do not invent a third pattern.
- **`test-index-entries-schema.sh`** is not a `REPO_ROOT` issue. Its fixture `manifest.json` omits
  `merge_targets.claudemd.source`, so `check_extension_md_length`'s manifest-authoritative guard
  short-circuits and Rule U never executes. `check-extension-docs.sh` itself needs no change.
- **`test-common-lib.sh`** is out of scope — the opencode session-id duplication is owned by a
  concurrent sibling task. Leave untouched.
- **`test-lint-state-writer-boundary.sh`** measured 8/8 green in five independent measurements.
  The earlier "7/8" report is stale. Leave untouched.
- **`test-four-tier-conflict.sh`** fails 2/2 inside the full sequence and passes 4/4 in isolation —
  an order/timing-dependent flake in a `task-lock.sh` fixture test (dead-pid probe plus a
  `holder.json.tmp` write race), root cause undiagnosed. Research recommends a dedicated diagnostic
  pass rather than a folded-in guess; this plan follows that recommendation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no `roadmap_flag` was set, so no
roadmap consultation was performed and no roadmap phases are included. `specs/ROADMAP.md` exists
but was deliberately not read under this plan's protocol.

## Goals & Non-Goals

**Goals**:
- Eliminate the `REPO_ROOT` depth defect as a **defect class**, not only in the five suites that
  fail loudly today — migrate every source-store test file carrying the literal to the proven
  depth-independent pattern.
- Restore Rule U coverage in `test-index-entries-schema.sh` by fixing its fixture manifest, so both
  the positive and the currently-vacuous negative assertion become meaningful.
- Refresh the deployed `.claude/` tree so deployed-mode `run-all.sh` actually exercises the fixed
  files, via a sanctioned deploy path only.
- Produce an honest, re-measured `run-all.sh` count and a written, evidenced justification for
  every residual failure.

**Non-Goals**:
- Fixing `test-common-lib.sh` or `.opencode/scripts/command-gate-in.sh` — owned by the concurrent
  sibling task.
- Touching `test-lint-state-writer-boundary.sh` — measured green, no current defect.
- Guaranteeing a fix for `test-four-tier-conflict.sh`. The diagnostic is time-boxed; "investigated
  and documented with evidence" is an accepted outcome for this suite.
- Hand-editing anything under `.claude/**`. That tree is a disposable deploy artifact; all edits
  land in `agent-system/extensions/**`.
- Changing `check-extension-docs.sh`'s manifest-authoritative design.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deployed-mode verification is impossible without a redeploy, and `deploy-headless.sh` is manual-only with exactly one sanctioned automated caller | H | H | Phase 4 encodes an explicit ladder of sanctioned paths and a non-mutating depth-3 scratch proof as fallback; if no sanctioned path is available the phase closes with an evidenced deferral, never a silent skip or a policy violation |
| Migrating 17 files touches more surface than the 5 failing suites strictly require | M | M | The change is mechanical and uses an already-proven in-tree pattern; the 13 masked suites keep their `$SCRIPT_DIR`-relative fallback candidates untouched, so their resolution behavior is unchanged either way. Phase 2 verifies each affected suite still passes |
| `test-four-tier-conflict.sh`'s flake may not reproduce inside a single diagnostic session | M | M | Time-box the diagnostic; the acceptance bar's "written, evidenced justification" branch is a pre-accepted outcome for this suite |
| Acting on `test-common-lib.sh` collides with the in-flight sibling task | H | L | Explicit non-goal; Phase 6 records it as a justified residual failure rather than fixing it |
| A `git rev-parse` failure in a non-git context silently changes resolution behavior | M | L | The fallback branch retains the exact existing five-level literal, so behavior in a non-git checkout is byte-identical to today |
| Source-store `run-all.sh` scans every extension, so its suite total will not equal the deployed total of 34 | L | H | Treat the two modes as separate measurements with separate counts; never compare their totals directly or present one as the other |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |
| 3 | 5 | 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 own disjoint file sets and
carry no shared-file conflicts.

---

### Phase 1: Migrate REPO_ROOT in the five confirmed-failing suites [COMPLETED]

**Goal**: Replace the fixed five-level `REPO_ROOT` climb with the depth-independent
`git rev-parse --show-toplevel` pattern in every suite research confirmed as failing in deployed
mode.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`'s `REPO_ROOT`
      block and reuse it verbatim (including its explanatory comment, adapted per file) *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` *(completed)*
- [x] Run each edited suite from its source-store location and confirm it still passes there *(completed: all 5 pass, 0 failed each)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 5 files are in this phase's scope, each containing exactly one
occurrence of the literal `REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"`. Confirm at
implementation time with
`grep -c 'SCRIPT_DIR/\.\./\.\./\.\./\.\./\.\.' <each file>` before editing and `grep -L
'git rev-parse --show-toplevel' <each file>` after; an occurrence count other than 1 in any file
means the hypothesis was wrong and the phase scope must be re-measured before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - REPO_ROOT resolution

**Verification**:
- Each of the 5 suites, run directly from `agent-system/extensions/core/scripts/tests/`, exits 0
- `grep -l 'git rev-parse --show-toplevel'` matches all 5 files
- The five-level literal survives in each file only inside the `if [[ -z "$REPO_ROOT" ]]` fallback
- Phase-close gate: the full source-store `run-all.sh` shows no new failures relative to its
  pre-phase measurement

---

### Phase 2: Migrate REPO_ROOT in the eleven latent suites [COMPLETED]

**Goal**: Eliminate the defect class rather than only its currently-loud instances, by migrating
the remaining suites that carry the same literal but are masked by a `$SCRIPT_DIR`-relative
fallback candidate.

**Tasks**:
- [x] Apply the same pattern in `test-corroborate-phase-counts.sh` *(completed)*
- [x] Apply the same pattern in `test-double-loading-check.sh` *(completed: this file's existing
      REPO_ROOT derivation was a manifest.json-probe dual-mode block rather than a bare literal, so
      the git-rev-parse resolution was placed first with that entire original block retained,
      unmodified, as the non-git fallback)*
- [x] Apply the same pattern in `test-errors-append.sh` *(completed)*
- [x] Apply the same pattern in `test-handoff-reader-parity.sh` *(completed)*
- [x] Apply the same pattern in `test-lint-postflight-boundary.sh` *(completed)*
- [x] Apply the same pattern in `test-lint-state-writer-boundary.sh` *(completed: re-confirmed 8/8
      green, matching the research report's baseline, not the stale 7/8)*
- [x] Apply the same pattern in `test-phase-heading-patterns.sh` *(completed)*
- [x] Apply the same pattern in `test-postflight-marker-schema.sh` *(completed)*
- [x] Apply the same pattern in `test-status-vocabulary.sh` *(completed)*
- [x] Apply the same pattern in `test-validate-handoff.sh` *(completed)*
- [x] Apply the same pattern in `test-validate-state.sh` *(completed)*
- [x] Leave each suite's existing candidate arrays and fallback ordering untouched — this phase
      changes only how `REPO_ROOT` itself is derived *(completed)*
- [x] Run all 11 suites from their source-store location and confirm each still passes *(completed:
      all 11 exit 0)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: 18 source-store test files carry the literal. Of those,
`test-deploy-propagation.sh` already uses the target pattern (its literal is the fallback branch)
and must NOT be edited; 5 belong to Phase 1; `test-index-entries-schema.sh` belongs to Phase 3.
That leaves exactly 11 for this phase. Confirm at implementation time with
`grep -rln 'SCRIPT_DIR/\.\./\.\./\.\./\.\./\.\.' agent-system/extensions/core/scripts/tests/`
(expect 18 before, 18 after — the literal persists as a fallback in every migrated file) and
`grep -rLn 'git rev-parse --show-toplevel'` over the same set (expect 17 before, 0 after). A count
mismatch means the file set changed since planning and must be re-derived before editing.

**Files to modify**: the 11 files enumerated in Tasks above, all under
`agent-system/extensions/core/scripts/tests/` - REPO_ROOT resolution only.

**Verification**:
- All 11 suites, run individually from the source-store location, exit 0 — in particular
  `test-lint-state-writer-boundary.sh` still reports 8/8, confirming no regression against its
  measured-green baseline
- `grep -rL 'git rev-parse --show-toplevel'` over all 18 literal-carrying files returns nothing
- Phase-close gate: the full source-store `run-all.sh` shows no new failures

---

### Phase 3: Fix the test-index-entries-schema.sh fixture manifest [COMPLETED]

**Goal**: Restore Rule U coverage by declaring `merge_targets.claudemd.source` in the suite's
fixture `manifest.json`, and migrate that file's `REPO_ROOT` for consistency with Phases 1-2.

**Tasks**:
- [x] Add `"merge_targets": {"claudemd": {"source": "EXTENSION.md"}}` to the fixture manifest
      heredoc in `test-index-entries-schema.sh` *(completed)*
- [x] Apply the `git rev-parse` REPO_ROOT pattern in the same file *(completed)*
- [x] Run the suite and confirm the Rule U positive case (61 lines) now fires *(completed)*
- [x] Confirm the Rule U negative case (60 lines) still stays silent — and that it now does so
      because the rule ran and correctly declined, not vacuously. Verify by asserting the 61-line
      case fires in the same run; a passing negative with a failing positive is the vacuous
      signature to watch for *(completed: both cases pass in the same run — 9 passed, 0 failed)*
- [x] Make no change to `check-extension-docs.sh` — its manifest-authoritative guard is correct
      by design *(completed: file untouched)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The suite writes exactly one fixture `manifest.json` (a single heredoc), and
both Rule U cases resolve against it. Confirm with
`grep -c 'FIXTURE/manifest.json' agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`
before editing; more than one write site means additional fixtures need the same key and the scope
must be widened.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` - fixture manifest
  gains `merge_targets.claudemd.source`; REPO_ROOT resolution migrated

**Verification**:
- The suite exits 0 with every assertion passing, including "Rule U fires on a 61-line
  EXTENSION.md"
- The Rule T assertions are unaffected (same pass count as before for that group)
- Phase-close gate: the full source-store `run-all.sh` shows no new failures

---

### Phase 4: Refresh the deployed tree and re-measure both modes [COMPLETED]

**Goal**: Get the fixed files into `.claude/scripts/tests/` through a sanctioned path only, then
produce a fresh measured count for both source-store and deployed mode.

**Constraint (binding)**: `deploy-headless.sh` is manual-by-default. Per
`context/patterns/regeneration-is-manual-only.md`, exactly one automated caller is sanctioned —
`skill-orchestrate`'s Stage MT-3 inter-cycle redeploy checkpoint — and that document explicitly
declines to license any other automated caller. The implementer MUST NOT invoke
`deploy-headless.sh` on its own authority, and MUST NOT use `--wipe` under any circumstance here.
Hand-copying files into `.claude/**` is likewise forbidden by the source-store/deploy boundary
rule.

**Tasks**:
- [x] Run the full source-store `run-all.sh` and record its measured counts verbatim (pass/fail/
      skip/total). Note explicitly that source-store mode scans every extension, so its total will
      not match the deployed total of 34 — record the two as separate measurements *(completed:
      37 passed, 0 failed, 0 skipped, 37 total)*
- [x] Establish deployed-depth correctness without a deploy: copy one migrated suite to an in-repo
      scratch path exactly three directories below the repo root (mirroring `.claude/scripts/tests/`
      depth, e.g. `specs/1012_fix_test_suite_deployed_mode_failures/scratch/`), run it there, and
      confirm it resolves the real repo root rather than `$HOME`. Delete the scratch copy afterward
      *(completed: test-skill-base-lifecycle.sh ran exit 0, 14 passed/0 failed, no $HOME-based path
      errors; scratch copy deleted)*
- [x] Obtain a redeploy through a sanctioned path, in this order of preference:
      (a) the orchestrator's inter-cycle redeploy checkpoint, if it fires on this task's
      `modified_files`; (b) an explicit operator action — the `<leader>al` picker's `[Reload All]`
      or a human-run `bash .claude/scripts/deploy-headless.sh` — requested and reported, not
      self-invoked *(completed: the inter-cycle redeploy checkpoint fired in a later cycle once
      the concurrent sibling dispatch's commits landed; `deploy-headless.sh` ran successfully (5
      extensions resynced), confirmed independently by byte-identical diffs between the
      source-store and deployed copies of all 18 files this task modified, and by the deployed
      copy of `task-lock.sh` carrying the `mkdir -p "$lock_dir"` fix)*
- [x] If a redeploy occurred: run the deployed `.claude/scripts/tests/run-all.sh` and record its
      measured counts verbatim *(completed: 34 passed, 0 failed, 0 skipped, 34 total — measured
      independently, twice, matching the team-lead's independently-reported count)*
- [ ] If no sanctioned redeploy is available: close this phase as `[BLOCKED]` with the reason
      recorded, carry the source-store green result plus the depth-3 scratch proof as the evidence
      of correctness, and state plainly in the summary that the deployed-mode count is
      unmeasured — never inferred, never presented as green *(not applicable: a sanctioned
      redeploy did occur)*

**Timing**: 45 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Verification**:
- Source-store `run-all.sh` measured counts recorded verbatim
- Depth-3 scratch run demonstrates repo-root resolution independent of directory depth
- Deployed `run-all.sh` measured counts recorded verbatim, or an explicit `[BLOCKED]` record naming
  why the redeploy could not be obtained through a sanctioned path
- No file under `.claude/**` was written by hand

---

### Phase 5: Diagnose the test-four-tier-conflict.sh order-dependent flake [COMPLETED WITH EXCLUSIONS]

**Goal**: Determine why `test-four-tier-conflict.sh` fails inside the full sequence but passes in
isolation, and either fix it or produce a written, evidenced justification for leaving it red.

**Time-box**: 1.5 hours of investigation. Reaching the box without a diagnosed root cause is an
accepted outcome and routes to the justification branch — it is not a failure of the phase.

**Tasks**:
- [x] Reproduce: run the full `run-all.sh` sequence and confirm the failure signature
      (`task-lock.sh` writing `.lock/holder.json.tmp`, "jq produced empty output", dead-pid probe
      resolving to 999999) *(completed: reproduced on the 3rd of 3 pre-fix full-sequence attempts)*
- [x] Confirm the isolation baseline: run the suite alone several times and record the pass count
      *(completed: pre-fix isolation was already reliably green — this suite's own docstring frames
      it as failing only inside the full sequence; post-fix isolation measured 5/5 green)*
- [ ] Bisect the ordering dependency: run the suite immediately after progressively larger prefixes
      of the preceding suites to identify the smallest preceding set that triggers the failure
      *(deviation: skipped — the root cause was identified directly by reading the failing suite's
      own fixture design (case 1's deliberate concurrent `rm -rf $lock_dir` releaser) rather than
      needing a bisection to locate it; the defect is a self-contained race inside
      `write_holder()`/`cmd_acquire`, not an inter-suite ordering dependency, so a bisection across
      preceding suites was not the applicable diagnostic once the mechanism was clear)*
- [x] Inspect `task-lock.sh`'s `holder.json.tmp` write path around the failing line for an
      unguarded assumption about the lock directory existing at write time *(completed: confirmed —
      see Phase 5 progress file objective 2 for the full mechanism)*
- [ ] Evaluate the dead-pid probe heuristic for PID-recycling sensitivity under accumulated load
      *(deviation: skipped — the dead-pid probe (`DEAD_PID=999999`, decremented until
      `kill -0` confirms no live process) is unrelated to the actual failure mechanism found; the
      "999999" appearing in the reproduced failure's INFO line is this probe's own informational
      fixture-build line, not part of the failure signature itself, and no evidence connects it to
      the write_holder race)*
- [x] If a root cause is established and the fix is small and evidenced: apply it in
      `agent-system/extensions/core/scripts/` (source store) and verify in both isolation and full
      sequence *(completed: `mkdir -p "$lock_dir" 2>/dev/null || true` added at the top of
      `write_holder()` in `task-lock.sh`; verified 5/5 isolation and 4/4 full-sequence runs green
      after the fix, versus an intermittent pre-fix failure)*
- [x] If no root cause is established within the time-box: write the evidence gathered (bisection
      result, reproduction rates, ruled-out hypotheses) for Phase 6's justification record. Do not
      apply a speculative fix *(not applicable: a root cause was established and fixed)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Ordering-dependency bisection across preceding suites | Root cause was identified directly from the failing suite's own fixture design rather than requiring a bisection; the defect is a self-contained concurrency race inside `write_holder()`, not a cross-suite ordering dependency | `test-four-tier-conflict.sh`'s case 1 fixture (lines 163-169) deliberately backgrounds a `rm -rf $lock_dir` releaser mid-retry-window; `cmd_acquire`'s stale-override/re-entry/missing-holder.json branches call `write_holder` without re-verifying `$lock_dir` exists immediately before the write, exactly reproducing the observed "No such file or directory" ERROR when raced against that releaser |
| Dead-pid probe heuristic evaluation | The probe's mechanism (`DEAD_PID=999999`, decremented until confirmed dead via `kill -0`) is unconnected to the actual failure; its appearance in the reproduced log is an unrelated informational fixture-build line, not a symptom | Reproduced failure log's `[INFO] Fixture built at ... (dead pid probe resolved to 999999)` line precedes and is independent of the `[FAIL] 1: Tier-2 resolving case` line that carries the actual defect signature |

**Timing**: 1.5 hours (time-boxed)

**Depends on**: 4

**Verification Tier**: full

**Verification**:
- Either: the suite passes both in isolation (repeated runs) and inside the full sequence, with the
  fix landing in the source store only
- Or: a written record naming the reproduction rate, the bisection result, and each hypothesis
  ruled out with its evidence

---

### Phase 6: Final gate, honest re-measurement, and residual-failure justification [PARTIAL]

**UPDATE (post-redeploy re-dispatch)**: the redeploy landed. `bash .claude/scripts/deploy-headless.sh`
ran successfully via the inter-cycle redeploy checkpoint once the sibling dispatch's commits
cleared; all 18 files this task modified (17 test suites + `task-lock.sh`) are confirmed
byte-identical between the source store and `.claude/`. Both modes were independently re-measured
post-redeploy: source-store `run-all.sh` 37 passed/0 failed/37 total, deployed `run-all.sh` 34
passed/0 failed/34 total — both clean, on two separate runs each. Phase 4 is now `[COMPLETED]`.

This phase stays `[PARTIAL]`, not `[COMPLETED]`, for one reason only: `bash
.claude/scripts/verify-deploy.sh` gate 8 (which internally re-runs source-store `run-all.sh`) was
reported by team-lead as failing intermittently post-redeploy (roughly 4 failures in 9
invocations), which is not explained by a clean direct `run-all.sh` measurement. This dispatch
diagnosed that flake (see the Residual-Failure section below) but could not reach a confirmed root
cause before being asked to checkpoint and stop; it is recorded as an evidenced residual with a
named leading suspect and a recommended next step, not as a resolved defect.

**Goal**: Run the full gate set, report the measured counts without qualification-free optimism,
and give every remaining failure a written, evidenced justification.

**Tasks**:
- [x] Run the full source-store `run-all.sh` and record measured counts verbatim *(completed:
      37 passed, 0 failed, 0 skipped, 37 total)*
- [x] Run the deployed `run-all.sh` and record measured counts verbatim (or restate the Phase 4
      `[BLOCKED]` record if the redeploy never happened) *(completed, post-redeploy re-measurement:
      34 passed, 0 failed, 0 skipped, 34 total, confirmed on two independent runs — supersedes the
      earlier interim 28/6/34 record, which is now stale)*
- [x] Run `bash .claude/scripts/verify-deploy.sh` and record the result of every gate, including
      the `check-task-references.sh` gate and the suite-discovery gate *(completed, post-redeploy:
      a single run measured 23/23 checks passing, including gate 8 (shell test suite runner);
      however gate 8 is independently reported (by team-lead) and partially corroborated by this
      dispatch's own smaller sample as INTERMITTENT — see the flake diagnosis below. Task-reference
      lint gate PASSED on every run)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm no new doc-lint failures
      *(completed: post-redeploy, the 18-file drift is gone; only the pre-existing, unrelated
      literature/zotero never-deployed advisory block remains)*
- [x] Write a residual-failure justification table in the implementation summary — one row per
      still-failing suite, with the reason and the evidence supporting it. `test-common-lib.sh` is
      expected here: justified as owned by the concurrent opencode session-id task, evidenced by
      its assertion output naming `.opencode/scripts/command-gate-in.sh` *(completed: see
      summaries/01_run-all-deployed-mode-fixes-summary.md; test-common-lib.sh in fact measured
      PASS in this task's deployed-mode run rather than needing the anticipated justification)*
- [x] State the final pass/fail/total counts as measured. If any failure remains, say so explicitly
      in the first sentence of the summary — never report an unqualified green *(completed)*
- [x] Confirm no deliverable outside `specs/**` gained a task-number reference *(completed: verified
      via verify-deploy.sh's task-reference lint gate plus a direct grep of every file touched)*

**Timing**: 45 minutes

**Depends on**: 5

**Verification Tier**: full

**Verification**:
- `run-all.sh` counts recorded verbatim for every mode that was measurable
- `verify-deploy.sh` gate results recorded
- Every residual failure has a row in the justification table with reason and evidence
- The summary's headline claim matches the measured numbers exactly

---

## Testing & Validation

- [x] Each of the 17 migrated suites passes when run individually from the source-store location
- [x] `test-lint-state-writer-boundary.sh` still reports 8/8 (no regression against its measured
      baseline)
- [x] `test-index-entries-schema.sh` passes with Rule U firing on the 61-line case
- [x] A depth-3 scratch run proves `REPO_ROOT` resolves to the real repo root independent of depth
- [x] Full source-store `run-all.sh`: counts recorded verbatim (37 passed, 0 failed, 37 total,
      post-redeploy)
- [x] Full deployed `run-all.sh`: counts recorded verbatim (34 passed, 0 failed, 34 total,
      post-redeploy, confirmed independently twice — supersedes the earlier `[BLOCKED]` record)
- [x] `verify-deploy.sh` gates recorded (23/23 passed on this dispatch's own runs post-redeploy;
      gate 8 specifically is reported elsewhere as intermittent — see the flake diagnosis in the
      implementation summary; not reproduced as a failure within this dispatch's own smaller sample)
- [x] `check-extension-docs.sh` shows no new failures (drift resolved by the redeploy; only the
      unrelated pre-existing literature advisories remain)
- [x] Zero hand-authored files under `.claude/**`
- [x] Zero task-number references in deliverables outside `specs/**`

## Artifacts & Outputs

- `specs/1012_fix_test_suite_deployed_mode_failures/plans/01_run-all-deployed-mode-fixes.md` (this file)
- `specs/1012_fix_test_suite_deployed_mode_failures/summaries/01_run-all-deployed-mode-fixes-summary.md`
  — including the residual-failure justification table
- 17 modified test files under `agent-system/extensions/core/scripts/tests/`
- Possibly `agent-system/extensions/core/scripts/task-lock.sh` or
  `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`, only if Phase 5 establishes a
  root cause
- A refreshed `.claude/` deploy tree (produced by a sanctioned redeploy, never hand-written)

## Rollback/Contingency

- Every edit is confined to the source store and is independently revertible per file. Reverting
  any single test file restores the exact prior five-level literal.
- The `REPO_ROOT` change is behavior-preserving in a non-git checkout: the fallback branch is the
  unmodified original expression.
- No deployed file is hand-edited, so a redeploy from the pre-change source store fully restores
  the prior deployed state.
- If Phase 2's broader migration causes an unexpected regression in a currently-green suite, revert
  that one file and record it as a reasoned exclusion — Phases 1 and 3 stand independently and do
  not depend on Phase 2.
- If Phase 5's investigation destabilizes anything, discard its working changes; the phase is
  explicitly permitted to end with documentation and no code change.
