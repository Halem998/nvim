# Implementation Plan: Task #495

- **Task**: 495 - Add multi-subagent continuation loop to skill-implementer
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: `specs/495_multi_subagent_continuation_loop/reports/01_continuation-research.md`
- **Artifacts**: `specs/495_multi_subagent_continuation_loop/plans/01_continuation-plan.md` (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the manual user-blocking partial-return behavior in `skill-implementer` with an automatic multi-subagent continuation loop. Wire the existing but unused `handoff-artifact.md` and `progress-file.md` formats into `general-implementation-agent` so that agents can detect context exhaustion, write structured handoffs, and return partial status with `handoff_path`. The skill will then detect `handoff_path` in partial metadata and spawn successor subagents with injected handoff context, up to a maximum of 3 continuations.

### Research Integration

The research report identified seven gaps:
1. Agent lacks handoff/progress file instructions
2. Agent lacks context exhaustion detection heuristics
3. Skill lacks continuation loop logic
4. Skill cleanup removes metadata too early for loop iterations
5. Postflight marker conflicts with continuation
6. Git commit strategy needs per-subagent commits
7. No `continuation_count` tracking

This plan addresses all seven gaps across four phases.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No direct roadmap items reference this task. The work advances the implicit goal of reducing user intervention during long-running implementations.

## Goals & Non-Goals

**Goals**:
- Enable `general-implementation-agent` to write progress files and handoff artifacts
- Enable `general-implementation-agent` to detect context exhaustion and trigger handoffs
- Add automatic continuation loop to `skill-implementer` that spawns successors from handoff artifacts
- Preserve session_id and artifact numbering across continuation chain
- Limit continuations to 3 to align with existing loop guard convention

**Non-Goals**:
- Parallel multi-agent execution (that is `skill-team-implement` scope)
- Modifying the postflight loop guard in `postflight-control.md`
- Changing how team mode handles context exhaustion
- Adding a user-facing `--max-continuations` flag

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Infinite continuation loop | High | Low | Hard limit of 3 continuations stored in task directory loop-guard file |
| Token cost explosion | High | Low | Each continuation spawns a fresh agent; limit 3; no plans to expose flag |
| Handoff artifact missing or malformed | Medium | Medium | Skill falls back to progress file + plan file; if both missing, report partial and require user resume |
| Successor re-does completed work | Medium | Low | Progress file marks objectives as `done`; agent instructions say "skip done objectives" |
| Git history bloat | Low | Low | Per-phase commits are already the intended checkpoint protocol |
| Postflight marker removed too early | Medium | Low | Move cleanup to after the loop; marker persists across continuations |
| Race condition with user re-running `/implement` | Low | Low | Session ID check in state.json; if session_id changes mid-loop, abort continuation |
| Context exhaustion during handoff writing | Low | Low | Handoff is short (~40 lines); write before any large file operations |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire Handoff/Progress Formats into General-Implementation-Agent [COMPLETED]

**Goal**: Teach the agent to track progress, detect context pressure, and write handoff artifacts before returning partial.

**Tasks**:
- [ ] Add **Stage 3.5: Initialize Progress Tracking**
  - After finding resume phase, create `specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`
  - Populate objectives from plan file steps
  - Set `handoff_count` to current value (read existing progress file if resuming)
- [ ] Add **Stage 4.5: Context Exhaustion Detection**
  - Add guidance for monitoring context pressure:
    - "After every 10 tool calls, assess whether you have sufficient context remaining"
    - "If you find yourself re-reading files you already read, this is a signal of context pressure"
    - "Before starting any operation that reads 3+ files, check if a handoff would be safer"
- [ ] Add **Stage 4B: Update Progress File**
  - After completing each objective/step, update the progress file:
    - Set objective status to `done` or `in_progress`
    - Update `current_objective`
    - Update `last_updated`
  - Before attempting a risky approach, add to `approaches_tried` if it fails
- [ ] Add **Stage 4C: Handoff on Context Pressure**
  - When approaching context limits (~80% or before a large operation):
    1. Update progress file to reflect current state
    2. Write handoff artifact to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
    3. Increment `handoff_count` in progress file
    4. Return `partial` status with `handoff_path` in `partial_progress`
- [ ] Modify **Stage 7: Write Metadata File**
  - If returning `partial` and handoff was written, include `handoff_path`, `phases_completed`, and `phases_total` in `partial_progress`

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.opencode/agent/subagents/general-implementation-agent.md` - Add stages 3.5, 4.5, 4B, 4C; modify Stage 7

**Verification**:
- Read modified agent file and confirm all new stages are documented with clear instructions
- Confirm handoff artifact schema matches `handoff-artifact.md`
- Confirm progress file schema matches `progress-file.md`
- Confirm metadata partial_progress includes `handoff_path` field

---

### Phase 2: Add Continuation Loop to Skill-Implementer [COMPLETED]

**Goal**: Restructure skill postflight into a loop that detects partial handoffs and spawns successor subagents automatically.

**Tasks**:
- [ ] Add **Stage 5c: Continuation Loop Init**
  - Initialize `continuation_count=0`
  - Max continuations = 3
  - Create `.continuation-loop-guard` file in task directory to track count across potential interruptions
- [ ] Restructure **Postflight into Continuation Loop**
  - Wrap Stages 6, 6a, 7, and 9 inside a loop
  - After Stage 6a, add **Stage 6b: Commit Phase Progress** (inside loop):
    - `git add -A`
    - `git commit -m "task {N} phase {P}: {phase_name}\n\nSession: {session_id}\n"`
  - Modify **Stage 7** loop logic:
    - If `status == "implemented"`: break loop, proceed to final postflight
    - If `status == "partial"` and `handoff_path` exists and `continuation_count < 3`:
      - `continuation_count += 1`
      - Read handoff artifact (for logging)
      - Prepare successor delegation context:
        - Same `session_id`
        - `delegation_depth += 1`
        - Include `handoff_path` and progress file path
        - Add `continuation_context` field: `{ is_successor: true, continuation_number: N, handoff_path: "...", progress_path: "...", previous_phases_completed: N }`
      - Spawn successor subagent (goto Stage 5)
      - Continue loop (next iteration reads successor metadata)
    - If `status == "partial"` and no `handoff_path`: break loop, report partial (user must resume)
    - If `status == "partial"` and `continuation_count >= 3`: break loop, report partial (max reached)
    - If `status == "failed"`: break loop, report failed
- [ ] Modify **Stage 10: Cleanup**
  - Move cleanup to AFTER the continuation loop exits
  - Ensure `.postflight-pending` marker persists across loop iterations
  - Remove `.continuation-loop-guard` in final cleanup
- [ ] Remove the **PROHIBITION** on continuation (line 503 of current skill file)
  - Replace with: "If the subagent returned partial status WITH a handoff_path, the lead skill MAY spawn a successor subagent to continue. If no handoff_path is present, report partial and let the user re-run `/implement` to resume."

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-implementer/SKILL.md` - Restructure postflight into loop, add continuation stages, modify cleanup

**Verification**:
- Read modified skill file and confirm loop structure is documented
- Confirm successor delegation context includes all required fields
- Confirm max continuation limit is enforced
- Confirm cleanup happens after loop exit
- Confirm prohibition text is updated

---

### Phase 3: Testing and Validation [COMPLETED]

**Goal**: Verify the continuation loop works correctly and edge cases are handled.

**Tasks**:
- [ ] Create a mock task with a multi-phase plan to test continuation logic
- [ ] Test that agent writes progress file at phase start
- [ ] Test that agent writes handoff artifact when simulating context pressure
- [ ] Test that skill detects `handoff_path` in partial metadata
- [ ] Test that skill spawns successor with correct delegation context
- [ ] Test that continuation count increments and stops at 3
- [ ] Test fallback behavior when `handoff_path` is missing (user resume required)
- [ ] Test that session_id and artifact_number are preserved across continuations
- [ ] Test that per-continuation git commits are created
- [ ] Test that cleanup only happens after final loop exit

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Files to modify**:
- No file modifications; this is validation work
- May create temporary test task directories under `specs/`

**Verification**:
- All test scenarios pass
- No regression in normal (non-continuation) implementation flow
- Edge cases (missing handoff, max continuations, failed status) behave correctly

---

### Phase 4: Documentation and Pattern Creation [COMPLETED]

**Goal**: Document the continuation loop pattern for reuse by other skills.

**Tasks**:
- [ ] Create `.opencode/context/patterns/subagent-continuation-loop.md`
  - Document loop structure: detect partial -> read handoff -> spawn successor -> repeat
  - Document max-continuation limits and loop-guard file convention
  - Document successor delegation context schema
  - Document handoff consumption by successors
- [ ] Create `.opencode/context/patterns/context-exhaustion-detection.md`
  - Document tool-call counting guidelines
  - Document re-read detection signals
  - Document handoff trigger thresholds
- [ ] Update cross-references in `general-implementation-agent.md` and `skill-implementer.md` to point to new pattern docs

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Files to create**:
- `.opencode/context/patterns/subagent-continuation-loop.md`
- `.opencode/context/patterns/context-exhaustion-detection.md`

**Files to modify**:
- `.opencode/agent/subagents/general-implementation-agent.md` - Add cross-references to new patterns
- `.opencode/skills/skill-implementer/SKILL.md` - Add cross-references to new patterns

**Verification**:
- New pattern files follow existing pattern documentation style
- Cross-references are valid paths
- Pattern docs are discoverable from agent and skill files

## Testing & Validation

- [ ] Agent writes progress file at phase start with correct schema
- [ ] Agent updates progress file after each objective completion
- [ ] Agent writes handoff artifact with correct schema when context pressure detected
- [ ] Agent includes `handoff_path` in partial metadata
- [ ] Skill detects `handoff_path` and enters continuation loop
- [ ] Skill spawns successor with `continuation_context.is_successor = true`
- [ ] Skill increments `continuation_count` each iteration
- [ ] Skill stops at max 3 continuations
- [ ] Skill commits after each subagent completes (per-continuation commit)
- [ ] Skill performs final cleanup only after loop exit
- [ ] Normal non-continuation flow remains unchanged
- [ ] Missing handoff_path falls back to user resume

## Artifacts & Outputs

- `.opencode/agent/subagents/general-implementation-agent.md` - Updated with progress tracking and handoff stages
- `.opencode/skills/skill-implementer/SKILL.md` - Updated with continuation loop
- `.opencode/context/patterns/subagent-continuation-loop.md` - New pattern documentation
- `.opencode/context/patterns/context-exhaustion-detection.md` - New pattern documentation
- `specs/495_multi_subagent_continuation_loop/plans/01_continuation-plan.md` - This plan

## Rollback/Contingency

If the continuation loop causes instability:
1. Revert `skill-implementer/SKILL.md` to the pre-loop version using git
2. Revert `general-implementation-agent.md` to the pre-handoff version using git
3. Remove any newly created pattern files
4. The system will fall back to the current behavior: user manually re-runs `/implement` on partial returns

If only Phase 1 is completed and Phase 2 is blocked, the agent will still write handoff/progress files, but the skill will not auto-continue. This is a safe partial state with no regression.
