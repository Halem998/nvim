# Research Report: Task #701

**Task**: 701 - Upgrade literature-retrieve.sh
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:30:00Z
**Effort**: 30 minutes
**Dependencies**: Task 697 (completed — provided the base rewrite this task upgrades)
**Sources/Inputs**:
- Codebase: `.claude/extensions/core/scripts/literature-retrieve.sh` (primary script to upgrade)
- Codebase: `.claude/scripts/literature-retrieve.sh` (sync copy)
- External: `/home/benjamin/Projects/cslib/specs/literature/index.json` (entries[] format, token_budget: 4000)
- External: `/home/benjamin/Projects/BimodalLogic/specs/literature/index.json` (entries[] format, token_budget: 40000)
- External: `/home/benjamin/Projects/cslib/specs/literature/blackburn_2001/index.json` (chapters[] format)
- External: `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997/index.json` (chapters[] format)
- External: `/home/benjamin/Projects/BimodalLogic/specs/literature/venema_1997/index.json` (chapters[] format)
- External: Multiple other subdirectory index.json files (all use chapters[] format)
**Artifacts**: specs/701_upgrade_literature_retrieve_script/reports/01_upgrade-lit-retrieve.md
**Standards**: report-format.md

---

## Executive Summary

- The TOKEN_BUDGET mismatch exists across projects: the script hardcodes `TOKEN_BUDGET=4000` but the BimodalLogic `index.json` declares `token_budget: 40000`; the cslib `index.json` declares `token_budget: 4000`. The fix is to read `token_budget` from the root `index.json` at runtime, with a fallback default of 8000.
- Subdirectory `index.json` files universally use a `chapters[]` array with a `file` field (not `path`), while the main `index.json` uses an `entries[]` array with a `path` field. Both share the same `keywords[]` and `token_count` structure, making unification straightforward.
- In the BimodalLogic project, `blackburn_2001/` has a subdirectory `index.json` but NO entries in the main `index.json`, meaning the current script silently misses the entire blackburn_2001 corpus (33+ chapters) in that project.
- The upgrade requires: (1) read `token_budget` from root `index.json`, (2) recursively discover and load subdirectory `index.json` files, (3) normalize `chapters[]` entries to the `entries[]` shape by remapping `file` -> `path` and prepending the subdirectory name, (4) merge all entries into one pool before scoring.
- Both scripts (`.claude/extensions/core/scripts/literature-retrieve.sh` and `.claude/scripts/literature-retrieve.sh`) are identical and must receive the same changes.

---

## Context & Scope

Task 697 rewrote `literature-retrieve.sh` from a naive file scanner to an index-based keyword selection system. That rewrite is now deployed. Task 701 upgrades the rewrite with three specific improvements identified from real-world usage across two projects (cslib and BimodalLogic):

1. **TOKEN_BUDGET configurability**: Different projects need different budgets. BimodalLogic's main index declares `token_budget: 40000` to accommodate large chapter files (some exceed 10,000 tokens each), but the hardcoded `TOKEN_BUDGET=4000` in the script overrides this.

2. **Recursive subdirectory merging**: Literature libraries are organized as hierarchical directories. Book-length works are split into subdirectories (e.g., `blackburn_2001/`, `chagrov_1997/`), each with their own `index.json`. The current script only reads the root `index.json`, missing subdirectory chapters entirely unless they happen to be listed in the root index.

3. **chapters[] format support**: Subdirectory `index.json` files use a different schema than the root index. The root uses `entries[]` with a `path` field; subdirectory files use `chapters[]` with a `file` field. The upgrade must normalize both into a common shape before scoring.

---

## Findings

### 1. TOKEN_BUDGET Mismatch Analysis

**Current state**: Script hardcodes `TOKEN_BUDGET=4000` on line 20. The root `index.json` has an optional `token_budget` field.

**Real values observed**:
- `cslib/specs/literature/index.json`: `"token_budget": 4000` (matches script — no bug here)
- `BimodalLogic/specs/literature/index.json`: `"token_budget": 40000` (10x larger — script uses 4000 but index says 40000)

**Root cause**: When BimodalLogic updated its index to use `token_budget: 40000` to accommodate large chapter files, the script was not updated to read this field. The script's hardcoded 4000 silently overrides the index's declared budget.

**Fix approach**: At script startup, after reading root `index.json`, extract `.token_budget // 8000` and use that as `TOKEN_BUDGET`. Fallback to 8000 (not 4000) since 4000 is too small for most literature files (the average chapter file is 5000-10000 tokens).

**Why 8000 as default**: The cslib main index declares 4000, but this was set when the index was first created. At 4000 tokens, most individual chapter files (average ~7000 tokens) exceed the entire budget individually, causing zero files to be selected. A default of 8000 allows at least 1-2 typical chapter files to be included, providing minimal useful context.

### 2. Subdirectory index.json Discovery

**Current state**: The script reads only `$LIT_DIR/index.json` (the root index). It does NOT scan for `*/index.json` subdirectory files.

**What exists in practice**:

In cslib (`/home/benjamin/Projects/cslib/specs/literature/`):
- Root `index.json`: 76 entries, all of which already reference subdirectory paths (e.g., `"path": "blackburn_2001/ch00_preface.md"`). The root index is the comprehensive catalog.
- 7 subdirectory `index.json` files exist: `blackburn_2001/`, `chagrov_1997/`, `church_1956/`, `gentzen_1935/`, `hughes_1996/`, `mendelson_2016/`, `zakharyaschev_2001/`
- **Relationship**: The root index entries overlap exactly with subdirectory chapters — the root index was hand-maintained to include all chapter-level entries.

In BimodalLogic (`/home/benjamin/Projects/BimodalLogic/specs/literature/`):
- Root `index.json`: 113 entries referencing subdirectory paths across 22 subdirectories.
- 23 subdirectory `index.json` files exist.
- **Key gap**: `blackburn_2001/` has a subdirectory `index.json` with 33 chapters but **zero entries in the root `index.json`**. The root index references `blackburn_2001/` entries for cslib but NOT for BimodalLogic — the BimodalLogic root index was not updated when blackburn_2001 was added.

**Implication**: Relying solely on the root `index.json` misses any subdirectory whose chapters were not manually added to the root. The upgrade must merge subdirectory `index.json` files to catch these cases.

**Deduplication strategy**: An entry from a subdirectory `index.json` may duplicate an entry already in the root `index.json` (cslib case). The merge should deduplicate by the normalized path: if both root and subdirectory claim the same file path, use root entry (gives summary field precedence). Or simpler: merge then deduplicate by `path` keeping the root entry.

### 3. chapters[] vs entries[] Format

**Root index.json** (`entries[]` format):
```json
{
  "entries": [
    {
      "id": "johansson_1937",
      "path": "johansson_1937.md",
      "title": "...",
      "token_count": 5653,
      "keywords": ["minimal logic", ...],
      "summary": "..."
    }
  ]
}
```

**Subdirectory index.json** (`chapters[]` format):
```json
{
  "book": "Modal Logic",
  "chapters": [
    {
      "id": "ch00",
      "file": "ch00_preface.md",       // <-- field name: "file"
      "title": "...",
      "token_count": 5801,
      "keywords": ["modal logic overview", ...]
      // no "summary" field
      // no "path" field
    }
  ]
}
```

**Normalization required**:
- `file` -> `path` (prepend `{subdir_name}/` to make it relative to `$LIT_DIR`)
- `chapters[]` -> `entries[]` array shape
- `summary` is absent in chapters — default to empty string `""`
- `id` stays as-is (may need prefix to avoid collision: `{subdir}_{id}`)

**Full normalization mapping** (for each subdirectory `{subdir}/index.json`):
```
path = "{subdir}/" + chapter.file
title = chapter.title
token_count = chapter.token_count
keywords = chapter.keywords
summary = ""  (absent from chapters format)
id = "{subdir}_{chapter.id}"  (or keep as-is if no collision risk)
score = computed during scoring pass
```

### 4. Unified Scoring Architecture

**Current flow**: Score entries from root `index.json` only, then select within budget.

**New flow**:
1. Read root `index.json` → extract `token_budget`, `entries[]`
2. Discover `*/index.json` files (all direct subdirectory indexes)
3. For each subdirectory `index.json`: extract `chapters[]`, normalize to entries shape (prepend subdir to path)
4. Merge: start with root entries, add subdirectory chapters not already in root (dedup by path)
5. Score unified pool by keyword overlap (same algorithm as current)
6. Select within TOKEN_BUDGET and MAX_FILES

**jq implementation strategy**: The scoring jq filter already handles `.entries // []`. The new version will need to operate on a pre-merged array. Since jq is not ideal for multi-file reads, the shell layer should:
1. Use `jq` on root index to extract token_budget and entries
2. Use a `find` + loop to collect subdirectory indexes
3. Use `jq` on each to extract chapters, normalized to entries shape
4. Concatenate all into a single JSON array (using `jq -s 'add'` or shell variable accumulation)
5. Pass unified array to the scoring jq filter

**Alternative**: A single jq call with `--slurpfile` for subdirectory indexes. But `--slurpfile` requires known filenames at call time, while subdirectory discovery is dynamic. Shell loop approach is simpler.

### 5. Edge Cases to Handle

1. **Subdirectory has index.json but no chapters[]**: Silently skip (use `.chapters // []` in jq)
2. **Root index.json has no entries[]**: Fall through to subdirectory-only merge
3. **No index.json anywhere**: Fall through to fallback file scan (unchanged behavior)
4. **chapters[] entry has no keywords**: Default to `[]` (same as current for entries)
5. **Duplicate paths**: Root entry wins during merge (root entries listed first, subdirectory entries appended only if path not seen)
6. **Very large token_budget (e.g., 40000)**: With many entries, the scored selection may include many files. MAX_FILES=10 cap still applies.

### 6. Files to Modify

Both scripts are identical and must be updated in sync:
- `.claude/extensions/core/scripts/literature-retrieve.sh` — primary (source of truth)
- `.claude/scripts/literature-retrieve.sh` — sync copy (byte-identical after update)

No other files need modification. The calling convention in 3 skills (skill-researcher, skill-planner, skill-implementer) remains unchanged.

---

## Decisions

- **Default TOKEN_BUDGET**: Use 8000 (not 4000) when `token_budget` is absent from root index. Rationale: 4000 is insufficient for typical chapter files; 8000 allows 1-2 chapters to be selected.
- **Deduplication**: Root index entries take precedence over subdirectory chapters when both reference the same path. Subdirectory chapters are appended after deduplication.
- **Subdirectory discovery depth**: Only scan direct subdirectories (`*/index.json`, not `**/index.json`). This matches the observed structure in both projects (no nesting beyond one level).
- **id collision**: Prefix subdirectory chapter ids with `{subdir}_` only if collision with root entry ids is possible. Since root entries typically use `author_year` format and subdir chapters use `ch00` etc., collision is unlikely but prefixing is safer.
- **token_budget field location**: Read from root `index.json` only. Subdirectory `index.json` files do not have a `token_budget` field (they are book-level, not project-level).

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Large token_budget (40000) causes very large output | MAX_FILES=10 cap limits output regardless of budget |
| Subdirectory index.json parsing fails | Wrap in `2>/dev/null` and use `// []` defaults |
| Path construction wrong for nested dirs | Normalize with `subdir_name + "/" + chapter.file` |
| jq performance with large merged arrays | 113+ entries is trivial for jq; no performance concern |
| Duplicate entries from root+subdir overlap | Sort merged array by path, dedup before scoring |

---

## Implementation Specification

The upgrade can be implemented in a single phase. The existing script structure (index path + fallback path) is preserved. Changes are localized to the index path section:

### Change 1: Read token_budget from root index.json

After confirming `$INDEX_FILE` exists, extract `token_budget` before scoring:

```bash
# Read token_budget from index.json, fallback to 8000
TOKEN_BUDGET=$(jq -r '.token_budget // 8000' "$INDEX_FILE" 2>/dev/null)
if ! [[ "$TOKEN_BUDGET" =~ ^[0-9]+$ ]]; then
  TOKEN_BUDGET=8000
fi
```

### Change 2: Recursive subdirectory index.json merging

After extracting root entries, discover and merge subdirectory chapters:

```bash
# Extract root entries
root_entries=$(jq '.entries // []' "$INDEX_FILE" 2>/dev/null)

# Discover subdirectory index.json files
sub_entries="[]"
while IFS= read -r sub_index; do
  subdir=$(basename "$(dirname "$sub_index")")
  # Normalize chapters[] to entries[] shape, prepend subdir to path
  sub_normalized=$(jq --arg subdir "$subdir" '
    .chapters // [] | map({
      id: ($subdir + "_" + .id),
      path: ($subdir + "/" + .file),
      title: (.title // .id),
      token_count: (.token_count // 0),
      keywords: (.keywords // []),
      summary: ""
    })
  ' "$sub_index" 2>/dev/null)
  if [ -n "$sub_normalized" ] && [ "$sub_normalized" != "null" ]; then
    sub_entries=$(echo "$sub_entries $sub_normalized" | jq -s 'add // []')
  fi
done < <(find "$LIT_DIR" -maxdepth 2 -name "index.json" ! -path "$INDEX_FILE" | sort)

# Merge: root entries first, then subdirectory entries not already in root
# Dedup by path (root wins)
all_entries=$(echo "$root_entries $sub_entries" | jq -s '
  (.[0] | map(.path) | unique) as $root_paths |
  (.[0]) + (.[1] | map(select(.path as $p | $root_paths | index($p) | not)))
')
```

### Change 3: Score unified pool

Replace `.entries // []` with the merged `$all_entries` variable in the scoring jq filter. Pass via `--argjson`:

```bash
scored_entries=$(echo "$all_entries" | jq --argjson kw "$keywords_json" '
  map(
    # ... same scoring logic as current ...
  ) | map(select(.score >= 1)) | sort_by(-.score)
')
```

---

## Context Extension Recommendations

- **Topic**: Literature index schema documentation
- **Gap**: No documentation exists for the `entries[]` vs `chapters[]` format distinction in `specs/literature/` index files.
- **Recommendation**: Task 703 (create literature organization guide) should document both schemas, the normalization contract, and when subdirectory indexes are appropriate.

---

## Appendix

### Search Queries Used
- `find /home/benjamin/ -path "*/literature*" -name "index.json"` — found index files in cslib and BimodalLogic
- `grep -r "token_budget\|TOKEN_BUDGET\|40000"` across `.claude/` — identified mismatch
- `python3` analysis of index.json files to count entries, check formats, identify overlap

### Key File Paths
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/literature-retrieve.sh` — primary script (167 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — sync copy (identical)
- `/home/benjamin/Projects/cslib/specs/literature/index.json` — entries[] format, token_budget: 4000, 76 entries
- `/home/benjamin/Projects/BimodalLogic/specs/literature/index.json` — entries[] format, token_budget: 40000, 113 entries
- `/home/benjamin/Projects/cslib/specs/literature/blackburn_2001/index.json` — chapters[] format, 33 chapters
- `/home/benjamin/Projects/BimodalLogic/specs/literature/blackburn_2001/index.json` — chapters[] format, 33 chapters (NOT in BimodalLogic main index)

### Scoring Algorithm (unchanged)
Current keyword scoring: tokenize description into lowercase words, remove stop words, filter length > 3, top 10. For each entry: count keyword matches in `entry.keywords[]` (kw_score) plus 1 bonus if any keyword appears in `entry.summary` (summary_bonus). Filter score >= 1, sort descending. Greedy select within TOKEN_BUDGET and MAX_FILES.

### Token Count Distribution (cslib)
- Smallest chapter: ~1600 tokens (venema_1997 sec03)
- Typical chapter: 5000-9000 tokens
- Largest chapter: ~70000 tokens (chagrov_1997 p01 — entire Part I)
- With TOKEN_BUDGET=4000: only ~0-1 files would typically be selected
- With TOKEN_BUDGET=8000: typically 1 file selected
- With TOKEN_BUDGET=40000: typically 4-8 files selected
