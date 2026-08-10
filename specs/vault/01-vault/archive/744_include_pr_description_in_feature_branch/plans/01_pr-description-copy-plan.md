# Implementation Plan: Include pr-description.md in Feature Branch

- **Task**: 744 - Include pr-description.md in feature branch during /pr workflow
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: 743 (AI Tools Used standardization)
- **Research Inputs**: specs/744_include_pr_description_in_feature_branch/reports/01_pr-description-copy.md
- **Artifacts**: plans/01_pr-description-copy-plan.md (this file)
- **Standards**: plan-format.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Insert a new STEP 9b in the `/pr` command that copies the approved PR description to the cslib repo root as an unstaged file. This lets the user review the full description alongside the code before pushing.

### Research Integration

Research confirmed the insertion point (between STEP 9 and STEP 10) and that this only applies in task mode when `has_pr_description=true`.

### Prior Plan Reference

No prior plan.

## Goals & Non-Goals

**Goals**:
- Add STEP 9b to pr.md that writes the approved `pr_body` to `$CSLIB_DIR/pr-description.md`
- File must be unstaged (not git-added)
- Only runs in task mode

**Non-Goals**:
- Adding the file to the PR commit
- Supporting path/description modes (no pr-description.md exists for those)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File accidentally committed | L | L | Explicit "do not git add" note; STEP 10 uses `git add -A` which WOULD catch it — add `.gitignore` entry or explicit exclusion |

**Important**: STEP 10 currently uses `git add -A` which would stage the copied file. The step must either: add `pr-description.md` to `.gitignore` before committing, or explicitly `git rm --cached` it after `git add -A`. The simplest approach is to write the file AFTER the commit in STEP 10, but that would lose the "review before pushing" benefit. Instead, write it before STEP 10 and have STEP 10 exclude it.

## Implementation Phases

### Phase 1: Insert STEP 9b and update STEP 10 [IN PROGRESS]

**Goal**: Add the copy step and ensure the file is excluded from the commit.

**Tasks**:
- [ ] Insert STEP 9b between the STEP 9 "On success" line and the STEP 10 heading
- [ ] In STEP 9b: write `pr_body` to `$CSLIB_DIR/pr-description.md` (task mode only)
- [ ] In STEP 10: after `git add -A`, add `git reset HEAD pr-description.md 2>/dev/null || true` to unstage the file

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — insert STEP 9b, modify STEP 10

**Verification**:
- STEP 9b text is present and correctly placed
- STEP 10 includes the unstage command

## Testing & Validation

- [ ] STEP 9b is between STEP 9 and STEP 10 in pr.md
- [ ] STEP 10 includes `git reset HEAD pr-description.md` after `git add -A`

## Artifacts & Outputs

- Modified: `.claude/extensions/cslib/commands/pr.md`

## Rollback/Contingency

```bash
git checkout -- .claude/extensions/cslib/commands/pr.md
```
