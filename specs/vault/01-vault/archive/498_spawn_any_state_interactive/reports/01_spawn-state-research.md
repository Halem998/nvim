# Research Report: Task #498

**Task**: 498 - Make /spawn work from any non-terminal state with interactive confirmation
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase, spawn.md, skill-spawn/SKILL.md, spawn-agent.md, status-markers.md, state-management.md, checkpoint-gate-in.md, fix-it.md, review.md, meta-builder-agent.md, multi-task-creation-standard.md
**Artifacts**: - specs/498_spawn_any_state_interactive/reports/01_spawn-state-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Current /spawn blocks `researching` and `planning` statuses**, but system-wide standards define these as non-terminal states that should allow any command.
- **Six files need coordinated changes** across `.opencode/` and `.claude/` trees (commands, skills, agents).
- **Spawn-agent needs a new "holistic analysis" mode** for non-blocked tasks, with AskUserQuestion interactive confirmation before creating tasks.
- **Skill-spawn must conditionally set parent status** -- only mark `[BLOCKED]` when the task is actually blocked; otherwise preserve the original status.
- **Pattern already exists** in `/fix-it`, `/review`, and `/meta` for interactive multiSelect confirmation using AskUserQuestion.

## Context & Scope

The task requires updating `/spawn` to work from any non-terminal state (removing the restriction on `researching` and `planning`), and updating `spawn-agent` to perform holistic task analysis with interactive confirmation when the task is not actually blocked.

### Files Under Study

| File | System | Role |
|------|--------|------|
| `commands/spawn.md` | Both (.opencode + .claude) | GATE IN status validation |
| `skills/skill-spawn/SKILL.md` | Both (.opencode + .claude) | Preflight status update, postflight task creation |
| `agents/spawn-agent.md` | Both (.opencode + .claude) | Blocker analysis and task decomposition |
| `context/standards/status-markers.md` | .opencode | Authoritative status definitions |
| `context/orchestration/state-management.md` | .opencode | Transition rules |
| `context/checkpoints/checkpoint-gate-in.md` | .opencode | Standard GATE IN pattern |

## Findings

### 1. Current Status Validation Table (spawn.md)

Both `.opencode/commands/spawn.md` and `.claude/commands/spawn.md` contain an identical status validation table at CHECKPOINT 1, Step 4:

| Status | Current Action |
|--------|---------------|
| `implementing`, `partial`, `blocked` | ALLOW - task is stuck |
| `planned`, `researched` | ALLOW - preemptive spawn |
| `completed` | ABORT "Task is already complete..." |
| `abandoned` | ABORT "Task is abandoned..." |
| `not_started` | ALLOW - may have discovered blocker before starting |
| `researching`, `planning` | **ABORT** "Task in progress. Wait for current phase to complete." |

**Problem**: This conflicts with the system-wide permissive rule.

### 2. Status Definitions (Terminal vs Non-Terminal)

From `context/standards/status-markers.md` (lines 283-288):

> **Permissive Rule**: Any command can run from any non-terminal status.
> **Terminal States** (block all transitions):
> - `[COMPLETED]` - No further transitions
> - `[ABANDONED]` - No further transitions
> - `[EXPANDED]` - No further transitions

From `context/orchestration/state-management.md` (lines 287-294):

> Any command can run from any non-terminal status. Only terminal states block transitions:
> ```
> Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]
> Any non-terminal status -> any command (research, plan, implement, revise)
> Any non-terminal status -> [BLOCKED] | [ABANDONED] | [EXPANDED]
> ```

From `context/checkpoints/checkpoint-gate-in.md` (lines 33-38):

> ```
> if status in [completed, abandoned, expanded]:
>   ABORT "Task is in terminal state [$status]"
> ```
> Any non-terminal status allows any operation (research, plan, implement, revise).

**Conclusion**: `researching`, `planning`, `revising`, `not_started`, `researched`, `planned`, `revised`, `implementing`, `partial`, and `blocked` are ALL non-terminal. `/spawn` should allow all of them.

### 3. Current spawn-agent Analysis Flow

Both `.opencode/extensions/core/agents/spawn-agent.md` and `.claude/agents/spawn-agent.md` implement an identical 7-stage flow:

**Stage 1**: Load Context (plan, reports, task data)
**Stage 2**: Analyze Blocker
  - If `blocker_prompt` provided: use it as primary signal
  - If not provided: infer from plan context (look for `[IN PROGRESS]`, `[PARTIAL]`, error notes)
  - Identify root cause category (Missing prerequisite, External dependency, Design ambiguity, Scope creep, Technical unknowns)
**Stage 3**: Decompose into Minimal Tasks (2-4 tasks max)
**Stage 4**: Write Blocker Analysis Report
**Stage 5**: Write `.spawn-return.json`
**Stage 6**: Update metadata to `researched`
**Stage 7**: Return brief summary

**Problem**: The agent is hardcoded for blocker analysis. When a task in `researching` or `planning` is spawned (e.g., to break down scope), there may be no actual blocker -- the user simply wants to decompose the task. The agent needs a holistic analysis mode.

### 4. Current skill-spawn Preflight Behavior

Both `skills/skill-spawn/SKILL.md` versions unconditionally update parent status to `blocked` in Stage 2:

> **Stage 2: Preflight Status Update**
> Update parent task status to "blocked" BEFORE invoking subagent.

And Stage 3 unconditionally updates TODO.md status to `[BLOCKED]`.

**Problem**: For non-blocked tasks (e.g., preemptive spawn from `researching`), marking the parent as `[BLOCKED]` is semantically incorrect.

### 5. AskUserQuestion Interactive Confirmation Patterns

The system has extensive, well-documented patterns for interactive confirmation:

**Pattern A: Task Type Selection** (from `/fix-it`)
```json
{
  "question": "Which task types should be created?",
  "header": "Task Types",
  "multiSelect": true,
  "options": [
    {"label": "fix-it task", "description": "..."},
    {"label": "TODO tasks", "description": "..."}
  ]
}
```

**Pattern B: Granularity Selection** (from `/review`)
```json
{
  "question": "How should selected groups be created as tasks?",
  "header": "Task Granularity",
  "multiSelect": false,
  "options": [
    {"label": "Keep as grouped tasks", "description": "Creates {N} tasks..."},
    {"label": "Expand into individual tasks", "description": "Creates {M} tasks..."}
  ]
}
```

**Pattern C: Multi-turn Interview** (from `meta-builder-agent`)
```json
{
  "question": "Can this be broken into smaller, independent tasks?",
  "header": "Task Breakdown",
  "options": [
    {"label": "Yes, there are multiple steps", "description": "3+ distinct tasks needed"},
    {"label": "No, it's a single focused change", "description": "1-2 tasks at most"}
  ]
}
```

**Pattern D: MultiSelect for Individual Items**
```json
{
  "question": "Which items should be created as tasks?",
  "header": "Task Selection",
  "multiSelect": true,
  "options": [
    {"label": "{item_title}", "description": "{item_context}"}
  ]
}
```

All patterns use `AskUserQuestion` with `options` array. The standard is:
- `multiSelect: true` when user can pick multiple items
- `multiSelect: false` for single-choice decisions
- Empty selection = graceful exit, no tasks created
- Always include descriptive `label` and `description` for each option

### 6. Holistic Task Analysis Patterns

The `meta-builder-agent` performs holistic analysis through a 7-stage interview workflow. Key relevant stages:

- **Stage 2 (GatherDomainInfo)**: Asks purpose, scope, affected components
- **Stage 3 (IdentifyUseCases)**: Asks if work can be broken down, captures task list
- **Stage 3.5 (TopicClustering)**: Automatically clusters related items
- **Stage 5 (DependencyMapping)**: Maps dependencies between tasks

This provides a model for how `spawn-agent` could conduct holistic analysis when not blocked: instead of "Analyze Blocker" -> "Decompose", it would be "Assess Task Holistically" -> "Identify Decomposition Opportunities" -> "Present Interactive Questions" -> "Create Tasks".

## Decisions

### Decision 1: Status Validation Rule
**Replace** the per-status table in `spawn.md` with the standard terminal-state check used by all other commands:

```
if status in [completed, abandoned, expanded]:
  ABORT "Task is in terminal state [$status]"
```

All other statuses ALLOW spawn.

### Decision 2: Parent Status on Non-Blocked Spawn
When spawning from a non-blocked task (status is NOT `blocked`, `implementing`, or `partial`), the parent task should **preserve its original status** rather than being forced to `[BLOCKED]`. The parent instead gets a new marker like `spawned_from` or simply has its `dependencies` updated to include the spawned tasks, while status remains unchanged.

Wait -- actually, looking more carefully at the system, if a task has dependencies, it effectively IS blocked by those dependencies. The status `blocked` is semantically correct when the task cannot proceed until dependencies complete. For a task in `researching` that spawns subtasks, it SHOULD become `blocked` because it now depends on spawned tasks.

However, the task description says: "Update spawn-agent to work without a blocker-focused analysis when the task is not actually blocked: instead, analyze the task holistically and present interactive questions to confirm what tasks to spawn."

So the parent should still transition to `[BLOCKED]` (because it now has dependencies), but the agent's analysis mode changes from "blocker-focused" to "holistic".

Revised Decision 2: Parent status still transitions to `[BLOCKED]` (consistent with the fact that the task now has uncompleted dependencies), but the analysis and user experience changes.

### Decision 3: Agent Analysis Mode Switch
The `spawn-agent` should detect whether the task is actually blocked:
- **Blocked mode** (status = `blocked`, `implementing`, `partial`, OR `blocker_prompt` is provided): Use existing blocker analysis flow.
- **Holistic mode** (status = `researching`, `planning`, `planned`, `researched`, `not_started`, AND no `blocker_prompt`): Perform holistic assessment of the task, identify natural decomposition points, and present AskUserQuestion confirmation.

### Decision 4: Interactive Confirmation Flow
For holistic mode, after proposing tasks, the agent must:
1. Present proposed tasks via AskUserQuestion with `multiSelect: true`
2. Allow user to select which tasks to create (or cancel)
3. Only write `.spawn-return.json` after confirmation

This mirrors the `/fix-it` and `/review` patterns.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Divergence between .opencode and .claude files | High | Edit both trees for every change; they are currently identical |
| Status `blocked` semantics confusion | Medium | Document clearly: `[BLOCKED]` means "has unmet dependencies", not "encountered an error" |
| Agent timeout during interactive questions | Low | AskUserQuestion is synchronous; user must respond before timeout |
| User cancels spawn after agent analysis | Low | Agent writes no `.spawn-return.json` on cancel; skill handles missing file gracefully |
| Breaking existing blocked-task spawn workflow | High | Keep existing blocker analysis path fully intact; only add holistic path |

## Recommended Changes

### File 1: `.opencode/commands/spawn.md` (and `.claude/commands/spawn.md`)

**Location**: CHECKPOINT 1, Step 4 (lines 55-68)

**Current**:
```markdown
4. **Validate Status Allows Spawn**
   Extract status and validate:
   ```bash
   status=$(echo "$task_data" | jq -r '.status')
   ```

   | Status | Action |
   |--------|--------|
   | `implementing`, `partial`, `blocked` | ALLOW - task is stuck |
   | `planned`, `researched` | ALLOW - preemptive spawn |
   | `completed` | ABORT "Task is already complete. Nothing to spawn." |
   | `abandoned` | ABORT "Task is abandoned. Recover it first with /task --recover {N}." |
   | `not_started` | ALLOW - may have discovered blocker before starting |
   | `researching`, `planning` | ABORT "Task in progress. Wait for current phase to complete." |
```

**Recommended**:
```markdown
4. **Validate Status Allows Spawn**
   Extract status and validate:
   ```bash
   status=$(echo "$task_data" | jq -r '.status')
   ```

   | Status Category | Action |
   |-----------------|--------|
   | Terminal (`completed`, `abandoned`, `expanded`) | ABORT "Task is in terminal state [$status]. Nothing to spawn." |
   | Non-terminal (all others) | ALLOW - /spawn works from any non-terminal state |

   **Rationale**: The system-wide permissive rule allows any command from any non-terminal status. Terminal states only: completed, abandoned, expanded.
```

**Also update**: The "Examples" section (line 238-241) to add an example for spawning from `researching`:
```markdown
### Spawn during research (break down scope)
```
/ spawn 150 scope is larger than expected, need to decompose
```
Spawns sub-tasks while research is still in progress.
```

### File 2: `.opencode/skills/skill-spawn/SKILL.md` (and `.claude/skills/skill-spawn/SKILL.md`)

**Location**: Stage 2 (Preflight Status Update), lines 62-78

**Current**: Unconditionally updates status to `blocked`.

**Recommended**: Add conditional logic. The parent task should transition to `blocked` because it now has dependencies, but we should note the original status for potential rollback:

```markdown
### Stage 2: Preflight Status Update

Determine if this is a blocker-driven spawn or a holistic decomposition:
- If `status` is `blocked`, `implementing`, or `partial` -> Blocker-driven spawn
- If `status` is any other non-terminal state -> Holistic decomposition

In both cases, update parent task status to `blocked` because the task now depends on spawned subtasks. Preserve `previous_status` in the task metadata for context.

**Update state.json**:
```bash
padded_num=$(printf "%03d" "$task_number")
previous_status=$(echo "$task_data" | jq -r '.status')

jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "blocked" \
   --arg prev "$previous_status" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    previous_status: $prev,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
```

**Location**: Stage 6 (Invoke Subagent), lines 151-162

**Recommended**: Add `analysis_mode` to delegation context:
```json
{
  "session_id": "...",
  "task_number": N,
  "task_data": { ... },
  "blocker_prompt": "...",
  "plan_path": "...",
  "analysis_mode": "blocker" | "holistic",  // <-- NEW
  "metadata_file_path": "..."
}
```

### File 3: `.opencode/extensions/core/agents/spawn-agent.md` (and `.claude/agents/spawn-agent.md`)

This is the most substantial change. The agent needs:

1. **Mode detection** at Stage 1
2. **Holistic analysis stage** as an alternative to Stage 2
3. **Interactive confirmation** before writing output files

**Recommended additions**:

**New section after Stage 1**:

```markdown
### Stage 1.5: Determine Analysis Mode

Based on task status and blocker prompt:

| Mode | Condition | Analysis Focus |
|------|-----------|---------------|
| `blocker` | `status` is `blocked`, `implementing`, or `partial` OR `blocker_prompt` is provided | Root cause of blocker |
| `holistic` | `status` is any other non-terminal state AND `blocker_prompt` is empty | Task decomposition opportunities |

Store `analysis_mode` for use in Stage 2.
```

**Revised Stage 2**:

```markdown
### Stage 2: Analyze (Blocker or Holistic)

#### Blocker Mode
[Keep existing Stage 2 content exactly as is]

#### Holistic Mode

**Assess the task holistically**:
1. Read the task description, plan, and any research reports
2. Identify natural decomposition points:
   - Are there multiple distinct components that could be implemented independently?
   - Are there prerequisite pieces of work that could be extracted?
   - Is the scope too large for a single implementation pass?
3. Determine if spawning is warranted (not all tasks should be decomposed)
4. If spawning is warranted, propose 2-4 minimal tasks following the Task Minimization Principle

**For each proposed task**, determine the same fields as blocker mode (index, title, description, effort, task_type, dependencies).
```

**New Stage 3.5: Interactive Confirmation (Holistic Mode Only)**

```markdown
### Stage 3.5: Interactive Confirmation

**If analysis_mode == "holistic"**: Present proposed tasks to the user for confirmation before creating them.

**Use AskUserQuestion**:
```json
{
  "question": "Which of these proposed tasks should be created?",
  "header": "Spawn Proposals for Task #{N}",
  "multiSelect": true,
  "options": [
    {
      "label": "{task_title}",
      "description": "{effort} | {rationale_summary}"
    }
  ]
}
```

**Selection handling**:
- Empty selection: Write `.spawn-return.json` with `new_tasks: []`, set status to `cancelled`, return "No tasks selected. Spawn cancelled."
- Any selection: Proceed to Stage 4 with only the selected tasks.

**If analysis_mode == "blocker"**: Skip this stage and proceed directly to Stage 4 (existing behavior).
```

**Note**: The `.spawn-return.json` schema needs a small extension to handle the cancelled case, or the skill needs to handle an empty `new_tasks` array gracefully.

### File 4: `.opencode/skills/skill-spawn/SKILL.md` Postflight Empty-Tasks Handling

**Location**: Stage 7 (Read Return Metadata)

**Current**: Exits with error if spawn return file is missing or invalid.

**Recommended**: Handle empty `new_tasks` array gracefully:

```bash
if [ -f "$spawn_file" ] && jq empty "$spawn_file" 2>/dev/null; then
    new_tasks=$(jq -r '.new_tasks' "$spawn_file")
    task_count=$(jq '.new_tasks | length' "$spawn_file")
    
    if [ "$task_count" -eq 0 ]; then
        echo "Spawn cancelled: no tasks selected."
        # Cleanup and restore parent status if needed
        exit 0
    fi
    
    dependency_order=$(jq -r '.dependency_order' "$spawn_file")
    analysis_summary=$(jq -r '.analysis_summary' "$spawn_file")
    report_path=$(jq -r '.report_path' "$spawn_file")
else
    echo "Error: Invalid or missing spawn return file"
    exit 1
fi
```

## Context Extension Recommendations

- **Topic**: Spawn command behavior from non-terminal states
- **Gap**: The `commands/spawn.md` currently documents a restricted status table that contradicts the system-wide permissive rule in `status-markers.md` and `state-management.md`.
- **Recommendation**: After implementing Task 498, update `commands/spawn.md` to reference the standard terminal-state check pattern and add a note cross-referencing `status-markers.md` for the canonical status definitions.

## Appendix

### Search Queries Used
- Read `.opencode/commands/spawn.md`, `.claude/commands/spawn.md`
- Read `.opencode/skills/skill-spawn/SKILL.md`, `.claude/skills/skill-spawn/SKILL.md`
- Read `.opencode/extensions/core/agents/spawn-agent.md`, `.claude/agents/spawn-agent.md`
- Read `.opencode/context/standards/status-markers.md`
- Read `.opencode/context/orchestration/state-management.md`
- Read `.opencode/context/checkpoints/checkpoint-gate-in.md`
- Read `.opencode/extensions/core/commands/fix-it.md` (AskUserQuestion patterns)
- Read `.opencode/extensions/core/commands/review.md` (interactive selection patterns)
- Read `.opencode/extensions/core/agents/meta-builder-agent.md` (holistic analysis/interview patterns)
- Read `.opencode/docs/reference/standards/multi-task-creation-standard.md`
- Read `.opencode/commands/task.md` (`--expand` mode for comparison)

### References
- `status-markers.md` lines 283-288: Permissive Rule
- `state-management.md` lines 287-294: Terminal states definition
- `checkpoint-gate-in.md` lines 33-38: Standard GATE IN pattern
- `multi-task-creation-standard.md` lines 52-83: Interactive Selection pattern
- `spawn-agent.md` lines 38-56: Current Stage 2 blocker analysis
