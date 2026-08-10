# Research Report: Task #589

**Task**: 589 - wezterm_artifact_colors_preflight
**Started**: 2026-05-21T02:00:00Z
**Completed**: 2026-05-21T02:30:00Z
**Effort**: 0.5 hours
**Dependencies**: 588
**Sources/Inputs**:
- `/home/benjamin/.dotfiles/config/wezterm.lua` - Current wezterm configuration (nix-managed)
- `/home/benjamin/.config/nvim/.claude/hooks/claude-stop-notify.sh` - Stop hook (created by task 588)
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-notify.sh` - OSC 1337 dispatch script
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-clear-status.sh` - UserPromptSubmit clear hook
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-task-number.sh` - UserPromptSubmit task number hook
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` - Centralized status+notification script
- `/home/benjamin/.config/nvim/.claude/settings.json` - Hook wiring configuration
- `specs/588_refactor_notification_signal_stop_hook/summaries/01_signal-stop-refactor-summary.md` - Task 588 completion summary
- `specs/588_refactor_notification_signal_stop_hook/plans/01_signal-stop-refactor.md` - Task 588 plan
**Artifacts**:
- `specs/589_wezterm_artifact_colors_preflight/reports/01_wezterm-artifact-colors.md` (this file)
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- Task 588 implemented a dual-dispatch notification architecture: postflight writes a lifecycle signal file and immediately fires TTS+wezterm; the Stop hook consumes the signal to suppress duplicates. Task 589 builds directly on this foundation.
- The current `wezterm.lua` already handles 8 status values (needs_input, researched, planned, completed, blocked, researching, planning, implementing) in a `status_colors` table via `CLAUDE_STATUS` user variable.
- Task 589 requires three distinct changes: (1) expand the `status_colors` table in `wezterm.lua` with per-artifact-type colors; (2) add preflight tab coloring via `UserPromptSubmit` hook; (3) include artifact type in the signal file so wezterm can distinguish artifact flavors.
- The signal file currently contains only a status string (e.g., `"researched"`). Adding artifact type requires a format change — either a two-line format or a JSON object in the signal file, with corresponding read logic updates in `claude-stop-notify.sh` and `wezterm-notify.sh` invocations.
- The `UserPromptSubmit` preflight coloring is simpler: parse the command, write CLAUDE_STATUS for in-progress states (`researching`, `planning`, `implementing`) immediately when the user submits a lifecycle command, before Claude begins work.
- The `wezterm.lua` at `~/.dotfiles/config/wezterm.lua` is nix-managed and is the sole file that needs color mapping changes; no NixOS rebuild is needed (wezterm watches the file and hot-reloads).

## Context & Scope

Task 589 expands the wezterm notification system established by task 588 in two orthogonal directions:

1. **Per-artifact-type colors** — When a research report is created, the tab should show green. When a plan is created, blue. When a summary is created, gold. When an error occurs, red. This requires the signal file to carry artifact type, not just lifecycle status.

2. **Preflight in-progress coloring** — When the user submits `/research N`, `/plan N`, or `/implement N`, the tab should immediately show a dim in-progress color (researching=dim green, planning=dim blue, implementing=dim yellow) _before_ Claude starts work. Currently, in-progress colors only appear after `update-task-status.sh preflight` runs (which is after subagent invocation begins). The `UserPromptSubmit` hook fires synchronously before Claude processes the prompt, making it the right place to set early in-progress state.

**Scope boundaries**:
- `wezterm.lua` is nix-managed; changes are made directly to `~/.dotfiles/config/wezterm.lua`. No NixOS rebuild needed (hot-reload).
- The `update-task-status.sh` Phase 5 (postflight) logic and the signal file format are within scope.
- The `wezterm-notify.sh` call signature may need to accept an optional artifact type argument.
- The `claude-stop-notify.sh` needs to pass artifact type when re-dispatching on signal consume (if that path requires it — see Findings for analysis).
- TTS is out of scope (task only mentions wezterm tab coloring).

## Findings

### 1. Current Status Colors in wezterm.lua

The `format-tab-title` event handler in `~/.dotfiles/config/wezterm.lua` (lines 319-328) defines:

```
needs_input  -> bg=#3a3a3a, fg=#d0d0d0  (gray)
researched   -> bg=#2a4a2a, fg=#d0d0d0  (dark green)
planned      -> bg=#2a2a5a, fg=#d0d0d0  (dark blue)
completed    -> bg=#1a5a1a, fg=#d0d0d0  (bright green)
blocked      -> bg=#5a2a2a, fg=#d0d0d0  (dark red)
researching  -> bg=#2a4a2a, fg=#808080  (dim green, in-progress)
planning     -> bg=#2a2a5a, fg=#808080  (dim blue, in-progress)
implementing -> bg=#3a3a1a, fg=#808080  (dim yellow, in-progress)
```

Unknown values fall through to default styling (safe degradation). The existing 8-entry table already maps _lifecycle states_. Task 589 wants to add _artifact-type-specific_ states for completed artifacts. The mapping requested is:

- `report` (research artifact) → green (similar to `researched` but distinct — possibly a brighter or subtly different green)
- `plan` (plan artifact) → blue (similar to `planned` but distinct)
- `summary` (implementation summary) → gold
- `error` (error condition) → red (similar to `blocked` but distinct)
- `needs_input` already exists → gray

The key design question is whether these are separate `CLAUDE_STATUS` values (e.g., `"report"`, `"plan"`, `"summary"`, `"error"`) passed directly through `wezterm-notify.sh`, or whether the existing lifecycle values (`researched`, `planned`, `completed`) are decorated with artifact type information.

### 2. Signal File Format (Current)

The signal file at `.claude/tmp/lifecycle-signal` currently contains a single line: the STATE_STATUS string (e.g., `"researched"`, `"planned"`, `"completed"`). Written in `update-task-status.sh` Phase 5:

```bash
echo "$STATE_STATUS" > "$SCRIPT_DIR/../tmp/lifecycle-signal"
```

Read in `claude-stop-notify.sh`:
```bash
STATUS=$(cat "$SIGNAL_CONSUMED" 2>/dev/null || echo "")
rm -f "$SIGNAL_CONSUMED"
# Signal was consumed -- postflight already announced TTS+wezterm
exit_success
```

The Stop hook reads the status but currently uses it only for silence (the suppress path exits without acting). The artifact type would need to be carried in the signal file only if the Stop hook needs to call `wezterm-notify.sh` with the artifact type. Since the suppress path is a no-op, artifact type in the signal file is mainly useful if a future no-signal path (needs_input fallback) needs to know the type. For the current scope of task 589, the artifact type is needed only by `update-task-status.sh` when it calls `wezterm-notify.sh`, not by the Stop hook suppress path.

**Design options for signal file format**:
- **Option A**: Two-line format — line 1 = status, line 2 = artifact_type. Simple, compatible.
- **Option B**: `STATUS:artifact_type` colon-delimited on one line. Simple parsing.
- **Option C**: JSON object `{"status": "researched", "artifact": "report"}`. Most extensible, requires jq.
- **Option D**: Keep signal file as-is (status only); pass artifact type as a second argument to `wezterm-notify.sh` directly from `update-task-status.sh` Phase 5.

**Recommendation**: Option D (no signal file format change) is simplest. The signal file suppress pattern only needs to exist to prevent duplicate dispatch. The artifact type is passed directly to `wezterm-notify.sh` as `"$STATE_STATUS_$ARTIFACT_TYPE"` or as a separate argument. The `wezterm-notify.sh` script already accepts a STATUS argument; adding a second argument for artifact type is clean. For example: `bash wezterm-notify.sh "researched" "report"` and the script concatenates them to form the CLAUDE_STATUS value `"researched_report"` or just passes `"report"` as the value. The most straightforward approach: use the artifact type directly as the `CLAUDE_STATUS` value for completed artifact events (`report`, `plan`, `summary`) while keeping lifecycle-only values for the other states.

### 3. Artifact Type Detection in update-task-status.sh

The script maps `operation:target_status` to STATE_STATUS. When `operation=postflight` and `target_status=research`, STATE_STATUS is `"researched"`. The artifact type can be inferred from `target_status`:

```
postflight:research   -> artifact_type = "report"
postflight:plan       -> artifact_type = "plan"
postflight:implement  -> artifact_type = "summary"
```

This mapping is already implicit in the status mapping table. No new input is needed — the script knows which artifact type was just created from its existing parameters.

### 4. wezterm-notify.sh Call Signature

Currently: `bash wezterm-notify.sh [STATUS]`

To support artifact-type colors for postflight events, the simplest approach is to use compound or separate status values. Two sub-options:

- **Sub-option 4a**: Pass the artifact type directly as STATUS. For example, call `bash wezterm-notify.sh "report"` after research postflight, `bash wezterm-notify.sh "plan"` after plan postflight, `bash wezterm-notify.sh "summary"` after implement postflight. The `wezterm.lua` maps `report`, `plan`, `summary` to their respective colors. This is maximally simple: no argument count change needed.
- **Sub-option 4b**: Pass both lifecycle status and artifact type: `bash wezterm-notify.sh "researched" "report"`. The script combines them or preferentially uses artifact type for CLAUDE_STATUS. This preserves the lifecycle state in the signal file for TTS but uses artifact type for wezterm color.

**Recommendation**: Sub-option 4a is preferred. The `CLAUDE_STATUS` value for postflight events becomes the artifact type string directly (`report`, `plan`, `summary`). The wezterm.lua adds entries for these in status_colors. The signal file continues to contain the lifecycle status string (unchanged). The `wezterm-notify.sh` call in Phase 5 becomes:

```bash
# Map target_status to artifact type for wezterm color
case "$target_status" in
  research)   ARTIFACT_STATUS="report" ;;
  plan)       ARTIFACT_STATUS="plan" ;;
  implement)  ARTIFACT_STATUS="summary" ;;
  *)          ARTIFACT_STATUS="$STATE_STATUS" ;;  # fallback to lifecycle status
esac
bash "$wezterm_script" "$ARTIFACT_STATUS" &
```

### 5. Preflight Tab Coloring via UserPromptSubmit Hook

The `UserPromptSubmit` hook currently has two scripts:
1. `wezterm-task-number.sh` — Sets TASK_NUMBER based on parsed command
2. `wezterm-clear-status.sh` — Clears CLAUDE_STATUS (resets color)

The task requests adding preflight coloring: when the user submits `/research N`, `/plan N`, or `/implement N`, immediately set CLAUDE_STATUS to the in-progress state (`researching`, `planning`, `implementing`) rather than clearing it to empty.

The current `wezterm-clear-status.sh` unconditionally clears CLAUDE_STATUS. The new behavior needs to:
- Parse the prompt for lifecycle commands
- Set CLAUDE_STATUS to the appropriate in-progress state instead of clearing
- Fall back to clearing for non-lifecycle commands

**Implementation approach**: Either modify `wezterm-clear-status.sh` to conditionally set (instead of always clear), or create a new script `wezterm-preflight-status.sh` that sets the in-progress state and call it instead of (or alongside) `wezterm-clear-status.sh`.

The `wezterm-task-number.sh` already has all the command-parsing logic (3-tier logic). The in-progress state detection follows the same pattern:

```
/research N  ->  CLAUDE_STATUS = "researching"
/plan N      ->  CLAUDE_STATUS = "planning"
/implement N ->  CLAUDE_STATUS = "implementing"
other /cmd   ->  CLAUDE_STATUS = "" (clear)
free text    ->  CLAUDE_STATUS unchanged (preserve)
```

The simplest approach: replace `wezterm-clear-status.sh` call with a new `wezterm-set-status.sh` that handles all cases (set in-progress on lifecycle commands, clear on other slash commands, no-op on free text). This eliminates the redundant clear step and centralizes UserPromptSubmit status logic.

The settings.json hook entry would change from calling `wezterm-clear-status.sh` to calling the new `wezterm-set-status.sh`.

**Alternative**: Modify `wezterm-clear-status.sh` in-place to add conditional logic. This is simpler (no settings.json change) but the file's name becomes misleading.

**Recommendation**: Create new `wezterm-preflight-status.sh` that sets in-progress state on lifecycle commands and clears otherwise. This is cleaner and the name reflects the actual behavior. Update `settings.json` to replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` in the UserPromptSubmit hook. Keep `wezterm-clear-status.sh` as-is for backward compatibility (it may be called from other places).

### 6. New Color Palette for wezterm.lua

Requested colors:
- `report` (research done) → green (distinct from `researched`)
- `plan` (plan done) → blue (distinct from `planned`)
- `summary` (implement done) → gold
- `error` → red
- `needs_input` → gray (already exists)

Color design notes:
- `researched` is already `#2a4a2a` (dark green, dim fg). `report` should be slightly brighter to distinguish.
- `planned` is already `#2a2a5a` (dark blue). `plan` could be a slightly more saturated blue.
- `completed` is `#1a5a1a` (bright green). `summary` should be gold (task description says gold).
- `error` is distinct from `blocked` (`#5a2a2a` dark red). Could use a brighter/different red.
- The existing scheme uses hex colors with the pattern `#XaYbZc`. Gold would be something like `#5a4a1a` or `#4a3a1a` (dark gold-brown) for a muted terminal color. A brighter option: `#5a4a00`.

Proposed new entries in `status_colors`:
```lua
report   = { bg = "#1a5a2a", fg = "#d0d0d0" },  -- bright green (artifact created)
plan     = { bg = "#1a2a5a", fg = "#d0d0d0" },  -- bright blue (artifact created)
summary  = { bg = "#5a4a1a", fg = "#d0d0d0" },  -- dark gold (artifact created)
error    = { bg = "#5a1a1a", fg = "#d0d0d0" },  -- bright red (error occurred)
```

Note: `summary` uses gold to distinguish from `completed` (bright green) since both represent implementation work.

### 7. Extension and OpenCode Parity

Task 588 required changes in 4 settings.json files and 2 extension copies of `wezterm-notify.sh`. Task 589 should follow the same parity pattern:
- New `wezterm-preflight-status.sh` needs a copy in `.claude/extensions/core/hooks/`
- `settings.json` change (replacing `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` in UserPromptSubmit) needs to be mirrored in:
  - `.claude/extensions/core/root-files/settings.json`
  - `.opencode/settings.json` (if it has a UserPromptSubmit hook)
  - `.opencode/extensions/core/root-files/settings.json` (if applicable)
- `wezterm.lua` color changes affect both Claude Code and OpenCode since they share the same wezterm instance

### 8. wezterm.lua Hot Reload

WezTerm watches its config file and automatically reloads on change. Since `~/.dotfiles/config/wezterm.lua` is nix-managed (symlinked or managed by home-manager), direct edits to the file will take effect immediately without any rebuild. Verification is possible by checking `wezterm ls-fonts` or `wezterm --version` to confirm reload.

## Decisions

1. **CLAUDE_STATUS values for postflight artifact events**: Use the artifact type string directly (`report`, `plan`, `summary`) rather than appending to lifecycle status. This keeps the status_colors table clean and avoids compound string parsing in wezterm.lua.

2. **Signal file format**: Keep signal file as status-only (no change to format or consumer). Artifact type is passed directly to `wezterm-notify.sh` in Phase 5 of `update-task-status.sh`, separate from the signal file content.

3. **Preflight coloring approach**: Create new `wezterm-preflight-status.sh` hook that replaces `wezterm-clear-status.sh` in UserPromptSubmit. Same command-parsing logic as `wezterm-task-number.sh`, different output target (CLAUDE_STATUS vs TASK_NUMBER).

4. **wezterm-clear-status.sh disposition**: Keep existing script as-is (backward compatibility). Replace its reference in `settings.json` with the new script.

5. **`error` status value**: Add `error` as a new CLAUDE_STATUS value with a distinct red. Future work can write `bash wezterm-notify.sh "error"` from error-handling scripts when appropriate.

## Recommendations

**Phase 1 — wezterm.lua color expansion** (standalone, no dependencies):
- Add `report`, `plan`, `summary`, `error` entries to `status_colors` table in `~/.dotfiles/config/wezterm.lua` (lines 319-328)
- Suggested palette: report=`#1a5a2a` (bright green), plan=`#1a2a5a` (bright blue), summary=`#5a4a1a` (dark gold), error=`#5a1a1a` (bright red)
- Update the comment block listing supported states

**Phase 2 — Artifact type dispatch in update-task-status.sh** (depends on Phase 1):
- In Phase 5 of `update-task-status.sh`, map `target_status` to artifact type
- Pass artifact type as STATUS to `wezterm-notify.sh` call (replace `"$STATE_STATUS"` with artifact type)
- Keep signal file write unchanged (signal file still contains lifecycle STATE_STATUS for TTS)

**Phase 3 — Create wezterm-preflight-status.sh and update settings.json** (standalone):
- Create `.claude/hooks/wezterm-preflight-status.sh` with 3-tier logic (set/clear/no-op based on prompt)
- Update `.claude/settings.json`: replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` in UserPromptSubmit hook
- Create extension copy: `.claude/extensions/core/hooks/wezterm-preflight-status.sh`
- Update `.claude/extensions/core/root-files/settings.json`
- Check `.opencode/settings.json` for UserPromptSubmit hook and mirror if present

**Verification**:
- After Phase 1: wezterm hot-reloads; simulate `SetUserVar=CLAUDE_STATUS=report` via OSC sequence and verify tab color changes to bright green
- After Phase 2: run `update-task-status.sh postflight N research sess_test` and observe tab color changes to green (`report`) not dark green (`researched`)
- After Phase 3: submit `/research 589` and observe tab immediately shows dim green (`researching`) before Claude begins work

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Artifact status values conflict with lifecycle values | Medium | Use distinct strings (`report`, `plan`, `summary`) that don't overlap with existing states |
| wezterm.lua nix-managed path differs from expected | Low | Confirmed path is `~/.dotfiles/config/wezterm.lua`; verify symlink before editing |
| `wezterm-preflight-status.sh` command parsing mismatches | Low | Reuse same regex patterns from `wezterm-task-number.sh` (already tested and working) |
| Extension copies drift from primary | Medium | Create copies in same implementation phase; document sync requirement as task 588 did |
| UserPromptSubmit hook ordering matters | Low | New script replaces `wezterm-clear-status.sh` in the hook list; `wezterm-task-number.sh` still runs independently |
| TTS not announcing artifact type | None | Task explicitly says wezterm only; TTS is out of scope |

## Appendix

### File Inventory for Implementation

| File | Change | Priority |
|------|--------|----------|
| `~/.dotfiles/config/wezterm.lua` | Add 4 new status_colors entries | Phase 1 |
| `.claude/scripts/update-task-status.sh` | Phase 5: map target_status to artifact type for wezterm-notify.sh | Phase 2 |
| `.claude/hooks/wezterm-preflight-status.sh` | NEW: set in-progress CLAUDE_STATUS on UserPromptSubmit | Phase 3 |
| `.claude/settings.json` | Replace `wezterm-clear-status.sh` with `wezterm-preflight-status.sh` | Phase 3 |
| `.claude/extensions/core/hooks/wezterm-preflight-status.sh` | NEW: extension copy | Phase 3 |
| `.claude/extensions/core/root-files/settings.json` | Mirror settings.json change | Phase 3 |
| `.opencode/settings.json` | Mirror UserPromptSubmit hook if present | Phase 3 |

### Current status_colors Table (wezterm.lua lines 319-328)

Existing 8-entry mapping serves as the foundation. New entries extend the same pattern with distinct semantic values for artifact types. No existing entries need modification.

### UserPromptSubmit Hook Command Patterns

From `wezterm-task-number.sh` (reuse in new script):
- Tier 1 (set task): `/research|plan|implement|revise|spawn` + task spec
- Tier 2 (clear): Any other slash command
- Tier 3 (no-op): Free text

New script adapts Tier 1 to map commands to in-progress states:
- `/research N` → `CLAUDE_STATUS = "researching"`
- `/plan N` → `CLAUDE_STATUS = "planning"`
- `/implement N` → `CLAUDE_STATUS = "implementing"`
- Other `/cmd` → `CLAUDE_STATUS = ""` (clear)
- Free text → no change
