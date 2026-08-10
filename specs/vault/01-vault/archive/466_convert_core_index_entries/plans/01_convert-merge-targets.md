# Implementation Plan: Convert core-index-entries.json to standard merge_targets

- **Task**: 466 - Convert core-index-entries.json from static fixture to standard merge_targets
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: 465 (completed)
- **Research Inputs**: [specs/466_convert_core_index_entries/reports/01_convert-merge-targets.md]
- **Artifacts**: plans/01_convert-merge-targets.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
- **Type**: meta

## Overview

The core extension loads its index entries via 12 lines of special-case code (init.lua:488-499) instead of using the standard `merge_targets` mechanism that all other extensions use. This plan converts core to use the same `merge_targets.index` pattern, eliminating the last piece of core-specific special-casing in the extension loader. The file is relocated from `extensions/core/context/core-index-entries.json` to `extensions/core/index-entries.json` to match the convention used by nvim, memory, and epidemiology extensions.

### Research Integration

- [01_convert-merge-targets.md](../reports/01_convert-merge-targets.md) -- Integrated in plan version 1 (2026-04-16). Covers current code paths, merge_targets pattern, orphan cleanup safety, and documentation references.

## Goals & Non-Goals

- **Goals**:
  - Eliminate special-case code in init.lua (lines 488-499) for core index entry loading
  - Add `merge_targets.index` to core manifest.json so core entries are tracked in `merged_sections`
  - Relocate the source file to match extension convention (`index-entries.json` at extension root)
  - Update all documentation referencing the old path (5 files identified in research)
  - Verify core entries survive reload and are properly tracked

- **Non-Goals**:
  - Changing the content of core-index-entries.json (only location and loading mechanism change)
  - Modifying the merge.lua or state.lua modules (they already support this pattern)
  - Changing orphan cleanup behavior (already safe for non-project/ entries)
  - Restructuring other extensions

## Risks & Mitigations

- **Risk**: Core entries missing after reload if file rename is not atomic with manifest update. **Mitigation**: Phase 1 does both file move and manifest update together; entries already exist in index.json from prior loads.
- **Risk**: Existing installations have empty `merged_sections` for core. **Mitigation**: First reload after update will populate tracking data; `append_index_entries` deduplicates so no duplicates created.
- **Risk**: Documentation references stale paths. **Mitigation**: Phase 3 explicitly updates all 5 documentation files identified in research.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |
| 3    | 3      | 2          |
| 4    | 4      | 3          |

Phases within the same wave can execute in parallel.

### Phase 1: Relocate file and update manifest [COMPLETED]

- **Goal:** Move the index entries file to the standard location and add `merge_targets.index` to the core manifest
- **Tasks:**
  - [ ] Move `.claude/extensions/core/context/core-index-entries.json` to `.claude/extensions/core/index-entries.json` (use `git mv`)
  - [ ] Add `"index"` entry to `merge_targets` in `.claude/extensions/core/manifest.json`:
    ```json
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
    ```
  - [ ] Verify the JSON in manifest.json is valid after editing
- **Timing:** 10 minutes
- **Depends on:** none

### Phase 2: Remove special-case code from init.lua [COMPLETED]

- **Goal:** Delete the 12-line special-case block that loads core index entries outside the standard merge_targets pipeline
- **Tasks:**
  - [ ] Remove the `core_index_path` code block (lines 488-499 in `lua/neotex/plugins/ai/shared/extensions/init.lua`)
  - [ ] Remove any preceding comment line that introduces this block
  - [ ] Verify no other code references `core_index_path` or `core-index-entries` in init.lua
  - [ ] Confirm `process_merge_targets()` call on line 502 (or nearby) will now handle index entry loading for core
- **Timing:** 10 minutes
- **Depends on:** 1

### Phase 3: Update documentation [COMPLETED]

- **Goal:** Fix all documentation references to the old file path and mechanism
- **Tasks:**
  - [ ] Update `.claude/extensions/core/context/README.md` -- remove or update reference to `core-index-entries.json`
  - [ ] Update `.claude/context/README.md` -- update core index entries description
  - [ ] Update `.claude/docs/architecture/extension-system.md` -- replace special-case description with merge_targets description
  - [ ] Update `.claude/extensions/core/docs/architecture/extension-system.md` -- same updates
  - [ ] Update `.claude/extensions/README.md` -- update core extension description
- **Timing:** 20 minutes
- **Depends on:** 2

### Phase 4: Verification [COMPLETED]

- **Goal:** Confirm the conversion works correctly end-to-end
- **Tasks:**
  - [ ] Reload core extension and verify `.claude/context/index.json` still contains all core entries
  - [ ] Check `.claude/extensions.json` core entry now has `merged_sections.index` with tracked paths
  - [ ] Verify unload/reload cycle preserves core entries correctly
  - [ ] Confirm no references to old path remain in codebase (grep for `core-index-entries`)
  - [ ] Confirm `extensions/core/context/` directory no longer contains the entries file
- **Timing:** 15 minutes
- **Depends on:** 3

## Testing & Validation

- [ ] After Phase 1: `jq . .claude/extensions/core/manifest.json` succeeds (valid JSON)
- [ ] After Phase 1: `.claude/extensions/core/index-entries.json` exists and contains entries
- [ ] After Phase 2: No references to `core_index_path` in init.lua
- [ ] After Phase 4: Grep for `core-index-entries` returns zero results outside specs/
- [ ] After Phase 4: Core `merged_sections` in extensions.json includes `index` tracking data
- [ ] After Phase 4: All core context entries present in `.claude/context/index.json`

## Artifacts & Outputs

- plans/01_convert-merge-targets.md (this file)
- summaries/01_convert-merge-targets-summary.md (after implementation)

## Rollback/Contingency

- Revert the git commits from each phase (all changes are in version control)
- If core entries are lost from index.json, manually run the extension loader to re-merge
- The old special-case code can be restored from git history if the merge_targets approach fails
