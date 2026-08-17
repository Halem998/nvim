# Implementation Summary: Task #11

- **Task**: 11 - expand_defect_class_vocabulary
- **Status**: [COMPLETED]
- **Started**: 2026-08-10
- **Completed**: 2026-08-10
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_defect-class-vocabulary-expansion.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added exactly three new `defect_class` values — `SESSION_LOCK_CONTENTION`,
`HOOK_REGEX_BOUNDARY_DEFECT`, `DEPLOY_ORPHAN_DRIFT` — to the closed enum at both of its
enumeration sites: the `case` validator in `system-defect-record.sh` and the Signal A table in
`system-defect-discrimination.md`. No existing class was renamed, reworded, or removed, and no
detector was wired for the three new classes, matching the document's existing
"not currently computed anywhere" precedent.

## What Changed

- `agent-system/extensions/core/scripts/system-defect-record.sh` — widened the closed enum from
  ten to thirteen values at all four locations where the vocabulary or its count is stated: the
  header comment, the `usage()` required-args list, the `case "$defect_class"` validation arm, and
  the invalid-value error message. All ten pre-existing literals are byte-identical in the diff.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — appended three
  rows to the Signal A table (after `STATE_SYNC_DIVERGENCE`), each using the
  `ARTIFACTS_MISSING_ON_SUCCESS` row's "not currently computed anywhere" convention, and added a
  paragraph to the "Extending the Signal A vocabulary is an explicit decision" section naming the
  three new instances and stating no existing instance was reworded and no recorder was wired. All
  ten pre-existing table rows are byte-identical in the diff.

## Decisions

- Confirmed the plan's Scope Hypotheses before editing rather than trusting stated line numbers:
  the script's vocabulary/count occurrences matched the hypothesized four locations exactly, and
  the document's Signal A table had exactly 10 rows with no bare count word outside the table.
- For Phase 3's positive round trip, verified enum-validation pass-through (no exit 1 from the
  `case` arm) rather than a full end-to-end script run, because `system-defect-record.sh` sources
  `deploy-root-guard.sh` (line 195) — after enum validation (lines 160-170) — which refuses to run
  from the agent-system source store by design. Running the deployed `.claude/scripts/` copy would
  have required a deploy, which is out of this task's scope and would have violated the plan's own
  expectation that `.claude/` shows zero new-class hits until an operator-initiated deploy runs.
  All three positive invocations passed the `case` arm cleanly and failed only later, at the
  unrelated guard.
- Excluded `system-defect-record.sh` itself from the Phase 3 producer-audit hit count: its own
  header/usage text contains the literal string `--defect-class` nine times as self-documentation,
  not as a caller. Excluding it reproduces the plan's hypothesized 17 call sites across 8 files
  exactly.

## Plan Deviations

- **Task 3.2** (positive round trip) altered: verified the enum-validation pass-through via the
  `deploy-root-guard.sh` guard's later, unrelated failure, rather than a full end-to-end write to
  `specs/events.jsonl`, for the source-store reason above.
- **Task 3.6** (git status scope check) altered: by Phase 3, the two source-store files no longer
  appeared as "modified" in `git status --short` because Phases 1 and 2 each committed their own
  green sub-step per the Commit-Per-Green-Substep Mandate. Verified the underlying assertion (no
  `.claude/**` write) directly via `git status --short` and a recursive grep for the three new
  class names under `.claude/`, both returning zero hits.

## Verification

- Build: N/A
- Tests: Passed — `bash -n` on the script exits 0; script-derived and document-derived 13-value
  class sets are identical; all three new classes pass enum validation; a bogus class
  (`NOT_A_REAL_CLASS`) still exits 1 with the invalid-class message; `specs/events.jsonl` line
  count unchanged (1303 before and after) confirming no stray writes from the round-trip
  invocations; producer audit shows 17 `--defect-class` call sites across 8 files, all passing
  fixed literals with no enum dispatch; no `ten`/`ten-value` count word remains describing the
  vocabulary size; no task-number citation in either modified file; no file under `.claude/**`
  created or modified.
- Files verified: Yes

## Impacts

- Three previously-unnamed defect shapes (session/lock self-contention, hook-regex path-depth
  boundary defects, deploy orphan/drift) now have a name in the Signal A vocabulary that a future
  detector or manual `system-defect-record.sh` call can use. No detector is wired yet — naming the
  vocabulary and instrumenting a detection site remain separate, sequential pieces of work, per the
  document's own precedent.
- All 17 existing `--defect-class` call sites continue to validate unchanged; none required a code
  change.

## Follow-ups

- The dedup rule's identity-key list in `system-defect-discrimination.md` names only five of the
  now-thirteen instances. This staleness predates this task and is out of scope here; recommend a
  separate documentation-hygiene task to reconcile it.
- No detector is wired for `SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, or
  `DEPLOY_ORPHAN_DRIFT` — this was an explicit non-goal of this task. Wiring a recorder to the
  underlying defect sites (the lock-acquire session-id mismatch, the 3-digit handoff regex, the
  additive-only deploy merge) is downstream work.

## References

- specs/011_expand_defect_class_vocabulary/plans/01_defect-class-vocabulary-expansion.md
- specs/011_expand_defect_class_vocabulary/reports/01_defect-class-vocabulary-gap.md
- specs/011_expand_defect_class_vocabulary/progress/phase-1-progress.json
- specs/011_expand_defect_class_vocabulary/progress/phase-2-progress.json
- specs/011_expand_defect_class_vocabulary/progress/phase-3-progress.json
