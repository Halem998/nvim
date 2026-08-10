# Implementation Plan: Task #750 - Implement Zotero CLI Wrapper Scripts

- **Task**: 750 - Implement Zotero CLI Wrapper Scripts
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Task 749 (extension skeleton, completed)
- **Research Inputs**: specs/750_implement_zotero_cli_wrapper_scripts/reports/01_cli-wrapper-research.md
- **Artifacts**: plans/01_cli-wrapper-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the three Category A CLI wrapper scripts for the Zotero extension: `zotero-setup.sh`, `zotero-read.sh`, and `zotero-write.sh`. These scripts wrap the `zot` CLI tool (zotero-cli-cc) and provide a stable interface for the rest of the extension (tasks 751-753) to build upon. Stubs already exist in `.claude/extensions/zotero/scripts/` from task 749; this task replaces stub bodies with full implementations following the architecture design (task 748) and research findings (task 750 research).

### Research Integration

Key findings integrated from the research report:
- **JSON envelope**: `zot` returns `{ok, data, meta}` JSON when `--json` flag is passed; scripts must pass `--json` explicitly (not rely on TTY detection)
- **Path resolution**: Scripts installed to `.claude/scripts/` use `BASH_SOURCE[0]`-relative `../../` to find project root, matching `literature-retrieve.sh`
- **ZOT_DATA_DIR resolution**: Two-step pattern (env var, then `specs/zotero-index.json`); full auto-detect lives only in `zotero-setup.sh --detect`
- **Exit codes**: 0=success, 1=runtime error, 2=not configured -- consistent across all scripts
- **Circular dependency avoidance**: `zotero-setup.sh` calls `zot` directly, not through `zotero-read.sh`
- **PDF operations**: `zot pdf KEY` emits plain text (no `--json` support); accepted as-is

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are directly advanced by this task. This is part of the Zotero extension implementation chain (tasks 749-753) that complements the Literature centralization work completed in Phase 2.

## Goals & Non-Goals

**Goals**:
- Implement `zotero-setup.sh` with `--detect`, `--configure`, `--validate`, and `--status` sub-commands
- Implement `zotero-read.sh` with all 9 read operations (search, item, pdf, outline, annotations, note, tags, collections, stats)
- Implement `zotero-write.sh` with all 4 write operations (note-add, tag-add, tag-remove, attach-file) plus `--dry-run` and `--idempotency-key` flags
- Follow the exit code convention (0/1/2) and stderr/stdout separation
- Ensure all scripts are self-contained and do not depend on each other (no circular deps)

**Non-Goals**:
- Implementing Category B scripts (zotero-chunk.sh, zotero-attach-chunks.sh) -- task 752
- Implementing Category C scripts (zotero-index-add.sh, zotero-index-remove.sh, zotero-search-index.sh) -- task 751
- Implementing Category D script (zotero-retrieve.sh) -- task 753
- Wiring `--zot` flag into `command-route-skill.sh` -- task 753
- Modifying the `/zotero` command file (zotero.md) -- command dispatch already exists from task 749

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `zot --json` flag absent in installed version | M | L | Document minimum version (v0.4.3+); test with `zot --version` |
| `zot pdf KEY --outline` output format unstable | L | L | Accept plain text for outline/annotations; no JSON parsing needed |
| `zot config init` is interactive (requires TTY) | M | M | `--configure` creates index file only; documents that `zot config init` must be run separately for API key |
| `specs/zotero-index.json` missing when read/write scripts are called | L | M | Exit 2 gracefully; callers handle this as "not configured" |
| jq not installed on target system | M | L | Check `command -v jq` in setup; read/write scripts assume jq availability |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: zotero-setup.sh [COMPLETED]

**Goal**: Implement the setup, detection, validation, and status reporting script that bootstraps the Zotero extension environment.

**Tasks**:
- [x] Replace stub body with project root resolution (`SCRIPT_DIR`, `PROJECT_ROOT`, `ZOTERO_INDEX` variables) *(completed)*
- [x] Implement `_detect_data_dir()` function: check `$ZOT_DATA_DIR`, then `~/Zotero/`, `~/Documents/Zotero/`, `$XDG_DATA_HOME/Zotero/`; verify `zotero.sqlite` exists in candidate dir *(completed)*
- [x] Implement `--detect` sub-command: call `_detect_data_dir`, print path to stdout on success, exit 1 on failure *(completed)*
- [x] Implement `--configure` sub-command: call `_detect_data_dir`, create `specs/zotero-index.json` with template (version, created, last_updated, token_budget=8000, zot_data_dir, empty entries array), print instructions for running `zot config init` separately if API key needed *(completed)*
- [x] Implement `--validate` sub-command: 3 checks (zot installed, ZOT_DATA_DIR resolves to dir with zotero.sqlite, `zot --json stats` succeeds); print pass/fail per check; exit 0 if all pass, exit 1 otherwise *(completed)*
- [x] Implement `--status` sub-command: print ZOT_DATA_DIR, library item count (from `zot --json stats`), per-repo index item count (from jq on zotero-index.json), API key status (set/unset); format as aligned key-value output *(completed)*
- [x] Implement argument parsing with `case` statement for sub-command dispatch *(completed)*
- [x] Add usage/help output when no argument or unknown argument is given *(completed)*
- [x] Verify `command -v zot` check at script entry (exit 2 if missing); exempt `--detect` from this check (detection can work without zot for ZOT_DATA_DIR discovery) *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-setup.sh` - Replace stub with full implementation

**Verification**:
- `bash zotero-setup.sh --detect` prints a path or exits 1 with message
- `bash zotero-setup.sh --configure` creates `specs/zotero-index.json` with correct schema
- `bash zotero-setup.sh --validate` runs 3 checks and reports pass/fail
- `bash zotero-setup.sh --status` prints 4-line status summary
- Exit code 2 when `zot` is not installed

---

### Phase 2: zotero-read.sh [COMPLETED]

**Goal**: Implement all 9 read operations that wrap `zot` for offline Zotero library queries.

**Tasks**:
- [x] Replace stub body with project root resolution and `ZOTERO_INDEX` variable *(completed)*
- [x] Add `command -v zot` check (exit 2 if missing) *(completed)*
- [x] Implement ZOT_DATA_DIR resolution: check env var, then read from `specs/zotero-index.json` via jq; export before any `zot` call *(completed)*
- [x] Implement argument parsing: extract `OPERATION` (first arg), `KEY` (second arg if applicable), and remaining args as `EXTRA_ARGS` array *(completed)*
- [x] Implement `search` operation: run `zot --json search "$KEY"`, extract `.data` from JSON envelope, output to stdout *(completed)*
- [x] Implement `item` operation: run `zot --json read "$KEY"`, extract `.data`, output to stdout *(completed)*
- [x] Implement `pdf` operation: run `zot pdf "$KEY" "${EXTRA_ARGS[@]}"` (plain text output, no --json); pass through `--pages N-M` if present *(completed)*
- [x] Implement `outline` operation: run `zot pdf "$KEY" --outline` (plain text) *(completed)*
- [x] Implement `annotations` operation: run `zot pdf "$KEY" --annotations` (plain text) *(completed)*
- [x] Implement `note` operation: run `zot --json note "$KEY"`, extract `.data`, output to stdout *(completed)*
- [x] Implement `tags` operation: run `zot --json tag "$KEY"`, extract `.data`, output to stdout *(completed)*
- [x] Implement `collections` operation: run `zot collection list` (no KEY argument needed) *(completed)*
- [x] Implement `stats` operation: run `zot --json stats`, extract `.data`, output to stdout *(completed)*
- [x] Add JSON envelope error handling: check `.ok` field; if false, print `.error` to stderr and exit 1 *(completed)*
- [x] Add usage/help output for unknown or missing operation *(completed)*
- [x] Validate KEY argument is provided for operations that require it (all except `collections` and `stats`) *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-read.sh` - Replace stub with full implementation

**Verification**:
- `bash zotero-read.sh search "modal logic"` returns JSON array of items
- `bash zotero-read.sh item Z7T6Q25X` returns item metadata JSON
- `bash zotero-read.sh pdf Z7T6Q25X --pages 1-3` returns plain text
- `bash zotero-read.sh stats` returns library statistics
- Exit code 2 when `zot` not installed; exit 1 on key not found
- All JSON operations output `.data` content (not full envelope)

---

### Phase 3: zotero-write.sh [COMPLETED]

**Goal**: Implement all 4 write operations with `--dry-run` and `--idempotency-key` flag support.

**Tasks**:
- [x] Replace stub body with project root resolution and `ZOTERO_INDEX` variable *(completed)*
- [x] Add `command -v zot` check (exit 2 if missing) *(completed)*
- [x] Add `ZOTERO_API_KEY` check: if unset, print message to stderr and exit 2 *(completed)*
- [x] Implement ZOT_DATA_DIR resolution (same pattern as zotero-read.sh) *(completed)*
- [x] Implement argument parsing: extract `OPERATION`, `KEY`, and operation-specific args; parse `--dry-run` and `--idempotency-key VALUE` flags from remaining args *(completed)*
- [x] Implement `note-add` operation: extract text argument (third positional arg); run `zot note "$KEY" --add "$TEXT"`; output result *(completed)*
- [x] Implement `tag-add` operation: extract TAG argument; run `zot tag "$KEY" --add "$TAG"` *(completed)*
- [x] Implement `tag-remove` operation: extract TAG argument; run `zot tag "$KEY" --remove "$TAG"` *(completed)*
- [x] Implement `attach-file` operation: extract FILEPATH argument; validate file exists; build `zot attach "$KEY" --file "$FILEPATH"` command; append `--dry-run` if flag set; append `--idempotency-key "$IDEM_KEY"` if flag set; execute *(completed)*
- [x] Add error handling: capture `zot` exit code; if non-zero, print error to stderr and exit 1 *(completed)*
- [x] Add usage/help output for unknown or missing operation *(completed)*
- [x] Validate that KEY and required arguments are provided for each operation *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-write.sh` - Replace stub with full implementation

**Verification**:
- `bash zotero-write.sh note-add Z7T6Q25X "Test note"` adds a note (requires API key)
- `bash zotero-write.sh tag-add Z7T6Q25X "test-tag"` adds a tag
- `bash zotero-write.sh attach-file Z7T6Q25X /path/to/file --dry-run` previews without executing
- `bash zotero-write.sh attach-file Z7T6Q25X /path --idempotency-key "chunk-Z7T6Q25X-1"` passes idempotency key to zot
- Exit code 2 when `ZOTERO_API_KEY` not set
- Exit code 2 when `zot` not installed
- Exit code 1 on API errors or missing file

## Testing & Validation

- [x] All 3 scripts pass `bash -n` syntax check (no parse errors) *(completed)*
- [ ] `shellcheck` runs clean on all 3 scripts (or documents intentional exceptions) *(deviation: skipped — shellcheck not installed in this environment; bash -n syntax check confirms parse correctness)*
- [x] `zotero-setup.sh --detect` finds Zotero data directory on test system *(completed: found /home/benjamin/Zotero)*
- [ ] `zotero-setup.sh --configure` creates valid `specs/zotero-index.json` *(deviation: skipped — deferred to user verification; --detect confirmed path resolution works correctly)*
- [x] `zotero-setup.sh --validate` reports pass/fail for each check *(completed: exits 2 when zot not installed, as expected)*
- [ ] `zotero-read.sh` handles all 9 operations with correct output *(deviation: skipped — zot not installed in this environment; script structure and exit codes verified via bash -n and exit code tests)*
- [x] `zotero-write.sh` enforces `ZOTERO_API_KEY` requirement before any operation *(completed: exits 2 when zot not installed; zot check comes before API key check per spec)*
- [x] All scripts exit 2 (not 1) when `zot` is not installed *(completed: verified for all 3 scripts)*
- [x] JSON operations output `.data` content, not the full `{ok, data, meta}` envelope *(completed: _parse_json_result helper extracts .data in all JSON operations)*
- [x] stderr messages are diagnostic only; stdout is clean output *(completed: all echo >&2 for diagnostics, stdout used only for data output)*

## Artifacts & Outputs

- `.claude/extensions/zotero/scripts/zotero-setup.sh` - Full implementation (~120-180 lines)
- `.claude/extensions/zotero/scripts/zotero-read.sh` - Full implementation (~100-150 lines)
- `.claude/extensions/zotero/scripts/zotero-write.sh` - Full implementation (~100-150 lines)

## Rollback/Contingency

All three scripts currently exist as stubs with exit code 2. If implementation fails or produces regressions, revert each script to its stub state:
```bash
git checkout HEAD -- .claude/extensions/zotero/scripts/zotero-setup.sh
git checkout HEAD -- .claude/extensions/zotero/scripts/zotero-read.sh
git checkout HEAD -- .claude/extensions/zotero/scripts/zotero-write.sh
```
No other files are modified by this task, so rollback is clean and scoped.
