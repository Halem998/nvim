# Teammate D Findings: Strategic Horizons

**Task**: 721
**Focus**: Long-term direction, creative approaches, minimum viable design
**Confidence**: high

## Key Findings

1. **The Karpathy "LLM-as-compiler" pattern is the most relevant 2025-2026 innovation.** Rather than building a retrieval system that re-reads raw documents every session, the pattern uses the LLM to incrementally compile raw sources into a structured, interlinked markdown wiki once — and maintain it over time. At personal scale (200-2000 documents), this eliminates the need for embeddings or vector databases entirely. The wiki's own index files plus the LLM's context window are sufficient for retrieval. This is directly applicable to the ~/Projects/Literature/ system.

2. **SQLite FTS5 is sufficient up to ~200,000 chunks; the threshold is far above 200 documents.** Pure FTS5 keyword search benchmarks at 0.37ms average latency, nearly 40% faster than semantic (vector) search. With ~200 academic papers chunked to ~500-token pieces, the corpus is roughly 5,000-20,000 chunks — well inside FTS5's comfortable range. The scaling cliff occurs around 200,000 document chunks for vector search; FTS5 pure keyword search scales to millions of rows with millisecond latency.

3. **Hybrid FTS5 + vector search (Reciprocal Rank Fusion) is the next tier — not a different database.** When semantic similarity matters (e.g., "find papers discussing ideas like concept X without using that term"), adding sqlite-vec alongside FTS5 and using RRF to combine ranked results is the upgrade path. This keeps everything in a single SQLite file. Dedicated vector databases (Qdrant, Pinecone) are only needed at millions of shared vectors under concurrent multiuser load — irrelevant at personal scale.

4. **Lazy/on-demand chunking is a sound design.** Pre-chunking the entire corpus at ingest time is simpler, but chunking on first access (when an agent needs a document) is viable and avoids upfront cost. The access pattern for academic research is highly skewed: the top 5% of chunks account for 60% of retrievals across sessions. Lazy chunking naturally prioritizes that hot 5% without explicit optimization.

5. **Agent bookmarking and access-pattern learning are well-motivated and feasible.** Research on chunk caching (Cache-Craft, 2025) confirms that tracking which chunks are retrieved most frequently and caching them across sessions yields significant gains. The same infrastructure that enables FTS5 search (a SQLite table) can track `chunk_id` access frequency. A bookmarking table (`agent_bookmarks` with `chunk_id`, `note`, `session_id`, `created_at`) requires zero new dependencies.

6. **Summarization cache ("reading receipts") compounds value.** When an agent reads a chunk, having it write a one-sentence summary back to a `summaries` column in the chunks table creates a persistent annotation layer. Future agents querying the same chunk see prior synthesis. This is the wiki-compilation pattern applied at chunk granularity — practical with the existing SQLite schema.

7. **Minimum viable version is very small.** A one-day ship of this system is: (a) bash script that runs `pandoc` or `marker` on each PDF to produce markdown, (b) a Python script that splits by heading and writes chunks to a SQLite table with FTS5, (c) a shell function that runs `fts_search("query")` and returns the top-5 chunk texts. That's the floor that delivers real value. Everything else (access logging, bookmarks, summaries cache, lazy chunking) is additive.

8. **Obsidian/Logseq hybrid workflows are popular but agent-hostile.** Knowledge workers who use Obsidian + Zotero + Dataview maintain rich bidirectional link graphs, but these graphs are human-navigated. For autonomous agent access, the flat SQLite FTS5 interface is strictly superior — agents can't "follow links" the way humans do, but they can execute precise SQL queries.

## Recommended Approach

**Phase 0 (MVP, 1 day)**: Ingest pipeline + FTS5 search only.
- Convert PDFs to markdown (marker or pandoc)
- Split at headings, write to `chunks(id, doc_id, heading_path, text, char_count)` with FTS5 virtual table
- Search function returns top-N chunks with their `heading_path` as context

**Phase 1 (1 week)**: Add access tracking and bookmarking.
- `chunk_access_log(chunk_id, session_id, timestamp)` table — one INSERT per agent read
- `chunk_summaries(chunk_id, summary, written_by_session)` table — populated by agents on read
- `agent_bookmarks(chunk_id, note, session_id, created_at)` table — agents write explicitly

**Phase 2 (if needed, months later)**: Add vector search when FTS5 misses queries.
- Add `sqlite-vec` extension
- Embed chunk text with a local model (e.g., nomic-embed-text via Ollama)
- Add RRF fusion layer in the search function

**Do not add Phase 2 until FTS5 search demonstrably fails to satisfy queries.** At 200 documents, it won't.

**Avoid**: Obsidian/graph-based retrieval (agent-hostile), dedicated vector databases (over-engineered for this scale), pre-computed embeddings at ingest time (front-loads cost with no benefit at this scale).

## Evidence/Examples

- **Karpathy's LLM Wiki** (April 2026): A single research topic grew to ~100 articles and 400,000 words with no manual writing. The three-layer architecture (raw sources → compiled wiki → derived outputs) shows that at personal scale, the LLM's context window replaces vector retrieval entirely. Reference: nashsu/llm_wiki on GitHub.

- **FTS5 benchmark**: 0.37ms average latency at blog scale (tens of thousands of rows). SQLite with NumPy vector search handles ~50,000 documents in under 1 second; past ~200,000, ANN indexes become necessary. The Literature system (200 docs → 5,000-20,000 chunks) is 10-40x below this threshold.

- **Cache-Craft (2502.15734, 2025)**: Confirms that the top 5% of chunks account for 60% of retrievals. Tracking access frequency in the same SQLite database as chunks is sufficient to build an effective cache with zero new dependencies.

- **Hybrid FTS5+vector RRF** (Simon Willison, 2024): Demonstrates that sqlite-vec plus FTS5 with RRF fusion stays inside a single SQLite file and avoids the score incomparability problem by using positional rank rather than raw scores.

- **Two-tier agent memory** (Redis AI Agent Memory post, 2026): Compact keyword index at session start, full content on demand. This is the same architecture as the proposed chunking system — agents receive search results (compact), then fetch full chunks on demand (content).

- **Roadmap context**: Task 710 (completed 2026-06-14) centralized literature at ~/Projects/Literature/ with Zotero integration and a v2 index schema. The proposed system should build on that foundation rather than replace it.

## Sources

1. [Andrej Karpathy's LLM Wiki - DAIR.AI Academy](https://academy.dair.ai/blog/llm-knowledge-bases-karpathy)
2. [Beyond RAG: How Karpathy's LLM Wiki Pattern Builds Knowledge That Compounds](https://levelup.gitconnected.com/beyond-rag-how-andrej-karpathys-llm-wiki-pattern-builds-knowledge-that-actually-compounds-31a08528665e)
3. [Hybrid full-text search and vector search with SQLite (Simon Willison, 2024)](https://simonwillison.net/2024/Oct/4/hybrid-full-text-search-and-vector-search-with-sqlite/)
4. [sqlite-vss: SQLite extension for vector search](https://github.com/asg017/sqlite-vss)
5. [Cache-Craft: Managing Chunk-Caches for Efficient RAG (arXiv 2502.15734)](https://arxiv.org/abs/2502.15734)
6. [AI Agent Memory: Types, Architecture & Implementation (Redis)](https://redis.io/blog/ai-agent-memory-stateful-systems/)
7. [Best Chunking Strategies for RAG in 2026 (Firecrawl)](https://www.firecrawl.dev/blog/best-chunking-strategies-rag)
8. [SQLite FTS5 Hybrid Memory vs Dedicated Vector Databases (ZeroClaw)](https://zeroclaws.io/blog/zeroclaw-sqlite-fts5-vector-hybrid-memory-explained/)
9. [Semantic Caching in RAG Systems & AI Agents (DEV Community)](https://dev.to/sreeni5018/semantic-caching-in-rag-systems-ai-agents-2gal)
10. [Inside ZeroClaw's Hybrid Memory: SQLite + FTS5 + Vectors](https://zeroclaws.io/blog/zeroclaw-sqlite-fts5-vector-hybrid-memory-explained/)
