# Research Report: Task #830

**Task**: 830 - aerc terminal C-hjkl/Esc passthrough
**Started**: 2026-07-08
**Completed**: 2026-07-08
**Effort**: Small (single-function edit, ~10-15 line diff)
**Dependencies**: None (this task is itself a hard prerequisite for .dotfiles task 105 Recommendation B)
**Sources/Inputs**: Local config (keymaps.lua, autocmds.lua, mail.lua), toggleterm.nvim source (installed at `~/.local/share/nvim/lazy/toggleterm.nvim`), cross-repo report `~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, `.claude/rules/neovim-lua.md`

## Executive Summary
- `set_terminal_keymaps()` (`lua/neotex/config/keymaps.lua:116-158`) detects `is_claude` via `nvim_buf_get_name(0)` substring match (`bufname:match("claude")`/`"ClaudeCode"`) and `is_opencode` via `vim.b.snacks_terminal.cmd`/`.args` substring match — two different idioms because Claude Code and OpenCode are launched through different terminal backends (a bufname-bearing terminal vs. a `snacks.nvim` terminal that stashes its launch command in a buffer-local table).
- aerc is launched via **toggleterm.nvim** (`Terminal:new({cmd = "aerc", ...})` in `lua/neotex/plugins/tools/mail.lua:33-52`), which is neither of those two backends, but toggleterm's own `Terminal:__spawn()` (in the installed plugin source) builds the shell command as `"aerc" .. ";" .. "#toggleterm#" .. id` and passes that full string to `termopen()`. Neovim's `:terminal` buffer-naming convention (`term://{cwd}//{pid}:{cmd}`) then produces a bufname like `term://~/.config/nvim//12345:aerc;#toggleterm#7`, in which the literal substring `"aerc"` appears immediately after the pid colon. **This means the `is_claude`-style bufname-match idiom (not the `is_opencode`-style `vim.b.snacks_terminal` idiom) is the correct pattern to mirror for `is_aerc`.**
- The two things to gate are precisely: (1) the `<Esc>` remaps at `keymaps.lua:132-136` (currently gated `if not is_claude`, needs `not is_claude and not is_aerc`), and (2) the `<C-h/j/k/l>` → `wincmd` remaps in the `else` branch at `keymaps.lua:146-151` (currently the generic fallback for anything that isn't `is_opencode`; needs an added `elseif is_aerc then` branch — or an added condition — that skips the wincmd binds entirely, or binds nothing, for aerc terminals).
- No regression risk to Claude Code or OpenCode or generic terminals: the change is additive (`is_aerc` is a brand-new boolean, `false` for every existing terminal type) and strictly gated, so `is_claude`/`is_opencode`/generic branches are untouched in the “not aerc” case.

## Context & Scope

Researched exactly what task 830 asked for: (1) how `is_claude`/`is_opencode` detection works and what idiom `is_aerc` should follow; (2) the precise line ranges of the `<Esc>` map and the `<C-hjkl>`→`wincmd` maps that must be gated; (3) confirmation of what bufname/cmd string the aerc toggleterm launcher actually produces, so the `is_aerc` match pattern is grounded in fact rather than assumption. No code was changed — this is research only, per task_type=neovim research dispatch.

## Findings

### Existing Configuration

**`set_terminal_keymaps()`** — `lua/neotex/config/keymaps.lua`, defined at line 116, called globally as `_G.set_terminal_keymaps` from the `TermOpen` autocmd (`lua/neotex/config/autocmds.lua:25-28`, pattern `term://*`, so it fires for every terminal buffer including toggleterm's aerc float).

Exact current body (lines 116-158):

```lua
116: function _G.set_terminal_keymaps()
117:   -- Lock terminal window to prevent buffer switching
118:   vim.wo.winfixbuf = true
119:
120:   -- Check terminal type for specialized keybindings
121:   local bufname = vim.api.nvim_buf_get_name(0)
122:   local is_claude = bufname:match("claude") or bufname:match("ClaudeCode")
123:   local is_opencode = false
124:   if vim.b.snacks_terminal then
125:     local cmd = vim.b.snacks_terminal.cmd or vim.b.snacks_terminal.args or {}
126:     local cmd_str = type(cmd) == "table" and table.concat(cmd, " ") or tostring(cmd)
127:     is_opencode = cmd_str:match("opencode%s+%-%-port")
128:   end
129:
130:   -- Terminal navigation
131:   -- Skip escape mapping for Claude Code to allow its internal normal mode
132:   if not is_claude then
133:     buf_map(0, "t", "<Esc>", "<C-\\><C-n>", "Exit terminal mode")
134:     -- In normal mode, Esc sends escape to the terminal app (for closing menus)
135:     buf_map(0, "n", "<Esc>", "i<Esc><C-\\><C-n>", "Send Esc to terminal app")
136:   end
137:
138:   -- OpenCode terminals: Ctrl+j/k send arrow keys for menu navigation
139:   -- Other terminals: Ctrl+hjkl for window navigation
140:   if is_opencode then
141:     buf_map(0, "t", "<C-j>", "<Down>", "Menu down")
142:     buf_map(0, "t", "<C-k>", "<Up>", "Menu up")
143:     buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
144:     buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
145:     buf_map(0, "t", "<C-g>", "<cmd>lua require('opencode').toggle()<CR>", "Toggle Opencode")
146:   else
147:     buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
148:     buf_map(0, "t", "<C-j>", "<Cmd>wincmd j<CR>", "Navigate down")
149:     buf_map(0, "t", "<C-k>", "<Cmd>wincmd k<CR>", "Navigate up")
150:     buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
151:   end
152:
153:   -- Terminal resizing
154:   buf_map(0, "t", "<M-Right>", "<Cmd>vertical resize -2<CR>", "Resize right")
155:   buf_map(0, "t", "<M-Left>", "<Cmd>vertical resize +2<CR>", "Resize left")
156:   buf_map(0, "t", "<M-l>", "<Cmd>vertical resize -2<CR>", "Resize right")
157:   buf_map(0, "t", "<M-h>", "<Cmd>vertical resize +2<CR>", "Resize left")
158: end
```

**Detection idiom mapping**:

| Terminal type | Backend | Detection mechanism | Line(s) |
|---|---|---|---|
| Claude Code | (bufname-bearing terminal, not snacks/toggleterm-tagged) | `nvim_buf_get_name(0)` substring match (`"claude"` / `"ClaudeCode"`) | 121-122 |
| OpenCode | `snacks.nvim` terminal | `vim.b.snacks_terminal.cmd`/`.args` substring match against `"opencode%s+%-%-port"` | 123-128 |
| aerc (new) | `toggleterm.nvim` terminal | **bufname substring match** (same idiom as Claude Code — confirmed below) | to be added |
| generic (fallback) | anything else | none — falls to `else` branches | 146-151, 132-136 (via `not is_claude`) |

**Exact gating points that must change**:
1. **`<Esc>` guard, line 132**: `if not is_claude then` → must become `if not is_claude and not is_aerc then` to also exempt aerc terminals from the `<Esc>` → exit-terminal-mode remap (lines 133-135) and the normal-mode Esc-passthrough remap (line 135). Nothing else in this block changes.
2. **`<C-h/j/k/l>` → `wincmd` maps, lines 146-151 (the `else` branch of the `is_opencode` conditional)**: this is the branch aerc currently falls into (since `is_opencode` is `false` for aerc). It must be restructured to add an `is_aerc` case that either binds nothing for `<C-hjkl>` (skip entirely, letting the keys reach the terminal app unmapped) or is placed as a third branch/early-return so the generic `wincmd` binds at 147-150 are skipped specifically for aerc. The cleanest minimal-diff shape, consistent with the existing `if is_opencode ... else ... end` structure, is a 3-way `if is_opencode then ... elseif is_aerc then -- (no binds, or aerc-specific binds) else ... end`.

No other lines in `set_terminal_keymaps()` need touching — the `<M-*>` resize binds (153-157) and `winfixbuf` (118) are unaffected and unconditional.

### Plugin Documentation (toggleterm.nvim internals)

`lua/neotex/plugins/tools/mail.lua:26-56` defines the aerc launcher as a `toggleterm.nvim` `keys` spec bound to `<leader>me`:

```lua
local Terminal = require("toggleterm.terminal").Terminal
local aerc = Terminal:new({
  cmd = "aerc",
  direction = "float",
  float_opts = { border = "curved", width = ..., height = ... },
  on_open = function(term) ... end,
})
aerc:toggle()
```

Installed toggleterm source (`~/.local/share/nvim/lazy/toggleterm.nvim/lua/toggleterm/terminal.lua`), `Terminal:__spawn()` (lines 389-415):

```lua
390: function Terminal:__spawn()
391:   local cmd = self.cmd or config.get("shell")
...
393:   local command_sep = get_command_sep()   -- ";" on non-Windows
394:   local comment_sep = get_comment_sep()    -- "#" on non-Windows
395:   cmd = table.concat({
396:     cmd,                    -- "aerc"
397:     command_sep,            -- ";"
398:     comment_sep,            -- "#"
399:     constants.FILETYPE,     -- "toggleterm"
400:     comment_sep,            -- "#"
401:     self.id,                -- e.g. 7
402:   })
403:   local dir = _get_dir(self.dir)
404:   self.job_id = fn.termopen(cmd, { ... })
...
413:   self.name = cmd
```

So the string actually passed to `fn.termopen()` for the aerc terminal is `"aerc;#toggleterm#<id>"` (e.g. `"aerc;#toggleterm#7"`). A code comment in the same file (line 520) confirms Neovim's resulting buffer-naming convention: `term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1` — i.e. `term://{cwd}//{pid}:{full-cmd-string}`. Substituting aerc's cmd string gives a bufname of the shape:

```
term://<cwd>//<pid>:aerc;#toggleterm#<id>
```

The literal substring `"aerc"` appears right after the pid colon, so **`bufname:match("aerc")`** (mirroring `is_claude`'s `bufname:match("claude")`) reliably matches the aerc terminal and does not require the `snacks_terminal`-style buffer-variable idiom (that idiom exists specifically because `snacks.nvim` terminals don't put the command into the buffer name the way `termopen`/toggleterm do — aerc's toggleterm terminal is not affected by that limitation).

Confirmed via `grep` for `vim.b[` assignments in toggleterm.nvim: the only buffer-local variable toggleterm sets is `vim.b[self.bufnr].toggle_number = self.id` (`terminal.lua:451`) — an opaque terminal ID, not a cmd string — so a `vim.b`-based match (the `is_opencode` idiom) is not viable for aerc without an extra `terminal.get(id)` lookup. The bufname-match idiom is simpler and directly parallel to `is_claude`.

**No collision risk**: grepping the existing codebase and standard terminal launch sites (Claude Code via `claudecode.lua`, OpenCode via `snacks`, generic `:terminal`/toggleterm shells) turns up no other terminal whose cmd or bufname would contain the substring `"aerc"`.

### Community Patterns

Not applicable — this is a self-contained, local-idiom-mirroring change with no external plugin API surface; no web research was needed beyond confirming toggleterm's internal bufname-construction behavior, which was done by reading the installed plugin source directly (higher-fidelity than web docs for this specific internal behavior).

### Recommendations

1. **Detection** (insert after line 128, before the "Terminal navigation" comment at line 130):
   ```lua
   local is_aerc = bufname:match("aerc") ~= nil
   ```
   This mirrors the `is_claude` idiom exactly (same `bufname` variable already computed at line 121, no new buffer-local lookups needed).

2. **`<Esc>` gate** (line 132): change `if not is_claude then` to `if not is_claude and not is_aerc then`. This is the minimal edit satisfying the task's explicit instruction to "extend the existing `if not is_claude` guard to also exempt aerc."

3. **`<C-hjkl>` gate** (lines 140-151): restructure the `if is_opencode then ... else ... end` to a 3-way branch, e.g.:
   ```lua
   if is_opencode then
     buf_map(0, "t", "<C-j>", "<Down>", "Menu down")
     buf_map(0, "t", "<C-k>", "<Up>", "Menu up")
     buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
     buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
     buf_map(0, "t", "<C-g>", "<cmd>lua require('opencode').toggle()<CR>", "Toggle Opencode")
   elseif is_aerc then
     -- Skip wincmd remaps: aerc float has no sibling windows, and aerc.nix
     -- (dotfiles task 105 Recommendation B) will bind C-hjkl for folder/message nav.
   else
     buf_map(0, "t", "<C-h>", "<Cmd>wincmd h<CR>", "Navigate left")
     buf_map(0, "t", "<C-j>", "<Cmd>wincmd j<CR>", "Navigate down")
     buf_map(0, "t", "<C-k>", "<Cmd>wincmd k<CR>", "Navigate up")
     buf_map(0, "t", "<C-l>", "<Cmd>wincmd l<CR>", "Navigate right")
   end
   ```
   The `is_aerc` branch is intentionally empty (no `buf_map` calls) so `<C-h/j/k/l>` are left entirely unmapped in terminal mode for aerc buffers, allowing them to pass through to the aerc process unmodified — this is precisely what "skip the remap" means operationally in Neovim's terminal mode (an unmapped `<C-x>` in terminal-mode is sent to the pty as-is).

4. **No lazy-loading concern**: this is a buffer-local keymap function invoked synchronously on every `TermOpen`, not a plugin spec — no `event`/`cmd`/`ft`/`keys` trigger design applies here.

5. **Ordering safety**: `is_aerc` must be computed from `bufname`, which is already fetched at line 121 before any of the conditional branches — no reordering of existing lines is required, only insertion.

## Decisions
- Use `bufname:match("aerc")` — the `is_claude` idiom — not a `vim.b.snacks_terminal`-style idiom, because aerc's toggleterm backend does not stash cmd in a buffer variable the way `snacks.nvim` does, and the bufname reliably contains `"aerc"` per the traced toggleterm `__spawn()` cmd-string construction.
- Gate `<C-hjkl>` via an explicit `elseif is_aerc then` (empty) branch rather than an `if is_aerc then return end` early-exit, to keep the diff minimal and keep the trailing `<M-*>` resize binds (lines 153-157) executing unconditionally for aerc terminals too (consistent with "only C-hjkl and Esc are special-cased," per task description — resize binds are not in scope for aerc special-casing and should NOT be silently dropped by an early return).
- Gate `<Esc>` via extending the existing `if not is_claude then` to `if not is_claude and not is_aerc then`, exactly as specified in the task description, rather than introducing a separate conditional block.

## Risks & Mitigations
- **Risk**: A future terminal cmd/bufname accidentally contains the substring `"aerc"` (e.g. a directory path with "aerc" in it, given `term://{cwd}//...`). **Mitigation**: Not currently a concern (no such path/tool exists in this config), and the existing `is_claude` idiom carries the identical theoretical risk already accepted by the codebase (`bufname:match("claude")` would also false-positive on a cwd containing "claude"). Consistent with existing risk tolerance; no new pattern introduced.
- **Risk**: Regression to Claude Code / OpenCode / generic terminal `<C-hjkl>`/`<Esc>` behavior. **Mitigation**: `is_aerc` is a new, independent boolean computed additively; the `is_claude`/`is_opencode`/generic branches keep their exact current conditions (`not is_claude and not is_aerc` is a strict narrowing — `is_claude` terminals are still exempted the `<Esc>` way they already are; `is_opencode` terminals hit the same first `if` branch unchanged; generic terminals still hit the trailing `else` unchanged since `is_aerc` is `false` for them).
- **Risk**: `<M-h>`/`<M-l>` resize binds (lines 156-157) collide with any future aerc-side `<M-*>` binds. **Out of scope** for this task (task description explicitly scopes to `<C-hjkl>` and `<Esc>` only); noted here only for completeness, no action needed.

## Context Extension Recommendations
none

## Appendix

### Search queries / commands used
- `grep -n "term://"` / `grep -n "cmd\b"` / `grep -n "vim.b\["` in installed `toggleterm.nvim/lua/toggleterm/terminal.lua`
- `find / -iname "toggleterm.nvim" -type d` to locate installed plugin source
- `grep -rln "ClaudeCode|claude-code|claudecode"` across `lua/neotex/plugins/` to confirm no separate bufname-construction path for Claude Code that would suggest a different idiom
- Read of `~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md` §4 (reachability table) and §6.2 (Recommendation B) for cross-repo rationale and the exact task origin text

### References
- `lua/neotex/config/keymaps.lua:116-158` — `set_terminal_keymaps()`
- `lua/neotex/config/autocmds.lua:25-28` — `TermOpen` autocmd, `pattern = "term://*"`
- `lua/neotex/plugins/tools/mail.lua:26-56` — aerc toggleterm launcher (`<leader>me`)
- `~/.local/share/nvim/lazy/toggleterm.nvim/lua/toggleterm/terminal.lua:389-415` — `Terminal:__spawn()` cmd-string construction; line 451 — the only `vim.b[]` assignment (`toggle_number`); line 520 — bufname-format code comment
- `~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md` §4, §4.1, §4.2, §6.2 — cross-repo companion research and Recommendation B origin text
