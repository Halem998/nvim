# Implementation Plan: PR Ready Status Lifecycle

- **Task**: 671 - pr_ready_status_lifecycle
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/671_pr_ready_status_lifecycle/reports/01_pr-ready-status.md
- **Artifacts**: plans/01_pr-ready-status-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `[PR READY]` as a new non-terminal status in the agent system's task lifecycle, gating between `[IMPLEMENTING]` and the `/merge` PR submission step. The implementation modifies 14 files across live copies and extension sources: state-management rules, shell scripts (`generate-todo.sh`, `generate-task-order.sh`, `update-task-status.sh`), the CLAUDE.md merge-source, schema reference documents, and orchestrate skill state machines. All changes follow the established sync convention (live copy + extension source kept identical).

### Research Integration

The research report (01_pr-ready-status.md) provides a complete file inventory with line-level references, proposed diffs, and edge case analysis. Key findings integrated:

- `pr_ready` is the canonical state.json value; `PR READY` is the TODO.md display marker.
- The `format_status()` catch-all in both `generate-todo.sh` and `generate-task-order.sh` would render `PR_READY` (with underscore) without explicit case entries.
- `update-task-status.sh` uses a 3-value enum for `target_status` that must be extended to 4 values.
- The orchestrate skills must handle `pr_ready` as a clean exit (human action required), not dispatch to implement.
- `skill-status-sync` needs table updates for manual status corrections.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `pr_ready` as a recognized state.json status value across all infrastructure files
- Ensure `[PR READY]` renders correctly in TODO.md and task order output
- Define clean transitions: `[IMPLEMENTING] -> [PR READY]`, `[PR READY] -> [COMPLETED]`, `[PR READY] -> [IMPLEMENTING]`
- Keep orchestrate skills functional when encountering `pr_ready` (clean exit, not error)

**Non-Goals**:
- Automatic routing of PR tasks through `pr_ready` in the implementer skill (task 673 scope)
- `/pr` or `/merge` command integration with `pr_ready` transitions (task 674 scope)
- Creating a pr-lifecycle documentation guide (can follow later)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Live/extension copy drift after edits | M | L | Apply identical changes to both copies in the same phase; diff-verify at phase end |
| Orchestrate skill state machine regression | H | L | Add explicit `pr_ready` case rather than relying on catch-all; test with `bash -n` syntax check |
| `format_status()` catch-all masking the omission | L | M | Explicit case entry before wildcard; verify rendering with test task |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Status definition and transition rules [COMPLETED]

**Goal**: Establish `[PR READY]` / `pr_ready` as a recognized status in the authoritative rules and reference files.

**Tasks**:
- [x] Edit `.claude/rules/state-management.md`: add three transition lines after the `[IMPLEMENTING] -> [PARTIAL]` line:
  - `[IMPLEMENTING] -> [PR READY] (implementation complete, awaiting PR submission)`
  - `[PR READY] -> [IMPLEMENTING] (if issues found during PR review)`
  - `[PR READY] -> [COMPLETED] (after /merge PR submission)` *(completed)*
- [x] Apply identical edit to `.claude/extensions/core/rules/state-management.md` *(completed)*
- [x] Edit `.claude/context/reference/state-management-schema.md`: add `| [PR READY] | pr_ready |` row after the `[IMPLEMENTING]` row in the Status Values Mapping table *(completed)*
- [x] Apply identical row addition to `.claude/extensions/core/context/reference/state-management-schema.md` *(completed)*
- [x] Edit `.claude/extensions/core/merge-sources/claudemd.md` Status Markers section: change `[IMPLEMENTING] -> [COMPLETED]` line to `[IMPLEMENTING] -> [PR READY] -> [COMPLETED]` and add `[PR READY] -> [IMPLEMENTING]` re-dispatch line *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/rules/state-management.md` - Add PR READY transition rules (lines 28-36 area)
- `.claude/extensions/core/rules/state-management.md` - Identical change
- `.claude/context/reference/state-management-schema.md` - Add PR READY row (line 276 area)
- `.claude/extensions/core/context/reference/state-management-schema.md` - Identical change
- `.claude/extensions/core/merge-sources/claudemd.md` - Update Status Markers (lines 32-37)

**Verification**:
- `diff` live vs extension copies of state-management.md confirms identical content
- `grep "PR READY" .claude/rules/state-management.md` returns the three new transition lines
- `grep "pr_ready" .claude/context/reference/state-management-schema.md` returns the new table row
- `grep "PR READY" .claude/extensions/core/merge-sources/claudemd.md` returns updated Status Markers

---

### Phase 2: Shell script format_status() updates [COMPLETED]

**Goal**: Ensure `pr_ready` renders as `PR READY` (with space, not underscore) in all generated output.

**Tasks**:
- [x] Edit `.claude/scripts/generate-todo.sh`: add `pr_ready) printf '%s' "PR READY" ;;` case before the wildcard `*)` case in `format_status()` (around line 128) *(completed)*
- [x] Apply identical edit to `.claude/extensions/core/scripts/generate-todo.sh` *(completed)*
- [x] Edit `.claude/scripts/generate-task-order.sh`: add `pr_ready) echo "PR READY" ;;` case before the wildcard `*)` case in `format_status()` (around line 619) *(completed)*
- [x] Apply identical edit to `.claude/extensions/core/scripts/generate-task-order.sh` *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - Add pr_ready case to format_status() (line 128)
- `.claude/extensions/core/scripts/generate-todo.sh` - Identical change
- `.claude/scripts/generate-task-order.sh` - Add pr_ready case to format_status() (line 619)
- `.claude/extensions/core/scripts/generate-task-order.sh` - Identical change

**Verification**:
- `bash -n .claude/scripts/generate-todo.sh` exits 0 (no syntax errors)
- `bash -n .claude/scripts/generate-task-order.sh` exits 0
- `diff .claude/scripts/generate-todo.sh .claude/extensions/core/scripts/generate-todo.sh` shows no diff
- `diff .claude/scripts/generate-task-order.sh .claude/extensions/core/scripts/generate-task-order.sh` shows no diff
- `grep "pr_ready" .claude/scripts/generate-todo.sh` returns the new case line

---

### Phase 3: update-task-status.sh validation and mapping [COMPLETED]

**Goal**: Allow `pr_ready` as a valid `target_status` value and define its preflight/postflight state mappings.

**Tasks**:
- [x] Edit `.claude/scripts/update-task-status.sh` validation block (line 69): add `&& "$target_status" != "pr_ready"` to the condition and update the error message to include `'pr_ready'` *(completed)*
- [x] Edit `.claude/scripts/update-task-status.sh` `map_status()` function (line 89-100): add two cases before the wildcard:
  - `preflight:pr_ready) STATE_STATUS="pr_ready"; TODO_STATUS="PR READY" ;;`
  - `postflight:pr_ready) STATE_STATUS="completed"; TODO_STATUS="COMPLETED" ;;` *(completed)*
- [x] Apply identical validation and map_status changes to `.claude/extensions/core/scripts/update-task-status.sh` *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Extend validation (line 69) and map_status() (lines 89-100)
- `.claude/extensions/core/scripts/update-task-status.sh` - Identical changes

**Verification**:
- `bash -n .claude/scripts/update-task-status.sh` exits 0
- `diff .claude/scripts/update-task-status.sh .claude/extensions/core/scripts/update-task-status.sh` shows no diff
- `grep "pr_ready" .claude/scripts/update-task-status.sh` returns both the validation and two map_status entries

---

### Phase 4: Orchestrate and status-sync skill updates [COMPLETED]

**Goal**: Ensure the orchestrate state machines and status-sync skill handle `pr_ready` correctly.

**Tasks**:
- [x] Edit `.claude/skills/skill-orchestrate/SKILL.md`: add a `pr_ready)` case to the main status dispatch `case "$status" in` block that exits cleanly with a message prompting the user to run `/merge` *(completed)*
- [x] Edit `.claude/skills/skill-orchestrate-hard/SKILL.md`: add an equivalent `pr_ready)` case in the hard-mode state machine *(completed)*
- [x] Edit `.claude/skills/skill-status-sync/SKILL.md`: add `pr_ready` / `PR READY` entries to both the preflight and postflight Status Mapping tables *(completed)*

**Timing**: 25 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add pr_ready exit case to state machine
- `.claude/skills/skill-orchestrate-hard/SKILL.md` - Add pr_ready exit case
- `.claude/skills/skill-status-sync/SKILL.md` - Add pr_ready to Status Mapping tables

**Verification**:
- `grep -c "pr_ready" .claude/skills/skill-orchestrate/SKILL.md` returns at least 1
- `grep -c "pr_ready" .claude/skills/skill-orchestrate-hard/SKILL.md` returns at least 1
- `grep -c "pr_ready" .claude/skills/skill-status-sync/SKILL.md` returns at least 1
- Manually verify the orchestrate case exits cleanly (not dispatching to implement)
- Run `bash .claude/scripts/generate-todo.sh` to confirm no rendering regressions in TODO.md

## Testing & Validation

- [ ] `bash -n` syntax check passes on all three modified shell scripts (generate-todo.sh, generate-task-order.sh, update-task-status.sh)
- [ ] `diff` confirms each live/extension script pair is identical after changes
- [ ] Temporarily set a test task to `pr_ready` in state.json; run `bash .claude/scripts/generate-todo.sh` and confirm `[PR READY]` appears correctly in TODO.md (then revert the test task)
- [ ] `grep -rn "pr_ready\|PR READY" .claude/` confirms all 14 files contain the new status references
- [ ] Verify `bash .claude/scripts/update-task-status.sh preflight pr_ready <test_task> <session>` sets status to `pr_ready` (then revert)

## Artifacts & Outputs

- `specs/671_pr_ready_status_lifecycle/plans/01_pr-ready-status-plan.md` (this plan)
- Modified files (14 total): 5 rules/reference docs, 6 shell scripts (3 pairs), 2 orchestrate skills, 1 status-sync skill

## Rollback/Contingency

All changes are additive (new case branches, new table rows, new transition lines). Rollback consists of reverting the commit via `git revert`. No existing behavior is modified -- only new `pr_ready` paths are added alongside existing status handling. If a syntax error is introduced in a shell script, `bash -n` will catch it before committing.
