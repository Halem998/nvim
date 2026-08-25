# Implementation Summary: Task #17

- **Task**: 17 - fix_return_meta_lifecycle_ordering
- **Status**: [COMPLETED]
- **Started**: 2026-08-18T02:25:00Z
- **Completed**: 2026-08-18T03:40:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_return-meta-lifecycle-ordering.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed a lifecycle-ordering defect where `skill_cleanup()` deleted `.return-meta.json` at the
skill's own Stage 9, always before the calling command's `command-gate-out.sh` (CHECKPOINT 2) or
CHECKPOINT 3 commit block ever read the file. This made `command-gate-out.sh`'s entire
post-metadata body — defensive status correction and `skill_validate_task_artifacts` —
structurally unreachable on all five commands that call it, and made the missing-metadata
warning fire identically on every successful run and every genuine crash. All six plan phases
completed and verified.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_cleanup()` no longer removes
  `.return-meta.json`; only `.postflight-pending` and `.postflight-loop-guard`. Header comment
  rewritten to document the new ownership model.
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` — Stage 16 now deletes
  `.return-meta.json` inline (the one skill with no downstream command-level consumer).
- `agent-system/extensions/core/scripts/command-gate-out.sh` — the "not found" warning rewritten
  to name the real cause/consequence (a genuine failure signal, not a routine event); added
  explanatory comments on why absence is now meaningful and an explicit "must not delete this
  file" note at the end of the script.
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md`, `revise.md`,
  `orchestrate.md` — each given exactly one deletion site for `.return-meta.json` on its
  single-task path, positioned after the last consumer of the file. `implement.md` deletes on
  both the completion and partial branches; `orchestrate.md` deletes on the completion branch
  only (the partial/paused branch deliberately keeps the file for
  `orchestrate-stage5-gates.sh`'s outcome-recovery fallback).
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md` — each given a
  per-task deletion loop in their multi-task batch commit step (Step 4), closing a leak these
  loops would otherwise have had (they bypass `command-gate-in.sh`/`command-gate-out.sh` and
  never reach the single-task CHECKPOINT 3).
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` — Stage 9 description
  and Ordering section updated; added a full per-command `.return-meta.json` reader table and a
  "why both gate-out mechanisms are retained" subsection.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — `.return-meta.json`
  row's Reader/Cleanup-site cells rewritten to reflect the new ownership model.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — updated the
  allowed-operations table and the worked example to reflect that `skill_cleanup()` no longer
  removes the metadata file.
- `agent-system/extensions/core/context/patterns/file-metadata-exchange.md` — updated the
  "Cleanup Patterns" section (found during the Phase 5 grep sweep, beyond the plan's enumerated
  list), which had presented the pre-fix assumption as the sanctioned pattern.

## Decisions

- Implemented the research report's recommended direction (b) refined: ownership of
  `.return-meta.json`'s deletion moves from the skill's shared `skill_cleanup()` to each calling
  command's own true last consumer, rather than reordering DELEGATE/GATE-OUT or archiving the
  file to a second location.
- Both currently-dead `command-gate-out.sh` mechanisms (defensive status correction,
  `skill_validate_task_artifacts`) were retained rather than deleted, per the binding constraint
  and the research's reasoning: the correction is an independent second reader guarding a
  non-`set -e` call, and the validation sweep is whole-directory, strictly broader than each
  skill's own single-artifact check.
- `/orchestrate`'s multi-task path (`skill-orchestrate` Stage MT-4) was investigated and
  confirmed to need no deletion site: it dispatches directly to agents, bypassing the skill layer
  and `skill_cleanup` entirely (so Phase 1's change is a no-op there), and the file serves an
  ongoing multi-cycle recovery role there — adding a deletion site would risk exactly the
  regression the binding constraints prohibit.

## Plan Deviations

- **Task 6.9** (Real-run spot-check) altered: substituted a fixture-harness demonstration (the
  actual modified source files run end-to-end in the session scratchpad, including the real
  `update-task-status.sh` write path) for a live `/plan`/`/implement` dispatch. Reasoning: a live
  dispatch right now would exercise the deployed `.claude/` tree, a disposable artifact
  regenerated separately from the source store this task edits — without an intervening
  deploy/regenerate step it would not exercise any of this task's changes — and this dispatch is
  itself a live, in-flight `/implement` run of this same self-modifying system, so a nested live
  dispatch mid-flight carries the self-modification risk the binding constraints caution against.

## Verification

- Build: N/A (no build system; `bash -n` parses clean for both modified scripts)
- Tests: Fixture-harness behavioral demonstration — all three acceptance criteria captured with
  output (no false warning on success; distinguishable genuine-failure warning; defensive
  correction observed to execute and state.json actually corrected, the first observed execution
  of that code path)
- Files verified: Yes — all six phases' verification criteria checked and recorded in the plan

## Impacts

- `command-gate-out.sh`'s defensive status correction and artifact-validation sweep are now
  reachable on every successful single-task command run, for the first time.
- `research.md`'s CHECKPOINT 3 `git add` no longer fails atomically on a missing
  `.return-meta.json` — a standalone `/research` run now reliably commits its report, `TODO.md`,
  and `state.json`.
- The missing-metadata warning is now a genuine, actionable diagnostic signal rather than routine
  noise.
- `/orchestrate`'s completion and resume behavior is unchanged, including its outcome-recovery
  fallback on the paused/partial branch and its multi-task path.

## Follow-ups

- None required by this task. The research report separately noted `orchestrator-postflight.sh`
  as an orphaned script with zero live call sites — explicitly out of scope here, left for a
  possible future cleanup task.

## References

- Plan: `specs/017_fix_return_meta_lifecycle_ordering/plans/01_return-meta-lifecycle-ordering.md`
- Research: `specs/017_fix_return_meta_lifecycle_ordering/reports/01_return-meta-lifecycle-ordering.md`
- Progress files: `specs/017_fix_return_meta_lifecycle_ordering/progress/phase-{1..6}-progress.json`
