# Research Report: Task #661

**Task**: 661 - Fix hook regexes and create lifecycle-notify.sh
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:00:00Z
**Effort**: Small (3 focused edits)
**Dependencies**: None
**Sources/Inputs**: Local config files
**Artifacts**: - specs/661_fix_hook_regexes_lifecycle_notify/reports/01_hook-regex-lifecycle.md
**Standards**: report-format.md

## Executive Summary

- Three changes needed: add `orchestrate` to two hook regex files, and create a missing `lifecycle-notify.sh` bridge script
- `wezterm-task-number.sh` Tier 1a regex (line 46) uses alternation `research|plan|implement|revise|spawn` — add `orchestrate` at end
- `wezterm-preflight-status.sh` Tier 1 matchers (lines 56-64) map three commands to statuses — add `orchestrate` mapping to `researching` (since orchestrate begins with research phase)
- `lifecycle-notify.sh` is referenced at line 306 of `orchestrator-postflight.sh` as `.claude/scripts/lifecycle-notify.sh`; it receives `$status` (a single positional arg) and should accept an optional `--quiet` flag
- Both hook files exist as identical copies in `.claude/hooks/` AND `.claude/extensions/core/hooks/` — both copies must be updated

## Context & Scope

Files researched:
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-task-number.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/hooks/wezterm-task-number.sh` (identical copy)
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-preflight-status.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/hooks/wezterm-preflight-status.sh` (identical copy)
- `/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh`
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-notify.sh`
- `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh`

`lifecycle-notify.sh` does NOT exist anywhere — confirmed by filesystem search.

## Findings

### Fix 1: wezterm-task-number.sh — Add `orchestrate` to Tier 1a

**File**: `.claude/hooks/wezterm-task-number.sh` (and `.claude/extensions/core/hooks/wezterm-task-number.sh`)

**Current state (line 46)**:
```bash
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research|plan|implement|revise|spawn)[[:space:]]+([0-9][0-9,' '-]*) ]]; then
```

**Change needed**: Add `|orchestrate` to the alternation group.

**New line 46**:
```bash
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research|plan|implement|revise|spawn|orchestrate)[[:space:]]+([0-9][0-9,' '-]*) ]]; then
```

The header comment (lines 9-14) also mentions the 3-tier logic listing `1a: /research|plan|implement|revise|spawn` — the comment at line 10 should also be updated to include `orchestrate`.

**Current comment (line 10)**:
```
#     1a: /research|plan|implement|revise|spawn + task spec (multi-task: N, N-N, N)
```

**Updated comment**:
```
#     1a: /research|plan|implement|revise|spawn|orchestrate + task spec (multi-task: N, N-N, N)
```

### Fix 2: wezterm-preflight-status.sh — Add `orchestrate` to Tier 1

**File**: `.claude/hooks/wezterm-preflight-status.sh` (and `.claude/extensions/core/hooks/wezterm-preflight-status.sh`)

**Current state (lines 52-64)**:
```bash
# Tier 1: Lifecycle commands -> set in-progress CLAUDE_STATUS
# /research N  -> researching
# /plan N      -> planning
# /implement N -> implementing
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research)[[:space:]]+ ]]; then
    STATUS_VALUE="researching"
    SHOULD_SET=1
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(plan)[[:space:]]+ ]]; then
    STATUS_VALUE="planning"
    SHOULD_SET=1
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(implement)[[:space:]]+ ]]; then
    STATUS_VALUE="implementing"
    SHOULD_SET=1
```

**Change needed**: Add an `elif` branch for `orchestrate` mapping to `researching`.

Rationale: `/orchestrate N` begins with the research phase (runs research -> plan -> implement). The initial in-progress status should be `researching` since that is the first phase it enters.

**New block (lines 52-68)**:
```bash
# Tier 1: Lifecycle commands -> set in-progress CLAUDE_STATUS
# /research N    -> researching
# /plan N        -> planning
# /implement N   -> implementing
# /orchestrate N -> researching (orchestrate begins with research phase)
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research)[[:space:]]+ ]]; then
    STATUS_VALUE="researching"
    SHOULD_SET=1
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(plan)[[:space:]]+ ]]; then
    STATUS_VALUE="planning"
    SHOULD_SET=1
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(implement)[[:space:]]+ ]]; then
    STATUS_VALUE="implementing"
    SHOULD_SET=1
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(orchestrate)[[:space:]]+ ]]; then
    STATUS_VALUE="researching"
    SHOULD_SET=1
```

### Fix 3: Create `.claude/scripts/lifecycle-notify.sh`

**Reference in orchestrator-postflight.sh (lines 303-309)**:
```bash
# Stage 8b: Lifecycle TTS notification (non-blocking, background)
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
  bash "$lifecycle_script" "$status" &
fi
```

**Interface contract**:
- Called with `$status` as the first positional argument (e.g., `researched`, `planned`, `completed`, `implemented`)
- Called from the working directory root (`.`) where `orchestrator-postflight.sh` is run
- Runs in background (`&`) so must be non-blocking
- Task description adds `--quiet` flag: suppress TTS, call wezterm-notify.sh only

**wezterm-notify.sh interface** (`.claude/hooks/wezterm-notify.sh`):
```bash
# Usage:
#   bash wezterm-notify.sh              # Sets CLAUDE_STATUS=needs_input
#   bash wezterm-notify.sh researched   # Sets CLAUDE_STATUS=researched
#   bash wezterm-notify.sh completed    # Sets CLAUDE_STATUS=completed
```
Takes one optional positional arg: the status value to set on CLAUDE_STATUS.

**tts-notify.sh interface** (`.claude/hooks/tts-notify.sh`):
```bash
# Usage:
#   tts-notify.sh --lifecycle STATUS    # Speaks "Tab N STATUS"
#   tts-notify.sh                       # Interactive mode, speaks "Tab N"
```
Takes `--lifecycle STATUS` for lifecycle announcements.

**Path considerations**: `orchestrator-postflight.sh` runs from the project root (`.`), so the hooks are at `.claude/hooks/wezterm-notify.sh` and `.claude/hooks/tts-notify.sh`. The script should use `SCRIPT_DIR` to locate sibling hooks.

**Recommended implementation**:

```bash
#!/bin/bash
# lifecycle-notify.sh — Bridge script for lifecycle phase transition notifications
#
# Called by orchestrator-postflight.sh Stage 8b after each research/plan/implement phase.
#
# Usage:
#   bash .claude/scripts/lifecycle-notify.sh STATUS           # wezterm + TTS
#   bash .claude/scripts/lifecycle-notify.sh STATUS --quiet   # wezterm only (no TTS)
#
# Arguments:
#   STATUS   Lifecycle status string (researched, planned, completed, etc.)
#   --quiet  Optional: suppress TTS, update tab color only
#
# Normal mode: calls wezterm-notify.sh + tts-notify.sh --lifecycle STATUS
# Quiet mode:  calls wezterm-notify.sh only (no TTS)
#
# Designed for mid-orchestrate phase transitions where quiet mode is used for
# intermediate phases (researched, planned) and full mode for final completion.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"

# Parse arguments
STATUS="${1:-}"
QUIET=0
if [[ "${2:-}" == "--quiet" ]]; then
    QUIET=1
fi

# Validate status argument
if [[ -z "$STATUS" ]]; then
    exit 0
fi

# Always call wezterm-notify.sh to update tab color
wezterm_script="$HOOKS_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" "$STATUS" 2>/dev/null || true
fi

# In quiet mode, skip TTS (used for mid-orchestrate phase transitions)
if [[ "$QUIET" -eq 1 ]]; then
    exit 0
fi

# Normal mode: call tts-notify.sh --lifecycle STATUS for audio announcement
tts_script="$HOOKS_DIR/tts-notify.sh"
if [[ -f "$tts_script" ]]; then
    bash "$tts_script" --lifecycle "$STATUS" 2>/dev/null || true
fi

exit 0
```

## Decisions

- `orchestrate` maps to `researching` initial status (not a new status like `orchestrating`) because it enters the research phase first and the existing vocabulary already covers all sub-phases
- `lifecycle-notify.sh` uses `SCRIPT_DIR/../hooks/` path pattern (consistent with `claude-stop-notify.sh` which uses `$SCRIPT_DIR/wezterm-notify.sh` where both are in hooks/)
- The `--quiet` flag is the second positional argument (not a named flag parsed with getopts) for simplicity, consistent with the minimal nature of the script
- Both `.claude/hooks/` and `.claude/extensions/core/hooks/` copies of the two hook files must be updated (they are currently identical)

## Risks & Mitigations

- **Risk**: The extension core copies drift from hooks copies if only one is updated.
  **Mitigation**: Implementation plan should update both paths for each file (4 edits total for fixes 1 and 2).

- **Risk**: `lifecycle-notify.sh` is called from the project root, but hooks live in `.claude/hooks/`. Using `SCRIPT_DIR/../hooks/` resolves correctly from `.claude/scripts/`.
  **Mitigation**: The path resolution in the recommended implementation mirrors the existing pattern in `claude-stop-notify.sh`.

- **Risk**: `orchestrate` appearing in Tier 2 (any other slash command) before being matched. Since the Tier 1a regex in `wezterm-task-number.sh` requires `[[:space:]]+([0-9]...)` after the command, any `/orchestrate` without a number would fall through to Tier 2 (CLEAR), which is correct behavior.

## Appendix

### Files Modified (Implementation)

| File | Change |
|------|--------|
| `.claude/hooks/wezterm-task-number.sh` | Line 10 comment + line 46 regex alternation |
| `.claude/extensions/core/hooks/wezterm-task-number.sh` | Same as above (identical copy) |
| `.claude/hooks/wezterm-preflight-status.sh` | Lines 52-53 comment + add elif branch after line 64 |
| `.claude/extensions/core/hooks/wezterm-preflight-status.sh` | Same as above (identical copy) |
| `.claude/scripts/lifecycle-notify.sh` | New file (create) |

### Key Line Numbers

- `wezterm-task-number.sh` comment: line 10
- `wezterm-task-number.sh` Tier 1a regex: line 46
- `wezterm-preflight-status.sh` Tier 1 comment block: lines 12-14 (header) and lines 52-54 (inline)
- `wezterm-preflight-status.sh` Tier 1 implement branch ends: line 64
- `orchestrator-postflight.sh` lifecycle-notify call: lines 306-309
