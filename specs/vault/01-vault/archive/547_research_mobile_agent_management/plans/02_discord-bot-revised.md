# Implementation Plan: Neovim Discord Session Integration

- **Task**: 547 - research_mobile_agent_management
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: External task 53 (bot source at `~/.dotfiles/opencode-discord-bot/`, bot HTTP API)
- **Research Inputs**:
  - specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md (v1 baseline)
  - specs/547_research_mobile_agent_management/reports/02_team-research.md (round 2 synthesis)
- **Artifacts**: plans/02_discord-bot-revised.md (this file, replaces v1)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Neovim-side integration for the Discord mobile agent management system. This covers only the Neovim Lua code in this repo — the Discord bot source code (`~/.dotfiles/opencode-discord-bot/`) is handled by external task 53. Two capabilities: (1) `:OpenCodeLinkDiscord` / `<leader>ar` to link the current OpenCode session to a Discord thread, and (2) a telescope picker listing all Discord-linked sessions with the ability to kill them. The bot's local HTTP API (`POST /link`, `GET /sessions`, `POST /kill`) is the integration surface.

### Research Integration

All research rounds are integrated:
- **R1**: OpenCode headless CLI, Nextcord 3.1.1, `/rc` slash command group, bot as thin relay
- **R2**: Implicit channel switching via Discord threads, single bot token confirmed, COAT abstractions in bot (external), P0 preflight handled in task 53

### External Dependencies

This plan depends on the bot HTTP API providing these endpoints (implemented in task 53):
- `POST /link` — creates Discord thread, returns thread jump URL (body: `{session_id, session_name}`)
- `GET /sessions` — lists all linked sessions with thread IDs, names, statuses
- `POST /kill` — kills a session by session ID (body: `{session_id}`)
- Auth: `Authorization: Bearer <LINK_API_TOKEN>` header on all requests

### What This Plan Does NOT Cover

- Bot Python source code (Phases 2-5, 7 of old plan) — task 53
- P0 preflight (MESSAGE_CONTENT, `opencode run` testing, permissions) — task 53
- Systemd service definitions — task 53
- Message pagination, gateway reconnect, thread lifecycle — task 53

## Goals & Non-Goals

**Goals**:
- Neovim `:OpenCodeLinkDiscord` user command
- `<leader>ar` keymap in the `<leader>a` (ai) group
- Discord-linked session kill picker (telescope) listing all sessions with kill action
- which-key entry for `<leader>ar`
- Error handling for all failure cases (no session, bot unreachable, auth failure, already linked)

**Non-Goals**:
- Discord bot source code (external task 53)
- Systemd, NixOS, secrets management (external task 53)
- `/rc` slash command implementation (external task 53)
- OpenCode server integration (external task 53)
- Message relay logic (external task 53)
- Pi agent host (future)
- Mosh/SSH (deferred)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bot HTTP API not available during development | High | Medium | Guard against connection errors; clear "bot unreachable" notification; use curl-based manual testing |
| `<leader>ar` keymap collision | Low | Low | `<leader>ar` verified free in current which-key config |
| Session ID discovery fragile (multiple opencode processes) | Medium | Medium | Inspect `opencode --port` process, filter by CWD in `opencode session list`, fall back to port-based lookup |
| Bot API returns stale session data | Low | Low | GET /sessions is authoritative; picker refreshes on open |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases 1 and 2 are independent and can run in parallel. Phase 3 integrates them into which-key.

### Phase 1: `:OpenCodeLinkDiscord` Command and `<leader>ar` Keymap [COMPLETED]

**Goal**: Neovim command that discovers the current OpenCode session, calls the bot's HTTP `POST /link` API, and displays the Discord thread URL to the user.

**Tasks**:
- [ ] **Task 1.1**: Implement `lua/neotex/plugins/ai/opencode/discord-link.lua` — module with `link_current_session()` function:
  - Discover current session: inspect running `opencode --port` process, extract port, use `opencode session list` filtered to CWD to find session ID
  - Check bot API reachability first with a quick `GET /health` call
  - Call `POST /link` with `Authorization: Bearer <LINK_API_TOKEN>`, body `{session_id, session_name}` (session_name from `vim.fn.getcwd()` basename)
  - Parse response for `thread_url`
  - Return both thread_url and any errors
- [ ] **Task 1.2**: Register `:OpenCodeLinkDiscord` user command — `vim.api.nvim_create_user_command` with `desc = "Link current OpenCode session to Discord thread"`; calls `link_current_session()`, displays thread URL via `vim.notify` (INFO level), copies to `+` clipboard
- [ ] **Task 1.3**: Add `<leader>ar` keymap in `lua/neotex/plugins/ai/opencode.lua` in the `keys` table: `{ "<leader>ar", "<cmd>OpenCodeLinkDiscord<CR>", desc = "Link session to Discord" }`
- [ ] **Task 1.4**: Handle error cases:
  - No active session: "No active OpenCode session — start one first"
  - Bot unreachable: "Discord bot unreachable — check systemctl status discord-bot"
  - Auth failure (401): "LINK_API_TOKEN mismatch — check env"
  - Already linked: "Session already linked" with existing thread URL
  - API error: pass through the error message from bot response

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/discord-link.lua` — link logic (new)
- `lua/neotex/plugins/ai/opencode.lua` — add keymap and command registration (modify)

**Verification**:
- `:OpenCodeLinkDiscord` with active session calls bot API and shows thread URL notification
- Thread URL is copied to clipboard
- `<leader>ar` triggers same behavior
- All four error cases produce clear, actionable messages
- Command is a no-op (graceful notification) when no session is active

---

### Phase 2: Discord-Linked Session Kill Picker [COMPLETED]

**Goal**: Telescope picker listing all Discord-linked sessions (fetched from bot's `GET /sessions` API) with the ability to kill them via `POST /kill`. Follows the existing process-picker pattern in `lua/neotex/plugins/tools/process-picker.lua`.

**Tasks**:
- [ ] **Task 2.1**: Implement `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` — module with `show()` function:
  - `fetch_sessions()`: call `GET /sessions` with auth header, parse JSON, return session list
  - If API unreachable, show telescope notification and abort
  - Build telescope entries: fields (session_name, session_id, thread_channel, status, linked_at, thread_url)
  - Column display: NAME (truncated), STATUS (active/idle/killed), LINKED (relative time)
  - Preview pane: session ID, thread URL, linked timestamp, status
  - Actions:
    - `<CR>`: kill session via `POST /kill {session_id}`, show confirmation notification, refresh picker
    - `<C-o>`: copy thread URL to clipboard
    - `<Esc>` / `<C-c>`: close picker
  - Follow the telescope patterns used in `process-picker.lua` (entry_maker, previewer, attach_mappings)
- [ ] **Task 2.2**: Register `:DiscordSessions` user command — `vim.api.nvim_create_user_command("DiscordSessions", function() require("neotex.plugins.ai.opencode.discord-session-picker").show() end, { desc = "Browse linked Discord sessions" })`
- [ ] **Task 2.3**: Add `<leader>ad` keymap in `lua/neotex/plugins/ai/opencode.lua` keys table: `{ "<leader>ad", "<cmd>DiscordSessions<CR>", desc = "Discord sessions" }`
- [ ] **Task 2.4**: Add which-key entry for `<leader>ad` in `lua/neotex/plugins/editor/which-key.lua` `<leader>a` group: `{ "<leader>ad", desc = "discord sessions", icon = "󰙯" }`

**Timing**: 1.5 hours

**Depends on**: none (can run parallel with Phase 1)

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` — session picker (new)
- `lua/neotex/plugins/ai/opencode.lua` — add keymap and command (modify)
- `lua/neotex/plugins/editor/which-key.lua` — add `<leader>ad` entry (modify)

**Verification**:
- `:DiscordSessions` opens telescope picker with session list from bot API
- Picker shows NAME, STATUS, LINKED columns
- `<CR>` on a session kills it via API, refreshes list with confirmation notification
- `<C-o>` copies thread URL to clipboard
- Empty list shows "No linked sessions" message
- API unreachable shows clear error and closes picker
- `<leader>ad` triggers same behavior

---

### Phase 3: Integration & Polish [COMPLETED]

**Goal**: Wire both commands into which-key, add final error handling, and test full end-to-end flow.

**Tasks**:
- [ ] **Task 3.1**: Update `lua/neotex/plugins/editor/which-key.lua` — ensure `<leader>ar` entry appears in `<leader>a` group with `desc = "link discord session"` and `icon = "󰙯"` (verify `<leader>ad` entry from Phase 2 is present)
- [ ] **Task 3.2**: Test end-to-end: start OpenCode session, `:OpenCodeLinkDiscord` (verify thread URL in clipboard), `:DiscordSessions` (verify session appears), kill session via `<CR>` in picker (verify it disappears), open Discord thread URL in browser to confirm it works
- [ ] **Task 3.3**: Test error recovery: stop bot (`systemctl stop discord-bot`), verify both commands show graceful "bot unreachable" messages; restart bot, verify commands work again

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` — verify entries (modify if needed)

**Verification**:
- `<leader>a` which-key popup shows `ar` ("link discord session") and `ad` ("discord sessions")
- Full linking → listing → killing cycle works end-to-end
- Bot restart recovery is graceful

## Testing & Validation

- [ ] Manual: `:OpenCodeLinkDiscord` with active session → thread URL notification + clipboard
- [ ] Manual: `:DiscordSessions` picker → lists sessions → kill works → picker refreshes
- [ ] Manual: `<leader>ar` and `<leader>ad` keymaps trigger correct commands
- [ ] Manual: `<leader>a` which-key shows both entries with icons
- [ ] Manual: Error states (no session, bot down, auth failure)
- [ ] Manual: Bot restart recovery (stop → "unreachable" → start → working again)

## Artifacts & Outputs

- `lua/neotex/plugins/ai/opencode/discord-link.lua` — session linking module (new)
- `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` — session kill picker (new)
- `lua/neotex/plugins/ai/opencode.lua` — updated with commands and keymaps
- `lua/neotex/plugins/editor/which-key.lua` — updated with `<leader>ar` and `<leader>ad` entries

## Rollback/Contingency

- **Remove integration**: Delete `discord-link.lua` and `discord-session-picker.lua`, revert `opencode.lua` and `which-key.lua` changes from git
- **No persistent state**: These modules are pure API clients; no filesystem state in this repo
- **Bot dependency**: If bot is down, both commands fail gracefully with clear messages; no cascading failures
- **Keymap conflicts**: If `<leader>ar` or `<leader>ad` collide, move to a different key in the `<leader>a` group
