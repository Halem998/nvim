# Research Report: Task #227

**Task**: 227 - Enhance /meta with topic consolidation and embedded research
**Started**: 2026-03-18T00:00:00Z
**Completed**: 2026-03-18T01:00:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase analysis: .claude/commands/meta.md, .claude/commands/fix-it.md, .claude/commands/review.md
- Codebase analysis: .claude/agents/meta-builder-agent.md, .claude/skills/skill-meta/SKILL.md
- Codebase analysis: .claude/skills/skill-fix-it/SKILL.md
- Standard reference: .claude/docs/reference/standards/multi-task-creation-standard.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- /meta command currently implements all 8 components of multi-task creation standard, but lacks **proactive topic consolidation** and **embedded research artifact generation**
- /fix-it command provides the reference pattern for **interactive topic grouping** via AskUserQuestion with multiSelect, topic clustering algorithm, and three grouping modes (grouped/separate/combined)
- Enhancement requires modifications to **meta-builder-agent.md** Interview Stages 3-5 to add topic analysis after user provides task breakdown, and new Stage 4.5 for research artifact generation
- Tasks should start in **RESEARCHED** status by generating lightweight research reports during task creation (similar to how /fix-it creates task descriptions with embedded context)

---

## Context & Scope

### What Was Researched

1. Current /meta command implementation and workflow
2. /fix-it command's interactive picker pattern for topic selection
3. Multi-task creation standard (8-component pattern)
4. AskUserQuestion syntax and options for multiSelect
5. Integration points for topic consolidation and embedded research

### Constraints

- Must maintain backward compatibility with existing /meta modes (interactive, prompt, analyze)
- Must follow multi-task creation standard (already implemented as reference)
- Must use AskUserQuestion for user interaction (consistent with other commands)
- Tasks must start in RESEARCHED status (requires research artifact generation)

---

## Findings

### 1. Current /meta Implementation Analysis

**File**: `.claude/agents/meta-builder-agent.md`

The current meta-builder-agent uses a 7-stage interview workflow:

| Stage | Purpose | Current Behavior |
|-------|---------|-----------------|
| 0 | DetectExistingSystem | Inventory .claude/ components |
| 1 | InitiateInterview | Explain process to user |
| 2 | GatherDomainInfo | Purpose and scope questions |
| 3 | IdentifyUseCases | Task breakdown (user-provided) |
| 4 | AssessComplexity | Effort estimates |
| 5 | ReviewAndConfirm | Mandatory confirmation |
| 6 | CreateTasks | Update TODO.md and state.json |
| 7 | DeliverSummary | Display results |

**Gap Identified**: Stage 3 asks users to provide task breakdown directly. There is no **proactive topic consolidation** where the system analyzes related items and suggests groupings. User must manually organize their change requests.

**Current Stage 3 Question 4** (from meta-builder-agent.md:256-259):
```json
{
  "question": "Can this be broken into smaller, independent tasks?",
  "header": "Task Breakdown",
  "options": [
    {"label": "Yes, there are multiple steps", ...},
    {"label": "No, it's a single focused change", ...},
    {"label": "Help me break it down", ...}
  ]
}
```

This is passive - it asks the user to break down their request rather than actively analyzing and suggesting consolidation.

### 2. /fix-it Interactive Picker Pattern (Reference Implementation)

**File**: `.claude/skills/skill-fix-it/SKILL.md`

The /fix-it command demonstrates the complete interactive picker pattern for topic consolidation:

#### 2.1 Topic Extraction Algorithm (Steps 7.5.1)

For each item, extract:
- **Key Terms**: Significant words (nouns, verbs), ignore stop words
- **File Section**: Path prefix for grouping related items
- **Action Type**: Categorize by action (implement, fix, document, test, refactor)

```
Example extraction:
TODO: "Add custom picker for worktrees" at nvim/lua/plugins/telescope.lua:67
  -> key_terms: ["picker", "worktrees", "telescope"]
  -> file_section: "nvim/lua/plugins/"
  -> action_type: "implementation"
```

#### 2.2 Clustering Algorithm (Step 7.5.2)

```
Groups items that share:
- 2+ significant key terms, OR
- Same file_section AND action_type
```

#### 2.3 Topic Group Confirmation (Step 7.5.4)

```json
{
  "question": "How should TODO items be grouped into tasks?",
  "header": "TODO Topic Grouping",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept suggested topic groups",
      "description": "Creates {N} grouped tasks: {group_summaries}"
    },
    {
      "label": "Keep as separate tasks",
      "description": "Creates {M} individual tasks (one per item)"
    },
    {
      "label": "Create single combined task",
      "description": "Creates 1 task containing all items"
    }
  ]
}
```

#### 2.4 Effort Scaling Formula

```
base_effort = 1 hour
scaled_effort = base_effort + (30 min * (item_count - 1))

Examples:
  1 item  -> 1 hour
  2 items -> 1.5 hours
  3 items -> 2 hours
```

### 3. Multi-Task Creation Standard Components

**File**: `.claude/docs/reference/standards/multi-task-creation-standard.md`

The /meta command is already the **reference implementation** for all 8 components:

| Component | Current Status | Enhancement Needed |
|-----------|---------------|-------------------|
| Discovery | Yes (Interview Stage 2-3) | Enhance with proactive analysis |
| Selection | Yes (Interview Stage 5) | Add topic selection picker |
| Grouping | User-defined only | Add automatic clustering |
| Dependencies | Full (Stage 3 Question 5) | No change |
| Ordering | Yes (Kahn's algorithm) | No change |
| Visualization | Yes (Linear/Layered DAG) | No change |
| Confirmation | Yes (Stage 5) | No change |
| State Updates | Yes (Batch insertion) | Enhance for RESEARCHED status |

**Key Enhancement**: Add automated topic clustering like /fix-it, then let user confirm/modify groupings.

### 4. AskUserQuestion Syntax for Interactive Pickers

Standard AskUserQuestion pattern with multiSelect for topic selection:

```json
{
  "question": "Which topics should be consolidated into single tasks?",
  "header": "Topic Consolidation",
  "multiSelect": true,
  "options": [
    {
      "label": "[Topic] {topic_name} ({item_count} items)",
      "description": "{item_summaries}"
    },
    ...
  ]
}
```

**Key Syntax Elements**:
- `multiSelect: true` for selecting multiple items
- `multiSelect: false` for single-choice (like grouping mode)
- `label`: Primary text shown to user
- `description`: Secondary context text

### 5. Research Artifact Generation for RESEARCHED Status

To have tasks start in RESEARCHED status, /meta needs to generate research artifacts during task creation.

**Current state.json entry format** (from multi-task-creation-standard.md:280-285):
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "language": "meta",
  "dependencies": [35, 34]
}
```

**Required change for RESEARCHED status**:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "researched",
  "language": "meta",
  "dependencies": [35, 34]
}
```

**Research artifact generation during task creation**:

The meta-builder-agent should:
1. Create task directory: `specs/{NNN}_{slug}/reports/`
2. Generate lightweight research report: `01_meta-research.md`
3. Populate with context gathered during interview (purpose, scope, affected components, user requirements)
4. Set status to "researched" in state.json

---

## Recommendations

### Recommended Approach: Three-Phase Enhancement

#### Phase 1: Add Topic Consolidation to Interview Stage 3

**Location**: meta-builder-agent.md, Interview Stage 3

**New Step 3.5**: After user provides task breakdown in Stage 3, analyze items for topics:

```markdown
### Interview Stage 3.5: AnalyzeTopics

**Condition**: User selected "Yes, there are multiple steps" in Question 3 AND provided task_list with 2+ items

**3.5.1: Extract Topic Indicators**

For each task in task_list, extract:
- **Key Terms**: Extract significant words (nouns, verbs) from task description
- **Component Type**: Identify component type (command, skill, agent, rule, context)
- **Affected Area**: Parse for directory/file mentions (.claude/commands/, .claude/skills/, etc.)
- **Action Type**: Map to action categories (create, modify, fix, document, refactor)

**3.5.2: Cluster Tasks by Shared Indicators**

Apply clustering algorithm (same as /fix-it Step 7.5.2):
- Group tasks sharing 2+ key terms
- Group tasks sharing component_type AND affected_area

**3.5.3: Generate Topic Labels**

For each group, generate label from:
- Most common key terms
- Component type (e.g., "Command Creation", "Agent Configuration")
- Affected area (e.g., ".claude/skills/ changes")

**3.5.4: Present Topic Consolidation Options**

```json
{
  "question": "How should related tasks be grouped?",
  "header": "Topic Consolidation",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept suggested topic groups",
      "description": "Creates {N} consolidated tasks: {group_summaries}"
    },
    {
      "label": "Keep as separate tasks",
      "description": "Creates {M} individual tasks (as provided)"
    },
    {
      "label": "Customize groupings",
      "description": "I'll specify which items to combine"
    }
  ]
}
```

**If "Customize groupings" selected**, present Tier 2 selection with multiSelect to let user pick which items belong together.
```

#### Phase 2: Add Research Artifact Generation (New Stage 4.5)

**Location**: meta-builder-agent.md, after Interview Stage 4

```markdown
### Interview Stage 4.5: GenerateResearchArtifacts

**Condition**: User confirmed task creation (Stage 5 passed) - execute after confirmation but before state updates

**4.5.1: For Each Task to be Created**

Create task directory:
```bash
task_num=$next_project_number
slug={generated_slug}
mkdir -p "specs/${task_num}_${slug}/reports"
```

**4.5.2: Generate Research Report**

Write to `specs/{NNN}_{slug}/reports/01_meta-research.md`:

```markdown
# Research Report: Task #{N}

**Task**: {N} - {title}
**Generated**: {ISO_DATE}
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: {purpose from Stage 2}
**Scope**: {scope from Stage 2}
**Affected Components**: {affected_components}
**Domain**: {detected_domain}

## Task Requirements

{task_description}

## Integration Points

- Component type: {component_type}
- Related files: {file_list if identified}
- Dependencies: {dependency_list}

## Implementation Notes

{any additional context from interview}

---

*This research report was auto-generated during task creation via /meta command.
For additional research, run `/research {N}` with a focus prompt.*
```

**4.5.3: Update Status for RESEARCHED**

When creating state.json entries in Stage 6, use:
```json
{
  "status": "researched"
}
```

Instead of:
```json
{
  "status": "not_started"
}
```
```

#### Phase 3: Update skill-meta.md Postflight

**Location**: .claude/skills/skill-meta/SKILL.md

**Update Step 5 (Return Propagation)**:

If tasks were created with RESEARCHED status, include research artifacts in return:

```json
{
  "status": "tasks_created",
  "artifacts": [
    {
      "type": "task",
      "path": "specs/430_create_export_command/",
      "summary": "Task directory for new command"
    },
    {
      "type": "research",
      "path": "specs/430_create_export_command/reports/01_meta-research.md",
      "summary": "Auto-generated research from interview context"
    }
  ]
}
```

### Integration Points Summary

| File | Modification | Purpose |
|------|--------------|---------|
| meta-builder-agent.md | Add Stage 3.5 | Topic consolidation picker |
| meta-builder-agent.md | Add Stage 4.5 | Research artifact generation |
| meta-builder-agent.md | Modify Stage 6 | Status = "researched" |
| skill-meta.md | Update return format | Include research artifacts |
| meta.md | Update documentation | Document new behavior |

---

## Decisions

1. **Topic consolidation placement**: Add as Stage 3.5 after user provides breakdown, not during discovery. This allows the system to analyze user input rather than preemptively guessing.

2. **Research artifact depth**: Generate lightweight reports from interview context, not full web research. Users can run `/research N` for deeper investigation if needed.

3. **Grouping mode options**: Use same three options as /fix-it (accept/separate/customize) for consistency across commands.

4. **Status progression**: Tasks start at RESEARCHED (skip NOT_STARTED and RESEARCHING) since /meta interview captures sufficient context for planning.

---

## Risks & Mitigations

### Risk 1: Topic Clustering May Not Match User Intent

**Description**: Automatic clustering might group items that user wants separate, or fail to group items user considers related.

**Mitigation**: Always present grouping as a **suggestion** with user confirmation. Include "Customize groupings" option for full control.

### Risk 2: Auto-Generated Research May Be Insufficient

**Description**: Lightweight research reports from interview context may not provide enough detail for planning phase.

**Mitigation**:
- Clearly label reports as "auto-generated from interview context"
- Include note: "For additional research, run `/research {N}` with a focus prompt"
- The RESEARCHED status enables immediate `/plan N` but doesn't prevent `/research N` if user wants more detail

### Risk 3: Interview Flow Becomes Too Long

**Description**: Adding topic consolidation step may make interactive mode feel cumbersome.

**Mitigation**:
- Skip Stage 3.5 if only 1 task provided (no consolidation benefit)
- Skip Stage 3.5 if tasks have no shared indicators (no obvious groupings)
- Keep consolidation question single-select (not multi-step like /fix-it for granularity)

---

## Context Extension Recommendations

None - this task is a meta task modifying the .claude/ system. Context files are not typically created for meta tasks as the changes are self-documenting in the command/agent files.

---

## Appendix

### Search Queries Used

1. Codebase search: `Glob("**/*.md")` for meta.md, fix-it.md, review.md
2. Codebase search: `Grep("AskUserQuestion.*multiSelect")` for picker patterns
3. File reads: multi-task-creation-standard.md for 8-component pattern
4. File reads: skill-fix-it/SKILL.md for complete topic grouping implementation

### References

- `/meta` command: `.claude/commands/meta.md`
- `/fix-it` command: `.claude/commands/fix-it.md` and `.claude/skills/skill-fix-it/SKILL.md`
- `/review` command: `.claude/commands/review.md`
- Meta-builder agent: `.claude/agents/meta-builder-agent.md`
- Multi-task creation standard: `.claude/docs/reference/standards/multi-task-creation-standard.md`
- Skill-meta: `.claude/skills/skill-meta/SKILL.md`

### Topic Clustering Algorithm (from /fix-it)

```python
# Clustering algorithm for reference
groups = []

for each item in all_items:
  matched = false

  # Primary match: same component_type AND same affected_area
  for each group in groups:
    if item.component_type == group.component_type AND item.affected_area == group.affected_area:
      add item to group.items
      matched = true
      break

  # Secondary match: 2+ shared key_terms
  if not matched:
    for each group in groups:
      shared_terms = intersection(item.key_terms, group.key_terms)
      if len(shared_terms) >= 2:
        add item to group.items
        update group.key_terms with union
        matched = true
        break

  # No match: create new group
  if not matched:
    create new group with item
```

### Effort Scaling Formula (for consolidated tasks)

```
base_effort = 1 hour
scaled_effort = base_effort + (30 min * (item_count - 1))

Examples:
  1 item  -> 1 hour
  2 items -> 1.5 hours
  3 items -> 2 hours
  4 items -> 2.5 hours
  5 items -> 3 hours
```
