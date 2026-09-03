# Implementation Summary: Task #147

- **Task**: 147 - Build orchestrate-cycle-plan.sh: one script returns the cycle dispatch plan
- **Status**: [COMPLETED]
- **Started**: 2026-09-03T00:00:00Z
- **Completed**: 2026-09-03T14:20:00Z
- **Effort**: ~8.5 hours (10 phases)
- **Dependencies**: None
- **Artifacts**: plans/01_orchestrate-cycle-plan-script.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `orchestrate-cycle-plan.sh`, a single script that absorbs skill-orchestrate/SKILL.md's
Stage MT-3 (status refresh, all-terminal check, eligibility, classification, admission) and Stage
MT-4's pre-dispatch half (per-task forced-phase consumption, task-directory creation, lock
acquire, dispatch_seq mint, preflight status write, the orchestrate-build-dispatch.sh call) into
one call the thin lead makes once per cycle. The script also absorbs and retires the standalone
`orchestrate-dry-run-report.sh`, since `--dry-run` now runs the identical read-only decision pass
and prints the same JSON plan the live path would emit, plus a compact human table derived from
that same object. Team mode (`--team`/`--team-size`, the `team` dispatch-row field) is deleted per
the dispatch addendum. SKILL.md's Stage MT-3/MT-4 pre-dispatch region collapsed by 46,180 bytes
(271,733 B -> 225,553 B) into one script call plus a 9-line dispatch loop, with the displaced
explanatory prose relocated to `docs/architecture/orchestrate-state-machine.md`.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — New. The cycle dispatch-plan
  composer: status refresh/heartbeat, all-terminal check, dependency-gated eligibility (never
  status-gated), admission via `orchestrate-batch-admit.sh` with verbatim verdict relay,
  classification via `orchestrate-triage-classify.sh`, per-task `force_phases_remaining`
  consumption (canonical research/plan/implement order, stop-after-last-named per task), task
  directory creation, lock acquire with stale-reclaim, atomic `dispatch_seq` mint, preflight
  status write, `MAX_CYCLES_MT`/`MAX_INFRA_FAILURES` accounting, the inter-cycle redeploy
  checkpoint, and `--dry-run` (identical read-only pass; stdout stays pure JSON in both modes,
  with a human table on stderr).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — New. Fixture
  suite covering eligibility, per-task forced phases, verdict relay (including the ORDERING
  CONSTRAINT text for 2+ self-modifying candidates and the forbidden-literal negative
  assertion), lock refusal, the bare-vs-suffixed session_id invariant, and dry-run no-mutation.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-3 steps 1-4.5 and
  Stage MT-4's pre-dispatch half replaced by one `orchestrate-cycle-plan.sh` call and an
  at-most-10-line dispatch loop; Stage MT-1's now-stale `force_phases` bullet and NOTICE text
  corrected (per-task forcing is no longer ignored in multi-task mode); Stage MT-1/MT-2/MT-5 left
  otherwise untouched.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — Extended: the
  pre-existing "MT Mode" diagram annotated with which surface (script vs. SKILL.md) now owns each
  step, plus a paragraph pointing to the script's own header as executable source of truth.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — Deleted (retired; absorbed
  into `orchestrate-cycle-plan.sh --dry-run`).
- `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — swapped the
  retired script's registry entries for the new script's.
- `agent-system/extensions/core/commands/orchestrate.md` — dry-run short-circuit repointed at
  `orchestrate-cycle-plan.sh --dry-run`.
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh`,
  `agent-system/extensions/core/scripts/lib/common.sh`,
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
  `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`,
  `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`,
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  `agent-system/extensions/core/context/patterns/task-lock.md` — cross-reference and lookup-shape
  updates accompanying the retirement.
- `agent-system/extensions/core/merge-sources/claudemd.md` — three stale "accepted and ignored in
  multi-task mode" force-phases claims corrected (Phase 9).
- `agent-system/extensions/core/index-entries.json` — `patterns/batch-orchestration-guardrails.md`
  entry's `line_count` corrected 923 -> 928 to match the file's real post-edit line count
  (verified against the deployed file; the only change this task made to this JSON file).

## Decisions

- Two-function structure: a single decision pass computes the whole cycle's plan with no live
  side effects beyond a read-only lock probe; a second, live-only pass applies side effects and
  enriches dispatch rows with real `dispatch_file`/`model` values. `--dry-run` runs only the first
  pass, so there is exactly one computation of every admission verdict, never two independently
  maintained renderings.
- `force_phases_remaining` applies the CLI's single `--force-phases` string uniformly to every
  task_number in one invocation (no per-task CLI selector exists), with each task tracking its own
  remaining-queue position independently in `mt_state_file` — the only coherent reading of
  "per-task force_phases consumption" given the existing CLI surface.
- The `MAX_CYCLES_MT` budget guard and the inter-cycle redeploy checkpoint are re-sited to the top
  of each invocation (rather than the end, as in the original Stage MT-3 step 7), because this
  script runs strictly before its own cycle's Agent-tool dispatches and cannot consult a
  same-cycle `cycle_modified_files` that does not exist yet; it instead consumes the prior cycle's
  accumulation.
- The `waves` field is deliberately NOT carried into the new `mt_state_file`: it was already a
  documented dead field in the pre-change SKILL.md ("diagnostic echo, recorded not consumed...
  nothing reads this field"), confirmed by Stage MT-5's own explicit read-list and its "replaces
  the deleted command's former reuse of a pre-computed `waves`" comment. Dropping it satisfies
  the phase's actual bar ("every field Stage MT-5 reads must still be present") rather than
  preserving dead weight.

## Plan Deviations

- **Phase 10** altered: the plan's verbatim verification bar ("every `scripts/lint/*.sh` exits 0";
  "`verify-deploy.sh` exits 0 both before and after deploy") is not literally met — 4 of 30
  `verify-deploy.sh` checks (one lint script plus 3 sub-checks) fail. All 4 are pre-existing,
  out-of-scope defects in files/records outside this task's `file_scope`, none introduced by this
  task's own 10 commits. See the plan's Phase 10 `#### Reasoned Exclusions` table for the
  per-item reason and evidence (git-log/diff/lint output). Phase closed
  `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`.

## Verification

- Build: N/A (shell script, no build step)
- Tests: Passed — `bash -n`/shellcheck clean (info-level only: SC2016/SC1091/SC2329, matching
  sibling scripts) on all 6 changed shell files; `scripts/tests/run-all.sh` 64/64 passed
  (including `test-orchestrate-cycle-plan.sh`'s own 22 fixture assertions).
- Files verified: Yes — `.claude/scripts/orchestrate-cycle-plan.sh` deployed,
  `.claude/scripts/orchestrate-dry-run-report.sh` absent, gate 5 content-hash parity green.
- Live 3-task parity (real candidates #13/#29/#43 against live `specs/state.json`): the
  pre-change engine (`orchestrate-dry-run-report.sh` at commit `31580c0d4^`) and the new
  `orchestrate-cycle-plan.sh --dry-run` produced an identical admitted set ({#13,#43} ->
  research/general-research-agent) and identical deferred set ({#29}, same colliding task #22,
  same overlapping path); the deferral wording differs because the new script relays
  `orchestrate-batch-admit.sh`'s own `reason` string byte-for-byte (confirmed by calling that
  script directly) instead of reconstructing it, per this task's own verbatim-relay design
  constraint — a documented improvement, not a divergence. A sandboxed LIVE (non-dry-run) run of
  the same 3 candidates produced an `mt_state_file` carrying all 25 pre-existing fields plus the
  1 new `force_phases_remaining` field; the only pre-existing field absent (`waves`) is confirmed
  dead in the pre-change engine too (see Decisions above).
- `verify-deploy.sh`: 26/30 pass both before and after `deploy-headless.sh` (identical split);
  the 4 failing checks are traced in Phase 10's Reasoned Exclusions table to unrelated,
  pre-existing conditions.

## Impacts

- The thin-lead multi-task dispatch path (`specs/PATH.md` Stage A.3) now has its per-cycle
  planning half fully mechanized; SKILL.md's own footprint for this region shrank by 46,180 bytes.
- `/orchestrate --dry-run` now has exactly one rendering of every admission verdict (the retired
  standalone reporter is gone), closing the drift risk between two independently maintained
  dry-run surfaces.
- Team mode is fully deleted from the multi-task dispatch-plan surface.

## Follow-ups

- The 4 pre-existing gate findings named in Phase 10's Reasoned Exclusions table
  (`test-force-phases.sh` hand-rolled state writes; `index-entries.json` line_count drift on
  `patterns/postflight-control.md` and `schemas/state-schema.json`; the documented
  `abandon_reason`/`blocks_note` schema-drift FAILs; one ghost `index-entries.json` declaration
  in whole-tree orphan detection) remain open and are outside this task's `file_scope` — each
  traces to a different, already-completed task's commit and should be addressed by a task
  scoped to that file, not folded into this one after the fact.
- The not-yet-built postflight composer (per-task postflight, commits, handoff/`.return-meta.json`
  read, `cycle_modified_files` accumulation) is a separate task (successor: revised task 143,
  `orchestrate-cycle-postflight.sh`) and was intentionally out of scope here.

## References

- `specs/147_build_orchestrate_cycle_plan/plans/01_orchestrate-cycle-plan-script.md`
- `specs/147_build_orchestrate_cycle_plan/reports/01_orchestrate-cycle-plan-script.md`
- `specs/147_build_orchestrate_cycle_plan/progress/phase-1-7-progress.json`
- `specs/147_build_orchestrate_cycle_plan/progress/phase-8-progress.json`
- `specs/147_build_orchestrate_cycle_plan/progress/phase-9-progress.json`
- `specs/147_build_orchestrate_cycle_plan/progress/phase-10-progress.json`
- `specs/PATH.md`, "The four moves per cycle"
