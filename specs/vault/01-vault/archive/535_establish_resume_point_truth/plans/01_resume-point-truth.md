# Implementation Plan: Establish Plan Markers as Primary Resume Source of Truth

- **Task**: 535 - establish_resume_point_truth
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: specs/535_establish_resume_point_truth/reports/01_resume-point-research.md
- **Artifacts**: plans/01_resume-point-truth.md (this file)
- **Standards**:
  - .opencode/context/formats/plan-format.md
  - .opencode/context/formats/status-markers.md
  - .opencode/context/formats/artifact-management.md
  - .opencode/context/formats/tasks.md
- **Type**: markdown

## Overview

The current implementation resume mechanism maintains two competing sources of truth for resume points: plan file phase markers (`[NOT STARTED]`, `[IN PROGRESS]`, `[PARTIAL]`, `[COMPLETED]`) and the ad-hoc `resume_phase` field in `state.json`. When these diverge, agents waste tokens reconciling them and may resume from the wrong phase. This plan makes plan file markers the single source of truth, removes or demotes `state.json` `resume_phase`, and adds defensive warnings when sources disagree.

## Goals & Non-Goals

- **Goals**:
  - Make plan file phase status markers the primary source of truth for resume points
  - Remove `resume_phase` postflight writes from all implementation skills
  - Update `/implement` command to declare plan markers as primary and compare against stale `state.json` values
  - Add a warning mechanism when plan markers and `state.json` disagree by more than 1 phase
  - Audit and update all ~25 `resume_phase` references across commands, skills, and agents
- **Non-Goals**:
  - Refactoring the overall checkpoint/GATE IN/GATE OUT architecture
  - Changing how plan markers are written by subagents (that mechanism remains unchanged)
  - Modifying historical/archive entries in `specs/archive/state.json`

## Risks & Mitigations

- **Risk**: Subagents or skills still rely on the `resume_phase` parameter after it is removed. Mitigation: Update all agent prompts to explicitly instruct scanning plan markers; grep for `resume_phase` after changes to verify zero active references.
- **Risk**: `skill-team-implement` uses `resume_phase` for wave scheduling. Mitigation: Review team skill logic in Phase 4; if needed, compute wave start from plan markers instead.
- **Risk**: Stale `resume_phase` values in active `state.json` entries mislead users reading raw state. Mitigation: Phase 5 removes or renames the field; no functional code depends on it.
- **Risk**: Off-by-one errors when comparing plan marker phase numbers to legacy `state.json` values. Mitigation: Comparison logic uses exact numeric difference and warns only when delta > 1.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5, 6 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Update /implement Command to Specify Plan Markers as PRIMARY Source of Truth [NOT STARTED]
- **Goal:** Update the `/implement` command specification so that plan file markers are explicitly declared the primary source of truth and `state.json` `resume_phase` is treated as advisory only.
- **Tasks:**
  - [ ] **Task 1.1**: Edit `.opencode/commands/implement.md` (CHECKPOINT 1: GATE IN) to add a primary-source declaration: "Plan file markers are the PRIMARY source of truth for resume points. `state.json` `resume_phase` is advisory."
  - [ ] **Task 1.2**: Add comparison logic before delegation:
    - Scan plan for resume point -> `plan_resume_phase`
    - Read `state.json` `resume_phase` -> `state_resume_phase`
    - If they differ by more than 1 phase: log a warning, use `plan_resume_phase`, and optionally clear the stale `state_resume_phase`
  - [ ] **Task 1.3**: Repeat updates for `.opencode/extensions/core/commands/implement.md` if it mirrors the core command
- **Timing:** 15-20 minutes
- **Depends on:** none

### Phase 2: Update skill-implementer to Calculate Resume from Plan File [NOT STARTED]
- **Goal:** Remove `resume_phase` from `skill-implementer` delegation context and postflight, and ensure the skill instructs subagents to scan plan markers.
- **Tasks:**
  - [ ] **Task 2.1**: Edit `.opencode/skills/skill-implementer/SKILL.md` to remove `resume_phase` from the delegation context JSON passed to `general-implementation-agent`
  - [ ] **Task 2.2**: Update the subagent prompt section to instruct: "To determine where to resume, scan the plan file for phase status markers. Do not rely on `resume_phase` from state.json."
  - [ ] **Task 2.3**: Remove the `resume_phase` jq update block from the partial postflight path (Stage 7, ~line 438)
  - [ ] **Task 2.4**: Repeat the above for `.opencode/extensions/core/skills/skill-implementer/SKILL.md` and `.claude/skills/skill-implementer/SKILL.md` if they exist and differ
- **Timing:** 15-20 minutes
- **Depends on:** 1

### Phase 3: Update skill-lean-implementation to Calculate Resume from Plan File [NOT STARTED]
- **Goal:** Remove `resume_phase` from the lean implementation skill and align it with the plan-marker-first policy.
- **Tasks:**
  - [ ] **Task 3.1**: Edit `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` to remove `resume_phase` from delegation context (line 93)
  - [ ] **Task 3.2**: Update subagent prompt to instruct scanning plan markers for resume point
  - [ ] **Task 3.3**: Verify that the skill does NOT write `resume_phase` in postflight (research indicates it already does not, but confirm)
- **Timing:** 10 minutes
- **Depends on:** 1

### Phase 4: Audit and Update Other Implementation Skills [NOT STARTED]
- **Goal:** Remove `resume_phase` postflight writes and parameter acceptance from all remaining implementation skills.
- **Tasks:**
  - [ ] **Task 4.1**: Edit `.claude/skills/skill-neovim-implementation/SKILL.md` (~line 232): remove `resume_phase` postflight jq block
  - [ ] **Task 4.2**: Edit `.claude/skills/skill-nix-implementation/SKILL.md` (~line 277): remove `resume_phase` postflight jq block
  - [ ] **Task 4.3**: Edit `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` (~line 228): remove `resume_phase` postflight jq block
  - [ ] **Task 4.4**: Edit `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` (~line 214): remove `resume_phase` postflight jq block
  - [ ] **Task 4.5**: Edit `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md` (~line 282): remove `resume_phase` postflight jq block
  - [ ] **Task 4.6**: Edit `.opencode/extensions/core/context/patterns/inline-status-update.md` (~line 155): remove or update `resume_phase` reference
  - [ ] **Task 4.7**: Edit `.opencode/skills/skill-team-implement/SKILL.md` (~line 39): review wave-start logic; remove `resume_phase` if not needed or compute from plan markers
  - [ ] **Task 4.8**: Edit `.opencode/extensions/founder/skills/skill-founder-implement/SKILL.md` (~line 49): remove `resume_phase` parameter
  - [ ] **Task 4.9**: Edit `.opencode/extensions/founder/skills/skill-deck-implement/SKILL.md` (~line 50): remove `resume_phase` parameter
  - [ ] **Task 4.10**: Run `rg "resume_phase"` across the entire `.opencode/` and `.claude/` trees to verify no remaining active references in skills/commands (ignore archive/historical)
- **Timing:** 20-30 minutes
- **Depends on:** 2, 3

### Phase 5: Remove or Deprecate resume_phase from state.json [NOT STARTED]
- **Goal:** Eliminate the stale `resume_phase` field from the active state schema and existing entries.
- **Tasks:**
  - [ ] **Task 5.1**: Update `.opencode/context/reference/state-management-schema.md` to remove `resume_phase` from documentation (or add a deprecation note if choosing Option 2)
  - [ ] **Task 5.2**: Strip `resume_phase` fields from all entries in `specs/state.json` using a targeted jq command
  - [ ] **Task 5.3**: Update any validation scripts (e.g., `.opencode/scripts/validate-state.sh` if it exists) to reject or warn on `resume_phase`
- **Timing:** 10-15 minutes
- **Depends on:** 4

### Phase 6: Add Warning When Plan Markers and state.json Disagree by >1 Phase [NOT STARTED]
- **Goal:** Implement the defensive comparison logic in `/implement` and optionally in a shared helper so that divergence is visible.
- **Tasks:**
  - [ ] **Task 6.1**: Implement the comparison in `.opencode/commands/implement.md` (CHECKPOINT 1):
    - `plan_resume_phase` = first non-COMPLETED phase from plan scan
    - `state_resume_phase` = value from `state.json` (or null)
    - If `state_resume_phase` is present and `|plan_resume_phase - state_resume_phase| > 1`, emit a warning to the user and use `plan_resume_phase`
  - [ ] **Task 6.2**: If a shared resume-point helper script exists (e.g., `.opencode/scripts/compute-resume-phase.sh`), centralize the comparison there and call it from `/implement`
  - [ ] **Task 6.3**: Repeat for `.opencode/extensions/core/commands/implement.md`
- **Timing:** 10-15 minutes
- **Depends on:** 4

## Testing & Validation

- [ ] Run `rg "resume_phase" .opencode/ .claude/` and confirm no active references remain (only historical/archive hits)
- [ ] Verify `/implement` command documentation includes the primary-source declaration
- [ ] Verify `skill-implementer` no longer writes `resume_phase` in partial postflight
- [ ] Verify `state-management-schema.md` does not list `resume_phase` as a valid field
- [ ] Verify `specs/state.json` has no `resume_phase` keys in active project entries
- [ ] Dry-run `/implement` logic path to ensure warning triggers correctly when a mock disagreement is injected

## Artifacts & Outputs

- plans/01_resume-point-truth.md (this file)
- Updated `.opencode/commands/implement.md`
- Updated `.opencode/skills/skill-implementer/SKILL.md`
- Updated `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- Updated extension implementation skills (neovim, nix, web, founder, deck, team)
- Updated `.opencode/context/reference/state-management-schema.md`
- Cleaned `specs/state.json` (no `resume_phase` fields)

## Rollback/Contingency

- If any skill still requires `resume_phase` for complex logic (e.g., `skill-team-implement` wave scheduling), revert that specific skill to advisory-cache mode (Option 2) instead of full removal.
- If stripping `resume_phase` from `state.json` causes downstream tooling issues, restore from git and switch to deprecation-only (schema note + warning).
- Keep a local git branch until validation is complete so all changes can be reverted in one command.
