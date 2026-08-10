# Research Report: Task #650

**Task**: 650 - Create update-phase-status.sh for phase-level plan tracking
**Started**: 2026-06-10T00:00:00Z
**Completed**: 2026-06-10T00:10:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/scripts/update-plan-status.sh` — existing plan-level status script
- `.claude/scripts/skill-base.sh` — skill lifecycle functions
- `.claude/skills/skill-implementer/SKILL.md` — implementation skill
- `.claude/agents/general-implementation-agent.md` — implementation agent
- `.claude/rules/plan-format-enforcement.md` — plan format rules
- `.claude/rules/artifact-formats.md` — artifact format rules
- `.claude/scripts/update-task-status.sh` — task status update script
- `specs/638_fix_generate_task_order_missing_section/plans/01_fix-task-order-bootstrap.md` — example plan
- `.claude/logs/subagent-postflight.log` — existing log format reference
**Artifacts**: specs/650_create_update_phase_status_script/reports/01_phase-status-research.md
**Standards**: report-format.md

## Executive Summary

- Phase markers in plan files use the format `### Phase N: {name} [STATUS]` with status in the heading only
- The existing `update-plan-status.sh` handles plan-level header status (`[IMPLEMENTING]`, `[COMPLETED]`, `[PARTIAL]`) not individual phases
- `general-implementation-agent` handles phase status manually via the `Edit` tool with hard-coded `old_string`/`new_string` patterns — there is no centralized script for this today
- The proposed `update-phase-status.sh` should accept `TASK_NUMBER`, `PROJECT_NAME`, `PHASE_NUMBER`, and `NEW_STATUS` and update the matching phase heading in the latest plan file
- Logging should follow the existing `[YYYY-MM-DDThh:mm:ss-TZ]` ISO timestamp pattern used in `.claude/logs/subagent-postflight.log`

## Context & Scope

The task requests a new shell script, `.claude/scripts/update-phase-status.sh`, that updates individual phase status markers in plan files (e.g., `[NOT STARTED]` → `[IN PROGRESS]` → `[COMPLETED]`). The existing `update-plan-status.sh` only updates the plan-level `**Status**:` metadata field in the plan header and does not touch phase headings. This creates a gap: implementation agents update phase headings manually via inline `Edit` calls, making phase progress invisible to external observers unless they read the plan file.

The new script will be called from `general-implementation-agent` (and optionally from `skill-implementer` postflight) at phase boundaries to centralize the update logic and add logging for oversight.

## Findings

### Phase Marker Format in Plan Files

From examining `plan-format-enforcement.md` and actual plan files:

**Phase heading pattern** (authoritative from `plan-format-enforcement.md`):
```
### Phase N: {name} [STATUS]
```

**Valid status markers** (same as plan-level markers):
- `[NOT STARTED]` — Phase not begun
- `[IN PROGRESS]` — Currently executing
- `[COMPLETED]` — Phase finished
- `[PARTIAL]` — Partially complete (interrupted)
- `[BLOCKED]` — Cannot proceed (rare at phase level)

**Key constraint from `general-implementation-agent.md`**: "Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase."

**Example phase heading** (from plan file `638`):
```markdown
### Phase 1: Apply patch to all four project scripts [COMPLETED]
### Phase 2: Validate fix on each project [COMPLETED]
```

**Regex to match a phase heading**:
```bash
^### Phase ${phase_number}: .* \[.*\]$
```

**Regex to capture just the status**:
```bash
sed -n "s/^### Phase ${phase_number}: .* \[\(.*\)\]$/\1/p"
```

### Existing update-plan-status.sh Behavior

The existing script (`.claude/scripts/update-plan-status.sh`) handles the plan-level `**Status**:` header field:

```
- **Status**: [IMPLEMENTING]
- **Status**: [COMPLETED]
```

It uses `sed -i` with a range pattern to replace only the first match:
```bash
sed -i "0,/^- \*\*Status\*\*: \[.*\]/{s/^- \*\*Status\*\*: \[.*\]$/- **Status**: [${new_status}]/}" "$plan_file"
```

It does **not** touch phase headings (`### Phase N: ...`). The new `update-phase-status.sh` will be a sibling script focused exclusively on phase headings.

**Interface of update-plan-status.sh**:
```bash
update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS
# STATUS values: IMPLEMENTING, COMPLETED, PARTIAL, PLANNED, NOT_STARTED
# Output: Updated plan file path on success, exit 1 on error
```

### Where Phase Status Is Currently Updated

In `general-implementation-agent.md`, phases are updated manually via the `Edit` tool:

**Mark phase in-progress (Stage 4A)**:
```
old_string: ### Phase {P}: {Phase Name} [NOT STARTED]
new_string: ### Phase {P}: {Phase Name} [IN PROGRESS]
```

**Mark phase complete (Stage 4D)**:
```
old_string: ### Phase {P}: {Phase Name} [IN PROGRESS]
new_string: ### Phase {P}: {Phase Name} [COMPLETED]
```

These `Edit` calls currently happen inline in the agent's execution loop. The new script would be called in place of (or alongside) these `Edit` calls to:
1. Centralize the sed logic
2. Add a log entry for oversight
3. Enable `skill-implementer` postflight to query phase progress

### Integration Points

**A. general-implementation-agent (Stage 4A and 4D)**

The agent currently uses inline `Edit` calls. The new script can be invoked via `Bash` instead:

```bash
# Stage 4A: Mark phase in-progress
bash .claude/scripts/update-phase-status.sh "$task_number" "$PROJECT_NAME" "$phase_number" "IN_PROGRESS"

# Stage 4D: Mark phase complete
bash .claude/scripts/update-phase-status.sh "$task_number" "$PROJECT_NAME" "$phase_number" "COMPLETED"
```

**B. skill-implementer postflight (Stage 6b, commit message)**

Currently skill-implementer reads `phases_completed` and `phases_total` from `.return-meta.json`. With `update-phase-status.sh` logging transitions, the skill could also query the plan file to count `[COMPLETED]` phase headings as a cross-check.

**C. skill-base.sh (optional helper function)**

A helper like `skill_update_phase_status()` could wrap the script call for convenience in postflight bash blocks.

### Script Design Recommendation

**Proposed interface**:
```bash
update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS
# PHASE_NUMBER: integer (1-based)
# NEW_STATUS: NOT_STARTED, IN_PROGRESS, COMPLETED, PARTIAL, BLOCKED
# Output: Updated plan file path on success, exit 1 on error
# Side effect: Appends to .claude/logs/phase-transitions.log
```

**Core logic**:
1. Find plan file (same logic as `update-plan-status.sh` — padded directory, latest `.md` file)
2. Locate the phase heading using `grep -n`
3. Extract current status for idempotency check
4. Replace `[OLD STATUS]` with `[NEW STATUS]` on that specific line using `sed -i`
5. Verify the update succeeded
6. Append log entry

**sed pattern for phase-level update** (targeting a specific line by number):
```bash
sed -i "${line_number}s/\[.*\]/[${new_status_pretty}]/" "$plan_file"
```

This is safer than a range pattern because it only modifies the exact line containing the phase heading.

### Logging Format Recommendation

Existing logs (`.claude/logs/sessions.log`, `.claude/logs/subagent-postflight.log`) use:
```
[2026-01-18T22:37:36-08:00] Message text
```

The new log file should follow this pattern and live at:
```
.claude/logs/phase-transitions.log
```

**Log entry format**:
```
[2026-06-10T12:34:56-07:00] task 650 plan file.md phase 1: NOT STARTED -> IN PROGRESS
```

Fields: timestamp, task number, plan file basename (for brevity), phase number, old status, new status.

**Append semantics**: Always append (`>>`) to the log file. Create the file if it doesn't exist (standard `>>` behavior). No rotation needed initially — same pattern as `sessions.log`.

### Relationship to update-plan-status.sh

| Script | Scope | Updates | Called By |
|--------|-------|---------|-----------|
| `update-plan-status.sh` | Plan-level header | `- **Status**: [...]` | `update-task-status.sh` Phase 4 |
| `update-phase-status.sh` (new) | Phase headings | `### Phase N: ... [...]` | `general-implementation-agent` Stages 4A, 4D |

Both scripts:
- Accept `TASK_NUMBER` and `PROJECT_NAME` (for plan file discovery)
- Find the latest plan file in `specs/{NNN}_{project}/plans/`
- Output the plan file path on success
- Are idempotent (no-op if already at target status)

The new script additionally accepts `PHASE_NUMBER` and logs to `phase-transitions.log`.

## Decisions

- **Log file location**: `.claude/logs/phase-transitions.log` — consistent with existing log directory
- **Phase number matching**: Use `grep -n` to find the exact line number, then `sed -i "${line}s/.../.../"`  — safer than range patterns
- **No side effects on plan-level status**: `update-phase-status.sh` only modifies phase headings, never the `**Status**:` header (that remains `update-plan-status.sh`'s responsibility)
- **Non-blocking on failure**: Like `update-plan-status.sh`, exit with non-zero but allow callers to handle as warning

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase number collision (two phases with same number) | M | L | Phase headings must be unique by design; grep returns first match |
| Plan file has non-standard phase heading format | M | L | Validate the line before replacing; exit non-zero if not found |
| Concurrent writes from multi-agent team mode | H | L | Use file locking (flock) consistent with update-task-status.sh |
| Log file grows unbounded | L | L | Append semantics accepted; no rotation initially (same as sessions.log) |
| Status value mismatch with plan-format spec | M | L | Validate allowed values at entry; map user-friendly inputs to canonical strings |

## Proposed Script Interface (Summary)

```bash
#!/usr/bin/env bash
# update-phase-status.sh - Update phase-level status marker in plan file
# Usage: .claude/scripts/update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS
#
# PHASE_NUMBER: 1-based integer matching "### Phase N:" in the plan file
# NEW_STATUS values: IN_PROGRESS, COMPLETED, PARTIAL, BLOCKED, NOT_STARTED
# Output: Updated plan file path on success, empty on failure/no-op
# Log: Appends to .claude/logs/phase-transitions.log

# Arguments: task_number, project_name, phase_number, new_status
# Find plan file (same logic as update-plan-status.sh)
# Grep for "^### Phase {phase_number}:" to find line number
# Extract current status from that line
# Idempotency check: skip if already at target
# sed -i "${line}s/\[.*\]/[${new_status}]/" plan_file
# Verify update
# Log: echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] task $task_number $plan_basename phase $phase_number: $old_status -> $new_status" >> .claude/logs/phase-transitions.log
```

## Context Extension Recommendations

- **Topic**: Phase-level status tracking patterns
- **Gap**: No existing context file documents the relationship between `update-plan-status.sh` (plan-level) and the manual Edit calls (phase-level) in implementation agents. Future agents would benefit from a clear explanation of when to use each mechanism.
- **Recommendation**: After implementing `update-phase-status.sh`, add a brief note to `.claude/context/patterns/` (e.g., `phase-status-updates.md`) documenting the two-script model.

## Appendix

### Search Queries Used

- Glob: `specs/*/plans/*.md` — found 5 plan files
- Read: `.claude/scripts/update-plan-status.sh` — found plan-level status update logic
- Read: `.claude/scripts/skill-base.sh` — confirmed no existing phase-level helper
- Read: `.claude/skills/skill-implementer/SKILL.md` — confirmed phase commit pattern and postflight phases_completed reading
- Read: `.claude/agents/general-implementation-agent.md` — found inline Edit pattern for phase status
- Read: `.claude/rules/plan-format-enforcement.md` — confirmed `### Phase N: {name} [STATUS]` format
- Read: `.claude/rules/artifact-formats.md` — confirmed status marker values
- Read: `.claude/scripts/update-task-status.sh` — reviewed locking and multi-phase update pattern
- Read: `specs/638.../plans/01_fix-task-order-bootstrap.md` — confirmed real phase heading examples
- Bash: `head -100 .claude/logs/subagent-postflight.log` — confirmed log timestamp format

### References

- `.claude/scripts/update-plan-status.sh` — plan-level update (model for new script)
- `.claude/scripts/update-task-status.sh` — flock pattern and multi-phase update model
- `.claude/agents/general-implementation-agent.md` Stage 4A/4D — current phase edit pattern
- `.claude/rules/plan-format-enforcement.md` — phase heading format spec
- `.claude/rules/artifact-formats.md` — phase status marker values
