# Memory Extension Data Directory Loading Issue - Research Report v2

**Task**: 179 - Fix memory extension data directory loading
**Date**: 2026-03-10 (Revised)
**Status**: Research Complete
**Language**: neovim (Lua)

## Problem Summary

When loading the memory extension via the `<leader>ao` picker, the data directory has two issues:
1. Data is placed at `.opencode/memory/` instead of project root
2. The resulting directory is named `memory/` instead of `.memory/` (per documentation)

## Root Cause Analysis

### Bug 1: Wrong Base Directory (Original Finding)

**File**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`

Line 297:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, target_dir)
```

**Issue**: Function called with `target_dir` (e.g., `.opencode/`) instead of `project_dir` (project root).

**Current behavior**: Data copied to `.opencode/memory/`
**Expected behavior**: Data copied to project root

### Bug 2: Missing Dot Prefix (NEW Finding)

**File**: `/home/benjamin/.config/nvim/.opencode/extensions/memory/manifest.json`

Line 11:
```json
"data": ["memory"],
```

**Issue**: The manifest specifies `"memory"` but all documentation references `.memory/` (with dot prefix).

**Evidence**:
- `EXTENSION.md` line 49: `.memory/`
- `data/memory/README.md` line 12: `.memory/`
- All context files and skill documentation: `.memory/`

**Loader behavior** (loader.lua:285):
```lua
local target_data_path = project_dir .. "/" .. data_name
```

With `data_name = "memory"`, this creates `./memory/`, NOT `./.memory/`.

## Complete Fix

### Fix 1: Update Function Call (1 line)

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`

**Line 297** - Change from:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, target_dir)
```

To:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, project_dir)
```

### Fix 2: Update Manifest and Source Directory

**File 1**: `.opencode/extensions/memory/manifest.json`

**Line 11** - Change from:
```json
"data": ["memory"],
```

To:
```json
"data": [".memory"],
```

**File 2**: Rename source directory
```bash
mv .opencode/extensions/memory/data/memory .opencode/extensions/memory/data/.memory
```

## Verification

### Existing Safeguards (No Changes Needed)

1. **Merge-copy semantics**: Already implemented in `loader.lua:294-316`. Existing user files are preserved.

2. **check_conflicts**: Correctly passes `project_dir` for data directory conflict detection (init.lua:205).

3. **Unload behavior**: Correctly reconstructs paths using `project_dir` (init.lua:394-396). Only skeleton files are removed, user data preserved.

### Post-Fix Test Plan

1. **Verify data location**:
   ```bash
   # Load extension
   <leader>ao → select memory → Load

   # Check
   ls -la .memory/          # Should exist with vault structure
   ls -la .opencode/memory/  # Should NOT exist
   ```

2. **Verify merge-copy**:
   ```bash
   mkdir -p .memory/10-Memories
   echo "test memory" > .memory/10-Memories/test.md
   # Reload extension - test.md should still exist
   ```

3. **Verify unload**:
   ```bash
   <leader>ao → select memory → Unload
   ls -la .memory/  # User files preserved, skeleton files removed
   ```

## Impact Assessment

### Files to Modify

| File | Change |
|------|--------|
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Line 297: `target_dir` → `project_dir` |
| `.opencode/extensions/memory/manifest.json` | Line 11: `"memory"` → `".memory"` |
| `.opencode/extensions/memory/data/memory/` | Rename to `data/.memory/` |

### Risk Assessment

**Low risk**:
- Single parameter change in init.lua
- Manifest update is simple
- Directory rename is straightforward
- No breaking changes to loader logic
- Existing loaded extensions will continue to work (data in wrong place until reloaded)

### Rollback Plan

1. Revert init.lua line 297 to `target_dir`
2. Revert manifest to `"memory"`
3. Rename `data/.memory/` back to `data/memory/`

## Related Tasks

- Task 174: Study opencode memory extension (completed)
- Task 175: Port memory extension to claude (researched)
- Task 176: Port Vision memory system changes to neovim (implementing)
- Task 178: Fix memory extension MCP port (implementing)

---

**Next Step**: Create implementation plan (2 phases: code fix + naming fix)
