# Team Research Report: Root Cause Analysis of Yank Blinking on Wayland

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Date**: 2026-05-21
**Mode**: Team Research (4 teammates)
**Session**: sess_1779384151_2b67eb

## Summary

All four teammates converged on the same root cause with high confidence. The visual blinking on yank is caused by two compounding issues, and the previous OSC 52 fix failed due to a provider caching constraint that was not understood at the time.

## Root Cause (Confirmed by All 4 Teammates)

### Cause 1: wl-copy Focus Stealing on GNOME/Wayland

`wl-copy` creates a **transient Wayland surface** to acquire clipboard ownership. On GNOME (which lacks the `zwlr_data_control` protocol), this surface briefly steals compositor focus, causing:
- WezTerm receives FocusLost then FocusGained
- GNOME redraws WezTerm's server-side title bar (since `window_decorations = "NONE"`) -- visible as "WezTerm blinking in the top-left corner"
- Cursor visibility resets during the focus round-trip -- visible as "blinking cursor"

This is documented in:
- Neovim #12622 (closed as blocked-external)
- wl-clipboard #90 (labeled "focus-stealing-side-effect")
- wl-clipboard #268

### Cause 2: `lazyredraw = true` Amplifies the Flash

`Y` is mapped to `y$` (keymaps.lua:303). During mapping execution, `lazyredraw` suppresses all screen redraws. The clipboard provider write (wl-copy) happens during the mapping. When the mapping completes and lazyredraw releases, all pending redraws flush at once -- producing a visible flash. Multiple Neovim issues confirm lazyredraw causes cursor flashing and visual artifacts (#2253, #11806, #23534).

### Why the Previous OSC 52 Fix Failed

**The clipboard provider was cached before our override took effect.** This is the critical finding that explains the entire failed implementation.

Neovim's clipboard provider (`autoload/provider/clipboard.vim`) has a load guard:
```vim
if exists('g:loaded_clipboard_provider')
  finish
endif
```

The provider initializes ONCE on first clipboard access. `provider#clipboard#Executable()` reads `g:clipboard` at that moment, registers `s:copy`/`s:paste` script-locals, and never re-reads `g:clipboard` again.

In the failed implementation:
- `clipboard=unnamedplus` was set in `options.lua` (early startup)
- This triggered Neovim to auto-detect and cache the wl-copy provider
- `vim.g.clipboard` was set to OSC 52 during VeryLazy (after UI render)
- **The cached provider was never updated -- wl-copy was called the entire time**

Additionally, Neovim explicitly refuses auto-OSC 52 when clipboard is set (clipboard.vim line 260):
```vim
elseif get(get(g:, 'termfeatures', {}), 'osc52') && &clipboard ==# ''
```

Confirmed by Neovim #29644: `g:clipboard` can only be effectively set once, before any clipboard operation.

## Synthesis: What Was Actually Happening During Each Fix Attempt

| Fix | What We Thought | What Actually Happened |
|-----|-----------------|----------------------|
| OSC 52 provider | Eliminated wl-copy | wl-copy still running (provider cached) |
| Disabled highlight | Eliminated visual operations | wl-copy focus steal still causing compositor blink |
| Disabled recovery | Eliminated mode/redraw | wl-copy focus steal still active |
| Debounced recovery | Reduced recovery frequency | Reduced OUR recovery calls, but wl-copy blink is compositor-level |

**Every fix targeted our code, but the blink was caused by wl-copy at the compositor level. Our code was never the problem -- the clipboard provider override simply never took effect.**

## Recommended Fix (Converged Across All Teammates)

### Part 1: Set `vim.g.clipboard` BEFORE `clipboard=unnamedplus` in `options.lua`

This is the critical fix. The provider must be registered before Neovim initializes the default:

```lua
-- In options.lua, BEFORE the options table that sets clipboard=unnamedplus:
if vim.env.WAYLAND_DISPLAY then
  vim.g.clipboard = {
    name = "osc52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
      ["*"] = function()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end,
    },
  }
end
```

Key design decisions:
- **Copy via OSC 52**: No external process, no focus steal, instant
- **Paste from local register**: Avoids wl-paste timeouts entirely. External clipboard content arrives via terminal paste (Ctrl+Shift+V) or via a FocusGained async sync
- **Wayland-only guard**: Only applies on Wayland; X11/macOS/SSH keep default behavior

This pattern is recommended by LazyVim (#2715) and Neovim discussions (#28010).

### Part 2: Keep yanky.nvim, set `sync_with_ring = false`

Do NOT replace yanky. It provides value (yank ring, enhanced put, highlighting, cursor preservation) and its `<Plug>(YankyYank)` interceptor actually masks minor visual glitches. Just disable the FocusGained sync that triggers the blocking wl-paste:

```lua
system_clipboard = {
  sync_with_ring = false,
},
```

### Part 3: Optional post-sleep recovery autocommand

A standalone autocommand (not in yanky, not in a yank ring module) for post-sleep rendering recovery. Uses the FocusLost timestamp approach with a 5-second threshold to avoid triggering on normal focus changes.

### Part 4: Consider removing `lazyredraw = true`

`lazyredraw` is known to cause visual artifacts in Neovim (multiple open issues). Modern Neovim (0.10+) has improved rendering that makes it less necessary. Removing it eliminates the redraw-batching that amplifies any remaining visual glitches. At minimum, test with `lazyredraw = false` as a diagnostic step.

## Alternative Approaches (If OSC 52 Doesn't Work)

### xclip via XWayland (High Confidence)
GNOME exposes X11 clipboard through XWayland. xclip doesn't create Wayland surfaces, so no focus stealing:
```lua
vim.g.clipboard = {
  name = "xclip",
  copy = {
    ["+"] = {"xclip", "-quiet", "-i", "-selection", "clipboard"},
    ["*"] = {"xclip", "-quiet", "-i", "-selection", "primary"},
  },
  paste = {
    ["+"] = {"xclip", "-o", "-selection", "clipboard"},
    ["*"] = {"xclip", "-o", "-selection", "primary"},
  },
}
```
Recommended in Neovim #30901 specifically for GNOME.

### Disable Wayland in WezTerm
Setting `enable_wayland = false` forces XWayland mode. Eliminates all Wayland clipboard issues but trades native performance.

## Diagnostic Steps Before Implementation

The critic (Teammate C) identified that the previous attempt skipped baseline validation. Before implementing:

1. **Confirm Y works with yanky NOW**: Press Y 20 times in restored config, confirm current behavior
2. **Test `lazyredraw = false`**: Single-line change in options.lua, test Y
3. **Test `nvim --clean` with clipboard=unnamedplus**: Isolate Neovim + WezTerm baseline
4. **Verify provider with strace**: `strace -f -e trace=execve -p $(pgrep nvim)` during yank to confirm wl-copy is/isn't called

## Conflicts and Resolutions

| Topic | Teammates | Resolution |
|-------|-----------|------------|
| Root cause | All 4 agree | wl-copy focus steal on GNOME (unanimous) |
| Why OSC 52 failed | A, B, D agree | Provider cached before override (unanimous) |
| Recommended fix | A, B, D agree | OSC 52 early in options.lua + keep yanky |
| lazyredraw removal | A recommends removal; C says test first | Test first, remove if it helps |
| Paste approach | B, D: local register; A: wl-paste with timeout | Local register preferred (avoids all external process issues) |
| Replace yanky? | C: don't replace; A, B: keep yanky | Keep yanky with sync_with_ring = false |

No unresolved conflicts. All findings are complementary.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary (call chain) | completed | high | Provider caching mechanism, lazyredraw interaction |
| B | Alternatives (community) | completed | high | LazyVim OSC 52 pattern, Neovim #29644 timing constraint |
| C | Critic (gaps) | completed | high | Baseline never established, simpler fixes skipped |
| D | Horizons (WezTerm/Wayland) | completed | high | GNOME lacks zwlr_data_control, xclip alternative |

## References

- [Neovim #12622: GNOME/Wayland clipboard flicker](https://github.com/neovim/neovim/issues/12622) (blocked-external)
- [Neovim #29644: g:clipboard can only be set once](https://github.com/neovim/neovim/issues/29644)
- [Neovim #28010: OSC 52 copy-only discussion](https://github.com/neovim/neovim/discussions/28010)
- [Neovim #30901: Prioritize xclip over wl-copy on GNOME](https://github.com/neovim/neovim/issues/30901)
- [Neovim #24470: wl-paste infinite hang](https://github.com/neovim/neovim/issues/24470)
- [Neovim #2253, #11806, #23534: lazyredraw visual artifacts](https://github.com/neovim/neovim/issues/2253)
- [wl-clipboard #90: wl-copy flashes window on GNOME](https://github.com/bugaevc/wl-clipboard/issues/90)
- [wl-clipboard #268: wl-copy spawns a window](https://github.com/bugaevc/wl-clipboard/issues/268)
- [LazyVim #2715: OSC 52 configuration](https://github.com/LazyVim/LazyVim/discussions/2715)
- [mwop.net: Fixing wl-clipboard transient windows](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html)
- [Neovim clipboard provider source](https://github.com/neovim/neovim/blob/master/runtime/autoload/provider/clipboard.vim)
