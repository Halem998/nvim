# Implementation Summary: Task #835

**Completed**: 2026-07-09
**Duration**: ~1 session (5 phases)

## Overview

Built a re-runnable provenance/fidelity detector for the `~/Projects/Literature` corpus, stamped
a five-value `provenance_fidelity` field onto 153 `index.json` entries across all 97 `sources/`
directories, and made both retrieval scripts (`literature-search.sh`, `literature-briefing.sh`)
loudly flag and quarantine low-fidelity entries instead of serving them as authoritative. The
detector reproduces the research report's corrected population exactly and flags exactly the one
confirmed defect (`rabinovich_2014`, an undisclosed hand-authored paraphrase) with zero false
positives against the five legitimate disclosed partial conversions.

## What Changed

- `.claude/scripts/literature-fidelity-audit.sh` (new) — re-runnable, backup-first, idempotent
  auditor. `--dry-run` (default) classifies every `sources/<dir>/` via a three-signal detector
  (document-level word-ratio, disclosure check, proof/body-completeness check) and prints a
  TSV report. `--write` backs up `index.json` (timestamped, verified byte-identical), stamps
  `provenance_fidelity` + `word_ratio` onto the resolved target entries per directory, and
  atomically replaces `index.json`. Re-running `--write` is a verified no-op.
- `.claude/scripts/literature-search.sh` — `do_search`/`do_read`/`do_toc` now enrich results with
  a `provenance_fidelity` key (directory-name-keyed lookup, fail-open). `do_search` excludes
  `unverified_summary`/`unverified_no_baseline` docs from default ranking; a new
  `--include-unverified` flag opts back in. `do_read` prefixes content with a loud warning banner
  for any non-`verified_conversion` chunk.
- `.claude/scripts/literature-briefing.sh` — per-repo mode (`.id`-keyed lookup, mirroring the
  existing relevance lookup) and global-corpus mode (reads the field already present on
  `do_search` results) both prepend an ASCII `[UNVERIFIED - provenance_fidelity: ...]` marker for
  `unverified_summary`/`unverified_no_baseline`/absent docs. The "How to Use" footer gained an
  UNVERIFIED-entries guidance line.
- `~/Projects/Literature/index.json` (external repo, not part of this git repository) — 153
  entries stamped with `provenance_fidelity` + `word_ratio`. A timestamped backup
  (`index.json.bak.20260709-190805`, plus later test-run backups) was written before the first
  mutation. This file is not committed by this task; it lives in its own separate git repository
  (`~/Projects/Literature`), where `git status` shows it as a pending modification for the user
  to review and commit independently if desired.

## Decisions

- **Word-ratio is aggregated at the whole-document level** (sum all `.md` in a directory / sum
  `pdftotext -layout` words over all PDFs in the directory), never sampled from a single file —
  this was the single most important correction from the research report and is asserted in the
  auditor's header comment.
- **`chunk_*.md` filename presence and a standalone `## Overview` heading are rejected as
  detector signals** — both are false discriminators in this corpus (0 of 30 healthy docs use the
  `chunk_*.md` convention).
- **Five-value enum**: `verified_conversion`, `unverified_summary`, `no_source_pdf`,
  `not_yet_converted`, `unverified_no_baseline` — expanded from the task description's original
  3-value ask per the report's explicit recommendation.
- **Proof-completeness sub-check**: Lemma/Theorem/Proposition/Corollary headings require an
  explicit "Proof" marker in their body to count as adequate (a list of unproved clauses does not
  count regardless of length); Definition headings use a content-length bar instead (>=2
  non-blank lines or >=15 words). The adequacy-fraction threshold was empirically calibrated to
  `< 0.6` after measuring `rabinovich_2014`'s actual value (0.545) — two lower thresholds (0.5,
  and a cruder line-count-based rule) were tried first and failed to flag it; see
  `progress/phase-1-progress.json` for the full record.
- **Two genuinely different `doc_id` namespaces exist in this corpus** and must not be conflated:
  `chunks_data.doc_id` (SQLite/`literature-search.sh`) is always the bare source directory name;
  `specs/literature-index.json`'s `doc_id` (`literature-briefing.sh` per-repo mode) is index.json's
  own `.id` field, which frequently differs from the directory name (e.g. `blackburn_2002_book`
  vs. directory `blackburn_2002`). Each script's fidelity lookup is keyed correctly for its own
  namespace; this was discovered via live testing against `.literature.db`, not by inspection
  alone, and is recorded as a memory candidate below.

## Plan Deviations

- **Phase 2** ("only touch parent entries, never child chunk entries"): altered. 15 of the 97
  directories have a pre-existing, orthogonal `index.json` metadata gap — their children reference
  a `parent_doc` value with no corresponding top-level `id` row (a phantom parent), including two
  of the plan's own named disclosed-partial benchmarks (`doets_1987`, `venema_1991`). These are
  stamped directly on their child entries as a documented fallback; otherwise they would be
  unstampable and would fail-open to a false `unverified_summary` flag, directly violating the
  plan's dominant acceptance criterion. Full rationale and the 15-directory list are in the
  auditor script's header comment and `progress/phase-2-progress.json` (deviation 2.5).
- **Phase 3** ("mirroring `get_project_doc_ids()`... jq keyed by `.id`"): altered. Verified via
  live testing that `chunks_data.doc_id` is the bare directory name, not index.json's `.id` — an
  `.id`-keyed lookup silently fail-opened on nearly every already-chunked document. Implemented as
  a directory-name-keyed Python dict lookup instead; see `progress/phase-3-progress.json`
  (deviation 3.1) and the `approaches_tried` record of the two failed intermediate designs.
- **Phase 5 verification**: several plan-cited benchmark docs (`rabinovich_2014`,
  `thomas_2003_reactive`, `libkin_2004_ch3_ch7`, `hodkinson_2006`, `baier_katoen_2008`) have no
  `chunks.json` and are absent from `.literature.db` (a pre-existing corpus-indexing gap,
  orthogonal to this task). Runtime verification substituted equivalent live-indexed docs
  (`thomason_1984` for `unverified_no_baseline`, `blackburn_2002`/`doets_1987` for
  `verified_conversion`); `rabinovich_2014`'s `index.json`-side correctness was verified directly
  instead of via a live `--read`.

## Verification

- Build: N/A (bash/Python scripts, no build step)
- Tests: Passed — `bash -n` syntax checks on all three modified/new scripts; the pre-existing
  `.claude/scripts/test-lit-pipeline.sh` (static: 26/26, `--runtime`: 33/33, no regressions);
  live functional tests against the real `.literature.db` and `index.json` for every enum value
  reachable there
- Files verified: Yes — real corpus stamped and idempotency-confirmed across three separate
  `--write` invocations (Phase 2 initial write, and two later re-verification writes after the
  Phase 3/4 script edits); zero corpus source files modified (confirmed via `git status` inside
  the `~/Projects/Literature` git repository and an independent mtime scan)

## Notes

- Recommended follow-up (out of scope here, noted by the research report): OCR-based re-extraction
  for the 4 `unverified_no_baseline` directories (`burgess_1984`, `gabbay_1994`, `thomason_1984`,
  `vardi_wolper_1986`), whose PDFs yield 0 words under `pdftotext -layout`.
- `~/Projects/Literature/index.json` now has 4 backup files
  (`index.json.bak.20260709-{190805,190827,192417,192428}`) from the initial write and later
  re-verification writes during this session. They are harmless and were intentionally left in
  place per the "quarantine, never delete" posture extended conservatively to anything under
  `~/Projects/Literature/`; the user may prune older ones if desired.
- Task #832 ("reconvert all 97 dirs") carries a documented dependency on this task's findings per
  its own task description; its premise should be revisited now that this task's corrected
  population classification is stamped and available.
