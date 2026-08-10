# Research Report: Task #736

**Task**: 736 - Update literature extension for sources/ directory convention
**Started**: 2026-06-16T20:30:00Z
**Completed**: 2026-06-16T20:45:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of `.claude/extensions/literature/`, `~/Projects/Literature/`, `literature-retrieve.sh`
**Artifacts**: `specs/736_literature_extension_sources_convention/reports/01_extension-sources-research.md`
**Standards**: report-format.md

## Executive Summary

- The `~/Projects/Literature/` repository was refactored: all 23 content directories moved into `sources/`, all index.json paths now have `sources/` prefix (confirmed: 196/196 entries)
- Three files need changes: `skill-literature/SKILL.md` (convert mode output paths), `EXTENSION.md` (documentation), and `literature-retrieve.sh` (fallback scan path)
- The index-based retrieval path already works correctly because it resolves paths from index.json entries, which already have `sources/` prefix; only the fallback scan and new conversion placement need updating

## Context & Scope

The `~/Projects/Literature/` repository was reorganized so all content lives under a `sources/` top-level directory. The extension's `LITERATURE_DIR` environment variable points to `~/Projects/Literature` (defaulted in `literature-ingest.sh` as `$HOME/Projects/Literature`). The skill's two-tier fallback resolves to `lit_dir=$LITERATURE_DIR` when the env var is set.

**Current directory structure of `~/Projects/Literature/`**:
```
~/Projects/Literature/
├── index.json          (root index — all paths prefixed with "sources/")
├── sources/            (all content lives here)
│   ├── blackburn_2002/
│   │   ├── ch00_preface.md
│   │   └── ...
│   └── ...
├── FIND_SOURCES.md
├── README.md
└── scripts/
```

All 196 entries in index.json have paths like `sources/blackburn_2002/ch00_preface.md`.

## Findings

### 1. What Already Works (No Changes Needed)

**Index-based retrieval (`literature-retrieve.sh` Tier 1/2)**:
The `literature-retrieve.sh` script reads paths directly from `index.json` entries and constructs full paths as `$LIT_DIR/$entry_path`. Since `entry_path` is now `sources/blackburn_2002/ch00_preface.md`, this resolves to `$LITERATURE_DIR/sources/blackburn_2002/ch00_preface.md` — which is correct. No change needed.

**`migrate-from-repo.sh` in Literature/**:
Already updated to place files under `sources/` (confirmed via grep: lines 180, 184, 225-226, 234, 275 all reference `sources/` prefix).

**`literature-ingest.sh` (core scripts)**:
Creates `DOC_DIR` at `$LITERATURE_DIR/$DOC_ID` (flat, no `sources/` prefix). This is the newer pipeline for FTS5 SQLite ingestion and is separate from the convert mode. It needs a separate decision about whether to adopt `sources/` — out of scope for this task per task description.

### 2. Changes Needed: `skill-literature/SKILL.md`

**Convert mode — output file path construction** (lines 591-628):

Currently, when `LITERATURE_DIR` is set and a new conversion is done, output files are written to:
- Single file: `$lit_dir/${basename_no_ext}.md` (flat at root of lit_dir)
- Multi-chunk: `$lit_dir/${basename_no_ext}/sectionNN_slug.md`

With the `sources/` convention, they should go to:
- Single file: `$lit_dir/sources/${basename_no_ext}.md`
- Multi-chunk: `$lit_dir/sources/${basename_no_ext}/sectionNN_slug.md`

**Specific code sections to change**:

a) **Content-aware chunking branch** (around line 594-606):
```bash
# BEFORE:
chunk_dir="$lit_dir/${basename_no_ext}"
mkdir -p "$chunk_dir"
# ...
output_files+=("${basename_no_ext}/section${nn}_${slug}.md")

# AFTER (when LITERATURE_DIR is set):
sources_prefix=$([ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ] && echo "sources/" || echo "")
chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"
mkdir -p "$chunk_dir"
# ...
output_files+=("${sources_prefix}${basename_no_ext}/section${nn}_${slug}.md")
```

b) **Mechanical fallback chunking branch** (around line 612-628):
Same pattern — both `chunk_dir` and `output_files` entries need the `sources/` prefix when using LITERATURE_DIR.

c) **Single-file (no-chunk) path** (around line 620):
```bash
# BEFORE:
output_files+=("${basename_no_ext}.md")

# AFTER (when LITERATURE_DIR is set):
output_files+=("${sources_prefix}${basename_no_ext}.md")
```

**The `sources_prefix` variable should be set once in Convert Step 1** (before target file determination) so all branches use it consistently.

**Backward compatibility**: Per-project `specs/literature/` directories should NOT get the `sources/` prefix. The conditional should check `[ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]` — the same condition used in Step 2 of the skill to set `lit_dir`.

### 3. Changes Needed: `literature-retrieve.sh` (Fallback Path)

**Lines 168-172** — the fallback `find` scan:
```bash
# CURRENT (finds .md/.txt anywhere in LIT_DIR):
while IFS= read -r f; do
  files+=("$f")
done < <(find "$LIT_DIR" -type f \( -name "*.md" -o -name "*.txt" \) ! -name "index.json" | sort)
```

The fallback triggers when index.json is absent or keywords are empty. With `sources/`, files are now at `$LIT_DIR/sources/**/*.md` rather than `$LIT_DIR/*.md`. The current `find` is recursive (`-type f` without `-maxdepth`), so it already searches subdirectories — but its behavior with `sources/` is acceptable because files at any depth are found.

However, the issue is that the fallback path will also pick up files NOT under `sources/` (like `FIND_SOURCES.md` at root or `README.md`). To clean this up with `sources/` awareness:

```bash
# BETTER FALLBACK: prefer sources/ subdirectory when it exists
if [ -d "$LIT_DIR/sources" ]; then
  scan_dir="$LIT_DIR/sources"
else
  scan_dir="$LIT_DIR"
fi

while IFS= read -r f; do
  files+=("$f")
done < <(find "$scan_dir" -type f \( -name "*.md" -o -name "*.txt" \) ! -name "index.json" | sort)
```

This is a minimal, backward-compatible change: if `sources/` doesn't exist (per-project directories), falls back to scanning `$LIT_DIR` as before.

### 4. Changes Needed: `EXTENSION.md`

The current `EXTENSION.md` (line 28) says:
> Source file co-location: PDF/DJVU source files live in the same literature directory or subdirectory as their converted markdown. Source files are gitignored via `specs/literature/**/*.pdf` and `specs/literature/**/*.djvu` (or the equivalent in the central repo's `.gitignore`).

The EXTENSION.md needs a section documenting the `sources/` convention for the centralized repo. Specifically:

1. Add a "sources/ Subdirectory Convention" subsection under "Key Conventions"
2. Document that when using `LITERATURE_DIR`, all content lives under `$LITERATURE_DIR/sources/`
3. Clarify that per-project `specs/literature/` directories use the flat (no `sources/`) layout
4. Mention that `index.json` paths are prefixed with `sources/` in the central repo

### 5. Other Files — No Changes Needed

- `literature-agent.md` (agents/): References `specs/literature/index.json` and `specs/literature/*/index.json` in documentation context only, not path construction
- `commands/literature.md`: Routes to skill only, no path construction
- `manifest.json`: No path references
- `scripts/cite-extract.sh`, `scripts/zotero-search.sh`: Do not construct lit_dir paths

## Decisions

- **The `sources/` prefix is conditional**: Only apply when `LITERATURE_DIR` is set and points to `~/Projects/Literature`. Per-project `specs/literature/` directories remain flat.
- **The fallback in literature-retrieve.sh needs the `sources/` scan-dir selection** but the current recursive `find` is technically functional (it finds files in subdirs). The change is a quality improvement.
- **`literature-ingest.sh` is out of scope**: It uses a different pipeline (SQLite FTS5) and creates `DOC_DIR` flat at `$LITERATURE_DIR/$DOC_ID`. Separate decision needed for that script.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Existing per-project `specs/literature/` break if `sources/` prefix applied unconditionally | Check `LITERATURE_DIR` env var before applying prefix — same condition used for `lit_dir` assignment |
| Validate mode looks for entries at wrong paths after convention change | Already works: validate reads paths from index.json, which already has `sources/` prefix |
| Fallback scan picks up non-content files at `$LITERATURE_DIR/` root | Add `sources/` dir check in fallback scan |

## Summary of Changes

| File | Change | Lines |
|------|--------|-------|
| `skills/skill-literature/SKILL.md` | Add `sources_prefix` variable in Convert mode; prefix `chunk_dir` and `output_files` entries | ~591-628 |
| `extensions/core/scripts/literature-retrieve.sh` | Add `sources/` dir check in fallback scan path | ~168-172 |
| `extensions/literature/EXTENSION.md` | Add "sources/ Subdirectory Convention" subsection | After line 28 |
