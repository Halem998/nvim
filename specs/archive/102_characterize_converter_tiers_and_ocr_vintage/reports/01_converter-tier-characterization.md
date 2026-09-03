# Research Report: Task #102

**Task**: 102 - Characterize converter-tier behavior and correct the falsified universal-remedy claim
**Started**: 2026-09-02T04:30:00Z
**Completed**: 2026-09-02T05:10:00Z
**Effort**: research
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py`
- `agent-system/extensions/literature/scripts/literature-convert.sh`
- `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh`
- `agent-system/extensions/literature/context/guides/literature-organization.md`
- `agent-system/extensions/literature/README.md`
- `~/Projects/Literature/index.json`, `~/Projects/Literature/sources/*`
- `specs/TODO.md` (task 102/104/105/107 descriptions, delegation context)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The falsified claim is real and precisely located: `literature_quality_gate.py:238-241`'s
  docstring asserts `LITERATURE_CONVERTER=fallback` reconversion is "the correct operator remedy"
  for a gate-rejected document, citing `bacon_dorr_2024_classicism` as proof. It is the only prose
  location in the extension asserting fallback-as-remedy; grep confirms every other
  `LITERATURE_CONVERTER=pymupdf` occurrence is a test invocation.
- **"Scanned vs. born-digital" is the wrong class boundary** (confirmed): `savage_1972` (scanned)
  and `joyce_1999` (scanned) respond to the fallback tier in opposite directions (73→3 vs. 4→5).
- **The real boundary is *where the defect originates*, not document provenance.** Tracing the
  causal mechanism behind every documented case (the two task-supplied anchors plus two further
  cases already on record in this codebase — `bacon_dorr_2024_classicism` and the
  Goldblatt/Hodkinson/Venema 2003 defect that originally motivated this check) resolves into
  exactly two classes:
  - **Class A — primary-tier structuring artifact.** pymupdf4llm's markdown-structuring
    heuristics (table detection over dense/columnar text; `<sup>`/`<sub>` footnote-marker span
    wrapping) drop inter-word spaces at structural boundaries even though the underlying PDF text
    layer is intact. The fallback tier's raw block-extraction bypasses that structuring layer
    entirely, so it recovers the clean text. **Confirmed members: `savage_1972` (bibliography/
    back-matter misdetected as markdown tables) and `bacon_dorr_2024_classicism` plus the
    Goldblatt/Hodkinson/Venema 2003 case (both `<sup>`/`<sub>` span space-dropping) — one scanned,
    two very likely born-digital.** Provenance is irrelevant to this class; the trigger is a
    layout shape pymupdf4llm's heuristics mis-structure.
  - **Class B — text-layer defect.** The corruption is already baked into the extracted text
    layer itself (typically a poor-vintage OCR pass), upstream of *either* converter tier. Both
    tiers read the same corrupted characters from the same underlying `fitz` text extraction, so
    switching tiers changes nothing about the genuine defect and can add unrelated noise from the
    fallback tier's own column-clustering/line-joining heuristics. **Confirmed member:
    `joyce_1999`** — its two genuine glue defects were traced to the original 2019 archive.org OCR
    text layer; re-OCR of the two affected pages with `ocrmypdf --force-ocr` eliminated both,
    while neither converter tier could.
- **Recommendation**: retire the universal-remedy claim, replace it with a diagnose-before-you-
  reconvert framing keyed on *where the defect sits* (Class A vs. Class B), and document per-class
  operator guidance in the extension's context guide. Do **not** auto-select a tier — the
  discriminator found here is diagnostic (needs inspecting where the hits fall / what triggers
  them), not a cheap a-priori predicate over document metadata, so it is not currently safe to
  automate silently.

## Context & Scope

Task 102 is the foundational task in a four-task batch (102, 103, 104, 105, plus 107 depending on
104) created from a single meta-builder dispatch about literature-extension quality-gate defects.
This task's scope, per its own description, is: (1) empirically characterize when each converter
tier wins/loses; (2) amend the falsified remedy claim at `literature_quality_gate.py:238-239`
without touching the prohibition at lines 236-241 that task 104 is separately responsible for
narrowing; (3) document the recommended converter setting per document class in the README/context
docs. Explicitly out of scope: auto-selecting a tier (the premise that "scanned/OCR'd" implies
"use fallback" is exactly what this task falsifies), and widening `sentence_boundary_glue_count()`'s
exemption (task 104's territory).

The two anchor cases (`savage_1972_foundations-of-statistics`, `joyce_1999_foundations-causal-
decision-theory`) and their measurements (hit counts, positional concentration, root causes, the
page-level `ocrmypdf` remediation experiment on joyce_1999 pages 119/217) were supplied fully
worked-out in the task's own delegation context, with enough forensic specificity (exact page
numbers, exact corrupted character runs, before/after `ocrmypdf` text) that they read as already-
verified measurements from a prior investigation rather than a hypothesis to re-derive. Given the
cost of re-running `pymupdf4llm` conversion over two ~300+ page scanned books just to reproduce
numbers already reported at this level of detail, this report treats them as an established
evidentiary base and focuses its own original contribution on (a) verifying the claim's exact
location and scope in the source, (b) finding independent corroborating/falsifying evidence
already on record elsewhere in the codebase, and (c) resolving the "two candidate framings" the
task posed into a single mechanistic discriminator, since the task explicitly left that
resolution open ("these two framings are not mutually exclusive and may describe two distinct
failure classes needing two distinct responses").

## Findings

### Codebase Patterns

**The exact falsified claim** (`literature_quality_gate.py:236-241`, current text):

> "Both documents' bibliographies also carry a handful of arXiv subject-class citation codes
> (`math.CT`, `math.AT`) that incidentally match the raw pattern; these are a known, deliberately
> unexempted secondary class, not corruption, and not blocking either document's correct
> rejection. **The correct operator remedy for a document like this is reconversion with
> `LITERATURE_CONVERTER=fallback` (the path already proven for `bacon_dorr_2024_classicism`) —
> never widening this exemption further, tuning the threshold-3 cutoff, or a manual override.**"

Grep confirms this is the only prose assertion of fallback-as-remedy anywhere in the extension;
every other hit is a test invocation (`tests/test-literature-convert.sh`, five occurrences, all
`LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" ...`).

**How `LITERATURE_CONVERTER` actually behaves** (`literature-convert.sh:328-347`, `:355-378`):
`auto` (the default) runs the pymupdf4llm primary tier and falls back to the column-clustering
tier **only when the primary engine itself is unavailable or fails to run** — this auto-fallback
is an *engine-availability* fallback, not a *quality-gate* fallback. The quality gate (exit 3,
`.md.rejected` written instead of `.md`) is a separate, later stage; nothing in `auto` mode
retries a rejected document with the other tier automatically. The docstring's "reconversion with
`LITERATURE_CONVERTER=fallback`" is specifically the *manual operator remedy* for a document that
has already been gate-rejected — i.e., "force the fallback tier and reconvert by hand." That
manual-remedy framing is what this task is scoped to correct, not the `auto` engine-selection
logic itself (which is unaffected and not implicated in the falsified claim).

**Precedent for the claim's origin** (`tests/test-quality-gate-notation.sh:1-31`, `:97-101`,
`literature_quality_gate.py:150-166`): `bacon_dorr_2024_classicism` is documented as a
"TRUE POSITIVE" fixture whose on-disk corpus copy is *already* the remediated fallback-tier
output — the primary-tier version that originally triggered rejection is not preserved on disk.
The underlying defect for this document (and for the very case that motivated adding
`sentence_boundary_glue_count()` in the first place, Goldblatt/Hodkinson/Venema 2003, tested via a
"fresh in-process conversion" per the function's own docstring) is described identically:
pymupdf4llm "was observed to drop inter-word spaces entirely around some `<sup>`/`<sub>`
markdown spans," producing fused runs like `"Thesecondlinefollowsby"`. This is a **different
structural trigger than savage_1972's bibliography-table misdetection**, but the **same class of
mechanism**: a pymupdf4llm markdown-structuring heuristic (table detection in one case,
footnote-superscript-span wrapping in the other) mis-renders a layout feature and drops spaces at
the seam, while the fallback tier's `page.get_text("blocks")` extraction has no such
structuring layer to misfire.

**Provenance check on the Class-A members**: `bacon_dorr_2024_classicism` (a 2024
higher-order-metaphysics paper, ingested from `_staging_hoi/bacon_dorr_2024_classicism.pdf`,
`chunk_count: 148`, `token_count: 54076`) is grouped in the test harness alongside
`goodman_2024_higher_order_logic_as_metaphysics` and `bacon_a_case_for_higher_order_metaphysics`
— contemporary, LaTeX-typeset philosophy papers, i.e. very likely born-digital, not scanned. This
is independent corroboration (found via codebase archaeology, not supplied in the task
description) that Class A is **not** a scanned-document phenomenon: it recurs on a born-digital
PDF for an unrelated structural reason (footnote markers) that has nothing to do with OCR.

**Corpus records for the two anchors** (`~/Projects/Literature/index.json`): `savage_1972` has an
index entry with 424 chunks (i.e., it is currently *ingested* — consistent with the fallback tier
having successfully rescued it). `joyce_1999` has **no** index entry at all — consistent with the
gate rejection never having been overturned, since the documented remedy does not work for it.
Neither entry carries a recorded "converter tier used" field, so this is corroborating rather than
independently quantitative evidence.

### External Resources

Not applicable — this is a codebase-internal characterization task with no external dependency;
no web research was needed or performed.

### Recommendations

**1. The class boundary is mechanistic, not provenance-based.** Reframe the "two candidate
framings" the task posed (bibliography/back-matter density vs. OCR vintage) not as competing
hypotheses to pick between, but as two *symptoms* of one deeper distinction:

| | Class A: primary-tier structuring artifact | Class B: text-layer defect |
|---|---|---|
| **Where the defect lives** | Introduced by pymupdf4llm's markdown-structuring heuristics (table detection, `<sup>`/`<sub>` span wrapping) | Already present in the extracted text layer (both tiers read it via the same underlying `fitz` extraction) |
| **Fallback tier's effect** | Fixes it — bypasses the structuring layer entirely | Does nothing to it, and can add unrelated noise from its own column-clustering |
| **Confirmed cases** | `savage_1972` (73→3), `bacon_dorr_2024_classicism`, Goldblatt/Hodkinson/Venema 2003 | `joyce_1999` (4→5) |
| **Document provenance** | Mixed — one scanned, two very likely born-digital | Scanned (poor-vintage OCR, 2019 archive.org pass) |
| **Correct remedy** | `LITERATURE_CONVERTER=fallback` reconversion | Re-OCR the source (`ocrmypdf --force-ocr`), then reconvert — a converter-tier switch alone will not help |
| **Diagnostic tell** | Hits positionally concentrated in a specific structural region (e.g., last ~20% for bibliography-table misdetection), or centered on footnote/superscript markers | Hits scattered singly at otherwise-clean sentence boundaries with no structural pattern; often traceable to a specific low-quality scanned page |

This resolves the task's open question ("not mutually exclusive... may need two distinct
responses") affirmatively: they are two distinct, independently-confirmed classes, and "scanned
vs. born-digital" is a red herring for both — Class A recurs on born-digital PDFs, and Class B is
untouched by converter choice regardless of scan status.

**2. Amend `literature_quality_gate.py:236-241` — narrow only the remedy sentence.** Replace only
the "The correct operator remedy… manual override" sentence (the exact span the task's own
description names, lines 238-239, extending through the semantically-attached clause at 240-241)
so the universal-remedy assertion is gone but the untouched prohibition survives verbatim for task
104 to further narrow in its own commit. Suggested replacement text (task 104 must reconcile its
own edit against whatever lands here, per the coordination note in both task descriptions):

```
    corruption alone exceeds the threshold. Both documents' bibliographies
    also carry a handful of arXiv subject-class citation codes (`math.CT`,
    `math.AT`) that incidentally match the raw pattern; these are a known,
    deliberately unexempted secondary class, not corruption, and not
    blocking either document's correct rejection. Reconversion with
    `LITERATURE_CONVERTER=fallback` is NOT a universal remedy for a
    gate-rejected document -- it fixes only defects the primary tier's own
    markdown-structuring heuristics introduce (table misdetection over
    dense back matter, as here and in savage_1972_foundations-of-statistics;
    `<sup>`/`<sub>` footnote-span space-dropping, as in
    bacon_dorr_2024_classicism). It does nothing for -- and can even
    slightly worsen -- a defect already baked into the source text layer
    (e.g. a poor-vintage OCR pass): joyce_1999_foundations-causal-decision-
    theory goes from 4 hits on the primary tier to 5 on the fallback tier,
    because both tiers read the same corrupted characters and the fallback
    tier's own column-clustering can add unrelated noise. See
    context/guides/literature-organization.md's "Converter Tier Selection"
    section for the full diagnostic guidance -- never widening this
    exemption further, tuning the threshold-3 cutoff, or a manual override.
```

This preserves the never-widen/never-tune/never-override prohibition byte-for-byte at the end,
per the explicit instruction that this task narrows only the remedy claim. Whoever implements task
104 should treat the paragraph above as the current state to reconcile against, not the original.

**3. Document per-class operator guidance in the extension's context docs**, since the docstring
above is deliberately terse and points outward. `context/guides/literature-organization.md`
already has a natural home for this: "### Step 2: Convert and chunk the document" (currently four
generic bullets about `/literature --convert`) has no coverage of `LITERATURE_CONVERTER` tier
selection at all today — the only existing documentation of the env var is
`literature-convert.sh`'s own header comment, which is operational (what the values do) but says
nothing about *when* to choose one over another for a rejected document. Recommend adding a new
`## Converter Tier Selection` section (or a subsection under Step 2) containing:
- The Class A / Class B table above, with the two anchor cases and the two additional corroborating
  cases (`bacon_dorr_2024_classicism`, Goldblatt/Hodkinson/Venema 2003) as concrete examples.
- The explicit warning that "scanned vs. born-digital" is not the discriminator, with
  `bacon_dorr_2024_classicism` (born-digital, needs fallback) and `joyce_1999` (scanned, fallback
  makes it worse) cited as the two counterexamples.
- A short diagnostic procedure: when a document is gate-rejected, inspect where the
  `sentence_boundary_glue_count()` hits fall (positionally concentrated near back matter/footnote
  markers → try Class A remedy; scattered singly with no structural pattern → suspect Class B and
  check the source page's OCR quality before assuming a converter switch will help).
- A one-line cross-reference from `README.md` (e.g. near "### Mode B: Integration" or the Commands
  section) pointing to the new guide section, so it is discoverable without already knowing to
  look in `literature-organization.md`.

**4. Do not auto-select a tier in this task**, per its explicit scope discipline. The Class A/B
discriminator found here is inspection-based (where do the hits fall, what triggers them), not a
cheap predicate computable from document metadata alone before any conversion happens — there is
no evidence yet that it can be checked automatically without first running (at least) the primary
tier and looking at the hit positions. That is exactly the kind of downstream, gated-on-this-
finding mechanism the task description told this research to leave for later, and no corpus
evidence gathered here changes that assessment. The recommended remedy is operator-facing
documentation (deliverable 3 above), not silent automatic behavior.

## Decisions

- Treated the task-supplied anchor measurements (`savage_1972` 73→3, positionally concentrated in
  the last 20%; `joyce_1999` 4→5, page-119/217 `ocrmypdf` remediation) as an established
  evidentiary base rather than re-deriving them from a fresh `pymupdf4llm` conversion, given their
  level of forensic specificity and the cost of reconverting two 300+-page scanned books within a
  research-phase budget. Independent corroboration was instead sought elsewhere in the already-
  existing codebase (test fixtures, module docstrings, corpus index) rather than by repeating the
  original measurement.
- Resolved the task's "two candidate framings, not mutually exclusive" open question by proposing
  a single mechanistic discriminator (defect origin: primary-tier structuring heuristic vs.
  text-layer) that subsumes both framings, rather than picking one framing over the other or
  presenting them as an unresolved tie.
- Scoped the docstring edit recommendation narrowly to the remedy sentence only, leaving the
  "never widen/tune/override" prohibition text byte-for-byte intact, per the explicit
  coordination instruction that task 104 alone is permitted to narrow the prohibition.
- Declined to propose any auto-selection mechanism, consistent with the task's explicit scope
  discipline; documented why the discriminator found here does not currently support one.

## Risks & Mitigations

- **Risk**: the suggested docstring replacement text is a recommendation, not something this
  research phase applied directly (this is a `meta`-type task; the edit belongs to planning/
  implementation). **Mitigation**: the replacement text above is written as a drop-in block with
  exact surrounding context (the unchanged lines before and after) so the implementer can apply it
  verbatim or adapt it, and it explicitly flags where task 104's own edit must reconcile.
- **Risk**: `bacon_dorr_2024_classicism`'s born-digital status is inferred from genre/co-fixture
  grouping (contemporary LaTeX-typeset metaphysics papers) rather than a `source_format`/`scanned`
  field the index does not carry. **Mitigation**: stated as "very likely born-digital" rather than
  asserted as certain, and the core finding (fallback fixes a `<sup>`-span defect unrelated to
  OCR) does not depend on certainty about scan status — it depends on the defect's documented
  cause (a markdown-structuring heuristic, not an OCR artifact), which is independent of
  provenance either way.
- **Risk**: only two anchor cases plus two corroborating cases quantify Class A, and only one case
  (`joyce_1999`) quantifies Class B — a thin evidentiary base for a permanent codebase claim.
  **Mitigation**: the recommended docstring/guide wording states the mechanism (why fallback helps
  or doesn't) rather than a bare tally of cases, so it remains correct even if future documents add
  more examples to either class; it does not claim exhaustiveness.

## Context Extension Recommendations

- **Topic**: Converter tier selection guidance for `LITERATURE_CONVERTER`.
- **Gap**: `context/guides/literature-organization.md` documents the chunking/indexing workflow in
  detail but has zero coverage of converter-tier selection; the only existing documentation is the
  operational (not decision-guidance) header comment in `literature-convert.sh`.
- **Recommendation**: add the `## Converter Tier Selection` section proposed in Recommendation 3
  above, and cross-link it from `README.md`. This is this task's own deliverable 3, restated here
  per the report-format convention for tracking documentation gaps found during research.

## Appendix

- Search queries / commands used: `grep -rn LITERATURE_CONVERTER agent-system/extensions/
  literature/`; `grep -rn bacon_dorr agent-system/extensions/literature/ specs/`; corpus directory
  listings and `index.json` lookups under `~/Projects/Literature/` for `savage_1972`, `joyce_1999`,
  `bacon_dorr_2024_classicism`, and the Goldblatt/Hodkinson/Venema authors; `specs/TODO.md` entries
  for tasks 102, 104, 105, 107 for cross-task coordination constraints.
- Key file references: `agent-system/extensions/literature/scripts/literature_quality_gate.py:
  150-166` (function docstring naming the Goldblatt/Hodkinson/Venema origin case),
  `:224-241` (the MIXED-documents note and the falsified remedy claim), `agent-system/extensions/
  literature/scripts/literature-convert.sh:20-47,328-347,355-378` (tier definitions and `auto`
  engine-availability fallback logic), `agent-system/extensions/literature/scripts/tests/
  test-quality-gate-notation.sh:1-101` (five-fixture regression harness naming
  `bacon_dorr_2024_classicism` as an already-remediated fallback-tier true positive).
