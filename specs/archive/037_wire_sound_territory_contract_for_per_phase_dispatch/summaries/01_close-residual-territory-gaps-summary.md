# Implementation Summary: Task #37

- **Task**: 37 - Close the two residual gaps left by the territory/handoff work
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T07:59:37Z
- **Completed**: 2026-08-12T09:15:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 33, 35 (both landed)
- **Artifacts**: plans/01_close-residual-territory-gaps.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the two residual gaps left by the territory/handoff work landed previously: watcher/monitor
teardown as an operational obligation in `context/contracts/wrap-up.md`, and a recorded base-mode
territory decision (base mode does NOT gain a `territory` dispatch key). Also rescoped
`context/contracts/territory.md`'s opening and Template preamble to match its actual
single-phase-dispatch consumer, and tied the STOP-and-report duty into both the hard and base
implementation agent files. All six phases completed; Phase 1's re-verification of the five
already-landed items confirmed no drift before any edits began.

## What Changed

- `agent-system/extensions/core/context/contracts/wrap-up.md` — added `## Teardown Precedes the
  Terminal Handoff Write` section (between the Defect-6 ordering section and Build-Green
  Invariant) stating the watcher/monitor/background-job teardown obligation, with a one-line
  pointer to `context/patterns/dispatch-report-not-termination.md` and a standing-limitation
  sentence.
- `agent-system/extensions/core/context/contracts/territory.md` — rescoped the opening paragraph
  to name `skill-orchestrate-hard`'s single-phase dispatch as the shipped consumer (retaining the
  `H7` identifier), and changed the Template preamble from "each parallel dispatch context" to
  "each dispatch context". Left the Template body, "Explicit removal note", and all other
  sections untouched.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added a `**Decision
  record**:` / `**Asymmetry decision (recorded, ... so the two visibly agree)**:` block adjacent
  to the Stage MT-3 `session_active` deferral branch, recording that base mode does not gain a
  `territory` dispatch key, that its multi-task dispatch is genuinely concurrent by construction
  (the BATCHING RULE), and that `file_scope` deferral is admission-time only and structurally
  blind to a woken predecessor from an earlier cycle — named explicitly as an OPEN residual gap.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — added one mirrored
  acknowledgment paragraph adjacent to the existing "Asymmetry decision (recorded, not merely
  implied)" record, citing the base engine's record. The `territory` dispatch key and
  `concurrency_note` were not touched (verified byte-identical to the Phase 1 scratch copy).
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — extended Stage 3.6
  ("Territory Check") with a fifth numbered step covering the STOP-and-report duty, pointing at
  `context/contracts/territory.md` and `context/patterns/dispatch-report-not-termination.md`. The
  gate line and existing four steps are unchanged.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — added a new "Stage 3.6:
  Observation Duty" section (self-contained, no dependence on a `territory` delegation-context
  parameter) with the same STOP-and-report obligation and a one-line pointer.
- `agent-system/extensions/core/index-entries.json` — updated `contracts/territory.md`'s
  `summary` field to drop the "for parallel dispatch"-only framing that now contradicted the
  rescoped opening; regenerated `line_count` for `contracts/wrap-up.md` (194 -> 209) and
  `contracts/territory.md` (107 -> 111) via `generate-context-line-counts.sh --write`.

## Decisions

- Base mode does NOT gain a `territory` dispatch key or `owned_files`/`read_only_files`/
  `forbidden_files` declaration — recorded per the plan's predetermined decision, with the
  woken-predecessor blindness of `file_scope` deferral named explicitly as an OPEN gap (not
  covered by `file_scope`).
- The Phase 4 decision record was placed adjacent to the Stage MT-3 `session_active` branch
  (one of the two sites the plan offered) rather than after the Stage MT-4 BATCHING RULE, since
  that is where a future reader investigating the deferral's limitation will naturally look.
- The territory.md rescope and the Phase 4 SKILL.md edits were each treated as atomic batches per
  the plan's `Commit Mode: atomic-batch` declaration — committed once, at each phase's declared
  green criterion, not per intermediate file.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation/contract task)
- Tests: N/A
- Files verified: Yes — all six phases' verification criteria confirmed directly against source,
  see the per-phase progress files under `progress/`.

Acceptance criteria confirmed:
1. `wrap-up.md` carries the teardown obligation before the terminal handoff write, as a pointer
   (`grep -inE 'watch|monitor|background|teardown'` now returns hits; previously none).
2. The base-mode decision record exists in `skill-orchestrate/SKILL.md`, is mirrored in
   `skill-orchestrate-hard/SKILL.md`, and names the woken-predecessor blindness of `file_scope`
   deferral explicitly as an open gap.
3. `territory.md`'s opening and Template preamble both describe today's single-phase-dispatch
   consumption, verified by a top-to-bottom read.
4. Phase 1's verification greps re-run clean; the hard engine's `concurrency_note` string is
   byte-identical to the Phase 1 scratch copy; `git diff --stat` for both SKILL.md files and both
   agent files shows purely additive, single-hunk changes.
5. `ls agent-system/extensions/*/context/patterns/dispatch-report-not-termination.md` returns
   exactly one path; every mention added by Phases 2, 4, and 5 is a one-line pointer, never a
   restatement.

Gate scripts: `generate-context-line-counts.sh --check` clean (0 mismatches, was 2);
`check-extension-docs.sh` PASS across all 20 extensions; `deploy-headless.sh` ran successfully
before any deployed-tree verification; `lint-contract-compliance.sh` PASS (24/24);
`lint-agent-contracts.sh` PASS (33/33). Source-store boundary held: `.claude/` is gitignored and
`git status --short` shows no tracked `.claude/**` modification.

## Impacts

- Future hard-mode dispatches now have an explicit, checkable teardown obligation for any
  watcher/monitor/background job they arm, closing a defect-inducing silent gap.
- The base-vs-hard territory asymmetry is now a recorded, mutual decision rather than an implicit
  omission — any future proposal to add a `territory` key to base mode must first address the
  named open gap (woken-predecessor blindness) rather than re-litigating settled ground.
- `territory.md` no longer misdescribes its own consumer, reducing the risk of a future reader
  concluding the contract is unused because "parallel dispatch" sounds inapplicable to today's
  single-phase-at-a-time hard engine.
- Both implementation agents now carry an explicit STOP-and-report duty tied to observed foreign
  work, independent of whether territory parameters are present.

## Follow-ups

- None.

## References

- `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/plans/01_close-residual-territory-gaps.md`
- `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/reports/01_close-two-residual-gaps.md`
- `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/progress/phase-{1..5}-progress.json`
