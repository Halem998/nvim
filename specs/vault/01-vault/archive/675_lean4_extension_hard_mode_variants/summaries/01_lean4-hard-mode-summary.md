# Implementation Summary: Task #675

**Completed**: 2026-06-12
**Duration**: ~1 hour

## Overview

Added hard-mode routing to the lean4 extension by creating 2 lean-specific hard agents,
2 hard skills, 2 lean4-specific contract overrides, and updating the manifest, index, and
EXTENSION.md. The core hard-mode infrastructure from task 669 provides the behavioral contracts
(H2, H3, H4, H5, H9); this task layers lean4-specific overrides on top.

## What Changed

- `.claude/extensions/lean/context/contracts/reference-grounding.md` — Created: H3 lean4 override with 5-column lemma mapping table (Source, Prop/Location, Lean Identifier, Type Signature, Status), PDF section citation requirement, sorry-inventory cross-reference
- `.claude/extensions/lean/context/contracts/anti-analysis.md` — Created: H2 lean4 override with formal proof line bar (first sorry-free lemma within 30% of tool calls), lean-specific forbidden conclusions, sub-sorry policy enforcement
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` — Created: hard-mode research agent (model: opus) with H2+H3+H4+H5 contracts, self-contained (no base agent @-references)
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` — Created: hard-mode implementation agent (model: opus) with H2+H9 contracts, single-phase focus, sorry_inventory tracking
- `.claude/extensions/lean/skills/skill-lean-research-hard/SKILL.md` — Created: thin wrapper delegating to lean-research-hard-agent with hard-mode cost note and postflight
- `.claude/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — Created: thin wrapper with per-phase dispatch context, sorry_inventory propagation, and postflight
- `.claude/extensions/lean/manifest.json` — Modified: added `routing_hard` key, 2 agents to `provides.agents`, 2 skills to `provides.skills`, `"contracts"` to `provides.context`
- `.claude/extensions/lean/index-entries.json` — Modified: added 2 context entries for the contract files with `load_when.agents` for both hard agents
- `.claude/extensions/lean/EXTENSION.md` — Modified: added "Lean Hard Mode" subsection with routing table, skill-agent mapping, behavioral contracts list

## Decisions

- Both hard agents use `model: opus` (consistent with base lean agents' opus selection)
- Hard agents are fully self-contained (no @-references to base agents) to prevent accidental base agent override
- No lean4 planner hard agent created — core `planner-hard-agent` handles lean4 tasks
- H2 formal proof line bar set at 30% (not the core's 20%) to account for lean4 search overhead
- `routing_hard` only covers research and implement (no plan entry), matching the research plan
- Contract overrides stored at `.claude/extensions/lean/context/contracts/` (new directory, separate from core `.claude/context/contracts/`)

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (no compiled artifacts)
- Tests: N/A
- Files verified: Yes — all 6 new files exist at expected paths
- `jq '.routing_hard' manifest.json` returns research and implement entries
- `jq '.provides.agents | length' manifest.json` returns 4 (2 base + 2 hard)
- `jq '.provides.skills | length' manifest.json` returns 6 (4 base + 2 hard)
- `jq '.entries | length' index-entries.json` returns 29 (27 original + 2 new)
- No @-references to base agent files in hard agent files (self-containment verified)
- EXTENSION.md contains "Lean Hard Mode" section with routing table

## Notes

Phase 4 changes (manifest.json, index-entries.json, EXTENSION.md) were committed as part of
task 676's work, which ran in a parallel session and committed the lean extension changes this
session also made. The final state of all files is correct.
