# Implementation Plan: Task #581

- **Task**: 581 - Port update-task-status.sh Phase 3 rewrite from ProofChecker
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 579 (generate-task-order.sh port), Task 580 (topic schema + state-management rules)
- **Research Inputs**: specs/581_port_status_script_phase3/reports/01_port-status-phase3.md
- **Artifacts**: plans/01_port-status-phase3.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the broken `update_todo_task_order()` function body in `.claude/scripts/update-task-status.sh` (lines 232-265) with the ProofChecker two-mode Phase 3 strategy. The current implementation searches for the old flat-list pattern (`^- \*\*${N}\*\* \[`) which never matches the wave+tree format produced by `generate-task-order.sh`, causing Phase 3 to silently no-op on all status changes. The replacement adds Mode B (full regeneration via `generate-task-order.sh --update-todo` for terminal transitions) and Mode A (in-place `sed` on tree lines using `^\s*(└─ )?${N} \[` pattern for non-terminal transitions, with fallback to Mode B when the task is not found in the tree). Phase 5 lifecycle notifications (TTS, WezTerm, OpenCode) remain untouched.

### Research Integration

The research report (`reports/01_port-status-phase3.md`) provides a complete side-by-side comparison of the current nvim-config Phase 3 and the ProofChecker Phase 3. Key findings integrated:

- Current Phase 3 uses `^- \*\*${task_number}\*\* \[` pattern (old flat-list format) -- never matches wave+tree entries
- ProofChecker Phase 3 dispatches on terminal status (COMPLETED/ABANDONED/EXPANDED) for Mode B, all other statuses for Mode A
- Mode A tree pattern `^\s*(└─ )?${task_number} \[` matches entries at any indent depth
- Mode A uses `grep -oE '\[([A-Z ]+)\]' | head -1 | tr -d '[]'` for status extraction (handles multi-word statuses like NOT STARTED)
- Mode A fallback to Mode B when task not found in tree, with `2>/dev/null` suppression on the fallback call
- Both Mode B calls are non-fatal with warning messages

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is internal infrastructure maintenance (agent system script porting).

## Goals & Non-Goals

**Goals**:
- Replace the broken Phase 3 function body with the working two-mode strategy from ProofChecker
- Enable Mode B (full regeneration) for terminal status transitions (COMPLETED, ABANDONED, EXPANDED)
- Enable Mode A (in-place sed) for non-terminal status transitions with correct tree-line pattern
- Include Mode A fallback to Mode B when task is not found in the tree
- Preserve all existing dry-run output messages for both modes

**Non-Goals**:
- Modifying any other phase (1, 2, 4, 5) in update-task-status.sh
- Changing script-level variables, configuration, or structure
- Touching Phase 5 lifecycle notifications (TTS, WezTerm tab colors, OpenCode session renaming)
- Adding new features beyond what the ProofChecker implementation provides

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 5 accidentally modified during edit | M | L | Edit only the `update_todo_task_order()` function body; verify line ranges before and after |
| `generate-task-order.sh` not executable or missing | M | L | ProofChecker implementation includes `[[ -x "$gen_script" ]]` guard with warning |
| Mode A sed replaces wrong bracket if description contains `[...]` | L | L | Pattern anchors on specific line number and exact status text |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace update_todo_task_order() Function Body [COMPLETED]

**Goal**: Replace the broken flat-list Phase 3 implementation with the ProofChecker two-mode strategy.

**Tasks**:
- [x] Read current `update_todo_task_order()` function (lines 232-265) to confirm exact boundaries *(completed)*
- [x] Replace function body with ProofChecker two-mode implementation: *(completed)*
  - Mode B dispatch block: terminal status check (COMPLETED/ABANDONED/EXPANDED), gen_script path construction, dry-run guard, non-fatal `generate-task-order.sh --update-todo` call
  - Mode A block: tree-line grep pattern `^\s*(└─ )?${task_number} \[`, status extraction via `grep -oE`, already-at-target check, dry-run guard, in-place sed replacement
  - Mode A fallback block: warning + non-fatal `generate-task-order.sh --update-todo` with `2>/dev/null`
- [x] Verify the function signature and closing brace are preserved (only the body changes) *(completed)*
- [x] Verify Phase 5 (lines ~330-370) is completely untouched after the edit *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Replace `update_todo_task_order()` body (lines 232-265)

**Verification**:
- Function opens with `update_todo_task_order() {` and closes with `}`
- Contains Mode B terminal check: `"$TODO_STATUS" == "COMPLETED" || "$TODO_STATUS" == "ABANDONED" || "$TODO_STATUS" == "EXPANDED"`
- Contains Mode A tree pattern: `^\s*(└─ )?${task_number} \[`
- Contains Mode A fallback with `2>/dev/null`
- Phase 5 block (TTS, WezTerm, OpenCode) is byte-identical to before

---

### Phase 2: Dry-Run Validation [COMPLETED]

**Goal**: Verify the ported function works correctly via dry-run execution without modifying any actual files.

**Tasks**:
- [x] Run `bash -n .claude/scripts/update-task-status.sh` to verify syntax (no parse errors) *(completed)*
- [x] Run a dry-run test to confirm Mode B output: `update-task-status.sh postflight <test_task> implement <session> --dry-run` (should print terminal status Mode B message) *(completed)*
- [x] Run a dry-run test to confirm Mode A output for a non-terminal transition (should print line number and status transition) *(completed: task not in tree triggers fallback message as expected)*
- [x] Verify the complete script still functions by checking that all functions are defined (grep for function signatures) *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- None (read-only validation)

**Verification**:
- `bash -n` exits 0 (no syntax errors)
- Dry-run output contains `[dry-run] TODO.md Task Order:` messages for both modes
- All existing function signatures still present in the script

## Testing & Validation

- [ ] `bash -n .claude/scripts/update-task-status.sh` passes (no syntax errors)
- [ ] Dry-run with terminal status shows Mode B message
- [ ] Dry-run with non-terminal status shows Mode A message (if task exists in tree) or fallback message (if not)
- [ ] Phase 5 lifecycle notifications code is unchanged (TTS, WezTerm, OpenCode)
- [ ] Script-level configuration variables are unchanged

## Artifacts & Outputs

- `specs/581_port_status_script_phase3/plans/01_port-status-phase3.md` (this plan)
- `specs/581_port_status_script_phase3/summaries/01_port-status-phase3-summary.md` (after implementation)
- `.claude/scripts/update-task-status.sh` (modified file)

## Rollback/Contingency

The change is confined to a single function body (~33 lines replaced with ~69 lines). To revert:
- `git checkout -- .claude/scripts/update-task-status.sh` restores the previous version
- The old flat-list pattern was already broken (silently no-ops), so reverting returns to the same broken state rather than introducing a regression
