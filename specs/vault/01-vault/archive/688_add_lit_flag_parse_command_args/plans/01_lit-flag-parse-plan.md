# Implementation Plan: Add --lit Flag to parse-command-args.sh

- **Task**: 688 - Add --lit flag to parse-command-args.sh
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/688_add_lit_flag_parse_command_args/reports/01_lit-flag-parse.md
- **Artifacts**: plans/01_lit-flag-parse-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `LIT_FLAG` boolean variable to `parse-command-args.sh` following the established pattern used by `--clean`, `--force`, `--exploit`, and `--explore`. The change touches exactly two files (primary script and its extension core copy) with five insertions each: header comment, initialization, detection block, sed strip line, and export list update.

### Research Integration

The research report confirmed both copies of `parse-command-args.sh` are byte-for-byte identical and identified exact line numbers and patterns for all five insertion points. The flag follows the same three-part structure (init, detect, strip) as existing boolean flags.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `LIT_FLAG` variable exported as "true" or "false" based on `--lit` presence
- Strip `--lit` from `FOCUS_PROMPT` so it does not leak into downstream text
- Keep both copies of parse-command-args.sh in sync

**Non-Goals**:
- Wiring `LIT_FLAG` into downstream skills or context injection (separate task)
- Adding `--lit` to command documentation or help text (separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--lit` regex matches inside longer flags (e.g., `--literal`) | M | L | The `=~` regex is consistent with existing flags which also use substring matching; no `--literal` flag exists |
| Copies drift out of sync after edit | M | L | Apply identical edits to both files and verify with diff |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add --lit flag to both parse-command-args.sh files [COMPLETED]

**Goal**: Insert the LIT_FLAG variable following the established flag pattern in both copies of the script.

**Tasks**:
- [x] Add `LIT_FLAG` header comment after the `EXPLORE_FLAG` comment line (line 21) in `.claude/scripts/parse-command-args.sh` *(completed)*
- [x] Add `LIT_FLAG="false"` initialization after `EXPLORE_FLAG="false"` (line 73) *(completed)*
- [x] Add `--lit` detection block after the `--explore` detection block (after line 109) *(completed)*
- [x] Add `| sed 's/--lit//g' \` to the FOCUS_PROMPT sed chain before `| xargs)` (after line 123) *(completed)*
- [x] Append `LIT_FLAG` to the export line between `EXPLORE_FLAG` and `FOCUS_PROMPT` (line 132) *(completed)*
- [x] Apply the same five edits to `.claude/extensions/core/scripts/parse-command-args.sh` *(completed)*
- [x] Run `diff` to confirm both files are identical after edits *(completed: no diff output)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/parse-command-args.sh` - Add LIT_FLAG in 5 locations
- `.claude/extensions/core/scripts/parse-command-args.sh` - Mirror identical changes

**Verification**:
- `diff .claude/scripts/parse-command-args.sh .claude/extensions/core/scripts/parse-command-args.sh` returns no output
- `grep -c 'LIT_FLAG' .claude/scripts/parse-command-args.sh` returns 4 (comment, init, detect, export)

---

### Phase 2: Test flag parsing [COMPLETED]

**Goal**: Verify the parser correctly detects, exports, and strips `--lit` from arguments.

**Tasks**:
- [x] Source the script with `--lit` present and verify `LIT_FLAG` is "true" *(completed)*
- [x] Source the script without `--lit` and verify `LIT_FLAG` is "false" *(completed)*
- [x] Verify `--lit` is stripped from `FOCUS_PROMPT` when combined with focus text *(completed)*
- [x] Verify `--lit` works alongside other flags (`--team`, `--hard`, `--clean`) *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**: None (read-only testing)

**Verification**:
- `bash -c 'source .claude/scripts/parse-command-args.sh "688 --lit some focus"; echo $LIT_FLAG'` outputs "true"
- `bash -c 'source .claude/scripts/parse-command-args.sh "688 some focus"; echo $LIT_FLAG'` outputs "false"
- `bash -c 'source .claude/scripts/parse-command-args.sh "688 --lit review api"; echo $FOCUS_PROMPT'` outputs "review api" (no `--lit`)
- `bash -c 'source .claude/scripts/parse-command-args.sh "688 --lit --hard --clean"; echo "$LIT_FLAG $EFFORT_FLAG $CLEAN_FLAG"'` outputs "true hard true"

## Testing & Validation

- [x] Both script copies are byte-for-byte identical (diff check) *(completed)*
- [x] LIT_FLAG exports "true" when --lit is present *(completed)*
- [x] LIT_FLAG exports "false" when --lit is absent *(completed)*
- [x] --lit is stripped from FOCUS_PROMPT *(completed)*
- [x] --lit does not interfere with other flags *(completed)*

## Artifacts & Outputs

- `specs/688_add_lit_flag_parse_command_args/plans/01_lit-flag-parse-plan.md` (this plan)
- `.claude/scripts/parse-command-args.sh` (modified)
- `.claude/extensions/core/scripts/parse-command-args.sh` (modified, synced copy)

## Rollback/Contingency

Revert with `git checkout HEAD -- .claude/scripts/parse-command-args.sh .claude/extensions/core/scripts/parse-command-args.sh`. Both files are version-controlled and the changes are localized.
