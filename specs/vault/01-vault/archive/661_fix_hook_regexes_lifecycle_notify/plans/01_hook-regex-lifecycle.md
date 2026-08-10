# Implementation Plan: Fix hook regexes and create lifecycle-notify.sh

- **Task**: 661 - Fix hook regexes and create lifecycle-notify.sh
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/661_fix_hook_regexes_lifecycle_notify/reports/01_hook-regex-lifecycle.md
- **Artifacts**: plans/01_hook-regex-lifecycle.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Three targeted fixes to support `/orchestrate N` in the WezTerm hook pipeline and create a missing bridge script. Fix 1 adds `orchestrate` to the task number extraction regex. Fix 2 adds `orchestrate` to the preflight status mapping (maps to `researching`). Fix 3 creates `lifecycle-notify.sh`, the bridge script that `orchestrator-postflight.sh` already references at line 306 for phase transition notifications.

### Research Integration

Research confirmed all three fixes are straightforward with known line numbers and exact changes. Both hook files exist as identical copies in `.claude/hooks/` and `.claude/extensions/core/hooks/` -- both copies must be updated. The `lifecycle-notify.sh` script does not exist anywhere and must be created from scratch. The interface contract is well-defined: accepts `STATUS` as arg 1 and optional `--quiet` as arg 2, calls `wezterm-notify.sh` always and `tts-notify.sh --lifecycle` in normal mode.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- `/orchestrate N` correctly sets `TASK_NUMBER` WezTerm user variable
- `/orchestrate N` immediately sets `CLAUDE_STATUS=researching` for tab coloring
- `orchestrator-postflight.sh` Stage 8b lifecycle notifications work end-to-end

**Non-Goals**:
- Wiring lifecycle-notify.sh into standalone command postflight (that is task 662)
- Changing WezTerm color schemes or adding new status colors
- Modifying orchestrator-postflight.sh itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension core copies drift from hooks copies | M | M | Update both paths in same phase, verify with diff |
| lifecycle-notify.sh path resolution fails | M | L | Use proven SCRIPT_DIR pattern consistent with other scripts |
| TTS or wezterm-notify.sh missing at runtime | L | L | Guard with -f checks, exit 0 on missing dependencies |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix hook regexes [COMPLETED]

**Goal**: Add `orchestrate` to both WezTerm hook scripts so `/orchestrate N` is recognized for task number extraction and preflight status setting.

**Tasks**:
- [x] Update `.claude/hooks/wezterm-task-number.sh` line 10 comment: add `|orchestrate` to the documented Tier 1a alternation
- [x] Update `.claude/hooks/wezterm-task-number.sh` line 46 regex: add `|orchestrate` to the alternation group `(research|plan|implement|revise|spawn|orchestrate)`
- [x] Update `.claude/hooks/wezterm-preflight-status.sh` lines 52-54 comment block: add `# /orchestrate N -> researching` line
- [x] Update `.claude/hooks/wezterm-preflight-status.sh`: add `elif` branch after line 64 for `orchestrate` mapping to `"researching"`
- [x] Copy updated `.claude/hooks/wezterm-task-number.sh` to `.claude/extensions/core/hooks/wezterm-task-number.sh`
- [x] Copy updated `.claude/hooks/wezterm-preflight-status.sh` to `.claude/extensions/core/hooks/wezterm-preflight-status.sh`
- [x] Verify both pairs are identical with `diff`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/wezterm-task-number.sh` - Add `orchestrate` to comment and regex
- `.claude/extensions/core/hooks/wezterm-task-number.sh` - Mirror changes
- `.claude/hooks/wezterm-preflight-status.sh` - Add `orchestrate` elif branch and comment
- `.claude/extensions/core/hooks/wezterm-preflight-status.sh` - Mirror changes

**Verification**:
- `diff .claude/hooks/wezterm-task-number.sh .claude/extensions/core/hooks/wezterm-task-number.sh` reports identical
- `diff .claude/hooks/wezterm-preflight-status.sh .claude/extensions/core/hooks/wezterm-preflight-status.sh` reports identical
- `grep -c 'orchestrate' .claude/hooks/wezterm-task-number.sh` returns 2 (comment + regex)
- `grep -c 'orchestrate' .claude/hooks/wezterm-preflight-status.sh` returns 2 (comment + elif)

---

### Phase 2: Create lifecycle-notify.sh [COMPLETED]

**Goal**: Create the missing bridge script that `orchestrator-postflight.sh` references at line 306 for lifecycle phase transition notifications.

**Tasks**:
- [x] Create `.claude/scripts/lifecycle-notify.sh` with the following behavior:
  - Accept `STATUS` as positional arg 1 (required, exit 0 if empty)
  - Accept optional `--quiet` as positional arg 2
  - Always call `.claude/hooks/wezterm-notify.sh STATUS` for tab color update
  - In normal mode (no `--quiet`): also call `.claude/hooks/tts-notify.sh --lifecycle STATUS`
  - Use `SCRIPT_DIR/../hooks/` path resolution pattern
  - Guard all external calls with `-f` checks
  - Use `set -uo pipefail` (no `-e` since we use `|| true` patterns)
  - Suppress stderr on external calls (`2>/dev/null || true`)
- [x] Make the script executable: `chmod +x .claude/scripts/lifecycle-notify.sh`
- [x] Verify the script runs without error: `bash .claude/scripts/lifecycle-notify.sh researched --quiet`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/lifecycle-notify.sh` - New file (create)

**Verification**:
- `test -x .claude/scripts/lifecycle-notify.sh` succeeds (executable)
- `bash .claude/scripts/lifecycle-notify.sh researched --quiet` exits 0 without error
- `bash .claude/scripts/lifecycle-notify.sh "" --quiet` exits 0 (empty status handled)
- Script contains `SCRIPT_DIR` path resolution and `wezterm-notify.sh` call

## Testing & Validation

- [x] Both hook file pairs are identical between `.claude/hooks/` and `.claude/extensions/core/hooks/`
- [x] `grep 'orchestrate' .claude/hooks/wezterm-task-number.sh` shows regex and comment hits
- [x] `grep 'orchestrate' .claude/hooks/wezterm-preflight-status.sh` shows elif and comment hits
- [x] `lifecycle-notify.sh` is executable and exits 0 when called with valid arguments
- [x] `lifecycle-notify.sh` exits 0 when called with empty arguments (graceful no-op)
- [x] `bash -n .claude/scripts/lifecycle-notify.sh` passes syntax check

## Artifacts & Outputs

- `specs/661_fix_hook_regexes_lifecycle_notify/plans/01_hook-regex-lifecycle.md` (this plan)
- `specs/661_fix_hook_regexes_lifecycle_notify/summaries/01_hook-regex-lifecycle-summary.md` (after implementation)

## Rollback/Contingency

All changes are to shell scripts with no build dependencies. Rollback via `git checkout` of the 4 modified hook files and deletion of the new `lifecycle-notify.sh` script. No database or state migration involved.
