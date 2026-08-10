# Implementation Summary: Unified AI Tool Picker with Session Management

## What was done

### Phase 1: Fix Pre-existing Bugs
- Deleted 9,612 orphaned `last_session.json.backup.*` files from `~/.local/share/nvim/claude/`
- Added backup file count cap (max 5) to `session-manager.lua:cleanup_state_file()`
- Fixed dead `opencode_terminal` filetype detection in `keymaps.lua:set_terminal_keymaps()` -- now uses `vim.b.snacks_terminal.cmd` string matching
- Resolved `<leader>as` collision in `which-key.lua` -- single unified binding with lazy init
- Corrected `<C-c>` to `<C-CR>` in docs: `MAPPINGS.md:123`, `AI_TOOLING.md:38`, `DOCUMENTATION_STANDARDS.md:217`, and `keymaps.lua` header comments

### Phase 2: Build Core ai-tool-picker.lua Module
- Created `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (~250 lines)
- Tool preference persistence with atomic writes to `~/.local/share/nvim/neotex-ai/tool-prefs.json`
- Active terminal detection: Claude via `session-manager.detect_claude_buffers()` with `jobwait(0)` liveness check; OpenCode via `snacks.terminal.list()` with cmd string matching
- `smart_toggle()`: direct toggle if one tool visible, Stage 1 picker otherwise
- Stage 1: `vim.ui.select` with 2 tools, last-selected reordered first
- Stage 2 Claude: delegates to existing `claude_session.show_session_picker()`
- Stage 2 OpenCode: Telescope dropdown with 3 options (new, restore last, browse all) with deferred API calls
- OpenCode session tracking via `OpencodeEvent:session.idle` autocmd, persisted to `opencode-last-session.json`
- "New session" uses `toggle()` only (TUI defaults to fresh session), avoiding double-terminal bug from `opencode.command()` internally starting its own server

### Phase 3: Integrate Keymaps
- Updated all 4 `<C-CR>` mode mappings (n, i, v, t) to call unified picker with lazy init
- Removed global `<C-g>` mapping (was at keymaps.lua:282-283)
- Updated `<leader>as` in which-key.lua with lazy init wrapper

### Phase 4: Polish and Documentation
- Added "Unified AI Tool Picker" section to `docs/AI_TOOLING.md` documenting two-stage flow and keybindings

## Key architectural decisions
- `vim.ui.select` for Stage 1 (simple 2-item picker, no Telescope dependency needed)
- Atomic writes (`io.open` + `os.rename`) for all persistence files -- zero backup file proliferation
- Lazy initialization: `setup()` called on first keypress, not at config load time
- Retry loop (10 attempts, 200ms intervals) for OpenCode TUI commands to handle server startup delay
