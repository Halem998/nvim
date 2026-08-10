# Implementation Plan: Task #679

- **Task**: 679 - Research June 2026 TTS best practices for Claude Code hooks
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/679_research_tts_best_practices/reports/01_tts-best-practices.md
- **Artifacts**: plans/01_tts-research-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The research report for task 679 is complete and comprehensive. It covers all four research questions (hook events, deduplication, notification matchers, TTS/tab integration) with concrete recommendations for downstream tasks 680 and 681. This plan verifies the report's completeness and ensures the findings are actionable for those consumers.

### Research Integration

The research report identifies: (1) 30+ Claude Code hook events with no new "AgentComplete" event -- Stop remains canonical, (2) recommended notification matcher update to add `idle_prompt`, (3) deduplication via workflow-active markers + timestamp cooldown, (4) specific code-level fixes for both task 680 (add TTS to Stop hook) and task 681 (remove `--quiet` from orchestrator postflight). All four question areas have concrete, implementable recommendations.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Verify the research report covers all 4 required question areas with actionable detail
- Confirm tasks 680 and 681 have sufficient information to proceed to implementation
- Validate that file paths and code references in recommendations are accurate

**Non-Goals**:
- Implementing any fixes (that is tasks 680 and 681)
- Creating new context files or memory entries beyond what the research report already provides
- Modifying any hook scripts or settings files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Research report references outdated file paths | M | L | Verify paths against current codebase during Phase 1 |
| Downstream tasks 680/681 descriptions may not align with findings | L | L | Cross-check task descriptions against recommendations |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Verify Research Completeness and Cross-Reference Accuracy [COMPLETED]

**Goal**: Confirm the research report is complete, internally consistent, and that all file path references point to real files in the current codebase.

**Tasks**:
- [x] Verify report covers question 1: new hook events beyond Stop/Notification/SubagentStop *(completed)*
- [x] Verify report covers question 2: deduplication and cooldown best practices *(completed)*
- [x] Verify report covers question 3: Notification hook matcher correctness (idle_prompt finding) *(completed)*
- [x] Verify report covers question 4: TTS + terminal tab integration patterns *(completed)*
- [x] Confirm file paths referenced in recommendations exist: `claude-stop-notify.sh`, `orchestrator-postflight.sh`, `lifecycle-notify.sh`, `tts-notify.sh`, `wezterm-notify.sh` *(completed)*
- [x] Confirm task 680 and 681 descriptions align with research recommendations *(completed)*
- [x] Mark task 679 as complete if all checks pass *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- No files modified -- this is a verification-only phase

**Verification**:
- All 4 research questions have concrete answers with code-level recommendations
- All file paths referenced in the report exist in the codebase
- Tasks 680 and 681 descriptions are consistent with research findings

## Testing & Validation

- [x] Each of the 4 research questions has at least one concrete recommendation *(completed)*
- [x] File paths in the recommendations section resolve to existing files *(completed)*
- [x] No contradictions between research findings and downstream task descriptions *(completed)*

## Artifacts & Outputs

- plans/01_tts-research-plan.md (this plan)
- reports/01_tts-best-practices.md (already exists, primary deliverable)

## Rollback/Contingency

If verification reveals gaps in the research report, update the report to address missing areas before marking the task complete. Since the report already exists and is comprehensive, rollback is unlikely to be needed.
