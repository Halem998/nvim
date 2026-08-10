# Implementation Summary: Task #627

**Completed**: 2026-06-01
**Duration**: ~1.5 hours

## Overview

Fixed three related bugs in the Task Order regeneration pipeline: (1) unsafe `shift 3`/`shift 2` argument-parsing bugs in `generate-task-order.sh` that would crash under `set -euo pipefail` with fewer than expected arguments, (2) missing `active_topics` array maintenance across all five task-creating commands, and (3) an invocation inconsistency in `task.md` Part C that lacked the `bash` prefix and `-f` existence check used by all other commands.

## What Changed

- `.claude/scripts/generate-task-order.sh` — Fixed `--update-todo` case to use sequential safe-shift pattern instead of `shift 3`; fixed `--goal` case similarly instead of `shift 2`
- `.claude/extensions/core/scripts/generate-task-order.sh` — Same fix applied to the mirror copy in core extension
- `.claude/commands/task.md` — Added explicit `active_topics` append code block in step 4.5 (Active Topics Maintenance); standardized Part C to use `bash` + `-f` check pattern
- `.claude/extensions/core/commands/task.md` — Added Part C (Task Order section update) which was missing from the core extension copy
- `.claude/agents/meta-builder-agent.md` — Added step 4b with batch `active_topics` append for all tasks created by `/meta`
- `.claude/extensions/core/agents/meta-builder-agent.md` — Added step 4a (Task Order call) and 4b (active_topics batch append) which were missing from core extension
- `.claude/skills/skill-fix-it/SKILL.md` — Added Step 9.3 (`active_topics` maintenance); renamed old Step 9.3 to Step 9.4
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` — Added Steps 9.3 and 9.4 (same changes)
- `.claude/skills/skill-spawn/SKILL.md` — Added `parent_topic` extraction from task data; added topic inheritance in jq template; added Stage 14a (`active_topics` maintenance) and Stage 14b (Task Order call, renamed from 14a)
- `.claude/extensions/core/skills/skill-spawn/SKILL.md` — Same changes applied to core extension mirror
- `.claude/commands/errors.md` — Added documentation note confirming `/task` delegation handles `active_topics`
- `.claude/extensions/core/commands/errors.md` — Added Task Order call (Step 4a) and topic note

## Decisions

- Used `index($t) == null` pattern for jq idempotency check (avoids `!=` operator per jq Issue #1132)
- For skill-spawn, added topic inheritance (parent topic flows to spawned tasks) rather than just a no-op guard, since spawn creates tasks that are logically part of the same workflow as the parent
- Treated `errors.md` as a delegation case (creates tasks via `/task`) rather than adding direct active_topics logic, since `/task` already handles topic detection and maintenance
- The pre-existing odd code fence count in `task.md` is unrelated to this task's changes (verified via git stash)

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: All argument-parsing edge cases pass; jq idempotency confirmed; full pipeline regeneration succeeds
- Files verified: Yes — all 5 task-creating commands confirmed to reference `active_topics`; all jq patterns use safe `index($t) == null` form

## Notes

The `--goal` with no arguments exits with a usage error (not a crash), which is correct behavior - a mode must be specified via `--print` or `--update-todo`. The fix prevents the previous crash that occurred when `shift 2` was attempted with only 1 argument remaining (the `--goal` token itself), which under `set -euo pipefail` would terminate the script.
