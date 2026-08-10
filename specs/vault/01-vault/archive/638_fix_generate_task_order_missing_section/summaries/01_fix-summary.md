# Implementation Summary: Task #638

**Completed**: 2026-06-08
**Duration**: ~20 minutes

## Overview

Applied the `bootstrap_task_order_section()` fix (originally added to the nvim config in commit `d926494cd`) to four downstream project copies of `generate-task-order.sh`. This fix enables `--update-todo` to succeed on first run when `TODO.md` lacks a `## Task Order` section, rather than silently printing a warning and returning exit code 1.

## What Changed

- `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh` — Added un-slugify line, `bootstrap_task_order_section()` function (39 lines), and call site before `replace_section`
- `/home/benjamin/Projects/BimodalHarness/.claude/scripts/generate-task-order.sh` — Same three changes
- `/home/benjamin/Projects/BimodalLogic/.claude/scripts/generate-task-order.sh` — Same three changes
- `/home/benjamin/Projects/ModelChecker/.claude/scripts/generate-task-order.sh` — Same three changes

## Decisions

- Used the nvim config script as the canonical reference; all four downstream copies were byte-identical to cslib pre-patch, so the same edit sequence applied to all four
- ModelChecker has a pre-existing unbound variable error when `active_projects` is empty (shell `set -u` causes failure on the first empty array reference). This bug exists equally in both the reference nvim script and the patched copy — it is not caused by this fix and is out of scope

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: `bash -n` syntax check passed for all 4 scripts
- `diff` against nvim reference: empty output for all 4 (byte-identical)
- Bootstrap path tested: cslib and BimodalHarness both had missing `## Task Order` section and succeeded (exit 0, section created)
- Idempotent path tested: BimodalLogic had existing section; second run exits 0, section count remains 1
- ModelChecker: pre-existing unbound variable error with empty state.json (same failure in reference script) — out of scope

## Notes

The ModelChecker project has an empty `active_projects` array in its `state.json`. This causes `bash -u` to fail on `${#all_task_nums[@]}` when the array was declared but never populated via the `while read` loop (empty input). This is a latent bash strictness issue in the shared script that predates this fix. A follow-up task could add a guard after `build_graph()` to handle the empty-array case more gracefully.
