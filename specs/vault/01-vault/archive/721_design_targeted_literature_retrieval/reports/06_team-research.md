# Research Report: Task #721 (Round 6) — Literature Chunking and Indexing Design

**Task**: 721 - Design targeted literature retrieval
**Date**: 2026-06-15
**Mode**: Team Research (4 teammates)

---

## Summary

Round 6 research produced strong convergence across four teammates on a concrete, implementable design for chunking and indexing the ~/Projects/Literature/ corpus. Key conclusions:

- **Two-pass structural splitting** (heading boundaries first, recursive subdivision second) is the right primary strategy for academic markdown. Target 512 tokens per leaf chunk with 64-token overlap within sections only.
- **The SQLite schema from Teammate B is the agreed design**: `documents` + `chunks` (with hierarchical parent/child links) + `chunks_fts` virtual table + `chunk_relations`. This fits entirely in SQLite FTS5 with no external dependencies.
- **The Critic surfaced three blockers requiring pre-implementation decisions**: (1) audit markdown conversion quality before any chunking work starts; (2) evaluate whether "dump full index.json into agent context" is sufficient before committing to FTS5; (3) harden the query interface against FTS5 syntax failures.
- **The MVP is narrower than previously scoped**: a single day's work (ingest + FTS5 search) delivers real agent value. Everything else (access logging, summaries cache, bookmarks, cross-reference extraction) is additive.
- **The dominant failure mode is semantic vocabulary mismatch**, not infrastructure gaps — the mitigation is metadata enrichment (Zotero abstracts, concept synonyms), not vector search. Vector search should be deferred until FTS5 demonstrably fails.

---

## Key Findings

### 1. Chunking Strategy (from Teammate A)

**Structure-first splitting is the correct approach for this corpus.** When documents have strong inherent structure (chapters, sections, subsections), heading-based splitting dramatically outperforms fixed-size or semantic chunking approaches — 87% vs. 13% accuracy in controlled benchmarks.

**Two-pass recommended design:**

Pass 1 — structural split on markdown headings (`#`, `##`, `###`). Each chunk captures the heading breadcrumb as metadata. Headers are preserved in the chunk body (`strip_headers=False`).

Pass 2 — recursive subdivision for oversized sections. Target **512 tokens** per leaf chunk, hard cap 1024 for math-heavy units. Overlap of **64 tokens** (12.5%) applied within a section only, never across heading boundaries. Subdivision priority: blank lines between paragraphs, then sentence boundaries.

**Atomic units that must never be split:**
- Code blocks (split only at function/class boundaries)
- Environments marked as `theorem`, `proof`, `lemma`
- Numbered lists mid-list
- Tables and figures (treat as single unit with caption)

**Content-type chunk size guidance:**

| Content type | Target size | Notes |
|---|---|---|
| Prose narrative | 400–512 tokens | Standard recursive split |
| Formal definitions | 50–200 tokens | Keep atomic |
| Theorems + proofs | Up to 1024 tokens | Never split across proof steps |
| Code blocks | Function/class unit | Regardless of token count |
| Tables + figures | Single unit + caption | Include caption in chunk |

**Semantic chunking (embedding-similarity splitting) is not recommended.** It produced fragments averaging only 43 tokens in academic content benchmarks, dropping end-to-end accuracy to 54%. It is also more expensive and slower than structural splitting.

**Context enrichment at near-zero cost:** Prepend the breadcrumb path ("Chapter 3 / Modal Logic / Completeness Theorem") to each chunk before FTS5 indexing. This achieves much of the benefit of Anthropic's contextual retrieval (49% reduction in retrieval failures) at zero LLM cost. Store as `section_path` in chunk metadata.

**Per-chunk metadata to store** (Teammate A's list, reconciled with Teammate B's schema):
- `chunk_id`, `doc_id`, `parent_chunk_id` (NULL for top-level)
- `level` (0=document, 1=chapter, 2=section, 3=leaf)
- `section_path` (breadcrumb, e.g., "Chapter 3 / Section 2.1 / Definitions")
- `chunk_type` (prose | definition | theorem | proof | code | table | figure)
- `section_title`, `token_count`, `char_count`
- `position` (sequential index within document for ordering)
- `prev_chunk_id`, `next_chunk_id` (sequential navigation)

---

### 2. Metadata and Relations (from Teammate B)

**The complete database schema** (combining all recommendations):

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
  chunk_id        TEXT PRIMARY KEY,
  doc_id          TEXT NOT NULL REFERENCES documents(doc_id),
  parent_chunk_id TEXT REFERENCES chunks(chunk_id),
  level           INTEGER NOT NULL,  -- 0=doc, 1=chapter, 2=section, 3=leaf
  section_path    TEXT,              -- breadcrumb path
  chunk_type      TEXT,              -- prose|definition|theorem|proof|code|table|figure
  title           TEXT,
  summary         TEXT,              -- LLM-generated; enables TOC without loading content
  keywords        TEXT,              -- JSON array; RAKE or LLM-extracted
  page_start      INTEGER,
  page_end        INTEGER,
  token_count     INTEGER,
  content         TEXT,
  prev_chunk_id   TEXT REFERENCES chunks(chunk_id),
  next_chunk_id   TEXT REFERENCES chunks(chunk_id),
  source_path     TEXT,
  created_at      TEXT NOT NULL
);

-- FTS5 virtual table (content + searchable metadata)
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  content, title, summary, keywords, section_path,
  content='chunks', content_rowid='rowid',
  tokenize='porter unicode61'
);

-- Keep FTS in sync
CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, content, title, summary, keywords, section_path)
  VALUES (new.rowid, new.content, new.title, new.summary, new.keywords, new.section_path);
END;

-- Inter-chunk relations (semantic and cross-reference; structural is in chunks table)
CREATE TABLE chunk_relations (
  from_chunk_id TEXT NOT NULL REFERENCES chunks(chunk_id),
  to_chunk_id   TEXT NOT NULL REFERENCES chunks(chunk_id),
  relation_type TEXT NOT NULL,  -- 'semantic' | 'cross_ref'
  weight        REAL DEFAULT 1.0,
  PRIMARY KEY (from_chunk_id, to_chunk_id, relation_type)
);
CREATE INDEX idx_relations_from ON chunk_relations(from_chunk_id);
CREATE INDEX idx_relations_to   ON chunk_relations(to_chunk_id);
```

**Three relation types are sufficient** (structural adjacency lives in `prev_chunk_id`/`next_chunk_id` and parent/child in the chunks table itself; no need to duplicate in relations):
- `semantic`: computed from embedding similarity at ingest time (optional, defer to Phase 2)
- `cross_ref`: extracted from text — citations like "see Definition 2.1", "by Lemma 3.4", "[Blackburn 2001]" — high value for this corpus

**TOC design:** A materialized JSON tree refreshed at ingest. Each node holds `{node_id, title, level, summary, page_start, page_end, token_count, children[]}`. The agent browses this tree without loading content. When it selects a node it fetches `content` from `chunks` by ID. The tree should be browsable at configurable depth (default: levels 0–1 only; expand subtree on demand) because at ~200 documents the full tree (titles + summaries, no content) is roughly 50–150k tokens — too large to load at once.

**The `summary` field is the key investment:** It enables the TOC layer at no retrieval cost. Source: either LLM-generated at ingest (MDKeyChunker pattern — single LLM call extracts summary, keywords, entities simultaneously) or left NULL for leaf chunks and populated lazily when an agent first reads them.

**Phase 2 additions** (not in MVP):
- `entities` field (JSON array)
- `questions` field (for reciprocal question answering retrieval)
- `content_type` (text | figure | table | equation)
- `sqlite-vec` virtual table for semantic similarity search (add alongside FTS5 in same file)

---

### 3. Gaps and Concerns (from Critic)

The Critic identified ten concerns, five of which require action before or during implementation:

**[BLOCKER] Finding 1 — Markdown conversion quality is unknown.** The entire design assumes that converted markdown faithfully represents the source PDFs. This is not guaranteed. Pandoc fails on two-column academic layouts (the dominant format in this corpus), mathematical equations are not always converted, and tables with merged cells degrade. **Required action: Audit 5 representative PDFs (heavy math, two-column, commutative diagrams) and verify their markdown before building any chunking infrastructure.** If significant corruption is found, a conversion quality improvement task must precede this one.

**[BLOCKER] Finding 8 — The simpler alternative was not evaluated.** At 183 entries × ~100 tokens each = ~18,300 tokens, the full metadata catalog fits in a single agent call. A jq-based search or full dump of `index.json` into agent context may provide 80% of the benefit at 10% of the complexity. **Required action: Explicitly test the "dump full index.json" approach and document whether it fails before committing to FTS5.** If it works, use it for Phase 0.

**[MUST FIX] Finding 5 — FTS5 query interface is fragile.** Agent-written queries with apostrophes (e.g., "Sahlqvist's"), leading NOT operators, or unbalanced parentheses will cause sqlite3 to crash with cryptic errors. The agent receives no results and silently concludes "not found." **Required action: `literature-search.sh` must sanitize input — escape single quotes, detect/reject leading NOT, return structured errors on failure rather than crashing.**

**[MUST FIX] Finding 2 — Wrong boundary semantics for formal math.** Header boundaries do not align with the atomic units of formal verification papers. Definitions, lemmas, theorems, proofs, and remarks are the real units — a theorem in Section 4.2 depends on a definition in Section 2.1 and a lemma in Section 3.3, none of which are captured by structural splitting alone. **Required mitigation: Add `chunk_type` to the schema (theorem | proof | lemma | definition | remark) and detect these environments during chunking. Keep proof environments atomic. Store a `cross_refs` field listing all named references within a chunk (e.g., "Definition 2.1", "Lemma 3.4") to enable reverse lookup.**

**[MUST FIX] Finding 3 — No mechanism for named cross-reference resolution.** The current design answers "what comes before and after this chunk?" but not "where is Lemma 4.2 that this chunk references?" For formal verification work, the second question is the one that matters. The parent/child/sibling relation graph enables only vertical hierarchy navigation. **Required mitigation: Store a `cross_refs` JSON field per chunk. An agent encountering "by Lemma 4.2" can search `cross_refs CONTAINS "Lemma 4.2"` to find the definition chunk. This is achievable within FTS5 with a dedicated column.**

**[ACCEPTABLE RISK] Finding 4 — BM25 vocabulary mismatch.** Porter stemming fixes morphological variation but not semantic variation ("frame completeness" vs. "canonical model theorem"; "definability" vs. "expressibility"). This is the dominant failure mode for this corpus. Mitigation: enrich metadata aggressively at ingest — pull abstracts from Zotero (the `zotero_key` field exists), manually add concept synonyms to `keywords` in `index.json` for the 20 most-cited works. This is curation work, not infrastructure work. Do not add vector search to address this until FTS5 demonstrably fails.

**[ACCEPTABLE RISK] Finding 6 — TOC token overhead is uncalculated.** The design never measures the actual token cost of the metadata layer. Before implementation, run: `literature-search.sh "" --limit 200` and measure the output. If under 4,000 tokens, load full catalog on first use. If over 20,000 tokens, implement hierarchical browse. This must be an explicit decision.

**[ACCEPTABLE RISK] Finding 7 — Index staleness has edge cases.** Partial writes can leave a corrupt `.db` that passes the mtime check. Mitigation: build to `.literature.db.tmp` and atomically rename to `.literature.db` only on successful completion. Add SHA-256 checksum validation alongside mtime. These are implementation details for the build script, not blockers.

**[DEFERRED] Findings 9 and 10** (no chunk quality metric; agent stopping behavior under context pressure) — these are real concerns but not pre-implementation blockers. Address in agent integration instructions: "If you do not find relevant literature within 3 searches, proceed without it."

---

### 4. Strategic Direction (from Horizons)

**The MVP is genuinely small.** A one-day version is:
1. Bash script: run `marker` or `pandoc` on each PDF to produce markdown
2. Python script: split by heading, write chunks to SQLite with FTS5
3. Shell function: `fts_search "query"` returning top-5 chunk texts

This delivers real agent value. Everything else is additive.

**Phasing:**

- **Phase 0 (MVP, 1 day)**: Ingest pipeline + FTS5 search only. `chunks(id, doc_id, heading_path, text, char_count)` with FTS5 virtual table. Search returns top-N with `heading_path` as context.
- **Phase 1 (1 week, after MVP validates)**: Add metadata enrichment (summaries, keywords, chunk_type, cross_refs), TOC materialization, access logging, and agent bookmarking.
- **Phase 2 (months later, if needed)**: Add `sqlite-vec` for semantic similarity when FTS5 demonstrably misses queries. Use Reciprocal Rank Fusion (RRF) to combine FTS5 and vector rankings inside the same SQLite file.

**Scale headroom is large.** FTS5 benchmarks at 0.37ms per query. With ~200 academic papers chunked to ~500-token pieces, the corpus is roughly 5,000–20,000 chunks — well inside FTS5's comfortable range. The scaling cliff occurs around 200,000 chunks for vector search; FTS5 scales to millions of rows with millisecond latency. There is no pressure to add vector search at this corpus size.

**The Karpathy LLM-wiki pattern is aspirationally relevant.** At personal scale, the LLM can incrementally compile raw sources into an interlinked markdown wiki, eliminating the need for vector databases entirely. This is a long-term direction for Phase 3 or beyond, not something to build toward now.

**Agent bookmarking and reading receipts are low-cost high-value additions** for Phase 1:
- `chunk_access_log(chunk_id, session_id, timestamp)` — one INSERT per read
- `chunk_summaries(chunk_id, summary, written_by_session)` — agents annotate on read
- `agent_bookmarks(chunk_id, note, session_id, created_at)` — explicit saves

These require zero new dependencies; they are additional tables in the same SQLite file.

---

## Synthesis

### Conflicts Resolved

**Conflict 1: Chunk size — 512 tokens (A) vs. minimal MVP without size target (D)**

Teammate A recommends 512 tokens as the canonical sweet spot based on benchmark data. Teammate D's MVP uses bare-minimum schema without specifying token targets. **Resolution: Use 512-token target for leaf chunks with 1024-token hard cap for math environments.** This is evidence-grounded and does not conflict with D's MVP — the MVP can use a 512-token target from day one.

**Conflict 2: Semantic chunking — reject (A) vs. not mentioned (B, D)**

Teammate A explicitly found semantic (embedding-similarity) chunking underperforms for academic content (54% accuracy vs. 69% for recursive 512-token splitting). No other teammate advocated for it. **Resolution: Confirmed rejection. Do not use embedding-similarity as the split criterion. Structural splitting wins at this content type and corpus size.**

**Conflict 3: Scope of inter-chunk relations — three types (B) vs. "structural only" implicit in MVP (D)**

Teammate B recommends three relation types (structural, semantic, cross_ref). Teammate D's MVP omits relations entirely. Teammate C flags cross-references as the most important missing piece for formal verification work. **Resolution: The `chunk_relations` table is deferred to Phase 1, but `cross_refs` as a JSON field on the `chunks` table is Phase 0. Cross-reference extraction can be done during chunking with a simple regex over named environments (Definition N.N, Lemma N.N, Theorem N.N) and citation patterns ([Author YYYY]).**

**Conflict 4: TOC as static JSON tree (B) vs. TOC as search output (C)**

Teammate B proposes a materialized JSON TOC tree refreshed at ingest. Teammate C points out the design conflates the static TOC with the dynamic search tool, and that `literature-search.sh "" --limit 200` is effectively the same as a catalog dump. **Resolution: The TOC and the search tool are complementary, not competing. The materialized JSON tree is the browse interface (no query required). The FTS5 search is the query interface. Both should exist. The key decision (measure TOC token size before choosing browse strategy) is correctly flagged by the Critic as a required action.**

**Conflict 5: Summary generation — LLM at ingest (B) vs. deferred (D)**

Teammate B recommends using a single LLM call to generate summary + keywords + entities at ingest time (MDKeyChunker pattern). Teammate D's MVP has no LLM enrichment at ingest. **Resolution: LLM enrichment at ingest is Phase 1, not Phase 0. Phase 0 can use keyword extraction (RAKE or simple TF-IDF) for the `keywords` field and leave `summary` NULL. Agents populate summaries lazily on first read. This preserves the MVP's simplicity while enabling enrichment in Phase 1.**

### Gaps Identified

**Gap 1 — Conversion tool selection is unresolved.** The design never specifies which tool converts PDFs to markdown. `pandoc` is known to fail on two-column layouts. `marker` (a newer academic PDF converter) handles multi-column better but has different dependencies. This must be decided before Phase 0 implementation — and the Critic's mandatory audit of 5 representative PDFs will reveal which tool is adequate for the corpus.

**Gap 2 — Cross-reference extraction completeness.** The `cross_refs` field is recommended but the extraction logic is not specified. A regex over "Definition N.N", "Lemma N.N", "Theorem N.N", and "[Author YYYY]" patterns will capture the most common forms but will miss informal references ("the above lemma", "our earlier result"). Coverage will be partial. Documented as a known limitation, not a blocker.

**Gap 3 — Chunk ID stability on re-ingestion.** If a document is re-converted and re-chunked (after a conversion quality improvement), chunk IDs will change, invalidating any bookmarks, access logs, or cached summaries. No teammate addressed ID stability strategy (content-hash vs. position-hash). This needs a decision before Phase 1 (when access logs and bookmarks are added).

**Gap 4 — Two-tier index synchronization.** Task 710 established two tiers of literature index: `~/Projects/Literature/index.json` and `specs/literature/index.json`. The proposed chunking system targets `~/Projects/Literature/`. The relationship between the two tiers during and after ingestion is not specified. The Critic flagged this as a staleness edge case.

**Gap 5 — Numbered environment detection.** The Critic correctly identifies that the real atomic units in formal verification papers are LaTeX-style numbered environments (Definition, Lemma, Theorem, Proof, Remark), not header sections. No teammate specified a concrete detection algorithm for these environments in converted markdown. This is a critical implementation detail for the `chunk_type` field.

---

### Recommendations

**Pre-implementation (before writing any code):**

1. **Audit markdown quality** — pick 5 representative PDFs (two-column, heavy math, commutative diagrams) from ~/Projects/Literature/ and verify their markdown. If significant corruption exists, resolve conversion first.
2. **Test the simple alternative** — run an agent that receives the full `index.json` (flattened to `{id, title, keywords, summary, path}` per entry) and must answer 5 research questions. If this works, use it for Phase 0 instead of FTS5.
3. **Select the conversion tool** — decide between `pandoc`, `marker`, or `nougat` based on audit findings. Document the choice.
4. **Measure TOC token cost** — run `jq '.entries[]' ~/Projects/Literature/index.json | wc -w` and document whether the full catalog fits in a single context call.

**Phase 0 MVP (1 day, core pipeline):**

- Ingest script: PDF → markdown (chosen tool) → chunk at headings → recursive split to 512-token leaves → write to SQLite
- Minimal schema: `documents` + `chunks(chunk_id, doc_id, section_path, chunk_type, content, token_count, prev_chunk_id, next_chunk_id)` + `chunks_fts` FTS5 virtual table with porter+unicode61 tokenizer
- Include `cross_refs` as JSON field extracted by regex during chunking
- Include `section_path` (breadcrumb) in FTS5 index for structural query support
- `literature-search.sh`: sanitize input, escape apostrophes, return structured errors, include `--limit` param

**Phase 1 (1 week, metadata enrichment):**

- Add LLM-generated `summary` and `keywords` via single-call enrichment at ingest
- Materialize JSON TOC tree (depth-parameterized browse tool)
- Add `chunk_relations` table with `cross_ref` relation type
- Add access logging, agent bookmarks, and summaries cache tables
- Decide and implement chunk ID stability strategy

**Phase 2 (deferred, only if FTS5 misses queries):**

- Add `sqlite-vec` for vector similarity search
- Add Reciprocal Rank Fusion (RRF) to combine FTS5 and vector rankings
- Embed chunks using a local model (e.g., nomic-embed-text via Ollama)

**Agent integration instructions** (add to `<literature-tool>` prompt):
- "If you do not find relevant literature within 3 searches, proceed without it and note in your output that literature was searched but not found."
- "Query syntax: avoid apostrophes and leading NOT operators; use simple phrase queries when possible."

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Chunking strategies, ideal sizes, tools | completed | high |
| B | Metadata schema, inter-chunk relations, TOC design, database | completed | high |
| C | Critic: gaps, failure modes, overlooked simplifications | completed | high |
| D | Strategic direction, MVP phasing, long-term scaling | completed | high |

---

## Sources

### Chunking Strategy (Teammate A)
1. [Best Chunking Strategies for RAG (and LLMs) in 2026 — Firecrawl](https://www.firecrawl.dev/blog/best-chunking-strategies-rag)
2. [Chunking Strategies for RAG Pipeline Performance — Weaviate](https://weaviate.io/blog/chunking-strategies-for-rag)
3. [Advanced RAG 01: Small-to-Big Retrieval — Medium (Sophia Yang)](https://medium.com/data-science/advanced-rag-01-small-to-big-retrieval-172181b396d4)
4. [MarkdownHeaderTextSplitter — LangChain Docs](https://docs.langchain.com/oss/python/integrations/splitters/markdown_header_metadata_splitter)
5. [TopoChunker: Topology-Aware Agentic Document Chunking Framework — arXiv 2603.18409](https://arxiv.org/html/2603.18409)
6. [Anthropic Introduces Contextual Retrieval — CO/AI](https://getcoai.com/news/anthropic-introduces-contextual-retrieval-to-boost-accuracy-of-rag-systems/)
7. [mdsplit — PyPI](https://pypi.org/project/mdsplit/0.3.1/)
8. [LEMMAHEAD: RAG Assisted Proof Generation — arXiv 2501.15797](https://arxiv.org/pdf/2501.15797)

### Metadata and Relations (Teammate B)
9. [Azure RAG Enrichment Phase Guide — Microsoft](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/rag/rag-enrichment-phase)
10. [MDKeyChunker: Single-Call LLM Enrichment — arXiv 2603.23533](https://arxiv.org/abs/2603.23533)
11. [PageIndex: Document Index for Vectorless RAG — VectifyAI](https://github.com/VectifyAI/PageIndex)
12. [Disco-RAG: Discourse-Aware RAG — arXiv 2601.04377](https://arxiv.org/pdf/2601.04377)
13. [IIER: Inter-Chunk Interactions — arXiv 2408.02907](https://arxiv.org/html/2408.02907v1)
14. [SQLite as a Graph Database — DEV Community](https://dev.to/rohansx/sqlite-as-a-graph-database-recursive-ctes-semantic-search-and-why-we-ditched-neo4j-1ai)
15. [Hybrid FTS5 + Vector Search with SQLite — Simon Willison](https://simonwillison.net/2024/Oct/4/hybrid-full-text-search-and-vector-search-with-sqlite/)

### Gaps and Concerns (Teammate C)
16. [Academic PDF to Markdown Conversion — blazedocs.io](https://blazedocs.io/blog/academic-pdf-to-markdown-guide)
17. [Seven Failure Points When Engineering a RAG System — arXiv 2401.05856](https://arxiv.org/abs/2401.05856)
18. [Vocabulary Mismatch — Wikipedia](https://en.wikipedia.org/wiki/Vocabulary_mismatch)
19. [SQLite FTS5 Extension — Official Documentation](https://sqlite.org/fts5.html)
20. [A New HOPE: Domain-agnostic Automatic Evaluation of Text Chunking — arXiv 2505.02171](https://arxiv.org/pdf/2505.02171)

### Strategic Direction (Teammate D)
21. [Andrej Karpathy's LLM Wiki — DAIR.AI Academy](https://academy.dair.ai/blog/llm-knowledge-bases-karpathy)
22. [Cache-Craft: Managing Chunk-Caches for Efficient RAG — arXiv 2502.15734](https://arxiv.org/abs/2502.15734)
23. [sqlite-vss: SQLite extension for vector search](https://github.com/asg017/sqlite-vss)
24. [AI Agent Memory: Types, Architecture and Implementation — Redis](https://redis.io/blog/ai-agent-memory-stateful-systems/)
