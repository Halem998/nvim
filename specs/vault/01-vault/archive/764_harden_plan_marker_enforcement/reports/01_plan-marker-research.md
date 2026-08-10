# Research Report: Task #764

**Task**: 764 - Harden implementation agent plan marker enforcement
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:30:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/agents/general-implementation-agent.md` (read in full)
- `.claude/skills/skill-orchestrate/SKILL.md` (read in full)
- `.claude/skills/skill-implementer/SKILL.md` (read in full)
- `.claude/context/formats/plan-format.md`
- `.claude/rules/plan-format-enforcement.md`
- `.claude/context/formats/summary-format.md`
- `.claude/scripts/update-plan-status.sh`
- `.claude/scripts/update-phase-status.sh`
- `.claude/scripts/validate-artifact.sh`
- `.claude/docs/architecture/handoff-schema.md`
- `.claude/docs/architecture/dispatch-agent-spec.md`
- `specs/762_add_literature_briefing_injection_to_cslib_agents/plans/01_lit-injection-agents-plan.md` (example plan file)
**Artifacts**: `specs/764_harden_plan_marker_enforcement/reports/01_plan-marker-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The `general-implementation-agent` has detailed instructions for marking phases `[IN PROGRESS]` (Stage 4A) and `[COMPLETED]` (Stage 4D), but these are written as procedural suggestions rather than hard contracts with explicit enforcement.
- When dispatched via `/orchestrate`, the implementation agent receives `orchestrator_mode: true` but the agent spec makes no distinction in marker behavior based on this flag. The failure is not orchestrator-specific — it is a general compliance issue that surfaces more visibly under orchestration.
- The top-level `**Status**` field in plans (set by `update-plan-status.sh`) is controlled by the skill layer (skill-implementer), not the agent. The agent only updates **phase headings**. This means the top-level status can be wrong even when phase markers are correct.
- The existing `validate-artifact.sh` checks plan structure but does not verify phase marker completeness (all phases `[COMPLETED]`) or top-level `**Status**` consistency.
- There is no post-implementation checkpoint that explicitly reads the plan file to verify all phases are marked `[COMPLETED]` before returning `implemented` status.
- The recommended approach is a **Stage 5a: Plan Marker Verification** inserted between the final phase completion and summary creation, written as a hard contract with fallback repair logic.

---

## Context & Scope

**Problem Statement**: Implementation agents (both via `/implement` and `/orchestrate`) inconsistently update plan phase markers. The symptoms are:
1. Phase headings remain `[NOT STARTED]` after implementation completes
2. The top-level `**Status**` field remains `[NOT STARTED]` or `[IMPLEMENTING]`
3. This is more visible under `/orchestrate` multi-task mode because multiple agents run in parallel, potentially overlapping on plan file edits, and there is less human-in-the-loop verification

**Scope of Research**:
- Stage 4A and 4D marker update instructions in `general-implementation-agent.md`
- How the orchestrator dispatches vs. the skill-implementer (differences in context)
- Plan file structure and marker patterns
- Existing enforcement mechanisms (validate-artifact.sh, plan-format-enforcement.md)
- The summary creation step and whether it could include verification
- The orchestrator handoff and whether it provides a natural enforcement point

---

## Findings

### 1. Current Marker Update Instructions (Soft Contracts)

The `general-implementation-agent.md` specifies marker updates at two points:

**Stage 4A (Mark In Progress)**:
```
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
```

**Stage 4D (Mark Completed)**:
```
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
```

**Why these fail**: Both are framed as instructions to execute — "Use the Edit tool with..." — but they lack enforcement. There is no subsequent verification step that checks whether the Edit actually succeeded, or whether the agent somehow skipped these steps due to:
- Context pressure (agent prioritizes implementation over bookkeeping)
- Edit tool errors (old_string mismatch because the plan file heading differs from expected format)
- Agent judgment calls ("the phase is done, I'll just move on")
- Successor agents continuing from handoffs, which may resume mid-phase without re-marking [IN PROGRESS]

**Note on the MUST NOT**: The spec says `MUST NOT` leave the plan file with stale status markers. This is in the Critical Requirements section. Despite the strong language, it is not enforced computationally — it remains a behavioral instruction.

### 2. Orchestrator Mode Difference (Why It's More Visible)

The orchestrator dispatches the implementation agent with `orchestrator_mode: true`. The agent spec makes **no distinction** in behavior based on this flag — the same Stage 4A/4D instructions apply regardless of mode.

However, the orchestrator has a key characteristic that makes marker failures more likely to surface:

1. **No inner continuation loop**: When `orchestrator_mode: true`, skill-orchestrate re-dispatches implementation after context exhaustion instead of using skill-implementer's inner continuation loop. This means each dispatch sees a fresh context with the plan as its primary state source.

2. **Multi-task parallel execution**: In multi-task mode (Stage MT-3/MT-4), multiple implementation agents run in parallel on different tasks. Each agent writes to its own plan file, but if any agent crashes or exits early (without completing Stage 4D), the plan file is left mid-state.

3. **No plan-reading by orchestrator**: The orchestrator's context flatness constraint explicitly prohibits reading plan files (`## MUST NOT: Read plan files (plans/*.md) during the state machine loop`). This means the orchestrator never verifies that the agent actually updated the markers — it only reads the 400-token `.orchestrator-handoff.json`.

4. **The handoff does NOT include plan marker state**: The orchestrator handoff schema (`handoff-schema.md`) has fields for `status`, `phases_completed`, `phases_total`, and `artifacts`, but no field that records whether plan markers were updated. `phases_completed` is a number — not a verification that the corresponding headings in the plan file were actually edited.

### 3. Top-Level Status Field: Controlled by Skill Layer

The top-level `**Status**` line in a plan file (e.g., `- **Status**: [NOT STARTED]`) is updated by `update-plan-status.sh`, which is called by the skill layer (skill-implementer), not the agent. Specifically:

- `skill-implementer` Stage 2 (Preflight) calls `update-task-status.sh preflight ... implement` which calls `update-plan-status.sh` to set status to `[IMPLEMENTING]`
- `skill-implementer` Stage 7 (Update Task Status) calls `update-task-status.sh postflight ... implement` which calls `update-plan-status.sh` to set status to `[COMPLETED]`

**In orchestrator mode**: The orchestrator does NOT call `update-task-status.sh` before or after dispatch. The postflight is handled via `skill_postflight_update()` in `skill-base.sh`, called from Stage 5 in skill-orchestrate. This updates `state.json` but may not update the plan file status field.

**Finding**: The top-level `**Status**` field update is performed by `update-plan-status.sh` as part of `update-task-status.sh`. When skill-orchestrate calls `skill_postflight_update()`, it should trigger this. However, the path through `skill-base.sh` → `orchestrator-postflight.sh` → `update-task-status.sh` → `update-plan-status.sh` is several indirections deep. Any break in this chain leaves the top-level status stale.

### 4. Existing Enforcement Mechanisms (What Already Exists)

**`validate-artifact.sh` for plans**: Checks for:
- H1 title heading
- Required metadata fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
- Required sections: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency
- At least one Phase heading (`### Phase N`)
- Dependency Analysis table (warning only)

**What it does NOT check**:
- That all phases are `[COMPLETED]` when the plan is done
- That no phases remain `[NOT STARTED]` after implementation
- That the top-level `**Status**` field matches actual completion state
- That the number of `[COMPLETED]` phases matches the total phase count

**`plan-format-enforcement.md` rule**: Only enforces format (heading structure, marker syntax, no emojis). No runtime enforcement.

**`update-phase-status.sh`**: A script for updating individual phase headings. Has idempotency checks and logs transitions to `.claude/logs/phase-transitions.log`. This script exists and is ready to use — but the agent spec does NOT call this script; it calls the Edit tool directly instead.

### 5. Stage 4D-ii (Post-Phase Self-Review) — Currently Behavioral Only

The spec includes a `Stage 4D-ii: Post-Phase Self-Review` that re-reads the phase checklist and verifies unchecked items. However:

1. It is framed as a behavioral self-review, not a mechanical contract
2. It checks **checklist items** (`- [ ]`) not **phase heading markers** (`[COMPLETED]`)
3. It does not verify that the phase heading was successfully updated

### 6. The Summary Creation Step (Stage 6)

The summary is written after all phases complete (Stage 5 → Stage 6). At this point, all phases should be `[COMPLETED]`. The summary step does NOT read the plan file to verify this — it synthesizes from the progress files.

**Opportunity**: Stage 5 (Run Final Verification) runs after all phases complete. This is the ideal insertion point for a plan marker verification step. The agent is about to return `implemented` status, so a mandatory final check here would catch marker failures before they are recorded as complete.

### 7. The Orchestrator Handoff as an Enforcement Point

The orchestrator handoff written by skill-implementer includes `phases_completed` and `phases_total`. If we require the skill to **verify** that plan markers match these counts before writing the handoff, we create a computational checkpoint.

However, the orchestrator reads only the handoff — it does not read the plan file. So enforcement must happen inside the agent or skill, not in the orchestrator.

---

## Decisions

- The root cause is that phase marker updates are behavioral instructions, not computational checkpoints. The fix must add a computational verification step that runs regardless of the agent's subjective assessment.
- The best enforcement location is **Stage 5a** in `general-implementation-agent.md` — after all phases complete but before creating the summary.
- The verification should use `grep` or `sed` to count `[NOT STARTED]` and `[IN PROGRESS]` phase headings in the plan file, and repair any that remain.
- Using `update-phase-status.sh` for repair (rather than the Edit tool) provides consistent logging and idempotency guarantees.
- A parallel change should be made to `validate-artifact.sh` to add a `--verify-completion` flag that checks phase marker completeness for use in postflight.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Stage 4A's `[IN PROGRESS]` heading may remain if the agent crashes mid-phase | The Stage 5a verification checks for both `[NOT STARTED]` and `[IN PROGRESS]`, repairing both |
| Edit tool failures (old_string doesn't match) may silently fail | Stage 5a catches this by reading the file state, not relying on Edit success |
| Agent reads stale cached version of plan file | Agent always reads live plan file via Read tool; no caching concern |
| Parallel agents in multi-task mode could race on plan file edits | Each task has its own plan file — no race condition possible |
| Stage 5a adds tool calls, increasing context usage | Verification is a single grep + conditional repair; minimal cost |
| The top-level `**Status**` field update path through postflight may be broken | Separate task needed to audit `orchestrator-postflight.sh` → `update-task-status.sh` → `update-plan-status.sh` chain |

---

## Recommendations

### Recommendation 1: Add Stage 5a (Plan Marker Verification) to general-implementation-agent.md

Insert between Stage 5 (Run Final Verification) and Stage 6 (Create Implementation Summary):

```
### Stage 5a: Verify and Repair Plan Markers (HARD CONTRACT)

**CRITICAL**: This stage is MANDATORY and must NOT be skipped. Failure to update plan markers
is the most common defect in this agent's output.

After all phases complete, verify the plan file has correct markers:

1. **Read the plan file** (fresh read — do not rely on memory of previous edits):
   ```bash
   plan_content=$(cat "$plan_path")
   ```

2. **Count incomplete phase headings**:
   ```bash
   not_started_count=$(grep -c "### Phase.*\[NOT STARTED\]" "$plan_path" || echo 0)
   in_progress_count=$(grep -c "### Phase.*\[IN PROGRESS\]" "$plan_path" || echo 0)
   incomplete_count=$((not_started_count + in_progress_count))
   ```

3. **If incomplete_count > 0**, repair each stale heading:
   For each phase heading matching `[NOT STARTED]` or `[IN PROGRESS]`:
   ```bash
   bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED
   ```
   Log: `[plan-marker] Repaired phase $phase_num: $old_status -> COMPLETED`

4. **Verify top-level Status field**:
   ```bash
   top_status=$(grep -m1 "^\- \*\*Status\*\*:" "$plan_path" | sed 's/.*\[\(.*\)\].*/\1/')
   if [ "$top_status" != "COMPLETED" ]; then
     bash .claude/scripts/update-plan-status.sh "$task_number" "$project_name" COMPLETED
     echo "[plan-marker] Updated top-level Status: [$top_status] -> [COMPLETED]"
   fi
   ```

5. **Final read to confirm**:
   Re-read the plan file and verify zero incomplete phase headings remain.
   If any remain after repair attempt, log a warning and include in the summary.

**This step MUST complete before proceeding to Stage 6. Returning `implemented` status with
stale plan markers is a defect that must be caught and corrected here.**
```

### Recommendation 2: Add Phase Marker Verification to validate-artifact.sh

Extend `validate-artifact.sh` with a `--verify-completion` flag:

```bash
# In validate-artifact.sh, for plan type with --verify-completion flag:
if [ "$verify_completion" = true ] && [ "$artifact_type" = "plan" ]; then
  not_started=$(grep -c "### Phase.*\[NOT STARTED\]" "$artifact_path" || echo 0)
  in_progress=$(grep -c "### Phase.*\[IN PROGRESS\]" "$artifact_path" || echo 0)
  if [ "$not_started" -gt 0 ] || [ "$in_progress" -gt 0 ]; then
    log_error "Plan has $not_started [NOT STARTED] and $in_progress [IN PROGRESS] phase(s) after completion"
  fi
  # Verify top-level status
  top_status=$(grep -m1 "^\- \*\*Status\*\*:" "$artifact_path" | sed 's/.*\[\(.*\)\].*/\1/' || echo "")
  if [ "$top_status" != "COMPLETED" ]; then
    log_error "Top-level Status is [$top_status], expected [COMPLETED]"
  fi
fi
```

This would be called from `skill-implementer` Stage 6a with `--verify-completion` after implementation:
```bash
bash .claude/scripts/validate-artifact.sh "$plan_path" plan --verify-completion
```

### Recommendation 3: Update the Critical Requirements Section

The existing MUST NOT list includes:
> 2. Leave plan file with stale status markers

Strengthen this with explicit framing as a hard contract by changing it to:

```
**HARD CONTRACT — ZERO TOLERANCE**:
The plan file MUST have all phase headings marked [COMPLETED] and the top-level **Status**
set to [COMPLETED] before this agent returns `implemented` status. Stage 5a is the mandatory
verification and repair step. If Stage 5a is skipped for any reason, the agent has introduced
a defect. There are no exceptions to this rule.
```

### Recommendation 4: Extend Orchestrator Handoff Schema

Add a `plan_markers_verified` field to the orchestrator handoff (optional, boolean):

```json
{
  "phase": "implement",
  "status": "implemented",
  "plan_markers_verified": true,
  ...
}
```

The orchestrator's Stage 5 postflight can log a warning if this field is absent or false:
```bash
markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "unset"')
if [ "$markers_verified" != "true" ]; then
  echo "[orchestrate] WARNING: Implementation returned without plan_markers_verified=true"
fi
```

This provides visibility without blocking the pipeline (since repair happens in Stage 5a).

### Recommendation 5: Use update-phase-status.sh Instead of Edit Tool for Markers

The agent spec currently directs agents to use the Edit tool directly for phase marker updates. This means:
- No logging (phase-transitions.log is bypassed)
- No idempotency guarantees
- Silent failures if old_string doesn't match exactly

**Recommended change**: Replace the Edit tool instructions in Stage 4A and Stage 4D with calls to `update-phase-status.sh`:

```bash
# Stage 4A: Mark In Progress
bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" IN_PROGRESS

# Stage 4D: Mark Completed  
bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED
```

Benefits:
- Transitions logged to `.claude/logs/phase-transitions.log`
- Idempotency: If already at target status, no-op
- Error messages if phase heading not found
- Single source of truth for phase marker update logic

---

## Context Extension Recommendations

- **Topic**: Plan marker enforcement at implementation completion
- **Gap**: No existing context file documents the hard contract between agents and plan files regarding phase marker completeness.
- **Recommendation**: Consider adding a `.claude/context/patterns/plan-marker-contract.md` that documents: the exact grep patterns for checking marker completeness, the update-phase-status.sh call pattern, and the Stage 5a verification template. This would allow all implementation agents (neovim, nix, lean) to load it lazily and follow the same pattern.

---

## Appendix

### Files Modified by This Research
None — research only.

### Key File Paths
- `general-implementation-agent.md`: `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
- `skill-orchestrate/SKILL.md`: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `skill-implementer/SKILL.md`: `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md`
- `update-phase-status.sh`: `/home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh`
- `update-plan-status.sh`: `/home/benjamin/.config/nvim/.claude/scripts/update-plan-status.sh`
- `validate-artifact.sh`: `/home/benjamin/.config/nvim/.claude/scripts/validate-artifact.sh`

### Grep Patterns for Plan Marker Checking
```bash
# Count phases with stale NOT STARTED marker
grep -c "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_path"

# Count phases with stale IN PROGRESS marker
grep -c "^### Phase [0-9]*:.*\[IN PROGRESS\]" "$plan_path"

# Count all COMPLETED phases
grep -c "^### Phase [0-9]*:.*\[COMPLETED\]" "$plan_path"

# Count total phases
grep -c "^### Phase [0-9]*:" "$plan_path"

# Check top-level status
grep -m1 "^\- \*\*Status\*\*:" "$plan_path"
```
