# Implementation Plan: Recover Kamp 1968 Font-Offset Mojibake

- **Task**: 849 - Recover the Kamp 1968 dissertation markdown from font-offset mojibake
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/849_recover_kamp_1968_mojibake/reports/01_kamp-1968-font-offset-recovery.md
- **Artifacts**: plans/01_kamp-1968-font-offset-decode.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The corpus document `kamp_1968_tense-logic-linear-order` (1 canonical `.md` of 251,922 bytes plus
141 `chunk_*.md`, no source PDF) is stored as font-offset mojibake but passes the word-ratio
fidelity audit. Research report 01 empirically validated a three-band ASCII decode cipher and
precisely characterized two punctuation collisions: encoded `*` (raw `0x2a`) is an unambiguous
comma, while decoded `0` is a genuine byte-level ambiguity between a real period and a real digit-0
(both extracted as raw `0x2c`). This plan builds a reusable, parameterized decoder that applies the
cipher plus a four-tier `0` normalization rule, safely quarantines all 142 files before any write,
decodes and re-chunks the canonical file, rebuilds the FTS index, and verifies the recovered text
is readable English. Definition of done: title page, chapter headings, and >=3 mid-document chunks
decode to clean English; the FTS database returns decoded text; and all 142 pre-change backups
exist and are byte-identical to the originals.

### Research Integration

Key findings from report 01 driving this plan:
- **Cipher (validated)**: encoded byte in [62,87] -> +3 (A-Z); [93,118] -> +4 (a-z); [44,53] -> +4
  (0-9); everything else passes through. Needs no correction.
- **Comma collision (safe)**: blind global replace `*` -> `,` (1780 occurrences, zero exceptions).
- **Period/zero collision (ambiguous)**: decoded `0` requires the four-tier context rule (Finding 3),
  not a naive replace. Zero confirmed genuine numeric zeros were found across 2163 samples.
- **No PDF**: software decode is the only recovery path; `literature-ingest.sh` (PDF-only) is unusable.
  Repair calls `literature-chunk.sh` + `literature-build-index.sh --global` directly.
- **Backup precedent**: `cp` then `cmp -s` verify-before-write, `.bak-<UTC>` sibling naming (the glob
  `*.bak-*` the pipeline's quarantine detection already recognizes).
- **Decoder location**: `.claude/extensions/literature/scripts/literature-decode-font-offset.py`,
  mirrored to `.claude/scripts/`, registered in `manifest.json`; parameterized (cipher bands as CLI
  args), not Kamp-specific.
- **index.json keywords** for this entry are also mojibake and need regeneration.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but this is a `meta` task and no `roadmap_flag` was set for this planning
run; no ROADMAP items are explicitly advanced and no ROADMAP review/update phases are included. This
task is corpus-data repair plus a reusable tooling addition, discovered as a side finding during
task #832.

## Goals & Non-Goals

**Goals**:
- Deliver a reusable, parameterized font-offset decoder script with a punctuation-normalization pass
  (comma blind-replace + four-tier `0` rule), registered in the literature extension manifest.
- Recover the canonical `kamp_1968` markdown to readable English via the validated cipher.
- Safely quarantine all 142 files (`.bak-<UTC>`) with `cmp -s` verification before any write.
- Re-chunk fresh from the decoded canonical and rebuild the global FTS index.
- Regenerate the mojibake `index.json` keywords for the document entry.
- Verify recovery with explicit, checkable acceptance tests.

**Non-Goals**:
- Fixing the audit blind spot (word-ratio-passes-but-content-garbled). That mirrors the #839-class
  fail-open concern and belongs to a separate audit-hardening task. **Explicit scope boundary.**
- Perfect recovery of inter-letter spacing artifacts (`"t e n s e"` -> `"tense"`) and garbled
  math/logic notation. These residuals are structural extraction damage the ASCII band cipher cannot
  repair; they are **acceptable known limitations** and this plan does not over-promise on them. A
  clean re-sourced PDF (ProQuest/UCLA, SOURCES.md entry #5) would be needed to fix math notation.
- Re-sourcing the dissertation from ProQuest/UCLA.
- Hand-editing the 141 existing chunk files (see decision below).

**Decision — re-chunk vs hand-edit**: Re-chunk fresh from the decoded canonical via
`literature-chunk.sh` (task-preferred). Rationale: the chunker deterministically regenerates chunk
boundaries, sha256 manifests, and breadcrumbs from the decoded source, guaranteeing chunk/canonical
consistency; hand-editing 141 files is error-prone and cannot fix boundary/manifest drift. The old
chunks are quarantined (not deleted) in Phase 2 before the chunker overwrites them.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blind `0` -> `.` corrupts a genuine mathematical zero | M | L | Apply four-tier rule (Finding 3); default `0`->period only when letter-adjacent; flag isolated unclassified `0` for manual review (Phase 3 acceptance test greps the rule-4 bucket) |
| Overwriting `chunk_*.md` before backups verify loses original bytes | H | L | Phase 2 backs up all 142 files with `cmp -s` before any write in Phase 3/4; chunker not run until Phase 4 |
| Isolated title-page font-switch anomaly (`"Los Angeles"` byline) recurs elsewhere | L | L | Phase 6 scans decoded output for suspicious non-dictionary tokens; treat as flagged manual exceptions, do NOT adjust the global cipher |
| `index.json` keywords stay mojibake after chunk/index rebuild | M | M | Phase 5 explicitly regenerates the document's keyword field; `literature-build-index.sh` rebuilds FTS from chunks but does not touch `index.json` keywords |
| `.bak-<UTC>` backups accidentally re-chunked/re-ingested | M | L | Use the `*.bak-*` glob the pipeline quarantine detection already recognizes; verify chunker output contains no `.bak-` files (Phase 4 acceptance test) |
| Decoder hardcodes Kamp cipher, not reusable | L | M | Cipher bands passed as CLI args with Kamp values as documented defaults; Phase 1 unit test exercises the parameterized path |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 1 (build decoder) and 2 (quarantine
backups) are independent and may run concurrently.

### Phase 1: Build and unit-test the parameterized decoder [COMPLETED]

**Goal**: Produce a reusable font-offset decoder + punctuation-normalization script that decodes a
known ground-truth sample to clean English, without touching corpus files.

**Tasks**:
- [x] Create `.claude/extensions/literature/scripts/literature-decode-font-offset.py` implementing:
  - Band decode: `[62,87]->+3`, `[93,118]->+4`, `[44,53]->+4`, else pass-through; bands and offsets
    as CLI args (`--upper-band`, `--lower-band`, `--digit-band`, or an equivalent `--band lo,hi,off`
    repeatable flag) with the validated Kamp values as documented defaults. *(completed: repeatable
    `--band lo,hi,off` flag, defaults to Kamp bands)*
  - Comma pass: blind global replace `*` -> `,`. *(completed)*
  - Four-tier `0` normalization (Finding 3), in priority order: (1) `0{3,}` runs = TOC dot-leaders,
    collapse and keep trailing digits as page number; (2) `0` letter-adjacent (no digit within 1
    char) -> `.`; (3) `0` touching another digit only, run length 1-2 -> leave as real digit; (4)
    isolated unclassified `0` -> leave in place AND emit to a `--flag-report` list for manual review.
    *(completed)*
  - CLI: `--in FILE --out FILE`, `--flag-report FILE`, optional `--quarantine` (cp + `cmp -s` sibling
    backup), `--dry-run`. *(completed)*
- [x] Mirror the script to `.claude/scripts/literature-decode-font-offset.py`. *(completed)*
- [x] Register the script in `.claude/extensions/literature/manifest.json` under `provides.scripts`.
      *(completed)*
- [x] Write a small unit test / self-check: decode the known title-page byte sample from report 01
      and assert the output contains the ground-truth strings. *(deviation: altered — ran decoder
      against the real title-page bytes; output matches report 01's ground truth exactly, including
      the accepted letter-spacing residual, so verification used readable-English + exact-term spot
      check rather than literal unspaced substring match for the two spaced phrases; see progress
      file deviations)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-decode-font-offset.py` - new decoder (create)
- `.claude/scripts/literature-decode-font-offset.py` - deployed mirror (create)
- `.claude/extensions/literature/manifest.json` - add script to `provides.scripts`

**Verification (acceptance tests)**:
- Running the decoder on the title-page sample yields text containing `UNIVERSITY OF CALIFORNIA`,
  `Tense Logic and the Theory of Linear Order`, and `Johan Anthony Willem Kamp`.
- Output shows commas where source had `*` and periods where the four-tier rule classifies `0` as a
  period (e.g. `C. C. Chang`, `Richard Montague, Chairman`).
- `python3 -c "import ast; ast.parse(open('.claude/scripts/literature-decode-font-offset.py').read())"`
  parses without error; `--help` runs.
- `jq '.provides.scripts' .claude/extensions/literature/manifest.json` includes the new script.

---

### Phase 2: Quarantine all 142 files with cmp verification [COMPLETED]

**Goal**: Create byte-identical `.bak-<UTC>` sibling backups of the canonical `.md` and all 141
chunk files BEFORE any decode/overwrite, aborting if any backup fails to verify.

**Tasks**:
- [x] Compute one UTC timestamp: `TS=$(date -u +%Y%m%d-%H%M%S)`. *(completed: TS=20260711-180106)*
- [x] For the canonical `.md` and each `chunk_*.md` (142 files): `cp <file> <file>.bak-$TS`, then
      `cmp -s <file> <file>.bak-$TS`; abort the whole phase with no further writes if any `cmp` fails.
      *(completed: 142/142 verified, 0 mismatches)*
- [x] Record the backup count and timestamp; confirm 142 `.bak-$TS` siblings exist. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/*.md` -> create `.bak-<UTC>`
  siblings (no in-place modification in this phase)

**Verification (acceptance tests)**:
- `ls .../kamp_1968_tense-logic-linear-order/*.bak-$TS | wc -l` == 142.
- Every backup passes `cmp -s` against its origin (loop reports zero mismatches).
- No original `.md` or `chunk_*.md` was modified (mtimes of originals unchanged).

---

### Phase 3: Decode canonical .md and apply punctuation cleanup [NOT STARTED]

**Goal**: Produce the decoded, punctuation-normalized canonical `.md` in place, with a manual-review
flag report for any rule-4 ambiguous `0`.

**Tasks**:
- [ ] Run the Phase 1 decoder on the canonical `.md` (in -> out), writing decoded output to the
      canonical path and the ambiguous-`0` list to a `--flag-report` file (task scratch or task dir).
- [ ] Inspect the flag report; hand-check each isolated ambiguous `0` (expected very few / zero per
      report survey) and resolve or leave with a documented note.
- [ ] Spot-read the decoded canonical: title page, `I. INTRODUCTION`-style chapter headings, and a
      mid-document region, confirming readable English.

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:
- `~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/kamp_1968_tense-logic-linear-order.md`
  - decode + normalize in place (backup exists from Phase 2)

**Verification (acceptance tests)**:
- Decoded canonical title page reads as clean English (matches report 01 ground truth).
- No `*` characters remain where commas belong; `grep -c '\*'` is reduced to expected residual
  (math-notation) levels, not ~1780.
- The flag report is reviewed; every rule-4 ambiguous `0` is either resolved or documented as an
  accepted residual (report survey found zero genuine numeric zeros).
- `cmp -s` still confirms the Phase 2 canonical backup is byte-identical to the pre-decode original.

---

### Phase 4: Re-chunk from the decoded canonical [NOT STARTED]

**Goal**: Regenerate the 141 chunk files from the decoded canonical so chunk content matches the
recovered text.

**Tasks**:
- [ ] Confirm quarantine backups (`.bak-<UTC>`) for the existing chunks are present (Phase 2).
- [ ] Run `literature-chunk.sh <decoded-canonical.md> <source-dir>/ --doc-id kamp_1968_tense-logic-linear-order`.
- [ ] Confirm the chunker overwrote `chunk_*.md` with decoded content and did not touch `.bak-*` files.

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/chunk_*.md` - regenerated from
  decoded canonical

**Verification (acceptance tests)**:
- `chunk_0001.md` and at least two other chunks open with readable English (spot-check).
- No `.bak-<UTC>` file was consumed or altered by the chunker (`cmp -s` against Phase 2 backups still
  passes; the chunker's own quarantine-hazard check reports no `*.bak-*` re-chunk).
- Chunk count is consistent with the decoded canonical (approximately the prior 141, regenerated).

---

### Phase 5: Rebuild FTS index and regenerate index.json keywords [NOT STARTED]

**Goal**: Make the decoded text searchable and repair the mojibake keyword metadata for the document.

**Tasks**:
- [ ] Run `literature-build-index.sh --global` to rebuild `~/Projects/Literature/.literature.db` from
      the decoded chunks.
- [ ] Regenerate the `keywords` array for the `kamp_1968_tense-logic-linear-order` entry in
      `~/Projects/Literature/index.json` from the decoded content (replace `"qdaj"`/`"okia"`-style
      mojibake with real terms, e.g. tense logic, linear order, temporal logic, Kamp).
- [ ] Confirm `index.json` remains valid JSON after the keyword edit.

**Timing**: 0.75 hours

**Depends on**: 4

**Files to modify**:
- `~/Projects/Literature/.literature.db` - rebuilt via `literature-build-index.sh --global`
- `~/Projects/Literature/index.json` - regenerate mojibake `keywords` for this document entry

**Verification (acceptance tests)**:
- An FTS query for a distinctive decoded phrase (e.g. `Tense Logic` or `Linear Order`) returns the
  kamp_1968 document/chunks from `.literature.db`.
- `jq '.[] | select(.id=="kamp_1968_tense-logic-linear-order") | .keywords' index.json` (path per
  actual schema) shows real English keywords, no mojibake tokens.
- `jq empty index.json` exits 0 (valid JSON).

---

### Phase 6: End-to-end verification and residual documentation [NOT STARTED]

**Goal**: Confirm all task acceptance criteria and document accepted residuals and scope boundary.

**Tasks**:
- [ ] Spot-check title page + chapter headings + >=3 mid-document chunks are readable English against
      the known subject matter (tense logic, Main Theorem / Theorem II.3).
- [ ] Confirm the FTS db returns decoded text for the document.
- [ ] Confirm all 142 backups exist and are byte-identical to pre-change originals (`cmp -s` sweep).
- [ ] Scan decoded output for suspicious non-dictionary tokens (title-page font-switch anomaly class);
      record any as flagged manual exceptions, not cipher changes.
- [ ] Document accepted residuals (inter-letter spacing, garbled math/logic notation) and the scope
      boundary (audit blind spot NOT fixed) in the implementation summary.

**Timing**: 0.75 hours

**Depends on**: 5

**Files to modify**:
- `specs/849_recover_kamp_1968_mojibake/summaries/01_kamp-1968-font-offset-decode-summary.md`
  (created at implementation completion)

**Verification (acceptance tests)**:
- Title page, chapter headings, and >=3 mid-document chunks confirmed readable English.
- FTS query returns decoded text (repeat of Phase 5 query, end-to-end).
- 142/142 backups byte-match originals (`cmp -s` sweep reports zero mismatches).
- Summary explicitly lists accepted residuals and states the audit-hardening scope boundary.

---

## Testing & Validation

- [ ] Phase 1: decoder unit test reproduces report-01 title-page ground truth; script parses, `--help`
      works; manifest registration present.
- [ ] Phase 2: 142 `.bak-<UTC>` siblings created; all `cmp -s` byte-identical; originals unmodified.
- [ ] Phase 3: decoded canonical is readable English; `*` comma residue eliminated; ambiguous-`0`
      flag report reviewed and resolved/documented.
- [ ] Phase 4: chunks regenerated with readable content; no `.bak-*` consumed.
- [ ] Phase 5: FTS query returns decoded text; `index.json` keywords regenerated; valid JSON.
- [ ] Phase 6: full acceptance sweep (title page + headings + >=3 chunks readable; FTS returns
      decoded; 142 backups verified; residuals + scope boundary documented).

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/literature-decode-font-offset.py` (reusable decoder)
- `.claude/scripts/literature-decode-font-offset.py` (deployed mirror)
- Updated `.claude/extensions/literature/manifest.json` (`provides.scripts`)
- Decoded `~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/kamp_1968_tense-logic-linear-order.md`
- Regenerated `chunk_*.md` (141) in the source directory
- 142 `.bak-<UTC>` quarantine backups (retained, never deleted)
- Rebuilt `~/Projects/Literature/.literature.db`
- Repaired `keywords` in `~/Projects/Literature/index.json`
- Ambiguous-`0` flag report (task scratch or task directory)
- `specs/849_recover_kamp_1968_mojibake/summaries/01_kamp-1968-font-offset-decode-summary.md`

## Rollback/Contingency

- All 142 corpus files have `.bak-<UTC>` siblings created and `cmp`-verified before any write. To
  revert corpus data: copy each `.bak-<UTC>` back over its origin, then re-run
  `literature-build-index.sh --global` to restore the pre-change FTS index.
- `index.json` keyword edit: restore from git or from an `index.json.bak.<UTC>` sibling if one is
  created before editing.
- The decoder script and manifest change are additive and independently reversible via git.
- If decoded output is not readable English (cipher mismatch), STOP before Phase 4 (no chunk
  overwrite yet), keep backups, and re-open research — do not adjust the validated global cipher to
  chase isolated font-switch anomalies.
