# Research Report: Task 518 - Teammate D (Horizons)

**Task**: 518 - Unified AI Tool Picker / Session Management
**Role**: Teammate D - Long-term alignment and strategic direction
**Completed**: 2026-05-03
**Confidence**: High on architecture analysis; Medium on UX alternatives

---

## Executive Summary

- The current architecture is well-positioned for N-tool scalability but has two design debts
  that should be addressed now before a third tool makes them expensive to fix
- The `shared/picker/config.lua` abstraction is sound but is used asymmetrically: OpenCode reuses
  Claude's `picker.init` directly while the shared layer only holds config; making `picker.init`
  itself shared (not Claude-owned) would complete the abstraction
- For 2-3 tool selection, a floating menu (snacks-based or `vim.ui.select`) is strongly preferable
  to a Telescope picker - it is instant, requires no fuzzy-search overhead, and matches the
  interaction pattern better
- Frequency-based tool ordering (beyond last-selected) would be low-cost and meaningful; context-
  aware selection (by filetype or directory) is feasible but should be opt-in
- The unified picker concept is a natural fit for a broader "AI hub" keymap group, but should not
  expand scope beyond session/tool selection in this task

---

## Key Findings

### 1. Scalability of the Two-Tool Architecture

**Current state**: Two tools (Claude Code via `greggh/claude-code.nvim`, OpenCode via
`NickvanDyke/opencode.nvim`) each have their own `commands.picker` facade that delegates to either
the shared `picker.init` (OpenCode explicitly reuses Claude's impl) or Claude's own impl directly.
The `shared/picker/config.lua` parameterizes the differences (base_dir, label, commands_subdir, etc.).

**Gap identified**: The picker implementation (`claude/commands/picker/init.lua`) lives under the
Claude module, not under `shared/`. OpenCode's facade imports it via:
```lua
local internal = require("neotex.plugins.ai.claude.commands.picker.init")
```
This is a cross-module dependency from `opencode` into `claude`. When a third tool (Aider, Cursor,
Copilot Chat) is added, it would also need to import from `claude`, making Claude the implicit
infrastructure owner. The clean fix is to move `picker/init.lua` and its subdirectories into
`shared/picker/` so the dependency direction is correct.

**Scalability verdict**: With the move above, the architecture scales to N tools with zero changes
to existing tool modules. Each new tool provides a `shared_config.create({...})` preset and a
one-line facade. This is excellent design.

**ai/init.lua observation**: The top-level `ai/init.lua` hardcodes four tool names:
```lua
local ai_plugins = { "claudecode", "lectic", "mcp-hub", "opencode" }
```
This is fine and intentional (not a registry pattern) - a fifth tool just adds one entry.

### 2. Is shared/picker/ the Right Architectural Home?

Yes, with one correction. The current layout:
```
shared/
  picker/
    config.lua        -- parameterized config presets (correct location)
    config_spec.lua   -- tests
```
Should become:
```
shared/
  picker/
    config.lua        -- parameterized config presets
    config_spec.lua   -- tests
    init.lua          -- moved from claude/commands/picker/init.lua
    display/          -- moved from claude/commands/picker/display/
    operations/       -- moved from claude/commands/picker/operations/
    utils/            -- moved from claude/commands/picker/utils/
```
The `claude/commands/picker.lua` and `opencode/commands/picker.lua` facades would then both
import from `neotex.plugins.ai.shared.picker.init`, and the cross-module dependency is eliminated.

This move is a refactor task, not a blocker for task 518, but noting it here because the unified
picker task is the natural trigger for making this correction.

### 3. Floating Menu vs. Telescope Picker for Tool Selection

**The two-stage concept** (Stage 1: pick tool, Stage 2: use tool's existing picker) is correct.
The question is what UI to use for Stage 1.

**Telescope picker for Stage 1 is wrong** for 2-3 items because:
- It loads the full Telescope machinery for a binary/ternary choice
- The user must type or navigate before selecting - unnecessary friction
- It signals "search within many" when the real action is "choose between few"

**Better options for Stage 1**:

Option A - `vim.ui.select` (recommended for simplicity):
```lua
vim.ui.select({"Claude Code", "OpenCode"}, {
  prompt = "AI Tool:",
  format_item = function(item) return item end,
}, function(choice)
  if choice == "Claude Code" then
    -- launch Stage 2: ClaudeCommands picker
  elseif choice == "OpenCode" then
    -- launch Stage 2: OpencodeCommands picker
  end
end)
```
Snacks is already configured to override `vim.ui.input` with its styled variant, and snacks
provides `input` but not `select` override in the current config. However `vim.ui.select` is
enhanced by dressing.nvim or snacks.picker if available. Even without enhancement it is lightweight.

Option B - snacks.nvim floating window (slightly richer):
Since `snacks.nvim` is already a dependency (used for OpenCode terminal), using `snacks.picker`
for Stage 1 would be native and consistent. Snacks already has `picker` enabled in `opencode.lua`
(`opts = { input = {}, picker = {}, terminal = {} }`). This gives a styled floating list.

Option C - `vim.fn.inputlist` (minimal):
```lua
local choice = vim.fn.inputlist({"Select AI tool:", "1. Claude Code", "2. OpenCode"})
```
Fast and dependency-free but visually inferior - no icons, no descriptions.

**Recommendation**: Use `vim.ui.select` for Stage 1. It is consistent with how `worktree.lua`
already does tool selection within Claude, it is styleable via existing snacks configuration,
and it requires no new dependencies. Add icon prefixes to item strings for visual richness:
```lua
{"  Claude Code", "  OpenCode"}
```

### 4. State Persistence and Frequency-Based Ordering

**Current state**: There is already a per-tool state system:
- Claude: `vim.fn.stdpath("data") .. "/claude/last_session.json"` (session state, not tool selection)
- OpenCode: no session persistence visible in current code

**For unified tool picker state**, a simple file at `vim.fn.stdpath("data") .. "/ai_tool_state.json"`
would store:
```json
{
  "last_selected": "claude",
  "usage_counts": {"claude": 47, "opencode": 12},
  "last_used_at": {"claude": 1746300000, "opencode": 1746200000}
}
```

**Frequency-based ordering** (show most-used tool first) is low-cost and meaningful. The
implementation requires only:
1. Reading the file on picker open
2. Sorting tool list by `usage_counts` descending
3. Writing an increment after selection

This takes ~20 lines of Lua and no new architecture. It is worth doing in task 518.

**Last-selected persistence** (show previously chosen tool first) is the minimum viable state
and should definitely be implemented. It handles the common case where a user works with one
tool for days at a time.

### 5. Context-Aware Tool Selection

**Feasibility**: The idea of preferring OpenCode for certain filetypes or directories is
technically trivial (check `vim.bo.filetype` or `vim.fn.getcwd()` before presenting the picker).

**Recommendation**: Do NOT implement context-awareness in task 518. Reasons:
1. It requires the user to configure rules ("prefer X for filetype Y"), adding configuration
   surface area that is not yet motivated by real usage patterns
2. The frequency-based ordering already provides emergent context-awareness: if a user always
   opens OpenCode when editing `.lean` files, it will naturally bubble up
3. It risks surprising behavior ("why is Claude pre-selected here?")

Reserve context-awareness as a follow-on task once the unified picker has been used long enough
to identify concrete patterns.

### 6. Live Status Display in Picker

**The question**: Should the picker show tool status (e.g., "Claude Code: 2 sessions", "OpenCode: idle")?

**Assessment**: This is valuable but has a complexity cost.

For Claude Code: session count is accessible via `session-manager.detect_claude_buffers()` which
returns active Claude terminal buffers. This is cheap.

For OpenCode: there is no session counting API visible in the current opencode module. The
`snacks.terminal.get()` call in `opencode.lua` could indicate if a terminal is active, but it
requires coupling the picker to the terminal backend.

**Recommendation for task 518**: Show a simple binary status ("active" vs "idle") based on
whether a terminal buffer for each tool is currently open. This is meaningful, cheap, and avoids
over-engineering. Full session counts can be added later.

Example display in `vim.ui.select`:
```
"  Claude Code  [active]"
"  OpenCode     [idle]"
```

### 7. Broader Unification Opportunities

The unified picker concept could extend to other areas. In approximate priority order:

**High value, low cost** - already partially done:
- Unified "AI session" keymap: `<leader>a` group is already the AI hub; the unified picker
  replaces `<leader>ac` (Claude commands) and `<leader>ao` (OpenCode commands) with a single
  `<leader>aa` (AI: pick tool then command)

**Medium value** - related but separate tasks:
- Unified visual selection: `<leader>av` sends visual selection to whichever AI tool is
  active/preferred; currently `<leader>ac` (visual mode) and `<leader>ao` (visual mode) are
  separate bindings that do the same thing for different tools
- Unified session history: a picker that shows sessions from both tools in a unified list,
  organized by recency

**Lower priority**:
- Unified search (Telescope + snacks picker), unified terminal management - these are
  independent concerns and should not be bundled with the AI picker

### 8. Keymap Architecture Implications

Current state has a conflict: `<leader>as` is bound to BOTH `claude.resume_session` AND
`opencode.select` (line 257 and 263 of which-key.lua). This is a which-key duplicate that
likely causes silent override. The unified picker is an opportunity to clean this up:

Proposed unified `<leader>a` group after task 518:
```
<leader>aa  -- AI: pick tool (unified Stage 1 picker)
<leader>ac  -- Claude commands (direct, no Stage 1 for power users)
<leader>ao  -- OpenCode commands (direct, no Stage 1 for power users)
<leader>as  -- AI sessions (unified session history picker)
<leader>ab  -- OpenCode buffer context (keep as-is, tool-specific)
<leader>ad  -- OpenCode diagnostics (keep as-is, tool-specific)
```

The `<C-CR>` and `<C-g>` toggle bindings should remain tool-specific (not unified) because
toggle-by-shortcut is a "I know what I want" interaction, while the picker is "help me choose."

---

## Recommended Approach

### Phase 1: Two-Stage Picker (core of task 518)

1. Create `lua/neotex/plugins/ai/shared/picker/tool-selector.lua`:
   - `M.show(opts)` - presents Stage 1 using `vim.ui.select`
   - Reads/writes `ai_tool_state.json` for persistence
   - Sorts tools by usage frequency
   - Shows binary active/idle status
   - On selection, dispatches to `ClaudeCommands` or `OpencodeCommands`

2. Register a new user command `AIToolPicker` that calls `tool-selector.show()`

3. Add keymap `<leader>aa` -> `AIToolPicker`

4. Keep `<leader>ac` and `<leader>ao` as direct shortcuts (do not remove)

5. Fix the `<leader>as` conflict

### Phase 2: Refactor (separate task, triggered by task 518)

6. Move `claude/commands/picker/init.lua` and subdirectories to `shared/picker/`
   - Update both tool picker facades to import from shared
   - This eliminates the cross-module dependency

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `vim.ui.select` looks plain without dressing.nvim | Medium | Low | Use icon prefixes; snacks already enhances vim.ui.input, extending to select is optional |
| State file corruption | Low | Low | Wrap all reads/writes in pcall; treat corrupted state as "no state" |
| Adding a third AI tool requires updating tool-selector | Certain | Low | Tool list in tool-selector should be a module-level table, not hardcoded strings |
| `<leader>as` conflict causes bugs currently | High | Low | Fix this in task 518 regardless of other scope |
| Scope creep into session management complexity | Medium | Medium | Keep Stage 1 picker simple; do not conflate tool selection with session resumption |

---

## Evidence and Examples

**Cross-module dependency confirmed** (opencode/commands/picker.lua line 8):
```lua
local internal = require("neotex.plugins.ai.claude.commands.picker.init")
```

**Existing `vim.ui.select` pattern in codebase** (claude/core/worktree.lua lines 257, 499, 586):
```lua
vim.ui.select(M.config.types, { prompt = "Worktree type:" }, function(choice) ... end)
```
This pattern is already established in the AI plugin tree.

**`<leader>as` conflict** (which-key.lua lines 257 and 263):
```lua
{ "<leader>as", function() require("neotex.plugins.ai.claude").resume_session() end, desc = "claude sessions" },
{ "<leader>as", function() require("opencode").select() end, desc = "opencode select" },
```
The second binding silently overrides the first in which-key. The description "opencode select"
is also misleading (it sends visual selection context, not "select" in the picker sense).

**snacks picker is already available**: `opencode.lua` declares `opts = { picker = {} }` in its
snacks dependency, meaning `snacks.picker` is already loaded when OpenCode is active.

**Usage count pattern precedent**: The session state file at
`vim.fn.stdpath("data") .. "/claude/last_session.json"` already stores timestamps and metadata.
The `ai_tool_state.json` can follow the same pattern in the same directory.

---

## Confidence Level

- Architecture analysis (shared/picker location, cross-module dependency): **High**
- `vim.ui.select` as right UX for Stage 1: **High** (established pattern in codebase)
- Frequency-based ordering: **High** (trivial to implement, clear value)
- Context-aware selection: **High confidence to NOT do this in task 518**
- Moving picker impl to shared/: **High** (correct direction, timing is judgement call)
- Status display in picker: **Medium** (Claude status easy, OpenCode status requires checking snacks terminal API)
