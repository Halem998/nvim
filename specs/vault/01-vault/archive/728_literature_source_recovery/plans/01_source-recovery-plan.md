# Implementation Plan: Recover PDF/DJVU Sources into Literature/pdfs/

- **Task**: 728 - Recover PDF/DJVU sources into Literature/pdfs/ from Zotero and project repos
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/728_literature_source_recovery/reports/01_source-recovery-research.md
- **Artifacts**: plans/01_source-recovery-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Populate `~/Projects/Literature/pdfs/` with source PDFs and DJVUs by copying from existing project repositories. Research confirmed that BimodalLogic's 32 PDFs cover all 30 unique source documents in the Literature index (29 available, 1 known paywall gap). No Zotero SQLite lookup is needed since BimodalLogic already has every recoverable file. The chagrov_1997.djvu from cslib is copied as a bonus asset (not currently indexed).

### Research Integration

Key findings from research report:
- `~/Projects/Literature/pdfs/` exists but is empty
- BimodalLogic has 32 PDFs covering all 30 unique indexed source documents
- `thomas_1997` has no PDF anywhere (Springer paywall; markdown reconstructed from secondary sources)
- `chagrov_1997.djvu` exists in cslib but has no Literature index entry
- Zotero key mapping is not needed -- BimodalLogic covers everything
- BimodalLogic PDFs use subdirectory structure; Literature/pdfs/ should be flat

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Copy all 32 BimodalLogic PDFs into `~/Projects/Literature/pdfs/` with flat naming
- Copy `chagrov_1997.djvu` from cslib into `~/Projects/Literature/pdfs/`
- Verify every indexed document (with zotero_key) has a corresponding file in `pdfs/`
- Document the one known gap (thomas_1997)

**Non-Goals**:
- Zotero SQLite key mapping (not needed; BimodalLogic covers all sources)
- Populating `zotero_path` fields in index.json (deferred to future task)
- Adding chagrov_1997 to Literature/index.json (separate task scope)
- Re-chunking or re-converting PDFs (downstream tasks 729-733)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| BimodalLogic subdirectory PDFs have filename collisions when flattened | M | L | Check for duplicate filenames before copy; all 32 have unique names per research |
| pdfs/ directory permissions prevent writing | L | L | Verify directory is writable before bulk copy |
| thomas_1997 gap causes downstream confusion | L | M | Document gap explicitly in verification output |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Copy Source Files [NOT STARTED]

**Goal**: Populate `~/Projects/Literature/pdfs/` with all available source PDFs and DJVUs from project repositories.

**Tasks**:
- [ ] Verify `~/Projects/Literature/pdfs/` exists and is writable
- [ ] Copy all 32 PDFs from `~/Projects/BimodalLogic/specs/literature/` into `~/Projects/Literature/pdfs/` using flat naming (no subdirectories)
- [ ] Copy `~/Projects/cslib/specs/literature/chagrov_1997.djvu` into `~/Projects/Literature/pdfs/`
- [ ] Verify no filename collisions occurred during copy (count files before and after)
- [ ] List all files in `~/Projects/Literature/pdfs/` and confirm 33 files present (32 PDFs + 1 DJVU)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `~/Projects/Literature/pdfs/*.pdf` - 32 new PDF files (copied from BimodalLogic)
- `~/Projects/Literature/pdfs/chagrov_1997.djvu` - 1 new DJVU file (copied from cslib)

**Verification**:
- `ls ~/Projects/Literature/pdfs/ | wc -l` returns 33
- `find ~/Projects/Literature/pdfs/ -name "*.pdf" | wc -l` returns 32
- `find ~/Projects/Literature/pdfs/ -name "*.djvu" | wc -l` returns 1

**Commands**:
```bash
# Copy all PDFs from BimodalLogic (flatten subdirectory structure)
find ~/Projects/BimodalLogic/specs/literature/ -name "*.pdf" -exec cp {} ~/Projects/Literature/pdfs/ \;

# Copy DJVU from cslib
cp ~/Projects/cslib/specs/literature/chagrov_1997.djvu ~/Projects/Literature/pdfs/

# Verify counts
echo "Total files: $(ls ~/Projects/Literature/pdfs/ | wc -l)"
echo "PDFs: $(find ~/Projects/Literature/pdfs/ -name '*.pdf' | wc -l)"
echo "DJVUs: $(find ~/Projects/Literature/pdfs/ -name '*.djvu' | wc -l)"
```

---

### Phase 2: Verify Coverage Against Index [NOT STARTED]

**Goal**: Confirm every indexed source document (with a non-null zotero_key) has a corresponding file in `pdfs/`, and document any gaps.

**Tasks**:
- [ ] Extract all unique source document IDs from `~/Projects/Literature/index.json` (group by zotero_key to get unique source documents)
- [ ] Cross-reference each unique source document against files in `~/Projects/Literature/pdfs/`
- [ ] Confirm thomas_1997 is the only gap (no PDF, known paywall issue)
- [ ] Print a summary showing: covered count, gap count, gap details

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- No files modified; read-only verification

**Verification**:
- Coverage report shows 29/30 unique source documents covered
- Only gap is thomas_1997 with explicit reason documented
- All 32 BimodalLogic PDFs accounted for in pdfs/

**Commands**:
```bash
# Extract unique zotero_keys from index.json
jq -r '[.entries[] | select(.zotero_key != null) | .zotero_key] | unique | .[]' \
  ~/Projects/Literature/index.json

# List pdfs/ contents for manual cross-reference
ls -1 ~/Projects/Literature/pdfs/

# Check for the known gap
jq -r '.entries[] | select(.zotero_key == null) | "\(.id): no zotero_key"' \
  ~/Projects/Literature/index.json
```

## Testing & Validation

- [ ] `~/Projects/Literature/pdfs/` contains exactly 33 files (32 PDFs + 1 DJVU)
- [ ] No zero-byte files exist in pdfs/
- [ ] Every unique zotero_key in index.json maps to at least one file in pdfs/ (except thomas_1997)
- [ ] Files are readable (not corrupted copies)

## Artifacts & Outputs

- `~/Projects/Literature/pdfs/*.pdf` - 32 recovered PDF source files
- `~/Projects/Literature/pdfs/chagrov_1997.djvu` - 1 recovered DJVU source file
- `specs/728_literature_source_recovery/plans/01_source-recovery-plan.md` - This plan

## Rollback/Contingency

Remove all files from pdfs/ to restore to empty state:
```bash
rm -f ~/Projects/Literature/pdfs/*
```
This is safe because pdfs/ is gitignored and these are copies of files that remain in their original locations (BimodalLogic, cslib).
