# Implementation Summary: Task #70

- **Task**: 70 - Fix literature-discover.sh tier starvation and silent Tier 3 failure
- **Status**: [COMPLETED]
- **Started**: 2026-08-18T19:10:00Z
- **Completed**: 2026-08-18T21:10:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-discover-tier-starvation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three discovery-correctness defects in the literature extension's three-tier source
discovery pipeline: silent Tier 3 (Semantic Scholar) failure, Tier 1 starving Tiers 2/3 of their
`DISCOVER_LIMIT` budget, and query-construction noise from full multi-paragraph task descriptions.
All five plan phases completed; all edits landed in the source store
(`agent-system/extensions/literature/**`), none in `.claude/**`.

## What Changed

- `agent-system/extensions/literature/scripts/literature-discover.sh` — `tier3_search()` now
  splits HTTP status from body and emits a machine-parseable `TIER3_STATUS: FAILED
  reason=<curl_exit|http|api_error> http_code=<code|n/a> (...)` line on stderr for any non-success
  outcome (curl failure, non-200, or a JSON `.error` body), staying silent on genuine success; the
  tier-dispatch line no longer discards Tier 3's stderr. Added reserved per-tier quotas
  (`TIER1_QUOTA`/`TIER2_QUOTA`/`TIER3_QUOTA`, an even-with-remainder split of `DISCOVER_LIMIT`)
  with rollover of unused quota into later tiers, computed from the shared `RESULTS` array length
  so it is correct under dedup. Query-construction noise reduced: `--task N` resolution now keeps
  the task title as always-included primary terms and caps the task description to the first
  `DISCOVER_DESC_WORD_CAP` (default 30) words as supplementary terms; `tier1_search()`'s matcher
  now requires >= 2 distinct filtered-term hits (instead of accept-on-first-hit) whenever the
  filtered term count exceeds 5, leaving short/deliberate queries unaffected.
- `agent-system/extensions/literature/commands/literature.md` — discover mode step 1 now captures
  `literature-discover.sh`'s stderr to a file (mirroring the existing `zotero_directive`/
  `zotero_rationale` pattern) instead of `2>/dev/null`, branches on `TIER3_STATUS: FAILED`, and
  surfaces a visible incompleteness notice on both the no-results path (step 2) and the
  results-found path (step 3). The step-0 paragraph that named this as deferred scope now
  describes the completed capture. Added a Tier 3 partial-failure row to the error-handling
  section.

## Decisions

- Per-tier quota split: `TIER1_QUOTA=(DISCOVER_LIMIT+2)/3`, `TIER2_QUOTA=(DISCOVER_LIMIT+1)/3`,
  `TIER3_QUOTA=DISCOVER_LIMIT-TIER1_QUOTA-TIER2_QUOTA`, exactly as specified in the plan.
- `cap_words()` flattens embedded newlines before applying the word cap — a bug was found during
  verification where awk's per-line `NF`/loop-index reset caused a multi-paragraph description to
  be capped per-paragraph rather than globally (observed 90 filtered terms instead of ~20-30 for
  task 70's own description before the fix).
- Query noise reduction applies a single `filter_terms()` call over the reordered
  (title-first)/capped-description combined string rather than two separate calls, since
  `filter_terms()` has no cross-token state and the two approaches are provably equivalent.

## Plan Deviations

- **Task 3.2** (filter title/description independently through `filter_terms()`) altered: single
  combined call instead of two separate calls, per the equivalence argument above.
- **Task 3.4** (match-strength threshold in `tier1_search()` and "the equivalent path in
  `tier2_search()`") skipped for `tier2_search()`: that function has no accept-on-first-hit call
  site of its own (it forwards `FILTERED_TERMS` to `zotero-search.sh`, which already does its own
  weighted multi-field scoring); the threshold was added only where an actual call site exists.
- **Phase 5** doc-update task: none of the three named doc sites (`README.md`,
  `literature-command-modes.md`, `adhoc-navigation-directive.md`) actually claimed a
  first-tier-wins budget or silent Tier 3, so no edit was factually required there; only
  `commands/literature.md` (Phase 4) carried the stale claim.

Both deviations are documented inline in the plan file with full reasoning.

## Verification

- Build: N/A (shell script + markdown command definition)
- Tests: Manual — `bash -n literature-discover.sh` clean after every phase; forced-failure runs
  (unroutable proxy) confirm exactly one `TIER3_STATUS: FAILED` line on stderr with stdout still a
  valid JSON array; a synthetic 12-entry Tier 1 index + 2-entry Zotero fixture at
  `DISCOVER_LIMIT=10` confirms both simulated "Jonsson & Tarski" titles survive (tier 1 n=4, tier 2
  n=2, total 6, no truncation); a noise-reduction fixture using task 70's own real (self-referential)
  description confirms an unrelated "Buchi/CTL" entry and a single-generic-word-overlap entry are
  both correctly excluded while a genuine multi-term-overlap entry survives; a 3-word query
  regression confirms short-query single-term-match behavior is byte-identical to pre-change.
- Files verified: Yes

## Impacts

- `/literature` discover mode (Mode A) now surfaces Tier 3 rate-limiting/unreachability instead of
  silently presenting a possibly-incomplete result set as final.
- Discovery results at the default `DISCOVER_LIMIT=10` now represent multiple tiers when multiple
  tiers have genuine matches, instead of Tier 1 alone consuming the whole budget.
- `--task N` discovery queries built from long task descriptions are less likely to surface
  unrelated papers via one incidental shared word.
- Discovery record schema (fields consumed by `literature-ingest-online.sh`) is unchanged.

## Follow-ups

- None.

## References

- `specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/reports/01_fix-discover-tier-starvation.md`
- `specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/plans/01_fix-discover-tier-starvation.md`
- `agent-system/extensions/literature/scripts/literature-discover.sh`
- `agent-system/extensions/literature/commands/literature.md`
