# Research Report: Task #207

**Task**: 207 - create_grant_command
**Started**: 2026-03-15T10:00:00Z
**Completed**: 2026-03-15T10:15:00Z
**Effort**: 1-2 hours
**Dependencies**: Task 206 (skill-grant wrapper must exist)
**Sources/Inputs**: Codebase exploration of .claude/commands/, .claude/skills/, .claude/extensions/grant/
**Artifacts**: This report at specs/207_create_grant_command/reports/01_grant-command-research.md
**Standards**: report-format.md, CLAUDE.md command structure

## Executive Summary

- Grant command should follow the checkpoint-based execution pattern: GATE IN -> DELEGATE (skill) -> GATE OUT -> COMMIT
- Command should parse grant-specific arguments: task number, workflow_type (funder_research, proposal_draft, budget_develop, progress_track)
- skill-grant already exists in `.claude/extensions/grant/skills/skill-grant/SKILL.md` - command delegates to this skill
- Postflight operations (status updates, git commits) are handled by skill-grant internally, not by the command
- Command structure should mirror `/research` and `/plan` commands with grant-specific argument parsing

## Context & Scope

This research analyzes existing command patterns in `.claude/commands/` to determine how to create a new `/grant` command for the grant extension. The command must:

1. Be placed in `.claude/extensions/grant/commands/grant.md` (extension-local)
2. Parse grant-specific arguments (task_number, workflow_type, optional focus)
3. Invoke skill-grant via the Skill tool
4. Handle postflight verification (but not status updates - skill handles those)

## Findings

### 1. Command File Structure

All commands in `.claude/commands/` follow a consistent YAML frontmatter pattern:

```yaml
---
description: Brief description of command purpose
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: ARGUMENT_FORMAT
model: claude-opus-4-5-20251101
---
```

**Key Fields**:
| Field | Purpose | Grant Command Value |
|-------|---------|---------------------|
| `description` | One-line description | "Execute grant workflows (funder research, proposal drafting, budget development)" |
| `allowed-tools` | Tools available to command | `Skill, Bash(jq:*), Bash(git:*), Read, Edit` |
| `argument-hint` | User-visible argument format | `TASK_NUMBER WORKFLOW_TYPE [FOCUS]` |
| `model` | Preferred model | `claude-opus-4-5-20251101` |

### 2. Checkpoint-Based Execution Pattern

All task-based commands follow a 3-checkpoint structure:

```
CHECKPOINT 1: GATE IN (Preflight)
  - Generate session ID
  - Lookup task from state.json
  - Validate task exists and status allows operation
  - Abort if validation fails

STAGE 2: DELEGATE
  - Invoke skill via Skill tool
  - Pass task_number, session_id, workflow-specific args

CHECKPOINT 2: GATE OUT (Postflight)
  - Validate return from skill
  - Verify artifacts exist
  - Verify status was updated (by skill)
  - Retry if validation fails

CHECKPOINT 3: COMMIT
  - Git add and commit
  - Non-blocking on failure
```

### 3. Argument Parsing Patterns

#### Simple Task Number Parsing (from /research, /plan, /implement)

```markdown
## Arguments

- `$1` - Task number (required)
- Remaining args - Optional focus/prompt
```

The command extracts task_number from $ARGUMENTS and passes remaining text as focus.

#### Flag-Based Parsing (from /task, /tag)

For commands with flags like `--recover`, `--expand`, parsing checks for specific prefixes:

```markdown
Check $ARGUMENTS for flags:
- `--recover RANGES` -> Recover tasks
- `--expand N [prompt]` -> Expand task
- No flag -> Default behavior
```

#### Grant Command Argument Design

The grant command needs a hybrid approach:

```
/grant TASK_NUMBER WORKFLOW_TYPE [FOCUS]

Examples:
/grant 500 funder_research
/grant 500 proposal_draft "Focus on methodology section"
/grant 500 budget_develop
/grant 500 progress_track
```

**Parsing Logic**:
1. First argument: task_number (integer)
2. Second argument: workflow_type (one of: funder_research, proposal_draft, budget_develop, progress_track)
3. Remaining arguments: optional focus prompt

### 4. Skill Tool Invocation Pattern

Commands invoke skills using the Skill tool, not Task tool directly.

**From /research command**:
```markdown
### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 passes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-researcher"
args: "task_number={N} focus={focus_prompt} session_id={session_id}"
```

The skill will spawn the appropriate agent to conduct research and create a report.
```

**For Grant Command**:
```
skill: "skill-grant"
args: "task_number={N} workflow_type={type} focus={focus_prompt} session_id={session_id}"
```

Note: skill-grant exists at `.claude/extensions/grant/skills/skill-grant/SKILL.md` and expects:
- task_number (required)
- workflow_type (required): funder_research, proposal_draft, budget_develop, progress_track
- focus_prompt (optional)
- session_id (required)

### 5. Postflight Checkpoint Pattern

Commands verify skill return and artifacts:

**From /research command**:
```markdown
### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts

2. **Verify Artifacts**
   Check each artifact path exists on disk

3. **Verify Status Updated**
   The skill handles status updates internally (preflight and postflight).
   Confirm status is now "researched" in state.json.

**RETRY** skill if validation fails.
```

**Key Insight**: skill-grant already handles status updates internally (preflight to "researching"/"planning", postflight to "researched"/"planned"). The command only verifies the updates occurred.

### 6. Git Commit Pattern

```markdown
### CHECKPOINT 3: COMMIT

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete {action}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).
```

**For Grant Command**, commit messages should reflect workflow_type:
- funder_research: "task {N}: complete funder research"
- proposal_draft: "task {N}: create proposal draft"
- budget_develop: "task {N}: develop budget"
- progress_track: "task {N}: update progress"

### 7. Error Handling Patterns

Commands handle errors at each checkpoint:

```markdown
## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Invalid status: Return error with current status

### DELEGATE Failure
- Skill fails: Keep status unchanged, log error
- Timeout: Partial progress preserved, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning
```

### 8. Extension Command Location

The grant command should be placed in the extension directory:

```
.claude/extensions/grant/
  commands/
    grant.md         <-- NEW: Grant command
  skills/
    skill-grant/
      SKILL.md       <-- Already exists
  agents/
    grant-agent.md   <-- Already exists
  context/
    project/grant/   <-- Already exists
  manifest.json      <-- Update: add command to provides.commands
```

The manifest.json currently shows `"commands": []` and must be updated to include the new command.

### 9. Workflow Type to Status Mapping

From skill-grant SKILL.md, the workflow types map to statuses:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| funder_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| proposal_draft | planning | planned | [PLANNING] -> [PLANNED] |
| budget_develop | planning | planned | [PLANNING] -> [PLANNED] |
| progress_track | (no change) | (no change) | (no change) |

The command should validate that the returned status matches expectations based on workflow_type.

## Decisions

1. **Command Location**: Place in `.claude/extensions/grant/commands/grant.md` to keep extension self-contained
2. **Argument Format**: `TASK_NUMBER WORKFLOW_TYPE [FOCUS]` - simple positional parsing
3. **Delegation**: Invoke skill-grant via Skill tool (not Task tool)
4. **Status Handling**: Command verifies but does not update status (skill handles this)
5. **Git Commits**: Workflow-specific commit messages handled by command, not skill (skill does internal commit, command does final commit)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Extension not loaded when command invoked | Add validation check for extension presence |
| Invalid workflow_type provided | Early validation in GATE IN with user-friendly error |
| Skill returns partial status | Command preserves partial state for resume |
| Git commit conflicts with skill's internal commit | Review skill - skill-grant already handles commits, command may skip CHECKPOINT 3 |

**Note on Commits**: skill-grant already performs git commits in Stage 9. The command may need to either:
1. Skip CHECKPOINT 3 entirely (let skill handle all commits)
2. Only commit if skill returned success but didn't commit (unlikely edge case)

Recommend Option 1: Remove CHECKPOINT 3 from grant command since skill-grant handles commits.

## Recommendations

### Implementation Approach

1. **Create command file** at `.claude/extensions/grant/commands/grant.md`
2. **Use simplified checkpoint pattern**:
   - CHECKPOINT 1: GATE IN (validate task, parse workflow_type)
   - STAGE 2: DELEGATE (invoke skill-grant)
   - CHECKPOINT 2: GATE OUT (verify return, no commit - skill handles it)
3. **Update manifest.json** to register the command

### Command Template

```markdown
---
description: Execute grant workflows (funder research, proposal drafting, budget development)
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER WORKFLOW_TYPE [FOCUS]
model: claude-opus-4-5-20251101
---

# /grant Command

Execute grant workflows for a task by delegating to skill-grant.

## Arguments

- `$1` - Task number (required)
- `$2` - Workflow type (required): funder_research, proposal_draft, budget_develop, progress_track
- Remaining args - Optional focus/prompt

## Execution

### CHECKPOINT 1: GATE IN
{validation logic}

### STAGE 2: DELEGATE
{skill invocation}

### CHECKPOINT 2: GATE OUT
{return validation - no commit, skill handles it}

## Output
{success/error messages}

## Error Handling
{error cases}
```

## Appendix

### Search Queries Used

1. `Glob: .claude/commands/**/*.md` - Found all existing commands
2. `Glob: .claude/skills/**/*.md` - Found all existing skills
3. `Glob: **/*grant*/**` - Found grant extension structure
4. `Read: .claude/commands/research.md` - Reference for checkpoint pattern
5. `Read: .claude/commands/plan.md` - Reference for skill invocation
6. `Read: .claude/commands/task.md` - Reference for argument parsing
7. `Read: .claude/commands/meta.md` - Reference for skill delegation
8. `Read: .claude/skills/skill-researcher/SKILL.md` - Reference for skill structure
9. `Read: .claude/skills/skill-grant/SKILL.md` - Target skill for delegation
10. `Read: .claude/extensions/grant/manifest.json` - Extension structure
11. `Read: .claude/docs/guides/creating-commands.md` - Command authoring guide

### References to Documentation

- `.claude/CLAUDE.md` - Command reference and checkpoint pattern
- `.claude/docs/guides/creating-commands.md` - Command creation guide
- `.claude/context/core/formats/report-format.md` - Report format standard
- `.claude/rules/git-workflow.md` - Git commit conventions
