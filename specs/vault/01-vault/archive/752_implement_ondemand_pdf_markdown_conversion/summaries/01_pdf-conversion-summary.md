# Implementation Summary: Task #752

- **Task**: 752 - Implement On-Demand PDF-to-Markdown Conversion via Zotero
- **Status**: [COMPLETED]
- **Started**: 2026-06-19T00:00:00Z
- **Completed**: 2026-06-19T00:30:00Z
- **Effort**: ~30 minutes
- **Dependencies**: Task 751 (zotero-index-add.sh, index schema)
- **Artifacts**: `.claude/extensions/zotero/scripts/zotero-chunk.sh`, `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Replaced two stub scripts in the Zotero extension with full implementations completing the PDF-to-markdown conversion pipeline. Both scripts follow existing codebase conventions (exit codes 0/1/2, `set -euo pipefail`, stderr for diagnostics, stdout for output) and integrate with the existing SKILL.md wiring without requiring any changes to callers.

## What Changed

- `.claude/extensions/zotero/scripts/zotero-chunk.sh` — Replaced stub with full pipeline: index lookup, PDF-to-markdown conversion via `literature-convert.sh`, chunking via `literature-chunk.sh`, token counting from `chunks.json`, relative `chunk_dir` path storage in `specs/zotero-index.json`, and FTS5 index rebuild via `literature-build-index.sh --local`. Includes trap-based temp dir cleanup.
- `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` — Replaced stub with idempotent chunk upload loop: reads `chunk_dir` from index, resolves relative path against `PROJECT_ROOT`, iterates `chunk_*.md` files lexicographically, calls `zotero-write.sh attach-file` with `--idempotency-key chunk-{KEY}-{N}` per file. Supports `--dry-run` pass-through.

## Decisions

- Used `literature-convert.sh` (not `zot pdf`) for PDF conversion, since `zot` is not installed and `literature-convert.sh` produces structured markdown with heading markers that `literature-chunk.sh` requires.
- Read `pdf_path` directly from `specs/zotero-index.json` entry to avoid `zot` CLI dependency.
- Store `chunk_dir` as a relative path from `PROJECT_ROOT` (e.g., `specs/literature/blackburn2001/`) using bash parameter substitution to strip the `PROJECT_ROOT/` prefix.
- Glob `$TMP_DIR/*.md` (not hardcoded doc_id) to locate the markdown file produced by `literature-convert.sh`, since the output filename derives from the PDF basename which may differ from the citation key.
- Token counting uses `jq '[.[].token_count] | add // 0'` on `chunks.json` manifest (safe — no `!=` operator per Issue #1132).
- Chunk iteration uses `chunk_*.md` glob pattern (not `*.md`) to avoid accidentally picking up `chunks.json` or other non-chunk files.

## Impacts

- `/zotero --convert KEY` and `/zotero --attach KEY` commands are now fully functional.
- The `--chunk` flag in `zotero-index-add.sh` will trigger `zotero-chunk.sh` successfully instead of printing the "not yet implemented" notice.
- SKILL.md executable checks at lines 237 and 266 will now pass, enabling the convert and attach handlers to execute.

## Follow-ups

- The `--pages N-M` argument is parsed by `zotero-chunk.sh` but not yet passed to `literature-convert.sh` (reserved for future use as noted in the plan).
- `zotero-write.sh` requires `zot` to be installed for `attach-file` operations — `zotero-attach-chunks.sh` will exit 2 if `zot` is not installed (handled by `zotero-write.sh`'s own dependency check).

## References

- `specs/752_implement_ondemand_pdf_markdown_conversion/plans/01_pdf-conversion-plan.md`
- `specs/752_implement_ondemand_pdf_markdown_conversion/reports/01_pdf-conversion-research.md`
- `.claude/extensions/zotero/scripts/zotero-index-add.sh` (path resolution pattern reference)
- `.claude/scripts/literature-convert.sh` (conversion pipeline)
- `.claude/scripts/literature-chunk.sh` (chunking pipeline)
