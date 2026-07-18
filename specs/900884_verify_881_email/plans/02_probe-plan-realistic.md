# Implementation Plan: Synthetic Verification (email realistic wrapper-only path)

- **Task**: 900884 - verify_881_email
- **Status**: [IMPLEMENTING]
- **Effort**: 0.05 hours
- **Dependencies**: none
- **Research Inputs**: none
- **Artifacts**: this file
- **Standards**: n/a
- **Type**: email

## Overview

Synthetic single-phase, single-step probe plan representing a REALISTIC wrapper-only run: the
only step is a read-only census query (no mutation, no repo-tracked file edited). Used to confirm
email-implementation-agent emits `modified_files: []` for the typical case per Class 3 treatment.

## Goals & Non-Goals

**Goals**: Confirm modified_files is emitted as an explicit empty array on a wrapper-only,
no-repo-file-touching run.
**Non-Goals**: Any mailbox mutation.

## Risks & Mitigations

None (read-only census only; synthetic verification).

## Implementation Phases

### Phase 1: Read-Only Census [NOT STARTED]

**Goal**: Run a single read-only census step; touch no repo-tracked file.

**Tasks**:
- [ ] **Task 1.1**: Run `email-census` (read-only) against `account=gmail` and report the count. No
      `Write`/`Edit` of any repo-tracked file in this phase.

**Timing**: 0.05 hours

**Depends on**: none

**Files to modify**: none.

**Verification**:
- Census ran and produced a count; no file was written.

## Testing & Validation

- [ ] No repo-tracked file was written or edited during this run.

## Artifacts & Outputs

- None.

## Rollback/Contingency

None needed (read-only).
