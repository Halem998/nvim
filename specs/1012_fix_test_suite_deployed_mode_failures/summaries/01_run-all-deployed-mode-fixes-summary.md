# Implementation Summary: Make run-all.sh green or justify every residual failure

- **Task**: 1012 - Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
- **Status**: [PARTIAL]
- **Started**: 2026-08-10T17:00:00Z
- **Last updated**: 2026-08-10T18:12:00Z (post-redeploy re-dispatch; one residual remains — see below)
- **Effort**: ~3.5 hours total across dispatches
- **Dependencies**: None (one advisory overlap: the opencode session-id duplication task owns `test-common-lib.sh`)
- **Artifacts**: plans/01_run-all-deployed-mode-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

**Not an unqualified green.** The redeploy this summary was previously waiting on has landed:
`bash .claude/scripts/deploy-headless.sh` ran successfully via the inter-cycle redeploy checkpoint,
and both modes now measure clean when run directly — source-store `run-all.sh`: 37 passed, 0
failed, 37 total; deployed `run-all.sh`: 34 passed, 0 failed, 34 total — each independently
confirmed on two separate runs in this dispatch, matching team-lead's own independent measurement.
Phases 1-5 are complete and verified; Phase 4 (redeploy + re-measurement) is now `[COMPLETED]`.

**One residual remains, and it is NOT one of this task's own fixes regressing.** Team-lead reports
`bash .claude/scripts/verify-deploy.sh` gate 8 (which internally re-runs source-store `run-all.sh`)
failing intermittently post-redeploy — roughly 4 failures in 9 invocations — even though `run-all.sh`
run directly passes consistently. This dispatch attempted to reproduce and diagnose that flake but
was asked to checkpoint findings to disk and stop before reaching a confirmed root cause (session
context was about to be cleared). The findings gathered are recorded below as an evidenced,
unresolved residual, not presented as fixed. Phase 6 stays `[PARTIAL]` for this reason alone.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — REPO_ROOT migrated to `git rev-parse --show-toplevel` with fixed-depth fallback
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — same REPO_ROOT migration
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` — same REPO_ROOT migration
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` — same REPO_ROOT migration
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` — same REPO_ROOT migration
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` — REPO_ROOT migrated with git-rev-parse-first; original manifest.json-probe dual-mode detection preserved as the non-git fallback
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-lint-postflight-boundary.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` — same REPO_ROOT migration (latent, masked); re-confirmed 8/8 green
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — same REPO_ROOT migration (latent, masked)
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` — fixture `manifest.json` gained `merge_targets.claudemd.source: "EXTENSION.md"`, restoring live Rule U coverage; REPO_ROOT migrated for consistency
- `agent-system/extensions/core/scripts/task-lock.sh` — `write_holder()` now `mkdir -p`s its lock directory immediately before writing, fixing a real concurrency race (see Decisions)

## Decisions

- **REPO_ROOT migration applied to all 17 literal-carrying files, not only the 5 loudly-failing
  ones.** The masked 11 (plus the already-fixed `test-index-entries-schema.sh`) were only
  accidentally safe via a `$SCRIPT_DIR`-relative fallback candidate; eliminating the defect class
  meant migrating every carrier. Each file's own candidate-array/fallback ordering was left
  untouched — only the `REPO_ROOT` derivation itself changed.
- **`test-double-loading-check.sh` needed a structural adaptation, not a literal swap.** Its
  existing REPO_ROOT derivation was a deliberate manifest.json-probe dual-mode detector (present 3
  levels up means source-store, absent means deployed), not a bare five-level literal. The fix
  places `git rev-parse --show-toplevel` first and keeps that suite's entire original detection
  block, unmodified, as the non-git fallback — honoring the phase's "leave candidate arrays and
  fallback ordering untouched" constraint for a file whose "fallback" is a block, not a line.
- **`write_holder()`'s missing `mkdir -p` was a real, reproduced concurrency defect, not a flake to
  document-and-skip.** `test-four-tier-conflict.sh`'s own case 1 fixture deliberately backgrounds a
  `rm -rf $lock_dir` releaser mid-retry-window. `cmd_acquire`'s stale-override, same-session
  re-entry, and missing-holder.json branches all decide to call `write_holder` after an earlier
  existence check, without re-verifying `$lock_dir` still exists immediately before the write. When
  the fixture's releaser removed the directory in that window, the tmp-file write failed with "No
  such file or directory," producing a hard `rc=2` abort instead of the test's expected clean
  resolve. The fix — `mkdir -p "$lock_dir" 2>/dev/null || true` at the top of `write_holder()` — is
  correct in every call site: every caller has already decided its own session should hold the
  lock before reaching this point, so recreating a concurrently-removed directory is never a new
  decision, only a defensive completion of one already made.
- **The "1012 minutes ago" heartbeat reading in the reproduced failure was not fully explained**
  within the Phase 5 time-box (plausibly a read racing the concurrent removal, or sandboxed-VM
  clock skew under the load of a full `run-all.sh` sequence). This was not blocking: the fix
  targets the reproducible, terminal failure mode (`write_holder`'s ERROR abort) regardless of
  which branch inside `cmd_acquire` triggered it, and the fix was verified effective (5/5 isolation
  runs, 4/4 full-sequence runs green, versus an intermittent pre-fix failure) without needing that
  sub-question resolved.
- **A redeploy landed, and Phase 4 closed `[COMPLETED]`.** The inter-cycle redeploy checkpoint
  fired once the previously-blocking sibling dispatch's commits cleared; `deploy-headless.sh` ran
  successfully (5 extensions resynced). This dispatch independently confirmed the redeploy landed
  correctly: all 18 files this task modified are byte-identical between the source store and
  `.claude/`, and both modes measure clean when run directly (37/0/37 source-store, 34/0/34
  deployed, each on two separate runs).
- **Gate 8's intermittent failure is a genuine, unresolved residual — diagnosis was time-boxed by
  an explicit instruction to checkpoint and stop, not by this task's own time-box.** Team-lead
  reported `verify-deploy.sh` gate 8 (which re-runs source-store `run-all.sh` internally,
  regardless of which tree `verify-deploy.sh` itself is checking) failing roughly 4 of 9 times
  post-redeploy, while direct `run-all.sh` invocations pass consistently. Two sequential
  reproduction loops (14 invocations planned, 7 completed before being asked to stop) did not
  reproduce a single failure in this dispatch's own sample — a sample too small to either confirm
  or refute the ~44% failure rate team-lead measured. The leading hypothesis, from code review
  rather than a captured failure: `test-claude-refresh-matcher.sh` (not one of this task's 18
  files) has a pre-existing, self-documented, load-sensitive flake — it backgrounds a real
  `sleep 300 &`, kills it, then polls up to 8s for `kill -0` to confirm it dead before asserting
  liveness semantics; its own comment states this budget was "widened once already" because it
  needs more headroom "when run alongside ~25 concurrent others." This dispatch hit that exact
  failure on a standalone source-store `run-all.sh` run (unrelated to any repro loop), and it
  self-resolved on immediate rerun — the same intermittent signature reported for gate 8. Re-reading
  `task-lock.sh`'s `cmd_acquire`/`write_holder()` flow found no residual TOCTOU window: Phase 5's
  `mkdir -p` fix covers every `write_holder` call site, so a recurrence of that specific race is not
  supported by code review. This is a hypothesis with circumstantial evidence, not a confirmed root
  cause — recorded honestly as such, with a named suspect and a recommended follow-up rather than
  either a claimed fix or a shrug.

## Plan Deviations

- **Phase 4, task "Obtain a redeploy through a sanctioned path"**: no longer a deviation — the
  redeploy landed in this dispatch via the inter-cycle checkpoint, as the plan's own preferred
  path anticipated. See `progress/phase-4-progress.json`.
- **Phase 5, task "Bisect the ordering dependency"**: skipped. The root cause was identified
  directly from `test-four-tier-conflict.sh`'s own fixture design (its deliberate concurrent
  `rm -rf $lock_dir` releaser) rather than requiring a bisection across preceding suites — the
  defect is a self-contained race inside `write_holder()`, not an inter-suite ordering dependency.
- **Phase 5, task "Evaluate the dead-pid probe heuristic"**: skipped. The probe (`DEAD_PID=999999`,
  decremented until confirmed dead) is unconnected to the actual failure mechanism found; its
  appearance in the reproduced log is an unrelated informational fixture-build line.
- **Phase 6, task "diagnose gate 8's intermittent failure"**: partially completed, then deferred.
  Reproduction was stopped after 7 of 14 planned `verify-deploy.sh` invocations, per an explicit
  instruction to checkpoint findings to disk and stop ahead of an imminent context clear, rather
  than complete the statistically-meaningful sample originally planned. Recorded as an evidenced
  residual in the table below, with a named leading suspect and a recommended follow-up task.
- All other tasks across all 6 phases completed as planned.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests, post-redeploy re-measurement (independently confirmed, twice each):
  **34 passed, 0 failed, 0 skipped, 34 total (deployed mode)**; **37 passed, 0 failed, 0 skipped,
  37 total (source-store mode, separate and non-comparable total)**
- `verify-deploy.sh`: this dispatch's own 7 completed runs (across two reproduction loops) all
  measured 23/23 checks passing, gate 8 included. Team-lead independently reports gate 8 failing
  intermittently (~4/9) in a separate, larger sample post-redeploy — not reproduced here, not
  refuted here; see the Residual-Failure section below.
- Files verified: Yes — every edited file confirmed to exist, contain the expected pattern, and
  pass its own suite (17 test files individually; `task-lock.sh` via the suite that exercises it);
  all 18 confirmed byte-identical between source store and deployed tree post-redeploy

### Residual-Failure Justification Table (1 unresolved residual)

| Suite / Gate | Reason | Evidence |
|-------|--------|----------|
| `verify-deploy.sh` gate 8 (intermittent, ~4/9 per team-lead's sample) | NOT one of this task's 18 modified files, and NOT the Phase 5 `write_holder()` race recurring (code review found no residual TOCTOU window — Phase 5's `mkdir -p` fix covers every call site). Leading suspect: `test-claude-refresh-matcher.sh`'s pre-existing, load-sensitive `kill -0` liveness poll (8s budget, self-documented as already widened once for exactly this kind of load sensitivity). Diagnosis was stopped before a failure was captured to confirm this — recorded as an evidenced hypothesis, not a proven cause | This dispatch reproduced the SAME failure signature (`is_live_inhibitor_target: still excludes the SAME inhibitor after its target was killed -- tautological check`) on a standalone source-store `run-all.sh` run, self-resolving on immediate rerun — matching gate 8's own intermittent, self-resolving character. 7 of 14 planned `verify-deploy.sh --findings` reproduction runs completed in this dispatch, all 23/23 PASS (did not capture a failure to inspect directly) |

Every REPO_ROOT-related residual from the prior interim snapshot (6 suites: `test-index-entries-schema.sh`,
`test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`, `test-resume-scan-nonconformance.sh`,
`test-skill-base-lifecycle.sh`, `test-update-task-status.sh`) is now resolved — the redeploy landed
and all 6 measure green in this dispatch's deployed-mode re-run. `test-common-lib.sh` (out of
scope, owned by the concurrent opencode session-id task) also measures PASS.

## Impacts

- Deployed-mode `run-all.sh` now measures 34/0/34 for real, not provisionally — every fix this task
  made is confirmed live in the deployed tree.
- The `write_holder()` fix in `task-lock.sh` is a real concurrency-correctness improvement that
  benefits every `task-lock.sh` consumer (acquire, acquire-retry, heartbeat), not only the test
  suite that exposed it, and is now confirmed deployed.
- The REPO_ROOT defect class (17 files) is now fully eliminated at the source and confirmed
  deployed, closing the recurrence surface the 13 previously-masked suites represented.
- Gate 8's intermittent failure remains open. If the leading hypothesis is correct, it is a
  pre-existing defect this task did not introduce and is not obligated to fix — but it is a real
  gap in `verify-deploy.sh`'s reliability as an automated gate (see Follow-ups).

## Follow-ups

- **Recommended new task**: reproduce gate 8's intermittent failure with a larger, unattended
  sample (15-20x `bash .claude/scripts/verify-deploy.sh --findings`), capturing `FINDING gate8`
  lines and the raw `run_all_output` on every failure, to confirm or rule out
  `test-claude-refresh-matcher.sh` as the cause. If confirmed: either widen its `kill -0` poll
  budget further (current 8s, already widened once) or replace the real-process-timing-dependent
  liveness assertion with an injectable/mockable predicate so the suite is no longer inherently
  load-sensitive.
- No further action needed on `test-common-lib.sh` from this task; it remains the concurrent
  sibling task's scope, and it measures PASS in current deployed mode regardless.

## References

- `specs/1012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md`
- `specs/1012_fix_test_suite_deployed_mode_failures/plans/01_run-all-deployed-mode-fixes.md`
- `specs/1012_fix_test_suite_deployed_mode_failures/progress/phase-1-progress.json` through `phase-6-progress.json`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (leading suspect for the gate-8 residual)
