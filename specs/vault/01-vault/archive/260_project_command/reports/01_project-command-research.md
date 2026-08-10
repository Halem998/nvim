# Research Report: Task #260

**Task**: 260 - project_command
**Started**: 2026-03-23T00:00:00Z
**Completed**: 2026-03-23T00:30:00Z
**Effort**: 2-4 hours estimated for implementation
**Dependencies**: Task 258 (project-agent - COMPLETED), Task 259 (skill-project - COMPLETED)
**Sources/Inputs**: Codebase exploration (commands, skills, agents), forcing-questions framework
**Artifacts**: specs/260_project_command/reports/01_project-command-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/project` command should follow the established founder extension command pattern with STAGE 0 pre-task forcing questions
- Forcing questions should cover: project name, goals/deliverables, team members (roles + allocation %), timeline constraints, resource needs, external dependencies, and risk factors
- Command routes to skill-project with `task_type: "project"` in state.json
- Three modes are supported: PLAN (create timeline), TRACK (update progress), REPORT (status summary)
- Implementation can directly follow the pattern established by `/market`, `/strategy`, `/analyze`, and `/legal` commands

## Context and Scope

This research analyzes how to create the `/project` command for the founder extension. The command should:
1. Ask forcing questions BEFORE task creation (v2.1 pattern)
2. Create a task with `task_type: "project"` and `forcing_data`
3. Route to skill-project for timeline generation
4. Support the standard four-stage workflow: command -> /research -> /plan -> /implement

The project-agent (task 258) and skill-project (task 259) have already been implemented, so this command serves as the user-facing entry point.

## Findings

### Codebase Patterns

#### Command Structure Pattern

All founder extension commands follow this structure:

1. **Frontmatter** (lines 1-5):
```markdown
---
description: Brief description of command
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [args]
---
```

2. **Overview Section**: Command purpose and workflow summary

3. **Syntax Section**: Usage examples with all input types

4. **Input Types Table**: How different inputs are handled

5. **Modes Table**: Available operational modes with posture and focus

6. **STAGE 0: PRE-TASK FORCING QUESTIONS**: Questions asked BEFORE task creation
   - Step 0.1: Mode selection via AskUserQuestion
   - Step 0.2: Essential forcing questions (4-5 questions, one at a time)
   - Step 0.3: Store forcing data as JSON

7. **CHECKPOINT 1: GATE IN**: Session ID generation, input type detection, task creation

8. **STAGE 2: DELEGATE**: Route to appropriate skill

9. **CHECKPOINT 2: GATE OUT**: Verify completion, display results

10. **Error Handling**: Standard error patterns

11. **Output Artifacts**: Location conventions

12. **Workflow Summary**: Visual workflow representation

13. **Examples**: Practical usage examples

#### Forcing Questions Framework

From `forcing-questions.md`, key principles:
- **One question at a time**: Never batch questions
- **Push-back on vague answers**: "Can you be more specific about..."
- **Specificity is the only currency**: Reject vague patterns
- **Context preservation**: Summarize what was learned before next question

Push-back triggers for project planning:
| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "ASAP" or "Soon" | "What is the specific target date?" |
| "The team" | "Name the specific people and their roles." |
| "Various resources" | "List the specific resources needed." |
| "It depends" | "What are the dependencies, specifically?" |
| "High priority" | "What is the completion criteria and deadline?" |

### Recommended Forcing Questions for /project

Based on the project-agent design and forcing-questions framework:

#### Mode Selection (Step 0.1)

```
What type of project management do you need?

- PLAN: Create new project timeline from scratch
- TRACK: Update existing timeline with progress
- REPORT: Generate executive status summary
```

#### Essential Forcing Questions (Step 0.2)

**Q1: Project Name and Completion Criteria**
```
What is this project called, and what does "done" look like?

Push for: Specific project name, clear completion criteria
Reject: Vague goals like "improve things"
Example: "Mobile App Redesign - done when new app is live with 4+ star rating"
```
Store as: `forcing_data.project_name`, `forcing_data.completion_criteria`

**Q2: Goals and Deliverables**
```
What are the 2-4 key deliverables (nouns, not actions)?

Push for: Specific output artifacts, not activities
Reject: "Do the development" -> Accept: "Deployed application"
Example: "1. Approved mockups, 2. Working prototype, 3. Production deployment"
```
Store as: `forcing_data.deliverables`

**Q3: Team Members with Roles and Allocation**
```
Who will work on this project? List names, roles, and allocation %.

Push for: Specific names, concrete roles, explicit allocations
Reject: "The team" or "developers"
Example: "Alice (PM, 50%), Bob (Designer, 100% during design, 25% after), Carol (Dev, 100%)"
```
Store as: `forcing_data.team_members`

**Q4: Timeline Constraints**
```
What are your timeline constraints?

Push for: Start date, target end date, key milestones
Accept: Hard deadlines, soft targets, or "flexible but prefer by X"
Example: "Start: April 1, Must launch by: June 15 for trade show, Milestone: Beta by May 15"
```
Store as: `forcing_data.start_date`, `forcing_data.target_date`, `forcing_data.milestones`

**Q5: Resource Needs**
```
What resources does this project require beyond the team?

Push for: Specific compute, budget, equipment, external services
Accept: "None beyond team time" if genuinely not needed
Example: "AWS compute: ~$500/month, Design tools: $100/month, External API: $200/month"
```
Store as: `forcing_data.resource_needs`

**Q6: External Dependencies**
```
What external dependencies or blockers exist?

Push for: Specific external parties, third-party services, approvals needed
Accept: "None" if internal-only project
Example: "Need API access from Partner X (pending), Legal approval for ToS (due April 5)"
```
Store as: `forcing_data.external_dependencies`

**Q7: Risk Factors**
```
What are the biggest risks to this project succeeding?

Push for: Specific risks with likelihood and impact
Reject: "Various risks" or "Things might go wrong"
Example: "1. Key developer might leave (medium), 2. API changes from partner (high impact, low likelihood)"
```
Store as: `forcing_data.risk_factors`

### Routing Pattern

The command should set `task_type: "project"` in state.json for type-based routing:

```json
{
  "project_number": 261,
  "project_name": "project_mobile_app_redesign",
  "status": "not_started",
  "language": "founder",
  "task_type": "project",
  "description": "Project timeline: Mobile App Redesign",
  "forcing_data": {
    "mode": "PLAN",
    "project_name": "Mobile App Redesign",
    "completion_criteria": "New app live with 4+ star rating",
    "deliverables": ["Approved mockups", "Working prototype", "Production deployment"],
    "team_members": [
      {"name": "Alice", "role": "PM", "allocation": "50%"},
      {"name": "Bob", "role": "Designer", "allocation": "100%/25%"}
    ],
    "start_date": "2026-04-01",
    "target_date": "2026-06-15",
    "milestones": ["Beta by May 15"],
    "resource_needs": "AWS ~$500/mo, Design tools ~$100/mo",
    "external_dependencies": "Partner API access pending",
    "risk_factors": ["Key developer availability", "API changes"],
    "gathered_at": "2026-03-23T10:00:00Z"
  }
}
```

When `/research {N}` is invoked on this task, routing uses:
- Language: `founder`
- Task type: `project`
- Composite key: `founder:project`
- Skill: `skill-project`
- Agent: `project-agent`

### Integration with Existing Components

The `/project` command integrates with:

1. **project-agent** (task 258): Handles the actual timeline generation with WBS, PERT estimation, and resource allocation
2. **skill-project** (task 259): Thin wrapper that routes to project-agent and handles postflight

The workflow is:
```
/project "description"   -> Asks forcing questions, creates task, stops at [NOT STARTED]
/research {N}            -> Routes to skill-project -> project-agent, stops at [PLANNED]
/plan {N}                -> Uses founder-plan-agent for implementation planning
/implement {N}           -> Uses founder-implement-agent to execute plan
```

Note: For project timeline tasks, `/research {N}` routes to skill-project which invokes project-agent. The agent creates the timeline during the "research" phase, but the status becomes [PLANNED] since this is a planning artifact, not a research artifact.

## Recommendations

### Implementation Approach

1. **Create command file**: `.claude/extensions/founder/commands/project.md`
   - Follow exact structure of `/market` command
   - Include all 7 forcing questions in STAGE 0
   - Support all input types (description, task number, file path, --quick)
   - Route to skill-project with `task_type: "project"`

2. **Update EXTENSION.md**: Add /project to command table and routing table

3. **Update index-entries.json**: Add routing entry for `founder:project`

4. **Testing**: Verify forcing question flow and routing works correctly

### Command File Structure

```markdown
---
description: Project timeline management with forcing questions for scope, team, timeline, and risks
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [mode]
---

# /project Command

Project timeline management command with WBS, PERT estimation, and resource allocation...
```

### Forcing Data Schema

```json
{
  "mode": "PLAN|TRACK|REPORT",
  "project_name": "string",
  "completion_criteria": "string",
  "deliverables": ["string"],
  "team_members": [{"name": "string", "role": "string", "allocation": "string"}],
  "start_date": "ISO date or null",
  "target_date": "ISO date or null",
  "milestones": ["string"],
  "resource_needs": "string",
  "external_dependencies": "string",
  "risk_factors": ["string"],
  "gathered_at": "ISO timestamp"
}
```

## Decisions

- Use 7 forcing questions (more than the 4-5 in other commands) because project planning requires more upfront context
- Store team members as array of objects with name, role, and allocation fields for structured processing
- Support all three modes (PLAN, TRACK, REPORT) at command level, passing to skill-project
- Follow the STAGE 0 pre-task forcing questions pattern (v2.1)
- Stop at [NOT STARTED] after task creation (do not auto-invoke research)

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User abandons forcing questions | Medium | Low | Partial data preserved, can resume |
| Too many questions frustrates user | Low | Medium | Keep questions focused, allow "skip" for optional ones |
| Team allocation data too complex | Low | Medium | Accept free-form text, agent parses during timeline creation |
| Mode mismatch with existing timeline | Low | Medium | TRACK/REPORT validate timeline exists before proceeding |

## Appendix

### Files Examined

- `.claude/extensions/founder/commands/market.md` - Reference command pattern
- `.claude/extensions/founder/commands/strategy.md` - Reference command pattern
- `.claude/extensions/founder/commands/analyze.md` - Reference command pattern
- `.claude/extensions/founder/commands/legal.md` - Reference command pattern
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Target skill (task 259)
- `.claude/extensions/founder/agents/project-agent.md` - Target agent (task 258)
- `.claude/extensions/founder/EXTENSION.md` - Extension overview and routing
- `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` - Forcing questions framework

### Search Queries Used

- `Glob: .claude/extensions/founder/commands/**/*` - Found 4 command files
- `Glob: .claude/extensions/founder/skills/**/*` - Found 7 skill files including skill-project
- `Glob: .claude/extensions/founder/agents/**/*` - Found 7 agent files including project-agent
- `Grep: forcing.question` - Found 21 files with forcing question patterns
