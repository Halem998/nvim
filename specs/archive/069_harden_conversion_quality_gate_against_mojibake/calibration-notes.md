# Calibration notes: quality-gate hardening against mojibake/NUL corruption

Measurements taken directly against the live corpus at `~/Projects/Literature/` (40 ingested
document directories at measurement time, excluding the non-document `scripts/`, `sources/`,
`specs/`, `tools/` subdirectories and two document directories with zero chunk files —
`bacon_and_zeng_-_2022_-_a_theory_of_necessities` and
`maclane_moerdijk_1994_sheaves_in_geometry_and_logic` — which contributed no text to measure and
are excluded from the counts below rather than silently treated as passing).

## Method

For each document directory, all `chunk_*.md` files were concatenated and scored with the exact
`printable_ratio()` formula being added to `literature_quality_gate.py`: `\t`/`\n`/`\r` are
exempted first (they do not count toward the denominator), then the fraction of the remaining
characters classified `unicodedata.category(c) in {"Cc","Cs","Co","Cn"}` is subtracted from 1.0.
NUL byte (`\x00`) and other-`Cc`-outside-tab/nl/cr counts were tracked separately, per the
Phase 1 task instruction, so a threshold decision could be made knowing whether legitimate
corpus documents use either category at all.

## Printable-ratio distribution (38 documents, sorted ascending)

| Document | printable_ratio | non-printable count | NUL count |
|---|---|---|---|
| reynolds_2002_axioms_for_branching_time | 0.931404 | 3932 | 0 |
| pym_ohearn_yang_2004_possible-worlds-resources-bi | 0.944283 | 6634 | **1352** |
| rumberg-zanardo-2019-transition-structures | 0.978475 | 1450 | 0 |
| johnstone_2002_sketches_of_an_elephant_vol1 | 0.990868 | 10585 | 0 |
| reynolds-2003-ockhamist | 0.991194 | 322 | 0 |
| johnstone_2002_sketches_of_an_elephant_vol2 | 0.991384 | 16023 | 0 |
| benton_2004_simple_relational_correctness_proofs | 0.99214 | 671 | 0 |
| ...30 more, monotonically increasing... | ... | ... | 0 |
| brookes_2007 / calcagno_2007 / docherty_pym_2019 / ishtiaq_ohearn_2001 / jonsson_tarski_1951 / jonsson_tarski_1952 / jipsen_litak_2017 / jung_2018 / ohearn_2007 / ohearn_2019 / reynolds_2002_separation-logic / rutten-2000 / thomason-1970 / tiwari_etal_2009 | 1.0 | 0 | 0 |

- **min = 0.931404** (`reynolds_2002_axioms_for_branching_time`) — manually spot-checked: clean,
  well-formed math prose (see chunk_0001-0003.md), no visible corruption. The near-1000s of
  non-printable characters here (and in the ~19 other documents with non-zero `Cc` counts, see
  below) are `Cc` codepoints in the `0x01`-`0x1F` range used by this corpus's PDF toolchain as
  glyph-index substitutes for math symbols under a broken/partial `ToUnicode` CMap — a real,
  systemic, but currently-tolerated artifact class, not the mojibake defect this task targets.
- **median ≈ 0.9994**, **max = 1.0**.
- **`pym_ohearn_yang_2004_possible-worlds-resources-bi` is a genuine, already-ingested defect**:
  1352 literal NUL bytes (`\x00`) found in its chunk text (e.g. author-list bullet markers
  rendered as `\x00`/`\x01`/`\x02` — see `Pym Ohearn Yang 2004...\n\n\x00\n\n\x00 Peter W.
  O'Hearn\n\n\x01 Hongseok Yang...`). This is the same corruption *class* the task's motivating
  Gabbay/Kurucz case describes (broken font encoding -> uninterpretable codepoints reaching the
  gate), already sitting in the live corpus and FTS index. Re-converting/repairing it is an
  explicit Non-Goal of this plan; it is recorded here as the real must-flag evidence instead of
  a synthetic-only fixture, and reconfirmed in Phase 6 as a *true* positive, not a
  miscalibration.
- `Cs` (surrogate) and `Cn` (unassigned) counts are zero across the entire corpus except two
  single-codepoint `Cn` hits (`schultz-spivak-temporal-type-theory`,
  `schultz-spivak-vasilakopoulou-dynamical-systems-sheaves`) — negligible. `Co` (private-use
  area) is non-zero in 5 documents, largest count 281 (`jacobs-coalgebra-intro-draft`) — all
  five documents still score at or above 0.99+ printable_ratio, so PUA usage in this corpus is
  sparse relative to the pervasive low-range-`Cc` glyph-substitution pattern above.

## Calibration-driven deviation from the plan's literal Phase 3 wording

The plan's Phase 3 task text specifies a single "zero-tolerance NUL/control-character check
(`\x00` plus any other `Cc` outside `\t \n \r`)". Real corpus measurement contradicts blanket
zero-tolerance on all `Cc`: **19 of the 38 measured documents** have non-zero `Cc`-outside-
tab/nl/cr counts (up to 17299 in one document), and these are legitimate already-passing corpus
members, not corruption — manually spot-checked on the two highest-`Cc` documents
(`reynolds_2002_axioms_for_branching_time`, `johnstone_2002_sketches_of_an_elephant_vol2`;
clean, coherent text in both). A blanket zero-tolerance `Cc` check would fail roughly half the
existing corpus, directly violating this plan's own Goal ("Zero false positives across the
existing corpus: all 40 documents ... still pass the widened gate").

Decision: split the check in two, per real evidence rather than the literal plan wording —
1. **`\x00` (NUL) specifically stays zero-tolerance.** Verified safe: every corpus document
   scores 0 NUL bytes except the one already-known defect above (which is correctly meant to
   fail, per the "true positive on already-ingested corruption" note above, not a false
   positive this plan is obligated to suppress).
2. **All other non-printable categories (`Cc`-outside-tab/nl/cr, `Cs`, `Co`, `Cn`) are folded
   into `printable_ratio()`'s calibrated-floor check instead of a zero-tolerance count.** This
   preserves the check's actual purpose (catch majority/large-scale glyph-index corruption)
   without breaking on this corpus's real, benign low-`Cc` math-glyph-substitution convention.

This is recorded as a Phase 3 plan deviation in the implementation summary.

## Chosen thresholds

- **`printable_ratio` floor: 0.85.** ~8.1 percentage points of headroom below the measured
  real-corpus minimum (0.931404), while still well above the neighborhood a majority-corrupted
  document would plausibly occupy (the one available real corruption data point,
  `pym_ohearn_yang_2004_possible-worlds-resources-bi`, sits at 0.944 driven by a handful of NUL
  markers — its overall document was not majority-corrupted, so this floor is not calibrated to
  catch *that specific* document; the NUL zero-tolerance check above does that instead. This
  floor targets the DIFFERENT failure shape — a document where a large fraction of characters
  are unrenderable — which no real corpus example currently exhibits at any severity, so the
  floor is set with generous headroom below the worst *legitimate* case rather than tuned to a
  measured bad case.).
- **`\x00` (NUL byte) count: zero-tolerance** (any occurrence fails the gate).

## Page-coverage two-sided band

The existing floor (`coverage < 0.40`) is unchanged. For the ceiling, two real source-PDF
comparisons were available:

| Document | source PDF | pages | src_words | out_words | coverage |
|---|---|---|---|---|---|
| `goldblatt_-_mathematical_modal_logic_a_view_of_its_evolution` (fallback tier, forced via `LITERATURE_CONVERTER=pymupdf`, this task's must-pass regression case) | `Goldblatt - MATHEMATICAL MODAL LOGIC A VIEW OF ITS EVOLUTION.pdf` | 98 | 49175 | 49168 | 0.99986 |
| `gabbay_2000` (`.md.rejected` sibling already on disk — rejected for a different check, not coverage) | `Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf` | 614 | 252458 | 252819 | 1.00143 |

Both real data points sit within 0.2% of 1.0. Only two source PDFs were locatable/reconvertible
within this task's time budget (most corpus `metadata.json` `source_path` values point at
now-nonexistent temp paths from ingest time) — this is a smaller sample than the plan's "at
least 6" target, recorded here as a scope discrepancy rather than fabricating additional data
points. Given the research finding that this metric's numerator and denominator are correlated
(both are PyMuPDF extractions of the same document — see the inline code comment), a ceiling
does not need document-class-level precision to be a safe secondary signal.

- **Ceiling chosen: `coverage > 2.5`** — over 2.5x the source-page word count, i.e. more than 6x
  further from 1.0 than either real measured data point, while still bounded (not vacuous).

## Must-pass regression: Goldblatt 2006 (fallback tier)

`LITERATURE_CONVERTER=pymupdf bash agent-system/extensions/literature/scripts/literature-convert.sh
"Goldblatt - MATHEMATICAL MODAL LOGIC A VIEW OF ITS EVOLUTION.pdf" <scratch-dir>` (never written
into the corpus) produced `engine=pymupdf-fallback-heuristic`, `Quality gate: PASSED`,
`words=49168`. Its `printable_ratio` is 0.999892 (32 non-printable characters, 0 NUL) — comfortably
above the 0.85 floor — confirming the fallback tier's rescue of this document survives the new
checks.

## Gabbay/Kurucz 2003 source location

The task description's exact "Gabbay/Kurucz 2003" source PDF was not locatable under
`~/Projects/`, `~/Downloads/`, or Zotero storage (searched by author-name glob). What WAS found:
a real, already-on-disk `.md.rejected` sibling for a *different* Gabbay/Reynolds document
(`gabbay_2000`, rejected by the *existing* gate for a non-coverage, non-printable-ratio reason —
its printable_ratio is 1.0 and coverage is 1.0014), and the real already-ingested NUL-corrupted
`pym_ohearn_yang_2004_possible-worlds-resources-bi` document described above. Per the plan's
Risk-table mitigation, the latter substitutes as real must-flag evidence for the synthetic-fixture
gap, and the substitution is recorded here rather than passed off as the original cited case.
