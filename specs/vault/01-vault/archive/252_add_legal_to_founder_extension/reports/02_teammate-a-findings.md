# Teammate A Findings: Implementation Patterns and Structure Analysis

**Task**: Add /legal command-skill-agent to founder extension
**Researcher**: Teammate A
**Date**: 2026-03-20
**Focus**: Implementation patterns, exact file structure, execution flows

---

## Key Findings

### 1. File Structure Pattern

The founder extension uses a strict parallel structure for each command-skill-agent triplet:

```
extensions/founder/
├── agents/
│   └── {name}-agent.md          # Agent definition with frontmatter
├── skills/
│   └── skill-{name}/
│       └── SKILL.md             # Skill definition with frontmatter
├── commands/
│   └── {name}.md                # Command definition with frontmatter
├── context/project/founder/
│   ├── domain/                  # Core domain knowledge
│   ├── patterns/                # Behavioral patterns
│   └── templates/               # Output templates
├── manifest.json                # Extension registration
├── index-entries.json           # Context file index
└── EXTENSION.md                 # Human-readable extension docs
```

For a new `/legal` command, the pattern requires creating exactly:
- `agents/legal-agent.md`
- `skills/skill-legal/SKILL.md`
- `commands/legal.md`
- Context files (domain, patterns, templates) for legal
- Updates to `manifest.json`, `index-entries.json`, `EXTENSION.md`

### 2. Agent Frontmatter Pattern

All agents use YAML frontmatter with `name`, `description`, and optional `mcp-servers`:

```yaml
---
name: market-agent
description: Market sizing research with TAM/SAM/SOM framework using forcing questions
mcp-servers:
  - sec-edgar
---
```

For legal-agent, MCP server integration is optional but pattern allows it (e.g., could add SEC EDGAR for public company filings or a legal database MCP).

**Key metadata block** inside the agent (lines 16-20 of market-agent.md):
```markdown
## Agent Metadata
- **Name**: market-agent
- **Purpose**: Market sizing research with forcing questions
- **Invoked By**: skill-market (via Task tool)
- **Return Format**: JSON metadata file + brief text summary
```

### 3. Skill Frontmatter Pattern

Skills use frontmatter with `name`, `description`, and `allowed-tools`:

```yaml
---
name: skill-market
description: Market sizing research with TAM/SAM/SOM framework
allowed-tools: Task, Bash, Edit, Read, Write
---
```

All skills use identical `allowed-tools: Task, Bash, Edit, Read, Write` - this is the standard set.

### 4. Command Frontmatter Pattern

Commands use frontmatter with `description`, `allowed-tools`, and `argument-hint`:

```yaml
---
description: Market sizing research using TAM/SAM/SOM framework with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [industry] [segment]
---
```

Key: Commands use `Skill` (not `Task`) as allowed tool, plus restricted Bash variants. They do NOT use `Task` directly - that is done inside the skill.

### 5. Execution Flow Stages

#### Agent Execution Flow (9-stage pattern):

All three agents (market, analyze, strategy) follow the same 9-stage flow:

| Stage | Name | Description |
|-------|------|-------------|
| 0 | Initialize Early Metadata | CRITICAL first step - write `in_progress` metadata file |
| 1 | Parse Delegation Context | Extract task_context, forcing_data, mode, metadata_file_path |
| 2 | Mode Selection | AskUserQuestion if mode is null; confirm selection |
| 3-5 | Forcing Questions (domain-specific) | One question at a time via AskUserQuestion |
| 6 | Generate Research Report | Compose markdown report content |
| 7 | Write Research Report | Save to `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |
| 8 | Write Metadata File | Save final JSON to `metadata_file_path` |
| 9 | Return Brief Text Summary | Plain text (NOT JSON) |

#### Skill Execution Flow (11-stage pattern):

All three skills follow the same 11-stage flow:

| Stage | Name | Description |
|-------|------|-------------|
| 1 | Input Validation | Validate task_number exists in state.json |
| 2 | Preflight Status Update | Set status to "researching" in state.json and TODO.md |
| 3 | Create Postflight Marker | Write `.postflight-pending` file |
| 4 | Prepare Delegation Context | Build JSON with task_context, forcing_data, metadata_file_path |
| 5 | Invoke Agent | Use `Task` tool with `subagent_type: "{name}-agent"` |
| 6 | Parse Subagent Return | Read `.return-meta.json` metadata file |
| 7 | Update Task Status (Postflight) | Set status to "researched" in state.json and TODO.md |
| 8 | Link Artifacts | Two-step jq pattern to add artifact to state.json |
| 9 | Git Commit | Commit with task-scoped message |
| 10 | Cleanup | Remove `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json` |
| 11 | Return Brief Summary | Plain text summary |

#### Command Execution Flow (STAGE 0 + CHECKPOINT 1 + STAGE 2 + CHECKPOINT 2):

All three commands follow the same structure:

```
STAGE 0: PRE-TASK FORCING QUESTIONS (for new tasks only)
  0.1: Mode selection via AskUserQuestion
  0.2: 4-5 essential forcing questions (one at a time)
  0.3: Store forcing_data as JSON object

CHECKPOINT 1: GATE IN
  Step 1: Generate session_id
  Step 2: Detect input type (--quick, task_number, file_path, description)
  Step 3: Handle input type
  Step 4: Create task in state.json (if new)
  Step 5: Update TODO.md
  Step 6: Git commit (task creation)
  Step 7: Display summary and STOP (for new tasks)

STAGE 2: DELEGATE (only for task_number or --quick)
  2A: Legacy mode (--quick) - invoke skill directly
  2B: Task workflow mode - invoke skill with task_number

CHECKPOINT 2: GATE OUT
  Verify research completed
  Get research artifact
  Display result with next steps
```

### 6. Forcing Question Pattern

Critical rules (from `patterns/forcing-questions.md`):
- **One question per AskUserQuestion** - never batch
- **Push back on vague answers** - specificity is mandatory
- Each question has explicit push-back triggers and acceptable answer examples
- Questions are grounded in context: re-state project before asking

### 7. Mode Selection Pattern

Every command offers 4 modes (from `patterns/mode-selection.md`):
- Presented via AskUserQuestion
- Confirmed after selection
- All subsequent questions adapt to selected mode

Mode naming convention per command:
- `/market`: VALIDATE, SIZE, SEGMENT, DEFEND
- `/analyze`: LANDSCAPE, DEEP, POSITION, BATTLE
- `/strategy`: LAUNCH, SCALE, PIVOT, EXPAND

For `/legal`, the pattern suggests 4 legal-domain modes (see Recommended Approach).

### 8. Delegation Context JSON Pattern

The exact structure passed from skill to agent:

```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "{description}",
    "language": "founder",
    "task_type": "{type}"
  },
  "forcing_data": {
    "mode": "{pre_gathered_mode}",
    "{field1}": "{value1}",
    "gathered_at": "{ISO timestamp}"
  },
  "{optional_hints}": "...",
  "mode": "{mode or use forcing_data.mode}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "{command}", "skill-{name}"]
  }
}
```

### 9. Metadata File Pattern

Early metadata (Stage 0 of agent - CRITICAL):
```json
{
  "status": "in_progress",
  "started_at": "{ISO8601 timestamp}",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, parsing delegation context"
  }
}
```

Final metadata (Stage 8 of agent):
```json
{
  "status": "researched",
  "summary": "...",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
      "summary": "..."
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 300,
    "agent_type": "{name}-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "{cmd}", "skill-{name}", "{name}-agent"],
    "mode": "{selected_mode}",
    "questions_asked": N,
    "{domain_specific}": "..."
  },
  "next_steps": "Run /plan to create implementation plan using this research"
}
```

### 10. manifest.json Pattern

```json
{
  "name": "founder",
  "version": "2.0.0",
  "description": "...",
  "language": "founder",
  "dependencies": [],
  "provides": {
    "agents": ["market-agent.md", "analyze-agent.md", "strategy-agent.md", ...],
    "skills": ["skill-market", "skill-analyze", "skill-strategy", ...],
    "commands": ["market.md", "analyze.md", "strategy.md"],
    "rules": [],
    "context": ["project/founder"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      "founder:strategy": "skill-strategy"
    },
    "plan": {"founder": "skill-founder-plan"},
    "implement": {"founder": "skill-founder-implement"}
  },
  "merge_targets": {...},
  "mcp_servers": {...}
}
```

For `/legal`, the routing entry would be: `"founder:legal": "skill-legal"`.

### 11. index-entries.json Pattern

Each context file gets an entry with:
- `path` - relative path from repo root
- `summary` - one-line description
- `line_count` - actual line count
- `load_when.agents` - array of agent names
- `load_when.languages` - always `["founder"]`
- `load_when.commands` - array of command names like `["/legal"]`

### 12. Context File Structure

Domain files (`domain/*.md`): Core conceptual frameworks
Pattern files (`patterns/*.md`): Behavioral patterns for agents
Template files (`templates/*.md`): Output format templates
Template files (`templates/typst/*.typ`): Typst PDF templates

For legal, appropriate context files would be:
- `domain/legal-frameworks.md` - Legal analysis frameworks (contracts, IP, compliance)
- `patterns/legal-questions.md` - Legal-specific forcing questions
- `templates/legal-analysis.md` - Research report template
- `templates/typst/legal-analysis.typ` - PDF template (optional)

---

## Recommended Approach

### File Creation Order

1. Create context files first (referenced by agent)
2. Create agent file
3. Create skill file (references agent)
4. Create command file (references skill)
5. Update manifest.json (add to provides and routing)
6. Update index-entries.json (add context file entries)
7. Update EXTENSION.md (add command to table)

### Proposed Mode Set for /legal

Based on the 4-mode pattern:

| Mode | Posture | Focus |
|------|---------|-------|
| REVIEW | "Spot risks" | Contract review, identify red flags |
| COMPLY | "Meet requirements" | Regulatory compliance audit |
| PROTECT | "Secure position" | IP protection, defensive strategy |
| NEGOTIATE | "Optimize terms" | Deal terms, negotiation preparation |

### Proposed Forcing Questions for /legal (STAGE 0 in command)

1. **Legal Domain** - What type of legal issue? (Contract, IP, Compliance, Employment, etc.)
2. **Jurisdiction** - What jurisdiction(s) apply? (US, EU, multi-jurisdiction?)
3. **Stakes** - What's the consequence if this goes wrong?
4. **Timeline** - Is there a deadline or urgency?

### Proposed Research Questions for legal-agent (interactive)

Q1: Entity Type - What type of entity/agreement are you analyzing?
Q2: Key Parties - Who are the parties involved?
Q3: Risk Identification - What are your top 3 concerns?
Q4: Precedent - Have you had similar legal issues before?
Q5: Constraints - Are there non-negotiable terms or regulatory constraints?
Q6: Outcome - What is the ideal outcome?

### Task Type Field

Add `task_type: "legal"` to task creation. Routing key: `"founder:legal": "skill-legal"`.

---

## Evidence / Examples

### Agent Frontmatter (exact pattern)
- File: `.claude/extensions/founder/agents/market-agent.md` lines 1-6
- File: `.claude/extensions/founder/agents/analyze-agent.md` lines 1-6
- File: `.claude/extensions/founder/agents/strategy-agent.md` lines 1-4

### Early Metadata Initialization (Stage 0)
- File: `.claude/extensions/founder/agents/market-agent.md` lines 57-75
- CRITICAL: Must be first operation before any substantive work

### Mode Selection (Stage 2 of agent)
- File: `.claude/extensions/founder/agents/market-agent.md` lines 99-114
- File: `.claude/extensions/founder/agents/analyze-agent.md` lines 101-116

### Forcing Question Pattern (one at a time)
- File: `.claude/extensions/founder/agents/market-agent.md` lines 116-153
- File: `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` lines 188-200

### Skill Postflight Pattern (Stages 7-10)
- File: `.claude/extensions/founder/skills/skill-market/SKILL.md` lines 218-285
- Identical across all three skills

### Two-Step jq Artifact Linking Pattern
- File: `.claude/extensions/founder/skills/skill-market/SKILL.md` lines 243-255
- Uses "| not" pattern per jq safety rules

### Command STAGE 0 Pattern (pre-task forcing questions)
- File: `.claude/extensions/founder/commands/market.md` lines 42-109
- File: `.claude/extensions/founder/commands/analyze.md` lines 42-108

### manifest.json routing pattern
- File: `.claude/extensions/founder/manifest.json` lines 28-41
- Composite key format: `"founder:{task_type}": "skill-{name}"`

### index-entries.json structure
- File: `.claude/extensions/founder/index-entries.json` lines 1-124
- All founder agents must be in `load_when.agents` for context files to load

### Delegation context JSON
- File: `.claude/extensions/founder/skills/skill-market/SKILL.md` lines 141-170
- File: `.claude/extensions/founder/skills/skill-analyze/SKILL.md` lines 143-169

---

## Confidence Level

**High confidence** on:
- Exact frontmatter format for agent, skill, command files
- All execution flow stages and their ordering
- Delegation context JSON structure
- Metadata file patterns (early + final)
- manifest.json and index-entries.json structure
- jq safety patterns (two-step, "| not" instead of "!=")
- STAGE 0 command pattern (pre-task forcing questions)
- Skill postflight pattern (Stages 7-10: status, artifacts, git, cleanup)

**Medium confidence** on:
- Appropriate legal domain modes (REVIEW/COMPLY/PROTECT/NEGOTIATE are reasonable but could be different)
- Whether a legal-specific MCP server should be included in frontmatter
- Exact forcing questions for legal domain research
- Whether typst template is required or optional for legal

**Low confidence** on:
- Whether legal needs its own plan/implement agents or can reuse founder-plan-agent/founder-implement-agent
- Exact legal domain context file structure and content
