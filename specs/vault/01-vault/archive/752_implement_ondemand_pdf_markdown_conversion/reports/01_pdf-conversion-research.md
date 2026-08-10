# Research Report: Task #752

**Task**: 752 - Implement On-Demand PDF-to-Markdown Conversion via Zotero
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:10:00Z
**Effort**: Low (well-specified in arch doc; prior tasks provide all dependencies)
**Dependencies**: Task 751 (zotero-index-add.sh, index schema — already implemented)
**Sources/Inputs**: Architecture doc (748 summary), zotero-chunk.sh stub, zotero-attach-chunks.sh stub, zotero-index-add.sh (implemented), zotero-write.sh (implemented), literature-chunk.sh (implemented), literature-convert.sh (implemented), SKILL.md, zotero.md command
**Artifacts**: - `specs/752_implement_ondemand_pdf_markdown_conversion/reports/01_pdf-conversion-research.md`
**Standards**: report-format.md

---

## Executive Summary

- Both target scripts (`zotero-chunk.sh`, `zotero-attach-chunks.sh`) are stubs that exit 2 with "not yet implemented (task 752)". Full implementation is required.
- The skill (`SKILL.md`) and command (`zotero.md`) already wire `--convert` and `--attach` modes to these stubs — the callers are ready.
- `literature-chunk.sh` (the reusable chunking engine) is fully implemented and accepts `<input.md> <output_dir> --doc-id <id>`. It requires markdown input, not raw PDF text.
- `literature-convert.sh` converts PDF → markdown (using marker, pymupdf, or pdftotext fallback). This is the right tool for the PDF extraction step; `zot pdf KEY` would produce plain text without headings.
- `pdftotext` is available at `/home/benjamin/.nix-profile/bin/pdftotext`. `pandoc` is also available at `/run/current-system/sw/bin/pandoc`. The `zot` CLI is NOT currently installed.
- `zotero-index-add.sh` already preserves chunk fields (`has_chunks`, `chunk_dir`, `chunk_count`, `token_count`) from existing index entries on update. The update logic for chunk fields is not yet in `zotero-chunk.sh` itself.
- The architecture doc specifies step 7 calls `literature-build-index.sh --local`. This script is implemented and rebuilds the SQLite FTS5 database from chunk manifests.
- `zotero-write.sh` is fully implemented and handles `attach-file KEY FILEPATH --idempotency-key VALUE`. `zotero-attach-chunks.sh` just needs to iterate chunks and call it.

---

## Context & Scope

Task 752 implements two scripts in `.claude/extensions/zotero/scripts/`:

1. **`zotero-chunk.sh`** — 7-step pipeline: fetch item metadata → extract PDF text → convert to markdown → chunk via literature-chunk.sh → save to `specs/literature/{citation_key}/` → count chunks and tokens → update index.
2. **`zotero-attach-chunks.sh`** — Upload existing local chunks as Zotero child attachments via `zotero-write.sh attach-file`.

Both are needed to complete the `--convert` and `--attach` sub-modes of `/zotero`.

---

## Findings

### Codebase Patterns

#### Existing Stubs
Both scripts contain only:
```bash
set -euo pipefail
echo "<script-name>: not yet implemented (task 752)" >&2
exit 2
```
All argument documentation is in the header comments. These must be replaced with full implementations.

#### literature-chunk.sh Interface
The existing chunking engine (`/home/benjamin/.config/nvim/.claude/scripts/literature-chunk.sh`) takes:
```
literature-chunk.sh <input.md> <output_dir> --doc-id <id>
```
- Input MUST be a markdown file (not raw PDF text)
- Outputs: `chunk_NNNN.md` files + `chunks.json` manifest
- `chunks.json` contains metadata per chunk including `token_count`
- Token count is estimated as `chars/4`
- Returns chunk count (integer) on stdout

**Key implication**: `zotero-chunk.sh` cannot pipe `zot pdf KEY` directly to `literature-chunk.sh`. It must first convert PDF to markdown. The right tool for this is `literature-convert.sh`.

#### literature-convert.sh Interface
Located at `/home/benjamin/.config/nvim/.claude/scripts/literature-convert.sh`. Takes:
```
literature-convert.sh <input.pdf|input.djvu> <output_dir>
```
- Produces `{output_dir}/{doc_id}.md` (markdown with heading markers from TOC)
- Tries tools in order: marker → pymupdf → pdftotext fallback
- `pdftotext` IS available (`/home/benjamin/.nix-profile/bin/pdftotext`)
- Exit 0 on success, 2 if all converters fail

**Revised pipeline for zotero-chunk.sh**:
1. Fetch item metadata via `zotero-read.sh item KEY` → extract `citation_key`, `title`, `authors`, `year`, `pdf_path`
2. Verify item is in `specs/zotero-index.json` AND has `has_pdf=true`
3. Create temp dir; run `literature-convert.sh <pdf_path> <tmp_dir>` → produces `{tmp_dir}/{doc_id}.md`
4. Run `literature-chunk.sh <tmp_dir>/{doc_id}.md <chunk_dir> --doc-id <citation_key>`
5. Count chunks from `chunks.json`; sum token counts from manifest
6. Update `specs/zotero-index.json` entry: `has_chunks=true`, `chunk_dir`, `chunk_count`, `token_count`
7. Run `literature-build-index.sh --local`
8. Clean up temp dir

Note: The architecture doc says step 2 uses `zotero-read.sh pdf KEY` to produce "full text to temp file" before calling `literature-chunk.sh`. However, `literature-chunk.sh` requires markdown input. The correct approach is to use `literature-convert.sh` for the PDF→markdown step (it already handles pdftotext internally and preserves heading structure better than raw text).

Alternatively: if `zot pdf KEY` is unavailable (zot not installed), `zotero-chunk.sh` should read `pdf_path` from the index and call `literature-convert.sh` directly on that path. This works without `zot` being installed.

#### zotero-index-add.sh Chunk Field Handling
The implemented `zotero-index-add.sh` (lines 230-254) preserves chunk fields when updating an existing entry:
```bash
existing_has_chunks="$(echo "$existing_entry" | jq -r '.has_chunks // false')"
existing_chunk_dir="$(echo "$existing_entry" | jq -c '.chunk_dir')"
existing_chunk_count="$(echo "$existing_entry" | jq -r '.chunk_count // 0')"
existing_token_count="$(echo "$existing_entry" | jq -r '.token_count // 0')"
```
So `zotero-chunk.sh` must update these fields directly in `specs/zotero-index.json` using `jq`, not rely on `zotero-index-add.sh` (which would re-fetch all metadata from Zotero).

#### zotero-write.sh attach-file
Fully implemented. The relevant signature:
```bash
zotero-write.sh attach-file KEY FILEPATH [--dry-run] [--idempotency-key VALUE]
```
Calls `zot attach KEY --file FILEPATH [--dry-run] [--idempotency-key VALUE]`.

Note: `ZOTERO_API_KEY` must be set. Exits 2 if not set. `zotero-attach-chunks.sh` inherits this behavior.

#### Skill/Command Wiring (Already Done)
- `SKILL.md` `handle_convert()` calls `bash "$zotero_chunk_sh" "$key"` — wired.
- `SKILL.md` `handle_attach()` calls `bash "$zotero_attach_sh" "$key"` — wired.
- `zotero.md` command parses `--convert KEY` → `mode=convert` and `--attach KEY` → `mode=attach` — wired.
- Both modes check for script existence with `[ ! -x "$script" ]` using the "not yet implemented" error path — this will pass once the scripts are real.

There is no `--convert-all` batch mode mentioned in the task description currently wired in the skill. The architecture doc mentions only per-key `--convert KEY`. The task description mentions supporting `--convert-all` as a batch mode — this is NOT in the architecture spec or existing skill. Treat as a bonus/extension feature, not blocking.

#### zot CLI Availability
`zot` is NOT installed (`zot not found`). The `zotero-chunk.sh` pipeline should NOT depend on `zot` for PDF extraction if `pdf_path` is already known from the index. The index entry stores `pdf_path` (absolute path). `literature-convert.sh` can be called directly on `pdf_path` without needing `zot`.

However, per the architecture spec, `zotero-chunk.sh` should still check `zot` is installed early (exit 2 if not). This is because `zotero-read.sh item KEY` is used to confirm the item exists and get fresh metadata. An alternative: read metadata from the index directly (it's already there), which avoids the `zot` dependency entirely for the chunking step.

**Recommendation**: Since `zot` is not installed, and the index already stores `pdf_path`, design `zotero-chunk.sh` to:
1. Read metadata (citation_key, pdf_path) from `specs/zotero-index.json` directly (primary path)
2. Optionally call `zotero-read.sh item KEY` if index entry lacks pdf_path (fallback)
3. Only require `zot` if pdf_path is not in the index

This makes the chunking pipeline work without `zot` installed, which matches the current system state.

#### Path Calculation in Scripts
`zotero-index-add.sh` uses:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
```
This is because scripts in `.claude/extensions/zotero/scripts/` are 4 levels deep from project root. The same pattern applies to `zotero-chunk.sh` and `zotero-attach-chunks.sh`.

However, the SKILL.md runs scripts with paths like:
```bash
SCRIPT_DIR=".claude/extensions/zotero/scripts"
```
(relative paths from project root). Scripts themselves must use `BASH_SOURCE[0]` for reliable path resolution.

---

### External Resources

No external research needed — all required components exist in the codebase.

---

### Recommendations

#### zotero-chunk.sh Implementation Plan

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Parse args: KEY, --output-dir DIR, --pages N-M
# 2. Resolve paths (SCRIPT_DIR, PROJECT_ROOT, ZOTERO_INDEX, SCRIPTS_DIR)
# 3. Check jq available
# 4. Verify KEY is in specs/zotero-index.json
# 5. Read entry: citation_key, pdf_path, has_pdf from index
# 6. Exit 2 if has_pdf=false or pdf_path null
# 7. Set chunk_dir: ${output_dir:-"$PROJECT_ROOT/specs/literature/$citation_key"}
# 8. Create chunk_dir
# 9. Create tmp_dir for PDF conversion
# 10. Call literature-convert.sh "$pdf_path" "$tmp_dir"
#     -> finds the produced .md file in tmp_dir
# 11. Call literature-chunk.sh "$tmp_md" "$chunk_dir" --doc-id "$citation_key"
#     -> chunk_count from stdout
# 12. Sum token_count from chunks.json manifest
# 13. Update specs/zotero-index.json entry: has_chunks=true, chunk_dir (relative), chunk_count, token_count
# 14. Call literature-build-index.sh --local
# 15. Clean tmp_dir
# 16. Report progress to stdout
```

Key implementation details:
- `chunk_dir` should be stored as RELATIVE path in the index (e.g., `specs/literature/blackburn2001/`) — matches the schema example
- The `literature-convert.sh` script writes to `{tmp_dir}/{doc_id}.md` where `doc_id` is derived from the input filename. We need to pass the pdf_path with a basename matching `citation_key` OR find the output file by glob.
- The script must compute total token_count by reading `chunks.json`: `jq '[.[].token_count] | add // 0' chunks.json`

#### zotero-attach-chunks.sh Implementation Plan

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Parse args: KEY, --dry-run
# 2. Resolve paths (SCRIPT_DIR, PROJECT_ROOT, ZOTERO_INDEX)
# 3. Check jq available; check ZOTERO_API_KEY set (exit 2 if not)
# 4. Read entry from specs/zotero-index.json for KEY
# 5. Check has_chunks=true (exit 2 if not)
# 6. Get chunk_dir (resolve relative path from PROJECT_ROOT)
# 7. Check chunk_dir exists
# 8. Collect .md files sorted lexicographically (exclude chunks.json)
# 9. For each chunk file (with N counter):
#    call zotero-write.sh attach-file KEY "$chunk_file" --idempotency-key "chunk-$KEY-$N"
#    [--dry-run if passed]
# 10. Count successes/failures; report summary
```

#### --convert-all Batch Mode (Optional Extension)

If implementing `--convert-all` as specified in the task description:
- Add `convert_all` mode to SKILL.md dispatch
- Iterate `specs/zotero-index.json` entries where `has_pdf=true` AND `has_chunks=false`
- Call `zotero-chunk.sh KEY` for each
- Report per-item results

This requires adding `--convert-all` parsing to `zotero.md` and `convert_all` mode to SKILL.md.

---

## Decisions

- Use `literature-convert.sh` (not `zot pdf KEY`) for PDF→markdown conversion. This avoids `zot` dependency for the chunking step and produces better markdown structure.
- Read `pdf_path` from the index entry (not from `zotero-read.sh item KEY`) as the primary path, since `zot` is not currently installed.
- Store `chunk_dir` as a relative path (from project root) in the index, matching the architecture schema.
- Sum token counts from `chunks.json` manifest rather than estimating from file sizes.
- Do NOT implement `--convert-all` in Phase 1 — it's not in the architecture spec and not in SKILL.md/command. Address separately if needed.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `literature-convert.sh` output filename depends on input basename | Use a temp copy of PDF named after citation_key, or glob for `.md` file in tmp_dir |
| `literature-convert.sh` requires `marker`/`pymupdf` which may not be installed | pdftotext IS available; convert.sh falls back to it automatically |
| `zot attach` may not support `--idempotency-key` flag | Verify with `zot --help`; if unsupported, omit the flag |
| Index update jq command may have issues with the `!=` operator (Issue #1132) | Use `select(.zotero_key == $k)` pattern (already used in zotero-index-add.sh) |
| chunk_dir as relative vs absolute | Be consistent: store relative from project root; resolve to absolute when checking existence |
| Token count overflow for very large PDFs | Use `jq` add with null guard: `[.[].token_count] | add // 0` |

---

## Context Extension Recommendations

- none (all relevant documentation exists in the architecture design doc and existing script headers)

---

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-chunk.sh` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-index-add.sh` (implemented)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-write.sh` (implemented)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-chunk.sh` (implemented)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-convert.sh` (first 40 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-build-index.sh` (first 30 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/skills/skill-zotero/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/commands/zotero.md`

### Tool Availability
- `pdftotext`: available at `/home/benjamin/.nix-profile/bin/pdftotext` (version 25.10.0)
- `pandoc`: available at `/run/current-system/sw/bin/pandoc`
- `zot`: NOT installed
- `jq`: available
- `python3`: available (required by literature-chunk.sh)
- `sqlite3`: available (required by literature-build-index.sh)
