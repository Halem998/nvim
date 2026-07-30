# Implementation Summary: System-Defect Discrimination Predicate

- **Task**: 951 - Define the system-defect discrimination predicate and detection-point registry
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_system-defect-discrimination.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Both `file_scope` deliverables already existed and were committed by this task's research phase,
which the planning pass independently re-verified against all 20 claims. This implementation
closed the four gaps the plan identified in `system-defect-discrimination.md`: one substantive
(Signal A provably excluded a live-observed violation class), two precision/completeness gaps,
and one consistency gap discovered during the Phase 4 self-review. `orchestrator-critical-paths.json`
required no change and was verified byte-identical to its delivered state throughout.

## What Changed

- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — corrected an
  off-by-two citation range (`lines 92-95` -> `lines 92-93`); added a fifth Signal A instance,
  `ARTIFACTS_MISSING_ON_SUCCESS`, covering a `null`/absent/empty `artifacts` field on a success
  status (both `return-metadata-file.md` and `handoff-schema.md` mark the field required),
  together with the empirical `jq` evidence that neither of the existing detector's two arms fires
  on it; added a Class (b) note naming the handoff-present branch's total absence of any
  `artifacts` shape check as a fourth, distinct "undetected" outcome, separate from the three named
  classes; extended the recursion guard's "Considered and excluded" paragraph with
  `scripts/reconcile-task-status.sh` and `scripts/check-extension-docs.sh`, reasoned out of the
  recursion-guard's scope but flagged as an open follow-on for the self-modification-hazard
  consumer; and, found during the Phase 4 top-to-bottom consistency read, added the new instance
  name to the deduplication rule's "Identity key" enumeration, which had not been updated when the
  Signal A table grew from four rows to five.
- `agent-system/extensions/core/index-entries.json` — `line_count` for
  `patterns/system-defect-discrimination.md` refreshed from 285 to 345.

## Decisions

- The new Signal A row is stated as having no current detector, cross-referencing the Class (b)
  detection-hole note rather than naming a site that does not actually check it — preserving the
  scope boundary that this task defines what counts as a violation, not what fires.
- The handoff-present branch's total absence of an `artifacts` check is named as a fourth outcome
  distinct from the registry's three existing classes (loud-but-unactioned / computed-but-discarded
  / ephemeral), rather than folded into class (b), because folding it in would understate the gap:
  a downstream implementer adding a consumer arm to the five recovered-path sites would leave this
  surface completely uncovered.
- The two additional orchestrator scripts (`reconcile-task-status.sh`, `check-extension-docs.sh`)
  are reasoned out of the recursion guard (neither implements the discrimination/recording
  pipeline itself) but their possible relevance to the separate self-modification-hazard consumer
  is named as an explicit, undecided follow-on rather than silently dropped.
- No durable anchor existed for the "Related documentation" cross-reference the task description
  asked for (`command-structure.md` does not exist; no file uses the phrase "source-store lane");
  per the plan's own instruction, nothing was added rather than inventing a link.

## Plan Deviations

- None (implementation followed plan). One additional in-scope fix — the dedup-rule enumeration
  update — was surfaced by Phase 4's own "confirm internal consistency" task, which explicitly
  calls for exactly this kind of correction; it is recorded here as work product of that task, not
  a deviation from it.

## Verification

- Build: N/A (documentation/markdown task)
- Tests: N/A
- Files verified: Yes — all four phases' verification criteria passed:
  - `check-task-references.sh` exits 0 (re-run after every phase).
  - `orchestrator-critical-paths.json` untouched: absent from every phase's diff, byte-identical
    to its delivered state, `critical_paths` length still 13.
  - Signal A instance table has exactly five rows; the fifth (`ARTIFACTS_MISSING_ON_SUCCESS`)
    is explicitly marked as having no current detector.
  - The `jq` probes (`(.artifacts // []) | length` and `.artifacts[0].path // ""` against
    `{"artifacts": null}`) reproduce exactly the `0` / empty-with-exit-0 outputs the new paragraph
    claims; the bare-string-array contrast case reproduces exit 5 via `jq_artifact_failure`.
  - The "system defect iff A AND B" classification sentence and the "A schema-conformant failure
    is always task work" section heading are unmodified in force.
  - `git diff --name-only` across all four phase commits contains zero `.claude/**` paths.
  - No recorder script, no new `evidence_reason` consumer arm, no hook change, no command change
    anywhere in the diff.
  - `bash .claude/scripts/generate-context-line-counts.sh --check` reports 461/461 exact match
    (0 mismatches) across all extensions after the `index-entries.json` update.
  - `bash .claude/scripts/check-extension-docs.sh` shows no new failure attributable to this
    task's changes; the one remaining `FAIL` (`scripts/tests/test-reconcile-handoff-status.sh`
    not in `provides.scripts`) was confirmed pre-existing via `git stash` against the
    pre-Phase-4 committed state, and is unrelated to this task's file scope.

## Impacts

- Establishes the normative discrimination contract that downstream recorder/wiring work (a
  separate, forward-referenced task) must encode rather than re-derive.
- Names a previously-invisible detection gap (the handoff-present branch's total absence of an
  `artifacts` shape check) that a downstream implementer wiring the existing five recovered-path
  consumer sites would otherwise believe was fully covered.
- Leaves two named, undecided follow-ons for future work: (1) building a detector for
  `ARTIFACTS_MISSING_ON_SUCCESS` on both the recovered and handoff-present paths, and (2) deciding
  whether `reconcile-task-status.sh` and `check-extension-docs.sh` belong in `critical_paths` for
  the self-modification-hazard consumer (independent of this task's recursion-guard reasoning).

## Follow-ups

- Build the recorder script (`scripts/system-defect-record.sh`) and wire the detection sites —
  explicitly out of this task's scope boundary, per the document's own forward reference.
- Decide whether `reconcile-task-status.sh` and `check-extension-docs.sh` should be added to
  `critical_paths` for the self-modification-hazard admission check (a separate question from the
  recursion guard this task settled).
- The pre-existing `check-extension-docs.sh` failure for
  `scripts/tests/test-reconcile-handoff-status.sh` (not registered in `provides.scripts`) remains
  open and unrelated to this task.

## References

- `specs/951_define_system_defect_discrimination_predicate/plans/01_system-defect-discrimination.md`
- `specs/951_define_system_defect_discrimination_predicate/progress/phase-1-progress.json`
  through `phase-4-progress.json`
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (verified
  unchanged)
