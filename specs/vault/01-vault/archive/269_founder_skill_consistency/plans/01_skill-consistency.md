# Implementation Plan: Normalize Skill Consistency Across Founder Extension

- **Task**: 269 - Normalize skill consistency across founder extension
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Task #263
- **Research Inputs**: specs/269_founder_skill_consistency/reports/01_meta-research.md
- **Artifacts**: plans/01_skill-consistency.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Normalize skill-founder-plan and skill-founder-implement to match the pattern established by the 5 research skills (skill-market, skill-analyze, skill-strategy, skill-legal, skill-project). The research report identified 4 inconsistencies: return format (JSON vs text), postflight marker format (string vs JSON object), cleanup completeness (missing file removals), and allowed-tools mismatch (Task-only vs full toolset). All changes are confined to 2 SKILL.md files.

### Research Integration

The research report (01_meta-research.md) identified 5 inconsistencies across the 7 founder skills. Item 4 (delegation_depth) is deferred since depth 2 may be intentionally correct for skills invoked via an orchestrator adding a delegation level. The remaining 4 items are addressed in this plan.

## Goals and Non-Goals

**Goals**:
- Align return format in skill-founder-plan and skill-founder-implement to use brief text summaries instead of JSON
- Align postflight marker creation to write full JSON objects matching the research skill pattern
- Add cleanup of `.return-meta.json` and `.postflight-loop-guard` to both skills
- Add Bash, Edit, Read, Write to allowed-tools in both skills

**Non-Goals**:
- Changing delegation_depth (requires verification of orchestrator invocation patterns)
- Modifying agent files (agents already return text; the mismatch is only in skill documentation)
- Changing research skills (they are the reference pattern)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plan/implement skills need Task-only for delegation isolation | M | L | Verify research skills work correctly with full toolset before applying |
| Return format change breaks command-layer parsing | M | L | Commands read metadata file, not skill return text; text return is for human display only |
| Missing a cleanup file causes stale markers | L | L | Compare cleanup lists side-by-side during implementation |

## Implementation Phases

### Phase 1: Update skill-founder-plan SKILL.md [COMPLETED]

**Goal**: Align skill-founder-plan with the research skill pattern across all 4 inconsistency areas.

**Tasks**:
- [ ] Update frontmatter `allowed-tools` from `Task` to `Task, Bash, Edit, Read, Write`
- [ ] Update Stage 3 (Create Postflight Marker) to write full JSON object instead of plain session_id string. Match skill-market pattern: `{ session_id, skill_name, task_number, operation, reason, created }`
- [ ] Update Stage 9 (Cleanup and Return) to remove `.return-meta.json` and `.postflight-loop-guard` in addition to `.postflight-pending`
- [ ] Update Return Format section to show brief text summary instead of JSON object. Add a Stage 11-style text template matching the research skill pattern
- [ ] Verify the skill file reads coherently after all edits

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md` - All 4 pattern alignments

**Verification**:
- Frontmatter `allowed-tools` line matches research skills
- Stage 3 marker content is a JSON object with 6 fields
- Stage 9 cleanup removes 3 files (`.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json`)
- Return Format section shows text template, not JSON

---

### Phase 2: Update skill-founder-implement SKILL.md [COMPLETED]

**Goal**: Align skill-founder-implement with the research skill pattern across all 4 inconsistency areas.

**Tasks**:
- [ ] Update frontmatter `allowed-tools` from `Task` to `Task, Bash, Edit, Read, Write`
- [ ] Update Stage 3 (Create Postflight Marker) to write full JSON object instead of plain session_id string. Match skill-market pattern: `{ session_id, skill_name, task_number, operation, reason, created }`
- [ ] Update Stage 9 (Cleanup and Return) to remove `.return-meta.json` and `.postflight-loop-guard` in addition to `.postflight-pending`
- [ ] Update Return Format section to show brief text summary instead of JSON object. Replace the 3 JSON examples (success with typst, success without typst, partial) with equivalent text templates
- [ ] Verify the skill file reads coherently after all edits

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - All 4 pattern alignments

**Verification**:
- Frontmatter `allowed-tools` line matches research skills
- Stage 3 marker content is a JSON object with 6 fields
- Stage 9 cleanup removes 3 files
- Return Format section shows text templates for success, success-without-typst, and partial cases

## Testing and Validation

- [ ] Diff each modified skill against skill-market to confirm pattern alignment on: frontmatter, marker format, cleanup list, return format
- [ ] Verify no references to JSON return format remain in the modified skills (except for metadata file format which is correctly JSON)
- [ ] Confirm stage numbering remains sequential and consistent in both files

## Artifacts and Outputs

- Modified: `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- Modified: `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`

## Rollback/Contingency

Both files are under git version control. If changes cause issues, revert with:
```bash
git checkout HEAD -- .claude/extensions/founder/skills/skill-founder-plan/SKILL.md
git checkout HEAD -- .claude/extensions/founder/skills/skill-founder-implement/SKILL.md
```
