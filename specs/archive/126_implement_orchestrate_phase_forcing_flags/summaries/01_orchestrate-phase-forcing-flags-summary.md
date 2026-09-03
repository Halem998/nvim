# Implementation Summary: Task #126

- **Task**: 126 - Implement orchestrate phase forcing flags
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T03:10:00Z
- **Effort**: ~3 hours
- **Dependencies**: Task 117, Task 122 (both completed)
- **Artifacts**: plans/01_orchestrate-phase-forcing-flags.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented design decision A2 (Phase-Forcing Flags): a composable `--research`/`--plan`/
`--implement` flag surface on `/orchestrate` that forces a lifecycle phase to re-run even when
the task has already progressed past it, opens a new `MM_` artifact round for the forced work,
and never regresses the task's status. All 7 phases of the plan landed across 5 dependency
waves, entirely in `agent-system/extensions/core/**` (never `.claude/**`).

## What Changed

- `agent-system/extensions/core/scripts/parse-command-args.sh` — new `FORCE_PHASES_FLAG` export:
  three detection blocks accumulating in canonical lifecycle order (research, plan, implement)
  regardless of command-line token order, three strip rules, header docs.
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` — new
  `STATUS_VOCABULARY_LIFECYCLE_RANK` map and two new functions, `status_vocabulary_rank` and
  `status_vocabulary_would_regress`, over the linear-progress subset of the status enum.
- `agent-system/extensions/core/commands/orchestrate.md` — `FORCE_PHASES_FLAG`/`force_phases`
  threaded through all 8 sites (argument-hint, 3 new Options rows, Exports comment, prose
  paragraph, 2 `args:` strings, 2 JSON delegation contexts) plus a Constraints sentence.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — new
  `### Stage 2b: Forced-Phase Queue Initialization` (ordered `force_queue`, phase-to-handler map,
  `resolve_cycle_artifact_number()`, observability write, empty-queue invariant, end-to-end chain
  note); Stage 3's 3c rewritten as a strictly-ordered 3-branch decision (terminal check first,
  then forced dispatch, then status-derived dispatch); a forced-sequence-exhausted terminal
  condition added to Stage 7; one Stage 4 preamble sentence declaring `artifact_number` on every
  handler's `context` object; append-only bullets on Stage 1 and Stage MT-1.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update` gains
  positional 7, `status_clamp_mode`. `"monotonic-max"` resolves `status-vocabulary.sh` and skips
  the status write (rc 0) on a would-be regression; absent/empty (every pre-existing call site)
  is byte-for-byte unchanged. Positional 6 deliberately untouched (reserved for a sibling task).
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` — positional 20,
  `force_invoked`; the three `skill_postflight_update` call sites now reach positional 7; a new
  artifact-round-advance block (after artifact linking, before the off-schema halt decision)
  advances `next_artifact_number` unconditionally on `researched` (P1, closing the pre-existing
  "/orchestrate never increments" gap) and on a forced `planned`/`implemented` dispatch (P2).
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` (new) — 19-case regression
  suite with a deliberately-inverted (source-store-first) candidate resolution for the four
  task-edited files; harness-sanity, parser, rank, clamp, clamp-opt-out, arity-preservation, and
  artifact-advance cases.
- `agent-system/extensions/core/merge-sources/claudemd.md` — `/orchestrate` command-table row
  updated with the three flags and their composition semantics.
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` — Stage 7 usage line
  and "Not covered by this shared call" paragraph updated to document the optional clamp
  parameter and confirm the inline-increment statement remains accurate for shared-pattern
  importers.
- `specs/state.json` / `specs/TODO.md` — new task 138, filed for the grouped multi-task
  (Stage MT-*) deferral, including the design-report WORK-item-3 premise correction.

## Decisions

- `orchestrator-postflight.sh` (the file the task description and design report both named for
  the artifact-round advance) was confirmed dead code for `/orchestrate` — zero call sites in
  `skill-orchestrate/SKILL.md` — and removed from scope; `orchestrate-stage5-postflight.sh` is
  the real target and is unmodified in `git status` verification terms (i.e. the former stays
  untouched while the latter carries the change).
- Artifact-numbering scope resolved as (a), bounded to single-task mode: the pre-existing
  "/orchestrate never increments `next_artifact_number`" gap is closed as a prerequisite (P1),
  since a forced phase cannot open a new round without a base increment mechanism to extend.
- Composition semantics: `--research --plan` means "force research, then plan, then STOP" —
  ordered by canonical lifecycle order, not command-line token order, and never falls through to
  status-derived dispatch after the forced sequence is exhausted.
- The monotonic-max clamp is strictly opt-in (new trailing parameter, empty default) so the four
  existing unforced status-transition paths are provably unaffected.
- Positional-slot partitioning on `skill_postflight_update` (position 7 only, position 6 left
  untouched) and stage/region partitioning on `SKILL.md` (a new Stage 2b, append-only bullets,
  handler bodies referenced by pointer) let this task land without colliding with two concurrent
  sibling tasks editing the same three files.

## Plan Deviations

- None (implementation followed plan). The plan's own Scope Hypothesis on Phase 5 (positional 6
  of `skill_postflight_update` either absent or sibling-owned with an `${TASK_DIR:-}` fallback)
  resolved to "absent" on re-read at implementation time, exactly one of the two anticipated
  branches — not a deviation from the plan, which explicitly anticipated and instructed this
  check.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `test-force-phases.sh` 19/19 standalone; the full source-store `run-all.sh`
  sweep (58 suites across every loaded extension) passes 58/58 including the new suite;
  `test-status-vocabulary.sh` and `test-skill-base-lifecycle.sh` (deployed tree, unmodified) both
  pass, recorded as deployed-copy regression checks per the plan's stale-deploy protocol, not as
  evidence about this task's source-store edits.
- Files verified: Yes — `bash -n` clean on all four modified shell files; scoped `git diff`
  confirmed no `#### State:` handler body or Stage 3.5 Dispatch Prep hunk in `SKILL.md`;
  `git status` confirms `scripts/orchestrator-postflight.sh` and
  `scripts/tests/test-skill-base-lifecycle.sh` remain unmodified throughout;
  `check-task-references.sh` reports 0 unexempted occurrences.
- Known limitation (recorded honestly in the plan's own Testing & Validation checklist): the six
  "Definition of done" scenarios describing literal `/orchestrate N --research [...]` command
  invocations were verified by code review of the added control flow (Stage 2b/3c/Stage 7) and by
  `test-force-phases.sh`'s harness-level simulation of the identical state transitions at the
  `skill_postflight_update`/`orchestrate-stage5-postflight.sh` layer — not by literally dispatching
  a live `/orchestrate` agent run, which this implementation session does not invoke.

## Impacts

- `/orchestrate N --research` now re-runs research on a task already `[PLANNED]` or beyond,
  opening a fresh `MM_` round without ever regressing the task's status.
- `/orchestrate N --research --plan` / `--research --plan --implement` compose in canonical
  lifecycle order and stop after the last named phase.
- Single-task `/orchestrate` now closes the pre-existing "`next_artifact_number` never advances"
  gap on every research postflight, forced or not — a behavior change for the unforced path too,
  deliberately scoped in as prerequisite P1.
- Zero behavior change when no forcing flag is passed (empty-queue invariant, opt-in clamp
  parameter, `force_invoked` floor-initialized to `"false"`).
- Multi-task (Stage MT-*) mode gains a loud accepted-and-ignored notice for `force_phases` but no
  functional change — deferred to task 138.

## Follow-ups

- Task 138 (`orchestrate_multitask_phase_forcing_gap`): multi-task consumption of `force_phases`
  in Stage MT-4, a multi-task `next_artifact_number` advance mechanism, and `artifact_number`
  dispatch-context threading into MT-4's three per-group dispatch loops. Also carries the
  correction to the design report's WORK item (3) premise (`orchestrator-postflight.sh` named in
  error; the real single-task target was `orchestrate-stage5-postflight.sh`).
- No live end-to-end `/orchestrate --research`/`--plan`/`--implement` dispatch was run in this
  session (see Verification above) — a natural first exercise of this feature on a real task
  would be valuable confirmation, though every unit-level and code-review-level check available
  within this implementation session passed.

## References

- `specs/126_implement_orchestrate_phase_forcing_flags/plans/01_orchestrate-phase-forcing-flags.md`
- `specs/126_implement_orchestrate_phase_forcing_flags/reports/01_orchestrate-phase-forcing-flags.md`
- `specs/126_implement_orchestrate_phase_forcing_flags/progress/phase-1-progress.json` through `phase-7-progress.json`
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A2, design source)
