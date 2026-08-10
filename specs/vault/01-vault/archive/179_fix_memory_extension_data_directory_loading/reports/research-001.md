# Memory Extension Data Directory Loading Issue - Research Report

**Task**: 179 - Fix memory extension data directory loading  
**Date**: 2026-03-10  
**Status**: Research Complete  
**Language**: neovim (Lua)  

## Problem Summary

When loading the memory extension via the `<leader>ao` picker, the data directory is being placed at `.opencode/memory/` (or `.claude/memory/`) instead of the project root at `.memory/`. Additionally, if a `.memory/` directory already exists, the extension should not overwrite user data.

## Root Cause Analysis

### Extension Loading Code Location

File: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`

Line 297:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, target_dir)
```

**Bug**: The function is called with `target_dir` instead of `project_dir`.

### Variable Definitions

Line 187:
```lua
local target_dir = project_dir .. "/" .. config.base_dir  -- Results in: ./.opencode/
```

Line 186:
```lua
local project_dir = opts.project_dir or vim.fn.getcwd()  -- Results in: ./ (project root)
```

### Loader Function Expectation

File: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua`

Lines 269-285:
```lua
function M.copy_data_dirs(manifest, source_dir, project_dir)
  ...
  for _, data_name in ipairs(manifest.provides.data) do
    local source_data_path = source_data_dir .. "/" .. data_name
    local target_data_path = project_dir .. "/" .. data_name  -- Expects project_dir
```

The `copy_data_dirs` function correctly expects `project_dir` (the project root), but it's receiving `target_dir` (the agent system directory like `.opencode/` or `.claude/`).

### Current Behavior

With `target_dir` = `./.opencode/` and `data_name` = `memory`:
- Data is copied to: `./.opencode/memory/`

### Expected Behavior

With `project_dir` = `./` and `data_name` = `memory`:
- Data should be copied to: `./.memory/`

## The Fix

### Primary Fix: Change Function Call

**File**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`

**Line 297** - Change from:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, target_dir)
```

To:
```lua
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, project_dir)
```

### Verification: Merge-Copy Semantics Already Implemented

The `copy_data_dirs` function already implements merge-copy semantics (lines 294-316 in loader.lua):

```lua
-- Only copy if target file doesn't already exist (preserve user data)
if vim.fn.filereadable(target_path) ~= 1 then
  -- ... copy file
end
```

This means:
- If `.memory/` already exists with user data, skeleton files won't overwrite existing files
- New files from the extension skeleton will be added
- Existing user files are preserved
- Only skeleton files are tracked for removal during unload

## Impact Assessment

### Files Affected

1. **`/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`**
   - Line 297: Change parameter from `target_dir` to `project_dir`

### Extension Manifest

File: `/home/benjamin/.config/nvim/.opencode/extensions/memory/manifest.json`

The manifest correctly specifies:
```json
"provides": {
  "data": ["memory"]
}
```

No changes needed to the manifest.

### Documentation References

All memory extension documentation correctly references `.memory/` as the target location:

- `EXTENSION.md` line 49: `.memory/`
- `data/memory/README.md` lines 12, 49: `.memory/`
- `context/project/memory/memory-setup.md` lines 8, 17: `.memory/`
- `context/project/memory/learn-usage.md` lines 55, 118: `.memory/`
- `context/project/memory/memory-troubleshooting.md` lines 16, 71: `.memory/`
- `skills/skill-memory/SKILL.md` lines 16, 17, 56, 81, 141, 185, 305, 384: `.memory/`
- `commands/learn.md` lines 158, 159, 163, 164: `.memory/`

## Testing Verification

After the fix:

1. **Load extension in a test project**:
   ```
   <leader>ao → select memory → Load
   ```

2. **Verify data location**:
   ```bash
   ls -la .memory/          # Should exist with vault structure
   ls -la .opencode/memory/  # Should NOT exist
   ```

3. **Verify merge-copy with existing data**:
   ```bash
   mkdir -p .memory/10-Memories
   echo "test memory" > .memory/10-Memories/test.md
   # Reload extension - test.md should still exist
   ```

4. **Verify skeleton-only unload**:
   ```bash
   # After unload
   ls -la .memory/  # User files preserved, skeleton files removed
   ```

## Related Tasks

- Task 174: Study opencode memory extension (completed)
- Task 175: Port memory extension to claude (researched)
- Task 176: Port Vision memory system changes to neovim (implementing)
- Task 178: Fix memory extension MCP port (implementing)

## Implementation Notes

This is a **one-line fix** with high impact. The change is minimal but critical for correct memory extension behavior.

### Risk Assessment

**Low risk**: 
- Single parameter change
- Function already designed to handle `project_dir`
- Merge-copy semantics already tested
- No breaking changes to existing loaded extensions (they'll just create data in the wrong place until reloaded)

### Rollback Plan

If issues occur, simply revert line 297 back to `target_dir`.

---

**Next Step**: Create implementation plan (1 phase: change line 297 in init.lua)
