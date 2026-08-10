# Diagnostic Report: Failed Implementation Attempt

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Date**: 2026-05-21
**Outcome**: Implementation reverted. All source changes rolled back to pre-task state.

## What Was Attempted

Replaced yanky.nvim with a custom yank ring module (6 files under `lua/neotex/yank/`, ~270 LOC) plus a lazy.nvim plugin spec at `lua/neotex/plugins/tools/yank-ring.lua`. The goal was to eliminate the blocking `wl-paste` call on FocusGained that causes post-sleep Neovim freezing on Wayland.

## Symptoms Observed

Pressing `Y` (mapped to `y$`) immediately after opening Neovim caused persistent visual blinking/flickering. The symptom changed character as fixes were applied but never resolved:

| Attempt | Change | Result |
|---------|--------|--------|
| Initial implementation | Plugin loaded on `TextYankPost`, keys table included `y`/`p`/`P`/`gp`/`gP` without rhs | Rapid blinking cursor on Y. `<leader>fy` returned nil error (plugin not loaded yet). |
| Fix 1: VeryLazy + remove keys | Changed to `event = "VeryLazy"`, removed keys table | Still rapid blinking cursor on Y |
| Fix 2: Debounce recovery | Added 2-second debounce to recovery.recover() | Slowed the blink rate but same fundamental issue |
| Fix 3: FocusLost threshold | Track FocusLost timestamp, only run recovery if gap > 5 seconds | Different symptom: "WezTerm" text blinking in top-left corner of screen |
| Fix 4: OSC 52 clipboard provider | Replaced `wl-copy` with OSC 52 for clipboard writes, kept `wl-paste` with timeout for reads | Same blinking on Y |
| Fix 5: Disable highlight + recovery | Commented out `vim.hl.on_yank()` and `recovery.setup()` entirely | Same blinking on Y (and no yank highlight) |

## Key Finding

**The blinking persists even with our TextYankPost handler doing nothing visible** (fix 5: only a table insert and variable assignment). This means the root cause is NOT in our yank ring module code. The issue is at the Neovim/WezTerm/Wayland interaction layer, likely triggered by the clipboard write that happens during native yank with `clipboard=unnamedplus`.

## What Was Ruled Out

1. **Our TextYankPost handler**: Disabling all visual operations (highlight, recovery) in the handler did not fix the blink. The handler only does a table insert and variable assignment.
2. **Recovery autocommand on FocusGained**: `vim.cmd("mode")` + `vim.cmd("redraw!")` running on every FocusGained DID contribute (debounce slowed the blink), but the blink persisted after completely disabling recovery.
3. **wl-copy focus stealing**: Replacing wl-copy with OSC 52 for clipboard writes (zero external processes) did not fix the blink. This rules out wl-copy's Wayland focus steal as the sole cause.
4. **vim.hl.on_yank()**: Disabling yank highlighting did not fix the blink.
5. **lazy.nvim keys table**: Intercepting native operators (y, p, P, gp, gP) without an rhs action DID break normal yank behavior, but fixing this did not resolve the blink.

## What Was NOT Investigated

1. **Whether the blink exists with yanky.nvim still installed**: The original yanky config was deleted and replaced. We never tested whether the blink is pre-existing (present with yanky) or was introduced by removing yanky.
2. **Whether `clipboard=unnamedplus` itself causes the blink**: Yanking with this option triggers the clipboard provider on every yank. With yanky, `Y` was mapped to `<Plug>(YankyYank)` which may have handled clipboard interaction differently than native `y$`.
3. **Whether the blink occurs with `nvim --clean`**: Testing with no plugins would isolate whether this is a Neovim/WezTerm issue or plugin-related.
4. **Whether WezTerm's OSC 52 processing causes visual feedback**: Some terminals show clipboard notifications. WezTerm config was not inspected.
5. **Whether `lazyredraw = true` interacts badly with clipboard provider writes**: The option (set in options.lua line 155) suppresses redraws during mapping execution. Since `Y` is a mapping (`y$`), the clipboard provider write happens during mapping execution, and visual side effects might be delayed/batched.
6. **Whether the Neovim clipboard provider caches or re-initializes**: Setting `vim.g.clipboard` after `clipboard=unnamedplus` may not override an already-initialized provider if Neovim caches the provider on first access.
7. **WezTerm `window-focus-changed` handler**: The user's WezTerm config (in `~/.dotfiles/config/wezterm.lua`) may have event handlers that react to focus changes caused by clipboard operations.
8. **Strace/logging of what processes are spawned on Y**: Never confirmed whether wl-copy was actually being called (or not) after the OSC 52 change.

## Recommended Next Steps for Future Research

### Priority 1: Establish baseline
- Test `Y` in current config (yanky.nvim restored) to confirm it works without blinking
- Test `Y` with `nvim --clean` (no plugins, but clipboard=unnamedplus) to see if Neovim + WezTerm + Wayland has a baseline blink
- Test `Y` with `clipboard=` (empty, no system clipboard sync) to confirm clipboard provider is the trigger

### Priority 2: Isolate the clipboard provider
- Run `strace -f -e trace=execve nvim` and press Y to see exactly what processes are spawned
- Check if `vim.g.clipboard` set before VeryLazy actually takes effect (test by setting it in options.lua directly)
- Test with a minimal custom `vim.g.clipboard` that does absolutely nothing on copy: `copy = { ["+"] = function() end }`

### Priority 3: Consider alternative approaches
- **Option A (minimal fix)**: Keep yanky.nvim but set `sync_with_ring = false` and add a standalone FocusGained recovery autocommand (with debounce). This was "Option A" from research report 02.
- **Option B (custom clipboard provider only)**: Don't replace yanky at all. Just set `vim.g.clipboard` to a timeout-protected provider in options.lua. Yanky would use this provider for its clipboard operations, getting timeout protection without any code changes.
- **Option C (investigate WezTerm)**: The blinking "WezTerm" in the top-left corner suggests WezTerm's own UI is reacting to something. Inspect WezTerm config for focus-change handlers, clipboard notifications, or title-bar behavior.

## Files That Were Changed (Now Reverted)

### Created (now deleted)
- `lua/neotex/yank/init.lua` - Entry point, setup, autocommands
- `lua/neotex/yank/ring.lua` - Circular buffer
- `lua/neotex/yank/clipboard.lua` - Async clipboard via vim.system() + OSC 52 provider
- `lua/neotex/yank/highlight.lua` - vim.hl.on_yank() wrapper
- `lua/neotex/yank/telescope.lua` - Telescope picker
- `lua/neotex/yank/recovery.lua` - Post-sleep rendering recovery
- `lua/neotex/plugins/tools/yank-ring.lua` - lazy.nvim plugin spec

### Modified (now restored)
- `lua/neotex/plugins/editor/telescope.lua` - Had yanky dependency removed
- `lua/neotex/plugins/editor/which-key.lua` - Had 3 yanky references updated
- `lua/neotex/plugins/tools/init.lua` - Had module reference updated

### Deleted (now restored)
- `lua/neotex/plugins/tools/yanky.lua` - Original yanky.nvim config
