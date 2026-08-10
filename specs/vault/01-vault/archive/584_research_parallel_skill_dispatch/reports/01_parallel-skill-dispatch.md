# Research Report: Task #584

**Task**: 584 - research_parallel_skill_dispatch
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `.claude/context/patterns/multi-task-operations.md`
- `.claude/commands/research.md`
- `.claude/commands/plan.md`
- `.claude/commands/implement.md`
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/context/patterns/skill-lifecycle.md`
- `.claude/context/patterns/team-orchestration.md`
- `.claude/skills/skill-team-research/SKILL.md`
**Artifacts**:
- `specs/584_research_parallel_skill_dispatch/reports/01_parallel-skill-dispatch.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current multi-task dispatch in all three command files (research.md, plan.md, implement.md) uses parallel Agent tool calls, NOT parallel Skill tool calls. The question of "replacing Agent dispatch with Skill invocation" requires clarification: skills internally spawn agents; the orchestrator cannot directly invoke agents without going through a skill.
- The Skill tool description in the system prompt has no documented constraint against parallel invocation (calling multiple Skill tool instances in a single message), matching the precedent set by Agent tool parallel calls.
- The existing multi-task-operations.md Section 6 documents a "Batch Skill Dispatch (Option B)" architecture but the actual command files implement a different pattern: dispatch is handled directly by the orchestrator loop using parallel Agent calls, NOT by routing through a batch skill.
- State.json race conditions are acknowledged in multi-task-operations.md (Section 10) and are mitigated by scoped project_number writes; however the recommended mitigation (batch skill collecting all results before a single consolidated state update) conflicts with the actual command file approach where each agent handles its own postflight.
- Each agent/skill in the current architecture already does its own postflight (status update + git commit via skill-researcher Stage 7-12), which conflicts with the batch commit intent documented in Section 8 of multi-task-operations.md.
- The single-task flow (CHECKPOINT 1 → STAGE 2) is completely isolated from multi-task dispatch in all three command files.

## Context & Scope

This research investigates whether and how the multi-task dispatch mechanism in `/research`, `/plan`, and `/implement` commands should be changed from parallel Agent spawning to parallel Skill invocation, and what related changes would be needed.

The current architecture has a disconnect between the specification document (multi-task-operations.md) and the actual command file implementations. Research maps the exact current state of all four files.

## Findings

### 1. Skill Tool Parallel Invocation

The Skill tool description in the system prompt states it "executes a skill within the main conversation." There is no documented constraint against calling it multiple times in a single message (parallel invocation). The Agent tool explicitly documents parallel usage ("invoke in a single message"), and by analogy the Skill tool should support the same pattern.

**Precedent from team-mode**: `skill-team-research/SKILL.md` Stage 5 explicitly spawns multiple Agent calls in a single message for parallel teammate execution. This is the existing precedent for parallel execution within the agent system. However, this is Agent parallel calls (from inside a skill), not parallel Skill calls (from the orchestrator).

**Critical distinction**: There is no example in the codebase of the orchestrator (command) invoking the Skill tool in parallel (multiple skills in one message). The team-orchestration precedent is agent-level, not skill-level. Whether parallel Skill invocation works the same way as parallel Agent invocation would need to be validated empirically.

### 2. Current Multi-Task Dispatch: What the Code Files Actually Say

All three command files currently use this dispatch pattern in Step 3:

**research.md** (lines 158-166):
> "Spawn one agent per task via parallel Agent tool calls"
> "Note: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill."

**plan.md** (lines 165-174):
> "Spawn one agent per task via parallel Agent tool calls"
> "Note: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill."

**implement.md** (lines 182-186):
> "Spawn one agent per task via parallel Agent tool calls"
> "Note: Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill."

All three files contain an explicit "Note" asserting that batch dispatch uses Agent calls directly, NOT a separate skill.

### 3. multi-task-operations.md vs Command Files: Architecture Mismatch

Section 6 of multi-task-operations.md documents "Batch Skill Dispatch (Option B)":
```
Command -> Skill(batch dispatch) -> [Task(agent, task 7), Task(agent, task 22), ...]
```

This is the spec-level architecture. But all three command files then diverge: they implement the dispatch inline in the orchestrator loop using Agent calls directly, explicitly noting "not by a separate skill."

Section 12 of multi-task-operations.md (lines 504-513) also confirms this is the intended pattern:
> "Multi-task dispatch is handled by the orchestrator loop built into each command file... not by a separate skill-batch-dispatch skill."

So multi-task-operations.md contains both the "Option B" batch-skill description AND the "orchestrator loop" description. The command files follow the orchestrator-loop variant. This is an internal documentation inconsistency in multi-task-operations.md.

### 4. Exact Change Locations

**multi-task-operations.md**:
- Section 6 "Parallel Agent Spawning" needs to clarify or update the architecture description in lines 226-238. The "Option B" framing conflicts with Section 12 (lines 504-513). If the goal is to switch to parallel Skill calls, this section needs updating to replace "parallel Agent tool calls" with "parallel Skill tool calls" throughout, and the rationale for Option B would need updating.
- Section 10 "Concurrent State Safety" (lines 453-458) documents the mitigation strategy: "batch skill collects all results and performs a single consolidated state update." This would apply if skills do NOT do their own postflight in multi-task mode.

**research.md**:
- MULTI-TASK DISPATCH Step 3 (lines 158-166): Replace the Agent-based dispatch description with Skill-based dispatch. The new language would describe invoking the routing skill per task in parallel (e.g., `skill-researcher`, `skill-neovim-research`, etc.) and collecting their text returns.

**plan.md**:
- MULTI-TASK DISPATCH Step 3 (lines 163-174): Replace parallel Agent tool calls with parallel Skill tool calls to the appropriate planner skill (e.g., `skill-planner`).

**implement.md**:
- MULTI-TASK DISPATCH Step 3 (lines 178-188): Replace parallel Agent tool calls with parallel Skill tool calls to the appropriate implementer skill (e.g., `skill-implementer`, `skill-neovim-implementation`, etc.).

### 5. State.json Race Conditions

**Current analysis**:
- multi-task-operations.md Section 10 (lines 453-458) explicitly acknowledges the race condition risk.
- The mitigation documented is: "batch skill collects all results and performs a single consolidated state update after all agents complete."
- Each spawned agent (via its skill postflight) writes to state.json independently during parallel execution.
- Skills use jq operations scoped by `project_number`, which reduces but does not eliminate race conditions.

**Race condition scenario**: Two agents A (task 7) and B (task 22) both:
1. Read state.json
2. Modify their own project entry
3. Write state.json back

If A's read and B's read happen before either write, B's write will overwrite A's changes. The `project_number`-scoped jq operations do NOT prevent this because jq uses read-then-write (not atomic transactions).

**Current mitigation gap**: Each skill does its own postflight (including state.json writes), so the "consolidated state update" described in multi-task-operations.md is NOT currently implemented. The actual command files rely on per-agent postflight, which has the race risk.

**Switching to Skill dispatch**: If parallel Skill calls are used, each skill still does its own postflight (state.json writes). The race condition does not go away; it moves from agent-level to skill-level postflight. The only way to eliminate races is the batch skill pattern where skills skip postflight and the orchestrator does a single consolidated write.

### 6. Return Value Changes: Skills vs Agents

**Agent returns**: When the orchestrator uses parallel Agent tool calls, each agent writes its result to a `.return-meta.json` file. The orchestrator reads these files to collect results. Agent tool returns are text summaries; the structured data comes from file I/O.

**Skill returns**: Skills return brief text summaries (NOT JSON). From `skill-researcher/SKILL.md` Stage 10 and Return Format sections: "This skill returns a brief text summary (NOT JSON)."

**Collection pattern**: With parallel Skill invocations, the orchestrator receives text summaries from each skill invocation directly (no `.return-meta.json` file reading needed). The text summary format from `skill-researcher/SKILL.md`:
```
Research completed for task {N}:
- Found {count} relevant patterns...
- Created report at specs/{NNN}.../reports/...
- Status updated to [RESEARCHED]
```

**Implication**: The batch result collection in Section 9 of multi-task-operations.md (the JSON `results` array) was designed for Agent returns reading metadata files. With Skill returns, the orchestrator parses skill text summaries instead. The batch output format (Table with Task/Status/Artifact columns) would require parsing skill text summaries or having skills signal success/failure through their text return.

**Recommendation**: Skills could return a simple structured prefix line indicating success/failure and artifact path, which the orchestrator parses to build the consolidated output table. Example: `RESULT: success task=7 status=researched artifact=specs/007_.../reports/01_....md`. This avoids JSON but provides machine-parseable output.

### 7. Batch Commit Implications

**Current state**: Each skill (via its postflight) does its own git commit. Skill-researcher Stage 12 (team research) uses targeted staging and commits. Skill-researcher's flow from SKILL.md shows no explicit git commit in Stage 9 cleanup, but the command files (research.md CHECKPOINT 3) do the final commit after skill return.

**Conflict**: multi-task-operations.md Section 8 documents a SINGLE batch commit after all agents complete. But in practice:
1. Each skill's postflight may commit (skill-team-research Stage 12 explicitly commits)
2. The command file then does a batch commit at Step 4

This creates potential double-commits. The batch commit at the command level commits changes already committed per-skill.

**With parallel Skill dispatch**: The same double-commit issue exists unless skills skip their individual commits when invoked in multi-task mode. Since skills have no way to know they're being called in multi-task mode (the args string doesn't contain this flag), they would always commit individually.

**Resolution options**:
1. Pass a `skip_commit=true` flag to skills when invoked from multi-task dispatch, and have skills check this flag before committing.
2. Accept double-commits (idempotent, since `git add -A` then commit on already-committed changes produces an empty commit, which fails gracefully).
3. Have the batch commit use only `git add -A` to catch anything skills missed, and treat it as a cleanup commit.

### 8. Single-Task Flow Preservation

All three command files have clear structural separation:

- **research.md**: STAGE 0 → dispatch decision → if single: fall through to CHECKPOINT 1 → STAGE 1.5 → STAGE 2. The MULTI-TASK DISPATCH section is completely separate and explicitly says "After dispatch completes, skip directly to output (do not enter single-task checkpoints)."

- **plan.md**: Same structure. MULTI-TASK DISPATCH ends with "End of multi-task flow. Do NOT continue to the single-task checkpoints below."

- **implement.md**: Same structure. "After consolidated output, STOP. The multi-task flow does not continue to CHECKPOINT 1."

The single-task flow (CHECKPOINT 1 → STAGE 2) is untouched regardless of any multi-task changes.

## Decisions

1. The current command files use parallel Agent calls (not parallel Skill calls) for multi-task dispatch. Any change to switch to Skill dispatch is a documentation/implementation change to the Step 3 sections of all three command files.

2. The parallel Skill invocation approach has no documented blocker in the Skill tool specification, but lacks an empirical precedent in this codebase (unlike Agent parallel calls which have team-orchestration precedent).

3. State.json races exist whether dispatch is via Agent or Skill, since both rely on per-task postflight. The real mitigation is having skills skip their own state.json writes in batch mode.

4. Skills return text (not JSON), requiring either text parsing or a structured prefix convention for batch result collection.

5. Batch commits conflict with per-skill commits. A `skip_commit` flag or accepting duplicate commits is the resolution path.

## Recommendations

1. **Clarify the architecture goal first**: The task asks to replace Agent dispatch with Skill dispatch, but the command files already say "not by a separate skill" because the orchestrator IS doing inline dispatch via Agent calls. The actual change would be: instead of `Agent(subagent_type="general-research-agent")`, use `Skill(skill-researcher)`. This means the orchestrator calls skills directly in parallel, and each skill internally spawns its own agent.

2. **multi-task-operations.md Section 6**: Update to clearly describe parallel Skill calls (not Agent calls). Remove the "Option B" framing and consolidate with Section 12 to have one consistent description.

3. **Research/Plan/Implement Step 3**: Replace "parallel Agent tool calls" with "parallel Skill tool calls". The routing logic (which skill per task type) already exists in STAGE 2 of each command; the same routing should apply in multi-task Step 3.

4. **State.json race handling**: Add a `batch_mode=true` flag that skills can check. If set, skills skip state.json writes (status update, artifact linking) and the batch orchestrator performs a single consolidated update after all parallel skills complete.

5. **Batch commit clarity**: Either (a) add `skip_commit=true` flag for batch mode and have skills skip their git commits, or (b) document that per-skill commits happen and the batch "commit" at Step 4 is a best-effort cleanup commit that may be empty.

6. **Return value parsing**: Define a structured text return convention for skills when invoked in multi-task mode. A prefix line like `RESULT: success task=7 artifact=...` enables the orchestrator to parse results without JSON.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Parallel Skill calls not supported | Medium | Validate empirically before implementing; fallback to sequential skill calls |
| State.json corruption from concurrent writes | High | Implement `batch_mode=true` flag so skills skip writes; orchestrator does consolidated update |
| Double-commit from per-skill + batch commit | Low | Accept idempotent behavior or add `skip_commit` flag |
| Skills unaware of batch context | Medium | Add `batch_mode` parameter to skill args; skills check and modify behavior |
| Text-return parsing fragility | Medium | Define structured prefix convention; document in skill-lifecycle.md |

## Context Extension Recommendations

- **Topic**: Multi-task dispatch architecture clarity
- **Gap**: multi-task-operations.md has conflicting descriptions (Section 6 "Option B" batch skill vs Section 12 "orchestrator loop with Agent calls"). This causes confusion about what the intended implementation is.
- **Recommendation**: Resolve the conflict with a definitive architecture statement, either in multi-task-operations.md or in a new context file documenting the parallel-skill-dispatch pattern.

## Appendix

### Files Examined

| File | Lines | Key Sections |
|------|-------|-------------|
| `.claude/context/patterns/multi-task-operations.md` | 523 | Section 6 (lines 225-295), Section 8 (lines 327-376), Section 10 (lines 427-459), Section 12 (lines 477-514) |
| `.claude/commands/research.md` | 500 | MULTI-TASK DISPATCH (lines 117-233), Step 3 (lines 158-166) |
| `.claude/commands/plan.md` | 532 | MULTI-TASK DISPATCH (lines 111-231), Step 3 (lines 163-174) |
| `.claude/commands/implement.md` | 613 | MULTI-TASK DISPATCH (lines 114-261), Step 3 (lines 178-188) |
| `.claude/skills/skill-researcher/SKILL.md` | 559 | Stage 5-12 (postflight and return format) |
| `.claude/context/patterns/skill-lifecycle.md` | 164 | Return format, postflight boundary |
| `.claude/context/patterns/team-orchestration.md` | 145 | Wave execution, parallel Agent spawning |
| `.claude/skills/skill-team-research/SKILL.md` | 617 | Stage 5 parallel Agent spawn, Stage 12 git commit |

### Key Quote: Architecture Conflict

From `multi-task-operations.md` Section 6 (line 226-238):
> "Architecture: Batch Skill Dispatch (Option B) -- Command -> Skill(batch dispatch) -> [Task(agent, task 7)...]"

From `multi-task-operations.md` Section 12 (lines 504-513):
> "Multi-task dispatch is handled by the orchestrator loop built into each command file, not by a separate skill-batch-dispatch skill."

These two statements in the same document conflict. The command files implement the Section 12 description (direct Agent calls).

### Skill Return Format (from skill-researcher/SKILL.md)

Skills return **brief text summaries, NOT JSON**. The structured data is written to `.return-meta.json` and read by the skill's own postflight -- the file is deleted during cleanup. So if the orchestrator needs to collect artifact paths and status from parallel skills, it needs either: (a) text parsing of skill returns, (b) skills to leave their `.return-meta.json` files in place for orchestrator reading, or (c) a structured text prefix convention.
