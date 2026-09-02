# Provenance Fidelity

`provenance_fidelity` is the field `literature-fidelity-audit.sh` stamps onto `index.json`
entries (see that script's header for target-entry resolution) recording how much a document's
`.md` conversion can be trusted to faithfully reproduce its source PDF. This file is the single
documented source of truth for the enum's values, the detector's signals, and the invariants any
future change to either must preserve — previously this lived only in the audit script's own
header comment.

## The seven-value enum

| Value | Meaning | Quarantined by search? | Marked by briefing? |
|---|---|---|---|
| `verified_conversion` | A word-ratio >= 0.75 was measured (and not scan-source-gated), OR a low ratio was explicitly disclosed as a selective conversion, OR a low ratio's numbered claims are adequately proved. The document is trusted. | No | No |
| `unverified_summary` | Ratio < 0.75, undisclosed, and fewer than 60% of numbered Definition/Lemma/Theorem/Proposition/Corollary statements have adequate bodies (a proof marker for claims, real content for definitions). Likely a lossy paraphrase. | Yes | Yes |
| `no_source_pdf` | No PDF/DJVU file exists in the directory, but markdown does. Nothing to compare against; not itself a fidelity failure (the pipeline's retain-chunks-not-PDFs convention produces most of these; see "Why `no_source_pdf` is not quarantined" below). | No | No |
| `not_yet_converted` | A PDF/DJVU exists but no markdown does yet. Self-evident from a 0-token entry; not a fidelity failure to mark. | No | No |
| `unverified_no_baseline` | Either neither a PDF nor markdown exists (anomalous), or a PDF exists but `pdftotext` extracted zero words from it (e.g. a fully scanned image PDF with no embedded text layer at all). No ratio could be computed. Fail-closed. | Yes | Yes |
| `unadjudicated` | Ratio < 0.75, undisclosed, and there are NO numbered Definition/Lemma/Theorem/Proposition/Corollary statements to check at all — the proof-completeness signal cannot fire. This is the ABSENCE of a signal, not a positive finding; fail closed rather than reading silence as a pass. | Yes | Yes |
| `unverified_scan_source` | A word-ratio >= 0.75 was measured, but at least one PDF in the directory carries a known scan/OCR-pipeline Creator/Producer metadata signature (ABBYY FineReader, Acrobat Capture/Import Plug-in, Image Conversion Plug-in). The ratio is self-referential by construction (a `pdftotext` extraction compared against `pdftotext`'s own extraction of the same scanned source reads ~1.0 regardless of true page-content fidelity) and cannot certify. | Yes | Yes |

## The detector's signals

Four signals, evaluated in this order for a directory that has both a PDF and markdown (the
`has_pdf and has_md` case; the three other has_pdf/has_md combinations resolve immediately to
`no_source_pdf` / `not_yet_converted` / `unverified_no_baseline` without reaching any of these
signals):

1. **Whole-document word-ratio**: `md_words / pdf_words`, both summed over ALL matching files in
   the directory (see "Aggregate at document level" below) — `md_words` via the conditional
   chunk-counting rule (see below), `pdf_words` via `pdftotext -layout` word counts summed across
   every `*.pdf`/`*.djvu` in the directory. If `pdf_words_total == 0`, the ratio cannot be
   computed at all -> `unverified_no_baseline`. Otherwise, `ratio >= RATIO_THRESHOLD` (0.75) is
   the certification threshold.
2. **Scan-source gate** (evaluated ONLY ahead of the ratio>=threshold certification branch, via
   `scan_source_check()`, which calls the shared `literature_quality_gate.scan_pipeline_provenance`
   function): does any PDF in the directory match the known scan/OCR-pipeline signature
   (case-insensitive `capture|finereader|image conversion` against `pdfinfo`'s Creator+Producer
   fields)? If so, route to `unverified_scan_source` instead of `verified_conversion`. This gate
   is deliberately metadata-only, not a general OCR-misrecognition text detector — a bounded,
   known-signature allowlist that will miss a scan pipeline whose tool string isn't in the list
   (accepted gap; `literature_quality_gate.scan_pipeline_provenance` is the single extension
   point for widening or replacing this signal without another `classify_dir()` rewrite). A
   content-based OCR-misrecognition text detector — one that could in principle catch a scan
   pipeline outside this allowlist — was evaluated separately across four progressively refined
   signal families against 11 known scan-pipeline corpus documents and 6 born-digital dense-math
   controls, and did not separate the two groups at any threshold (a genuine scan scored
   15.69 hits/10k words while born-digital controls scored 153.95 and 306.22/10k); see
   `context/guides/literature-organization.md`'s "Content-Based OCR-Misrecognition Detection: A
   Measured Negative Result" subsection for the full measured record. This metadata-only check is
   very likely the ceiling on this corpus, not a placeholder for that content-based detector. It
   is NOT applied to the low-ratio disclosure/proof-completeness paths below — a document already
   withheld from high-ratio certification does not need a second reason to be withheld.
   The same shared function also drives a separate, non-blocking ADVISORY in
   `literature-convert.sh`'s per-conversion quality gate — see that script's `run_quality_gate()`
   — which is unrelated to this classifier and never affects `provenance_fidelity`.
3. **Disclosure check** (only when ratio < 0.75): does the `.md` content or the matching
   `index.json` summary text admit to being a selective/partial conversion (regex match on
   "selective conversion", "extracted: chapter", "truncated", "excerpt", "chapters N and M")? If
   so -> `verified_conversion` (a disclosed partial conversion is not a fidelity failure).
4. **Proof/body-completeness check** (only when ratio < 0.75 and undisclosed): for numbered
   Definition/Lemma/Theorem/Proposition/Corollary headings, a claim (Lemma/Theorem/Proposition/
   Corollary) is adequate only if an explicit "Proof" marker follows in its body; a Definition is
   adequate if its body has real defining content (>=2 non-blank lines or >=15 words). If there
   are no numbered statements at all, the signal cannot fire -> `unadjudicated` (fail closed). If
   the fraction of adequate statements is below 0.6 -> `unverified_summary`; otherwise ->
   `verified_conversion`.

### Additive signal: combining-mark check (not part of the enum gate)

`combining_mark_checked`/`combining_mark_dropped`/`combining_marks_missing` are a distinct,
precedented pattern: reported ALONGSIDE `provenance_fidelity` for informational purposes, never
folded into the ratio>=threshold gate or the enum itself. This is intentionally different from
the scan-source gate above — de-certifying scan-sourced false positives was an explicit
acceptance requirement, which an additive-only field cannot satisfy (it would leave every
scan-sourced directory still stamped `verified_conversion`). A future signal should default to
the additive pattern unless it specifically needs to change the enum value, in which case it
needs its own gate placement decision documented here, the way the scan-source gate is above.

## Aggregate at document level, never single file

Every ratio, word count, and disclosure/proof check operates on ALL `.md` files and ALL
`.pdf`/`.djvu` files in a directory, summed together — never sampled from a single file within
the directory. Single-file sampling is a known false-discriminator: a document split across
multiple files (chunks, or multiple chapters) can have wildly different per-file ratios while its
whole-document ratio is accurate.

## Conditional chunk-counting rule

`chunk_NNNN.md` files count toward `md_words`/`has_md` **only when a directory has no non-chunk
`.md`** — see `chunk-file-conventions.md` for the full rule, the double-count and blindness
failure modes it prevents, and the reference implementation
(`classify_dir()`'s `non_chunk_mds`/`chunk_mds`/conditional `mds` assignment). Chunk-ness is
never a *verdict* signal for classification outcome (a chunk-only directory is not, by that fact
alone, less trustworthy) — it only affects what counts as the directory's markdown content.

## Why `no_source_pdf` is not quarantined

The pipeline's current retain-chunks-not-PDFs convention means most ingested documents have no
PDF file in `sources/<dir>/` at all — `no_source_pdf` is the correct, non-quarantined resting
state for "there is nothing to compare against," distinct from `unverified_no_baseline`'s "a PDF
exists but yielded no baseline" (which fails closed because a comparison was attempted and
failed, not merely absent). Do not collapse the two: `no_source_pdf` says "cannot be checked, not
alleged to be checked," while every quarantined value says "was checked (or should have been
checkable) and failed the check."

## The fail-open invariant

`literature-search.sh` and `literature-briefing.sh` are the two retrieval-time consumers, and
both are ALLOWLIST checks of quarantined/marked values, not denylist checks of trusted ones: an
absent `provenance_fidelity` field, or any value not in their list, is read as "fine" by the
allowlist mechanism itself — which is why every value that should withhold trust MUST be added
to both lists explicitly, or it silently passes through unmarked and unquarantined (exactly what
happened to the orphaned `unverified_conversion` string a stale corpus stamp once carried, which
matched no current enum value and slipped through both consumers until the next re-stamp
overwrote it). Never invert this into a "trusted-values allowlist" — that direction fails closed
on anything new, which sounds safer but actually breaks retrieval the moment a new legitimate
value is introduced without also being added to a "trusted" list, which is a worse failure mode
for an already-small corpus.

**Whenever a new `provenance_fidelity` value is added, it MUST be added to all of these in the
same change:**
- `literature-fidelity-audit.sh`'s own enum comment and `classify_dir()` (obviously — it's the
  producer).
- `literature-fidelity-audit.sh`'s `main()` population-summary key list, so the new value appears
  in the reported counts instead of being silently dropped from the report.
- `literature-search.sh`'s `QUARANTINED_FIDELITY_VALUES` (a single space-separated string
  consumed by both of its embedded Python blocks) — UNLESS the new value is deliberately meant to
  be non-quarantined (like `no_source_pdf`/`not_yet_converted`), which must be a documented,
  deliberate decision, not an oversight.
- `literature-briefing.sh`'s `needs_fidelity_marker()` case list — same non-quarantined caveat
  applies.
- This file's enum table above.
- Re-grep the full `agent-system/extensions/literature/` tree for the existing enum value strings
  and `provenance_fidelity`/`QUARANTINED_FIDELITY` — the two consumers named above are the ones
  known today, not a guaranteed exhaustive list for all future changes.
