# Teammate A Findings: Clipboard Provider Call Chain Deep Dive

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Focus**: Trace the full clipboard write call chain to identify the blinking root cause
**Date**: 2026-05-21

## Key Findings

### 1. The Clipboard Provider Is Cached — OSC 52 Override Likely Never Took Effect

**This is the most critical finding.** The Neovim clipboard provider (`autoload/provider/clipboard.vim`) has a load guard:

```vim
if exists('g:loaded_clipboard_provider')
  finish
endif
let g:loaded_clipboard_provider = 0
```

At the bottom of the file:
```vim
let g:loaded_clipboard_provider = empty(provider#clipboard#Executable()) ? 0 : 2
```

The provider is loaded ONCE via Vimscript autoload on first clipboard access. `provider#clipboard#Executable()` reads `g:clipboard` at that moment, initializes `s:copy`/`s:paste` script-local variables, and **never re-reads `g:clipboard` again**.

**The failed implementation set `vim.g.clipboard` during VeryLazy event (after UI render).** But by that point, Neovim had already auto-detected `wl-copy`/`wl-paste` on the first clipboard access. The custom OSC 52 provider was stored in `vim.g.clipboard` but the script-local `s:copy`/`s:paste` variables still pointed to wl-copy.

**To force a provider reload after changing `g:clipboard`:**
```vim
:unlet g:loaded_clipboard_provider
:runtime autoload/provider/clipboard.vim
```

This was never done in the implementation attempt. **The OSC 52 provider was never actually active — wl-copy was being called the entire time.**

### 2. wl-copy Creates a Visible Transient Window on GNOME Wayland

The wl-clipboard tool (`wl-copy`) works around Wayland's security model by creating a **transient Wayland surface** (window) to gain clipboard ownership. This is documented in multiple upstream issues:

- [wl-clipboard #90](https://github.com/bugaevc/wl-clipboard/issues/90): "wl-copy flashes window on GNOME" — labeled `focus-stealing-side-effect`
- [wl-clipboard #268](https://github.com/bugaevc/wl-clipboard/issues/268): "wl-copy spawns a window when focus stealing prevention is set"
- [mwop.net blog post](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html): Documents "transient wl-clipboard windows appearing with system notifications whenever clipboard operations occurred in Neovim"

The Wayland protocol restricts clipboard access to focused windows. Since Neovim runs inside WezTerm (not as its own Wayland client), `wl-copy` must create its own surface to interact with the clipboard. On GNOME/Mutter, this surface:
1. Briefly appears as a window in the compositor
2. Steals focus momentarily
3. Causes WezTerm to receive FocusLost → FocusGained events
4. May flash in the taskbar/dock or show "WezTerm" title flickering

**This exactly matches the user's observed symptom**: "blinking of 'WezTerm' in the top left corner of my screen."

### 3. The Clipboard Provider Uses `jobstart` (Async) for Writes, `systemlist` (Sync) for Reads

From `clipboard.vim`, the `s:clipboard.set()` function (clipboard WRITE path):

```vim
function! s:clipboard.set(lines, regtype, reg) abort
  " ... When cache is enabled:
  let jobid = jobstart(selection.argv, selection)  " ASYNC via jobstart
  call jobsend(jobid, a:lines)
  call jobclose(jobid, 'stdin')
```

The write path uses **`jobstart`** — an async job. The wl-copy process runs asynchronously, but it still creates its Wayland surface and steals focus.

For reads (`s:clipboard.get`), when not cached:
```vim
let clipboard_data = type(s:paste[a:reg]) == v:t_func
    \ ? s:paste[a:reg]()
    \ : s:try_cmd(s:paste[a:reg])
```
Where `s:try_cmd` calls **`systemlist()`** — a synchronous blocking call. This is what causes the post-sleep freeze (wl-paste blocks in systemlist).

### 4. `lazyredraw = true` Combined with `jobstart` Creates the Visual Flash

The user has `lazyredraw = true` (options.lua line 155). `Y` is mapped to `y$` (a keymapping). During keymapping execution:

1. `lazyredraw` suppresses screen redraws
2. `y$` yanks the text
3. Neovim calls `s:clipboard.set()` → `jobstart` launches `wl-copy`
4. `wl-copy` creates its transient window → GNOME shifts focus
5. WezTerm receives FocusLost
6. Keymapping finishes → `lazyredraw` releases
7. All deferred redraws flush at once
8. WezTerm receives FocusGained
9. Screen renders the new state — visible as a "flash"

The combination of `lazyredraw` deferring redraws + `wl-copy` stealing focus + deferred redraw flushing creates the blinking effect. There are known Neovim issues with `lazyredraw` causing cursor flashing:
- [neovim #2253](https://github.com/neovim/neovim/issues/2253): "Cursor flashes with lazyredraw"
- [neovim #11806](https://github.com/neovim/neovim/issues/11806): "lazyredraw causes cursor to jump to statusline or commandline"
- [neovim #23534](https://github.com/neovim/neovim/issues/23534): "When winbar is set and lazyredraw is set, statusline and winbar will be broken"

### 5. yanky.nvim Masks the Problem via `<Plug>(YankyYank)`

With yanky.nvim installed, `Y` (mapped to `y$`) triggers yanky's `<Plug>(YankyYank)` which **intercepts** the `y` operator. Yanky handles the clipboard write through its own mechanism (which still calls wl-copy under the hood via vim's clipboard provider). However:

- Yanky wraps the yank in its own function context
- Yanky's highlighting (`timer = 100`) may mask the brief focus flash
- Yanky's `preserve_cursor_position` prevents the cursor jump that `lazyredraw` causes

When yanky was removed and native `y$` was used directly, the flash became visible because there was no interceptor smoothing the visual transition.

### 6. WezTerm Config Has No Focus-Related Visual Handlers

The user's WezTerm config (`~/.dotfiles/config/wezterm.lua`) does NOT have:
- No `window-focus-changed` handler (commented out)
- No explicit clipboard notification settings
- `window_decorations = "NONE"` (compositor handles decorations)
- `cursor_blink_rate = 500` (cursor blinks at normal rate)

However, `config.visual_bell` IS configured with cursor color fading (75ms fade in/out), which could amplify visual effects from focus changes.

## Recommended Approach

**Three-pronged fix, in order of impact:**

### Fix 1: Set `vim.g.clipboard` EARLY and force provider reload

Set the custom clipboard provider in `options.lua`, immediately after `clipboard = "unnamedplus"`, BEFORE Neovim's autoload provider initializes:

```lua
-- In options.lua, right after clipboard = "unnamedplus"
if vim.env.WAYLAND_DISPLAY then
  vim.g.clipboard = {
    name = "osc52-wlpaste",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = function()
        local obj = vim.system({"wl-paste", "--no-newline"}, {text = true, timeout = 2000}):wait()
        if obj.code == 0 and obj.stdout then return vim.split(obj.stdout, "\n") end
        return nil
      end,
      ["*"] = function()
        local obj = vim.system({"wl-paste", "--no-newline", "--primary"}, {text = true, timeout = 2000}):wait()
        if obj.code == 0 and obj.stdout then return vim.split(obj.stdout, "\n") end
        return nil
      end,
    },
  }
end
```

Setting `g:clipboard` BEFORE the first clipboard access means `provider#clipboard#Executable()` will see it and use it. No need for the reload hack.

### Fix 2: Remove `lazyredraw = true`

`lazyredraw` is known to cause visual artifacts in Neovim (multiple open issues). It exacerbates any focus-related visual flash by batching redraws. Modern Neovim (0.10+) has improved rendering that makes `lazyredraw` less necessary.

### Fix 3: Keep yanky.nvim — only fix the post-sleep hang

Instead of replacing yanky entirely, keep it and just fix the two actual problems:

1. Set `system_clipboard = { sync_with_ring = false }` to prevent the blocking wl-paste call on FocusGained
2. Use the custom `vim.g.clipboard` provider (Fix 1) which gives wl-paste a 2-second timeout for ALL clipboard reads
3. Add a standalone FocusGained/VimResume recovery autocommand with the focus-lost gap threshold

This is "Option B" from the original research report 02, and it's the minimal fix that addresses both the post-sleep freeze AND the yank blinking.

## Evidence/Examples

- **Provider source**: `/nix/store/nbgpqjr9c78gp4xnfwdhmirhwcq6xl3s-neovim-0.12.2/share/nvim/runtime/autoload/provider/clipboard.vim`
- **wl-clipboard #90**: Confirms transient window flash on GNOME
- **wl-clipboard #268**: Confirms focus stealing behavior
- **Neovim #2253, #11806, #23534**: Confirm `lazyredraw` causes cursor flash/visual artifacts
- **mwop.net**: Documents identical symptoms with WezTerm + wl-clipboard

## Confidence Level

**High** — The provider caching issue (Finding #1) directly explains why the OSC 52 fix never worked. The wl-copy transient window issue (Finding #2) is well-documented upstream. The `lazyredraw` interaction (Finding #4) has multiple supporting Neovim issues.

## Sources

- [Neovim clipboard.vim source](https://github.com/neovim/neovim/blob/master/runtime/autoload/provider/clipboard.vim)
- [wl-clipboard #90: wl-copy flashes window on GNOME](https://github.com/bugaevc/wl-clipboard/issues/90)
- [wl-clipboard #268: wl-copy spawns a window](https://github.com/bugaevc/wl-clipboard/issues/268)
- [mwop.net: Fixing wl-clipboard transient windows with Neovim](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html)
- [Neovim #2253: Cursor flashes with lazyredraw](https://github.com/neovim/neovim/issues/2253)
- [Neovim #11806: lazyredraw cursor jump](https://github.com/neovim/neovim/issues/11806)
- [Neovim #23534: lazyredraw breaks winbar](https://github.com/neovim/neovim/issues/23534)
- [LazyVim OSC52 discussion](https://github.com/LazyVim/LazyVim/discussions/2715)
- [Neovim provider docs](https://neovim.io/doc/user/provider/)
