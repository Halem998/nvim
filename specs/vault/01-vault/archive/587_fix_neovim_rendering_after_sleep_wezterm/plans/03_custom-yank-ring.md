# Implementation Plan: Task #587

- **Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_neovim-sleep-rendering.md, reports/02_yanky-alternatives.md, reports/03_custom-yank-design.md
- **Artifacts**: plans/03_custom-yank-ring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Replace yanky.nvim with a custom yank ring module (~460 LOC across 6 modules under `lua/neotex/yank/`) to fix post-sleep Neovim freezing on Wayland. The root cause is yanky.nvim's `system_clipboard.sync_with_ring = true` which triggers a blocking `wl-paste` call via `FocusGained` on wake; `wl-paste` hangs indefinitely when the compositor clipboard state is stale after sleep, freezing the entire TUI. The custom implementation uses `vim.system()` with a 2-second timeout for all clipboard reads, making it structurally impossible for clipboard staleness to freeze Neovim. Post-sleep rendering recovery autocommands (`:mode`, `:redraw!`, treesitter invalidation) are bundled. Definition of done: system sleep no longer causes focused-tab Neovim freeze or rendering corruption.

### Research Integration

Three research reports inform this plan:

1. **Report 01** (root cause analysis): Identified yanky.nvim's `sync_with_ring` as the primary cause -- `vim.fn.getreg('+')` on `FocusGained` synchronously calls `wl-paste` which hangs after sleep on Wayland/GNOME. Confirmed by upstream issues (yanky#123, neovim#24470, neovim#25832, LazyVim#3981). Secondary cause: no `VimResume`/`FocusGained` autocommands for terminal state reset.

2. **Report 02** (alternatives): Audited the user's actual yanky feature usage -- put cycling is NOT used despite being yanky's signature feature. Evaluated nvim-neoclip.lua, yankbank-nvim, and custom implementation. A custom replacement covering the used feature set is feasible at ~200-460 LOC. The blocking `vim.fn.getreg('+')` is a Neovim-level problem (issue #24470), not plugin-specific.

3. **Report 03** (architecture design): Complete module architecture with code sketches for all 6 modules. Established `lua/neotex/yank/` as a new namespace, documented `vim.system()` API usage patterns, and designed the non-blocking clipboard sync flow. Includes detailed LOC estimates, API references, and risk analysis.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Eliminate the post-sleep TUI freeze caused by blocking `wl-paste` calls on `FocusGained`
- Preserve all yanky features the user actually uses: yank ring, enhanced put, yank highlighting, Telescope history picker, clipboard sync
- Add non-blocking clipboard sync via `vim.system()` with 2-second timeout
- Add post-sleep rendering recovery autocommands (`:mode`, `:redraw!`, treesitter invalidation)
- Remove yanky.nvim as an external dependency
- Clean up all yanky references in telescope.lua, which-key.lua, and tools/init.lua

**Non-Goals**:
- Put cycling (`<Plug>(YankyCycleForward/Backward)`) -- user does not use this feature
- Persistent storage (sqlite, shada) -- user has `storage = "memory"` currently
- Custom clipboard provider (`vim.g.clipboard`) -- addressed architecturally by async reads
- WezTerm-side reset sequence injection -- Neovim-side fix is sufficient
- Support for X11/xclip/xsel fallback testing (Wayland-only system)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Custom yank ring misses edge cases yanky handles (visual mode put, expression register) | M | M | The user's actual usage is limited to basic yank/put; edge cases can be addressed post-launch |
| `vim.system()` callback not firing in edge cases | M | L | Fallback to `pcall(vim.fn.getreg, '+')` when no clipboard tool found; timeout guarantees no hang |
| Telescope picker API changes break custom picker | L | L | Telescope core API is stable; picker uses same patterns as dozens of community plugins |
| Treesitter `parser:invalidate()` API changes in future Neovim | L | L | Wrapped in pcall; failure is non-fatal (just no treesitter recovery) |
| lazy.nvim `dir` spec for local module does not trigger correctly | M | L | Verified pattern from report; fallback is `config` function call without lazy-loading |
| Removing yanky.nvim breaks something unexpected (e.g., other plugin depending on it) | M | L | Search codebase for all `yanky` references before deletion; telescope.lua and which-key.lua are the only dependents |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create core yank ring modules [COMPLETED]

**Goal**: Create the 4 foundational modules under `lua/neotex/yank/` that have no dependencies on other project files.

**Tasks**:
- [ ] Create directory `lua/neotex/yank/`
- [ ] Create `lua/neotex/yank/ring.lua` -- Circular buffer data structure (~65 LOC). Implements `setup()`, `push()` with consecutive deduplication, `all()`, `get()`, `count()`, `clear()`. Max size configurable (default 50). Uses `vim.uv.now()` for entry timestamps.
- [ ] Create `lua/neotex/yank/clipboard.lua` -- Non-blocking clipboard via `vim.system()` (~130 LOC). Implements `setup()`, `read_async()`, `read_sync()`, `write()`, `sync_to_ring()`, `update_last()`. Auto-detects `wl-paste`/`xclip`/`xsel` based on `$WAYLAND_DISPLAY`/`$DISPLAY`. All reads use 2-second timeout. Falls back to `pcall(vim.fn.getreg, '+')` only when no clipboard tool found.
- [ ] Create `lua/neotex/yank/highlight.lua` -- Thin wrapper around `vim.hl.on_yank()` (~20 LOC). Configurable higroup (default `IncSearch`), timeout (default 150ms), on_macro, on_visual flags.
- [ ] Create `lua/neotex/yank/recovery.lua` -- Post-sleep rendering recovery (~40 LOC). `recover()` function runs `:mode`, `:redraw!`, `parser:invalidate()` + `parser:parse()`, `doautocmd CursorMoved`. `setup()` registers `FocusGained`/`VimResume` autocommand with provided augroup.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/yank/ring.lua` - Create new file
- `lua/neotex/yank/clipboard.lua` - Create new file
- `lua/neotex/yank/highlight.lua` - Create new file
- `lua/neotex/yank/recovery.lua` - Create new file

**Verification**:
- Each module loads without error: `nvim --headless -c "lua require('neotex.yank.ring')" -c "q"`
- Each module returns a table with expected public functions
- No global variable pollution

---

### Phase 2: Create Telescope picker and init module [COMPLETED]

**Goal**: Create the Telescope picker (adapted from the user's existing custom picker) and the main `init.lua` entry point that wires all modules together.

**Tasks**:
- [ ] Create `lua/neotex/yank/telescope.lua` -- Telescope picker (~65 LOC). `open(ring)` function creates a picker with buffer previewer showing yanked text with filetype-aware syntax highlighting. Adapted from the existing `_G.YankyTelescopeHistory()` in yanky.lua (lines 92-162). On selection: `vim.fn.setreg('+', content, regtype)` then `vim.cmd('normal! "+p')` (replaces yanky's `use_temporary_register` approach which is no longer available).
- [ ] Create `lua/neotex/yank/init.lua` -- Entry point (~100 LOC). `setup(opts)` merges config with defaults, initializes all submodules, creates `NeoTexYank` augroup with `clear = true`. Registers autocommands: `TextYankPost` (capture to ring + highlight), `FocusGained` (async clipboard sync via `clipboard.sync_to_ring`), `VimLeavePre` (cleanup). Exports `telescope_history()`, `clear_history()`, `ring()` convenience functions. Stores `_G.YankTelescopeHistory` global for which-key compatibility.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/yank/telescope.lua` - Create new file
- `lua/neotex/yank/init.lua` - Create new file

**Verification**:
- Full module loads: `nvim --headless -c "lua require('neotex.yank').setup({})" -c "q"`
- `_G.YankTelescopeHistory` is defined after setup
- Autocommands exist in `NeoTexYank` group: `nvim --headless -c "lua require('neotex.yank').setup({}); print(vim.inspect(vim.api.nvim_get_autocmds({group='NeoTexYank'})))" -c "q"`

---

### Phase 3: Create plugin spec and remove yanky.nvim [COMPLETED]

**Goal**: Create the lazy.nvim plugin spec that replaces yanky.lua, and update tools/init.lua to load the new module instead.

**Tasks**:
- [ ] Create `lua/neotex/plugins/tools/yank-ring.lua` -- lazy.nvim plugin spec (~40 LOC). Uses `dir = vim.fn.stdpath("config") .. "/lua/neotex/yank"` for local module loading. Lazy-loads on `TextYankPost` event and yank/put keys (`y`, `p`, `P`, `gp`, `gP`). Depends on Telescope. Config function calls `require("neotex.yank").setup()` with ring size 50, clipboard timeout 2000ms, highlight IncSearch/150ms, recovery enabled.
- [ ] Update `lua/neotex/plugins/tools/init.lua` line 82: Change `safe_require("neotex.plugins.tools.yanky")` to `safe_require("neotex.plugins.tools.yank-ring")`
- [ ] Update `lua/neotex/plugins/tools/init.lua` line 109: Change `add_if_valid(yanky_module)` to `add_if_valid(yank_ring_module)` (and the variable name on line 82 from `yanky_module` to `yank_ring_module`)
- [ ] Delete `lua/neotex/plugins/tools/yanky.lua`

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/yank-ring.lua` - Create new file
- `lua/neotex/plugins/tools/init.lua` - Modify lines 82 and 109 (rename yanky references)
- `lua/neotex/plugins/tools/yanky.lua` - Delete

**Verification**:
- `init.lua` loads the new spec: `nvim --headless -c "lua local specs = require('neotex.plugins.tools'); for _, s in ipairs(specs) do if s.name == 'neotex-yank-ring' then print('FOUND') end end" -c "q"`
- Deleted yanky.lua no longer exists
- No Lua require errors on startup

---

### Phase 4: Update telescope.lua and which-key.lua references [COMPLETED]

**Goal**: Remove all yanky.nvim references from telescope.lua and which-key.lua, replacing them with the new custom module's API.

**Tasks**:
- [ ] Update `lua/neotex/plugins/editor/telescope.lua` line 13: Remove `"gbprod/yanky.nvim"` from the dependencies list
- [ ] Update `lua/neotex/plugins/editor/telescope.lua` line 132: Remove `telescope.load_extension("yank_history")` (the custom module does not register a Telescope extension)
- [ ] Update `lua/neotex/plugins/editor/which-key.lua` line 500: Change `_G.YankyTelescopeHistory()` to `_G.YankTelescopeHistory()` in the find yanks mapping (note: name change drops the second 'y' to distinguish from yanky)
- [ ] Update `lua/neotex/plugins/editor/which-key.lua` line 822: Change `require("yanky").clear_history()` to `require("neotex.yank").clear_history()`
- [ ] Update `lua/neotex/plugins/editor/which-key.lua` line 823: Change `_G.YankyTelescopeHistory()` to `_G.YankTelescopeHistory()` in the yank history mapping

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `lua/neotex/plugins/editor/telescope.lua` - Remove yanky dependency (line 13) and extension load (line 132)
- `lua/neotex/plugins/editor/which-key.lua` - Update 3 references (lines 500, 822, 823)

**Verification**:
- No remaining `yanky` references in telescope.lua: `grep -i yanky lua/neotex/plugins/editor/telescope.lua` returns nothing
- No remaining `yanky` references in which-key.lua: `grep -i yanky lua/neotex/plugins/editor/which-key.lua` returns nothing (except comments if any)
- which-key yank group functions resolve correctly
- Telescope loads without error about missing `yank_history` extension

---

### Phase 5: Integration testing and cleanup [COMPLETED]

**Goal**: Verify the complete system works end-to-end, confirm no remaining yanky references in the codebase, and perform a clean Neovim startup test.

**Tasks**:
- [ ] Search entire codebase for remaining `yanky` references: `grep -r "yanky" lua/` -- only comments should remain (if any)
- [ ] Search for the old global function name: `grep -r "YankyTelescopeHistory" lua/` -- should return nothing
- [ ] Verify clean Neovim startup: `nvim --headless -c "lua vim.defer_fn(function() print('OK') vim.cmd('q') end, 2000)"` -- no errors in `:messages`
- [ ] Verify yank ring module loads and autocommands are registered: `nvim --headless -c "lua require('neotex.yank').setup({}); local cmds = vim.api.nvim_get_autocmds({group='NeoTexYank'}); print('Autocmds: ' .. #cmds)" -c "q"`
- [ ] Verify clipboard module detects wl-paste on Wayland: `nvim --headless -c "lua local cb = require('neotex.yank.clipboard'); print('WAYLAND_DISPLAY=' .. tostring(vim.env.WAYLAND_DISPLAY))" -c "q"`
- [ ] Verify recovery module functions exist: `nvim --headless -c "lua local r = require('neotex.yank.recovery'); print(type(r.recover))" -c "q"`
- [ ] Remove yanky.nvim from lazy.nvim's lock file by running `:Lazy clean` (or let lazy.nvim handle it on next sync)

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- No new files; verification-only phase
- `lazy-lock.json` - yanky.nvim entry removed by `:Lazy clean` (automatic)

**Verification**:
- Zero `yanky` require paths in the codebase (excluding comments and specs/)
- Clean Neovim startup with no error messages
- All 6 yank modules load successfully
- `NeoTexYank` augroup contains TextYankPost, FocusGained, VimResume, and VimLeavePre autocmds
- Yank operation captures to ring (manual test)
- Telescope picker opens with `<leader>fy` or `<leader>yh` (manual test)
- `<leader>yc` clears history without error (manual test)

## Testing & Validation

- [ ] **Module load test**: All 6 modules under `lua/neotex/yank/` load without error in headless mode
- [ ] **Autocommand registration**: `NeoTexYank` augroup contains expected autocommands (TextYankPost, FocusGained, VimResume, VimLeavePre)
- [ ] **Yank capture**: Yanking text adds entries to the ring (verify via `require('neotex.yank').ring().all()`)
- [ ] **Clipboard async read**: `clipboard.read_async()` returns content from wl-paste without blocking (verify exit code 0, content matches clipboard)
- [ ] **Clipboard timeout**: Simulated hang (e.g., `sleep 10` instead of `wl-paste`) times out at 2 seconds with code 124
- [ ] **Telescope picker**: `<leader>fy` and `<leader>yh` open the yank history picker with previewer
- [ ] **Clear history**: `<leader>yc` clears ring and shows notification
- [ ] **Recovery**: `require('neotex.yank.recovery').recover()` executes without error (runs `:mode`, `:redraw!`, treesitter invalidation)
- [ ] **No yanky references**: `grep -r "yanky" lua/` returns only comments or nothing
- [ ] **Clean startup**: Neovim starts with no error messages related to yank, yanky, or clipboard
- [ ] **Post-sleep test** (manual): Put computer to sleep with Neovim in focused WezTerm tab, wake, verify no freeze and display recovers within seconds

## Artifacts & Outputs

- `lua/neotex/yank/init.lua` - Entry point and setup
- `lua/neotex/yank/ring.lua` - Circular buffer data structure
- `lua/neotex/yank/clipboard.lua` - Non-blocking clipboard via vim.system()
- `lua/neotex/yank/highlight.lua` - Yank highlighting wrapper
- `lua/neotex/yank/telescope.lua` - Telescope picker for yank history
- `lua/neotex/yank/recovery.lua` - Post-sleep rendering recovery
- `lua/neotex/plugins/tools/yank-ring.lua` - lazy.nvim plugin spec (replaces yanky.lua)
- `lua/neotex/plugins/tools/init.lua` - Updated module loading (yanky -> yank-ring)
- `lua/neotex/plugins/editor/telescope.lua` - Removed yanky dependency and extension
- `lua/neotex/plugins/editor/which-key.lua` - Updated function references
- `lua/neotex/plugins/tools/yanky.lua` - Deleted

## Rollback/Contingency

If the custom implementation causes issues:

1. **Quick revert**: Restore `lua/neotex/plugins/tools/yanky.lua` from git (`git checkout -- lua/neotex/plugins/tools/yanky.lua`), revert changes to telescope.lua, which-key.lua, and tools/init.lua. Delete `lua/neotex/yank/` directory. This restores yanky.nvim with the original configuration.

2. **Minimal fix fallback**: If the full custom replacement is problematic but the freeze must be fixed immediately, apply only the minimal fix from Report 01: set `system_clipboard = { sync_with_ring = false }` in the existing yanky.lua. This eliminates the freeze at the cost of losing automatic clipboard sync to the yank ring.

3. **Git safety**: All changes are in `lua/` and affect no system configuration. A `git stash` or `git checkout -- lua/` reverts everything cleanly.
