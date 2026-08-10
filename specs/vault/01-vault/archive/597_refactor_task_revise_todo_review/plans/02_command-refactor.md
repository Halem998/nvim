# Implementation Plan: Task #597

- **Task**: 597 - Refactor /task, /revise, /todo, /review for consistency with new architecture
- **Status**: [COMPLETED]
- **Effort**: 10 hours
- **Dependencies**: Task 593 (shared utilities -- complete), Task 596 (orchestrator -- complete)
- **Research Inputs**: specs/597_refactor_task_revise_todo_review/reports/01_seed-research.md, specs/597_refactor_task_revise_todo_review/reports/02_command-refactor-analysis.md, specs/597_refactor_task_revise_todo_review/reports/03_design-guidance.md
- **Artifacts**: plans/02_command-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor four secondary commands (/task 710L, /revise 160L, /todo 1046L, /review 1039L) to integrate shared infrastructure from task 593, decompose monolithic commands into reusable utility scripts, and close a critical memory harvest gap affecting 47 unharvested task candidates. The highest-priority deliverable is `memory-harvest.sh`, which plugs silent information loss in the /todo archival pipeline. The remaining work extracts 8 utility scripts, integrates gate-in/gate-out where applicable, and adds orchestrator handoff support to /revise.

### Research Integration

Three research reports were integrated:

1. **Seed research (01)**: Identified memory vault gap (47 archived tasks with unharvested memory_candidates), /todo decomposition risks, /revise orchestrator handoff requirement, and /task shared utilities scope.
2. **Command refactor analysis (02)**: Confirmed line counts, mapped shared infrastructure applicability (gate-in/gate-out applies only to /revise and 2-3 modes of /task; not to /todo or /review). Identified 8 utility scripts to create. Verified `parse-command-args.sh` does NOT apply to /task due to `--flag N` syntax mismatch.
3. **Design guidance (03)**: Provided target line counts and module signatures. Confirmed `skill_write_orchestrator_handoff()` in skill-base.sh already scaffolds the /revise handoff.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly reference task 597. This is a meta/infrastructure task; meta tasks are excluded from ROADMAP.md matching per /todo conventions.

## Goals & Non-Goals

**Goals**:
- Create `memory-harvest.sh` to close the 47-task memory candidate gap
- Decompose /todo (1046L) into 5 utility modules, reducing it to ~450L
- Decompose /review (1039L) into 3 utility modules, reducing it to ~450L
- Integrate /revise (160L) with gate-in/gate-out and orchestrator handoff, targeting ~125L
- Apply gate-in to /task modes 3 (expand) and 5 (abandon), reducing from 710L to ~665L
- Ensure all refactored commands follow the architecture established by task 593/595

**Non-Goals**:
- Decomposing /task's --review mode (240L of unique logic, not cost-effective for this task)
- Applying `parse-command-args.sh` to /task (incompatible `--flag N` syntax)
- Applying gate-in/gate-out to /todo or /review (they don't delegate to skills or operate on single tasks)
- Reducing /task below ~650L (bulk of content is unique per-mode logic)
- Creating test infrastructure for commands (would require a separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| /todo decomposition corrupts state.json or archive/state.json | H | M | Extract one module at a time; verify each extraction preserves behavior before connecting |
| memory-harvest.sh creates duplicate memories | M | L | Use existing deduplication in memory-index.json; confidence threshold >= 0.7 filters noise |
| Extracted utility scripts break on edge cases (empty inputs, legacy formats) | M | M | Preserve exact logic from inline code; handle both padded and unpadded directory formats |
| /revise orchestrator handoff triggers incorrectly | L | L | Guard with explicit `--orchestrator` flag; call `skill_write_orchestrator_handoff()` which has its own guard |
| roadmap-sync.sh produces incorrect annotation matches | M | L | Preserve explicit > exact > summary priority order from current inline logic |
| Regressions in /review issue-grouping algorithm after extraction | M | M | Extract algorithm verbatim; test with single-issue and empty inputs |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5, 6 | 2 |
| 4 | 7 | 6 |
| 5 | 8 | 3, 5, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create memory-harvest.sh [COMPLETED]

**Goal**: Build the highest-priority deliverable -- a standalone script that harvests memory_candidates from state.json task entries and writes them to the memory vault.

**Tasks**:
- [x] Create `.claude/scripts/memory-harvest.sh` (~100L) *(completed)*
- [x] Implement `harvest_memories()` function accepting task_number as argument *(completed: implemented as main script body with per-candidate loop)*
- [x] Read `memory_candidates` array from state.json for the given task number *(completed)*
- [x] Filter candidates with `confidence >= 0.7` *(completed)*
- [x] For each qualifying candidate:
  - Generate memory ID from category and keywords: `MEM-{category}-{first-keyword}-{second-keyword}`
  - Write memory file to `.memory/10-Memories/MEM-{id}.md` using existing memory file format
  - Check for duplicates via `memory-index.json` before writing (skip if ID already exists)
  *(completed)*
- [x] Update `.memory/memory-index.json` with new entries (append to entries array, update entry_count and total_tokens) *(completed)*
- [x] Output harvest count (stdout) for caller integration *(completed)*
- [x] Make script executable (`chmod +x`) *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/memory-harvest.sh` - New file

**Verification**:
- Script exists and is executable
- Running with a task number that has memory_candidates in state.json creates files in `.memory/10-Memories/`
- Running with a task that has no candidates produces no output (exit 0)
- Duplicate candidates are skipped (idempotent)

---

### Phase 2: Create /todo utility scripts (archive-task.sh, orphan-detection.sh, vault-operation.sh) [COMPLETED]

**Goal**: Extract three self-contained utility modules from /todo to reduce its monolithic structure. These three are independent of the roadmap-sync module which has more complex shared state.

**Tasks**:
- [x] Create `.claude/scripts/orphan-detection.sh` (~100L) *(completed)*
  - Extract Steps 2.5-2.6 (lines 27-123 of todo.md)
  - Input: specs/ directory path, state.json path, archive/state.json path
  - Output: Print orphaned_in_specs, orphaned_in_archive, and misplaced_in_specs as newline-separated lists to stdout
  - Separate the three categories with delimiter lines for parsing
- [x] Create `.claude/scripts/archive-task.sh` (~80L) *(completed)*
  - Extract core archival logic from Steps 5A-5D (lines 379-441 of todo.md)
  - Input: task_number, project_name, dry_run flag
  - Operations: move task from active_projects to archive completed_projects, move directory to archive/
  - Handle both padded and unpadded directory formats
  - Return 0 on success, 1 on failure
- [x] Create `.claude/scripts/vault-operation.sh` (~135L) *(completed)*
  - Extract Step 5.7 (lines 693-828 of todo.md)
  - Input: state.json path, confirmation flag (skip user prompt when pre-confirmed)
  - Operations: create vault directory, move archive, renumber tasks, reset state
  - Include post-renumber Task Order regeneration call
- [x] Make all scripts executable *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/orphan-detection.sh` - New file
- `.claude/scripts/archive-task.sh` - New file
- `.claude/scripts/vault-operation.sh` - New file

**Verification**:
- All three scripts exist and are executable
- Each script runs without errors when called with valid arguments
- orphan-detection.sh correctly identifies directories not tracked in state files
- archive-task.sh handles both padded (015_slug) and unpadded (15_slug) directory formats

---

### Phase 3: Refactor /todo to use utility scripts and integrate memory harvest [COMPLETED]

**Goal**: Rewire /todo to call the extracted utility scripts and the new memory-harvest.sh, reducing its line count from 1046L to ~450L.

**Tasks**:
- [x] Create `.claude/scripts/roadmap-sync.sh` (~210L) *(completed: 331L with scan+apply phases)*
  - Extract Steps 3.5 + 5.5 combined (lines 124-260 and 523-596 of todo.md)
  - Input: archivable tasks JSON array, ROADMAP.md path
  - Operations: scan for roadmap matches, apply annotations, track changes
  - Combine scan and application since they share roadmap_matches state
- [x] Replace Steps 2.5-2.6 in todo.md with `source .claude/scripts/orphan-detection.sh` call *(completed)*
- [x] Replace Step 3.5 roadmap scan with `source .claude/scripts/roadmap-sync.sh` scan call *(completed)*
- [x] Add memory-harvest.sh integration to archival loop (before archive step for each task) *(completed)*
- [x] Replace Steps 5A-5D inline archival with `bash .claude/scripts/archive-task.sh` calls *(completed)*
- [x] Replace Step 5.5 roadmap application with roadmap-sync.sh apply call *(completed)*
- [x] Replace Step 5.7 vault operation with `bash .claude/scripts/vault-operation.sh` call *(completed)*
- [x] Add harvest count to /todo output section *(completed: Memories: {H} harvested in output)*
- [x] Verify all references to extracted inline code are removed *(completed)*
- [x] Verify roadmap_matches array is properly passed between scan and application phases *(completed: via temp JSON file)*

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/roadmap-sync.sh` - New file
- `.claude/commands/todo.md` - Refactor to use utility scripts (~1046L to ~450L)

**Verification**:
- `wc -l .claude/commands/todo.md` shows ~400-500L
- All 5 utility scripts are called from todo.md
- Memory harvest step is present in archival loop
- Dry-run output still displays all categories (tasks, orphans, misplaced, roadmap)
- Harvest count appears in final output
- Roadmap annotation format matches existing pattern

---

### Phase 4: Refactor /revise with gate-in/gate-out and orchestrator handoff [COMPLETED]

**Goal**: Integrate /revise with shared command infrastructure and add orchestrator handoff support for /orchestrate integration.

**Tasks**:
- [x] Add `--orchestrator` flag parsing to ARGUMENTS handling *(completed)*
- [x] Replace CHECKPOINT 1 (GATE IN, lines 22-51) inline jq with `source .claude/scripts/command-gate-in.sh "$task_number" "revise"` *(completed: replaced inline session ID generation and task lookup, ~15L reduction)*
- [x] Replace CHECKPOINT 3 (GATE OUT, lines 80-116) inline defensive correction with `bash .claude/scripts/command-gate-out.sh "$task_number" "plan" "$SESSION_ID"` *(completed: replaced inline status verification, ~20L reduction)*
- [x] Add orchestrator handoff after delegation *(completed: sources skill-base.sh and calls skill_write_orchestrator_handoff with phase="revise", status="planned", next_hint="implement" when --orchestrator flag set)*
- [x] Preserve plan existence check routing (plan revision vs description update paths) *(completed)*
- [x] Update "Artifact Numbering Note" to reference shared infrastructure *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/revise.md` - Refactor to use shared infrastructure (~160L to ~125L)

**Verification**:
- `wc -l .claude/commands/revise.md` shows ~120-130L
- GATE IN uses command-gate-in.sh (SESSION_ID, PADDED_NUM exported)
- GATE OUT uses command-gate-out.sh (defensive correction delegated)
- `--orchestrator` flag triggers handoff file creation
- Without `--orchestrator`, behavior is identical to current

---

### Phase 5: Refactor /task with gate-in for applicable modes [COMPLETED]

**Goal**: Apply command-gate-in.sh to /task modes that perform task-number-based operations, eliminating repeated inline jq patterns.

**Tasks**:
- [x] Add `source .claude/scripts/command-gate-in.sh` to Expand mode (--expand N, mode 3) *(completed)*
  - Replace inline task lookup jq block with gate_in call
  - Use exported TASK_DATA, PROJECT_NAME, PADDED_NUM
- [x] Add `source .claude/scripts/command-gate-in.sh` to Abandon mode (--abandon N, mode 5) *(completed: gate-in for validation; task_data re-read post-gate for archive jq insert)*
  - Replace inline task lookup jq block with gate_in call
  - Note: abandon moves to archive, so some post-gate-in logic is unique
- [x] Evaluate Recover mode (--recover N, mode 2) gate-in applicability *(deviation: skipped — gate-in reads active_projects only; recover looks up from archive/state.json. Documented with NOTE comment in command file.)*
  - Recover reads from archive/state.json, not active_projects
  - gate-in reads active_projects only -- so Recover mode must keep inline lookup
  - Document this decision in the command file
- [x] Replace inline session ID generation in modes 2, 3, 5 with SESSION_ID from gate-in (where applicable) *(completed: SESSION_ID exported by gate-in in modes 3 and 5; mode 2 keeps inline as gate-in not used)*
- [x] Preserve all mode-specific logic (create mode, sync mode, review mode) unchanged *(completed)*
- [x] Verify the duplicated 4-line task lookup pattern is eliminated from modes 3 and 5 *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/commands/task.md` - Apply gate-in to modes 3 and 5 (~710L to ~665L)

**Verification**:
- `wc -l .claude/commands/task.md` shows ~650-680L
- Expand mode uses gate-in instead of inline jq
- Abandon mode uses gate-in instead of inline jq
- Recover mode retains inline archive lookup (documented reason)
- Create and sync modes are unchanged
- Review mode (--review) is unchanged

---

### Phase 6: Create /review utility scripts [COMPLETED]

**Goal**: Extract three reusable components from /review's monolithic structure.

**Tasks**:
- [x] Create `.claude/scripts/issue-grouping.sh` (~180L) *(completed)*
  - Extract Steps 5.5.2-5.5.5 (issue grouping indicators, clustering algorithm, post-processing, scoring)
  - Input: issue list as JSON array (via stdin or file argument)
  - Output: grouped issues JSON with scores to stdout
  - Preserve clustering algorithm exactly: primary match (file_section + issue_type), secondary match (2+ shared key_terms + same priority), new group fallback
  - Preserve group cap at 10 and small-group merging (< 2 items)
- [x] Create `.claude/scripts/roadmap-integration.sh` (~180L) *(completed)*
  - Extract Steps 2.5-2.5.3 (parse ROADMAP.md, cross-reference with state, annotate completed items)
  - Input: ROADMAP.md path, state.json path
  - Output: roadmap_state JSON structure to stdout, applies annotations via Edit-style output
  - Preserve safety rules: skip already-annotated items, one edit per item
- [x] Create `.claude/scripts/tier-selection.sh` (~100L) *(completed)*
  - Extract Steps 5.5.6-5.5.7 (Tier 1 group selection + Tier 2 granularity + Tier 3 manual)
  - Note: This script primarily generates the AskUserQuestion JSON prompts and parses responses
  - Input: grouped issues JSON
  - Output: selected issues list for task creation
- [x] Make all scripts executable *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/issue-grouping.sh` - New file
- `.claude/scripts/roadmap-integration.sh` - New file
- `.claude/scripts/tier-selection.sh` - New file

**Verification**:
- All three scripts exist and are executable
- issue-grouping.sh produces valid JSON output from a JSON input array
- roadmap-integration.sh correctly parses ROADMAP.md phase headers and checkboxes
- tier-selection.sh generates correctly formatted AskUserQuestion prompts

---

### Phase 7: Refactor /review to use utility scripts [COMPLETED]

**Goal**: Rewire /review to call the extracted utility scripts, reducing it from 1039L to ~450L.

**Tasks**:
- [x] Replace Steps 2.5-2.5.3 (roadmap integration, ~180L) with `bash .claude/scripts/roadmap-integration.sh` call *(completed: replaced ~148L inline with 35L wrapper calling --roadmap and --annotate flags)*
- [x] Replace Steps 5.5.2-5.5.5 (issue grouping, ~180L) with `bash .claude/scripts/issue-grouping.sh` call *(completed: replaced ~108L inline with stdin pipe call)*
- [x] Replace Steps 5.5.6-5.5.7 (tier selection, ~100L) with `bash .claude/scripts/tier-selection.sh` call *(completed: replaced ~90L inline with --mode tier1/tier2/tier3 calls)*
- [x] Verify issue grouping output is correctly consumed by task creation logic (Steps 5.6.1-5.6.4) *(completed: grouped_issues JSON consumed by 5.6.1/5.6.2)*
- [x] Verify roadmap_state structure is correctly consumed by review report generation (Step 4) *(completed: roadmap_state/roadmap_matches extracted from script output, referenced in Step 4 note)*
- [x] Ensure Task Order regeneration (Step 6.5) is preserved *(completed)*
- [x] Ensure review state tracking (Step 4.5) is preserved *(completed)*
- [x] Verify git commit section (Step 7) references all modified files *(completed)*

**Timing**: 1.5 hours

**Depends on**: 6

**Files to modify**:
- `.claude/commands/review.md` - Refactor to use utility scripts (~1039L to ~450L)

**Verification**:
- `wc -l .claude/commands/review.md` shows ~400-500L
- All three utility scripts are called from review.md
- Review report generation uses roadmap_state from roadmap-integration.sh
- Issue grouping uses output from issue-grouping.sh
- Task creation flow uses selection from tier-selection.sh
- Git commit captures all modified files

---

### Phase 8: Cross-command verification and documentation [COMPLETED]

**Goal**: Verify all refactored commands work correctly together and update documentation to reflect new architecture.

**Tasks**:
- [ ] Verify line counts for all four commands:
  - `wc -l .claude/commands/task.md` -- target ~650-680L
  - `wc -l .claude/commands/revise.md` -- target ~120-130L
  - `wc -l .claude/commands/todo.md` -- target ~400-500L
  - `wc -l .claude/commands/review.md` -- target ~400-500L
- [ ] Verify all 9 new utility scripts exist and are executable:
  - `ls -la .claude/scripts/memory-harvest.sh`
  - `ls -la .claude/scripts/archive-task.sh`
  - `ls -la .claude/scripts/orphan-detection.sh`
  - `ls -la .claude/scripts/roadmap-sync.sh`
  - `ls -la .claude/scripts/vault-operation.sh`
  - `ls -la .claude/scripts/issue-grouping.sh`
  - `ls -la .claude/scripts/roadmap-integration.sh`
  - `ls -la .claude/scripts/tier-selection.sh`
  - (memory-harvest.sh counted as the 9th, already created in Phase 1)
- [ ] Verify /revise orchestrator handoff:
  - Check `--orchestrator` flag is parsed
  - Check `skill_write_orchestrator_handoff()` is called conditionally
- [ ] Verify memory harvest integration in /todo:
  - Confirm harvest call appears in archival loop
  - Confirm harvest count appears in output
- [ ] Verify no inline code duplication remains (search for patterns that should have been extracted)
- [ ] Run `bash -n` syntax check on all new scripts to catch shell syntax errors

**Timing**: 1 hour

**Depends on**: 3, 5, 7

**Files to modify**:
- No new files; verification only

**Verification**:
- All line count targets met within tolerance (+/- 50L)
- All 9 scripts pass `bash -n` syntax check
- No orphaned inline code (search for extracted patterns returns only script references)
- /revise orchestrator handoff documented and guarded

## Testing & Validation

- [ ] All 9 new scripts exist in `.claude/scripts/` and are executable
- [ ] `bash -n` syntax check passes for all new scripts
- [ ] /todo line count reduced from 1046L to ~450L
- [ ] /review line count reduced from 1039L to ~450L
- [ ] /revise line count reduced from 160L to ~125L
- [ ] /task line count reduced from 710L to ~665L
- [ ] memory-harvest.sh handles edge cases: no candidates, empty array, duplicate IDs
- [ ] /revise --orchestrator flag produces .orchestrator-handoff.json
- [ ] Extracted utility scripts preserve the exact logic from their inline origins

## Artifacts & Outputs

- `specs/597_refactor_task_revise_todo_review/plans/02_command-refactor.md` (this plan)
- `.claude/scripts/memory-harvest.sh` - Memory candidate harvesting
- `.claude/scripts/archive-task.sh` - Task archival operations
- `.claude/scripts/orphan-detection.sh` - Orphaned directory detection
- `.claude/scripts/roadmap-sync.sh` - ROADMAP.md synchronization
- `.claude/scripts/vault-operation.sh` - Vault archival operations
- `.claude/scripts/issue-grouping.sh` - Issue clustering algorithm
- `.claude/scripts/roadmap-integration.sh` - Roadmap analysis for reviews
- `.claude/scripts/tier-selection.sh` - Tiered issue selection flow
- `.claude/commands/todo.md` - Refactored (1046L to ~450L)
- `.claude/commands/review.md` - Refactored (1039L to ~450L)
- `.claude/commands/revise.md` - Refactored (160L to ~125L)
- `.claude/commands/task.md` - Refactored (710L to ~665L)

## Rollback/Contingency

All changes are to command definition files (.md) and new shell scripts. Rollback is straightforward:

1. `git checkout` the four command files to their pre-refactoring state
2. Remove the 8 new utility scripts from `.claude/scripts/`
3. No runtime state is affected -- commands are interpreted at invocation time

If a single phase fails, the affected command can be reverted independently while keeping other phases' work. The utility scripts are additive and do not break existing functionality if the calling command is reverted.
