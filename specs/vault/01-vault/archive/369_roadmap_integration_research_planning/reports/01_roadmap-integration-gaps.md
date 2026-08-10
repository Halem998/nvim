# Research Report: ROAD_MAP.md Integration in Research and Planning Agents

**Task**: 369 - Integrate ROAD_MAP.md consultation into research/planning agents
**Date**: 2026-04-07
**Status**: Complete

## Executive Summary

Research and planning agents operate without any awareness of `specs/ROAD_MAP.md`, leading to repeated mistakes where agents propose work that conflicts with or duplicates roadmap priorities. The `/review` and `/todo` commands handle roadmap *updates* (writing) well, but no agent *reads* the roadmap for strategic context before beginning work.

## Findings

### 1. Complete Absence of Roadmap Awareness in Research/Planning

**general-research-agent.md**: Zero references to ROAD_MAP.md. The agent's 7-stage workflow (Initialize -> Parse -> Analyze -> Search -> Gap Detection -> Report -> Return) never consults the roadmap at any point.

**planner-agent.md**: Zero references to ROAD_MAP.md. The agent's workflow (Initialize -> Parse -> Load Research -> Analyze -> Decompose -> Create Plan -> Verify -> Return) creates plans in isolation from strategic priorities.

**skill-researcher/SKILL.md**: 10-stage execution flow with no roadmap stage. Delegation context sent to the research agent contains `task_context` (number, name, description, language) and `focus_prompt` but no roadmap context.

**skill-planner/SKILL.md**: 11-stage execution flow with no roadmap stage. Delegation context includes `research_path` but no roadmap reference.

### 2. Context Index Excludes Research/Planning from Roadmap Files

In `.claude/context/index.json`, the two roadmap context files are narrowly scoped:

**formats/roadmap-format.md** (65 lines):
- `load_when.agents`: `[]` (empty -- no agents)
- `load_when.languages`: `["meta"]`
- `load_when.commands`: `["/todo"]`

**patterns/roadmap-update.md** (100 lines):
- `load_when.agents`: `[]` (empty -- no agents)
- `load_when.languages`: `[]` (empty)
- `load_when.commands`: `["/todo"]`

Neither file loads for `/research`, `/plan`, or any research/planning agent.

### 3. Downstream Components Handle Roadmap Well

**general-implementation-agent.md**: Generates `roadmap_items` array at completion (Stage 8, completion_data). This is consumed downstream by `/todo`.

**skill-todo/SKILL.md**: Stage 5 (ScanRoadmap) reads ROAD_MAP.md, matches completed tasks via explicit `roadmap_items` (Priority 1) or exact `(Task {N})` references (Priority 2). Stage 11 (UpdateRoadmap) annotates matched items with completion status.

**/review command**: Section 2.5 parses ROAD_MAP.md for phase headers, checkboxes, and status tables. Section 2.5.2 cross-references with project state. Section 2.5.3 annotates completed items. Creates tasks from incomplete roadmap items.

### 4. Information Flow Gap

Current flow:
```
ROAD_MAP.md --> /review (reads, annotates, creates tasks)
                /todo (reads, annotates completed items)

/implement --> roadmap_items --> state.json --> /todo (consumes)
```

Missing flow:
```
ROAD_MAP.md --> /research (should read for context)
                /plan (should read to align phases)
```

## Recommendations

### R1: Add Roadmap Context Stage to general-research-agent.md

Insert after Stage 1 (Parse delegation context), before Stage 2 (Analyze task scope):

- Read `specs/ROAD_MAP.md` if it exists
- Extract: current phase/priorities, items related to the task being researched
- Include in research context so findings align with strategic direction
- This is a read-only operation -- the research agent should never modify the roadmap

### R2: Add Roadmap Alignment Stage to planner-agent.md

Insert after Stage 2 (Load research report), before Stage 3 (Analyze task scope):

- Read `specs/ROAD_MAP.md` if it exists
- Identify which roadmap items the task advances
- Pre-populate suggested `roadmap_items` in plan metadata
- Ensure plan phases align with roadmap ordering/priorities
- This makes the implementation agent's `roadmap_items` generation more informed

### R3: Update context/index.json load_when Entries

Expand both roadmap context files:

**formats/roadmap-format.md**:
- Add agents: `["general-research-agent", "planner-agent"]`
- Add commands: `["/todo", "/research", "/plan"]`

**patterns/roadmap-update.md**:
- Add agents: `["planner-agent"]` (research doesn't update, only reads)
- Add commands: `["/todo", "/plan"]`

### R4: Pass Roadmap Path in Delegation Context

Update skill-researcher and skill-planner delegation contexts to include:
```json
{
  "roadmap_path": "specs/ROAD_MAP.md"
}
```

This lets agents know where to find the roadmap without hardcoding.

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Agents modify ROAD_MAP.md | Explicit read-only instruction in agent stages |
| ROAD_MAP.md doesn't exist | Guard with `if exists` check; skip gracefully |
| Extra context bloats agent prompt | Roadmap is typically compact; extract only relevant sections |
| Roadmap is stale/outdated | Agents should treat it as directional guidance, not hard constraints |

## Files to Modify

| File | Change |
|------|--------|
| `.claude/agents/general-research-agent.md` | Add roadmap consultation stage |
| `.claude/agents/planner-agent.md` | Add roadmap alignment stage |
| `.claude/skills/skill-researcher/SKILL.md` | Add `roadmap_path` to delegation context |
| `.claude/skills/skill-planner/SKILL.md` | Add `roadmap_path` to delegation context |
| `.claude/context/index.json` | Expand `load_when` for roadmap entries |
