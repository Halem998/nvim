# Implementation Plan: Rewrite Multi-Task Dispatch

- **Task**: 585 - rewrite_multitask_dispatch
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 584 (research_parallel_skill_dispatch) - COMPLETED
- **Research Inputs**: specs/585_rewrite_multitask_dispatch/reports/01_rewrite-multitask-dispatch.md
- **Artifacts**: plans/01_rewrite-multitask-dispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 584 already implemented the core rewrite of multi-task dispatch from parallel Agent tool calls to parallel Skill tool calls across all three command files (research.md, plan.md, implement.md), multi-task-operations.md Section 6, skill-lifecycle.md, and CLAUDE.md. Research confirms all installed copies and canonical copies in extensions/core are synchronized and correct. The remaining work is a minor terminology cleanup in multi-task-operations.md where the Purpose header still says "dispatch parallel agents" instead of "dispatch parallel skills," and a final verification pass to confirm consistency across all files.

### Research Integration

The research report (01_rewrite-multitask-dispatch.md) verified the current state of all seven affected files:
- All three command files Step 3 already say "parallel Skill tool calls"
- multi-task-operations.md Section 6 already uses "Orchestrator-Loop Skill Invocation"
- skill-lifecycle.md has "Parallel Invocation" subsection
- Installed copies match canonical copies in extensions/core
- The only remaining inconsistency is the Purpose header in multi-task-operations.md

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any roadmap items. It is a follow-up to task 584 which completed the architectural change. The "Subagent-return reference cleanup" roadmap item is tangentially related but addresses a different set of stale references.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix the remaining terminology inconsistency in multi-task-operations.md Purpose header
- Sync the fix to the canonical copy in extensions/core
- Verify all dispatch-related documentation is consistent with the new "parallel Skill tool calls" architecture

**Non-Goals**:
- Updating ProofChecker project command files (separate codebase, out of scope)
- Refactoring the command file structure beyond the dispatch terminology
- Adding integration tests for multi-task dispatch

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing a file that has diverged from canonical | L | L | Diff installed vs canonical before editing (already verified as identical) |
| Missing additional stale references in other docs | L | L | grep sweep for "dispatch.*agent" pattern already performed; no problematic results found |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Terminology Cleanup and Sync [COMPLETED]

**Goal**: Fix the remaining stale "dispatch parallel agents" wording in multi-task-operations.md and sync to canonical copy.

**Tasks**:
- [x] Edit `.claude/context/patterns/multi-task-operations.md` line 4: change "dispatch parallel agents" to "dispatch parallel skills" *(completed)*
- [x] Edit `.claude/extensions/core/context/patterns/multi-task-operations.md` line 4: apply the same change to the canonical copy *(completed)*
- [x] Verify both files are still otherwise identical after the edit *(completed: diff returns empty)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/multi-task-operations.md` - Fix Purpose header wording
- `.claude/extensions/core/context/patterns/multi-task-operations.md` - Sync the same fix

**Verification**:
- `grep "Purpose" .claude/context/patterns/multi-task-operations.md` shows "dispatch parallel skills"
- `diff` between installed and canonical copy shows no differences

---

### Phase 2: Final Verification and Completion [COMPLETED]

**Goal**: Run a comprehensive verification pass to confirm all dispatch-related documentation is consistent.

**Tasks**:
- [x] Grep for any remaining "dispatch Agent" or "parallel Agent tool calls" patterns in `.claude/` directory *(completed: zero results)*
- [x] Verify all three command files (research.md, plan.md, implement.md) Step 3 headings say "Dispatch Skills" *(completed: all three confirmed)*
- [x] Verify multi-task-operations.md Section 6 title is "Orchestrator-Loop Skill Invocation" *(completed: confirmed at line 227)*
- [x] Verify skill-lifecycle.md has "Parallel Invocation" section *(completed: confirmed at line 150)*
- [x] Verify CLAUDE.md multi-task syntax description mentions "skill in parallel" *(completed: confirmed)*
- [x] Confirm installed copies match canonical copies in extensions/core for all modified files *(completed: all diffs empty)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only)

**Verification**:
- `grep -rn "dispatch Agent\|parallel Agent tool calls" .claude/ --include="*.md"` returns zero results
- All diff checks between installed and canonical copies return empty

## Testing & Validation

- [ ] `grep -rn "dispatch parallel agents" .claude/` returns zero results after Phase 1
- [ ] `grep -rn "dispatch Agent\|parallel Agent tool calls" .claude/ --include="*.md"` returns zero results
- [ ] `diff .claude/context/patterns/multi-task-operations.md .claude/extensions/core/context/patterns/multi-task-operations.md` produces no output
- [ ] All three command file Step 3 sections contain "parallel Skill tool calls"

## Artifacts & Outputs

- `specs/585_rewrite_multitask_dispatch/plans/01_rewrite-multitask-dispatch.md` (this plan)
- `specs/585_rewrite_multitask_dispatch/summaries/01_rewrite-multitask-dispatch-summary.md` (post-implementation)

## Rollback/Contingency

Changes are limited to a single line edit in one file (plus its canonical copy). Rollback is trivial: revert the Purpose header in multi-task-operations.md to "dispatch parallel agents" in both copies. Since the rest of the architecture is already correct and tested, there is no risk of breaking functionality.
