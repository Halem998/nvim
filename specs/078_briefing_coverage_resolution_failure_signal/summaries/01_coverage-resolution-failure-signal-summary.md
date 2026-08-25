# Implementation Summary: Task #78

- **Task**: 78 - briefing_coverage_resolution_failure_signal
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T04:17:16Z
- **Completed**: 2026-08-25T04:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (predecessor schema-unification task already [COMPLETED])
- **Artifacts**: plans/01_coverage-resolution-failure-signal.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`literature-briefing.sh`'s `lit-coverage` marker previously derived `seg_count` only from
resolved documents, so a repo-mode briefing that silently dropped every requested `doc_id`
self-reported `sparse=false` (or, in the total-failure case, exited with no output at all). This
task instrumented the single skip site, ended the silent full-failure exit, extended the marker
schema with `requested=`/`resolved=`/`skipped=`/`skip_rate=` fields appended after the existing
fields, folded a new skip-rate threshold into the existing `sparse` boolean, surfaced skipped
`doc_id`s in the briefing body, documented the threshold policy, and added a regression test
(Section G in `test-lit-pipeline.sh`) that fails when the fix is reverted.

## What Changed

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — added
  `skip_count`/`requested_count`/`skipped_doc_ids[]` counters initialized before the mode branch;
  set `requested_count` in both repo mode (post-`mapfile`) and global mode (`= seg_count`);
  instrumented the single repo-mode skip site (the `continue` at the unresolved-`doc_id` check)
  to increment the counter and append to the array; replaced the silent `exit 0` on total
  resolution failure with a fallthrough gated on `skip_count -gt 0` (the genuinely-empty-sub-index
  guards earlier in the function are untouched and still exit silently); added
  `LITERATURE_SKIP_RATE_THRESHOLD` (default `50`, percent); computed `skip_rate` as a
  zero-division-guarded integer percentage; extended the `sparse` rule to a disjunction (existing
  absolute-count rule OR `skip_count -gt 0 && skip_rate -ge threshold`); extended the
  `<!-- lit-coverage ... -->` marker with the four new fields strictly after `threshold=T`; added
  a `[SKIPPED SOURCES ...]` banner (fires whenever `skip_count -gt 0`, independent of whether the
  rate crossed the sparse threshold); added an `## Unresolved Documents` body section listing
  `skipped_doc_ids[]`, guarded by non-empty array.
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` —
  documented `LITERATURE_SKIP_RATE_THRESHOLD`, the full new marker schema, and a new "Threshold
  Policy" subsection recording the decision to fold the skip-rate signal into the existing
  `sparse` boolean (rather than a second, unconsumed flag) and the rationale for the conservative
  `50`-percent default.
- `agent-system/extensions/literature/index-entries.json` — resynced the
  `project/literature/domain/sparse-coverage.md` entry's `keywords` (added
  `LITERATURE_SKIP_RATE_THRESHOLD`, `skip_rate`), `summary`, and `line_count` (33 -> 61).
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — added `section_g()`: Case
  G1 (partial failure, 2 requested/1 skipped, asserts `requested=2 resolved=1 skipped=1
  skip_rate=50 sparse=true`, the `## Unresolved Documents` body section, and the `[SKIPPED
  SOURCES ...]` banner), Case G2 (isolates the new skip-rate disjunct from the pre-existing
  absolute-count rule using a 4-resolved/4-skipped fixture where `resolved=4` alone would not
  trip the old rule), Case G3 (total failure — asserts non-empty stdout and `seg_count=0
  resolved=0 skipped=1 sparse=true` instead of the old silent `exit 0`), and a negative control
  (an `entries: []` sub-index still exits silently). Registered `section_g` in `main()`'s
  `RUN_RUNTIME` block after `section_f`, added a `G - ...` line to the header comment's
  `Sections:` list, and updated Section F's header comment to point at Section G instead of
  describing the regression as deferred.

## Decisions

- Reused the existing `sparse` boolean/marker/banner machinery for the skip-rate signal rather
  than inventing a second flag — both existing marker consumers (`lit-stage4a-flow.md`,
  `adhoc-navigation-directive.md`) already poll `sparse=true`, so this satisfies AC1 and AC3
  simultaneously with zero edits to either consumer file.
- New marker fields (`requested=`/`resolved=`/`skipped=`/`skip_rate=`) were appended strictly
  after the pre-existing `threshold=T` field, leaving `mode=`/`seg_count=`/`sparse=`/`threshold=`
  byte-for-byte adjacent and in original order — verified empirically against the pre-change
  script on identical fixtures (see Verification).
- `LITERATURE_SKIP_RATE_THRESHOLD` default set to `50` (percent, `>=` comparison), a conservative
  starting value chosen without calibration data, documented as such in `sparse-coverage.md`.
- The full-failure fallthrough (line ~294-297 in the pre-change script) is gated strictly on
  `skip_count -gt 0`, so the pre-existing legitimately-empty-sub-index silent-exit guards remain
  untouched and are covered by a negative-control regression assertion in Section G.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime`
  reports 30/30 passed, 0 failed, 0 warnings (Sections A-G).
- Files verified: Yes — `bash -n` clean on both edited scripts; `jq .` parses
  `index-entries.json`; `line_count` matches `wc -l` on the edited doc.
- Regression-detection check: temporarily reverted the Phase 1 skip-counter increment and
  re-ran Section G — 6 of 7 assertions failed (marker fields, body section, banner, total-failure
  non-silence), confirming the test detects the actual defect rather than passing vacuously.
  Restored and re-verified `bash -n` + a clean full-suite run afterward.
- AC3 empirically verified: captured real global-mode markers from the edited script for a
  `sparse=true` fixture (1 matching chunk, below the default threshold of 3) and a `sparse=false`
  fixture (3 matching chunks); `lit-stage4a-flow.md:203`'s literal
  `grep -q 'lit-coverage mode=global .*sparse=true'` matched the sparse marker and rejected the
  non-sparse one. Diffed the marker prefix (`mode=`/`seg_count=`/`sparse=`/`threshold=`) against
  the same fixtures run through the pre-change script (`git show` of the commit immediately
  before this task's first edit) — byte-for-byte identical in both cases.
  `adhoc-navigation-directive.md:45-46` was re-read and confirmed to carry no independent grep of
  its own (cites the shared Stage 4a marker contract in prose). `git status --short` confirmed
  neither consumer file's directory was touched by this task's commits.

## Impacts

- Any `--lit`-enabled skill invocation that hits a repo-mode resolution failure now surfaces the
  failure in the coverage marker and briefing body instead of silently under-reporting coverage.
  A high repo-mode skip rate now also flips `sparse=true`, though — as scoped in the plan — no
  downstream code currently re-prompts on a sparse *repo-mode* marker (both existing consumers
  poll only `mode=global`); wiring that re-prompt is an explicit non-goal left for a future task.

## Follow-ups

- None.

## References

- `specs/078_briefing_coverage_resolution_failure_signal/reports/01_coverage-resolution-failure-signal.md`
- `specs/078_briefing_coverage_resolution_failure_signal/plans/01_coverage-resolution-failure-signal.md`
