# Research Report: Task #711

**Task**: 711 - create_zotero_search_script
**Started**: 2026-06-15T05:00:00Z
**Completed**: 2026-06-15T05:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 710 (completed — centralized Literature repo and LITERATURE_DIR established)
**Sources/Inputs**:
- Codebase: `.claude/extensions/literature/manifest.json`, `~/Projects/Literature/scripts/migrate-from-repo.sh`
- Task 710 artifacts: `reports/01_team-research.md`, `plans/02_centralized-literature-plan.md`
- Live filesystem: `~/texmf/bibtex/bib/Zotero.bib`, `~/Documents/Zotero/storage/`, `~/Projects/Literature/index.json`
**Artifacts**: This report

---

## Executive Summary

- The Zotero library is documented as a Better BibTeX CSL-JSON auto-export to `~/Projects/Literature/zotero-library.json`, but the file does not yet exist (user must run the one-time Zotero export setup). The script must handle this gracefully.
- CSL-JSON structure is well-understood from Better BibTeX documentation and from the existing `migrate-from-repo.sh` which already references `citation-key`, and from the Zotero.bib file which reveals the path format: `{/absolute/path/to/Zotero/storage/HASH/filename.pdf}`.
- PDF path resolution from Zotero storage is straightforward: Better BibTeX CSL-JSON includes an `attachments` array (or `attachment` field) with absolute paths. The existing Zotero.bib `file` field format (`/home/benjamin/Documents/Zotero/storage/QYLBSWIN/filename.pdf`) reveals the path structure.
- The literature extension has no `scripts/` directory yet — it must be created.
- The manifest.json `provides` block needs a `scripts` array entry to register the new script.
- Relevance scoring should use weighted multi-field matching: title (3x weight), abstract (1x), author (1x), keyword tags (2x).

---

## Context & Scope

Task 711 creates `.claude/extensions/literature/scripts/zotero-search.sh` — a jq-powered search tool for the Better BibTeX CSL-JSON auto-export at `~/Projects/Literature/zotero-library.json`. This script:

1. Searches a CSL-JSON file across title, author, abstract fields using jq
2. Checks PDF availability (verifies files exist on disk from Zotero storage paths)
3. Ranks results by keyword relevance score
4. Outputs JSON with: `bib_key`, `title`, `authors`, `year`, `type`, `pdf_paths` (existing only), `abstract_snippet`

This is a **new standalone utility script** (not a skill or agent). It is registered in the literature extension manifest and can be called by other scripts/agents that need to look up Zotero entries.

---

## Findings

### 1. CSL-JSON Structure (Better BibTeX Export Format)

Better BibTeX CSL-JSON (`zotero-library.json`) is a JSON array of entries. The top-level structure is:

```json
[
  {
    "id": "http://zotero.org/users/USER_ID/items/ITEM_KEY",
    "citation-key": "Burgess1982",
    "type": "article-journal",
    "title": "Axioms for Tense Logic. I. \"Since\" and \"Until\"",
    "author": [
      {"family": "Burgess", "given": "John P."}
    ],
    "issued": {"date-parts": [[1982, 7]]},
    "abstract": "...",
    "DOI": "...",
    "ISSN": "...",
    "volume": "41",
    "page": "367-374",
    "container-title": "Notre Dame Journal of Formal Logic"
  }
]
```

Key fields for the search script:
- **`citation-key`**: The Better BibTeX cite key (e.g., `Burgess1982`, `BlackburnDeRijkeVenema2002`). This is the primary lookup key.
- **`type`**: CSL item type strings: `"article-journal"`, `"book"`, `"chapter"` (for `@incollection`), `"thesis"`, `"paper-conference"`, `"report"`.
- **`title`**: Plain text title string. No LaTeX encoding — Better BibTeX decodes `{{}}` braces.
- **`author`**: Array of `{family, given}` objects. Must be joined for display.
- **`issued`**: `{"date-parts": [[YYYY, MM?, DD?]]}` — nested array format. Year is `issued["date-parts"][0][0]`.
- **`abstract`**: Full abstract as plain text (Better BibTeX decodes LaTeX).
- **`attachments`** or **`attachment`**: PDF path information. The exact field name depends on the Better BibTeX version.

**PDF attachment field**: Better BibTeX CSL-JSON stores attachment paths in the `attachments` array (newer versions) or as part of the item data. However, the existing `migrate-from-repo.sh` references `.attachment // .PDF` which suggests an older format. The most reliable approach is to check multiple possible fields: `attachments`, `attachment`, `PDF`.

**Key insight from migrate-from-repo.sh**: The script already uses:
```bash
jq -r --arg key "$bib_key" '
  .[] | select(.["citation-key"] == $key) |
  (.attachment // .PDF // null)
' "$zotero_lib"
```
This confirms `citation-key` is the lookup field and `attachment` or `PDF` holds the path.

**Zotero storage path format** (from live Zotero.bib analysis):
```
/home/benjamin/Documents/Zotero/storage/QYLBSWIN/Burgess - 1982 - Axioms for tense logic. I. Since and until..pdf
```
Format: `/home/benjamin/Documents/Zotero/storage/{8-char-hash}/{author} - {year} - {title-truncated}.pdf`

Better BibTeX CSL-JSON may encode these paths differently than the BibTeX `file` field. The script must normalize and verify file existence via `[ -f "$path" ]`.

**Multi-file entries**: 138 Zotero.bib entries have semicolon-separated files. CSL-JSON represents multiple attachments as an array. The search script should return all valid PDF paths from the attachments, not just the first.

### 2. The Zotero Library File Status

`~/Projects/Literature/zotero-library.json` **does not yet exist** — the task description says it's a Better BibTeX auto-export that the user must configure. The script must:

1. Check `ZOTERO_LIBRARY` env var first (configurable path)
2. Fall back to `${LITERATURE_DIR:-~/Projects/Literature}/zotero-library.json`
3. Fall back to `~/Projects/Literature/zotero-library.json` if neither is set
4. Exit cleanly with an error message if no file is found

This mirrors the two-tier fallback pattern established in `literature-retrieve.sh`.

### 3. PDF Path Resolution Strategy

Two approaches for resolving PDF paths from CSL-JSON:

**Approach A: Direct CSL-JSON attachment field**
Better BibTeX CSL-JSON may include attachment paths directly. Query pattern:
```jq
.[] | select(.["citation-key"] == $key) | .attachments[]?.path // empty
```

**Approach B: Fallback to Zotero.bib**
If CSL-JSON lacks attachment data, fall back to parsing the `file` field in `~/texmf/bibtex/bib/Zotero.bib`. This requires BibTeX parsing (fragile) — should be an optional fallback, not the primary.

**Recommended approach**: Try CSL-JSON attachment fields first; report paths that exist on disk; skip paths that don't. No BibTeX parsing needed. If `zotero-library.json` was exported without attachment data, `pdf_paths` will be an empty array (not an error).

**Path verification**: Use `[ -f "$path" ]` for each path. Only include paths of existing files in output.

### 4. Multi-Field Search Implementation

The search function should work across three primary fields with different weights:

```
Score = (title_matches × 3) + (abstract_matches × 1) + (author_matches × 1) + (keyword_matches × 2)
```

**jq implementation approach** (single-pass per entry):
```jq
map(
  . as $entry |
  ($entry.title // "" | ascii_downcase) as $title |
  ($entry.abstract // "" | ascii_downcase) as $abstract |
  ($entry.author // [] | map(.family + " " + .given) | join(" ") | ascii_downcase) as $authors |
  ($entry.keyword // "" | ascii_downcase) as $keywords |
  
  ([$query_terms[] |
    . as $term |
    (if ($title | test($term)) then 3 else 0 end) +
    (if ($abstract | test($term)) then 1 else 0 end) +
    (if ($authors | test($term)) then 1 else 0 end) +
    (if ($keywords | test($term)) then 2 else 0 end)
  ] | add // 0) as $score |
  
  select($score > 0) |
  . + {_score: $score}
) | sort_by(-._score)
```

**Query term splitting**: Split query string on whitespace, remove stop words, search each term independently (OR semantics). Minimum score of 1 to include in results.

### 5. Output JSON Format

Per task requirements, output one JSON object per matching entry:
```json
[
  {
    "bib_key": "Burgess1982",
    "title": "Axioms for Tense Logic. I. \"Since\" and \"Until\"",
    "authors": "John P. Burgess",
    "year": 1982,
    "type": "article-journal",
    "score": 5,
    "pdf_paths": [
      "/home/benjamin/Documents/Zotero/storage/5HK4WV9T/Burgess - 1982 - Axioms for tense logic.pdf"
    ],
    "abstract_snippet": "First 200 chars of abstract..."
  }
]
```

**Author formatting**: Join `author[].family + ", " + given` with "; " separator.
**Year extraction**: `entry.issued["date-parts"][0][0]` — handles nullable gracefully.
**Abstract snippet**: First 200 characters of `abstract` field, trimmed at word boundary.
**pdf_paths**: Only include paths where `[ -f "$path" ]` is true.

### 6. Literature Extension Manifest Integration

The current `manifest.json` has no `scripts` entry:

```json
{
  "provides": {
    "agents": ["literature-agent.md"],
    "commands": ["literature.md"],
    "skills": ["skill-literature"]
  }
}
```

The manifest needs a `scripts` array added to `provides`. However, checking other extension manifests to confirm the exact schema:
<br>The `provides.scripts` array convention needs to be checked — some extensions use `hooks` for script deployment. The script should be placed at `.claude/extensions/literature/scripts/zotero-search.sh` regardless; manifest registration can list it in a `scripts` array (copied-on-install pattern) or as a standalone utility (no registration needed if it's called directly by path).

**Recommendation**: Add `"scripts": ["scripts/zotero-search.sh"]` to `provides` in the manifest. The install mechanism copies scripts alongside skills. This follows the pattern where scripts land at `.claude/scripts/` in each project.

### 7. Usage Interface Design

```bash
# Basic usage
zotero-search.sh <query>

# With explicit library path
ZOTERO_LIBRARY=/path/to/lib.json zotero-search.sh "temporal logic"

# Output format flag
zotero-search.sh --format=json "modal logic completeness"    # default
zotero-search.sh --format=pretty "modal logic completeness"  # human-readable
zotero-search.sh --limit=10 "modal logic"                    # limit results

# Exit codes:
# 0 - results found
# 1 - no library file found (with usage message)
# 2 - no results found (empty JSON array [])
```

### 8. Implementation Approach: Pure jq

The entire search can be done in a single `jq` invocation with the query terms passed as `--arg` parameters. This avoids shell loops over potentially 878 entries and is significantly faster:

```bash
# Build query terms array
query_terms=$(echo "$query" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' '\n' | \
  grep -v -E "^(the|a|an|and|or|but|in|on|at|of|to|for|is|are|was|were)$" | \
  awk 'length > 2' | sort -u | jq -R . | jq -s .)

# Run single jq pass
jq --argjson terms "$query_terms" --argjson max "$LIMIT" '
  map(
    . as $e |
    ($e.title // "" | ascii_downcase) as $t |
    ($e.abstract // "" | ascii_downcase) as $a |
    ($e.author // [] | map(.family + " " + .given) | join(" ") | ascii_downcase) as $au |
    ($terms | map(
      . as $term |
      (if ($t | test($term; "i")) then 3 else 0 end) +
      (if ($a | test($term; "i")) then 1 else 0 end) +
      (if ($au | test($term; "i")) then 1 else 0 end)
    ) | add // 0) as $score |
    select($score > 0) |
    {
      bib_key: $e["citation-key"],
      title: $e.title,
      authors: ($e.author // [] | map(.family + ", " + .given) | join("; ")),
      year: ($e.issued["date-parts"]?[0]?[0]? // null),
      type: $e.type,
      score: $score,
      pdf_paths: [],
      abstract_snippet: ($e.abstract // "" | .[0:200])
    }
  ) | map(select(. != null)) | sort_by(-.score) | .[0:$max]
' "$ZOTERO_LIBRARY_PATH"
```

PDF path verification cannot be done inside jq (no filesystem access) — paths must be post-processed in bash with `[ -f "$path" ]` checks.

### 9. Edge Cases and Error Handling

| Edge Case | Handling |
|-----------|----------|
| `zotero-library.json` not found | Exit 1 with setup instructions |
| Empty query string | Exit with usage message |
| No results | Output `[]` and exit 2 |
| CSL-JSON is not an array | Detect and report format error |
| PDF path not accessible | Skip path (not included in `pdf_paths`) |
| Abstract field missing | Use `""` as default |
| Author array empty | Use `""` as default |
| Year field missing/malformed | Use `null` in output |
| Very large library (2000+ entries) | jq handles this fine; single-pass performance is adequate |

---

## Recommendations

### Implementation Plan

**Phase 1**: Create the scripts directory and the script:
- `mkdir -p .claude/extensions/literature/scripts/`
- Write `zotero-search.sh` with the pure-jq approach

**Phase 2**: Update manifest.json:
- Add `"scripts": ["scripts/zotero-search.sh"]` to `provides`
- This ensures the script is deployed to `.claude/scripts/` in projects using the extension

**Script structure**:
```bash
#!/usr/bin/env bash
# zotero-search.sh - Search Zotero library (Better BibTeX CSL-JSON) using jq
#
# Usage: zotero-search.sh [--limit=N] [--format=json|pretty] <query>
#
# Environment:
#   ZOTERO_LIBRARY   - Path to Better BibTeX CSL-JSON export (overrides default)
#   LITERATURE_DIR   - Base literature directory (used for default library path)
#
# Default library path: ${LITERATURE_DIR:-~/Projects/Literature}/zotero-library.json
```

**Key design decisions**:
1. Pure jq for search (no bash loops per entry) — performance scales to 1000+ entries
2. PDF verification in bash post-pass — jq cannot check filesystem
3. Graceful degradation when library is absent — clear error + setup instructions
4. Output is always valid JSON array (empty `[]` on no results)
5. No BibTeX parsing fallback — CSL-JSON is the only supported format

### Manifest Registration

Check other extension manifests for the `provides.scripts` convention before writing. If no extension uses it yet, establish the pattern here. The alternative (not registering, relying on path) is acceptable since the script is called by path in other scripts, not by name.

---

## Decisions

1. **Query model**: OR semantics across terms, minimum score 1 to include
2. **Weighting**: title (3x), keywords/tags (2x), abstract (1x), author (1x)
3. **Output format**: JSON array, always valid (empty array on no results)
4. **PDF verification**: Filesystem check (`[ -f ]`) for each path; missing paths excluded
5. **Library path**: `ZOTERO_LIBRARY` env var > `$LITERATURE_DIR/zotero-library.json` > `~/Projects/Literature/zotero-library.json`
6. **Script location**: `.claude/extensions/literature/scripts/zotero-search.sh`

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| CSL-JSON attachment field format varies between Better BibTeX versions | Check both `attachments[].path`, `attachment`, `PDF` fields; skip if all null |
| `zotero-library.json` doesn't exist yet (user hasn't exported) | Graceful exit with setup instructions |
| Abstract field may contain Unicode or special chars that break jq | Use `ascii_downcase` which handles Unicode safely; jq handles UTF-8 natively |
| Very long abstracts slow jq test() matching | Truncate abstract to 2000 chars before matching (not just snippet) |
| BibTeX `file` field multi-path format (semicolons) may appear in CSL-JSON | Parse semicolon-separated paths as a fallback if `attachments` is absent |

---

## Appendix: Relevant File Paths

- Extension location: `/home/benjamin/.config/nvim/.claude/extensions/literature/`
- Manifest: `/home/benjamin/.config/nvim/.claude/extensions/literature/manifest.json`
- Target script: `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh`
- Reference (migration script): `~/Projects/Literature/scripts/migrate-from-repo.sh`
- Zotero BibTeX (for path format reference): `~/texmf/bibtex/bib/Zotero.bib`
- Zotero storage base: `~/Documents/Zotero/storage/`
- Central literature index: `~/Projects/Literature/index.json` (183 entries, v2 schema)
- Target library (to be created by user): `~/Projects/Literature/zotero-library.json`

## Appendix: CSL-JSON Field Reference

| BibTeX field | CSL-JSON field | Notes |
|---|---|---|
| `key` | `citation-key` | Better BibTeX cite key |
| `title` | `title` | Plain text, no LaTeX |
| `author` | `author` | Array of `{family, given}` |
| `year` | `issued["date-parts"][0][0]` | Nested array |
| `abstract` | `abstract` | Plain text |
| `journal` | `container-title` | For articles |
| `booktitle` | `container-title` | For chapters |
| entry type | `type` | `article-journal`, `book`, `chapter`, etc. |
| `file` | `attachments[].path` or `attachment` | PDF path(s) |
| `doi` | `DOI` | Uppercase key |
| `keywords` | `keyword` | Comma-separated string (not array) in CSL |
