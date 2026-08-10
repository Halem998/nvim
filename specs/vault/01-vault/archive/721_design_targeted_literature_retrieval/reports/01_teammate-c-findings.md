# Teammate C Findings: Critic Report
## Task 721 — Design Targeted Literature Retrieval

**Role**: Critic — Gaps, Blind Spots, Wrong Assumptions
**Date**: 2026-06-14

---

## Key Findings Summary

The proposed targeted retrieval system addresses a real symptom (poor scoring quality) but
may be treating the wrong root cause. The deeper problem is architectural: the entire
preflight-injection model is at odds with how LLMs actually process context, and how formal
verification practitioners actually use literature. Fixing the scoring algorithm without
questioning this architecture risks building a more sophisticated version of something that
still fundamentally does not work.

---

## 1. Is This Even the Right Problem?

### Finding: Preflight Injection Is Architecturally Wrong for This Use Case

**Claim being evaluated**: The current --lit flag "might even be worse" than no injection.
The proposed solution is better scoring.

**Evidence that the architecture is the problem, not just the scoring**:

The "Lost in the Middle" effect (documented in multiple peer-reviewed studies, including
Liu et al. 2023) shows that LLMs systematically fail to retrieve information from the
middle of long contexts. Attention is biased toward the beginning and end of prompts.
This means that even a perfectly scored literature injection that places the right paper
into context will likely be ignored if it lands in the middle of an 8,000-token injection
block.

Research from JetBrains (NeurIPS 2025) on AI coding agents explicitly found that "as
the context grows, language models often struggle to make good use of all the information"
provided, and that agent-generated context "quickly turns into noise instead of being
useful information." Their finding: 25% of tokens preserved 95% of accuracy relative to
full injection. This is not a scoring problem — it is a context-volume problem.

The coding agent research community (SWE-bench practitioners, tools like Cline and
Continue.dev) has largely converged on agentic on-demand retrieval over preflight
injection for exactly this reason. One widely-cited practitioner view describes RAG as a
"massive distraction" for coding agents because it "fragments context into disconnected
snippets, undermining the LLM's reasoning abilities."

**What this means for Task 721**: The proposed "targeted retrieval" redesign is framed as
improving scoring quality within the preflight injection model. But the JetBrains finding
suggests the right question is: should the injection happen at preflight at all, or should
literature be available as an on-demand tool call during agent execution?

**Confidence**: High. Multiple independent sources converge on this finding.

---

## 2. Scale Assumptions

### Finding: The 183-Entry Corpus is Already Large Enough to Matter; Growth Will Be Non-Linear

**Claim being evaluated**: "SQLite at 500-1000 entries" — the assumption that the corpus
is small now and scaling matters only in the future.

**Evidence on current scale**:

The actual corpus at `/home/benjamin/Projects/Literature/index.json` has 183 entries, but
the token sizes reveal the real problem. The first entry alone — Blackburn, de Rijke &
Venema's "Modal Logic" — is 365,868 tokens. This single entry exceeds the entire
TOKEN_BUDGET (8,000 tokens) by a factor of 46. Its own summary notes: "will almost always
exceed budget; prefer more specific entries."

Looking at the token counts, the corpus contains many full-text book-length documents
alongside shorter papers. The current scoring algorithm cannot distinguish "this 5,437-token
paper is highly relevant" from "this 365,868-token book is loosely relevant" — both would
score similarly on keyword overlap, but only the short paper can be included within budget.
The problem is not that 183 entries is "too small for SQLite" but that the token distribution
is so skewed that keyword scoring without token-awareness produces qualitatively wrong results
at current scale.

**On realistic growth trajectory**:

Zotero forum data shows personal academic libraries typically reach 5,000-20,000 entries
over a research career, with researchers consistently underestimating their growth rate
("I can't imagine reaching 20k, but then again I didn't foresee reaching 5k either"). The
claim that SQLite becomes necessary at 500-1000 entries is probably accurate, but at current
growth rates for an active researcher in formal logic, that threshold could arrive within
1-2 years.

**Critical gap**: The current design treats token_count as a budget filter, not as a signal
in scoring. A 365k-token book that scores 3 on keyword overlap is currently ranked above a
5k-token paper that scores 2 — even though the book can never be included in any budget.
Any redesign must incorporate token-efficiency into scoring, not just keyword relevance.

**Confidence**: High on the skewed-token-distribution problem. Medium on growth timeline.

---

## 3. What Gets Missed by Keyword Search

### Finding: Keyword Failure is Catastrophic for the Primary Use Case

**Claim being evaluated**: Keyword-overlap scoring on metadata is adequate for the user's
primary domain (Lean4 theorem proving / formal verification).

**Evidence from formal verification research**:

LeanSearch v2 (arxiv 2605.13137, 2026) documents this failure mode with a concrete example:
proving irreducibility of (x^p−1)/(x−1). The relevant supporting lemmas involve "cyclotomic
polynomials," "geometric sums," and the symbol Φ. None of these words appear in the problem
statement. "Identifying them requires reasoning about proof strategy, not lexical matching."

This is the exact failure mode that will afflict the current system. When an agent is
working on a Lean proof about modal frame completeness and needs the canonical model
construction from Burgess 1982, the task description might say "prove soundness" — keywords
that do not overlap with "maximal consistent sets," "chronicle construction," or "tense
axioms" at all.

The Rango paper (ICSE 2025) confirms this from a different angle: sparse BM25 outperformed
dense embeddings for tactic-to-tactic matching, but crucially, this was for retrieving
similar *proof states*, not for retrieving *papers*. For paper-level retrieval, the paper
explicitly notes that the proof strategy connects to literature through logical architecture,
not terminology overlap.

**Keyword failures specific to this corpus**:

1. **Mathematical symbol aliasing**: "completeness" means different things in modal logic
   (valid formulas are provable), database theory, and graph theory. The current system
   cannot distinguish these.

2. **Concept-to-terminology gap**: A task about "bimodal frame definability" might need the
   Sahlqvist correspondence theory paper (deRijke & Venema 1995), but neither "Sahlqvist"
   nor "correspondence" will appear in a task description that says "check frame conditions."

3. **Cross-paper dependencies**: A lemma in paper A depends on a construction in paper B.
   Keyword scoring of B against the task description yields 0 overlap — B is never
   retrieved even though A (which scores high) cannot be used without B.

**Confidence**: High. Directly evidenced by published formal verification retrieval research.

---

## 4. The Git-Binary Problem

### Finding: This is a Solved Problem, But Requires Deliberate Setup; Not a True Blocker

**Claim being evaluated**: SQLite databases in git repos create large diffs and are a
deployment blocker.

**Evidence**:

The git-binary problem is real but manageable. The standard approaches are:

1. **`.gitignore` the database**: Keep the SQLite file out of git entirely. Use a
   generation script (like the existing `migrate-from-repo.sh`) to build it from `index.json`.
   This is the cleanest approach. The JSON `index.json` remains in git for version control;
   the SQLite cache is ephemeral and rebuilt from JSON as needed.

2. **`git-textconv`**: Configure git to use `sqlite3 .dump` for diffs. This makes the
   binary displayable but does not solve storage bloat.

3. **Git LFS**: An option but overkill for this use case. LFS adds operational complexity
   (requires LFS support on hosting, separate storage limits, different clone behavior).

The existing implementation summary from Task 710 already made this decision correctly:
"JSON over SQLite: Confirmed by research; deferred to 500+ entry threshold. README
documents the rationale and Option A upgrade path (ephemeral SQLite cache, JSON primary)."

**The actual git problem being overlooked**: Not SQLite vs. JSON, but the current practice
of storing full-text markdown files in the Literature repo. The entry for Blackburn et al.
is 365,868 tokens — roughly 1.4MB of markdown for a single book. As the corpus grows with
full-text PDFs converted to markdown, the git repo will bloat not because of SQLite but
because of these markdown files. The `.gitignore` already excludes `pdfs/`, but not the
converted markdown. This is the real version control problem.

**Confidence**: High on the "solved problem" assessment. Medium on the overlooked markdown
bloat issue (would need to audit file sizes to confirm magnitude).

---

## 5. Maintenance Burden

### Finding: Every Search Approach Has Silent Failure Modes; JSON is Most Transparent

**Claim being evaluated**: Which retrieval approach has the lowest ongoing maintenance cost?

**Evidence**:

Vector/embedding approaches have a specific and dangerous failure mode called "embedding
drift." When the embedding model is updated, old embeddings become incompatible with new
query embeddings, and the system silently degrades. There is no error — queries just return
increasingly poor results. Published guidance recommends canary queries run weekly plus
10-15% of embedding costs budgeted for reindexing. For a personal tool used by one
researcher, this monitoring burden is impractical.

BM25/keyword indexes (like the current JSON keyword approach) have a different failure mode:
keyword staleness. When new papers are added, the keyword fields in `index.json` must be
manually curated. The current system requires the user to write accurate keywords for each
entry. This is a human-labor maintenance cost, not a technical one.

**The missed maintenance question**: The task assumes the existing `index.json` keyword
metadata is high-quality. Looking at the actual entries, the keywords are manually curated
for BimodalLogic-specific retrieval. They include author names (e.g., "Burgess"), specific
technical terms ("chronicle construction"), and narrow concepts. These keywords are optimized
for a single project's needs.

If the system were to serve multiple projects (as the centralized `~/Projects/Literature/`
architecture implies), the keyword metadata optimized for BimodalLogic will actively
mislead retrieval for other projects. A paper tagged "bimodal" and "modal logic" for a
modal logic proof project is irrelevant when the agent is working on a different formalism.
The `project_tags` field exists but is not used in scoring.

**Confidence**: High on embedding drift risk. High on keyword staleness. Medium on the
project_tags gap (depends on whether multi-project use is actually intended).

---

## 6. Questions Not Being Asked

### Finding: Five Critical Questions Are Missing from the Design

**6.1. When should `--lit` be silent?**

The current system (and presumably the redesign) injects literature whenever `--lit` is
passed and keyword overlap reaches MIN_SCORE=1. A score of 1 means one keyword matched.
This is a very low bar. The question nobody is asking: when should the system inject
*nothing* even though `--lit` was passed?

If the task is "update the CLAUDE.md extension routing table" and `--lit` is passed, the
system may find a paper with "logic" in its keywords that matches "logic" from the task
description and inject 5,000 tokens of modal logic content. This is harmful, not neutral.
The MIN_SCORE threshold needs to be calibrated by task type, not just set globally.

**6.2. What is the actual failure mode the user experienced?**

The task description says "the current --lit flag might even be worse than no injection"
but does not specify what failure was observed. Did the agent produce wrong results? Did
it ignore the injected content? Did it hallucinate connections between literature and
code? The design of a better system depends critically on diagnosing the actual failure
mode, not just assuming "scoring was bad."

**6.3. Should the system be task-type-aware?**

Literature is relevant for `lean4` and `latex` task types but typically irrelevant for
`neovim` and `nix` task types. The current system applies identical scoring logic
regardless. A `neovim` task with the word "modal" in the description (e.g., "configure
modal keybindings") will match papers about modal logic. This is a false positive that
any scoring improvement must account for.

**6.4. What does "better" retrieval actually look like for formal verification?**

For Lean4 theorem proving, the practitioner workflow is: identify which theorem or
construction from a paper is needed, then look it up. This is chapter-level or
section-level retrieval, not paper-level retrieval. The current index structure with
`chapters[]` in subdirectory indexes acknowledges this, but the merge logic that
normalizes chapters into a flat entries list loses the hierarchical relationship. A
targeted system might need to retrieve "Section 4.3 of Burgess 1982b" rather than the
full paper.

**6.5. Is the real bottleneck retrieval or utilization?**

Research on retrieval systems (arxiv 2603.02473, 2025) finds that retrieval failure
accounts for 11-46% of all agent errors depending on configuration, but utilization
failure — the agent retrieves the right content but fails to use it correctly — accounts
for the remaining majority. If the current --lit system fails, it may be because the
agent cannot identify which section of an injected paper applies to the current proof
state, not because the wrong paper was selected. Better scoring would not fix a
utilization bottleneck.

**Confidence**: High that these questions are missing. Medium to high that each represents
a genuine design gap.

---

## Overall Assessment

### What the Proposed Design Gets Right

- Keyword overlap scoring on index.json metadata is genuinely insufficient
- Token-budget-aware selection is necessary
- The 183-entry corpus is already large enough to require better filtering

### What the Proposed Design Risks Getting Wrong

1. **Optimizing the wrong layer**: Better scoring for preflight injection does not address
   the architectural problem that preflight injection itself is poorly suited to the
   "lost in the middle" failure mode and the non-linear relationship between task
   description keywords and relevant paper content.

2. **The right comparison is injection vs. tool-call**: Before designing a better scoring
   system, the design decision that matters most is: should literature be injected at
   preflight, or exposed as a tool call (`read_literature(query)`) that the agent invokes
   when it determines it needs a reference? The Rango paper's core finding — that
   step-by-step adaptive retrieval outperforms static injection by 47% — is directly
   applicable here.

3. **Embedding drift is a hidden cost**: Any embedding-based approach requires maintenance
   infrastructure that is impractical for a personal tool. For this use case, a hybrid
   sparse approach (BM25 on keyword + summary text, boosted by exact author/title match)
   may outperform embeddings while requiring no ongoing maintenance.

4. **The markdown-in-git problem is the real binary bloat risk**: Full-text converted PDFs
   stored as markdown files in a git repo will bloat the repository independently of any
   SQLite decision.

---

## Sources

- [Rango: Adaptive Retrieval-Augmented Proving](https://arxiv.org/html/2412.14063) — on-demand vs. preflight, BM25 vs. embeddings
- [LeanSearch v2: Global Premise Retrieval for Lean 4](https://arxiv.org/abs/2605.13137) — keyword failure modes in formal verification
- [JetBrains Research: Efficient Context Management (NeurIPS 2025)](https://blog.jetbrains.com/research/2025/12/efficient-context-management/) — context volume vs. quality
- [Embeddings Aren't Magic: Predictable RAG Failure Modes](https://towardsdatascience.com/embeddings-arent-magic-the-predictable-failure-modes-of-rag-retrieval-enterprise-document-intelligence-vol-1-2/) — structural gaps in embedding retrieval
- [Why RAG Falls Short for Autonomous Coding Agents](https://medium.com/@animesh1997/why-rag-falls-short-for-autonomous-coding-agents-86cf5b3dcb69) — industry practitioner perspective
- [SQLite in Git (ongardie.net)](https://ongardie.net/blog/sqlite-in-git/) — binary diff solutions
- [Context Overload in AI Agents (Nexla)](https://nexla.com/blog/context-overload-in-ai-agents) — irrelevant context effects
- [Zotero Forums: How Big Can a Library Get](https://forums.zotero.org/discussion/86136/how-big-can-a-library-get) — realistic corpus growth data
- [Embedding Drift: Why Vector Search Quietly Falls Apart](https://krishnakonar12.medium.com/embedding-drift-why-your-vector-search-quietly-falls-apart-c0b93c29e08d) — silent maintenance failures
- [Diagnosing Retrieval vs. Utilization Bottlenecks in LLM Agent Memory](https://arxiv.org/pdf/2603.02473) — retrieval vs. utilization failure split
