# Implementation Plan: Task #735

- **Task**: 735 - Add project-aware literature filtering with project_tags population and retrieval filtering
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/735_literature_project_aware_filtering/reports/01_project-aware-filtering.md
- **Artifacts**: plans/01_project-aware-filtering.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Add project-aware filtering to the literature retrieval pipeline. Both `literature-search.sh` (Tier 1 FTS5) and `literature-retrieve.sh` (Tier 2 keyword) will auto-detect the current project from `$PWD`'s git root basename and prefer literature entries tagged with that project via `project_tags` in `index.json`. Untagged entries and entries from non-matching projects serve as fallback when project-filtered results are empty.

### Research Integration

Research confirmed that `project_tags` is already populated for all 195 entries (all tagged `["BimodalLogic"]`). The FTS5 database has no `project_tags` column, so filtering must cross-reference `index.json` by `doc_id` to build an allowed set. Project detection uses `basename "$(git rev-parse --show-toplevel)"` which yields exact matches against tag values (`BimodalLogic`, `cslib`). No source-file scanning is needed since `project_tags` is a curated field.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the literature centralization infrastructure from Phase 2. No specific unchecked roadmap item corresponds directly to this task.

## Goals & Non-Goals

**Goals**:
- Auto-detect project name from git root basename in both retrieval scripts
- Filter Tier 1 (FTS5) search results to project-tagged `doc_id` values via `--project` flag
- Filter Tier 2 (keyword) scored entries to project-tagged entries before budget selection
- Graceful fallback to all entries when project filter yields zero results
- Include untagged entries (empty `project_tags`) in all filtered result sets

**Non-Goals**:
- Auto-generating `project_tags` from source file scanning
- Adding `project_tags` column to the SQLite FTS5 database schema
- Adding cslib-tagged literature entries (requires separate content curation)
- Modifying `index.json` schema or adding new fields

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `doc_id` mismatch between index.json and FTS5 database | H | L | Research verified exact match between `id` field and `doc_id` values |
| Performance degradation from loading index.json on every search | L | L | index.json is ~195 entries, sub-5ms parse; negligible overhead |
| Project detection fails outside git repos | M | M | Fallback to `basename "$PWD"`; if no match, full entry set used |
| Tier 1 tool block not updated, agent ignores project context | M | M | Add project hint to `<literature-tool>` block and pass `--project` flag |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add project detection and Tier 2 filtering to literature-retrieve.sh [COMPLETED]

**Goal**: Add project auto-detection from git root and filter Tier 2 keyword-scored entries by `project_tags` before budget selection. Also inject project context into the Tier 1 tool block.

**Tasks**:
- [ ] Add `detect_project()` function after the Tier 1 constants block (around line 34) that runs `basename "$(git rev-parse --show-toplevel 2>/dev/null)"` with fallback to `basename "$PWD"`
- [ ] Call `detect_project` and store result in `CURRENT_PROJECT` variable
- [ ] In the Tier 1 branch (lines 41-86), add a line to the `<literature-tool>` printf block indicating the current project name and suggesting `--project` flag usage for project-scoped results
- [ ] In the Tier 2 branch, after `all_entries` is built (line 194) and before scoring (line 196), add a jq filter that restricts `all_entries` to entries where `project_tags` contains `$CURRENT_PROJECT` or `project_tags` is null/empty. If the filtered set is empty, keep original `all_entries` (fallback)
- [ ] Verify the fallback path (no index.json) remains unaffected

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-retrieve.sh` - Add project detection function, Tier 1 project hint, Tier 2 project filtering

**Verification**:
- Run `literature-retrieve.sh "modal logic" general` from within `~/Projects/BimodalLogic/` and verify results are project-filtered
- Run from a directory with no matching project tags and verify fallback to all entries
- Run with `LITERATURE_DIR` set and verify Tier 1 tool block includes project hint

---

### Phase 2: Add --project flag to literature-search.sh (Tier 1 FTS5) [COMPLETED]

**Goal**: Accept a `--project <name>` flag that filters FTS5 search results to `doc_id` values tagged with the given project in `index.json`. Implement fallback on zero results.

**Tasks**:
- [ ] Add `--project` flag parsing in the main dispatch case statement, storing value in `PROJECT_FILTER` variable. Support it as an optional prefix before the query: `literature-search.sh --project BimodalLogic "modal logic"`
- [ ] In `do_search()`, when `PROJECT_FILTER` is set, load `index.json` from `$LITERATURE_DIR` and build a set of allowed `doc_id` values: entries where `project_tags` contains the project name OR `project_tags` is null/empty
- [ ] Modify the Python search SQL to add `AND d.doc_id IN (...)` clause when allowed doc_ids are computed
- [ ] If filtered search returns zero results, re-run the query without the `doc_id IN` filter (fallback)
- [ ] Pass `PROJECT_FILTER` through environment or argument to the Python block
- [ ] Update the `--doc` and `--toc` commands to also accept `--project` for consistency (filter output to project-tagged doc_ids)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-search.sh` - Add `--project` flag parsing, doc_id filtering in `do_search()`, fallback logic

**Verification**:
- Run `literature-search.sh --project BimodalLogic "modal logic"` and verify results only include BimodalLogic-tagged doc_ids
- Run `literature-search.sh --project cslib "modal logic"` and verify fallback returns all results (since no cslib entries exist)
- Run without `--project` flag and verify behavior is unchanged

---

### Phase 3: Integration testing and edge case verification [COMPLETED]

**Goal**: Verify both tiers work end-to-end with project filtering, test fallback behavior, and validate edge cases.

**Tasks**:
- [ ] Test Tier 1 flow: run `literature-retrieve.sh` from BimodalLogic directory, verify `<literature-tool>` block includes project hint and `--project` flag suggestion
- [ ] Test Tier 2 flow: temporarily rename `.literature.db` to force Tier 2, run from BimodalLogic dir, verify entries are project-filtered
- [ ] Test fallback: run from `cslib` directory (no matching entries), verify all entries returned
- [ ] Test edge case: run from a non-project directory (e.g., `/tmp`), verify graceful behavior (all entries)
- [ ] Test edge case: run from nvim config directory, verify project detected as `nvim` with no matching entries and full fallback
- [ ] Verify `--project` flag works with `--toc` and `--doc` subcommands in literature-search.sh
- [ ] Run a quick end-to-end test: invoke a `/research --lit` from a BimodalLogic subdirectory (if feasible) to validate the full pipeline

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- No file modifications; testing only

**Verification**:
- All test scenarios pass with expected filtering and fallback behavior
- No regressions in existing literature retrieval without `--project` flag

## Testing & Validation

- [ ] Tier 1: `literature-search.sh --project BimodalLogic "Kripke semantics"` returns only BimodalLogic-tagged chunks
- [ ] Tier 1 fallback: `literature-search.sh --project nonexistent "modal logic"` returns all results
- [ ] Tier 2: `literature-retrieve.sh "modal logic" general` from BimodalLogic dir filters by project
- [ ] Tier 2 fallback: same command from cslib dir falls back to all entries
- [ ] No-flag baseline: both scripts produce identical output to current behavior when `--project` is absent
- [ ] Project detection: verify `detect_project` returns correct name from BimodalLogic, cslib, and nvim directories

## Artifacts & Outputs

- plans/01_project-aware-filtering.md (this file)
- Modified `.claude/scripts/literature-retrieve.sh`
- Modified `.claude/scripts/literature-search.sh`
- summaries/01_project-aware-filtering-summary.md (post-implementation)

## Rollback/Contingency

Both scripts are tracked in git. If project filtering causes issues:
1. `git checkout HEAD -- .claude/scripts/literature-retrieve.sh .claude/scripts/literature-search.sh`
2. The changes are additive (new flag, new function, new filter step) with no removal of existing logic, so partial rollback is straightforward
