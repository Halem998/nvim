# Research Report: Task #697

**Task**: 697 - Fix literature-retrieve.sh keyword matching
**Started**: 2026-06-14T12:00:00Z
**Completed**: 2026-06-14T12:30:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/scripts/literature-retrieve.sh` (current implementation)
- Codebase: `.claude/scripts/memory-retrieve.sh` (pattern to follow)
- Codebase: `.claude/extensions/core/manifest.json` (extension sync manifest)
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (Load Core sync mechanism)
- Codebase: `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md` (calling convention)
- External: `/home/benjamin/Projects/cslib/specs/200_fix_literature_directory_quality/reports/01_literature-quality-audit.md` (Priority 1 recommendation)
- External: `/home/benjamin/Projects/cslib/specs/literature/index.json` (reference schema)
**Artifacts**: specs/697_fix_literature_retrieve_keyword_matching/reports/01_literature-retrieve-research.md
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- **Manifest gap (root cause of deployment failure)**: `literature-retrieve.sh` is missing from `provides.scripts` in `.claude/extensions/core/manifest.json`, which means the Load Core sync mechanism filters it out during `<leader>al` sync -- the script never reaches child projects like cslib despite existing in the extension core scripts directory
- The current `literature-retrieve.sh` has 4 defects: `-maxdepth 1` misses subdirectory files, `description`/`task_type` arguments are captured but unused, no `index.json` integration, and alphabetical ordering instead of relevance-based selection
- A complete rewrite should follow the proven `memory-retrieve.sh` pattern: tokenize description into keywords, score `index.json` entries by keyword overlap, greedy-select within TOKEN_BUDGET, output `<literature-context>` block
- The calling convention is fixed across 3 skills and must not change: `bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null`
- When `index.json` is absent, the script must fall back to the current naive behavior (scan for small `.md`/`.txt` files) for backward compatibility with projects that have not created an index

## Context & Scope

Task 200 in the cslib project performed a quality audit of `specs/literature/` and identified 6 priority recommendations. Priority 1 -- creating a functional `literature-retrieve.sh` -- is the focus of this task. The cslib audit found the script already exists but has fundamental design limitations. In the nvim project, the script exists and is identical to the extension core copy. The script is called from 3 skills (skill-researcher, skill-planner, skill-implementer) with a fixed interface.

### Current Script Analysis

The current script (69 lines) does the following:
1. Accepts `description` and `task_type` as arguments (lines 19-20) but never uses them
2. Finds files with `find "$LIT_DIR" -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) | sort` -- only top-level files, alphabetical order
3. Iterates files, estimates tokens as `words * 1.3`, enforces TOKEN_BUDGET=4000 and MAX_FILES=10
4. Outputs `<literature-context>` block with file contents

### Calling Convention (must not change)

All 3 skills use identical invocation:
```bash
lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
```

The script must:
- Accept exactly 2 positional arguments: `$1` = description, `$2` = task_type
- Output to stdout on success (exit 0)
- Exit 1 with no output on failure/no-match

---

## Findings

### 0. Manifest Gap: Script Not Deployed to Child Projects (BLOCKING)

**Root cause**: `literature-retrieve.sh` exists in `.claude/extensions/core/scripts/` but is NOT listed in the `provides.scripts` array in `.claude/extensions/core/manifest.json`.

**How the sync works**: The Load Core mechanism (`<leader>al` in nvim, implemented in `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`) scans artifacts from the global directory. On line 832, it calls `sync_scan("scripts", "*.sh", true, nil, "scripts")` with `"scripts"` as the `filter_category`. When an allow-list exists for a category (which it does, since `core_provides` includes `provides.scripts`), only files in the allow-list are included (lines 760-784 of sync.lua). Since `literature-retrieve.sh` is absent from `provides.scripts` in the manifest, it gets filtered out.

**Evidence**:
- File exists: `.claude/extensions/core/scripts/literature-retrieve.sh` (confirmed)
- NOT in manifest: `grep "literature-retrieve" manifest.json` returns empty
- NOT deployed: `/home/benjamin/Projects/cslib/.claude/scripts/literature-retrieve.sh` does not exist
- 42 other scripts ARE listed in `provides.scripts` and ARE synced correctly
- `memory-retrieve.sh` IS listed in the manifest and IS synced to child projects

**Fix**: Add `"literature-retrieve.sh"` to the `provides.scripts` array in `.claude/extensions/core/manifest.json`. After adding, the next Load Core sync will deploy the script to all child projects.

**This is the primary blocker**: Even if the script quality is improved (defects 1-4 below), it will not reach child projects until the manifest is fixed.

### 1. Defect Analysis (4 defects from cslib audit)

**Defect 1: `-maxdepth 1` misses subdirectory files**
- Current: `find "$LIT_DIR" -maxdepth 1 -type f`
- Problem: Literature directories like `chagrov_1997/`, `church_1956/`, etc. contain chapter splits in subdirectories. These are never found.
- Fix: When using index.json, file discovery comes from index entries (which include subdirectory paths like `chagrov_1997/p01_introduction.md`). When falling back, remove `-maxdepth 1`.

**Defect 2: `description` and `task_type` captured but unused**
- Current: `description="${1:-}"` and `task_type="${2:-}"` are set on lines 19-20 but never referenced in selection logic
- Fix: Use description for keyword extraction and task_type for topic bonus scoring (following memory-retrieve.sh pattern)

**Defect 3: No index.json integration**
- Current: No awareness of `specs/literature/index.json`
- Fix: Read index.json, extract entries with keywords, score by keyword overlap against description
- Schema: Each entry has `id`, `path`, `token_count`, `keywords` (array of 6-10 strings), `summary`

**Defect 4: Alphabetical ordering instead of relevance**
- Current: `| sort` produces alphabetical order
- Fix: Sort by relevance score (keyword overlap + topic bonus), descending

### 2. memory-retrieve.sh Pattern Analysis

The `memory-retrieve.sh` script (168 lines) provides the proven pattern to follow:

**Keyword extraction** (lines 54-64):
```bash
# Extract keywords: lowercase, split on non-alpha, remove stop words, filter short words, deduplicate, top 10
STOP_WORDS="the|a|an|and|or|but|in|on|at|of|to|for|is|are|..."
keywords=$(echo "$combined_text" | \
  tr '[:upper:]' '[:lower:]' | \
  tr -cs '[:alpha:]' '\n' | \
  grep -v -E "^($STOP_WORDS)$" | \
  awk 'length > 3' | \
  sort -u | \
  head -10 | \
  tr '\n' ' ' | sed 's/ *$//')
```

**Scoring** (lines 74-101): jq-based scoring with:
- Keyword overlap count (case-insensitive match against entry keywords)
- Topic bonus (+2 for topic match, +1 for category match)
- Minimum score threshold (MIN_SCORE=1)
- Sort by descending score

**Greedy selection** (lines 109-119): jq reduce selecting entries within budget:
```bash
selected=$(echo "$scored_entries" | jq --argjson budget "$TOKEN_BUDGET" --argjson max "$MAX_ENTRIES" '
  reduce .[] as $entry (
    {selected: [], total_tokens: 0, count: 0};
    if .count < $max and (.total_tokens + $entry.token_count) <= $budget then
      .selected += [$entry] | .total_tokens += $entry.token_count | .count += 1
    else . end
  ) | .selected
')
```

**Key differences** for literature-retrieve.sh:
- TOKEN_BUDGET=4000 (vs 2000 for memory)
- MAX_FILES=10 (vs MAX_ENTRIES=5 for memory)
- No retrieval_count/last_retrieved tracking (literature index is static, not mutable)
- Literature index schema uses `keywords` array directly (no `topic`/`category` fields)
- Fallback to naive scan when index.json is missing (memory just exits)

### 3. index.json Schema Analysis

The `specs/literature/index.json` in cslib has 45 entries with this schema:

```json
{
  "version": 1,
  "token_budget": 4000,
  "max_chunks": 10,
  "entries": [
    {
      "id": "johansson_1937",
      "bib_key": "Johansson1937",
      "title": "Der Minimalkalkul...",
      "authors": "Ingebrigt Johansson",
      "year": 1937,
      "section": null,
      "path": "johansson_1937.md",
      "page_range": "119-136",
      "token_count": 5653,
      "keywords": ["minimal logic", "intuitionistic logic", "ex falso quodlibet", ...],
      "summary": "Defines minimal logic by removing..."
    }
  ]
}
```

Key observations:
- `path` is relative to `specs/literature/` (e.g., `johansson_1937.md` or `chagrov_1997/p01_introduction.md`)
- `keywords` array has 6-10 entries per file, average 7
- `token_count` is pre-computed (words * 1.3)
- Token counts range from 2,072 to 93,601; only 7 of 45 entries fit within the 4000-token budget individually
- Per-book subdirectories also have their own `index.json` files (not needed for retrieval -- the master index includes all entries)

### 4. Token Budget Implications

With TOKEN_BUDGET=4000 and typical chapter files at 10k-90k tokens, the scoring algorithm will naturally select the smaller files (scholarly reconstructions, front-matter sections) unless the token budget is raised. This is correct behavior -- the budget constrains what fits in the agent prompt.

The greedy selection (sorted by relevance, pick until budget exhausted) means:
- High-relevance small files get selected first
- Large files are skipped unless they are the only match and fit alone
- In practice, 1-3 files will be selected (most entries exceed 4000 tokens individually)

### 5. Scoring Algorithm Design

**Recommended scoring formula** (adapted from memory-retrieve.sh):

```
score = keyword_overlap_count + summary_match_bonus
```

Where:
- `keyword_overlap_count`: Number of extracted description keywords that appear in the entry's `keywords` array (case-insensitive)
- `summary_match_bonus`: +1 if any description keyword appears in the entry's `summary` field (provides additional signal)
- No `topic`/`category` bonus (literature index has no topic field; `task_type` could match against keywords but adds complexity for minimal benefit)

**Minimum score threshold**: MIN_SCORE=1 (same as memory-retrieve.sh) -- entries with zero keyword overlap are excluded.

### 6. Fallback Behavior Design

When `index.json` is absent, the script should fall back to the current naive behavior but with `-maxdepth 1` removed:

```bash
# Fallback: no index.json -- scan recursively for small files
find "$LIT_DIR" -type f \( -name "*.md" -o -name "*.txt" \) | sort
```

This ensures backward compatibility for projects that have a `specs/literature/` directory but no `index.json`. The token budget and MAX_FILES limits still apply in fallback mode.

### 7. Files to Modify

Two files must be updated (kept identical):
1. `.claude/scripts/literature-retrieve.sh` -- primary copy
2. `.claude/extensions/core/scripts/literature-retrieve.sh` -- extension core copy

Both are currently byte-identical (confirmed via `diff`).

---

## Decisions

1. **Fix manifest first**: Add `literature-retrieve.sh` to `provides.scripts` in the core extension manifest -- this is the blocking prerequisite for all other fixes
2. **Follow memory-retrieve.sh pattern**: The keyword extraction, jq-based scoring, and greedy selection pattern is proven and should be adapted for literature retrieval
3. **Do not mutate index.json**: Unlike memory-retrieve.sh which updates `retrieval_count` and `last_retrieved`, the literature index is static reference data -- no writes back
4. **Use MIN_SCORE=1**: Entries with zero keyword overlap should be excluded, same threshold as memory-retrieve.sh
5. **Remove `-maxdepth 1` in fallback**: Fallback mode should find files recursively to fix defect 1
6. **Keep calling convention unchanged**: The 2-argument interface (`$description` `$task_type`) must not change
7. **Token budget and max files remain constants**: TOKEN_BUDGET=4000 and MAX_FILES=10 are defined in the script header and match the index.json metadata
8. **Single canonical copy**: Edit `.claude/extensions/core/scripts/literature-retrieve.sh` as the source of truth, then copy to `.claude/scripts/literature-retrieve.sh` to maintain dual-file sync

---

## Risks & Mitigations

- **Risk**: jq unavailable on some systems
  - **Mitigation**: jq is required by the entire agent system (state.json, memory-retrieve.sh). Not a new dependency.

- **Risk**: Large index.json with many entries could slow scoring
  - **Mitigation**: The cslib index has 45 entries (largest known). jq processes this in milliseconds. No performance concern.

- **Risk**: Keyword extraction produces too-generic terms (e.g., "logic", "proof") matching many entries
  - **Mitigation**: The greedy budget selection naturally limits output to 4000 tokens regardless of match count. High-relevance entries sort first.

- **Risk**: No entries fit within TOKEN_BUDGET individually (all files > 4000 tokens)
  - **Mitigation**: This is expected for chapter-level files. The script correctly outputs nothing (exit 1) when no files fit. The calling skills handle empty lit_context gracefully.

- **Risk**: Forgetting to sync the extension core copy
  - **Mitigation**: Implementation plan should include explicit "copy to extensions/core" step with `diff` verification.

- **Risk**: Manifest fix alone does not verify the script works
  - **Mitigation**: Both fixes (manifest + rewrite) should ship together. The manifest fix enables deployment; the rewrite ensures correctness.

---

## Recommendations

1. **Add `literature-retrieve.sh` to core manifest** (BLOCKING):
   - Edit `.claude/extensions/core/manifest.json`
   - Add `"literature-retrieve.sh"` to the `provides.scripts` array (alphabetical position: after `"link-artifact-todo.sh"`, before `"manage-topics.sh"`)
   - This single-line fix unblocks deployment to all child projects

2. **Rewrite literature-retrieve.sh** with the following structure:
   - Phase 0: Validate directory exists
   - Phase 1: Check for index.json; if absent, use fallback path
   - Phase 2 (index path): Extract keywords from description, score entries via jq, greedy-select within budget
   - Phase 3: Read selected files, format `<literature-context>` block
   - Fallback path: Recursive find for `.md`/`.txt` files, apply token budget and MAX_FILES (current behavior minus `-maxdepth 1`)

3. **Implementation should be a single phase** -- the manifest fix is a one-line change; the script rewrite is ~100-120 lines total, straightforward adaptation of memory-retrieve.sh

4. **Test with cslib's index.json** to verify keyword matching against known entries before deployment

5. **Sync mechanism**: Edit the extension core copy first (`.claude/extensions/core/scripts/literature-retrieve.sh`), then copy to `.claude/scripts/literature-retrieve.sh` -- both must remain identical

---

## Appendix

### Script Interface Contract

```
Input:  $1 = task description (string, may be multi-word)
        $2 = task_type (string: general, meta, markdown, lean4, nix, neovim, etc.)
Output: stdout = <literature-context>...</literature-context> block (on success)
Exit:   0 = content emitted
        1 = no content (directory missing, no matches, or all entries exceed budget)
```

### Stop Words List (from memory-retrieve.sh)

```
the|a|an|and|or|but|in|on|at|of|to|for|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|could|should|may|might|can|shall|not|no|with|by|from|as|into|through|during|before|after|above|below|between|out|off|over|under|again|further|then|once|here|there|when|where|why|how|all|both|each|few|more|most|other|some|such|only|own|same|so|than|too|very|just|about|up|its|it|this|that|these|those|what|which|who|whom
```

### Proposed Script Outline

```bash
#!/usr/bin/env bash
# literature-retrieve.sh - Keyword-based literature injection from specs/literature/
# Phase 1: Score index.json entries by keyword overlap with description
# Phase 2: Greedy-select within TOKEN_BUDGET, read files, output <literature-context>
# Fallback: Recursive file scan when index.json is absent

set -euo pipefail

TOKEN_BUDGET=4000
MAX_FILES=10
MIN_SCORE=1

description="${1:-}"
task_type="${2:-}"

# Path setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
INDEX_FILE="$LIT_DIR/index.json"

# Exit if directory missing
[ -d "$LIT_DIR" ] || exit 1

# --- INDEX PATH (when index.json exists) ---
if [ -f "$INDEX_FILE" ]; then
  # Extract keywords from description
  STOP_WORDS="..." # (same list as memory-retrieve.sh)
  keywords=$(echo "$description $task_type" | ...)  # tokenize, deduplicate
  [ -z "$keywords" ] && exit 1
  keywords_json=$(echo "$keywords" | tr ' ' '\n' | jq -R . | jq -s .)

  # Score entries by keyword overlap
  scored_entries=$(jq --argjson kw "$keywords_json" '
    .entries // [] | map(
      . as $entry |
      ($entry.keywords // []) as $ekw |
      ([$kw[] | ascii_downcase] | map(
        . as $k |
        if ([$ekw[] | ascii_downcase] | index($k)) then 1 else 0 end
      ) | add // 0) as $score |
      { id: $entry.id, path: $entry.path, title: $entry.title,
        token_count: $entry.token_count, score: $score }
    ) | map(select(.score >= 1)) | sort_by(-.score)
  ' "$INDEX_FILE")

  # Greedy selection within budget
  selected=$(echo "$scored_entries" | jq --argjson budget "$TOKEN_BUDGET" --argjson max "$MAX_FILES" '
    reduce .[] as $entry (...) | .selected
  ')

  # Read files and output
  # (iterate selected, read full_path = LIT_DIR/entry.path, format output)
else
  # --- FALLBACK PATH (no index.json) ---
  # Recursive find, token budget enforcement, alphabetical
  files=($(find "$LIT_DIR" -type f \( -name "*.md" -o -name "*.txt" \) | sort))
  # (same loop as current script but without -maxdepth 1)
fi
```

### Key Differences from memory-retrieve.sh

| Aspect | memory-retrieve.sh | literature-retrieve.sh (proposed) |
|--------|-------------------|----------------------------------|
| Token budget | 2000 | 4000 |
| Max entries | 5 | 10 |
| Index location | `.memory/memory-index.json` | `specs/literature/index.json` |
| Fallback | Exit 1 | Recursive file scan |
| Mutates index | Yes (retrieval_count) | No |
| Topic bonus | +2 for topic, +1 for category | None (no topic field in schema) |
| Min score | 1 | 1 |
| Output tag | `<memory-context>` | `<literature-context>` |
