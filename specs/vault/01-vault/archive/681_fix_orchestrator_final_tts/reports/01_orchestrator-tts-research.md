# Research Report: Task #681

**Task**: 681 - Fix orchestrator final-completion TTS and tab opacity integration
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: ~2.5 hours
**Dependencies**: Task 679 (TTS best practices research)
**Sources/Inputs**: Codebase (orchestrator-postflight.sh, lifecycle-notify.sh, claude-stop-notify.sh, update-task-status.sh, wezterm-preflight-status.sh, skill-base.sh, all skill SKILL.md files, wezterm.lua), prior research report 679
**Artifacts**: specs/681_fix_orchestrator_final_tts/reports/01_orchestrator-tts-research.md

---

## Executive Summary

- The core bug is confirmed: orchestrator-postflight.sh Stage 8b always passes `--quiet` to lifecycle-notify.sh (line 313), suppressing TTS for every phase transition including final completion
- The skills (researcher, planner, implementer, hard variants, reviser) each call `lifecycle-notify.sh` **without** `--quiet` directly in their own Stage 8a — but these skill-direct calls only apply in **standalone** mode (`/research N`, `/plan N`, `/implement N`); in orchestrator-driven mode the subagent's own postflight is bypassed and the orchestrator calls `orchestrator-postflight.sh` instead
- **Critical discovery**: In orchestrate mode, subagent skills still run their own Stage 8a lifecycle-notify call WITHOUT `--quiet` — this means TTS fires for EVERY phase completion (researched, planned, completed) already. The `orchestrator-postflight.sh` Stage 8b call is REDUNDANT and was added to handle non-skill-driven cases, but the comment "orchestrator itself fires the final TTS" is a false promise — there is no final TTS anywhere
- The workflow-active marker is written on preflight but **never cleared** at orchestrate completion — this means the final Stop hook after orchestrate also fires silently. The marker is only cleared by wezterm-preflight-status.sh Tier 2 (non-lifecycle slash commands), not by orchestrate postflight
- **Recommended fix**: (A) Remove `--quiet` from orchestrator-postflight.sh Stage 8b so both the skill's own Stage 8a and the shared postflight's Stage 8b both fire — the cooldown in tts-notify.sh prevents double-speak. (B) Add `rm -f .claude/tmp/workflow-active` to orchestrate Stage 8 clean exit so the final Stop hook fires correctly for task 680

---

## Context and Scope

This report covers the call-site inventory for orchestrator-postflight.sh, the signal design for distinguishing mid-orchestrate from final completion, the workflow-active marker lifecycle, and the tab color flow correctness. It directly feeds the planner for task 681.

---

## Findings

### 1. Call Site Inventory

There are only two call sites of `orchestrator-postflight.sh`:

**Finding**: `orchestrator-postflight.sh` is NOT called by the skills. The script header says "skill-researcher/SKILL.md calls this" but inspection of the actual SKILL.md files shows **they do not call this script**. All six skills (researcher, planner, implementer, researcher-hard, planner-hard, implementer-hard, reviser) implement their postflight inline, including lifecycle-notify at Stage 8a.

**Actual call sites of orchestrator-postflight.sh** (from grep): None found in any SKILL.md file. The script is referenced only in its own header (documentation) and in lifecycle-notify.sh (which says "Called by orchestrator-postflight.sh Stage 8b").

**What this means**: `orchestrator-postflight.sh` is a shared script designed to be called by skills, but no current skill actually calls it. All skills handle their own postflight directly. The script exists as infrastructure but is not yet wired to the skills.

**Actual lifecycle-notify call sites in skills** (the real TTS-firing path):

| Skill | lifecycle-notify call | --quiet? |
|-------|----------------------|---------|
| skill-researcher/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-planner/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-implementer/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-researcher-hard/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-planner-hard/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-implementer-hard/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |
| skill-reviser/SKILL.md Stage 8a | `bash lifecycle-notify.sh "$STATE_STATUS" &` | No |

**All skill Stage 8a calls are without `--quiet`**. This means TTS fires for every phase completion in BOTH standalone and orchestrator-driven modes — because in orchestrator mode the subagent skill still executes its own postflight before returning to the orchestrator.

**Implication**: The `orchestrator-postflight.sh` Stage 8b with `--quiet` is a redundant call that was documented as suppressing TTS "while the orchestrator fires final TTS", but:
1. No final TTS was ever implemented in the orchestrator
2. The skill Stage 8a already fires TTS without `--quiet`
3. The --quiet Stage 8b adds nothing except a tab color update that the skill Stage 8a already provided via wezterm-notify

**In orchestrate mode specifically**: When the orchestrate skill dispatches research via `general-research-agent`, the research agent's own SKILL.md Stage 8a fires `lifecycle-notify.sh "researched"` — no `--quiet`. The Stop hook then fires but is suppressed by the workflow-active marker. This means TTS fires for each phase. The broken part is the **final** Stop (after orchestrate completes) is also suppressed because the marker is never cleared.

---

### 2. Signal Design: Distinguishing Mid-Orchestrate from Final Completion

The four candidates evaluated:

**Option A: New 7th arg `--final`/`--mid` to orchestrator-postflight.sh**

Since orchestrator-postflight.sh is NOT actually called by any skill, this option is moot in the current codebase. If the script were wired to skills, the arg would need to come from the skill caller (which doesn't know if it's mid-orchestrate). Rating: LOW APPLICABILITY.

**Option B: Env var `ORCHESTRATE_MODE` set by skill-orchestrate**

The orchestrate skill could `export ORCHESTRATE_MODE=mid` before each subagent dispatch and `export ORCHESTRATE_MODE=final` for the last one. Subagent skills could read this env var. However, env vars do NOT cross agent boundaries (subagents don't inherit the orchestrator's env). Rating: DOES NOT WORK.

**Option C: Check workflow-active marker existence inside the script**

Lifecycle-notify.sh could check if `.claude/tmp/workflow-active` exists — if it does, suppress TTS (mid-orchestrate); if not, fire TTS. This is the same logic the Stop hook uses. However, the workflow-active marker is set during the ENTIRE orchestration run (from first preflight to... never cleared), so checking it from lifecycle-notify won't distinguish mid vs final. Rating: DOES NOT WORK as-is, but could work if the marker were cleared before the final Stop.

**Option D: Operation-based: research/plan always quiet, implement always loud**

In the context of orchestrator-postflight.sh, the operation_type arg is already available ($5). This would make `research` and `plan` postflight calls quiet (no TTS) and `implement` postflight calls loud. However, since skills don't call orchestrator-postflight.sh and instead call lifecycle-notify directly, this distinction is irrelevant to the current architecture.

**Recommended Signal Design** (given actual architecture):

Since TTS already fires correctly at every phase via skill Stage 8a (without --quiet), the actual problem is:

1. **The workflow-active marker is never cleared after orchestrate completes** → the final Stop hook fires silently (no TTS, no needs_input color)

The fix is: **Clear the workflow-active marker in skill-orchestrate Stage 8 (clean exit)**. This lets the subsequent Stop hook fire `needs_input` color and (after task 680's fix) TTS.

Additionally:
2. `orchestrator-postflight.sh` Stage 8b is dead code — nothing calls it. The `--quiet` comment is misleading. The script should be either wired up correctly or the Stage 8b should be fixed to not pass `--quiet` for future use.

---

### 3. Workflow-Active Marker Lifecycle

**Written by**: `update-task-status.sh` preflight (line 147-149):
```bash
if [[ "$operation" == "preflight" ]]; then
    mkdir -p "$SCRIPT_DIR/../tmp"
    echo "$task_number $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SCRIPT_DIR/../tmp/workflow-active"
fi
```

Written at: `.claude/tmp/workflow-active`

**Cleared by** (two locations):
1. `wezterm-preflight-status.sh` Tier 2 (any non-lifecycle slash command): `rm -f "$SCRIPT_DIR/../tmp/workflow-active"`
2. Implicitly by the next lifecycle command's preflight overwriting the file (same path, same task number)

**NEVER CLEARED** by:
- orchestrator-postflight.sh Stage 10 (cleanup)
- skill-orchestrate Stage 8 (final cleanup)
- Any postflight script

**Impact Analysis**:

When `/orchestrate 681` runs:
1. Orchestrate dispatches research agent
2. Researcher's preflight calls `update-task-status.sh preflight research` → writes `workflow-active` with task 681
3. Researcher completes → researcher's postflight calls lifecycle-notify (TTS fires) → researcher returns
4. Stop hook fires for researcher → marker exists → Stop is suppressed (correct)
5. Orchestrate dispatches planner agent
6. Planner's preflight calls `update-task-status.sh preflight plan` → **overwrites** `workflow-active` (same file, task 681)
7. Planner completes → planner's postflight calls lifecycle-notify (TTS fires) → planner returns
8. Stop hook fires for planner → marker exists → Stop is suppressed (correct)
9. Orchestrate dispatches implement agent
10. Implementer's preflight calls `update-task-status.sh preflight implement` → **overwrites** `workflow-active`
11. Implementer completes → implementer's postflight calls lifecycle-notify (TTS fires) → implementer returns
12. Stop hook fires for implementer → marker exists → Stop is suppressed (correct)
13. Orchestrate reaches State: `completed` → **does NOT clear workflow-active** → exits
14. **Main orchestrator Stop fires** → marker STILL EXISTS → Stop is suppressed → **NO needs_input color, NO TTS**

**Verdict**: The workflow-active marker is never cleared at orchestrate completion. This means the final Stop after a completed orchestration is silently suppressed. Task 680's fix (TTS in Stop hook) would fire correctly only if the marker is cleared before the final Stop.

---

### 4. Tab Color Flow Analysis

**Design intent** (from wezterm.lua + task description):
- `researching` → dim green (in-progress)
- `researched` → bright green (done)
- `planning` → dim blue (in-progress)
- `planned` → bright blue (done)
- `implementing` → dim gold (in-progress)
- `completed` → bright gold (done)
- `needs_input` → gray (user attention required)

**Discrepancy 1**: The task description mentions "mid-orchestrate transitions should use the in-progress color of the NEXT phase". This is NOT what happens:

Current flow during orchestrate:
- After research: lifecycle-notify fires `researched` (bright green) ✓
- Transition to planning: wezterm-preflight-status.sh Tier 1 matches `/orchestrate N` → fires `researching` NOT `planning`

The `wezterm-preflight-status.sh` only fires once on `/orchestrate N` submission (setting `researching`). All subsequent mid-orchestrate phase transitions (research→plan, plan→implement) do NOT update the WezTerm tab to the next phase's dim color because there is no UserPromptSubmit hook firing for those transitions.

The tab color timeline during `/orchestrate 681`:
1. User submits `/orchestrate 681` → WezTerm fires `researching` (dim green) ✓
2. Research completes → lifecycle-notify fires `researched` (bright green) ✓
3. Plan starts → **NO intermediate `planning` (dim blue) fired** — gap in coverage
4. Plan completes → lifecycle-notify fires `planned` (bright blue) ✓
5. Implement starts → **NO intermediate `implementing` (dim gold) fired** — gap
6. Implement completes → lifecycle-notify fires `completed` (bright gold) ✓
7. Orchestrate exits → **NO `needs_input` (gray) fired** — MISSING (marker never cleared)

**Discrepancy 2**: `implemented` → `completed` translation in orchestrator-postflight.sh

In `orchestrator-postflight.sh` Stage 8b, `notify_status` translates `implemented` to `completed` (line 312). This is needed because wezterm.lua only maps `completed`, not `implemented`. The skills also use `STATE_STATUS` which for implement is "completed" (set after `update-task-status.sh postflight implement` maps `postflight:implement` → `completed`). So both the skill Stage 8a and the orchestrator-postflight.sh Stage 8b correctly fire `completed`.

**Discrepancy 3**: Missing `planning` and `implementing` dim colors during orchestrate

To show `planning` (dim blue) when transitioning from research→plan, something must fire `wezterm-notify.sh planning` at that moment. Currently, neither the orchestrator nor any preflight script fires this mid-orchestrate.

The orchestrator-postflight.sh Stage 8b comment says it handles mid-orchestrate colors — but it fires AFTER the research agent completes (producing `researched` bright green), not BEFORE the plan agent starts.

If the goal is "mid-orchestrate transitions should show the NEXT phase's dim color", the orchestrator would need to call `wezterm-notify.sh planning` between dispatching research→plan, and `wezterm-notify.sh implementing` between dispatching plan→implement. This is not currently implemented.

**Summary of discrepancies**:

| Color transition | Current behavior | Expected behavior |
|-----------------|-----------------|------------------|
| Submit `/orchestrate N` | `researching` (dim green) ✓ | `researching` |
| Research complete | `researched` (bright green) ✓ | `researched` |
| Plan starts | No color change | `planning` (dim blue) |
| Plan complete | `planned` (bright blue) ✓ | `planned` |
| Implement starts | No color change | `implementing` (dim gold) |
| Implement complete | `completed` (bright gold) ✓ | `completed` |
| Orchestrate exits | No color change (marker not cleared) | `needs_input` (gray) |

---

### 5. Double-Announcement Risk with Task 680

**The risk scenario**:

If task 680 adds TTS to the Stop hook (when no workflow-active marker exists), AND task 681 clears the marker at orchestrate completion, the final sequence is:
1. Implement completes → lifecycle-notify fires TTS ("Tab N completed") — lifecycle path
2. Orchestrate Stage 8 clears workflow-active marker
3. Main orchestrator Stop fires → (after 680's fix) Stop hook fires TTS ("Tab N") — Stop path

This is a double-announcement: "Tab N completed" then "Tab N".

**Coordination mechanism**:

`tts-notify.sh` has no cooldown mechanism. The task 679 research recommends adding a timestamp cooldown to the project tts-notify.sh (10s default). This would prevent the double-speak: after "Tab N completed" fires, a 10s window suppresses "Tab N".

**For task 681's implementation plan**, the coordination is:
1. Orchestrate Stage 8 clears workflow-active marker **after** lifecycle TTS has already fired (lifecycle TTS is background, runs in parallel)
2. Stop hook fires ~0-100ms after orchestrate exits (very short delay)
3. Without cooldown, double TTS fires
4. With cooldown in tts-notify.sh (shared between both paths), the Stop-hook TTS is suppressed if lifecycle TTS fired within the cooldown window

**Recommendation**: Task 681 implementation MUST include the cooldown addition to tts-notify.sh (as recommended by task 679). The cooldown timestamp file should be `/tmp/claude-tts-last-notify` (matching the global tts-notify.sh pattern). A 10s window is appropriate — lifecycle events won't fire faster than 10s apart in practice.

---

## Decisions

1. **No new arg or env var needed**: Since skills don't call orchestrator-postflight.sh, the signal design question (how to distinguish mid-orchestrate from final) is moot. Skills already fire lifecycle-notify without --quiet.

2. **Primary fix location**: `skill-orchestrate/SKILL.md` Stage 8 (clean exit), add:
   ```bash
   rm -f ".claude/tmp/workflow-active" 2>/dev/null || true
   ```
   This unblocks the final Stop hook.

3. **orchestrator-postflight.sh Stage 8b**: Remove `--quiet` to make the script correct for any future callers. This is a low-risk change since the script isn't currently called.

4. **Add cooldown to tts-notify.sh**: Required to prevent double-announcement when both lifecycle TTS and Stop-hook TTS fire in sequence.

5. **Mid-orchestrate dim colors**: Fixing `planning` and `implementing` dim colors during orchestrate is a separate concern, lower priority. The current behavior (missing intermediate dim states) is a visual gap, not a TTS correctness issue. Defer to a separate task.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Clearing workflow-active too early (mid-orchestrate) | High | Only clear in Stage 8 on CLEAN exit (completed state), not on partial/MAX_CYCLES exit |
| Double TTS on final completion | Medium | Add 10s cooldown to tts-notify.sh |
| orchestrator-postflight.sh is dead code | Low | Document it; fix --quiet for correctness; consider wiring to skills in future task |
| Neovim extension skills not checked | Low | The nvim skills likely mirror core skills; verify wezterm-notify calls same pattern |

---

## Proposed Change Set

### File 1: `.claude/skills/skill-orchestrate/SKILL.md` — Stage 8 clean exit

Add after `rm -f "$loop_guard_file"`:
```bash
# Clear workflow-active marker so the final Stop hook fires needs_input color + TTS
rm -f ".claude/tmp/workflow-active" 2>/dev/null || true
```

This is the primary fix. Apply to BOTH single-task Stage 8 clean exit AND multi-task Stage MT-5 clean exit.

### File 2: `.claude/scripts/orchestrator-postflight.sh` — Stage 8b

Change line 313 from:
```bash
bash "$lifecycle_script" "$notify_status" --quiet &
```
To:
```bash
bash "$lifecycle_script" "$notify_status" &
```

Remove the comment "-- this script is called mid-orchestrate..." since it was incorrect. Update comment to explain the script is a shared postflight utility, not specifically mid-orchestrate.

### File 3: `.claude/hooks/tts-notify.sh` — Add cooldown

Add a 10s timestamp-based cooldown to prevent double-announce when both lifecycle TTS and Stop-hook TTS fire in sequence:
```bash
# Cooldown check (prevents double-announce from lifecycle + Stop race)
COOLDOWN_FILE="/tmp/claude-tts-last-notify"
COOLDOWN_SECONDS=10
if [[ -f "$COOLDOWN_FILE" ]]; then
    last_notify=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    elapsed=$((now - last_notify))
    if [[ "$elapsed" -lt "$COOLDOWN_SECONDS" ]]; then
        log "Cooldown active (${elapsed}s < ${COOLDOWN_SECONDS}s) — skipping TTS"
        exit_success
    fi
fi
# Write timestamp before speaking
echo "$(date +%s)" > "$COOLDOWN_FILE" 2>/dev/null || true
```

Place this block AFTER the TTS_ENABLED and piper availability checks, but BEFORE the lifecycle/interactive mode branches.

### File 4: `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` (if exists)

Check if the extension directory mirrors the skill and apply the same Stage 8 fix.

---

## Context Extension Recommendations

- **Topic**: Orchestrator postflight architecture clarification
- **Gap**: orchestrator-postflight.sh header says skills call it, but they don't — this documentation is incorrect and misleading
- **Recommendation**: Update the script header comments and the relevant CLAUDE.md documentation to clarify the actual call graph

---

## Appendix

### Search Queries Used

- `grep -rn "orchestrator-postflight" .claude/` (grep for all call sites)
- `grep -rn "workflow-active" .claude/` (marker lifecycle)
- `grep -rn "lifecycle-notify" .claude/skills/` (TTS call sites in skills)
- `grep "completed\|implemented" wezterm.lua` (tab color mapping)

### Key Files Examined

- `.claude/scripts/orchestrator-postflight.sh` (full file, 342 lines)
- `.claude/scripts/lifecycle-notify.sh` (full file, 46 lines)
- `.claude/scripts/update-task-status.sh` (full file, 344 lines)
- `.claude/hooks/claude-stop-notify.sh` (full file, 66 lines)
- `.claude/hooks/wezterm-preflight-status.sh` (full file, 92 lines)
- `.claude/hooks/wezterm-notify.sh` (full file, 72 lines)
- `.claude/hooks/tts-notify.sh` (full file, 128 lines)
- `.claude/skills/skill-orchestrate/SKILL.md` (full file, ~1146 lines)
- `.claude/skills/skill-researcher/SKILL.md` (Stage 8a excerpt)
- `.claude/skills/skill-planner/SKILL.md` (Stage 8a excerpt)
- `.claude/skills/skill-implementer/SKILL.md` (Stage 8a excerpt)
- `.claude/scripts/skill-base.sh` (postflight functions)
- `.config/wezterm/wezterm.lua` (tab color mapping)
- `specs/679_research_tts_best_practices/reports/01_tts-best-practices.md` (prior research)
