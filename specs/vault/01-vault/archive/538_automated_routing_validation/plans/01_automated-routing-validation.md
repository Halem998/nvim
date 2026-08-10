# Implementation Plan: Automated Routing Table Validation
- **Task**: 538 - automated_routing_validation
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #534
- **Research Inputs**: specs/534_sync_extension_routing_tables/reports/01_routing-tables-research.md
- **Artifacts**: plans/01_automated-routing-validation.md
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/status-markers.md
- **Type**: markdown

## Overview

Create `.opencode/scripts/validate-routing-tables.sh` that parses extension manifests and validates command docs include all task types. Integrate into pre-commit or CI to prevent future routing table drift.

## Goals & Non-Goals

- **Goals**:
  - Script parses all extension manifests
  - Script extracts task types from routing.implement, routing.research, routing.plan
  - Script parses command docs and extracts routing tables
  - Script reports missing entries (in docs but not manifests, or vice versa)
  - Script exits non-zero on validation failure
  - Integrate into CI/pre-commit

- **Non-Goals**:
  - No modification of command docs (Task 534 handles that)
  - No validation of .claude/ mirrors (they are auto-generated)

## Risks & Mitigations

- **Risk**: Command docs use markdown tables which are hard to parse reliably. Mitigation: Use simple regex patterns, document limitations.
- **Risk**: Manifests may have no routing section. Mitigation: Skip manifests with empty routing.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Create validation script [NOT STARTED]
- **Goal**: Implement validate-routing-tables.sh
- **Tasks**:
  - [ ] Parse all manifests in .opencode/extensions/*/manifest.json
  - [ ] Extract task types from routing.implement, routing.research, routing.plan
  - [ ] Parse command docs and extract routing tables
  - [ ] Compare and report discrepancies
  - [ ] Exit non-zero on mismatch
- **Timing**: 1-2 hours
- **Depends on**: none

### Phase 2: Test script [NOT STARTED]
- **Goal**: Verify script catches current mismatches
- **Tasks**:
  - [ ] Run script against current state
  - [ ] Verify it reports correctly
  - [ ] Fix any false positives
- **Timing**: 30 minutes
- **Depends on**: 1

### Phase 3: Integrate into CI [NOT STARTED]
- **Goal**: Add to pre-commit or CI pipeline
- **Tasks**:
  - [ ] Add to .pre-commit-config.yaml or equivalent
  - [ ] Document usage
- **Timing**: 30 minutes
- **Depends on**: 2

## Testing & Validation

- [x] Script runs successfully
- [x] Script catches missing entries (48 found)
- [ ] Script exits 0 when tables are in sync
- [x] Script exits non-zero when tables are out of sync

## Artifacts & Outputs

- `.opencode/scripts/validate-routing-tables.sh`
- This plan file

## Rollback/Contingency

- Remove script from CI
- Delete script file
