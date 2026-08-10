# Implementation Plan: Task #650

- **Task**: 650 - Create update-phase-status.sh for phase-level plan tracking
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/650_create_update_phase_status_script/reports/01_phase-status-research.md
- **Artifacts**: plans/01_phase-status-script.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a new `.claude/scripts/update-phase-status.sh` script that updates individual phase status markers (`[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`) in plan file headings. The script parallels the existing `update-plan-status.sh` (which handles plan-level header status) but targets phase headings of the form `### Phase N: {name} [STATUS]`. Integration into `general-implementation-agent.md` replaces the current inline Edit calls at phase boundaries with centralized Bash calls, and a transition log at `.claude/logs/phase-transitions.log` provides oversight visibility.

### Research Integration

Key findings from research report:
- Phase headings use the exact pattern `### Phase N: {name} [STATUS]` with status only in the heading (confirmed by `plan-format-enforcement.md` and actual plan files)
- `general-implementation-agent.md` currently uses inline Edit tool calls at Stage 4A (mark in-progress) and Stage 4D (mark complete) -- these are the primary integration points
- `skill-implementer/SKILL.md` reads `phases_completed` from `.return-meta.json` at postflight but does not directly update phase markers -- integration here is optional and lower priority
- Existing `update-plan-status.sh` provides a proven pattern for plan file discovery, idempotency, and sed-based status replacement
- Log format should follow the `[ISO8601] message` pattern used by `sessions.log` and `subagent-postflight.log`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items directly referenced by this task.

## Goals & Non-Goals

**Goals**:
- Create `update-phase-status.sh` that updates a single phase heading status in a plan file
- Support all valid phase statuses: NOT_STARTED, IN_PROGRESS, COMPLETED, PARTIAL, BLOCKED
- Log every phase transition to `.claude/logs/phase-transitions.log` for oversight
- Be idempotent (no-op when already at target status)
- Integrate with `general-implementation-agent.md` at Stage 4A and 4D phase boundaries
- Document the two-script model (plan-level vs phase-level)

**Non-Goals**:
- Replacing `update-plan-status.sh` (it continues to handle plan-level header status)
- Adding file locking (flock) in this iteration (can be added later if concurrent writes become a real problem)
- Adding log rotation for `phase-transitions.log`
- Modifying `skill-implementer/SKILL.md` postflight logic (read-only consultation of phase markers can be a follow-up)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase heading format varies from spec | M | L | Use regex anchored to `### Phase {N}:` prefix; validate line before replacing |
| sed on macOS vs GNU Linux differences | M | L | Use POSIX-compatible sed patterns; test on target (Linux) |
| Script called with non-existent phase number | L | M | grep returns no match; script exits with non-zero and stderr message |
| Agent integration breaks existing Edit flow | H | L | Add script calls alongside existing pattern; old Edit calls remain as fallback documentation |
| Log file grows unbounded | L | L | Accept for now; same pattern as sessions.log; rotation can be added later |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create update-phase-status.sh script [COMPLETED]

**Goal**: Create the core shell script that finds a plan file, locates a phase heading by number, updates its status marker, and logs the transition.

**Tasks**:
- [x] Create `.claude/scripts/update-phase-status.sh` with the following structure: *(completed)*
  - Accept 4 positional arguments: TASK_NUMBER, PROJECT_NAME, PHASE_NUMBER, NEW_STATUS
  - Validate all inputs are non-empty; print usage to stderr and exit 1 on missing args
  - Normalize NEW_STATUS values (case-insensitive input to canonical display form): IN_PROGRESS -> "IN PROGRESS", NOT_STARTED -> "NOT STARTED", COMPLETED -> "COMPLETED", PARTIAL -> "PARTIAL", BLOCKED -> "BLOCKED"
  - Find plan directory using padded task number (`printf "%03d"`) with fallback to unpadded (same logic as `update-plan-status.sh`)
  - Find latest plan file (`ls -t "$plan_dir"/*.md | head -1`)
  - Use `grep -n "^### Phase ${phase_number}:"` to find the exact line number of the phase heading
  - Extract current status from that line using sed capture: `sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p"`
  - Idempotency check: if current status equals target status, exit 0 silently (no-op)
  - Replace status on the specific line: `sed -i "${line_number}s/\[.*\]/[${new_status_display}]/" "$plan_file"`
  - Verify the replacement succeeded by re-reading the line
  - Append log entry to `.claude/logs/phase-transitions.log`: `[ISO8601] task {N} {plan_basename} phase {P}: {OLD_STATUS} -> {NEW_STATUS}`
  - Output the updated plan file path on success (stdout)
  - Exit 1 on any failure (plan dir not found, phase not found, replacement failed)
- [x] Make the script executable: `chmod +x .claude/scripts/update-phase-status.sh` *(completed)*
- [x] Verify the script passes basic invocation checks (help text on no args, unknown status rejection) *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-phase-status.sh` -- Create new file

**Verification**:
- Script exists and is executable
- Running with no args prints usage and exits 1
- Running with invalid status value prints error and exits 1

---

### Phase 2: Integrate with general-implementation-agent.md [COMPLETED]

**Goal**: Update the implementation agent specification to call `update-phase-status.sh` at phase boundaries (Stage 4A and 4D), replacing the description of inline Edit calls with Bash script invocations.

**Tasks**:
- [x] Read `.claude/agents/general-implementation-agent.md` and locate Stage 4A ("Mark Phase In Progress") and Stage 4D ("Mark Phase Complete") *(completed)*
- [x] In Stage 4A, add a Bash call instruction before or alongside the Edit tool pattern: *(completed)*
  - Add: `bash .claude/scripts/update-phase-status.sh "$task_number" "$PROJECT_NAME" "$phase_number" "IN_PROGRESS"`
  - Keep the existing Edit tool description as the primary mechanism (the script provides logging; the Edit tool remains the agent's direct action)
  - Add a note: "If the Bash call succeeds, the Edit tool call for phase status is redundant but harmless. The script provides centralized logging."
- [x] In Stage 4D, add the corresponding Bash call: *(completed)*
  - Add: `bash .claude/scripts/update-phase-status.sh "$task_number" "$PROJECT_NAME" "$phase_number" "COMPLETED"`
  - Same pattern as Stage 4A: script call plus existing Edit description
- [x] In Stage 4 (Execute File Operations Loop), section E (Handoff on Context Pressure), add a call for PARTIAL status: *(completed)*
  - Add: `bash .claude/scripts/update-phase-status.sh "$task_number" "$PROJECT_NAME" "$phase_number" "PARTIAL"`
  - This marks the phase as PARTIAL when context pressure forces a handoff
- [x] Add a brief note in the "Phase Checkpoint Protocol" section referencing the script for phase-level status updates *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Add Bash calls at Stages 4A, 4D, and 4E

**Verification**:
- Agent spec references `update-phase-status.sh` at Stage 4A, 4D, and 4E
- Existing Edit tool descriptions are preserved (not removed)
- Phase Checkpoint Protocol section mentions the script

---

### Phase 3: Integrate with skill-implementer/SKILL.md [COMPLETED]

**Goal**: Add a lightweight integration in the skill-implementer postflight that can query phase status from the plan file for cross-validation, and document the script in the skill's delegation context.

**Tasks**:
- [x] Read `.claude/skills/skill-implementer/SKILL.md` and locate the delegation context preparation (Stage 4) *(completed)*
- [x] In Stage 4 (Prepare Delegation Context), add a comment noting that `update-phase-status.sh` is available to the subagent for phase-level status updates *(completed)*
- [x] In Stage 6b (Commit Phase Progress), add an optional cross-check comment: after reading `phases_completed` from `.return-meta.json`, the skill could verify by counting `[COMPLETED]` headings in the plan file using `grep -c "^### Phase.*\[COMPLETED\]"` -- add this as a non-blocking verification note (not mandatory logic) *(completed)*
- [x] In the Context References section at the top, add a reference to the new script: `- .claude/scripts/update-phase-status.sh - Phase-level status update script` *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` -- Add references and optional cross-check note

**Verification**:
- SKILL.md references `update-phase-status.sh` in Context References
- Delegation context section mentions the script availability
- Stage 6b includes the optional cross-check comment

---

### Phase 4: Validation and end-to-end test [COMPLETED]

**Goal**: Validate the script works correctly against a real plan file by running it with different status values and verifying the plan file is updated and the log file is created.

**Tasks**:
- [x] Create a temporary test plan file with known phase headings (or use an existing plan file from `specs/*/plans/`) *(completed: used a temporary in-repo test plan)*
- [x] Run `update-phase-status.sh` to transition Phase 1 from NOT STARTED to IN PROGRESS; verify the heading changed *(completed)*
- [x] Run `update-phase-status.sh` to transition Phase 1 from IN PROGRESS to COMPLETED; verify the heading changed *(completed)*
- [x] Run the idempotency check: call COMPLETED again on Phase 1; verify it exits 0 with no changes *(completed)*
- [x] Run with a non-existent phase number; verify it exits 1 with an error message *(completed: fixed grep set-e interaction with || true)*
- [x] Check `.claude/logs/phase-transitions.log` exists and contains the expected log entries with correct format *(completed)*
- [x] Verify the script does not modify the plan-level `**Status**:` header (only phase headings) *(completed)*

**Timing**: 45 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/logs/phase-transitions.log` -- Created as a side effect of running the script

**Verification**:
- All test transitions produce correct plan file updates
- Idempotency works (no-op on duplicate status)
- Error cases produce non-zero exit and stderr messages
- Log file contains properly formatted transition entries
- Plan-level Status header is untouched

## Testing & Validation

- [ ] Script accepts all 5 valid status values and rejects unknown values
- [ ] Script finds plan files in both padded and unpadded directory formats
- [ ] Phase heading update is line-specific (only the targeted phase is modified)
- [ ] Idempotency: calling with current status is a no-op
- [ ] Error handling: missing plan dir, missing plan file, missing phase number all produce stderr + exit 1
- [ ] Log file format matches `[ISO8601] task N filename.md phase P: OLD -> NEW`
- [ ] Agent spec correctly references the script at all three integration points (4A, 4D, 4E)
- [ ] Skill spec references the script in context and delegation sections

## Artifacts & Outputs

- `.claude/scripts/update-phase-status.sh` -- New script (primary deliverable)
- `.claude/agents/general-implementation-agent.md` -- Updated with script calls
- `.claude/skills/skill-implementer/SKILL.md` -- Updated with references
- `.claude/logs/phase-transitions.log` -- Created on first use (side effect)
- `specs/650_create_update_phase_status_script/plans/01_phase-status-script.md` -- This plan
- `specs/650_create_update_phase_status_script/summaries/01_phase-status-script-summary.md` -- Implementation summary

## Rollback/Contingency

The script is a new file with no existing dependencies, so rollback is straightforward:
- Remove `.claude/scripts/update-phase-status.sh`
- Revert changes to `general-implementation-agent.md` (restore original Stage 4A/4D text)
- Revert changes to `skill-implementer/SKILL.md` (remove references)
- The agent's existing inline Edit pattern continues to work without the script
- Delete `.claude/logs/phase-transitions.log` if created
