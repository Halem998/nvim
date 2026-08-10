# Research Report: Team Research Mandatory Roles (Critic + Horizons)

**Task**: 369 - Integrate ROAD_MAP.md consultation into research/planning agents
**Date**: 2026-04-07
**Focus**: Adding mandatory Critic and Horizons teammates to `--team` research mode

## Executive Summary

The current `skill-team-research` defines 4 teammate roles (A: Primary, B: Alternatives, C: Risk Analysis, D: Devil's Advocate) but none systematically checks for gaps in the research or consults the ROADMAP.md for long-term alignment. Two new mandatory teammate roles should be added: a **Critic** who identifies gaps and shortcomings, and a **Horizons** agent who reads ROAD_MAP.md to assess long-term aims and think outside the box about approach improvements.

## Current Team Research Architecture

### Teammate Roles (skill-team-research Stage 5)

| Letter | Role | Focus | Required |
|--------|------|-------|----------|
| A | Primary Angle | Implementation approaches and patterns | Always (team_size >= 2) |
| B | Alternative Approaches | Prior art, existing solutions to adapt | Always (team_size >= 2) |
| C | Risk Analysis | Risks, blockers, edge cases | Only if team_size >= 3 |
| D | Devil's Advocate | Challenge findings, find inconsistencies | Only if team_size >= 4 |

### Current team_size Behavior

- Default: 2 (teammates A + B)
- Range: [2, 4] (clamped)
- Cost: ~5x tokens per teammate

### Key Observation

Teammates C (Risk Analysis) and D (Devil's Advocate) overlap with the proposed Critic role. The current D "Devil's Advocate" is closest but: (1) it only activates at team_size=4, (2) it waits for other teammates to finish first (Wave 2 pattern), and (3) it doesn't read any specific artifacts like ROAD_MAP.md.

No current teammate reads ROAD_MAP.md or considers long-term project trajectory.

## Proposed Role Design

### Critic Teammate (Mandatory)

**Purpose**: Identify gaps, shortcomings, and blind spots in the research.

**Behavior**:
- Runs in parallel with other teammates (Wave 1, no dependency)
- Independently researches the task looking specifically for what could be missed
- Checks if existing patterns/solutions have known limitations
- Identifies assumptions that haven't been validated
- Reviews whether the task scope is complete

**Differentiation from existing roles**:
- C (Risk Analysis) focuses on *implementation risks* -- things that could go wrong during execution
- Critic focuses on *research quality* -- what the research itself might be missing or getting wrong
- D (Devil's Advocate) is reactive (reads other findings); Critic is proactive (independent investigation)

### Horizons Teammate (Mandatory)

**Purpose**: Consult ROAD_MAP.md to assess long-term alignment and suggest improvements.

**Behavior**:
- Runs in parallel with other teammates (Wave 1)
- Reads `specs/ROAD_MAP.md` to understand project direction and priorities
- Evaluates whether the proposed task approach aligns with long-term goals
- Identifies opportunities to solve adjacent roadmap items simultaneously
- Thinks outside the box about alternative approaches that better serve the project trajectory
- Checks if the task could be scoped differently to advance more roadmap items

**Key context**: Receives `roadmap_path` in delegation context (from Phase 1 of the existing plan).

## Integration Options

### Option A: Replace C and D with Critic and Horizons

Replace the conditional teammates:
- A: Primary Angle (unchanged)
- B: Alternative Approaches (unchanged)
- C: **Critic** (replaces Risk Analysis, always present)
- D: **Horizons** (replaces Devil's Advocate, always present)

Minimum team_size becomes 4 (always). This is expensive (~20x tokens vs single agent).

### Option B: Make Critic and Horizons always-present, keep others optional (Recommended)

Restructure the team so the first 4 slots are fixed:
- A: Primary Angle (always)
- B: Alternative Approaches (always)
- C: Critic (always -- new mandatory role)
- D: Horizons (always -- new mandatory role)

Adjust team_size:
- Minimum: 4 (was 2)
- Default: 4 (was 2)
- Maximum: 4 (was 4)

This means `--team` always spawns exactly 4 teammates with fixed roles. The `--team-size` flag becomes unnecessary for research (could be kept for plan/implement).

### Option C: Add Critic and Horizons as always-present, reduce to 3 mandatory

Merge Primary + Alternatives into a single "Explorer" role:
- A: Explorer (combined primary + alternatives)
- B: Critic (always)
- C: Horizons (always)

Minimum/default: 3. This saves cost vs Option B.

### Recommendation: Option B

Option B is cleanest:
- 4 fixed roles, no ambiguity about team composition
- Critic and Horizons always present as user requested
- Primary and Alternatives remain separate for focused investigation
- `--team-size` flag becomes a no-op for research (always 4)
- Cost increase is acceptable since `--team` is already an explicit opt-in

## Files to Modify

| File | Change |
|------|--------|
| `.claude/skills/skill-team-research/SKILL.md` | Replace teammate C/D prompts with Critic/Horizons, set min/default team_size to 4, add roadmap_path to delegation context |
| `.claude/context/patterns/team-orchestration.md` | Update wave diagram to show 4 fixed research roles |

## Impact on Existing Plan

The existing plan (01_roadmap-integration.md) needs a **new Phase 4** to handle team research modifications. The 3 existing phases remain valid:
- Phase 1: context/index.json + delegation contexts (add roadmap_path)
- Phase 2: general-research-agent roadmap stage
- Phase 3: planner-agent roadmap stage
- **Phase 4 (new)**: Restructure team research teammate roles

Phase 4 depends on Phase 1 (needs roadmap_path in delegation context).

## Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| 4 mandatory teammates increases cost | M | `--team` is already opt-in; user accepts cost by using it |
| Horizons teammate fails if no ROAD_MAP.md | L | Guard with existence check; contribute general strategic thinking instead |
| Critic may duplicate Risk Analysis findings | L | Clear prompt differentiation: research quality vs implementation risks |
| Fixed team_size removes flexibility | L | Can add `--team-size` back later if needed for other use cases |
