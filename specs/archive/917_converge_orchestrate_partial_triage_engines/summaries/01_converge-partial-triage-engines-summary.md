# Implementation Summary: Task #917

**Completed**: 2026-07-27
**Duration**: ~1.5 hours (6 phases)

## Overview

Converged the single-task `/orchestrate` engine's handling of a `partial` task with neither a
continuation handoff nor blockers onto the same routing the multi-task (`mt`) engine already
used: dispatch `implement` rather than exit with a referral to `/implement`. Removed the engine
fork in the shared classifier, rewrote Stage 4's dead-end branch as a real implement dispatch
sourcing resume context from `orchestrate-recover-outcome.sh`, and brought six source-store
files plus one regression test into three-way agreement (classifier header table, Stage 4 prose,
Stage MT-4 table). Both decisions the task required (keep the `blocked` divergence; retain
`exit_partial` as a reserved schema value) were resolved with justifications recorded in all
three artifacts. All existing verification passed at every phase; the deploy tree was
regenerated and confirmed at parity with the source store.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — removed the
  `partial`/neither branch's `mt`/`single` engine fork (both now emit `implement`); rewrote the
  header's "Two-engine rationale" paragraph, updated the header engine table's `partial, neither`
  row, added the Decision 1 (`blocked`) justification with the independent-corroboration
  discriminator, and annotated the `group` field's `exit_partial` value as reserved (Decision 2,
  no schema version bump)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — reworded the step-7
  header comment and the `exit_partial` `case` arm's explanatory string to match Decision 2 (a
  reserved value, defensively excluded if ever emitted); the defensive `case` arm itself was kept
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — deleted the now-false
  "Cross-reference" paragraph above the `partial` sub-state block; replaced the "Sub-state: no
  handoff, no blockers" branch's unconditional `EXIT (partial, cycle_count)` with a real
  `implement` dispatch (probe via `orchestrate-recover-outcome.sh` with
  `prior_meta_probe_window=0`, `skill_preflight_update`, dispatch-window reset, plan-path
  resolution, Agent invocation, post-return infra-failure discrimination); added the Decision 1
  justification to the `blocked` handler; extended the Stage MT-4 phase-grouping table's preamble
  to name all three artifacts that must stay in lockstep, and added the Decision 1 justification
  to its `blocked` row annotation
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — added one
  clarifying sentence beneath the state table (table itself left byte-identical) stating the
  `partial` no-handoff/no-blockers sub-state now dispatches implement while budget remains, and
  that the cycle-limit row is reached via the generic end-of-cycle check
- `agent-system/extensions/core/commands/orchestrate.md` — one-line strengthening in CHECKPOINT
  1's permissive-gate prose, explicitly naming the `partial`-no-handoff case as included
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` — converged the
  `expect_single` fixture-955 expectation from `exit_partial` to `implement`; rewrote test case 3
  from a divergence assertion to a convergence assertion; annotated the intentionally-retained
  `blocked` divergence (964) in both engine expectation tables
- `specs/state.json` — expanded task 917's `file_scope` to include the regression test file;
  regenerated `specs/TODO.md`

## Decisions

- **Decision 1 (`blocked` row)**: kept the `mt`→`skip` / `single`→`needs_human` divergence,
  justified by independent corroboration — both engines' own handlers already implement it
  separately, unlike the removed `partial` divergence, which only the classifier asserted.
- **Decision 2 (`exit_partial`)**: retained as an explicitly-reserved `group` enum value with no
  schema version bump — a schema version governs field set/shape, neither of which changed; only
  one enum's reachable value domain shrank, which cannot break any reader.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts and markdown; syntax-checked with `bash -n`, both pass)
- Tests: Passed — `test-triage-classify.sh` (6/6) and `test-dry-run-report.sh` (14/14), both
  re-run against the final redeployed tree
- Files verified: Yes — `verify-deploy.sh` PASS (11 checks, 0 failures) after
  `deploy-headless.sh` regenerated 264 artifacts from the source store
- Three-way table agreement: confirmed by literal side-by-side audit (classifier header / Stage 4
  prose / Stage MT-4 table), recorded in Phase 4 of the plan
- MAX_CYCLES bound: confirmed by trace (Phase 6) — exactly 5 dispatches then the pre-existing
  Stage 7 exit; no new counter, guard, or gate added in any phase

## Notes

Acceptance criterion satisfied: `/orchestrate N` on a single task in `partial` state with no
handoff and no blockers now routes to `implement` (verified via the classifier and the regression
suite) rather than exiting with a referral to `/implement`, while `MAX_CYCLES` still bounds a
task that cannot progress. All edits landed under `agent-system/extensions/core/` and `specs/**`
only; `.claude/` was touched exclusively by the deliberate `deploy-headless.sh` regeneration in
Phase 6, never by an authored edit.
