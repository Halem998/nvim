# Implementation Plan: Task #731

- **Task**: 731 - Migrate cslib's Literature Entries into Central Literature Repo
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 730 (semantic chunking standards)
- **Research Inputs**: specs/731_literature_cslib_migration/reports/01_cslib-migration-research.md
- **Artifacts**: plans/01_cslib-migration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Migrate 70 unique literature entries from cslib's per-project `specs/literature/` into the central `~/Projects/Literature/` repository. The migration uses the existing `migrate-from-repo.sh` script for bulk import with v1-to-v2 schema backfilling, then applies manual corrections for 6 ID overlaps (5 true duplicates where Literature has fuller versions, 1 mislabeled reynolds_1992), and tags 35+ existing Literature blackburn_2001 chapter entries with `"cslib"` in `project_tags`. The chagrov_1997 DJVU conversion is already complete -- no conversion work needed.

### Research Integration

Key findings from the research report:
- cslib has 76 index entries; 70 are unique to cslib (6 overlap with Literature)
- All 5 true content overlaps have fuller versions in Literature already
- cslib's `reynolds_1992` is mislabeled (actually Reynolds 1994); Literature's `reynolds_1994` already covers it with 5x more content
- The 35 blackburn_2001 chapter entries exist as identical files in Literature under different IDs (section-based naming)
- `chagrov_1997.djvu` conversion is already complete (6 markdown files ready to migrate)
- Migration script at `~/Projects/Literature/scripts/migrate-from-repo.sh` handles v1-to-v2 schema transformation automatically

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Import all 70 unique cslib literature entries into central Literature repo with v2 schema fields
- Add `project_tags: ["cslib"]` to all migrated and overlapping entries
- Resolve the 6 ID overlaps correctly (keep Literature's fuller versions, skip mislabeled reynolds)
- Tag existing Literature blackburn_2001 section entries with "cslib" rather than creating duplicate chapter entries
- Migrate chagrov_1997 markdown files (already converted from DJVU)

**Non-Goals**:
- Converting chagrov_1997.djvu (already done)
- Copying the DJVU binary file to Literature
- Changing cslib's `specs/literature/` directory (deprecation is a separate task)
- Re-chunking blackburn_2001 chapters to match Literature's section-based naming

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Migration script imports blackburn ch01a-ch07e as new IDs, creating duplicate file references | M | H | Run script in dry-run/preview mode first; post-migration remove duplicate blackburn entries and tag existing Literature entries instead |
| reynolds_1992 ID collision silently drops cslib's 1994 content | L | H | Acceptable -- Literature's reynolds_1994 already covers the paper with 5x more content; verify post-migration |
| authors field string-to-array transformation fails for edge cases | M | L | Migration script handles this; spot-check 3-5 entries after import |
| chagrov_1997 sub-index format incompatible with migrate script | M | L | Script reads subdirectory index.json files; verify chagrov sub-index format matches expectations |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pre-migration Audit and Preparation [NOT STARTED]

**Goal**: Verify the state of both repos and confirm the migration script will behave correctly for edge cases before running it.

**Tasks**:
- [ ] Read cslib's `specs/literature/index.json` and confirm 76 entries with v1 schema
- [ ] Read Literature's `index.json` and confirm current entry count (183) and v2 schema
- [ ] Verify the 6 overlapping IDs: `burgess_1982_i`, `burgess_1982_ii`, `burgess_1984`, `gabbay_1994_ch10`, `blackburn_2001_ch00`, `reynolds_1992`
- [ ] Confirm Literature has `reynolds_1994` entry covering the same paper as cslib's mislabeled `reynolds_1992`
- [ ] Verify `chagrov_1997/index.json` sub-index format is compatible with migration script (should have `chapters` or `entries` array)
- [ ] Check migration script for `--dry-run` or preview option; if none, review script logic to confirm skip-on-duplicate behavior

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- None (read-only audit)

**Verification**:
- All 6 overlap IDs confirmed present in both indexes
- chagrov sub-index format validated
- Script behavior for duplicates confirmed (skip by ID)

---

### Phase 2: Run Migration Script and Handle Blackburn Duplicates [NOT STARTED]

**Goal**: Execute the bulk migration and clean up the blackburn_2001 chapter duplicate entries that the script will create.

**Tasks**:
- [ ] Run migration script: `cd ~/Projects/Literature && ./scripts/migrate-from-repo.sh ~/Projects/cslib`
- [ ] Verify script output: confirm it skipped the 6 overlapping IDs and imported the remaining entries
- [ ] Count new entries in Literature's `index.json` -- expect ~70 new entries (35 blackburn chapters + 35 others)
- [ ] Identify the 35 blackburn_2001 chapter entries added by cslib IDs (ch01a through ch07e)
- [ ] Remove the 35 duplicate blackburn chapter entries from Literature's `index.json` (the files are already present under Literature's section-based IDs)
- [ ] If the script copied duplicate blackburn markdown files, remove them (Literature already has identical copies)
- [ ] Verify the remaining ~35 new entries are correct (chagrov x6, church x6, gentzen x5, hughes x4, mendelson x6, zakharyaschev x4, plus standalone papers)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/index.json` -- remove duplicate blackburn chapter entries
- `~/Projects/Literature/blackburn_2001/` -- remove any duplicate files if script copied them

**Verification**:
- Literature's `index.json` contains no duplicate blackburn_2001 chapter entries with cslib-style IDs
- Net new entries count matches expectations (~35 genuinely new entries)
- All chagrov_1997 files present in `~/Projects/Literature/chagrov_1997/`

---

### Phase 3: Tag Overlap and Blackburn Entries with project_tags [NOT STARTED]

**Goal**: Add `"cslib"` to `project_tags` for all entries that exist in both repos (the 5 true overlaps plus the blackburn_2001 section entries already in Literature).

**Tasks**:
- [ ] Add `"cslib"` to `project_tags` for the 5 true overlap entries in Literature's `index.json`: `burgess_1982_i`, `burgess_1982_ii`, `burgess_1984`, `gabbay_1994_ch10`, `blackburn_2001_ch00`
- [ ] Identify all existing Literature blackburn_2001 section entries (should be ~35 entries with section-based IDs like `blackburn_2001_ch01_sec01-02`)
- [ ] Add `"cslib"` to `project_tags` for all identified blackburn_2001 section entries
- [ ] Verify `reynolds_1994` in Literature -- add `"cslib"` to its `project_tags` since cslib references this paper (was mislabeled as reynolds_1992)
- [ ] Spot-check 5 migrated entries for correct v2 schema fields: `doc_type`, `source_format`, `zotero_key`, `project_tags`, `authors` (should be array)

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `~/Projects/Literature/index.json` -- update `project_tags` on overlap and blackburn entries

**Verification**:
- All 5 overlap entries have `"cslib"` in project_tags
- All blackburn_2001 section entries have `"cslib"` in project_tags
- `reynolds_1994` has `"cslib"` in project_tags
- Spot-checked entries have correct v2 schema fields

---

### Phase 4: Final Validation and Integrity Check [NOT STARTED]

**Goal**: Verify the complete migration is correct, all files are present, and the index is consistent.

**Tasks**:
- [ ] Run `jq '.entries | length' ~/Projects/Literature/index.json` to confirm total entry count (should be ~218: 183 original + ~35 new)
- [ ] Verify all migrated markdown files exist on disk by cross-checking index paths against filesystem
- [ ] Check for orphaned files (files in Literature directories without index entries)
- [ ] Verify no entry has empty or null `project_tags` where `"cslib"` was expected
- [ ] Run Literature's validation script if available (`/literature --validate` equivalent)
- [ ] Confirm cslib's original `specs/literature/` is untouched (migration is non-destructive to source)

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- None (read-only validation), or `~/Projects/Literature/index.json` if corrections needed

**Verification**:
- Total entry count is in expected range (215-220)
- All index paths resolve to existing files
- No orphaned files in migrated directories
- cslib's `specs/literature/` unchanged

## Testing & Validation

- [ ] Literature `index.json` entry count increased by ~35 net new entries
- [ ] All 6 chagrov_1997 chapter files present in `~/Projects/Literature/chagrov_1997/`
- [ ] All standalone papers (church, gentzen, hughes, mendelson, zakharyaschev, johansson, henkin, bentzen, trufas, from, post) present in Literature
- [ ] No blackburn_2001 entries with cslib-style IDs (ch01a, ch01b, etc.) remain in index
- [ ] All blackburn_2001 section-style entries have `"cslib"` in project_tags
- [ ] 5 true overlap entries + reynolds_1994 have `"cslib"` in project_tags
- [ ] All migrated entries have v2 schema fields: `doc_type`, `source_format`, `project_tags` (array containing "cslib")
- [ ] `authors` field is array type (not string) on all migrated entries

## Artifacts & Outputs

- `specs/731_literature_cslib_migration/plans/01_cslib-migration-plan.md` (this plan)
- `~/Projects/Literature/index.json` (updated with ~35 new entries and project_tags additions)
- `~/Projects/Literature/chagrov_1997/` (6 chapter files migrated from cslib)
- Various standalone paper markdown files migrated to Literature

## Rollback/Contingency

The migration is non-destructive to cslib's `specs/literature/`. If the Literature repo migration goes wrong:
1. Use `git checkout -- index.json` in `~/Projects/Literature/` to revert index changes
2. Use `git clean -fd` in `~/Projects/Literature/` to remove any newly copied files
3. Re-run with corrected approach
