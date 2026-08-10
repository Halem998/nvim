# Final Design Report: Task #721 — Literature Ingestion, Chunking, and Agent Search

**Task**: 721 - Design targeted literature retrieval
**Date**: 2026-06-15
**Rounds synthesized**: 1-7
**Design status**: User-confirmed, ready for planning

---

## Design Summary

- Literature is ingested from any repo via `/literature --ingest <path-or-zotero-key>`, converted to markdown, chunked hierarchically, and stored in a global `~/Projects/Literature/` directory.
- Chunks are rows in a SQLite FTS5 database (`.literature.db`), which is ephemeral and rebuilt from disk. Chunked markdown files on disk are the canonical content source.
- Two-pass chunking: first split at heading boundaries (chapter/section/subsection), then recursively subdivide any chunk over 512 tokens at paragraph/sentence breaks. Theorem/proof/definition/lemma blocks stay atomic up to 1024 tokens.
- Cross-references ("by Definition 2.1", "see Lemma 3.4") are extracted from chunk text and stored in a `chunk_relations` table, enabling graph traversal during agent search.
- A two-tier search model: agents search a local `.literature.db` (project-specific, in `specs/literature/`) then a global `.literature.db` (full library). Local results take precedence on duplicate doc_ids.
- The `--lit` flag changes from "inject content at preflight" to "make `literature-search.sh` available to the agent." The agent queries, browses metadata, follows cross-refs, reads full content from disk, and decides when to stop.
- Before building: audit PDF conversion quality and cross-reference extraction regex on 5 representative papers.

---

## Architecture

```
ANY REPO                           GLOBAL
--------                           ------
/literature --ingest <source>
        |
        v
  [resolve source]
  (file path / directory / zotero key)
        |
        v
  [convert to markdown]
  (marker or pandoc)
        |
        v
  [two-pass chunking]
  (headings → 512-token recursive)
        |
        v
  [extract cross-refs]
  (Definition 2.1, Lemma 3.4, Theorem X of [Author])
        |
        +---> ~/Projects/Literature/{author_year}/
        |       - chunked .md files
        |       - index.json entry updated
        |       - .literature.db rebuilt
        |
        v
  [offer local loading]
  "Load into local specs/literature/?"
        |
   yes? +---> specs/literature/
        |       - hard copies of chunk files
        |       - local .literature.db rebuilt
        |
        v
  DONE

AGENT ACCESS (--lit flag active):
  agent → literature-search.sh "query"
       → searches local .literature.db first
       → searches global .literature.db second
       → merges results (local takes precedence on duplicate doc_ids)
       → reads metadata/TOC without loading content
       → reads full chunk content from disk for selected chunks
       → follows cross_refs to related chunks
       → iterates until satisfied, then stops
```

---

## Layer 1: Ingestion

### Input Sources

The user runs `/literature --ingest <source>` from any repo. Three source types:

| Source | Format | Resolution |
|--------|--------|------------|
| File path | `/path/to/paper.pdf` or `.djvu` | Use file directly |
| Directory path | `/path/to/papers/` | Collect all `.pdf` and `.djvu` files in it |
| Zotero key | `--zotero "AuthorYear"` | Look up in `zotero-library.json`, resolve to PDF path in Zotero storage |

### Ingestion Pipeline

**Step 1: Resolve source**
Determine source type from argument. For Zotero keys, parse `zotero-library.json` (maintained by the existing `/literature` skill) to find the storage path.

**Step 2: Convert to markdown**
Run marker (preferred for academic PDFs with two-column layouts and math) or pandoc as fallback. Output: one markdown file per PDF, preserving heading structure.

**Step 3: Two-pass chunking**
Invoke `literature-chunk.sh` (or `.py`):

- **Pass 1 — Heading split**: Walk the markdown and split at heading boundaries.
  - `#` → chapter-level (level 1)
  - `##` → section-level (level 2)
  - `###` → subsection-level (level 3)
  - Deeper headings absorbed into nearest subsection.
- **Pass 2 — Size enforcement**: For any chunk over 512 tokens, recursively subdivide at paragraph breaks first, then sentence breaks if needed.
- **Atomic blocks**: Theorem, proof, definition, lemma blocks (detected by keyword markers and fenced environments) are kept intact even if over 512 tokens, up to a hard cap of 1024 tokens.
- **Breadcrumb prepend**: Each chunk gets a `section_path` breadcrumb prepended: `"Ch3 > Frame Definability > Theorem 3.4"`.
- **Chunk ID**: Stable hash of `(doc_id, section_path, content_hash)` so re-ingestion of unchanged content produces the same IDs.

**Step 4: Extract cross-references**
Parse chunk text for reference patterns:
- `"by Definition 2.1"`, `"see Definition 3"` → definition reference
- `"Lemma 3.4"`, `"the previous Lemma"` → lemma reference
- `"Theorem X of [Author]"` → external document reference
- `"Proposition 2"`, `"Corollary 4.1"` → proposition/corollary references

Store extracted refs as `(from_chunk_id, referenced_label)` pairs, to be resolved to `to_chunk_id` during index build when all chunks are known.

**Step 5: Write to global Literature/**
Output directory: `~/Projects/Literature/{author_year}/` where `author_year` is derived from document metadata (author last name + publication year, e.g., `blackburn2001`).

File layout:
```
~/Projects/Literature/blackburn2001/
├── metadata.json         # document-level metadata
├── chunk_0001.md         # one file per chunk (or per-document, see Open Questions)
├── chunk_0002.md
└── ...
```

**Step 6: Update index.json**
The global `~/Projects/Literature/index.json` gets an entry or updated entry for this document. Fields: `doc_id`, `title`, `authors`, `year`, `source_path` (original PDF), `chunks_dir`, `chunk_count`, `ingested_at`.

**Step 7: Rebuild .literature.db**
Call `literature-build-index.sh` to (re)build `~/Projects/Literature/.literature.db` from all chunks + `index.json`.

**Step 8: Offer local loading**
Prompt the user: "Load these chunks into `specs/literature/` in the current repo? [y/N]"

- If yes: hard-copy the chunk files to `specs/literature/{author_year}/`. Add `global_id` field to local copies linking back to the global source. Rebuild local `specs/literature/.literature.db`.
- If no: chunks remain in global only, still accessible to agents via the `LITERATURE_DIR` environment variable.

---

## Layer 2: Index (SQLite FTS5)

### FTS5 Virtual Table

```sql
CREATE VIRTUAL TABLE chunks USING fts5(
  chunk_id        UNINDEXED,
  doc_id          UNINDEXED,
  parent_chunk_id UNINDEXED,
  level           UNINDEXED,
  section_path    UNINDEXED,
  title           ,            -- weight 10
  keywords        ,            -- weight 5
  summary         ,            -- weight 3
  token_count     UNINDEXED,
  source_path     UNINDEXED,
  prev_chunk_id   UNINDEXED,
  next_chunk_id   UNINDEXED,
  cross_refs      UNINDEXED,
  content         ,            -- weight 1
  tokenize = 'porter unicode61 remove_diacritics 2',
  content = '',               -- external content pattern
  content_rowid = 'rowid'
);
```

BM25 column weights applied at query time:
```sql
SELECT *, bm25(chunks, 0,0,0,0,0, 10,5,3,0,0,0,0,0,1) AS rank
FROM chunks
WHERE chunks MATCH ?
ORDER BY rank;
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `chunk_id` | TEXT | Stable hash: `sha256(doc_id + section_path + content_hash)[:16]` |
| `doc_id` | TEXT | Parent document identifier (e.g., `blackburn2001`) |
| `parent_chunk_id` | TEXT | Chunk ID of containing section (NULL for top-level) |
| `level` | INTEGER | 0=document, 1=chapter, 2=section, 3=subsection |
| `section_path` | TEXT | Breadcrumb: `"Ch3 > Frame Definability > Theorem 3.4"` |
| `title` | TEXT | Section or chunk title |
| `keywords` | TEXT | Space-separated terms for FTS tokenization |
| `summary` | TEXT | Brief description of chunk content (LLM-generated or extracted) |
| `token_count` | INTEGER | Token count so agent can budget context window |
| `source_path` | TEXT | Relative path to chunk `.md` file on disk |
| `prev_chunk_id` | TEXT | Previous chunk in document sequence (NULL if first) |
| `next_chunk_id` | TEXT | Next chunk in document sequence (NULL if last) |
| `cross_refs` | TEXT | JSON array of referenced labels: `["Definition 2.1", "Lemma 3.4"]` |
| `content` | TEXT | First ~500 words for FTS indexing (full content lives on disk) |

### Relations Table

```sql
CREATE TABLE chunk_relations (
  from_chunk_id TEXT NOT NULL,
  to_chunk_id   TEXT NOT NULL,
  relation_type TEXT NOT NULL,  -- 'parent', 'child', 'sibling', 'cross_ref'
  weight        REAL DEFAULT 1.0,
  PRIMARY KEY (from_chunk_id, to_chunk_id, relation_type)
);
```

Relation types:
- `parent` / `child`: structural hierarchy
- `sibling`: same-level sequential adjacency
- `cross_ref`: extracted textual reference (Definition 2.1 → chunk containing Definition 2.1)

### Database Files

| Location | Purpose |
|----------|---------|
| `~/Projects/Literature/.literature.db` | Global index over all ingested literature |
| `specs/literature/.literature.db` | Local index over project-specific copies |

Both are gitignored. Both are rebuilt by `literature-build-index.sh` from chunk files on disk.

---

## Layer 3: Agent Access

### How `--lit` Changes Behavior

**Before (current)**: `--lit` injects raw content from `specs/literature/` into agent context at preflight. Limited to ~4000 tokens, effectively 1-2 documents.

**After (new design)**: `--lit` makes `literature-search.sh` available to the agent as a callable tool. No content is injected at preflight. The agent searches on demand.

### Search Tool Interface

```bash
# Full-text search
literature-search.sh "query string"
# Returns: ranked list of chunks with metadata (no full content)

# Read full content of a specific chunk
literature-search.sh --read <chunk_id>
# Returns: full markdown content of the chunk from disk

# Browse TOC (all chunks' metadata, no content)
literature-search.sh --toc [doc_id]
# Returns: section_path, title, token_count, chunk_id for all chunks (or one document)

# Follow cross-references from a chunk
literature-search.sh --refs <chunk_id>
# Returns: metadata for all chunks linked from cross_refs field

# Navigate sequentially
literature-search.sh --next <chunk_id>
literature-search.sh --prev <chunk_id>
# Returns: metadata + first paragraph of adjacent chunk
```

Search output format (JSON, one object per result):
```json
{
  "chunk_id": "a3f7bc12",
  "doc_id": "blackburn2001",
  "section_path": "Ch3 > Frame Definability > Theorem 3.4",
  "title": "Theorem 3.4",
  "summary": "Completeness theorem for basic modal logic over reflexive frames",
  "token_count": 312,
  "cross_refs": ["Definition 2.1", "Lemma 3.2"],
  "rank": -4.23,
  "snippet": "...the following conditions are equivalent for any formula φ..."
}
```

### Agent Behavior Pattern

The agent operates autonomously:

1. **Initial search**: Query FTS5 for chunks matching the research question.
2. **TOC browse**: Call `--toc` on promising documents to understand structure before committing to reading.
3. **Selective read**: Call `--read <chunk_id>` only for chunks likely to be relevant (based on summary + rank).
4. **Cross-ref follow**: When encountering "by Definition 2.1" in a chunk, call `--refs <chunk_id>` to fetch the definition chunk rather than searching from scratch.
5. **Sequential navigation**: Use `--next` / `--prev` to read adjacent chunks when context requires surrounding material.
6. **Budget tracking**: Track `token_count` of chunks read; stop when context budget is nearly exhausted or when the answer is found.

### Two-Tier Search

`literature-search.sh` always searches both databases and merges:

1. Query local `specs/literature/.literature.db` (project-specific)
2. Query global `~/Projects/Literature/.literature.db` (full library)
3. Merge results: if same `doc_id` appears in both, local result takes precedence (project-specific annotations may differ)
4. Rank merged results by BM25 score

If only one database exists (global only, or local only), search that database alone.

---

## Multi-Repo Workflow

### The Problem

The user works across multiple repos (nvim config, BimodalLogic, cslib, etc.). Literature should be ingested once and available everywhere, not duplicated per-repo.

### The Solution

**Global library** (`~/Projects/Literature/`): One copy of every ingested document, chunked and indexed. All repos can search this via the global `.literature.db`.

**Local library** (`specs/literature/`): Hard copies of selected chunks for a specific project. Committed with the repo. Useful when a project deeply depends on specific papers and needs those chunks to be available without the global library.

### Ingestion From Any Repo

```bash
# From nvim config repo
/literature --ingest ~/Papers/blackburn2001.pdf

# From BimodalLogic repo
/literature --ingest ~/Zotero/storage/AB12CD34/paper.pdf

# Using Zotero key (resolved via zotero-library.json)
/literature --ingest --zotero "BlackburnDeRijkeVenema2001"

# Ingest all PDFs in a directory
/literature --ingest ~/Papers/modal-logic/
```

All ingestion writes to `~/Projects/Literature/` regardless of current repo. The global index and database are updated. Then the user is offered the option to create local copies in the current repo.

### Local Loading Decision

After ingestion, the tool asks:
```
Ingested: Blackburn, de Rijke, Venema (2001) — 247 chunks
Load into specs/literature/ in current repo? [y/N]
```

- **Yes**: Hard-copies chunk files to `specs/literature/{author_year}/`. Adds `"global_id": "blackburn2001"` to local chunk metadata. Rebuilds local `.literature.db`.
- **No**: Chunks accessible globally only. Agent in this repo can still search them via the global database path.

### Environment Variable

`LITERATURE_DIR` (default: `~/Projects/Literature`) controls the global library path. Can be overridden in `.env` or shell config for non-standard setups.

---

## Source of Truth

| Artifact | Status | Notes |
|----------|--------|-------|
| Chunked `.md` files on disk | **Canonical** | Full content lives here; FTS index stores only first ~500 words |
| `index.json` | **Canonical** | Document-level metadata; one entry per ingested document |
| `.literature.db` | **Derived, ephemeral** | Rebuilt by `literature-build-index.sh`; gitignored |
| `specs/literature/` chunk files | **Independent copies** | Committed with repo; have `global_id` back-reference but are not symlinks |

The rebuild command is idempotent: running `literature-build-index.sh` from scratch produces an identical database given the same chunk files and `index.json`.

---

## Scripts to Implement

### 1. `literature-ingest.sh`

**Purpose**: Main ingestion entry point. Orchestrates the full pipeline.

**Interface**:
```bash
literature-ingest.sh <path>                    # file or directory
literature-ingest.sh --zotero <key>            # Zotero key lookup
literature-ingest.sh --no-local <path>         # skip local-loading prompt
literature-ingest.sh --local <path>            # auto-accept local loading
```

**Flow**:
1. Resolve source type (file / dir / zotero)
2. For each PDF/DJVU: call `literature-convert.sh`
3. For each converted markdown: call `literature-chunk.sh`
4. Update global `index.json`
5. Call `literature-build-index.sh --global`
6. Prompt for local loading; if yes, hard-copy and call `literature-build-index.sh --local`

**Outputs**: Chunk files in `~/Projects/Literature/{author_year}/`, updated `index.json`, rebuilt `.literature.db`.

---

### 2. `literature-convert.sh`

**Purpose**: Convert PDF or DJVU to structured markdown.

**Interface**:
```bash
literature-convert.sh <input.pdf> <output_dir>
literature-convert.sh <input.djvu> <output_dir>
```

**Behavior**:
- Try marker first (better for academic two-column PDFs and math)
- Fall back to pandoc if marker unavailable or fails
- Preserve heading hierarchy in output markdown
- Report conversion quality (heading count, math block count) for audit

**Outputs**: `{output_dir}/{doc_id}.md`

---

### 3. `literature-chunk.sh`

**Purpose**: Two-pass hierarchical chunking with cross-reference extraction.

**Interface**:
```bash
literature-chunk.sh <input.md> <output_dir> --doc-id <id>
```

**Pass 1 — Heading split**:
- Parse markdown for `#`, `##`, `###` headings
- Split at each heading boundary, carrying the heading as chunk title
- Assign `level` (1/2/3) and build `section_path` breadcrumb
- Detect atomic blocks: lines matching `\*\*(Theorem|Proof|Definition|Lemma|Proposition|Corollary)\b`

**Pass 2 — Size enforcement**:
- Count tokens in each chunk (using character-based approximation: chars/4)
- For chunks > 512 tokens (excluding atomic blocks): split at blank-line paragraph boundaries
- For sub-chunks still > 512 tokens: split at sentence boundaries (period + space + capital)
- Hard cap for atomic blocks: 1024 tokens (emit warning if exceeded, do not split)

**Cross-reference extraction**:
- Regex: `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+\d+(\.\d+)*\b`
- Regex: `\bTheorem\s+[A-Z]\b` (single-letter labels)
- Store as JSON array in chunk metadata

**Output**: One `.md` file per chunk plus one `chunks.json` manifest listing all chunks and their metadata fields.

---

### 4. `literature-build-index.sh`

**Purpose**: Build or rebuild `.literature.db` from chunk files and `index.json`.

**Interface**:
```bash
literature-build-index.sh --global              # rebuild ~/Projects/Literature/.literature.db
literature-build-index.sh --local               # rebuild specs/literature/.literature.db
literature-build-index.sh --global --local      # rebuild both
```

**Flow**:
1. Drop and recreate FTS5 virtual table and `chunk_relations` table
2. Walk all `chunks.json` manifests in the target directory
3. For each chunk: read first ~500 words from `.md` file, insert row into FTS5 table
4. Resolve cross-references: match label strings (e.g., "Definition 2.1") to chunk IDs within the same document; insert `chunk_relations` rows
5. Insert structural relations (parent/child/sibling) from `chunks.json` hierarchy

**Performance note**: For a library of ~200 documents × 100 chunks = 20,000 chunks, rebuild should complete in under 30 seconds.

---

### 5. `literature-search.sh`

**Purpose**: Agent-callable FTS5 search tool. Accessed by agents when `--lit` is active.

**Interface**:
```bash
literature-search.sh "query"                    # FTS5 search, returns ranked metadata
literature-search.sh --read <chunk_id>          # read full chunk content from disk
literature-search.sh --toc [doc_id]             # browse TOC (metadata only, no content)
literature-search.sh --refs <chunk_id>          # follow cross-references
literature-search.sh --next <chunk_id>          # next chunk in sequence
literature-search.sh --prev <chunk_id>          # previous chunk in sequence
literature-search.sh --doc <doc_id>             # list all chunks in a document
```

**Search behavior**:
1. Query local `.literature.db` if it exists
2. Query global `.literature.db`
3. Merge results (local takes precedence on duplicate `doc_id`)
4. Return JSON array of result objects (see Layer 3 for format)
5. Default limit: 20 results

**Query sanitization**: Strip FTS5 special characters (`"`, `*`, `OR`, `AND`, `NOT` at word boundaries) from agent-provided query strings before passing to SQLite. Agent queries should be plain text; the script handles FTS syntax.

**Output format**: JSON to stdout. Errors to stderr with non-zero exit code.

---

## Pre-Implementation Audits

Two audits must pass before building the full pipeline. These are scripted checks, not manual review.

### Audit 1: Conversion Quality

**What**: Test markdown conversion on 5 representative PDFs with academic formatting challenges.

**Selection criteria**: Include at least one paper with two-column layout, one with heavy display math (theorems, proofs), one with many cross-references, one with tables, one with footnotes.

**Pass criteria**:
- Headings preserved in output markdown (`#`, `##`, `###` present and correctly nested)
- Math blocks converted (LaTeX environments present, not garbled)
- No major garbling (>90% of readable text from PDF present in markdown)
- Conversion completes without error

**Action if audit fails**: Fix `literature-convert.sh` (tune marker parameters, add pandoc post-processing, or implement a hybrid approach) before proceeding to chunking.

### Audit 2: Cross-Reference Extraction

**What**: Test regex extraction patterns on 5 papers covering formal logic, modal logic, category theory, or similar math-heavy domains.

**Method**: Run `literature-chunk.sh` on the 5 papers. For each paper, manually count 10-20 cross-references in the original PDF and verify they appear in the extracted `cross_refs` JSON arrays.

**Pass criteria**:
- Recall > 85%: at least 85% of actual cross-references are captured
- Precision > 90%: fewer than 10% of extracted references are false positives

**Action if audit fails**: Expand or refine the regex patterns. Consider adding domain-specific patterns (e.g., `\bAxiom\s+\d+` for formal systems, `\bFigure\s+\d+` for diagrams).

---

## Open Questions for Planning

These decisions should be resolved by the planner before writing implementation phases:

1. **Conversion tool**: Use marker, pandoc, or a hybrid (marker for math-heavy papers, pandoc as fallback)? Marker requires Python + ML model download; pandoc is universally available. Recommendation: default to marker with pandoc fallback, but make the choice configurable in `literature-ingest.sh`.

2. **Chunk storage format**: One file per chunk (clean separation, easy to hard-copy selectively) vs. one file per document with chunk markers (fewer files, harder to selectively load). The one-file-per-chunk approach is cleaner for selective local loading; the one-file-per-document approach is easier to audit manually. Pick one.

3. **Re-ingestion handling**: If a PDF is ingested again (updated version), how are old chunk IDs handled? Options:
   - **Overwrite**: Delete old chunks for that `doc_id`, re-ingest fresh. Simple but breaks any local copies that reference old chunk IDs.
   - **Versioned**: Append version suffix to `doc_id` (e.g., `blackburn2001_v2`). Preserves old chunks but requires user to manage versions.
   - **Diff**: Compare new chunk IDs to old; only insert changed chunks. Complex but preserves stable references.
   Recommendation: Overwrite with a warning listing any local repos that have hard copies of the affected `doc_id`.

4. **Summary generation**: Should chunk summaries be LLM-generated at ingest time (high quality, non-zero cost) or extracted heuristically (first sentence, or heading + first paragraph)? Heuristic extraction is free and fast; LLM generation produces better metadata for search. Options: default to heuristic, offer `--summarize` flag for LLM generation.

5. **FTS5 query sanitization**: The agent writes free-text queries. How strictly should the search script sanitize? Options: strip all FTS5 operators (safe but loses power-user queries), allow quoted phrases only, or pass through with error handling. Recommendation: strip bare operators, allow `"quoted phrases"`.

---

## Prior Research Summary

| Round | What It Established |
|-------|---------------------|
| Round 1 | The "geometry problem": with 183 entries and an 8K token budget, only 1-2 entries are injectable at preflight. Industry solution is on-demand agent retrieval, not pre-injection. |
| Round 2 | Two-tier architecture (global `~/Projects/Literature/` + local `specs/literature/`). `LITERATURE_DIR` env var for global path. Hard copies (not symlinks) for repo portability. |
| Round 3 | SQLite FTS5 schema with BM25 column weights (title 10x, keywords 5x, summary 3x, content 1x). Agent writes search queries directly; no intermediate scoring script needed. |
| Round 4 | Lectic is for interactive use, not agent automation. The agent access path is bash scripts calling SQLite, not lectic's interactive CLI. |
| Round 5 | Consolidated design: agent-driven autonomous search via bash scripts + FTS5. The `--lit` flag enables the search tool, not content injection. |
| Round 6 | Two-pass structural splitting (headings then 512-token recursive). Cross-references are essential for formal math (definitions, lemmas, theorems are deeply interconnected). Pre-build audits (conversion quality + cross-ref extraction) are required. 16-field metadata schema. `chunk_relations` table for graph edges. |
| Round 7 | Final consolidation. Multi-repo ingestion workflow clarified. Source-of-truth hierarchy defined. Full script interface specifications written. Open questions surfaced for planner. |

---

## Sources

- **Round 1 report**: `specs/721_design_targeted_literature_retrieval/reports/01_initial-research.md`
- **Round 2 report**: `specs/721_design_targeted_literature_retrieval/reports/02_two-tier-architecture.md`
- **Round 3 report**: `specs/721_design_targeted_literature_retrieval/reports/03_fts5-schema.md`
- **Round 4 report**: `specs/721_design_targeted_literature_retrieval/reports/04_lectic-assessment.md`
- **Round 5 report**: `specs/721_design_targeted_literature_retrieval/reports/05_consolidated-design.md`
- **Round 6 report**: `specs/721_design_targeted_literature_retrieval/reports/06_chunking-and-crossrefs.md`
- **SQLite FTS5 documentation**: https://www.sqlite.org/fts5.html
- **marker (PDF to markdown)**: https://github.com/VikParuchuri/marker
- **Existing `/literature` skill**: `.claude/skills/skill-literature/SKILL.md`
- **Existing `zotero-library.json` integration**: `.claude/extensions/cslib/` (Zotero key resolution)
