# Implementation Plan: Task #186

- **Task**: 186 - filter_extension_artifacts_from_core_sync
- **Status**: [COMPLETED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [research-003.md](../reports/research-003.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-11
- **Feature**: Unified extension loader with manifest-based blocklist filtering for core sync
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

The core sync operation (`sync.lua`) currently copies all files from the global directory without distinguishing core artifacts from extension artifacts. When extensions are loaded into the global directory, their files leak into core sync output. This plan implements a manifest-based blocklist that aggregates all extension `provides` entries and excludes them during sync, plus a self-loading guard to prevent future contamination. A shared extension picker replaces two near-identical 245-line files, and the oversized Claude state wrapper is simplified.

### Research Integration

Research report 003 confirmed that:
- The shared extension infrastructure already handles parameterization via config objects
- Manifest-based blocklist (Pattern A) is the optimal filtering approach -- no schema changes needed
- The two extension pickers differ in only 3 lines out of 245
- The `scan_directory_for_sync` exclude check needs prefix matching for skills/context categories
- All copy operations are already idempotent

## Goals & Non-Goals

**Goals**:
- Core sync produces identical results regardless of what extensions are loaded in the global directory
- Manifest-based blocklist filters extension artifacts during `scan_all_artifacts()`
- Self-loading guard prevents extensions from being loaded into the global source directory
- Shared extension picker eliminates 490 lines of duplication across two files
- Claude state wrapper simplified from 102 lines of method-by-method delegation

**Non-Goals**:
- Changing the manifest schema (current schema already supports both systems)
- Caching the blocklist across syncs (per-sync computation ensures correctness)
- Modifying the extension loader copy semantics (already idempotent)
- Creating a core manifest (Pattern B) -- manifest enumeration (Pattern A) is sufficient
- Changing how extensions are loaded/unloaded (only sync filtering is affected)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blocklist misses files not declared in any manifest | Medium | Very Low | Symlink skip as defense in depth; clean global dir removes root cause |
| Self-loading guard breaks an existing workflow | Medium | Low | Clear error message; guard only blocks `project_dir == global_dir` |
| Shared picker introduces regressions in key mappings | Low | Low | Both pickers are nearly identical; diff is 3 lines |
| Prefix matching in exclude causes over-filtering | Medium | Low | Only activates for patterns containing `/`; exact match still works first |
| Breaking require paths when simplifying state wrapper | Medium | Low | Search all callers before removing methods |

## Implementation Phases

### Phase 1: Add `aggregate_extension_artifacts()` to manifest.lua [COMPLETED]

**Goal**: Create the function that reads all extension manifests and builds a blocklist keyed by category with set-based lookup.

**Tasks**:
- [ ] Add `aggregate_extension_artifacts(config)` function to `shared/extensions/manifest.lua`
- [ ] Function reads all extension manifests via existing `list_extensions(config)`
- [ ] Aggregates all `provides` entries into a blocklist: `{agents = {["file.md"] = true}, skills = {["skill-name"] = true}, ...}`
- [ ] Returns set-based structure (tables with string keys mapping to `true`) for O(1) lookup
- [ ] Handle edge cases: extensions without `provides`, empty category arrays

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Add aggregate function (~25 lines)

**Verification**:
- Load neovim, call `require("neotex.plugins.ai.shared.extensions.manifest").aggregate_extension_artifacts(config)` with both claude and opencode configs
- Verify returned blocklist contains entries from all extension manifests
- Verify empty categories return empty tables (not nil)

---

### Phase 2: Enhance scan.lua exclude matching with prefix support [COMPLETED]

**Goal**: Extend the exclude pattern check in `scan_directory_for_sync` to support prefix matching for skills (directory names) and context (path prefixes), while maintaining backward compatibility with existing exact-match patterns.

**Tasks**:
- [ ] Modify the exclude check loop in `scan_directory_for_sync` (around line 94-100) to add prefix matching
- [ ] Pattern: if `rel_path == pattern` (exact match) OR `rel_path:sub(1, #pattern + 1) == pattern .. "/"` (prefix match), exclude the file
- [ ] Add optional `skip_symlinks` parameter to `scan_directory_for_sync` as defense in depth
- [ ] When `skip_symlinks` is true, skip files where `vim.fn.resolve(path) ~= path`
- [ ] Ensure existing `CONTEXT_EXCLUDE_PATTERNS` in sync.lua still work (exact match preserved)

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Enhance exclude check (~10 lines changed)

**Verification**:
- Verify existing CONTEXT_EXCLUDE_PATTERNS still filter correctly (exact match)
- Test prefix matching: pattern "project/neovim" excludes "project/neovim/domain/neovim-api.md"
- Test that pattern "project" does NOT exclude "project-overview.md" (prefix must match at directory boundary)

---

### Phase 3: Apply blocklist in sync.lua `scan_all_artifacts()` [COMPLETED]

**Goal**: Integrate the manifest blocklist into the core sync operation so extension artifacts are excluded from every category scan.

**Tasks**:
- [ ] Import manifest module at top of sync.lua
- [ ] At the start of `scan_all_artifacts()`, build blocklist by calling `manifest.aggregate_extension_artifacts(config_for_system)`
- [ ] Determine the correct extension config to pass (need to map from picker config's `base_dir` to the extension config)
- [ ] For each `sync_scan()` call, convert the blocklist category set into an array of exclude patterns and merge with existing excludes (e.g., CONTEXT_EXCLUDE_PATTERNS)
- [ ] Convert set-based blocklist entries to array format for `exclude_patterns` parameter: `{["file.md"] = true}` -> `{"file.md"}`
- [ ] For context category, merge blocklist context entries with existing CONTEXT_EXCLUDE_PATTERNS
- [ ] Update module comment to reflect that sources may contain extension artifacts and filtering is active

**Timing**: 1.0 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Blocklist integration (~30 lines)

**Verification**:
- From a project directory, run "Load Core Agent System" with extensions loaded in global dir
- Verify extension agents, skills, commands, rules, context are NOT synced
- Verify all core artifacts ARE still synced
- Test with both `.claude` and `.opencode` base_dir configurations

---

### Phase 4: Add self-loading guard to shared/extensions/init.lua [COMPLETED]

**Goal**: Prevent extensions from being loaded when the target project IS the global source directory, which would contaminate the source and cause future sync leakage.

**Tasks**:
- [ ] In `manager.load()`, after resolving `project_dir`, compare with `scan.get_global_dir()`
- [ ] If `project_dir == global_dir`, return `false, "Cannot load extensions into source directory"` before any other work
- [ ] Import scan module at top of init.lua (or use a lightweight path comparison)
- [ ] Add `opts.force` override to bypass the guard for exceptional cases
- [ ] Log a warning if force is used

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add guard check (~10 lines)

**Verification**:
- From the global source directory (`~/.config/nvim`), attempt to load an extension
- Verify it fails with clear error message
- From a different project directory, verify extension loading still works normally
- Verify `opts.force = true` bypasses the guard

---

### Phase 5: Create shared extension picker [COMPLETED]

**Goal**: Replace the two near-identical 245-line extension picker files with a single shared implementation that accepts configuration parameters.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/shared/extensions/picker.lua` with a `create(extensions_module, picker_config)` factory function
- [ ] Copy the picker logic from `claude/extensions/picker.lua` as the base
- [ ] Parameterize the 3 differing elements: extensions module reference, prompt title (from `picker_config.label`), and notification text
- [ ] Replace `claude/extensions/picker.lua` with thin delegation (~10 lines): require shared picker, pass claude extensions module and claude picker config
- [ ] Replace `opencode/extensions/picker.lua` with thin delegation (~10 lines): require shared picker, pass opencode extensions module and opencode picker config
- [ ] Ensure all key mappings are preserved: Enter (toggle), Ctrl-r (reload), Ctrl-d (details), Tab (multi-select)
- [ ] Ensure floating window for file list display is preserved

**Timing**: 1.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` - NEW shared picker (~245 lines, moved from claude)
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Simplify to ~10 lines
- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Simplify to ~10 lines

**Verification**:
- Open `:ClaudeExtensions` picker, verify all functionality works (toggle, reload, details, multi-select)
- Open `:OpencodeExtensions` picker, verify identical functionality
- Verify prompt titles show "Claude Extensions" vs "OpenCode Extensions" correctly
- Verify load/unload/reload operations work through both pickers

---

### Phase 6: Simplify claude/extensions/state.lua [COMPLETED]

**Goal**: Reduce the 102-line method-by-method delegation wrapper to a simpler pattern, since it adds no value over calling shared state directly with config.

**Tasks**:
- [ ] Search all callers of `claude/extensions/state.lua` to understand usage patterns
- [ ] If callers can use the shared state module directly (passing config), remove the wrapper entirely and update imports
- [ ] If a thin wrapper is still needed for backward compatibility, reduce to a factory pattern that returns the shared module bound to claude config
- [ ] Update any `require("neotex.plugins.ai.claude.extensions.state")` references
- [ ] Also evaluate `claude/extensions/loader.lua` (7-line re-export) for similar cleanup

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/state.lua` - Simplify or remove
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` - Evaluate for removal
- Any files that import these modules - Update require paths

**Verification**:
- Extension load/unload/reload operations work correctly for Claude system
- State is correctly read/written to extensions.json
- No broken require paths

---

### Phase 7: Clean existing symlinks and final verification [COMPLETED]

**Goal**: One-time cleanup of any symlinks in the global directory, plus end-to-end verification of the complete system.

**Tasks**:
- [ ] Check for symlinks in global `.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/rules/`, `.claude/context/`
- [ ] Remove any symlinks found (they should have been replaced by regular file copies already)
- [ ] Check for symlinks in global `.opencode/` directories similarly
- [ ] Run end-to-end test: load extensions in global dir, sync to a test project, verify only core artifacts appear
- [ ] Verify extension load/unload cycle in a non-global project directory
- [ ] Update sync.lua module docstring to document the filtering behavior

**Timing**: 0.5 hours

**Files to modify**:
- Global directory symlink cleanup (file system operations, no code changes)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Update module docstring

**Verification**:
- `find ~/.config/nvim/.claude -type l` returns no results
- `find ~/.config/nvim/.opencode -type l` returns no results
- Full sync from clean project directory produces correct artifact set
- Extension load + sync + extension unload cycle works cleanly

## Testing & Validation

- [ ] Phase 1: `aggregate_extension_artifacts()` returns correct blocklist for both claude and opencode configs
- [ ] Phase 2: Prefix matching excludes `project/neovim/anything` but not `project-overview.md`
- [ ] Phase 3: Core sync excludes all extension artifacts while preserving all core artifacts
- [ ] Phase 4: Self-loading guard prevents extension load in global directory
- [ ] Phase 5: Both `:ClaudeExtensions` and `:OpencodeExtensions` pickers work identically
- [ ] Phase 6: All claude extension state operations work after simplification
- [ ] Phase 7: No symlinks remain in global directories
- [ ] End-to-end: Load extensions -> sync to project -> verify only core files copied -> unload extensions -> re-sync -> verify identical output

## Artifacts & Outputs

- Modified: `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (aggregate function)
- Modified: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (prefix matching)
- Modified: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (blocklist integration)
- Modified: `lua/neotex/plugins/ai/shared/extensions/init.lua` (self-loading guard)
- Created: `lua/neotex/plugins/ai/shared/extensions/picker.lua` (shared picker)
- Simplified: `lua/neotex/plugins/ai/claude/extensions/picker.lua` (thin wrapper)
- Simplified: `lua/neotex/plugins/ai/opencode/extensions/picker.lua` (thin wrapper)
- Simplified: `lua/neotex/plugins/ai/claude/extensions/state.lua` (reduced delegation)
- Evaluated: `lua/neotex/plugins/ai/claude/extensions/loader.lua` (potential removal)

## Rollback/Contingency

Each phase is independently reversible via git:
- Phases 1-4 are additive changes to existing modules (revert individual commits)
- Phase 5 creates a new file and simplifies two existing files (revert to restore originals)
- Phase 6 simplifies wrappers (revert to restore method-by-method delegation)
- Phase 7 is a one-time cleanup (symlinks can be recreated if needed, though there is no reason to)

If the blocklist approach proves insufficient, fall back to the clean global directory approach (remove extension artifacts from global dir manually). The self-loading guard (Phase 4) prevents future contamination regardless.
