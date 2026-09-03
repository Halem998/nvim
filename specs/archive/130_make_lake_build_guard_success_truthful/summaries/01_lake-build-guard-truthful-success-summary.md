# Implementation Summary: Task #130

- **Task**: 130 - Stop lake-build-guard.sh reporting passes for builds it did not run
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_lake-build-guard-truthful-success.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`lake-build-guard.sh` reported exit 0 in two situations where no corresponding build ran
(Defect A: an unvalidated `lake` subcommand vector dispatched straight through; Defect B: a
completed result silently replayed for a differently-scoped build over an unchanged tree), and
never documented the correct idiom for waiting on an in-flight guarded build (Defect C). All six
plan phases were implemented and verified: subcommand validation before dispatch, a `scope_key`
record field and fifth sharing condition, an audible `REPLAY:` stderr marker, the `kill -0` wait
idiom in both the header and `--help` output, a rewritten FAMILY CONVENTIONS block, and eight new
harness cases plus three new mutations (24 harness cases total across 21 acceptance-mapped cases
and 5 mutations, all in `tests/test-lake-build-guard.sh` — mutation count is A/B/C/D/E = 5, not
3, because the existing suite already carried mutations A and B before this task).

## What Changed

- `agent-system/extensions/core/scripts/lake-build-guard.sh` — added the `LAKE_SUBCOMMANDS`
  allowlist constant and `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` escape hatch; added
  `validate_build_subcommand()`, called in `main()` immediately after the argument-parsing loop
  converges and before `resolve_project_root()`, rejecting an empty, flag-shaped, or
  unrecognized `lake_args[0]` with exit 77; added `compute_scope_key()` (a NUL-joined-argument-
  vector hash); added a `scope_key=` field to `write_inflight_record()`/`finalize_record()`;
  gave `decide_sharing()` a second parameter and a fifth condition comparing the waiter's scope
  key to the record's (fail-closed on a missing/empty recorded value); threaded the scope key
  through `run_as_holder()` and `cmd_build()`; added a `lake-build-guard: REPLAY:` stderr notice
  (holder pid, age, recorded exit status — no job count, per Decision 3) on the replay branch
  only, immediately before `replay_shared_result()`; added a "WAITING ON AN IN-FLIGHT GUARDED
  BUILD" subsection to both the header USAGE block and `print_help()`'s rendered output, plus a
  cross-referencing comment beside `cmd_status()`; rewrote the header's EXIT CODES, STALENESS
  POLICY, and FAMILY CONVENTIONS blocks to state the revised contract (validated passthrough,
  qualified silent-when-no-conflict, scope-keyed sharing as a fifth named convention).
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — added
  `build_fixture_unknown_cmd()` (a deterministic fake `lake` that always exits 0 with an "unknown
  command" stderr line, reproducing the documented defect shape without depending on the real
  `lake` binary); added cases 14-21 covering the seven acceptance bullets (unknown subcommand via
  both argument paths, empty `lake_args`, exit-code passthrough surviving validation, scoped-vs-
  full sharing, sharing preserved for an identical full build, the `REPLAY:` marker, and the
  `--help` wait-idiom text); added mutations C (disables `validate_build_subcommand()`), D
  (disables the `scope_key` comparison in `decide_sharing()`), and E (removes the `REPLAY:`
  stderr line), following mutations A/B's scratch-copy pattern; extended the by-inspection
  non-vacuousness `info` block with reasoning for cases 16 and 21; updated the header comment's
  case count from 13 to 21 and documented the new fixture variant.

## Decisions

- Followed the plan's three pre-settled decisions verbatim: a hardcoded subcommand allowlist
  (not a dynamic `lake --help` probe) plus the `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` escape hatch;
  a zero-length `lake_args` in build mode rejected with exit 77; the replay notice names holder
  pid, age, and recorded exit status, deliberately omitting the job count.
- Confirmed at implementation time (Phase 1's Scope Hypothesis) that exactly two branches
  populate `lake_args` (the `--)` branch and the bare catch-all `*)` branch) and that both
  converge at one post-loop point in `main()`; the validation call was placed there, once.
- Regression cases 14-16 (and mutation C) use a dedicated `build_fixture_unknown_cmd()` fake
  `lake` rather than the real binary, per the plan's Risk mitigation: on this machine
  `lake TARGET` actually exits 1, not the 0 the original defect record asserted, which would have
  made a real-binary-based test vacuous or version-flaky.
- Phase 5's eight-case estimate held exactly: each of the task's seven acceptance bullets maps to
  at least one of cases 14-21, with the empty-`lake_args` bullet (Decision 2) and the unknown-
  subcommand bullet each getting a dedicated case (14/15/16) rather than being folded together.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell script, no compilation step).
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
  exits 0 with `Passed: 27` / `Failed: 0` (21 acceptance-mapped cases, one split into 12a/12b,
  plus 5 mutations A-E), confirmed stable across 3 consecutive runs.
- `bash -n` clean on both modified files.
- `grep -rn '\.claude/'` over the diff: no `.claude/**` path was written (both files live under
  `agent-system/extensions/core/scripts/**`, the source store).
- Task-reference lint: no task-number reference in either modified file.
- Manual spot-checks: exit 77 for `-- garbagecmd TARGET`, bare `garbagecmd TARGET`, and empty
  `build` args; exit-code passthrough survives validation (`FAKE_LAKE_EXIT=7` -> guard exit 7);
  `--version`-style flag-shaped first token rejected; `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS`
  escape hatch verified to accept an otherwise-unknown subcommand; scoped-then-full sequence
  produces 2 real invocations, full-then-identical-full still shares (1 invocation); `REPLAY:`
  marker present on a replay and absent on a fresh build; `--help` output contains both
  `kill -0` and the `pgrep -f` self-match warning.

## Impacts

- `lake-build-guard.sh`'s `build` mode no longer reports a false pass for an unrecognized/absent
  `lake` subcommand or for a result replayed across a scope change; a replay is now audible on
  stderr without requiring `--no-share`.
- The header's FAMILY CONVENTIONS block — the contract a not-yet-existing sibling guard (e.g.
  `latex-build-guard.sh`) will instantiate — now states the revised, corrected shape rather than
  the superseded one, so that sibling is not built on the defects this task closes.
- No call site changes: the script's own documented non-goal (wiring itself into any caller)
  remains untouched; existing callers of `status`/`preflight` are unaffected, and every existing
  build-mode invocation in the test harness already passed `build` as `lake_args[0]`, so no live
  caller is broken by the new validation.

## Recorder-Class Taxonomy Observation (Phase 6, recorded here per plan scope)

Both events that originally motivated this task were filed under the recorder-class
`OFF_SCHEMA_STATUS`, which does not fit their actual defect shape: "a tool reports success for
work it did not do." This is a distinct failure mode from an off-schema status value and would
benefit from its own recorder class in a future taxonomy revision. Per the plan's explicit
scope boundary, this observation is recorded here for whoever next revises the taxonomy; this
task does not register a new class or touch the taxonomy mechanism itself — that is a sibling
task's responsibility.

## Follow-ups

- None beyond the taxonomy observation above and the plan's own explicitly out-of-scope items
  (wiring the guard into a call site; creating `latex-build-guard.sh`; redesigning the record
  schema or `flock` machinery).

## References

- `specs/130_make_lake_build_guard_success_truthful/reports/01_lake-build-guard-truthful-success.md`
- `specs/130_make_lake_build_guard_success_truthful/plans/01_lake-build-guard-truthful-success.md`
- `agent-system/extensions/core/scripts/lake-build-guard.sh`
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
