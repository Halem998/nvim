# Implementation Plan: Task #649

- **Task**: 649 - Simplify state update pipeline to state.json-only with TODO.md regeneration
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 648 (generate-todo.sh — completed), Task 650 (update-phase-status.sh — completed)
- **Research Inputs**: specs/649_simplify_state_update_pipeline/reports/01_pipeline-simplification-research.md
- **Artifacts**: plans/01_pipeline-simplification.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor the task status update pipeline from a dual-write model (state.json + direct TODO.md awk/sed surgery) to a state.json-first model where TODO.md is regenerated from state.json via generate-todo.sh. The main targets are update-task-status.sh (remove Phases 2 and 3), skill-base.sh (replace link-artifact-todo.sh with generate-todo.sh), postflight-workflow.sh (add generate-todo.sh call), and all direct callers of link-artifact-todo.sh. Old code paths are preserved as logged fallbacks during transition so task 652 can verify they are unused before removal.

### Research Integration

Key findings from the research report:
- update-task-status.sh has 5 clearly labeled phases; Phases 2 (TODO.md task entry awk/sed) and 3 (TODO.md Task Order awk/sed) are the removal targets; Phases 1, 4, and 5 are kept as-is
- postflight-workflow.sh is already state.json-only; it only needs a generate-todo.sh call appended
- skill_link_artifacts() in skill-base.sh performs two operations: state.json artifact update (keep) and link-artifact-todo.sh call (replace)
- 8 total callers of link-artifact-todo.sh identified across 6 files (skill-base.sh, skill-orchestrate x2, skill-reviser x1, reconcile-task-status.sh x2, skill-project-overview x1, skill-team-research x1)
- Exit code 3 (TODO.md failure) in update-task-status.sh has zero callers and can be removed
- PIPELINE_MODE environment variable approach enables safe rollback during transition

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Make state.json the single write target for all status and artifact updates
- Replace all TODO.md awk/sed text surgery with generate-todo.sh regeneration calls
- Add deprecation logging to old code paths so task 652 can verify zero usage
- Keep old code paths as logged fallbacks via PIPELINE_MODE during transition
- Update all callers of link-artifact-todo.sh to use generate-todo.sh instead

**Non-Goals**:
- Full removal of deprecated code (that is task 652's scope)
- Updating reconcile-task-status.sh beyond adding deprecation logging (recovery tool needs separate analysis)
- Performance optimization of generate-todo.sh (acceptable tradeoff per research)
- Changing the state.json schema (already v1.1.0 via task 647)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| generate-todo.sh is slower than in-place awk (~1s vs microseconds) | L | H | Acceptable tradeoff; current TODO.md has ~17 tasks; generate-todo.sh already logs elapsed time |
| Concurrent write collision on TODO.md (multiple agents calling generate-todo.sh) | L | M | Last-write-wins is acceptable because both agents read from the same updated state.json; content is identical |
| Missed callers of link-artifact-todo.sh | M | L | Deprecation logging in link-artifact-todo.sh will surface any unidentified callers; comprehensive grep confirms 8 callers across 6 files |
| TODO.md becomes empty/corrupted if generate-todo.sh fails | H | L | generate-todo.sh uses atomic write (mktemp + mv); wrap calls in non-fatal error handler |
| PIPELINE_MODE=legacy fallback has bugs from bitrot | M | L | Legacy mode preserves exact existing code; only new code is the generate-todo.sh call path |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Refactor update-task-status.sh [COMPLETED]

**Goal**: Replace Phases 2 and 3 (TODO.md awk/sed surgery) with a single generate-todo.sh call, preserving old code as logged fallbacks behind PIPELINE_MODE.

**Tasks**:
- [ ] Add PIPELINE_MODE variable and deprecation logging helper function at the top of the script
  - `PIPELINE_MODE="${PIPELINE_MODE:-new}"`
  - `log_deprecation()` function that appends to `.claude/logs/deprecation.log`
- [ ] Wrap `update_todo_task_entry()` function body (Phase 2, lines 200-267) in `PIPELINE_MODE=legacy` guard with deprecation logging
- [ ] Wrap `update_todo_task_order()` function body (Phase 3, lines 272-368) in `PIPELINE_MODE=legacy` guard with deprecation logging
- [ ] Add new function `regenerate_todo()` that calls `.claude/scripts/generate-todo.sh` with non-fatal error handling
- [ ] Replace the execution block (lines 411-451) with new flow:
  - Call `update_todo_task_entry` only when PIPELINE_MODE=legacy (with deprecation log)
  - Call `update_todo_task_order` only when PIPELINE_MODE=legacy (with deprecation log)
  - Always call `regenerate_todo()` (the new path)
- [ ] Remove `todo_failed` variable and exit code 3 logic (zero callers depend on it)
- [ ] Ensure Phase 4 (plan file update) and Phase 5 (notifications) remain unchanged
- [ ] Ensure the `mkdir -p .claude/logs` exists before writing deprecation log

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Main refactor: wrap Phases 2+3 in legacy guard, add generate-todo.sh call, add deprecation logging

**Verification**:
- `bash .claude/scripts/update-task-status.sh --dry-run preflight 649 research sess_test` succeeds without errors
- When PIPELINE_MODE=legacy, deprecation log entries appear in `.claude/logs/deprecation.log`
- When PIPELINE_MODE=new (default), Phases 2 and 3 are skipped and generate-todo.sh is called

---

### Phase 2: Update skill-base.sh [COMPLETED]

**Goal**: Replace link-artifact-todo.sh call in skill_link_artifacts() with generate-todo.sh call, keeping state.json artifact update unchanged.

**Tasks**:
- [ ] In `skill_link_artifacts()` (line 383-384): replace `bash .claude/scripts/link-artifact-todo.sh ...` call with `bash .claude/scripts/generate-todo.sh || echo "WARNING: generate-todo.sh failed (non-fatal)"`
- [ ] Verify `skill_link_artifact_from_handoff()` is automatically fixed (it calls `skill_link_artifacts()` internally)
- [ ] Verify `skill_preflight_update()` and `skill_postflight_update()` need no changes (they call update-task-status.sh which is already updated in Phase 1)

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Replace link-artifact-todo.sh call with generate-todo.sh in `skill_link_artifacts()`

**Verification**:
- `grep -n "link-artifact-todo" .claude/scripts/skill-base.sh` returns zero matches
- `grep -n "generate-todo" .claude/scripts/skill-base.sh` shows the new call

---

### Phase 3: Update postflight-workflow.sh [COMPLETED]

**Goal**: Add generate-todo.sh call after state.json artifact update so TODO.md reflects newly linked artifacts.

**Tasks**:
- [ ] Add `generate-todo.sh` call after Step 3 (artifact add, line 141) with non-fatal error handling: `bash "$(dirname "$0")/generate-todo.sh" || echo "WARNING: generate-todo.sh failed (non-fatal)" >&2`
- [ ] Verify no direct TODO.md manipulation exists in the script (confirmed by research: none)

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/postflight-workflow.sh` - Add generate-todo.sh call after Step 3

**Verification**:
- `grep -n "generate-todo" .claude/scripts/postflight-workflow.sh` shows the new call
- `bash .claude/scripts/postflight-workflow.sh` with a test task does not error

---

### Phase 4: Deprecate link-artifact-todo.sh and update all callers [COMPLETED]

**Goal**: Add deprecation logging to link-artifact-todo.sh itself and replace all direct callers with generate-todo.sh (state.json artifact updates happen upstream of each caller).

**Tasks**:
- [ ] Add deprecation header comment and logging at the top of `link-artifact-todo.sh`:
  - Log entry format: `[ISO8601] link-artifact-todo: DEPRECATED task=$task_number field=$field_name path=$artifact_path`
  - Keep the script fully functional (don't break any remaining callers)
  - Ensure `.claude/logs/` directory creation
- [ ] Update `skill-orchestrate/SKILL.md` lines 436-438: replace the 3-line link-artifact-todo.sh case block with `bash .claude/scripts/generate-todo.sh` (single call after the state.json artifact update which happens via `skill_link_artifact_from_handoff`)
- [ ] Update `skill-orchestrate/SKILL.md` lines 1077-1079: same replacement for the multi-task orchestration section
- [ ] Update `skill-reviser/SKILL.md` line 383: replace `bash .claude/scripts/link-artifact-todo.sh` call with `bash .claude/scripts/generate-todo.sh`
- [ ] Update `skill-team-research/SKILL.md` line 478: replace link-artifact-todo.sh call with generate-todo.sh
- [ ] Update `skill-project-overview/SKILL.md` lines 391-393: replace link-artifact-todo.sh call with generate-todo.sh
- [ ] Add deprecation logging to `reconcile-task-status.sh` lines 154-157 (keep functional, add log; defer full migration)
- [ ] Update documentation references:
  - `.claude/rules/artifact-formats.md` line 115: update PROHIBITION note to reference generate-todo.sh instead
  - `.claude/context/patterns/artifact-linking-todo.md`: add deprecation notice noting that link-artifact-todo.sh is deprecated in favor of generate-todo.sh

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/link-artifact-todo.sh` - Add deprecation logging at entry point
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace 2 link-artifact-todo.sh call blocks with generate-todo.sh
- `.claude/skills/skill-reviser/SKILL.md` - Replace 1 link-artifact-todo.sh call with generate-todo.sh
- `.claude/extensions/core/skills/skill-team-research/SKILL.md` - Replace 1 link-artifact-todo.sh call with generate-todo.sh
- `.claude/skills/skill-project-overview/SKILL.md` - Replace 1 link-artifact-todo.sh call with generate-todo.sh
- `.claude/scripts/reconcile-task-status.sh` - Add deprecation logging (keep functional)
- `.claude/rules/artifact-formats.md` - Update documentation reference
- `.claude/context/patterns/artifact-linking-todo.md` - Add deprecation notice

**Verification**:
- `grep -rn "link-artifact-todo" .claude/scripts/ .claude/skills/ .claude/extensions/core/skills/ | grep -v "DEPRECATED\|deprecated\|extensions.json\|settings.local"` returns only link-artifact-todo.sh itself and reconcile-task-status.sh
- Running link-artifact-todo.sh produces a deprecation log entry in `.claude/logs/deprecation.log`

---

### Phase 5: Integration validation [COMPLETED]

**Goal**: Verify the complete pipeline works end-to-end and deprecation logging captures any fallback usage.

**Tasks**:
- [ ] Run `bash .claude/scripts/generate-todo.sh --dry-run` and verify output matches current TODO.md structure
- [ ] Run a preflight/postflight cycle: `bash .claude/scripts/update-task-status.sh preflight 649 plan sess_test` followed by `bash .claude/scripts/update-task-status.sh postflight 649 plan sess_test` and verify TODO.md is regenerated correctly
- [ ] Verify `cat .claude/logs/deprecation.log` shows no DEPRECATED entries from the new pipeline mode (only from explicit fallback testing)
- [ ] Test PIPELINE_MODE=legacy fallback: `PIPELINE_MODE=legacy bash .claude/scripts/update-task-status.sh preflight 649 research sess_test_legacy` and verify deprecation entries appear
- [ ] Verify state.json task entry has correct status after the cycle
- [ ] Run `grep -rn "link-artifact-todo" .claude/` to produce a final audit of remaining references (expected: link-artifact-todo.sh itself, reconcile-task-status.sh, documentation files, extensions.json, settings.local.json)

**Timing**: 30 minutes

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- No files modified in this phase (validation only)

**Verification**:
- All validation tasks above pass
- TODO.md content matches expected structure from state.json
- Deprecation log is empty under normal operation (PIPELINE_MODE=new)
- Deprecation log captures entries under PIPELINE_MODE=legacy

---

## Testing & Validation

- [ ] update-task-status.sh --dry-run produces correct output for all operation/status combinations
- [ ] generate-todo.sh produces valid TODO.md from state.json
- [ ] Preflight + postflight cycle updates state.json and regenerates TODO.md correctly
- [ ] Deprecation logging works: link-artifact-todo.sh logs when called, Phase 2/3 legacy code logs when PIPELINE_MODE=legacy
- [ ] No regressions in skill-base.sh functions (skill_link_artifacts, skill_preflight_update, skill_postflight_update)
- [ ] All SKILL.md files compile without syntax errors in their bash blocks

## Artifacts & Outputs

- `.claude/scripts/update-task-status.sh` - Refactored with generate-todo.sh call replacing Phases 2+3
- `.claude/scripts/skill-base.sh` - Updated skill_link_artifacts with generate-todo.sh
- `.claude/scripts/postflight-workflow.sh` - Added generate-todo.sh call
- `.claude/scripts/link-artifact-todo.sh` - Deprecated with logging
- `.claude/logs/deprecation.log` - New file for transition-period logging
- 5 SKILL.md files updated to remove link-artifact-todo.sh calls
- 2 documentation files updated with deprecation notices

## Rollback/Contingency

Set `PIPELINE_MODE=legacy` environment variable to restore old awk/sed behavior in update-task-status.sh. The link-artifact-todo.sh script remains fully functional (just deprecated with logging). If generate-todo.sh has a critical bug, reverting to legacy mode restores the entire old pipeline while the bug is fixed. Task 652 performs final cleanup after confirming zero legacy usage.
