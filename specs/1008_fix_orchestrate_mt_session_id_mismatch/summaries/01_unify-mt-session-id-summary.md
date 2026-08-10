# Implementation Summary: Task #1008

- **Task**: 1008 - fix_orchestrate_mt_session_id_mismatch
- **Status**: [COMPLETED]
- **Started**: 2026-08-10
- **Completed**: 2026-08-10
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_unify-mt-session-id.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`skill-orchestrate/SKILL.md`'s multi-task batch registered itself in the session registry under
the bare `$session_id` (Stage MT-1) but acquired/released each task's lock under a
task-suffixed `${session_id}_${task_num}` (Stage MT-4). Because the session-registry contention
predicate's self-exclusion is an exact string match, the batch's own union-`file_scope`
registration was never excluded, so every lock acquire in every multi-task `/orchestrate`
invocation was refused against the batch's own registration. This implementation unified the
three lock-touching session-id sites onto the bare `$session_id`, stated the parity invariant in
prose at the point of use and in the canonical lock spec, and added a five-case regression group
to the existing `test-conflict-predicate.sh` suite that reproduces the defect and pins the fix.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the Stage MT-4
  `task-lock.sh acquire` argument, the Stage MT-4 step 6 `task-lock.sh release` argument, and the
  `implement_agents[task_num]` Agent-tool dispatch context's `session_id` field all changed from
  `"${session_id}_${task_num}"` to the bare `"$session_id"`. Added invariant prose at the acquire
  block and a pointer note at the release block and the implement dispatch context.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — added Group 9
  (register/acquire parity), five cases: 9.1 registration (real `session-register` CLI, asserts
  the union `file_scope` over fixture 820/850), 9.2 positive (bare-id acquire/release admits both
  fixture batch members), 9.3 negative (suffixed-id acquire contends, exit 1 + stderr `registered
  session`, reproducing the pre-fix defect), 9.4 heartbeat parity (bare-id heartbeat does not warn
  of a foreign holder), 9.5 static guard (no lock-touching `task-lock.sh` call in
  `skill-orchestrate/SKILL.md` uses the suffixed pattern — verified to actually fail via a
  scratch revert, then discarded, not committed).
- `agent-system/extensions/core/context/patterns/task-lock.md` — added a "Register/acquire parity
  invariant" paragraph under the Consumers section's multi-task/wave-dispatch item, cross-
  referencing item 5 and the Session-Registry Reader Contract section.
- `agent-system/extensions/core/index-entries.json` — `line_count` for `patterns/task-lock.md`
  corrected from 1167 to 1178 via `generate-context-line-counts.sh --write`, reflecting Phase 3's
  11-line addition.
- `.claude/` deploy tree — regenerated via `deploy-headless.sh` so the deployed copies of the
  three source-store files above match the source store (required for `check-extension-docs.sh`
  to pass; the deploy/reload mechanism writing `.claude/` in full is the documented exception to
  the source-store-is-canonical rule, not a violation of it).

## Decisions

- Followed the plan's Phase 1 Scope Hypothesis exactly: only the three lock-touching sites
  changed; all other `${session_id}_${task_num}` sites in `SKILL.md` (provenance/attribution:
  `skill_preflight_update`/`skill_postflight_update`, `research_agents`/`planner-agent` dispatch
  contexts, `system-defect-record.sh --session`, `git-commit-scoped.sh --session`) were left
  suffixed, per the plan's Non-Goals.
- Wrote the new regression group against the real `task-lock.sh` CLI end to end
  (`session-register` then `acquire`/`release`/`heartbeat`) rather than a hand-built registry
  fixture, so it reproduces the actual union-`file_scope` computation, not an assumption about it.
- Used fixture phrasing ("fixture 820", "the 820/850 fixture pair") throughout the new test
  group's comments and messages, never "task 820" — this file is a deliverable outside
  `specs/**`.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `test-conflict-predicate.sh` (29 passed, 0 failed, including the new Group 9)
  and `test-session-registry.sh` (11 passed, 0 failed, no regression)
- Files verified: Yes

**Confirmed scope evidence** (final Scope Hypothesis grep, `grep -n
'\${session_id}_\${task_num}' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`):
13 remaining hits, all in the enumerated out-of-scope set — the MT append-idiom prose note (1),
this implementation's own new invariant-prose mention of the pattern-to-avoid (1),
`skill_preflight_update` for research/plan/implement (3), the `research_agents` and
`planner-agent` dispatch contexts (2), `system-defect-record.sh --session` (2),
`skill_postflight_update` (3), and `git-commit-scoped.sh --session` (1).

**Static guard verified to actually bite**: temporarily reverted the Phase 1 `acquire` line to
the suffixed form in place, re-ran the suite (case 9.5 failed as expected, 28/29 passing), then
restored the file from a scratch copy before continuing — the reverted state was never committed.

**Gates run**: `check-task-references.sh` (PASS, 0 unexempted occurrences across 4 deliverable
trees), `check-extension-docs.sh` (initially FAILed on deployed-content drift for
`test-conflict-predicate.sh` and an `index-entries.json` line-count mismatch for
`task-lock.md`; resolved via `generate-context-line-counts.sh --write` and `deploy-headless.sh`,
then re-ran to a clean exit 0). `git status --short` shows changes only under
`agent-system/extensions/**` and `specs/**` — no `.claude/**` path appears (it is gitignored;
the deploy regeneration above is the documented exception to the source-store rule, not a
violation).

Verification deliberately avoided a multi-task `/orchestrate` invocation, per the task
constraint that the mechanism under repair not be used to verify its own repair. The
`test-conflict-predicate.sh` Group 9 CLI-level reproduction against the real `task-lock.sh`
binary is the substitute, and it exercises the exact `session-register` -> `acquire` sequence
Stage MT-1/MT-4 perform.

## Impacts

- Every multi-task `/orchestrate` invocation (2+ tasks in one call) can now actually acquire
  per-task locks; previously every such invocation refused every lock acquire against the
  batch's own registration, making multi-task `/orchestrate` non-functional.
- The per-phase heartbeat `general-implementation-agent` issues during a multi-task-dispatched
  implement now presents the same session_id the lock was acquired under, so a long implement
  phase's lock will no longer silently go stale mid-run for a multi-task `/orchestrate` dispatch.
- No externally-visible behavior change for single-task `/orchestrate` or for any of
  `/research`, `/plan`, `/implement`'s own multi-task paths (see Follow-ups).

## Follow-ups

- **Same defect pattern remains live in the three multi-task command files.**
  `commands/research.md`, `commands/plan.md`, and `commands/implement.md` each register their
  batch under the bare `batch_session_id` (with an explicit inline comment warning "never a
  `_${task_num}`-suffixed derivative") but then acquire/release the per-task lock under
  `"${batch_session_id}_${task_num}"` — the structurally identical MT-1/MT-4 mismatch this task
  fixed in `skill-orchestrate/SKILL.md`. Exact call sites at the time of this implementation:
  - `research.md`: `session-register` at line 165; `acquire-retry` at line 234; `release` at
    line 238.
  - `plan.md`: `session-register` at line 172; `acquire-retry` at line 241; `release` at line
    245.
  - `implement.md`: `session-register` at line 89; `acquire-retry` at line 155; `release` at
    line 159.
  The same fix shape applies (switch the `acquire-retry`/`release` argument to the bare
  `batch_session_id`) and the same regression-test pattern (a CLI-driven register/acquire parity
  group) would pin it. This was explicitly out of scope for this task (see the plan's
  Non-Goals) and is not fixed here — recorded for the orchestrator or user to act on via a
  follow-up task.

## References

- `specs/1008_fix_orchestrate_mt_session_id_mismatch/plans/01_unify-mt-session-id.md`
- `specs/1008_fix_orchestrate_mt_session_id_mismatch/reports/01_mt-session-id-self-contention.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh`
- `agent-system/extensions/core/context/patterns/task-lock.md`
