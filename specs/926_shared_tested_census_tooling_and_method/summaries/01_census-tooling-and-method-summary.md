# Implementation Summary: Task #926

**Completed**: 2026-07-27
**Duration**: 7 phases, single session

## Overview

Shipped a shared, fixture-tested census tool (`census-count.sh`) plus a written standard method
(`census-methodology.md`) so repo-wide counts in this agent system are derived once, recorded
with the exact producing command, and cross-checked by an independent second method before being
published or acted on. The same pass closed the live instance of one of the three named bug
classes inside `hooks/validate-no-task-references.sh`'s own separator regex, and established a
shell-test harness convention (`shell-script-testing.md`) resolving the tension between core's
pre-existing flat single-script test and literature's `tests/` subdirectory shape.

## What Changed

- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new: core shell-test
  harness convention (scope-based location rule, `pass`/`fail`/`info` helper naming, inline-
  heredoc fixture convention, loud-skip discipline, mutation-check discipline).
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` — fixed the separator-only
  regex gap (`task-N`, `task_N`, `Task #N` were structurally invisible) via an explicit alternation
  separator group (`TASK_SEP='([[:space:]]+#?|[-_#])'`), and added a task-qualified compound Phase
  branch (`task N phase P`, `phase P of task N`) while deliberately leaving bare `Phase N`
  unmatched. Distinct advisory messages for task-citation vs. phase-citation matches.
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` — new:
  21-case fixture suite (10 positive, 7 negative, 2 exemption, 2 degenerate) driving the hook as a
  real subprocess via synthetic PostToolUse payloads.
- `agent-system/extensions/core/scripts/census-count.sh` — new: shared census tool with three
  subcommands — `occurrences` (naive vs. comment/string-aware real count, bug classes 1 and 3),
  `membership` (declared-set diff, bug class 2), `cross-check` (independent-method agreement,
  exits non-zero on MISMATCH). Every subcommand emits a greppable record block with the verbatim
  producing command.
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` — new: 8-case fixture suite
  covering all three bug classes (each with a naive-vs-correct distinguishing assertion, not a
  happy-path-only fixture), cross-check MATCH/MISMATCH, and the record-block guarantee.
- `agent-system/extensions/core/context/standards/census-methodology.md` — new: the three-part
  standard method (derive once / record the command / cross-check before publishing), the three
  bug classes mapped to `census-count.sh` subcommands, tool boundaries, and four worked examples
  run live against the real CLI.
- `agent-system/extensions/core/manifest.json` — registered 3 new `provides.scripts` entries
  (`census-count.sh`, `tests/test-census-count.sh`, `tests/test-validate-no-task-references.sh`).
- `agent-system/extensions/core/index-entries.json` — registered 2 new entries
  (`standards/shell-script-testing.md`, `standards/census-methodology.md`).

## Decisions

- Confirmed (not assumed) that `manifest.json`'s `provides.context` lists directory names only
  (`"standards"` already present), so no manifest change was needed for the two new
  `context/standards/*.md` files — only `index-entries.json` entries.
- Harness location follows a scope-based split, not an extension-based one: narrow single-script
  suites go in `scripts/tests/`; broad pipeline suites stay flat. This matches literature's own
  internal split and required no migration of the pre-existing `test-task-lock-reap.sh`.
- The method doc lives under `context/standards/` (indexed, `load_when`-scoped), not `rules/`
  (auto-applied to every command) — census correctness is needed selectively, not universally.

## Plan Deviations

- **Task 5.3** (bug class 3 fixture): the plan estimated a naive whitespace-only pattern would
  miss "four of the five" named separator forms. Verified directly that only 2 of the 5 forms
  contain a literal whitespace separator, so the naive pattern actually misses 3, not 4. The test
  asserts the verified 5-vs-2 result; the underlying proof point (naive produces a demonstrably
  wrong, smaller count; the tool's separator-aware pattern produces the correct, larger count)
  holds unchanged.
- **Phase 7 correction to Phase 2's file**: dogfooding the no-task-references audit against the
  fixed hook found it flagging its own explanatory comments, which used a concrete example digit
  sequence ("788") that matched the pattern being described. Corrected the hook's comments to use
  letter placeholders (N, P, M) instead, eliminating the self-reference with no behavior change
  (re-verified via `bash -n` and a clean re-run of the Phase 3 suite, still 21/21).

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `test-validate-no-task-references.sh` 21/21, `test-census-count.sh` 8/8, both
  exit 0 from a clean shell.
- Mutation check: reverting the Phase 2 separator group to `[[:space:]]+` made the hook suite fail
  (17/21, exit 1); restored and re-confirmed 21/21, `git diff` byte-identical.
- Files verified: Yes — all six new/modified source-store files pass `bash -n`; `manifest.json`
  and `index-entries.json` both parse as JSON.
- Registration validators: `validate-extension-index.sh`, `validate-context-index.sh`, and
  `check-extension-docs.sh` all PASSED. `validate-context-index.sh` inspects the deployed
  `.claude/context/index.json` only, so it does not (and is not expected to) see this task's new
  entries — a stale-deploy discrepancy reported per the plan's own risk mitigation, not fixed by
  editing `.claude/**` (redeploy is out of scope).
- Source-store boundary: `git status --short` shows zero `.claude/**` paths across this task's
  diff.
- No-task-references audit: 4 of 6 audited files are clean; the 2 new test suites intentionally
  contain literal separator-form fixture strings (e.g. "task 788") as test data — expected, not
  real citations of any task in this repo's tracker.

## Notes

- Real-repo dogfooding (the `membership` worked example comparing core's `manifest.json` against
  `scripts/*.sh` on disk) appears only in the method doc as an illustrative example, never as a
  test assertion — per the plan's explicit anti-fragility constraint.
- Migrating `scripts/test-task-lock-reap.sh` into `scripts/tests/` remains an intentionally
  tolerated, out-of-scope exception, recorded in `shell-script-testing.md`.
