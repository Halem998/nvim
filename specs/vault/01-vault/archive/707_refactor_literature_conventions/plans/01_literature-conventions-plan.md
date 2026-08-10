# Implementation Plan: Task #707

- **Task**: 707 - refactor_literature_conventions
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/707_refactor_literature_conventions/reports/01_literature-conventions-research.md
- **Artifacts**: plans/01_literature-conventions-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements three convention changes to the literature extension: (1) gitignore PDF/DJVU source files in specs/literature/, (2) replace the fixed 10-page-per-chunk approach with content-aware 4,000-line logical splitting, and (3) enrich the index.json schema with author, title, year, doc_type, source_format, parent_doc, and page_range fields. All changes apply to the canonical extension source in `.claude/extensions/literature/` and must be mirrored to the synced copies in `.claude/agents/`, `.claude/commands/`, and `.claude/skills/`.

### Research Integration

The research report (01_literature-conventions-research.md) identified the complete file inventory: 3 extension source files and 3 synced copies, plus `.gitignore`, `literature-organization.md`, `EXTENSION.md`, and `README.md`. Key findings: no `specs/literature/` directory exists yet (no migration needed), `literature-retrieve.sh` does not require changes (it only reads existing fields), and the existing advisory metadata convention fields in `literature-organization.md` already partially align with the new schema. The recommended ordering is gitignore -> index schema -> chunking -> documentation sweep.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. The task advances agent system quality in the literature extension but is not explicitly listed.

## Goals & Non-Goals

**Goals**:
- Add `.gitignore` patterns for PDF/DJVU files in `specs/literature/`
- Replace page-count chunking with content-aware 4,000-line logical splitting in SKILL.md
- Extend index.json schema with `authors`, `title`, `year`, `doc_type`, `source_format`, `parent_doc`, `page_range` fields
- Update all documentation files (extension source + synced copies) consistently

**Non-Goals**:
- Modifying `literature-retrieve.sh` (it already works with the existing fields it reads)
- Migrating existing data (no `specs/literature/` exists yet)
- Changing the `manifest.json` structure
- Adding runtime validation of the new schema fields (validation is advisory)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Synced copies diverge from extension source | H | M | Each phase explicitly lists both canonical and synced files; verify sync at end |
| Content-aware heading regex misses edge cases | M | M | Keep user confirmation step (already exists in convert flow); document supported patterns |
| New schema fields create friction for manual `--index` usage | L | L | Auto-detect fields from filename/context; only prompt for what cannot be inferred |
| SKILL.md edit complexity (large file, many sections) | M | L | Phase 3 targets specific convert steps by line reference from research report |

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

### Phase 1: Gitignore and Co-location Convention [COMPLETED]

**Goal**: Add gitignore patterns for PDF/DJVU source files in specs/literature/ and document the co-location convention.

**Tasks**:
- [x] Add `specs/literature/**/*.pdf` pattern to `.gitignore` *(completed)*
- [x] Add `specs/literature/**/*.djvu` pattern to `.gitignore` *(completed)*
- [x] Update SKILL.md Standards Reference section to describe co-located, gitignored source convention (extension source: `.claude/extensions/literature/skills/skill-literature/SKILL.md`) *(completed)*
- [x] Mirror SKILL.md change to synced copy: `.claude/skills/skill-literature/SKILL.md` *(completed: hardlinked — same inode, no separate copy needed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.gitignore` - Add 2 lines for PDF/DJVU patterns
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Update Standards Reference section
- `.claude/skills/skill-literature/SKILL.md` - Sync same change (if synced copy exists; create if needed)

**Verification**:
- `grep "specs/literature" .gitignore` returns both patterns
- SKILL.md Standards Reference section mentions co-located gitignored sources

---

### Phase 2: Index Schema Enhancement [COMPLETED]

**Goal**: Extend the index.json entry schema with new retrieval-useful fields and update all schema-documenting files.

**Tasks**:
- [x] Update SKILL.md Convert Step 3f/3g (index write) to include new fields: `authors` (array), `title` (string), `year` (integer, nullable), `doc_type` (paper/book/chapter/section), `source_format` (pdf/djvu/manual), `parent_doc` (string, nullable), `page_range` (string, nullable) *(completed)*
- [x] Update SKILL.md Index Step 4/5 (`--index` mode) to prompt for or auto-detect the new fields *(completed)*
- [x] Update SKILL.md Validate Step 2 to check that new required fields are present *(completed)*
- [x] Update `literature-agent.md` Index Schema section with the full field table (extension source: `.claude/extensions/literature/agents/literature-agent.md`) *(completed)*
- [x] Mirror `literature-agent.md` change to synced copy: `.claude/agents/literature-agent.md` *(completed: symlinked — no separate copy needed)*
- [x] Update `literature-organization.md` to replace advisory convention fields with the authoritative schema table (`.claude/context/guides/literature-organization.md`) *(completed)*
- [x] Mirror SKILL.md changes to synced copy: `.claude/skills/skill-literature/SKILL.md` *(completed: hardlinked — same inode, no separate copy needed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Convert 3f/3g, Index 4/5, Validate Step 2
- `.claude/skills/skill-literature/SKILL.md` - Sync same SKILL.md changes
- `.claude/extensions/literature/agents/literature-agent.md` - Index Schema section
- `.claude/agents/literature-agent.md` - Sync same agent doc changes
- `.claude/context/guides/literature-organization.md` - Full schema table, remove advisory/required distinction

**Verification**:
- SKILL.md jq commands in Convert 3g include all new fields
- SKILL.md `--index` mode prompts for or auto-detects new fields
- `literature-agent.md` Index Schema section lists all fields with types
- `literature-organization.md` has a single unified field table

---

### Phase 3: Content-Aware Chunking [COMPLETED]

**Goal**: Replace the fixed 10-page-per-chunk algorithm with content-aware 4,000-line logical splitting that detects chapter/section boundaries.

**Tasks**:
- [x] Replace Convert Step 3b chunking algorithm: remove `pages_per_chunk=10` approach; implement line-count threshold (4000 lines) with heading detection regex (`^(Chapter|CHAPTER)\s+\d+`, `^\d+\s+[A-Z]`, `^Part\s+[IVX\d]+`, `^#{1,3}\s+`) *(completed)*
- [x] Add small-section merging logic: adjacent sections below 500 lines are merged to approach the 4000-line target *(completed)*
- [x] Add fallback: when no headings detected, split mechanically at 4000-line boundaries with sequential naming (`_part01.md`, `_part02.md`) *(completed)*
- [x] Update Convert Step 3c user prompt (AskUserQuestion) to show detected section names or line ranges instead of page ranges *(completed)*
- [x] Update Convert Step 3d output file naming: chapters use `{basename}/sectionNN_{slug}.md`, fallback uses `{basename}/{basename}_partNN.md` *(completed)*
- [x] Update Convert Step 4 display summary table to reflect new naming *(completed)*
- [x] Update the `parent_doc` and `doc_type` fields in Convert 3g index writes for chunked entries (set `doc_type: "section"`, `parent_doc: parent_id`) *(completed)*
- [x] Mirror all SKILL.md changes to synced copy: `.claude/skills/skill-literature/SKILL.md` *(completed: hardlinked — same inode, no separate copy needed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Convert Steps 3b, 3c, 3d, 3e, 3g, Step 4
- `.claude/skills/skill-literature/SKILL.md` - Sync same changes

**Verification**:
- SKILL.md Convert Step 3b no longer references `pages_per_chunk`
- Heading detection regex patterns are present in the chunking algorithm
- Fallback to 4000-line mechanical splitting is documented
- Output file naming uses structure-aware convention (not page ranges)
- Chunked entries set `doc_type: "section"` and `parent_doc` in index writes

---

### Phase 4: Documentation Sweep [COMPLETED]

**Goal**: Update all remaining documentation files to consistently describe the new conventions (gitignored sources, content-aware chunking, enriched schema).

**Tasks**:
- [x] Update `EXTENSION.md` Directory Convention section to describe co-located gitignored sources, content-aware chunking, and enriched schema (`.claude/extensions/literature/EXTENSION.md`) *(completed)*
- [x] Update `README.md` to reflect all three convention changes (`.claude/extensions/literature/README.md`) *(completed)*
- [x] Update `commands/literature.md` State Management section if it references source file handling or chunking (`.claude/extensions/literature/commands/literature.md`) *(completed)*
- [x] Mirror `commands/literature.md` changes to synced copy: `.claude/commands/literature.md` *(completed: symlinked — same file)*
- [x] Final consistency check: verify extension source files and synced copies are identical for `SKILL.md`, `literature-agent.md`, and `commands/literature.md` *(completed: SKILL.md hardlinked identical; agent.md and commands/literature.md are symlinks)*

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/literature/EXTENSION.md` - Directory Convention, chunking description, schema summary
- `.claude/extensions/literature/README.md` - All convention sections
- `.claude/extensions/literature/commands/literature.md` - State Management / source handling
- `.claude/commands/literature.md` - Sync same command doc changes

**Verification**:
- `diff` between each extension source file and its synced copy shows no differences
- EXTENSION.md mentions gitignored PDFs, content-aware chunking, and the new index fields
- README.md is consistent with EXTENSION.md

---

## Testing & Validation

- [x] `grep -c "specs/literature" .gitignore` returns 2 (both patterns present) *(verified: 2)*
- [x] SKILL.md contains no reference to `pages_per_chunk=10` *(verified: 0 occurrences)*
- [x] SKILL.md Convert 3g jq command includes `authors`, `title`, `year`, `doc_type`, `source_format`, `parent_doc`, `page_range` *(verified: 54 occurrences of new field names)*
- [x] `literature-agent.md` Index Schema lists all new fields with types *(verified: 9 occurrences of new field names)*
- [x] `literature-organization.md` has a single unified schema table *(verified: 11 occurrences of new field names)*
- [x] Extension source files and synced copies are byte-identical (diff returns 0) *(verified: SKILL.md hardlinked; agent.md and commands/literature.md are symlinks)*
- [x] `literature-retrieve.sh` is unchanged (no modifications needed) *(verified: not modified)*

## Artifacts & Outputs

- `specs/707_refactor_literature_conventions/plans/01_literature-conventions-plan.md` (this plan)
- `specs/707_refactor_literature_conventions/summaries/01_literature-conventions-summary.md` (after implementation)

## Rollback/Contingency

All changes are to documentation and skill definition files within `.claude/`. Rollback is straightforward via `git checkout` of the affected files. No runtime state, data migrations, or external dependencies are involved. If any phase fails, prior phases remain independently valid.
