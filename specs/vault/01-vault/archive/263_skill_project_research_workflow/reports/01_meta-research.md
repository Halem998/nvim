# Research Report: Task #263

**Task**: 263 - Update skill-project for research-only lifecycle
**Started**: 2026-03-24T00:00:00Z
**Completed**: 2026-03-24T00:00:00Z
**Effort**: Small (1-2 hours)
**Dependencies**: Task #262 (project-agent refactor to produce research report)
**Sources/Inputs**: Codebase analysis of all 5 founder research skills
**Artifacts**: specs/263_skill_project_research_workflow/reports/01_meta-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-project is the only founder research skill that deviates from the standard research lifecycle
- All 4 other research skills (skill-market, skill-analyze, skill-strategy, skill-legal) share an identical lifecycle pattern
- The required changes are mechanical: replace status values, artifact types, commit messages, and remove mode branching
- skill-market serves as the canonical template -- every stage can be mapped 1:1

## Context and Scope

### What Was Researched

A line-by-line comparison of skill-project against the 4 standard research skills to identify every deviation from the research lifecycle pattern. The goal is to produce a precise change specification that eliminates all divergence.

### Constraints

- skill-project must continue delegating to `project-agent` (agent name unchanged)
- The `forcing_data` pass-through mechanism is preserved (project-specific fields)
- The `mode` parameter (PLAN/TRACK/REPORT) and its branching are removed entirely
- Task #262 must land first (project-agent produces research reports, not timelines)

## Findings

### Standard Research Skill Pattern

All 4 conforming skills (market, analyze, strategy, legal) share this exact lifecycle:

| Stage | Action | Value |
|-------|--------|-------|
| Stage 2 (Preflight) | state.json status | `"researching"` |
| Stage 2 (Preflight) | TODO.md marker | `[RESEARCHING]` |
| Stage 3 (Marker) | operation field | `"research"` |
| Stage 4 (Delegation) | delegation_depth | `1` |
| Stage 7 (Postflight) | state.json status | `"researched"` |
| Stage 7 (Postflight) | TODO.md marker | `[RESEARCHED]` |
| Stage 8 (Artifacts) | type filter | `"research"` |
| Stage 8 (Artifacts) | TODO.md link | Research artifact link |
| Stage 9 (Commit) | message | `"complete research"` |
| Stage 10 (Cleanup) | files removed | `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json` |
| Stage 11 (Summary) | next step | `"Next: Run /plan {N} to create implementation plan"` |

### Current skill-project Deviations

Every deviation from the standard pattern is listed below with its location in the current SKILL.md:

#### Deviation 1: Preflight status (Stage 2, line 98)
- **Current**: `status: "planning"`, marker: `[PLANNING]`
- **Target**: `status: "researching"`, marker: `[RESEARCHING]`
- **Impact**: Sets wrong status, blocks proper research-to-plan lifecycle

#### Deviation 2: Postflight marker operation field (Stage 3, line 128)
- **Current**: `"operation": "project"`
- **Target**: `"operation": "research"`
- **Impact**: Cosmetic, but inconsistent with other research skills

#### Deviation 3: Delegation depth (Stage 4, line 159)
- **Current**: `"delegation_depth": 2`
- **Target**: `"delegation_depth": 1`
- **Impact**: All research skills use depth 1; depth 2 is reserved for nested delegations

#### Deviation 4: Mode-dependent postflight status (Stage 7, lines 215-237)
- **Current**: Mode-dependent branching maps PLAN/TRACK/REPORT to `planned`/`tracked`/`reported` with `[PLANNED]`/`[TRACKED]`/`[REPORTED]` markers
- **Target**: Single path: `status: "researched"`, marker: `[RESEARCHED]`
- **Impact**: Largest structural change -- entire case statement and mode-specific logic removed

#### Deviation 5: Artifact type filter (Stage 8, lines 248-260)
- **Current**: Filters on `type == "timeline"`, links timeline artifacts
- **Target**: Filters on `type == "research"`, links research artifacts
- **Impact**: Artifact linking uses wrong type identifier

#### Deviation 6: Artifact path handling (Stage 8, line 265)
- **Current**: Special note about not stripping `specs/` prefix for `strategy/timelines/` paths
- **Target**: Standard `specs/` prefix stripping (research reports live in `specs/{NNN}_{SLUG}/reports/`)
- **Impact**: Remove the special-case note; standard path handling applies

#### Deviation 7: Commit message (Stage 9, line 275)
- **Current**: `"complete project ${mode_used,,}"` (e.g., "complete project plan")
- **Target**: `"complete research"`
- **Impact**: Non-standard commit message format

#### Deviation 8: Mode input validation (Stage 1, lines 86-91)
- **Current**: Validates `mode` parameter (PLAN/TRACK/REPORT)
- **Target**: Remove mode validation entirely
- **Impact**: Mode concept no longer applies to this skill

#### Deviation 9: Return summary (Stage 11, lines 296-332)
- **Current**: Three mode-specific summary templates (PLAN, TRACK, REPORT)
- **Target**: Single research completion summary matching market/analyze/strategy/legal pattern
- **Impact**: Simplification from 3 templates to 1

#### Deviation 10: Error handling - mode-specific errors (lines 364-376)
- **Current**: Includes "No Existing Timeline (TRACK/REPORT modes)" and mode-specific error cases
- **Target**: Remove mode-specific error handling; keep standard research error patterns
- **Impact**: Simplification of error section

#### Deviation 11: Metadata file missing recovery (line 362)
- **Current**: Keeps status as `"planning"` for resume
- **Target**: Keep status as `"researching"` for resume
- **Impact**: Correct resume status

### Detailed Change Specification

Below is every text replacement needed, organized by stage. Using skill-market as the template.

#### Stage 1: Input Validation

**Remove** the mode parameter validation block (lines 86-91):
```
# Remove this block entirely:
# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    PLAN|TRACK|REPORT) ;;
    *) return error "Invalid mode: $mode. Must be PLAN, TRACK, or REPORT" ;;
  esac
fi
```

**Remove** from validated inputs list: `- mode - Optional, one of: PLAN, TRACK, REPORT`

#### Stage 2: Preflight Status Update

**Replace** `"planning"` with `"researching"` in state.json update.
**Replace** `[PLANNING]` with `[RESEARCHING]` in TODO.md update instruction.

#### Stage 3: Create Postflight Marker

**Replace** `"operation": "project"` with `"operation": "research"`.

#### Stage 4: Prepare Delegation Context

**Replace** `"delegation_depth": 2` with `"delegation_depth": 1`.
**Remove** `"mode": "PLAN|TRACK|REPORT or null"` from delegation context.
**Keep** `forcing_data` pass-through (project-specific fields remain valid for the agent).

#### Stage 5: Invoke Agent

No changes needed. Agent name remains `project-agent`. Description can be updated to reflect research focus.

#### Stage 6: Parse Subagent Return

**Remove** `mode_used` extraction: `mode_used=$(jq -r '.metadata.mode // ""' "$metadata_file")`
The rest of the parsing remains identical.

#### Stage 7: Update Task Status (Postflight)

**Replace** entire mode-dependent case statement with single-path update:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Replace** TODO.md instruction to change marker to `[RESEARCHED]`.

#### Stage 8: Link Artifacts

**Replace** `type == "timeline"` with `type == "research"` in the filter step.
**Replace** comment "Add new timeline artifact" with "Add new research artifact".
**Replace** TODO.md instruction from "Add timeline artifact link" to "Add research artifact link".
**Remove** the special note about not stripping `specs/` prefix for `strategy/timelines/` paths.
**Add** standard `specs/` prefix stripping note: `todo_link_path="${artifact_path#specs/}"`.

#### Stage 9: Git Commit

**Replace** commit message:
```bash
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

#### Stage 10: Cleanup

Already matches the standard pattern (all 3 files cleaned). No changes needed.

#### Stage 11: Return Brief Summary

**Replace** all three mode-specific templates with single research template:
```
Project research completed for task {N}:
- {questions_asked} forcing questions completed
- Project: {project_name}
- Research report: specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
- Next: Run /plan {N} to create implementation plan
```

#### Error Handling Section

**Remove** "No Existing Timeline (TRACK/REPORT modes)" error case.
**Replace** "planning" with "researching" in metadata file missing recovery.
**Remove** "User Abandonment" section referencing keeping status as "planning".
**Add** standard "User Abandonment" returning partial status with "researching" for resume.
**Remove** "Directory Creation Failure" section (no more `strategy/timelines/` directory).

#### Skill Description and Header

**Replace** frontmatter description: `"Project timeline management with WBS, PERT estimation, and resource allocation"` with `"Project research with scope analysis and timeline estimation"` (or similar research-focused description).
**Replace** header description: `"Thin wrapper that routes project timeline requests"` with `"Thin wrapper that routes project research requests"`.

### File Affected

Single file: `.claude/extensions/founder/skills/skill-project/SKILL.md`

## Decisions

- **Use skill-market as canonical template**: All 4 research skills are identical in lifecycle structure. skill-market was chosen as the reference because it was explicitly cited in the task description and is the most-documented.
- **Keep forcing_data pass-through**: The project-specific forcing_data fields (project_name, target_date, stakeholders) remain valid for the agent's research phase. The agent uses these to scope its investigation.
- **Remove mode entirely**: The PLAN/TRACK/REPORT modes are timeline-specific operations that belong in the implementation phase, not the research phase. The agent will be refactored separately (task #262).
- **delegation_depth: 1**: Research skills use depth 1 because they are the first and only delegation hop. Depth 2 was incorrect.

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Task #262 not complete when this lands | Medium | Verify project-agent already produces research reports before merging. If not, this skill change is safe to land first (agent output format is independent of skill lifecycle). |
| Existing tasks in `planned`/`tracked`/`reported` status | Low | These are founder extension tasks with short lifecycles. Any in-flight tasks should be completed or abandoned before this change. |
| Trigger conditions reference timeline concepts | Low | The trigger conditions section mentions WBS, PERT, Gantt -- these may need updating if the agent's research scope changes. Not blocking for this task. |

## Appendix

### Comparison Matrix: All 5 Founder Research Skills

| Property | market | analyze | strategy | legal | project (current) | project (target) |
|----------|--------|---------|----------|-------|--------------------|-------------------|
| Preflight status | researching | researching | researching | researching | planning | researching |
| TODO marker (pre) | RESEARCHING | RESEARCHING | RESEARCHING | RESEARCHING | PLANNING | RESEARCHING |
| delegation_depth | 1 | 1 | 1 | 1 | 2 | 1 |
| operation field | research | research | research | research | project | research |
| Postflight status | researched | researched | researched | researched | planned/tracked/reported | researched |
| TODO marker (post) | RESEARCHED | RESEARCHED | RESEARCHED | RESEARCHED | PLANNED/TRACKED/REPORTED | RESEARCHED |
| Artifact filter type | research | research | research | research | timeline | research |
| Commit message | complete research | complete research | complete research | complete research | complete project {mode} | complete research |
| Mode branching | no | no | no | no | yes (3 modes) | no |
| Cleanup files | 3 | 3 | 3 | 3 | 3 | 3 |

### Files Examined

- `.claude/extensions/founder/skills/skill-project/SKILL.md` (393 lines)
- `.claude/extensions/founder/skills/skill-market/SKILL.md` (337 lines) -- canonical template
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md` -- pattern confirmation
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md` -- pattern confirmation
- `.claude/extensions/founder/skills/skill-legal/SKILL.md` -- pattern confirmation
