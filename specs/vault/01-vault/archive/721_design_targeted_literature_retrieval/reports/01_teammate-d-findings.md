# Research Report: Task #721 — Teammate D (Horizons)
# Targeted Literature Retrieval — Strategic Direction and Long-Term Alignment

**Task**: 721 - design_targeted_literature_retrieval
**Role**: Teammate D — Horizons (long-term alignment, strategic direction)
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:50:00Z
**Sources/Inputs**: Codebase (literature-retrieve.sh, zotero-search.sh, memory-retrieve.sh, literature extension), index.json (183 entries, 1.3M tokens total), task 710 research reports, tasks 716-720 descriptions, ROADMAP.md

---

## Key Findings

### 1. The Real Problem Is Architectural, Not Algorithmic

The task description frames this as a scoring problem ("crude bag-of-words overlap") but the
actual bottleneck is architectural: **preflight injection is the wrong abstraction for a 183-entry,
1.3M-token corpus**.

Current state of the corpus (measured from index.json):
- 183 entries, total ~1.3M tokens
- 1 entry alone is 365,868 tokens (blackburn_2002 — the full Modal Logic textbook)
- 36 entries individually exceed the 8,000 token budget
- 60 entries exceed 5,000 tokens
- Median entry: ~3,500-4,000 tokens

With an 8,000-token budget and 183 entries averaging 7,164 tokens, at most 1-2 entries can
be injected per invocation — and only if they happen to score above MIN_SCORE=1. The
scoring problem is real but secondary. The primary failure mode is: **even a perfectly-ranked
list cannot fit useful context within 8,000 tokens when every relevant entry is 5,000+ tokens**.

Improving scoring from bag-of-words to TF-IDF-like weighting would improve the *which* entry
gets selected but not the *how much* of it is usable. This is a geometry problem, not a
keyword problem.

### 2. The /cite Command Needs a Fundamentally Different Retrieval Model

Tasks 716-720 are building a `/cite` command for citation verification. The cite workflow
(as designed in task 717) requires:
1. Extract citation claims from text
2. **Search** for matches to each claim in Literature/ and Zotero
3. Score confidence: confirmed/partial/unconfirmed/gap
4. Present findings interactively

This is an **on-demand search** model, not preflight injection. `/cite` will call
`zotero-search.sh` and the Literature/ index independently, with query terms derived
from extracted citation claims — not from a task description passed at preflight time.

The architectural insight: `zotero-search.sh` already implements the right retrieval
model for `/cite`. It scores title (+3), keyword (+2), abstract (+1), author (+1) per
matching term — richer than `literature-retrieve.sh`'s current keyword-only scoring.

**The strategic fork**:
- `--lit` preflight injection: optimizes for "inject the most relevant context before agent starts"
- `/cite` verification: optimizes for "find the matching source for this specific claim"

These are different enough that they warrant different tools. Trying to unify them would
optimize for neither.

### 3. Zotero as the Query Layer, Literature/ as the Content Layer

The clearest strategic insight from examining what exists:

- `zotero-library.json` (CSL-JSON): 878 entries with title, abstract, keywords, authors —
  rich metadata, fast to search with jq, but **no full text**
- `~/Projects/Literature/` index.json: 183 converted entries with summaries and keywords —
  has **file paths to full text**, but weaker metadata than Zotero

These are complementary. The right architecture:

```
Query resolution:
  Task description -> zotero-search.sh (score by title/abstract/keywords) -> top N bib_keys
  bib_keys -> Literature/index.json lookup -> file paths for matched entries
  file paths -> read content -> inject into context
```

This is a **two-pass retrieval**: Zotero gives us fast, metadata-rich ranking; Literature/
gives us the actual converted text. `zotero-search.sh` already does step 1. The missing
piece is the bridge: "take these top-ranked bib_keys and look up their converted text in
Literature/index.json."

This two-pass design eliminates the current problem where literature-retrieve.sh must score
183 entries with limited metadata (only `keywords[]` and `summary` fields). Zotero's `abstract`
field (~200 tokens per entry) provides much richer signal than the current summary, and it
covers 878 entries (the full library), not just 183.

### 4. The Minimal Viable Improvement Is a Two-Step Script, Not a New System

The smallest change that meaningfully improves on current behavior:

**Approach**: Modify `literature-retrieve.sh` to:
1. If `ZOTERO_LIBRARY` is available: run `zotero-search.sh <keywords>`, get ranked bib_keys
2. Look up those bib_keys in `Literature/index.json` to find the converted file paths
3. Inject the matched files within token budget

This requires ~20 lines of new bash logic (call zotero-search.sh, parse its JSON output,
cross-reference index.json). The scoring quality jumps significantly because Zotero's abstract
field is much richer than the current keyword-match-only approach.

**What it doesn't require**:
- SQLite (still below 500-entry threshold, confirmed by task 710 research)
- Embedding/vector search (overkill for 183 entries)
- Agent-callable tools (adds complexity, breaks preflight injection model)
- New index schema fields (the bib_key bridge already exists in index.json v2)

### 5. Agent-Callable Search: The Right Model for /cite, Not for --lit

The task asks whether `--lit` should become an agent-invocable tool. The answer is:
**agent-invocable search is the right model for /cite, but the wrong model for --lit**.

Reasons:
- `--lit` preflight injection happens *before* the agent starts. Converting to agent-callable
  would require the agent to first call the search tool, then decide what to read. This adds
  a tool-use round trip and requires the agent to know to call it. The current model (inject
  context before agent context) is architecturally cleaner for general-purpose augmentation.
- `/cite` *already* needs agent-callable search: the cite workflow extracts claims, searches
  for matches, and presents results — all within the agent run. `zotero-search.sh` is already
  structured as an agent-callable script (stdin/stdout, JSON output).

The bifurcation is: `--lit` stays preflight injection (improved), `/cite` uses on-demand
search (zotero-search.sh + Literature/ index lookup).

### 6. Cross-Repo Literature Sharing: LITERATURE_DIR Is Already Correct

The cross-repo design (LITERATURE_DIR env var, two-tier fallback) was established by task 710
and is implemented. All projects that set `LITERATURE_DIR=/home/benjamin/Projects/Literature`
get access to the same 183-entry corpus via `--lit`. No per-project index is needed unless a
project needs custom chunking of shared papers (which is the existing two-tier fallback model).

The strategic question for retrieval: should there be a **per-project search context** that
filters which Literature/ entries are relevant? For example, a cslib task might want only
entries tagged `project_tags: ["cslib"]`. The v2 index schema already has `project_tags`.

The simplest implementation: add a `--project SLUG` filter to `literature-retrieve.sh` that
restricts candidates to entries whose `project_tags` include the given slug. This is a 3-line
jq filter addition.

### 7. Long-Term: The Abstract Field Is the Missing Bridge

The current index.json has `summary` fields for all 183 entries — a manually-curated or
agent-generated description of what each entry covers. But `zotero-library.json` has `abstract`
fields for most entries (automatically maintained by Zotero from the paper metadata).

The long-term improvement that unlocks much better retrieval without embedding:
**Add `abstract` as a searchable field in Literature/index.json**, populated from
`zotero-library.json` during indexing. This is a one-time migration (183 entries, jq
cross-reference from bib_key) and would double the signal available for keyword matching.

At the same time, the current `summary` field is agent-written (not Zotero-sourced) and
likely contains different content than the abstract. Both are valuable:
- `abstract`: author's own summary (citable, precise, uses domain terms)
- `summary`: what the agent found important (retrieval-optimized, task-oriented)

Supporting both in the scoring function with different weights (abstract: +2, summary: +1)
would be a modest improvement achievable with a jq scoring update.

---

## Recommended Approach

**The Horizons recommendation: a three-tier architecture with clean separation of concerns.**

### Tier 1: Preflight Injection (--lit) — Improve, Don't Replace

Keep `--lit` as preflight injection. The improvement path:

1. **Phase A (immediate)**: Zotero-bridge scoring in `literature-retrieve.sh`. When
   `ZOTERO_LIBRARY` is available, use `zotero-search.sh` to rank entries by Zotero
   metadata (title + abstract + keywords) and cross-reference to Literature/ index for
   file paths. Falls back to current keyword scoring when Zotero library is absent.

2. **Phase B (next, with abstract migration)**: Add `abstract` field to Literature/index.json
   entries (populated from zotero-library.json via bib_key cross-reference). Update scoring
   to weight abstract (+2) and summary (+1) separately. No Zotero library required at retrieval
   time — all metadata is in index.json.

3. **Phase C (deferred, ~500+ entries)**: SQLite FTS5 ephemeral cache for full-text search
   across all 183+ converted documents. This is the task 710 "Option A" (JSON primary, SQLite
   ephemeral cache on demand).

### Tier 2: On-Demand Verification (/cite) — Use zotero-search.sh Directly

The `/cite` command workflow (tasks 716-720) should use `zotero-search.sh` as its primary
search tool. For citation verification:
- Input: extracted citation claim ("Smith 2020 proves completeness of S4")
- Query: `zotero-search.sh "completeness S4" --limit=5`
- Cross-reference result bib_keys with Literature/index.json for converted text availability
- Present confidence scores to user

No changes needed to `literature-retrieve.sh` for `/cite`. The two tools serve different
masters. `/cite` needs Zotero-primary search (broader library, better metadata). `--lit`
needs Literature/-primary injection (smaller corpus, full converted text).

### Tier 3: Memory Seeding (future) — Literature Entries as Memory Pointers

From the task 710 horizons research: when a Literature/ entry is indexed, emit a compact
memory to `.memory/` vault:
```
[bib_key] "{Title}" ({Year}) — {one-sentence summary} — at Literature/{path}
```

This means `memory-retrieve.sh` would surface "there is a relevant literature entry for
this topic" during research, and the agent could decide to request `--lit` in the next
invocation. This creates a soft two-pass retrieval: memory as pointer, `--lit` as content.

This is a Phase B+ enhancement, not a Phase A requirement.

---

## Evidence and Examples

### The Geometry Problem (Concrete Numbers)

```
Token budget:         8,000
Average entry size:   7,164 tokens
Budget / avg:         1.1 entries per invocation (maximum)

Entries > budget:        36 (entirely excluded regardless of relevance)
Entries within budget:  147

For task 201 "IPL completeness":
  Relevant entries likely include:
  - johansson_1937 (IPL founder paper) — ~2,500 tokens
  - doets_1987 (completeness) — ~19,591 tokens (EXCEEDS BUDGET)
  - venema_2001_temporal_logic_survey — likely large
  
  Only johansson_1937 could be injected without budget exhaustion.
  Better scoring would still only get you 1-2 entries in 8,000 tokens.
```

The geometry problem is fundamental. Better scoring narrows *which* entry appears in slot 1
but doesn't change that slot 1 is all you get. The Zotero-bridge approach (Phase A) would
ensure slot 1 is the *best* possible entry (using abstract-rich scoring), which is still
a meaningful improvement.

### The Zotero Bridge (Pseudocode)

```bash
# In literature-retrieve.sh, after extracting keywords:
if [ -f "$ZOTERO_LIBRARY" ]; then
  # Phase A: Get ranked bib_keys from Zotero metadata
  zotero_results=$(zotero-search.sh --limit=20 --format=json $keywords)
  ranked_bib_keys=$(echo "$zotero_results" | jq -r '.[].id')
  
  # Cross-reference with Literature/index.json
  selected=$(jq --argjson keys "$ranked_bib_keys" '
    [.entries[] | select(.bib_key as $k | $keys | index($k) != null)]
    | sort_by(.bib_key as $k | $keys | index($k))
  ' "$INDEX_FILE")
else
  # Phase A fallback: current keyword scoring
  scored_entries=...
fi
```

This replaces the current bag-of-words overlap with Zotero's abstract-aware scoring while
keeping the Literature/ index as the source of converted text.

### Why Not Embedding/Vector Search?

At 183 entries with rich keyword and abstract metadata, classical keyword scoring with
proper weighting consistently outperforms embeddings in IR benchmarks for specialized
academic corpora. The domain is narrow (modal logic, temporal logic, formal verification) —
keywords are highly discriminative. Embeddings would add:
- External API dependency (or local model at ~1-4GB)
- Index maintenance complexity (re-embed on update)
- No interpretability (can't debug why an entry was/wasn't selected)

The crossover point where embeddings meaningfully outperform keyword scoring for this
domain is probably ~5,000+ entries with sufficient topical diversity. Not applicable here.

### Why Not SQLite Now?

Task 710 research established 500-1000 entries as the SQLite threshold. That research stands.
At 183 entries, jq handles the scoring in milliseconds. The current jq pipeline in
`literature-retrieve.sh` is ~120 lines but computationally trivial.

---

## Confidence Level: High

**High confidence** on:
- The geometry problem diagnosis (numbers are concrete and measured from actual index.json)
- The two-pass Zotero-bridge approach (builds on existing zotero-search.sh, minimal new code)
- The --lit vs /cite architectural bifurcation (different use cases, different tools)
- SQLite deferral (task 710 research is directly applicable and recent)
- LITERATURE_DIR cross-repo design (already implemented correctly by task 710)

**Medium confidence** on:
- The exact Phase A implementation (the bash integration of zotero-search.sh output into
  literature-retrieve.sh needs verification that the bib_key cross-reference works reliably
  across the 183 entries — some entries have `bib_key: null` or divergent keys)
- The abstract migration timeline (depends on Zotero CSL-JSON export quality for all 183 entries)

**Lower confidence** on:
- Future AI tool integration (MCP context injection, etc.) — the standards are evolving
  quickly and any prediction about 2027+ tooling is speculative

---

## Strategic Implications for the Full Task Chain (716-721)

The recommended approach has a clean division of labor:

| Component | Tool | Model |
|-----------|------|-------|
| --lit (preflight) | literature-retrieve.sh + zotero-search.sh bridge | Push model (inject before agent) |
| /cite (verification) | zotero-search.sh + Literature/ cross-ref | Pull model (agent queries on demand) |
| /literature --search | zotero-search.sh | Interactive search (user-driven) |
| Memory vault | memory-retrieve.sh | Short pointers to longer literature entries |

Tasks 716-720 (/cite chain) can proceed without waiting for task 721 implementation, because
they use `zotero-search.sh` directly — a separate tool that already exists. Task 721 improves
`--lit` injection quality but is independent of the `/cite` verification workflow.

**The key strategic decision for task 721 implementation**: implement Phase A (Zotero bridge
in literature-retrieve.sh) as an additive improvement that gracefully falls back to current
behavior when `ZOTERO_LIBRARY` is unavailable. This preserves backward compatibility for all
existing `--lit` users (BimodalLogic tasks, etc.) while unlocking better retrieval for the
centralized Literature/ setup.
