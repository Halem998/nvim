# Implementation Plan: Update WezTerm Dim/Bright Colors

- **Task**: 602 - update_wezterm_dim_bright_colors
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_wezterm-dim-bright-colors.md
- **Artifacts**: plans/01_wezterm-dim-bright-colors.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Update the WezTerm tab color palette to use proper dim/bright semantics for workflow lifecycle states (research=green, plan=blue, implement=gold), fix the `update-status` handler to only clear `needs_input` on tab switch while preserving lifecycle states, and fix TTS announcements to use lowercase "tab" prefix. The WezTerm config is at `~/.dotfiles/config/wezterm.lua` (Nix-managed via Home Manager symlink); changes are live immediately via WezTerm's file watcher. The TTS hook is at `.claude/hooks/tts-notify.sh` (not Nix-managed).

### Research Integration

Research report `reports/01_wezterm-dim-bright-colors.md` identified:
- Current color values have poor contrast: dim states are nearly invisible, bright states lack pop, gold looks khaki/olive
- The `update-status` handler incorrectly clears ALL `CLAUDE_STATUS` values on tab switch instead of only `needs_input`
- TTS uses capitalized "Tab" prefix instead of lowercase "tab"
- Recommended color values with distinct hue per workflow family and clear dim-to-bright progression

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace all 8 `status_colors` entries with improved values that have distinct hue per workflow family and visible dim-to-bright contrast
- Fix `update-status` handler to only clear `needs_input` on tab switch, preserving lifecycle states (`researching`, `researched`, `planning`, `planned`, `implementing`, `completed`, `blocked`)
- Fix TTS prefix from "Tab" to "tab" in `tts-notify.sh`
- Verify all changes work by visual inspection and Home Manager rebuild

**Non-Goals**:
- Changing tab title display format (already correct)
- Modifying `home.nix` or the Nix symlink configuration
- Adding new lifecycle states or changing the state vocabulary
- Modifying the WezTerm notify hook or preflight status hook

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Color values look wrong on user's display | M | L | Values are based on existing palette anchors; easy to tweak post-implementation |
| Clearing only `needs_input` leaves stale lifecycle colors | L | L | Lifecycle states are overwritten by next command's preflight; this is the intended behavior per task description |
| Home Manager rebuild fails | M | L | WezTerm changes are live via file watcher regardless; rebuild is optional sync step |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Color Palette and Fix update-status Handler [COMPLETED]

**Goal**: Replace `status_colors` table with improved dim/bright values and fix the `update-status` handler to only clear `needs_input` on tab switch.

**Tasks**:
- [x] **Task 1.1**: Edit `~/.dotfiles/config/wezterm.lua` lines 322-331: replace all 8 `status_colors` entries with the recommended values from the research report *(completed)*
  - `needs_input`: bg=#3a3a3a, fg=#d0d0d0 (unchanged gray)
  - `researching`: bg=#1e2e1e, fg=#5a7a5a (dim green)
  - `researched`: bg=#1a4a1a, fg=#a0d080 (bright green)
  - `planning`: bg=#1a1e30, fg=#5a6a8a (dim blue)
  - `planned`: bg=#1a2a5a, fg=#80a8d8 (bright blue)
  - `implementing`: bg=#2e2a18, fg=#8a7a40 (dim gold)
  - `completed`: bg=#4a3e18, fg=#e5c060 (bright gold)
  - `blocked`: bg=#5a2a2a, fg=#d0d0d0 (unchanged red)
- [x] **Task 1.2**: Edit `~/.dotfiles/config/wezterm.lua` lines 413-419: change the `update-status` handler conditional from `if user_vars.CLAUDE_STATUS and user_vars.CLAUDE_STATUS ~= ""` to `if user_vars.CLAUDE_STATUS == "needs_input"` so only `needs_input` is cleared on tab switch *(completed)*
- [x] **Task 1.3**: Update the comment at line 417 to reflect the new behavior: clearing only `needs_input`, not all lifecycle states *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.dotfiles/config/wezterm.lua` - Update `status_colors` table and `update-status` handler conditional

**Verification**:
- Lua syntax is valid (no parse errors in WezTerm log)
- The `status_colors` table has all 8 entries with correct hex values
- The `update-status` handler only clears `needs_input`

---

### Phase 2: Fix TTS Announcement Prefix [COMPLETED]

**Goal**: Change TTS prefix from capitalized "Tab" to lowercase "tab" so announcements read "tab 4 researched" instead of "Tab 4 researched".

**Tasks**:
- [x] **Task 2.1**: Edit `.claude/hooks/tts-notify.sh` line 51: change `local tab_prefix="Tab"` to `local tab_prefix="tab"` *(completed)*
- [x] **Task 2.2**: Edit `.claude/hooks/tts-notify.sh` line 68: change `tab_prefix="Tab $tab_num"` to `tab_prefix="tab $tab_num"` *(completed)*

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh` - Lowercase "tab" prefix on lines 51 and 68

**Verification**:
- grep confirms no remaining uppercase "Tab" strings in the tab_prefix assignments
- Script remains syntactically valid (bash -n check)

---

### Phase 3: Verification and Home Manager Rebuild [COMPLETED]

**Goal**: Verify all changes are correct and rebuild Home Manager to sync the Nix store.

**Tasks**:
- [x] **Task 3.1**: Run `bash -n /home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh` to verify shell syntax *(completed)*
- [x] **Task 3.2**: Visually confirm `status_colors` table has all 8 entries with correct values *(completed)*
- [x] **Task 3.3**: Visually confirm `update-status` handler only clears `needs_input` *(completed)*
- [x] **Task 3.4**: Run `home-manager switch --flake ~/.dotfiles` to rebuild and sync Nix store *(completed)*
- [x] **Task 3.5**: Verify WezTerm reloads config without errors (check `wezterm cli list` works) *(completed)*

**Timing**: 10 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (verification only)

**Verification**:
- Home Manager rebuild succeeds
- WezTerm responds to `wezterm cli list` after config reload
- No Lua parse errors in WezTerm log

## Testing & Validation

- [x] All `status_colors` entries match the recommended values from the research report *(completed)*
- [x] The `update-status` handler conditional checks for `"needs_input"` specifically, not any non-empty status *(completed)*
- [x] TTS `tab_prefix` uses lowercase "tab" on both line 51 and line 68 *(completed)*
- [x] `bash -n` passes on `tts-notify.sh` *(completed)*
- [x] `home-manager switch --flake ~/.dotfiles` completes without errors *(completed)*
- [x] WezTerm reloads without Lua parse errors *(completed: wezterm cli list confirmed responsive)*

## Artifacts & Outputs

- `specs/602_update_wezterm_dim_bright_colors/plans/01_wezterm-dim-bright-colors.md` (this plan)
- `specs/602_update_wezterm_dim_bright_colors/summaries/01_wezterm-dim-bright-colors-summary.md` (post-implementation)

## Rollback/Contingency

Both modified files are tracked in git (`~/.dotfiles` and `~/.config/nvim`). To revert:
- `cd ~/.dotfiles && git checkout -- config/wezterm.lua` to restore previous color palette and handler
- `cd ~/.config/nvim && git checkout -- .claude/hooks/tts-notify.sh` to restore TTS prefix
- Run `home-manager switch --flake ~/.dotfiles` after reverting wezterm.lua
