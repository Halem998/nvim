# Research Report: Task #671 — PR Ready Status Lifecycle

**Task**: 671 - pr_ready_status_lifecycle
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (all referenced files read directly)
**Artifacts**: specs/671_pr_ready_status_lifecycle/reports/01_pr-ready-status.md
**Standards**: report-format.md

---

## Executive Summary

- [PR READY] does not yet exist anywhere in the codebase; it is a net-new non-terminal status.
- Six files require modification (three live copies + three extension/source copies), plus the state-management-schema.md reference file (both copies).
- The key constraint is that `update-task-status.sh` uses a fixed 3-value `target_status` enum (`research | plan | implement`); adding `pr_ready` requires a new branch in this script without changing how existing statuses work.
- `generate-todo.sh` and `generate-task-order.sh` use a `format_status()` function (wildcard `*)` catch-all); `pr_ready` will render as `PR_READY` by the catch-all, so an explicit case is needed for proper rendering as `PR READY`.
- The orchestrate/orchestrate-hard skills treat `completed` as a terminal state and all others as non-terminal; since `pr_ready` is non-terminal, the state machines need to recognise it as an "in-flight" state analogous to `implementing` (re-dispatch to implement) rather than treating it as unknown.

---

## Context & Scope

Task 671 adds `[PR READY]` as a gating status between `[IMPLEMENTING]` and the `/merge` (PR submission) step. The new status is:

- **State.json value**: `pr_ready`
- **TODO.md marker**: `[PR READY]`
- **Non-terminal**: transitions back to `[IMPLEMENTING]` if issues are found
- **Forward transition**: `[PR READY]` -> `[COMPLETED]` after `/merge`/`/pr` submission

This is a **meta** task; it modifies the agent system infrastructure, not application code.

---

## Findings

### Current Status Lifecycle

```
[NOT STARTED]  (not_started)
     |
     v
[RESEARCHING]  (researching)  <- preflight:research
     |
     v
[RESEARCHED]   (researched)   <- postflight:research
     |
     v
[PLANNING]     (planning)     <- preflight:plan
     |
     v
[PLANNED]      (planned)      <- postflight:plan
     |
     v
[IMPLEMENTING] (implementing) <- preflight:implement
     |
     v
[COMPLETED]    (completed)    <- postflight:implement
     |
     [BLOCKED]   (blocked)     <- any non-terminal -> blocked
     [ABANDONED] (abandoned)   <- any -> abandoned (terminal)
     [PARTIAL]   (partial)     <- implementing -> partial (on timeout)
     [EXPANDED]  (expanded)    <- any non-terminal -> expanded (terminal)
```

**Terminal states**: `completed`, `abandoned`, `expanded`
**Non-terminal exception states**: `blocked`, `partial`

### Proposed Addition

```
[IMPLEMENTING] (implementing) <- preflight:implement
     |
     v (postflight:implement on pr tasks, or manual set)
[PR READY]     (pr_ready)     <- NEW: gating status before /merge
     |                \
     v (after /merge)  v (if issues found)
[COMPLETED]   (completed)  [IMPLEMENTING] (re-dispatch)
```

---

## Complete File Inventory

### Files That MUST Be Modified

#### 1. `.claude/rules/state-management.md` (live copy)
**Path**: `/home/benjamin/.config/nvim/.claude/rules/state-management.md`
**Current relevant section** (lines 28-36):
```
Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]
Any non-terminal status -> any command (research, plan, implement, revise)
Any status -> [BLOCKED] (with reason)
Any status -> [ABANDONED] (moves to archive)
Any non-terminal -> [EXPANDED] (when divided into subtasks)
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
```
**Change needed**: Add `[IMPLEMENTING] -> [PR READY]` and `[PR READY] -> [IMPLEMENTING]` and `[PR READY] -> [COMPLETED]` transitions.

#### 2. `.claude/extensions/core/rules/state-management.md` (extension source)
**Path**: `/home/benjamin/.config/nvim/.claude/extensions/core/rules/state-management.md`
**Change needed**: Identical change to #1 above (files are currently identical).

#### 3. `.claude/scripts/generate-todo.sh` (live copy)
**Path**: `/home/benjamin/.config/nvim/.claude/scripts/generate-todo.sh`
**Current format_status() function** (lines 115-131):
```bash
format_status() {
  local raw="$1"
  case "$raw" in
    not_started)  printf '%s' "NOT STARTED" ;;
    researching)  printf '%s' "RESEARCHING" ;;
    researched)   printf '%s' "RESEARCHED" ;;
    planning)     printf '%s' "PLANNING" ;;
    planned)      printf '%s' "PLANNED" ;;
    implementing) printf '%s' "IMPLEMENTING" ;;
    completed)    printf '%s' "COMPLETED" ;;
    blocked)      printf '%s' "BLOCKED" ;;
    abandoned)    printf '%s' "ABANDONED" ;;
    partial)      printf '%s' "PARTIAL" ;;
    expanded)     printf '%s' "EXPANDED" ;;
    *)            printf '%s' "$(echo "$raw" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}
```
**Change needed**: Add `pr_ready) printf '%s' "PR READY" ;;` before the wildcard case. Without this explicit entry, `pr_ready` renders as `PR_READY` (with underscore) due to the `tr` catch-all.

#### 4. `.claude/extensions/core/scripts/generate-todo.sh` (extension source)
**Path**: `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/generate-todo.sh`
**Change needed**: Identical change to #3 (files are currently byte-for-byte identical per `diff`).

#### 5. `.claude/scripts/update-task-status.sh` (live copy)
**Path**: `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`
**Current validation** (lines 69-72):
```bash
if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" ]]; then
  echo "Error: target_status must be 'research', 'plan', or 'implement', got '$target_status'" >&2
  exit 1
fi
```
**Current map_status()** (lines 86-101):
```bash
map_status() {
  local op="$1"
  local target="$2"
  case "${op}:${target}" in
    preflight:research)   STATE_STATUS="researching";   TODO_STATUS="RESEARCHING" ;;
    preflight:plan)       STATE_STATUS="planning";      TODO_STATUS="PLANNING" ;;
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;
    postflight:plan)      STATE_STATUS="planned";       TODO_STATUS="PLANNED" ;;
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    *)
      echo "Error: unknown operation:target_status combination '${op}:${target}'" >&2
      exit 1
      ;;
  esac
}
```
**Change needed**:
- Add `pr_ready` to the allowed values in the validation block.
- Add two new `map_status` cases:
  - `preflight:pr_ready` -> `STATE_STATUS="pr_ready"` / `TODO_STATUS="PR READY"` (transitioning into PR READY from IMPLEMENTING)
  - `postflight:pr_ready` -> `STATE_STATUS="completed"` / `TODO_STATUS="COMPLETED"` (transitioning from PR READY to COMPLETED after merge)

  **Design note**: The `pr_ready` status is a gate, not an active-work state. The convention would be:
  - A manual `bash update-task-status.sh postflight implement` on a PR task should instead do `bash update-task-status.sh preflight pr_ready` (set to pr_ready instead of completed).
  - Then `bash update-task-status.sh postflight pr_ready` moves to completed.

  This means we need `preflight:pr_ready` for "entering PR READY state" and `postflight:pr_ready` for "PR submitted, now complete."

#### 6. `.claude/extensions/core/scripts/update-task-status.sh` (extension source)
**Path**: `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/update-task-status.sh`
**Change needed**: Identical changes to #5 (files are currently byte-for-byte identical per `diff`).

#### 7. `.claude/extensions/core/merge-sources/claudemd.md` (CLAUDE.md merge-source)
**Path**: `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`
**Current Status Markers section** (lines 32-37):
```markdown
### Status Markers
- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` -> `[RESEARCHED]` - Research phase
- `[PLANNING]` -> `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` -> `[COMPLETED]` - Implementation phase
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states
```
**Change needed**: Modify the Implementation phase line and add PR READY:
```markdown
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - Implementation + PR phase
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states
- `[PR READY]` -> `[IMPLEMENTING]` - If PR review finds issues
```

**Note**: The live `.claude/CLAUDE.md` is auto-generated from merge-sources; it must NOT be edited directly.

#### 8. `.claude/context/reference/state-management-schema.md` (live reference)
**Path**: `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`
**Current Status Values Mapping table** (lines 267-280):
```markdown
| TODO.md Marker | state.json status |
|----------------|-------------------|
| [NOT STARTED] | not_started |
| [RESEARCHING] | researching |
| [RESEARCHED] | researched |
| [PLANNING] | planning |
| [PLANNED] | planned |
| [IMPLEMENTING] | implementing |
| [COMPLETED] | completed |
| [BLOCKED] | blocked |
| [ABANDONED] | abandoned |
| [PARTIAL] | partial |
| [EXPANDED] | expanded |
```
**Change needed**: Add `| [PR READY] | pr_ready |` row (before or after `[IMPLEMENTING]`).

#### 9. `.claude/extensions/core/context/reference/state-management-schema.md` (extension copy)
**Path**: `/home/benjamin/.config/nvim/.claude/extensions/core/context/reference/state-management-schema.md`
**Change needed**: Same row addition. (Extension copy differs from live on some sections but the Status Values Mapping table is present in both.)

### Files That MAY Need Consideration (No Direct Change Required)

#### `generate-task-order.sh` (live + extension copies)
Both copies contain an identical `format_status()` function (line 606-621 in live copy) using the same case structure as `generate-todo.sh`. **This DOES need the same `pr_ready) echo "PR READY" ;;` addition** to render correctly in the Task Order section.

Files:
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (line 606-621)
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/generate-task-order.sh`

#### `skill-orchestrate/SKILL.md`
The state machine at line 863-892 handles statuses:
```bash
not_started|"not started") -> research
researched)                -> plan
planned|implementing)      -> implement
partial)                   -> blocker/resume logic
blocked|researching|planning) -> wait/exit
```
`pr_ready` falls through to none of these cases. The orchestrator should treat `pr_ready` as: task is done with implementation work, awaiting manual PR submission. Best behavior: **exit cleanly with status "pr_ready"** (like completed, but non-terminal message). No auto-dispatch for PR submission — that's a human action.

The orchestrate skill description says "10-state task lifecycle state machine" — adding `pr_ready` makes it 11 states. A case for `pr_ready` should be added to exit cleanly:
```bash
pr_ready)
  echo "[orchestrate] Task $task_number is PR READY — awaiting /merge submission."
  EXIT (ok, pr_ready)
```

#### `skill-orchestrate-hard/SKILL.md`
Same consideration as above — needs a `pr_ready` state case added.

#### `skill-implementer/SKILL.md`
Lines 381 and 424 reference that `postflight:implement` maps to "completed." For PR tasks, the implementer postflight should instead set `pr_ready`. However, the task description says this is a **gating status** that the user explicitly invokes (not automatic). The implementer skill itself probably doesn't need changes — the user would manually call the status update.

#### `skill-status-sync/SKILL.md`
The preflight Status Mapping table (line 108-114) lists `implementing` but not `pr_ready`. The postflight Status Mapping table (line 160-165) lists `implemented` (not `completed`). This file needs `pr_ready` added to both tables if it's to be used for manual status corrections.

---

## File Change Summary

| Priority | File | Location | Change Type |
|----------|------|----------|-------------|
| HIGH | `.claude/rules/state-management.md` | transitions block | Add PR READY transitions |
| HIGH | `.claude/extensions/core/rules/state-management.md` | transitions block | Same |
| HIGH | `.claude/scripts/generate-todo.sh` | format_status() | Add pr_ready case |
| HIGH | `.claude/extensions/core/scripts/generate-todo.sh` | format_status() | Same |
| HIGH | `.claude/scripts/generate-task-order.sh` | format_status() | Add pr_ready case |
| HIGH | `.claude/extensions/core/scripts/generate-task-order.sh` | format_status() | Same |
| HIGH | `.claude/scripts/update-task-status.sh` | validation + map_status() | Add pr_ready |
| HIGH | `.claude/extensions/core/scripts/update-task-status.sh` | validation + map_status() | Same |
| HIGH | `.claude/extensions/core/merge-sources/claudemd.md` | Status Markers section | Add PR READY |
| HIGH | `.claude/context/reference/state-management-schema.md` | Status Values table | Add PR READY row |
| MEDIUM | `.claude/extensions/core/context/reference/state-management-schema.md` | Status Values table | Add PR READY row |
| MEDIUM | `.claude/skills/skill-orchestrate/SKILL.md` | state machine case | Add pr_ready exit case |
| MEDIUM | `.claude/skills/skill-orchestrate-hard/SKILL.md` | state machine | Add pr_ready exit case |
| LOW | `.claude/skills/skill-status-sync/SKILL.md` | Status Mapping tables | Add pr_ready entries |

**Total files**: 14 (10 HIGH priority, plus 4 MEDIUM/LOW)

---

## Proposed Changes in Detail

### Change 1: state-management.md (both copies)

In the "Permissive Model" transitions block, change:
```
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
```
to:
```
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
[IMPLEMENTING] -> [PR READY] (implementation complete, awaiting PR submission)
[PR READY] -> [IMPLEMENTING] (if issues found during PR review)
[PR READY] -> [COMPLETED] (after /merge PR submission)
```

### Change 2: generate-todo.sh format_status() (both copies)

Add before the wildcard `*)` case:
```bash
pr_ready)     printf '%s' "PR READY" ;;
```

### Change 3: generate-task-order.sh format_status() (both copies)

Same addition as Change 2, but in `generate-task-order.sh` which has its own independent `format_status()` function.

### Change 4: update-task-status.sh validation (both copies)

Change validation block from:
```bash
if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" ]]; then
  echo "Error: target_status must be 'research', 'plan', or 'implement', got '$target_status'" >&2
  exit 1
fi
```
To:
```bash
if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" && "$target_status" != "pr_ready" ]]; then
  echo "Error: target_status must be 'research', 'plan', 'implement', or 'pr_ready', got '$target_status'" >&2
  exit 1
fi
```

**Note**: Because of jq Issue #1132, the `&&` chained `!=` pattern is safe here (this is Bash, not jq). Only jq `!=` is problematic.

### Change 5: update-task-status.sh map_status() (both copies)

Add two cases to the `case "${op}:${target}" in` block:
```bash
preflight:pr_ready)  STATE_STATUS="pr_ready";  TODO_STATUS="PR READY" ;;
postflight:pr_ready) STATE_STATUS="completed";  TODO_STATUS="COMPLETED" ;;
```

**Semantic explanation**:
- `preflight:pr_ready` — Called when implementation is done and task transitions to PR READY state (entering the gate)
- `postflight:pr_ready` — Called after `/merge` succeeds; PR READY -> COMPLETED

### Change 6: claudemd.md merge-source Status Markers

Change:
```markdown
- `[IMPLEMENTING]` -> `[COMPLETED]` - Implementation phase
```
To:
```markdown
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - Implementation + PR phase
- `[PR READY]` -> `[IMPLEMENTING]` - If PR review finds issues (re-dispatch)
```

### Change 7: state-management-schema.md Status Values table (both copies)

Add after the `[IMPLEMENTING]` row:
```markdown
| [PR READY] | pr_ready |
```

### Change 8: skill-orchestrate/SKILL.md state machine

In the large `case "$status" in` block (around line 863), add:
```bash
pr_ready)
  echo "[orchestrate] Task $task_number is PR READY — use /merge to submit the pull request."
  EXIT (ok)
  ;;
```
This exits cleanly with a human-action prompt rather than trying to auto-dispatch.

---

## Edge Cases and Concerns

### 1. update-task-status.sh: postflight:implement Still Goes to COMPLETED

The current `postflight:implement` case maps to `completed`. For tasks that use `pr_ready`, a workflow would need to:
1. Use `preflight:pr_ready` to set the gate after implementation work is done (instead of `postflight:implement`).
2. Or use `postflight:implement` -> `implementing -> completed` path for non-PR tasks (unchanged).

This means the implementer skill itself does NOT automatically route through `pr_ready`. The transition to `pr_ready` is either:
- Manual: user runs `bash update-task-status.sh preflight pr_ready N session`
- Skill-driven: implementer skill can detect PR task type and call `preflight:pr_ready` instead of `postflight:implement`

The task description says to add the status as a "gating status"; the implementer skill change is optional scope and should be tracked separately.

### 2. Orchestrator State Machine Coverage

The orchestrate skill's state machine has 10 named states. `pr_ready` is not handled. If a task enters `pr_ready` while orchestrate is running, the state machine will fall through to the unhandled case (currently exits as partial with warning). An explicit `pr_ready` case should be added so orchestrate exits cleanly with a message.

### 3. CLAUDE.md is Auto-Generated

The live `/home/benjamin/.config/nvim/.claude/CLAUDE.md` is auto-generated from merge-sources and must NOT be edited directly. Only `extensions/core/merge-sources/claudemd.md` needs to be modified; the live CLAUDE.md will be regenerated by the install-extension.sh process.

### 4. TODO.md Rendering for PR READY

The `pr_ready` value contains an underscore. Without the explicit `format_status()` case, `tr '[:lower:]' '[:upper:]'` would produce `PR_READY` instead of `PR READY`. Both `generate-todo.sh` and `generate-task-order.sh` have independent `format_status()` functions that both need the explicit case.

### 5. generate-task-order.sh: Active Task Filtering

The `get_active_tasks()` function in `generate-task-order.sh` filters out `completed`, `abandoned`, and `expanded` tasks. Tasks with `pr_ready` status will correctly appear in the Task Order section (they are non-terminal). No change needed to filtering logic.

### 6. State Machine Completeness in skill-orchestrate-hard

The hard orchestrate skill (lines 264 and 320) handles `planned|implementing` together. `pr_ready` tasks in the hard state machine would be unhandled. Same exit-cleanly case needed.

---

## Decisions

1. `pr_ready` is the canonical state.json value (underscore, lowercase), `PR READY` is the TODO.md display (space, uppercase).
2. `[PR READY]` is non-terminal — the state machine and terminal-state checks must NOT include it.
3. Transition to `pr_ready` is via `preflight:pr_ready` in update-task-status.sh.
4. Transition from `pr_ready` to `completed` is via `postflight:pr_ready`.
5. The implementer skill does NOT automatically route through `pr_ready` — this is a separate concern for a future task.
6. The orchestrate skill should exit cleanly (not as error) when encountering `pr_ready`.

---

## Context Extension Recommendations

- **Topic**: PR lifecycle integration with task status
- **Gap**: No documented pattern for how tasks transition from implementation to PR submission in the agent system
- **Recommendation**: After implementation, add a brief guide in `.claude/context/patterns/pr-lifecycle.md` explaining the [PR READY] gate and how to manually invoke the status transitions

---

## Appendix

### Search Queries Used
- `grep -rn "format_status" .claude/scripts/`
- `grep -rn "Status Markers" .claude/extensions/core/merge-sources/`
- `grep -rn "pr_ready|PR READY" .claude/`
- `diff scripts/generate-todo.sh extensions/core/scripts/generate-todo.sh`
- `diff scripts/update-task-status.sh extensions/core/scripts/update-task-status.sh`

### Key File Line References
- `generate-todo.sh` format_status(): lines 115-131 (live), same in extension
- `generate-task-order.sh` format_status(): lines 606-621 (live), same in extension
- `update-task-status.sh` validation: lines 69-72; map_status(): lines 86-101 (live), same in extension
- `state-management-schema.md` Status Values table: lines 267-280 (live)
- `claudemd.md` Status Markers: lines 32-37 (extension merge-source)
- `skill-orchestrate/SKILL.md` state machine: lines 863-892
