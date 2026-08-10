# Research Report: Task #662

**Task**: 662 - wire_postflight_lifecycle_notifications
**Started**: 2026-06-11T18:00:00Z
**Completed**: 2026-06-11T18:15:00Z
**Effort**: Low (implementation-ready — code paths are clear)
**Dependencies**: Task 661 (completed — lifecycle-notify.sh now exists)
**Sources/Inputs**: orchestrator-postflight.sh, skill-base.sh, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md, wezterm-notify.sh, tts-notify.sh, claude-stop-notify.sh, wezterm-preflight-status.sh, update-task-status.sh, settings.json, wezterm.lua
**Artifacts**: - specs/662_wire_postflight_lifecycle_notifications/reports/01_wire-lifecycle-notify.md
**Standards**: report-format.md

---

## Executive Summary

- `lifecycle-notify.sh` already exists (task 661) and has a correct interface: `lifecycle-notify.sh STATUS` for full TTS+color, `lifecycle-notify.sh STATUS --quiet` for color-only.
- `orchestrator-postflight.sh` Stage 8b already calls `lifecycle-notify.sh "$status" &` (line 308) — **no quiet flag**. This is a bug: mid-orchestrate completions (research→planning, plan→implementing) should use `--quiet`; only the final completion should TTS.
- Standalone skills (skill-researcher, skill-planner, skill-implementer) each have Stage 8a that calls `lifecycle-notify.sh "$STATE_STATUS" &` — but `STATE_STATUS` is **never defined** in these skill files. This variable is local to `update-task-status.sh` and does not escape it. The lifecycle call is effectively a no-op (expands to empty string) for standalone flows.
- The `workflow-active` marker is written by `update-task-status.sh preflight` but is **never cleared** by any postflight script. It is only cleared by `wezterm-preflight-status.sh` Tier 2 (next slash command) or on the ESC edge case. This means the Stop hook will suppress `needs_input` color until the user types another slash command — which is likely intentional for orchestrate but potentially undesirable for standalone flows.
- The `wezterm.lua` color table distinguishes dim in-progress (researching/planning/implementing) from bright completed (researched/planned/completed) already — the infrastructure is all present.

---

## Context & Scope

Task 661 created `lifecycle-notify.sh` as a bridge script that calls `wezterm-notify.sh STATUS` and optionally `tts-notify.sh --lifecycle STATUS`. This task (662) wires it correctly into both the standalone command flow and the orchestrate flow.

The key distinction to implement:
- **Orchestrate mid-phase transition** (e.g., research done → start planning): `--quiet` (dim color of next phase, no TTS)
- **Orchestrate final completion** OR **standalone command completion**: Full mode (bright color + TTS)

---

## Findings

### Finding 1: orchestrator-postflight.sh — Current Stage 8b

```bash
# Lines 306-309 in orchestrator-postflight.sh
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
  bash "$lifecycle_script" "$status" &
fi
```

**Problem**: This always calls without `--quiet`, regardless of whether this is a mid-orchestrate transition or the final completion. Every intermediate phase completion (researched, planned) will produce TTS speech, which is noisy during /orchestrate runs.

**Fix required**: Need to distinguish final from mid-orchestrate transitions. The key insight from the orchestrate state machine: `orchestrator-postflight.sh` is only called by standalone skills (researcher, planner, implementer) — it is NOT called by skill-orchestrate directly. Instead, skill-orchestrate reads the `.orchestrator-handoff.json` and calls `skill_postflight_update` from `skill-base.sh`.

However, the comment in `orchestrator-postflight.sh` header says it IS called by skill-researcher, skill-planner, and skill-implementer. But reading the skill files, they do NOT call orchestrator-postflight.sh — they implement their own inline postflight stages. The `orchestrator-postflight.sh` script appears to be an alternative/shared path that may be called by some SKILL.md files but not the ones we're looking at.

**Clarifying verification needed**: Check if any SKILL.md currently calls `orchestrator-postflight.sh`.

### Finding 2: STATE_STATUS Bug in Standalone Skills

In `skill-researcher/SKILL.md` Stage 8a (line 372):
```bash
bash "$lifecycle_script" "$STATE_STATUS" &
```

`STATE_STATUS` is never set in the skill SKILL.md. It is a local variable inside `update-task-status.sh` that gets set to values like `researched`, `planned`, `completed` during the `map_status()` function — but it is NOT exported and NOT available to callers.

**Same bug exists in**: skill-planner/SKILL.md (line 375) and skill-implementer/SKILL.md (line 535).

**Fix required**: Replace `$STATE_STATUS` with the actual status string derived from the subagent's return status:
- skill-researcher: use `"$status"` (already holds `"researched"` when success) — but only call when status = "researched"
- skill-planner: use `"$status"` (holds `"planned"` when success) — but only call when status = "planned"  
- skill-implementer: use `"$status"` (holds `"implemented"`/`"completed"` when success) — need to map `"implemented"` → `"completed"` since wezterm.lua uses `"completed"` not `"implemented"`

**Status vocabulary mismatch**: `skill-implementer` returns status `"implemented"` (from subagent), but `update-task-status.sh postflight:implement` maps to `STATE_STATUS="completed"` (the wezterm tab color vocabulary). The TTS/wezterm call must use `"completed"` not `"implemented"` since `wezterm.lua` status_colors only has `completed` not `implemented`.

### Finding 3: workflow-active Marker Not Cleared by Postflight

The `workflow-active` marker at `.claude/tmp/workflow-active` is written by `update-task-status.sh preflight` but is only cleared by:
1. `wezterm-preflight-status.sh` Tier 2 (any non-lifecycle slash command)
2. ESC-cancel edge case (also Tier 2)

It is NOT cleared by:
- `orchestrator-postflight.sh` Stage 10
- Any of the standalone skill cleanup stages
- `skill-base.sh skill_cleanup()`

**Consequence**: After a standalone `/research N` completes, the `workflow-active` marker remains. The Stop hook (`claude-stop-notify.sh`) checks for this marker and exits silently if present — so `needs_input` (gray) tab color is NOT set when Claude returns to interactive mode after a standalone research. The tab stays at `researched` (bright green) until the user types another slash command.

**This is actually desirable behavior** — the tab keeps the completed color so the user can see "research is done." The user then initiates the next command (clearing the marker via Tier 2), and the cycle continues.

**BUT**: For /orchestrate which chains multiple phases, the workflow-active marker is set at each preflight and never cleared between phases. This means the Stop hook stays suppressed throughout the entire orchestrate run (correct — no `needs_input` interruption between phases). When orchestrate fully completes and Claude stops, the final Stop hook fires, sees workflow-active still present, and exits silently — so `needs_input` is never set after orchestrate finishes. Only when the user types their next command does Tier 2 clear it.

**Conclusion**: The workflow-active marker behavior works correctly without changes. No explicit cleanup needed from postflight scripts.

### Finding 4: Color Distinction in wezterm.lua (Already Correct)

From `wezterm.lua` lines 322-331:
```lua
local status_colors = {
  needs_input  = { bg = "#3a3a3a", fg = "#d0d0d0" },
  researching  = { bg = "#1e2e1e", fg = "#5a7a5a" },   -- dim green
  researched   = { bg = "#1a4a1a", fg = "#a0d080" },   -- bright green
  planning     = { bg = "#1a1e30", fg = "#5a6a8a" },   -- dim blue
  planned      = { bg = "#1a2a5a", fg = "#80a8d8" },   -- bright blue
  implementing = { bg = "#2e2a18", fg = "#8a7a40" },   -- dim gold
  completed    = { bg = "#4a3e18", fg = "#e5c060" },   -- bright gold
  blocked      = { bg = "#5a2a2a", fg = "#d0d0d0" },
}
```

The dim/bright distinction for mid-orchestrate vs final is therefore:
- Research done → next phase is planning → set `planning` (dim blue) via `--quiet`
- Plan done → next phase is implementing → set `implementing` (dim gold) via `--quiet`
- Implement done (final) → set `completed` (bright gold) without `--quiet` → fires TTS

For standalone completions:
- `/research N` done → set `researched` (bright green) → fires TTS
- `/plan N` done → set `planned` (bright blue) → fires TTS
- `/implement N` done → set `completed` (bright gold) → fires TTS

### Finding 5: skill-orchestrate Stage 5 Postflight — No lifecycle-notify Call

In `skill-orchestrate/SKILL.md` Stage 5, after each dispatch, the code calls `skill_postflight_update` from skill-base.sh. This function only updates state.json/TODO.md — it does NOT call lifecycle-notify.sh.

**For mid-orchestrate transitions (research done → planning)**: skill-orchestrate should call lifecycle-notify.sh with the status of the NEXT phase in dim color, e.g., after `researched` dispatch → call `lifecycle-notify.sh "planning" --quiet`.

**For final orchestrate completion (implement done → completed)**: skill-orchestrate should call `lifecycle-notify.sh "completed"` (no --quiet) to fire TTS.

### Finding 6: orchestrator-postflight.sh Caller Analysis

Cross-checking which skills call orchestrator-postflight.sh directly vs implementing inline postflight:

- `skill-researcher/SKILL.md`: Implements inline Stages 6-9 — does NOT call orchestrator-postflight.sh
- `skill-planner/SKILL.md`: Implements inline postflight — does NOT call orchestrator-postflight.sh  
- `skill-implementer/SKILL.md`: Implements inline postflight with continuation loop — does NOT call orchestrator-postflight.sh

The header comment in `orchestrator-postflight.sh` says it's called by these skills, but that's documentation drift. The actual skills have their own inline postflight. `orchestrator-postflight.sh` may be called by other skills or as a future refactor target. The Stage 8b lifecycle-notify.sh call in orchestrator-postflight.sh is fine to update for completeness but is not currently exercised by the main skill flows.

---

## Decisions

1. **Fix STATE_STATUS → use hardcoded status string** in standalone skill Stage 8a calls. For researcher: `"researched"`. For planner: `"planned"`. For implementer: `"completed"` (maps from `"implemented"`). Guard each with `if [ "$status" = "..." ]`.

2. **Fix orchestrator-postflight.sh Stage 8b** to pass `--quiet` since it's called in contexts where the transition is mid-workflow. If called for "implemented" status, map to "completed" for wezterm vocabulary.

3. **Add lifecycle-notify.sh calls to skill-orchestrate Stage 5** for both mid-orchestrate (with `--quiet` and next-phase dim status) and final completion (without `--quiet`, "completed").

4. **No changes needed to workflow-active cleanup** — existing behavior is correct.

5. **No changes needed to wezterm.lua, wezterm-notify.sh, or tts-notify.sh** — they already handle the vocabulary correctly.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `implemented` vs `completed` vocabulary mismatch | Always convert `implemented` → `completed` before calling lifecycle-notify.sh |
| skill-orchestrate Stage 5 is pseudocode/SKILL.md directives, not bash | Changes must follow the SKILL.md instruction pattern, not add executable bash blocks |
| Double-TTS if both orchestrator-postflight.sh AND skill-orchestrate fire | Since skills don't call orchestrator-postflight.sh directly, no double-fire risk |
| STATE_STATUS fix in SKILL.md changes skill behavior for agents reading SKILL.md | Agents follow SKILL.md instructions; fixing the variable reference is safe |

---

## Implementation Plan Summary

### Change 1: orchestrator-postflight.sh Stage 8b (lines 306-309)

Add `--quiet` flag and map `implemented` → `completed`:

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
  # Map "implemented" to "completed" for wezterm vocabulary
  notify_status="$status"
  if [ "$notify_status" = "implemented" ]; then
    notify_status="completed"
  fi
  bash "$lifecycle_script" "$notify_status" --quiet &
fi
```

Rationale: orchestrator-postflight.sh is called as a shared postflight helper. Adding `--quiet` is conservative — it fires tab color but not TTS. Since skill-orchestrate adds its own TTS call for final completion, this avoids double-TTS.

### Change 2: skill-researcher/SKILL.md Stage 8a

Replace `$STATE_STATUS` with `"researched"` (guarded):

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ] && [ "$status" = "researched" ]; then
    bash "$lifecycle_script" "researched" &
fi
```

### Change 3: skill-planner/SKILL.md Stage 8a

Replace `$STATE_STATUS` with `"planned"` (guarded):

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ] && [ "$status" = "planned" ]; then
    bash "$lifecycle_script" "planned" &
fi
```

### Change 4: skill-implementer/SKILL.md Stage 8a

Replace `$STATE_STATUS` with `"completed"` (guarded, mapping `implemented`→`completed`):

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ] && [ "$status" = "implemented" ]; then
    bash "$lifecycle_script" "completed" &
fi
```

### Change 5: skill-orchestrate/SKILL.md Stage 5 (after postflight_update block)

After the `skill_postflight_update` case block, add lifecycle notification:

```bash
# Lifecycle notification for orchestrate phase transitions
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
  case "$dispatch_status" in
    researched)
      # Mid-orchestrate: dim color of next phase (planning), no TTS
      bash "$lifecycle_script" "planning" --quiet &
      ;;
    planned)
      # Mid-orchestrate: dim color of next phase (implementing), no TTS
      bash "$lifecycle_script" "implementing" --quiet &
      ;;
    implemented)
      # Final completion: bright completed + TTS
      bash "$lifecycle_script" "completed" &
      ;;
  esac
fi
```

---

## Test Scenarios

### Scenario A: `/research N` standalone
1. UserPromptSubmit hook sets `researching` (dim green) immediately
2. Research agent runs, returns "researched"
3. skill-researcher Stage 8a calls `lifecycle-notify.sh "researched"` (no --quiet)
4. wezterm-notify.sh sets `researched` (bright green)
5. tts-notify.sh speaks "Tab N researched"
6. Stop hook fires — workflow-active present → suppressed (tab stays bright green)
7. User types next command → Tier 2 clears workflow-active

### Scenario B: `/orchestrate N` multi-phase
1. UserPromptSubmit hook sets `researching` (dim green) immediately
2. Research subagent completes, handoff status = "researched"
3. skill-orchestrate Stage 5: calls `skill_postflight_update` + `lifecycle-notify.sh "planning" --quiet`
4. Tab turns to `planning` (dim blue), no TTS
5. Plan subagent completes, handoff status = "planned"
6. skill-orchestrate Stage 5: calls `lifecycle-notify.sh "implementing" --quiet`
7. Tab turns to `implementing` (dim gold), no TTS
8. Implement subagent completes, handoff status = "implemented"
9. skill-orchestrate Stage 5: calls `lifecycle-notify.sh "completed"` (no --quiet)
10. Tab turns to `completed` (bright gold), TTS speaks "Tab N completed"
11. Stop hook fires — workflow-active present → suppressed (tab stays bright gold)

---

## Context Extension Recommendations

- **Topic**: SKILL.md variable scope in postflight stages
- **Gap**: No existing documentation explains that variables set inside bash scripts called by SKILL.md are not exported to the calling skill context. The `STATE_STATUS` bug exists because SKILL.md authors assumed the variable would be available.
- **Recommendation**: Add a note to `.claude/context/project/neovim/standards/skill-authoring.md` (if it exists) or create a new pattern document about variable scoping in postflight stages.

---

## Appendix

### Files Modified (Implementation)
- `/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh` (lines 306-309)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (lines 369-376)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (lines 371-378)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (lines 531-538)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (Stage 5, after line ~383)

### Files Read (Research)
- orchestrator-postflight.sh — Stage 8b lifecycle call, stage 10 cleanup
- skill-base.sh — skill_cleanup(), skill_postflight_update(), skill_write_orchestrator_handoff()
- lifecycle-notify.sh — --quiet flag interface (created by task 661)
- wezterm-notify.sh — STATUS → OSC 1337 SetUserVar
- tts-notify.sh — --lifecycle STATUS mode
- claude-stop-notify.sh — workflow-active suppression logic
- wezterm-preflight-status.sh — Tier 1/2/3 logic, workflow-active clearing
- update-task-status.sh — STATE_STATUS local var, workflow-active marker writing
- skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md — Stage 8a
- skill-orchestrate/SKILL.md — Stage 5 postflight block
- wezterm.lua — status_colors dim/bright mapping
- settings.json — Stop/UserPromptSubmit/Notification hook wiring
