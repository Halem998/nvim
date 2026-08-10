# Implementation Plan: Task #604

- **Task**: 604 - add_task_order_regen_to_creators
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/604_add_task_order_regen_to_creators/reports/01_task-order-regen.md
- **Artifacts**: plans/01_task-order-regen.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `generate-task-order.sh --update-todo` calls to four task-creating commands that currently skip Task Order regeneration, causing newly created tasks to not appear in the Task Order section until the next `/todo` or `/review` cycle. The fix inserts a non-blocking regen call at the identified insertion point in each gap file, using the established reference pattern from `task.md` Part C. The policy documentation in `state-management.md` is updated to reflect that task creation now triggers regeneration.

### Research Integration

- **Report**: `specs/604_add_task_order_regen_to_creators/reports/01_task-order-regen.md` -- Identified all 4 gap files with exact insertion points, confirmed `generate-task-order.sh` is safe under `set -euo pipefail`, and documented the reference call pattern.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `generate-task-order.sh --update-todo` call to `meta-builder-agent.md`, `skill-spawn/SKILL.md`, `skill-fix-it/SKILL.md`, and `errors.md`
- Update `state-management.md` to remove "Task creation" from Non-Regeneration Events and add it to Regeneration Triggers
- Use the established non-blocking pattern (suppress stderr, log non-fatal on failure)

**Non-Goals**:
- Modifying `generate-task-order.sh` itself (already confirmed safe)
- Changing existing regen call sites in `task.md`, `todo.md`, `review.md`, or `update-task-status.sh`
- Adding per-task regen in batch creators (single call after all tasks suffices)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regen call fails and blocks task creation | M | L | Non-blocking pattern: `2>/dev/null \|\| echo "..."` ensures failure is non-fatal |
| Double regen in `errors.md` (delegates to `/task` which already regens) | L | H | Harmless: idempotent operation, minor overhead only |
| Insertion point line numbers drift from research | L | M | Use content-based matching (Edit tool), not line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add regen calls to 4 gap files [COMPLETED]

**Goal**: Insert `generate-task-order.sh --update-todo` call at the correct point in each of the four task-creating files, using the non-blocking reference pattern.

**Tasks**:
- [ ] Read `meta-builder-agent.md` Stage 6 to find exact insertion point between state.json update (item 4) and git commit (item 5)
- [ ] Insert regen call block in `meta-builder-agent.md` Stage 6 between state.json update and git commit
- [ ] Read `skill-spawn/SKILL.md` to find Stage 14/15 boundary
- [ ] Insert regen call in `skill-spawn/SKILL.md` after Stage 14 (parent deps updated), before Stage 15 (git commit)
- [ ] Read `skill-fix-it/SKILL.md` to find Step 9.2/10 boundary
- [ ] Insert regen call in `skill-fix-it/SKILL.md` between Step 9.2 (all tasks written) and Step 10 (display)
- [ ] Read `errors.md` to find Step 4/5 boundary
- [ ] Insert regen call in `errors.md` after Step 4 (fix tasks created), before Step 5 (output)
- [ ] Verify all 4 insertions use the consistent non-blocking pattern:
  ```
  if [ -f ".claude/scripts/generate-task-order.sh" ]; then
    bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
      2>/dev/null || echo "Note: Failed to regenerate Task Order (non-fatal)" >&2
  fi
  ```

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Stage 6: insert regen between state.json update and git commit
- `.claude/skills/skill-spawn/SKILL.md` - After Stage 14: insert regen before Stage 15 git commit
- `.claude/skills/skill-fix-it/SKILL.md` - After Step 9.2: insert regen before Step 10 display
- `.claude/commands/errors.md` - After Step 4: insert regen before Step 5 output

**Verification**:
- `grep -c "generate-task-order" .claude/agents/meta-builder-agent.md` returns >= 1
- `grep -c "generate-task-order" .claude/skills/skill-spawn/SKILL.md` returns >= 1
- `grep -c "generate-task-order" .claude/skills/skill-fix-it/SKILL.md` returns >= 1
- `grep -c "generate-task-order" .claude/commands/errors.md` returns >= 1
- Each insertion is positioned BEFORE the git commit step in its respective file

---

### Phase 2: Update state-management.md policy [COMPLETED]

**Goal**: Update `state-management.md` to reflect the new policy that task creation triggers Task Order regeneration.

**Tasks**:
- [ ] Read `state-management.md` Non-Regeneration Events section (around line 101-111)
- [ ] Remove "Task creation (before the task enters a terminal or near-terminal state)" bullet from Non-Regeneration Events list
- [ ] Add new row to the Regeneration Triggers table: `| Task creation | /task, /meta, /spawn, /fix-it, /errors | generate-task-order.sh --update-todo |`
- [ ] Verify the Non-Regeneration Events list no longer mentions task creation
- [ ] Verify the Regeneration Triggers table includes the new task creation row

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/rules/state-management.md` - Remove task creation from Non-Regeneration Events, add to Regeneration Triggers table

**Verification**:
- `grep -c "Task creation" .claude/rules/state-management.md` in Non-Regeneration section returns 0
- Regeneration Triggers table contains row with "Task creation" and lists all 5 commands

## Testing & Validation

- [ ] `grep -rn "generate-task-order" .claude/agents/meta-builder-agent.md .claude/skills/skill-spawn/SKILL.md .claude/skills/skill-fix-it/SKILL.md .claude/commands/errors.md` shows all 4 files contain the regen call
- [ ] Each regen call uses the non-blocking pattern (stderr suppressed, failure logged as non-fatal)
- [ ] Each regen call is positioned after state.json + TODO.md writes and before git commit
- [ ] `state-management.md` Regeneration Triggers table includes "Task creation" row
- [ ] `state-management.md` Non-Regeneration Events no longer lists "Task creation"

## Artifacts & Outputs

- `specs/604_add_task_order_regen_to_creators/plans/01_task-order-regen.md` (this plan)
- `specs/604_add_task_order_regen_to_creators/summaries/01_task-order-regen-summary.md` (after implementation)

## Rollback/Contingency

All changes are to markdown instruction files (agent definitions, skill definitions, command definitions, rules). If any change causes issues, revert the specific file using `git checkout HEAD -- <file>`. Since the regen calls are non-blocking by design, even a broken insertion would not prevent task creation from succeeding -- only Task Order regeneration would fail silently.
