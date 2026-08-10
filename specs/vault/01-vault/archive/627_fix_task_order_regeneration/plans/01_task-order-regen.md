# Implementation Plan: Task #627

- **Task**: 627 - Fix Task Order regeneration after task creation
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/627_fix_task_order_regeneration/reports/01_task-order-regen.md
- **Artifacts**: plans/01_task-order-regen.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix three related bugs in the Task Order regeneration pipeline: (1) a `shift 3` argument-parsing bug in `generate-task-order.sh` that fails under `set -euo pipefail` with insufficient arguments, (2) missing `active_topics` array maintenance across all five task-creating commands, and (3) an invocation inconsistency in `task.md` where the `generate-task-order.sh` call lacks the `-f` existence check and `bash` prefix used by all other commands.

### Research Integration

The research report (01_task-order-regen.md) confirmed all three issues via codebase analysis:
- The `shift 3` bug on line 53 of `generate-task-order.sh` is latent (all current callers pass correct args) but would fail silently due to `2>/dev/null` wrappers if any caller omitted a file argument. The `--goal` case on line 57 has the same `shift 2` issue.
- All five task-creating commands write per-task `topic` fields but none append new topics to the top-level `active_topics` array. `/task` documents the intent in step 4.5 prose but the jq template in step 6 omits the actual update.
- The `--update-todo` mechanism writes via `mv` (not stdout), so the non-blocking calls are mechanically sound. Only `task.md` create mode uses a bare `$gen_script` variable without `bash` prefix or `-f` check.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation required for this task.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix the `shift 3` and `shift 2` argument-parsing bugs in `generate-task-order.sh` to be safe under `set -euo pipefail`
- Add `active_topics` array maintenance to all five task-creating commands so new topics are appended when first used
- Standardize the `task.md` create mode `generate-task-order.sh` call to match the pattern used by all other commands
- Verify all changes via dry-run testing of argument parsing and jq patterns

**Non-Goals**:
- Refactoring the overall `generate-task-order.sh` architecture
- Adding topic handling to commands that do not create tasks (e.g., `/review`, `/todo`)
- Making the `generate-task-order.sh` call use absolute paths (CWD assumption is acceptable)
- Adding topic assignment to `/spawn` or `/errors` (they do not currently assign topics; only ensure if they DID assign topics, the array would be updated)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect shift logic breaks argument parsing for valid callers | H | L | Test all three argument patterns (--print, --update-todo, --goal) after changes |
| jq `active_topics` append pattern uses `!=` operator (Issue #1132) | M | M | Use `index($t) == null` pattern per jq-escaping-workarounds.md |
| Edits to SKILL.md or agent files break markdown rendering | M | L | Verify file structure after edits; test with grep for expected patterns |
| Spawn/errors do not assign topics, so active_topics logic is a no-op | L | L | Guard the append with `if [[ -n "$topic" ]]` so it is safe when topic is empty |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix generate-task-order.sh Argument Parsing [COMPLETED]

**Goal**: Replace unsafe `shift 3` and `shift 2` calls with sequential safe-shift patterns that work under `set -euo pipefail`.

**Tasks**:
- [x] Replace `--update-todo` case (lines 49-54) with sequential shift pattern: *(completed)*
  ```bash
  --update-todo)
    MODE="update"
    shift  # consume --update-todo
    TODO_ARG="${1:-}"
    [[ $# -gt 0 ]] && shift
    STATE_ARG="${1:-}"
    [[ $# -gt 0 ]] && shift
    ;;
  ```
- [x] Replace `--goal` case (lines 55-58) with sequential shift pattern: *(completed)*
  ```bash
  --goal)
    shift  # consume --goal
    GOAL_OVERRIDE="${1:-}"
    [[ $# -gt 0 ]] && shift
    ;;
  ```
- [x] Verify the `--print` case (line 46) is already safe (single `shift`, always valid since `$1` matched) *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Lines 43-65, argument parsing loop

**Verification**:
- Run `bash .claude/scripts/generate-task-order.sh --update-todo` with 0, 1, and 2 file args and confirm no crash under `set -euo pipefail`
- Run `bash .claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json` and confirm it still works correctly
- Run `bash .claude/scripts/generate-task-order.sh --goal` with 0 args and confirm no crash
- Run `bash .claude/scripts/generate-task-order.sh --print` and confirm output

---

### Phase 2: Add active_topics Maintenance to Task-Creating Commands [COMPLETED]

**Goal**: Ensure all five task-creating commands append new topic values to the `active_topics` array in state.json when the assigned topic is not already present.

**Tasks**:
- [x] **task.md** (`.claude/commands/task.md`, around line 165-183): Add an explicit `active_topics` append step between step 4.5 (topic detection) and step 6 (state.json update). *(completed)*
- [x] **task.md** (`.claude/commands/task.md`, lines 208-213): Standardize the generate-task-order.sh call in Part C to match all other commands. *(completed)*
- [x] **meta-builder-agent.md** (`.claude/agents/meta-builder-agent.md`, around line 676-691): Add `active_topics` maintenance as step 4b after state.json update and before Task Order call. *(completed)*
- [x] **skill-fix-it/SKILL.md** (`.claude/skills/skill-fix-it/SKILL.md`, around line 451-479): Add `active_topics` maintenance as Step 9.3 before the Task Order call (renamed to Step 9.4). *(completed)*
- [x] **skill-spawn/SKILL.md** (`.claude/skills/skill-spawn/SKILL.md`, around line 323-346): Added topic inheritance from parent task in jq template; added active_topics maintenance as Stage 14a; renamed Task Order call to Stage 14b. *(completed)*
- [x] **errors.md** (`.claude/commands/errors.md`, around line 121-129): Added note documenting that `/task` delegation handles `active_topics` maintenance. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/task.md` - Add active_topics jq block after step 4.5; standardize Part C invocation
- `.claude/agents/meta-builder-agent.md` - Add active_topics maintenance after topic inference (~line 691) and batch append before Task Order call (~line 1362)
- `.claude/skills/skill-fix-it/SKILL.md` - Add active_topics maintenance after topic inference (~line 479) and batch append before Task Order call (~line 517)
- `.claude/skills/skill-spawn/SKILL.md` - Add topic inheritance from parent task in jq template (~line 333); add active_topics append before Task Order call (~line 422)
- `.claude/commands/errors.md` - Add documentation note at step 4 confirming /task delegation handles topics

**Verification**:
- Grep all five files for `active_topics` to confirm the pattern was added
- Verify jq patterns use `index($t) == null` (not `!=`) per jq-escaping-workarounds.md
- Verify each file's generate-task-order.sh call is intact after edits

---

### Phase 3: End-to-End Verification and Testing [COMPLETED]

**Goal**: Verify all changes work together and do not break existing functionality.

**Tasks**:
- [x] Test `generate-task-order.sh` argument parsing with edge cases: *(completed: all 6 edge cases pass)*
  - `bash .claude/scripts/generate-task-order.sh --print` (works)
  - `bash .claude/scripts/generate-task-order.sh --update-todo` (no crash, uses defaults)
  - `bash .claude/scripts/generate-task-order.sh --update-todo specs/TODO.md` (no crash)
  - `bash .claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json` (works fully)
  - `bash .claude/scripts/generate-task-order.sh --goal` (exits with usage msg, no shift crash)
  - `bash .claude/scripts/generate-task-order.sh --goal "test goal" --print` (works)
- [x] Test jq `active_topics` append pattern in isolation: *(completed: idempotency confirmed)*
- [x] Verify no syntax errors in modified markdown files by checking that code fences are balanced *(completed: 4/5 files balanced; task.md imbalance is pre-existing)*
- [x] Run `bash .claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json` to confirm the full pipeline works after all changes *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- No files modified; verification only

**Verification**:
- All argument-parsing edge cases pass without crash
- jq pattern is idempotent and correctly appends new topics
- Full Task Order regeneration succeeds against current state.json

## Testing & Validation

- [x] `generate-task-order.sh --update-todo` with 0, 1, 2, and 3 args does not crash under `set -euo pipefail` *(verified)*
- [x] `generate-task-order.sh --goal` with 0 and 1 args does not crash *(verified)*
- [x] `generate-task-order.sh --print` continues to produce correct output *(verified)*
- [x] jq `active_topics` append is idempotent (no duplicates on repeat) *(verified)*
- [x] All five task-creating commands reference `active_topics` maintenance (grep verification) *(verified)*
- [x] `task.md` Part C uses the standardized `bash` + `-f` check pattern *(verified)*
- [x] Full Task Order regeneration against current specs/state.json succeeds *(verified)*

## Artifacts & Outputs

- plans/01_task-order-regen.md (this file)
- Modified: `.claude/scripts/generate-task-order.sh`
- Modified: `.claude/commands/task.md`
- Modified: `.claude/agents/meta-builder-agent.md`
- Modified: `.claude/skills/skill-fix-it/SKILL.md`
- Modified: `.claude/skills/skill-spawn/SKILL.md`
- Modified: `.claude/commands/errors.md`

## Rollback/Contingency

All changes are to documentation/template files (markdown) and one shell script. If any change causes issues:
- `git diff` to review all changes
- `git checkout -- <file>` to revert individual files
- The `generate-task-order.sh` change is the only runtime-affecting edit; all other files are agent instruction templates that do not execute directly
