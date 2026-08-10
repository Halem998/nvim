# Research Report: Task #123

**Task**: 123 - fix_nonatomic_extension_loading
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T00:30:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (extensions module, maildir atomic patterns), Neovim API testing
**Artifacts**: - specs/123_fix_nonatomic_extension_loading/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The extension loading sequence in `init.lua` performs 6 file-copy steps followed by merge operations and state writes, with no error protection or rollback around any step
- A failure at any point after the first file copy (line 225) leaves orphaned files on disk with no state tracking, making the extension system unable to detect or clean up the mess
- The codebase already has two established atomic-write patterns (maildir `atomic_write()` and persistence `queue_save()`) that use write-to-temp-then-rename, providing a precedent for the implementation approach
- **Recommended approach**: Hybrid solution combining early "loading" state marker (Solution 1) with pcall-based error wrapping and rollback (Solution 2), plus recovery detection in `check_conflicts()` (Solution 3)

## Context & Scope

### Problem Statement

The extension loading function `manager.load()` in `lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 154-267) executes a multi-step sequence that is not atomic. When any step after the initial conflict check fails, the system is left in an inconsistent state: files have been copied to the target project's `.claude/` directory, but no `extensions.json` state file records that fact.

### Evidence of the Problem

The git status shows `?? .claude/extensions/filetypes/` as an untracked directory with the filetypes extension source files present. The task description reports orphaned extension files in `Logos/Theory/.claude/` and `ProofChecker/.claude/` project directories without corresponding `extensions.json` files -- the classic symptom of a load that succeeded at file copy but failed before state write.

### Current Load Sequence (init.lua lines 154-267)

```
Step 1: Find extension manifest         (line 161)
Step 2: Check if already loaded          (line 170)
Step 3: Check for conflicts              (line 176)
Step 4: User confirmation dialog         (line 192)
Step 5: Ensure base directory            (line 218)
Step 6: Copy agents                      (line 225) -- POINT OF NO RETURN
Step 7: Copy commands                    (line 230)
Step 8: Copy rules                       (line 235)
Step 9: Copy skills                      (line 240)
Step 10: Copy context                    (line 245)
Step 11: Copy scripts                    (line 250)
Step 12: Process merge targets           (line 255) -- DOCUMENTED FAILURE POINT
Step 13: Update state                    (line 258)
Step 14: Write extensions.json           (line 259)
```

**Step 6** is the point of no return: once file copying begins, any subsequent failure leaves orphaned files. **Step 12** (`process_merge_targets`) is the documented crash site. However, any step from 6-14 can fail.

## Findings

### Failure Point Analysis

#### process_merge_targets (Step 12)

The `process_merge_targets()` function (init.lua lines 47-107) calls three merge operations:

1. **inject_section()** -- Injects markdown content into CLAUDE.md using section markers. Uses backup/restore for its own file but does not signal failure to the caller in a way that halts the load.

2. **merge_settings()** -- Deep-merges JSON settings. Calls `deep_merge()` (merge.lua line 184) which uses `vim.isarray()` on line 187. Testing confirms `vim.isarray(nil)` throws an error. If a malformed merge target passes a nil value into deep_merge, it crashes.

3. **append_index_entries()** -- Appends to index.json. Relatively safe but still unprotected.

**Key observation**: The `process_merge_targets` return value is a table of merged sections. Failures in individual merge operations are silently swallowed (each returns `false, nil` on failure). The crash only happens if the function itself throws an unhandled error (e.g., from `vim.isarray(nil)`, `vim.pesc()` on nil, or a malformed manifest table).

#### File Copy Operations (Steps 6-11)

The `copy_simple_files()`, `copy_skill_dirs()`, `copy_context_dirs()`, and `copy_scripts()` functions in `loader.lua` individually handle missing files gracefully (checking `vim.fn.filereadable`), but they do NOT:

- Use pcall to catch unexpected errors
- Track partial progress for rollback
- Report which files were actually copied vs. skipped

If a file copy function throws (e.g., `vim.fn.isdirectory` on a nil path from malformed manifest, or a permissions error on `helpers.ensure_directory`), the cascade halts mid-copy.

#### State Write (Step 14)

The `state_mod.write()` function (state.lua lines 100-111) uses `io.open` for file writing, which can fail silently on permission errors. It also shells out to `jq` for pretty-printing (line 49), which is a potential failure point if `jq` is unavailable.

### Existing Atomic Patterns in Codebase

Two established patterns exist for atomic file operations:

#### Pattern 1: Maildir atomic_write (maildir.lua:191-228)

```lua
function M.atomic_write(tmp_path, target_path, content)
  -- 1. Write to tmp file
  -- 2. Atomic rename to target (vim.loop.fs_rename)
  -- 3. On failure: delete tmp file
end
```

This is a classic write-to-temp-then-rename pattern. It prevents partial writes but does not handle multi-file transactions.

#### Pattern 2: Persistence queue_save (persistence.lua:290-306)

```lua
-- 1. Encode to JSON
-- 2. Write to temp file (.tmp suffix)
-- 3. Rename temp to final (vim.fn.rename)
-- 4. On failure: delete temp, log error
```

Same pattern as maildir but using `vim.fn.rename` instead of `vim.loop.fs_rename`.

#### Pattern 3: Merge module backup/restore (merge.lua)

The merge module already implements per-file backup/restore:

```lua
backup_file(filepath)     -- Creates .backup copy
restore_from_backup(filepath)  -- Restores from .backup
```

This is used internally for each merge operation but is not coordinated across the entire load sequence.

### No Recovery Mechanism Exists

Searching the extensions module for "recovery", "orphan", "corrupt", or "inconsistent" yields no results. The `check_conflicts()` function (loader.lua:263-304) only checks for file existence -- it does not distinguish between "file was placed by a previous extension load" vs. "file was manually created by the user".

## Solution Evaluation

### Solution 1: Early State Marker with "loading" Status

**Concept**: Write an `extensions.json` entry with `status: "loading"` before file copies begin. On success, update to `status: "active"`. On restart, detect "loading" status and trigger cleanup.

**Pros**:
- Simple to implement (add one state write before copies, one after)
- Provides crash recovery information
- Leverages existing `state_mod.mark_loaded()` with minor modifications
- Compatible with the existing `is_loaded()` check which filters by `status == "active"`

**Cons**:
- If the initial state write itself fails, no protection
- Does not prevent partial state (files exist but load failed)
- Requires a separate recovery function that runs at startup or on next load

**Implementation complexity**: Low (15-25 lines of new code)

### Solution 2: Atomic Copy with Rollback

**Concept**: Wrap the entire copy+merge sequence in a pcall. On failure, iterate through `all_files` and `all_dirs` collected so far and remove them.

**Pros**:
- Prevents orphaned files entirely
- Uses established pcall pattern already in the codebase
- Cleans up immediately rather than requiring separate recovery
- all_files/all_dirs tracking already exists (lines 221-222)

**Cons**:
- Merge operations are harder to roll back (section injection, settings merge, index entries)
- If rollback itself fails, state is still inconsistent
- Does not help with previously orphaned files from past failures

**Implementation complexity**: Medium (40-60 lines of new code)

### Solution 3: Recovery Detection in check_conflicts()

**Concept**: Enhance `check_conflicts()` to detect files that match extension patterns but have no corresponding state entry, treating them as orphans from a failed load.

**Pros**:
- Handles historical orphaned files
- Provides user-visible information about the problem
- Can be combined with any other solution

**Cons**:
- Reactive, not preventive
- Cannot distinguish extension-installed files from user-created files with the same names
- Must be careful not to delete user files

**Implementation complexity**: Low-Medium (20-30 lines of new code)

### Solution 4: State-First with File Tracking Array

**Concept**: Write the full intended file list to `extensions.json` before copying, then copy, then update status. On recovery, compare expected files vs. actual files.

**Pros**:
- Enables precise recovery (knows exactly what should exist)
- Can detect partial copies
- Supports resume-from-failure

**Cons**:
- Most complex to implement
- Requires manifest analysis before copy (which already happens for conflict check)
- Two state writes per load (before and after)

**Implementation complexity**: Medium-High (50-80 lines of new code)

## Recommendations

### Recommended Approach: Hybrid (Solutions 1 + 2 + 3)

The recommended implementation combines three solutions for defense-in-depth:

**Layer 1 -- Early state marker (Solution 1)**:
Before any file copies, write an extensions.json entry with `status: "loading"` and the manifest's `provides` data (intended file list). This is the cheapest protection against crashes.

```lua
-- Before file copies (after line 222 in current code)
state = state_mod.mark_loading(state, extension_name, ext_manifest)
state_mod.write(project_dir, state, config)
```

**Layer 2 -- pcall wrapping with rollback (Solution 2)**:
Wrap the entire copy+merge sequence in a pcall. On failure, use the already-populated `all_files` and `all_dirs` arrays plus the merge module's `restore_from_backup` to clean up.

```lua
local load_ok, load_err = pcall(function()
  -- All copy operations (current lines 225-252)
  -- process_merge_targets (current line 255)
end)

if not load_ok then
  -- Rollback: remove copied files
  loader_mod.remove_installed_files(all_files, all_dirs)
  -- Rollback: reverse any merge operations that succeeded
  -- Remove "loading" state entry
  state = state_mod.mark_unloaded(state, extension_name)
  state_mod.write(project_dir, state, config)
  return false, "Extension load failed: " .. tostring(load_err)
end
```

**Layer 3 -- Recovery detection (Solution 3)**:
Add a `state_mod.detect_loading_state()` function that checks for `status: "loading"` entries on startup or next `check_conflicts()` call. Offer to clean up or resume.

### Why Not Solution 4 Alone?

Solution 4 (state-first with file tracking) is conceptually cleaner but offers marginal benefit over the hybrid approach while being significantly more complex. The hybrid approach provides:

1. **Prevention** (pcall + rollback prevents orphans from new loads)
2. **Detection** (early state marker records intent for crash recovery)
3. **Historical cleanup** (recovery detection handles past orphans)

### Implementation Order

1. Add `mark_loading()` to state.lua (new function, ~10 lines)
2. Add pcall wrapping + rollback to `manager.load()` in init.lua (~30 lines)
3. Add `detect_incomplete_loads()` to state.lua (~15 lines)
4. Integrate recovery into `check_conflicts()` or as a separate startup check (~15 lines)
5. Add tests for each failure scenario

### Merge Rollback Detail

The merge module already has individual rollback functions:
- `remove_section()` reverses `inject_section()`
- `unmerge_settings()` reverses `merge_settings()`
- `remove_index_entries_tracked()` reverses `append_index_entries()`

The `reverse_merge_targets()` function in init.lua (lines 109-141) already orchestrates these. The rollback in the pcall error handler should call `reverse_merge_targets()` for any merge operations that completed before the failure.

This requires tracking which merge operations succeeded, which means `process_merge_targets()` should be refactored to report partial progress (return merged_sections even on partial failure) or each merge step should be individually pcall-wrapped.

## Decisions

1. **Hybrid approach over single solution**: Defense-in-depth is appropriate here because the extension system touches user project directories (external state), making recovery from inconsistency critical.
2. **pcall over temp-directory staging**: Staging all files in a temp directory then atomic-moving would be the most theoretically correct approach, but it adds significant complexity for marginal benefit. Most failures are runtime errors (bad data, API crashes), not I/O failures -- pcall handles these cleanly.
3. **"loading" status over "pending" or "installing"**: The term "loading" matches the existing vocabulary (the function is `manager.load()`, status transitions are `loading -> active`).
4. **Track merged_sections progressively**: Rather than treating merge operations as all-or-nothing, track which merges completed and reverse only those on rollback.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Rollback itself fails (e.g., file permission error) | Low | High | Log error, leave "loading" state for manual recovery |
| State write fails before file copies | Low | Low | No files copied yet, system returns to clean state |
| User manually modifies files during load | Very Low | Medium | Load is synchronous in Neovim UI thread; effectively impossible |
| `jq` unavailable for JSON formatting in state write | Low | Low | State module already falls back to raw JSON (state.lua line 52) |
| Recovery deletes user-created files | Low | High | Only clean up files listed in the "loading" state entry's intended file list |

## Context Extension Recommendations

- **Topic**: Atomic multi-file operations in Neovim Lua
- **Gap**: No existing context file documents patterns for transactional file operations spanning multiple files/directories
- **Recommendation**: Consider adding a section to `.claude/context/project/neovim/patterns/` covering pcall-based transaction patterns, as this pattern will be useful for other multi-step operations in the plugin system

## Appendix

### Search Queries Used
1. `vim.isarray|vim.tbl_isarray` in extensions module -- found 2 uses in merge.lua
2. `pcall.*rollback|atomic|transaction|staging` across lua/ -- found established patterns in himalaya/maildir and himalaya/persistence
3. `backup_file|restore_from_backup` in extensions module -- found 15 uses in merge.lua
4. `check_conflicts|orphan|recovery|corrupt` in extensions module -- no recovery mechanisms found

### References
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- Main load function (452 lines)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` -- File copy engine (342 lines)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- State tracking (225 lines)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` -- Merge strategies (417 lines)
- `lua/neotex/plugins/ai/shared/extensions/config.lua` -- Configuration schema (71 lines)
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` -- Manifest parsing (228 lines)
- `lua/neotex/plugins/tools/himalaya/data/maildir.lua:191-228` -- Atomic write precedent
- `lua/neotex/plugins/tools/himalaya/core/persistence.lua:290-306` -- Atomic write precedent

### Key Code References

**The failure point** (init.lua:255): `process_merge_targets` is called without pcall protection. If `deep_merge()` in merge.lua encounters unexpected data (nil values, type mismatches in nested structures), `vim.isarray()` or `vim.deep_equal()` can throw unhandled errors.

**The gap** (init.lua:258-259): State write happens only after all operations succeed. No intermediate state is recorded.

**Existing rollback support** (init.lua:109-141): `reverse_merge_targets()` already exists for unload -- it can be repurposed for rollback during failed loads.

### Neovim Version Context

- Neovim version: 0.11.6
- `vim.isarray` exists and works (succeeds on tables, throws on nil)
- `vim.tbl_isarray` does NOT exist in this version (returns nil)
- The code correctly uses `vim.isarray` (not the deprecated `vim.tbl_isarray`)
