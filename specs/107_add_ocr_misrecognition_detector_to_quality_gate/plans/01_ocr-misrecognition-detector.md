# Implementation Plan: Task #107

- **Task**: 107 - Add an OCR-misrecognition detector to the literature quality gate
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: Task 102 (converter-tier characterization, COMPLETED), Task 104 (glue-check false-positive class, COMPLETED), Task 105 (OCR tier, COMPLETED)
- **Research Inputs**: specs/107_add_ocr_misrecognition_detector_to_quality_gate/reports/01_ocr-misrecognition-detector.md
- **Artifacts**: plans/01_ocr-misrecognition-detector.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

**The content-based OCR-misrecognition detector this task is titled after was not built, and this
plan does not build it.** Research measured four progressively refined content signals against 11
known scan-pipeline documents and 6 born-digital dense-math negative controls, and none separated
the two groups: negative controls repeatedly scored equal to or higher than genuine positives
(`blackburn_2002`, a real Acrobat Image Conversion scan, scored 15.69/10k while born-digital
`venema_2007` scored 153.95/10k and `ahrens_north` 306.22/10k; at Round 4's narrowest refinement
`blackburn_2002` was still at 2.70/10k against `ahrens_north`'s 84.55/10k). Each refinement round
closed exactly one false-positive class (proper nouns, then typographic quotes, then citation
codes/diacritics/LaTeX leakage, then dash/slash compounds and HTML leakage) and exposed a
different one. This is a measured negative result, and the task description pre-authorized it as a
complete outcome.

What this plan implements instead is the provenance-only fallback the research recommends:
promote the existing scan-pipeline Creator/Producer regex — which already lives, duplicated, in
`literature-fidelity-audit.sh` — into an importable `scan_pipeline_provenance(creator, producer)`
in the shared `literature_quality_gate.py` module, have the fidelity audit consume it instead of
its own copy, and add a **non-blocking advisory** line to `literature-convert.sh`'s
`run_quality_gate()`. Provenance is the one signal that works cleanly on this corpus: 11 of 74
PDFs match, with zero observed false positives among the other 63. Definition of done: one shared
function with self-test coverage, one deduplicated consumer, one advisory that can never reject a
conversion, and a durable written record of the negative result so nobody rebuilds the dead end.

### Research Integration

- The corpus has **11** scan-pipeline PDFs, not the 7 the task description asserted. The undercount
  came from `pdfinfo | grep` without `-a`: Acrobat Capture embeds a literal NUL byte at the end of
  its Creator/Producer strings, which silently breaks bash grep matching. **Every implementation
  path in this plan reads this metadata via Python** (`fitz.Document.metadata`, or
  `subprocess.run(..., text=True)`), never a bash grep pipeline. Phase 2 locks this in with a
  NUL-bearing self-test fixture.
- `literature-fidelity-audit.sh` already contains this exact check (`SCAN_SOURCE_SIGNATURE_RE` +
  `scan_source_check()`), and its own docstring frames it as a placeholder for "a separate,
  not-yet-built detector['s]... broader, content-based detection." Phase 3 updates that docstring:
  the broader detector was evaluated and found non-viable, so the metadata-only check is very
  likely the ceiling, not a stepping stone.
- The regex moves **byte-identical** (`r"capture|finereader|image conversion"`, `re.IGNORECASE`,
  applied to `f"{creator}|{producer}"`). Widening it is a separate, unvalidated change and is
  explicitly out of scope.
- The function takes **extracted metadata strings, not a `fitz.Document`**, preserving
  `literature_quality_gate.py`'s stated module invariant that every check in it needs no PDF
  access at all.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` in the delegation context).

### Coordination With Concurrent Work

- **Task 105** added a non-auto `LITERATURE_CONVERTER=ocr` mode with a `LITERATURE_OCR_FORCE=1`
  opt-in, and a shared `ocr_remedy_command(pdf_path, force=...)` emitter in
  `literature-convert.sh`. Phase 4's advisory text must point at that existing remedy by calling
  `ocr_remedy_command()`, never by hand-writing a parallel command string.
- **Task 104** appended docstring text to `sentence_boundary_glue_count()` in
  `literature_quality_gate.py` and a resolved-example paragraph to `## Converter Tier Selection`
  in `literature-organization.md`. Phases 1 and 5 touch both files. Locate edit points by anchor
  text and leave that text byte-identical.

## Goals & Non-Goals

**Goals**:
- One importable `scan_pipeline_provenance(creator, producer)` in the source-store
  `literature_quality_gate.py`, with self-test coverage including a NUL-bearing input.
- `literature-fidelity-audit.sh` consuming that function instead of its own duplicate regex, with
  its existing fail-open contract preserved exactly.
- A distinctly-labeled, non-blocking advisory line in `literature-convert.sh`'s
  `run_quality_gate()` that never enters the `reasons` list.
- A durable written record — in repository documentation, not only in a task report — that
  content-based OCR-misrecognition detection was evaluated across four measurement rounds and
  found non-viable on this corpus, with the specific false-positive classes named.

**Non-Goals**:
- Building any content-based OCR-misrecognition detector. Four rounds of measurement did not
  produce a threshold the evidence supports; manufacturing one is out of scope.
- Any gate rejection, exit-3 contribution, or withheld certification based on scan provenance.
- Any converter-tier auto-selection based on scan provenance. Task 102 established with
  counter-examples (`savage_1972` and `joyce_1999`, both scans, opposite fallback-tier outcomes)
  that scan provenance does not predict remedy.
- Widening the signature regex beyond `capture|finereader|image conversion`.
- Running a fresh `ocrmypdf`/Tesseract comparison pass (see Future Work below).

### Future Work (recorded, not scoped here)

A genuinely independent second extraction — comparing the existing text layer against a **fresh**
`ocrmypdf`/Tesseract pass on the same page images — would sidestep the blind spot both existing
engine tiers share (they read the same already-degraded `fitz`-extracted text layer, which is why
`joyce_1999`'s fallback-tier reconversion did not fix its defect). Both binaries are on PATH. It
is deliberately excluded here for the same cost reason task 105 kept `LITERATURE_CONVERTER=ocr`
explicit-only: a full Tesseract pass over a 70-page document is a document-scale, minutes-long
operation. It belongs in an on-demand audit command, not the automatic per-conversion gate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The advisory is misread by an operator as "this document is broken" — it will fire on 11 of 74 corpus documents | M | H | Phase 4 fixes the wording contract: "scan-pipeline provenance detected — recommend manual spot-check", explicitly followed by "not a quality-gate failure". Never the words "defect" or "failed". |
| The advisory leaks into `reasons` and trips the exit-3 `QUALITY GATE FAILED` path (entered whenever `reasons` is non-empty) | H | M | Phase 4 emits via `print(..., file=sys.stderr)` only, never `reasons.append`. Phase 6 asserts a clean exit 0 on a scan-metadata fixture. |
| The new stderr line collides with an existing marker-discriminated grep — task 105's `literature-ingest.sh` dispatch matches on `NO TEXT LAYER:` | H | M | Phase 4 enumerates every stderr consumer and greps each for a substring that could match the new line before choosing final wording; the advisory uses the distinct `ADVISORY:` token. |
| The negative result gets dropped from the record and someone rebuilds the same dead end | M | M | Phase 5 writes it into `literature-organization.md` with the false-positive classes and the key numbers, self-contained (see the task-reference constraint below). |
| Removing `SCAN_SOURCE_SIGNATURE_RE` breaks an unnoticed consumer | M | L | Phase 3 runs a repo-wide grep for the constant name before removal and reports the hit set. |
| Two separate import sites of `literature_quality_gate` exist in `literature-convert.sh` (self-test heredoc and live heredoc) and only one gets the new symbol | M | M | Phases 2 and 4 each name their own import site explicitly; Phase 6 exercises both entry points. |
| An edit lands in `.claude/` instead of the source store and is silently wiped by the next regeneration | H | M | Every phase names its path under `agent-system/extensions/literature/`; Phase 6 verifies no `.claude/**` file was modified. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Promote the provenance regex into the shared gate module [COMPLETED]

**Goal**: `literature_quality_gate.py` exposes an importable `scan_pipeline_provenance(creator,
producer)` with behavior byte-identical to `literature-fidelity-audit.sh`'s existing inline check.

**Tasks**:
- [x] Add a module-level compiled constant next to the module's other regex constants:
      `re.compile(r"capture|finereader|image conversion", re.IGNORECASE)`. Do not widen the
      pattern; do not add `scan` or `abbyy` as bare alternatives. *(completed)*
- [x] Add `scan_pipeline_provenance(creator, producer) -> bool`, applying that regex to
      `f"{creator}|{producer}"`. Coerce `None` to `""` for both arguments so a caller passing a
      missing metadata key cannot raise. *(completed)*
- [x] Write the function docstring to record three things: (a) it is provenance-only and takes
      metadata strings rather than a `fitz.Document`, preserving this module's stated
      "every check needs no PDF access at all" invariant; (b) it is a bounded known-signature
      allowlist and is expected to miss a scan pipeline whose tool string is not in the list
      (accepted gap); (c) a `True` result is advisory — it must never drive a gate rejection, a
      withheld certification beyond what already exists, or a converter-tier selection. *(completed)*
- [x] Append a short paragraph to the module docstring noting this is the first non-content check
      in the module and why it still belongs here (both `literature-convert.sh` and
      `literature-fidelity-audit.sh` need it, and it still needs no PDF access). *(completed)*
- [x] Confirm `sentence_boundary_glue_count()`'s docstring is byte-identical to before the edit
      (`git diff` on that hunk must be empty). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — new module constant,
  new function, additive module-docstring paragraph.

**Verification**:
- `cd agent-system/extensions/literature/scripts && python3 -c "import literature_quality_gate as m; print(m.scan_pipeline_provenance('Acrobat 3.0 Capture Plug-in', 'Acrobat 3.0 Import Plug-in'), m.scan_pipeline_provenance('pdfTeX-1.40.20', 'pdfTeX-1.40.20'), m.scan_pipeline_provenance(None, None))"`
  prints `True False False` with no warnings.
- `git diff -- agent-system/extensions/literature/scripts/literature_quality_gate.py` shows only
  additive hunks; no line inside `sentence_boundary_glue_count()` changed.

---

### Phase 2: Self-test fixtures for the new function [NOT STARTED]

**Goal**: The `--self-test` gate-fixture block exercises `scan_pipeline_provenance` in both
directions, including the NUL-byte case that defeated the original bash detection.

**Tasks**:
- [ ] Add `scan_pipeline_provenance` to the `from literature_quality_gate import (...)` list in
      the **self-test heredoc's** import block in `literature-convert.sh` (the earlier of the two
      import sites in this file — the one preceding the `gate_check()` helper, not the live
      conversion heredoc's).
- [ ] Add `gate_check(...)` fixtures using the real Creator/Producer strings measured in research:
      positives `Acrobat 3.0 Capture Plug-in`, `Acrobat 4.0 Capture Plug-in for Windows`,
      `ABBYY FineReader` (with an empty Producer), and
      `Adobe Acrobat 7.0 Image Conversion Plug-in`.
- [ ] Add negative fixtures: a pdfTeX Creator/Producer pair, a cairo pair, and the
      empty-string/`None` pair.
- [ ] Add the regression-lock fixture: a Creator string with a trailing NUL byte
      (`"Acrobat 3.0 Capture Plug-in\x00"`) must still return `True`. Comment it with why it
      exists — Acrobat Capture embeds a literal NUL that silently truncates bash `$(...)` +
      `grep` matching, which is how the corpus scan count was undercounted; Python string
      handling is immune, and this fixture is what keeps the check on the Python path.
- [ ] Add a negative fixture proving the regex is not accidentally matching a substring of a
      common born-digital producer string.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts one edited file and roughly 8 new fixture assertions in
one `gate_check` block. Confirm at implementation time by locating the `gate/` fixture block via
its `def gate_check(name, cond, detail="")` anchor and counting the added assertions; if the
self-test import block turns out to already carry the symbol, or the fixture block has moved,
report the actual shape rather than forcing the estimate.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` — self-test heredoc import
  list and gate-fixture block only. No change to the live conversion heredoc in this phase.

**Verification**:
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` exits 0 and
  prints a `PASS: gate/...` line for every new fixture.
- Temporarily reverting the Phase 1 function body to always return `False` makes the positive
  fixtures fail (confirming the assertions are live, not vacuous); restore afterwards.

---

### Phase 3: Fidelity audit consumes the shared function [NOT STARTED]

**Goal**: `literature-fidelity-audit.sh` has exactly one definition of the scan-source signal —
the shared one — with its fail-open contract and its seven-value enum behavior unchanged.

**Tasks**:
- [ ] Run `grep -rn 'SCAN_SOURCE_SIGNATURE_RE' agent-system/ .claude/ specs/` and record the hit
      set before removing anything. If any consumer outside `literature-fidelity-audit.sh` exists,
      stop and report rather than removing.
- [ ] Add `from literature_quality_gate import scan_pipeline_provenance` to the audit heredoc,
      after the existing `sys.path.insert(0, os.environ["LITERATURE_SCRIPT_DIR"])` line.
      Use a **plain, unguarded import**, not the `try/except ImportError` graceful-degrade shape
      used a few lines above for `literature_combining_detect`. Rationale to record in a comment:
      that guard exists because the combining module carries a PyMuPDF dependency;
      `literature_quality_gate` imports only `re` and `unicodedata`, ships in the same scripts
      directory, and is already imported unguarded by `literature-convert.sh`. A silent
      ImportError degrade here would turn the scan gate off and let documents fall through to the
      certifying ratio branch — the wrong failure direction to make silent.
- [ ] Delete the module-level `SCAN_SOURCE_SIGNATURE_RE` constant and its comment block.
- [ ] Rewrite `scan_source_check(pdf_path)`'s body to call `scan_pipeline_provenance(creator,
      producer)` on the strings it already parses out of `pdfinfo` output. Keep its
      `subprocess.run(..., text=True)` call, its 30s timeout, its `try/except` + stderr warn, and
      its `return False` failure default exactly as they are — the docstring's explanation of why
      `False` is the safe default (the check is only a gate ahead of the ratio branch, so an
      unevaluable gate falls through to today's behavior) stays accurate and must be preserved.
- [ ] Move the "single extension point for widening or replacing the scan-source signal" comment
      to point at `literature_quality_gate.scan_pipeline_provenance` as the new home.
- [ ] Update the script header's signal-2 description: the sentence currently reading that broader
      content-based detection is "a separate, not-yet-built detector's scope" must be replaced
      with the measured finding — content-based OCR-misrecognition detection was evaluated across
      four refinement rounds against 11 known scan-pipeline documents and 6 born-digital
      dense-math controls and did not separate the two groups at any threshold, so this
      metadata-only check is very likely the ceiling rather than a placeholder. Do not cite a
      task number or a `specs/` path here (see Phase 5's constraint note).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — import line,
  constant removal, `scan_source_check()` body, two comment blocks, header docstring.

**Verification**:
- `grep -rn 'SCAN_SOURCE_SIGNATURE_RE' agent-system/` returns no hits.
- `python3 -c` harness importing the audit heredoc's logic is not practical; instead run the audit
  script in its read-only/report mode against the corpus and confirm the
  `unverified_scan_source` verdict count is unchanged from a pre-edit baseline run captured before
  the first edit of this phase. Record both counts in the phase progress notes.
- The `classify_dir()` call site `if any(scan_source_check(p) for p in pdfs):` is untouched.

---

### Phase 4: Non-blocking advisory in the conversion quality gate [NOT STARTED]

**Goal**: A conversion of a scan-pipeline PDF prints a distinctly-labeled advisory to stderr and
still exits 0. Nothing about the exit-3 rejection path changes.

**Tasks**:
- [ ] Enumerate the stderr consumers of `literature-convert.sh` before choosing wording:
      `literature-ingest.sh` (task 105's marker-discriminated `NO TEXT LAYER:` dispatch),
      `literature-ingest-online.sh`, and `scripts/tests/test-literature-convert.sh`. Grep each for
      substrings of the candidate advisory line and confirm no existing matcher can fire on it.
      The line uses the distinct token `ADVISORY:`.
- [ ] Add `scan_pipeline_provenance` to the `from literature_quality_gate import (...)` list in
      the **live conversion heredoc's** import block (the later of the two import sites, the one
      adjacent to `from literature_combining_overlay import compose_combining_overlays`).
- [ ] In `run_quality_gate(content, doc)`, read `doc.metadata` defensively — it can be `None` for
      some documents — and extract `creator`/`producer` with `.get(..., "")`. Wrap the read in a
      `try/except` that degrades to no advisory on any failure: an unreadable metadata dict must
      never break a conversion that would otherwise succeed.
- [ ] When `scan_pipeline_provenance(...)` is `True`, `print(..., file=sys.stderr)` a single
      advisory line. Required wording properties: it says scan-pipeline provenance was detected
      from Creator/Producer metadata; it says "recommend manual spot-check"; it says explicitly
      that this is **not** a quality-gate failure; and it names the re-OCR remedy by calling the
      existing `ocr_remedy_command(pdf_path, force=True)` helper rather than hand-writing a
      command string. It must not contain the words "defect", "corrupt", or "FAILED".
- [ ] Add an inline comment above the block stating the two prohibitions: this must never be
      appended to `reasons` (which drives the exit-3 path), and it must never feed converter-tier
      selection — scan provenance does not predict which remedy, or whether any remedy, a document
      needs.
- [ ] Confirm by reading the diff that `reasons` is not touched anywhere in the new code.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` — live heredoc import list
  and `run_quality_gate()` body.

**Verification**:
- `git diff` on `run_quality_gate()` contains no new `reasons.append`.
- A conversion of a clean born-digital PDF prints no `ADVISORY:` line and still exits 0.
- The grep sweep from task 1 of this phase is recorded with its hit counts (expected: zero
  matchers capable of firing on the advisory line).

---

### Phase 5: Record the negative result and refresh the index [NOT STARTED]

**Goal**: The measured negative result and the provenance-only fallback are discoverable from
repository documentation alone, without reading a task report.

**Tasks**:
- [ ] Add a subsection to `context/guides/literature-organization.md` adjacent to
      `## Converter Tier Selection`, recording: (a) content-based OCR-misrecognition detection was
      evaluated and found non-viable on this corpus; (b) the four signal families tried
      (whole-document OOV rate, whole-document mixed-alnum-symbol density, prose-line-restricted
      anomaly rate, embedded-corruption-token rate); (c) the decisive numbers — a genuine
      Acrobat Image Conversion scan scored 15.69/10k while born-digital controls scored 153.95 and
      306.22/10k, and at the narrowest refinement the same scan scored 2.70/10k against a
      born-digital 84.55/10k; (d) the false-positive classes that defeated each round (proper
      nouns, typographic quotes, citation-year author codes and combining-mark diacritics and
      LaTeX macro leakage, em/en-dash and slash compounds and inline HTML sub/superscript
      leakage); (e) that provenance-only flagging is the fallback and is advisory, never a
      rejection or a tier selector; and (f) the fresh-OCR-pass direction as the one untried
      avenue, with its document-scale cost named.
- [ ] **Constraint**: this file is outside `specs/**`, so the note must be self-contained. Do not
      write "task 107", "see task N", or a `specs/107_.../reports/...` path — a `specs/` artifact
      path embeds a task number. State the findings and numbers inline instead.
- [ ] Locate the insertion point by the anchors task 104 left in this section (the Diagnostic
      procedure bullets, the resolved-example paragraph, and the "No automatic tier selection"
      paragraph) and leave all of that text byte-identical.
- [ ] Update `context/project/literature/patterns/provenance-fidelity.md`'s scan-source-gate
      signal description: the regex now lives in `literature_quality_gate.scan_pipeline_provenance`
      and is shared with the conversion pipeline's advisory; content-based detection was evaluated
      and found non-viable. Same no-task-reference constraint.
- [ ] Refresh `index-entries.json` `line_count` for both edited context files, verified against
      `wc -l`, and add keywords covering the new material (e.g. `scan_pipeline_provenance`,
      `ocr-misrecognition`, `provenance-advisory`).

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts three edited files (two context docs plus
`index-entries.json`). Confirm at implementation time by grepping the extension for other places
describing the scan-source signal or the not-yet-built content detector
(`grep -rn 'not-yet-built\|scan-source\|scan_source' agent-system/extensions/literature/context/`)
and extend the file set if that grep finds additional stale text.

**Files to modify**:
- `agent-system/extensions/literature/context/guides/literature-organization.md`
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
- `agent-system/extensions/literature/index-entries.json`

**Verification**:
- `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
  task-number references outside `specs/**`.
- `wc -l` on both edited context files matches their `line_count` entries.
- `python3 -c "import json; json.load(open('agent-system/extensions/literature/index-entries.json'))"`
  succeeds.

---

### Phase 6: Regression tests and full gate run [NOT STARTED]

**Goal**: The advisory's non-blocking property is locked in by a test, and the whole literature
test surface is green.

**Tasks**:
- [ ] Add a `scan-metadata` fixture arm to `scripts/tests/generate-test-fixtures.py` building a
      small valid PDF with a real text layer whose Creator/Producer are set to a scan-pipeline
      signature (via PyMuPDF `set_metadata`). It must be a document that otherwise passes every
      existing gate check, so the test isolates the advisory.
- [ ] Add assertions to `scripts/tests/test-literature-convert.sh`: converting that fixture emits
      a line containing `ADVISORY:` and `scan-pipeline provenance`; the exit code is **0**, not 3;
      no `.rejected` file is written; and the `Quality gate: PASSED` line is still printed.
- [ ] Add the negative assertion: converting an existing born-digital fixture emits no `ADVISORY:`
      line.
- [ ] Add the ingest-bucketing assertion: `literature-ingest.sh` processing the scan-metadata
      fixture does not bucket it as needs-OCR or as a hard failure — the advisory must not
      disturb task 105's marker-discriminated dispatch.
- [ ] Run the full suite: `--self-test`, `test-literature-convert.sh`,
      `test-quality-gate-notation.sh`, `test-literature-build-index.sh`, and a fidelity-audit run
      compared against the Phase 3 baseline.
- [ ] Verify no file under `.claude/**` was modified: `git status --short | grep '^.*\.claude/'`
      returns nothing.

**Timing**: 1.25 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py`
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`

**Verification**:
- All four test scripts exit 0.
- The new advisory assertions fail when the Phase 4 print statement is temporarily removed
  (confirming they are live); restore afterwards.
- `git status --short` shows changes only under `agent-system/extensions/literature/` and
  `specs/107_*/`.

---

## Testing & Validation

- [ ] `literature-convert.sh --self-test` passes, including all new `gate/scan-pipeline-*` fixtures
      and the NUL-byte regression lock.
- [ ] `test-literature-convert.sh` passes, including the new advisory assertions (fires on a
      scan-metadata fixture, exit 0, no `.rejected`; silent on a born-digital fixture).
- [ ] `test-quality-gate-notation.sh` and `test-literature-build-index.sh` pass unchanged.
- [ ] `literature-fidelity-audit.sh` produces the same `unverified_scan_source` verdict count as
      the pre-edit baseline.
- [ ] `grep -rn 'SCAN_SOURCE_SIGNATURE_RE' agent-system/` returns nothing.
- [ ] No new task-number reference outside `specs/**`.
- [ ] No file modified under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — new
  `scan_pipeline_provenance()` + module constant.
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — deduplicated
  consumer, updated header docstring.
- `agent-system/extensions/literature/scripts/literature-convert.sh` — self-test fixtures + live
  non-blocking advisory.
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` — `scan-metadata`
  fixture arm.
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` — advisory
  regression assertions.
- `agent-system/extensions/literature/context/guides/literature-organization.md` — negative-result
  record.
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
  — updated signal description.
- `agent-system/extensions/literature/index-entries.json` — refreshed line counts and keywords.
- `specs/107_add_ocr_misrecognition_detector_to_quality_gate/summaries/01_ocr-misrecognition-detector-summary.md`

## Rollback/Contingency

Every phase is additive or a pure move within a single extension directory, and each is committed
separately, so `git revert` of an individual phase commit restores the prior state without
touching the others. Two ordering notes:

- Phase 3 removes `SCAN_SOURCE_SIGNATURE_RE`, so reverting Phase 1 without also reverting Phase 3
  leaves the audit importing a symbol that no longer exists. Revert Phase 3 first, or revert both
  together.
- Phases 4 and 6 are independently revertible: dropping the advisory print leaves a shared
  function with no conversion-side consumer, which is a valid resting state (the fidelity audit is
  still a consumer).

If Phase 3's baseline verdict-count comparison diverges, stop and report rather than adjusting the
regex — a divergence means the move was not behavior-preserving, which is the one thing this phase
promises.
