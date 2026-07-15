# Implementation Plan: Wire status preflight into both /orchestrate paths

- **Task**: 876 - Wire status preflight into both /orchestrate paths
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/876_wire_preflight_into_orchestrate_paths/reports/01_wire-preflight-orchestrate.md
- **Artifacts**: plans/01_wire-preflight-orchestrate.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Under `/orchestrate`, both `skill-orchestrate` and `skill-orchestrate-hard` dispatch worker
agents directly by `subagent_type`, bypassing the top-level skills (`skill-researcher`,
`skill-planner`, `skill-implementer`) that own the status-transition preflight call. The result
is a task that sits at `not_started`/`researched`/`planned` through an entire work window instead
of transitioning to `researching`/`planning`/`implementing`. The fix is to call the
already-in-scope `skill_preflight_update()` wrapper (from `skill-base.sh`) before each Agent-tool
dispatch in the state handlers. No new scripts: this wires the existing `update-task-status.sh`
via the same wrapper already used for postflight in these files. Definition of done: every
orchestrate dispatch site that starts a research/plan/implement work window first calls
`skill_preflight_update`, the misleadingly-named "Preflight" loop-guard headings are renamed, the
H4 verification loop is provably excluded, and a manual walkthrough confirms the transitions.

### Research Integration

Research report `01_wire-preflight-orchestrate.md` verified all cited evidence and recommends
**option (b) via the existing `skill_preflight_update()` wrapper** rather than routing handlers
through the top-level skills (option (a) would double-fire hooks and conflict with the hard
skill's pure-dispatcher tool contract). Key findings integrated:
- `skill_preflight_update()` (skill-base.sh:142-149) is the exact mirror of the
  `skill_postflight_update()` these files already call, is already sourced/in-scope in both, and
  picks up the `hooks.preflight` extension-hook call for free.
- The gap is identical for research and plan phases, not just implement (Finding B), and exists in
  multi-task Stage MT-4 (Finding C) and hard mode's per-phase dispatch (Finding D).
- `update-task-status.sh` is idempotent (no-ops when already at target status), so preflight is
  safe to call on every cycle including repeated per-phase and continuation resumes (Finding F).
- **Critical constraint (Research "Risks"):** the H4 adversarial-verification re-dispatch loop
  re-dispatches the research agent while status is `researched`; it must NOT receive a
  `research`-preflight (that would regress status to `researching`). Only the final planner
  dispatch after `adversarial_verified=true` gets the `plan`-preflight.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no `roadmap_path` provided; no roadmap flag).

## Goals & Non-Goals

**Goals**:
- Insert `skill_preflight_update` before every research/plan/implement dispatch site on both
  orchestrate paths (single-task and multi-task), so status transitions to the in-progress
  variant during the work window.
- Preserve exact H4 ordering: research preflight only on the true research dispatch, plan
  preflight only after `adversarial_verified=true`, never on the verification re-dispatch.
- Rename the two "Stage 2: Preflight — Loop Guard[...]" headings to drop the reserved word
  "Preflight" (it names a status operation these headings have nothing to do with).
- Document in the architecture doc that `dispatch()` now performs the preflight status transition.

**Non-Goals**:
- No new scripts. No changes to `update-task-status.sh` or `skill-base.sh`.
- No routing of orchestrate handlers through `skill-researcher`/`skill-planner`/`skill-implementer`
  (rejected option (a)).
- No changes to postflight logic, drift/churn detection, blocker escalation, or handoff schema.
- No automated test harness (none exists for orchestrate; manual verification only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Research preflight leaks into the H4 verification re-dispatch, causing `researched`→`researching` status flicker | H | M | Phase 3 places the `plan` preflight strictly inside the `if [ "$adversarial_verified" = "true" ]` block, never in the verification branch; Phase 5 manual check asserts status stays `researched` across a verification pass |
| Wrapper not in scope where inserted | M | L | Both files already call `skill_postflight_update`/`skill_link_artifacts` from the same `skill-base.sh`, so `skill_preflight_update` is equally in scope; Phase 5 confirms |
| One-time implement-preflight side effects (workflow-active marker write, first `[NOT STARTED]`→`[IN PROGRESS]` phase auto-advance) collide with hard-mode per-phase heading scan | M | L | The heading scan (`skill-orchestrate-hard` Per-Phase Dispatch) already matches `IN PROGRESS`, so phase-1 auto-advance still resolves `next_phase=1`; preflight fires only once on `planned`→`implementing` (idempotent no-op thereafter) so it never advances later phases. Call this out in the phase notes |
| Wrong session-id form in multi-task Stage MT-4 | M | L | Use `"${session_id}_${task_num}"` to match the existing per-task postflight convention in the same stage |
| Task-number citations leak into deliverable files | L | L | All edits cite durable anchors (file/section), never task numbers, per no-task-references-in-deliverables |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 4 | -- |
| 2 | 2 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 both edit
`skill-orchestrate/SKILL.md` (distinct regions) so Phase 2 follows Phase 1 to avoid overlapping
edits; Phases 3 (hard skill) and 4 (doc) touch independent files.

### Phase 1: Base skill single-task preflights + heading rename [COMPLETED]

**Goal**: Add the three research/plan/implement preflight calls to the single-task state handlers
in `skill-orchestrate/SKILL.md` and rename the Stage 2 heading.

**Tasks**:
- [x] Re-verify current line numbers before editing (anchors below are from the current file). *(completed: anchors matched plan within a few lines)*
- [x] Rename the heading `### Stage 2: Preflight — Loop Guard` (currently line 100) to drop
      "Preflight" — e.g. `### Stage 2: Loop Guard Initialization`. *(completed)*
- [x] `not_started` handler (currently the block starting at `#### State: \`not_started\``,
      line 195): immediately before the `Invoke the Agent tool:` line (currently 197), add a
      fenced bash snippet:
      `skill_preflight_update "$task_number" "research" "$session_id"` *(completed)*
- [x] `researched` handler (currently `#### State: \`researched\``, line 217): after the
      `research_artifact=$(...)` read block (currently 219-224) and immediately before
      `Invoke the Agent tool:` (currently 226), add:
      `skill_preflight_update "$task_number" "plan" "$session_id"` *(completed)*
- [x] `planned` or `implementing` handler (currently `#### State: \`planned\` or \`implementing\``,
      line 240): after the `plan_path=$(...)` read (currently 242-245) and before
      `Invoke the Agent tool:` (currently 247), add:
      `skill_preflight_update "$task_number" "implement" "$session_id"` *(completed)*
- [x] `partial` continuation sub-state (currently `**Sub-state: continuation available**`,
      line 268): after its `plan_path=$(...)` read (currently 270-273) and before
      `Invoke the Agent tool:` (currently 275), add the same `implement` preflight call
      (defense-in-depth; typically a no-op since status is already `implementing`). *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` — heading rename (Stage 2); insert one
  `skill_preflight_update` call in each of the four single-task handlers listed above.

**Verification**:
- `grep -c "skill_preflight_update" .claude/skills/skill-orchestrate/SKILL.md` returns at least 4
  after this phase (Phase 2 adds more).
- The Stage 2 heading no longer contains the word "Preflight".
- Each inserted call sits before its handler's `Invoke the Agent tool:` line, not after.

---

### Phase 2: Base skill multi-task Stage MT-4 preflights [NOT STARTED]

**Goal**: Add per-task preflight before each group's dispatch in the multi-task dispatch stage.

**Tasks**:
- [ ] Re-verify line numbers before editing.
- [ ] In Stage MT-4 (`### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight`, currently
      line 655), in the "Dispatch all groups in ONE message" region (currently 693-705), add a
      per-task `skill_preflight_update` call before each group's Agent dispatch, using
      `"${session_id}_${task_num}"` as the session id (matching the existing per-task postflight
      convention in this stage):
  - [ ] `research_tasks` loop (currently 695-696): `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"`
  - [ ] `plan_tasks` loop (currently 698-700): `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"`
  - [ ] `implement_tasks` loop (currently 702-705): `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"`
- [ ] Note in the edited text that these preflights run per task before the single batched
      dispatch message (consistent with the BATCHING RULE) and are idempotent.

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` — Stage MT-4 dispatch region: one preflight call
  per task group.

**Verification**:
- Stage MT-4 contains three `skill_preflight_update` calls using the `${session_id}_${task_num}`
  form, one per group.
- The calls precede the corresponding Agent dispatch descriptions.

---

### Phase 3: Hard skill preflights + heading rename [COMPLETED]

**Goal**: Add the four preflight calls to `skill-orchestrate-hard/SKILL.md` with the exact H4
ordering constraint, and rename its Stage 2 heading.

**Tasks**:
- [x] Re-verify line numbers before editing. *(completed: anchors matched plan within a few lines; applied to both the canonical source at agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md and the deployed .claude/ copy)*
- [x] Rename `### Stage 2: Preflight — Loop Guard and Churn State` (currently line 187) to drop
      "Preflight" — e.g. `### Stage 2: Loop Guard and Churn State Initialization`. *(completed)*
- [x] `not_started` handler (currently `#### State: \`not_started\``, line 324): before the
      `Agent tool:` block (currently 329), add `skill_preflight_update "$task_number" "research" "$session_id"`. *(completed)*
- [x] `researched` H4 handler (currently line 342): add
      `skill_preflight_update "$task_number" "plan" "$session_id"` **inside** the
      `if [ "$adversarial_verified" = "true" ]` block (currently 376-381), immediately before the
      `subagent_type: $PLANNER_AGENT` Agent call (currently 377). **MUST NOT** place it in the
      verification re-dispatch branch (currently 364-368) — that branch re-dispatches
      `$RESEARCH_AGENT` while status is `researched` and must not receive a research preflight
      (would regress status to `researching`). Add an inline comment stating this constraint.
      *(completed: preflight call and 4-line constraint comment inserted immediately inside the
      `if [ "$adversarial_verified" = "true" ]` block, before the `subagent_type: $PLANNER_AGENT`
      call; the verification re-dispatch branch above it received no preflight call)*
- [x] `planned` or `implementing` H1 per-phase handler (currently line 388): add
      `skill_preflight_update "$task_number" "implement" "$session_id"` **inside** the
      `if [ -n "$next_phase" ]` branch (currently opens at 418), immediately before the
      `Agent tool: subagent_type: $IMPLEMENT_AGENT` call (currently 433). MUST NOT add it in the
      `elif` skeleton-exhaustion branch (447-453) or the final `else` all-complete branch
      (455-461) — neither dispatches an implement agent. Add a brief note that this preflight's
      one-time side effects (workflow-active marker, first-phase auto-advance) do not collide with
      the heading scan, which already matches `IN PROGRESS`. *(completed)*
- [x] `partial` continuation sub-state (currently `**Sub-state: continuation available**`,
      line 506): add `skill_preflight_update "$task_number" "implement" "$session_id"` before the
      per-phase implement dispatch described there (defense-in-depth, idempotent). *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — heading rename (Stage 2); four preflight
  insertions with the H4 ordering constraint enforced and commented.

**Verification**:
- `grep -c "skill_preflight_update" .claude/skills/skill-orchestrate-hard/SKILL.md` returns 4.
- The `plan` preflight appears after the `adversarial_verified=true` gate line, never in the
  verification re-dispatch branch (visually confirm ordering relative to the two
  `subagent_type: $RESEARCH_AGENT` blocks in the `researched` handler).
- The `implement` preflight sits inside the `if [ -n "$next_phase" ]` branch only.
- The Stage 2 heading no longer contains "Preflight".

---

### Phase 4: Architecture doc note [NOT STARTED]

**Goal**: Keep the state-machine spec in sync with the implementation.

**Tasks**:
- [ ] In `.claude/docs/architecture/orchestrate-state-machine.md`, at the Complete State Table
      (currently `## Complete State Table`, line 17) which already lists `researching`/`planning`
      as reachable states, add a short note (a sentence directly under the table, or a new
      one-line row footnote) stating that `dispatch()` now performs the preflight status
      transition (to `researching`/`planning`/`implementing`) immediately before invoking the
      Agent tool, so these in-flight states are entered during the work window.
- [ ] Cite durable anchors only (the skill file names and the "Complete State Table" section) —
      no task-number references (per no-task-references-in-deliverables).

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/orchestrate-state-machine.md` — add the preflight-transition note at
  the Complete State Table.

**Verification**:
- The doc contains a sentence describing `dispatch()` performing the preflight status transition.
- No "task N" / "task N-M" citations were introduced (advisory hook
  `validate-no-task-references.sh` surfaces none).

---

### Phase 5: Manual verification [NOT STARTED]

**Goal**: Confirm the wiring works and the H4 constraint holds, since no orchestrate test harness
exists.

**Tasks**:
- [ ] Static checks: `grep -n "skill_preflight_update" .claude/skills/skill-orchestrate/SKILL.md`
      and `.../skill-orchestrate-hard/SKILL.md` show the expected counts and positions from
      Phases 1-3.
- [ ] Confirm no `### Stage 2: Preflight` heading remains in either skill file
      (`grep -rn "Stage 2: Preflight" .claude/skills/skill-orchestrate*/SKILL.md` returns nothing).
- [ ] Trace-read (or dry-run against a throwaway/scratch task) each single-task handler to confirm
      the preflight call precedes the Agent dispatch and uses the correct operation
      (`research`/`plan`/`implement`).
- [ ] H4 ordering assertion: in `skill-orchestrate-hard`, confirm by reading that the `plan`
      preflight is only reachable when `adversarial_verified=true`, and the verification
      re-dispatch of `$RESEARCH_AGENT` has no preflight — status stays `researched` across a
      verification pass.
- [ ] Idempotency spot-check: confirm `update-task-status.sh` no-ops when already at target status
      (so repeated per-phase implement dispatches and continuation resumes do not thrash status).

**Timing**: 20 minutes

**Depends on**: 2, 3, 4

**Files to modify**: none (verification only).

**Verification**:
- All static greps pass; the H4 ordering is confirmed by reading; a scratch-task dry run (if run)
  shows status transitioning to the in-progress variant during dispatch.

## Testing & Validation

- [ ] `grep -c "skill_preflight_update" .claude/skills/skill-orchestrate/SKILL.md` >= 7
      (4 single-task + 3 multi-task).
- [ ] `grep -c "skill_preflight_update" .claude/skills/skill-orchestrate-hard/SKILL.md` == 4.
- [ ] `grep -rn "Stage 2: Preflight" .claude/skills/skill-orchestrate*/SKILL.md` returns nothing.
- [ ] Hard skill: `plan` preflight is inside the `adversarial_verified=true` block; no preflight in
      the verification re-dispatch branch.
- [ ] Hard skill: `implement` preflight only inside the `if [ -n "$next_phase" ]` branch.
- [ ] Architecture doc references the `dispatch()` preflight transition.
- [ ] No task-number citations introduced outside `specs/**`.

## Artifacts & Outputs

- `.claude/skills/skill-orchestrate/SKILL.md` (edited)
- `.claude/skills/skill-orchestrate-hard/SKILL.md` (edited)
- `.claude/docs/architecture/orchestrate-state-machine.md` (edited)
- `specs/876_wire_preflight_into_orchestrate_paths/plans/01_wire-preflight-orchestrate.md` (this plan)
- `specs/876_wire_preflight_into_orchestrate_paths/summaries/01_wire-preflight-orchestrate-summary.md` (on completion)

## Rollback/Contingency

All changes are additive text edits (call insertions + heading renames + a doc sentence) across
three files with no schema or script changes. To revert, `git checkout` the three edited files
(the skill files and the architecture doc) — no state, migration, or data changes are involved.
If the H4 ordering is discovered wrong post-merge, the fix is localized to the single `plan`
preflight line in the hard skill's `researched` handler.
