# Research Report: Task #350

**Task**: 350 - multi_task_operations_pattern
**Started**: 2026-04-02T12:00:00Z
**Completed**: 2026-04-02T12:30:00Z
**Effort**: Small-Medium
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of commands, skills, agents, and existing patterns
**Artifacts**: specs/350_multi_task_operations_pattern/reports/01_multi-task-ops.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `parse_ranges()` function in `routing.md` already handles `"7, 22-24, 59"` style range parsing for `/task --recover` and `/task --abandon` operations
- Workflow commands (`/research`, `/plan`, `/implement`) currently accept exactly one task number, then parse optional flags (`--team`, `--force`) and focus prompts
- The existing team-orchestration pattern (wave-based parallel agent spawning) provides the parallel execution model to adapt
- A new "STAGE 0: PARSE TASK NUMBERS" can be inserted before GATE IN, with single-task falling through unchanged and multi-task spawning parallel agents
- Each parallel agent runs the full single-task command flow independently, with results collected for batch commit and consolidated output

## Context and Scope

This research investigates how to extend `/research`, `/plan`, and `/implement` commands to accept multiple task numbers (e.g., `/research 7, 22-24, 59`) while maintaining full backward compatibility with single-task usage. The pattern document to be created at `.claude/context/patterns/multi-task-operations.md` must define argument parsing, parallel dispatch, batch commits, consolidated output, and partial-success error handling.

## Findings

### 1. Existing Range Parsing (`parse_ranges()`)

Found in `routing.md` lines 266-296, the `parse_ranges()` function already implements the exact parsing logic needed:

```bash
parse_ranges() {
  local ranges="$1"
  local task_numbers=()

  IFS=',' read -ra parts <<< "$ranges"

  for part in "${parts[@]}"; do
    part=$(echo "$part" | tr -d ' ')  # Trim whitespace

    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      for ((i=start; i<=end; i++)); do
        task_numbers+=("$i")
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      task_numbers+=("$part")
    else
      echo "[FAIL] Invalid range format: $part"
      exit 1
    fi
  done

  printf '%s\n' "${task_numbers[@]}" | sort -nu
}
```

This function is used by `/task --recover`, `/task --abandon`, and `/task --sync`. It handles:
- Single numbers: `343`
- Ranges: `343-345`
- Comma-separated lists: `337, 343-345, 350`
- Deduplication and sorting

**Key observation**: The function outputs sorted, deduplicated task numbers. This is suitable for multi-task operations but the sort order may need consideration -- for `/research`, tasks might benefit from processing in dependency order rather than numeric order.

### 2. Current Single-Task Command Flow

All three workflow commands follow identical structure:

```
CHECKPOINT 1: GATE IN
  1. Generate session_id
  2. Lookup task via jq (single task_number)
  3. Validate status
  4. Load context (plan file for /implement)

STAGE 1.5: PARSE FLAGS
  1. Extract --team, --team-size, --force
  2. Extract focus_prompt (remaining text)

STAGE 2: DELEGATE
  1. Determine skill by language + flags
  2. Invoke Skill tool with task_number and args
  3. Skill spawns agent via Task tool

CHECKPOINT 2: GATE OUT
  1. Validate return
  2. Verify artifacts on disk
  3. Verify status updated

CHECKPOINT 3: COMMIT
  1. git add -A && git commit
```

**Critical detail**: The command files (`.claude/commands/research.md`, etc.) are markdown instruction files interpreted by Claude Code at command invocation time. They are NOT executable scripts. The "Skill tool" invocation is a Claude Code tool call that loads and executes a skill definition.

**Implication for multi-task**: The command file itself performs GATE IN, then delegates to a Skill. For multi-task, the command file would need to perform GATE IN for each task and invoke multiple Skills (or a single batch-aware skill). However, the Skill tool does not support parallel invocation from command files -- skills are invoked sequentially.

### 3. Agent Spawning Mechanism

The current delegation chain is:

```
Command -> Skill tool -> Skill (SKILL.md) -> Task tool -> Agent
```

Key findings about the Task tool:
- Skills invoke agents via the **Task** tool (NOT the Agent tool referenced in the task description)
- The Task tool spawns a subagent with a specific prompt
- Multiple Task tool calls CAN be made in parallel within a single message
- The team-orchestration pattern (`team-orchestration.md`) already demonstrates parallel agent spawning

From `skill-researcher/SKILL.md` Stage 5:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-research-agent"
  - prompt: [delegation context]
  - description: "Execute research for task {N}"
```

**Team mode precedent**: The `skill-team-research` and related team skills already spawn multiple agents in parallel. The wave-based model groups independent work into waves and executes agents concurrently within each wave.

### 4. Current Argument Parsing

Commands currently parse arguments as:
```
$ARGUMENTS = "TASK_NUMBER [FOCUS_PROMPT] [--team] [--team-size N] [--force]"
```

The task number is always the first argument, extracted via:
```bash
task_number=$(echo "$ARGUMENTS" | awk '{print $1}')
```

For multi-task, this needs to change. The challenge is distinguishing between:
- `/research 7, 22-24, 59` (multi-task with ranges)
- `/research 7 focus on API design` (single task with focus prompt)
- `/research 7, 22-24 --team` (multi-task with flags)

### 5. Git Commit Patterns

Current per-task commit:
```
task {N}: complete research

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

For multi-task, a batch commit format is needed. The `/task --recover` and `--abandon` commands already use a batch pattern:
```
task: recover tasks {ranges}
task: abandon tasks {ranges}
```

## Proposed Pattern Design

### STAGE 0: PARSE TASK NUMBERS

Insert before existing GATE IN. This stage parses the raw argument string to extract task numbers and remaining arguments.

**Algorithm**:

```
Input: $ARGUMENTS (raw string)

1. Scan from left, consuming characters that are:
   - Digits [0-9]
   - Commas [,]
   - Hyphens [-] between digits
   - Whitespace adjacent to above

2. Stop consuming when encountering:
   - An alphabetic character [a-zA-Z]
   - A flag marker [--]
   - End of input

3. Parse consumed portion through parse_ranges()
4. Remaining portion becomes $REMAINING_ARGS

Result:
  - task_numbers[] = sorted, deduplicated array
  - remaining_args = flags and focus prompt
```

**Pseudocode**:

```bash
parse_task_args() {
  local input="$1"
  local task_spec=""
  local remaining=""

  # Match leading task specification: digits, commas, hyphens, spaces
  # Stop at first alphabetic char or -- flag
  if [[ "$input" =~ ^([0-9][0-9,\ \-]*)(\ +.*)?$ ]]; then
    task_spec="${BASH_REMATCH[1]}"
    remaining="${BASH_REMATCH[2]}"
  else
    echo "[FAIL] No task number found in arguments"
    return 1
  fi

  # Trim trailing whitespace/commas from task_spec
  task_spec=$(echo "$task_spec" | sed 's/[, ]*$//')

  # Parse through existing parse_ranges()
  task_numbers=($(parse_ranges "$task_spec"))

  # Trim leading whitespace from remaining
  remaining=$(echo "$remaining" | sed 's/^[[:space:]]*//')

  echo "TASK_NUMBERS=${task_numbers[*]}"
  echo "REMAINING_ARGS=$remaining"
}
```

**Examples**:

| Input | task_numbers | remaining_args |
|-------|-------------|----------------|
| `7` | `[7]` | `` |
| `7, 22-24, 59` | `[7, 22, 23, 24, 59]` | `` |
| `7 focus on APIs` | `[7]` | `focus on APIs` |
| `7, 22-24 --team` | `[7, 22, 23, 24]` | `--team` |
| `42 --team --team-size 3` | `[42]` | `--team --team-size 3` |

### Dispatch Decision

```
if len(task_numbers) == 1:
    # SINGLE-TASK MODE: Fall through to existing flow unchanged
    task_number = task_numbers[0]
    # Continue to GATE IN -> DELEGATE -> GATE OUT -> COMMIT

elif len(task_numbers) > 1:
    # MULTI-TASK MODE: Parallel dispatch
    # Continue to MULTI-TASK DISPATCH below
```

### MULTI-TASK DISPATCH

When multiple task numbers are detected:

**Step 1: Validate All Tasks (Sequential)**

Before spawning any agents, validate all tasks exist and have valid status:

```bash
validated_tasks=()
invalid_tasks=()

for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    invalid_tasks+=("$task_num: not found")
    continue
  fi

  status=$(echo "$task_data" | jq -r '.status')
  # Check status allows operation (varies by command)
  if ! status_allows_operation "$status" "$command"; then
    invalid_tasks+=("$task_num: invalid status [$status]")
    continue
  fi

  validated_tasks+=("$task_num")
done

# Report invalid tasks but continue with valid ones
if [ ${#invalid_tasks[@]} -gt 0 ]; then
  echo "[WARN] Skipping invalid tasks:"
  for msg in "${invalid_tasks[@]}"; do
    echo "  - $msg"
  done
fi

if [ ${#validated_tasks[@]} -eq 0 ]; then
  echo "[FAIL] No valid tasks to process"
  exit 1
fi
```

**Step 2: Generate Batch Session ID**

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Step 3: Spawn Parallel Agents**

For each validated task, invoke the appropriate Skill tool. The command file would include multiple Skill tool invocations in a single response:

```
# All invoked in parallel (multiple tool calls in one message)
For each task_num in validated_tasks:
  Skill: "{skill_name}"
  args: "task_number={task_num} session_id={batch_session_id}_{task_num} {remaining_args}"
```

**Important constraint**: The Skill tool invocations happen at the command level. Each Skill call internally manages its own lifecycle (preflight status update, agent delegation via Task tool, postflight status update). This means each task gets full lifecycle management independently.

**Alternative approach**: Instead of multiple Skill tool calls from the command, create a new `skill-batch-{command}` skill that receives the full task list and internally spawns multiple Task tool agents in parallel (similar to `skill-team-research`). This is more architecturally consistent with the existing pattern where commands invoke exactly one skill.

**Recommended approach**: The batch skill pattern. Create `skill-batch-dispatch` (or integrate batch logic into `skill-orchestrator`) that:
1. Receives task list and command type
2. Validates all tasks
3. Spawns one agent per task via parallel Task tool calls
4. Collects results
5. Produces batch status report

### Batch Commit Format

After all agents complete, produce a single batch commit:

```
{command} tasks {range_summary}: {action}

Tasks: {comma-separated list}
Session: {batch_session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

Examples:
```
research tasks 7, 22-24, 59: complete research

Tasks: 7, 22, 23, 24, 59
Session: sess_1743523200_abc123

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

**Partial success commit**:
```
research tasks 7, 22-24: complete research (3/4 succeeded)

Tasks completed: 7, 22, 24
Tasks failed: 23 (invalid status [IMPLEMENTING])
Session: sess_1743523200_abc123

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

### Consolidated Output Format

```
## Batch {Command} Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | task_title | [RESEARCHED] | specs/007_slug/reports/01_short.md |
| #22 | task_title | [RESEARCHED] | specs/022_slug/reports/01_short.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Invalid status [IMPLEMENTING] |

### Next Steps
- /plan 7, 22, 24, 59
```

### Error Handling: Partial Success

The multi-task pattern must handle partial success gracefully:

**Principle**: Failure of one task must not block or roll back other tasks.

**Status tracking**:
```json
{
  "batch_session_id": "sess_...",
  "results": [
    {"task": 7, "status": "researched", "artifact": "..."},
    {"task": 22, "status": "researched", "artifact": "..."},
    {"task": 23, "status": "failed", "error": "Agent timeout"},
    {"task": 24, "status": "researched", "artifact": "..."}
  ],
  "summary": {
    "total": 4,
    "succeeded": 3,
    "failed": 1
  }
}
```

**Error categories**:

| Error | Handling | Recovery |
|-------|----------|----------|
| Task not found | Skip, report in output | User creates task first |
| Invalid status | Skip, report in output | User fixes status |
| Agent timeout | Mark partial, report | User re-runs single task |
| Agent failure | Keep "in progress" status | User re-runs single task |
| Git conflict | Non-blocking, log | Manual resolution |

**Important**: Each agent manages its own task's state independently. If agent for task 23 fails, task 23's status remains "researching" while tasks 7, 22, 24 transition to "researched". The batch commit only includes changes from successful tasks.

### Backward Compatibility Analysis

The proposed pattern is fully backward compatible:

1. **Single task number** (`/research 7`): Falls through STAGE 0 with `task_numbers = [7]`, proceeds to existing single-task flow unchanged
2. **Single task with focus** (`/research 7 focus on APIs`): Parser correctly separates `7` from `focus on APIs`
3. **Single task with flags** (`/research 7 --team`): Parser correctly separates `7` from `--team`
4. **Existing /task --recover ranges**: Unaffected -- different command with flag-based routing

**Edge cases to handle**:
- `/research 7-7` should normalize to `[7]` (single task)
- `/research 7,7,7` should deduplicate to `[7]` (single task)
- Ranges producing single task should use single-task flow

### Flag Compatibility with Multi-Task

| Flag | Multi-task behavior |
|------|---------------------|
| `--team` | Applied to ALL tasks in batch (each task gets team mode) |
| `--team-size N` | Applied to ALL tasks uniformly |
| `--force` | Applied to ALL tasks |
| Focus prompt | Applied to ALL tasks (same focus for each) |

**Note**: Per-task flags (e.g., different focus per task) are NOT supported in this pattern. Users wanting different configurations per task should run separate commands.

### Architecture Decision: Command-Level vs Skill-Level Dispatch

Two approaches were considered:

**Option A: Command-level dispatch (multiple Skill calls)**
```
Command -> [Skill(task 7), Skill(task 22), Skill(task 24)]
```
- Pro: Simpler, reuses existing skills unchanged
- Con: Command markdown becomes more complex
- Con: No centralized result collection
- Con: Commit happens per-skill (not batched)

**Option B: Batch skill dispatch (single skill, multiple agents)**
```
Command -> Skill(skill-batch-dispatch) -> [Task(agent, task 7), Task(agent, task 22), Task(agent, task 24)]
```
- Pro: Centralized result collection and batch commit
- Pro: Consistent with team-mode pattern (single skill entry point)
- Pro: Commands stay simple (single Skill call)
- Con: New skill to create

**Recommendation**: Option B (batch skill dispatch). This is consistent with the existing architecture where commands invoke exactly one skill, and the team-mode precedent where a single skill orchestrates multiple agents.

### Implementation Scope

The pattern document should be sufficient for implementing:

1. **`parse_task_args()`** -- Shared argument parsing function (inline in pattern doc)
2. **STAGE 0** -- Inserted into `/research`, `/plan`, `/implement` command files
3. **Batch dispatch** -- Either integrated into existing skills or via new batch skill
4. **Batch commit format** -- Extension of existing git-workflow conventions
5. **Consolidated output** -- New output format for multi-task results

### Interaction with `--team` Flag

Multi-task and team mode are orthogonal features:
- Multi-task: Run same command on multiple tasks (horizontal scaling across tasks)
- Team mode: Run multiple agents on a single task (vertical scaling within a task)

Combining both (`/research 7, 22, 24 --team`) would spawn `N * team_size` total agents. This should work but may be expensive. The pattern document should note this cost multiplication.

## Decisions

1. **Use Option B (batch skill dispatch)** for centralized result collection and batch commits
2. **Reuse `parse_ranges()`** from routing.md with a wrapper for argument separation
3. **Single task falls through** to existing flow -- no performance penalty for common case
4. **Partial success is the norm** -- never roll back successful tasks due to other failures
5. **Flags apply uniformly** -- no per-task configuration in multi-task mode

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Concurrent state.json writes from parallel agents | State corruption | Each agent writes its own task's fields; jq operations are scoped to specific project_number |
| Token cost multiplication with `--team` + multi-task | High token usage | Document cost warning; consider max-task limit |
| Argument parsing ambiguity (`7-9` as range vs `7 -9` as task + negative) | Incorrect parsing | Require comma separation for ranges; hyphens only valid between digits |
| Parallel agent failures cascade | Partial results lost | Independent lifecycle per task; failures isolated |
| Git merge conflicts from parallel commits | Commit failure | Single batch commit after all agents complete (not per-agent commits) |

## Appendix

### Files Examined

1. `.claude/context/orchestration/routing.md` -- `parse_ranges()` function, argument parsing patterns
2. `.claude/commands/task.md` -- `--recover` and `--abandon` range handling, task lifecycle
3. `.claude/commands/research.md` -- Single-task GATE IN -> DELEGATE -> GATE OUT -> COMMIT flow
4. `.claude/commands/plan.md` -- Same checkpoint pattern, team mode routing
5. `.claude/commands/implement.md` -- Same checkpoint pattern, `--force` flag
6. `.claude/context/patterns/checkpoint-execution.md` -- Checkpoint model reference
7. `.claude/context/patterns/team-orchestration.md` -- Wave-based parallel agent spawning
8. `.claude/context/patterns/skill-lifecycle.md` -- Self-contained skill lifecycle
9. `.claude/context/patterns/thin-wrapper-skill.md` -- Skill delegation pattern
10. `.claude/skills/skill-researcher/SKILL.md` -- Concrete example of Task tool agent spawning

### Pattern Document Outline

The implementation plan should produce `.claude/context/patterns/multi-task-operations.md` with these sections:

1. Overview and motivation
2. Argument parsing specification (with `parse_task_args()`)
3. Single-task fallthrough behavior
4. Multi-task dispatch flow (STAGE 0 + batch skill)
5. Parallel agent spawning (Task tool calls)
6. Result collection and status tracking
7. Batch git commit format
8. Consolidated output format
9. Partial-success error handling
10. Interaction with `--team` mode
11. Backward compatibility guarantees
12. Command file modification guide (for /research, /plan, /implement)
