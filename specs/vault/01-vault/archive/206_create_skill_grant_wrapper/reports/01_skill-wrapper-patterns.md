# Research Report: Task #206

**Task**: 206 - create_skill_grant_wrapper
**Started**: 2026-03-15T00:00:00Z
**Completed**: 2026-03-15T00:00:00Z
**Effort**: 1-2 hours
**Dependencies**: Task 205 (grant-agent, already created)
**Sources/Inputs**: Codebase analysis of existing skills
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Analyzed 6 skill implementations to identify thin wrapper patterns
- Key pattern: skill-internal postflight with 11-stage execution flow
- skill-grant must follow skill-researcher/skill-planner/skill-implementer structure
- Grant extension uses `workflow_type` parameter for multi-workflow routing (unlike single-workflow core skills)
- Required: frontmatter, input validation, preflight status, postflight marker, delegation, metadata parsing, status update, artifact linking, git commit, cleanup, return

## Context and Scope

This research examined existing skill implementations in `.claude/skills/` to identify the patterns required for implementing `skill-grant` as a thin wrapper that delegates to `grant-agent`. The focus was on:

1. Skill frontmatter structure
2. Execution stages with internal postflight
3. Delegation to agents via Task tool
4. Metadata file exchange pattern
5. Error handling and recovery

## Findings

### 1. Skill Frontmatter Structure

All thin wrapper skills use this frontmatter format:

```yaml
---
name: skill-grant
description: Grant proposal research and drafting with funder analysis
allowed-tools: Task, Bash, Edit, Read, Write
# Context references (loaded by subagent):
#   - .claude/extensions/grant/context/project/grant/README.md
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---
```

**Key observations**:
- `allowed-tools` specifies tools the SKILL uses (Task for delegation, Bash/Edit/Read/Write for postflight)
- Subagent tools are commented documentation only
- No `agent:` field in frontmatter (used in placeholder but not in production skills)
- Optional fields: `model:` (but typically set in agent definition instead)

### 2. Skill-Internal Postflight Pattern

All workflow skills (skill-researcher, skill-planner, skill-implementer, skill-meta) implement internal postflight to eliminate the "continue" prompt issue. The pattern consists of 11 stages:

| Stage | Purpose | Key Operations |
|-------|---------|----------------|
| 1 | Input Validation | Validate task_number exists, check status |
| 2 | Preflight Status Update | Update state.json + TODO.md to in-progress status |
| 3 | Create Postflight Marker | Write `.postflight-pending` in task directory |
| 4 | Prepare Delegation Context | Build JSON with session_id, task_context, etc. |
| 5 | Invoke Subagent | Use **Task tool** (NOT Skill tool) |
| 5a | Validate Return Format | Check if JSON was erroneously returned to console |
| 6 | Parse Metadata File | Read `.return-meta.json` from task directory |
| 7 | Update Task Status | Update state.json + TODO.md to final status |
| 8 | Link Artifacts | Add artifacts to state.json and TODO.md |
| 9 | Git Commit | Commit with session ID |
| 10 | Cleanup | Remove marker, loop guard, metadata files |
| 11 | Return Brief Summary | Return text summary (NOT JSON) |

### 3. Grant-Specific Workflow Type Routing

Unlike single-workflow core skills, grant-agent supports four workflow types:

```
skill-grant receives invocation
    |
    v
Parse workflow_type from context
    |
    +--- funder_research
    |    Status: researching -> researched
    |    Output: reports/{MM}_funder-analysis.md
    |
    +--- proposal_draft
    |    Status: planning -> planned (or implementing -> implemented)
    |    Output: drafts/{MM}_narrative-draft.md
    |
    +--- budget_develop
    |    Status: planning -> planned (or implementing -> implemented)
    |    Output: budgets/{MM}_line-item-budget.md
    |
    +--- progress_track
         Status: (no status change)
         Output: summaries/{MM}_progress-summary.md
```

**skill-grant must**:
1. Accept `workflow_type` parameter in invocation
2. Map workflow_type to appropriate preflight/postflight status transitions
3. Pass workflow_type in delegation context to grant-agent

### 4. Delegation Context Structure

Based on skill-researcher pattern, delegation context for skill-grant:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "grant", "skill-grant"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "grant"
  },
  "workflow_type": "funder_research|proposal_draft|budget_develop|progress_track",
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### 5. Critical Implementation Details

#### 5.1 Task Tool Invocation (NOT Skill Tool)

```markdown
**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "grant-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, focus_prompt, metadata_file_path]
  - description: "Execute {workflow_type} for task {N}"

**DO NOT** use `Skill(grant-agent)` - this will FAIL.
```

#### 5.2 Postflight Marker Protocol

Create before subagent invocation:

```bash
# Create postflight marker in task directory
cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-grant",
  "task_number": ${task_number},
  "operation": "${workflow_type}",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

Remove after postflight complete:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

#### 5.3 jq Escaping Workaround (Issue #1132)

Use two-step jq pattern to avoid `!=` escaping bug:

```bash
# Step 1: Filter out existing artifacts (use "| not" pattern)
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "report" | not)]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add new artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### 6. Status Mapping by Workflow Type

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| funder_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| proposal_draft | planning | planned | [PLANNING] -> [PLANNED] |
| budget_develop | planning | planned | [PLANNING] -> [PLANNED] |
| progress_track | (no change) | (no change) | (no change) |

### 7. Return Format

Skills return brief text summary (NOT JSON):

```
Grant funder research completed for task 500:
- Identified 5 potential funders for AI safety research
- Top recommendation: Open Philanthropy (strongest alignment)
- Created report at specs/500_research_ai_safety_funders/reports/01_funder-analysis.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1773637808_c37314
```

### 8. Error Handling Patterns

| Error Type | Response |
|------------|----------|
| Task not found | Return immediately with error message |
| Metadata file missing | Keep status as in-progress, do not cleanup, report error |
| Git commit failure | Non-blocking: log and continue |
| jq parse failure | Log to errors.json, retry with two-step pattern |
| Subagent timeout | Return partial status, keep as in-progress for resume |

## Recommendations

### Implementation Approach

1. **Use skill-researcher as primary template** - Most similar workflow pattern
2. **Add workflow_type routing** - Grant-specific extension to standard pattern
3. **Map workflow_type to status transitions** - Different workflows may use different status patterns
4. **Follow exact 11-stage structure** - Critical for postflight hook integration

### Suggested Structure for skill-grant/SKILL.md

```markdown
---
name: skill-grant
description: Grant proposal research and drafting with funder analysis. Invoke for grant tasks.
allowed-tools: Task, Bash, Edit, Read, Write
# Context (loaded by subagent):
#   - .claude/extensions/grant/context/project/grant/README.md
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Grant Skill

Thin wrapper that delegates grant work to `grant-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern...

## Context References
- Path: `.claude/context/core/formats/return-metadata-file.md`
- Path: `.claude/context/core/patterns/postflight-control.md`
- Path: `.claude/context/core/patterns/jq-escaping-workarounds.md`

## Trigger Conditions
- Task language is "grant"
- Grant workflow requested (funder_research, proposal_draft, budget_develop, progress_track)

## Execution Flow
### Stage 1: Input Validation
[Validate task_number, workflow_type, language == "grant"]

### Stage 2: Preflight Status Update
[Map workflow_type to appropriate in-progress status]

### Stage 3: Create Postflight Marker
...

### Stage 4: Prepare Delegation Context
[Include workflow_type in context]

### Stage 5: Invoke Subagent
[Task tool -> grant-agent]

### Stage 6-11: [Standard postflight pattern]
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| workflow_type not passed correctly | Agent uses wrong workflow | Validate workflow_type in Stage 1, include in delegation context |
| Status mapping incorrect | State machine violations | Use status mapping table, test each workflow type |
| Grant extension not loaded | Missing context files | Check extension loaded before invocation, fail gracefully |
| Multiple concurrent grant tasks | State conflicts | Task-scoped marker files already handle this |

## Appendix

### Search Queries Used

- Codebase: `.claude/skills/**/SKILL.md` - All skill definitions
- Codebase: `.claude/extensions/grant/**/*` - Grant extension files
- Codebase: `.claude/context/core/formats/return-metadata-file.md` - Metadata schema
- Codebase: `.claude/context/core/patterns/postflight-control.md` - Marker protocol

### Skills Analyzed

1. `skill-meta` - Interactive system builder with multi-mode routing
2. `skill-researcher` - General research delegation (primary template)
3. `skill-planner` - Plan creation delegation
4. `skill-implementer` - Implementation delegation with phase tracking
5. `skill-status-sync` - Direct execution (no delegation, for reference)
6. `skill-fix-it` - Direct execution with AskUserQuestion (for reference)

### Key Files Referenced

- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/grant/agents/grant-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/grant/skills/skill-grant/SKILL.md` (placeholder)
- `/home/benjamin/.config/nvim/.claude/context/core/formats/return-metadata-file.md`
- `/home/benjamin/.config/nvim/.claude/context/core/patterns/postflight-control.md`
