# Research Report: Task #466

**Task**: 466 - Convert core-index-entries.json from static fixture to standard merge_targets
**Started**: 2026-04-16T12:00:00Z
**Completed**: 2026-04-16T12:15:00Z
**Effort**: Small (3 files changed)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: init.lua extension loader, merge.lua, state.lua, core manifest.json
- Codebase: nvim/memory/epidemiology extension manifests (merge_targets patterns)
- Codebase: extensions.json (current core state)
**Artifacts**:
- specs/466_convert_core_index_entries/reports/01_convert-merge-targets.md
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The core extension loads its index entries via 12 lines of special-case code (init.lua:488-499) instead of using the standard `merge_targets` mechanism that all other extensions use.
- The fix is straightforward: add an `"index"` key to the core manifest's `merge_targets`, rename/move the source file to match the convention, and delete the special-case code block.
- The core entries are currently NOT tracked in `merged_sections` (state shows `[]`), which means core unload cannot cleanly reverse these entries. Converting to `merge_targets` fixes this.
- The orphan cleanup function (`remove_orphaned_index_entries`) already protects non-`project/` entries, so core entries will survive cleanup regardless of the loading mechanism. No ordering concern exists.

## Context & Scope

The extension loader (init.lua) has one remaining piece of core-specific special-casing: lines 488-499 load `core-index-entries.json` directly from the extension source directory and call `merge_mod.append_index_entries()` without tracking. All other extensions use the `merge_targets.index` mechanism in their manifest, which routes through `process_merge_targets()` and properly tracks added paths in `merged_sections.index` for clean unload.

This task eliminates that special-casing to make core fully uniform with other extensions.

## Findings

### Current Special-Case Code (init.lua:488-499)

```lua
-- Load core context entries from extension source directory
local core_index_path = source_dir .. "/context/core-index-entries.json"
local core_stat = vim.loop.fs_stat(core_index_path)
if core_stat then
  local ok_core, core_data = pcall(read_json, core_index_path)
  if ok_core and core_data then
    local core_entries = core_data.entries or (vim.isarray(core_data) and core_data) or nil
    if core_entries then
      merge_mod.append_index_entries(index_path, core_entries)
    end
  end
end
```

Key observations:
1. It reads from `source_dir .. "/context/core-index-entries.json"` (the extension source directory, not the deployed directory).
2. The return values of `append_index_entries()` are **discarded** -- no tracking data is stored.
3. This runs BEFORE `process_merge_targets()` on line 502.

### Standard merge_targets Pattern (process_merge_targets lines 103-119)

Other extensions declare in their manifest:
```json
"merge_targets": {
  "index": {
    "source": "index-entries.json",
    "target": ".claude/context/index.json"
  }
}
```

The `process_merge_targets()` function then:
1. Reads the source file from `source_dir .. "/" .. mt_config.source`
2. Calls `merge_mod.append_index_entries(target_path, entries)`
3. Stores the tracking data in `merged_sections.index`

The tracking data (`{ paths = added_paths }`) is persisted via `state_mod.mark_loaded()` into `extensions.json` and used by `reverse_merge_targets()` during unload.

### Current Core State in extensions.json

The core extension currently has `"merged_sections": []` -- an empty array. This confirms that:
- Core's index entries are not tracked for unload.
- The CLAUDE.md merge target for core intentionally skips tracking (handled by computed artifact generation).
- Adding `merge_targets.index` to the core manifest will populate `merged_sections.index` with tracking data.

### File Location Convention

Other extensions store their index entries file at the **extension root**:
- `.claude/extensions/nvim/index-entries.json`
- `.claude/extensions/memory/index-entries.json`
- `.claude/extensions/epidemiology/index-entries.json`

The core extension currently stores it nested:
- `.claude/extensions/core/context/core-index-entries.json`

The `merge_targets.source` path is relative to the extension's source directory, so the file should be moved to match the convention:
- **New location**: `.claude/extensions/core/index-entries.json`
- **New manifest entry**: `"source": "index-entries.json"`

### Orphan Cleanup Safety

The `remove_orphaned_index_entries()` function (merge.lua:470) only removes entries whose path starts with `"project/"`. Core entries use paths like `"architecture/..."`, `"formats/..."`, `"patterns/..."`, etc. -- they are explicitly preserved by the check on line 494: `entry.path:sub(1, 8) ~= "project/"`. This means:

- Core entries survive orphan cleanup regardless of loading mechanism.
- No ordering concern: even if `process_merge_targets` runs after cleanup, core entries won't be erroneously removed.

### Documentation References

Five files reference `core-index-entries.json` and will need documentation updates:
1. `.claude/extensions/core/context/README.md`
2. `.claude/context/README.md`
3. `.claude/docs/architecture/extension-system.md`
4. `.claude/extensions/core/docs/architecture/extension-system.md`
5. `.claude/extensions/README.md`

## Decisions

1. **Rename and relocate the file**: Move from `extensions/core/context/core-index-entries.json` to `extensions/core/index-entries.json` to match the convention used by all other extensions.
2. **Use standard merge_targets mechanism**: Add `"index"` to core's `merge_targets` in manifest.json.
3. **Delete special-case code entirely**: Remove init.lua lines 488-499 and associated comments.
4. **Update documentation**: Fix all five documentation files that reference the old path.

## Recommendations

### Implementation Steps (ordered)

1. **Rename the source file**: `git mv .claude/extensions/core/context/core-index-entries.json .claude/extensions/core/index-entries.json`

2. **Update core manifest.json**: Add the `"index"` merge_target entry:
   ```json
   "merge_targets": {
     "claudemd": { ... },
     "index": {
       "source": "index-entries.json",
       "target": ".claude/context/index.json"
     }
   }
   ```

3. **Remove special-case code in init.lua**: Delete lines 488-499 (the `core_index_path` block) and the preceding comment on line 488.

4. **Update documentation** in all five referenced files to describe the new unified mechanism.

5. **Verify**: Reload core extension and confirm:
   - `extensions.json` core entry now has `merged_sections.index` with tracked paths
   - `.claude/context/index.json` contains all core entries
   - Unload/reload cycle preserves entries correctly

### Estimated Scope

- 3 files changed in the implementation (manifest.json, init.lua, file rename)
- 5 documentation files updated
- Total: ~8 files, small effort

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Core entries lost during reload | Low | High | The orphan cleanup explicitly preserves non-`project/` entries; `append_index_entries` deduplicates |
| Breaking existing installations | Low | Medium | Existing `index.json` already has core entries; reload will re-add any missing ones via deduplication |
| Empty `merged_sections` on existing installs | Low | Low | First reload after update will populate tracking; unload before reload has no data to reverse-remove anyway |
| Documentation drift | Medium | Low | Implementation plan should include all 5 doc files as explicit checklist items |

## Appendix

### Key File Paths
- **Extension loader**: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- **Merge module**: `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- **State module**: `lua/neotex/plugins/ai/shared/extensions/state.lua`
- **Core manifest**: `.claude/extensions/core/manifest.json`
- **Core index entries**: `.claude/extensions/core/context/core-index-entries.json` (current)
- **Extensions state**: `.claude/extensions.json`

### Reference Extension Manifests Examined
- `.claude/extensions/nvim/manifest.json` (has `merge_targets.index`)
- `.claude/extensions/memory/manifest.json` (has `merge_targets.index`)
- `.claude/extensions/epidemiology/manifest.json` (has `merge_targets.index`)
