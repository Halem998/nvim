# Implementation Plan: Task #699

- **Task**: 699 - Revise /pr command to be single entry point for branch creation, CI, and PR submission
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/699_revise_pr_command_branch_ci_submit/reports/01_research-pr-command-revision.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four targeted edits to `.claude/extensions/cslib/commands/pr.md` (1054 lines) to make `pr-description.md` mandatory in task mode, insert a `lake exe cache get` step after branch creation, and simplify the STEP 8/9 fallback section headers. All changes are isolated to specific line ranges and do not alter path-mode or description-mode flows.

### Research Integration

Research identified the exact line ranges, current behavior, and replacement content for each edit. The file is an agent-executed instruction document (not executable code), so changes are markdown text edits with no build step.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Make `pr-description.md` a hard requirement in task mode (error + STOP if missing)
- Insert STEP 5b (`lake exe cache get`) after branch creation for Mathlib cache restoration
- Update STEP 8 and STEP 9 fallback section headers to remove dead task-mode clause
- Preserve all path-mode and description-mode flows unchanged

**Non-Goals**:
- Renumbering existing steps (5b insertion avoids this)
- Removing the interactive composition code body from STEP 8/9 (only headers change)
- Tightening the task status pre-check warning in STEP 2
- Modifying CI pipeline steps (STEP 7)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect line numbers due to prior edits | M | L | Verify line numbers via grep before editing |
| STEP 5b cache failure blocking PR flow | H | L | Implementation is explicitly non-fatal with warning |
| Breaking path/description mode flows | H | L | Edits are scoped to task-mode guards only |
| Step numbering confusion with 5b | L | M | Clearly document as "STEP 5b" to avoid renumbering |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: STEP 2 Hard Error [NOT STARTED]

**Goal**: Make `pr-description.md` mandatory in task mode -- replace warning + fallback with hard error + STOP.

**Tasks**:
- [ ] Locate the `else` branch in STEP 2 (lines 117-121) that sets `has_pr_description=false`
- [ ] Replace the 3-line warning block with a hard error block:
  - **Before** (lines 117-121):
    ```
      has_pr_description=false
      echo "Warning: pr-description.md not found at $pr_desc_path"
      echo "The description will be composed interactively (STEP 9)."
    ```
  - **After**:
    ```
      echo "ERROR: pr-description.md not found at $pr_desc_path"
      echo "Task-mode /pr requires a pre-built pr-description.md."
      echo "Run skill-pr-implementation to generate this file before submitting."
      # STOP -- cannot continue without pr-description.md in task mode
    ```
- [ ] Verify the `fi` on line 121 is preserved and the `else` block terminates correctly
- [ ] Confirm no downstream references to `has_pr_description=false` in task mode are left dangling

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Lines 117-121 (STEP 2 else branch)

**Verification**:
- grep for `has_pr_description=false` should return zero matches in the file
- grep for `ERROR: pr-description.md not found` confirms the new error message exists
- The `else` / `fi` structure around line 116-121 is syntactically valid

---

### Phase 2: Insert STEP 5b Cache Management [NOT STARTED]

**Goal**: Insert a new STEP 5b section between STEP 5 "On success" line (line 314) and STEP 6 (line 319) to run `lake exe cache get`.

**Tasks**:
- [ ] Locate the "On success" / "IMMEDIATELY CONTINUE to STEP 6" line at end of STEP 5 (around line 314)
- [ ] Insert the following new section between STEP 5 and STEP 6:
  ```markdown
  ---

  ### STEP 5b: Fetch Mathlib Cache

  **EXECUTE NOW**: Fetch the pre-built Mathlib `.olean` cache so CI does not trigger a near-full rebuild.

  When a feature branch is created from `upstream/main`, Lean's build cache may be invalidated
  because the new branch diverges from the branch the existing `.olean` files were built on.
  Running `lake exe cache get` restores the Mathlib pre-built cache so only CSLib modules need
  to be rebuilt during CI.

  ```bash
  cd /home/benjamin/Projects/cslib
  lake exe cache get 2>&1
  CACHE_STATUS=$?

  if [ $CACHE_STATUS -eq 0 ]; then
    echo "[OK] Mathlib cache fetched successfully."
  else
    echo "Warning: lake exe cache get exited with status $CACHE_STATUS."
    echo "CI may take significantly longer due to a full Mathlib rebuild."
    echo "Proceeding anyway -- this is non-fatal."
  fi
  ```

  Cache fetch failure is **non-fatal**: CI will still run correctly, just more slowly. Always
  proceed to STEP 6 regardless of cache fetch exit status.

  **On success (or non-fatal failure)**: **IMMEDIATELY CONTINUE** to STEP 6.
  ```
- [ ] Verify the markdown section break (`---`) separates STEP 5 from STEP 5b
- [ ] Verify STEP 6 heading still follows immediately after the new section

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Insert after line 314 (end of STEP 5), before line 319 (STEP 6)

**Verification**:
- grep for "STEP 5b: Fetch Mathlib Cache" returns exactly 1 match
- grep for "lake exe cache get" returns at least 1 match in the new section
- STEP 6 heading is still present and follows the new section

---

### Phase 3: Update STEP 8/9 Fallback Section Headers [NOT STARTED]

**Goal**: Remove the "task mode when `has_pr_description` is false" clause from STEP 8 and STEP 9 fallback section headers since that path is now unreachable.

**Tasks**:
- [ ] Locate STEP 8 fallback section header (line 564) containing text like "Path mode or Description mode (or task mode when `has_pr_description` is false)"
- [ ] Replace with: "Path mode or Description mode:"
- [ ] Locate STEP 9 fallback section header (line 687) containing similar task-mode fallback clause
- [ ] Replace with: "Path mode or Description mode:"
- [ ] Verify no other references to "task mode when has_pr_description is false" remain

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Line 564 (STEP 8 header) and line 687 (STEP 9 header)

**Verification**:
- grep for "task mode when" returns zero matches in the file
- grep for "Path mode or Description mode:" returns exactly 2 matches (STEP 8 and STEP 9)
- Surrounding content of STEP 8/9 interactive flows is unchanged

---

### Phase 4: Verification [NOT STARTED]

**Goal**: End-to-end verification that all edits are consistent, no broken markdown structure, and flows are coherent.

**Tasks**:
- [ ] Read full file and confirm STEP numbering is: 1, 2, 3, 4, 5, 5b, 6, 7, 8, 9, 10, 10b, 11
- [ ] Verify no orphaned `has_pr_description=false` assignments exist
- [ ] Verify STEP 5b is positioned correctly between STEP 5 and STEP 6
- [ ] Verify the STEP 2 error block includes a clear STOP instruction
- [ ] Verify path-mode and description-mode flows in STEP 8/9 are untouched (content body unchanged)
- [ ] Check total line count is reasonable (original 1054 + ~25 lines for STEP 5b = ~1080)

**Timing**: 15 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (read-only verification)

**Verification**:
- All grep checks from phases 1-3 pass
- File structure is valid markdown with no broken headings or unclosed code blocks
- Step flow is logically coherent: task mode without pr-description.md errors at STEP 2

---

## Testing & Validation

- [ ] grep confirms `has_pr_description=false` does not appear in file
- [ ] grep confirms "STEP 5b: Fetch Mathlib Cache" appears exactly once
- [ ] grep confirms "task mode when" does not appear in STEP 8/9 headers
- [ ] grep confirms "ERROR: pr-description.md not found" appears in STEP 2
- [ ] File has valid markdown structure (no unclosed code blocks)
- [ ] Path-mode and description-mode flows pass visual inspection (unchanged)

## Artifacts & Outputs

- `.claude/extensions/cslib/commands/pr.md` - Modified command file (4 edits)
- `specs/699_revise_pr_command_branch_ci_submit/plans/01_implementation-plan.md` - This plan

## Rollback/Contingency

All changes are to a single file (`.claude/extensions/cslib/commands/pr.md`). Rollback via `git checkout -- .claude/extensions/cslib/commands/pr.md` restores the original. No database migrations, no dependency changes, no build artifacts.
