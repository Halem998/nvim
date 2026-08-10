# Implementation Plan: Persist Core Context Index Entries

**Task**: 306
**Date**: 2026-03-26
**Status**: Ready

## Overview

Create `core-index-entries.json` with entries for all ~90 core context `.md` files and modify the extension loader to always include them during index.json rebuilds.

## Phase 1: Create core-index-entries.json [NOT STARTED]

**Files**: `.claude/context/core-index-entries.json` (new)

### Steps
1. Enumerate all `.md` files under `.claude/context/` excluding `project/` subdirectory
2. For each file, create an index entry with:
   - `path`: relative path from `.claude/context/` (e.g., `orchestration/routing.md`)
   - `domain`: `"core"`
   - `subdomain`: directory name (e.g., `"orchestration"`, `"standards"`) or `"root"` for top-level files
   - `summary`: `null` (to be populated later)
   - `line_count`: actual line count from disk
   - `keywords`: `[]`
   - `topics`: `[]`
   - `load_when`: `{ "agents": [], "languages": [], "commands": [] }`
3. Write to `.claude/context/core-index-entries.json` with `{ "entries": [...] }` format
4. Validate: confirm valid JSON and correct entry count

### Verification
- `jq '.entries | length' core-index-entries.json` matches file count
- `jq -e '.' core-index-entries.json` succeeds (valid JSON)

## Phase 2: Update loader to include core entries [NOT STARTED]

**Files**: `lua/neotex/plugins/ai/shared/extensions/init.lua`

### Steps
1. In `manager.load()`, before the `process_merge_targets()` call (line ~349), add code to load core entries
2. The code should:
   - Construct path to `core-index-entries.json` in the target project's `.claude/context/` directory
   - Check if the file exists with `vim.loop.fs_stat()`
   - Read and parse it with `read_json()` (already available as local function)
   - Extract the entries array
   - Call `merge_mod.append_index_entries()` with the target index.json path and entries
3. Use pcall for safety -- failure to load core entries should not block extension loading

### Code Location
Insert before `merged_sections = process_merge_targets(...)` inside the pcall block in `manager.load()`.

### Verification
- Extension load still works
- Core entries appear in target index.json after load
- Core entries survive extension reload cycle

## Risks

- **Low**: `append_index_entries` already handles deduplication, so multiple loads won't create duplicates
- **Low**: Core entries loaded before extensions means extension entries take precedence (desired behavior)

## Effort Estimate

- Phase 1: 30 minutes (generate JSON file)
- Phase 2: 15 minutes (add ~10 lines to loader)
- Total: ~45 minutes
