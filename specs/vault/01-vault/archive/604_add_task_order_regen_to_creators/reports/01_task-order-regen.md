# Research Report: Task #604

**Task**: 604 - add_task_order_regen_to_creators
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:15:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/commands/task.md` - Reference implementation for regen call pattern
- `.claude/agents/meta-builder-agent.md` - Gap file #1
- `.claude/skills/skill-spawn/SKILL.md` - Gap file #2
- `.claude/skills/skill-fix-it/SKILL.md` - Gap file #3
- `.claude/commands/errors.md` - Gap file #4
- `.claude/rules/state-management.md` - Non-Regeneration Events policy
- `.claude/scripts/update-task-status.sh` - Mode A/B regeneration patterns
- `.claude/scripts/generate-task-order.sh` - Script source
- `grep -rn "generate-task-order"` search across `.claude/`
**Artifacts**:
- `specs/604_add_task_order_regen_to_creators/reports/01_task-order-regen.md`
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

---

## Executive Summary

- `generate-task-order.sh --update-todo` is currently called in `/task` (create mode), `/todo`, `/review`, `update-task-status.sh` (Mode B terminal), and `update-task-status.sh` (Mode A fallback) — but NOT in the four task-creating commands: `meta-builder-agent.md`, `skill-spawn`, `skill-fix-it`, and `errors.md`.
- All four gap files create task entries in `state.json` and `TODO.md` but leave the Task Order section stale until the next `/todo` or `/review` cycle.
- The reference pattern from `task.md` Part C is a one-liner bash guard: check script exists, run `--update-todo`, suppress stderr, log non-fatal on failure.
- `generate-task-order.sh` already uses `if [[ "$rx" != "$ry" ]]; then` in `cc_union()` (the fix was already applied) — the script is safe under `set -euo pipefail`.
- `state-management.md` Non-Regeneration Events explicitly lists "Task creation" as a non-trigger; this policy must be updated to reflect the new design.
- Each gap file has a distinct insertion point; skill-spawn's is after Stage 14 (before git commit); meta-builder-agent's is between the batch TODO insert and git commit in Stage 6; skill-fix-it's is after Step 9.2; errors.md's is after Step 4.

---

## Context & Scope

Task 604 closes the creation gap in Task Order regeneration. The `generate-task-order.sh --update-todo` script already handles all post-creation status changes via `update-task-status.sh` (Mode B for terminal transitions, Mode A fallback for new tasks not yet in the tree). The remaining gap is that newly created tasks do not appear in the Task Order section until some later regeneration event fires.

This research identifies the exact insertion points in each of the four gap files and documents the current policy in `state-management.md` that needs updating.

---

## Findings

### Current Call Sites for generate-task-order.sh

| File | Line(s) | Context |
|------|---------|---------|
| `commands/task.md` | 211, 356 | Part C (create mode) and Sync mode Step 6 |
| `commands/todo.md` | 679-686, 811-813 | Step 5.8 archival and post-vault regen |
| `commands/review.md` | 834-841, 859 | Section 6.5 post-review regen |
| `scripts/update-task-status.sh` | 239-255 | Mode B: terminal transitions (COMPLETED/ABANDONED/EXPANDED) |
| `scripts/update-task-status.sh` | 268-278 | Mode A fallback: task not found in tree |
| `skills/skill-todo/SKILL.md` | 647-653, 660-661 | Step 5.8 archival regen |

**Confirmed absent** from: `meta-builder-agent.md`, `skill-spawn/SKILL.md`, `skill-fix-it/SKILL.md`, `commands/errors.md`.

### Reference Pattern (from task.md Part C)

```bash
# Update Task Order section (non-blocking)
gen_script=".claude/scripts/generate-task-order.sh"
"$gen_script" --update-todo specs/TODO.md specs/state.json 2>/dev/null || echo "Note: Failed to regenerate Task Order section (non-fatal)"
```

Alternate inline form (also seen in task.md Sync mode):
```bash
.claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json 2>/dev/null || \
  echo "Warning: Task Order regeneration failed (non-fatal)"
```

Both forms are equivalent; the guard pattern with `gen_script` variable is cleaner for multiple steps but a single inline call suffices for each gap file.

### Gap File #1: meta-builder-agent.md

**Task creation location**: Stage 6 (Status Updates) — the agent builds all task entries in memory in topological order, inserts them into TODO.md as a batch, then updates state.json and runs git commit.

**Current Stage 6 sequence**:
1. Build task entries batch (sorted order)
2. Insert batch into TODO.md after `## Tasks` heading
3. Include all required fields
4. Update state.json (add to active_projects, increment next_project_number)
5. Git Commit: `git commit -m "meta: create {N} tasks for {domain}"`

**Insertion point**: Between items 4 (state.json update) and 5 (git commit). The regen call should run after both TODO.md insertion and state.json update are complete, so the script has fresh data. The call goes BEFORE the git commit so it is included in the same commit.

**Special considerations**: This is a batch creation agent — it creates N tasks in a single operation. A single `generate-task-order.sh --update-todo` call after all tasks are inserted handles the entire batch correctly, since the script reads `state.json` to discover all active tasks at once.

### Gap File #2: skill-spawn/SKILL.md

**Task creation location**: Stages 10-14 (postflight section). The skill creates new task directories (Stage 10), updates state.json with new tasks (Stage 11), updates TODO.md with new task entries (Stage 12), updates parent task dependencies in state.json (Stage 13), and updates parent task in TODO.md (Stage 14).

**Current Stage sequence (relevant)**:
- Stage 12: Update TODO.md with New Task Entries — already has `update-recommended-order.sh refresh` call (for a different section)
- Stage 13: Update Parent Task Dependencies (state.json)
- Stage 14: Update Parent Task Dependencies in TODO.md
- Stage 15: Git Commit (`task {N}: spawn {M} tasks to resolve blocker`)
- Stage 16: Cleanup

**Insertion point**: After Stage 14 (both state.json and TODO.md fully updated) and before Stage 15 (git commit). This mirrors the task.md pattern where regen runs after all state is written, before committing.

**Note about existing update-recommended-order.sh**: The existing call at Stage 12 targets the `## Recommended Order` section (a different section from `## Task Order`). The new `generate-task-order.sh` call targets the `## Task Order` section. Both can coexist.

### Gap File #3: skill-fix-it/SKILL.md

**Task creation location**: Steps 8-9. Step 8 creates task data in memory; Step 9 writes state.json and TODO.md.

**Current Step 9 sequence**:
- Step 9.1: Update state.json (jq to add task, increment next_project_number)
- Step 9.2: Update TODO.md (prepend task entry to `## Tasks` section)
- Step 10: Display Results (summary table)
- Step 11: Git Commit

**Insertion point**: Between Step 9.2 (after all tasks written) and Step 10 (display), OR just before Step 11 (git commit). Since multiple tasks may be created in a loop (learn-it, fix-it, TODO tasks, research tasks each in separate iterations), the regen call should come AFTER the outer loop completes — i.e., after all Step 9 iterations are done and before Step 10 display.

**Special consideration**: The regen call should be a single call after all tasks are created, not one call per task. The script regenerates from state.json in full, so one call covers the entire batch.

### Gap File #4: errors.md

**Task creation location**: Step 4 (Create Fix Tasks). The command creates tasks via `/task "Fix: {error description} ({N} occurrences)"` for each significant error pattern.

**Current Step 4 / Step 5 sequence**:
- Step 4: Create Fix Tasks (calls `/task` for each error pattern)
- Step 5: Output summary

**Insertion point**: After Step 4 (after all fix tasks created) and before Step 5 (output). Because `/task` itself calls `generate-task-order.sh` (Part C), each individual `/task` call already triggers a regen. However, if errors.md is ever refactored to create tasks directly (without delegating to `/task`), this gap would reopen. For robustness, an explicit regen call at the end of Step 4 (or start of Step 5) should be added.

**Note**: The errors.md command currently delegates to `/task`, which already includes the regen call. The gap here is lower-priority than the other three, which create tasks directly via jq/Edit tool calls. However, the policy change in state-management.md and potential future refactoring make it worth adding the explicit call for clarity.

### update-task-status.sh Mode A and Mode B

**Mode B** (lines 239-256): Fires on terminal status transitions (COMPLETED, ABANDONED, EXPANDED). Calls `generate-task-order.sh --update-todo`. This covers archival-driven regen.

**Mode A fallback** (lines 268-278): Fires when `update_todo_task_order()` cannot find the task number in the existing Task Order tree (new task not yet in tree). This is the existing "new task" path that fires on first status change, not at creation time.

Mode A is a best-effort fallback — it fires on first status update if the task is missing from the tree. Adding explicit regen at creation time is better because:
1. The task appears in Task Order immediately after creation
2. No waiting for first status change
3. Policy is clear: creation always triggers regen

### state-management.md Non-Regeneration Events Section

**Current policy** (lines 101-111):
```
These events do NOT trigger Task Order regeneration:
- Task creation (before the task enters a terminal or near-terminal state)
- Status transitions to researching, researched, planning, planned, implementing, partial, blocked
- Roadmap annotation updates
- Git commits and state.json writes not involving task number changes
- Memory harvest operations
```

**Required change**: Remove "Task creation" from the Non-Regeneration Events list and add it to the Regeneration Triggers table. The new policy is: regen on ALL task creation events.

**Updated Regeneration Triggers table** should include:
| Task creation | `/task`, `/meta`, `/spawn`, `/fix-it`, `/errors` | `generate-task-order.sh --update-todo` |

---

## Decisions

- The `generate-task-order.sh` script is already fixed (`cc_union()` uses `if/then` not `&&`) — no script changes needed.
- All four gap files need a non-blocking `generate-task-order.sh --update-todo` call added after task creation completes.
- The regen call should always go BEFORE the final git commit in each file, so the regenerated Task Order is included in the same commit as the new tasks.
- For batch creators (meta-builder-agent, skill-fix-it), a single regen call after all tasks are created is correct — not one call per task.
- `state-management.md` Non-Regeneration Events section must be updated to remove "Task creation" and add it to the Regeneration Triggers table.
- `errors.md` regen addition is lower-priority since it delegates to `/task` which already calls regen, but should be added for policy consistency.

---

## Recommendations

1. **meta-builder-agent.md (Stage 6)**: Insert regen call between state.json update (item 4) and git commit (item 5):
   ```bash
   # Update Task Order section (non-blocking)
   if [ -f ".claude/scripts/generate-task-order.sh" ]; then
     bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
       2>/dev/null || echo "Note: generate-task-order.sh not found -- skipping Task Order regeneration" >&2
   fi
   ```

2. **skill-spawn/SKILL.md (after Stage 14)**: Add a new step before Stage 15 git commit:
   ```bash
   # Update Task Order section (non-blocking)
   if [ -f ".claude/scripts/generate-task-order.sh" ]; then
     bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
       2>/dev/null || echo "Note: Failed to regenerate Task Order (non-fatal)" >&2
   fi
   ```

3. **skill-fix-it/SKILL.md (between Step 9.2 and Step 10)**: Add regen after the task creation loop completes:
   ```bash
   # Update Task Order section (non-blocking)
   if [ -f ".claude/scripts/generate-task-order.sh" ]; then
     bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
       2>/dev/null || echo "Note: Failed to regenerate Task Order (non-fatal)" >&2
   fi
   ```

4. **errors.md (between Step 4 and Step 5)**: Add regen after fix tasks are created:
   ```bash
   # Update Task Order section (non-blocking)
   if [ -f ".claude/scripts/generate-task-order.sh" ]; then
     bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
       2>/dev/null || echo "Note: Failed to regenerate Task Order (non-fatal)" >&2
   fi
   ```

5. **state-management.md Non-Regeneration Events section**: Remove "Task creation" bullet. Add row to Regeneration Triggers table: `| Task creation | /task, /meta, /spawn, /fix-it, /errors | generate-task-order.sh --update-todo |`

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Regen call is blocking and fails | All calls use `2>/dev/null \|\| echo "..."` — non-fatal pattern from reference |
| `set -euo pipefail` in generate-task-order.sh causes exit on cc_union | Already fixed: `cc_union` uses `if/then` not `&&` short-circuit |
| errors.md delegates to `/task` which already regens — double regen | Harmless: double regen produces identical output, only minor overhead |
| Partial batch in meta-builder-agent (some tasks created, regen runs, then more tasks added) | Regen runs after ALL tasks are created in batch; single call covers full set |

---

## Appendix

### Search Queries Used
- `grep -rn "generate-task-order" .claude/ --include="*.sh" --include="*.md"`
- `grep -rn "update-recommended-order" .claude/skills/skill-spawn/SKILL.md`
- `grep -n "task-order\|generate-task-order" .claude/agents/meta-builder-agent.md`
- `grep -n "task-order\|generate-task-order" .claude/skills/skill-fix-it/SKILL.md`
- `grep -n "task-order\|generate-task-order" .claude/commands/errors.md`

### File Locations
- Reference implementation: `/home/benjamin/.config/nvim/.claude/commands/task.md` (lines 208-213)
- Gap file 1: `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` (Stage 6, lines ~1361-1365)
- Gap file 2: `/home/benjamin/.config/nvim/.claude/skills/skill-spawn/SKILL.md` (after Stage 14, ~line 422)
- Gap file 3: `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` (after Step 9.2, ~line 484)
- Gap file 4: `/home/benjamin/.config/nvim/.claude/commands/errors.md` (after Step 4, ~line 129)
- Policy file: `/home/benjamin/.config/nvim/.claude/rules/state-management.md` (lines 101-111)
- Script: `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`
