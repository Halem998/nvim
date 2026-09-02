# Implementation Plan: Task #105

- **Task**: 105 - Add an OCR tier for image-only and poor-vintage-OCR PDFs
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: Task 102 (converter-tier characterization; COMPLETED)
- **Research Inputs**: specs/105_add_ocr_tier_for_image_only_pdfs/reports/01_add-ocr-tier-image-only-pdfs.md
- **Artifacts**: plans/01_add-ocr-tier-image-only-pdfs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature conversion pipeline has no OCR path at all, and its two failure exits say nothing
about OCR. A genuinely image-only PDF exits 2 with `"All engine tiers produced empty output"`
before the quality gate is ever reached, and `literature-ingest.sh` dumps that into the same
generic "Files failed" bucket as a missing input file. This plan lands the cheap, mandatory fix
first — distinct, actionable, OCR-naming failure messaging at both the exit-2 and exit-3 paths,
plus a dedicated "needs OCR" bucket in the ingest summary mirroring the existing exit-3 bucket —
and then adds `LITERATURE_CONVERTER=ocr` as an explicit, operator-invoked, never-auto mode built
on the same escape-hatch template as the existing `pdftotext` mode. Done means: an operator who
hits either failure is told the exact remedy command at the point of failure, and that command
exists and works. The edit target is `agent-system/extensions/literature/` throughout; nothing in
`.claude/` is hand-authored (see `.claude/rules/source-store-deploy-boundary.md`).

### Research Integration

The plan is built directly on the research report's confirmed mechanics:

- **The exit-2 path is pre-gate.** In `run_unified_engine()`'s embedded Python `MAIN` block, the
  `if not content or not content.strip(): sys.exit(2)` check runs *before* `gate_doc =
  fitz.open(pdf_path)`. A fully image-only PDF therefore never technically fails the quality gate;
  it fails earlier, at exit 2. Phase 1 must fix the message at that site, not at the gate.
- **Exit 2 is an overloaded code.** It is emitted by at least two distinct producers: the
  empty-output path above, and the `LITERATURE_CONVERTER=pymupdf4llm`-but-primary-tier-unavailable
  path (both the bash-level `return 2` in `run_unified_engine` and the Python-level
  `sys.exit(2)`). A consumer must therefore key off a distinctive stderr marker, never off the
  bare exit code. This is exactly the mechanism `literature-ingest.sh` already uses for exit 3
  (`grep -m1 'QUALITY GATE FAILED'`), and Phase 2 mirrors it.
- **`ocrmypdf` needs detection, not provisioning.** `ocrmypdf` 17.4.2 and `tesseract` 5.5.2 are
  present system-wide via the NixOS system profile. Being plain CLI binaries rather than compiled
  Python wheels, they need only the `command -v` half of the
  `literature-pyenv-provision.sh` graceful-detection contract — none of the pinned-`uv`-venv /
  nix-ld-shim machinery the primary tier requires. They remain an ungoverned external dependency
  this repo does not provision, and must never be assumed present.
- **`pdftotext` is the template, not the primary/fallback tiers.** The script header already
  establishes a real, useful tier deliberately excluded from `auto`'s silent chain. The OCR mode
  copies that shape exactly.
- **Two distinct conditions, two distinct responses.** Text-layer *absence* (OCR enables
  extraction at all; `ocrmypdf`'s default skip-text behavior is correct and non-destructive) vs.
  poor OCR *vintage* (an existing degraded layer; `--force-ocr` is the remedy and is destructive).
  A design keying only on zero-text-layer misses the second, larger class — `gabbay_2000` is a
  live, currently-un-ingested 614-page instance failing solely on
  `sentence_boundary_glue_count=10`.
- **The manual workflow already exists.** `~/Projects/Literature/_staging_gametheory/`'s
  operator-built `ocr/`, `ocr2/`, `ocr3/`, `sweep_default/`, `sweep_fallback/`,
  `sweep_lastresort/` folders are direct evidence of hand-run tier escalation this plan folds
  into one command.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap phases were requested.

## Goals & Non-Goals

**Goals**:
- Every conversion failure caused by a missing or degraded text layer names its remedy command
  in stderr, at the point of failure, without the operator having to know to open a guide.
- `literature-ingest.sh` reports needs-OCR documents in their own distinct summary bucket,
  separate from both hard failures and quality-gate rejections.
- `LITERATURE_CONVERTER=ocr` exists as an explicit, single-document, operator-invoked mode that
  shells out to `ocrmypdf` and feeds the result through the existing conversion + normalization +
  quality-gate path unchanged.
- The poor-vintage (Class B) case is reachable via an explicit opt-in to `--force-ocr`.
- Absence of `ocrmypdf` degrades gracefully with a clear, actionable message — never a crash and
  never a silent no-op.
- Regression tests lock in both the messaging contract and the never-auto-invoked guarantee.

**Non-Goals**:
- Adding OCR as a 4th tier inside `auto`'s automatic chain. Explicitly prohibited: a full-book
  OCR run (614 pages; a 143MB scan) inside `literature-ingest.sh`'s batch loop would silently
  balloon wall-clock time.
- Making `--force-ocr` a default anywhere. It rasterizes every page and discards any existing
  text layer, which is actively destructive on documents that do not need it.
- Automatic Class A vs. Class B discrimination. Task 102 established this is diagnostic and
  non-automatable; that finding is not re-litigated here.
- Automatic reconversion or retry of a gate-rejected document.
- Provisioning, vendoring, or version-pinning `ocrmypdf`/`tesseract`.
- Re-ingesting `gabbay_2000` or any other live corpus document as part of this task. Corpus
  remediation is separate operator work; the test suite must not read from or write to
  `~/Projects/Literature/`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Exit-2 bucketing in ingest keys off the bare exit code and mis-buckets the primary-tier-unavailable case as "needs OCR" | H | H | Phase 2 keys off a distinctive stderr marker emitted only by the empty-output path, mirroring the existing `grep -m1 'QUALITY GATE FAILED'` mechanism. Phase 2's verification explicitly exercises the venv-unavailable exit-2 case and asserts it does NOT land in the OCR bucket. |
| Phase 1 writes remedy strings that Phase 3 must then rewrite once the mode exists | M | M | Phase 1 routes both failure paths through a single shared remedy-hint emitter so Phase 3 changes exactly one string, not scattered copies. |
| The new `ocr_explicit` branch in the main dispatch collapses exit 3 into a generic failure, the way the existing `pdftotext` branch's `&& CONVERTED=1` does | M | M | The OCR branch runs through `run_unified_engine`, which can legitimately return 3; Phase 3 handles 0/2/3 explicitly in that branch and its verification asserts a post-OCR gate rejection still exits 3 with a `.rejected` sibling. |
| `LITERATURE_CONVERTER=ocr` later widened into `auto` as a "convenience" | H | M | Explicit prohibition comment at the mode's definition mirroring the `pdftotext` header language, plus a regression test asserting `auto` on an image-only fixture exits 2 without invoking `ocrmypdf`. |
| `ocrmypdf` absent on another operator's machine makes the mode silently unavailable | M | M | `command -v ocrmypdf` up front with a clear stderr message naming the missing binary and how to install it; non-zero exit, never a crash and never a fallthrough to a different engine. |
| Test fixture for an image-only PDF proves harder to construct than assumed | M | L | Phase 4 carries a Scope Hypothesis; the fallback is a render-page-to-pixmap-then-`insert_image` construction using the same plain `fitz` idiom the existing `build_*_pdf` fixtures use. |
| Long `ocrmypdf` runs appear hung to the operator | L | M | The mode logs a start notice naming the page count and warning the run is minutes-scale before invoking `ocrmypdf`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 2, 3 |

Phases within the same wave can execute in parallel. Waves 2 and 3 are territory-clean: Phase 2
owns `literature-ingest.sh`, Phase 3 owns `literature-convert.sh`, Phase 4 owns
`scripts/tests/`, Phase 5 owns `context/` and `index-entries.json`.

---

### Phase 1: Actionable OCR-naming failure messages in literature-convert.sh [COMPLETED]

**Goal**: Both text-layer failure paths in `literature-convert.sh` print a distinctive,
greppable marker and name a concrete remedy command, instead of today's generic messages.

**Tasks**:
- [x] Add a single shared remedy-hint emitter (one function or one constant string) used by both
      failure paths, so the remedy text has exactly one definition to update in Phase 3.
- [x] Rewrite the exit-2 empty-output message in `run_unified_engine()`'s embedded Python `MAIN`
      block (currently `"[convert] All engine tiers produced empty output"`). It must carry a
      distinctive marker token (e.g. `NO TEXT LAYER`) that no other exit-2 producer emits, state
      that the PDF appears to have no extractable text layer, and name the `ocrmypdf` remedy
      command with the actual input path substituted in.
- [x] Extend the exit-3 gate-rejection stderr (currently the `QUALITY GATE FAILED (...)` line
      plus the `Rejected output written to:` line) with an additional remedy line. Preserve the
      existing `QUALITY GATE FAILED` prefix verbatim and byte-for-byte — `literature-ingest.sh`
      greps for it and Phase 2 must not have to touch that code path.
- [x] Make the exit-3 remedy line distinguish the two Class B/Class A responses in one sentence:
      try `LITERATURE_CONVERTER=fallback` for a structuring artifact, or re-OCR with
      `ocrmypdf --force-ocr` for a degraded text layer, and point at the
      `context/guides/literature-organization.md` "Converter Tier Selection" section by name.
- [x] Update the bash-level `log "All converters failed for: $INPUT"` message before the outer
      `exit 2` so the DJVU and pdftotext paths that reach it are not left with a bare generic line.
- [x] Update the `Exit codes:` block in the script header comment to state that exit 2 covers both
      "no engine produced usable output" and "no text layer present", and that the two are
      distinguished by the stderr marker, not by the code.
- [x] Verify no task-number references appear in any new comment or message string; cite the guide
      section by heading name only (`.claude/rules/no-task-references-in-deliverables.md`).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two failure paths need messaging and that the
`QUALITY GATE FAILED` prefix is the only cross-file-consumed string in them. Confirm at
implementation time by grepping `literature-convert.sh` for every `sys.exit(2)`, `return 2`,
`exit 2`, and `sys.exit(3)` site, and by grepping the whole extension for consumers of
`convert`-emitted stderr strings (`grep -rn 'QUALITY GATE FAILED\|All engine tiers' agent-system/extensions/literature`).
If a third failure path or a second consumed string turns up, extend this phase rather than
deferring it.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` - shared remedy emitter;
  exit-2 empty-output message; exit-3 gate-rejection remedy line; bash-level all-converters-failed
  message; header `Exit codes:` block.

**Verification**:
- `bash -n scripts/literature-convert.sh` passes.
- `bash scripts/literature-convert.sh --self-test` still passes (the existing fixture self-test
  must not regress).
- Convert a known-good fixture PDF end-to-end and confirm exit 0 with unchanged success output.
- Confirm the new exit-2 marker string is unique within the script
  (`grep -c` on the marker returns the expected single definition site).

---

### Phase 2: Distinct "needs OCR" bucket in literature-ingest.sh [COMPLETED]

**Goal**: An image-only PDF is reported in its own summary bucket with its own counter and entry
list, mirroring the existing exit-3 `GATE_FAILED` treatment, instead of the generic `FAILED`
counter.

**Tasks**:
- [x] Add an `OCR_NEEDED` counter and a `declare -a OCR_NEEDED_ENTRIES=()` array alongside the
      existing `FAILED` / `GATE_FAILED` / `GATE_FAILED_ENTRIES` declarations.
- [x] In the per-file exit-code dispatch, insert a branch before the generic
      `elif [ "$CONVERT_EXIT" -ne 0 ]` branch that matches exit 2 AND a stderr hit on Phase 1's
      distinctive marker. Exit 2 without the marker must continue to fall through to the generic
      hard-failure branch untouched.
- [x] Log the needs-OCR case distinctly (naming the file and the remedy command), accumulate the
      entry, increment the counter, clean up the temp dir and stderr file, and `continue` —
      following the exit-3 branch's structure exactly.
- [x] Add a `Files needing OCR: $OCR_NEEDED` line to the final summary block, with an indented
      entry list under it, mirroring the `Files quality-gate-failed:` block's shape and its
      explanatory parenthetical.
- [x] Update the all-files-failed aggregate message (currently reporting only gate-rejected and
      hard-failed counts) to include the needs-OCR count.
- [x] Check whether any other consumer parses the ingest summary (skill-literature, the audit
      scripts, tests) and would be broken by a new summary line; adjust or note as needed.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exit 2 has at least two distinct producers in
`literature-convert.sh` and therefore cannot be bucketed on the code alone. Confirm at
implementation time by enumerating the exit-2 sites found in Phase 1's scope check, and by
actually running the primary-tier-unavailable case (`LITERATURE_CONVERTER=pymupdf4llm` with
`LITERATURE_PYENV_DIR` pointed at a nonexistent directory) to observe a marker-free exit 2.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest.sh` - counter/array declarations;
  per-file exit-code dispatch; final summary block; all-files-failed aggregate message.

**Verification**:
- `bash -n scripts/literature-ingest.sh` passes.
- Ingest a directory containing one good PDF and one image-only PDF into a scratch output
  directory (never `~/Projects/Literature/`); assert the summary reports the image-only file under
  `Files needing OCR` with `Files failed: 0`.
- Assert the marker-free exit-2 case (primary tier forced but unavailable) still lands in
  `Files failed` and NOT in `Files needing OCR`.
- Assert a gate-rejected document still lands in `Files quality-gate-failed` unchanged.

---

### Phase 3: LITERATURE_CONVERTER=ocr explicit, non-auto mode [COMPLETED]

**Goal**: An operator can run one command to OCR a scanned PDF and convert it, and that mode is
structurally incapable of being reached by `auto`.

**Tasks**:
- [x] Add `ocr) ENGINE_MODE="ocr_explicit" ;;` to the `LITERATURE_CONVERTER` case statement.
- [x] Implement `try_ocr_explicit()` immediately after `try_pdftotext_explicit()`, carrying the
      same "explicit, NOT part of 'auto'" prohibition comment in its own words.
- [x] Guard on `command -v ocrmypdf` (and report `tesseract` absence too if `ocrmypdf` surfaces
      it): log a clear message naming the missing binary and return non-zero. Never fall through
      to another engine, never crash the caller — the `literature-pyenv-provision.sh`
      graceful-detection contract.
- [x] Log a start notice before invoking `ocrmypdf` that names the input and warns the run is
      minutes-scale on large documents.
- [x] Run `ocrmypdf` into a `mktemp --suffix=.pdf` temp file using its default (skip-text)
      behavior, which OCRs only pages with no existing text layer and is non-destructive. Remove
      the temp file on every exit path.
- [x] Add `LITERATURE_OCR_FORCE=1` as the explicit, documented opt-in that adds `--force-ocr` for
      the poor-vintage (Class B) case. Comment at the flag site that `--force-ocr` rasterizes every
      page and discards any existing text layer, so it must never become a default.
- [x] Feed the OCR'd temp PDF through `run_unified_engine "$tmp_pdf" "$output" "fallback_only"`,
      so normalization and the quality gate run unchanged. Comment the deliberate choice of the
      always-available column-clustering fallback tier (no venv dependency) over the primary tier.
- [x] Add the `ocr_explicit` branch to the main conversion dispatch, handling `run_unified_engine`
      exit codes explicitly: 0 sets `CONVERTED=1`, 3 sets `GATE_FAILED=1`, anything else leaves
      `CONVERTED=0`. Do not copy the `pdftotext` branch's `&& CONVERTED=1` form, which discards
      the exit-3 distinction.
- [x] Update the shared remedy-hint string from Phase 1 to name `LITERATURE_CONVERTER=ocr` (and
      `LITERATURE_OCR_FORCE=1` on the exit-3 path) now that the mode exists.
- [x] Update the script header comment: add `ocr` to the `LITERATURE_CONVERTER` environment
      documentation with its non-auto prohibition, add `LITERATURE_OCR_FORCE` to the
      `Environment:` block, and add `ocr` to the engine-tier ladder comment as an explicit
      escape hatch (not a numbered auto tier).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes `ocrmypdf` and `tesseract` are invocable in the
implementation environment and that `ocrmypdf`'s default behavior is skip-text. Confirm at
implementation time with `command -v ocrmypdf tesseract`, `ocrmypdf --version`, and
`ocrmypdf --help` (checking the documented default for pages that already carry text). If the
default differs from skip-text on the installed version, pass the explicit flag rather than
relying on the default. If `ocrmypdf` is absent, implement and verify the graceful-detection path
and record the runtime path as unverified rather than assuming it works.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` - `ocr` case arm;
  `try_ocr_explicit()`; main dispatch branch; remedy-hint string update; header comment blocks.

**Verification**:
- `bash -n scripts/literature-convert.sh` passes; `--self-test` still passes.
- `LITERATURE_CONVERTER=ocr` on an image-only fixture produces a non-empty `.md` and exits 0.
- `LITERATURE_CONVERTER=ocr` with `ocrmypdf` masked off `PATH` exits non-zero with the
  graceful-detection message and no traceback.
- A post-OCR gate rejection still exits 3 and writes a `.rejected` sibling with no final `.md`.
- `LITERATURE_CONVERTER=auto` on the image-only fixture still exits 2 and never invokes
  `ocrmypdf`.
- `LITERATURE_CONVERTER=auto`, `=fallback`, and `=pdftotext` on a known-good fixture behave
  exactly as before (no regression in the shared dispatch).
- No temp PDF remains after any of the above runs.

---

### Phase 4: Regression tests [COMPLETED]

**Goal**: The messaging contract, the bucketing discrimination, and the never-auto-invoked
guarantee are locked in by tests that fail if any of them regresses.

**Tasks**:
- [x] Add an image-only PDF fixture builder to `scripts/tests/generate-test-fixtures.py`,
      following the existing `build_*_pdf` convention: render a text-bearing page to a pixmap and
      insert it as an image into a fresh page so the result has visible content and zero
      extractable text. Assert in the builder itself that `page.get_text()` returns empty.
- [x] Add a test to `scripts/tests/test-literature-convert.sh` asserting `auto` on the image-only
      fixture exits 2, stderr carries the distinctive marker, and stderr names the
      `LITERATURE_CONVERTER=ocr` remedy.
- [x] Add a test asserting `auto` on the image-only fixture never invokes `ocrmypdf` (a `PATH`
      shim recording invocation, or an assertion that no OCR log line appears).
- [x] Add a test asserting `LITERATURE_CONVERTER=ocr` with `ocrmypdf` absent from `PATH` fails
      with the graceful-detection message and no traceback. This test must run unconditionally,
      since it does not require `ocrmypdf` to be installed.
- [x] Add an `ocrmypdf`-dependent test that runs the real OCR path on the image-only fixture. It
      must SKIP WITH A VISIBLE WARNING when `ocrmypdf` is absent, following the existing
      `LITERATURE_TEST_PDF` skip idiom — never silently pass and never fail the suite.
- [x] Add a test asserting the exit-3 gate-rejection stderr still starts with the unmodified
      `QUALITY GATE FAILED` prefix and now also carries the remedy line.
- [x] Add coverage for `literature-ingest.sh`'s new bucket: an image-only file lands in
      `Files needing OCR`, a marker-free exit-2 lands in `Files failed`. Place it in
      `test-literature-convert.sh` or a sibling test file, whichever matches the suite's existing
      separation of concerns.
- [x] Register any new test file in `manifest.json`'s `provides.scripts` array (existing test *(completed: no new test file added, both files already registered)*
      files are listed there); no registration change is needed if tests are added to existing
      files.
- [x] Confirm every test writes only to scratch temp directories and never reads from or writes to
      `~/Projects/Literature/`, per the suite's stated corpus constraint.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts an image-only PDF fixture is cheaply constructible with
plain `fitz` (the idiom every existing fixture uses) and that `test-literature-convert.sh` is the
right host file. Confirm at implementation time by building the fixture and asserting
`page.get_text()` is empty on it before writing any test against it, and by reading the existing
suite's section layout to place the ingest-level tests correctly.

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` - image-only
  fixture builder.
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` - new test cases.
- `agent-system/extensions/literature/manifest.json` - only if a new test file is added.

**Verification**:
- `bash scripts/tests/test-literature-convert.sh` exits 0 with the new tests reported as passing
  (or visibly skipped, for the `ocrmypdf`-dependent one).
- Temporarily reverting each of Phase 1's marker and Phase 2's bucket branch makes the
  corresponding new test fail — confirming the tests actually bind to the behavior.
- The pre-existing tests in the suite still pass.

---

### Phase 5: Documentation and dependency registration [NOT STARTED]

**Goal**: The new mode and the absence class are documented where an operator and a future agent
will find them, closing the "documented but not discoverable" gap the research identified.

**Tasks**:
- [ ] Add a `Class C: no text layer (absence)` treatment to
      `context/guides/literature-organization.md`'s "Converter Tier Selection" section — either a
      third column on the existing Class A/Class B table or a parallel subsection, whichever reads
      better against the existing prose. It must state the tell (exit 2 with the marker; both
      tiers produce empty output), the remedy (`LITERATURE_CONVERTER=ocr`), and that this is a
      third failure mode distinct from the two post-conversion glue-defect classes.
- [ ] Update the Class B `Correct remedy` cell to name `LITERATURE_OCR_FORCE=1
      LITERATURE_CONVERTER=ocr` as the in-pipeline way to run the `ocrmypdf --force-ocr` remedy it
      already prescribes in prose.
- [ ] Extend the section's "No automatic tier selection exists or is intended" paragraph to state
      that the OCR mode is likewise explicit-only and never entered by `auto`, and why (a
      document-scale, minutes-long operation inside a batch loop).
- [ ] Add `ocrmypdf` and `tesseract` to
      `context/project/literature/domain/extension-dependencies.md` as optional, externally
      provisioned, gracefully detected dependencies required only by `LITERATURE_CONVERTER=ocr` —
      explicitly contrasted with the primary tier's pinned-venv provisioning, and explicitly noted
      as not provisioned or guaranteed by this repo.
- [ ] Refresh `line_count` in `index-entries.json` for every context file this phase edits, and
      extend that entry's `keywords`/`topics` with the OCR vocabulary (`ocr`, `ocrmypdf`,
      `text-layer`, `scanned`) so the new content is retrievable.
- [ ] Re-grep the extension for any other surface documenting `LITERATURE_CONVERTER` values
      (skills, README, merge-sources) and update any that enumerate the mode list.
- [ ] Verify no task-number references appear in any edited file
      (`.claude/rules/no-task-references-in-deliverables.md`); cite section headings and filenames.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the `LITERATURE_CONVERTER` documentation surface is
limited to `context/guides/literature-organization.md` plus the script header. Confirm at
implementation time with
`grep -rn 'LITERATURE_CONVERTER' agent-system/extensions/literature --include='*.md' --include='*.json'`
and extend the file list if additional surfaces appear.

**Files to modify**:
- `agent-system/extensions/literature/context/guides/literature-organization.md` - Class C
  treatment, Class B remedy cell, no-auto-selection paragraph.
- `agent-system/extensions/literature/context/project/literature/domain/extension-dependencies.md`
  - optional external dependency entry.
- `agent-system/extensions/literature/index-entries.json` - `line_count` refresh, keyword/topic
  additions.
- Any further surface the re-grep turns up.

**Verification**:
- `jq empty index-entries.json` parses, and each edited entry's `line_count` matches
  `wc -l` on the file it describes.
- The guide's Class C content names the exact command an operator would type, verbatim and
  copy-pasteable.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no new
  violations.

---

## Testing & Validation

- [ ] `bash -n` clean on `literature-convert.sh` and `literature-ingest.sh`.
- [ ] `bash scripts/literature-convert.sh --self-test` passes (existing fixture self-test
      unregressed).
- [ ] `bash scripts/tests/test-literature-convert.sh` exits 0, with new tests passing or visibly
      skipping.
- [ ] `bash scripts/tests/test-quality-gate-notation.sh` and
      `bash scripts/tests/test-literature-build-index.sh` still pass (no collateral regression).
- [ ] An image-only PDF: `auto` exits 2 with the marker and the named remedy; `ocr` converts it.
- [ ] A marker-free exit-2 (primary tier forced but unavailable) is still bucketed as a hard
      failure, not as needs-OCR.
- [ ] A gate-rejected document still exits 3, writes a `.rejected` sibling, and appears in the
      `Files quality-gate-failed` bucket unchanged.
- [ ] `LITERATURE_CONVERTER=auto`/`fallback`/`pdftotext` on a known-good fixture are byte-identical
      in behavior to before this task.
- [ ] `ocrmypdf` masked off `PATH` produces a clear message and a clean non-zero exit.
- [ ] No test touches `~/Projects/Literature/`.
- [ ] `jq empty` passes on every edited JSON file.

## Artifacts & Outputs

- `specs/105_add_ocr_tier_for_image_only_pdfs/plans/01_add-ocr-tier-image-only-pdfs.md` (this file)
- `specs/105_add_ocr_tier_for_image_only_pdfs/summaries/01_add-ocr-tier-image-only-pdfs-summary.md`
- Modified: `agent-system/extensions/literature/scripts/literature-convert.sh`
- Modified: `agent-system/extensions/literature/scripts/literature-ingest.sh`
- Modified: `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py`
- Modified: `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`
- Modified: `agent-system/extensions/literature/context/guides/literature-organization.md`
- Modified: `agent-system/extensions/literature/context/project/literature/domain/extension-dependencies.md`
- Modified: `agent-system/extensions/literature/index-entries.json`
- Possibly modified: `agent-system/extensions/literature/manifest.json` (only if a new test file
  is added)

## Rollback/Contingency

Every phase is a self-contained commit against the source store; no state or schema migration is
involved and no corpus data is mutated. Reverting is `git revert` of the phase commits in reverse
order.

Phases 1 and 2 are independently valuable and shippable on their own: if Phase 3 proves harder
than estimated (an `ocrmypdf` invocation problem, or the post-OCR gate behaving unexpectedly), the
correct fallback is to stop after Phase 2 with the messaging naming the manual
`ocrmypdf` command — which is the research report's "mandatory" deliverable and already removes
the misleading-rejection problem — and to record the OCR mode as a separate follow-up rather than
landing it half-built.

If Phase 3 lands but the OCR mode later proves unreliable, it can be neutralized in one line by
removing the `ocr)` case arm without touching any other tier, since the mode is never reached by
`auto` and nothing else in the pipeline invokes it.
