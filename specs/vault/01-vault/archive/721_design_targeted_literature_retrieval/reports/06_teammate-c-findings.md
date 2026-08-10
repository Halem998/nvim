# Teammate C Findings: Critical Analysis

**Task**: 721
**Focus**: Gaps, blind spots, failure modes, overlooked simplifications
**Confidence**: high (most concerns backed by external evidence or derivable from the design spec)

---

## Key Findings

### 1. The Source Material Is Already Lossy — Before Any Chunking Happens

The design assumes markdown conversion of academic PDFs is reliable enough to split semantically. It is not.

Pandoc converts two-column academic layouts into "an unreadable garble" by mashing column text together [Source 5]. Mathematical equations are not converted 100% of the time — Nougat (academic OCR model) and even paid tools like Mathpix fail on complex LaTeX environments [Source 5]. Tables with merged cells or intricate layouts fall apart. The corpus is ~200 modal logic and formal verification papers — a domain with heavy two-column layouts, nested proof environments, commutative diagrams, and custom LaTeX macros.

**Implication**: Markdown "headers" in a poorly-converted PDF do not correspond to actual section boundaries. A chunk that begins with `## Theorem 3.4` may actually contain the end of Section 3.3 mashed together with the beginning of Section 3.4 because the column layout was misread. Recursive splitting at these headers creates silently-wrong chunks that pass no automated quality check.

**Unvalidated assumption**: The design never specifies the conversion tool or validates conversion quality. If `~/Projects/Literature/` was populated with Pandoc without quality review, the markdown layer itself may be substantially corrupted for a non-trivial fraction of the 183 entries.

---

### 2. Logical Joints in Academic Math Don't Align with Markdown Headers

The design's Phase 1 ingestion calls for "recursive splitting at logical joints (chapters → sections → subsections)." In academic mathematics, this is often the wrong boundary.

The actual atomic units of formal verification papers are not sections — they are definitions, lemmas, theorems, proofs, and remarks. A section can contain a theorem that references a definition three subsections earlier, followed by a remark that references a lemma in the next section. Splitting at the section header boundary separates the theorem from its proof (often continued below a subheading) and from its dependencies (scattered throughout the document).

For the specific corpus (modal logic, formal verification, philosophy):
- **Proofs are not self-contained at section boundaries.** A proof in Section 4.2 typically establishes notation defined in Section 2.1 and applies a lemma from Section 3.3. No chunk boundary captures this.
- **Definitions migrate.** Papers in this domain often restate a definition slightly differently in each chapter (for the reader's convenience), meaning the "definitive" definition and the one actually cited in proofs may differ subtly across chunks.
- **Numbered environments are the real structure.** The semantic structure is: Definition 2.1 → Lemma 3.4 → Theorem 4.2 → Proof. This is orthogonal to the header hierarchy.

**Implication**: A chunk of "Section 4.2" without the definitions from Section 2.1 is semantically incomplete. An agent reading that chunk cannot verify a proof step because the chunk doesn't contain the definitions it references. The chunk looks complete (it spans a section heading to the next) but is semantically broken.

---

### 3. Cross-References Are the Primary Access Pattern — The Design Has No Answer

Academic papers are intensely cross-referential. A typical proof in this corpus contains: "By Definition 3.1 and Lemma 4.2 (proved in Section 5), we have..." with references backward and forward across sections, and sometimes to other papers in the corpus ("By the duality theorem of Blackburn et al. [2], see also [7]").

The proposed design stores parent/child/sibling relations between chunks based on their position in the document hierarchy. But this is not how content is actually referenced:

- A proof in Chapter 7 references a definition in Chapter 2 — these are not siblings, parents, or children of each other.
- A theorem in Paper A references a result in Paper B — these are in completely separate documents.
- An agent encountering "by Lemma 4.2" in a chunk must know: (a) which Lemma 4.2 (some papers have more than one in different namespaces), and (b) how to navigate to it given only the chunk currently in context.

The proposed relation graph (parent, children, siblings) only enables vertical navigation within the document hierarchy. It provides no mechanism for following a named cross-reference to an arbitrary chunk in the same or different document.

**The design as written answers the question "what comes before and after this chunk?" but not "where is Lemma 4.2 referenced in this chunk?"** For formal verification work, the second question is the one that actually matters.

---

### 4. BM25 Vocabulary Mismatch Is Worse Than Acknowledged — Even With Porter Stemming

The design correctly identifies cross-vocabulary failure as a problem and uses Porter stemming to address it. But Porter stemming is a morphological fix, not a semantic one, and the failure mode in this corpus is semantic.

Research shows that on average, 80% of experts in the same field will name the same concept differently [Source 7]. For formal logic and philosophy:
- "Frame completeness" and "canonical model theorem" refer to the same result in different expositions
- "Normal modal logic" and "Kripke semantics" are deeply related but share no stemmed terms
- "Definability" and "expressibility" and "characterization" describe the same mathematical relationship using different vocabulary traditions

Porter stemming helps "definability" match "definable" but cannot help "completeness" match "canonicity" or "correspondence" match "preservation". The design's own Round 1 documents a concrete failure case: "bimodal frame definability" needs Sahlqvist, with zero keyword overlap. Porter stemming does not fix this.

**The design mitigates vocabulary mismatch at the level of inflections (morphological variation) but leaves semantic variation (same concept, different word) entirely unaddressed.** For a philosophical/formal verification corpus where authors actively choose different terminological traditions, this is the dominant failure mode, not the edge case.

---

### 5. The Agent Writes Unparameterized FTS5 Queries Through Bash — This Is Fragile

The design instructs agents to call `literature-search.sh "query terms"` with arbitrary query strings. The query is then interpolated into a bash command that calls `sqlite3`. The design's own "Open Questions for Planning" item 4 acknowledges this:

> "If the query contains single quotes or SQL injection characters, the bash command could fail or behave unexpectedly."

This is flagged as a planning decision to resolve, but the severity is undersold. An FTS5 MATCH query has its own syntax distinct from SQL (parentheses, AND, OR, NOT, quotes for phrases). An agent-written query like `"frame (completeness OR definability)"` or `"author's"` (with a possessive) will cause the bash interpolation to fail with a cryptic sqlite3 error. LLMs writing FTS5 queries will produce syntactically incorrect queries at a non-trivial rate, causing silent failures where the agent receives an error and simply concludes "no results found."

More subtly: FTS5 MATCH parsing is strict. `literature-search.sh "NOT completeness"` returns a syntax error because FTS5 does not support leading NOT. The agent has no way to know this without documentation or error feedback.

**Implication**: A fragile query interface causes silent retrieval failures. The agent will move on assuming no relevant literature exists, when in fact the query was malformed.

---

### 6. Token Overhead of the TOC/Metadata Layer Is Not Calculated

The design proposes that "Agent has access to a table of contents — hierarchy of chunks with metadata only." The existing design never computes what this TOC costs in tokens.

A rough estimate: 183 entries × (id + title + authors + year + doc_type + token_count + path + keywords) ≈ 50-150 tokens per entry. That's 9,000-27,000 tokens just for the metadata catalog, before any content is read.

If chunks are added (the design considers chapter-level entries under books), the count grows. A book with 20 chapters and 100 subsections contributes ~120 hierarchical entries. With 10 such books in the corpus, the flat TOC grows to 1,000+ entries and potentially 50,000-150,000 tokens.

The design never addresses:
- Is the TOC injected into the agent context upfront? (If yes: huge token cost)
- Is it queried via search? (If yes: this is the search tool, not a TOC)
- Is it browsed incrementally? (If yes: what's the mechanism?)

The FTS5 search tool (literature-search.sh) IS effectively the TOC — it returns metadata without content. The design conflates two concepts (TOC as static catalog, search as dynamic query) without resolving the tension. At current scale (183 entries), a single `literature-search.sh "modal logic" --limit 183` dumps the full catalog. That may be acceptable. But it was never explicitly verified.

---

### 7. Index Staleness Has No Defined SLA or Detection Mechanism Beyond mtime Check

The design's staleness detection is a single timestamp comparison: if `index.json` is newer than `.literature.db`, rebuild. This is correct for the common case. But it misses several real-world scenarios:

- **Partial writes**: If `literature-build-index.sh` fails mid-run (disk full, permission error, interrupted), it leaves a partial `.db` that is newer than `index.json`. The mtime check marks it as fresh. All subsequent queries against a corrupt database return garbage or errors.
- **In-place `index.json` updates**: If the file is modified but its mtime is not updated (e.g., an editor that writes to a temp file and renames, but sets the mtime to the original), the staleness check silently misses it.
- **Two-tier divergence**: If `specs/literature/index.json` is updated but `~/Projects/Literature/index.json` is not (or vice versa), the two-tier merge produces incorrect results because one tier's `.db` is stale relative to the other.

The design's "atomic rebuild" claim (always removes stale `.db` before rebuilding) only protects against interruption if `literature-build-index.sh` deletes the old `.db` as its first step. The current description says "always removes the stale `.db` before rebuilding" — this is correct as specified. But it requires the script to atomically delete-then-write. If the rebuild itself fails after deletion, the caller receives no results (missing `.db`) instead of stale results. Neither failure mode is documented for the agent.

---

### 8. The Simpler Alternative Was Not Evaluated: Just Cat the Index

Before building a SQLite FTS5 pipeline, the design should validate that the complexity is justified. The existing `index.json` is ~183 entries. A minimal agent-callable alternative:

```bash
# Option A: jq-based search (zero new infrastructure)
jq -r '.entries[] | select(.keywords[] | test("'$QUERY'"; "i")) | 
  "\(.id)\t\(.title)\t\(.path)"' ~/Projects/Literature/index.json
```

```bash
# Option B: Dump entire index.json (50-100KB) into agent context
cat ~/Projects/Literature/index.json | jq '.entries[] | {id, title, keywords, summary, path}'
```

At 183 entries with ~50-150 tokens of metadata each, the full metadata dump is 9,000-27,000 tokens — within a single-call context for current models. The agent could then reason over the full catalog directly, with no search tool overhead, no query syntax to learn, and no infrastructure to maintain.

The design jumps from "keyword overlap scoring is broken" to "SQLite FTS5 with BM25" without evaluating whether "give the agent the full index" is sufficient. For a 183-entry corpus, this may be 80% of the benefit at 10% of the complexity.

**This is the most important overlooked simplification.** The design should explicitly evaluate and reject it before committing to FTS5.

---

### 9. Chunk Quality Has No Evaluation Metric

The design describes splitting, chunking, and indexing, but never defines what a "good chunk" is or how to measure it. This matters because chunk quality is the primary determinant of retrieval quality [Source 1].

Known metrics for chunk quality that the design ignores:
- **HOPE metric** (A New HOPE, ACL 2025): Measures chunk coherence and boundary quality
- **Context preservation**: Does the chunk contain the context needed to understand its claims?
- **Self-containedness**: Can the chunk be understood without its parent section?
- **Cross-reference completeness**: Does the chunk include definitions it depends on?

For the specific content type (proofs, theorems, definitions), none of these are easy to compute automatically. But the design never acknowledges they exist, which means there's no way to evaluate whether the chunking strategy produces usable chunks before committing to an implementation.

---

### 10. The "Agent Decides When to Stop" Assumption May Not Hold Under Token Pressure

The design's agent integration assumes: "Agent formulates queries based on the task, browses ranked results, reads specific files as needed, and decides what is relevant and when to stop."

This is correct when the agent has a large token budget. But in practice, agents under context pressure (long task history, large plan files, multiple prior searches) will satisfice rather than search thoroughly. An agent 70% through its context window will stop searching after 1-2 queries even if relevant literature exists.

The design provides no guidance on:
- When should the agent search literature vs. proceed without?
- How many searches is "enough"?
- What signal indicates "the relevant chunk is not in the corpus"?

These are agent behavior questions, not infrastructure questions. But the design's correctness depends on agents behaving in a particular way that the infrastructure cannot enforce.

---

## Recommended Mitigations

**For Finding 1 (Lossy source material)**:
Before building any chunking infrastructure, audit a sample of the markdown files in `~/Projects/Literature/`. Pick 5 PDFs known to have complex layouts (two-column, heavy math) and verify that their markdown representations are correct. If significant corruption is found, the chunking task should be preceded by a conversion quality improvement task.

**For Finding 2 (Wrong boundary semantics)**:
Consider numbering-aware chunking: extract LaTeX-style numbered environments (Definition, Lemma, Theorem, Proof, Remark) as first-class chunks rather than splitting at headers. Headers become the navigation structure; numbered environments become the retrievable units. This aligns with how formal verification papers are actually read and cited.

**For Finding 3 (Cross-references)**:
At minimum, store a `cross_refs` field in each chunk's metadata that lists all named references within it (e.g., "Definition 2.1", "Lemma 3.4", "[Blackburn 2001]"). This doesn't resolve them, but it enables an agent to search for `cross_refs CONTAINS "Definition 2.1"` to find all chunks that mention that definition, then retrieve the definition chunk separately. FTS5 can support this with a dedicated column.

**For Finding 4 (Vocabulary mismatch)**:
Accept that BM25 is a keyword search tool, not a concept search tool. The mitigation is: enrich metadata aggressively before indexing. Pull abstracts from Zotero (the `zotero_key` field enables this). Manually add concept synonyms to the `keywords` field in `index.json` for the most important works. This is curation work, not infrastructure work, and is more effective at this corpus size than adding vector search.

**For Finding 5 (Fragile FTS5 queries)**:
Implement query sanitization in `literature-search.sh`: escape single quotes (replace `'` with `''`), detect and reject leading NOT operators, wrap the query in FTS5 double-quote phrase syntax if it looks like a phrase. Return a structured error (not a sqlite3 crash) if the query fails, with a suggestion to simplify the query. Log the raw query and error for debugging.

**For Finding 6 (TOC token overhead)**:
Explicitly benchmark: call `literature-search.sh "" --limit 200` (or equivalent full-catalog dump) and measure the token count of the output. Document this number. If it's under 4,000 tokens, the agent can safely retrieve the full catalog on first use. If it's over 20,000 tokens, a hierarchical browse strategy is needed. The design must make this decision explicit.

**For Finding 7 (Index staleness)**:
Add a checksum-based staleness check alongside the mtime check: store the MD5 or SHA-256 of `index.json` in a `.literature.db.stamp` file at build time; compare at query time. Protect against partial writes by building to `.literature.db.tmp` and atomically renaming to `.literature.db` only on successful completion. The Obsidian Index Service uses this SHA-256 change detection pattern [Source 10 in design synthesis].

**For Finding 8 (Simpler alternative)**:
Add an explicit evaluation step before implementation: run a test where an agent receives the full `index.json` (flattened to a list of {id, title, keywords, summary, path} objects) as context and must answer 5 research questions. Compare answer quality against the FTS5 approach. If the simpler approach works, use it.

**For Finding 9 (No quality metric)**:
Define a minimal acceptance test for chunking quality: pick 10 representative theorem statements and manually verify that each theorem + its proof can be recovered from the chunks that contain them (possibly requiring retrieval of multiple chunks via navigation). If this test cannot be constructed, the chunking strategy needs redesign.

**For Finding 10 (Agent stopping behavior)**:
Add guidance to the `<literature-tool>` prompt: "If you do not find relevant literature within 3 searches, proceed without it and note in your output that literature was searched but not found." This bounded-search contract prevents both over-searching (burning context) and under-searching (one query and give up).

---

## Evidence/Examples

### Cross-reference failure (Finding 3)

In Blackburn, de Rijke, and Venema's *Modal Logic* (a likely corpus member), Chapter 4 "Completeness" depends on the filtration construction introduced in Chapter 3 and the truth lemma from Chapter 2. A chunk for Chapter 4 is semantically incomplete without Chapters 2 and 3. No parent/child/sibling relation in the proposed design connects Chapter 4 to the specific theorem in Chapter 2 it depends on. An agent reading the Chapter 4 chunk will encounter "by the Truth Lemma (2.71)" and have no way to resolve it except to guess or issue another search.

### Vocabulary mismatch surviving Porter stemming (Finding 4)

Query: "canonical model completeness" — intended to find results about canonical frame construction.  
Relevant paper title: "On the Decidability of the Satisfiability Problem for Normal Modal Logics."  
Relevant keywords in index: "decidability, satisfiability, filtration, small model property."  
Stemmed overlap between query and keywords: zero terms. Porter stemming maps "completeness" → "complet" and "canonical" → "canon". Neither stem appears in "decidability, satisfiability, filtration, small model property." BM25 score: 0.

### Chunk boundary failure for proofs (Finding 2)

Standard academic structure:
```
## Section 4.2: The Löb Formula
Let us recall the operator □, defined in Section 2.1. [reference]
**Theorem 4.7** (Löb's theorem): □(□A → A) → □A.
*Proof.* By induction on the complexity of A, using Lemma 3.4... □
**Remark 4.3**: The above theorem fails in K...
```
A chunk at the section boundary contains Theorem 4.7 and its proof but lacks the definition of □ (Section 2.1) and Lemma 3.4 (Section 3). An agent encountering this chunk cannot verify the proof. The design's parent/child navigation would retrieve "Section 2" (100+ pages) not "Definition 2.1 (the box operator)."

### FTS5 query syntax failure (Finding 5)

Agent query (natural language): `"Sahlqvist's correspondence result"`  
Interpolated bash: `sqlite3 .literature.db "SELECT ... WHERE literature_fts MATCH 'Sahlqvist''s correspondence result'"`  
Result: sqlite3 syntax error — the apostrophe in `Sahlqvist's` terminates the SQL string. The script exits non-zero. The agent receives no results and no explanation.

---

## Overlooked Simplifications

**The 80/20 option: Full index dump as context**

For 183 entries × 100 tokens/entry = 18,300 tokens, a complete metadata dump fits in one agent call for modern models with 100K+ context. This is simpler, requires no new scripts, needs no FTS5 schema, and lets the agent reason over the complete catalog directly. It should be explicitly tested and rejected before committing to the FTS5 pipeline.

**Bounded agent search instead of open-ended**

The `<literature-tool>` instructions currently say "search when you need to" with no bounds. A 3-query limit with explicit fallback is simpler and more predictable than hoping agents stop at the right time.

**Metadata enrichment instead of chunking**

Rather than splitting existing documents into chunks, the simpler intervention is enriching `index.json` with better metadata (Zotero abstracts, concept synonyms, numbered environment inventory). At 183 entries, manual curation of the 20 most-cited works is feasible and directly addresses the vocabulary mismatch problem without any new infrastructure.

---

## Sources

1. [Your Chunks Failed Your RAG in Production — Towards Data Science](https://towardsdatascience.com/your-chunks-failed-your-rag-in-production/)
2. [Seven Failure Points When Engineering a RAG System — Barnett et al. 2024 (arXiv:2401.05856)](https://arxiv.org/abs/2401.05856)
3. [Common Failure Patterns in RAG Systems — Medium](https://medium.com/@ishii_24878/common-failure-patterns-in-rag-systems-and-how-to-fix-them-5d880977a785)
4. [Chunking Strategies for RAG: Methods, Trade-offs & Best Practices — Atlan](https://atlan.com/know/chunking-strategies-rag/)
5. [Academic PDF to Markdown Conversion — blazedocs.io](https://blazedocs.io/blog/academic-pdf-to-markdown-guide)
6. [Accelerating End-to-End PDF to Markdown Conversion (arXiv:2512.18122)](https://arxiv.org/html/2512.18122v1)
7. [Vocabulary Mismatch — Wikipedia](https://en.wikipedia.org/wiki/Vocabulary_mismatch)
8. [SQLite FTS5 Extension — Official Documentation](https://sqlite.org/fts5.html)
9. [Beyond FTS5: Building Transactional Full-Text Search — Turso](https://turso.tech/blog/beyond-fts5)
10. [Hybrid Full-Text Search and Vector Search with SQLite — Alex Garcia](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html)
11. [Contextual Retrieval — Together AI docs](https://docs.together.ai/docs/how-to-implement-contextual-rag-from-anthropic)
12. [A New HOPE: Domain-agnostic Automatic Evaluation of Text Chunking (arXiv:2505.02171)](https://arxiv.org/pdf/2505.02171)
13. [AutoChunker: Structured Text Chunking and its Evaluation (ACL 2025)](https://aclanthology.org/2025.acl-industry.69.pdf)
14. [Breaking Up Is Hard to Do: Chunking in RAG Applications — Stack Overflow Blog](https://stackoverflow.blog/2024/12/27/breaking-up-is-hard-to-do-chunking-in-rag-applications/)
15. [Real-Time Data Synchronization for RAG — Droptica](https://www.droptica.com/blog/real-time-data-synchronization-rag-how-keep-your-ai-chatbots-knowledge-fresh/)
