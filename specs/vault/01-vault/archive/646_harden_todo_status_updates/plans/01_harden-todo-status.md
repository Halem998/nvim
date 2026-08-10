# Implementation Plan: Task #646

- **Task**: 646 - Harden TODO.md Status Updates
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/646_harden_todo_status_updates/reports/01_harden-todo-status.md
- **Artifacts**: plans/01_harden-todo-status.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the two-step sed extraction+replacement patterns in `update-task-status.sh` (PHASE 2: `update_todo_task_entry` and PHASE 3 Mode A: `update_todo_task_order`) with awk single-pass replacements that co-locate search and replace, eliminate silent no-op failures when status extraction yields an empty string, and return non-zero exit codes on genuine failure rather than silently succeeding.

### Research Integration

The research report identified five failure modes (A-E) in the current sed-based approach. The core issue is that extracting `current_status` as a separate step and then using it as a sed match target creates a fragile two-step pipeline: if extraction fails, the sed replacement silently does nothing and exits 0. The awk approach eliminates this by performing the find-and-replace in a single pass using `sub(/\[[A-Z ]+\]/, "[NEW_STATUS]")`, with `exit (count == 0)` for proper failure detection.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace PHASE 2 sed extraction+replacement with awk single-pass in `update_todo_task_entry`
- Replace PHASE 3 Mode A sed extraction+replacement with awk single-pass in `update_todo_task_order`
- Ensure non-zero exit code when no status replacement is made (failure detection)
- Preserve existing dry-run behavior and idempotency semantics
- Preserve PHASE 3 Mode B (terminal status full regeneration) unchanged

**Non-Goals**:
- Fixing `update-plan-status.sh` (separate file, separate task)
- Addressing shared temp file collision (task 645 scope)
- Adding a test harness for `update-task-status.sh` (future enhancement)
- Changing PHASE 1 (state.json via jq, already robust) or PHASE 4 (plan file delegation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Awk pattern regression on existing TODO.md format | H | L | Test with current TODO.md content before and after; verify idempotent re-runs |
| Unicode `└─` character handling in awk | L | L | Awk handles UTF-8 bytes in string literals; same chars already used in grep pattern |
| Shared `$TMP_DIR/todo.md.tmp` file collision during parallel writes | M | L | Pre-existing issue; task 645 addresses separately; not introduced by this change |
| Trailing newline loss when using `echo "$var" > file` | M | L | Use `printf '%s\n' "$var"` or verify awk output preserves file structure |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace PHASE 2 (update_todo_task_entry) with awk [COMPLETED]

**Goal**: Replace the sed extraction+replacement logic in `update_todo_task_entry` (lines ~205-234) with an awk single-pass approach that finds the task heading, locates the Status line within a 10-line window, performs `sub()` replacement, and exits non-zero if no replacement was made.

**Tasks**:
- [ ] Read `update-task-status.sh` lines 187-235 to confirm current implementation matches research
- [ ] Replace the status extraction (line 219) and sed replacement (line 234) with awk single-pass block
- [ ] Preserve the heading-line lookup via `grep -n` (line 195) -- this remains useful for the early-exit guard
- [ ] Preserve dry-run checks (lines 228-231) by keeping the `current_todo_status` extraction but using awk for it
- [ ] Alternatively: restructure so that awk handles the full operation including dry-run status display
- [ ] Ensure the function returns 1 (not 0) when the awk replacement finds no match
- [ ] Preserve the atomic write pattern: awk output to `$TMP_DIR/todo.md.tmp`, then `mv` to `$TODO_FILE`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Replace lines ~205-234 in `update_todo_task_entry`

**Verification**:
- Run `update-task-status.sh` with `--dry-run` against current TODO.md for an active task; confirm dry-run output shows correct current and target status
- Run without `--dry-run` on a test task and verify TODO.md status line changed correctly
- Verify that running again (idempotent) correctly detects "already at target" and skips

---

### Phase 2: Replace PHASE 3 Mode A (update_todo_task_order) with awk [COMPLETED]

**Goal**: Replace the sed extraction+replacement logic in the Mode A (non-terminal, in-place) path of `update_todo_task_order` (lines ~291-308) with an awk single-pass approach that matches tree lines at any indent level and replaces the bracketed status.

**Tasks**:
- [ ] Read `update-task-status.sh` lines 266-309 to confirm current implementation matches research
- [ ] Replace the status extraction (line 293) and sed replacement (line 308) with awk single-pass block
- [ ] Preserve the tree-line lookup via `grep -n` (line 272) for the "not found" fallback to full regeneration
- [ ] Preserve dry-run checks (lines 302-305) by extracting current status via awk or simplified grep
- [ ] Ensure the function falls back to `generate-task-order.sh` when awk replacement finds no match (instead of silently skipping)
- [ ] Preserve the atomic write pattern: awk output to `$TMP_DIR/todo.md.tmp`, then `mv` to `$TODO_FILE`

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Replace lines ~291-308 in `update_todo_task_order`

**Verification**:
- Run `update-task-status.sh` with `--dry-run` for an active task; confirm Task Order dry-run output is correct
- Run without `--dry-run` and verify the Task Order tree line status changed
- Verify indented tree entries (with `└─` prefix) are handled correctly
- Verify that a non-existent task number triggers the fallback to `generate-task-order.sh`

---

### Phase 3: Integration Testing and Edge Cases [COMPLETED]

**Goal**: Verify both replacements work correctly together in a full status update cycle, including edge cases identified in the research.

**Tasks**:
- [ ] Run a full `update-task-status.sh` invocation (not dry-run) for an active task and verify all four phases complete successfully
- [ ] Verify the script exits 0 on success
- [ ] Test idempotent behavior: run the same status update twice and confirm the second is a no-op
- [ ] Test with a task that appears in the Task Order tree with indentation (`└─` prefix)
- [ ] Verify that `set -euo pipefail` at the top of the script interacts correctly with the new awk exit codes (non-zero awk exit should be caught by the function, not crash the script)
- [ ] Confirm PHASE 3 Mode B (terminal status) still uses `generate-task-order.sh` unchanged
- [ ] Run `--dry-run` end-to-end and verify all dry-run output messages are consistent

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (testing only)

**Verification**:
- All tests pass without error
- TODO.md and state.json remain synchronized after updates
- No regressions in existing status update behavior

## Testing & Validation

- [ ] Run `update-task-status.sh research 646 research sess_test --dry-run` and verify dry-run output for both PHASE 2 and PHASE 3
- [ ] Run actual status update on a test task and diff TODO.md before/after to confirm only the target status line changed
- [ ] Verify `set -euo pipefail` does not cause script abort when awk returns non-zero inside a function that catches the exit code
- [ ] Confirm Task Order tree lines with `└─` prefix are matched and updated correctly
- [ ] Verify the `$TMP_DIR/todo.md.tmp` intermediate file is cleaned up by the existing trap

## Artifacts & Outputs

- `.claude/scripts/update-task-status.sh` - Modified script with awk-based status replacement
- `specs/646_harden_todo_status_updates/plans/01_harden-todo-status.md` - This plan
- `specs/646_harden_todo_status_updates/summaries/01_harden-todo-status-summary.md` - Post-implementation summary

## Rollback/Contingency

The change is confined to a single file (`.claude/scripts/update-task-status.sh`). If the awk approach causes regressions:
1. `git checkout -- .claude/scripts/update-task-status.sh` restores the original sed-based implementation
2. No other files are modified, so no cascading rollback is needed
3. The original sed approach is functional for well-formed TODO.md entries; rollback loses only the hardening against edge cases
