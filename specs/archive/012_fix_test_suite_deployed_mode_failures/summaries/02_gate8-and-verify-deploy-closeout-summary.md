# Implementation Summary: Close the gate-8 flake and the standing verify-deploy failures

- **Task**: 12 - Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T13:26:30Z
- **Completed**: 2026-08-10T22:19:00Z
- **Effort**: 8.75 hours total (4.75 in Phases 1-5, 4.0 in Phases 6-11)
- **Dependencies**: None (one advisory overlap: the opencode session-id duplication task owns `test-common-lib.sh`)
- **Artifacts**: plans/02_gate8-and-verify-deploy-closeout.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

**Headline (never an unqualified green)**: 0 findings attributable to this task's own scope
across 20 consecutive `verify-deploy.sh` runs; 1 pre-existing, out-of-scope finding present in
every one of the 20 runs. Exact observed fraction: **0/20 runs reported zero findings; 20/20 runs
reported exactly one finding**, and that one finding is the same finding in all 20 — a
pre-existing `index-entries.json` `line_count` mismatch in the literature extension, outside this
task's `file_scope`. Zero `gate 8` (shell test suite runner) failures occurred across the sample —
the flake that motivated this closeout phase is confirmed resolved. All 11 phases of
`plans/02_gate8-and-verify-deploy-closeout.md` are now `[COMPLETED]` or
`[COMPLETED WITH EXCLUSIONS]` (Phase 5, carried forward unchanged from the prior round).

Phases 1-5 (REPO_ROOT migration across 17 suites, the `test-index-entries-schema.sh` fixture fix,
and the `task-lock.sh` `write_holder()` race fix) were already complete and verified entering this
round. This round closed the remaining six phases: the injectable liveness seam in
`claude-refresh.sh` (Phase 6), the scripted-probe replacement for
`test-claude-refresh-matcher.sh` assertion (c) (Phase 7), the `index-entries.json` `line_count`
correction (Phase 8), the dangling-dependency removal in `specs/state.json` (Phase 9), a
sanctioned redeploy with independently-confirmed byte-identity (Phase 10), and this Phase 11's
20-run repeated-sample acceptance bar.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` — extracted a `_pid_is_alive` seam from
  the bare `kill -0` call inside `is_live_inhibitor_target`, so the liveness check is overridable
  in tests without changing production behavior (the seam is a verbatim extraction of the same
  syscall)
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — assertion (c)
  rewritten from a real backgrounded-`sleep 300`-and-`kill`-and-poll race into a deterministic
  scripted probe using two designated PID literals (424242 alive, 424243 dead) via the
  `_pid_is_alive` override; the `sleep 300` helper, `SLEEP_HELPER_PID`, and the `kill -0` poll loop
  are removed entirely; the file header comment no longer claims the assertion drives a real
  process, and an in-block comment records the trade-off and the two repairs that were tried and
  disproven
- `agent-system/extensions/core/index-entries.json` — `line_count` corrected from 382 to 397 for
  `patterns/system-defect-discrimination.md`, via the sanctioned
  `generate-context-line-counts.sh --write` fixer (scoped to the `core` extension only)
- `specs/state.json` — task 9's `dependencies` array had a dangling `1015` entry (a vault-renumbering
  leftover); removed surgically via `jq`, leaving `[18]`
- `specs/TODO.md` — regenerated via `generate-todo.sh` to reflect the `state.json` edit above
- Full deploy: `bash .claude/scripts/deploy-headless.sh` run via explicit one-time operator
  authorization (obtained through the team lead, never self-invoked), resynced 5 extensions

Carried forward from Phases 1-5 (unchanged this round, listed for completeness — see
`summaries/01_run-all-deployed-mode-fixes-summary.md` for the full per-file breakdown):
`test-skill-base-lifecycle.sh`, `test-update-task-status.sh`, `test-loop-guard-staleness.sh`,
`test-reconcile-handoff-status.sh`, `test-resume-scan-nonconformance.sh`,
`test-corroborate-phase-counts.sh`, `test-double-loading-check.sh`, `test-errors-append.sh`,
`test-handoff-reader-parity.sh`, `test-lint-postflight-boundary.sh`,
`test-lint-state-writer-boundary.sh`, `test-phase-heading-patterns.sh`,
`test-postflight-marker-schema.sh`, `test-status-vocabulary.sh`, `test-validate-handoff.sh`,
`test-validate-state.sh`, `test-index-entries-schema.sh`, `task-lock.sh`.

## Decisions

- **20-run sample, not a single lucky run.** The gate-8 flake was measured at 20% inside
  `verify-deploy.sh` before the fix, so a single green run would have had a ~4-in-5 chance of
  occurring even with the defect fully intact. The revised Phase 11 acceptance bar required a
  20-run sample specifically to make the before/after comparison like-for-like with the original
  diagnosis's sample size.
- **The one residual finding is deliberately not fixed here.** It is `index-entries.json`
  `line_count: 117` (declared) vs `144` (actual) for
  `project/literature/domain/literature-index.md`, inside
  `agent-system/extensions/literature/index-entries.json`. It is: (1) **pre-existing** — present
  in the pre-redeploy baseline this task inherited, not introduced by any of this task's edits;
  (2) **outside this task's `file_scope`**, which names only
  `agent-system/extensions/core/index-entries.json`; (3) inside an extension with other files
  (`literature-index.md`, `literature-briefing.sh`, `literature-search.sh`, plus an untracked
  `scripts/literature-pyenv/`) already mid-edit by a separate, concurrent session at the time this
  task ran Phase 8 — fixing it here would have touched that session's in-flight territory.
  Recommended as a follow-up task below.
- **A second, independent observation of the same finding.** Phase 8's own diagnostic step ran an
  *unscoped* `generate-context-line-counts.sh --check` (before scoping the fixer to `core` only)
  and it surfaced the identical literature `line_count` mismatch by a different mechanism than
  `verify-deploy.sh` gate 3 — confirming the finding is real, stable, and not an artifact of
  `verify-deploy.sh`'s own check logic. It was left alone for the same file_scope/concurrent-edit
  reasons. This is not a second, distinct mismatch — it is the same one, corroborated twice.
- **Two assumptions recorded in earlier artifacts are corrected here, because a future reader
  would otherwise be misled by them:**
  1. **The gate-8 flake was NOT load-sensitive.** An earlier snapshot hypothesized load-sensitivity
     (failures more likely "when run alongside ~25 concurrent others"). Measurement in this task's
     own diagnostic phases found a 43% standalone failure rate on an otherwise-idle machine —
     higher, not lower, than under measured load — so load-sensitivity is not the operative
     variable.
  2. **Widening the `kill -0` poll budget was tried and disproven as a fix.** No finite poll
     budget resolves a failure mode with a 43-83% observed rate, and the underlying race (a
     killed-but-unreaped child still answering `kill -0` as alive) is inherent to relying on a
     real process's OS-level state at all. What actually resolved it is the structural fix applied
     in Phases 6-7: extracting an injectable `_pid_is_alive` seam and replacing the real-process
     race with a scripted, deterministic probe — eliminating the timing dependency rather than
     giving it more room.

## Plan Deviations

- **Phase 11, task "report actual N if the wall-clock budget is genuinely exhausted before 20
  runs"**: not applicable — all 20 runs completed within budget, so there was nothing to report
  under this contingency.
- All other tasks across all 11 phases (this round: Phases 6-11) completed as planned. See
  `plans/02_gate8-and-verify-deploy-closeout.md` for the per-phase task checklists and Phase
  8/9/10's own deviation records (index-entries.json scoping, state.json surgical edit, redeploy
  path).

## Verification

- Build: N/A (shell scripts and JSON, no build step)
- Tests:
  - `verify-deploy.sh`: **20/20 runs, exit=1, 1 finding each** (raw logs preserved — see
    References). 0/20 runs were clean; 20/20 runs' one finding is the same pre-existing,
    out-of-scope literature `line_count` mismatch.
  - Gates 5 (deploy drift), 8 (shell test suite runner), and 10 (dangling dependencies) — the
    other three gates this closeout round targeted, alongside gate 3 — report **PASS in all
    20/20 runs**.
  - Gate 3 (Rule R / line counts) reports **PASS for the core-extension entry this task fixed in
    all 20/20 runs**, and FAILs only for the pre-existing out-of-scope literature entry, also in
    all 20/20 runs.
  - `check-extension-docs.sh`: **19/20 extensions PASS**; `literature` FAILs on the same
    pre-existing `line_count` mismatch. The pre-existing zotero/literature never-deployed advisory
    block is present and unchanged — not a new failure.
  - `generate-context-line-counts.sh --check` (unscoped): confirms the same single literature
    mismatch and nothing else — 478/479 entries exact, 1 mismatch (the literature entry above).
  - `check-task-references.sh`: PASS, 0 unexempted occurrences across all 4 scanned trees.
- Files verified: Yes — every file this task modified across all 11 phases confirmed
  byte-identical between the source store and the deployed tree (Phase 10), and the merged
  deployed `index.json` confirmed to carry the corrected `line_count: 397` for
  `patterns/system-defect-discrimination.md`.

### Residual-Failure Justification Table (1 residual, deliberately not fixed)

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` gate 3 [literature]: `index-entries.json` entry `project/literature/domain/literature-index.md` `line_count` mismatch (declared 117, actual 144) | Pre-existing (present in the pre-redeploy baseline, not introduced by this task); outside this task's `file_scope` (`agent-system/extensions/literature/index-entries.json` is not a listed scope path); belongs to a separate, concurrent editing session's territory (`literature-index.md`, `literature-briefing.sh`, `literature-search.sh` were mid-edit in that extension at the time this task ran); deliberately not fixed here | Present in all 20/20 `verify-deploy.sh` sample runs (raw logs preserved — see References); independently corroborated by an unscoped `generate-context-line-counts.sh --check` during Phase 8, which reported the identical mismatch by a different code path; also reflected in `check-extension-docs.sh`'s single `literature` FAIL among 20 extensions |

Pre-redeploy baseline (10 findings) for contrast: gate 3 core drift on `claude-refresh.sh` /
`system-defect-record.sh` / `test-claude-refresh-matcher.sh`; gate 3 literature `line_count`
117 vs 144 (the residual above); gate 5 core content-differs on the same three core files; gate 8
`[FAIL] --verbose did not report the exempt candidate line` in
`test-lint-state-writer-boundary.sh`. All core-scoped findings in that baseline are resolved and
confirmed absent across all 20 post-fix sample runs; only the pre-existing, out-of-scope
literature finding persists.

## Impacts

- `verify-deploy.sh` gate 8 is now reliable: 0 failures across a 20-run sample, versus the
  previously-measured 20% failure rate inside gate 8 (and 43% standalone on an idle machine). This
  removes a source of false-negative noise from every future automated deploy verification.
- The `test-claude-refresh-matcher.sh` suite is now deterministic rather than timing-dependent, at
  the recorded cost of assertion (c) no longer driving a real OS process (traded off explicitly in
  an in-file comment).
- `agent-system/extensions/core/index-entries.json` and `specs/state.json` are both now internally
  consistent (correct `line_count`, no dangling dependency reference).
- The one remaining `verify-deploy.sh` finding is fully attributable to a different extension's
  out-of-scope, pre-existing data error, not to any regression from this task.

## Follow-ups

- **Recommended new task**: correct the `line_count` declarations in
  `agent-system/extensions/literature/index-entries.json` (at minimum the
  `project/literature/domain/literature-index.md` entry, declared 117 vs actual 144), once the
  concurrent session editing that extension's other files has landed. Use the same sanctioned
  `generate-context-line-counts.sh --write` fixer, scoped to the `literature` extension.
- No further action needed on `test-common-lib.sh` from this task; it remains the concurrent
  sibling task's scope and measures PASS in current deployed mode.

## References

- `specs/012_fix_test_suite_deployed_mode_failures/plans/02_gate8-and-verify-deploy-closeout.md`
- `specs/012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md`
- `specs/012_fix_test_suite_deployed_mode_failures/summaries/01_run-all-deployed-mode-fixes-summary.md`
  (Phases 1-5 detail)
- `specs/012_fix_test_suite_deployed_mode_failures/progress/phase-6-progress.json` through
  `phase-11-progress.json`
- `specs/012_fix_test_suite_deployed_mode_failures/reports/phase-11-verify-deploy-sample/` — the
  full 20-run raw evidence (`run-1.log` through `run-20.log`, `summary.log`, `driver.log`)
