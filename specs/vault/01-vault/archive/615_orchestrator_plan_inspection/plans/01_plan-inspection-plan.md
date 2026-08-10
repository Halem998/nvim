# Implementation Plan: Orchestrator Plan Drift Inspection

- **Task**: 615 - orchestrator_plan_inspection
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 613 (phases_completed/phases_total in handoff)
- **Research Inputs**: specs/615_orchestrator_plan_inspection/reports/01_plan-inspection.md
- **Artifacts**: plans/01_plan-inspection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add plan drift detection to the orchestrator's post-dispatch logic. When an implement dispatch returns `partial` with less than 70% phase completion, the orchestrator forks an inspection agent to read the plan file (respecting the context-protective lead constraint) and report a drift percentage. If drift exceeds 30%, the orchestrator invokes reviser-agent to revise the plan before re-dispatching implementation. This uses the same fork-then-revise pattern already established by blocker escalation in Stage 6.

### Research Integration

The research report identified: (1) the exact insertion point in Stage 5 after `phases_completed`/`phases_total` logging; (2) the two-gate design where a cheap arithmetic gate precedes the expensive inspection fork; (3) the use of a dedicated `.drift-inspection.json` file to avoid clobbering the primary handoff; (4) three named constants for thresholds and caps; (5) no changes needed to reviser-agent, skill-reviser, or the handoff schema.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. This is an internal agent system improvement (meta task type).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Detect plan drift when implement dispatch returns partial with low completion
- Fork an inspection agent to read the plan (maintaining context-protective lead constraint)
- Conditionally invoke reviser-agent when drift exceeds threshold
- Cap drift inspections to prevent runaway loops

**Non-Goals**:
- Modifying reviser-agent or skill-reviser (they already support this use case)
- Changing the handoff schema (phases_completed/phases_total already exist from task 613)
- Adding deviation markers to the plan format (inspection uses checkbox counting)
- Implementing drift detection for non-implement dispatches (research/plan cycles)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Inspection fork consumes a cycle, shortening MAX_CYCLES budget | M | M | MAX_DRIFT_INSPECTIONS=1 caps to at most one inspection per lifecycle run |
| Inspection fork reads plan incorrectly (no deviation markers) | L | M | Default to drift_pct=0 when no markers found; revision skipped safely |
| Drift detection fires when agent is legitimately slow, not drifted | M | L | Two-gate design (< 70% AND partial status) filters false positives |
| `.drift-inspection.json` left behind after interrupted run | L | L | Clean up in Stage 8 postflight alongside other temp files |
| Extension copy of SKILL.md gets out of sync with primary | M | M | Phase 4 explicitly updates extension copy as final step |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add drift detection constants and arithmetic gate [COMPLETED]

**Goal**: Add the three drift constants to Stage 2 (alongside existing MAX_CYCLES and MAX_BLOCKER_ESCALATIONS) and insert the first-gate arithmetic check in Stage 5 after the phase progress logging.

**Tasks**:
- [x] Add `drift_inspection_count=0` and `MAX_DRIFT_INSPECTIONS=1` to Stage 2 (after line 128, alongside `blocker_escalation_count=0`) *(completed)*
- [x] Add `DRIFT_COMPLETION_THRESHOLD=0.70` and `DRIFT_REVISION_THRESHOLD=0.30` constants to Stage 2 *(completed)*
- [x] Insert the arithmetic gate in Stage 5 between the phase progress echo (line 325) and the cycle_count increment (line 329): check `phases_total > 0`, `dispatch_status == "partial"`, and `phases_completed / phases_total < DRIFT_COMPLETION_THRESHOLD` *(completed)*
- [x] Add conditional log line: `echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."` *(completed)*
- [x] Add placeholder comment `# invoke_drift_inspection (Phase 2)` inside the conditional for the next phase to fill in *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add constants to Stage 2 and gate logic to Stage 5

**Verification**:
- Constants appear in Stage 2 code block near MAX_CYCLES/MAX_BLOCKER_ESCALATIONS
- Gate logic appears in Stage 5 between phase progress echo and cycle_count increment
- Gate only fires when all three conditions are met (phases_total > 0, partial status, below threshold)

---

### Phase 2: Add invoke_drift_inspection function [COMPLETED]

**Goal**: Create the `invoke_drift_inspection` function that forks an inspection agent, reads `.drift-inspection.json`, and returns the drift percentage. This mirrors the `blocker_escalation` function structure.

**Tasks**:
- [x] Create `invoke_drift_inspection` function between Stage 5 and Stage 6 (or as a new Stage 5a), using the same structure as `blocker_escalation` *(completed)*
- [x] Function signature: `invoke_drift_inspection(task_number, plan_path, session_id)` *(completed)*
- [x] Inside the function: check `drift_inspection_count >= MAX_DRIFT_INSPECTIONS` and return early with warning if cap reached *(completed)*
- [x] Increment `drift_inspection_count` *(completed)*
- [x] Build fork context JSON with `task_number`, `session_id`, `plan_path`, and `orchestrator_mode: false` *(completed)*
- [x] Build fork prompt instructing the inspection agent to: read the plan file, count total `- [ ]` and `- [x]` checkboxes, count deviation annotations, calculate `drift_pct`, and write compact JSON to `${TASK_DIR}/.drift-inspection.json` *(completed)*
- [x] Dispatch the fork using `dispatch_agent "" "$drift_inspect_prompt" "$drift_context" "true"` (unnamed fork, same pattern as blocker research) *(completed)*
- [x] After fork returns: read `.drift-inspection.json` and extract `drift_pct` and `summary` *(completed)*
- [x] Replace Phase 1 placeholder with actual `invoke_drift_inspection "$task_number" "$plan_path" "$session_id"` call *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add function between Stage 5 and Stage 6; update Stage 5 call site

**Verification**:
- Function exists with cap check, fork dispatch, and `.drift-inspection.json` reading
- Fork uses unnamed dispatch pattern (first argument empty string)
- Function is called from the Stage 5 arithmetic gate

---

### Phase 3: Add conditional reviser-agent invocation and cleanup [COMPLETED]

**Goal**: After drift inspection, conditionally invoke reviser-agent when `drift_pct > DRIFT_REVISION_THRESHOLD`. Also add `.drift-inspection.json` cleanup to Stage 8 postflight.

**Tasks**:
- [x] Inside `invoke_drift_inspection`, after reading `drift_pct`: add conditional check `drift_pct > DRIFT_REVISION_THRESHOLD` *(completed)*
- [x] On threshold exceeded: log `echo "[orchestrate] Drift detected ($drift_pct). Triggering plan revision..."` *(completed)*
- [x] Build revise context JSON with `task_number`, `session_id`, `plan_path`, `revision_reason: "drift"`, and `drift_pct` *(completed)*
- [x] Dispatch reviser-agent using `dispatch_agent "reviser-agent" "$revise_prompt" "$revise_context" "false"` (same pattern as Stage 6 Step 4) *(completed)*
- [x] On threshold not exceeded: log `echo "[orchestrate] Drift check passed ($drift_pct <= $DRIFT_REVISION_THRESHOLD). Continuing."` *(completed)*
- [x] Add cleanup of `.drift-inspection.json` in Stage 8 postflight: `rm -f "${TASK_DIR}/.drift-inspection.json"` *(completed)*
- [x] Update the Skill-to-Agent Mapping table at the bottom to add a row for "Drift inspection" (fork, cache-warm) and note that "Plan revision" reuses reviser-agent *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add revision logic inside the function, cleanup in Stage 8, update mapping table

**Verification**:
- Reviser-agent is dispatched only when drift_pct exceeds the threshold
- `.drift-inspection.json` is cleaned up in Stage 8
- Skill-to-Agent Mapping table includes drift inspection and drift revision entries

---

### Phase 4: Sync extension copy [COMPLETED]

**Goal**: Copy the updated SKILL.md to the extension location to keep the primary and extension copies in sync.

**Tasks**:
- [x] Copy `.claude/skills/skill-orchestrate/SKILL.md` to `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` *(completed)*
- [x] Verify both files are identical (diff check) *(completed: diff returned no differences)*

**Timing**: 5 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - Full replacement with updated primary copy

**Verification**:
- `diff` between the two files returns no differences

## Testing & Validation

- [ ] Verify drift constants (DRIFT_COMPLETION_THRESHOLD, DRIFT_REVISION_THRESHOLD, MAX_DRIFT_INSPECTIONS) appear in Stage 2 alongside existing constants
- [ ] Verify the arithmetic gate in Stage 5 correctly guards the inspection fork dispatch
- [ ] Verify `invoke_drift_inspection` function follows the same structural pattern as `blocker_escalation`
- [ ] Verify the fork uses unnamed dispatch (empty string first argument to dispatch_agent)
- [ ] Verify reviser-agent dispatch matches the pattern in Stage 6 Step 4
- [ ] Verify `.drift-inspection.json` cleanup appears in Stage 8 postflight
- [ ] Verify primary and extension SKILL.md copies are identical
- [ ] Verify no plan files are read by the orchestrator itself (context-protective constraint maintained)

## Artifacts & Outputs

- `.claude/skills/skill-orchestrate/SKILL.md` - Updated with drift detection logic
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - Synced extension copy

## Rollback/Contingency

Revert the single file `.claude/skills/skill-orchestrate/SKILL.md` and its extension copy to the pre-task state using `git checkout HEAD -- .claude/skills/skill-orchestrate/SKILL.md .claude/extensions/core/skills/skill-orchestrate/SKILL.md`. The changes are confined to one file (plus its copy), making rollback trivial.
