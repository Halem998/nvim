---
next_project_number: 840
---

# TODO

## Task Order

*Updated 2026-07-09. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,821,826,832,837,838 | -- | agent-system, literature, extensions, ... |
| 2 | 822,827 | 821,826 | extensions |

**Grouped by Topic** (indented = depends on parent):

### Agent System

837 [NOT STARTED] — Shared .claude/ infrastructure has diverged across child projects
838 [NOT STARTED] — General skill-lifecycle data-loss bug: the planner-phase postflig

### Literature

832 [PLANNED] — Reconvert and validate the actionable portion of the ~/Projects/L

### Extensions

821 [RESEARCHED] — Route confirmed email-cleanup decisions (junk vs keep) from the e
  └─ 822 [NOT STARTED] — Implement the email->memory contribution per the #821 design. Add
826 [BLOCKED] — Root-cause and fix the pre-existing Logos (Protonmail Bridge) mai
  └─ 827 [BLOCKED] — The freshness gate shipped in tasks 823-825 is defective: email-c

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 839. Fix fail-open classification in literature-fidelity-audit.sh
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [839_fix_fidelity_audit_fail_open/reports/01_fidelity-audit-fail-open.md]
- **Plan**: [839_fix_fidelity_audit_fail_open/plans/01_fix-fidelity-audit-fail-open.md]
- **Summary**: [839_fix_fidelity_audit_fail_open/summaries/01_fix-fidelity-audit-fail-open-summary.md]

**Description**: Fix the fail-open classification bug in .claude/scripts/literature-fidelity-audit.sh, which silently stamps provenance_fidelity="verified_conversion" onto documents it could not actually adjudicate.

THE BUG (verified by reading the script and by running `literature-fidelity-audit.sh --dry-run` against the live corpus):

At lines 367-374, classify_dir() takes this branch:

    frac, adequate, total = proof_completeness_fraction(md_texts)
    if frac is None:
        # "this corpus is formal-math-heavy and every low-ratio case observed
        #  carries numbered statements"
        result["provenance_fidelity"] = "verified_conversion"
        return result

So a document with word_ratio far below RATIO_THRESHOLD (0.75), disclosed=False, and NO numbered statements to check gets labeled verified_conversion by default. The signal that would have caught it cannot fire, and the absence of that signal is read as a pass.

The inline comment justifies this by asserting "every low-ratio case observed carries numbered statements." That assumption was true of the corpus #835 measured. It is now FALSIFIED: task #836 recovered PDFs for prose philosophy papers that carry no numbered theorems.

MEASURED VICTIMS (disclosed=False, proof_fraction=None, stamped verified_conversion):
  fine_2012_guide-to-ground                         word_ratio=0.0327   (677 md words vs 20,701 pdf words)
  fine_2012_counterfactuals-without-possible-worlds word_ratio=0.2455   (2,960 vs 12,056)
  venema_1991                                       word_ratio=0.3737   (22,623 vs 60,541)

A 677-word stub against a 20,701-word PDF is a hand-written summary, not a verified conversion. The corpus currently asserts otherwise.

DO NOT BREAK THE LEGITIMATE BRANCH: doets_1987 (ratio=0.2378) and libkin_2004_ch3_ch7 (ratio=0.0187) are also low-ratio, but have disclosed=True. These are the documented partial conversions from #835. The disclosure branch (line 361) is correct and must keep passing them.

REQUIRED FIX: when the proof-completeness signal cannot fire (frac is None) on a low-ratio, undisclosed document, the honest result is a distinct value meaning "could not adjudicate" -- NOT verified_conversion. Introduce a sixth enum value (suggested: `unadjudicated`) rather than overloading unverified_summary, which asserts a positive finding the audit did not make. Fail closed, never open.

CONSEQUENT WORK:
- Update the five-value enum contract (currently documented at the script header, ~line 38) to six values, and update every consumer of provenance_fidelity. Known consumers: `.claude/scripts/literature-build-index.sh`, `literature-search.sh` (surfaces provenance_fidelity in result rows), and task #832 s cohort logic.
- Re-run `--write` after the fix so the 3 victim dirs are re-stamped honestly.
- #835 s report (`01_provenance-fidelity-audit.md`) documents this branch as accepted residual risk. Update that record; the risk is now realized, not residual.

SECONDARY DEFECT (same file, lower severity, no upper ratio bound): the `ratio >= RATIO_THRESHOLD` test at line 354 has no upper bound, so a markdown file with FAR MORE words than its PDF passes unexamined. Observed: fine_2010_some-puzzles-of-ground (2.08), fine_2012_pure-logic-of-ground (1.91), bacon_2018_broadest-necessity (1.78). Plausibly pdftotext under-extracting two-column math rather than corrupted markdown -- but nothing checks, and a ratio of 2.08 is not evidence of a faithful conversion. Investigate; add an upper sanity bound or an explicit documented exemption.

VERIFICATION: `--dry-run` is report-only and never writes index.json -- use it freely. After the fix, `--dry-run` must show the 3 victim dirs as unadjudicated (or equivalent), doets_1987 and libkin_2004_ch3_ch7 still verified_conversion via disclosure, and rabinovich_2014 still unverified_summary (proof_fraction=0.545 < 0.6). Confirm `--write` remains idempotent.

CONTEXT: discovered while orchestrating #836 (Zotero PDF recovery) and preparing the second /revise of #832. Task #832 was explicitly amended to WORK AROUND this bug (treating the 3 unadjudicated dirs as reconversion candidates) rather than fix it, because the audit script is outside #832 s file_scope. This task is the real fix.

---

### 838. Fix planner clobbering researcher .return-meta.json (merge not overwrite)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: General skill-lifecycle data-loss bug: the planner-phase postflight OVERWRITES the researcher's specs/{NNN}_*/.return-meta.json wholesale instead of MERGING, silently dropping memory_candidates the research agent emitted. Concrete instance: on task #831 the planner clobbered .return-meta.json, destroying 3 memory_candidates the research agent produced - (a) nix-ld/libstdc++ shim, (b) PyMuPDF sort=True reproduces the column-glue extraction bug, (c) NFKC normalization corrupts math Unicode. This affects EVERY task where research emits memory_candidates and a later phase rewrites the file, not just literature work - which is why it warrants its own task rather than folding into #835-#837 (all unrelated in scope). FIX SITE: .claude/context/formats/return-metadata-file.md (the contract) plus the skill postflight metadata-handling code - change semantics from overwrite to merge-not-overwrite so later phases preserve earlier phases' memory_candidates and other accumulated fields. Fully independent of #831-#837.

---

### 837. Fix .claude/ cross-project contract drift and add dangling-reference lint
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Shared .claude/ infrastructure has diverged across child projects and nothing detects dangling references at sync/load time - the same silent-degradation failure mode as #831's missing marker. IMPORTANT correction of the original bug report, which was MISATTRIBUTED to nvim: this repo (~/.config/nvim/.claude/) is HEALTHY - context/contracts/ contains all 8 of adversarial-verification, anti-analysis, convergence, orchestrator-discipline, recovery, reference-grounding, territory, wrap-up; its skill-orchestrate-hard/SKILL.md references 6, all present. The real defect is in ~/Projects/BimodalLogic/.claude/ - a SEPARATE COPY, not a symlink - whose skill-orchestrate-hard references 5 contracts it LACKS, so H5/H6/H7/H9 are silently un-injected. Drift is BIDIRECTIONAL: only-in-BimodalLogic = context-hygiene.md; only-in-nvim = convergence.md, orchestrator-discipline.md, recovery.md, territory.md, wrap-up.md. SCOPE: (1) reconcile contracts/ across ~/.config/nvim/.claude/ and ~/Projects/BimodalLogic/.claude/, sweeping other child projects (e.g. cslib); (2) decide the canonical set (is context-hygiene.md a real contract nvim should adopt?); (3) add a validator - extend check-extension-docs.sh or add a sibling script - that FAILS when any skill/agent/rule references a contracts/*.md, @.claude/... path, or context file absent in that project; (4) wire it into the sync path (.syncprotect / 'Load Core') so drift is caught at load time. LOUD-FAILURE requirement: a missing contract must not silently no-op. Fully independent of #831-#836 and #838.

---

### 836. Recover source PDFs via Zotero for PDF-less central dirs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 835
- **Research**: [836_recover_source_pdfs_via_zotero/reports/01_recover-source-pdfs-zotero.md]
- **Plan**: [836_recover_source_pdfs_via_zotero/plans/01_recover-source-pdfs-zotero.md]
- **Summary**: [836_recover_source_pdfs_via_zotero/summaries/01_recover-source-pdfs-zotero-summary.md]

**Description**: Recover source PDFs for the 52 central dirs under ~/Projects/Literature/sources/ that lack a source PDF (49 chunk-bearing + 3 empty - two different populations; address all 52). Zotero is the ONLY viable recovery source: ~/Projects/Literature/zotero-library.json exists (173 KB, 400 entries) and index.json entries carry zotero_key and zotero_path fields. SCOPE: re-resolve zotero_key/zotero_path against the Zotero library and its storage dir for the 52 PDF-less dirs; repopulate ~/Projects/Literature/pdfs/ symlinks; report which of the 52 remain unrecoverable after Zotero resolution and mark them no_source_pdf, never silently retained as authoritative. Likely entry point: .claude/scripts/zotero-resolve-sqlite-path.sh already exists and is probably the right starting point. VERIFIED - do NOT re-investigate per-repo copies: they yield ZERO unique PDFs (~/Projects/BimodalLogic/specs/literature/sources = 31 pdfs but 0 unique vs central; ~/Projects/cslib/specs/literature/sources = 0 pdfs; ~/Projects/cslib-refactor-prop_logic/specs/literature/sources = 0 pdfs). There is NO ordering constraint against #834 - deleting BimodalLogic's sources/ destroys zero unique recovery sources (central-lacks-PDF intersect BimodalLogic-has-PDF = 0). DEPENDENCY: depends on #835 via file-footprint overlap - both write ~/Projects/Literature/index.json, where 835 DEFINES the provenance/fidelity enum and 836 WRITES one of its values (no_source_pdf); schema must precede population.

---

### 835. Literature corpus provenance and fidelity audit
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md]
- **Plan**: [835_literature_corpus_provenance_fidelity_audit/plans/01_provenance-fidelity-flagging.md]
- **Summary**: [835_literature_corpus_provenance_fidelity_audit/summaries/01_provenance-fidelity-flagging-summary.md]

**Description**: Provenance/fidelity defect orthogonal to #831's four extraction bugs. Many literature dirs are not badly converted - they were never converted; the .md is a hand-authored paraphrase that reads as authoritative and the index blesses it with a token count, so agents ground formal work on a summary that never contained the lemma it cites. VERIFIED: of 97 dirs under ~/Projects/Literature/sources/, populations are: 0 healthy (PDF AND chunks), 45 PDF+zero-chunks (never converted; .md is a hand-written stand-in), 49 chunks+no-PDF (converted but source PDF absent, not reconvertible), 3 neither. Word-ratio (md_words/pdf_words) on PDF-bearing dirs shows systematic summary-substitution: blackburn_2002=0.03, baier_katoen_2008=0.10, caleiro_2013=0.09, doets_1987=0.11, gabbay_1993=0.15, goldblatt_2003=0.25, rabinovich_2014=0.29, doets_1989=0.36, derijke_1995=0.44, hodkinson_2006=0.57. Concrete exemplar: rabinovich_2014 .md = 245 lines / 2,093 words (opens '## Overview\nProvides a simple, self-contained proof of Kamp's theorem...' - editorial prose), sibling PDF = 16 pages / 7,296 words, index.json holds ONE entry id=rabinovich_2014 token_count=2721; Lemma 3.2(1) is a single unproved sentence, Definition 7.13 is one line. SCOPE: (1) classify every dir into the four populations; (2) build a detector for 'md is a hand-authored summary, not a conversion of the sibling PDF' using word-ratio threshold, absence of chunk_*.md, prose markers (leading '## Overview'), absence of the PDF's section headings, missing numbered lemma/definition bodies; (3) record a provenance/fidelity field per index.json entry with values verified_conversion / unverified_summary / no_source_pdf; (4) make literature-briefing.sh and literature-search.sh LOUDLY flag low-fidelity entries rather than serving them as authoritative; (5) quarantine, never delete. KEY INSIGHT to record for downstream: corrupt column-interleaved text announces itself, a fluent hand-written summary does not - which is exactly why fidelity needs its own gate, the fidelity analogue of #831's quality gate. Independent of #831-#834. NOTE: #832's 'reconvert all 97 dirs' premise is invalidated by this finding (52 have no PDF; 45 need .md replacement, not re-derivation) - #832 carries deps [835,836] as a premise interlock and should be /revised once 835/836 land.

---

### 834. Retire stale per-repo literature copies (FINDING 6)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [834_retire_stale_per_repo_literature_copies/reports/01_retire-stale-literature-copies.md]
- **Plan**: [834_retire_stale_per_repo_literature_copies/plans/01_retire-stale-literature-copies.md]
- **Summary**: [834_retire_stale_per_repo_literature_copies/summaries/01_retire-stale-literature-copies-summary.md]

**Description**: Retire the stale per-repo literature copies. FINDING 6: the architecture is ALREADY correct (central store + per-repo index, no document duplication) - the cleanup simply never happened. ~/Projects/BimodalLogic/specs/literature/ is 181 MB with 27 source dirs, and ALL 27 already exist in ~/Projects/Literature/sources/ (97 dirs total). A DEPRECATED.md there records migration completed 2026-06-14 under task 710, and LITERATURE_DIR is already wired into both .claude/settings.json and home.nix. Verify content equivalence of the 27 BimodalLogic source dirs against central, confirm the per-repo specs/literature-index.json sub-index convention works end-to-end (currently unclear whether it is populated anywhere), then delete ~/Projects/BimodalLogic/specs/literature/sources/. Sweep ~/Projects/ for other stale specs/literature/ copies. Keep DEPRECATED.md in place. Scope as verify-then-delete + confirm the sub-index convention works, NOT as a re-migration. Independent - no dependencies.

---

### 833. Harden retrieval against tokenization brittleness
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 831
- **Research**: [833_harden_literature_retrieval_tokenization/reports/01_harden-retrieval-tokenization.md]
- **Plan**: [833_harden_literature_retrieval_tokenization/plans/01_harden-retrieval-tokenization.md]
- **Summary**: [833_harden_literature_retrieval_tokenization/summaries/01_harden-retrieval-tokenization-summary.md]

**Description**: Harden .claude/scripts/literature-search.sh and literature-briefing.sh so tokenization brittleness degrades gracefully. Triggering symptom (a symptom, not the disease): an agent dead-ended with 'FTS5 chokes on the punctuation; the research agent will read the chunk directly', surfaced while working on ~/Projects/BimodalLogic/specs/337_build_joint_multiowner_disjunct_bracketholds_engine_for_kve2_sepdisjunct/plans/04_joint-disjunct-holds-codesign.md. Normalize the search query using the SAME normalization applied to the corpus in #831; on zero-results or an FTS5 parse failure, fall back gracefully (trigram/LIKE, or sqlite-vec semantic search per the draperlaboratory/pdf2sqlite design, which would make retrieval resilient to exactly this punctuation/tokenization brittleness). Evaluate storing a per-chunk LLM-generated 'gist' alongside text for searchable summaries. Ensure literature-briefing.sh surfaces a usable next action rather than leaving the agent to improvise 'I'll just read the chunk directly.' System ALREADY has literature-schema.sql + FTS5 (chunks_fts, bm25) - this is augmentation, not a rewrite. Depends on #831; can run parallel to #832.

---

### 832. Reconvert and validate the literature corpus (BUG 5)
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 831, Task 835, Task 836, Task 839
- **Research**: [832_reconvert_and_validate_literature_corpus/reports/01_reconvert-validate-corpus.md]
- **Plan**: [832_reconvert_and_validate_literature_corpus/plans/01_reconvert-validate-corpus.md]

**Description**: Reconvert and validate the actionable portion of the ~/Projects/Literature corpus, driven by the measured provenance/fidelity classification that task #835 established and stamped onto ~/Projects/Literature/index.json, as corrected by the re-derivation performed after #836 landed. The original "reconvert and validate all 97 source dirs" premise is dead, and so are the earlier "verified facts" that replaced it: the "ZERO are healthy / 45 dirs are hand-written summaries" figures and the cited word-ratios (blackburn_2002 = 0.03, rabinovich_2014 = 0.29) were artifacts of a single-file-sampling bug (comparing one arbitrary .md file against the entire PDF). Aggregated at the whole-document level, nearly every cited case is a healthy conversion, and blackburn_2002 is in fact a verified conversion. Drop all of those numbers rather than restating them.

MEASURED CLASSIFICATION (authoritative, re-derived post-#836 via `literature-fidelity-audit.sh --dry-run`). Two real granularities exist; state which you mean and never conflate them.
At DIRECTORY level (97 dirs total):
- 45 no_source_pdf         — no PDF present; cannot be reconverted
- 42 verified_conversion   — stamped healthy, but see the UNADJUDICATED caveat below
- 5  not_yet_converted     — PDF present, zero markdown (already self-disclosed)
- 4  unverified_no_baseline — PDF present but `pdftotext -layout` extracts 0 words; ratio undeterminable
- 1  unverified_summary    — rabinovich_2014, the ONLY confirmed undisclosed paraphrase
At index-ENTRY level (153 entries): 91 verified_conversion, 45 no_source_pdf, 15 unverified_no_baseline, 1 not_yet_converted, 1 unverified_summary.

THE STAMP IS NOT FULLY TRUSTWORTHY (read before acting on any classification). `.claude/scripts/literature-fidelity-audit.sh` FAILS OPEN at lines 367-374: when a document has word_ratio < 0.75, disclosed = False, AND proof_fraction = None (no numbered statements available to check), it defaults the document to `verified_conversion`. Its inline comment justifies this by assuming "every low-ratio case observed carries numbered statements" — an assumption FALSIFIED by the PDFs #836 recovered, which include prose philosophy papers with no numbered theorems. Three directories are therefore stamped `verified_conversion` while being genuinely UNADJUDICATED:
- fine_2012_guide-to-ground                         ratio = 0.0327 (677 md words vs 20,701 pdf words)
- fine_2012_counterfactuals-without-possible-worlds ratio = 0.2455 (2,960 vs 12,056)
- venema_1991                                       ratio = 0.3737 (22,623 vs 60,541)
Two other low-ratio dirs — doets_1987 (0.2378) and libkin_2004_ch3_ch7 (0.0187) — carry disclosed = True. Those are the LEGITIMATE documented partial conversions. Do not touch them.

REMAINING WORK — 13 ACTIONABLE DIRS, SCOPED PER COHORT (touch only the cohorts that need work):
- 5 not_yet_converted dirs (gabbay_2000, girard_1989, negri_von_plato_2001, troelstra_schwichtenberg_2000, van_doorn_2015) — the only greenfield conversion work. Run the fixed converter from #831 (COMPLETE). Treat converter exit code 3 as skip+log (a loud quality-gate failure), NEVER as success. Goldblatt/Hodkinson/Venema 2003 is a known document that fails the primary tier and must be routed with LITERATURE_CONVERTER=pymupdf.
- 3 unadjudicated dirs (fine_2012_guide-to-ground, fine_2012_counterfactuals-without-possible-worlds, venema_1991) — RECONVERSION CANDIDATES despite their `verified_conversion` stamp. The two Fine papers have real PDFs thanks to #836; venema_1991 had a PDF all along. Reconvert from the PDF and compare.
- 4 unverified_no_baseline dirs (burgess_1984, gabbay_1994, thomason_1984, vardi_wolper_1986) — NOT reconversion. Their PDFs yield 0 words under pdftotext (scanned/image PDFs), so they need a baseline-extraction fix (OCR-based re-extraction, e.g. ocrmypdf/pytesseract) so a ratio becomes computable; then re-run the fidelity audit to confirm/promote.
- 1 unverified_summary dir (rabinovich_2014) — REPLACE its .md with a real conversion derived from its sibling PDF (a PDF is present), then re-run `literature-fidelity-audit.sh` to reclassify.
- Remaining verified_conversion dirs (the 42 minus the 3 unadjudicated above) — no action.
- 45 no_source_pdf dirs — OUT OF SCOPE. #836 RAN and resolved the question: it recovered 7 of the original 52 from Zotero, and the remaining 45 are CONFIRMED ABSENT from the Zotero library (not merely unmatched). They are not "gated pending #836"; they need a different acquisition route entirely, which belongs to a separate sourcing task.

REVALIDATION HALF (still real, still worth doing): now that a fixed converter (#831) and a provenance field (#835) both exist, rebuild/validate the corpus index via `.claude/scripts/literature-build-index.sh`, and re-run the fidelity audit after any conversion so newly-converted dirs receive a fresh `provenance_fidelity` + `word_ratio` stamp. Any residue that still lacks a PDF stays no_source_pdf.

CONSTRAINTS:
- Trust #835's stamped `provenance_fidelity` EXCEPT where (word_ratio < 0.75 AND disclosed = False AND proof_fraction = None). Those entries are UNADJUDICATED, not verified, and must be treated as reconversion candidates.
- Aggregate word-ratio at the WHOLE-DOCUMENT level, never single-file.
- Quarantine-never-delete posture throughout.
- Converter exit code 3 = skip + log, never success.
- Goldblatt/Hodkinson/Venema 2003 must route with LITERATURE_CONVERTER=pymupdf.
- The 45 no_source_pdf dirs are out of scope for this task.

SCOPE BOUNDARY: fixing the fail-open in `literature-fidelity-audit.sh` is task #839 (Fix fail-open classification in literature-fidelity-audit.sh). 832's file_scope is `~/Projects/Literature/sources/` and `.claude/scripts/literature-build-index.sh`; the audit script is NOT in scope. 832 must WORK AROUND the fail-open by treating the 3 unadjudicated dirs as reconversion candidates — do not fix the script here. Re-run the audit only AFTER #839 lands; otherwise accept that re-running it will re-stamp those 3 dirs as `verified_conversion` again.

RESIDUAL RISK (note, not work): the audit has no UPPER ratio bound — fine_2010_some-puzzles-of-ground (2.08), fine_2012_pure-logic-of-ground (1.91), and bacon_2018 (1.78) pass unexamined because they clear the >= 0.75 floor. Plausibly pdftotext under-extracting math, but nothing checks.

STATUS: BLOCKED on #839 (audit fail-open fix). #831/#835/#836 are all complete, so the corpus work itself is fully specified and ready; the remaining gate is #839, which also serializes on the shared file `.claude/scripts/literature-build-index.sh`. All 13 actionable dirs (5 not_yet_converted + 3 unadjudicated + 4 unverified_no_baseline + 1 unverified_summary) can be executed against #831's fixed converter and #835's classification, with the unadjudicated caveat applied.

DEPENDENCIES: 831 (COMPLETE — fixed converter), 835 (COMPLETE — provenance/fidelity classification), 836 (COMPLETE — Zotero PDF recovery; 7 recovered, 45 confirmed absent), 839 (NOT STARTED — audit fail-open fix; both a correctness prerequisite for the final re-audit and a file_scope conflict on literature-build-index.sh).

---

### 831. Fix literature conversion pipeline correctness (BUGS 1-4)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md]
- **Plan**: [831_fix_literature_conversion_pipeline_correctness/plans/01_conversion-pipeline-fix.md]
- **Summary**: [831_fix_literature_conversion_pipeline_correctness/summaries/01_conversion-pipeline-fix-summary.md]

**Description**: Fix silent conversion-correctness bugs in .claude/scripts/literature-convert.sh. BUG 1 (ROOT CAUSE): converter prefers marker/marker_single, but marker_single is NOT installed on this machine, so every corpus doc fell back to `pdftotext -layout`, which glues two-column academic layouts side-by-side into semantic garbage (verified in ~/Projects/Literature/sources/alur_2013_syntax-guided-synthesis/chunk_0012.md). Make converter selection explicit and LOUD, never silently degrade to a layout-destroying engine. Evaluate/require marker, or pymupdf4llm/docling/nougat, or replace the -layout path with column-aware PyMuPDF page.get_text("blocks"/"dict") reading-order extraction (never -layout on multi-column). BUG 2: literature-convert.sh:171 `for pg in range(start_page, min(end_page, start_page + 3))` silently truncates each TOC section to its first 3 pages (unbounded data loss) - remove it. BUG 3: 2,351 chunk files match `^(.+) > \1$` (doubled breadcrumb headers); no-TOC docs derive headings from sentence fragments (e.g. ~/Projects/Literature/wdb.cariani.santorio/chunk_0010.md begins 'indeterminacy. > indeterminacy.'). Fix heading derivation and doubled breadcrumbs. BUG 4: 64 markdown files contain raw U+FB00-U+FB06 ligatures (swordﬁsh, identiﬁ) that FTS5 unicode61 won't decompose; add NFKC/ligature folding, dehyphenation across line breaks, and soft-wrap rejoining. Add a conversion-quality gate that FAILS LOUDLY rather than emitting corrupt markdown: column-interleaving heuristic, page-coverage assertion against len(doc), ligature scan. HIGH priority - blocks #832 and #833. Evidence pre-verified; no need to re-derive.

---

### 830. Aerc terminal ctrl hjkl esc passthrough
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/reports/01_aerc-terminal-passthrough-research.md]
- **Plan**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/plans/01_aerc-terminal-passthrough.md]
- **Summary**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/summaries/01_aerc-terminal-passthrough-summary.md]

**Description**: Special-case the aerc terminal in Neovim's terminal-mode keymap setup so <C-h/j/k/l> and <Esc> reach aerc instead of being intercepted by Neovim. This is the cross-repo companion to .dotfiles task 105 Recommendation B (aerc<->nvim/himalaya keymap alignment); it is a hard PREREQUISITE for the aerc-side <C-hjkl> folder binds in that task.

BACKGROUND: aerc is launched via <leader>me into a floating toggleterm (lua/neotex/plugins/tools/mail.lua, cmd="aerc"). Every terminal matches the term://* TermOpen autocmd (lua/neotex/config/autocmds.lua:25) which calls set_terminal_keymaps() (lua/neotex/config/keymaps.lua:116). aerc is neither the is_claude nor is_opencode special case, so it falls through to the generic else branch (keymaps.lua:147-150) that maps terminal-mode <C-h/j/k/l> -> wincmd h/j/k/l, and the <Esc> -> <C-\><C-n> exit-terminal map (keymaps.lua:133). Result: aerc NEVER receives <C-hjkl> (they navigate Neovim windows) or <Esc> (it drops to Neovim normal mode instead of cancelling aerc's :prompt / :search / selection).

CHANGE: add an is_aerc detection alongside is_claude/is_opencode (match the terminal bufname/cmd for 'aerc'), and for aerc terminals (1) SKIP the <C-h/j/k/l>->wincmd remaps so they pass through to aerc, and (2) SKIP the <Esc>->exit-terminal remap (extend the existing `if not is_claude` guard to also exempt aerc) so aerc prompts cancel with Esc. This is safe because the aerc window is a fullscreen float with no sibling Neovim windows, so wincmd h/j/k/l do nothing useful there anyway. The change MUST be strictly gated on is_aerc: claude, opencode, and generic terminals keep their current <C-hjkl>/<Esc> behavior unchanged.

AFTER THIS LANDS: the .dotfiles task 105 side binds aerc's <C-h>/<C-l> = :prev-folder/:next-folder (or <C-j>/<C-k> = message nav) in modules/home/email/aerc.nix. That aerc-side edit is out of scope here.

FILES: lua/neotex/config/keymaps.lua (set_terminal_keymaps, ~L116-158). Reference only: lua/neotex/config/autocmds.lua:25 (the term://* trigger), lua/neotex/plugins/tools/mail.lua (the <leader>me launcher).

VERIFICATION: open aerc via <leader>me; confirm (once the aerc.nix binds exist) <C-hjkl> reach aerc and <Esc> cancels an aerc :prompt from inside the float; confirm a Claude Code terminal and a general :terminal STILL have working <C-hjkl> window-nav and <Esc> exit (no regression from the is_aerc gate).

CROSS-REPO: research + rationale in ~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md (esp. §4 reachability table and §6.2 Recommendation B). Companion .dotfiles task 105.

---

### 829. Add leader vl piper tts read buffer
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [829_add_leader_vl_piper_tts_read_buffer/reports/01_piper-tts-toggle-research.md]
- **Plan**: [829_add_leader_vl_piper_tts_read_buffer/plans/01_piper-tts-toggle.md]

**Description**: Add <leader>vl toggle mapping that uses piper TTS to read the current buffer aloud from the cursor position to end of buffer, stopping playback when toggled off

---

### 828. Resolve Logos Trash/Archive UID collisions via live IMAP verification
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [826_logos_maildir_duplication_mbsync_repair/reports/02_spawn-analysis.md]
- **Plan**: [828_logos_trash_archive_uid_collision_repair/plans/01_logos-uid-collision-repair.md]
- **Summary**: [828_logos_trash_archive_uid_collision_repair/summaries/01_logos-uid-collision-repair-summary.md]

**Description**: Build and run a live-IMAP-verified, rename-only repair for the 862 duplicate-UID pairs left unresolved by task 826's Phase 5 (860 in ~/Mail/Logos/.Trash/cur, 2 in ~/Mail/Logos/.Archive/cur). Task 826's implementation verified that all 862 pairs have DIFFERENT Message-Id values between the two colliding files -- these are distinct, irreplaceable real messages that collided on the same local U=NNN slot due to a corrupted, non-monotonic Near-side UID counter from the 2026-02-09 import (see specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md). No Message-Id-based delete is safe.

Scope: For each colliding UID, perform a live IMAP UID FETCH/Message-Id lookup against the ProtonMail Bridge server for the current Far-side UID assignment of the affected folder (.Trash or .Archive), compare it against each local candidate file's Message-Id, and where a match is found on one member of the pair, rename the OTHER (non-matching) member's Maildir filename to a fresh, non-colliding U=NNN token. Rename only -- never delete either file, never write/push anything to the server via this task's own script. Build a dry-run mode that lists all planned renames before executing any of them. Validate the technique end-to-end on the 2 tractable .Archive pairs first, then apply the same script to the 860 .Trash pairs. Use the existing Phase 1 backup at ~/Mail/.logos-backup-20260706/ (tarballs, mbsyncstate/uidvalidity snapshots, baseline counts) as the rollback source, and log every rename decision (matched/renamed, which file, old and new UID token) to a new artifact under that backup directory.

Explicitly out of scope (left for task 826 to resume afterward): running `mbsync logos`, clearing/resetting .mbsyncstate or .uidvalidity, lifting email-freeze, notmuch reindexing. Do not re-verify Message-Id distinctness (already established) or re-run Phase 3's Labels-mirror analysis (separate, already-decided concern). Ground the implementation in specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md (resolution path 1) and the Phase 5 section of specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md.

Definition of done: `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the equivalent for .Archive/cur both return nothing (one physical file per UID), zero files deleted, zero server-side writes performed by this task's script, and a decision log written to the Phase 1 backup directory documenting every rename.

---

### 827. Redesign the /email staleness detector - stop equating maildir files with deduped messages
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 826

**Description**: The freshness gate shipped in tasks 823-825 is defective: email-census compares `himalaya -f INBOX` maildir FILE count against `notmuch count folder:X` deduped-MESSAGE count. These are incomparable (different file sets; heavy label-folder duplication; Message-ID dedup), so the line reads [STALE] even immediately after a full email-reindex (observed live: on-disk=3736 vs notmuch-indexed=3735, and `notmuch count --output=files folder:Logos`=11075 - none agree). As a hard gate requiring [ok] it is unreachable, forcing a manual 'Proceed, accept N' override on every --all run. Redesign options to evaluate: (a) compare comparable file sets - on-disk files vs `notmuch count --output=files` for the EXACT indexed path (path:<acct>/cur); (b) downgrade from a hard equality gate to a 'notmuch grossly behind disk' ratio/threshold heuristic that can actually reach a passing state and only blocks on large lags; (c) make the real gate 'was email-reindex run this session?' rather than a count comparison. Update census.nix (freshness line), skill-email-cleanup Stage 1 gate, staleness-detection.md, and wrapper-contracts.md section 13. Depends on 826 because the correct true count depends on resolving the Logos maildir duplication first. Cross-repo: census.nix change lands in ~/.dotfiles.

---

### 826. Investigate Logos maildir file-duplication and repair broken mbsync logos sync
- **Status**: [BLOCKED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**:
  - [826_logos_maildir_duplication_mbsync_repair/reports/01_logos-maildir-mbsync-diagnosis.md]
  - [826_logos_maildir_duplication_mbsync_repair/handoffs/phase-7-blocker-report.md]
- **Plan**: [826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md]
- **Summary**:
  - [826_logos_maildir_duplication_mbsync_repair/summaries/01_logos-mbsync-maildir-repair-summary.md]
  - [826_logos_maildir_duplication_mbsync_repair/summaries/02_phase7-reconcile-attempt-summary.md]

**Description**: Root-cause and fix the pre-existing Logos (Protonmail Bridge) mail infrastructure problem exposed by /email --logos --all (2026-07-05). Symptoms: (1) severe maildir file duplication - path:Logos/cur holds 8448 files for only 2869 unique Message-IDs (~3x), and folder:Logos spans 3735 messages / 11075 files; the Gmail-labels-over-IMAP pattern stores one message under many .Labels.* folders. (2) `mbsync logos` reconcile exits non-zero after mutations with: duplicate UIDs in .Trash/.Archive, a Maildir++ dotted-folder problem on `.Labels.benbrastmckie@gmail.com` (a dot in the folder name), and a draft with a missing Date header. Consequence: 161 local deletes from the recent cleanup are staged in local Logos Trash but CANNOT be pushed to the Proton server. Investigate ~/.dotfiles/modules/home/email/mbsync.nix (logos group/channels), notmuch.nix, and protonmail.nix; determine whether the .Labels.* folders should be excluded from the logos mbsync channels, whether Bridge label-folders are double-synced, and how to resolve the duplicate-UID and dotted-folder errors. Cross-repo: fixes land in ~/.dotfiles (deliberate handoff). Deliver a diagnosis + a concrete mbsync/notmuch config fix and a maildir de-duplication/cleanup plan. Do NOT run /email --logos --sync until this is fixed.

---

### 825. Wire detect->remediate->re-run into the --all coverage contract and docs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823, Task 824

**Description**: Synthesis/documentation task closing the loop opened by 823 (detection) and 824 (remediation). Update commands/email.md (add the staleness->remediation flow to Workflow Execution and Error Handling), EXTENSION.md, README.md, and the archive-mode-risk.md / bulk-bucket-review.md context so the --all whole-mailbox coverage promise is EXPLICITLY conditioned on a fresh notmuch index, and the end-to-end flow (detect staleness -> recommend/run sanctioned reindex or --sync -> re-run --all) is documented consistently across command, skill, and context layers. Ensure no residual doc claims --all covers the whole mailbox unconditionally.

---

### 824. Provide a sanctioned notmuch reindex remediation path for /email
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823

**Description**: When staleness is detected (task 823) the skill currently dead-ends: notmuch new is treated as forbidden raw notmuch, so there is no sanctioned remediation. But notmuch new is index-only and non-mutating — exactly analogous to mbsync, which IS sanctioned via skill-email-sync (not a wrapper binary, passes mail-guard.sh, human-confirmed). Research how notmuch reindexing is actually wired for these maildirs (post-mbsync notmuch new hook? systemd path/timer? manual). Then add a sanctioned remediation mirroring the mbsync precedent: fold a reindex step into skill-email-sync or a documented /email --sync behavior, or document the exact sanctioned command, so the skill can remediate rather than dead-end. Reconcile wrapper-contracts.md §8 (two-layer enforcement) and mail-guard.sh reasoning to distinguish index-only notmuch new (sanctioned, like mbsync) from forbidden raw notmuch/himalaya MUTATION and tag commands; ensure skill MUST-NOT text stays consistent. May surface a .dotfiles handoff recommendation if reindex belongs in the frozen wrapper layer.

---

### 823. Add notmuch-staleness detection gate to skill-email-cleanup
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [823_email_notmuch_staleness_detection_gate/reports/01_staleness-detection-research.md]

**Description**: /email --all promises whole-mailbox coverage but classification reads notmuch (email-classify) while mailbox ground truth is maildir/himalaya (email-census); a stale notmuch index silently degrades --all to partial coverage (observed: census=62 vs notmuch folder:Logos=12 for the Logos INBOX). Add a wrapper-only staleness precondition to skill-email-cleanup that, before an --all sweep (and surfaced in default mode), compares the maildir ground-truth count from email-census against the notmuch indexed count for the same account/folder via the email-classify --limit 0 count-oracle (wrapper-contracts.md §10); on divergence beyond a small threshold, WARN or BLOCK with an actionable message rather than presenting partial coverage as whole-mailbox. Research must verify which source email-census actually counts from (maildir vs notmuch) so the comparison is meaningful. Add domain/staleness-detection.md documenting the check, count sources, and threshold. Wrapper-only compliant (both are wrapper calls); no .dotfiles change.

---

### 822. Implement email cleanup to memory vault contribution
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 821

**Description**: Implement the email->memory contribution per the #821 design. Add a harvest step to skill-email-cleanup (or a memory lifecycle hook) that, when junk/keep decisions are confirmed, creates or UPDATEs a sender/domain-aggregated preference memory in the vault (CREATE/UPDATE/EXTEND with dedup against memory-index.json). Include an opt-in/gate consistent with skill-todo's harvest pattern, tests, and documentation updates to both extensions' READMEs/manifests.

---

### 821. Research and design email-to-memory contribution architecture
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [821_email_to_memory_contribution_architecture/reports/01_team-research.md]

**Description**: Route confirmed email-cleanup decisions (junk vs keep) from the email extension into the memory vault so the system learns sender/domain preferences over time. RESEARCH PHASE FIRST: survey July-2026 best practices for email-triage to preference/memory-learning systems (sender reputation, preference capture, vault-bloat avoidance, aggregation strategies, dedup, feedback loops), plus the concrete integration surfaces already identified: capture point = skill-email-cleanup human review gate (Stage 3 per-message / Stage 2.5 bucket approval in --all mode) where the JSONL candidate manifest (Message-ID keyed, proposed_action delete|archive|keep|unsure + confidence) is confirmed; memory API = skill-memory CREATE/UPDATE/EXTEND with content-mapping + MCP dedup against .memory/memory-index.json; reusable pattern = skill-todo's harvest->dedup->user-gated-create flow (Stage ~181+); hook surface = memory extension manifest.json empty hooks object as an alternative capture path. DESIGN DECISION ALREADY MADE BY USER: memories are SENDER/DOMAIN-AGGREGATED (one evolving preference memory per sender or domain, UPDATE/EXTEND as more mail is seen -- NOT per-message), chosen to avoid vault bloat; the research should refine the aggregation/dedup/schema mechanics within that decision, not relitigate it. Output: chosen capture point, memory schema/tags, dedup + update strategy, and opt-in/gate behavior.

---

### 820. Email all resurface classified gap
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [820_email_all_resurface_classified_gap/reports/01_wrapper-gap-seed.md]
- **Plan**: [820_email_all_resurface_classified_gap/plans/02_email-all-emit-tagged.md]
- **Summary**: [~/.dotfiles/modules/home/email/agent-tools/classify.nix]

**Description**: /email --all cannot re-surface an already-fully-classified mailbox for review: email-classify is emit-on-change, email-census takes no query, and mutation wrappers plan over an approved manifest not proposed-* tags, so there is no wrapper-only read-out of tagged messages. Fix spans the email extension skill (--all Stage 2) and the .dotfiles wrapper binaries (a read-only --emit-tagged / candidate rebuild). See reports/01_wrapper-gap-seed.md.

---

### 819. Load email extension in extensions json
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [819_load_email_extension_in_extensions_json/reports/01_intent-and-mechanics.md]
- **Plan**: [819_load_email_extension_in_extensions_json/plans/01_document-no-op-decision.md]

**Description**: Add the email extension to .claude/extensions.json so it is actually loaded and its EXTENSION.md content propagates into .claude/CLAUDE.md (pre-existing gap flagged in review-2026-07-04: check-extension-docs.sh warns 'routing target not deployed: skill-email-implementation', and EXTENSION.md->CLAUDE.md merge is unobservable because 'email' is absent from extensions.json). Only do this if the email extension is intended to be loaded in this repo. Verify: extension loads without routing warnings, EXTENSION.md [email] section propagates to CLAUDE.md via the merge mechanism.

---

### 818. Email extension doc consistency sweep
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [{]
- **Plan**: [818_email_extension_doc_consistency_sweep/plans/01_email-doc-consistency-sweep.md]

**Description**: Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04). (3 MED) Finish account-generalizing archive-mode-risk.md: title still says 'All Mail Scope' (line 1), Blast-Radius table hardcodes ~64,000 msgs with no Logos row (12-17), Gate #1 hardcodes 'All Mail' (61), Gate #3 hardcodes 'mbsync gmail' (68) — make them match the account-generic tables in skill-email-cleanup/SKILL.md. (4 MED) Hardcode ONE pilot-ack file convention in skill-email-cleanup/SKILL.md (428-442) — single 'account'-keyed file with the gate always checking that path — instead of leaving it to per-invocation agent judgment. (5 MED) Refresh README.md (16-17,106-125): still describes /email as Gmail-only with no --account/--logos. (6 MED) Add a --sync channel/account mismatch warning in Stage 3 confirm (commands/email.md ~32-34, skill-email-sync/SKILL.md ~64-66). Ref: specs/reviews/review-2026-07-04.md.

---

### 817. Reconcile email stale multiaccount gating
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Plan**: [817_reconcile_email_stale_multiaccount_gating/plans/01_reconcile-multiaccount-gating.md]

**Description**: Reconcile the email/ extension's stale multi-account gating language with the now-verified wrapper contract. Ground truth: .dotfiles task 79 landed + switched in and was live-verified by .dotfiles task 80 (9/9 contract rows PASS), so wrapper-contracts.md is authoritative. Findings 1,2,7 from review-2026-07-04: (1 CRITICAL) strip the obsolete 'wrapper reserves --account gmail / hard error / pending task 79' gating language from commands/email.md (~41-44,67-72,204-208), EXTENSION.md (~29,72-77), skill-email-cleanup/SKILL.md (~45-60), skill-email-sync/SKILL.md (~58-61); (2 HIGH) convert the skill-email-cleanup precondition gate from a 'wrapper is gmail-only, STOP' gate into a light liveness check, and fix the probe: 'email-census --account logos --help' short-circuits before flag validation — use a real read-only probe like 'email-census --account logos' and check exit/stderr; (7 LOW) align gate naming ('step-1' vs 'Phase-1'). Ref: specs/reviews/review-2026-07-04.md. Verify: agent reading /email --logos gets one consistent, non-contradictory story; check-extension-docs.sh [email] still PASS.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Task Type**: neovim
- **Topic**: Email Integration
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted. The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.
