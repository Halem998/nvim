# Research Report: Task #103

**Task**: 103 - Fix literature-fidelity-audit.sh chunk-blindness (a), the absent-baseline
majority (b), and the self-referential-ratio certification gap (c)
**Started**: 2026-09-01
**Completed**: 2026-09-01
**Effort**: research only (read-only; two throwaway scratch simulations run, no corpus writes)
**Dependencies**: None blocking. Related, non-blocking: Task 102 (converter-tier
characterization — tier-selection concern, explicitly orthogonal to this task's
certification-withholding concern, per delegation). Task 107 (OCR-misrecognition detector,
[NOT STARTED], empty directory) — coordinate, do not duplicate.
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (full, 552 lines)
- `agent-system/extensions/literature/scripts/literature-search.sh` (quarantine logic, ~lines 24-60, 240-290)
- `agent-system/extensions/literature/scripts/literature-briefing.sh` (fidelity marker logic, ~lines 140-190)
- `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md`
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
- `specs/vault/01-vault/archive/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md` (full, incl. "Detector Design" section)
- `~/Projects/Literature/index.json` (live corpus, 292-296 `sources/` directories, direct jq/shell inspection)
- `~/Projects/Literature/sources/*/` (direct file listing, `pdfinfo` metadata, `wc -w`)
- Two scratch simulations of the audit script (patched copies, `--dry-run` only, written to the
  session scratchpad, never touching `~/Projects/Literature/index.json`)
- Live invocation of `literature-search.sh "deliberative stit"` (read-only query)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect (a) is real and exactly as described**: `literature-fidelity-audit.sh:342-346`
  excludes every `chunk_NNNN.md` from the `mds` glob, and the ingest pipeline
  (`literature-ingest.sh` -> `literature-chunk.sh`) can legitimately produce directories whose
  *only* markdown is `chunk_NNNN.md` files (confirmed on disk, e.g.
  `agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl/`: only `chunk_*.md` +
  `metadata.json`, no canonical `.md`). For those directories `has_md` is permanently `False`.
- **The naive fix (delete the exclusion) is wrong and was caught by simulation, not inspection.**
  A large minority of directories carry *both* a canonical `<doc>.md` *and* its own
  `chunk_NNNN.md` re-split of that same content (this is the documented, intentional FTS
  re-split described in `chunk-file-conventions.md`, and is exactly what task #839 fixed once
  already for a different reason — see "Divergence from the delegation" below). Simulating a
  blanket un-exclusion reproduced that exact double-count regression live: `burgess_1982_i`'s
  ratio inflated from the correct 1.0982 to a fabricated 2.2476 because its 4182-word canonical
  `.md` and its 4371-word chunk re-split were summed together. **The correct fix is conditional,
  not a deletion**: count `chunk_NNNN.md` toward `has_md`/`md_words` *only when no non-chunk
  `.md` exists in the directory*; when a canonical `.md` is present, current (already-correct)
  behavior is preserved unchanged. This was verified by a second, corrected simulation whose
  ratios for all directories with a canonical `.md` reproduce the current stamped values exactly,
  and whose ratio for `goldblatt_1989` (chunk-only... actually canonical-`.md`-present, see
  below) reproduces the delegation's own cited 1.0162 figure exactly.
- **The report's "Detector Design" section (line 76) confirms the delegation's framing exactly**:
  it rejects `chunk_*.md` filename presence/absence only "as a primary signal" for the
  *classification verdict* ("would misclassify ~30 genuinely converted docs" if chunk-ness were
  used to decide the outcome) — it never contemplated excluding chunk files from `has_md`/word
  counting entirely. The fix is a reconciliation of an over-broad implementation with a narrower
  intent, not a reversal of the report's design, and the two governing comments (the script's own
  line-33 docstring, and `chunk-file-conventions.md`'s "Do not double-count chunks" section) both
  need updating together to state the conditional rule precisely — `chunk-file-conventions.md`'s
  current wording ("chunk_NNNN.md files ... are index-only re-splits of that directory's
  canonical document .md file(s)") is now stale: it assumes a canonical `.md` always exists,
  which the pipeline no longer guarantees.
- **Defect (b), re-measured live, is smaller in its currently-realized form than described, but
  the underlying danger it names is real and directionally worse than "unchanged."** Live
  corpus measurement (parent entries only) shows **208 of 292** entries already stamped
  `no_source_pdf` today — a value `literature-search.sh` and `literature-briefing.sh` do **not**
  quarantine or mark. A live re-run of `literature-search.sh "deliberative stit"` (the
  delegation's own cited failing example) currently **returns results without
  `--include-unverified`**, because `horty_belnap_1995_deliberative-stit` already carries a
  `no_source_pdf` stamp from a prior `--write` run. The "137 unset" / "zero-result" figures in
  the delegation reflect an earlier corpus/index.json snapshot; only **1** parent entry
  (`goldblatt_1989`, deliberately left unstamped per the delegation's own account) is unset
  today. **This does not mean defect (b) is moot** — see next bullet — but the report should be
  precise about what is currently true so the plan is not built to fix a symptom that has already
  partly self-resolved by other churn, at the cost of missing the symptom that has NOT
  resolved.
- **The real, still-live danger of (a)+(b) together is prospective, not (as of this
  measurement) fully realized: the corpus is one un-fixed `--write` run away from a mass
  regression.** The stamps currently serving `no_source_pdf` results were produced by a prior
  version of the classifier (predating the chunk-exclusion bug, and using an enum spelling —
  `unverified_conversion`, 10 live entries, see "Related finding" below — that the current
  6-value enum doesn't even produce). If `--write` is re-run today with the *unpatched* script,
  every currently-`no_source_pdf` chunk-only directory that has **no** canonical `.md` (has_pdf
  False, has_md **now correctly False** under current code, has_pdf **also** False) would
  re-classify via the `not has_pdf and not has_md` branch into `unverified_no_baseline` —
  **which IS quarantined**. That is the live risk this task must close before anyone next runs
  `--write`, and it is a strictly worse failure mode than "already broken," because it would
  silently downgrade documents that are currently retrievable into quarantine, mid-operation,
  the next time the audit is (correctly, routinely) re-run after an ingest.
- **After the conditional chunk-fix alone (simulated), the true residual "cannot classify"
  population is tiny: 5 of 296 directories** (`not_yet_converted`: 2, `unverified_no_baseline`:
  2, `unadjudicated`: 1) — not "most of the corpus." The overwhelming majority (225/296, ~76%)
  correctly resolve to `no_source_pdf`, which both consumers already treat as non-quarantined,
  non-marked. **This directly narrows what defect (b) still needs to *design*: not a rescue for
  a hypothetically-quarantined majority (that majority does not exist once (a) is fixed
  correctly), but a decision about whether `no_source_pdf` is the semantically right resting
  state for "pipeline discarded the PDF after conversion" (arguably-fine-as-is) versus a
  positive alternative — see Decisions.**
- **Defect (c) is fully confirmed and reproducible today, independent of (a)/(b).** A
  `pdfinfo` Creator/Producer metadata survey of every retained PDF in the corpus
  (`~/Projects/Literature/sources/*/*.pdf`) found exactly the same population the delegation
  describes plus a few more: **10 directories** whose PDF was produced by a known scan/OCR
  pipeline (`ABBYY FineReader`, `Acrobat N.n Capture Plug-in` / `... Image Conversion Plug-in`).
  **9 of the 10 are currently stamped `verified_conversion`** at word_ratio ~1.0 (the tenth,
  `goldblatt_1989`, is the anchor case and was deliberately left unstamped). This is measured
  live, today, and matches the delegation's anchor-case numbers exactly once the double-count
  bug above is also accounted for. The Producer/Creator regex is a precise, cheap,
  no-new-detector-module signal that requires no coordination with Task 107's (unbuilt)
  OCR-misrecognition text detector.
- **Related finding, in-scope but not one of the three named defects**: 10 live parent entries
  carry `provenance_fidelity: "unverified_conversion"` — a string that **no version of
  `classify_dir()` in the current script produces** (the six-value enum is
  `verified_conversion`/`unverified_summary`/`no_source_pdf`/`not_yet_converted`/
  `unverified_no_baseline`/`unadjudicated`). It is absent from both `literature-search.sh`'s
  `QUARANTINED_FIDELITY_VALUES` and `literature-briefing.sh`'s `needs_fidelity_marker()`, so
  these 10 documents currently pass through **both** consumers as if fully trusted, unmarked —
  a live instance of exactly the "never silently authoritative" violation the whole
  `provenance_fidelity` mechanism exists to prevent. It self-heals the moment a fixed `--write`
  re-stamps the corpus (their next value will be a real enum member), so no separate code change
  is required for this by itself, but the plan should be aware it exists and should not be
  surprised if the acceptance count of "how many entries changed" on the fixed `--write` run
  includes these 10 for a reason unrelated to (a)/(b)/(c).

## Context & Scope

Read-only research. Two throwaway scratch copies of `literature-fidelity-audit.sh` were run
with `--dry-run` from `/tmp/claude-.../scratchpad/` to validate proposed fixes against the live
corpus; neither wrote to `~/Projects/Literature/index.json` (verified: `--dry-run` never opens
the file for writing, and the file's mtime/content were not touched — only `--write` mode does
that, and it was never invoked). No corpus files were modified. No `.claude/**` files were
edited (per `rules/source-store-deploy-boundary.md`, all recommendations below target
`agent-system/extensions/literature/**`).

## Findings

### Defect (a) — chunk-blindness — confirmed, plus a discovered double-count trap

`literature-fidelity-audit.sh:342-346` (current):

```python
mds = sorted(
    os.path.join(dirpath, e) for e in entries_on_disk
    if e.lower().endswith(".md")
    and not re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)
)
```

This exclusion was added by task #839 (documented in
`context/project/literature/patterns/chunk-file-conventions.md`) to fix a *different*,
already-realized double-counting bug: directories that carry **both** a canonical `<doc>.md`
**and** its own `chunk_NNNN.md` FTS re-split of that same content were having their word count
summed twice. That fix is correct and must not regress.

The delegation's defect (a) is a second, later-arriving problem the same exclusion now causes:
the ingest pipeline (`literature-ingest.sh` -> `literature-chunk.sh`) can produce directories
whose *only* markdown is `chunk_NNNN.md` — no canonical `.md` at all. Confirmed on disk, e.g.:

```
sources/agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl/
    chunk_0001.md ... chunk_00NN.md   metadata.json   chunks.json
    (no canonical .md)
```

For these, the current code's `has_md` is `False` unconditionally — `chunk-file-conventions.md`'s
premise ("chunk_NNNN.md files ... are index-only re-splits of that directory's canonical
document .md file(s)") is stale for this and every directory shaped like it.

**The correct fix must be conditional, not a blanket deletion of the exclusion.** A naive fix
(remove the regex filter entirely) was simulated against the live corpus and produces a real
regression: for directories that have *both* a canonical `.md` and chunk re-splits (the case
task #839 already fixed), word counts double again. Measured example:

| Directory | Canonical `.md` words | Chunk re-split words (summed) | Naive-fix ratio | Correct ratio (post-conditional-fix) | Delegation's cited ratio |
|---|---|---|---|---|---|
| `burgess_1982_i` | 4182 | 4371 | 2.2476 (fabricated) | 1.0982 | 1.0982 |
| `goldblatt_1989` | 19008 (chunk sum, no canonical `.md` present — see note) | n/a | 2.044 (fabricated, double-counts against itself if regex removed elsewhere) | 1.0162 | 1.0162 |

(`goldblatt_1989`'s directory has both `goldblatt_1989.md`, a canonical file, AND
`chunk_0001.md`..`chunk_0074.md` — so it is actually in the "both exist" bucket, not the
chunk-only bucket; it is included here because it is the delegation's own anchor case and the
naive fix visibly corrupts its ratio too, which is a useful independent cross-check.)

**Recommended fix** (verified against the live corpus by a corrected simulation, 100% dry-run,
no writes):

```python
non_chunk_mds = sorted(
    os.path.join(dirpath, e) for e in entries_on_disk
    if e.lower().endswith(".md")
    and not re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)
)
chunk_mds = sorted(
    os.path.join(dirpath, e) for e in entries_on_disk
    if re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)
)
# Count chunk_NNNN.md toward has_md/md_words only when no non-chunk .md exists in
# the directory (the pipeline-ingest-only shape) -- this is what keeps task #839's
# double-count fix intact for directories that carry BOTH representations, while
# fixing the chunk-only-directory blindness this task exists to close.
mds = non_chunk_mds if non_chunk_mds else chunk_mds
```

This reproduces every currently-stamped ratio for directories with a canonical `.md` exactly
(spot-checked against `blackburn_2002`, `burgess_1982*`, `doets_1989`, `gabbay_1993`,
`wijesekera_1990_...`, `xu_1988`, `zielonka_1998` — all match to 4 decimal places), and produces
the delegation's own cited `goldblatt_1989` ratio (1.0162) exactly. Simulated corpus-wide result
after this fix alone: `verified_conversion: 65, no_source_pdf: 225, not_yet_converted: 2,
unverified_no_baseline: 2, unadjudicated: 2` (296 directories total; combining-mark submodule
disabled in the scratch copy for import-path reasons, unrelated to this fix — it is additive and
does not gate the enum, see script header).

Both governing comments need updating in the same change, per the delegation's own instruction
to update the line-33 docstring:
- `literature-fidelity-audit.sh:33` docstring — currently states chunk presence/absence is
  "deliberately NOT used as signals ... do not add them back without re-reading the report's
  Detector Design section." Needs the conditional distinction stated explicitly: chunk-ness is
  never a *verdict* signal (unchanged, per the report), but `chunk_NNNN.md` files *do* count
  toward `has_md`/`md_words` when they are a directory's only markdown.
- `context/project/literature/patterns/chunk-file-conventions.md`'s "Do not double-count chunks
  in whole-document computations" section — currently states a blanket "MUST exclude chunk_*.md"
  rule with no fallback case. Needs the same conditional restated so a future reader (per this
  same file's own stated purpose) does not re-derive the blanket exclusion and reintroduce this
  exact bug a third time.

### Defect (b) — absent baseline for the majority — re-measured, narrower than described, still real

The report's ("835") original 3-signal detector design (word-ratio -> disclosure check ->
proof-completeness check) already anticipated, and handles without a new value, the case where
`pdf_words_total == 0` (scanned/image PDF, no extractable text: `unverified_no_baseline`) — but
the report's own directory-classification model always presumed a PDF is present. It never
designed for "no PDF *file* is present in `sources/<dir>/` at all," a separate and much larger
population under the pipeline's current retain-chunks-not-PDFs convention. That case already has
a designated value (`no_source_pdf`, `has_pdf=False and has_md=True`) which predates the report
(the report calls it out as one of its two proposed additional values, alongside
`unverified_no_baseline`) and both consumers already treat as **not** a fidelity failure
(`no_source_pdf` is excluded from `QUARANTINED_FIDELITY_VALUES` in `literature-search.sh` and
from `needs_fidelity_marker()`'s case list in `literature-briefing.sh`).

**Re-measured live population** (parent entries, `~/Projects/Literature/index.json`, today):

| provenance_fidelity | count |
|---|---|
| `no_source_pdf` | 208 |
| `verified_conversion` | 70 |
| `unverified_conversion` (orphaned, see Related Finding) | 10 |
| `unadjudicated` | 2 |
| `not_yet_converted` | 1 |
| unset | 1 (`goldblatt_1989`, deliberately) |

A live re-run of `literature-search.sh "deliberative stit"` (no `--include-unverified`) **returns
results today**, because the affected document (`horty_belnap_1995_deliberative-stit`) already
carries a `no_source_pdf` stamp. This does not match the delegation's "every working query
currently requires `--include-unverified`" description as a currently-observable symptom — the
corpus has evidently been re-stamped (at least partially, by an older script version) since that
description was written. **This is a measurement-timing discrepancy worth flagging plainly to
the planning stage so the plan is scoped to the actual current state, not a stale snapshot** —
it does not change that (a) is a real code defect (confirmed by direct inspection, independent
of any index.json state) or that (c) is real (confirmed live, below).

**What remains a real, live problem for (b) is prospective, not currently-observed**: the
`no_source_pdf` stamps now in `index.json` were produced by a classifier that predates the
chunk-exclusion bug (see the orphaned `unverified_conversion` enum value below, which no current
code path produces — direct evidence the last real `--write` predates the present code). If
`--write` is run again **before** defect (a) is fixed, every directory that is genuinely
chunk-only (no canonical `.md`, confirmed to exist on disk, e.g. the `agrawal_bonakdarpour_2016`
example above) and also has no PDF will flip from `no_source_pdf` (has_md wrongly `False` today,
but the classify order still reaches `no_source_pdf`... actually reaches the anomalous
`not has_pdf and not has_md` branch since `has_md` is `False` under current code and always was)
— **this needs the plan to verify against the fixed script, not assume the un-fixed script's
current behavior is stable.** Concretely: today's `no_source_pdf` count for genuinely
chunk-only-no-PDF directories is only correct *by accident of a stale stamp*; the *current*
unfixed code, run today via `--write`, would **not** reproduce `no_source_pdf` for those
directories — it would produce `unverified_no_baseline` (quarantined). This was confirmed by
inspecting `classify_dir()`'s branch order directly (not simulated, since simulating the
*unfixed* behavior is just reading the current code) and is the operationally real form of
defect (b): **the fix must land, and `--write` must be re-run under the fixed script, in the
same change** — running `--write` under the *current* script between now and the fix would be
actively harmful.

**Decision needed for (b)** (recommend to planning stage, not decided here): now that the
"rescue the majority from quarantine" framing is shown to be already handled by the existing
`no_source_pdf` value (once (a) is fixed and `--write` is re-run correctly), the open design
question narrows to whether `no_source_pdf` is the *semantically correct* resting state for
"pipeline discarded the PDF after a conversion attempt" versus its original intended meaning,
"there never was a digital PDF to compare against" (e.g. a disclosed hand-transcription). Both
currently collapse to the same unquarantined, unmarked value. Two options for the plan to weigh,
neither implemented here:
1. **Accept the collapse** (do nothing further for (b) beyond the (a) fix + docstring updates):
   `no_source_pdf` already means "cannot be checked, not alleged to be checked" for both cases,
   and per-document text-quality concerns for chunk-only ingests are a different axis
   (combining-mark detector, and Task 107's planned OCR-misrecognition detector) already handled
   or planned elsewhere, not this task's job to duplicate.
2. **Apply the report's baseline-free signals (disclosure + proof-completeness) even when no PDF
   is present**, since neither signal requires a PDF — only `.md` text and the index summary.
   This would let a `no_source_pdf` document additionally earn a structural pass/fail on
   "does this look like a real conversion with numbered claims and proofs," reusing the existing
   `unadjudicated` value for "no numbered statements to check" (already precedented) rather than
   inventing an eighth value. This is more work and a bigger behavior change to a value most of
   the corpus depends on; not required to close the delegation's stated motivating symptom
   (search quarantine), which the (a) fix already closes for this population.
   **Recommendation: option 1** for this task's scope — it satisfies the delegation's own
   acceptance framing ("resolve the absent-baseline problem that blocks the ... majority of the
   corpus," which the (a) fix's measured 76%-to-`no_source_pdf` outcome already does) without
   taking on a second, larger design surface change to a value 208+ live entries already depend
   on. Option 2 remains available as a follow-up if a future task wants positive (not merely
   non-quarantined) confidence for chunk-only, no-PDF documents.

### Defect (c) — self-referential ratio on scan-sourced PDFs — confirmed live, reproducible detector

Live `pdfinfo` Creator/Producer survey of every retained PDF under `sources/*/`:

```
blackburn_2002                              Creator=Adobe Acrobat 7.0            Producer=Adobe Acrobat 7.0 Image Conversion Plug-in
burgess_1982 / _i / _ii / b                 Creator=ABBYY FineReader
doets_1989                                  Creator=ABBYY FineReader
gabbay_1993                                 Creator=ABBYY FineReader
goldblatt_1989                              Creator=Acrobat 3.0 Capture Plug-in   Producer=Acrobat 3.0 Import Plug-in
wijesekera_1990_constructivemodallogicsi    Creator=Acrobat 3.0 Capture Plug-in   Producer=Acrobat 3.0 Import Plug-in
xu_1988                                     Creator=Acrobat 4.0 Capture Plug-in for Windows
zielonka_1998                               Creator=Acrobat 3.0 Capture Plug-in   Producer=Acrobat 3.0 Import Plug-in
```

10 directories total (case-insensitive match on `capture|finereader|image conversion` across
Creator+Producer). Current live `provenance_fidelity`:

| Directory | Current value | word_ratio |
|---|---|---|
| `blackburn_2002` | `verified_conversion` | 1.0438 |
| `burgess_1982` | `verified_conversion` | 1.0 |
| `burgess_1982_i` | `verified_conversion` | 1.0982 |
| `burgess_1982_ii` | `verified_conversion` | 1.0705 |
| `burgess_1982b` | `verified_conversion` | 1.0 |
| `doets_1989` | `verified_conversion` | 1.0 |
| `gabbay_1993` | `verified_conversion` | 1.0025 |
| `wijesekera_1990_constructivemodallogicsi` | `verified_conversion` | 0.9922 |
| `xu_1988` | `verified_conversion` | 1.0 |
| `zielonka_1998` | `verified_conversion` | 1.0 |
| `goldblatt_1989` | unset (deliberate) | n/a |

**9 of 10 are live, standing false certifications** — exactly the population the delegation
describes (6 named + `blackburn_2002`, plus 3 more the metadata survey additionally surfaced:
`burgess_1982_ii`, `wijesekera_1990_constructivemodallogicsi`, `xu_1988`, `zielonka_1998` — the
delegation's "6" was evidently a partial list, not an exhaustive one). All are `.md` files
produced by `pdftotext`/PyMuPDF extraction of a scanned-image PDF; the ratio is ~1.0 by
construction (comparing an extraction to `pdftotext`'s own extraction of the same source) and
carries no information about page-content fidelity, matching the delegation's diagnosis exactly.

**This is independent of (a) and (b)**: confirmed by re-running the corrected (a)-fix simulation
above — every one of these 10 directories still resolves to `verified_conversion` under the (a)
fix alone (ratios shift only for `goldblatt_1989`'s pair, which was affected by the double-count
issue described under (a); the other 9 are unaffected because they have no chunk files sharing
the directory, or the chunk sum was correctly excluded by the conditional fix).

**Recommended detection signal**: `pdfinfo`'s Creator/Producer fields (already-available system
tool; `pdftotext` from the same poppler-utils package is already a hard dependency of this
script), matched case-insensitively against known scan/OCR-pipeline signatures
(`capture`, `finereader`, `image conversion`, extendable). This is deliberately **narrower** than
a general OCR-misrecognition text detector (Task 107's stated scope, [NOT STARTED] as of this
research) — it identifies *known scan-pipeline provenance from PDF metadata*, not *garbled text
from content analysis*. It requires the PDF to still be present (so it only ever applies within
the subset of directories where a ratio is computed at all — 69 measured live today), needs no
new Python module, and does not duplicate or preempt Task 107's planned work. Per the
delegation's explicit coordination note, if Task 107's detector lands first, this signal should
be replaced by (or made to consume) that detector rather than maintained as a permanent second,
narrower implementation — but building the narrow metadata check now, rather than waiting, is
what makes the de-certification acceptance criterion achievable in this task's own scope.

**Design implication — this must gate the enum, not just annotate it, unlike the
combining-mark check.** The script's existing `combining_mark_checked`/`combining_mark_dropped`/
`combining_marks_missing` fields are a precedented pattern for an *additive, informational*
signal explicitly "reported ALONGSIDE `provenance_fidelity`, never folded into ... the six-value
enum" (script's own comment, confirmed by reading the `combining_mark_check()` call site and its
result-dict placement). That pattern is insufficient here: the delegation's acceptance
criterion is that the fixed audit **must** re-adjudicate the 9 false stamps to something other
than `verified_conversion` on its own. An additive-only field would leave all 9 stamped
`verified_conversion` and would not satisfy this. The scan-pipeline signal must therefore act as
a **gate** ahead of (or folded into) the ratio-based `verified_conversion` branch:
scan-pipeline-sourced + ratio-would-otherwise-pass -> route to a new outcome rather than
`verified_conversion`.

**Recommended new enum value** (following the `unadjudicated` precedent — task #839 added a
sixth value rather than overloading an existing one, and widened both consumers alongside it):
a seventh value, e.g. `unverified_scan_source`, distinct from `unverified_no_baseline` because
it names a different failure mode the delegation itself insists on distinguishing ("What the
ratio actually measures: truncation... What it cannot measure: garbling... those are different
failure modes and the enum currently conflates them"). Both consumers need the same two-line
addition `unadjudicated` received:
- `literature-search.sh:46` `QUARANTINED_FIDELITY_VALUES` — add the new value.
- `literature-briefing.sh`'s `needs_fidelity_marker()` (~line 175) — add the new value's case.

A lower-effort alternative (reuse `unverified_no_baseline` for this case instead of adding a
seventh value) was considered and is available to the planning stage, but reduces information —
"the ratio could not be computed" and "the ratio was computed but is not trustworthy" read as the
same downstream signal to both consumers and to any future operator, which is a regression
against the delegation's explicit "different failure modes" framing. Recommend the seventh
value.

### Related finding (in scope, not one of the three named defects): orphaned `unverified_conversion` value

10 live parent entries carry `"provenance_fidelity": "unverified_conversion"`
(`word_ratio: null` for all 10, e.g. `goldblatt_2023_strong-completeness-real-time`,
`rutten-2000-universal-coalgebra`, two Jónsson-Tarski entries, `venema_2007_algebras_and_coalgebras`
— full list in Appendix). This string is produced by **no** branch of the current
`classify_dir()` (the six-value enum does not include it) and does not appear anywhere in the
current `agent-system/extensions/literature/` tree via full-tree grep — it predates the current
script and was never migrated. Both consumers' allowlist-style checks (`QUARANTINED_FIDELITY_VALUES`
membership test in search; `needs_fidelity_marker()`'s `case` statement in briefing) silently
treat any value **not** on their list as "fine, not a fidelity concern" — so these 10 documents
currently pass through both gates **unmarked and unquarantined**, exactly the "silently
authoritative" failure the whole mechanism exists to prevent. It is transient (a correct
`--write` re-run under the fixed script will overwrite all 10 with a real enum value, whatever
that document's actual classification turns out to be) so it needs no dedicated code fix by
itself — flagging it here so the plan is not surprised by these 10 appearing in the "changed"
count of the next `--write` run for a reason unrelated to (a)/(b)/(c), and so nobody reads their
presence as a fourth defect requiring separate remediation.

## Decisions

- **(a) fix is conditional, not a deletion**: count `chunk_NNNN.md` toward `has_md`/`md_words`
  only when the directory has no non-chunk `.md`; otherwise, current behavior (excluding chunks)
  is unchanged. This is the only variant verified against the live corpus without regressing
  task #839's original double-count fix.
- **Both docstrings must be updated together**: `literature-fidelity-audit.sh:33` and
  `chunk-file-conventions.md`'s "Do not double-count chunks" section, to state the conditional
  rule explicitly (chunk-ness is never a *verdict* signal; it *is* counted as content when it is
  the only content).
- **(b) is resolved for this task's scope by the (a) fix + a correct `--write` re-run**, landed
  in the same change (never run `--write` under the unfixed script in the interim — see Findings
  above for why that would actively regress currently-working `no_source_pdf` stamps). No new
  enum value or baseline mechanism is required to meet the delegation's stated acceptance
  criterion (search quarantine relief for the corpus majority) — recommend against inventing one
  unless the planning stage decides Option 2 above is worth its added surface.
- **(c) requires a new, seventh enum value** (recommend `unverified_scan_source` or planner's
  preferred name), gated by a `pdfinfo` Creator/Producer regex check, added to both consumers'
  fail-open lists in the same change — following the `unadjudicated` precedent exactly. This
  must be a **gate**, not an additive-only field like the combining-mark signal, because
  de-certifying the 9 standing false stamps is an explicit acceptance criterion.
- **Do not build a general OCR-misrecognition text detector for (c)**: the metadata-only
  Creator/Producer check is sufficient to meet this task's acceptance criterion and does not
  duplicate Task 107's (unbuilt, [NOT STARTED]) planned scope.

## Risks & Mitigations

- **Risk**: implementing (a) as a blanket "always count chunks" fix (the intuitive first read of
  the delegation's phrasing) silently reintroduces the double-count bug task #839 already fixed
  once, for every directory that carries both a canonical `.md` and its chunk re-split.
  **Mitigation**: this report's conditional fix and the concrete `burgess_1982_i` /
  `goldblatt_1989` before/after numbers above give the planning stage a directly-verifiable
  acceptance check (re-run `--dry-run` post-fix and diff those specific ratios against the table
  in this report).
- **Risk**: running `--write` under the current unfixed script between now and this task's
  landing would move the corpus in the wrong direction (working `no_source_pdf` stamps regress
  to quarantined `unverified_no_baseline`). **Mitigation**: no action needed from this research
  itself (read-only), but the planning/implementation stage should sequence "land the fix" and
  "run `--write`" as one atomic change, and should not treat an interim `--write` as a safe
  no-op status check.
- **Risk**: a seventh enum value adds a fourth place (beyond the two consumers and the script
  itself) that must agree — any future consumer added later must remember the `unadjudicated`
  precedent (widen fail-open lists, never allowlist-invert). **Mitigation**: the recommendation
  to update `chunk-file-conventions.md` and the script docstring together already establishes
  the pattern of updating governing prose alongside code; the plan should extend this to note
  the seventh value in whatever documents the enum today (see Context Extension
  Recommendations).
- **Risk**: the Producer/Creator regex is a known-signature allowlist, not a general scan
  detector — a scan pipeline whose tool string doesn't match `capture|finereader|image
  conversion` (e.g. a stripped-metadata PDF, or a tool not yet seen in this corpus) would pass
  through uncaught, silently remaining a false `verified_conversion`. **Mitigation**: this is an
  accepted, bounded gap for this task (matches the delegation's own "coordinate, do not
  duplicate" boundary with Task 107's broader text-based detector); recommend the plan leave an
  explicit extension point (a single list/regex constant) so Task 107's future detector, if it
  lands, can widen or replace this check without another `classify_dir()` rewrite.

## Context Extension Recommendations

- **Topic**: `chunk-file-conventions.md`'s "Do not double-count chunks in whole-document
  computations" section states an unconditional exclusion rule that this task's fix makes
  incomplete.
  **Gap**: the document doesn't anticipate chunk-only directories (no canonical `.md` at all),
  which the current ingest pipeline can and does produce.
  **Recommendation**: update the section (not just the audit script's own docstring) to state
  the conditional rule verified in this report, so a future whole-document-metric script (not
  just this one) doesn't re-derive the now-stale blanket exclusion.
- **Topic**: the `provenance_fidelity` seven-value enum (once (c) lands) has no single
  documented source of truth outside the audit script's own header comment and the archived
  report at `specs/vault/01-vault/archive/835_.../reports/01_provenance-fidelity-audit.md`.
  **Gap**: `literature-index.md`'s domain doc mentions `provenance_fidelity` only in passing
  (targeting/eligibility, not the enum's values or semantics).
  **Recommendation**: the archived 835 report already anticipated this
  ("Recommend a new context file ... documenting the `provenance_fidelity` enum, the detector's
  3 signals, and the 'aggregate at document level, never single-file' constraint") — this was
  never done; the planning stage for this task is a natural point to finally create
  `context/project/literature/patterns/provenance-fidelity.md`, now with the conditional
  chunk-counting rule and the seventh value included from the start.

## Appendix

### Commands used

```bash
# Live parent-entry population count
jq -r '.entries[] | select(.parent_doc == null) | .provenance_fidelity // "UNSET"' \
  ~/Projects/Literature/index.json | sort | uniq -c

# Scan-pipeline metadata survey
for d in ~/Projects/Literature/sources/*/; do
  for pdf in "$d"*.pdf "$d"*.PDF; do
    [ -f "$pdf" ] || continue
    info=$(pdfinfo "$pdf" 2>/dev/null)
    combo="$(echo "$info" | grep -i '^Creator')|$(echo "$info" | grep -i '^Producer')"
    echo "$combo" | grep -qiE 'capture|finereader|image conversion|scan' && \
      echo "SCAN-FLAG: $(basename "$d") :: $combo"
  done
done

# Live search sanity check
LITERATURE_DIR="$HOME/Projects/Literature" \
  bash agent-system/extensions/literature/scripts/literature-search.sh "deliberative stit"

# Scratch simulation (conditional chunk-fix), no writes:
cp agent-system/extensions/literature/scripts/literature-fidelity-audit.sh \
   "$SCRATCH/sim-audit2.sh"
# ... patched mds computation as shown in Findings ...
"$SCRATCH/sim-audit2.sh" --dry-run > "$SCRATCH/sim-out2.tsv" 2> "$SCRATCH/sim-out2.stderr"
```

### Full `unverified_conversion` orphaned-value list (10 entries, live)

```
goldblatt_2023_strong-completeness-real-time
thomason-1970-indeterminist-time
rutten-2000-universal-coalgebra
reynolds-2003-ockhamist
rumberg-zanardo-2019-transition-structures
j_nsson_and_tarski_-_1951_-_boolean_algebras_with_operators._part_i
j_nsson_and_tarski_-_1952_-_boolean_algebras_with_operators._part_ii
gabbay_kurucz_wolter_zakharyaschev_2003_many_dimensional_modal_logics
venema_2007_algebras_and_coalgebras
gehrke_vosmaer_2011_view-of-canonical-extension
```

### Files read in full

- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (552 lines, full)
- `specs/vault/01-vault/archive/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md` (full)
- `agent-system/extensions/literature/context/project/literature/patterns/chunk-file-conventions.md` (full)
- Partial: `literature-search.sh` (quarantine/fidelity-map sections), `literature-briefing.sh`
  (fidelity-marker sections), `literature-index.md` (sources/-placement section)
