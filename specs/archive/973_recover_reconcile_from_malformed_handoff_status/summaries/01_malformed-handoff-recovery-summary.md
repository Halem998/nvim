# Implementation Summary: Task #973

- **Task**: 973 - Make reconcile-task-status.sh recover from a malformed handoff status instead of refusing promotion
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_malformed-handoff-recovery.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`handoff_permits_promotion()` in `agent-system/extensions/core/scripts/reconcile-task-status.sh`
previously refused promotion whenever `.orchestrator-handoff.json` carried a `status` value
outside the six-value normative enum, treating an uninterpretable value as *more* suspicious than
a missing handoff — which permitted promotion unconditionally. Because
`record_refused_promotion()` writes no recoverable state for an off-enum value, this wedged the
task permanently: every reconcile pass hit the identical refusal. This task rewrote the helper
into an explicit three-way classification (exact match permits; on-enum terminal mismatch refuses
unchanged; anything else — off-vocabulary, empty, unparseable JSON, or `in_progress` — permits
with a mandatory diagnostic), consolidated the one remaining un-refactored call site in the
`partial` branch onto the same helper, and added an 11-case fixture-driven regression suite.

## What Changed

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — rewrote
  `handoff_permits_promotion()` with the three-way `case` classification, extended its docstring
  with the full contract and the do-not-re-tighten rationale (both rejected alternatives
  recorded inline), added a top-of-file header note, and consolidated the `partial` branch's
  inline duplicate handoff check onto the shared helper (previously a bare
  `[[ "$handoff_status" != "implemented" ]]` fallthrough that silently no-opped under `--dry-run`
  only).
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` — new file. An
  11-case, 14-assertion fixture-driven regression suite built on a throwaway sandbox deploy tree
  (required because `deploy-root-guard.sh` hard-fails when the script runs from the source
  store).
- `specs/973_recover_reconcile_from_malformed_handoff_status/plans/01_malformed-handoff-recovery.md` —
  all four phases marked `[COMPLETED]`, task checklists checked off with completion/deviation
  annotations.

## Decisions

- Off-vocabulary, empty (`.status` absent), and unparseable-JSON handoff statuses are treated as
  equivalent to a **missing** handoff — same permit code path, not merely an equivalent outcome —
  because they make no interpretable terminal claim, exactly like an absent handoff file. Every
  branch reaching this guard has already found the phase's success artifact on disk, so this is
  never promotion on faith alone.
- `in_progress` also permits, but with **distinct diagnostic wording** that never uses
  "off-schema" or "malformed" framing. This is the one substantive departure from the research
  report's proposed code, made after aligning with
  `context/patterns/system-defect-discrimination.md`'s `OFF_SCHEMA_STATUS` row, which states
  verbatim that `in_progress` "is a valid non-terminal marker, not a violation." Labeling it
  malformed would have invented a second, competing notion of "malformed status" contradicting
  that sibling contract (which this task did not touch, per its Non-Goals).
- On-enum terminal mismatches (`blocked`, `partial`, `failed`, or another phase's success value)
  continue to refuse exactly as before — no relaxation. This is genuine negative evidence: a
  different terminal outcome was legitimately claimed.
- The `partial` branch's inline duplicate now emits its refusal line unconditionally (not only
  under `--dry-run`) and calls `record_refused_promotion`, matching the other five call sites'
  shape exactly. This is a deliberate, called-out behavior change for on-enum non-`implemented`
  values (previously a silent no-op); `record_refused_promotion` writing `partial` on an
  already-`partial` task is an idempotent no-op transition, so this is safe.
- Both rejected alternatives are recorded directly in the script comment (not just this summary),
  per the task's explicit "do not re-tighten by reflex" concern: (1) refuse-with-diagnostic-only
  — preserves the wedge, only adds visibility; (2) a known-bad-synonym normalization table —
  unmaintainable, launders malformed writes, risks false-positive promotion.
- The regression suite's sandbox candidate order is **source-store-first**, inverted from the
  deploy-tree-first idiom used by the model test (`test-phase-heading-patterns.sh`). Discovered
  during implementation: `.claude/scripts/` is a stale, gitignored deploy mirror until the next
  explicit redeploy (per `rules/source-store-deploy-boundary.md`), so a deploy-tree-first order
  would have silently validated the OLD, pre-fix code whenever the deployed copy lagged behind —
  exactly the failure mode observed on the first suite run (cases 4-11 failed against the stale
  mirror). Source-store-first makes the suite actually test the edit this task made. Documented
  in the test file's own header comment.

## Plan Deviations

- **Task 3.2** (sandbox harness candidate order) altered: source-store-first / deploy-tree-fallback
  instead of the plan's specified deploy-tree-first / source-store-fallback. See Decisions above
  for the full rationale; this was discovered mid-implementation when the first suite run failed
  11 of 14 assertions against the stale `.claude/scripts/` mirror.
- No other deviations. All eleven planned regression cases were implemented as specified.

## Verification

- **Build**: N/A (bash scripts)
- **Tests**:
  - `bash agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` — **14
    passed, 0 failed**.
  - `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` (sibling suite,
    plausibly affected via `state-write.sh`/`update-task-status.sh` reuse) — 9 passed, 0 failed.
  - `bash agent-system/extensions/core/scripts/test-state-write-regen-timing.sh` — 3 passed, 0
    failed.
  - `bash .claude/scripts/check-task-references.sh` — repo-wide scan: **0 unexempted occurrences
    across 4 tree(s)**, `agent-system/extensions` included.
  - `bash -n agent-system/extensions/core/scripts/reconcile-task-status.sh` — parses cleanly.
    `shellcheck` was NOT run: it is not installed in this environment (`which shellcheck`
    resolved nothing). This is an honest gap, not a silently-skipped check — recorded as a
    follow-up below.
  - **Non-vacuousness proof**: reverted `handoff_permits_promotion()` and the `partial` branch to
    their pre-fix form in a scratch copy (outside the repo, in the scratchpad) and re-ran the
    suite against it. Result: **4 passed, 10 failed** — cases 4-11 (every off-vocabulary,
    `in_progress`, empty-status, unparseable-JSON, parity, and `partial`-branch case) failed
    against the old code, confirming the suite is a live regression guard, not a vacuous pass.
- **Files verified**: Yes — both touched files exist, are non-empty, and parse (`bash -n`).

**Direct demonstration of the task's stated bar** (real output, from a throwaway sandbox running
the fixed script, `--dry-run`, status=researching, artifact present):

Off-vocabulary status `success` (handoff present):
```
[reconcile] WARNING: task 1: handoff status='success' is off-schema (not one of the six legal values researched|planned|implemented|partial|failed|blocked, and not in_progress) -- treating the handoff as if absent and permitting promotion to 'researched'.
[reconcile] Task 1: status=researching, found report 01_report.md
[reconcile] Would promote: researching -> researched via postflight research
[reconcile] Would link artifact in state.json: type=report path=specs/001_demo_task/reports/01_report.md
[reconcile] Would regenerate TODO.md via generate-todo.sh
```

Same directory, handoff deleted entirely:
```
[reconcile] Task 1: status=researching, found report 01_report.md
[reconcile] Would promote: researching -> researched via postflight research
[reconcile] Would link artifact in state.json: type=report path=specs/001_demo_task/reports/01_report.md
[reconcile] Would regenerate TODO.md via generate-todo.sh
```

The two outputs are identical apart from the one extra diagnostic line in the off-vocabulary
case, which names the offending value (`success`) and the full six-value legal set
(`researched|planned|implemented|partial|failed|blocked`) — meeting the parity bar exactly: at
least as permissive as the handoff-deleted case, with a loud, non-silent diagnostic.

## Impacts

- `reconcile-task-status.sh` runs live and unattended at the entry of every `/orchestrate` run.
  Tasks whose dispatched agent wrote an off-vocabulary or malformed handoff status (the incident
  that motivated this task) will now self-heal on the next reconcile pass instead of wedging
  permanently, provided the phase's success artifact is already on disk.
- The `partial` branch's behavior changes for on-enum non-`implemented` handoff statuses: it now
  logs a refusal line unconditionally and calls `record_refused_promotion`, where it previously
  logged only under `--dry-run` and never recorded anything. This is more consistent with the
  other five call sites, not a regression.
- No change to `orchestrate-recover-outcome.sh`, `context/patterns/system-defect-discrimination.md`,
  or `docs/architecture/handoff-schema.md` — all three were explicitly out of scope and untouched
  (confirmed via `git status --short`).

## Follow-ups

- `shellcheck` could not be run in this environment (not installed). A future pass in an
  environment with `shellcheck` available should confirm no new findings relative to a captured
  pre-edit baseline, per the plan's original verification bullet.
- The Rollback/Contingency section's suggested fallback (requiring `artifact_newer_than_last_update`
  corroboration for an off-enum-status permit, if the current fix proves too permissive in
  practice) is recorded there as a follow-up task, not implemented here — this task's scope was
  the fix as specified, not a stronger evidentiary bar.

## References

- Plan: `specs/973_recover_reconcile_from_malformed_handoff_status/plans/01_malformed-handoff-recovery.md`
- Research: `specs/973_recover_reconcile_from_malformed_handoff_status/reports/01_malformed-handoff-recovery-design.md`
- Sibling contract (read, not edited): `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
