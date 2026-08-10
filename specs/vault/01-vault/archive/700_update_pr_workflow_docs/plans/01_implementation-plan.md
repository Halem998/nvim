# Implementation Plan: Update PR Workflow Documentation

- **Task**: 700 - Update PR workflow documentation
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: 698 (skill-pr-implementation revision), 699 (/pr command revision)
- **Research Inputs**: specs/700_update_pr_workflow_docs/reports/01_research-pr-docs-update.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update 4 documentation files to reflect the revised PR workflow separation established by tasks 698 and 699. skill-pr-implementation now produces only pr-description.md (no branch creation, no CI), while the /pr command handles branch creation, cache fetch, CI pipeline, and PR submission. Changes are purely documentation (string/text updates); no behavioral code is modified.

### Research Integration

Research report (01_research-pr-docs-update.md) identified 4 files needing updates with specific line numbers and exact replacement text. manifest.json routing and cslib-implementation-agent.md were confirmed correct and excluded from scope.

## Goals & Non-Goals

**Goals**:
- Update EXTENSION.md skill table to accurately describe skill-pr-implementation scope
- Add CSLib-specific /pr workflow documentation to pr-prohibition.md (both copies)
- Remove stale references to skill-pr-implementation creating branches in pr.md
- Keep both pr-prohibition.md copies (core extension + project-level) in sync

**Non-Goals**:
- Modifying manifest.json routing (confirmed correct)
- Changing cslib-implementation-agent.md (already updated by task 698)
- Altering any behavioral logic or scripts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| pr-prohibition.md copies drifting out of sync | M | L | Update both in same phase |
| EXTENSION.md table description too long for readability | L | L | Keep to single line with concise wording |
| pr.md line numbers shifted since research | M | M | Grep for exact strings rather than relying on line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: EXTENSION.md Skill Table Update [COMPLETED]

**Goal**: Update the skill-pr-implementation description to reflect its new scope (description-only, no branch/CI).

**Tasks**:
- [ ] Open `.claude/extensions/cslib/EXTENSION.md`
- [ ] Locate the skill-pr-implementation row in the skill table (line ~18)
- [ ] Change description from `PR branch/description preparation, transitions task to [PR READY]` to `PR description preparation only -- produces pr-description.md, transitions task to [PR READY]; branch creation and CI handled by /pr`
- [ ] Verify table formatting is preserved (pipes aligned, single row)

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` - Skill table row for skill-pr-implementation

**Verification**:
- Grep for "PR description preparation only" in EXTENSION.md confirms update
- Table still renders correctly (pipe-delimited columns intact)

---

### Phase 2: pr-prohibition.md Updates (Both Copies) [COMPLETED]

**Goal**: Add a "CSLib Extension: /pr Command" section to both pr-prohibition.md copies explaining the two-step workflow.

**Tasks**:
- [ ] Open `.claude/extensions/core/rules/pr-prohibition.md`
- [ ] Add the following section after the "Rationale" section at the end of the file:

```markdown
## CSLib Extension: /pr Command

For tasks with `task_type: "pr"` (CSLib pull request tasks), the workflow differs from the
general `/merge` flow:

1. **skill-pr-implementation** (invoked via `/implement N`): Analyzes the git diff and
   composes `specs/{NNN}_{SLUG}/pr-description.md`. Transitions the task to `[PR READY]`.
   Does NOT create branches or run CI.

2. **`/pr {task_number}`** (user-invoked command): The single entry point for branch
   creation, Mathlib cache fetch, the 7-step CI pipeline, PR title confirmation, and
   `gh pr create` submission.

The prohibition on agent-created PRs and agent pushes still applies. Only step 2 (the
user-invoked `/pr` command) performs git push and PR creation.
```

- [ ] Open `.claude/rules/pr-prohibition.md` (project-level copy)
- [ ] Apply the identical addition after the "Rationale" section
- [ ] Verify both files are byte-identical by diffing them

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/rules/pr-prohibition.md` - Add CSLib workflow section
- `.claude/rules/pr-prohibition.md` - Add identical CSLib workflow section (keep in sync)

**Verification**:
- `diff .claude/extensions/core/rules/pr-prohibition.md .claude/rules/pr-prohibition.md` returns no output
- Grep for "CSLib Extension: /pr Command" in both files confirms section exists
- Core prohibition text ("Agents MUST NOT") remains unchanged above the new section

---

### Phase 3: pr.md Stale Reference Fixes [COMPLETED]

**Goal**: Remove 3 stale references in pr.md that attribute branch creation to skill-pr-implementation.

**Tasks**:
- [ ] Open `.claude/extensions/cslib/commands/pr.md`
- [ ] Find the string `as would be created by \`skill-pr-implementation\`` (around line 272) and change to `from a previous /pr run or manual branch creation`
- [ ] Find the string `Branch '$proposed_branch' already exists (created by skill-pr-implementation).` (around line 274) and change to `Branch '$proposed_branch' already exists.`
- [ ] Find the string `(if created by skill-pr-implementation)` (around line 287) and change to `(if previously created)`
- [ ] Verify no other references to skill-pr-implementation creating branches remain

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - 3 string replacements removing stale branch attribution

**Verification**:
- `grep -n "created by skill-pr-implementation" .claude/extensions/cslib/commands/pr.md` returns no results
- The surrounding context/logic remains intact (only string content changed, not code structure)

---

### Phase 4: Verification [COMPLETED]

**Goal**: Confirm all changes are consistent and no stale references remain across the codebase.

**Tasks**:
- [ ] Run `grep -r "PR branch/description" .claude/` to confirm old EXTENSION.md description is gone
- [ ] Run `grep -r "created by skill-pr-implementation" .claude/` to confirm all stale branch-creation references are removed
- [ ] Run `diff .claude/extensions/core/rules/pr-prohibition.md .claude/rules/pr-prohibition.md` to confirm both copies are identical
- [ ] Verify manifest.json routing is unchanged: `grep -A2 '"implement"' .claude/extensions/cslib/manifest.json` still shows `"pr": "skill-pr-implementation"`
- [ ] Read the new CSLib section in pr-prohibition.md to verify it does not contradict the core prohibition

**Timing**: 10 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (read-only verification)

**Verification**:
- All grep checks pass with expected output
- No contradictions found between old prohibition text and new CSLib section

## Testing & Validation

- [ ] `grep -r "PR branch/description" .claude/` returns no results
- [ ] `grep -r "created by skill-pr-implementation" .claude/` returns no results
- [ ] `diff .claude/extensions/core/rules/pr-prohibition.md .claude/rules/pr-prohibition.md` shows no differences
- [ ] EXTENSION.md skill table renders correctly with updated description
- [ ] manifest.json routing for `pr` task type unchanged

## Artifacts & Outputs

- plans/01_implementation-plan.md (this file)
- summaries/01_pr-docs-update-summary.md (after implementation)

## Rollback/Contingency

All changes are documentation-only text edits. Rollback is trivial via `git checkout` of the 4 affected files:
- `.claude/extensions/cslib/EXTENSION.md`
- `.claude/extensions/core/rules/pr-prohibition.md`
- `.claude/rules/pr-prohibition.md`
- `.claude/extensions/cslib/commands/pr.md`
