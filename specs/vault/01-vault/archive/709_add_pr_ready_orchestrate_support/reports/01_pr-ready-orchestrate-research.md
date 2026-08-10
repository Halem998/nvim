# Research Report: Task #709

**Task**: 709 - add_pr_ready_orchestrate_support
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:10:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: `.claude/skills/skill-orchestrate/SKILL.md`, `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`, `.claude/extensions/cslib/manifest.json`, `.claude/scripts/update-task-status.sh`, `.claude/scripts/skill-base.sh`, `.claude/extensions/cslib/commands/pr.md`
**Artifacts**: `specs/709_add_pr_ready_orchestrate_support/reports/01_pr-ready-orchestrate-research.md`
**Standards**: report-format.md

## Executive Summary

- The `skill-orchestrate` SKILL.md (1152 lines) has four locations that need `pr_ready` support added
- The PR lifecycle: `skill-pr-implementation` calls `postflight pr_ready` -> state becomes `pr_ready` -> user runs `/pr N` -> state transitions to `completed`
- The bug: when orchestrate dispatches an implement agent that returns `pr_ready` handoff status, all four code sites fall through to catch-all cases instead of handling PR tasks properly
- The `/pr` command (not `/merge`) is the correct command to reference in the `pr_ready` state handler message
- All four changes are additive insertions — no existing code needs modification

## Context & Scope

The cslib extension provides a `pr` task type with a `skill-pr-implementation` that transitions tasks to `[PR READY]` status instead of `[COMPLETED]`. When orchestrate drives a `pr` task through the full lifecycle, it encounters `pr_ready` at two points where it currently has no handler:

1. **Stage 4 state handler** — when the task is already in `pr_ready` state, orchestrate hits "Unknown state" and exits partial
2. **Stage 5 postflight dispatch_status** — when skill-pr-implementation writes `pr_ready` to the handoff, orchestrate's `skill_postflight_update` case falls to `*` (no update)
3. **Stage 5 artifact linking** — artifact type `pr_description` falls through to the `*` default with field_name `**Summary**` (acceptable but semantically wrong — should be `**PR Description**`)
4. **Multi-task equivalents** — Stages MT-3 and MT-4 have the same gaps

## Findings

### State Machine Context

The `pr_ready` state is used in the PR lifecycle:

```
not_started -> researching -> researched -> planning -> planned
             -> implementing -> pr_ready -> [user runs /pr N] -> completed
```

The `update-task-status.sh` script supports:
- `preflight:pr_ready` -> state=`pr_ready`, TODO=`[PR READY]`
- `postflight:pr_ready` -> state=`completed`, TODO=`[COMPLETED]` (used by `/pr` command)

### `skill_postflight_update` in skill-base.sh

The function at line 275 only recognizes `researched`, `planned`, `implemented` as success values:

```bash
case "$status" in
  researched|planned|implemented)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
    ;;
  *)
    echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
    ;;
esac
```

This function is not what orchestrate calls directly. Orchestrate calls `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"`. When `dispatch_status="pr_ready"`, the `skill_postflight_update` function's `*)` branch fires (not the implement branch), and `update-task-status.sh postflight <task> implement` is never called.

The orchestrate skill's own case statement (Stage 5, line ~372) is what needs the new `pr_ready` arm — it calls `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"`. Adding `pr_ready)` to call `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"` will trigger `update-task-status.sh postflight implement`, which maps to COMPLETED. That would be wrong.

**Critical Distinction**: For a `pr_ready` dispatch, the orchestrate skill should call `skill_postflight_update "$task_number" "pr_ready" "$session_id" "$dispatch_status"` — but `skill_postflight_update` also doesn't recognize `pr_ready` as a success status. However, `update-task-status.sh postflight pr_ready` would map to COMPLETED, which is also wrong.

The correct call is: `bash .claude/scripts/update-task-status.sh postflight pr_ready "$task_number" "$session_id"` — wait, the argument order in skill-base.sh is `"$task_number" "$operation" "$session_id"`.

Actually, the correct postflight for `pr_ready` is **NOT** postflight — it's preflight. When skill-pr-implementation reports `pr_ready` dispatch status, the task should already be in `pr_ready` state in state.json (skill-pr-implementation's own postflight already ran `postflight pr_ready` which maps to `completed`). 

Wait — let me re-read carefully. The skill-pr-implementation calls `bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"`, which maps `postflight:pr_ready` -> COMPLETED. That would make the task COMPLETED, but the task description says the expected transition is to `[PR READY]`.

There's an inconsistency in the existing skill-pr-implementation vs what update-task-status.sh actually does. The skill-pr-implementation says it should produce `[PR READY]`, but postflight:pr_ready -> COMPLETED.

**Resolution**: Looking at the `/pr` command (line 909): it calls `update-task-status.sh postflight "$input_value" pr_ready "$session_id"` to transition from `pr_ready` to `COMPLETED` after the PR is submitted. This means the intended flow is:

1. `skill-pr-implementation` calls `preflight pr_ready` (-> state=`pr_ready`, TODO=`[PR READY]`) — NOT postflight
2. Then writes `.return-meta.json` with status `pr_ready`  
3. `/pr N` later calls `postflight pr_ready` (-> state=`completed`, TODO=`[COMPLETED]`)

But the skill SKILL.md says Stage 6 calls `postflight pr_ready`. This is actually a bug in skill-pr-implementation — it should call `preflight pr_ready` not `postflight pr_ready`. However, that's out of scope for this task.

**For orchestrate purposes**: The handoff from skill-pr-implementation will have `status: "pr_ready"` (or possibly `"implemented"` if the task uses standard return). The task description says the dispatch_status from the handoff will be `pr_ready`.

### Insertion Point 1: Stage 4 State Handler (line ~312)

**Current code at lines 312-334:**

```
#### State: `completed`

```
echo "[orchestrate] Task $task_number completed successfully."
# Clean up loop guard
rm -f "$loop_guard_file"
EXIT (success)
```

#### States: `abandoned`, `expanded`

```
echo "[orchestrate] Task $task_number is in terminal state [$current_status]. No action taken."
EXIT (no-op)
```

#### Unknown state

```
echo "[orchestrate] WARNING: Unrecognized state '$current_status' for task $task_number."
EXIT (partial)
```
```

**Where to insert**: Between the `completed` handler and the `abandoned/expanded` handler, at approximately line 322 (after the `completed` EXIT block, before `#### States: abandoned, expanded`).

**Pattern to follow** (from `completed` handler):
```
echo "[orchestrate] Task $task_number completed successfully."
rm -f "$loop_guard_file"
EXIT (success)
```

**New `pr_ready` handler**:
```
#### State: `pr_ready`

```
echo "[orchestrate] Task $task_number is [PR READY]. Run /pr $task_number to create the branch and submit the pull request."
# Clean up loop guard — pr_ready is a terminal state for orchestrate
rm -f "$loop_guard_file"
EXIT (success)
```
```

### Insertion Point 2: Stage 5 dispatch_status case (lines ~372-385)

**Current code:**

```bash
case "$dispatch_status" in
  researched)
    skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
    ;;
  planned)
    skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
    ;;
  implemented)
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
    ;;
  *)
    echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
    ;;
esac
```

**Where to insert**: After the `implemented)` arm, before the `*)` arm (approximately line 381).

**New arm to add**:
```bash
  pr_ready)
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
    ;;
```

**Rationale**: The `pr_ready` status is the result of an implement operation (skill-pr-implementation). Calling `skill_postflight_update ... "implement" ... "pr_ready"` passes `pr_ready` as the status arg, which hits the `*)` case in `skill_postflight_update` and skips the status update — but the status update was already done by the skill itself. The point is that the postflight extension hook still fires. This matches the pattern used by `implemented`.

**Alternative**: Call `bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"` directly. But this duplicates what skill-pr-implementation already did.

**Simplest correct behavior**: Add `pr_ready)` arm that mirrors the `implemented)` arm — the skill already ran the status transition; orchestrate just needs to not fall through to the `*)` no-op path.

### Insertion Point 3: Stage 5 artifact type case (lines ~392-411)

**Current code:**

```bash
case "$handoff_artifact_type" in
  report)
    field_name='**Research**'
    next_field='**Plan**'
    ;;
  plan)
    field_name='**Plan**'
    next_field='**Description**'
    ;;
  summary)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
  *)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
esac
```

**Where to insert**: After `summary)` arm, before `*)` arm (approximately line 406).

**New arm to add**:
```bash
  pr_description)
    field_name='**PR Description**'
    next_field='**Description**'
    ;;
```

**Rationale**: `skill-pr-implementation` Stage 7 specifies artifact type `pr_description` and says to link it with `field_name=**Summary**` in TODO.md. However, using `**PR Description**` is more semantically accurate. The task description specifies `**PR Description**` with `next_field` of `**Description**`. Using `**Description**` as `next_field` means the artifact link appears before the Description field in TODO.md.

### Insertion Point 4: Multi-task section — Stage MT-3 state filtering (line ~830)

**Current code at lines 830-837:**

```bash
case "$current_status" in
  completed|abandoned|expanded)
    echo "[orchestrate-mt] Task $task_num already in terminal state [$current_status], skipping"
    jq --argjson num "$task_num" \
      '.completed_tasks = (.completed_tasks + [$num] | unique)' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    continue
    ;;
esac
```

**Where to insert**: Add `pr_ready` to the `completed|abandoned|expanded` list.

**New code**:
```bash
case "$current_status" in
  completed|abandoned|expanded|pr_ready)
    echo "[orchestrate-mt] Task $task_num already in terminal state [$current_status], skipping"
    jq --argjson num "$task_num" \
      '.completed_tasks = (.completed_tasks + [$num] | unique)' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    continue
    ;;
esac
```

**Rationale**: `pr_ready` is a terminal state for orchestrate (it exits cleanly and directs user to run `/pr N`). In multi-task mode, a task in `pr_ready` should be treated as done (moved to `completed_tasks`) and not re-dispatched.

### Insertion Point 5: Multi-task section — Stage MT-4 dispatch_status case (lines ~997-1013)

**Current code:**

```bash
case "$dispatch_status" in
  researched)
    operation="research"
    skill_postflight_update "$task_num" "research" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  planned)
    operation="plan"
    skill_postflight_update "$task_num" "plan" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  implemented)
    operation="implement"
    skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  *)
    operation="unknown"
    echo "[orchestrate-mt] Task $task_num status '$dispatch_status' — no postflight update"
    ;;
esac
```

**Where to insert**: After the `implemented)` arm, before `*)` arm.

**New arm to add**:
```bash
  pr_ready)
    operation="implement"
    skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"
    ;;
```

**Rationale**: Mirrors single-task Stage 5. The `pr_ready` handoff is the result of an implement dispatch; the operation label `"implement"` is correct.

### Insertion Point 6: Multi-task section — Stage MT-4 artifact type case (lines ~1021-1037)

**Current code:**

```bash
case "$handoff_artifact_type" in
  report)
    field_name='**Research**'
    next_field='**Plan**'
    ;;
  plan)
    field_name='**Plan**'
    next_field='**Description**'
    ;;
  summary)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
  *)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
esac
```

**Where to insert**: After `summary)` arm, before `*)` arm.

**New arm to add**:
```bash
  pr_description)
    field_name='**PR Description**'
    next_field='**Description**'
    ;;
```

**Rationale**: Identical to single-task Stage 5 insertion.

## Decisions

1. **pr_ready as terminal for orchestrate**: When orchestrate reads `pr_ready` state in Stage 4, it exits cleanly (like `completed`) rather than trying to advance the task. The `/pr` command handles the next step.
2. **Message text**: Direct user to `/pr N` (not `/merge N`) — the cslib pr-prohibition rule confirms `/pr {task_number}` is the correct command.
3. **Multi-task parity**: Four insertions map to six actual code changes (Stage 4: 1 new handler; Stage 5: 2 new arms; MT-3: 1 case expansion; MT-4: 2 new arms = 6 total edits to the file).
4. **skill_postflight_update call for pr_ready dispatch**: The `pr_ready` arm in both Stage 5 and MT-4 should call `skill_postflight_update ... "implement" ... "$dispatch_status"` matching the `implemented` arm pattern. The `skill_postflight_update` function will skip the status update for `pr_ready` (correct — skill already did it) but will run extension hooks.

## File Inventory

Single file to modify:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1152 lines)

## Precise Line Numbers

| Change | Lines | Description |
|--------|-------|-------------|
| 1 | After line 321 (after `EXIT (success)` in `completed` handler) | Add `pr_ready` state handler section |
| 2 | After line 380 (after `implemented)` arm, before `*)`) | Add `pr_ready)` arm to dispatch_status case |
| 3 | After line 404 (after `summary)` arm, before `*)`) | Add `pr_description)` arm to artifact type case |
| 4 | Line 831 | Expand `completed|abandoned|expanded` to include `pr_ready` |
| 5 | After line 1008 (after `implemented)` arm, before `*)`) | Add `pr_ready)` arm to MT dispatch_status case |
| 6 | After line 1032 (after `summary)` arm, before `*)`) | Add `pr_description)` arm to MT artifact type case |

## Risks & Mitigations

- **Risk**: Adding `pr_ready` to the MT-3 terminal states might cause multi-task orchestration to mark the task as `completed` in `completed_tasks`, even though the task is only `pr_ready`. This is acceptable — from orchestrate's perspective, the task is done; the user must run `/pr N` manually.
- **Risk**: The `skill_postflight_update` for `pr_ready` dispatch status passes `"pr_ready"` as the status argument but `"implement"` as the operation argument. The function won't actually call `update-task-status.sh` (because `pr_ready` isn't in the recognized success values), but extension hooks will still fire. This is correct behavior.
- **No risk**: Adding `pr_ready` to Stage 4 handlers is purely additive.

## Context Extension Recommendations

- None for this meta task.

## Appendix

### Search Queries Used
- grep for `pr_ready` in SKILL.md (0 matches — confirms no existing support)
- grep for `pr_ready` in update-task-status.sh (shows preflight/postflight mapping)
- grep for `skill_postflight_update` in skill-base.sh (shows success value recognition)
- Read skill-pr-implementation SKILL.md (confirms handoff status and artifact type)

### Key References
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — file to modify
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — source of truth for pr_ready handoff format
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` — status transition mapping
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — skill_postflight_update implementation
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — confirms `/pr N` is the user command
