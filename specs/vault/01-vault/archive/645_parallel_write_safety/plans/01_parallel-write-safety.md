# Implementation Plan: Fix parallel write safety for state.json

- **Task**: 645 - Fix parallel write safety for state.json
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/645_parallel_write_safety/reports/01_parallel-write-safety.md
- **Artifacts**: plans/01_parallel-write-safety.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the shared `specs/tmp/state.json` temp path with per-write unique temp files via `mktemp`, and add `flock` mutex around the state.json read-jq-write critical section in `update-task-status.sh`. This prevents last-write-wins corruption when multiple agents write concurrently during multi-task orchestration. Three scripts require changes: `update-task-status.sh` (flock + mktemp), `postflight-workflow.sh` (mktemp), and `skill-base.sh` (mktemp + atomic Python writes).

### Research Integration

Key findings from research report (01_parallel-write-safety.md):
- 40+ call sites use the shared `specs/tmp/state.json` temp path
- The race occurs between parallel subagents in multi-task orchestration waves, each calling `update-task-status.sh`
- Three runtime scripts are the actual write paths: `update-task-status.sh`, `postflight-workflow.sh`, `skill-base.sh`
- SKILL.md inline jq patterns run sequentially in the orchestrator postflight loop and do not race with each other
- `flock` (util-linux 2.42) and `mktemp` (coreutils 9.11) are confirmed available on this NixOS system
- Python direct-write functions in `skill-base.sh` are worse than the shared tmp path because they truncate on open

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Eliminate last-write-wins race condition for state.json during parallel agent writes
- Replace all shared temp file paths in the three runtime write scripts with mktemp unique paths
- Add flock-based exclusive locking around the state.json write critical section in update-task-status.sh
- Fix Python direct-write functions in skill-base.sh to use atomic write-to-tmp-then-rename
- Fix TODO.md shared tmp path in update-task-status.sh

**Non-Goals**:
- Fixing inline jq patterns in SKILL.md files (they run sequentially, no race)
- Updating documentation examples in context/patterns/ (cosmetic, no runtime impact)
- Adding flock to postflight-workflow.sh (called sequentially by skills, does not race with itself)
- Adding flock around TODO.md writes (lower severity, tasks update different line ranges)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| flock not available on non-NixOS systems | M | L | System is NixOS-only; flock is util-linux standard on all Linux |
| Lock file left behind after crash | L | L | flock releases on process exit; stale lock file is harmless |
| flock timeout blocks agent for 30s | M | L | 30s timeout is generous; concurrent writes complete in <1s |
| Python writes bypass shell flock | H | M | Fix Python functions to use os.replace() atomicity directly |
| mktemp cleanup on error paths | M | M | Use trap to clean up temp files on EXIT |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Harden update-task-status.sh with flock and mktemp [COMPLETED]

**Goal**: Protect the primary state.json write chokepoint with exclusive locking and unique temp files. This is the highest-value change since all lifecycle status transitions flow through this script.

**Tasks**:
- [x] Add `LOCK_FILE="$PROJECT_ROOT/specs/.state.json.lock"` to the configuration section (after line 32) *(completed)*
- [x] Replace the `update_state_json()` function's jq write to use mktemp instead of `$TMP_DIR/state.json.tmp`:
  - Change `jq ... > "$TMP_DIR/state.json.tmp"` to `local tmp; tmp=$(mktemp "$TMP_DIR/state.XXXXXX.json")`
  - Change validation to use `$tmp` instead of `"$TMP_DIR/state.json.tmp"`
  - Change `mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"` to `mv "$tmp" "$STATE_FILE"` *(completed)*
- [x] Wrap the entire `update_state_json()` function body (the non-dry-run path) in a flock subshell:
  ```
  (
    flock -x -w 30 200 || { echo "Error: could not acquire state.json lock" >&2; return 1; }
    # ... existing jq read-transform-write with mktemp ...
  ) 200>"$LOCK_FILE"
  ``` *(completed)*
- [x] Update the cleanup trap to remove `$tmp` (use a variable or pattern glob for temp files):
  - Replace `rm -f "$TMP_DIR/state.json.tmp"` with `rm -f "$TMP_DIR"/state.??????.json` in the trap *(completed)*
- [x] Replace `$TMP_DIR/todo.md.tmp` in `update_todo_task_entry()` with mktemp:
  - Change `printf '%s\n' "$replaced" > "$TMP_DIR/todo.md.tmp"` to use `local tmp_todo; tmp_todo=$(mktemp "$TMP_DIR/todo.XXXXXX.md")`
  - Change `mv "$TMP_DIR/todo.md.tmp" "$TODO_FILE"` to `mv "$tmp_todo" "$TODO_FILE"` *(completed)*
- [x] Apply the same mktemp fix to `update_todo_task_order()` for its `$TMP_DIR/todo.md.tmp` usage *(completed)*
- [x] Update the cleanup trap to also handle todo temp file cleanup: replace `"$TMP_DIR/todo.md.tmp"` with `"$TMP_DIR"/todo.??????.md` *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add flock locking, replace all shared tmp paths with mktemp

**Verification**:
- Run `bash .claude/scripts/update-task-status.sh preflight 645 plan sess_test --dry-run` to verify script still parses and runs
- Verify lock file path `specs/.state.json.lock` is referenced correctly
- Verify no remaining references to `state.json.tmp` (literal shared path) in the script
- Verify no remaining references to `todo.md.tmp` (literal shared path) in the script
- Run `grep -n 'state\.json\.tmp\|todo\.md\.tmp' .claude/scripts/update-task-status.sh` to confirm zero matches

---

### Phase 2: Fix postflight-workflow.sh temp paths [COMPLETED]

**Goal**: Replace the three hardcoded `specs/tmp/state.json` temp file writes with mktemp unique paths to prevent collisions if this script is ever called concurrently.

**Tasks**:
- [x] Add a `TMP_DIR` variable near the top of the script (after `mkdir -p specs/tmp`) *(completed)*
- [x] Replace Step 1 temp write: change `> specs/tmp/state.json && mv specs/tmp/state.json` to use mktemp *(completed)*
- [x] Replace Step 2 temp write: same mktemp pattern for artifact filtering *(completed)*
- [x] Replace Step 3 temp write: same mktemp pattern for artifact addition *(completed)*
- [x] Add cleanup trap at the top of the script to remove any leftover temp files on error *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/postflight-workflow.sh` - Replace 3 hardcoded temp paths with mktemp

**Verification**:
- Run `grep -n 'specs/tmp/state\.json' .claude/scripts/postflight-workflow.sh` to confirm zero hardcoded matches
- Verify the script has valid bash syntax: `bash -n .claude/scripts/postflight-workflow.sh`

---

### Phase 3: Fix skill-base.sh shared temp paths and Python atomic writes [COMPLETED]

**Goal**: Replace the `specs/tmp/state.json` hardcoded temp path in `skill_link_artifacts()` with mktemp, and fix the two Python direct-write functions (`skill_increment_artifact_number`, `skill_propagate_memory_candidates`) to use atomic write-to-tmp-then-os.replace() pattern.

**Tasks**:
- [x] Fix `skill_link_artifacts()` Step 1: replace `> specs/tmp/state.json && mv specs/tmp/state.json specs/state.json` with mktemp *(completed)*
- [x] Fix `skill_link_artifacts()` Step 2: same mktemp pattern for artifact addition *(completed)*
- [x] Fix `skill_increment_artifact_number()` Python code: replace direct `open('specs/state.json', 'w')` with atomic tempfile.mkstemp() + os.replace() pattern *(completed)*
- [x] Fix `skill_propagate_memory_candidates()` Python code: same atomic pattern *(completed)*
- [x] Ensure `specs/tmp` directory creation guard exists in `skill_link_artifacts()` before mktemp calls *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Fix jq temp paths in skill_link_artifacts(), fix Python direct-write functions

**Verification**:
- Run `grep -n "specs/tmp/state\.json" .claude/scripts/skill-base.sh` to confirm zero hardcoded temp path matches
- Run `grep -n "open('specs/state.json', 'w')" .claude/scripts/skill-base.sh` to confirm zero direct-write matches
- Verify syntax: `bash -n .claude/scripts/skill-base.sh`
- Verify Python syntax in both functions by extracting and running `python3 -c "import ast; ast.parse('''..code..''')"` on each

---

### Phase 4: End-to-end verification and cleanup [COMPLETED]

**Goal**: Verify all scripts work correctly after modifications, confirm no remaining shared temp paths, and test the flock locking pattern.

**Tasks**:
- [x] Run comprehensive grep across all three scripts to confirm no remaining shared temp paths *(completed: zero matches)*
- [x] Run syntax check on all three scripts *(completed: all pass)*
- [x] Run the update-task-status.sh dry-run test to verify functional correctness *(completed: correct output)*
- [x] Verify flock is available and the lock file path is consistent *(completed: util-linux 2.42, referenced at lines 33 and 157)*
- [x] Verify mktemp template works correctly *(completed: generates unique filename)*

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- No files modified in this phase (verification only)

**Verification**:
- All grep checks return zero matches for shared temp paths
- All syntax checks pass without errors
- Dry-run test produces expected output
- flock version check confirms availability
- mktemp template test produces a unique filename

## Testing & Validation

- [x] `bash -n` syntax check passes for all three modified scripts *(completed)*
- [x] `grep` confirms zero remaining hardcoded shared temp paths across all three scripts *(completed)*
- [x] `grep` confirms zero remaining Python direct-write-to-state.json patterns *(completed)*
- [x] `update-task-status.sh --dry-run` produces correct output for preflight and postflight operations *(completed)*
- [x] Lock file path `specs/.state.json.lock` is consistently referenced *(completed)*
- [x] mktemp template `state.XXXXXX.json` generates valid unique filenames *(completed)*
- [x] flock binary is available and reports version correctly *(completed: util-linux 2.42)*

## Artifacts & Outputs

- `specs/645_parallel_write_safety/plans/01_parallel-write-safety.md` (this plan)
- `.claude/scripts/update-task-status.sh` (modified: flock + mktemp)
- `.claude/scripts/postflight-workflow.sh` (modified: mktemp)
- `.claude/scripts/skill-base.sh` (modified: mktemp + atomic Python writes)

## Rollback/Contingency

All three scripts are tracked in git. If implementation introduces regressions:
1. `git diff .claude/scripts/update-task-status.sh .claude/scripts/postflight-workflow.sh .claude/scripts/skill-base.sh` to review changes
2. `git checkout -- .claude/scripts/update-task-status.sh .claude/scripts/postflight-workflow.sh .claude/scripts/skill-base.sh` to revert all changes
3. The lock file `specs/.state.json.lock` can be safely deleted (flock does not depend on file presence, only lock state)
