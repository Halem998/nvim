# Teammate B Findings: Alternative Approaches and Prior Art

**Task**: 601 - Simplify Notification Pipeline / Merge Vocabulary
**Date**: 2026-05-22
**Angle**: Alternative patterns, prior art, minimal architecture
**Confidence Level**: High

## Key Findings

### 1. Root Cause of Tab Color Reset

The Stop hook (`claude-stop-notify.sh`) fires when the **main orchestrator's turn ends** — including when it pauses to wait for Agent tool results. The sequence:

1. `UserPromptSubmit` fires `wezterm-preflight-status.sh` → sets `CLAUDE_STATUS=researching` (dim green)
2. Orchestrator runs `update-task-status.sh preflight` → state updated (no notifications)
3. Orchestrator spawns Agent(s) → **its turn stops** → **Stop hook fires**
4. `claude-stop-notify.sh` checks:
   - `agent_id` in stdin? **NO** (this is the main agent, not a subagent)
   - Signal file exists? **NO** (postflight hasn't run yet)
   - Falls through → fires `needs_input` wezterm + TTS
5. **CLAUDE_STATUS is overwritten from `researching` to `needs_input`** (gray)

This is the definitive bug. The Stop hook has no way to know the orchestrator is mid-workflow.

### 2. Dual Vocabulary Creates Invisible Transition

The postflight path in `update-task-status.sh` maps lifecycle states to artifact-type states before sending to wezterm:
- `research` → sends `report` to wezterm (not `researched`)
- `plan` → sends `plan` to wezterm (conflates with lifecycle `planned`)
- `implement` → sends `summary` to wezterm (not `completed`)

WezTerm has **12 color entries** across two vocabularies:

| Lifecycle State | BG Color | Artifact State | BG Color |
|-----------------|----------|----------------|----------|
| `researching` | `#2a4a2a` (dim) | — | — |
| `researched` | `#2a4a2a` (same bg!) | `report` | `#1a5a2a` |
| `planning` | `#2a2a5a` (dim) | — | — |
| `planned` | `#2a2a5a` (same bg!) | `plan` | `#1a2a5a` |
| `implementing` | `#3a3a1a` (dim) | — | — |
| `completed` | `#1a5a1a` | `summary` | `#5a4a1a` |

**Problem**: `researching` and `researched` have the **same background** (`#2a4a2a`), differing only in foreground dim (`#808080`) vs bright (`#d0d0d0`). But postflight sends `report` instead of `researched`, so the dim→bold foreground transition never happens. The user sees `researching` (dim green bg) → `report` (different bright green bg), which is a jarring jump rather than the expected dim→bold transition.

### 3. Team Research TTS Problem

During `--team` research, `update-task-status.sh postflight` is called only ONCE at the end (by the skill, not by teammates). **However**, the Stop hook fires when the orchestrator pauses between teammate dispatches and completions, and each such fire triggers a `needs_input` TTS announcement ("Tab N"). The user hears multiple "Tab N" announcements during the workflow, not just the final lifecycle announcement.

### 4. Signal File Mechanism Is Solving the Wrong Problem

The current signal file (`.claude/tmp/lifecycle-signal`) solves: "postflight already announced, so Stop hook shouldn't re-announce." But it doesn't solve: "orchestrator is mid-workflow, so Stop hook shouldn't announce at all." The signal file only exists **after** postflight completes. During the entire workflow (preflight → agent work → postflight), no signal file exists, and every Stop hook invocation falls through to `needs_input`.

## Alternative Approaches

### Alternative A: Workflow-Active File (Recommended)

Replace the signal file with a **workflow-active** file that persists for the entire workflow duration.

```
Created:  update-task-status.sh preflight (before any agents spawn)
Content:  {"status": "researching", "task": 601, "session": "sess_..."}
Read by:  claude-stop-notify.sh Stop hook
Behavior: If workflow-active exists → Stop hook skips ALL dispatch (no wezterm, no TTS)
Deleted:  update-task-status.sh postflight (after firing TTS + wezterm)
```

**Advantages**:
- Stop hook never fires `needs_input` during active workflow
- No race condition (file exists for full lifecycle)
- Replaces signal file entirely (simpler)
- Works for all workflow types (single-agent, team, multi-task)

**Implementation**: Change 2 scripts (update-task-status.sh + claude-stop-notify.sh), delete signal file logic.

### Alternative B: Unified Notification Script

Merge all notification logic into a single `claude-notify.sh`:

```bash
claude-notify.sh --preflight research   # Set CLAUDE_STATUS=researching
claude-notify.sh --postflight research  # Set CLAUDE_STATUS=researched + TTS
claude-notify.sh --stop                 # Conditional needs_input (check workflow-active)
claude-notify.sh --clear                # Clear CLAUDE_STATUS (prompt submit)
```

**Advantages**: Single source of truth for all notification logic; easier to reason about state transitions.
**Disadvantages**: Larger single file; UserPromptSubmit hooks need stdin parsing that differs from Stop hooks.

### Alternative C: Second WezTerm User Variable

Add `WORKFLOW_ACTIVE` user variable alongside `CLAUDE_STATUS`:

```lua
-- WezTerm Lua: skip clearing CLAUDE_STATUS if WORKFLOW_ACTIVE is set
if user_vars.WORKFLOW_ACTIVE == "1" then
  -- Don't clear on tab switch
end
```

**Disadvantages**: WezTerm CLI can't read user variables, so hooks can't check `WORKFLOW_ACTIVE` before deciding whether to fire. This approach only works in the WezTerm Lua handler, not in shell hooks.

## Minimal Hook Architecture

### Current Hook Count (notification-related)

| Hook Event | Scripts | Purpose |
|------------|---------|---------|
| UserPromptSubmit | wezterm-task-number.sh | Set task number |
| UserPromptSubmit | wezterm-preflight-status.sh | Set in-progress color or clear |
| Stop | claude-stop-notify.sh | Conditional needs_input + TTS |
| Notification | tts-notify.sh | Interactive TTS |
| (script call) | update-task-status.sh PHASE 5 | Lifecycle TTS + wezterm |
| (script call) | wezterm-notify.sh | Set any CLAUDE_STATUS |
| (dead code) | wezterm-clear-status.sh | Replaced by preflight-status |
| (dead code) | lifecycle-notify.sh | Deprecated no-op |

**Total**: 6 active scripts + 2 dead code scripts

### Proposed Minimal Architecture

| Hook Event | Scripts | Purpose |
|------------|---------|---------|
| UserPromptSubmit | wezterm-task-number.sh | Set task number |
| UserPromptSubmit | wezterm-preflight-status.sh | Set in-progress color or clear |
| Stop | claude-stop-notify.sh (simplified) | Conditional needs_input + TTS |
| Notification | tts-notify.sh | Interactive TTS |
| (script call) | update-task-status.sh PHASE 5 (simplified) | Lifecycle TTS + wezterm |
| (script call) | wezterm-notify.sh | Set any CLAUDE_STATUS |

**Reduction**: Delete wezterm-clear-status.sh and lifecycle-notify.sh (both dead). Simplify claude-stop-notify.sh (remove signal file logic, add workflow-active check). Simplify update-task-status.sh PHASE 5 (remove signal file write, add workflow-active delete).

### TTY Discovery Consolidation

5 scripts duplicate this ~6-line TTY discovery pattern:
```bash
PANE_TTY=$(wezterm cli list --format=json 2>/dev/null | \
    jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" 2>/dev/null || echo "")
if [[ -z "$PANE_TTY" ]] || [[ ! -w "$PANE_TTY" ]]; then
    exit_success
fi
```

Could extract to `.claude/scripts/wezterm-tty.sh` sourced by all hooks:
```bash
source "$(dirname "$0")/../scripts/wezterm-tty.sh"
# PANE_TTY is now set, or script has already exited
```

### Files Affected by Full Implementation

Hook copies exist in 4 locations:
1. `.claude/hooks/` (active hooks)
2. `.claude/extensions/core/hooks/` (extension source copies)
3. `.opencode/hooks/` (OpenCode copies)
4. `.opencode/extensions/core/hooks/` (OpenCode extension copies)

**Total files to update**: ~28 hook files + wezterm.lua + update-task-status.sh + wezterm-integration.md + tts-stt-integration.md + neovim-integration.md

## Prior Art Summary

| System | Approach | Relevant Pattern |
|--------|----------|-----------------|
| tmux | `monitor-activity` per window, auto-clears on focus | Binary state, terminal-managed clearing |
| iTerm2 | OSC 9 notifications, tab badges | No workflow state concept |
| WezTerm user vars | Set via OSC 1337, read in Lua | Our approach; can't read from CLI |
| POSIX bg jobs | `PROMPT_COMMAND` checks | Simple done/not-done |

The closest prior art to our needs is tmux's `monitor-activity`, but we need richer state (multiple lifecycle phases). The workflow-active file pattern is essentially a "session-scoped activity flag" that tmux manages implicitly but we must manage explicitly.

## Recommended Approach

**Alternative A (Workflow-Active File)** with vocabulary merge:

1. **Replace signal file with workflow-active file** in update-task-status.sh
2. **Merge vocabularies**: Eliminate artifact-type states (`report`, `plan`, `summary`, `error`). Use only lifecycle states (`researching`/`researched`/`planning`/`planned`/`implementing`/`completed`/`needs_input`/`blocked`).
3. **Fix dim→bold transition**: Make `researching` and `researched` use same hue but distinct brightness (both bg AND fg should differ visibly).
4. **Delete dead code**: wezterm-clear-status.sh, lifecycle-notify.sh
5. **Extract TTY discovery**: Shared function sourced by all hooks
6. **Update WezTerm Lua**: Remove artifact-type entries from status_colors table

This gives the simplest architecture while fixing all reported bugs.
