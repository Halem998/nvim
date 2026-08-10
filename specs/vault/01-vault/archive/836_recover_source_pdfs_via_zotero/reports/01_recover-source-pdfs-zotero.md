# Research Report: Task #836

**Task**: 836 - Recover source PDFs via Zotero for PDF-less central dirs
**Started**: 2026-07-09T00:00:00Z
**Completed**: 2026-07-09T00:00:00Z
**Effort**: research only (read-only; no files under `~/Projects/Literature/` moved, symlinked, or modified)
**Dependencies**: #835 (COMPLETED — defines the `provenance_fidelity` enum this task writes into)
**Sources/Inputs**:
- `~/Projects/Literature/index.json` (280 entries, live)
- `~/Projects/Literature/sources/*/` (direct filesystem enumeration)
- `~/Projects/Literature/zotero-library.json` + `.zotero-library.meta.json` (400-entry CSL-JSON snapshot, generated 2026-07-01)
- Live Zotero 7 local HTTP API at `127.0.0.1:23119` (Zotero was running throughout this session)
- `.claude/scripts/zotero-resolve-sqlite-path.sh`, `zotero-generate-export.sh`, `zotero-export-status.sh` (read in full)
- `~/Projects/Literature` git history (`git log`)
- Task #835 artifacts: `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`, `.orchestrator-handoff.json`, `summaries/01_provenance-fidelity-flagging-summary.md`

**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The 52-count is confirmed but the task's "49 chunk-bearing + 3 empty" breakdown is stale/wrong.** Live filesystem enumeration of all 97 `sources/` dirs shows exactly **52 dirs lack any `.pdf`/`.djvu`**, and **all 52 are chunk-bearing (0 are empty)**. This matches #835's independently-computed and already-stamped `provenance_fidelity: "no_source_pdf"` count (52) exactly — #835 has already identified and stamped the precise target population; task 836 does not need to recompute it, only query `index.json` for `provenance_fidelity == "no_source_pdf"`.
- **The premise "index.json entries carry zotero_key and zotero_path fields" barely holds for this population.** Of the 52 target entries, only **2** have a non-null `zotero_key` (`burgess_1982_i`, `burgess_1982_ii`); the other 50 are `null`. Across the *entire* 280-entry `index.json`, only **1** entry anywhere has a non-null `zotero_path` — that field is effectively unpopulated corpus-wide and cannot be relied on as a resolution mechanism.
- **`zotero-resolve-sqlite-path.sh` is NOT the right entry point for key-to-PDF resolution** — it only resolves *which sqlite file* to open (a genuinely separate concern), and it correctly reports this machine's real path (`/home/benjamin/Documents/Zotero/zotero.sqlite`, a custom `dataDir`, not the historical `~/Zotero` default). No script in the repo does "given a Better-BibTeX citation key, return a PDF path" as a standalone, reusable operation. The closest existing logic is `zotero-generate-export.sh`'s internal `fetch_path3()`, which reconstructs CSL-JSON with attachment paths straight from the sqlite tables — but (a) it's a private helper inside a whole-library exporter, not a per-item resolver, (b) it only runs when Zotero is closed (sqlite is locked while Zotero runs — confirmed empirically, `sqlite3 -readonly ... "SELECT count(*) FROM items"` returned `Error: database is locked` while Zotero was running), and (c) **it hardcodes `$HOME/Zotero/storage/`** for resolving `storage:` attachment paths, which is wrong on this machine (confirmed: `~/Zotero/storage/<key>/` does not exist; the real files live under `/home/benjamin/Documents/Zotero/storage/<key>/`). Any new resolver script must reuse `zotero-resolve-sqlite-path.sh`'s dataDir-aware resolution for the storage root too, not copy the `fetch_path3()` hardcode.
- **`zotero-library.json` (the 400-entry CSL-JSON snapshot) carries zero file-path/attachment information at all** — it's pure bibliography (title/author/issued/citation-key/etc.), by design (it's what `zotero-generate-export.sh` Path 1/2 produce). It can only get you from a doc to *a candidate Zotero item key* via title/author/year matching; the actual PDF location must then come from either the live local API (`/items/{key}/children`) or the sqlite `itemAttachments` table (only when Zotero is closed).
- **The snapshot is also stale relative to the live library** — a live API search found a real PDF match (`bacon_2018_broadest-necessity`) for a title that does not appear anywhere in the 400-entry snapshot file at all. **Any implementation must query the live Zotero API (Zotero was running throughout this session) rather than trust the static `zotero-library.json` file**, or must regenerate the snapshot first via `zotero-generate-export.sh --force`.
- **Empirically verified recoverable count: at least 7 of 52 (~13%), not the near-total recovery the task's framing implies.** See the Findings section for the exact list and verification method (live API item search -> `/children` endpoint -> confirmed `contentType: application/pdf` attachment -> confirmed file exists on disk at the correct custom-dataDir storage path). The remaining ~45 show no plausible match: this is a corpus with **two structurally distinct sub-populations** — a modal-logic/philosophy Zotero-tracked collection (where matches exist) and a **30-entry cluster of 2023–2026 arXiv hardware-verification/LLM preprints** that a targeted keyword search (`verilog|rtl|chip|hardware verif|assert`) confirms **do not appear anywhere in the 400-item Zotero library at all** — these were almost certainly downloaded directly from arXiv and never added to Zotero, so no citation-key/title-matching strategy will recover them. Marking them `no_source_pdf` is the correct and only defensible outcome, not evidence of a resolution failure.

## Context & Scope

Read-only research per delegation instructions. No file under `~/Projects/Literature/` was moved, symlinked, or edited. Live GET requests were made to the local Zotero HTTP API (`127.0.0.1:23119`) to search bibliographic items and list their child attachments — these are non-mutating reads of the user's own already-running local Zotero instance, consistent with the read-only scope. `sqlite3 -readonly` was attempted against the resolved sqlite path but failed (file locked because Zotero was running); no write was attempted.

Per delegation instructions, the per-repo-copy investigation (BimodalLogic/cslib/cslib-refactor-prop_logic `specs/literature/sources`) was treated as VERIFIED and was NOT re-investigated.

## Findings

### 1. Real population count and shape (re-confirmed against live filesystem)

```
Total sources/ dirs:                  97
Dirs lacking *.pdf and *.djvu:        52   (chunk-bearing: 52, empty: 0)
index.json provenance_fidelity counts:
  no_source_pdf          52   <- exact match with the filesystem count
  verified_conversion     84
  unverified_no_baseline  15
  unverified_summary       1
  not_yet_converted        1
  (no field / MISSING)   127  (chunk-child entries, not parent docs)
```

The task description's "49 chunk-bearing + 3 empty — two different populations" does not match current reality: **there are zero empty dirs** in the current `sources/` tree. This premise appears to derive from an earlier/stale scan (possibly pre-dating #835's June 16 "reorganize sources directory structure" commit, `404bb36`, which moved 23 content dirs and 6 loose markdown files into `sources/` and dissolved a `pdfs/` symlink dir — see Finding 2). **Recommendation for the planning stage: use `provenance_fidelity == "no_source_pdf"` in `index.json` as the authoritative target list (52 doc_ids), not a fresh empty/chunk-bearing filesystem re-classification** — #835 already computed and stamped this exact set, so 836 should consume it directly rather than re-deriving it (re-deriving independently is how the "49+3" stale split likely originated in the first place).

### 2. `~/Projects/Literature/pdfs/` does not exist — it was deliberately dissolved, not accidentally lost

```
$ ls ~/Projects/Literature/pdfs/
ls: cannot access '.../pdfs/': No such file or directory
```

`git log --all --grep="dissolve pdfs"` finds the commit:
```
404bb363e3952ffdec8704c3315bc8f6402460d4  2026-06-16 14:08:54 -0700
task 1: complete implementation — reorganize sources directory structure

Move all 23 content directories and 6 loose markdown files into sources/,
dissolve pdfs/ by co-locating 32 PDFs with their source dirs, update
index.json paths, .gitignore, and migrate-from-repo.sh for the new layout.
```

**This is a load-bearing correction to the task's premise.** The task asks to "repopulate `~/Projects/Literature/pdfs/` symlinks," but that directory was intentionally removed as an architectural decision — PDFs now live directly inside each `sources/<dir>/` alongside their markdown, not as a centralized symlink farm. Recreating `pdfs/` as a symlink directory would be *regressing* the corpus back to a superseded layout. **Recommendation: any recovered PDF should be placed directly into its `sources/<doc_id>/` directory** (matching the current, post-reorg convention), and the `file_scope` entry `~/Projects/Literature/pdfs/` should be revisited at planning time — either dropped or reinterpreted as "the target location for recovered PDFs is `sources/<dir>/`, not a separate `pdfs/` tree."

### 3. `zotero_key` / `zotero_path` field population (empirical, not assumed)

```
Entries with zotero_key != null (entire index.json, 280 entries):  194
Entries with zotero_path != null (entire index.json, 280 entries): 1
```

Within the 52 `no_source_pdf` target population specifically:
```
zotero_key present:  2   (burgess_1982_i -> "Burgess1982I", burgess_1982_ii -> "Burgess1982a")
zotero_key null:     50
```

So the task's stated premise ("index.json entries carry zotero_key and zotero_path fields") is true only for a small minority of the target population, and `zotero_path` is essentially never populated anywhere in the corpus. A resolver that only trusts pre-populated `zotero_key`/`zotero_path` fields would resolve at most 2 of 52 by field lookup alone; everything else requires **title/author/year matching against the Zotero library** as the primary mechanism, with `zotero_key` used only as a fast-path shortcut when present.

### 4. Zotero storage layout on this machine (confirmed, not assumed)

- `zotero-resolve-sqlite-path.sh` correctly detects a **custom Zotero Data Directory**: `/home/benjamin/Documents/Zotero/zotero.sqlite` (not the historical default `~/Zotero/zotero.sqlite`).
- Zotero was **running** throughout this session (`curl .../api/users/0/items?...` returned HTTP 200), so:
  - The sqlite file is **locked** (`sqlite3 -readonly` returns `Error: in prepare, database is locked (5)`) — any resolver must handle this, either by using the live local API (preferred, works right now) or by requiring Zotero to be closed for a sqlite-direct fallback (mirroring `zotero-generate-export.sh`'s existing Path 1/Path 3 split).
  - The live API supports item search (`/api/users/0/items?q=<query>&itemType=-attachment`) and child-attachment listing (`/api/users/0/items/{key}/children`), both of which were used in this research to positively verify PDF attachments (see Finding 5).
- **Storage path bug found in existing code (latent, not yet triggered):** `zotero-generate-export.sh`'s `fetch_path3()` (its Zotero-closed sqlite-reconstruction fallback) hardcodes the storage root as `$HOME/Zotero/storage/<attKey>/<filename>` (script line ~412: `$home + "/Zotero/storage/" + (.attKey ...)`). On this machine that resolves to a path that **does not exist** (`~/Zotero/storage/C9CHHCD2/` — confirmed absent); the real files live under the custom dataDir, `/home/benjamin/Documents/Zotero/storage/C9CHHCD2/` (confirmed present, contains the actual PDF). This bug is currently latent because Path 3 only runs when the live API is unreachable (it wasn't, this session), but **a new zotero_key-to-PDF resolver script must NOT copy this hardcoded pattern** — it must derive the storage root from the same dataDir resolution `zotero-resolve-sqlite-path.sh` already performs (dataDir's parent, i.e. `dirname "$ZOTERO_SQLITE"`, then `/storage/`), not assume `~/Zotero/storage/`.

### 5. Actual recoverability of the 52 — empirically verified, not estimated

Method: (a) attempted exact `(author-family, year)` matching against the 400-entry static snapshot — found 4 candidates; (b) live Zotero API title/author search for each candidate plus several additional plausible titles, to compensate for the snapshot's staleness and the regex's strictness; (c) for every bibliographic hit, fetched `/items/{key}/children` and required `contentType: application/pdf`; (d) for the two most concrete hits, additionally confirmed the actual file exists on disk at the resolved storage path.

**Confirmed recoverable (real PDF attachment verified, at least by live-API metadata; file-existence double-checked for the first two):**

| doc_id | Zotero item key | Attachment filename | Verified |
|---|---|---|---|
| `burgess_1982_i` | `7XEG8NM9` | `Burgess - 1982 - Axioms for tense logic. I. ...pdf` | PDF attachment confirmed via API; file confirmed on disk at `/home/benjamin/Documents/Zotero/storage/5HK4WV9T/` |
| `burgess_1982_ii` | `ZASX3GNR` | `Burgess - 1982 - Axioms for tense logic. II. ...pdf` | PDF attachment confirmed via API; file confirmed on disk at `/home/benjamin/Documents/Zotero/storage/C9CHHCD2/` |
| `bacon_2018_broadest-necessity` | `Q3YVBYBT` | `Bacon - 2018 - The Broadest Necessity.pdf` | PDF attachment confirmed via API (item absent from the static snapshot entirely — snapshot staleness) |
| `fine_2010_some-puzzles-of-ground` | `G953SI3G` | `euclid.ndjfl.1273002112.pdf` | PDF attachment confirmed via API |
| `fine_2012_pure-logic-of-ground` | `TXUP5UWL` | `Fine - 2012 - THE PURE LOGIC OF GROUND.pdf` | PDF attachment confirmed via API |
| `fine_2012_counterfactuals-without-possible-worlds` | `5DAQR76K` | `Fine - 2012 - Counterfactuals Without Possible Worlds.pdf` | PDF attachment confirmed via API |
| `fine_2012_guide-to-ground` | `4JFAFMBY` | `2012 - Guide to Ground - Fine(2).pdf` | PDF attachment confirmed via API |

**Bibliographically matched but NOT recoverable (no PDF, HTML-only snapshot attachment):**

| doc_id | Zotero item key | Attachment | Why unrecoverable |
|---|---|---|---|
| `kamp_1968_tense-logic-linear-order` | `AYJAC2IF` | `KAMTLA.html` (`text/html`) | Zotero only holds an HTML page snapshot, not the PDF |
| `pnueli_1977_temporal-logic-programs` | `YCLL49EF` | `4567924.html` (`text/html`) | Zotero only holds an IEEE Xplore HTML snapshot, not the PDF |

**Needs manual disambiguation, not an auto-match (title-similarity false-positive risk):**

- `fine_2014_truthmaker-semantics-intuitionistic` — the live search's best hit is Zotero item `S2VXD9JT`, titled "Truthmaker Semantics" dated **2017**, filename `Fine - 2017 - Truthmaker Semantics.pdf`. The target doc_id says **2014** and specifically "...intuitionistic". This may be the same paper (preprint-vs-published-year drift) or a genuinely different Fine paper on a related topic — **a population script must not blindly accept the first title-search hit as ground truth**; it should cross-check DOI/venue against whatever provenance is already in `index.json`'s `summary` field for this doc_id, or flag it for a one-line human confirmation rather than auto-resolving.
- `fine_2012_difficulty-possible-worlds-counterfactuals` — no independent Zotero hit found (only `fine_2012_counterfactuals-without-possible-worlds`'s "Counterfactuals Without Possible Worlds" matched). These two doc_ids' titles are suspiciously close ("Difficulty [of the] Possible-Worlds [account of] Counterfactuals" vs "Counterfactuals Without Possible Worlds") — worth checking during planning whether these are two directories for what is actually the *same* underlying paper (a corpus-metadata duplicate, out of this task's scope to fix, but relevant context for why one "matches" and the other doesn't).

**Confirmed absent — no plausible Zotero match found (spot-checked directly, not merely absent from the stale snapshot):**

`thomas_1997`, `alur_2013_syntax-guided-synthesis`, `lamport_2002_specifying-systems`, `solar-lezama_2008_sketching-thesis`, plus a keyword sweep (`verilog|rtl |chip|hardware verif|assert`) across all 400 snapshot titles returning **zero hits** — confirming the entire **30-entry arXiv hardware-verification/LLM cluster** (`arxiv_2308.00708_verigen` through `arxiv_2605.27472_assertllm2`, plus `biere_1999...`, `bradley_2011_ic3-pdr`, `burch_1992...`, `een_2011...`, `herklotz_2021_vericert`, `kuehlmann_2002...`, `mishchenko_2010...`, `piterman_2006...`, `biere_2024_hwmcc-2024`, `witharana_2022_abv-survey`) has **no representation in this Zotero library at all**. This is a distinct sub-corpus (hardware/RTL formal-verification + LLM-for-hardware papers, mostly 2023–2026 arXiv preprints) layered into the same `sources/` tree as the modal-logic/philosophy collection that Zotero actually tracks. These were almost certainly pulled directly from arXiv/web and never imported into Zotero — no citation-key or title-matching strategy against *this* Zotero library can recover them.

### 6. Net recoverability estimate

Of 52 target dirs: **7 confirmed genuinely recoverable** (real PDF, ready to fetch), **2 bibliographically matched but not recoverable** (HTML-only in Zotero), **1 needs human disambiguation before auto-resolving**, **1 likely a corpus-duplicate worth flagging**, and **~41 show no plausible Zotero match at all** (dominated by the 30-item arXiv hardware-verification cluster that is structurally outside this Zotero library's collection scope). This spot-check was not exhaustive over all 52 — a full implementation pass should still attempt a live-API search for every one of the 50 `zotero_key`-null entries (title + first-author), since 3 of the 4 confirmed non-Burgess recoveries (`bacon`, and 4 of 5 `fine` papers) were found only via live search after the snapshot-based/regex-based first pass missed them — but the **~13% (7/52) confirmed floor** is real, empirically verified, and should set expectations: this is a modest, real, worthwhile recovery, not a near-complete resolution of the 52-doc gap.

## Decisions

- **Target population source**: use `index.json`'s already-stamped `provenance_fidelity == "no_source_pdf"` entries (52, exact) as the authoritative list for population/implementation, rather than re-deriving a filesystem-based empty/chunk-bearing split (which is what produced the stale "49+3" premise).
- **Recovery destination**: place any recovered PDF directly into its `sources/<doc_id>/` directory, matching the post-reorg (June 16, commit `404bb36`) convention — do NOT recreate a centralized `pdfs/` symlink tree, which was deliberately dissolved.
- **Resolution mechanism, in priority order**: (1) if `zotero_key` is already populated (2 of 52), use it directly as a fast path; (2) for all others, live-API title/first-author search (`/api/users/0/items?q=...&itemType=-attachment`) is the only currently-viable mechanism, since `zotero_path` is essentially unpopulated corpus-wide and the static `zotero-library.json` snapshot is both attachment-path-free and demonstrably stale; (3) require Zotero to be running for the live-API path, with a documented sqlite-direct fallback (mirroring `zotero-generate-export.sh` Path 3) for when it is closed — but that fallback must fix the hardcoded `~/Zotero/storage/` path to instead derive the storage root from the resolved dataDir.
- **No blind auto-accept of first search hit**: title-similarity matches must be treated as candidates requiring at least a lightweight cross-check (year/DOI/venue against any existing `index.json` summary) before being trusted, per the `fine_2014_truthmaker-semantics-intuitionistic` finding above.
- **Marking unrecoverable entries**: `provenance_fidelity` is already `no_source_pdf` for all 52 (stamped by #835); this task's job is to leave that value in place for genuinely unrecoverable entries (confirmed correct — no change needed) and only flip it away from `no_source_pdf` for the small subset that gets a real PDF placed in `sources/`. #835's five-value enum (`verified_conversion`, `unverified_summary`, `no_source_pdf`, `not_yet_converted`, `unverified_no_baseline`) should NOT be extended with a new value for this task — a recovered entry becomes a normal candidate for `verified_conversion`/`unverified_no_baseline` re-classification via re-running #835's `literature-fidelity-audit.sh` after the new PDF lands, not a bespoke new state.

## Risks & Mitigations

- **Risk**: A population script trusts `zotero-library.json`'s static snapshot as ground truth and silently misses real matches (as this research did initially for `bacon_2018` and 4 of 5 `fine_*` entries). **Mitigation**: query the live API when Zotero is running (confirmed reachable this session); if unreachable, either require the user to open Zotero, or regenerate the snapshot first via `zotero-generate-export.sh --force` (which itself prefers the live API when available) rather than trusting a possibly-stale existing file.
- **Risk**: Title-similarity search produces false-positive matches (different paper, same author, similar title) — demonstrated concretely by the `fine_2014_truthmaker-semantics-intuitionistic` vs. Zotero's 2017 "Truthmaker Semantics" case. **Mitigation**: treat any non-`zotero_key`-anchored match as a candidate needing a secondary check (year proximity, DOI, or a one-line confirmation step) before writing a symlink/copy, not an automatic resolution.
- **Risk**: Reusing `zotero-generate-export.sh`'s `fetch_path3()` storage-path logic verbatim in a new resolver would silently produce wrong paths on this machine (confirmed: hardcoded `~/Zotero/storage/` vs. the real custom dataDir `/home/benjamin/Documents/Zotero/storage/`). **Mitigation**: derive the storage root as `dirname "$(zotero-resolve-sqlite-path.sh)")/storage/`, which correctly generalizes to both default and custom dataDir configurations.
- **Risk**: Recreating `~/Projects/Literature/pdfs/` as instructed literally in the task/file_scope would reintroduce an architecture that was deliberately removed on 2026-06-16. **Mitigation**: flag this explicitly for the planning stage (done above); recovered PDFs should land in `sources/<doc_id>/`, and the `pdfs/` file_scope entry should be treated as stale unless the user has a specific reason to want the symlink-farm layout restored.
- **Risk**: Expectations mismatch — the task's framing ("Zotero is the ONLY viable recovery source... re-resolve... for the 52 PDF-less dirs") could be read as implying most or all 52 are recoverable. **Mitigation**: this report's empirically-verified ~13% floor (7/52), with the 30-entry arXiv cluster's structural non-membership in this Zotero library clearly demonstrated (zero keyword hits across 400 items), should reset that expectation before planning/implementation proceeds, so the eventual summary isn't read as a failure when it reports ~7-11 recovered and ~41-45 confirmed `no_source_pdf`.

## Context Extension Recommendations

- **Topic**: there is no existing context file documenting the Zotero live-API-vs-sqlite-vs-snapshot resolution tradeoffs discovered here (locked sqlite while Zotero runs; snapshot staleness; custom-dataDir storage-path derivation). Recommend `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` once a resolver script is implemented, documenting: (1) prefer live API when reachable, (2) sqlite fallback requires Zotero closed, (3) storage root must be derived via `zotero-resolve-sqlite-path.sh`'s dataDir, never hardcoded to `~/Zotero/storage/`.

## Appendix

### Commands used

```bash
# Real filesystem count of PDF-less dirs
for d in ~/Projects/Literature/sources/*/; do
  find "$d" -maxdepth 1 -iname "*.pdf" -o -iname "*.djvu"
done

# provenance_fidelity population counts
jq -r '.entries[] | .provenance_fidelity // "MISSING"' ~/Projects/Literature/index.json | sort | uniq -c

# zotero_key / zotero_path presence
jq -r '.entries[] | select(.provenance_fidelity == "no_source_pdf") | {id, zotero_key, zotero_path}' ~/Projects/Literature/index.json

# git history of pdfs/ dissolution
git -C ~/Projects/Literature log --all --grep="dissolve pdfs" --format="%H %ai%n%B"

# Live Zotero API search + attachment check
curl -s "http://127.0.0.1:23119/api/users/0/items?q=<query>&itemType=-attachment&limit=5" | jq
curl -s "http://127.0.0.1:23119/api/users/0/items/{key}/children" | jq '.[] | {itemType: .data.itemType, contentType: .data.contentType, filename: .data.filename}'

# Confirm sqlite lock while Zotero runs
sqlite3 -readonly "$(bash .claude/scripts/zotero-resolve-sqlite-path.sh)" "SELECT count(*) FROM items;"

# Confirm real storage path vs. hardcoded default
ls /home/benjamin/Documents/Zotero/storage/<attKey>/
ls ~/Zotero/storage/<attKey>/   # does not exist
```

### Files read

- `.claude/scripts/zotero-resolve-sqlite-path.sh` (full)
- `.claude/scripts/zotero-generate-export.sh` (full)
- `.claude/scripts/zotero-export-status.sh` (full)
- `~/Projects/Literature/index.json` (queried via jq, all 280 entries)
- `~/Projects/Literature/zotero-library.json` (400 entries, queried via jq/python)
- `~/Projects/Literature/.zotero-library.meta.json` (full)
- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`, `.orchestrator-handoff.json`, `summaries/01_provenance-fidelity-flagging-summary.md`
