# Research Report: Task #721 — Teammate B Findings
# Alternative Patterns and Prior Art for Targeted Literature Retrieval

**Task**: 721 - Design targeted literature retrieval to replace bulk injection
**Role**: Teammate B — Alternative patterns and prior art
**Completed**: 2026-06-14
**Focus**: How other AI coding tools handle document retrieval; MCP servers; Zotero integration; academic retrieval patterns; the "just let the agent grep" argument

---

## Key Findings (Summary)

1. **The grep-vs-index debate is settled for personal scale**: At <1,000 documents, BM25 keyword matching finds the right document 90%+ of the time with no index overhead. Agentic grep beats pre-built vector search in recent benchmarks (68% vs 60% accuracy across harness tests). For 183 entries this strongly favors enhanced jq/shell scoring over embeddings.

2. **The field has converged on hybrid retrieval (BM25 + vector + RRF)** for production document search: SQLite FTS5 (BM25) + sqlite-vec (dense) + Reciprocal Rank Fusion. This is now the standard pattern in MCP servers, Obsidian integration, and documentation search systems built in 2025-2026.

3. **MCP-based document search is mature**: There are 16,500+ MCP servers as of early 2026, including dedicated RAG servers. The `ck` tool (Rust, MCP-native), `ragdocs` MCP server, and `sqlite-memory-mcp` all implement hybrid retrieval. This is off-the-shelf territory.

4. **Zotero has multiple MCP integrations**: `cookjohn/zotero-mcp` is a native Zotero-7 plugin exposing 20 MCP tools with Boolean full-text search, annotation search, and relevance scoring. PapersGPT provides fully local RAG (embeddings + vector DB + rerank, no internet required). These are the two main paths for Zotero integration.

5. **"Preflight injection" is losing to "on-demand retrieval"**: Anthropic's own guidance favors just-in-time loading. OpenHands uses keyword-triggered skill injection (matching on user message keywords at call time, not pre-computed). Continue.dev deprecated its `@docs` provider in favor of MCP-based on-demand retrieval via Context7. The direction of travel is clear.

6. **The strongest argument for "just let the agent grep"**: For a personal collection with self-authored descriptions, the author uses the same vocabulary when searching as when writing. The semantic gap is near-zero. A ~200-line shell script beats a full embedding pipeline. Agent harness choice matters as much as retrieval method (arxiv 2605.15184).

---

## Section 1: How AI Coding Tools Handle Document Retrieval in 2026

### Windsurf (Codeium)

Windsurf generates local embeddings for files/functions/classes at project open, stores them in an incremental local index, and uses RAG to pull relevant snippets into a ~200K-token context window automatically. Users do nothing. The embeddings, not raw source, power retrieval (privacy-preserving). This is the "fully automatic, always-on" pattern.

**Relevance to task**: This is the premium end. For 183 literature entries this would work but is heavy infrastructure for a shell-script context system.

Source: [Windsurf Context Engine](https://markaicode.com/windsurf-flow-context-engine/)

### Cursor

Takes the opposite approach: explicit, manual context curation via `@file`, `@folder`, `@codebase`. The user drives what goes into context. `@codebase` triggers semantic search across the project. No automatic injection.

**Relevance**: Cursor's `@docs` pattern (user explicitly requests document search at query time) is closer to what the literature system could evolve toward — on-demand rather than preflight bulk injection.

### Continue.dev

Continue uses a three-layer approach:
1. Embeddings stored locally via transformers.js in `~/.continue/index`
2. AST parsing via tree-sitter
3. Fast text search via ripgrep

The `@docs` context provider was recently **deprecated** in favor of:
- Context7 MCP for public documentation
- Custom MCP servers for internal documentation
- Rules files that reference documentation URLs

**Key signal**: A mature AI IDE tool has moved away from bulk doc injection toward MCP-mediated on-demand retrieval. This is directionally significant.

Source: [Continue.dev docs](https://docs.continue.dev/customize/deep-dives/docs), [DeepWiki](https://deepwiki.com/continuedev/continue/3.3-context-providers)

### Aider

Aider takes a pragmatic hybrid approach:
- Automatic "repository map" built from the whole codebase for context
- External files can be attached as read-only (fresh-loaded each request)
- Conventions file for structured context injection

The "attached files" mechanism (read-only, reloaded each call) is architecturally similar to what `literature-retrieve.sh` does but without scoring. Aider's repo map is essentially a BM25-like relevance filter over the codebase.

Source: [Aider FAQ](https://aider.chat/docs/faq.html)

### OpenHands (2025 V1 SDK)

OpenHands' skill system uses keyword-triggered context injection:
- Skills are markdown files with YAML frontmatter
- `KeywordTrigger` activates a skill when matching words appear in the user message
- Repository skills (always active) vs knowledge skills (keyword-triggered) vs task skills (keyword + input)
- Skills inject into system prompt dynamically at call time

**Key pattern**: This is exactly what an improved `literature-retrieve.sh` could do — extract keywords from the task description (which already happens) and activate matching skill content. The difference: OpenHands uses string matching against the *incoming message*, while the literature system scores against *index keywords*.

Source: [OpenHands Skill Docs](https://docs.openhands.dev/sdk/arch/skill)

### SWE-agent / ContextBench

A 2026 benchmark paper (arxiv 2602.05892) studied how different agent harnesses affect context retrieval:
- Explicit pre-submission constraint: agent must output code context before submission
- Finding: agent architecture matters as much as retrieval method
- SWE-agent, OpenHands, Claude Code all tested

**Relevance**: The harness (how context is requested and presented) shapes outcomes more than the retrieval algorithm in isolation. This argues for designing the retrieval interface carefully, not just the scoring function.

---

## Section 2: MCP-Based Document Search Servers

The MCP ecosystem as of early 2026 has 16,500+ servers and 97M monthly SDK downloads. Several directly address local document search:

### sanderkooger/ragdocs (PulseMCP)

A dedicated MCP server for RAG documentation search:
- Semantic search via vector embeddings
- Source attribution on all retrieved chunks
- Simple installation via `server.json`
- Designed specifically for documentation retrieval workflows

Source: [PulseMCP ragdocs](https://www.pulsemcp.com/servers/sanderkooger-ragdocs)

### RMANOV/sqlite-memory-mcp

SQLite-backed MCP memory server with:
- FTS5 with BM25 ranking (Python stdlib, no dependencies)
- Hybrid: BM25 + semantic via sqlite-vec cosine similarity
- Reciprocal Rank Fusion for score merging
- WAL concurrent safety
- Cross-machine sync bridge

This is the most directly relevant off-the-shelf option. It demonstrates that FTS5 + sqlite-vec + RRF in a single SQLite file is viable and well-implemented.

Source: [GitHub sqlite-memory-mcp](https://github.com/RMANOV/sqlite-memory-mcp)

### BeaconBay/ck (Rust, hybrid BM25+semantic)

A local-first code and document search tool with MCP integration:
- Rust workspace with modular components (`ck-cli`, `ck-engine`, `ck-index`, `ck-embed`)
- Hybrid search: BM25 keyword + FastEmbed vector + RRF fusion
- Language-aware chunking via `ck-chunk`
- Chunk-level incremental indexing (80-90% cache hit rates)
- MCP tools: `semantic_search`, `regex_search`, `hybrid_search`, `index_status`
- Returns `(file, [start_line, end_line])` spans rather than full files

**Key insight**: Returns spans, not full files — this is important for a token-budget-constrained system. Rather than injecting whole literature files, a span-based approach could inject only the most relevant passages.

Source: [GitHub BeaconBay/ck](https://github.com/BeaconBay/ck)

### Zerto Docs MCP (May 2026, production deployment)

A recent production case study combining:
- Chroma vector DB (dense retrieval)
- SQLite FTS5 (BM25, lexical retrieval)
- RRF fusion pipeline
- Cross-encoder reranker
- ~50ms total latency

Architecture:
```
query → embed → Chroma (dense) ──┐
                                  ├── RRF fuse → reranker → top-k
query → tokenize → FTS5 (BM25) ──┘
```

**Key lessons from this deployment**:
- Dense retrieval fails on rare technical tokens (like specific API names) — BM25 handles these
- RRF needs no score calibration (rank-based, not score-based fusion)
- Defensive fallbacks essential at every stage
- MCP tool description language drives LLM retrieval behavior ("call proactively" wording works)

Source: [Justin's IT Blog](https://www.jpaul.me/2026/05/zerto-docs-mcp-part-2-hybrid-search/)

### Obsidian MCP + Hybrid Retrieval (2026 reference implementation)

Single SQLite file (83MB for 49,746-chunk vault) containing:
- FTS5 index on three columns: primary content, section headings, metadata
- sqlite-vec 256-dimensional vectors (minishlab/potion-base-8M, CPU-only, static embeddings)
- RRF fusion: `score(d) = Σ (weight / (k + rank))`
- ~23ms query latency
- Incremental indexing via file modification time
- Token-budget enforcement

**For 183 entries**: This architecture is massively over-engineered. The Obsidian vault with 49K chunks achieves 23ms. A 183-entry literature index with FTS5 alone would be instantaneous.

Source: [Blake Crosley Obsidian Guide](https://blakecrosley.com/guides/obsidian)

---

## Section 3: Zotero Integration Patterns

### cookjohn/zotero-mcp (Native Plugin, Recommended)

The most sophisticated integration:
- Native Zotero-7 plugin with built-in MCP server (no Python, no Node.js)
- Uses Zotero's internal JS API (not the web API) — full write access
- 20 MCP tools including:
  - `search_library`: Boolean operators, yearRange, fulltext, relevanceScoring, annotation search
  - `get_item_metadata`: Complete metadata retrieval by itemKey
  - Full-text search with context snippets
  - Annotation search by color/tags/keywords
  - Collection management and navigation

**Search parameters** exposed via MCP:
- `q`, `title`, `titleOperator`, `yearRange`, `fulltext`, `fulltextMode`
- `itemType`, `includeAttachments`
- `mode` (minimal/preview/standard/complete)
- `relevanceScoring`, `sort`, `limit`, `offset`

This is essentially a complete research library search API exposed as MCP tools. An agent with this MCP server configured could retrieve from Zotero on-demand rather than via preflight injection.

Source: [cookjohn/zotero-mcp GitHub](https://github.com/cookjohn/zotero-mcp), [PulseMCP](https://www.pulsemcp.com/servers/cookjohn-zotero)

### PapersGPT for Zotero (Local RAG)

Fully local RAG pipeline:
- Local embeddings (no internet required)
- Local vector database
- Local reranker
- Local LLMs (Gemma3 1b, Qwen3-1.7B, etc.)
- MCP support (any MCP-compatible client can connect)
- Chat with individual PDFs or entire collections

**Key differentiator**: Everything runs offline. No data leaves the machine. This is the privacy-preserving academic workflow.

Source: [PapersGPT GitHub](https://github.com/papersgpt/papersgpt-for-zotero)

### mcp-for-zotero.com (Remote SSE Endpoint)

The "easiest to set up" option:
- Remote SSE endpoint (not self-hosted)
- Credentials encrypted, not stored on provider servers
- Search by title/author/tag/collection
- Search within indexed PDFs
- Claude Desktop configured via `claude_desktop_config.json`

Trade-off: Requires internet, credentials sent to third-party service. Not suitable for academic privacy requirements.

Source: [Zotero Forums MCP discussion](https://forums.zotero.org/discussion/130133/mcp-for-zotero-connect-your-library-to-claude-chatgpt-and-other-ai-assistants)

### Pattern for this project

Given the project already has a `specs/literature/` directory with markdown-converted papers and an `index.json`, the most natural Zotero integration path would be:
1. Use `cookjohn/zotero-mcp` to expose the Zotero library as MCP tools
2. Update `/literature --search` to query Zotero MCP in addition to the local index
3. Add `/literature --import-zotero KEY` to copy a Zotero paper into `specs/literature/`

This doesn't require replacing the existing system — it adds Zotero as an additional retrieval source.

---

## Section 4: Academic/Research Paper Retrieval Patterns

### The Standard Academic RAG Pipeline (2025-2026)

Research literature review tools now follow a three-stage pipeline:
1. **Query processing**: Accept natural-language question + operational mode (fast/deep) + source selection
2. **Multi-source retrieval**: Parallel queries to multiple backends (Semantic Scholar API, local index, external DBs)
3. **Two-stage re-ranking**: BM25 → dense re-ranking → adaptive evidence synthesis

Key finding from benchmark literature:
- BM25-based methods: R@1 = 0.80
- Semantic baseline alone: R@1 = 0.62 (significant drop)
- Hybrid BM25 + dense: best of both

**For 183 entries**: BM25 alone achieves 0.80 R@1 at academic scale. For a personal collection with carefully crafted keywords in index.json, pure BM25 should reach 0.85+ because the keyword vocabulary is controlled by the same person who indexes.

Source: [Deep Retrieval at CheckThat! 2025](https://arxiv.org/html/2505.23250v1), [Scientific Paper Retrieval paper](https://arxiv.org/pdf/2505.21815)

### LitLLM and Multi-Agent Literature Review

LitLLM toolkit: retrieves relevant papers using Semantic Scholar API (200M+ records), generates summaries, synthesizes findings. The agent pattern is: query → fetch → summarize → synthesize.

Paper Circle (2026): Open-source multi-agent research discovery framework — multiple specialized agents for search, filtering, analysis, synthesis.

**Relevance**: For 183 local files, this level of sophistication is unnecessary. The multi-agent pattern makes sense when querying external databases with millions of papers, not a local collection.

### DeepXiv-SDK Pattern

Accepts: natural-language research question + operational mode (fast/deep) + source-selection criteria. This mirrors exactly what `literature-retrieve.sh` already does — take a task description, extract query terms, select from sources. The difference is sophistication of scoring.

Source: [DeepXiv-SDK](https://arxiv.org/pdf/2603.00084)

---

## Section 5: The "Just Let the Agent Grep" Argument

### The Core Argument

From DEV Community article "Why I Replaced My AI Agent's Vector Database with Grep":

> "At personal scale, the retrieval problem isn't semantic — it's organizational. You don't need to find documents that are 'similar in meaning.' You need to find the document where you wrote down that specific thing."

The author found BM25 keyword matching finds the right document **over 90% of the time** in systems under ~1,000 documents, because:
1. The search query uses identical vocabulary to the original writing
2. The "semantic gap" between query and document is near-zero for personal collections
3. The complete solution requires ~200 lines of TypeScript vs. a separate embedding service

The implementation is simpler, debuggable (human-readable files), auditable (git history), and trustworthy.

### When Grep Wins vs. When It Fails

**Grep/BM25 excels when**:
- < 1,000 documents (definitely the case here: 183 entries)
- Single author who writes and searches their own notes
- Queries use same vocabulary as original content
- Debuggability and transparency matter
- No infrastructure overhead acceptable

**Grep/BM25 fails when**:
- > 10,000 documents (noise accumulates)
- Multi-user distributed systems
- Cross-document conceptual reasoning needed
- Multilingual content
- Users search with different vocabulary than writing

**For 183 entries**: Firmly in the "grep wins" regime.

Source: [DEV Community article](https://dev.to/kuro_agent/why-i-replaced-my-ai-agents-vector-database-with-grep-59mm)

### Benchmark Evidence: arxiv 2605.15184

"Is Grep All You Need? How Agent Harnesses Reshape Agentic Search" (2026):
- Tested across Chronos, Claude Code, Codex CLI, Gemini CLI
- **Grep generally yields higher accuracy than vector retrieval** in comparisons
- Agentic grep: ~68% accuracy
- Vector search: ~60% accuracy
- Agent harness choice matters as much as retrieval method

**Key nuance**: "Both methods are improved by the harness; the choice of harness matters as much as retrieval strategy." This means improving *how* the agent requests and uses retrieved context may matter more than improving the retrieval algorithm.

Source: [arxiv 2605.15184](https://arxiv.org/abs/2605.15184)

### Agentic Search: On-Demand vs. Preflight

From Morph LLM's analysis of agentic search:
- Agentic search: iterative, 3-4 turns, 4-12 parallel tool calls, 2-8 seconds
- Returns `(file, [start_line, end_line])` spans, not whole files
- Runs in separate context window from main coding model
- Slower than pre-computed retrieval but avoids stale indexing and irrelevant content

**Preflight injection** (current `--lit` approach) is faster (0ms overhead at query time) but risks injecting irrelevant content that degrades model attention. Agentic on-demand search is slower but more precise.

**Anthropic's own guidance** (from their Context Engineering blog post):
> "Find the smallest set of high-signal tokens that maximize the likelihood of some desired outcome."

The recommended pattern for long-horizon tasks:
1. Compaction: summarize history, reinitialize with condensed context
2. Structured note-taking: agents maintain NOTES.md files for persistence
3. Sub-agent architectures: specialized agents return distilled summaries

Anthropic explicitly describes "just in time" loading as the preferred pattern over pre-injection.

Source: [Anthropic Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

---

## Recommended Approach

Based on this research, the recommended design for improved literature retrieval has three tiers:

### Tier 1: Enhanced Scoring in Shell (Minimal Change, High Impact)

**Do now**. Improve the existing `literature-retrieve.sh` scoring without adding dependencies:
- Expand keyword extraction: use 15-20 keywords (not current head -10)
- Add TF-IDF-style weighting: title match > keyword match > summary match
- Add position scoring: keywords appearing early in description score higher
- Add n-gram matching: "modal logic" should score higher than individual "modal" + "logic" hits
- Normalize scores by document length (avoid bias toward longer keyword lists)

This fits the "grep wins at <1,000 docs" finding and requires no infrastructure.

### Tier 2: SQLite FTS5 Index (Medium Change, Significant Improvement)

**Do when Tier 1 hits limits**. Build a SQLite database from index.json:
- FTS5 virtual table with Porter stemming
- Weighted columns: title (weight 3) > keywords (weight 2) > summary (weight 1)
- BM25 ranking built-in to FTS5
- Single-file, no dependencies beyond sqlite3 (always available)
- Rebuild from index.json on demand (fast for 183 entries)

This is the architecture used by the Zerto Docs MCP production deployment.

### Tier 3: On-Demand Agent Retrieval via MCP (Future Direction)

**Do when the preflight injection model is abandoned**. Expose `specs/literature/` as an MCP tool the agent can call on-demand:
- MCP tool: `literature_search(query: string) -> chunks[]`
- Agent requests relevant literature during research, not at preflight
- Aligns with Anthropic's "just in time" guidance and Continue.dev's trajectory
- Optionally chain to Zotero via `cookjohn/zotero-mcp` for full library access

---

## Evidence/Examples

| Source | URL | Key Finding |
|--------|-----|-------------|
| DEV Community: Grep vs Vector DB | https://dev.to/kuro_agent/why-i-replaced-my-ai-agents-vector-database-with-grep-59mm | BM25 >90% accuracy at <1K docs |
| arxiv 2605.15184 | https://arxiv.org/abs/2605.15184 | Grep 68% > vector 60% in harness benchmarks |
| Morph LLM: Agentic Search | https://www.morphllm.com/agentic-search | Iterative agent search: spans, not files |
| Anthropic Context Engineering | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | JIT over preflight injection |
| Zerto Docs MCP (May 2026) | https://www.jpaul.me/2026/05/zerto-docs-mcp-part-2-hybrid-search/ | FTS5+Chroma+RRF production architecture |
| Obsidian MCP Hybrid | https://blakecrosley.com/guides/obsidian | 23ms latency, 256-dim vectors, FTS5 |
| BeaconBay/ck | https://github.com/BeaconBay/ck | Rust MCP server: BM25+FastEmbed+RRF |
| sqlite-memory-mcp | https://github.com/RMANOV/sqlite-memory-mcp | FTS5+sqlite-vec+RRF in stdlib |
| cookjohn/zotero-mcp | https://github.com/cookjohn/zotero-mcp | 20-tool Zotero MCP plugin, no external deps |
| PapersGPT | https://github.com/papersgpt/papersgpt-for-zotero | Fully local Zotero RAG |
| PulseMCP RAG server | https://www.pulsemcp.com/servers/sanderkooger-ragdocs | Off-the-shelf MCP RAG server |
| OpenHands Skill Docs | https://docs.openhands.dev/sdk/arch/skill | KeywordTrigger injection pattern |
| Continue.dev @docs deprecated | https://docs.continue.dev/customize/deep-dives/docs | Move to MCP-based on-demand retrieval |

---

## Confidence Assessment

| Finding | Confidence | Basis |
|---------|-----------|-------|
| BM25 beats vector for <1K personal docs | **High** | Multiple sources, empirical benchmarks, logical argument |
| Hybrid FTS5+vector+RRF is production standard | **High** | 3+ independent production deployments verified in 2026 |
| cookjohn/zotero-mcp is the best Zotero integration | **High** | Native plugin, no external deps, 20 tools, full-text search |
| On-demand retrieval preferred over preflight | **Medium-High** | Anthropic guidance + Continue.dev deprecation, but preflight still common |
| arxiv 2605.15184 grep accuracy numbers | **Medium** | Single preprint, not peer-reviewed yet |
| Span-based retrieval better than full-file injection | **Medium** | Logical argument + Morph LLM data, but not tested in this system |

---

## Gaps Not Covered (Teammate A's Territory)

This report does not cover:
- SQLite FTS5 implementation details and jq integration (Teammate A focus)
- Specific scoring formula improvements to existing jq pipeline
- Token budget optimization algorithms
- The `index.json` schema changes needed for better scoring

These are addressed by Teammate A's findings on primary approaches.
