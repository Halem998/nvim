# Research Report: Task 615 — Orchestrator Plan Inspection

- **Task**: 615 - orchestrator_plan_inspection
- **Started**: 2026-05-25T00:00:00Z
- **Completed**: 2026-05-25T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 613 (phases_completed/phases_total in handoff), Task 614 (agent subtask validation)
- **Sources/Inputs**:
  - `.claude/skills/skill-orchestrate/SKILL.md` (full read)
  - `.claude/agents/reviser-agent.md` (full read)
  - `.claude/skills/skill-reviser/SKILL.md` (full read)
  - `.claude/docs/architecture/handoff-schema.md` (full read)
  - `.claude/context/patterns/context-protective-lead.md` (full read)
  - `.claude/scripts/skill-base.sh` (full read)
- **Artifacts**: `specs/615_orchestrator_plan_inspection/reports/01_plan-inspection.md`
- **Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The orchestrator (skill-orchestrate) currently reads `phases_completed`/`phases_total` from the handoff (added in task 613) but takes no action when completion is low — it just logs and continues.
- The context-protective lead pattern is a hard constraint: the orchestrator MUST NOT read plan files directly. Any plan inspection must be delegated to a fork.
- The blocker escalation flow (Stage 6) already demonstrates the pattern: fork a research agent, then invoke reviser-agent. Drift detection can reuse this exact sequence with a specialized drift-inspection fork instead of a blocker-research fork.
- The threshold logic (< 70% phase completion triggers inspection; > 30% drift triggers revision) should live entirely in Stage 5 of the orchestrator, as a decision gate between handoff reading and the next cycle dispatch.
- The implementation inserts ~15 lines of bash logic after the existing `phases_completed`/`phases_total` extraction in Stage 5, plus one new fork dispatch path in Stage 6 (or an inline fork in Stage 5).

---

## Context & Scope

This research covers the current orchestrator post-dispatch logic and establishes exactly where and how plan drift detection should be added, while staying strictly within the context-protective lead pattern.

**In scope:**
- Stage 5 of skill-orchestrate (post-dispatch handoff reading logic, lines 306–326)
- Stage 6 (blocker escalation, which provides the fork+revise pattern to reuse)
- Context-protective constraints on what the orchestrator is allowed to read
- How to delegate plan inspection without the orchestrator reading plan files

**Out of scope:**
- Changes to agents (reviser-agent, general-research-agent) — these are unchanged
- Changes to skill-base.sh — already supports the necessary primitives
- Changes to the handoff schema — `phases_completed`/`phases_total` already exist

---

## Findings

### Current Stage 5 Logic (Post-Dispatch Handoff Reading)

Stage 5 of `skill-orchestrate/SKILL.md` (lines 305–329) reads the orchestrator handoff after every agent dispatch:

```bash
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
echo "[orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
[ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"
```

After these four lines, execution falls through to Stage 7 (loop guard update) and then cycles back to the top. There is no decision gate on phase completion percentage. The `phases_completed`/`phases_total` fields are logged but not acted upon.

**Gap identified**: The orchestrator has the phase ratio data and never uses it to detect drift.

### Context-Protective Lead Constraint

The `context-protective-lead.md` pattern document imposes a hard rule: the orchestrator MUST NOT read plan files (`plans/*.md`). Specifically:

> **MUST NOT section in skill-orchestrate:**
> 3. Read plan files (`plans/*.md`) during the state machine loop

This means the drift detection logic cannot work by having the orchestrator directly read the plan and count unchecked vs. annotated items. Any plan inspection must be delegated to a fork that operates in its own context window and returns only a compact summary.

**The correct pattern**: Fork an inspection agent (passing the plan_path), receive a compact JSON summary reporting drift percentage, then decide whether to invoke reviser-agent.

### How the Existing Blocker Escalation Pattern Works (Stage 6)

The blocker escalation in Stage 6 demonstrates exactly the pattern we need:

1. **Detect condition** — caller detects `blocker_count > 0` in handoff
2. **Fork a research agent** — dispatch a fork (unnamed, inherits parent type) to investigate
3. **Read compact findings from handoff** — `findings_summary` (~100 tokens)
4. **Invoke reviser-agent** — named subagent dispatch with findings context
5. **Re-dispatch implementer** — continue lifecycle after plan is updated

The drift detection path mirrors this exactly:
1. **Detect condition** — `phases_completed / phases_total < 0.70` after implement dispatch
2. **Fork an inspection agent** — delegate reading of the plan file
3. **Read drift report from handoff** — compact JSON with `drift_pct` and `deviations_found`
4. **Conditionally invoke reviser-agent** — only if `drift_pct > 0.30`
5. **Continue the cycle** — loop back to dispatch implement again

### Where the New Logic Fits in Stage 5

The new logic inserts a decision gate immediately after the existing phase progress logging, before `cycle_count` is incremented:

```
... (existing: lines 311-326, read handoff fields including phases_completed/phases_total)

# NEW: Drift detection gate (insert here)
if phases_total > 0 AND phases_completed / phases_total < 0.70 AND dispatch_status == "partial":
    invoke_drift_inspection()   # forks inspection agent
    if drift_pct > 0.30:
        invoke_reviser_agent()  # reuses Stage 6 pattern

# EXISTING: Increment cycle_count (line 329)
cycle_count=$((cycle_count + 1))
```

The gate only fires when:
- `phases_total > 0` (implementer reported counts — prevents false positives from research/plan phases)
- `phases_completed / phases_total < 0.70` (< 70% completion rate)
- `dispatch_status == "partial"` (agent returned early, not a normal in-progress cycle)

### How the Drift Inspection Fork Works

The inspection fork receives only `plan_path` (a file path string, not content) and its prompt instructs it to:
1. Read the plan file
2. Count: total subtask checkboxes, checked checkboxes, and lines annotated with `[deviation]` or `<!-- deviation -->` or similar markers
3. Calculate: `drift_pct = deviations / total_subtasks`
4. Write a compact handoff JSON with `drift_pct` (float) and a one-sentence summary

The fork uses the unnamed dispatch pattern (same as blocker research in Stage 6, line 369):
```bash
dispatch_agent "" "$drift_inspect_prompt" "$drift_context" "true"
```

The orchestrator reads only the resulting handoff (~50-100 tokens), extracts `drift_pct`, and decides.

### How reviser-agent Is Invoked for Drift

The reviser-agent invocation for drift-triggered revision is identical to the blocker escalation pattern:

```bash
dispatch_agent "reviser-agent" \
  "Revise the implementation plan for task $task_number. Drift detected: $drift_pct of subtasks deviated from the plan. Inspect unchecked items and revise remaining phases." \
  "$revise_context" "false"
```

The `reviser-agent` already supports this use case: it loads the existing plan (Stage 3), inspects it, and produces a revised plan (Stage 5a). No changes needed to the agent itself. The `revision_reason` field in the delegation context carries the drift description.

### Thresholds and Decision Criteria

The task description specifies:
- **Trigger inspection**: `phases_completed / phases_total < 0.70` (< 70% completion)
- **Trigger revision**: drift detected at > 30% of subtasks (`drift_pct > 0.30`)

These two thresholds create a two-stage gate:
1. First gate (cheap): arithmetic on two integers already in context — no delegation needed
2. Second gate (expensive): requires fork to read plan — only triggered if first gate fires

This is the right layering. The first gate prevents unnecessary fork dispatches on tasks that are making adequate progress.

### Blocker Escalation Cap Interaction

The blocker escalation cap (`MAX_BLOCKER_ESCALATIONS=2`) currently guards only the `blocker_escalation()` function. The drift inspection is a distinct flow — it should NOT share this cap, because drift is not a blocker. It should have its own cap (suggested: `MAX_DRIFT_INSPECTIONS=1` per cycle) to prevent runaway inspection loops.

If the reviser-agent is invoked from drift detection AND a blocker is also present, the blocker escalation takes priority (the existing `partial` state handler already checks blockers first — this ordering is preserved by placing the drift gate only after reading the handoff, not inside the blocker handler).

### Token Budget Analysis

The new logic adds approximately:
- Drift detection condition check: ~20 tokens (arithmetic on already-loaded variables)
- Fork dispatch for inspection: ~150 tokens (delegation context + prompt)
- Reading inspection fork handoff: ~80 tokens (drift_pct + summary)
- Conditional reviser-agent dispatch: ~150 tokens (same as blocker escalation Step 4)
- Reviser-agent handoff read: ~80 tokens

**Total additional per drift-triggered cycle**: ~480 tokens above the existing Stage 5 overhead. This is within the context-protective budget (the pattern document allows ~5,000 tokens total above baseline for all routing).

### Handoff Schema Support for Drift Inspection

The inspection fork will write a handoff with a custom structure. The orchestrator reads it via `jq`. The drift_pct value is a simple float field added to the existing handoff schema. Since the inspection fork operates in its own context, no schema changes to skill-base.sh are needed — the fork writes the JSON directly.

However, if we want a cleaner approach, the drift inspection fork could write a compact file (e.g., `${TASK_DIR}/.drift-inspection.json`) rather than the standard orchestrator handoff, to avoid overwriting the primary handoff from the implement dispatch. The orchestrator reads this file, then continues.

---

## Decisions

1. **Use fork dispatch (unnamed agent)** for plan inspection, reusing the same pattern as blocker research in Stage 6. This is the only approach compatible with the context-protective constraint.

2. **Insert the drift detection gate in Stage 5**, immediately after the `phases_completed`/`phases_total` echo, before `cycle_count` increment. This preserves the clean stage boundaries.

3. **Use a separate inspection file** (`${TASK_DIR}/.drift-inspection.json`) rather than overwriting `.orchestrator-handoff.json`, to avoid clobbering the implement dispatch handoff before the orchestrator finishes processing it.

4. **Do not share the blocker escalation cap** — drift inspection gets its own `MAX_DRIFT_INSPECTIONS=1` cap to prevent loops.

5. **Only trigger on `dispatch_status == "partial"`** — if the implement dispatch returned `"implemented"` (all phases complete), there is no drift to detect regardless of phases_completed value.

6. **Reviser-agent invocation for drift uses `revision_reason`** to describe the drift context. No changes to reviser-agent or skill-reviser are needed.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Fork dispatch adds ~1 cycle cost when drift is detected | Gate is cheap (arithmetic); fork only dispatches when first gate fires. MAX_DRIFT_INSPECTIONS=1 prevents repeated inspections |
| Inspection fork reads plan incorrectly (no deviation markers in current format) | Task description should specify the marker format; if no markers are found, drift_pct=0 and revision is skipped |
| Drift detection triggers revision when agent is legitimately slow (not drifted) | The two-gate design (< 70% AND `partial`) ensures only clearly underperforming dispatches trigger inspection |
| Inspection fork writes to standard handoff path, overwriting implement handoff | Use a dedicated `.drift-inspection.json` file to prevent collision |
| Revision adds a cycle, consuming MAX_CYCLES budget faster | MAX_CYCLES is 5; drift detection should only fire once per lifecycle (MAX_DRIFT_INSPECTIONS=1). Net cost: +1-2 cycles when drift is detected |

---

## Recommendations

### Recommended Implementation Plan

**Phase 1: Add drift detection logic to Stage 5 of skill-orchestrate**

Insert after line 325 (`[ "$phases_total" -gt 0 ] && echo ...`):

```bash
# Drift detection gate: inspect plan if < 70% phases completed on partial return
drift_inspection_count=0
MAX_DRIFT_INSPECTIONS=1

if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
  completion_pct=$(echo "scale=2; $phases_completed / $phases_total" | bc 2>/dev/null || echo "1.0")
  completion_threshold="0.70"
  if [ "$(echo "$completion_pct < $completion_threshold" | bc 2>/dev/null)" = "1" ] && \
     [ "$drift_inspection_count" -lt "$MAX_DRIFT_INSPECTIONS" ]; then
    drift_inspection_count=$((drift_inspection_count + 1))
    echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
    invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
  fi
fi
```

**Phase 2: Add `invoke_drift_inspection` function (parallel to `blocker_escalation`)**

The function:
1. Dispatches a fork with `plan_path` to inspect unchecked items vs. annotated deviations
2. Reads `.drift-inspection.json` (compact: `{"drift_pct": 0.35, "summary": "..."}`)
3. If `drift_pct > 0.30`, dispatches reviser-agent (same as Stage 6 Steps 4-5)

**Phase 3: Document the drift threshold values**

Add them as named constants near MAX_CYCLES/MAX_BLOCKER_ESCALATIONS at the top of Stage 2:
```bash
DRIFT_COMPLETION_THRESHOLD=0.70   # Trigger inspection if below this
DRIFT_REVISION_THRESHOLD=0.30     # Trigger revision if drift exceeds this
MAX_DRIFT_INSPECTIONS=1           # Cap per lifecycle run
```

### Inspection Fork Prompt Design

The fork prompt must be precise about what constitutes a "deviation". Since current plan files use markdown checkboxes, the inspection agent should:
- Count `- [ ]` (unchecked) vs `- [x]` (checked) subtasks
- Count lines with deviation annotation markers (to be specified — e.g., `<!-- deviation -->` or `(skipped)` annotations)
- Calculate `drift_pct = annotated_deviations / total_subtasks`
- Write compact JSON to `${TASK_DIR}/.drift-inspection.json`

If no deviation markers exist in the current plan format, the inspection agent reports `drift_pct=0` and revision is skipped. This is a safe default.

---

## Context Extension Recommendations

- **Topic**: Orchestrator drift detection pattern
- **Gap**: No documentation exists for how lead orchestrators should detect and respond to plan drift without reading plan files directly
- **Recommendation**: After implementation, add a new pattern file `.claude/context/patterns/orchestrator-drift-detection.md` documenting the two-gate threshold design and fork-inspect-revise sequence

---

## Appendix

### Files Read During Research

| File | Purpose |
|------|---------|
| `.claude/skills/skill-orchestrate/SKILL.md` | Primary target — full Stage 5 and Stage 6 analysis |
| `.claude/docs/architecture/handoff-schema.md` | Confirms phases_completed/phases_total schema (from task 613) |
| `.claude/context/patterns/context-protective-lead.md` | Hard constraints on orchestrator file reads |
| `.claude/agents/reviser-agent.md` | Reviser invocation contract (no changes needed) |
| `.claude/skills/skill-reviser/SKILL.md` | Delegation context format for reviser |
| `.claude/scripts/skill-base.sh` | skill_write_orchestrator_handoff primitives |

### Key Line References in skill-orchestrate/SKILL.md

| Lines | Content |
|-------|---------|
| 99-129 | Stage 2: Loop guard setup, MAX_CYCLES, blocker_escalation_count |
| 234-266 | Stage 4: `partial` state handler — where blocker escalation is triggered |
| 305-329 | Stage 5: Handoff reading — where drift gate should be inserted |
| 334-411 | Stage 6: Blocker escalation — pattern to reuse for drift inspection |
| 476-487 | MUST NOT section — context-protective constraints to maintain |
