# Implementation Plan: Task #709

- **Task**: 709 - add_pr_ready_orchestrate_support
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/709_add_pr_ready_orchestrate_support/reports/01_pr-ready-orchestrate-research.md
- **Artifacts**: plans/01_pr-ready-orchestrate-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `pr_ready` state handling and `pr_description` artifact support to `skill-orchestrate` SKILL.md so the orchestrate skill properly handles the PR lifecycle for cslib extension pr tasks. All six changes are additive insertions to a single file (`.claude/skills/skill-orchestrate/SKILL.md`), following existing patterns already present in the file.

### Research Integration

The research report identified 6 precise insertion points in SKILL.md (1152 lines) and confirmed all changes are purely additive. Key findings: `pr_ready` is a terminal state for orchestrate (user must run `/pr N` to advance to COMPLETED); the dispatch_status `pr_ready` arm mirrors the `implemented` arm pattern; `pr_description` artifact type uses `**PR Description**` field name.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this meta task.

## Goals & Non-Goals

**Goals**:
- Orchestrate exits cleanly when a task reaches `pr_ready` state (Stage 4)
- Postflight status updates fire correctly for `pr_ready` dispatch results (Stage 5 and MT-4)
- `pr_description` artifacts are linked in TODO.md with the correct field name (Stage 5 and MT-4)
- Multi-task orchestration treats `pr_ready` as a terminal state (MT-3)

**Non-Goals**:
- Modifying `skill-base.sh` or `update-task-status.sh` (out of scope)
- Fixing the potential `preflight` vs `postflight` inconsistency in `skill-pr-implementation` (separate concern)
- Adding test infrastructure for orchestrate state machine changes

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect insertion location shifts existing code behavior | H | L | All insertions are new case arms or new sections between existing blocks; no existing code is modified |
| `skill_postflight_update` does not recognize `pr_ready` as success value | L | L | Expected behavior: the skill-pr-implementation already ran the status transition; orchestrate just needs to not fall through to `*` no-op |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add pr_ready support to skill-orchestrate SKILL.md [NOT STARTED]

**Goal**: Insert all 6 additive changes into `.claude/skills/skill-orchestrate/SKILL.md` to support `pr_ready` state handling, dispatch status processing, and `pr_description` artifact linking in both single-task and multi-task sections.

**Tasks**:
- [ ] **Insertion 1 (Stage 4 state handler)**: Insert a new `#### State: pr_ready` section between the `completed` handler (ends at line 320) and the `abandoned/expanded` handler (starts at line 322). The new section should read:

```
#### State: `pr_ready`

\```
echo "[orchestrate] Task $task_number is [PR READY]. Run /pr $task_number to create the branch and submit the pull request."
# Clean up loop guard — pr_ready is a terminal state for orchestrate
rm -f "$loop_guard_file"
EXIT (success)
\```
```

Insert after line 321 (blank line after the `completed` block's closing triple-backtick) and before line 322 (`#### States: abandoned, expanded`).

- [ ] **Insertion 2 (Stage 5 dispatch_status case)**: Add a `pr_ready)` arm to the `case "$dispatch_status"` statement at line 372. Insert after the `implemented)` arm (line 380) and before the `*)` arm (line 382):

```bash
    pr_ready)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
```

- [ ] **Insertion 3 (Stage 5 artifact type case)**: Add a `pr_description)` arm to the `case "$handoff_artifact_type"` statement at line 392. Insert after the `summary)` arm (line 403) and before the `*)` arm (line 405):

```bash
      pr_description)
        field_name='**PR Description**'
        next_field='**Description**'
        ;;
```

- [ ] **Insertion 4 (MT-3 terminal state filter)**: Expand the terminal state case pattern at line 831 from `completed|abandoned|expanded)` to `completed|abandoned|expanded|pr_ready)`.

- [ ] **Insertion 5 (MT-4 dispatch_status case)**: Add a `pr_ready)` arm to the multi-task `case "$dispatch_status"` statement at line 997. Insert after the `implemented)` arm (line 1008) and before the `*)` arm (line 1010):

```bash
    pr_ready)
      operation="implement"
      skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"
      ;;
```

- [ ] **Insertion 6 (MT-4 artifact type case)**: Add a `pr_description)` arm to the multi-task `case "$handoff_artifact_type"` statement at line 1021. Insert after the `summary)` arm (line 1032) and before the `*)` arm (line 1034):

```bash
      pr_description)
        field_name='**PR Description**'
        next_field='**Description**'
        ;;
```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` -- 6 additive insertions (no existing lines modified)

**Verification**:
- grep for `pr_ready` in SKILL.md returns matches at all 4 expected locations (Stage 4, Stage 5 dispatch, MT-3, MT-4 dispatch)
- grep for `pr_description` in SKILL.md returns matches at 2 expected locations (Stage 5 artifact, MT-4 artifact)
- grep for `PR Description` in SKILL.md returns matches at 2 expected locations
- No existing case arms or sections are altered (diff shows only additions)

## Testing & Validation

- [ ] `grep -c 'pr_ready' .claude/skills/skill-orchestrate/SKILL.md` returns 4+ matches
- [ ] `grep -c 'pr_description' .claude/skills/skill-orchestrate/SKILL.md` returns 2 matches
- [ ] `grep -c 'PR Description' .claude/skills/skill-orchestrate/SKILL.md` returns 2 matches
- [ ] Visual review confirms all 6 insertions follow the formatting patterns of their surrounding code
- [ ] No existing lines are modified (only net additions in diff)

## Artifacts & Outputs

- `specs/709_add_pr_ready_orchestrate_support/plans/01_pr-ready-orchestrate-plan.md` (this plan)
- `specs/709_add_pr_ready_orchestrate_support/summaries/01_pr-ready-orchestrate-summary.md` (after implementation)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified file)

## Rollback/Contingency

Revert the 6 insertions by removing the added lines. Since all changes are additive and no existing code is modified, reverting is a simple deletion of the inserted blocks. `git checkout -- .claude/skills/skill-orchestrate/SKILL.md` restores the original file.
