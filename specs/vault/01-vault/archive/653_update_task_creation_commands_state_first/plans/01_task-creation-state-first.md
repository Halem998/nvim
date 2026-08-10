# Implementation Plan: Task #653

- **Task**: 653 - Update all task creation commands to state.json-first pattern
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: Task 649 (pipeline simplification)
- **Research Inputs**: specs/653_update_task_creation_commands_state_first/reports/01_pipeline-audit.md
- **Artifacts**: plans/01_task-creation-state-first.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Migrate all task creation commands, skills, and agents from direct TODO.md editing to the state.json-first pattern established by tasks 648-649. Currently, 8 HIGH-priority writers create entries directly in TODO.md via Edit/sed operations. Since generate-todo.sh regenerates TODO.md from state.json, these direct writes get silently overwritten. The fix for each writer is uniform: remove TODO.md Edit/sed operations, ensure state.json is fully populated, then call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md. Each modified file has a corresponding copy in `.claude/extensions/core/` that must also be updated.

### Research Integration

The pipeline audit report (01_pipeline-audit.md) cataloged 59 total TODO.md writers across 4 categories. This plan addresses the 8 HIGH-priority Category A gaps (task creation writers: G1, G2, G5, G7, G11-G14) plus 3 MEDIUM-priority Category C gaps (archive/vault writers: G21-G23) and 2 MEDIUM-priority command-level field writers (G8-G10). The remaining Category B gaps (K1-K9, K15-K20) are status/artifact field edits that become harmless redundancies under the new pipeline and are deferred to task 651 (documentation cleanup).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace all direct TODO.md task-entry creation (Edit/sed) with state.json writes + generate-todo.sh calls
- Replace direct TODO.md entry removal (Python/sed) in archive-task.sh and vault-operation.sh with generate-todo.sh calls
- Handle the /review goal line feature by adding an active_goal field to state.json and updating generate-todo.sh to render it
- Ensure all extension copies in `.claude/extensions/core/` are updated in sync
- Eliminate the TODO.md frontmatter sed operations (next_project_number) -- generate-todo.sh handles this

**Non-Goals**:
- Updating Category B skill-level Edit instructions (K1-K9 status/artifact edits) -- deferred to task 651
- Modifying generate-todo.sh rendering logic (except for the goal line feature)
- Removing link-artifact-todo.sh or updating artifact linking -- covered by task 649
- Updating plan file status writers -- independent system, covered by task 650

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| generate-todo.sh called before state.json write completes | H | L | Ensure sequential execution: jq write + mv, then generate-todo.sh |
| Extension copies diverge from primary files | M | M | Phase 6 explicitly syncs extension copies; verify with diff |
| Goal line feature requires generate-todo.sh changes | M | L | Phase 2 scopes the change narrowly: one new field, one rendering block |
| Batch task creation in meta-builder-agent calls generate-todo.sh per-task | M | M | Call generate-todo.sh once after all state.json writes, not per-task |
| Sync mode loses bidirectional capability | L | L | Sync becomes state.json-authoritative (one-way regeneration), which aligns with the new architecture |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Update commands/task.md (all 6 modes) [COMPLETED]

**Goal**: Replace all direct TODO.md writes in the /task command with state.json updates followed by a single generate-todo.sh call per mode.

**Tasks**:
- [ ] **Create mode (lines 197-227)**: Remove Part A (sed frontmatter update), remove Part B (Edit task entry insertion), remove Part C (generate-task-order.sh call). Replace all three with a single call: `bash .claude/scripts/generate-todo.sh`. The state.json update in Step 6 already writes the task entry. The generate-todo.sh script handles frontmatter, Task Order, and task entries.
- [ ] **Recover mode (line 295)**: Remove the "Prepend recovered task entry to `## Tasks` section" Edit instruction. The state.json update in the Recover mode jq block (lines 277-281) already adds the task to active_projects. Add `bash .claude/scripts/generate-todo.sh` after the state.json write.
- [ ] **Expand mode (line 336)**: Remove "Also update TODO.md: Change task status to `[EXPANDED]`" Edit instruction. The state.json update (lines 329-334) already sets status to "expanded". Add `bash .claude/scripts/generate-todo.sh` after all subtask state.json writes complete.
- [ ] **Sync mode (lines 340-371)**: Fundamentally simplify. state.json is truth. Remove bidirectional Edit sync logic. Replace with: (a) validate state.json integrity, (b) identify orphan TODO.md tasks not in state.json (warn user), (c) call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md from state.json. Keep topic backfill logic (lines 373-434) unchanged. Remove the generate-task-order.sh call (line 369) since generate-todo.sh handles it.
- [ ] **Review/Followup mode (line 656)**: Remove "Update TODO.md (add entry and update frontmatter)" Edit instruction. The state.json update (lines 638-654) already writes the task. Add `bash .claude/scripts/generate-todo.sh` after all follow-up task state.json writes complete.
- [ ] **Abandon mode (line 744)**: Remove "Remove the task entry" Edit instruction. After the state.json removal (lines 730-742) and directory move, add `bash .claude/scripts/generate-todo.sh`. The task is no longer in active_projects, so generate-todo.sh will not render it.
- [ ] Update the `allowed-tools` frontmatter: remove `Edit(specs/TODO.md)` and `Bash(sed:*)` since TODO.md is no longer directly edited. Add `Bash(bash:*)` for generate-todo.sh calls.
- [ ] Verify all 6 modes produce correct TODO.md output by running `bash .claude/scripts/generate-todo.sh --dry-run` after state.json changes

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Remove all TODO.md Edit/sed operations, add generate-todo.sh calls

**Verification**:
- Each mode has exactly one `generate-todo.sh` call after state.json updates
- No remaining Edit/sed operations targeting TODO.md
- No remaining sed operations on TODO.md frontmatter
- No remaining generate-task-order.sh calls (subsumed by generate-todo.sh)

---

### Phase 2: Update commands/review.md and commands/implement.md [COMPLETED]

**Goal**: Replace TODO.md task creation Edits in /review, add goal line support to state.json and generate-todo.sh, and remove defensive TODO.md edits from /implement.

**Tasks**:
- [ ] **review.md Section 5.6.3 Step 5 (line 562-563)**: Remove "Add task entry following existing format in TODO.md" Edit instruction. The state.json update in Step 4 (lines 544-559) already writes the task. Add `bash .claude/scripts/generate-todo.sh` after all review task state.json writes and generate-task-order.sh call are done.
- [ ] **review.md Section 6.5 (lines 599-614)**: Remove the standalone generate-task-order.sh call block. generate-todo.sh already calls generate-task-order.sh internally.
- [ ] **review.md Section 6.7.3 Goal line (lines 714-718)**: Replace the Edit-based goal update. Instead, add `active_goal` field to state.json via jq: `jq --arg goal "$selected_goal" '.active_goal = $goal' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json`. Then call `bash .claude/scripts/generate-todo.sh`.
- [ ] **generate-todo.sh**: Add rendering of `active_goal` field. After writing the `## Task Order` header and before the wave table, check if `active_goal` exists in state.json and render it as `**Goal**: {value}`. This is a targeted 5-10 line addition to generate-todo.sh's `generate_todo()` function, specifically in the Task Order section delegation. Note: the goal rendering may need to be added to generate-task-order.sh instead, since generate-todo.sh delegates the Task Order section to that script. Investigate which script renders the `**Goal**:` line and add the `active_goal` lookup there.
- [ ] **implement.md (lines 173, 177)**: Remove the defensive TODO.md Edit that adds `- **Summary**` to the task entry (G9). generate-todo.sh does not render completion_summary lines, and state.json already stores the field. Remove the defensive status correction Edit (G10) -- generate-todo.sh renders status from state.json, so if state.json is correct, TODO.md will be too.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/review.md` - Remove TODO.md Edits, add generate-todo.sh call, replace goal Edit with state.json write
- `.claude/commands/implement.md` - Remove defensive TODO.md Edits (lines 173, 177)
- `.claude/scripts/generate-todo.sh` or `.claude/scripts/generate-task-order.sh` - Add active_goal rendering

**Verification**:
- No remaining Edit operations targeting TODO.md in review.md
- No remaining Edit operations targeting TODO.md in implement.md
- Goal line renders correctly when `active_goal` is set in state.json
- `bash .claude/scripts/generate-todo.sh --dry-run` produces correct output with goal line

---

### Phase 3: Update skill files (spawn, fix-it, project-overview) [COMPLETED]

**Goal**: Replace all direct TODO.md writes in skill definitions with generate-todo.sh calls after state.json updates.

**Tasks**:
- [ ] **skill-spawn/SKILL.md Stage 3 (lines 92-99)**: Remove the Edit instruction that changes status marker to `[BLOCKED]` in TODO.md. The state.json update in Stage 2 (lines 76-88) already sets status to "blocked". generate-todo.sh will render the correct status.
- [ ] **skill-spawn/SKILL.md Stage 12 (lines 360-377)**: Remove the Edit instruction that inserts new task entries after the Tasks header. The state.json updates in Stage 11 (lines 299-356) already write all task data. generate-todo.sh will render these entries.
- [ ] **skill-spawn/SKILL.md Stage 14 (lines 402-414)**: Remove the Edit instruction that updates parent task Dependencies line in TODO.md. The state.json update in Stage 13 (lines 386-398) already writes the dependencies array. generate-todo.sh renders dependencies from state.json.
- [ ] **skill-spawn/SKILL.md Stage 14b (lines 438-448)**: Replace the generate-task-order.sh call with `bash .claude/scripts/generate-todo.sh`. This single call replaces Stages 3, 12, and 14 (all TODO.md writes) plus the existing Task Order regeneration.
- [ ] **skill-fix-it/SKILL.md Step 9.2 (lines 481-510)**: Remove the Edit instruction that prepends task entries to `## Tasks` section. The state.json update in Step 9.1 (lines 442-477) already writes the task data. Replace the generate-task-order.sh call in Step 9.4 (lines 531-538) with `bash .claude/scripts/generate-todo.sh`.
- [ ] **skill-project-overview/SKILL.md Section 5.4 (lines 376-393)**: Remove the Edit instruction that prepends the task entry. The state.json update in Section 5.3 (lines 362-373) already writes the task. The existing generate-todo.sh call in Section 5.5 (lines 389-393) is already correct -- keep it. Remove any link-artifact-todo.sh call if present.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-spawn/SKILL.md` - Remove Stages 3, 12, 14 TODO.md Edits; replace Stage 14b with generate-todo.sh
- `.claude/skills/skill-fix-it/SKILL.md` - Remove Step 9.2 Edit; replace Step 9.4 with generate-todo.sh
- `.claude/skills/skill-project-overview/SKILL.md` - Remove Section 5.4 Edit; keep Section 5.5 generate-todo.sh call

**Verification**:
- No remaining Edit operations targeting TODO.md in any of the three skill files
- Each skill has exactly one generate-todo.sh call after all state.json writes are complete
- No remaining generate-task-order.sh calls (subsumed)
- skill-spawn allowed-tools frontmatter no longer needs Edit for TODO.md

---

### Phase 4: Update meta-builder-agent.md [COMPLETED]

**Goal**: Replace the batch TODO.md insertion pattern in meta-builder-agent with a single generate-todo.sh call after all tasks are written to state.json.

**Tasks**:
- [ ] **Batch insertion (lines 750-803)**: Remove the entire "TODO.md Entry Format" section and "TODO.md Batch Insertion Pattern" code block. The state.json writes (lines 728-748) already store all task data. Replace with a note: "After all tasks are written to state.json, call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md."
- [ ] **Lines 1400-1439**: Remove the "Insert batch into TODO.md" step and the generate-task-order.sh call. Replace with `bash .claude/scripts/generate-todo.sh`.
- [ ] Simplify the delivery summary section: the batch insertion code (python pseudocode for building markdown entries and calling `insert_after_heading`) can be removed entirely. The task table, dependency graph, and execution order sections remain (they are user output, not file writes).
- [ ] Verify the agent's state.json writes include all fields that generate-todo.sh needs to render: project_number, project_name, status, task_type, topic, dependencies, description, effort.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Remove batch TODO.md insertion, add generate-todo.sh call

**Verification**:
- No remaining Edit operations targeting TODO.md in meta-builder-agent.md
- No remaining generate-task-order.sh --update-todo calls
- Single generate-todo.sh call after all state.json writes
- State.json entries include all fields needed for correct TODO.md rendering

---

### Phase 5: Update archive-task.sh and vault-operation.sh [COMPLETED]

**Goal**: Replace direct TODO.md modification (Python entry removal, sed renumbering, Python comment insertion) with generate-todo.sh calls.

**Tasks**:
- [ ] **archive-task.sh Section C (lines 110-155)**: Remove the entire Python inline script that removes task blocks from TODO.md. After Section B (line 102-108, removing task from state.json active_projects), add `bash .claude/scripts/generate-todo.sh`. The task is no longer in active_projects, so generate-todo.sh will not render it. This eliminates 40 lines of Python.
- [ ] **vault-operation.sh lines 161-167 (sed renumber)**: Remove the sed commands that replace task number references in TODO.md. After all state.json renumbering is complete (the jq updates on lines 138-140), generate-todo.sh will render correct numbers.
- [ ] **vault-operation.sh lines 195-228 (transition comment)**: Remove the Python script that inserts vault transition comments into TODO.md frontmatter. Add the vault transition information to state.json instead (e.g., as a `vault_transition_comment` field), or simply remove the feature since generate-todo.sh produces a clean regeneration. If keeping the comment, add it to state.json's `vault_history` entry and have generate-todo.sh render it.
- [ ] **vault-operation.sh lines 230-237 (generate-task-order.sh call)**: Replace with `bash .claude/scripts/generate-todo.sh`. This single call handles everything: frontmatter, Task Order, and all task entries with renumbered task numbers.
- [ ] Ensure vault-operation.sh calls generate-todo.sh exactly once at the end, after all state.json modifications are complete (renumbering + state reset).

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/archive-task.sh` - Remove Python block removal, add generate-todo.sh call
- `.claude/scripts/vault-operation.sh` - Remove sed renumber, Python comment, generate-task-order.sh; add generate-todo.sh

**Verification**:
- No remaining Python or sed operations on TODO.md in either script
- archive-task.sh flow: remove from state.json -> generate-todo.sh -> move directory
- vault-operation.sh flow: renumber state.json -> reset state -> generate-todo.sh (once at end)
- `bash .claude/scripts/generate-todo.sh --dry-run` produces correct output after archival

---

### Phase 6: Sync extension copies and validate [COMPLETED]

**Goal**: Update all extension copies in `.claude/extensions/core/` to match the primary files, and run end-to-end validation.

**Tasks**:
- [ ] Copy updated `.claude/commands/task.md` to `.claude/extensions/core/commands/task.md`
- [ ] Copy updated `.claude/commands/review.md` to `.claude/extensions/core/commands/review.md`
- [ ] Copy updated `.claude/commands/implement.md` to `.claude/extensions/core/commands/implement.md`
- [ ] Copy updated `.claude/skills/skill-spawn/SKILL.md` to `.claude/extensions/core/skills/skill-spawn/SKILL.md`
- [ ] Copy updated `.claude/skills/skill-fix-it/SKILL.md` to `.claude/extensions/core/skills/skill-fix-it/SKILL.md`
- [ ] Copy updated `.claude/skills/skill-project-overview/SKILL.md` to `.claude/extensions/core/skills/skill-project-overview/SKILL.md`
- [ ] Copy updated `.claude/agents/meta-builder-agent.md` to `.claude/extensions/core/agents/meta-builder-agent.md`
- [ ] Run `bash .claude/scripts/generate-todo.sh --dry-run` and verify output matches expected TODO.md structure
- [ ] Verify no remaining direct TODO.md writes in any modified file: `grep -n "Edit.*TODO\|sed.*TODO\|TODO\.md" .claude/commands/task.md .claude/commands/review.md .claude/commands/implement.md .claude/skills/skill-spawn/SKILL.md .claude/skills/skill-fix-it/SKILL.md .claude/skills/skill-project-overview/SKILL.md .claude/agents/meta-builder-agent.md .claude/scripts/archive-task.sh .claude/scripts/vault-operation.sh`
- [ ] Verify extension copies match primaries: `diff .claude/commands/task.md .claude/extensions/core/commands/task.md` (and similar for each file)

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `.claude/extensions/core/commands/task.md` - Sync from primary
- `.claude/extensions/core/commands/review.md` - Sync from primary
- `.claude/extensions/core/commands/implement.md` - Sync from primary
- `.claude/extensions/core/skills/skill-spawn/SKILL.md` - Sync from primary
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` - Sync from primary
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` - Sync from primary
- `.claude/extensions/core/agents/meta-builder-agent.md` - Sync from primary

**Verification**:
- All extension copies are identical to primary files
- grep finds no remaining direct TODO.md write patterns in any modified file
- generate-todo.sh --dry-run produces valid output
- No regression in task creation workflow (state.json -> generate-todo.sh -> correct TODO.md)

## Testing & Validation

- [ ] Run `bash .claude/scripts/generate-todo.sh --dry-run` and verify complete TODO.md output
- [ ] Verify state.json has all fields needed by generate-todo.sh: project_number, project_name, status, task_type, topic, dependencies, artifacts, description, effort
- [ ] Grep all modified files for residual TODO.md direct-write patterns: `Edit.*TODO`, `sed.*TODO`, `link-artifact-todo`
- [ ] Verify no commands/skills/agents reference generate-task-order.sh --update-todo (all replaced by generate-todo.sh)
- [ ] Test goal line: set `active_goal` in state.json, run generate-todo.sh, verify goal renders in Task Order section

## Artifacts & Outputs

- plans/01_task-creation-state-first.md (this file)
- Modified files: 10 primary files + 7 extension copies = 17 total files
- summaries/01_task-creation-state-first-summary.md (upon completion)

## Rollback/Contingency

All changes are to agent instruction files (.md) and shell scripts. Git revert of the implementation commit restores all previous behavior. The key invariant to maintain: state.json must be written before generate-todo.sh is called. If a partial implementation leaves some commands using the old pattern and others using the new pattern, the system will still function -- old-pattern commands write to TODO.md directly (which gets overwritten on next generate-todo.sh call), while new-pattern commands write to state.json first. The only risk during transition is temporary TODO.md staleness for old-pattern commands.
