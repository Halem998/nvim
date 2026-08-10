# Implementation Summary: Convert opencode.json to Computed-Artifact Pattern

- **Task**: 543 - convert_opencode_json_to_computed_artifact
- **Status**: [COMPLETED]
- **Started**: 2026-05-07T18:45:00Z
- **Completed**: 2026-05-07T19:30:00Z
- **Artifacts**: plans/01_convert-opencode-json-computed-artifact.md

## Overview

Replaced the merge-target approach for `opencode.json` with a computed-artifact regeneration pipeline, mirroring the existing `generate_claudemd()` pattern. The previous per-extension merge/unmerge logic was complex, suffered from an agent-orphaning edge case, and required stale-agent cleanup. The new approach rebuilds `opencode.json` from scratch on every load/unload cycle by aggregating agent fragments from all loaded extensions over the base template.

## What Changed

- **`lua/neotex/plugins/ai/shared/extensions/merge.lua`**: Added `generate_opencode_json()` function with managed sidecar gating, fragment validation, first-wins merge, and atomic temp-file write. Removed deprecated `merge_opencode_agents()` and `unmerge_opencode_agents()`.
- **`lua/neotex/plugins/ai/shared/extensions/init.lua`**: Replaced per-extension opencode.json merge/unmerge in `process_merge_targets()` and `reverse_merge_targets()` with comments noting computed-artifact behavior. Added `generate_opencode_json()` calls after `generate_claudemd()` in `manager.load()` and `manager.unload()`. Removed `cleanup_stale_opencode_agents()` function and its invocations.
- **`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`**: Replaced per-extension opencode.json re-injection loop with a single `generate_opencode_json()` call at the end of `reinject_loaded_extensions()`.
- **`lua/neotex/plugins/ai/opencode/core/init.lua`**: Updated `install_base_opencode_json()` to trigger `generate_opencode_json()` after template installation, with non-fatal error handling.
- **`lua/neotex/plugins/ai/opencode.lua`**: Replaced startup `cleanup_stale_opencode_agents()` call with `generate_opencode_json()` regeneration.
- **`.opencode/templates/opencode.json`**: Added `permission` block (`edit: "allow"`, `external_directory: {"*": "ask"}`, bash deny rules) and temp-directory guidance in agent prompts.
- **`.opencode/extensions/*/manifest.json`**: Removed `merge_targets.opencode_json` from all 16 extension manifests.
- **`.opencode/context/patterns/computed-artifacts.md`**: New pattern documentation with overview, invariants, template, checklist, examples, and centralized permission configuration subsection.
- **`.opencode/context/reference/opencode-json-lifecycle.md`**: Updated lifecycle stages to reflect computed-artifact regeneration, removed stale-cleanup and per-extension unmerge stages, updated state diagram.
- **`.opencode/context/patterns/json-merge-tracking.md`**: Added deprecation note stating opencode.json no longer uses merge tracking, updated examples to use settings/index, added comparison table vs computed-artifact pattern.

## Decisions

- **First-wins conflict resolution**: Base template agents are preserved exactly; extension fragments only add missing keys. This matches the old merge behavior.
- **Permission block isolation**: Extension fragments merge only into the `agent` table, never into `permission`. Users who need custom permissions should use unmanaged mode.
- **Atomic write with fallback**: Write to temp file then `os.rename()`; fall back to direct write if rename fails.
- **Startup regeneration**: `opencode.lua` triggers `generate_opencode_json()` on Neovim startup to ensure the file reflects currently loaded extensions.

## Impacts

- **Orphaning edge case resolved**: Unloading one extension no longer removes agents still provided by another loaded extension.
- **Deterministic output**: Given the same base template and loaded extensions, `opencode.json` is always identical.
- **No per-extension tracking**: `extensions.json` no longer stores `merged_sections.opencode_json`, simplifying state.
- **Unmanaged files skip regeneration**: Users with unmanaged `opencode.json` will no longer receive automatic extension agents (intentional behavior change).

## Follow-ups

- None.

## References

- Plan: `specs/543_convert_opencode_json_to_computed_artifact/plans/01_convert-opencode-json-computed-artifact.md`
- Research: `specs/543_convert_opencode_json_to_computed_artifact/reports/01_computed-artifact-pattern.md`
