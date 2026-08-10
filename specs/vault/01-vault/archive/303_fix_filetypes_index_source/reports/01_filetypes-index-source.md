# Research: Fix Filetypes Extension Source index-entries.json

**Task**: 303
**Date**: 2026-03-26
**Status**: Complete

## Problem Statement

Task 297 removed 2 duplicate pitch-deck entries from the output `index.json`, but the concern was that the SOURCE file at `.claude/extensions/filetypes/index-entries.json` still contained them, causing every reload to re-add the duplicates.

## Findings

### Source File: filetypes/index-entries.json

The filetypes extension source (`/home/benjamin/.config/nvim/.claude/extensions/filetypes/index-entries.json`) contains **7 entries**, none of which reference pitch-deck files:

1. `project/filetypes/tools/tool-detection.md`
2. `project/filetypes/tools/dependency-guide.md`
3. `project/filetypes/tools/mcp-integration.md`
4. `project/filetypes/patterns/spreadsheet-tables.md`
5. `project/filetypes/patterns/presentation-slides.md`
6. `project/filetypes/domain/conversion-tables.md`
7. `project/filetypes/README.md`

**Result**: The source file is already clean. No pitch-deck entries exist here.

### Source File: present/index-entries.json

The present extension source (`/home/benjamin/.config/nvim/.claude/extensions/present/index-entries.json`) correctly contains 2 pitch-deck entries:

- `project/present/patterns/pitch-deck-structure.md` (line_count: 180, deck-agent)
- `project/present/patterns/touying-pitch-deck-template.md` (line_count: 250, deck-agent)

These are the canonical, correctly-located entries with rich metadata (topics, keywords, languages, commands).

### Output File: .claude/context/index.json

The merged output `index.json` still contains **2 orphaned entries** under the wrong path prefix:

- `project/filetypes/patterns/pitch-deck-structure.md` (subdomain: filetypes, deck-agent)
- `project/filetypes/patterns/touying-pitch-deck-template.md` (subdomain: filetypes, deck-agent)

These are NOT sourced from `filetypes/index-entries.json`. They were likely added directly to `index.json` by metadata enrichment tasks (298-300) or persisted after a reload that didn't clean them properly.

The correct `project/present/patterns/` entries are NOT currently in the output `index.json`, suggesting the present extension is not loaded.

## Root Cause

The original hypothesis (source file contains duplicates) is **incorrect**. The filetypes source is clean. The orphaned entries in `index.json` persist because:

1. They were added to `index.json` directly (not via extension loading)
2. The extension loader doesn't clean entries that weren't added during the current session (task 301 addresses this root cause)
3. Task 297 may have removed them, but a subsequent reload or metadata task re-introduced them

## Recommendation

**No changes needed to `filetypes/index-entries.json`** -- it is already clean.

The 2 orphaned `project/filetypes/patterns/pitch-deck-*` entries in the output `index.json` should be removed as part of task 302 (clean orphaned index entries from Website index.json), which already identifies these among 26 orphaned entries to remove.

This task can be marked as researched with no implementation needed -- the source file problem described does not exist. The output file problem is covered by task 302.

## Effort Estimate

~10 minutes (research only, no implementation needed)
