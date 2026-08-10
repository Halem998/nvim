# Teammate A Findings: Primary Implementation Approach

**Task**: 601 - Simplify WezTerm tab coloring and TTS notification pipeline
**Date**: 2026-05-22
**Angle**: Implementation approaches and patterns
**Confidence**: High

## Key Findings

### Bug 1: Tab Color Resets When Agent Is Invoked

**Root cause identified with high confidence.** The `claude-stop-notify.sh` Stop hook has subagent detection that checks for `agent_id` in stdin JSON (line 41):

```bash
AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_ID" ]]; then
    exit_success  # suppress for subagent stops
fi
```

However, the Stop hook fires not only for subagent stops but also for **orchestrator-level stops** between skill delegation turns. When the Skill tool returns to the orchestrator and before the orchestrator continues to postflight, the Stop hook fires for the main process. At this point:
- No signal file exists yet (postflight hasn't run)
- No `agent_id` in stdin (it's the main process)
- Falls through to `needs_input` path → **overwrites CLAUDE_STATUS**

Additionally, subagent stops handled by `SubagentStop` hook are a *different event* than Stop. The `Stop` hook fires for the main conversation agent at each turn boundary. The subagent detection in `claude-stop-notify.sh` only helps if the Stop hook JSON actually contains `agent_id`, which depends on how Claude Code populates the stdin JSON for Stop events.

**Key insight**: The dual-dispatch signal file architecture (task 588) was designed for the final Stop after postflight, but doesn't account for intermediate Stop events between turns of a multi-step orchestrator workflow.

### Bug 2: Random TTS Announcements During --team Research

**Root cause identified.** When `--team` research runs, each teammate's work triggers `update-task-status.sh` via the skill lifecycle. Looking at the flow:

1. Team skill sets up preflight (researching) — fires TTS "researching" via PHASE 5
2. Each teammate creates report files
3. If any intermediate status update happens (via `update-task-status.sh postflight`), it fires TTS

The real issue: `update-task-status.sh` PHASE 5 fires TTS unconditionally on ANY postflight call. If the team skill calls intermediate status updates or if individual teammates' completion triggers postflight-like behavior, multiple TTS announcements fire.

Additionally, the Stop hook fires between turns during synthesis, creating even more "Tab N" interactive announcements (since no signal file suppresses them).

### Bug 3: No Shaded-to-Bold Transition on Completion

**Root cause identified.** The `update-task-status.sh` PHASE 5 maps postflight statuses to **artifact-type vocabulary** instead of lifecycle vocabulary:

```bash
case "$target_status" in
  research)  WEZTERM_STATUS="report" ;;     # NOT "researched"
  plan)      WEZTERM_STATUS="plan" ;;       # same name, different semantics
  implement) WEZTERM_STATUS="summary" ;;    # NOT "completed"
esac
bash "$wezterm_script" "$WEZTERM_STATUS" &
```

In `wezterm.lua`, the artifact colors are:
- `report` → `#1a5a2a` (bright green)
- `plan` → `#1a2a5a` (bright blue)
- `summary` → `#5a4a1a` (dark gold)

While the lifecycle in-progress colors are:
- `researching` → `#2a4a2a` bg + `#808080` fg (dim green)
- `planning` → `#2a2a5a` bg + `#808080` fg (dim blue)
- `implementing` → `#3a3a1a` bg + `#808080` fg (dim yellow)

The transition is from dim green → bright green (similar hue), but the naming mismatch means the user sees "researching" go to "report" rather than "researched". The visual difference is subtle (mainly foreground brightness change). For `implement`, it goes from dim yellow to dark gold — barely distinguishable.

**The artifact-type vocabulary creates confusion and prevents the expected dim→bold transition pattern.**

### Bug 4: Color Should Persist Until New Non-Workflow Task

**Current behavior analysis**: CLAUDE_STATUS is cleared by:
1. `wezterm-preflight-status.sh` Tier 2: any non-lifecycle slash command → clears ✓ (correct)
2. `update-status` handler in wezterm.lua: switching to the tab → clears ✓ (problematic)
3. `claude-stop-notify.sh`: intermediate Stop events → sets to needs_input (incorrect)

Problem (2) is actually desired UX — when you switch to a tab, you've "seen" it. But problem (3) causes the color to vanish prematurely during workflows.

## Recommended Approach

### 1. Eliminate the Signal File Mechanism Entirely

**Replace with a workflow-active marker file.** Instead of using a signal file to suppress the Stop hook after postflight, use a "workflow-active" marker that persists for the entire workflow duration:

```bash
# .claude/tmp/workflow-active contains the current lifecycle state
# Written by: wezterm-preflight-status.sh (on lifecycle command)
# Updated by: update-task-status.sh postflight (on status transition)
# Consumed by: claude-stop-notify.sh (checked but NOT consumed during workflow)
# Cleared by: wezterm-preflight-status.sh Tier 2 (on non-lifecycle command)
```

The Stop hook becomes:
```bash
# If workflow-active file exists, this Stop is mid-workflow -> exit silently
if [[ -f "$WORKFLOW_ACTIVE_FILE" ]]; then
    exit_success
fi
# Otherwise, this is a true interactive stop -> fire needs_input + TTS
```

The workflow-active marker is cleared when:
- User submits a non-lifecycle slash command (Tier 2 in wezterm-preflight-status.sh)
- This replaces both the signal file AND the `wezterm-clear-status.sh` (which is now unused since `wezterm-preflight-status.sh` took over)

### 2. Merge to Single Lifecycle Vocabulary

**Eliminate**: `report`, `plan`, `summary`, `error` artifact-type states.

**Keep**: `researching`, `researched`, `planning`, `planned`, `implementing`, `completed`, `needs_input`, `blocked`.

**Changes needed**:

In `update-task-status.sh` PHASE 5, replace artifact mapping with direct lifecycle status:
```bash
# BEFORE (artifact-type vocabulary):
case "$target_status" in
  research)  WEZTERM_STATUS="report" ;;
  plan)      WEZTERM_STATUS="plan" ;;
  implement) WEZTERM_STATUS="summary" ;;
esac

# AFTER (lifecycle vocabulary):
bash "$wezterm_script" "$STATE_STATUS" &
# STATE_STATUS is already "researched", "planned", or "completed"
```

In `wezterm.lua`, remove the artifact-type color entries and make the lifecycle-completed colors more visually distinct from in-progress:

```lua
local status_colors = {
  needs_input  = { bg = "#3a3a3a", fg = "#d0d0d0" },  -- gray
  researching  = { bg = "#1a3a1a", fg = "#606060" },   -- dim green, dim fg
  researched   = { bg = "#1a5a1a", fg = "#e0e0e0" },   -- bright green, bright fg
  planning     = { bg = "#1a1a3a", fg = "#606060" },    -- dim blue, dim fg
  planned      = { bg = "#1a2a6a", fg = "#e0e0e0" },   -- bright blue, bright fg
  implementing = { bg = "#3a3a1a", fg = "#606060" },    -- dim yellow, dim fg
  completed    = { bg = "#2a5a1a", fg = "#e0e0e0" },    -- bright green-gold, bright fg
  blocked      = { bg = "#5a2a2a", fg = "#d0d0d0" },    -- dark red
  -- report, plan, summary, error -> REMOVED
}
```

The key visual distinction for dim→bold: change BOTH background brightness AND foreground brightness. Currently in-progress uses `#808080` fg; completed uses `#d0d0d0`. Making in-progress even dimmer (`#606060`) and completed brighter (`#e0e0e0`) creates a noticeable shift.

### 3. TTS Only at the Right Time

**Move TTS out of `update-task-status.sh`** entirely. `update-task-status.sh` should be a pure state management script — it updates state.json and TODO.md, nothing else.

**New architecture**:
- TTS fires from ONE place only: the skill/command postflight, AFTER artifact linking
- The postflight code directly calls `tts-notify.sh --lifecycle STATUS` after all state updates are done
- `update-task-status.sh` loses its PHASE 5 entirely
- For `--team` research, TTS fires ONCE after synthesis is complete, not per teammate

The Stop hook becomes simple:
```bash
# If workflow-active marker exists, exit silently
# If not, set needs_input wezterm color (NO TTS from Stop at all)
```

This eliminates:
- TTS from Stop hook (no more "Tab N" on every turn boundary)
- TTS from update-task-status.sh (no more intermediate announcements)
- The need for signal file suppression mechanism

TTS fires ONLY from:
1. Skill postflight (lifecycle announcements: "Tab N researched")
2. Notification hook (permission/elicitation: "Tab N")

### 4. TTY Discovery Consolidation

Create `.claude/hooks/wezterm-utils.sh` as a sourceable library:

```bash
#!/bin/bash
# Shared WezTerm utilities for hook scripts
# Source this file: source "$(dirname "$0")/wezterm-utils.sh"

# Get the TTY path for the current WezTerm pane
# Returns empty string if not in WezTerm or TTY unavailable
get_pane_tty() {
    if [[ -z "${WEZTERM_PANE:-}" ]]; then
        echo ""
        return 1
    fi
    local tty
    tty=$(wezterm cli list --format=json 2>/dev/null | \
        jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" 2>/dev/null || echo "")
    if [[ -z "$tty" ]] || [[ ! -w "$tty" ]]; then
        echo ""
        return 1
    fi
    echo "$tty"
}

# Set a WezTerm user variable via OSC 1337
# Usage: set_user_var VARIABLE_NAME "value"
set_user_var() {
    local var_name="$1"
    local var_value="${2:-}"
    local pane_tty
    pane_tty=$(get_pane_tty) || return 0
    local encoded
    encoded=$(echo -n "$var_value" | base64 | tr -d '\n')
    printf '\033]1337;SetUserVar=%s=%s\007' "$var_name" "$encoded" > "$pane_tty"
}

# Clear a WezTerm user variable
# Usage: clear_user_var VARIABLE_NAME
clear_user_var() {
    local var_name="$1"
    local pane_tty
    pane_tty=$(get_pane_tty) || return 0
    printf '\033]1337;SetUserVar=%s=\007' "$var_name" > "$pane_tty"
}
```

Then each hook script becomes much simpler:
```bash
# wezterm-notify.sh (simplified)
source "$(dirname "$0")/wezterm-utils.sh"
set_user_var "CLAUDE_STATUS" "${1:-needs_input}"
echo '{}'
```

This eliminates 6 copies of the TTY discovery boilerplate (wezterm-notify.sh, wezterm-clear-status.sh, wezterm-clear-task-number.sh, wezterm-preflight-status.sh, wezterm-task-number.sh, tts-notify.sh).

## Evidence/Examples

### Stop Hook Firing Timeline (Current - Broken)

```
T=0  User types: /research 601
     UserPromptSubmit → wezterm-preflight-status.sh → CLAUDE_STATUS=researching ✓

T=1  Orchestrator runs gate-in, invokes Skill tool
     (no hooks fire)

T=2  Skill spawns Agent tool (research agent)
     Agent works, writes report, returns to skill

T=3  Agent returns → Stop hook fires (main process turn boundary)
     claude-stop-notify.sh:
       - No agent_id in stdin (this is main process)
       - No signal file (postflight hasn't run)
       → Sets CLAUDE_STATUS=needs_input ✗ (OVERWRITES researching)
       → Fires TTS "Tab N" ✗ (unwanted)

T=4  Skill postflight runs update-task-status.sh
     → Writes signal file
     → Sets CLAUDE_STATUS=report (artifact type)
     → Fires TTS "Tab N researched"

T=5  Final Stop hook fires
     → Signal file consumed
     → Exits silently ✓
```

### Stop Hook Firing Timeline (Proposed - Fixed)

```
T=0  User types: /research 601
     UserPromptSubmit → wezterm-preflight-status.sh:
       → CLAUDE_STATUS=researching ✓
       → Creates .claude/tmp/workflow-active ✓

T=1  Orchestrator runs gate-in, invokes Skill tool
T=2  Skill spawns Agent, agent works, returns

T=3  Stop hook fires (main process turn boundary)
     claude-stop-notify.sh:
       → Checks workflow-active file → EXISTS → exit silently ✓

T=4  Skill postflight:
     → update-task-status.sh (state.json + TODO.md only, no notifications)
     → Calls wezterm-notify.sh "researched" → CLAUDE_STATUS=researched ✓
     → Calls tts-notify.sh --lifecycle "researched" → "Tab N researched" ✓
     → Updates workflow-active file content to "researched"

T=5  Final Stop hook fires
     → Checks workflow-active → EXISTS → exit silently ✓

T=6  User submits next prompt (non-workflow):
     UserPromptSubmit → wezterm-preflight-status.sh Tier 2:
       → Clears CLAUDE_STATUS ✓
       → Removes workflow-active ✓
```

### File Inventory (What Changes Where)

| File | Change | Copies |
|------|--------|--------|
| `wezterm-notify.sh` | Simplify using wezterm-utils.sh | 4 |
| `wezterm-clear-status.sh` | DELETE (replaced by wezterm-preflight-status.sh Tier 2) | 4 |
| `wezterm-preflight-status.sh` | Add workflow-active marker write/clear | 4 |
| `wezterm-task-number.sh` | Simplify using wezterm-utils.sh | 4 |
| `wezterm-clear-task-number.sh` | Simplify using wezterm-utils.sh | 4 |
| `claude-stop-notify.sh` | Replace signal mechanism with workflow-active check; remove TTS | 4 |
| `tts-notify.sh` | Remove lifecycle-notify references; keep --lifecycle mode | 4 |
| `lifecycle-notify.sh` | DELETE (already deprecated no-op) | 1 |
| `update-task-status.sh` | Remove PHASE 5 entirely | 1 |
| `wezterm-utils.sh` | CREATE (shared TTY discovery) | 4 |
| `wezterm.lua` | Remove artifact-type colors; brighten lifecycle colors | 1 |
| `wezterm-integration.md` | Update to reflect single vocabulary | 1 |
| `tts-stt-integration.md` | Update lifecycle-notify references | 1 |
| `neovim-integration.md` | Update hook flow diagrams | 1 |

**Total files changed**: ~14 files across 4 copy locations
**Total files deleted**: ~9 (wezterm-clear-status.sh × 4 + lifecycle-notify.sh × 1 + signal file mechanism)
**Total files created**: ~5 (wezterm-utils.sh × 4 + 1 shared script copy)

## Confidence Level

**High confidence** on root cause analysis for all three bugs.

**High confidence** on the workflow-active marker approach — it's simpler than the signal file and correctly handles multi-turn orchestrator workflows.

**High confidence** on vocabulary merge — the artifact-type vocabulary adds complexity without value, since lifecycle states already encode the needed information.

**Medium confidence** on exact wezterm.lua color values — the dim→bold transition needs real visual testing to pick optimal values. The structural approach (changing both bg and fg brightness) is sound, but specific hex values may need tuning.
