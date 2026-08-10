# Teammate D Findings: WezTerm + Wayland Deep Dive

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Angle**: WezTerm/Wayland clipboard architecture, focus stealing, and strategic alternatives
**Date**: 2026-05-21

## Key Findings

### 1. The Root Cause is Confirmed: wl-copy Transient Window Focus Stealing on GNOME

This is a **known, documented issue** across multiple projects:

- **Neovim issue #12622**: "On GNOME/Wayland, clipboard=unnamed causes the app name to flicker." The symptom is identical to what the user reports. Every clipboard operation (yank, delete, etc.) causes the window title/app name to briefly change to "Unknown" and flicker. The issue was closed as "Blocked-External" because the fix must come from wl-clipboard or the compositor, not Neovim.

- **wl-clipboard issue #90**: "wl-copy flashes window on gnome." The maintainer labeled this as "focus-stealing-side-effect" — an inherent limitation of how wl-clipboard works on Wayland compositors that don't implement the `zwlr_data_control` protocol.

- **The Wayland protocol requires** that only the focused window can set clipboard content. Since `wl-copy` is a separate process (not the terminal window), it must briefly create an invisible surface and acquire focus to set the clipboard. On GNOME, this surface creation triggers a focus change event that's visible to the user.

### 2. GNOME Specifically Lacks the Protocol That Would Fix This

GNOME does NOT implement the `zwlr_data_control_unstable_v1` protocol, which allows clipboard access without focus. This protocol is available in wlroots-based compositors (Sway, Hyprland, etc.) but GNOME intentionally omits it. This means:

- On GNOME: wl-copy MUST create a transient window and steal focus → flicker is unavoidable
- On wlroots compositors: wl-copy can use data-control protocol → no focus steal → no flicker

This is why the issue is specific to the user's GNOME setup.

### 3. Why OSC 52 Also Failed (Critical Finding)

The previous implementation attempt switched to OSC 52 for clipboard writes and the blinking persisted. Here's why:

**Neovim's clipboard provider initialization is CACHED.** From the clipboard provider source (`clipboard.vim`):

```vim
if exists('g:loaded_clipboard_provider')
  finish
endif
let g:loaded_clipboard_provider = 0
```

And at the end:
```vim
let g:loaded_clipboard_provider = empty(provider#clipboard#Executable()) ? 0 : 2
```

The `provider#clipboard#Executable()` function is called ONCE during initialization. It checks `g:clipboard` at that time. If `g:clipboard` is not set, it falls through to auto-detection, which finds `wl-copy`/`wl-paste` (because `$WAYLAND_DISPLAY` is set) and **permanently** registers them as the clipboard provider.

**The critical timing issue**: In the failed implementation, `vim.g.clipboard` was set during the VeryLazy event (after plugin config runs). But the clipboard provider is initialized EARLIER — the first time any clipboard operation is attempted. If anything accesses the clipboard before VeryLazy fires (startup autocommands, yanky.nvim loading, `checktime`, etc.), the wl-copy provider is cached and `vim.g.clipboard` changes are IGNORED.

This means the OSC 52 provider was likely never actually used. wl-copy was still being called on every yank.

**To verify**: Set `vim.g.clipboard` in `init.lua` BEFORE `clipboard=unnamedplus` is set, or use:
```vim
:unlet g:loaded_clipboard_provider
:runtime autoload/provider/clipboard.vim
```
to force a reload after setting the custom provider.

### 4. The `update-status` Handler Adds Overhead

The user's WezTerm config has an `update-status` event handler that fires every 500ms:

```lua
config.status_update_interval = 500
wezterm.on("update-status", function(window, pane)
  -- Checks tab changes and injects OSC sequences to clear CLAUDE_STATUS
end)
```

When wl-copy steals focus, the compositor sends focus events that may trigger this handler, which then iterates all tabs and potentially injects OSC escape sequences. This could compound the visual flickering.

### 5. `window_decorations = "NONE"` Means GNOME Handles Title Bar

The config sets `config.window_decorations = "NONE"`, meaning GNOME's server-side decorations (SSD) are used. This means the title bar is drawn by the GNOME compositor, not WezTerm. When wl-copy steals focus:

1. GNOME marks WezTerm as unfocused → title bar changes appearance
2. wl-copy finishes → WezTerm regains focus → title bar changes back
3. This compositor-level title bar flash is what the user sees as "WezTerm blinking in the top-left corner"

WezTerm can't prevent this because it's the compositor drawing the title bar.

### 6. `vim.cmd("mode")` Sends DA1 Query

The Neovim `:mode` command re-sends terminal mode initialization sequences, including a DA1 (Device Attributes) query (`ESC[c`). WezTerm responds with its terminal identification. If the terminal response isn't consumed fast enough, it could briefly appear as text in the buffer — potentially the "WezTerm" text the user reported in the top-left corner. This is a red herring from the recovery autocommand, not the clipboard issue itself.

## Strategic Recommendations

### Recommended Approach: OSC 52 for Copy, Set EARLY

The previous OSC 52 attempt was correct in concept but failed due to provider caching. The fix:

```lua
-- In options.lua, BEFORE clipboard=unnamedplus is set:
vim.g.clipboard = {
  name = 'osc52-wlpaste',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    -- Use local register for paste (avoids wl-paste timeout on reads too)
    ['+'] = function()
      return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
    end,
    ['*'] = function()
      return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
    end,
  },
}
```

For the paste side, a common pattern from the Neovim discussion (#28010) is to use local registers for paste (avoiding wl-paste entirely for normal operations) and rely on FocusGained async sync for external clipboard changes.

### Alternative: Use xclip/xsel via XWayland

Since GNOME exposes X11 clipboard through XWayland, xclip and xsel work WITHOUT focus stealing:

```lua
vim.g.clipboard = {
  name = 'xclip',
  copy = {
    ['+'] = {'xclip', '-quiet', '-i', '-selection', 'clipboard'},
    ['*'] = {'xclip', '-quiet', '-i', '-selection', 'primary'},
  },
  paste = {
    ['+'] = {'xclip', '-o', '-selection', 'clipboard'},
    ['*'] = {'xclip', '-o', '-selection', 'primary'},
  },
}
```

Neovim issue #30901 specifically recommends this for GNOME. The user's system likely has xclip available via NixOS.

### Alternative: Disable Wayland in WezTerm

Setting `config.enable_wayland = false` forces WezTerm to use XWayland. This eliminates the Wayland clipboard issues entirely but trades native Wayland performance for X11 compatibility. The mwop.net blog confirms this resolves the transient window issue.

## Unconventional Approaches

### 1. Hybrid Clipboard with Deferred Sync

Instead of syncing clipboard on every yank, use OSC 52 for immediate copy and a deferred FocusGained handler for external-to-Neovim clipboard changes:

- Copy: OSC 52 (instant, no external process)
- Paste: Use Neovim's internal register cache (instant)
- External sync: On FocusGained, async wl-paste with timeout to pull in external clipboard changes

This gives the user instant yank/paste with zero flicker, and external clipboard content syncs when they switch back to Neovim.

### 2. GNOME Clipboard Portal

GNOME implements the `org.freedesktop.portal.Clipboard` D-Bus portal. Using `gdbus` or `busctl` to set clipboard content via the portal might avoid the transient window issue entirely, since the portal API is designed for non-focused applications.

### 3. Compositor-level Fix

Install a GNOME extension that suppresses focus-change visual feedback during clipboard operations, or implement the `zwlr_data_control` protocol via a GNOME extension (the `wl-clipboard-manager` project attempted this).

## Confidence Level

- **Root cause identification** (wl-copy focus steal on GNOME): **HIGH** — confirmed across multiple upstream issue trackers
- **Provider caching as reason OSC 52 failed**: **HIGH** — verified by reading Neovim's clipboard.vim source
- **OSC 52 early registration as fix**: **MEDIUM** — correct in theory, needs empirical validation
- **xclip alternative**: **HIGH** — documented in upstream Neovim issues as the recommended GNOME workaround

## Sources

- [Neovim #12622: GNOME/Wayland clipboard=unnamed flicker](https://github.com/neovim/neovim/issues/12622)
- [wl-clipboard #90: wl-copy flashes window on GNOME](https://github.com/bugaevc/wl-clipboard/issues/90)
- [mwop.net: Fixing wl-clipboard transient windows with Neovim](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html)
- [Neovim #30901: Prioritize xclip over wl-copy on GNOME](https://github.com/neovim/neovim/issues/30901)
- [Neovim #28010: OSC 52 copy-only discussion](https://github.com/neovim/neovim/discussions/28010)
- [Neovim clipboard provider source](https://github.com/neovim/neovim/blob/master/runtime/autoload/provider/clipboard.vim)
- [WezTerm enable_wayland docs](https://wezterm.org/config/lua/config/enable_wayland.html)
- User's WezTerm config at `~/.dotfiles/config/wezterm.lua`
