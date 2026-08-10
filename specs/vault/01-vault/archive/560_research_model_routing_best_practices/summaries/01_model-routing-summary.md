# Implementation Summary: Task #560

- **Task**: 560 - Research Model Routing Best Practices
- **Status**: [COMPLETED]
- **Started**: 2026-05-13T18:00:00Z
- **Completed**: 2026-05-13T18:45:00Z
- **Effort**: 45 minutes
- **Dependencies**: None
- **Artifacts**: [plans/01_model-routing-research.md], [reports/01_model-routing-research.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Applied a tiered model routing policy across the `.claude/` agent system, replacing the uniform "all agents default to Opus" approach with a three-tier system: Opus for deep-reasoning agents (planning, formal verification, architecture), Sonnet for general-purpose agents (research, implementation, review, domain tasks), and inherit for utility agents. This addresses the 1.2-point SWE-bench gap between Sonnet 4.6 (79.6%) and Opus 4.6 (80.8%) finding that Sonnet is suitable for most pattern-execution work.

## What Changed

- Updated 8 core agents from `model: opus` to `model: sonnet` (general-research, general-implementation, code-reviewer, spawn, neovim-research, neovim-implementation, nix-research, nix-implementation)
- Kept 3 core agents at `model: opus` (planner, meta-builder, reviser)
- Updated 20 extension agents from `model: opus` to `model: sonnet` across core mirrors, epidemiology, founder, latex, nix, nvim, and present extensions
- Kept 10 extension agents at `model: opus` (formal/4, lean/2, legal-analysis/1, core mirrors of planner/meta-builder/reviser/3)
- Changed 4 dispatch commands from `model: opus` to `model: sonnet` (research, plan, implement, project-overview)
- Kept 11 direct-execution commands at `model: opus`
- Added `model: sonnet` to neovim-implementation-agent (both core and extension copies had no model field)
- Updated documentation standards: agent-frontmatter-standard.md, agent-template.md, creating-commands.md, core/agents/README.md, creating-extensions.md (both main and core extension copies)
- Updated CLAUDE.md skill-to-agent mapping table and Model Enforcement paragraph
- Updated core merge-sources/claudemd.md

## Decisions

- Formal/lean/math/logic/physics agents retain Opus per user's explicit priority for formal reasoning tasks
- Legal-analysis-agent retains Opus due to complex document reasoning requirements
- Dispatch commands (research, plan, implement) changed to Sonnet since agent model takes precedence during execution
- Direct-execution commands kept at Opus since they do the reasoning work themselves
- Extension agents without model fields (filetypes, some founder agents, python, typst, web, z3) left as inherit-tier for now

## Impacts

- Projected 32-40% cost reduction per session from reduced Opus usage
- `CLAUDE_CODE_SUBAGENT_MODEL` env var now works as intended for agents without explicit model fields
- `--opus` flag provides per-invocation override for any task requiring deeper reasoning
- Documentation now accurately reflects the tiered policy

## Follow-ups

- Monitor quality on Sonnet-tier agents; use `--opus` flag if regression observed
- Consider adding model fields to remaining inherit-tier extension agents as their usage patterns become clear

## References

- `specs/560_research_model_routing_best_practices/reports/01_model-routing-research.md`
- `specs/560_research_model_routing_best_practices/plans/01_model-routing-research.md`
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`
