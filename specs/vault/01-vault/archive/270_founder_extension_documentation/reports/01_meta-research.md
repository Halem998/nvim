# Task 270: Update Founder Extension Documentation for Phased Workflow

**Status**: Research Complete
**Created**: 2026-03-24
**Dependencies**: All tasks 262-269

---

## Problem Statement

After tasks 262-269 are complete, the founder extension documentation needs to reflect the new architecture where all 5 task types (market, analyze, strategy, legal, project) follow the standard `/research -> /plan -> /implement` lifecycle with proper per-type routing.

## Documentation Files to Update

### 1. /project Command (`.claude/extensions/founder/commands/project.md`)

**Current**: Documents the monolithic workflow where project-agent does everything in one shot.

**Target**: Document the new phased workflow:
```
/project "description"    -> Ask forcing questions, create task [NOT STARTED]
/research N               -> project-agent gathers WBS/PERT data, creates research report [RESEARCHED]
/plan N                   -> founder-plan-agent creates project-timeline plan [PLANNED]
/implement N              -> founder-implement-agent generates Typst timeline + PDF [COMPLETED]
```

**Sections to Update**:
- Overview: mention standard phased workflow
- Workflow Summary: replace autonomous flow with phased flow
- STAGE 2: DELEGATE: research-only routing
- CHECKPOINT 2: GATE OUT: research output only
- Output Artifacts: update locations
- Examples: full /research -> /plan -> /implement examples

**Reference**: Use market.md and strategy.md as templates for the phased workflow documentation pattern.

### 2. EXTENSION.md (`.claude/extensions/founder/EXTENSION.md`)

**Current**: Documents v2.2 features including the routing table.

**Target**: Update to v3.0 reflecting:
- All 5 types follow phased workflow
- Per-type routing for all 3 phases (research, plan, implement)
- Updated routing table showing all entries
- Updated workflow diagram showing standard lifecycle
- Removed references to project-agent's monolithic behavior

### 3. README.md (`.claude/extensions/founder/README.md`)

**Current**: v2.0 overview.

**Target**: Update to v3.0 reflecting:
- Unified workflow description for all commands
- Updated agent descriptions (project-agent is now research-only)
- Updated routing reference
- Quick start examples showing the phased pattern

### 4. manifest.json Version Bump

- Bump version from `"2.1.0"` to `"3.0.0"` (breaking change: project workflow)

## Key Documentation Themes

### Unified Workflow

All 5 commands now follow the same pattern:
```
/{command} "description"   -> Create task with forcing questions
/research N                -> Domain-specific research agent
/plan N                    -> Shared planner (content-aware)
/implement N               -> Shared implementer (type-aware)
```

The real differentiation is at the **research** phase where each command has a specialized agent:
- /market -> market-agent (SEC EDGAR, TAM/SAM/SOM)
- /analyze -> analyze-agent (Firecrawl, competitor analysis)
- /strategy -> strategy-agent (positioning, channels)
- /legal -> legal-council-agent (contract review, risk assessment)
- /project -> project-agent (WBS, PERT, resource allocation)

Planning and implementation use shared agents that detect the task type from the research report content.

### Per-Type Routing Table

Document the complete routing table:

| Phase | founder:market | founder:analyze | founder:strategy | founder:legal | founder:project |
|-------|---------------|-----------------|------------------|---------------|-----------------|
| Research | skill-market | skill-analyze | skill-strategy | skill-legal | skill-project |
| Plan | skill-founder-plan | skill-founder-plan | skill-founder-plan | skill-founder-plan | skill-founder-plan |
| Implement | skill-founder-implement | skill-founder-implement | skill-founder-implement | skill-founder-implement | skill-founder-implement |

### Breaking Changes from v2.x

1. `/project` no longer generates timelines directly - use `/research N -> /plan N -> /implement N`
2. TRACK and REPORT modes move to `/implement` phase
3. project-agent output is now a research report, not a Typst file
4. skill-project sets `researched` status, not `planned`

## Files Affected

- `.claude/extensions/founder/commands/project.md`
- `.claude/extensions/founder/EXTENSION.md`
- `.claude/extensions/founder/README.md`
- `.claude/extensions/founder/manifest.json` (version bump only)

## Effort Estimate

1 hour - documentation updates across 3-4 files with clear source material from other commands.
