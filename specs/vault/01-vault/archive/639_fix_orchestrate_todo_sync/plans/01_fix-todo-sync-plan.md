# Implementation Plan: Fix /orchestrate TODO.md status sync and artifact linking

- **Task**: 639 - Fix /orchestrate TODO.md status sync and artifact linking
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/639_fix_orchestrate_todo_sync/reports/01_todo-sync-analysis.md
- **Artifacts**: plans/01_fix-todo-sync-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/orchestrate` skill (`SKILL.md`) references three bash functions (`skill_preflight_update`, `skill_postflight_update`, `skill_link_artifact_from_handoff`) as if they are available in the agent's execution environment. However, the executing agent reads SKILL.md as markdown guidance and never sources `skill-base.sh`, so all function calls are silently dropped. This causes TODO.md status updates and artifact links to be skipped during orchestration. The fix replaces all 16 function references with equivalent standalone bash commands that the agent can run directly via the Bash tool.

### Research Integration

The research report (01_todo-sync-analysis.md) provides:
- Complete inventory of all 16 function reference locations with exact line numbers
- Function signatures and their equivalent standalone script invocations
- The full inline replacement logic for `skill_link_artifact_from_handoff` including the jq two-step pattern and Issue #1132 safety
- Risk analysis for surgical edits in a 1129-line file

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task (meta/agent-system infrastructure fix).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace all 8 `skill_preflight_update` calls with direct `bash .claude/scripts/update-task-status.sh preflight ...` invocations
- Replace all 6 `skill_postflight_update` calls with direct `bash .claude/scripts/update-task-status.sh postflight ...` invocations
- Replace both `skill_link_artifact_from_handoff` calls with inlined artifact type mapping, state.json update, and `link-artifact-todo.sh` invocation
- Ensure all replacements preserve the original variable names and session ID formats (single-task vs multi-task)
- Verify no function references remain after all edits

**Non-Goals**:
- Refactoring SKILL.md beyond the function call replacements
- Adding `source skill-base.sh` as an alternative fix approach
- Changing the logic or behavior of the status sync (only the invocation mechanism changes)
- Modifying `update-task-status.sh` or `link-artifact-todo.sh` scripts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit `old_string` not unique in 1129-line file | M | M | Include surrounding context lines to ensure uniqueness; verify each edit |
| Multi-task session ID format differs from single-task | H | L | Research report documents the distinction: `$session_id` vs `${session_id}_${task_num}` -- preserve exactly |
| Inlined artifact linking logic has jq Issue #1132 exposure | H | L | Use `select(.type == $atype \| not)` pattern per research report |
| Partial edit leaves file in inconsistent state | M | L | Apply edits in logical groups; verify after each phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |
| 3    | 3      | 2          |

Phases are sequential because all edits target the same file and line numbers shift after each phase.

---

### Phase 1: Replace preflight and postflight function calls [COMPLETED]

**Goal**: Replace all 14 `skill_preflight_update` and `skill_postflight_update` calls with direct script invocations.

**Tasks**:
- [ ] Replace `skill_preflight_update "$task_number" "research" "$session_id"` at line ~202 with `bash .claude/scripts/update-task-status.sh preflight "$task_number" "research" "$session_id"`
- [ ] Replace `skill_preflight_update "$task_number" "plan" "$session_id"` at line ~231 with `bash .claude/scripts/update-task-status.sh preflight "$task_number" "plan" "$session_id"`
- [ ] Replace `skill_preflight_update "$task_number" "implement" "$session_id"` at line ~261 with `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- [ ] Replace `skill_preflight_update "$task_number" "implement" "$session_id"` at line ~294 (partial/continuation) with `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- [ ] Replace `skill_preflight_update "$task_number" "implement" "$session_id"` at line ~559 (blocker escalation) with `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- [ ] Replace `skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"` at line ~391 with `bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"`
- [ ] Replace `skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"` at line ~394 with `bash .claude/scripts/update-task-status.sh postflight "$task_number" "plan" "$session_id"`
- [ ] Replace `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"` at line ~397 with `bash .claude/scripts/update-task-status.sh postflight "$task_number" "implement" "$session_id"`
- [ ] Replace multi-task preflight at line ~917 (research): `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"` with `bash .claude/scripts/update-task-status.sh preflight "$task_num" "research" "${session_id}_${task_num}"`
- [ ] Replace multi-task preflight at line ~942 (plan): `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"` with `bash .claude/scripts/update-task-status.sh preflight "$task_num" "plan" "${session_id}_${task_num}"`
- [ ] Replace multi-task preflight at line ~973 (implement): `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"` with `bash .claude/scripts/update-task-status.sh preflight "$task_num" "implement" "${session_id}_${task_num}"`
- [ ] Replace multi-task postflight at line ~1001 (research): `skill_postflight_update "$task_num" "research" "${session_id}_${task_num}" "$dispatch_status"` with `bash .claude/scripts/update-task-status.sh postflight "$task_num" "research" "${session_id}_${task_num}"`
- [ ] Replace multi-task postflight at line ~1005 (plan): `skill_postflight_update "$task_num" "plan" "${session_id}_${task_num}" "$dispatch_status"` with `bash .claude/scripts/update-task-status.sh postflight "$task_num" "plan" "${session_id}_${task_num}"`
- [ ] Replace multi-task postflight at line ~1009 (implement): `skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"` with `bash .claude/scripts/update-task-status.sh postflight "$task_num" "implement" "${session_id}_${task_num}"`
- [ ] Verify: `grep -c 'skill_preflight_update\|skill_postflight_update' SKILL.md` returns 0

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace 14 function call references

**Verification**:
- `grep 'skill_preflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns no matches
- `grep 'skill_postflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns no matches
- `grep 'update-task-status.sh' .claude/skills/skill-orchestrate/SKILL.md` returns 14 matches

---

### Phase 2: Replace artifact linking function calls [COMPLETED]

**Goal**: Replace both `skill_link_artifact_from_handoff` calls with inlined logic that extracts artifact metadata from handoff JSON, updates state.json, and calls `link-artifact-todo.sh`.

**Tasks**:
- [ ] Replace single-task `skill_link_artifact_from_handoff "$task_number" "$handoff"` at line ~405 with inlined block:
  - Extract `artifacts[0].{path,type,summary}` from `$handoff` via jq
  - Map artifact type to `field_name`/`next_field` (report->Research/Plan, plan->Plan/Description, summary->Summary/Description)
  - Two-step jq update of state.json artifacts array using `select(.type == $atype | not)` pattern
  - Call `bash .claude/scripts/link-artifact-todo.sh "$task_number" "$_field_name" "$_next_field" "$_handoff_artifact_path"`
- [ ] Replace multi-task `skill_link_artifact_from_handoff "$task_num" "$handoff"` at line ~1018 with equivalent inlined block using `$task_num` instead of `$task_number`
- [ ] Verify: `grep -c 'skill_link_artifact_from_handoff' SKILL.md` returns 0

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace 2 artifact linking calls with inlined multi-line logic

**Verification**:
- `grep 'skill_link_artifact_from_handoff' .claude/skills/skill-orchestrate/SKILL.md` returns no matches
- `grep 'link-artifact-todo.sh' .claude/skills/skill-orchestrate/SKILL.md` returns 2 matches
- Inlined blocks include `mkdir -p specs/tmp` guard
- Inlined blocks use `select(.type == $atype | not)` jq pattern (Issue #1132 safe)

---

### Phase 3: Final verification and smoke test [COMPLETED]

**Goal**: Confirm all function references are eliminated and the file is syntactically consistent.

**Tasks**:
- [ ] Run comprehensive grep for any remaining function references: `grep -n 'skill_preflight_update\|skill_postflight_update\|skill_link_artifact_from_handoff\|skill_link_artifacts' .claude/skills/skill-orchestrate/SKILL.md`
- [ ] Verify replacement command counts: `grep -c 'update-task-status.sh' .claude/skills/skill-orchestrate/SKILL.md` should be 14, `grep -c 'link-artifact-todo.sh' .claude/skills/skill-orchestrate/SKILL.md` should be 2
- [ ] Spot-check that `$task_number` is used in single-task sections and `$task_num` in multi-task sections
- [ ] Verify the file is valid markdown (no unclosed code blocks): `grep -c '```' .claude/skills/skill-orchestrate/SKILL.md` should return an even number

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- Zero matches for old function names
- Correct counts for new script invocations (14 + 2 = 16 total replacement sites)
- Even number of code fence markers

## Testing & Validation

- [ ] `grep -c 'skill_preflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns 0
- [ ] `grep -c 'skill_postflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns 0
- [ ] `grep -c 'skill_link_artifact_from_handoff' .claude/skills/skill-orchestrate/SKILL.md` returns 0
- [ ] `grep -c 'update-task-status.sh' .claude/skills/skill-orchestrate/SKILL.md` returns 14
- [ ] `grep -c 'link-artifact-todo.sh' .claude/skills/skill-orchestrate/SKILL.md` returns 2
- [ ] No unclosed code fences in SKILL.md
- [ ] Single-task sections use `$task_number` and `$session_id`; multi-task sections use `$task_num` and `${session_id}_${task_num}`

## Artifacts & Outputs

- `specs/639_fix_orchestrate_todo_sync/plans/01_fix-todo-sync-plan.md` (this file)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified file)

## Rollback/Contingency

The single modified file (`.claude/skills/skill-orchestrate/SKILL.md`) is tracked by git. If implementation introduces regressions, revert with `git checkout HEAD -- .claude/skills/skill-orchestrate/SKILL.md`.
