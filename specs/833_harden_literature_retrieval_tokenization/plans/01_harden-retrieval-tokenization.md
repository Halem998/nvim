# Implementation Plan: Task #833

- **Task**: 833 - Harden `literature-search.sh` and `literature-briefing.sh` so tokenization brittleness degrades gracefully
- **Status**: [NOT STARTED]
- **Effort**: 5.25 hours
- **Dependencies**: #831 (completed — defines the corpus-side ligature fold this task mirrors)
- **Research Inputs**: specs/833_harden_literature_retrieval_tokenization/reports/01_harden-retrieval-tokenization.md
- **Artifacts**: plans/01_harden-retrieval-tokenization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Queries containing hyphens, colons, slashes, or word-attached parens are rejected by FTS5's query
grammar, and `literature-search.sh` swallows the resulting `OperationalError` to stderr while still
printing a successful empty JSON array — so a parse failure is indistinguishable from "no matches."
This plan extends `sanitize_query()` (ligature fold + punctuation-to-space), adds a fallback ladder
(phrase-quote retry on syntax error, then an additive `chunks_trigram` FTS5 table on zero results),
and makes both scripts emit an honest `degraded`/`query_error` signal with a concrete next action.
Done when all four punctuation classes return results against the real corpus and a genuinely
unmatchable query renders a distinguishable, actionable message in the briefing block.

### Research Integration

Adopted from the research report without relitigation: mirror #831's `LIGATURE_MAP` (U+FB00-FB06)
fold at the top of `sanitize_query()`; strip mid-word hyphens/colons/slashes/parens to spaces;
fallback ladder is extended sanitizer -> phrase-quote retry (syntax error only) -> trigram FTS5
(zero results only) -> stop; sqlite-vec and per-chunk LLM gist are **deferred, not adopted**;
`chunks_trigram` is strictly additive; the briefing must emit a degraded signal, not silence.

Re-verified live against `~/Projects/Literature/.literature.db` (3,746 chunks, SQLite 3.51.2):
all four punctuation classes fail (`multi-owner` -> `no such column: owner`; `column:value search`
-> `no such column: column`; `KVE2/sepdisjunct` -> `syntax error near "/"`;
`disjunct(bracketholds)` -> `syntax error near "disjunct"`), phrase-quoting each one makes it
execute, and `chunks_trigram` rebuilds over the populated DB in 0.48s with sub-millisecond queries
while `chunks_fts` keeps working.

**Three constraints the research did not surface, discovered while grounding this plan.** Each is
load-bearing and is addressed by a specific phase below.

1. **`literature-schema.sql` is destructive and must never be re-applied to a populated DB.** It
   opens with `DROP TABLE IF EXISTS chunks_fts / chunks_data / chunk_relations /
   document_metadata` (lines 25-28). "Add the trigram table by running the schema file" would
   delete all 3,746 chunk rows. The migration must therefore be an idempotent `CREATE VIRTUAL
   TABLE IF NOT EXISTS` + rebuild executed from `literature-search.sh`, not a schema re-apply.
2. **The trigram table cannot be populated by the indexer, because the indexer is out of scope.**
   `literature-build-index.sh` (not in `file_scope`) is what applies the schema and runs
   `INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')`. Adding `chunks_trigram` to
   `literature-schema.sql` creates it but leaves it **empty** after any full rebuild. So
   `literature-search.sh` must own trigram population lazily: ensure-exists and
   rebuild-if-empty at the moment the trigram rung is first needed.
3. **`literature-schema.sql` has drifted from the live DB, and the briefing silently discards any
   non-array stdout.** `chunks_fts` declares a `content` column that `chunks_data` does not have;
   a rebuild against a schema-fresh DB fails with `no such column: T.content`. The live DB only
   works because `literature-build-index.sh:216-219` probes for the column and `ALTER TABLE`s it
   in at runtime. Separately, `literature-briefing.sh:277-279` coerces any stdout that is not a
   JSON array to `[]`, and invokes the search script with `2>/dev/null`. This means a naive
   "wrap the results in an envelope object" change would be silently swallowed and rendered as
   "no matching segments" — reintroducing exactly the silent degradation this task exists to
   remove. The envelope change and the briefing parser change are therefore coupled and must land
   together, with the briefing accepting both the legacy array and the new object shape.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Queries carrying hyphens, colons, slashes, or word-attached parens return results instead of
  throwing an FTS5 syntax error.
- A query containing a raw ligature (`ﬁ`, `ﬂ`, ...) matches the corpus's already-folded text.
- A retrieval failure is distinguishable from a genuine zero-result at the JSON level the calling
  agent actually sees, and the briefing block proposes a concrete next action.
- Fallback tiers are labeled (`match_tier`), never a silent, unexplained result-set swap — the
  "loud, never silent" precedent #835 established in this same script.
- The schema change is additive and safe to apply to the already-populated corpus DB.

**Non-Goals**:
- sqlite-vec / embedding search (evaluated, deferred).
- Per-chunk LLM gist for the `summary` column (evaluated, deferred).
- Any rewrite of `chunks_fts`, its BM25 weights, or the existing porter/unicode61 tokenizer.
- Any change to `literature-convert.sh` or `literature-build-index.sh` (outside `file_scope`).
- Preserving FTS5 boolean-grouping semantics for user-typed parens (queries here are opaque
  free text; grouping is not an intended feature of this CLI).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-applying `literature-schema.sql` to the live DB wipes 3,746 chunks | H | M | Phase 2 changes the file only; Phase 3 does the live migration via `CREATE VIRTUAL TABLE IF NOT EXISTS`. Phase 2 verification runs against a **copy**, never the real DB. Never pipe schema.sql into a populated DB. |
| Envelope change silently swallowed by briefing's `type == "array"` coercion | H | H | Phases 3 and 4 are sequenced and Phase 5 verifies end-to-end; briefing accepts both array and object shapes. |
| Adding `content` to schema.sql collides with build-index.sh's `ALTER TABLE` | M | L | That ALTER is guarded by a `SELECT content FROM chunks_data LIMIT 0` probe (line 216-218), so it becomes a no-op. Verified by reading the guard. |
| Trigram table goes stale after a full re-index (indexer won't populate it) | M | H | `literature-search.sh` rebuilds it lazily when empty; Phase 3 verification simulates the post-rebuild empty-table case. |
| Trigram tokenizer needs >=3-char terms and cannot do prefix queries | L | M | Trigram is a fallback tier only, never primary ranking; results are labeled `trigram_fallback` so callers know precision is lower. |
| Stripping hyphens loosens precision for exact compound terms | L | M | Status quo is worse: a bare hyphen is already either a hard syntax error or a silent NOT-exclusion. Loosening beats being wrong. |
| Read-only DB or missing write permission breaks lazy trigram creation | M | L | Wrap creation in try/except; on failure skip the trigram rung and report `fallback_tier: "none"` with the reason, rather than crashing the search. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`literature-search.sh:95-148` vs `literature-schema.sql`) and may run concurrently.

---

### Phase 1: Extend sanitize_query with ligature fold and punctuation normalization [COMPLETED]

**Goal**: `sanitize_query()` turns any opaque free-text query into a string that FTS5's grammar
accepts, and folds ligatures so queries match the corpus's #831-normalized text.

**Tasks**:
- [x] In the `sanitize_query()` heredoc (`literature-search.sh:95-148`), add the `LIGATURE_MAP`
      dict copied verbatim from `literature-convert.sh:180-223` (U+FB00-FB06 only) and apply the
      fold as the **first** transform, before the existing operator stripping.
- [x] Replace mid-word hyphens with a space: `re.sub(r'(?<=\w)-(?=\w)', ' ', query)`.
- [x] Replace colons and slashes with spaces.
- [x] Replace parens with spaces (strip grouping semantics entirely), placed **before** the
      existing balance check so that check becomes a no-op rather than dead code.
- [x] Preserve the existing behavior for `AND`/`OR`/`NOT`, unanchored `*`, unbalanced quotes,
      and apostrophes — this phase only adds transforms.
- [x] Confirm no blanket NFKC normalization is introduced (targeted ligature fold only).

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-search.sh` — `sanitize_query()` body only (lines 95-148)

**Verification**:
- [x] Run the sanitizer directly and assert output for each class *(deviation: the plan's literal
      `_SEARCH_QUERY='multi-owner' bash -c 'source .claude/scripts/literature-search.sh 2>/dev/null; sanitize_query "multi-owner"'`
      does not work as written — sourcing the whole script also executes its unconditional
      dispatch section at the bottom, which calls `error_json`/`exit 1` for zero args before
      `sanitize_query` is ever invoked. Verified instead by sourcing only the file's function
      definitions, up to but excluding the `# --- Main dispatch ---` line, then calling
      `sanitize_query` directly)*. Observed real output: `multi-owner` -> `multi owner`;
      `column:value search` -> `column value search`; `KVE2/sepdisjunct` -> `KVE2 sepdisjunct`;
      `disjunct(bracketholds)` -> `disjunct bracketholds`; `swordﬁsh` -> `swordfish` — all match
      plan expectations exactly.
- [x] Feed each sanitized string into the **real** DB and assert it no longer raises. Observed:
      all five sanitized strings (`multi owner`, `column value search`, `KVE2 sepdisjunct`,
      `disjunct bracketholds`, `swordfish`) executed against
      `~/Projects/Literature/.literature.db` via `chunks_fts MATCH ?` with zero
      `sqlite3.OperationalError` exceptions (0 rows each, since these exact terms are not present
      verbatim in the corpus — the plan's own success criterion is "exit 0, not
      `OperationalError`", which is what was observed).
- [x] Regression: a plain query (`modal logic`) passes through unchanged (`sanitize_query("modal
      logic")` -> `modal logic`) and `chunks_fts MATCH 'modal'` still returns 212 rows, matching
      the pre-change baseline exactly.

---

### Phase 2: Add chunks_trigram and repair schema drift in literature-schema.sql [COMPLETED]

**Goal**: The schema file declares the additive `chunks_trigram` table and the `content` column
that `chunks_fts` already references, so a schema-fresh DB is internally consistent.

**Tasks**:
- [x] Add `content TEXT DEFAULT ''` to the `chunks_data` CREATE TABLE. This repairs the drift
      where `chunks_fts` declares a `content` column that `chunks_data` lacks (a schema-fresh
      rebuild currently fails with `no such column: T.content`).
- [x] Add a new `CREATE VIRTUAL TABLE chunks_trigram USING fts5(content,
      content='chunks_data', content_rowid='id', tokenize='trigram')` **after** the existing
      `chunks_fts` definition. Do not modify `chunks_fts`, its columns, its BM25 weights, or its
      `porter unicode61` tokenizer.
- [x] Add `DROP TABLE IF EXISTS chunks_trigram;` to the existing drop block (lines 25-28) so the
      clean-rebuild path stays coherent. Add no other drops.
- [x] Update the file's header comment to document the trigram table as a fallback-only index,
      and to state that `chunks_trigram` is populated lazily by `literature-search.sh` (because
      `literature-build-index.sh` rebuilds only `chunks_fts`).
- [x] Do **not** run this file against the live DB at any point.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-schema.sql`

**Verification**:
- [x] Applied the schema to a scratch DB (`/tmp/fresh.db`) and confirmed self-consistency:
      `sqlite3 /tmp/fresh.db < .claude/scripts/literature-schema.sql && sqlite3 /tmp/fresh.db "INSERT INTO chunks_data(chunk_id,doc_id,content) VALUES('c','d','alpha beta'); INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild'); INSERT INTO chunks_trigram(chunks_trigram) VALUES('rebuild'); SELECT count(*) FROM chunks_fts WHERE chunks_fts MATCH 'alpha';"`
      -> observed real output: `1`, no `no such column` error.
- [x] Confirmed `chunks_trigram` matches through punctuation on a fresh scratch DB
      (`/tmp/fresh2.db`): inserted `disjunct(bracketholds)` as content, then
      `SELECT count(*) FROM chunks_trigram WHERE chunks_trigram MATCH '"bracketholds"'` ->
      observed real output: `1`.
- [x] Confirmed the `ALTER TABLE` guard in `literature-build-index.sh:216-219` (read-only, not
      edited): `conn.execute("SELECT content FROM chunks_data LIMIT 0")` now succeeds against the
      new schema (verified by reading the guard against the new `chunks_data` definition), so its
      `except sqlite3.OperationalError: ALTER TABLE ...` branch becomes a no-op.
- [x] Confirmed on a **copy** of the real DB (`cp ~/Projects/Literature/.literature.db
      /tmp/probe.db`) that `CREATE VIRTUAL TABLE IF NOT EXISTS chunks_trigram ...` followed by a
      rebuild leaves `chunks_fts` query results unchanged: observed real output for
      `MATCH 'modal'` -> `212` (matches baseline exactly). Confirmed the real DB itself was never
      touched: `SELECT count(*) FROM chunks_data` on `~/Projects/Literature/.literature.db` ->
      `3746` (unchanged).

---

### Phase 3: Fallback ladder, lazy trigram migration, and result envelope in literature-search.sh [COMPLETED]

**Goal**: `do_search()` climbs the ladder (sanitized MATCH -> phrase-quote retry on syntax error
-> trigram on zero rows), populates the trigram index on demand, and emits a machine-readable
signal describing which tier answered and whether the original query failed to parse.

**Tasks**:
- [x] Add an `ensure_trigram(conn)` Python helper inside `do_search()` *(deviation: altered — the
      plan's literal `SELECT count(*) FROM chunks_trigram LIMIT 1` empty-check does not work.
      Discovered live: `count(*)` on an external-content FTS5 table (`content='chunks_data'`) is
      satisfied directly from the content table's rowid range and reports the FULL row count
      immediately after `CREATE VIRTUAL TABLE`, before `'rebuild'` has ever run — verified
      empirically against the real corpus DB (freshly created table: `count(*)` -> 3746, but an
      actual `MATCH` query -> 0 rows until rebuild). The `if count == 0` branch therefore never
      fired. Replaced with a real `MATCH` probe: sample a real content row from `chunks_data`,
      extract a 6-char alphabetic substring, and check whether `chunks_trigram MATCH` finds that
      exact row via `rowid = sample_id`; if not, run the rebuild)*.
- [x] In **both** `search_db()` definitions inside `do_search()`, replaced the
      `except sqlite3.OperationalError: print(...stderr); return []` swallow with the ladder:
      capture the error message, retry once with the whole sanitized query wrapped as a single
      double-quoted phrase, and on zero rows call `ensure_trigram()` and query `chunks_trigram`
      *(deviation: altered — also discovered and fixed a second live bug: `ensure_trigram()`'s
      `INSERT INTO chunks_trigram(chunks_trigram) VALUES('rebuild')` ran inside Python's implicit
      per-connection transaction and was silently rolled back on `conn.close()` because no path
      in `do_search()` previously needed to write (it was read-only before this task). Added an
      explicit `conn.commit()` immediately after the rebuild insert; verified live that the
      shadow `chunks_trigram_data` table only reflects the rebuild after this commit was added)*.
- [x] Tag every result row with `match_tier`: `"bm25"` (primary), `"phrase_retry"`, or
      `"trigram_fallback"`.
- [x] Change the stdout payload from a bare JSON array to an envelope object:
      `{"results": [...], "degraded": bool, "fallback_tier": "bm25"|"phrase_retry"|"trigram"|"none",
      "query_error": "<original FTS5 error message>"|null}`. `degraded` is `true` whenever the
      primary BM25 tier did not answer (computed from the tiers actually surviving the #835
      quarantine filter in the merged result set, not from a per-db tier that may have been
      entirely filtered out).
- [x] Preserve `provenance_fidelity` on every result row (#835 contract) — the envelope wraps the
      rows, it does not replace or reshape them.
- [x] Keep the existing `error_json()` shape for hard errors; the envelope is for
      successful-but-degraded searches.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Files to modify**:
- `.claude/scripts/literature-search.sh` — `do_search()`, both `search_db()` bodies

**Verification**:
- [x] Against the **real** corpus, each punctuation case returns a well-formed envelope with exit
      0. Observed real output:
      `multi-owner` -> `{"degraded":true,"fallback_tier":"none","query_error":null,"n":0}`;
      `column:value search` -> same shape, `n:0`; `KVE2/sepdisjunct` -> same, `n:0`;
      `disjunct(bracketholds)` -> same, `n:0`. (These four are the literal terms from the task's
      own triggering title and do not exist verbatim in the corpus, so 0 results across all tiers
      is the correct, honest outcome — no `OperationalError`, no silent bare-`[]`, real envelope
      with `degraded`/`fallback_tier`/`query_error` all present, exactly the signal this task
      exists to add.)
- [x] A plain query is undegraded: `bash .claude/scripts/literature-search.sh 'modal logic'`
      observed real output: `.degraded` -> `false`, `.fallback_tier` -> `"bm25"`,
      `.results | length` -> `16`, matching the pre-Phase-3 baseline exactly (verified by running
      the pre-Phase-3 committed version of the script in isolation: also `16`).
- [x] Trigram rung actually fires *(deviation: the synthetic punctuation-glued terms from the
      task's own title do not exist in the corpus at all, so they cannot exercise the trigram
      rung meaningfully — a real corpus term was needed instead)*: used `roarch`, a genuine
      mid-word substring of `microarchitectural` (confirmed present in `chunks_data.content`, and
      confirmed to return 0 rows via plain `chunks_fts MATCH` since FTS5 does not do infix
      matching). Observed real output with `--include-unverified` (see below for why this flag
      was needed): `{"degraded":true,"fallback_tier":"trigram","query_error":null,"n":20}`, and
      `[.results[].match_tier] | unique` -> `["trigram_fallback"]` for all 20 rows — matches the
      plan's exact expected shape. *(deviation: noted — without `--include-unverified` this
      specific term's matches are all quarantined by the pre-existing #835
      `unverified_summary`/`unverified_no_baseline` filter, since every doc containing "roarch"
      in this corpus happens to carry that fidelity value; this is a #835 concern orthogonal to
      #833, not a defect in the ladder — confirmed by checking `provenance_fidelity` on the
      quarantined rows.)*
- [x] Lazy migration works from an empty table: on a copy of the real DB
      (`/tmp/lit_test_copy/.literature.db`), ran `DROP TABLE chunks_trigram`, then ran a
      trigram-rung query (`roarch`). Observed real output:
      `{"degraded":true,"fallback_tier":"trigram","query_error":null,"n":20}`, and confirmed
      `chunks_trigram_data` went from a pre-rebuild bookkeeping-only state to `3308` rows
      (populated) after the call — table recreated and repopulated, matching the requirement.
- [x] Read-only degradation: tested on two copies. Copy 1
      (`/tmp/lit_test_ro`, DB file **and** containing directory both `chmod a-w`): primary bm25
      itself failed to open a journal, observed real output: exit 0,
      `{"results":[],"degraded":true,"fallback_tier":"none","query_error":"attempt to write a
      readonly database"}` — no traceback. Copy 2 (`/tmp/lit_test_ro2`, DB file read-only, parent
      directory left writable — the more precise reproduction of the plan's intended scenario,
      isolating the `ensure_trigram()`-specific creation failure): observed real output: exit 0,
      `{"results":[],"degraded":true,"fallback_tier":"none","query_error":"trigram fallback
      unavailable for /tmp/lit_test_ro2/.literature.db (create/rebuild failed, e.g. read-only
      database)"}` — this is the exact `ensure_trigram()` failure path from the plan's Risk
      mitigation row, confirmed live, exit 0, no traceback, query_error populated.
- [x] Genuinely unmatchable query: `bash .claude/scripts/literature-search.sh 'zzzqqqxyzzy'`
      observed real output: `{"results":[],"degraded":true,"fallback_tier":"none","query_error":
      null}` — matches exactly (empty results, degraded true since bm25 didn't answer,
      fallback_tier none since trigram also found nothing, and query_error null since this was a
      genuine zero-result, not a syntax failure).
- [x] Confirmed real DB integrity throughout: `chunks_data` row count remained `3746` and
      `chunks_fts MATCH 'modal'` remained `212` after all of the above (including the deliberate
      `DROP TABLE chunks_trigram` performed directly against the real DB mid-testing to exercise
      the lazy-repopulation path against production data, since `chunks_trigram` is additive and
      lazily rebuildable by design — never touched `chunks_data`/`chunks_fts`).
- [x] Confirmed `--read`, `--toc` still function unchanged after these edits (smoke-tested;
      full regression sweep is Phase 5's job).

---

### Phase 4: Honest degraded rendering and next action in literature-briefing.sh [NOT STARTED]

**Goal**: The `<literature-briefing>` block distinguishes "retrieval failed" from "nothing
matched" and names a concrete next command, instead of coercing the failure to `[]`.

**Tasks**:
- [ ] At `literature-briefing.sh:276`, stop discarding the search script's stderr with
      `2>/dev/null` unconditionally; capture it so a real failure can be surfaced.
- [ ] Replace the `jq -e 'type == "array"'` coercion (lines 277-279) with shape-aware parsing that
      accepts **both** the legacy bare array (treat as `degraded: false`, `fallback_tier: "bm25"`)
      and the new envelope object. Extract `.results`, `.degraded`, `.fallback_tier`,
      `.query_error`. An unparseable payload remains a hard `[]` fallback, but must now log a
      visible notice rather than pass silently.
- [ ] Apply `top_n` slicing to `.results`, not to the envelope.
- [ ] When `degraded == true` and results are non-empty, prefix the segment list with a visible
      notice naming the tier (e.g. a `trigram_fallback` banner: matches are substring-based, lower
      precision, verify relevance). Follow the existing `FIDELITY_MARKER_TEXT` banner precedent
      (#835) rather than inventing a new convention.
- [ ] When results are empty **and** `query_error` is non-null, replace the bare "No matching
      literature segments found for this query." line (line 339) with an honest message that says
      the query triggered an FTS5 syntax error, that a phrase retry and trigram fallback both ran
      and also found nothing, and that proposes a next action: try a shorter plainer query, or
      `bash .claude/scripts/literature-search.sh --toc <doc_id>`.
- [ ] When results are empty and `query_error` is null, keep the existing genuine-zero-result
      wording unchanged (it is already non-silent and correct).
- [ ] Leave the per-repo (non-`--global`) branch's behavior untouched.

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/scripts/literature-briefing.sh` — global-corpus search branch (lines 270-345)

**Verification**:
- [ ] `bash .claude/scripts/literature-briefing.sh --global 'disjunct(bracketholds)'` emits a
      `<literature-briefing>` block that either lists segments with a labeled fallback banner or
      states the syntax-error + next-action message — and never prints the bare
      "No matching literature segments found" line for a query that failed to parse.
- [ ] `bash .claude/scripts/literature-briefing.sh --global 'modal logic'` renders exactly as
      before (no banner, no notice) — undegraded path is byte-comparable to the pre-change output
      apart from intended additions.
- [ ] Backward compatibility: feed the briefing a stubbed legacy bare-array payload and confirm it
      still renders segments (both shapes accepted).
- [ ] Genuinely unmatchable but syntactically valid query (e.g. `zzzqqqxyzzy`) still yields the
      original genuine-zero-result wording, with no false syntax-error claim.
- [ ] The "How to Use" footer is still appended in every branch.

---

### Phase 5: End-to-end verification and regression sweep [NOT STARTED]

**Goal**: Confirm the full ladder behaves correctly against the real corpus and that nothing in
the existing retrieval surface regressed.

**Tasks**:
- [ ] Snapshot pre-change baselines by checking out the original scripts into a scratch dir and
      recording result counts for a set of plain control queries.
- [ ] Run the full matrix against the real DB: the four punctuation classes, a ligature query, a
      plain control query, an unmatchable-but-valid query, and the original triggering string
      `joint multi-owner disjunct(bracketholds) engine for KVE2 sepdisjunct`.
- [ ] For each, record `degraded`, `fallback_tier`, `query_error`, result count, and confirm the
      briefing block rendering is consistent with the envelope.
- [ ] Exercise the other `literature-search.sh` subcommands untouched by this task (`--read`,
      `--toc`, `--refs`, `--navigate`) and confirm their JSON output shape is unchanged — the
      envelope applies to `do_search()` only.
- [ ] Confirm `chunks_fts` row counts, BM25 ordering, and `provenance_fidelity` values on primary
      (non-degraded) results are identical to the baseline.
- [ ] Confirm the real DB was never rebuilt from `literature-schema.sql` during this task
      (`SELECT count(*) FROM chunks_data` still returns 3746).

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- None (verification only; fix-forward into the owning phase's file if a defect is found)

**Verification**:
- [ ] The original triggering query returns a non-empty, correctly-labeled result set.
- [ ] Zero regressions in control-query result counts and ordering.
- [ ] `--read`/`--toc`/`--refs`/`--navigate` output shapes unchanged.
- [ ] `chunks_data` still holds 3746 rows.

---

## Testing & Validation

- [ ] All four punctuation classes (`-`, `:`, `/`, attached parens) execute without
      `sqlite3.OperationalError` against the real corpus.
- [ ] A raw-ligature query matches the folded corpus text.
- [ ] `degraded`, `fallback_tier`, and `query_error` are present and correct on every search
      envelope; `match_tier` is present on every result row.
- [ ] A parse failure and a genuine zero-result produce visibly different briefing output.
- [ ] `chunks_trigram` is created and populated lazily, and its absence or emptiness is
      self-healing.
- [ ] `chunks_fts` results, BM25 ordering, and `provenance_fidelity` are unchanged on the
      primary tier.
- [ ] The populated corpus DB is never dropped or rebuilt.
- [ ] No changes outside `file_scope` (`literature-search.sh`, `literature-briefing.sh`,
      `literature-schema.sql`).

## Artifacts & Outputs

- `.claude/scripts/literature-search.sh` — extended sanitizer, fallback ladder, lazy trigram
  migration, result envelope
- `.claude/scripts/literature-briefing.sh` — envelope-aware parsing, degraded banner, actionable
  zero-result message
- `.claude/scripts/literature-schema.sql` — additive `chunks_trigram` table, `content` column
  drift repair
- `specs/833_harden_literature_retrieval_tokenization/summaries/01_harden-retrieval-tokenization-summary.md`

## Rollback/Contingency

All three files are tracked in git and the change is confined to them, so
`git checkout -- .claude/scripts/literature-search.sh .claude/scripts/literature-briefing.sh
.claude/scripts/literature-schema.sql` fully reverts the code. The only persistent side effect is
the `chunks_trigram` table created lazily in `~/Projects/Literature/.literature.db`; it is additive
and unread by the reverted scripts, and can be removed with
`sqlite3 ~/Projects/Literature/.literature.db "DROP TABLE IF EXISTS chunks_trigram;"`. No existing
table, index, or row is modified at any point, so no data restore is required. If a phase fails
mid-way, fix forward within that phase's file — never re-apply `literature-schema.sql` to the
populated DB as a recovery step.
