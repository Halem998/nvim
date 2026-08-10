# Implementation Summary: Task #92

**Completed**: 2026-02-24
**Duration**: ~10 minutes

## Changes Made

Added a fish shell prompt hook that emits OSC 7 escape sequences on every prompt. This overwrites any stale OSC 7 values left by child processes (like Neovim) when the shell regains control, ensuring WezTerm's pane metadata reflects the shell's actual `$PWD` rather than the last directory Neovim reported.

## Files Modified

- `~/.dotfiles/config/config.fish` - Added `__wezterm_osc7_prompt` function with `--on-event fish_prompt` trigger inside the existing `if set -q WEZTERM_PANE` block (3 lines: 1 comment + 2 lines for function definition)

## Code Change

```fish
# Emit OSC 7 on every prompt to override stale values from child processes
function __wezterm_osc7_prompt --on-event fish_prompt
    printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
end
```

## Verification

- Fish syntax check: Passed (`fish -n config.fish`)
- Manual verification required: Open WezTerm, run `nvim`, exit, open new tab (Leader+c) - should spawn at shell's actual `$PWD`

## Notes

- The fish config is managed by home-manager and stored at `~/.dotfiles/config/config.fish`
- The symlinked file at `~/.config/fish/config.fish` is read-only (nix store)
- A `home-manager switch` is required to apply the change to the active environment
- The fix has no performance impact (printf is sub-millisecond)
- The existing `__wezterm_osc7` function (triggered on PWD change) remains unchanged and complements this fix
