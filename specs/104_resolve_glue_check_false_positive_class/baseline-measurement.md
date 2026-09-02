# Phase 1 Baseline Measurement — Scope Hypothesis FALSIFIED

**Purpose**: Phase 1 of the implementation plan (`plans/01_glue-check-false-positive-class.md`)
required reproducing the document's asserted 4-hit gate rejection and localizing the 2 genuine
defects to PDF pages before any OCR runs. This record captures that measurement and its outcome:
**the plan's Scope Hypothesis is falsified** — the document is not currently rejected, and no
genuine text-layer defect is present to fix.

## Method

1. Confirmed source PDF: `/home/benjamin/Projects/Logos/Theory/specs/literature/joyce_1999_foundations-causal-decision-theory.pdf`
   — `pdfinfo` reports **284 pages** (matches plan-time check; the task's cited "296pp" remains
   unconfirmed and is now moot, see below).
2. Converted into a scratch directory (never over the live corpus) via
   `agent-system/extensions/literature/scripts/literature-convert.sh <pdf> <scratch_dir>`.
3. Ran `sentence_boundary_glue_count()` directly on the single output markdown file (already one
   contiguous unit — no chunk-join step needed, matching the live gate's own per-document join
   granularity).
4. Cross-checked against the second, independent corpus copy the research report flagged as
   adjacent scope: `~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/`
   (396 chunks, ingested via the pre-106 ungated `/literature <path>` path, joined with `"\n\n"`).
5. Computed the raw, unexempted `[a-z]\.[A-Z]` count directly (no `Ph.D.`/binder/hat stripping) as
   a third check that no genuine hit is hiding behind an exemption.

## Results

| Source | Hit count (exempted, gate's real count) | Raw unexempted count |
|---|---|---|
| Fresh reconversion of current source PDF | **2** | 2 |
| Existing corpus copy (396 chunks, ingested 2026-08-25 22:51, ~2 min after the PDF's own 22:49 mtime) | **2** | (not separately computed; same 2 strings, same context) |

`literature-convert.sh`'s own pipeline output for the fresh reconversion:
```
[convert] Quality gate: PASSED
[convert] Metrics: headings=56 words=113484 math=0 engine=pymupdf4llm
```

Both sources' 2 surviving hits are **byte-identical in content and context** to each other, and
match the report's predicted math-notation pair exactly:

1. `...Stalnaker's Equation. U(A) = ^s.P(S\A)u(0[A S])\n\nHere P(S\A)...` (Stalnaker's Equation
   fragment)
2. `... (af¬ ter a bit of algebra):\n\nf.I+i p*( YHr\ = ^{DllC^jXIIC...` (garbled matrix-predicate
   fragment)

**No third or fourth hit exists anywhere in the document, exempted or raw.** The raw, unexempted
`[a-z]\.[A-Z]` scan over the full 651,619-character converted text returns exactly these same 2
matches — no `Ph.D.` or binder/hat exemption is masking a genuine defect elsewhere.

A targeted search for the report's own named page-119/217 recovery evidence ("a dropped closing
curly quote" and "an accented 'Reyni'") found "Reyni-Popper" spelled consistently and correctly
spaced at every occurrence in the current converted text (e.g. lines mentioning "Reyni-Popper
measure(s)" throughout Chapter 6) — no glue defect is present at any of those occurrences.

## Conclusion

**The document currently converts and PASSES the quality gate at 2 hits — the exact count the
plan predicted as the *post-fix* outcome of Phase 3 — without any re-OCR having been performed by
this task.** The plan's Phase 1 Scope Hypothesis required stopping if "the measured genuine-defect
count is not 2, or the total is not 4": the measured genuine-defect count is **0** and the total is
**2**, not 4. Per the plan's own Rollback/Contingency section ("If Phase 1 or Phase 3 falsifies its
Scope Hypothesis ... stop, revert any partial change, and report"), this phase stops here.

**No partial change was made.** Every step above was read-only: two scratch-directory
reconversions and direct function calls against on-disk text. The source PDF, the corpus copy, and
`index.json` are all untouched.

## Most likely explanation

The source PDF's mtime (2026-08-25 22:49) and the existing corpus copy's ingestion mtime
(2026-08-25 22:51, ~2 minutes later) are close enough to indicate the corpus copy was ingested
directly from the PDF in its *current* state — not from some earlier, more-corrupted revision.
Combined with the research report's own account that "the task's own supplied evidence
demonstrates, at page level ... that `ocrmypdf --force-ocr` ... on pages 119 and 217 individually
eliminates both genuine defects," the most likely explanation is that the page-level fix
demonstrated as evidence during task authoring was already applied to the canonical source PDF
(this file lives outside this repo, is not git-tracked, and carries no backup/rollback trail this
task can inspect) — so today's on-disk PDF is already the post-fix artifact the plan describes
producing in Phase 2, and no further OCR action is needed or safe to duplicate.

## Implication for remaining phases

- **Phase 2** (targeted re-OCR): nothing to do — there is no genuine defect left to fix, and
  re-running `ocrmypdf --force-ocr` on pages that already convert cleanly risks introducing new
  artifacts for no benefit, which the plan's own risk table flags as a real risk ("Re-OCR of the
  targeted pages introduces *new* hits").
- **Phase 3** (reconvert and confirm 2 hits): already true today, but not "confirmed by this
  task's own fix" — it was already true before this task touched anything.
- **Phase 4** (docstring reconciliation): the plan's specified content asserts a causal narrative
  ("targeted re-OCR of the two specific defective pages eliminates them") that this task did not
  perform and cannot honestly attribute to itself. Writing that narrative now would misrepresent
  what happened. This phase is withheld pending guidance.
- **Phase 5** (guide pointer): same dependency on Phase 4's narrative; withheld for the same
  reason.
- **Phase 6** (regression gates): not blocked in principle (it only re-runs existing tests), but
  its purpose in the plan is to verify Phases 4-5 didn't touch gate behavior — with those withheld,
  running it now would not serve that purpose. Held pending guidance.
- **Phase 7** (re-gate stale corpus copy): the "stale" 396-chunk copy already passes the gate at 2
  hits today (see table above) — it does not currently hold the uncorrected OCR the plan assumed.
  A mechanical refresh would be close to a no-op (replacing already-matching content), but doing so
  without Phase 3's citable "corrected conversion" artifact would be premature. Held pending
  guidance.

## Recommendation

This finding should go back to the task's requester/planner rather than being resolved
unilaterally by continuing the plan as written: either (a) the task is effectively already
resolved and should be closed on that basis (with Phase 4/5's docstring note reworded to state
the true, verified narrative — the document already passes with 2 residual notation hits, no
genuine defect found at implementation time), or (b) there is a genuine defect on some other
revision of the source PDF this task cannot see (e.g. a different copy the requester has in mind),
in which case the requester should supply it. This task does not fabricate a page-level fix
narrative it did not perform.
