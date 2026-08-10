# Implementation Plan: Defer Orchestrate Commits to Implementation Cycles

- **Task**: 745 - Modify /orchestrate commit behavior
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/745_defer_orchestrate_commits/reports/01_defer-commits.md
- **Artifacts**: plans/01_defer-commits-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan modifies the /orchestrate commit flow so that git commits happen after each implementation dispatch (or partial with progress) rather than only once at the end. The per-cycle commit bundles all uncommitted artifacts from prior research/plan cycles via `git add -A`. The final CHECKPOINT 3 commit and the multi-task batch commit are made conditional to avoid empty/duplicate commits when per-cycle commits already captured everything.

### Research Integration

Research report (01_defer-commits.md) identified three change locations: (1) skill-orchestrate SKILL.md Stage 5 case block for per-cycle commit insertion, (2) orchestrate.md CHECKPOINT 3 for conditional guard, (3) orchestrate.md Step 5 batch commit for the same conditional guard. The uncommitted-changes check pattern is `! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'` which handles both tracked modifications and untracked new files, including the edge case of empty HEAD.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is an internal agent-system quality improvement.

## Goals & Non-Goals

**Goals**:
- Add per-implementation-cycle commits in skill-orchestrate Stage 5 that bundle all uncommitted artifacts (research, plan, implementation) from the current cycle
- Skip commits for `researched` and `planned` dispatch statuses (those artifacts get bundled into the next implementation commit)
- Make CHECKPOINT 3 final commit conditional on having uncommitted changes
- Make multi-task batch commit conditional on having uncommitted changes
- Maintain non-blocking git failure behavior (log and continue)

**Non-Goals**:
- Adding per-cycle commits to the multi-task parallel dispatch path (Stage MT-4) -- the batch commit in orchestrate.md Step 5 is the correct single commit point for multi-task
- Changing commit message format conventions beyond the new per-cycle messages
- Adding commits after research or plan dispatches

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git diff --quiet HEAD` fails on empty HEAD | L | L | `2>/dev/null` suppresses error; fallback to `git status --porcelain` detects untracked files |
| Double commit (per-cycle + CHECKPOINT 3) | M | M | CHECKPOINT 3 conditional guard prevents this; only fires if something was uncommitted |
| Research/plan artifacts lost if implementation never completes | L | L | Files exist on disk; next orchestrate invocation or manual commit captures them |
| Partial with phases_completed=0 creates empty commit | L | L | Condition `phases_completed > 0` guards against this |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Per-Implementation-Cycle Commit in skill-orchestrate Stage 5 [COMPLETED]

**Goal**: Insert a conditional git commit block after the `case "$dispatch_status"` block in Stage 5 of SKILL.md, so that `implemented` or `partial` (with phases_completed > 0) dispatches trigger a commit bundling all accumulated artifacts.

**Tasks**:
- [ ] In `.claude/skills/skill-orchestrate/SKILL.md`, locate Stage 5 (lines ~371-385), specifically after the closing `esac` of the `case "$dispatch_status"` block and before the artifact linking block (`# Artifact linking`)
- [ ] Insert a new markdown-fenced bash block with the per-cycle commit logic:
  - Set `should_commit=false`
  - If `dispatch_status = "implemented"`, set `should_commit=true`
  - If `dispatch_status = "partial"` AND `phases_completed > 0`, set `should_commit=true`
  - If `should_commit = "true"`, check for uncommitted changes using `! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'`
  - On `implemented`: commit message `task ${task_number}: complete implementation\n\nSession: ${session_id}`
  - On `partial` with progress: commit message `task ${task_number}: implementation progress (${phases_completed}/${phases_total} phases)\n\nSession: ${session_id}`
  - Use `git add -A && git commit -m "$commit_msg"` with `|| echo "[orchestrate] WARNING: Git commit failed (non-blocking)"` for non-blocking failure
  - Log `[orchestrate] No uncommitted changes -- skipping per-cycle commit` when no changes detected
- [ ] Add a comment header above the block: `# Per-implementation-cycle commit: bundle all artifacts from this research+plan+implement cycle`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Insert per-cycle commit block in Stage 5, between the `esac` closing the postflight status update case and the artifact linking section

**Verification**:
- The new block appears after the `esac` and before `# Artifact linking`
- The block only triggers for `implemented` or `partial` with `phases_completed > 0`
- Commit messages follow the `task {N}: {action}` convention with session ID
- Git failure is non-blocking (uses `||` with warning echo)

---

### Phase 2: Make CHECKPOINT 3 Conditional in orchestrate.md [COMPLETED]

**Goal**: Wrap the CHECKPOINT 3 commit blocks (both "On completion" and "On partial" variants) with an uncommitted-changes guard so they only fire when there are actual changes to commit.

**Tasks**:
- [ ] In `.claude/commands/orchestrate.md`, locate CHECKPOINT 3 (lines ~371-387)
- [ ] Wrap both the "On completion" and "On partial" commit blocks inside a conditional check:
  - Add `if ! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'; then` before the commit commands
  - Add `else` with `echo "[orchestrate] No uncommitted changes after orchestration -- skipping final commit"` message
  - Add closing `fi`
- [ ] Keep the existing "Commit failure is non-blocking (log and continue)." note

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/orchestrate.md` - Wrap CHECKPOINT 3 commit blocks with conditional guard

**Verification**:
- Both commit variants (completion and partial) are inside the conditional guard
- The guard uses the same pattern as Phase 1: `! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'`
- The "non-blocking" note is preserved
- An else branch logs when no commit is needed

---

### Phase 3: Make Multi-Task Batch Commit Conditional in orchestrate.md [COMPLETED]

**Goal**: Wrap the Step 5 batch commit blocks (both "full success" and "partial success" variants) with the same uncommitted-changes guard.

**Tasks**:
- [ ] In `.claude/commands/orchestrate.md`, locate Step 5 batch commit section (lines ~246-264)
- [ ] Wrap both the "Full success" and "Partial success" commit blocks inside the conditional check:
  - Add `if ! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'; then` before the commit commands
  - Add `else` with `echo "[orchestrate] No uncommitted changes after batch orchestration -- skipping batch commit"` message
  - Add closing `fi`

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/orchestrate.md` - Wrap Step 5 batch commit blocks with conditional guard

**Verification**:
- Both batch commit variants (full and partial success) are inside the conditional guard
- The guard pattern is identical to Phase 1 and Phase 2
- An else branch logs when no commit is needed

## Testing & Validation

- [ ] Read modified SKILL.md Stage 5 and confirm the per-cycle commit block is correctly placed between `esac` and artifact linking
- [ ] Read modified orchestrate.md CHECKPOINT 3 and confirm both commit variants are wrapped with the conditional guard
- [ ] Read modified orchestrate.md Step 5 and confirm both batch commit variants are wrapped with the conditional guard
- [ ] Verify commit message format follows `task {N}: {action}` convention
- [ ] Verify all three locations use the identical uncommitted-changes check pattern
- [ ] Confirm no changes were made to Stage MT-4 (multi-task parallel dispatch path)

## Artifacts & Outputs

- plans/01_defer-commits-plan.md (this plan)
- summaries/01_defer-commits-summary.md (post-implementation)
- Modified files:
  - `.claude/skills/skill-orchestrate/SKILL.md`
  - `.claude/commands/orchestrate.md`

## Rollback/Contingency

Both files are under git version control. If the changes cause issues:
1. `git diff .claude/skills/skill-orchestrate/SKILL.md .claude/commands/orchestrate.md` to review changes
2. `git checkout -- .claude/skills/skill-orchestrate/SKILL.md .claude/commands/orchestrate.md` to revert
3. The original single-commit-at-end behavior is fully restored
