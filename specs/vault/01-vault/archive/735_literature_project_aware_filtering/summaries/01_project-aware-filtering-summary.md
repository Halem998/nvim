# Implementation Summary: Task #735

**Completed**: 2026-06-16
**Duration**: ~1 hour

## Overview

Added project-aware filtering to the literature retrieval pipeline. Both `literature-retrieve.sh` (Tier 2 keyword) and `literature-search.sh` (Tier 1 FTS5) now auto-detect or accept a project name and filter literature entries to those tagged with that project via `project_tags` in `index.json`. Untagged entries and non-matching projects gracefully fall back to the full entry set.

## What Changed

- `.claude/scripts/literature-retrieve.sh` — Added `detect_project()` function using `git rev-parse --show-toplevel`, project hint injected into Tier 1 `<literature-tool>` block, Tier 2 keyword path now pre-filters `all_entries` by `project_tags` before scoring
- `.claude/scripts/literature-search.sh` — Added `--project <name>` flag parsing (pre-scan loop strips it before subcommand dispatch), `get_project_doc_ids()` function builds allowed `doc_id` set from `index.json`, `do_search()` accepts project filter and adds `AND d.doc_id IN (...)` SQL clause, fallback re-runs query without filter when filtered results are empty

## Decisions

- Pre-scan loop for `--project` flag (before subcommand dispatch) makes the flag composable with all subcommands without duplicating parsing in each branch
- Fallback condition checks result count after filter: if 0 results and filter was active, re-runs unfiltered query — this handles cslib and any unrecognized project names gracefully
- Project detection in `literature-retrieve.sh` uses `git rev-parse --show-toplevel` with fallback to `basename "$PWD"` for non-git directories
- Tier 2 filtering uses jq `index()` with `ascii_downcase` for case-insensitive project tag matching

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — verified BimodalLogic filter returns 20 results, cslib fallback returns 20 results (all entries), no-flag baseline unchanged at 20 results
- Tier 1 tool block verified to include project hint with correct project name detection ("nvim" from nvim config directory)
- Files verified: Yes

## Notes

All 195 index.json entries are tagged `["BimodalLogic"]` with no untagged entries. The cslib fallback path therefore returns the full result set when called from a cslib project directory. This is correct behavior — it ensures cslib users get literature results even before cslib-tagged entries are added to the index.
