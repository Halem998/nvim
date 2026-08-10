# Implementation Plan: Task #678

- **Task**: 678 - auto_escalation_advisory_v2
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None (task 669 hard_mode_agent_system already completed)
- **Research Inputs**: specs/678_auto_escalation_advisory_v2/reports/01_auto-escalation-research.md
- **Artifacts**: plans/01_auto-escalation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add advisory-only churn detection to the standard orchestrator (`skill-orchestrate/SKILL.md`) that emits a "consider --hard" warning when repeated deflection patterns are observed. Three signals are tracked: plan revision count (>= 2), implement dispatches with no phase progress (>= 3), and analysis-only output (>= 1). Counters persist in the existing loop guard file. The advisory emits once per task lifecycle and never alters dispatch routing.

### Research Integration

The research report identified three measurable signals, all extractable from data already available in the orchestrator loop (handoff fields, plan directory listing). The implementation is contained to `skill-orchestrate/SKILL.md` with three insertion points: Stage 2 (counter initialization), Stage 5 (churn check function call), and a new `check_churn_advisory()` function definition. The loop guard schema is extended with a `churn_advisory` sub-object. Stage 7's selective jq merge already preserves unmentioned fields, so no Stage 7 changes are needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is an internal agent system quality improvement.

## Goals & Non-Goals

**Goals**:
- Detect churn patterns in the standard orchestrator via three measurable signals
- Emit a one-time human-readable advisory suggesting `--hard` mode
- Persist churn counters across `/orchestrate` invocations via the loop guard file
- Keep the implementation minimal (60-80 lines added to one file)

**Non-Goals**:
- Auto-escalation to `--hard` mode (advisory only, never alters routing)
- Multi-task mode support (MT-1 through MT-5 are out of scope for v1)
- Reading plan files or implementation summaries (violates context flatness)
- Modifying `skill-orchestrate-hard/SKILL.md` (already has full churn detection)
- Creating new files (all changes in existing SKILL.md)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Analysis-only keyword regex matches legitimate summary text | L | M | Use tight regex with exact phrases from Report 01; threshold of 1 means low false-positive cost since it is advisory-only |
| Stage 7 jq selective merge accidentally overwrites churn_advisory | H | L | Stage 7 only updates `.current_state`, `.last_updated`, `.cycle_count` -- selective merge preserves other fields. Verify in testing. |
| Churn counter inflation from loop guard manual deletion | L | L | Deletion resets counters to 0; advisory will re-trigger once thresholds are crossed again, which is correct behavior |
| Signal 2 counter never resets, leading to stale churn signal | M | M | Counter resets to 0 whenever `phases_delta > 0` (actual progress made) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |
| 3    | 3      | 2          |

Phases within the same wave can execute in parallel.

### Phase 1: Extend Loop Guard Schema in Stage 2 [COMPLETED]

**Goal**: Add churn advisory counter fields to the loop guard initialization (fresh start) and resume reading (existing guard) in Stage 2.

**Tasks**:
- [x] In Stage 2 fresh-start branch: add `churn_advisory` sub-object to the `jq -n` command that creates the loop guard, with fields: `plan_revision_count` (0), `implement_no_progress_count` (0), `analysis_only_count` (0), `advisory_emitted` (false), `last_implement_phases_completed` (0) *(completed)*
- [x] In Stage 2 resume branch: read the five churn advisory fields from the existing loop guard using `jq -r '.churn_advisory.FIELD // DEFAULT'` pattern, storing them in shell variables `churn_plan_revisions`, `churn_no_progress`, `churn_analysis_only`, `churn_advisory_emitted`, `last_impl_phases` *(completed)*
- [x] Initialize the same shell variables in the fresh-start branch (all zeros, emitted=false) *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` -- Stage 2 section (lines ~122-158)

**Verification**:
- The loop guard JSON schema includes `churn_advisory` sub-object on fresh creation
- Resume path reads all five fields without errors
- No existing fields are removed or overwritten

---

### Phase 2: Add check_churn_advisory() Function [COMPLETED]

**Goal**: Implement the churn detection function that evaluates three signals and emits the advisory warning.

**Tasks**:
- [x] Define `check_churn_advisory()` function after Stage 5a (drift inspection), as a new Stage 5b section *(completed)*
- [x] Signal 1 (plan revisions): count `*.md` files in `${TASK_DIR}/plans/` directory using `ls -1 | wc -l`; store in `churn_plan_revisions` *(completed)*
- [x] Signal 2 (implement no-progress): compare `phases_completed` against `last_impl_phases`; increment `churn_no_progress` when delta <= 0, reset to 0 when delta > 0; update `last_impl_phases` *(completed)*
- [x] Signal 3 (analysis-only output): when `phases_completed == 0` AND `dispatch_status == "partial"`, grep `dispatch_summary` for analysis-marker regex; increment `churn_analysis_only` on match *(completed)*
- [x] Gate: skip check for `researched` and `planned` dispatch statuses (phases_completed is meaningless for those) *(completed)*
- [x] Threshold check: emit advisory if any threshold crossed (`churn_plan_revisions >= 2`, `churn_no_progress >= 3`, `churn_analysis_only >= 1`) AND `churn_advisory_emitted == false` *(completed)*
- [x] Warning output: use `[orchestrate] ADVISORY:` prefix on stderr, multi-line with counter values and `Consider: /orchestrate $task_number --hard` suggestion *(completed)*
- [x] Set `churn_advisory_emitted=true` after emission *(completed)*
- [x] Persist updated counters back to loop guard using selective `jq` field updates on the `churn_advisory` sub-object *(completed)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` -- new Stage 5b section after Stage 5a

**Verification**:
- Function compiles cleanly in bash (no syntax errors in pseudocode blocks)
- All three signals have clear measurement logic
- Advisory emits only once per task lifecycle
- Counters persist to loop guard file after each check

---

### Phase 3: Wire check_churn_advisory() into Stage 5 [COMPLETED]

**Goal**: Insert the function call into the Stage 5 handoff reading flow, after postflight status update and before artifact linking.

**Tasks**:
- [x] Add `check_churn_advisory` call in Stage 5 after the `case "$dispatch_status"` postflight block and before the artifact linking section *(completed)*
- [x] Verify the call site has access to all required variables: `dispatch_status`, `dispatch_summary`, `phases_completed`, `last_impl_phases`, `churn_plan_revisions`, `churn_no_progress`, `churn_analysis_only`, `churn_advisory_emitted` *(completed)*
- [x] Verify Stage 7 loop guard update (selective jq merge) does not overwrite the `churn_advisory` sub-object -- confirm it only updates `current_state`, `last_updated`, `cycle_count` *(completed)*
- [x] Test the full flow conceptually: fresh start -> research dispatch (no check) -> plan dispatch (no check) -> implement dispatch (check fires) -> no-progress (counter increments) -> advisory emits once *(completed)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` -- Stage 5 section (lines ~368-410), inserting between postflight and artifact linking

**Verification**:
- `check_churn_advisory` is called exactly once per dispatch (not duplicated)
- Function call is inside the `if [ -f "$handoff_file" ]` guard (only runs when handoff exists)
- Stage 7 jq update confirmed to preserve `churn_advisory` via selective merge
- No changes to multi-task mode stages (MT-1 through MT-5)

## Testing & Validation

- [x] Read the modified SKILL.md and verify all three insertion points are present and syntactically correct *(completed)*
- [x] Verify loop guard JSON schema includes `churn_advisory` sub-object in the fresh-start `jq -n` command *(completed)*
- [x] Verify resume branch reads all five churn fields with `// DEFAULT` fallback pattern *(completed)*
- [x] Verify `check_churn_advisory()` function definition is complete with all three signals *(completed)*
- [x] Verify the function call site is between postflight status update and artifact linking in Stage 5 *(completed)*
- [x] Verify Stage 7 loop guard update does not touch `churn_advisory` fields *(completed)*
- [x] Verify no changes to multi-task mode sections (MT-1 through MT-5) *(completed)*
- [x] Grep the modified file for `ADVISORY` to confirm warning output format matches `[orchestrate] ADVISORY:` pattern *(completed)*

## Artifacts & Outputs

- `specs/678_auto_escalation_advisory_v2/plans/01_auto-escalation-plan.md` (this file)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified, ~60-80 lines added)

## Rollback/Contingency

Revert the single file `.claude/skills/skill-orchestrate/SKILL.md` to its pre-modification state via `git checkout HEAD -- .claude/skills/skill-orchestrate/SKILL.md`. The churn advisory is purely additive and does not alter any existing dispatch logic, so removal is clean.
