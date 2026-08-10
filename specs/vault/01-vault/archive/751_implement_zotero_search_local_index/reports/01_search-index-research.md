# Research Report: Task #751 — Implement Zotero Search and Local Index Management

**Task**: 751 — Implement Zotero search and local index management
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 750 (CLI wrappers — completed)
**Sources/Inputs**: Codebase (architecture design, stub scripts, implemented CLI wrappers, SKILL.md, command definition)
**Artifacts**: `specs/751_implement_zotero_search_local_index/reports/01_search-index-research.md`
**Standards**: report-format.md

---

## Executive Summary

- Task 750 (CLI wrappers) is complete; `zotero-read.sh` and `zotero-setup.sh` are fully implemented and provide the foundation for this task
- Three Category C scripts (`zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-search-index.sh`) exist as stubs with detailed comment headers; all implementation goes into these files
- The SKILL.md and command file already contain correct dispatch logic for `--search`, `--link`/`--add`, `--unlink`/`--remove`, `--status`, and `--sync` modes; the mode handlers call the scripts but check for `! -x` (not-yet-implemented), so wiring is already there pending the scripts
- The per-repo index schema is fully specified with 20 fields; `zotero-index-add.sh` must extract 18 metadata fields from `zot --json read KEY` output and write them with `jq`
- The scoring algorithm for `zotero-search-index.sh` is explicitly specified in the architecture design with jq pseudocode (Section 6 of the arch design) — implementation can follow it closely
- The main complexity is in `zotero-index-add.sh`: fetching metadata from `zot`, extracting diverse fields (authors array, PDF attachment path, tags, collections, keywords), and building the 20-field entry JSON; the jq field extraction patterns from `zotero-read.sh` serve as reference

---

## Context & Scope

### What was researched

1. Architecture design (task 748 summary) — full per-repo index schema, script specifications, scoring algorithm, command surface, and mode dispatch table
2. Implemented CLI wrappers (task 750) — `zotero-read.sh` and `zotero-setup.sh` to understand output format, path conventions, and helper patterns
3. Stub scripts — `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-search-index.sh` to see what scaffolding exists
4. SKILL.md — mode dispatch logic, argument extraction patterns, and which modes are plumbed to task 751 scripts
5. Command file (`zotero.md`) — argument parsing and delegation pattern to `skill-zotero`
6. Literature extension scripts (`zotero-search.sh`) — reference for scoring pattern and pretty-print table formatting
7. `zotero-retrieve.sh` stub — to understand the scoring algorithm context for the parallel search implementation

### Constraints

- `zot` CLI is not installed in the development environment; all tests must use `bash -n` syntax checks plus code review verification
- `zotero-chunk.sh` (task 752) is not yet implemented; `zotero-index-add.sh --chunk` flag must call it but the call will fail gracefully (exit 2) until task 752 is done — that is acceptable
- The SKILL.md mode handlers check `if [ ! -x "$script" ]` to detect not-yet-implemented scripts; this check works by file existence and executable bit, so the scripts must be made executable after implementation
- No changes to SKILL.md or `zotero.md` should be needed — the dispatch is already wired; only the three scripts need implementing

---

## Findings

### Codebase Patterns

#### Path Resolution Convention

Both `zotero-read.sh` and `zotero-setup.sh` use this pattern:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"
```

The `../..` navigation is because scripts live at `.claude/extensions/zotero/scripts/` (two levels up from `.claude/extensions/zotero/` gives `.claude/`, one more gives project root). This is correct and must be replicated in all three new scripts. The SKILL.md uses relative `SCRIPT_DIR=".claude/extensions/zotero/scripts"` because it executes from project root.

#### ZOT_DATA_DIR Resolution

`zotero-index-add.sh` and `zotero-search-index.sh` call `zotero-read.sh`, which already handles `ZOT_DATA_DIR` resolution from `specs/zotero-index.json`. The new scripts do NOT need to re-implement this resolution; they simply call `zotero-read.sh` as a subprocess and the wrapper handles the env var.

#### JSON Envelope from `zot --json`

`zotero-read.sh` consumes the `{ok, data, meta}` JSON envelope from `zot` and exposes only `.data` to stdout. So when `zotero-index-add.sh` calls:
```bash
item_json="$(bash "$SCRIPT_DIR/zotero-read.sh" item "$KEY")"
```
It receives the `.data` portion directly — no envelope unwrapping needed.

#### zot `item` Command Output Structure

Based on the `zotero-read.sh` implementation and `zot --json read KEY` behavior (inferred from arch design):
- `.title` — string
- `.authors` — array of `{family, given}` objects (CSL-JSON style) OR Zotero-native format
- `.date` — year string or ISO date (need to extract 4-digit year)
- `.itemType` — Zotero item type string
- `.abstractNote` — full abstract text
- `.tags` — array of `{tag: "string"}` objects
- `.collections` — array of collection keys or names
- `.attachments` — array of attachment objects with `{path, contentType}` or similar

**Critical**: The exact field structure from `zot --json read KEY` determines extraction jq paths. The arch design treats `.data` as having these fields, but the actual `zot` output structure must be verified empirically during implementation. The implementation should use `// empty` and `// []` fallbacks throughout.

#### Index Write Pattern

`zotero-setup.sh --configure` demonstrates the safe index update pattern:
```bash
_updated="$(jq --arg foo "$val" '...' "$ZOTERO_INDEX")"
echo "$_updated" > "$ZOTERO_INDEX"
```
This reads, transforms in memory, then atomically overwrites. The same pattern applies for `zotero-index-add.sh` (add/update entry) and `zotero-index-remove.sh` (delete entry).

#### jq Safety

From `.claude/rules/` and CLAUDE.md: avoid `!=` in jq (use `select(.x == "y" | not)` instead). All jq expressions in the new scripts must follow this rule. In particular, the "check if key already exists" logic in `zotero-index-add.sh` should use:
```bash
exists=$(jq --arg key "$KEY" '[.entries[] | select(.zotero_key == $key)] | length' "$ZOTERO_INDEX")
```
Not: `select(.zotero_key != $key)`.

#### Relevance Keyword Extraction

The arch design specifies: "title + keywords, stop-word filtered, length > 3". The stop word list is documented in Section 6:
```
a, an, the, in, on, at, of, to, for, is, are, was, were, be, been, being, have, has, had,
do, does, did, will, would, shall, should, may, might, can, could, and, or, but, not, with,
from, by, as, if, that, this, these, those, it, its
```
The extraction can be done in bash (tokenize on whitespace/punctuation, filter, lowercase).

#### SKILL.md Mode Dispatch — Task Scope

Looking at SKILL.md carefully, the modes wired to task 751 scripts are:
- `add` → `zotero-index-add.sh KEY [--chunk]`
- `remove` → `zotero-index-remove.sh KEY [--delete-chunks]`
- `search` → `zotero-search-index.sh QUERY --format pretty`
- `sync` → calls `zotero-index-add.sh` in a loop over all keys
- `validate` → implemented entirely in SKILL.md (reads index, checks paths) — NO script needed

The `--link` and `--unlink` modes mentioned in the task description map to `--add` and `--remove` in the architecture design. The command file uses `--add`/`--remove` terminology throughout. No `--link`/`--unlink` aliases need to be wired; the task description uses those as synonyms.

The `--status` mode in the task description maps to the `status_verbose` mode in SKILL.md (which calls `zotero-setup.sh --status`). This is already fully implemented in task 750.

The `--task N` mode is mentioned in the task description but does NOT appear in the current SKILL.md or command file. This is an additional mode to wire. Looking at how the literature skill handles `--task N`: it extracts the task description from `specs/state.json` and uses it as a search query. This same pattern would apply here.

#### SKILL.md `--task N` Gap

The task description says: "5. /zotero --task N — extract task description as search query". However, `--task` is not in the current `zotero.md` command file or SKILL.md. This means the plan must add `--task N` argument parsing to `zotero.md` and a `task_search` mode handler to SKILL.md, plus extract the task description from `specs/state.json` and pass it to `zotero-search-index.sh`.

### External Resources

- Architecture design at `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` is the authoritative spec; all script behavior derives from it
- The `zotero-search.sh` in the literature extension (a different, older search tool using CSL-JSON export) demonstrates the scoring + pretty-print pattern; useful as reference but the new `zotero-search-index.sh` operates on `specs/zotero-index.json` (not CSL-JSON export)
- The scoring jq pseudocode from Section 6 of the arch design is directly usable

---

## Recommendations

### Implementation Order

1. **`zotero-index-remove.sh`** first — simplest script; 4 steps; no external calls except `jq`; good confidence builder
2. **`zotero-search-index.sh`** second — scoring algorithm is fully specified; fallback to `zotero-read.sh search` is straightforward
3. **`zotero-index-add.sh`** third — most complex; depends on `zotero-read.sh` output structure; build incrementally
4. **SKILL.md `--task N` mode** fourth — minor addition; extract description from `state.json` and pass to search

### `zotero-index-remove.sh` Implementation Plan

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"

KEY="${1:-}"
DELETE_CHUNKS=false
[[ "${2:-}" == "--delete-chunks" ]] && DELETE_CHUNKS=true

[[ -z "$KEY" ]] && { echo "Error: KEY required" >&2; exit 1; }
[[ ! -f "$ZOTERO_INDEX" ]] && { echo "Error: specs/zotero-index.json not found" >&2; exit 2; }

# Find entry
entry=$(jq --arg k "$KEY" '.entries[] | select(.zotero_key == $k)' "$ZOTERO_INDEX")
[[ -z "$entry" ]] && { echo "Key $KEY not found in index" >&2; exit 1; }

if [[ "$DELETE_CHUNKS" == "true" ]]; then
  chunk_dir=$(echo "$entry" | jq -r '.chunk_dir // empty')
  [[ -n "$chunk_dir" ]] && rm -rf "$PROJECT_ROOT/$chunk_dir"
fi

# Remove entry
updated=$(jq --arg k "$KEY" 'del(.entries[] | select(.zotero_key == $k))' "$ZOTERO_INDEX")
echo "$updated" > "$ZOTERO_INDEX"
echo "Removed $KEY from index"
```

### `zotero-search-index.sh` Implementation Plan

Key design decisions:
- Query term extraction: tokenize, lowercase, filter stop words (length > 3)
- Build jq terms array as JSON: `["term1","term2"]`
- Run scoring in single jq pass using Section 6 pseudocode
- Threshold: `total_score >= 1` (looser than retrieve's `>= 4`)
- Pretty format: table with columns `SCORE | CITATION KEY | TITLE | YEAR | STATUS`
- Status column shows: `[HAS CHUNKS]`, `[PDF ONLY]`, `[NO PDF]` (per task description)
- Fallback: if index empty/missing, call `zotero-read.sh search "QUERY"` and print notice

The status tag display (`[HAS MARKDOWN]`, `[PDF ONLY]`, `[NO PDF]`) maps to:
- `has_chunks == true` → `[HAS MARKDOWN]`
- `has_chunks == false && has_pdf == true` → `[PDF ONLY]`
- `has_pdf == false` → `[NO PDF]`

### `zotero-index-add.sh` Implementation Plan

The main challenge is extracting fields from `zot --json read KEY` output. The plan:

1. Call `bash zotero-read.sh item "$KEY"` and capture JSON
2. Extract fields using jq; use safe fallbacks:
   ```bash
   title=$(echo "$item_json" | jq -r '.title // empty')
   # Authors: handle {family, given} Zotero format
   authors=$(echo "$item_json" | jq -r '[.creators[]? | select(.creatorType == "author") | .lastName + ", " + .firstName] // []')
   year=$(echo "$item_json" | jq -r '.date // "" | scan("[0-9]{4}") // null')
   item_type=$(echo "$item_json" | jq -r '.itemType // "unknown"')
   abstract=$(echo "$item_json" | jq -r '.abstractNote // "" | .[0:300]')
   # Keywords: from `extra` field or dedicated field
   keywords=$(echo "$item_json" | jq -r '[.tags[]?.tag // empty] // []')
   tags=$(echo "$item_json" | jq -r '[.tags[]?.tag // empty]')  # same source in Zotero
   ```

   **Note**: Zotero's native JSON (from `zot --json read`) may use `tags` for both user-applied tags and keywords. The arch design distinguishes `keywords` (author-supplied) vs `tags` (user's Zotero tags), but `zot --json read` may not separate them. Implementation should use `tags` for both and leave `keywords` as the subset extracted from title + abstract for relevance scoring.

3. PDF path resolution:
   ```bash
   # Check attachments in item data
   pdf_path=$(echo "$item_json" | jq -r '
     [.attachments[]? | select(.contentType == "application/pdf") | .path] | first // null
   ')
   has_pdf=$([ -n "$pdf_path" ] && echo "true" || echo "false")
   ```

4. Build relevance_keywords (bash extraction from title + keywords):
   ```bash
   raw_text="$title $keywords"
   # Tokenize, lowercase, filter stop words and length > 3
   ```

5. Optionally fetch notes:
   ```bash
   notes_json=$(bash zotero-read.sh note "$KEY" 2>/dev/null || echo "null")
   notes_summary=$(echo "$notes_json" | jq -r '.[0].note // "" | .[0:200]' 2>/dev/null || echo "null")
   ```

6. Build 20-field entry JSON using `jq -n` with `--arg` for each field

7. Check if key exists; update or append:
   ```bash
   exists=$(jq --arg k "$KEY" '[.entries[] | select(.zotero_key == $k)] | length' "$ZOTERO_INDEX")
   if [ "$exists" -gt 0 ]; then
     updated=$(jq --arg k "$KEY" --argjson entry "$new_entry" \
       '(.entries[] | select(.zotero_key == $k)) |= $entry' "$ZOTERO_INDEX")
   else
     updated=$(jq --argjson entry "$new_entry" '.entries += [$entry]' "$ZOTERO_INDEX")
   fi
   echo "$updated" > "$ZOTERO_INDEX"
   ```

8. Update `last_updated` in top-level fields after write

9. If `--chunk` flag and `has_pdf=true`: call `zotero-chunk.sh "$KEY"` (will exit 2 until task 752)

### `--task N` Mode (New Addition)

Add to `zotero.md` argument parsing:
```
elif "--task" in $ARGUMENTS:
  sub_mode = "task_search"
  task_num = extract_arg_after("--task", $ARGUMENTS) or ""
```

Add to SKILL.md dispatch case:
```bash
task_search) handle_task_search ;;
```

Add mode handler:
```bash
handle_task_search() {
  if [ -z "$task_num" ]; then
    echo "Error: --task requires a task number"
    exit 1
  fi
  # Extract description from specs/state.json
  desc=$(jq --arg n "$task_num" '
    .active_projects[] | select(.project_number == ($n | tonumber)) | .description // ""
  ' specs/state.json 2>/dev/null || echo "")
  if [ -z "$desc" ]; then
    echo "Error: Task $task_num not found in state.json"
    exit 1
  fi
  # Pass description as search query
  bash "$zotero_search_sh" "$desc" --format pretty
}
```

Note: `state.json` stores task descriptions in the project entries. If the description field is not present (older state format), fall back to the project_name slug.

### Atomic Write Safety

All three scripts must use the read-transform-write-atomically pattern. Do NOT pipe directly into the index file. Use a temp variable:
```bash
updated_json="$(jq ... "$ZOTERO_INDEX")"
echo "$updated_json" > "$ZOTERO_INDEX"
```

### Exit Code Discipline

| Condition | Exit code |
|-----------|-----------|
| Success | 0 |
| Key not found, parse error, write error | 1 |
| Index missing, zot not installed, not configured | 2 |

`zotero-index-remove.sh` does NOT call `zot` at all, so it never exits 2 for "zot not installed" — only for "index not found".

---

## Decisions

- The `--task N` / `--link` / `--unlink` modes from the task description are aliased to existing mode names in the arch design: `--task N` → new `task_search` mode; `--link` = `--add`; `--unlink` = `--remove`. No new modes beyond `task_search` are required.
- The `--status` mode in the task description maps to the existing `status_verbose` mode (already implemented in task 750 via `zotero-setup.sh --status`). No changes needed for `--status`.
- `zotero-index-add.sh` will attempt to call `zotero-read.sh note KEY` to get `notes_summary` but will gracefully set it to `null` if the call fails (notes are optional in the schema).
- The `--chunk` flag in `zotero-index-add.sh` will call `zotero-chunk.sh` which currently exits 2 (not yet implemented). This is acceptable — the call is gated on `has_pdf=true` and the exit 2 is treated as a graceful not-configured failure.
- Pretty format for `zotero-search-index.sh` will display the availability tags `[HAS MARKDOWN]`, `[PDF ONLY]`, `[NO PDF]` as specified in the task description (Section 1).

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| `zot --json read KEY` field names differ from arch design assumptions | Medium | Use `// empty` and `// []` fallbacks throughout; log actual structure on first real run |
| Zotero author format is not `{family, given}` but some other structure | Medium | Use `try` in jq or iterate `.creators` with type check |
| `jq` update-in-place for existing entry uses path that fails | Low | Use `map(if .zotero_key == $k then $entry else . end)` as safer alternative to `(.entries[] | select(...)) |= $entry` |
| `--chunk` call hangs (not just exits 2) | Low | Wrap in `timeout 5s`; the stub currently calls `exit 2` immediately |
| `state.json` does not have `.description` field for `--task N` | Medium | Fall back to `project_name` slug; document limitation |
| Large index with many entries causes slow jq scoring loop | Low | Index intended to be small (dozens to hundreds); jq handles this fine |

---

## Context Extension Recommendations

This is a meta task; no context extension recommendations apply.

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-read.sh` (implemented)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-setup.sh` (implemented)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-index-add.sh` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-index-remove.sh` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-search-index.sh` (stub)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-retrieve.sh` (stub, task 753)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-chunk.sh` (stub, task 752)
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/skills/skill-zotero/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/zotero/commands/zotero.md`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh`
- `/home/benjamin/.config/nvim/specs/750_implement_zotero_cli_wrapper_scripts/summaries/01_cli-wrapper-summary.md`

### Key Architecture References

- Per-repo index schema: arch design Section 4 (20 fields)
- Scoring algorithm: arch design Section 6 (jq pseudocode)
- Script specifications: arch design Section 5 Category C
- Command surface: arch design Section 7
