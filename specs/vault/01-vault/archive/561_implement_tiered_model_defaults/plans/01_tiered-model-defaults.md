# Implementation Plan: Task #561

- **Task**: 561 - implement_tiered_model_defaults
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: Task 560 (completed)
- **Research Inputs**: specs/561_implement_tiered_model_defaults/reports/01_tiered-model-audit.md
- **Artifacts**: plans/01_tiered-model-defaults.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 560 completed the bulk of the tiered model routing implementation -- updating 8 core agents, 20+ extension agents, 4 commands, and all documentation standards. The research audit for task 561 identified 3 remaining gaps: stale "currently opus for all agents" text in 3 command files, a missing Model column in the nix extension skill-agent table in CLAUDE.md, and 14 extension agents that need explicit model fields added. This plan addresses all 3 gaps with straightforward text edits and a verification phase.

### Research Integration

Research report `reports/01_tiered-model-audit.md` provided a complete audit of codebase state post-task 560. Findings F7, F8, and F9 identified the 3 actionable gaps. Findings F1-F6 confirmed that core agents, extension agents with explicit models, commands, documentation, team-mode skills, and override flags are all correctly implemented. The research recommended specific replacement text and per-file changes adopted in this plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the ROADMAP item "Agent frontmatter validation" under Phase 1 > Agent System Quality, by ensuring all pattern-execution extension agents have explicit model frontmatter fields. It does not directly complete that item (which calls for a lint script), but reduces the gap.

## Goals & Non-Goals

**Goals**:
- Fix 6 occurrences of stale "currently opus for all agents" text in command files
- Add Model column to nix extension skill-agent table in CLAUDE.md
- Add explicit `model: sonnet` to 13 pattern-execution extension agents
- Add explicit `model: opus` to 1 high-stakes extension agent (legal-council-agent)
- Verify all changes via grep-based validation

**Non-Goals**:
- Changing filetypes extension agents (correct inherit behavior)
- Changing founder utility agents (market, strategy, analyze, project, meeting, finance, financial-analysis, founder-spreadsheet -- correct inherit behavior)
- Building a lint script for agent frontmatter validation (separate ROADMAP item)
- Modifying override flag behavior (already working correctly)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| z3 agent quality regression at sonnet tier | M | L | `--opus` flag available per-invocation; research matrix still recommended sonnet for z3 |
| CLAUDE.md table formatting breakage | L | L | Compare against nvim extension table (already correct 4-column format) |
| Stale text replacement misses edge cases | L | L | Grep verification in Phase 4 catches any missed occurrences |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Stale Command Documentation [COMPLETED]

**Goal**: Replace 6 occurrences of "currently opus for all agents" with accurate tiered description in 3 command files.

**Tasks**:
- [ ] Edit `.claude/commands/research.md`: replace first occurrence of `(use agent default, currently opus for all agents)` with `(use agent's frontmatter default: opus for planner/meta-builder/reviser; sonnet for general-purpose agents)`
- [ ] Edit `.claude/commands/research.md`: replace second occurrence (same substitution)
- [ ] Edit `.claude/commands/plan.md`: replace first occurrence (same substitution)
- [ ] Edit `.claude/commands/plan.md`: replace second occurrence (same substitution)
- [ ] Edit `.claude/commands/implement.md`: replace first occurrence (same substitution)
- [ ] Edit `.claude/commands/implement.md`: replace second occurrence (same substitution)

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/research.md` - 2 text replacements
- `.claude/commands/plan.md` - 2 text replacements
- `.claude/commands/implement.md` - 2 text replacements

**Verification**:
- `grep -r "currently opus" .claude/commands/` returns zero results
- `grep -c "frontmatter default" .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md` shows 2 occurrences per file

---

### Phase 2: Fix Nix Extension Table in CLAUDE.md [COMPLETED]

**Goal**: Add Model column with "sonnet" values to the nix extension skill-agent table, matching the nvim extension table format.

**Tasks**:
- [ ] Locate the nix extension skill-agent table in `.claude/extensions/nix/merge-sources/CLAUDE-nix.md` (the source file that generates the CLAUDE.md section)
- [ ] Add Model column header and "sonnet" values for both rows
- [ ] If the nix table also exists directly in a merge-source or template, update both locations
- [ ] Verify the updated table has 4 columns: Skill, Agent, Model, Purpose

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/nix/merge-sources/CLAUDE-nix.md` - Add Model column to skill-agent table
- `.claude/CLAUDE.md` may need regeneration or direct edit if not auto-generated from merge-sources

**Verification**:
- The nix extension skill-agent table has 4 columns matching nvim extension format
- Both nix agents show "sonnet" in the Model column

---

### Phase 3: Add Explicit Model Fields to Extension Agents [COMPLETED]

**Goal**: Add `model: sonnet` to 13 pattern-execution agents and `model: opus` to 1 high-stakes agent, eliminating inherit-tier ambiguity for these files.

**Tasks**:
- [ ] Add `model: sonnet` to frontmatter of `extensions/python/agents/python-research-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/python/agents/python-implementation-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/typst/agents/typst-research-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/typst/agents/typst-implementation-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/web/agents/web-research-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/web/agents/web-implementation-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/z3/agents/z3-research-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/z3/agents/z3-implementation-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/founder/agents/deck-builder-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/founder/agents/deck-research-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/founder/agents/founder-implement-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/founder/agents/founder-plan-agent.md`
- [ ] Add `model: sonnet` to frontmatter of `extensions/latex/agents/latex-implementation-agent.md`
- [ ] Add `model: opus` to frontmatter of `extensions/founder/agents/legal-council-agent.md`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/python/agents/python-research-agent.md` - Add `model: sonnet`
- `.claude/extensions/python/agents/python-implementation-agent.md` - Add `model: sonnet`
- `.claude/extensions/typst/agents/typst-research-agent.md` - Add `model: sonnet`
- `.claude/extensions/typst/agents/typst-implementation-agent.md` - Add `model: sonnet`
- `.claude/extensions/web/agents/web-research-agent.md` - Add `model: sonnet`
- `.claude/extensions/web/agents/web-implementation-agent.md` - Add `model: sonnet`
- `.claude/extensions/z3/agents/z3-research-agent.md` - Add `model: sonnet`
- `.claude/extensions/z3/agents/z3-implementation-agent.md` - Add `model: sonnet`
- `.claude/extensions/founder/agents/deck-builder-agent.md` - Add `model: sonnet`
- `.claude/extensions/founder/agents/deck-research-agent.md` - Add `model: sonnet`
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Add `model: sonnet`
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Add `model: sonnet`
- `.claude/extensions/latex/agents/latex-implementation-agent.md` - Add `model: sonnet`
- `.claude/extensions/founder/agents/legal-council-agent.md` - Add `model: opus`

**Verification**:
- `grep -l "model: sonnet" .claude/extensions/{python,typst,web,z3,founder,latex}/agents/*.md` lists all 13 sonnet agents
- `grep "model: opus" .claude/extensions/founder/agents/legal-council-agent.md` confirms opus

---

### Phase 4: Verification and Consistency Check [COMPLETED]

**Goal**: Validate all changes are correct and no stale text or missing model fields remain.

**Tasks**:
- [ ] Verify no "currently opus" text remains: `grep -r "currently opus" .claude/`
- [ ] Verify nix extension table has Model column in CLAUDE.md
- [ ] Count agents with explicit model fields vs inherit: `grep -rl "model:" .claude/extensions/*/agents/*.md | wc -l`
- [ ] Verify legal-council-agent has opus (not sonnet): `grep "model:" .claude/extensions/founder/agents/legal-council-agent.md`
- [ ] Verify filetypes agents remain without model fields (inherit): `grep -L "model:" .claude/extensions/filetypes/agents/*.md`
- [ ] Verify founder utility agents remain without model fields: `grep -L "model:" .claude/extensions/founder/agents/{analyze-agent,finance-agent,financial-analysis-agent,founder-spreadsheet-agent,market-agent,meeting-agent,project-agent,strategy-agent}.md`
- [ ] Verify override flags still documented correctly in command files

**Timing**: 10 minutes

**Depends on**: 1, 2, 3

**Files to modify**: None (read-only verification)

**Verification**:
- All grep checks pass with expected results
- No regressions in existing correct tiering

## Testing & Validation

- [ ] `grep -r "currently opus" .claude/` returns zero results
- [ ] Nix extension table in CLAUDE.md has 4 columns (Skill, Agent, Model, Purpose)
- [ ] All 13 pattern-execution agents have `model: sonnet` in frontmatter
- [ ] `legal-council-agent.md` has `model: opus` in frontmatter
- [ ] Filetypes agents have no model field (inherit behavior preserved)
- [ ] Founder utility agents have no model field (inherit behavior preserved)
- [ ] Command files correctly describe tiered defaults

## Artifacts & Outputs

- `specs/561_implement_tiered_model_defaults/plans/01_tiered-model-defaults.md` (this plan)
- `specs/561_implement_tiered_model_defaults/summaries/01_tiered-model-defaults-summary.md` (post-implementation)

## Rollback/Contingency

All changes are text-only edits to markdown files. Rollback via `git checkout HEAD~1 -- .claude/` restores prior state. No build steps, no runtime dependencies, no data migrations. Individual phases can be reverted independently since all 3 gaps are orthogonal.
