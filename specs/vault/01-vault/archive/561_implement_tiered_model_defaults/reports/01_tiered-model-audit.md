# Research Report: Tiered Model Defaults Implementation Audit

- **Task**: 561 - implement_tiered_model_defaults
- **Started**: 2026-05-13T20:00:00Z
- **Completed**: 2026-05-13T20:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: task 560 (research_model_routing_best_practices) - COMPLETED
- **Sources/Inputs**:
  - `specs/560_research_model_routing_best_practices/reports/01_model-routing-research.md` - task 560 research
  - `specs/560_research_model_routing_best_practices/plans/01_model-routing-research.md` - task 560 plan
  - `specs/560_research_model_routing_best_practices/summaries/01_model-routing-summary.md` - task 560 summary
  - Codebase audit: `.claude/agents/*.md`, `.claude/commands/*.md`, `.claude/extensions/*/agents/*.md`
  - `.claude/CLAUDE.md` - skill-agent mapping tables
  - `.claude/docs/reference/standards/agent-frontmatter-standard.md` - tiered policy doc
  - `.claude/skills/skill-team-research/SKILL.md` - team mode model behavior
- **Artifacts**: `specs/561_implement_tiered_model_defaults/reports/01_tiered-model-audit.md`
- **Standards**: report-format.md, artifact-management.md

## Project Context

- **Upstream Dependencies**: task 560 (completed) - researched and partially implemented tiered model routing
- **Downstream Dependents**: All agent invocations, cost optimization, CLAUDE_CODE_SUBAGENT_MODEL env var effectiveness
- **Alternative Paths**: None
- **Potential Extensions**: Haiku tier for simplest agents (future), opusplan mode documentation

## Executive Summary

- Task 560 substantially completed the tiered model implementation: 8 core agents, 20+ extension agents, and 4 commands have been updated from `model: opus` to `model: sonnet`. The tiered policy documentation is in place.
- **3 primary gaps remain**: (1) stale "currently opus for all agents" text in 3 command files; (2) nix extension skill-agent table missing a Model column in CLAUDE.md; (3) 29 extension agents remain in the "inherit" tier without explicit model fields.
- Team-mode skills already default teammates to sonnet - no action needed.
- Override flags (--opus/--sonnet/--haiku) still work correctly - no action needed.
- The task 561 scope is now scoped to fixing the 3 gaps; core implementation from task 560 is complete.

## Context & Scope

Task 561 was created to implement the tiered model routing strategy researched in task 560. However, task 560 expanded its scope to complete phases 1-5 of the implementation, including:
- Updating core and extension agent frontmatter
- Updating command frontmatter (research, plan, implement, project-overview)
- Updating documentation standards (agent-frontmatter-standard.md, agent-template.md, creating-commands.md, README.md)
- Updating CLAUDE.md tables and merge-sources

This research audits the current codebase state to identify any remaining gaps before task 561 proceeds.

## Findings

### F1: Core Agents — COMPLETE

All 11 core agents are correctly tiered:

| Agent | Model | Status |
|-------|-------|--------|
| planner-agent | opus | ✓ correct |
| meta-builder-agent | opus | ✓ correct |
| reviser-agent | opus | ✓ correct |
| general-research-agent | sonnet | ✓ correct |
| general-implementation-agent | sonnet | ✓ correct |
| code-reviewer-agent | sonnet | ✓ correct |
| spawn-agent | sonnet | ✓ correct |
| neovim-research-agent | sonnet | ✓ correct |
| neovim-implementation-agent | sonnet | ✓ correct (was missing; now added) |
| nix-research-agent | sonnet | ✓ correct |
| nix-implementation-agent | sonnet | ✓ correct |

### F2: Extension Agents with Explicit Model Fields — COMPLETE

All extension agents that had `model: opus` have been correctly updated:

| Group | Agents | Model | Status |
|-------|--------|-------|--------|
| formal extension | formal-research, logic-research, math-research, physics-research | opus | ✓ correct (kept) |
| lean extension | lean-research, lean-implementation | opus | ✓ correct (kept) |
| founder extension | legal-analysis-agent | opus | ✓ correct (kept) |
| core extension mirrors | planner, meta-builder, reviser | opus | ✓ correct (kept) |
| core extension mirrors | general-research, general-implementation, code-reviewer, spawn | sonnet | ✓ correct |
| epidemiology extension | epi-research, epi-implement | sonnet | ✓ correct |
| founder extension | deck-planner-agent | sonnet | ✓ correct |
| latex extension | latex-research-agent | sonnet | ✓ correct |
| nix extension | nix-research, nix-implementation | sonnet | ✓ correct |
| nvim extension | neovim-research, neovim-implementation | sonnet | ✓ correct |
| present extension | all 9 agents | sonnet | ✓ correct |

### F3: Commands — COMPLETE

| Command | Model | Status |
|---------|-------|--------|
| research.md | sonnet | ✓ correct |
| plan.md | sonnet | ✓ correct |
| implement.md | sonnet | ✓ correct |
| project-overview.md | sonnet | ✓ correct |
| errors, fix-it, merge, meta, refresh, review, revise, spawn, tag, task, todo | opus | ✓ correct |

### F4: Documentation — COMPLETE

- `agent-frontmatter-standard.md`: Three-tier policy documented with table and examples ✓
- `agent-template.md`: Default changed to `model: sonnet` with tier comments ✓
- `creating-commands.md`: Model selection guidance added ✓
- `core/agents/README.md`: Contradiction resolved, tiered approach documented ✓
- CLAUDE.md `Model Enforcement` paragraph: Updated to tiered policy language ✓
- CLAUDE.md core skill-agent mapping table: Model column shows correct values ✓

### F5: Team-Mode Skills — COMPLETE

`skill-team-research` already defaults teammates to sonnet:
```bash
# SKILL.md line: teammate_model="${model_flag:-sonnet}"
```
No action needed. `skill-team-plan` and `skill-team-implement` follow the same pattern.

### F6: Override Flags — COMPLETE

`--opus`/`--sonnet`/`--haiku` flags continue to work correctly. The `research.md`, `plan.md`, and `implement.md` commands correctly document the flag parsing logic. No changes needed to flag dispatch code.

### F7: STALE DOCUMENTATION — ACTION NEEDED

Three command files contain a stale comment that is now factually incorrect:

**Files affected**: `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md`

**Stale text** (appears twice in each file, 6 occurrences total):
```
If none: `model_flag = null` (use agent default, currently opus for all agents)
```
and:
```
- `model_flag=null` -> omit `model` parameter (use agent default, currently opus for all agents)
```

**Correct text should be**:
```
If none: `model_flag = null` (use agent's frontmatter default: opus for planner/meta-builder/reviser; sonnet for general-purpose agents)
```

### F8: NIX EXTENSION TABLE MISSING MODEL COLUMN — ACTION NEEDED

CLAUDE.md contains two extension skill-agent mapping tables with inconsistent column schemas:

**Nvim extension table** (4 columns — correct):
```
| Skill | Agent | Model | Purpose |
| skill-neovim-research | neovim-research-agent | sonnet | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | sonnet | Neovim configuration implementation |
```

**Nix extension table** (3 columns — missing Model column):
```
| Skill | Agent | Purpose |
| skill-nix-research | nix-research-agent | NixOS/Home Manager/flakes research with MCP-NixOS |
| skill-nix-implementation | nix-implementation-agent | Nix configuration implementation with verification |
```

The nix table needs a Model column added with `sonnet` for both agents.

### F9: 29 INHERIT-TIER AGENTS WITHOUT EXPLICIT MODEL FIELDS — DECISION NEEDED

The following agents have no `model:` field and inherit from the parent session:

| Extension | Agents |
|-----------|--------|
| filetypes (7) | document-agent, docx-edit-agent, filetypes-router-agent, filetypes-spreadsheet-agent, presentation-agent, scrape-agent, sheet-agent |
| founder (12) | analyze-agent, deck-builder-agent, deck-research-agent, finance-agent, financial-analysis-agent, founder-implement-agent, founder-plan-agent, founder-spreadsheet-agent, legal-council-agent, market-agent, meeting-agent, project-agent, strategy-agent |
| latex (1) | latex-implementation-agent |
| python (2) | python-research-agent, python-implementation-agent |
| typst (2) | typst-research-agent, typst-implementation-agent |
| web (2) | web-research-agent, web-implementation-agent |
| z3 (2) | z3-research-agent, z3-implementation-agent |

**Total**: 29 agents

**Current behavior**: These agents inherit the main session's model (set by `/model` command). If the user is running on Sonnet, they get Sonnet; if on Opus, they get Opus.

**Task 560 rationale**: These were intentionally left as inherit because their usage patterns were unclear or they were viewed as utility/mechanical agents.

**Task 561 description says**: "Consider model: inherit for user-controlled agents."

**Analysis**:
- For research/implementation agents (python, typst, web, z3, founder/deck, latex-implementation): These should get `model: sonnet` for consistency with the tiered policy. They are pattern-execution agents, not deep-reasoning.
- For utility agents (filetypes/* routing, format conversion): `inherit` is correct policy — these are mechanical and should follow the session default.
- For founder general agents (market, strategy, analyze, project, meeting): These involve business analysis; `sonnet` is appropriate but leaving as inherit is acceptable.
- For legal-council-agent: This is different from legal-analysis-agent (which has opus). Legal council work requires nuanced reasoning — should probably get `model: opus` or at minimum be explicitly documented.

## Decisions

1. **Fix stale "currently opus" text in 3 command files** — clear bug, should be fixed.
2. **Add Model column to nix extension table in CLAUDE.md** — clear inconsistency, should be fixed.
3. **Add `model: sonnet` to research/implementation extension agents** without model fields (python, typst, web, z3, founder-research/implement, latex-implementation): These are pattern-execution agents equivalent to other sonnet-tier agents.
4. **Leave filetypes agents as inherit** — routing/conversion agents; correct inherit behavior.
5. **Leave founder utility agents (market, strategy, analyze, project, meeting, finance, financial-analysis, founder-spreadsheet) as inherit** — adequate for now, consistent with task 560's plan.
6. **Add `model: opus` to legal-council-agent** — high-stakes legal reasoning warrants Opus, consistent with legal-analysis-agent.

## Recommendations

1. **Fix stale command docs** (6 occurrences in research.md, plan.md, implement.md): Replace "currently opus for all agents" with tiered description. Low effort, high accuracy gain.

2. **Fix nix extension table** in CLAUDE.md: Add Model column with `sonnet` values. 1 table, 2 rows.

3. **Add `model: sonnet` to 8 pattern-execution extension agents**:
   - `extensions/python/agents/python-research-agent.md`
   - `extensions/python/agents/python-implementation-agent.md`
   - `extensions/typst/agents/typst-research-agent.md`
   - `extensions/typst/agents/typst-implementation-agent.md`
   - `extensions/web/agents/web-research-agent.md`
   - `extensions/web/agents/web-implementation-agent.md`
   - `extensions/z3/agents/z3-research-agent.md`
   - `extensions/z3/agents/z3-implementation-agent.md`

4. **Add `model: sonnet` to founder pattern-execution agents**:
   - `extensions/founder/agents/deck-builder-agent.md`
   - `extensions/founder/agents/deck-research-agent.md`
   - `extensions/founder/agents/founder-implement-agent.md`
   - `extensions/founder/agents/founder-plan-agent.md`
   - `extensions/latex/agents/latex-implementation-agent.md`

5. **Add `model: opus` to legal-council-agent**:
   - `extensions/founder/agents/legal-council-agent.md`

6. **Leave as inherit** (no change): filetypes/*, founder/analyze, founder/finance, founder/financial-analysis, founder/founder-spreadsheet, founder/market, founder/meeting, founder/project, founder/strategy.

7. **Update agent-frontmatter-standard.md** or CLAUDE.md to document that z3, python, web, typst, and latex-implementation are now explicitly sonnet (reflect the decisions made above).

## Risks & Mitigations

- **z3 sonnet regression**: z3 SMT formula construction was flagged medium risk in task 560. Monitor quality; `--opus` flag provides override. Research matrix still recommended sonnet for z3.
- **legal-council-agent change**: Adding `model: opus` increases cost for founder extension legal tasks but improves quality for high-stakes decisions.
- **Over-specification**: Adding explicit sonnet to 13 more agents means CLAUDE_CODE_SUBAGENT_MODEL no longer applies to them. This is consistent with the tiered policy — explicit sonnet agents are protected from both downward (haiku via env var) and upward (opus via env var) overrides. Per-invocation `--opus` flag still works.

## Appendix

### File Change Summary

| Category | Files | Change |
|----------|-------|--------|
| Stale docs | research.md, plan.md, implement.md | Fix "currently opus" text (6 occurrences) |
| CLAUDE.md | .claude/CLAUDE.md | Add Model column to nix extension table |
| Pattern-execution agents | python/*, typst/*, web/*, z3/*, founder/deck-*, founder/implement, founder-plan, latex-implementation | Add `model: sonnet` (13 files) |
| Legal | founder/legal-council-agent.md | Add `model: opus` (1 file) |
| No change | filetypes/*, founder/analyze, finance, financial-analysis, spreadsheet, market, meeting, project, strategy | Leave as inherit |

**Total files to modify**: 18 files (3 command docs + 1 CLAUDE.md + 14 agent files)
