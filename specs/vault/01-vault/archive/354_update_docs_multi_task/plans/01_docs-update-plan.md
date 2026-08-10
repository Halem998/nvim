# Implementation Plan: Update CLAUDE.md Documentation for Multi-Task Support

- **Task**: 354 - Update CLAUDE.md argument-hints and documentation
- **Status**: [COMPLETED]
- **Effort**: 15 minutes
- **Dependencies**: 351, 352, 353
- **Research Inputs**: specs/354_update_docs_multi_task/reports/01_docs-update-scope.md
- **Artifacts**: plans/01_docs-update-plan.md (this file)
- **Standards**: plan-format.md
- **Type**: meta

## Overview

Update the command reference table in `.claude/CLAUDE.md` to reflect the new multi-task syntax (`N[,N-N]`) for `/research`, `/plan`, and `/implement`. The command frontmatter has already been updated by tasks 351-353. This task updates the user-facing documentation.

## Goals & Non-Goals

**Goals**:
- Update command reference table usage column to show multi-task syntax
- Add brief note about multi-task dispatch capability

**Non-Goals**:
- Updating other references to `/research N` in agent/skill docs (these correctly refer to single-task usage)
- Modifying command files (already done by 351-353)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overly verbose syntax in table | L | L | Keep compact: `N[,N-N]` |

## Implementation Phases

### Phase 1: Update Command Reference Table [NOT STARTED]

**Goal:** Update the 3 command entries in `.claude/CLAUDE.md` and add a multi-task note.

**Tasks:**
- [ ] Update `/research` usage to `\`/research N[,N-N] [focus] [--team]\``
- [ ] Update `/plan` usage to `\`/plan N[,N-N] [--team]\``
- [ ] Update `/implement` usage to `\`/implement N[,N-N] [--team] [--force]\``
- [ ] Add brief multi-task note after the command table

**Timing:** 15 minutes

**Files to modify:**
- `.claude/CLAUDE.md` (lines 87-89, plus note insertion)

**Verification:**
- Command table shows multi-task syntax
- Note explains range/comma syntax briefly

## Testing & Validation

- [ ] Command reference table updated with multi-task syntax
- [ ] Brief note about multi-task dispatch added
- [ ] No other files modified

## Artifacts & Outputs

- `.claude/CLAUDE.md` -- updated command reference table

## Rollback/Contingency

Revert the 3 table lines and remove the note. No other files affected.
