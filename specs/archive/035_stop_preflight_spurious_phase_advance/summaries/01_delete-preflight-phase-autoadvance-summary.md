# Implementation Summary: Task #35

- **Task**: 35 - Stop preflight from auto-advancing an undispatched plan phase to [IN PROGRESS]
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T00:00:00Z
- **Completed**: 2026-08-12T02:35:00Z
- **Effort**: ~3 hours
- **Dependencies**: 16, 33 (both completed)
- **Artifacts**: plans/01_delete-preflight-phase-autoadvance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Deleted `update_plan_file()`'s preflight-only "auto-advance the first `[NOT STARTED]` phase to
`[IN PROGRESS]`" convenience in `update-task-status.sh`, which independently re-derived the
target phase with a narrower match criterion than the orchestrator's own dispatch-selection scan
and could therefore mark an undispatched later phase `[IN PROGRESS]`, feeding a fabricated
territory-conflict signal into hard-mode reasoning. Added non-vacuous regression coverage in two
test suites (each carrying a required positive control), retired the now-false comment in
`skill-orchestrate-hard/SKILL.md`, and — discovered only during the final gate sweep — fixed a
third suite (`test-resume-scan-nonconformance.sh`) whose structural assertion was pinned to the
exact code this task deletes.

## What Changed

- `agent-system/extensions/core/scripts/update-task-status.sh` — deleted the entire
  `if [[ "$operation" == "preflight" ]]` auto-advance block (comment through closing `fi`) and its
  3-line dry-run preview; added an explanatory comment at the retained
  `target_status != implement` guard recording that it is the sole bound on plan-file side
  effects and that the function no longer touches per-phase markers.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — appended Case 10: a
  non-dispatching implement preflight leaves plan phase headings byte-identical, with a required
  positive control (exit 0 and the plan-level `[IMPLEMENTING]` stamp).
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — extended
  `build_fixture_repo`'s copy loop (and the top-of-file environment-check loop) with
  `update-plan-status.sh`/`update-phase-status.sh`; added a Group 4 case exercising
  `skill_preflight_update` with `target_status="implement"` against a fixture that actually
  contains a plan file, with a dual positive control (state.json status + plan-level stamp).
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — rewrote the comment
  block preceding the implement-dispatch `skill_preflight_update` call to describe the call's
  actual remaining side effects instead of the deleted auto-advance.
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` — updated Site D
  (not in the original file scope; discovered via Phase 6's own blast-radius grep) to assert the
  ABSENCE of the deleted `has_nonconforming_phase_headings "$plan_file"` guard invocation instead
  of its presence, confirming a full deletion.

## Decisions

- Followed the plan's deletion strategy (not gating): no code path depends on the plan file
  already showing `[IN PROGRESS]` before an agent's own self-mark.
- Left the `--phase-check` postflight backstop's `has_nonconforming_phase_headings` sourcing and
  usage fully untouched — a Non-Goal, and it lives in a structurally separate PHASE 0 section of
  the same file.
- Did not edit `skill-orchestrate/SKILL.md` — the fresh Phase 5 grep found zero matching prose
  there, confirming the plan's co-maintenance hypothesis.
- Fixed `test-resume-scan-nonconformance.sh`'s Site D (outside the original FILE SCOPE) rather
  than leaving it red or reverting Phase 1: its assertion was a structural check on the exact
  block this task deletes, not a behavioral dependency on the deleted marker, and the plan's own
  Testing & Validation checklist ("every other test suite referencing `update-task-status`
  passes") and Phase 6 task text ("re-run any orchestration-adjacent suites... so the deletion's
  blast radius is checked, not assumed") both require it green.
- Routed the Phase 4 fixture's status setup through the fixture's own copied `state-write.sh`
  rather than a hand-rolled `jq ... > tmp && mv` sequence, after `lint-state-writer-boundary.sh`
  flagged the latter — `test-skill-base-lifecycle.sh` carries no whole-file allowlist entry for
  that pattern (unlike `test-update-task-status.sh`'s deliberate corrupt-state fixture).

## Plan Deviations

- **Fixed `test-resume-scan-nonconformance.sh`** (Phase 2): not listed in the plan's Phase 2
  "Files to modify" or the delegation FILE SCOPE. Discovered when the first `verify-deploy.sh` run
  in Phase 2 surfaced a real gate-8 (`run-all.sh`) failure — this suite's Site D structurally
  asserted the presence of the deleted auto-advance's `has_nonconforming_phase_headings` guard.
  Updated the assertion to check for absence instead. Necessary for the plan's own
  Testing & Validation checklist and Phase 6 blast-radius requirement; see Plan's Phase 2
  Verification notes for the full reasoning.
- **Routed Phase 4's fixture status write through `state-write.sh`** instead of the hand-rolled
  jq+mv pattern used elsewhere in the same suite family, after the Phase 6 gate sweep's
  `lint-state-writer-boundary.sh` check flagged it. Not a plan deviation in outcome (the case still
  does exactly what Phase 4 specifies), only in the fixture-setup mechanism.

## Verification

- Build: N/A (bash scripts and markdown only)
- Tests: `test-update-task-status.sh` 23/0, `test-skill-base-lifecycle.sh` 18/0,
  `test-resume-scan-nonconformance.sh` 39/0, `test-reconcile-handoff-status.sh` 14/0 — all four
  `update-task-status`-touching suites green (94 cases, 0 failures)
- Files verified: Yes — `bash -n` clean on all edited shell scripts; deployed tree matches
  source store via `diff` for all five edited files
- `verify-deploy.sh`: 22/23 checks pass. The sole remaining failure (gate 10,
  `validate-state.sh --deep`, two `blockers`/`priority` unknown-field findings against task 52 in
  the real `specs/state.json`) is pre-existing — `specs/state.json` was already modified in
  `git status` before this dispatch began any edit — and unrelated to `update-task-status.sh`'s
  per-phase marker logic.

## Acceptance Criteria Discharge

- **AC 1 / AC 5** (no preflight can mark an undispatched phase `[IN PROGRESS]`): discharged by
  Phase 1's deletion, confirmed structurally (`grep -c 'update-phase-status.sh'` on the
  auto-advance's actual call site returns 0; the only remaining hits are two pre-existing,
  unrelated `--phase-check` backstop comments) and behaviorally (Case 10 and the Group 4
  implement-target case both assert byte-identical phase headings after a non-dispatching
  preflight; the "guard's teeth" sanity check reproduced the original defect against the pre-fix
  script in an isolated scratch fixture, confirming the new assertions would catch a regression).
- **AC 2** (deletion justification recorded durably): discharged via the code comment at the
  retained `target_status != implement` guard in `update-task-status.sh` and this plan/summary.
- **AC 3** (research/plan slots unreachable, scope-widening premise refuted): recorded, not
  code-changed, per the plan's explicit Non-Goal — `update_plan_file()`'s unconditional early
  return on `target_status != implement` predates this task (verified via `git log -p` at
  research time) and was reconfirmed untouched by every phase's diff read-through.
- **AC 4** (non-vacuous regression coverage): discharged by Case 10
  (`test-update-task-status.sh`) and the Group 4 implement-target case
  (`test-skill-base-lifecycle.sh`), each carrying a required positive control proving the fixture
  plan file was actually found and `update_plan_file()`'s plan-file logic was actually entered.
- **Co-maintenance contract** (both orchestrate SKILL.md copies agree): discharged — the fresh
  Phase 5 grep found matching prose only in `skill-orchestrate-hard/SKILL.md` (rewritten) and none
  in `skill-orchestrate/SKILL.md` (left untouched, as the plan predicted).

## Impacts

- Hard-mode per-phase dispatch (`skill-orchestrate-hard`) can no longer receive a
  fabricated-territory-conflict signal caused by a preflight advancing a phase heading that no
  agent actually worked on.
- `update-task-status.sh`'s implement preflight is now a pure status-transition operation for
  plan-file purposes: it writes only the plan-level `[STATUS]` stamp, never a per-phase marker.

## Follow-ups

- None. The pre-existing, unrelated `validate-state.sh --deep` finding against task 52's
  `blockers`/`priority` fields in `specs/state.json` is out of scope for this task and was named
  explicitly rather than silently absorbed.

## References

- Plan: `specs/035_stop_preflight_spurious_phase_advance/plans/01_delete-preflight-phase-autoadvance.md`
- Research: `specs/035_stop_preflight_spurious_phase_advance/reports/01_preflight-phase-advance-defect.md`
- Progress files: `specs/035_stop_preflight_spurious_phase_advance/progress/phase-{1..6}-progress.json`
