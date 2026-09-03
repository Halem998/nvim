# Implementation Summary: Task #112

- **Task**: 112 - Fix literature-briefing.sh --global FTS5 over-constraint returning zero segments
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T00:00:00Z
- **Completed**: 2026-09-02T06:00:00Z
- **Effort**: ~9 hours (plan estimated 8.25h; Phase 5 ran long due to two additional real-corpus
  defects discovered and fixed during verification)
- **Dependencies**: 108 (completed, non-overlapping)
- **Artifacts**: plans/01_fix-briefing-fts5-recall.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed `literature-briefing.sh --global`'s AND-all-terms FTS5 over-constraint (0 segments on any
realistic query length) and its unhandled `<`/`>` hard syntax error, by adding a single-process
multi-query search mode to `literature-search.sh` and rewiring `--global` mode to use it with
`literature-term-match.sh`'s filtered terms. Real-corpus verification (Phase 5) surfaced two
further defects beyond the plan's original scope — cross-query BM25 incomparability flooding
top-ranked results with noise, and a false-negative sparse signal on genuinely off-topic queries —
both fixed and folded back into the Phase 2/3 files per the plan's own contingency. All 6 phases
completed; `lit-stage4a-flow.md`'s callers were deliberately left unchanged, with reasons recorded
below.

## What Changed

- `agent-system/extensions/literature/scripts/literature-search.sh` — `sanitize_query()` now
  folds `<`/`>` to spaces (Phase 1); added `--multi` mode (`do_multi_search()`) running N
  sanitized queries against one already-open connection per database, merging by `chunk_id` with
  a `matched_terms` corroboration count (Phase 2); merge sort changed from rank-primary to
  `matched_terms`-descending-then-rank (Phase 5 fold-back — see Decisions); added
  `corroborated_count` envelope field (Phase 5 fold-back).
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — `--global` mode now
  sources `literature-term-match.sh`, computes and caps `FILTERED_TERMS`
  (`LITERATURE_GLOBAL_MAX_TERMS`, default 12, longest-first), and calls `--multi` instead of a
  single raw-query search, with an empty-filtered-terms fallback (Phase 3); `seg_count` pinned to
  the multi-query envelope's `total_matched`; sparse determination now uses a new
  `sparse_eval_count` (defaults to `coverage_count`; in global mode with more than
  `MULTI_TERM_MATCH_THRESHOLD` filtered terms, uses `corroborated_count` instead) (Phase 5
  fold-back — see Decisions).
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — new Section I (4 cases +
  a marker-shape assertion) with a real FTS5-populated fixture DB, following Section G/H's idiom
  (Phase 4).
- `agent-system/extensions/literature/context/project/literature/domain/fts5-query-semantics.md`
  — new domain doc: FTS5 bareword-AND recall ceiling, the full hostile-character set, the ladder's
  real (narrow) recall behavior, the `--multi` envelope contract, and a recorded residual
  limitation in term-selection (Phase 6).
- `agent-system/extensions/literature/index-entries.json` — registered the new domain doc
  (Phase 6).

## Decisions

- **`literature-search.sh --multi` runs entirely inside one process per briefing** (one DB open,
  one fidelity-map load; only the cheap per-term `sanitize_query()` python3 call is per-term) —
  confirmed via `strace -f -e trace=execve` against the real corpus: exactly one nested
  `bash literature-search.sh` invocation per `--global` call, regardless of filtered-term count.
- **`corroborated_count` (matched_terms >= 2) is real signal `total_matched` cannot give.**
  Verified empirically against the real ~250MB global corpus: a control query with zero real
  topical overlap with the corpus (`"quantum chromodynamics particle accelerator experiment
  string theory"`) reported `total_matched` > 100 purely from coincidental single-term hits by
  common English words spread across unrelated documents — a direct violation of the plan's
  sparse-coverage-contract requirement. Added `corroborated_count` as an additive envelope field
  and switched the sparse boolean's input to it whenever the filtered term count exceeds
  `MULTI_TERM_MATCH_THRESHOLD` (5), leaving `seg_count`/`total_matched`/the displayed result set
  itself unchanged, exactly as the plan's own risk mitigation prescribed. Re-verified: the same
  control query now correctly reports `sparse=true`; a genuinely rich real query still correctly
  reports `sparse=false`.
- **Merge sort changed from rank-primary to `matched_terms`-primary.** The plan specified
  "matched_terms is a tiebreak only, never a replacement for rank." Verified empirically against
  the real corpus with the actual original failing task description (see Verification below) that
  rank-primary sorting returned zero topically relevant chunks in the top 10 despite non-empty
  recall, because BM25 scores from independent single-term sub-queries are not on a comparable
  scale. Promoting `matched_terms` to the primary sort key (descending, with `rank` as the
  ascending tiebreak within a tier) surfaced the corpus's own canonical Modal Logic textbook
  (Chagrov & Zakharyaschev) at position 1 for the same query. This is a deliberate, evidence-based
  deviation from the plan's literal sort-priority instruction, made because Phase 5 exists
  precisely to test such assumptions against real data — recorded as a Plan Deviation below.
  `LITERATURE_GLOBAL_MAX_TERMS` was left at its Phase 3 default of 12 after empirically finding
  that raising it did not reliably improve (and once measurably worsened) top-rank relevance for
  the same query (see Follow-ups).
- **`lit-stage4a-flow.md`'s two `--global "$description"` call sites are left UNCHANGED** — a
  ratified decision, not an omission. Reasons:
  1. The verification bar ("non-empty, topically relevant segment set") is met by the script fix
     alone: `seg_count` went from 0 to 150 for the original failing description, and the
     `matched_terms`-primary sort now puts a genuinely on-topic canonical source at position 1.
  2. A short, well-chosen reformulation of the same query (e.g. `"representation theorem modal
     logic algebraic duality"`) demonstrably surfaces even better material (directly hit
     `venema_2007_algebras_and_coalgebras`, the exact citation the downstream research report
     used for the Goldblatt/Esakia duality) — confirming the caller-change direction the plan
     names ("pass title + filtered terms") has real headroom. But this repository's `state.json`
     schema (and, per the origin repository's history, not reliably the origin repository's) has
     a separate `title` field distinct from `description` at some points in its schema evolution;
     `lit-stage4a-flow.md`'s six importing skills currently only extract `description`. Wiring a
     `title`-based (or otherwise pre-filtered) query into a file imported verbatim by 6 skill call
     sites, and re-verifying all six read correctly afterward, is a materially larger and riskier
     change than this task's already-expanded scope (two additional real-corpus defects were
     found and fixed in Phase 5).
  3. The measured relevance gap is a matter of degree (few relevant items now appear, more relevant
     items could appear with a better query), not the binary pass/fail the verification bar names,
     and the residual limitation is fully recorded in
     `fts5-query-semantics.md`'s "Known residual limitation" section for whoever picks up the
     properly-scoped follow-up.

## Plan Deviations

- **Merge sort priority**: the plan specified `rank` primary / `matched_terms` tiebreak-only
  (Phase 2's task list and Risk table). Changed to `matched_terms` primary / `rank` secondary
  during Phase 5, after empirically finding the specified priority produced zero topically
  relevant top-10 results against the real corpus for the origin failing query. See Decisions
  above for the full evidence and rationale; Section I's regression suite (Phase 4) was
  re-verified against this change and all cases still pass (order is never asserted there, only
  presence/counts).
- **New additive envelope field `corroborated_count`** (not named in the plan): added during
  Phase 5 as the sanctioned fix for a real sparse-coverage-contract violation the plan's own Risk
  table anticipated ("Phase 4's genuinely-sparse control query is the empirical trigger for
  tightening the sparse accounting to `matched_terms >= 2`... leaving the displayed result set
  unchanged") but Phase 4's synthetic fixture (too small to exhibit coincidental cross-document
  term overlap) never actually triggered. Phase 5's real-corpus test did trigger it.
- **`lit-stage4a-flow.md` callers**: left unchanged per plan Non-Goals; see Decisions above for
  the full reasoning, now backed by real-corpus evidence rather than the plan-time assumption
  alone.

## Verification

- **Build**: N/A (bash/Python scripts).
- **Tests**: `bash -n` clean on all three edited scripts.
  `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime` — **51 passed,
  0 failed, 1 pre-existing warning** (unrelated `specs/literature-index.json already exists`
  notice). All 9 new Section I cases pass; each was independently re-run against a stashed
  pre-fix copy of `literature-search.sh`/`literature-briefing.sh` and demonstrably fails there
  (10 failures, including the primary regression case and the redesigned dedupe case).
- **Primary bar — re-run of the actual origin failing query**: the origin `/research --lit`
  session's real task description (100 words, containing the literal `<sec:representation>`
  token and two absolute file paths, from the archived task in the origin repository) was
  re-derived verbatim from that repository's git history (`specs/state.json`'s pre-archive
  diff) and re-run against the real global Literature corpus (`~/Projects/Literature/.literature.db`,
  ~252MB) via a temp-tree symlink of the fixed source-store scripts into the origin repository's
  own root (so `PROJECT_ROOT`/local-db resolution matched real conditions, without touching that
  repository's `.claude/`). Result: **`seg_count` 0 → 150** (non-empty), `sparse=true` (see
  Decisions — this specific query's corroboration signal is genuinely weak, an honest result, not
  a defect), top-ranked result is `chagrovzakharyaschev_1997_modallogic` (a canonical Modal Logic
  textbook) after the `matched_terms`-primary fix.
- **Ground-truth cross-check** (re-derived fresh against the current corpus, not assumed from the
  origin session): `literature-coverage-delta.sh` reported **104 matching global documents**
  (origin session reported 111 — expected drift, corpus has changed since). Nine hand-written
  2-4 word searches (`"representation theorem modal logic"`, `"Jonsson Tarski"`, `"canonical
  extension"`, `"duality algebra coalgebra"`, `"descriptive general frames"`, `"Sahlqvist"`,
  `"tense algebra"`, `"Kripke frames representation"`, `"Goldblatt duality"`) resolved
  **159 deduplicated reachable segments** (origin session reported 131). The briefing's own
  `seg_count=150` is in the same order of magnitude as this ground truth — recall breadth is
  genuinely fixed.
- **Relevance spot-check** (read, not merely counted): `chagrovzakharyaschev_1997_modallogic`
  (top-1 result for the origin query) and `venema_2007_algebras_and_coalgebras`'s "Duality of
  algebra and coalgebra" chunk (top-1 for a short reformulated query) were both read directly from
  disk and confirmed genuinely on-topic — the latter is the exact source the downstream research
  report cited for the Goldblatt/Esakia duality. **Observed, out-of-scope finding**: `--read`'s
  chunk-file path resolution failed for several chunks in this real corpus (`[Chunk file not
  found: ...]`, resolving against `LITERATURE_DIR` root instead of `LITERATURE_DIR/sources/<doc_id>/`)
  — reproduced identically against the unmodified pre-fix `literature-search.sh`, confirming it
  predates this task and is unrelated to it (not fixed here; flagged for a separate task).
- **Timing table** (3 runs each, origin query, wall clock): pre-fix (single AND-all-terms query,
  fails fast) ≈ 0.42-0.51s; post-fix (12-term `--multi` fan-out, single process) ≈ 0.82-0.88s.
  Process count confirmed via `strace -f -e trace=execve`: exactly **one**
  `bash literature-search.sh` invocation per `--global` briefing (13 python3 processes total — 12
  cheap per-term `sanitize_query()` calls plus one big search process — matching the plan's
  "only the cheap sanitize_query() call is per-term" design).
- **Marker honesty, both directions confirmed against the real corpus**: the off-topic control
  query now correctly reports `sparse=true` (was a false `sparse=false` before the
  `corroborated_count` fix); a genuinely rich query (`"canonical extension Jonsson Tarski
  representation theorem modal algebra duality"`, seg_count=162) correctly stays `sparse=false`
  both before and after. `lit-stage4a-flow.md`'s `lit-coverage mode=global .*sparse=true` grep
  still matches (Section I's marker field-order/adjacency assertion also passes).
- **Error isolation**: confirmed via Section I Case I3 and directly against the real corpus with
  a leading-hyphen hostile term (survives `sanitize_query` — only mid-word hyphens are folded, so
  a leading hyphen still raises FTS5's "no such column" error): one hostile term among valid ones
  returns results with `query_error: null`; all-hostile terms return a non-null `query_error`.
- **Repo mode (`--query`) unchanged**: confirmed by re-running the full test suite's Sections
  A-H (which exercise repo mode extensively) with 0 regressions.

## Impacts

- `literature-briefing.sh --global` is now usable with realistic, full-length task descriptions
  instead of only short hand-typed queries — the actual failure mode the task originated from.
- `sanitize_query()`'s `<`/`>` fix benefits every `literature-search.sh` caller, not just
  `--global` (e.g. any future direct search containing an angle-bracketed section-reference token).
- The new `--multi` mode, `total_matched`, `matched_terms`, and `corroborated_count` fields are
  available to any future caller needing per-term recall at one-process cost — not
  `--global`-specific.

## Follow-ups

- The length-based `LITERATURE_GLOBAL_MAX_TERMS` cap heuristic is a known, recorded, imperfect
  proxy for "discriminating term" (see `fts5-query-semantics.md`'s "Known residual limitation").
  A properly scoped follow-up could pursue IDF-weighted term selection, cross-query BM25
  normalization, or a caller-side switch to a short representative query instead of the full raw
  description (the `lit-stage4a-flow.md` caller question, revisited with real headroom evidence
  in Decisions above).
- The `--read` chunk-file path-resolution defect observed during Phase 5's relevance spot-check
  (pre-existing, reproduced against the unmodified pre-fix script, unrelated to this task's scope)
  is worth its own investigation.

## References

- `specs/112_fix_briefing_fts5_over_constraint/reports/01_fix-briefing-fts5-recall.md`
- `specs/112_fix_briefing_fts5_over_constraint/plans/01_fix-briefing-fts5-recall.md`
- `agent-system/extensions/literature/context/project/literature/domain/fts5-query-semantics.md`
