# Implementation Summary: Task #910

**Completed**: 2026-07-26
**Duration**: ~3 hours

## Overview

`roadmap-integration.sh` found valid table-row completion matches and then silently failed to
apply them: the annotation loop unconditionally built checkbox syntax (`- [ ] {item}`), which
cannot exist in a checkbox-free table roadmap, so every table-row annotation attempt failed, the
script still exited 0, and its sole consumer (`/review`) surfaced only `annotations_made`,
making the failure invisible end to end. This plan's six phases (1) plumb a source-line
reference from parser through matcher to annotator so table-row matches can be located and
rewritten in place, (2) add an always-on machine-readable structure marker plus two conditional
loud banners and additive JSON fields so a no-op can never masquerade as success, and (3) extend
`/review`, the one consumer that reads the payload, so the new signal actually reaches the user.
All six phases are complete and verified.

## What Changed

- `agent-system/extensions/core/scripts/roadmap-integration.sh` (source store; the corresponding
  `.claude/`/`.opencode/` deploy copies are disposable and were intentionally left untouched):
  - Step 2.5 parser: each `status_tables[]` entry now also carries `line_index` (0-based),
    `raw_line` (unmodified source text), and `status_index` (the column the completion allowlist
    matched, or `1` as a fallback, or `null` when there is no column to point at).
  - Step 2.5.2 matcher: table-sourced `roadmap_matches[]` entries carry the same three fields
    through unchanged; checkbox-sourced match objects are untouched (still no `source` key at
    all), preserving `.source // ""` as the branch discriminator.
  - Step 2.5.3 annotator: branches on `.source`. The checkbox path is the pre-existing
    `OLD_LINE`/`NEW_LINE`/`awk`/`diff` logic, unmodified. The table path locates a row strictly
    by `(line_index, raw_line)` (never by component text, which can collide across rows),
    verifies the on-disk line still matches the captured `raw_line` before writing (skip reason
    `table_row_line_mismatch` on drift, never a blind write), rewrites only the matched status
    cell via a small `python3` re-parse of the same `^\|(.*)\|(\s*)$` / `split('|')` shape the
    parser itself uses (preserving column count and every other cell byte-for-byte), and applies
    with a line-index-targeted `awk` mirroring the checkbox apply. Dry-run no longer
    over-reports: both branches gate the `ANNOTATIONS_MADE` increment on the same existence
    check the apply path performs, and print `[dry-run] would skip: {reason}` otherwise. Every
    dry-run and applied-annotation stderr message is now source-tagged (`(checkbox)` /
    `(table row)`).
  - New always-on diagnostics: an unconditional
    `<!-- roadmap-structure phases=N checkboxes=M table_rows=T parseable=true|false -->` marker
    on every invocation (mirroring the `literature-briefing.sh` convention), a loud
    `[UNPARSEABLE ROADMAP - 0 phases, 0 checkboxes, 0 table rows]` banner when no recognized
    structure exists, and a loud `[ROADMAP ANNOTATION NO-OP - {K} high-confidence match(es), 0
    applied]` banner when annotate mode ran, found high-confidence matches, and applied none of
    them. Neither banner fires on a working table-only roadmap (the two-signal split is a
    deliberate refinement of the task's literal proposed condition -- see the plan's Overview).
  - Output JSON gains, additively only: top-level `roadmap_structure`
    (`{phases, checkboxes, table_rows, parseable}`), top-level `warnings` (stable string codes
    `unparseable_roadmap` / `annotation_noop`, `[]` when neither applies), and
    `annotation_summary.high_confidence_matches` / `annotation_summary.silent_noop`. Every
    pre-existing field path (`roadmap_state`, `roadmap_matches`,
    `annotation_summary.annotations_made`/`.items_skipped`/`.skipped_reasons`) is unchanged in
    name, type, and nesting -- verified by `jq` type checks across every fixture scenario.
  - Header comment block (`Output schema:`) rewritten to document the new fields, the two
    warning codes, and the `status_tables[]`/table-match `line_index`/`raw_line`/`status_index`
    keys.

- `agent-system/extensions/core/commands/review.md` (source store; **declared `file_scope`
  expansion**, see below):
  - Section 2.5 extraction block now also captures `roadmap_structure`, `warnings` (as
    `roadmap_warnings`), `annotation_summary.items_skipped`, `.skipped_reasons`,
    `.high_confidence_matches`, and `.silent_noop`.
  - Both empty-state fallback branches (script missing / script failed or empty output) now
    default every one of those variables too, so the downstream template and commit-message step
    never reference an unbound variable.
  - New explicit warning emission: when `roadmap_warnings` is non-empty, each code is echoed to
    stderr with a human-readable expansion during the review run, so the signal is visible in the
    transcript, not only inside the eventual report file.
  - The `## Roadmap Progress` report template gains a **Roadmap Signal** subsection (rendered
    only when `warnings` is non-empty or `roadmap_structure.parseable` is `false`), and its
    accompanying note now directs population of that subsection from `roadmap_structure` /
    `roadmap_warnings`.
  - The Section 7 commit-message template's `Roadmap: {annotations_made} items annotated` line
    is disambiguated to `Roadmap: {annotations_made} items annotated, {items_skipped}
    skipped{warning codes, if any}`, with an explanatory note distinguishing "nothing to do" /
    "N matches all failed to apply" / "structure unrecognized" -- previously all three collapsed
    to an identical-looking `0 items annotated`.

- `specs/910_fix_roadmap_annotation_silent_noop/fixtures/` -- task-scoped verification fixtures
  (created; not a deliverable, nothing added to the repository's permanent test surface):
  `checkbox-roadmap.md` (copy of the real `specs/ROADMAP.md`), `table-roadmap.md` (two tables,
  4- and 5-column, including a deliberate `Widget Driver` component-text collision across both
  tables), `unstructured-roadmap.md`, `fixture-state.json`, and `matrix-output/` (9 saved
  stdout/stderr/file-diff runs: each fixture x {parse-only, `--dry-run`, `--annotate`}, plus the
  pre-change baseline run and an idempotence re-run).

## Decisions

- **Two-signal split instead of the task's literal single condition**: the task (and research)
  proposed firing an "unparseable" signal on `phases == 0 && checkboxes == 0`. After Phases 1-3
  land, a *working, fully-annotatable* table-only roadmap has exactly that shape, so the literal
  condition would false-positive on precisely the case this task fixes. `unparseable_roadmap`
  additionally requires `table_rows == 0`; `annotation_noop` is a separate signal for "structure
  recognized, matches found, nothing applied." Verified: the working table fixture emits neither
  warning.
- **Location by `(line_index, raw_line)`, never by component text**: two rows can share
  identical component text (exercised directly in `table-roadmap.md`'s two "Widget Driver" rows
  across different tables); text-based lookup would either collide or require disambiguation
  logic. The captured line reference makes lookup exact and collision-proof, verified by the
  fixture leaving the non-matching "Widget Driver" row untouched.
- **Dry-run gating via the same existence check as apply**: rather than a parallel "would it
  work" heuristic, both branches literally reuse the boolean the apply path itself computes
  (`LINE_EXISTS` for checkboxes; the `(line_index, raw_line)` agreement check for table rows),
  so dry-run and apply can never diverge on what counts as annotatable.
- **`review.md`'s `file_scope` expansion (Phase 6) was pre-authorized by the orchestrator** for
  this dispatch, on the grounds that a diagnostic no consumer reads reproduces the identical
  silence this task exists to close (see the plan's "Scope Decision" section for the full
  rationale). This is recorded here per that authorization's explicit requirement, and in
  `modified_files` below.

## Plan Deviations

- **Phase 3 idempotence-verification wording** (altered): re-running `--annotate` on an
  already-annotated table row yields `annotations_made: 0` with an *empty* `skipped_reasons`
  array, not `already_annotated` as the phase's verification bullet literally describes. Cause:
  the Step 2.5.2 matcher already filters rows whose status text contains `*(Completed:` before
  they reach the annotate loop at all -- identical to how the pre-existing, unmodified checkbox
  path's own matcher-level filter (`item.get("completed")`) makes its own `already_annotated`
  annotator-level check a dead path in the common case. Net effect (0 annotations, no duplicate
  marker, idempotent) is unchanged; only which layer performs the filtering differs, and it
  differs identically to how the unmodified checkbox path already behaves. See
  `progress/phase-3-progress.json` for the full note.
- **Phase 6 pre-existing task-number citation** (out of scope, not fixed): `review.md` already
  contained one task-number citation before this phase touched the file (in the unrelated
  "Add task to state.json" section, from prior work). It falls outside every section this
  phase's declared expansion covers (Section 2.5, the `## Roadmap Progress` template, Section 7).
  Fixing it would be scope creep beyond the narrowly authorized roadmap-signal expansion, so it
  was left in place and is called out here rather than silently fixed or silently ignored. All
  content this phase *added* is citation-free, verified by grep scoped to exactly the three
  edited regions.
- No other deviations. All six phases followed the plan as written.

## Verification

- **Build/lint**: `bash -n agent-system/extensions/core/scripts/roadmap-integration.sh` passes.
  Both bash blocks added to `review.md` (Section 2.5 and Section 7) independently pass `bash -n`
  when extracted.
- **Tests**: No permanent test harness exists for this script (by design, per the plan's
  Non-Goals); verification used the task-scoped fixture matrix below.
- **Files verified**: Yes -- every phase's own verification criteria were checked against real
  script runs (not read-only inspection) before being marked complete.

### Fixture Matrix (Phase 5)

9 runs, each fixture x {parse-only, `--dry-run`, `--annotate`}, all exit 0:

| Fixture | Mode | Result |
|---|---|---|
| `checkbox-roadmap.md` (copy of real `specs/ROADMAP.md`) | annotate | Byte-identical file and JSON payload (pre-existing fields only) vs. the pre-task-commit baseline script |
| `table-roadmap.md` | parse-only | `roadmap_structure: {phases:0, checkboxes:0, table_rows:4, parseable:true}`, `warnings: []` (no false-positive banner on a working table roadmap) |
| `table-roadmap.md` | `--dry-run` | Proposes a table-shaped replacement (not `- [ ] {component}`); file left byte-identical to input |
| `table-roadmap.md` | `--annotate` | Both eligible rows (4-column and 5-column tables) annotated in place; column count unchanged; only the matched status cell changed; the still-in-progress row and the second, non-matching same-named "Widget Driver" row both left untouched |
| `table-roadmap.md` (re-run on already-annotated output) | `--annotate` | `annotations_made: 0`, file byte-identical to the prior annotated output (idempotent, no duplicate marker) |
| `unstructured-roadmap.md` | parse-only / `--dry-run` / `--annotate` | `[UNPARSEABLE ROADMAP ...]` banner, `roadmap_structure.parseable: false`, `warnings: ["unparseable_roadmap"]` |
| engineered no-op fixture (real unannotated line present, but the document-wide `grep -F` safety-check style false-positive was replicated) | `--annotate` | `[ROADMAP ANNOTATION NO-OP - 1 high-confidence match(es), 0 applied]`, `warnings: ["annotation_noop"]`, `annotation_summary.silent_noop: true` |

All pre-existing JSON field paths (`roadmap_state.phases`/`.status_tables`, `roadmap_matches`,
`annotation_summary.annotations_made`/`.items_skipped`/`.skipped_reasons`) confirmed present with
unchanged `type` across every scenario above via `jq`. `set -euo pipefail` was not tripped by an
empty `status_tables` array or an empty `warnings`/`SKIPPED_REASONS` array in any scenario.

### review.md End-to-End Drive (Phase 6)

Ran the exact extraction/fallback/warning-emission logic added to Section 2.5 against both the
engineered no-op fixture and the unstructured fixture: both the script-level stderr banner and
`review.md`'s own human-readable warning line appeared in the transcript, and every newly
extracted variable (`roadmap_structure`, `roadmap_warnings`, `items_skipped`,
`high_confidence_matches`, `silent_noop`) matched the Phase 4 payload field-for-field.

## Notes

- `git status --porcelain specs/ROADMAP.md` is clean throughout -- the real roadmap file was
  never touched, per the plan's Non-Goals.
- Confirmed via `git log --name-only` across all six phase commits that only
  `agent-system/extensions/core/scripts/roadmap-integration.sh` and
  `agent-system/extensions/core/commands/review.md` were modified; no file under `.claude/` or
  `.opencode/` was touched at any point.
- Follow-ups intentionally not implemented here (see the plan's Follow-Ups section): consolidating
  or connecting `/todo`'s independent, prose-level roadmap reimplementation
  (`skill-todo/SKILL.md`, Stages 5 and 11) to this script, and broadening the phase-header regex
  now that `roadmap_structure` makes its limitation visible for the first time.
