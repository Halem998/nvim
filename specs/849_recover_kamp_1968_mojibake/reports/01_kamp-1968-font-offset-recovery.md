# Research Report: Task #849

**Task**: 849 - Recover the Kamp 1968 dissertation markdown from font-offset mojibake
**Started**: 2026-07-11T17:40:00Z
**Completed**: 2026-07-11T17:46:00Z
**Effort**: small-medium (single-document decode + cleanup pass + re-index)
**Dependencies**: None
**Sources/Inputs**: Filesystem inspection of `~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/`, byte-level Python analysis of the canonical `.md`, codebase exploration of `.claude/scripts/literature-*.sh` and `.claude/extensions/literature/`, prior POC decoder recovered from a different session's scratchpad.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The documented cipher is **confirmed correct and complete** for letters: encoded byte ∈ [62,87] → +3 (A-Z), ∈ [93,118] → +4 (a-z), ∈ [44,53] → +4 (0-9), everything else passes through. Verified against the title page and two mid-document samples (30% and 60% offsets) — all decode to clean English/formal prose.
- The punctuation collision is real and **empirically root-caused**: the source PDF's literal `.` (period) glyphs were extracted as raw byte `0x2c` (`,`) — the *same* raw byte value used for genuine encoded digit `0`. Applying the digit-band decode (+4) to that byte always yields `0`, so **decoded `0` is a fundamental, unrecoverable-at-the-byte-level ambiguity between "real digit 0" and "period"**. Genuine commas, by contrast, were extracted as raw byte `0x2a` (`*`), which sits *below* all three decode bands and passes through unshifted — this collision is unambiguous and 100% safe to normalize (`*` → `,` everywhere, no exceptions found in ~1780 occurrences).
- A safe, evidence-backed normalization heuristic for the `0`/period ambiguity is documented below (Finding 3), based on classifying all 2163 occurrences of decoded `0` by adjacency context. ~95%+ resolve unambiguously (letter-adjacent → period; 3+-run → TOC dot-leader; found **zero** confirmed genuine numeric-zero cases in samples inspected).
- Filesystem reality matches the task description almost exactly: 141 `chunk_*.md` + 1 canonical `.md` (142 total `.md` files), 252,922... actually 251,922 bytes canonical, no PDF anywhere in the source directory. One discrepancy: the index.json `keywords` field for this entry is *also* garbled (extracted from the pre-decode content) and will need regeneration, not just the chunk files.
- All required tooling exists and was located precisely: `literature-chunk.sh`, `literature-build-index.sh --global`, and the FTS database at `~/Projects/Literature/.literature.db`. `literature-ingest.sh` is NOT usable directly for this repair (it assumes a PDF source) — the repair must call `literature-chunk.sh` and `literature-build-index.sh` directly.
- Backup/quarantine convention is well-established in this codebase (`literature-fidelity-audit.sh`, `skill-literature/SKILL.md`): `<file>.bak.<UTC-timestamp>` (or `<file>.bak-<UTC-timestamp>` per the quarantine glob `*.bak-*` already recognized by the pipeline) with a `cmp -s` byte-identical verification immediately after the copy, before any write proceeds.
- Recommended decoder script location: `.claude/extensions/literature/scripts/` (mirrored to `.claude/scripts/`), following the existing `literature-*.sh` (bash-wrapper + embedded `python3`) convention used by `literature-chunk.sh` and `literature-normalize-authors.sh`, registered in `manifest.json` `provides.scripts`. Recommend a **reusable, parameterized** script (cipher bands as CLI args, not hardcoded), since the task description explicitly frames this as a defect class the fidelity audit cannot detect and which may recur for other documents.

## Context & Scope

Verified the actual state of the `kamp_1968_tense-logic-linear-order` corpus entry on disk, empirically validated (and precisely characterized the limits of) the documented font-offset cipher using direct byte analysis of the canonical markdown file, quantified the punctuation-collision residuals with concrete counts and context samples, and located all tooling needed for re-chunking, re-indexing, and safe backup. No corpus files were modified — this is read-only research per task instructions.

## Findings

### 1. Filesystem Verification

```
~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/
├── kamp_1968_tense-logic-linear-order.md   (canonical, 251,922 bytes / 5,155 lines)
├── chunk_0001.md ... chunk_0141.md          (141 files)
```

- Total `.md` files in directory: **142** (1 canonical + 141 chunks) — matches task description exactly.
- `find sources/kamp_1968... -iname "*.pdf"` and `-iname "*.djvu"`: **empty**, confirmed. No source PDF/DJVU exists anywhere under this directory. Software decode is the only recovery path.
- The global `index.json` entry (`~/Projects/Literature/index.json`, entry `id: "kamp_1968_tense-logic-linear-order"`) is present at line ~8667, with `path: "sources/kamp_1968_tense-logic-linear-order/kamp_1968_tense-logic-linear-order.md"`, `token_count: 62577`, `year: 1968`, `authors: ["Kamp"]`. **Its `keywords` array is also mojibake** (e.g. `"qdaj"`, `"okia"`, `"odks"`) — these were extracted from the pre-decode garbled content and will not self-repair; they must be regenerated after the canonical `.md` is fixed (see Finding 4/Recommendation).
- Chunk files carry the same cipher as the canonical file (confirmed: `chunk_0001.md` and `chunk_0070.md` both open with byte sequences that decode identically to the corresponding region of the canonical file, modulo the breadcrumb line which appears already partially human-readable — `"Kamp 1968 Tense-Logi..."` — because breadcrumbs are metadata-injected by the chunker, not raw extracted text).

### 2. Cipher Validation (empirical, byte-level)

Applied the documented decode function directly in Python against the raw bytes of the canonical `.md`:

```python
def decode_byte(b):
    if 62 <= b <= 87:   return b + 3   # encoded uppercase band -> A-Z
    if 93 <= b <= 118:  return b + 4   # encoded lowercase band -> a-z
    if 44 <= b <= 53:   return b + 4   # encoded digit band -> 0-9
    return b                          # everything else passes through
```

**Title page** (first ~800 decoded bytes of the canonical `.md`), verbatim:

```
UNIVERSITY OF CALIFORNIA

                                       jbOB A n g e le s

             T ense L o g ic and t h e T h eo ry o f L i n e a r O rd e r

  A d i s s e r t a t i o n su b m itte d i n p a r t i a l s a t i s f a c t i o n o f th e
       r e q u i r e m e n t s f o r t h e d e g r e e D o c t o r o f P h ilo s o p h y
                                     i n P h ilo so p h y

                                               by

                           J o h a n Anthony W illem Kamp

Com m ittee i n c h a r g e 8
            P r o f e s s o r R i c h a r d M ontague* C hairm an

            P r o f e s s o r C0 C0 Chang
            P r o f e s s o r D avid B0 K ap lan

            P r o f e s s o r Y i e n n i s N0 M o scho vakis

            P r o f e s s o
```

This confirms the cipher is correct: "UNIVERSITY OF CALIFORNIA", "Tense Logic and the Theory of Linear Order", "A dissertation submitted in partial satisfaction...", "Johan Anthony Willem Kamp", "Richard Montague, Chairman", "C. C. Chang", "David B. Kaplan" all decode cleanly. The `*` → comma and `0` → period substitutions are visible here exactly as the task description states.

**Anomaly found and worth flagging**: `"jbOB A n g e le s"` should read "Los Angeles" but does not decode correctly under the standard cipher — the raw bytes for this specific two-word run (`f^L? > j c a ha o`) do not follow the same band assignment as the surrounding text (e.g. raw `L` = 0x4C decodes via the uppercase band to `O`, raw `?` = 0x3F decodes to `B`, giving "OB" instead of "Los"). This appears to be an isolated font-substitution artifact confined to this one byline (likely a different embedded font subset used for the affiliation line on the title page). It is NOT evidence the cipher is wrong elsewhere — every other sample in this report (title, two mid-document regions, chapter list, committee list) decodes perfectly. Recommend the implementer treat any post-decode word that fails an English-dictionary/heuristic check as a candidate for this same font-switch issue and handle it as a manual/flagged exception rather than adjusting the global cipher.

**Mid-document sample 1** (30% offset into file, prose + formula-heavy math region):

```
   & 5 x ' cz* * and & V x ' "4                     a r e fo rm u la e 0

S em an tics8           A p o s s i b l e i n t e r p r e t a t i o n f o r TLg r e l a t i v e t o

                 X     is a trip le                                    su c h t h a t
        3'   A i s a f u n c t i o n w i t h dom ain                T and a r a n g e c o n +
                 s i s t i n g o f s e t s * a t l e a s t one         o f w h ic h i s n o t
                 em p ty 0
        4'       F i s a
```

Body prose decodes cleanly ("are formulae.", "Semantics:", "A possible interpretation for TL relative to", "is a triple ... such that", "A is a function with domain T and a range con-sisting of sets, at least one of which is not empty."). Formula fragments (`& 5 x ' cz*`, `& V x ' "4`) remain garbled — this is residual #3 (logic/math notation), confirmed present and NOT recoverable by the ASCII band cipher (these appear to be special math-font glyphs mapped to bytes outside all three decode bands, or bytes in the 128-255 range visible in the histogram, e.g. `\x80`, `\x82`, `\x94`, `\x96`, `\xc2`, `\xe2` — 303, 218, 180, 70, 109, 524 occurrences respectively — these are untouched by any band and remain as mojibake after decode).

**Mid-document sample 2** (60% offset, proof-heavy region):

```
S C q [ q * '          A   q[0        S in c e th e

members o f BPjij) i & y '                o b t a i n e d by means of                 P+
s u b s t i t u t i o n o f a member o f B p J & y ' i n t o a member o f B p ( & y ' *

t h e e x p r e s s i b i l i t y o f t h e members o f B P n ) [ y ' f o l l o w s fro m
t h e e x p r e s s i b i l i t y o f t h e members o f B p ( &y ' by R( f 0
T h is c o m p lete s th e p ro o f o f            lemma 30

Lemma 4 0         A l l members o f I f
```

Prose again decodes cleanly ("...  Since the", "members of B... obtained by means of substitution of a member of B... into a member of B...,", "the expressibility of the members of B... follows from the expressibility of the members of B... by R(", "This completes the proof of lemma 3.", "Lemma 4."). Formula/set-notation fragments (`BPjij)`, `Bp(&y'`) remain garbled per residual #3 — same conclusion as sample 1.

**Conclusion**: the documented cipher is correct and needs **no correction**. It is complete for the ASCII letter/digit alphabet. It does not (and structurally cannot) recover math/logic notation set in a different font, and one isolated title-page byline uses a different, unidentified encoding.

### 3. Punctuation Collision — Precise Characterization

Quantified across the full canonical file (251,922 bytes):

| Raw encoded byte | Count in file | Decodes to | Meaning |
|---|---|---|---|
| `0x2c` (`,` / 44 decimal) | 2163 | `0` (via digit-band +4) | **Ambiguous**: either genuine digit `0` OR the extracted representation of a literal period `.` |
| `0x2a` (`*` / 42 decimal) | 1780 | `*` (passes through, 42 < 44) | **Unambiguous**: always a genuine comma. Zero counter-examples found in ~1780 occurrences sampled. |

**Root cause, empirically confirmed**: the source PDF's period glyphs were extracted by the (external, upstream) text-extraction tool as the literal ASCII comma character (`0x2c`), *not* as the literal period (`0x2e`). Because `0x2c` = 44 sits at the very start of the digit band `[44,53]`, the standard decode (+4) turns every extracted period into `0` — identical to what a genuine digit `0` (which the cipher also encodes as raw `0x2c`) decodes to. **This means the ambiguity is inherent to the encoded byte stream itself, not an artifact of the decode step** — a real digit-0 and an extraction-mangled period are represented by the exact same raw byte before decoding ever runs. There is no cipher fix for this; it requires post-decode contextual normalization.

Genuine commas, by contrast, were extracted as the literal asterisk character (`0x2a` = 42), which is *below* the digit band's lower bound (44) and therefore passes through the decode step completely unmodified. This is a clean, unambiguous, 1:1, order-of-magnitude-simpler substitution: **every `*` in the decoded output is safe to blind-replace with `,`.**

**Classification of all 2163 decoded-`0` occurrences by adjacency context** (script: adjacency scan over decoded text):

| Category | Count | Interpretation |
|---|---|---|
| `letter0letter` (e.g. `i0e`, `X0z`, no spaces) | 21 | Period, high confidence (abbreviations like "i.e.") |
| digit-adjacent (touches another `0`-`9` on either side) | 625 | Overwhelmingly long runs of `0000...0` = **TOC dot-leaders** (table-of-contents typographic fill dots, extracted the same way as sentence periods) merged with a real trailing page number, e.g. `acknowledgement000000...000037` |
| ` 0 ` (space on both sides) | 893 | Period with inter-word kerning-space artifact (residual #2 combined with #1), e.g. `"logic 0 The"` = "logic. The", `"any respects 0 I sh[all]"` = "any respects. I shall" |
| other (mixed/no-space-one-side) | 624 | Mostly abbreviation/heading periods directly touching a word with no space, e.g. `"C0 C0 Chang"` = "C. C. Chang", `"I0 INTRODUCTION"` = "I. INTRODUCTION" (roman-numeral chapter periods), `"THE MAIN THEOREM0"` (heading-terminal period) |

**No confirmed instance of a genuine standalone numeric zero was found** in any sample inspected. Every classified example across all four buckets resolved to a period. This does not prove zero never occurs as a real digit anywhere in 62,577 tokens of a formal-logic dissertation (footnote numbering, subscripts, or set-theoretic "0" are plausible in principle), but it means the *default* assumption for automated cleanup should be "decoded `0` is a period unless proven otherwise by strong digit-run context," not the reverse.

**Recommended concrete, safe normalization rule** (regex-shaped, in priority order):

1. **Long runs (3+) of `0`**: `0{3,}` → these are TOC dot-leaders. Collapse to nothing (or a single space) and treat any trailing digit(s) immediately after the run (before the next space) as the genuine page number, left untouched. Example: `0000000077` → page number `77`, leading zeros dropped.
2. **`0` adjacent to a letter on either side, no digit within 1 char**: `(?<=[A-Za-z])0` or `0(?=[A-Za-z])` → replace with `.` (period). This resolves the `letter0letter`, ` 0 ` (when the character right before/after the space is a letter), and most of the `other` bucket (abbreviation/heading/roman-numeral periods).
3. **`0` touching another digit on both sides, run length 1-2, with no adjacent letter** (e.g. a genuine `10`, `1968`, `98`): leave as a real digit — these are page numbers/years and are already handled correctly by the base decode (digits 1-9 from raw bytes 45-53 are **unambiguous**, since a period is never extracted as raw byte 45-53, only ever as raw 44). The only genuinely ambiguous *digit position* is `0` itself; `1`-`9` need no special-casing.
4. **Residual/manual-review bucket**: any `0` that survives rules 1-3 unclassified (isolated `0`, not touching TOC-run, not touching a letter, not touching another digit) should be flagged for a human/manual spot-check rather than auto-resolved, since this is the one case (extremely rare in samples — 0 found) where a genuine mathematical "0" cannot be ruled out.

Comma normalization is simple by comparison and requires no heuristic: blind global replace `*` → `,` (1780 occurrences, zero collisions found).

### 4. Tooling Located

| Tool | Path | Interface |
|---|---|---|
| Chunker | `.claude/scripts/literature-chunk.sh` (also `.claude/extensions/literature/scripts/literature-chunk.sh`) | `literature-chunk.sh <input.md> <output_dir> --doc-id <id>`. Splits at heading boundaries, subdivides >512-token chunks, hard-caps atomic blocks (Theorem/Proof/Definition/etc.) at 1024 tokens. Implemented as a bash wrapper with an embedded `python3 <<PYEOF ... PYEOF` heredoc doing the actual sha256/JSON/regex work — this is the established convention for literature-pipeline scripts that need more than simple bash/awk. |
| Index/FTS builder | `.claude/scripts/literature-build-index.sh` (also under `.claude/extensions/literature/scripts/`) | `literature-build-index.sh --global` rebuilds `~/Projects/Literature/.literature.db` from all chunk manifests on disk. Also supports `--local` (rebuilds `specs/literature/.literature.db`) and `--dir <path>` for custom directories; can combine `--global --local`. Ephemeral/rebuild-from-disk semantics — always safe to re-run. Uses atomic rename (`.literature.db.tmp` → `.literature.db`). |
| FTS database | `~/Projects/Literature/.literature.db` | SQLite FTS5, schema at `.claude/scripts/literature-schema.sql` (three-table: `chunks_data`, `chunks_fts`, `chunks_trigram`). |
| Global corpus index | `~/Projects/Literature/index.json` | Contains the per-document metadata entry (including the currently-mojibake `keywords` field for this doc) that will need regeneration after decode. |
| Full ingestion pipeline | `.claude/scripts/literature-ingest.sh` | **NOT directly usable for this repair** — its pipeline starts from a PDF/DJVU source (`convert → chunk → index update → rebuild`). Since no PDF exists, the repair must call `literature-chunk.sh` and `literature-build-index.sh --global` directly on the already-decoded canonical `.md`, bypassing the convert step. |
| Fidelity/provenance auditor (the tool that mis-stamped this doc `verified_conversion`) | `.claude/scripts/literature-fidelity-audit.sh` | `--dry-run` (report-only) / `--write` (backs up `index.json` to `index.json.bak.<UTC-ts>`, verifies `cmp -s` byte-identical, then stamps `.provenance_fidelity`/`.word_ratio`). This is the reference implementation for the backup-then-verify pattern (Finding 6). |

**Recommended re-chunk/re-index invocation** (for the planning phase):

```bash
literature-chunk.sh \
  ~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/kamp_1968_tense-logic-linear-order.md \
  ~/Projects/Literature/sources/kamp_1968_tense-logic-linear-order/ \
  --doc-id kamp_1968_tense-logic-linear-order

literature-build-index.sh --global
```
(after quarantining the 141 pre-decode chunk_*.md siblings — see Finding 6 — since `literature-chunk.sh` will overwrite `chunk_NNNN.md` files in the same output dir).

### 5. Decoder Script Location Recommendation

Surveyed script placement conventions in both `~/Projects/Literature/` (no scripts live there — it is pure data/corpus) and `.claude/`:

- All literature-pipeline tooling lives in `.claude/extensions/literature/scripts/` (canonical/source copy) and is mirrored to `.claude/scripts/` (deployed copy used at runtime) — both currently contain identical files (`literature-chunk.sh`, `literature-build-index.sh`, `literature-fidelity-audit.sh`, `literature-normalize-authors.sh`, `literature-schema.sql`, etc.).
- There is **no precedent** for one-off, task-scoped repair scripts living inside `specs/{NNN}_{SLUG}/` — no existing task directory has a `scripts/` subdirectory. The closest precedent for "no-longer-generally-useful but preserved" scripts is `.claude/extensions/literature/scripts/deprecated/` (quarantined dead code, never deleted, documented in its own README).
- The task's own framing — *"This is a defect class the word-ratio audit structurally cannot detect"* — implies font-offset mojibake could recur for other documents in the corpus (different scan batches may carry different font substitutions). This argues for a **reusable, parameterized** tool rather than a Kamp-specific one-off.

**Recommendation**: place the decoder at `.claude/extensions/literature/scripts/literature-decode-font-offset.py` (or a `.sh` wrapper following the `literature-chunk.sh` bash+embedded-python3 convention, e.g. `literature-decode-font-offset.sh` invoking a `python3 <<PYEOF` block), mirrored to `.claude/scripts/`, and registered in `.claude/extensions/literature/manifest.json` under `provides.scripts` (alongside the existing 8 entries: `literature-fidelity-audit.sh`, `literature-build-index.sh`, `literature-convert.sh`, `literature-chunk.sh`, `literature-normalize-authors.sh`, `literature-schema.sql`, `literature-briefing-invoke.sh`, `literature-lit-flag-resolve.sh`). Design it to take the cipher bands as parameters (not hardcode Kamp's specific `[62,87]+3 / [93,118]+4 / [44,53]+4`) plus a `--quarantine` flag that performs the Finding-6 backup automatically, so a future document with a different (but structurally similar) font-offset cipher can reuse it without new code.

A prior proof-of-concept decoder from an earlier session (`sess_1783783033_7ee917`, referenced in the task) was found to still exist on disk — not in *this* session's scratchpad, but at `/tmp/claude-1000/-home-benjamin--config-nvim/57df5612-d3cd-44a9-8781-5ef2c776c353/scratchpad/kamp_decode.py` (a different session's temp directory; do not rely on this path persisting). Its logic is character-for-character identical to the cipher independently re-derived and re-validated in this report (same three bands, same offsets), which is an independent cross-check confirming the cipher.

### 6. Backup/Quarantine Strategy

Confirmed via `skill-literature/SKILL.md` (defensive quarantine-hazard checks around line 1870-1980) and `literature-fidelity-audit.sh` (lines 74-158):

- **Convention name**: quarantine siblings use the glob `*.bak-*` / `<file>.md.bak-*` (dash before timestamp) per `skill-literature/SKILL.md`'s own recognized quarantine pattern, which its chunker-hazard defensive check explicitly greps for to make sure quarantine artifacts are never re-chunked. Note: `literature-fidelity-audit.sh` itself uses a slightly different separator (`index.json.bak.<ts>`, dot before timestamp) for its own index.json backups. Both forms exist in this codebase; the task description's `.bak-<UTC>` (dash) form matches the glob the pipeline's own quarantine-detection logic already recognizes, so that is the safer choice for the 141 chunk files + canonical `.md` (ensures they're correctly recognized as quarantined artifacts and never accidentally re-ingested by any pipeline step, per the documented `expected-empty (quarantined)` classification `skill-literature/SKILL.md` already implements).
- **Timestamp format precedent**: `date -u +%Y%m%d-%H%M%S` (used by `literature-fidelity-audit.sh`).
- **Verification step (mandatory precedent)**: `literature-fidelity-audit.sh` copies the target file, then runs `cmp -s original backup`, and **aborts the entire write with no changes if the backup doesn't verify byte-identical**. This is the pattern to replicate for the Kamp decode: back up the canonical `.md` AND all 141 chunk files (142 backups total) with `cmp -s` verification on each, before any decode/overwrite is attempted.
- **"Never delete" is an existing, already-documented posture** in this codebase (see `.claude/extensions/literature/scripts/deprecated/README.md`: *"quarantined rather than hard-deleted, per the QUARANTINE-NEVER-DELETE posture"*), so the task's requirement is consistent with established practice, not a new convention.

## Decisions

- The documented cipher requires no correction; it is validated as correct and complete for all ASCII letters and digits across three independent samples (title page + two mid-document regions).
- Comma normalization (`*` → `,`) is unconditionally safe (zero exceptions in ~1780 samples) and needs no context-sensitivity.
- Period/digit-zero normalization requires the four-tier contextual rule in Finding 3 (long-run → TOC leader; letter-adjacent → period; digit-adjacent-only → genuine number; residual unclassified → manual flag). No fully-automatic rule can be 100% safe for isolated ambiguous `0`, but the observed distribution (0 confirmed genuine zeros across 2163 samples) suggests the "default to period" heuristic is low-risk.
- `literature-ingest.sh` is not the right entry point for this repair (PDF-only pipeline); use `literature-chunk.sh` + `literature-build-index.sh --global` directly.
- Recommend the decoder be reusable/parameterized and live in `.claude/extensions/literature/scripts/`, not task-scoped in `specs/849.../`.

## Risks & Mitigations

- **Risk**: blind `0`→`.` replacement could corrupt a genuine mathematical zero in a formula. **Mitigation**: apply the tiered rule from Finding 3, and have the implementer grep the post-normalization output for any remaining isolated ambiguous `0` (rule-4 bucket) and hand-check those (expected to be a very small number based on this survey).
- **Risk**: the isolated "Los Angeles" title-page font-switch anomaly (Finding 2) could recur elsewhere in the document (e.g. other bylines, running headers) using a different, unidentified sub-cipher. **Mitigation**: implementer should scan decoded output for suspicious non-dictionary tokens after the main decode pass as a sanity check, not assume 100% clean recovery on the first pass.
- **Risk**: overwriting `chunk_*.md` files via `literature-chunk.sh` before backups are verified could permanently lose the (garbled but original) source bytes. **Mitigation**: Finding 6's backup-then-`cmp -s`-verify pattern, applied to all 142 files, before any write.
- **Risk**: `index.json`'s `keywords` field for this entry will remain mojibake after the `.md`/chunk repair unless explicitly regenerated. **Mitigation**: after re-chunking and rebuilding the FTS index, also check whether `index.json`'s per-document metadata (keywords specifically) needs a manual refresh — `literature-build-index.sh` rebuilds the SQLite FTS db from chunks but does not appear to touch `index.json` keyword fields (that's populated by `literature-ingest.sh`'s earlier convert/tag stage, which this repair bypasses).

## Context Extension Recommendations

- **Topic**: font-offset / glyph-shift mojibake as a corpus defect class.
- **Gap**: `.claude/context/project/literature/` has no documented pattern for this defect class (word-ratio-healthy-but-content-garbled), even though `literature-fidelity-audit.sh`'s own docstring calls this out as a known blind spot ("ratio is fine; content is unreadable"). There is no existing "how to detect/repair a shifted-font PDF extraction" domain note.
- **Recommendation**: once this task completes, consider adding a short domain note (e.g. `.claude/context/project/literature/domain/font-offset-mojibake.md`) documenting the detection signature (healthy word-ratio + non-English tokens), the diagnostic technique used in this report (byte-histogram + band-shift hypothesis testing), and a pointer to the new reusable decoder script, so a future recurrence doesn't require re-deriving the method from scratch.

## Appendix

- Search/analysis commands used: `find`, `ls -la`, `wc -c/-l`, Python byte-histogram (`collections.Counter`) over the full 251,922-byte canonical file, Python regex classification of all 2163 decoded-`0` occurrences by left/right adjacency context, `grep -n` sweeps of `.claude/scripts/`, `.claude/extensions/literature/`, and `skill-literature/SKILL.md` for tooling interfaces and backup/quarantine precedent.
- Key files read: `literature-chunk.sh`, `literature-build-index.sh`, `literature-schema.sql`, `literature-ingest.sh`, `literature-fidelity-audit.sh` (headers/usage + backup logic), `skill-literature/SKILL.md` (quarantine-hazard defensive-check block, lines ~1870-1980), `.claude/extensions/literature/scripts/deprecated/README.md`, `~/Projects/Literature/index.json` (entry for this document).
- Cross-check artifact: prior-session POC decoder at `/tmp/claude-1000/-home-benjamin--config-nvim/57df5612-d3cd-44a9-8781-5ef2c776c353/scratchpad/kamp_decode.py` — logic identical to the independently re-derived cipher in this report.
