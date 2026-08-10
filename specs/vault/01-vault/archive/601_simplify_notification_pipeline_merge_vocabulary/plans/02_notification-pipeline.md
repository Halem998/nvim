# Implementation Plan: Simplify Notification Pipeline / Merge Vocabulary

- **Task**: 601 - simplify_notification_pipeline_merge_vocabulary
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: [reports/01_team-research.md]
- **Artifacts**: plans/02_notification-pipeline.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The WezTerm tab coloring and TTS notification pipeline has three confirmed bugs: (1) tab color resets to gray mid-workflow because the Stop hook fires during orchestrator pauses, (2) random TTS announcements during `--team` mode from intermediate Stop events, and (3) no dim-to-bold color transition because postflight maps lifecycle states to artifact-type vocabulary with different hues. This plan eliminates the signal file mechanism, replaces it with a workflow-active marker checked by the Stop hook, merges to a single lifecycle vocabulary, extracts shared TTY discovery boilerplate, deletes dead code, and propagates all changes to the 4 hook copy locations plus documentation. Definition of done: only lifecycle states drive tab coloring, Stop hook is silent during active workflows, TTS fires only from skill postflight via update-task-status.sh, and all 4 locations are synchronized.

### Research Integration

Team research (4 teammates, all converged) confirmed root causes and solution approach:
- Stop hook fires during mid-workflow orchestrator pauses; no signal file exists yet, no agent_id in stdin -> falls through to needs_input, overwriting in-progress color
- Dual vocabulary (lifecycle + artifact-type) prevents dim-to-bold visual transition
- `.postflight-pending` marker already exists for subagent blocking; workflow-active file should be a separate file since `.postflight-pending` serves a different purpose (force continuation) and is scoped per-task
- Critic recommended keeping workflow-active file through final Stop hook, clearing on next `UserPromptSubmit` via Tier 2
- Budget 4-5 hours across 28+ files

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the roadmap success metric "Zero stale references to removed files" by deleting `wezterm-clear-status.sh` and `lifecycle-notify.sh`, both of which are dead code. It also simplifies the infrastructure for future extension hot-reload work (Phase 2 roadmap).

## Goals & Non-Goals

**Goals**:
- Fix tab color reset during mid-workflow orchestrator pauses
- Eliminate random TTS announcements during `--team` mode
- Merge to single lifecycle vocabulary (researching/researched/planning/planned/implementing/completed/needs_input/blocked)
- Implement dim-to-bold color transition within same hue family per lifecycle phase
- Delete dead code: `wezterm-clear-status.sh`, `lifecycle-notify.sh`
- Extract TTY discovery boilerplate into shared `wezterm-utils.sh`
- Propagate all changes to all 4 hook locations and documentation

**Non-Goals**:
- Terminal abstraction layer (WezTerm is the only consumer)
- Making notifications an extension (it is foundational infrastructure)
- Event-sourcing notifications (hooks are already event-driven)
- File-polling (OSC 1337 push-based is correct)
- Redesigning the SubagentStop hook (`subagent-postflight.sh`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stop hook does not receive agent_id for subagent stops | M | M | Keep existing subagent detection logic as-is; workflow-active file handles the primary suppression case. Subagent detection is defense-in-depth. |
| ESC-cancel leaves workflow-active file orphaned | M | L | Tier 2 of `wezterm-preflight-status.sh` (non-lifecycle slash command) already clears state; add workflow-active cleanup there. Also `skill-refresh` can clean stale marker files. |
| Race condition between postflight and Stop hook | H | L | Keep workflow-active file through final Stop hook; clear on next `UserPromptSubmit` (not during postflight). |
| Copy divergence between 4 hook locations | M | M | Phase 4 explicitly copies primary hooks to all 3 locations after primary is validated. Use `diff` verification step. |
| Extension copy of update-task-status.sh already diverges from primary | M | H | Apply vocabulary merge changes only to PHASE 5 area which only exists in primary. Extension/opencode copies lack PHASE 5 and need no notification changes. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Workflow-Active Marker and Stop Hook Fix [COMPLETED]

**Goal**: Eliminate the signal file mechanism and replace it with a workflow-active marker file that suppresses the Stop hook during active workflows.

**Tasks**:
- [ ] Create workflow-active marker file in `update-task-status.sh` preflight path
  - At the start of PHASE 1 (before state.json update), when `operation == "preflight"`:
  - Write `.claude/tmp/workflow-active` containing the task number and timestamp
  - `mkdir -p "$SCRIPT_DIR/../tmp" && echo "$task_number $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SCRIPT_DIR/../tmp/workflow-active"`
- [ ] Remove signal file mechanism from `update-task-status.sh` PHASE 5
  - Delete the line: `echo "$STATE_STATUS" > "$SCRIPT_DIR/../tmp/lifecycle-signal"`
  - Keep the PHASE 5 section but remove the signal file write
- [ ] Rewrite `claude-stop-notify.sh` to check workflow-active marker
  - Remove all signal file logic (SIGNAL_FILE, SIGNAL_CONSUMED, atomic mv pattern)
  - Add workflow-active check at top (after subagent detection):
    ```
    WORKFLOW_ACTIVE="$SCRIPT_DIR/../tmp/workflow-active"
    if [[ -f "$WORKFLOW_ACTIVE" ]]; then
        exit_success
    fi
    ```
  - Keep subagent detection logic (defense-in-depth)
  - Keep needs_input wezterm dispatch for non-workflow stops
  - Remove TTS dispatch from Stop hook (Stop should only set `needs_input` wezterm color, no TTS)
- [ ] Add workflow-active cleanup to `wezterm-preflight-status.sh` Tier 2
  - In the `SHOULD_CLEAR` block (non-lifecycle slash commands), add:
    `rm -f "$SCRIPT_DIR/../tmp/workflow-active" 2>/dev/null || true`
  - This handles ESC-cancel edge case and normal non-lifecycle prompt cleanup
- [ ] Verify Stop hook receives proper stdin JSON by adding temporary debug log
  - Add a single debug line at the top: `echo "[$(date -Iseconds)] STDIN: $STDIN_JSON" >> "$SCRIPT_DIR/../tmp/stop-debug.log"`
  - This will be removed in Phase 3 cleanup

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add workflow-active write in preflight, remove signal file write
- `.claude/hooks/claude-stop-notify.sh` - Replace signal file with workflow-active check, remove TTS
- `.claude/hooks/wezterm-preflight-status.sh` - Add workflow-active cleanup in Tier 2

**Verification**:
- Manual: Run `/research N` and verify Stop hook does not overwrite tab color during orchestrator pauses
- Manual: Verify non-lifecycle slash commands clear the workflow-active file
- Check: `ls .claude/tmp/workflow-active` exists during active workflow, absent after non-lifecycle command

---

### Phase 2: Merge to Lifecycle Vocabulary and Fix Colors [COMPLETED]

**Goal**: Eliminate artifact-type vocabulary (report/plan/summary/error) from the notification pipeline and use only lifecycle states. Fix dim-to-bold color transitions in wezterm.lua.

**Tasks**:
- [ ] Simplify PHASE 5 of `update-task-status.sh` to use lifecycle vocabulary
  - Replace the artifact-type mapping block:
    ```
    # OLD: case "$target_status" in research) WEZTERM_STATUS="report" ;; ...
    # NEW: Pass lifecycle STATE_STATUS directly
    bash "$wezterm_script" "$STATE_STATUS" &
    ```
  - The `$STATE_STATUS` variable already contains `researched`, `planned`, or `completed`
- [ ] Update `wezterm.lua` status_colors table
  - Remove artifact-type entries: `report`, `plan`, `summary`, `error`
  - Fix dim-to-bold transitions within same hue family:
    - Research: `researching` = dim green bg + dim fg, `researched` = bright green bg + bright fg
    - Planning: `planning` = dim blue bg + dim fg, `planned` = bright blue bg + bright fg
    - Implementing: `implementing` = dim gold bg + dim fg, `completed` = bright gold bg + bright fg
  - Updated color values (same hue, different brightness):
    ```lua
    needs_input  = { bg = "#3a3a3a", fg = "#d0d0d0" },  -- gray
    researching  = { bg = "#1a3a1a", fg = "#607060" },   -- dim green
    researched   = { bg = "#2a5a2a", fg = "#d0d0d0" },   -- bright green
    planning     = { bg = "#1a1a3a", fg = "#606070" },    -- dim blue
    planned      = { bg = "#2a2a6a", fg = "#d0d0d0" },   -- bright blue
    implementing = { bg = "#3a3a1a", fg = "#707060" },    -- dim gold
    completed    = { bg = "#5a5a2a", fg = "#d0d0d0" },   -- bright gold
    blocked      = { bg = "#5a2a2a", fg = "#d0d0d0" },   -- red
    ```
  - Remove the comment block referencing artifact-type states
- [ ] Update `wezterm-notify.sh` header comments to remove artifact-type references
  - Remove references to `report`, `plan`, `summary`, `error` from usage docs
  - Update the color mapping comment to list only lifecycle states
- [ ] Update `tts-notify.sh` header comments if needed
  - No functional changes; TTS already speaks lifecycle status names

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Simplify PHASE 5 wezterm dispatch to use `$STATE_STATUS`
- `~/.dotfiles/config/wezterm.lua` - Replace status_colors table with lifecycle-only entries and dim-to-bold colors
- `.claude/hooks/wezterm-notify.sh` - Update header comments
- `.claude/hooks/tts-notify.sh` - Update header comments (if artifact-type references exist)

**Verification**:
- `grep -c "report\|summary\|error" wezterm.lua` returns 0 (no artifact-type entries in status_colors)
- `grep "WEZTERM_STATUS" update-task-status.sh` shows only `"$STATE_STATUS"` assignment
- Visual: Tab transitions from dim to bright within same hue when lifecycle completes

---

### Phase 3: Delete Dead Code and Extract TTY Discovery [COMPLETED]

**Goal**: Remove unused scripts, extract shared TTY discovery boilerplate into `wezterm-utils.sh`, and update hooks to source it.

**Tasks**:
- [ ] Delete `wezterm-clear-status.sh` from `.claude/hooks/`
  - Verify it is not referenced in `.claude/settings.json` (confirmed: not present)
  - `rm .claude/hooks/wezterm-clear-status.sh`
- [ ] Delete `lifecycle-notify.sh` from `.claude/scripts/`
  - Verify no active callers remain (confirmed: deprecated no-op stub, Stage 8a blocks already removed from skills)
  - `rm .claude/scripts/lifecycle-notify.sh`
- [ ] Remove temporary debug log from `claude-stop-notify.sh` (added in Phase 1)
- [ ] Create `.claude/hooks/wezterm-utils.sh` with shared functions
  - `get_pane_tty()`: Returns the TTY path for the current WezTerm pane
    ```bash
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
    ```
  - `set_user_var()`: Sets a WezTerm user variable via OSC 1337
    ```bash
    set_user_var() {
        local name="$1"
        local value="${2:-}"
        local tty="${3:-}"
        if [[ -z "$tty" ]]; then
            tty=$(get_pane_tty) || return 0
        fi
        local encoded
        encoded=$(echo -n "$value" | base64 | tr -d '\n')
        printf '\033]1337;SetUserVar=%s=%s\007' "$name" "$encoded" > "$tty"
    }
    ```
- [ ] Refactor `wezterm-notify.sh` to source `wezterm-utils.sh`
  - Replace inline TTY discovery (lines 50-63) with `source "$SCRIPT_DIR/wezterm-utils.sh"` and `PANE_TTY=$(get_pane_tty) || exit_success`
  - Replace inline OSC write (lines 66-73) with `set_user_var "CLAUDE_STATUS" "$STATUS" "$PANE_TTY"`
- [ ] Refactor `wezterm-preflight-status.sh` to source `wezterm-utils.sh`
  - Replace inline TTY discovery (lines 66-74) with `source "$SCRIPT_DIR/wezterm-utils.sh"` and `PANE_TTY=$(get_pane_tty) || exit_success`
  - Replace inline OSC writes (lines 79-83) with `set_user_var` calls

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/hooks/wezterm-clear-status.sh` - DELETE
- `.claude/scripts/lifecycle-notify.sh` - DELETE
- `.claude/hooks/claude-stop-notify.sh` - Remove debug log line
- `.claude/hooks/wezterm-utils.sh` - CREATE (new shared utility)
- `.claude/hooks/wezterm-notify.sh` - Refactor to use wezterm-utils.sh
- `.claude/hooks/wezterm-preflight-status.sh` - Refactor to use wezterm-utils.sh

**Verification**:
- `ls .claude/hooks/wezterm-clear-status.sh` fails (deleted)
- `ls .claude/scripts/lifecycle-notify.sh` fails (deleted)
- `ls .claude/hooks/wezterm-utils.sh` succeeds (created)
- Run `bash -n .claude/hooks/wezterm-notify.sh` - no syntax errors
- Run `bash -n .claude/hooks/wezterm-preflight-status.sh` - no syntax errors
- Run `bash -n .claude/hooks/wezterm-utils.sh` - no syntax errors
- Manual: `/research N` still produces correct tab coloring

---

### Phase 4: Propagate to All Copy Locations and Update Documentation [COMPLETED]

**Goal**: Synchronize all changes to the 3 remaining hook/script copy locations and update documentation files.

**Tasks**:
- [ ] Copy updated hooks to `.claude/extensions/core/hooks/`
  - Copy: `claude-stop-notify.sh`, `wezterm-notify.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh`
  - Delete: `wezterm-clear-status.sh`
- [ ] Copy updated hooks to `.opencode/hooks/`
  - Copy: `claude-stop-notify.sh`, `wezterm-notify.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh`
  - Delete: `wezterm-clear-status.sh`
- [ ] Copy updated hooks to `.opencode/extensions/core/hooks/`
  - Copy: `claude-stop-notify.sh`, `wezterm-notify.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh`
  - Delete: `wezterm-clear-status.sh`
- [ ] Verify no PHASE 5 notification changes needed in extension/opencode copies of `update-task-status.sh`
  - The extension copy (`.claude/extensions/core/scripts/update-task-status.sh`) does NOT have PHASE 5 (confirmed by diff)
  - The opencode copy (`.opencode/scripts/update-task-status.sh`) also lacks PHASE 5
  - No changes needed to these copies for vocabulary merge; only the primary `.claude/scripts/update-task-status.sh` has PHASE 5
- [ ] Add workflow-active preflight write to extension/opencode copies of `update-task-status.sh`
  - Both copies need the same `workflow-active` file creation in their preflight path (so the Stop hook works regardless of which update-task-status.sh runs)
- [ ] Update documentation: `.claude/context/project/neovim/hooks/wezterm-integration.md`
  - Replace dual-vocabulary description with lifecycle-only vocabulary
  - Remove signal file documentation
  - Add workflow-active marker documentation
  - Update color table to match new lifecycle-only colors
  - Document `wezterm-utils.sh` shared functions
- [ ] Update documentation: `.claude/context/project/neovim/guides/tts-stt-integration.md`
  - Remove references to artifact-type vocabulary in TTS
  - Update lifecycle mode description
  - Note that TTS fires from update-task-status.sh postflight only (not from Stop hook)
- [ ] Copy updated documentation to extension copies
  - `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md`
  - `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- [ ] Verify all 4 hook locations are synchronized
  - `diff .claude/hooks/claude-stop-notify.sh .claude/extensions/core/hooks/claude-stop-notify.sh`
  - `diff .claude/hooks/claude-stop-notify.sh .opencode/hooks/claude-stop-notify.sh`
  - `diff .claude/hooks/claude-stop-notify.sh .opencode/extensions/core/hooks/claude-stop-notify.sh`
  - Repeat for: `wezterm-notify.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh`
  - Verify `wezterm-clear-status.sh` is absent from all 4 locations

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/core/hooks/claude-stop-notify.sh` - Copy from primary
- `.claude/extensions/core/hooks/wezterm-notify.sh` - Copy from primary
- `.claude/extensions/core/hooks/wezterm-preflight-status.sh` - Copy from primary
- `.claude/extensions/core/hooks/wezterm-utils.sh` - Copy from primary (new)
- `.claude/extensions/core/hooks/wezterm-clear-status.sh` - DELETE
- `.opencode/hooks/claude-stop-notify.sh` - Copy from primary
- `.opencode/hooks/wezterm-notify.sh` - Copy from primary
- `.opencode/hooks/wezterm-preflight-status.sh` - Copy from primary
- `.opencode/hooks/wezterm-utils.sh` - Copy from primary (new)
- `.opencode/hooks/wezterm-clear-status.sh` - DELETE
- `.opencode/extensions/core/hooks/claude-stop-notify.sh` - Copy from primary
- `.opencode/extensions/core/hooks/wezterm-notify.sh` - Copy from primary
- `.opencode/extensions/core/hooks/wezterm-preflight-status.sh` - Copy from primary
- `.opencode/extensions/core/hooks/wezterm-utils.sh` - Copy from primary (new)
- `.opencode/extensions/core/hooks/wezterm-clear-status.sh` - DELETE
- `.claude/extensions/core/scripts/update-task-status.sh` - Add workflow-active preflight
- `.opencode/scripts/update-task-status.sh` - Add workflow-active preflight
- `.claude/context/project/neovim/hooks/wezterm-integration.md` - Update docs
- `.claude/context/project/neovim/guides/tts-stt-integration.md` - Update docs
- `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` - Copy docs
- `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - Copy docs

**Verification**:
- All 4 hook locations have identical versions of modified hooks (diff exits 0)
- `wezterm-clear-status.sh` absent from all 4 locations
- `wezterm-utils.sh` present in all 4 locations
- Documentation files describe only lifecycle vocabulary, no artifact-type references
- `grep -rn "report\|summary\|error" .claude/context/project/neovim/hooks/wezterm-integration.md` returns 0 artifact-type hits in status color context

## Testing & Validation

- [ ] Run `bash -n` syntax check on all modified shell scripts (no syntax errors)
- [ ] Verify `wezterm-clear-status.sh` and `lifecycle-notify.sh` are deleted from all locations
- [ ] Verify `wezterm-utils.sh` exists in all 4 hook locations
- [ ] Verify all 4 hook locations are synchronized (diff exits 0 for each hook file)
- [ ] Manual test: Run `/research N` and observe tab stays dim green during research, transitions to bright green on completion
- [ ] Manual test: Run `/plan N` and observe dim blue to bright blue transition
- [ ] Manual test: Run `/implement N` and observe dim gold to bright gold transition
- [ ] Manual test: Stop hook sets `needs_input` gray only when no workflow-active file exists
- [ ] Manual test: Non-lifecycle slash command (e.g., `/todo`) clears workflow-active file
- [ ] Manual test: `--team` mode does not produce random TTS announcements
- [ ] Verify `grep -rn "lifecycle-signal" .claude/` returns no references (signal file fully removed)
- [ ] Verify `grep -rn "wezterm-clear-status" .claude/settings.json` returns no references

## Artifacts & Outputs

- `plans/02_notification-pipeline.md` (this plan)
- Modified hooks in `.claude/hooks/` (primary, 5 files modified, 1 created, 1 deleted)
- Modified hooks in `.claude/extensions/core/hooks/` (copies)
- Modified hooks in `.opencode/hooks/` (copies)
- Modified hooks in `.opencode/extensions/core/hooks/` (copies)
- New shared utility: `.claude/hooks/wezterm-utils.sh`
- Modified script: `.claude/scripts/update-task-status.sh`
- Modified config: `~/.dotfiles/config/wezterm.lua`
- Updated docs: `wezterm-integration.md`, `tts-stt-integration.md` (2 copies each)
- Deleted: `wezterm-clear-status.sh` (4 copies), `lifecycle-notify.sh` (1 copy)

## Rollback/Contingency

All changes are to shell scripts and a Lua config file with no build artifacts. Rollback via `git checkout -- .claude/hooks/ .claude/scripts/update-task-status.sh .claude/extensions/core/hooks/ .opencode/hooks/ .opencode/extensions/core/hooks/ ~/.dotfiles/config/wezterm.lua`. The deleted files (`wezterm-clear-status.sh`, `lifecycle-notify.sh`) are confirmed dead code with no active callers, so their deletion is safe. If the workflow-active marker causes issues (e.g., orphaned files preventing Stop hook), `skill-refresh` can clean up stale marker files as it already handles `.postflight-pending` cleanup.
