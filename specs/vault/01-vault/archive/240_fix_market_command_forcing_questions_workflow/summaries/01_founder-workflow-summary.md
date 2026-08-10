# Implementation Summary: Task #240

**Completed**: 2026-03-18
**Duration**: ~45 minutes

## Overview

Restructured the founder extension commands (/market, /analyze, /strategy) to ask forcing questions BEFORE task creation. Added `task_type` field to enable type-based routing for finer-grained control over /research behavior on founder tasks.

## Changes Made

### Phase 1: Schema Update
- Added `task_type` field documentation to `.claude/rules/state-management.md`
- Defined valid values: `market`, `analyze`, `strategy`, or `null` (backward compatible)
- Documented routing behavior and format conversion

### Phase 2: Manifest Routing
- Updated `.claude/extensions/founder/manifest.json` routing section
- Added composite key routing: `founder:market`, `founder:analyze`, `founder:strategy`
- Preserved default `founder` key for backward compatibility

### Phase 3: /market Command
- Added STAGE 0: PRE-TASK FORCING QUESTIONS section
- Mode selection before task creation
- 4 essential forcing questions (problem, target, geography, price point)
- Task creation now includes `task_type: "market"` and `forcing_data`
- Updated skill-market to accept and pass forcing_data to agent

### Phase 4: /analyze Command
- Added STAGE 0 with analyze-specific questions
- Mode selection (LANDSCAPE, DEEP, POSITION, BATTLE)
- 4 essential forcing questions (product, competitors, advantage, decision factors)
- Task creation now includes `task_type: "analyze"` and `forcing_data`
- Updated skill-analyze to accept and pass forcing_data to agent

### Phase 5: /strategy Command
- Added STAGE 0 with strategy-specific questions
- Mode selection (LAUNCH, SCALE, PIVOT, EXPAND)
- 5 essential forcing questions (target, value prop, differentiator, channel, launch context)
- Task creation now includes `task_type: "strategy"` and `forcing_data`
- Updated skill-strategy to accept and pass forcing_data to agent

### Phase 6: /research Command
- Added task_type extraction during task lookup
- Implemented composite key routing (`{language}:{task_type}`)
- Documented type-based routing for founder extension
- Backward compatible: falls back to language-only routing when task_type is null

### Phase 7: Documentation
- Updated EXTENSION.md to v2.1 documentation
- Documented pre-task forcing questions workflow
- Added task_type field documentation
- Included migration guide from v2.0

## Files Modified

| File | Changes |
|------|---------|
| `.claude/rules/state-management.md` | Added task_type field schema and documentation |
| `.claude/extensions/founder/manifest.json` | Added composite key routing entries |
| `.claude/extensions/founder/commands/market.md` | Added STAGE 0, task_type, forcing_data |
| `.claude/extensions/founder/skills/skill-market/SKILL.md` | Accept and pass forcing_data |
| `.claude/extensions/founder/commands/analyze.md` | Added STAGE 0, task_type, forcing_data |
| `.claude/extensions/founder/skills/skill-analyze/SKILL.md` | Accept and pass forcing_data |
| `.claude/extensions/founder/commands/strategy.md` | Added STAGE 0, task_type, forcing_data |
| `.claude/extensions/founder/skills/skill-strategy/SKILL.md` | Accept and pass forcing_data |
| `.claude/commands/research.md` | Added task_type routing logic |
| `.claude/extensions/founder/EXTENSION.md` | Updated to v2.1 documentation |

## Verification

- All modified JSON files validated (manifest.json)
- Each phase completed with git commit
- Documentation updated with migration guides
- Backward compatibility preserved via:
  - `--quick` flag for legacy standalone mode
  - `null` task_type falls back to default routing
  - Existing tasks without task_type continue to work

## New Workflow

```
/market "description"   -> STAGE 0: Ask forcing questions
                        -> CHECKPOINT 1: Create task with forcing_data
                        -> Display summary, STOP at [NOT STARTED]

/research {N}           -> Route by task_type (founder:market)
                        -> skill-market passes forcing_data to agent
                        -> Agent uses pre-gathered data
                        -> STOP at [RESEARCHED]

/plan {N}               -> Read research, create plan
/implement {N}          -> Execute plan, generate output
```

## Notes

- Pre-task forcing questions gather essential data upfront
- Research agents can use forcing_data and only ask follow-up questions
- task_type enables finer-grained routing within the founder extension
- The pattern could be extended to other extensions with multiple research paths
