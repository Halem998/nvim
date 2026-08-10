# Implementation Summary: Make run-all.sh green or justify every residual failure

- **Task**: 1012 - Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T17:00:00Z
- **Completed**: 2026-08-10T19:15:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None (one advisory overlap: the opencode session-id duplication task owns `test-common-lib.sh`)
- **Artifacts**: plans/01_run-all-deployed-mode-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Deployed-mode `run-all.sh` measures 28 passed, 6 failed, 34 total — down from the research
baseline's 8 failures, but **not zero**: this is not an unqualified green. Source-store `run-all.sh`
measures 37 passed, 0 failed, 37 total (its own separate, non-comparable total, since source-store
mode scans every extension). The 6 residual deployed-mode failures are all suites this task fixed
in the source store but could not get redeployed through any sanctioned path within this dispatch
— see the justification table below. Every fix in this task's own scope was verified green from
the source-store location; the gap between source-store green and deployed-mode green is entirely
attributable to the pending redeploy, not to any unresolved defect.

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
- **No redeploy was invoked by this agent.** Per the source-store/deploy-boundary rule and this
  task's own binding Phase 4 constraint, only `skill-orchestrate`'s Stage MT-3 inter-cycle
  checkpoint or an explicit operator action may run `deploy-headless.sh`. A redeploy was requested
  from team-lead via SendMessage; none landed within this dispatch. Phase 4 closed `[BLOCKED]`
  per the plan's own pre-accepted contingency, carrying the source-store-green result and a
  depth-3 scratch proof as evidence of correctness.

## Plan Deviations

- **Phase 4, task "Obtain a redeploy through a sanctioned path"**: skipped. No sanctioned redeploy
  path was invokable from within this agent's own dispatch. Requested via SendMessage to
  team-lead; none landed before Phase 4 closed. Recorded in `progress/phase-4-progress.json`.
- **Phase 5, task "Bisect the ordering dependency"**: skipped. The root cause was identified
  directly from `test-four-tier-conflict.sh`'s own fixture design (its deliberate concurrent
  `rm -rf $lock_dir` releaser) rather than requiring a bisection across preceding suites — the
  defect is a self-contained race inside `write_holder()`, not an inter-suite ordering dependency.
- **Phase 5, task "Evaluate the dead-pid probe heuristic"**: skipped. The probe (`DEAD_PID=999999`,
  decremented until confirmed dead) is unconnected to the actual failure mechanism found; its
  appearance in the reproduced log is an unrelated informational fixture-build line.
- All other tasks across all 6 phases completed as planned.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: **28 passed, 6 failed, 0 skipped, 34 total (deployed mode)**; 37 passed, 0 failed, 0
  skipped, 37 total (source-store mode, separate and non-comparable total)
- Files verified: Yes — every edited file confirmed to exist, contain the expected pattern, and
  pass its own suite (17 test files individually; `task-lock.sh` via the suite that exercises it)

### Residual-Failure Justification Table (deployed mode, 6 failures)

| Suite | Reason | Evidence |
|-------|--------|----------|
| `test-index-entries-schema.sh` | Source-store fix (fixture manifest + REPO_ROOT) verified green (9/9 passed, Rule U firing correctly); no sanctioned redeploy path was available in this dispatch to land it in `.claude/scripts/tests/` | Deployed-mode failure text: `[FAIL] Rule U did not fire on a 61-line EXTENSION.md`, matching the pre-fix defect exactly; source-store run of the same (already-fixed) file: `Results: 9 passed, 0 failed` |
| `test-loop-guard-staleness.sh` | Same — REPO_ROOT fix verified green in source store (28/0), pending redeploy | Deployed grep confirms 0 occurrences of `git rev-parse --show-toplevel` in the deployed copy; source-store copy has it and passes |
| `test-reconcile-handoff-status.sh` | Same — REPO_ROOT fix verified green in source store (14/0), pending redeploy | Same drift pattern; source-store `Results: 14 passed, 0 failed` |
| `test-resume-scan-nonconformance.sh` | Same — REPO_ROOT fix verified green in source store (39/0), pending redeploy | Same drift pattern; source-store `Results: 39 passed, 0 failed` |
| `test-skill-base-lifecycle.sh` | Same — REPO_ROOT fix verified green in source store (14/0), pending redeploy; also the file used for the depth-3 scratch proof, which independently confirmed correct REPO_ROOT resolution at deployed depth without a redeploy | Source-store `Results: 14 passed, 0 failed`; depth-3 scratch run: exit 0, 14 passed/0 failed, no `$HOME`-based path errors |
| `test-update-task-status.sh` | Same — REPO_ROOT fix verified green in source store (19/0), pending redeploy | Same drift pattern; source-store `Results: 19 passed, 0 failed` |

**`test-common-lib.sh`** (out of scope, owned by the concurrent opencode session-id task, per this
task's binding constraint) was explicitly **not** expected to be justified as red here — and in
fact it **measured PASS** in this task's own deployed-mode run, along with
`test-lint-state-writer-boundary.sh` (8/8, confirming the research report's finding that its
earlier 7/8 report was stale) and `test-four-tier-conflict.sh` (deployed copy, unfixed
`task-lock.sh`, passed this run — consistent with the flake's own intermittent, not-always-firing
nature documented in Phase 5).

`verify-deploy.sh`: 21 of 23 checks passed. The 2 failures (doc-lint, manifest-driven content-hash
parity) are the same un-redeployed drift as the table above, not new or unrelated findings — both
resolve to a stable count of 18 drifted files (17 test suites + `task-lock.sh`), exactly matching
this task's own source-store edits. `check-extension-docs.sh` (deployed copy): same 18-file drift,
plus a pre-existing, unrelated 36-item literature/zotero never-deployed advisory block this task
did not touch.

## Impacts

- Once a sanctioned redeploy runs (orchestrator inter-cycle checkpoint or an operator running
  `<leader>al` / `deploy-headless.sh`), deployed-mode `run-all.sh` is expected to reach 34/0/34 —
  every currently-red suite is proven green from the source-store location and the only gap is the
  pending deploy.
- The `write_holder()` fix in `task-lock.sh` is a real concurrency-correctness improvement that
  benefits every `task-lock.sh` consumer (acquire, acquire-retry, heartbeat), not only the test
  suite that exposed it.
- The REPO_ROOT defect class (17 files) is now fully eliminated at the source, closing the
  recurrence surface the 13 previously-masked suites represented.

## Follow-ups

- Land a redeploy (orchestrator inter-cycle checkpoint, or an operator running `<leader>al`
  `[Reload All]` / `bash .claude/scripts/deploy-headless.sh`) to bring deployed-mode `run-all.sh`
  to its expected 34/0/34 and clear the `verify-deploy.sh`/`check-extension-docs.sh` drift
  findings for these 18 files.
- No further action needed on `test-common-lib.sh` from this task; it remains the concurrent
  sibling task's scope.

## References

- `specs/1012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md`
- `specs/1012_fix_test_suite_deployed_mode_failures/plans/01_run-all-deployed-mode-fixes.md`
- `specs/1012_fix_test_suite_deployed_mode_failures/progress/phase-1-progress.json` through `phase-6-progress.json`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
