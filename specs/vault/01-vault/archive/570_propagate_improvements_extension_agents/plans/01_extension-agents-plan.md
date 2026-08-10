# Implementation Plan: Propagate Deviation Tracking to Extension Agents

- **Task**: 570 - propagate_improvements_extension_agents
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 569
- **Research Inputs**: specs/570_propagate_improvements_extension_agents/reports/01_extension-agents-research.md
- **Artifacts**: plans/01_extension-agents-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Propagate six task-569 improvements (4B-ii Step 4 deviation annotation, 4D-ii post-phase self-review, 4D-iii progressive handoff, 4E Step 1.5 plan annotation, Stage 6 Plan Deviations section, Phase Checkpoint Protocol update) to all 11 extension implementation agents. Agents are grouped by structural similarity: 1 verbatim copy (Type A), 6 full agents with phase loops (Type B), and 4 thin wrappers (Type C). The implementation uses the post-569 general-implementation-agent as the authoritative reference and adapts insertions to each agent's existing structure.

### Research Integration

Research report (01_extension-agents-research.md) classified all 11 agents into three types and identified exact insertion points for each. Key findings: the core extension copy is a pre-569 snapshot needing identical edits; nix/neovim agents exist as identical pairs (extension + .claude/agents/ mirror); the lean agent has a unique structure requiring adapted insertions; thin wrappers need only minimal 1-sentence notes plus a Plan Deviations mention.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- All 11 extension implementation agents include deviation annotation (4B-ii Step 4) adapted to their structure
- All 11 agents include post-phase self-review (4D-ii) at appropriate detail level
- All 11 agents include progressive handoff update (4D-iii) at appropriate detail level
- All full agents (Types A and B) include 4E Step 1.5 plan annotation before handoff
- All agents with summary templates include Plan Deviations section
- All full agents with Phase Checkpoint Protocol sections have updated step references
- Nix and neovim agent pairs remain identical after changes

**Non-Goals**:
- Expanding thin wrapper agents into full agents
- Adding progress file tracking to the lean agent
- Modifying the post-569 general-implementation-agent (already updated)
- Updating summary-format.md or other shared format files (separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nix/neovim pairs diverge after edits | M | M | Apply identical edits to both files in each pair; verify with diff after |
| Lean agent's unique structure causes incorrect insertion | H | M | Use adapted insertion points identified in research; test against lean agent's existing sections |
| Summary template format conflicts (old vs new) | L | L | Full Type B agents get complete updated template; thin Type C agents get mention only |
| Core extension copy drifts from main agent | M | L | After Phase 1, verify core copy matches main agent with diff |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2, 3   | 1          |
| 3    | 4      | 1          |
| 4    | 5      | 1          |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core Extension Copy (Type A) [COMPLETED]

**Goal**: Update `extensions/core/agents/general-implementation-agent.md` to match the post-569 general-implementation-agent exactly.

**Tasks**:
- [ ] Read `.claude/agents/general-implementation-agent.md` (post-569 reference) to capture the exact text of all six changes
- [ ] Read `.claude/extensions/core/agents/general-implementation-agent.md` (pre-569 copy) to locate insertion points
- [ ] Insert 4B-ii Step 4 (deviation annotation block) after Step 3 in the Stage 4B-ii section (after the "in-progress objective" step, before the "Note: If the plan file does not use..." line)
- [ ] Insert 4D-ii (Post-Phase Self-Review) section after Stage 4D (Mark Phase Complete)
- [ ] Insert 4D-iii (Progressive Handoff Update) section after 4D-ii
- [ ] Insert 4E Step 1.5 (plan annotation before handoff) into Stage 4E between Step 1 and Step 2
- [ ] Replace Stage 6 summary template: change `## Changes Made` / `## Files Modified` to `## Overview` / `## What Changed` / `## Decisions` / `## Plan Deviations` format
- [ ] Add Plan Deviations population instruction after the template ("Populate `## Plan Deviations` from the `deviations` arrays across all phase progress files...")
- [ ] Update Phase Checkpoint Protocol step 4: change from `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]` to reference 4D-ii and 4D-iii
- [ ] Verify with diff: `diff extensions/core/agents/general-implementation-agent.md .claude/agents/general-implementation-agent.md` should show zero differences

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/agents/general-implementation-agent.md` - Apply all six task-569 changes

**Verification**:
- `diff` between core extension copy and post-569 general agent returns empty output

---

### Phase 2: Paired Domain Agents (Type B - Nix and Neovim) [COMPLETED]

**Goal**: Add all six deviation tracking improvements to the nix pair (2 files) and neovim pair (2 files), adapted to their Stage 4 structure.

**Tasks**:

**Nix agent pair** (`extensions/nix/agents/nix-implementation-agent.md` + `.claude/agents/nix-implementation-agent.md`):
- [ ] Insert 4B-ii Step 4 (deviation annotation) as a new step after Step C.4 ("Verify changes") in the Execute Steps section. Add as Step C.5: "For any step deviated from (skipped/altered/deferred), annotate the checklist item inline" with the three annotation formats
- [ ] Insert 4D-ii (Post-Phase Self-Review) section after Step E (Mark Phase Complete), as a new `#### 4D-ii. Post-Phase Self-Review` subsection. Adapt from general agent but reference `nix flake check` as the verification context
- [ ] Insert 4D-iii (Progressive Handoff Update) section after 4D-ii. Same condensed template as general agent
- [ ] Add new `#### 4E. Handoff on Context Pressure` section after 4D-iii, adapted from general agent. Include Step 1.5 (plan annotation before handoff). Reference nix verification in the handoff context
- [ ] Replace Stage 6 summary template: change `## Changes Made` / `## Files Modified` to `## Overview` / `## What Changed` / `## Decisions` / `## Plan Deviations`. Keep nix-specific verification section and example content
- [ ] Add Plan Deviations population instruction after Stage 6 template
- [ ] Add `## Phase Checkpoint Protocol` section after the Stage 6a section (before any existing error handling or other sections). Include all 5 steps: mark in-progress, execute, mark completed + self-review + handoff, git commit, repeat
- [ ] Copy all changes identically to `.claude/agents/nix-implementation-agent.md`
- [ ] Verify with diff: both nix files should be identical

**Neovim agent pair** (`extensions/nvim/agents/neovim-implementation-agent.md` + `.claude/agents/neovim-implementation-agent.md`):
- [ ] Insert 4B-ii Step 4 (deviation annotation) as Step B.4 after Step B.3 ("Verify changes") in the Execute Steps section. Same three annotation formats as general agent
- [ ] Insert 4D-ii (Post-Phase Self-Review) section after Step D (Mark Phase Complete). Adapt from general agent
- [ ] Insert 4D-iii (Progressive Handoff Update) section after 4D-ii. Same condensed template as general agent
- [ ] Add new `#### 4E. Handoff on Context Pressure` section after 4D-iii, adapted from general agent. Include Step 1.5 (plan annotation before handoff). Reference `nvim --headless` verification
- [ ] Replace Stage 6 summary template: change `## Changes Made` / `## Files Modified` to `## Overview` / `## What Changed` / `## Decisions` / `## Plan Deviations`. Keep neovim-specific verification section and example content
- [ ] Add Plan Deviations population instruction after Stage 6 template
- [ ] Add `## Phase Checkpoint Protocol` section after Stage 6a. Include all 5 steps referencing neovim-specific commit format
- [ ] Copy all changes identically to `.claude/agents/neovim-implementation-agent.md`
- [ ] Verify with diff: both neovim files should be identical

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/nix/agents/nix-implementation-agent.md` - Add all six changes
- `.claude/agents/nix-implementation-agent.md` - Mirror of nix extension agent
- `.claude/extensions/nvim/agents/neovim-implementation-agent.md` - Add all six changes
- `.claude/agents/neovim-implementation-agent.md` - Mirror of neovim extension agent

**Verification**:
- `diff` between each extension agent and its `.claude/agents/` mirror returns empty output
- Each agent file contains all six new sections (grep for "4D-ii", "4D-iii", "Plan Deviations", "deviation: skipped", "Step 1.5", "Phase Checkpoint Protocol")

---

### Phase 3: Web Agent (Type B - Standalone) [COMPLETED]

**Goal**: Add all six deviation tracking improvements to the web implementation agent, adapted for web-specific build references.

**Tasks**:
- [ ] Insert 4B-ii Step 4 (deviation annotation) after Step B.4 ("Handle build errors") as Step B.5. Same three annotation formats. Add note that deferred tasks affecting TypeScript types or build require `pnpm check` before proceeding
- [ ] Insert 4D-ii (Post-Phase Self-Review) section after Step D (Mark Phase Complete). Adapt from general agent
- [ ] Insert 4D-iii (Progressive Handoff Update) section after 4D-ii. Same condensed template as general agent
- [ ] Add new `#### 4E. Handoff on Context Pressure` section after 4D-iii, adapted from general agent. Include Step 1.5 (plan annotation before handoff). Reference `pnpm build` and `pnpm check` in handoff context
- [ ] Replace Stage 6 summary template: change `## Changes Made` / `## Files Modified` to `## Overview` / `## What Changed` / `## Decisions` / `## Plan Deviations`. Keep web-specific verification section and example content
- [ ] Add Plan Deviations population instruction after Stage 6 template
- [ ] Add `## Phase Checkpoint Protocol` section after Stage 6a. Include all 5 steps with web-specific commit format

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/web/agents/web-implementation-agent.md` - Add all six changes with web-specific adaptations

**Verification**:
- Agent file contains all six new sections (grep for "4D-ii", "4D-iii", "Plan Deviations", "deviation: skipped", "Step 1.5", "Phase Checkpoint Protocol")
- Web-specific references (`pnpm check`, `pnpm build`) appear in deviation annotation and handoff sections

---

### Phase 4: Lean Agent (Type B - Unique Structure) [COMPLETED]

**Goal**: Add adapted versions of all six deviation tracking improvements to the lean implementation agent, respecting its unique structure (no progress file tracking, different section layout, escalation protocol).

**Tasks**:
- [ ] Read the lean agent file to confirm current structure: "Phase Status Updates" section (lines 66-89), "Phase Checkpoint Protocol" (lines 326-348), "Context Management" (lines 351-371)
- [ ] Insert deviation annotation note in the "Phase Status Updates" section, after the "After Completing a Phase" block (after line 88). Add a new subsection: "### When Deviating from Plan Steps" with the three inline annotation formats (skipped/altered/deferred). Note that the lean agent does not use a progress file; deviations are annotated inline on plan checklist items only
- [ ] Insert 4D-ii (Post-Phase Self-Review) into the Phase Checkpoint Protocol section. Add as a new step between step 3 (mark completed) and the current step 4 (git commit). Adapt for lean context: include "verify no unchecked tactics or introduced sorries" as a lean-specific self-review item
- [ ] Insert 4D-iii (Progressive Handoff Update) after 4D-ii in the Phase Checkpoint Protocol. Use the same condensed template but note that the lean agent already has a fuller handoff protocol in "Context Management"
- [ ] Renumber the Phase Checkpoint Protocol: step 3 = mark completed, step 4 = post-phase self-review, step 5 = progressive handoff, step 6 = git commit
- [ ] Insert Step 1.5 (plan annotation before handoff) into the "Handoff Protocol" subsection of "Context Management" between step 1 ("Write progress file") and step 2 ("Write handoff document"). Adapt: "Before writing the handoff document, annotate the plan file with completion status and deviation annotations for each checklist item in the current phase"
- [ ] Add a brief note after the existing summary-related instructions that the implementation summary should include a `## Plan Deviations` section populated from inline plan annotations. Since the lean agent has no explicit Stage 6 template, add this as a note in the Critical Requirements section or near the summary mention

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - Add adapted versions of all six changes

**Verification**:
- Agent file contains deviation annotation formats (grep for "deviation: skipped")
- Phase Checkpoint Protocol has 6 steps (not 4)
- Context Management / Handoff Protocol has Step 1.5 reference
- "Plan Deviations" appears in the file

---

### Phase 5: Thin Wrapper Agents (Type C) [COMPLETED]

**Goal**: Add minimal deviation tracking notes to all four thin wrapper agents (latex, python, typst, z3) using a uniform pattern.

**Tasks**:

For each of the four agents, apply the same three changes:

**LaTeX agent** (`extensions/latex/agents/latex-implementation-agent.md`):
- [ ] After Step D (Mark Phase Complete), before Step E (Git Commit Phase), insert a 1-sentence self-review note: "After marking COMPLETED, review any unchecked plan items and annotate deviations inline (skipped/altered/deferred) per the general agent's 4D-ii protocol."
- [ ] After the self-review note, insert a 1-sentence progressive handoff note: "Write a condensed phase-end handoff to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md` after each phase completion (see general agent 4D-iii for template)."
- [ ] In Stage 6 (Create Implementation Summary), after the existing line "Write to `specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md`", add: "Include a `## Plan Deviations` section listing any deviations from the plan (see general agent Stage 6 for format). Use `- None (implementation followed plan)` when no deviations occurred."

**Python agent** (`extensions/python/agents/python-implementation-agent.md`):
- [ ] After Step C (Mark Phase Complete), before Step D (Git Commit), insert the same 1-sentence self-review note
- [ ] After the self-review note, insert the same 1-sentence progressive handoff note
- [ ] In Stage 6, after the summary path line, add the same Plan Deviations instruction

**Typst agent** (`extensions/typst/agents/typst-implementation-agent.md`):
- [ ] After Step D (Mark Phase Complete), before Step E (Git Commit), insert the same 1-sentence self-review note
- [ ] After the self-review note, insert the same 1-sentence progressive handoff note
- [ ] In Stage 6, after the summary path line, add the same Plan Deviations instruction

**Z3 agent** (`extensions/z3/agents/z3-implementation-agent.md`):
- [ ] After Step C or D (Mark Phase Complete -- confirm exact step letter), insert the same 1-sentence self-review note
- [ ] After the self-review note, insert the same 1-sentence progressive handoff note
- [ ] In Stage 6, after the summary path line, add the same Plan Deviations instruction

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/latex/agents/latex-implementation-agent.md` - Add 3 minimal notes
- `.claude/extensions/python/agents/python-implementation-agent.md` - Add 3 minimal notes
- `.claude/extensions/typst/agents/typst-implementation-agent.md` - Add 3 minimal notes
- `.claude/extensions/z3/agents/z3-implementation-agent.md` - Add 3 minimal notes

**Verification**:
- All four files contain "Plan Deviations" (grep confirmation)
- All four files contain "self-review" or "4D-ii" reference
- All four files contain "handoff" reference
- No thin wrapper exceeds ~20 lines of additions (keeps agents thin)

---

## Testing & Validation

- [ ] All 11 agent files contain "Plan Deviations" string: `grep -l "Plan Deviations" .claude/extensions/*/agents/*-implementation-agent.md .claude/agents/*-implementation-agent.md`
- [ ] All Type A and B agents (7 files) contain "4D-ii" string: `grep -l "4D-ii" .claude/extensions/{core,nix,nvim,web,lean}/agents/*-implementation-agent.md .claude/agents/{nix,neovim}-implementation-agent.md`
- [ ] All Type A and B agents contain "deviation: skipped" format: `grep -l "deviation: skipped" .claude/extensions/{core,nix,nvim,web,lean}/agents/*-implementation-agent.md .claude/agents/{nix,neovim}-implementation-agent.md`
- [ ] Nix pair identical: `diff .claude/extensions/nix/agents/nix-implementation-agent.md .claude/agents/nix-implementation-agent.md` returns empty
- [ ] Neovim pair identical: `diff .claude/extensions/nvim/agents/neovim-implementation-agent.md .claude/agents/neovim-implementation-agent.md` returns empty
- [ ] Core extension matches general agent: `diff .claude/extensions/core/agents/general-implementation-agent.md .claude/agents/general-implementation-agent.md` returns empty

## Artifacts & Outputs

- `specs/570_propagate_improvements_extension_agents/plans/01_extension-agents-plan.md` (this file)
- `specs/570_propagate_improvements_extension_agents/summaries/01_extension-agents-summary.md` (created during implementation)
- 11 modified agent files across `.claude/extensions/` and `.claude/agents/`

## Rollback/Contingency

All 11 agent files are tracked in git. If changes introduce problems:
1. Revert individual files with `git checkout HEAD -- <path>` for any agent that has issues
2. Since pairs must stay identical, always revert both files in a pair together
3. The post-569 general-implementation-agent is not modified by this task and serves as the stable reference
