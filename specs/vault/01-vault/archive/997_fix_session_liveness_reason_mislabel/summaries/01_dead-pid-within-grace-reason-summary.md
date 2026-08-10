# Implementation Summary: Report a confirmably-dead pid within the grace floor as its own liveness reason

- **Task**: 997 - Report a confirmably-dead pid within the grace floor as its own liveness reason
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T03:10:00Z
- **Completed**: 2026-08-10T03:57:00Z
- **Effort**: ~50 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_dead-pid-within-grace-reason.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`session_liveness()` in `task-lock.sh` discarded the result of its own `kill -0` probe when a
registry entry's heartbeat age was at or below `SESSION_REGISTRY_DEAD_PID_MIN`, falling through
to a branch that labeled the entry `pid-alive` purely because the `pid` field was numeric — even
though the probe had just proven the process gone. This positively misled operator-facing defer
output. The fix carries the `kill -0` result forward into the fallback branch, introduces a
distinct sixth reason (`dead-pid-within-grace`), and preserves the existing verdict
(`live: true`, not reaped) byte-for-byte. Both phases of the plan are complete: Phase 1 (ladder
fix, docstring, and reason-string test assertions with a required falsifiability check) and
Phase 2 (reconciling every doc/comment site describing the reason count, redeploying, and running
the full verification gate).

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — `session_liveness()`: added a
  `pid_dead=false` local, set `true` when `kill -0` fails, and extended the fallback branch to
  check `pid_dead` before falling back to `pid-alive`/`undeterminable`. Updated the in-file
  docstring above the function, and (incidental fix found during Phase 2's repo-wide sweep)
  corrected `cmd_session_list`'s own header comment, which enumerated the `live`-derivation
  membership list without the new reason.
- `agent-system/extensions/core/scripts/test-session-registry.sh` — added case `5a` (asserts
  `session-list` reports `dead-pid-within-grace`/`dead-pid`/`pid-alive` correctly across the
  grace-floor boundary, placed before the live reap so `sess_dead_old` is still listable) and
  extended Case 6's dry-run assertion to confirm `sess_dead_young` is never selected for reap.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — added case `4.2b`: proves a
  `dead-pid-within-grace` session both reports the correct reason/`live:true` via `session-list`
  and still contends via `orchestrate-batch-admit.sh` (`decision: defer`,
  `defer_reason: session_active`, `session_liveness_reason: dead-pid-within-grace`).
- `agent-system/extensions/core/context/patterns/task-lock.md` — five prose edits: new
  `dead-pid-within-grace` bullet in the reason list, "other four" -> "other five" on the
  `corrupt` bullet, extended the do-not-reap paragraph and the `session-reap` two-signal step 2
  parenthetical, and added the new reason to the `session-list` `live`-derivation membership
  list.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — schema-table row:
  "five reasons" -> "six reasons", added `dead-pid-within-grace` to the allowed-value list.
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — header-comment entry:
  identical count and allowed-value-list edits, confirmed to stay entirely inside `#`-comment
  lines via `bash -n` and a `git diff` read-through (guards the `prose` verification tier's named
  blind spot).

## Decisions

- No changes to `cmd_session_list`'s `live_flag` case, `cmd_session_reap`'s reap set, or
  `scripts/lib/file-scope-overlap.sh` — their `dead-pid|stale-heartbeat)` wildcard defaults
  already produce the required verdict for any new reason, confirmed by `git diff --stat`
  showing zero changes to those code paths and by test case `4.2b` proving the contend-set is
  empirically unchanged (not merely asserted).
- Performed the falsifiability check via `git stash push --keep-index -- task-lock.sh` (isolating
  the code hunk from the still-modified test files), confirming both new assertions (case `5a`
  and case `4.2b`) FAIL against the pre-fix ladder before restoring the fix and re-confirming
  both suites green.
- Fixed one incidental site beyond the plan's three declared Phase 2 files
  (`task-lock.sh`'s `cmd_session_list` header comment) after the Scope Hypothesis re-sweep
  surfaced it as the same implicit-membership-list defect class; left the structurally identical
  comment in `scripts/lib/file-scope-overlap.sh` untouched per the plan's explicit Non-Goal.

## Plan Deviations

- None (implementation followed plan; the one incidental `task-lock.sh` comment fix was
  anticipated and pre-authorized by Phase 2's own Scope Hypothesis clause: "Any additional site
  found is an in-scope incidental edit for this phase, recorded in the summary").

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `test-session-registry.sh` 11/11, `test-conflict-predicate.sh` 24/24, both run
  from the source store so they exercised the edited `task-lock.sh`.
- Files verified: Yes — `bash -n` clean on `task-lock.sh` and `orchestrate-batch-admit.sh`;
  `git diff --stat` confirmed each phase's edit scope matched its Scope Hypothesis.
- `bash .claude/scripts/deploy-headless.sh` completed successfully.
- `bash .claude/scripts/verify-deploy.sh`: gate 4 (task-reference lint) and gate 5 (content-hash
  parity) both PASS. Two unrelated, pre-existing gates also reported FAIL and are NOT caused by
  this task: gate 3 doc-lint's "core script never deployed" advisories (all name `literature`
  extension scripts; traced to `.claude-extensions.json`/literature-extension drift present in
  `git status` before this task's session began) and gate 8's shell-suite runner, whose sole
  failure is the pre-existing `test-index-entries-schema.sh` (an EXTENSION.md schema-linting
  fixture suite unrelated to `session_liveness()` or any file this task touched).
  `test-four-tier-conflict.sh`, noted as occasionally flaky, was green on every re-run performed
  during this task.

## Impacts

- Operators diagnosing a `session_active` defer verdict for a confirmably-dead pid within the
  grace window now see `dead-pid-within-grace` instead of the misleading `pid-alive`, pointing
  debugging toward "wait out the grace floor or reap" instead of "hunt a live process that
  doesn't exist."
- No behavioral change to admission decisions, reap eligibility, or contention detection — the
  fix is reason-string-only, confirmed by test coverage that checks `live`/`decision`/
  `defer_reason` directly, not just the string.

## Follow-ups

- None. The suffixed-vs-bare `session_id` self-contention defect noted in the originating
  research report remains explicitly out of scope (no code-path overlap with this fix).

## References

- Plan: specs/997_fix_session_liveness_reason_mislabel/plans/01_dead-pid-within-grace-reason.md
- Research report: specs/997_fix_session_liveness_reason_mislabel/reports/01_verify-liveness-reason-ladder.md
- Progress: specs/997_fix_session_liveness_reason_mislabel/progress/phase-1-progress.json,
  specs/997_fix_session_liveness_reason_mislabel/progress/phase-2-progress.json
- Handoff: specs/997_fix_session_liveness_reason_mislabel/handoffs/phase-1-handoff-20260810T031120Z.md
