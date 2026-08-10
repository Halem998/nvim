# Research Report: Task #516

**Task**: 516 - Remove claudemd_suggestions feature from /todo and implementation pipeline
**Started**: 2026-05-02T22:00:00Z
**Completed**: 2026-05-02T22:15:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase grep for `claudemd_suggestions` across all files
- `.claude/skills/skill-implementer/SKILL.md` (lines 293, 343-348)
- `.claude/commands/todo.md` (lines 151, 261-341, 390-431, 719-854, 1096-1127, 1247-1267)
- `.claude/agents/general-implementation-agent.md` (lines 151-176, 214)
- `.claude/context/reference/state-management-schema.md` (lines 29, 166, 411)
- `.claude/context/formats/return-metadata-file.md` (lines 152, 156, 416)
- `.claude/extensions/core/merge-sources/claudemd.md` (line 134)
- `.claude/docs/templates/agent-template.md` (line 59)
- `.claude/skills/skill-team-implement/SKILL.md` (line 534)
- `.claude/CLAUDE.md` (line 146, auto-generated)
**Artifacts**: - specs/516_remove_claudemd_suggestions_feature/reports/01_claudemd-suggestions-removal.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `claudemd_suggestions` feature spans 15 active files across `.claude/` (plus mirrored copies in `.opencode/` and `.claude/extensions/core/`)
- The feature touches 4 major system components: implementation agent, skill-implementer postflight, /todo command, and schema documentation
- Historical data in `specs/archive/state.json` and `state.json/state.json` contains ~200+ `claudemd_suggestions` field values on archived tasks -- these are read-only data and should NOT be modified
- The `completion_summary` and `roadmap_items` fields must be preserved in all locations where they coexist with `claudemd_suggestions`
- Meta task completion workflow needs simplification: meta tasks should use only `completion_summary` (same as non-meta tasks)

## Context & Scope

CLAUDE.md is now auto-generated from merge-sources via the extension loader. The previous pattern where meta tasks proposed CLAUDE.md edits via `claudemd_suggestions` (collected during `/implement` postflight and applied interactively during `/todo`) is obsolete. This research identifies every file requiring modification and the exact content to remove or update.

Files in `.opencode/` and `.claude/extensions/core/` mirror the `.claude/` files and need parallel changes. Archive files (specs/archive/) are historical and should not be modified.

## Findings

### Category 1: Skill-Implementer Postflight (SKILL.md)

**File**: `.claude/skills/skill-implementer/SKILL.md`

1. **Line 293** - Extraction of `claudemd_suggestions` from metadata file:
   - `claudemd_suggestions=$(jq -r '.completion_data.claudemd_suggestions // ""' "$metadata_file")`
   - **Action**: Remove this line entirely

2. **Lines 343-348** - Step 3 meta task handling block:
   ```
   # For meta tasks: add claudemd_suggestions
   if [ "$task_type" = "meta" ] && [ -n "$claudemd_suggestions" ]; then
       jq --arg suggestions "$claudemd_suggestions" \
         '(.active_projects[] | select(.project_number == '$task_number')).claudemd_suggestions = $suggestions' \
         specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   fi
   ```
   - **Action**: Remove this entire block. Keep the non-meta roadmap_items block (lines 350-355) and rename the step header from "Step 3: Add task-type-specific completion fields" to reflect only roadmap_items

**Mirrored in**:
- `.opencode/skills/skill-implementer/SKILL.md` (same lines)
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` (same lines)
- `.opencode/extensions/core/skills/skill-implementer/SKILL.md` (same lines)

### Category 2: /todo Command

**File**: `.claude/commands/todo.md`

1. **Line 151** - Meta task exclusion note:
   - `**IMPORTANT**: Meta tasks (task_type: "meta") are excluded from ROADMAP.md matching. They use claudemd_suggestions instead (see Step 3.6).`
   - **Action**: Remove this note. Meta tasks should now participate in ROADMAP.md matching (or continue to be excluded, but the claudemd_suggestions reference must go). Decision needed: should meta tasks now use roadmap_items? Recommend: remove the exclusion entirely -- meta tasks should use completion_summary for roadmap matching like all other tasks.

2. **Lines 261-341** - Entire Step 3.6 "Scan Meta Tasks for CLAUDE.md Suggestions":
   - **Action**: Remove entirely. This includes Step 3.6.1 (extraction loop), counter tracking, and the tracking variables list.

3. **Lines 390-431** - Dry-run output "CLAUDE.md suggestions" section:
   - **Action**: Remove the entire "CLAUDE.md suggestions (from meta tasks)" dry-run output block and the conditional note at lines 428-431.

4. **Lines 719-854** - Step 5.6 "Interactive CLAUDE.md Suggestion Selection for Meta Tasks":
   - **Action**: Remove entirely. This includes Steps 5.6.1 through 5.6.5.

5. **Lines 1096-1098** - Output section CLAUDE.md line:
   ```
   {If CLAUDE.md suggestions:}
   CLAUDE.md: {applied}/{total} suggestions applied
   ```
   - **Action**: Remove these lines.

6. **Line 1114** - Section inclusion rules table:
   - `| CLAUDE.md | claudemd_suggestions processed |`
   - **Action**: Remove this row.

7. **Lines 1116-1127** - Conditional output rules for CLAUDE.md suggestions:
   - **Action**: Remove all four conditional blocks about CLAUDE.md suggestions.

8. **Lines 1247-1267** - Appendix section "Interactive CLAUDE.md Application":
   - **Action**: Remove entire subsection.

**Mirrored in**:
- `.opencode/commands/todo.md` (same structure, uses "AGENTS.md" instead of "CLAUDE.md")
- `.claude/extensions/core/commands/todo.md` (same lines)
- `.opencode/extensions/core/commands/todo.md` (same structure)

### Category 3: General Implementation Agent

**File**: `.claude/agents/general-implementation-agent.md`

1. **Lines 151-176** - Stage 6a completion_data generation:
   - **Lines 151-156**: "For META tasks only" section with claudemd_suggestions generation instructions
   - **Lines 163-176**: Example JSON blocks showing claudemd_suggestions
   - **Action**: Remove the META-specific step 3, remove the two meta task example blocks. Keep `completion_summary` (step 1) and the non-meta `roadmap_items` (step 2). Renumber remaining steps.

2. **Line 214** - Stage 7 metadata file description:
   - `...claudemd_suggestions (meta) or roadmap_items (non-meta)...`
   - **Action**: Simplify to mention only `completion_summary` (all tasks) and `roadmap_items` (optional, non-meta).

**Mirrored in**:
- `.opencode/agent/subagents/general-implementation-agent.md`
- `.claude/extensions/core/agents/general-implementation-agent.md`
- `.opencode/extensions/core/agents/general-implementation-agent.md`

### Category 4: Schema Documentation

**File**: `.claude/context/reference/state-management-schema.md`

1. **Line 29** - JSON example field:
   - `"claudemd_suggestions": "Description of .claude/ changes (meta tasks only)"`
   - **Action**: Remove this line from the example JSON block.

2. **Line 166** - Completion Fields table row:
   - `| claudemd_suggestions | string | Yes (meta only) | .claude/ changes made, or "none" |`
   - **Action**: Remove this table row.

3. **Line 411** - Example completed meta task:
   - `"claudemd_suggestions": "Added merge.md command, updated CLAUDE.md command reference"`
   - **Action**: Remove this field from the example JSON block.

**Mirrored in**:
- `.opencode/context/reference/state-management-schema.md`
- `.opencode/context/core/reference/state-management-schema.md`
- `.claude/extensions/core/context/reference/state-management-schema.md`

### Category 5: Return Metadata File Format

**File**: `.claude/context/formats/return-metadata-file.md`

1. **Line 152** - completion_data table row:
   - `| claudemd_suggestions | string | Yes (meta only) | Description of .claude/ changes made, or "none" if no .claude/ files modified |`
   - **Action**: Remove this table row.

2. **Lines 155-156** - Notes about claudemd_suggestions:
   - `- claudemd_suggestions is mandatory for meta tasks (language: "meta")`
   - **Action**: Remove this bullet.

3. **Line 416** - Meta task note:
   - `For other scenarios (meta tasks, blocked), combine the schema fields above. Meta tasks add claudemd_suggestions to completion_data.`
   - **Action**: Simplify to remove the claudemd_suggestions reference.

**Mirrored in**:
- `.opencode/context/formats/return-metadata-file.md`
- `.claude/extensions/core/context/formats/return-metadata-file.md`
- `.opencode/extensions/core/context/formats/return-metadata-file.md`

### Category 6: CLAUDE.md Merge Source

**File**: `.claude/extensions/core/merge-sources/claudemd.md`

1. **Line 134** - Completion Workflow bullet:
   - `- Meta tasks: completion_summary + claudemd_suggestions -> /todo displays for user review`
   - **Action**: Change to: `- Meta tasks: completion_summary -> /todo archives (same as non-meta)` or simply remove the meta-specific bullet.

Note: `.claude/CLAUDE.md` (line 146) is auto-generated from this merge source and will be regenerated automatically.

### Category 7: Agent Template

**File**: `.claude/docs/templates/agent-template.md`

1. **Line 59**:
   - `- completion_data: object with completion_summary (1-3 sentences). For meta tasks, also include claudemd_suggestions.`
   - **Action**: Remove the "For meta tasks, also include claudemd_suggestions." clause.

**Mirrored in**:
- `.opencode/docs/templates/agent-template.md`
- `.claude/extensions/core/docs/templates/agent-template.md`
- `.opencode/extensions/core/docs/templates/agent-template.md`

### Category 8: Team Implement Skill

**File**: `.claude/skills/skill-team-implement/SKILL.md`

1. **Line 534** - Return format JSON:
   - `"claudemd_suggestions": "Changes to .claude/ (meta tasks) or 'none'"`
   - **Action**: Remove this line from the completion_data example.

**Mirrored in**:
- `.opencode/skills/skill-team-implement/SKILL.md`
- `.claude/extensions/core/skills/skill-team-implement/SKILL.md`
- `.opencode/extensions/core/skills/skill-team-implement/SKILL.md`

### Category 9: Historical/Archive Data (NO ACTION)

The following contain `claudemd_suggestions` but should NOT be modified:
- `specs/archive/state.json` (~200 field values on archived tasks)
- `state.json/state.json` and `state.json/tmp/state.json` (archived state snapshots)
- `state.json/tasks_to_archive.json` (archive buffer)
- `specs/archive/*/reports/*.md` and `specs/archive/*/plans/*.md` (historical research/plans)
- `specs/archive/*/summaries/*.md` (historical summaries)
- `specs/OC_504_*/summaries/*.md` (completed OpenCode task)
- `specs/state.json` line 92 (task 516 itself, `project_name` field -- not the feature field)

### Category 10: Active state.json Entries (CLEAN UP)

**File**: `state.json/state.json`

Active task entries in `state.json/state.json` have `claudemd_suggestions` fields from past completed tasks. Since these are in the archived state.json directory (not `specs/state.json`), they should not be modified.

**File**: `specs/state.json`

The active `specs/state.json` should have its schema updated to no longer expect `claudemd_suggestions`. When existing completed tasks with this field are archived via `/todo`, the field will naturally move to `specs/archive/state.json`. No immediate cleanup of existing data fields is needed -- they are harmless extra fields.

## Decisions

1. **Meta tasks and ROADMAP.md**: After removing `claudemd_suggestions`, meta tasks should still be excluded from ROADMAP.md matching (they rarely have roadmap-relevant outcomes). The exclusion note should be updated to simply state "Meta tasks are excluded from ROADMAP.md matching" without referencing claudemd_suggestions.
2. **Archive data**: Historical `claudemd_suggestions` values in archived state.json and task artifacts are left as-is. They are read-only historical records.
3. **Existing state.json entries**: Completed tasks in `specs/state.json` that have `claudemd_suggestions` fields are left alone. The field is harmless and will be archived naturally.
4. **.opencode/ mirrors**: All changes to `.claude/` files must be mirrored in their `.opencode/` counterparts and `.claude/extensions/core/` copies.

## Risks & Mitigations

- **Risk**: Missing a reference causes runtime errors in /todo or skill-implementer
  - **Mitigation**: Comprehensive grep found all references; implementation should re-verify with grep after changes
- **Risk**: .opencode/ mirrors fall out of sync
  - **Mitigation**: Implementation plan should handle all mirror files in the same phase
- **Risk**: CLAUDE.md auto-generation breaks if merge-source still references claudemd_suggestions
  - **Mitigation**: Update merge-source first, then regenerate

## Appendix

### Files Requiring Active Modification (15 primary + mirrors)

| # | File | Mirror Count | Change Type |
|---|------|-------------|-------------|
| 1 | `.claude/skills/skill-implementer/SKILL.md` | 3 | Remove extraction + jq block |
| 2 | `.claude/commands/todo.md` | 3 | Remove Steps 3.6, 5.6, dry-run section, output sections, appendix |
| 3 | `.claude/agents/general-implementation-agent.md` | 3 | Remove meta-specific completion_data instructions |
| 4 | `.claude/context/reference/state-management-schema.md` | 3 | Remove field from schema, table, examples |
| 5 | `.claude/context/formats/return-metadata-file.md` | 3 | Remove field from table and notes |
| 6 | `.claude/extensions/core/merge-sources/claudemd.md` | 0 | Update completion workflow bullet |
| 7 | `.claude/docs/templates/agent-template.md` | 3 | Remove meta task clause |
| 8 | `.claude/skills/skill-team-implement/SKILL.md` | 3 | Remove field from JSON example |

**Total files**: 8 primary files + 19 mirror copies = 27 files to modify

### Search Query Used

```
grep -rn "claudemd_suggestions" /home/benjamin/.config/nvim/
```
