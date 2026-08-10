# Research Report: Task #95

**Task**: 95 - Remove ineffective changes from tasks 92 and 94
**Date**: 2026-02-24
**Focus**: Identify changes from tasks 92 and 94 that are ineffective at fixing the WezTerm new tab directory issue and add unnecessary complexity

## Summary

Tasks 92 and 94 together made 4 distinct changes across 4 files in 2 repositories. The user confirmed that even after all changes, pressing Ctrl+Space followed by 'c' inside a Neovim session still opens a new tab at the Neovim session root instead of the original shell directory. This means the core problem (WezTerm new tab opens in wrong directory when invoked from inside Neovim) was NOT fixed. Three of the four changes are directly related to this issue and are ineffective. One change (CursorHold re-enablement) is unrelated to the task goal entirely and was added as scope creep during research.

## Findings

### Complete Inventory of Changes

#### Repository 1: nvim (~/.config/nvim)

**Change 1: CursorHold/CursorHoldI re-enablement** (autocmds.lua)
- **Commit**: `6df459f2` (task 92: complete research)
- **File**: `lua/neotex/config/autocmds.lua` (lines 90-93)
- **What changed**: Re-added `CursorHold` and `CursorHoldI` events to the checktime autocmd, changing from `{ "FocusGained", "BufEnter" }` to `{ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }`
- **Original comment that explained removal**: "CursorHold/CursorHoldI removed: caused 5-10ms lag on every cursor pause"
- **New comment justification**: "CursorHold/CursorHoldI re-enabled: performance issue fixed in Neovim 0.8+ (PR #20198)"
- **Relation to task 92 goal**: NONE. Task 92 was about WezTerm tab directory sync. This change detects external file modifications more promptly but has nothing to do with which directory new WezTerm tabs open in.
- **Assessment**: UNRELATED SCOPE CREEP. Was added during the research commit without being part of any plan. The original removal was intentional and documented for performance reasons. The claim about "PR #20198" fixing the performance issue is not verifiable and the original rationale (5-10ms lag on every cursor pause) may still apply.
- **Recommendation**: REVERT to original `{ "FocusGained", "BufEnter" }` with original comments.

**Change 2: Maildir resync keybinding** (which-key.lua)
- **Commit**: `6df459f2` (task 92: complete research)
- **File**: `lua/neotex/plugins/editor/which-key.lua` (line 528)
- **What changed**: Added `<leader>mr` keybinding for maildir resync via TermExec
- **Relation to task 92 goal**: NONE. This is a completely unrelated email/maildir utility keybinding.
- **Assessment**: UNRELATED SCOPE CREEP. Added during the same research commit. This keybinding has nothing to do with WezTerm directory sync. However, unlike the other changes, this may be intentionally useful to the user even though it was added in the wrong context.
- **Recommendation**: ASK USER. This change is unrelated to the directory issue but may be independently useful. The user should decide whether to keep it.

#### Repository 2: dotfiles (~/.dotfiles)

**Change 3: Fish shell OSC 7 prompt hook** (config.fish)
- **Commit**: Uncommitted in dotfiles repo (applied to working tree)
- **File**: `~/.dotfiles/config/config.fish` (lines 12-15)
- **What changed**: Added `__wezterm_osc7_prompt` function that emits OSC 7 on every fish prompt event
- **Relation to task 92 goal**: DIRECTLY RELATED. This was the primary fix from task 92, designed to overwrite stale OSC 7 values after exiting Neovim.
- **Assessment**: INEFFECTIVE. The user confirmed that after this change, new tabs still open in the wrong directory when invoked from inside Neovim. The issue is that when pressing Ctrl+Space c while inside Neovim, the foreground process is Neovim (not the shell), so the fish prompt hook never fires -- Neovim is still running, so the shell prompt is not displayed. The hook only helps AFTER Neovim exits and the user is back at a shell prompt, which is not the reported scenario.
- **Recommendation**: REVERT. Remove the 3-line `__wezterm_osc7_prompt` function and its comment.

**Change 4: WezTerm Leader+c keybinding override** (wezterm.lua)
- **Commit**: `8c62b91` (task 94 phase 1: replace Leader+c keybinding)
- **File**: `~/.dotfiles/config/wezterm.lua` (lines 430-447)
- **What changed**: Replaced `act.SpawnTab("CurrentPaneDomain")` with `wezterm.action_callback` that reads the foreground process's CWD from `/proc/PID/cwd`
- **Relation to task 94 goal**: DIRECTLY RELATED. This was the entire fix from task 94.
- **Assessment**: INEFFECTIVE FOR THE REPORTED SCENARIO. When the user is inside Neovim and presses Ctrl+Space c, the foreground process IS Neovim. So `pane:get_foreground_process_info()` returns Neovim's process info, and `info.cwd` is Neovim's CWD (the project root). The new tab opens at Neovim's CWD -- which is exactly the same behavior as the stale OSC 7 metadata would produce. The "fix" only helps when the user is at a shell prompt after exiting Neovim, which is the same scenario the fish prompt hook (Change 3) already handles.
- **Why the user's scenario is unfixable with this approach**: When the user is INSIDE Neovim, there is no way to determine the original shell directory from which Neovim was launched by reading the foreground process CWD. The research (task 94, Section 10) identified that a ppid-based parent shell lookup would be needed, but the "simpler approach" was chosen instead. Even with ppid lookup, this is unreliable because the parent shell's CWD may have been changed by other means.
- **Recommendation**: REVERT to original simple `act.SpawnTab("CurrentPaneDomain")`. The complex callback adds 17 lines of code to achieve the same behavior as the original single line for the reported scenario.

### Root Cause Analysis: Why Neither Fix Works

The user's scenario is:
1. Open a WezTerm tab in `some/directory/`
2. Open Neovim with root at `some/root/` (which is different from the shell directory)
3. While inside Neovim, press Ctrl+Space c
4. Expected: new tab at `some/directory/` (the original shell directory)
5. Actual: new tab at `some/root/` (Neovim's CWD)

This scenario is fundamentally difficult because:
- **OSC 7 metadata**: Reports Neovim's CWD (the project root), not the original shell directory
- **Foreground process CWD** (`/proc/PID/cwd`): Is Neovim's CWD, same as OSC 7
- **Fish prompt hook**: Does not fire while Neovim is running (shell prompt is not displayed)
- **Parent shell CWD lookup**: The parent shell's CWD may or may not still be `some/directory/` -- it depends on whether the shell tracks its own CWD correctly while a child process runs

The user has decided to accept this behavior, so all the added complexity to try to fix it should be removed.

## Recommendations

### Changes to Revert

| # | File | Repository | Action |
|---|------|------------|--------|
| 1 | `lua/neotex/config/autocmds.lua` | nvim | REVERT: Restore original `{ "FocusGained", "BufEnter" }` with original comments |
| 2 | `lua/neotex/plugins/editor/which-key.lua` | nvim | ASK USER: Remove the `<leader>mr` maildir resync keybinding if unwanted |
| 3 | `~/.dotfiles/config/config.fish` | dotfiles | REVERT: Remove `__wezterm_osc7_prompt` function (3 lines + 1 comment) |
| 4 | `~/.dotfiles/config/wezterm.lua` | dotfiles | REVERT: Restore original `act.SpawnTab("CurrentPaneDomain")` one-liner |

### Implementation Approach

1. **In the nvim repository** (this repo):
   - Revert `autocmds.lua` CursorHold change (restore original 4-line comment block and event list)
   - Optionally remove `which-key.lua` maildir keybinding (ask user)

2. **In the dotfiles repository** (`~/.dotfiles`):
   - Revert `config.fish` prompt hook addition
   - Revert `wezterm.lua` Leader+c keybinding to original simple form

### What NOT to Remove

- The existing `__wezterm_osc7` function in `config.fish` (was there before task 92, fires on PWD change)
- The existing OSC 7 integration in `autocmds.lua` lines 103-144 (WezTerm tab title support, predates task 92)
- Any specs/reports/plans in the specs directory (documentation of what was attempted)

## References

- Task 92 commits: `2a10c7da` through `30102ab2`
- Task 94 commits: `f7595da3` through `675aa4af`
- Dotfiles repo task 94 commit: `8c62b91`
- Task 92 research reports: `specs/092_*/reports/research-001.md` through `research-004.md`
- Task 94 research report: `specs/094_*/reports/research-001.md`

## Next Steps

1. Create implementation plan with exact revert steps for each file
2. Implement reversions in both repositories
3. Run verification (nvim --headless checkhealth, fish syntax check)
