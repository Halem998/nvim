# Research Report: Task #234

**Task**: 234 - upgrade_founder_extension_workflow
**Started**: 2026-03-18T00:00:00Z
**Completed**: 2026-03-18T01:30:00Z
**Effort**: 6-10 hours implementation
**Dependencies**: Task #233 (current founder/ extension implementation)
**Sources/Inputs**: Codebase analysis, existing command/skill/agent patterns, task 233 research reports
**Artifacts**: specs/234_upgrade_founder_extension_workflow/reports/01_task-integration-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current founder/ extension produces standalone artifacts in `founder/` directory without task system integration
- Task integration requires: creating tasks in `specs/state.json`, updating `specs/TODO.md`, writing artifacts to `specs/{NNN}_{SLUG}/` directories, and following the checkpoint-based command lifecycle
- Three-phase forcing questions workflow should follow: (1) initial context gathering, (2) interactive forcing questions informed by gathered context, (3) final synthesis producing detailed report artifact
- Commands must accept file path, task number, or no argument with graceful handling for each input type
- Key patterns to adopt: skill-internal postflight, metadata file exchange, lazy directory creation, AskUserQuestion one-at-a-time pattern

---

## Context & Scope

This research analyzes the current founder/ extension architecture and identifies the changes needed to:

1. Integrate `/market`, `/analyze`, and `/strategy` commands with the task management system
2. Implement a three-phase forcing questions workflow (research -> questions -> synthesis)
3. Support flexible input handling (file path, task number, or no argument)
4. Produce detailed report artifacts in the task directory structure

---

## Findings

### Current Founder Extension Architecture

The founder extension currently consists of:

**Directory Structure**:
```
.claude/extensions/founder/
  manifest.json
  EXTENSION.md
  index-entries.json
  commands/
    market.md          # /market command
    analyze.md         # /analyze command
    strategy.md        # /strategy command
  skills/
    skill-market/SKILL.md
    skill-analyze/SKILL.md
    skill-strategy/SKILL.md
  agents/
    market-agent.md
    analyze-agent.md
    strategy-agent.md
  context/
    project/founder/
      domain/
        business-frameworks.md
        strategic-thinking.md
      patterns/
        forcing-questions.md
        decision-making.md
        mode-selection.md
      templates/
        market-sizing.md
        competitive-analysis.md
        gtm-strategy.md
```

**Current Command Pattern** (from market.md):
```
CHECKPOINT 1: GATE IN
  - Generate session ID
  - Parse arguments (industry, segment, --mode)
  - Prepare delegation context

STAGE 2: DELEGATE
  - Invoke skill-market
  - Skill invokes market-agent via Task tool
  - Agent uses forcing questions
  - Agent writes artifact to founder/market-sizing-{datetime}.md

CHECKPOINT 2: GATE OUT
  - Validate return (status, summary, artifacts)
  - Display result
```

**Key Gaps Identified**:

| Aspect | Current State | Required State |
|--------|---------------|----------------|
| Artifact location | `founder/` directory | `specs/{NNN}_{SLUG}/reports/` |
| Task creation | None | Create task in state.json + TODO.md |
| Status tracking | None | Preflight/postflight status updates |
| Input handling | Industry/segment hints only | File path, task number, or none |
| Question workflow | All-in-one | Three-phase (research -> questions -> synthesis) |

---

### Task System Integration Patterns

Studied from `/research`, `/plan`, `/implement` commands.

#### Checkpoint-Based Lifecycle

All task-integrated commands follow this pattern:

```
CHECKPOINT 1: GATE IN (Preflight)
  1. Generate session ID
  2. Lookup or create task
  3. Validate status allows operation
  4. Update status to "in progress" variant
  5. Prepare delegation context

STAGE 2: DELEGATE
  - Invoke skill via Skill tool
  - Skill invokes agent via Task tool
  - Agent does work, writes metadata file
  - Skill handles postflight internally

CHECKPOINT 2: GATE OUT (Postflight)
  1. Read metadata file
  2. Update status to completed variant
  3. Link artifacts in state.json
  4. Update TODO.md
  5. Git commit

CHECKPOINT 3: COMMIT
  - Git add + commit with session ID
```

#### Skill-Internal Postflight Pattern

The skill handles all postflight operations after agent returns. This eliminates the "continue" prompt issue between skill return and orchestrator.

From `skill-planner/SKILL.md`:
1. Create postflight marker file before invoking agent
2. Agent returns brief text summary + writes metadata to file
3. Skill reads metadata file
4. Skill updates state.json, TODO.md, links artifacts
5. Skill commits changes
6. Skill removes marker files

#### Lazy Directory Creation

Task directories are created only when the first artifact is written, not at task creation time:

```bash
# When writing first artifact
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}/reports"
```

#### Metadata File Exchange

Agents write structured metadata to `.return-meta.json` for skill consumption:

```json
{
  "status": "researched",
  "session_id": "sess_...",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md",
      "summary": "Brief 1-sentence summary"
    }
  ],
  "metadata": {
    "agent_type": "market-agent",
    "mode": "SIZE",
    "questions_asked": 8
  },
  "next_steps": "Review assumptions and validate data sources"
}
```

---

### Three-Phase Forcing Questions Workflow

The task requires a three-phase workflow. Design based on current forcing questions pattern:

#### Phase 1: Initial Research (Context Gathering)

**Purpose**: Gather context before asking forcing questions. Makes questions more informed and relevant.

**Input Sources**:
- If file path provided: Read and analyze the file
- If task number provided: Load existing research/plan artifacts
- If no argument: Ask initial open-ended question to establish context

**Actions**:
1. Read input source (file, task artifacts, or initial question response)
2. Extract key information: industry, problem statement, existing data
3. Build context summary for Phase 2

**Example Questions for No-Argument Mode**:
```
Before we begin market sizing, I'd like to understand your context.

What specific product or business are you analyzing?
```

#### Phase 2: Interactive Forcing Questions (Context-Aware)

**Purpose**: Ask forcing questions informed by Phase 1 findings. Questions are tailored to the gathered context.

**Key Principles** (from forcing-questions.md):
- ONE question at a time via AskUserQuestion
- Explicit push-back on vague answers
- "Specificity is the only currency"

**Context-Aware Question Selection**:

| Phase 1 Finding | Adjusted Questions |
|-----------------|-------------------|
| Industry identified | Skip "What industry?" question |
| Problem statement found | Reference it in questions |
| Data sources mentioned | Ask for validation, not discovery |
| Competitor names found | Use them in competitive questions |

**Example Context-Aware Question**:
```
From your context file, I see you're building a {product} for {industry}.

Q1: What's the strongest evidence someone actually wants this?

Push for: Specific behavior, payment, or workflow dependency
Note: You mentioned {insight from file} - does this represent real demand?
```

#### Phase 3: Synthesis (Report Generation)

**Purpose**: Combine Phase 1 context and Phase 2 answers into detailed report artifact.

**Actions**:
1. Synthesize all gathered information
2. Generate report using template (market-sizing.md, competitive-analysis.md, gtm-strategy.md)
3. Include "What I Noticed" observations
4. Write artifact to task directory
5. Write metadata file for skill postflight

---

### Flexible Input Handling

Commands must accept three input types with graceful handling:

#### Input Type 1: File Path

```
/market /path/to/context.md
/market ~/projects/startup/pitch-deck.md
```

**Handling**:
1. Detect file path (starts with `/`, `~`, or contains `.md`/`.txt`)
2. Create task automatically with derived description
3. Read file as Phase 1 context
4. Proceed to Phase 2 with file content as context

**Task Creation from File**:
```bash
# Derive description from filename
description="Market sizing analysis for $(basename "$filepath" | sed 's/\.[^.]*$//')"

# Create task
next_num=$(jq -r '.next_project_number' specs/state.json)
# ... standard task creation via jq
```

#### Input Type 2: Task Number

```
/market 234
/market --task 234
```

**Handling**:
1. Detect task number (integer, optionally with `--task` flag)
2. Load existing task from state.json
3. Read any existing artifacts (research reports, plans) as Phase 1 context
4. Proceed to Phase 2 with existing task context

**Task Loading**:
```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Find existing artifacts
padded_num=$(printf "%03d" "$task_number")
slug=$(echo "$task_data" | jq -r '.project_name')
task_dir="specs/${padded_num}_${slug}"
```

#### Input Type 3: No Argument

```
/market
```

**Handling**:
1. Detect empty arguments
2. Ask initial open-ended question via AskUserQuestion
3. Use response as Phase 1 context
4. Create task from response
5. Proceed to Phase 2

**Initial Question**:
```
Let's start your market sizing analysis.

What product or business are you analyzing? Please describe:
- What problem does it solve?
- Who is your target customer?
- What stage are you at (idea, MVP, paying customers)?
```

#### Input Detection Logic

```python
def detect_input_type(args):
    if not args:
        return "no_argument"

    if args.isdigit() or args.startswith("--task"):
        return "task_number"

    if args.startswith("/") or args.startswith("~") or any(ext in args for ext in [".md", ".txt", ".pdf"]):
        return "file_path"

    # Legacy mode: treat as industry/segment hint
    return "hint"
```

---

### Artifact Path Changes

Current artifacts go to `founder/market-sizing-{datetime}.md`. New structure:

**New Artifact Paths**:
```
specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
```

**Naming Convention**:
- `{NNN}` = 3-digit padded task number (e.g., 234 -> 234)
- `{SLUG}` = task slug (e.g., `market_sizing_fintech_payments`)
- `MM` = sequence number within task (01, 02, ...)
- `{short-slug}` = 3-5 word kebab-case description (e.g., `market-sizing-analysis`)

**Examples**:
```
specs/234_market_sizing_fintech_payments/reports/01_market-sizing-analysis.md
specs/235_competitive_analysis_saas/reports/01_competitive-landscape.md
specs/236_gtm_strategy_b2b_launch/reports/01_gtm-strategy-launch.md
```

---

## Recommended Changes

### Commands to Modify

#### /market Command Changes

```markdown
# /market Command (Upgraded)

## Syntax

- `/market` - Start with initial question, create task, three-phase workflow
- `/market /path/to/file.md` - Use file as context, create task
- `/market 234` - Use existing task, load existing artifacts as context
- `/market --mode SIZE` - Legacy mode, skip task creation

## CHECKPOINT 1: GATE IN

### Step 1: Parse Input Type

```bash
input_type = detect_input_type($ARGUMENTS)

case $input_type in
  "no_argument")
    # Phase 1 will start with open-ended question
    task_number = null
    context_source = "interactive"
    ;;
  "file_path")
    # Read file, create task
    context_source = "file"
    context_content = read_file($ARGUMENTS)
    task_number = create_task_from_file($ARGUMENTS)
    ;;
  "task_number")
    # Load existing task and artifacts
    context_source = "task"
    task_number = extract_task_number($ARGUMENTS)
    context_content = load_task_artifacts($task_number)
    ;;
esac
```

### Step 2: Create or Load Task

If task_number is null, prepare for task creation after Phase 1.

### Step 3: Prepare Delegation Context

```json
{
  "input_type": "file_path|task_number|no_argument",
  "context_source": "file|task|interactive",
  "context_content": "{file content or task artifacts or null}",
  "task_number": "{existing task number or null}",
  "mode": "{VALIDATE|SIZE|SEGMENT|DEFEND or null}",
  "output_dir": "specs/{NNN}_{SLUG}/reports/",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "market", "skill-market"]
  }
}
```

## STAGE 2: DELEGATE

Invoke skill-market with three-phase workflow.
```

#### /analyze Command Changes

Same structure as /market with competitive analysis specifics.

#### /strategy Command Changes

Same structure as /market with GTM strategy specifics.

### Skills to Modify

#### skill-market Changes

Add task lifecycle management:

```markdown
## Stage 2: Preflight Status Update

If task_number provided:
- Update task status to "researching" in state.json
- Update TODO.md status marker to [RESEARCHING]

If no task_number:
- Create postflight marker noting task will be created

## Stage 3: Invoke Agent with Three-Phase Prompt

Agent prompt includes:
- input_type and context_content from delegation
- Instruction to execute three-phase workflow
- Metadata file path for return

## Stage 7: Update Task Status (Postflight)

1. If task was created by agent, update state.json with new task
2. Update status to "researched"
3. Link artifact in state.json
4. Update TODO.md

## Stage 8: Git Commit

Commit with appropriate message based on operation.
```

### Agents to Modify

#### market-agent Changes

**Three-Phase Execution Flow**:

```markdown
## Stage 1: Phase 1 - Context Gathering

Based on input_type:

### If "file_path" or "task_number":
1. Parse provided context_content
2. Extract: industry, problem statement, data sources, competitors
3. Build context summary for Phase 2

### If "no_argument":
1. Ask open-ended initial question via AskUserQuestion:
   ```
   Let's start your market sizing analysis.

   What product or business are you analyzing? Please describe:
   - What problem does it solve?
   - Who is your target customer?
   - What stage are you at (idea, MVP, paying customers)?
   ```
2. Parse response to extract context
3. Create task entry if not yet created

## Stage 2: Phase 2 - Context-Aware Forcing Questions

Use context from Phase 1 to tailor questions.

### Mode Selection
If mode not pre-selected:
```
Based on your context, I recommend {recommended_mode} mode because {reason}.

Select your market sizing mode:
A) VALIDATE - Test assumptions with evidence gathering
B) SIZE - Comprehensive TAM/SAM/SOM with full methodology
C) SEGMENT - Deep dive into specific segments
D) DEFEND - Investor-ready with conservative estimates
```

### TAM Questions (adapted to context)
Ask one at a time, reference context:
- Q1: "You mentioned {context_item}. What specific problem does your product solve? For whom?"
- Q2: "How many {context_segment} entities have this problem?"
- etc.

## Stage 3: Phase 3 - Synthesis

1. Compile all data from Phase 1 and Phase 2
2. Generate market-sizing report using template
3. Write to task directory: `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`
4. Write metadata file
5. Return brief text summary
```

---

### State Management Changes

**New State Flow**:

```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED]
                     ^
                     |
            (founder commands use research phase)
```

**Artifact Linking**:

```json
{
  "project_number": 234,
  "project_name": "market_sizing_fintech_payments",
  "status": "researched",
  "language": "founder",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/234_market_sizing_fintech_payments/reports/01_market-sizing-analysis.md",
      "summary": "TAM/SAM/SOM analysis for fintech payments segment"
    }
  ]
}
```

---

## Files to Modify/Create

### Commands (Modify)

| File | Changes |
|------|---------|
| `extensions/founder/commands/market.md` | Add input type detection, task creation, three-phase delegation |
| `extensions/founder/commands/analyze.md` | Same pattern as market.md |
| `extensions/founder/commands/strategy.md` | Same pattern as market.md |

### Skills (Modify)

| File | Changes |
|------|---------|
| `extensions/founder/skills/skill-market/SKILL.md` | Add preflight/postflight, task lifecycle, metadata file handling |
| `extensions/founder/skills/skill-analyze/SKILL.md` | Same pattern |
| `extensions/founder/skills/skill-strategy/SKILL.md` | Same pattern |

### Agents (Modify)

| File | Changes |
|------|---------|
| `extensions/founder/agents/market-agent.md` | Implement three-phase workflow, context-aware questions |
| `extensions/founder/agents/analyze-agent.md` | Same pattern |
| `extensions/founder/agents/strategy-agent.md` | Same pattern |

### Context (Modify)

| File | Changes |
|------|---------|
| `extensions/founder/context/project/founder/patterns/forcing-questions.md` | Add context-aware question patterns |

### Manifest (Modify)

| File | Changes |
|------|---------|
| `extensions/founder/manifest.json` | Update routing to use language "founder" properly |

---

## Decisions

1. **Task Creation Mode**: Commands create tasks automatically when invoked with file path or no argument. Existing task number mode operates on pre-existing tasks.

2. **Phase Naming**: Use "Context Gathering", "Interactive Questions", "Synthesis" for clarity in code and documentation.

3. **Status Progression**: Founder commands use the research phase (`researching` -> `researched`) since they produce analysis reports, not implementation plans.

4. **Artifact Type**: Use `type: "research"` for founder artifacts, enabling consistent artifact filtering.

5. **Language Tag**: Keep `language: "founder"` to enable founder-specific routing and context loading.

6. **Legacy Mode**: Support `--mode` flag without task creation for backward compatibility with existing workflows.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing workflows | High | Add `--no-task` flag for legacy mode |
| Question workflow feels too long | Medium | Allow `--quick` mode that skips Phase 1 |
| File path detection false positives | Low | Explicit `--file` flag option |
| Task status conflicts | Medium | Validate status in preflight, clear error messages |
| Large files slow down Phase 1 | Low | Limit file read to first 10KB, summarize |

---

## Context Extension Recommendations

None. This task modifies the existing founder extension rather than creating new context files.

---

## Next Steps

1. Run `/plan 234` to create implementation plan
2. Implement in phases:
   - Phase 1: Update commands with input type detection
   - Phase 2: Update skills with task lifecycle
   - Phase 3: Update agents with three-phase workflow
   - Phase 4: Test all input modes
3. Consider creating a common `founder-skill-base.md` to reduce duplication across skills

---

## Appendix: Design Patterns Summary

### Three-Phase Workflow Pattern

```
Phase 1: Context Gathering
  ├── File input: Read and extract context
  ├── Task input: Load existing artifacts
  └── No input: Ask open-ended question

Phase 2: Interactive Questions
  ├── Mode selection (context-aware recommendation)
  └── Forcing questions (one at a time, push for specificity)

Phase 3: Synthesis
  ├── Compile data from Phase 1 + Phase 2
  ├── Generate report using template
  ├── Write artifact to task directory
  └── Write metadata file
```

### Input Detection Pattern

```python
def detect_input_type(args):
    if args is None or args.strip() == "":
        return InputType.NO_ARGUMENT

    # Check for task number
    if re.match(r"^\d+$", args) or args.startswith("--task"):
        return InputType.TASK_NUMBER

    # Check for file path
    if args.startswith(("/", "~", ".")) or re.search(r"\.(md|txt|pdf)$", args):
        return InputType.FILE_PATH

    # Check for legacy mode flag
    if args.startswith("--mode"):
        return InputType.LEGACY_MODE

    # Default: treat as industry/segment hint (legacy)
    return InputType.HINT
```

### Skill-Internal Postflight Pattern

```
1. Create postflight marker BEFORE agent invocation
2. Agent writes metadata to .return-meta.json
3. Skill reads metadata file AFTER agent returns
4. Skill handles: status update, artifact linking, git commit
5. Skill removes marker files
6. Skill returns brief text summary
```

---

## Appendix: Example Command Invocations

```bash
# No argument - opens with question
/market

# File path - uses file as context
/market ~/startup/pitch-deck.md

# Task number - operates on existing task
/market 234

# Legacy mode - backward compatible
/market fintech payments --mode SIZE
```
