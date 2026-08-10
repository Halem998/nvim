# Implementation Plan: Fix Non-Atomic Extension Loading

- **Task**: 123 - fix_nonatomic_extension_loading
- **Status**: [NOT STARTED]
- **Effort**: 2-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

The extension loading function `manager.load()` in `init.lua` performs 6 file-copy steps followed by merge operations and a state write, with no error protection or rollback. A failure at any point after the first file copy (line 225) leaves orphaned files on disk with no state tracking. This plan implements a defense-in-depth hybrid approach: (1) an early "loading" state marker written before file copies, (2) pcall wrapping of the copy+merge sequence with rollback on failure, and (3) a recovery detection function for detecting incomplete loads on startup or next load.

### Research Integration

Research report `research-001.md` identified the exact failure sequence (steps 6-14 in `manager.load()`), confirmed that `all_files`/`all_dirs` tracking already exists (lines 221-222), that `reverse_merge_targets()` already exists for unload (lines 109-141), and that `loader_mod.remove_installed_files()` is available. The recommended hybrid approach (Solutions 1+2+3) is adopted directly. Research also confirmed `vim.isarray(nil)` throws in Neovim 0.11.6, explaining the `process_merge_targets` crash.

## Goals & Non-Goals

**Goals**:
- Prevent orphaned files from new extension loads that fail mid-operation
- Record loading intent in `extensions.json` before file copies begin
- Roll back all copied files and merge operations on failure
- Detect and offer cleanup for previously incomplete loads
- Maintain backward compatibility with existing `extensions.json` format

**Non-Goals**:
- Staging files in a temp directory before atomic rename (over-engineered for this use case)
- Cleaning up orphaned files from past failures automatically without user confirmation
- Changing the overall load sequence or refactoring the extension system architecture
- Adding retry logic for failed loads

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rollback itself fails (file permission error) | High | Low | Log error, leave "loading" state for manual recovery via `detect_incomplete_loads()` |
| State write fails before file copies | Low | Low | No files copied yet, system returns to clean state |
| `reverse_merge_targets` fails during rollback | Medium | Low | Catch error in pcall, log it, continue with file cleanup; "loading" state remains for detection |
| New "loading" status breaks existing `is_loaded()` checks | Medium | Very Low | `is_loaded()` already filters by `status == "active"`, so "loading" entries are invisible to it |
| Recovery deletes user-created files | High | Low | Only clean up files listed in the "loading" state entry's `provides` manifest data |

## Implementation Phases

### Phase 1: Add Loading State Marker to state.lua [NOT STARTED]

**Goal**: Add a `mark_loading()` function that writes an `extensions.json` entry with `status: "loading"` and manifest provides data before file copies begin.

**Tasks**:
- [ ] Add `M.mark_loading(state, extension_name, manifest)` function to `state.lua`
  - Store `status = "loading"`, `version`, `loaded_at` timestamp, manifest `provides` data
  - Return updated state table (same pattern as `mark_loaded`)
- [ ] Add `M.is_loading(state, extension_name)` helper function
  - Return true if extension exists with `status == "loading"`
- [ ] Verify `is_loaded()` correctly ignores "loading" entries (it checks `status == "active"`)

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Add `mark_loading()` and `is_loading()` functions (~15 lines)

**Verification**:
- `mark_loading()` creates entry with `status = "loading"` and manifest provides data
- `is_loaded()` returns false for "loading" entries
- `is_loading()` returns true only for "loading" entries

---

### Phase 2: Wrap Load Sequence in pcall with Rollback [NOT STARTED]

**Goal**: Protect the file copy and merge sequence in `manager.load()` with pcall, rolling back all changes on failure.

**Tasks**:
- [ ] Insert `mark_loading()` call and state write after the `all_files`/`all_dirs` initialization (after line 222) and before the first file copy (line 225)
- [ ] Wrap file copy operations (lines 225-252) and `process_merge_targets` (line 255) in a pcall block
- [ ] On pcall success: proceed to existing `mark_loaded()` and state write (lines 258-259)
- [ ] On pcall failure: execute rollback sequence:
  1. Call `loader_mod.remove_installed_files(all_files, all_dirs)` to clean up copied files
  2. Call `reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)` for any merge operations that succeeded (requires `merged_sections` to be accessible from the outer scope)
  3. Call `state_mod.mark_unloaded(state, extension_name)` to remove the "loading" entry
  4. Call `state_mod.write(project_dir, state, config)` to persist the cleanup
  5. Return `false, "Extension load failed: " .. tostring(load_err)`
- [ ] Refactor `process_merge_targets` to track progress incrementally:
  - Declare `merged_sections` in the outer scope (before pcall) so rollback can access it
  - Each merge step in `process_merge_targets` updates `merged_sections` immediately after success, so partial progress is available for rollback

**Timing**: 1 hour

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Restructure `manager.load()` with pcall wrapping and rollback (~30 lines of changes)

**Verification**:
- A failure in any copy step results in all previously copied files being removed
- A failure in `process_merge_targets` results in both copied files and completed merges being reversed
- The "loading" state entry is removed on rollback
- On success, behavior is identical to current code (state transitions from "loading" to "active")

---

### Phase 3: Add Recovery Detection [NOT STARTED]

**Goal**: Add a function that detects incomplete "loading" entries from previous failed/crashed loads and provides cleanup capability.

**Tasks**:
- [ ] Add `M.detect_incomplete_loads(state)` function to `state.lua`
  - Iterate `state.extensions`, collect entries where `status == "loading"`
  - Return array of `{name = extension_name, info = entry}` for each incomplete load
- [ ] Add `M.cleanup_incomplete(state, extension_name, project_dir, config)` function to `state.lua`
  - Read the "loading" entry's provides data
  - Build expected file paths from provides manifest
  - Remove files that exist and match the expected list
  - Remove the "loading" state entry
  - Write updated state
  - Return count of cleaned files
- [ ] Integrate detection into `manager.load()`:
  - At the start of `manager.load()`, after reading state, call `detect_incomplete_loads()`
  - If incomplete loads are found for the same extension being loaded, automatically clean up
  - If incomplete loads are found for other extensions, log a warning with `helpers.notify()`

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Add `detect_incomplete_loads()` and `cleanup_incomplete()` (~25 lines)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Integrate detection at start of `manager.load()` (~10 lines)

**Verification**:
- `detect_incomplete_loads()` returns empty array when no "loading" entries exist
- `detect_incomplete_loads()` correctly identifies "loading" entries
- `cleanup_incomplete()` removes files listed in the provides data and cleans state
- Loading an extension after a previous failed load of the same extension auto-cleans

---

### Phase 4: Testing and Validation [NOT STARTED]

**Goal**: Verify all failure scenarios are handled correctly through automated tests.

**Tasks**:
- [ ] Create test file `lua/neotex/plugins/ai/shared/extensions/state_spec.lua` (or add to existing test file if one exists)
- [ ] Test `mark_loading()`: verify state entry has `status = "loading"` and correct manifest data
- [ ] Test `is_loading()`: verify returns true for "loading", false for "active" and missing entries
- [ ] Test `detect_incomplete_loads()`: verify detection with mixed "active" and "loading" entries
- [ ] Test `cleanup_incomplete()`: verify file removal and state cleanup
- [ ] Test rollback in `manager.load()`:
  - Mock a failure in `process_merge_targets` (e.g., inject error-throwing merge target)
  - Verify files are cleaned up after failure
  - Verify state reverts to pre-load state
  - Verify correct error message is returned
- [ ] Test successful load path: verify "loading" -> "active" transition works
- [ ] Run tests with `nvim --headless -c "lua require('plenary.busted').run('path/to/spec')" -c "q"`

**Timing**: 1 hour

**Files to modify**:
- Test file (new or existing) for state and load function tests

**Verification**:
- All test cases pass
- No regressions in existing extension load/unload functionality
- Edge cases covered: empty manifest, nil provides, missing files during cleanup

## Testing & Validation

- [ ] `mark_loading()` creates correct state entry with "loading" status
- [ ] `is_loaded()` returns false for "loading" status entries (no behavior change)
- [ ] Simulated failure in copy step triggers rollback of all copied files
- [ ] Simulated failure in `process_merge_targets` triggers rollback of both files and merges
- [ ] "loading" state entry is removed on successful rollback
- [ ] "loading" state entry transitions to "active" on successful load
- [ ] `detect_incomplete_loads()` finds "loading" entries from previous sessions
- [ ] `cleanup_incomplete()` removes only files from the loading manifest
- [ ] End-to-end: load an extension, verify success; simulate crash mid-load, verify recovery on next load
- [ ] Existing load/unload/reload functionality works without regression

## Artifacts & Outputs

- `specs/123_fix_nonatomic_extension_loading/plans/implementation-001.md` (this file)
- Modified: `lua/neotex/plugins/ai/shared/extensions/state.lua` (new functions)
- Modified: `lua/neotex/plugins/ai/shared/extensions/init.lua` (pcall wrapping, recovery integration)
- New or modified: test file for extension state and load atomicity
- `specs/123_fix_nonatomic_extension_loading/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

If the implementation introduces regressions:
1. The changes are confined to two files (`state.lua` and `init.lua`) with additive modifications
2. Reverting the pcall wrapping in `init.lua` restores original behavior (the new state functions in `state.lua` are unused without the init.lua changes)
3. Git revert of the implementation commits restores the original non-atomic behavior
4. No schema changes to `extensions.json` -- "loading" entries are simply additional valid states that existing code ignores
