# Research Report: Task #835

**Task**: 835 - Literature corpus provenance and fidelity audit
**Started**: 2026-07-09T00:00:00Z
**Completed**: 2026-07-09T00:00:00Z
**Effort**: research only (read-only)
**Dependencies**: Orthogonal to #831 (extraction correctness); premise-interlocked with #832 (dep on 835, 836)
**Sources/Inputs**:
- `~/Projects/Literature/index.json` (280 entries across 97 source dirs)
- `~/Projects/Literature/sources/*/` (direct file inspection, `pdftotext -layout` word counts)
- `.claude/scripts/literature-briefing.sh`, `.claude/scripts/literature-search.sh`, `.claude/scripts/literature-audit.sh`, `.claude/scripts/literature-build-index.sh` (read)
- Task #831 description (for the orthogonality claim and BUG3/BUG4 naming-convention context)

**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task's core insight is correct and the `rabinovich_2014` exemplar is fully verified**: it is a genuine hand-authored, editorial-prose paraphrase (headed `## Overview`, closes with a `## Key Insights for Formalization` section written *for the citing project*, not part of the original paper) whose `Lemma 3.2` is three bare unproved clauses and whose `Definition 7.13` is a one-line gloss. Its `index.json` `summary` field does **not** disclose this — an agent has no structural signal that this entry lacks proofs.
- **The task's pre-verified population counts and word-ratio numbers are, however, largely artifacts of a single-file sampling bug and do not hold up under directory-level (whole-document) aggregation.** Recomputing word-ratio by summing *all* `.md` files against *all* `.pdf` text per document (rather than picking one arbitrary `.md` file) flips the classification for most of the cited examples — see Findings, "Correction to Pre-Verified Evidence." This is itself a load-bearing finding for detector design: **the aggregation unit matters more than the threshold value.**
- Corrected population count (97 dirs): **52 chunks-only/no-PDF**, **5 PDF-present-zero-markdown** (already self-disclosed as `"PDF only, not yet converted to markdown"` in their own `index.json` summaries, `token_count: 0`), **40 PDF+markdown-present**, of which **30 are healthy conversions** (ratio 0.85–1.20), **4 have undeterminable ratio** (pdftotext yields 0 words — scanned/image PDFs), and **6 have low ratio** (<0.6).
- Of the 6 low-ratio candidates, only **`rabinovich_2014` is a confirmed undisclosed paraphrase**. The other five (`doets_1987`, `libkin_2004_ch3_ch7`, `venema_1991`, `thomas_2003_reactive`, `hodkinson_2006`) are *disclosed* partial/selective extractions — either the `.md` itself carries a "Selective conversion" / "Extracted: Chapters X, Y" banner, or the `index.json` `summary` already says so (e.g. `hodkinson_2006`: `"...table of contents and introduction only; full chapter truncated"`) — and, on inspection, contain real numbered Lemmas/Theorems **with proofs attached**, not paraphrase.
- Recommended fix is a structural field (Decisions section) plus loud flagging in both scripts, exactly as scoped — but the detector must (a) aggregate at the whole-document level, never a single file, (b) never use `chunk_*.md` filename presence as a signal (it is a false discriminator — see below), and (c) treat low-ratio as a **trigger for manual/structural review**, not an automatic "paraphrase" verdict, because disclosed partial extracts are legitimate and should not be quarantined identically to `rabinovich_2014`.

## Context & Scope

Read-only research per delegation. No files were modified: `literature-briefing.sh`, `literature-search.sh`, and `~/Projects/Literature/index.json` were read/queried but not written. No corpus content was touched or deleted.

Scope executed: (1) classify all 97 `sources/` dirs; (2) design a detector for "hand-authored summary masquerading as conversion"; (3) design an `index.json` provenance/fidelity field; (4) design loud-flagging behavior for the two retrieval scripts; (5) confirm quarantine-not-delete as the remediation posture.

## Findings

### Correction to Pre-Verified Evidence (read this before using the task's cited numbers)

The task description states the word-ratio evidence was pre-verified and asks to spot-check rather than re-derive. Spot-checking revealed the **verification methodology itself is broken** for any directory containing more than one `.md` file, which is most of the corpus. Concretely:

- `blackburn_2002`: task claims ratio **0.03**. Directory has 35 `.md` files (`ch01_general-frames.md`, `app_algebraic-computational.md`, ...) totaling **281,437 words** against a PDF of **269,554 words** — actual ratio **1.044** (fully converted, garbled in places per #831's BUG1/BUG3 but not fabricated). The cited 0.03 is exactly `wc -w app_algebraic-computational.md` (8,457 words, the alphabetically-first file) divided by the full PDF word count — i.e., the verification script picked one arbitrary file out of 35 and compared it to the whole book.
- `baier_katoen_2008`: task claims **0.10**; actual (12 files summed) = **1.0**.
- `caleiro_2013`: task claims **0.09**; actual (7 files summed) = **0.923**.
- `gabbay_1993`: not cited as low by the task but included among the "PDF+zero-chunks" population despite 5 real `.md` files summing to ratio **1.002**.
- `goldblatt_2003`: task claims **0.25**; actual (5 files) = **0.953**.
- `doets_1989`: task claims **0.36**; actual (3 files) = **0.985**.
- `derijke_1995`: task claims **0.44**; actual (3 files) = **0.925**.
- `hodkinson_2006` (task: 0.57) and `rabinovich_2014` (task: 0.29 vs. recomputed 0.238) are in the same ballpark either way — these two are single-`.md`-file directories, so single-file sampling happens to equal whole-document aggregation for them. This is *why* the pre-verified numbers looked plausible: the two directories used to anchor the claim are exactly the two where the sampling bug is invisible.

Likewise, the "0 healthy (PDF and chunks)" population count is an artifact of defining "chunks" as files matching the literal glob `chunk_*.md`. That glob only matches one of *three* legitimate output conventions used by the conversion pipeline:
1. `chunk_NNNN.md` (used for documents without an embedded TOC — the arxiv_* corpus, `kamp_1968`, `lamport_2002`, `solar-lezama_2008`, etc.)
2. `secNN_<slug>.md` / `chNN_<slug>.md` / `appabNN_<slug>.md` (TOC-derived section names — `blackburn_2002`, `gabbay_1994`, `doets_1987`, `venema_1991`, `reynolds_2001`)
3. A single `<Author>_<Year>_<Title>.md` file matching the PDF 1:1 (`gerth_1995`, `tarjan_1972`, `vardi_1996`, `kupferman_vardi_2001`, `schewe_2009`, `yan_2008`, `zielonka_1998`, `courcoubetis_1992`, `schwoon_esparza_2005`, `thomas_1997_languages`, and — the exception that proves the rule — `rabinovich_2014` itself, which is a single-file dir with a bad ratio)

All 30 directories that pass the corrected word-ratio check (0.85–1.20) use conventions 2 or 3 — **zero of them use `chunk_*.md` naming.** `chunk_*.md`-file-presence and genuine conversion are essentially uncorrelated in this corpus; using it as (or as part of) the detector would misclassify the entire well-converted TOC-chunked and single-file population as "never converted." **This item from the task's proposed detector design must be dropped, not weighted down.**

### Corrected Population Classification (97 dirs, directory-level aggregation)

| Population | Count | Definition | Fidelity value |
|---|---|---|---|
| Chunks-only, no source PDF | 52 | `.md` file(s) present, zero `*.pdf`/`*.djvu` in dir; not reconvertible | `no_source_pdf` |
| PDF present, zero `.md` at all | 5 | `gabbay_2000`, `girard_1989`, `negri_von_plato_2001`, `troelstra_schwichtenberg_2000`, `van_doorn_2015`. All 5 already carry an honest `index.json` summary (`"PDF only, not yet converted to markdown."`) and `token_count: 0`. | `not_yet_converted` (new value — see Decisions) |
| PDF + `.md` both present, ratio undeterminable | 4 | `burgess_1984`, `gabbay_1994`, `thomason_1984`, `vardi_wolper_1986` — `pdftotext -layout` returns 0 words (scanned/image-only PDF, or a PDF set where naive extraction fails); `.md` word counts are nonzero and plausible (7–27k words), so these are likely real conversions the ratio check simply cannot verify by this method | `unverified_no_baseline` (needs OCR page-count or manual spot-check, not silently `verified_conversion`) |
| PDF + `.md`, ratio 0.85–1.20 | 30 | Genuine full-text conversions (may still have #831-class readability defects — orthogonal axis) | `verified_conversion` |
| PDF + `.md`, ratio <0.6 | 6 | See sub-classification below | mixed — see below |

Sub-classification of the 6 low-ratio dirs (this is where structural signals, not ratio alone, must decide the verdict):

| Dir | Ratio | Self-disclosed? | Has real Lemma/Def + Proof bodies? | Verdict |
|---|---|---|---|---|
| `rabinovich_2014` | 0.238 | **No** — summary reads as if authoritative ("Clean proof of Kamp's theorem...") | **No** — Lemma 3.2 is 3 unproved one-line clauses; Definition 7.13 is a one-line gloss | `unverified_summary` (confirmed) |
| `doets_1987` | 0.238 | Yes — file opens `> **Selective conversion**... Chapters included: 7, 6, 3, 1` | Yes — e.g. `### 6.9 Lemma` followed by a full `*Proof.* Induction on ρa...` | `verified_conversion` (partial, disclosed) |
| `libkin_2004_ch3_ch7` | 0.019 | Yes — filename and file header both say "Chapters 3 and 7" | Yes, per `index.json` summary detail (Lemma 3.7, Lemma 7.11 named specifically) | `verified_conversion` (partial, disclosed) |
| `venema_1991` | 0.374 | Yes — each chunk file has `**Source:** Yde Venema, ... Chapter 2` header; `index.json` chunk summaries say "§2.1-2.2", "§2.3", etc. | Yes — real Definitions/Theorems inline (`Definition A17`, `Theorem 2.5.1 SD-THEOREM`) | `verified_conversion` (partial, disclosed) |
| `thomas_2003_reactive` | 0.504 | Partially — filenames (`Thomas_2003_ch01_omega_automata.md`, `ch03_deterministic_omega.md`) indicate chapter scope but no explicit disclosure banner | Yes — real theorem content, garbled ligatures (#831-class defect, not fabrication) | `verified_conversion` (partial; recommend adding an explicit scope banner) |
| `hodkinson_2006` | 0.569 | Yes — `index.json` summary literally says `"table of contents and introduction only; full chapter truncated"` | N/A (explicitly a TOC/intro stub) | `verified_conversion` (partial, disclosed) but **should also carry a `page_range` / completeness flag** since it is the thinnest of the disclosed cases |

**Net effect**: of 97 directories, exactly **one** (`rabinovich_2014`) is a confirmed case of the failure mode the task describes — a hand-authored paraphrase serving as an authoritative stand-in with no disclosure, sitting behind an `index.json` entry with a normal-looking `token_count`. This does not weaken the task's motivating concern; if anything it sharpens it: **the corpus is not systemically corrupted, but the one occurrence that exists is exactly as dangerous as described, and nothing in the current pipeline would catch a second one.** A detector is still the right investment — it just needs to be precise enough not to also flag the 5 disclosed-partial entries as equivalently dangerous, or it will train users to ignore the flag.

### Detector Design

Reject as a primary signal:
- `chunk_*.md` filename presence/absence (see above — false discriminator, would misclassify ~30 genuinely converted docs).
- Leading `## Overview` heading alone — only 1 of 6 low-ratio files uses this exact heading; it is not a generalizable marker on its own, though it is a legitimate corroborating signal when *combined* with the absence-of-disclosure and absence-of-proof signals below.

Use as primary signal:
1. **Whole-document word-ratio**, `md_words / pdf_words`, computed by:
   - Grouping all `.md` files under a `sources/<dir>/` by their shared `doc_id`/`parent_doc` relationship in `index.json` (or, absent that, all `.md` files in the same directory minus any `chunks.json`), summing word counts across the group.
   - Grouping all `*.pdf` files in the same directory (some dirs, e.g. `gabbay_1994`, have multiple split PDFs — sum across them) and summing `pdftotext -layout` word counts.
   - Dividing. If PDF-side word count is 0 (scanned/image PDF, 4 dirs found), do **not** silently default to a ratio — emit `unverified_no_baseline`, not `unverified_summary` and not `verified_conversion`.
   - Threshold: ratio ≥ 0.75 -> presumptively healthy; ratio < 0.75 -> route to structural sub-checks (below) rather than an immediate verdict. (The corpus shows a clean empirical gap: 30 docs cluster at 0.85–1.20, the next-highest "unhealthy" case is 0.569, so 0.75 is a safe, generous cut line with margin on both sides — no directory in this corpus falls in [0.6, 0.85].)
2. **Disclosure check** (only for ratio < 0.75 candidates): does the `.md` content or the `index.json` `summary` field contain an explicit partial/selective-conversion admission? Pattern-match on phrases like `Selective conversion`, `Extracted: Chapter`, `truncated`, `excerpt`, `chapters? \d+ and \d+`, or a `page_range` in `index.json` that is visibly narrower than the PDF's total page count. Presence -> `verified_conversion` (partial, disclosed). Absence -> proceed to signal 3.
3. **Proof/body-completeness check** (the decisive signal for the undisclosed case): for headings matching `^#+\s*(Definition|Lemma|Theorem|Proposition|Corollary)\s+[\d.]+`, check whether a `Proof` (or, for Definitions, more than ~2 lines of actual defining content) follows before the next heading of equal-or-higher level. Compute the fraction of numbered statements with a following proof/body. A ratio near 0 (as with `rabinovich_2014`: 0/1 observed Lemmas proved, Definition given as a one-liner) combined with ratio<0.75 and no disclosure is the `unverified_summary` verdict.
4. **Heading-overlap-with-PDF-TOC** (secondary corroborator, not required for MVP): extract the PDF's embedded TOC via PyMuPDF (already used by `literature-convert.sh`/`literature-audit.sh`'s `convert_with_pymupdf`) and check what fraction of TOC section titles appear as `.md` headings. Low overlap alongside low ratio adds confidence but is not necessary given the proof/disclosure checks already separate the corpus cleanly.

This detector is deliberately **conservative**: it only escalates to `unverified_summary` when ratio is low **and** there is no disclosure **and** numbered claims lack bodies. Any one of the three failing to trigger routes to `verified_conversion` (possibly partial) rather than a false quarantine.

## Decisions

- **`provenance_fidelity` field values**: the task specifies a 3-value enum (`verified_conversion` / `unverified_summary` / `no_source_pdf`). Empirical classification above needs **two additional values** to avoid misclassifying legitimate states:
  - `not_yet_converted` — PDF present, zero `.md` at all (5 dirs). Distinct from `no_source_pdf` (which means the reverse: `.md` exists, PDF absent, not reconvertible) and from `unverified_summary` (which implies a *misleading* `.md` exists). Recommend implementers either add this 4th/5th value or, if the schema must stay strictly 3-valued per the task's explicit ask, fold `not_yet_converted` into `no_source_pdf`'s sibling case with a boolean `has_pdf` companion field rather than conflating two structurally different situations under one string.
  - `unverified_no_baseline` — PDF+`.md` present but the PDF extracted to 0 words (4 dirs), so ratio cannot be computed. This must not silently become `verified_conversion` by default (that would hide a real gap) nor `unverified_summary` (that would falsely quarantine likely-legitimate content). Recommend a distinct value or a `ratio: null` sentinel alongside `provenance_fidelity: "unverified_no_baseline"`.
  - If the implementer wants to honor the strict 3-value ask, the safe collapse is: `not_yet_converted` -> `no_source_pdf`-adjacent (document clearly in the field's description, e.g. `"no_source_pdf (converted=false)"` is wrong — prefer adding the two values; a 3-to-5 value expansion is cheap and the two extra states are semantically load-bearing, not decorative).
- **Storage location**: mirror the existing `project_tags` pattern — the field belongs on the parent (`parent_doc == null`) entry in `~/Projects/Literature/index.json` only, not duplicated into the `.literature.db` SQLite `chunks_data` table that `literature-build-index.sh`/`literature-search.sh` operate on. `literature-search.sh` already does a live per-query jq lookup against `index.json` for `project_tags` (`get_project_doc_ids()`); the same lookup-by-`doc_id` pattern should be extended to fetch `provenance_fidelity` when formatting `--read`/search results, rather than migrating the SQLite schema.
- **Ratio computation must be directory/document-level**, never single-file. This is the single most important implementation constraint from this research — see "Correction to Pre-Verified Evidence."
- **Quarantine, never delete**: confirmed as the correct posture for both scripts (below) and any future batch remediation — no file deletion is recommended by this research for any of the 97 dirs, including `rabinovich_2014`.

## Flagging Behavior for `literature-briefing.sh` and `literature-search.sh`

Both scripts currently treat every entry uniformly — there is no code path today that reads or could read a fidelity signal (confirmed by reading both scripts in full; `index.json` currently has no such field, and neither script filters or annotates by any quality/fidelity axis; `project_tags` is the only per-doc-id filter that exists, in `literature-search.sh`'s `get_project_doc_ids()`).

Recommended changes (design only — not implemented per read-only scope):

- **`literature-briefing.sh`** (per-repo mode, lines ~119–223, and global mode, lines ~252–275): when building each `entry=` string, look up `provenance_fidelity` for the `doc_id` via a jq query against `$GLOBAL_INDEX`, mirroring the existing `relevance` lookup pattern (line 197). If the value is `unverified_summary` or `unverified_no_baseline`, prepend a visible marker to the entry line, e.g. `⚠ UNVERIFIED SUMMARY — do not cite as a faithful source without checking the PDF:` (or an ASCII-safe equivalent, matching this repo's emoji policy — see `.claude/extensions/nvim/context/project/neovim/standards/emoji-policy.md`) directly in the briefing text the agent reads, not just in a footnote. The existing "How to Use" footer should also gain a line: `- Entries marked UNVERIFIED are not confirmed faithful to their source PDF; treat claims as provisional and verify against primary literature before citing in formal work.`
- **`literature-search.sh`** (`do_search`, `do_read`, `do_toc`): the JSON result objects returned to agents (`chunk_id`, `doc_id`, `title`, `summary`, ...) should gain a `provenance_fidelity` key, populated via the same `doc_id -> index.json` lookup used for `project_tags`. Since agents consume this as structured JSON (not prose), this is the more load-bearing fix of the two — an agent scanning `snippet`/`summary` fields for relevance will not notice a caveat sentence buried in `summary` (exactly `rabinovich_2014`'s current failure mode: its `summary` field reads as fully authoritative). A structured field an agent can (and per updated SKILL.md instructions, should be told to) check programmatically closes that gap. `do_read` in particular should prefix `content` with a warning banner when `provenance_fidelity != "verified_conversion"`, since that is the path that hands an agent the full chunk text to reason from directly.
- Both scripts should **fail open, not closed**: if `provenance_fidelity` is absent from an entry (e.g., during a migration window before the batch-stamping script has run over the whole corpus), treat it as `unverified_summary` for display purposes (loud-by-default) rather than `verified_conversion` — this matches the "never silently authoritative" spirit of the task and of the `--lit` flag's existing "never a silent no-op" design principle documented in CLAUDE.md.
- New standalone script recommended (not in the stated file_scope but necessary to populate the field): `literature-fidelity-audit.sh`, run once over the full corpus and re-run whenever new documents are ingested (natural hook point: end of `literature-convert.sh` / `literature-ingest.sh`, or as a `/literature --validate` sub-check). This is distinct in purpose from the existing `literature-audit.sh` (a one-time, throwaway pipeline-tool-selection audit from the pre-implementation design phase, not a per-corpus per-entry auditor) and from `literature-build-index.sh` (builds the SQLite FTS index from `chunks.json`, does not touch `index.json`). It should implement the 3-signal detector above and write `provenance_fidelity` (and, for transparency, the raw computed `word_ratio` where determinable) back into each parent entry of `index.json`.

## Risks & Mitigations

- **Risk**: An overly literal 3-value `unverified_summary` label applied uniformly to all 6 low-ratio dirs would falsely stigmatize `doets_1987`, `libkin_2004_ch3_ch7`, `venema_1991`, `thomas_2003_reactive`, and `hodkinson_2006` — all of which are legitimate, disclosed, proof-bearing partial conversions. **Mitigation**: the disclosure + proof-completeness sub-checks in the detector design above are not optional refinements; without them, the fix produces five false positives for every one true positive it catches in this corpus, which will train users/agents to distrust or ignore the flag.
- **Risk**: A padded/verbose paraphrase (one that pads word count to approach the ratio threshold) would evade a ratio-only check. **Mitigation**: this is why the proof/body-completeness signal is required, not merely a corroborator, for any document that also has a numbered-statement density above a low floor (formal math/logic literature, which is most of this corpus). Purely narrative literature without numbered statements is not covered by signal 3 and remains a residual risk — acceptable for this corpus given its formal-math-heavy composition, but worth flagging as a known gap.
- **Risk**: The 4 `pdftotext`-zero-word directories (`burgess_1984`, `gabbay_1994`, `thomason_1984`, `vardi_wolper_1986`) cannot be ratio-checked at all; leaving them unclassified risks the exact silent-gap failure mode this task exists to close. **Mitigation**: `unverified_no_baseline` as a distinct, loud, non-`verified_conversion` value, with a recommended follow-up of OCR-based extraction (`pytesseract`/`ocrmypdf`, already touched on by #831's engine-evaluation work) or manual page-count spot-check before promoting to `verified_conversion`.
- **Risk**: Quarantine mechanics were scoped as "design, never delete" but not further specified. **Mitigation** (recommendation for the planning stage): quarantine should mean *retrievability degradation*, not removal — e.g., `literature-search.sh` excludes `unverified_summary`/`unverified_no_baseline` entries from default result ranking unless a `--include-unverified` flag is passed, while `literature-briefing.sh` always lists them but with the loud warning prefix. Files themselves are untouched on disk.

## Context Extension Recommendations

- **Topic**: literature corpus fidelity is currently undocumented as a *distinct* axis from conversion quality (#831's domain). Recommend a new context file, e.g. `.claude/context/project/literature/patterns/provenance-fidelity.md`, once implemented, documenting the `provenance_fidelity` enum, the detector's 3 signals, and the "aggregate at document level, never single-file" constraint discovered here — this constraint is non-obvious and will silently regress if a future contributor re-derives a word-ratio check without reading this report.

## Appendix

### Search / verification commands used

```bash
# Per-directory PDF/MD word counts, aggregated (not single-file)
for d in ~/Projects/Literature/sources/*/; do
  pdftotext -layout "$d"/*.pdf - 2>/dev/null | wc -w   # summed across all PDFs in dir
  cat "$d"/*.md 2>/dev/null | wc -w                     # summed across all .md in dir
done

# index.json field inventory
jq -r '.entries[] | keys[]' ~/Projects/Literature/index.json | sort -u

# parent_doc grouping (chunk-child counts per parent doc)
jq -r '.entries[] | .parent_doc // "NULL"' ~/Projects/Literature/index.json | sort | uniq -c
```

Full per-directory word-count table (97 rows) was generated to
`/tmp/claude-1000/.../scratchpad/835_wordcounts.tsv` during this session (scratchpad, not a
repo artifact).

### Files read

- `.claude/scripts/literature-briefing.sh` (full, 316 lines)
- `.claude/scripts/literature-search.sh` (full, 689 lines)
- `.claude/scripts/literature-audit.sh` (full, 418 lines)
- `.claude/scripts/literature-build-index.sh` (partial, schema/insert section)
- `~/Projects/Literature/index.json` (queried via jq; not fully read — 280 entries)
- `~/Projects/Literature/sources/{blackburn_2002,gabbay_1994,rabinovich_2014,doets_1987,venema_1991,thomas_2003_reactive,hodkinson_2006,libkin_2004_ch3_ch7,gabbay_2000,...}/*.md` (spot-read for structural verification)
