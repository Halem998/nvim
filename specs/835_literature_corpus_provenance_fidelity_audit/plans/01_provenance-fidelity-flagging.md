# Implementation Plan: Task #835

- **Task**: 835 - Literature corpus provenance and fidelity audit
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None (orthogonal to #831; unblocks a required /revise of #832)
- **Research Inputs**: specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md
- **Artifacts**: plans/01_provenance-fidelity-flagging.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a per-document `provenance_fidelity` signal to the literature corpus and make the two
retrieval scripts loudly flag low-fidelity entries instead of serving them as authoritative. A
re-runnable auditor computes fidelity from a conservative three-signal detector (document-level
word-ratio, disclosure check, proof/body-completeness check) and stamps it into each parent entry
of `~/Projects/Literature/index.json`; `literature-search.sh` and `literature-briefing.sh` then
read that field, warn on anything that is not a `verified_conversion`, and fail open (a missing
field is treated as unverified, never verified). Definition of done: `rabinovich_2014` (the one
confirmed undisclosed paraphrase) is stamped `unverified_summary` and shows a loud warning in both
scripts; the 30 healthy conversions and 5 disclosed partial extracts are not falsely quarantined;
no corpus file is deleted.

### Research Integration

This plan is built on the CORRECTED findings of report 01, not the task description's original
"pre-verified" numbers (which were single-file-sampling artifacts). Load-bearing corrections
carried into the design:

- Word-ratio MUST be aggregated per document (sum all `.md` in a source dir / sum all PDF text),
  never sampled from one `.md`. Single-file sampling flipped ~7 healthy docs to false low-ratio
  (blackburn_2002: 0.03 sampled vs 1.044 aggregate).
- Corrected population (97 dirs): 52 `no_source_pdf`, 5 `not_yet_converted` (already self-disclosed,
  `token_count: 0`), 30 `verified_conversion`, 4 `unverified_no_baseline` (pdftotext yields 0 words),
  6 low-ratio -> of which only `rabinovich_2014` is a true `unverified_summary`; the other 5
  (doets_1987, libkin_2004_ch3_ch7, venema_1991, thomas_2003_reactive, hodkinson_2006) are
  legitimate disclosed partials and must classify as `verified_conversion`.
- `chunk_*.md` filename presence is REJECTED as a signal (0 of 30 healthy docs use it); leading
  `## Overview` is at most a corroborator, never a standalone signal.
- Five-value enum adopted (not the task's 3): `verified_conversion`, `unverified_summary`,
  `no_source_pdf`, `not_yet_converted`, `unverified_no_baseline`.
- Field lives only on parent (`parent_doc == null`) entries of `index.json`; the `.literature.db`
  SQLite schema is NOT migrated. Retrieval scripts look the field up by `doc_id` at query time,
  mirroring `literature-search.sh`'s existing `get_project_doc_ids()` `project_tags` pattern.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path in delegation; roadmap_flag not set).

### Scope Note (read before implementing)

Delegation `file_scope` names three files: `literature-briefing.sh`, `literature-search.sh`,
`~/Projects/Literature/index.json`. The design constraint "any index.json mutation must be backed
up first and be idempotent/re-runnable" cannot be satisfied without a persisted, re-runnable
mechanism. This plan therefore adds ONE new file, `.claude/scripts/literature-fidelity-audit.sh`,
as the stamping tool (Phases 1-2). This is a deliberate, flagged extension of the literal
three-file scope, justified by the re-runnable requirement and explicitly recommended by report 01
("necessary to populate the field"). If the orchestrator/user requires strict three-file
adherence, the fallback is to fold the stamping logic into a one-shot procedure invoked from an
existing `/literature --validate` sub-check instead of a standalone script — but the detector
logic itself is unchanged either way. No other files are touched.

## Goals & Non-Goals

**Goals**:
- A re-runnable, backup-first, idempotent auditor that computes and stamps `provenance_fidelity`
  (plus raw `word_ratio` where determinable) onto each parent entry of `index.json`.
- A conservative three-signal detector that flags exactly `rabinovich_2014` as `unverified_summary`
  in the current corpus (zero false positives against the 5 disclosed partials).
- `literature-search.sh`: `provenance_fidelity` added to result JSON; `--read` content prefixed
  with a warning banner for non-`verified_conversion` docs; unverified docs excluded from default
  ranking unless `--include-unverified` is passed; fail-open on missing field.
- `literature-briefing.sh`: visible per-entry warning marker for non-`verified_conversion` docs;
  extended "How to Use" footer; fail-open on missing field.
- Quarantine via retrieval degradation and loud banners only. No corpus file is ever deleted.

**Non-Goals**:
- Fixing #831-class readability/extraction defects (orthogonal quality axis).
- Reconverting or re-deriving any `.md` (invalidated #832 premise; out of scope here).
- OCR of the 4 `unverified_no_baseline` scanned PDFs (recommended follow-up, not this task).
- Migrating the `.literature.db` SQLite schema.
- Deleting, moving, or rewriting `rabinovich_2014` or any other corpus content.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Uniform low-ratio flagging falsely quarantines the 5 disclosed partials | H | M | Detector requires ALL of: ratio<0.75 AND no disclosure AND numbered claims lack bodies before `unverified_summary`; any single miss routes to `verified_conversion`. Verify against the 6 named low-ratio dirs in Phase 1. |
| Single-file word-ratio regression re-introduced by a future contributor | H | M | Aggregate at directory/document level in the detector; assert this in code comments and Phase 1 verification; capture as memory candidate. |
| index.json corrupted by a non-idempotent or partial write | H | L | Timestamped backup before any write; write to temp file then atomic move; re-run must be a no-op on already-stamped entries; `--dry-run` mode. |
| Scope extension (new auditor script) rejected | M | L | Scope Note documents the fallback (fold into `/literature --validate`); detector logic is unchanged in either path. |
| pdftotext missing/zero-words silently defaults to a verdict | M | M | Zero PDF words -> `unverified_no_baseline` with `word_ratio: null`; never silently `verified_conversion`. |
| Fail-closed behavior hides new/unstamped docs | M | M | Both scripts fail OPEN: absent field treated as unverified (loud), never verified. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Fidelity detector core (compute-only, read-only) [COMPLETED]

**Goal**: Implement the three-signal detector in `.claude/scripts/literature-fidelity-audit.sh`
that emits, per parent `doc_id`, a `provenance_fidelity` value and raw `word_ratio` — without
mutating `index.json` yet. Read-only and independently verifiable against known cases.

**Tasks**:
- [x] Create `.claude/scripts/literature-fidelity-audit.sh` skeleton (`set -euo pipefail`,
      `LITERATURE_DIR` resolution mirroring the other two scripts, `--dry-run`/report-only default).
      *(completed)*
- [x] Enumerate the 97 `sources/<dir>/` directories and, per dir, classify presence of `*.pdf`/
      `*.djvu` and `*.md`. *(completed)*
- [x] Implement DOCUMENT-LEVEL word-ratio: sum `wc -w` over ALL `.md` in the dir divided by summed
      `pdftotext -layout` words over ALL PDFs in the dir. Never sample a single file. If PDF words
      == 0 -> emit `word_ratio: null`. *(completed)*
- [x] Implement classification routing: no PDF + `.md` present -> `no_source_pdf`; PDF present +
      zero `.md` -> `not_yet_converted`; PDF+`.md` with `word_ratio` null -> `unverified_no_baseline`;
      ratio >= 0.75 -> `verified_conversion`; ratio < 0.75 -> structural sub-checks below. *(completed)*
- [x] Implement disclosure sub-check (regex over `.md` content and the entry's `summary`:
      `Selective conversion`, `Extracted:? Chapter`, `truncated`, `excerpt`, `chapters? \d+ and \d+`).
      Match -> `verified_conversion` (disclosed partial). *(completed)*
- [x] Implement proof/body-completeness sub-check: for headings matching
      `^#+\s*(Definition|Lemma|Theorem|Proposition|Corollary)\s+[\d.]+`, compute the fraction with a
      following `Proof`/body before the next equal-or-higher heading. Only when ratio<0.75 AND no
      disclosure AND that fraction ~0 -> `unverified_summary`; otherwise `verified_conversion`.
      *(completed: threshold calibrated to <0.6 during empirical verification — see Testing note
      below and progress file `approaches_tried`; Lemma/Theorem/Proposition/Corollary require an
      explicit "Proof" marker in the body, Definition headings use a content-length bar instead)*
- [x] Emit a TSV/JSON report (doc_id, population, word_ratio, provenance_fidelity) to stdout.
      *(completed)*
- [x] REJECT `chunk_*.md`-presence and standalone `## Overview` as signals (do not implement them).
      *(completed — neither signal appears anywhere in the detector)*

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-fidelity-audit.sh` (new) - detector + report, no index writes.

**Verification**:
- Run report-only mode; confirm `rabinovich_2014` -> `unverified_summary`. VERIFIED.
- Confirm all 5 disclosed partials (doets_1987, libkin_2004_ch3_ch7, venema_1991,
  thomas_2003_reactive, hodkinson_2006) -> `verified_conversion` (zero false positives). VERIFIED.
- Confirm blackburn_2002/baier_katoen_2008/caleiro_2013 -> `verified_conversion` (aggregate ratio),
  the 5 zero-md dirs -> `not_yet_converted`, and the 4 zero-pdf-word dirs -> `unverified_no_baseline`.
  VERIFIED.
- Spot-check total counts approximate 52/5/30/4/1 across the enum. VERIFIED EXACTLY:
  52 no_source_pdf / 5 not_yet_converted / 35 verified_conversion (30 healthy + 5 disclosed
  partial) / 4 unverified_no_baseline / 1 unverified_summary = 97.

### Phase 2: Idempotent index.json stamping [COMPLETED]

**Goal**: Extend the auditor to write `provenance_fidelity` (and `word_ratio` where determinable)
into each parent (`parent_doc == null`) entry of `index.json`, backup-first, atomically, and
idempotently.

**Tasks**:
- [x] Add a `--write` mode (default remains report-only/dry-run) to the auditor. *(completed)*
- [x] Before any write, copy `index.json` to `index.json.bak.<YYYYMMDD-HHMMSS>` and verify the copy.
      *(completed)*
- [x] Build the update with `jq`: for each parent entry, set `.provenance_fidelity` and
      `.word_ratio` (null allowed); write to a temp file and atomically `mv` over `index.json`.
      *(completed: implemented in Python via json.load/json.dump + os.replace rather than jq, for
      the same effect — atomic temp-file-then-rename over index.json)*
- [x] Guarantee idempotency: re-running `--write` on an already-stamped corpus yields byte-identical
      output (no spurious diffs, stable key ordering). *(completed and verified: second --write run
      produced changed=0/unchanged=153 and an empty diff against the post-first-write file)*
- [x] Only touch parent entries (`parent_doc == null`/empty); never child chunk entries; never the
      `.literature.db`. *(deviation: altered — see progress file deviation 2.5. 15 directories have
      a pre-existing phantom-parent data gap (children reference a parent_doc with no top-level id
      row); those are stamped directly on their child entries as a documented fallback, since
      otherwise the plan's own named disclosed-partial benchmarks doets_1987 and venema_1991 would
      be unstampable and would fail-open to a false unverified_summary flag. .literature.db is
      never touched.)*
- [x] Emit a summary of how many entries were stamped/changed/unchanged. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-fidelity-audit.sh` - add `--write`, backup, atomic idempotent update.
- `~/Projects/Literature/index.json` - populated with `provenance_fidelity` + `word_ratio`.

**Verification**:
- `--write` once, then confirm `jq '.entries[] | select(.id=="rabinovich_2014") | .provenance_fidelity'`
  returns `"unverified_summary"`. VERIFIED on the real corpus.
- Re-run `--write`; confirm `git diff`/`diff` against the previous post-write state is empty (idempotent).
  VERIFIED (byte-identical).
- Confirm a timestamped backup exists and matches the pre-write content. VERIFIED
  (`index.json.bak.20260709-190805`, md5 matches pre-write file exactly).
- Confirm no child (`parent_doc != null`) entries gained the field. PARTIALLY VERIFIED — true for
  the ~82 directories with a proper root entry (spot-checked blackburn_2002: children have no
  `provenance_fidelity` key, only the root `blackburn_2002_book` does); the 15 phantom-parent
  directories are an intentional, documented exception (see deviation 2.5).

### Phase 3: literature-search.sh loud flagging + quarantine [NOT STARTED]

**Goal**: Surface `provenance_fidelity` in search JSON, banner-prefix `--read` content for
non-verified docs, exclude unverified docs from default ranking (opt back in via
`--include-unverified`), and fail open on a missing field.

**Tasks**:
- [ ] Add a `doc_id -> provenance_fidelity` lookup against `$LITERATURE_DIR/index.json`, mirroring
      `get_project_doc_ids()` (jq keyed by `.id`). Missing/absent field resolves to
      `unverified_summary` (fail-open, loud-by-default).
- [ ] `do_search`: enrich each result object with a `provenance_fidelity` key via that lookup.
- [ ] `do_search`: exclude results whose fidelity is `unverified_summary`/`unverified_no_baseline`
      from the default ranked output; add an `--include-unverified` flag (parsed alongside
      `--project`) that disables the exclusion.
- [ ] `do_read`: when `provenance_fidelity != "verified_conversion"`, prefix the returned `content`
      with a loud ASCII-safe warning banner (emoji-policy compliant) naming the fidelity value and
      instructing the agent to verify against the source PDF before citing.
- [ ] `do_read`/`do_toc` result objects also gain the `provenance_fidelity` key.
- [ ] Preserve existing behavior for `verified_conversion` docs (no banner, normal ranking).

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/literature-search.sh` - lookup helper, `do_search` enrichment + exclusion,
  `--include-unverified` flag, `do_read` banner.

**Verification**:
- `--read` a `rabinovich_2014` chunk: content is prefixed with the warning banner and JSON carries
  `provenance_fidelity: "unverified_summary"`.
- A default search does not surface `rabinovich_2014`; `--include-unverified` surfaces it (banner
  present).
- A `verified_conversion` doc: no banner, normal ranking, field present and `verified_conversion`.
- Temporarily unset a doc's field (or query a doc lacking it): treated as unverified (fail-open).

### Phase 4: literature-briefing.sh loud flagging [NOT STARTED]

**Goal**: Prepend a visible per-entry warning marker for non-verified docs in both per-repo and
global modes, extend the "How to Use" footer, and fail open on a missing field.

**Tasks**:
- [ ] Add a `doc_id -> provenance_fidelity` lookup against `$GLOBAL_INDEX`, mirroring the existing
      `relevance` lookup (per-repo, ~line 197) and reusing it for global-mode entries by `doc_id`.
      Absent field -> treat as unverified (fail-open).
- [ ] Per-repo mode: when fidelity is `unverified_summary`/`unverified_no_baseline`/absent, prepend
      an ASCII-safe warning marker line to that `entry` string (emoji-policy compliant), e.g.
      `[UNVERIFIED SUMMARY - verify against source PDF before citing]`.
- [ ] Global mode: apply the same marker to each search-result entry by `doc_id`.
- [ ] Extend the "How to Use" footer with a line explaining that UNVERIFIED entries are not
      confirmed faithful to their source PDF and must be verified before citing in formal work.
- [ ] Leave `verified_conversion` entries visually unchanged.

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/literature-briefing.sh` - fidelity lookup, per-entry marker (both modes),
  footer extension.

**Verification**:
- Construct a briefing including `rabinovich_2014`: its entry shows the warning marker.
- The footer contains the new UNVERIFIED guidance line.
- A `verified_conversion`-only briefing shows no markers and is otherwise byte-compatible with
  prior output aside from the new footer line.

### Phase 5: End-to-end verification and defect sweep [NOT STARTED]

**Goal**: Confirm the full path (audit -> stamp -> flag) behaves correctly across both scripts and
that no false positives or corpus mutations occurred.

**Tasks**:
- [ ] Run the auditor `--write` on a clean corpus (backup taken); capture the enum distribution.
- [ ] Exercise `literature-search.sh` default search, `--include-unverified` search, and `--read`
      for one doc of each enum value; record banner/ranking behavior.
- [ ] Exercise `literature-briefing.sh` per-repo and (if a query is available) global mode; confirm
      markers and footer.
- [ ] Confirm the 5 disclosed partials and 30 healthy docs surface WITHOUT the unverified marker.
- [ ] Confirm no corpus `.md`/`.pdf` file was modified or deleted (`git status`/mtime check on
      `~/Projects/Literature/sources`).
- [ ] Confirm re-running the auditor is a no-op (idempotency holds after all edits).

**Timing**: 1 hour

**Depends on**: 3, 4

**Files to modify**:
- None (verification only; fixes route back to the owning phase's file if a defect is found).

**Verification**:
- All checklist items pass; `rabinovich_2014` is the only `unverified_summary`; zero disclosed-partial
  false positives; zero corpus deletions.

## Testing & Validation

- [ ] Detector report-only run classifies the corpus with `rabinovich_2014` as the sole
      `unverified_summary` and the 5 disclosed partials as `verified_conversion`.
- [ ] `--write` is idempotent (second run produces an empty diff) and backup-first.
- [ ] `literature-search.sh` `--read` banners non-verified content; default ranking excludes
      unverified; `--include-unverified` re-includes.
- [ ] `literature-search.sh` and `literature-briefing.sh` both fail open (absent field -> unverified).
- [ ] `literature-briefing.sh` marks non-verified entries and carries the extended footer.
- [ ] No corpus file deleted or content-modified anywhere under `~/Projects/Literature/sources`.

## Artifacts & Outputs

- `.claude/scripts/literature-fidelity-audit.sh` (new) - detector + idempotent stamper.
- `.claude/scripts/literature-search.sh` (modified) - fidelity JSON field, `--read` banner,
  quarantine ranking, `--include-unverified`.
- `.claude/scripts/literature-briefing.sh` (modified) - per-entry warning marker, footer line.
- `~/Projects/Literature/index.json` (modified) - `provenance_fidelity` + `word_ratio` on parents,
  plus a timestamped `index.json.bak.*`.
- `specs/835_literature_corpus_provenance_fidelity_audit/summaries/01_provenance-fidelity-flagging-summary.md`
  (implementation summary).

## Rollback/Contingency

- `index.json`: restore from the timestamped `index.json.bak.<ts>` written before the first
  `--write`; the field is additive so removal is a clean `jq del(.entries[].provenance_fidelity,
  .entries[].word_ratio)` if a full revert is needed.
- Script changes: revert via git (`literature-search.sh`, `literature-briefing.sh`); delete the new
  `literature-fidelity-audit.sh` to fully back out.
- No corpus content is ever deleted, so there is nothing to restore under `sources/`.
