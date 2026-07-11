---
next_project_number: 849
---

# TODO

## Task Order

*Updated 2026-07-11. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,821,826,837,838 | -- | agent-system, extensions, email integration, ... |
| 2 | 822,827 | 821,826 | extensions |

**Grouped by Topic** (indented = depends on parent):

### Agent System

837 [NOT STARTED] — Shared .claude/ infrastructure has diverged across child projects
838 [NOT STARTED] — General skill-lifecycle data-loss bug: the planner-phase postflig

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

### 832. Reconvert and validate the literature corpus (BUG 5)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 831, Task 835, Task 836, Task 839
- **Research**: [832_reconvert_and_validate_literature_corpus/reports/01_reconvert-validate-corpus.md]
- **Plan**: [832_reconvert_and_validate_literature_corpus/plans/01_reconvert-validate-corpus.md]
- **Summary**: [832_reconvert_and_validate_literature_corpus/summaries/01_reconvert-validate-corpus-summary.md]

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
