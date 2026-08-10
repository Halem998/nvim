# Implementation Plan: Task #112

- **Task**: 112 - Fix leader ac artifact loader project-overview exclusion
- **Status**: [COMPLETED]
- **Date**: 2026-03-02
- **Feature**: Add file exclusion logic to Load All Artifacts sync to skip project-specific files and root CLAUDE.md
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `<leader>ac` "Load All Artifacts" feature copies all files from the global `.claude/` directory to the current project without any exclusion logic. This causes `project-overview.md` and `self-healing-implementation-details.md` (repository-specific files) to be copied to every target project. Additionally, the root-level `CLAUDE.md` (containing Neovim-specific coding standards) is synced alongside `.claude/CLAUDE.md`, which is inappropriate for non-Neovim projects.

The fix adds a configurable exclusion list to `scan_directory_for_sync()` in `scan.lua`, passes exclusion patterns from `sync.lua` when scanning context artifacts, and removes the root-level `CLAUDE.md` from automatic sync.

### Research Integration

Research report identified three key issues:
1. `scan_directory_for_sync()` (scan.lua:51-103) has no file exclusion mechanism
2. `scan_all_artifacts()` (sync.lua:149-229) syncs project-specific context files without filtering
3. Root `CLAUDE.md` (sync.lua:216-227) is synced but contains Neovim-specific standards irrelevant to other projects

## Goals & Non-Goals

**Goals**:
- Add `exclude_patterns` parameter to `scan_directory_for_sync()` for general-purpose file exclusion
- Exclude `project-overview.md` and `self-healing-implementation-details.md` from context sync
- Remove root-level `CLAUDE.md` (outside `.claude/`) from automatic sync
- Preserve `update-project.md` in sync (it is a guide/template, not project-specific content)
- Add tests for the new exclusion logic

**Non-Goals**:
- Merging or deduplicating the `.claude/CLAUDE.md` and root `CLAUDE.md` content
- Adding a `.syncignore` file mechanism (potential future enhancement)
- Changing the picker display filtering (separate from sync logic)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Exclusion list becomes stale as new repo-specific files are added | Low | Low | Document convention in code comments; list is easily extensible |
| Users expecting root CLAUDE.md to sync | Medium | Low | Root CLAUDE.md removal is intentional per research; `.claude/CLAUDE.md` still syncs |
| Regex pattern matching errors exclude unintended files | Medium | Low | Use exact relative path matching, not glob patterns; test thoroughly |

## Implementation Phases

### Phase 1: Add exclude_patterns to scan_directory_for_sync [COMPLETED]

**Goal**: Extend `scan_directory_for_sync()` in `scan.lua` to accept and apply an optional exclusion list, filtering files by their relative path within the scanned directory.

**Tasks**:
- [ ] Add optional `exclude_patterns` parameter (table of relative path strings) to `scan_directory_for_sync()`
- [ ] After computing `rel_path` for each file (line 86), check if it matches any exclusion pattern
- [ ] Skip files whose relative path matches an exclusion entry (exact string match or Lua pattern)
- [ ] Ensure backward compatibility: when `exclude_patterns` is nil or empty, behavior is unchanged

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Add exclude_patterns parameter and filtering logic to `scan_directory_for_sync()` (lines 51-103)

**Verification**:
- Existing tests pass unchanged (no exclusions = same behavior)
- Function signature remains backward compatible

---

### Phase 2: Apply exclusions in sync.lua and remove root CLAUDE.md sync [COMPLETED]

**Goal**: Pass exclusion patterns when scanning context artifacts and remove the root-level `CLAUDE.md` from the sync operation.

**Tasks**:
- [ ] Define a `CONTEXT_EXCLUDE_PATTERNS` table in `sync.lua` containing the relative paths to exclude: `"project/repo/project-overview.md"` and `"project/repo/self-healing-implementation-details.md"`
- [ ] Pass the exclusion patterns to `scan.scan_directory_for_sync()` calls for the `context` category (lines 163-165)
- [ ] Remove or comment out the root-level `CLAUDE.md` sync block (lines 216-227) with a code comment explaining why
- [ ] Verify `update-project.md` is NOT in the exclusion list

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add exclusion patterns for context scanning (lines 163-171) and remove root CLAUDE.md sync (lines 216-227)

**Verification**:
- Load All no longer copies `project-overview.md` or `self-healing-implementation-details.md`
- Load All no longer copies root-level `CLAUDE.md`
- `.claude/CLAUDE.md` is still synced (it is in `root_file_names` on line 199)
- `update-project.md` is still synced

---

### Phase 3: Add tests for exclusion logic [COMPLETED]

**Goal**: Add test cases to `scan_spec.lua` verifying that exclusion patterns work correctly.

**Tasks**:
- [ ] Add test: `scan_directory_for_sync` excludes files matching exclude_patterns
- [ ] Add test: `scan_directory_for_sync` with empty exclude_patterns returns all files (backward compat)
- [ ] Add test: `scan_directory_for_sync` excludes nested path patterns (e.g., `"project/repo/project-overview.md"`)
- [ ] Add test: files NOT in exclude list are still returned

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` - Add test cases in `scan_directory_for_sync` describe block

**Verification**:
- All new tests pass via `:TestFile`
- All existing tests still pass

---

## Testing & Validation

- [ ] Run `:TestFile` on `scan_spec.lua` -- all tests pass (existing + new)
- [ ] Manual test: open a non-nvim project, run `<leader>ac` Load All, verify `project-overview.md` is NOT in the sync list
- [ ] Manual test: verify `.claude/CLAUDE.md` IS still synced
- [ ] Manual test: verify root `CLAUDE.md` is NOT synced
- [ ] Manual test: verify `update-project.md` IS still synced

## Artifacts & Outputs

- Modified `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` with exclude_patterns support
- Modified `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` with context exclusions and root CLAUDE.md removal
- Updated `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` with exclusion tests

## Rollback/Contingency

Revert the three modified files to their previous state. The changes are isolated to scan/sync logic and do not affect any other picker or plugin functionality. No data migration or state changes are involved.
