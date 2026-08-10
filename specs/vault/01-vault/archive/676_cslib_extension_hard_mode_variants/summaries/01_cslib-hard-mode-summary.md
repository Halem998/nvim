# Implementation Summary: Task #676

**Completed**: 2026-06-12
**Duration**: ~1 hour

## Overview

Added hard-mode routing to the cslib extension, making it the first extension with a
`routing_hard` manifest block. Created 2 hard-mode agent files and 2 hard-mode skill
directories, then updated the manifest, EXTENSION.md, and index-entries.json to register them.

## What Changed

- `.claude/extensions/cslib/manifest.json` - Added `routing_hard` block (cslib and pr task types for research/plan/implement), expanded `provides.agents` (4 agents) and `provides.skills` (5 skills)
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` - Created new hard research agent with H2+H3+H4 contracts and CSLib-specific BibKey verification protocol
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` - Created new hard implementation agent with H2+H7+H9 contracts, sorry_inventory in handoff JSON, and full CSLib CI pipeline
- `.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - Created hard research skill wrapper that dispatches to cslib-research-hard-agent with effort_flag: "hard"
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - Created hard implementation skill wrapper with per-phase dispatch (H1), territory params, and phase_number support
- `.claude/extensions/cslib/EXTENSION.md` - Added hard-mode rows to Skill-Agent Mapping table and "When to Use --hard for CSLib Tasks" guidance section
- `.claude/extensions/cslib/index-entries.json` - Added 2 new entries (citation-conventions.md for cslib-research-hard-agent, ci-pipeline.md for cslib-implementation-hard-agent)

## Decisions

- H3 enrichment is cslib-specific: BibKey verification against `references.bib` (not just generic citation grounding from the core contract)
- H9 sorry_inventory is added to the cslib implementation hard agent's orchestrator handoff JSON because tracking sorry debt is critical for CSLib's zero-debt policy
- The `pr` task type routes to core hard skills (`skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`) -- no cslib-specific hard variant needed for PR preparation tasks
- cslib-research-hard-agent uses model: opus (same as base cslib-research-agent) because CSLib research is deep-reasoning work
- cslib-implementation-hard-agent uses model: sonnet (same as base) because it is a worker agent with its own fresh context

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (meta task, no Lean code)
- Tests: N/A
- Files verified: Yes
- `jq empty manifest.json`: Success
- `jq empty index-entries.json`: Success
- `jq '.routing_hard.research.cslib'`: "skill-cslib-research-hard"
- `jq '.routing_hard.implement.cslib'`: "skill-cslib-implementation-hard"
- `jq '.routing_hard.plan.cslib'`: "skill-planner-hard"
- `jq '.provides.agents | length'`: 4
- `jq '.provides.skills | length'`: 5
- `jq '.entries | length' index-entries.json`: 13 (11 + 2 new)
- All 4 new files exist in expected locations

## Notes

The cslib extension is now the first extension in the system with a `routing_hard` manifest block.
This establishes the pattern for other extensions (lean4, etc.) to add hard-mode routing in the future.
The `pr` task type reuses core hard skills rather than extension-specific ones, matching the
research report finding that there is no domain gap for PR preparation tasks.
