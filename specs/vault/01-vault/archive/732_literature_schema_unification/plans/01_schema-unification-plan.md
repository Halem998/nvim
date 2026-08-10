# Implementation Plan: Task #732

- **Task**: 732 - Unify Index Schema to v2 and Clean Up Deprecated Collections
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Tasks 728, 729, 730, 731 (completed)
- **Research Inputs**: specs/732_literature_schema_unification/reports/01_schema-unification-research.md
- **Artifacts**: plans/01_schema-unification-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Remove 6 redundant directory-level entries from the centralized Literature/index.json, fix token_count on 2 kept directory entries, and create a DEPRECATED.md in cslib's specs/literature/ to redirect users to the centralized repository. Research confirmed the root index is already fully v2 (183 entries, 0 v1), so no schema upgrade is needed there. The cslib index (76 v1 entries) will be deprecated rather than upgraded, since the centralized repo is now canonical.

### Research Integration

Key findings from the research report (01_schema-unification-research.md):
- Root Literature/index.json is 100% v2 compliant (183 entries) -- no upgrade needed
- cslib/specs/literature/index.json is 100% v1 (76 entries) -- deprecation preferred over upgrade
- 6 directory-level entries are true redundancies (token_count=0, no retrievable content)
- 2 directory-level entries (blackburn_2001, gabbay_1994) must be kept (distinct content)
- No per-directory index.json files exist -- centralized architecture already achieved
- No orphaned or missing entries in either direction

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Literature centralization" roadmap item in Phase 2, which is already marked complete for task 710. Task 732 is cleanup/polish work that finalizes the schema unification portion of that initiative.

## Goals & Non-Goals

**Goals**:
- Remove 6 redundant directory-level entries from ~/Projects/Literature/index.json
- Fix token_count for 2 kept directory entries (blackburn_2001, gabbay_1994)
- Create DEPRECATED.md in ~/Projects/cslib/specs/literature/ pointing to centralized repo
- Mark cslib's index.json as deprecated at the version level
- Validate final state: no orphans, no missing entries, all v2

**Non-Goals**:
- Upgrading cslib's 76 v1 entries to v2 (unnecessary since cslib is being deprecated)
- Migrating cslib-unique entries to the centralized repo (separate future task)
- Modifying any markdown content files (only index metadata changes)
- Changing the Literature/ directory structure or file layout

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing dir entries breaks agents referencing them by id | Medium | Low | Search BimodalLogic codebase for id references before deleting |
| cslib DEPRECATED.md sends users to Literature/ before unique entries migrated | Medium | Medium | List cslib-unique entries explicitly so users know what remains local |
| token_count calculation for kept dir entries is inaccurate | Low | Low | Sum actual chunk file sizes using wc -w and apply 0.75 token ratio |
| Concurrent edits to Literature/index.json by other tasks | Low | Low | Tasks 728-731 are completed; no concurrent work expected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Remove Redundant Directory Entries and Fix token_count [COMPLETED]

**Goal**: Clean up the 6 redundant directory-level entries from Literature/index.json and fix token_count on 2 kept directory entries.

**Tasks**:
- [ ] Back up ~/Projects/Literature/index.json to index.json.bak
- [ ] Search BimodalLogic codebase for references to the 6 entry ids being removed: `burgess_1982`, `burgess_1982b`, `venema_1991`, `venema_1993`, `derijke_1995`, `venema_1993_since`
- [ ] Remove these 6 entries from index.json using jq (filter by id, keep all others)
- [ ] Calculate correct token_count for `blackburn_2001` directory entry by summing section chunk token_counts
- [ ] Calculate correct token_count for `gabbay_1994` directory entry by summing section chunk token_counts
- [ ] Update token_count for both kept directory entries in index.json
- [ ] Validate resulting index.json: count entries (should be 177), verify no duplicate ids, verify JSON validity

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `~/Projects/Literature/index.json` - Remove 6 entries, update 2 entries' token_count

**Verification**:
- `jq '.entries | length' ~/Projects/Literature/index.json` returns 177
- `jq '[.entries[] | select(.path | endswith("/"))] | length' ~/Projects/Literature/index.json` returns 2
- `jq '.entries[] | select(.id == "blackburn_2001") | .token_count' ~/Projects/Literature/index.json` returns non-zero value
- `jq '.entries[] | select(.id == "gabbay_1994") | .token_count' ~/Projects/Literature/index.json` returns non-zero value
- `python3 -c "import json; json.load(open('index.json'))"` passes (valid JSON)

---

### Phase 2: Create cslib DEPRECATED.md [PARTIAL]

**Goal**: Add a DEPRECATED.md to cslib's specs/literature/ that redirects users to the centralized Literature/ repository.

**Tasks**:
- [ ] Read ~/Projects/cslib/specs/literature/README.md for context
- [ ] Identify cslib-unique entries by comparing cslib index ids against Literature/ index ids
- [ ] Create ~/Projects/cslib/specs/literature/DEPRECATED.md with:
  - Deprecation notice pointing to ~/Projects/Literature/
  - LITERATURE_DIR environment variable setup instructions
  - List of 6 migrated overlap entries (burgess_1982_i, burgess_1982_ii, blackburn_2001_ch00, reynolds_1992, gabbay_1994_ch10, burgess_1984)
  - List of cslib-unique entries not yet in Literature/ (~57 entries)
  - Note that cslib's index.json remains as historical reference
- [ ] Verify DEPRECATED.md content is accurate against actual filesystem state

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `~/Projects/cslib/specs/literature/DEPRECATED.md` - New file

**Verification**:
- File exists and contains deprecation notice
- Migrated entry list matches the 6 known overlaps
- LITERATURE_DIR instructions reference correct path

---

### Phase 3: Mark cslib Index as Deprecated [PARTIAL]

**Goal**: Add a `"deprecated": true` flag to cslib's index.json version metadata without modifying its entries.

**Tasks**:
- [ ] Read ~/Projects/cslib/specs/literature/index.json to confirm current structure
- [ ] Add `"deprecated": true` and `"deprecated_in_favor_of": "~/Projects/Literature/index.json"` at the top level using jq
- [ ] Preserve all existing entries unchanged
- [ ] Validate resulting JSON

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `~/Projects/cslib/specs/literature/index.json` - Add deprecation flags

**Verification**:
- `jq '.deprecated' ~/Projects/cslib/specs/literature/index.json` returns `true`
- `jq '.entries | length' ~/Projects/cslib/specs/literature/index.json` still returns 76
- JSON is valid

---

### Phase 4: Final Validation and Consistency Check [COMPLETED]

**Goal**: Validate the entire Literature/ index is consistent -- no orphans, no missing files, all v2, correct entry count.

**Tasks**:
- [ ] Run full orphan check: every index entry path resolves to an existing file
- [ ] Run reverse check: every .md file in Literature/ (excluding README.md, scripts/, pdfs/) has a corresponding index entry
- [ ] Verify all 177 entries have all 4 v2 fields: doc_type, source_format, zotero_key, project_tags
- [ ] Verify no duplicate ids in index
- [ ] Remove index.json.bak backup file
- [ ] Report final statistics: total entries, directory entries, section entries, flat entries

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `~/Projects/Literature/index.json.bak` - Remove backup

**Verification**:
- Zero orphaned entries (index paths with no file)
- Zero unindexed files (files with no index entry)
- 177 total entries, all v2 compliant
- 2 directory entries with correct token_count
- cslib index marked deprecated

## Testing & Validation

- [ ] Literature/index.json has exactly 177 entries after Phase 1
- [ ] All 177 entries contain doc_type, source_format, zotero_key, project_tags fields
- [ ] Only 2 directory-level entries remain (blackburn_2001, gabbay_1994) with non-zero token_count
- [ ] Section entries for removed directories still present and intact
- [ ] cslib DEPRECATED.md exists with correct content
- [ ] cslib index.json has deprecated flag without entry modifications
- [ ] No orphaned or missing entries in Literature/

## Artifacts & Outputs

- `~/Projects/Literature/index.json` - Cleaned index (177 entries, 6 removed, 2 fixed)
- `~/Projects/cslib/specs/literature/DEPRECATED.md` - Deprecation notice
- `~/Projects/cslib/specs/literature/index.json` - Deprecated flag added
- `specs/732_literature_schema_unification/plans/01_schema-unification-plan.md` - This plan
- `specs/732_literature_schema_unification/summaries/01_schema-unification-summary.md` - Post-implementation summary

## Rollback/Contingency

Restore from backup: `cp ~/Projects/Literature/index.json.bak ~/Projects/Literature/index.json`. The backup is created at the start of Phase 1 and preserved through Phase 4. For cslib changes, `git checkout` the index.json file and delete DEPRECATED.md. No destructive operations on content files -- only index metadata is modified.
