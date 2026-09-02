# Implementation Plan: Correct the falsified converter-tier remedy claim

- **Task**: 102 - Characterize converter-tier behavior and correct the falsified universal-remedy claim
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: `specs/102_characterize_converter_tiers_and_ocr_vintage/reports/01_converter-tier-characterization.md`
- **Artifacts**: plans/01_correct-converter-tier-remedy-claim.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase confirmed the falsified claim's exact location and resolved the task's open
"two candidate framings" question into a single mechanistic discriminator: whether a
sentence-boundary-glue defect ORIGINATES in pymupdf4llm's markdown-structuring heuristics
(Class A — the fallback tier fixes it) or is already baked into the extracted text layer
(Class B — no converter tier can fix it, and the fallback tier can make it marginally worse).
This plan applies that finding as three documentation edits in the literature extension's source
store: narrow the `literature_quality_gate.py` remedy sentence, add a `## Converter Tier
Selection` section to the organization guide, and cross-reference it from the extension README.
No behavioral code changes and no auto-selection mechanism are in scope. Definition of done: the
universal-remedy assertion is gone, the `joyce_1999` counterexample is stated explicitly, the
never-widen/tune/override prohibition clause survives verbatim, and both existing literature test
harnesses still pass.

### Research Integration

Key findings carried into this plan:
- The falsified claim is a single prose location, `literature_quality_gate.py:237-241`; every
  other `LITERATURE_CONVERTER` occurrence in the extension is a test invocation or the
  operational header comment in `literature-convert.sh`. The blast radius of the correction is
  therefore exactly one docstring.
- The Class A / Class B table (research report, Recommendations §1) is the substantive content
  for the new guide section; it supersedes both of the task description's candidate framings
  rather than choosing between them.
- The research report supplies exact drop-in replacement prose for the docstring (§Recommendations
  2). This plan treats that text as the starting point, with two mechanical adjustments recorded
  in Phase 1 (connector punctuation and quote characters).
- Recommendation 4 is an explicit non-goal decision, not an omission: the discriminator is
  inspection-based (where do the hits fall) and not computable a priori from document metadata,
  so a naive auto-select would regress Class B documents.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context supplied for this dispatch; no `specs/ROADMAP.md` consultation performed.

## Goals & Non-Goals

**Goals**:
- Remove the universal-remedy assertion from `literature_quality_gate.py`'s
  `sentence_boundary_glue_count()` docstring and replace it with the Class A / Class B framing,
  naming `joyce_1999_foundations-causal-decision-theory` (4 hits -> 5 on the fallback tier) as
  the explicit counterexample.
- Preserve the "never widening this exemption further, tuning the threshold-3 cutoff, or a manual
  override" prohibition clause verbatim, so the sibling task that narrows it separately has an
  unambiguous base to reconcile against.
- Add a `## Converter Tier Selection` section to
  `agent-system/extensions/literature/context/guides/literature-organization.md` carrying the
  Class A / Class B table, the "scanned vs. born-digital is not the discriminator" warning, and a
  short operator diagnostic procedure.
- Add a one-line cross-reference from `agent-system/extensions/literature/README.md` so the
  guidance is discoverable without already knowing where to look.

**Non-Goals**:
- Any auto-selection of a converter tier, any change to `literature-convert.sh`'s `auto`
  engine-availability fallback logic, or any new metadata field recording which tier ran.
- Widening `sentence_boundary_glue_count()`'s exemption regexes, tuning the threshold-3 cutoff, or
  narrowing the prohibition clause — all sibling-task territory.
- Re-deriving the anchor measurements by reconverting `savage_1972` or `joyce_1999`; the research
  phase treated them as an established evidentiary base and this plan does not reopen that.
- Editing anything under `.claude/` — that tree is a disposable deploy artifact regenerated from
  the source store (see `.claude/rules/source-store-deploy-boundary.md`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The remedy sentence and the prohibition clause are one grammatical sentence, so rewriting the remedy necessarily touches the text immediately preceding the prohibition | H | H | Define the preserved invariant precisely as the exact clause string `never widening this exemption further, tuning the threshold-3 cutoff, or a manual override.` plus its em-dash connector; verify by literal `grep -F` after the edit (Phase 1 verification) |
| Sibling task edits the same docstring paragraph concurrently and the two corrections contradict each other | M | M | Keep this edit strictly additive to the remedy sentence and leave the prohibition clause byte-identical; the research report explicitly instructs the sibling implementer to reconcile against the post-edit paragraph, so the invariant above is the handshake |
| Docstring is a non-raw `"""` string containing regex escapes; a stray backslash or a `"""` sequence in new prose breaks module parsing | H | L | Replacement prose contains no backslashes; render the guide section name without double quotes; verify with `python3 -m py_compile` and by importing the module (Phase 1, tier `local`) |
| New guide/README prose cites task numbers, violating the no-task-references-in-deliverables rule | M | L | Cite durable anchors only (document slugs, file names, section headings); Phase 4 runs the repo-wide task-reference lint |
| Guide section heading name drifts from the name the docstring points at | M | M | Plan fixes the exact heading text `## Converter Tier Selection` as a cross-reference contract; Phase 4 greps both files for it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Amend the docstring remedy claim [COMPLETED]

**Goal**: `sentence_boundary_glue_count()`'s docstring no longer asserts
`LITERATURE_CONVERTER=fallback` is the universal remedy; it states the Class A / Class B
distinction and names the `joyce_1999` counterexample, while the prohibition clause survives
verbatim.

**Tasks**:
- [x] Confirm the current text and line span of the remedy sentence with
      `grep -n "correct operator\|never widening" agent-system/extensions/literature/scripts/literature_quality_gate.py`
      before editing (do not trust the plan's line numbers). *(completed: confirmed at lines 237/240)*
- [x] Record the exact prohibition clause as a preserved invariant:
      `never widening this exemption further, tuning the threshold-3 cutoff, or a manual override.` *(completed)*
- [x] Replace only the sentence beginning `The correct operator remedy for a document like this
      is reconversion with ...` up to (but not including) the em dash that introduces the
      prohibition clause, using the drop-in block from the research report's Recommendations §2. *(completed)*
- [x] Apply two mechanical adjustments to the report's proposed text: (a) keep the existing
      em-dash connector `—` before `never widening` rather than the report's ASCII `--`, so the
      prohibition clause and its connector are unchanged; (b) render the guide reference without
      double quotes (e.g. `See context/guides/literature-organization.md's Converter Tier
      Selection section for the full diagnostic guidance`) to avoid introducing quote characters
      into a non-raw `"""` docstring. *(completed)*
- [x] Re-wrap the new prose to the file's existing ~72-column docstring width. *(deviation: altered — the final prohibition-clause line was left unwrapped (~95 chars incl. indent) rather than split across two lines, because the Phase 1/4 `grep -F` invariant check requires the whole clause on one physical line to match at all; confirmed the pre-edit original also fails that same check when wrapped. All other new lines follow the ~68-col wrap.)*
- [x] Confirm no backslash was introduced into the docstring body. *(completed: verified via grep)*

**Timing**: 40 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The remedy sentence occupies lines 237-241 and is the ONLY prose assertion
of fallback-as-remedy in the extension. Confirm at implementation time by re-running
`grep -rn "LITERATURE_CONVERTER" agent-system/extensions/literature/` and checking that every
hit other than this docstring is a test invocation or the `literature-convert.sh` header comment;
if a second prose assertion has appeared since the research phase, amend it too and note the
deviation.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — replace the remedy
  sentence inside `sentence_boundary_glue_count()`'s docstring; no code changes.

**Verification**:
- `python3 -m py_compile agent-system/extensions/literature/scripts/literature_quality_gate.py`
  exits 0.
- `grep -cF 'never widening this exemption further, tuning the threshold-3 cutoff, or a manual override.' agent-system/extensions/literature/scripts/literature_quality_gate.py`
  reports exactly 1 (prohibition clause preserved).
- `grep -c 'The correct operator' agent-system/extensions/literature/scripts/literature_quality_gate.py`
  reports 0 (universal-remedy assertion gone).
- `grep -c 'joyce_1999' agent-system/extensions/literature/scripts/literature_quality_gate.py`
  reports at least 1 (counterexample stated explicitly).
- `git diff` on the file shows changes confined to the docstring; no line outside the `"""`
  block is touched.

---

### Phase 2: Add the Converter Tier Selection guide section [COMPLETED]

**Goal**: `literature-organization.md` gains a self-contained operator-facing section explaining
when each converter tier helps, keyed on defect origin rather than document provenance.

**Tasks**:
- [x] Add a new top-level section with the exact heading `## Converter Tier Selection`, placed
      after `### Step 7: Test the injection` / before `## Maintenance`, or as a subsection under
      `### Step 2: Convert and chunk the document` — pick one and keep the heading text exact
      either way, since the docstring points at it by name. *(completed: placed after Step 7, before Maintenance)*
- [x] Include the Class A / Class B table from the research report's Recommendations §1 (rows:
      where the defect lives, fallback tier's effect, confirmed cases, document provenance,
      correct remedy, diagnostic tell). *(completed)*
- [x] State explicitly that "scanned vs. born-digital" is NOT the discriminator, citing
      `bacon_dorr_2024_classicism` (very likely born-digital, fallback tier fixes it) and
      `joyce_1999_foundations-causal-decision-theory` (scanned, fallback tier makes it worse) as
      the two counterexamples. *(completed)*
- [x] Add the diagnostic procedure: on a gate rejection, inspect where the
      `sentence_boundary_glue_count()` hits fall — positionally concentrated near back matter or
      footnote/superscript markers suggests Class A (try `LITERATURE_CONVERTER=fallback`);
      scattered singly at otherwise-clean sentence boundaries with no structural pattern suggests
      Class B (check the source page's OCR quality; `ocrmypdf --force-ocr` on the affected pages,
      then reconvert — a tier switch alone will not help). *(completed)*
- [x] Add an explicit note that no automatic tier selection exists or is intended, and why: the
      discriminator requires inspecting post-conversion hit positions and is not computable from
      document metadata beforehand. *(completed)*
- [x] Note that `LITERATURE_CONVERTER=auto`'s fallback is an engine-availability fallback, not a
      quality-gate retry — nothing reconverts a gate-rejected document automatically. *(completed)*
- [x] Use durable anchors only; no task-number citations. *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/context/guides/literature-organization.md` — new
  `## Converter Tier Selection` section.

**Verification**:
- `grep -n '^## Converter Tier Selection' agent-system/extensions/literature/context/guides/literature-organization.md`
  returns exactly one match.
- The section names all four documented cases (`savage_1972`, `joyce_1999`,
  `bacon_dorr_2024_classicism`, and the Goldblatt/Hodkinson/Venema 2003 case).
- Section is pure prose/table addition; `git diff` shows no edits to existing sections.

---

### Phase 3: Cross-reference the guide from the extension README [COMPLETED]

**Goal**: The new guidance is discoverable from the extension's front door.

**Tasks**:
- [x] Add a one-line pointer to `context/guides/literature-organization.md`'s
      `## Converter Tier Selection` section in `README.md` — natural homes are the end of
      `### Mode B: Integration` (where conversion is described) or the `## Content-Aware
      Chunking` section; choose one. *(completed: added at end of Mode B: Integration)*
- [x] Phrase it so it says what the section answers ("which converter tier to force when a
      document is rejected by the quality gate, and when a tier switch will not help"), not just
      that a section exists. *(completed)*
- [x] Use the deploy-relative path `context/guides/literature-organization.md` (matching the
      docstring's reference and the extension's deployed layout), not the source-store path. *(completed)*

**Timing**: 15 minutes

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/README.md` — one cross-reference line.

**Verification**:
- `grep -n 'Converter Tier Selection' agent-system/extensions/literature/README.md` returns a
  match, and the heading text matches Phase 2's heading exactly.
- `git diff` on README shows a single added line (plus at most surrounding blank-line
  adjustment).

---

### Phase 4: Consistency and regression gate [NOT STARTED]

**Goal**: Confirm the three edits are mutually consistent, the preserved invariant held, and
nothing in the literature extension's test surface regressed.

**Tasks**:
- [ ] Run `bash agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh`
      and record the result. If the harness cannot run because the real corpus fixtures under
      `~/Projects/Literature/sources/` are unavailable, record that as a skip with the exact
      failure output rather than reporting a pass.
- [ ] Run `bash agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` and
      record the result under the same skip-vs-pass discipline.
- [ ] Verify the cross-reference chain end to end: the docstring names the guide section, the
      guide section heading matches byte-for-byte, and the README points at the same name.
- [ ] Re-confirm the prohibition clause invariant with a literal `grep -F` (same check as Phase 1,
      re-run after all edits land).
- [ ] Run the repo-wide task-reference lint
      (`bash .claude/scripts/check-task-references.sh` or the equivalent entry point in
      `scripts/lib/task-reference-patterns.sh`'s consumer) and confirm the three touched files
      introduce no new violations.
- [ ] Confirm no file under `.claude/` was modified: `git status --short` shows changes only
      under `agent-system/extensions/literature/` and `specs/`.

**Timing**: 25 minutes

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The docstring edit is inert with respect to both test harnesses (neither
asserts on docstring text; `test-quality-gate-notation.sh` asserts hit counts and
`test-literature-convert.sh` asserts tier selection and column ordering). Confirm by running both
suites and comparing against their pre-edit behavior; if either references the docstring, treat
that as a scope surprise and report it rather than adjusting the test to fit.

**Files to modify**:
- None (verification-only phase).

**Verification**:
- Both test harnesses report the same outcome as before the edits (pass, or the same
  environment-driven skip).
- All four cross-reference greps succeed.
- Task-reference lint reports no new violations.

---

## Testing & Validation

- [ ] `python3 -m py_compile` on `literature_quality_gate.py` exits 0.
- [ ] `test-quality-gate-notation.sh` outcome unchanged from pre-edit baseline.
- [ ] `test-literature-convert.sh` outcome unchanged from pre-edit baseline.
- [ ] Prohibition clause present exactly once, byte-for-byte, via `grep -F`.
- [ ] `The correct operator` no longer appears in `literature_quality_gate.py`.
- [ ] `joyce_1999` named as counterexample in the docstring.
- [ ] `## Converter Tier Selection` heading present in the guide and referenced by both the
      docstring and the README under the identical name.
- [ ] No `.claude/**` file modified.
- [ ] No task-number references introduced outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — amended docstring.
- `agent-system/extensions/literature/context/guides/literature-organization.md` — new
  `## Converter Tier Selection` section.
- `agent-system/extensions/literature/README.md` — cross-reference line.
- `specs/102_characterize_converter_tiers_and_ocr_vintage/summaries/01_*-summary.md` —
  implementation summary.

## Rollback/Contingency

All three edits are documentation-only and independently revertable with
`git checkout HEAD -- <path>` per file (or `git revert` of the per-phase commits). No runtime
behavior, no schema, and no test fixture changes, so a rollback cannot leave the extension in an
inconsistent operational state. If the sibling task narrowing the prohibition lands first and its
wording conflicts, the correct response is to re-reconcile the paragraph — not to revert this
task's Class A / Class B content, which is the finding both tasks depend on.
