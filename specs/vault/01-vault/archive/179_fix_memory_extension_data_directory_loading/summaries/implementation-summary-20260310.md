# Implementation Summary: Task #179

**Completed**: 2026-03-10
**Duration**: 15 minutes

## Changes Made

Fixed two bugs in the memory extension data directory loading:

1. **Base directory parameter**: Changed `copy_data_dirs` call in `init.lua` to use `project_dir` instead of `target_dir`, ensuring data directories are copied to project root rather than inside `.opencode/`.

2. **Directory naming**: Updated manifest `data` field from `"memory"` to `".memory"` and renamed the source directory to match, ensuring the hidden `.memory` vault directory name is used as documented.

## Files Modified

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Line 297: changed `target_dir` to `project_dir` in `copy_data_dirs` call
- `.opencode/extensions/memory/manifest.json` - Line 11: changed data array entry from `"memory"` to `".memory"`
- `.opencode/extensions/memory/data/memory/` - Renamed to `.opencode/extensions/memory/data/.memory/`

## Verification

- Module loads cleanly: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` - passed
- Manifest JSON validates: `jq . manifest.json` - passed
- Source data directory exists at new path: `.opencode/extensions/memory/data/.memory/` - confirmed
- Old source data directory removed: `data/memory/` - confirmed no longer exists

## Notes

- Existing `.opencode/memory/` data from previous (incorrect) loads will remain orphaned; users can manually migrate if needed
- The `.memory` directory is intentionally hidden (dot-prefixed) as documented in EXTENSION.md
