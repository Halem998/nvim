# Implementation Plan: Post-validation cleanup

- **Task**: 652 - Post-validation cleanup: remove obsolete scripts after logging review
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 649 (completed), 651 (completed), 653 (completed)
- **Research Inputs**: specs/652_post_validation_cleanup/reports/01_post-validation-cleanup.md
- **Artifacts**: plans/01_post-validation-cleanup.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove obsolete scripts and dead code from the agent system after the generate-todo.sh pipeline has been validated over 5+ days and 1,124 successful runs. The cleanup has three sequential phases: (1) update reconcile-task-status.sh to stop calling link-artifact-todo.sh, (2) remove old sed/awk code from update-task-status.sh and add a generate-todo.sh call to make the CLAUDE.md claim true, (3) delete the now-unreferenced scripts and update documentation. Each phase unlocks the next.

### Research Integration

The research report (01_post-validation-cleanup.md) confirmed:
- generate-todo.sh pipeline is healthy: 1,124 runs, zero errors
- update-task-status.sh still has old awk/sed Phase 2+3 code (reverted from task 649)
- link-artifact-todo.sh is still called by reconcile-task-status.sh (one remaining caller)
- postflight-*.sh scripts have zero callers (orphaned)
- skill-base.sh has no dead functions
- CLAUDE.md claim that "update-task-status.sh calls generate-todo.sh internally" is currently false

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove all dead scripts: link-artifact-todo.sh, postflight-{research,plan,implement,workflow}.sh
- Remove redundant awk/sed code from update-task-status.sh (Phases 2+3)
- Add generate-todo.sh call to update-task-status.sh so the CLAUDE.md claim becomes true
- Update reconcile-task-status.sh to use generate-todo.sh instead of link-artifact-todo.sh
- Clean up documentation references and extension manifest entries

**Non-Goals**:
- Refactoring update-task-status.sh beyond removing dead code
- Adding new features to generate-todo.sh
- Modifying skill-base.sh (no dead code found)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing sed code from update-task-status.sh breaks edge case | M | L | generate-todo.sh regenerates entire file from state.json; sed was redundant for 5+ days |
| reconcile-task-status.sh link_artifact() behavior changes with generate-todo.sh | M | L | generate-todo.sh is more robust (full regeneration vs. line surgery); behavior is equivalent |
| Extension mirror copies get out of sync | L | M | Update both .claude/scripts/ and .claude/extensions/core/scripts/ in same phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases are fully sequential: Phase 1 removes the last caller of link-artifact-todo.sh, Phase 2 cleans update-task-status.sh and makes the CLAUDE.md claim true, Phase 3 deletes scripts and updates docs.

### Phase 1: Update reconcile-task-status.sh [COMPLETED]

**Goal**: Replace the link-artifact-todo.sh call in reconcile-task-status.sh with generate-todo.sh, eliminating the last caller of the deprecated script.

**Tasks**:
- [ ] In `reconcile-task-status.sh`, replace the `link_artifact()` function's TODO.md linking section (lines 144-164) with a `generate-todo.sh` call instead of calling `link-artifact-todo.sh`
- [ ] Remove the `DEPRECATION_LOG` variable (line 34) since it was only used for the deprecated call
- [ ] Remove the `field_name`/`next_field` case mapping (lines 145-151) since generate-todo.sh does not need field parameters
- [ ] Replace the dry-run and live branches (lines 153-164) with a single `generate-todo.sh` call (or dry-run echo)
- [ ] Apply identical changes to the mirror copy at `.claude/extensions/core/scripts/reconcile-task-status.sh`
- [ ] Verify: `grep -r "link-artifact-todo" .claude/scripts/reconcile-task-status.sh` returns no results

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/reconcile-task-status.sh` - Replace link-artifact-todo.sh call with generate-todo.sh
- `.claude/extensions/core/scripts/reconcile-task-status.sh` - Mirror copy, same changes

**Verification**:
- `grep -r "link-artifact-todo" .claude/scripts/reconcile-task-status.sh` returns empty
- `bash .claude/scripts/reconcile-task-status.sh 999 test_session --dry-run` runs without error (task 999 should no-op gracefully)
- Mirror copy matches primary

---

### Phase 2: Clean update-task-status.sh and add generate-todo.sh call [COMPLETED]

**Goal**: Remove the redundant awk/sed TODO.md manipulation (Phases 2+3) from update-task-status.sh and add a generate-todo.sh call, making the CLAUDE.md claim "update-task-status.sh calls generate-todo.sh internally" true.

**Tasks**:
- [ ] Remove the `update_todo_task_entry()` function (lines 187-235)
- [ ] Remove the `update_todo_task_order()` function (lines 239-273)
- [ ] Remove the `todo_failed` variable and its usage (lines 320-337)
- [ ] Remove the `TODO_FILE` variable (line 31) since it is no longer needed
- [ ] Remove exit code 3 from the script header comment (line 23) since TODO.md failures are no longer possible
- [ ] Add a `generate-todo.sh` call after the state.json update (after Phase 1) and before the plan file update (Phase 4), replacing the removed Phases 2+3
- [ ] For dry-run mode, echo the generate-todo.sh call instead of executing it
- [ ] Keep the `TMP_DIR` variable (still used for state.json.tmp)
- [ ] Apply identical changes to `.claude/extensions/core/scripts/update-task-status.sh`
- [ ] Verify the CLAUDE.md claim is now accurate (script calls generate-todo.sh internally)

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Remove Phases 2+3, add generate-todo.sh call
- `.claude/extensions/core/scripts/update-task-status.sh` - Mirror copy, same changes

**Verification**:
- `grep -n "update_todo_task_entry\|update_todo_task_order\|todo_failed" .claude/scripts/update-task-status.sh` returns empty
- `grep -n "generate-todo.sh" .claude/scripts/update-task-status.sh` returns a match
- `bash .claude/scripts/update-task-status.sh preflight 999 research test_session --dry-run` works (task 999 should error gracefully since it does not exist, but validates argument parsing)
- Mirror copy matches primary

---

### Phase 3: Delete obsolete scripts and update documentation [COMPLETED]

**Goal**: Delete link-artifact-todo.sh and postflight-*.sh scripts (now confirmed to have zero callers), and update all documentation references.

**Tasks**:
- [ ] Delete `.claude/scripts/link-artifact-todo.sh`
- [ ] Delete `.claude/extensions/core/scripts/link-artifact-todo.sh`
- [ ] Delete `.claude/scripts/postflight-research.sh`
- [ ] Delete `.claude/scripts/postflight-plan.sh`
- [ ] Delete `.claude/scripts/postflight-implement.sh`
- [ ] Delete `.claude/scripts/postflight-workflow.sh`
- [ ] Delete `.claude/extensions/core/scripts/postflight-research.sh`
- [ ] Delete `.claude/extensions/core/scripts/postflight-plan.sh`
- [ ] Delete `.claude/extensions/core/scripts/postflight-implement.sh`
- [ ] Delete `.claude/extensions/core/scripts/postflight-workflow.sh`
- [ ] Remove `link-artifact-todo.sh` entry from `.claude/extensions.json` (line 312)
- [ ] Remove `postflight-implement.sh`, `postflight-plan.sh`, `postflight-research.sh`, `postflight-workflow.sh` entries from `.claude/extensions.json` (lines 320-323)
- [ ] Update `.claude/extensions/core/manifest.json` to remove the same script entries
- [ ] Update `.claude/context/patterns/artifact-linking-todo.md`: revise the deprecation notice to indicate the script has been removed (keep the reference documentation about the four-case logic since it explains historical design)
- [ ] Update `.claude/context/patterns/jq-escaping-workarounds.md`: remove or replace the postflight-*.sh examples (lines 248-254) with current script examples
- [ ] Update `.claude/docs/architecture/architecture-spec.md`: remove references to postflight-workflow.sh and link-artifact-todo.sh (lines 150, 202, 510, 548)
- [ ] Verify: `grep -r "link-artifact-todo\|postflight-research\|postflight-plan\|postflight-implement\|postflight-workflow" .claude/scripts/ .claude/extensions/core/scripts/` returns no results (excluding comments in retained scripts)

**Timing**: 45 minutes

**Depends on**: 2

**Files to delete**:
- `.claude/scripts/link-artifact-todo.sh`
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/postflight-plan.sh`
- `.claude/scripts/postflight-implement.sh`
- `.claude/scripts/postflight-workflow.sh`
- `.claude/extensions/core/scripts/link-artifact-todo.sh`
- `.claude/extensions/core/scripts/postflight-research.sh`
- `.claude/extensions/core/scripts/postflight-plan.sh`
- `.claude/extensions/core/scripts/postflight-implement.sh`
- `.claude/extensions/core/scripts/postflight-workflow.sh`

**Files to modify**:
- `.claude/extensions.json` - Remove script entries
- `.claude/extensions/core/manifest.json` - Remove script entries
- `.claude/context/patterns/artifact-linking-todo.md` - Update deprecation notice
- `.claude/context/patterns/jq-escaping-workarounds.md` - Replace postflight examples
- `.claude/docs/architecture/architecture-spec.md` - Remove script references

**Verification**:
- `ls .claude/scripts/link-artifact-todo.sh .claude/scripts/postflight-*.sh 2>/dev/null` returns empty
- `ls .claude/extensions/core/scripts/link-artifact-todo.sh .claude/extensions/core/scripts/postflight-*.sh 2>/dev/null` returns empty
- `grep -r "link-artifact-todo" .claude/extensions.json` returns empty
- `grep -r "postflight-research\|postflight-plan\|postflight-implement\|postflight-workflow" .claude/extensions.json` returns empty
- `jq empty .claude/extensions.json` validates JSON is still valid

## Testing & Validation

- [ ] Run `bash .claude/scripts/update-task-status.sh preflight 652 plan sess_test --dry-run` to verify the updated script works with dry-run
- [ ] Run `bash .claude/scripts/reconcile-task-status.sh 652 sess_test --dry-run` to verify the updated reconcile script works
- [ ] Verify `grep -rn "generate-todo.sh" .claude/scripts/update-task-status.sh` shows the new call
- [ ] Verify no orphaned references: `grep -r "link-artifact-todo\|postflight-research\|postflight-plan\|postflight-implement\|postflight-workflow" .claude/scripts/ .claude/extensions/core/scripts/ .claude/extensions.json` returns only historical documentation references (if any)
- [ ] Verify state.json and TODO.md remain in sync after changes

## Artifacts & Outputs

- `specs/652_post_validation_cleanup/plans/01_post-validation-cleanup.md` (this file)
- `specs/652_post_validation_cleanup/summaries/01_post-validation-cleanup-summary.md` (after implementation)

## Rollback/Contingency

All deleted scripts exist in git history and can be restored with `git checkout HEAD~1 -- .claude/scripts/<script>`. The update-task-status.sh and reconcile-task-status.sh changes are additive removals (removing dead code, adding a generate-todo.sh call) and can be reverted with `git revert`. If generate-todo.sh is found to have issues, the old sed code can be restored from git history, though this is unlikely given 5+ days and 1,124 successful runs.
