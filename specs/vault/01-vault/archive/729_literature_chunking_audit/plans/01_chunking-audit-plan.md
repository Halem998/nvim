# Implementation Plan: Task #729

- **Task**: 729 - Audit Literature Subdirectories for Chunking Quality
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/729_literature_chunking_audit/reports/01_chunking-audit-research.md
- **Artifacts**: plans/01_chunking-audit-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Produce a structured chunking-quality manifest for all literature subdirectories in ~/Projects/Literature/ and ~/Projects/cslib/specs/literature/, then execute corrective actions: rename arbitrarily-named chunks to semantic names, and flag oversized cslib chunks for future re-chunking. The research report identified 18 well-chunked Literature/ subdirectories (keep), 4 with arbitrary naming (rename), 1 critical flat file (Blackburn 2002, 365K tokens), and 5 oversized cslib subdirectories needing section-level re-chunking.

### Research Integration

Key findings from the research report integrated into this plan:
- ~/Projects/Literature/: 23 subdirectories audited; 18 semantic (keep), 3 arbitrary-named (rename: burgess_1984, doets_1989, reynolds_1994), 1 borderline (doets_1987)
- ~/Projects/cslib/specs/literature/: 7 subdirectories; 2 good (blackburn_2001, gentzen_1935), 5 oversized (chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001)
- 1 critical flat file: Blackburn_deRijke_Venema_2002_Modal_Logic.md (~365K tokens, no subdirectory)
- 17+ duplicate flat files at Literature/ root that mirror existing subdirectories

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Produce a machine-readable manifest (JSON) classifying every literature subdirectory by chunking quality
- Rename arbitrarily-named chunks in Literature/ to semantic names (burgess_1984, doets_1989, reynolds_1994)
- Document the oversized cslib chunks with recommended section-level re-chunking targets
- Identify and list duplicate flat files for user review
- Flag the Blackburn 2002 flat file as needing a dedicated chunking task

**Non-Goals**:
- Actually re-chunking the 5 oversized cslib textbooks (high effort, separate tasks)
- Chunking the Blackburn 2002 flat file (requires PDF source, separate task)
- Deleting duplicate flat files (user decision required)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Renaming chunks breaks external references | M | L | Check for references in index.json or other config before renaming |
| Source PDFs not available for determining semantic names | M | M | Use file content headings/sections to derive semantic names |
| Oversized cslib chunks have no clear section boundaries | M | L | Note in manifest; defer to dedicated re-chunking tasks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Generate Chunking Quality Manifest [COMPLETED]

**Goal**: Scan both literature directories and produce a comprehensive JSON manifest classifying every subdirectory and flat file by chunking quality.

**Tasks**:
- [ ] Scan ~/Projects/Literature/ subdirectories: count files, compute max chunk size (bytes/4), identify naming pattern
- [ ] Scan ~/Projects/Literature/ root flat files: compute sizes, check for matching subdirectory
- [ ] Scan ~/Projects/cslib/specs/literature/ subdirectories: count files, compute max chunk size, identify naming pattern
- [ ] Scan ~/Projects/cslib/specs/literature/ root flat files: compute sizes
- [ ] Generate `specs/729_literature_chunking_audit/chunking-manifest.json` with classification per entry:
  - `status`: "good" | "rename" | "oversized" | "unchunked" | "duplicate"
  - `action`: "keep" | "rename" | "rechunk" | "chunk-new" | "review-for-removal"
  - `location`, `files_count`, `max_chunk_tokens`, `naming_pattern`, `recommended_structure`
- [ ] Generate `specs/729_literature_chunking_audit/chunking-manifest-summary.md` with human-readable tables

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/729_literature_chunking_audit/chunking-manifest.json` - create (machine-readable manifest)
- `specs/729_literature_chunking_audit/chunking-manifest-summary.md` - create (human-readable summary)

**Verification**:
- JSON manifest is valid and contains entries for all 30 subdirectories and notable flat files
- Each entry has status, action, and size metrics
- Summary tables match research report findings

---

### Phase 2: Rename Arbitrary Chunks in Literature/ [COMPLETED]

**Goal**: Rename the 3 arbitrarily-named Literature/ subdirectories' chunks from page-based or part-based names to semantic names derived from file content.

**Tasks**:
- [ ] Read content of each chunk in ~/Projects/Literature/burgess_1984/ (7 files), identify section topics from headings/content, rename files from `sec{N}_page-{N}.md` to `sec{N}_{semantic-topic}.md`
- [ ] Read content of each chunk in ~/Projects/Literature/doets_1989/ (3 files), rename from `sec{N}_part-{N}.md` to `sec{N}_{semantic-topic}.md`
- [ ] Read content of each chunk in ~/Projects/Literature/reynolds_1994/ (3 files), rename from `sec{N}_part-{N}.md` to `sec{N}_{semantic-topic}.md`
- [ ] Check for any index.json or reference files that point to old filenames; update if found
- [ ] Update the manifest JSON to reflect new filenames

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/burgess_1984/*.md` - rename files
- `~/Projects/Literature/doets_1989/*.md` - rename files
- `~/Projects/Literature/reynolds_1994/*.md` - rename files

**Verification**:
- All renamed files follow `sec{N}_{semantic-topic}.md` pattern
- No broken references to old filenames
- File contents unchanged (rename only)

---

### Phase 3: Document Oversized cslib Chunks and Duplicates [COMPLETED]

**Goal**: Add detailed re-chunking recommendations to the manifest for the 5 oversized cslib subdirectories, and list all duplicate flat files in Literature/ root.

**Tasks**:
- [ ] For each oversized cslib subdirectory (chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001): read each chunk file, identify section/subsection boundaries from content headings, record recommended split points and target chunk count in manifest
- [ ] For each duplicate flat file in ~/Projects/Literature/ root (17+ files): confirm the corresponding subdirectory exists and contains equivalent content
- [ ] Add `recommended_splits` field to oversized entries in manifest with target chunk count and section names
- [ ] Add `duplicate_of` field to flat file entries that have subdirectory equivalents

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `specs/729_literature_chunking_audit/chunking-manifest.json` - update with split recommendations and duplicate markers
- `specs/729_literature_chunking_audit/chunking-manifest-summary.md` - update summary tables

**Verification**:
- Each oversized entry has `recommended_splits` with section-level targets
- Each duplicate flat file entry has `duplicate_of` pointing to its subdirectory
- Recommended chunk counts target 5-10K tokens per chunk

---

### Phase 4: Final Validation and Action Summary [COMPLETED]

**Goal**: Validate the complete manifest, produce a prioritized action list, and create follow-up task recommendations for the oversized re-chunking work.

**Tasks**:
- [ ] Validate manifest JSON schema consistency (all entries have required fields)
- [ ] Cross-check manifest totals against research report statistics (23 Literature/ subdirs, 7 cslib subdirs, 30 Literature/ flat files, 11 cslib flat files)
- [ ] Create prioritized action summary in manifest-summary with:
  - Completed actions (renames done in Phase 2)
  - Recommended follow-up tasks (re-chunk 5 cslib subdirs, chunk Blackburn 2002, review duplicates)
  - Estimated effort per follow-up task
- [ ] Update chunking-manifest-summary.md with final status and action tracking table

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `specs/729_literature_chunking_audit/chunking-manifest.json` - final validation pass
- `specs/729_literature_chunking_audit/chunking-manifest-summary.md` - final summary with action items

**Verification**:
- Manifest contains entries for all expected directories and files
- Action summary lists all follow-up work with effort estimates
- No inconsistencies between manifest and research report

## Testing & Validation

- [ ] `jq '.' specs/729_literature_chunking_audit/chunking-manifest.json` validates as JSON
- [ ] Manifest entry count matches expected totals (30+ subdirectories, 40+ flat files)
- [ ] All renamed files in Literature/ are accessible at new paths
- [ ] No orphaned references to old filenames in any index files

## Artifacts & Outputs

- `specs/729_literature_chunking_audit/plans/01_chunking-audit-plan.md` - this plan
- `specs/729_literature_chunking_audit/chunking-manifest.json` - machine-readable manifest
- `specs/729_literature_chunking_audit/chunking-manifest-summary.md` - human-readable summary with action items

## Rollback/Contingency

File renames in Phase 2 can be reverted by renaming back to original names. The manifest and summary are new files that can be deleted. No destructive operations are performed on file contents.
