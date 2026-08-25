# Implementation Summary: Task #83

- **Task**: 83 - Make 'completed' mean 'in effect' for tasks that edit the source store — a postflight deploy gate
- **Status**: [COMPLETED]
- **Started**: 2026-08-24T17:50:00Z
- **Completed**: 2026-08-25T01:45:00Z
- **Effort**: ~8 hours
- **Dependencies**: 82 (complete)
- **Artifacts**: plans/01_postflight-deploy-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Implemented a check-only, unconditional deploy-freshness backstop inside
`scripts/update-task-status.sh` (new exit code 6) that refuses a source-store-touching task's
`postflight … implement` transition when the task's own `modified_files` overlap
`agent-system/extensions/**` and the deploy is provably stale. Two serialized, baseline-relative
redeploy triggers (single-task `command-gate-out.sh`, multi-task `commands/implement.md` Step 4)
make the refusal self-resolving. The mechanism is documented as an authoritative subsection in
`batch-orchestration-guardrails.md` plus a mandatory additive carve-out in
`regeneration-is-manual-only.md`. All 8 plan phases are `[COMPLETED]`; the change was deployed
and dogfooded against this task's own completion.

## What Changed

- `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` — new shared library holding
  the per-extension path-scoped freshness comparison, exporting `deploy_freshness_stale_names`
  (advisory tier) and `deploy_freshness_status` (blocking tier's fresh/stale/cannot-verify
  three-way distinction).
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` — re-pointed at the shared
  library via SCRIPT_DIR-relative sibling resolution; byte-identical observable behavior verified
  against a live re-run of the unmodified original.
- `agent-system/extensions/core/scripts/update-task-status.sh` — new "PHASE 0.5" block: an
  unconditional, check-only backstop firing on `postflight`/`implement`/non-noop, implementing a
  six-branch conclusiveness convention (no `.return-meta.json`; empty `modified_files`; no
  overlap; missing shared library (D4); cannot-verify freshness; overlap+fresh) with exit 6
  reserved for the sole conclusive refusal (overlap+stale). Mechanically verified to contain zero
  `deploy-headless`/`verify-deploy` string references (the check-only contract).
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — new regression
  suite (7 cases, 19 assertions), deliberately resolving the two files under test
  source-store-first (opposite of every other suite in this directory) so it is meaningful
  before a deploy runs. Negative control confirmed: the suite fails (7 assertions) against the
  pre-Phase-3 script.
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — extended with 8
  library-direct cases pinning the STALE/FRESH/CANNOTVERIFY three-way distinction.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — new `rc == 6` branch implementing
  the single-task serialized redeploy trigger, with the same baseline-relative (a)/(b)/(c)
  contract as the existing Inter-Cycle Redeploy Checkpoint. Verified via stubbed
  `deploy-headless.sh`/`verify-deploy.sh` across all three branches.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update` now captures
  and returns `update-task-status.sh`'s own exit code (previously silently swallowed by the
  trailing events-append call's own exit status); on rc 6 specifically, emits a
  `[deploy-check] deploy-pending` line and records `deploy_pending: true` into the task's
  `.return-meta.json`.
- `agent-system/extensions/core/commands/implement.md` — new Step 4 batch-refusal deploy trigger
  (the multi-task path's serialized redeploy site), placed before the existing per-task
  `.return-meta.json` deletion loop.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  authoritative `### The Postflight Completion-Deploy Gate` subsection plus a Blocking-vs-Advisory
  classification table entry.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — new additive
  `## Automated Exception: The Postflight Completion-Deploy Gate` carve-out (existing
  Inter-Cycle exception left byte-identical, verified), a two-tier staleness model statement, and
  two new `## Related Documentation` entries.
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  — scope-corrected additions (see Plan Deviations): registered the two new source files in
  `provides.scripts` and corrected `line_count` for the two heavily-edited docs.
- `specs/state.json` — task 83's `file_scope` corrected from 4 to 12 entries (the originally
  planned 10, plus `manifest.json` and `index-entries.json`, both directly necessitated by this
  task's own edits).

## Decisions

- D1-D7 from the plan's Design Decisions section were followed without modification (unconditional
  backstop; ordering-constraint refusal; exit code 6; D4 inconclusive-pass-through; git-log-only
  freshness comparison; `skill-orchestrate` untouched; path-based overlap predicate).
- The overlap library (`file-scope-overlap.sh`) must be sourced via `if ! . "$LIB" 2>/dev/null;
  then ... fi` rather than a bare `.` — its `read -r -d '' ... <<'JQDEFS'` idiom returns exit 1 at
  heredoc EOF even on success, which trips `set -e` on a bare source. Mirrors `task-lock.sh`'s
  existing `ensure_file_scope_overlap_lib` guard.
- Stale-wins-over-cannot-verify-over-fresh when a task's `modified_files` touch multiple
  extensions: refuse if ANY touched extension is provably stale.

## Plan Deviations

- **Phase 2** (altered): `check-deploy-freshness.sh`'s re-point to the shared library uses
  SCRIPT_DIR-relative sibling resolution rather than the PROJECT_ROOT-anchored candidate-list
  pattern `update-task-status.sh` uses for `phase-heading-patterns.sh` — this script has no
  `deploy-root-guard.sh`/PROJECT_ROOT concept and its own `$1` argument names the CONSUMER repo
  being checked, not its own location. See `progress/phase-2-progress.json`.
- **Phase 3** (altered): shellcheck is unavailable in this environment; `bash -n` was substituted
  for the "no new shellcheck findings" verification criterion.
- **Phase 7 / file_scope** (altered, scope-corrected): `agent-system/extensions/core/manifest.json`
  and `agent-system/extensions/core/index-entries.json` were added to the corrected `file_scope`
  (10 → 12 entries) and edited — registering the two new source files (`deploy-freshness-lib.sh`,
  `test-postflight-deploy-gate.sh`) in `provides.scripts` (without which `deploy-headless.sh`
  would never copy them) and correcting `line_count` for the two docs Phase 7 grew. Neither file
  was in the plan's originally-corrected 10-entry scope; both are directly necessitated by this
  task's own edits, not incidental scope creep.
- No phase was skipped, altered in scope, or deferred beyond the two items above.

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `test-postflight-deploy-gate.sh` (19/19), `test-deploy-freshness.sh` (15/15,
  including 8 new library-direct cases), full `run-all.sh` from the deployed tree: 48 passed, 2
  failed (both pre-existing, matching the Phase 1 baseline exactly — `test-skill-base-lifecycle.sh`'s
  `skill_cleanup` temp-file leftover and `test-validate-return-meta.sh`'s well-formed/fix-roundtrip
  issue).
- Files verified: Yes — all 10 modified scripts/docs byte-identical between source-store and
  deployed tree after `deploy-headless.sh`; `check-deploy-freshness.sh` no longer reports `core`
  stale.
- Negative control: `test-postflight-deploy-gate.sh` fails (7 of its assertions) when run against
  a pre-Phase-3 copy of `update-task-status.sh`, confirming it exercises real behavior.
- Check-only contract: `grep -c 'deploy-headless\|verify-deploy'` over `update-task-status.sh`
  returns 0 for both strings.

## Self-Demonstration (Phase 8)

This task's own implementation edits `agent-system/extensions/**`, so its own completion is
subject to the gate it introduces — the intended dogfooding case. Both outcomes were confirmed by
execution, not inferred:

1. **With the deploy fresh** (after `deploy-headless.sh` ran): `update-task-status.sh --dry-run
   postflight 83 implement <session>` printed `[deploy-check] Task 83: touched extension(s)
   verified fresh -- proceeding.` and previewed the `completed` transition (exit 0).
2. **In a scratch fixture** (never the live tree) with a deliberately staged stale extension: the
   same deployed script refused with exit 6, `[deploy-check] refusing postflight implement...`,
   and left both `state.json` status and the plan file unchanged.

## Impacts

- A source-store-touching task can no longer reach `[COMPLETED]` while its deploy is provably
  behind — closing the exact gap that let four previously-completed tasks (including this
  system's own dispatch-seq fix) claim completion while their fixes were absent from the running
  `.claude/` tree.
- `check-deploy-freshness.sh`'s advisory-only, always-exit-0 contract is now documented as tier 1
  of an explicit two-tier staleness model, so it is no longer mistaken for a gate.
- `skill_postflight_update`'s previously-silent swallowing of `update-task-status.sh`'s exit code
  is fixed as a byproduct — every existing `--phase-check=refuse` (exit 4) caller now also
  correctly observes that refusal, not only the new exit 6.

## Follow-ups

- **D6 residual** (recorded, not fixed): `/orchestrate`'s Stage MT-3 step 7 trigger predicate is
  not widened to cover `agent-system/extensions/**`; a refused task under `/orchestrate` defers
  loudly via the `deploy_pending` marker rather than converging within that same invocation.
  Widening the predicate is named as explicit follow-up work in
  `batch-orchestration-guardrails.md`'s new subsection.
- **Observed, not fixed**: `check-extension-docs.sh` reports one line_count mismatch for
  `guides/extension-development.md` not present in this task's Phase 1 baseline and not caused by
  any file in this task's `file_scope` — attributed to a concurrent sibling session's own
  in-flight work. Similarly, the Phase 8 post-deploy `verify-deploy.sh --findings` diff shows
  three new literature-extension and task-77 findings, attributable to `deploy-headless.sh`
  resyncing the whole tree (not just `core`) while a sibling session was mid-edit in the
  literature extension. Neither is caused by this task's own changes; neither was fixed (out of
  scope). See `progress/phase-7-progress.json` and `progress/phase-8-progress.json`.
- Commit-granularity residual (by design, documented in the plan's Risks table and in the new
  mechanism subsection): the freshness signal is commit-granular, not per-file; an uncommitted
  source-store edit at postflight time would report a false "fresh".

## References

- `specs/083_postflight_deploy_gate_for_source_store_tasks/plans/01_postflight-deploy-gate.md`
- `specs/083_postflight_deploy_gate_for_source_store_tasks/reports/01_postflight_deploy_gate.md`
- `specs/083_postflight_deploy_gate_for_source_store_tasks/progress/phase-{1..8}-progress.json`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — `### The Postflight Completion-Deploy Gate`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — `## Automated Exception: The Postflight Completion-Deploy Gate`
