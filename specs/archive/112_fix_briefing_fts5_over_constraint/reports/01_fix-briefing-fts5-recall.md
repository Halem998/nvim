# Research Report: Task #112

- **Task**: 112 - Fix literature-briefing.sh --global FTS5 over-constraint returning zero segments
- **Started**: 2026-09-02T06:12:11Z
- **Completed**: 2026-09-02T06:20:00Z
- **Effort**: 6-10 hours (per task estimate; research confirms this is realistic — the fix spans
  two extensions and needs a new cross-search merge path plus regression coverage)
- **Dependencies**: Task 108 (completed; `literature-term-match.sh` unchanged in its public
  contract — see Findings)
- **Sources/Inputs**: Codebase (literature-briefing.sh, literature-search.sh,
  literature-term-match.sh, literature-coverage-delta.sh, literature-discover.sh,
  literature-briefing-invoke.sh, lit-stage4a-flow.md, test-lit-pipeline.sh), live `sqlite3`/FTS5
  empirical verification, specs/TODO.md task description, specs/108 summary
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed empirically, not just by re-reading the origin session's claim.** A
  live in-memory FTS5 test proves both halves of the defect: (1) FTS5 bareword queries AND all
  terms together, so an 18-term query against a table containing every one of the first 4 terms
  still returns zero rows; (2) a literal `<` character throws a hard `fts5: syntax error near
  "<"` on the primary rung.
- **`sanitize_query()` in `literature-search.sh` (lines 118-198) strips `AND`/`OR`/`NOT`,
  unbalanced quotes, `*`, mid-word hyphens, `:`, `/`, and `(`/`)` — but never touches `<` or
  `>`.** Confirmed by tracing the function and by running it directly: `"hello <sec:representation>
  world"` sanitizes to `"hello <sec representation> world"`, `<`/`>` untouched, still a syntax
  error on the primary bm25 rung.
- **The phrase_retry and trigram fallback rungs are syntax-safe against `<`/`>` (they wrap the
  whole string in quotes) but recall-dead for a long query**, because both require the query's
  words to appear as one contiguous sequence/substring — verified empirically: a 6-word quoted
  phrase found nothing even in a table containing all 6 words as separate tokens.
- **`literature-briefing.sh` does not source `literature-term-match.sh` at all** (grep-confirmed:
  zero `filter_terms`/`term_matches` references) and passes the raw `--global` query verbatim to
  `literature-search.sh` in one call (`literature-briefing.sh:399`,
  `bash "$SEARCH_SCRIPT" --project "$repo_name" "$query"`). There is no existing codebase pattern
  for merging multiple `literature-search.sh` invocations by rank — `literature-discover.sh`'s
  Tier 1 is a separate substring matcher against `index.json` title/keywords, not FTS5, so it is
  not directly reusable as a merge template; only `filter_terms`/`term_matches` themselves are
  reusable, not a merge strategy.
- **Every one of task 108's dependency-clearing claims holds**: `literature-term-match.sh`'s
  public contract (`to_lower`, `term_matches`, `filter_terms`, `STOP_WORDS`,
  `MULTI_TERM_MATCH_THRESHOLD`) is unchanged by task 108; only the internal fork-free
  implementation changed. Task 112 can proceed without any rebase concern on that file.
- **Recommended approach**: source `literature-term-match.sh` in `literature-briefing.sh`, run
  one `literature-search.sh` call per filtered term (or small term-groups) instead of one
  AND-all call, merge the returned envelopes by each result's existing `rank` field
  (`literature-search.sh` already computes and returns `rank` per result — do not recompute),
  dedupe by `chunk_id`, and separately hays-strip FTS5-hostile characters (`<`, `>`, and any
  other unhandled syntax character) inside `sanitize_query()` so any single term that still
  contains hostile punctuation degrades to a phrase_retry/trigram result for that one term
  instead of poisoning the whole request. Evaluate but do not default to changing
  `lit-stage4a-flow.md`'s caller — it is imported verbatim by 6 skill call sites.

## Context & Scope

Task 112 fixes global-corpus literature briefing recall: `literature-briefing.sh --global
"<query>"` currently forwards its query untouched to `literature-search.sh`, whose FTS5 MATCH
semantics AND every term together, so the moment a query is longer than a handful of words
(the actual caller passes the *entire task description*), the search can only match a document
containing every single term — a condition essentially unreachable for a real 15-30-word
description. A stray FTS5-syntax character (observed: `<`) additionally converts a poor-recall
query into a hard per-database syntax error.

This report verifies the defect claims already laid out in the task description/TODO.md entry
against the current source tree (BimodalLogic's claims re-verified here against this repo's
copy, which per the task's own note is byte-identical at task-creation time), adds direct
empirical proof via a live FTS5 database, and narrows the fix-direction options into one
concrete recommended design plus the tradeoffs the planner should weigh.

Scope explicitly includes: `literature-briefing.sh` (global-mode block, ~lines 390-490),
`literature-search.sh`'s `sanitize_query()` (~lines 118-198), and an evaluation (not a
committed decision) of whether `lit-stage4a-flow.md`'s two `--global "$description"` call sites
should pass a narrower query instead. Out of scope (per the task's own dependency/overlap
notes): task 113's SIGPIPE crash fix (disjoint code path, `--query` repo-mode parent-entry
extraction) and task 108 (already completed, verified non-overlapping in its final contract).

## Findings

### Codebase Patterns

- **`literature-briefing.sh` global mode** (`agent-system/extensions/literature/scripts/literature-briefing.sh:390-490`):
  a single `results_json=$(bash "$SEARCH_SCRIPT" --project "$repo_name" "$query" ...)` call
  (`:399`), shape-aware envelope parsing for both the legacy bare-array and the new
  `{results, degraded, fallback_tier, query_error}` object shape (`:403-423`), top-N truncation
  (`:427-429`), briefing-line rendering per segment including a `Read:` command and fidelity
  marker (`:431-463`), a degraded-tier banner keyed off `fallback_tier` (`:470-489`), and the
  shared machine-readable `<!-- lit-coverage mode=global seg_count=N sparse=... -->` marker plus
  `[SPARSE COVERAGE ...]` banner emitted from the single shared exit point (`:504-536`). The
  "no results" messaging already distinguishes a genuine zero-result from an FTS5 syntax error
  via `query_error` (`:567-587`) — this distinction was evidently added by a prior task (`#833`
  referenced in comments) and must be preserved, not re-invented.
- **`literature-search.sh`'s `sanitize_query()`** (`:118-198`): a Python heredoc that (1) folds
  ligatures, (2) strips bare `AND`/`OR`/`NOT` at word boundaries, (3) strips unquoted `*`, (4)
  balances/strips unbalanced `"`, (5) strips mid-word hyphens, `:`, `/`, `(`, `)`, (6) strips
  unbalanced parens (dead code today since parens are already unconditionally stripped), (7)
  strips `'`. **No handling exists for `<`, `>`,** or any other FTS5-meaningful character not
  already in this list (e.g. FTS5 also treats a leading `^` and bare `NEAR` specially, though
  those were not observed as failures in the origin session and are lower priority).
- **`do_search()`'s three-rung fallback ladder** (`:389-438`, inside the same file's second
  Python heredoc): Rung 0 = primary `bm25(chunks_fts, ...)` MATCH on the sanitized query
  (bareword AND semantics — this is the actual over-constraint mechanism); Rung 1 = on a
  `sqlite3.OperationalError` (syntax error) only, retry the *entire* sanitized string wrapped in
  one `"..."` phrase; Rung 2 = on zero rows from either prior rung, retry the same phrase as a
  trigram (substring) match. `rank` (BM25 score, lower/more negative = better) is already
  computed and attached to every result row (`:363`/`:378`, `AS rank`) and again exposed at the
  top level via `merged.sort(key=lambda r: r['rank'])` (`:486`) — this is the exact "already
  computed" field the fix should consume for cross-call merging rather than recomputing
  relevance.
- **`literature-briefing.sh` never sources `literature-term-match.sh`**: `grep -c
  'literature-term-match\|filter_terms' literature-briefing.sh` returns 0. Contrast
  `literature-coverage-delta.sh:145,147`, the established consumption pattern: `source
  "$SCRIPT_DIR/literature-term-match.sh"` then `mapfile -t FILTERED_TERMS < <(filter_terms
  "$query")`.
- **`filter_terms()` is a naive whitespace/stopword filter, not a tokenizer**
  (`literature-term-match.sh:76-99`): it splits on literal spaces (`IFS=' '`), lowercases, and
  drops terms under 3 characters or in `STOP_WORDS`. It does **not** strip punctuation — a raw
  token like `<sec:representation>` survives filtering as one long "term" (14+ chars, not a stop
  word). This matters for the fix: `filter_terms` alone is not sufficient FTS5 sanitization; the
  `sanitize_query()` gap for `<`/`>` (and similar) must still be closed independently, per the
  task's fix-direction #3, or a single filtered term can still poison one of the per-term
  sub-searches.
- **No existing merge-by-rank pattern across multiple `literature-search.sh` calls exists
  anywhere in the codebase.** `literature-discover.sh`'s Tier 1 (`:211-233`) reuses
  `filter_terms`/`term_matches`/`MULTI_TERM_MATCH_THRESHOLD` from the same shared helper, but
  it's a direct substring match against `index.json` title/keyword text, not an FTS5 query or a
  BM25 rank merge — it is a precedent for *term extraction*, not for *result merging*. The merge
  logic this task needs is new; there is nothing to "reuse" for that half beyond the `rank`
  field literature-search.sh already emits.
- **Task 108's completion cleared the file-overlap dependency as expected.** Its summary
  (`specs/108_eliminate_coverage_delta_per_entry_jq_spawns/summaries/01_coverage-delta-perf-fix-summary.md`)
  confirms `literature-term-match.sh`'s public contract (`filter_terms`, `STOP_WORDS`,
  `MULTI_TERM_MATCH_THRESHOLD`) is untouched — only `to_lower`/`term_matches`' internals became
  fork-free pure-bash. No rebase is needed for task 112's planned `filter_terms` reuse.
- **`lit-stage4a-flow.md`'s two `--global "$description"` call sites** (core extension,
  `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`): the `AUTONOMOUS_GLOBAL`
  branch and "The Four Options" option 1 (shared by `PROMPT_NEEDED` and `SPARSE_PROMPT_NEEDED`)
  both call `bash .claude/scripts/literature-briefing-invoke.sh --global "$description"` with
  the **full, unfiltered task description** — confirmed no intermediate preprocessing:
  `literature-briefing-invoke.sh` is a thin pass-through wrapper (`output="$(bash
  "$SCRIPT_DIR/literature-briefing.sh" "$@")"`) that only adds failure-visibility, never touches
  the query text.
- **The sparse-coverage marker contract that must survive the fix** is emitted once, at the
  shared exit point (`literature-briefing.sh:517-522,530`): `sparse="true"` fires when
  `coverage_count < LITERATURE_SPARSE_THRESHOLD` (global mode: `coverage_count = seg_count`, the
  *pre-top_n-slice* total match count) OR the skip-rate rule (repo-mode only). Any redesign that
  changes how `seg_count`/`coverage_count` is computed in global mode (e.g., summing distinct
  merged results across per-term searches) must keep this an honest total-match count, not an
  inflated per-term-call sum with duplicates counted multiple times — `lit-stage4a-flow.md`'s
  "Two-Checkpoint Sparse Detection" section (`:206-223`) `grep`s this exact marker to decide
  whether to re-prompt interactively.
- **Existing regression coverage is shallow for global mode.** `test-lit-pipeline.sh` (1,043
  lines) has a full Section H suite for the repo-mode coverage-delta guard, but its
  global-mode-related checks are limited to script existence/executability/`bash -n` syntax
  (`:168-188`) — no fixture exercises `--global` end-to-end against a real or mocked FTS5
  database. A fix here needs new test coverage, not just reliance on the existing suite staying
  green.

### External Resources

Not applicable — this is a pure codebase/SQLite-FTS5 semantics investigation; no external
library or API research was needed. FTS5 query-syntax behavior (bareword-AND default,
`<`/`>` as unhandled syntax tokens) was verified directly against the live `sqlite3` Python
module rather than from documentation, since the exact error text and boundary behavior needed
confirming against this environment's SQLite build.

### Empirical Verification (this session)

Ran three isolated in-memory FTS5 tests (`python3` + `sqlite3`, porter+unicode61 tokenizer,
single row `"hello world foo bar bar\z"`-style content):

1. `MATCH "hello world"` -> 1 row (control, confirms basic behavior).
2. `MATCH "<sec:representation>"` -> `sqlite3.OperationalError: fts5: syntax error near "<"`
   (confirms fix-direction #3's premise directly, not just by citing the origin session).
3. `MATCH "<18-word free-text query containing only 4 of the row's actual words>"` -> 0 rows
   despite the row containing 4 of those exact words (confirms the AND-all-terms recall defect
   independent of any syntax error — this is the deeper of the two problems and the reason
   fix-direction #3 alone, without #1/#2, would not be sufficient).
4. Ran the actual `sanitize_query()` function (sourced verbatim from the file) against
   `"hello <sec:representation> world AND OR foo/bar (baz)"` -> output
   `"hello <sec representation> world foo bar baz"` — confirms AND/OR/colon/slash/parens are
   stripped as documented, but `<`/`>` pass through untouched.
5. Ran the phrase_retry shape (`'"' + sanitized + '"'`) against a row containing all 6 words as
   separate tokens (not as a contiguous phrase) -> 0 rows, confirming the phrase-retry/trigram
   fallback rungs are recall-dead for a long query even once the syntax error is worked around —
   this directly explains the origin session's observation that "a hand-written 14-word
   plain-language retry ALSO returned 0."

### Recommendations

1. **Sanitize FTS5-hostile characters in `sanitize_query()`** (`literature-search.sh:118-198`):
   add `<` and `>` to the character-stripping section alongside the existing `:`/`/`/`(`/`)`
   handling (fold to space, consistent with the existing style). This is the smallest, most
   surgical piece and should land regardless of which merge strategy is chosen for point 2 —
   it also benefits every other `literature-search.sh` caller (repo-mode `--query`,
   interactive `--read` follow-ups typed by a user, etc.), not just the `--global` path.
2. **Replace the single AND-all-terms `--global` call with multiple short searches merged by
   existing `rank`.** Concretely, in `literature-briefing.sh`'s global-mode block: source
   `literature-term-match.sh`, compute `mapfile -t FILTERED_TERMS < <(filter_terms "$query")`
   (mirroring `literature-coverage-delta.sh:145,147` exactly, per the task's explicit
   instruction not to write a second stop-word filter), then issue one `literature-search.sh
   --project "$repo_name" "<term-or-small-group>"` call per filtered term (or per small
   fixed-size group, e.g. 2-3 terms, to keep the bareword-AND semantics useful rather than
   defeated entirely) and merge the returned `results` arrays by each row's own `rank` field
   (ascending — more negative is better), de-duplicating on `chunk_id` (keep the best-ranked
   occurrence when a chunk surfaces from more than one per-term search) before applying the
   existing `top_n` slice. This directly satisfies the task's stated preference (short merged
   searches over one AND-all query, consuming the existing `rank` rather than recomputing
   relevance) while reusing the existing envelope-parsing and degraded/fallback-tier logic
   per sub-call.
3. **Aggregate `degraded`/`fallback_tier`/`query_error` conservatively across sub-calls**: the
   overall `degraded` banner should reflect whether the *retained, top-N* results include any
   non-bm25-tier row (mirrors the existing single-call logic in
   `literature-search.sh:493-508`, just applied to the merged set); `query_error` should only
   surface as a message when **every** sub-call failed (all filtered terms returned an error),
   not when one hostile or rare term's sub-search failed while others succeeded — this preserves
   the recent "distinguish genuine zero-result from FTS5 syntax error" UX
   (`literature-briefing.sh:567-587`) without regressing it to alarm on a single bad term inside
   an otherwise-successful multi-term search.
4. **Preserve `coverage_count`/`seg_count` as an honest total-match count for the sparse
   marker.** Use the de-duplicated merged-result count (post-merge, pre-`top_n`-slice) as
   `seg_count`, matching the existing semantic ("pre-top_n-slice total match count") — do not
   sum raw per-term-call totals (which would double/triple count a single chunk matched by
   several terms and falsely suppress `sparse=true`).
5. **Evaluate, but do not default to, changing `lit-stage4a-flow.md`'s callers to pass a
   narrower query** (task title + filtered terms) instead of the raw description. Because this
   file is imported verbatim by 6 skill call sites (`skill-researcher`, `skill-planner`,
   `skill-implementer`, and their `-hard` variants), a change here has a wide blast radius for a
   comparatively small additional benefit once recommendations 1-2 land in the script itself
   (fixing the script fixes recall for every caller, including any future direct
   `literature-briefing.sh --global` invocation outside the Stage 4a flow). Recommend leaving
   this caller unchanged in the initial fix and revisiting only if post-fix verification shows
   the per-term-merge approach still underperforms against a full, unfiltered task description
   (e.g., because `filter_terms`'s naive whitespace splitter leaves too much noise in individual
   terms). This should be an explicit planning decision with a documented reason either way, not
   a default.
6. **Add global-mode FTS5 regression coverage to `test-lit-pipeline.sh`** (or a new dedicated
   `--runtime` section, following the existing Section H convention): a fixture with a small
   real/mocked `.literature.db`, one long multi-word query (mirroring the failing task-503
   shape, including a `<...>`-bracketed token) that must now return a non-empty result, and a
   negative-control short query verifying `sparse=true`/banner behavior is unaffected for a
   genuinely sparse topic. This did not exist before and is necessary to make the fix's
   correctness durable rather than one-off-verified.

## Decisions

- **Reuse `filter_terms` from `literature-term-match.sh`** rather than writing a second
  stop-word filter — confirmed as both the task's explicit instruction and the established
  codebase convention (`literature-coverage-delta.sh`'s consumption pattern).
- **Merge multiple per-term (or small-group) `literature-search.sh` calls by the existing `rank`
  field** rather than invent a new relevance-scoring mechanism — `rank` is already computed and
  returned by `do_search()`, so recomputing it would be redundant per the task's own guidance.
- **Extend `sanitize_query()` to strip `<`/`>`** as an independent, always-beneficial fix,
  regardless of the merge-strategy outcome — confirmed both characters currently pass through
  unsanitized and both throw hard FTS5 syntax errors.
- **Do not change `lit-stage4a-flow.md`'s callers in this pass** — recommend fixing the script
  first (lower blast radius, benefits every caller) and revisiting the caller-side change only
  if post-fix verification shows it is still needed; this is a recommendation for the planner to
  ratify or override with reasons, not a closed decision.

## Risks & Mitigations

- **Risk**: merging results from many small per-term searches could reintroduce noise (a query
  with 20+ filtered terms means 20+ separate searches, each potentially surfacing marginally
  relevant chunks that only match one rare term). **Mitigation**: bound per-term-search
  contribution by requiring the same "accept-on-first-hit vs. `>=2`-hits-when-above-threshold"
  asymmetry `literature-coverage-delta.sh`/`literature-discover.sh` already use via
  `MULTI_TERM_MATCH_THRESHOLD`, adapted to a rank-merge context (e.g., only retain a chunk that
  no single term alone would have surfaced above the fold), or simply rely on the existing
  `top_n` slice plus BM25's own per-term-result ranking to keep marginal singleton-term matches
  out of the default top-8. This needs to be validated against the origin query
  (111 documents / 131 segments known-reachable) during implementation, not assumed correct from
  design alone.
- **Risk**: N separate `literature-search.sh` invocations per `--global` briefing (each spawning
  its own `python3`/`sqlite3` process) is materially slower than the current single call,
  especially for long task descriptions with many filtered terms. **Mitigation**: this is a
  legitimate tradeoff to flag to the planner (task 108's motivation was exactly this kind of
  per-call fork/spawn overhead) — options include capping the number of per-term searches
  (e.g., top-K terms by length/rarity rather than all filtered terms), grouping terms into a
  fixed number of small AND-queries instead of one query per term, or a longer-term refactor
  that pushes the per-term loop into a single Python process (mirroring how
  `literature-coverage-delta.sh` and `literature-search.sh` internals already batch work to
  avoid repeated `jq`/shell-fork costs). Do not treat this as pure research scope — but the
  planner should explicitly budget for a performance check similar to task 108's before/after
  timing table, not assume it away.
- **Risk**: changing `seg_count`/`coverage_count` semantics for global mode could silently break
  the sparse-coverage re-prompt contract that `lit-stage4a-flow.md` depends on via the
  `<!-- lit-coverage ... -->` marker grep. **Mitigation**: recommendation 4 above pins the
  definition explicitly (de-duplicated merged-result count, pre-`top_n`); the implementation
  plan should include an explicit before/after comparison of the marker line's fields for at
  least one genuinely-sparse and one genuinely-rich test query, not just a "does it look right"
  spot check.
- **Risk**: a single filtered term still containing FTS5-hostile characters `sanitize_query()`
  doesn't yet handle (something beyond `<`/`>` not observed in the origin session) could still
  throw inside one per-term sub-call. **Mitigation**: recommendation 3's per-sub-call error
  isolation (aggregate `query_error` only when *all* sub-calls fail) already contains this — a
  single bad term degrading to its own phrase_retry/trigram/failure without poisoning the whole
  request is the entire point of moving from one big query to many small ones.

## Context Extension Recommendations

- **Topic**: FTS5 query-construction conventions for this codebase (sanitization rules,
  bareword-AND semantics, fallback-ladder behavior).
- **Gap**: there is no dedicated context doc explaining `literature-search.sh`'s
  `sanitize_query()`/fallback-ladder design as a reusable reference — the rationale currently
  lives only as inline comments in the script itself, and a future contributor adding a new FTS5
  call site (or a new sanitization rule) has to re-derive the AND-all-terms/`<`-syntax-error
  gotchas from scratch, as this task's origin session did.
- **Recommendation**: after this task's fix lands, consider adding a short
  `context/project/literature/domain/fts5-query-semantics.md` (or extending an existing
  literature-domain doc) documenting: the bareword-AND default and why long free-text queries
  need per-term/grouped search rather than one big MATCH; the full FTS5-hostile-character list
  `sanitize_query()` handles (and now `<`/`>` too); and the three-rung fallback ladder's actual
  recall behavior (phrase_retry/trigram are syntax-safe but recall-narrow, not general-purpose
  recall improvements). This is a documentation nice-to-have, not a blocker for this task.

## Appendix

- Files read in full or in relevant part: `agent-system/extensions/literature/scripts/literature-briefing.sh`,
  `agent-system/extensions/literature/scripts/literature-search.sh`,
  `agent-system/extensions/literature/scripts/literature-term-match.sh`,
  `agent-system/extensions/literature/scripts/literature-coverage-delta.sh`,
  `agent-system/extensions/literature/scripts/literature-discover.sh` (grep-scoped),
  `agent-system/extensions/literature/scripts/literature-briefing-invoke.sh`,
  `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`,
  `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` (grep-scoped),
  `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/summaries/01_coverage-delta-perf-fix-summary.md`,
  `specs/TODO.md` (task 112 and 113 entries, for cross-task boundary confirmation).
- Empirical verification commands: ad hoc `python3 -c` scripts against an in-memory
  `sqlite3` FTS5 table (porter+unicode61 tokenizer) run directly in this session (not persisted
  as files); `sanitize_query()` sourced and invoked directly via `bash -c`.
- No web search was performed — this is a pure internal-codebase/SQLite-behavior investigation.
