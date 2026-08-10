# Research Report: Task #765

**Task**: 765 - Fix multi-task orchestration wave cycling and agent tracking
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:30:00Z
**Effort**: ~30 minutes (codebase-only research)
**Dependencies**: None
**Sources/Inputs**: skill-orchestrate/SKILL.md, orchestrate.md, orchestrate-state-machine.md, handoff-schema.md
**Artifacts**: specs/765_fix_mt_orchestration_wave_cycling/reports/01_mt-wave-cycling-research.md
**Standards**: report-format.md

---

## Executive Summary

- The MT mode wave loop (Stage MT-3) iterates through a **static, pre-computed wave list once** — it has no mechanism to re-dispatch tasks that have advanced in phase after completing research or planning. After Wave 0 dispatches research for all tasks and research completes, the wave loop simply exits.
- The wave loop has **no cycling mechanism** comparable to the `while [ cycle_count < MAX_CYCLES ]` loop in single-task mode. The outer `for wave_idx` loop is a one-pass iteration, not a lifecycle driver.
- **Parallel Agent completion tracking is implicit-only**: the SKILL.md says "dispatch in parallel" but the code blocks around `echo` statements and a for-loop over research/plan/implement groups — the actual Agent tool calls are expected to run in parallel when made in a single message, but the SKILL.md spec does not explicitly pause between phases within a wave to collect results before issuing the next batch.
- The fix requires converting the MT outer loop from a one-pass wave iterator into a **phase-cycling loop** that keeps iterating until all tasks reach terminal state, consulting current task statuses on each pass to dispatch the appropriate next phase.
- Parallel Agent completion is already handled correctly by Claude Code when multiple Agent tool calls are issued in one message — the problem is the loop exits before issuing the next round of Agent calls.

---

## Context & Scope

Task 765 was filed after a live observation where `/orchestrate` with multiple tasks ran Wave 0 research dispatches, research agents completed (planner agents were reported done after 8+ minutes), but the orchestrator never dispatched planning or implementation phases. The user had to manually prompt the orchestrator to continue.

The scope of this research covers:
1. The MT mode stages (MT-1 through MT-5) in `skill-orchestrate/SKILL.md`
2. The orchestrate.md command's multi-task dispatch path (MULTI-TASK DISPATCH section)
3. The single-task state machine loop (Stages 3-5) as the working reference
4. The handoff and state-machine architecture docs

Files examined:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (full, 1172 lines)
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` (full, 403 lines)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md`

---

## Findings

### Bug 1: Wave Loop is a One-Pass Iterator, Not a Lifecycle Driver

**Location**: SKILL.md Stage MT-3 (lines 819–868)

The single-task state machine (Stage 3) uses a `while [ cycle_count < MAX_CYCLES ]` loop that re-reads task state on every iteration and dispatches whichever agent phase matches the current status:

```
while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
  current_status=$(jq ...)       # fresh read each iteration
  case "$current_status" in
    not_started) dispatch research ...
    researched)  dispatch plan ...
    planned)     dispatch implement ...
    ...
  esac
  cycle_count=$((cycle_count + 1))
done
```

The MT wave loop (Stage MT-3) uses a `for wave_idx in $(seq 0 $((wave_count - 1)))` loop that iterates through the **pre-computed wave list exactly once**:

```
for wave_idx in $(seq 0 $((wave_count - 1))); do
  wave_tasks=$(echo "$waves_json" | jq -r ".[$wave_idx][]")
  # filter active tasks ...
  # dispatch to Stage MT-4 ...
done
```

`waves_json` is produced by Kahn's algorithm in `orchestrate.md` and represents the **dependency order** of the tasks (which tasks can run in parallel vs. must wait for predecessors). It is NOT a lifecycle phase schedule. All tasks in Wave 0 have no intra-batch dependencies and run together. Tasks in Wave 1 depend on Wave 0 tasks, and so on.

The wave structure answers "which tasks can run at the same time" — it does NOT encode the lifecycle sequence (research → plan → implement) for each task. After one pass through all waves, the loop exits.

**Root cause**: There is no outer lifecycle phase loop. The wave loop was written as if one pass delivers tasks from `not_started` to `completed`, but in practice each wave pass dispatches only one phase per task (research, OR plan, OR implement), not all three.

### Bug 2: Phase-Aware Dispatch Correctly Identifies Current Phase but Has No Re-Entry Mechanism

**Location**: SKILL.md Stage MT-4 (lines 875–921)

Stage MT-4 does correctly group tasks by their current status into `research_tasks`, `plan_tasks`, and `implement_tasks` arrays, then dispatches the appropriate agent for each group. The logic reads `current_statuses[$task_num]` which was populated by re-reading `state.json` at the top of each `wave_idx` iteration.

However, because the wave loop exits after one pass, Stage MT-4 is called only once per wave, and after all waves are exhausted, there is no mechanism to re-enter the loop and dispatch the next lifecycle phase for tasks that have now advanced (e.g., from `not_started` → `researched`).

The handoff postflight at the end of Stage MT-4 does update `current_statuses[$task_num]` with fresh status from state.json, but these updated statuses are never consulted again by the wave loop because it has already moved on to the next wave index (or exited).

### Bug 3: Parallel Agent Completion Tracking — No Explicit Wait Mechanism

**Location**: SKILL.md Stage MT-4 (lines 997–1101)

The SKILL.md spec says "dispatch research tasks (concurrent, max 4)" and iterates a for-loop building dispatch contexts, with `echo "[orchestrate-mt] Dispatching research for task $task_num -> $r_agent"` as placeholder. The actual Agent tool calls must be issued together in a single orchestrator message to run in parallel. The postflight section at the bottom of Stage MT-4 then reads all handoff files.

This approach is correct in principle for Claude Code's parallel Agent execution model — multiple Agent tool calls in one message execute concurrently. However, the SKILL.md documentation is ambiguous about how the parallel dispatch is structured:

1. It lists three separate for-loops: one for research tasks, one for plan tasks, one for implement tasks.
2. There is no explicit statement that these three loops' Agent calls should be issued together in one message.
3. In the observed failure, "user had to manually prompt that planner agents had finished after 8+ minutes of churning" — this suggests the orchestrator may have dispatched parallel research agents correctly, but then did not issue the planning Agent calls because the wave loop had already exited.

The more likely scenario is that the orchestrator issued all research Agent calls in Wave 0, they completed, but the for-wave loop moved to wave index 1 (or exited if there was only one wave), and Stage MT-4 for wave 1 either had no tasks or didn't recognize that tasks had advanced to `researched` status.

### Bug 4: Within-Wave Status Staleness

**Location**: SKILL.md Stage MT-3, status re-read block (lines 829–832)

At the top of each wave iteration, Stage MT-3 re-reads status from state.json:

```bash
current_status=$(jq -r --argjson num "$task_num" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  specs/state.json)
current_statuses[$task_num]="$current_status"
```

This re-read is only useful if tasks have advanced since the previous wave iteration. But since all tasks in `Wave 0` typically start as `not_started`, the filter in Stage MT-3 will see them all as active (not in terminal state), dispatch them to Stage MT-4 as `research_tasks`, and after research completes, update `current_statuses` to `researched`. This is correct behavior for Wave 0.

The bug is that after Wave 0's agent calls return and postflight runs (updating statuses to `researched`), the for-wave loop increments to `wave_idx=1`, but `waves_json[1]` may contain the same task numbers (or different dependent tasks) that are now in `researched` state — yet the wave loop has NO mechanism to re-dispatch Wave 0 tasks that advanced in phase. Wave 1 tasks are different tasks (those that depended on Wave 0), not the same tasks in a new lifecycle phase.

This is the crux of the architectural mismatch: **waves encode dependency order, not lifecycle phases**.

### Single-Task Mode: What Works Correctly

The single-task state machine (Stages 3-5, lines 163–417) works because:
1. It has a `while [ cycle_count < MAX_CYCLES ]` outer loop.
2. On each iteration it reads the current task status fresh from state.json.
3. It dispatches the correct phase based on current status.
4. After each dispatch returns, the cycle increments and the while-condition is re-checked.
5. The task naturally advances: `not_started` → (research dispatch) → `researched` → (plan dispatch) → `planned` → (implement dispatch) → `completed`.
6. The loop exits when status hits `completed`, `abandoned`, or `expanded`.

This is the pattern the MT mode must adopt.

### Architecture Documentation Gap

The `orchestrate-state-machine.md` documents only single-task behavior. The MT mode is described only in SKILL.md itself. There is no architectural documentation for how the wave-based lifecycle should work (i.e., what happens after Wave 0 research completes — how do the same tasks advance to planning?).

---

## Decisions

The following decisions are implicit in the analysis above and should guide the fix:

1. **Wave structure is preserved as dependency ordering** — the wave index determines which tasks are eligible to start (can't start until predecessors complete), not what lifecycle phase to dispatch.
2. **A new outer lifecycle-cycling loop is needed** that wraps the wave loop — it keeps iterating until all tasks reach terminal states or MAX_CYCLES is hit.
3. **Within each cycling iteration**, Stage MT-4's phase-aware dispatch correctly handles the current phase of each task — this logic does not need to change.
4. **Parallel Agent calls** within a wave/phase batch should be issued together in a single orchestrator message. The structure of three separate dispatch groups (research, plan, implement) should remain but all calls for the current iteration should be batched.

---

## Proposed Fix

### Fix 1: Add Outer Lifecycle Cycling Loop in Stage MT-3

Replace the single `for wave_idx` loop with a `while [ cycle_count < MAX_CYCLES_MT ]` outer loop that terminates when all tasks are in terminal state. Inside this loop, determine which tasks are eligible to be dispatched based on:
- They are not already in terminal state (completed, abandoned, expanded, failed)
- Their wave predecessors have all reached `researched` or later state (dependency check)
- Their current status maps to a dispatchable phase (not_started, researched, planned, partial)

**Pseudo-structure:**

```
while [ cycle_count < MAX_CYCLES_MT ] && [ not_all_terminal ]; do
  # Refresh all task statuses from state.json
  for task_num in all_tasks:
    current_statuses[$task_num] = read from state.json
  
  # Identify eligible tasks (predecessors complete, not terminal, not in-flight)
  eligible_tasks = []
  for task_num in all_tasks:
    if is_terminal(current_statuses[$task_num]): skip
    if predecessors_not_yet_at_researched(task_num): skip  # dependency gate
    eligible_tasks += task_num
  
  if [ ${#eligible_tasks[@]} -eq 0 ]; then
    # All remaining tasks are either terminal or waiting on predecessors
    # Check if anything is still in-flight (researching, planning)
    break
  fi
  
  # Phase-aware dispatch (Stage MT-4 logic unchanged)
  dispatch_eligible_tasks(eligible_tasks)
  
  # Read handoffs and run postflight
  read_handoffs_and_postflight()
  
  cycle_count++
done
```

**Dependency gate refinement**: Instead of requiring predecessors to be `completed`, the gate should allow a task to proceed to planning once its predecessors are `researched` (or later), and to implementation once predecessors are `planned` (or later). However, the simplest correct gate is: a task can start (research phase) only when all its predecessors have reached at least `researched`. Since the task description says the simple case (all tasks `not_started`, no dependencies) failed, the minimal fix is just adding the outer while loop with all-terminal detection.

### Fix 2: Correct Dependency Eligibility Check

The current Stage MT-3 checks if a predecessor is in `failed_tasks` (to skip the task) but does NOT check if a predecessor is still in `not_started` or `researching` (i.e., not yet done enough). For truly independent tasks (Wave 0), this doesn't matter — they all start fresh. For Wave 1 tasks that depend on Wave 0, the check should ensure Wave 0 tasks have completed their research (or fully completed) before Wave 1 tasks are dispatched.

In the cycling loop design, this is naturally handled: Wave 1 tasks will only appear in `eligible_tasks` once their predecessors are no longer blocking them. The specific gate depends on whether "predecessors complete" means `completed` (strict) or `researched` (relaxed, allows pipelining).

**Recommendation**: Use the strict gate (`completed`) for simplicity and correctness. Wave 1 tasks wait until Wave 0 tasks are fully `completed`. This means tasks proceed strictly through the lifecycle before unlocking dependents. This matches the intent of topological wave assignment.

### Fix 3: Parallel Agent Call Clarity

The SKILL.md spec should explicitly state that all Agent tool calls for a given cycle's dispatch batch (research_tasks + plan_tasks + implement_tasks) must be issued **in a single orchestrator message** to execute concurrently. The current spec uses echo statements as placeholders and says "concurrent, max 4" but the actual mechanics of how Claude Code parallelizes Agent calls is implicit.

Add explicit instruction: "Issue all Agent tool calls for this dispatch batch in a single message (multiple tool-use content blocks). Do not sequentialize across the dispatch groups within the same cycle iteration."

### Fix 4: Completion Detection

After each cycling iteration, check if all tasks are in terminal state:

```bash
all_terminal=true
for task_num in all_tasks:
  status = current_statuses[$task_num]
  if ! is_terminal(status):
    all_terminal=false
    break

if $all_terminal: break out of while loop
```

Terminal states: `completed`, `abandoned`, `expanded`, plus tasks in `failed_tasks` array.

### Fix 5: In-Flight State Handling

The current MT-4 code skips tasks in `blocked|researching|planning` states:

```bash
blocked|researching|planning)
  echo "[orchestrate-mt] Task $task_num in in-flight or blocked state [$status] — skipping this cycle"
```

With the cycling loop, in-flight states are naturally handled: the task will be skipped in the current cycle and reconsidered in the next cycle when its status changes. This is correct behavior — the orchestrator should not dispatch a second research agent for a task that is already `researching`.

---

## Risks & Mitigations

### Risk 1: Infinite Loop
**Risk**: The cycling loop could iterate indefinitely if tasks get stuck in non-terminal, non-dispatchable states (e.g., all remaining tasks in `researching` state with no agent running).

**Mitigation**: MAX_CYCLES_MT cap (already exists: `task_count * 5`, capped at 25). The loop must unconditionally exit when `cycle_count >= MAX_CYCLES_MT`. Additionally, add a "no eligible tasks" circuit breaker: if `eligible_tasks` is empty AND not all tasks are terminal, exit with a warning listing stuck tasks.

### Risk 2: Missed Postflight Updates
**Risk**: If the skill dispatches agents in parallel but the postflight loop runs before all agents complete (race condition), handoff files may be missing.

**Mitigation**: In Claude Code's execution model, Agent tool calls in a single message complete before the next message is processed. As long as the orchestrator issues all Agent calls in a single message and reads handoffs after that message returns, there is no race. The SKILL.md must be explicit about this sequencing.

### Risk 3: Stale `current_statuses` Array
**Risk**: The bash `declare -A current_statuses` array is populated in Stage MT-2, then updated in Stage MT-4 postflight. The cycling loop must refresh from state.json at the top of each iteration, not rely on the in-memory array from the previous cycle.

**Mitigation**: The cycling loop's first step must always be to re-read all task statuses from state.json into `current_statuses`. This is a single jq query per task, which is cheap. State MT-4 already has this logic for wave-level filtering; it just needs to be promoted to the cycling loop level.

### Risk 4: Dependency Gate Blocking Eligible Tasks
**Risk**: If the dependency gate is too strict (requiring `completed` before unlocking Wave 1), a partial failure in Wave 0 could permanently block Wave 1 tasks even if they have soft dependencies.

**Mitigation**: The current design already marks failed predecessors and skips dependent tasks. This is the correct behavior for hard dependencies. If pipelining is desired in the future (Wave 1 can start planning while Wave 0 is still implementing), the dependency gate can be relaxed to `researched` or `planned`. For the immediate fix, strict (`completed` or `failed_tasks`) is correct and safe.

---

## Recommended Implementation Plan

1. **Stage MT-3 rewrite**: Replace `for wave_idx` with `while [ cycle_count < MAX_CYCLES_MT ]`. Inside:
   - Re-read all task statuses from state.json.
   - Build `eligible_tasks` list: tasks not in terminal state and whose intra-batch predecessors are all in terminal state (using `failed_tasks` and `completed_tasks` arrays from multi-state file).
   - If `eligible_tasks` is empty: check if all tasks are terminal; if so, break successfully; if not, log warning and break with partial.
   - Pass `eligible_tasks` to Stage MT-4 dispatch.
   - Read handoffs and run postflight.
   - Increment `cycle_count`.

2. **Stage MT-4 unchanged structurally**: The phase grouping (research/plan/implement) and dispatch logic is correct. The only change: all Agent tool calls for the batch must be explicitly issued in one message.

3. **Stage MT-5 unchanged**: Postflight reads multi-state file and reports results.

4. **MAX_CYCLES_MT clarification**: The formula `task_count * 5` with cap at 25 is correct — 5 dispatch cycles per task (research + plan + implement + 2 retry/continuation slots). The cycling loop will typically use `task_count * 3` cycles for a clean run (one cycle per lifecycle phase per task, with wave-level pipelining).

5. **Documentation**: Update `orchestrate-state-machine.md` to include the MT lifecycle cycling diagram.

---

## Context Extension Recommendations

- **Topic**: MT orchestration lifecycle cycling in orchestrate-state-machine.md
- **Gap**: The architecture doc only documents single-task behavior. MT mode wave cycling is entirely undocumented at the architecture level.
- **Recommendation**: Add an "MT Mode" section to `orchestrate-state-machine.md` describing how the cycling loop wraps the wave dependency structure, with an ASCII diagram similar to the single-task diagram.
