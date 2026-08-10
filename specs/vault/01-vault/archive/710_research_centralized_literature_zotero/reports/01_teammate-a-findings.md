# Research Report: Task #710 — Teammate A Findings

**Task**: 710 - Research Centralized Literature Management with Zotero.bib Integration
**Role**: Teammate A — Primary Researcher (Implementation Approaches and Patterns)
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T01:00:00Z
**Effort**: ~2 hours
**Sources/Inputs**: Codebase exploration, Zotero.bib analysis, existing index.json schemas, skill-base.sh, literature-retrieve.sh, literature-organization.md, WebSearch

---

## Executive Summary

- Zotero.bib uses absolute paths to `~/Documents/Zotero/storage/{HASH}/filename.pdf`; 746 of 878 entries have PDFs; bib_keys are year-suffixed author names (e.g., `Burgess1982`, `Gabbay1994`)
- BimodalLogic has 113 index entries (25 unique source works) and cslib has 76 entries (10 unique source works); 3 bib_keys overlap (`Burgess1984`, `GHR94`, `Reynolds1994`) but the files are independently converted
- `~/Projects/Literature/` already exists as an empty repo (README only); it is the right home for a centralized store
- The current `literature-retrieve.sh` is hardcoded to `$PROJECT_ROOT/specs/literature/` via script-relative path arithmetic; it has no `LITERATURE_DIR` support
- The `--lit` flag path is: parse-command-args.sh sets `LIT_FLAG="true"` -> skill calls `bash .claude/scripts/literature-retrieve.sh "$description" "$task_type"` -> script resolves `LIT_DIR="$PROJECT_ROOT/specs/literature"`
- The centralized design requires: (1) `LITERATURE_DIR` env var override in literature-retrieve.sh, (2) a unified index.json schema with `bib_key`, (3) a PDF storage strategy (copy from Zotero storage is preferred over symlink), and (4) a `/literature` command that operates on `LITERATURE_DIR` regardless of project

---

## Research Area 1: Zotero.bib Format Analysis

### File Field Format

The `file` field in `~/texmf/bibtex/bib/Zotero.bib` uses **absolute paths** to Zotero's internal storage:

```bibtex
file = {/home/benjamin/Documents/Zotero/storage/QYLBSWIN/Abasnezhad - 2020 - Leibnizian Identity and Paraconsistent Logic.pdf}
```

Key observations:
- **Single-file entries**: `file = {/absolute/path/to/file.pdf}`
- **Multi-file entries**: semicolon-separated: `file = {/path/a.pdf;/path/b.pdf;/path/c.pdf}`
- **Path structure**: `~/Documents/Zotero/storage/{8-char-hash}/{Author} - {Year} - {Title}.pdf`
- The 8-character hash (e.g., `QYLBSWIN`) is Zotero's internal storage key, not a content hash
- Files **do exist** at these paths (verified: the first sampled file resolved correctly)
- **878 total entries** in Zotero.bib; **746 have PDF attachments** (85% coverage)

### BibTeX Key Format

Zotero exports use `AuthorYYYY` format with disambiguation suffixes:
- `Burgess1982`, `Burgess1982a`, `Burgess1984` — year + optional letter suffix
- `Gabbay1994`, `Reynolds1992`, `Blackburn2001`

**Mismatch with literature index.json**: The current per-repo indexes use `bib_key` values that sometimes differ from Zotero's keys (e.g., `GHR94` and `Reynolds1994` are used in the BimodalLogic index but not found as Zotero keys under those names; the Zotero keys are `Gabbay1994` and `Reynolds1992`). This requires a normalization step or dual-key tracking.

### BibTeX Entry Type Distribution

| Type | Count |
|------|-------|
| `@article` | 592 |
| `@book` | 177 |
| `@incollection` | 92 |
| `@phdthesis` | 7 |
| `@inproceedings` | 5 |
| `@unpublished` | 3 |
| `@misc` | 2 |

**Confidence**: High — directly observed from file content.

---

## Research Area 2: Current Per-Repo Literature Systems

### BimodalLogic (`~/Projects/BimodalLogic/specs/literature/`)

- **113 index entries** covering **25 unique source works** (by bib_key)
- Files organized in subdirectory-per-work pattern (e.g., `burgess_1982/sec01_...md`)
- Most works are deeply chunked by section (up to 10+ sections per book chapter)
- Schema: `{id, bib_key, title, authors, year, section, path, page_range, token_count, keywords, summary}`
- `token_budget: 40000` (unusually high — 5x the default 8000 in literature-retrieve.sh)
- PDF source files also present (`.pdf` files alongside markdown)
- No `doc_type` or `source_format` fields (predates the enriched schema from task 702)

### CSLib (`~/Projects/cslib/specs/literature/`)

- **76 index entries** covering **10 unique source works** (by bib_key)
- Mix of flat files (short papers: `johansson_1937.md`, `henkin_1949.md`) and subdirectory chunks (long books: `blackburn_2001/`, `chagrov_1997/`, `church_1956/`)
- `token_budget: 4000` (standard)
- Schema matches enriched format: includes `doc_type`, `source_format`, `parent_doc`, `page_range`
- Many entries have `bib_key: null` (manually added papers not in Zotero)

### Overlap Analysis

**3 bib_keys appear in both repos**: `Burgess1984`, `GHR94`, `Reynolds1994`

However the overlap is only partial in what is converted:
- `Burgess1984` (Basic Tense Logic): BimodalLogic has 7 sections; cslib has 1 entry
- `GHR94` (Gabbay/Hodkinson/Reynolds 1994): BimodalLogic has many chapter-sections; cslib has 1 (ch10 only)
- `Reynolds1994`: BimodalLogic has 3 sections; cslib has 1 entry (oddly keyed as `reynolds_1992` in id but `Reynolds1994` in bib_key)

This represents **true redundancy**: the same physical PDFs are converted independently and stored with duplicated markdown in two separate repos.

### Schema Difference: BimodalLogic vs CSLib

| Field | BimodalLogic | CSLib |
|-------|-------------|-------|
| `id` | yes | yes |
| `bib_key` | yes | yes |
| `title` | yes | yes |
| `authors` | yes | yes |
| `year` | yes | yes |
| `section` | yes | yes (mapped to description) |
| `path` | yes | yes |
| `page_range` | yes | yes |
| `token_count` | yes | yes |
| `keywords` | yes | yes |
| `summary` | yes | yes |
| `doc_type` | **no** | **yes** |
| `source_format` | **no** | **yes** |
| `parent_doc` | **no** | **yes** |

The BimodalLogic index predates the enriched schema added in task 702 (the literature extension). A unified schema must include all fields from both.

**Confidence**: High — directly read from index.json files.

---

## Research Area 3: Centralized `~/Projects/Literature/` Repo Design

### Proposed Directory Layout

```
~/Projects/Literature/
├── README.md
├── index.json                    # Unified master index (all entries from all projects)
├── Zotero.bib -> ~/texmf/bibtex/bib/Zotero.bib  # OR: copy/sync script
├── pdfs/                         # PDF storage (copied from Zotero storage)
│   ├── Burgess1982/
│   │   └── burgess_1982_axioms-for-tense-logic.pdf
│   ├── Gabbay1994/
│   │   └── gabbay_1994_temporal-logic-vol1.pdf
│   └── ...
└── docs/                         # Converted markdown files
    ├── burgess_1982/
    │   ├── sec01_axioms-for-tense-logic.md
    │   └── sec02_28-lemma.md
    ├── burgess_1984/
    │   ├── sec01_page-1.md
    │   └── ...
    ├── johansson_1937.md          # Flat short papers
    ├── henkin_1949.md
    └── ...
```

**Alternative flat layout** (simpler, matches current per-repo convention):

```
~/Projects/Literature/
├── README.md
├── index.json
├── burgess_1982/                  # Subdirectory per work (current convention)
│   ├── sec01_axioms-for-tense-logic.md
│   └── sec02_28-lemma.md
├── burgess_1984/
│   └── ...
├── johansson_1937.md
└── Burgess_1982_AxiomsForTenseLogic.pdf  # Co-located PDF (gitignored)
```

**Recommendation**: Use the **flat layout matching current per-repo convention** (no `docs/` subdirectory). This:
- Is backward-compatible with existing `literature-retrieve.sh` path expectations
- Avoids restructuring the `path` field convention in index.json
- Matches what `/literature --convert` already produces

### Unified index.json Schema

Extend the current enriched schema (from task 702) with one new field: `bib_key`.

The BimodalLogic index already has `bib_key`. The unified schema should be:

```json
{
  "version": 2,
  "token_budget": 8000,
  "max_chunks": 10,
  "description": "Unified literature index for ~/Projects/Literature/. Shared across all projects via LITERATURE_DIR.",
  "schema": {
    "id": "Unique identifier (author_year[_section])",
    "bib_key": "BibTeX key in Zotero.bib (null if not in Zotero)",
    "title": "Full title of work",
    "authors": "Author(s) as string",
    "year": "Publication year (integer)",
    "section": "Section/chapter description (null for whole-paper files)",
    "path": "Path relative to LITERATURE_DIR root (exact filename)",
    "page_range": "Page range within original source (null if unknown)",
    "token_count": "Estimated token count (chars/4 + 20)",
    "keywords": "6-10 keywords for retrieval matching",
    "summary": "One-sentence description of content",
    "doc_type": "paper|book|chapter|section",
    "source_format": "pdf|djvu|manual",
    "parent_doc": "ID of parent entry for chunks/sections (null for top-level)",
    "projects": ["BimodalLogic", "cslib"]
  },
  "entries": [...]
}
```

**New field: `projects`** (array of strings) — which repos currently use this entry. Enables project-scoped queries: "give me all entries used by BimodalLogic tasks". This is optional metadata for tooling; `literature-retrieve.sh` ignores unknown fields.

**New field semantics for `bib_key`**: In the centralized index, `bib_key` MUST use the exact key from Zotero.bib (e.g., `Gabbay1994` not `GHR94`). The existing repos use shorthand keys (`GHR94`) that are project-local conventions. Migration requires remapping these to Zotero canonical keys OR maintaining a `bib_key_aliases` field.

**Recommendation**: Add a `zotero_key` field to distinguish Zotero's canonical key from the project-local shorthand:

```json
{
  "bib_key": "GHR94",          // project convention (for backward compat)
  "zotero_key": "Gabbay1994"   // exact key in ~/texmf/bibtex/bib/Zotero.bib
}
```

**Confidence**: High on schema design; medium on `projects` field (depends on whether cross-project querying is needed).

---

## Research Area 4: Cross-Repo Path Resolution via `LITERATURE_DIR`

### Current Path Resolution in `literature-retrieve.sh`

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
```

This is entirely hardcoded relative to the script's location. When the script lives at `.claude/scripts/literature-retrieve.sh`, the project root is always `$PROJECT_ROOT = <repo>/.claude/../..` = `<repo>/`. So `LIT_DIR` = `<repo>/specs/literature`.

### Proposed `LITERATURE_DIR` Override

The minimal change to `literature-retrieve.sh`:

```bash
# After PROJECT_ROOT calculation, add:
DEFAULT_LIT_DIR="$PROJECT_ROOT/specs/literature"
LIT_DIR="${LITERATURE_DIR:-$DEFAULT_LIT_DIR}"
INDEX_FILE="$LIT_DIR/index.json"
```

This means:
- **When `LITERATURE_DIR` is unset**: behavior is identical to current (per-project `specs/literature/`)
- **When `LITERATURE_DIR=/home/benjamin/Projects/Literature`**: retrieval reads from the centralized repo
- **Mixed mode**: Projects can still have their own `specs/literature/` for project-specific drafts that haven't been promoted to the centralized repo

### Environment Variable Discovery

The `LITERATURE_DIR` variable should be set in:
1. `~/.bashrc` or `~/.zshrc` (persistent for all shells)
2. `~/.claude/settings.json` env block (for Claude Code sessions)
3. Per-project `.env` file (optional override)

**Recommended approach**: Set in shell profile AND in `.claude/settings.json` to ensure both interactive shell sessions and Claude Code agent sessions pick it up.

```json
// ~/.claude/settings.json (or .claude/settings.local.json)
{
  "env": {
    "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
  }
}
```

### Fallback Behavior When `LITERATURE_DIR` Unset

The existing fallback is ideal: if `specs/literature/` doesn't exist in the project, `literature-retrieve.sh` exits with code 1 and the `--lit` flag is silently ignored. This already handles the "no local literature" case gracefully.

**Confidence**: High — the implementation change is minimal (4 lines in literature-retrieve.sh).

---

## Research Area 5: Agent System Integration

### Current `--lit` Flag Flow

```
User: /research 710 --lit
  -> parse-command-args.sh: sets LIT_FLAG="true"
  -> skill-researcher/SKILL.md: reads lit_flag from delegation context
  -> calls: bash .claude/scripts/literature-retrieve.sh "$description" "$task_type"
  -> literature-retrieve.sh: resolves LIT_DIR, scores entries, outputs <literature-context>
  -> context block injected into agent prompt
```

The call site in skill-planner/SKILL.md (and skill-implementer):
```bash
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

No path arguments are passed. The script is called from the project root directory (since Claude Code runs in `$PROJECT_ROOT`). The script's `$(dirname "${BASH_SOURCE[0]}")` resolves relative to `.claude/scripts/`.

### What Changes with Centralized Design

1. **literature-retrieve.sh**: Add `LITERATURE_DIR` override (4 lines). No other changes needed.
2. **skill-literature/SKILL.md**: The skill currently hardcodes `lit_dir="specs/literature"`. This must be updated to respect `LITERATURE_DIR`:
   ```bash
   lit_dir="${LITERATURE_DIR:-specs/literature}"
   ```
3. **`/literature` command**: Currently always operates on `specs/literature/` relative to project. Must detect and operate on `LITERATURE_DIR` when set.
4. **`literature-retrieve.sh` path field interpretation**: Currently reads `LIT_DIR/$entry.path`. With centralized design, paths in index.json are relative to `LITERATURE_DIR`, so this still works correctly.

### Token Budget Considerations

The BimodalLogic index has `token_budget: 40000` but the retrieve script defaults to `TOKEN_BUDGET=8000` and only reads from the index when it finds `token_budget` in the JSON. This is inconsistent. The centralized index should use a single `token_budget` value.

**Recommendation**: Set `token_budget: 8000` in the unified index (the retrieve script's default). Individual callers can override via a future flag if needed.

### Project-Scoped vs Global Retrieval

A key design question: when a task in BimodalLogic uses `--lit`, should it retrieve ALL literature from the centralized repo, or only entries marked with `"projects": ["BimodalLogic"]`?

**Recommendation**: Retrieve ALL entries (keyword scoring already filters to relevant ones). The `projects` field is metadata for tooling, not a retrieval filter. The keyword scoring mechanism is sufficient to ensure only relevant literature appears. This keeps `literature-retrieve.sh` simple.

**Confidence**: High on the integration approach; medium on token budget recommendation.

---

## Research Area 6: PDF Storage Strategy

### Current State

- **BimodalLogic**: PDF source files are co-located with markdown in `specs/literature/` subdirectories. They are gitignored (`specs/literature/**/*.pdf`). Users must re-add after checkout.
- **CSLib**: Same pattern. PDFs present but gitignored.
- **Zotero storage**: All 746 PDFs are at `/home/benjamin/Documents/Zotero/storage/{hash}/`.

### Option A: Copy PDFs from Zotero to Literature/

Copy the PDF to `~/Projects/Literature/{bib_key}/` or `~/Projects/Literature/{author_year}.pdf`.

**Pros**:
- PDFs survive Zotero reorganization or key renaming
- Literature repo is self-contained
- Can be backed up independently of Zotero
- Consistent naming convention (human-readable) vs Zotero's internal hashes

**Cons**:
- Doubles disk space for indexed works
- Updates require manual sync when Zotero updates a PDF

### Option B: Symlink to Zotero Storage

Create symlinks in `~/Projects/Literature/pdfs/{bib_key}.pdf` -> `/home/benjamin/Documents/Zotero/storage/{hash}/filename.pdf`.

**Pros**:
- Zero disk duplication
- Always reflects current Zotero attachment

**Cons**:
- Symlink targets break if Zotero reorganizes internal storage or if storage moves
- Zotero's 8-char hash is opaque — symlink construction requires parsing `file =` field from Zotero.bib
- Hash-named target paths are not human-readable

### Option C: Reference Only (No PDF Copy)

Store only the converted markdown in `~/Projects/Literature/`. PDFs remain in Zotero storage. Record the Zotero storage path in index.json as `zotero_path` field.

**Pros**:
- No disk duplication
- No sync needed
- `zotero_path` enables users to open the original PDF from index data

**Cons**:
- PDF not accessible without Zotero being installed and synced
- No self-contained repo

### Recommendation: Option A (Copy) for new additions; Option C (reference field) for lookup

**For practical implementation**:
1. When converting a new paper: copy the PDF from Zotero storage to `~/Projects/Literature/{author_year}/` with a human-readable name
2. Record `"zotero_path": "/home/benjamin/Documents/Zotero/storage/HASH/filename.pdf"` in index.json for traceability
3. The PDF in Literature is gitignored (consistent with per-project convention)

This gives: human-readable local PDF copies that survive Zotero reorganization, plus a Zotero path field for auditing the provenance.

**Confidence**: Medium — the copy approach is more robust but requires a migration workflow.

---

## Recommended Architecture: Concrete Design Decisions

### Decision 1: Single `~/Projects/Literature/` Centralized Repo

**Decision**: Use `~/Projects/Literature/` as the single centralized store. The repo already exists (README only). It will hold all converted markdown for works shared across projects. Per-project `specs/literature/` directories are deprecated for shared works but may still hold project-specific drafts.

### Decision 2: `LITERATURE_DIR` Environment Variable with Fallback

**Decision**: Modify `literature-retrieve.sh` (4 lines) to honor `LITERATURE_DIR`:

```bash
DEFAULT_LIT_DIR="$PROJECT_ROOT/specs/literature"
LIT_DIR="${LITERATURE_DIR:-$DEFAULT_LIT_DIR}"
```

Set `LITERATURE_DIR=/home/benjamin/Projects/Literature` in `~/.config/nvim/.claude/settings.json` (or settings.local.json, or `~/.bashrc`).

### Decision 3: Unified index.json Schema v2

**Decision**: The unified `~/Projects/Literature/index.json` uses the enriched schema (from task 702) plus `zotero_key` and `projects` fields. All existing per-repo entries must be migrated.

```json
{
  "version": 2,
  "token_budget": 8000,
  "max_chunks": 10,
  "entries": [{
    "id": "burgess_1982_sec01",
    "bib_key": "Burgess1982",
    "zotero_key": "Burgess1982",
    "title": "...",
    "authors": "John P. Burgess",
    "year": 1982,
    "section": "§1",
    "path": "burgess_1982/sec01_axioms-for-tense-logic.md",
    "page_range": "367-370",
    "token_count": 3541,
    "keywords": [...],
    "summary": "...",
    "doc_type": "section",
    "source_format": "pdf",
    "parent_doc": "burgess_1982",
    "projects": ["BimodalLogic"]
  }]
}
```

### Decision 4: PDF Storage — Copy with `zotero_path` Reference

**Decision**: Copy PDFs from Zotero storage to `~/Projects/Literature/{bib_key}/` with human-readable filenames. Record original Zotero path as `"zotero_path"` in index.json. PDFs are gitignored in Literature repo.

### Decision 5: `/literature` Command Updated for `LITERATURE_DIR`

**Decision**: The `skill-literature/SKILL.md` and any scripts that hardcode `specs/literature` must be updated to use:
```bash
lit_dir="${LITERATURE_DIR:-specs/literature}"
```

The `/literature --convert` and `/literature --index` modes should always write to `LITERATURE_DIR` when set, ensuring new conversions go to the centralized repo.

### Decision 6: Migration Strategy for Existing Per-Repo Literature

**Decision**: Do NOT retroactively delete `specs/literature/` from BimodalLogic and cslib. Instead:
1. Migrate the markdown files to `~/Projects/Literature/` (copy them)
2. Update index.json entries to include `doc_type`, `source_format`, `parent_doc` (missing from BimodalLogic)
3. Set `LITERATURE_DIR` so future `--lit` operations use the centralized repo
4. Leave per-project `specs/literature/` as empty stubs (or with a README pointing to Literature repo)

---

## Evidence and Examples

### Zotero.bib file field (multi-file example)

```bibtex
@incollection{Abramsky2011,
  title = {Introduction to Categories and Categorical Logic},
  author = {Abramsky, S. and Tzevelekos, N.},
  year = 2011,
  file = {/home/benjamin/Documents/Zotero/storage/5VP5TULI/LNPnotes.pdf;
          /home/benjamin/Documents/Zotero/storage/5WGNA75Y/Abramsky and Tzevelekos - 2011 - Introduction to Categories and Categorical Logic.pdf;
          /home/benjamin/Documents/Zotero/storage/ZBDEXKPS/2011_Book_NewStructuresForPhysics.pdf}
}
```

Multiple PDFs per entry is common for incollection entries (chapter PDF + book PDF).

### Current literature-retrieve.sh hardcoded path (key line)

```bash
LIT_DIR="$PROJECT_ROOT/specs/literature"
```

Location: `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` line 31.

### literature-retrieve.sh proposed minimal change

```bash
# Lines 29-32 (current):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
INDEX_FILE="$LIT_DIR/index.json"

# Lines 29-34 (proposed):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_LIT_DIR="$PROJECT_ROOT/specs/literature"
LIT_DIR="${LITERATURE_DIR:-$DEFAULT_LIT_DIR}"
INDEX_FILE="$LIT_DIR/index.json"
```

This 2-line change is the entirety of the literature-retrieve.sh modification needed.

---

## Confidence Levels by Research Area

| Area | Finding | Confidence |
|------|---------|------------|
| 1. Zotero.bib | File field format, absolute paths, hash directories, entry count | High |
| 1. Zotero.bib | bib_key format (AuthorYYYY) | High |
| 2. Current systems | Entry counts (113 BimodalLogic, 76 cslib) | High |
| 2. Current systems | 3 bib_keys overlap; files independently converted | High |
| 2. Current systems | Schema differences (BimodalLogic missing doc_type, source_format) | High |
| 3. Centralized design | Directory layout recommendation | High |
| 3. Centralized design | Unified schema v2 with `zotero_key` and `projects` fields | Medium-High |
| 4. Path resolution | LITERATURE_DIR override (2-line change to retrieve.sh) | High |
| 4. Path resolution | Settings.json injection for Claude Code sessions | High |
| 5. Agent integration | Skills need lit_dir variable update | High |
| 5. Agent integration | Token budget consolidation to 8000 | Medium |
| 6. PDF strategy | Copy-with-zotero_path recommendation | Medium |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| `LITERATURE_DIR` not set in Claude Code agent sessions | Set in `.claude/settings.json` env block, not just `~/.bashrc` |
| bib_key mismatch between Zotero.bib and literature index | Add `zotero_key` field alongside project-local `bib_key` |
| Large centralized index degrades keyword scoring (too many matches) | Token budget (8000) and MAX_FILES=10 already limit output; keyword scoring handles scale |
| PDF copies go stale if Zotero updates an attachment | `zotero_path` field enables manual re-sync; accept occasional staleness |
| BimodalLogic's `token_budget: 40000` causes retrieval mismatch | Override in retrieve script if BimodalLogic has its own `token_budget` in index.json; harmonize to 8000 |
| Per-project `specs/literature/` entries shadow centralized entries | When `LITERATURE_DIR` is set, retrieve script uses only centralized repo; no shadowing |
| Migration of existing 189 entries (113 + 76) | Migration is additive (copy markdown, update index); old data remains in place as fallback |

---

## Context Extension Recommendations

- **Topic**: `LITERATURE_DIR` cross-repo environment variable pattern
- **Gap**: No documentation exists for how to configure `LITERATURE_DIR` or what the fallback chain looks like
- **Recommendation**: Add `literature-organization.md` section on centralized configuration; update CLAUDE.md literature mode section

- **Topic**: Zotero.bib parsing for PDF discovery
- **Gap**: No documented tooling for extracting PDF paths from Zotero.bib to assist with Literature repo population
- **Recommendation**: A small helper script `zotero-lookup.sh` that resolves a bib_key to its PDF path would support `/literature --convert-from-zotero KEY`

---

## Appendix: Search Queries Used

1. "Zotero BibTeX export file field format PDF path storage 2025 2026"
2. "centralized reference management multiple git repositories shared literature 2025 2026"
3. "literature as code academic reference sharing across projects environment variable symlink 2025"
4. "shared academic library git repository cross-project knowledge base environment variable discovery pattern"
5. "Zotero Better BibTeX file field absolute path format storage hash"

## Appendix: Key File Paths Examined

- `/home/benjamin/texmf/bibtex/bib/Zotero.bib` — 878 entries, 11788 lines
- `/home/benjamin/Projects/BimodalLogic/specs/literature/index.json` — 113 entries, 2284 lines
- `/home/benjamin/Projects/cslib/specs/literature/index.json` — 76 entries
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — path resolution lines 29-37
- `/home/benjamin/.config/nvim/.claude/skills/skill-literature/SKILL.md` — hardcoded `lit_dir="specs/literature"`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/EXTENSION.md` — extension overview
- `/home/benjamin/.config/nvim/.claude/context/guides/literature-organization.md` — current conventions
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/parse-command-args.sh` — LIT_FLAG parsing
- `/home/benjamin/Projects/Literature/` — exists, README only
