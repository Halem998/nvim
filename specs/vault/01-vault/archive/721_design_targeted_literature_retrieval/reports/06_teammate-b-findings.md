# Teammate B Findings: Metadata Schemas and Inter-Chunk Relations

**Task**: 721
**Focus**: Metadata, chunk relations, TOC design, database patterns
**Confidence**: high

---

## Key Findings

1. **Canonical metadata schema**: Production RAG systems converge on 12-15 fields per chunk. Core identifiers (chunk_id, doc_id, parent_chunk_id), provenance (source_path, title, section_path, page_range), enrichment (summary, keywords, entities), and retrieval-support fields (token_count, previous_chunk_id, next_chunk_id) form the stable core. LLM-generated fields like `questions` and `rephrasing` add retrieval breadth at a cost.

2. **MDKeyChunker's complete field list**: The production system MDKeyChunker (arxiv 2603.23533) defines: `chunk_id`, `text`, `section_title`, `title`, `summary`, `keywords`, `entities`, `questions`, `key` (semantic key), `related_keys`, `content_types`, `position_index`, `previous_chunk_id`, `next_chunk_id`, `token_count`, `start_line`, `end_line`. This is the most complete real-world schema found and closely matches the design target.

3. **Three practical relation types are sufficient**: Research literature (Disco-RAG, IIER) identifies dozens of rhetorical relation types (ELABORATES, SUPPORTS, PRECEDES, CONTRADICTS, etc.), but production systems only benefit from three actionable categories: **structural** (adjacent chunks, parent/child), **semantic** (high cosine-similarity, same topic), and **cross-reference** (explicit citations/see-also within text). The first is computable from position; the latter two add the most navigation value.

4. **PageIndex pattern for TOC**: The strongest agent-navigation pattern is a hierarchical tree of metadata-only nodes, where each node has: `node_id`, `title`, `summary`, `start_index`/`end_index` (page or chunk range), and `children[]` (nested nodes). Agent browses the tree, then fetches only the leaf node content it selects. This pattern achieved 98.7% accuracy on FinanceBench vs. 31% for flat vector RAG.

5. **Progressive disclosure = three-tier access**: (1) Metadata index — ~50-100 tokens per entry — gives agent a map; (2) on-demand section summary (~200-500 tokens); (3) full chunk content (~500-2000 tokens). Each tier has a different trigger: tier 1 at every query, tier 2 when a node is plausibly relevant, tier 3 when the agent decides to read. This pattern saves 87% of tokens on typical tasks.

6. **SQLite alone is sufficient; sqlite-vec is optional enhancement**: SQLite FTS5 is proven for production-scale keyword retrieval (sub-millisecond, BM25 ranking). Adding `sqlite-vec` enables vector/semantic search as an additional column in the same file. Adding a graph edge table with recursive CTEs handles structural and semantic relations without a separate graph DB. Neo4j is only warranted beyond ~100k entities with depth-4+ traversals or multi-user writes.

7. **The "right amount" of metadata**: The Azure architecture guide's heuristic is to add a field only if it enables a query type you could not otherwise support. Core provenance fields pay for themselves immediately. LLM-generated `questions` field measurably improves recall when queries are short relative to chunk size. `entities` field enables entity-based filtering. `summary` field enables the TOC layer without loading full content.

8. **Relation graph is lightweight in SQLite**: A `chunk_relations` table with `(from_chunk_id, to_chunk_id, relation_type, weight)` rows is the minimal viable inter-chunk graph. For ~200 documents with typical academic structure, this table will have thousands to tens of thousands of rows — easily managed by SQLite with two indexes on `from_chunk_id` and `to_chunk_id`.

---

## Recommended Approach

### Chunk Metadata Schema

Each chunk record should carry these fields (ordered by priority):

| Field | Type | Source | Purpose |
|---|---|---|---|
| `chunk_id` | TEXT (hash) | computed | Stable identity, dedup key |
| `doc_id` | TEXT | computed | Link to source document |
| `parent_chunk_id` | TEXT nullable | computed | Hierarchy: NULL for top-level |
| `level` | INTEGER | computed | 0=document, 1=chapter, 2=section, 3=leaf |
| `section_path` | TEXT | computed | E.g. "3.2.1" or "Ch3 > Sec2 > Para1" |
| `title` | TEXT | extracted/LLM | Node label in TOC |
| `summary` | TEXT | LLM | Shown in TOC without loading content |
| `keywords` | TEXT (JSON array) | LLM/RAKE | FTS filter, tag cloud |
| `page_start` | INTEGER | extracted | Source location |
| `page_end` | INTEGER | extracted | Source location |
| `token_count` | INTEGER | computed | Budget guidance for agent |
| `content` | TEXT | extracted | The actual chunk text |
| `prev_chunk_id` | TEXT nullable | computed | Sequential navigation |
| `next_chunk_id` | TEXT nullable | computed | Sequential navigation |
| `source_path` | TEXT | from ingestion | Absolute path to original file |
| `created_at` | TEXT | computed | ISO8601 ingestion timestamp |

**Defer to phase 2** (nice to have, not critical): `entities`, `questions`, `content_type` (text/figure/table/equation), `language`.

### Inter-Chunk Relations

Use a separate `chunk_relations` table:

```sql
CREATE TABLE chunk_relations (
  from_chunk_id TEXT NOT NULL REFERENCES chunks(chunk_id),
  to_chunk_id   TEXT NOT NULL REFERENCES chunks(chunk_id),
  relation_type TEXT NOT NULL, -- 'structural', 'semantic', 'cross_ref'
  weight        REAL DEFAULT 1.0,
  PRIMARY KEY (from_chunk_id, to_chunk_id, relation_type)
);
CREATE INDEX idx_chunk_relations_from ON chunk_relations(from_chunk_id);
CREATE INDEX idx_chunk_relations_to   ON chunk_relations(to_chunk_id);
```

**Three relation types only**:
- `structural`: auto-computed from `prev_chunk_id`/`next_chunk_id` and parent/child — no separate rows needed since these are in the chunks table itself
- `semantic`: optional; computed by comparing embedding similarity above a threshold during ingestion; stored in `chunk_relations`
- `cross_ref`: extracted from text (citations, "see section X", footnotes); high value for academic literature

Agent traversal: given a retrieved chunk, look up `chunk_relations WHERE from_chunk_id = ?` to find related content the agent should consider reading next.

### TOC / Hierarchical Index Design

The agent-facing index should be a **materialized TOC view** — not a live query — refreshed on ingestion:

```json
{
  "toc": [
    {
      "node_id": "doc_001",
      "title": "Category Theory for Programmers",
      "level": 0,
      "token_count": 42000,
      "children": [
        {
          "node_id": "chunk_0042",
          "title": "Chapter 1: Composition",
          "level": 1,
          "summary": "Introduces the concept of morphism composition...",
          "page_start": 1,
          "page_end": 18,
          "token_count": 3200,
          "children": [...]
        }
      ]
    }
  ]
}
```

This JSON tree is the "browse" interface. An agent scans it without loading any content. When it selects a node, it fetches the `content` field from the `chunks` table by `node_id`. For the ~200-document library, the full TOC (titles + summaries, no content) will be roughly 50-150k tokens — too large to load at once, so the agent should browse it using a tool that accepts a `depth` parameter (show only levels 0-1 by default; expand a subtree on demand).

### Database Design

```sql
-- Documents table (one per source file)
CREATE TABLE documents (
  doc_id       TEXT PRIMARY KEY,
  title        TEXT,
  authors      TEXT,   -- JSON array
  year         INTEGER,
  source_path  TEXT UNIQUE NOT NULL,
  created_at   TEXT NOT NULL
);

-- Chunks table (all hierarchical levels)
CREATE TABLE chunks (
  chunk_id       TEXT PRIMARY KEY,
  doc_id         TEXT NOT NULL REFERENCES documents(doc_id),
  parent_chunk_id TEXT REFERENCES chunks(chunk_id),
  level          INTEGER NOT NULL,
  section_path   TEXT,
  title          TEXT,
  summary        TEXT,
  keywords       TEXT,  -- JSON array
  page_start     INTEGER,
  page_end       INTEGER,
  token_count    INTEGER,
  content        TEXT,
  prev_chunk_id  TEXT REFERENCES chunks(chunk_id),
  next_chunk_id  TEXT REFERENCES chunks(chunk_id),
  created_at     TEXT NOT NULL
);

-- FTS5 index on content + metadata fields
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  content, title, summary, keywords,
  content='chunks', content_rowid='rowid',
  tokenize='porter unicode61'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, content, title, summary, keywords)
  VALUES (new.rowid, new.content, new.title, new.summary, new.keywords);
END;

-- Relations table
CREATE TABLE chunk_relations (
  from_chunk_id TEXT NOT NULL REFERENCES chunks(chunk_id),
  to_chunk_id   TEXT NOT NULL REFERENCES chunks(chunk_id),
  relation_type TEXT NOT NULL,
  weight        REAL DEFAULT 1.0,
  PRIMARY KEY (from_chunk_id, to_chunk_id, relation_type)
);
```

Optional extension: add `sqlite-vec` for semantic similarity search when embedding generation is available. This adds a `chunks_vec` virtual table alongside `chunks_fts` with no schema changes required.

---

## Evidence/Examples

### Microsoft Azure RAG Enrichment Guide (production reference)
The official Azure architecture guide defines the canonical metadata fields used in production: `id`, `chunk` (raw text), `cleaned_chunk`, `title`, `summary`, `keywords` (array), `questions` (vectorized). It clearly states: "The metadata columns that you need to add depend on your problem domain... you can determine what metadata might help you address your workload's requirements."

### MDKeyChunker (arxiv 2603.23533)
Peer-reviewed 2025 paper implementing the most complete chunk metadata schema in production. Single LLM call extracts 7 metadata fields simultaneously: `title`, `summary`, `keywords`, `entities`, `questions`, `semantic_key`, `content_types`. Adds `previous_chunk_id` / `next_chunk_id` for sequential navigation. Demonstrated superior retrieval accuracy on academic benchmarks.

### PageIndex (VectifyAI/PageIndex)
Open-source framework that replaced vector databases with a hierarchical tree index of metadata-only nodes. Each node: `node_id`, `title`, `summary`, `start_index`, `end_index`, `children[]`. Agent navigates tree to locate relevant section, then fetches page content. Achieved 98.7% accuracy on FinanceBench vs. 31% for traditional RAG. Directly validates the progressive-disclosure approach.

### Progressive Disclosure Pattern (Claude-Mem / Microsoft Agent Skills)
Documented 3-tier pattern: (1) metadata-only index loaded at startup (~50-100 tokens/item), (2) section content loaded on-demand, (3) supplementary detail loaded when explicitly needed. Results in 87% token reduction for typical tasks. The pattern is language/DB-agnostic and maps directly onto the proposed SQLite schema.

### Disco-RAG Inter-Chunk Relations (arxiv 2601.04377)
Defines a taxonomy of 20+ inter-chunk rhetorical relations (SUPPORTS, ELABORATES, PRECEDES, CONTRADICTS, CAUSES, RESULTS_FROM, etc.). For navigation purposes, only 3 practical categories matter: structural (position-based), semantic (embedding-based), cross-reference (citation-based). The full taxonomy is useful for complex multi-hop reasoning but overkill for browse-then-read navigation.

### IIER Inter-Chunk Interaction Graph (arxiv 2408.02907)
Academic system building a Chunk-Interaction Graph (CIG = {V, E}) with three edge types: structural (weight=1 for adjacent chunks), semantic (cosine similarity weight), keyword (shared keyword count weight). Directly validates the three-relation-type recommendation. Graph stored and queried with standard graph operations (BFS/DFS) over the edge table.

### SQLite as Graph Database (DEV Community)
Production case study replacing Neo4j with SQLite for a system with "tens-of-thousands-of nodes." Conclusions: SQLite wins for single-user, offline, <100k entities with traversal depth ≤4. Uses `WITH RECURSIVE` CTEs for graph traversal. Bi-temporal edge design: `valid_from`/`valid_until` for relation validity + `recorded_at` for audit. For ~200 academic documents, SQLite is clearly the right choice.

---

## Sources

1. [Azure RAG Enrichment Phase Guide](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/rag/rag-enrichment-phase) — Microsoft official production RAG metadata recommendations
2. [MDKeyChunker: Single-Call LLM Enrichment (arxiv 2603.23533)](https://arxiv.org/abs/2603.23533) — Complete chunk metadata schema with LLM enrichment
3. [PageIndex: Document Index for Vectorless RAG](https://github.com/VectifyAI/PageIndex) — Hierarchical TOC tree approach for agent navigation
4. [PageIndex: 98.7% Accuracy (VentureBeat)](https://venturebeat.com/infrastructure/this-tree-search-framework-hits-98-7-on-documents-where-vector-search-fails) — Performance validation of tree-based navigation
5. [Progressive Disclosure – Claude-Mem](https://docs.claude-mem.ai/progressive-disclosure) — 3-tier progressive disclosure pattern with token budget data
6. [Progressive Disclosure for AI Agents (understandingdata.com)](https://understandingdata.com/posts/progressive-disclosure-context/) — 87% token savings claim, tier structure
7. [Disco-RAG: Discourse-Aware RAG (arxiv 2601.04377)](https://arxiv.org/pdf/2601.04377) — Inter-chunk rhetorical relation taxonomy
8. [IIER: Inter-Chunk Interactions (arxiv 2408.02907)](https://arxiv.org/html/2408.02907v1) — Chunk-Interaction Graph with three edge types
9. [SQLite as a Graph Database (DEV Community)](https://dev.to/rohansx/sqlite-as-a-graph-database-recursive-ctes-semantic-search-and-why-we-ditched-neo4j-1ai) — SQLite vs Neo4j for knowledge graph, recursive CTEs
10. [Hybrid FTS5 + Vector Search with SQLite (Simon Willison)](https://simonwillison.net/2024/Oct/4/hybrid-full-text-search-and-vector-search-with-sqlite/) — RRF hybrid search pattern
11. [Metadata-Aware Chunking (Medium)](https://medium.com/@asimsultan2/metadata-aware-chunking-the-secret-to-production-ready-rag-pipelines-85bc25b12350) — Core schema fields with JSON example
12. [Beyond Fixed Chunks: Semantic Chunking and Metadata Enrichment (Medium)](https://medium.com/@shaikmohdhuz/beyond-fixed-chunks-how-semantic-chunking-and-metadata-enrichment-transform-rag-accuracy-07136e8cf562) — LLM-generated metadata enrichment patterns
13. [GraphRAG Explained (Zilliz/Medium)](https://medium.com/@zilliz_learn/graphrag-explained-enhancing-rag-with-knowledge-graphs-3312065f99e1) — Knowledge graph vs flat chunk comparison
