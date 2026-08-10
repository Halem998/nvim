# Implementation Summary: Task #616

**Completed**: 2026-05-25
**Duration**: ~20 minutes

## Overview

Replaced the broken Python regex in `archive-task.sh` Step C with a working line-by-line block removal approach. The original regex matched a `- #N:` pattern that has never existed in TODO.md; the actual format is `### N. Title` blocks separated by `---` horizontal rules. Both the primary script and its extension copy were fixed and verified to be identical.

## What Changed

- `.claude/scripts/archive-task.sh` — Replaced lines 113-137 (broken Python regex block) with correct line-by-line block removal anchored on `^### {N}\. ` (literal dot + space)
- `.claude/extensions/core/scripts/archive-task.sh` — Synced identical fix from primary copy

## Decisions

- Used line-by-line removal instead of regex with `re.DOTALL` for better robustness with multi-line descriptions, last-task-without-trailing-`---` edge cases, and descriptions that might contain `---`
- Preserved the `if [ -f "$TODO_FILE" ]` guard and `|| true` error semantics so archive continues even if TODO cleanup fails
- Anchored the block start pattern with `re.escape(task_num) + r'\. '` (literal dot + space) to prevent partial number matches (task 6 matching `### 61.`)

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: Passed — 4 test cases verified:
  1. Middle block removal (preceding/following blocks remain intact)
  2. Last task without trailing `---` handled correctly
  3. Partial number match safety (`### 6.` does not match `### 61.`)
  4. Task not found returns unchanged content
- Files verified: Both copies confirmed identical via `diff`

## Notes

The bug was silently failing (exited via `|| true`) so no errors surfaced during archival, but task blocks accumulated indefinitely in TODO.md's `## Tasks` section after archival. This fix ensures the block is cleanly removed starting from the `### N.` heading through and including the `---` separator.
