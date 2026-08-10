# Implementation Plan: Persist description in task creation flows

- **Task**: 692 - Persist description in task creation flows
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/692_persist_description_in_task_creation_flows/reports/01_research-description-persistence.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `description` and `title` fields to the state.json jq templates in 5 task creation flows that currently omit them. The downstream consumer (`generate-todo.sh`) already reads and renders both fields -- the only work needed is adding the fields at the point of creation. Each of the 5 affected source files has an identical copy under `.claude/extensions/core/` that must be edited in sync, totaling 10 file edits. The reference pattern is `commands/task.md` --review mode (step 8, lines 604-620), which already includes `"description": $desc`.

### Research Integration

Research report `01_research-description-persistence.md` confirmed:
- `generate-todo.sh` is already complete -- no changes needed
- `skill-spawn` already includes `"description": $desc` -- no changes needed
- 5 gaps exist across 4 files (task.md has 2 gaps: Create Task and Expand Mode)
- The `--arg` jq flag safely handles multiline strings and quotes
- The --review mode pattern in task.md is the gold standard reference

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It is an internal quality fix for the agent system's state management.

## Goals & Non-Goals

**Goals**:
- Every task creation flow persists `description` and `title` to state.json
- TODO.md entries display descriptions for all newly created tasks
- Extension copies remain in sync with their main file counterparts

**Non-Goals**:
- Backfilling descriptions for existing tasks in state.json
- Modifying `generate-todo.sh` (already complete)
- Changing the description format or adding new fields beyond `description` and `title`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq variable injection with special characters in descriptions | M | L | Use `--arg` (not `--argjson`); `--arg` handles multiline/quotes safely |
| Forgetting to sync extension copy | M | M | Plan lists both paths explicitly for every edit; verification step checks both |
| Meta-builder agent description variable not available at write time | M | L | Research confirmed `task_list[].title` and `task_list[].description` are populated during interview (Stage 3A) |
| Expand Mode subtask descriptions not yet computed | M | L | Each subtask description should be derived from parent analysis (step 2) and passed per-subtask |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |
| 4 | 4 | 1 |

Phases within the same wave can execute in parallel (Phases 2 and 3 share Wave 2-3 but are independent; listed separately for clarity since each touches different files).

---

### Phase 1: Fix commands/task.md (Create Task + Expand Mode) [COMPLETED]

**Goal**: Add `description` and `title` fields to both the Create Task (step 6) and Expand Mode (step 3) jq templates in `commands/task.md`, then sync the extension copy.

**Tasks**:
- [ ] In `.claude/commands/task.md` step 6 (lines 161-174): add `--arg desc "$improved_desc"` to the jq arguments and add `"description": $desc, "title": $desc,` to the template object (before `"created"`)
- [ ] In `.claude/commands/task.md` step 3 / Expand Mode (lines 299-307): update the instruction text to explicitly state that each subtask jq entry must include `"description": $subtask_desc, "title": $subtask_desc,` fields, where `$subtask_desc` is the subtask's description derived from the parent task analysis
- [ ] Copy the exact same changes to `.claude/extensions/core/commands/task.md`
- [ ] Verify both files are identical after editing: `diff .claude/commands/task.md .claude/extensions/core/commands/task.md`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Add description/title to Create Task step 6 jq template and Expand Mode step 3 instructions
- `.claude/extensions/core/commands/task.md` - Mirror the same changes

**Verification**:
- `grep -n '"description"' .claude/commands/task.md` shows matches at step 6, step 3 (Expand), and step 8 (--review, already existing)
- `diff .claude/commands/task.md .claude/extensions/core/commands/task.md` returns no output

---

### Phase 2: Fix agents/meta-builder-agent.md Stage 6 [COMPLETED]

**Goal**: Add `title` and `description` fields to the state.json entry template in the meta-builder-agent's CreateTasks stage.

**Tasks**:
- [ ] In `.claude/agents/meta-builder-agent.md` Stage 6 (lines 689-700): add `"title": "{task.title}"` and `"description": "{task.description}"` to the JSON template, and add corresponding `--arg title "$task_title"` and `--arg desc "$task_description"` to the bash jq call instruction
- [ ] Copy the exact same changes to `.claude/extensions/core/agents/meta-builder-agent.md`
- [ ] Verify both files are identical: `diff .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md`

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Add title/description to Stage 6 state.json entry template
- `.claude/extensions/core/agents/meta-builder-agent.md` - Mirror the same changes

**Verification**:
- `grep -n '"description"' .claude/agents/meta-builder-agent.md` shows a match in Stage 6
- `diff .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md` returns no output

---

### Phase 3: Fix skills/skill-fix-it/SKILL.md step 9.1 [COMPLETED]

**Goal**: Add `title` and `description` fields to both jq templates (with-dependency and without-dependency) in skill-fix-it's state.json write step.

**Tasks**:
- [ ] In `.claude/skills/skill-fix-it/SKILL.md` step 9.1 (lines 487-508): add `"title": "{title}"` and `"description": "{description}"` to the "with dependency" JSON template (lines 489-497)
- [ ] Add the same `"title"` and `"description"` fields to the "all other tasks" JSON template (lines 500-507)
- [ ] Add instruction text noting `--arg title "$title"` and `--arg desc "$description"` must be passed to the jq call
- [ ] Copy the exact same changes to `.claude/extensions/core/skills/skill-fix-it/SKILL.md`
- [ ] Verify both files are identical: `diff .claude/skills/skill-fix-it/SKILL.md .claude/extensions/core/skills/skill-fix-it/SKILL.md`

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-fix-it/SKILL.md` - Add title/description to both JSON templates in step 9.1
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` - Mirror the same changes

**Verification**:
- `grep -n '"description"' .claude/skills/skill-fix-it/SKILL.md` shows matches in step 9.1
- `diff .claude/skills/skill-fix-it/SKILL.md .claude/extensions/core/skills/skill-fix-it/SKILL.md` returns no output

---

### Phase 4: Fix skills/skill-project-overview/SKILL.md step 5.3 [COMPLETED]

**Goal**: Add static `title` and `description` fields to the project-overview task creation template.

**Tasks**:
- [ ] In `.claude/skills/skill-project-overview/SKILL.md` step 5.3 (lines 392-404): add `"title": "Generate project-overview.md"` and `"description": "Generate .claude/context/repo/project-overview.md from repository scan findings and user interview"` as static strings in the jq template object (before `"next_artifact_number"`)
- [ ] Copy the exact same changes to `.claude/extensions/core/skills/skill-project-overview/SKILL.md`
- [ ] Verify both files are identical: `diff .claude/skills/skill-project-overview/SKILL.md .claude/extensions/core/skills/skill-project-overview/SKILL.md`

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-project-overview/SKILL.md` - Add static title/description to step 5.3 jq template
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` - Mirror the same changes

**Verification**:
- `grep -n '"description"' .claude/skills/skill-project-overview/SKILL.md` shows a match in step 5.3
- `diff .claude/skills/skill-project-overview/SKILL.md .claude/extensions/core/skills/skill-project-overview/SKILL.md` returns no output

---

## Testing & Validation

- [ ] All 5 main files contain `"description"` in their jq templates: `grep -l '"description"' .claude/commands/task.md .claude/agents/meta-builder-agent.md .claude/skills/skill-fix-it/SKILL.md .claude/skills/skill-project-overview/SKILL.md`
- [ ] All 5 extension copies are identical to their main counterparts: `diff .claude/commands/task.md .claude/extensions/core/commands/task.md && diff .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md && diff .claude/skills/skill-fix-it/SKILL.md .claude/extensions/core/skills/skill-fix-it/SKILL.md && diff .claude/skills/skill-project-overview/SKILL.md .claude/extensions/core/skills/skill-project-overview/SKILL.md`
- [ ] Create a test task via `/task "test description persistence"` and verify state.json contains `description` and `title` fields for the new entry
- [ ] Verify `generate-todo.sh` renders the description in TODO.md for the test task

## Artifacts & Outputs

- `specs/692_persist_description_in_task_creation_flows/plans/01_implementation-plan.md` (this file)
- `specs/692_persist_description_in_task_creation_flows/summaries/01_execution-summary.md` (post-implementation)
- 5 modified main files under `.claude/`
- 5 modified extension copies under `.claude/extensions/core/`

## Rollback/Contingency

All changes are additive (adding new fields to existing JSON templates). Rollback by reverting the commit. The added fields are optional in state.json -- `generate-todo.sh` already handles missing `description`/`title` gracefully via `// ""` fallback. No data loss risk.
