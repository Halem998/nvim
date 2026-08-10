# Implementation Summary: Task #333

**Completed**: 2026-03-30
**Duration**: ~15 minutes

## Changes Made

Added Stage 6a plan format verification to `.claude/extensions/founder/agents/founder-plan-agent.md`, mirroring the pattern from the core `planner-agent.md` but with more comprehensive coverage. The new verification step checks all requirements from `plan-format.md` before the agent writes success metadata.

## Files Modified

- `.claude/extensions/founder/agents/founder-plan-agent.md` - Added Stage 6a verification section (lines 638-699) and updated Critical Requirements (added items 8 and 6 to MUST DO/MUST NOT lists)

## Verification

- Build: N/A (markdown file)
- Tests: N/A
- Files verified: Yes - Stage 6a correctly inserted between Stage 6 and Stage 7, Critical Requirements updated

## Details

### Stage 6a Content

The new Stage 6a verifies:
- **8 required metadata fields**: Status, Task, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
- **7 required sections**: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency
- **Phase format**: `### Phase N: {name} [STATUS]` heading pattern
- **Per-phase fields**: Goal, Tasks (checklist), Timing

Includes a bash verification procedure and remediation instructions (edit plan to add missing fields before proceeding).

### Critical Requirements Updates

- MUST DO #8: "Always verify plan format at Stage 6a before writing metadata"
- MUST NOT #6: "Skip plan format verification (Stage 6a)"
