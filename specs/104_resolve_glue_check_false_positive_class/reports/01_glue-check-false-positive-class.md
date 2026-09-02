# Research Report: Task #104

**Task**: 104 - Resolve glue-check false-positive class on math-heavy OCR'd scans
**Started**: 2026-09-01T00:00:00Z
**Completed**: 2026-09-01T01:30:00Z
**Effort**: research
**Dependencies**: Task 102 (completed)
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py`
- `agent-system/extensions/literature/scripts/literature-convert.sh`
- `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh`
- `agent-system/extensions/literature/context/guides/literature-organization.md`
- `specs/102_characterize_converter_tiers_and_ocr_vintage/reports/01_converter-tier-characterization.md`
- `specs/102_characterize_converter_tiers_and_ocr_vintage/summaries/01_correct-converter-tier-remedy-claim-summary.md`
- `specs/TODO.md` (task 104/105/107 descriptions)
- `~/Projects/Literature/index.json`, `~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/`
- System check: `which ocrmypdf`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Route (a) — improve the input via targeted re-OCR — is selected.** It resolves the practical
  ingestion blocker with **zero changes** to `sentence_boundary_glue_count()`, its exemption
  regexes, or the threshold-3 cutoff, fully satisfying the file's existing prohibition rather
  than requiring any narrowing of it.
- **The decisive arithmetic**: `joyce_1999`'s 4 hits = 2 genuine text-layer defects + 2
  math-notation false hits. Re-OCR of just the two defective pages (119, 217) — already proven at
  page level in the task's own supplied evidence — eliminates both genuine defects and adds no
  new hits. That alone drops the count to **2**, which is below the `>=3` reject threshold. The
  two notation hits never need to be exempted, matched, or otherwise addressed by the gate.
- **Route (b)** (a narrowly-scoped math-notation regex exemption) is rejected: the two
  false-positive strings are garbled OCR artifacts with no shared, generalizable shape to extend
  the existing binder/hat regex family with. Any pattern covering them either overfits to these
  two exact strings or risks the pinned over-exemption tripwires, for no benefit since route (a)
  already solves the problem risk-free.
- **Route (c)** (a distinct calibration class for scanned/OCR'd documents) is rejected: it
  contradicts task 102's own finding that "scanned vs. born-digital" is not the discriminator,
  and the two MIXED documents (`hott_book_2013`, `ahrens_north`) are themselves scanned/OCR'd
  math texts whose genuine corruption must stay rejected — a class-keyed threshold bump for
  "scanned/OCR'd" risks masking exactly that.
- **Reconciliation**: the prohibition at `literature_quality_gate.py:252` ("never widening this
  exemption further, tuning the threshold-3 cutoff, or a manual override") is not being narrowed
  by this task — route (a) doesn't touch any of the three things it forbids. Recommend appending
  a closing note to the same paragraph recording the resolution, plus a one-line pointer in the
  guide doc, rather than altering the prohibition's substance.
- **Adjacent-scope flag**: `~/Projects/Literature/index.json` already carries a
  `joyce_1999_foundations-causal-decision-theory` entry (396 chunks, `metadata_status:
  "unresolved"`), which appears to predate task 106's gated-pipeline fix. This contradicts the
  task description's "cannot be ingested at all" framing and should be surfaced to the planner,
  not silently resolved by this task.

## Context & Scope

Task 104 is scoped to resolve the false-positive class `sentence_boundary_glue_count()` produces
on `joyce_1999_foundations-causal-decision-theory` (296pp scan, 654,128 extracted chars, 4 hits,
rejected at the `>=3` gate threshold), where the two real defects are genuine missing
inter-sentence spaces but the other two hits are inline math notation, and the documented
fallback-tier remedy (`LITERATURE_CONVERTER=fallback`) provably makes it worse (4 hits -> 5). The
task explicitly required evaluating three named routes without presupposing any of them, and
required whichever route wins to reconcile with the "never widen/tune/override" prohibition
already present in the gate module's docstring — narrowing that prohibition only if the winning
route requires it.

Task 102 (completed, dependency of this task) already amended the docstring's *remedy* claim from
a false universal-remedy assertion to a Class A (primary-tier structuring artifact, fixed by the
fallback tier) / Class B (text-layer defect, unaffected by tier choice) framing, naming
`joyce_1999` as the confirmed Class B counterexample, and added a `## Converter Tier Selection`
section to `context/guides/literature-organization.md` documenting re-OCR as the Class B remedy.
This report builds on that framing rather than re-deriving it, and treats the task description's
quoted "for a document like this... never widening..." sentence as the **pre-102** text — the
live file no longer contains that exact wording (see Findings).

## Findings

### Codebase Patterns

**Current docstring state** (`literature_quality_gate.py:150-252`, post-task-102): the
MIXED-documents paragraph (`:224-252`) already states the Class A/B framing and the `joyce_1999`
4->5 fallback-tier counterexample, ending with the prohibition clause at line 252: "never widening
this exemption further, tuning the threshold-3 cutoff, or a manual override." The task
description's verbatim quote of "The correct operator remedy for a document like this is
reconversion with `LITERATURE_CONVERTER=fallback`..." is the **pre-102** sentence task 102 already
replaced (confirmed via its own summary, which records the prohibition clause preserved
byte-for-byte across that edit). The prohibition itself is unscoped by any "document like this"
qualifier in the current text — that qualifier belonged to the sentence task 102 removed.

**The decisive count breakdown**: of `joyce_1999`'s 4 `[a-z]\.[A-Z]` hits, 2 are genuine missing
spaces after a sentence period (pages 119 and 217) and 2 are inline math notation (Stalnaker's
Equation fragment `"^s.P(S\A)u(0[A S])"`, and a garbled matrix-predicate fragment `"f.I+i p*(
YHr"`). The task's own supplied evidence demonstrates, at page level (not merely hypothesized),
that `ocrmypdf --force-ocr --output-type pdf -l eng` on pages 119 and 217 individually eliminates
both genuine defects and introduces zero new `[a-z]\.[A-Z]` hits on those pages — recovering a
dropped closing curly quote (page 119) and an accented "Reyni" (page 217) that the original 2019
archive.org OCR pass had lost. Since the gate's threshold is `>=3`, fixing only the 2 genuine
defects brings the total to 2 (the 2 notation hits, untouched, on different pages) — **below** the
reject threshold. No code path in the gate needs to change for `joyce_1999` to pass.

**Pinned tripwires constraining route (b)** (`scripts/tests/test-quality-gate-notation.sh:79-111`):
`hott_book_2013` must remain at exactly 11 hits and `ahrens_north` at exactly 21 — described in the
harness as "over-exemption tripwires [that] must never fall" (rise, for these two — see the
substitution-self-interference note below). The docstring
(`literature_quality_gate.py:174-183`) records a prior widening attempt (a blanket global
markdown-underscore strip preprocessing pass) that increased one MIXED document from 11 to 26 hits
via substitution self-interference — deleting matched spans glued previously non-adjacent
characters into brand-new spurious matches. The current three-pattern exemption family
(`_PREFIX_BINDER_RE`, `_PREFIX_HAT_RE`, `_strip_postfix_hat`/`_POSTFIX_HAT_TAIL_RE`) deliberately
avoids a separate global-strip pass for exactly this reason, matching noise-tolerant runs directly
within each exemption regex.

**Shape mismatch for route (b)'s target strings**: the existing exemption family targets clean,
structurally regular notation — `∀x.`, `∃y.`, `λx1 . . . xn.`, `ˆx.` (a Unicode modifier-letter
circumflex, not ASCII `^`) — with a bounded lowercase-variable run between binder and period.
`joyce_1999`'s two false positives are garbled OCR output of a rendered equation and a
matrix-predicate expression, not clean binder syntax: `"^s.P(S\A)u(0[A S])"` uses an ASCII caret in
an unrelated position, and `"f.I+i p*( YHr"` has no binder/quantifier glyph at all. There is no
common structural shape between these two strings and the existing three patterns' target shapes
to extend the regex family with; a pattern loose enough to catch both would need to match
essentially arbitrary lowercase-letter-dot-uppercase-letter runs bounded by punctuation/space
noise, which is very close to the raw `[a-z]\.[A-Z]` pattern the check exists to catch.

**Route (c)'s premise is the premise task 102 falsified**: task 102 established, via the
`savage_1972`/`joyce_1999` pair, that "scanned vs. born-digital" does not predict fallback-tier
behavior (`savage_1972` scanned and rescued 73->3; `joyce_1999` scanned and worsened 4->5;
`bacon_dorr_2024_classicism` very-likely born-digital and rescued). The real discriminator found
was defect origin (primary-tier structuring artifact vs. text-layer defect), which task 102's own
recommendation section states explicitly is **not** a cheap a-priori document-metadata predicate —
it requires inspecting where post-conversion hits fall. `hott_book_2013` and `ahrens_north` are
themselves scanned/OCR'd mathematical texts whose hits are dominated by genuine `<sup>`-span
fusion corruption; either document would fall inside any "scanned/OCR'd" calibration class
alongside `joyce_1999`, so a class-keyed threshold increase risks un-rejecting documents the gate
is correctly rejecting today.

**Ocrmypdf availability**: `ocrmypdf` is already installed system-wide
(`/run/current-system/sw/bin/ocrmypdf`) — the targeted 2-page fix requires no new dependency or
provisioning work beyond what the task's own supplied evidence already exercised.

**Adjacent finding — `joyce_1999` is already present in the live corpus index**: contrary to task
102's report ("joyce_1999 has no index entry at all") and the task description's "rejected
outright, so it cannot be ingested at all" framing, `~/Projects/Literature/index.json` currently
carries an entry for `joyce_1999_foundations-causal-decision-theory` (396 chunks,
`metadata_status: "unresolved"`), and 396 `chunk_*.md` files exist on disk under
`~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/`. Task 106 ("Route
skill literature convert through gated pipeline," now `[COMPLETED]`) documents that
`skill-literature`'s `/literature <path>` ingest path bypassed the quality gate entirely prior to
its fix, using `pdftotext -layout` directly with no gate call. The most likely explanation is that
this corpus copy was ingested via that pre-106 ungated path, never through the gated
`literature-convert.sh` CLI the 4-hit rejection was measured against. This is flagged as adjacent
scope for the planner, not resolved here.

### External Resources

Not applicable — this is a codebase-internal policy-resolution task with no external dependency.

### Recommendations

**1. Select route (a).** No change to `sentence_boundary_glue_count()`, its exemption regexes, or
the threshold-3 cutoff is required. The fix is entirely at the input layer: targeted re-OCR of the
two specific defective pages (119, 217) of `joyce_1999`'s source PDF via `ocrmypdf --force-ocr
--output-type pdf -l eng`, applied narrowly to those pages rather than the whole 296-page document
— minimizing blast radius, since a full-document re-OCR is unproven and could introduce new
artifacts on currently-clean pages. Reconvert afterward and confirm the gate now reports 2 hits
(below threshold).

**2. Reconcile the docstring by addition, not narrowing.** Append a short closing note to the
existing MIXED-documents paragraph (`literature_quality_gate.py:224-252`, after the current
`joyce_1999` 4->5-fallback sentence, before the prohibition clause) recording:
   - The resolution: `joyce_1999`'s two genuine defects were an artifact of the original 2019
     archive.org OCR text layer (already stated); targeted re-OCR of the two specific defective
     pages eliminates them and brings the document to 2 hits, safely under threshold, with no gate
     change.
   - The two residual math-notation hits named as a second **deliberately unexempted, non-blocking
     class**, parallel to the arXiv subject-code precedent already documented in the same
     paragraph (`:234`) — explicitly accepted rather than pattern-matched away.
   - The prohibition clause at `:252` itself is left untouched, since route (a) does not widen the
     exemption, tune the threshold, or apply a manual override.

**3. Add a one-line pointer in `context/guides/literature-organization.md`'s existing "Converter
Tier Selection" section (`:346-379`, added by task 102).** That section already documents re-OCR
as the Class B remedy (`:362`, `:370-371`) but does not yet cite `joyce_1999`'s concrete post-fix
hit count as a resolved example; add one sentence naming the 4->2 result once the targeted fix is
applied.

**4. Split ownership between this task and task 105.** Per the task description's own "this task
may select (a) and hand off" framing: recommend this task's implementation phase execute the
proven, bounded, one-off fix for `joyce_1999` specifically (no new tooling required — `ocrmypdf` is
already present and the exact remedy is already demonstrated at page level), while task 105 ("Add
an OCR tier for image-only and poor-vintage-OCR PDFs") remains the owner of building reusable,
general-purpose tooling (a repeatable page-level re-OCR-and-splice mechanism, or a productionized
OCR tier) for future documents. Task 104 should not block on task 105, and task 105 should not
need to re-litigate this decision — cite this report's route-(a) selection as its rationale
anchor.

**5. Flag, don't resolve, the existing ingested-but-ungated corpus copy.** The planner should
decide whether to re-run the gate against the currently-ingested `joyce_1999` corpus copy
retroactively once the targeted re-OCR fix lands, per task 106's own "no gate rejection becomes a
silent skip" acceptance criterion — this is adjacent scope this research surfaced but did not
investigate further (e.g., whether the 396 on-disk chunks reflect the un-fixed OCR text).

## Decisions

- Selected route (a) over (b) and (c), on the strength of the arithmetic finding that fixing the 2
  genuine defects alone (independent of any exemption for the notation hits) already drops
  `joyce_1999` below the reject threshold.
- Rejected route (b) as unnecessary given (a) solves the problem, and additionally risky: the two
  target strings share no generalizable structural shape with the existing binder/hat exemption
  family, and the file's own history shows over-broad widening attempts can increase false
  positives via substitution self-interference.
- Rejected route (c) as contradicted by task 102's own finding that scan status is not the
  discriminator, and because the two MIXED documents occupy the same candidate "scanned/OCR'd"
  class while needing to stay correctly rejected — a class-keyed recalibration risks masking their
  genuine corruption.
- Determined the prohibition clause at `literature_quality_gate.py:252` requires no substantive
  narrowing under route (a); recommended only an additive closing note recording the resolution.
- Declined to independently re-verify the `joyce_1999` page-level `ocrmypdf` experiment by
  re-running it, since the task description supplied it with page-number-level and
  before/after-text-level specificity consistent with an already-completed measurement; this
  report's own original contribution is the threshold arithmetic (4 -> 2 without any notation
  exemption), the route (b)/(c) risk analysis, and the docstring/guide reconciliation plan.

## Risks & Mitigations

- **Risk**: this report recommends the implementation phase execute an actual `ocrmypdf` run and
  PDF page-splice against a real corpus source file, which is more than a docstring edit.
  **Mitigation**: the exact command and target pages are already proven in the task's supplied
  evidence; the implementation plan should treat this as a bounded, two-page operation with a
  before/after gate-count check as its verification step, not open-ended re-OCR work.
- **Risk**: the adjacent finding that `joyce_1999` is already present in the live index (396
  chunks, `metadata_status: "unresolved"`) could be read as evidence the described 4-hit rejection
  never actually blocked ingestion, undermining the task's premise. **Mitigation**: the most
  likely explanation (pre-task-106 ungated ingest path) is documented above and is consistent with
  the CLI-gate rejection being real and separately measured; this is flagged for the planner as
  adjacent scope rather than treated as invalidating the task, since the fresh
  `literature-convert.sh` CLI path (which task 106 now routes `/literature` through as well) still
  gate-rejects `joyce_1999` at 4 hits today.
- **Risk**: full-document re-OCR (rather than the targeted 2-page fix) might seem like a more
  "thorough" remedy but is unproven at the 296-page scale and could introduce new artifacts.
  **Mitigation**: explicitly recommended against in favor of the narrower, already-proven
  page-level fix.

## Context Extension Recommendations

None — this is a `meta`-type task and the relevant documentation gap (converter tier selection
guidance) was already addressed by task 102's `## Converter Tier Selection` section; this task's
recommendation 3 above is a small addition to that existing section, not a new documentation gap.

## Appendix

- Search/inspection commands used: `grep -n "never widening this exemption\|MIXED documents\|correct
  operator remedy\|NOT a universal remedy\|arXiv subject-class"
  agent-system/extensions/literature/scripts/literature_quality_gate.py`; `grep -n "Converter Tier
  Selection" -A 60 agent-system/extensions/literature/context/guides/literature-organization.md`;
  `which ocrmypdf`; `jq` queries against `~/Projects/Literature/index.json` for a `joyce_1999`
  entry; directory listing of
  `~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/`.
- Key file references: `agent-system/extensions/literature/scripts/literature_quality_gate.py:150-252`
  (`sentence_boundary_glue_count` and its docstring, post-task-102 state, prohibition at `:252`);
  `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh:79-111` (pinned
  tripwires); `agent-system/extensions/literature/context/guides/literature-organization.md:346-379`
  (`## Converter Tier Selection`, added by task 102); `specs/102_characterize_converter_tiers_and_ocr_vintage/reports/01_converter-tier-characterization.md`
  (Class A/B discriminator and its evidentiary base).
