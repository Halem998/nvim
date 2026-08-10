# Implementation Plan: Task #92 - Fix WezTerm New Tab Directory

- **Task**: 92 - Sync Wezterm terminal directory with Neovim session root
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md), [research-003.md](../reports/research-003.md), [research-004.md](../reports/research-004.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Research-003 identified the root cause: Neovim emits OSC 7 escape sequences that update WezTerm's pane metadata to the Neovim project directory. After Neovim exits, the stale OSC 7 value persists because the fish shell's `__wezterm_osc7` hook only fires on `PWD` variable changes (i.e., when the user runs `cd`), not on every prompt. When the user opens a new tab, WezTerm's `SpawnTab("CurrentPaneDomain")` reads the stale OSC 7 metadata, spawning the new tab in Neovim's last project directory instead of the shell's actual `$PWD`.

Research-004 evaluated four fix options and recommends Option A: add a `fish_prompt` event handler that emits OSC 7 with the shell's actual `$PWD` on every prompt. This overwrites stale OSC 7 values as soon as the shell prompt appears after Neovim exits, with no impact on Neovim tab titles while Neovim is running (since the fish prompt does not display while Neovim is the foreground process).

### Research Integration

All four research reports were consulted:
- Research-001: Identified existing OSC 7 implementation in Neovim autocmds
- Research-002: Investigated lastdir file pattern (not needed for this fix)
- Research-003: Diagnosed OSC 7 as the cause of stale pane metadata after Neovim exits
- Research-004: Evaluated 4 fix options; recommends fish prompt hook as minimal fix

## Goals & Non-Goals

**Goals**:
- New WezTerm tabs spawn at the shell's actual `$PWD` after Neovim exits
- Tab title reflects the shell's actual directory after Neovim exits
- No impact on Neovim tab titles while Neovim is running

**Non-Goals**:
- Changing the shell's `$PWD` to match Neovim's directory (different problem)
- Modifying WezTerm configuration
- Modifying Neovim's OSC 7 integration (it works correctly for tab titles during Neovim usage)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extra OSC 7 on every prompt has performance impact | Low | Very Low | printf is sub-millisecond; negligible overhead |
| Prompt hook conflicts with existing `__wezterm_osc7` | Low | Very Low | They use different event triggers (`fish_prompt` vs `--on-variable PWD`) and emit the same payload |
| Fish prompt does not fire in expected scenarios | Medium | Very Low | Standard fish shell event; well-documented behavior |

## Implementation Phases

### Phase 1: Add fish prompt hook and verify [COMPLETED]

**Goal**: Add the `__wezterm_osc7_prompt` function to fish config and verify the fix works end-to-end.

**Tasks**:
- [ ] Add `__wezterm_osc7_prompt` function with `--on-event fish_prompt` trigger inside the existing `if set -q WEZTERM_PANE` block in `~/.config/fish/config.fish`
- [ ] Verify fix by opening Neovim in WezTerm, exiting, and confirming new tab spawns at shell's `$PWD`
- [ ] Verify Neovim tab titles still update correctly while Neovim is running
- [ ] Create implementation summary

**Timing**: 30 minutes

**Files to modify**:
- `~/.config/fish/config.fish` -- Add 3 lines (function definition + comment) inside existing `if set -q WEZTERM_PANE` block

**Code change**:

Current code (lines 7-14 of `~/.config/fish/config.fish`):
```fish
# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Send initial cwd
    __wezterm_osc7
end
```

Modified code:
```fish
# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Emit OSC 7 on every prompt to override stale values from child processes
    function __wezterm_osc7_prompt --on-event fish_prompt
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Send initial cwd
    __wezterm_osc7
end
```

The addition is 3 lines: 1 comment + 2 lines for the function definition.

**Verification**:
- Open WezTerm, note `$PWD` (e.g., `~/`)
- Run `nvim` -- tab title changes to Neovim project directory
- Exit Neovim -- tab title updates to shell's `$PWD` (prompt hook fires)
- Press Leader+c -- new tab opens at shell's `$PWD`, not Neovim's directory
- Repeat with `cd /tmp && nvim` to test different directories

## Testing & Validation

- [ ] After Neovim exits, tab title shows shell's actual `$PWD`
- [ ] New tabs (Leader+c) spawn at shell's `$PWD` after Neovim exits
- [ ] Neovim tab titles still update correctly during Neovim usage (BufEnter, DirChanged events)
- [ ] Normal shell usage (cd, fish prompt) continues to work correctly
- [ ] No visible errors in fish shell or WezTerm logs

## Artifacts & Outputs

- `specs/092_sync_wezterm_directory_with_neovim_session/plans/implementation-002.md` (this file)
- `specs/092_sync_wezterm_directory_with_neovim_session/summaries/implementation-summary-20260224.md`
- `~/.config/fish/config.fish` (modified)

## Rollback/Contingency

Remove the 3-line `__wezterm_osc7_prompt` function from `~/.config/fish/config.fish`. The existing `__wezterm_osc7` (on PWD change) and Neovim's OSC 7 integration remain unaffected.
