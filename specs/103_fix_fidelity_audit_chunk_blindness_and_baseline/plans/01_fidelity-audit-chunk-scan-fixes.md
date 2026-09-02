# Implementation Plan: Task #103

- **Task**: 103 - Fix fidelity audit chunk-only blindness, the absent-baseline majority, and the self-referential scan-source ratio
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None blocking. Non-blocking coordination: Task 102 (converter-tier characterization, orthogonal), Task 107 (OCR-misrecognition detector, [NOT STARTED] — do not duplicate).
- **Research Inputs**: `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/reports/01_fidelity-audit-chunk-blindness-baseline.md`
- **Artifacts**: plans/01_fidelity-audit-chunk-scan-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three defects in `literature-fidelity-audit.sh`'s `classify_dir()` are fixed in one change, then
the corpus is re-stamped in the same landing. Defect (a): `chunk_NNNN.md` files are excluded from
the `mds` glob unconditionally, so pipeline-ingested directories whose only markdown is chunks are
permanently `has_md=False`. Defect (c): when a word-ratio *is* computable, a PDF produced by a
scan/OCR pipeline makes the ratio self-referential (~1.0 by construction), yielding 9 standing
false `verified_conversion` stamps. Defect (b) is closed by (a) plus a correct `--write` re-run —
research re-measurement showed that once (a) is fixed, 225/296 directories resolve to
`no_source_pdf`, a value neither consumer quarantines, so no new baseline mechanism is required.

Definition of done: the fixed audit, run `--write` from the source store, de-certifies all 9 false
scan-source stamps without regressing any currently-correct ratio, and both consumers quarantine
the new enum value.

### Research Integration

Findings that constrain the design, all carried directly from the research report:

- **The naive (a) fix is wrong.** Deleting the `chunk_\d+\.md` exclusion outright was simulated
  against the live corpus and reintroduces the double-count bug a prior task already fixed
  (`burgess_1982_i` inflates from a correct 1.0982 to a fabricated 2.2476). The fix must be
  **conditional**: count chunk files toward `has_md`/`md_words` only when the directory has no
  non-chunk `.md`.
- **`chunk-file-conventions.md`'s premise is now stale.** Its "chunk files are re-splits of that
  directory's canonical `.md`" wording assumes a canonical `.md` always exists; the ingest pipeline
  no longer guarantees this. It and the script's line-33 docstring must be updated together.
- **(b) needs no new enum value or baseline mechanism** (research Decisions, Option 1). The live
  corpus already differs from the task description's snapshot: only 1 parent entry is unset today,
  and `no_source_pdf` — which is *not* quarantined — is the correct resting state for the majority.
- **LIVE RISK — the fix and the `--write` must land atomically.** Running `--write` under the
  *current unfixed* script would flip genuinely chunk-only, no-PDF directories from a
  currently-working `no_source_pdf` stamp into quarantined `unverified_no_baseline`. No `--write`
  invocation is permitted before Phase 5.
- **(c) must gate the enum, not merely annotate it.** The existing `combining_mark_*` additive-field
  pattern is insufficient: de-certifying the 9 false stamps is an acceptance criterion, and an
  additive field would leave all 9 stamped `verified_conversion`.
- **Use the metadata-only check.** `pdfinfo` Creator/Producer regex, not a text-content OCR
  detector — that broader detector is Task 107's separately-owned scope.
- **Expect 10 unrelated entries in the changed count.** 10 live entries carry an orphaned
  `unverified_conversion` value no current code path produces; it self-heals on the fixed `--write`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Count `chunk_NNNN.md` toward `has_md`/`md_words` when and only when a directory has no non-chunk
  `.md`, preserving every currently-correct ratio exactly.
- Add a seventh enum value, `unverified_scan_source`, gated by a `pdfinfo` Creator/Producer check,
  positioned ahead of the ratio-based `verified_conversion` branch.
- Widen both consumers (`literature-search.sh`'s `QUARANTINED_FIDELITY_VALUES`,
  `literature-briefing.sh`'s `needs_fidelity_marker()`) with the new value in the same change.
- Update all governing prose so the blanket-exclusion rule is not re-derived a third time.
- Re-stamp the live corpus with one `--write` run under the fixed script, and prove the 9 false
  scan-source certifications are gone.

**Non-Goals**:
- Building a general OCR-misrecognition text detector (Task 107's scope; consume it if it lands
  first rather than maintaining a second implementation).
- Applying the report's baseline-free disclosure/proof signals to no-PDF documents (research
  Option 2, explicitly deferred — a bigger surface change to a value 208+ entries depend on).
- Importing PDFs into `sources/` directories (tested and reverted previously; corpus surgery is
  not the answer).
- Hand-editing `index.json` to strip the 9 false stamps (the fixed audit must do it on its own).
- Editing anything under `.claude/**` (deploy artifact; source store is the edit target).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| (a) implemented as a blanket un-exclusion, reintroducing the double-count bug | H | M | Phase 1 verification diffs `burgess_1982_i` (must be 1.0982, not 2.2476) and `goldblatt_1989` (must be 1.0162) against the research report's table before the phase closes |
| A `--write` run under partially-fixed code regresses working `no_source_pdf` stamps into quarantine | H | M | `--write` is forbidden until Phase 5; every earlier phase verifies with `--dry-run` only. Phase 5 confirms the backup file exists before proceeding |
| Scan-source gate placed after the ratio branch, leaving the 9 false stamps intact | H | M | Phase 2 acceptance is the de-certification itself, checked per-directory against the 10-row table in the research report |
| Seventh enum value added to the script but not to one consumer, leaving it silently authoritative | H | L | Phase 3 is a dedicated phase covering both consumers; Phase 5's end-to-end check re-runs a live search |
| Creator/Producer regex is a known-signature allowlist; a stripped-metadata scan passes uncaught | M | H | Accepted, bounded gap (matches the Task 107 boundary). Phase 2 places the signature list in a single named constant so it can be widened or replaced without another `classify_dir()` rewrite |
| The changed-entry count on the `--write` run looks larger than expected | L | H | Expected: the 10 orphaned `unverified_conversion` entries self-heal in the same run. Phase 5 accounts for them explicitly rather than treating them as a regression |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 3 has no code dependency on Phases 1-2
because the enum value's spelling (`unverified_scan_source`) is fixed by this plan; a consumer that
quarantines a value the script does not yet emit is inert, and both consumers are fail-open
list-membership checks. The one hard ordering constraint is that **Phase 5 must follow all others**
— it is the only phase permitted to run `--write`.

---

### Phase 1: Conditional chunk-counting fix and docstring reconciliation [COMPLETED]

**Goal**: `has_md`/`md_words` account for `chunk_NNNN.md` files when they are a directory's only
markdown, while directories carrying both a canonical `.md` and its chunk re-split behave exactly
as they do today.

**Tasks**:
- [x] In `classify_dir()` (around lines 342-346), split the current single `mds` comprehension into
      `non_chunk_mds` (existing predicate) and `chunk_mds` (files matching `^chunk_\d+\.md$`,
      case-insensitive), then set `mds = non_chunk_mds if non_chunk_mds else chunk_mds`. *(completed)*
- [x] Add an inline comment at the assignment recording *why* it is conditional: the fallback fixes
      chunk-only-directory blindness; the `non_chunk_mds`-first preference is what keeps the prior
      double-count fix intact. *(completed)*
- [x] Update the line-33 docstring block to state the distinction explicitly — chunk-ness is never a
      *verdict* signal (unchanged, per the original detector design), but chunk files *are* counted
      as content when they are the only content. Do not delete the existing "do not add them back
      without re-reading the Detector Design section" warning; qualify it. *(completed)*
- [x] Run `--dry-run` and capture the full TSV output plus the stderr population summary to a
      scratch file for the diff below. *(completed: diffed against the unmodified script's own
      --dry-run on the same live corpus; 158 transitions, all attributable — see summary)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research report predicts a post-(a)-fix population of
`verified_conversion: 65, no_source_pdf: 225, not_yet_converted: 2, unverified_no_baseline: 2,
unadjudicated: 2` across 296 directories, and specific ratios for `burgess_1982_i` (1.0982) and
`goldblatt_1989` (1.0162). These are hypotheses from a scratch simulation whose combining-mark
submodule was disabled, not facts. Confirm at implementation time by running `--dry-run` and
comparing; the two named ratios are hard acceptance values, the population counts are expected to
match closely but a small drift from corpus churn since the research run is acceptable if every
individual directory's classification is explicable.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — `classify_dir()`
  `mds` computation (~lines 342-346) and the header docstring at ~line 33.

**Verification**:
- `--dry-run` completes without error and never touches `~/Projects/Literature/index.json`
  (confirm mtime unchanged).
- `burgess_1982_i` reports `word_ratio` 1.0982 (NOT 2.2476 — that value means the blanket
  un-exclusion was implemented and the phase has failed).
- `goldblatt_1989` reports `word_ratio` 1.0162.
- Spot-check that ratios for `blackburn_2002`, `burgess_1982`, `doets_1989`, `gabbay_1993`,
  `wijesekera_1990_constructivemodallogicsi`, `xu_1988`, `zielonka_1998` are unchanged from their
  current live `index.json` values (these directories all have a canonical `.md`, so the fix must be
  a no-op for them).
- At least one known chunk-only directory (e.g.
  `agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl`) now reports `has_md` true and
  no longer classifies via the `not has_pdf and not has_md` branch.

---

### Phase 2: Scan-source gate and the seventh enum value [COMPLETED]

**Goal**: A PDF produced by a known scan/OCR pipeline can no longer reach `verified_conversion` via
a self-referential word ratio; it resolves to a new, distinct `unverified_scan_source` value.

**Tasks**:
- [x] Add a module-level constant holding the scan-pipeline signature pattern (case-insensitive
      `capture|finereader|image conversion`), commented as the single extension point that Task
      107's broader detector can widen or replace without another `classify_dir()` rewrite. *(completed)*
- [x] Add a helper that runs `pdfinfo` on a PDF path and returns whether its Creator or Producer
      field matches the signature pattern. Follow `pdf_word_count()`'s existing error discipline:
      wrap in try/except, warn to stderr, and return a safe default on failure. Decide and comment
      the failure default — a `pdfinfo` failure must not silently certify, so default to "not
      detected" only because the ratio branch downstream is itself the thing being gated; record the
      reasoning inline. *(completed: scan_source_check())*
- [x] In `classify_dir()`, evaluate the scan check across the directory's PDFs and place the gate
      **ahead of** the `ratio >= RATIO_THRESHOLD` -> `verified_conversion` branch, so a
      scan-sourced directory whose ratio would otherwise pass routes to `unverified_scan_source`
      instead. Preserve the existing `pdf_words_total == 0` -> `unverified_no_baseline` branch
      ordering; `unverified_scan_source` names a different failure mode ("the ratio was computed but
      is not trustworthy") and must not collapse into it. *(completed)*
- [x] Decide and comment whether the gate also applies on the low-ratio disclosure/proof paths, or
      only to the high-ratio certification path. Recommended: gate only the paths that would
      otherwise *certify* (`verified_conversion`), leaving `unverified_summary`/`unadjudicated`
      outcomes untouched — a document already withheld from certification does not need a second
      reason. *(completed: gate applied only ahead of the ratio>=threshold branch, per the
      recommendation)*
- [x] Update the "Six-value enum" comment at ~line 38 to seven values, and add
      `unverified_scan_source` to `main()`'s population-summary key list (~line 480) so the new value
      appears in the counts rather than being silently dropped from the report. *(completed)*
- [x] Extend the line-33 docstring's signal list with the scan-source signal and its
      metadata-only-by-design boundary. *(completed)*
- [x] Re-run `--dry-run` and capture output. *(completed: 11 scan-flagged directories found by a
      live pdfinfo survey, not 10 -- the research report's own table lists 11 including
      goldblatt_1989, its prose count undercounted by one; all 11 now read
      unverified_scan_source, none remains verified_conversion, exactly matching the acceptance
      criterion)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The research report's `pdfinfo` survey found 10 scan-pipeline directories
(`blackburn_2002`, `burgess_1982`, `burgess_1982_i`, `burgess_1982_ii`, `burgess_1982b`,
`doets_1989`, `gabbay_1993`, `wijesekera_1990_constructivemodallogicsi`, `xu_1988`,
`zielonka_1998`, plus `goldblatt_1989` which is currently unstamped), 9 of which carry a live false
`verified_conversion`. Confirm at implementation time by re-running the report's Appendix
Creator/Producer survey command before editing, and by checking the post-fix `--dry-run` TSV covers
exactly the set the survey returns. If the survey returns a different set than the report's,
reconcile before proceeding — the acceptance criterion is "no scan-sourced directory is stamped
`verified_conversion`", not "exactly 9 change".

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — new constant, new
  `pdfinfo` helper, `classify_dir()` gate placement, enum comment (~line 38), docstring (~line 33),
  `main()` summary key list (~line 480).

**Verification**:
- Every directory returned by the Creator/Producer survey reports `unverified_scan_source` (or an
  already-withheld value) in `--dry-run` output. **None reports `verified_conversion`** — this is the
  task's explicit acceptance criterion.
- No non-scan directory changes classification relative to the Phase 1 `--dry-run` output (diff the
  two TSVs; the only rows that move are scan-source rows).
- `unverified_scan_source` appears in the stderr population summary with a non-zero count.
- `--dry-run` still writes nothing to `~/Projects/Literature/index.json`.

---

### Phase 3: Widen both consumers with the new enum value [NOT STARTED]

**Goal**: `unverified_scan_source` is quarantined by search and marked by briefing, so the value is
never silently authoritative — following the precedent set when `unadjudicated` was added.

**Tasks**:
- [ ] Add `unverified_scan_source` to `QUARANTINED_FIDELITY_VALUES` at
      `literature-search.sh:53` (the space-separated string consumed by both embedded Python blocks
      at ~line 242 and ~line 545 — verify both read the same variable and need no separate edit).
- [ ] Add `unverified_scan_source` to the `case` list in `needs_fidelity_marker()` at
      `literature-briefing.sh:179`.
- [ ] Grep the full `agent-system/extensions/literature/` tree for any other consumer that
      enumerates fidelity values (allowlist-style membership tests, case statements, docs tables) and
      widen anything found. The research report names two consumers; treat that as a hypothesis, not
      an exhaustive list.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The research report asserts exactly two consumers read `provenance_fidelity`
and both are fail-open list-membership checks. Confirm at implementation time with a tree-wide grep
for `provenance_fidelity`, `QUARANTINED_FIDELITY`, and each of the six existing enum value strings;
if a third consumer surfaces, widen it in this phase and note it in the phase record.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-search.sh` — line 53.
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — line 179.
- Any additional consumer the grep surfaces.

**Verification**:
- `bash -n` passes on both edited scripts.
- Grep confirms `unverified_scan_source` appears alongside `unadjudicated` in every location where
  `unadjudicated` appears as a quarantine/marker member.
- No allowlist was inverted: the checks still fail open (an unknown value is treated as a concern by
  the *caller's* default, never as verified).

---

### Phase 4: Update governing prose and document the enum [NOT STARTED]

**Goal**: A future reader cannot re-derive the blanket chunk exclusion, and the seven-value enum has
a single documented source of truth outside the script header.

**Tasks**:
- [ ] Rewrite `chunk-file-conventions.md`'s "Do not double-count chunks in whole-document
      computations" section (line 8 onward) to state the **conditional** rule: exclude `chunk_*.md`
      when a non-chunk `.md` exists in the directory; count them when they are the directory's only
      markdown. Explicitly correct the now-stale premise that chunk files always accompany a
      canonical `.md` — the ingest pipeline does not guarantee this.
- [ ] Update the same file's consumer list (~line 36) where it describes the audit script as
      "excludes `chunk_*.md` from its `mds` glob" — that description is no longer accurate.
- [ ] Create `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
      documenting: the seven-value enum with the precise meaning of each value; the three ratio
      signals plus the scan-source gate and the additive combining-mark signal; the
      aggregate-at-document-level-never-single-file constraint; the conditional chunk-counting rule;
      the fail-open invariant and the list of places that must be widened together whenever a value
      is added. This was recommended by the original fidelity-audit report and never done.
- [ ] Add a pointer to the new patterns file from
      `context/project/literature/domain/literature-index.md` at its existing `provenance_fidelity`
      mention (~line 140), so the domain doc's passing reference leads somewhere.
- [ ] Add the new patterns file to the literature extension's manifest if the manifest enumerates
      context files (check `agent-system/extensions/literature/manifest.json` before assuming it does
      or does not).

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md`
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md` (new)
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
- `agent-system/extensions/literature/manifest.json` (conditional)

**Verification**:
- Diff read-through confirms every changed hunk is prose or a manifest data entry, with no code
  surface touched.
- The conditional rule as written in `chunk-file-conventions.md` matches the code shipped in
  Phase 1 verbatim in meaning (read both side by side).
- The new patterns file lists all seven enum values and matches the script's actual branch order.
- No task-number references appear in any of these files (they live outside `specs/**`; cite
  filenames and section headings instead).

---

### Phase 5: Atomic corpus re-stamp and end-to-end acceptance [NOT STARTED]

**Goal**: The live corpus is re-stamped once, under the fully fixed script, and the task's stated
acceptance criteria are demonstrated against real data.

**Tasks**:
- [ ] Confirm no `--write` has been run at any earlier point in this task. Re-run `--dry-run` from
      the source-store path one final time and review the full population summary.
- [ ] Record the pre-write population by value from `~/Projects/Literature/index.json` (the research
      report's Appendix `jq` one-liner) so the changed set is attributable afterward.
- [ ] Run `--write` **from the source-store path**
      (`agent-system/extensions/literature/scripts/literature-fidelity-audit.sh`), not from the
      `.claude/` deploy copy, which is stale until the user redeploys. Confirm the script's own
      `index.json` backup was created before proceeding to verification.
- [ ] Record the post-write population and diff it against the pre-write record.
- [ ] Verify the 9 previously-false scan-source stamps are de-certified.
- [ ] Verify the 10 orphaned `unverified_conversion` entries now carry real enum values (expected
      self-heal, not a regression).
- [ ] Re-run `literature-search.sh "deliberative stit"` without `--include-unverified` and confirm
      `horty_belnap_1995_deliberative-stit` still surfaces (this is the (b) acceptance check: the
      fix must not have pushed the `no_source_pdf` majority into quarantine).
- [ ] Run `literature-briefing.sh` against a document now stamped `unverified_scan_source` and
      confirm the `[UNVERIFIED - provenance_fidelity: ...]` marker is emitted.
- [ ] Note in the summary that `.claude/` remains stale until the user redeploys the extension;
      redeployment is out of scope for this task.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: The changed-entry count on the `--write` run is expected to include the 10
orphaned `unverified_conversion` entries for reasons unrelated to defects (a)/(b)/(c), plus the 9
scan-source de-certifications, plus any chunk-only directories whose stamp corrects. Confirm at
implementation time by attributing every changed entry to one of those three causes before
declaring the phase green; an unattributable change is a signal to stop and investigate, not to
proceed.

**Files to modify**:
- `~/Projects/Literature/index.json` (data, via `--write`; outside the repository — this is a corpus
  operation, not a git-tracked edit, and its backup is the rollback path).

**Verification**:
- No directory whose PDF matches the scan-pipeline signature carries `provenance_fidelity:
  "verified_conversion"` in the post-write `index.json`. **If any of the 9 is still
  `verified_conversion`, the fix is incomplete and the task is not done.**
- Zero entries carry `unverified_conversion` after the run.
- `literature-search.sh "deliberative stit"` returns results without `--include-unverified`.
- Every changed entry is attributable to a scan-source de-certification, an orphaned-value
  self-heal, or a chunk-only classification correction.
- The script's backup of the pre-write `index.json` exists on disk.

---

## Testing & Validation

- [ ] `--dry-run` output after Phase 1 reproduces `burgess_1982_i` = 1.0982 and `goldblatt_1989` =
      1.0162 (the anti-double-count regression check).
- [ ] `--dry-run` output after Phase 2 shows zero scan-source directories at `verified_conversion`.
- [ ] TSV diff between the Phase 1 and Phase 2 dry runs moves only scan-source rows.
- [ ] `bash -n` clean on all three edited shell scripts; the audit script's embedded Python parses
      (`--dry-run` running to completion is the check).
- [ ] `unverified_scan_source` present in every consumer location where `unadjudicated` is present.
- [ ] Post-`--write`: search returns results without `--include-unverified`; briefing emits the
      unverified marker for a scan-source document.
- [ ] No file under `.claude/**` was modified at any point.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (modified: conditional
  chunk counting, scan-source gate, seventh enum value, docstring)
- `agent-system/extensions/literature/scripts/literature-search.sh` (modified: quarantine list)
- `agent-system/extensions/literature/scripts/literature-briefing.sh` (modified: marker case list)
- `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md`
  (modified: conditional rule)
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
  (new: enum source of truth)
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
  (modified: pointer)
- `~/Projects/Literature/index.json` (re-stamped corpus data, plus the script's backup)
- `specs/103_fix_fidelity_audit_chunk_blindness_and_baseline/summaries/01_*-summary.md`

## Rollback/Contingency

- **Code**: all repository edits are ordinary git-tracked changes; revert the task's commits.
- **Corpus data**: `--write` creates a backup of `index.json` before stamping. Restore that backup
  to undo the re-stamp. Do not hand-edit `index.json` to correct individual stamps — the whole point
  of the task is that the audit must produce the correct values itself.
- **If Phase 2's gate cannot de-certify all 9 within its timebox**: do NOT run Phase 5. Leaving the
  corpus at its current (partly stale but working) stamps is strictly safer than a partial re-stamp,
  because an interim `--write` would regress currently-retrievable documents into quarantine. Mark
  the task `[PARTIAL]` with Phases 1-4 landed and Phase 5 explicitly not run.
