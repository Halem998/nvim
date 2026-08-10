# Implementation Summary: Task #593

- **Task**: 593 - Extract shared workflow utilities
- **Status**: [COMPLETED]
- **Started**: 2026-05-22T00:00:00Z
- **Completed**: 2026-05-22T01:00:00Z
- **Effort**: 7 hours (estimated), ~1 session (actual)
- **Dependencies**: 592 (design, satisfied)
- **Artifacts**:
  - `.claude/scripts/parse-command-args.sh` (new)
  - `.claude/scripts/command-gate-in.sh` (new)
  - `.claude/scripts/command-gate-out.sh` (new)
  - `.claude/scripts/postflight-workflow.sh` (new)
  - `.claude/commands/research.md` (modified)
  - `.claude/commands/plan.md` (modified)
  - `.claude/commands/implement.md` (modified)
  - `.claude/scripts/postflight-research.sh` (modified to thin wrapper)
  - `.claude/scripts/postflight-plan.sh` (modified to thin wrapper)
  - `.claude/scripts/postflight-implement.sh` (modified to thin wrapper)
- **Standards**: status-markers.md, artifact-management.md, tasks.md

## Overview

Extracted shared command logic from the 3 Claude Code workflow command files (`research.md`, `plan.md`, `implement.md`) into 4 reusable shell scripts in `.claude/scripts/`. This eliminates 305 lines of duplicated logic across commands and establishes Component 1 of the unified workflow architecture described in `architecture-spec.md`. The 3 existing postflight scripts (69 lines each) were converted to 12-line thin wrappers calling the unified `postflight-workflow.sh`.

## What Changed

- `.claude/scripts/parse-command-args.sh` — Created: superset argument parser (90 lines). Parses task numbers (including ranges), and exports TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE, EFFORT_FLAG, MODEL_FLAG, CLEAN_FLAG, FORCE_FLAG, FOCUS_PROMPT. Must be sourced (not called as subprocess).
- `.claude/scripts/command-gate-in.sh` — Created: CHECKPOINT 1 gate script (60 lines). Generates SESSION_ID, looks up task in state.json, exports TASK_TYPE/TASK_STATUS/PROJECT_NAME/DESCRIPTION/PADDED_NUM, guards against terminal statuses. Must be sourced.
- `.claude/scripts/command-gate-out.sh` — Created: CHECKPOINT 2 gate script (70 lines). Reads `.return-meta.json`, applies defensive status correction, runs validate-artifact.sh. Called as subprocess.
- `.claude/scripts/postflight-workflow.sh` — Created: unified postflight (105 lines). Parameterizes the 3 formerly near-identical postflight scripts via OPERATION_TYPE parameter. Uses safe jq `select(.type == $atype | not)` pattern per Issue #1132.
- `.claude/commands/research.md` — Modified: 500→393 lines (-107, 21% reduction). Replaced inline `parse_task_args()`, STAGE 1.5 flag parsing, and GATE IN/OUT blocks with source/bash calls to new scripts.
- `.claude/commands/plan.md` — Modified: 531→420 lines (-111, 20% reduction). Same replacement pattern. Added `--roadmap` flag handling inline (plan-specific).
- `.claude/commands/implement.md` — Modified: 612→525 lines (-87, 14% reduction). Same replacement pattern. Retained `--force` override and implement-specific GATE OUT steps inline.
- `.claude/scripts/postflight-research.sh` — Modified: 69→12 lines. Thin wrapper using `exec` to delegate to `postflight-workflow.sh "$@" "research"`.
- `.claude/scripts/postflight-plan.sh` — Modified: 69→12 lines. Thin wrapper delegating to `postflight-workflow.sh "$@" "plan"`.
- `.claude/scripts/postflight-implement.sh` — Modified: 69→12 lines. Thin wrapper delegating to `postflight-workflow.sh "$@" "implement"`.

## Decisions

- **Source vs subprocess**: `parse-command-args.sh` and `command-gate-in.sh` use `source` because they must export shell variables into the calling context. `command-gate-out.sh` and `postflight-workflow.sh` use subprocess (`bash`/`exec`) since they only produce side effects. Documented with explicit header comments in each script.
- **Superset flag parsing**: `parse-command-args.sh` parses ALL flags unconditionally; each command applies its own post-clamp (e.g., `TEAM_SIZE` max 3 for plan, max 4 for research/implement). This avoids per-command divergence in the parser.
- **Narrow GATE OUT scope**: `command-gate-out.sh` contains only the shared defensive status correction (~25 lines). Implement-specific steps (completion_summary, plan file verification) remain inline in `implement.md`. Plan-specific plan file checks remain inline in `plan.md`.
- **Safe jq pattern**: `postflight-workflow.sh` uses `select(.type == $atype | not)` instead of `select(.type != $atype)` to avoid Claude Code Issue #1132 jq escaping bug.
- **Backward-compatible wrappers**: Old postflight scripts preserved as thin wrappers using `exec` (not deletion). This maintains backward compatibility for any callers until task 599 removes them.
- **bash regex fix**: Initial `grep -oE '^[0-9][0-9, -]*'` was too greedy (captured `--` from flags). Fixed using bash `BASH_REMATCH` approach to capture leading task spec.
- **GATE IN uses `return` not `exit`**: Since `command-gate-in.sh` is sourced, errors use `return 1` to avoid killing the parent shell.

## Plan Deviations

- **Line count target**: The plan targeted 250-280 lines per command file after extraction. Actual results are 393/420/525. This is explained by the plan's own non-goal: "multi-task dispatch logic (reserved for task 595)" — these blocks are ~115 lines each that remain inline. The plan later acknowledges "150-200 line target is achievable only after task 595." The 20-21% reduction achieved is accurate for what task 593 was scoped to extract.

## Impacts

- All 3 core command files (`/research`, `/plan`, `/implement`) now delegate argument parsing and gate logic to shared scripts, eliminating ~305 lines of duplicated code.
- The 3 postflight scripts are now thin wrappers (12 lines each vs 69 previously), with all logic centralized in `postflight-workflow.sh`.
- Task 594 (`skill-base.sh`) can now build on these 4 shared scripts as its foundation.
- Task 595 (multi-task dispatch extraction) has clear targets — the remaining ~115-line dispatch blocks in each command.

## Follow-ups

- Task 594: Create `skill-base.sh` that sources `parse-command-args.sh` and `command-gate-in.sh` — these scripts are designed for this use case.
- Task 595: Extract multi-task dispatch blocks to reduce command files further toward the 150-200 line target.
- Task 599: Delete the now-thin postflight wrapper scripts once all callers are confirmed to use `postflight-workflow.sh` directly.

## References

- Plan: `specs/593_extract_shared_workflow_utilities/plans/02_extract-shared-utilities.md`
- Design guidance: `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md`
- Architecture spec: `.claude/docs/architecture/architecture-spec.md`
- jq safe patterns: `.claude/context/patterns/jq-escaping-workarounds.md`
