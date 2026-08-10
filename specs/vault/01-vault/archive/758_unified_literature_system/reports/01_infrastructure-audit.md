# Infrastructure Audit: Literature and Zotero Extensions

## 1. Extension Inventory

### Literature Extension (`.claude/extensions/literature/`)

| Artifact | Type | Status |
|----------|------|--------|
| `manifest.json` | Config | Complete — routing_exempt, depends on core+filetypes |
| `EXTENSION.md` | Docs | Complete — merged into CLAUDE.md |
| `README.md` | Docs | Complete — full user guide |
| `agents/literature-agent.md` | Agent | Documentation-only (direct execution, never spawned) |
| `skills/skill-literature/SKILL.md` | Skill | **Fully implemented** — 1,567 lines of detailed pseudocode |
| `commands/literature.md` | Command | Complete — argument parsing for 7 sub-modes |
| `commands/cite.md` | Command | Complete — citation verification |
| `skills/skill-cite/SKILL.md` | Skill | Present (not audited in detail) |
| `scripts/zotero-search.sh` | Script | **Fully implemented** — 409 lines, CSL-JSON search with weighted scoring |
| `scripts/cite-extract.sh` | Script | **Fully implemented** — 325 lines, 9 citation pattern families |

### Zotero Extension (`.claude/extensions/zotero/`)

| Artifact | Type | Status |
|----------|------|--------|
| `manifest.json` | Config | Complete — depends on core+literature |
| `EXTENSION.md` | Docs | Complete — merged into CLAUDE.md |
| `README.md` | Docs | Complete — full user guide with implementation status table |
| `agents/zotero-agent.md` | Agent | Documentation-only (direct execution, never spawned) |
| `skills/skill-zotero/SKILL.md` | Skill | Present — dispatches to scripts |
| `commands/zotero.md` | Command | Complete — argument parsing for 11 sub-modes |
| `context/project/zotero/domain/zotero-index.md` | Context | Partial — placeholder with schema summary |
| `context/project/zotero/patterns/retrieval-flags.md` | Context | Complete — --zot vs --lit coexistence docs |

### Zotero Scripts Implementation Status

| Script | Category | Lines | Status |
|--------|----------|-------|--------|
| `zotero-read.sh` | A: CLI Wrappers | 210 | **Fully implemented** — search, item, pdf, outline, annotations, note, tags, collections, stats |
| `zotero-write.sh` | A: CLI Wrappers | 239 | **Fully implemented** — note-add, tag-add, tag-remove, attach-file with --dry-run |
| `zotero-setup.sh` | A: CLI Wrappers | 300 | **Fully implemented** — --detect, --configure, --validate, --status |
| `zotero-chunk.sh` | B: Chunk Pipeline | 292 | **Fully implemented** — index lookup, PDF conversion, chunking, FTS5 rebuild |
| `zotero-attach-chunks.sh` | B: Chunk Pipeline | 229 | **Fully implemented** — upload chunks as Zotero child attachments |
| `zotero-index-add.sh` | C: Index Mgmt | 361 | **Fully implemented** — 20-field entry with metadata extraction, upsert |
| `zotero-index-remove.sh` | C: Index Mgmt | 131 | **Fully implemented** — delete entry, optional chunk cleanup |
| `zotero-search-index.sh` | C: Index Mgmt | 311 | **Fully implemented** — weighted scoring, Zotero library fallback |
| `zotero-retrieve.sh` | D: Context Injection | 310 | **Fully implemented** — scoring, greedy selection, token budget enforcement |

**Key finding**: Despite the README's implementation status table showing tasks 750-753 as "Not started", all 9 scripts are fully implemented with complete logic. The README is outdated.

### Core Scripts (`.claude/scripts/`)

| Script | Lines | Status |
|--------|-------|--------|
| `literature-retrieve.sh` | 211 | **Fully implemented** — keyword scoring from index.json, fallback to file scan |
| `zotero-retrieve.sh` | 310 | **Identical duplicate** of `.claude/extensions/zotero/scripts/zotero-retrieve.sh` |
| `literature-ingest.sh` | ~400 | Present — full pipeline ingestion (not read in detail) |

---

## 2. Data Flow

### PDF-to-Agent-Context Pipeline

```
Source PDF/DJVU
    |
    v
[Step 1: Extraction]
    pdftotext -layout / djvutxt
    |
    v
[Step 2: Chunking]
    Content-aware section detection (headings, chapters)
    Merge small sections toward 4,000-line target
    Mechanical fallback at 4,000-line boundaries
    |
    v
[Step 3: Storage]
    specs/literature/{doc_name}/sectionNN_{slug}.md  (chunked)
    specs/literature/{doc_name}.md                    (flat)
    |
    v
[Step 4: Indexing]
    specs/literature/index.json  (literature path)
    specs/zotero-index.json      (zotero path — 20-field entries)
    |
    v
[Step 5: Context Injection]
    --lit flag -> literature-retrieve.sh -> <literature-context> block
    --zot flag -> zotero-retrieve.sh     -> <zotero-context> block
    |
    v
[Step 6: Agent Prompt]
    Injected into skill preflight, before agent delegation
```

### Two Parallel Ingestion Pathways

**Literature pathway** (`/literature --convert`):
1. User places PDF in `specs/literature/`
2. `skill-literature` runs pdftotext/djvutxt
3. Content-aware chunking into `specs/literature/{doc}/`
4. Interactive metadata prompts (AskUserQuestion)
5. Writes to `specs/literature/index.json`

**Zotero pathway** (`/zotero --add KEY --chunk`):
1. `zotero-index-add.sh` fetches metadata from Zotero SQLite via `zot` CLI
2. Builds 20-field entry in `specs/zotero-index.json`
3. If `--chunk`: `zotero-chunk.sh` extracts PDF, chunks, stores in `specs/literature/{citation_key}/`
4. Updates `specs/zotero-index.json` with chunk metadata

**Hybrid pathway** (`/literature --search`):
1. Searches Zotero CSL-JSON export (`zotero-library.json`) via `zotero-search.sh`
2. Cross-references against `specs/literature/index.json`
3. Import pipeline: symlink PDF, convert, patch index with Zotero fields
4. Git commit in `$LITERATURE_DIR`

---

## 3. Index Schemas

### Literature Index (`specs/literature/index.json`)

```json
{
  "token_budget": 4000,
  "entries": [{
    "id": "string",
    "path": "string (relative to specs/literature/)",
    "token_count": "integer",
    "keywords": ["string"],
    "summary": "string",
    "authors": ["string"],
    "title": "string",
    "year": "integer|null",
    "doc_type": "paper|book|chapter|section",
    "source_format": "pdf|djvu|manual",
    "parent_doc": "string|null",
    "page_range": "string|null",
    "bib_key": "string|null",
    "zotero_key": "string|null",
    "zotero_path": "string|null",
    "project_tags": ["string"]
  }]
}
```

### Zotero Index (`specs/zotero-index.json`)

```json
{
  "version": "1.0",
  "created": "ISO8601",
  "last_updated": "ISO8601",
  "token_budget": 8000,
  "zot_data_dir": "/path/to/Zotero",
  "entries": [{
    "zotero_key": "8-char key",
    "citation_key": "string",
    "title": "string",
    "authors": ["string"],
    "year": "integer|null",
    "item_type": "string",
    "abstract_snippet": "string (300 chars)",
    "keywords": ["string"],
    "tags": ["string"],
    "collections": ["string"],
    "has_pdf": "boolean",
    "pdf_path": "string|null",
    "has_chunks": "boolean",
    "chunk_dir": "string|null",
    "chunk_count": "integer",
    "token_count": "integer",
    "relevance_keywords": ["string"],
    "notes_summary": "string|null",
    "added_at": "ISO8601",
    "last_retrieved": "ISO8601|null"
  }]
}
```

**Key differences**: The zotero index has 20 fields per entry with richer metadata (abstract_snippet, tags, collections, notes_summary, has_pdf, has_chunks, chunk_dir, chunk_count, relevance_keywords, last_retrieved). The literature index has 16 fields with bibliographic focus (doc_type, source_format, parent_doc, page_range, bib_key, zotero_key, zotero_path, project_tags). Schemas are incompatible despite both indexing the same underlying markdown files.

---

## 4. Duplication Analysis

### Identical or Near-Identical Code

| Component | Literature Location | Zotero Location | Duplication Type |
|-----------|-------------------|-----------------|-----------------|
| `zotero-retrieve.sh` | `.claude/scripts/` | `.claude/extensions/zotero/scripts/` | **Byte-identical copy** (310 lines) |
| Stop-word lists | `literature-retrieve.sh:48` | `zotero-retrieve.sh:82` | Near-identical (same words, different formatting) |
| Stop-word lists | `literature-retrieve.sh:48` | `zotero-index-add.sh:182` | Near-identical |
| Stop-word lists | `literature-retrieve.sh:48` | `zotero-search-index.sh:129` | Near-identical |
| Keyword extraction | `literature-retrieve.sh:50-58` | `zotero-retrieve.sh:85-95` | Same algorithm |
| Keyword extraction | Same pattern | `zotero-search-index.sh:131-163` | Same algorithm, more elaborate |
| Token estimation | `literature-retrieve.sh:194` (word*1.3) | `zotero-retrieve.sh:197-199` (word*1.3) | Identical formula |
| Greedy token budget selection | `literature-retrieve.sh:125-136` | `zotero-retrieve.sh:149-281` | Same pattern, zotero version has 3-path branching |
| Weighted scoring | `zotero-search.sh` (title+3, keyword+2, abstract+1, author+1) | `zotero-search-index.sh` (title+4, tags+3, abstract+2, keywords+2, collections+1, notes+1) | **Different weights, same approach** |
| Weighted scoring | `zotero-retrieve.sh` (same as search-index) | `literature-retrieve.sh` (keyword overlap only, +1 per match + summary bonus) | **Different algorithms** |

### Functional Duplication

| Feature | Literature Extension | Zotero Extension |
|---------|---------------------|-----------------|
| PDF text extraction | `pdftotext` in skill-literature | `zot pdf KEY` or `pdftotext` via `zotero-chunk.sh` |
| Content-aware chunking | Built into skill-literature SKILL.md (~200 lines) | Delegates to `literature-chunk.sh` (external) |
| Search | `zotero-search.sh` (CSL-JSON based) | `zotero-search-index.sh` (per-repo index based) |
| Context injection | `literature-retrieve.sh` -> `<literature-context>` | `zotero-retrieve.sh` -> `<zotero-context>` |
| Index management | Inline in SKILL.md (jq operations) | Dedicated scripts (`zotero-index-add.sh`, `zotero-index-remove.sh`) |
| Chunk storage | `specs/literature/{doc}/` | `specs/literature/{citation_key}/` (same directory!) |

---

## 5. Flag Wiring Analysis

### `--lit` Flag Path

```
User: /research 42 --lit
  -> parse-command-args.sh: LIT_FLAG="true" (exported)
  -> skill-researcher/SKILL.md line 170:
     if [ "$lit_flag" = "true" ]; then
       lit_context=$(bash .claude/scripts/literature-retrieve.sh ...)
     fi
  -> Injected into agent prompt as <literature-context> block
```

Wired through: `skill-researcher`, `skill-planner`, `skill-implementer`, `skill-orchestrate`

### `--zot` Flag Path

**Critical finding**: `--zot` is **NOT parsed** by `parse-command-args.sh`. There is no `ZOT_FLAG` variable.

The only place `--zot` / `zot_flag` appears in the skill layer is `skill-orchestrate/SKILL.md`, which threads it through delegation context JSON. But the standard `/research`, `/plan`, `/implement` commands **do not support `--zot`**.

The `zotero-retrieve.sh` script exists and is fully implemented, but there is no wiring to invoke it from the standard skill preflight. Only `/orchestrate` can use `--zot`.

**Conclusion**: The `--zot` flag is incomplete infrastructure. The README and docs describe it as working with `/research`, `/plan`, `/implement`, but only `/orchestrate` actually supports it.

---

## 6. Storage Architecture

### Three Storage Locations

| Location | Owner | Git-tracked | Contains |
|----------|-------|-------------|----------|
| `specs/literature/` | Literature extension | Yes (markdown only; PDFs gitignored) | Converted markdown chunks, `index.json` |
| `specs/zotero-index.json` | Zotero extension | Yes | Per-repo curated Zotero item metadata |
| `$LITERATURE_DIR` (e.g., `~/Projects/Literature/`) | User | Varies (own git repo possible) | Centralized markdown, `zotero-library.json`, `pdfs/` symlinks |

### Relationship Between Locations

- `specs/literature/` and `$LITERATURE_DIR` are **alternatives** controlled by the `LITERATURE_DIR` env var. If set, all `/literature` operations use `$LITERATURE_DIR` instead of `specs/literature/`.
- `specs/zotero-index.json` is always per-repo. It points to chunks stored in `specs/literature/{citation_key}/`.
- Both the literature and zotero extensions write chunks to the **same** `specs/literature/` directory, but maintain **separate indexes** with incompatible schemas.
- `zotero-library.json` (Better BibTeX CSL-JSON export) is the Zotero library snapshot used by `zotero-search.sh`. It lives in `$LITERATURE_DIR/` and is maintained by Zotero's auto-export.

---

## 7. Scoring Algorithms Comparison

| Retrieval Script | Scoring Fields | Threshold | Token Budget |
|-----------------|---------------|-----------|-------------|
| `literature-retrieve.sh` | keywords (+1 per overlap), summary (+1 bonus) | >= 1 | 8000 (or index `token_budget`) |
| `zotero-retrieve.sh` | title*4, tags*3, abstract*2, keywords*2, collections*1, notes*1 | >= 4 | 8000 (or index `token_budget`) |
| `zotero-search.sh` | title*3, keyword*2, abstract*1, author*1 | > 0 | N/A (returns all matches) |
| `zotero-search-index.sh` | title*4, tags*3, abstract*2, keywords*2, collections*1, notes*1 | >= 1 | N/A (returns top N) |

The four scripts use three different scoring formulas for essentially the same task.

---

## 8. Key Findings for Refactoring

### Structural Issues

1. **Two indexes, one storage**: Both extensions write to `specs/literature/` but maintain separate incompatible indexes (`index.json` with 16 fields vs `zotero-index.json` with 20 fields)
2. **Identical code duplication**: `zotero-retrieve.sh` is byte-identical across two locations
3. **Near-identical algorithm duplication**: Stop-word lists, keyword extraction, token estimation repeated 4+ times
4. **Incomplete wiring**: `--zot` flag is documented but only functional via `/orchestrate`
5. **Three scoring algorithms**: Retrieval and search use different weights despite the same underlying need
6. **Passive injection model**: Both `--lit` and `--zot` dump pre-scored content into the prompt — the agent cannot explore, search, or filter

### What Works Well

1. **Zotero scripts are robust**: All 9 scripts fully implemented with graceful degradation
2. **Content-aware chunking**: The heading-detection algorithm is well-designed
3. **Graceful degradation**: Both systems fail silently when unconfigured (exit 0 with no output)
4. **Per-repo curation**: The `specs/zotero-index.json` model of explicitly curating relevant items per project is a good design pattern worth preserving
5. **Shared chunk storage**: Both systems already write to `specs/literature/`, which validates the "one storage" vision

### For the Unified System

1. A single merged index schema is needed that captures the union of both schemas' fields
2. The per-repo sub-index (relevance filter) concept from zotero should be preserved but generalized
3. The retrieval model should shift from "inject everything matching" to "agent explores via tools"
4. The `zot` CLI integration is valuable and should be preserved for Zotero SQLite access
5. Stop-word lists, keyword extraction, and token estimation should be centralized into shared utility functions
