# Implementation Plan: Task #625

- **Task**: 625 - Refactor skill-orchestrate for single-agent multi-task orchestration
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 623 (multi-task dispatch), Task 624 (postflight status sync)
- **Research Inputs**: specs/625_orchestrate_single_agent_multi_task/reports/01_orchestrate-refactor.md
- **Artifacts**: plans/01_orchestrate-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor `skill-orchestrate/SKILL.md` to support a multi-task mode where a single orchestrator agent manages all tasks instead of spawning N separate skill instances. The refactor has two independent parts: (1) fix a pre-existing bug where `skill_link_artifacts()` is never called from SKILL.md Stage 5, meaning TODO.md artifact links are missing during orchestration, and (2) add a multi-task entry path (Stage 0 detection + Stages MT-1 through MT-5) that receives all task numbers, the dependency graph, and pre-computed waves, then dispatches phase-specific agents in a wave loop with per-task postflight updates. This reduces orchestration overhead from O(N * 44k) to O(1 * 44k) tokens.

### Research Integration

Key findings from the research report:

1. `skill_link_artifacts()` is defined in `skill-base.sh` but never called from `SKILL.md` -- artifact linking in TODO.md is missing for all orchestrated tasks (single-task and multi-task).
2. The multi-task code path should extend the existing SKILL.md with a Stage 0 branch rather than creating a new skill file, keeping maintenance overhead low.
3. Tasks within the same dependency wave are independent and can proceed at different lifecycle phases simultaneously -- the orchestrator groups tasks by needed phase (research/plan/implement) and dispatches each group to the appropriate agent type in parallel.
4. A compact multi-state JSON file (`specs/.orchestrator-multi-state.json`) tracks per-task status, cycle counts, and wave progress without violating the Context Flatness Constraint.
5. `orchestrate.md` Step 4 must be updated to dispatch a single skill-orchestrate instance with all task context instead of N instances.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly targeted by this task.

## Goals & Non-Goals

**Goals**:
- Fix artifact linking gap in SKILL.md Stage 5 (single-task and multi-task)
- Add multi-task entry path to SKILL.md with wave-based phase-aware dispatch
- Update orchestrate.md multi-task dispatch to invoke one skill instance instead of N
- Maintain Context Flatness Constraint (only read handoff JSON, not full artifacts)
- Call both `skill_postflight_update()` and `skill_link_artifacts()` per task after each phase dispatch

**Non-Goals**:
- Modifying single-task state machine logic (Stages 1-8 remain unchanged except Stage 5 artifact linking fix)
- Adding new agent types or modifying existing agent definitions
- Implementing drift inspection or blocker escalation in multi-task mode (deferred to future work)
- Changing the Kahn's algorithm wave computation in orchestrate.md (it stays there, results passed to skill)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md becomes too large/complex | M | M | Keep multi-task stages in a clearly delimited section with its own header |
| Parallel Agent calls hit tool concurrency limits | H | M | Limit parallel dispatch to max 4 concurrent agents; batch if wave is larger |
| Multi-state JSON corrupted by partial writes | H | L | Use atomic write pattern (write to .tmp then mv) |
| Single orchestrator context grows unbounded for large N | M | M | MAX_TASKS=8 cap at orchestrate.md level; split into batches if exceeded |
| Backward compatibility regression for single-task | L | L | Stage 0 detects `len == 1` and falls through to existing Stages 1-8 |
| Handoff file collision between parallel tasks in same wave | H | M | Each task writes to its own `${TASK_DIR}/.orchestrator-handoff.json`; no collision possible since TASK_DIR differs per task |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |
| 3    | 3      | 2          |
| 4    | 4      | 3          |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix artifact linking in SKILL.md Stage 5 (single-task) [COMPLETED]

**Goal**: Add `skill_link_artifacts()` call to the existing single-task Stage 5 handoff reading, fixing the pre-existing bug where TODO.md artifact links are never populated during orchestration.

**Tasks**:
- [x] **Task 1.1**: In `SKILL.md` Stage 5, after the existing `case "$dispatch_status"` block that calls `skill_postflight_update()`, add artifact extraction and linking logic *(completed)*
- [x] **Task 1.2**: Extract `handoff_artifact_path` and `handoff_artifact_type` from the handoff JSON's `artifacts[0]` field *(completed)*
- [x] **Task 1.3**: Map artifact type to `field_name` and `next_field` parameters *(completed)*
- [x] **Task 1.4**: Call `skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" "$dispatch_summary" "$field_name" "$next_field"` *(completed)*
- [x] **Task 1.5**: Guard with `if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]` to handle dispatches that produce no artifacts *(completed)*
- [x] **Task 1.6**: Also extract `handoff_artifact_summary` from `handoff.artifacts[0].summary // ""` for the artifact_summary parameter *(completed: also applied fix to extension mirror at .claude/extensions/core/skills/skill-orchestrate/SKILL.md)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage 5, after the `case "$dispatch_status"` block (around line 358)

**Verification**:
- The artifact linking block references `skill_link_artifacts` from `skill-base.sh` (already sourced at Stage 1)
- The new code only executes when a handoff file exists and contains an artifact path
- No regression to existing postflight status update logic

---

### Phase 2: Add multi-task mode detection and state initialization (SKILL.md Stage 0 + MT-1 + MT-2) [COMPLETED]

**Goal**: Add the multi-task entry point to SKILL.md that detects `multi_task_mode=true` in the delegation context, parses all task numbers and waves, builds a per-task routing table, and initializes the multi-state tracking file.

**Tasks**:
- [x] **Task 2.1**: Add a new `## Multi-Task Mode` section header (placed after Stage 8, before MUST NOT) in SKILL.md *(completed)*
- [x] **Task 2.2**: Add Stage 0 at the very beginning of the Execution Flow: parse `multi_task_mode` from delegation context; if true, branch to multi-task stages; if false, fall through to existing Stage 1 *(completed)*
- [x] **Task 2.3**: Implement Stage MT-1 (Parse multi-task context) — extracts task_numbers, dependency_graph, waves, session_id, focus_prompt from delegation context *(completed)*
- [x] **Task 2.4**: Implement Stage MT-2 (Build per-task routing table) — reads task_type from state.json, resolves agents per task using Stage 1b case statement + extension manifests, builds task_dirs/task_types/research_agents/implement_agents *(completed)*
- [x] **Task 2.5**: Implement multi-state initialization — creates `specs/.orchestrator-multi-state.json` with compact schema, sets MAX_CYCLES to `5 * len(task_numbers)` capped at 25 *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - New Stage 0 section before Stage 1; new Stage MT-1 and MT-2 sections after Stage 8

**Verification**:
- Stage 0 detection correctly parses `multi_task_mode` and branches
- Per-task routing matches the existing Stage 1b case statement logic
- Multi-state JSON file is created with valid schema and all task numbers populated
- Single-task mode (multi_task_mode=false or absent) falls through to existing Stage 1 unchanged

---

### Phase 3: Implement multi-task wave loop and phase-aware dispatch (SKILL.md Stages MT-3 through MT-4) [COMPLETED]

**Goal**: Implement the core wave execution loop that dispatches tasks to phase-specific agents based on each task's current lifecycle status, reads handoffs, calls postflight updates, and advances through waves.

**Tasks**:
- [x] **Task 3.1**: Implement Stage MT-3 (Wave execution loop) — outer loop over waves, filters active tasks (skips terminal states and tasks with failed predecessors), logs wave activity *(completed)*
- [x] **Task 3.2**: Implement phase-aware grouping within each wave iteration — reads current_status from state.json for freshness, groups into research_tasks/plan_tasks/implement_tasks, handles partial with continuation vs blockers *(completed)*
- [x] **Task 3.3**: Implement per-task handoff reading after each dispatch batch — reads handoff.json, calls skill_postflight_update() and skill_link_artifacts() per task, updates current_statuses in multi-state JSON, moves completed/failed tasks *(completed)*
- [x] **Task 3.4**: Implement cycle guard — increments cycle_count, exits with partial status at MAX_CYCLES, atomic multi-state JSON write pattern *(completed)*
- [x] **Task 3.5**: Implement dispatch context construction for each agent type — research/plan/implement contexts with appropriate fields *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - New Stages MT-3 and MT-4

**Verification**:
- Wave loop respects wave ordering (Wave 0 before Wave 1, etc.)
- Tasks within a wave are dispatched in parallel
- Phase grouping correctly maps task status to agent type
- Per-task postflight (both status sync and artifact linking) fires after every dispatch
- Cycle guard prevents unbounded looping
- Multi-state JSON is updated atomically after each batch

---

### Phase 4: Update orchestrate.md dispatch and add multi-task postflight (SKILL.md Stage MT-5) [COMPLETED]

**Goal**: Update orchestrate.md to dispatch a single skill-orchestrate instance for multi-task mode instead of N instances, and add the multi-task postflight stage to SKILL.md.

**Tasks**:
- [x] **Task 4.1**: Modify `orchestrate.md` Step 4 (Wave Execution) — replaced per-wave per-task Skill calls with single skill-orchestrate dispatch passing multi_task_mode=true, task_numbers, waves, dependency_graph, session_id, focus_prompt *(completed)*
- [x] **Task 4.2**: Implement Stage MT-5 (Multi-task postflight) in SKILL.md — on clean exit removes multi-state file, on partial exit preserves it; writes .return-meta-multi.json with aggregated results *(completed)*
- [x] **Task 4.3**: Update orchestrate.md Step 5 consolidated output to read from multi-state JSON — parses completed_tasks, failed_tasks, cycles_used; generates markdown table format; handles missing multi-state file *(completed)*
- [x] **Task 4.4**: Add MAX_TASKS=8 guard to orchestrate.md — trims task list to 8 with warning if exceeded *(completed)*
- [x] **Task 4.5**: Update delegation context JSON in orchestrate.md Step 4 to include all required fields: multi_task_mode, task_numbers, waves, dependency_graph, session_id, focus_prompt *(completed: also synced to .claude/extensions/core/commands/orchestrate.md)*

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/commands/orchestrate.md` - Step 4 (Wave Execution) rewrite, Step 5 result reading
- `.claude/skills/skill-orchestrate/SKILL.md` - New Stage MT-5 (Multi-task postflight)

**Verification**:
- Single-task mode (`len == 1`) still falls through to existing GATE IN flow unchanged
- Multi-task mode dispatches exactly one skill-orchestrate instance
- Consolidated output reads from multi-state JSON and produces correct markdown tables
- MAX_TASKS guard prevents large batches from overwhelming the orchestrator
- Return metadata contains per-task results for downstream consumers

---

## Testing & Validation

- [ ] Single-task orchestration: Run `/orchestrate N` for a single task and verify artifact links appear in TODO.md (Phase 1 fix)
- [ ] Single-task backward compatibility: Verify existing Stages 1-8 execute unchanged when `multi_task_mode` is false or absent
- [ ] Multi-task mode detection: Verify Stage 0 correctly branches to multi-task path when `multi_task_mode=true`
- [ ] Wave ordering: Verify tasks in Wave 0 complete before Wave 1 tasks are dispatched
- [ ] Phase-aware dispatch: Verify a `not_started` task gets research-agent while a `researched` task in the same wave gets planner-agent
- [ ] Per-task postflight: Verify both `skill_postflight_update()` and `skill_link_artifacts()` are called for each task after each phase
- [ ] Cycle guard: Verify orchestration exits cleanly when MAX_CYCLES is reached with partial progress
- [ ] Failed predecessor handling: Verify tasks whose predecessors failed are skipped with appropriate logging
- [ ] Multi-state JSON: Verify atomic writes and correct schema after each batch

## Artifacts & Outputs

- `specs/625_orchestrate_single_agent_multi_task/plans/01_orchestrate-refactor.md` (this file)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified: Stage 5 fix + new Stages 0, MT-1 through MT-5)
- `.claude/commands/orchestrate.md` (modified: Step 4 single dispatch, Step 5 result reading)

## Rollback/Contingency

- Phase 1 (artifact linking fix) is a standalone improvement that can be merged independently even if multi-task phases are reverted.
- The multi-task code path is entirely additive -- it lives behind the `multi_task_mode=true` flag check in Stage 0. Removing the multi-task stages restores the original single-task-only behavior.
- If the multi-task approach proves too complex, `orchestrate.md` can revert to the per-task dispatch pattern by removing the MAX_TASKS guard and single-dispatch logic in Step 4.
- `specs/.orchestrator-multi-state.json` is a transient file deleted on success; no persistent state is affected if the feature is rolled back.
