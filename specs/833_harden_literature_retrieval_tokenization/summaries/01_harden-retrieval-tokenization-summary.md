# Implementation Summary: Task #833

**Completed**: 2026-07-09
**Duration**: single session, 5 phases

## Overview

Hardened `literature-search.sh` and `literature-briefing.sh` so that FTS5 query-syntax
brittleness (hyphens, colons, slashes, word-attached parens) degrades gracefully instead of
silently returning an empty result indistinguishable from "no matches," and so that a raw
ligature glyph in a query matches the corpus's already-folded text (mirroring #831's
conversion-time ligature fold). Added an additive `chunks_trigram` FTS5 substring-match table as
a last-resort fallback tier, and made both scripts emit an honest `degraded`/`fallback_tier`/
`query_error` signal all the way through to the `<literature-briefing>` block, with a concrete
next action on genuine parse failures.

All five plan phases are complete and verified against the real corpus DB
(`~/Projects/Literature/.literature.db`, 3,746 chunks) — not just checked for absence of crashes,
but confirmed to produce correct, honest output, including two true-positive checks (a real
ligature match and a real trigram substring match) that go beyond the plan's literal examples
where those examples turned out to be already-fixed by an earlier phase.

## What Changed

- `.claude/scripts/literature-search.sh` — `sanitize_query()` now folds `LIGATURE_MAP` (U+FB00-
  FB06, copied from `literature-convert.sh`) first, then converts mid-word hyphens, colons,
  slashes, and parens to spaces. `do_search()`'s `search_db()` (both the project-scoped and
  unscoped-retry definitions) now climbs a three-rung ladder — primary bm25 MATCH, phrase-quote
  retry on syntax error, `chunks_trigram` substring fallback on zero rows — and returns an
  envelope `{"results": [...], "degraded": bool, "fallback_tier": "bm25"|"phrase_retry"|
  "trigram"|"none", "query_error": str|null}` instead of a bare array. Every result row now
  carries `match_tier`. A new `ensure_trigram(conn)` helper lazily creates and (re)populates
  `chunks_trigram` on demand.
- `.claude/scripts/literature-schema.sql` — added `content TEXT DEFAULT ''` to `chunks_data`
  (repairs a pre-existing schema/live-DB drift where `chunks_fts` declared a `content` column
  `chunks_data` never had in the schema file, papered over at runtime by
  `literature-build-index.sh`'s own `ALTER TABLE` probe). Added the additive
  `chunks_trigram USING fts5(..., tokenize='trigram')` virtual table and its `DROP TABLE IF
  EXISTS` entry in the clean-rebuild block. `chunks_fts` itself is untouched. Header comment
  documents the trigram table as fallback-only and lazily populated by the search script, never
  by the indexer.
- `.claude/scripts/literature-briefing.sh` — global-corpus branch now captures the search
  script's stderr instead of discarding it, parses both the legacy bare-array shape and the new
  envelope object, slices `top_n` on `.results`, prefixes a tier-specific `[DEGRADED RETRIEVAL
  ...]` banner when results are degraded, and replaces the bare zero-result line with an honest
  syntax-error-plus-next-action message when `query_error` is non-null. A top-level
  `query_error="null"` default was added (see Deviations) so `set -u` doesn't crash repo mode.
- `specs/833_harden_literature_retrieval_tokenization/summaries/01_harden-retrieval-tokenization-summary.md` —
  this file.

## Decisions

- Followed the research/plan's fallback ladder order exactly: extended sanitizer -> phrase-quote
  retry (syntax error only) -> trigram (zero rows only) -> stop. sqlite-vec and per-chunk LLM
  gist remain deferred, not implemented.
- `envelope.fallback_tier`/`degraded` are computed from the tiers actually surviving the #835
  quarantine filter in the final merged result set, not from a per-database tier that might have
  been entirely filtered out — otherwise a quarantined-away bm25 hit could falsely report
  `degraded: false`.
- Read-only-DB degradation reports `query_error` populated with a synthetic, honest message
  ("trigram fallback unavailable ... read-only database") when `ensure_trigram()` itself fails
  and no earlier syntax error exists to report, so the envelope's `query_error` is never silently
  null on a real failure.

## Plan Deviations

- **Phase 1 verification** altered: the plan's literal
  `bash -c 'source literature-search.sh 2>/dev/null; sanitize_query ...'` command doesn't work —
  sourcing the whole script also runs its unconditional dispatch section, which exits 1 for zero
  args before `sanitize_query` is ever called. Verified instead by sourcing only the function
  definitions (excluding the dispatch section).
- **Phase 3, `ensure_trigram()` empty-check** altered (real bug found and fixed): `SELECT
  count(*) FROM chunks_trigram LIMIT 1` is not a valid "is the index populated" check for an
  external-content FTS5 table — `count(*)` is satisfied directly from the content table's rowid
  range and reports the full row count immediately after `CREATE`, before `'rebuild'` has ever
  run. Verified empirically against the real corpus DB. Replaced with a real `MATCH` probe
  against a sampled content row.
- **Phase 3, missing `conn.commit()`** altered (second real bug found and fixed): the lazy
  rebuild's `INSERT INTO chunks_trigram(chunks_trigram) VALUES('rebuild')` lived inside Python
  sqlite3's implicit per-connection transaction and was silently rolled back on `conn.close()`,
  since every path in `do_search()` was read-only before this task. Added an explicit
  `conn.commit()` immediately after the rebuild insert.
- **Phase 3/4/5 verification terms** altered: the task's own literal example terms
  (`multi-owner`, `disjunct(bracketholds)`, etc.) are synthetic strings from the triggering task
  title and do not exist anywhere in the real corpus, so they cannot exercise the trigram rung or
  the syntax-error-message path meaningfully once Phase 1's sanitizer has already neutralized
  their punctuation. Substituted real corpus terms (`roarch`, a genuine mid-word substring of
  "microarchitectural", for the trigram rung; `modal -classical`, a space-preceded hyphen that
  Phase 1's mid-word-only regex deliberately does not touch, for the syntax-error path) to
  genuinely exercise both paths end-to-end.
- **Phase 4, `query_error` top-level default** altered: added `query_error="null"` at the
  top-level argument-parsing block (before the mode branch) because the shared zero-results exit
  point references `$query_error` regardless of mode, and the script runs under `set -euo
  pipefail`; without this default, repo mode (which never assigns `query_error`) would crash with
  an unbound-variable error. Repo-mode's own rendered output is unaffected since the new message
  is gated on `mode == "global"`.

## Verification

- Build: N/A (shell + SQLite, no build step)
- Tests: All five phases' verification steps executed for real against
  `~/Projects/Literature/.literature.db` (backed up before any schema work; backup removed after
  full verification passed) — see the plan file's per-phase Verification sections for exact
  observed output. Highlights:
  - All four punctuation classes + the original triggering string + a ligature query all execute
    with exit 0 and well-formed envelopes (no `OperationalError`).
  - `deﬁnition` (raw ligature) matches plain "definition" content via primary bm25 — a true
    positive.
  - `roarch` (real corpus substring) correctly reaches and is answered by the trigram tier,
    tagged `match_tier: "trigram_fallback"`, `fallback_tier: "trigram"`.
  - `modal -classical` genuinely fails FTS5 syntax parsing and is honestly reported end-to-end
    through to the briefing block's syntax-error + next-action message.
  - Lazy trigram migration and read-only degradation both verified on real DB copies.
  - Control queries (`modal logic`, `possible worlds`, `algorithm`) are byte-identical in
    ordering, rank, and `provenance_fidelity` against the true pre-#833 baseline.
  - `--toc`/`--doc` byte-identical to baseline; `--refs`/`--next`/`--prev` shapes unchanged.
  - `chunks_data` remained 3746 rows throughout; `chunks_fts MATCH 'modal'` remained 212;
    `PRAGMA integrity_check` -> `ok`.
- Files verified: Yes — `bash -n` syntax-checked on both shell scripts after every edit.

## Notes

- The real corpus DB's `chunks_trigram` table was left in a populated, working state (rebuilt
  once more after test-induced drops) at the end of this task.
- One pre-existing, orthogonal-to-#833 observation surfaced during Phase 3 testing: the term
  `roarch` (and likely other substring-only matches) is fully quarantined by #835's
  `unverified_summary`/`unverified_no_baseline` filter in this corpus, meaning the trigram
  fallback's results were only visible with `--include-unverified`. This is a #835 concern, not a
  #833 defect, and was not touched here.
- No changes were made outside the declared `file_scope`
  (`literature-search.sh`, `literature-briefing.sh`, `literature-schema.sql`, and this task's own
  `specs/833_.../` directory).
