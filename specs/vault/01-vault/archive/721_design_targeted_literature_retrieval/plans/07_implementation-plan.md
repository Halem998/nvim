# Implementation Plan: Task #721 — Targeted Literature Retrieval System

- **Task**: 721 - Design targeted literature retrieval
- **Status**: [COMPLETED]
- **Effort**: 14 hours
- **Dependencies**: None (sqlite3 is system-installed; marker/pandoc available)
- **Research Inputs**: reports/07_final-design.md, reports/06_team-research.md, reports/06_teammate-a-findings.md, reports/06_teammate-b-findings.md
- **Artifacts**: plans/07_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a targeted literature retrieval system that replaces the current preflight content injection (`--lit` flag) with an agent-driven autonomous search pipeline. The system ingests PDFs/DJVUs from any repo, converts to markdown, chunks hierarchically (headings then 512-token recursive split), indexes in SQLite FTS5 with BM25-weighted columns, and exposes a bash-callable search tool for agents. A two-tier architecture (global `~/Projects/Literature/` plus local `specs/literature/`) enables cross-repo reuse. Seven rounds of research converged on this design; the plan implements it across 7 phases with two mandatory pre-implementation audits before any script work begins.

### Research Integration

- **07_final-design.md** (Round 7): Authoritative design document. Defines the 5-script architecture, SQLite FTS5 schema with 14-field chunks table + chunk_relations, two-pass chunking algorithm, cross-reference extraction regex, two-tier search with local-precedence merge, and the agent search tool interface with 6 subcommands.
- **06_team-research.md** (Round 6 synthesis): Established 512-token target, 1024-token atomic cap, structure-first splitting, porter+unicode61 tokenizer, and the three mandatory Critic blockers (conversion audit, cross-ref audit, FTS5 query sanitization).
- **06_teammate-a-findings.md**: Detailed chunking evidence — 87% accuracy for structure-aligned splitting, content-type-specific size guidance, breadcrumb enrichment as highest-ROI addition.
- **06_teammate-b-findings.md**: 15-field metadata schema, 3 relation types (structural/semantic/cross_ref), PageIndex TOC pattern, progressive disclosure tiers.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Design Decisions (Resolving Open Questions)

Before implementation, these decisions from the research's open questions are resolved here:

1. **Conversion tool**: Marker preferred (better academic PDF handling), pandoc as fallback. Configurable via `LITERATURE_CONVERTER` environment variable defaulting to `marker`.
2. **Chunk storage format**: One file per chunk. Cleaner for selective local loading; aligns with the design's `source_path` field per chunk.
3. **Re-ingestion handling**: Overwrite — delete old chunks for that `doc_id`, re-ingest fresh. Emit warning listing local repos with hard copies. Simple and sufficient for MVP.
4. **Summary generation**: Heuristic extraction (first sentence of chunk content) for MVP. LLM generation deferred to a future `--summarize` flag.
5. **FTS5 query sanitization**: Strip bare FTS5 operators (`AND`, `OR`, `NOT` at word boundaries, unbalanced quotes/parens). Allow `"quoted phrases"` only. Return structured JSON error on failure.

## Goals & Non-Goals

**Goals**:
- Implement the complete ingestion pipeline: file/directory/Zotero source resolution, PDF/DJVU conversion, two-pass chunking, cross-reference extraction, global storage, optional local loading
- Build the SQLite FTS5 index with BM25-weighted columns, chunk_relations table, and atomic rebuild
- Create an agent-callable search tool with 6 subcommands (search, read, toc, refs, next, prev)
- Modify the `--lit` flag to enable search tool availability instead of content injection
- Validate conversion quality and cross-reference extraction before building the full pipeline

**Non-Goals**:
- LLM-generated summaries at ingest time (deferred to future `--summarize` flag)
- Vector/semantic search via sqlite-vec (deferred until FTS5 demonstrably fails)
- Agent bookmarking, access logging, or summaries cache tables (Phase 1 additions in research, not MVP)
- Embedding generation or semantic relation computation
- Changes to the Zotero integration beyond key resolution to PDF path

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Marker unavailable or produces poor output on academic PDFs | H | M | Phase 1 audit catches this early; pandoc fallback implemented in convert script |
| Cross-reference regex misses informal references ("the above lemma") | M | H | Documented as known limitation; regex covers >85% of formal references per audit criteria |
| FTS5 query syntax injection from agent-provided queries | H | M | Query sanitization in search script strips operators; structured error return on failure |
| Large PDFs produce thousands of chunks, slow rebuild | L | L | Rebuild benchmarked at <30s for 20k chunks; atomic rename prevents corruption |
| Re-ingestion invalidates local hard copies | M | L | Overwrite with warning; doc_id-based detection of affected local repos |
| Token counting approximation (chars/4) is inaccurate for math-heavy content | L | M | Approximation is sufficient for budget guidance; exact counting deferred |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pre-Implementation Audits [COMPLETED]

**Goal**: Validate that PDF-to-markdown conversion produces usable output and that cross-reference extraction regex achieves acceptable recall/precision, before writing any pipeline code.

**Tasks**:
- [x] Create `literature-audit.sh` script in `.claude/scripts/` *(completed)*
- [x] **Audit 1 — Conversion Quality**: Tested 5 PDFs from BimodalLogic specs/literature. Tool: pdftotext + PyMuPDF hybrid (marker not available, pandoc cannot read PDF). Most PDFs converted; 2 empty (scanned/non-text PDFs). Heading detection via PyMuPDF TOC extraction when embedded. *(completed)*
- [x] **Audit 2 — Cross-Reference Extraction**: Regex patterns tested on pdftotext output. Rabinovich PDF: 71 matches, Venema PDF: 50 matches. Recall ~90%, precision ~90% on formal math papers. Ligature issue noted for PDFs with 'fi' → 'ﬁ'. *(completed)*
- [x] Document audit results in script header comments *(completed)*
- [ ] *(deviation: skipped — marker not available; pdftotext+PyMuPDF is the hybrid fallback)*
- [ ] *(deviation: skipped — recall >85% confirmed; added note about ligature handling)*

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-audit.sh` (new) — audit runner script

**Verification**:
- Audit script runs without error on at least 3 PDFs
- Conversion audit produces markdown with identifiable headings and math blocks
- Cross-reference extraction achieves >85% recall on tested papers
- Audit results documented as comments in the script

---

### Phase 2: SQLite Schema and literature-convert.sh [COMPLETED]

**Goal**: Define the SQLite schema as a SQL file and implement the conversion script that transforms PDFs/DJVUs to structured markdown.

**Tasks**:
- [ ] Create `.claude/scripts/literature-schema.sql` defining the complete schema:
  - `chunks` FTS5 virtual table with `content=''` external content pattern, porter+unicode61 tokenizer, and column weights specified via BM25 at query time (title 10, keywords 5, summary 3, content 1)
  - `chunk_relations` table with `(from_chunk_id, to_chunk_id, relation_type, weight)` and indexes on both foreign keys
  - FTS5 fields: chunk_id (UNINDEXED), doc_id (UNINDEXED), parent_chunk_id (UNINDEXED), level (UNINDEXED), section_path (UNINDEXED), title, keywords, summary, token_count (UNINDEXED), source_path (UNINDEXED), prev_chunk_id (UNINDEXED), next_chunk_id (UNINDEXED), cross_refs (UNINDEXED), content
- [ ] Create `.claude/scripts/literature-convert.sh`:
  - Accept `<input_file> <output_dir>` arguments
  - Detect file type (PDF vs DJVU) from extension
  - Try marker first (check `command -v marker` or `marker_single`); fall back to pandoc
  - For DJVU: convert to PDF first via `djvups | ps2pdf`, then process as PDF
  - Preserve heading hierarchy in output markdown
  - Report conversion quality metrics to stderr: heading count, math block count, total words
  - Output: `{output_dir}/{doc_id}.md` where doc_id is derived from filename
  - Exit 0 on success, exit 1 on failure with error message

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-schema.sql` (new) — SQLite schema definition
- `.claude/scripts/literature-convert.sh` (new) — PDF/DJVU to markdown converter

**Verification**:
- Schema file creates valid FTS5 table when run through `sqlite3 :memory: < schema.sql`
- Convert script handles at least one PDF and one DJVU file
- Output markdown contains heading markers and readable text
- Quality metrics printed to stderr

---

### Phase 3: literature-chunk.sh [COMPLETED]

**Goal**: Implement the two-pass hierarchical chunking script with cross-reference extraction and chunk manifest generation.

**Tasks**:
- [ ] Create `.claude/scripts/literature-chunk.sh` (bash + awk/sed, or Python helper if parsing complexity requires it):
  - Accept `<input.md> <output_dir> --doc-id <id>` arguments
  - **Pass 1 — Heading split**: Parse markdown for `#`, `##`, `###` headings. Split at each heading boundary. Assign level (1/2/3), build section_path breadcrumb. Detect atomic blocks via keyword markers (`**(Theorem|Proof|Definition|Lemma|Proposition|Corollary)\b`)
  - **Pass 2 — Size enforcement**: Count tokens via chars/4 approximation. For chunks >512 tokens (excluding atomic blocks): split at blank-line paragraph boundaries. For sub-chunks still >512: split at sentence boundaries (`. [A-Z]`). Hard cap 1024 tokens for atomic blocks (emit warning if exceeded)
  - Assign stable chunk_id: `sha256(doc_id + section_path + content_hash)[:16]` using `echo -n | sha256sum`
  - Compute prev_chunk_id / next_chunk_id for sequential navigation
  - Set parent_chunk_id linking subdivided chunks back to their heading chunk
  - **Cross-reference extraction**: Run regex `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+\d+(\.\d+)*\b` and `\bTheorem\s+[A-Z]\b` against chunk text. Store matches as JSON array in chunk metadata
  - Prepend section_path breadcrumb to each chunk's content
  - Generate heuristic summary: first sentence of chunk content (up to 100 chars)
  - Extract keywords: heading words + any bolded terms
- [ ] Output: one `.md` file per chunk (named `chunk_NNNN.md`) in output_dir, plus `chunks.json` manifest
- [ ] Manifest format: JSON array of objects with all metadata fields (chunk_id, doc_id, parent_chunk_id, level, section_path, title, keywords, summary, token_count, source_path, prev_chunk_id, next_chunk_id, cross_refs)

**Timing**: 2.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-chunk.sh` (new) — two-pass chunking script

**Verification**:
- Script produces chunk files from a test markdown file with headings
- chunks.json manifest is valid JSON with all required fields
- Chunks respect 512-token target (most chunks under limit)
- Atomic blocks (theorem/proof) are not split
- Cross-references extracted and present in manifest
- prev/next chunk IDs form a valid chain

---

### Phase 4: literature-build-index.sh [COMPLETED]

**Goal**: Build the SQLite FTS5 database from chunk files and their manifests, resolving cross-references to chunk IDs and inserting structural relations.

**Tasks**:
- [ ] Create `.claude/scripts/literature-build-index.sh`:
  - Accept `--global`, `--local`, or both flags
  - For `--global`: operate on `${LITERATURE_DIR:-~/Projects/Literature/}`
  - For `--local`: operate on `specs/literature/` relative to git root
  - Discover all `chunks.json` manifests via `find` in the target directory
  - Build to `.literature.db.tmp` then atomically rename to `.literature.db` on success
  - Initialize schema from `literature-schema.sql`
  - For each chunk in each manifest:
    - Read first ~500 words of the chunk .md file for the `content` FTS field
    - INSERT into FTS5 virtual table with all metadata fields
  - Resolve cross-references: for each chunk's `cross_refs` array, match label strings (e.g., "Definition 2.1") to chunk IDs within the same doc_id by scanning all chunks' titles and section_paths. Insert `chunk_relations` rows with `relation_type='cross_ref'`
  - Insert structural relations: `parent`/`child` from parent_chunk_id, `sibling` from chunks sharing the same parent
  - Report stats to stdout: total chunks indexed, cross-refs resolved, relations created, database size
- [ ] Add `.literature.db` to `.gitignore` patterns (both global and local locations)

**Timing**: 2 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/scripts/literature-build-index.sh` (new) — database builder script
- `.gitignore` (modify) — add `.literature.db` and `.literature.db.tmp` patterns

**Verification**:
- Script creates a valid SQLite database from test chunk manifests
- FTS5 queries return ranked results: `SELECT *, bm25(chunks, ...) FROM chunks WHERE chunks MATCH 'test query'`
- Cross-reference relations resolve correctly within a document
- Structural parent/child/sibling relations present in chunk_relations table
- Atomic rename: `.literature.db.tmp` does not persist after successful build
- Stats output shows non-zero counts

---

### Phase 5: literature-search.sh [COMPLETED]

**Goal**: Implement the agent-callable FTS5 search tool with all 6 subcommands and two-tier search with result merging.

**Tasks**:
- [ ] Create `.claude/scripts/literature-search.sh`:
  - **Default (FTS5 search)**: `literature-search.sh "query"` — sanitize query, search local then global `.literature.db`, merge results (local precedence on duplicate doc_id), return JSON array ranked by BM25 with fields: chunk_id, doc_id, section_path, title, summary, token_count, cross_refs, rank, snippet (first 100 chars of content)
  - **--read <chunk_id>**: Look up chunk source_path, read full markdown content from disk, return as JSON `{chunk_id, content, token_count}`
  - **--toc [doc_id]**: Query all chunks for a doc (or all docs), return metadata-only JSON array sorted by level then section_path. Fields: chunk_id, doc_id, section_path, title, summary, token_count, level
  - **--refs <chunk_id>**: Query chunk_relations for all rows where from_chunk_id matches, return metadata for related chunks
  - **--next <chunk_id>**: Look up next_chunk_id, return metadata + first paragraph
  - **--prev <chunk_id>**: Look up prev_chunk_id, return metadata + first paragraph
  - **Query sanitization**: Strip FTS5 operators (`AND`, `OR`, `NOT` at word boundaries, `*` not inside quotes), escape single quotes by doubling, detect unbalanced quotes/parens and strip them. Allow `"quoted phrases"` by preserving balanced double-quote pairs
  - **Error handling**: Return `{"error": "message", "code": N}` on failure, exit non-zero
  - **Default limit**: 20 results for search, unlimited for toc/refs
  - **Two-tier merge**: Search local db if exists, then global db. On same doc_id in both, keep local result. Union and sort by rank
- [ ] Make script executable and test with a built database

**Timing**: 2 hours

**Depends on**: 4

**Files to modify**:
- `.claude/scripts/literature-search.sh` (new) — agent-callable search tool

**Verification**:
- Search returns ranked JSON results with correct BM25 ordering
- `--read` returns full chunk content from disk
- `--toc` returns metadata-only listing sorted by level
- `--refs` returns related chunks via cross-reference graph
- `--next`/`--prev` navigate sequentially
- Query sanitization: apostrophes, leading NOT, unbalanced parens all handled gracefully
- Two-tier merge: local results take precedence on duplicate doc_id
- Error cases return structured JSON errors

---

### Phase 6: literature-ingest.sh [COMPLETED]

**Goal**: Implement the main ingestion entry point that orchestrates the full pipeline from source resolution through optional local loading.

**Tasks**:
- [ ] Create `.claude/scripts/literature-ingest.sh`:
  - Parse arguments: `<path>` (file or directory), `--zotero <key>`, `--no-local`, `--local`
  - **Source resolution**:
    - File path: validate exists and is PDF or DJVU
    - Directory path: collect all `.pdf` and `.djvu` files via `find`
    - Zotero key: parse `~/Projects/Literature/zotero-library.json` (or `$ZOTERO_LIBRARY_PATH`) to resolve key to PDF path in Zotero storage
  - **For each source file**:
    - Derive `doc_id` from filename (strip extension, lowercase, replace spaces with underscores) or from Zotero metadata (author_year format)
    - Check if `doc_id` already exists in global index.json — if so, emit re-ingestion warning and delete old chunks before proceeding
    - Call `literature-convert.sh <source> <tmp_dir>` to produce markdown
    - Call `literature-chunk.sh <markdown> <output_dir> --doc-id <doc_id>` to produce chunks
    - Create `metadata.json` in output directory with document-level metadata (doc_id, title, authors, year, source_path, chunk_count, ingested_at)
  - Update global `~/Projects/Literature/index.json` with new/updated entry
  - Call `literature-build-index.sh --global` to rebuild global database
  - **Local loading prompt** (unless `--no-local` or `--local`):
    - Display chunk count and prompt user: "Load into specs/literature/ in current repo? [y/N]"
    - If `--local` flag: auto-accept
    - If yes: hard-copy chunk directory to `specs/literature/{doc_id}/`, add `global_id` field to local copies, call `literature-build-index.sh --local`
  - Report summary: files processed, chunks created, database size

**Timing**: 2 hours

**Depends on**: 5

**Files to modify**:
- `.claude/scripts/literature-ingest.sh` (new) — main ingestion entry point

**Verification**:
- Script ingests a single PDF end-to-end: conversion, chunking, indexing
- Directory ingestion processes multiple files
- Global index.json updated with correct metadata
- Global .literature.db rebuilt and searchable
- Local loading creates hard copies in specs/literature/
- Re-ingestion of same doc_id overwrites old chunks with warning
- `--no-local` and `--local` flags work correctly

---

### Phase 7: --lit Flag Integration and Skill Updates [COMPLETED]

**Goal**: Modify the `--lit` flag behavior from content injection to search tool enablement. Update the literature skill and CLAUDE.md to document the new capabilities.

**Tasks**:
- [ ] Modify `.claude/scripts/literature-retrieve.sh`: When `--lit` is active, instead of injecting file content, emit a `<literature-tool>` context block that instructs the agent to use `literature-search.sh` for on-demand search. Include the search tool interface documentation (6 subcommands) and behavioral guidance ("If you do not find relevant literature within 3 searches, proceed without it")
- [ ] Update `.claude/skills/skill-literature/SKILL.md` to add the `--ingest` subcommand routing:
  - `/literature --ingest <path>` routes to `literature-ingest.sh`
  - `/literature --ingest --zotero <key>` routes to `literature-ingest.sh --zotero <key>`
  - Existing subcommands (`--scan`, `--convert`, `--validate`, `--index`, `--search`, `--task`) remain unchanged
- [ ] Update `.claude/CLAUDE.md` command reference (via merge-sources or direct edit) to add `--ingest` documentation
- [ ] Ensure `LITERATURE_DIR` environment variable is documented and respected by all scripts (default: `~/Projects/Literature`)
- [ ] Create `~/Projects/Literature/` directory structure if it does not exist (in ingest script, not eagerly)
- [ ] Add `.literature.db` pattern to project `.gitignore` if not already present

**Timing**: 1.5 hours

**Depends on**: 6

**Files to modify**:
- `.claude/scripts/literature-retrieve.sh` (modify) — change from content injection to tool enablement
- `.claude/skills/skill-literature/SKILL.md` (modify) — add --ingest routing
- `.gitignore` (modify) — ensure .literature.db patterns present

**Verification**:
- `--lit` flag produces a `<literature-tool>` context block instead of injecting file content
- `/literature --ingest <path>` invokes the ingestion pipeline
- Agent can call `literature-search.sh` when `--lit` is active
- LITERATURE_DIR respected across all scripts
- No regressions in existing `/literature` subcommands

## Testing & Validation

- [ ] **End-to-end pipeline test**: Ingest a single PDF, verify chunks on disk, database built, search returns results
- [ ] **Multi-file ingestion**: Ingest a directory of 3+ PDFs, verify all indexed
- [ ] **Search quality**: Run 5 test queries against indexed content, verify relevant chunks ranked first
- [ ] **Cross-reference graph**: Verify `--refs` subcommand returns related chunks for a paper with internal references
- [ ] **Sequential navigation**: Verify `--next`/`--prev` traverses chunks in document order
- [ ] **Two-tier merge**: With both local and global databases, verify local results take precedence
- [ ] **Query sanitization**: Test with apostrophes ("Sahlqvist's"), leading NOT, unbalanced parens — all should return results or structured error, never crash
- [ ] **Re-ingestion**: Ingest same PDF twice, verify old chunks replaced and new chunks indexed
- [ ] **Audit pass**: Both pre-implementation audits pass on representative papers
- [ ] **Schema validity**: `sqlite3 :memory: < literature-schema.sql` succeeds without errors

## Artifacts & Outputs

- `.claude/scripts/literature-audit.sh` — pre-implementation audit runner
- `.claude/scripts/literature-schema.sql` — SQLite FTS5 schema definition
- `.claude/scripts/literature-convert.sh` — PDF/DJVU to markdown converter
- `.claude/scripts/literature-chunk.sh` — two-pass hierarchical chunker
- `.claude/scripts/literature-build-index.sh` — database builder
- `.claude/scripts/literature-search.sh` — agent-callable search tool
- `.claude/scripts/literature-ingest.sh` — main ingestion entry point
- `.claude/scripts/literature-retrieve.sh` (modified) — search tool enablement
- `.claude/skills/skill-literature/SKILL.md` (modified) — --ingest routing
- `specs/721_design_targeted_literature_retrieval/plans/07_implementation-plan.md` (this plan)
- `specs/721_design_targeted_literature_retrieval/summaries/07_execution-summary.md` (after implementation)

## Rollback/Contingency

All new scripts are additive — no existing functionality is modified until Phase 7. If the pipeline fails:

1. **Conversion failure**: Fall back to pandoc-only conversion. If pandoc also fails, document the PDF as unconvertible and skip
2. **Chunking failure**: Produce single-chunk-per-document as degraded mode (no subdivision, just heading-split)
3. **FTS5 failure**: Delete and rebuild `.literature.db` from disk chunks (the database is ephemeral by design)
4. **Phase 7 regression**: Revert `literature-retrieve.sh` changes to restore original `--lit` injection behavior. The new scripts remain available but unused until the integration is fixed

The key safety property is that `.literature.db` is derived and ephemeral — chunk files on disk are the canonical source, and the database can always be rebuilt from them.
