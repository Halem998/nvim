# Research Report: Task #750 — Implement Zotero CLI Wrapper Scripts

**Task**: 750 - Create shell scripts wrapping zot/zotero-cli-cc for the Zotero extension
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:45:00Z
**Effort**: ~45 minutes
**Dependencies**: Task 747 (CLI evaluation), Task 748 (architecture design), Task 749 (extension skeleton)
**Sources/Inputs**: Codebase (stubs, architecture docs, literature extension scripts, skill-base.sh)
**Artifacts**: specs/750_implement_zotero_cli_wrapper_scripts/reports/01_cli-wrapper-research.md
**Standards**: report-format.md

---

## Executive Summary

- All 9 Zotero CLI wrapper scripts exist as stubs in `.claude/extensions/zotero/scripts/` with correct shebang, `set -euo pipefail`, and detailed header comments — the scaffold is complete from task 749
- The architecture design (task 748) provides complete specifications for all scripts in Section 5 of the arch-design document; no gaps or TBDs remain for the 3 Category A scripts (task 750 scope)
- Task 750 scope is specifically **Category A** (zotero-read.sh, zotero-write.sh, zotero-setup.sh) plus the `/zotero --setup` and `/zotero --status` sub-modes; Category B/C/D scripts belong to tasks 752, 751, and 753 respectively
- The existing `literature-chunk.sh` (287 lines of Python-based chunking), `literature-retrieve.sh` (keyword scoring + token-budget selection), and `zotero-search.sh` provide mature patterns to reuse and adapt
- The `zot` CLI tool (zotero-cli-cc) uses a **stable JSON envelope** `{ok, data, meta}` on non-TTY stdout; scripts must detect pipe context (already guaranteed in agent invocation) or pass `--json` flag
- Exit code contract: 0=success, 1=runtime error, 2=not configured — this aligns exactly with graceful degradation needed for `zotero-retrieve.sh`
- The `/zotero` command file already exists and is complete; it delegates to `skill-zotero` which dispatches scripts; the `/zotero --setup` and `--status` sub-modes call `zotero-setup.sh` directly

---

## Context & Scope

### What Task 750 Covers

Task 750 implements **Category A: CLI Wrappers** per the architecture design Section 5:
1. `zotero-read.sh` — all 9 read operations (search, item, pdf, outline, annotations, note, tags, collections, stats)
2. `zotero-write.sh` — all 4 write operations (note-add, tag-add, tag-remove, attach-file) with --dry-run and --idempotency-key
3. `zotero-setup.sh` — 4 sub-commands (--detect, --configure, --validate, --status)

The remaining scripts are deferred:
- Tasks 751: zotero-index-add.sh, zotero-index-remove.sh, zotero-search-index.sh
- Task 752: zotero-chunk.sh, zotero-attach-chunks.sh
- Task 753: zotero-retrieve.sh

### Constraints

All scripts must:
- Use `#!/usr/bin/env bash` + `set -euo pipefail`
- Write diagnostics to stderr, output to stdout
- Implement the 3-code exit convention (0/1/2)
- Begin with `command -v zot &>/dev/null || { echo "..." >&2; exit 2; }` for Category A/B/C
- Set `ZOT_DATA_DIR` from `specs/zotero-index.json` when not already in environment
- Follow bash style matching existing extension scripts (no `local` outside functions)

---

## Findings

### Codebase Patterns

#### Stub State

All 9 stubs exist in `.claude/extensions/zotero/scripts/`:
- Header comments fully describe each script's interface
- All stubs exit with code 2 and a "not yet implemented" message
- The stubs have correct shebang and `set -euo pipefail`
- Implementation tags note which task implements each (`# Implementation: task 750`, etc.)

Only 3 stubs belong to task 750: `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`.

#### zot CLI Command Syntax (from task 747 research)

The `zot` tool (zotero-cli-cc) provides these operations relevant to Category A:

**Read operations (SQLite, offline)**:
```bash
zot --json search "query"          # Search by keyword
zot --json read KEY                 # Item metadata
zot pdf KEY                         # PDF full text
zot pdf KEY --pages N-M             # Page-range extraction
zot pdf KEY --outline               # Document outline
zot pdf KEY --annotations           # PDF annotations
zot --json note KEY                 # Notes (HTML -> Markdown)
zot --json tag KEY                  # Tags for item
zot collection list                 # Collection hierarchy
zot --json stats                    # Library statistics
```

**Write operations (Web API, requires ZOTERO_API_KEY)**:
```bash
zot note KEY --add "text"           # Add note
zot tag KEY --add "tag"             # Add tag
zot tag KEY --remove "tag"          # Remove tag
zot attach KEY --file /path/to/file # Upload attachment
```

**Config**:
```bash
zot config init                     # Prompts for API key
```

**JSON envelope** (when output is non-TTY or `--json` passed):
```json
{"ok": true, "data": {...}, "meta": {"request_id": "...", "cli_version": "0.4.3"}}
```
On error: `{"ok": false, "error": "...", "meta": {...}}`

The `--json` flag forces JSON output even on a TTY. Scripts should pass `--json` explicitly to guarantee structured output in all contexts.

**Dry-run and idempotency**:
```bash
zot attach KEY --file path --dry-run
zot attach KEY --file path --idempotency-key "chunk-KEY-N"
```

#### ZOT_DATA_DIR Handling Pattern

The architecture specifies reading `ZOT_DATA_DIR` from `specs/zotero-index.json` if not set in the environment. The correct pattern (derived from how literature-retrieve.sh handles LITERATURE_DIR):

```bash
# Resolve ZOT_DATA_DIR: env var > specs/zotero-index.json > auto-detect
_resolve_zot_data_dir() {
  if [[ -n "${ZOT_DATA_DIR:-}" ]]; then
    echo "$ZOT_DATA_DIR"
    return 0
  fi
  local index_file
  index_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/../../specs/zotero-index.json"
  # Normalize: script is at .claude/scripts/ (2 levels up from nvim root)
  # Project root relative path resolution
  local project_root
  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  local idx="$project_root/specs/zotero-index.json"
  if [[ -f "$idx" ]]; then
    local dir
    dir="$(jq -r '.zot_data_dir // empty' "$idx" 2>/dev/null)"
    if [[ -n "$dir" && -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  fi
  # Auto-detect fallback
  for candidate in "$HOME/Zotero" "$HOME/Documents/Zotero" "${XDG_DATA_HOME:-$HOME/.local/share}/Zotero"; do
    if [[ -d "$candidate" && -f "$candidate/zotero.sqlite" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}
```

**Important path note**: Scripts installed to `.claude/scripts/` are 2 levels below the project root (`.config/nvim/`). The `$project_root` must be resolved relative to `${BASH_SOURCE[0]}` using `../../`. The scripts are NOT in the extension directory during runtime — the extension loader copies them to `.claude/scripts/`.

#### Literature Extension Script Patterns

The `literature-chunk.sh` script provides the chunk pipeline already used by task 752. Key interface:

```bash
literature-chunk.sh <input.md> <output_dir> --doc-id <id>
# Output: {output_dir}/chunk_NNNN.md files + {output_dir}/chunks.json manifest
# stdout: chunk count (integer)
# stderr: progress messages
# exit 0 on success, 1 on error
```

The `literature-retrieve.sh` script provides the retrieval pattern:
- Reads project root via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../..`
- Uses jq for scoring; reads `specs/literature/index.json`
- Emits `<literature-context>...</literature-context>` block or exits 1 silently

The `zotero-search.sh` (in literature extension) provides the CSL-JSON keyword search pattern — stop word filtering, term escaping for jq regex, single-pass scoring.

#### skill-base.sh Patterns

`skill-base.sh` provides shared functions that can be sourced. However, Category A scripts do not need skill lifecycle functions — they are called as subprocess utilities, not skill entry points. The relevant pattern from skill-base.sh is just the extension directory resolution approach (`BASH_SOURCE[0]`-relative paths).

#### command-route-skill.sh and --zot Flag

The `command-route-skill.sh` does NOT yet parse `--zot`. That is task 753's responsibility. Task 750's scripts only need to work correctly when called directly by `skill-zotero` (which is called by the `/zotero` command). The `--zot` flag wiring into `/research`, `/plan`, `/implement` is a separate concern.

---

### zotero-setup.sh: Critical Design Details

#### --detect sub-command

Detection order per arch design Section 11:
1. `$ZOT_DATA_DIR` environment variable
2. `~/Zotero/`
3. `~/Documents/Zotero/`
4. `$XDG_DATA_HOME/Zotero/` (or `~/.local/share/Zotero/`)

Success criterion: found directory contains `zotero.sqlite`.

Output: resolved path to stdout on success; exit 1 with "not found" message if all fail.

#### --configure sub-command

Steps:
1. Run `--detect` to find data dir
2. Run `zot config init` if API key is needed (prompts interactively)
3. Create or update `specs/zotero-index.json` with `zot_data_dir` field
4. If `specs/zotero-index.json` doesn't exist: create with all required top-level fields + empty `entries`

The `specs/zotero-index.json` template (from arch design Section 4):
```json
{
  "version": "1.0",
  "created": "<ISO8601 timestamp>",
  "last_updated": "<ISO8601 timestamp>",
  "token_budget": 8000,
  "zot_data_dir": "<detected path>",
  "entries": []
}
```

#### --validate sub-command

Three checks:
1. `command -v zot` — is zot installed?
2. `$ZOT_DATA_DIR` resolves to a directory containing `zotero.sqlite`
3. `zot --json stats` succeeds (SQLite is readable)

Output: pass/fail lines per check; exit 0 if all pass, exit 1 with failure details.

#### --status sub-command

Required output fields:
- ZOT_DATA_DIR value
- Library item count (from `zot --json stats | jq .data.item_count`)
- Per-repo index item count (from `jq '.entries | length' specs/zotero-index.json`)
- Web API key status: "set" or "unset" (check `$ZOTERO_API_KEY`, never print value)

---

### zotero-read.sh: Operation Mapping

Each operation maps to a specific `zot` invocation:

| Operation | zot command | Notes |
|-----------|-------------|-------|
| `search "query"` | `zot --json search "query"` | Returns array of items |
| `item KEY` | `zot --json read KEY` | Full metadata JSON envelope |
| `pdf KEY [--pages N-M]` | `zot pdf KEY` or `zot pdf KEY --pages N-M` | Plain text (no --json) |
| `outline KEY` | `zot pdf KEY --outline` | May need --json check |
| `annotations KEY` | `zot pdf KEY --annotations` | May need --json check |
| `note KEY` | `zot --json note KEY` | HTML converted to Markdown by zot |
| `tags KEY` | `zot --json tag KEY` | JSON array of tags |
| `collections` | `zot collection list` | No KEY argument |
| `stats` | `zot --json stats` | No KEY argument |

**Argument parsing pattern** (to handle `--pages N-M` passthrough):

```bash
OPERATION="${1:-}"
KEY="${2:-}"
shift 2 2>/dev/null || shift "${#}" 2>/dev/null || true
EXTRA_ARGS=("$@")  # Capture remaining args (e.g., --pages 1-5)
```

---

### zotero-write.sh: Operation Mapping

| Operation | zot command | Notes |
|-----------|-------------|-------|
| `note-add KEY "text"` | `zot note KEY --add "text"` | Requires ZOTERO_API_KEY |
| `tag-add KEY TAG` | `zot tag KEY --add TAG` | Requires ZOTERO_API_KEY |
| `tag-remove KEY TAG` | `zot tag KEY --remove TAG` | Requires ZOTERO_API_KEY |
| `attach-file KEY FILEPATH` | `zot attach KEY --file FILEPATH` | + optional --dry-run, --idempotency-key |

**--dry-run passthrough**: Both the script flag and `zot`'s `--dry-run` flag exist. The script should detect `--dry-run` in its own args and pass it to `zot`.

**--idempotency-key handling**: Format is `"chunk-{KEY}-{N}"`. The script receives it as `--idempotency-key VALUE` and passes `--idempotency-key VALUE` to `zot attach`.

**ZOTERO_API_KEY check** (before any zot call):
```bash
if [[ -z "${ZOTERO_API_KEY:-}" ]]; then
  echo "ZOTERO_API_KEY not set; run /zotero --setup" >&2
  exit 2
fi
```

---

### Existing Script Pattern Analysis

The literature extension's `zotero-search.sh` script (180+ lines) provides the best model for bash scripting style in this project:
- Argument parsing with `for arg in "$@"` + `case` matching
- Stop word filtering with a string variable and inner loop
- jq program as a heredoc variable
- Cleanup via trap + temp file
- Pretty output formatting with printf column alignment

The `cite-extract.sh` shows the pattern for scripts with multiple output modes (`--format json|pretty`).

Neither `skill-base.sh` functions nor any special framework is needed for Category A scripts — they are simple bash wrappers around `zot`.

---

### Implementation Order Within Task 750

The three scripts have a natural dependency order:
1. **zotero-setup.sh** first — it creates `specs/zotero-index.json` and sets up the environment that all other scripts depend on
2. **zotero-read.sh** second — it wraps all read operations; needed by zotero-setup.sh `--status` and `--validate` (for `zot --json stats`)
3. **zotero-write.sh** third — independent of read; only dependency is ZOTERO_API_KEY and zot

However, these can be implemented in parallel since each is self-contained. The recommended implementation order for the plan is:
1. zotero-read.sh (all 9 operations)
2. zotero-write.sh (all 4 operations + flag handling)
3. zotero-setup.sh (all 4 sub-commands, calling zot directly for validate/status rather than through zotero-read.sh to avoid circular deps)

Note: `zotero-setup.sh --status` can call `zotero-read.sh stats` OR call `zot --json stats` directly. The design doc says zotero-setup.sh calls `zot --json stats` directly (it is itself a Category A CLI wrapper, not a consumer of zotero-read.sh). This avoids a circular dependency at initialization time (before data dir is fully configured).

---

### Project Root Path Resolution

This is the most important implementation detail for scripts installed to `.claude/scripts/`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

Scripts live at `{project_root}/.claude/scripts/`, so `$SCRIPT_DIR/../..` = `{project_root}`.

The index file is at `$PROJECT_ROOT/specs/zotero-index.json`.

**Verification**: `literature-retrieve.sh` uses exactly this pattern:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
```

Zotero scripts should use the same convention with `ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"`.

---

### ZOT_DATA_DIR Export Pattern

Every Category A script that calls `zot` must export ZOT_DATA_DIR before the zot call:

```bash
# Resolve and export ZOT_DATA_DIR if not already set
if [[ -z "${ZOT_DATA_DIR:-}" ]]; then
  if [[ -f "$ZOTERO_INDEX" ]]; then
    _detected_dir="$(jq -r '.zot_data_dir // empty' "$ZOTERO_INDEX" 2>/dev/null)"
    if [[ -n "$_detected_dir" && -d "$_detected_dir" ]]; then
      export ZOT_DATA_DIR="$_detected_dir"
    fi
  fi
  # If still unset: zot may auto-detect or fail; that's handled by zot's own error reporting
fi
```

This is simpler than a full auto-detect function in every script — the full auto-detect lives in `zotero-setup.sh --detect`. In read/write scripts, if neither env var nor index file sets ZOT_DATA_DIR, let `zot` fail naturally (it has its own auto-detection and error output).

---

## Decisions

- **zot --json flag**: Pass `--json` explicitly to all `zot` commands that should return JSON — do not rely on TTY detection. This ensures consistent JSON output when scripts are called from any context.
- **PDF operations without --json**: `zot pdf KEY` outputs plain text and does not support `--json`. Accept plain text output for `pdf`, `outline`, and `annotations` operations.
- **Project root resolution**: Use `BASH_SOURCE[0]`-relative `../../` from `.claude/scripts/`, matching `literature-retrieve.sh` exactly.
- **ZOT_DATA_DIR resolution**: Simple two-step: (1) check env var, (2) read from `specs/zotero-index.json`. No full auto-detect in read/write scripts — that complexity lives only in `zotero-setup.sh`.
- **Circular dependency avoidance**: `zotero-setup.sh` calls `zot` directly rather than through `zotero-read.sh` to avoid startup-time circular dependencies.
- **`zotero-setup.sh --configure` non-interactive mode**: Since `zot config init` is interactive (prompts for API key), `--configure` should call it only if the user explicitly requests it. The `--configure` sub-command detects data dir and creates the index; it optionally runs `zot config init` based on whether the user wants write access.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `zot --json` flag may not exist in older versions | Medium | Per task 747 research, v0.4.3+ supports --json; document minimum version requirement |
| `zot pdf KEY --outline` may not emit stable format | Low | Accept plain text for outline; no --json needed |
| Circular dep: zotero-setup.sh calling zotero-read.sh | Low | Have setup call zot directly; established in design |
| `specs/zotero-index.json` missing when scripts are called | Low | Scripts exit 2 gracefully; callers (skill-zotero) handle exit 2 as "not configured" |
| BASH_SOURCE[0] path resolution in edge cases | Low | Test with `bash ./script.sh` and `source script.sh`; BASH_SOURCE[0] is stable in both |
| `zot config init` is interactive (requires TTY) | Medium | `--configure` documents that `zot config init` must be run separately if API key needed; configure sub-command sets up index only |

---

## Context Extension Recommendations

- **Topic**: Zotero CLI wrapper patterns (ZOT_DATA_DIR resolution, JSON envelope handling)
- **Gap**: No documented patterns for wrapping `zot` in shell scripts; future agents implementing tasks 751-753 need these details
- **Recommendation**: After task 750 completion, add `.claude/context/project/zotero/patterns/cli-wrapper-patterns.md` with the ZOT_DATA_DIR resolution pattern and JSON envelope handling

- **Topic**: Extension script path resolution (`BASH_SOURCE[0]` -> project root)
- **Gap**: The `../../` pattern for scripts in `.claude/scripts/` is established by `literature-retrieve.sh` but not explicitly documented as a convention
- **Recommendation**: Add note to `.claude/context/guides/extension-development.md` or `.claude/context/architecture/context-layers.md`

---

## Appendix

### Files Read for This Research

- `specs/747_evaluate_zotero_cli_tools/reports/01_zotero-cli-eval.md` — zot CLI command surface, JSON envelope, exit codes, write-back strategy
- `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` — complete script specifications (Sections 5, 11), ZOT_DATA_DIR detection order, exit code contract
- `.claude/extensions/zotero/scripts/zotero-read.sh` — stub (confirms scope)
- `.claude/extensions/zotero/scripts/zotero-write.sh` — stub (confirms scope)
- `.claude/extensions/zotero/scripts/zotero-setup.sh` — stub (confirms scope)
- `.claude/extensions/zotero/scripts/zotero-chunk.sh` — stub (task 752, not in scope)
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` — stub (task 753, not in scope)
- `.claude/extensions/zotero/scripts/zotero-index-add.sh` — stub (task 751, not in scope)
- `.claude/extensions/zotero/scripts/zotero-index-remove.sh` — stub (task 751, not in scope)
- `.claude/extensions/zotero/scripts/zotero-search-index.sh` — stub (task 751, not in scope)
- `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` — stub (task 752, not in scope)
- `.claude/extensions/literature/scripts/zotero-search.sh` — mature bash style reference
- `.claude/extensions/literature/scripts/cite-extract.sh` — format flag pattern reference
- `.claude/scripts/literature-chunk.sh` — dependency for task 752; reviewed for interface
- `.claude/scripts/literature-retrieve.sh` — project root resolution pattern reference
- `.claude/scripts/skill-base.sh` — lifecycle framework (not needed for Category A scripts)
- `.claude/scripts/command-route-skill.sh` — --zot flag location (task 753 scope)
- `.claude/extensions/zotero/zotero.md` — /zotero command file (already complete)
- `.claude/extensions/zotero/manifest.json` — confirmed provides.scripts list

### Key Implementation Reference

**Project root pattern** (use in all 3 scripts):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"
```

**ZOT install check** (use in all 3 scripts):
```bash
if ! command -v zot &>/dev/null; then
  echo "zot not installed. Install via: uv tool install zotero-cli-cc" >&2
  exit 2
fi
```

**ZOT_DATA_DIR export** (use in zotero-read.sh and zotero-write.sh):
```bash
if [[ -z "${ZOT_DATA_DIR:-}" ]] && [[ -f "$ZOTERO_INDEX" ]]; then
  _dir="$(jq -r '.zot_data_dir // empty' "$ZOTERO_INDEX" 2>/dev/null)"
  [[ -n "$_dir" && -d "$_dir" ]] && export ZOT_DATA_DIR="$_dir"
fi
```

**JSON envelope parse** (for item/note/tags/stats/search):
```bash
_result="$(zot --json read "$KEY" 2>/dev/null)"
if [[ "$(echo "$_result" | jq -r '.ok')" != "true" ]]; then
  echo "zot error: $(echo "$_result" | jq -r '.error // "unknown"')" >&2
  exit 1
fi
echo "$_result" | jq -r '.data'
```
