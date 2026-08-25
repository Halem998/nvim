# Research Report: Task #92

**Task**: 92 - quality_gate_false_positive_on_logic_notation
**Started**: 2026-08-24T21:51:50Z
**Completed**: 2026-08-24T22:20:00Z
**Effort**: medium
**Dependencies**: 32 (completed)
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` (source store, in sync with `.claude/scripts/` deploy copy — verified `diff` clean)
- `agent-system/extensions/literature/scripts/literature-convert.sh` (gate invocation site, self-test fixtures)
- `~/Projects/Literature/FIND_SOURCES.md` ("Quality-gate overrides (2026-08-20, higher-order identity batch)")
- All five regression-fixture documents, read from their already-chunked, already-indexed markdown under `~/Projects/Literature/sources/{doc}/chunk_*.md`
- Direct regex experimentation against the real fixture text (not synthetic examples)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The ADDENDUM's mechanism description is correct and verified: `sentence_boundary_glue_count()` (literature_quality_gate.py:118) exempts only a binder glyph immediately followed by exactly one lowercase letter, so multi-character bound-variable notation and hat-abstraction both trip the gate.
- **The ADDENDUM's suggested regex shape, `[∀∃λ^][a-z][A-Za-z0-9]*\.`, does NOT reach zero hits on either false-positive fixture when tested literally against the real converted text.** Two concrete, previously-undocumented defects in that shape were found and are detailed below (ASCII `^` vs. the actual U+02C6 hat glyph; simple character-class widening vs. the markdown-emphasis/subscript-digit fragmentation real pymupdf4llm output exhibits).
- A refined pattern, empirically iterated against all five fixtures until it reached zero hits on both false positives while never suppressing the genuine-corruption fixture or the two MIXED documents' real defect counts, is reported below as a validated starting point for planning — not a final patch, since it still needs review for regex-substitution hazards (see Risks).
- The genuine-corruption fixture (`bacon_dorr_2024_classicism`) could **not** be re-verified against a fresh pymupdf4llm conversion in this environment — the only copy of its converted text on disk is the already-remediated `LITERATURE_CONVERTER=fallback` output, which is clean by design. This is a real verification gap, not a negative result; see Risks.
- Recommendation for the two MIXED documents (per the ADDENDUM's explicit ask): the gate should **continue to reject both**, unmodified — even with the binder exemption fully fixed, their `[a-z]\.[A-Z]` hit counts stay far above the threshold-3 cutoff, driven by genuine `<sup>`-span corruption, not notation. The correct operator path is the one already proven for `bacon_dorr_2024_classicism`: reconvert with `LITERATURE_CONVERTER=fallback`, not a manual override.

## Context & Scope

Task 92 (`meta`, dependencies: [32]) targets `literature_quality_gate.py`'s `sentence_boundary_glue_count()` check, which rejects clean conversions of higher-order-logic and lambda-notation papers as if they were extraction corruption. The ADDENDUM (added 2026-08-24, after execution-based verification) narrows the task to: (1) confirm the exact mechanism, (2) *evaluate, not assume* a suggested regex widening, (3) validate against five named regression fixtures on disk under `~/Projects/Literature/sources/`, and (4) state explicitly what the gate should do with the two MIXED documents rather than tuning until they happen to pass.

This report evaluates the suggested regex shape empirically against the real fixture text (not synthetic examples), reports where it falls short, and proposes a refined shape backed by concrete before/after hit counts on every fixture.

## Findings

### Mechanism confirmation (matches ADDENDUM exactly)

`literature_quality_gate.py:118`, inside `sentence_boundary_glue_count()`:

```python
exempted = re.sub(r"Ph\.D\.?", "", text)
exempted = re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", exempted)
return len(re.findall(r"[a-z]\.[A-Z]", exempted))
```

Called from `literature-convert.sh:742` (`run_quality_gate()`) against `content` — the final, persisted markdown output, not a raw/intermediate form — with threshold `>= 3` (`literature-convert.sh:743`). Source and deploy copies of `literature_quality_gate.py` are byte-identical (verified via `diff`); the drift warning in the task description applies to `literature-convert.sh`, not this module.

Three existing self-test fixtures at `literature-convert.sh:220-227` must keep passing: a >=3 flagging case, the `Ph.D.` exemption, and the narrow single-letter binder exemption (`∀x.P`, `∃y.E`). All three still pass under the refined pattern below (verified).

### The suggested shape does not reach zero on the real fixtures

Testing `[∀∃λ][a-z][A-Za-z0-9]*\.` (character-class widening only, no other change) against the concatenated chunk markdown for all five fixtures:

| Fixture | Addendum's stated hit count | Current (narrow) count, reproduced | Suggested-shape count |
|---|---|---|---|
| goodman_2024 (FALSE POSITIVE) | 11/11 lambda notation | 7 | 6 |
| bacon_a_case (FALSE POSITIVE) | 11/11 hat/lambda | 10 | 10 (unchanged) |
| bacon_dorr_2024 (TRUE POSITIVE) | genuine corruption | 0 | 0 |
| hott_book_2013 (MIXED) | 8 genuine + 3 bib = 11 | 11 (exact match) | 11 |
| ahrens_north (MIXED) | ~17 + ~7 = ~24 | 21 (close; see caveat below) | 21 |

The "reproduced" counts above validate the methodology: `hott_book_2013`'s automated count (11) matches the ADDENDUM's manual match-by-match count (8+3=11) exactly. `ahrens_north`'s count (21) is close to but not identical to the ADDENDUM's `~17+~7=~24` — plausibly because the ADDENDUM's counts were visual estimates ("~") against the original single-pass conversion output, while this report reads the already-indexed, already-chunked markdown, which may differ in minor whitespace/chunking normalization. This is a minor methodology caveat, not a contradiction.

The suggested shape barely moves goodman_2024 (7 -> 6) and does not move bacon_a_case at all (10 -> 10). Inspecting the actual residual matches explains why — two root causes not mentioned in the ADDENDUM:

**1. Wrong hat glyph.** The corpus's hat-abstraction notation uses U+02C6 (`ˆ` MODIFIER LETTER CIRCUMFLEX ACCENT), not the ASCII caret `^` (U+005E) the suggested shape names. Every hat-abstraction occurrence in `bacon_a_case_for_higher_order_metaphysics` — its entire false-positive hit count — would remain unexempted by a literal `^` in the character class:

```
'nt. For instance, when a property term, _x.Fx_ ˆ , appe'
'igher-Or... > **4 are closer to th... > _x.Fx_ ˆ = _x.Gx_ ˆ ...
```

Note also that the hat frequently appears in **postfix** position (`x.Fx ˆ`), trailing the variable-period-matrix, not prefixed to it — pymupdf4llm's extraction-order for the circumflex diacritic (typeset above the base character in the source PDF) is inconsistent between prefix and postfix. A pure `[binder][var].` prefix pattern cannot catch the postfix form at all.

**2. Markdown-emphasis and subscript-digit fragmentation.** pymupdf4llm renders italicized PDF spans as markdown emphasis (`_..._`), and subscripted variable indices (x₁, xₙ) as bare digits with surrounding whitespace, both of which interrupt the immediate character-adjacency a simple `[binder][a-z]\.` pattern assumes. Real excerpt from `goodman_2024` (λx₁...xₙ.Rx₁...xₙ):

```
'( _λx_ 1 _. . . xn.Rx_ 1 _. . . xn_ )'
```

The trigger match is `n.R` inside `xn.Rx` — the **last** bound variable in a multi-variable ellipsis list, not adjacent to the binder `λ` at all (the binder is several tokens to the left, before `x`₁). No amount of widening the character class at the binder position fixes this; the exemption has to span the whole ellipsis-separated variable list, tolerating the intervening markdown/whitespace/digit noise.

### A refined, empirically-validated pattern

Iterating against the real fixture text (not synthetic cases), a pattern search that (a) tolerates markdown-emphasis/whitespace/digit noise between a binder and its bound-variable run, (b) accepts an optional ellipsis-separated second variable for multi-variable lists, and (c) separately handles both prefix- and postfix-hat notation with the correct U+02C6 glyph, reaches **zero hits on both false-positive fixtures** without touching the true-positive or MIXED fixtures' counts:

```python
NOISE = r"[_\s]*"
VAR = rf"[a-z][a-z0-9_\s]*?{NOISE}"       # bound-variable run, tolerating markdown/whitespace/subscript noise
ELLIPSIS = rf"\.{NOISE}\.{NOISE}\.{NOISE}"
PREFIX      = re.compile(rf"[∀∃λ]{NOISE}{VAR}(?:{ELLIPSIS}{VAR})?\.")
PREFIX_HAT  = re.compile(rf"ˆ{NOISE}{VAR}\.")
POSTFIX_HAT = re.compile(rf"{VAR}\.[A-Za-z]+{NOISE}ˆ")
```

Applied in sequence (all three substitutions before the final `findall`), measured hit counts:

| Fixture | Before (narrow, current) | After (refined) |
|---|---|---|
| goodman_2024 (FALSE POSITIVE) | 7 | **0** |
| bacon_a_case (FALSE POSITIVE) | 10 | **0** |
| bacon_dorr_2024 (TRUE POSITIVE, currently-clean copy — see Risks) | 0 | 0 (unaffected) |
| hott_book_2013 (MIXED) | 11 | 11 (unaffected — correctly still counts real corruption) |
| ahrens_north (MIXED) | 21 | 21 (unaffected — correctly still counts real corruption) |

All three existing `literature-convert.sh` self-test fixtures (flagging, `Ph.D.` exemption, narrow single-letter binder exemption) still pass unchanged under this pattern (verified directly).

**This is offered as an empirically-grounded starting point for the implementation plan, not a drop-in patch.** It is meaningfully more complex than the ADDENDUM's one-line suggestion, and that complexity is load-bearing — every simplification attempted during this research (see appendix history below) regressed one of the two false-positive fixtures back to nonzero. The planner should treat "the exemption needs to span a whole binder+ellipsis+variable-list run, not just a binder-adjacent single character" as the key finding to design against, rather than re-deriving it from the ADDENDUM's one-line suggestion alone.

### A distinct false-positive class in the MIXED documents, out of stated scope

Both `hott_book_2013` and `ahrens_north` bibliography sections contain arXiv subject-class citation codes (`arXiv:math.CT/0610239`, `arXiv:math.AT/9811037`, `DOI:10.4230/LIPIcs.TYPES.2013...`) that also match `[a-z]\.[A-Z]` (`math.CT`, `math.AT`) and are not corruption. These are a handful of the 11/21 residual hits in each MIXED document. The ADDENDUM's acceptance criteria do not require these two documents to reach any particular count, so this is reported as a secondary, non-blocking observation for a possible future follow-up, not addressed by the refined pattern above.

### `ahrens_north`'s dominant notation is a fourth, unrelated shape

The majority of `ahrens_north`'s residual hits are dependent-type-theory binder notation with a **parenthesized, typed** variable — `∀(x : A).Px`, `Σ(a:A)B(a)` — which none of the addendum's suggested shape, nor the refined pattern above, attempt to exempt (the variable is inside parens with a type annotation, not immediately adjacent to the binder). The rest of `ahrens_north`'s and most of `hott_book_2013`'s residual hits are genuine fused-word corruption from the same `<sup>`-span collapse defect the gate exists to catch (e.g. `isalsomodal.Thus`, `iscontractible.Since`, `isinjective.Forif`). This directly supports the MIXED-document recommendation below: widening the exemption further to cover this fourth notation shape would not meaningfully change either document's pass/fail outcome, since the genuine-corruption hit count alone already exceeds the threshold.

## Decisions

- The suggested regex shape from the ADDENDUM (`[∀∃λ^][a-z][A-Za-z0-9]*\.`) is evaluated and **rejected as insufficient** — it leaves 6/11 and 5/10 (later found ~5-6, exact residuals shown above) hits uncaught on the two false-positive fixtures respectively, due to two specific, verified defects: wrong hat glyph, and no handling for markdown-emphasis/subscript-digit-fragmented multi-variable binder runs.
- A refined pattern (above) is validated empirically to reach zero hits on both false positives while leaving the true-positive and both MIXED fixtures' counts unchanged, and is recommended as the starting point for the implementation plan.
- For the two MIXED documents, the gate should **keep rejecting them**, exactly as it does today. The correct fix is not to widen the exemption until they pass — the ADDENDUM is explicit that this must not happen — and this research confirms empirically that a *correct* exemption fix does not make them pass either: their residual hit counts (11 and 21) are dominated by genuine corruption and a distinct dependent-type binder shape the exemption was never meant to cover, not by the notation this task targets. The recommended operator remedy is the one already proven for `bacon_dorr_2024_classicism`: reconvert with `LITERATURE_CONVERTER=fallback`.

## Risks & Mitigations

- **Verification gap on the true-positive fixture.** `bacon_dorr_2024_classicism`'s currently-indexed markdown is the already-remediated `LITERATURE_CONVERTER=fallback` output (per `FIND_SOURCES.md`), not the original pymupdf4llm output that exhibited the genuine `<sup>`-span corruption. This report could not reproduce the corrupted conversion directly: `pymupdf4llm` is not importable in the base environment, and the project's own `literature-pyenv` venv (an untracked scratch directory, visible in `git status`) fails to import it with `ImportError: libstdc++.so.6: cannot open shared object file` outside its intended nix-shell wrapper. **Mitigation**: the implementation phase must re-run the actual `literature-convert.sh` pipeline (with its correct nix-shell/library environment) against `~/Projects/Literature/_staging_hoi/bacon_dorr_2024_classicism.pdf` using the primary (non-fallback) converter, and confirm the refined regex still trips on the reproduced corruption — this is the acceptance criterion's "bacon_dorr_2024 still trips" requirement, and it cannot be verified from research-agent tooling alone.
- **Regex-substitution self-interference.** An early, cruder attempt at this fix (blanket-stripping all markdown underscore characters as a preprocessing step before applying a widened regex) was tested and **increased** false positives on `hott_book_2013` from 11 to 26 — deleting matched exemption spans can glue previously non-adjacent characters into new spurious `[a-z]\.[A-Z]` matches. The refined pattern above avoids this by matching noise-tolerant runs directly within the exemption regex itself, never via a separate global-strip pass, and was re-verified to leave `hott_book_2013`/`ahrens_north` counts exactly unchanged. Whoever implements this should treat "does the fix introduce new matches on the MIXED fixtures, not just fail to remove old ones" as a required check, not just "did the false-positive count go to zero."
- **Complexity vs. threshold-3 design intent.** The refined pattern is materially more complex than a single character-class edit. If the planner judges this complexity unacceptable for a gate check, an alternative worth evaluating (not attempted here, out of this report's scope) is switching this specific check from "any single occurrence, threshold 3" to a density-normalized signal for documents with detected logic/lambda notation — the SCOPE section of the original task description names this as a candidate approach the ADDENDUM's narrower request doesn't rule out.

## Context Extension Recommendations

- **Topic**: pymupdf4llm markdown-emphasis fragmentation of adjacent-glyph regex assumptions.
- **Gap**: no existing context document records that pymupdf4llm's italic-span markdown wrapping (`_..._`) and subscript-digit extraction (bare digits with surrounding whitespace) routinely break naive character-adjacency regexes written against "clean" notation examples — this cost significant iteration in this research and would recur for any future quality-gate check targeting notation-adjacent patterns.
- **Recommendation**: a short note under the literature extension's domain context (e.g. alongside `context/project/literature/domain/`) documenting this fragmentation pattern with the real excerpts captured in this report, so future gate-check regexes are designed against it from the start rather than rediscovered per-task.

## Appendix

### Search / test methodology

- Read `literature_quality_gate.py` in full (source store, confirmed identical to deploy copy).
- Read `literature-convert.sh`'s gate invocation site and its three existing self-test fixtures.
- Read `state.json`'s task 92 entry for the full ADDENDUM text.
- Read `~/Projects/Literature/FIND_SOURCES.md`'s "Quality-gate overrides" section (the original override log the task description references).
- Located all five fixture documents' already-converted, already-chunked markdown under `~/Projects/Literature/sources/{doc}/chunk_*.md` and their source PDFs under `~/Projects/Literature/_staging_hoi/`.
- Wrote and iterated a standalone Python harness (concatenating each fixture's chunks, applying `Ph.D.` strip + candidate exemption regex + final `findall`) directly against the real text, comparing hit counts and inspecting residual match context at each iteration — five iterations total, moving from the literal ADDENDUM suggestion, through an unsafe blanket-underscore-strip variant (rejected — see Risks), to the final noise-tolerant, no-global-strip pattern reported above.
- Attempted (and could not complete, for environment reasons — see Risks) a fresh pymupdf4llm reconversion of `bacon_dorr_2024_classicism.pdf` to directly verify the true-positive fixture against the refined pattern.
