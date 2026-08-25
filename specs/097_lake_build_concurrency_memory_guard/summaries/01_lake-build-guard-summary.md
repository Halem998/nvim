# Implementation Summary: Task #97

- **Task**: 97 - Add shared Lean build concurrency and memory guard script (flock serialization, result sharing, cgroup bounding)
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T16:08:00Z
- **Completed**: 2026-08-25T17:10:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_lake-build-guard-mechanism.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Shipped `agent-system/extensions/core/scripts/lake-build-guard.sh`, a portable, project-root-derived
guard that serializes concurrent `lake build` invocations against one Lean package, replays an
already-completed build's result for a session that would otherwise duplicate it, and optionally
bounds a build in a `systemd-run --user --scope` memory ceiling. Delivered alongside its 13-case
toolchain-free regression suite and two `manifest.json` registrations. All 7 plan phases are
closed (6 `[COMPLETED]`, 1 `[COMPLETED WITH EXCLUSIONS]`); the guard is not yet wired into any
call site, by design — that is dependent-task work.

## What Changed

- `agent-system/extensions/core/scripts/lake-build-guard.sh` — new, executable. Three subcommands
  (`status`, `preflight`, `build`), a reserved 75-79 guard-specific exit-code band with `lake`'s
  own exit code passed through untouched on the normal path, lock/result/log paths derived by
  walking up to the nearest `lakefile.lean`/`lakefile.toml` (never `git rev-parse`), a
  key=value result record with an explicit staleness policy (abandoned-lock / stale-result /
  max-age / `--no-share`), a `stat`- or `hash`-mode tree fingerprint, lock-holder-state detection
  with zero-query self-exclusion and descendant-scoped `--verbose` diagnostics, PSI+swap-ratio
  memory preflight (warn-by-default, `--defer-on-pressure` to defer), and opt-in
  `systemd-run --user --scope --quiet --collect` cgroup bounding with percentage-based
  `MemoryHigh`/`MemoryMax` (never a byte constant).
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — new, executable.
  13 acceptance-mapped cases plus 2 live mutation checks (the two examples the plan names by
  name: removing `--quiet`, disabling `flock` serialization) and documented mutation reasoning
  for the remaining cases. All cases build a fresh synthetic fixture per case (heredoc-authored
  fake `lake`, per the core testing convention — no committed fixture data).
- `agent-system/extensions/core/manifest.json` — two `provides.scripts` entries added in
  alphabetical position (`lake-build-guard.sh` between `issue-grouping.sh` and `lib/common.sh`;
  `tests/test-lake-build-guard.sh` between `tests/test-index-entries-schema.sh` and
  `tests/test-lint-agent-contracts.sh`), exactly two added lines, count 131 -> 133.

## Decisions

- **LEAN_NUM_THREADS dropped entirely.** Falsified by prior research (controlled A/B: max
  concurrent `lean` children stayed 1 regardless of the value). It appears only in comment lines
  documenting the dead end; Case 13 is a regression guard asserting it is never assigned or
  exported.
- **Sharing decision checked on lock acquisition unconditionally, not only the waiter branch.**
  Phase 3's prose scoped the sharing check to the waiter (contended) path only, but Phase 6's
  Case 5/6 scenarios are written sequentially ("after A completes ... then run B"), which never
  enters that branch under a waiter-only design — B would always become an uncontended fresh
  holder and always run a real build regardless of fingerprint/record state, making those cases
  vacuous. Generalized `cmd_build` so `decide_sharing()` runs whether the lock was acquired
  immediately or after waiting on a concurrent holder. This is a strict superset: a freshly
  in-flight record (no prior `complete` state) still always falls through to a real build on the
  immediate-acquire path, so Case 4's convoy-avoidance guarantee for genuinely concurrent
  sessions is unchanged. It also makes sharing generally useful as a short-lived result cache for
  sequential repeat invocations, a net improvement over the narrower original scope.
- **Fingerprint `stat` mode reads nanosecond-resolution mtime (`stat -c '%y'`), not whole-second
  (`%Y`).** Discovered while authoring Case 5's fixture: a same-size content edit landing within
  the same wall-clock second as the prior build produced an identical `(path, size, mtime-in-
  seconds)` tuple, causing a false "unchanged" verdict. Switched to nanosecond resolution, which
  ext4/xfs/btrfs/tmpfs all record; the documented residual edge narrows to an identical-size-
  and-identical-nanosecond-mtime restore, closing the more common "fast edit-then-build" case the
  original coarser edge did not cover.
- **`MemoryHigh`/`MemoryMax` expressed as systemd percentage strings (`60%`/`80%`), never
  computed bytes.** Avoids both the machine-specific-figure hazard the plan calls out (the
  originating incident's 29.9GB/6.36GB figures must never appear as thresholds) and any manual
  byte arithmetic — systemd natively accepts percentage-of-`MemTotal` values for these
  properties.
- **PSI/meminfo preflight thresholds are ratios/PSI values with a `--memory-high`/`--memory-max`
  override seam** (build mode's cgroup bound), never absolute byte figures, per the plan's
  explicit prohibition.

## Plan Deviations

- **Phase 3 ("On acquiring the lock as a waiter, ... apply the sharing decision")** altered:
  generalized to check sharing on lock acquisition unconditionally (see Decisions above). Full
  reasoning recorded in `progress/phase-6-progress.json`'s `deviations` array.
- **Phase 3 fingerprint mtime resolution** altered: `stat -c '%y'` (nanosecond) instead of
  `stat -c '%Y'` (whole-second). Full reasoning recorded in the same progress file.
- **Phase 7 ("Run check-extension-docs.sh — no new failures")** closed via
  `[COMPLETED WITH EXCLUSIONS]`: the script refuses to run directly from the agent-system
  source-store path, and this agent has no deploy authority (the single sanctioned automated
  `deploy-headless.sh` caller is `skill-orchestrate`, per
  `context/patterns/regeneration-is-manual-only.md`). Substituted equivalent manual verification
  (manifest count/duplicate/presence checks via `jq`, task-reference lint via the shared pattern
  library). See the `#### Reasoned Exclusions` table in the plan's Phase 7 body for the full
  evidence record.

## Verification

- Build: N/A (shell script, no compile step). `bash -n` clean on both new scripts.
- Tests: Passed. `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — all
  16 assertions `[PASS]` (13 acceptance cases, split case 12 into 12a/12b, plus 2 live mutation
  checks). `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` — 53 passed, 0
  failed, 0 skipped, exit 0; `test-lake-build-guard.sh` confirmed discovered and `[PASS]` by name
  in a non-quiet run.
- Files verified: Yes. Both new scripts exist, are executable, and are registered in
  `manifest.json`'s `provides.scripts` (count 131 -> 133, exactly two added lines, no
  duplicates).
- All 10 items in the task's ACCEPTANCE list independently verified — see the plan's Phase 7
  task-1 annotation and the `#### Reasoned Exclusions` table for the command/observation
  establishing each.
- `git diff --stat <first-phase-1-commit>^ HEAD -- agent-system/` shows exactly 3 changed files
  (`manifest.json`, `lake-build-guard.sh`, `tests/test-lake-build-guard.sh`); the same diff over
  `.claude/` is empty — no `.claude/**` file was touched.
- Task-reference lint: zero matches for `$TASK_PATTERN`/`$PHASE_PATTERN` (sourced from
  `scripts/lib/task-reference-patterns.sh`) in all three touched files.
- `shellcheck`: not installed in this environment; `bash -n` used as the available fallback.

## Impacts

- A new, standalone, opt-in guard is available in core for any future call site
  (`lean-sorry-census.sh --cross-check`, `skill-lake-repair`, etc.) to adopt via
  `lake-build-guard.sh build -- <lake args>` — none currently do, by design; this task delivered
  the mechanism only.
- Sets the family precedent (subcommand shape, exit-code band, silent-when-no-conflict
  convention) for a future `latex-build-guard.sh` sibling, which does not yet exist.
- No behavior change to any existing script or workflow — the guard is inert until a caller
  opts in.

## Follow-ups

- Wire the guard into `lean-sorry-census.sh`, `skill-lake-repair`, or other Lean build call
  sites (out of scope for this task by design; dependent-task work).
- Run `agent-system/extensions/core/scripts/check-extension-docs.sh` against the deployed tree
  at the next deploy cycle (`<leader>al` / `skill-orchestrate`) to obtain the full deployed-drift
  and orphan-gate coverage this agent could not run directly (see Phase 7's Reasoned Exclusions).
- Consider a `context/patterns/build-guard-family.md` conventions doc once a second guard in the
  family (`latex-build-guard.sh`) exists — deliberately deferred per the plan's Non-Goals, since
  it falls outside this task's declared `file_scope` and there is only one consumer so far.

## References

- Plan: `specs/097_lake_build_concurrency_memory_guard/plans/01_lake-build-guard-mechanism.md`
- Research: `specs/097_lake_build_concurrency_memory_guard/reports/01_lake-build-guard-research.md`
- Progress files: `specs/097_lake_build_concurrency_memory_guard/progress/phase-{1,2,3,4,5,6,7}-progress.json`
- Script: `agent-system/extensions/core/scripts/lake-build-guard.sh`
- Test suite: `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
