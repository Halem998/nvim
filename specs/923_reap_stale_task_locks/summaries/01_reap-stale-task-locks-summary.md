# Implementation Summary: Task #923

**Completed**: 2026-07-27
**Duration**: ~4 hours across 4 phases

## Overview

Added a `reap [--dry-run]` subcommand to `task-lock.sh` that explicitly sweeps `specs/`
(including `specs/archive/`, depth 3) for stale task-number `.lock` directories and removes/
reports them per-item, wired it into `/refresh` as its sole caller, proved the contract with a
6-case isolated-temp-root test fixture (including a manually-performed negative teeth-check),
and documented the full contract — threshold derivation, two-band staleness model, archive-depth
rationale, and the correction to the task's own originating premise — in the canonical
`task-lock.md` pattern doc.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — new `TASK_LOCK_REAP_MIN` constant
  (`TASK_LOCK_STALE_MIN * 4`, default 120 min), new `cmd_reap()`, new `reap)` dispatch case,
  updated usage comment and catch-all usage line. `find_held_locks()`, `cmd_acquire`,
  `cmd_heartbeat`, `cmd_release`, `cmd_check` left byte-identical.
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh` — new isolated-temp-root suite
  (6 PASS/FAIL cases: dry-run no-op, no-implicit-reap, fresh-survives, stale-reaped-and-reported,
  corrupt-holder skip-vs-reap, depth-3 archive removal).
- `agent-system/extensions/core/manifest.json` — registered `test-task-lock-reap.sh` in
  `provides.scripts`.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — new Step 4 ("Reap Stale Task
  Locks"), calling `task-lock.sh reap [--dry-run]` and echoing its output verbatim; subsequent
  steps renumbered 5-7 (gapless, monotonic).
- `agent-system/extensions/core/commands/refresh.md` — new "Stale Task Locks" subsection under
  "What It Cleans", including the not-on-the-hourly-timer scoping note.
- `agent-system/extensions/core/context/patterns/task-lock.md` — new `## Reap Contract` section
  (signature, staleness determination, output format, exit codes, never-implicit invariant),
  `### Threshold Derivation` (checkpoint-cadence reasoning, explicit CONSTRAINT 5 two-band
  answer, calibration evidence), `### Two Depths, Deliberately Different`, `### Correction to
  This Feature's Originating Constraint`; updated the acquire/heartbeat/release/check/init-marker
  section's lead sentence, the Consumers section (now "Four Distinct Wiring Paths"), and Related
  Documentation to reference `reap` and its two new caller files.

## Decisions

- `TASK_LOCK_REAP_MIN` derives proportionally from `TASK_LOCK_STALE_MIN` (4x) rather than being
  an independent constant, so the two thresholds move together if a caller raises the base.
- The reaper uses its own dedicated `find ... -mindepth 2 -maxdepth 3 ...` rather than calling
  `find_held_locks()` (which is intentionally left at `-maxdepth 2`, since widening it would add
  scan cost to every `acquire` for zero cross-task-overlap signal from archived tasks).
- A missing/corrupt `holder.json` falls back to the `.lock` directory's own mtime for the
  staleness decision; a normal fresh lock (valid holder, within threshold) produces no output
  line at all, while a corrupt-but-fresh lock produces an explicit `SKIP:` line naming the reason.
- The task's originating CONSTRAINT 2 ("honor the holder-declared staleness window written into
  the lock directory") does not correspond to any real field on the task-number lock's
  `holder.json`; the plan's resolution — reading the same `TASK_LOCK_STALE_MIN`-derived constant
  every other caller reads — was implemented and documented rather than inventing a new field.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts + markdown)
- Tests: `bash -n` clean on both shell files; 6/6 fixture cases PASS on both the source-store and
  deployed copies; negative teeth-check performed manually (temporarily reverted the reaper's
  `-maxdepth 3` to `-maxdepth 2`, re-ran the suite — case F failed as expected, 5 passed/1
  failed — then reverted `task-lock.sh` to a byte-identical state, confirmed via empty `git diff`,
  and re-ran to confirm 6/6 PASS again); `check-extension-docs.sh` exits 0;
  `validate-artifact.sh` on this plan reports 0 warnings; live `/refresh --dry-run` path executed
  end-to-end (process cleanup step is non-destructive without `--force`), reap section appeared
  correctly reporting the three real archived orphans, lock count unchanged (4 before, 4 after).
- Files verified: Yes (`git diff --stat` scoped to `agent-system/**` only across all 4 phase
  commits; zero `.claude/` paths modified by any commit in this task).
- `shellcheck`: not installed in this execution environment — skipped. `bash -n` was used as the
  available syntax-validation substitute; no other verification depended on shellcheck.

## Notes

- Read-only sanity check against the real tree (`task-lock.sh reap --dry-run`, never destructive)
  correctly identified the three genuine orphaned locks at
  `specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock`,
  `specs/archive/860_enforce_plan_compliance_rule/.lock`, and
  `specs/archive/921_throwaway_verify_meta_task_creation_pipeline/.lock` (ages ~433, ~18,551-
  18,557, and ~446-452 minutes across the two runs performed), confirming the depth-3 sweep works
  against real data as well as the fixture. These were never destructively reaped as part of this
  implementation — only the isolated fixture's own locks were ever removed.
