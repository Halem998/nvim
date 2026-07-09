# Dry-Run Report: Task #836 Phase 3

**Generated**: 2026-07-09 (UTC timestamp in `resolution-manifest.json`)
**Status**: DRY RUN ONLY. No file has been copied, no `index.json` field has been written, no
Zotero item or file has been touched. This report describes what Phase 5 (Apply) *would* do.

## Population

52 of 52 `no_source_pdf` entries in `~/Projects/Literature/index.json` were swept (confirmed
count matches the plan and research report exactly).

## Tier counts

| Tier | Count |
|---|---|
| `key-anchored` | 2 |
| `search-candidate` | 8 |
| `matched-no-pdf` | 1 |
| `absent` | 41 |

## What would be copied (pending Phase 4 approval)

| doc_id | tier | zotero_key | title_similarity | doc year | zotero year | Would copy to |
|---|---|---|---|---|---|---|
| `burgess_1982_i` | key-anchored | `7XEG8NM9` | 1.0 | 1982 | 1982 | `sources/burgess_1982_i/Burgess - 1982 - Axioms for tense logic. I. ...pdf` |
| `burgess_1982_ii` | key-anchored | `ZASX3GNR` | 1.0 | 1982 | 1982 | `sources/burgess_1982_ii/Burgess - 1982 - Axioms for tense logic. II. ...pdf` |
| `bacon_2018_broadest-necessity` | search-candidate | `Q3YVBYBT` | 1.0 | 2018 | 2018 | `sources/bacon_2018_broadest-necessity/Bacon - 2018 - The Broadest Necessity.pdf` |
| `fine_2010_some-puzzles-of-ground` | search-candidate | `G953SI3G` | 1.0 | 2010 | 2010 | `sources/fine_2010_some-puzzles-of-ground/euclid.ndjfl.1273002112.pdf` |
| `fine_2012_pure-logic-of-ground` | search-candidate | `TXUP5UWL` | 0.9091 | 2012 | 2012 | `sources/fine_2012_pure-logic-of-ground/Fine - 2012 - THE PURE LOGIC OF GROUND.pdf` |
| `fine_2012_counterfactuals-without-possible-worlds` | search-candidate | `5DAQR76K` | 1.0 | 2012 | 2012 | `sources/fine_2012_counterfactuals-without-possible-worlds/Fine - 2012 - Counterfactuals Without Possible Worlds.pdf` |
| `fine_2012_guide-to-ground` | search-candidate | `4JFAFMBY` | 0.9375 | 2012 | 2012 | `sources/fine_2012_guide-to-ground/2012 - Guide to Ground - Fine(2).pdf` |

These 7 rows are exactly the research report's confirmed-recoverable list. Each has a
`resolved_path` under `$ZOTERO_STORAGE_ROOT` that passes `test -f`, and (except the two
`key-anchored` rows) each has doc-year == zotero-year exact match, satisfying Phase 4's
auto-approve condition. Expected Phase 5 outcome: **7 PDFs copied**.

## What would NOT be copied (surfaced, but must not be auto-approved)

| doc_id | tier | zotero_key | title_similarity | doc year | zotero year | Disposition |
|---|---|---|---|---|---|---|
| `fine_2014_truthmaker-semantics-intuitionistic` | search-candidate | `S2VXD9JT` ("Truthmaker Semantics") | 0.7273 | 2014 | **2017** | Year mismatch, explicitly called out in the plan/research as needing human disambiguation. Phase 4 must route this to `needs-confirmation`/`rejected`, never `approved`. |
| `pnueli_1977_temporal-logic-programs` | search-candidate | `96GLGRC5` (Lamport, "``Sometime'' is sometimes ``not never''...") | 0.5227 | 1977 | **1980** | Different paper, different author (Lamport, not Pnueli) that happens to share title words. Year mismatch correctly disqualifies auto-approval. |
| `een_2011_efficient-pdr-implementation` | search-candidate | `4F3Z5EEG` ("Meaning and Explanation") | 0.4314 | 2011 | **2014** | Unrelated philosophy paper; matched via a substring collision on the author-fallback query ("Een" substring-matches "Shaheen"). Year mismatch correctly disqualifies auto-approval. |

## Bibliographically matched but not recoverable (HTML-only)

| doc_id | tier | zotero_key | title | Why unrecoverable |
|---|---|---|---|---|
| `kamp_1968_tense-logic-linear-order` | matched-no-pdf | `AYJAC2IF` | "Tense Logic and the Theory of Linear Order" | Only a `KAMTLA.html` snapshot attachment, no PDF. |

Note: the plan's Phase 3 verification expected *both* `kamp_1968...` and `pnueli_1977...` to
land in `matched-no-pdf`. `pnueli_1977` instead surfaced as `search-candidate` because a
different, unrelated item (Lamport 1980) with a genuine PDF attachment scored higher similarity
(0.5227) than the floor and was selected as the resolver's best-PDF candidate ahead of the
correct-but-HTML-only Pnueli 1977 item. This is flagged here as a resolver-tier deviation, not a
data-loss risk: Phase 4's year check (1977 vs matched 1980) will reject this candidate exactly as
it would have rejected a `matched-no-pdf` classification, and the entry remains `no_source_pdf`
either way.

## Absent (41 entries) -- confirmed no plausible Zotero match

All 30 arXiv hardware-verification/LLM-for-hardware cluster entries land in `absent`, plus 11
others (`thomas_1997`, `alur_2013_syntax-guided-synthesis`, `lamport_2002_specifying-systems`,
`solar-lezama_2008_sketching-thesis`, `biere_1999...`, `bradley_2011_ic3-pdr`,
`burch_1992_symbolic-model-checking`, `herklotz_2021_vericert`,
`kuehlmann_2002_robust-boolean-reasoning`, `mishchenko_2010_sequential-equivalence-checking`,
`piterman_2006_gr1-synthesis`, `biere_2024_hwmcc-2024`, `witharana_2022_abv-survey`,
`fine_2012_difficulty-possible-worlds-counterfactuals`). This matches the research report's
prediction: this is a structurally distinct sub-corpus with zero representation in this Zotero
library, not a resolution failure.

An initial resolver pass (before a `title_similarity >= 0.4` floor was added — see Phase 2
deviation notes) spuriously classified 9 of these 30 arXiv entries as `search-candidate` via
common-surname author-fallback collisions (e.g. author "Liu" matching an unrelated modal-logic
paper by a different "Liu"; similarities 0.12-0.34). The floor was added specifically to correct
this and was re-verified against the full sweep before this report was written.

## Full manifest

See `resolution-manifest.json` for the complete 52-record list with all fields.

## No changes made

`git -C ~/Projects/Literature status --porcelain -- sources/` remains empty; `index.json` is
untouched by this phase (its pre-existing dirty state from task #835's backfill and task #833's
concurrent work is unrelated to this sweep -- see Phase 1's `environment.json` for that
investigation).
