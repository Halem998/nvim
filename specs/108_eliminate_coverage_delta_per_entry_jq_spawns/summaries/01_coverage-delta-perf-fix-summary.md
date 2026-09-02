# Implementation Summary: Task #108

- **Task**: 108 - Eliminate literature-coverage-delta.sh per-entry jq spawns so --lit stops timing out
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_coverage-delta-perf-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Applied both halves of the validated combined performance fix to the topic-scoped coverage-delta
guard: single-pass jq `@tsv` extraction in `literature-coverage-delta.sh` (eliminating the
per-entry `echo | jq` triple-spawn) and fork-free pure-bash `to_lower`/`term_matches` in
`literature-term-match.sh` (eliminating the dominant `echo|tr`/`echo|grep` fork cost). All five
plan phases completed. The candidate-set equivalence gate passed cleanly across 7 test queries
(byte-identical, order-preserved id lists and `delta_candidates` counts), a full-corpus
non-ASCII/locale divergence audit found exactly one entry with a fold difference (informational,
did not affect any test query), and the full `test-lit-pipeline.sh --runtime` suite (44 checks,
including all 6 Section H coverage-delta regression cases) passed.

## What Changed

- `agent-system/extensions/literature/scripts/literature-term-match.sh` — `to_lower()` replaced
  with `printf '%s' "${1,,}"`; `term_matches()` replaced with fork-free `${1,,}`/`${2,,}` folding
  plus `[[ "$haystack" == *"$needle"* ]]`. Header contract comment extended with an
  "Implementation note (fork-free)" paragraph documenting the two accepted behavioral deltas
  (non-ASCII case-fold difference vs. `tr`; no trailing-newline stripping / no `-n`/`-e` echo-option
  swallowing). `filter_terms`, `STOP_WORDS`, and `MULTI_TERM_MATCH_THRESHOLD` untouched.
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` — the keyword-pass
  loop feeder (originally lines 166-212, confirmed unchanged from research's citation) replaced
  with a single jq pass emitting `[(.id // .doc_id // ""), (.title // ""), ((.keywords // []) |
  join(" "))] | @tsv`, consumed by `while IFS=$'\t' read -r doc_id title keywords`. The
  `.id // .doc_id` tolerance, the empty-`doc_id` skip, the `SUB_KEYS` sub-index exclusion, the
  match-rule block (`>= 2` distinct hits above `MULTI_TERM_MATCH_THRESHOLD`, accept-on-first-hit
  at or below it), the `delta_candidates` increment, and the bounded `top_n` accumulation are all
  preserved verbatim. The now-unreachable `[ "$entry" = "null" ]` guard was removed (the existing
  empty-`doc_id` skip already covers an all-empty `@tsv` record). Added a caveat comment
  documenting the `@tsv` display-fidelity limitation directly above the loop.
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/` (new, task-directory-only) —
  `run-delta-compare.sh` equivalence harness; `before/` and `after/` pristine/edited script
  snapshots with isolated fake 2-entry sub-indices; `baseline/` and `after-capture/` per-query
  captures (stdout, stderr, sorted candidate-id lists, wall time, summary TSV);
  `divergence-audit/` (corpus-wide fold-divergence report, id-list diffs); `discover-spotcheck/`
  (second-consumer Tier 1 regression check).

## Decisions

- Ran the equivalence harness with `--top-n 1000` (the plan's requirement) so the FULL unbounded
  candidate list is captured and diffed, not just the bounded default top-5 output.
- Chose an isolated fake-root nesting (`harness/{before,after}/fakeroot/scripts/...` +
  `harness/{before,after}/specs/literature-index.json`) so the guard's own `PROJECT_ROOT =
  SCRIPT_DIR/../..` path resolution lands on a harness-local fake sub-index rather than the real
  `specs/literature-index.json` (which does not currently exist in this repo) — avoids any risk of
  the harness run touching real repo state.
- Fixed a bug discovered in the harness's own stdout-parsing regex during Phase 1: `grep -oE
  'candidates=[^ ]*'` also matched the embedded substring `candidates=107` inside
  `delta_candidates=107`, corrupting the id list with a spurious `"107"` entry. Replaced with a
  positional `read -r` split (the stdout line's first 6 fields are provably space-free; only the
  final `candidate_titles` JSON array can contain spaces). Caught before the baseline was
  committed; the committed baseline reflects the corrected parsing.
- No `LC_ALL=C` remediation applied for the one divergent corpus entry (see Equivalence Result
  below) — not needed given the clean per-query candidate-set result, and pinning would foreclose
  a one-entry correctness improvement rather than fix a regression.

## Plan Deviations

- None (implementation followed plan).

## Equivalence Result (the performance-task gate)

**Per-query candidate-set diff: CLEAN.** All 7 harness queries (the 5 from the research report
plus 2 deliberately targeting non-ASCII-titled entries) produced byte-identical, order-preserved
`candidate-ids.sorted.txt` output and identical `delta_candidates` counts between the BEFORE and
AFTER snapshots:

| Query | delta_candidates (before = after) |
|---|---|
| q1 modal/temporal (10-term) | 107 |
| q2 erdos graph theory | 72 |
| q3 since/until tense operator | 49 |
| q4 quantum field theory | 64 |
| q5 finite model theory / EF games | 38 |
| q6 buchi automata (non-ASCII target) | 21 |
| q7 erdos renyi random (non-ASCII target) | 5 |

**Whole-corpus non-ASCII/locale divergence audit**: of 292 top-level entries (unchanged from
research), 30 contain non-ASCII characters (unchanged from research). Exactly **1 entry**
diverges in its case-fold: `doets_1989` ("Monadic Π¹₁-Theories of Π¹₁-Properties") — the Greek
capital Pi (`Π`, U+03A0) folds to `π` under `${var,,}` but is left untouched by `tr
'[:upper:]' '[:lower:]'`. This divergence can only ever ADD a match relative to the old behavior
(never remove one — proven: wherever `tr`-folded forms were already byte-identical, the
characters compared were either matching ASCII or the literal same non-ASCII character, and
`${var,,}` folds any given character deterministically, so a pre-existing match cannot become a
non-match). It did not manifest in any of the 7 test queries because none contain a Greek-letter
term (0 of the 7 queries' filtered terms diverge under the two fold methods either).

**Decision gate: PASSED.** Per the plan's own rule, a clean candidate-set diff means the
divergence audit is recorded as informational and the implementation proceeds without
remediation. No `LC_ALL=C` pinning was applied.

**Second `to_lower` consumer** (`literature-discover.sh`'s `SEEN_TITLES` title-dedup): both
trailing-newline-stripping and `-n`/`-e`-swallowing deltas are unreachable at every current
`to_lower` call site (all three wrap the call in `$(...)`, which already stripped trailing
newlines under the OLD implementation too; all pass single-line pre-tokenized strings). The
Tier 1 second-consumer regression spot-check (see below) confirms no observable change.

## Timing (measured, not restated from research)

Per-query wall time against the live `~/Projects/Literature/index.json` (292 top-level docs /
11,545 total entries), `--top-n 1000`:

| Query | Before (s) | After (s) | Speedup |
|---|---|---|---|
| q1 modal/temporal (10-term) | 32.322 | 0.275 | ~117x |
| q2 erdos graph theory | 14.419 | 0.222 | ~65x |
| q3 since/until tense operator | 17.491 | 0.270 | ~65x |
| q4 quantum field theory | 17.805 | 0.218 | ~82x |
| q5 finite model theory / EF games | 24.765 | 0.253 | ~98x |
| q6 buchi automata | 9.906 | 0.211 | ~47x |
| q7 erdos renyi random | 15.135 | 0.215 | ~70x |
| **Total (7 queries)** | **132.0s (2m12s)** | **1.737s** | **~76x** |

Every query now completes in a fraction of a second, well under the "a few seconds" bar the
research report set, and comfortably clear of the 120s tool-timeout that originally motivated this
task (the origin incident observed 4-5 minutes against the live corpus). Full end-to-end
regression: `test-lit-pipeline.sh --runtime` (44 checks total, including all 6 Section H cases)
completed in 1.495s with 0/44 failures.

## File-Overlap Resolution (required statement)

**`literature-term-match.sh` WAS modified** by this task (`to_lower` and `term_matches` bodies
replaced). Per the plan's Research Integration section, this overlap with the serialized FTS5
briefing task is real and was not avoided — that task must stay blocked pending this task's
completion (now done) and any necessary rebase/coordination on `literature-term-match.sh`.

**`literature-lit-flag-resolve.sh` was NOT touched** — confirmed via `git status --porcelain`
showing no changes to that file. It was in the declared `file_scope` but, as research anticipated,
no defect was found there requiring an edit.

**No file under `.claude/**` was written** — confirmed via `git status --porcelain .claude/`
(empty). All edits landed in the source store (`agent-system/extensions/literature/scripts/`) per
`rules/source-store-deploy-boundary.md`. A `.claude/` redeploy is a separate, user-triggered step
required for these changes to reach deployed copies of the two scripts.

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `test-lit-pipeline.sh --runtime`: 44/44 passed, 0 failed, 0 warnings (all
  Section H cases: H1 fires, H2 negative control, H3 chunk-inflation, H4 not-computed, H5
  fail-open, H6 `>=` boundary)
- `bash -n` clean on both edited scripts
- No `echo "$entry" | jq` construct remains in `literature-coverage-delta.sh`
- Candidate-set equivalence: 7/7 queries byte-identical (BEFORE vs. AFTER), full unbounded lists
- `literature-discover.sh` Tier 1 second-consumer spot-check: byte-identical results before/after
- Files verified: Yes

## Impacts

- `--lit` dispatches whose sub-index clears the sparsity floor and whose global-vs-subindex gap
  clears `LITERATURE_COVERAGE_GAP_MIN` (25 by default) no longer risk a 120s tool timeout or the
  4-5 minute worst case observed in the origin incident — the guard now completes in well under
  1 second against the current live corpus.
- `literature-discover.sh`'s Tier 1 keyword search shares the same `to_lower`/`term_matches`
  helper and inherits the same fork-free speedup and the same (informational, non-manifesting)
  non-ASCII fold-divergence profile.
- The serialized FTS5 briefing task remains correctly blocked on `literature-term-match.sh`
  (this task's edits to that file are now the current baseline it must account for).

## Follow-ups

- Optional (not implemented): re-fetch raw, unescaped titles only for the bounded `top_n` output
  rows of `candidate_titles`, to eliminate the cosmetic `@tsv`-escaping display caveat for a title
  containing a literal tab/newline/backslash (zero such titles exist in the live corpus today).
- No caching was added, per the plan's explicit non-goal — the ~2-orders-of-magnitude speedup
  already clears the freshness-vs-latency tradeoff without invalidation-correctness burden.

## References

- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/plans/01_coverage-delta-perf-fix.md`
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/reports/01_coverage-delta-perf.md`
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/` (equivalence harness, baseline
  and after captures, divergence audit, discover.sh spot-check)
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh`
- `agent-system/extensions/literature/scripts/literature-term-match.sh`
