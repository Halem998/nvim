# Research Report: Task #623

**Task**: 623 - Add multi-task argument support to /orchestrate command with dependency-aware execution ordering
**Started**: 2026-06-01T18:05:00Z
**Completed**: 2026-06-01T18:20:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/commands/orchestrate.md` — current single-task orchestrate command
- `.claude/skills/skill-orchestrate/SKILL.md` — autonomous state machine skill
- `.claude/commands/research.md` — multi-task dispatch reference
- `.claude/commands/plan.md` — multi-task dispatch reference
- `.claude/commands/implement.md` — multi-task dispatch reference
- `.claude/context/patterns/multi-task-operations.md` — the canonical pattern specification
- `.claude/scripts/parse-command-args.sh` — argument parser
- `specs/state.json` — task state with dependencies field
**Artifacts**: `specs/623_orchestrate_multi_task_dispatch/reports/01_multi-task-orchestrate.md`
**Standards**: report-format.md

---

## Executive Summary

- `/orchestrate` currently accepts exactly one task number. Adding multi-task support follows the same STAGE 0 parse-and-dispatch pattern used by `/research`, `/plan`, and `/implement`, but with a critical difference: `skill-orchestrate` drives a task through its *entire lifecycle*, so task dependencies must be respected during dispatch.
- The `dependencies` field in `state.json` is an array of task numbers (integers). Tasks 621 and 622 both depend on 620, demonstrating the field is already in production use.
- The topological wave dispatch model groups tasks into waves based on dependency resolution. Wave 0 = tasks with no intra-batch dependencies; Wave N+1 = tasks whose predecessors all completed in earlier waves. Each wave runs in parallel (concurrent `skill-orchestrate` invocations); the next wave starts only after all tasks in the current wave complete or fail.
- The `skill-orchestrate` SKILL.md stays single-task — all multi-task logic lives in `orchestrate.md`.
- Four files need modification: `orchestrate.md` (primary), `multi-task-operations.md` (document orchestrate section), `.claude/CLAUDE.md` (update command table syntax).

---

## Context & Scope

Task 623 extends the `/orchestrate` command from single-task to multi-task with dependency-aware wave dispatch. Unlike `/research`, `/plan`, and `/implement` — which operate on a single lifecycle phase and can safely run all tasks in parallel — `/orchestrate` drives tasks through their *entire lifecycle* (research → plan → implement → complete). This means if task B depends on task A (task A's output is needed as input for task B), running them in parallel would be incorrect: B would start researching before A has completed anything.

The scope is:
1. **`orchestrate.md`** — STAGE 0 argument parsing + MULTI-TASK DISPATCH section (new)
2. **`multi-task-operations.md`** — New "Orchestrate-Specific Behavior" section documenting the wave model
3. **`.claude/CLAUDE.md`** — Command table row update to show `N[,N-N]` syntax

The `skill-orchestrate/SKILL.md` is explicitly out of scope (remains single-task).

---

## Findings

### 1. Current orchestrate.md Implementation

The current `orchestrate.md` has a simple STAGE 0:

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')
focus_prompt="${FOCUS_PROMPT:-}"
```

It grabs only the first task number and discards the rest. The constraint comment says:
> "Single task only: no multi-task, no `--team` flag in v1"

The command has four stages: STAGE 0 (parse), CHECKPOINT 1 (gate in), STAGE 2 (delegate to `skill-orchestrate`), CHECKPOINT 2 (gate out), CHECKPOINT 3 (commit). The single-task path delegates to `skill-orchestrate` with a structured context object.

### 2. The Multi-Task Dispatch Pattern (from /research, /plan, /implement)

All three commands use an identical pattern from `multi-task-operations.md`:

**STAGE 0: PARSE TASK NUMBERS**
```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# TASK_NUMBERS is space-separated list of expanded task numbers
```

**Decision**:
- `len(TASK_NUMBERS) > 1` → continue to MULTI-TASK DISPATCH
- `len(TASK_NUMBERS) == 1` → fall through to existing CHECKPOINT 1 (zero overhead)

**MULTI-TASK DISPATCH has 4 steps**:
1. **Batch Validation** — iterate tasks, check existence and non-terminal status, collect `validated_tasks[]` and `skipped_tasks[]`
2. **Generate Batch Session ID** — `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')`
3. **Dispatch Skills** — invoke all skills in a single message (parallel Skill tool calls, one per task); each skill receives `session_id={batch_session_id}_{task_num}`
4. **Batch Git Commit + Consolidated Output** — after all skills complete

The critical design principle: all tasks in step 3 are dispatched simultaneously in one message. This is what enables true parallelism.

### 3. Dependencies Field Structure in state.json

The `dependencies` field is an array of integer task numbers:

```json
{
  "project_number": 621,
  "project_name": "add_revise_task_order_regeneration",
  "dependencies": [620],
  "status": "completed"
}
{
  "project_number": 622,
  "project_name": "fix_task_order_status_sync_pruning",
  "dependencies": [620],
  "status": "not_started"
}
```

Key observations:
- `dependencies: []` is the common case (most tasks have no dependencies)
- Dependencies reference other tasks by `project_number`
- Dependencies can reference tasks outside the current batch (cross-batch dependencies)
- Dependencies can also reference already-completed tasks (trivially satisfied)

### 4. Topological Wave Dispatch Model

The wave model differs from pure parallel dispatch by serializing dependent tasks:

**Wave construction algorithm (Kahn's-style)**:

```
Input: batch of validated task numbers T = {t1, t2, ..., tn}
       dependency graph: deps[t] = set of tasks t depends on

Step 1: Restrict dependencies to intra-batch only
  for each t in T:
    intra_deps[t] = deps[t] ∩ T  (only care about dependencies within the batch)

Step 2: Compute wave assignments
  remaining = T
  wave_num = 0
  while remaining is not empty:
    ready = {t in remaining | intra_deps[t] is empty}
    if ready is empty:
      ERROR: circular dependency detected
    waves[wave_num] = ready
    for each t in ready:
      for each successor s in remaining:
        intra_deps[s].remove(t)
    remaining.remove(ready)
    wave_num++

Step 3: Execute waves sequentially, tasks within each wave in parallel
  for wave in waves:
    dispatch all tasks in wave concurrently (single message, parallel Skill calls)
    wait for all tasks to complete (or fail)
    mark completed_tasks += succeeded tasks
  
  (failed tasks do not block subsequent waves — treated as satisfied predecessors)
```

**Why cross-batch dependencies don't need special handling**: If task B depends on task A and A is not in the batch, A either already completed (status check passes normally) or hasn't (A is in a non-terminal state). The wave algorithm only considers intra-batch dependencies for wave assignment; the orchestrate skill itself handles the case where prerequisite work isn't done (it starts from wherever the task status currently is).

**Example**:
```
Batch: /orchestrate 620, 621, 622
Task 620: no deps → Wave 0
Task 621: deps=[620] ∩ batch={620,621,622} → {620} → Wave 1
Task 622: deps=[620] ∩ batch={620,621,622} → {620} → Wave 1

Execution:
  Wave 0: [orchestrate 620] (parallel, but only one task here)
  Wave 1: [orchestrate 621, orchestrate 622] (parallel)
```

**Failed task handling**: If task 620 fails (ends partial/blocked), tasks 621 and 622 still launch in Wave 1. This is correct because the orchestrate skill will read the current task status and either resume from a valid intermediate state or detect the blocker. Alternatively, the command could skip Wave N+1 tasks that depend on failed Wave N predecessors — this is a design decision (see Decisions section).

### 5. Batch Validation for Orchestrate

Unlike `/research`, `/plan`, `/implement` which block on specific statuses, `/orchestrate` has a **permissive gate**: it accepts any non-terminal status (`not_started`, `researched`, `planned`, `implementing`, `partial`, `blocked`). This simplifies batch validation:

```bash
validated_tasks=(); skipped_tasks=()
for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' specs/state.json)
  if [ -z "$task_data" ]; then
    skipped_tasks+=("$task_num: not found"); continue
  fi
  status=$(echo "$task_data" | jq -r '.status')
  case "$status" in
    completed|abandoned|expanded)
      skipped_tasks+=("$task_num: terminal status [$status]"); continue ;;
  esac
  validated_tasks+=("$task_num")
done
```

### 6. Consolidated Output Format

Following the pattern from `multi-task-operations.md` Section 9, adapted for orchestrate:

```markdown
## Batch Orchestration Results

Session: {batch_session_id}
Tasks requested / Succeeded / Failed / Skipped: {counts}

### Succeeded
| Task | Title | Final Status | Cycles |
|------|-------|--------------|--------|

### Failed / Partial
| Task | Status | Cycles | Recovery |
|------|--------|--------|----------|

### Skipped
| Task | Reason |
|------|--------|

### Next Steps
- Tasks that reached [PARTIAL]: /orchestrate {task_numbers} to resume
```

### 7. Commit Format

```
orchestrate tasks {range_summary}: complete orchestration

Tasks: {comma-separated list}
Session: {batch_session_id}
```

For partial results:
```
orchestrate tasks {range_summary}: orchestration batch ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks partial/failed: {num}
Session: {batch_session_id}
```

### 8. CLAUDE.md Command Table Update

Current:
```
| `/orchestrate` | `/orchestrate N [prompt]` | Drive task autonomously through full lifecycle (no confirmation gates) |
```

Updated:
```
| `/orchestrate` | `/orchestrate N[,N-N] [prompt]` | Drive task(s) autonomously through full lifecycle with dependency-aware wave dispatch |
```

### 9. multi-task-operations.md Addition

A new section "13. Orchestrate-Specific Behavior" should be appended documenting:
- Why `/orchestrate` needs wave-based dispatch instead of pure parallel
- The intra-batch dependency resolution algorithm
- How failed predecessors are handled
- The N[,N-N] syntax and compatibility with focus prompt

---

## Decisions

1. **Failed predecessor handling**: If task A fails (partial/blocked), should tasks depending on A still launch in the next wave? **Recommendation: YES, launch them.** The orchestrate skill is designed to resume from any non-terminal state. If A left partial work, B can still launch and the skill will handle the state correctly. Skipping would require more complex bookkeeping and could leave valid tasks unrun.

2. **Focus prompt applies to all tasks**: Same as other commands — a single focus prompt passed to all `skill-orchestrate` invocations. The prompt is optional context, not required input.

3. **No `--team` flag**: `/orchestrate` does not support `--team` (each task is a full lifecycle, adding team mode per task would be excessive). If `--team` appears in args, it should be passed to the skill as-is (skill-orchestrate ignores unknown args). This matches the existing behavior where SKILL.md doesn't accept `--team`.

4. **Wave vs pure-parallel for single dependency chain**: Even with 1 task per wave, sequential dispatch is correct. A batch of 3 tasks where B depends on A and C depends on B creates 3 waves with 1 task each.

5. **Circular dependency detection**: If the wave algorithm cannot make progress (ready set is empty, remaining is non-empty), this indicates a cycle. The command should abort with an error listing the circular set, rather than silently hanging.

6. **No `skill-orchestrate` changes**: The skill remains single-task. All wave orchestration logic lives in `orchestrate.md`. This maintains a clean separation: the command handles multi-task coordination, the skill handles single-task state machine execution.

---

## Files That Need Modification

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/commands/orchestrate.md` | Primary | Update STAGE 0, add MULTI-TASK DISPATCH section, update ## Arguments and ## Constraints |
| `.claude/context/patterns/multi-task-operations.md` | Additive | Add Section 13: Orchestrate-Specific Behavior |
| `.claude/CLAUDE.md` | Minor | Update command table row for /orchestrate to show N[,N-N] syntax |

Note: `skill-orchestrate/SKILL.md` is **not modified**.

---

## Implementation Outline for orchestrate.md

### Section: ## Arguments (update)

```
- `$1` — Task number(s) (required). Single (`42`), comma-separated (`7,22`), ranges (`22-24`), or combined.
- `$2+` — Optional prompt/focus text (applies to all tasks in multi-task mode)
```

### Section: ## Constraints (update)

Remove: "Single task only: no multi-task, no `--team` flag in v1"
Add: "Multi-task mode uses dependency-aware wave dispatch. `--team` flag not supported."

### STAGE 0 (update)

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, REMAINING_ARGS, FOCUS_PROMPT
focus_prompt="${FOCUS_PROMPT:-}"

# Single-task fallthrough
task_numbers_array=($TASK_NUMBERS)
if [ "${#task_numbers_array[@]}" -eq 1 ]; then
  task_number="${task_numbers_array[0]}"
  # Fall through to CHECKPOINT 1
else
  # Continue to MULTI-TASK DISPATCH
fi
```

### New Section: MULTI-TASK DISPATCH

**Step 1: Batch Validation**
- For each task: check existence and non-terminal status → build `validated_tasks[]`, `skipped_tasks[]`

**Step 2: Dependency Graph Construction**
```bash
# For each validated task, read its dependencies from state.json
# Restrict to intra-batch dependencies only
declare -A intra_deps  # intra_deps[task_num]="space-separated list of dep task nums"
for task_num in "${validated_tasks[@]}"; do
  raw_deps=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' \
    specs/state.json)
  # Filter to only intra-batch deps
  filtered_deps=""
  for dep in $raw_deps; do
    for v in "${validated_tasks[@]}"; do
      if [ "$dep" = "$v" ]; then filtered_deps="$filtered_deps $dep"; fi
    done
  done
  intra_deps[$task_num]=$(echo "$filtered_deps" | xargs)
done
```

**Step 3: Topological Wave Assignment**
```bash
# Kahn's algorithm: repeatedly extract tasks with no remaining deps
declare -A wave_num
remaining=("${validated_tasks[@]}")
current_wave=0
while [ "${#remaining[@]}" -gt 0 ]; do
  ready=()
  for t in "${remaining[@]}"; do
    if [ -z "${intra_deps[$t]}" ]; then ready+=("$t"); fi
  done
  if [ "${#ready[@]}" -eq 0 ]; then
    echo "ERROR: Circular dependency detected in batch"
    # Report involved tasks and ABORT
  fi
  for t in "${ready[@]}"; do
    wave_num[$t]=$current_wave
    # Remove from remaining
    # Remove t from all other tasks' intra_deps
  done
  current_wave=$((current_wave + 1))
done
```

**Step 4: Wave Execution**
```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
completed_tasks=(); failed_tasks=()
total_waves=$current_wave

for wave_idx in $(seq 0 $((total_waves - 1))); do
  # Collect tasks in this wave
  wave_tasks=()
  for t in "${validated_tasks[@]}"; do
    if [ "${wave_num[$t]}" -eq "$wave_idx" ]; then wave_tasks+=("$t"); fi
  done
  
  echo "[orchestrate] Wave $((wave_idx+1))/$total_waves: tasks ${wave_tasks[*]}"
  
  # Dispatch all wave tasks in parallel (single message, concurrent Skill invocations)
  # For each task in wave_tasks:
  #   Skill: skill-orchestrate
  #   args: "task_number=$t session_id=${batch_session_id}_${t} focus_prompt=$focus_prompt orchestrator_mode=true"
  
  # After all skills in wave complete, collect results
  # Update completed_tasks[] / failed_tasks[]
done
```

**Step 5: Batch Git Commit + Consolidated Output**
(Same format as other commands)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Bash associative arrays (`declare -A`) may not work in all contexts | Test with simple loops and space-separated strings as fallback |
| Concurrent `skill-orchestrate` writes to state.json (loop guard files, status updates) | Each skill writes to its own scoped task data; loop guard files use per-task paths (`specs/NNN_slug/.orchestrator-loop-guard`) — no collision |
| Wave 1 tasks start before Wave 0 tasks fully commit state | `skill-orchestrate` reads live state.json status; Wave 0 tasks update their own status before terminating |
| Focus prompt contains special characters that break shell quoting | Pass focus_prompt via delegation context JSON, not as raw shell arg |
| Very large batches (many waves) exceed session context limits | MAX_CYCLES applies per task within the skill; the command's wave loop adds overhead proportional to wave count, not task count |
| Circular dependency edge case may not be caught if dep is outside batch | Only intra-batch deps are checked; cross-batch deps fall back to skill-level handling |

---

## Context Extension Recommendations

None. The multi-task-operations.md pattern file already exists and will be extended in-place (Section 13). No new context files are needed.

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/commands/research.md`
- `/home/benjamin/.config/nvim/.claude/commands/plan.md`
- `/home/benjamin/.config/nvim/.claude/commands/implement.md`
- `/home/benjamin/.config/nvim/.claude/context/patterns/multi-task-operations.md`
- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-in.sh`
- `/home/benjamin/.config/nvim/specs/state.json` (dependency field structure)

### Key Design Reference

`multi-task-operations.md` Section 6 ("Parallel Skill Dispatch") and Section 12 ("Command File Modification Guide") are the authoritative reference for the dispatch pattern. The orchestrate variant reuses this exactly but wraps the dispatch loop in the wave execution layer.

The dependency field structure confirmed in state.json:
```json
"dependencies": [620]   // array of integer task numbers
"dependencies": []      // common case: no dependencies
```
