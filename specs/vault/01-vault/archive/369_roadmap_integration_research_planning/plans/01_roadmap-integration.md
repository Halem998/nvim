# Implementation Plan: Task #369

- **Task**: 369 - Integrate ROAD_MAP.md consultation into research and planning agents
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/369_roadmap_integration_research_planning/reports/01_roadmap-integration-gaps.md
- **Artifacts**: plans/01_roadmap-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add ROAD_MAP.md awareness to the research and planning agents so they consult project priorities before generating reports and plans. This involves adding a new stage to each agent, passing the roadmap path through delegation contexts in the wrapper skills, and expanding the context index so roadmap format documentation is available to these agents.

### Research Integration

Research report identified that `general-research-agent.md` and `planner-agent.md` have zero references to ROAD_MAP.md, and that `context/index.json` scopes the two roadmap context files exclusively to `/todo`. The downstream pipeline (`/implement` -> `roadmap_items` -> `/todo` -> annotate) works well; only the upstream read path is missing.

## Goals & Non-Goals

**Goals**:
- Research agent reads ROAD_MAP.md for strategic context before beginning research
- Planner agent reads ROAD_MAP.md to align plan phases with roadmap priorities
- Context index makes roadmap docs available to research/planning agents
- Delegation contexts include roadmap path so agents don't hardcode it

**Non-Goals**:
- Agents do not write/modify ROAD_MAP.md (that stays with /todo and /review)
- No changes to /todo, /review, or /implement workflows
- No new context files -- only modifications to existing ones

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ROAD_MAP.md doesn't exist in some projects | L | M | Guard with existence check, skip gracefully |
| Extra context bloats agent prompts | L | L | Agents extract only relevant sections, roadmap is compact |
| Agents accidentally modify ROAD_MAP.md | M | L | Explicit read-only instruction in stage text |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update context/index.json and delegation contexts [NOT STARTED]

**Goal**: Make roadmap context files discoverable by research/planning agents and pass roadmap path in delegation contexts.

**Tasks**:
- [ ] Edit `context/index.json`: expand `formats/roadmap-format.md` `load_when` to add agents `["general-research-agent", "planner-agent"]` and commands `["/todo", "/research", "/plan"]`
- [ ] Edit `context/index.json`: expand `patterns/roadmap-update.md` `load_when` to add agents `["planner-agent"]` and commands `["/todo", "/plan"]`
- [ ] Edit `skill-researcher/SKILL.md` Stage 4 delegation context: add `"roadmap_path": "specs/ROAD_MAP.md"` field to the JSON block
- [ ] Edit `skill-planner/SKILL.md` Stage 4 delegation context: add `"roadmap_path": "specs/ROAD_MAP.md"` field to the JSON block

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` - Expand `load_when` for two roadmap entries
- `.claude/skills/skill-researcher/SKILL.md` - Add roadmap_path to delegation context (Stage 4)
- `.claude/skills/skill-planner/SKILL.md` - Add roadmap_path to delegation context (Stage 4)

**Verification**:
- jq query for `general-research-agent` returns `formats/roadmap-format.md`
- jq query for `planner-agent` returns both roadmap context files
- Delegation context JSON blocks include `roadmap_path` field

---

### Phase 2: Add roadmap consultation stage to general-research-agent.md [NOT STARTED]

**Goal**: Research agent reads ROAD_MAP.md for strategic context before executing searches.

**Tasks**:
- [ ] Add new "Stage 1.5: Load Roadmap Context" between Stage 1 (Parse Delegation Context) and Stage 2 (Analyze Task)
- [ ] Stage reads `roadmap_path` from delegation context, checks file exists, extracts current phase priorities and items relevant to the task
- [ ] Add explicit read-only instruction: agent must never modify ROAD_MAP.md
- [ ] Update Stage 2 (Analyze Task) to reference roadmap context when determining search strategy
- [ ] Add `@.claude/context/formats/roadmap-format.md` to Context References section

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Add Stage 1.5, update Stage 2 and Context References

**Verification**:
- Agent file contains Stage 1.5 with roadmap reading logic
- Context References includes roadmap-format.md
- Read-only guard is explicitly stated

---

### Phase 3: Add roadmap alignment stage to planner-agent.md [NOT STARTED]

**Goal**: Planner agent reads ROAD_MAP.md to align plan phases with roadmap priorities and suggest roadmap_items.

**Tasks**:
- [ ] Add new "Stage 2.5: Load Roadmap Context" between Stage 2 (Load Research) and Stage 3 (Analyze Task Scope)
- [ ] Stage reads `roadmap_path` from delegation context, checks file exists, identifies which roadmap items the task advances
- [ ] Add explicit read-only instruction: agent must never modify ROAD_MAP.md
- [ ] Update Stage 4 (Decompose into Phases) to consider roadmap ordering when sequencing phases
- [ ] Update Stage 5 plan template to include a "Roadmap Alignment" subsection in Overview noting which roadmap items this plan advances
- [ ] Add `@.claude/context/formats/roadmap-format.md` to Context References section

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/planner-agent.md` - Add Stage 2.5, update Stages 4-5 and Context References

**Verification**:
- Agent file contains Stage 2.5 with roadmap reading logic
- Plan template includes Roadmap Alignment subsection
- Context References includes roadmap-format.md
- Read-only guard is explicitly stated

## Testing & Validation

- [ ] jq query `index.json` for `general-research-agent` returns roadmap format file
- [ ] jq query `index.json` for `planner-agent` returns both roadmap files
- [ ] `general-research-agent.md` contains Stage 1.5 with existence guard
- [ ] `planner-agent.md` contains Stage 2.5 with existence guard
- [ ] Both agent files have read-only ROAD_MAP.md instruction
- [ ] Delegation contexts in both skills include `roadmap_path`
- [ ] No agent file contains instructions to write/modify ROAD_MAP.md

## Artifacts & Outputs

- Modified: `.claude/context/index.json`
- Modified: `.claude/agents/general-research-agent.md`
- Modified: `.claude/agents/planner-agent.md`
- Modified: `.claude/skills/skill-researcher/SKILL.md`
- Modified: `.claude/skills/skill-planner/SKILL.md`

## Rollback/Contingency

All changes are to markdown instruction files with no runtime dependencies. Revert via `git checkout` on the 5 modified files.
