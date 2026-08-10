# Implementation Summary: Task #868

**Completed**: 2026-07-15
**Duration**: ~20 minutes

## Overview

Recorded the durable NO-GO decision on typst-based literature segmentation: markdown remains the
sole convert/chunk/index format. The implementation is documentation-only, as required by the
research outcome — no code, scripts, or index schema were changed. The decision record is now
discoverable via the literature extension's context index and referenced from the extension's
merge-source doc.

## What Changed

- `agent-system/extensions/literature/context/project/literature/domain/format-decision.md` —
  Created. A self-contained, task-number-free decision record covering: the decision statement;
  three-part rationale (no mature PDF-to-Typst converter, no segmentation advantage for
  PDF-sourced content, FTS5 indexes plain text only); durable-anchor evidence citations
  (`literature-convert.sh` engine-tier comment, `literature-audit.sh` audit-results block,
  `literature-schema.sql`'s `chunks_data` columns, the archived conversion-pipeline
  report/summary filenames); the format-agnostic index-layer note identifying
  `literature-ingest.sh`'s `ls "$TMP_MD_DIR"/*.md` glob as the one format-hardcoded spot (recorded
  as fact, not a change); the `source_format` clarification (document-level field in
  `specs/literature/index.json`, values `pdf`/`djvu`/`manual` — not an FTS5/chunk column); and a
  re-evaluation trigger (a maintained, deterministic, install-cheap PDF-to-Typst converter
  reaching pymupdf4llm-level correctness parity).
- `agent-system/extensions/literature/index-entries.json` — Added one registration entry for the
  new file (path, domain `project`, subdomain `literature`, topics/keywords including `typst`,
  `format`, `markdown`, `decision`, `format-agnostic`, a one-line summary, `line_count: 95`, and a
  `load_when` block mirroring the `agent-exploration.md` sibling entry's agents/skills/commands).
- `agent-system/extensions/literature/EXTENSION.md` — Added a "Format Decision: Markdown Retained"
  subsection (between "Centralized Repository" and "Zotero Integration (Unified)") stating the
  decision and pointing to `context/project/literature/domain/format-decision.md` by filename for
  the full rationale.
- `specs/868_typst_segmentation_evaluation/plans/01_markdown-retention-decision.md` — Checked off
  all Phase 1 and Phase 2 tasks and the Testing & Validation checklist; both phase headings marked
  `[COMPLETED]`.

## Decisions

- Placed the new "Format Decision" subsection in EXTENSION.md adjacent to the "Centralized
  Repository" and "Zotero Integration" sections (rather than at the top or bottom of the file) so
  it sits near the pipeline-description content it qualifies.
- Cited the archived conversion-pipeline research/summary filenames only (`01_conversion-pipeline-fix.md`,
  `01_conversion-pipeline-fix-summary.md`) as durable anchors for prior engine-selection evidence,
  without any task-number or task-path context, per the no-task-references rule.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation-only change).
- Tests: N/A.
- `python3 -m json.tool agent-system/extensions/literature/index-entries.json` — parses without
  error; new entry present with a `load_when` block.
- `grep -nE 'task[s]? *#?[0-9]|\(task [0-9]'` on both `format-decision.md` and `EXTENSION.md` —
  zero matches (exit code 1, no task-number citations).
- `bash .claude/scripts/check-extension-docs.sh` — `literature PASS` (overall `PASS: all
  extensions OK`).
- `git status --short agent-system/extensions/literature/scripts/` — no output; confirms no
  script changes.
- `git status --short` — no CLAUDE.md entries; confirms no generated-file hand-edit.
- Files verified: Yes (all three deliverable files exist with expected content).

## Notes

Two files were staged and committed as part of the Phase 1 checkpoint that pre-existed but were
previously uncommitted from earlier `/research` and `/plan` runs for this task
(`reports/01_typst-segmentation-decision.md` and `plans/01_markdown-retention-decision.md`) — this
is expected first-commit behavior for this task's artifact directory, not scope creep. Unrelated
pre-existing working-tree changes present at session start (`lua/neotex/plugins/tools/himalaya/utils/cli.lua`,
`specs/TODO.md`, `specs/state.json`, a stale `868`-adjacent task lock-file delta, and an untracked
`specs/.orchestrator-multi-state.json`) were deliberately left unstaged/uncommitted as out of
scope for this implementation.
