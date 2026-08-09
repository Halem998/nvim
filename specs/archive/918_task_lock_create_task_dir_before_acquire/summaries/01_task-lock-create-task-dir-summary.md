# Implementation Summary: Task #918

**Completed**: 2026-07-27
**Duration**: ~1 hour

## Overview

`task-lock.sh acquire` now creates the canonical `specs/{NNN}_{SLUG}/{reports,plans,summaries}/`
directory tree when `state.json` names a task but no directory exists yet on disk, closing the
GATE IN abort that hit any freshly created (`not_started`) task before its directory was lazily
created. Creation is opt-in, exclusive to `acquire`, and reachable only from a `state.json`-derived
path attempted after the filesystem-glob fallback has already failed, so `check`/`heartbeat`/
`release` remain provably side-effect-free and a typo'd or unknown task number still fails
cleanly. All edits landed in the source store (`agent-system/extensions/core/`); the deploy tree
was regenerated and drift-checked.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — `resolve_task_dir()` gained an opt-in
  second parameter (`local task_number="$1" create_mode="${2:-}"`), a `state_dir` local that
  records the `state.json`-resolved path, and a creation block (`mkdir -p .../{reports,plans,
  summaries}`) placed AFTER the existing `find` fallback and gated on
  `[ "$create_mode" = "create" ] && [ -n "$state_dir" ]`. `cmd_acquire`'s sole call site now passes
  `"create"`; `cmd_heartbeat`, `cmd_release`, and `cmd_check` are byte-identical (confirmed via
  `git diff -U0`, zero changed lines in those three functions). Both the function's block comment
  and the top-of-file `acquire` exit-code comment were extended to document the opt-in,
  `acquire`-only contract.
- `agent-system/extensions/core/context/patterns/task-lock.md` — `acquire`'s contract section now
  states the full three-step resolution order (state.json -> glob -> create-if-missing) and notes
  the glob fallback never creates; `heartbeat`, `release`, and `check` each gained a one-line
  read-only guarantee; the `Consumers (Two Distinct Wiring Paths)` section notes that
  gate-bypassing consumers (`skill-orchestrate` Stage MT, `implement.md` multi-task Step 3) inherit
  the fix with zero changes of their own, since creation lives entirely inside `acquire`.
- `specs/918_task_lock_create_task_dir_before_acquire/tests/test-task-lock-create.sh` — new
  7-scenario isolated-fixture test harness (each scenario builds a fresh `mktemp -d` root with a
  `.claude/scripts/` copy of the deployed `task-lock.sh` + `deploy-root-guard.sh` and a synthetic
  `specs/state.json`; never touches the real `specs/` tree).
- `.claude/` — regenerated from the source store via `deploy-headless.sh` (gitignored, not
  hand-edited).
- `specs/914_converge_todo_roadmap_annotation_with_script/` — created as the incidental, expected
  side effect of the Phase 4 live `acquire` probe against a real `not_started` task with no prior
  directory; retained per the plan's explicit instruction (it is the directory `state.json`
  already designates for that task).

## Decisions

- Followed the plan's two corrections to the research's literal recommendation: bound
  `create_mode="${2:-}"` instead of referencing `$2` directly (avoids a `set -u` abort reachable
  from `cmd_check`), and placed the creation block after the `find` fallback rather than inside
  the `state.json` branch (preserves existing resolution precedence on slug drift instead of
  creating a second, empty directory).
- Did not touch `command-gate-in.sh`, `skill-orchestrate/SKILL.md`, or `implement.md` — all three
  system-wide `acquire` call sites funnel through `cmd_acquire`, so the fix is complete at the
  function level.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `bash -n` clean; exactly one `resolve_task_dir` call carries `"create"`; no
  `$2` reference inside `resolve_task_dir`; `git diff -U0` shows zero changed lines in
  `cmd_heartbeat`/`cmd_release`/`cmd_check`; the 7-scenario fixture harness reports
  **7 passed, 0 failed** (run twice, both green, no stray `specs/{NNN}_*` directories created);
  `verify-deploy.sh` exits 0 (11 checks, 0 failures); `check-extension-docs.sh` exits 0 with zero
  "task-lock" mentions in its drift output; live probe against real task 914 confirmed `check`
  exits 3 with no filesystem change, `acquire` exits 0 and creates
  `reports/`/`plans/`/`summaries/`/`.lock/holder.json`, and `release` exits 0, removes `.lock/`,
  and retains the directory.
- Files verified: Yes

## Notes

No follow-up items. The doc-lint run surfaced 34 pre-existing, unrelated "core script never
deployed" advisories for literature/zotero scripts — confirmed unrelated to this change (no
"task-lock" hits in the drift output) and out of scope here.
