# Implementation Plan: Fix Orchestrator Final-Completion TTS and Tab Opacity Integration

- **Task**: 681 - Fix orchestrator final-completion TTS and tab opacity integration
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 680 (Stop hook TTS + cooldown in tts-notify.sh)
- **Research Inputs**: [specs/681_fix_orchestrator_final_tts/reports/01_orchestrator-tts-research.md]
- **Artifacts**: plans/01_orchestrator-tts-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The orchestrator's workflow-active marker is never cleared at orchestration completion, which silently suppresses the final Stop hook (preventing TTS and needs_input tab color). Additionally, skill Stage 8a lifecycle-notify calls fire TTS for every mid-orchestrate phase completion (researched, planned, completed), contradicting the desired UX where mid-orchestrate transitions should be silent (tab color only) and only the final/standalone completion should announce via TTS. This plan introduces an `orchestrate-active` marker file that skills check to suppress mid-orchestrate TTS, clears the workflow-active marker on orchestration exit, fixes the misleading `--quiet` flag in orchestrator-postflight.sh, and optionally adds mid-orchestrate dim tab color transitions.

### Research Integration

Key findings from the research report:
- orchestrator-postflight.sh is NOT called by any skill; all skills call lifecycle-notify.sh directly in their Stage 8a
- All skill Stage 8a calls use lifecycle-notify WITHOUT `--quiet`, meaning TTS fires for every phase completion even mid-orchestrate
- The workflow-active marker is written on preflight but never cleared on orchestration exit
- Environment variables do not cross agent boundaries, but file-based markers (like workflow-active) are accessible to all agents
- The recommended fix is: clear workflow-active in Stage 8, remove `--quiet` from Stage 8b for correctness, and use a file-based signal to suppress mid-orchestrate TTS

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Clear the workflow-active marker at orchestration completion so the final Stop hook fires correctly
- Suppress TTS during mid-orchestrate phase transitions (tab color only) while preserving TTS for standalone completions
- Fix orchestrator-postflight.sh Stage 8b to remove misleading `--quiet` flag
- Add mid-orchestrate dim tab color transitions between phases (planning, implementing)

**Non-Goals**:
- Changes to claude-stop-notify.sh, tts-notify.sh, or settings.json (task 680 territory)
- Restructuring the orchestrator-postflight.sh call architecture (skills calling it vs. inline postflight)
- Changes to wezterm.lua color mapping

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Clearing workflow-active too early (mid-orchestrate) causes Stop hook to fire incorrectly | H | L | Only clear in Stage 8 on clean exit and partial exit, not in the state machine loop |
| orchestrate-active marker not cleared on crash/timeout | M | L | wezterm-preflight-status.sh Tier 2 already clears workflow-active on next command; add orchestrate-active cleanup there too |
| Skill Stage 8a changes break standalone TTS | H | L | Standalone mode has no orchestrate-active marker, so lifecycle-notify fires TTS normally |
| Mid-orchestrate dim color transitions fire at wrong time | L | L | Colors are purely visual; incorrect dim color is harmless and self-correcting at next lifecycle-notify |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add orchestrate-active marker lifecycle to skill-orchestrate [COMPLETED]

**Goal**: Create the orchestrate-active marker file at orchestration start and clear it (along with workflow-active) at all exit points, enabling downstream scripts to distinguish mid-orchestrate from standalone execution.

**Tasks**:
- [x] In `.claude/skills/skill-orchestrate/SKILL.md` Stage 2 (after loop guard creation, around line 147), add a write of `.claude/tmp/orchestrate-active` marker file containing the task number and timestamp *(completed)*
- [x] In Stage 8 clean exit (around line 602-605), add `rm -f ".claude/tmp/orchestrate-active" 2>/dev/null || true` and `rm -f ".claude/tmp/workflow-active" 2>/dev/null || true` after the existing `rm -f "$loop_guard_file"` *(completed)*
- [x] In Stage 8 partial exit (around line 612-614), add `rm -f ".claude/tmp/orchestrate-active" 2>/dev/null || true` and `rm -f ".claude/tmp/workflow-active" 2>/dev/null || true` so that paused/blocked orchestrations also enable the final Stop hook TTS *(completed)*
- [x] In Stage MT-5 multi-task postflight (around line 1093), add the same orchestrate-active and workflow-active cleanup after `rm -f "$mt_state_file"` *(completed)*
- [x] In Stage MT-5 partial exit path (around line 1097), add the same cleanup *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add marker write at Stage 2, cleanup at Stage 8 (clean + partial) and Stage MT-5 (clean + partial)

**Verification**:
- Grep for `orchestrate-active` in SKILL.md confirms marker write and cleanup at all exit paths
- Grep for `workflow-active` in SKILL.md confirms cleanup alongside orchestrate-active
- Count exit paths: Stage 8 clean, Stage 8 partial, in-flight warnings (researching/planning), MAX_CYCLES, terminal states, MT-5 clean, MT-5 partial -- verify each has appropriate cleanup

---

### Phase 2: Suppress mid-orchestrate TTS via orchestrate-active check in lifecycle-notify.sh [COMPLETED]

**Goal**: Modify lifecycle-notify.sh to check for the orchestrate-active marker and suppress TTS (but not tab color) when it exists, implementing the UX decision table.

**Tasks**:
- [x] In `.claude/scripts/lifecycle-notify.sh`, after the STATUS empty check (line 31) and before the wezterm-notify call (line 33), add a check for `.claude/tmp/orchestrate-active`: if the file exists, set `QUIET="--quiet"` to suppress TTS while preserving tab color updates *(completed)*
- [x] Update the script header comment (lines 1-17) to document the orchestrate-active marker behavior and the UX decision table *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/lifecycle-notify.sh` - Add orchestrate-active check, update header documentation

**Verification**:
- Read the modified lifecycle-notify.sh and confirm the orchestrate-active check is placed AFTER the empty status check and BEFORE the quiet-mode decision
- Confirm the logic: `if [[ -f "$SCRIPT_DIR/../tmp/orchestrate-active" ]]; then QUIET="--quiet"; fi`
- Verify that the wezterm-notify call (tab color) is NOT gated by the new check -- only TTS is suppressed

---

### Phase 3: Fix orchestrator-postflight.sh Stage 8b and add mid-orchestrate dim tab colors [COMPLETED]

**Goal**: Remove the misleading `--quiet` flag from Stage 8b (making it correct for future callers), update comments, and add mid-orchestrate dim tab color transitions in the orchestrate state machine.

**Tasks**:
- [x] In `.claude/scripts/orchestrator-postflight.sh` Stage 8b (lines 304-314), remove `--quiet` from the lifecycle-notify.sh call on line 313: change `bash "$lifecycle_script" "$notify_status" --quiet &` to `bash "$lifecycle_script" "$notify_status" &` *(completed)*
- [x] Update the Stage 8b comment block (lines 304-307) to remove "this script is called mid-orchestrate" and replace with accurate documentation: "Fires lifecycle notification for tab color and TTS. TTS is automatically suppressed during orchestration via the orchestrate-active marker in lifecycle-notify.sh." *(completed)*
- [x] In `.claude/skills/skill-orchestrate/SKILL.md` Stage 4, add a `wezterm-notify.sh` call before plan dispatch (State: `researched`) and implement dispatch (State: `planned` or `implementing`) to set the dim "in-progress" color *(completed)*
- [x] Add cleanup of `orchestrate-active` to `.claude/hooks/wezterm-preflight-status.sh` Tier 2 (where workflow-active is already cleaned up) to handle crash/timeout recovery *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/orchestrator-postflight.sh` - Remove `--quiet` from Stage 8b, update comments
- `.claude/skills/skill-orchestrate/SKILL.md` - Add dim color transitions before plan and implement dispatches in Stage 4
- `.claude/hooks/wezterm-preflight-status.sh` - Add `orchestrate-active` cleanup in Tier 2

**Verification**:
- Grep `--quiet` in orchestrator-postflight.sh -- should return zero matches
- Grep `wezterm-notify.sh planning` and `wezterm-notify.sh implementing` in SKILL.md confirms dim color dispatches
- Grep `orchestrate-active` in wezterm-preflight-status.sh confirms crash recovery cleanup
- Read the updated Stage 8b comment block to confirm accurate documentation

---

### Phase 4: End-to-end verification and documentation [COMPLETED]

**Goal**: Verify the complete signal flow for all scenarios in the UX decision table and ensure documentation is consistent.

**Tasks**:
- [x] Trace the standalone `/research N` signal flow: no orchestrate-active -> lifecycle-notify fires TTS normally *(verified)*
- [x] Trace the `/orchestrate N` signal flow: Stage 2 writes orchestrate-active -> each dispatch's lifecycle-notify suppresses TTS (orchestrate-active exists) -> Stage 8 clean exit removes both markers -> Stop hook fires TTS *(verified)*
- [x] Verify the tab color timeline: researching -> researched -> planning (dim, new dispatch call) -> planned -> implementing (dim, new dispatch call) -> completed -> needs_input *(verified)*
- [x] Verify no double-announce: in orchestrate mode, lifecycle-notify TTS suppressed -> orchestrate-active cleared -> Stop hook is the ONLY TTS *(verified)*
- [x] Review orchestrator-postflight.sh Stage 8b documentation: accurate (removed "mid-orchestrate" claim, documents orchestrate-active mechanism) *(verified)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- No new file changes expected; verification and documentation review only

**Verification**:
- All signal flow traces documented in a verification checklist
- No contradictions found between modified files
- UX decision table satisfied for all four scenarios

## Testing & Validation

- [ ] Grep for `orchestrate-active` across `.claude/` directory confirms marker write (SKILL.md Stage 2), cleanup (SKILL.md Stage 8 + MT-5, wezterm-preflight-status.sh Tier 2), and check (lifecycle-notify.sh)
- [ ] Grep for `workflow-active` in SKILL.md confirms cleanup at Stage 8 and MT-5
- [ ] Grep for `--quiet` in orchestrator-postflight.sh returns zero matches
- [ ] Grep for `wezterm-notify.sh planning` and `wezterm-notify.sh implementing` in SKILL.md confirms dim color dispatches
- [ ] Read lifecycle-notify.sh and verify the orchestrate-active check is correctly placed
- [ ] Verify no changes were made to task 680 territory files: claude-stop-notify.sh, tts-notify.sh, settings.json

## Artifacts & Outputs

- `specs/681_fix_orchestrator_final_tts/plans/01_orchestrator-tts-plan.md` (this plan)
- Modified files:
  - `.claude/skills/skill-orchestrate/SKILL.md` (orchestrate-active marker write + cleanup + dim tab colors)
  - `.claude/scripts/lifecycle-notify.sh` (orchestrate-active check for TTS suppression)
  - `.claude/scripts/orchestrator-postflight.sh` (remove --quiet from Stage 8b)
  - `.claude/hooks/wezterm-preflight-status.sh` (orchestrate-active crash recovery cleanup)

## Rollback/Contingency

All changes are to bash scripts and a markdown SKILL.md specification file. If the changes cause issues:
1. Revert the lifecycle-notify.sh orchestrate-active check to restore pre-change TTS behavior
2. Revert the SKILL.md marker write/cleanup to remove the orchestrate-active mechanism
3. Re-add `--quiet` to orchestrator-postflight.sh Stage 8b if the removal causes unexpected TTS

The orchestrate-active marker file is ephemeral (`.claude/tmp/`) and self-cleaning via wezterm-preflight-status.sh Tier 2, so stale markers are not a permanent concern.
