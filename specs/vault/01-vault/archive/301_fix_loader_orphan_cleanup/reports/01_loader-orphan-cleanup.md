# Research Report: Fix Extension Loader Orphaned Index Entry Cleanup

**Task**: 301
**Date**: 2026-03-26
**Status**: Complete

## Problem Statement

The extension loader at `lua/neotex/plugins/ai/shared/extensions/merge.lua` uses append/remove semantics for managing `index.json` entries during extension load/unload cycles. When entries are added or modified by external processes (tasks, manual edits, other automation), they bypass the loader's tracking system. On sparse reload (loading a subset of previously-loaded extensions), the loader removes only its tracked entries and leaves behind orphaned entries from unloaded extensions.

### Observed Symptom

After a sparse reload in the Website project (loading only the `web` extension), 27 lean4 entries and 2 pitch-deck entries remained in the project's `.claude/context/index.json`. These entries belonged to extensions that were no longer loaded but had been added or modified by external processes (tasks 297-300 enriched metadata, task 299 added new entries).

## Source Code Analysis

### Architecture Overview

The extension system consists of five modules:

| Module | File | Purpose |
|--------|------|---------|
| `init.lua` | `shared/extensions/init.lua` (624 lines) | Public API: load, unload, reload, list |
| `merge.lua` | `shared/extensions/merge.lua` (534 lines) | Merge strategies for shared files |
| `loader.lua` | `shared/extensions/loader.lua` (431 lines) | File copy engine |
| `state.lua` | `shared/extensions/state.lua` (239 lines) | State tracking via `extensions.json` |
| `picker.lua` | `shared/extensions/picker.lua` (257 lines) | Telescope-based UI |

### How Index Entries Are Added (`append_index_entries`)

Located at `merge.lua:362-405`:

1. Reads the target `index.json` (or creates `{entries: []}`)
2. For each entry from the extension's `index-entries.json`:
   - Normalizes the path (strips known bad prefixes)
   - Checks for duplicates by comparing `entry.path` against existing entries
   - If no duplicate, appends the entry and records the path in `added_paths`
3. Returns `{paths: added_paths}` as tracking data

### How Index Entries Are Removed (`remove_index_entries_tracked`)

Located at `merge.lua:411-449`:

1. Reads the tracked `{paths: [...]}` from state
2. Creates a set of paths to remove
3. Filters `index.entries` to exclude entries matching tracked paths
4. Writes the filtered index back

### How Tracking Data Is Stored

In `state.lua:122-134`, `mark_loaded()` stores per-extension state in `extensions.json`:

```json
{
  "extensions": {
    "lean": {
      "version": "1.0.0",
      "loaded_at": "...",
      "installed_files": [...],
      "installed_dirs": [...],
      "merged_sections": {
        "index": {
          "paths": ["project/lean4/domain/mathlib-overview.md", ...]
        }
      },
      "data_skeleton_files": [],
      "status": "active"
    }
  }
}
```

### The Root Cause

The tracking data (`merged_sections.index.paths`) is a **snapshot** of paths added at load time. When external processes subsequently:

1. **Add new entries** to `index.json` that belong to an extension's domain (e.g., task 299 adding 75 new entries, some with `project/lean4/` paths)
2. **Modify existing entries** (e.g., tasks 298/300 enriching metadata on entries already tracked)

...the tracking data does not get updated. On unload, `remove_index_entries_tracked()` only removes the originally-tracked paths, leaving behind any entries that were added externally.

### How Extensions Declare Their Domain

Each extension has a `manifest.json` with:
- `name`: Extension identifier (e.g., `"lean"`)
- `language`: Language identifier (e.g., `"lean4"`)
- `provides.context`: Array of context directory paths (e.g., `["project/lean4"]`)
- `merge_targets.index.source`: Path to the extension's `index-entries.json`

The `provides.context` field directly maps to the path prefix used in index entries. For example, the lean extension provides `"project/lean4"`, and all its index entries have paths starting with `project/lean4/`.

### How Sparse Reload Works

There is no dedicated "sparse reload" function. The user interaction is:

1. Open extension picker (`<leader>ac`)
2. Toggle individual extensions on/off (Enter key)
3. Or reload a single extension (Ctrl-r)

A "sparse reload" scenario occurs when:
- Multiple extensions were previously loaded (e.g., lean + web)
- The user unloads some (lean) but keeps others (web)
- Or: the project's `extensions.json` gets reset/deleted, then only some extensions are reloaded

The `reload()` function (init.lua:468-492) simply calls `unload()` then `load()` for a single extension.

### How Extensions.json Tracks State

Located at `{project}/.claude/extensions.json` (or `.opencode/extensions.json`):
- Contains a map of `extension_name -> extension_info`
- When an extension is unloaded, its entry is removed entirely (`mark_unloaded` sets it to nil)
- The `merged_sections.index.paths` array is the only record of which index entries belong to an extension

## Proposed Solutions

### Option A: Path-Prefix-Based Cleanup After Unload

**Approach**: After removing tracked entries during unload, scan remaining entries and remove any whose path starts with a prefix belonging to the unloaded extension (derived from `provides.context`).

**Implementation**:
1. In `init.lua`, after `reverse_merge_targets()` in `manager.unload()`, add a cleanup step
2. Read the extension's `provides.context` from manifest (e.g., `["project/lean4"]`)
3. Scan `index.json` entries and remove any entry whose `path` starts with any of those prefixes
4. Only do this if the extension is being unloaded (not if it's being reloaded, since reload calls unload then load)

**Pros**:
- Directly addresses the root cause
- Uses existing manifest metadata (no new configuration needed)
- Deterministic: the extension "owns" its path prefix
- Fast: simple string prefix match

**Cons**:
- Assumes extensions have exclusive ownership of their path prefixes (generally true by convention)
- If a core entry happens to share a prefix with an extension, it would be incorrectly removed
- Requires manifest access during unload (already available in the code)

**Risk Assessment**: Low. Extension context directories are namespaced under `project/{domain}/` and core entries use different prefixes (`core/`, `meta/`, `patterns/`, etc.). Path collision is unlikely by design.

### Option B: Full Index Rebuild on Each Reload

**Approach**: Instead of append/remove, rebuild `index.json` from scratch: start with core entries, then append only loaded extension entries.

**Implementation**:
1. Maintain a list of "core" entries (entries not belonging to any extension)
2. On any load/unload, read all loaded extensions from state
3. Rebuild index from: core entries + entries from each loaded extension's `index-entries.json`

**Pros**:
- Eliminates orphan problem entirely
- Clean, predictable state after every operation
- No tracking data needed

**Cons**:
- Requires knowing which entries are "core" vs "extension" (no current marker)
- Would need a `core-index.json` or similar to store base entries
- Loses any manual edits to extension entries (metadata enrichment from tasks)
- More disruptive change to existing architecture
- Significantly more complex to implement correctly

**Risk Assessment**: Medium-high. The main risk is losing metadata enrichment. Tasks 298-300 specifically enriched extension entries with domain/subdomain/summary metadata. A full rebuild from source `index-entries.json` files would lose those enrichments unless the source files are also updated.

### Option C: Filesystem Validation on Unload

**Approach**: After all unloads complete, validate remaining index entries against files on disk. Remove any entry whose referenced file doesn't exist in the project's `.claude/context/` directory.

**Implementation**:
1. After `reverse_merge_targets()` in unload, scan remaining index entries
2. For each entry, check if `{project}/.claude/context/{entry.path}` exists on disk
3. Remove entries whose files don't exist

**Pros**:
- Simple and robust
- Doesn't need to know about extension ownership
- Catches all types of orphans, not just extension-related ones

**Cons**:
- Context files from loaded extensions are copied to `{target_dir}/context/` by the loader, so their files DO exist on disk. This approach would only catch entries for files that were deleted but not for files that exist via a different extension
- CRITICAL FLAW: Extension context files are physically present on disk until unloaded. Since unload removes files first, then calls `reverse_merge_targets()`, the files are already gone when we'd check. But entries added by external processes for those same paths would reference files that NO LONGER exist (since the extension's context directory was removed). This partially works but is fragile.
- Doesn't handle entries for extensions whose files were never copied (edge case)
- Slightly slower (filesystem I/O per entry)

**Risk Assessment**: Medium. The timing of file removal vs. entry cleanup creates subtle edge cases. Also fails if the context files are referenced by relative paths that don't correspond to the physical layout.

## Recommendation

**Option A (Path-Prefix-Based Cleanup)** is the recommended approach.

### Rationale

1. **Minimal code change**: Add ~20 lines to `init.lua` unload function and ~15 lines to `merge.lua`
2. **Uses existing metadata**: `provides.context` already declares the path prefixes each extension owns
3. **Correct by design**: Extension entries are namespaced by convention (`project/{domain}/`)
4. **Preserves architecture**: No need for core/extension entry distinction or rebuild logic
5. **Handles the exact problem**: External processes add entries under extension-owned prefixes; prefix-based cleanup catches them

### Suggested Implementation Location

Add a new function `M.remove_index_entries_by_prefix()` to `merge.lua`:

```lua
--- Remove index entries whose path starts with any of the given prefixes
--- @param target_path string Path to index.json
--- @param prefixes table Array of path prefixes to match
--- @return boolean success True if removal succeeded
--- @return number removed_count Number of entries removed
function M.remove_index_entries_by_prefix(target_path, prefixes)
  -- Read index, filter entries, write back
  -- Similar structure to remove_index_entries_tracked
end
```

Then in `init.lua` `manager.unload()`, after `reverse_merge_targets()`:

```lua
-- Clean up orphaned index entries by path prefix
if extension and extension.manifest and extension.manifest.provides
    and extension.manifest.provides.context then
  local mt_config = extension.manifest.merge_targets and extension.manifest.merge_targets.index
  if mt_config then
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.remove_index_entries_by_prefix(target_path, extension.manifest.provides.context)
  end
end
```

### Edge Case Handling

1. **Reload (unload + load)**: The prefix cleanup during unload removes all entries including orphans. The subsequent load re-adds the canonical entries from `index-entries.json`. This is correct behavior.
2. **Shared prefixes**: No two extensions currently share a `provides.context` prefix. If they did, the second extension's entries would be removed when the first is unloaded. This could be mitigated by checking loaded state before removing.
3. **Core entries under project/ prefix**: Core entries use `core/`, `meta/`, `patterns/` prefixes, never `project/{domain}/`. No collision risk.

## Files to Modify

| File | Change |
|------|--------|
| `lua/neotex/plugins/ai/shared/extensions/merge.lua` | Add `remove_index_entries_by_prefix()` function |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Call prefix cleanup after `reverse_merge_targets()` in `unload()` |

## Testing Strategy

1. Load lean + web extensions into a test project
2. Manually add entries with `project/lean4/` prefix to `index.json` (simulating external task)
3. Unload lean extension
4. Verify: no `project/lean4/` entries remain in `index.json`
5. Verify: web entries and core entries are untouched
6. Reload lean extension
7. Verify: canonical lean entries are restored from `index-entries.json`
