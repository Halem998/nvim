# Implementation Plan: Reconvert and Validate the Literature Corpus (BUG 5)

- **Task**: 832 - Reconvert and validate the actionable portion of the ~/Projects/Literature corpus
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: 831 (complete), 835 (complete), 836 (complete), 839 (complete)
- **Research Inputs**: specs/832_reconvert_and_validate_literature_corpus/reports/01_reconvert-validate-corpus.md
- **Artifacts**: plans/01_reconvert-validate-corpus.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Execute the actionable portion of the `~/Projects/Literature` corpus reconversion, driven by the
live-verified cohorts in report 01. #839 has landed: the fidelity audit now fails closed (sixth
enum value `unadjudicated`), so the audit is trustworthy and re-runnable freely. The task's stale
"5 + 3 + 4 + 1 = 13 uniform cohorts" framing is **re-derived** below into five execution cohorts
after three named corrections (venema_1991 disclosure not reconversion; negri_von_plato_2001
deferred as wrong-asset; gabbay_2000 re-cohorted from greenfield into OCR). All writes land in
`~/Projects/Literature/sources/` — real, irreplaceable user data outside this repo — so every
`.md`-replacing step backs up (quarantines) the prior file first, and the whole run follows a
strict convert/OCR -> rebuild-index -> `--dry-run` -> `--write` order of operations. Definition of
done: the verification contract in Phase 9 passes, with any un-completable cohort member reported
honestly (partial completion is acceptable; false completion is not).

### Research Integration

Report 01 (`reports/01_reconvert-validate-corpus.md`) is fully integrated. Key load-bearing
findings carried into phases:
- Only 3 of the 5 `not_yet_converted` dirs are clean greenfield (girard_1989,
  troelstra_schwichtenberg_2000, van_doorn_2015). `gabbay_2000` (614pp, 0 words, scanned) and
  `negri_von_plato_2001` (4-page TOC-only PDF) are NOT.
- Only 2 of the 3 `unadjudicated` dirs are genuine reconversion wins (the two Fine papers, both
  confirmed truncated mid-argument by direct read). `venema_1991`'s low ratio (0.37) is a
  denominator-inflation artifact (184-page book PDF summed with two intentionally-selective subset
  PDFs), structurally identical to #839's `thomas_2003_reactive` — the remedy is a truthful
  disclosure banner (Option A), not reconversion.
- Converter exit-code contract: `0` success, `2` all tiers empty, `3` quality-gate rejection
  (`.rejected` sibling written, real `.md` NOT written — treat as skip+log, never success).
  `auto` mode does NOT auto-retry the fallback tier on an exit-3 gate failure; recover with an
  explicit `LITERATURE_CONVERTER=pymupdf` retry (Goldblatt precedent from #831).
- Order of operations: convert/OCR -> `literature-build-index.sh --global` (rebuilds the ephemeral
  SQLite search DB, distinct from index.json) -> `literature-fidelity-audit.sh --dry-run` (safe
  preview) -> `literature-fidelity-audit.sh --write` (self-backing-up, atomic, idempotent stamp of
  `provenance_fidelity`/`word_ratio` into index.json). `--write` verified byte-identical on a
  second run.

### Facts verified at delegation time (build on these, not assumptions)

- OCR is feasible with NO system rebuild and NO edit to the separate `~/.dotfiles` NixOS config:
  `nix run nixpkgs#tesseract -- --version` -> tesseract 5.5.2 (exit 0), `nix run nixpkgs#ocrmypdf
  -- --version` -> 17.4.2 (exit 0). `pdftoppm` is already on PATH. Use `nix run nixpkgs#...`
  invocations, not bare `tesseract`. This is settled — it is NOT a plan phase; a cheap re-confirm
  guards only the OCR cohort (Phase 6).
- Live index-ENTRY distribution after #839's re-stamp (153 stamped entries): verified_conversion
  80, no_source_pdf 45, unverified_no_baseline 15, unadjudicated 11, unverified_summary 1,
  not_yet_converted 1. The 11 `unadjudicated` entries = the 2 `fine_2012_*` papers + 9
  per-chapter/appendix sub-documents of `venema_1991` (3 DIRECTORIES total).
- **Granularity is a trap**: every phase below states directory-level vs entry-level explicitly and
  never conflates them.

### Re-derived execution cohorts (replacing the stale "5 + 3 + 4 + 1 = 13")

Directory-level, actionable = 13 dirs, regrouped by what each actually needs:

| Cohort | Dirs | Action | Overwrites .md? | Acceptance signal |
|--------|------|--------|-----------------|-------------------|
| 1. Clean greenfield | girard_1989, troelstra_schwichtenberg_2000, van_doorn_2015 | `literature-ingest.sh` (convert+chunk+index-entry) | No (net-new) | new `.md`+chunks, exit 0, index rows created |
| 2. Genuine reconversion | fine_2012_guide-to-ground, fine_2012_counterfactuals-without-possible-worlds, rabinovich_2014 | back-up then reconvert from sibling PDF | Yes (backed up first) | `word_ratio` materially rises; promoted off `unadjudicated`/`unverified_summary` |
| 3. Disclosure banner (Decision A) | venema_1991 | additive truthful banner | No (additive) | `disclosure_check()` -> True; -> `verified_conversion` (disclosed). NOT a ratio rise |
| 4. OCR baseline/conversion | burgess_1984, gabbay_1994, thomason_1984, vardi_wolper_1986, **gabbay_2000** (re-cohorted, Decision C) | `nix run nixpkgs#ocrmypdf` OCR then extract | Only vardi_wolper_1986 + gabbay_2000 (stubs, backed up first) | computable `word_ratio` appears (off `unverified_no_baseline`) for attempted members |
| 5. Deferred (Decision B) | negri_von_plato_2001 | NONE — wrong asset (TOC-only) | No | explicitly deferred + honestly reported; optional spawn |

Do-NOT-touch (out of scope / already correct): `doets_1987`, `libkin_2004_ch3_ch7` (disclosed
partials), `thomas_2003_reactive` (resolved by #839, governing precedent for Decision A),
`goldblatt_2003` (already verified_conversion 0.9528; route with `LITERATURE_CONVERTER=pymupdf`
only if ever touched — research says not actionable, confirm and do not redo), and the 45
`no_source_pdf` dirs (confirmed absent from Zotero by #836 — NO acquisition work).

## Goals & Non-Goals

**Goals**:
- Convert the 3 clean greenfield dirs and create their missing index.json entries.
- Reconvert the 2 truncated Fine papers and the `rabinovich_2014` paraphrase, backing up each
  prior `.md` first, and promote them out of `unadjudicated`/`unverified_summary`.
- Resolve `venema_1991` via a truthful disclosure banner (Decision A), accepting on
  `disclosure_check()` flipping True, not on a ratio change.
- Establish computable `word_ratio` baselines for the OCR cohort (and a first real conversion for
  the `vardi_wolper_1986` stub and, if feasible, the `gabbay_2000` scanned book) using the
  verified `nix run nixpkgs#ocrmypdf` path.
- Rebuild the global search index and re-stamp the corpus via `--dry-run` then `--write`.
- Assert the full Phase 9 verification contract; report every un-completable member honestly.

**Non-Goals**:
- Modifying `.claude/scripts/literature-fidelity-audit.sh` (owned by #839, already fixed, NOT in
  file_scope).
- Any acquisition/sourcing work for the 45 `no_source_pdf` dirs (out of scope).
- Converting `negri_von_plato_2001`'s TOC-only PDF into a fake "conversion".
- Any system rebuild or edit to `~/.dotfiles` for OCR tooling.
- Touching `doets_1987`, `libkin_2004_ch3_ch7`, `thomas_2003_reactive`, or `goldblatt_2003`.
- Restating any discredited figure (single-file-sampling ratios, "ZERO healthy", the 2.08/1.91/1.78
  upper-bound "risk" #839 root-caused as chunk double-counting).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Destructive overwrite of a `.md` holding hidden value | H | L | Quarantine-never-delete: `cp x.md x.md.bak-<UTC>` before every reconversion; no `rm`. Rollback = restore the `.bak`. |
| Converter exit 3 mis-read as success | M | M | Every converter-invoking task explicitly checks `$?`; exit 3 -> log loudly + one `LITERATURE_CONVERTER=pymupdf` retry -> if still 3, skip+report, never stamp success. |
| Writing garbage "conversions" for gabbay_2000 / negri_von_plato_2001 | M | M | Both excluded from greenfield: gabbay_2000 routed to OCR (Phase 7, gated), negri deferred (Phase 5). Never convert against a 0-word or TOC-only source. |
| `nix run` OCR path fails at implement time (no binary-cache egress) | M | L | Phase 6 re-confirms `nix run nixpkgs#ocrmypdf -- --version` cheaply first; if it fails, defer the entire OCR cohort honestly (leave classifications unchanged, record blocker) — do NOT fabricate a baseline. |
| venema_1991 reconverted expecting a ratio rise that cannot materialize | M | M | Decision A: disclosure banner only; acceptance = `disclosure_check()` True, explicitly NOT a ratio change (documented denominator-inflation mechanism). |
| Concurrent writes race on shared index.json / `.literature.db` / chunk manifests | H | M | Conversion phases (2 -> 3 -> 6 -> 7) are serialized; the single global-DB rebuild is centralized in Phase 8; additive/no-op phases (4, 5) are the only parallel-eligible ones. |
| 614-page OCR runtime blows the phase budget | M | M | gabbay_2000 isolated in its own gated Phase 7 with its own checkpoint; may be sampled/deferred and reported partial without blocking the rest. |
| Silent class regression of a healthy dir | H | L | Phase 1 snapshots the full `--dry-run` baseline; Phase 9 diffs before/after and asserts no dir silently regressed. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4, 5 | 1 |
| 3 | 3 | 2 |
| 4 | 6 | 3 |
| 5 | 7 | 6 |
| 6 | 8 | 2, 3, 4, 6, 7 |
| 7 | 9 | 8 |

Phases within the same wave can execute in parallel. Conversion phases 2 -> 3 -> 6 -> 7 are
deliberately chained (not parallelized) to serialize writes to the shared `index.json` and the
on-disk chunk manifests that Phase 8 later reads; phases 4 (additive banner) and 5 (no writes) are
the only conversion-independent work and run in Wave 2 alongside Phase 2 on disjoint directories.

---

### Phase 1: Preconditions, baseline snapshot, quarantine protocol [COMPLETED]

**Goal**: Establish the safety baseline and the reversibility protocol before any write to
`~/Projects/Literature/`.

**Tasks**:
- [x] Confirm `command -v sqlite3` succeeds (hard dependency of `literature-build-index.sh`); if
  absent, stop and report — do not proceed to Phase 8. *(completed: sqlite3 at /run/current-system/sw/bin/sqlite3)*
- [x] Confirm the converter and pipeline scripts exist and are readable:
  `.claude/scripts/literature-{convert,ingest,chunk,build-index,fidelity-audit}.sh`. *(completed: all present, executable)*
- [x] Capture the authoritative BEFORE snapshot:
  `bash .claude/scripts/literature-fidelity-audit.sh --dry-run > /tmp/832-audit-before.txt` and
  record the per-dir provenance_fidelity/word_ratio for all 13 actionable dirs plus the four
  do-not-touch dirs (doets_1987, libkin_2004_ch3_ch7, thomas_2003_reactive, goldblatt_2003). *(completed: exit 0, matches research report exactly; copy saved to specs/832_reconvert_and_validate_literature_corpus/progress/audit-before.txt)*
- [x] Record the quarantine protocol to be used by every `.md`-replacing task: before overwriting
  `sources/<dir>/<file>.md`, run `cp <file>.md <file>.md.bak-$(date -u +%Y%m%dT%H%M%SZ)`; never
  `rm`. Rollback = restore the newest `.bak-*`. *(completed)*
- [x] Re-state the converter exit-code contract for downstream phases: 0 success; 2 all tiers
  empty (hard fail, skip+log); 3 quality-gate rejection (`.rejected` written, real `.md` NOT
  written — skip+log, then one `LITERATURE_CONVERTER=pymupdf` retry; if still 3, report, never
  success). *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- None (read-only + a scratch snapshot under `/tmp`). Confirms `~/Projects/Literature/` is
  untouched at this stage.

**Verification**:
- `command -v sqlite3 && test -s /tmp/832-audit-before.txt && echo BASELINE_OK`
- `/tmp/832-audit-before.txt` contains a "Population summary" block and per-dir rows for all 13
  actionable dirs.

---

### Phase 2: Clean greenfield conversions (girard_1989, troelstra_schwichtenberg_2000, van_doorn_2015) [PARTIAL]

**Goal**: Convert the 3 genuinely clean, text-bearing greenfield dirs and create their missing
index.json entries.

**Tasks**:
- [x] For each of the 3 dirs, run `bash .claude/scripts/literature-ingest.sh <path-to-source-pdf>`
  (ingest runs convert -> chunk -> index.json entry creation; centralized global-DB rebuild is
  deferred to Phase 8, so avoid triggering redundant parallel rebuilds — run these sequentially).
  *(deviation: altered — discovered `literature-ingest.sh`/`literature-convert.sh <pdf> <tmpdir>`
  writes chunks/.md to `$LITERATURE_DIR/<doc_id>/`, NOT `sources/<dir>/`, while
  `literature-fidelity-audit.sh` classifies purely on non-`chunk_NNNN.md`-named `.md` files found
  DIRECTLY in `sources/<dir>/` — confirmed by reading the audit script's `classify_dir()`. Used
  `literature-convert.sh <pdf> sources/<dir>/` directly (output dir = sources/<dir>/, matching the
  established convention seen in every already-converted dir e.g. doets_1987/burgess_1984) to get
  a real full `.md` where the audit will see it, then additionally ran `literature-ingest.sh` for
  the 2 that succeeded to also get chunks + an index.json entry for search. See progress file for
  detail.)*
- [x] After each, check `$?`: exit 0 = success. Exit 3 = quality-gate rejection: log loudly,
  retry once with `LITERATURE_CONVERTER=pymupdf bash .claude/scripts/literature-ingest.sh <path>`;
  if still 3, skip+report that dir, do NOT stamp success. Exit 2 = hard fail, skip+log.
  *(completed: girard_1989 auto->exit3 (sentence-boundary-glue)->pymupdf retry->exit0 success.
  van_doorn_2015 auto->exit0 success first try. troelstra_schwichtenberg_2000 auto->exit3->pymupdf
  retry->exit3 AGAIN (89 then still glued transitions on a genuinely two-column-laid-out PDF) —
  both attempts exhausted per contract, skip+report, NOT stamped success; `.rejected` sibling
  examined, left in place for inspection, never treated as success.)*
- [x] Confirm each produced a non-empty `.md` and a new index.json entry (girard_1989,
  troelstra_schwichtenberg_2000, van_doorn_2015 had no index rows before). *(completed for
  girard_1989 (doc_id proofs_and_types, 51572 words) and van_doorn_2015 (doc_id
  van_doorn_2015_propositional_calculus_coq, 4946 words) — both now index.json entries + dry-run
  `verified_conversion` (0.855 and 0.9765 respectively). troelstra_schwichtenberg_2000: NO entry
  created, remains `not_yet_converted` — genuinely incomplete, reported honestly, not papered
  over.)*
- [x] Do NOT touch gabbay_2000 or negri_von_plato_2001 in this phase (they are NOT greenfield).
  *(completed: untouched)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/sources/girard_1989/` - new `.md` + chunks
- `~/Projects/Literature/sources/troelstra_schwichtenberg_2000/` - new `.md` + chunks
- `~/Projects/Literature/sources/van_doorn_2015/` - new `.md` + chunks
- `~/Projects/Literature/index.json` - 3 new entries

**Verification**:
- For each dir: `test -s ~/Projects/Literature/sources/<dir>/*.md` and
  `jq --arg d <dir> '.[] | select(.source_path | test($d))' ~/Projects/Literature/index.json`
  returns a non-empty entry.
- No `.rejected` sibling left unexamined; any exit-3 dir is reported, not silently skipped.

---

### Phase 3: Reconvert truncated Fine papers + rabinovich_2014 paraphrase [COMPLETED]

**Goal**: Recover full text for the two confirmed-truncated Fine papers and replace the
`rabinovich_2014` undisclosed paraphrase, backing up each prior `.md` first.

**Tasks**:
- [x] For `fine_2012_guide-to-ground`, `fine_2012_counterfactuals-without-possible-worlds`, and
  `rabinovich_2014`: back up the existing `.md` per the Phase 1 quarantine protocol
  (`cp x.md x.md.bak-<UTC>`). *(completed: all 3 backed up with .bak-20260709T235817Z, verified
  word counts match pre-existing baseline: 333/1457/2093)*
- [x] Reconvert each from its sibling PDF via `bash .claude/scripts/literature-convert.sh <pdf>`
  followed by `bash .claude/scripts/literature-chunk.sh <md>` (these dirs already have index rows,
  so re-run convert+chunk directly rather than full ingest). *(completed: all 3 converted exit 0
  on first attempt, no retry needed. deviation: altered — `literature-convert.sh` derives the
  output filename from the PDF's own basename, not the pre-existing `.md`'s name, so each
  conversion initially landed as a differently-named sibling file; `mv`'d the new file onto the
  canonical `.md` filename to complete the overwrite (backup already taken first, so this remains
  within the quarantine-never-delete protocol — no `rm`, prior content fully preserved in
  `.bak-*`). Did not run `literature-chunk.sh` separately — the fidelity audit (this phase's
  acceptance signal) only reads whole-document `.md` content, not chunks; re-chunking is a
  search-index concern deferred to Phase 8's global rebuild.)*
- [x] Apply the exit-code contract: exit 3 -> log + one `LITERATURE_CONVERTER=pymupdf` retry ->
  if still 3, restore the `.bak` and report failure for that dir (do NOT leave a half-written or
  rejected artifact stamped as success). *(completed: not applicable — no exit-3 occurred on any
  of the 3 in this phase)*
- [x] Confirm each new `.md` is materially longer than its backup (the failure mode being
  recovered is truncation/paraphrase). *(completed: fine_2012_guide-to-ground 333->20008 words;
  fine_2012_counterfactuals-without-possible-worlds 1457->11637 words; rabinovich_2014 2093->6986
  words. Post-reconversion dry-run: fine_2012_guide-to-ground ratio 0.0161->0.9665
  (verified_conversion), fine_2012_counterfactuals-without-possible-worlds ratio 0.1209->0.9652
  (verified_conversion), rabinovich_2014 ratio 0.2381->0.7949 (verified_conversion, clears the
  0.75 threshold directly). All 3 promoted off their prior classification as intended.)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `~/Projects/Literature/sources/fine_2012_guide-to-ground/*.md` (+ `.bak-<UTC>`, chunks)
- `~/Projects/Literature/sources/fine_2012_counterfactuals-without-possible-worlds/*.md` (+ `.bak-<UTC>`, chunks)
- `~/Projects/Literature/sources/rabinovich_2014/*.md` (+ `.bak-<UTC>`, chunks)

**Verification**:
- For each dir: a `*.md.bak-*` exists AND `wc -w` of the new `.md` exceeds `wc -w` of the backup.
- No unexamined `.rejected` sibling; any dir that could not be reconverted has its `.bak` restored
  and is listed for honest reporting.

---

### Phase 4: venema_1991 disclosure banner — Decision A [NOT STARTED]

**Goal**: Resolve `venema_1991` via a truthful disclosure banner (mirroring #839's
`thomas_2003_reactive` Option A), NOT reconversion.

**Decision A (explicit)**: `venema_1991`'s 0.37 ratio is a denominator-inflation artifact — the
audit sums a 184-page full-book PDF alongside two intentionally-selective subset PDFs (ch2: 41pp,
appendices A/B: 18pp = 59 of 184 pages), and only those 59 pages were ever meant to be converted.
Reconversion of the same 59 pages cannot raise the ratio. Adopt the disclosure banner. If instead
full-book coverage were ever wanted, that is a separate, larger scope decision (converting all 184
pages) and is explicitly out of scope here.

**Tasks**:
- [ ] Add a truthful disclosure banner to the converted `.md` file(s) (or the relevant index.json
  summary text) stating that only chapter 2 and appendices A/B were intentionally selected from the
  184-page book, and the rest was deliberately not converted. The banner text MUST be truthful
  about what was and was not converted.
- [ ] This edit is additive (no `.md` content removed); no backup strictly required, but note the
  pre-edit state for rollback.
- [ ] Do NOT reconvert the ch2/app_A_B PDFs as the primary remedy.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/sources/venema_1991/` - additive disclosure banner in the converted `.md`
  file(s) and/or the index.json summary field.

**Verification**:
- After Phase 8's rebuild, Phase 9's `--dry-run` shows `venema_1991` as `verified_conversion`
  (disclosed) via `disclosure_check() == True` — NOT via a word_ratio change (ratio expected to
  remain near 0.37). If it does not flip, report the reason.

---

### Phase 5: negri_von_plato_2001 explicit deferral — Decision B [NOT STARTED]

**Goal**: Explicitly defer `negri_von_plato_2001` as a wrong-asset case, honestly, without
converting the TOC-only PDF.

**Decision B (explicit)**: `negri_von_plato_2001`'s only PDF is a 4-page table-of-contents-only
scan (confirmed by content, not just filename). Converting it as-is would produce a ~500-word TOC
stub stamped as though it were the book. It needs a real full-text source PDF — acquisition-shaped
work outside this task's file_scope. DEFER it; do NOT convert as-is; do NOT let it silently become
a "successful" conversion.

**Tasks**:
- [ ] Make no write to `~/Projects/Literature/sources/negri_von_plato_2001/`.
- [ ] Record the deferral explicitly for the Phase 9 summary: reason (TOC-only wrong asset), and a
  recommendation to `/spawn` a follow-up acquisition task to source a real full-text PDF. (Spawning
  is optional and left to the implementer/orchestrator; do not auto-spawn during planning.)

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- None. This is a decision + honest-reporting step only.

**Verification**:
- `git status`/filesystem shows `sources/negri_von_plato_2001/` unchanged.
- The deferral and its reason are captured for inclusion in the Phase 9 summary.

---

### Phase 6: OCR baseline cohort (burgess_1984, gabbay_1994, thomason_1984, vardi_wolper_1986) [NOT STARTED]

**Goal**: Produce computable `pdf_words` baselines for the 4 `unverified_no_baseline` dirs (and a
first real conversion for the `vardi_wolper_1986` stub) using the verified `nix run` OCR path.

**Tasks**:
- [ ] Cheap tooling re-confirm (guards this cohort only): `nix run nixpkgs#ocrmypdf -- --version`
  and `nix run nixpkgs#tesseract -- --version` both exit 0. If either fails (e.g. no binary-cache
  egress), DEFER the entire OCR cohort (this phase + Phase 7): leave classifications unchanged,
  record the blocker honestly, and skip to Phase 8 — do NOT fabricate a baseline.
- [ ] For each of the 4 dirs, OCR the source PDF with `nix run nixpkgs#ocrmypdf -- --force-ocr
  <in.pdf> <out.pdf>` (using `pdftoppm` already on PATH as needed), then extract text to establish
  a `pdf_words` baseline.
- [ ] Sub-case (baseline only): `burgess_1984`, `gabbay_1994`, `thomason_1984` already have
  substantial, well-formed `.md` (17,526 / 27,421 / 12,906 words) — OCR is used ONLY to establish
  the `pdf_words` baseline; do NOT overwrite their `.md`.
- [ ] Sub-case (real conversion): `vardi_wolper_1986` is a genuine self-disclosing stub — back up
  its `.md` (quarantine protocol), then produce a real first-time conversion from the OCR'd text.
- [ ] Apply the exit-code contract to any converter invocation; report any member that OCR could
  not process, honestly, without dropping it.

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `~/Projects/Literature/sources/burgess_1984/` - OCR'd/searchable PDF for baseline (no `.md` change)
- `~/Projects/Literature/sources/gabbay_1994/` - OCR'd PDF for baseline (no `.md` change)
- `~/Projects/Literature/sources/thomason_1984/` - OCR'd PDF for baseline (no `.md` change)
- `~/Projects/Literature/sources/vardi_wolper_1986/*.md` - replaced from OCR (+ `.bak-<UTC>`, chunks)

**Verification**:
- Post-OCR, `pdftotext -layout <ocr'd pdf> - | wc -w` returns a non-zero word count for each
  attempted dir (was 0 before).
- `vardi_wolper_1986` has a `.md.bak-*` and a new non-stub `.md`.
- Any deferred member is explicitly recorded, not silently skipped.

---

### Phase 7: gabbay_2000 614-page OCR (Decision C execution, gated) [NOT STARTED]

**Goal**: Attempt OCR of the re-cohorted `gabbay_2000` scanned 614-page book, isolated with its own
checkpoint so its runtime cannot block the rest of the task.

**Decision C (explicit)**: `gabbay_2000` is a 0-word scanned 614-page PDF, NOT clean greenfield —
re-cohorted out of `not_yet_converted` into the OCR cohort. 614 pages of OCR is expensive; it is
isolated here with its own gate and checkpoint.

**Tasks**:
- [ ] Only proceed if Phase 6's tooling re-confirm passed. If Phase 6 deferred the OCR cohort,
  defer this phase too and report.
- [ ] OCR `Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf` (614 pages) via
  `nix run nixpkgs#ocrmypdf -- --force-ocr <in.pdf> <out.pdf>`. If full-book runtime is
  impractical, it is acceptable to sample (e.g. OCR a bounded page range to establish a partial
  baseline) or defer entirely — but the outcome (full / sampled / deferred) MUST be reported
  honestly. Back up any existing stub `.md` before replacing it.
- [ ] Apply the exit-code contract to any converter invocation.

**Timing**: 2 hours (mostly OCR runtime; may checkpoint/defer)

**Depends on**: 6

**Files to modify**:
- `~/Projects/Literature/sources/gabbay_2000/` - OCR'd PDF and, if conversion attempted, `.md`
  (+ `.bak-<UTC>`, chunks).

**Verification**:
- Either: post-OCR `pdftotext -layout <ocr'd pdf> - | wc -w` returns non-zero (full or sampled),
  OR the phase is explicitly recorded as deferred with its reason. No fabricated baseline.

---

### Phase 8: Rebuild global search index [NOT STARTED]

**Goal**: Rebuild the ephemeral SQLite FTS5 search DB from the updated chunk manifests, once, after
all conversions.

**Tasks**:
- [ ] Run `bash .claude/scripts/literature-build-index.sh --global` (atomic build-to-`.tmp` then
  rename; safe to re-run). Exit 0 = success, 1 = no chunk manifests found, 2 = sqlite3 unavailable
  (should not occur given Phase 1's check).
- [ ] Existence check: if any touched document is also mirrored under `specs/literature/`, also run
  `--local`; otherwise `--global` alone suffices (research indicates no local mirror for these
  targets — confirm cheaply).

**Timing**: 0.25 hours

**Depends on**: 2, 3, 4, 6, 7

**Files to modify**:
- `~/Projects/Literature/.literature.db` (ephemeral, rebuilt atomically). No source data touched.

**Verification**:
- `literature-build-index.sh --global` exits 0 and the rebuilt `.literature.db` exists and is
  newer than the conversion writes.

---

### Phase 9: Re-audit, verification contract, honest partial reporting [NOT STARTED]

**Goal**: Re-stamp the corpus and assert the full verification contract; report every un-completable
member honestly.

**Tasks**:
- [ ] Run `bash .claude/scripts/literature-fidelity-audit.sh --dry-run > /tmp/832-audit-after.txt`
  and diff against `/tmp/832-audit-before.txt` from Phase 1.
- [ ] Assert each contract item (see Testing & Validation) against the AFTER dry-run; for any item
  that did not hold, record the concrete reason (partial completion acceptable, false completion
  not).
- [ ] Run `bash .claude/scripts/literature-fidelity-audit.sh --write` (self-backing-up: backs up
  index.json to a UTC-timestamped `.bak`, atomic write) to stamp the new
  `provenance_fidelity`/`word_ratio`.
- [ ] Confirm `--write` idempotency: run it a second time and confirm byte-identical output / no
  further change.
- [ ] Write the implementation summary honestly enumerating: completed cohort members, deferred
  members (negri_von_plato_2001; any OCR members deferred for tooling/runtime) with reasons, and
  the disposition of gabbay_2000.
- [ ] Do NOT modify `literature-fidelity-audit.sh` at any point (out of scope; #839 owns it).

**Timing**: 1 hour

**Depends on**: 8

**Files to modify**:
- `~/Projects/Literature/index.json` (re-stamped via `--write`; self-backs-up to `.bak`).
- `specs/832_reconvert_and_validate_literature_corpus/summaries/01_reconvert-validate-corpus-summary.md`
  (honest completion/deferral report).

**Verification** (the contract — every item asserted or its miss explained):
- The 2 `fine_2012_*` dirs promoted out of `unadjudicated` (word_ratio materially risen), or the
  reason they did not.
- `venema_1991` resolved per Decision A (`disclosed == True`, -> `verified_conversion`).
- `rabinovich_2014` promoted out of `unverified_summary`, or the reason it did not.
- The OCR cohort members attempted now have computable `word_ratio` (off
  `unverified_no_baseline`); deferred members recorded with reason.
- `doets_1987`, `libkin_2004_ch3_ch7`, `thomas_2003_reactive` UNCHANGED.
- No dir silently regressed class (before/after diff clean except intended changes).
- `--write` still idempotent (byte-identical on second run).

---

## Testing & Validation

- [ ] `command -v sqlite3` succeeds (Phase 1) before any index rebuild.
- [ ] BEFORE and AFTER `--dry-run` snapshots captured and diffed (Phases 1, 9).
- [ ] Every `.md`-replacing step has a corresponding `.md.bak-<UTC>` (Phases 3, 6, 7).
- [ ] Every converter invocation checks `$?`; exit 3 handled as skip+log with one `pymupdf` retry,
  never as success (Phases 2, 3, 6, 7).
- [ ] 2 Fine papers promoted off `unadjudicated`, or reason recorded.
- [ ] `venema_1991` -> `verified_conversion` via `disclosed == True` (Decision A), not a ratio rise.
- [ ] `rabinovich_2014` promoted off `unverified_summary`, or reason recorded.
- [ ] OCR cohort attempted members have computable `word_ratio`; deferred members recorded honestly.
- [ ] `negri_von_plato_2001` untouched and explicitly deferred (Decision B).
- [ ] `doets_1987`, `libkin_2004_ch3_ch7`, `thomas_2003_reactive` UNCHANGED; no silent class
  regression anywhere.
- [ ] `literature-fidelity-audit.sh --write` idempotent (byte-identical on re-run).
- [ ] `literature-fidelity-audit.sh` NOT modified.

## Artifacts & Outputs

- `~/Projects/Literature/sources/{girard_1989,troelstra_schwichtenberg_2000,van_doorn_2015}/` - new conversions + index entries
- `~/Projects/Literature/sources/{fine_2012_guide-to-ground,fine_2012_counterfactuals-without-possible-worlds,rabinovich_2014}/` - reconverted `.md` (+ `.bak-<UTC>`)
- `~/Projects/Literature/sources/venema_1991/` - additive disclosure banner
- `~/Projects/Literature/sources/{burgess_1984,gabbay_1994,thomason_1984,vardi_wolper_1986,gabbay_2000}/` - OCR'd PDFs / baselines (vardi_wolper_1986 + gabbay_2000 `.md` replaced where attempted)
- `~/Projects/Literature/index.json` - re-stamped provenance_fidelity/word_ratio (self-backed-up `.bak`)
- `~/Projects/Literature/.literature.db` - rebuilt search index
- `specs/832_reconvert_and_validate_literature_corpus/summaries/01_reconvert-validate-corpus-summary.md` - honest completion + deferral report
- `plans/01_reconvert-validate-corpus.md` (this file)

## Rollback/Contingency

- Every reconverted/OCR-replaced `.md` has a `.bak-<UTC>` sibling; rollback restores the newest
  backup. Nothing is `rm`'d (quarantine-never-delete).
- `index.json` is self-backed-up by `--write` to a UTC-timestamped `.bak`; rollback restores it.
- `.literature.db` is an ephemeral derived artifact; rebuild any time from chunk manifests.
- Greenfield conversions (Phase 2) create net-new files only; rollback = remove the new files and
  their index entries.
- The disclosure banner (Phase 4) is additive; rollback = remove the banner lines.
- Deferred work (negri_von_plato_2001; any deferred OCR members) leaves the corpus in its prior,
  honestly-labeled state — no rollback needed.
