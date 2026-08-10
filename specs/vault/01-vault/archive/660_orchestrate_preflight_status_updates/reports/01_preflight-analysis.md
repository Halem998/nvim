# Research Report: Task #660

**Task**: 660 - Add preflight status updates to skill-orchestrate state handlers
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:05:00Z
**Effort**: 1 hour (research only)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-orchestrate/SKILL.md`
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/scripts/update-task-status.sh`
- `.claude/scripts/update-plan-status.sh`
- `.claude/agents/general-implementation-agent.md`
**Artifacts**: - `specs/660_orchestrate_preflight_status_updates/reports/01_preflight-analysis.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-orchestrate Stage 4 dispatches agents (research/plan/implement) without first calling `update-task-status.sh preflight`, leaving tasks stuck in their prior status during execution
- Each individual skill (skill-researcher Stage 2, skill-planner Stage 2, skill-implementer Stage 2) calls `update-task-status.sh preflight <N> <target> <session_id>` before spawning its agent — these calls are what orchestrate bypasses entirely
- `update-task-status.sh preflight implement` internally calls `update-plan-status.sh` to set the plan file's top-level `**Status**:` to `[IMPLEMENTING]`
- `general-implementation-agent` Stage 4A/4D correctly updates per-phase markers (`[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`) — this is independent of the top-level plan Status field
- Fix: Insert one `bash .claude/scripts/update-task-status.sh preflight "$task_number" <target> "$session_id"` call in each active Stage 4 handler (not_started, researched, planned/implementing) and in Stage MT-4 dispatch loops — with an idempotency guard to handle the `researching`/`planning`/`implementing` pass-through states
- Idempotency: `update-task-status.sh` performs a current-status check and exits 0 if already at target — no double-preflight risk

## Context & Scope

skill-orchestrate is a state machine that reads task status from `state.json` and dispatches the appropriate agent. Unlike the individual skills (`/research`, `/plan`, `/implement`), it does not call the preflight update before each dispatch. The consequence is:

1. A task stays at `not_started` while it is being researched
2. A task stays at `researched` while it is being planned
3. A task stays at `planned` while it is being implemented
4. Plan files never show `[IMPLEMENTING]` during orchestrated runs

The postflight side works correctly: `skill_postflight_update` is called in Stage 5 after each dispatch. The gap is exclusively on the preflight side.

## Findings

### Codebase Patterns

#### What each skill's preflight does

**skill-researcher Stage 2**:
```bash
.claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```
Sets `state.json` status to `"researching"`, `TODO.md` markers to `[RESEARCHING]`.

**skill-planner Stage 2**:
```bash
bash .claude/scripts/update-task-status.sh preflight $task_number plan $session_id
```
Sets `state.json` status to `"planning"`, `TODO.md` markers to `[PLANNING]`.

**skill-implementer Stage 2**:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```
Sets `state.json` status to `"implementing"`, `TODO.md` markers to `[IMPLEMENTING]`. Additionally triggers `update-plan-status.sh` internally to set plan file `**Status**:` to `[IMPLEMENTING]`.

#### How update-task-status.sh handles preflight

The script at `.claude/scripts/update-task-status.sh` maps:
- `preflight:research` → `STATE_STATUS="researching"`, `TODO_STATUS="RESEARCHING"`
- `preflight:plan` → `STATE_STATUS="planning"`, `TODO_STATUS="PLANNING"`
- `preflight:implement` → `STATE_STATUS="implementing"`, `TODO_STATUS="IMPLEMENTING"`

The script updates state.json (status, last_updated, session_id), TODO.md task entry `**Status**:` marker, TODO.md Task Order entry, and for `implement` it calls `update-plan-status.sh` for the plan file top-level `**Status**:`.

**Idempotency**: At lines 116-126, the script reads current status from state.json and exits 0 with no-op if already at target status. This makes it safe to call preflight multiple times.

Also: On preflight, the script writes `.claude/tmp/workflow-active` marker (line 147-149). This is currently not happening in orchestrated runs.

#### update-plan-status.sh behavior

`update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS` — when called with `IMPLEMENTING`, it:
1. Locates the latest `.md` in `specs/{NNN}_{PROJECT_NAME}/plans/`
2. Updates the first `- **Status**: [...]` line to `[IMPLEMENTING]`
3. Is idempotent (no-op if already at target)

This is called from within `update-task-status.sh`'s `update_plan_file()` function when `target_status == implement`.

#### general-implementation-agent phase markers

Stage 4A marks a phase `[IN PROGRESS]` by editing the plan file heading:
```
old: ### Phase {P}: {Phase Name} [NOT STARTED]
new: ### Phase {P}: {Phase Name} [IN PROGRESS]
```

Stage 4D marks a phase `[COMPLETED]`:
```
old: ### Phase {P}: {Phase Name} [IN PROGRESS]
new: ### Phase {P}: {Phase Name} [COMPLETED]
```

These are **per-phase** markers in headings, entirely separate from the top-level `**Status**:` field updated by `update-plan-status.sh`. The agent updates phase headings correctly; the top-level Status is only set by `update-plan-status.sh` during preflight.

#### skill-orchestrate current Stage 4 handlers (missing preflight)

**State `not_started` (or `not started`)**: Dispatches `$RESEARCH_AGENT` — NO preflight call before dispatch.

**State `researched`**: Dispatches `planner-agent` — NO preflight call before dispatch.

**State `planned` or `implementing`**: Dispatches `$IMPLEMENT_AGENT` — NO preflight call before dispatch.

**State `partial` with continuation**: Dispatches `$IMPLEMENT_AGENT` — NO preflight call before dispatch.

**Stage 5 postflight**: Correctly calls `skill_postflight_update` for `researched`, `planned`, `implemented` dispatch statuses.

#### skill-orchestrate Stage MT-4 (multi-task, same gap)

The research/plan/implement dispatch loops in MT-4 do not call preflight before each task dispatch. They do call `skill_postflight_update` in the per-task postflight loop after dispatch completes.

### Specific Insertion Points

#### Single-task Stage 4 (3 points)

**Point 1 — State `not_started`**: Before the dispatch_agent call for $RESEARCH_AGENT, add:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id" || \
  echo "[orchestrate] WARNING: preflight research update failed (non-blocking)"
```

**Point 2 — State `researched`**: Before the dispatch_agent call for planner-agent, add:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" plan "$session_id" || \
  echo "[orchestrate] WARNING: preflight plan update failed (non-blocking)"
```

**Point 3 — State `planned` or `implementing`**: Before the dispatch_agent call for $IMPLEMENT_AGENT, add:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id" || \
  echo "[orchestrate] WARNING: preflight implement update failed (non-blocking)"
```

**Point 3b — State `partial` with continuation**: Before the dispatch_agent call for $IMPLEMENT_AGENT in the partial/continuation sub-state, add the same preflight:implement call. Note: if the task is already `implementing` (which is correct for partial continuations), the idempotency check in the script will no-op this call.

#### Multi-task Stage MT-4 (3 loop insertion points)

**Research loop** (for task_num in "${research_tasks[@]}"):
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_num" research "${session_id}_${task_num}" || \
  echo "[orchestrate-mt] WARNING: preflight research failed for task $task_num (non-blocking)"
```
Add before `echo "[orchestrate-mt] Dispatching research for task $task_num -> $r_agent"`.

**Plan loop** (for task_num in "${plan_tasks[@]}"):
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_num" plan "${session_id}_${task_num}" || \
  echo "[orchestrate-mt] WARNING: preflight plan failed for task $task_num (non-blocking)"
```
Add before `echo "[orchestrate-mt] Dispatching planning for task $task_num -> planner-agent"`.

**Implement loop** (for task_num in "${implement_tasks[@]}"):
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_num" implement "${session_id}_${task_num}" || \
  echo "[orchestrate-mt] WARNING: preflight implement failed for task $task_num (non-blocking)"
```
Add before `echo "[orchestrate-mt] Dispatching implement for task $task_num -> $i_agent"`.

### Idempotency Analysis

**No double-preflight risk**: The `update-task-status.sh` script reads the current status from `state.json` at lines 116-126 and exits 0 immediately if `current_state_status == STATE_STATUS`. This means:
- If a task is `not_started` and we call `preflight research`, it sets to `researching` — correct.
- If a task is already `researching` (rare: resumed cycle), calling `preflight research` is a no-op — safe.
- If a task is `implementing` and we call `preflight implement` (partial continuation), it is a no-op — safe.

The only case requiring careful handling is the `implementing` state handler in Stage 4 (`planned|implementing`). When task is `planned`, preflight sets it to `implementing`. When task is already `implementing` (resume path), preflight is a no-op. Both cases are correct.

**Blocking vs. non-blocking**: The individual skills treat preflight as blocking (abort on non-zero exit). For orchestrate, the recommendation is to make preflight non-blocking (log warning, continue dispatch) because the orchestrator should not abort the entire orchestration loop due to a TODO.md update failure. Use `|| echo "WARNING: ..."` pattern.

**Multi-task session_id**: In MT-4, the dispatch context uses `"${session_id}_${task_num}"` as the per-task session ID. The preflight call should use the same pattern to maintain consistent session tracking in state.json.

### Plan File Status Verification

`update-plan-status.sh` is confirmed to:
- Accept `IMPLEMENTING` as valid status (line 22)
- Find the latest plan file via `ls -t "$plan_dir"/*.md | head -1`
- Update the first `- **Status**: [...]` line using `sed -i "0,/^- \*\*Status\*\*: \[.*\]/{"` pattern
- Is idempotent (exits 0 if already at target)
- Is called internally by `update-task-status.sh preflight implement` (no need to call it separately)

The agent's per-phase `[IN PROGRESS]`/`[COMPLETED]` heading markers are orthogonal — they are managed by the implementation agent and do not interact with the top-level `**Status**:` field.

### workflow-active Marker

`update-task-status.sh` writes `.claude/tmp/workflow-active` on preflight operations (line 146-149). This marker is used by the Stop hook to suppress mid-workflow fires. Without preflight calls in orchestrate, this marker is never written, which may cause the Stop hook to fire unexpectedly during orchestrated runs. Adding preflight calls fixes this as a side effect.

## Decisions

- Preflight calls in skill-orchestrate should be non-blocking (`|| echo WARNING`) rather than blocking — the orchestrator is a higher-level coordinator and a TODO.md update failure should not abort the state machine loop
- The `partial`/continuation sub-state handler also needs a preflight call (implement), which will be a no-op when task is already `implementing` — this is the correct behavior
- Multi-task preflight uses per-task session_id (`${session_id}_${task_num}`) to match the dispatch context

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Double-preflight sets wrong status | Low | `update-task-status.sh` idempotency check prevents this |
| Preflight fails and orchestrator aborts | Medium | Use non-blocking `||` pattern with warning log |
| Partial state: preflight sets `implementing` but task was already `implementing` | Low | Idempotency check is a no-op — safe |
| MT-4 parallel batch: preflight calls are sequential per task before parallel dispatch | Low | Preflight is fast (jq + sed); sequential overhead is minimal |
| `workflow-active` marker from orchestrate may conflict with direct skill invocations | Low | Same task shouldn't run in both modes simultaneously; marker is overwritten anyway |

## Context Extension Recommendations

- none

## Appendix

**Files examined**:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (Stage 4, MT-4)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (Stage 2)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (Stage 2)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (Stage 2)
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (full script)
- `/home/benjamin/.config/nvim/.claude/scripts/update-plan-status.sh` (full script)
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (Stage 4A, 4D)
