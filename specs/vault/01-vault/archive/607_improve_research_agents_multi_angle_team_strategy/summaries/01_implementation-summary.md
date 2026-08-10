# Implementation Summary: Task #607

**Completed**: 2026-05-22
**Mode**: Team Implementation (sequential wave execution within fork)
**Session**: sess_1748000000_607abc

## Wave Execution

### Wave 1 (Phases 1, 2 -- parallel)
- Phase 1: Fix Structural Bugs in SKILL.md [COMPLETED]
- Phase 2: Add --exploit and --explore Flags to Parser [COMPLETED] (pre-existing)

### Wave 2 (Phase 3)
- Phase 3: Wave 2 Critic and Domain Context Injection [COMPLETED]

### Wave 3 (Phases 4, 5 -- parallel)
- Phase 4: Exploit/Explore Mode Integration in SKILL.md [COMPLETED]
- Phase 5: Agent Prompt Enhancements [COMPLETED]

### Wave 4 (Phase 6)
- Phase 6: Integration Testing and Documentation [COMPLETED]

## Changes Made

### Dynamic Team Sizing (Phase 1)
Removed hardcoded `team_size=4` that overrode user input. Replaced with effort-flag-based sizing: `--fast` = 2, default = 3, `--hard` = 4. Added `--team-size N` override support. Added conditional spawning rules: Teammate B at size >= 3, Teammate D at size >= 4, Critic always present.

### Parser Flags (Phase 2)
`--exploit` and `--explore` flags already implemented in `parse-command-args.sh`. Verified: initialized, matched, stripped, exported.

### Wave 2 Critic (Phase 3)
Moved Critic from Wave 1 (parallel with other teammates) to Wave 2 (after Wave 1 completion). Critic now reads all Wave 1 findings before critiquing, enabling informed, targeted critique instead of generic skepticism. Added Stage 6a to SKILL.md for Wave 2 spawn logic.

### Domain Context Injection (Phase 3)
Added domain context injection to Stage 5b: queries `index.json` for context paths matching `task_type` and injects domain-specific references into all teammate prompts. Ensures team research teammates get same domain knowledge as single-agent research.

### Exploit/Explore Modes (Phase 4)
Added mode detection from `EXPLOIT_FLAG`/`EXPLORE_FLAG` in Stage 5b. Each teammate prompt now includes mode-specific instructions that shape their research direction. Synthesis report includes mode designation. Updated team-orchestration.md with mode documentation table.

### Agent Prompt Enhancements (Phase 5)
Added "Prototype-First Research Pattern" to general-research-agent.md: favor validation over speculation, describe minimal prototypes, verify when feasible, report pass/fail. Added "Tactic Discovery Survey Protocol" to lean-research-agent.md: survey LeanHammer pipeline tactics, test with `lean_multi_attempt`, check premises, consider APOLLO decomposition pattern.

### Documentation Updates (Phase 6)
Updated default team_size references from 2 to 3 across: CLAUDE.md, merge-sources/claudemd.md, skill-agent-mapping.md (core and extension copies). Added "Future Work (Tier 3)" section to team-orchestration.md listing deferred items.

## Files Modified

- `.claude/skills/skill-team-research/SKILL.md` - Dynamic sizing, Wave 2 Critic, domain injection, exploit/explore modes
- `.claude/scripts/parse-command-args.sh` - (verified pre-existing exploit/explore flags)
- `.claude/context/patterns/team-orchestration.md` - Two-wave model, domain injection, exploit/explore docs, future work
- `.claude/agents/general-research-agent.md` - Prototype-first research pattern
- `.claude/extensions/lean/agents/lean-research-agent.md` - Tactic discovery survey protocol
- `.claude/CLAUDE.md` - Updated default team_size
- `.claude/extensions/core/merge-sources/claudemd.md` - Updated default team_size
- `.claude/context/reference/skill-agent-mapping.md` - Updated default team_size
- `.claude/extensions/core/context/reference/skill-agent-mapping.md` - Updated default team_size

## Verification

- No hardcoded `team_size=4` override remains
- Dynamic sizing maps effort flags correctly
- Wave 2 Critic spawns after Wave 1 completion with finding paths
- Domain context injection queries index.json for task_type matches
- Exploit/explore modes shape teammate prompts when flags present
- Prototype-first and tactic discovery sections are advisory (non-blocking)
- All stale default team_size=2 references updated to 3
