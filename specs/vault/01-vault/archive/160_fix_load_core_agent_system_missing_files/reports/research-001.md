# Research Report: Task #160

**Task**: 160 - fix_load_core_agent_system_missing_files
**Started**: 2026-03-07T00:00:00Z
**Completed**: 2026-03-07T00:15:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis, picker implementation code
**Artifacts**: - specs/160_fix_load_core_agent_system_missing_files/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The "Load Core Agent System" action uses two DIFFERENT scan implementations: a recursive one for the actual sync operation (correct) and a non-recursive one for the previewer display (buggy)
- The previewer's local `scan_directory_for_sync` in `previewer.lua` (lines 19-40) only scans top-level files, missing all nested files
- The previewer is also missing entire artifact categories: agents, context, and root_files
- The actual sync operation in `sync.lua` (via `scan_all_artifacts`) IS recursive and handles all categories correctly
- The fix requires updating the previewer's `preview_load_all` function to match the sync's `scan_all_artifacts` logic

## Context & Scope

The task asks to fix 9 missing files in the "Load Core Agent System" picker action. Research confirms these files exist in the global directory but the previewer's file count display is inaccurate due to a simpler, non-recursive scan function.

## Findings

### Architecture Overview

The picker system has two relevant operations for "Load Core Agent System":

1. **Preview** (`previewer.lua:preview_load_all`) - Shows file counts when hovering over the entry
2. **Action** (`sync.lua:load_all_globally`) - Actually performs the sync when Enter is pressed

These use DIFFERENT scan implementations, creating a discrepancy.

### Root Cause: Dual Scan Implementations

**Previewer's scan** (`previewer.lua:19-40`):
```lua
local function scan_directory_for_sync(global_dir, project_dir, subdir, extension, base_dir)
  local global_files = vim.fn.glob(global_path .. "/" .. extension, false, true)
  -- Only scans top-level files, NOT recursive
end
```

**Sync's scan** (`scan.lua:53-120` via `sync.lua:166-167`):
```lua
function M.scan_directory_for_sync(global_dir, local_dir, subdir, extension, recursive, ...)
  if recursive == nil then recursive = true end
  -- Scans both **/<pattern> AND /<pattern> with deduplication
end
```

### Missing Categories in Previewer

The previewer `preview_load_all` (lines 195-214) scans these categories:
- commands, hooks, skills (*.md only), templates, lib, docs, scripts, tests, rules, output, systemd, settings

But the actual sync `scan_all_artifacts` (sync.lua:161-263) also handles:
- **agents** - Entire category missing from previewer
- **context** - Entire category missing (*.md recursive + *.json + *.yaml)
- **root_files** - Entire category missing (.gitignore, README.md, CLAUDE.md, settings.local.json)
- **skills *.yaml** - Only *.md is scanned in previewer, not *.yaml

### Impact on the 9 Missing Files

| File | Category | Why Missing in Preview |
|------|----------|----------------------|
| context/core/patterns/early-metadata-pattern.md | context | Context category not scanned in previewer |
| context/core/troubleshooting/workflow-interruptions.md | context | Context category not scanned in previewer |
| context/index.schema.json | context | Context category not scanned in previewer |
| docs/reference/standards/agent-frontmatter-standard.md | docs | Non-recursive scan misses nested files |
| docs/reference/standards/multi-task-creation-standard.md | docs | Non-recursive scan misses nested files |
| docs/templates/agent-template.md | docs | Non-recursive scan misses nested files |
| docs/templates/command-template.md | docs | Non-recursive scan misses nested files |
| scripts/update-plan-status.sh | scripts | These ARE top-level, should be found |
| scripts/validate-context-index.sh | scripts | These ARE top-level, should be found |

Note: The two scripts files ARE at the top level of `.claude/scripts/` and WOULD be found by the non-recursive previewer scan. They would also be synced correctly by the actual sync operation. The task description may have incorrectly identified them as missing, or they may have been added after the task was created.

### Key Files

| File | Role | Lines |
|------|------|-------|
| `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` | Preview display with non-recursive scan | 19-40 (local scan), 189-276 (preview_load_all) |
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | Actual sync with recursive scan | 155-264 (scan_all_artifacts), 270-355 (load_all_globally) |
| `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` | Shared recursive scan utility | 53-120 (scan_directory_for_sync) |
| `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` | Entry creation (line 981-995 for special entry) | N/A |

### Recommendations

**Option A: Reuse sync's scan_all_artifacts in previewer** (Recommended)

Replace the previewer's `preview_load_all` function to call the sync module's `scan_all_artifacts` or the shared `scan.scan_directory_for_sync` instead of its own local non-recursive version. This ensures the preview counts always match what the sync will actually do.

Implementation approach:
1. Remove the local `scan_directory_for_sync` from `previewer.lua` (lines 19-40)
2. Import the sync module: `local sync_ops = require("neotex.plugins.ai.claude.commands.picker.operations.sync")`
3. Either:
   - Export `scan_all_artifacts` from sync.lua and call it in the previewer, OR
   - Use `scan.scan_directory_for_sync` directly in the previewer (with recursive=true)
4. Add missing categories to the previewer display: agents, context, root_files
5. Add skills *.yaml scanning

**Option B: Mirror the sync logic in the previewer**

Update the previewer's local scan function to be recursive and add the missing categories. This keeps the modules independent but requires maintaining two parallel implementations.

**Recommended: Option A** - Single source of truth, no duplication.

### Lazy Loading Considerations

The previewer is loaded on-demand when the picker is opened. Adding an import to the sync module is safe since it's already loaded at picker open time.

## Decisions

- The actual sync operation (`load_all_globally`) appears to work correctly and DOES handle all file types recursively
- The bug is in the **previewer display** showing incorrect/incomplete counts, which may also confuse users about what will be synced
- The fix should make the previewer use the same scan logic as the actual sync

## Risks & Mitigations

- **Risk**: Changing the previewer scan might slow down preview rendering if the recursive scan is slow
  - **Mitigation**: The scan is filesystem glob-based and should be fast; test with large directories
- **Risk**: The sync module's scan_all_artifacts is a local function, not exported
  - **Mitigation**: Either export it or factor the scan logic into the shared scan module

## Context Extension Recommendations

None - this is a straightforward code fix within the existing picker system.

## Appendix

### File Locations (Absolute Paths)
- Previewer: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
- Sync: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Scan utils: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- Entries: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
- Which-key: `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua`
- Shared config: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/picker/config.lua`

### Search Queries Used
- `Load Core Agent System` - grep across nvim directory
- `scan_directory_for_sync` - grep in previewer and scan modules
- `is_load_all|load_all_globally` - grep for action handler
- `leader.*ao` - grep for which-key mapping
