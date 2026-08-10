# Research Report: Task #241

**Task**: 241 - Add /spawn command, skill-spawn wrapper, and spawn-agent for blocked task recovery
**Generated**: 2026-03-19
**Source**: /meta prompt analysis (auto-generated)
**Status**: Pre-populated from prompt context

---

## Context Summary

**Purpose**: Create a /spawn workflow command that recovers from blocked implementations by researching the blocker, decomposing it into minimal new tasks, and establishing proper dependency relationships between new tasks and the parent blocked task.

**Scope**: Three new .claude/ system components:
- `.claude/commands/spawn.md` - User-facing command
- `.claude/skills/skill-spawn/SKILL.md` - Thin wrapper skill with dependency-update postflight
- `.claude/agents/spawn-agent.md` - Blocker analysis and task decomposition agent

**Affected Components**: .claude/commands/, .claude/skills/, .claude/agents/, CLAUDE.md (Skill-to-Agent Mapping)

**Domain**: meta
**Language**: meta

---

## Task Requirements

### /spawn Command (`.claude/commands/spawn.md`)

**Syntax**: `/spawn N [prompt]`

**Arguments**:
- `N` (required) - Task number of the blocked task
- `prompt` (optional) - Free-text description of the blocker (e.g., "missing API endpoint", "upstream library incompatible")

**Argument Hint**: `TASK_NUMBER [blocker description]`

**Allowed Tools**: `Skill, Bash(jq:*), Bash(git:*), Read, Glob`

**Model**: `claude-opus-4-5-20251101` (consistent with other workflow commands)

**CHECKPOINT 1: GATE IN**

1. Generate session ID: `sess_{timestamp}_{random}`
2. Display header: `[Spawning] Task {N}: {project_name}`
3. Lookup task from state.json via jq
4. Validate:
   - Task exists (ABORT if not)
   - Status allows spawn: `implementing`, `partial`, `blocked`, `planned`, `researched` (anything that can become blocked)
   - If `completed`: ABORT "Task is already complete. Nothing to spawn."
   - If `abandoned`: ABORT "Task is abandoned. Recover it first with /task --recover N."
5. Extract optional blocker prompt from $ARGUMENTS (everything after the task number)
6. Load task context: read latest plan from `specs/{NNN}_{SLUG}/plans/*.md` (if exists)

**STAGE 2: DELEGATE**

Invoke `skill-spawn` with delegation context:
```json
{
  "session_id": "...",
  "task_number": N,
  "task_data": { ... },
  "blocker_prompt": "optional user description",
  "plan_path": "path/to/latest/plan or null"
}
```

**CHECKPOINT 2: GATE OUT**

After skill returns, display summary of tasks created and next steps.

**Git Commit**: The skill handles state updates and git commit internally (postflight pattern). The command does not commit.

---

### skill-spawn Wrapper (`.claude/skills/skill-spawn/SKILL.md`)

Follows the thin-wrapper-skill pattern. Delegates to spawn-agent, then in postflight: reads the agent's return metadata to create new task entries, update the parent task's dependencies, and commit.

**Frontmatter**:
```yaml
name: skill-spawn
description: Research blockers and spawn new tasks to overcome them, updating parent task dependencies
version: "1.0"
author: meta-builder-agent
```

**Execution Flow** (12 stages):

1. **Parse delegation context** from command (task_number, task_data, blocker_prompt, plan_path, session_id)

2. **Preflight status update**: Set parent task status to `blocked` in state.json (if not already):
   ```bash
   jq --arg num "$task_number" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '(.active_projects[] | select(.project_number == ($num | tonumber)) | .status) = "blocked" |
      (.active_projects[] | select(.project_number == ($num | tonumber)) | .last_updated) = $ts' \
     specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   ```

3. **Update TODO.md parent task status** to `[BLOCKED]`

4. **Delegate to spawn-agent** via Task tool with full context

5. **Read return metadata** from `specs/{NNN}_{SLUG}/.spawn-return.json`:
   ```json
   {
     "new_tasks": [
       { "title": "...", "description": "...", "effort": "...", "language": "meta", "dependencies": [] },
       { "title": "...", "description": "...", "effort": "...", "language": "meta", "dependencies": [0] }
     ],
     "dependency_order": [0, 1],
     "parent_task_number": 241,
     "analysis_summary": "...",
     "report_path": "specs/241_.../reports/02_spawn-analysis.md"
   }
   ```

6. **Get next task numbers** from state.json

7. **Apply topological sort** (Kahn's algorithm) to `dependency_order` from agent to determine insertion order and assign task numbers. Internal dependency indices (0-based) map to assigned task numbers.

8. **Create new task directories** and research artifact stubs (using agent's report as pre-existing research)

9. **Update state.json** - Insert new tasks (in topological order, foundational tasks first) with:
   - `parent_task: N` field referencing the blocked task
   - `dependencies` array with resolved task numbers (internal deps converted to task numbers)
   - `status: "researched"` (since agent wrote a research report)
   - `artifacts` array pointing to the spawn analysis report

10. **Update TODO.md** - Insert new task entries in dependency order with:
    - `- **Parent Task**: #N` field
    - `- **Dependencies**: Task #X, Task #Y` or `None`
    - `- **Status**: [RESEARCHED]`
    - `- **Research**: [link to spawn analysis report]`

11. **Update parent task in state.json** - Add new task numbers to `dependencies` array:
    ```bash
    jq --argjson new_deps "[242, 243]" --arg num "241" \
      '(.active_projects[] | select(.project_number == ($num | tonumber)) | .dependencies) =
       ((.active_projects[] | select(.project_number == ($num | tonumber)) | .dependencies // []) + $new_deps)' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
    ```

12. **Update parent task in TODO.md** - Edit the parent task's `- **Dependencies**:` line to include new task numbers. If no Dependencies line exists, add one after the Status line.

13. **Git commit**:
    ```
    task N: spawn {M} tasks to resolve blocker

    Session: {session_id}

    Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
    ```

14. **Clean up** `.spawn-return.json` file.

**MUST NOT** (postflight boundary):
- Perform any research or analysis
- Make decisions about task breakdown (that is the agent's job)
- Write implementation files
- Modify files outside `specs/`

---

### spawn-agent (`.claude/agents/spawn-agent.md`)

**Frontmatter**:
```yaml
name: spawn-agent
description: Analyzes blocked tasks, researches blockers, and proposes minimal new tasks to overcome the blocker
model: claude-opus-4-5-20251101
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash(jq:*)
```

**Purpose**: Given a blocked task and optional user description of the blocker, the agent:
1. Reads task context (plan, partial progress, task description, existing research reports)
2. Analyzes what specifically is blocking progress
3. Proposes a minimal set of new tasks to overcome the blocker
4. Applies the Task Minimization Principle (fewer, well-scoped tasks preferred)
5. Identifies which new tasks are sequential vs. independent (explicit dependency reasoning)
6. Writes a blocker analysis research report
7. Returns structured JSON for the skill's postflight to act on

**Execution Stages**:

**Stage 0: Write early metadata** (in_progress status)

**Stage 1: Load Context**
- Read task data from delegation context
- Read plan file if provided: identify which phase is blocked and why
- Read existing research reports for background
- Read any partial summaries or debug artifacts

**Stage 2: Analyze Blocker**
- If `blocker_prompt` provided: use it as primary signal for what's blocking
- If not provided: infer from plan phase status ([IN PROGRESS] or [PARTIAL] phases), phase descriptions, and any error notes in phase descriptions
- Identify root cause categories:
  - Missing prerequisite (upstream work not done)
  - External dependency (library, API, tool not available)
  - Design ambiguity (implementation path unclear, needs decision)
  - Scope creep (task too large for single implementation)
  - Technical unknowns (research needed before implementation can proceed)

**Stage 3: Decompose into Minimal Tasks**

Apply these principles when proposing new tasks:
- **Minimality**: Prefer fewer tasks. Combine work that can be done together without one depending on the details of the other.
- **Sequentiality**: Keep tasks separate when the implementation details of one task affect how the next task should be implemented (not just completion, but the specific choices made).
- **Independence**: Tasks that can be implemented in any order (or in parallel) should be marked as independent.
- **Specificity**: Each task description must be specific enough for an implementer to act on without additional context.

For each proposed task, determine:
- Title and description
- Estimated effort
- Language (inherit from parent task unless clearly different)
- Internal dependencies (which other new tasks must complete first, and crucially: WHY - what details from that task's completion inform this task)
- Whether it depends on the parent task (usually: new tasks clear the way FOR the parent task, so the parent depends on them, not vice versa)

**Stage 4: Write Blocker Analysis Report**

Write to `specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md`:

```markdown
# Blocker Analysis: Task #{N}

**Parent Task**: #{N} - {title}
**Generated**: {date}
**Blocker**: {summary of what is blocking}

## Root Cause

{Analysis of what is causing the block}

## Proposed New Tasks

### New Task 1: {title}
- **Effort**: {estimate}
- **Rationale**: {why this task is needed}
- **Depends on**: None (or: New Task 2, because {specific reason})

### New Task 2: {title}
- **Effort**: {estimate}
- **Rationale**: {why this task is needed}
- **Depends on**: None

## Dependency Reasoning

{Explicit explanation of which tasks are sequential and why. For each dependency: what specific implementation details from the prerequisite task affect how the dependent task should be done.}

## After Completion

Once all spawned tasks are complete, resume the parent task #{N} with `/implement {N}`. The blocker should be resolved because: {explanation}.
```

**Stage 5: Write Return File**

Write to `specs/{NNN}_{SLUG}/.spawn-return.json`:
```json
{
  "new_tasks": [
    {
      "index": 0,
      "title": "Task title",
      "description": "Full description with enough detail for an implementer",
      "effort": "1-2 hours",
      "language": "meta",
      "dependencies": []
    },
    {
      "index": 1,
      "title": "Task title",
      "description": "Full description referencing what it needs from task 0",
      "effort": "2-3 hours",
      "language": "meta",
      "dependencies": [0]
    }
  ],
  "dependency_order": [0, 1],
  "parent_task_number": 241,
  "analysis_summary": "One sentence describing what is blocking and how the new tasks resolve it",
  "report_path": "specs/241_slug/reports/02_spawn-analysis.md"
}
```

`dependency_order` is the topologically sorted list of task indices (0-based) from foundational to dependent. The skill uses this to assign task numbers so foundational tasks get lower numbers.

**Stage 6: Update early metadata to final status**

Update `.return-meta.json` to `researched` status with artifact references.

**CRITICAL REQUIREMENTS**:
- NEVER create tasks in state.json or TODO.md (skill postflight handles all state writes)
- NEVER create task directories (skill postflight handles this)
- ONLY write to: `specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md` and `specs/{NNN}_{SLUG}/.spawn-return.json`
- Dependency reasoning MUST be explicit: state what specific implementation details from one task affect another

---

## Integration Points

- **Component Type**: command + skill + agent (full triad)
- **Affected Area**: `.claude/commands/`, `.claude/skills/`, `.claude/agents/`
- **Action Type**: create
- **CLAUDE.md update required**: Add `skill-spawn -> spawn-agent` to Skill-to-Agent Mapping table

## Dependencies

None - this task can be started independently.

## Effort Assessment

- **Estimated Effort**: 4-6 hours
- **Complexity Notes**: Three interdependent components but well-defined interfaces. The postflight state-management logic (updating parent task dependencies) is the most nuanced part. The agent's dependency reasoning logic requires careful prompt design.

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 241 [focus]` with a specific focus prompt.*
