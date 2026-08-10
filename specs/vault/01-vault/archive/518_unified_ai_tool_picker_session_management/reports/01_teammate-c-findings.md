# Critic Analysis: Task 518 - Unified AI Tool Picker

**Teammate**: C (Critic)
**Task**: 518 - Unified AI Tool Picker / Session Management
**Date**: 2026-05-03
**Focus**: Gap identification, unvalidated assumptions, edge cases, and missing scope

---

## Executive Summary

The proposed unified picker approach has several unvalidated assumptions and genuine implementation
hazards. The most critical are: (1) the `is_opencode` filetype detection is already broken in the
existing codebase, making the "skip picker if visible" logic for OpenCode unimplementable without
a fix; (2) the JSON persistence file has proven brittle in practice (9,612 backup files currently
on disk); (3) the two-tool picker has a `<leader>as` key collision that the task should resolve as
part of scope; and (4) the documentation sources list `<C-c>` as the Claude Code toggle but the
actual binding is `<C-CR>` - an existing inconsistency that scoping discussions may be based on.

---

## Key Findings

### Finding 1: OpenCode Terminal Filetype Detection Is Broken

**Evidence**: The existing code in `lua/neotex/config/keymaps.lua` (line 121) uses:
```lua
local is_opencode = vim.bo.filetype == "opencode_terminal"
```
But the actual `opencode.lua` plugin configuration overrides the server to use `snacks.terminal`,
which sets filetype `"snacks_terminal"` (not `"opencode_terminal"`). The `opencode.nvim` plugin
itself sets only `"opencode_ask"` filetype for the ask input, never `"opencode_terminal"`.

**Impact**: The `set_terminal_keymaps()` branch for `is_opencode` (lines 133-138 of keymaps.lua)
is dead code - it never executes. The `<C-g>` buffer-local map inside OpenCode terminals is never
being set. This means the "skip picker if OpenCode is visible" heuristic must detect OpenCode via
a different mechanism (e.g., querying `snacks.terminal.get("opencode --port", opts):win_valid()`),
not filetype.

**Implication for task**: Any "detect active terminal" logic must use snacks API or buffer-name
matching, not the `opencode_terminal` filetype. The correct approach:
```lua
local snacks_term = require("snacks.terminal").get("opencode --port", opencode_win_opts)
local opencode_visible = snacks_term and snacks_term:win_valid()
```
But this requires knowing the exact `opencode_win_opts` used during creation, because snacks uses
`vim.inspect({cmd, cwd, env, count})` as the terminal ID (snacks/terminal.lua line 176-184). If
cwd changes between invocations, the terminal ID changes and `get()` returns nil.

---

### Finding 2: The "Both Terminals Visible Simultaneously" Scenario Is Undefined

**Gap**: The task spec says "If an active terminal is visible, skip the picker and toggle directly."
It does not specify what happens when BOTH Claude Code AND OpenCode are simultaneously visible.
This is a realistic scenario: a developer with a wide monitor might have both open side by side.

**Possible behaviors** (none specified):
1. Toggle the last-used tool (requires tracking which was used more recently)
2. Toggle Claude Code (because it's tied to `<C-CR>` historically)
3. Show the tool picker anyway (defeats the "skip" optimization)
4. Close both

**Current code gap**: `session-manager.lua:detect_claude_buffers()` only detects Claude. There is
no equivalent `detect_opencode_buffers()` function anywhere in the codebase. The task as specified
must either define the concurrent behavior or restrict the "skip" logic to a specific case.

**Recommendation**: The spec needs an explicit decision: when both are visible, does `<C-CR>` act
on the last-selected tool from the persistence file, or show the picker?

---

### Finding 3: JSON Persistence Is Already Demonstrably Problematic

**Evidence**: The current session state at `~/.local/share/nvim/claude/` contains **9,612 files**,
almost entirely backup files named `last_session.json.backup.<timestamp>`. This is caused by the
`validate_state_file()` function in `session-manager.lua` (line 293-298), which renames the state
file to a backup whenever validation fails.

The 5-second timer in `session-manager.lua:setup()` (line 467-470) calls
`sync_state_with_processes()` repeatedly, which calls `validate_state_file()`, which creates
backups on every validation failure. This is a live proliferation problem.

**Impact on proposed task**: If the "last selected tool" persistence uses the same `stdpath("data")`
pattern with the same backup-on-failure approach, it will suffer the same proliferation. The task
should either: (a) use `vim.g` for in-memory persistence only (no cross-restart memory), or (b)
use a cleaner write-with-atomic-rename pattern without backup proliferation.

**Note**: There is no cleanup mechanism for the backup files. The 9,612 files represent months of
accumulation. Any new persistence added by this task should avoid this pattern entirely.

---

### Finding 4: Documentation Has a Pre-Existing Key Inconsistency

**Evidence**: Multiple documentation sources list `<C-c>` as the Claude Code toggle:
- `docs/MAPPINGS.md` line 123: `| <C-c> | All | Toggle Claude Code sidebar |`
- `docs/AI_TOOLING.md` line 38: `<C-c>` (toggle)
- `lua/neotex/config/keymaps.lua` header comment line 23: `<C-c> | Toggle Claude Code`
- `lua/neotex/config/keymaps.lua` header comment line 78: `<C-c> | Toggle Claude Code`

**But the actual binding** is `<C-CR>` (lines 265-279 of keymaps.lua). The `<C-c>` binding only
appears as `actions.close` inside Telescope pickers (telescope.lua line 27).

**Impact on task 518**: The task description says to "replace the current separate `<C-CR>` (Claude
Code) and `<C-g>` (OpenCode) keybindings." This is accurate for the code. However, any plan
based on the documentation (which says `<C-c>`) is starting from wrong assumptions. The scope
must include correcting the documentation as part of the task.

---

### Finding 5: `<leader>as` Key Collision Already Exists

**Evidence**: In `which-key.lua` lines 257 and 263:
```lua
{ "<leader>as", function() require("neotex.plugins.ai.claude").resume_session() end, desc = "claude sessions" },
{ "<leader>as", function() require("opencode").select() end, desc = "opencode select" },
```
Both Claude Code and OpenCode are mapped to `<leader>as`. Which-key last-writer-wins means OpenCode
(`opencode.select`) wins. The Claude sessions function is silently shadowed. This is an existing
bug that the task's "unified picker" approach could resolve - but it's not mentioned in the spec.

**Recommendation**: The task scope should include resolving this collision, either by removing
`<leader>as` from both and creating a single AI tool select shortcut, or by differentiating them.

---

### Finding 6: Telescope as Tool for a 2-Item Pick Is Architecturally Questionable

**Evidence**: The existing codebase already uses `vim.ui.select` for small picks:
- `lua/neotex/util/buffer.lua:188` - Yes/No confirmation
- `lua/neotex/plugins/tools/worktree.lua:78` - Worktree type selection
- `lua/neotex/plugins/editor/which-key.lua:424` - Model selection

And `lua/neotex/plugins/editor/telescope.lua` overrides `vim.ui.select` with Telescope for the
`"confirmation"` and `"file_deletion"` kinds, but falls back to native for others. There is also
`snacks.picker` already configured (referenced in telescope.lua line 49 as "when using
snacks.picker").

**Gap**: A 2-item picker ("Claude Code" vs "OpenCode") has no functional need for Telescope's full
machinery (fuzzy search, preview, custom finders). `vim.ui.select` would be:
- Faster to open (no Telescope overhead)
- Simpler to implement (10 lines vs ~50)
- Consistent with the project pattern for small selections

**Assumption to validate**: The spec assumes Telescope because Stage 2 (session management) uses
it. But Stage 1 (tool selection) doesn't require Telescope. Using `vim.ui.select` for Stage 1
would be consistent with project patterns and would work with the telescope-ui-select override
already installed.

---

### Finding 7: "Remember Last Selection" Cross-Restart UX Value Is Unvalidated

**Gap**: The spec assumes that persisting the last-used AI tool across restarts saves meaningful
time for a 2-item list. This assumption may not hold:

1. The picker will have exactly 2 items. Navigating to the non-default item requires 1 keypress
   (arrow down) plus Enter. The total cost of "wrong default" is ~2 keystrokes.
2. Many Neovim sessions start from a fresh context where the user doesn't know which tool they
   want until they think about it.
3. In-memory persistence (valid only for current session, using `vim.g`) would cover the "I
   toggled Claude Code 5 minutes ago and now want to toggle it again" case without the file I/O
   and backup proliferation risks.

**Recommendation**: Consider `vim.g.ai_last_tool = "claude"` (in-memory, reset each startup)
instead of JSON file persistence. Cross-restart persistence adds complexity for marginal benefit.

---

### Finding 8: OpenCode Session Management Parity Is Absent

**Evidence**: The spec says "Stage 2 presents a session management picker adapted to the selected
tool." For Claude Code, the session picker exists (`core/session.lua:show_session_picker()`). For
OpenCode, there is no equivalent session picker infrastructure. The closest is:
- `require("opencode").command("session.list")` (mapped to `<leader>ah`) - this is a TUI command
  sent to the running opencode process, not a Neovim picker

**Gap**: If OpenCode is selected in Stage 1, what does Stage 2 look like? There is no
`opencode/core/session.lua` with a `show_session_picker()` equivalent. Implementing Stage 2 for
OpenCode either requires: (a) calling `opencode.command("session.list")` which opens the session
list inside the TUI itself, or (b) building a new Neovim-native OpenCode session picker (significant
additional scope). The task scope must define this explicitly.

---

### Finding 9: Terminal Buffer Exists But Process Has Exited

**Evidence**: `session-manager.lua:detect_claude_buffers()` checks `channel > 0` to verify the
terminal is active (line 204-205). But `channel > 0` means the Neovim channel to the job exists,
not that the job is still running. A Claude process that has exited but whose terminal buffer has
not been wiped will still show `channel > 0` for a brief window until Neovim processes the
`TermClose` event.

**Impact**: The "skip picker and toggle directly" logic could fire for a Claude terminal that is
in the process of closing, leading to incorrect behavior (toggling a dying session instead of
showing the picker for a new one).

**More robust check**: `vim.api.nvim_buf_get_option(bufnr, 'channel')` combined with
`vim.fn.jobwait([channel], 0)` returning -1 (still running) would be more reliable.

---

### Finding 10: Scope Gaps - Which-Key Descriptions and Buffer-Local Terminal Keymaps

**Gap A - Which-key descriptions**: The current which-key config has no entry for `<C-CR>` or
`<C-g>` because they are non-leader keys and which-key only triggers on `<leader>`. However, the
`<leader>a` group description will need updating when `<C-g>` is removed. The comment "OpenCode
toggle: Use `<leader>aoo` via which-key" at keymaps.lua line 285 may become stale.

**Gap B - The `<C-g>` in surround.lua**: The file `lua/neotex/plugins/tools/surround.lua` uses
`<C-g>s` and `<C-g>S` as insert-mode surround keymaps (lines 30-31). These are buffer-local
insert-mode bindings that begin with `<C-g>`. If `<C-g>` is removed as a global n/i mode OpenCode
toggle, these surround bindings should continue to work (since they are `<C-g>s`, not `<C-g>`
alone). But this interaction should be verified.

**Gap C - OpenCode `<C-g>` inside its own terminal**: keymaps.lua line 138 sets a buffer-local
`<C-g>` in terminal mode for OpenCode terminals (which was identified as dead code in Finding 1).
When `<C-g>` global is removed, this dead buffer-local mapping should also be removed.

**Gap D - DOCUMENTATION_STANDARDS.md reference**: `docs/DOCUMENTATION_STANDARDS.md` line 217
documents `<C-c>` as Claude Code toggle. This needs updating when `<C-CR>` is formally documented.

---

## Recommended Approach

Based on findings, the implementation should:

1. **Fix OpenCode detection first**: Use `snacks.terminal.get()` with `{create=false}` to detect
   OpenCode visibility. The filetype approach is broken and cannot be the detection mechanism.

2. **Define concurrent behavior explicitly**: Document and implement the "both visible" case before
   writing any code. The simplest safe choice: if either tool's terminal is visible in the current
   window layout, skip the Stage 1 picker and toggle that tool. If both are visible, fall through
   to the picker.

3. **Use in-memory persistence for last tool**: `vim.g.ai_last_tool = "claude"` avoids the JSON
   backup proliferation problem entirely. Cross-restart persistence is not worth the complexity.

4. **Use `vim.ui.select` for Stage 1** (tool selection), Telescope for Stage 2 (session picker).
   This matches project conventions for small selections and avoids Telescope overhead for a 2-item
   list.

5. **Resolve the `<leader>as` collision as part of this task** rather than leaving it as a silent
   bug.

6. **Define OpenCode Stage 2 behavior explicitly**: Either accept that OpenCode's session list opens
   inside the TUI itself (not a Neovim picker), or scope out a new OpenCode session picker as a
   separate task.

7. **Address documentation inconsistency**: Update `docs/MAPPINGS.md`, `docs/AI_TOOLING.md`,
   `docs/DOCUMENTATION_STANDARDS.md`, and the keymaps.lua header comments to reflect `<C-CR>`
   rather than `<C-c>`.

---

## Evidence Summary

| File | Line(s) | Issue |
|------|---------|-------|
| `lua/neotex/config/keymaps.lua` | 121 | `opencode_terminal` filetype never set by plugin |
| `lua/neotex/config/keymaps.lua` | 133-138 | Dead code branch for OpenCode terminal keymaps |
| `lua/neotex/config/keymaps.lua` | 23, 78 | Header documents `<C-c>` but actual binding is `<C-CR>` |
| `lua/neotex/plugins/editor/which-key.lua` | 257, 263 | `<leader>as` collision between Claude/OpenCode |
| `lua/neotex/plugins/ai/claude/core/session-manager.lua` | 293-298 | Backup-on-failure causes proliferation |
| `~/.local/share/nvim/claude/` | - | 9,612 backup files (live evidence of proliferation) |
| `docs/MAPPINGS.md` | 123 | Documents `<C-c>`, actual binding is `<C-CR>` |
| `docs/AI_TOOLING.md` | 38 | Documents `<C-c>`, actual binding is `<C-CR>` |
| `lua/neotex/plugins/ai/opencode.lua` | 56-58 | snacks.terminal sets filetype `snacks_terminal` |
| `snacks.nvim/lua/snacks/terminal.lua` | 176-184 | Terminal ID includes CWD - changes on dir switch |

---

## Confidence Levels

| Finding | Confidence | Basis |
|---------|-----------|-------|
| OpenCode filetype detection broken | High | Verified against snacks.nvim source |
| Both-visible scenario undefined | High | No handling found anywhere in codebase |
| JSON backup proliferation | High | 9,612 files observed on disk |
| Documentation inconsistency `<C-c>` vs `<C-CR>` | High | Direct code comparison |
| `<leader>as` collision | High | Both entries directly observed in which-key.lua |
| Telescope vs vim.ui.select question | Medium | Functional concern, not a bug |
| Cross-restart persistence value | Medium | UX judgment call, reasonable to question |
| OpenCode Session picker parity gap | High | No opencode session picker module exists |
| Dead process terminal detection | Medium | Race window is narrow but real |
| Scope gaps (which-key, surround, docs) | High | Direct file inspection |
