# Teammate A Findings: Semantic Chunking Strategies

**Task**: 721
**Focus**: Chunking strategies and ideal sizes for LLM agent consumption
**Confidence**: high

---

## Key Findings

1. **Structure-first chunking dominates for academic/technical content.** When documents have strong inherent structure (chapters, sections, subsections), cutting along structural boundaries dramatically outperforms fixed-size approaches — 87% vs. 13% accuracy in a controlled clinical study (MDPI Bioengineering, Nov 2025). For converted markdown from PDFs, heading-based splitting is the right primary strategy.

2. **The canonical chunk size sweet spot is 512 tokens with 10–20% overlap.** A February 2026 benchmark of 7 strategies across 50 academic papers ranked recursive 512-token splitting first at 69% accuracy. The 1024-token range produces peak faithfulness on analytical queries (LlamaIndex, 2023), but precision drops. A "context cliff" exists at ~2,500 tokens beyond which quality degrades.

3. **Semantic chunking (embedding-similarity splitting) underperforms for academic content.** A NAACL 2025 Findings paper found fixed 200-word chunks matched or beat semantic chunking. In a Feb 2026 test, semantic chunking produced fragments averaging only 43 tokens — too small for coherent agent consumption, dropping end-to-end accuracy to 54%. Structural splitting is cheaper and more reliable.

4. **Parent-child (small-to-big) retrieval is the production-proven architecture.** Two-tier hierarchy: small child chunks (~128–300 tokens) for precise embedding/retrieval, large parent chunks (~512–1200 tokens) for LLM context delivery. LangChain's `ParentDocumentRetriever` defaults to 100-token children / 500-token parents. LlamaIndex `HierarchicalNodeParser` uses [2048, 512, 128] tiers. Reported 15–30% accuracy gain over single-granularity chunking.

5. **Markdown header splitting is the right tool for converted academic documents.** LangChain's `MarkdownHeaderTextSplitter` splits on `#`, `##`, `###` etc. and stores the full breadcrumb path as metadata. For sections exceeding the target size, a second pass with `RecursiveCharacterTextSplitter` further subdivides using `split_documents()` (not `split_text()`) to preserve per-chunk metadata and prevent overlap from crossing section boundaries.

6. **Mathematical proofs and theorems require preserve-as-unit treatment.** The RAG literature explicitly warns against splitting problem-solution pairs and multi-step proofs ("atomic facts don't exist independently"). Proofs that span multiple paragraphs should be kept in a single chunk even if oversized, or split only at natural proof-step boundaries (after "Proof:", at "QED", between numbered steps). Formal math notation inflates token counts significantly (e.g., TeX → 24 tokens vs. MathML → 201 tokens for the same expression).

7. **Context enrichment (prepending breadcrumb metadata) is the single highest-ROI addition.** Anthropic's contextual retrieval (2024) prepends 50–100 token LLM-generated context snippets situating each chunk within its document before embedding. Results: 49% reduction in retrieval failures with hybrid search, 67% with reranking. The prompt caches the full document, costing ~$1.02 per million document tokens. For non-LLM approaches, prepending the header path (e.g., "Chapter 3 > Section 2.1 > Definitions:") to each chunk embedding achieves much of the same benefit at zero cost.

8. **For ~200 documents, lightweight Python (not heavy frameworks) is appropriate.** Libraries like `mdsplit` (PyPI), LangChain's text splitters standalone, or a custom header-parsing script are sufficient. LlamaIndex/LangChain full stacks are designed for thousands of documents with persistent vector stores — the SQLite FTS5 backend already chosen for this system doesn't need their retrieval infrastructure, only their parsing utilities.

9. **Different content types warrant different chunk sizes.** In the same document corpus:
   - **Prose/narrative** (introductions, discussions): 400–512 tokens
   - **Formal definitions/theorems/lemmas**: keep atomic (50–300 tokens), do not split
   - **Multi-step proofs**: up to 1024 tokens if needed to preserve unit
   - **Code blocks**: split at function/class boundaries regardless of token count
   - **Tables/figures**: treat as single atomic chunks with caption metadata

10. **The TopoChunker framework (March 2026) uses 500-token threshold with per-chunk metadata.** Each chunk stores: semantic signature (3–8 word title), topological path (/Chap1/Sec3), context supplement (resolved anaphora/entity definitions), and verbatim text. This is close to the ideal metadata schema for this system.

---

## Recommended Approach

**Two-pass hierarchical structural splitting with metadata-rich chunks:**

**Pass 1 — Structural split on markdown headings:**
- Split at `#` (chapter), `##` (section), `###` (subsection) boundaries
- Each chunk gets metadata: `{doc_id, title, chapter, section, subsection, chunk_seq, chunk_type}`
- Preserve header text in the chunk body (`strip_headers=False`)
- Keep proof/theorem/lemma blocks atomic even if they exceed size limits

**Pass 2 — Recursive subdivision for oversized chunks:**
- Target size: **512 tokens** (hard cap: 1024 for math-heavy units)
- Overlap: **64 tokens** (12.5%) applied within-section only, never across headings
- Subdivision priority: blank lines between paragraphs → sentence boundaries
- Never split: code blocks, environments marked as `theorem`/`proof`/`lemma`, numbered lists mid-list

**Per-chunk metadata to store:**
- `doc_id`, `chunk_id`, `parent_id` (if subdivided)
- `breadcrumb_path` (e.g., "Chapter 3 / Modal Logic / Completeness Theorem")
- `chunk_type` (prose | definition | theorem | proof | code | table | figure)
- `section_title`, `section_level` (1–4)
- `token_count`, `char_count`
- `position` (chunk index within document, for ordering)

**For FTS5 retrieval:** Index the verbatim text plus breadcrumb path. The breadcrumb path at query time surfaces chunks from the right structural location.

---

## Evidence/Examples

### Two-tier hierarchy from LlamaIndex (cited in Small-to-Big Retrieval):
```python
sub_chunk_sizes = [128, 256, 512]
# Children for retrieval; 1024-token parents for LLM context delivery
```

### LangChain header splitter with secondary recursive split:
```python
headers_to_split_on = [("#", "chapter"), ("##", "section"), ("###", "subsection")]
md_splitter = MarkdownHeaderTextSplitter(headers_to_split_on, strip_headers=False)
header_chunks = md_splitter.split_text(markdown_text)

# Second pass for oversized sections
char_splitter = RecursiveCharacterTextSplitter(chunk_size=2048, chunk_overlap=256)
final_chunks = char_splitter.split_documents(header_chunks)  # preserves metadata
```

### Anthropic contextual retrieval prompt (verbatim):
> "Please give a short succinct context to situate this chunk within the overall document for the purposes of improving search retrieval of the chunk."
> — prepended as 50–100 tokens before embedding, costs ~$1.02/million document tokens with prompt caching

### Accuracy comparison (Feb 2026 benchmark, 50 academic papers):
| Strategy | Accuracy |
|---|---|
| Adaptive / topic-aligned (clinical) | 87% |
| Recursive 512-token | 69% |
| Sentence-based | ~67% (comparable to semantic at lower cost) |
| Semantic chunking (embedding-similarity) | 54% |
| Fixed-size baseline | 13% |

### Content-type chunk size guidance (derived from multiple sources):
| Content type | Target size | Notes |
|---|---|---|
| Prose narrative | 400–512 tokens | Standard recursive split |
| Formal definitions | 50–200 tokens | Keep atomic |
| Theorems + proofs | Up to 1024 tokens | Never split across proof steps |
| Code blocks | Function/class unit | Regardless of token count |
| Tables | Single unit + caption | |
| Section intros | 256–512 tokens | |

---

## Sources

1. [Best Chunking Strategies for RAG (and LLMs) in 2026 — Firecrawl](https://www.firecrawl.dev/blog/best-chunking-strategies-rag)
2. [Chunking Strategies for RAG Pipeline Performance — Weaviate](https://weaviate.io/blog/chunking-strategies-for-rag)
3. [RAG Chunking Strategies: A 2026 Retrieval Playbook — Digital Applied](https://www.digitalapplied.com/blog/rag-chunking-strategies-2026-retrieval-quality-playbook)
4. [The Complete Guide to Document Chunking for RAG — Medium (Kaustav Mukherjee, Apr 2026)](https://kaustavmukherjee-66179.medium.com/the-complete-guide-to-document-chunking-for-rag-ac312e6d635f)
5. [Advanced RAG 01: Small-to-Big Retrieval — Medium (Sophia Yang)](https://medium.com/data-science/advanced-rag-01-small-to-big-retrieval-172181b396d4)
6. [MarkdownHeaderTextSplitter — LangChain Docs](https://docs.langchain.com/oss/python/integrations/splitters/markdown_header_metadata_splitter)
7. [TopoChunker: Topology-Aware Agentic Document Chunking Framework — arXiv 2603.18409 (2026)](https://arxiv.org/html/2603.18409)
8. [From RAG to Context — 2025 Year-End Review — RAGFlow](https://ragflow.io/blog/rag-review-2025-from-rag-to-context)
9. [Anthropic Introduces Contextual Retrieval — CO/AI](https://getcoai.com/news/anthropic-introduces-contextual-retrieval-to-boost-accuracy-of-rag-systems/)
10. [RAG Chunking Strategies & Embeddings Optimization: 2026 Benchmark Guide — Substack](https://nandigamharikrishna.substack.com/p/rag-chunking-strategies-and-embeddings)
11. [LEMMAHEAD: RAG Assisted Proof Generation — arXiv 2501.15797](https://arxiv.org/pdf/2501.15797)
12. [mdsplit — PyPI](https://pypi.org/project/mdsplit/0.3.1/)
13. [Implementing Anthropic's Contextual Retrieval — Instructor / Python](https://python.useinstructor.com/blog/2024/09/26/implementing-anthropics-contextual-retrieval-with-async-processing/)
