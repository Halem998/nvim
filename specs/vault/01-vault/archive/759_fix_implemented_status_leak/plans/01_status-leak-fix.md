# Implementation Plan: Fix "implemented" Status Leak

- **Task**: 759 - Fix "implemented" status leak into state.json
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/759_fix_implemented_status_leak/reports/01_status-leak-fix.md
- **Artifacts**: plans/01_status-leak-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The agent return value `"implemented"` from `.return-meta.json` leaks into state.json as a raw status instead of being normalized to `"completed"`. The root cause is scattered: documentation in skill-status-sync maps `implemented -> [IMPLEMENTED]` as valid, skill-orchestrate writes `"implemented"` in its metadata for both clean and partial exits, generate-todo.sh has no defensive case for `"implemented"`, and command-gate-out.sh only matches `"implemented"` (not `"completed"`) in its defensive correction guard. Six files need coordinated edits across primary and extension mirrors.

### Research Integration

Research report `01_status-leak-fix.md` identified 6 fix sites across 4 logical changes: skill-status-sync documentation table (x2 mirrors), skill-orchestrate Stage 8 metadata write (x2 mirrors), generate-todo.sh format_status function (x1), and command-gate-out.sh trigger condition (x1). The report confirmed that skill-base.sh, orchestrator-postflight.sh, and update-task-status.sh are NOT bug sites -- they correctly translate `"implemented"` to `"completed"` via the postflight pipeline.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Prevent `"implemented"` from appearing in state.json as a lifecycle status
- Ensure generate-todo.sh produces `[COMPLETED]` even if `"implemented"` reaches state.json
- Make skill-orchestrate emit semantically correct status values (`"completed"` vs `"partial"`)
- Keep command-gate-out.sh defensive correction working after skill-orchestrate fix
- Keep primary and extension mirrors in sync

**Non-Goals**:
- Refactoring the two-layer status model (agent return status vs lifecycle status)
- Changing the `.return-meta.json` schema (it intentionally uses `"implemented"` as a signal)
- Modifying skill-base.sh or orchestrator-postflight.sh (these correctly translate already)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| command-gate-out.sh stops matching after skill-orchestrate writes "completed" instead of "implemented" | M | H | Fix site 4 adds "completed" to the match condition (coordinated change) |
| Extension mirrors drift from primary if not updated atomically | L | M | Fix both mirrors in same commit |
| generate-todo.sh defensive case masks future state.json corruption | L | L | Intentional defense-in-depth; primary fixes prevent "implemented" from reaching state.json |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix All Status Leak Sites [COMPLETED]

**Goal**: Eliminate all paths where `"implemented"` can leak into state.json or TODO.md as a lifecycle status.

**Tasks**:
- [x] **Fix 1a**: Edit `.claude/skills/skill-status-sync/SKILL.md` line 164 -- replace `implemented | [IMPLEMENTED]` with `completed  | [COMPLETED]` in the Status Mapping table *(completed)*
- [x] **Fix 1b**: Edit `.claude/extensions/core/skills/skill-status-sync/SKILL.md` line 164 -- same change as 1a (extension mirror) *(completed)*
- [x] **Fix 2**: Edit `.claude/scripts/generate-todo.sh` -- add `implemented) printf '%s' "COMPLETED" ;;` case between line 128 (`expanded`) and line 129 (`pr_ready`) in the `format_status` function *(completed)*
- [x] **Fix 3a**: Edit `.claude/skills/skill-orchestrate/SKILL.md` lines 698-712 -- replace the single shared metadata write block with two blocks: one for clean exit using `--arg status "completed"` and one for partial exit using `--arg status "partial"`. Restructure as: *(completed)*

```
Write metadata file.

On clean exit:

\`\`\`bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "completed" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
\`\`\`

On partial exit:

\`\`\`bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "partial" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
\`\`\`
```

- [x] **Fix 3b**: Edit `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` lines 620-635 -- same restructuring as 3a (extension mirror) *(completed)*
- [x] **Fix 4**: Edit `.claude/scripts/command-gate-out.sh` lines 64-65 -- add `[ "$skill_status" = "completed" ]` to the match condition, changing: *(completed)*

Old (line 64-65):
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

New:
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "completed" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-status-sync/SKILL.md` (line 164) - fix status mapping table
- `.claude/extensions/core/skills/skill-status-sync/SKILL.md` (line 164) - extension mirror
- `.claude/scripts/generate-todo.sh` (line ~128) - add defensive case
- `.claude/skills/skill-orchestrate/SKILL.md` (lines 698-712) - split metadata write into clean/partial
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 620-635) - extension mirror
- `.claude/scripts/command-gate-out.sh` (lines 64-65) - add "completed" to match condition

**Verification**:
- `grep -n "implemented" .claude/skills/skill-status-sync/SKILL.md` returns no matches in the Status Mapping table
- `grep -n "implemented" .claude/extensions/core/skills/skill-status-sync/SKILL.md` returns no matches in the Status Mapping table
- `grep -c 'implemented.*COMPLETED' .claude/scripts/generate-todo.sh` returns 1 (the new defensive case)
- `grep -c '"implemented"' .claude/skills/skill-orchestrate/SKILL.md` returns 0 (no more "implemented" in metadata writes)
- `grep -c '"implemented"' .claude/extensions/core/skills/skill-orchestrate/SKILL.md` returns 0
- `grep -c '"completed"' .claude/scripts/command-gate-out.sh` returns at least 1 (the new match condition)
- Primary and extension mirror files are consistent (diff shows no unintended differences)

## Testing & Validation

- [ ] Verify no remaining `"implemented"` in skill-orchestrate metadata blocks (both primary and extension)
- [ ] Verify skill-status-sync mapping table shows `completed | [COMPLETED]` (both mirrors)
- [ ] Verify generate-todo.sh has explicit `implemented) ... "COMPLETED"` case
- [ ] Verify command-gate-out.sh matches both `"implemented"` and `"completed"` for backward compatibility
- [ ] Run `bash .claude/scripts/generate-todo.sh` to confirm it executes without error
- [ ] Grep all six modified files to confirm no stale `"implemented"` references in status-critical positions

## Artifacts & Outputs

- plans/01_status-leak-fix.md (this plan)
- summaries/01_status-leak-fix-summary.md (post-implementation)

## Rollback/Contingency

All changes are to documentation files (SKILL.md) and shell scripts. Revert via `git checkout` on the six modified files. No database or runtime state changes are involved. The generate-todo.sh defensive case is purely additive and safe to leave even if other fixes are reverted.
