# Research Report: Task #234 (Supplemental)

**Task**: 234 - upgrade_founder_extension_workflow
**Started**: 2026-03-18T02:00:00Z
**Completed**: 2026-03-18T03:30:00Z
**Effort**: 8-12 hours implementation
**Dependencies**: Task #233 (current founder/ extension implementation)
**Sources/Inputs**: Codebase analysis of plan.md, implement.md, skill-planner, skill-implementer, founder extension
**Artifacts**: specs/234_upgrade_founder_extension_workflow/reports/02_plan-implement-workflow.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/plan` and `/implement` commands use language-based routing to delegate to appropriate skills and agents
- Adding "founder" as a language type enables seamless integration with the existing task workflow
- The proposed architecture creates `skill-founder-plan` and `skill-founder-implement` with corresponding agents
- Standalone commands (`/market`, `/analyze`, `/strategy`) should become shortcuts that create tasks and run the workflow
- Reports go to `strategy/{report-type}.md` by default, with plans in `specs/{NNN}_{SLUG}/plans/`

---

## Context & Scope

This supplemental research focuses on:

1. How `/plan` and `/implement` route to skills based on task language
2. The skill-internal postflight pattern for state management
3. How to add "founder" language type with proper routing
4. Designing the interactive forcing questions flow during planning
5. Report output location handling

---

## Findings

### 1. Language-Based Routing in `/plan` and `/implement`

**Current Routing Table (from implement.md):**

```
| Language | Skill to Invoke |
|----------|-----------------|
| general, meta, markdown | skill-implementer |
| formal, logic, math, physics | skill-implementer |
```

**Routing Extension Mechanism:**

Extensions provide language-specific routing via `manifest.json`:

```json
{
  "routing": {
    "research": {
      "founder": "skill-market"
    },
    "implement": {
      "founder": "skill-strategy"
    }
  }
}
```

**Key Insight**: The current founder manifest routes `founder` tasks to `skill-market` for research and `skill-strategy` for implementation. However, this doesn't align with the new workflow where `/plan` should create a *plan* and `/implement` should *execute* that plan.

**Proposed Routing Update:**

```json
{
  "routing": {
    "research": {
      "founder": "skill-founder-research"
    },
    "plan": {
      "founder": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement"
    }
  }
}
```

**Note**: The `plan` routing key is new. Currently, `/plan` always routes to `skill-planner`. The extension system needs to support `plan` routing for language-specific planning workflows.

---

### 2. Plan Command Structure Analysis

**Current `/plan` Flow:**

```
/plan N
  |
  v
CHECKPOINT 1: GATE IN
  - Generate session_id
  - Lookup task in state.json
  - Validate status (not_started, researched, partial)
  - Load research reports if any
  |
  v
STAGE 2: DELEGATE
  - skill: "skill-planner"
  - args: "task_number={N} research_path={path} session_id={session_id}"
  |
  v
skill-planner
  - Preflight: Update status to "planning"
  - Invoke: Task tool -> planner-agent
  - Postflight: Update status to "planned", link artifacts, git commit
  |
  v
CHECKPOINT 2: GATE OUT
  - Validate return
  - Verify plan file exists
  |
  v
CHECKPOINT 3: COMMIT
  - git add -A
  - git commit
```

**Key Pattern**: The skill handles all state management (preflight/postflight), not the command. The command just validates and delegates.

---

### 3. Adding "founder" to Plan Routing

**Option A: Extend `/plan` Command**

Add language-based routing to `/plan` similar to `/implement`:

```markdown
### STAGE 2: DELEGATE

**Language-Based Routing:**

| Language | Skill to Invoke |
|----------|-----------------|
| general, meta, markdown | skill-planner |
| founder | skill-founder-plan |
```

**Option B: Extension Manifest Routing (Preferred)**

The extension manifest already supports `routing`. Adding `plan` key:

```json
{
  "routing": {
    "plan": {
      "founder": "skill-founder-plan"
    }
  }
}
```

The `/plan` command would need modification to check extension routing:

```bash
# In /plan command, STAGE 2: DELEGATE
language=$(echo "$task_data" | jq -r '.language // "general"')

# Check extension routing first
skill_name=$(jq -r --arg lang "$language" \
  '.routing.plan[$lang] // "skill-planner"' \
  .claude/extensions/*/manifest.json 2>/dev/null | head -1)

# Fallback to default
skill_name=${skill_name:-"skill-planner"}
```

---

### 4. Founder-Specific Planning Workflow Design

The `skill-founder-plan` and `founder-plan-agent` implement a specialized workflow:

#### Stage 1: Parse Context

The agent receives:
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_analysis_fintech",
    "description": "Market analysis for fintech payments vertical",
    "language": "founder"
  },
  "research_path": "specs/234_market_analysis_fintech/reports/01_initial-context.md",
  "metadata_file_path": "specs/234_market_analysis_fintech/.return-meta.json"
}
```

#### Stage 2: Load Existing Context

If `research_path` exists:
- Read prior research reports
- Extract key findings, assumptions, data sources
- Build context for forcing questions

If file/task reference provided in description:
- Read referenced file
- Extract relevant business context

#### Stage 3: Interactive Forcing Questions

**Key Difference from Standard Planning**: Instead of decomposing into implementation phases, the founder-plan-agent asks forcing questions to gather data for the final report.

**Forcing Questions for Market Sizing Plan:**

1. **Problem Definition**
   ```
   Based on your context, let's define the problem scope.

   What specific problem does your product solve? For whom?

   Push for: Specific problem statement, specific customer type
   ```

2. **Market Boundaries**
   ```
   Now let's establish market boundaries.

   Which geographies can you actually serve today?

   Push for: Specific countries/regions with rationale
   ```

3. **Data Sources**
   ```
   For credible market sizing, we need data sources.

   What research reports or databases have market size data for your industry?

   Push for: Named sources (Gartner, CB Insights, industry reports)
   ```

4. **Competitive Context**
   ```
   Understanding competitors helps validate market size.

   Name the top 3 direct competitors. What's their estimated revenue?

   Push for: Named companies with revenue estimates
   ```

5. **Pricing Model**
   ```
   Let's establish your price point assumptions.

   What's your target price per unit/seat/month? What comparables justify this?

   Push for: Dollar amount with competitive rationale
   ```

6. **Capture Rate Realism**
   ```
   Finally, let's set realistic capture expectations.

   What market share can you realistically achieve in Year 1? Year 3?

   Push for: Percentages with justification
   ```

#### Stage 4: Generate Plan Artifact

After forcing questions, generate a plan that outlines:

```markdown
# Implementation Plan: Task #234

**Task**: Market analysis for fintech payments vertical
**Version**: 01
**Created**: 2026-03-18
**Language**: founder

## Overview

Market sizing analysis plan based on forcing questions session.

## Gathered Context

### Problem Definition
- Problem: {from Q1}
- Target: {from Q1}

### Market Boundaries
- Geographies: {from Q2}
- Exclusions: {noted}

### Data Sources
- {source1}: {description}
- {source2}: {description}

### Competitive Context
- {competitor1}: {revenue estimate}
- {competitor2}: {revenue estimate}

### Pricing Assumptions
- Price point: {from Q5}
- Justification: {from Q5}

### Capture Rate Targets
- Year 1: {from Q6}
- Year 3: {from Q6}

## Phases

### Phase 1: TAM Calculation [NOT STARTED]

**Objectives**:
1. Calculate Total Addressable Market using {methodology}
2. Document data sources and assumptions

**Inputs**:
- {data_source_1}
- {data_source_2}

**Outputs**:
- TAM figure with methodology
- Assumption documentation

### Phase 2: SAM Narrowing [NOT STARTED]

**Objectives**:
1. Apply geographic and segment filters
2. Calculate Serviceable Addressable Market

**Inputs**:
- TAM from Phase 1
- Geographic constraints
- Segment exclusions

**Outputs**:
- SAM figure
- Narrowing factor documentation

### Phase 3: SOM Projection [NOT STARTED]

**Objectives**:
1. Apply capture rate assumptions
2. Calculate Serviceable Obtainable Market

**Inputs**:
- SAM from Phase 2
- Capture rate targets
- Competitive landscape

**Outputs**:
- SOM Y1 and Y3 projections
- Growth assumptions

### Phase 4: Report Generation [NOT STARTED]

**Objectives**:
1. Synthesize all findings into final report
2. Generate investor one-pager

**Outputs**:
- strategy/market-sizing-{topic}.md
- Executive summary

## Report Output

- **Location**: strategy/market-sizing-fintech-payments.md
- **Template**: market-sizing.md

## Success Criteria

- [ ] TAM calculated with cited sources
- [ ] SAM narrowed with explicit exclusions
- [ ] SOM projected with realistic capture rates
- [ ] Red flags section included
- [ ] Investor one-pager generated
```

---

### 5. Founder-Specific Implementation Workflow Design

The `skill-founder-implement` and `founder-implement-agent` execute the plan:

#### Stage 1: Load Plan

Read the plan from `specs/{NNN}_{SLUG}/plans/`:
- Extract gathered context
- Identify resume point (Phase 1 if new)

#### Stage 2: Execute Phases

**Phase 1: TAM Calculation**
- Use gathered data sources
- Apply top-down and/or bottom-up methodology
- Calculate TAM figure

**Phase 2: SAM Narrowing**
- Apply geographic filters
- Apply segment exclusions
- Calculate SAM

**Phase 3: SOM Projection**
- Apply capture rate assumptions
- Project Year 1 and Year 3 figures

**Phase 4: Report Generation**
- Compile all data into final report
- Use `market-sizing.md` template
- Generate investor one-pager
- Write to `strategy/market-sizing-{topic}.md`

#### Stage 3: Write Report Artifact

**Default Location**: `strategy/market-sizing-{topic}.md`

**Custom Location**: If `--output` specified in task description:
- Parse output path from description
- Write to specified location

**Example Output Path Resolution:**

```bash
# Default
output_path="strategy/market-sizing-$(echo "$project_name" | sed 's/_/-/g').md"

# From task description (if --output specified)
# Task description: "Market analysis for fintech --output ~/reports/fintech-market.md"
if echo "$description" | grep -q '\-\-output'; then
  output_path=$(echo "$description" | sed 's/.*--output \([^ ]*\).*/\1/')
  output_path=$(eval echo "$output_path")  # Expand ~
fi
```

#### Stage 4: Write Summary

Create summary in `specs/{NNN}_{SLUG}/summaries/`:

```markdown
# Implementation Summary: Task #234

**Completed**: 2026-03-18
**Duration**: 45 minutes

## Changes Made

Generated market sizing analysis for fintech payments vertical.

## Files Created

- `strategy/market-sizing-fintech-payments.md` - Full market sizing report

## Key Results

- TAM: $50B (global fintech payments)
- SAM: $8B (US SMB segment)
- SOM Y1: $40M (0.5% capture)
- SOM Y3: $200M (2.5% capture)

## Verification

- All data sources cited
- Assumptions documented
- Red flags identified
- Investor one-pager included
```

---

### 6. Standalone Command Transformation

**Current State**: `/market`, `/analyze`, `/strategy` are standalone commands that:
- Generate session ID
- Invoke skill directly
- Write to `founder/` directory
- No task integration

**Proposed Options:**

#### Option A: Commands Become Task Shortcuts (Recommended)

```
/market "fintech payments"
  |
  v
Creates task:
  - project_number: {next}
  - project_name: "market_sizing_fintech_payments"
  - language: "founder"
  - description: "Market sizing: fintech payments"
  |
  v
Runs /plan {task_number}
  |
  v
Runs /implement {task_number}
```

**Implementation in market.md:**

```markdown
# /market Command

## CHECKPOINT 1: GATE IN

### Step 1: Create Task

```bash
# Generate session ID
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"

# Get next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Create task
slug="market_sizing_$(echo "$ARGUMENTS" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
jq --arg num "$next_num" \
   --arg name "$slug" \
   --arg lang "founder" \
   --arg desc "Market sizing: $ARGUMENTS" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '. + {
     next_project_number: ($num | tonumber + 1)
   } | .active_projects += [{
     project_number: ($num | tonumber),
     project_name: $name,
     status: "not_started",
     language: $lang,
     description: $desc,
     created: $ts
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Step 2: Run Planning

Invoke `/plan {task_number}` which routes to `skill-founder-plan` based on language.

### Step 3: Run Implementation

Invoke `/implement {task_number}` which routes to `skill-founder-implement`.
```

**Advantages:**
- Full task tracking
- Resume capability
- Artifact linking
- Git commit history

**Disadvantages:**
- More steps for simple analyses
- May feel heavyweight for quick questions

#### Option B: Commands Support Both Modes

Add `--quick` flag for standalone mode:

```
/market fintech payments         # Full task workflow
/market --quick fintech payments # Standalone (legacy) mode
```

**Implementation:**

```markdown
### Step 0: Check Quick Mode

```bash
if echo "$ARGUMENTS" | grep -q '\-\-quick'; then
  # Remove flag from arguments
  ARGUMENTS=$(echo "$ARGUMENTS" | sed 's/--quick//')

  # Delegate directly to skill (legacy mode)
  skill: "skill-market"
  args: "industry={industry} segment={segment} mode={mode} session_id={session_id}"
  # Output to founder/ directory
  exit
fi
```

#### Option C: Keep Commands Separate, Add Task Commands

Keep `/market`, `/analyze`, `/strategy` as quick standalone commands.

Add new task-integrated commands:
- `/market-task` or `/task-market`
- Or use existing workflow: `/task "Market sizing for fintech" --language founder`

**Recommendation**: Option A (commands become task shortcuts) is cleanest. Users who want quick mode can use `--quick` flag (Option B hybrid).

---

### 7. Report Output Location Handling

**Default Location**: `strategy/{report-type}-{topic}.md`

**Custom Location via Task Description:**

Parse `--output` from task description:

```
Task description: "Market sizing for fintech --output ~/startup/reports/market.md"
```

**Storage in state.json:**

```json
{
  "project_number": 234,
  "project_name": "market_sizing_fintech",
  "language": "founder",
  "metadata": {
    "output_path": "~/startup/reports/market.md"
  }
}
```

**Resolution in Agent:**

```bash
# Check for custom output path
output_path=$(echo "$task_data" | jq -r '.metadata.output_path // ""')

if [ -z "$output_path" ]; then
  # Use default
  output_path="strategy/market-sizing-${slug}.md"
else
  # Expand path
  output_path=$(eval echo "$output_path")
fi

# Ensure directory exists
mkdir -p "$(dirname "$output_path")"
```

---

### 8. Extension Manifest Updates

**Updated manifest.json:**

```json
{
  "name": "founder",
  "version": "2.0.0",
  "description": "Strategic business analysis for founders with task integration",
  "language": "founder",
  "dependencies": [],
  "provides": {
    "agents": [
      "market-agent.md",
      "analyze-agent.md",
      "strategy-agent.md",
      "founder-plan-agent.md",
      "founder-implement-agent.md"
    ],
    "skills": [
      "skill-market",
      "skill-analyze",
      "skill-strategy",
      "skill-founder-plan",
      "skill-founder-implement"
    ],
    "commands": [
      "market.md",
      "analyze.md",
      "strategy.md"
    ],
    "rules": [],
    "context": ["project/founder"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "founder": "skill-founder-research"
    },
    "plan": {
      "founder": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement"
    }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_founder"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

---

## Complete Workflow Diagram

```
User runs: /market "fintech payments"
    |
    v
CHECKPOINT 1: GATE IN (in /market command)
    |
    +--> Parse arguments: "fintech payments"
    |
    +--> Create task in state.json:
    |      - project_number: 235
    |      - project_name: "market_sizing_fintech_payments"
    |      - language: "founder"
    |      - status: "not_started"
    |
    +--> Update TODO.md: Add task entry
    |
    v
STAGE 2: INVOKE /plan 235
    |
    v
/plan 235
    |
    +--> GATE IN: Lookup task, validate status
    |
    +--> Route by language: founder -> skill-founder-plan
    |
    v
skill-founder-plan
    |
    +--> Preflight: Update status to "planning"
    |
    +--> Create postflight marker
    |
    +--> Task tool -> founder-plan-agent
    |        |
    |        +--> Load context (research reports if any)
    |        |
    |        +--> Interactive forcing questions (6-8 questions)
    |        |     - Problem definition
    |        |     - Market boundaries
    |        |     - Data sources
    |        |     - Competitive context
    |        |     - Pricing assumptions
    |        |     - Capture rate targets
    |        |
    |        +--> Generate plan artifact:
    |        |     specs/235_market_sizing_fintech_payments/plans/01_market-sizing-plan.md
    |        |
    |        +--> Write metadata file
    |        |
    |        +--> Return brief summary
    |
    +--> Postflight: Update status to "planned", link artifacts
    |
    +--> Git commit
    |
    v
STAGE 3: INVOKE /implement 235
    |
    v
/implement 235
    |
    +--> GATE IN: Lookup task, find plan, detect resume point
    |
    +--> Route by language: founder -> skill-founder-implement
    |
    v
skill-founder-implement
    |
    +--> Preflight: Update status to "implementing"
    |
    +--> Create postflight marker
    |
    +--> Task tool -> founder-implement-agent
    |        |
    |        +--> Load plan from specs/235.../plans/
    |        |
    |        +--> Execute phases:
    |        |     - Phase 1: TAM calculation
    |        |     - Phase 2: SAM narrowing
    |        |     - Phase 3: SOM projection
    |        |     - Phase 4: Report generation
    |        |
    |        +--> Write report artifact:
    |        |     strategy/market-sizing-fintech-payments.md
    |        |
    |        +--> Write summary:
    |        |     specs/235.../summaries/01_market-sizing-summary.md
    |        |
    |        +--> Write metadata file
    |        |
    |        +--> Return brief summary
    |
    +--> Postflight: Update status to "completed", link artifacts
    |
    +--> Git commit
    |
    v
CHECKPOINT 2: GATE OUT (back in /market command)
    |
    +--> Display final result:
         Market sizing complete for Task #235

         Report: strategy/market-sizing-fintech-payments.md

         Key Numbers:
         - TAM: $50B
         - SAM: $8B
         - SOM Y1: $40M

         Status: [COMPLETED]
```

---

## Proposed File Structure

```
.claude/extensions/founder/
  manifest.json                      # Updated with plan/implement routing
  EXTENSION.md                       # Updated documentation
  index-entries.json

  commands/
    market.md                        # Updated: creates task, runs /plan, /implement
    analyze.md                       # Updated: same pattern
    strategy.md                      # Updated: same pattern

  skills/
    skill-market/SKILL.md            # Keep for --quick mode
    skill-analyze/SKILL.md           # Keep for --quick mode
    skill-strategy/SKILL.md          # Keep for --quick mode
    skill-founder-plan/SKILL.md      # NEW: founder-specific planning
    skill-founder-implement/SKILL.md # NEW: founder-specific implementation

  agents/
    market-agent.md                  # Keep for --quick mode
    analyze-agent.md                 # Keep for --quick mode
    strategy-agent.md                # Keep for --quick mode
    founder-plan-agent.md            # NEW: interactive forcing questions -> plan
    founder-implement-agent.md       # NEW: execute plan -> report

  context/project/founder/
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
    README.md
```

---

## Decisions

1. **Language-Based Plan Routing**: Add `plan` routing to extension manifest, modify `/plan` command to check extension routing.

2. **Forcing Questions in Planning**: The `founder-plan-agent` conducts forcing questions during the planning phase, storing gathered data in the plan file for implementation.

3. **Report Location**: Default to `strategy/{report-type}-{topic}.md`. Support `--output` in task description for custom paths.

4. **Standalone Command Mode**: Commands become task shortcuts by default, with `--quick` flag for legacy standalone mode.

5. **Skill Separation**: Keep existing `skill-market`, `skill-analyze`, `skill-strategy` for `--quick` mode. Add new `skill-founder-plan` and `skill-founder-implement` for task workflow.

6. **Phase Structure**: Founder implementation plans use domain-specific phases (TAM/SAM/SOM calculation) rather than generic implementation phases.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `/plan` command modification | High | Test extensively; fallback to skill-planner if routing fails |
| Forcing questions feel too long | Medium | Allow `--mode` pre-selection to skip mode question |
| Extension routing not discovered | Medium | Clear error message if extension not loaded |
| Report output path conflicts | Low | Check file exists, prompt user if overwriting |
| Migration breaks existing workflows | High | `--quick` flag preserves legacy behavior |

---

## Migration Path

### Phase 1: Add New Skills and Agents

1. Create `skill-founder-plan/SKILL.md`
2. Create `skill-founder-implement/SKILL.md`
3. Create `founder-plan-agent.md`
4. Create `founder-implement-agent.md`

### Phase 2: Update Manifest

1. Update `manifest.json` with new routing
2. Add new skills and agents to `provides`
3. Bump version to 2.0.0

### Phase 3: Modify Commands

1. Update `/market` to create task and invoke `/plan` + `/implement`
2. Add `--quick` flag for legacy mode
3. Repeat for `/analyze` and `/strategy`

### Phase 4: Update `/plan` Command

1. Add extension routing lookup
2. Fallback to `skill-planner` if no extension routing

### Phase 5: Documentation

1. Update EXTENSION.md
2. Update context files if needed
3. Add migration notes

---

## Context Extension Recommendations

None. This is a meta task modifying the founder extension itself.

---

## Next Steps

1. Run `/plan 234` to create detailed implementation plan
2. Implementation phases:
   - Phase 1: Create new skills (skill-founder-plan, skill-founder-implement)
   - Phase 2: Create new agents (founder-plan-agent, founder-implement-agent)
   - Phase 3: Update manifest.json
   - Phase 4: Modify /plan command for extension routing
   - Phase 5: Modify standalone commands (/market, /analyze, /strategy)
   - Phase 6: Testing and documentation

---

## Appendix: New Agent Templates

### founder-plan-agent.md (Skeleton)

```markdown
---
name: founder-plan-agent
description: Create founder analysis plans with interactive forcing questions
---

# Founder Plan Agent

## Overview

Creates implementation plans for founder tasks (market sizing, competitive analysis, GTM strategy) through interactive forcing questions.

## Execution Flow

### Stage 1: Parse Delegation Context
### Stage 2: Load Existing Context
### Stage 3: Conduct Forcing Questions
### Stage 4: Generate Plan Artifact
### Stage 5: Write Metadata and Return
```

### founder-implement-agent.md (Skeleton)

```markdown
---
name: founder-implement-agent
description: Execute founder plans and generate strategy reports
---

# Founder Implement Agent

## Overview

Executes founder implementation plans, generating detailed strategy reports in the specified output location.

## Execution Flow

### Stage 1: Parse Delegation Context
### Stage 2: Load Plan and Detect Resume Point
### Stage 3: Execute Phases
### Stage 4: Generate Report Artifact
### Stage 5: Write Summary and Metadata
### Stage 6: Return Brief Summary
```

---

## Appendix: Key Code Patterns

### Extension Routing Lookup (for /plan command)

```bash
# Get task language
language=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .language // "general"' \
  specs/state.json)

# Check extension routing for plan
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.plan[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback to default planner
skill_name=${skill_name:-"skill-planner"}
```

### Task Creation from Command

```bash
# In /market command
next_num=$(jq -r '.next_project_number' specs/state.json)
slug="market_sizing_$(echo "$ARGUMENTS" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | head -c 40)"

# Create task entry
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg lang "founder" \
   --arg desc "Market sizing: $ARGUMENTS" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {next_project_number: ($num + 1)} |
   .active_projects += [{
     project_number: $num,
     project_name: $name,
     status: "not_started",
     language: $lang,
     description: $desc,
     created: $ts
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
