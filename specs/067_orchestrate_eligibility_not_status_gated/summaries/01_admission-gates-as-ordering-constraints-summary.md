# Implementation Summary: Task #67

- **Task**: 67 - Make /orchestrate admission gates ordering constraints, not exclusions: unstrand in-flight tasks and end solo-only self-modifying dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-08-18T00:30:00Z
- **Completed**: 2026-08-18T04:50:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_admission-gates-as-ordering-constraints.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Repaired two coupled defects in `/orchestrate`'s multi-task admission predicate so every
admission gate degrades to an ORDERING CONSTRAINT rather than a PERMANENT EXCLUSION. Work Stream
B (Phases 1-2) gave the self-modification gate a deterministic designated-candidate tie-breaker
and phase-aware gating. Work Stream A (Phases 3-6) removed the `{researching, planning}`
eligibility exclusion, replacing it with the already-existing lock/`dependencies[]`/`file_scope`
gates, with the classifier's phase-group mapping landing first so the exclusion removal never
routes a stranded task into an unclassifiable dead end. Phase 7 recorded the resulting
normative principle in `batch-orchestration-guardrails.md`. All 7 phases completed and verified.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — designated-candidate
  tie-breaker (lowest task number admits per cycle, others defer) and `--phase-map` phase-aware
  exemption for research/plan dispatches; header contract updated; verdict `reason` string
  rewritten to name the designated candidate as an ordering constraint, never a solo-run
  instruction.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — `--phase-map`
  documentation, tie-breaker non-bump rationale (schema stays v5), convergence-mechanism
  paragraph corrected and extended with the tie-breaker's second exit condition.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — case 2.4 updated for the
  new solo-admit behavior; case 2.4b added to pin the two-candidate tie-breaker defer path
  (file widened into `file_scope` mid-task after the tie-breaker caused a genuine regression here).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — classifier call relocated to
  Stage MT-3 step 4.5 (feeds `--phase-map`, reused by Stage MT-4 rather than re-invoked); self-mod
  operator warning now logs the verdict's own `reason` string; convergence-guard diagnostic
  reframed; eligibility bullet `Status is NOT {researching, planning}` removed and replaced with
  the lock/dependencies/file_scope contract; 5 convergence-exit-condition sites corrected;
  `researching`/`planning` single-task Stage 4 handlers converged with `not_started`/`researched`
  (dispatch, not exit-with-warning); Stage MT-4 phase-grouping table updated.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — mirrored admission-call
  `--phase-map` threading, self-mod warning text, `in_batch` convergence-exit correction, and the
  converged `researching`/`planning` handlers.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — `researching` ->
  `research` and `planning` -> `plan` classifier arms added (mutation-check confirmed RED
  pre-fix, GREEN post-fix); header engine table updated.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — extended
  from a `partial`-only suite to the full status-to-group regression suite (13 new baseline
  assertions in Phase 3, 4 mutation-check assertions in Phase 4; 26 total, 0 failed).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — state table
  rows for `researching`/`planning` corrected to dispatch (not exit-with-warning); ASCII
  eligibility box clause (b) removed; Dependency Gating Model item 2 removed; new "Convergence:
  researching/planning No Longer Exit" subsection added.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — new `demote_stranded_status()`
  helper: lock-aware demotion (`researching` -> `not_started`, `planning` -> `researched`) gated
  on `task-lock.sh check` exit code (demote on 0/2, refuse on 1/3), reached only after the
  existing no-artifact no-op branch; fixed a `set -e` command-substitution pitfall on the
  lock-check call; header comment extended.
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` —
  `scripts/reconcile-task-status.sh` added to `critical_paths` (not `recursion_guard`).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  "Ordering Constraint vs. Exclusion" section with a Gate Catalogue table; "considered and found
  already satisfied" note for Direction 3 (redeploy-boundary serialization) under the Inter-Cycle
  Redeploy Checkpoint subsection; two-clause distinction added to "The Same-Cycle Narrowing and
  Its Hazard Accounting"; 4 dependency-terminal-state claim sites re-read and confirmed accurate
  (no edit owed).

## Decisions

- Adopted Work Stream B Direction 1 (designated-candidate tie-breaker, lowest task number) and
  Direction 2 (phase-aware gating via `--phase-map`), rejecting Direction 3
  (redeploy-boundary serialization) as targeting a hazard that provably cannot occur under this
  system's cycle-synchronous dispatch architecture — recorded as closed, not a follow-up.
- The tie-breaker and `--phase-map` addition does NOT bump the admission script's schema version
  (stays `orchestrate-batch-admit-v5`): it reassigns which of two already-existing verdict shapes
  a candidate lands in, using criteria no consumer needs to inspect, rather than introducing a new
  field or verdict shape — a materially different situation from every prior version bump in that
  schema's history.
- Adopted Direction (b) defense-in-depth (lock-aware demotion in `reconcile-task-status.sh`)
  alongside Direction (a) (eligibility no longer status-gated), per the research report's Decision
  1 — giving operator-visible repair independent of `/orchestrate` ever being re-invoked.
- Widened `file_scope` mid-task (via `state-write.sh`) to add
  `agent-system/extensions/core/scripts/test-conflict-predicate.sh` after discovering the
  tie-breaker caused a genuine, expected regression in that file's pre-existing self-modification
  fixture — corrected in the same phase rather than deferred.

## Plan Deviations

- **Phase 4**: additionally corrected `docs/architecture/orchestrate-state-machine.md`'s
  Complete State Table rows for `researching`/`planning` (restating the old "exit with warning"
  behavior) and added a new "Convergence" subsection, though the file was named in Phase 5's
  (not Phase 4's) Files-to-modify list for a different part of the same file. Required by the
  phase's own Scope Hypothesis census-grep instruction; the state-table rows directly restated
  the behavior this phase converges. Phase 5's own scope (the eligibility-rule ASCII box and
  Dependency Gating Model prose) remained untouched until Phase 5 as planned.
- **Phase 6**: verification ran as an ad hoc sandbox script rather than extending the permanent
  `test-reconcile-handoff-status.sh` suite, since that file is outside the declared `file_scope`
  and the plan's Phase 6 Files-to-modify list does not name it. All 8 matrix rows verified green;
  the pre-existing suite was re-run to confirm no regression (14 passed, 0 failed).
- **Phase 1 (test-conflict-predicate.sh)**: `file_scope` was widened mid-task (declared deviation,
  not a plan checklist item) to fix a genuine regression the tie-breaker caused in an existing
  fixture outside the plan's originally-declared file list.

## Verification

- Build: N/A (no build system)
- Tests: `test-orchestrate-triage-classify.sh` 26/26 passed; `test-conflict-predicate.sh` 36/36
  passed (was 34/35 pre-fix with 1 pre-existing regression, now fixed); full suite
  `run-all.sh` 41/43 passed, with the 2 remaining failures (`test-common-lib.sh`,
  `test-validate-return-meta.sh`) pre-existing and unrelated to this task's `file_scope`.
- Files verified: Yes
- `deploy-headless.sh && verify-deploy.sh`: run at the close of every phase. `verify-deploy.sh`'s
  own overall exit reflects 2 pre-existing, unrelated failures (doc-lint line-count drift on
  files this task never touched; a `state.json` schema warning on tasks #53/#66's `priority`
  field) that predate this task and are out of its `file_scope` scope to fix.
- `check-task-references.sh`: PASS (0 occurrences) after every phase.
- `bash -n`: passed on every edited shell script.
- Admission-script fixture matrix (Phase 1): deadlock, Consequence-A, phase-gate, and
  no-`--phase-map`-regression fixtures all produced the expected verdicts.
- `reconcile-task-status.sh` exit-code matrix (Phase 6): all 8 sandbox rows behaved as tabulated
  (demote on lock-check exit 0/2, refuse on 1, promotion path unchanged when an artifact exists).
- `grep -rn "re-run affected tasks solo\|run it solo" agent-system/extensions/core/` — 0 matches.
- `grep -rn "entering \`researching\`/\`planning\`" agent-system/extensions/core/` — 0 matches.
- `git diff --stat` confirms no file under `.claude/**` was hand-edited at any point.

## Impacts

- A task stranded in `researching`/`planning` by a dead prior session's stale lock is no longer
  silently skipped forever by `/orchestrate` — it is admitted, classified to the correct phase
  group, and dispatched (with the stale lock reclaimed by Stage MT-4's `task-lock.sh acquire`).
- N self-modifying tasks co-dispatched in one `/orchestrate` batch now run in a deterministic
  sequence (lowest task number first) instead of deadlocking; the operator is never instructed to
  re-run anything solo.
- A self-modifying task's research or plan dispatch is no longer deferred merely because its
  implementation footprint names a critical path.
- `reconcile-task-status.sh` gains a new, narrowly-scoped demotion write class, giving
  operator-visible repair of stranded tasks independent of `/orchestrate`.

## Follow-ups

- None. Direction 3 (redeploy-boundary serialization) was evaluated and closed as
  already-satisfied by the existing cycle-synchronous architecture — no follow-up task is owed.
- The 2 pre-existing, unrelated test failures (`test-common-lib.sh`,
  `test-validate-return-meta.sh`) and the pre-existing doc-lint/state.json drift are outside this
  task's `file_scope` and were not introduced by this change; they remain open for a separate task
  if addressed.

## References

- `specs/067_orchestrate_eligibility_not_status_gated/plans/01_admission-gates-as-ordering-constraints.md`
- `specs/067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md`
- `specs/067_orchestrate_eligibility_not_status_gated/progress/phase-{1-7}-progress.json`
