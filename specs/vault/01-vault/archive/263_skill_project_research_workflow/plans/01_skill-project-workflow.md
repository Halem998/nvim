# Implementation Plan: Task #263

- **Task**: 263 - Update skill-project for research-only workflow
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task #262 (project-agent refactored to produce research reports)
- **Research Inputs**: specs/263_skill_project_research_workflow/reports/01_meta-research.md
- **Artifacts**: plans/01_skill-project-workflow.md (this file)
- **Standards**: plan-format.md, artifact-formats.md, skills-authoring.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Align skill-project's SKILL.md with the standard research skill lifecycle shared by skill-market, skill-analyze, skill-strategy, and skill-legal. The changes are mechanical text replacements across 11 identified deviations, transforming the skill from a multi-mode timeline manager into a single-path research wrapper. skill-market serves as the canonical 1:1 template.

### Research Integration

The research report identified 11 specific deviations between skill-project and the 4 conforming research skills. Every deviation has a precise replacement specification. The comparison matrix confirms all 4 conforming skills are structurally identical, so converging on any one (skill-market chosen) guarantees consistency with all.

## Goals & Non-Goals

**Goals**:
- Replace all planning/timeline lifecycle values with research lifecycle values
- Remove PLAN/TRACK/REPORT mode branching entirely
- Produce a SKILL.md that passes structural comparison against skill-market
- Preserve project-specific forcing_data pass-through mechanism

**Non-Goals**:
- Refactoring project-agent itself (that is task #262)
- Adding new features to skill-project
- Changing trigger conditions or keyword patterns (deferred to task #269)
- Updating manifest.json routing (that is task #268)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task #262 not landed yet | M | M | skill-project lifecycle change is independent of agent output format; safe to land first |
| In-flight tasks in planned/tracked/reported status | L | L | Check state.json for any project tasks in those statuses before merging |
| Trigger conditions still reference timeline concepts | L | L | Noted but deferred to task #269 for full skill consistency pass |

## Implementation Phases

### Phase 1: Remove mode system and update header [COMPLETED]

**Goal**: Strip all mode-related code and update the skill description to reflect research focus.

**Tasks**:
- [ ] Update frontmatter description from timeline management to research focus
- [ ] Update header paragraph from "routes project timeline requests" to "routes project research requests"
- [ ] Remove `mode` from Stage 1 validated inputs list (line 63)
- [ ] Remove mode validation block (lines 85-91): the `if [ -n "$mode" ]` case statement
- [ ] Remove `"mode": "PLAN|TRACK|REPORT or null"` from Stage 4 delegation context (line 155)
- [ ] Remove `mode_used` extraction from Stage 6 (line 204): `mode_used=$(jq -r '.metadata.mode // ""' "$metadata_file")`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - frontmatter, Stage 1, Stage 4, Stage 6

**Verification**:
- No occurrences of `PLAN|TRACK|REPORT` remain in the file
- No occurrences of `mode_used` or `mode` parameter validation remain
- Frontmatter description reflects research purpose

---

### Phase 2: Update preflight and postflight status values [COMPLETED]

**Goal**: Replace all planning/timeline status values with research lifecycle values.

**Tasks**:
- [ ] Stage 2: Replace `"planning"` with `"researching"` in state.json update (line 103)
- [ ] Stage 2: Replace `[PLANNING]` with `[RESEARCHING]` in TODO.md instruction (line 112)
- [ ] Stage 2: Update the section description from "planning" to "researching" (line 98)
- [ ] Stage 3: Replace `"operation": "project"` with `"operation": "research"` in postflight marker (line 127)
- [ ] Stage 4: Replace `"delegation_depth": 2` with `"delegation_depth": 1` in delegation context (line 159)
- [ ] Stage 7: Replace entire mode-dependent case statement (lines 214-237) with single-path update: `status: "researched"`, marker: `[RESEARCHED]`
- [ ] Stage 7: Update section description to match skill-market's wording

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Stages 2, 3, 4, 7

**Verification**:
- Stage 2 sets status "researching" and marker [RESEARCHING]
- Stage 3 operation field is "research"
- Stage 4 delegation_depth is 1
- Stage 7 is a single-path update to "researched"/[RESEARCHED] with no case statement

---

### Phase 3: Update artifact handling and commit message [COMPLETED]

**Goal**: Replace timeline artifact references with research artifact references and fix the commit message.

**Tasks**:
- [ ] Stage 8: Replace `type == "timeline"` with `type == "research"` in filter step (line 251)
- [ ] Stage 8: Replace "timeline artifacts" comment with "research artifacts" (line 249-254)
- [ ] Stage 8: Replace "Add new timeline artifact" comment with "Add new research artifact" (line 254)
- [ ] Stage 8: Replace TODO.md instruction from "Add timeline artifact link" to "Add research artifact link" (line 263)
- [ ] Stage 8: Remove the special note about not stripping `specs/` prefix for `strategy/timelines/` paths (line 265)
- [ ] Stage 8: Add standard `specs/` prefix stripping note matching skill-market: `todo_link_path="${artifact_path#specs/}"`
- [ ] Stage 9: Replace commit message from `"complete project ${mode_used,,}"` to `"complete research"` (line 275)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Stages 8, 9

**Verification**:
- All artifact type references use "research" not "timeline"
- No references to `strategy/timelines/` path
- Commit message is exactly `"task ${task_number}: complete research"`
- `specs/` prefix stripping note matches skill-market pattern

---

### Phase 4: Replace summary templates and error handling [COMPLETED]

**Goal**: Replace three mode-specific summary templates with a single research template, and clean up error handling.

**Tasks**:
- [ ] Stage 11: Replace all three mode-specific templates (PLAN/TRACK/REPORT, lines 298-332) with single research template matching the pattern:
  ```
  Project research completed for task {N}:
  - {questions_asked} forcing questions completed
  - Project: {project_name}
  - Research report: specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
  - Status updated to [RESEARCHED]
  - Changes committed
  - Next: Run /plan {N} to create implementation plan
  ```
- [ ] Stage 5: Update agent description from "Project timeline with WBS, PERT estimation, and resource allocation" to "Project research with scope analysis and timeline estimation"
- [ ] Stage 5: Update the bullet list to reflect research output (report at specs/) instead of timeline at strategy/timelines/
- [ ] Error handling: Remove "No Existing Timeline (TRACK/REPORT modes)" error case (lines 364-370)
- [ ] Error handling: Replace "planning" with "researching" in metadata file missing recovery (line 361)
- [ ] Error handling: Update "User Abandonment" to reference "researching" status instead of "planning" (line 376)
- [ ] Error handling: Remove "Directory Creation Failure" section about `strategy/timelines/` (lines 385-390)
- [ ] Error handling: Remove invalid mode error message (lines 354-356)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Stages 5, 11, Error Handling section

**Verification**:
- Only one summary template exists (research pattern)
- No references to PLAN/TRACK/REPORT modes in any template
- Error handling section has no mode-specific or timeline-specific entries
- All status references in error handling use "researching" not "planning"

---

### Phase 5: Validation and structural comparison [COMPLETED]

**Goal**: Verify the modified skill-project matches the standard research skill pattern.

**Tasks**:
- [ ] Compare modified SKILL.md structure against skill-market SKILL.md stage-by-stage
- [ ] Verify no residual references to: `timeline`, `planned`, `tracked`, `reported`, `PLAN`, `TRACK`, `REPORT`, `mode_used`, `mode`, `strategy/timelines`
- [ ] Verify preserved elements: `project-agent` name, `forcing_data` pass-through, `skill-project` in postflight marker
- [ ] Verify line count is reasonable (should shrink from ~393 to ~340 lines, similar to skill-market's 337)
- [ ] Run a grep for any remaining deviations from the comparison matrix in the research report

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - Fix any issues found during validation

**Verification**:
- Zero matches for forbidden terms (timeline, planned, tracked, reported, PLAN, TRACK, REPORT as mode values)
- All 11 deviations from research report resolved
- forcing_data mechanism preserved
- project-agent delegation preserved

## Testing & Validation

- [ ] Grep modified SKILL.md for any residual mode/timeline references
- [ ] Structural comparison: each stage heading matches skill-market's stage headings
- [ ] Status values match the comparison matrix "project (target)" column from research report
- [ ] Artifact type filter uses "research" throughout
- [ ] Commit message format matches "complete research" pattern
- [ ] delegation_depth is 1
- [ ] Error handling has no mode-specific cases

## Artifacts & Outputs

- Modified file: `.claude/extensions/founder/skills/skill-project/SKILL.md`
- This plan: `specs/263_skill_project_research_workflow/plans/01_skill-project-workflow.md`

## Rollback/Contingency

The change is confined to a single file. Rollback via `git checkout HEAD -- .claude/extensions/founder/skills/skill-project/SKILL.md`. Since the file is under version control, any partial or incorrect edit can be fully reverted.
