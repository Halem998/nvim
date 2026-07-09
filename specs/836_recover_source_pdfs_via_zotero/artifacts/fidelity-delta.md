# Fidelity Delta: Task #836 Phase 6

Re-ran `.claude/scripts/literature-fidelity-audit.sh --write` (the existing #835 machinery) after
Phase 5 copied 7 PDFs into `sources/<doc_id>/`. Entries are re-classified by the script itself --
none were hand-stamped in this phase.

## `provenance_fidelity` distribution (per `index.json` entry, 280 total)

| Value | Before Phase 5 | After Phase 6 | Delta |
|---|---|---|---|
| `verified_conversion` | 84 | 91 | +7 |
| `no_source_pdf` | 52 | 45 | -7 |
| `unverified_no_baseline` | 15 | 15 | 0 |
| `unverified_summary` | 1 | 1 | 0 |
| `not_yet_converted` | 1 | 1 | 0 |
| `MISSING` (chunk-child entries) | 127 | 127 | 0 |
| **Total** | **280** | **280** | **0** |

Exactly 7 entries moved off `no_source_pdf`, matching `apply-log.json`'s 7 `copied` records
one-for-one. No other category changed.

## Entries that moved off `no_source_pdf`

| doc_id | New `provenance_fidelity` | word_ratio |
|---|---|---|
| `burgess_1982_i` | `verified_conversion` | 1.0982 |
| `burgess_1982_ii` | `verified_conversion` | 1.0705 |
| `bacon_2018_broadest-necessity` | `verified_conversion` | 1.7814 |
| `fine_2010_some-puzzles-of-ground` | `verified_conversion` | 2.0827 |
| `fine_2012_pure-logic-of-ground` | `verified_conversion` | 1.9118 |
| `fine_2012_counterfactuals-without-possible-worlds` | `verified_conversion` | 0.2455 |
| `fine_2012_guide-to-ground` | `verified_conversion` | 0.0327 |

All 7 landed in `verified_conversion` (not `unverified_no_baseline` or `unverified_summary`) per
the audit script's own detector logic -- this task did not choose or influence that
classification, only supplied the missing PDF baseline.

## Entries confirmed still `no_source_pdf` (45)

Every doc_id from the original 52-entry population that was NOT in the `copied` list remains
`no_source_pdf`, including:

- `kamp_1968_tense-logic-linear-order` (`matched-no-pdf` tier -- bibliographically identified via
  Zotero, but only an HTML snapshot exists, no PDF to copy)
- `fine_2014_truthmaker-semantics-intuitionistic` (`needs-confirmation` -- year/title mismatch,
  correctly left unresolved per the plan's explicit instruction not to guess)
- `pnueli_1977_temporal-logic-programs`, `een_2011_efficient-pdr-implementation` (`rejected` --
  confirmed false positives: wrong author / wrong subject)
- All 30 entries in the arXiv hardware-verification/LLM cluster (`absent` -- confirmed zero
  representation in this Zotero library)
- 11 other `absent` entries (`thomas_1997`, `alur_2013_syntax-guided-synthesis`,
  `lamport_2002_specifying-systems`, `solar-lezama_2008_sketching-thesis`, `biere_1999...`,
  `bradley_2011_ic3-pdr`, `burch_1992_symbolic-model-checking`, `herklotz_2021_vericert`,
  `kuehlmann_2002_robust-boolean-reasoning`, `mishchenko_2010_sequential-equivalence-checking`,
  `piterman_2006_gr1-synthesis`, `biere_2024_hwmcc-2024`, `witharana_2022_abv-survey`,
  `fine_2012_difficulty-possible-worlds-counterfactuals`)

Verified directly against `index.json`: all 45 non-copied doc_ids from the original 52 carry
`provenance_fidelity == "no_source_pdf"`; none was accidentally reclassified without a PDF, and
none of the 30-entry arXiv cluster changed.

## Enum integrity

Distinct `provenance_fidelity` values present after this phase: `verified_conversion`,
`no_source_pdf`, `unverified_no_baseline`, `unverified_summary`, `not_yet_converted`, plus
`MISSING` for chunk-child entries that never carry the field. This is exactly #835's five-value
enum -- no sixth value was introduced.

## Convergence

Re-ran `literature-fidelity-audit.sh --write` a second time: `index.json` md5sum was identical
before and after (`748f4c3eda015afc4082566c7814e446`), confirming the audit has converged and
produces no further change.

## No architectural regression

`test ! -e ~/Projects/Literature/pdfs` still holds -- the dissolved `pdfs/` directory was not
recreated at any point in this phase.
