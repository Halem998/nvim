# Implementation Plan: Task #500 - Add context: fork to core skills

- **Task**: 500 - add_context_fork_to_core_skills
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task #499 (completed)
- **Research Inputs**: specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md
- **Artifacts**: plans/01_add-context-fork-skills.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research for task 500 determined that the original task description -- adding `context: fork` frontmatter to core delegating skills -- would break their structured delegation architecture. Core skills (researcher, planner, implementer, reviser, spawn) and extension skills (neovim-research, neovim-implementation, nix-research, nix-implementation) all use Pattern A delegation, which requires skill bodies to execute in the parent conversation for preflight/postflight orchestration. Adding `context: fork` would isolate the skill body as a subagent prompt, preventing structured context injection (session_id, delegation_depth, memory_context, roadmap_context). Task 499 already corrected the documentation that originally motivated this task.

**Recommendation**: Abandon task 500 with no code changes.

### Research Integration

Key findings from the research report (01_add-context-fork-skills.md):

1. **All 5 core skills and all 4 loaded extension skills lack `context: fork` by design** -- they use Pattern A (explicit Task tool with `subagent_type`) with multi-stage preflight/postflight logic.
2. **Adding `context: fork` would break core skills** -- it would prevent skill-level orchestration (status updates, memory retrieval, roadmap injection, artifact linking, git commits) by isolating the skill body from the parent conversation.
3. **Task 499 already resolved the documentation misalignment** -- system-overview.md, thin-wrapper-skill.md template, and fork-patterns.md now all correctly describe why core skills intentionally do NOT use `context: fork`.
4. **No loaded skills qualify for `context: fork`** -- all delegating skills (core and extension) have substantive preflight/postflight logic that requires Pattern A.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Document why task 500 should be abandoned rather than implemented
- Provide clear rationale linking back to task 499 findings and the research report
- Enable clean task closure via `/implement` -> abandon workflow

**Non-Goals**:
- Making any code changes to skill SKILL.md files
- Adding `context: fork` to any skills (core or extension)
- Modifying any documentation files (already done by task 499)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementing task as-described would break core skill delegation | H | H | Abandon task; research conclusively shows this would be harmful |
| Future developer adds `context: fork` to core skill without understanding Pattern A | M | L | fork-patterns.md decision matrix (created by task 499) documents when NOT to use it |
| Confusion about why task was created then abandoned | L | M | This plan and the research report provide full rationale |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Document abandonment rationale and abandon task [NOT STARTED]

**Goal**: Mark task 500 as abandoned with clear documentation of why no code changes are needed.

**Tasks**:
- [ ] Verify task 499 completion status in state.json (confirms the documentation fix is in place)
- [ ] Verify fork-patterns.md exists and documents Pattern A vs Pattern B distinction
- [ ] Update state.json: set task 500 status to "abandoned" with completion_summary explaining that research found the task would break core skill architecture and that task 499 already resolved the underlying documentation gap
- [ ] Update TODO.md: mark task 500 as [ABANDONED]

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `specs/state.json` - Update task 500 status to abandoned with completion_summary
- `specs/TODO.md` - Mark task 500 as [ABANDONED]

**Verification**:
- Task 500 shows [ABANDONED] in TODO.md
- state.json has status "abandoned" and a completion_summary for task 500
- No skill SKILL.md files were modified

## Testing & Validation

- [ ] Confirm task 499 is completed (prerequisite documentation fix)
- [ ] Confirm fork-patterns.md exists at `.claude/context/patterns/fork-patterns.md`
- [ ] Confirm no SKILL.md files have been modified by this task
- [ ] Confirm state.json and TODO.md are synchronized with abandoned status

## Artifacts & Outputs

- `specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md` (existing research report)
- `specs/500_add_context_fork_to_core_skills/plans/01_add-context-fork-skills.md` (this plan)

## Rollback/Contingency

No rollback needed -- this plan makes no code changes. If the task is later determined to have merit (e.g., new Pattern B extension skills are created that would benefit from `context: fork`), a new task should be created with the narrower scope rather than reopening task 500.
