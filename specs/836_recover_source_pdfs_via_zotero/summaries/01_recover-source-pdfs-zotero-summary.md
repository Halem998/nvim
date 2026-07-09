# Implementation Summary: Task #836

**Completed**: 2026-07-09
**Duration**: ~1.5 hours (all 7 phases)

## Overview

Built a read-only, Zotero-storage-root-safe resolver (`.claude/scripts/zotero-resolve-pdf.sh`),
swept all 52 `~/Projects/Literature/index.json` entries marked `provenance_fidelity ==
"no_source_pdf"` against the live Zotero library, gated non-key-anchored matches through a
year/similarity verification step, and applied the result idempotently. **7 of 52 PDFs were
recovered** and copied into their `sources/<doc_id>/` directories; `index.json` was updated with
verified Zotero identities and re-audited by the existing #835 fidelity machinery. The remaining
45 entries stay honestly marked `no_source_pdf` -- this is the correct, expected outcome per the
research report's empirically-verified ~13% recovery floor, not a resolution failure.

`~/Projects/Literature/pdfs/` (deliberately dissolved 2026-06-16) was never recreated.

## What Changed

- `.claude/scripts/zotero-resolve-pdf.sh` -- new read-only `doc_id` -> Zotero PDF resolver
  (live-api / sqlite-readonly / abort access modes; `key-anchored` / `search-candidate` /
  `matched-no-pdf` / `absent` tiers).
- `.claude/scripts/.zotero-title-sim.py` -- small helper computing normalized title similarity.
- `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` -- new context file
  documenting the live-API-vs-sqlite-vs-snapshot resolution pattern, the derived-storage-root
  rule, the citekey-vs-real-key gotcha, and the title-search truncation/similarity-floor
  mitigations discovered while building the resolver.
- `.claude/extensions/literature/index-entries.json` -- registered the new pattern file.
- `~/Projects/Literature/sources/<doc_id>/*.pdf` -- 7 new PDFs copied (see table below).
- `~/Projects/Literature/index.json` -- `zotero_key`/`zotero_path` set on 8 verified entries (7
  copied + `kamp_1968_tense-logic-linear-order`, identified but HTML-only); `provenance_fidelity`
  recomputed by `literature-fidelity-audit.sh` (52 -> 45 `no_source_pdf`, 84 -> 91
  `verified_conversion`, all other categories unchanged).
- `~/Projects/Literature/index.json.bak.836.<timestamp>` -- pre-mutation backup (retained).
- `specs/836_recover_source_pdfs_via_zotero/artifacts/` -- `corpus-baseline.txt`,
  `environment.json`, `resolution-manifest.json`, `dry-run-report.md`, `apply-log.json`,
  `fidelity-delta.md`.

## Final Disposition of All 52 Target Entries

| Disposition | Count | doc_ids |
|---|---|---|
| **recovered** | 7 | `burgess_1982_i`, `burgess_1982_ii`, `bacon_2018_broadest-necessity`, `fine_2010_some-puzzles-of-ground`, `fine_2012_pure-logic-of-ground`, `fine_2012_counterfactuals-without-possible-worlds`, `fine_2012_guide-to-ground` |
| **html-only** | 1 | `kamp_1968_tense-logic-linear-order` (Zotero item `AYJAC2IF` identified; only an HTML snapshot attachment exists, no PDF) |
| **needs-disambiguation** | 1 | `fine_2014_truthmaker-semantics-intuitionistic` (best candidate `S2VXD9JT` "Truthmaker Semantics", dated 2017 not 2014, lacks "intuitionistic" in title -- left unresolved per explicit instruction not to guess) |
| **absent-from-zotero** | 43 | see full list below |

### Full per-doc_id table

| doc_id | Disposition | Zotero key found | Decision |
|---|---|---|---|
| `burgess_1982_i` | recovered | `7XEG8NM9` | approved |
| `burgess_1982_ii` | recovered | `ZASX3GNR` | approved |
| `bacon_2018_broadest-necessity` | recovered | `Q3YVBYBT` | approved |
| `fine_2010_some-puzzles-of-ground` | recovered | `G953SI3G` | approved |
| `fine_2012_pure-logic-of-ground` | recovered | `TXUP5UWL` | approved |
| `fine_2012_counterfactuals-without-possible-worlds` | recovered | `5DAQR76K` | approved |
| `fine_2012_guide-to-ground` | recovered | `4JFAFMBY` | approved |
| `kamp_1968_tense-logic-linear-order` | html-only | `AYJAC2IF` | -- |
| `fine_2014_truthmaker-semantics-intuitionistic` | needs-disambiguation | `S2VXD9JT` (unconfirmed) | needs-confirmation |
| `pnueli_1977_temporal-logic-programs` | absent-from-zotero | `96GLGRC5` (rejected -- different author, Lamport 1980) | rejected |
| `een_2011_efficient-pdr-implementation` | absent-from-zotero | `4F3Z5EEG` (rejected -- unrelated paper, author-substring collision) | rejected |
| `fine_2012_difficulty-possible-worlds-counterfactuals` | absent-from-zotero | -- | -- (flagged as suspected duplicate of `fine_2012_counterfactuals-without-possible-worlds`) |
| `thomas_1997` | absent-from-zotero | -- | -- |
| `alur_2013_syntax-guided-synthesis` | absent-from-zotero | -- | -- |
| `lamport_2002_specifying-systems` | absent-from-zotero | -- | -- |
| `solar-lezama_2008_sketching-thesis` | absent-from-zotero | -- | -- |
| `biere_1999_symbolic-model-checking-without-bdds` | absent-from-zotero | -- | -- |
| `bradley_2011_ic3-pdr` | absent-from-zotero | -- | -- |
| `burch_1992_symbolic-model-checking` | absent-from-zotero | -- | -- |
| `herklotz_2021_vericert` | absent-from-zotero | -- | -- |
| `kuehlmann_2002_robust-boolean-reasoning` | absent-from-zotero | -- | -- |
| `mishchenko_2010_sequential-equivalence-checking` | absent-from-zotero | -- | -- |
| `piterman_2006_gr1-synthesis` | absent-from-zotero | -- | -- |
| `biere_2024_hwmcc-2024` | absent-from-zotero | -- | -- |
| `witharana_2022_abv-survey` | absent-from-zotero | -- | -- |
| `arxiv_2308.00708_verigen` | absent-from-zotero | -- | -- |
| `arxiv_2308.05345_rtlllm` | absent-from-zotero | -- | -- |
| `arxiv_2309.07544_verilogeval-v1` | absent-from-zotero | -- | -- |
| `arxiv_2311.00176_chipnemo` | absent-from-zotero | -- | -- |
| `arxiv_2312.08617_rtlcoder` | absent-from-zotero | -- | -- |
| `arxiv_2402.00386_assertllm` | absent-from-zotero | -- | -- |
| `arxiv_2406.18627_assertionbench` | absent-from-zotero | -- | -- |
| `arxiv_2408.09858_shortcircuit` | absent-from-zotero | -- | -- |
| `arxiv_2408.11053_verilogeval-v2` | absent-from-zotero | -- | -- |
| `arxiv_2410.23299_fveval` | absent-from-zotero | -- | -- |
| `arxiv_2502.00212_stp-self-play-theorem-provers` | absent-from-zotero | -- | -- |
| `arxiv_2503.15112_openllm-rtl` | absent-from-zotero | -- | -- |
| `arxiv_2504.01986_turtle` | absent-from-zotero | -- | -- |
| `arxiv_2507.04736_chipseek` | absent-from-zotero | -- | -- |
| `arxiv_2509.06239_proof2silicon` | absent-from-zotero | -- | -- |
| `arxiv_2510.00915_rl-verifiable-noisy-rewards` | absent-from-zotero | -- | -- |
| `arxiv_2512.18160_propose-solve-verify` | absent-from-zotero | -- | -- |
| `arxiv_2601.19747_veri-sure` | absent-from-zotero | -- | -- |
| `arxiv_2601.21448_chipbench` | absent-from-zotero | -- | -- |
| `arxiv_2603.03147_agentic-coverage-closure` | absent-from-zotero | -- | -- |
| `arxiv_2603.08738_formalrtl` | absent-from-zotero | -- | -- |
| `arxiv_2603.27630_rtlseek` | absent-from-zotero | -- | -- |
| `arxiv_2604.07666_imperfect-verifier-good-enough` | absent-from-zotero | -- | -- |
| `arxiv_2604.15149_llms-gaming-verifiers` | absent-from-zotero | -- | -- |
| `arxiv_2605.12857_chipmate` | absent-from-zotero | -- | -- |
| `arxiv_2605.22763_alphaproof-nexus` | absent-from-zotero | -- | -- |
| `arxiv_2605.27472_assertllm2` | absent-from-zotero | -- | -- |

`pnueli_1977_temporal-logic-programs` and `een_2011_efficient-pdr-implementation` produced a
Zotero search hit, but the secondary verification gate (Phase 4) rejected both as false positives
on year mismatch (and, for `pnueli`, a completely different author -- Lamport, not Pnueli). Both
remain `no_source_pdf`, correctly.

The 30-entry arXiv hardware-verification/LLM cluster (`arxiv_2308.00708_verigen` through
`arxiv_2605.27472_assertllm2`, plus `biere_1999...`, `bradley_2011_ic3-pdr`,
`burch_1992_symbolic-model-checking`, `herklotz_2021_vericert`,
`kuehlmann_2002_robust-boolean-reasoning`, `mishchenko_2010_sequential-equivalence-checking`,
`piterman_2006_gr1-synthesis`, `biere_2024_hwmcc-2024`, `witharana_2022_abv-survey`) has zero
representation in this Zotero library -- confirmed by the resolver returning `absent` for all 30
after a similarity-floor correction (see Decisions below) removed 9 initial false-positive
`search-candidate` classifications caused by common-surname collisions.

## Decisions

- **Recovery destination**: `sources/<doc_id>/`, never a recreated `pdfs/` directory (verified
  absent throughout: `test ! -e ~/Projects/Literature/pdfs`).
- **`zotero_key` fast path reinterpreted**: index.json's pre-existing `zotero_key` values for
  `burgess_1982_i`/`burgess_1982_ii` are Better-BibTeX citekeys, not real Zotero API item keys
  (confirmed: a direct lookup 404s). The resolver still performs a title/author search for these,
  but tiers the result `key-anchored` based on the pre-existing field's presence, preserving the
  higher-trust distinction the plan's tier scheme depends on. Per the plan's literal "set
  zotero_key only when currently null" instruction, these two entries' existing citekey-style
  `zotero_key` values were left untouched in Phase 5; only `zotero_path` was set for them.
- **Added a title-similarity floor (0.4) and progressive title right-truncation** to the
  resolver after an initial full sweep showed 9 of the 30 arXiv-cluster entries spuriously
  matching unrelated modal-logic/philosophy papers via weak author-surname collisions (e.g.
  "Een" substring-matching "Shaheen"). After the fix, all 30 correctly resolve to `absent`. See
  `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` section 6 for the full
  writeup.
- **`fine_2014_truthmaker-semantics-intuitionistic` left unresolved**, exactly per the plan's
  explicit instruction: the best candidate (`S2VXD9JT`, "Truthmaker Semantics", 2017) has a year
  and title mismatch against the doc_id (2014, "...Intuitionistic"), and no auto-acceptance was
  applied.
- **`fine_2012_difficulty-possible-worlds-counterfactuals` vs.
  `fine_2012_counterfactuals-without-possible-worlds`** flagged as a suspected corpus-metadata
  duplicate (near-identical titles); not de-duplicated here, per the plan's non-goals.
- **`zotero-generate-export.sh`'s `fetch_path3()` hardcoded storage-root bug** recorded as a
  follow-up item in the new context file; not fixed here, per the plan's non-goals (it is latent
  today since Path 3 only runs when the live API is down).

## Plan Deviations

- **Phase 1**: The corpus git tree was not clean at Phase 1 (contrary to the plan's literal
  "if dirty, stop and report" instruction). Investigated and classified as benign: task #835's
  own uncommitted `provenance_fidelity`/`word_ratio` backfill (a dependency this task consumes),
  plus concurrent task #833 artifacts, plus untracked new-entry directories unrelated to
  `sources/`. `sources/` itself was confirmed untouched. Proceeded with file-level-only rollback
  discipline (never bulk `git checkout`) for the remainder of the task, per the plan's own
  contingency clause for exactly this situation. See `artifacts/environment.json`
  `corpus_dirty_deviation`.
- **Phase 2**: The literal `zotero_key` fast-path (direct `GET /items/<key>/children`) does not
  work because the field holds citekeys, not real API keys (see Decisions above). Also added
  progressive title right-truncation and a similarity floor, beyond the plan's literal spec, to
  fix concrete false-positive/false-negative failure modes found empirically during
  implementation.
- **Phase 3**: `pnueli_1977_temporal-logic-programs` surfaced as `search-candidate` rather than
  the plan-expected `matched-no-pdf`, because an unrelated Lamport-1980 item with a genuine PDF
  outscored the correct-but-HTML-only Pnueli item on title similarity. Functionally equivalent --
  Phase 4 rejects the candidate either way, and the entry remains `no_source_pdf`.
- **Phase 4**: Two unambiguous false positives (`pnueli_1977`, `een_2011`) were routed to
  `decision: "rejected"` rather than the more generic `"needs-confirmation"` the task literally
  says to use for "every other" non-approved candidate, since the evidence for these two is
  dispositive (wrong author / wrong domain), unlike the genuinely ambiguous `fine_2014` case.
  `"rejected"` is a valid member of the plan's own decision enum.
- **Phase 5**: `burgess_1982_i`/`burgess_1982_ii` already had non-null (citekey-style)
  `zotero_key` values, so per the literal "when currently null" instruction those fields were
  left untouched; only `zotero_path` was set for those two entries.
- An intermediate jq bug (treating null-`id` chunk-child entries as object keys) truncated a
  scratch copy of `resolution-manifest.json` to 0 bytes mid-Phase-4. Recovered fully from the
  still-intact per-doc_id sweep files in `/tmp/zotero-sweep/`; no task-dir artifact or corpus file
  was permanently lost. See `progress/phase-4-progress.json` `incident_note`.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: N/A (no test suite for this corpus-mutation task); verification was empirical:
  - `zotero-resolve-pdf.sh` confirmed side-effect-free (`git status --porcelain` unaffected) and
    produces byte-identical output on repeated runs.
  - All 7 recovered PDFs verified by sha256 match between source (Zotero storage tree) and
    destination (`sources/<doc_id>/`).
  - **Idempotency**: the entire apply phase was re-run in full; the second run produced zero
    `copied` actions (all `skipped-identical`) and an identical `index.json` md5sum.
  - `literature-fidelity-audit.sh --write` re-run twice produced an identical `index.json` md5sum
    the second time (converged).
  - `index.json` retained 280 entries and parsed validly after every write.
  - `~/Projects/Literature/pdfs/` confirmed absent throughout.
  - Zotero's `zotero.sqlite` was never opened read-write (`access_mode: live-api` throughout;
    the sqlite fallback path was implemented but not exercised).
- Files verified: Yes

## Notes

- `~/Projects/Literature/index.json.bak.836.<timestamp>` is retained as a rollback point (280
  entries, validated at creation).
- The `~/Projects/Literature` corpus commit and this repository's commit are separate (different
  git repositories), per the plan's Phase 7 instruction.
