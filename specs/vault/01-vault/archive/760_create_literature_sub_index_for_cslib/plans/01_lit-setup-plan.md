# Implementation Plan: Add interactive literature index setup detection to --lit flag

- **Task**: 760 - Add interactive literature index setup detection to --lit flag
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/760_create_literature_sub_index_for_cslib/reports/01_lit-setup-detection.md
- **Artifacts**: plans/01_lit-setup-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

When `--lit` is used and `specs/literature-index.json` does not exist, the system currently exits silently with no literature context injected. This plan replaces that silent-exit behavior with an interactive detection and setup flow. The detection logic is inserted inline in each skill's Stage 4a block (since AskUserQuestion is a Claude tool, not a shell command), while the task-creation side effect is extracted into a shared bash helper script. The user gets three choices: skip, create a setup task, or create a setup task and orchestrate it inline before resuming.

### Research Integration

Key findings from the research report integrated into this plan:
- The insertion point is Stage 4a in all 6 skills (researcher, planner, implementer, plus hard variants), between the `lit_flag == "true"` check and the `literature-briefing.sh` call
- AskUserQuestion must remain inline in SKILL.md (cannot be invoked from a sourced shell script)
- All 6 affected skills currently lack `AskUserQuestion` in their `allowed-tools` frontmatter
- Programmatic task creation follows the well-established pattern from task.md (state.json update + generate-todo.sh)
- The fork-orchestrate inline option maps to the existing `dispatch-agent.sh` fork dispatch pattern
- The global Literature index at `~/Projects/Literature/index.json` has `project_tags` as the primary relevance signal

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task.

## Goals & Non-Goals

**Goals**:
- Detect missing `specs/literature-index.json` when `--lit` is used and present interactive setup options
- Provide three user choices: skip (proceed without literature), create setup task (deferred), create + orchestrate inline (immediate)
- Create a shared helper script for the task-creation side effect to avoid duplicating bash logic across 6 skills
- Ensure the global index (`~/Projects/Literature/index.json`) absence is handled gracefully with informative messaging

**Non-Goals**:
- Changing how `literature-briefing.sh` works when the sub-index already exists
- Modifying the sub-index schema or global index structure
- Implementing the actual research logic that populates the sub-index (that is the spawned setup task's responsibility)
- Adding `--lit` support to commands that do not already have it

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 6 SKILL.md files need identical Stage 4a edits -- divergence risk | M | M | Extract all bash logic into shared helper; only the AskUserQuestion prompt and control flow stay inline |
| Fork-orchestrate (option b) times out before completing sub-index population | M | L | Option b is user-chosen; if fork times out, the created task persists and user can `/orchestrate` it separately |
| Global Literature index missing (`~/Projects/Literature/index.json`) | L | L | Check for global index before offering setup options; display informative message if missing |
| User interrupts mid-setup after task was already created | L | M | Task created with `not_started` status -- harmless orphan; can be abandoned via `/task --abandon N` |
| Adding AskUserQuestion to allowed-tools has side effects | L | L | AskUserQuestion is a read-only interactive tool with no destructive capabilities |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

### Phase 1: Create shared helper script `literature-create-setup-task.sh` [COMPLETED]

**Goal**: Create a bash helper that programmatically creates a literature sub-index setup task in state.json and outputs the new task number.

**Tasks**:
- [x] Create `.claude/scripts/literature-create-setup-task.sh` with the following logic: *(completed)*
  - Read `next_project_number` from `specs/state.json`
  - Generate slug `populate_literature_sub_index`
  - Generate description: "Scan global Literature index (~\/Projects\/Literature\/index.json), analyze this repo's task descriptions and domain keywords, and populate specs/literature-index.json with relevant doc_ids and relevance annotations"
  - Insert new entry into `state.json` active_projects with `task_type: "meta"`, `status: "not_started"`
  - Increment `next_project_number`
  - Call `bash .claude/scripts/generate-todo.sh` to sync TODO.md
  - Print the new task number to stdout (for the calling skill to capture)
  - Exit 0 on success, exit 1 on failure with stderr message
- [x] Make the script executable (`chmod +x`) *(completed)*
- [x] Verify the script creates a valid task entry by dry-running against current state.json structure *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-create-setup-task.sh` - New file

**Verification**:
- Script creates a valid state.json entry when run
- `generate-todo.sh` produces correct TODO.md after script runs
- Script outputs only the task number to stdout
- Script handles edge cases (missing state.json, jq errors) with non-zero exit

---

### Phase 2: Add inline detection block to all 6 skill SKILL.md files [COMPLETED]

**Goal**: Insert the interactive detection logic into Stage 4a of all 6 affected skills, between the `lit_flag` check and the `literature-briefing.sh` call.

**Tasks**:
- [x] Add `AskUserQuestion` to `allowed-tools` in the frontmatter of all 6 SKILL.md files: *(completed)*
  - `.claude/skills/skill-researcher/SKILL.md`
  - `.claude/skills/skill-planner/SKILL.md`
  - `.claude/skills/skill-implementer/SKILL.md`
  - `.claude/skills/skill-researcher-hard/SKILL.md`
  - `.claude/skills/skill-planner-hard/SKILL.md`
  - `.claude/skills/skill-implementer-hard/SKILL.md`
- [x] Insert detection block into Stage 4a of each skill, immediately before the existing `lit_context` assignment. The block should: *(completed)*
  1. Check `lit_flag == "true"` AND `! -f specs/literature-index.json`
  2. Check whether the global index exists at `~/Projects/Literature/index.json` (or `$LITERATURE_DIR/index.json`)
  3. If global index missing: display a message explaining that no global Literature index was found, set `lit_context=""`, and continue
  4. If global index exists: present AskUserQuestion with 3 options:
     - **Skip**: Continue without literature context (proceed normally)
     - **Create setup task**: Call `literature-create-setup-task.sh`, report the task number, set `lit_context=""`, and continue with the original command
     - **Create task and run now**: Call `literature-create-setup-task.sh`, fork-orchestrate the created task inline, then re-call `literature-briefing.sh` to populate `lit_context`
  5. After detection block, the existing `lit_context=$(bash .claude/scripts/literature-briefing.sh ...)` code runs as before
- [x] Ensure the detection block is identical across all 6 skills (copy-paste consistency) *(completed)*
- [x] Ensure that when option "Create task and run now" is selected, the fork dispatch uses the Agent tool with `subagent_type: "fork"` to inherit context and run the setup task's research + implementation inline *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add AskUserQuestion to frontmatter; insert detection block in Stage 4a
- `.claude/skills/skill-planner/SKILL.md` - Same changes
- `.claude/skills/skill-implementer/SKILL.md` - Same changes
- `.claude/skills/skill-researcher-hard/SKILL.md` - Same changes
- `.claude/skills/skill-planner-hard/SKILL.md` - Same changes
- `.claude/skills/skill-implementer-hard/SKILL.md` - Same changes

**Verification**:
- All 6 SKILL.md files have `AskUserQuestion` in their `allowed-tools` list
- The detection block is syntactically correct and identical across all 6 files
- The block only triggers when `lit_flag == "true"` AND `specs/literature-index.json` is absent
- When the sub-index already exists, the block is skipped entirely (no user prompt)

---

### Phase 3: Implement fork-orchestrate inline logic for option b [COMPLETED]

**Goal**: Wire up the "create task and run now" option to fork-dispatch the setup task's research and populate the sub-index before the original command resumes.

**Tasks**:
- [x] In the Stage 4a detection block (option b path), after calling `literature-create-setup-task.sh` to get the new task number: *(completed)*
  1. Construct a fork prompt that instructs the forked agent to:
     - Read the global Literature index at `~/Projects/Literature/index.json`
     - Read task descriptions from `specs/state.json`
     - Analyze keyword overlap between global index entries (using `keywords`, `project_tags`, `summary` fields) and the repo's task descriptions/domain
     - Write matched entries to `specs/literature-index.json` following the sub-index schema (with `source: "discover"`)
     - Update the created task to `completed` status with a completion summary
  2. Invoke the Agent tool with `subagent_type: "fork"` and the constructed prompt
  3. After fork returns, verify `specs/literature-index.json` was created
  4. Re-run `literature-briefing.sh` to populate `lit_context` with the newly created sub-index
  5. If fork failed or sub-index was not created, log a warning and continue with `lit_context=""`
- [x] Add error handling for fork timeout or failure (graceful degradation: report task number, suggest manual `/orchestrate N`) *(completed)*
- [x] Ensure the fork does not interfere with the original command's state (the fork writes only to `specs/literature-index.json` and the new task's state.json entry) *(completed)*

**Timing**: 1.0 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Flesh out option b fork dispatch logic in Stage 4a detection block
- `.claude/skills/skill-planner/SKILL.md` - Same changes
- `.claude/skills/skill-implementer/SKILL.md` - Same changes
- `.claude/skills/skill-researcher-hard/SKILL.md` - Same changes
- `.claude/skills/skill-planner-hard/SKILL.md` - Same changes
- `.claude/skills/skill-implementer-hard/SKILL.md` - Same changes

**Verification**:
- Option b successfully creates the task, forks, populates `specs/literature-index.json`, and resumes with populated `lit_context`
- Fork failure degrades gracefully with informative message
- The original command's task state is not affected by the fork

---

### Phase 4: Documentation and CLAUDE.md update [COMPLETED]

**Goal**: Update documentation to describe the new interactive setup detection behavior.

**Tasks**:
- [x] Update the "Literature Mode (`--lit`)" section in `.claude/CLAUDE.md` (or its merge source) to document: *(completed)*
  - The new interactive detection behavior when `specs/literature-index.json` is missing
  - The three user choices (skip, create task, create + run now)
  - That the global index at `~/Projects/Literature/index.json` must exist for setup options to appear
- [x] Update `.claude/scripts/literature-briefing.sh` header comment to note that detection is now handled upstream in skills (the script's silent-exit behavior is unchanged, but the context around it is different) *(completed)*
- [x] Verify all 6 SKILL.md files have consistent Stage 4a detection blocks (final consistency check) *(completed)*

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- `.claude/CLAUDE.md` - Update Literature Mode section (or the merge source file that generates it)
- `.claude/scripts/literature-briefing.sh` - Update header comment

**Verification**:
- CLAUDE.md accurately describes the new --lit behavior
- `literature-briefing.sh` header comment is accurate
- All documentation references are consistent with the implementation

## Testing & Validation

- [ ] Run `/research N --lit` in a repo WITHOUT `specs/literature-index.json` -- verify AskUserQuestion prompt appears with 3 options
- [ ] Select "Skip" -- verify command continues normally with empty lit_context
- [ ] Select "Create setup task" -- verify new task appears in state.json and TODO.md, command continues with empty lit_context
- [ ] Select "Create task and run now" -- verify task is created, fork runs, `specs/literature-index.json` is populated, and lit_context is non-empty for the original command
- [ ] Run `/plan N --lit` in a repo WITH `specs/literature-index.json` already present -- verify NO prompt appears (existing behavior preserved)
- [ ] Run `/implement N --lit` in a repo without global Literature index (`~/Projects/Literature/index.json`) -- verify informative message instead of setup options
- [ ] Verify `literature-create-setup-task.sh` handles missing `specs/state.json` gracefully

## Artifacts & Outputs

- `.claude/scripts/literature-create-setup-task.sh` - New shared helper script
- `.claude/skills/skill-researcher/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/skills/skill-planner/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/skills/skill-implementer/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/skills/skill-researcher-hard/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/skills/skill-planner-hard/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/skills/skill-implementer-hard/SKILL.md` - Updated frontmatter + Stage 4a detection block
- `.claude/CLAUDE.md` - Updated documentation
- `specs/760_create_literature_sub_index_for_cslib/plans/01_lit-setup-plan.md` - This plan

## Rollback/Contingency

- Revert all 6 SKILL.md files to their pre-edit state (restore original Stage 4a blocks and remove AskUserQuestion from frontmatter)
- Delete `.claude/scripts/literature-create-setup-task.sh`
- Revert CLAUDE.md documentation changes
- The `literature-briefing.sh` script itself is not modified functionally, only its comment header, so no rollback needed there
- Git revert of the implementation commit(s) restores full previous behavior
