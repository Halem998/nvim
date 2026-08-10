# Implementation Plan: Task #752

- **Task**: 752 - Implement On-Demand PDF-to-Markdown Conversion via Zotero
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 751 (zotero-index-add.sh, index schema -- already implemented)
- **Research Inputs**: specs/752_implement_ondemand_pdf_markdown_conversion/reports/01_pdf-conversion-research.md
- **Artifacts**: plans/01_pdf-conversion-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement two shell scripts in `.claude/extensions/zotero/scripts/` that complete the PDF-to-markdown conversion pipeline: `zotero-chunk.sh` (converts a Zotero item's PDF to markdown, chunks it, stores chunks locally, and updates the per-repo index) and `zotero-attach-chunks.sh` (uploads existing chunks as Zotero child attachments). Both scripts are currently stubs that exit 2. The callers in SKILL.md and zotero.md are already wired -- no command or skill changes are needed.

### Research Integration

The research report confirms:
- `literature-convert.sh` must be used for PDF-to-markdown conversion (not `zot pdf KEY`, which produces plain text without heading structure that `literature-chunk.sh` cannot process)
- `pdf_path` should be read from `specs/zotero-index.json` directly, avoiding the `zot` CLI dependency for the chunking step (since `zot` is not currently installed)
- `literature-chunk.sh` requires markdown input and produces `chunk_NNNN.md` files plus a `chunks.json` manifest; token counts are derived from `chunks.json`
- `zotero-write.sh attach-file KEY FILEPATH --idempotency-key VALUE` is fully implemented and ready to use
- `zotero-index-add.sh` preserves chunk fields on update, so `zotero-chunk.sh` must update chunk metadata directly in `specs/zotero-index.json` via `jq`
- `pdftotext` is available at `/home/benjamin/.nix-profile/bin/pdftotext` as a fallback converter

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Implement `zotero-chunk.sh` with a complete pipeline: index lookup, PDF-to-markdown conversion, chunking, local storage, index update, and FTS5 rebuild
- Implement `zotero-attach-chunks.sh` with idempotent chunk upload via `zotero-write.sh`
- Both scripts must follow existing codebase conventions (exit codes 0/1/2, `set -euo pipefail`, stderr for diagnostics, stdout for output)
- Store chunks in `specs/literature/{citation_key}/` with relative path in the index

**Non-Goals**:
- Implementing `--convert-all` batch mode (not in architecture spec or existing skill wiring)
- Modifying SKILL.md or zotero.md (callers are already wired)
- Installing the `zot` CLI (scripts should work without it by reading from the index)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `literature-convert.sh` output filename depends on input PDF basename, not citation_key | M | H | Copy or symlink PDF to a temp file named after citation_key before calling convert, OR glob for the `.md` file in the temp dir |
| `zot attach` may not support `--idempotency-key` flag | M | M | Test with `--dry-run` first; if unsupported, omit the flag and document |
| jq `!=` operator escaping (Issue #1132) | L | M | Use `select(.zotero_key == $k | not)` pattern throughout |
| Large PDF produces too many chunks for Zotero attachment upload | L | L | Report progress per chunk; allow partial success with summary |
| `literature-convert.sh` fails (all converters unavailable) | H | L | `pdftotext` is confirmed available; exit cleanly with error message |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement zotero-chunk.sh [COMPLETED]

**Goal**: Replace the stub with a complete PDF-to-markdown chunking pipeline that reads from the per-repo index, converts PDF to markdown, chunks the result, stores chunks locally, and updates the index.

**Tasks**:
- [ ] Implement argument parsing: `<zotero_key>` (required), `--output-dir DIR` (optional), `--pages N-M` (optional, reserved for future use)
- [ ] Implement path resolution: `SCRIPT_DIR`, `PROJECT_ROOT` (4 levels up from scripts dir), `ZOTERO_INDEX`, `LITERATURE_SCRIPTS_DIR` (for literature-convert.sh and literature-chunk.sh)
- [ ] Implement prerequisite checks: verify `jq` available, verify `specs/zotero-index.json` exists
- [ ] Implement index lookup: read entry for given zotero_key from index; extract `citation_key`, `pdf_path`, `has_pdf`; exit 2 if key not found or `has_pdf=false`
- [ ] Implement PDF-to-markdown conversion: create temp dir, call `literature-convert.sh "$pdf_path" "$tmp_dir"`, locate the produced `.md` file by globbing `$tmp_dir/*.md`
- [ ] Implement chunking: set `chunk_dir` to `${output_dir:-"$PROJECT_ROOT/specs/literature/$citation_key"}`, call `literature-chunk.sh "$tmp_md" "$chunk_dir" --doc-id "$citation_key"`, capture chunk count from stdout
- [ ] Implement token counting: read `chunks.json` manifest from chunk_dir, sum `token_count` values via `jq '[.[].token_count] | add // 0'`
- [ ] Implement index update: use `jq` to update the matching entry in `specs/zotero-index.json` with `has_chunks=true`, `chunk_dir` (relative path), `chunk_count`, `token_count`; also update `last_updated` timestamp
- [ ] Implement FTS5 rebuild: call `literature-build-index.sh --local`
- [ ] Implement cleanup: remove temp dir in a trap; print progress messages to stdout

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-chunk.sh` - Replace stub with full implementation

**Verification**:
- `bash -n .claude/extensions/zotero/scripts/zotero-chunk.sh` passes (syntax check)
- Script prints usage info when called with no arguments
- Script exits 2 when called with a key not in the index
- Script exits 2 when `specs/zotero-index.json` does not exist
- Script handles the full pipeline when given a valid key with `has_pdf=true` and a readable `pdf_path`

---

### Phase 2: Implement zotero-attach-chunks.sh [COMPLETED]

**Goal**: Replace the stub with a script that iterates local chunks and uploads each as a Zotero child attachment via `zotero-write.sh attach-file`.

**Tasks**:
- [ ] Implement argument parsing: `<zotero_key>` (required), `--dry-run` (optional)
- [ ] Implement path resolution: `SCRIPT_DIR`, `PROJECT_ROOT`, `ZOTERO_INDEX`, `ZOTERO_WRITE_SH` (path to zotero-write.sh)
- [ ] Implement prerequisite checks: verify `jq` available, verify `ZOTERO_API_KEY` is set (exit 2 if not), verify `specs/zotero-index.json` exists
- [ ] Implement index lookup: read entry for given zotero_key; check `has_chunks=true` and `chunk_dir` is non-null (exit 2 if not)
- [ ] Implement chunk_dir resolution: resolve relative `chunk_dir` from index against `PROJECT_ROOT`; verify directory exists
- [ ] Implement chunk iteration: collect `*.md` files from chunk_dir (excluding `chunks.json`), sorted lexicographically; for each file with counter N, call `zotero-write.sh attach-file "$KEY" "$chunk_file" --idempotency-key "chunk-$KEY-$N"` (pass `--dry-run` if set)
- [ ] Implement result tracking: count successes and failures; print per-chunk status to stdout; print summary at end
- [ ] Implement exit code logic: exit 0 if all uploads succeed (or dry-run), exit 1 if any upload failed

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` - Replace stub with full implementation

**Verification**:
- `bash -n .claude/extensions/zotero/scripts/zotero-attach-chunks.sh` passes (syntax check)
- Script prints usage info when called with no arguments
- Script exits 2 when `ZOTERO_API_KEY` is not set
- Script exits 2 when entry has `has_chunks=false`
- Script correctly passes `--dry-run` through to `zotero-write.sh`

---

### Phase 3: Verification and Integration Testing [COMPLETED]

**Goal**: Verify both scripts pass syntax checks, handle edge cases, and integrate correctly with the existing skill and command wiring.

**Tasks**:
- [ ] Run `bash -n` syntax check on both scripts
- [ ] Verify `shellcheck` passes on both scripts (if available), or manually review for common bash pitfalls
- [ ] Verify that the SKILL.md `handle_convert()` and `handle_attach()` functions call the scripts with correct arguments
- [ ] Verify that `zotero.md` command correctly parses `--convert KEY` and `--attach KEY` modes
- [ ] Review jq commands in zotero-chunk.sh for Issue #1132 safety (no bare `!=` operator)
- [ ] Verify chunk_dir is stored as a relative path (e.g., `specs/literature/blackburn2001/`) in the index, not an absolute path
- [ ] Verify the trap-based temp dir cleanup in zotero-chunk.sh functions correctly on both success and error paths

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Files to modify**:
- No new files; review and fix issues found in Phase 1 and Phase 2 outputs

**Verification**:
- Both scripts pass `bash -n` syntax validation
- No jq commands use the `!=` operator
- All exit codes match the documented specification in the script headers
- Relative chunk_dir path convention is consistent between zotero-chunk.sh and zotero-attach-chunks.sh

## Testing & Validation

- [ ] `bash -n .claude/extensions/zotero/scripts/zotero-chunk.sh` exits 0
- [ ] `bash -n .claude/extensions/zotero/scripts/zotero-attach-chunks.sh` exits 0
- [ ] `zotero-chunk.sh` with no args prints usage and exits non-zero
- [ ] `zotero-chunk.sh NONEXISTENT_KEY` exits 2 with "not found in index" message
- [ ] `zotero-attach-chunks.sh` with no args prints usage and exits non-zero
- [ ] `zotero-attach-chunks.sh KEY` without `ZOTERO_API_KEY` set exits 2
- [ ] No `!=` operators in any jq command within either script
- [ ] Chunk directory paths stored as relative paths from project root

## Artifacts & Outputs

- `.claude/extensions/zotero/scripts/zotero-chunk.sh` - Full implementation replacing stub
- `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` - Full implementation replacing stub
- `specs/752_implement_ondemand_pdf_markdown_conversion/plans/01_pdf-conversion-plan.md` - This plan
- `specs/752_implement_ondemand_pdf_markdown_conversion/summaries/01_pdf-conversion-summary.md` - Execution summary (created during implementation)

## Rollback/Contingency

Both scripts are currently stubs (exit 2 with "not yet implemented" message). If implementation introduces regressions, restore the stub versions via `git checkout` on the two script files. No other files are modified by this task, so rollback is isolated to these two scripts.
