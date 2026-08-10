# Implementation Plan: Upgrade literature-retrieve.sh

- **Task**: 701 - Upgrade literature-retrieve.sh
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 697 (completed -- provided the base rewrite)
- **Research Inputs**: specs/701_upgrade_literature_retrieve_script/reports/01_upgrade-lit-retrieve.md
- **Artifacts**: plans/01_upgrade-lit-retrieve.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Upgrade `literature-retrieve.sh` with three targeted improvements: (1) read `token_budget` from the root `index.json` instead of hardcoding 4000, with a fallback default of 8000; (2) recursively discover subdirectory `index.json` files and normalize their `chapters[]` format to the `entries[]` shape used by the root index; (3) merge all discoverable entries into a single pool before keyword scoring and greedy selection. Both copies of the script (extensions/core and scripts/) must be updated identically.

### Research Integration

The research report (01_upgrade-lit-retrieve.md) confirmed three issues across two real-world projects (cslib and BimodalLogic): the BimodalLogic root index declares `token_budget: 40000` but the script ignores it; BimodalLogic's `blackburn_2001/` subdirectory has 33 chapters in its local `index.json` but zero entries in the root index, causing the entire corpus to be silently missed; and subdirectory indexes uniformly use `chapters[]` with a `file` field rather than `entries[]` with a `path` field. The research provided complete jq snippets for normalization and merging, plus a recommended default of 8000 tokens (sufficient for 1-2 typical chapter files).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly reference literature-retrieve.sh. This task advances general infrastructure quality.

## Goals & Non-Goals

**Goals**:
- Make TOKEN_BUDGET configurable via `token_budget` field in root `index.json`, with 8000 fallback
- Discover and merge subdirectory `index.json` files (one level deep) into the scoring pool
- Normalize `chapters[]` format (file field) to `entries[]` shape (path field) with subdirectory prefix
- Deduplicate merged entries by path (root entries take precedence)
- Keep both script copies byte-identical after changes

**Non-Goals**:
- Multi-level recursive discovery (no `**/index.json`; only direct subdirectories)
- Changing the scoring algorithm itself (keyword overlap scoring is unchanged)
- Modifying caller skills (skill-researcher, skill-planner, skill-implementer) -- calling convention is unchanged
- Creating documentation for the index schema (separate task scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq parsing failure on malformed subdirectory index.json | M | L | Wrap all jq calls in `2>/dev/null` with `// []` defaults |
| Shell variable accumulation slow for many subdirectories | L | L | Real-world projects have < 30 subdirectories; trivial for jq |
| Duplicate entries inflate scored pool | M | M | Deduplicate by path after merge, root entries win |
| Large token_budget (40000) produces excessive output | M | L | MAX_FILES=10 cap still applies regardless of budget |
| Subdirectory path construction wrong (double slashes, missing prefix) | H | L | Test with real cslib/BimodalLogic literature directories |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Configurable TOKEN_BUDGET [COMPLETED]

**Goal**: Replace the hardcoded `TOKEN_BUDGET=4000` with dynamic reading from the root `index.json` token_budget field, falling back to 8000.

**Tasks**:
- [ ] In `.claude/extensions/core/scripts/literature-retrieve.sh`, change line 20 from `TOKEN_BUDGET=4000` to `TOKEN_BUDGET=8000` (set the new default)
- [ ] Inside the index path block (after `if [ -f "$INDEX_FILE" ]`), add token_budget extraction before keyword processing:
  ```bash
  # Read token_budget from index.json, fallback to default
  idx_budget=$(jq -r '.token_budget // empty' "$INDEX_FILE" 2>/dev/null)
  if [[ "$idx_budget" =~ ^[0-9]+$ ]]; then
    TOKEN_BUDGET="$idx_budget"
  fi
  ```
- [ ] Update the script header comment to reflect the new default (change `TOKEN_BUDGET=4000` to `TOKEN_BUDGET=8000 (or index.json token_budget)`)
- [ ] Verify the fallback path also uses the updated default (it does -- it reads `$TOKEN_BUDGET` which is now 8000)

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/literature-retrieve.sh` - Lines 12, 20, and insert after line 40

**Verification**:
- Script uses 8000 as default when no index.json exists
- Script reads token_budget from index.json when present
- Non-numeric or missing token_budget values fall back to 8000

---

### Phase 2: Subdirectory Discovery and chapters[] Normalization [COMPLETED]

**Goal**: Discover subdirectory `index.json` files, normalize their `chapters[]` arrays to the `entries[]` shape, and merge all entries into a single pool with deduplication.

**Tasks**:
- [ ] After extracting root entries from `$INDEX_FILE`, add subdirectory discovery using `find "$LIT_DIR" -maxdepth 2 -name "index.json" ! -path "$INDEX_FILE" | sort`
- [ ] For each discovered subdirectory `index.json`, extract `chapters[]` and normalize to entries shape:
  - Map `file` field to `path` with `{subdir}/` prefix
  - Preserve `title`, `token_count`, `keywords` fields
  - Default `summary` to empty string (chapters format lacks it)
  - Prefix `id` with `{subdir}_` to avoid collisions
- [ ] Extract root entries into a shell variable instead of reading inline in the jq scoring filter
- [ ] Merge root entries and subdirectory entries, deduplicating by `path` (root entries take precedence)
- [ ] Store the merged array in a variable (`all_entries`) for use by the scoring filter

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/scripts/literature-retrieve.sh` - Replace lines 60-83 with extracted root entries, subdirectory loop, merge logic, and refactored scoring

**Verification**:
- Subdirectory index.json files with `chapters[]` are discovered and normalized
- Paths are correctly prefixed with subdirectory name (e.g., `blackburn_2001/ch00_preface.md`)
- Duplicate entries (same path in root and subdirectory) are deduplicated with root winning
- Empty or malformed subdirectory indexes are silently skipped
- Projects with no subdirectory indexes continue to work (root-only case)

---

### Phase 3: Scoring Integration and Sync Copy [COMPLETED]

**Goal**: Wire the merged entry pool into the existing scoring filter and ensure both script copies are byte-identical.

**Tasks**:
- [ ] Refactor the scoring jq filter to operate on the `$all_entries` variable (passed via stdin or `--argjson`) instead of reading `.entries // []` from `$INDEX_FILE`
- [ ] Verify the selection filter uses the dynamically-set `$TOKEN_BUDGET` (already does via `--argjson budget "$TOKEN_BUDGET"`)
- [ ] Copy the updated script to `.claude/scripts/literature-retrieve.sh` using `cp`
- [ ] Run `diff` between the two copies to confirm they are byte-identical
- [ ] Test the complete script with a representative description string against a project that has subdirectory indexes (manual verification or dry-run)

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/scripts/literature-retrieve.sh` - Scoring filter refactoring (lines within the index path block)
- `.claude/scripts/literature-retrieve.sh` - Full copy of the updated script

**Verification**:
- Scoring operates on the merged pool (root + subdirectory entries)
- Selection respects the configurable TOKEN_BUDGET
- Both script copies are byte-identical (`diff` returns 0)
- Script exits 0 with content when matching entries exist
- Script falls through to fallback path when no index or no matches
- No regressions: projects without subdirectory indexes or without index.json at all continue to work

## Testing & Validation

- [ ] Script exits 1 when `specs/literature/` does not exist
- [ ] Script uses fallback default (8000) when no `index.json` exists
- [ ] Script reads `token_budget` from `index.json` when the field is present
- [ ] Script ignores non-numeric `token_budget` values and falls back to 8000
- [ ] Subdirectory `chapters[]` entries are normalized (file -> path with subdir prefix)
- [ ] Root entries take precedence over subdirectory entries with the same path
- [ ] Subdirectory entries not in root index are included in the merged pool
- [ ] Scoring and selection work correctly on the merged pool
- [ ] MAX_FILES=10 cap is respected regardless of TOKEN_BUDGET size
- [ ] Both copies of the script are byte-identical after all changes
- [ ] Projects with no subdirectory indexes work without regression
- [ ] The fallback path (no index.json) is unaffected by changes

## Artifacts & Outputs

- `plans/01_upgrade-lit-retrieve.md` (this file)
- `.claude/extensions/core/scripts/literature-retrieve.sh` (modified primary script)
- `.claude/scripts/literature-retrieve.sh` (sync copy, byte-identical)
- `summaries/01_upgrade-lit-retrieve-summary.md` (post-implementation)

## Rollback/Contingency

Both script files are tracked in git. If the upgrade introduces regressions:
1. `git checkout HEAD -- .claude/extensions/core/scripts/literature-retrieve.sh .claude/scripts/literature-retrieve.sh`
2. This restores the pre-upgrade version (task 697 rewrite) which works correctly for root-only index.json files
3. No caller changes are needed since the script interface (arguments, exit codes, stdout format) is unchanged
