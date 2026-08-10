# Implementation Summary: Task #464

- **Task**: 464 - Enable extension loading in global source repository without sync leakage
- **Status**: [COMPLETED]
- **Started**: 2026-04-16T00:00:00Z
- **Completed**: 2026-04-16T01:00:00Z
- **Effort**: 3 hours
- **Dependencies**: None
- **Artifacts**: plans/02_enable-extensions-source.md, summaries/02_enable-extensions-source-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Enabled safe extension loading in the global source repository (~/.config/nvim) by closing three sync leak vectors, creating a virtual core manifest, relaxing the self-loading guard, and switching sync from blocklist to allow-list filtering. All 15 non-core extensions now declare a dependency on core, formalizing the dependency graph.

## What Changed

- Added `strip_extension_sections()` and `strip_extension_settings()` to sync.lua to strip extension-injected content from source files before syncing to target repos
- Added blocklist filtering to `update_artifact_from_global()` to block Ctrl-l updates of extension-provided artifacts
- Created `.claude/extensions/core/manifest.json` with `"virtual": true` listing all core agent system files
- Added virtual extension handling to `manager.load()` (skip file copy) and `manager.unload()` (skip file removal)
- Hidden virtual extensions from the picker UI
- Replaced hard self-loading guard with WARN-level notification; removed `opts.force` bypass
- Used configured `global_extensions_dir` instead of hardcoded path for source repo detection
- Added `get_core_provides()` and `build_allow_list()` to manifest.lua for allow-list sync
- Modified `scan_all_artifacts()` to post-filter using allow-list with blocklist fallback
- Added `"core"` to all 15 non-core extension manifest dependency arrays

## Decisions

- Virtual core manifest describes files in-place rather than moving them, avoiding the 175+ file migration cost
- Allow-list uses post-filtering (scan then filter) rather than pre-filtering, keeping the scan module interface unchanged
- Context directory allow-list uses prefix matching on top-level subdirectory names
- The `strip_extension_settings()` reads extensions.json from source to identify merged keys
- Virtual extensions are completely hidden from the picker (filtered via `get_details().virtual`)

## Impacts

- Extensions can now be loaded in ~/.config/nvim without `force=true`
- Sync operations are protected by both stripping (source-side) and allow-list (file selection)
- Loading any extension auto-loads core first via dependency resolution
- The doc-lint script (`check-extension-docs.sh`) reports expected failures for the virtual core extension (no README/EXTENSION.md, files not inside extensions/core/)

## Follow-ups

- Consider updating `check-extension-docs.sh` to skip virtual extensions
- Consider adding a README to `extensions/core/` explaining the virtual manifest concept
- Future: extension hot-reload can now be developed since extensions load in source repo

## References

- `specs/464_enable_extensions_in_source_repo/reports/01_team-research.md`
- `specs/464_enable_extensions_in_source_repo/reports/02_team-research.md`
- `specs/464_enable_extensions_in_source_repo/plans/02_enable-extensions-source.md`
