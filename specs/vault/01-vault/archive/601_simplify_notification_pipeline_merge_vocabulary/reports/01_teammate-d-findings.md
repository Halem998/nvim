# Teammate D Findings: Strategic Horizons

**Task**: 601 - Simplify Notification Pipeline / Merge Vocabulary
**Angle**: Long-term alignment, architectural strategy, scope risks
**Date**: 2026-05-22

## Key Findings

### 1. The Dual Vocabulary Is the Root of User-Facing Bugs

The current system has **two competing color vocabularies** in `update-task-status.sh` PHASE 5:

```bash
case "$target_status" in
  research)  WEZTERM_STATUS="report" ;;    # lifecycle -> artifact-type translation
  plan)      WEZTERM_STATUS="plan" ;;
  implement) WEZTERM_STATUS="summary" ;;
esac
```

This means the WezTerm tab transitions through: `researching` (preflight dim) -> `report` (postflight bright) instead of `researching` -> `researched`. The wezterm.lua handler maps both to similar greens but at different brightness/hue values (`#2a4a2a` vs `#1a5a2a`), making the dim-to-bold transition less visible than the intended `researching` -> `researched` pair (same bg `#2a4a2a` but fg `#808080` -> `#d0d0d0`).

**Eliminating the artifact-type vocabulary** directly fixes the "no dim-to-bold transition" bug by ensuring the same bg color is used throughout, with only the fg (dim vs bright) changing.

### 2. Tab Color Reset on Agent Spawn: A Stop Hook Timing Issue

The tab color resets when an agent is invoked because:

1. Preflight fires `wezterm-preflight-status.sh` on `UserPromptSubmit` -> sets `researching` (dim green)
2. The **orchestrator** (parent agent) does processing, then spawns a subagent
3. During agent work, the parent may "stop" (hand off to subagent) -- this fires the **Stop hook** (`claude-stop-notify.sh`)
4. The Stop hook checks for a signal file. If none exists (because postflight hasn't run yet -- we're still mid-workflow), it falls through to the **no-signal path** which sets `CLAUDE_STATUS=needs_input` (gray)

This is the fundamental race: the Stop hook doesn't know whether a stop is "I'm done with this turn but subagents are still working" vs "the entire workflow is done." The `agent_id` check in `claude-stop-notify.sh` only suppresses **subagent** stops, not the **parent orchestrator's** intermediate stops when it delegates to a skill.

### 3. Random TTS During --team Research: Per-Teammate Postflight Firing

Each teammate in `--team` mode runs `update-task-status.sh postflight` independently (via skill postflight). This fires TTS + WezTerm for every intermediate status transition, not just the final synthesis. The skill-team-research pattern calls `update-task-status.sh` once for the final postflight, but if any teammate skill invokes postflight status updates along the way, TTS fires for each one.

### 4. File Proliferation Is the Primary Maintenance Cost

There are **20 copies** of notification-related hook scripts across 4 locations:
- `.claude/hooks/` (5 files) -- primary
- `.claude/extensions/core/hooks/` (5 files) -- extension source
- `.opencode/hooks/` (10 files) -- OpenCode copies
- `.opencode/extensions/core/hooks/` (5 files) -- OpenCode extension source

Any change requires updating all 4 locations. This is the largest cost multiplier for this task and for all future notification work.

## Recommended Approach

### Strategic Alignment: Simplify First, Then Consolidate

The proposed simplification **aligns well** with the roadmap:
- The roadmap Phase 2 mentions "Extension hot-reload" -- a simpler notification system is easier to hot-reload
- The roadmap success metric "Zero stale references to removed files" directly benefits from fewer vocabulary terms to track

However, I recommend a **phased approach** different from what the task description proposes:

#### Phase A: Fix the Bugs (1 hour)
1. Fix the Stop hook race: add a "workflow-in-progress" marker file that the Stop hook checks before overriding color. Set on preflight, clear on postflight.
2. Suppress TTS in team mode except for the synthesis step: pass a `--suppress-tts` flag to `update-task-status.sh` that teammates use, or check for `.postflight-pending` marker before firing TTS.
3. Use lifecycle vocabulary (`researched`) instead of artifact-type (`report`) in PHASE 5 of `update-task-status.sh`.

#### Phase B: Eliminate Artifact-Type Vocabulary (30 min)
1. Remove `report`, `plan`, `summary`, `error` entries from `wezterm.lua`
2. Update `update-task-status.sh` PHASE 5 to use `$STATE_STATUS` directly
3. Update `wezterm-integration.md` to reflect lifecycle-only vocabulary

#### Phase C: Consolidate (1 hour)
1. Extract TTY discovery into a shared function in a common sourced file (e.g., `.claude/scripts/wezterm-common.sh`)
2. Symlink or source-copy the hook files to reduce the 4-location problem
3. Update all copies

### Scope Realism

The task estimates "2-3 hours" but lists 4 hook locations + extension copies + .opencode copies + documentation. Based on the 20-file count:
- **If done as a single pass**: 3-4 hours is more realistic
- **If phased**: Phase A (bug fixes) can land in 1 hour and provide immediate user value

### What NOT to Do

1. **Don't make notifications an extension**: The core notification pipeline is foundational infrastructure. Making it an extension adds loader complexity for zero user benefit.
2. **Don't add a terminal abstraction layer**: WezTerm is the only terminal with OSC 1337 user vars. An abstraction layer adds code with no second consumer.
3. **Don't switch to file-polling from WezTerm**: OSC 1337 user variables are the correct mechanism -- they're push-based, instant, and native to WezTerm's architecture. File polling would add latency and complexity.
4. **Don't event-source notifications**: The system is already event-driven via hooks. An event log would duplicate state without adding value.

### Future-Proofing Without Over-Engineering

The lifecycle vocabulary (`researching/researched/planning/planned/implementing/completed/needs_input/blocked`) is **sufficient and extensible**. If new states are ever needed (e.g., `reviewing`), they can be added to the same color map with a single line in `wezterm.lua` and the hook scripts. The current 8-state vocabulary covers the complete task lifecycle.

The `wezterm.lua` already has safe degradation for unknown values, so adding states is forward-compatible without touching WezTerm config first.

### Multi-Agent (--team) Strategic Consideration

The notification system should adopt a **batch-aware** pattern:
- **During team execution**: Suppress intermediate notifications entirely (TTS and tab color changes). The preflight `researching` color stays stable throughout.
- **After synthesis**: Fire a single `researched` notification (TTS + tab color transition).
- **This is already the intended pattern** in skill-team-research, but `update-task-status.sh` fires notifications on every postflight call indiscriminately.

The fix: add a `--quiet` flag to `update-task-status.sh` that skips PHASE 5 (notifications), used by intermediate team operations.

## Evidence/Examples

### Color Transition Evidence

Current broken transition (research flow):
```
UserPromptSubmit -> wezterm-preflight-status.sh -> CLAUDE_STATUS="researching" (dim green #2a4a2a, fg #808080)
... agent does work ...
Stop hook fires (no signal) -> CLAUDE_STATUS="needs_input" (gray #3a3a3a)  ← BUG: color reset
... more processing ...
update-task-status.sh postflight -> CLAUDE_STATUS="report" (bright green #1a5a2a)  ← different hue from "researched"
```

Desired transition:
```
UserPromptSubmit -> wezterm-preflight-status.sh -> CLAUDE_STATUS="researching" (dim green #2a4a2a, fg #808080)
... agent does work ... (no color change -- Stop hook suppressed during workflow)
update-task-status.sh postflight -> CLAUDE_STATUS="researched" (same green #2a4a2a, fg #d0d0d0)  ← dim-to-bold
... user sees it, switches tab or submits prompt -> CLAUDE_STATUS cleared
```

### Signal File Race Condition

```
t0: UserPromptSubmit -> preflight sets "researching"
t1: Skill spawns Agent
t2: Skill's "stop" fires (agent is running) -> claude-stop-notify.sh
t3: No signal file exists (postflight hasn't happened) -> sets "needs_input" ← BUG
t4: Agent finishes
t5: Postflight writes signal file + fires TTS + wezterm "report" ← already overridden
t6: Final Stop hook fires -> consumes signal, exits silently
```

The fix for t3: check for `.postflight-pending` marker in claude-stop-notify.sh. If it exists, suppress the needs_input fallback.

## Confidence Level

**High** for the bug analysis and phased approach recommendation. The root causes are clear from code inspection, and the fixes are mechanical.

**Medium** for the scope estimate. The 20-file update surface is well-defined but has historically taken longer than expected due to copy-paste divergence between locations.

**Low** for the "don't add abstractions" recommendation. If the user plans to support additional terminals beyond WezTerm in the future, an abstraction layer would be warranted -- but there's no evidence of that intention in the roadmap.
