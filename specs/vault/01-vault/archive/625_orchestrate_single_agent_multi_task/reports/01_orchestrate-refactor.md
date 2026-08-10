# Research Report: Task #625

**Task**: 625 - Refactor skill-orchestrate for single-agent multi-task orchestration
**Started**: 2026-06-01T23:05:00Z
**Completed**: 2026-06-01T23:30:00Z
**Effort**: 45 minutes
**Dependencies**: Task 623 (multi-task dispatch in orchestrate.md), Task 624 (postflight status sync)
**Sources/Inputs**: Codebase (SKILL.md, orchestrate.md, skill-base.sh, dispatch-agent.sh, update-task-status.sh, link-artifact-todo.sh, task 623 plan, task 624 summary)
**Artifacts**: specs/625_orchestrate_single_agent_multi_task/reports/01_orchestrate-refactor.md

## Executive Summary

- The current `orchestrate.md` multi-task dispatch spawns one `skill-orchestrate` invocation per task per wave, incurring the full 44k-token context cost per task. Task 625 refactors this so a single orchestrator agent manages all tasks, dispatching phase-specific workers (research, planner, implement agents) directly.
- The key challenge is designing per-task state tracking within a single agent context, coordinating wave-based dependency scheduling internally, and ensuring TODO.md synchronization (update-task-status.sh + link-artifact-todo.sh) is called for each task after each phase.
- The existing `skill_postflight_update()` in skill-base.sh (fixed in task 624) provides the exact hook needed; the new multi-task SKILL.md must call it per-task after each worker dispatch.
- Recommended approach: extend `skill-orchestrate/SKILL.md` with a second entry point triggered by `multi_task_mode=true`. The skill maintains an in-memory compact status table (JSON file), dispatches all tasks in a wave as parallel Agent calls, reads per-task handoffs, updates TODO.md per task, and advances to the next wave.

## Context & Scope

### What Was Researched

This research covers the complete orchestration stack:
1. How `skill-orchestrate/SKILL.md` implements the single-task state machine (Stages 1-8)
2. How `orchestrate.md` currently dispatches one skill per task in multi-task mode (Steps 1-5)
3. How `dispatch-agent.sh` and `skill-base.sh` provide dispatch infrastructure
4. How `update-task-status.sh` and `link-artifact-todo.sh` synchronize TODO.md
5. What tasks 623 and 624 established as prior context

### Prior Work (Tasks 623 and 624)

**Task 623** (completed): Added multi-task argument parsing and wave dispatch to `orchestrate.md`. Explicitly chose NOT to modify `skill-orchestrate/SKILL.md` — the skill stayed single-task; all multi-task coordination lives in `orchestrate.md`. Each wave dispatches tasks in parallel via concurrent Skill tool calls to `skill-orchestrate`.

**Task 624** (completed): Fixed postflight status sync gap in `skill-orchestrate/SKILL.md` Stage 5. The orchestrate state machine now calls `skill_postflight_update()` after each successful research/plan/implement dispatch, updating both state.json and TODO.md Task Order. Three locations were fixed:
- `SKILL.md` Stage 5: Added case statement calling `skill_postflight_update()` for `researched`, `planned`, `implemented` statuses
- `command-gate-out.sh`: Added `orchestrate` case and fixed operator precedence

**Remaining gap (task 625's scope)**: The multi-task dispatch in `orchestrate.md` still spawns O(N) skill-orchestrate instances. Each instance loads the full 44k-token SKILL.md context. For N tasks, this is N * 44k tokens of overhead just in skill invocation, before any actual agent work begins. The goal is O(1) skill invocation where a single orchestrator agent handles all N tasks.

## Findings

### Current Architecture Analysis

#### orchestrate.md Multi-Task Path (Stages 4.2-4.4)

```
STAGE 0 parse -> len(TASK_NUMBERS) > 1 -> MULTI-TASK DISPATCH
  Step 1: Batch validation
  Step 2: Dependency graph construction
  Step 3: Topological wave assignment (Kahn's algorithm)
  Step 4: Wave execution
    For each wave:
      For each task in wave (parallel):
        Skill("skill-orchestrate", args="task_number={N} ...")
  Step 5: Git commit + consolidated output
```

Each `Skill("skill-orchestrate")` call invokes the full SKILL.md context, then the skill itself dispatches research/plan/implement agents. For N=5 tasks, this means 5 skill contexts + 5*3 agent invocations minimum. The O(N * 44k) overhead is in the skill invocations themselves.

#### skill-orchestrate/SKILL.md State Machine (Stages 1-8)

The single-task state machine:
- **Stage 1**: Parse task_number from delegation_context, read state.json, resolve RESEARCH_AGENT/IMPLEMENT_AGENT by task_type
- **Stage 1b**: Route task_type to correct extension agents (neovim, nix, lean4, general)
- **Stage 2**: Create/read loop guard file (MAX_CYCLES=5)
- **Stage 3**: State machine loop — reads current_status, dispatches by state
- **Stage 4**: State handlers: `not_started`→research, `researched`→plan, `planned`/`implementing`→implement, `partial`→resume/escalate, `blocked`→escalate, `completed`→exit
- **Stage 5**: Handoff reading — reads `.orchestrator-handoff.json`, calls `skill_postflight_update()` (added in task 624), increments cycle_count
- **Stage 5a**: Drift inspection (fork subagent, compares plan checklist completion)
- **Stage 6**: Blocker escalation (5-step: detect, fork-research, revise, re-implement)
- **Stage 7**: Loop guard update, MAX_CYCLES check
- **Stage 8**: Postflight — writes .return-meta.json

Key constraint: SKILL.md explicitly MUST NOT read research reports, plan files, or summaries — only `.orchestrator-handoff.json` (<=400 tokens). This is the Context Flatness Constraint that keeps context growth to ~450 tokens per cycle.

#### skill-base.sh Infrastructure

The key functions used by skill-orchestrate:

- `skill_postflight_update(task_number, operation, session_id, status)` — calls `update-task-status.sh postflight` which updates state.json + TODO.md task entry + TODO.md Task Order
- `skill_link_artifacts(task_number, artifact_path, artifact_type, ...)` — calls `link-artifact-todo.sh` to add artifact links to TODO.md task entries; also updates state.json artifacts array
- `skill_write_orchestrator_handoff(...)` — writes `.orchestrator-handoff.json` for the parent state machine to read

Currently in SKILL.md, `skill_postflight_update()` is called in Stage 5 after reading the handoff. However, `skill_link_artifacts()` is NOT called from within SKILL.md — artifact linking happens inside the individual research/plan/implement skills (via their own postflight). So TODO.md artifact links are already correctly populated by the worker agents.

#### update-task-status.sh

Updates in three phases:
1. state.json: status, last_updated, session_id
2. TODO.md task entry: replaces `[STATUS]` in `- **Status**:` line
3. TODO.md Task Order: in-place sed for non-terminal; full regeneration for terminal
4. Plan file status (implement only)
5. WezTerm/TTS lifecycle notifications

Idempotent: if task is already at target status, exits 0 with no-op.

#### link-artifact-todo.sh

Implements four-case logic for adding artifact links to a task's TODO.md entry:
- Case 1: No existing field line — inserts new `- **Research**:` line before next_field
- Case 2: Existing inline single link — converts to multi-line list
- Case 3: Existing multi-line header — appends new bullet
- Case 4: Link already present — no-op

Called by `skill_link_artifacts()` in skill-base.sh. Already called correctly from within individual research/plan/implement skills when they run in orchestrator_mode. The question is whether the single-agent multi-task orchestrator needs to call it redundantly.

### Key Design Insight: Where Does Artifact Linking Happen?

After reading the full skill-base.sh, the artifact linking flow is:

1. Worker agent (e.g., general-research-agent) writes `.return-meta.json` with artifact_path
2. The skill that invoked the agent (e.g., skill-researcher) calls `skill_link_artifacts()` in its postflight
3. `skill_link_artifacts()` updates both state.json artifacts array and TODO.md via link-artifact-todo.sh

In the current single-task orchestrate path:
- `skill-orchestrate` dispatches `general-research-agent` directly (not via `skill-researcher`)
- The research agent writes `.orchestrator-handoff.json` with the artifact path
- `skill-orchestrate` Stage 5 reads the handoff and calls `skill_postflight_update()` (status sync)
- BUT `skill_link_artifacts()` is NOT called from SKILL.md — artifact linking is done inside the research agent itself when it calls `skill_link_artifacts()` in its own return path

Wait — re-reading SKILL.md more carefully: the state handlers dispatch agents directly via `dispatch_agent()`, which routes to `invoke_named_agent()` producing dispatch instructions. The skill itself calls the Agent tool. The research/plan/implement agents are invoked as named subagents, and those subagents include their own postflight that calls `skill_link_artifacts()`.

However, when `orchestrator_mode=true`, the research agent's skill-researcher wrapper is bypassed — the orchestrate skill invokes the research agent directly. The research agent (general-research-agent) writes its `.return-meta.json` and the orchestrator reads `.orchestrator-handoff.json`. Looking at SKILL.md Stage 5, the postflight update calls `skill_postflight_update()` which handles status, but there is no `skill_link_artifacts()` call in SKILL.md.

This means: **artifact linking to TODO.md is currently missing from within skill-orchestrate**. The task description confirms this: "ensure the single orchestrator properly calls... link-artifact-todo.sh after artifact creation."

### Proposed Multi-Task State Machine Design

#### Architecture Decision: Extend SKILL.md vs New Skill

**Option A**: Add multi-task code path to existing `skill-orchestrate/SKILL.md`
- Entry point: check `multi_task_mode` flag in delegation_context
- Pro: Single skill file, reuses all existing infrastructure
- Con: SKILL.md becomes larger and more complex

**Option B**: Create a new `skill-orchestrate-multi/SKILL.md`
- Route from orchestrate.md to different skill based on task count
- Pro: Clean separation, SKILL.md stays focused
- Con: Code duplication, two skills to maintain

**Option C**: Refactor orchestrate.md to implement multi-task dispatch inline without spawning skill-orchestrate
- The orchestrate.md command itself manages the per-task state table and dispatches workers directly
- Pro: Eliminates skill invocation overhead entirely (O(0) skill context)
- Con: orchestrate.md becomes very complex, blurs command/skill boundary

**Recommendation: Option A** — extend the existing SKILL.md with a multi-task entry point. The skill is already the right abstraction level (not a user-facing command), and the existing single-task state machine code can be reused as the "per-task dispatch" primitive.

#### Multi-Task State Table Design

The single orchestrator tracks per-task state in a compact JSON file:

```json
// specs/.orchestrator-multi-state.json (created by the skill, not per-task)
{
  "session_id": "sess_...",
  "task_numbers": [42, 43, 44],
  "task_types": {"42": "neovim", "43": "general", "44": "general"},
  "task_dirs": {"42": "specs/042_...", "43": "specs/043_...", "44": "specs/044_..."},
  "current_statuses": {"42": "not_started", "43": "researched", "44": "planned"},
  "cycle_counts": {"42": 0, "43": 1, "44": 2},
  "failed_tasks": [],
  "completed_tasks": [],
  "dependency_graph": {"42": [], "43": [42], "44": [42]},
  "waves": [[42], [43, 44]]
}
```

This file replaces the per-task `.orchestrator-loop-guard` for multi-task mode. It is updated after each wave.

#### Multi-Task Stage Machine (New Stages in SKILL.md)

**Stage 0: Multi-task mode detection**

```bash
multi_task_mode=$(echo "$delegation_context" | jq -r '.multi_task_mode // false')
if [ "$multi_task_mode" = "true" ]; then
  # Jump to Multi-Task State Machine (Stage MT-1 through MT-8)
else
  # Fall through to existing Stage 1
fi
```

**Stage MT-1: Parse all task numbers**

```bash
task_numbers=$(echo "$delegation_context" | jq -r '.task_numbers | .[]')
dependency_graph=$(echo "$delegation_context" | jq -c '.dependency_graph')
waves=$(echo "$delegation_context" | jq -c '.waves')
```

**Stage MT-2: Build per-task routing table**

For each task_number, resolve RESEARCH_AGENT and IMPLEMENT_AGENT by task_type (reuse Stage 1b logic).

**Stage MT-3: Wave loop**

```
for each wave in waves:
  ready_tasks = [tasks in wave not yet completed or failed]
  
  # Phase dispatch: dispatch the SAME phase for all ready tasks in parallel
  # Determine phase for each task based on its current status
  # Group tasks by needed phase
  
  for each phase_group (research, plan, implement):
    dispatch all tasks needing this phase as parallel Agent calls
  
  # After all parallel dispatches complete:
  for each task in wave:
    read .orchestrator-handoff.json
    call skill_postflight_update(task, phase, session_id, status)
    if artifact_path:
      call skill_link_artifacts(task, artifact_path, ...)
    update multi-state.json
  
  # Advance tasks that completed one phase but need another
  # A research->plan->implement sequence requires multiple sub-waves within a wave
```

**Critical complication**: Tasks in the same wave may need different phases (task A is at `not_started`, task B is at `researched`). They cannot all be dispatched to the same agent type simultaneously. The orchestrator must either:

1. **Phase-synchronize**: Run all tasks in a wave through research first, then planning, then implementation. This means sub-waves within each wave.
2. **Status-aware dispatch**: For each task, dispatch to the appropriate next phase agent, regardless of other tasks in the wave. Tasks in the same wave are independent, so they can be at different phases.

**Option 2 is correct**: Tasks within a wave are independent. They can proceed at their own pace. The wave constraint only applies between waves (inter-task dependencies). Within a wave, dispatch each task to its needed agent type.

#### Revised Wave Execution Logic

```
for each wave in waves:
  active_tasks = tasks in wave (not completed, not failed, not blocked)
  
  while active_tasks:
    # Group by needed phase
    research_tasks = [t for t in active_tasks if status[t] in (not_started)]
    plan_tasks = [t for t in active_tasks if status[t] == "researched"]
    implement_tasks = [t for t in active_tasks if status[t] in (planned, implementing)]
    
    # Dispatch all groups in parallel (parallel Agent calls)
    for t in research_tasks: Agent(RESEARCH_AGENT[t], task=t)
    for t in plan_tasks: Agent("planner-agent", task=t)
    for t in implement_tasks: Agent(IMPLEMENT_AGENT[t], task=t)
    
    # After all dispatches complete, read handoffs and update
    for each dispatched task t:
      read .orchestrator-handoff.json for t
      call skill_postflight_update(t, ...)
      call skill_link_artifacts(t, ...) if artifact exists
      update active_tasks (remove if completed/failed)
    
    cycle_count++
    if cycle_count >= MAX_CYCLES: EXIT partial
```

This structure allows tasks in the same wave to be at different lifecycle phases and proceed at their own pace, without blocking each other.

#### TODO.md Synchronization Gaps (Current vs Required)

| Operation | Current (single-task) | Current (multi-task) | Required (new multi-task) |
|-----------|----------------------|---------------------|--------------------------|
| Status update (state.json) | skill_postflight_update via Stage 5 | Each skill-orchestrate instance | skill_postflight_update per task after each phase |
| Status update (TODO.md entry) | skill_postflight_update via Stage 5 | Each skill-orchestrate instance | skill_postflight_update per task after each phase |
| Artifact link (TODO.md) | Missing from SKILL.md | Each skill-orchestrate instance | skill_link_artifacts per task after each phase |
| Artifact link (state.json) | Missing from SKILL.md | Each skill-orchestrate instance | skill_link_artifacts per task after each phase |

The critical finding is that `skill_link_artifacts()` is currently NOT called from within `skill-orchestrate/SKILL.md`. It is called from within the individual skill wrappers (skill-researcher, skill-planner, skill-implementer) that are bypassed in orchestrator_mode. The task description confirms this is a bug to fix.

However, re-reading the agent architecture more carefully: when `orchestrator_mode=true` is passed in the delegation_context, the research/plan/implement agents themselves may still call `skill_link_artifacts()` via their own postflight. The question is whether the research agent SKILL.md calls `skill_link_artifacts()` or if that lives in the skill wrapper.

Looking at skill-base.sh: `skill_link_artifacts()` is defined there and called by skills (not agents). The agents write `.return-meta.json`; the skills read it and call `skill_link_artifacts()`. Since SKILL.md bypasses skills and invokes agents directly, artifact linking is indeed missing.

**Fix needed in SKILL.md**: After reading each handoff in Stage 5, extract the artifact path and type from the handoff's `artifacts` array, then call `skill_link_artifacts()`.

#### Specific Changes Needed

**1. skill-orchestrate/SKILL.md Stage 5 (both single-task fix and multi-task)**

After the existing `skill_postflight_update()` case statement, add:

```bash
# Extract artifact from handoff and link to TODO.md
handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
if [ -n "$handoff_artifact_path" ] && [ -n "$handoff_artifact_type" ]; then
  source .claude/scripts/skill-base.sh
  case "$handoff_artifact_type" in
    report)   field_name="**Research**"; next_field="**Plan**" ;;
    plan)     field_name="**Plan**";     next_field="**Description**" ;;
    summary)  field_name="**Summary**";  next_field="**Description**" ;;
  esac
  skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
    "" "$field_name" "$next_field"
fi
```

**2. orchestrate.md MULTI-TASK DISPATCH Step 4 — change dispatch target**

Currently:
```
Skill("skill-orchestrate", args="task_number={N} ...")
```

Change to:
```
Skill("skill-orchestrate", args="task_numbers={ALL} dependency_graph={...} waves={...} multi_task_mode=true session_id=... focus_prompt=...")
```

This dispatches a SINGLE skill-orchestrate invocation that receives all task numbers and the pre-computed dependency graph.

**3. skill-orchestrate/SKILL.md — New multi-task entry (Stage 0 + Stages MT-1 through MT-8)**

Add a multi-task mode detection at the very beginning (before Stage 1), which branches to a new multi-task state machine. The multi-task state machine:
- Parses all task numbers and waves from delegation_context
- Runs wave-by-wave, dispatching tasks to phase-specific agents
- Calls `skill_postflight_update()` and `skill_link_artifacts()` per task after each phase
- Maintains a compact multi-state JSON for loop guard purposes
- Exits when all tasks complete, fail, or MAX_CYCLES is reached

#### Token Overhead Analysis

| Mode | Skill invocations | Context per invocation | Total skill context |
|------|-------------------|-----------------------|---------------------|
| Current multi-task (N=5) | 5 | 44k | 220k |
| Proposed multi-task (N=5) | 1 | 44k | 44k |
| Single-task (N=1) | 1 | 44k | 44k |

Reduction for N tasks: from N*44k to 44k, saving (N-1)*44k tokens.

Additional savings: the orchestrator accumulates context as it dispatches workers. In the current model, each of the N skill-orchestrate instances accumulates ~450 tokens per cycle separately. In the proposed model, the single orchestrator accumulates across all tasks. For N=5 tasks, 3 phases each: current=5*3*450=6750 tokens per wave; proposed=1*(5*3)*450=6750 tokens (same, since the single agent sees all handoffs). No savings here — the accumulation is the same.

The main savings are in the skill invocation overhead itself (N*44k → 44k).

#### Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md becomes too large/complex | M | M | Keep multi-task code in a clearly delimited section; add Stage 0 branch |
| Parallel Agent calls in multi-task mode hit tool concurrency limits | H | M | Limit wave parallelism to max 4 concurrent agents; batch if N > 4 |
| Per-task state tracking in multi-state.json corrupted by partial writes | H | L | Use atomic write pattern (write to .tmp then mv) |
| Tasks at different phases within a wave cause interleaving complexity | M | M | Use clear while-loop with phase grouping; document carefully |
| Single orchestrator context grows unbounded for large N | M | M | Enforce MAX_TASKS_PER_ORCHESTRATOR=8 (orchestrate.md splits into batches if N > 8) |
| skill_link_artifacts missing from single-task SKILL.md (pre-existing bug) | M | H | Fix in Stage 5 regardless of multi-task refactor |
| Backward compatibility: orchestrate.md must still work for single task | L | L | Stage 0 detects `len == 1` and falls through to old single-task path |

## Decisions

1. **Extend existing SKILL.md** rather than creating a new skill — lower maintenance overhead
2. **Fix artifact linking (skill_link_artifacts) in Stage 5** of existing SKILL.md as part of this task — it's a pre-existing bug that affects single-task orchestration
3. **Delegate multi-task mode detection to SKILL.md Stage 0** — orchestrate.md simply passes `multi_task_mode=true` and the pre-computed waves; skill handles the dispatch loop
4. **Phase-aware parallel dispatch** within each wave — tasks at different lifecycle phases are dispatched to their appropriate agent type in parallel
5. **Use a multi-state JSON file** for tracking per-task state — small enough to read at each cycle without violating context flatness
6. **MAX_TASKS cap at orchestrate.md level** — if N > 8 (or configurable), split into batches to prevent single-agent context explosion

## Risks & Mitigations

See risk table in Findings section above. Primary risks:
- Tool concurrency limits for parallel Agent calls in large waves
- Context growth in single orchestrator for large N (>8 tasks)
- Complexity of phase-aware dispatch logic in SKILL.md

## Context Extension Recommendations

- **Topic**: Orchestrator multi-task state machine patterns
- **Gap**: No documentation on how skill-orchestrate handles multi-task mode once it's implemented
- **Recommendation**: Create `.claude/docs/architecture/orchestrate-multi-task.md` documenting the multi-state JSON schema, wave execution algorithm, and per-task dispatch patterns after implementation is complete

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — Full state machine (Stages 1-8)
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` — Command file with STAGE 0 + MULTI-TASK DISPATCH
- `/home/benjamin/.config/nvim/.claude/scripts/dispatch-agent.sh` — dispatch_agent(), invoke_named_agent(), invoke_agent_fork()
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — skill_postflight_update(), skill_link_artifacts(), skill_write_orchestrator_handoff()
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` — Atomic state.json + TODO.md status update
- `/home/benjamin/.config/nvim/.claude/scripts/link-artifact-todo.sh` — Four-case TODO.md artifact link insertion
- `/home/benjamin/.config/nvim/specs/623_orchestrate_multi_task_dispatch/plans/01_multi-task-orchestrate-plan.md` — Task 623 plan confirming SKILL.md was not modified
- `/home/benjamin/.config/nvim/specs/624_orchestrate_postflight_status_sync/summaries/01_postflight-sync-summary.md` — Task 624 summary confirming skill_postflight_update was added to SKILL.md Stage 5

### Key Architectural Facts

- `skill_postflight_update()` is sourced from skill-base.sh and is already in SKILL.md (added in task 624)
- `skill_link_artifacts()` is NOT currently called from SKILL.md — this is the TODO.md artifact linking gap
- orchestrate.md STAGE 0 uses `parse-command-args.sh` and has single-task fallthrough at `len == 1`
- The multi-task dispatch in orchestrate.md dispatches skill-orchestrate once per task; the refactor reduces this to one dispatch total
- Context flatness constraint must still be respected: SKILL.md reads only handoff JSON, not full artifacts
