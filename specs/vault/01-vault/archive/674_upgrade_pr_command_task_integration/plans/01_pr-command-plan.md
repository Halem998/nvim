# Implementation Plan: Upgrade /pr Command Task Integration

- **Task**: 674 - Upgrade /pr command for task-integrated workflow
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Tasks 671, 672, 673 (all completed)
- **Research Inputs**: specs/674_upgrade_pr_command_task_integration/reports/01_pr-command-integration.md
- **Artifacts**: plans/01_pr-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Upgrade the `/pr` command's task-mode path to integrate with the task lifecycle established by tasks 671-673. The core changes are: fix the hardcoded state.json path bug in STEP 2, read pr-description.md and base_branch from task metadata instead of generating interactively, add a post-submission status transition (STEP 10b), and update the cslib project's own scripts to support the `pr_ready` status. Additionally, update `skill-pr-implementation` to write `base_branch` to state.json. Path-mode and description-mode are preserved unchanged.

### Research Integration

The research report (01_pr-command-integration.md) provided a complete STEP-by-STEP change map across 4 files, identified the hardcoded path bug at line 79, confirmed the pr-description.md artifact path convention, documented the base_branch detection approach, and enumerated edge cases (missing pr-description.md, task not in pr_ready status, stacked PR without base_branch). All findings are integrated into this plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Fix the hardcoded state.json path bug in STEP 2 (reads nvim config instead of cslib project)
- Make task-mode read pr-description.md for PR title and body instead of generating from scratch
- Support stacked PRs via base_branch detection from state.json task metadata
- Add STEP 10b to transition task from [PR READY] to [COMPLETED] after successful PR submission
- Update cslib project scripts (update-task-status.sh, generate-todo.sh) to support pr_ready status
- Update skill-pr-implementation to write base_branch to state.json during artifact linking

**Non-Goals**:
- Modifying path-mode or description-mode behavior (preserved as-is)
- Changing STEP 3 (Environment Check), STEP 4 (Sync), STEP 7 (CI Pipeline), or STEP 11 (Merge-Back)
- Modifying the pr-description.md format itself (established by task 672)
- Adding new CLI flags or input modes to /pr

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| cslib project scripts are outside this repo's git | M | H | Phase 4 clearly marked as cross-repo; changes committed separately in cslib |
| pr-description.md missing when status is pr_ready | M | L | Graceful fallback: warn and fall through to interactive STEP 9 generation |
| base_branch not in state.json for legacy tasks | L | H | Default to "main" (preserves existing behavior) |
| STEP 10b fails if cslib update-task-status.sh not yet updated | M | L | Graceful error handling with manual guidance |
| Editing 886-line pr.md introduces regressions in path/description modes | H | L | Each phase has targeted grep verification; path/description modes untouched |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix STEP 2 Bug and Add Task Metadata Loading [COMPLETED]

**Goal**: Fix the hardcoded state.json path, add pr-description.md loading, base_branch detection, and status validation to STEP 2 task-mode.

**Tasks**:
- [x] Define `CSLIB_DIR` and `CSLIB_STATE` constants at the top of STEP 2 task-mode section *(completed)*
- [x] Replace hardcoded `/home/benjamin/.config/nvim/specs/state.json` with `$CSLIB_STATE` *(completed)*
- [x] Add `project_name` and `task_status` reads from state.json alongside existing `task_desc` *(completed)*
- [x] Add status validation: warn if task_status is not `pr_ready`, offer continue or abort *(completed)*
- [x] Compute `pr_desc_path` using `CSLIB_DIR/specs/{NNN}_{project_name}/pr-description.md` *(completed)*
- [x] Add pr-description.md loading: if file exists, extract `pr_title` from first line (strip `# `), store `pr_body` from full content, set `has_pr_description=true`; if missing, set `has_pr_description=false` with warning *(completed)*
- [x] Add `base_branch` read from state.json task entry with `// "main"` jq default *(completed)*
- [x] Add stacked PR warning: if pr_body contains "stacked" but base_branch is "main", display advisory *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - STEP 2 section (lines ~70-105)

**Verification**:
- [ ] `grep -c "nvim/specs/state.json" .claude/extensions/cslib/commands/pr.md` returns 0 (bug removed)
- [ ] `grep -c "CSLIB_STATE" .claude/extensions/cslib/commands/pr.md` returns >= 2 (constant defined and used)
- [ ] `grep -c "pr_desc_path\|has_pr_description\|base_branch" .claude/extensions/cslib/commands/pr.md` returns >= 3 (new variables present)

---

### Phase 2: Update skill-pr-implementation base_branch Write [COMPLETED]

**Goal**: Add base_branch field to state.json task entry during Stage 7 (Link Artifacts) of skill-pr-implementation.

**Tasks**:
- [x] Add a substep to Stage 7 that writes `base_branch` to the task's state.json entry using jq *(completed)*
- [x] Document that base_branch defaults to "main" when the PR targets upstream/main directly, and is set to the parent branch name for stacked PRs *(completed)*
- [x] Add a note in the delegation context (Stage 3) that the subagent should determine and report the base branch used *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` - Stage 7 section (lines ~103-108)

**Verification**:
- [ ] `grep -c "base_branch" .claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` returns >= 2 (field documented and written)

---

### Phase 3: Redesign STEPs 5, 8, 9, 10 for Task-Mode [COMPLETED]

**Goal**: Update the remaining task-mode-affected STEPs to use data loaded in STEP 2 (pr_title, pr_body, base_branch, has_pr_description).

**Tasks**:
- [x] STEP 5 (Branch Creation): Add task-mode check -- if a `feat/` branch matching the task slug already exists (created by skill-pr-implementation), offer to reuse it instead of creating a new one from upstream/main *(completed)*
- [x] STEP 8 (Select PR Title): Add task-mode conditional -- when `has_pr_description` is true, display the extracted `pr_title` and ask approve/override (skip the 3-step interactive prefix+area+description flow); when false, fall through to existing interactive flow *(completed)*
- [x] STEP 9 (Compose PR Description): Add task-mode conditional -- when `has_pr_description` is true, display the loaded `pr_body` and use the existing approve/edit/replace AskUserQuestion; when false, fall through to existing template-based generation *(completed)*
- [x] STEP 10 (Commit, Push, Create PR): Replace hardcoded `--base main` with `--base "$base_branch"` in both the draft and non-draft `gh pr create` calls; update the PR submission summary to show `-> leanprover/cslib {base_branch}` instead of `-> leanprover/cslib main` *(completed)*
- [x] Add new STEP 10b after STEP 10: task-mode only -- generate `session_id`, call cslib `update-task-status.sh postflight $input_value pr_ready $session_id`, handle failure gracefully with manual guidance *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - STEPs 5, 8, 9, 10 sections; new STEP 10b (~lines 195-730)

**Verification**:
- [ ] `grep -c "has_pr_description" .claude/extensions/cslib/commands/pr.md` returns >= 4 (used in STEPs 8, 9, and STEP 2 definition)
- [ ] `grep -c 'base main' .claude/extensions/cslib/commands/pr.md` returns 0 (hardcoded --base main removed)
- [ ] `grep -c 'base_branch' .claude/extensions/cslib/commands/pr.md` returns >= 3 (used in STEP 2, STEP 10)
- [ ] `grep -c "STEP 10b\|update-task-status" .claude/extensions/cslib/commands/pr.md` returns >= 2 (new step present)
- [ ] Path-mode and description-mode code blocks are unchanged (spot-check STEP 6, 8, 9 for mode guards)

---

### Phase 4: Update cslib Project Scripts (Cross-Repo) [COMPLETED]

**Goal**: Add `pr_ready` status support to the cslib project's own copies of update-task-status.sh and generate-todo.sh.

**Tasks**:
- [x] In `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh`: add `preflight:pr_ready` and `postflight:pr_ready` cases to the `map_status()` function (after the `postflight:implement` line) *(completed)*
- [x] In `/home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh`: add `pr_ready) printf '%s' "PR READY"` case to the `format_status()` function (after the `planned)` line) *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` - map_status() function (line ~95)
- `/home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` - format_status() function (line ~122)

**IMPORTANT**: These files are in the cslib project (`/home/benjamin/Projects/cslib`), NOT in this repository. Changes cannot be committed via this repo's git workflow. They must be committed separately in the cslib project or noted for manual commit.

**Verification**:
- [ ] `grep -c "pr_ready" /home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` returns >= 2 (preflight + postflight cases)
- [ ] `grep -c "pr_ready\|PR READY" /home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` returns >= 1 (format_status case)
- [ ] `bash -n /home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` exits 0 (syntax valid)
- [ ] `bash -n /home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` exits 0 (syntax valid)

---

### Phase 5: Integration Verification [COMPLETED]

**Goal**: Verify all changes are consistent, no regressions in path/description modes, and the full task-mode flow is coherent end-to-end.

**Tasks**:
- [x] Verify pr.md total structure: grep for all 11 STEPs plus new STEP 10b, confirm sequential ordering *(completed: 12 STEP headings found)*
- [x] Verify no hardcoded `--base main` remains in STEP 10 *(completed: only advisory echo text, all gh pr create calls use $base_branch)*
- [x] Verify no references to nvim config state.json remain *(completed: count=0)*
- [x] Verify path-mode and description-mode are unchanged: diff the non-task-mode sections to confirm no modifications *(completed: path/description mode code preserved in STEP 6, 8, 9)*
- [x] Verify CSLIB_DIR constant is used consistently (not mixed with hardcoded paths) *(completed: 5 references)*
- [x] Verify SKILL.md base_branch documentation is consistent with pr.md's reading logic *(completed: both use same jq pattern and "main" default)*
- [x] Verify cslib scripts syntax with `bash -n` *(completed: both return exit 0)*
- [x] Count total line changes across all files to confirm scope is proportional to plan *(completed: pr.md 887->1053 lines (+166), SKILL.md +20 lines, 2 cslib scripts each +3-4 lines)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- No files modified (verification only)

**Verification**:
- [ ] All Phase 1-4 verification checks pass
- [ ] `grep -c "STEP" .claude/extensions/cslib/commands/pr.md` returns 12 (STEPs 1-11 + 10b)
- [ ] `wc -l .claude/extensions/cslib/commands/pr.md` shows reasonable line count (expect ~950-1000 lines, up from 886)

## Testing & Validation

- [ ] `bash -n` syntax check on all modified shell scripts (cslib update-task-status.sh, generate-todo.sh)
- [ ] `grep` verification that hardcoded nvim state.json path is fully removed from pr.md
- [ ] `grep` verification that `--base main` is replaced with `--base "$base_branch"` in all `gh pr create` calls
- [ ] Manual inspection: STEP 2 task-mode correctly defines CSLIB_DIR, CSLIB_STATE, reads pr-description.md, extracts pr_title, reads base_branch
- [ ] Manual inspection: STEP 8 task-mode skips interactive title selection when has_pr_description is true
- [ ] Manual inspection: STEP 9 task-mode loads pr_body from file when has_pr_description is true
- [ ] Manual inspection: STEP 10b exists and calls update-task-status.sh with pr_ready target
- [ ] Manual inspection: path-mode and description-mode code paths are unchanged

## Artifacts & Outputs

- `specs/674_upgrade_pr_command_task_integration/plans/01_pr-command-plan.md` (this plan)
- `.claude/extensions/cslib/commands/pr.md` (modified: STEPs 2, 5, 8, 9, 10, new 10b)
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` (modified: Stage 7)
- `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` (modified: map_status)
- `/home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` (modified: format_status)

## Rollback/Contingency

All changes are to markdown command files and shell scripts. Rollback via `git checkout` of the two modified files in this repo (pr.md, SKILL.md). The cslib project changes are two small additions to existing case statements and can be reverted independently. No database migrations, no binary artifacts, no deployment concerns.
