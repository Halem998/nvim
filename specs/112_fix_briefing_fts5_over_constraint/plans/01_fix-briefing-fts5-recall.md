# Implementation Plan: Fix literature-briefing.sh --global FTS5 over-constraint

- **Task**: 112 - Fix literature-briefing.sh --global FTS5 over-constraint returning zero segments
- **Status**: [IMPLEMENTING]
- **Effort**: 8.25 hours
- **Dependencies**: 108 (completed; verified non-overlapping — `literature-term-match.sh`'s public
  contract `filter_terms`/`STOP_WORDS`/`MULTI_TERM_MATCH_THRESHOLD` is unchanged by it)
- **Research Inputs**: specs/112_fix_briefing_fts5_over_constraint/reports/01_fix-briefing-fts5-recall.md
- **Artifacts**: plans/01_fix-briefing-fts5-recall.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, git-workflow.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`literature-briefing.sh --global "<query>"` forwards the entire task description verbatim to
`literature-search.sh`, whose FTS5 bareword `MATCH` ANDs every term together — a condition no real
document satisfies at 15-30 word query lengths — and whose `sanitize_query()` never strips `<`/`>`,
turning a poor-recall query into a hard `fts5: syntax error`. This plan closes both halves: strip
the unhandled FTS5-hostile characters, and replace the single AND-all-terms query with a set of
short per-term searches merged by the `rank` `literature-search.sh` already computes, deduped by
`chunk_id`. To avoid re-creating the per-invocation fork cost that task 108 was fixing elsewhere,
the per-term loop runs inside **one** `literature-search.sh` process (one 252 MB DB open, one
`index.json` fidelity-map load) rather than one process per term. Definition of done: the original
failing description returns a non-empty, topically relevant segment set; the `<!-- lit-coverage ...
sparse=... -->` marker stays honest; regression coverage exists; the `lit-stage4a-flow.md` caller
decision is made with a written reason.

### Research Integration

Every design decision below traces to a verified finding in
`reports/01_fix-briefing-fts5-recall.md`:
- The AND-all-terms recall defect and the `<` syntax error were each confirmed by live in-memory
  FTS5 tests, and `sanitize_query()` was sourced and run directly to confirm `<`/`>` pass through
  untouched. Both halves are therefore treated as independently real, and Phase 1 lands regardless
  of the merge design.
- The phrase_retry and trigram rungs are syntax-safe but recall-dead for long queries (a 6-word
  quoted phrase found nothing in a row containing all 6 words non-contiguously), so no fix that
  relies on the existing fallback ladder is viable.
- `literature-briefing.sh` has zero `filter_terms` references; `literature-coverage-delta.sh`'s
  `source "$SCRIPT_DIR/literature-term-match.sh"` + `mapfile -t FILTERED_TERMS < <(filter_terms
  "$query")` is the established reuse template and is copied verbatim in Phase 3.
- No merge-by-rank pattern exists anywhere in the codebase to reuse (`literature-discover.sh`
  Tier 1 is a substring matcher against `index.json`, not FTS5). The merge is new work; only
  `filter_terms`/`term_matches` are reused.
- `rank` is already attached to every `do_search` row (`AS rank`, then `merged.sort(key=lambda r:
  r['rank'])`); the merge consumes it and never recomputes relevance.
- The two `--global "$description"` call sites in `lit-stage4a-flow.md` pass the raw description
  with zero preprocessing (`literature-briefing-invoke.sh` is a pure pass-through), and that file
  is imported verbatim by 6 skill call sites — hence the caller change is evaluated in Phase 5,
  not assumed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- `literature-briefing.sh --global` returns a non-empty, topically relevant segment set for a
  full-length task description, including one containing `<sec:representation>`-shaped tokens.
- `sanitize_query()` strips `<`/`>` (and documents the FTS5-hostile character set it owns), fixing
  every `literature-search.sh` caller, not just `--global`.
- The per-term search fan-out costs **one** `literature-search.sh` process per briefing, not N.
- `degraded`/`fallback_tier`/`query_error` aggregate conservatively: a hard `query_error` surfaces
  only when every sub-query failed.
- `seg_count`/`coverage_count` remain an honest de-duplicated total-match count, so the
  `sparse=true` marker keeps firing for genuinely sparse topics and `lit-stage4a-flow.md`'s
  re-prompt path stays live.
- Global-mode FTS5 regression coverage exists in `test-lit-pipeline.sh` (it currently has none).

**Non-Goals**:
- Task 113's SIGPIPE crash in the `--query` repo-mode parent-entry extraction (disjoint code path).
- Repo-mode (`--query`) briefing behavior — unchanged by this plan except where it shares
  `sanitize_query()`.
- A blanket rewrite of the three-rung fallback ladder. The ladder stays; it is simply no longer the
  mechanism recall depends on.
- Changing `lit-stage4a-flow.md`'s callers **by default**. Phase 5 evaluates and records a decision;
  a change there is only made if post-fix verification shows the script fix is insufficient.
- Any hand-authored edit under `.claude/**` — that tree is a disposable deploy artifact
  (`rules/source-store-deploy-boundary.md`). All edits target `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Per-term fan-out re-creates the process-spawn cost task 108 was eliminating | H | H | Phase 2 keeps the per-term loop inside a single Python process (one DB open, one fidelity-map load). Only the cheap `sanitize_query()` python3 call is per-term. Phase 5 records a before/after timing table. |
| Many small per-term matches flood the briefing with marginal, single-term-only chunks | M | M | Phase 2 records a per-chunk `matched_terms` corroboration count during the merge and uses it as a rank tiebreak; Phase 4's genuinely-sparse control query is the empirical trigger for tightening the sparse accounting to `matched_terms >= 2` (mirroring the existing `MULTI_TERM_MATCH_THRESHOLD` asymmetry in `literature-coverage-delta.sh`/`literature-discover.sh`). |
| Inflated `seg_count` silently kills the `sparse=true` re-prompt contract | H | M | `seg_count` is pinned to the **de-duplicated, post-merge, pre-`top_n`** count (never a sum of per-term totals). Phase 4 asserts marker fields for one rich and one genuinely-sparse query, exercising the `< threshold` boundary explicitly. |
| Envelope-shape change breaks the legacy bare-array / object parsing in `literature-briefing.sh` or another consumer | M | M | Phase 2 adds fields only (never removes or renames); the single-query path stays byte-compatible. Phase 3's parser reads `total_matched` with a `results | length` fallback. |
| A single filtered term still carries an unhandled FTS5-hostile character and throws | M | M | Per-sub-query error isolation: one failing term degrades to its own rung/failure and never poisons the request. This is the point of many small queries over one large one. |
| Verification run against the source-store copy misresolves `PROJECT_ROOT` (`$SCRIPT_DIR/../..`) | M | H | Phase 5 states the run location explicitly and uses the deployed `.claude/scripts/` copy (refreshed via the sanctioned deploy path) or a temp tree whose layout resolves correctly — never a hand-edit of `.claude/**`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 4 and 5 own disjoint files
(`test-lit-pipeline.sh` vs. no source edits) and may run concurrently.

---

### Phase 1: Strip FTS5-hostile `<`/`>` in sanitize_query() [COMPLETED]

**Goal**: Close the hard-syntax-error half of the defect for every `literature-search.sh` caller,
independently of the merge redesign.

**Tasks**:
- [x] In `sanitize_query()`'s punctuation-normalization block (the section that already folds *(completed)*
      mid-word hyphens, `:`, `/`, `(`, `)` to spaces), fold `<` and `>` to spaces using the same
      idiom and the same comment style.
- [x] Extend that block's existing comment to name the character set this function owns and state *(completed)*
      why these are folded rather than quoted (the caller passes one opaque free-text query, never
      a hand-built FTS5 boolean expression) — the rationale already given there for `:`/`/`/parens.
- [x] Re-run the research's direct check: source the function and confirm *(completed)*
      `"hello <sec:representation> world"` sanitizes with no `<`/`>` surviving, and that the
      sanitized output no longer raises `fts5: syntax error near "<"` against a live FTS5 table.
- [x] Confirm no existing behavior regressed: AND/OR/NOT stripping, quote balancing, unquoted `*` *(completed)*
      stripping, ligature folding, and apostrophe stripping all still behave as before.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-search.sh` — `sanitize_query()`
  punctuation-normalization block only.

**Verification**:
- `bash -n agent-system/extensions/literature/scripts/literature-search.sh` passes.
- A direct `sanitize_query` invocation on the research's probe string emits no `<` or `>`.
- An FTS5 `MATCH` on the sanitized output raises no `OperationalError`.

---

### Phase 2: Multi-query search mode in literature-search.sh [COMPLETED]

**Goal**: Let one `literature-search.sh` invocation run N short queries and return one
rank-merged, `chunk_id`-deduped envelope — so the briefing gets per-term recall at one-process cost.

**Tasks**:
- [x] Add a multi-query entry point to the main dispatch (alongside `--read`/`--toc`/`--refs`/…): *(completed)*
      a `--multi` flag reading newline-separated queries from stdin. Keep it composable with the
      existing pre-scanned `--project` / `--include-unverified` flags, and reject an empty query
      list through the existing `error_json` path.
- [x] In the bash layer, loop the existing `sanitize_query()` once per query and drop entries that *(completed)*
      sanitize to empty. `sanitize_query()` stays the **single** source of sanitization truth — do
      not port or duplicate its rules into the search heredoc.
- [x] Generalize `search_db()` to accept a list of sanitized queries: run the existing three-rung *(completed)*
      ladder (bm25 -> phrase_retry on syntax error -> trigram on zero rows) **per query**, inside
      the one already-open connection, accumulating rows across queries.
- [x] Merge across queries: dedupe on `chunk_id`, keeping the occurrence with the best (lowest, *(completed)*
      most negative) `rank`. Consume the existing `rank`; do not compute a new relevance score.
- [x] Record a per-chunk `matched_terms` integer (how many distinct sub-queries surfaced that *(completed)*
      chunk) during the merge, expose it on each result row, and use it only as a tiebreak among
      equal-rank rows — never as a replacement for `rank`.
- [x] Preserve the existing post-merge pipeline unchanged: local-over-global `doc_id` precedence, *(completed)*
      the `include_unverified` quarantine filter, the final `rank` sort, and the `limit` slice.
- [x] Aggregate the envelope conservatively: `fallback_tier`/`degraded` continue to derive from the *(completed)*
      `match_tier` values of the rows that actually survive quarantine (existing logic works
      unchanged on merged rows); `query_error` is non-null **only** when every sub-query errored,
      and carries a message naming how many of N sub-queries failed.
- [x] Add a `total_matched` field to the envelope: the de-duplicated merged count taken **before** *(completed)*
      the `limit` slice. Add fields only — never rename or remove an existing envelope field.
- [x] Confirm the single-query path is byte-compatible: a one-element multi-query list and the *(completed)*
      existing positional-query path must produce the same `results` for the same input.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that the envelope gains exactly two additive fields
(`total_matched` top-level, `matched_terms` per row) and that no consumer reads the envelope
positionally. Confirm at implementation time with
`grep -rn 'fallback_tier\|query_error\|\.results' agent-system/extensions --include=*.sh --include=*.md`
before editing; if a consumer beyond `literature-briefing.sh` reads the envelope, enumerate it and
widen this phase's dependent set rather than proceeding on the assumption.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-search.sh` — `do_search()`, its embedded
  `search_db()`/merge/envelope Python, and the main dispatch `case`.

**Verification**:
- `bash -n` passes.
- Single-query invocation returns an envelope identical in shape (and, for a fixed query, in
  `results`) to pre-change output.
- A `--multi` run with two terms known to hit different chunks returns the union, `chunk_id`-unique,
  sorted ascending by `rank`, with `total_matched` equal to the deduped pre-limit count.
- A `--multi` run where one term is deliberately hostile and the others are valid returns
  `query_error: null` and non-empty results; a run where every term is hostile returns a non-null
  `query_error`.

---

### Phase 3: Rebuild literature-briefing.sh global mode on filtered terms [COMPLETED]

**Goal**: Replace the single AND-all-terms `--global` call with a filtered-term multi-query call,
preserving the briefing's rendering, degraded banner, error messaging, and coverage marker.

**Tasks**:
- [x] `source "$SCRIPT_DIR/literature-term-match.sh"` and compute *(completed)*
      `mapfile -t FILTERED_TERMS < <(filter_terms "$query")`, copying
      `literature-coverage-delta.sh`'s consumption pattern verbatim (including the
      `# shellcheck source=` directive). Do not write a second stop-word filter.
- [x] Add `LITERATURE_GLOBAL_MAX_TERMS="${LITERATURE_GLOBAL_MAX_TERMS:-12}"` alongside the file's *(completed)*
      other threshold declarations, and cap the term list to that many terms (longest-first, so the
      most discriminating survive). Document the cap's purpose (fan-out bound) in a comment.
- [x] Handle the empty-filtered-terms case explicitly: fall back to the current single-query call *(completed)*
      with the raw query rather than searching nothing, and log a `>&2` notice — never a silent
      zero-result.
- [x] Replace the single `bash "$SEARCH_SCRIPT" --project "$repo_name" "$query"` call with the *(completed)*
      Phase 2 multi-query invocation, keeping the existing stderr-capture-and-surface pattern
      (`search_err_file`) intact.
- [x] Extend the shape-aware envelope parser to read `total_matched`, falling back to *(completed)*
      `results | length` when the field is absent (keeps the legacy bare-array and pre-change object
      shapes working).
- [x] Set `seg_count`/`coverage_count`/`requested_count` from the de-duplicated merged total *(completed)*
      (`total_matched`), i.e. post-merge and **pre-`top_n`-slice** — matching the field's existing
      documented semantics. Never sum per-term totals.
- [x] Leave untouched: the `top_n` slice, per-segment rendering (title/section/doc/tokens/summary/ *(completed)*
      `Read:` command), the fidelity marker, the degraded-tier banner and its `case` on
      `fallback_tier`, the genuine-zero-vs-`query_error` messaging, and the shared exit point's
      marker/banner emission.
- [x] Confirm the emitted `<!-- lit-coverage ... -->` line keeps its original eight fields *(completed)*
      byte-adjacent and in order (the `delta_*` fields stay strictly after them), so
      `lit-stage4a-flow.md`'s `lit-coverage mode=global .*sparse=true` grep still matches.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes the global-mode block is the only region of
`literature-briefing.sh` needing change, and that repo mode shares no code with it beyond the shared
exit point. Confirm by re-reading the file's mode branch boundaries before editing; if repo mode
shares the search call, widen the phase and re-verify repo-mode behavior explicitly.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — global-mode branch and the
  threshold-declaration block.

**Verification**:
- `bash -n` passes.
- A `--global` run with a long description emits a marker whose `seg_count` equals the deduped
  merged total and whose `resolved=` matches it, with `requested=` consistent.
- A `--global` run against a topic with almost no corpus coverage still emits `sparse=true`.
- The `Read:` commands in the rendered output resolve: at least one is executed and returns a chunk.

---

### Phase 4: Global-mode FTS5 regression coverage [COMPLETED]

**Goal**: Make the fix durable with real-fixture tests, since `test-lit-pipeline.sh` currently
checks only `--global` script existence/executability/`bash -n`.

**Tasks**:
- [x] Add a new `section_i` to `test-lit-pipeline.sh` following Section G/H's fixture idiom *(completed)*
      (own temp `LITERATURE_DIR`, own fixture DB, resolved relative to the script's own
      `SCRIPT_DIR`), register it in `main()`'s `--runtime` block, and add its one-paragraph entry to
      the header's `Sections:` list.
- [x] Build a small real fixture `.literature.db` from `literature-schema.sql` with a handful of *(completed)*
      chunks whose content collectively contains the query's terms but never contiguously, plus a
      matching fixture `index.json` carrying `provenance_fidelity` so results are not quarantined.
- [x] Case I1 (the core regression): a long, realistic multi-word query including a literal *(completed)*
      `<sec:representation>` token returns a **non-empty** result set. This case must fail against
      the pre-fix scripts.
- [x] Case I2 (sparse honesty): a genuinely off-corpus query still yields `sparse=true`, and a query *(completed)*
      matching exactly `LITERATURE_SPARSE_THRESHOLD` segments yields `sparse=false` — exercising the
      strict `<` boundary on both sides.
- [x] Case I3 (error isolation): a query whose terms are all FTS5-hostile surfaces a non-null *(completed)*
      `query_error`, while a query mixing one hostile term with valid terms returns results and no
      hard error.
- [x] Case I4 (dedupe): a chunk matched by several terms appears exactly once, and `seg_count` *(completed)*
      counts it once.
- [x] Assert the marker line's field order and adjacency (the eight original fields, then the *(completed)*
      `delta_*` fields) so a future edit cannot silently break the Stage 4a grep.
- [x] If Case I2's genuinely-sparse query comes back `sparse=false`, apply the corroboration rule: *(completed)*
      count only chunks with `matched_terms >= 2` toward the sparse accounting when the filtered
      term count exceeds `MULTI_TERM_MATCH_THRESHOLD`, leaving the displayed result set unchanged.
      Record the decision and its trigger in the phase notes either way.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts one new test section with four cases and that Section G/H's
fixture idiom is directly reusable. Confirm by reading `section_g`/`section_h` before writing; if
the fixture helpers are not reusable for a real FTS5 DB (as opposed to an index-only fixture), state
that and budget the extra fixture-builder work rather than silently reducing case coverage.

**Files to modify**:
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — header `Sections:` list, new
  `section_i`, `main()` runtime dispatch.

**Verification**:
- `bash test-lit-pipeline.sh --runtime` passes end to end (Sections A-I), run from a location where
  the script's `PROJECT_ROOT` resolution is valid.
- Each new case is confirmed to fail when run against a stashed pre-fix copy of the two edited
  scripts — a test that passes both before and after proves nothing.

---

### Phase 5: Real-corpus verification, timing, and caller decision [COMPLETED]

**Goal**: Meet the task's verification bar against the live global corpus, quantify the cost change,
and settle the `lit-stage4a-flow.md` caller question with a written reason.

**Tasks**:
- [x] Establish the run location first: `literature-briefing.sh` derives `PROJECT_ROOT` as *(completed)*
      `$SCRIPT_DIR/../..`, which does **not** resolve to a repo root from the source-store path.
      Run the end-to-end verification against the deployed `.claude/scripts/` copy refreshed through
      the sanctioned deploy/reload path, or a temp tree laid out so the resolution is correct.
      Never hand-edit `.claude/**` to achieve this.
- [x] Re-run the original failing task description through `literature-briefing.sh --global`. It *(completed)*
      previously returned 0 segments; it must now return a non-empty, topically relevant set.
- [x] Re-derive the ground truth rather than assuming it: run *(completed)*
      `literature-coverage-delta.sh` against the same description for the matching-global-document
      count, and a set of hand-written 2-4 word searches for the reachable-segment count. Compare
      the briefing's `seg_count` against both and record all three numbers.
- [x] Record a before/after timing table (`time` on the same query against stashed pre-fix scripts *(completed)*
      vs. post-fix), in the spirit of task 108's measurement, and confirm the briefing spawns one
      `literature-search.sh` process rather than one per term.
- [x] Spot-check relevance by hand: read 2-3 of the returned chunks via their emitted `Read:` *(completed)*
      commands and confirm topical relevance, not merely non-emptiness.
- [x] Capture the marker line before and after for one genuinely-sparse and one genuinely-rich real *(completed)*
      query and confirm `sparse=` flips correctly in both.
- [x] Decide the caller question and write the reason down: if the above shows the script fix alone *(completed)*
      meets the bar, leave `lit-stage4a-flow.md`'s two `--global "$description"` call sites
      unchanged (the research's recommendation — 6 skill call sites import that file verbatim, so
      the blast radius is wide for a small marginal gain). Only if the bar is still unmet, change
      the callers to pass title + filtered terms, and then re-verify all six importing skills'
      Stage 4a blocks still read correctly.
- [x] If the callers are left unchanged, state that explicitly in the implementation summary as a *(completed)*
      ratified decision with its reason — not as an omission.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: The research reports 111 matching global documents and 131 reachable segments
for the origin query as the known-reachable ground truth. Treat both as hypotheses: re-derive them
in this phase against the current corpus (the global DB has changed since the origin session) and
report the measured numbers, flagging any material divergence rather than asserting the reported
figures.

**Files to modify**:
- None (verification only). Any fix discovered here is folded back into Phase 1-3's files.

**Verification**:
- Briefing returns a non-empty, hand-confirmed topically relevant set for the origin query.
- Measured document/segment ground truth recorded alongside the briefing's `seg_count`.
- Timing table recorded; process count confirmed as one per briefing.
- Caller decision recorded with its reason.

---

### Phase 6: Document FTS5 query semantics [NOT STARTED]

**Goal**: Record the AND-all-terms/`<`-syntax gotchas so the next contributor adding an FTS5 call
site does not re-derive them, as the origin session had to.

**Tasks**:
- [ ] Add `agent-system/extensions/literature/context/project/literature/domain/fts5-query-semantics.md`
      covering: FTS5's bareword-AND default and why long free-text queries need per-term/grouped
      search; the full FTS5-hostile character set `sanitize_query()` owns (now including `<`/`>`);
      the three-rung ladder's actual recall behavior (phrase_retry/trigram are syntax-safe but
      recall-narrow, never general recall improvements); and the multi-query envelope contract
      (`total_matched`, `matched_terms`, conservative `query_error` aggregation).
- [ ] Register the new file wherever the extension's context files are indexed (manifest/index
      entries and the extension's context pointer list), matching how sibling domain docs are
      registered.
- [ ] Cite durable anchors only — file names, function names, section headings. No task-number
      references (`rules/no-task-references-in-deliverables.md`).

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/domain/fts5-query-semantics.md` (new)
- The literature extension's context index/manifest and pointer list — exact files confirmed at
  implementation time by inspecting how a sibling `domain/*.md` doc is registered.

**Verification**:
- Diff read-through confirms every changed hunk is prose or an index entry.
- Every path and function name cited in the new doc resolves.
- `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
  task-number references.

---

## Testing & Validation

- [ ] `bash -n` clean on `literature-search.sh`, `literature-briefing.sh`, `test-lit-pipeline.sh`.
- [ ] `bash test-lit-pipeline.sh --runtime` passes Sections A-I.
- [ ] Each new Section I case demonstrably fails against stashed pre-fix scripts.
- [ ] **Primary bar**: the original failing task description through `literature-briefing.sh
      --global` returns a non-empty, topically relevant set (it returned 0 before).
- [ ] Cross-check that result against re-derived ground truth: matching global documents via
      `literature-coverage-delta.sh` (research reported 111) and reachable segments via hand-written
      2-4 word searches (research reported 131). Report measured values; flag divergence.
- [ ] Marker honesty: `sparse=true` for a genuinely sparse real query, `sparse=false` for a rich
      one; the `< threshold` boundary exercised on both sides in fixtures.
- [ ] `lit-stage4a-flow.md`'s `lit-coverage mode=global .*sparse=true` grep still matches the emitted
      marker.
- [ ] Error isolation: one hostile term among valid ones yields results and no hard `query_error`;
      all-hostile yields a non-null `query_error`.
- [ ] Repo-mode (`--query`) briefing output unchanged apart from the shared `sanitize_query()` fix.
- [ ] Timing: one `literature-search.sh` process per `--global` briefing; before/after table
      recorded.

## Artifacts & Outputs

- `specs/112_fix_briefing_fts5_over_constraint/plans/01_fix-briefing-fts5-recall.md` (this file)
- `specs/112_fix_briefing_fts5_over_constraint/summaries/01_fix-briefing-fts5-recall-summary.md`
  (implementation), including the measured ground-truth numbers, the timing table, and the ratified
  caller decision
- Modified: `agent-system/extensions/literature/scripts/literature-search.sh`
- Modified: `agent-system/extensions/literature/scripts/literature-briefing.sh`
- Modified: `agent-system/extensions/literature/scripts/test-lit-pipeline.sh`
- New: `agent-system/extensions/literature/context/project/literature/domain/fts5-query-semantics.md`
  plus its context-index registration
- Unchanged by decision (Phase 5, unless verification forces otherwise):
  `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`

## Rollback/Contingency

- Each phase is committed separately per the commit-per-green-substep mandate, so any single phase
  reverts with a targeted `git revert` without disturbing the others.
- Phase 1 is independent and always beneficial: if the merge redesign (Phases 2-3) has to be
  abandoned, keep Phase 1 — it fixes the hard syntax error for every caller on its own.
- Phase 2's additive-only envelope change means a Phase 3 revert leaves `literature-search.sh`
  fully backward compatible; the unused multi-query mode is inert.
- If the multi-query design underperforms against the real corpus in Phase 5, the documented
  fallback is the research's simpler shape — N separate `literature-search.sh` calls merged in the
  briefing by `rank` — accepting the fan-out cost and recording it as a known regression. Do not
  fall back silently.
- If verification cannot reach the corpus at all (missing global DB), mark the affected phase
  `[BLOCKED]` with the reason rather than declaring the bar met on fixtures alone — fixture passes
  are necessary but not sufficient for this task's verification bar.
