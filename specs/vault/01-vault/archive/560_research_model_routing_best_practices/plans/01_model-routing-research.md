# Implementation Plan: Model Routing Optimization

- **Task**: 560 - Research Model Routing Best Practices
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/560_research_model_routing_best_practices/reports/01_model-routing-research.md
- **Artifacts**: plans/01_model-routing-research.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply the tiered model assignment strategy from the research report to the `.claude/` agent system. Currently 10/11 core agents, 31 extension agents, and 15 commands hardcode `model: opus`, blocking cost optimization and preventing `CLAUDE_CODE_SUBAGENT_MODEL` from working as intended. This plan updates agent frontmatter, command frontmatter, documentation standards, and CLAUDE.md tables to reflect a three-tier model policy: Opus for deep reasoning agents, Sonnet for general-purpose agents, and inherit for utility agents. Definition of done: all files updated per the research matrix, documentation aligned, and CLAUDE.md regenerated.

### Research Integration

Key findings from `reports/01_model-routing-research.md`:
- Sonnet 4.6 scores 79.6% vs Opus 4.6's 80.8% on SWE-bench (1.2-point gap), making it suitable for most pattern-execution tasks
- Anthropic explicitly recommends Haiku 4.5 for "sub-agent tasks" in their model selection matrix
- Current hardcoded `model: opus` blocks `CLAUDE_CODE_SUBAGENT_MODEL` env var from working on those agents
- Hybrid approach recommended: explicit `model: opus` on deep-reasoning agents, explicit `model: sonnet` on general agents, field omitted on utility agents
- Projected cost savings: 32-40% per session

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Update all core agent frontmatter to tiered model assignments per research matrix
- Update all extension agent frontmatter to match the same tiered policy
- Update command frontmatter for dispatch commands (research, plan, implement) to inherit
- Update documentation (agent-frontmatter-standard.md, agent-template.md, creating-commands.md, core/agents/README.md) to reflect tiered policy
- Update CLAUDE.md merge-sources and regenerate CLAUDE.md with accurate model columns
- Preserve `--opus`/`--sonnet`/`--haiku` override flags as escape hatches

**Non-Goals**:
- Changing the skill dispatch logic or routing tables (model is set at the agent/command level only)
- Implementing `opusplan` mode (documented as alternative, not implemented)
- Adding Haiku tier assignments (research suggests Sonnet as the practical lower tier for now)
- Modifying team mode skills (they already default to Sonnet)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Quality regression on complex research tasks with Sonnet | Medium | Medium | `--opus` flag provides per-invocation override; document when to use it |
| Core and extension agents drift out of sync after update | Low | Medium | Update both in a single phase; add note in standards doc about keeping them aligned |
| Breaking CLAUDE_CODE_SUBAGENT_MODEL for agents that should stay Opus | High | Low | Only remove explicit model from agents that should inherit; deep-reasoning agents keep `model: opus` |
| Extension agents README contradicts new policy | Low | High | Resolve contradiction as part of documentation phase |
| CLAUDE.md regeneration fails or produces stale tables | Medium | Low | Manual verification of generated output against merge-sources |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update Standards and Documentation [COMPLETED]

**Goal**: Establish the tiered model policy in documentation before applying it to files, so the standard is in place for reference during subsequent phases.

**Tasks**:
- [x] Update `.claude/docs/reference/standards/agent-frontmatter-standard.md`: replace "All agents default to Opus" with tiered policy (Opus for deep reasoning, Sonnet for general, inherit for utility) *(completed)*
- [x] Update `.claude/docs/templates/agent-template.md`: change default `model: opus` to `model: sonnet` with comments explaining when to use opus vs sonnet vs inherit *(completed)*
- [x] Update `.claude/docs/guides/creating-commands.md`: add model selection guidance for new commands *(completed)*
- [x] Update `.claude/extensions/core/agents/README.md`: resolve contradiction, document tiered approach consistently *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Replace uniform Opus policy with tier definitions
- `.claude/docs/templates/agent-template.md` - Change template default from opus to sonnet
- `.claude/docs/guides/creating-commands.md` - Add model selection section
- `.claude/extensions/core/agents/README.md` - Align README with tiered policy

**Verification**:
- grep for "All agents default to Opus" returns zero matches
- agent-template.md shows `model: sonnet` as default
- README.md no longer contains contradictory guidance

---

### Phase 2: Update Core Agent and Command Frontmatter [COMPLETED]

**Goal**: Apply tiered model assignments to all 11 core agents and 15 commands.

**Tasks**:
- [x] Change `model: opus` to `model: sonnet` in 7 core agents: general-research-agent, general-implementation-agent, code-reviewer-agent, spawn-agent, neovim-research-agent, nix-research-agent, nix-implementation-agent *(completed)*
- [x] Add `model: sonnet` to neovim-implementation-agent (currently has no model field) *(completed)*
- [x] Verify 3 core agents retain `model: opus`: planner-agent, meta-builder-agent, reviser-agent *(completed: verified)*
- [x] Change `model: opus` to `model: sonnet` in 3 dispatch commands: research.md, plan.md, implement.md (these route to agents whose model takes precedence) *(completed)*
- [x] Change `model: opus` to `model: sonnet` in project-overview.md (lower complexity) *(completed)*
- [x] Verify remaining 11 commands retain `model: opus`: errors, fix-it, merge, meta, refresh, review, revise, spawn, tag, task, todo *(completed: all 11 verified)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-research-agent.md` - opus to sonnet
- `.claude/agents/general-implementation-agent.md` - opus to sonnet
- `.claude/agents/code-reviewer-agent.md` - opus to sonnet
- `.claude/agents/spawn-agent.md` - opus to sonnet
- `.claude/agents/neovim-research-agent.md` - opus to sonnet
- `.claude/agents/nix-research-agent.md` - opus to sonnet
- `.claude/agents/nix-implementation-agent.md` - opus to sonnet
- `.claude/agents/neovim-implementation-agent.md` - add `model: sonnet`
- `.claude/commands/research.md` - opus to sonnet
- `.claude/commands/plan.md` - opus to sonnet
- `.claude/commands/implement.md` - opus to sonnet
- `.claude/commands/project-overview.md` - opus to sonnet

**Verification**:
- `grep "^model: opus" .claude/agents/*.md` returns only planner-agent, meta-builder-agent, reviser-agent
- `grep "^model: sonnet" .claude/agents/*.md` returns the 8 changed agents
- `grep "^model: opus" .claude/commands/*.md` returns 11 commands (not research/plan/implement/project-overview)

---

### Phase 3: Update Extension Agent Frontmatter [COMPLETED]

**Goal**: Apply tiered model assignments to all extension agents, maintaining consistency with core agents.

**Tasks**:
- [x] Change `model: opus` to `model: sonnet` in 7 core extension mirrors: core/agents/{general-research-agent, general-implementation-agent, code-reviewer-agent, spawn-agent}.md; keep opus on {planner-agent, meta-builder-agent, reviser-agent}.md *(completed: 4 changed, 3 kept)*
- [x] Change `model: opus` to `model: sonnet` in epidemiology extension: epi-research-agent, epi-implement-agent *(completed)*
- [x] Verify formal extension agents retain `model: opus`: formal-research-agent, logic-research-agent, math-research-agent, physics-research-agent *(completed: all 4 verified)*
- [x] Verify lean extension agents retain `model: opus`: lean-research-agent, lean-implementation-agent *(completed: both verified)*
- [x] Verify founder/legal-analysis-agent retains `model: opus` *(completed: verified)*
- [x] Change `model: opus` to `model: sonnet` in founder/deck-planner-agent *(completed)*
- [x] Change `model: opus` to `model: sonnet` in latex/latex-research-agent *(completed)*
- [x] Change `model: opus` to `model: sonnet` in nix extension: nix-research-agent, nix-implementation-agent *(completed)*
- [x] Change `model: opus` to `model: sonnet` in nvim/neovim-research-agent *(completed)*
- [x] Change `model: opus` to `model: sonnet` in all 9 present extension agents: budget-agent, funds-agent, grant-agent, pptx-assembly-agent, slide-critic-agent, slide-planner-agent, slides-research-agent, slidev-assembly-agent, timeline-agent *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/agents/general-research-agent.md` - opus to sonnet
- `.claude/extensions/core/agents/general-implementation-agent.md` - opus to sonnet
- `.claude/extensions/core/agents/code-reviewer-agent.md` - opus to sonnet
- `.claude/extensions/core/agents/spawn-agent.md` - opus to sonnet
- `.claude/extensions/epidemiology/agents/epi-research-agent.md` - opus to sonnet
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md` - opus to sonnet
- `.claude/extensions/founder/agents/deck-planner-agent.md` - opus to sonnet
- `.claude/extensions/latex/agents/latex-research-agent.md` - opus to sonnet
- `.claude/extensions/nix/agents/nix-research-agent.md` - opus to sonnet
- `.claude/extensions/nix/agents/nix-implementation-agent.md` - opus to sonnet
- `.claude/extensions/nvim/agents/neovim-research-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/budget-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/funds-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/grant-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/pptx-assembly-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/slide-critic-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/slide-planner-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/slides-research-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/slidev-assembly-agent.md` - opus to sonnet
- `.claude/extensions/present/agents/timeline-agent.md` - opus to sonnet

**Verification**:
- `grep -rl "^model: opus" .claude/extensions/*/agents/*.md` returns only formal, lean, legal, planner, meta-builder, reviser agents (7 files that should keep opus)
- No extension agents have inconsistent model assignments relative to their core agent counterparts

---

### Phase 4: Update CLAUDE.md Tables and Merge Sources [COMPLETED]

**Goal**: Update the CLAUDE.md merge-sources to reflect the new model assignments in skill-to-agent mapping tables, then regenerate CLAUDE.md.

**Tasks**:
- [x] Update `.claude/extensions/core/merge-sources/claudemd.md`: change the Skill-to-Agent Mapping table to show correct model per agent (sonnet for general-research, sonnet for general-implementation, opus for planner, etc.) *(completed)*
- [x] Update the Model Enforcement paragraph to replace "All agents default to Opus" with tiered policy description *(completed)*
- [x] Update extension merge-sources if they contain model references in their skill-agent mapping sections *(completed: only core had references; nvim extension table updated in CLAUDE.md directly)*
- [x] Regenerate `.claude/CLAUDE.md` by running the CLAUDE.md generation process (or manually update if auto-generation is not scripted) *(completed: manually updated)*
- [x] Verify the generated CLAUDE.md tables match the new assignments *(completed: verified)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Update model column in tables
- `.claude/CLAUDE.md` - Regenerated output with updated tables

**Verification**:
- CLAUDE.md Skill-to-Agent Mapping table shows correct model for each agent
- Model Enforcement section describes tiered policy
- No references to "All agents default to Opus" remain in CLAUDE.md

---

### Phase 5: Validation and Consistency Check [COMPLETED]

**Goal**: Verify all changes are internally consistent and no files were missed.

**Tasks**:
- [x] Run comprehensive grep to confirm `model: opus` only appears in expected files (planner-agent, meta-builder-agent, reviser-agent, formal/*, lean/*, legal-analysis-agent, and 11 direct-execution commands) *(completed: 13 agent files verified, all expected)*
- [x] Run comprehensive grep to confirm `model: sonnet` appears in all expected files *(completed: 29 agent files verified)*
- [x] Verify no agent files lack a model field that should have one (check neovim-implementation-agent got its new field) *(completed: both core and extension copies updated)*
- [x] Cross-reference CLAUDE.md tables against actual agent frontmatter for accuracy *(completed: tables match)*
- [x] Verify `--opus`/`--sonnet`/`--haiku` override flags still work (check flag handling code is unchanged) *(completed: flag docs intact)*
- [x] Spot-check 2-3 extension agents to confirm frontmatter is well-formed after edits *(completed: grant-agent, epi-research-agent, deck-planner-agent verified)*

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- No files modified (validation only)

**Verification**:
- Zero unexpected `model: opus` entries
- Zero agents missing model fields that should have them
- CLAUDE.md matches actual state of agent definitions
- Override flags documentation is intact

## Testing & Validation

- [x] `grep -rl "^model: opus" .claude/agents/*.md` returns exactly 3 files (planner, meta-builder, reviser) *(verified)*
- [x] `grep -rl "^model: sonnet" .claude/agents/*.md` returns exactly 8 files *(verified)*
- [x] `grep -rl "^model: opus" .claude/extensions/*/agents/*.md` returns exactly 10 files (formal/4, lean/2, founder/legal-analysis/1, core planner/meta-builder/reviser/3) *(verified: plan said 7 non-core, actual is 10 including 3 core mirrors)*
- [x] `grep -rl "^model: sonnet" .claude/commands/*.md` returns exactly 4 files (research, plan, implement, project-overview) *(verified)*
- [x] `grep "All agents default to Opus" .claude/` returns zero matches across all files *(verified)*
- [x] CLAUDE.md skill-agent table model column is accurate *(verified)*
- [x] agent-frontmatter-standard.md documents the three-tier policy *(verified)*

## Artifacts & Outputs

- `plans/01_model-routing-research.md` (this file)
- Updated agent frontmatter in `.claude/agents/` (11 files)
- Updated extension agent frontmatter in `.claude/extensions/*/agents/` (20 files changed, 7 kept)
- Updated command frontmatter in `.claude/commands/` (4 files)
- Updated documentation in `.claude/docs/` (3 files)
- Updated `.claude/extensions/core/agents/README.md`
- Updated `.claude/extensions/core/merge-sources/claudemd.md`
- Regenerated `.claude/CLAUDE.md`

## Rollback/Contingency

All changes are to frontmatter fields and documentation text. If quality regression is observed after deployment:
1. Revert individual agent model fields back to `opus` using `git checkout` on specific files
2. The `--opus` flag provides immediate per-invocation override without any file changes
3. Users can set `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-4-6` as a global override for agents that inherit
4. Full rollback via `git revert` of the implementation commit restores original state
