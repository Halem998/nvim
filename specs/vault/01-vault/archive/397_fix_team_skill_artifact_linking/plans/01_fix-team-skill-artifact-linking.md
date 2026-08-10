# Implementation Plan: Fix Team-Mode Skill TODO.md Artifact Linking

- **Task**: 397 - fix_team_skill_artifact_linking
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md
- **Artifacts**: plans/01_fix-team-skill-artifact-linking.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/reference/state-management-schema.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Team-mode skills (skill-team-research, skill-team-plan, skill-team-implement) update
`state.json` artifacts but fail to insert the count-aware artifact link into
`specs/TODO.md`, creating drift between machine and user-facing state. This plan adds
an in-place "Link Artifact to TODO.md" step to each team skill's postflight stage,
mirroring the single-agent Stage 8 pattern verbatim. Shared-helper extraction is
explicitly deferred to a follow-up task to keep this fix minimal and reviewable.

### Research Integration

The research report (`01_team-skill-artifact-linking.md`) confirms the bug via task 396
git-history forensics, identifies exact gap locations in all three team skills (Stage
10 for research/plan, Stage 12 for implement), cites the canonical four-case insertion
logic from single-agent skills, and recommends in-place duplication over shared-helper
extraction due to the skill-boundary halt constraint documented in skill-status-sync.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances internal agent-system correctness; no explicit ROADMAP.md item is directly
tied to this fix, but it restores parity between team-mode and single-agent workflows,
which is implicit infrastructure health.

## Goals & Non-Goals

**Goals**:
- Add TODO.md artifact-link insertion to skill-team-research postflight.
- Add TODO.md artifact-link insertion to skill-team-plan postflight.
- Add TODO.md artifact-link insertion to skill-team-implement postflight.
- Ensure count-aware format: inline for 1 artifact, multi-line list for 2+.
- Preserve TODO.md field ordering (Research before Plan before Summary, under
  Task Type, above Description) consistent with single-agent skills.
- Verify end-to-end with a throwaway test task across all three team commands.

**Non-Goals**:
- Extracting a shared helper script (`link-artifact-todo.sh`) -- deferred to a
  follow-up meta task that will refactor all six skills (three single-agent +
  three team) together. This plan documents the deferral.
- Lifting the "standalone only" restriction on skill-status-sync.
- Retroactively fixing task 396's non-canonical `- **Artifacts**:` wrapper in
  TODO.md -- that is a separate drift issue for `/fix-it` or manual cleanup.
- Modifying single-agent skills (skill-researcher, skill-planner, skill-implementer).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit-tool access missing in team skill postflight | H | L | Postflight runs on orchestrator, not subagent; verify allowed-tools in SKILL.md frontmatter during Phase 1 |
| Next-field anchor mismatch when no later field exists | M | M | Copy single-agent anchor logic verbatim; insert after `- **Task Type**:` when no later anchor present |
| Drift from canonical four-case detection | M | L | Copy single-agent text verbatim; do not paraphrase |
| Test task pollutes specs/ state.json | L | M | Use high-numbered throwaway task and `/task --abandon` during cleanup |
| TODO.md ordering concern: inserted field positioned incorrectly relative to Description/Plan fields | M | M | Phase 1 explicitly documents anchor selection per artifact type; verification phase inspects field order |
| Non-canonical task 396 entry trips up a future re-research | L | L | Out of scope; documented in non-goals |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Audit and Anchor Mapping [COMPLETED]

**Goal**: Read all six skill files, confirm exact gap locations, verify Edit-tool
availability in team skill frontmatter, and produce a per-skill anchor table that
phases 2-4 will apply verbatim.

**Tasks**:
- [ ] Read `.claude/skills/skill-researcher/SKILL.md` Stage 8 (lines ~263-308) and
      record the exact four-case Edit block as the research reference template.
- [ ] Read `.claude/skills/skill-planner/SKILL.md` Stage 8 (lines ~284-329) and
      record the exact four-case Edit block as the plan reference template.
- [ ] Read `.claude/skills/skill-implementer/SKILL.md` Stage 8 (lines ~335-380) and
      record the exact four-case Edit block as the summary reference template.
- [ ] Read `.claude/skills/skill-team-research/SKILL.md` Stage 10 to locate exact
      insertion point after the `jq ... .artifacts += [...]` block.
- [ ] Read `.claude/skills/skill-team-plan/SKILL.md` Stage 10 to locate insertion point.
- [ ] Read `.claude/skills/skill-team-implement/SKILL.md` Stage 12 to locate insertion point.
- [ ] Verify `allowed-tools` frontmatter in each team SKILL.md includes `Edit` and `Read`.
- [ ] Produce anchor table: for each artifact type record (field label, next-field
      anchor when present, fallback anchor when absent, filename pattern).

**Timing**: 30 minutes

**Depends on**: none

**Files to read** (no modifications in this phase):
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-team-research/SKILL.md`
- `.claude/skills/skill-team-plan/SKILL.md`
- `.claude/skills/skill-team-implement/SKILL.md`

**Verification**:
- Anchor table is complete with four cases x three artifact types.
- Edit tool confirmed in allowed-tools frontmatter for all three team skills.

---

### Phase 2: Add TODO.md Linking to skill-team-research [COMPLETED]

**Goal**: Insert a "Link Artifact to TODO.md" sub-step into skill-team-research
Stage 10, immediately after the existing state.json artifact append, mirroring the
skill-researcher Stage 8 four-case Edit block verbatim.

**Tasks**:
- [ ] Open `.claude/skills/skill-team-research/SKILL.md` and locate the line
      following the `jq ... .artifacts += [...]` block in Stage 10.
- [ ] Insert a new sub-step "**Update TODO.md**: Add research artifact link using
      count-aware format" with four cases:
  1. No existing `- **Research**:` line -> insert inline after `- **Task Type**:`.
  2. Existing inline (single link) -> convert to multi-line with both items.
  3. Existing multi-line -> append new item before next field anchor `- **Plan**:`
     (or `**Description**:` if no plan field yet).
  4. Exact old_string/new_string patterns per single-agent template.
- [ ] Use filename pattern `{NN}_team-research.md` in all insertion paths.
- [ ] Add cross-reference to `.claude/rules/state-management.md` "Artifact Linking Format".
- [ ] Re-read the file to confirm the edit landed in the correct Stage 10 position
      (after state.json jq, before Stage 11 "Write Metadata File").

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - add TODO.md linking sub-step in Stage 10.

**Verification**:
- Grep the file for `**Update TODO.md**: Add research artifact link` returns one match.
- Four-case structure present verbatim from skill-researcher.
- Filename pattern uses `team-research` not `initial-research`.

---

### Phase 3: Add TODO.md Linking to skill-team-plan [COMPLETED]

**Goal**: Insert a "Link Artifact to TODO.md" sub-step into skill-team-plan Stage 10,
mirroring skill-planner Stage 8 with `- **Plan**:` label and `**Description**:` anchor.

**Tasks**:
- [ ] Locate insertion point after the `jq ... .artifacts += [...]` block in Stage 10
      of `.claude/skills/skill-team-plan/SKILL.md`.
- [ ] Insert the four-case Edit block with:
  - Field label: `- **Plan**:`
  - Next-field anchor: `**Description**:`
  - Fallback anchor (insert after): `- **Research**:` if present, else `- **Task Type**:`
  - Filename pattern: `{NN}_implementation-plan.md` (or team synthesis name actually
    emitted by skill-team-plan -- confirm in Phase 1 audit)
- [ ] Add cross-reference to `.claude/rules/state-management.md`.
- [ ] Re-read to confirm placement.

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-plan/SKILL.md` - add TODO.md linking sub-step in Stage 10.

**Verification**:
- Grep shows one `**Update TODO.md**: Add plan artifact link` match.
- Anchor uses `**Description**:` consistent with skill-planner.

---

### Phase 4: Add TODO.md Linking to skill-team-implement [COMPLETED]

**Goal**: Insert a "Link Artifact to TODO.md" sub-step into skill-team-implement
Stage 12, mirroring skill-implementer Stage 8 with `- **Summary**:` label.

**Tasks**:
- [ ] Locate insertion point after the `jq ... .artifacts += [...]` block in
      Stage 12 of `.claude/skills/skill-team-implement/SKILL.md`.
- [ ] Insert the four-case Edit block with:
  - Field label: `- **Summary**:`
  - Next-field anchor: `**Description**:`
  - Fallback anchor: insert after `- **Plan**:` if present, else `- **Research**:`,
    else `- **Task Type**:`
  - Filename pattern: `{NN}_implementation-summary.md` (or actual team synthesis
    summary filename from Phase 1 audit)
- [ ] Add cross-reference.
- [ ] Re-read to confirm placement.

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - add TODO.md linking sub-step in Stage 12.

**Verification**:
- Grep shows one `**Update TODO.md**: Add summary artifact link` match.
- Field label is `- **Summary**:`.

---

### Phase 5: End-to-End Verification with Test Task [COMPLETED]

**Goal**: Create a throwaway test task, run all three team commands against it, and
confirm TODO.md entries receive canonical top-level artifact links in correct order.

**Tasks**:
- [ ] Create a throwaway task: `/task "Test team-mode artifact linking fix"` (records
      task number as {TEST_N}).
- [ ] Run `/research {TEST_N} --team` (use minimum team_size=2 to reduce token cost).
- [ ] Inspect `specs/TODO.md` task {TEST_N} entry: confirm a top-level
      `- **Research**: [{NN}_team-research.md](...)` line exists immediately after
      `- **Task Type**:` (NOT nested under `- **Artifacts**:`).
- [ ] Inspect `specs/state.json`: confirm artifact entry matches.
- [ ] Run `/plan {TEST_N} --team`.
- [ ] Confirm `- **Plan**:` line added as sibling of `- **Research**:`, above
      `**Description**:`.
- [ ] Run `/implement {TEST_N} --team` (may skip if plan has trivial phases; if
      /implement --team is impractical as a test, document the manual `- **Summary**:`
      verification using a dry inspection of the stage text instead).
- [ ] Confirm `- **Summary**:` line added as sibling.
- [ ] Verify count-aware behavior: the single-artifact case (inline format) is
      exercised naturally by the test flow since each type has exactly one artifact.
- [ ] Optionally exercise the multi-artifact case by running `/revise {TEST_N}` ->
      `/research {TEST_N}` a second time (or manually simulating) and confirm the
      single `- **Research**:` inline line converts to multi-line with two items.
- [ ] Grep the test task's TODO.md entry for `- **Artifacts**:` wrapper -- must not appear.
- [ ] Run `/task --abandon {TEST_N}` to clean up; verify state.json and TODO.md reflect
      abandonment.
- [ ] Remove or archive the `specs/{TEST_NNN}_*/` directory created by the test task.

**Timing**: 45 minutes

**Depends on**: 2, 3, 4

**Files involved** (read/inspected):
- `specs/TODO.md`
- `specs/state.json`
- `specs/{TEST_NNN}_*/` (created and then abandoned)

**Verification**:
- All three top-level artifact link lines present in test task entry.
- No `- **Artifacts**:` wrapper.
- Count-aware conversion from inline to multi-line verified (if exercised).
- Test task successfully abandoned and cleaned up.

---

### Phase 6: Document Deferred Shared-Helper Refactor [COMPLETED]

**Goal**: Record the deferred shared-helper extraction as an explicit follow-up task
so the duplication introduced by this plan is tracked and eventually retired.

**Tasks**:
- [ ] Create a new follow-up task via `/task`: "Extract artifact-linking logic to
      shared helper script (consolidate six skill Stage 8 blocks)".
- [ ] In the task description, cite task 397, list the six skills, and reference the
      research report's recommendation (section "Existing helper candidates") and
      the trade-offs between sed-based scripts and Edit-tool in-place logic.
- [ ] Note dependency: follow-up task blocked on 397 being [COMPLETED].
- [ ] Optionally link the new task number back into the task 397 summary metadata
      for traceability.

**Timing**: 15 minutes

**Depends on**: 5

**Files to modify**:
- `specs/TODO.md` - prepend new follow-up task entry.
- `specs/state.json` - register new task.

**Verification**:
- New task entry present in TODO.md with reference to task 397.
- state.json `next_project_number` incremented.
- Research report recommendation section cited in the new task description.

## Testing & Validation

- [ ] All three team skills have a `**Update TODO.md**: Add {type} artifact link`
      sub-step in their postflight.
- [ ] Throwaway test task passes the end-to-end check in Phase 5.
- [ ] TODO.md entry for the test task contains top-level `- **Research**:`,
      `- **Plan**:`, `- **Summary**:` lines in correct order.
- [ ] No `- **Artifacts**:` wrapper introduced by the fix.
- [ ] `.claude/scripts/check-extension-docs.sh` passes (no doc-lint regressions).
- [ ] Manual re-read of each modified SKILL.md confirms the four-case block is
      verbatim from the single-agent reference.

## Artifacts & Outputs

- Modified: `.claude/skills/skill-team-research/SKILL.md`
- Modified: `.claude/skills/skill-team-plan/SKILL.md`
- Modified: `.claude/skills/skill-team-implement/SKILL.md`
- Created (then abandoned): `specs/{TEST_NNN}_test_team_artifact_linking/` test task
- Created: new follow-up task entry for shared-helper refactor
- Summary: `specs/397_fix_team_skill_artifact_linking/summaries/01_fix-team-skill-artifact-linking-summary.md`

## Rollback/Contingency

If any phase fails or the verification test task reveals incorrect insertion:

1. Revert the modified SKILL.md files via `git checkout -- .claude/skills/skill-team-*/SKILL.md`.
2. Abandon and clean up the test task (`/task --abandon {TEST_N}`, remove test directory).
3. Re-open task 397, log the failure mode in `specs/errors.json`, and iterate on
   Phase 1's anchor table before retrying phases 2-4.
4. If the root cause is an Edit-tool access limitation in team-skill postflight
   contexts, escalate to the shared-helper route (promote the deferred follow-up
   task to replace the in-place approach).
