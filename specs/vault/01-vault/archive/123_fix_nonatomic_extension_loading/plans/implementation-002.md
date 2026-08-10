# Implementation Plan: Fix Non-Atomic Extension Loading (Simplified)

- **Task**: 123 - fix_nonatomic_extension_loading
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md
- **Type**: neovim
- **Supersedes**: implementation-001.md (4-phase hybrid approach deemed over-engineered)

## Overview

Wrap the copy+merge sequence in `manager.load()` with pcall. On failure, clean up copied files and reverse completed merge operations using existing infrastructure. No new state functions, no "loading" marker, no recovery detection.

### Why This Approach

Research-002.md established that:
1. The "loading" state marker (original Phase 1) is unnecessary -- pcall prevents orphaned files from runtime errors, and process-kill scenarios are not meaningfully helped by same-disk state markers
2. Recovery detection (original Phase 3) is unnecessary -- it exists to find "loading" entries that we no longer create
3. All rollback infrastructure already exists: `all_files`, `all_dirs`, `loader_mod.remove_installed_files()`, `reverse_merge_targets()`

The simplified approach handles the documented failure mode (runtime error in `process_merge_targets`) completely while reducing implementation from 4 phases (~2-4 hours) to 1 phase (~1.5 hours).

## Goals & Non-Goals

**Goals**:
- Prevent orphaned files from new extension loads that fail mid-operation
- Clean up copied files and reverse merges when runtime errors occur
- Maintain backward compatibility with existing behavior on success

**Non-Goals**:
- Adding "loading" state markers (unnecessary overhead)
- Detecting incomplete loads from previous sessions (one-time historical issue)
- Protecting against process kill during file copy (same-disk state markers don't help)
- Staging directory with atomic rename (incompatible with scattered file layout)

## Implementation

### Phase 1: pcall Wrapping with Rollback [COMPLETED]

**Goal**: Wrap the file copy and merge sequence in pcall, rolling back on failure.

**Tasks**:
- [ ] Declare `merged_sections = {}` before the copy sequence (so rollback can access it)
- [ ] Wrap file copy operations (lines 225-252) and `process_merge_targets` (line 255) in pcall
- [ ] On pcall failure:
  1. Call `loader_mod.remove_installed_files(all_files, all_dirs)`
  2. Call `reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)`
  3. Return `false, "Extension load failed: " .. tostring(load_err)`
- [ ] On pcall success: proceed to existing `mark_loaded()` and state write (lines 258-259)

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - ~20 lines of changes in `manager.load()`

**Code sketch**:
```lua
-- Before file copies (after line 222)
local all_files = {}
local all_dirs = {}
local merged_sections = {}  -- Declare here so rollback can access

local load_ok, load_err = pcall(function()
  -- Copy agents (existing line 225)
  local files, dirs = loader_mod.copy_simple_files(ext_manifest, source_dir, target_dir, "agents", ".md")
  vim.list_extend(all_files, files)
  vim.list_extend(all_dirs, dirs)

  -- Copy commands, rules, skills, context, scripts (existing lines 230-252)
  -- ... (unchanged, just wrapped in pcall)

  -- Process merge targets (existing line 255)
  merged_sections = process_merge_targets(ext_manifest, source_dir, project_dir, config)
end)

if not load_ok then
  -- Rollback copied files
  loader_mod.remove_installed_files(all_files, all_dirs)
  -- Rollback completed merge operations
  reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
  return false, "Extension load failed: " .. tostring(load_err)
end

-- Success path unchanged (existing lines 258-259)
state = state_mod.mark_loaded(state, extension_name, ext_manifest, all_files, all_dirs, merged_sections)
state_mod.write(project_dir, state, config)
```

**Verification**:
- [ ] A failure in any copy step results in all previously copied files being removed
- [ ] A failure in `process_merge_targets` results in both copied files and completed merges being reversed
- [ ] On success, behavior is identical to current code
- [ ] Error message includes the original error for debugging

---

### Phase 2: Testing [COMPLETED]

**Goal**: Verify rollback behavior for key failure scenarios.

**Tasks**:
- [ ] Test: Simulate error during copy (e.g., inject `error()` after first copy)
  - Verify no files remain in target directory
  - Verify function returns false with error message
- [ ] Test: Simulate error during merge (e.g., pass malformed merge target)
  - Verify copied files are removed
  - Verify completed merges are reversed
  - Verify function returns false with error message
- [ ] Test: Successful load path
  - Verify state transitions to "active"
  - Verify all files are present
  - Verify no regressions from original behavior

**Timing**: 1 hour

**Files to modify**:
- Test file (new or existing) for extension load tests

**Verification**:
- [ ] All test cases pass
- [ ] No regressions in existing extension load/unload functionality

---

## Testing & Validation

- [ ] Simulated failure in copy step triggers rollback of all copied files
- [ ] Simulated failure in `process_merge_targets` triggers rollback of both files and merges
- [ ] Successful load works identically to current behavior
- [ ] Error message includes original error for debugging
- [ ] Existing load/unload/reload functionality works without regression

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rollback leaves partial files (cleanup error) | Medium | Low | Return error message; user can manually clean up or use unload |
| `merged_sections` partially populated when error occurs | None | Expected | `reverse_merge_targets` already handles partial sections (checks each key) |
| pcall catches errors from unrelated code | Low | Very Low | The pcall only wraps the specific copy+merge block |

## Rollback/Contingency

If this implementation introduces regressions:
1. The change is confined to one function in one file (`manager.load()` in `init.lua`)
2. Reverting the pcall wrapping restores original behavior exactly
3. No schema changes, no new files, no new dependencies

## Comparison to Original Plan

| Aspect | Original (v001) | Simplified (v002) |
|--------|-----------------|-------------------|
| Phases | 4 | 2 |
| Estimated effort | 2-4 hours | 1-2 hours |
| New state functions | 3 (`mark_loading`, `is_loading`, `detect_incomplete_loads`) | 0 |
| Files modified | 2 (init.lua, state.lua) | 1 (init.lua) |
| Lines of change | ~70 | ~20 |
| Handles runtime errors | Yes | Yes |
| Handles process kill | Partially (loading marker) | No (but loading marker didn't help much either) |
| Handles historical orphans | Yes (detection + cleanup) | No (manual unload sufficient) |
