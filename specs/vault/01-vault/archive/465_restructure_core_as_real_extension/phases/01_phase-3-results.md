# Phase 3 Results: Manifest and Virtual Flag Removal

**Status**: COMPLETED
**Date**: 2026-04-16

## Changes Made

### 1. `.claude/extensions/core/manifest.json`
- Removed `"virtual": true` field
- Updated description from virtual-oriented to real-extension description
- Added `merge_targets.claudemd` with fields:
  - `source`: `"merge-sources/claudemd.md"`
  - `target`: `".claude/CLAUDE.md"`
  - `section_id`: `"core"`
- Note: Phase 2 also added `docs` and `templates` to `provides` during parallel execution

### 2. `lua/neotex/plugins/ai/shared/extensions/init.lua` - Load function
- Removed virtual fast-path block (lines ~357-373 in original):
  ```lua
  if ext_manifest.virtual then ... return true, nil end
  ```
  Now all extensions including core go through the full file copy/merge path.

### 3. `lua/neotex/plugins/ai/shared/extensions/init.lua` - Unload function
- Removed virtual fast-path block (lines ~541-563 in original):
  ```lua
  if extension and extension.manifest and extension.manifest.virtual then ... end
  ```
- Replaced soft dependent warning with **hard block**: when any loaded extension depends on the
  extension being unloaded, `unload()` now returns an error and does not proceed. This applies
  universally (not just to core) and prevents orphaned dependent extensions.
- Removed the now-unused `dep_warning` variable from the confirmation dialog format string.

### 4. `lua/neotex/plugins/ai/shared/extensions/init.lua` - `get_details()`
- Removed `virtual = extension.manifest.virtual or false` field from returned details table.
  This field no longer exists on any manifest.

### 5. `lua/neotex/plugins/ai/shared/extensions/picker.lua`
- Removed the virtual-extension filter in `picker_mod.show()`:
  ```lua
  -- OLD: filtered out extensions where details.virtual == true
  -- NEW: shows all available extensions including core
  local available = extensions_module.list_available()
  ```
  Core now appears in the picker as a normal extension.

## Verification

- `grep -rn "virtual" lua/neotex/plugins/ai/shared/extensions/` returns zero hits
- `manifest.json` has no `virtual` field and has `merge_targets.claudemd`
- Load path: no virtual short-circuit; core will go through full file copy (Phase 2 must
  complete before core can actually be loaded, as source files are being migrated there)
- Unload protection: hard block when dependents are loaded (returns error, not just warning)
- Picker: core visible as a real extension alongside others

## Notes

- Phase 2 (Physical File Migration) is running in parallel and modifies different files
- The `merge-sources/claudemd.md` source file referenced in `merge_targets.claudemd` will
  need to be created as part of Phase 5 (Computed CLAUDE.md Generation)
- The hard block on unloading with dependents loaded is a behavior improvement over the old
  warning-only approach that applied to all extensions (not just core)
