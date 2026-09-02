# Implementation Summary: Remove the dead .opencode command router and its self-referential test scripts

- **Task**: 27 - Remove the dead .opencode command router and its self-referential test scripts
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T20:55:00Z
- **Completed**: 2026-09-02T21:07:00Z
- **Effort**: ~15 minutes
- **Dependencies**: None
- **Artifacts**: This summary
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`.opencode/scripts/execute-command.sh` routed slash commands via a case statement whose every
live branch sourced a `command-integration.sh` file that has never existed and called an
`execute_lean_command` function that is defined nowhere in the repository — the router had no
working dispatch path. It was invoked by nothing outside its own three test scripts. This work
deletes the router, those three test scripts, and its stale test-results note, and verifies the
tree is structurally unaffected by the removal.

## What Changed

- Deleted `.opencode/scripts/execute-command.sh` (the dead router).
- Deleted `.opencode/scripts/test-execution-system.sh`, `test-execution.sh`, and
  `test-command.sh` — all three existed solely to invoke the router and had no other purpose.
- Deleted `.opencode/scripts/test-results.md`, which documented a test plan/status for the router
  plus three sibling files that never existed (`command-execution.sh`,
  `lean-command-execution.sh`, `command-integration.sh`) and for the now-deleted test scripts.
- Re-checked `.opencode/scripts/README.md` for references to any of the above; confirmed empty
  both before and after (no edit needed).
- All five deletions are staged via `git rm` in the working tree; the commit itself is owned by
  the orchestrator's postflight, not this dispatch.

## Decisions

- **Deleted `test-results.md` outright rather than stubbing it with a "router removed" note.**
  The `.opencode/` tree is documented elsewhere as a frozen, unmaintained mirror; adding a new
  placeholder file to it for a router removal that git history already records was judged to add
  clutter with no reader benefit, versus full removal being unambiguous.
- **Did not edit README.md.** A grep for `execute-command|test-execution|test-command|test-results`
  against it returns nothing before and after the deletions — it never referenced any of the
  removed files, so no change was required.
- **Left the four other repos carrying copies of this router untouched** (Logos/Theory, protocol,
  ModelChecker, OpenCode), per the task's addendum recording `.opencode/` as a frozen mirror with
  no reload-driven propagation to verify. Out of scope by design, not an oversight.

## Plan Deviations

- None (implementation followed the task's WORK list; no separate plan artifact was produced —
  the task description carried complete measured evidence and the work was pure deletion).

## Impacts

- No live code, command, or test path depended on the router or its tests (verified below), so no
  downstream breakage is expected.
- `.opencode/scripts/` file count drops from 56 to 52 `*.sh` files (plus removal of one `*.md`
  file); no other file in the repository outside `specs/**` references any of the five removed
  paths after the change.

## Follow-ups

- None required by this task. The four downstream repo copies of the same dead router remain
  out of scope per the frozen-mirror addendum and are not tracked here.

## References

- `.opencode/scripts/execute-command.sh` (removed) — command router with no working dispatch
  branch; both `case` arms sourced a nonexistent `command-integration.sh` and called an
  undefined `execute_lean_command`.
- `.opencode/scripts/test-execution-system.sh`, `test-execution.sh`, `test-command.sh` (removed)
  — test scripts whose sole subject was the removed router.
- `.opencode/scripts/test-results.md` (removed) — stale test-status note for the removed router
  and test scripts.
- `.opencode/scripts/README.md` — re-checked, confirmed no reference to any removed file, no
  edit made.

## Verification

- **Repo-wide reference sweep**: `grep -rln "execute-command\.sh"` and, separately,
  `grep -rlnE "test-execution(-system)?\.sh|test-command\.sh|test-results\.md"` across
  `*.sh`/`*.md`/`*.json`, both restricted to outside `specs/**` — zero hits after deletion. The
  only matches (before filtering) live under `specs/**` (`TODO.md`, `state.json`, and archived
  vault reports/plans referencing this router historically), which is exempt.
- **Structural soundness**: `bash -n` across all 52 remaining `.opencode/scripts/*.sh` files —
  zero failures.
- **`assess-repo-health.sh` `build_errors`**: `1` before this change, `1` after — unchanged, not
  higher. The residual `1` is pre-existing and unrelated to this task: `jq empty` fails on
  `specs/121_delete_hard_mode_lifecycle_files/.return-meta.json`, which is deleted on disk but
  still git-tracked (a phantom-path failure another, separately-tracked task is chartered to
  fix). Confirmed via a direct `bash -n`/`jq empty` sweep of every git-tracked `*.sh`/`*.json`
  file, both before and after this change, that this was the only failing file in both runs.
