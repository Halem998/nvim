# Implementation Plan: Update Literature Extension for sources/ Convention

- **Task**: 736 - Update literature extension for sources/ directory convention
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/736_literature_extension_sources_convention/reports/01_extension-sources-research.md
- **Artifacts**: plans/01_extension-sources-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update the literature extension to use the `sources/` subdirectory convention matching the refactored `~/Projects/Literature/` repository. Three files need changes: SKILL.md (convert mode output paths), literature-retrieve.sh (fallback scan path), and EXTENSION.md (documentation). The index-based retrieval path already works correctly because paths come from index.json which already has `sources/` prefix. Per-project `specs/literature/` directories remain flat (no `sources/` prefix).

### Research Integration

Research report confirmed that 196/196 index.json entries already have `sources/` prefix. Only the convert mode output path construction and fallback file scan need updating. The `literature-ingest.sh` script is explicitly out of scope.

### Roadmap Alignment

This task advances the "Literature centralization" item under Phase 2. That item is already marked complete for the initial centralization (task 710); this task extends it with the `sources/` convention alignment.

## Goals & Non-Goals

**Goals**:
- Convert mode in SKILL.md places new conversions under `sources/` when `LITERATURE_DIR` is active
- Fallback scan in `literature-retrieve.sh` prefers `sources/` subdirectory when it exists
- EXTENSION.md documents the `sources/` convention
- Per-project `specs/literature/` directories remain unaffected (no `sources/` prefix)

**Non-Goals**:
- Updating `literature-ingest.sh` (uses separate SQLite FTS5 pipeline)
- Migrating existing files in `~/Projects/Literature/` (already done)
- Changing index-based retrieval paths (already work correctly)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Per-project dirs get `sources/` prefix by mistake | H | L | Condition on `LITERATURE_DIR` env var, same check used for `lit_dir` assignment |
| Fallback scan misses files in edge cases | M | L | Only change scan root when `sources/` dir exists; unchanged behavior otherwise |
| Convert mode writes to wrong path | H | L | Set `sources_prefix` variable once early, used consistently in all branches |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update SKILL.md Convert Mode [NOT STARTED]

**Goal**: Add `sources_prefix` variable to convert mode so new conversions go under `sources/` when `LITERATURE_DIR` is active.

**Tasks**:
- [ ] Add `sources_prefix` variable definition after the `lit_dir` assignment in Convert Step 1 (around line 53-57 of SKILL.md). Set to `"sources/"` when `LITERATURE_DIR` is set and exists, empty string otherwise.
- [ ] Update content-aware chunking branch (around line 594): change `chunk_dir="$lit_dir/${basename_no_ext}"` to `chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"`
- [ ] Update `output_files` entry in content-aware branch (around line 606): change `"${basename_no_ext}/section${nn}_${slug}.md"` to `"${sources_prefix}${basename_no_ext}/section${nn}_${slug}.md"`
- [ ] Update mechanical fallback branch `chunk_dir` (around line 615): change `chunk_dir="$lit_dir/${basename_no_ext}"` to `chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"`
- [ ] Update single-file path (around line 620): change `output_files+=("${basename_no_ext}.md")` to `output_files+=("${sources_prefix}${basename_no_ext}.md")`
- [ ] Update mechanical multi-chunk `output_files` entry (around line 628): change `"${basename_no_ext}/${basename_no_ext}_part${nn}.md"` to `"${sources_prefix}${basename_no_ext}/${basename_no_ext}_part${nn}.md"`

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Add `sources_prefix` variable and update 5 path construction sites in convert mode

**Verification**:
- Grep for `sources_prefix` in SKILL.md confirms variable is defined and used in all 3 branches (content-aware, mechanical multi-chunk, single-file)
- Grep confirms no bare `${basename_no_ext}` path construction remains in output_files/chunk_dir without the prefix

---

### Phase 2: Update literature-retrieve.sh Fallback Scan [NOT STARTED]

**Goal**: Make the fallback file scan prefer `sources/` subdirectory when it exists, avoiding pickup of non-content files at the repo root.

**Tasks**:
- [ ] Add `sources/` directory check before the fallback `find` command (around line 168-172). If `$LIT_DIR/sources` exists, set `scan_dir="$LIT_DIR/sources"`; otherwise set `scan_dir="$LIT_DIR"`.
- [ ] Update the `find` command to use `$scan_dir` instead of `$LIT_DIR`

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/literature-retrieve.sh` - Add scan_dir variable and update fallback find command (lines 168-172)

**Verification**:
- Script still exits cleanly when `specs/literature/` has no `sources/` subdirectory (backward compatible)
- When `sources/` exists, only files under `sources/` are scanned in fallback mode

---

### Phase 3: Update EXTENSION.md Documentation [NOT STARTED]

**Goal**: Document the `sources/` subdirectory convention so users understand the directory structure difference between centralized and per-project literature directories.

**Tasks**:
- [ ] Add a "sources/ Subdirectory Convention" subsection after the existing "Source file co-location" paragraph (after line 29 of EXTENSION.md)
- [ ] Document that when `LITERATURE_DIR` is set, all content lives under `$LITERATURE_DIR/sources/`
- [ ] Clarify that per-project `specs/literature/` directories use the flat layout (no `sources/` prefix)
- [ ] Mention that `index.json` paths in the central repo are prefixed with `sources/`

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/EXTENSION.md` - Add sources/ convention documentation subsection

**Verification**:
- EXTENSION.md contains a section explaining the `sources/` convention
- Both centralized and per-project layouts are documented

## Testing & Validation

- [ ] Verify `sources_prefix` is defined conditionally in SKILL.md convert mode
- [ ] Verify all chunk_dir and output_files references in convert mode use `${sources_prefix}` prefix
- [ ] Verify `literature-retrieve.sh` fallback path checks for `sources/` directory
- [ ] Verify EXTENSION.md documents the `sources/` convention
- [ ] Verify no changes affect per-project `specs/literature/` behavior (no unconditional `sources/` prefix)

## Artifacts & Outputs

- `plans/01_extension-sources-plan.md` (this file)
- Modified: `.claude/extensions/literature/skills/skill-literature/SKILL.md`
- Modified: `.claude/extensions/core/scripts/literature-retrieve.sh`
- Modified: `.claude/extensions/literature/EXTENSION.md`

## Rollback/Contingency

All changes are to documentation files (SKILL.md pseudocode and EXTENSION.md) and one script. Revert with `git checkout` on the three files. No database migrations or state changes involved.
