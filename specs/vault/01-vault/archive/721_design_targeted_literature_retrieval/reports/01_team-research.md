# Research Report: Task #721 — Targeted Literature Retrieval Design

**Task**: 721 - Design targeted literature retrieval to replace bulk injection
**Date**: 2026-06-15
**Mode**: Team Research (4 teammates)

## Summary

Four research teammates independently converged on a clear diagnosis: **the fundamental problem is architectural, not algorithmic**. With an 8,000-token budget and entries averaging 7,164 tokens, even perfect scoring yields only 1-2 entries per invocation. Improving keyword overlap to BM25 changes *which* entry fills slot 1, but slot 1 is nearly all you get. The industry has moved toward on-demand agent retrieval over preflight injection — Anthropic's own guidance favors JIT loading, and Continue.dev deprecated its bulk injection provider in favor of MCP-based on-demand retrieval.

The recommended path is a **tiered architecture** that separates `--lit` (preflight injection, improved) from `/cite` (on-demand search via zotero-search.sh), with three implementation phases of increasing sophistication.

## Key Findings

### 1. The Geometry Problem (Unanimous)

The current corpus has 183 entries totaling ~1.3M tokens. 36 entries individually exceed the 8,000-token budget. The median entry is ~3,500-4,000 tokens. At most 1-2 entries can be injected per invocation. **Better scoring narrows which entry appears in slot 1 but doesn't change that slot 1 is all you get.**

### 2. Preflight Injection Is the Wrong Model (Teammates C, D; supported by A, B)

Evidence from multiple 2025-2026 sources:
- **"Lost in the middle" effect**: LLMs systematically ignore information in the middle of long contexts (Liu et al. 2023)
- **JetBrains NeurIPS 2025**: 25% of tokens preserved 95% of accuracy vs. full injection
- **Rango paper (ICSE 2025)**: Step-by-step adaptive retrieval outperformed static injection by 47%
- **Anthropic**: "Find the smallest set of high-signal tokens that maximize the likelihood of some desired outcome" — JIT loading recommended over preflight injection
- **Continue.dev**: Deprecated `@docs` provider in favor of MCP-based on-demand retrieval

### 3. Keyword Search Fails for Formal Verification (Teammate C)

LeanSearch v2 (arxiv 2605.13137) documents the exact failure mode: proving irreducibility of (x^p-1)/(x-1) requires lemmas about "cyclotomic polynomials" and "geometric sums" — zero vocabulary overlap with the problem statement. This is structurally identical to the Literature/ use case: a task about "bimodal frame definability" needs the Sahlqvist correspondence paper, but neither "Sahlqvist" nor "correspondence" appears in the task description.

### 4. BM25 Wins at This Scale (Teammates A, B)

For <1,000 documents with a single author's vocabulary:
- BM25 finds the right document >90% of the time (DEV Community benchmark)
- Agentic grep (68%) beats vector search (60%) in harness benchmarks (arxiv 2605.15184)
- BM25 R@1 = 0.80 vs. semantic baseline R@1 = 0.62 (academic retrieval benchmarks)

### 5. Zotero Metadata Is the Untapped Resource (Teammate D)

`zotero-library.json` has 878 entries with title, abstract, keywords, authors — richer metadata than Literature/index.json's keywords[] and summary fields. The existing `zotero-search.sh` already scores on title (+3), keyword (+2), abstract (+1), author (+1). The minimal viable improvement is bridging zotero-search.sh's output to Literature/ index file paths — ~20 lines of bash.

### 6. SQLite FTS5 Is the Standard Backend (Teammate A)

SQLite FTS5 with BM25 provides:
- True IDF/TF weighting (rare terms score higher)
- Column-weighted scoring (title > keywords > summary > content)
- Full-content search (not just metadata)
- Phrase and boolean queries
- Zero new dependencies (sqlite3 is pre-installed everywhere)
- .db file gitignored, rebuilt in <1s for 183 docs

### 7. MCP-Based Literature Search Is Mature (Teammate B)

- `cookjohn/zotero-mcp`: Native Zotero-7 plugin with 20 MCP tools, Boolean full-text search, relevance scoring — no Python/Node required
- Multiple production hybrid search MCP servers exist (SQLite FTS5 + sqlite-vec + RRF)
- Obsidian MCP achieves 23ms latency on a 49,746-chunk vault

### 8. --lit and /cite Need Different Models (Teammate D)

- `--lit`: Push model (inject before agent starts) — improved scoring is still valuable here
- `/cite`: Pull model (agent queries for specific claims on demand) — zotero-search.sh already implements this
- These are different enough to warrant separate tools, not a unified architecture

## Synthesis

### Conflicts Resolved

| Conflict | Resolution |
|----------|------------|
| **SQLite FTS5 now vs. defer to 500+ entries** (A vs. D) | Zotero bridge first (leverages existing infrastructure, ~20 lines); FTS5 when Zotero metadata is insufficient or corpus exceeds 500 entries |
| **Enhanced jq vs. Zotero bridge** (A vs. D) | Zotero bridge wins — accesses abstract fields not in index.json, uses existing zotero-search.sh scoring which is already richer than any jq enhancement |
| **Vector/embedding search** (all teammates) | Unanimously rejected at current scale: heavy Python dependencies, embedding drift maintenance, overkill for 183 entries with domain-specific vocabulary |
| **Replace preflight with on-demand** (C) vs. **Improve preflight** (D) | Both: improve --lit short-term (Zotero bridge), but recognize the industry direction is toward on-demand retrieval; /cite already uses the on-demand model |

### Gaps Identified

1. **When should --lit inject nothing?** A MIN_SCORE=1 threshold means one keyword match triggers injection. A "neovim" task with "modal" in its description will match modal logic papers. Needs task-type-aware filtering.
2. **Chapter-level vs. paper-level retrieval**: The current system retrieves whole entries, but formal verification often needs specific sections. Span-based retrieval would be more token-efficient.
3. **Utilization vs. retrieval bottleneck**: Research shows 54-89% of agent failures are utilization failures (right content retrieved, poorly used), not retrieval failures. Better scoring may not fix the observed problem.
4. **Token-efficiency in scoring**: A 365K-token book scoring 3 on keywords ranks above a 5K-token paper scoring 2, but the book can never be injected. Token-efficiency must be a scoring signal.
5. **Abstract field migration**: Literature/index.json lacks abstracts; Zotero has them. A one-time migration would make improved scoring available without Zotero at retrieval time.

## Recommendations

### Tier 0: Zotero Bridge (Immediate, ~20 lines)

Modify `literature-retrieve.sh` to use `zotero-search.sh` for scoring when `ZOTERO_LIBRARY` is available:
1. Extract keywords from task description (existing logic)
2. Call `zotero-search.sh <keywords> --limit=20 --format=json`
3. Cross-reference returned bib_keys with Literature/index.json for file paths
4. Inject matched files within token budget
5. Fall back to current keyword scoring when Zotero library absent

**Cost**: ~2 hours. **Impact**: Significant — leverages abstract+title+keyword scoring from 878-entry Zotero library.

### Tier 1: Abstract Migration + Scoring Enhancement (Near-term)

1. Add `abstract` field to Literature/index.json entries (one-time migration from zotero-library.json via bib_key cross-reference)
2. Update scoring to weight: title (+3), abstract (+2), keywords (+2), summary (+1)
3. Add token-efficiency signal: penalize entries exceeding budget, boost entries fitting in budget
4. Add task-type filtering: suppress injection for task types unlikely to need literature
5. Add `--project SLUG` filter using existing `project_tags` field

**Cost**: ~4-6 hours. **Impact**: Makes improved scoring work without Zotero library at retrieval time.

### Tier 2: SQLite FTS5 Ephemeral Cache (500+ entries)

Build gitignored SQLite database from index.json with FTS5 virtual table:
- Column weights: title (5x), keywords (3x), abstract (2x), summary (1x), content (1x)
- BM25 ranking built-in
- Rebuild when index.json modification time > .db modification time
- Full-content search across converted markdown files

**Cost**: ~8-12 hours. **Trigger**: Corpus growth past 500 entries or Tier 1 scoring proving insufficient.

### Tier 3: Agent-Callable On-Demand Retrieval (Future)

Replace preflight injection with MCP tool or bash tool the agent calls on demand:
- `literature_search(query)` returns ranked entries with snippets
- Agent decides when and what to retrieve based on task context
- Compatible with cookjohn/zotero-mcp for full library access
- Aligns with Anthropic's JIT loading recommendation

**Cost**: Significant architectural change. **Trigger**: When preflight injection model is formally abandoned.

### Separate Track: /cite Uses zotero-search.sh Directly

Tasks 716-720 are independent of task 721. The /cite command uses on-demand search via zotero-search.sh, not preflight injection. No changes needed to literature-retrieve.sh for /cite.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | Primary approaches | completed | high | SQLite FTS5 deep dive, 5-approach comparison with 2026 web research |
| B | Prior art & alternatives | completed | high | MCP ecosystem survey, zotero-mcp discovery, "grep wins" benchmark |
| C | Critic | completed | high | Architecture diagnosis, keyword failure for formal verification, 5 missing questions |
| D | Horizons | completed | high | Geometry problem quantification, Zotero bridge design, --lit vs /cite bifurcation |

## References

**Architecture & Agent Retrieval**:
- [Anthropic: Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — JIT loading over preflight injection
- [JetBrains NeurIPS 2025: Efficient Context Management](https://blog.jetbrains.com/research/2025/12/efficient-context-management/) — 25% tokens = 95% accuracy
- [Rango: Adaptive Retrieval-Augmented Proving (ICSE 2025)](https://arxiv.org/html/2412.14063) — adaptive > static by 47%
- [Is Grep All You Need? (arxiv 2605.15184)](https://arxiv.org/abs/2605.15184) — grep 68% > vector 60%

**SQLite FTS5**:
- [SQLite FTS5 Official Docs](https://sqlite.org/fts5.html)
- [memweave: Zero-Infra AI Agent Memory](https://towardsdatascience.com/memweave-zero-infra-ai-agent-memory-with-markdown-and-sqlite-no-vector-database-required/)

**MCP & Zotero**:
- [cookjohn/zotero-mcp](https://github.com/cookjohn/zotero-mcp) — 20-tool native Zotero MCP plugin
- [PapersGPT for Zotero](https://github.com/papersgpt/papersgpt-for-zotero) — fully local RAG
- [sqlite-memory-mcp](https://github.com/RMANOV/sqlite-memory-mcp) — FTS5+sqlite-vec+RRF

**Formal Verification Retrieval**:
- [LeanSearch v2 (arxiv 2605.13137)](https://arxiv.org/abs/2605.13137) — keyword failure in formal verification
- [Embeddings Aren't Magic](https://towardsdatascience.com/embeddings-arent-magic-the-predictable-failure-modes-of-rag-retrieval-enterprise-document-intelligence-vol-1-2/) — structural RAG failures
