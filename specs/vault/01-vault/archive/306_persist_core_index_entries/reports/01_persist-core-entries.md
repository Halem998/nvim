# Research Report: Persist Core Context Index Entries Across Reloads

**Task**: 306
**Date**: 2026-03-26
**Status**: Complete

## Problem Statement

Task 299 added ~75 core context entries (domain="core") to the Website OUTPUT project's `.claude/context/index.json`. These entries cover orchestration, standards, patterns, formats, templates, and other base agent system files. However, the extension loader rebuilds `index.json` during reload operations, and core entries are not sourced from any extension's `index-entries.json` -- so they get discarded.

## Loader Architecture Analysis

### How index.json is rebuilt

The extension loader (`lua/neotex/plugins/ai/shared/extensions/`) manages index.json through two key functions:

1. **`merge.append_index_entries(target_path, entries)`** (merge.lua:362-405)
   - Called during `process_merge_targets()` in init.lua
   - Reads existing index.json (or creates `{entries: []}`)
   - Appends new entries, deduplicating by path
   - Normalizes paths (strips extension prefixes)
   - Returns tracking data `{paths: [...]}` for later removal

2. **`merge.remove_index_entries_tracked(target_path, tracked)`** (merge.lua:411-449)
   - Called during `reverse_merge_targets()` on unload
   - Removes only the paths recorded in tracking data
   - This is the root issue: only entries the loader itself added are tracked

### Load/unload/reload flow (init.lua)

- **Load**: For each extension, reads `merge_targets.index.source` (the extension's `index-entries.json`), calls `append_index_entries`, stores tracked paths in extension state
- **Unload**: Reads tracked paths from state, calls `remove_index_entries_tracked` for those paths only
- **Reload**: Unload then load (init.lua:468-492)

### What sources feed into index.json

Each extension declares in its `manifest.json`:
```json
"merge_targets": {
  "index": {
    "source": "index-entries.json",
    "target": ".claude/context/index.json"
  }
}
```

The loader reads `index-entries.json` from the extension's directory and appends entries to the target project's index.json. Format:
```json
{
  "entries": [
    {
      "path": "project/neovim/README.md",
      "domain": "project",
      "subdomain": "neovim",
      ...
    }
  ]
}
```

**There is no "core" or "base" index-entries.json.** Only extension-provided entries survive reload.

### Existing base/core index files

Checked both locations -- neither exists:
- `.claude/context/index-entries.json` -- does not exist
- `.claude/index-entries.json` -- does not exist

The source repository's `.claude/context/index.json` has 22 core entries and 54 project entries (76 total). These are the source-of-truth entries but they are not consumed by the loader's merge pipeline.

## Current State of Core Entries

The source repository (this repo) has ~90 non-project `.md` files under `.claude/context/`:
- `architecture/` (4 files)
- `checkpoints/` (4 files)
- `formats/` (11 files)
- `guides/` (1 file)
- `meta/` (6 files)
- `orchestration/` (11 files)
- `patterns/` (14 files)
- `processes/` (3 files)
- `reference/` (5 files)
- `repo/` (3 files)
- `routing.md` (1 file)
- `standards/` (13 files)
- `templates/` (6 files)
- `troubleshooting/` (1 file)
- `validation.md` (1 file)
- `workflows/` (5 files)
- `README.md` (1 file)

Only 22 of these are currently indexed in the source index.json. Task 299 indexed 75 of these in the Website OUTPUT, but those entries will be lost on next extension reload.

## Proposed Solutions

### Option A: Create `core-index-entries.json` (Recommended)

Create a `.claude/context/core-index-entries.json` file containing all core entries. Modify the loader to always include this file during index.json rebuild, treating it the same as extension `index-entries.json` files.

**Loader change**: In `process_merge_targets()` (init.lua), before processing extension index entries, check for and load `{target_dir}/context/core-index-entries.json`. Call `append_index_entries()` with these entries first.

**Advantages**:
- Minimal loader change (~10 lines)
- Core entries maintained in a single file, easy to audit
- Same format as extension `index-entries.json` (no new schema)
- Entries survive reload because they're always re-applied
- Does not require modifying any extension manifests

**Disadvantages**:
- Requires maintaining the core-index-entries.json file manually when adding new core context files

### Option B: Auto-scan `.claude/context/` for .md files

Modify the loader to scan the context directory for `.md` files not under `project/` and auto-generate index entries for them.

**Advantages**:
- Zero maintenance -- new files are automatically indexed
- No separate entries file to maintain

**Disadvantages**:
- Cannot set per-file metadata (summaries, keywords, load_when, topics)
- Auto-generated entries would have empty/default metadata
- Significant loader change (directory scanning, path resolution)
- Breaks the principle that index entries are curated, not discovered

### Option C: Split index.json into base + overlay

Keep a `base-index.json` that is never overwritten. The loader only manages an overlay section or a separate `extension-index.json`.

**Advantages**:
- Clean separation of concerns
- Base entries never at risk

**Disadvantages**:
- Major architectural change to how index.json works
- All context discovery queries would need to merge two sources
- Breaks existing jq query patterns that read `.entries[]` from one file

## Recommendation

**Option A** is the simplest and most natural fit. It:
1. Requires ~10 lines of loader code change
2. Uses the existing `append_index_entries` API (already handles deduplication)
3. Keeps the single `index.json` as the query target (no consumer changes)
4. The `core-index-entries.json` file is maintained alongside existing context files

### Implementation sketch

In `process_merge_targets()` or a new function called before it:

```lua
-- Load core index entries (always present, not extension-specific)
local core_entries_path = target_dir .. "/context/core-index-entries.json"
if vim.fn.filereadable(core_entries_path) == 1 then
  local entries_data = read_json(core_entries_path)
  if entries_data then
    local entries = entries_data.entries or (vim.isarray(entries_data) and entries_data) or nil
    if entries then
      merge_mod.append_index_entries(target_dir .. "/context/index.json", entries)
    end
  end
end
```

The `core-index-entries.json` would be synced to target projects alongside other `.claude/context/` files (it's a core file, not an extension file).

### Core files needing persistent entries

All ~90 `.md` files under `.claude/context/` that are not under `project/` need entries. The 22 already in the source index.json can serve as the starting point, with the remaining ~68 needing entries created (task 299 already created these for the Website project -- those entries should be extracted and placed into `core-index-entries.json`).

## Effort Estimate

- **Option A implementation**: 2-3 hours
  - Create `core-index-entries.json` with ~90 entries: 1 hour (extract from Website's index.json or generate)
  - Modify loader to load core entries: 30 minutes
  - Test load/unload/reload cycle: 30-60 minutes

## Dependencies

- **Task 301** (loader orphan cleanup): Should understand loader behavior first. The core entries fix should be compatible with whatever orphan cleanup approach task 301 takes, since core entries would be re-applied on every load cycle.
- **Task 299** (completed): The entries created by this task are the ones that need to be persisted. Can extract the core entries from the Website project's current index.json.
