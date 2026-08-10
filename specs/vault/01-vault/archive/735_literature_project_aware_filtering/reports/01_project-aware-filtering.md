# Research Report: Task #735

**Task**: 735 - Add project-aware literature filtering
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T00:30:00Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase (literature-retrieve.sh, literature-search.sh, index.json, BimodalLogic/, cslib/)
**Artifacts**: specs/735_literature_project_aware_filtering/reports/01_project-aware-filtering.md
**Standards**: report-format.md

## Executive Summary

- `project_tags` already exists as a v2 field in `~/Projects/Literature/index.json` and is **already populated** for all 195 entries (all tagged `["BimodalLogic"]`). No scanning of source files is needed to add this field — it is a curated metadata field, not auto-generated.
- `cslib` has zero entries in `index.json` (and zero in the FTS5 database); adding cslib-tagged entries requires identifying relevant literature and adding new entries manually or via `/literature --index`.
- The FTS5 database (`~/Projects/Literature/.literature.db`) stores chunks in `chunks_data` and `document_metadata` tables — neither has a `project_tags` column. For Tier 1 filtering, the project tag lookup must cross-reference `index.json` by `doc_id`.
- `literature-retrieve.sh` uses Tier 1 (FTS5) when `.literature.db` exists. Tier 1 emits a `<literature-tool>` block instructing the agent to use `literature-search.sh` — it does **not** inject content directly. For Tier 2 (legacy keyword mode), it reads `index.json` and scores entries by keyword overlap.
- Recommended approach: (a) auto-detect project from `$PWD` using git root basename, (b) for Tier 1: pass a `--project` flag to `literature-search.sh` that filters `chunks_fts` results to only `doc_id` values tagged with the current project in `index.json`, (c) for Tier 2: filter scored entries by project tag before budget selection; (d) entries with no project tags remain as fallback when filtered results are empty.

## Context & Scope

The global literature library at `~/Projects/Literature/` is shared across all projects (BimodalLogic, cslib, etc.). The `literature-retrieve.sh` script provides context injection via `--lit`. Currently it injects all relevant literature regardless of which project the agent is working in. The task is to make retrieval project-aware: when invoked from a cslib working directory, prefer cslib-tagged entries; when in BimodalLogic, prefer BimodalLogic-tagged entries.

## Findings

### 1. Current index.json Schema and Sample Entries

**File**: `/home/benjamin/Projects/Literature/index.json`
**Version**: 2
**Total entries**: 195

Schema fields per entry:
```
id, bib_key, title, authors, year, section, path, page_range,
token_count, keywords, summary, doc_type, source_format,
zotero_key, zotero_path, parent_doc, project_tags
```

`project_tags` is already a defined, populated field (added in v2). All 195 current entries have `project_tags: ["BimodalLogic"]`. There are **no entries tagged `cslib`** and **no untagged entries**.

Sample entry structure:
```json
{
  "id": "blackburn_2002_book",
  "bib_key": "BlackburnDeRijkeVenema2002",
  "title": "Modal Logic (2002 Cambridge edition)",
  "path": "blackburn_2002/",
  "token_count": 0,
  "keywords": ["modal logic", "Kripke semantics", ...],
  "summary": "Full text of Blackburn, de Rijke & Venema's Modal Logic...",
  "doc_type": "book",
  "project_tags": ["BimodalLogic"]
}
```

The `project_tags` field is multi-valued (array), so a single entry can belong to multiple projects (e.g., a paper relevant to both BimodalLogic and cslib could have `["BimodalLogic", "cslib"]`).

### 2. Current literature-retrieve.sh Architecture

**File**: `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh`

**Tier 1 (FTS5 database present)**:
- Checks for `.literature.db` at local path (`specs/literature/`) or global path (`~/Projects/Literature/`)
- If found, emits a `<literature-tool>` XML block instructing the agent to call `literature-search.sh` on demand
- Does **not** inject document content — just describes the search tool interface
- The agent then calls `literature-search.sh "query"` during its work

**Tier 2 (legacy, no database)**:
- Reads `index.json` (from `$LITERATURE_DIR` or `specs/literature/`)
- Extracts keywords from task description and type
- Scores each entry by keyword overlap against `entry.keywords` and `entry.summary`
- Greedily selects up to `MAX_FILES=10` entries within `TOKEN_BUDGET=8000` tokens
- Emits `<literature-context>` with file content directly injected

**Key observation**: The script takes `<description> <task_type>` as arguments but has **no project-detection logic**. It does not inspect `$PWD` or read any project identifier.

### 3. literature-search.sh Architecture (Tier 1 query engine)

**File**: `/home/benjamin/.config/nvim/.claude/scripts/literature-search.sh`

FTS5 query path:
```sql
SELECT d.chunk_id, d.doc_id, d.section_path, d.title, d.summary,
       d.token_count, d.cross_refs, d.source_path,
       d.prev_chunk_id, d.next_chunk_id,
       bm25(chunks_fts, 10, 5, 3, 1) AS rank,
       substr(d.content, 1, 200) AS snippet
FROM chunks_fts
JOIN chunks_data d ON d.id = chunks_fts.rowid
WHERE chunks_fts MATCH ?
ORDER BY rank
LIMIT ?
```

The database schema has **no `project_tags` column** in `chunks_data` or `document_metadata`. The `doc_id` values in the database (e.g., `blackburn_2001`, `blackburn_2002`) correspond to `id` prefixes in `index.json` entries.

The script has **no `--project` flag** and no project filtering.

### 4. FTS5 Database Schema

**File**: `/home/benjamin/Projects/Literature/.literature.db`

```sql
CREATE TABLE chunks_data (
  id INTEGER PRIMARY KEY,
  chunk_id TEXT UNIQUE,
  doc_id TEXT NOT NULL,
  parent_chunk_id TEXT,
  level INTEGER,
  section_path TEXT,
  title TEXT,
  keywords TEXT,
  summary TEXT,
  token_count INTEGER,
  source_path TEXT,
  prev_chunk_id TEXT,
  next_chunk_id TEXT,
  cross_refs TEXT,
  content TEXT
);
CREATE TABLE document_metadata (
  doc_id TEXT PRIMARY KEY,
  title TEXT, authors TEXT, year INTEGER,
  source_path TEXT, chunks_dir TEXT, chunk_count INTEGER, ingested_at TEXT
);
CREATE VIRTUAL TABLE chunks_fts USING fts5(title, keywords, summary, content, ...)
```

There are 24 distinct `doc_id` values in the database, all corresponding to BimodalLogic entries (e.g., `blackburn_2001`, `blackburn_2002`, `burgess_1982`, etc.). No cslib docs are present.

**Key constraint**: Adding `project_tags` to the SQLite schema requires an ALTER TABLE migration or recreating the database. Alternatively, project filtering can be done by reading allowed `doc_id` values from `index.json` and using SQL `IN (...)` filtering.

### 5. BimodalLogic Source File Structure

**Path**: `/home/benjamin/Projects/BimodalLogic/`

Key topics extractable from module structure:
- `Theories/Bimodal/Syntax/` — bimodal logic, formula syntax, TM operators (box, diamond, H, G)
- `Theories/Bimodal/ProofSystem/` — axioms, derivation, inference rules
- `Theories/Bimodal/Semantics/` — Kripke frames, truth evaluation, frame conditions
- `Theories/Bimodal/Metalogic/` — soundness, completeness, weak canonical models
- `Theories/Bimodal/Automation/` — proof tactics, search

Keywords: `modal logic`, `temporal logic`, `bimodal`, `Kripke semantics`, `frame conditions`, `soundness`, `completeness`, `tense logic`, `S5`, `linear temporal`

All 195 literature entries cover these topics (Modal Logic textbooks, tense logic papers by Burgess, Reynolds, Venema, etc.). The project tag `BimodalLogic` accurately describes these entries.

### 6. cslib Source File Structure

**Path**: `/home/benjamin/Projects/cslib/`

Top-level module categories:
- `Algorithms` — MergeSort, TimeM
- `Computability` — Automata (DA/NA/EpsilonNA/Acceptors), Distributed (FLP), Languages (Büchi/omega/regular), Machines (Turing), URM
- `Crypto` — PerfectSecrecy, SecretSharing
- `Foundations` — Combinatorics, Logic (inference systems, connectives), Relations, Semantics (LTS/FLTS/bisimulation), Syntax
- `Languages` — CCS, CombinatorLogic, LambdaCalculus (locally nameless, STLC, Fsub, untyped)
- `Logics` — HML, LinearLogic (CLL, MLL), Modal, Propositional
- `MachineLearning` — PAC learning
- `Probability` — PMF

Keywords for cslib: `automata`, `bisimulation`, `LTS`, `CCS`, `lambda calculus`, `linear logic`, `HML`, `modal logic`, `regular languages`, `omega automata`, `Büchi automata`, `process algebra`, `formal semantics`, `computability`, `Turing machine`

**Current state**: Zero literature entries are tagged `cslib`. No cslib-specific literature exists in `index.json`. Literature overlapping cslib topics (process algebra, automata theory, etc.) would need to be sourced and added.

### 7. Project Detection from $PWD

The git root basename provides the canonical project name:
```bash
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo '')")
```

For common project paths:
- `/home/benjamin/Projects/BimodalLogic` → `BimodalLogic`
- `/home/benjamin/Projects/cslib` → `cslib`
- `/home/benjamin/.config/nvim` → `nvim`

This approach is reliable and zero-configuration. If git root is unavailable, fall back to `basename "$PWD"`.

## Recommendations

### A. Project Tag Population

**For BimodalLogic**: Already complete — all 195 entries tagged. No action needed.

**For cslib**: Two-step process:
1. Identify literature relevant to cslib topics (automata theory, process algebra, bisimulation, lambda calculus, linear logic). Key candidates: Milner's CCS paper, Hopcroft/Ullman automata theory, Barendregt lambda calculus, Girard linear logic, etc.
2. Add entries via `/literature --index` (for existing markdown) or `/literature --convert` (for PDFs). Include `project_tags: ["cslib"]` in the index entry.

**Cross-project tagging**: Entries relevant to both (e.g., a paper on temporal logic and automata) should have `["BimodalLogic", "cslib"]`.

**Manual population approach**: Since `project_tags` is a curated field (not auto-generated), the recommended approach is to add tags explicitly when adding new literature. A scan-and-tag script for existing entries would compare entry keywords against project-specific keyword sets, but this risks false positives and is better done manually.

### B. literature-retrieve.sh Modifications

**Project detection** (add near top of script after constants):
```bash
detect_project() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$git_root" ]; then
    basename "$git_root"
  else
    basename "$PWD"
  fi
}
CURRENT_PROJECT=$(detect_project)
```

**Tier 2 filtering** (before scoring loop):
Add a jq filter that prioritizes project-tagged entries:
```bash
# Build project-filtered + untagged fallback entry list
project_entries=$(echo "$all_entries" | jq --arg proj "$CURRENT_PROJECT" '
  map(select(.project_tags | (. == null or length == 0) or (index($proj) != null)))
')
# If project filtering yields results, use them; otherwise use all_entries
if [ "$(echo "$project_entries" | jq 'length')" -gt 0 ]; then
  all_entries="$project_entries"
fi
```

Then score against keywords as before. Entries with no `project_tags` are always included as fallback.

**Tier 1 enhancement**: Pass project to `literature-search.sh` via a flag or environment variable:
```bash
# In the <literature-tool> block, add:
printf 'Current project: %s (prefer entries tagged with this project)\n' "$CURRENT_PROJECT"
printf 'FILTER HINT: Use --project "%s" flag if available for project-scoped results.\n' "$CURRENT_PROJECT"
```

Or pass as environment variable: `LITERATURE_PROJECT="$CURRENT_PROJECT"` in the tool invocation.

### C. literature-search.sh Modifications

Add `--project <name>` flag support:

1. Parse `--project <name>` argument; store as `PROJECT_FILTER`
2. Load allowed `doc_id` set from `index.json`:
   ```python
   with open(index_path) as f:
       idx = json.load(f)
   project_doc_ids = set()
   untagged_doc_ids = set()
   for e in idx.get('entries', []):
       tags = e.get('project_tags', [])
       if not tags:
           untagged_doc_ids.add(e['id'])
       elif project_filter in tags:
           project_doc_ids.add(e['id'])
   allowed_doc_ids = project_doc_ids | untagged_doc_ids
   # If no project matches found, allow all (graceful fallback)
   if not project_doc_ids:
       allowed_doc_ids = None  # no filter
   ```
3. Modify SQL to add `AND d.doc_id IN (...)` when `allowed_doc_ids` is set:
   ```sql
   WHERE chunks_fts MATCH ?
   AND d.doc_id IN (...)
   ```

**Fallback contract**: If `--project` yields zero results, re-run without the project filter and return all results. This ensures entries with no project_tags are always accessible.

### D. Tier 1 vs Tier 2 Consistency

The `<literature-tool>` block currently tells the agent to search freely. For Tier 1 project awareness, two options:
1. **Inject project hint**: Add project context to the tool description so the agent includes the project name in its searches (soft guidance)
2. **Flag-based filtering**: Pass `--project` to `literature-search.sh` explicitly in agent instructions

Option 1 is simpler and requires no changes to the agent's behavior. Option 2 requires the agent to use a specific flag pattern. **Recommend Option 1 for Tier 1** (minimal change) and **Option 2 for a follow-up** when cslib entries exist and cross-project contamination is observed.

## Edge Cases and Fallback Behavior

| Scenario | Behavior |
|----------|----------|
| Project not detectable (no git root) | `CURRENT_PROJECT` = `basename $PWD`; may produce no matches → fall back to all entries |
| Project has no tagged entries | Filter returns empty set → fall back to untagged + all entries |
| All entries untagged (legacy state) | No filtering applied, all entries available |
| Entry tagged for multiple projects | Included for any matching project |
| Agent invoked outside a project dir | Detected project = dirname; tags unlikely to match → full fallback |
| cslib has no entries yet | Filter matches zero entries → untagged fallback only |

## Decisions

1. **Do not auto-generate `project_tags` from source file scanning.** The field is curated metadata. Keyword-based scanning would produce false positives and is not how the field is currently managed.
2. **Use git root basename as project identifier.** Matches existing convention (BimodalLogic dir = "BimodalLogic" tag).
3. **Modify `literature-retrieve.sh` for Tier 2** (clear, direct change to the scored entries pipeline).
4. **Modify `literature-search.sh` with `--project` flag for Tier 1** (database-level filtering via `doc_id IN` after loading from index.json).
5. **Untagged entries are always available as fallback.** No entry is ever excluded permanently; the filtering is preference-based.
6. **Do not add `project_tags` column to SQLite schema.** Use index.json as the authority for tags; filter by `doc_id IN (allowed_set)`.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Detecting wrong project from $PWD | Use git root, not $PWD basename; document override via `LITERATURE_PROJECT` env var |
| Performance: loading index.json on every search | index.json is ~200 entries, sub-5ms parse; acceptable |
| cslib entries don't exist yet | Tier 2 filter will find no matches → falls back to all (correct behavior) |
| Tier 1: agent ignores project hint | Soft guidance only; add `--project` flag in follow-up if needed |
| `doc_id` mismatch between index.json and DB | index.json `id` field uses underscore format matching DB `doc_id` exactly (verified) |

## Appendix

### Search Queries Used
- Codebase: `literature-retrieve.sh`, `literature-search.sh`, `index.json`, `~/Projects/BimodalLogic`, `~/Projects/cslib`
- Database schema inspection via sqlite3

### References
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` (Tier 1/2 architecture)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-search.sh` (FTS5 query engine)
- `/home/benjamin/Projects/Literature/index.json` (195 entries, all BimodalLogic-tagged)
- `/home/benjamin/Projects/Literature/.literature.db` (24 doc_ids, no project_tags column)
- `/home/benjamin/Projects/BimodalLogic/` (Lean 4, TM bimodal logic)
- `/home/benjamin/Projects/cslib/Cslib.lean` (155 public imports across 9 top-level modules)
