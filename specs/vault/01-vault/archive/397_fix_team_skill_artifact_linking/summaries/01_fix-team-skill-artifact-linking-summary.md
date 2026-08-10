# Implementation Summary: Fix Team-Mode Skill TODO.md Artifact Linking

- **Task**: 397 - fix_team_skill_artifact_linking
- **Status**: [COMPLETED]
- **Started**: 2026-04-10T18:55:29Z
- **Completed**: 2026-04-10T20:45:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**:
  - specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md
  - specs/397_fix_team_skill_artifact_linking/plans/01_fix-team-skill-artifact-linking.md
  - specs/397_fix_team_skill_artifact_linking/summaries/01_fix-team-skill-artifact-linking-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, artifact-formats.md, state-management.md

## Overview

The three team-mode skills (`skill-team-research`, `skill-team-plan`, `skill-team-implement`) updated `state.json` but failed to insert the count-aware artifact link into `specs/TODO.md`, causing silent drift from single-agent behavior. This fix adds an in-place "Update TODO.md" sub-step to each team skill's postflight stage, mirroring the canonical four-case Edit block from the corresponding single-agent skill verbatim, and records the deferred shared-helper refactor as follow-up task 398.

## What Changed

- `.claude/skills/skill-team-research/SKILL.md` Stage 10: added four-case TODO.md linking sub-step for `- **Research**:` with `{NN}_team-research.md` filename pattern.
- `.claude/skills/skill-team-plan/SKILL.md` Stage 10: added four-case TODO.md linking sub-step for `- **Plan**:` with `{NN}_implementation-plan.md` filename pattern and `**Description**:` anchor.
- `.claude/skills/skill-team-implement/SKILL.md` Stage 12: added four-case TODO.md linking sub-step for `- **Summary**:` with `{NN}_implementation-summary.md` filename pattern.
- `specs/state.json`: registered follow-up task 398 (`extract_artifact_linking_helper`), incremented `next_project_number` to 399.
- `specs/TODO.md`: prepended task 398 entry with dependency on 397.
- Plan file phase markers advanced from `[NOT STARTED]` through `[COMPLETED]` for all six phases; plan header status set to `[COMPLETED]`.

## Decisions

- Duplicated the single-agent Stage 8 block verbatim rather than extracting a shared helper, per the research report's recommendation (keeps this fix minimal and reviewable; shared-helper refactor is now tracked as task 398).
- Phase 5 verification was performed statically (grep across the three modified files plus re-reads) rather than via a live throwaway test task: creating and abandoning a real task from within an implementation agent session is not reliably self-executable and would pollute `state.json`. A live `/research --team` run remains recommended as manual follow-up.
- Used `Edit`-tool four-case logic (not a sed script) to match the single-agent reference exactly and avoid introducing a new pattern.

## Impacts

- Team-mode `/research --team`, `/plan --team`, `/implement --team` will now keep `TODO.md` synchronized with `state.json` artifact entries on their next invocation.
- Six skills now carry near-identical Stage 8 TODO.md linking logic; this duplication is intentional and tracked by task 398.
- No behavior change for single-agent skills (unchanged).

## Follow-ups

- Task 398: Extract artifact-linking logic to shared helper script (blocked on 397 [COMPLETED]).
- Manual live verification: run `/research --team` on a test task and confirm TODO.md receives the top-level `- **Research**:` line (not nested under `- **Artifacts**:`).
- Task 396's existing non-canonical `- **Artifacts**:` wrapper in TODO.md is out of scope (documented in plan non-goals).

## References

- `.claude/skills/skill-team-research/SKILL.md` (Stage 10)
- `.claude/skills/skill-team-plan/SKILL.md` (Stage 10)
- `.claude/skills/skill-team-implement/SKILL.md` (Stage 12)
- `.claude/skills/skill-researcher/SKILL.md` (Stage 8, reference template)
- `.claude/skills/skill-planner/SKILL.md` (Stage 8, reference template)
- `.claude/skills/skill-implementer/SKILL.md` (Stage 8, reference template)
- `.claude/rules/state-management.md` (Artifact Linking Format)
- `specs/397_fix_team_skill_artifact_linking/plans/01_fix-team-skill-artifact-linking.md`
- `specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`
