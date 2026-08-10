# Implementation Plan: Wire Postflight Lifecycle Notifications End-to-End

- **Task**: 662 - Wire postflight lifecycle notifications end-to-end
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 661 (completed -- lifecycle-notify.sh exists)
- **Research Inputs**: specs/662_wire_postflight_lifecycle_notifications/reports/01_wire-lifecycle-notify.md
- **Artifacts**: plans/01_wire-lifecycle-notify.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Wire the `lifecycle-notify.sh` bridge script (created by task 661) into the postflight pipeline for both standalone and orchestrate flows. Three bugs need fixing: (1) standalone skill SKILL.md files reference an undefined `$STATE_STATUS` variable, making lifecycle calls no-ops; (2) `orchestrator-postflight.sh` calls lifecycle-notify without `--quiet`, causing unwanted TTS during mid-orchestrate transitions; (3) `skill-orchestrate` Stage 5 has no lifecycle-notify calls at all, so dim/bright color transitions never fire during `/orchestrate` runs. All changes are to `.claude/` infrastructure files (SKILL.md directives and shell scripts), not Lua code.

### Research Integration

Research report `01_wire-lifecycle-notify.md` confirmed all five files that need changes, identified the `STATE_STATUS` scoping bug (variable is local to `update-task-status.sh`, never exported), the missing `--quiet` flag in `orchestrator-postflight.sh`, and the `implemented` vs `completed` vocabulary mismatch between subagent return values and `wezterm.lua` status_colors. The `workflow-active` marker cleanup was found to be correct as-is (no changes needed).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. This is a bug-fix and integration task for the terminal UI lifecycle notification system.

## Goals & Non-Goals

**Goals**:
- Fix standalone skill lifecycle notifications so TTS and tab color fire on `/research`, `/plan`, and `/implement` completion
- Add `--quiet` to orchestrator-postflight.sh so shared postflight path does not produce TTS
- Wire lifecycle-notify into skill-orchestrate Stage 5 with dim color for mid-phase transitions and bright + TTS for final completion
- Map `implemented` to `completed` everywhere lifecycle-notify is called, since wezterm.lua only has `completed` in its color table

**Non-Goals**:
- Modifying wezterm.lua, wezterm-notify.sh, tts-notify.sh, or lifecycle-notify.sh (all correct as-is)
- Changing workflow-active marker cleanup behavior (correct as-is)
- Adding new lifecycle statuses or notification modes

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md changes misread by agents (these are directives, not executable bash) | M | L | Follow existing SKILL.md code-block style exactly, only change the variable reference |
| Double-TTS if orchestrator-postflight.sh is called by some flow AND skill-orchestrate fires | H | L | Research confirmed skills do NOT call orchestrator-postflight.sh; no overlap risk |
| implemented vs completed mapping missed in one path | M | L | All three call sites (standalone, orchestrator-postflight, orchestrate) must map; verify each in phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Standalone Skill SKILL.md Files [COMPLETED]

**Goal**: Replace the undefined `$STATE_STATUS` variable with correct hardcoded status strings in the three standalone skill SKILL.md Stage 8a blocks, with success guards and the `implemented` to `completed` mapping.

**Tasks**:
- [x] Edit `skill-researcher/SKILL.md` Stage 8a (lines 369-374): replace `$STATE_STATUS` with `"researched"`, guard with `[ "$status" = "researched" ]`
- [x] Edit `skill-planner/SKILL.md` Stage 8a (lines 372-377): replace `$STATE_STATUS` with `"planned"`, guard with `[ "$status" = "planned" ]`
- [x] Edit `skill-implementer/SKILL.md` Stage 8a (lines 532-537): replace `$STATE_STATUS` with `"completed"`, guard with `[ "$status" = "implemented" ]` (maps implemented to completed)
- [x] Verify each edit preserves the surrounding markdown structure and code-block fencing

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Fix Stage 8a lifecycle call
- `.claude/skills/skill-planner/SKILL.md` - Fix Stage 8a lifecycle call
- `.claude/skills/skill-implementer/SKILL.md` - Fix Stage 8a lifecycle call

**Verification**:
- Grep each SKILL.md for `STATE_STATUS` -- must return zero matches
- Grep each SKILL.md for `lifecycle-notify.sh` -- must return exactly one match per file with correct status string
- Confirm code blocks are valid bash syntax (no unclosed quotes or brackets)

---

### Phase 2: Fix orchestrator-postflight.sh [COMPLETED]

**Goal**: Add `--quiet` flag and `implemented` to `completed` mapping in the shared postflight script's Stage 8b lifecycle call, so any code path through this script fires tab color only (no TTS).

**Tasks**:
- [x] Edit `orchestrator-postflight.sh` lines 306-309: add `notify_status` variable with `implemented` to `completed` mapping, pass `--quiet` flag
- [x] Update the Stage 8b comment to document the `--quiet` rationale

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/orchestrator-postflight.sh` - Add --quiet and status mapping to Stage 8b

**Verification**:
- Run `bash -n .claude/scripts/orchestrator-postflight.sh` -- must exit 0 (syntax check)
- Grep for `--quiet` in the lifecycle call -- must be present
- Grep for `notify_status` mapping -- must map implemented to completed

---

### Phase 3: Wire Lifecycle Notifications into skill-orchestrate Stage 5 [COMPLETED]

**Goal**: Add lifecycle-notify.sh calls to the skill-orchestrate SKILL.md Stage 5 postflight block. Mid-orchestrate transitions (researched, planned) use `--quiet` with the dim color of the NEXT phase. Final completion (implemented) uses full mode with `completed` status.

**Tasks**:
- [x] Add a lifecycle notification code block after the `skill_postflight_update` case statement (after line 382), before the artifact-linking block
- [x] Implement a case statement on `$dispatch_status`: `researched` calls `lifecycle-notify.sh "planning" --quiet`, `planned` calls `lifecycle-notify.sh "implementing" --quiet`, `implemented` calls `lifecycle-notify.sh "completed"` (no --quiet)
- [x] Add explanatory markdown text above the code block documenting the dim/bright distinction
- [x] Ensure the code block follows the existing SKILL.md style (indented bash in triple-backtick fences)

**Timing**: 20 minutes

**Depends on**: 1 (need to understand the status mapping pattern established in Phase 1 to stay consistent)

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add lifecycle-notify calls to Stage 5

**Verification**:
- Grep skill-orchestrate/SKILL.md for `lifecycle-notify.sh` -- must return 3 matches (one per case branch)
- Grep for `--quiet` -- must appear on researched and planned branches only
- Grep for `"completed"` -- must appear on implemented branch without --quiet
- Confirm the code block uses `$dispatch_status` (not `$status` or `$STATE_STATUS`)

## Testing & Validation

- [x] `bash -n .claude/scripts/orchestrator-postflight.sh` passes syntax check
- [x] `grep -r 'STATE_STATUS' .claude/skills/skill-researcher/SKILL.md .claude/skills/skill-planner/SKILL.md .claude/skills/skill-implementer/SKILL.md` returns empty (bug is fixed)
- [x] `grep -c 'lifecycle-notify.sh' .claude/skills/skill-orchestrate/SKILL.md` returns 3+ (3 bash invocations via $lifecycle_script variable)
- [x] `grep 'lifecycle-notify.sh.*--quiet' .claude/scripts/orchestrator-postflight.sh` returns a match
- [ ] Manual smoke test: run `/research N` on a test task and confirm TTS fires with "researched" status
- [ ] Manual smoke test: run `/orchestrate N` and confirm dim color transitions between phases, TTS only on final completion

## Artifacts & Outputs

- `specs/662_wire_postflight_lifecycle_notifications/plans/01_wire-lifecycle-notify.md` (this plan)
- `specs/662_wire_postflight_lifecycle_notifications/summaries/01_wire-lifecycle-notify-summary.md` (after implementation)

## Rollback/Contingency

All changes are to `.claude/` infrastructure files. Revert with `git checkout HEAD -- .claude/skills/skill-researcher/SKILL.md .claude/skills/skill-planner/SKILL.md .claude/skills/skill-implementer/SKILL.md .claude/scripts/orchestrator-postflight.sh .claude/skills/skill-orchestrate/SKILL.md`. Since lifecycle-notify.sh is a no-op on empty status, reverting the callers restores the pre-implementation behavior (silent no-ops).
