# Task 544: Fix OpenCode Session Picker Restore/Browse Options

- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: neovim
- **Dependencies**: None

## Description

Fix the "Restore last session" and "Browse all sessions" options in the OpenCode session picker (`<C-CR>` → OpenCode).

### Root Cause

In `lua/neotex/plugins/ai/ai-tool-picker.lua`, `show_opencode_session_picker()` has three options:

1. **"Create new session"** — Works: just calls `toggle()` to open terminal
2. **"Restore last session"** — Broken: calls `toggle()`, then after 1s tries `server.select_session(last_session_id)` via `vim.defer_fn(..., 1000)`
3. **"Browse all sessions"** — Broken: calls `toggle()`, then after 1s tries `opencode_mod.select_session()`

The approach relies on `vim.defer_fn(..., 1000)` to wait for the OpenCode server to be ready, which is fundamentally unreliable. The server needs to start the `opencode --port` process, open a port, start the HTTP server, and be discoverable via `pgrep`. A 1-second hardcoded delay is too fragile.

### Proposed Fix

Replace the fragile deferred approach with proper server-ready detection:

- Wait for `OpencodeEvent:server.connected` event (or poll the server) before attempting session API calls
- Handle edge cases: server startup failure, no saved sessions
- Add proper error messages for each failure mode

### Contrast with ClaudeCode

Claude Code's session picker works because it uses CLI flags (`claude --continue`, `claude --resume <id>`) to start directly with the desired session. OpenCode doesn't have equivalent CLI flags — sessions are managed through the TUI's HTTP API, which requires the server to be running first.

### Key Files

- `lua/neotex/plugins/ai/ai-tool-picker.lua` — Session picker implementation
- OpenCode plugin session API (`server.select_session()`, `select_session()`)
