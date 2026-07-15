# Implementation Plan: Record Markdown-Retention Decision for Literature Segmentation

- **Task**: 868 - Evaluate whether Typst segmentation is superior AND just-as-convenient versus the current markdown chunking, and implement conditionally
- **Status**: [NOT STARTED]
- **Effort**: 1.25 hours
- **Dependencies**: 866 (complete)
- **Research Inputs**: reports/01_typst-segmentation-decision.md
- **Artifacts**: plans/01_markdown-retention-decision.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research reached a decisive NO-GO: keep markdown as the sole convert/chunk/index format for the
literature extension. No PDF-to-Typst converter comparable in maturity to the production
`pymupdf4llm`/PyMuPDF path exists; typst headings and `#theorem[]` functions offer no segmentation
advantage for PDF-sourced (not natively authored) content; and the chunk-level SQLite FTS5 index
only ever indexes extracted plain text, so markup syntax is irrelevant to retrieval quality.
Because the outcome is "no format change," the implementation is purely documentation: record a
durable decision record in the literature extension's context tree, register it so future readers
discover it, and keep the extension's merge-source doc (EXTENSION.md) in sync. No code changes are
in scope. Definition of done: a durable, task-number-free decision record exists under
`agent-system/extensions/literature/`, is registered in the extension context index, is referenced
from EXTENSION.md, and CLAUDE.md remains auto-generated (no hand-edits).

### Research Integration

The full evidence base is in `reports/01_typst-segmentation-decision.md`. Key findings carried into
the decision record:
- **PDF-to-Typst converter immaturity**: only candidates are an LLM-based hobby project
  ("very much in development") and unvetted ad-supported web tools; pandoc has a typst reader and
  writer but no PDF reader at all, so it cannot bridge PDF to structured text. The "just as
  convenient" bar fails.
- **No segmentation advantage**: typst `=`/`==` headings carry the same information as markdown
  `#`/`##`; `#theorem[]` is authoring-time package sugar (`@preview/thmbox`) that cannot be
  reconstructed from rendered PDF glyphs any better than the existing plain-text keyword-regex
  atomic-block detector. The "superior" bar fails.
- **Format-agnostic index layer**: `literature-build-index.sh` (chunk discovery via
  `find -name chunks.json`, chunk reads via the manifest `source_path` field) and
  `literature-search.sh`'s `do_read()` have no `.md` hardcoding. The one format-hardcoded spot is
  `literature-ingest.sh`'s `ls "$TMP_MD_DIR"/*.md` output-discovery glob.
- **`source_format` clarification**: it is a document-level index field
  (`specs/literature/index.json`, values `pdf`/`djvu`/`manual`) recording the original source
  document's format — not a column on `literature-schema.sql`'s `chunks_data`/FTS5 table and not a
  chunk-markup-dialect signal.
- **Re-evaluation trigger**: reopen only if a maintained, deterministic (non-LLM), install-cheap
  PDF-to-Typst converter reaches `pymupdf4llm`-level correctness parity on multi-column/math-heavy
  academic PDFs.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this plan (no `roadmap_path` provided, no `roadmap_flag`). Not
applicable to a no-format-change documentation outcome.

## Goals & Non-Goals

**Goals**:
- Record a durable, self-contained decision record stating markdown is retained as the sole
  convert/chunk/index format, with rationale and the research's durable-anchor evidence.
- Include, as a future-facing note in that record, the one factual correction the research
  surfaced: `literature-ingest.sh`'s `*.md` glob is the only format-hardcoded spot; the rest of
  the index/search layer is already format-agnostic. Also correct the `source_format`
  characterization.
- Make the decision record discoverable by registering it in the extension's context index
  (`index-entries.json`).
- Keep EXTENSION.md (the merge-source doc) in sync with a brief reference to the decision, using a
  durable anchor (filename/section heading), not a task number.

**Non-Goals**:
- No PDF-to-Typst conversion path, no typst-aware segmenter, no index-schema change (the decision
  is NO-GO — building any of these is explicitly out of scope).
- No change to `literature-ingest.sh`'s `*.md` glob or any other script (the glob stays
  markdown-only; the correction is recorded as a note, not implemented).
- No hand-edit of any generated CLAUDE.md (it is auto-generated from merge sources).
- No task-number citations anywhere in the deliverable files (they live outside `specs/**`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future contributor re-proposes typst segmentation without knowing this evaluation happened | M | M | The decision record is placed in the extension context tree, registered in the index with "typst"/"format" keywords, and referenced from EXTENSION.md; it names an explicit re-evaluation trigger |
| Task-number citation accidentally leaks into a deliverable file (outside specs/**) | M | L | Phase 2 verification greps the new doc and EXTENSION.md for task-number patterns; use durable anchors (filenames, section headings) only |
| The `source_format` imprecision from the task description propagates into the decision doc | L | L | The doc explicitly states the accurate characterization (document-index field pdf/djvu/manual, not an FTS5 column) |
| Editing a generated CLAUDE.md instead of the merge source | M | L | Only EXTENSION.md (merge source) is edited; CLAUDE.md is treated as read-only/auto-generated |
| New context file not picked up because it is unregistered | L | L | Phase 1 registers the file in `index-entries.json`; Phase 2 validates JSON well-formedness |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Author and register the durable decision record [COMPLETED]

**Goal**: Create a durable, task-number-free decision record documenting markdown retention, its
rationale, the supporting evidence, and the format-layer notes; register it in the extension
context index so future readers discover it.

**Tasks**:
- [x] Create `agent-system/extensions/literature/context/project/literature/domain/format-decision.md`
      with these sections: *(completed)*
  - [x] Decision statement: markdown remains the sole convert/chunk/index format for the literature
        extension. *(completed)*
  - [x] Rationale (self-contained, no task numbers): (a) no mature PDF-to-Typst converter comparable
        to `pymupdf4llm`/PyMuPDF exists — "just as convenient" bar fails; (b) typst structural
        affordances (`=`/`==`, `#theorem[]`) give no segmentation advantage for a PDF-sourced corpus
        — "superior" bar fails; (c) re-encoding markdown to typst via pandoc's writer is pure
        syntactic churn with zero retrieval effect (FTS5 indexes extracted plain text only).
        *(completed)*
  - [x] Evidence via durable anchors: reference `literature-convert.sh` engine-tier header comment
        and `literature-audit.sh` audit-results block (pandoc PDF-input unavailability); reference
        `literature-schema.sql` (no chunk-format column); reference the archived conversion-pipeline
        report by filename. Cite by filename/section, never by task number. *(completed)*
  - [x] Format-agnostic index-layer note: `literature-build-index.sh` (chunk discovery +
        `source_path` reads) and `literature-search.sh`'s `do_read()` are already format-agnostic;
        the single format-hardcoded spot is `literature-ingest.sh`'s `ls "$TMP_MD_DIR"/*.md`
        output-discovery glob. State explicitly this is recorded as a fact, not a change to make.
        *(completed)*
  - [x] `source_format` clarification: document-level index field (`specs/literature/index.json`,
        values pdf/djvu/manual) recording the original source document's format — not a
        `chunks_data`/FTS5 column and not a chunk-markup-dialect signal. *(completed)*
  - [x] Re-evaluation trigger: reopen only if a maintained, deterministic (non-LLM), install-cheap
        PDF-to-Typst converter reaches `pymupdf4llm` correctness parity on multi-column/math-heavy
        academic PDFs. *(completed)*
- [x] Add an entry for the new file to
      `agent-system/extensions/literature/index-entries.json` following the existing entry shape
      (path relative to `context/`, domain `project`, subdomain `literature`, topics/keywords
      including `typst`, `format`, `markdown`, `decision`, `format-agnostic`; a one-line summary;
      `line_count`; and a `load_when` block mirroring the pattern used by sibling entries such as
      `agent-exploration.md`). *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/domain/format-decision.md` -
  new durable decision record (create).
- `agent-system/extensions/literature/index-entries.json` - add one registration entry for the new
  file.

**Verification**:
- The new `format-decision.md` exists and contains the decision statement, rationale, evidence
  anchors, format-layer note, `source_format` clarification, and re-evaluation trigger.
- `python3 -m json.tool` (or `jq .`) parses `index-entries.json` without error and the new entry is
  present with a `load_when` block.
- `grep -nE 'task[s]? *#?[0-9]|\(task [0-9]' format-decision.md` returns no matches
  (no task-number citations).

---

### Phase 2: Sync EXTENSION.md and verify no generated-file edits [COMPLETED]

**Goal**: Reference the decision from the extension's merge-source doc using a durable anchor, and
confirm no auto-generated CLAUDE.md was hand-edited and no code changed.

**Tasks**:
- [x] Add a short subsection to
      `agent-system/extensions/literature/EXTENSION.md` (e.g. "### Format Decision: Markdown
      Retained") stating markdown is the retained convert/chunk/index format and pointing to
      `context/project/literature/domain/format-decision.md` for the full rationale and
      re-evaluation trigger. Use the filename as the durable anchor; no task-number citation.
      *(completed)*
- [x] Confirm no generated CLAUDE.md file was edited (the literature section of any CLAUDE.md is
      produced by the extension loader from EXTENSION.md / merge sources; leave it untouched).
      *(completed: verified via `git status --short`, no CLAUDE.md changes)*
- [x] Confirm no script under `agent-system/extensions/literature/scripts/` was modified (the
      `*.md` glob correction remains a documented note only). *(completed: verified via
      `git status --short agent-system/extensions/literature/scripts/`, no output)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/literature/EXTENSION.md` - add the "Format Decision: Markdown Retained"
  subsection referencing the new decision record.

**Verification**:
- EXTENSION.md contains the new subsection and references `format-decision.md` by filename.
- `grep -nE 'task[s]? *#?[0-9]|\(task [0-9]' EXTENSION.md` shows the new content introduces no
  task-number citation.
- `git status --short` shows only the three intended files changed
  (`format-decision.md` added, `index-entries.json` and `EXTENSION.md` modified) — no CLAUDE.md and
  no `scripts/` changes.
- If present, run `bash .claude/scripts/check-extension-docs.sh` and confirm it does not report new
  failures attributable to these edits.

---

## Testing & Validation

- [x] `format-decision.md` reads as a self-contained decision record: a future reader with no task
      tracker can understand what was decided, why, and when to reopen it. *(verified)*
- [x] `index-entries.json` is valid JSON and the new entry mirrors sibling entries' shape.
      *(verified via `python3 -m json.tool`)*
- [x] No task-number citations in either deliverable file (grep clean). *(verified, both grep
      commands exit 1 with no matches)*
- [x] `git status --short` shows exactly the intended file set; no CLAUDE.md, no `scripts/` edits.
      *(verified)*
- [x] `check-extension-docs.sh` (if available) reports no new failures. *(verified: `literature
      PASS`)*

## Artifacts & Outputs

- `agent-system/extensions/literature/context/project/literature/domain/format-decision.md` (new)
- `agent-system/extensions/literature/index-entries.json` (modified: +1 registration entry)
- `agent-system/extensions/literature/EXTENSION.md` (modified: +1 subsection)
- `specs/868_typst_segmentation_evaluation/summaries/01_markdown-retention-decision-summary.md`
  (implementation summary, produced at /implement time)

## Rollback/Contingency

All changes are additive documentation across three files. To revert: `git checkout --` the two
modified files (`index-entries.json`, `EXTENSION.md`) and `git rm`/delete the new
`format-decision.md`. No code, schema, or generated-artifact changes are made, so there is no
runtime behavior to roll back.
