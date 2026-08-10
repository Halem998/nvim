# Implementation Summary: Task #882

**Completed**: 2026-07-16
**Duration**: ~2 hours

## Overview

Implemented both halves of the hybrid verdict from research: exposed the existing
`acquire_scope_mutex`/`release_scope_mutex` primitive on `task-lock.sh` as a standalone
`scope-acquire`/`scope-release` CLI, wired it to bracket exactly the `specs/state.json`
read-modify-write plus `TODO.md`-regeneration window (`orchestrator-postflight.sh` Stages 7
through 8a), gave `update-task-status.sh`'s standalone path the same protection via an inherited
`SCOPE_MUTEX_HELD` re-entrancy guard, and made Stage 9 commit messages honestly name every other
task whose current index rows a commit carries. All six plan phases completed and were verified
against the live `.claude/scripts/` deploy copy without ever creating a real commit or disturbing
any other task's data.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — extended `acquire_scope_mutex` to accept
  an optional holder-declared stale-window argument (written to `specs/.scope-lock/stale_sec`,
  read by every waiter instead of each waiter's own default); added `cmd_scope_acquire`
  (`scope-acquire <session_id> [stale_sec]`, owner-token write, no `RETURN` trap) and
  `cmd_scope_release` (`scope-release <token>`, owner-token-verified, best-effort, always exits 0);
  registered both in the dispatch table and usage/header documentation.
- `agent-system/extensions/core/scripts/update-task-status.sh` — brackets the state.json
  read-modify-write plus the `generate-todo.sh` call in the scope mutex when invoked standalone;
  skips acquire/release entirely (guest mode) when `SCOPE_MUTEX_HELD=1` is already set by an outer
  holder; extends the script's pre-existing `cleanup` EXIT trap (rather than installing a second
  one) to also release the mutex, idempotently, on any exit path.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — acquires the scope mutex
  immediately before Stage 7 with `POSTFLIGHT_SCOPE_STALE_SEC=30`, exports `SCOPE_MUTEX_HELD=1` so
  Stage 7's `update-task-status.sh` child inherits the guard, installs an EXIT trap (the first and
  only trap in this script), and releases explicitly at the close of Stage 8a — Stage 8b (TTS),
  Stage 9 (git commit), and Stage 10 (cleanup) run outside the mutex. Stage 9 also gained a
  failure-tolerant staged-diff scan (python3, parsed `active_projects` entry comparison, never a
  raw line diff) that appends `Also carries current index rows for tasks: N, M` to the commit
  message when the commit's staged `state.json` carries other tasks' current rows.
- `agent-system/extensions/core/context/patterns/task-lock.md` — new "Scope-Mutex CLI" section
  documenting `scope-acquire`/`scope-release`, the `SCOPE_MUTEX_HELD` re-entrancy contract and the
  EXIT-trap caller requirement, holder-declared staleness, owner-token-verified release, the two
  reference consumers, and the relationship to the (distinct, orthogonal) task-number lock.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new "State-Write
  Serialization and Honest Commit Messages" section cross-referencing `task-lock.md` and explaining
  the Stage 9 commit-message addendum; the existing staging-scope contract itself is unchanged.
- `specs/882_research_shared_index_commit_serialization/summaries/01_scope-mutex-serialization-summary.md` —
  this summary.

## Decisions

- Reused the pre-existing `cleanup` EXIT trap in `update-task-status.sh` (extended, idempotent
  release) rather than installing and later clearing a second dedicated trap — functionally
  equivalent to the plan's literal wording and verified by a forced-failure test, with less
  trap-stacking complexity in a script that already had one. `orchestrator-postflight.sh` had no
  pre-existing trap, so it follows the plan's install/clear pattern literally.
- `POSTFLIGHT_SCOPE_STALE_SEC=30`: Phase 1's audit measured the Stages 7-8a span's dominant
  sub-operations (state.json read-modify-write round trips, `generate-todo.sh`) at roughly
  300-400ms worst case; 6x that is well under the plan's mandated 30s floor, so the floor governs.
- Ambient system load from concurrently-running sibling agent sessions made raw wall-clock
  measurements unreliable during Phase 4 testing (a previously-23ms `generate-todo.sh` call
  measured ~2.4s under load, confirmed independent of this task's changes via direct re-timing).
  The deadlock-regression check was therefore done as a load-independent A/B comparison (same
  external contention, with vs. without the `SCOPE_MUTEX_HELD` guard) rather than a bare
  before/after wall-clock delta.

## Plan Deviations

- **Task 3.3** altered: reused `update-task-status.sh`'s existing `cleanup` EXIT trap (extended to
  also call the idempotent `release_state_mutex`) instead of installing a second, dedicated trap
  and clearing it after the explicit release. See Decisions above.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on all three modified scripts, both source and
  deployed copies)
- Tests: All Testing & Validation checklist items in the plan verified and checked off — regression
  on the pre-existing `acquire`/`heartbeat`/`release`/`check` path; `scope-acquire` fail-closed
  contention; `scope-release` owner-token mismatch protection; the deadlock-regression A/B
  comparison; EXIT-trap release under three different forced-failure mechanisms (proxy, unwritable
  tmp dir, literal `kill -TERM` mid-Stage-7); two concurrent full `orchestrator-postflight.sh` runs
  on different tasks with no lost write; the Stage 9 commit-message scan's four scenarios in an
  isolated scratch git repo; `check-extension-docs.sh` PASS
- Files verified: Yes — `.claude/scripts/{task-lock.sh,update-task-status.sh,orchestrator-postflight.sh}`
  and `.claude/context/{patterns/task-lock.md,standards/git-staging-scope.md}` are fully deployed,
  byte-identical to source, and left in a working, verified-green state; no real git commit was
  ever created during testing (git HEAD unchanged until this task's own phase commits); task 882's
  own `.lock/` and `state.json` row, and the three explicitly-protected pre-existing working-tree
  edits (`.claude-extensions.json`, `lua/neotex/plugins/editor/which-key.lua`,
  `lua/neotex/plugins/tools/himalaya/utils/cli.lua`), were verified untouched throughout.

## Notes

An early Phase 2 regression test mistakenly deleted the live task-882 `.lock/` (held by the
orchestrating session) via `task-lock.sh release`'s unconditional, ownership-blind removal —
this was caught and the lock was restored with the correct `session_id`/`operation`/`command`
before continuing; all further destructive-path testing used a disposable scratch task directory
instead. All scratch task rows added to `specs/state.json` during testing (project numbers
99997, 99998, 99999) were removed via targeted `jq del()` operations against the live,
possibly-concurrently-modified file — never a wholesale overwrite — to avoid clobbering any
sibling session's concurrent writes.
