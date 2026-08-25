# Implementation Summary: Task #61

- **Task**: 61 - Surface coarse file_scope declarations at creation
- **Status**: [COMPLETED]
- **Started**: 2026-08-17T21:10:00Z
- **Completed**: 2026-08-17T23:20:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 59 (completed)
- **Artifacts**: plans/01_coarse-file-scope-advisory.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added two new WARN-only base-mode checks to `scripts/validate-state.sh` — Check 8 (coarse,
whole-directory-root `file_scope` declarations, triggered by measured blast radius against a
default threshold of 3, tunable via `FILE_SCOPE_COARSE_MIN_OVERLAP`) and Check 9 (duplicate
`file_scope` entries, split into an exact-duplicate Class A and a normalization-equivalent
Class B) — plus an opt-in `--fix` flag that repairs Class A duplicates order-preservingly through
the deployed, mutex-guarded `state-write.sh`, and a new advisory Step 6.5 in `commands/task.md`'s
Create Task Mode that surfaces those warnings at task-creation time without ever blocking. All six
plan phases are complete; Phase 6 closed as `[COMPLETED WITH EXCLUSIONS]` on three confirmed
pre-existing, unrelated `verify-deploy.sh`/`validate-state.sh --deep` failures.

## What Changed

- `agent-system/extensions/core/scripts/validate-state.sh` — new `file-scope-overlap.sh` library
  sourcing block; Check 8 (coarse blast-radius, WARN-only); Check 9 (duplicate entries, two
  labelled classes, WARN-only); opt-in `--fix` (D3 deployed-`state-write.sh` resolution, refuses
  loudly when none resolves, order-preserving dedup, repair-then-revalidate); header docs and the
  `--help` `sed` range moved three times (`2,74p` -> `2,94p` -> `2,99p` -> `2,112p`) to track
  header growth.
- `agent-system/extensions/core/commands/task.md` — new Step 6.5 in Create Task Mode: runs the
  deployed `validate-state.sh` base mode after Step 6's state write, surfaces `[WARN]` lines
  mentioning `file_scope` under a short heading, guarded so a nonzero exit or missing script can
  never block Steps 7-8; a one-line pointer added to Step 8's output block.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — four new fixture blocks
  (coarse, threshold, duplicate, `--fix`) plus a new source-store-first `FS_VALIDATOR` resolution
  block grepping for both "Check 8" and "Check 9"; suite grew from 14 to 18 assertion pairs, all
  passing from both the source-store and deployed invocation sites.
- `specs/state.json` — task 61's own `file_scope` amended (Phase 1) to add
  `agent-system/extensions/core/scripts/tests/test-validate-state.sh`, via the deployed
  `state-write.sh` (append-only).
- Regenerated `.claude/` deploy tree via `deploy-headless.sh` (not hand-edited; gitignored).

## Decisions

- Check 8's jq invocation is one `jq -c --argjson min ... "$STATE_FILE"` call (matching this
  script's existing Check 5/6/7 idiom) rather than the plan's suggested `jq -n --slurpfile`
  literal form — still exactly one jq process per run, satisfying the plan's own
  "or --argfile-equivalent" allowance.
- Check 9's Class B reuses `norm` from the same spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS` rather than
  writing a second local `rtrimstr("/")`.
- `--fix`'s regression fixture is deliberately placed inside this repo's own git tree (cleaned up
  immediately after) rather than a generic `/tmp` workdir, so the D3 git-toplevel candidate can
  reach the real deployed `state-write.sh`, gracefully SKIPPED (not FAILED) when no deployed copy
  exists yet.
- Phase 6 closed via the reasoned-exclusion mechanism (`[COMPLETED WITH EXCLUSIONS]`) rather than
  `[PARTIAL]`: all five admission conditions were met for three confirmed pre-existing, unrelated
  failures (see Plan Deviations below).

## Plan Deviations

- **Phase 2, task 2** altered: Check 8 implemented as one `jq -c --argjson` invocation rather than
  literal `jq -n --slurpfile`, matching the script's own existing Check 5/6/7 idiom.
- **Phase 2 Scope Hypothesis** confirmed-with-variance: 8 WARN lines emitted at `N=3`, not the
  hypothesized 6 — the 2 extra triples (tasks 20 and 50 against
  `.../core/scripts/tests/`) are a direct, expected consequence of Phase 1's own deliberate
  `file_scope` amendment (adding an overlap against both), not a mis-spliced predicate.
- **Phase 6, task "verify-deploy.sh Gate 10 passes"** altered: `verify-deploy.sh` reports 3 of 23
  gates FAIL — doc-lint (Gate 3, three unrelated files' `index-entries.json` line-count drift),
  `run-all.sh`'s `test-lint-state-writer-boundary.sh` `--verbose` sub-case (Gate 8), and Gate 10
  itself (task 53's undocumented `priority` field). All three confirmed byte-identical to the
  pre-Phase-1 commit (`18fcd2472`) via `git stash`; none reference `file_scope`, Check 8, Check 9,
  or `--fix`. Recorded as a Reasoned Exclusion on Phase 6 (all five admission conditions met).
- **Phase 6, task "`validate-state.sh --deep` exits 0"** altered: exits 1 on the same pre-existing
  task-53 finding, not 0. This task's own Checks 8/9 are WARN-only by construction
  (`grep -c log_fail` on both hunks is 0) and never contribute a FAIL-level finding.
- All other plan tasks completed exactly as written; see the plan file's per-task `*(completed)*`
  annotations for the full per-item record.

## Verification

- Build: N/A (bash/jq scripts, no build step)
- Tests: Passed — `test-validate-state.sh` 18/18 from both the source-store
  (`agent-system/extensions/core/scripts/tests/`) and deployed (`.claude/scripts/tests/`)
  invocation sites
- Files verified: Yes — all four modified/touched files confirmed present and correct via direct
  `bash`/`jq`/`grep` inspection at each phase's close

## Impacts

- Any future `/task` creation now surfaces pre-existing coarse or duplicate `file_scope`
  declarations (currently 8 coarse WARNs, 0 duplicate WARNs against live `specs/state.json`) as an
  advisory note, without blocking creation.
- `verify-deploy.sh` Gate 10 and the base-mode `validate-state.sh` invocation both continue to
  exit 0 on WARN-only findings, so no existing deploy or task-creation flow is newly blocked by
  this change.
- A maintainer can now run `validate-state.sh --fix` to mechanically repair exact-duplicate
  `file_scope` entries anywhere in `specs/state.json`, through the same mutex-guarded writer every
  other state mutation uses.

## Follow-ups

- The three pre-existing `verify-deploy.sh` failures recorded as Phase 6's Reasoned Exclusions
  (doc-lint `index-entries.json` line-count drift on three files, `test-lint-state-writer-boundary.sh`'s
  `--verbose` sub-case, and task 53's undocumented `priority` field) remain open and are candidates
  for a separate follow-up task — none are in this task's declared `file_scope`.
- The plan's own non-goals list a natural follow-up (extending `meta-builder-agent.md` Component
  4a, which populates `file_scope` for most tasks, to consult these same checks pre-emptively) —
  explicitly out of this task's scope.
- **Observed but not acted on**: `specs/state.json` (and its `TODO.md` mirror) carried a
  foreign, uncommitted edit to a different task's `description` field from a concurrent session,
  discovered during Phase 4's `--fix` testing. Confirmed unrelated to `file_scope` (0
  `file_scope`-touching diff lines) and left untouched, per the observation-duty obligation to
  report rather than act on work not done by this task. Still uncommitted as of this task's own
  completion; belongs to whichever session/task authored it.

## References

- Plan: `specs/061_surface_coarse_file_scope_declarations_at_creation/plans/01_coarse-file-scope-advisory.md`
- Report: `specs/061_surface_coarse_file_scope_declarations_at_creation/reports/01_coarse-file-scope-detection.md`
- Phase handoffs: `specs/061_surface_coarse_file_scope_declarations_at_creation/handoffs/`
- Phase progress files: `specs/061_surface_coarse_file_scope_declarations_at_creation/progress/`
