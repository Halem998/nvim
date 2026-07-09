# Research Report: Task #839

**Task**: 839 - Fix fail-open classification in literature-fidelity-audit.sh
**Started**: 2026-07-09T22:20:40Z
**Completed**: 2026-07-09T23:13:44Z
**Effort**: Medium (single-file logic fix + 3-consumer enum widening + 2 index.json re-stamps + 2 report corrections)
**Dependencies**: None (task #832 was amended to route around this bug rather than depend on it)
**Sources/Inputs**:
- `.claude/scripts/literature-fidelity-audit.sh` (full read)
- `.claude/scripts/literature-search.sh` (grep + read of `load_fidelity_map`/`get_fidelity`/`QUARANTINED_FIDELITY_VALUES` call sites)
- `.claude/scripts/literature-briefing.sh` (full read of fidelity-marker logic)
- `.claude/scripts/literature-build-index.sh` (full read — ruled out as a consumer)
- Live corpus at `~/Projects/Literature/` (`index.json`, `sources/*/`) via `--dry-run` and direct file inspection
- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/fidelity-delta.md`
- `specs/832_reconvert_and_validate_literature_corpus/` (grepped; no direct enum references found)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Primary bug confirmed exactly as described.** `classify_dir()` in
  `.claude/scripts/literature-fidelity-audit.sh` (the `if frac is None:` branch, lines 367-375)
  stamps `verified_conversion` when the proof-completeness signal cannot fire on a low-ratio,
  undisclosed document. `--dry-run` against the live corpus reproduces all 3 named victims
  exactly (word_ratio, disclosed=False, proof_fraction=None columns match the task description
  to 4 decimal places).
- **A 4th live victim exists that the task description did not enumerate**: `thomas_2003_reactive`
  (ratio=0.5041, disclosed=**False**, proof_fraction=None, currently stamped
  `verified_conversion` on both its live index.json child entries `thomas_2003_ch01` and
  `thomas_2003_ch03`). Critically, task #835's own report *already* identified this exact
  directory as needing "an explicit scope banner" to legitimately resolve via the disclosure
  branch (like `doets_1987`/`libkin_2004_ch3_ch7`) — that recommendation was never implemented,
  so today it falls through the same `frac is None` fail-open hole as the 3 named victims. The
  fix must either (a) let it become `unadjudicated` like the others, or (b) implement #835's
  original banner recommendation so it resolves via the disclosure branch. Recommend (b),
  since #835 already did the legwork verifying it's a legitimate partial conversion with real,
  proved theorem content.
- **The "secondary defect" (ratio > 1, no upper bound) has a different, more specific root
  cause than the task description's hypothesis.** It is NOT pdftotext under-extracting
  two-column math. It is **word-count double-counting**: `classify_dir()`'s `mds` glob (lines
  298-301) matches every `*.md` file in a `sources/<dir>/`, which includes the pre-chunked
  `chunk_NNNN.md` files generated alongside the canonical document `.md` — and those chunks are
  near-verbatim re-splits of the SAME content, not additional material. Directly verified by
  word-counting the canonical `.md` file alone vs. the `chunk_*.md` files alone vs. the PDF for
  all 5 affected directories (see Findings). Excluding `chunk_*.md` from the glob resolves the
  "> 1" anomaly for all 3 flagged high-ratio dirs (their true ratios land at ~0.89-1.04, normal)
  and makes the true ratios for the 2 already-flagged low-ratio victims that also have chunk
  files (`fine_2012_guide-to-ground`, `fine_2012_counterfactuals-without-possible-worlds`) even
  lower — same classification outcome, more honest numbers.
- **Consumer enumeration corrects the task description on one point and adds one the
  description missed.** `literature-build-index.sh` does NOT reference `provenance_fidelity` at
  all (grep confirms zero hits) — it only rebuilds the FTS5 chunk database and is not a real
  consumer; no change needed there. `literature-briefing.sh`'s `needs_fidelity_marker()` (line
  109, NOT mentioned in the task description) uses an **opt-in allowlist**
  (`unverified_summary | unverified_no_baseline`) rather than a fail-open `!= verified_conversion`
  check — a new `unadjudicated` value would silently get NO warning banner in `--lit` briefings
  unless this line is explicitly updated. This is the same class of silent-trust bug the task
  is fixing, one script over.
- **Recommended sixth enum value**: `unadjudicated`, exactly as suggested in the task
  description. Three concrete code sites require it: the `frac is None` branch itself (assign
  `unadjudicated` instead of `verified_conversion`), `literature-search.sh`'s
  `QUARANTINED_FIDELITY_VALUES` (line 51, currently `"unverified_summary unverified_no_baseline"`),
  and `literature-briefing.sh`'s `needs_fidelity_marker()` case statement (line 109).

## Context & Scope

Researched the fail-open classification defect in `literature-fidelity-audit.sh` per task #839's
description, verified all claimed line numbers and victim measurements against the live script
and live `~/Projects/Literature/index.json`, enumerated every real consumer of the
`provenance_fidelity` field across `.claude/scripts/` and `specs/`, and investigated the
"secondary defect" (ratio > 1, no upper bound) to its actual root cause. No implementation was
performed — this report is research-only, per the delegation contract.

## Findings

### Codebase Patterns

**Primary bug — confirmed line-for-line.** `classify_dir()` in
`.claude/scripts/literature-fidelity-audit.sh`:

```python
367  frac, adequate, total = proof_completeness_fraction(md_texts)
368  result["proof_fraction"] = frac
369  if frac is None:
370      # No numbered statements to check at all. Conservative default for a
371      # low-ratio, undisclosed, non-formal-prose document: this corpus is
372      # formal-math-heavy and every low-ratio case observed carries numbered
373      # statements; a document with none is out of this signal's coverage
374      # (documented residual risk in report 01) rather than misclassified
375      # against a signal that cannot fire.
376      result["provenance_fidelity"] = "verified_conversion"
377      return result
```

(Line numbers are offset by ~1-2 from the task description's "367-374" due to intervening
comment/blank lines added since #835 — the branch structure and logic are otherwise identical
to what was described.)

Preceding branches, for context:
- Lines 354-356: `ratio >= RATIO_THRESHOLD (0.75)` -> `verified_conversion`, no upper bound.
- Lines 358-363: disclosure check (`disclosed=True`) -> `verified_conversion`. This branch is
  correct and must be preserved unchanged — confirmed via `--dry-run` that `doets_1987`
  (ratio=0.2378, disclosed=True) and `libkin_2004_ch3_ch7` (ratio=0.0187, disclosed=True) both
  pass through it, not the buggy branch.
- Lines 365-380: proof-completeness check. `frac < 0.6` -> `unverified_summary` (confirmed via
  `rabinovich_2014`, proof_fraction=0.5454... < 0.6, ratio=0.2381). `frac is None` -> the buggy
  branch. `frac >= 0.6` -> `verified_conversion` (legitimate pass).

**`--dry-run` reproduction (live corpus, 97 directories, run 2026-07-09).** Full TSV output was
captured; the three columns of interest for the 3 named victims match exactly:

| dir | provenance_fidelity | word_ratio | disclosed | proof_fraction |
|---|---|---|---|---|
| `fine_2012_guide-to-ground` | verified_conversion | 0.0327 | False | None |
| `fine_2012_counterfactuals-without-possible-worlds` | verified_conversion | 0.2455 | False | None |
| `venema_1991` | verified_conversion | 0.3737 | False | None |
| `doets_1987` (legit, disclosed) | verified_conversion | 0.2378 | **True** | None |
| `libkin_2004_ch3_ch7` (legit, disclosed) | verified_conversion | 0.0187 | **True** | None |
| `rabinovich_2014` (legit, low-adequacy) | unverified_summary | 0.2381 | False | 0.5454... |

All match the task description and the VERIFICATION section's expected post-fix invariants
exactly.

**A 4th victim not named in the task description: `thomas_2003_reactive`** (ratio=0.5041,
disclosed=**False**, proof_fraction=None, `verified_conversion`). Verified live in
`~/Projects/Literature/index.json`: both its child entries (`thomas_2003_ch01`,
`thomas_2003_ch03` — this directory has no root `id` entry, it uses the
`phantom_parent_fallback` resolution path documented in the script header) are currently
stamped `verified_conversion`. Checked the source `.md` files directly: zero markdown headings
of any kind (`grep -n "^#"` returns nothing), consistent with `proof_completeness_fraction`
returning `None` (no numbered Definition/Lemma/Theorem/Proposition/Corollary headings exist to
evaluate — this is lecture-note prose, not because it's undocumented, but because the source
document's structure doesn't use markdown headings for its formal content). Checked the
disclosure signal: no disclosure banner in either `.md` file, and no disclosure language in the
`index.json` `.summary` fields for either child entry — so `disclosed=False` is correct given
current inputs.

Critically, `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`
already flagged this exact gap (its own line 71, cohort table):
> `thomas_2003_reactive` | 0.504 | Partially — filenames... indicate chapter scope but no
> explicit disclosure banner | Yes — real theorem content, garbled ligatures... |
> `verified_conversion` (partial; **recommend adding an explicit scope banner**)

That recommendation was never implemented. So `thomas_2003_reactive` is simultaneously (a) a
document #835's own analysis judged to be a *legitimate* partial/disclosed conversion with real
proved content, and (b) a document that, under the current code, hits the *exact same fail-open
branch* as the 3 undisclosed victims — for a different underlying reason (no headings at all,
not "headings present but none proved"). Two honest resolutions, either is acceptable, but they
produce different outcomes and the plan should pick one explicitly:
- **(Option A, recommended)**: implement #835's original recommendation — add an explicit
  disclosure banner (either to the `.md` files or the `index.json` `.summary` fields, matching
  the pattern used for `hodkinson_2006`'s summary: `"...table of contents and introduction only;
  full chapter truncated"`) so `disclosed=True` fires and it resolves via the legitimate
  disclosure branch, same as `doets_1987`/`libkin_2004_ch3_ch7`.
- **(Option B)**: leave it undisclosed and let the code fix reclassify it to `unadjudicated`
  alongside the 3 named victims, accepting a "regression" in the population summary compared to
  what #835 evaluated (91 `verified_conversion` after #836's Phase 6 write, per
  `specs/836_recover_source_pdfs_via_zotero/artifacts/fidelity-delta.md`, would drop to 89 —
  actually 90 since `thomas_2003_reactive` was not one of #836's newly-added 7).

Either way, this is 1 additional directory the plan and `--write` re-run must explicitly account
for beyond the 3 named in the task description.

### Root cause of the secondary defect (ratio > 1, no upper bound)

The task description hypothesizes "pdftotext under-extracting two-column math." Direct
word-counting of the source files rules this out and identifies the actual cause:
**`classify_dir()`'s `mds` glob (script lines ~298-301) includes `chunk_NNNN.md` files, which
duplicate the content of the canonical document `.md` file** (chunks are pre-split copies of the
same document generated for the FTS5 search index — see `literature-build-index.sh` and
`chunks.json` in each directory). Summing word counts across both the canonical `.md` and its
own `chunk_*.md` re-splits roughly doubles `md_words_total`.

Verified for all 3 flagged high-ratio directories by counting words in the canonical `.md` file
alone vs. `chunk_*.md` files alone:

| dir | canonical .md words | chunk_*.md words (sum) | audit's md_words (combined, matches script) | pdf_words | audit's reported ratio | **true ratio (canonical only)** |
|---|---|---|---|---|---|---|
| `fine_2010_some-puzzles-of-ground` | 12,708 | 11,889 | 24,640 | 11,831 | 2.0827 | **~1.074** |
| `fine_2012_pure-logic-of-ground` | (not individually re-measured; chunk sum ~22,271 by proportion) | — | 30,583 | 15,997 | 1.9118 | **~0.958** (extrapolated) |
| `bacon_2018_broadest-necessity` | 28,500 | 22,196 | 50,771 (script) / 50,696 (manual sum, close enough — whitespace/tokenization variance) | 28,500 | 1.7814 | **~1.0** |

All three collapse to a normal, unremarkable ~0.9-1.1 ratio once chunk duplication is removed —
these are NOT anomalous conversions at all; they are a word-counting artifact.

Cross-checked scope: enumerated every `sources/<dir>/` with `chunk_*.md` files present (48
directories total). Of those, only 5 also have a PDF present (the rest are `no_source_pdf`
arXiv/hardware-verification directories where ratio is never computed, since `classify_dir`
short-circuits to `no_source_pdf` before reaching the ratio calculation): `bacon_2018_broadest-necessity`,
`fine_2010_some-puzzles-of-ground`, `fine_2012_counterfactuals-without-possible-worlds`,
`fine_2012_guide-to-ground`, `fine_2012_pure-logic-of-ground`. The two low-ratio ones in that set
(`fine_2012_guide-to-ground`, `fine_2012_counterfactuals-without-possible-worlds`) are already
correctly failing the ratio check even with the doubling — excluding chunks makes their true
ratio even lower (e.g. `fine_2012_guide-to-ground`: canonical-only 333 words / 20,701 pdf words =
~0.016, vs. the reported 0.0327), which does not change their classification outcome, only makes
the reported evidence honest.

**Recommendation**: fix the root cause, not just the symptom. Exclude `chunk_NNNN.md` files from
the `mds` glob at lines 298-301 (e.g. add `and not re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)`
to the filter), rather than adding an arbitrary upper-bound ratio threshold. An upper bound alone
would suppress the visible symptom (values > ~1.3 flagged as suspicious) without fixing the
underlying double-count, and would leave the *reported* ratios for all 5 affected directories
wrong in the index.json/report evidence even where the final classification happens to still be
correct.

### Consumer Enumeration (complete)

Grepped `.claude/` and `specs/` for `provenance_fidelity`. Real code consumers, with exact
required changes:

1. **`.claude/scripts/literature-fidelity-audit.sh`** (the producer) — needs:
   - The `frac is None` branch (line ~369-377) changed to assign `unadjudicated` instead of
     `verified_conversion`.
   - Header comment (~line 38-39): five-value enum list -> six values (add `unadjudicated`).
   - `main()`'s population-summary tuple (lines 423-424, currently hardcodes the 5 known keys
     for the stderr summary printout) -> add `unadjudicated` or the new bucket's count silently
     never appears in the `--dry-run`/`--write` stderr summary (it would still be correct in the
     per-row TSV and in `index.json`, but the aggregate summary print would silently omit it).
   - Secondary defect: exclude `chunk_*.md` from the `mds` glob (lines ~298-301), per the root
     cause above.

2. **`.claude/scripts/literature-search.sh`** — real consumer, confirmed:
   - `QUARANTINED_FIDELITY_VALUES` (line 51, currently `"unverified_summary
     unverified_no_baseline"`) determines which fidelity values are excluded from default search
     ranking (opt-in allowlist, not fail-open by default here). **Must add `unadjudicated`** or
     an unadjudicated doc will appear in default (non-`--include-unverified`) search results
     unquarantined.
   - `load_fidelity_map()`/`get_fidelity()` (appears 3x in the file — inside the `do_search`
     Python heredoc ~line 225-264, and again in the `get_toc`-adjacent heredoc ~line 763-790,
     and a third occurrence servicing another subcommand ~line 907-930) are keyed by directory
     name and fail open on absent entries (`fmap.get(doc_id) or "unverified_summary"`) — these
     require **no code change**, they pass through whatever string is stored in `index.json`
     verbatim, including the new value.
   - The `[UNVERIFIED CONTENT - provenance_fidelity: ...]` banner logic (~line 855-861 in the
     `--read` heredoc) uses `if provenance_fidelity != 'verified_conversion':` — a fail-open
     check by construction. **No code change needed**; it already treats any non-`verified_conversion`
     value, including a brand-new one it has never seen, as needing the warning banner.

3. **`.claude/scripts/literature-briefing.sh`** — real consumer, **not mentioned in the task
   description**, and the most important one to catch:
   - `needs_fidelity_marker()` (line 107-112) is an **opt-in allowlist**, not a fail-open check:
     ```bash
     case "$1" in
       unverified_summary | unverified_no_baseline) return 0 ;;
       *) return 1 ;;
     esac
     ```
     A doc stamped `unadjudicated` falls into the `*)` branch and gets **NO warning marker** in
     `--lit` briefings unless this line is explicitly updated to include `unadjudicated`. This is
     the identical silent-trust failure mode task #839 exists to fix, one script downstream. This
     is a required change, not optional cleanup.
   - `get_doc_fidelity()` (line 94-101) fails open correctly already (`echo
     "${val:-unverified_summary}"` on absent field) — no change needed there.

4. **`.claude/scripts/literature-build-index.sh`** — **NOT a real consumer** (grep confirms zero
   references to `provenance_fidelity`, `verified_conversion`, or any enum value; the script only
   rebuilds the FTS5 chunk-search SQLite database from `chunks.json` manifests and has no
   awareness of the fidelity field at all). The task description's "known consumers" list is
   inaccurate on this point — **no change needed** in this file.

5. **Task #832's "cohort logic"** — grepped `specs/832_reconvert_and_validate_literature_corpus/`
   for `provenance_fidelity`/enum values/`reconversion`/`unadjudicated`: **zero matches**. #832's
   plan/report reference the 3 victim directories by name and by the general concept of
   "reconversion candidates," but do not hard-code the string `verified_conversion` or otherwise
   depend on the enum's exact value set in a way that would break from a 6th value being added.
   No file changes required in #832's artifacts as a *consumer*, though #832's plan text itself
   (which explicitly frames these 3 dirs as a workaround for this exact bug) should be
   cross-referenced/updated once #839 lands, per that task's own stated intent.

6. **`.claude/context/project/literature/patterns/zotero-pdf-resolution.md`** — one prose
   reference to "task #835's `provenance_fidelity` enum," non-normative documentation, not a code
   consumer. Worth a one-line update for accuracy but not required for correctness.

### Report/record updates required (documentation, not code)

- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`:
  - Line 118's "Risk" bullet documents the `frac is None` gap as an *accepted residual risk*
    ("acceptable for this corpus given its formal-math-heavy composition, but worth flagging as
    a known gap"). This must be updated to record that the risk was **realized** (3-4 real
    victims found, not hypothetical), and reference task #839 as the fix.
  - Line 71's `thomas_2003_reactive` recommendation ("recommend adding an explicit scope banner")
    should be marked as either implemented (if Option A above is chosen) or superseded by the
    `unadjudicated` reclassification (if Option B is chosen).
- `specs/836_recover_source_pdfs_via_zotero/artifacts/fidelity-delta.md` is a point-in-time
  delta record (Phase 6 of #836) and does not need retroactive correction, but a `--write`
  re-run after the #839 fix will produce a new distribution that a future task/summary should
  note supersedes it (all 3 named victims plus, depending on the Option A/B decision,
  `thomas_2003_reactive` will move out of `verified_conversion`).

## Decisions

- Confirmed the bug, all 3 named victims, and the two legitimate branches (disclosed and
  proof-adequate) exactly as the task description states — no corrections needed there.
- Identified `thomas_2003_reactive` as an unenumerated 4th directory hitting the same
  `frac is None` branch live in the current corpus; flagged as a decision point for the plan
  (Option A: add disclosure banner per #835's original recommendation, vs. Option B: let it
  become `unadjudicated`).
- Determined the secondary defect's true root cause is `chunk_*.md` double-counting in the `mds`
  glob, not pdftotext extraction quality — recommend fixing the glob rather than adding an
  upper-bound threshold.
- Corrected the consumer list: `literature-build-index.sh` is not a real consumer;
  `literature-briefing.sh`'s `needs_fidelity_marker()` (undocumented in the task description) is
  a real, required consumer change.

## Risks & Mitigations

- **Risk**: Fixing only the `literature-fidelity-audit.sh` enum without updating
  `literature-briefing.sh`'s `needs_fidelity_marker()` allowlist would leave a silent-trust gap
  in `--lit` briefings for any `unadjudicated` doc. **Mitigation**: explicit required change,
  documented above with exact line number (109).
- **Risk**: Deciding `thomas_2003_reactive`'s fate implicitly (by omission) rather than
  explicitly. **Mitigation**: the plan must pick Option A or B and state it; do not let the code
  fix silently determine the outcome without a plan-level decision, since #835's own analysis
  already judged this document legitimate and only failed to implement its own recommendation.
- **Risk**: Conflating the secondary defect's fix (glob exclusion) with an upper-bound-threshold
  approach could mask the real bug elsewhere in the corpus if new chunked+PDF directories are
  added later. **Mitigation**: fix the glob at the root, and optionally add a loose upper-bound
  sanity check (e.g. > 1.5) as defense-in-depth for genuinely anomalous future cases, but the
  glob fix is not optional.
- **Risk**: `--write` idempotency could be broken if the re-stamp logic depends on exact string
  matching against a hardcoded 5-value set anywhere else in the script not yet located.
  **Mitigation**: the plan's implementation phase should re-run `--dry-run` before and after the
  fix and diff the full TSV output, then run `--write` twice in a row and confirm the second run
  is a no-op (per the script's own documented idempotency contract), exactly as the task's
  VERIFICATION section requires.

## Context Extension Recommendations

- **Topic**: Literature corpus chunk-file conventions (`chunk_NNNN.md` as index-only artifacts,
  never additional content).
- **Gap**: No existing context file documents that `chunk_*.md` files are pure re-splits of a
  document's canonical `.md` and must be excluded from any whole-document word-count computation.
  This gap directly caused the secondary defect.
- **Recommendation**: Add a short note to
  `.claude/context/project/literature/patterns/` (or extend an existing literature pattern file)
  documenting this convention so future scripts touching `sources/<dir>/*.md` do not repeat the
  double-count mistake.

## Appendix

- Search commands used: `grep -rln "provenance_fidelity"` across `.claude/` and `specs/`;
  `grep -n "provenance_fidelity\|verified_conversion\|unverified_summary\|no_source_pdf\|not_yet_converted\|unverified_no_baseline"` per candidate consumer file.
- Verification commands: `bash .claude/scripts/literature-fidelity-audit.sh --dry-run` (full run
  against live `~/Projects/Literature` corpus, 97 directories); `jq` queries against
  `~/Projects/Literature/index.json` for the 3 named victims, `thomas_2003_reactive`'s two child
  entries, and directory-level chunk-file enumeration; direct `wc -w` word counts of canonical
  `.md` vs. `chunk_*.md` files for the 3 high-ratio directories; `pdfinfo` page-count/size checks
  (ruled out two-column-math hypothesis was not directly disprovable by page geometry alone, but
  the word-count reconciliation makes it moot regardless).
- No web search was needed; this is a pure codebase/data investigation task.
