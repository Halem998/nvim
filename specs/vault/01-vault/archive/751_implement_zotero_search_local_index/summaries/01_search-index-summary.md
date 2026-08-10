# Implementation Summary: Task #751 — Implement Zotero Search and Local Index Management

**Completed**: 2026-06-19
**Duration**: ~45 minutes

## Overview

Implemented all three Category C index management scripts (`zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-search-index.sh`) and wired the `--task N` mode into `zotero.md` and SKILL.md. Also fixed a path resolution bug in the task 750 scripts (`zotero-read.sh` and `zotero-setup.sh`).

## What Changed

### New Implementations (replacing stubs)

- `.claude/extensions/zotero/scripts/zotero-index-add.sh` — Full implementation (~210 lines):
  - Calls `zotero-read.sh item KEY` and extracts all 20 index entry fields
  - Handles authors via `.creators[]` with `creatorType == "author"` filter
  - Resolves PDF path from `.attachments[]` with `contentType` pdf check
  - Extracts `relevance_keywords` via stop-word-filtered bash tokenization
  - Optionally fetches `notes_summary` from `zotero-read.sh note KEY`
  - Upsert logic: `select(.zotero_key == $k)` for update, `.entries += [$entry]` for append
  - Preserves `has_chunks`, `chunk_dir`, `chunk_count`, `token_count` from existing entry on update
  - Handles `--chunk` flag with graceful exit-2 degradation for unimplemented `zotero-chunk.sh`

- `.claude/extensions/zotero/scripts/zotero-index-remove.sh` — Full implementation (~100 lines):
  - Looks up entry by `zotero_key` using `select(.zotero_key == $k)`
  - Optional `--delete-chunks`: `rm -rf` the chunk directory if it exists
  - Removes entry with `select(.zotero_key == $k | not)` jq pattern (safe, no `!=`)
  - Atomic read-transform-write with `last_updated` timestamp update
  - Exits 1 for key not found, exits 2 for missing index

- `.claude/extensions/zotero/scripts/zotero-search-index.sh` — Full implementation (~215 lines):
  - Stop-word-filtered query term extraction into JSON array
  - Multi-field weighted scoring jq expression: title*4 + tags*3 + abstract*2 + keywords*2 + collections*1 + notes*1
  - Threshold: `score >= 1` (looser than retrieve's `>= 4`)
  - Pretty output with availability tags: `[HAS MARKDOWN]`, `[PDF ONLY]`, `[NO PDF]`
  - JSON output mode via `--format json`
  - Fallback to `zotero-read.sh search QUERY` when index is empty/missing

### Command and Skill Updates

- `.claude/extensions/zotero/commands/zotero.md`:
  - Added `--task N` to argument-hint, sub-mode dispatch table, argument parsing pseudocode, validation table, error messages, delegation args, and result display section

- `.claude/extensions/zotero/skills/skill-zotero/SKILL.md`:
  - Added `task_num` to argument parsing block
  - Added `task_search)    handle_task_search ;;` to dispatch
  - Added `handle_task_search` mode: extracts task description from `specs/state.json` (tries `description`, `title`, `project_name`), passes to `zotero-search-index.sh`

### Bug Fixes (task 750 scripts)

- `.claude/extensions/zotero/scripts/zotero-read.sh` — Fixed `PROJECT_ROOT` path: `../..` → `../../../../`
- `.claude/extensions/zotero/scripts/zotero-setup.sh` — Fixed `PROJECT_ROOT` path: `../..` → `../../../../`

The scripts live at `.claude/extensions/zotero/scripts/` which is 4 directory levels below the project root, not 2. The old `../..` resolved to `.claude/extensions/` rather than the project root.

## Decisions

- **Path resolution**: Scripts use `SCRIPT_DIR/../../../..` (4 levels up) to reach project root from `.claude/extensions/zotero/scripts/`
- **jq safety**: All selects use `select(.field == value | not)` pattern; no `!=` in jq expressions
- **Relevance keywords**: Extracted from title + tags via bash tokenization, not from jq (simpler, avoids complex jq string manipulation)
- **Task description extraction**: `handle_task_search` tries `.description`, `.title`, `.project_name` in order; converts `project_name` underscores to spaces as last resort
- **`--task N` task number**: Uses `tonumber` in jq for integer comparison against `project_number`

## Verification

- Build: N/A (shell scripts)
- Tests:
  - `bash -n` syntax: all 5 scripts pass (including the 2 task 750 fixes)
  - All 3 new scripts are executable (`chmod +x`)
  - `zotero-index-add.sh` exits 2 when `specs/zotero-index.json` missing
  - `zotero-index-remove.sh` exits 2 when index missing, exits 1 when key not found
  - `zotero-search-index.sh` exits 2 when both index and zot unavailable, exits 1 for empty query
  - Search with test data: scoring working (modal logic query scored blackburn2001=29, jones2019=21, type theory query scored smith2020=23)
  - Availability tags display correctly: `[HAS MARKDOWN]`, `[PDF ONLY]`, `[NO PDF]`
  - Remove: entry count drops from 3 to 2 after removing a key
  - jq `| not` pattern confirmed in remove script

## Notes

- Task 752 (`zotero-chunk.sh`) must be implemented before `--chunk` flag in `zotero-index-add.sh` produces chunks; currently exits 2 gracefully
- Task 753 (`zotero-retrieve.sh`) must be implemented before `--zot` flag works in `/research`, `/plan`, `/implement`
- The `handle_task_search` mode assumes `state.json` has a `.description` field; many tasks only have `project_name`. The fallback (underscore-to-space conversion of project_name) provides reasonable search terms in that case
