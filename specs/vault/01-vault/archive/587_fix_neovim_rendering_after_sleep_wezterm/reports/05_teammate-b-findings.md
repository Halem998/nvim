# Teammate B Findings: Community Best Practices and Alternative Solutions

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Angle**: Alternative approaches, community patterns, 2024-2026 best practices
**Date**: 2026-05-21

## Key Findings

### 1. The Blinking Is a Known, Documented GNOME/Wayland Issue (Not Our Code)

**Neovim issue [#12622](https://github.com/neovim/neovim/issues/12622)** documents the exact symptom: when `clipboard=unnamed` or `clipboard=unnamedplus` is set on GNOME/Wayland, the app name flickers and shows as "Unknown" on every clipboard operation (`x`, `dd`, `yy`, `P`). The issue was closed as `status:blocked-external` — it's a GNOME/Wayland problem, not a Neovim bug.

**wl-clipboard issue [#90](https://github.com/bugaevc/wl-clipboard/issues/90)** confirms the root cause: `wl-copy` creates a transient Wayland surface (invisible window) to hold clipboard data. On GNOME, this causes **focus stealing** — the transient window briefly takes focus, causing the compositor to flash the window title/app name. This is labeled "focus-stealing-side-effect" and has no fix in wl-clipboard itself.

**This explains all observed symptoms in the diagnostic report**: the "WezTerm" text blinking in the top-left corner is WezTerm's title bar (with `window_decorations = "NONE"`, the compositor draws the title) flickering as GNOME transfers focus to wl-copy's transient surface and back. The "blinking cursor" is the cursor disappearing during the focus-steal round-trip.

### 2. OSC 52 Did Not Fix It Because vim.g.clipboard Was Set Too Late

**Neovim issue [#29644](https://github.com/neovim/neovim/issues/29644)** reveals a critical constraint: **`g:clipboard` can only be effectively set once, before any clipboard operation occurs**. The clipboard provider is initialized by `provider#clipboard#Executable()` which runs when `clipboard=unnamedplus` is first evaluated. After initialization, changing `vim.g.clipboard` updates the variable but does NOT re-execute the provider initialization code.

In the failed implementation, `clipboard=unnamedplus` was set in `options.lua` (early startup), but the OSC 52 provider was registered in the yank-ring plugin's `config()` function (fires on `VeryLazy` — well after startup). By that point, Neovim had already initialized the default `wl-copy` provider. **The OSC 52 override never actually took effect.**

The source code confirms this (`clipboard.vim` line 5-7):
```vim
if exists('g:loaded_clipboard_provider')
  finish
endif
```

The workaround documented in the source (lines 9-11) is:
```vim
:unlet g:loaded_clipboard_provider
:runtime autoload/provider/clipboard.vim
```

### 3. Neovim's Provider Priority: wl-copy Beats OSC 52 When clipboard Is Set

From `clipboard.vim` (line 238-264), the provider priority chain is:
1. `g:clipboard` (if set)
2. pbcopy (macOS)
3. **wl-copy (if `$WAYLAND_DISPLAY` is set)** — this wins on Wayland
4. xsel, xclip, etc.
5. **OSC 52 (dead last, AND only if `&clipboard ==# ''`)**

Line 260 is the smoking gun:
```vim
elseif get(get(g:, 'termfeatures', {}), 'osc52') && &clipboard ==# ''
  " Don't use OSC 52 when 'clipboard' is set. It can be slow and cause a lot
  " of user prompts.
  return s:set_osc52()
```

**Neovim explicitly refuses to auto-use OSC 52 when `clipboard=unnamedplus` is set.** This is by design — OSC 52 paste can freeze for 10 seconds waiting for terminal response. So on Wayland with `clipboard=unnamedplus`, Neovim always chooses wl-copy, causing the GNOME focus-steal flicker.

### 4. LazyVim's Recommended Approach: OSC 52 with Local Paste Fallback

[LazyVim discussion #2715](https://github.com/LazyVim/LazyVim/discussions/2715) and [Neovim discussion #28010](https://github.com/neovim/neovim/discussions/28010) converge on this pattern:

```lua
-- Set BEFORE clipboard=unnamedplus
vim.g.clipboard = {
  name = "OSC 52",
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
```

Key insight: **paste reads from Neovim's internal register, not from the terminal.** This avoids both the wl-paste freeze AND the OSC 52 paste timeout. External pastes use Ctrl+Shift+V (terminal paste) instead.

### 5. The "Disable unnamedplus" Alternative

[Neovim discussion #28010](https://github.com/neovim/neovim/discussions/28010) also proposes:
```vim
set clipboard=
autocmd TextYankPost * silent! call setreg('+', getreg('"'), v:event.regtype)
```

This is a lightweight approach: `clipboard` is unset (so Neovim never initializes a clipboard provider at all), and yanks are manually synced to the `+` register via autocommand. Pastes use `"+p` explicitly or terminal paste. This completely avoids wl-copy.

### 6. Yanky.nvim's `<Plug>(YankyYank)` Masked the Issue

With yanky.nvim installed, `Y` is mapped to `<Plug>(YankyYank)` → `y$`. Yanky intercepts the yank, captures to its ring, does highlighting, and then sets the register via `vim.fn.setreg()`. The clipboard provider still fires (wl-copy runs), but yanky's own visual processing (highlight timer, cursor preservation) may mask the brief focus-steal flicker by keeping the UI busy during the critical moment. When yanky was removed and native `y$` was used, the flicker became visible because there's no visual activity to mask it.

### 7. WezTerm Config: `window_decorations = "NONE"` May Amplify the Issue

The user's WezTerm config uses `window_decorations = "NONE"`, which tells WezTerm not to draw its own title bar, letting the GNOME compositor handle it. When wl-copy steals focus, GNOME redraws the compositor-drawn title bar, making the flicker more visible than it would be with WezTerm's native decorations.

### 8. `lazyredraw = true` Is Known to Cause Visual Glitches

Multiple Neovim issues ([#6729](https://github.com/neovim/neovim/issues/6729), [#23534](https://github.com/neovim/neovim/issues/23534), [#2253](https://github.com/neovim/neovim/issues/2253)) document that `lazyredraw` causes cursor flashing, statusline/winbar breakage, and inconsistent rendering. While not directly clipboard-related, it may amplify the visual impact of the wl-copy focus steal by delaying the redraw that would normally smooth over the flicker.

## Recommended Approach

**The correct fix has two parts:**

### Part 1: Set `vim.g.clipboard` to OSC 52 BEFORE `clipboard=unnamedplus` (in options.lua)

This must happen in `options.lua`, not in a lazy-loaded plugin. The OSC 52 copy function writes through the terminal escape sequence (no wl-copy, no transient window, no focus steal). Paste uses Neovim's internal register cache.

```lua
-- In options.lua, BEFORE setting clipboard=unnamedplus:
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

-- THEN set clipboard
clipboard = "unnamedplus",
```

### Part 2: Keep yanky.nvim, set `sync_with_ring = false`

Yanky still provides value (yank ring, enhanced put, highlighting, cursor preservation). Just disable the FocusGained clipboard sync that triggers the blocking wl-paste call:

```lua
system_clipboard = {
  sync_with_ring = false,
},
```

### Optional Part 3: Add debounced FocusGained recovery for post-sleep corruption

A standalone autocommand (not in yanky, not in the yank-ring module) that runs `vim.cmd("mode")` + `vim.cmd("redraw!")` only after prolonged absence (>5 seconds). This handles the original post-sleep rendering corruption without interfering with normal clipboard operations.

## Evidence/Examples

- [Neovim #12622](https://github.com/neovim/neovim/issues/12622) — GNOME/Wayland app name flicker (closed:blocked-external)
- [wl-clipboard #90](https://github.com/bugaevc/wl-clipboard/issues/90) — wl-copy focus-stealing side effect on GNOME
- [Neovim #29644](https://github.com/neovim/neovim/issues/29644) — g:clipboard can only be set once
- [Neovim #28010](https://github.com/neovim/neovim/discussions/28010) — OSC 52 copy-only with local paste
- [LazyVim #2715](https://github.com/LazyVim/LazyVim/discussions/2715) — LazyVim OSC 52 configuration
- [Neovim clipboard.vim source](https://github.com/neovim/neovim/blob/master/runtime/autoload/provider/clipboard.vim) — Provider priority chain, OSC 52 exclusion when clipboard is set
- [mwop.net blog](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html) — WezTerm-specific wl-clipboard fixes
- [Neovim #24470](https://github.com/neovim/neovim/issues/24470) — wl-paste infinite hang
- [Neovim #6729](https://github.com/neovim/neovim/issues/6729), [#23534](https://github.com/neovim/neovim/issues/23534), [#2253](https://github.com/neovim/neovim/issues/2253) — lazyredraw visual glitches
- [nramkumar.org](https://nramkumar.org/tech/blog/2025/05/11/neovim-copying-to-the-system-clipboard-in-kde/) — 2025 Neovim clipboard guide

## Confidence Level

**High** — The root cause (wl-copy focus steal on GNOME/Wayland) is documented across multiple independent sources. The provider timing constraint (g:clipboard must be set before initialization) is confirmed in both Neovim source code and issue tracker. The OSC 52 + local-paste pattern is the community-converged solution used by LazyVim and recommended in official Neovim discussions. The previous implementation's failure is fully explained by the late vim.g.clipboard assignment.
