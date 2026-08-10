# Implementation Summary: Task #879

**Completed**: 2026-07-15
**Duration**: single session, 5 phases

## Overview

`reconcile-task-status.sh` was a deployed, fully-functional self-healing script with zero
callers. All 5 plan phases were implemented, including the optional stretch phase. The script
now has three live/dry-run callers (`/task --sync`, `/orchestrate` entry, `skill-todo`), a
handoff-aware promotion guard that prevents automatic reconciliation from masking a reported
`blocked`/`partial`/`failed` outcome as success, and a report-only plan-vs-state.json divergence
check. Every edit landed in the canonical `agent-system/extensions/core/` tree and was mirrored
byte-identical to the gitignored `.claude/` deploy tree; all verification ran against isolated
`mktemp -d` fixtures per the plan's constraint against exercising a live `/orchestrate`, `/task
--sync`, or `/todo` run.

## What Changed

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (+ `.claude/` mirror) —
  Phase 1: added `handoff_permits_promotion()`, `handoff_status_value()`, and
  `record_refused_promotion()` helpers, generalizing the `partial` branch's existing
  handoff-consultation pattern into the `researching`/`planning`/`implementing` branches. A
  refused promotion now prints a visible line in both dry-run and live mode and, when the
  handoff status maps unambiguously (`blocked` or `partial`), records that outcome via
  `update-task-status.sh`'s sanctioned postflight termini rather than silently no-opping.
  Phase 5: added `plan_level_equivalent()` and `check_plan_state_divergence()` — a report-only
  check (never repairs) comparing the plan file's `- **Status**:` field against state.json's
  status, called as the first statement in all four reconcilable branches so divergence surfaces
  even on the no-artifact no-op path. Also hardened `find_latest_artifact()` against a
  pre-existing latent bug discovered during fixture testing (see Notes).
- `agent-system/extensions/core/commands/task.md` (+ mirror) — Phase 2: new Sync Mode step 2.6,
  inserted after the existing artifact-reconciliation step 2.5. Generates an inline session ID
  (Sync Mode has none of its own), sweeps every task in one of the four reconcilable statuses,
  calls the script live per task, and always prints a summary line (including the zero-candidate
  case).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (+ mirror) — Phase 3: added an
  entry-reconcile call at the Stage 2/Stage 3 boundary (single-task, before the `while` loop) and
  inside Stage MT-2's per-task routing-table iteration (multi-task, before Stage MT-3's cycling
  loop). Both calls are live, non-fatal (`|| true`), and bracketed to print an explicit no-op
  notice when the script produces no output, since a live no-op is otherwise silent.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (+ mirror) — Phase 4: new
  `<stage id="1.5" name="ReconcileScan">` (dry-run only, side-effect-free), a Stage 8 dry-run
  preview line, and a Stage 9 `AskUserQuestion` multiSelect sub-step. Only user-approved
  candidates are re-run live; unselected candidates stay stranded rather than being silently
  archived alongside a silent promotion.

## Decisions

- Used a positive-match `select(.status == "researching" or ...)` selector at both the `/task
  --sync` and `skill-todo` sweep sites instead of a `| not` negation selector. Both approaches
  avoid the forbidden `!=` operator; positive-match against the four reconcilable statuses is
  simpler and was cross-verified to return the identical result set against real
  `specs/state.json`.
- The handoff-status-to-postflight-terminus mapping in `record_refused_promotion()` only fires
  for `blocked` and `partial` (a literal 1:1 match with `update-task-status.sh`'s accepted
  `target_status` values). Any other handoff status, including `failed` or an absent/empty
  status field, is left as a plain no-op rather than guessing a mapping.

## Plan Deviations

- **Task 2.3 / 4.3** (positive-match selector instead of `| not`): see Decisions above. Recorded
  in `progress/phase-2-progress.json` and `progress/phase-4-progress.json`.
- **Unplanned fix in Phase 5**: hardened `find_latest_artifact()` against a pre-existing latent
  bug (see Notes) discovered while fixture-testing Phase 5's "no plan file" case. Not called for
  in the plan, but fixed in-place since it directly undermines the non-fatal/visible guarantees
  the Phase 2-4 callers depend on, and the file was already open for Phase 5's own edit. Recorded
  in `progress/phase-5-progress.json`.

## Verification

- Build: N/A (shell scripts and markdown skill/command documents, no build step)
- Tests: All fixture-based verification passed — `bash -n` on every edited shell block/script;
  byte-identical diff between all 4 canonical/mirror pairs; per-phase fixture scenarios (no-handoff
  unchanged behavior, refusal + recorded terminus, matching-handoff promotion, sweep selector
  cross-check against real `specs/state.json`, stranded-vs-completed sweep isolation,
  zero-candidate summary line, single-task and multi-task entry-reconcile placement-by-inspection
  and no-op/stranded bracket behavior, skill-todo's byte-identical dry-run scan and single
  live-invocation-site confirmation, and Phase 5's mismatch/match/no-plan-file divergence cases)
  all passed. A full Phase 1-5 regression sweep was re-run after the `find_latest_artifact` fix
  to confirm no earlier-phase behavior regressed.
- Files verified: Yes — all 4 canonical files parse cleanly and match their mirrors exactly; the
  final backstop scan of the plan file confirmed all 5 phase headings carry `[COMPLETED]` with
  zero stale markers; a full-diff grep confirmed no task-number citation was added to any
  deliverable file outside `specs/**`; confirmed no new script files were created anywhere.

## Notes

- **Optional Phase 5 was executed.** The gap (no plan-vs-state.json divergence detector anywhere
  in the system) was reconfirmed still open before building, per the plan's first task item. The
  check is strictly report-only: it never mutates either the plan file or state.json in any of
  the tested scenarios.
- **Latent bug found and fixed**: `find_latest_artifact()`'s original implementation
  (`ls -1 "$dir"/*.md 2>/dev/null | sort -V | tail -1`) aborted the entire script with exit 2
  under `set -euo pipefail` whenever an artifact subdirectory existed but was empty — the
  unexpanded glob makes `ls` fail, and `pipefail` propagates that failure past the successful
  `sort`/`tail` stages. This is pre-existing behavior (present before this task's changes) but
  was only surfaced by Phase 5's own fixture testing. Fixed with a trailing `|| true` on the
  pipeline, since an empty artifact directory is a legitimate no-artifact-yet state, not an
  error. This directly protects the non-fatal/visible guarantees built into the Phase 2-4
  callers, all three of which now depend on `reconcile-task-status.sh` never crashing
  unexpectedly.
- **Deferred, per plan Non-Goals**: the archived-while-still-held-lock problem (a separate
  `task-lock.sh check`/`release` wiring into `skill-todo`'s `ArchiveTasks` stage) remains
  unaddressed, as explicitly scoped out of this plan.
- No live `/orchestrate`, `/task --sync`, or `/todo` invocation was run at any point during
  implementation or verification, per the plan's explicit constraint (this task was itself being
  executed under an orchestrator dispatch touching the very documents a live run would execute).
