# Implementation Summary: Task #96

- **Task**: 96 - surface_literature_coverage_delta_under_lit
- **Status**: [COMPLETED]
- **Started**: 2026-08-24
- **Completed**: 2026-08-25
- **Effort**: ~6.5 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_coverage-delta-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented a topic-scoped coverage-delta guard under `--lit`: a per-repo sub-index that clears
`LITERATURE_SPARSE_THRESHOLD` no longer short-circuits as healthy without ever checking whether
the global Literature corpus holds topic-relevant documents the sub-index never references. The
guard is a compound, topic-scoped condition (never a bare ratio) wired into the two existing
`SPARSE_PROMPT_NEEDED`/`lit-coverage`-marker mechanisms rather than a parallel mechanism, and
reaches `orchestrator_mode=true` runs via a mandatory in-band banner since `AskUserQuestion` is
unavailable there.

## What Changed

- `agent-system/extensions/literature/scripts/literature-term-match.sh` — new source-only helper
  extracting `to_lower`/`STOP_WORDS`/`filter_terms`/`term_matches`/`MULTI_TERM_MATCH_THRESHOLD`
  verbatim out of `literature-discover.sh`, now shared by two call sites.
- `agent-system/extensions/literature/scripts/literature-discover.sh` — sources the extracted
  helper instead of defining the matcher inline; output confirmed byte-identical before/after.
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` — new executable.
  Computes `delta_gap` (global top-level docs, `parent_doc == null` filtered, minus sub-index
  entry count) as a cheap pre-filter (`LITERATURE_COVERAGE_GAP_MIN`, default 25), then a
  keyword-matched candidate count (`LITERATURE_COVERAGE_DELTA_THRESHOLD`, default 1) reusing the
  Tier 1 matcher. Fail-open in every error path (missing/unreadable index, no `--query`, empty
  filtered-term list) — always exits 0.
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` — `SUBINDEX_PRESENT`
  branch now invokes the delta guard after the absolute-count check passes; downgrades to the
  existing `SPARSE_PROMPT_NEEDED` token (no new directive) when the delta fires, with a stderr
  rationale distinguishing this cause from the absolute-count one. Guarded so a missing/failing
  delta script degrades to prior behavior.
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — new optional `--query`
  argument (repo mode only; ignored with a warning in `--global` mode). When present, invokes the
  delta guard and appends `delta_checked=`/`delta_gap=`/`delta_candidates=` to the `lit-coverage`
  marker strictly after the pre-existing eight fields, plus a bounded `[COVERAGE DELTA - ...]`
  banner when the guard fires. Does not set `sparse=true` (D5). `delta_checked=false` is always
  emitted (never omitted) when `--query` is absent.
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — new Section H (opt-in
  `--runtime`): six cases (H1 fires, H2 negative control, H3 chunk-inflation, H4 not-computed, H5
  fail-open, H6 `LITERATURE_COVERAGE_GAP_MIN` `>=` boundary at/below threshold). All 44 total
  suite checks pass (Sections A-H); confirmed the trigger inversion sanity check (H1/H2 fail when
  the firing condition is inverted, proving the test exercises real behavior).
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` — every repo-mode
  `literature-briefing-invoke.sh` call site (`SUBINDEX_PRESENT`, autonomous
  `SPARSE_PROMPT_NEEDED`, and the "Create curation task"/"Search online to ingest" post-action
  re-briefs) now passes `--query "$description"`; interactive `SPARSE_PROMPT_NEEDED` prompt
  wording now names both causes; new "Coverage-Delta Marker Fields" subsection documents the
  three new marker fields and the D5 rationale for not setting `sparse=true`.
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` — new
  "Coverage-Delta Detection" section (compound condition, both env vars, the mandatory
  `parent_doc == null` filter, marker-field placement, the D6 not-computed convention, the D5
  rationale, and the named claim-level-verifier follow-up), placed beside the existing "Threshold
  Policy" section per the file's own layout convention.
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
  — the three repo-mode `literature-briefing-invoke.sh` call sites in the primary-session ad-hoc
  flow now also pass `--query`, mirroring the Stage 4a change (this file explicitly mirrors
  Stage 4a; leaving it stale would have made this call path permanently blind to the guard).

## Decisions

- Followed D1-D6 from the plan verbatim (compound topic-scoped trigger, `parent_doc == null`
  filtering, shared single computation with two wiring sites, dual advisory/interactive
  surfacing, `sparse` left untouched, `delta_checked=false` never misread as zero).
- Extended the "every repo-mode call site now carries `--query`" verification criterion in Phase
  5 to cover all `lit-stage4a-flow.md` no-arg repo-mode call sites (not only the two named in the
  phase's Tasks list), and mirrored the same change into `adhoc-navigation-directive.md` even
  though that file's `<!-- lit-coverage ... -->` reference itself needed no correction — both
  changes close the exact "guard silently never fires in production" risk the plan's own Risks
  table names.
- Added Case H6 (boundary at/below `LITERATURE_COVERAGE_GAP_MIN`) beyond the plan's named H1-H5,
  per the Phase 6 Scope Hypothesis instruction to re-check Section G's boundary-case coverage
  before declaring the case list closed.

## Plan Deviations

- None (implementation followed plan; the two additions above — broader `--query` propagation
  and the H6 boundary case — are within the plan's own verification criteria and Scope
  Hypothesis instructions, not departures from them).

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime`
  reports 44 passed, 0 failed, 0 warnings (Sections A-H)
- Files verified: Yes — every new/modified script passes `bash -n`; `literature-coverage-delta.sh`
  and `literature-lit-flag-resolve.sh`/`literature-briefing.sh` exercised by hand against the real
  `$LITERATURE_DIR` (204 top-level docs of 414 raw entries, confirming the anti-inflation filter)
  and against fixture repos covering firing, non-firing, chunk-inflation, not-computed, fail-open,
  and threshold-boundary cases; the H1/H2 trigger-inversion sanity check confirmed the fixture
  suite tests real behavior, not tautologies; the full autonomous-path flow (resolver ->
  `[lit:auto]` -> briefing with `--query`) was manually walked end-to-end confirming the
  `[COVERAGE DELTA ...]` banner reaches `lit_context` without any `AskUserQuestion` call.

## Impacts

- Every `--lit` run with a pre-existing sub-index now pays one extra `jq` pass over the local
  global index (200-400 entries) per invocation when `LITERATURE_COVERAGE_GAP_MIN` is cleared —
  no network calls, no material latency.
- A previously-silent gap (topically relevant, already-indexed global sources invisible to a
  research run because never added to the sub-index) is now surfaced both in-band (reaches
  autonomous runs) and interactively (reuses the existing four-option prompt).

## Follow-ups

- The claim-level "no counterpart exists" verifier named in the plan's Non-Goals and Named
  Follow-Up section remains unimplemented by design — it is a materially different, more
  expensive mechanism (post-hoc draft-claim scanning against the full global corpus) than the
  briefing-time topic-scoped delta guard delivered here, and is a candidate for a dedicated
  follow-up task (`/spawn`), not something this task's completion should be read as having closed.

## References

- specs/096_surface_literature_coverage_delta_under_lit/plans/01_coverage-delta-guard.md
- specs/096_surface_literature_coverage_delta_under_lit/reports/01_lit-coverage-delta-guard.md
