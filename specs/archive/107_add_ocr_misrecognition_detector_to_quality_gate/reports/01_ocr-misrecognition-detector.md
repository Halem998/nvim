# Research Report: Task #107

**Task**: 107 - Add an OCR-misrecognition detector to the literature quality gate
**Started**: 2026-09-02T00:25:00Z
**Completed**: 2026-09-02T07:33:00Z
**Effort**: ~3 hours
**Dependencies**: Task 102 (converter-tier characterization, COMPLETED), Task 104 (glue-check false-positive class, COMPLETED), Task 105 (OCR tier, COMPLETED)
**Sources/Inputs**: `literature_quality_gate.py`, `literature-convert.sh`, `literature-fidelity-audit.sh`, `literature-organization.md`, real corpus documents at `~/Projects/Literature/sources/`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **No content-based signal evaluated separates OCR misrecognition from legitimate dense
  mathematics at an acceptable false-positive rate on this corpus.** Four independently
  designed and progressively refined candidate signals (whole-document OOV rate, whole-document
  mixed-alnum-symbol density, prose-line-restricted OOV/symbol anomaly rate, and a narrower
  "embedded-corruption-token" rate) were measured against the 11 known scan-pipeline documents
  and 6 born-digital dense-math controls. In every version, the negative controls' scores
  overlapped or exceeded several positives' scores. This is a **measured negative result**, not
  a hypothesis — see Findings for the actual numbers on all four attempts.
- **Provenance detection (PDF Creator/Producer metadata) remains the one signal that works
  cleanly**: 11 of 74 corpus PDFs carry an unambiguous scan-pipeline signature
  (`capture|finereader|image conversion`, case-insensitive), with zero false positives among the
  63 non-matching documents (verified via direct string search, not just the substring "imag").
  This is 4 more than the 7 the delegating message cited — see "Corrected provenance count" below
  for why.
- **This exact metadata-only provenance check already exists**, independently implemented in
  `literature-fidelity-audit.sh`'s `scan_source_check()`, whose own docstring explicitly frames
  it as a placeholder for "a separate, not-yet-built detector['s]... broader, content-based
  detection." This task's finding is that the broader content-based detector this comment
  anticipates does not have a viable design on this corpus — the metadata-only check is not a
  stepping stone to something better, it is very likely the ceiling for an automatic, per-document
  gate check.
- **Recommendation**: promote the existing provenance regex to an importable function in
  `literature_quality_gate.py` (the shared module both `literature-convert.sh` and
  `literature-fidelity-audit.sh` already import from), have `literature-fidelity-audit.sh`
  consume it instead of its own inline `SCAN_SOURCE_SIGNATURE_RE`, and add a **non-blocking
  warning** (never a gate rejection) to `run_quality_gate()` in `literature-convert.sh` so an
  operator sees "scan-pipeline provenance — recommend manual spot-check" at conversion time. Do
  NOT gate/reject on it and do NOT use it to select a converter tier — both are foreclosed by
  task 102's finding that scan provenance does not predict which remedy (or whether any remedy)
  a document needs.
- A genuinely independent second signal — comparing the existing text layer against a **fresh**
  `ocrmypdf`/Tesseract pass on the same page images — is technically available in this
  environment (`ocrmypdf`/`tesseract` both on PATH) and would not share the primary/fallback
  tiers' common blind spot (both read the same already-degraded PyMuPDF-extracted text layer).
  It is deliberately **not** recommended for the automatic per-conversion gate, for the same
  reason task 105 kept `LITERATURE_CONVERTER=ocr` explicit-only: it is a document-scale,
  minutes-long operation. It is a plausible on-demand/audit-time follow-up, not this task's
  deliverable.

## Context & Scope

The quality gate's six existing string-only checks (`literature_quality_gate.py`) are tuned for
**encoding** defects: glyph-index-as-codepoint corruption, ligature residue, dehyphenation
residue, column interleaving, sentence-boundary glue. None of them detect **OCR misrecognition**:
well-formed, printable, plausibly-tokenized text that is simply wrong. The delegating message
measured all six checks directly against `goldblatt_1989` (a documented, hand-annotated-as-corrupt
2001 Acrobat 3.0 Capture scan) and confirmed every check passes despite visible corruption — this
report does not re-derive that; it starts from it.

This task's scope, per the delegation: evaluate candidate content signals for detecting probable
OCR misrecognition (for warning/withholding-certification/routing-to-re-OCR purposes only — never
for auto-selecting a converter tier, per task 102's finding that scan status does not predict tier
remedy), validate against real corpus documents in both directions, and report actual numbers. A
negative result, with measurements and a fallback to provenance-only flagging, is explicitly an
acceptable outcome.

## Findings

### `goldblatt_1989` already carries a hand-written corruption warning

`~/Projects/Literature/sources/goldblatt_1989/goldblatt_1989.md` (and its `chunk_0001.md`) already
opens with a manually-authored `> **OCR FIDELITY WARNING — READ BEFORE USING THIS TEXT.**` block
describing exactly the corruption the delegating message cites (`{9=, 4s:`, `0%`, `$m`,
"v&et&s", "New 2Miand"). This is the *only* document in the corpus carrying such an annotation
(`grep -rl "OCR FIDELITY WARNING" ~/Projects/Literature/sources/` returns only this one
directory) — confirming it is a known, previously manually-flagged case that no automatic check
currently catches, not a newly discovered one.

### Corrected provenance count: 11, not 7

The delegating message's count of 7 scan-pipeline PDFs came from `pdfinfo | grep -iE
'capture|scan|abbyy|finereader|imag'`. Reproducing that exact command against all 74 corpus PDFs
under `~/Projects/Literature/sources/*/*.pdf` returns only 7 — but this undercounts by 4. Acrobat
3.0/4.0 Capture Plug-in embeds a **literal NUL byte** at the end of its own Creator/Producer
metadata strings (confirmed via `pdfinfo ... | cat -A`: `Creator:  Acrobat 3.0 Capture
Plug-in^@$`). Bash's `$(...)` command substitution silently drops everything from that NUL byte
onward with a bash 5.x warning (`command substitution: ignored null byte in input`) in a way that,
depending on shell/grep interaction, causes `grep -iE '...'` (without `-a`) to intermittently fail
to match lines carrying it. Re-running with `grep -a` (or reading via Python, see below) surfaces
4 additional documents the plain-grep count silently dropped: `goldblatt_1989` itself,
`wijesekera_1990_constructivemodallogicsi`, `xu_1988`, and `zielonka_1998` — all four are genuine
Acrobat Capture scans on inspection (`pdfinfo` output shown below), not false positives introduced
by loosening the grep.

The corrected, verified list (11 of 74 corpus PDFs, via direct Python `fitz.Document.metadata`
inspection — see "Recommended implementation" for why this access path also sidesteps the NUL-byte
pitfall entirely):

| Document | Creator | Producer |
|---|---|---|
| `blackburn_2002` | Adobe Acrobat 7.0 | Adobe Acrobat 7.0 Image Conversion Plug-in |
| `burgess_1982` | ABBYY FineReader | (empty) |
| `burgess_1982_i` | ABBYY FineReader | (empty) |
| `burgess_1982_ii` | ABBYY FineReader | (empty) |
| `burgess_1982b` | ABBYY FineReader | (empty) |
| `doets_1989` | ABBYY FineReader | (empty) |
| `gabbay_1993` | ABBYY FineReader | (empty) |
| `goldblatt_1989` | Acrobat 3.0 Capture Plug-in | Acrobat 3.0 Import Plug-in |
| `wijesekera_1990_constructivemodallogicsi` | Acrobat 3.0 Capture Plug-in | Acrobat 3.0 Import Plug-in |
| `xu_1988` | Acrobat 4.0 Capture Plug-in for Windows | Acrobat 4.0 Import Plug-in for Windows |
| `zielonka_1998` | Acrobat 3.0 Capture Plug-in | Acrobat 3.0 Import Plug-in |

This regex has **zero false positives** among the corpus: searching all 74 documents' combined
Creator+Producer strings for the substring `imag` (the broadest term in the original grep) returns
exactly one hit — `blackburn_2002`, which is a genuine scan (`Image Conversion Plug-in`). This
regex is also exactly what `literature-fidelity-audit.sh`'s existing (and narrower — no bare
`scan`/`abbyy`) `SCAN_SOURCE_SIGNATURE_RE = r"capture|finereader|image conversion"` already uses,
independently confirming both the pattern and the count.

**Practical note for anyone else reaching for this check by hand**: use `fitz.Document.metadata`
(Python `subprocess.run(..., text=True)` also works correctly — verified directly, see below) or
`pdfinfo ... | grep -a`, never bare `pdfinfo | grep` from a shell script — the NUL byte will
silently truncate matches on this corpus's actual Capture-scanned documents.

### Candidate content signals: four rounds of measurement, all negative

Corpus documents used:

- **Positives** (11 scan-pipeline documents above, all their non-chunk `.md`/section files
  concatenated).
- **Negative controls** (born-digital, dense mathematics, chosen specifically because the
  delegating message's stated risk — "a naive symbol-density threshold will fire on correct
  math" — needs stress-testing against genuinely math-heavy prose, not merely
  non-mathematical born-digital text): `venema_2007` (pdfTeX), `venema_1991` (cairo/pdf,
  born-digital), `venema_1997` (pdfTeX), `hott_book_2013`, `ahrens_north_shulman_tsementzis`,
  `awodey_2016` (all born-digital, heavy category-theory/HoTT/modal-algebra notation).

An English wordlist (`dwyl/english-words`, 370,105 entries) was fetched for OOV-rate signals; no
system dictionary (`aspell`/`hunspell`/`/usr/share/dict/words`) was available in this environment.

**Round 1 — whole-document OOV rate, mixed-alnum-symbol token density/1000, "glued word" rate
(digit/symbol immediately adjacent to a 4+-letter alpha run, in lines with ≥6 tokens)**, computed
over the entire document text with no line filtering:

| Doc | OOV | mixed/1000 | glued_rate |
|---|---|---|---|
| goldblatt_1989 (+) | 0.1064 | 77.70 | 0.0084 |
| blackburn_2002 (+) | 0.0625 | 14.70 | 0.0000 |
| xu_1988 (+) | 0.1501 | 392.42 | 0.1726 |
| **venema_1991 (−)** | 0.0905 | **293.82** | **0.1541** |
| **venema_1997 (−)** | **0.1449** | 194.65 | 0.1445 |

`venema_1991`'s mixed-token density (293.82/1000) and glued-word rate (0.1541) both *exceed*
several positives' — dense math prose alone produces the same symbol-adjacency shapes the signal
was meant to catch. `venema_1997`'s OOV rate (0.1449) exceeds `goldblatt_1989`'s (0.1064). No
threshold on any of these three metrics separates the two groups.

**Round 2 — restrict to "prose-classified" lines only** (a line counts as prose if ≥70% of its
whitespace tokens are recognized English words, filtering out display-math/table lines before
scoring), then measure OOV+mixed-symbol anomaly rate only within those lines:

| Doc | anomaly_rate |
|---|---|
| goldblatt_1989 (+) | 0.0833 |
| **venema_2007 (−)** | **0.0933** |
| venema_1991 (−) | 0.1413 |
| venema_1997 (−) | 0.1185 |

`venema_2007` — a born-digital, pdfTeX-produced paper — scores *higher* than `goldblatt_1989`
even restricted to its own prose lines. Root cause: proper nouns (`Voevodsky`, `Rutgers`),
hyphenated compounds (`set-based`, `higher-categorical`), inline LaTeX math snippets
(`$\mathfrak{X}$`), and URLs/emails inside otherwise-prose sentences are common in this corpus and
are not corruption, but are indistinguishable from corruption under a bare OOV/symbol-mixing test.

**Round 3 — narrow to "embedded-corruption tokens"** (a token mixes alpha characters with a digit
or non-hyphen/apostrophe symbol *and* stays alpha-majority and word-length, excluding citation
markers, URLs, and LaTeX-delimited math), still restricted to prose lines, with typographic quotes
(`’‘“”–—`) explicitly exempted after Round 2's raw run showed they were the single largest false
positive source (`Voevodsky’s`, `doesn’t`, `“abuse”` all scored as "anomalous" under the naive
apostrophe handling):

| Doc | rate/10k |
|---|---|
| blackburn_2002 (+) | **15.69** |
| goldblatt_1989 (+) | 120.87 |
| **venema_2007 (−)** | **153.95** |
| **ahrens_north (−)** | **306.22** |
| awodey_2016 (−) | 7.63 |

`blackburn_2002` — a genuine scan-pipeline positive — scores *lower* than every negative control
except `awodey_2016`. `ahrens_north` — a born-digital negative — scores 2.5x higher than
`goldblatt_1989`. Remaining false-positive sources at this point: citation-year author codes
(`Ben65`, `Awo96`), Unicode math operators fused to hyphenated words (`∞-categories`,
`1-ary`), diacritic-bearing names via combining marks (`Gor´e`, `Martin-L¨of`), footnote markers
(`[^1]`), and LaTeX macro leakage from imperfect markdown structuring (`mathfrak{F`, `nabla_1`).

**Round 4 — additionally restrict to lowercase-initial tokens only** (excluding proper nouns,
citation codes, and diacritic names by construction, since they are capitalized, while the
delegating message's own corruption examples — "varieties" → "v&et&s" — are lowercase common
words):

| Doc | rate/10k |
|---|---|
| blackburn_2002 (+) | **2.70** |
| goldblatt_1989 (+) | 55.61 |
| **ahrens_north (−)** | **84.55** |
| venema_2007 (−) | 38.32 |
| venema_1991 (−) | 34.13 |

`ahrens_north` still exceeds `goldblatt_1989`; `blackburn_2002` still sits below every negative
control. Remaining false-positive sources: em/en-dash-joined compounds (`step–by–step`,
`identicals—the`), slash-joined alternatives (`since/until`, `syntactic/axiomatic`), and inline
HTML sub/superscript leakage from the markdown structuring layer (`p_<sup>…</sup>`).

**Conclusion from all four rounds**: each refinement closed one specific false-positive class the
previous round's raw examples exposed, and each time a *different* false-positive class
(proper nouns → typographic quotes → citation codes/diacritics/LaTeX leakage → dash/slash
compounds/HTML leakage) took its place, while the true signal (`goldblatt_1989`'s genuine
mid-word substitutions like `v&et&s`, `j%xis`) never separated cleanly from the noise floor. This
corpus's typesetting is idiosyncratic enough (Unicode math operators, LaTeX macro residue,
footnote markers, combining-mark diacritics, em-dash prose, embedded sub/superscript HTML) that a
generic lexical/symbol-shape heuristic is chasing a moving target, not converging on one. This
matches the delegating message's own explicit warning about naive symbol-density thresholds,
generalized: the problem is not specific to symbol density, it recurs for every content-shape
signal tried.

The one candidate signal from the delegation not empirically tested here — **agreement between
two independent extractions of the same page** — was analyzed but not run, because the pipeline's
two existing engine tiers (primary `pymupdf4llm`, fallback PyMuPDF column-clustering) are not
independent for this purpose: both read the *same* underlying `fitz`-extracted text layer, which
is exactly the layer OCR misrecognition already corrupted (this is the documented reason
`joyce_1999`'s fallback-tier reconversion did not fix its Class B defect — see
`literature-organization.md`'s Converter Tier Selection table). A truly independent second
extraction would require a fresh OCR pass (below), not a second read of the existing text layer.

### A genuinely independent extraction is possible, but expensive and out of automatic scope

`ocrmypdf` and `tesseract` are both present on PATH in this environment. Running
`ocrmypdf --force-ocr` (task 105's `LITERATURE_OCR_FORCE=1 LITERATURE_CONVERTER=ocr` mode) on
`goldblatt_1989`'s source PDF and diffing the result against the existing text layer would be a
genuinely independent second opinion, unlike the two existing PyMuPDF-based tiers. This was not
executed as part of this task (a full Tesseract pass over a 70-page document is a
document-scale, minutes-long operation, and task 105 deliberately kept that mode explicit-only for
exactly that cost reason — see its summary's Decisions section). It is a plausible design for a
future **on-demand** audit-time signal (e.g., a `/literature --validate`-adjacent spot-check
command an operator invokes explicitly on a scan-flagged document), not for the automatic
per-conversion gate this task was scoped to extend.

## Decisions

- **No content-based check is added to the quality gate.** Four rounds of real-corpus
  measurement, each closing one false-positive class only to expose another, did not produce a
  threshold that separates the 11 known scan-pipeline positives from born-digital dense-math
  negatives at an acceptable rate. Manufacturing a threshold the evidence does not support was
  explicitly out of scope per the delegating message.
- **Provenance-only flagging is the recommended fallback**, exactly as the delegating message
  pre-authorized. It is cheap (metadata read, no PDF text processing), one-pass, and — measured
  against all 74 corpus PDFs, not just the 11 positives — has zero observed false positives.
- **The correct target file for the promoted function is `literature_quality_gate.py`**, per the
  delegation's explicit source-store instruction and the "CONSUMERS" note: `literature-convert.sh`
  and `literature-fidelity-audit.sh` both need it, and `literature_quality_gate.py` is already the
  shared module both import from for exactly this reason (see its own module docstring).
- **The function must take extracted metadata strings, not a `fitz.Document`**, to preserve this
  module's existing "every check needs no PDF access at all" invariant (stated in its module
  docstring) — the caller (which already has `doc.metadata` or a `pdfinfo` result) extracts
  `creator`/`producer` and passes them in, the same way callers already pass in extracted
  `content` strings to every other check in this module.
- **Any gate-level or fidelity-audit-level use of this signal must remain a WARNING, never a
  rejection or an auto-tier-selector.** Task 102 already established, with concrete
  counter-examples (`savage_1972` vs. `joyce_1999`, both scans, opposite fallback-tier
  outcomes), that scan provenance does not predict what remedy — or whether any remedy — a
  document needs. This task's own measurements add a second, independent reason: several
  documents with real scan-pipeline provenance (`burgess_1982*`, `doets_1989`, `gabbay_1993`,
  `zielonka_1998`) already pass every existing gate check cleanly, so a rejecting or
  auto-rerouting use of provenance would regress documents that are not actually defective.

## Risks & Mitigations

- **Risk**: a future contributor reads the "no content signal validated" conclusion as "no
  content signal is possible" and stops looking. **Mitigation**: this report documents the
  specific false-positive classes that defeated each round (proper nouns, typographic quotes,
  citation codes, diacritics, LaTeX leakage, dash/slash compounds, HTML leakage) so a future
  attempt does not have to re-derive them from scratch, and separately documents the
  independent-fresh-OCR-pass direction as the one avenue not yet tried, with its cost tradeoff
  named explicitly.
- **Risk**: the provenance regex (`capture|finereader|image conversion`) is a known-signature
  allowlist and will silently miss a scan pipeline whose tool string isn't in the list (already
  documented as an accepted gap in `literature-fidelity-audit.sh`'s own comment). **Mitigation**:
  none proposed here beyond what already exists — this is inherent to any signature-based
  approach and is out of this task's scope to close.
- **Risk**: adding a warning path to `run_quality_gate()` that always fires on 11/74 corpus
  documents could be misread by an operator as "these are broken." **Mitigation**: the warning
  text must say "scan-pipeline provenance — recommend manual spot-check," not "quality defect
  detected," and must never contribute to the function's `reasons` list in a way that trips the
  exit-3 `QUALITY GATE FAILED` path (which currently is entered whenever `reasons` is non-empty,
  per `literature-convert.sh`'s main dispatch) — see Recommended Implementation below for the
  concrete separation needed.

## Recommended Implementation (for the planning phase)

Not executed here (source-store editing is a planning/implementation-phase activity); recorded so
the plan can be written directly against it.

1. **`literature_quality_gate.py`**: add
   `scan_pipeline_provenance(creator, producer)` returning `bool`, wrapping
   `re.compile(r"capture|finereader|image conversion", re.IGNORECASE)` applied to
   `f"{creator}|{producer}"` — this is `literature-fidelity-audit.sh`'s existing
   `SCAN_SOURCE_SIGNATURE_RE`/`scan_source_check()` logic, moved to the shared module and kept
   byte-identical in behavior (do not widen it as part of this move; widening is a separate,
   unvalidated change).
2. **`literature-fidelity-audit.sh`**: replace its inline `SCAN_SOURCE_SIGNATURE_RE` +
   `scan_source_check()` body with a call into the shared function (`sys.path.insert` +
   import, matching the existing `literature_combining_detect` import pattern already used a few
   lines above `scan_source_check()` in this same file). Preserve the function's existing
   fail-open contract (pdfinfo/metadata read failure → `False`, never a new certification).
3. **`literature-convert.sh`**: in `run_quality_gate(content, doc)`, read
   `doc.metadata.get("creator", "")` / `doc.metadata.get("producer", "")` (the `doc` parameter is
   already a `fitz.Document` — see the pdf_word_count/scan_source_check note above on why
   `fitz.Document.metadata` is the preferred access path over shelling out to `pdfinfo`, since it
   is immune to the NUL-byte truncation pitfall this report found in the naive
   `pdfinfo | grep` pattern). If `scan_pipeline_provenance(...)` is `True`, emit a distinctly
   labeled **advisory** line — kept out of the `reasons` list that drives the exit-3 rejection
   path, printed to stderr alongside the existing `[convert] Engine used: ...` line, e.g.
   `[convert] ADVISORY: scan-pipeline provenance detected (Creator/Producer match) — recommend
   manual spot-check before certification, not a quality-gate failure`.
4. Do **not** add a corresponding rejecting check, and do **not** feed this signal into any
   converter-tier selection logic — both are explicitly out of scope per the Decisions section
   above and per task 102's prior finding.

## Context Extension Recommendations

- **Topic**: OCR-misrecognition content-signal infeasibility on this corpus.
- **Gap**: `literature-organization.md`'s Converter Tier Selection section documents the
  Class A/B/C remedy taxonomy but has no note recording that content-based misrecognition
  detection was evaluated and found not viable — a future contributor re-attempting this will not
  know four approaches were already tried.
- **Recommendation**: once the provenance-warning implementation above lands, add a short note to
  `literature-organization.md` (or a new subsection near Converter Tier Selection) pointing at
  this report's Findings section, so the negative result is discoverable without re-running the
  measurement.

## Appendix

### Corpus documents inspected

Positives (all 11, `.md`/section files concatenated per document): `goldblatt_1989`,
`blackburn_2002`, `burgess_1982`, `burgess_1982_i`, `burgess_1982_ii`, `burgess_1982b`,
`doets_1989`, `gabbay_1993`, `wijesekera_1990_constructivemodallogicsi`, `xu_1988`,
`zielonka_1998`.

Negative controls: `venema_2007_algebras_and_coalgebras`, `venema_1991`, `venema_1997`,
`hott_book_2013_homotopy_type_theory_univalent_foundations`,
`ahrens_north_shulman_tsementzis_the_univalence_principle`,
`awodey_2016_univalence_as_a_principle_of_logic`.

### Tools/commands used

- `pdfinfo <pdf> | cat -A` to surface the embedded NUL byte in Acrobat Capture metadata.
- Python `fitz.Document(...).metadata` and `subprocess.run(["pdfinfo", ...], text=True)` (both
  verified independently to handle the NUL byte correctly, unlike bash `$(...)` + `grep`).
- `curl -sL https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt` for the
  370,105-entry wordlist used in the OOV-rate signals (no system dictionary was available in this
  environment).
- Four purpose-built Python probe scripts (not committed; scratch artifacts only) implementing
  the four measurement rounds above.
