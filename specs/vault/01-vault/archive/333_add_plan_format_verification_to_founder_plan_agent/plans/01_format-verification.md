# Implementation Plan: Add plan format verification to founder-plan-agent

- **Task**: 333 - Add plan format verification to founder-plan-agent
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_format-verification.md
- **Artifacts**: plans/01_format-verification.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Add a Stage 6a verification checklist to `.claude/extensions/founder/agents/founder-plan-agent.md` that validates plan artifacts contain all required metadata fields and sections before writing success metadata. This mirrors the pattern already established in the core `planner-agent.md` but provides more comprehensive coverage based on `plan-format.md`.

## Goals & Non-Goals

**Goals**:
- Add Stage 6a verification step between Stage 6 (Write Plan File) and Stage 7 (Write Metadata File)
- Verify all 8 required metadata fields from plan-format.md
- Verify all 7 required sections from plan-format.md
- Verify phase heading format and per-phase fields
- Update Critical Requirements to reference the new verification

**Non-Goals**:
- Modifying the core planner-agent.md (separate concern)
- Adding automated test infrastructure
- Changing the plan generation logic in Stage 5

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage numbering conflicts with existing content | Low | Low | Careful insertion between Stage 6 and Stage 7 |
| Overly strict verification rejects valid plans | Medium | Low | Match verification to plan-format.md exactly |

## Implementation Phases

### Phase 1: Add Stage 6a Verification Section [COMPLETED]

**Goal**: Insert a new Stage 6a verification step between Stage 6 and Stage 7 in founder-plan-agent.md

**Tasks**:
- [ ] Read founder-plan-agent.md to identify exact insertion point (after Stage 6, before Stage 7)
- [ ] Create Stage 6a section with metadata field verification (8 fields)
- [ ] Add section verification (7 sections)
- [ ] Add phase format verification (heading format, Goal/Tasks/Timing per phase)
- [ ] Include remediation instructions (edit plan to add missing fields)
- [ ] Insert the new section using Edit tool

**Timing**: 30 minutes

### Phase 2: Update Critical Requirements and Final Verification [COMPLETED]

**Goal**: Update the Critical Requirements section to reference the new verification step and verify the edit

**Tasks**:
- [ ] Add verification-related requirement to MUST DO list
- [ ] Re-read the modified file to verify correct insertion
- [ ] Verify no existing content was damaged

**Timing**: 15 minutes

## Testing & Validation

- [ ] Stage 6a section exists between Stage 6 and Stage 7
- [ ] All 8 metadata fields listed in verification checklist
- [ ] All 7 sections listed in verification checklist
- [ ] Phase format verification included
- [ ] Critical Requirements updated
- [ ] No existing content damaged or removed

## Artifacts & Outputs

- plans/01_format-verification.md (this plan)
- summaries/01_format-verification-summary.md (implementation summary)

## Rollback/Contingency

If implementation fails:
1. Revert founder-plan-agent.md via git checkout
2. The file is version-controlled, so any damage is recoverable
