# Implementation Plan: Task #108

- **Task**: 108 - Eliminate literature-coverage-delta.sh per-entry jq spawns so --lit stops timing out
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/108_eliminate_coverage_delta_per_entry_jq_spawns/reports/01_coverage-delta-perf.md
- **Artifacts**: plans/01_coverage-delta-perf-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The topic-scoped coverage-delta guard (`literature-coverage-delta.sh`) is invoked unconditionally
by `literature-lit-flag-resolve.sh` on every `--lit` dispatch whose sub-index clears the absolute
sparsity floor, and currently costs ~33s wall against the live 292-top-level-doc global index
(observed at 4-5 minutes / past a 120s tool timeout in the origin incident). Research measured the
cost split and found the per-entry `echo | jq` triple-spawn is only ~30% of it; the dominant
~65-70% is `literature-term-match.sh`'s `to_lower()`/`term_matches()` helpers forking `echo|tr` and
`echo|grep` per term comparison. This plan applies both halves of the validated combined fix —
single-pass jq `@tsv` extraction plus pure-bash term matching — and gates them behind an
equivalence proof that the candidate set is unchanged.

This is a PERFORMANCE task. A speedup with a changed candidate set is a failed implementation, not
a partial success. Every phase after the edits exists to prove the candidate set did not move, and
to surface (never silently absorb) any divergence found.

### Research Integration

Findings from `reports/01_coverage-delta-perf.md` that this plan is built on:

- The `parent_doc` top-level filter is **already implemented** at the loop feeder
  (`literature-coverage-delta.sh:212`). No work item exists for it; re-proposing it is a no-op.
- Corrected cost model: single-pass-jq-only measures 33.36s -> 29.69s (~11% of wall time). The
  combined fix (single-pass jq + pure-bash `to_lower`/`term_matches`) measures 33.36s -> 0.184s
  (~181x), with byte-identical candidate-id lists across 5 test queries covering both
  match-threshold branches.
- Microbenchmark: `term_matches` 6.8ms/call (fork/exec dominated, corroborated by 16-18s of the
  ~33s being `sys` time) vs. 0.019ms/call pure-bash.
- **No caching.** The combined fix clears the "a few seconds" bar by ~2 orders of magnitude; a
  cache would add invalidation-correctness burden to a guard whose whole purpose is freshness.
- `@tsv` escapes literal tab/backslash/newline *within* a field, so `IFS=$'\t' read` splits
  correctly; the only residual is a cosmetic display-fidelity caveat on `candidate_titles` for a
  title containing such a character (zero such titles in the live corpus today).
- **File-overlap resolution**: this fix DOES modify `literature-term-match.sh`. The serialized
  FTS5 briefing task must stay blocked; the overlap is real, not avoided. This must be stated
  explicitly in the implementation summary.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (`specs/ROADMAP.md` does not exist in this repository).

## Goals & Non-Goals

**Goals**:
- Collapse the per-entry `echo | jq` triple-spawn in `literature-coverage-delta.sh`'s keyword loop
  into a single `@tsv`-emitting jq pass consumed by `while IFS=$'\t' read -r doc_id title keywords`.
- Replace `to_lower()`'s `echo | tr` pipe and `term_matches()`'s `echo | grep -qF` pipe in
  `literature-term-match.sh` with fork-free pure-bash equivalents.
- Prove the emitted candidate-id set is unchanged, over the *full unbounded* list (not just the
  bounded top-n output), across queries exercising both match-threshold branches.
- Record before/after wall-clock timing against the live global index.
- Keep both consumers of the shared helper (`literature-coverage-delta.sh`,
  `literature-discover.sh`) behaviorally unchanged.

**Non-Goals**:
- No caching of the delta result (explicitly rejected by research; see Overview).
- No change to match semantics: the `>= 2` distinct-hit rule above `MULTI_TERM_MATCH_THRESHOLD`,
  accept-on-first-hit at or below it, the `.id // .doc_id` tolerance, the empty-`doc_id` skip, the
  sub-index exclusion, and the `parent_doc` top-level filter all stay exactly as they are.
- No change to the guard's external contract: stdout line shape, `fail_open` behavior, stderr
  rationale line, and exit codes are untouched.
- No change to `filter_terms`'s or `MULTI_TERM_MATCH_THRESHOLD`'s external contract (signatures,
  stop-word list, 3-character floor).
- No edits under `.claude/**`. The source store `agent-system/extensions/literature/scripts/` is
  the only edit target (see `rules/source-store-deploy-boundary.md`). Redeploying `.claude/` is a
  separate, user-triggered operation and is out of scope.
- No changes to `literature-lit-flag-resolve.sh`. It is in the declared `file_scope` but research
  identified no defect there; if the implementation finds it genuinely needs an edit, that is a
  scope surprise to surface, not to absorb silently.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pure-bash `${var,,}` is locale-aware and case-folds non-ASCII uppercase (e.g. `Π`, `Ő`) where GNU `tr '[:upper:]' '[:lower:]'` operates bytewise and does not — this can *add* matches | H (a candidate-set change is a task failure by definition) | M (30 of 292 top-level title/keyword lines contain non-ASCII characters in the live corpus) | Phase 4 runs a dedicated divergence audit over the full corpus, not a sample. Any divergence is SURFACED in the summary and the plan re-decided (pin `LC_ALL=C` for the fold, or accept the change explicitly) — never silently accepted |
| `to_lower` semantic drift beyond case: `$(echo "$1" \| tr ...)` strips trailing newlines and would treat a bare `-n`/`-e` argument as an `echo` option; `${1,,}` does neither | M | L | Phase 2 records both differences explicitly and Phase 4's audit covers the second consumer (`literature-discover.sh:243,258` uses `to_lower` for title-dedup keys, where a trailing-newline difference could in principle alter dedup) |
| `grep -qF` matches line-by-line so a needle spanning a newline never matches, while `[[ == *needle* ]]` matches across newlines | L | L | `filter_terms` can never produce a term containing a newline (it splits on whitespace), so the case is unreachable from either call site; noted in Phase 2, verified by the Phase 4 full-corpus diff |
| `@tsv` returns a jq-escaped (`\t`, `\\`) substring for a title containing a literal tab/newline/backslash, changing displayed `candidate_titles` text | L (cosmetic only — `term_matches` does substring comparison and `filter_terms` never emits such characters, so selection cannot change) | L (zero affected entries in the live corpus today) | Documented as a known caveat in Phase 5 with the optional follow-up recorded (re-fetch raw titles only for the bounded top-n output rows); not implemented now |
| Changing the shared helper alters `literature-discover.sh` Tier 1 runtime behavior | M | L | Phase 5 spot-checks `literature-discover.sh` Tier 1 results before/after as a second-consumer regression |
| `${var,,}` requires bash 4+ | L | L | Already required by this extension (`declare -A` in `literature-coverage-delta.sh`, existing `${var,,}` in `literature-ingest.sh`/`literature-convert.sh`); no new constraint. Phase 2 confirms the shebang/bash version assumption holds |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 edit disjoint files
(`literature-term-match.sh` and `literature-coverage-delta.sh` respectively) and are genuinely
parallel-safe.

---

### Phase 1: Baseline capture and equivalence harness [COMPLETED]

**Goal**: Produce the BEFORE side of the verification bar and a reusable harness that can re-run
the identical comparison after the edits, so equivalence is proven mechanically rather than
eyeballed.

**Tasks**:
- [x] Write a harness script under the task directory (e.g.
      `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/run-delta-compare.sh`) that,
      for a given copy of `literature-coverage-delta.sh` + `literature-term-match.sh`, runs the
      guard against the live `~/Projects/Literature/index.json` with a forced 2-entry sub-index
      (so `delta_gap` clears `LITERATURE_COVERAGE_GAP_MIN`) and `--top-n 1000` so the FULL
      unbounded candidate list is emitted, capturing wall time and the candidate-id list per query.
      *(completed: `harness/run-delta-compare.sh`, parameterized by script-copy-root + output-dir;
      isolated fake sub-index resolved via PROJECT_ROOT=script-copy-root)*
- [x] Encode at minimum these 5 queries (from the research report, covering both branches of the
      `MULTI_TERM_MATCH_THRESHOLD` rule): the 10-term
      `modal logic temporal completeness axiomatization graphs games monadic theory canonicity`;
      `erdos graph theory`; `since until tense operator`;
      `quantum field theory renormalization`;
      `finite model theory ehrenfeucht fraisse games composition`. *(completed)*
- [x] Add at least two queries deliberately targeting non-ASCII titles in the live corpus (e.g. a
      term drawn from a `Büchi` / `Fraïssé` / `Erdős` / `Π¹₁` bearing title) so the Phase 4
      divergence audit has direct coverage rather than incidental coverage. *(completed: q6
      "buchi automata", q7 "erdos renyi random", both matching non-ASCII-titled entries)*
- [x] Snapshot the pristine `literature-coverage-delta.sh` and `literature-term-match.sh` into the
      harness directory as the BEFORE reference implementation, so the AFTER comparison does not
      depend on git checkout gymnastics mid-task. *(completed: harness/before/fakeroot/scripts/)*
- [x] Run the harness against the BEFORE snapshot; store per-query candidate-id lists,
      `delta_candidates` counts, and `time` output as committed baseline artifacts. *(completed:
      harness/baseline/SUMMARY.tsv + per-query .stdout.txt/.stderr.txt/.candidate-ids.sorted.txt/.time.txt;
      total wall 2m12s across 7 queries, per-query 9.9s-32.3s, all delta_checked=true delta_gap=290)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The harness is asserted to exercise 292 top-level docs out of 11,545 total
entries via 7+ queries. Confirm at implementation time by running
`jq '[.entries[] | select(.parent_doc == null or .parent_doc == "")] | length'` against the live
index and recording the actual number in the baseline artifact; if the corpus has changed since
research, record the new number rather than restating 292. *(confirmed: 292 top-level docs / 11,545
total entries, unchanged from research; 7 queries encoded)*

**Files to modify**:
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/` - new harness script and
  BEFORE snapshots plus captured baseline output (task-directory artifacts, not production code)

**Verification**:
- Harness runs to completion against the BEFORE snapshot and emits a non-empty candidate-id list
  for every query that research reported a non-zero `delta_candidates` for.
- Baseline wall time is in the tens of seconds (confirming the harness reproduces the reported
  slow path rather than accidentally short-circuiting via `fail_open`).
- The stderr rationale line shows `delta_checked=true`, proving the keyword pass actually ran.

---

### Phase 2: Pure-bash to_lower/term_matches in literature-term-match.sh [COMPLETED]

**Goal**: Remove the dominant cost — the per-comparison `echo|tr` and `echo|grep` forks — while
preserving the helper's documented contract for both consumers.

**Tasks**:
- [x] Replace `to_lower()`'s body with the fork-free `${1,,}` form (printed, not echoed through a
      pipe), keeping the function name and single-argument signature exactly. *(completed:
      `printf '%s' "${1,,}"`)*
- [x] Replace `term_matches()`'s body with fork-free lowercasing of both arguments plus
      `[[ "$haystack" == *"$needle"* ]]`, keeping the two-argument signature and the
      true/false-via-exit-code contract exactly. *(completed)*
- [x] Leave `filter_terms`, `STOP_WORDS`, and `MULTI_TERM_MATCH_THRESHOLD` untouched (note that
      `filter_terms` calls `to_lower` per raw token and therefore inherits the new implementation —
      this is intended, and is covered by the Phase 4 audit). *(confirmed unchanged)*
- [x] Update the file's header contract comment block to state that the helpers are fork-free
      pure-bash and that the external contract (case-insensitive substring match, exit-code
      protocol) is unchanged; do not weaken or restate the `MULTI_TERM_MATCH_THRESHOLD`
      caller-responsibility paragraph. *(completed: new "Implementation note (fork-free)"
      paragraph added directly after the existing contract paragraph, which is preserved verbatim)*
- [x] Record in a comment (or in the summary) the two known behavioral deltas versus the old
      implementation: trailing-newline stripping is no longer applied, and a leading `-n`/`-e`
      argument is no longer swallowed as an `echo` option. *(completed: recorded in the header
      comment's "Implementation note" paragraph)*
- [x] Confirm the bash 4+ assumption holds (the file is `#!/usr/bin/env bash` source-only and the
      extension already uses `declare -A` and `${var,,}` elsewhere). *(confirmed: bash 5.3.9 in
      this environment; `${var,,}`/`declare -A` already present in literature-ingest.sh,
      literature-convert.sh, and literature-coverage-delta.sh)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly two functions (`to_lower`, `term_matches`) change, and exactly two
production consumers exist (`literature-coverage-delta.sh`, `literature-discover.sh`). Confirm at
implementation time with
`grep -rn 'to_lower\|term_matches' agent-system/extensions/literature/scripts/` and record the
consumer list; note that `zotero-search.sh` defines its own independent `filter_terms` and does NOT
source this helper — confirm that separation still holds rather than assuming it. *(confirmed:
exactly two production consumers, `literature-coverage-delta.sh` and `literature-discover.sh`;
`zotero-search.sh` defines its own independent `filter_terms` at its own line 258 and does not
source `literature-term-match.sh` — separation holds)*

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-term-match.sh` - `to_lower` and
  `term_matches` bodies replaced with fork-free pure-bash; header contract comment updated

**Verification**:
- `bash -n` parses the file cleanly.
- A direct microbenchmark of 1000 `term_matches` calls completes in well under 1s (research
  baseline: 6.8s before, 0.019s after).
- A hand-run truth table confirms unchanged results for: exact match, case-mismatched match,
  substring match, empty needle (must still return true), empty haystack with non-empty needle
  (must return false).

---

### Phase 3: Single-pass @tsv extraction in literature-coverage-delta.sh [COMPLETED]

**Goal**: Eliminate the three per-entry `echo | jq` spawns by having the loop feeder emit
already-extracted fields, without touching the match rule or the output contract.

**Tasks**:
- [x] Replace the loop feeder with a single jq pass emitting
      `[(.id // .doc_id // ""), (.title // ""), ((.keywords // []) | join(" "))] | @tsv` over
      entries already filtered by the existing `select(.parent_doc == null or .parent_doc == "")`
      predicate. *(completed)*
- [x] Change the loop header to `while IFS=$'\t' read -r doc_id title keywords`, deleting the three
      `echo "$entry" | jq -r ...` assignments. *(completed)*
- [x] Preserve the `.id // .doc_id` tolerance exactly (it is load-bearing) and preserve the
      empty-`doc_id` `continue` skip exactly. *(preserved: `.id // .doc_id // ""` is the
      3-way-chained jq equivalent of the old `(.id // .doc_id) // ""`, semantically identical)*
- [x] Preserve the sub-index exclusion (`SUB_KEYS`) check, the match-rule block, the
      `delta_candidates` increment, and the bounded `top_n` `candidate_ids`/`candidate_titles`
      accumulation verbatim — none of these change. *(preserved verbatim, untouched)*
- [x] Confirm the now-unreachable `[ "$entry" = "null" ]` guard is either removed or correctly
      re-expressed for the new record shape (a blank line from an all-empty record must not be
      treated as a valid entry). *(removed; the existing empty-doc_id skip already covers an
      all-empty @tsv line, documented inline)*
- [x] Leave the stdout line and the stderr rationale line byte-identical in shape. *(unchanged —
      neither line was touched)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The change is asserted to be confined to the keyword-pass loop and its feeder
(research cited `literature-coverage-delta.sh:166-212`, pre-edit). Confirm the actual current line
span at implementation time by locating the `while IFS= read -r entry` header and its
`done < <(jq -c ...)` feeder rather than trusting the cited numbers; report the real span in the
summary. *(confirmed: pre-edit span was lines 166-212, matching the cited numbers exactly; the
loop header (166) through the `done < <(...)` feeder (212) is the entirety of the edit)*

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` - keyword-pass loop
  feeder and field extraction replaced with a single `@tsv` jq pass

**Verification**:
- `bash -n` parses the file cleanly.
- No `echo "$entry" | jq` construct remains anywhere in the file
  (`grep -n 'echo "\$entry"' ` returns nothing).
- A run against the live index emits a `delta_checked=true` stdout line whose field names and order
  are unchanged from the Phase 1 baseline capture.

---

### Phase 4: Candidate-set equivalence and non-ASCII/locale divergence audit [COMPLETED]

**Goal**: Prove the candidate set did not move, and specifically resolve the one risk that could
legitimately move it — the locale-aware case-folding difference between `${var,,}` and
`tr '[:upper:]' '[:lower:]'`.

**Tasks**:
- [x] Re-run the Phase 1 harness against the edited source-store scripts and diff the full
      unbounded candidate-id list per query against the stored BEFORE lists. Byte-identical,
      order-preserved output is the pass condition. *(completed: `harness/after-capture/`; 7/7
      queries byte-identical to `harness/baseline/`, see `harness/divergence-audit/id-list-diffs.txt`)*
- [x] Diff `delta_candidates` counts per query as an independent check on the id-list diff.
      *(completed: identical for every query — 107, 72, 49, 64, 38, 21, 5)*
- [x] Run the dedicated divergence audit over the WHOLE corpus, not a sample: for every top-level
      doc, compute both the old (`echo|tr`) and new (`${var,,}`) folded forms of title and joined
      keywords and report every entry where they differ. Do the same for the folded forms of every
      filtered query term. *(completed: `harness/divergence-audit/corpus-fold-divergence.txt`; 1 of
      292 top-level entries diverges — `doets_1989` "Monadic Π¹₁-Theories of Π¹₁-Properties" (Greek
      Π folds to π under `${var,,}`, untouched by `tr`); 0 of the 7 harness queries' filtered terms
      diverge)*
- [x] For each divergence found, determine whether it can change a match decision (it can only ever
      ADD a match, since the new fold is strictly more aggressive). Record the count and the
      affected entries. *(completed: 1 entry, `doets_1989`; confirmed add-only per the plan's risk
      analysis; did not manifest in any harness query since none contain a Greek-letter term)*
- [x] **Decision gate**: if the full candidate-set diff is clean, record the divergence audit as
      informational and proceed. If ANY query's candidate set changed, STOP — do not proceed to
      Phase 5. Surface the change with the specific entries and terms involved, and record the two
      remediation options (pin `LC_ALL=C` around the fold to restore byte-exact `tr` parity, or
      accept the change as a deliberate correctness improvement) as a decision for the user rather
      than choosing one unilaterally. *(GATE PASSED: candidate-set diff is clean across all 7
      queries; divergence audit recorded as informational per the plan's own rule; proceeding to
      Phase 5 — no `LC_ALL=C` pinning applied, see conclusion in
      `harness/divergence-audit/corpus-fold-divergence.txt`)*
- [x] Audit the second `to_lower` consumer path: confirm `literature-discover.sh`'s title-dedup use
      (`SEEN_TITLES` accumulation and the dedup comparison) is unaffected by the trailing-newline
      and `-n`/`-e` deltas recorded in Phase 2. *(completed: both deltas are unreachable at every
      current to_lower call site — all wrap the call in `$(...)`, which already stripped trailing
      newlines under the OLD implementation too, and all pass single-line pre-tokenized
      titles/terms, never a bare `-n`/`-e` argument; see corpus-fold-divergence.txt)*

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: 30 of the top-level title/keyword lines in the live corpus contain non-ASCII
characters, and the subset containing non-ASCII UPPERCASE characters (the only ones that can
diverge) is expected to be smaller still. Confirm at implementation time by running the audit over
the full corpus and reporting the real counts for both figures; do not restate 30 without
re-measuring. *(confirmed: 30 of 292 top-level title/keyword lines contain non-ASCII characters,
unchanged from research; of those, exactly 1 entry — `doets_1989` — contains a non-ASCII uppercase
character (Greek Π) whose fold actually diverges between the two methods)*

**Files to modify**:
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/` - AFTER capture, per-query
  diffs, and the divergence-audit output (task-directory artifacts)

**Verification**:
- Per-query candidate-id diffs are empty for every harness query.
- `delta_candidates` counts match the baseline for every query.
- The divergence audit output exists, names its measured counts, and its conclusion (clean, or
  STOP-with-surfaced-change) is recorded explicitly.

---

### Phase 5: End-to-end regression, timing record, and caveat documentation [COMPLETED]

**Goal**: Confirm the guard still behaves correctly end-to-end through its real callers, record the
measured speedup, and leave the known caveats and the file-overlap resolution on the record.

**Tasks**:
- [x] Run `test-lit-pipeline.sh --runtime` and confirm Section H (the coverage-delta guard
      regression suite: fire H1, silent-on-non-match H2, chunk-inflation H3, not-computed H4,
      fail-open H5, `>=` boundary H6) passes. Confirm the rest of the suite is no worse than its
      pre-change state. *(completed: full suite 44/44 passed, 0 failed, 0 warnings, including all
      6 Section H cases)*
- [x] Spot-check `literature-discover.sh` Tier 1 keyword search before/after the shared-helper
      change (same query, same global index, same results) as the second-consumer regression the
      research report calls for. *(completed: `harness/discover-spotcheck/`; query "ehrenfeucht
      fraisse games composition finite model theory" against the live global index; tier1-only
      results byte-identical before/after — 4 doc_ids: hodkinson_2006, blackburn_2002_book,
      libkin_2004_ch3_ch7, thomas_1997)*
- [x] Record before/after wall-clock timing against the live global index in the implementation
      summary, using the numbers measured in Phases 1 and 4 (not the research report's numbers
      restated). *(completed — see implementation summary)*
- [x] Document the `@tsv` display-fidelity caveat as a comment near the new jq pass: for a title or
      keyword containing a literal tab, newline, or backslash, `candidate_titles` shows the
      jq-escaped form; matching is unaffected. Record the optional follow-up (re-fetch raw titles
      only for the bounded top-n output rows) as a named future refinement, not implemented now.
      *(completed: comment added directly above the `while IFS=$'\t' read` loop)*
- [x] State explicitly in the implementation summary that `literature-term-match.sh` WAS modified,
      so the serialized FTS5 briefing task stays blocked — the file overlap is real, not avoided.
      This is a required, load-bearing statement, not a nicety. *(completed — see implementation
      summary's File-Overlap Resolution section)*
- [x] State explicitly whether `literature-lit-flag-resolve.sh` was touched (expected: not touched)
      so the declared `file_scope` and the actual edit set are reconcilable. *(confirmed: NOT
      touched — `git status --porcelain` on this file is empty)*
- [x] Confirm no file under `.claude/**` was written, and note that a `.claude/` redeploy is a
      separate user-triggered step for the change to take effect in deployed copies. *(confirmed:
      `git status --porcelain .claude/` is empty; a `.claude/` redeploy is a separate,
      user-triggered step for these edits to reach the deployed copies)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` - caveat comment only
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/summaries/01_coverage-delta-perf-fix-summary.md` -
  implementation summary with timings, equivalence proof, caveats, and the file-overlap statement

**Verification**:
- `test-lit-pipeline.sh --runtime` Section H passes in full.
- `literature-discover.sh` Tier 1 results are unchanged for the spot-check query.
- The summary contains: measured before/after wall time, the per-query equivalence result, the
  divergence-audit conclusion, the `@tsv` caveat, and the explicit `literature-term-match.sh`
  file-overlap statement.

---

## Testing & Validation

- [ ] Full unbounded candidate-id lists are byte-identical before vs. after for every harness query
      (both `MULTI_TERM_MATCH_THRESHOLD` branches represented).
- [ ] `delta_candidates` counts identical before vs. after for every harness query.
- [ ] Non-ASCII / locale divergence audit run over the whole corpus, with its conclusion recorded.
- [ ] Wall-clock time against the live global index drops from tens of seconds to well under the
      "a few seconds" bar (research measured 33.36s -> 0.184s; the implementation records its own).
- [ ] `test-lit-pipeline.sh --runtime` Section H passes.
- [ ] `literature-discover.sh` Tier 1 spot-check unchanged.
- [ ] `bash -n` clean on both edited scripts.
- [ ] No `.claude/**` file written.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` (modified)
- `agent-system/extensions/literature/scripts/literature-term-match.sh` (modified)
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/harness/` (comparison harness, BEFORE
  snapshots, baseline and AFTER captures, divergence-audit output)
- `specs/108_eliminate_coverage_delta_per_entry_jq_spawns/summaries/01_coverage-delta-perf-fix-summary.md`

## Rollback/Contingency

- Both edits are confined to two self-contained bash files with no schema, state, or on-disk format
  change, so `git checkout -- <path>` on the two script paths fully reverts (take a snapshot first
  per `rules/git-workflow.md` if the tree is dirty).
- The guard fails open by design: even a broken edit degrades to `SUBINDEX_PRESENT` with exit 0
  rather than breaking `--lit` dispatch, which bounds the blast radius of a bad intermediate state.
- If Phase 4's decision gate trips (candidate set changed), the contingency is NOT to revert
  silently: surface the divergence, and the narrow remediation is to pin `LC_ALL=C` around the
  case-fold in `to_lower` to restore byte-exact parity with `tr` while keeping the fork-free
  speedup. Phase 3's jq consolidation is independent of that decision and can stand either way.
- If the Section H suite regresses, revert Phase 3 first (it is the change with an external stdout
  contract); Phase 2 is signature-preserving and is the less likely culprit.
