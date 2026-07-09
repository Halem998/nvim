# Research Report: Task #832

**Task**: 832 - Reconvert and validate the actionable portion of the ~/Projects/Literature corpus
**Started**: 2026-07-09T23:34:00Z
**Completed**: 2026-07-09T23:59:00Z
**Effort**: N/A (research only)
**Dependencies**: 831 (complete), 835 (complete), 836 (complete), 839 (complete — landed immediately before this research)
**Sources/Inputs**: Live `~/Projects/Literature/index.json`, live filesystem under `~/Projects/Literature/sources/`, `.claude/scripts/literature-{convert,ingest,build-index,fidelity-audit,chunk}.sh`, `pdftotext`/PyMuPDF probes, prior task artifacts (831/834/835/836/839)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The stale-description warning is correct on all five points; #839 has landed, the audit fails closed, and a live `--dry-run` run of `literature-fidelity-audit.sh` **exactly confirms** the claimed 13 actionable directories across 4 cohorts (5 + 3 + 4 + 1).
- However, live inspection of the actual PDF/markdown content uncovers three material corrections the stale description (and even the "NOW TRUE" framing) does not anticipate:
  1. **2 of the 5 `not_yet_converted` dirs are not simple greenfield conversions.** `gabbay_2000`'s 614-page PDF extracts **0 words** under both `pdftotext` and PyMuPDF (`fitz`) — it is a scanned image book with no embedded text layer, i.e. the *same* OCR blocker as the `unverified_no_baseline` cohort, not a "run the converter" case. `negri_von_plato_2001`'s PDF is literally a 4-page **table-of-contents-only** scan (confirmed by content, not just the filename) — there is no book text to convert at all. Only `girard_1989`, `troelstra_schwichtenberg_2000`, and `van_doorn_2015` are genuinely clean greenfield candidates.
  2. **1 of the 3 `unadjudicated` dirs (`venema_1991`) is likely a false reconversion candidate.** Its low ratio (0.37) is best explained by the audit's `pdf_words` denominator summing the full 184-page book PDF alongside two already-selective subset PDFs (ch2: 41pp, appendices A/B: 18pp = 59 of 184 pages) that are the *only* pages ever meant to be converted — an intentional partial-conversion pattern structurally identical to `thomas_2003_reactive`/`doets_1987`/`libkin_2004_ch3_ch7`, not a genuine content gap. Reconverting the same 59 pages cannot raise this ratio. The two Fine papers, by contrast, ARE genuine reconversion candidates: both `.md` files visibly cut off mid-argument partway through the source PDF (confirmed by reading file tails), and reconversion with the #831-fixed pipeline should substantially improve them.
  3. **OCR tooling (`ocrmypdf`, `tesseract`, `pytesseract`) is confirmed absent** from this NixOS machine by direct probe (not assumed). One document in the `unverified_no_baseline` cohort (`vardi_wolper_1986`) already carries a self-disclosing placeholder `.md` stating exactly this ("OCR conversion requires tesseract (not currently installed)"), independently corroborating the finding. This is a genuine blocker for that cohort as specified, and — per finding (1) above — now *also* blocks `gabbay_2000`.
- Discredited numbers from the description (single-file-sampling ratios, "ZERO healthy" claim, upper-bound-ratio risk on fine_2010/fine_2012_pure-logic/bacon_2018) are **not restated** anywhere in this report, per instructions.
- **Recommendation**: split cohort work into a converter path (3 clean not_yet_converted dirs + 2 genuine unadjudicated dirs = 5 items using `literature-ingest.sh`/`literature-convert.sh`), a blocked-pending-OCR path (4 unverified_no_baseline dirs + `gabbay_2000`), a needs-real-source-PDF path (`negri_von_plato_2001`, likely a spawn/acquisition task rather than an in-scope conversion), a disclosure-banner path (`venema_1991`, mirroring #839's Option A fix for `thomas_2003_reactive`), and a straightforward reconversion (`rabinovich_2014`). All are followed by `literature-build-index.sh --global` and a final `literature-fidelity-audit.sh --write`.

## Context & Scope

Task 832's stored description in `specs/state.json` (revision 2, `last_updated: 2026-07-09T22:21:58Z`) was written before #839 landed and is explicitly marked stale by the orchestrator's delegation preamble on five points (fail-open workaround, residual-ratio risk, thomas_2003_reactive treatment, BLOCKED status, and stale dir-level counts). This research re-derives every cohort from the **live** index and filesystem rather than trusting either the stored description or the delegation preamble's own restated numbers, per the delegation's explicit instruction to "re-derive them yourself from the LIVE index."

Two independent granularities exist in the corpus and are kept distinct throughout this report:
- **Directory granularity** (97 `sources/<dir>/` directories) — what `literature-fidelity-audit.sh` classifies and what "13 actionable dirs in 4 cohorts" refers to.
- **Index-entry granularity** (153 non-null-`provenance_fidelity` entries out of 280 total index.json entries, the rest being unstamped `chunk_*`/sub-document rows) — what the delegation's "153 entries" breakdown refers to.

## Findings

### Live cohort verification (directory granularity — `literature-fidelity-audit.sh --dry-run`, run just now, zero writes)

```
--- Population summary ---
verified_conversion: 39
unverified_summary: 1
no_source_pdf: 45
not_yet_converted: 5
unverified_no_baseline: 4
unadjudicated: 3
Total directories: 97
```

13 actionable directories (5+4+3+1) — **the claimed count is exactly confirmed** at directory granularity. Per-directory detail from the same dry run:

| dir | provenance_fidelity | word_ratio | md_words | pdf_words |
|---|---|---|---|---|
| gabbay_2000 | not_yet_converted | — | — | — |
| girard_1989 | not_yet_converted | — | — | — |
| negri_von_plato_2001 | not_yet_converted | — | — | — |
| troelstra_schwichtenberg_2000 | not_yet_converted | — | — | — |
| van_doorn_2015 | not_yet_converted | — | — | — |
| fine_2012_counterfactuals-without-possible-worlds | unadjudicated | 0.1209 | 1457 | 12056 |
| fine_2012_guide-to-ground | unadjudicated | 0.0161 | 333 | 20701 |
| venema_1991 | unadjudicated | 0.3737 | 22623 | 60541 |
| burgess_1984 | unverified_no_baseline | — | 17526 | 0 |
| gabbay_1994 | unverified_no_baseline | — | 27421 | 0 |
| thomason_1984 | unverified_no_baseline | — | 12906 | 0 |
| vardi_wolper_1986 | unverified_no_baseline | — | 151 | 0 |
| rabinovich_2014 | unverified_summary | 0.2381 | 2093 | 8789 |

(Note: these live ratios for the two Fine papers, 0.0161/0.1209, are lower than the stale description's 0.0327/0.2455 — because #839's chunk-glob fix further reduced counted `md_words` by excluding `chunk_*.md` re-splits that were previously double-counted. This is expected and correctly reflects the fix, not a regression.)

At index-entry granularity (153 stamped entries, confirmed via `jq` against the live index): `verified_conversion`=80, `no_source_pdf`=45, `unverified_no_baseline`=15, `unadjudicated`=11 (the 2 Fine papers + 9 `venema_1991` per-chapter/appendix child rows, phantom-parent-fallback-stamped), `unverified_summary`=1, `not_yet_converted`=1 (only `gabbay_2000` has an existing index row; the other 4 not-yet-converted dirs have no index.json presence at all yet — they will need entries created, most naturally via `literature-ingest.sh` rather than manual `jq` editing).

### Cohort A — `not_yet_converted` (5 dirs claimed and confirmed, but only 3 are clean)

Verified via `pdfinfo` (page count) and `pdftotext -layout | wc -w` on the actual source PDFs (not assumed):

| dir | PDF | pages | pdftotext words | Assessment |
|---|---|---|---|---|
| gabbay_2000 | Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf | 614 | **0** (also 0 via PyMuPDF `fitz`) | **BLOCKED** — scanned, no text layer at all. Same class of problem as cohort C, not a greenfield conversion. |
| girard_1989 | Proofs_and_Types.pdf | 183 | 60,321 | Clean — real embedded text, straightforward conversion. |
| negri_von_plato_2001 | Structural_Proof_Theory_TOC_only.pdf | **4** | 511 | **BLOCKED/WRONG ASSET** — `pdftotext` output confirms this PDF is literally the book's table of contents (title page + contents list), not the book body. The filename is accurate, not a false alarm. Converting it "successfully" would only produce a ~500-word TOC stub, not the book. |
| troelstra_schwichtenberg_2000 | Proof_Theory_Lectures.pdf | 139 | 54,191 | Clean — real embedded text, straightforward conversion. |
| van_doorn_2015 | van_Doorn_2015_Propositional_Calculus_Coq.pdf | 11 | 5,065 | Clean — real embedded text, straightforward conversion. |

This is the single most important correction this research makes to the task's own framing: **only 3 of the 5 are actually "run the fixed converter" work.** `gabbay_2000` needs the same OCR remediation as cohort C (see below — and is equally blocked by the same absent tooling). `negri_von_plato_2001` needs a different, real full-text source PDF; that is an acquisition problem structurally similar to the out-of-scope `no_source_pdf` cohort, not a conversion problem, and is better handled as a `/spawn` candidate (source a real copy) or explicitly deferred, rather than silently "converted" into a useless TOC-only markdown file that would then get stamped with a nonsense low ratio.

**Converter entry point and exit-code contract** (`.claude/scripts/literature-convert.sh`, read in full):
- `LITERATURE_CONVERTER` env var selects engine mode: `auto` (default: primary pymupdf4llm tier, falls back to the *mandatory* PyMuPDF column-clustering tier only if primary is **unavailable or raises/returns empty** — NOT if primary succeeds but fails the quality gate), `pymupdf4llm` (primary tier only, exit 2 if unavailable — no silent substitution), `pymupdf`/`fallback` (force the column-clustering fallback tier, skipping primary entirely), `pdftotext` (explicit manual escape hatch, no heading detection, never used by `auto`).
- **Exit codes, confirmed by reading the script's Main section (lines ~606-660) and the `run_unified_engine`/quality-gate flow**: `0` = success, quality gate passed. `1` = input file missing/unsupported type. `2` = all engine tiers produced empty output (hard failure). `3` = an engine produced non-empty content but the quality gate rejected it — output goes to a `.rejected` sibling file, the real `.md` is **never written**, and this must be treated as skip+log, never success. This confirms the task's framing exactly: **exit 3 is a loud quality-gate failure, not partial success.**
- Critically: **`auto` mode does NOT automatically retry the fallback tier when the primary tier's output fails the quality gate.** If `pymupdf4llm` produces non-empty text that then fails the gate, the script exits 3 immediately (`GATE_FAILED=1` branch in Main); it does not fall through to the column-clustering tier. To recover from such a quality-gate rejection, the correct action is an explicit **retry with `LITERATURE_CONVERTER=pymupdf`** (forced fallback tier), not treating exit 3 as final or re-running `auto` again.
- **Goldblatt/Hodkinson/Venema 2003** — located at `sources/goldblatt_2003/`. This document is **already `verified_conversion` (ratio 0.9528)** and is **not** one of the 13 actionable dirs; it is cited in the converter script's own comments (and in #831's plan/summary) purely as the real-corpus document that exposed a genuine `pymupdf4llm` defect (dropped inter-word spaces around `<sup>`/`<sub>` markdown spans, producing fused runs like "Thesecondlinefollowsby"). #831's summary explicitly flags this as "valuable, actionable information for task #832": *if* any of this task's conversions/reconversions hits a similar sentence-boundary-glue quality-gate failure (the `sentence_boundary_glue_count()` check, threshold ≥3), the fix is to re-run that specific document with `LITERATURE_CONVERTER=pymupdf` forced, not to treat the exit-3 rejection as unrecoverable. No action is needed on `goldblatt_2003` itself.

**Recommended entry point for genuinely greenfield conversions**: `.claude/scripts/literature-ingest.sh <path>` (read in full) is the higher-level pipeline wrapper — it runs `literature-convert.sh`, then `literature-chunk.sh`, then **updates `index.json`** (creating the entry — important, since 4 of these 5 dirs have no index.json row at all yet), then rebuilds the global `.literature.db` (`literature-build-index.sh --global`). It tracks quality-gate exit-3 rejections in a distinct counter from hard failures, matching the exit-code contract above. Using `literature-ingest.sh` rather than calling `literature-convert.sh` directly avoids having to hand-write new index.json entries for `girard_1989`, `troelstra_schwichtenberg_2000`, and `van_doorn_2015`.

### Cohort B — `unadjudicated` (3 dirs claimed and confirmed — but only 2 are genuine reconversion wins)

All three currently carry real PDFs (per task framing: "the two Fine papers thanks to #836"; `venema_1991` had its PDFs all along). Verified by reading actual `.md` content, not just ratios:

- **`fine_2012_guide-to-ground`** (ratio 0.0161, 333 md words vs 20,701 pdf words over 44 pages): the `.md` file is confirmed by direct read to be a genuine stub — it contains only the title, a short intro paragraph, and §1's opening examples, then simply **stops**, well short of a 44-page paper. This is unambiguously an incomplete conversion. Reconversion via the #831-fixed pipeline should recover the full paper and substantially raise the ratio.
- **`fine_2012_counterfactuals-without-possible-worlds`** (ratio 0.1209, 1457 vs 12,056 words over 26 pages): confirmed by reading the file tail — it cuts off mid-argument (mid-proof of a "Negative Effect"/"Counterfactual Possibility" argument), clearly truncated relative to a 26-page paper. Same conclusion: genuine reconversion candidate, expected to improve.
- **`venema_1991`** (ratio 0.3737, 22,623 vs 60,541 words): **this is likely a false-positive reconversion candidate**, not a genuine content gap. The directory holds three PDFs — the full book (184 pages) plus two already-selective extracts, `..._ch2.pdf` (41 pages) and `..._app_A_B.pdf` (18 pages) — and only chapter 2 + appendices A/B (59 of 184 pages) were ever converted (9 `.md` files matching exactly those sections, confirmed against `chunks.json`'s `source_path` entries). The audit's `pdf_words` denominator sums **all three PDFs**, so it is comparing 59 converted pages against a 184-page total — an apples-to-the-whole-orchard denominator-inflation artifact structurally identical to the `thomas_2003_reactive` case #839 just resolved via a truthful disclosure banner (Option A), **not** a case where reconversion of the same 59 pages could ever raise the ratio. Reconverting `ch2.pdf`/`app_A_B.pdf` again will reproduce essentially the same word count against the same inflated denominator and leave the ratio unchanged near 0.37.

  **Recommendation for `venema_1991`**: do NOT reconvert as the primary remedy. Instead mirror #839's `thomas_2003_reactive` fix — add a truthful disclosure banner to the converted `.md` files (or to the relevant index.json summary text) stating that only chapter 2 and appendices A/B were intentionally selected from the 184-page book, so the audit's `disclosure_check()` classifies it `verified_conversion` (disclosed partial) instead of `unadjudicated`. If the planner instead wants full-book coverage, that is a much larger scope expansion (converting all 184 pages) that should be called out explicitly as a separate, larger decision, not folded silently into "reconvert the existing 2 PDFs."

**Acceptance criterion for cohort B (as researched)**: for the two genuine Fine-paper candidates, compare post-reconversion `word_ratio` against the current baseline (0.0161 / 0.1209) — a substantial rise (ideally toward or above the 0.75 threshold used by the audit script, `RATIO_THRESHOLD`) is the expected, falsifiable signal of success; re-run `literature-fidelity-audit.sh --dry-run` afterward to confirm the reclassification away from `unadjudicated`. For `venema_1991`, the acceptance criterion is different: confirm the disclosure banner causes `disclosure_check()` to return `True` on the next `--dry-run`, converting it to `verified_conversion` (disclosed) — not a ratio change.

### Cohort C — `unverified_no_baseline` (4 dirs claimed and confirmed — OCR-blocked, tooling absent)

Confirmed independently, not assumed: all four PDFs (`Burgess_1984_Basic_Tense_Logic.pdf`, the full `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1.pdf` plus its ch9/ch10/ch12 splits, `Thomason_1984_Combinations_of_Tense_and_Modality.pdf`, `Vardi_Wolper_1986_Automata_Theoretic_Verification.pdf`) extract **0 words** under both `pdftotext -layout` and PyMuPDF's own `page.get_text()` — genuinely scanned image PDFs with no embedded text layer at all, not a `pdftotext`-specific encoding quirk (both extraction backends agree on zero, ruling out a "PyMuPDF can read it but pdftotext can't" hypothesis I checked and rejected).

Two distinct sub-cases within this cohort, found by reading the existing `.md` content directly:
- **`burgess_1984`, `thomason_1984`, `gabbay_1994`** already have substantial, well-formed existing markdown (17,526 / 12,906 / 27,421 words respectively, with real prose, section numbering, and — for `gabbay_1994` — LaTeX math). These are **not stubs**; they read as genuine, previously-completed conversions (most plausibly produced from different, non-scanned source copies, or transcribed independently of this pipeline's converters). For these three, the OCR work is needed **only to establish a computable `pdf_words` baseline** for the ratio check — not to redo the `.md` itself.
- **`vardi_wolper_1986`** is a genuine stub: its `.md` is an explicit placeholder that reads *"Text extraction via pdftotext produced no output. OCR conversion requires tesseract (not currently installed)... [Abstract from context]... Key Topics... Citation"* — i.e., someone already hit this exact blocker and left a self-disclosing note rather than silently faking a conversion. This independently corroborates the tooling-absence finding below (this is not solely this research's own probe). For this one document, OCR must produce both the baseline **and** the actual first-time real conversion.

**OCR tooling availability (checked directly, not assumed)**:
```
which ocrmypdf     -> not found
which tesseract    -> not found
which pytesseract  -> not found (also: python3 -c "import pytesseract" -> ModuleNotFoundError)
pip show ocrmypdf  -> not found
nix-env -q          -> no tesseract/ocr packages installed
dpkg -l              -> n/a (NixOS, no dpkg)
```
This is a NixOS machine (`/run/current-system/sw/bin/nix` present; no system `flake.nix`/`configuration.nix` inside this repo, but a separate `~/.dotfiles/flake.nix` + `configuration.nix` exists for actual system config). None of `ocrmypdf`, `tesseract`, or `pytesseract` are installed or importable anywhere on `PATH`/site-packages right now.

**This is a genuine, currently-unresolved blocker, not something to plan around silently.** Feasible remediation paths for the planner to choose between (none attempted or verified further here, per "research only, do not convert anything"):
1. **Ephemeral, no-system-change invocation**: `nix run nixpkgs#tesseract -- --version` or `nix-shell -p tesseract ocrmypdf --run '...'` — nixpkgs is known to package both `tesseract` and `ocrmypdf`; this path does not require editing `~/.dotfiles/configuration.nix` or a system rebuild, but its viability depends on network egress to a Nix binary cache being available in the execution environment at implementation time — **unverified here** (not run, to avoid installing anything during research). The plan should treat "does `nix run nixpkgs#tesseract -- --version` succeed" as its first, cheap, reversible verification step before committing to this cohort.
2. **Persistent system install** via the separate `~/.dotfiles` NixOS/home-manager config — out of scope for an agent to perform (system rebuild, human-owned repo), and not this task's `file_scope` (`~/Projects/Literature/sources/`, `.claude/scripts/literature-build-index.sh`) in any case.
3. **Gate/defer the cohort**: if neither path is viable at implementation time, the honest outcome is to leave these 4 dirs (plus `gabbay_2000`, per Cohort A's finding) at their current classification and record the OCR blocker explicitly, rather than fabricating a baseline.

Do not assume availability; the plan must pick one of these paths explicitly and verify tooling before committing to conversion work in this cohort.

### Cohort D — `unverified_summary` (1 dir claimed and confirmed)

`rabinovich_2014`: ratio 0.2381 (2,093 md words vs 8,789 pdf words), `proof_fraction` = 0.545 (below the 0.6 adequacy threshold) — the only directory that hits the audit's genuine "undisclosed paraphrase" signal (numbered Definition/Lemma/Theorem statements exist, but fewer than 60% carry adequate defining/proof content). A sibling PDF is present (`Rabinovich_2014_Proof_of_Kamps_Theorem.pdf`). This is a straightforward reconversion: replace the `.md` with a real conversion from the PDF via the standard pipeline, then re-run the fidelity audit to reclassify. No OCR or acquisition blocker applies here — `pdftotext`/PyMuPDF both see real text (this document was never in the 0-word set).

### `no_source_pdf` (45 entries) — confirmed out of scope

Per the delegation and #836's own findings, these 45 are confirmed absent from the Zotero library entirely (not merely unmatched or gated). No acquisition planning was performed here, matching the "OUT OF SCOPE" instruction.

### Revalidation half — `literature-build-index.sh` and the correct order of operations

Read `.claude/scripts/literature-build-index.sh` in full (323 lines). Key finding, which the task's framing slightly conflates: **this script builds the ephemeral SQLite FTS5 search database (`~/Projects/Literature/.literature.db` and/or `specs/literature/.literature.db`) from chunk manifests on disk — it is entirely distinct from `index.json` and from `literature-fidelity-audit.sh`.** It does not compute or touch `provenance_fidelity`/`word_ratio` at all; it only rebuilds the text-search index that `literature-search.sh`/`literature-briefing.sh` query. Usage: `literature-build-index.sh --global` (rebuild the global DB), `--local` (rebuild `specs/literature/`'s DB), or both; exit codes are `0` success, `1` no chunk manifests found, `2` `sqlite3` unavailable (not checked here — `sqlite3` is presumed present since it's a hard dependency of the existing pipeline, but worth a cheap `command -v sqlite3` check at implementation time). It is atomic (build-to-`.tmp`, then rename).

Given this, and given how `literature-ingest.sh` already chains steps 1-5 (convert → chunk → update index.json → rebuild global db) for any single document, the correct end-to-end order of operations for 832 as a whole is:

1. **Convert/reconvert** each cohort's actionable document(s) per the cohort-specific approach above (respecting the exit-code contract; explicit `LITERATURE_CONVERTER=pymupdf` retry on any quality-gate exit-3 rejection, per the Goldblatt precedent) — preferably via `literature-ingest.sh` for the 3 clean greenfield docs (since it also creates their missing index.json entries and chunks), and via direct `literature-convert.sh` + `literature-chunk.sh` re-runs for the reconversion targets (Fine papers, `rabinovich_2014`) that already have index rows.
2. **Rebuild the global search index**: `literature-build-index.sh --global` (and `--local` too if any of these documents are also mirrored into `specs/literature/`, which does not appear to be the case for this task's targets but is worth a quick existence check at implementation time).
3. **Re-run the fidelity audit**: `literature-fidelity-audit.sh --dry-run` first (safe, no writes) to preview the new classification for every touched directory, then `literature-fidelity-audit.sh --write` (which itself backs up `index.json` to a timestamped `.bak` file and writes atomically) to actually re-stamp `provenance_fidelity`/`word_ratio`.
4. **Confirm stamps**: diff the `--dry-run` output before/after, or `jq` the specific touched dirs' entries, to confirm the expected reclassification (e.g., Fine papers moving off `unadjudicated`, `rabinovich_2014` moving to `verified_conversion`, `venema_1991` moving to `verified_conversion` via disclosure rather than ratio).

### Risk / reversibility assessment (writes to `~/Projects/Literature/` — outside this repo, real user data)

| Operation | Destructive? | Reversibility |
|---|---|---|
| `literature-convert.sh`/`literature-ingest.sh` on the 3 clean not_yet_converted dirs | No | Creates new `.md`/chunk files; no existing file is overwritten (none exist yet). Quality-gate rejections write to `.rejected` siblings, never overwrite a real `.md`. |
| Reconverting the 2 genuine Fine-paper unadjudicated dirs | **Overwrites existing `.md`** | Existing `.md` content is already confirmed-truncated/low-value (per direct read above), so overwriting is a strict improvement if quality-gated — but the plan should still back up the current `.md` (e.g. `cp x.md x.md.bak`) before overwriting, consistent with the quarantine-never-delete posture, since this task's own constraints demand it even though the pipeline itself does not auto-backup `.md` files (only `index.json` gets an automatic `--write`-time backup). |
| Disclosure-banner edit to `venema_1991`'s `.md`/summary | No (additive) | Adding a truthful disclosure sentence is non-destructive and directly mirrors the just-completed #839 precedent for `thomas_2003_reactive`. |
| Reconverting `rabinovich_2014` | **Overwrites existing `.md`** | Same as Fine papers — back up first; existing content is a confirmed undisclosed paraphrase (proof_fraction 0.545 < 0.6), so overwriting is intended and net-positive. |
| OCR cohort (if attempted) | No direct overwrite of `.md` for burgess/thomason/gabbay_1994 (OCR only informs the baseline) | Low risk for those three. For `vardi_wolper_1986`, OCR + conversion would replace the placeholder stub — also intended and net-positive, back up first. |
| `negri_von_plato_2001` | **None recommended** — do not convert the TOC-only PDF into a fake "conversion"; treat as blocked/needs-real-source | N/A — recommend NOT touching `sources/negri_von_plato_2001/` until a real full-text PDF is sourced. |
| `gabbay_2000` | **None until OCR path is resolved** | Blocked identically to cohort C; do not attempt conversion against a 0-word source. |
| `literature-build-index.sh --global` | No | Atomic rebuild of an ephemeral derived artifact (rename-over-tmp); safe to re-run any number of times. |
| `literature-fidelity-audit.sh --write` | No (self-backing-up) | Backs up `index.json` to a UTC-timestamped `.bak` file, verified byte-identical, before any atomic write. Never deletes entries, PDFs, or markdown files. Safe and idempotent to re-run. |

Overall posture: every planned write either (a) creates net-new files, (b) is additive (disclosure banners), (c) overwrites `.md` files whose current content is independently confirmed defective/stub and hence a strict improvement, or (d) is a self-backing-up, atomic, idempotent script (`--write` mode of the audit). The two items this research recommends **not** touching (`negri_von_plato_2001`, `gabbay_2000`) are flagged precisely to avoid a destructive "convert anyway" action that would stamp a nonsense classification onto real PDFs. `doets_1987` and `libkin_2004_ch3_ch7` were not read or touched, consistent with the "do not touch" constraint.

## Decisions

- Trust the live `literature-fidelity-audit.sh --dry-run` output as ground truth over both the stale stored description and the delegation preamble's restated numbers; use only the freshly-run numbers in this report.
- Treat `venema_1991` as a disclosure-banner case (Option A, mirroring `thomas_2003_reactive`), not a reconversion case, pending planner confirmation — flagged as an open decision point since it revises the task's own framing of all 3 unadjudicated dirs as uniform "reconversion candidates."
- Treat `gabbay_2000` and `negri_von_plato_2001` as blocked/non-greenfield, splitting cohort A into "3 clean + 2 blocked" rather than executing all 5 uniformly.
- Do not attempt, simulate, or verify any actual OCR install/run — only tooling absence was probed (read-only `which`/`pip show`/`nix-env -q` checks); no packages were installed.

## Risks & Mitigations

- **Risk**: planner treats all 5 `not_yet_converted` dirs as uniformly ready and dispatches a blind batch conversion, silently producing a garbage 0-word or TOC-only "conversion" for `gabbay_2000`/`negri_von_plato_2001` that the audit would then (correctly, per its 0-pdf-word branch) still flag `unverified_no_baseline`/leave odd — wasted work, not data corruption, but still worth avoiding.
  **Mitigation**: this report's cohort-A table makes the 3-vs-2 split explicit with page/word-count evidence.
- **Risk**: planner reconverts `venema_1991`'s ch2/appAB PDFs expecting a ratio improvement that cannot materialize given the fixed 184-page denominator, then treats the unchanged ratio as a pipeline defect.
  **Mitigation**: this report documents the denominator-inflation mechanism and recommends the disclosure-banner route instead, with an explicit, different acceptance criterion.
- **Risk**: OCR cohort is planned without first confirming tooling is genuinely unavailable (rather than just "not on this probe's PATH").
  **Mitigation**: this report used three independent absence checks (`which`, `pip show`, `nix-env -q`) plus one independent corroborating artifact already in the corpus (`vardi_wolper_1986`'s self-disclosing stub) — the blocker is well-grounded, not assumed.
- **Risk**: destructive overwrite of `.md` files that turn out to hold hidden value.
  **Mitigation**: every `.md`-overwriting target in this report was read directly (not just ratio-inspected) before being recommended for reconversion, and a pre-overwrite backup (`cp x.md x.md.bak`) is recommended regardless, consistent with quarantine-never-delete.

## Context Extension Recommendations

- **Topic**: OCR tooling availability on this NixOS machine.
  **Gap**: no existing context file records that `ocrmypdf`/`tesseract`/`pytesseract` are absent, nor the ephemeral `nix run nixpkgs#<pkg>` workaround pattern for one-off tool use without a system rebuild.
  **Recommendation**: after 832 resolves (or explicitly defers) the OCR cohort, consider adding a short note to `.claude/extensions/literature/context/project/literature/` (or a new `.memory/` entry) recording the tooling-absence finding and whichever remediation path was actually chosen, so future literature tasks don't re-probe from scratch.
- **Topic**: the `venema_1991`-style "selective extract PDF alongside the full book PDF" denominator-inflation pattern.
  **Gap**: `.claude/context/project/literature/patterns/chunk-file-conventions.md` (written by #839) documents the chunk-double-counting pattern, but not this sibling pattern (multiple PDFs of differing scope in one `sources/<dir>/`).
  **Recommendation**: once 832 resolves `venema_1991` (whichever route is chosen), extend that pattern doc or add a sibling one documenting "multi-PDF directories where only a subset PDF was ever intended for conversion" as a known, non-bug ratio-suppression source, parallel to the chunk-glob fix.

## Appendix

### Commands run (all read-only; no writes to `~/Projects/Literature/` or `index.json`)

```
jq queries against ~/Projects/Literature/index.json (counts, cohort membership, per-dir provenance_fidelity/word_ratio)
ls -la on each cohort's sources/<dir>/
pdfinfo <pdf> (page counts) for all 13 actionable dirs' PDFs plus goldblatt_2003
pdftotext -layout <pdf> - | wc -w for all 13 actionable dirs' PDFs
python3 -c "import fitz; ..." word-count cross-check for the 4 unverified_no_baseline PDFs + gabbay_2000
which/pip show/nix-env -q probes for ocrmypdf, tesseract, pytesseract
bash .claude/scripts/literature-fidelity-audit.sh --dry-run  (fresh, authoritative population summary + per-dir table)
Read .claude/scripts/literature-convert.sh (full, 765 lines), literature-ingest.sh (header+body), literature-build-index.sh (full, 323 lines), literature-fidelity-audit.sh (full, 480 lines)
Read existing .md content for fine_2012_guide-to-ground, fine_2012_counterfactuals-without-possible-worlds, vardi_wolper_1986, burgess_1984, thomason_1984, gabbay_1994 (heads/tails)
```

### References

- `specs/831_fix_literature_conversion_pipeline_correctness/plans/01_conversion-pipeline-fix.md` and its summary — converter fix detail, Goldblatt/HV 2003 defect origin story, exit-code contract rationale.
- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md` — original classification methodology (whole-document ratio, disclosure check, proof-completeness check).
- `specs/839_fix_fidelity_audit_fail_open/` (task just completed) — fail-open fix, `thomas_2003_reactive` disclosure-banner precedent, `chunk-file-conventions.md` pattern doc.
- `.claude/context/project/literature/patterns/chunk-file-conventions.md` — chunk-double-counting fix background.
- `specs/834_retire_stale_per_repo_literature_copies/reports/01_retire-stale-literature-copies.md` — prior confirmation `goldblatt_2003` conversions are equivalent/deduplicated.
