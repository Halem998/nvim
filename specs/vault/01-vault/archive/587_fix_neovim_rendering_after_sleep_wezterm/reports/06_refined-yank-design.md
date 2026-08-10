# Refined Custom Yank Ring Design

**Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
**Artifact**: 06 - Refined architecture (post-fixes)
**Date**: 2026-05-21
**Session**: sess_1779384151_2b67eb
**Prior Reports**: 03_custom-yank-design.md (6-module architecture), 05_team-research.md (root cause)

---

## Executive Summary

The three independent fixes already committed to the config eliminate most of the complexity
from the previous 6-module design. With `clipboard.lua` and `recovery.lua` removed, the
yank ring can be implemented in **3 modules + 1 plugin spec** (~200 LOC total). The design
is simpler, has fewer moving parts, and is less likely to break during implementation.

Key decisions:
- Drop `clipboard.lua`: OSC 52 provider in `options.lua` eliminates wl-copy; no async sync needed
- Drop `recovery.lua`: `autocmds.lua` handles post-sleep recovery with proper 5s debounce
- Keep `ring.lua`, `highlight.lua`, `telescope.lua`: unchanged from report 03
- Collapse `init.lua` to ~60 LOC (no clipboard sync, no recovery management)
- Load on `VeryLazy` (not `TextYankPost` + keys table, which broke native operators)
- The `keys` table in the plugin spec must be empty or absent — native y/p/P/gp/gP work fine
- Preserve `_G.YankyTelescopeHistory` as the global name (no rename needed)

---

## Feature Audit: What Does the User Actually Use?

### Used Features (from yanky.lua + which-key.lua)

| Feature | Location | Notes |
|---------|----------|-------|
| Yank ring (TextYankPost capture) | yanky.lua:40-54 | Core. Keep. |
| Yank highlighting | yanky.lua:75-78 | Used. Keep via `vim.hl.on_yank()`. |
| Telescope history picker | yanky.lua:92-162 | Used. `<leader>fy` and `<leader>yh`. |
| Clear history | which-key.lua:821 | Used. `<leader>yc`. |
| Deduplicate | yanky.lua:87 | Keep for ring quality. |
| History length limit | yanky.lua:42 | Keep (50 entries). |

### NOT Used Features (can be dropped)

| Feature | Notes |
|---------|-------|
| Put cycling (`[y`/`]y`) | No keymaps in which-key.lua |
| `<Plug>(YankyYank)` intercept | Keymaps re-route y/p/P/gp/gP to yanky Plug; drop these |
| `<Plug>(YankyPutAfter)` etc. | Same — native operators work correctly without interception |
| Cursor position preservation | yanky.lua:83-85 — no evidence this is used or needed |
| Numbered register sync | yanky.lua:47 — Neovim does this natively |
| FocusGained clipboard sync | yanky.lua sync_with_ring — disabled in current config |
| Persistent storage (shada) | yanky uses memory storage anyway (yanky.lua:43) |
| `telescope.load_extension("yank_history")` | The custom picker bypasses this already |

### Yanky's `<Plug>` Mappings: What They Actually Add

Yanky's `<Plug>(YankyYank)`, `<Plug>(YankyPutAfter)`, etc. do three things beyond native operators:
1. **Ring capture on yank**: Already handled by `TextYankPost` without any interception
2. **Ring-aware put**: Puts from the ring's current position (needed only for put cycling)
3. **Cursor position preservation**: Minor UX improvement, not missed in practice

Since put cycling is not used, the `<Plug>` interception adds nothing. Native operators are
sufficient. The `keys` table in the previous plugin spec (report 03) is **exactly what broke
native operators** — lazy.nvim treated y/p/P/gp/gP as load triggers and mapped them to
<Plug> variants before the module was ready.

**Decision**: No `keys` table in the plugin spec. No `<Plug>` mappings. Native operators only.

---

## Architecture Simplification

### What Changed Since Report 03

| Module | Report 03 | This Report | Reason |
|--------|-----------|-------------|--------|
| `ring.lua` | Yes (~65 LOC) | Yes (~65 LOC) | Unchanged |
| `highlight.lua` | Yes (~20 LOC) | Yes (~20 LOC) | Unchanged |
| `telescope.lua` | Yes (~65 LOC) | Yes (~65 LOC) | Unchanged |
| `init.lua` | Yes (~100 LOC) | Yes (~60 LOC) | No clipboard sync, no recovery setup |
| `clipboard.lua` | Yes (~130 LOC) | **DROPPED** | OSC 52 in options.lua handles it |
| `recovery.lua` | Yes (~40 LOC) | **DROPPED** | autocmds.lua handles it |
| `yank-ring.lua` (spec) | Yes (~40 LOC) | Yes (~30 LOC) | No keys table, simpler |

**Net result**: 4 files instead of 7, ~200 LOC instead of ~420 LOC (excluding plugin spec).

### Module Layout

```
lua/neotex/yank/
  init.lua         -- Entry point, setup(), TextYankPost autocmd, augroup
  ring.lua         -- Circular buffer data structure
  highlight.lua    -- Thin wrapper around vim.hl.on_yank()
  telescope.lua    -- Telescope picker (adapted from existing custom picker)

lua/neotex/plugins/tools/
  yank-ring.lua    -- lazy.nvim plugin spec (replaces yanky.lua)
```

---

## Clipboard Sync on FocusGained: Decision

The OSC 52 provider's paste function reads from local register `""` (the unnamed register),
NOT from the system clipboard. The implementation in `options.lua` lines 34-39 is:

```lua
paste = {
  ["+"] = function()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end,
```

This means: when Neovim needs to paste from the `+` register (system clipboard), it returns
the contents of the anonymous register `""`. The consequence:

- **Local yanks**: Work correctly (native y writes to `""` and `+`; OSC 52 writes to terminal clipboard)
- **External clipboard content** (copied from browser, etc.): Does NOT appear in the yank ring

Should we add async FocusGained sync via `wl-paste`? The analysis:

**Arguments for async FocusGained sync:**
- External clipboard content never reaches the yank ring
- User could switch to browser, copy text, come back, and `<leader>fy` shows no external yanks
- The original yanky feature (sync_with_ring = true) was valued enough to be enabled by default

**Arguments against:**
- `wl-paste` still creates a brief Wayland client connection (lower risk than `wl-copy`, but not zero)
- The post-sleep scenario is the problem: stale compositor clipboard state causes `wl-paste` to hang
- With `sync_with_ring = false` (current state), the user is already accepting "no external sync"
- The FocusGained debounce in `autocmds.lua` uses 5s threshold — async sync would trigger on EVERY
  focus change including very brief ones

**Decision: No async FocusGained clipboard sync in the yank ring module.**

The OSC 52 paste-from-register approach is intentional: it trades "external clipboard in yank ring"
for "no wl-paste timeout risk." The user already accepted this trade with `sync_with_ring = false`.

If the user later wants external clipboard content in the ring, the correct approach is:
- A user-invoked `<leader>yv` ("yank from clipboard") that reads `wl-paste` once on demand
- Not an automatic FocusGained handler

This decision also removes the last dependency on `wl-paste` from the yank module entirely.

---

## Plugin Spec Design

### Load Strategy

Load on `VeryLazy` (deferred until after UI render). This is the correct approach because:
- `TextYankPost` autocommands only fire after yank operations, which cannot happen before Neovim
  is fully rendered anyway — there is no risk of missing early yanks
- `VeryLazy` avoids the keys-table trap that broke native operators in the previous attempt
- The module is self-contained: it registers its own autocommands in `setup()`

### Keys Table

**No keys table.** The module does not intercept y/p/P/gp/gP. Native operators work correctly
and `TextYankPost` captures all yanks. The `keys` table in the previous spec was the direct
cause of the operator breakage.

### Global Function Name

Keep `_G.YankyTelescopeHistory` — which-key.lua already calls this name on lines 499 and 822.
Renaming would require updating both references without any benefit.

### `dir` vs Lazy Registry

Use `dir = vim.fn.stdpath("config") .. "/lua/neotex/yank"` to load the local module as a
lazy.nvim plugin. This is the correct pattern for local plugins (same as himalaya-plugin).
The module does not need a `name` field (lazy.nvim derives it from `dir`).

---

## Complete Module Specifications

### `lua/neotex/yank/ring.lua` (unchanged from report 03)

No changes needed. The circular buffer implementation is correct and complete. ~65 LOC.

Key properties:
- `M._entries = {}` — most-recent-first order
- `M.push(entry)` — consecutive deduplication, trim to max_size
- `M.all()`, `M.get(index)`, `M.count()`, `M.clear()`
- `M.setup({ max_size = 50 })`

### `lua/neotex/yank/highlight.lua` (unchanged from report 03)

No changes needed. 20 LOC wrapper around `vim.hl.on_yank()`.

### `lua/neotex/yank/telescope.lua` (minor change from report 03)

The paste action in report 03 used `vim.cmd('normal! "+p')`. This should use `vim.fn.setreg`
followed by a simpler paste. The existing custom picker in `yanky.lua` lines 142-157 uses
`yanky.utils.use_temporary_register` — that yanky dependency is dropped.

The correct minimal paste action:
```lua
vim.schedule(function()
  vim.fn.setreg('"', selection.value.regcontents, selection.value.regtype)
  vim.cmd('normal! p')
end)
```

This puts from the unnamed register (not `+`), which avoids triggering the OSC 52 provider
and avoids any wl-copy invocation. Pure local register paste.

### `lua/neotex/yank/init.lua` (simplified from report 03)

Key changes from report 03:
- Remove all `clipboard` module imports and calls
- Remove all `recovery` module imports and calls
- Remove FocusGained autocommand
- Keep: TextYankPost capture, highlight, cleanup

```lua
--- neotex.yank
--- Custom yank ring with built-in highlighting and Telescope history.
---
--- Replaces yanky.nvim. Uses native TextYankPost for capture and
--- vim.hl.on_yank() for highlighting. No external process dependencies.
---
--- Clipboard writes: handled by OSC 52 provider in options.lua
--- Post-sleep recovery: handled by autocmds.lua FocusGained handler
---
--- Usage (via lazy.nvim plugin spec):
---   require("neotex.yank").setup({})

local M = {}

local ring = require("neotex.yank.ring")
local highlight = require("neotex.yank.highlight")
local telescope = require("neotex.yank.telescope")

local defaults = {
  ring = {
    max_size = 50,
  },
  highlight = {
    higroup = "IncSearch",
    timeout = 150,
    on_macro = false,
    on_visual = true,
  },
}

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", defaults, opts or {})

  ring.setup(config.ring)
  highlight.setup(config.highlight)

  local group = vim.api.nvim_create_augroup("NeoTexYank", { clear = true })

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    pattern = "*",
    callback = function()
      local event = vim.v.event
      -- Skip black hole register deletions
      if event.operator == "d" and event.regname == "_" then
        return
      end
      local regcontents = table.concat(event.regcontents, "\n")
      ring.push({
        regcontents = regcontents,
        regtype = event.regtype,
        filetype = vim.bo.filetype,
        timestamp = vim.uv.now(),
      })
      highlight.on_yank()
    end,
    desc = "Yank: capture to ring and highlight",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      ring.clear()
    end,
    desc = "Yank: cleanup on exit",
  })

  M._ring = ring
end

function M.telescope_history()
  if not M._ring then
    vim.notify("[yank] Module not initialized", vim.log.levels.WARN)
    return
  end
  telescope.open(M._ring)
end

function M.clear_history()
  if M._ring then
    M._ring.clear()
  end
  vim.notify("[yank] History cleared", vim.log.levels.INFO)
end

return M
```

**LOC**: ~60

### `lua/neotex/plugins/tools/yank-ring.lua` (plugin spec)

```lua
-----------------------------------------------------
-- Custom Yank Ring
--
-- Replaces yanky.nvim. Captures yanks via TextYankPost,
-- provides yank history with Telescope picker, and highlights
-- yanked text using vim.hl.on_yank().
--
-- Clipboard writes: OSC 52 provider (options.lua)
-- Post-sleep recovery: FocusGained handler (autocmds.lua)
-----------------------------------------------------

return {
  dir = vim.fn.stdpath("config") .. "/lua/neotex/yank",
  lazy = true,
  event = "VeryLazy",
  dependencies = {
    { "nvim-telescope/telescope.nvim", lazy = true },
  },
  config = function()
    local yank = require("neotex.yank")
    yank.setup({
      ring = { max_size = 50 },
      highlight = { higroup = "IncSearch", timeout = 150 },
    })
    -- Preserve the existing global name that which-key.lua already uses
    _G.YankyTelescopeHistory = function()
      yank.telescope_history()
    end
  end,
}
```

**LOC**: ~25

---

## All File Changes Required

### Files to Create

| File | Action | LOC |
|------|--------|-----|
| `lua/neotex/yank/ring.lua` | Create | ~65 |
| `lua/neotex/yank/highlight.lua` | Create | ~20 |
| `lua/neotex/yank/telescope.lua` | Create | ~65 |
| `lua/neotex/yank/init.lua` | Create | ~60 |
| `lua/neotex/plugins/tools/yank-ring.lua` | Create | ~25 |

### Files to Modify

**`lua/neotex/plugins/editor/telescope.lua`**:
- Line 13: Remove `"gbprod/yanky.nvim"` from dependencies array
- Line 132: Remove `telescope.load_extension("yank_history")`
- No other changes needed

**`lua/neotex/plugins/editor/which-key.lua`**:
- Line 499: Already calls `_G.YankyTelescopeHistory()` — NO CHANGE (global name preserved)
- Line 821: Change `require("yanky").clear_history()` to `require("neotex.yank").clear_history()`
- Line 822: Already calls `_G.YankyTelescopeHistory()` — NO CHANGE (global name preserved)

**`lua/neotex/plugins/tools/init.lua`**:
- Line 82: Change `safe_require("neotex.plugins.tools.yanky")` to `safe_require("neotex.plugins.tools.yank-ring")`
- Line 109: Change `add_if_valid(yanky_module)` to `add_if_valid(yank_module)` (and rename the variable on line 82)

### Files to Delete

| File | Why |
|------|-----|
| `lua/neotex/plugins/tools/yanky.lua` | Replaced by yank-ring.lua |

---

## Implementation Notes

### TextYankPost Event Data

`vim.v.event` in a TextYankPost callback provides:
```lua
{
  operator = "y",          -- "y", "d", "c", "s", "x"
  regname = "",            -- register name ("" = unnamed, "+" = clipboard, etc.)
  regtype = "v",           -- "v" (char), "V" (line), "\x16" (block)
  regcontents = {"line1"}, -- table of strings (lines)
  visual = false,
  inclusive = false,
}
```

The `regcontents` field is a **table of strings** (one per line). Use
`table.concat(event.regcontents, "\n")` for the ring entry. This matches
how the existing custom picker in `yanky.lua` accesses `entry.value.regcontents`.

### The `dir`-based Plugin Pattern

The `dir` field in a lazy.nvim spec tells lazy to load from a local filesystem path rather
than fetching from git. The `lua/neotex/yank/` directory must contain `init.lua` (which serves
as the module's entry point when `require("neotex.yank")` is called).

Verify pattern with the himalaya-plugin:
```lua
-- lua/neotex/plugins/tools/himalaya-plugin.lua (for reference)
dir = vim.fn.stdpath("config") .. "/lua/neotex/plugins/tools/himalaya",
```

The yank ring uses the same pattern with a cleaner top-level path.

### Ring Entry Deduplication

Consecutive deduplication (comparing only against the most recent entry) is sufficient and
matches the user's current yanky config (`deduplicate = true` in yanky deduplicates
consecutive identical yanks). Full ring deduplication would be heavier and is not needed.

### Highlight Timing

`vim.hl.on_yank()` must be called from inside a TextYankPost autocommand callback. It
internally uses `vim.v.event` to determine the yanked region. The `highlight.on_yank()` call
in `init.lua` is in exactly the right place.

### Telescope Paste Action

Using `vim.fn.setreg('"', ...)` + `normal! p` (unnamed register) is correct and avoids:
- OSC 52 provider trigger (which would happen with `vim.fn.setreg('+', ...)`)
- wl-copy invocation (which would happen with `normal! "+p`)
- Any external process involvement

---

## Questions Answered

**Q1: Can we reduce to 3-4 modules?**
Yes. 4 modules (ring, highlight, telescope, init) plus 1 plugin spec. Down from 6 modules.

**Q2: Should we add async FocusGained clipboard sync?**
No. The OSC 52 paste-from-register approach is intentional. External clipboard content
does not need to flow into the yank ring automatically. The user accepted this trade with
`sync_with_ring = false`. A user-invoked `<leader>yv` command could be added later.

**Q3: Should we keep native operators or provide `<Plug>` wrappers?**
Native operators only. `<Plug>` interception broke native operators in the previous attempt
and adds nothing when put cycling is not used.

**Q4: What does yanky's interception actually add?**
Beyond ring capture (already handled by TextYankPost): put cycling and cursor position
preservation. Neither is used by the user. The interception adds zero user-visible benefit.

**Q5: Load on VeryLazy vs TextYankPost?**
VeryLazy. TextYankPost cannot fire before the user can type, so no early yanks are missed.
VeryLazy avoids the keys-table trap entirely.

**Q6: Should `_G.YankyTelescopeHistory` be renamed?**
No. which-key.lua already calls `_G.YankyTelescopeHistory()` on lines 499 and 822. Keeping
the name eliminates two which-key.lua edits. The name is slightly misleading but the user
will not see it.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| `dir`-based plugin not found by lazy.nvim | High | Verify `lua/neotex/yank/init.lua` exists before loading |
| `vim.hl.on_yank()` signature change | Low | Stable API since Neovim 0.5; wrapped in pcall if needed |
| Telescope API change breaks picker | Low | Core picker API is stable; use same pattern as existing custom picker |
| which-key.lua line 821 references `yanky` | Medium | Simple replace: `require("yanky")` -> `require("neotex.yank")` |
| `VimLeavePre` cleanup fires before autocmd.lua cleanup | None | Both handlers are independent, order doesn't matter |
| Missing early yanks (before VeryLazy fires) | Very Low | VeryLazy fires after first UI render; no user input possible before that |

---

## Appendix: Complete File Change Summary

```
CREATE: lua/neotex/yank/ring.lua              (~65 LOC)
CREATE: lua/neotex/yank/highlight.lua         (~20 LOC)
CREATE: lua/neotex/yank/telescope.lua         (~65 LOC)
CREATE: lua/neotex/yank/init.lua              (~60 LOC)
CREATE: lua/neotex/plugins/tools/yank-ring.lua (~25 LOC)

MODIFY: lua/neotex/plugins/editor/telescope.lua
  - Remove line 13:  "gbprod/yanky.nvim" from dependencies
  - Remove line 132: telescope.load_extension("yank_history")

MODIFY: lua/neotex/plugins/editor/which-key.lua
  - Line 499: NO CHANGE (_G.YankyTelescopeHistory preserved)
  - Line 821: require("yanky").clear_history() -> require("neotex.yank").clear_history()
  - Line 822: NO CHANGE (_G.YankyTelescopeHistory preserved)

MODIFY: lua/neotex/plugins/tools/init.lua
  - Line 82: safe_require("neotex.plugins.tools.yanky") -> safe_require("neotex.plugins.tools.yank-ring")
  - Rename local variable yanky_module -> yank_module (lines 82 and 109)

DELETE: lua/neotex/plugins/tools/yanky.lua
```

**Total LOC created**: ~235
**Files modified**: 3
**Files deleted**: 1
**External dependencies removed**: gbprod/yanky.nvim
