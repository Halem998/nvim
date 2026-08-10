# Implementation Summary: Convert core-index-entries to merge_targets

- **Task**: 466 - Convert core-index-entries.json from static fixture to standard merge_targets
- **Status**: [COMPLETED]
- **Started**: 2026-04-16T20:00:00Z
- **Completed**: 2026-04-16T20:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: 465 (completed)
- **Artifacts**: plans/01_convert-merge-targets.md
- **Standards**: status-markers.md, artifact-formats.md, summary-format.md

## Overview

Converted the core extension's index entry loading from a 12-line special-case code block in init.lua to the standard `merge_targets.index` mechanism used by all other extensions. This eliminates the last piece of core-specific special-casing in the extension loader.

## What Changed

- Relocated `extensions/core/context/core-index-entries.json` to `extensions/core/index-entries.json` (matching convention used by nvim, memory, and other extensions)
- Added `merge_targets.index` entry to core `manifest.json` pointing to `index-entries.json`
- Removed the `core_index_path` special-case block (lines 488-499) from `init.lua`
- Removed stale `core-index-entries.json` from `provides.context` array in manifest.json
- Updated 5 documentation files to reflect the new loading mechanism

## Decisions

- Kept the file content unchanged -- only the location and loading mechanism changed
- Removed the `core-index-entries.json` entry from `provides.context` since the file no longer lives under `context/`
- Left historical references in specs/ task artifacts untouched (they are archival)

## Impacts

- Core index entries now flow through `process_merge_targets()` like all other extensions
- The `merged_sections.index` tracking in `extensions.json` will now include core entries after next reload
- No functional change to what entries appear in `index.json` -- same entries, different loading path

## Follow-ups

- Reload the core extension in the editor to verify entries are properly tracked in `extensions.json`
- Task 470 (fix loader root-level context files) may interact with this change if it touches index loading

## References

- specs/466_convert_core_index_entries/plans/01_convert-merge-targets.md
- specs/466_convert_core_index_entries/reports/01_convert-merge-targets.md
