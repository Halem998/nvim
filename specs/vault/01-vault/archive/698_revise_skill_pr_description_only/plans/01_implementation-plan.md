# Implementation Plan: Task #698

- **Task**: 698 - Revise skill-pr-implementation to focus exclusively on analyzing changes and producing pr-description.md
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/698_revise_skill_pr_description_only/reports/01_research-pr-skill-scope.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Narrow `skill-pr-implementation` so it only composes `pr-description.md` from task context and git diff analysis, removing all branch creation and CI verification logic. The `/pr` command already owns those responsibilities. Two files need targeted edits: the SKILL.md (6 edits) and the cslib-implementation-agent.md (2 edits).

### Research Integration

The research report identified exact line numbers and replacement text for all 8 edits across 2 files. Key finding: the `/pr` command (STEP 5 and STEP 7) already fully implements branch creation and CI, so the skill's only value is automated composition of `pr-description.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove branch creation and CI verification logic from skill-pr-implementation
- Update delegation context JSON to remove `pr_branch_strategy` and `ci_verification_mode` fields
- Rewrite skill prose to describe the narrowed scope (diff analysis and description composition)
- Add PR Description Mode bypass in cslib-implementation-agent Final Verification Stage
- Ensure the skill directs users to `/pr {N}` instead of `/merge`

**Non-Goals**:
- Modifying the `/pr` command itself (already complete)
- Creating a separate PR-mode agent (conditional block in existing agent is sufficient)
- Changing `pr-description-format.md` or any format standards
- Touching any Lean proof code

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent still runs CI when invoked in PR mode | M | L | Explicit "PR Description Mode (Skip Verification)" block at top of Final Verification Stage |
| Branch creation logic leaks via "Important" paragraph | L | L | Complete rewrite of that paragraph with explicit exclusions |
| Existing MUST NOT items shift numbering | L | M | Carefully insert new items and verify surrounding numbering |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: SKILL.md Revisions [COMPLETED]

**Goal**: Remove branch/CI scope from skill-pr-implementation and narrow to pr-description.md composition only

**Tasks**:
- [ ] Edit 1: Update frontmatter `description` field (line 3) from "PR branch and description preparation" to "PR description preparation for CSLib tasks. Analyzes task description and git diff to produce pr-description.md. Delegates to cslib-implementation-agent and transitions task to [PR READY]. Branch creation and CI are handled by the /pr command."
- [ ] Edit 2: Update Trigger Conditions bullet (lines 15-20) -- replace "A PR branch, pr-description.md, and CI verification are needed" with "A pr-description.md needs to be composed based on the task description and git diff"
- [ ] Edit 3: Replace Stage 3 bullet list (lines 37-40) -- remove "Branch strategy" and "CI verification" bullets, add "Diff analysis" bullet and "Note: Branch creation and CI verification are handled by the /pr command" bullet
- [ ] Edit 4: Remove `pr_branch_strategy` and `ci_verification_mode` fields from the Stage 3 delegation JSON block (lines 42-60)
- [ ] Edit 5: Rewrite Stage 3 "Important" paragraph (lines 63-69) -- replace 5-step list to: (1) Read task description and plan, (2) Run git diff, (3) Compose pr-description.md, (4) Determine base_branch, (5) Write .return-meta.json
- [ ] Edit 6: Update Stage 9 return message (lines 133-136) -- change "Run `/merge`" to "Run `/pr {task_number}`" and adjust lead-in text
- [ ] Edit 7: Add two new MUST NOT items after item 5 -- "Create feature branches" and "Run CI pipeline" with explanations

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` - All 7 edits in this file

**Verification**:
- File parses as valid markdown
- No references to branch creation or CI pipeline remain in skill flow description
- Delegation JSON contains only: session_id, delegation_depth, delegation_path, timeout, task_context, plan_path, orchestrator_mode, metadata_file_path, pr_description_path

---

### Phase 2: cslib-implementation-agent.md Revisions [COMPLETED]

**Goal**: Add PR Description Mode conditional bypass so the agent skips CI when invoked for PR description tasks

**Tasks**:
- [ ] Edit 1: Add "PR Description Mode (Skip Verification)" section at the top of "Final Verification Stage (MANDATORY)" (before the CSLib CI Pipeline steps, around line 128) -- include detection criteria (task_type: "pr" or delegation_path containing skill-pr-implementation), outputs list (pr-description.md and .return-meta.json), and skip instruction with mock verification JSON
- [ ] Edit 2: Add exception clause to MUST DO item 7 (line ~370) -- append "EXCEPT in PR description mode (task_type=pr), where CI is deferred to the `/pr` command"
- [ ] Edit 3: Add exception to MUST NOT item 3 (line ~384) -- append "(exception: PR description mode skips CI by design)"

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - All 3 edits in this file

**Verification**:
- File parses as valid markdown
- PR Description Mode section clearly states skip conditions
- MUST DO and MUST NOT items have appropriate exception clauses

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm both files are syntactically valid and internally consistent

**Tasks**:
- [ ] Read both modified files end-to-end to verify no markdown syntax errors
- [ ] Verify SKILL.md delegation JSON is valid JSON (no trailing commas, matching braces)
- [ ] Verify no stale references to branch creation or CI pipeline remain in the SKILL.md flow stages (Stages 1-9)
- [ ] Verify the "PR Description Mode" section in cslib-implementation-agent.md references correct detection criteria
- [ ] Confirm Stage 9 return message says `/pr {task_number}` not `/merge`

**Timing**: 10 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- All checks pass with no issues found

## Testing & Validation

- [ ] SKILL.md frontmatter description accurately reflects narrowed scope
- [ ] SKILL.md Stage 3 delegation JSON contains no branch/CI fields
- [ ] SKILL.md Stage 3 "Important" paragraph lists only description-composition steps
- [ ] SKILL.md MUST NOT section includes branch creation and CI prohibition items
- [ ] cslib-implementation-agent.md has PR Description Mode bypass block
- [ ] cslib-implementation-agent.md MUST DO item 7 has PR-mode exception
- [ ] No dangling references to `/merge` where `/pr` should be used

## Artifacts & Outputs

- `specs/698_revise_skill_pr_description_only/plans/01_implementation-plan.md` (this plan)
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` (modified)
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` (modified)

## Rollback/Contingency

Both files are version-controlled. If edits introduce inconsistencies:
1. `git checkout -- .claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
2. `git checkout -- .claude/extensions/cslib/agents/cslib-implementation-agent.md`

The changes are purely documentation/configuration edits with no runtime impact until the skill is invoked.
