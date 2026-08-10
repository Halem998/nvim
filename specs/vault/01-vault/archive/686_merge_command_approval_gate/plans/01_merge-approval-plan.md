# Implementation Plan: Add User Approval Gate to /merge Command

- **Task**: 686 - Add user approval gate to /merge command
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/686_merge_command_approval_gate/reports/01_merge-approval-research.md
- **Artifacts**: plans/01_merge-approval-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add two safety mechanisms to the `/merge` command: (1) a user-only prohibition preventing agents from invoking it autonomously, and (2) an AskUserQuestion approval gate between branch validation and push, allowing users to review branch, target, commit summary, and choose to proceed, submit as draft, or cancel. Both `.claude/commands/merge.md` and `.claude/extensions/core/commands/merge.md` are byte-identical and must receive the same changes.

### Research Integration

The research report confirmed the current 6-step flow, identified the insertion point between STEP 3 (Validate Branch) and STEP 4 (Push to Origin), and provided the full AskUserQuestion pattern adapted from the cslib `/pr` command with three options (Yes/Draft/Cancel). The user-only prohibition pattern was extracted from `/tag` with three components: frontmatter suffix, header block, and Agent Restrictions section. The report also confirmed both merge.md copies are byte-identical and no separate skill file exists.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task.

## Goals & Non-Goals

**Goals**:
- Add AskUserQuestion confirmation gate showing branch, target, commit count, and commit log before push
- Support three response options: proceed, submit as draft, cancel
- Add user-only prohibition markers (frontmatter, header, Agent Restrictions section)
- Keep both merge.md copies in sync with identical changes

**Non-Goals**:
- Modifying CLAUDE.md or merge-sources directly (auto-generated; updating claudemd.md merge-source is sufficient)
- Adding hook-based enforcement of the user-only prohibition
- Changing the PR/MR creation logic itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Step renumbering introduces off-by-one in continuation references | M | M | Audit all 5 "IMMEDIATELY CONTINUE" lines systematically |
| Extension core copy drifts from main copy | M | L | Update both files in same phase, verify with diff |
| Agents ignore user-only prohibition | L | L | Documentation-only enforcement matches /tag precedent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add User-Only Prohibition to merge.md [COMPLETED]

**Goal**: Mark `/merge` as a user-only command using the three-component pattern from `/tag`.

**Tasks**:
- [ ] Update frontmatter `description` in `.claude/commands/merge.md` to append `(user-only)`
- [ ] Add `**User Only**: YES - Agents MUST NOT invoke this command autonomously. PR/MR creation is a user-controlled decision.` after the opening paragraph of the command body
- [ ] Add an `## Agent Restrictions` section before "Related Commands" (or at the end if no Related Commands exists) with the prohibition text: "Agents MUST NOT invoke /merge autonomously. PR/MR creation timing and targeting are user-controlled decisions."
- [ ] Update `.claude/extensions/core/merge-sources/claudemd.md` line for `/merge` to add "(user-only)" to the description column

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/merge.md` - Add user-only frontmatter suffix, header block, and Agent Restrictions section
- `.claude/extensions/core/merge-sources/claudemd.md` - Add "(user-only)" to /merge description

**Verification**:
- `grep -q "user-only" .claude/commands/merge.md` returns success
- `grep -q "Agent Restrictions" .claude/commands/merge.md` returns success
- `grep "merge" .claude/extensions/core/merge-sources/claudemd.md` shows "(user-only)" in description

---

### Phase 2: Insert AskUserQuestion Approval Gate and Renumber Steps [COMPLETED]

**Goal**: Insert new STEP 4 (User Approval) between current STEP 3 and STEP 4, renumber all subsequent steps, and update all "IMMEDIATELY CONTINUE" cross-references.

**Tasks**:
- [ ] After STEP 3's "IMMEDIATELY CONTINUE to STEP 4" line, insert the new STEP 4 (User Approval) block containing:
  - Git commands to gather commit count and commit log (`git rev-list --count`, `git log --oneline`, capped at 20 lines)
  - Merge summary display (platform, branch, target, draft status, commit count, commit log)
  - AskUserQuestion call with three options: "Yes, push and create {PR_type}", "Submit as draft", "Cancel"
  - Response handling: Yes continues to STEP 5, Draft sets draft=true then continues to STEP 5, Cancel stops with message
- [ ] Renumber old STEP 4 (Push to Origin) to STEP 5
- [ ] Renumber old STEP 5 (Create PR/MR) to STEP 6
- [ ] Renumber old STEP 6 (Report Results) to STEP 7
- [ ] Update all "IMMEDIATELY CONTINUE to STEP N" references throughout the file:
  - STEP 3: already says "STEP 4" (correct after renumbering, since new STEP 4 is the approval gate)
  - New STEP 4: uses "STEP 5" for proceed paths
  - STEP 5 (old 4): change "STEP 5" to "STEP 6"
  - STEP 6 (old 5): change "STEP 6" to "STEP 7"
  - STEP 7 (old 6): terminal (STOP), no continuation reference
- [ ] Verify the step count reference in any preamble text is updated from "6 steps" to "7 steps" if present

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/merge.md` - Insert new STEP 4, renumber STEPs 5-7, update all cross-references

**Verification**:
- `grep -c "^### STEP" .claude/commands/merge.md` returns 7
- `grep "AskUserQuestion" .claude/commands/merge.md` finds the approval gate
- `grep "IMMEDIATELY CONTINUE" .claude/commands/merge.md` shows correct step numbers (no references to nonexistent steps)
- All step transitions are sequential (no skips or duplicates)

---

### Phase 3: Sync Extension Core Copy [COMPLETED]

**Goal**: Make `.claude/extensions/core/commands/merge.md` identical to the updated `.claude/commands/merge.md`.

**Tasks**:
- [ ] Copy the fully updated `.claude/commands/merge.md` to `.claude/extensions/core/commands/merge.md`
- [ ] Verify both files are byte-identical with `diff`

**Timing**: 5 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/commands/merge.md` - Full replacement with updated content from `.claude/commands/merge.md`

**Verification**:
- `diff .claude/commands/merge.md .claude/extensions/core/commands/merge.md` produces no output
- Both files have the same line count and contain all 7 steps

## Testing & Validation

- [ ] Both merge.md copies are byte-identical (`diff` produces no output)
- [ ] New STEP 4 contains AskUserQuestion with three options (Yes/Draft/Cancel)
- [ ] Step count is 7 (verified by `grep -c "^### STEP"`)
- [ ] All "IMMEDIATELY CONTINUE" references point to valid, sequential step numbers
- [ ] Frontmatter description contains "(user-only)"
- [ ] Agent Restrictions section exists
- [ ] `claudemd.md` merge-source has "(user-only)" in the /merge row

## Artifacts & Outputs

- `specs/686_merge_command_approval_gate/plans/01_merge-approval-plan.md` (this file)
- Modified files (during implementation):
  - `.claude/commands/merge.md`
  - `.claude/extensions/core/commands/merge.md`
  - `.claude/extensions/core/merge-sources/claudemd.md`

## Rollback/Contingency

All changes are to markdown command files with no runtime dependencies. Rollback via `git checkout -- .claude/commands/merge.md .claude/extensions/core/commands/merge.md .claude/extensions/core/merge-sources/claudemd.md` restores the original state immediately. No build or configuration state is affected.
