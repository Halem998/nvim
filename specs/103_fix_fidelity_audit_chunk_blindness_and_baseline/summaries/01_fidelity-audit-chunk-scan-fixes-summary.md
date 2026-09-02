# Implementation Summary: Task #103

- **Task**: 103 - Fix fidelity audit chunk-only blindness, the absent-baseline majority, and the self-referential scan-source ratio
- **Status**: [COMPLETED]
- **Started**: 2026-09-02
- **Completed**: 2026-09-02
- **Effort**: ~2.5 hours
- **Dependencies**: None blocking. Non-blocking coordination: converter-tier characterization work (orthogonal), an OCR-misrecognition detector task ([NOT STARTED] — not duplicated here).
- **Artifacts**: plans/01_fidelity-audit-chunk-scan-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three defects in `literature-fidelity-audit.sh`'s `classify_dir()` and re-stamped the live
`~/Projects/Literature/index.json` corpus under the fixed script in one atomic landing. Defect
(a): `chunk_NNNN.md` files were excluded from the `mds` glob unconditionally, making
chunk-only-ingested directories permanently `has_md=False`; fixed with a conditional
non-chunk-first, chunk-fallback rule that preserves the prior double-count fix exactly. Defect
(c): a PDF produced by a known scan/OCR pipeline made its word-ratio self-referential (~1.0 by
construction), yielding 11 standing false `verified_conversion` stamps (the research report's own
survey table enumerated 11 despite a "10" prose summary); fixed with a `pdfinfo` Creator/Producer
metadata gate and a new seventh enum value, `unverified_scan_source`, widened into both retrieval
consumers. Defect (b) required no new mechanism — the (a) fix alone resolves 225/296 directories
to the pre-existing, non-quarantined `no_source_pdf` value.

## What Changed

- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — conditional
  `non_chunk_mds`/`chunk_mds`/`mds` computation in `classify_dir()`; new
  `SCAN_SOURCE_SIGNATURE_RE` constant and `scan_source_check()` helper (pdfinfo-based, fails
  safe to "not detected" on error); scan-source gate placed ahead of the
  `ratio >= RATIO_THRESHOLD` branch only; enum comment and docstring updated to seven
  values/four signals; `main()`'s population-summary key list extended.
- `agent-system/extensions/literature/scripts/literature-search.sh` — `unverified_scan_source`
  added to `QUARANTINED_FIDELITY_VALUES` (one variable, consumed by both embedded Python
  search blocks).
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — `unverified_scan_source`
  added to `needs_fidelity_marker()`'s case list.
- `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md`
  — rewritten to state the conditional chunk-counting rule with both the double-count and
  blindness failure-mode examples; consumer list and detection guidance updated.
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
  — new file: the complete seven-value enum table, the four detector signals in order, the
  scan-source gate's placement rationale, the additive combining-mark contrast, the
  aggregate-at-document-level constraint, the conditional chunk rule, why `no_source_pdf` isn't
  quarantined, and the fail-open invariant with the full widen-together checklist for any future
  enum addition.
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` —
  pointer to the new patterns file added at the existing `provenance_fidelity` mention.
- `~/Projects/Literature/index.json` — re-stamped via `--write` (data, not git-tracked); backup
  at `index.json.bak.20260902-052324`.

## Decisions

- Gated the scan-source signal only ahead of the high-ratio `verified_conversion` branch, per
  the plan's explicit recommendation — the low-ratio disclosure/proof-completeness paths are
  left ungated, since a document already withheld from certification does not need a second
  reason.
- `pdfinfo` failure defaults `scan_source_check()` to "not detected" rather than "detected,"
  documented inline: this is safe because the check is only ever a gate ahead of the
  pre-existing ratio branch — a failed gate simply falls through to that branch's existing
  behavior, never a new certification path.
- Opportunistically cleaned two pre-existing task-number references encountered while rewriting
  the touched sections of `chunk-file-conventions.md`, replacing them with durable descriptions
  per the no-task-references-in-deliverables rule.

## Plan Deviations

- None (implementation followed plan). One factual correction surfaced during implementation:
  the research report's own survey table enumerates 11 scan-flagged directories (including
  `goldblatt_1989`), not the "10" its prose states — the implementation followed the report's
  own table, which the live `pdfinfo` survey reproduced exactly, and de-certified all 11 (a
  strictly stronger outcome than the plan's ">=9" acceptance bar).

## Verification

- Build: N/A (bash/Python scripts, no build step)
- Tests: `bash -n` clean on all three edited shell scripts; every phase's `--dry-run`
  completed without error and left `index.json`'s mtime unchanged until Phase 5's deliberate
  `--write`
- Files verified: Yes — see per-phase verification notes in
  `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/progress/phase-{1..5}-progress.json`
- Anti-regression gate: `burgess_1982_i` reads `word_ratio` 1.0982 throughout (never 2.2476)
- Corpus re-stamp: entry-level diff shows exactly 29 `provenance_fidelity` transitions on
  parent entries, every one attributable to scan-source de-certification (11), orphaned-value
  self-heal (10), or a pre-existing stale stamp correcting to reflect a PDF since removed from
  disk (8, independently confirmed on-disk) — zero unattributable changes
- Live acceptance: `literature-search.sh "deliberative stit"` returns results without
  `--include-unverified` post-write; `literature-briefing.sh` emits the
  `[UNVERIFIED - provenance_fidelity: unverified_scan_source - ...]` marker for a scan-source
  document (verified via a throwaway single-entry sub-index, deleted immediately after)

## Impacts

- The literature corpus's fidelity stamps are now current and trustworthy: 11 previously-false
  `verified_conversion` scan-source certifications are de-certified and quarantined; 10 orphaned,
  unrecognized `unverified_conversion` stamps that silently bypassed both retrieval consumers are
  gone; chunk-only-ingested directories are no longer permanently invisible to the detector.
- `.claude/` remains stale until the user redeploys the literature extension — the running
  deployed copies of `literature-fidelity-audit.sh`, `literature-search.sh`, and
  `literature-briefing.sh` do not yet reflect these fixes. Redeployment is out of scope for this
  task.

## Follow-ups

- None required for this task's scope. A future OCR-misrecognition text detector (separately
  scoped) could widen or replace `SCAN_SOURCE_SIGNATURE_RE`'s metadata-only check without another
  `classify_dir()` rewrite, per the extension point documented inline and in
  `provenance-fidelity.md`.

## References

- Plan: `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/plans/01_fidelity-audit-chunk-scan-fixes.md`
- Research report: `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/reports/01_fidelity-audit-chunk-blindness-baseline.md`
- Progress files: `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/handoffs/`
- New pattern doc: `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
