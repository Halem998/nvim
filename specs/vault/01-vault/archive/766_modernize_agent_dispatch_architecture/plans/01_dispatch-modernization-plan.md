# Implementation Plan: Task #766

- **Task**: 766 - Modernize agent dispatch architecture for current Claude Code capabilities
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: None (tasks 764, 765 already fixed immediate bugs)
- **Research Inputs**: specs/766_modernize_agent_dispatch_architecture/reports/01_dispatch-modernization-research.md
- **Artifacts**: plans/01_dispatch-modernization-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the dispatch-agent.sh indirection layer (4 files totaling ~720 lines) and replace all dispatch pseudocode in skill-orchestrate/SKILL.md with direct Agent tool call prose tables. Rewrite the ~590-line MT mode bash pseudocode (Stages MT-1 through MT-5) as ~150-line numbered prose steps with explicit dispatch tables. Unify the two fork dispatch points to use `subagent_type: "fork"` consistently, matching the pattern already working in skill-researcher.

### Research Integration

Key findings from the research report (01_dispatch-modernization-research.md):

1. **dispatch-agent.sh is pseudocode, not runtime**: The script generates JSON that is never programmatically parsed. The Claude instance always makes Agent tool calls directly from SKILL.md prose. The 360 lines (128 script + 233 spec) across 4 files add complexity with no runtime effect.
2. **MT bash pseudocode is the primary reliability risk**: Tasks 764 and 765 both resulted from the model misinterpreting bash that looks executable but requires human-level intent reading. Prose tables would eliminate this class of bug.
3. **Fork patterns should use `subagent_type: "fork"`**: The FORK_SUBAGENT env var mechanism is outdated. skill-researcher already uses `subagent_type: "fork"` successfully.
4. **No Workflow tool available**: The Workflow tool referenced in the original task description is not in the skill's available tool set. MT mode stays as prose dispatch tables, not declarative pipelines.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" roadmap items under Phase 1, specifically reducing dead-code complexity and improving dispatch reliability.

## Goals & Non-Goals

**Goals**:
- Remove dispatch-agent.sh and its spec doc (both core and extension copies)
- Replace all `dispatch_instructions = dispatch_agent ...` patterns in SKILL.md with direct Agent tool call prose tables
- Rewrite MT-1 through MT-5 (~590 lines of bash pseudocode) as ~150 lines of numbered prose steps
- Unify fork dispatch to use `subagent_type: "fork"` consistently
- Update orchestrate-state-machine.md to reflect the direct-dispatch pattern

**Non-Goals**:
- Redesigning MT mode around a Workflow tool (not available)
- Changing the blocker escalation 5-step sequence (only the dispatch format changes)
- Modifying skill-orchestrate-hard/SKILL.md (if it has no dispatch-agent references, leave it)
- Changing agent routing logic (task_type -> agent mapping stays the same)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| MT prose rewrite omits edge case (failed_tasks, dependency gating, continuation context) | H | M | Phase 3 includes a pre-write edge case checklist extracted from existing MT code; verify each is present in prose |
| Removing dispatch-agent.sh breaks an undiscovered consumer | L | L | Grep confirmed only SKILL.md and extension copy reference it; verify with find before deletion |
| `subagent_type: "fork"` behaves differently from FORK_SUBAGENT env var omission pattern | M | L | Already confirmed working in skill-researcher Stage 4a; pattern is identical |
| Plan drift: MT rewrite grows beyond ~150 lines defeating the simplification goal | M | M | Set hard line-count target; if exceeding 200 lines, factor out repetitive sections into a reference table |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Delete dispatch-agent.sh files and update references [COMPLETED]

**Goal**: Remove the 4 dispatch-agent files and update any cross-references in architecture docs.

**Tasks**:
- [ ] Verify no other consumers exist: `grep -rn "dispatch-agent\|dispatch_agent" .claude/ --include="*.sh" --include="*.md" | grep -v "SKILL.md\|dispatch-agent-spec.md\|dispatch-agent.sh\|orchestrate-state-machine.md"`
- [ ] Delete `.claude/scripts/dispatch-agent.sh` (128 lines)
- [ ] Delete `.claude/extensions/core/scripts/dispatch-agent.sh` (extension copy)
- [ ] Delete `.claude/docs/architecture/dispatch-agent-spec.md` (233 lines)
- [ ] Delete `.claude/extensions/core/docs/architecture/dispatch-agent-spec.md` (extension copy)
- [ ] Update the "See Also" line in `.claude/docs/architecture/orchestrate-state-machine.md` (line 5) to remove the `dispatch-agent-spec.md` reference
- [ ] Grep for any remaining references to the deleted files and fix them

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/dispatch-agent.sh` - Delete
- `.claude/extensions/core/scripts/dispatch-agent.sh` - Delete
- `.claude/docs/architecture/dispatch-agent-spec.md` - Delete
- `.claude/extensions/core/docs/architecture/dispatch-agent-spec.md` - Delete
- `.claude/docs/architecture/orchestrate-state-machine.md` - Remove dispatch-agent-spec.md reference

**Verification**:
- `find .claude -name "dispatch-agent*"` returns no results
- `grep -rn "dispatch-agent" .claude/` returns no hits (except this plan)
- No broken cross-references in architecture docs

---

### Phase 2: Rewrite single-task dispatch in SKILL.md as direct Agent tool call prose [COMPLETED]

**Goal**: Replace all `dispatch_instructions = dispatch_agent ...` patterns in Stages 4, 5a, and 6 with direct prose tables specifying Agent tool call parameters. Also unify fork dispatch to use `subagent_type: "fork"`.

**Tasks**:
- [ ] Replace Stage 4 `not_started` state handler (lines ~203-209): Remove `dispatch_instructions = dispatch_agent` block, replace with prose table:
  ```
  Invoke the Agent tool:
    subagent_type: $RESEARCH_AGENT
    prompt: "Research task $task_number: $DESCRIPTION..."
    context: { task_number, task_type, session_id, orchestrator_mode: false, lit_flag }
  After return: read handoff (Stage 5). Increment cycle_count.
  ```
- [ ] Replace Stage 4 `researched` state handler (lines ~230-236): Same pattern with planner-agent
- [ ] Replace Stage 4 `planned`/`implementing` state handler (lines ~253-260): Same pattern with $IMPLEMENT_AGENT
- [ ] Replace Stage 4 `partial` continuation handler (lines ~280-286): Same pattern with continuation_context
- [ ] Replace Stage 5a drift inspection (lines ~440-490): Remove `source dispatch-agent.sh` and `dispatch_agent "" ... "true"`, replace with:
  ```
  Invoke the Agent tool:
    subagent_type: "fork"
    prompt: "$drift_inspect_prompt"
    context: { task_number, session_id, plan_path }
  ```
- [ ] Replace Stage 5a reviser dispatch (lines ~482-484): Direct prose with `subagent_type: "reviser-agent"`
- [ ] Replace Stage 6 blocker research fork (lines ~523-530): Remove `source dispatch-agent.sh` and `dispatch_agent "" ... "true"`, replace with:
  ```
  Invoke the Agent tool:
    subagent_type: "fork"
    prompt: "$blocker_research_prompt"
    context: { task_number, session_id, blocker }
  ```
- [ ] Replace Stage 6 Step 4 reviser dispatch (lines ~550-552): Direct prose with `subagent_type: "reviser-agent"`
- [ ] Replace Stage 6 Step 5 re-implement dispatch (lines ~565-567): Direct prose with `subagent_type: $IMPLEMENT_AGENT`
- [ ] Remove all `source .claude/scripts/dispatch-agent.sh` lines from SKILL.md

**Timing**: 1 hour

**Depends on**: Phase 1 (dispatch-agent.sh files must be deleted first so no stale references remain)

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stages 4, 5a, 6 (single-task dispatch blocks)

**Verification**:
- `grep -n "dispatch_instructions\|dispatch_agent\|source.*dispatch" .claude/skills/skill-orchestrate/SKILL.md` returns no results
- `grep -n "FORK_SUBAGENT" .claude/skills/skill-orchestrate/SKILL.md` returns no results
- All fork dispatches use `subagent_type: "fork"` (verify with grep)
- Each state handler clearly shows: subagent_type, prompt template, context fields, and post-return action

---

### Phase 3: Rewrite MT mode (Stages MT-1 through MT-5) as numbered prose steps [COMPLETED]

**Goal**: Replace ~590 lines of bash pseudocode (Stages MT-1 through MT-5) with ~150 lines of numbered prose steps and explicit dispatch tables. Preserve all edge case handling while making the batching requirement visually prominent.

**Tasks**:
- [ ] Pre-write edge case checklist -- verify each is addressed in the prose rewrite:
  - Dependency gating (predecessor terminal check)
  - Failed task propagation (predecessor failed -> downstream blocked)
  - In-flight state skipping (researching/planning)
  - No-eligible-tasks circuit breaker
  - Continuation context for partial tasks
  - Blocker detection in partial state
  - Per-task postflight (status update + artifact linking)
  - Multi-state file lifecycle (create, update, cleanup)
  - MAX_CYCLES_MT cap (5 * task_count, capped at 25)
  - Parallel Agent call batching rule
- [ ] Rewrite Stage MT-1 as prose: "Parse task_numbers, dependency_graph, and waves from delegation context" (3-5 lines)
- [ ] Rewrite Stage MT-2 as prose with a routing table: "For each task, read task_type from state.json and resolve agents" + agent routing table + multi-state initialization (15-20 lines)
- [ ] Rewrite Stage MT-3 as numbered prose loop: numbered steps for status refresh, all-terminal check, eligible-task filtering, no-eligible circuit breaker (30-40 lines)
- [ ] Rewrite Stage MT-4 as dispatch table with batching rule: group tasks by needed phase (research/plan/implement), build Agent tool call table, issue ALL calls in ONE message (30-40 lines)
- [ ] Rewrite MT-4 postflight section: read handoffs, call per-task postflight, update multi-state (20-25 lines)
- [ ] Rewrite Stage MT-5 as prose: final aggregation, cleanup, return metadata (10-15 lines)
- [ ] Remove the python3 inline call (originally lines 761-766) -- replace with prose or direct jq
- [ ] Verify total MT section is under 200 lines

**Timing**: 1.5 hours

**Depends on**: Phase 1 (no dispatch-agent.sh references to worry about)

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stages MT-1 through MT-5 (lines ~660-1246)

**Verification**:
- MT section line count is under 200 lines (target: ~150)
- No bash `declare -A` associative arrays remain
- No python3 inline calls remain
- Batching rule is visually prominent (bold or boxed)
- Each edge case from the checklist appears in the prose
- `grep -c "dispatch_agent\|dispatch_instructions" .claude/skills/skill-orchestrate/SKILL.md` returns 0

---

### Phase 4: Update architecture docs and verify consistency [COMPLETED]

**Goal**: Update orchestrate-state-machine.md to reflect the direct-dispatch pattern. Verify the entire SKILL.md is internally consistent.

**Tasks**:
- [ ] Update `.claude/docs/architecture/orchestrate-state-machine.md` to remove references to dispatch-agent.sh and document the direct prose dispatch pattern
- [ ] Verify the SKILL.md line count has decreased (target: from ~1274 to under ~900)
- [ ] Run final consistency check: grep for any remaining references to deleted files across all of `.claude/`
- [ ] Verify fork-patterns.md still accurately describes the fork dispatch model (the FORK_SUBAGENT env var section may need updating or a note)
- [ ] Update `.claude/context/patterns/fork-patterns.md` if it references FORK_SUBAGENT as the primary fork mechanism (add note that `subagent_type: "fork"` is the current pattern)

**Timing**: 30 minutes

**Depends on**: Phases 2 and 3 (SKILL.md changes must be complete before doc alignment)

**Files to modify**:
- `.claude/docs/architecture/orchestrate-state-machine.md` - Update dispatch references
- `.claude/context/patterns/fork-patterns.md` - Update fork dispatch pattern description (if needed)

**Verification**:
- `grep -rn "dispatch-agent\|FORK_SUBAGENT" .claude/ --include="*.md" --include="*.sh"` returns no stale references
- SKILL.md total line count is under 900
- orchestrate-state-machine.md accurately describes the current dispatch model
- fork-patterns.md documents `subagent_type: "fork"` as the primary fork mechanism

## Testing & Validation

- [ ] `grep -rn "dispatch-agent" .claude/` returns no results (files fully removed)
- [ ] `grep -rn "dispatch_agent\|dispatch_instructions" .claude/skills/skill-orchestrate/SKILL.md` returns no results
- [ ] `grep -rn "FORK_SUBAGENT" .claude/skills/skill-orchestrate/SKILL.md` returns no results
- [ ] All fork dispatches use `subagent_type: "fork"` pattern
- [ ] SKILL.md line count is under 900 (down from 1274)
- [ ] MT section (MT-1 through MT-5) is under 200 lines (down from ~590)
- [ ] No python3 inline calls in SKILL.md
- [ ] Single-task state handlers each show: subagent_type, prompt, context, post-return action
- [ ] MT batching rule is explicitly stated and visually prominent

## Artifacts & Outputs

- `specs/766_modernize_agent_dispatch_architecture/plans/01_dispatch-modernization-plan.md` (this file)
- `specs/766_modernize_agent_dispatch_architecture/summaries/01_dispatch-modernization-summary.md` (after implementation)

## Rollback/Contingency

All deleted files are tracked in git. If the SKILL.md rewrite introduces regressions:

1. `git checkout HEAD -- .claude/scripts/dispatch-agent.sh .claude/docs/architecture/dispatch-agent-spec.md` to restore deleted files
2. `git checkout HEAD -- .claude/skills/skill-orchestrate/SKILL.md` to restore original SKILL.md
3. Extension copies can be restored similarly from git history

The changes are entirely within `.claude/` documentation and pseudocode -- no runtime scripts or configuration files are modified. The risk of user-facing breakage is minimal since dispatch-agent.sh was never executed as runtime code.
