# Research Report: Task #721 — Teammate A Findings
# Primary Implementation Approaches for Targeted Literature Retrieval

**Task**: 721 - Design Targeted Literature Retrieval to Replace Bulk Injection
**Role**: Teammate A — Primary Implementation Approaches
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Focus**: Five candidate approaches evaluated in depth using web search (June 2026)

---

## Executive Summary

The current `literature-retrieve.sh` uses bag-of-words overlap on `keywords[]` and `summary` fields. With 183 entries at 5000+ tokens each and an 8000-token budget, selection quality is critical — roughly 1.5 entries fit on average, so wrong selection is a hard miss.

Five approaches were evaluated. The clearest verdict from June 2026 best practices:

1. **SQLite FTS5 with BM25** — The strongest single-backend upgrade. Already available in `sqlite3` CLI, no Python required, dramatic improvement over bag-of-words overlap. **Recommended primary approach.**
2. **Enhanced jq/JSON scoring** — Viable as a zero-dependency improvement to the current system, but fundamentally limited by lack of content-level search.
3. **Agent-callable on-demand retrieval** — The 2026 architectural best practice for AI agents, but requires restructuring from preflight injection to tool-call patterns.
4. **Lightweight vector/embedding search** — Best accuracy, but requires Python and significant first-run model download; adds maintenance burden for git-tracked repos.
5. **Hybrid BM25 + embeddings (RRF)** — Production-grade quality, but combines the dependencies of both approach 3 and 4.

---

## Approach 1: SQLite FTS5 with BM25

### What It Is

SQLite's FTS5 (Full-Text Search v5) extension provides an inverted index with built-in BM25 ranking. It ships with `sqlite3` on all modern Linux/macOS systems (bundled since SQLite 3.9.0, 2015). BM25 (Best Matching 25) accounts for term frequency, inverse document frequency, and document length normalization — a substantial improvement over simple keyword overlap.

### How It Works in Practice (2026)

From the TheLinuxCode guide and SQLite official docs:

```bash
# Build the index (one-time or on-change)
sqlite3 literature.db <<'SQL'
CREATE VIRTUAL TABLE IF NOT EXISTS lit_fts
  USING fts5(id UNINDEXED, title, keywords, summary, content);
SQL

# Insert documents (scripted from index.json + file contents)
# Query with BM25 ranking
sqlite3 literature.db "
SELECT id, bm25(lit_fts, 0, 5.0, 3.0, 1.0) AS rank
FROM lit_fts
WHERE lit_fts MATCH 'lean4 proof modal logic'
ORDER BY rank
LIMIT 10;
"
```

Column weights (0, 5.0, 3.0, 1.0) map to (id=ignore, title=5x, keywords=3x, summary=1x, content=1x). This means title and keyword matches score much higher than incidental content matches.

### Key Capabilities vs. Current System

| Feature | Current (bag-of-words) | SQLite FTS5 BM25 |
|---------|------------------------|-------------------|
| Term frequency weighting | No | Yes (BM25) |
| IDF (rare terms score higher) | No | Yes |
| Document length normalization | No | Yes |
| Content body search | No | Yes (can index full text) |
| Column weighting | No | Yes (per-column weights) |
| Phrase matching | No | Yes ("exact phrase") |
| Prefix search | No | Yes (pyth* → python) |
| Boolean operators | No | Yes (AND/OR/NOT) |
| Proximity search | No | Yes |

### Performance at 200-1000 Documents

The TheLinuxCode guide describes FTS5 delivering "snappy search on typical hardware" at 50k+ rows. For 183-1000 entries, query time is effectively instantaneous. Indexing 183 markdown files (even full content) takes under 1 second on modern hardware.

### Dependencies

- `sqlite3` CLI — pre-installed on macOS/Linux, available on all target systems
- Bash (already used in `literature-retrieve.sh`)
- No Python, no pip, no network access for operation

### Maintenance Burden and Git Tracking

**This is the key tradeoff.** The SQLite `.db` file is binary and changes on every index update. Options:

1. **Gitignore the `.db`** and rebuild at retrieval time — clean git history, ~1s rebuild cost on each `/research` invocation with 183 docs.
2. **Gitignore and cache** — rebuild only when `index.json` modification time changes (fast, simple caching with a sentinel file).
3. **Committed `.db`** — convenient but binary bloat in git history; not recommended.

The memweave pattern (from Towards Data Science) uses option 1: markdown files are the source of truth, SQLite is a derived index that never goes in git. This maps well to the existing architecture where `specs/literature/` files are committed and an ephemeral `.db` is built on demand.

From the memweave article: "Version control becomes intrinsic—every agent-learned fact is auditable as a line in a committed file, with full diffs showing what changed, when, and why." The SQLite file would go in `.gitignore`.

### Accuracy/Relevance Quality

BM25 is the industry standard for keyword search. FTS5's BM25 implementation has been battle-tested since 2016. For the literature retrieval use case (finding relevant papers for a task description), BM25 dramatically outperforms bag-of-words overlap:
- Rare, specific terms score much higher (IDF weighting)
- Term frequency is counted (multiple matches in title score better)
- Document length normalization prevents long summaries from artificially winning

If content bodies are included in the FTS5 table, the index can even match against paper body text, not just metadata fields.

### Implementation Complexity

**Low-to-medium.** The logic in `literature-retrieve.sh` can be replaced with:
1. A one-time or cached index-build step (bash + sqlite3 + jq to read index.json)
2. A single `sqlite3` query to get ranked IDs
3. The same file-reading loop (already exists)

Estimated change: ~100 lines replacing the current jq scoring block, plus a `.gitignore` entry.

### Evidence/Examples

- [SQLite FTS5 Extension Official Docs](https://sqlite.org/fts5.html)
- [SQLite FTS5 in Practice: Fast Search, Ranking, and Real-World Patterns](https://thelinuxcode.com/sqlite-full-text-search-fts5-in-practice-fast-search-ranking-and-real-world-patterns/)
- [memweave: Zero-Infra AI Agent Memory with Markdown and SQLite](https://towardsdatascience.com/memweave-zero-infra-ai-agent-memory-with-markdown-and-sqlite-no-vector-database-required/)
- [SQLite FTS5 Comprehensive Guide for Code Indexing (MCP server)](https://glama.ai/mcp/servers/@ViperJuice/Code-Index-MCP/blob/e3183d0106c586aec03535faabe632b4db4d6046/ai_docs/sqlite_fts5_overview.md)

**Confidence: High**

---

## Approach 2: Enhanced jq/JSON Scoring

### What It Is

Improvements to the existing jq-based scoring in `literature-retrieve.sh` without introducing new dependencies. This means staying in pure bash + jq but implementing better scoring heuristics:

- **Title match bonus** (currently absent — title is not searched)
- **Keyword positional weighting** (exact keyword order, not just overlap)
- **IDF-like weighting** (precomputed in index.json: rare keywords score higher)
- **Multi-field combination**: keywords + summary + title with different weights
- **Content search**: if content previews or abstract fields are stored in index.json

### What's Possible with jq

The current scoring assigns 1 point per keyword match in `keywords[]` and 1 bonus point for any summary match. A meaningfully enhanced version could:

```bash
# Conceptual: title=3x, keywords=2x, summary=1x, IDF from precomputed rarity
scored=$(jq --argjson kw "$keywords_json" '
  map(
    . as $e |
    ([$kw[] | ascii_downcase] | map(
      . as $k |
      ( if ([$e.keywords[]? | ascii_downcase] | index($k)) then 2 else 0 end ) +
      ( if ($e.title // "" | ascii_downcase | test($k)) then 3 else 0 end ) +
      ( if ($e.summary // "" | ascii_downcase | test($k)) then 1 else 0 end )
    ) | add // 0) as $score |
    {id: $e.id, path: $e.path, score: $score, token_count: $e.token_count}
  ) | map(select(.score > 0)) | sort_by(-.score)
')
```

### Fundamental Limitations

This approach cannot overcome the core problem: **it only searches metadata stored in index.json, not document content**. With 183 entries, a task description containing terminology that doesn't appear verbatim in the `keywords[]` array will miss relevant documents. jq also has no IDF capability — it cannot know that "lean4" is a rare/specific term while "logic" appears in 80% of entries.

For a small corpus where keywords are carefully curated by a human (which may be the case for `specs/literature/`), this could be adequate. For programmatically-generated or sparse keyword arrays, it will miss important documents.

### Dependencies

Zero. This is a pure improvement to the existing bash+jq system.

### Maintenance Burden

Lowest of all approaches. The current `literature-retrieve.sh` already implements this pattern; enhancement is additive.

### Implementation Complexity

Very low. A few hours of jq coding changes to the existing scoring block.

### Accuracy/Relevance Quality

Moderate improvement over current. Title matching is a meaningful gain (currently unimplemented). But fundamentally limited by metadata quality and lack of IDF weighting.

### Evidence/Examples

- [Azure AI Search: Scoring Profiles and Field Weighting](https://learn.microsoft.com/en-us/azure/search/index-add-scoring-profiles)
- [Weighing Search Results — Personal Search Engine](https://jamesg.blog/2021/08/06/weighing-search-results/)
- Elastic App Search Relevance Tuning Guide confirms title=3x, summary=2x, content=1x as common defaults

**Confidence: High (for what it can achieve), Low (for whether it solves the core problem)**

---

## Approach 3: Agent-Callable On-Demand Retrieval

### What It Is

Instead of a preflight bash script injecting literature into the agent's context, the agent is given a **tool** to search literature on demand, calling it when it decides retrieval is relevant and with a query it formulates itself.

In Claude Code's architecture, this could be:
- A bash tool the agent calls: `bash .claude/scripts/literature-search.sh "lean4 modal logic"`
- An MCP tool (if a literature MCP server is configured)
- A read-from-index pattern where the agent reads `specs/literature/index.json` directly and calls `Read` on specific files

### The 2026 State of the Art

This is the **dominant architecture** for AI agents in 2026. From multiple sources:

> "Instead of stuffing all possible information into the prompt upfront, agents should retrieve context on demand using the ReAct pattern, where the model reasons about what information it needs, acts to retrieve it, then reasons again with the new context." — FutureAGI Agentic RAG Guide 2026

> "Even keyword-based rules cut context bloat before you invest in LLM-based classification." — State of Context Engineering 2026

> "Monitor-based RAG maintains concise reasoning by injecting only the evidence that is needed precisely when it is needed, delivering comparable knowledge augmentation with markedly fewer tokens and iterations." — Search results on agentic retrieval

The parallel tool call pattern (from the Relace FAS paper) showed **4x latency reduction** while maintaining accuracy through parallelizing retrieval calls.

### Applicability to the Current System

The current `--lit` system is a **preflight injection**: the script runs before the agent starts and injects whatever it selects. This means:
- The agent cannot refine its query based on what it finds
- The agent cannot retrieve additional documents mid-task
- Selection happens with zero task context (just task description + type)

An on-demand tool approach would let the agent:
1. Start working on the task
2. When it identifies it needs reference material, call `literature-search "BM25 ranking algorithm"`
3. Get back relevant file contents
4. Continue working with precisely the documents it needs

### Implementation Options for Claude Code

Option A: **Bash tool call** (simplest): The agent calls the literature search script directly with a refined query. No architecture change needed — just expose the search as an agent-callable command.

Option B: **Agent reads index.json directly**: The agent uses `Read` to examine `specs/literature/index.json`, identifies relevant entries, then calls `Read` on specific files. This is already possible but requires the agent to do scoring itself.

Option C: **MCP-based literature server**: A local MCP server provides `literature_search` tool. Full-featured but adds significant infrastructure.

### Tradeoffs

| Factor | On-Demand | Preflight Injection |
|--------|-----------|---------------------|
| Relevance quality | Higher (agent refines) | Lower (blind selection) |
| Token cost | Lower (fetches only what it needs) | Higher (may inject irrelevant) |
| Latency | Higher (extra LLM calls) | Lower (single pass) |
| Architecture change | Significant | None |
| Backward compatibility | Breaking change | Incremental |

From the FutureAGI guide: "On-demand retrieval uses 3-8 LLM calls + 2-6 retrieves versus classic RAG's single pass, exchanging latency for faithfulness on hard questions."

The key consideration: this isn't just a scoring improvement — it's a **paradigm shift** from push (inject before the agent starts) to pull (agent fetches when it decides). For the current `--lit` flag workflow, this would mean the preflight script becomes a no-op or lightweight index loader, and the real retrieval happens through agent tool calls.

### Dependencies

Depends on implementation option chosen:
- Option A: Improved `literature-retrieve.sh` (callable with query) — zero new deps
- Option B: No new deps (agent reads files directly)
- Option C: MCP server — significant new infrastructure

### Maintenance Burden

Low for Options A and B, moderate for Option C.

**Confidence: High (for architectural validity), Medium (for practical implementation complexity in current system)**

---

## Approach 4: Lightweight Vector/Embedding Search

### What It Is

Using local embedding models to compute semantic similarity between the task description and each literature document, without requiring an external API or server.

Key options as of June 2026:

1. **sentence-transformers/all-MiniLM-L6-v2**: 22MB model, 5x faster than larger models, good quality. Pure Python, runs locally.
2. **BM25S**: Not embeddings, but pure Python BM25 (numpy+scipy only) that outperforms rank-bm25 by 500x.
3. **sqlite-vec**: SQLite extension (C, no dependencies) that adds vector search to SQLite — pairs with FTS5 for a hybrid approach.
4. **ChromaDB / LanceDB**: Embedded vector databases (no server), Python-based.
5. **USearch**: C++ library with Python bindings, compact FAISS alternative.

### All-MiniLM-L6-v2 Setup

```python
from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer("all-MiniLM-L6-v2")
# First run: downloads ~22MB model
task_embedding = model.encode(task_description)
doc_embeddings = np.load("literature_embeddings.npy")
similarities = np.dot(doc_embeddings, task_embedding)
top_indices = np.argsort(similarities)[::-1][:10]
```

### Performance at 200-1000 Documents

For 183 documents, cosine similarity with a 384-dimensional MiniLM embedding takes ~1ms (dot product on 183×384 matrix). Embedding generation for 183 documents takes ~2-5 seconds on first index build, then <1ms for query-time encoding.

### Key Issues for This Use Case

1. **First-time model download**: 22MB model download on first use. Acceptable for one-time setup, but requires network access.
2. **Python dependency**: Not callable directly from bash. Requires `python3 -m sentence_transformers` or a wrapper script.
3. **Index files are binary numpy arrays**: `.npy` files are binary, must be gitignored and rebuilt.
4. **Cold start**: Even after index build, loading Python + sentence-transformers adds ~3-5s startup overhead vs sqlite3's ~100ms.
5. **Model drift**: Model updates can invalidate cached embeddings, requiring full reindex.

### BM25S as Pure-Python Alternative

BM25S (numpy+scipy only) provides dramatically better BM25 than the current jq implementation:
- 500x faster than rank-bm25
- Saves/loads index to disk
- No Java, no external services
- But still requires Python (not callable directly from bash without a wrapper)

### Accuracy/Relevance Quality

For semantic tasks (finding a paper about "modal logic" when the task says "formal verification of temporal properties"), vector search dramatically outperforms keyword matching. MiniLM achieves strong performance on semantic similarity benchmarks.

However, vector search can miss exact-match requirements: a task asking about "Lean4 `apply` tactic" should strongly match a document with those exact terms, and BM25 outperforms vectors here.

### Dependencies

- Python 3.x (available on target systems)
- `sentence-transformers` (pip install, ~500MB with PyTorch)
- OR: `bm25s` (pip install, ~50MB with numpy+scipy)
- `numpy` (usually pre-installed)

**This is a significant dependency increase** compared to the current pure-bash approach.

### Maintenance Burden

Moderate. Need to:
- Maintain Python virtual environment or global install
- Rebuild index when documents change
- Handle model updates
- Gitignore `.npy` and model cache files

**Confidence: High (for technical capability), Low (for fit with current bash-based architecture)**

---

## Approach 5: Hybrid BM25 + Embedding Search (RRF)

### What It Is

Combining keyword-based retrieval (BM25) with semantic vector retrieval and merging results using Reciprocal Rank Fusion (RRF). RRF avoids the score normalization problem by working purely on ranks:

```python
def rrf(bm25_results, vector_results, k=60):
    scores = {}
    for rank, doc_id in enumerate(bm25_results, 1):
        scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank)
    for rank, doc_id in enumerate(vector_results, 1):
        scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank)
    return sorted(scores, key=scores.get, reverse=True)
```

This is simple enough to implement without libraries. The RRF formula with k=60 is the industry default.

### Current Best Practice (June 2026)

From the production hybrid retrieval guide (atalupadhyay.wordpress.com, June 2026):
> "For ~57k short documents, this is only ~33MB" and "no external database needed. For most real-world use cases (under 1 million chunks), this approach works perfectly"

From the RRF blog (avchauzov, 2025):
> "Hybrid search adds minimal latency (~10ms fusion overhead) while improving recall by 25-30% on queries requiring exact matches."

The memweave system uses exactly this pattern: FTS5 BM25 (30%) + sqlite-vec cosine (70%) merged via weighted combination. This is the same concept as RRF but with score-based rather than rank-based fusion.

### Implementation Stack for This Use Case

The cleanest small-scale hybrid implementation:
1. **SQLite FTS5** for BM25 (already covered above)
2. **sqlite-vec** (C extension) or **numpy cosine similarity** for vector search
3. **RRF merge** in Python or bash (trivial math)

### Git Tracking Implications

- `.db` file: binary, gitignored (rebuild on demand)
- `.npy` embeddings: binary, gitignored (rebuild on change detection)
- Source truth: `index.json` + `*.md` files (already committed)

From the production guide: "Add `indexes/` directory to `.gitignore`. Rebuild indices from source corpus on deployment."

### Accuracy/Relevance Quality

**Best of all approaches.** Research consistently shows 25-30% recall improvement over either method alone. For diverse task descriptions (some needing exact term matches, some needing semantic similarity), hybrid retrieval covers both failure modes.

### Dependencies

- `sqlite3` CLI (already available)
- Python 3 + numpy (nearly universal)
- Optional: `sentence-transformers` for high-quality embeddings OR an API call for embeddings

### Implementation Complexity

**Medium-high.** Requires implementing both backends and the merge logic. Probably 200-300 lines of new code vs the current ~100-line jq scoring block.

### Maintenance Burden

Moderate. Two index types to manage, both gitignored and rebuilt on change.

**Confidence: High (for quality), Medium (for implementation fit)**

---

## Comparative Summary Table

| Approach | Relevance Quality | Impl. Complexity | Dependencies | Git Impact | Works at 200 Docs |
|----------|------------------|------------------|--------------|------------|-------------------|
| 1. SQLite FTS5 BM25 | High | Low-Medium | sqlite3 (pre-installed) | .db gitignored | Excellent |
| 2. Enhanced jq scoring | Low-Medium | Very Low | None (pure bash) | None | Limited |
| 3. Agent on-demand | Highest (agent decides) | Medium-High | None (bash) or Python | None | Excellent |
| 4. Vector/embedding | Very High | Medium | Python + pip | .npy gitignored | Excellent |
| 5. Hybrid BM25+vectors | Best | High | sqlite3 + Python + pip | .db + .npy gitignored | Best |

---

## Recommended Approach

### Short Term: SQLite FTS5 BM25 (Approach 1)

**Strongest bang-for-buck with minimal new dependencies.** The `sqlite3` CLI is already available on all target systems. Replacing the jq scoring block with SQLite FTS5 provides:
- True BM25 ranking (IDF + TF + length normalization)
- Column-weighted scoring (title > keywords > summary > content)
- Full-content search capability (can index document bodies, not just metadata)
- Phrase and boolean query support
- Zero new package installs

The `.db` file is gitignored and rebuilt on demand. For 183 documents, rebuild takes <1 second.

**Suggested enhancement to index.json**: Add a `content_preview` field (first 500 tokens of each document) to make content-level BM25 scoring available without full-file reads at index time.

### Medium Term: Agent On-Demand Retrieval (Approach 3)

Once the immediate scoring quality problem is fixed via FTS5, the bigger architectural improvement is making the search agent-callable. The current preflight injection model sends a blind selection before the agent even knows what it needs. A tool-callable `literature-search` command allows the agent to:
1. Formulate its own query based on task context
2. Retrieve iteratively as understanding develops
3. Use only what's relevant

This aligns with the dominant 2026 pattern for AI agents and would apply to the broader context engineering system (memory retrieval shares the same fundamental pattern).

### Long Term: Hybrid (Approach 5)

For a literature corpus with deep semantic content (academic papers, formal specs), vector search finds relevant documents that use different terminology. RRF-merged BM25+vectors achieves the best recall. This is appropriate once the dependency story (Python, sentence-transformers or API) is accepted.

---

## Key Constraints to Communicate to Other Teammates

1. **The `.db` file must be gitignored** — SQLite databases are binary, change on every write, and have no sensible merge semantics.

2. **The index.json `content_preview` field** would enable meaningful content-level BM25 scoring without storing full text in the index. Recommend a 300-500 token summary or abstract per entry.

3. **Rebuild caching**: Use the modification time of `index.json` as a sentinel to avoid rebuilding the FTS5 index on every invocation. Only rebuild when `index.json` is newer than `literature.db`.

4. **Token budget compatibility**: The current `TOKEN_BUDGET=8000` and `MAX_FILES=10` logic is independent of the scoring approach — the greedy selection loop can stay identical; only the scoring that produces the ranked list changes.

5. **The `--lit` flag paradigm** is essentially preflight RAG injection. Moving toward agent-callable search requires changes to how skills invoke the retrieval step (not just the script itself).

---

## Appendix: Search Queries Used

1. "SQLite FTS5 BM25 local document search best practices 2025 2026"
2. "AI agent RAG tool-use document retrieval patterns 2025 2026 best practices"
3. "lightweight local vector embedding search small corpus no server 2025 2026"
4. "hybrid keyword semantic search small scale local documents 2025 2026"
5. "TF-IDF JSON scoring document retrieval jq bash shell script"
6. "SQLite FTS5 shell script bash command line document indexing 2025"
7. "agent tool-use on-demand retrieval vs bulk injection context window LLM 2025 2026"
8. "usearch faiss-lite nanopq local embedding search python no server small dataset"
9. "RRF reciprocal rank fusion BM25 embeddings hybrid search implementation 2025"
10. "sqlite3 command line FTS5 BM25 search bash script example index markdown files"
11. "sqlite FTS5 git tracked binary file .db gitignore agent memory 2025"
12. "chromadb lancedb local no-server embedding search python 200 documents 2025 lightweight"
13. "bm25s rank-bm25 python library local document retrieval no dependencies 2025"
14. "sentence-transformers all-MiniLM local embedding generation no API 200 docs search 2025"
15. "sqlite-vec sqlite vector search extension lightweight 2025 local embedding"
16. "agent callable search tool MCP literature retrieval on-demand 2025 implementation bash"

---

## References

- [SQLite FTS5 Official Documentation](https://sqlite.org/fts5.html)
- [SQLite FTS5 in Practice — TheLinuxCode](https://thelinuxcode.com/sqlite-full-text-search-fts5-in-practice-fast-search-ranking-and-real-world-patterns/)
- [memweave: Zero-Infra AI Agent Memory with Markdown and SQLite — Towards Data Science](https://towardsdatascience.com/memweave-zero-infra-ai-agent-memory-with-markdown-and-sqlite-no-vector-database-required/)
- [Agentic RAG: Developer Guide to Smarter Retrieval (2026) — FutureAGI](https://futureagi.com/blog/agentic-rag-systems-2025/)
- [State of Context Engineering in 2026 — SwirlAI Newsletter](https://www.newsletter.swirlai.com/p/state-of-context-engineering-in-2026)
- [Hybrid Retrieval with RRF: Solving the Score Normalization Problem — Andrey Chauzov](https://avchauzov.github.io/blog/2025/hybrid-retrieval-rrf-rank-fusion/)
- [Building a Production-Ready Hybrid Retrieval System — atalupadhyay (June 2026)](https://atalupadhyay.wordpress.com/2026/06/10/building-a-production-ready-hybrid-retrieval-system-from-scratch-bm25-dense-embeddings-rrf-re-ranking/)
- [Exploiting Parallel Tool Calls to Make Agentic Search 4x Faster — Relace](https://relace.ai/blog/fast-agentic-search)
- [BM25S: Fast BM25 Search in Python — HuggingFace Blog](https://huggingface.co/blog/xhluca/bm25s)
- [BM25S GitHub](https://github.com/xhluca/bm25s)
- [sqlite-vec: Embedded Vector Search — DEV Community](https://dev.to/aairom/embedded-intelligence-how-sqlite-vec-delivers-fast-local-vector-search-for-ai-3dpb)
- [Embedded Intelligence: sqlite-vec for Local AI — Mozilla Builders](https://builders.mozilla.org/project/sqlite-vec/)
- [RRF with BM25 and Semantic Search — GitHub carloodq](https://github.com/carloodq/rrf)
- [Tool Search Tool — Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)
- [Agent Skills — Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
