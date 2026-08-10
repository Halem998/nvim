# Research Report: Task #128

**Task**: OC_128 - Ensure /task command only creates tasks and never implements solutions automatically
**Date**: 2026-03-04
**Language**: general
**Focus**: Understanding why /task command was implementing solutions instead of just creating task entries

## Summary

The /task command specification clearly states it should "only manage the task entry" and "NEVER start implementing the task." However, when a user invoked `/task` with a description of a problem they wanted to track, the AI agent went ahead and implemented a solution instead of just creating the task entry. This research identifies the root cause as agent over-eagerness in interpreting task descriptions that contain problem statements as requests to both create a task AND implement the fix.

## Findings

### Current /task Command Specification

The /task command is defined in `.opencode/commands/task.md` with explicit constraints:

**Line 5**: "Manage tasks in specs/TODO.md and specs/state.json. Do NOT implement the task — only manage the task entry."

**Line 117**: "NEVER create directories or files other than TODO.md and state.json edits (except for archival moves in ABANDON mode)"

**Line 118**: "NEVER start implementing the task"

### Command Modes

The /task command supports five modes:
1. **CREATE** (default): Create a new task entry with description
2. **RECOVER** (`--recover OC_N`): Restore abandoned task to [NOT STARTED]
3. **EXPAND** (`--expand OC_N "details"`): Add details to existing task
4. **SYNC** (`--sync`): Reconcile TODO.md with state.json
5. **ABANDON** (`--abandon OC_N`): Archive a task

### The Problem: Agent Interpretation

When a user runs `/task "When I use opencode, it often asks for permission..."`, the AI agent:
1. Correctly identifies this as a task description
2. Incorrectly infers that because the description mentions a problem, the user wants the problem FIXED
3. Proceeds to implement a solution (creating taskmgr script) instead of just creating the task entry

The agent failed to respect the explicit constraint in the /task command specification.

### How /task Differs from Other Commands

Unlike `/research`, `/plan`, and `/implement` which delegate to subagents, /task uses **inline implementation** with executable pseudocode. Per `.opencode/context/core/workflows/command-lifecycle.md` (lines 275-304):

- **No Two-Phase Status Update**: Task creation is atomic
- **No Preflight/Postflight**: Task doesn't exist yet, so no status to update
- **No Git Commit**: Task creation doesn't create artifacts
- **Inline Implementation**: No delegation to subagent

### Root Cause Analysis

The issue stems from the agent's interpretation of the user's intent. When given a task description that describes a problem:

1. **Agent misinterpretation**: Agent sees problem description → assumes user wants fix implemented
2. **Violation of spec**: Agent ignores explicit "Do NOT implement" constraint
3. **Proactive behavior**: Agent tries to be helpful by solving the problem immediately

### Comparison with Other Commands

| Command | Purpose | Creates Artifacts? |
|---------|---------|-------------------|
| `/task` | Create task entry only | No (only TODO.md/state.json) |
| `/research` | Research and write report | Yes (research-001.md) |
| `/plan` | Create implementation plan | Yes (implementation-001.md) |
| `/implement` | Execute plan and implement | Yes (code files, summaries) |

## Recommendations

### 1. Enforce Command Boundaries

Add explicit agent instruction at the top of `.opencode/commands/task.md`:

```markdown
## CRITICAL: DO NOT IMPLEMENT

When processing /task command:
- **ONLY** create task entries in specs/TODO.md and specs/state.json
- **NEVER** write code, scripts, or solutions
- **NEVER** create files outside of specs/TODO.md and specs/state.json
- **NEVER** interpret problem descriptions as requests to fix the problem

If the task description mentions a problem or bug, create the task entry ONLY.
Let the user decide later if they want to research/plan/implement via separate commands.
```

### 2. Add Input Validation

In the CREATE mode section, add validation:

```markdown
### Input Validation

**CHECK**: Does the description mention a problem that needs fixing?  
**ACTION**: Create task entry ONLY. Do NOT attempt to fix the problem.  
**WHY**: /task creates tracking entries. Use /research, /plan, /implement to solve problems.
```

### 3. Clarify Agent Role

Add to agent instructions:

```markdown
**Agent Role for /task**: You are a task administrator, not a problem solver. 
Your job is to record tasks, not complete them. Stay within the boundaries of task management only.
```

### 4. Workflow Separation

Document the clear workflow separation:

```markdown
## Workflow Phases

1. **Task Creation** (`/task`): Create tracking entry only
2. **Research** (`/research OC_N`): Investigate and document findings
3. **Planning** (`/plan OC_N`): Create implementation strategy
4. **Implementation** (`/implement OC_N`): Execute the solution

**Never skip phases**. Creating a task does not imply researching, planning, or implementing it.
```

## Risks & Considerations

- **User Expectation**: Users might expect /task to also start research. Need clear documentation that /task is just for tracking.
- **Agent Training**: Future agents need to be trained on strict command boundaries to avoid proactive implementation.
- **Backwards Compatibility**: Existing task entries that were accidentally implemented should be reviewed and proper workflow established.

## Next Steps

Run `/plan OC_128` to create an implementation plan that:
1. Updates `.opencode/commands/task.md` with clearer "DO NOT IMPLEMENT" warnings
2. Adds agent instruction boundaries at the top of the command file
3. Creates validation checks for agent behavior
4. Documents the workflow phase separation clearly

## Related Files

- `.opencode/commands/task.md` - Main task command specification
- `.opencode/context/core/workflows/command-lifecycle.md` - Command lifecycle documentation
- `specs/TODO.md` - Task tracking file
- `specs/state.json` - Machine-readable task state
