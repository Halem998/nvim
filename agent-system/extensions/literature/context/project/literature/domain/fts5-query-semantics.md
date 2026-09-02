# FTS5 Query Semantics: AND-All-Terms, the Hostile-Character Set, and the Multi-Query Envelope

This doc records the FTS5 gotchas a contributor needs before adding a new call site to
`literature-search.sh` or changing how a query string reaches it. Every claim here traces to a
live `sqlite3`/FTS5 check or a direct read of the two scripts named below — none of it is
inference from documentation alone.

## FTS5's bareword-AND default

A bareword `MATCH` query (no explicit `AND`/`OR`/quoting) requires **every** whitespace-separated
term to appear in the row. This is fine for a 2-4 word hand-typed search, but it is a hard
recall ceiling once a query reaches full-sentence or full-paragraph length: the probability that
any single chunk contains all N terms falls off fast as N grows, and by 15-30+ words it is
effectively zero for any real corpus. `literature-search.sh`'s `do_search()` forwards a raw query
string to FTS5 exactly this way — it is the right choice for a short query and the wrong one for
a long one.

**Consequence for callers**: never hand a full free-text paragraph to a single bareword `MATCH`
call expecting broad recall. Either keep the caller's query short (2-6 words), or decompose a long
query into several short per-term (or small-group) queries and merge the results — see
"The multi-query envelope" below for the mechanism `literature-briefing.sh`'s `--global` mode
uses.

The three-rung fallback ladder inside `search_db()` (bm25 → phrase_retry → trigram, on syntax
error / zero rows respectively) does **not** rescue this. `phrase_retry` wraps the whole query in
quotes, which is syntax-safe but requires the terms to appear **contiguously in that exact
order** — recall-narrower than the bareword AND, not broader. `trigram` is a substring fallback
with no query-grammar sensitivity, useful for punctuation-glued or unusual tokenization, but it
does not relax the "all terms present" requirement either (its query is also a quoted phrase).
Neither rung is a general recall improvement for long queries; both exist for syntax-error/zero
-row *robustness*, not for over-constraint relief.

## The FTS5-hostile character set `sanitize_query()` owns

`sanitize_query()` (in `literature-search.sh`) is the single source of truth for stripping/folding
characters that are FTS5 query-grammar syntax rather than word characters, for its one caller (a
free-text query string, never a hand-built FTS5 boolean expression). The full set it folds to
spaces, and why:

| Character(s) | FTS5 meaning if left in | Handling |
|---|---|---|
| mid-word `-` | column-exclusion / `NOT`-prefix | folded to space (word-boundary hyphens only — `foo-bar` → `foo bar`) |
| `:` | column-filter syntax | folded to space |
| `/` | no direct meaning, but paired with `:`/paths, folded for the same reason absolute paths are noise (see "Absolute file paths" below) | folded to space |
| `(` `)` | grouping, even word-attached and balanced | folded to space |
| `<` `>` | **not valid FTS5 syntax at all** — raises a hard `fts5: syntax error near "<"` the instant either character appears anywhere in a `MATCH` string | folded to space |
| unquoted `*` | prefix-wildcard operator | stripped (kept only inside `"quoted phrases"`) |
| unbalanced `"` | phrase-quote syntax | all quotes stripped if the count is odd |
| bare `AND`/`OR`/`NOT` (word-boundary, case-insensitive) | boolean operators | folded to space |
| ligatures (U+FB00-FB06) | not FTS5 syntax, but must match how the corpus was indexed | folded to their expanded ASCII form (`ﬁ`→`fi`, etc.), mirroring `literature-convert.sh`'s own fold |
| `'` | FTS5 does not accept SQL-escaped `''` in a query string | stripped |

The `<`/`>` row is the one that turns a poor-recall query into a hard, unrecoverable per-database
error rather than merely returning zero rows — verified directly:
`"hello <sec:representation> world"` raised `fts5: syntax error near "<"` before this set was
extended to include `<`/`>`; the fallback ladder (phrase_retry, trigram) does not rescue a syntax
error that occurs in `sanitize_query()`'s own output, since every rung re-sends the (still
hostile) sanitized string.

**Absolute file paths** are not a distinct character-class fix — a raw path like
`/home/user/project/pkg/module.ext` sanitizes (via the `/` fold) into a multi-word bareword AND
query (`home user project pkg module ext`), which is syntactically safe but has near-zero recall
value: it is exceedingly unlikely any indexed document literally contains "pkg" or a
project-specific directory name as a word. This is not a bug to fix in `sanitize_query()`; a path
fragment sanitizing to a harmless, low-recall no-op sub-query is the correct, safe outcome (see
"Known residual limitation" below for why term-selection heuristics that try to avoid this
proactively did not clearly help in practice).

## The multi-query envelope

`literature-search.sh --multi` (reading newline-separated raw queries from stdin) exists so a
caller with more than one short query to run pays the cost of **one** database open and **one**
fidelity-map load, not one per query. Its envelope is additive over the single-query envelope
(`{results, degraded, fallback_tier, query_error}`):

- **`total_matched`** (top-level integer): the de-duplicated (by `chunk_id`), post-quarantine
  count **before** the `limit` slice. This is the field a caller pins its own "how many did we
  really find" reporting to (e.g. `literature-briefing.sh`'s `seg_count`/`coverage_count`) —
  never `results | length`, which is post-slice and therefore an undercount once more than
  `limit` distinct chunks matched.
- **`matched_terms`** (per result row, integer): how many of the N sub-queries surfaced that
  chunk. Used as the **primary** sort key (descending), with `rank` as the ascending tiebreak
  *within* a `matched_terms` tier — see "Why matched_terms leads, not rank" below for the
  empirical reason this is not the other way around.
- **`corroborated_count`** (top-level integer): the same pre-limit-slice pool, restricted to rows
  with `matched_terms >= 2`. A caller uses this — never `total_matched` — as the sparse/rich
  signal specifically once the filtered term count exceeds `MULTI_TERM_MATCH_THRESHOLD` (defined
  in `literature-term-match.sh`). See "Why total_matched is not a reliable sparse signal" below.
- **`query_error`**: non-null only when **every** sub-query attempted against **every** database
  that exists on disk failed outright (zero rows and an operational error). One bad term among
  several good ones — or a term that fails against one database but succeeds against the other —
  must never poison the whole response; this mirrors the fallback ladder's own per-database error
  isolation, extended across sub-queries.

### Why `matched_terms` leads, not `rank`

BM25 scores from **independent** single-term `MATCH` queries are not on a comparable scale: a
generic word that happens to be the entirety of one short document's match can produce a more
extreme (better-looking) score than a genuinely on-topic multi-word hit, simply because there is
no other term diluting that document's relevance computation. Sorting a merged multi-query pool
by raw `rank` alone therefore lets corpus-wide-common words flood the top with single-term-only
noise. This was not a theoretical concern: verified directly against a real ~250MB corpus with a
full-length (100+-word), filler-word-heavy natural-language query, rank-primary sorting returned
zero topically relevant chunks in the top 10 despite a large, genuinely non-empty `total_matched`.
Promoting `matched_terms` to the primary sort key surfaced a canonical, directly relevant
textbook chunk at position 1 for the same query. Within a `matched_terms` tier, `rank` is still
the only signal used to order — this changes sort *priority*, it never recomputes a new relevance
score from scratch.

### Why `total_matched` is not a reliable sparse signal

The same OR-across-independent-single-term-queries structure that inflates recall can inflate
`total_matched` on a **genuinely off-topic** query too: once enough short, individually-common
English words are searched independently and merged, coincidental single-term hits scattered
across unrelated documents can add up to a large `total_matched` with no real topical overlap at
all. Verified directly: a control query with no subject-matter connection to a logic/philosophy
corpus (`"quantum chromodynamics particle accelerator experiment string theory"`) reported over
100 matched segments from `total_matched` alone. `corroborated_count` (rows with `matched_terms
>= 2`) correctly reported this as sparse, because a document mentioning two-or-more of those
specific words independently is a much rarer coincidence than mentioning any one of them. A
caller using the sparse signal for a multi-query result **must** use `corroborated_count` once
the filtered term count is large, never `total_matched` alone — the asymmetry (only above
`MULTI_TERM_MATCH_THRESHOLD`) mirrors the identical `>= 2 distinct hits` rule
`literature-coverage-delta.sh`/`literature-discover.sh` already apply to their own long-query
keyword passes, for the same reason.

## Known residual limitation

Selecting *which* terms to search when a query must be capped (`literature-briefing.sh`'s
`LITERATURE_GLOBAL_MAX_TERMS`) is not solved by this design. The implemented heuristic
(longest-string-first) is a poor proxy for "discriminating": in ordinary English prose, common
long words (adverbs, gerunds — "systematically", "understanding") routinely outrank short,
highly domain-specific nouns ("modal", "logic") by raw character count. Raising the cap
substantially does not reliably help either — a larger candidate pool creates more opportunities
for coincidental multi-term overlap among unrelated documents (e.g. many unrelated papers share
an "Overview" section that happens to use several different generic words from a long query).
Both directions were tested empirically against a real corpus with the fix's own original failing
case; neither produced a clear, general improvement over the implemented default, so the cap
stays at its tuned default and this limitation is recorded rather than silently engineered away.
A properly targeted fix (IDF-weighted term selection, cross-query score normalization, or a
caller-side switch to a much shorter representative query instead of a full raw description) is
future work, not attempted here.
