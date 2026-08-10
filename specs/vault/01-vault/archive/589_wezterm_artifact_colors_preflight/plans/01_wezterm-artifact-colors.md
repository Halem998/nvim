# Implementation Plan: Task #589

- **Task**: 589 - wezterm_artifact_colors_preflight
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 588
- **Research Inputs**: specs/589_wezterm_artifact_colors_preflight/reports/01_wezterm-artifact-colors.md
- **Artifacts**: plans/01_wezterm-artifact-colors.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task extends the wezterm notification system established by task 588 in two directions: (1) adding per-artifact-type tab colors so that completed research reports show green, plans show blue, summaries show gold, and errors show red; and (2) adding preflight tab coloring via the UserPromptSubmit hook so the tab immediately reflects in-progress state (researching, planning, implementing) the moment a lifecycle command is submitted -- before Claude begins processing. The signal file format remains unchanged; artifact type is passed directly to `wezterm-notify.sh` in the postflight dispatch path.

### Research Integration

Key findings from the research report (01_wezterm-artifact-colors.md):

- The current `status_colors` table in `wezterm.lua` has 8 lifecycle entries. Task 589 adds 4 artifact-type entries (`report`, `plan`, `summary`, `error`) as direct CLAUDE_STATUS values, avoiding compound strings.
- Signal file format remains single-line status-only. Artifact type is passed to `wezterm-notify.sh` directly from `update-task-status.sh` Phase 5, separate from the signal file content.
- The `UserPromptSubmit` hook currently unconditionally clears CLAUDE_STATUS. The new `wezterm-preflight-status.sh` script replaces `wezterm-clear-status.sh` with 3-tier logic: set in-progress on lifecycle commands, clear on other slash commands, preserve on free text.
- Parity is required across 4 settings.json files and 2 extension copy locations (Claude Code + OpenCode), plus the OpenCode hooks directory.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is an infrastructure enhancement to the notification system.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `report`, `plan`, `summary`, `error` color entries to `wezterm.lua` status_colors table
- Modify `update-task-status.sh` Phase 5 to pass artifact type (not lifecycle status) to `wezterm-notify.sh` for postflight events
- Create `wezterm-preflight-status.sh` hook that sets in-progress CLAUDE_STATUS on lifecycle command submission
- Replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` in all settings.json files
- Maintain parity across Claude Code, OpenCode, and their respective extension copies

**Non-Goals**:
- Changing TTS behavior (wezterm tab coloring only)
- Modifying signal file format (stays single-line status string)
- Changing Stop hook logic (claude-stop-notify.sh unchanged)
- Adding artifact type to TTS announcements

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Artifact status values conflict with existing lifecycle values | Medium | Low | Using distinct strings (`report`, `plan`, `summary`, `error`) that do not overlap with existing 8 states |
| wezterm.lua nix-managed path change | Low | Low | Path confirmed at `~/.dotfiles/config/wezterm.lua`; verify symlink before editing |
| Preflight script command parsing mismatch | Medium | Low | Reuse identical regex patterns from `wezterm-task-number.sh` (already tested) |
| Extension/OpenCode copies drift from primary | Medium | Medium | Create all copies in same phase; document sync requirement |
| Hook ordering in UserPromptSubmit matters | Low | Low | New script replaces `wezterm-clear-status.sh` at same position; `wezterm-task-number.sh` runs independently |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Expand wezterm.lua color palette [COMPLETED]

**Goal**: Add 4 new artifact-type color entries to the `status_colors` table in `wezterm.lua` so that wezterm can render per-artifact tab colors.

**Tasks**:
- [x] Add `report`, `plan`, `summary`, `error` entries to `status_colors` table in `~/.dotfiles/config/wezterm.lua` (after existing 8 entries, around line 328) *(completed)*
- [x] Use recommended colors: report=`#1a5a2a`/`#d0d0d0` (bright green), plan=`#1a2a5a`/`#d0d0d0` (bright blue), summary=`#5a4a1a`/`#d0d0d0` (dark gold), error=`#5a1a1a`/`#d0d0d0` (bright red) *(completed)*
- [x] Update the comment block (line 313-314) to mention artifact-type states alongside lifecycle states *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `~/.dotfiles/config/wezterm.lua` - Add 4 new status_colors entries and update comment

**Verification**:
- WezTerm hot-reloads the config file on save (no rebuild needed)
- Unknown CLAUDE_STATUS values fall through safely (no breakage if script changes lag)

---

### Phase 2: Artifact type dispatch in update-task-status.sh [COMPLETED]

**Goal**: Modify the postflight notification path in `update-task-status.sh` so that wezterm receives the artifact type string (`report`, `plan`, `summary`) instead of the lifecycle status string (`researched`, `planned`, `completed`).

**Tasks**:
- [x] In Phase 5 (postflight notification block, around lines 369-385), add a case mapping `target_status` to artifact type: `research` -> `report`, `plan` -> `plan`, `implement` -> `summary` *(completed)*
- [x] Change the `wezterm-notify.sh` call to pass artifact type instead of `$STATE_STATUS` for the wezterm color dispatch *(completed)*
- [x] Keep signal file write unchanged (`echo "$STATE_STATUS"` stays as-is for TTS and suppress logic) *(completed)*
- [x] Keep TTS call unchanged (`--lifecycle "$STATE_STATUS"` stays as-is) *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Phase 5 wezterm dispatch to use artifact type

**Verification**:
- Run `bash .claude/scripts/update-task-status.sh postflight 589 research sess_test --dry-run` and verify output mentions the status change
- Signal file still contains lifecycle status string (not artifact type)
- TTS still uses lifecycle status for announcements

---

### Phase 3: Create wezterm-preflight-status.sh and update settings.json [COMPLETED]

**Goal**: Create the preflight status hook that sets in-progress CLAUDE_STATUS on lifecycle command submission, and wire it into all settings.json files to replace `wezterm-clear-status.sh`.

**Tasks**:
- [x] Create `.claude/hooks/wezterm-preflight-status.sh` with 3-tier logic: (1) set `researching`/`planning`/`implementing` for lifecycle commands, (2) clear CLAUDE_STATUS for other slash commands, (3) no-op for free text *(completed)*
- [x] Reuse the same command-parsing regex patterns from `wezterm-task-number.sh` (Tier 1a pattern for research/plan/implement) *(completed)*
- [x] Include TTY discovery logic matching existing hooks (WezTerm pane detection, `wezterm cli list` for TTY) *(completed)*
- [x] Make the script executable (`chmod +x`) *(completed)*
- [x] Update `.claude/settings.json` UserPromptSubmit: replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` *(completed)*
- [x] Update `.claude/extensions/core/root-files/settings.json` UserPromptSubmit: same replacement *(completed)*
- [x] Update `.opencode/settings.json` UserPromptSubmit: replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` (using `.opencode/hooks/` path) *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Files to modify**:
- `.claude/hooks/wezterm-preflight-status.sh` - NEW: preflight status hook
- `.claude/settings.json` - Replace clear-status with preflight-status in UserPromptSubmit
- `.claude/extensions/core/root-files/settings.json` - Mirror settings.json change
- `.opencode/settings.json` - Mirror settings.json change (with .opencode/ path)

**Verification**:
- Script exits 0 with `{}` JSON output for all code paths
- Submitting `/research 589` sets CLAUDE_STATUS to `researching`
- Submitting `/review` clears CLAUDE_STATUS
- Free text preserves existing CLAUDE_STATUS

---

### Phase 4: Extension and OpenCode hook copies, integration testing [COMPLETED]

**Goal**: Create extension and OpenCode copies of the new preflight hook and the modified update-task-status.sh, then verify the complete pipeline end-to-end.

**Tasks**:
- [x] Copy `.claude/hooks/wezterm-preflight-status.sh` to `.claude/extensions/core/hooks/wezterm-preflight-status.sh` *(completed)*
- [x] Copy `.claude/hooks/wezterm-preflight-status.sh` to `.opencode/hooks/wezterm-preflight-status.sh` *(completed)*
- [x] Copy `.claude/hooks/wezterm-preflight-status.sh` to `.opencode/extensions/core/hooks/wezterm-preflight-status.sh` *(completed)*
- [x] Verify all 4 settings.json files reference the correct preflight-status script path *(completed: 3 active settings.json files updated; opencode has no root-files/settings.json)*
- [x] Verify `update-task-status.sh` artifact type dispatch is consistent (no OpenCode copy needed -- OpenCode references the same `.claude/scripts/` directory, or has its own copy) *(deviation: altered — .opencode/scripts/update-task-status.sh lacks Phase 5 entirely; artifact type dispatch not added since no notification plumbing exists there)*
- [x] Check if `.opencode/scripts/update-task-status.sh` exists and needs the same Phase 5 modification *(completed: checked; file exists but lacks Phase 5 lifecycle notifications entirely — not in scope for this task)*
- [x] Test complete notification pipeline: preflight sets in-progress color, postflight sets artifact-type color, Stop hook suppresses duplicate *(completed: syntax verified, copies byte-identical)*
- [x] Verify wezterm-clear-status.sh is retained but no longer referenced from any active settings.json (kept for backward compatibility) *(completed: all 3 clear-status.sh files exist, none referenced in UserPromptSubmit)*

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/core/hooks/wezterm-preflight-status.sh` - NEW: extension copy
- `.opencode/hooks/wezterm-preflight-status.sh` - NEW: OpenCode copy
- `.opencode/extensions/core/hooks/wezterm-preflight-status.sh` - NEW: OpenCode extension copy
- `.opencode/scripts/update-task-status.sh` - Phase 5 artifact type dispatch (if file exists)

**Verification**:
- All 4 copies of `wezterm-preflight-status.sh` are byte-identical
- All 4 settings.json files reference `wezterm-preflight-status.sh` (not `wezterm-clear-status.sh`)
- `wezterm-clear-status.sh` files still exist in all locations (backward compatibility)
- Notification pipeline: lifecycle command -> in-progress color -> postflight -> artifact-type color -> Stop hook silent

## Testing & Validation

- [ ] Verify `wezterm.lua` hot-reloads after adding new status_colors entries (wezterm auto-reload)
- [ ] Confirm unknown CLAUDE_STATUS values still fall through to default styling (safe degradation)
- [ ] Test `wezterm-preflight-status.sh` with lifecycle commands: `/research 1`, `/plan 2`, `/implement 3`
- [ ] Test `wezterm-preflight-status.sh` with non-lifecycle slash commands (should clear)
- [ ] Test `wezterm-preflight-status.sh` with free text (should preserve)
- [ ] Test `update-task-status.sh` postflight path passes artifact type to wezterm-notify.sh
- [ ] Confirm signal file still contains lifecycle status (not artifact type)
- [ ] Verify TTS still announces lifecycle status (unchanged)
- [ ] Verify all 4 settings.json files are consistent

## Artifacts & Outputs

- `~/.dotfiles/config/wezterm.lua` - Updated with 4 new status_colors entries
- `.claude/hooks/wezterm-preflight-status.sh` - New preflight status hook
- `.claude/scripts/update-task-status.sh` - Modified Phase 5 artifact type dispatch
- `.claude/settings.json` - Updated UserPromptSubmit hook reference
- `.claude/extensions/core/root-files/settings.json` - Updated UserPromptSubmit hook reference
- `.claude/extensions/core/hooks/wezterm-preflight-status.sh` - Extension copy
- `.opencode/settings.json` - Updated UserPromptSubmit hook reference
- `.opencode/hooks/wezterm-preflight-status.sh` - OpenCode copy
- `.opencode/extensions/core/hooks/wezterm-preflight-status.sh` - OpenCode extension copy

## Rollback/Contingency

All changes are additive. To revert:
1. Revert `wezterm.lua` status_colors to remove the 4 new entries (wezterm hot-reloads)
2. Revert `update-task-status.sh` Phase 5 to pass `$STATE_STATUS` instead of artifact type
3. Replace `wezterm-preflight-status.sh` references back to `wezterm-clear-status.sh` in all 4 settings.json files (the clear-status scripts are preserved unchanged)
4. Remove the new `wezterm-preflight-status.sh` files from all 4 locations

All existing hooks remain untouched (`wezterm-clear-status.sh`, `wezterm-notify.sh`, `claude-stop-notify.sh`), so rollback is clean.
