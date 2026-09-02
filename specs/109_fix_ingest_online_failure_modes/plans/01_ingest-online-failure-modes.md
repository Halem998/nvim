# Implementation Plan: Task #109

- **Task**: 109 - Fix three distinct failure modes in the online-ingest bridge
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: specs/102_characterize_converter_tiers_and_ocr_vintage (completed; consumed for defect (c))
- **Research Inputs**: specs/109_fix_ingest_online_failure_modes/reports/01_ingest-online-failure-modes.md
- **Artifacts**: plans/01_ingest-online-failure-modes.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three independently-observed failure modes in the online-discovery -> Zotero+PDF -> ingest bridge
are fixed at the layer where each actually originates, per the research report's root-cause
analysis: (a) `zot add --pdf` hard-fails (exit 3, no item created) when it cannot regex a DOI out
of the PDF's first two pages, fixed by deriving `10.48550/arXiv.<id>` as an explicit `--doi` for
arXiv-only records; (b) two separate orphan leaks — a staging PDF file surviving
`CREATE_FAILED`/`ATTACH_FAILED` in `literature-ingest-online.sh`, and a pre-existing latent
`sources/<doc_id>/` directory leak on the no-cleanup `continue` branches of
`literature-ingest.sh`'s per-file loop; (c) a message-text-only diagnostic enrichment of the
`ONLINE_INGEST_PIPELINE_FAILED` rationale, since the converter-tier characterization forecloses
any automatic fallback retry.

**Edit target is the source store**: `agent-system/extensions/literature/`. `.claude/` is a
gitignored, disposable deploy artifact regenerated from that store — never hand-author there (see
`.claude/rules/source-store-deploy-boundary.md`).

**Definition of done**: all four scripts/docs edited in the source store, each fix exercised by a
forced-failure or stub-driven invocation (not `--dry-run`, which cannot reach any of these code
paths), with observed before/after evidence recorded.

### Research Integration

The plan follows the research report's corrections to the original task framing, not the task
framing itself:

- **(a) is a `zot`-internal failure, not a bridge-script bug.** Both bridge layers were confirmed
  clean: `zotero-write.sh`'s `item-add` check accepts `--pdf` OR `--doi`, and
  `literature-ingest-online.sh` already correctly omits `--doi` when the record has none. The hard
  failure lives in `zotero-cli-cc` v0.10.0's `commands/add.py::_add_from_pdf`, which calls
  `extract_doi()` (regex `10\.\d{4,9}/\S+` over pages 1-2 only) and, finding nothing, calls
  `emit_error("validation_error", "No DOI found in PDF")` -> `SystemExit(3)` **before** ever
  calling `writer.add_item`. It does not degrade to a barer item.
- **(b)'s location in the task description was wrong.** `.online-ingest-staging/<id>.pdf` already
  self-cleans on both `download_and_verify()` failure branches, so `DOWNLOAD_FAILED(2)` needs no
  change. Two narrower real leaks replace it (Phases 3 and 5).
- **(b)'s requested "we-created-it-this-run" guard is unnecessary.** The loop's pre-existing
  re-ingestion branch (`EXISTING == yes -> rm -rf "$DOC_DIR"`) already guarantees `DOC_DIR` is
  brand-new or freshly wiped by the time conversion runs, so an unconditional `rm -rf` on the
  failure branches is safe without additional bookkeeping.
- **(c) admits no automatic retry.** Class A (primary-tier structuring artifact; fallback fixes
  it — `savage_1972`, 73 hits -> 3) and Class B (text-layer/OCR defect; fallback does nothing or
  worsens — `joyce_1999`, 4 hits -> 5) respond oppositely, the discriminator is not computable
  from document metadata, and the guide states outright "No automatic tier selection exists or is
  intended." The fix is message text only.

**Two count corrections made during plan construction** (verified by reading the current source,
both recorded as Scope Hypotheses on their phases):

1. The research names **three** no-cleanup `continue` branches in `literature-ingest.sh`; the
   current source has **four** — `continue` at lines 239 (quality-gate reject), 246 (hard convert
   failure), **259 (conversion reported success but no `.md` file found — missed by the
   research)**, and 279 (chunking failure). Phase 5 covers all four.
2. The research names **one** `ONLINE_INGEST_PIPELINE_FAILED` `directive_stop` site (cited as
   `:736-738`); the current source has **two** — line 717 (resolvable/open-access path) and line
   821 (existing-no-pdf attach path). Phase 4 covers both.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Make arXiv-only `open_access` records survive Zotero item creation by passing a mechanically
  derived `10.48550/arXiv.<arxiv_id>` as `--doi`.
- Remove the staging PDF file on the two `directive_stop` paths that fire after a successful
  download (`ZOTERO_CREATE_FAILED(3)`, `ZOTERO_ATTACH_FAILED(5)`).
- Remove the orphaned `sources/<doc_id>/` directory on every no-cleanup `continue` branch of
  `literature-ingest.sh`'s per-file loop.
- Enrich both `ONLINE_INGEST_PIPELINE_FAILED` rationales with a pointer to the preserved rejected
  markdown and the Class A / Class B manual diagnostic procedure.
- Correct `zotero-item-creation.md` §1's understatement that a `--pdf`-only create merely "yields
  a barer item".
- Establish a reusable stub/forced-failure harness, since `--dry-run` cannot exercise any of these
  paths.

**Non-Goals**:
- Any automatic converter-tier retry, auto-selection, or Class A/B heuristic classifier — this is
  explicitly foreclosed by the converter-tier characterization and would regress Class B documents.
- Changing `ONLINE_INGEST_DOWNLOAD_FAILED(2)` cleanup — already clean.
- Changing the stable-contract surface documented in `literature-ingest-online.sh`'s header: no
  field names, directive-token spellings, or exit-code numbers change in this task.
- Making Crossref resolve the synthesized DataCite DOI (it will not — see Risks).
- Regenerating or editing `.claude/` — that is the deploy step's job, not this task's.
- Fixing the separate success-path orphan where `BASE_DOC_ID` and the converter-derived `DOC_ID`
  differ (see Phase 5's optional sub-step, which is scoped to a safe `rmdir` only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Synthesized `10.48550/arXiv.*` DOI mistaken downstream for a resolved bibliographic DOI | M | M | Comment it in code as a mechanical fallback identifier, distinct from a published-venue DOI; note it in the implementation summary. `patch_global_index` sources title/authors/year from the discovery record, so corpus-side metadata is unaffected |
| Crossref cannot resolve a DataCite DOI, so the created Zotero item is metadata-bare (DOI field only) | L | H (certain) | Accepted and documented, not worked around. An existing bare item beats the current outcome of no item at all. Record explicitly in the summary and in the Phase 6 doc correction |
| `rm -rf "$DOC_DIR"` in `literature-ingest.sh` destroys a pre-existing populated corpus directory | H | L | The loop's own re-ingestion branch already `rm -rf`s and recreates `DOC_DIR` when an index entry exists, so by conversion time it is always fresh-this-iteration. Phase 5 re-confirms this ordering by reading lines 193-212 before editing |
| Editing `literature-ingest.sh` touches the "UNMODIFIED literature-ingest.sh pipeline" the bridge's header contract references | M | M | This is a narrow safety-preserving cleanup fix benefiting every caller, not a bridge-specific behavior change. Call it out explicitly in the summary so it is not read as scope creep. No pipeline semantics, output, or exit codes change |
| Stub `zot` / `literature-convert.sh` diverge from real behavior, producing false-green verification | M | M | Stubs reproduce only exit codes and stderr text taken verbatim from the real tools' observed output; Phase 7 additionally checks the real scripts parse and run to the expected `directive_stop` under forced failure |
| Test artifacts leak into the real `$LITERATURE_DIR` corpus | H | M | Every harness invocation sets `LITERATURE_DIR` to a scratch directory under the task dir or `/tmp`; Phase 1 verifies the override is honored before any fix phase runs |
| Fixes land only in `.claude/` and are wiped by the next deploy | H | L | All edits target `agent-system/extensions/literature/`; Phase 7 greps the diff to confirm no `.claude/**` path was written |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3, 6 | 2 |
| 4 | 4 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 are deliberately
serialized despite having no logical dependency on each other: all three edit
`literature-ingest-online.sh`, and serializing them keeps the territory single-owner per phase.

---

### Phase 1: Build the forced-failure / stub verification harness [COMPLETED]

**Goal**: Establish the test vehicle every later phase verifies against, since `--dry-run` cannot
reach any of the three defects' code paths.

**Tasks**:
- [x] Read `literature-ingest-online.sh` header lines 20-38 (the documented INPUT SCHEMA) and hand-build
  three synthetic record JSON documents in a scratch directory:
  - `arxiv_only.json` — `status: "open_access"`, `tier: 3`, `doi: null`, `arxiv_id: "1009.2803"`,
    `doc_id: "arxiv_1009_2803"`, a reachable `pdf_url`
  - `doi_present.json` — same shape but with a non-null `doi`, to prove Phase 2 does not disturb
    the existing `--doi` branch
  - `in_zotero_no_pdf.json` — `status: "in_zotero_no_pdf"`, `tier: 2`, to reach the attach path
  *(completed: harness/records/*.json; arxiv_only.json's pdf_url is the real, reachable
  https://arxiv.org/pdf/1009.2803)*
- [x] Write a stub `zot` that exits 3 on `add --pdf` with no `--doi` and prints the real
  `No DOI found in PDF` validation-error text to stderr; exits 0 with a minimal valid envelope when
  `--doi` is present. Put it first on `PATH` for harness runs only *(completed:
  harness/stub-path/zot; also implements `attach` and `search` for Phases 3/4)*
- [x] Write a stub `literature-convert.sh` that exits 3 and prints
  `[convert] QUALITY GATE FAILED (<engine>): <reasons>` to stderr, for exercising the quality-gate
  `continue` branch and both `PIPELINE_FAILED` sites *(completed: harness/bin/literature-convert.sh,
  4 modes: success/quality_gate_fail/hard_fail/no_md_produced)*
- [x] Point `LITERATURE_DIR` at a scratch corpus root and confirm the override is honored: run one
  invocation and verify nothing was written under the real `~/Projects/Literature/` *(completed:
  run-harness.sh's before/after md5sum trap on `~/Projects/Literature`, verified on every scenario)*
- [x] Record the exact reproduction commands in the harness directory so Phases 2-7 and the
  implementation summary can cite them verbatim *(completed: harness/README.md)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes exactly two stub executables (`zot`,
`literature-convert.sh`) suffice to reach all three defects' code paths. Confirm at implementation
time by tracing each target `directive_stop`/`continue` site from a harness run and checking no
third external binary (e.g. `curl`, `zotero-resolve-pdf.sh`) also needs stubbing; if one does, add
it here and note the correction rather than silently widening a later phase.

**Correction (confirmed at implementation time)**: two stubs were not sufficient. The
`existing_no_pdf` (attach) path needed under Phase 3 additionally required stubbing
`zotero-resolve-pdf.sh` (avoids a real call to the local Zotero HTTP API at `127.0.0.1:23119`)
and `zotero-read.sh` (the `search` op used by the DOI dedup check) as sibling files placed
alongside the real, symlinked `literature-ingest-online.sh`/`literature-ingest.sh` in
`harness/bin/` (so `$SCRIPT_DIR`-relative resolution picks up the stubs); a stub `curl`
(intercepting only `api.unpaywall.org`, passing every other URL through to the real binary) was
added to `harness/stub-path/` so the attach path's Unpaywall OA-lookup step is controllable
without depending on a real DOI's real Unpaywall record; and a stub `literature-chunk.sh` was
added (also in `harness/bin/`) to deterministically exercise Phase 5's chunking-failure branch.
Final stub count: 6 (`zot`, `curl`, `literature-convert.sh`, `literature-chunk.sh`,
`zotero-resolve-pdf.sh`, `zotero-read.sh`), not 2.

**Files to modify**:
- `specs/109_fix_ingest_online_failure_modes/harness/` (new, task-local scratch — synthetic
  records, stub executables, reproduction commands)

**Verification**:
- Each of the three synthetic records is accepted by `literature-ingest-online.sh`'s own argument
  and schema validation (no exit 64 usage error)
- A stub-driven run reaches `ONLINE_INGEST_ZOTERO_CREATE_FAILED` (exit 3) for `arxiv_only.json`,
  reproducing the observed pre-fix failure
- `LITERATURE_DIR` override confirmed: real corpus untouched after a harness run

---

### Phase 2: Derive an arXiv DOI for arXiv-only records (defect a) [COMPLETED]

**Goal**: Make `zot add --pdf` succeed for records with an `arxiv_id` and no `doi`, by
short-circuiting `_add_from_pdf`'s `doi_override` path.

**Tasks**:
- [x] In `literature-ingest-online.sh`, at the `ZW_CMD` construction in the resolvable path (line
  ~692-696 as of this plan; anchor on `ZW_CMD=("$SCRIPT_DIR/zotero-write.sh" item-add --pdf`),
  extend the existing `if [ -n "$DOI_RAW" ]` branch with an `elif [ -n "$ARXIV_ID_RAW" ]` arm that
  sets `SYNTH_DOI="10.48550/arXiv.$ARXIV_ID_RAW"` and appends `--doi "$SYNTH_DOI"` *(completed)*
- [x] Add a code comment stating that this is arXiv's own mechanical DataCite DOI, used as a
  fallback identifier to bypass `zot add`'s PDF-text DOI regex — explicitly **not** a resolved
  published-venue DOI *(completed)*
- [x] Add a `log` line recording that a synthesized arXiv DOI was used, so the choice is visible in
  the run log rather than silent *(completed)*
- [x] Confirm `DOI_JSON`/`ARXIV_JSON` (lines ~627-628), which feed `patch_global_index`, are left
  untouched — the synthesized DOI must not leak into the corpus index as a real `doi` field
  *(completed: DOI_JSON is computed at line 627 from the original $DOI_RAW, before the ZW_CMD
  block at line ~692 ever sets SYNTH_DOI; harness run confirms index.json's doi field stays null
  for the arxiv-only record)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - add the `elif`
  arXiv-DOI derivation arm to the `ZW_CMD` build

**Verification**:
- `bash -n` parses clean
- Harness run with `arxiv_only.json` + stub `zot`: `zot` receives `--doi 10.48550/arXiv.1009.2803`
  and the run proceeds past item-add instead of stopping at
  `ONLINE_INGEST_ZOTERO_CREATE_FAILED(3)`
- Harness run with `doi_present.json`: the real `doi` is still passed unchanged, and no
  synthesized DOI appears (proves the `elif` did not capture the `if` branch)
- `patch_global_index`'s `doi` argument is still `null` for the arXiv-only record

---

### Phase 3: Clean the staging file on post-download failure stops (defect b, part 1) [COMPLETED]

**Goal**: Stop leaking `$STAGING_PATH` on the two `directive_stop` calls that fire after a
successful download and magic-byte verification.

**Tasks**:
- [x] Add `rm -f "$STAGING_PATH"` immediately before the `ONLINE_INGEST_ZOTERO_CREATE_FAILED`
  `directive_stop` (line ~704-706 as of this plan; anchor on the `ITEM_ADD_EXIT -ne 0` guard)
  *(completed: landed at line 721, shifted +14 lines by Phase 2's added elif arm)*
- [x] Add `rm -f "$STAGING_PATH"` immediately before the `ONLINE_INGEST_ZOTERO_ATTACH_FAILED`
  `directive_stop` (line ~807-809; anchor on the `ATTACH_EXIT -ne 0` guard) *(completed: landed
  at line 827)*
- [x] Leave both `ONLINE_INGEST_DOWNLOAD_FAILED` stops untouched — `download_and_verify()` already
  `rm -f`s `$dest` on both its failure branches *(completed: verified untouched by grep)*
- [x] Confirm no later success path reads `$STAGING_PATH` after these two stop points (both call
  `exit`, so this is a read-through confirmation, not a behavioral question) *(completed: grep of
  every $STAGING_PATH reference confirms directive_stop exits unconditionally at both sites; the
  only other reads are the success-path RESOLVED_PDF_PATH fallback, unreached after either rm -f)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two `directive_stop` sites fire after a
successful download. Confirm at implementation time with
`grep -n 'directive_stop' literature-ingest-online.sh` and check each hit's position relative to
its path's `download_and_verify` call; if a third post-download stop exists, cover it here and
record the correction.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - add staging cleanup at
  the two post-download `directive_stop` sites

**Verification**:
- `bash -n` parses clean
- Harness run forcing item-add failure: `$LITERATURE_DIR/.online-ingest-staging/` contains no
  leftover `<doc_id>.pdf` after the run (compare against a pre-fix run, which does)
- Harness run forcing attach failure: same, on the `in_zotero_no_pdf` path
- The shared `.online-ingest-staging/` directory itself is left in place (it is reused across
  ingests and is not the leak)

---

### Phase 4: Enrich both PIPELINE_FAILED rationales with a diagnostic pointer (defect c) [COMPLETED]

**Goal**: Give the operator an actionable manual next step on a quality-gate rejection, without
introducing any automatic retry or tier selection.

**Tasks**:
- [x] Extend the `ONLINE_INGEST_PIPELINE_FAILED` rationale at line ~717 (resolvable path) to name
  the preserved rejected-markdown path that `literature-convert.sh` writes, and to point at the
  "Converter Tier Selection" section of `context/guides/literature-organization.md` *(deviation:
  altered — see note below; landed at line 770 after Phases 2-3 shifted line numbers)*
- [x] Apply the same enrichment at line ~821 (existing-no-pdf attach path) — this second site was
  missed by the research and must not be left inconsistent *(completed: landed at line 879, via
  the same shared helper)*
- [x] Include the Class A / Class B discriminator inline, phrased as a manual procedure: hits
  clustered near structure/footnotes -> retry with `LITERATURE_CONVERTER=fallback`; hits scattered
  at otherwise-clean sentence boundaries -> re-OCR the source first (e.g.
  `ocrmypdf --force-ocr`), then reconvert *(completed)*
- [x] State explicitly in the message that the retry is deliberately manual — the two classes
  respond oppositely to the fallback engine, so no automatic selection is performed *(completed)*
- [x] Change no control flow: no retry, no exit-code change, no directive-token change. The
  `ONLINE_INGEST_PIPELINE_FAILED` token and exit 6 are part of the file's stable contract
  *(completed: verified via harness -- stdout is still exactly one token line, exit 6)*
- [x] Consider factoring the shared rationale text into one helper or variable so the two sites
  cannot drift; keep it simple if a local variable suffices *(completed: `pipeline_failed_diagnostic_hint()`
  helper function, called identically from both sites)*

**Deviation note**: the "preserved rejected-markdown path" this task assumed does NOT actually
survive through this delegation path. `literature-ingest.sh` writes `literature-convert.sh`'s
`.rejected` sibling into its own `mktemp -d` `TMP_MD_DIR`, then `rm -rf`s that directory on the
quality-gate-rejection `continue` branch before `run_ingest_pipeline()` ever returns to the
bridge. The enrichment was corrected to be honest about this: it points the operator at
re-running `literature-convert.sh` manually against the still-durable `$RESOLVED_PDF_PATH` to
regenerate and inspect the `.rejected` sibling themselves, rather than naming a path that no
longer exists by the time the rationale is read. The rest of the task (guide-section pointer,
Class A/B remedies, manual-only framing, shared helper) is implemented as specified.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two `ONLINE_INGEST_PIPELINE_FAILED`
`directive_stop` sites (lines 717 and 821 as of this plan) — a correction to the research's
single-site claim. Confirm at implementation time with
`grep -n 'ONLINE_INGEST_PIPELINE_FAILED' literature-ingest-online.sh`, excluding the two
header-contract documentation hits (lines ~60 and ~104), and edit every executable site found.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - enrich the rationale
  string at both `PIPELINE_FAILED` `directive_stop` sites

**Verification**:
- `bash -n` parses clean
- Harness run with the stub `literature-convert.sh` forcing a quality-gate rejection: stdout is
  still exactly the single line `ONLINE_INGEST_PIPELINE_FAILED`, exit code is still 6, and stderr
  now carries the rejected-path pointer, the guide section name, and both class remedies
- The same enriched text appears on the attach path's forced failure
- `grep -c` confirms the guide section name is spelled exactly as it appears in
  `context/guides/literature-organization.md` line 346

---

### Phase 5: Remove orphaned doc directories on failure branches (defect b, part 2) [NOT STARTED]

**Goal**: Stop `literature-ingest.sh`'s per-file loop from leaving an empty, unindexed
`sources/<doc_id>/` directory behind when conversion or chunking fails.

**Tasks**:
- [ ] Re-read `literature-ingest.sh` lines 193-212 first and confirm the ordering the safety of
  this fix depends on: the re-ingestion branch (`EXISTING == yes -> rm -rf "$DOC_DIR"`) runs
  **before** `mkdir -p "$DOC_DIR"`, so `DOC_DIR` is always fresh-this-iteration by conversion time
- [ ] Add `rm -rf "$DOC_DIR"` to the quality-gate rejection branch (`CONVERT_EXIT -eq 3`, `continue`
  at line ~239)
- [ ] Add `rm -rf "$DOC_DIR"` to the hard conversion-failure branch (`CONVERT_EXIT -ne 0`,
  `continue` at line ~246)
- [ ] Add `rm -rf "$DOC_DIR"` to the "conversion reported success but no `.md` file found" branch
  (`continue` at line ~259) — **this branch was not identified by the research** and leaks
  identically
- [ ] Add `rm -rf "$DOC_DIR"` to the chunking-failure branch (`CHUNK_COUNT -eq 0 || ! -f
  "$DOC_DIR/chunks.json"`, `continue` at line ~279). Note this branch runs after `DOC_DIR` has been
  reassigned to the converter-derived `DOC_ID` (line ~266-267)
- [ ] Optional, safety-bounded: at the `DOC_DIR` reassignment (line ~266), when the derived
  `DOC_ID` differs from `BASE_DOC_ID`, `rmdir` the now-unused `sources/$BASE_DOC_ID` directory with
  `|| true`. Use `rmdir`, never `rm -rf` — it fails harmlessly on a non-empty directory, which is
  exactly the guard needed against destroying a pre-existing populated corpus directory. Skip this
  sub-step if it cannot be verified cleanly; it is a success-path observation, not one of the three
  reported defects
- [ ] Add no "did we create it this run" bookkeeping — the existing re-ingestion `rm -rf` makes it
  unnecessary

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **four** no-cleanup `continue` branches (lines 239, 246,
259, 279 as of this plan) — a correction to the research's count of three. Confirm at
implementation time by listing every `continue` between the `for source_file` loop head (line 180)
and `done` (line 491) and checking each for a `DOC_DIR` cleanup; edit every branch found, and
record any further divergence from four rather than assuming this count.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest.sh` - add `DOC_DIR` cleanup to
  every no-cleanup `continue` branch in the per-file loop

**Verification**:
- `bash -n` parses clean
- Harness run forcing a quality-gate rejection: no `sources/<doc_id>/` directory remains under the
  scratch `LITERATURE_DIR` (compare against a pre-fix run, which leaves an empty one)
- Harness run forcing a chunking failure: same result for the converter-derived `DOC_ID` directory
- Positive control — a successful ingest still produces a populated `sources/<doc_id>/` with
  `chunks.json` and its index entry, proving the cleanup did not fire on the success path
- Safety control — a pre-existing populated `sources/<doc_id>/` **with** a matching index entry is
  still handled by the existing re-ingestion path, and one **without** an index entry is not
  destroyed by the optional `rmdir` sub-step (it fails on non-empty)
- The script's exit codes, stdout contract, and the `GATE_FAILED`/`FAILED` counters are unchanged

---

### Phase 6: Correct the zotero-item-creation.md understatement [NOT STARTED]

**Goal**: Replace the claim that a `--pdf`-only create merely "yields a barer item" with the
confirmed hard-failure mechanism and the implemented mitigation.

**Tasks**:
- [ ] Edit `context/project/literature/patterns/zotero-item-creation.md` §1 (the "barer item"
  sentence at line ~28) to state that a `--pdf`-only create can also hard-fail outright — exit 3,
  `No DOI found in PDF`, with no item created at all
- [ ] Document the mechanism concretely: `_add_from_pdf` calls `extract_doi()`, which regexes
  `10\.\d{4,9}/\S+` over the PDF's first two pages only, and `emit_error`s before reaching
  `writer.add_item` when that finds nothing
- [ ] Document the implemented mitigation from Phase 2 (`10.48550/arXiv.<id>` as `--doi` for
  arXiv-only records) and the honest caveat that Crossref will not resolve a DataCite DOI, so the
  resulting Zotero item is metadata-bare on the Zotero side while the corpus index is unaffected
- [ ] Note in §6 (verification scope limitation) that `zot add --dry-run` returns a static preview
  and never calls `_add_from_pdf`, so dry-run cannot exercise or reproduce this failure
- [ ] Cite durable anchors only — file names, function names, section headings. **No task-number
  references**: this file lives outside `specs/**` and is governed by
  `.claude/rules/no-task-references-in-deliverables.md`

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` -
  correct §1's understatement; extend §6's dry-run limitation note

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no code or executable content touched
- The corrected text matches the Phase 2 implementation as landed, not as planned
- `bash .claude/scripts/check-task-references.sh` (or an equivalent `grep -nE 'task [0-9]+'`) reports
  no task-number reference introduced in this file

---

### Phase 7: Integration verification and source-store boundary check [NOT STARTED]

**Goal**: Confirm all four fixes hold together on a single end-to-end path, and that nothing landed
in the deploy artifact.

**Tasks**:
- [ ] Run the full harness suite against the fixed scripts: arXiv-only record through item-add,
  forced item-add failure, forced attach failure, forced quality-gate rejection, forced chunking
  failure, and one clean success path
- [ ] Confirm the stable contract is intact: for each forced failure, stdout is exactly one
  directive token and the exit code matches the header's documented mapping (1/2/3/5/6). No token
  spelling, exit number, or input field name changed
- [ ] Confirm no leftovers under the scratch `LITERATURE_DIR`: no staging PDF, no empty
  `sources/<doc_id>/`, no partial index entries
- [ ] Run `git status --short` and `git diff --stat` and confirm **no path under `.claude/`** was
  modified — all edits are under `agent-system/extensions/literature/`
- [ ] Confirm the real corpus at the default `LITERATURE_DIR` was never written to during any
  verification run
- [ ] Record before/after evidence (command, observed output, observed filesystem state) for each of
  the three defects in the implementation summary
- [ ] Note in the summary that `literature-ingest.sh` was modified despite the bridge header calling
  it the "UNMODIFIED literature-ingest.sh pipeline" — a narrow cleanup fix benefiting every caller,
  with no change to pipeline semantics, output, or exit codes

**Timing**: 0.75 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts a six-scenario harness suite (arXiv-only success, forced
item-add failure, forced attach failure, forced quality-gate rejection, forced chunking failure,
clean success control). Confirm at implementation time against the reproduction commands Phase 1
actually recorded — if Phase 1's Scope Hypothesis found an additional stub or path, the scenario
count here rises accordingly and must be updated rather than left as planned.

**Files to modify**:
- `specs/109_fix_ingest_online_failure_modes/summaries/01_ingest-online-failure-modes-summary.md`
  (created at implementation time)

**Verification**:
- All six harness scenarios produce the expected directive token and exit code
- Scratch `LITERATURE_DIR` is clean of orphans after every failure scenario
- `git diff --stat` shows only `agent-system/extensions/literature/**` and `specs/**` paths
- `bash -n` clean on both modified scripts

---

## Testing & Validation

- [ ] `bash -n` passes on `literature-ingest-online.sh` and `literature-ingest.sh`
- [ ] arXiv-only record: `zot` receives `--doi 10.48550/arXiv.<id>`; the run no longer stops at
  `ONLINE_INGEST_ZOTERO_CREATE_FAILED(3)`
- [ ] DOI-present record: the real DOI is still passed; no synthesized DOI appears
- [ ] Forced `CREATE_FAILED` and `ATTACH_FAILED`: no staging PDF remains in
  `.online-ingest-staging/`
- [ ] Forced quality-gate rejection and forced chunking failure: no empty `sources/<doc_id>/`
  remains
- [ ] Successful ingest (positive control): `sources/<doc_id>/` is populated with `chunks.json` and
  indexed — cleanup does not fire on the success path
- [ ] Both `PIPELINE_FAILED` rationales carry the rejected-path pointer, the guide section name, and
  both Class A / Class B remedies; stdout remains one token and the exit code remains 6
- [ ] No automatic retry, tier selection, or classifier was added anywhere
- [ ] `zotero-item-creation.md` §1 no longer understates the failure, and introduces no
  task-number reference
- [ ] `git diff` touches no `.claude/**` path
- [ ] The real `~/Projects/Literature/` corpus is unmodified by any verification run

## Artifacts & Outputs

- `specs/109_fix_ingest_online_failure_modes/plans/01_ingest-online-failure-modes.md` (this file)
- `specs/109_fix_ingest_online_failure_modes/harness/` — synthetic records, stub executables,
  reproduction commands
- `specs/109_fix_ingest_online_failure_modes/summaries/01_ingest-online-failure-modes-summary.md`
- Modified: `agent-system/extensions/literature/scripts/literature-ingest-online.sh`
- Modified: `agent-system/extensions/literature/scripts/literature-ingest.sh`
- Modified:
  `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`

## Rollback/Contingency

All changes are confined to two shell scripts and one markdown file in the source store, committed
per phase. Reverting is `git revert` of the phase commits — no state migration, no data
transformation, and no schema change is involved.

Per-defect contingencies:

- **(a)**: if the synthesized DataCite DOI turns out to cause a *different* `zot` failure (rather
  than merely an unresolved metadata-bare item), revert Phase 2 alone; the pre-fix behavior is
  unchanged for every record that already carries a real `doi`.
- **(b) staging file**: `rm -f` on an already-exiting path is trivially revertible and cannot
  affect a success path.
- **(b) doc directory**: if any evidence emerges that `DOC_DIR` is *not* always fresh-this-iteration
  at conversion time, revert Phase 5 immediately — the safety of the unconditional `rm -rf` rests
  entirely on that ordering. Leaving orphan directories is strictly preferable to deleting a
  populated corpus directory.
- **(c)**: message text only; reverting restores the previous rationale with no behavioral
  difference.
