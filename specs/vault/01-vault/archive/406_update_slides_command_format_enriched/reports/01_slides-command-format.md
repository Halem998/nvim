# Research Report: Task #406

**Task**: 406 - update_slides_command_format_enriched
**Started**: 2026-04-12T00:00:00Z
**Completed**: 2026-04-12T00:15:00Z
**Effort**: Medium (3-5 files, moderate changes per file)
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/zed/DIFF.md` section 2 (canonical spec)
- `.claude/extensions/present/commands/slides.md` (current command)
- `.claude/extensions/present/skills/skill-slides/SKILL.md` (current skill)
- `.claude/extensions/present/manifest.json` (routing config)
- `.claude/extensions/present/agents/slides-research-agent.md` (existing agent)
**Artifacts**:
- `specs/406_update_slides_command_format_enriched/reports/01_slides-command-format.md`
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The `/slides` command needs 15 specific changes per DIFF.md section 2 to remove the `--design` flag, add output format selection, add enriched description construction, update routing, and update output templates.
- The skill-slides SKILL.md already has most NEW changes applied (Stage 3.5 design questions, multi-agent dispatch, plan workflow routing). It needs no changes for this task.
- The manifest.json already has correct plan routing (`present:slides` -> `skill-slides`). No changes needed.
- The primary file requiring modification is `extensions/present/commands/slides.md` (all 15 changes from DIFF.md section 2).
- The agents (`slides-research-agent`, `pptx-assembly-agent`, `slidev-assembly-agent`) already exist and need no changes.

## Context & Scope

This task ports changes described in DIFF.md section 2 ("Commands") to the nvim present extension. The changes restructure the `/slides` command to:
1. Remove the `--design` flag and entire Stage 3 (design confirmation) -- design questions move to skill-slides plan workflow
2. Add output format selection (Slidev default vs PPTX) at Step 0.0
3. Add enriched description construction at Step 2.5
4. Update the routing table so `/plan N` routes to `skill-slides`
5. Update all output templates to use `{output_format}`

## Findings

### Current State Analysis

**slides.md (command)**: Still has OLD version. Contains `--design` flag in syntax, Step 2 design detection, entire Stage 3 design confirmation (~130 lines), old routing table pointing `/plan N` to `skill-planner`, and hardcoded "Slidev" references in output templates.

**skill-slides/SKILL.md**: Already updated to NEW version. Has Stage 3.5 design questions, multi-agent dispatch table, plan workflow routing, UCSF theme option (E), output_format extraction from forcing_data. No changes needed.

**manifest.json**: Already has `"present:slides": "skill-slides"` in the plan routing section, and `"slides": "skill-slides"` as a direct route. No changes needed.

**Agents**: `slides-agent.md` already deleted. Three specialized agents (`slides-research-agent`, `pptx-assembly-agent`, `slidev-assembly-agent`) already exist. No changes needed.

### Files Requiring Changes

Only one file needs modification:

**`.claude/extensions/present/commands/slides.md`** -- 15 discrete changes:

### Change List (from DIFF.md section 2)

1. **Overview text** (line 14): Change "Slidev-based research talks" to "research talks. Output format is user-selectable: Slidev (default) or PowerPoint (PPTX)."

2. **Syntax section** (line 22): Remove `/slides 500 --design` syntax line.

3. **Mode table** (lines 28-33): Remove the `Task number --design` row from Input Types table.

4. **NEW Step 0.0 (Output Format)**: Insert before Step 0.1. AskUserQuestion with "SLIDEV (default)" vs "PPTX" options. Store as `forcing_data.output_format`. Default: `"slidev"`.

5. **Step 0.4 (forcing_data object)** (line 103): Add `"output_format": "{selected_format}"` as first field in the forcing_data JSON.

6. **Step 2 (Detect Input Type)** (lines 129-131): Remove `--design` flag detection block (the `if` branch checking for `--design`).

7. **Step 3 (Handle Input Type)** (lines 156-157): Remove the `--design` handling paragraph ("If --design: Load existing task...").

8. **NEW Step 2.5 (Enrich Description)**: Insert after Step 2 in Stage 1. Construct enriched description: `{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.` Store as `$enriched_description`.

9. **Step 3 (state.json)** (line 188): Change `$description` to `$enriched_description` in state.json update.

10. **Step 4 (TODO.md)** (line 219): Change `{description}` to `{enriched_description}` in TODO.md entry.

11. **Step 6 (Output)** (lines 236-247): Add `Output Format: {output_format}` line. Change "Generate Slidev presentation" to "Generate {output_format} presentation".

12. **Stage 2 Research output** (line 288-289): Change "Next: /slides {N} --design (optional)..." to "Next: /plan {N} (create implementation plan with design questions)".

13. **ENTIRE STAGE 3 removed** (lines 294-418): Delete the entire "STAGE 3: DESIGN CONFIRMATION" section (~125 lines).

14. **Core Command Integration routing table** (lines 424-431): Change `/plan N` row from `skill-planner` to `skill-slides (plan workflow) -- Ask design questions, then delegate to planner-agent`. Change `/implement N` description to "Generate presentation (Slidev or PPTX per output_format)".

15. **Output Format templates** (lines 453-479): Change all "Generate Slidev presentation" to "Generate {output_format} presentation" in output format sections.

### Implementation Approach

All changes are confined to `slides.md`. The recommended approach is to apply edits in order from bottom to top to preserve line numbers:
1. Update Output Formats section (bottom)
2. Update Core Command Integration table
3. Delete Stage 3 entirely
4. Update Stage 2 research output
5. Add Step 2.5 (enriched description) in Stage 1
6. Update Stage 1 Steps 3-4 for enriched_description
7. Update Stage 1 Step 6 output
8. Remove --design from Step 2 and Step 3
9. Add Step 0.0 before Step 0.1
10. Update forcing_data object in Step 0.4
11. Remove --design from Input Types table and Syntax section
12. Update overview text

## Decisions

- Only `slides.md` needs changes. All other present extension files (skill, agents, manifest) are already in the NEW state.
- Changes should be applied in a single phase since they all target one file.
- The enriched description template follows the exact format from DIFF.md: `{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.`

## Risks & Mitigations

- **Risk**: The enriched description Step 2.5 references `{duration}` which maps to talk_type mode durations. Need to include a duration lookup based on talk_type in Step 2.5.
  - **Mitigation**: Add a case statement mapping talk_type to duration string (e.g., CONFERENCE -> "15-20 min").

- **Risk**: Removing Stage 3 could break any external references to `--design` flag.
  - **Mitigation**: The skill-slides SKILL.md already handles design questions in its plan workflow (Stage 3.5). No external dependencies on the old `--design` flag remain.

## Appendix

### Files Inventory

| File | Status | Action |
|------|--------|--------|
| `extensions/present/commands/slides.md` | OLD (needs update) | Apply 15 changes from DIFF.md section 2 |
| `extensions/present/skills/skill-slides/SKILL.md` | Already NEW | No changes needed |
| `extensions/present/manifest.json` | Already has plan routing | No changes needed |
| `extensions/present/agents/slides-research-agent.md` | Already exists | No changes needed |
| `extensions/present/agents/pptx-assembly-agent.md` | Already exists | No changes needed |
| `extensions/present/agents/slidev-assembly-agent.md` | Already exists | No changes needed |
| `agents/slides-agent.md` | Already deleted | No action needed |

### Key Line References in Current slides.md

- Overview: line 14
- Syntax: lines 18-22
- Input Types table: lines 27-33
- Stage 0 forcing questions: lines 46-109
- Step 2 (Detect Input Type): lines 128-149
- Step 3 (Handle Input Type): lines 151-164
- Stage 1 Task Creation: lines 168-247
- Stage 2 Research Delegation: lines 251-290
- Stage 3 Design Confirmation: lines 294-418
- Core Command Integration: lines 422-431
- Output Formats: lines 450-479
