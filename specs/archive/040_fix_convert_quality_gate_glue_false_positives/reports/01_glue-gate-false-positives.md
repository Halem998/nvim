# Research Report: sentence_boundary_glue_count False Positives

**Task**: fix_convert_quality_gate_glue_false_positives - Fix sentence-boundary-glue gate false positives on Ph.D. and quantifier notation
**Started**: 2026-08-11T20:39:00Z
**Completed**: 2026-08-11T21:20:00Z
**Effort**: 1-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/literature/scripts/literature-convert.sh`, `scripts/tests/generate-test-fixtures.py`, `scripts/tests/test-literature-convert.sh`), real corpus documents (`~/Projects/Literature/pym_ohearn_yang_2004_possible-worlds-resources-bi/`, `~/Projects/Literature/ishtiaq_ohearn_2001_bi-assertion-language/`), a standalone Python simulation validating the proposed regex fix against the real corpus text
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gate's regex engine is plain Python `re` (the whole quality-gate block runs inside a `python3 << 'PYEOF'` heredoc, `literature-convert.sh:256-767` — no `grep -P`/`awk` involved, so full `re` features including fixed-context substitution are available with no engine-portability constraint).
- The false positive is exactly two collision patterns against a single, deliberately narrow regex `[a-z]\.[A-Z]`: the `h.D` transition inside literal `Ph.D` / `Ph.D.`, and the `{var}.{Upper}` transition inside quantifier/binder notation `∀x.P`, `∃x.P`, `∃y.E`, `∃x.Q` (the binder is `∀` or `∃` immediately followed by a single lowercase variable, a period, and an uppercase formula letter, with no intervening space in the extracted text).
- Verified directly against the two named real papers (concatenated corpus markdown, read-only): `pym_ohearn_yang_2004` scores 4/4 raw hits, all `Ph.D`; `ishtiaq_ohearn_2001` scores 7/7 raw hits, 5 quantifier + 2 `Ph.D` — both counts match the task description's empirical numbers exactly.
- **Recommended fix**: a pre-count strip-then-count transform — `re.sub(r"Ph\.D\.?", "", text)` then `re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", text)`, THEN run the original `re.findall(r"[a-z]\.[A-Z]", text)` on the doubly-stripped text. Verified in simulation: both real papers drop from their true counts (4 and 7) to 0; a synthetic genuine-fusion string with 3 fused sentence boundaries (no `Ph.D`, no quantifier symbols) still counts 3 and would still fail the gate. No lookbehind needed — the strip-first approach sidesteps Python `re`'s fixed-width lookbehind limitation entirely, since the exemption substrings fully contain the raw match span in both cases (`Ph.D` contains `h.D`; `∀x.P` contains `x.P`).
- No fixtures currently exercise this check in either polarity. Both a NEGATIVE fixture (Ph.D.-heavy bibliography + quantifier notation, must pass, exit 0) and a POSITIVE fixture (genuine fused-word corruption mirroring the Goldblatt/Hodkinson/Venema signature, must still fail, exit 3) are needed, following the existing `generate-test-fixtures.py` / `test-literature-convert.sh` pattern (hermetic PyMuPDF-generated PDFs, scratch temp dir only, `LITERATURE_CONVERTER=pymupdf` to force the deterministic fallback tier).

## Context & Scope

Researched the exact behavior of `sentence_boundary_glue_count` and its caller `run_quality_gate` in `agent-system/extensions/literature/scripts/literature-convert.sh`, confirmed the regex engine and available features, designed and empirically validated (via an offline Python simulation against real corpus text, not by re-running the conversion pipeline) a narrowing fix that satisfies all 5 acceptance criteria, and surveyed the existing test-fixture infrastructure to spec out the two required regression fixtures. This is a research-only pass — no source files were edited; recommendations below are for the subsequent plan/implement phases. All edits described are scoped to `agent-system/extensions/literature/**`, never the deployed `.claude/**` tree.

## Findings

### Codebase Patterns

**`sentence_boundary_glue_count`** (`literature-convert.sh:655-677`), called from **`run_quality_gate`** (`literature-convert.sh:680-715`):

```python
def sentence_boundary_glue_count(text):
    """..."""
    return len(re.findall(r"[a-z]\.[A-Z]", text))
```

```python
glue_count = sentence_boundary_glue_count(content)
if glue_count >= 3:
    reasons.append(
        f"sentence-boundary-glue: {glue_count} zero-space word/sentence-fusion "
        f"transition(s) found (threshold 3) — a distinct extraction-corruption "
        f"signature, independent of the whitespace-gap column-interleaving check"
    )
```

`run_quality_gate` collects reasons from 5 independent checks (`column_interleaving_flagged`, `sentence_boundary_glue_count`, page-coverage, ligature-scan, dehyphenation-check via inline `re.findall`). If `reasons` is non-empty, `literature-convert.sh:750-755` writes `content` to `rejected_path` (`out_path + ".rejected"`, set at `literature-convert.sh:269`), never writes the final `.md`, and `sys.exit(3)`. A single false-positive check therefore silently blocks an otherwise-clean conversion.

**Regex engine**: The entire quality-gate block (and all of `try_pymupdf_fallback`, `derive_toc_markdown`, etc.) lives inside a `python3 << 'PYEOF'` heredoc spanning `literature-convert.sh:256-767` (confirmed via `grep -n "PYEOF"`). This is pure Python `re` — not `grep -E`, not `grep -P`, not `awk`. Python's `re` module supports lookbehind/lookahead but only **fixed-width** patterns for lookbehind (a real constraint if a lookbehind-based approach were chosen — `(?<!Ph)` works since "Ph" is fixed-width 2 chars, but a lookbehind covering both exemption cases in one alternation is awkward). The strip-then-count approach recommended below avoids this constraint entirely and is simpler to read.

**The docstring's own documented precedent** (`literature-convert.sh:656-661`) already records that a comma/semicolon-inclusive version of this pattern was removed for false-positiving on math tuple/list notation (`(x,Y)`, `a,B,c`) — the exact same class of fix this task applies to the period-only pattern's own blind spots.

**Empirical verification against the two named real papers** (read-only, corpus markdown at `~/Projects/Literature/{doc}/chunk_*.md`, concatenated and scanned with the exact production regex in an offline Python script — never by reconverting or mutating the corpus):

| Document | Raw `[a-z]\.[A-Z]` hits | Breakdown |
|---|---|---|
| `pym_ohearn_yang_2004_possible-worlds-resources-bi` | 4 | All 4 are `h.D` inside `Ph.D. thesis` (bibliography) |
| `ishtiaq_ohearn_2001_bi-assertion-language` | 7 | 5 are quantifier notation (`∀x.P` ×2, `∃y.E` ×1, `∃x.P` ×1, `∃x.Q` ×1); 2 are `h.D` inside `Ph.D. thesis` |

These exactly match the task description's stated counts ("rejected at exactly 4 hits, ALL of them Ph.D." and "rejected at 7 hits — 5 quantifier notation ... 2 Ph.D."), confirming the task description's empirical claims are accurate and the false-positive mechanism is fully understood.

### Recommended Fix

Replace the function body with a strip-then-count transform, applied before the final `re.findall`:

```python
def sentence_boundary_glue_count(text):
    """Secondary word-fusion signal, added during test-harness verification.
    Deliberately period-ONLY (`[a-z]\\.[A-Z]`), NOT comma/semicolon: an
    earlier comma/semicolon-inclusive version was empirically found to
    false-positive heavily on legitimate math tuple/list notation
    (`(x,Y)`, `a,B,c` are extremely common in this math-heavy corpus and
    are not defects).

    [... existing Goldblatt/Hodkinson/Venema provenance paragraph, unchanged ...]

    Two further benign patterns are exempted BEFORE counting, both found via
    real corpus PDFs during Logos/Theory corpus building:
      - `Ph.D.` / `Ph.D` in bibliography entries (the `h.D` transition) —
        e.g. Pym-O'Hearn-Yang 2004 "Possible Worlds and Resources", rejected
        at exactly 4 hits, all `Ph.D.` in the bibliography.
      - Single-letter-variable quantifier/binder notation such as `∀x.P`,
        `∃x.P`, `∃y.E` (the `{var}.{Upper}` transition immediately preceded
        by a `∀`/`∃`/`λ` binder) — e.g. Ishtiaq-O'Hearn 2001 "BI as an
        Assertion Language", rejected at 7 hits (5 quantifier notation, 2
        Ph.D.). Both conversions were otherwise clean and were manually
        promoted from rejected_path before this fix.

    Exemption is applied by stripping the exempted substrings first, THEN
    counting on what remains — not a negative lookbehind — since the
    exemption spans (`Ph.D`, `{binder}{var}.{Upper}`) each fully contain the
    raw 3-character match span they exempt, making a strip-first pass exact
    and avoiding Python re's fixed-width-lookbehind constraint. Verified at
    0-1 occurrences across a random sample of 60 real corpus markdown files
    (read-only, not reconverted) with the period-only pattern; the threshold
    below (>=3) sits well above that baseline."""
    exempted = re.sub(r"Ph\.D\.?", "", text)
    exempted = re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", exempted)
    return len(re.findall(r"[a-z]\.[A-Z]", exempted))
```

This satisfies acceptance criterion 5 unmodified: the `>= 3` threshold in `run_quality_gate` is untouched, and none of the other four gate checks (`column_interleaving_flagged`, page-coverage, ligature-scan, dehyphenation-check) are touched — only `sentence_boundary_glue_count`'s internal counting logic changes.

**Simulation verification** (offline Python, run against the real corpus text described above, not against the pipeline):

```
pym_ohearn_yang_2004...           before: 4   after: 0
ishtiaq_ohearn_2001...            before: 7   after: 0
synthetic genuine-fusion sample   count: 3  (still >= 3 -> still fails)
```

The synthetic genuine-fusion sample used to confirm the check's real purpose is preserved: `"...local reasoning.The second line follows by inspection of the derivation.Another sentence fuses here.A third fusion occurs at this boundary as well."` — three `[a-z].[A-Z]` transitions from dropped sentence-boundary spaces, zero `Ph.D`, zero quantifier symbols. This mirrors the documented Goldblatt/Hodkinson/Venema defect mechanism (pymupdf4llm dropping inter-word spaces around `<sup>`/`<sub>` spans, which also swallows the space after a sentence-final period, producing exactly this `period-immediately-followed-by-capital` shape) without needing to reconvert or mutate the real corpus PDF.

### Fixture Infrastructure (current structure)

`scripts/tests/generate-test-fixtures.py` (104 lines) currently provides two builders, both following the same shape: open a `fitz.Document`, `insert_text()`/`insert_textbox()` literal content at explicit coordinates, save, return via CLI dispatch in `main()`:

- `build_two_column_pdf(out_path)` — uses `insert_textbox()` with column-width-constrained rectangles (the docstring records that an earlier `insert_text()`-based version produced unwrapped lines wide enough to span both columns, defeating column-band clustering — a wrapped-textbox approach is required for realism).
- `build_bold_heading_pdf(out_path)` — uses `insert_text()` per line at explicit `y` coordinates, mixing a genuine bold heading, a sentence-fragment "heading" negative case, and enough body lines (14 + 8) to give the font-size histogram a real majority.

`main()` dispatches on `sys.argv[1]` (`"two-column"` / `"bold-heading"`) — adding new fixture kinds means adding both a new `build_*_pdf` function and a new `elif kind == "..."` branch.

`scripts/tests/test-literature-convert.sh` (265 lines) is `set -uo pipefail`, uses a `mktemp -d` `WORKDIR` with `trap 'rm -rf "$WORKDIR"' EXIT` (never touches `~/Projects/Literature/`), and a `t_pass`/`t_fail`/`PASS`/`FAIL` counter pattern with `exit 1` if `FAIL > 0`. Existing tests:

- **Test 1** (forced-fallback, `literature-convert.sh:68-103`): generates `two_column.pdf`, runs with `LITERATURE_CONVERTER=pymupdf` (forces the fallback tier deterministically), asserts the fallback-tier log line appears, and accepts EITHER exit 0 with output OR exit 3 with `.rejected` written and no final `.md` (never a silent wrong answer).
- **Test 2 / 2b** (two-column reading-order regression, `:105-197`): `check_two_column_order()` helper asserts no `LEFTCOL`/`RIGHTCOL` glue on one line and correct ordering; Test 2 runs forced-fallback (strict: must be exit 0), Test 2b runs `auto` mode (looser: exit 0 correct-order OR exit 3 loud rejection).
- **Supplementary no-TOC heading test** (`:199-228`): `bold_heading.pdf`, forced fallback, asserts the sentence-fragment heading is rejected and the genuine "Introduction" heading is accepted, reading from `.md` or `.md.rejected` depending on exit code.
- **Optional real-PDF check** (`:230-255`): gated on `$LITERATURE_TEST_PDF` env var, skips with a visible warning (never fails the suite) if unset — reads a user-supplied path only, never the corpus.

### Recommendations (fixture design for implementation)

Both new fixtures should follow the established pattern: hermetic PyMuPDF-generated PDFs, run through `LITERATURE_CONVERTER=pymupdf` (forced fallback tier, for determinism matching Test 1/2's rationale), enough ordinary body text to keep page-coverage, column-interleaving, ligature, and dehyphenation checks from firing so the sentence-boundary-glue check is isolated as the only variable.

**Negative fixture** — `build_biblio_quantifier_pdf(out_path)` (or similar name) in `generate-test-fixtures.py`: single-column body text plus a "References" block containing 3-4 `Ph.D. thesis,` entries (mirroring the pym paper) and a body block containing single-letter quantifier notation (`∀x.P`, `∃y.E`, `∃x.Q`, mirroring the ishtiaq paper) — written as single `insert_text()` strings per line so PyMuPDF doesn't introduce unwanted spacing at the exempted transitions. Total raw (pre-fix) hits should clear the `>= 3` threshold (e.g. 4-7, matching the real evidence) so the fixture actually exercises the exemption rather than merely sitting under threshold already. Wire into `test-literature-convert.sh` as a new "Test 3" section: run with `LITERATURE_CONVERTER=pymupdf`, assert **exit 0** and the final `.md` exists (non-skipping, required assertion, following Test 2's strict pattern rather than Test 2b's looser one, since this fixture's purpose specifically is to lock in "these known-benign patterns never fail the gate").

**Positive fixture** — `build_fused_word_pdf(out_path)`: single-column body text containing 3+ instances of the Goldblatt/Hodkinson/Venema fused-sentence-boundary signature (a lowercase letter immediately followed by a period immediately followed by an uppercase letter, with the intervening space dropped, e.g. `"...principle of induction.Thesecondlinefollows by a similar argument.Athirdexampleconcludes the proof."`), containing **no** `Ph.D` and **no** quantifier symbols, so it is unaffected by the new exemptions. Wire in as "Test 3b": run with `LITERATURE_CONVERTER=pymupdf`, assert **exit 3**, `.md.rejected` exists, and the final `.md` does NOT exist (mirroring Test 1's exit-3 branch assertions at `:93-98`).

Both fixtures need a `main()` dispatch branch added (`"biblio-quantifier"` / `"fused-word"` or similar) alongside the existing `"two-column"` / `"bold-heading"` branches.

## Decisions

- Strip-then-count (two `re.sub` passes removing the exempted substrings, then the original `re.findall` on the residue) is recommended over a negative-lookbehind rewrite of the counting regex itself: it reads closer to the existing style, needs no lookbehind-width reasoning, and was directly validated against the real evidence in this research pass (0 false-positive residue on both named papers; genuine fusion still counted at 3+).
- The quantifier exemption pattern is deliberately narrow — `[∀∃λ][a-z]\.[A-Z]`, requiring the binder character immediately adjacent to the single-letter variable with no space — rather than a broader "any single-letter-variable-then-period-then-capital" pattern with no binder requirement, per the task's explicit preserve-the-purpose constraint: an unqualified `[a-z]\.[A-Z]` exemption would risk hiding genuine fusion defects that happen to produce a bare single-letter-then-capital transition. Requiring the binder prefix keeps the exemption tied to the actual linguistic shape observed in the evidence (`∀x.P`, `∃x.P`, `∃y.E`, `∃x.Q` — always binder-adjacent in the corpus text).
- `λ` (lambda) is included in the binder character class alongside `∀`/`∃` on the reasoning that it is the same class of single-letter-variable binder notation in this math/logic corpus, even though no `λ`-prefixed instance appeared in the two named documents' evidence; this is a judgment call for the implementer to confirm or narrow to just `∀∃` if a more conservative reading is preferred (either choice keeps the two named real papers passing and the synthetic fusion case failing, since neither uses `λ`).

## Risks & Mitigations

- **Risk**: a hermetic PDF fixture may not reproduce the exact spacing PyMuPDF would introduce around quantifier symbols or `Ph.D.` in a way that matches the real corpus's extraction shape (e.g. if `insert_text()` introduces different kerning/whitespace than the real PDFs' embedded fonts did). **Mitigation**: build fixtures with the exemption substrings inside single `insert_text()` string literals (not split across multiple calls or relying on PyMuPDF's own text-reflow), and empirically verify the produced `.md`'s raw (pre-fix) hit count during implementation before wiring the fixed function — the existing fixtures' docstrings (e.g. `build_two_column_pdf`'s "an earlier version...insert_text()...defeated column clustering" note) already establish this iterate-and-verify pattern as normal for this test suite.
- **Risk**: broadening the quantifier exemption class too far could mask a real fusion defect that happens to look like binder notation. **Mitigation**: the recommended pattern requires the exact binder-adjacent shape from the evidence (`[∀∃λ][a-z]\.[A-Z]`, no space, single lowercase variable) rather than any looser heuristic — this is the narrowest pattern that covers both empirical cases.
- **Risk**: `Ph\.D\.?` could theoretically also strip a genuine defect that coincidentally contains the literal substring "Ph.D" as fused/corrupted text unrelated to a real bibliography Ph.D. citation. **Mitigation**: judged acceptable given this exact tradeoff already exists for the comma/semicolon precedent documented in the current docstring, and "Ph.D" as literal fused garbage is not a plausible corruption shape (fusion defects glue arbitrary adjacent words, not specifically reproduce this exact bibliographic abbreviation).

## Context Extension Recommendations

None (meta task type — omitted per research-agent instructions).

## Appendix

- Read: `agent-system/extensions/literature/scripts/literature-convert.sh` (lines 1-50, 560-877)
- Read: `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` (full, 104 lines)
- Read: `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` (full, 265 lines)
- Searched: `grep -n "sentence_boundary_glue\|sentence-boundary-glue" agent-system/` — confirmed only 2 reference sites (definition + comment), no other docs reference this check
- Searched: `find ~/Projects/Literature -iname "*ossible*orlds*" -o -iname "*ssertion*anguage*"` and `grep -n "Ph\.D" .../*.md` — located and read the two named real papers' corpus markdown (read-only)
- Ran: an offline Python simulation (`re.findall`/`re.sub` against the concatenated real corpus markdown of both named papers) to empirically confirm both the current false-positive counts (4 and 7, matching the task description exactly) and the proposed fix's effect (both drop to 0; a synthetic genuine-fusion string with no Ph.D./quantifier content still counts 3)
- Searched: `find /home/benjamin/.config/nvim/agent-system -iname "handoff-schema.md"` and read `docs/architecture/handoff-schema.md`'s "Handoff Writers" table — confirmed `.orchestrator-handoff.json` is hard-mode-implement-only and research agents never write one; flagged to the delegating orchestrator (see final summary) rather than writing that file
