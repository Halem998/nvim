# Implementation Summary: Task #645

**Completed**: 2026-06-08
**Duration**: ~45 minutes

## Overview

Fixed parallel write safety for `specs/state.json` by replacing all shared `specs/tmp/state.json` temp paths with unique-per-write `mktemp` files, adding `flock` exclusive locking around the state.json read-jq-write critical section in `update-task-status.sh`, and converting Python direct-write functions in `skill-base.sh` to the atomic `tempfile.mkstemp()` + `os.replace()` pattern. This eliminates the last-write-wins race condition that could corrupt state.json during multi-task orchestration waves where multiple agents call these scripts concurrently.

## What Changed

- `.claude/scripts/update-task-status.sh` — Added `LOCK_FILE` variable, wrapped `update_state_json()` non-dry-run path in `flock -x -w 30` subshell on fd 200, replaced `$TMP_DIR/state.json.tmp` with `mktemp "$TMP_DIR/state.XXXXXX.json"`, replaced both `$TMP_DIR/todo.md.tmp` usages with `mktemp "$TMP_DIR/todo.XXXXXX.md"`, updated cleanup trap to glob-match `state.??????.json` and `todo.??????.md`
- `.claude/scripts/postflight-workflow.sh` — Added `TMP_DIR="specs/tmp"` variable, added cleanup trap, replaced 3 hardcoded `> specs/tmp/state.json && mv specs/tmp/state.json` writes with `mktemp "$TMP_DIR/state.XXXXXX.json"` pattern
- `.claude/scripts/skill-base.sh` — Added `mkdir -p specs/tmp` guard and `local tmp` in `skill_link_artifacts()`, replaced 2 jq temp writes with `mktemp specs/tmp/state.XXXXXX.json`, converted `skill_increment_artifact_number()` Python to `tempfile.mkstemp()` + `os.replace()`, converted `skill_propagate_memory_candidates()` Python to same atomic pattern

## Decisions

- Used fd 200 for flock as the conventional high-fd choice that avoids conflicts with stdin/stdout/stderr and typical script file descriptors
- Applied flock only to `update-task-status.sh` (the serialization chokepoint for all lifecycle transitions); `postflight-workflow.sh` is called sequentially by skills and does not race with itself
- Used `rm -f "$tmp"` inside the flock subshell on jq error, relying on the outer cleanup trap for any residual files
- Used glob pattern `state.??????.json` (6 random chars) to match mktemp's `XXXXXX` template in cleanup trap

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: `bash -n` syntax check passed for all three scripts; `--dry-run` test produced correct output; `grep` confirmed zero remaining shared temp paths and direct Python writes; `flock --version` confirmed util-linux 2.42; `mktemp` template test generated unique filename
- Files verified: Yes

## Notes

The lock file `specs/.state.json.lock` is created automatically by bash's `200>"$LOCK_FILE"` redirection on first use and persists harmlessly between runs. flock tests lock state, not file existence, so no cleanup of the lock file is needed.
