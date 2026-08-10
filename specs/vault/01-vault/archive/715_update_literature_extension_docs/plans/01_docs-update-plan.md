# Implementation Plan: Task #715

- **Task**: 715 - Update literature extension documentation to reflect Zotero search and import capabilities
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Tasks 711 (zotero-search.sh), 714 (search + import pipeline)
- **Research Inputs**: specs/715_update_literature_extension_docs/reports/01_docs-update-research.md
- **Artifacts**: plans/01_docs-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update four documentation files to reflect Zotero search and import capabilities added by tasks 711 and 714. The implementation files (SKILL.md, literature.md command, zotero-search.sh, literature-agent.md) are already fully updated. The documentation gap exists in EXTENSION.md, README.md, core merge-source claudemd.md, and the generated CLAUDE.md. No cross-extension updates are needed (lean/formal use "literature" conceptually for proof sources, not the specs/literature/ system).

### Research Integration

Research report (01_docs-update-research.md) confirmed: manifest.json already correct; EXTENSION.md partially updated (missing 2 command rows); README.md missing all Zotero documentation and 4 index schema fields; claudemd.md missing 2 command rows and skill description update; CLAUDE.md needs matching edits to claudemd.md. No merge script exists -- CLAUDE.md must be edited directly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation needed for this meta task.

## Goals & Non-Goals

**Goals**:
- Add `--search "QUERY"` and `--task N` command rows to all command tables (EXTENSION.md, README.md, claudemd.md, CLAUDE.md)
- Update EXTENSION.md description to mention Zotero search/import
- Add 4 missing index schema fields to README.md (bib_key, zotero_key, zotero_path, project_tags)
- Add "Zotero Search and Import" workflow section to README.md
- Update skill-literature description in claudemd.md and CLAUDE.md
- Add scripts/zotero-search.sh to README.md Provided Artifacts table
- Update README.md Directory Convention to include pdfs/ subdirectory

**Non-Goals**:
- Modifying implementation files (already complete)
- Updating lean or formal extension documentation
- Creating or modifying merge scripts
- Updating manifest.json (already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CLAUDE.md direct edit out of sync with merge-source | M | L | Edit claudemd.md first, then apply identical command-table changes to CLAUDE.md |
| README.md section ordering confusion | L | L | Add Zotero section after Content-Aware Chunking for logical flow |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update EXTENSION.md and core merge-source claudemd.md [COMPLETED]

**Goal**: Add Zotero command rows and description updates to the extension-level docs and the core merge source that feeds CLAUDE.md generation.

**Tasks**:
- [ ] Update EXTENSION.md line 1-4 description to mention Zotero search/import
- [ ] Add 2 new command rows to EXTENSION.md Commands table: `--search "QUERY"` and `--task N`
- [ ] Add 2 new command rows to claudemd.md `/literature` command table (after `--index FILE` row)
- [ ] Update claudemd.md skill-literature description to include "search/import from Zotero"

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/EXTENSION.md` - Description update (lines 1-4), 2 new command rows (after line 60)
- `.claude/extensions/core/merge-sources/claudemd.md` - 2 new command rows (after line 111), skill-literature description update (line 203)

**Verification**:
- EXTENSION.md contains 7 command rows (was 5)
- EXTENSION.md description mentions "Zotero"
- claudemd.md `/literature` table has 7 rows
- claudemd.md skill-literature row mentions "search/import from Zotero"

---

### Phase 2: Update README.md [COMPLETED]

**Goal**: Add comprehensive Zotero documentation to the user-facing README including commands, index schema fields, workflow section, directory layout, and artifact table.

**Tasks**:
- [ ] Add 2 new command rows to README.md Commands table: `--search "QUERY"` and `--task N`
- [ ] Update Directory Convention section to add `pdfs/` subdirectory to layout example and mention LITERATURE_DIR centralized repo
- [ ] Add 4 missing fields to Index Schema table: `bib_key`, `zotero_key`, `zotero_path`, `project_tags`
- [ ] Add new "Zotero Search and Import" section after Content-Aware Chunking, documenting: setup (Better BibTeX CSL-JSON export), usage (`--search` and `--task` commands), scoring algorithm (weighted multi-field), interactive result selection with status tags, import pipeline (symlink -> convert -> index patch -> commit), graceful degradation
- [ ] Add `scripts/zotero-search.sh` entry to Provided Artifacts table

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/README.md` - Commands table (line 22), Directory Convention (lines 33-42), Index Schema (lines 66-80), new Zotero section (after line 58), Provided Artifacts (lines 105-109)

**Verification**:
- README.md Commands table has 7 rows
- Index Schema table has 14 fields (was 10 base + 2 missing = 12 shown, now 16 total)
- "Zotero Search and Import" section exists with setup, usage, scoring, import pipeline subsections
- Directory Convention shows `pdfs/` subdirectory
- Provided Artifacts includes scripts/zotero-search.sh

---

### Phase 3: Update CLAUDE.md [COMPLETED]

**Goal**: Apply matching command-table and skill-description changes to the generated CLAUDE.md file, keeping it consistent with the claudemd.md merge source.

**Tasks**:
- [ ] Add 2 new `/literature` command rows to CLAUDE.md Command Reference table (matching claudemd.md changes from Phase 1)
- [ ] Update skill-literature description in CLAUDE.md Skill-to-Agent Mapping table to match claudemd.md

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/CLAUDE.md` - `/literature` command rows in Command Reference, skill-literature row in Skill-to-Agent Mapping

**Verification**:
- CLAUDE.md `/literature` command table has 7 rows
- CLAUDE.md skill-literature description mentions "search/import from Zotero"
- Command rows match claudemd.md exactly

## Testing & Validation

- [ ] All 4 files contain `--search` and `--task` command documentation
- [ ] EXTENSION.md description mentions Zotero
- [ ] README.md Index Schema includes bib_key, zotero_key, zotero_path, project_tags
- [ ] README.md contains "Zotero Search and Import" section
- [ ] README.md Provided Artifacts lists scripts/zotero-search.sh
- [ ] CLAUDE.md command table and skill description match claudemd.md
- [ ] No cross-extension files modified (lean, formal unchanged)

## Artifacts & Outputs

- specs/715_update_literature_extension_docs/plans/01_docs-update-plan.md (this plan)
- `.claude/extensions/literature/EXTENSION.md` (updated)
- `.claude/extensions/literature/README.md` (updated)
- `.claude/extensions/core/merge-sources/claudemd.md` (updated)
- `.claude/CLAUDE.md` (updated)

## Rollback/Contingency

All changes are documentation-only edits to markdown files. Revert via `git checkout -- <file>` for any individual file, or `git reset HEAD~1` to undo the entire commit.
