# Research Report: /literature Workflow and --lit Flag Design

**Task**: 758 - Unified Literature System
**Dimension**: Concrete command workflow and implementation design
**Date**: 2026-06-23
**Builds on**: Reports 01-06 (infrastructure audit, agent design, storage, consolidation, synthesis, team research)

---

## Executive Summary

The unified literature system has exactly two user-facing features:

1. **`--lit` flag**: Agents get a compact briefing listing available literature, plus tools to search and read on demand. Surgical swap in 6 SKILL.md Stage 4a blocks.
2. **`/literature` command**: Two modes — discover sources (from task/prompt), or integrate PDFs (from path or specs/literature/ drop zone). Everything else is internal plumbing.

The existing infrastructure covers ~70% of the work. The missing pieces are: a briefing generator script, a source discovery script, and the per-repo sub-index format.

---

## Feature 1: `--lit` Flag (Briefing + Tools)

### What changes

Replace `literature-retrieve.sh` (injects full file content, up to 8,000 tokens) with `literature-briefing.sh` (injects ~300-token metadata listing, plus tool-use instructions).

### Files to change

| File | Change |
|------|--------|
| `skill-researcher/SKILL.md` Stage 4a | `literature-retrieve.sh` -> `literature-briefing.sh` |
| `skill-planner/SKILL.md` Stage 4a | Same |
| `skill-implementer/SKILL.md` Stage 4a | Same |
| `skill-researcher-hard/SKILL.md` Stage 4a | Same |
| `skill-planner-hard/SKILL.md` Stage 4a | Same |
| `skill-implementer-hard/SKILL.md` Stage 4a | Same |

No changes to `parse-command-args.sh` (already parses `--lit` correctly). No changes to `skill-orchestrate` `lit_flag` threading (already correct). Remove `zot_flag` references from skill-orchestrate.

### `literature-briefing.sh` design

```
INPUT: (no arguments — reads sub-index and global index directly)
OUTPUT: <literature-briefing>...</literature-briefing> block to stdout

FLOW:
1. Read specs/literature-index.json (per-repo sub-index)
   - If missing or empty: exit 0 (empty stdout, silent)
2. For each entry in sub-index:
   - Look up metadata from $LITERATURE_DIR/index.json (title, authors, year, chunk_count, total_tokens)
   - If not found in global index: skip with warning to stderr
3. Format compact briefing:

<literature-briefing>
Available literature (N sources):

1. Author et al., Year — "Title" [doc_id]
   Chunks: N chunks, ~M tokens total
   Path: ~/Projects/Literature/doc_id/

2. ...

To search across all literature: Bash('bash .claude/scripts/literature-search.sh "query"')
To browse a document's TOC: Bash('bash .claude/scripts/literature-search.sh --toc doc_id')
To read a specific chunk: Read('~/Projects/Literature/doc_id/section01_intro.md')
</literature-briefing>
```

Token budget: ~300-500 tokens for a typical 5-10 source sub-index.

### Bash permission requirement

Add to `.claude/settings.json` permissions.allow:
```
"Bash(bash .claude/scripts/literature-search.sh *)"
```

Without this, agents in orchestrate mode are blocked from calling the search tool. This is the single most critical prerequisite.

---

## Feature 2: `/literature` Command

### Command parsing — mode detection

```
/literature                              -> Mode B (integrate: scan specs/literature/ for unprocessed PDFs)
/literature ~/path/to/file.pdf           -> Mode B (integrate: process specific file)
/literature ~/path/to/dir/               -> Mode B (integrate: process all PDFs in directory)
/literature 42                           -> Mode A (discover: extract terms from task 42 description)
/literature "modal logic completeness"   -> Mode A (discover: use prompt as search terms)
/literature 42 "modal logic"             -> Mode A (discover: combine task description + prompt)
```

**Detection logic** (pseudocode):

```bash
args="$ARGUMENTS"

# Check for path (starts with / or ~ or . or contains .pdf/.djvu)
if [[ "$args" =~ ^[~/.]|\.pdf|\.djvu ]]; then
  mode="integrate"
  path="$args"

# Check for task number (leading digits, optionally followed by text)
elif [[ "$args" =~ ^([0-9]+)(\ +(.*))?$ ]]; then
  mode="discover"
  task_num="${BASH_REMATCH[1]}"
  prompt="${BASH_REMATCH[3]:-}"

# Check for bare text (prompt only, no task number)
elif [ -n "$args" ]; then
  mode="discover"
  task_num=""
  prompt="$args"

# No arguments: integrate mode (scan for unprocessed PDFs)
else
  mode="integrate"
  path=""
fi
```

### Mode A: Source Discovery

**Triggered by**: `/literature N`, `/literature "prompt"`, or `/literature N "prompt"`

**Flow**:

```
Step 1: Build search query
  - If task_num provided: read description from state.json
  - If prompt provided: use as-is
  - If both: concatenate description + prompt
  - Extract keywords (reuse stop-word removal from literature-retrieve.sh)

Step 2: Check global Literature/ index (Tier 1 — offline, instant)
  - jq search $LITERATURE_DIR/index.json by title/keyword match
  - Already-indexed sources: add to sub-index immediately, report as "already available"

Step 3: Check Zotero library (Tier 2 — offline, fast)
  - If $LITERATURE_DIR/zotero-library.json exists:
    Call zotero-search.sh with keywords
  - For matches with PDF available:
    Run literature-ingest.sh --zotero KEY (auto-integrate)
    Add doc_id to sub-index
  - For matches without PDF:
    Add to SOURCES.md as [IN_ZOTERO]

Step 4: Search online (Tier 3 — network, slower)
  - Semantic Scholar API: search by title/keywords
    curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=TERMS&fields=title,authors,year,openAccessPdf,externalIds&limit=10"
  - For each result with openAccessPdf.url:
    Download PDF to temp dir
    Run literature-ingest.sh on downloaded PDF
    Add doc_id to sub-index
  - For results without open-access PDF:
    Try Unpaywall via DOI:
      curl -s "https://api.unpaywall.org/v2/$DOI?email=benbrastmckie@gmail.com"
    If best_oa_location.url_for_pdf exists: download and ingest
    Otherwise: add to SOURCES.md as [PAYWALL]
  - For results with arXiv ID:
    PDF always available at https://arxiv.org/pdf/$ARXIV_ID
    Download and ingest

Step 5: Present results via AskUserQuestion
  - Show discovered sources with status tags
  - [AVAILABLE] — already in Literature/
  - [INGESTED] — just integrated from Zotero or online
  - [PAYWALL] — needs manual acquisition
  - Let user confirm which sources to add to sub-index
  - For [PAYWALL] sources: confirm adding to SOURCES.md

Step 6: Update sub-index and SOURCES.md
  - Add confirmed doc_ids to specs/literature-index.json
  - Append unresolved entries to specs/literature/SOURCES.md
  - Git commit
```

### Mode B: Source Integration

**Triggered by**: `/literature ~/path`, `/literature ~/dir/`, or bare `/literature` (scan mode)

**Flow**:

```
Step 1: Resolve source files
  - If path given and is a file: process that single PDF/DJVU
  - If path given and is a directory: find all *.pdf and *.djvu in it
  - If no path given:
    - Scan specs/literature/ for unprocessed PDFs (PDFs without corresponding .md)
    - Read SOURCES.md for [PENDING]/[FOUND] entries to match against

Step 2: Match PDFs to SOURCES.md entries (if applicable)
  - For each PDF found in specs/literature/:
    - Check filename against SOURCES.md entries (fuzzy title match)
    - If match found: associate metadata from SOURCES.md entry

Step 3: For each PDF, run literature-ingest.sh
  - Converts to markdown with content-aware chunking
  - Integrates into $LITERATURE_DIR (global Literature/ repo)
  - Updates global index.json
  - Rebuilds .literature.db FTS5 index

Step 4: Update per-repo sub-index
  - Add each ingested doc_id to specs/literature-index.json
  - Include relevance note from SOURCES.md if available

Step 5: Update SOURCES.md
  - Mark resolved entries as [RESOLVED] with doc_id
  - Leave unmatched entries unchanged

Step 6: Report and commit
  - Show summary: N files processed, M added to sub-index, K SOURCES.md entries resolved
  - Git commit in project repo
```

---

## Per-Repo Sub-Index: `specs/literature-index.json`

### Schema

```json
{
  "project": "nvim",
  "literature_dir": "~/Projects/Literature",
  "entries": [
    {
      "doc_id": "blackburn_2001_modal_logic",
      "relevance": "Core reference for modal logic semantics",
      "added": "2026-06-23",
      "source": "discover"
    }
  ]
}
```

**Design principle**: References only. No cached metadata (title, authors, year, token_count). Metadata is resolved at runtime from `$LITERATURE_DIR/index.json` by `literature-briefing.sh`. This avoids staleness.

**Fields**:
- `doc_id` (string, required): Matches an entry id in the global index
- `relevance` (string, optional): Why this source matters to this project
- `added` (ISO date, required): When the entry was added
- `source` (string, optional): How it was added — "discover", "manual", "import"

### Operations

| Operation | How |
|-----------|-----|
| Add entry | `jq '.entries += [{"doc_id": $id, "added": $date, "source": $src}]'` |
| Remove entry | `jq '.entries |= map(select(.doc_id == $id | not))'` |
| List entries | `jq '.entries[].doc_id'` |
| Check membership | `jq -e --arg id "$id" '.entries[] | select(.doc_id == $id)'` |

No separate script needed — these are one-liner jq operations inlined in the skill.

---

## SOURCES.md Format

**Location**: `specs/literature/SOURCES.md`

```markdown
# Literature Sources

Sources identified as relevant but not yet available in the Literature repository.

## Status Legend
- [PENDING] — Identified but not yet searched for
- [IN_ZOTERO] — In Zotero library but no PDF attached
- [PAYWALL] — No open-access version found
- [FOUND] — PDF URL identified, awaiting download
- [RESOLVED] — Integrated into Literature/ (doc_id in notes)

## Sources

| Title | Authors | Year | DOI | Status | Notes |
|-------|---------|------|-----|--------|-------|
| Example Paper | Smith, Jones | 2020 | 10.1234/example | [PAYWALL] | Springer, check institutional access |
| Another Paper | Lee | 2018 | 10.5678/another | [RESOLVED] | doc_id: lee_2018_another |
```

**Matching PDFs to entries**: When a PDF is dropped in `specs/literature/`, the filename is fuzzy-matched against the Title column (lowercased, underscores-to-spaces). If a match is found, the entry's metadata enriches the ingest pipeline. If no match, the PDF is ingested with metadata extracted from the PDF itself.

---

## Existing Modes: What Survives

The current skill-literature has 7 modes. In the unified system:

| Current Mode | Disposition | Reasoning |
|-------------|-------------|-----------|
| `status` | **Remove** | Replaced by bare `/literature` triggering integrate/scan mode |
| `scan` | **Merge into integrate** | Scanning for unprocessed PDFs is step 1 of Mode B |
| `convert` | **Merge into integrate** | Conversion is step 3 of Mode B (via literature-ingest.sh) |
| `validate` | **Keep** (as `--validate` flag) | Useful for index health checks, low cost to maintain |
| `index` | **Remove** | Sub-index is managed automatically by discover/integrate |
| `search` | **Remove from /literature** | Search is now agent-facing via literature-search.sh + --lit |
| `ingest` | **Merge into integrate** | literature-ingest.sh is called internally by Mode B |

**New command surface**:

```
/literature                    # Mode B: scan+integrate unprocessed PDFs
/literature <path>             # Mode B: integrate specific file/directory
/literature <N> [prompt]       # Mode A: discover sources for task
/literature "prompt"           # Mode A: discover sources from text
/literature --validate         # Health check on sub-index vs global index
```

That's 4 entry points (2 modes + validate), down from 7. Clean and minimal.

---

## New Script: `literature-discover.sh`

**Location**: `.claude/scripts/literature-discover.sh`

```
#!/usr/bin/env bash
# literature-discover.sh - Source discovery pipeline
#
# Usage:
#   literature-discover.sh "search terms"           # Discover by keywords
#   literature-discover.sh --task N                  # Discover from task description
#   literature-discover.sh --task N "extra terms"    # Task description + extra terms
#
# Pipeline:
#   Tier 1: Check global $LITERATURE_DIR/index.json
#   Tier 2: Check Zotero library (zotero-search.sh)
#   Tier 3: Search Semantic Scholar + Unpaywall + arXiv
#
# Output: JSON array of discovered sources with status
#
# Environment:
#   LITERATURE_DIR     — Global library (default: ~/Projects/Literature)
#   ZOTERO_LIBRARY     — CSL-JSON export (default: $LITERATURE_DIR/zotero-library.json)
#   DISCOVER_LIMIT     — Max results per API (default: 10)
#
# Exit codes:
#   0 — sources found (JSON on stdout)
#   1 — no sources found
#   2 — argument error

FLOW:

1. Parse args (terms, optional task_num)
2. If task_num: read description from specs/state.json, combine with terms
3. Extract keywords (stop-word removal, min 4 chars)

4. Tier 1 — Global index:
   python3 << 'PY'
   import json
   index = json.load(open(f"{LITERATURE_DIR}/index.json"))
   entries = index if isinstance(index, list) else index.get("entries", [])
   # Match by title substring or keyword overlap
   PY

5. Tier 2 — Zotero:
   zotero-search.sh --format=json --limit=$DISCOVER_LIMIT $KEYWORDS
   # Cross-reference results with Tier 1 (skip already-indexed)
   # Check PDF availability via pdf_paths field

6. Tier 3 — Online:
   # Semantic Scholar (only for sources not found in Tier 1/2)
   curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=$ENCODED&fields=title,authors,year,openAccessPdf,externalIds&limit=$DISCOVER_LIMIT"
   # For each result with DOI but no openAccessPdf:
   curl -s "https://api.unpaywall.org/v2/$DOI?email=benbrastmckie@gmail.com"

7. Merge results, deduplicate, assign status:
   - "available": already in global index
   - "in_zotero": in Zotero with PDF
   - "in_zotero_no_pdf": in Zotero without PDF
   - "open_access": PDF URL found online
   - "paywall": no open-access version found

8. Output JSON array to stdout
```

**The skill orchestrates**: The `/literature` command invokes this script, presents results via AskUserQuestion, then calls `literature-ingest.sh` for each source the user selects. The script itself does discovery only — it does not download or ingest.

---

## Implementation Sequence

Given the existing infrastructure, the implementation phases are:

1. **Create `specs/literature-index.json` schema + jq helpers** (~30 min)
2. **Create `literature-briefing.sh`** — reads sub-index, resolves metadata, outputs briefing block (~1 hr)
3. **Create `literature-discover.sh`** — three-tier lookup, outputs JSON (~2 hr)
4. **Update `/literature` command** — new argument parsing, two modes (~1 hr)
5. **Update skill-literature** — replace 7 modes with discover/integrate/validate (~1.5 hr)
6. **Swap Stage 4a in 6 SKILL.md files** — `literature-retrieve.sh` -> `literature-briefing.sh` (~30 min)
7. **Add Bash permission** + remove `zot_flag` from skill-orchestrate (~1 hr)
8. **Remove zotero extension** — delete `.claude/extensions/zotero/`, clean CLAUDE.md merge targets (~30 min)

Total: ~8 hours

---

## What NOT to Build

- No `/zotero` command — Zotero is an internal detail of the discover pipeline
- No literature-agent as a separate agent type — agents use briefing + Bash(literature-search.sh) + Read
- No `--zot` flag — single `--lit` flag covers everything
- No `status` or `scan` standalone modes — folded into bare `/literature` (integrate mode)
- No `index` or `search` standalone modes — sub-index is managed automatically, search is agent-facing
- No per-repo `.literature.db` SQLite — search uses the global database only
- No automatic `--lit` discovery preflight — discovery is a manual `/literature N` action, not triggered by `--lit`
