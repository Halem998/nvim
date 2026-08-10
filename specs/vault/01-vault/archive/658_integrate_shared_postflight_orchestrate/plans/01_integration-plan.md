# Implementation Plan: Task #658

- **Task**: 658 - Integrate shared postflight into skill-orchestrate
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 657 (orchestrator-postflight.sh -- COMPLETE)
- **Research Inputs**: specs/658_integrate_shared_postflight_orchestrate/reports/01_integration-research.md
- **Artifacts**: plans/01_integration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace skill-orchestrate's inline `skill_postflight_update` and `skill_link_artifacts` calls with calls to the shared `orchestrator-postflight.sh` script. This fixes a bug where research and plan dispatches (which use `orchestrator_mode: false`) never receive postflight processing because the current code depends on `.orchestrator-handoff.json`, which is only written when `orchestrator_mode: true`. The fix applies to both single-task (Stage 5) and multi-task (Stage MT-4) modes, and includes a `.return-meta.json` fallback for `dispatch_status` inference when the orchestrator handoff is absent.

### Research Integration

Key findings from `01_integration-research.md`:
- Current Stage 5 postflight (lines 385-426) is dead code for research/plan dispatches because `.orchestrator-handoff.json` is never written when `orchestrator_mode: false`
- `.return-meta.json` is written by ALL agents regardless of `orchestrator_mode` and should be used as the data source for postflight
- `orchestrator-postflight.sh` accepts 5-6 positional args: `TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]`
- For implement dispatches, skill-implementer already calls `orchestrator-postflight.sh` internally, so the orchestrator's call will be a no-op (`.return-meta.json` already deleted)
- Three architecture docs need updates: `orchestrate-state-machine.md`, `handoff-schema.md`, `dispatch-agent-spec.md`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific roadmap items are directly advanced by this task. The task contributes to agent system quality by fixing broken postflight processing.

## Goals & Non-Goals

**Goals**:
- Replace inline `skill_postflight_update` / `skill_link_artifacts` calls in Stage 5 with `orchestrator-postflight.sh`
- Replace identical inline calls in Stage MT-4 with `orchestrator-postflight.sh`
- Add `.return-meta.json` fallback for `dispatch_status` inference when `.orchestrator-handoff.json` is absent
- Update architecture documentation to reflect the unified postflight path

**Non-Goals**:
- Removing `skill_postflight_update` / `skill_link_artifacts` from `skill-base.sh` (other skills may still use them)
- Merging `.orchestrator-handoff.json` and `.return-meta.json` (they serve different purposes)
- Modifying `orchestrator-postflight.sh` itself (already functional per task 657)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `.return-meta.json` already deleted by skill-implementer when orchestrator calls postflight for implement | L | H | `orchestrator-postflight.sh` handles missing metadata gracefully (status=failed, cleanup-only); this is expected no-op behavior |
| `PROJECT_NAME` extraction in MT-4 requires parsing from task_dirs associative array | M | L | Research confirmed the pattern `${task_dirs[$task_num]}` and project_name extraction via state.json is already done in MT-2 |
| Handoff file absent for research/plan dispatches breaks current dispatch_status detection | H | H | Add `.return-meta.json` fallback to infer dispatch_status when handoff is missing (core bug fix) |
| `orchestrator-postflight.sh` Stage 9 git commit conflicts with orchestrator's own git state | L | L | Commits are non-blocking (`|| true`); sequential execution within loop prevents conflicts |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace Stage 5 Postflight (Single-Task Mode) [COMPLETED]

**Goal**: Replace the inline `skill_postflight_update` and `skill_link_artifacts` calls in Stage 5 with a single `orchestrator-postflight.sh` call per dispatch_status case, and add `.return-meta.json` fallback for dispatch_status inference.

**Tasks**:
- [x] Read current SKILL.md to confirm exact line locations (tasks 659/660 may have shifted lines) *(completed)*
- [x] Add `.return-meta.json` fallback block in the `if [ ! -f "$handoff_file" ]` branch: read `dispatch_status` from `.return-meta.json` when handoff is absent, so research/plan dispatches get proper status detection *(completed)*
- [x] Replace the `skill_postflight_update` case block (lines ~385-399) and the `skill_link_artifacts` block (lines ~401-426) with a single case block that calls `bash .claude/scripts/orchestrator-postflight.sh` with the correct `OPERATION_TYPE` per `dispatch_status` *(completed)*
- [x] Ensure error handling uses `|| echo "[orchestrate] WARNING: ... postflight failed (non-blocking)"` pattern *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace Stage 5 postflight block

**Verification**:
- Stage 5 no longer references `skill_postflight_update` or `skill_link_artifacts`
- Stage 5 calls `orchestrator-postflight.sh` for researched, planned, and implemented cases
- Missing handoff file path falls through to `.return-meta.json` for dispatch_status inference
- No broken variable references (`$task_number`, `$PROJECT_NAME`, `$PADDED_NUM`, `$session_id`, `$TASK_TYPE`)

---

### Phase 2: Replace Stage MT-4 Postflight (Multi-Task Mode) [COMPLETED]

**Goal**: Replace the inline `skill_postflight_update` and `skill_link_artifacts` calls in Stage MT-4 with `orchestrator-postflight.sh` calls, parameterized per task.

**Tasks**:
- [x] Locate the per-task postflight loop in Stage MT-4 (lines ~1000-1063) *(completed)*
- [x] Add `.return-meta.json` fallback for dispatch_status inference in the MT handoff-reading block (same pattern as Phase 1, but using per-task `task_dir`) *(completed)*
- [x] Replace the `skill_postflight_update` case block and `skill_link_artifacts` block with `orchestrator-postflight.sh` calls, using per-task variables: `$task_num`, project_name from `task_dirs`, padded number, per-task session_id `${session_id}_${task_num}`, and `task_type` from `task_types` *(completed)*
- [x] Extract `mt_project_name` from `task_dirs[$task_num]` by stripping the `specs/{padded}_` prefix *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace Stage MT-4 postflight block

**Verification**:
- Stage MT-4 no longer references `skill_postflight_update` or `skill_link_artifacts`
- Stage MT-4 calls `orchestrator-postflight.sh` for each task with correct per-task parameters
- Missing handoff falls through to `.return-meta.json` before marking task as failed
- Variable extraction for `mt_project_name` and `mt_padded` is correct

---

### Phase 3: Update Architecture Documentation [COMPLETED]

**Goal**: Update three architecture docs to describe the unified postflight path via `orchestrator-postflight.sh`.

**Tasks**:
- [x] Update `.claude/docs/architecture/orchestrate-state-machine.md`: Add a "Postflight Pipeline" section after "Context Flatness Guarantee" describing the dual-file read pattern (`.orchestrator-handoff.json` for state machine decisions, `.return-meta.json` via `orchestrator-postflight.sh` for artifact postflight). Note the `.return-meta.json` fallback for dispatch_status. *(completed)*
- [x] Update `.claude/docs/architecture/handoff-schema.md`: In the `artifacts` field definition, add a note clarifying that the `artifacts` array in the handoff is now ADVISORY for state machine continuation context; authoritative artifact data for linking comes from `.return-meta.json` via the shared postflight script. *(completed)*
- [x] Update `.claude/docs/architecture/dispatch-agent-spec.md`: Add a "Postflight Integration" section noting that after each dispatch, skill-orchestrate calls `orchestrator-postflight.sh` to drive the full postflight pipeline, matching the path used by individual `/research`, `/plan`, `/implement` commands. *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/docs/architecture/orchestrate-state-machine.md` - Add postflight pipeline section
- `.claude/docs/architecture/handoff-schema.md` - Add advisory note to artifacts field
- `.claude/docs/architecture/dispatch-agent-spec.md` - Add postflight integration section

**Verification**:
- Each doc includes the new content describing `orchestrator-postflight.sh` integration
- No contradictions with existing content (dual-file coexistence is preserved)
- Writing contract in `handoff-schema.md` still correctly states handoff is written only for `orchestrator_mode: true`

---

### Phase 4: Verification and Consistency Check [COMPLETED]

**Goal**: Verify all changes are consistent and no references to the old inline pattern remain.

**Tasks**:
- [x] Grep SKILL.md for any remaining `skill_postflight_update` calls (should find zero) *(completed: zero occurrences confirmed)*
- [x] Grep SKILL.md for any remaining `skill_link_artifacts` calls (should find zero) *(completed: zero occurrences confirmed)*
- [x] Verify `orchestrator-postflight.sh` is called in both Stage 5 and Stage MT-4 *(completed: 8 total call sites confirmed)*
- [x] Verify that the `.return-meta.json` fallback correctly handles the case where both handoff AND return-meta are absent *(completed: MT-4 marks task failed and continues; Stage 5 sets dispatch_status=failed)*
- [x] Check that Stage 8 (orchestrator's own `.return-meta.json` write at end of execution) is not affected by the postflight script's cleanup of the task-level `.return-meta.json` *(completed: Stage 8 writes to orchestrator task dir, postflight cleanup targets per-task dirs — no conflict)*

**Timing**: 15 minutes

**Depends on**: 3

**Files to modify**:
- None (verification only; fix any issues found in the files modified in earlier phases)

**Verification**:
- Zero occurrences of `skill_postflight_update` in SKILL.md
- Zero occurrences of `skill_link_artifacts` in SKILL.md
- `orchestrator-postflight.sh` appears in both Stage 5 and Stage MT-4 blocks
- Stage 8 metadata write path (`${TASK_DIR}/.return-meta.json`) is distinct from task-level metadata and unaffected by postflight cleanup

## Testing & Validation

- [ ] Grep `.claude/skills/skill-orchestrate/SKILL.md` for `skill_postflight_update` returns zero matches
- [ ] Grep `.claude/skills/skill-orchestrate/SKILL.md` for `skill_link_artifacts` returns zero matches
- [ ] Grep `.claude/skills/skill-orchestrate/SKILL.md` for `orchestrator-postflight.sh` returns matches in both Stage 5 and Stage MT-4
- [ ] Verify `.return-meta.json` fallback block exists in Stage 5 handoff-reading section
- [ ] Verify `.return-meta.json` fallback block exists in Stage MT-4 handoff-reading section
- [ ] Architecture docs contain new sections describing the unified postflight path

## Artifacts & Outputs

- `specs/658_integrate_shared_postflight_orchestrate/plans/01_integration-plan.md` (this plan)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified: Stage 5, Stage MT-4)
- `.claude/docs/architecture/orchestrate-state-machine.md` (modified: new postflight section)
- `.claude/docs/architecture/handoff-schema.md` (modified: advisory note on artifacts)
- `.claude/docs/architecture/dispatch-agent-spec.md` (modified: postflight integration section)

## Rollback/Contingency

All changes are to markdown/pseudocode files (SKILL.md and architecture docs). Rollback is a simple `git checkout` of the modified files. The `orchestrator-postflight.sh` script (created by task 657) is not modified by this task, so no rollback is needed for the script itself.
