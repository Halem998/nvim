# Implementation Summary: opencode.json Agent Registration Gaps

**Task**: 542 - implement_opencode_json_agent_registration
**Status**: COMPLETED
**Date**: 2026-05-07

## Overview

Closed four implementation gaps in the automatic opencode.json agent registration system and updated the base template to include all 7 core agents.

## Phases Completed

### Phase 1: Wire Cleanup to Automatic Triggers [COMPLETED]
- **`lua/neotex/plugins/ai/opencode.lua`**: Added `pcall`-wrapped call to `manager.cleanup_stale_opencode_agents()` in `config()` after server setup. This runs on Neovim startup.
- **`lua/neotex/plugins/ai/shared/extensions/init.lua`** `manager.load()`: Added `pcall`-wrapped cleanup call after successful load, replacing the TODO(541) comment.
- **`lua/neotex/plugins/ai/shared/extensions/init.lua`** `manager.unload()`: Added `pcall`-wrapped cleanup call after successful unload, replacing the TODO(541) comment.
- Removed TODO(541) docstring from `cleanup_stale_opencode_agents()` function definition.

### Phase 2: Implement Conflict Detection in merge_opencode_agents [COMPLETED]
- **`lua/neotex/plugins/ai/shared/extensions/merge.lua`**: Added `extension_name` parameter to `M.merge_opencode_agents()`.
- Implemented conflict detection before silent skip: reads `extensions.json`, iterates loaded extensions' `merged_sections.opencode_json.keys`, and emits a `vim.notify` warning if the conflicting key is owned by a different extension.
- User-added agents (no owner in state) are silently skipped without warning.
- Removed TODO(541) comment from merge.lua.
- Updated call site in `init.lua` `process_merge_targets()` to pass `ext_manifest.name or "unknown"`.
- Updated call site in `sync.lua` `reinject_loaded_extensions()` to pass `ext_manifest.name or "unknown"`.

### Phase 3: Add verify_opencode_json_merge to verify.lua [COMPLETED]
- **`lua/neotex/plugins/ai/shared/extensions/verify.lua`**: Added `verify_opencode_json_merge()` helper function that:
  - Reads `opencode-agents.json` from the extension directory
  - Extracts agent names from both fragment and `manifest.provides.agents`
  - Computes symmetric difference (missing in either direction)
  - Returns `{passed = true}` or mismatch details
- Called in `M.verify_extension()` after the index merge check.
- Mismatches append to `verification.errors` and set `verification.opencode_json.passed = false`, but do NOT change `verification.status` to `failed` (only downgrades to `warnings`).
- Removed TODO(541) comment from verify.lua.

### Phase 4: Respect Managed Sidecar in Sync [COMPLETED]
- **`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`** `collect_sync_artifacts()`:
  - Updated `opencode.json` action determination:
    - Local file does not exist -> `action = "copy"`
    - Local file exists and `.managed` sidecar readable -> `action = "replace"`
    - Local file exists and no `.managed` sidecar -> `action = "skip"`
- `sync_files()`: Added defensive guard that forces `continue` (skip) for `opencode.json` if the local file exists but has no `.managed` sidecar, regardless of what `collect_sync_artifacts` decided.
- Removed TODO(541) comment from sync.lua.
- Updated NOTE(541) comment to remove design spec reference and rephrase as a general note about post-sync re-injection.

### Phase 5: Update Base Template [COMPLETED]
- **`.opencode/templates/opencode.json`**: Added `reviser` and `spawn` agent definitions matching the core extension fragment and plan specifications.
- Validated updated template JSON with `python3 -m json.tool`.

## Files Modified

- `lua/neotex/plugins/ai/opencode.lua`
- `lua/neotex/plugins/ai/shared/extensions/init.lua`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- `.opencode/templates/opencode.json`

## Validation

- JSON template validated successfully.
- No remaining TODO(541) comments in modified Lua files.
- All call sites updated to pass the new `extension_name` parameter.
- Conflict detection, verification, and managed sidecar logic are all non-blocking (warn/skip, never fail).

## Non-Goals Honored

- Merge/unmerge algorithm and tracking format unchanged.
- No runtime enforcement of agent-name registry document.
- No new merge target types beyond `opencode_json`.
- No changes to `{file:...}` reference resolution at CLI startup.
