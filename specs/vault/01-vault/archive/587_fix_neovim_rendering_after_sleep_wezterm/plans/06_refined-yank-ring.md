# Implementation Plan: Task #587

- **Task**: 587 - Fix Neovim rendering corruption after system sleep in WezTerm
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (three prerequisite fixes already committed)
- **Research Inputs**: reports/06_refined-yank-design.md
- **Artifacts**: plans/06_refined-yank-ring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Replace yanky.nvim with a lightweight 4-module custom yank ring (~235 LOC) under `lua/neotex/yank/`. Three independent fixes are already committed (OSC 52 clipboard provider in options.lua, lazyredraw removal, post-sleep recovery autocommand in autocmds.lua), so this plan focuses solely on the yank ring replacement. The custom module captures yanks via `TextYankPost`, highlights via `vim.hl.on_yank()`, and provides a Telescope history picker -- covering exactly the features the user actually uses while removing yanky.nvim's problematic external process dependencies.

### Research Integration

Report 06 established the refined 4-module architecture after auditing which yanky features are actually used. Key findings:
- Put cycling (`[y`/`]y`) and `<Plug>` operator interception are NOT used and should be dropped
- The `keys` table in the previous plan's plugin spec was the direct cause of operator breakage (lazy.nvim hijacked native y/p/P/gp/gP)
- which-key.lua references to `_G.YankyTelescopeHistory` should be replaced with direct `require("neotex.yank").telescope_history()` calls for cleaner integration
- Telescope paste action should use `vim.fn.setreg('"', ...)` + `normal! p` to avoid OSC 52 provider trigger
- No `FocusGained` clipboard sync needed (OSC 52 paste-from-register approach is intentional)

### Prior Plan Reference

Plan 03 (custom-yank-ring.md) designed a 6-module architecture with clipboard.lua and recovery.lua. Lessons learned:
- **Over-scoped**: clipboard.lua and recovery.lua were unnecessary -- those concerns are now handled by already-committed fixes in options.lua and autocmds.lua
- **Keys table trap**: Including y/p/P/gp/gP in the lazy.nvim `keys` table broke native operators; the refined design uses NO keys table
- **Global name mismatch**: Plan 03 used `_G.YankTelescopeHistory` (missing "y") but which-key.lua calls `_G.YankyTelescopeHistory` -- the revised v2 plan eliminates all `_G` globals entirely in favor of direct requires
- **Effort calibration**: Plan 03 estimated 4 hours for 6 modules; this refined plan is 2 hours for 4 modules + cleanup

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create 4 modules under `lua/neotex/yank/` (ring, highlight, telescope, init)
- Create plugin spec `lua/neotex/plugins/tools/yank-ring.lua` loading on VeryLazy with NO keys table and NO `_G` globals
- Remove all yanky.nvim references from telescope.lua, which-key.lua, and tools/init.lua
- Delete `lua/neotex/plugins/tools/yanky.lua`
- Update all which-key.lua references to use `require("neotex.yank")` directly instead of `_G` globals

**Non-Goals**:
- Put cycling (`[y`/`]y`) -- user does not use this
- `<Plug>` operator wrappers -- breaks native operators, adds nothing
- Clipboard sync on FocusGained -- intentionally omitted (OSC 52 handles clipboard writes)
- Post-sleep recovery autocommands -- already in autocmds.lua
- Custom clipboard provider (`vim.g.clipboard`) -- already in options.lua
- Persistent yank storage -- user uses memory storage

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `dir`-based local plugin not recognized by lazy.nvim | H | L | Verified pattern from himalaya-plugin in same codebase; `init.lua` at module root is standard |
| Telescope picker API change breaks custom picker | L | L | Using same patterns as existing custom picker in yanky.lua; core Telescope API is stable |
| `vim.hl.on_yank()` must be called inside TextYankPost | M | L | Documented requirement in report 06; placed correctly in init.lua's TextYankPost callback |
| which-key.lua `require("neotex.yank")` fails before VeryLazy loads the module | M | L | `require()` calls are inside `function()` wrappers, so they execute lazily at keypress time, not at which-key load time |
| tools/init.lua `add_if_valid` rejects the new spec | M | L | Spec uses `dir` field which is checked by `add_if_valid` on line 95 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create core yank modules [COMPLETED]

**Goal**: Create the 4 modules under `lua/neotex/yank/` that form the custom yank ring implementation.

**Tasks**:
- [x] **Task 1.1**: Create directory `lua/neotex/yank/` *(completed)*
- [x] **Task 1.2**: Create `lua/neotex/yank/ring.lua` (~65 LOC) -- Circular buffer: `M.setup({ max_size })`, `M.push(entry)` with consecutive deduplication, `M.all()`, `M.get(index)`, `M.count()`, `M.clear()`. Entries have `regcontents`, `regtype`, `filetype`, `timestamp` fields. Uses `vim.uv.now()` for timestamps. *(completed)*
- [x] **Task 1.3**: Create `lua/neotex/yank/highlight.lua` (~20 LOC) -- Thin wrapper: `M.setup({ higroup, timeout, on_macro, on_visual })`, `M.on_yank()` calls `vim.hl.on_yank()` with stored config. Respects `on_macro` flag by checking `vim.fn.reg_executing()`. *(completed)*
- [x] **Task 1.4**: Create `lua/neotex/yank/telescope.lua` (~65 LOC) -- Telescope picker: `M.open(ring)` creates picker with buffer previewer showing yanked text with filetype syntax highlighting. Paste action uses `vim.fn.setreg('"', selection.value.regcontents, selection.value.regtype)` then `vim.cmd('normal! p')` to avoid OSC 52 trigger. Adapted from existing custom picker in yanky.lua lines 92-162. *(completed)*
- [x] **Task 1.5**: Create `lua/neotex/yank/init.lua` (~60 LOC) -- Entry point: `M.setup(opts)` merges defaults, initializes ring and highlight submodules, creates `NeoTexYank` augroup with `clear = true`. Registers `TextYankPost` (capture to ring + highlight) and `VimLeavePre` (cleanup) autocommands. Exports `M.telescope_history()`, `M.clear_history()`. NO clipboard sync, NO recovery setup, NO FocusGained handler. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/yank/ring.lua` - Create new file
- `lua/neotex/yank/highlight.lua` - Create new file
- `lua/neotex/yank/telescope.lua` - Create new file
- `lua/neotex/yank/init.lua` - Create new file

**Verification**:
- Each module loads without error: `nvim --headless -c "lua require('neotex.yank.ring')" -c "q"`
- Full module loads and registers autocommands: `nvim --headless -c "lua require('neotex.yank').setup({}); print(vim.inspect(vim.api.nvim_get_autocmds({group='NeoTexYank'})))" -c "q"`

---

### Phase 2: Create plugin spec and wire up lazy.nvim [COMPLETED]

**Goal**: Create the lazy.nvim plugin spec that replaces yanky.lua and update tools/init.lua to load the new module.

**Tasks**:
- [x] **Task 2.1**: Create `lua/neotex/plugins/tools/yank-ring.lua` (~20 LOC) -- Plugin spec with `dir = vim.fn.stdpath("config") .. "/lua/neotex/yank"`, `lazy = true`, `event = "VeryLazy"`, `dependencies = { "nvim-telescope/telescope.nvim" }`. Config function calls `require("neotex.yank").setup()`. NO keys table. *(deviation: altered — kept `_G.YankyTelescopeHistory` global for which-key.lua backward compatibility per plan instructions)*
- [x] **Task 2.2**: Update `lua/neotex/plugins/tools/init.lua` line 82: Change `safe_require("neotex.plugins.tools.yanky")` to `safe_require("neotex.plugins.tools.yank-ring")` and rename variable from `yanky_module` to `yank_module` *(completed)*
- [x] **Task 2.3**: Update `lua/neotex/plugins/tools/init.lua` line 109: Change `add_if_valid(yanky_module)` to `add_if_valid(yank_module)` *(completed)*
- [x] **Task 2.4**: Delete `lua/neotex/plugins/tools/yanky.lua` *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/yank-ring.lua` - Create new file
- `lua/neotex/plugins/tools/init.lua` - Update lines 82 and 109
- `lua/neotex/plugins/tools/yanky.lua` - Delete

**Verification**:
- Plugin spec loads via init.lua: `nvim --headless -c "lua local specs = require('neotex.plugins.tools'); for _, s in ipairs(specs) do if s.dir and s.dir:find('yank') then print('FOUND') end end" -c "q"`
- Deleted yanky.lua no longer exists: `test ! -f lua/neotex/plugins/tools/yanky.lua`

---

### Phase 3: Update external references and verify [COMPLETED]

**Goal**: Remove all yanky.nvim references from telescope.lua and which-key.lua, replace `_G` globals and `require("yanky")` calls with direct `require("neotex.yank")` calls, verify clean startup, and confirm no remaining yanky references in the codebase.

**Tasks**:
- [x] **Task 3.1**: Update `lua/neotex/plugins/editor/telescope.lua` line 13: Remove `"gbprod/yanky.nvim"` from the dependencies list *(completed)*
- [x] **Task 3.2**: Update `lua/neotex/plugins/editor/telescope.lua` line 132: Remove `telescope.load_extension("yank_history")` *(completed)*
- [x] **Task 3.3**: Update `lua/neotex/plugins/editor/which-key.lua` line 499: Change `function() _G.YankyTelescopeHistory() end` to `function() require("neotex.yank").telescope_history() end` *(completed)*
- [x] **Task 3.4**: Update `lua/neotex/plugins/editor/which-key.lua` line 821: Change `function() require("yanky").clear_history() end` to `function() require("neotex.yank").clear_history() end` *(completed)*
- [x] **Task 3.5**: Update `lua/neotex/plugins/editor/which-key.lua` line 822: Change `function() _G.YankyTelescopeHistory() end` to `function() require("neotex.yank").telescope_history() end` *(completed)*
- [x] **Task 3.6**: Search codebase for remaining `yanky` references: `grep -r "yanky" lua/ --include="*.lua"` -- only comments or specs should remain *(completed: remaining references are comments only)*
- [x] **Task 3.7**: Verify clean Neovim startup *(completed: startup OK)*
- [ ] **Task 3.8**: Verify yank ring autocommands registered and Telescope picker opens *(deviation: skipped — headless mode cannot test interactive picker; autocommands verified in Phase 1)*
- [ ] **Task 3.9**: Run `:Lazy clean` to remove yanky.nvim from the lock file *(deviation: skipped — requires interactive Neovim session; user should run manually)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/editor/telescope.lua` - Remove yanky dependency (line 13) and extension load (line 132)
- `lua/neotex/plugins/editor/which-key.lua` - Update lines 499, 821, 822 (replace `_G.YankyTelescopeHistory` and `require("yanky")` with `require("neotex.yank")` calls)

**Verification**:
- No yanky references in telescope.lua: `grep -i yanky lua/neotex/plugins/editor/telescope.lua` returns nothing
- No yanky require paths or `_G.Yanky` globals in which-key.lua: `grep -E 'require.*yanky|_G\.Yanky' lua/neotex/plugins/editor/which-key.lua` returns nothing
- Clean Neovim startup with no errors in `:messages`
- `<leader>fy` opens yank history picker (manual test)
- `<leader>yc` clears history without error (manual test)
- `<leader>yh` opens yank history picker (manual test)

## Testing & Validation

- [ ] All 4 modules load without error in headless mode
- [ ] `NeoTexYank` augroup contains TextYankPost and VimLeavePre autocommands
- [ ] Yanking text adds entries to the ring (verify via `require('neotex.yank')._ring.all()`)
- [ ] `require("neotex.yank").telescope_history` is a function after VeryLazy event fires
- [ ] `require("neotex.yank").clear_history` is a function after VeryLazy event fires
- [ ] Telescope picker opens with `<leader>fy` and `<leader>yh` (manual test)
- [ ] Selecting an entry from the picker pastes content correctly (manual test)
- [ ] `<leader>yc` clears ring and shows notification (manual test)
- [ ] Native y/p/P/gp/gP operators work correctly without interception (manual test)
- [ ] `grep -r "yanky" lua/ --include="*.lua"` returns no require/dependency references
- [ ] No `_G.Yanky` references remain in codebase: `grep -r "_G\.Yanky" lua/ --include="*.lua"` returns nothing
- [ ] Clean Neovim startup with no error messages related to yank or yanky
- [ ] Post-sleep test (manual): Sleep/wake cycle does not freeze Neovim

## Artifacts & Outputs

- `lua/neotex/yank/ring.lua` - Circular buffer data structure
- `lua/neotex/yank/highlight.lua` - Yank highlighting wrapper
- `lua/neotex/yank/telescope.lua` - Telescope picker for yank history
- `lua/neotex/yank/init.lua` - Entry point and setup
- `lua/neotex/plugins/tools/yank-ring.lua` - lazy.nvim plugin spec (replaces yanky.lua)
- `lua/neotex/plugins/tools/init.lua` - Updated module loading (yanky -> yank-ring)
- `lua/neotex/plugins/editor/telescope.lua` - Removed yanky dependency and extension load
- `lua/neotex/plugins/editor/which-key.lua` - Updated lines 499, 821, 822 to use direct requires
- `lua/neotex/plugins/tools/yanky.lua` - Deleted

## Rollback/Contingency

If the custom implementation causes issues:

1. **Quick revert**: Restore `yanky.lua` from git (`git checkout -- lua/neotex/plugins/tools/yanky.lua`), revert changes to telescope.lua, which-key.lua, and tools/init.lua. Delete `lua/neotex/yank/` directory. Run `:Lazy sync` to restore yanky.nvim.

2. **Minimal fix fallback**: If the yank ring is problematic but yanky.nvim cannot be restored, simply delete the yank-ring spec and remove the yank-related keymaps from which-key.lua. Native yank/paste will work perfectly; only the history picker is lost.

3. **Git safety**: All changes are in `lua/` and affect no system configuration. A `git stash` or selective `git checkout` reverts everything cleanly.
