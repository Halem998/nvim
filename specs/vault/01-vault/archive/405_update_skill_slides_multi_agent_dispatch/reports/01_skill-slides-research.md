# Research Report: Task #405

**Task**: 405 - Update skill-slides for multi-agent dispatch and plan workflow
**Started**: 2026-04-12T00:00:00Z
**Completed**: 2026-04-12T00:15:00Z
**Effort**: Small-Medium (single file rewrite with ~120 lines net addition)
**Dependencies**: Task 403 (completed -- three specialized agents now exist)
**Sources/Inputs**:
- `/home/benjamin/.config/zed/DIFF.md` section 3.1 (primary specification)
- Current `extensions/present/skills/skill-slides/SKILL.md` (337 lines)
- Current `extensions/present/commands/slides.md` (design questions pattern at lines 328-418)
- Core `skills/skill-planner/SKILL.md` (plan delegation pattern)
- `extensions/present/manifest.json` (routing table)
- Task 403 completion summary (agent split confirmed)
**Artifacts**:
- `specs/405_update_skill_slides_multi_agent_dispatch/reports/01_skill-slides-research.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The DIFF.md spec defines 12 discrete changes to SKILL.md, moving from a 2-workflow/1-agent model to a 3-workflow/4-agent dispatch model
- All three target agents (slides-research-agent, pptx-assembly-agent, slidev-assembly-agent) already exist from task 403; planner-agent is a core agent
- The largest new section is Stage 3.5 (Design Questions, ~120 lines), which relocates D1-D3 interactive questions from the `/slides --design` command into the skill's plan workflow
- The existing code structure maps cleanly to the diff: changes are additive (new workflow row, new stage, new dispatch logic) rather than restructuring
- Theme option E ("UCSF Institutional") is a new addition with no precedent in the current D1 question; the `ucsf-institutional.json` theme file already exists from task 403/408

## Context and Scope

Task 405 rewrites `extensions/present/skills/skill-slides/SKILL.md` to:

1. Add a `plan` workflow type that runs design questions (D1-D3) before delegating to planner-agent
2. Replace single-agent delegation with a multi-agent dispatch table routing to one of four agents
3. Add plan postflight status mapping ([PLANNING] -> [PLANNED])

The scope is limited to the SKILL.md file itself. The manifest.json routing already handles `/plan` -> `skill-slides` (line 31 of manifest.json). The command file (`slides.md`) retains its `--design` path for backward compatibility but the primary design workflow moves into the skill.

## Findings

### 1. Current SKILL.md Structure (337 lines)

The file has this structure:
- Frontmatter (lines 1-11): name, description, allowed-tools, context/tools comments
- Introduction (lines 14-19): "Thin wrapper that delegates to slides-agent"
- Context References (lines 22-29)
- Trigger Conditions (lines 33-38): `/slides`, `/research` on slides, `/implement` on slides
- Workflow Type Routing table (lines 43-53): two rows (slides_research, assemble) plus `--design` note
- Input Parameters (lines 58-65): workflow_type accepts slides_research or assemble
- Stage 1 Input Validation (lines 70-98)
- Stage 2 Preflight Status Update (lines 104-137): two cases
- Stage 3 Create Postflight Marker (lines 143-158)
- Stage 4 Prepare Delegation Context (lines 164-182)
- Stage 5 Invoke Subagent (lines 188-200): hardcoded "slides-agent"
- Stage 6 Parse Subagent Return (lines 206-216)
- Stage 7 Update Task Status Postflight (lines 222-229): two workflow rows
- Stage 8 Link Artifacts (lines 233-234)
- Stage 9 Git Commit (lines 238-261)
- Stage 10 Cleanup (lines 265-271)
- Stage 11 Return Brief Summary (lines 275-336)

### 2. Diff Change Analysis (12 changes from DIFF.md section 3.1)

| # | Location | Type | Complexity |
|---|----------|------|------------|
| 1 | Frontmatter description | Edit (add phrase) | Trivial |
| 2 | Frontmatter comments | Replace block | Simple |
| 3 | Intro text | Rewrite paragraph | Simple |
| 4 | Trigger conditions | Add bullet | Trivial |
| 5 | Workflow Type Routing table | Add row | Simple |
| 6 | Routing note | Replace note | Moderate |
| 7 | Input Parameters | Add "plan" to enum | Trivial |
| 8 | Stage 3 preflight | Add case branch | Simple |
| 9 | NEW Stage 3.5 | New section (~120 lines) | Significant |
| 10 | Stage 4 delegation | Add agent resolution | Moderate |
| 11 | Stage 5 invoke | Parameterize agent | Simple |
| 12 | Stage 6/7 postflight | Add plan rows | Simple |

### 3. Design Questions (D1-D3) -- Source Analysis

The current design questions live in `slides.md` (lines 328-418) under the `--design` workflow. The DIFF.md spec moves them into SKILL.md Stage 3.5 with these modifications:

**D1 Visual Theme**: Current options are A-D. The diff adds "E) UCSF Institutional -- Navy/blue, Garamond headings (institutional branding)". The `ucsf-institutional.json` theme file exists at `extensions/present/context/project/present/talk/themes/ucsf-institutional.json` (confirmed via task 408 completion).

**D2 Key Message Ordering**: Identical to current pattern -- read research report, extract key messages, present for reorder.

**D3 Section Emphasis**: Identical to current multi-select pattern.

**New behavior**: Stage 3.5 checks for existing `design_decisions` in task metadata and offers reuse/reconfigure. This is new -- the `--design` command did not check for prior decisions.

**Theme fallback chain** (new): `design_decisions.theme` -> research report "Recommended Theme" section -> default `academic-clean`. This is specified in DIFF.md item 6.

### 4. Multi-Agent Dispatch Pattern

The dispatch table maps (workflow_type, output_format) to a target agent:

| workflow_type | output_format | target_agent |
|---------------|---------------|--------------|
| slides_research | (any) | slides-research-agent |
| plan | (any) | planner-agent |
| assemble | pptx | pptx-assembly-agent |
| assemble | (other/slidev) | slidev-assembly-agent |

This is a new pattern for present extension skills. The current skill-grant routes all workflow types to a single `grant-agent`. The core `skill-planner` always routes to `planner-agent`. Skill-slides will be the first skill to implement conditional multi-agent dispatch.

The dispatch logic goes in Stage 4 (Prepare Delegation Context), and Stage 5 changes from hardcoded `slides-agent` to `{target_agent}`.

### 5. Existing Agent Readiness

All four target agents are confirmed available:
- `slides-research-agent.md` -- 304 lines, created by task 403
- `pptx-assembly-agent.md` -- ~385 lines, created by task 403 with Phase Checkpoint Protocol
- `slidev-assembly-agent.md` -- ~415 lines, created by task 403 with Phase Checkpoint Protocol
- `planner-agent` -- core agent, always available

### 6. Manifest Routing (Already Configured)

The manifest.json already routes `/plan` on slides tasks to skill-slides:
```json
"plan": { "present:slides": "skill-slides", "slides": "skill-slides" }
```
No manifest changes needed for task 405.

### 7. Postflight Status Mapping for Plan Workflow

The plan workflow needs these postflight mappings added to Stage 7:

| Workflow Type | Meta Status | Final state.json | Final TODO.md |
|---------------|-------------|-----------------|---------------|
| plan | planned | planned | [PLANNED] |
| plan | partial | planning | [PLANNING] |
| plan | failed | (keep preflight) | (keep preflight) |

And Stage 9 git commit needs a `plan)` case with action "create implementation plan".

### 8. Stage Renumbering Impact

Adding Stage 3.5 does not require renumbering existing stages. The diff uses "3.5" to insert between Stage 3 (postflight marker) and Stage 4 (delegation context). This follows the convention of interstitial numbering used elsewhere in the codebase.

## Decisions

- The `--design` workflow in `slides.md` should be preserved for backward compatibility. The new Stage 3.5 in SKILL.md is the primary path.
- Stage numbering will use "3.5" for the design questions stage rather than renumbering all subsequent stages.
- The allowed-tools frontmatter already includes `AskUserQuestion` (needed for D1-D3).
- The `update-task-status.sh` script is not used by skill-slides (it uses inline jq). The implementation should follow the existing inline pattern for consistency, or adopt the script if appropriate.

## Risks and Mitigations

1. **Risk**: Design questions referencing research report that does not exist yet.
   **Mitigation**: Stage 3.5 should validate that a research report exists before attempting to extract key messages. If absent, skip D2 (message ordering) and provide sensible defaults.

2. **Risk**: Existing `design_decisions` from old `--design` workflow may have different schema.
   **Mitigation**: The reuse check in Stage 3.5 should validate all required fields (theme, message_order, section_emphasis) exist before offering reuse.

3. **Risk**: `planner-agent` may not understand slides-specific delegation context.
   **Mitigation**: The planner-agent is generic and receives task context including task_type. The design_decisions in state.json metadata provide the slides-specific information.

## Appendix

### Search Queries Used
- Glob: `extensions/present/agents/*.md` -- confirmed 3 new agents exist
- Grep: `design_decisions|D1:|D2:|D3:` in `.claude/` -- found current design question locations
- Grep: `AskUserQuestion` in present skills -- confirmed allowed-tools already includes it
- Read: DIFF.md lines 91-135 -- full specification of section 3.1

### Key File Paths
- Target: `.claude/extensions/present/skills/skill-slides/SKILL.md`
- Design question source: `.claude/extensions/present/commands/slides.md` (lines 328-418)
- Planner skill pattern: `.claude/skills/skill-planner/SKILL.md`
- Manifest routing: `.claude/extensions/present/manifest.json`
- Agent files: `.claude/extensions/present/agents/{slides-research,pptx-assembly,slidev-assembly}-agent.md`
