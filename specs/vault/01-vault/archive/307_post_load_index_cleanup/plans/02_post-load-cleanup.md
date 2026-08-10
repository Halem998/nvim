# Implementation Plan: Post-Load Index Cleanup

**Task**: 307 - Add post-load index cleanup to extension loader
**Date**: 2026-03-26
**Status**: Planned

## Overview

Add a post-load filter to remove orphaned index entries from non-loaded extensions. This complements task 301's unload-time cleanup by catching orphans from sparse reloads where `manager.unload()` is never called.

## Phase 1: Add `remove_orphaned_index_entries()` to merge.lua [NOT STARTED]

**File**: `lua/neotex/plugins/ai/shared/extensions/merge.lua`
**Location**: After `remove_index_entries_by_prefix()` (after line 510)

Add a new function that filters index.json entries, keeping:
- Core entries (path does NOT start with `project/`)
- Extension entries whose path starts with a valid prefix from loaded extensions

Parameters:
- `index_path` (string) - Path to index.json
- `valid_prefixes` (table) - Array of path prefixes from loaded extensions' `provides.context`

Returns:
- `success` (boolean) - Whether cleanup succeeded
- `removed_count` (number) - Number of entries removed

Uses pcall for safety, backs up index.json before modification.

## Phase 2: Integrate into manager.load() in init.lua [NOT STARTED]

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`
**Location**: After state is written (after line 378), before the notification

Add a `cleanup_orphaned_entries()` local function that:
1. Reads extensions.json via `state_mod.read()` to get all loaded extension names
2. For each loaded extension, reads its manifest via `manifest_mod.get_extension()`
3. Extracts `provides.context` prefixes from each manifest
4. Calls `merge_mod.remove_orphaned_index_entries()` with collected prefixes
5. Logs removal count at DEBUG level

Call this function after state is written, wrapped in pcall so failures are non-fatal.

## Verification

- Lua syntax check via `luacheck` or `nvim --headless` load test
- No existing tests to break (extension loader is manually tested)
