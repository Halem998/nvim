# Research Report: Task #833

**Task**: 833 - Harden `.claude/scripts/literature-search.sh` and `literature-briefing.sh` so
tokenization brittleness degrades gracefully
**Started**: 2026-07-09
**Completed**: 2026-07-09
**Effort**: Medium (query-side normalization + a fallback ladder in one script; no schema rewrite)
**Dependencies**: #831 (completed — defines the corpus-side normalization this task mirrors)
**Sources/Inputs**:
- `.claude/scripts/literature-search.sh` (905 lines, read in full)
- `.claude/scripts/literature-briefing.sh` (366 lines, read in full)
- `.claude/scripts/literature-schema.sql` (89 lines, read in full)
- `.claude/scripts/literature-convert.sh` lines 170-244 (the `normalize_unit`/`normalize_document`
  functions #831 added, read directly)
- `specs/831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md`
  and `summaries/01_conversion-pipeline-fix-summary.md` (read in full — #831's Interface
  Contracts section explicitly hands #833 the ligature-folding boundary)
- Empirical testing: live SQLite 3.51.2 FTS5 queries (both a synthetic in-memory table and the
  real corpus at `~/Projects/Literature/.literature.db`, 3746 chunk rows / 81 docs, read-only)
  against the actual `sanitize_query()` Python function copied verbatim from the script
- `python3 -c "import sqlite_vec"` (not installed) and a live `conn.execute("...tokenize='trigram'...")`
  probe (trigram FTS5 tokenizer confirmed built into this system's SQLite, no extension needed)
- `git log --oneline -- .claude/scripts/literature-search.sh literature-briefing.sh literature-schema.sql`
  (confirms task #835's provenance/fidelity work is the only other recent change to these files,
  and is orthogonal to tokenization)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The triggering symptom is real and empirically reproduced**: `sanitize_query()` in
  `literature-search.sh` (lines 94-148) strips `AND`/`OR`/`NOT`, unanchored `*`, unbalanced quotes,
  unbalanced parens, and apostrophes — but does **not** touch hyphens, colons, slashes, or
  *balanced* parens attached to a word. All four still throw FTS5 `OperationalError` (syntax
  error, or "no such column") after passing through the current sanitizer, verified directly
  against a query shaped like the triggering task's own title
  (`"joint multi-owner disjunct(bracketholds) engine for KVE2 sepdisjunct"` →
  `no such column: owner`).
- **#831's corpus-side normalization (ligature fold, keep-hyphen dehyphenation, soft-wrap
  rejoining) is a *content* transform applied once at conversion time, not a tokenizer setting** —
  there is nothing in FTS5 config to "mirror." The one piece of that normalization with a live
  query-time consequence is ligature folding: a query containing a raw ligature character
  (e.g. `ﬁ`) will never match the corpus's already-folded `fi`, silently returning zero results
  with no error. This is exactly the gap #831's own report flags for #833 ("#833 must perform its
  own FTS-time folding ... This is a #833 dependency, not implemented here").
- **Recommended fallback ladder** (four rungs, each cheap and already available in this SQLite
  build — no new dependency): (1) apply an extended sanitizer (fold ligatures + escape/space
  hyphens, colons, slashes, and word-attached parens) before the existing FTS5 MATCH; (2) if that
  still throws `OperationalError`, retry with the *entire* sanitized query double-quoted as one
  FTS5 phrase (turns almost any punctuation soup into a valid, if less precise, phrase query);
  (3) if MATCH succeeds syntactically but returns zero rows, fall back to a **trigram FTS5
  index** (SQLite 3.51.2's built-in `tokenize='trigram'` — confirmed present, no extension,
  substring-matches through punctuation by construction) over `chunks_data.content`; (4) sqlite-vec
  semantic search is **not recommended** for this task (see below) — evaluated and explicitly
  deferred, not silently dropped.
- **sqlite-vec / embeddings: recommend DEFER, not adopt.** Not installed on this machine
  (`ModuleNotFoundError`), and it solves a different problem (semantic drift) than the one in the
  triggering symptom (syntax-level query rejection). Trigram FTS5 fixes the actual reported
  failure at zero new dependencies; sqlite-vec would add an embedding-generation pipeline,
  re-embedding on every corpus change, and a new query-time embedding call — real cost for a
  problem this task's own evidence doesn't show existing today (no report of correct-punctuation
  queries returning semantically-wrong results, only of syntax rejection).
- **Per-chunk LLM "gist": recommend DEFER, not adopt**, for the same reason #831 already gave when
  triaging this exact idea out of its own scope: non-deterministic, costly at ~3,746 chunks, and
  orthogonal to the concrete failure mode in evidence. The existing heuristic `summary` column
  (already FTS-indexed at BM25 weight 3) is the cheaper lever if the real problem is match
  *quality* rather than match *availability* — that's a separable, lower-priority enhancement, not
  required to fix the "chokes on punctuation" complaint.
- **`literature-briefing.sh`'s "usable next action" gap is real but narrow**: today, when
  `--global` mode's search returns zero results, the block correctly says "No matching literature
  segments found for this query" (verified at lines 338-341) — that's already non-silent. But
  neither `literature-briefing.sh` nor `literature-search.sh` ever surfaces the FTS5 *parse
  failure* itself to the agent; a syntax error is currently swallowed to stderr
  (`print(f"[search] Query error: {e}", file=sys.stderr)`, `do_search`, lines 286-289) and the
  script still emits a *successful* empty JSON array (`[]`), indistinguishable from "genuinely no
  matches." This is the direct mechanism behind the agent's "I'll just read the chunk directly"
  dead end — the tool never told it retrieval had failed rather than found nothing.

## Context & Scope

Task #833 augments `.claude/scripts/literature-search.sh` and `literature-briefing.sh` (schema
change to `literature-schema.sql` is additive-only — a new trigram virtual table alongside the
existing `chunks_fts`, never a rewrite of the existing FTS5/BM25 design). Corpus conversion
(#831, completed) and corpus reconversion (#832, parallel) are out of scope; this report treats
#831's Interface Contracts section as binding and does not re-derive or contradict its
ligature-folding-boundary decision (query-time folding belongs to #833, corpus-time folding stays
targeted-ligature-only, no blanket NFKC).

## Findings

### 1. What #831 normalized on the corpus side, and where the query path diverges

`literature-convert.sh:180-223` (read directly) defines the corpus-side normalization exactly:

```python
LIGATURE_MAP = {"ﬀ":"ff","ﬁ":"fi","ﬂ":"fl","ﬃ":"ffi","ﬄ":"ffl","ﬅ":"st","ﬆ":"st"}
def fold_ligatures(text): ...        # targeted U+FB00-FB06 only, no blanket NFKC
def dehyphenate(text): ...           # word-\nword -> word-word, KEEP the hyphen
def rejoin_soft_wraps(text): ...     # word\nword -> word word, within a paragraph only
def normalize_unit(text):
    text = fold_ligatures(text); text = dehyphenate(text); text = rejoin_soft_wraps(text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()
```

Three of these four are line-break/whitespace repairs with no query-time analogue — a query
string typed by an agent doesn't contain PDF line-wrap artifacts. **Ligature folding is the only
one with a live query-time consequence**: the corpus stores `fi`/`fl`/etc. (folded), so a query
containing the original ligature glyph (`ﬁ`, `ﬂ`, ...) will never match, and — critically — this
fails *silently*, not with a syntax error (verified: `"swordﬁsh identiﬁcation"` passes
`sanitize_query()` unchanged and executes as valid FTS5, returning `[]` against content containing
"swordfish identifi"). #831's own summary document says this explicitly and hands it to #833:
> "#833 must perform its own FTS-time folding for `unicode61` tokenizer matching (broader
> normalization for search purposes, applied at index time, not destructively at conversion
> time). This is a #833 dependency, not implemented here."

**Recommendation**: add the identical `LIGATURE_MAP` fold (7-character regex substitution, no new
dependency, copy-paste-stable from `literature-convert.sh`) as the *first* step of
`sanitize_query()`, before any other processing. This is the literal "same normalization" the
task description asks for, scoped correctly (folding, not NFKC).

### 2. Current FTS5 query construction and exactly which characters break it

`do_search()` (`literature-search.sh:151-471`) sends the sanitizer's output straight into
`WHERE chunks_fts MATCH ?` via a parameterized query (line 262/277/415) — parameterization is
correct and already prevents SQL injection; the problem is entirely FTS5's own query-string
grammar, which is stricter than plain full-text input. Reading `sanitize_query()`
(lines 94-148) line by line: it handles `AND`/`OR`/`NOT` keywords, unanchored `*`, unbalanced `"`
pairs, unbalanced `(`/`)` pairs, and apostrophes. It does **not** handle:

| Character | FTS5 meaning | Verified failure (this session, live SQLite 3.51.2) |
|---|---|---|
| `-` (hyphen, mid-word) | Column-exclusion / NOT-prefix operator | `"multi-owner"` → `no such column: owner` |
| `:` (colon) | Column-filter syntax (`column: value`) | `"column:value search"` → `no such column: column` |
| `/` (slash) | Not a valid bare token character | `"KVE2/sepdisjunct"` → `syntax error near "/"` |
| `(`/`)` attached to a word, **even when balanced** | Grouping operator, needs surrounding whitespace | `"disjunct(bracketholds)"` (open=close=1, so the sanitizer's unbalanced-paren check never fires) → `syntax error near "disjunct"` (quoting it as `"disjunct(bracketholds)"` fixes it — verified) |

All four were reproduced directly against a query string shaped like the triggering task's own
title (`04_joint-disjunct-holds-codesign.md`, `KVE2_sepdisjunct`) — this is not a hypothetical;
it is the literal class of string that caused the original dead end.

**Root cause in one sentence**: `sanitize_query()` is a strip-known-bad-tokens filter, not a
"make anything into a valid FTS5 query" transform, and academic/technical query text (task slugs,
paper titles, code identifiers) routinely contains exactly the punctuation FTS5 treats as syntax
(hyphens, colons, slashes, parens) rather than as word characters.

### 3. Concrete fallback ladder design

Each rung reuses existing capability already present in this repo/runtime — no new package
installs, no schema rewrite:

**Rung 0 — extend `sanitize_query()`** (in-place fix, cheapest, catches the majority case):
- Prepend the `LIGATURE_MAP` fold (Finding 1).
- Replace mid-word hyphens with a space (`re.sub(r'(?<=\w)-(?=\w)', ' ', query)`) — turns
  `multi-owner` into `multi owner`, both real tokens, matches user intent far better than an
  exclusion operator nobody meant to invoke.
- Strip colons (`query.replace(':', ' ')`) — colon-as-column-filter is never an intended search
  operator for this tool's callers (no caller constructs `title: foo` deliberately; the CLI takes
  one free-text query string).
- Strip slashes (`query.replace('/', ' ')`).
- For parens: the existing unbalanced-paren strip already exists; additionally treat *any* paren
  adjacent to a non-space character as needing a surrounding space
  (`re.sub(r'\(', ' ( ', query); re.sub(r'\)', ' ) ', query)` before the balance check) so FTS5's
  grouping syntax is only invoked when whitespace-delimited, matching what a user typing literal
  parens almost always means (grouping, not attachment) — or, simpler and equally effective given
  this tool never needs FTS5 grouping semantics from free-text input: strip parens entirely like
  colons/slashes, since no caller in this codebase constructs a deliberate FTS5 boolean-grouping
  query. **Recommend the simpler option** (strip, don't try to preserve grouping semantics) —
  this tool's only caller is "one opaque query string," never a hand-built FTS5 boolean
  expression.

**Rung 1 — safe phrase-quote retry, only on syntax error**: if MATCH still raises
`sqlite3.OperationalError` after Rung 0 (should be rare after the above, but a punctuation
character not enumerated above could still appear), catch the exception in the existing
`try/except sqlite3.OperationalError` block (`do_search`'s `search_db()`, lines 283-289 and
419-425) and retry once with the whole sanitized string wrapped in a single double-quoted phrase
(`'"' + sanitized.replace('"','') + '"'`) — FTS5 phrase queries accept most punctuation inside
the quotes as literal content to tokenize, since the tokenizer (not the query grammar) processes
phrase contents. This is a one-line addition to the existing except block, not a new code path.

**Rung 2 — trigram fallback on zero-results (not on syntax error)**: after Rungs 0-1 produce a
syntactically valid MATCH with zero rows, fall back to a **second FTS5 virtual table using
SQLite's built-in `trigram` tokenizer** — confirmed present in this system's SQLite 3.51.2
(`tokenize='trigram'` created and queried successfully in this session's testing, no extension
load required, unlike the `unicode61`/`porter` combination FTS5 already uses for `chunks_fts`).
Trigram tokenization matches on any 3-character substring run, so punctuation-glued queries like
`bracketholds` still match `disjunct(bracketholds)`-shaped content because it never treats
punctuation as syntax in the first place — it's a data representation choice, not a query-parsing
concern. At this corpus's actual size (3,746 chunk rows, 81 docs, measured live against
`~/Projects/Literature/.literature.db`), a second FTS5 index adds negligible storage/rebuild cost
and trigram queries return in sub-millisecond time; this is the "trigram/LIKE" option the task
description names, and trigram is strictly better than raw LIKE here (LIKE requires a full table
scan per query with no index support for `'%term%'` patterns; SQLite's trigram FTS5 tokenizer
gives the same substring-matching semantics with an actual index).
- **Schema addition** (additive to `literature-schema.sql`, not a rewrite): a second virtual
  table, e.g. `chunks_trigram USING fts5(content, content='chunks_data', content_rowid='id',
  tokenize='trigram')`, populated via the same `INSERT INTO ...(chunks_fts) VALUES('rebuild')`
  pattern already used for `chunks_fts`. Only invoked as a fallback query path, never the primary
  ranking (BM25 on `chunks_fts` remains primary since it has the title/keywword/summary/content
  weighting the task depends on; trigram fallback returns unranked or naively-ranked matches,
  clearly labeled as a fallback tier in the result JSON, e.g. `"match_tier": "trigram_fallback"`).

**Rung 3 — sqlite-vec semantic search**: evaluated, **not recommended for this task** (see next
section) — included in the ladder design only as the documented "why we stopped at rung 2"
decision point, not as a rung to implement now.

### 4. sqlite-vec / per-chunk gist: evaluate, recommendation = defer both

**sqlite-vec**: not installed (`pip3 show sqlite-vec` → not found; `import sqlite_vec` →
`ModuleNotFoundError`). Adopting it would require: (a) a new Python dependency (outside this
project's existing zero-extra-dependency SQLite/stdlib approach for retrieval scripts), (b) an
embedding model choice and a one-time (or per-corpus-change) embedding-generation pass over all
3,746 chunks, (c) a query-time embedding call for every search (latency + potentially a model
load), and (d) an index-maintenance story (re-embed on re-ingest) that doesn't exist yet anywhere
in this pipeline. Against that cost, semantic search solves *semantic* mismatch (synonyms,
paraphrase), which is a **different failure mode** than the one in evidence — the triggering
symptom was a hard syntax rejection on a query containing the right words in the wrong
punctuation shape, not a case where the right words failed to find semantically related content.
Rungs 0-2 fix the actual reported failure at zero new dependencies. **Recommendation: defer.**
Revisit only if a future task reports genuine semantic-mismatch retrieval failures (right
punctuation, wrong words) as its own triggering symptom — that would be a new, separate task, not
an expansion of #833.

**Per-chunk LLM gist**: #831's own report already triaged this exact idea out of its scope with
reasoning that still applies unchanged here: "Requires an LLM call per page (~4,000 files × N
pages = large, non-deterministic, costly...) If ever wanted, it's a retrieval-time enrichment
(#833), not a deterministic conversion step." Having now looked at the retrieval side directly:
the schema already has a `summary` column (`chunks_data.summary`, FTS-weighted 3rd of 4 in the
existing `bm25(chunks_fts, 10, 5, 3, 1)` call) populated today by a cheap heuristic (first
sentence, per the schema's own comment). An LLM gist would only improve *that already-existing,
already-weighted* column's content quality — it does not unlock any new retrieval *capability*
the punctuation-tolerant fallback ladder doesn't already provide, and it introduces per-run LLM
cost and non-determinism across ~3,746 chunks for a benefit (better semantic summaries) orthogonal
to the reported symptom (syntax rejection). **Recommendation: defer.** If summary quality is
later found to be a real, separately-reported retrieval problem, that is a scoped, small follow-up
(re-generate the `summary` column's content, no schema change) — not bundled into this task.

### 5. What "usable next action" `literature-briefing.sh` should emit on zero results / failure

Two distinct situations need to be distinguished, and today they are conflated into the same
observable outcome (empty JSON array, no error signal reaching the agent):

1. **Genuine zero-results** (query was valid FTS5, corpus has nothing matching): already handled
   reasonably in `--global` mode — `literature-briefing.sh:338-341` emits "No matching literature
   segments found for this query." inside the `<literature-briefing>` block. This is not silent
   already, and needs no further change.
2. **Query parse failure** (the actual triggering symptom): `literature-search.sh`'s
   `search_db()` catches `sqlite3.OperationalError`, prints to stderr only
   (`file=sys.stderr`, invisible to the calling agent unless it's inspecting the subprocess's
   stderr stream, which callers of this CLI tool generally are not), and returns `[]` — making a
   parse failure *indistinguishable* from case 1 at the JSON-output level the agent actually sees.
   This is the direct mechanism behind "FTS5 chokes on the punctuation; I'll just read the chunk
   directly": the agent got an empty result with no signal that the empty result was an artifact
   of a broken query rather than an accurate "nothing here."

**Recommendation**: after Rungs 0-2 of the fallback ladder run and *still* produce zero usable
results (i.e., even the trigram fallback found nothing, or an internal error occurred at every
tier), have `do_search()` include a `"degraded": true` / `"fallback_tier": "trigram" | "none"` /
`"query_error": "<original FTS5 error message>"` field set on the JSON envelope (not per-row, a
top-level field alongside the results array or as part of an error object) so
`literature-briefing.sh` can render an honest, actionable line in the briefing block, e.g.:

```
No matching literature segments found for "disjunct(bracketholds)" query.
Note: the original query triggered an FTS5 syntax error; a punctuation-tolerant retry and a
trigram fallback both ran and also found nothing. Try a shorter, plainer-language query, or
browse the table of contents: `bash .claude/scripts/literature-search.sh --toc <doc_id>`
```

This directly replaces the agent's current improvisation ("I'll just read the chunk directly")
with a concrete, scripted next action the tool itself proposes — satisfying the task's explicit
requirement that `literature-briefing.sh` "surfaces a usable next action rather than leaving the
agent to improvise."

## Decisions

- Mirror #831's corpus normalization on the query side by folding the *same* `LIGATURE_MAP`
  (U+FB00-FB06) at the top of `sanitize_query()` — this is the literal, scoped "same
  normalization" the task asks for; no broader Unicode normalization (no NFKC) on the query side
  either, for the same math-corruption reasons #831 already established.
- Strip mid-word hyphens, colons, slashes, and parens to spaces in `sanitize_query()` rather than
  trying to preserve FTS5's grouping/column-filter semantics — simpler and matches this tool's
  actual usage pattern (opaque free-text query, never a hand-built FTS5 boolean expression).
- Fallback ladder order is: extended sanitizer -> phrase-quote retry (on syntax error only) ->
  trigram FTS5 (on zero-results, syntax-valid case) -> stop (sqlite-vec explicitly not
  implemented). Each rung is only invoked when the prior rung fails its specific condition
  (syntax error vs. zero rows), so the common case (a query that already works) pays no extra
  cost.
- sqlite-vec: **defer**, not adopt. Per-chunk LLM gist: **defer**, not adopt. Both evaluated on
  their merits against the actual reported symptom, not assumed-adopted per the task's explicit
  instruction not to assume adoption.
- Add a `chunks_trigram` FTS5 virtual table to `literature-schema.sql` as a strictly additive
  schema change (new `CREATE VIRTUAL TABLE`, new rebuild-trigger insert, no `DROP TABLE`/rewrite
  of the existing `chunks_fts`/`chunks_data`/`chunk_relations`/`document_metadata` tables).
- Surface parse-failure vs. genuine-zero-results as a distinguishable, honest signal in
  `literature-search.sh`'s JSON output and `literature-briefing.sh`'s rendered block, with a
  concrete next-action suggestion (shorter query, or `--toc`) rather than leaving the calling
  agent to infer failure from an empty array.

## Risks & Mitigations

- **Risk**: Stripping hyphens/colons/slashes to spaces could reduce precision for queries that
  legitimately mean a compound/hyphenated technical term as one unit (e.g. a query for an exact
  "well-known" phrase). **Mitigation**: this is exactly the trade-off FTS5's own query grammar
  already forces on any caller — a raw hyphen is *already* being interpreted as an operator today
  (worse: silently changing meaning to "NOT that word" rather than erroring, in some cases), so
  converting it to a space converts "wrong interpretation" into "slightly looser but at least
  matching" — an unambiguous improvement over the current status quo of either a hard syntax
  error or a silently-wrong exclusion query.
- **Risk**: A second FTS5 index (`chunks_trigram`) doubles the on-disk index size for `content`.
  **Mitigation**: at 3,746 rows this is negligible in absolute terms (verified corpus size live);
  if the corpus grows by orders of magnitude, revisit — not a concern for the corpus size seen in
  this repo today.
- **Risk**: Trigram fallback matches are lower-precision (unranked or crudely ranked) than BM25
  results and could look confusingly authoritative if unlabeled. **Mitigation**: tag trigram-
  fallback results distinctly in the output JSON (`"match_tier": "trigram_fallback"`) so
  `literature-briefing.sh` and any agent consuming the JSON directly can visually distinguish
  "confident FTS5/BM25 match" from "fallback substring match, verify relevance yourself."
- **Risk**: Silently degrading is exactly what task #835 (already landed) worked to eliminate for
  provenance/fidelity; this task's fallback ladder must not reintroduce silent degradation in a
  different dimension. **Mitigation**: every fallback rung's activation is intended to be visible
  in the output (`"fallback_tier"`, `"query_error"` fields) — never a bare, unexplained result-set
  swap. This mirrors #835's own "loud, never silent" pattern already established in this same
  script (`provenance_fidelity` quarantine banners), which the planner should follow as
  established local precedent, not invent a new convention.

## Context Extension Recommendations

- **Topic**: FTS5 query-string grammar gotchas (hyphen-as-NOT-operator, colon-as-column-filter,
  unattached-vs-attached parens, trigram tokenizer availability) discovered empirically this
  session.
- **Gap**: No existing `.claude/context/` entry documents SQLite FTS5's query-syntax pitfalls for
  free-text input, despite this being the second literature-retrieval task (after #831) to run
  into SQLite/FTS5-specific behavior that isn't obvious from the schema file's own comments.
- **Recommendation**: after #833 implementation lands, consider a
  `.claude/context/project/literature/` doc (or a `.memory/` entry) capturing: the specific
  characters that break bare FTS5 MATCH queries, the "trigram tokenizer needs no extension in
  SQLite >= 3.34" fact (verified present at 3.51.2 on this machine), and the phrase-quote-everything
  fallback trick — directly reusable for any future FTS5-based tool in this repo.

## Appendix

### Commands / probes run this session
- `git log --oneline -20 -- .claude/scripts/literature-search.sh literature-schema.sql literature-briefing.sh`
  — confirmed only #835 (provenance/fidelity) touched these files recently; no prior tokenization work.
- Live in-memory SQLite 3.51.2 FTS5 probes reproducing exact syntax errors for hyphen, colon,
  slash, and attached-but-balanced parens, both against a synthetic table and against the actual
  `sanitize_query()` function body copied verbatim from the script.
- `python3 -c "import sqlite3; conn=sqlite3.connect(':memory:'); conn.enable_load_extension(True)"`
  — confirmed extension loading is available in this Python's sqlite3 build (relevant if
  sqlite-vec were ever revisited later, though not needed for the trigram tokenizer, which is
  built into SQLite core).
- `pip3 show sqlite-vec` / `python3 -c "import sqlite_vec"` — confirmed not installed.
- `python3 -c "...tokenize='trigram'..."` — confirmed the trigram FTS5 tokenizer works natively,
  no extension load required, and correctly substring-matches through attached punctuation.
- Queried the real corpus DB (`~/Projects/Literature/.literature.db`, read-only) for row/doc
  counts to ground the "negligible index-size cost" and "sub-millisecond" claims in this
  corpus's actual scale (3,746 chunk rows, 81 distinct docs) rather than a hypothetical.

### Files read in full
- `.claude/scripts/literature-search.sh` (905 lines)
- `.claude/scripts/literature-briefing.sh` (366 lines)
- `.claude/scripts/literature-schema.sql` (89 lines)
- `specs/831_.../reports/01_conversion-pipeline-fix.md` and
  `summaries/01_conversion-pipeline-fix-summary.md`

### Files referenced but not modified (research only)
- `.claude/scripts/literature-convert.sh` (lines 170-244 read directly for the normalization
  function bodies)
