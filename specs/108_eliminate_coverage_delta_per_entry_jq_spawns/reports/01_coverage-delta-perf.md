# Research Report: Task #108

**Task**: 108 - Eliminate coverage-delta guard per-entry jq spawns (make `--lit` fast)
**Started**: 2026-09-01
**Completed**: 2026-09-01
**Effort**: Small (single-file bash rewrite + one shared-helper change)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/literature/scripts/`), live benchmarking against the real `~/Projects/Literature/index.json` (11,545 entries, 292 top-level docs), `test-lit-pipeline.sh` Section H
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The parent_doc top-level filter the origin defect proposed is already in place
  (`literature-coverage-delta.sh:212`) — confirmed, no work needed there.
- **The per-entry `echo | jq` triple-spawn (lines 171-173) is real but is NOT the dominant
  cost.** Benchmarked in isolation it accounts for only ~30% of wall time (~11s of ~33s on the
  live 292-top-level-doc corpus).
- **The dominant cost (~65-70%) is `literature-term-match.sh`'s `to_lower()`/`term_matches()`
  helpers**, which fork `echo|tr` and `echo|grep` for every term comparison inside the
  per-candidate matching loop — invoked up to `2 x FILTERED_TERM_COUNT` times per candidate
  document. This was not named in the origin defect and must be fixed for the guard to actually
  land in "a few seconds."
- Recommended fix: (1) collapse the three per-entry jq spawns into one `@tsv`-emitting jq pass
  feeding a `while IFS=$'\t' read` loop, **and** (2) replace `to_lower`/`term_matches` in
  `literature-term-match.sh` with pure-bash equivalents (`${var,,}` / `[[ == *pat* ]]`) — no
  subprocess forks. Combined, measured wall time drops from **33.36s to 0.18s** (≈181x) on the
  live 292-doc corpus, with byte-identical candidate sets across 5 test queries.
- No caching is warranted: the combined fix alone clears the "a few seconds" bar by roughly two
  orders of magnitude, so the caching alternative in the task brief is not needed.
- **File-overlap resolution for the serialized FTS5 task**: this task's fix DOES require editing
  `literature-term-match.sh` (`to_lower`, `term_matches`). The serialized task should NOT be
  unblocked early on the assumption this task avoided that file — it does not.

## Context & Scope

Origin: a `/research 503 --lit` run in the BimodalLogic repo where the topic-scoped
coverage-delta guard (`literature-coverage-delta.sh`, invoked unconditionally from
`literature-lit-flag-resolve.sh:164-193` on every `--lit` dispatch once a sub-index clears the
absolute sparsity floor) exceeded a 120s tool timeout and took 4-5 minutes to complete against an
11,545-entry global index.

The task brief pre-empted the most obvious fix (restricting the keyword pass to top-level docs)
as already implemented, and directed research at the per-entry `echo "$entry" | jq ...` calls at
`literature-coverage-delta.sh:171-173` as "the hot path," proposing a single consolidated jq pass
as the primary fix, with caching as a secondary fallback only if that proves insufficient.

Scope for this research: measure the real cost breakdown (not just count the jq spawns),
validate a rewrite against the live global index for both speed and exact candidate-set
equivalence, and determine whether the primary fix alone clears the "few seconds" bar or whether
the caching fallback (or an additional fix) is actually needed.

## Findings

### Codebase Patterns

- `literature-coverage-delta.sh:212` already filters the global index's flat `.entries` array to
  `select(.parent_doc == null or .parent_doc == "")` before the loop body runs — the
  chunk-inflation fix from the origin defect. Confirmed unmodified, no further action here.
- The keyword-match loop (`literature-coverage-delta.sh:166-212`) sources
  `literature-term-match.sh` (`literature-coverage-delta.sh:145`) and reuses its
  `filter_terms`/`term_matches`/`MULTI_TERM_MATCH_THRESHOLD` exactly as `literature-discover.sh`'s
  Tier 1 matcher does (`literature-discover.sh:200-328` also calls `to_lower`/`term_matches`
  directly). Any change to the shared helper's *implementation* (not its external contract)
  benefits both call sites; a change to its *matching semantics* would affect both and is out of
  scope here.
- `literature-term-match.sh:39-52` implements `to_lower()` as `echo "$1" | tr '[:upper:]'
  '[:lower:]'` and `term_matches()` as two `to_lower` calls plus `echo "$haystack" | grep -qF
  "$needle"` — each `term_matches()` invocation forks 6 subprocesses (2 pipes x 2 procs +
  1 pipe x 2 procs). This is called up to `2 x FILTERED_TERM_COUNT` times per surviving candidate
  document (title check + keywords check, per filtered term, until the multi-term
  accept-threshold is met or all terms are exhausted).
- The codebase already assumes bash 4+ elsewhere in this same extension
  (`literature-ingest.sh`, `literature-convert.sh` use `${var,,}`; `literature-coverage-delta.sh`
  itself uses `declare -A` associative arrays), so a pure-bash `${var,,}` / `[[ == *pat* ]]`
  rewrite introduces no new portability constraint.

### Benchmark: cost breakdown (live global index, 292 top-level docs of 11,545 total entries)

Query used (10 filtered terms, exercises the `> MULTI_TERM_MATCH_THRESHOLD` branch): `"modal
logic temporal completeness axiomatization graphs games monadic theory canonicity"`. Sub-index
forced to 2 dummy entries so `delta_gap=290 >= LITERATURE_COVERAGE_GAP_MIN` and the keyword pass
actually runs.

| Variant | Wall time | sys time | delta_candidates | Top-5 candidate ids |
|---|---|---|---|---|
| Current script (unmodified) | 33.356s | 18.6s | 107 | identical set (below) |
| Isolated single-pass jq extraction only (no bash loop) | 0.121s | 0.013s | n/a (extraction only) | n/a |
| Rewrite: single-pass jq only, `term_matches` unchanged | 29.686s | 16.7s | 107 | identical |
| **Rewrite: single-pass jq + pure-bash `term_matches`/`to_lower`** | **0.184s** | 0.031s | 107 | identical |

The single-pass-jq-only variant (what the task brief's primary fix direction describes) removes
only ~11% of wall time on this corpus — it does not clear a "few seconds" bar by itself. The
dominant cost is the `term_matches`/`to_lower` subprocess forking, confirmed by a microbenchmark:
1000 bare `term_matches` calls took 6.818s (~6.8ms/call, dominated by fork/exec), vs. 0.019s for
1000 calls of a pure-bash equivalent (`${var,,}` + `[[ == *pat* ]]`) — a ~360x per-call speedup.
The high `sys` time (16-18s out of ~30-33s real) in every variant that still calls
`term_matches`/`to_lower` corroborates that fork/exec syscall overhead, not jq parsing itself, is
the bottleneck.

### Correctness verification: candidate-set equivalence

Ran the current script and the full rewrite (single-pass jq + pure-bash term matching) against
the live global index for 5 different queries chosen to exercise both match-threshold branches
(a 10-term query above threshold, and four shorter queries at/under
`MULTI_TERM_MATCH_THRESHOLD=5`), with `--top-n 1000` on both sides to compare the *entire*
candidate list, not just the bounded top-N:

| Query | delta_candidates | Full candidate-id list identical? |
|---|---|---|
| `modal logic temporal completeness axiomatization graphs games monadic theory canonicity` | 107 | Yes (byte-identical, order preserved) |
| `erdos graph theory` | 72 | Yes |
| `since until tense operator` | 49 | Yes |
| `quantum field theory renormalization` | 64 | Yes |
| `finite model theory ehrenfeucht fraisse games composition` | 38 | Yes |

All five produced byte-identical ordered candidate-id lists and identical `delta_candidates`
counts between the current script and the rewrite. Match semantics (parent_doc filter, sub-index
exclusion, `.id // .doc_id` fallback, `>= 2` vs. accept-on-first-hit branch selection) were not
touched.

### Edge-case verification: `@tsv` field-delimiter safety

The proposed single jq pass emits `[(.id // .doc_id // ""), (.title // ""), ((.keywords // [])
| join(" "))] | @tsv`, consumed by `while IFS=$'\t' read -r doc_id title keywords`. Verified
against the live corpus that **zero** top-level titles or keyword strings contain a literal tab
or backslash character today. Additionally constructed a synthetic index with a title containing
a literal tab, a literal backslash, and a quote character, plus an entry with `"id": ""` (jq's
`//` treats empty string as truthy, not falsy — confirmed the fallback chain
`.id // .doc_id // ""` behaves identically whether done per-entry or in the single pass) and a
`doc_id`-only fallback entry. Result: jq's `@tsv` escapes literal tabs/newlines/backslashes
*within* a field as two-character sequences (`\t`, `\\`) so the real tab *between* fields is
never ambiguous — `IFS=$'\t' read` splits fields correctly in every case tested, and the
empty-id and `doc_id`-fallback skip/match logic is unchanged.

**One real, narrow, low-severity caveat**: for a title or keyword string that literally contains
a tab, newline, or backslash character, the single-pass `@tsv` extraction returns that substring
jq-escaped (e.g. `\t` as two characters) rather than the raw character the current
per-entry-`jq -r '.title'` extraction would return. This is invisible to the matching logic
(`term_matches` only does substring comparison, and `filter_terms` never produces a term
containing those characters), so it cannot change which documents are selected — it would only
cosmetically affect the `candidate_titles` JSON field's displayed text for such an entry. No
entry in the live corpus is affected today. If exact-fidelity display matters going forward, the
plan should consider re-fetching the raw title with a second jq call only for the (at most
`top_n`, default 5) entries actually selected for output, rather than for all top-level docs —
this preserves the O(1)-per-run cost while removing the caveat entirely.

### Recommendations

1. In `literature-coverage-delta.sh`, replace the per-entry `while IFS= read -r entry; do
   doc_id=$(echo "$entry" | jq ...); title=$(echo "$entry" | jq ...); keywords=$(echo "$entry" |
   jq ...); ... done < <(jq -c '.entries[] | select(...)' ...)` (lines 166-212) with a single jq
   pass emitting `@tsv` records (doc_id, title, space-joined keywords) already filtered to
   top-level docs, consumed via `while IFS=$'\t' read -r doc_id title keywords`. Preserve the
   `.id // .doc_id // ""` tolerance and the empty-doc_id skip exactly.
2. In `literature-term-match.sh`, replace `to_lower()`'s `echo | tr` pipe and `term_matches()`'s
   `echo | grep -qF` pipe with pure-bash equivalents: `${1,,}` for lowercasing and `[[
   "$haystack" == *"$needle"* ]]` for the case-insensitive substring test. This is the change
   that actually clears the "few seconds" bar; the jq consolidation alone does not. Preserve the
   function names/signatures and the `MULTI_TERM_MATCH_THRESHOLD`/`filter_terms` contract
   unchanged (`literature-discover.sh` depends on the same signatures).
3. Do not add caching. The combined fix measures at 0.184s (from 33.356s) on the live corpus —
   roughly two orders of magnitude under the "a few seconds" bar the task brief sets as the
   threshold for skipping caching. Scaling linearly from the measured ~0.63ms/top-level-doc, even
   a corpus where every one of the global index's 11,545 entries were (implausibly) a top-level
   doc would land under ~10s — caching would add invalidation-correctness burden for no
   remaining measured benefit.
4. Optional refinement (not required to clear the performance bar, worth a line in the plan):
   only re-extract the *raw* (non-`@tsv`-escaped) title for the bounded `top_n` candidates
   actually selected for `candidate_titles` output, closing the cosmetic edge case named above.

## Decisions

- Confirmed the origin defect's premise that the parent_doc filter is already implemented — no
  work item needed for that.
- Rejected "single jq pass only" as sufficient — it is necessary but not sufficient; the
  `literature-term-match.sh` subprocess-forking helpers are the larger cost and must also change.
- Rejected adding a cache — the two combined code changes already exceed the required speedup by
  a wide margin, and a cache would add freshness-invalidation risk to a guard whose entire
  purpose is up-to-date coverage detection.
- **File-overlap determination for the serialized FTS5 task**: this task's implementation WILL
  modify `literature-term-match.sh` (`to_lower`, `term_matches`). Per the task brief's own
  instruction, this is reported explicitly so the serialized FTS5 task is NOT unblocked early —
  the file overlap is real, not avoided.

## Risks & Mitigations

- **Risk**: a future title/keyword containing a literal tab, newline, or backslash would show
  jq-escaped text in `candidate_titles` output instead of the raw character. **Mitigation**:
  documented above as cosmetic-only (does not affect which documents match); optional follow-up
  fix (re-extract raw title only for the bounded output candidates) fully closes it if desired.
- **Risk**: changing `to_lower`/`term_matches` in the shared helper file also changes the
  runtime characteristics (not the output) of `literature-discover.sh`'s Tier 1 search, which
  sources the same file. **Mitigation**: the replacement preserves exact matching semantics
  (case-insensitive substring match) and function signatures; `literature-discover.sh` should
  also benefit from the speedup as a byproduct, but its own test coverage should be re-run as
  part of implementation verification since it is a second consumer of the changed file.
- **Risk**: `${var,,}` requires bash 4+. **Mitigation**: confirmed this script and sibling
  scripts in the same extension already require bash 4+ (associative arrays, existing `${var,,}`
  usage elsewhere in the extension) — no new constraint introduced.

## Context Extension Recommendations

None — the existing `context/project/literature/domain/sparse-coverage.md` already documents the
coverage-delta guard's design and fail-open contract at the right level of detail; this
performance fix does not change the guard's external contract (its stdout line shape, fail-open
behavior, and match semantics are all unchanged) and needs no new context file.

## Appendix

### Commands/queries used

- `jq '.entries | length'` / `jq '[.entries[] | select(.parent_doc == null or .parent_doc == "")] | length'` against `~/Projects/Literature/index.json` (11,545 entries; 292 top-level).
- `time bash literature-coverage-delta.sh --query "..." --top-n N` against a temp fake repo
  (`specs/literature-index.json` with 2 dummy entries) to force `delta_gap >= LITERATURE_COVERAGE_GAP_MIN`.
- Isolated microbenchmark: `time for i in $(seq 1 1000); do term_matches "..." "..." ; done` (current helper) vs. a pure-bash equivalent.
- A candidate rewrite script combining the single-pass jq extraction and pure-bash term matching, run against the live global index for 5 queries with `--top-n 1000`, diffed against the current script's output for exact candidate-set equivalence.
- Synthetic index (`/tmp/synthetic_index.json`) with a tab/backslash/quote-bearing title, an
  empty-`id` entry, and a `doc_id`-only-fallback entry, to verify `@tsv` field-delimiter safety
  and the `.id // .doc_id // ""` fallback chain.

### Verification bar for implementation

- Before/after `time` of `literature-coverage-delta.sh` against the live global index (already
  captured above: 33.356s -> 0.184s).
- Diff the full (unbounded, `--top-n` set high) candidate-id list for several queries, before vs.
  after (already captured above: 5/5 queries byte-identical).
- Run `test-lit-pipeline.sh`'s Section H (`--runtime`) regression suite, which exercises the
  guard's fire/no-fire/chunk-inflation/not-computed/boundary cases end-to-end through
  `literature-lit-flag-resolve.sh` and `literature-briefing.sh`.
- Because `literature-term-match.sh` is shared, also spot-check `literature-discover.sh`'s Tier 1
  keyword search still returns the same results after the helper rewrite.
