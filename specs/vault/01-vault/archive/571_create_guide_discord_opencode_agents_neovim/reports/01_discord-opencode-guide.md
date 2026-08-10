# Research Report: Task #571

**Task**: 571 - Create guide for using Discord to manage OpenCode agents from Neovim
**Started**: 2026-05-14T09:15:00Z
**Completed**: 2026-05-14T09:55:00Z
**Effort**: 45 minutes
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.dotfiles/docs/discord-bot.md` - NixOS Discord bot infrastructure docs
- `/home/benjamin/.dotfiles/configuration.nix` - NixOS systemd service definitions
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` - Nextcord bot source
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/api.py` - HTTP API routes
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` - OpenCode REST client
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/relay.py` - Thread relay logic
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_tool/src/config.py` - Bot configuration
- `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_tool/src/store.py` - Session persistence
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode.lua` - Neovim OpenCode plugin
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/discord-link.lua` - Discord link module
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/discord-session-picker.lua` - Telescope session picker
- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` - Keymap registrations
- `/home/benjamin/.config/nvim/.opencode/docs/guides/tts-stt-integration.md` - Style reference
- `systemctl status opencode-serve / discord-bot` - Live service status verification
**Artifacts**:
- `specs/571_create_guide_discord_opencode_agents_neovim/reports/01_discord-opencode-guide.md` (this file)
**Standards**: report-format.md, artifact-management.md, tasks.md

---

## Executive Summary

- The Discord bot infrastructure is **fully implemented and running** on the host (`hamsa`): both `opencode-serve.service` and `discord-bot.service` are active since 2026-05-10 with sops-nix secrets injected
- Neovim integration plugins already exist: `discord-link.lua` (POST /link) and `discord-session-picker.lua` (Telescope picker for GET /sessions / POST /kill) with keybindings `<leader>ar` and `<leader>as`
- The current discord-bot process has a **known issue**: "heartbeat blocked" warnings indicate the asyncio event loop is blocking, preventing the HTTP API server from accepting connections; this needs fixing before the Neovim integration is usable
- The full workflow is: `<leader>ar` links the current OpenCode session to a Discord thread -> Discord mobile receives messages -> user can reply from Discord -> bot relays to OpenCode; `<leader>as` opens the Telescope picker to monitor/kill sessions
- Two environment variables must be set in Neovim's environment for the integration to work: `DISCORD_BOT_URL` (default `http://localhost:8080`) and `DISCORD_BOT_LINK_TOKEN` (matches `LINK_API_TOKEN` in the service, currently empty = no auth needed)
- The guide should document the full workflow, the environment variable setup, service management commands, and the heartbeat bug as a known issue with the fix (restart or use `systemctl restart discord-bot`)

---

## Context & Scope

**What was researched**: The complete system for using Discord to manage OpenCode agents from within Neovim, including the NixOS infrastructure, bot Python source code, Neovim plugin implementations, keymap registrations, and current live system state.

**Scope**: The guide will live at `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` (following the existing guide naming convention). It should cover the everyday workflow, not the initial setup (which is documented in `discord-bot.md` and the task 053 specs).

**Constraints**:
- The `LINK_API_TOKEN` / `DISCORD_BOT_LINK_TOKEN` is currently empty (no auth enforced), but the Neovim plugin requires it to be set (line 52 of discord-link.lua returns error if TOKEN is empty/nil). This needs to be documented.
- The `DISCORD_CHANNEL_ID` is now loaded from sops-nix (updated from the `discord-bot.md` which shows it as a plain env var). This is an important clarification.
- OpenCode server runs on port **4096** (fixed, not mDNS discovery as older docs state).

---

## Findings

### Architecture Overview

```
Neovim (Editor)
  |
  | <leader>ar -- POST /link  -->  discord-bot HTTP API (127.0.0.1:8080)
  | <leader>as -- GET /sessions --> discord-bot HTTP API
  |              POST /kill    -->
  |
discord-bot.service (Nextcord)
  |
  | POST /session/{id}/message --> opencode-serve.service (127.0.0.1:4096)
  | GET  /session               -->
  |
Discord Gateway <--> Discord Servers <--> Discord Mobile App
```

The three-tier architecture:
1. **Neovim layer**: Lua plugins call the bot's HTTP API via `curl` (async via `vim.fn.jobstart`)
2. **Bot layer**: Discord bot + aiohttp HTTP server bridging Neovim to Discord threads
3. **OpenCode layer**: Headless `opencode serve` agent receiving/sending messages

### NixOS Infrastructure (Confirmed Running)

- `opencode-serve.service`: Running since 2026-05-10, bound to `127.0.0.1:4096`, auth via `OPENCODE_SERVER_PASSWORD` from sops-nix credential
- `discord-bot.service`: Running since 2026-05-10, **but has heartbeat blocking issue** (asyncio event loop blocked by heavy I/O from concurrent OpenCode sessions in the same process). The HTTP API server (port 8080) may not respond due to this.
- Secrets: `discord_bot_token`, `opencode_server_password`, `discord_channel_id` all managed via sops-nix, injected as LoadCredential files, never plaintext on disk
- `LINK_API_TOKEN` is **empty** (configured as plain env var with empty value, not via sops). This means the bot API has no authentication; Neovim's `DISCORD_BOT_LINK_TOKEN` can be set to any non-empty value but the bot will reject it. Actually: the bot auth check returns `None` (no-op) when `LINK_API_TOKEN` is empty, so any Bearer token (or even an empty auth header) would... wait, re-reading `auth.py`: if `expected_token` (=`LINK_API_TOKEN`) is empty, auth IS skipped. But in `discord-link.lua`, line 52: if TOKEN is nil/empty it returns an error "DISCORD_BOT_LINK_TOKEN not set". So the Neovim side requires the token to be set even though the bot side doesn't enforce it. This means `DISCORD_BOT_LINK_TOKEN` must be set to ANY non-empty string for the Neovim plugin to work.

### Neovim Plugins (Already Implemented)

**`discord-link.lua`** (`lua/neotex/plugins/ai/opencode/discord-link.lua`):
- `link_current_session()`: Discovers active OpenCode session via `opencode session list --format json`, filters by CWD, calls `POST /link` with `{session_id, session_name}`, copies thread URL to clipboard
- Error handling: connection refused, 401, 409 (already linked), generic API errors
- Environment: `DISCORD_BOT_URL` (default: `http://localhost:8080`), `DISCORD_BOT_LINK_TOKEN` (required, any non-empty string works since bot has no auth)

**`discord-session-picker.lua`** (`lua/neotex/plugins/ai/opencode/discord-session-picker.lua`):
- `show()`: Telescope picker fetching `GET /sessions`, displays session name/status/linked time
- `<CR>`: Kills selected session (POST /kill) and refreshes picker
- `<C-o>`: Copies thread URL to clipboard
- Preview pane shows session details (ID, status, thread URL, CWD, linked time)

**Registered commands and keybindings** (`opencode.lua`):
- `:OpenCodeLinkDiscord` → `<leader>ar` — Link current session to Discord
- `:DiscordSessions` → `<leader>as` — Browse/manage linked sessions

**Session discovery flow**: `opencode session list --format json` → filter by `directory == vim.fn.getcwd()` → use first match or most recent session if no CWD match

### Bot HTTP API Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/link` | POST | Bearer | Link session to Discord thread; body: `{session_id, session_name}` |
| `/sessions` | GET | Bearer | List all linked sessions |
| `/kill` | POST | Bearer | Abort + unlink session; body: `{session_id}` |
| `/health` | GET | None | Health check; returns `{healthy, discord_connected, opencode_connected, linked_sessions, uptime}` |

Note: Auth is **skipped** when `LINK_API_TOKEN` is empty (current config). The Neovim plugin still requires `DISCORD_BOT_LINK_TOKEN` to be set to any non-empty string.

### OpenCode REST API (used by bot internally)

- `GET /global/health` — Health check
- `GET /session` — List all sessions
- `GET /session/{id}` — Get session details
- `POST /session/{id}/message` — Send message (body: `{parts: [{type: "text", text: "..."}]}`)
- `POST /session/{id}/abort` — Abort session
- `DELETE /session/{id}` — Delete session

### Discord Threading Model

- Each linked OpenCode session gets a **dedicated Discord thread** in a configured channel (`DISCORD_CHANNEL_ID`)
- Thread name: `Session: {session_name}` or `Session: {session_id[:12]}`
- Thread auto-archives after 7 days of inactivity
- Messages sent in the thread are relayed to OpenCode; responses are split at 2000-char Discord limit
- Bot only processes messages in linked threads from the CWD-matched session

### Current Status and Known Issues

1. **Heartbeat blocking**: The `discord-bot` process shows "heartbeat blocked for >N seconds" warnings. This is a Discord gateway keepalive issue where the asyncio event loop becomes blocked. The aiohttp HTTP API server (for Neovim) runs in the same event loop and becomes unresponsive. Fix: `systemctl restart discord-bot`.

2. **LINK_API_TOKEN empty**: The bot has no authentication on the HTTP API (`LINK_API_TOKEN=` is empty). To use the Neovim plugin, `DISCORD_BOT_LINK_TOKEN` must be set to any non-empty string in the shell environment. When the token is empty in the env, the Neovim plugin refuses to make requests.

3. **Port is 8080 by default**: `BOT_HTTP_PORT` not set in the service; defaults to 8080. The bot binds the HTTP server to `127.0.0.1:8080`.

4. **OpenCode session discovery**: The `_discover_session` function uses `opencode session list --format json` to find the current session. This requires that an OpenCode session exists and was started from (or is associated with) the current working directory. If multiple sessions exist for the same CWD, it uses the first one returned.

### Everyday Workflow (Low-Friction Pattern)

The intended workflow for everyday use:

1. **Start working in Neovim**: OpenCode runs as a TUI panel via `opencode.nvim` (opened with the configured OpenCode keybinding in the `<leader>a` group)
2. **Link session to Discord**: Press `<leader>ar` → session is discovered, thread created, URL copied to clipboard
3. **Open Discord on mobile**: Paste/navigate to the thread URL — or just check the channel for the new thread
4. **Monitor from mobile**: When OpenCode finishes a task, Discord thread receives the response. Can review on phone without being at the computer.
5. **Send instructions from mobile**: Type a message in the Discord thread → bot relays to OpenCode → response comes back in the thread
6. **Manage sessions from Neovim**: Press `<leader>as` → Telescope picker shows all linked sessions → `<CR>` kills a session, `<C-o>` copies thread URL
7. **Service health check**: `:!curl -s http://localhost:8080/health | jq .` or `systemctl status discord-bot` from terminal

### Environment Variables to Document

For the Neovim integration to work, the following must be in the shell environment (e.g., in `.zshrc`/`.bashrc` or NixOS `home.sessionVariables`):

| Variable | Value | Notes |
|----------|-------|-------|
| `DISCORD_BOT_URL` | `http://localhost:8080` | Optional; this is the default. Override only if port changes. |
| `DISCORD_BOT_LINK_TOKEN` | Any non-empty string | Required by Neovim plugin. Bot ignores auth when `LINK_API_TOKEN` is empty. |

The bot-side environment variables are managed by the systemd service unit; users do not set these directly.

### Guide Location and Naming

The guide should be placed at:
```
/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md
```

Following existing guide conventions (kebab-case, descriptive names like `tts-stt-integration.md`).

The guides `README.md` should be updated to list this new guide.

---

## Decisions

1. **Guide audience**: Everyday user who has the infrastructure running, not the initial setup operator. The setup is covered in `discord-bot.md` and task 053 specs.
2. **Scope boundaries**: The guide covers the workflow from Neovim's perspective. It references `discord-bot.md` for NixOS setup but does not duplicate it.
3. **Known issues section**: The heartbeat blocking issue and the `LINK_API_TOKEN` quirk should be prominently documented since they affect the current live system.
4. **Service management**: Include `systemctl` commands for checking/restarting services — these are the day-to-day operations a user needs.
5. **Discord mobile angle**: Explicitly frame this as enabling mobile monitoring and remote control — that's the key use case that makes this valuable for someone working in Neovim.

---

## Recommendations

1. **Write the guide file** at `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` with:
   - Architecture diagram (text-based)
   - Prerequisites (services must be running, env vars set)
   - Quick start (3-step: open session, link, check Discord)
   - Detailed workflow (everyday operations)
   - Keybinding reference table
   - Service management commands
   - Troubleshooting (heartbeat issue, token issue, session discovery failures)

2. **Update `guides/README.md`** to add a new section for "Mobile/Remote Access" containing this guide.

3. **Fix the `LINK_API_TOKEN` gap**: Either:
   - Add `LINK_API_TOKEN` to sops secrets and set `DISCORD_BOT_LINK_TOKEN` to match in home.sessionVariables, OR
   - Document clearly that any non-empty string works for `DISCORD_BOT_LINK_TOKEN` since the bot has no auth configured

4. **Note the heartbeat fix**: Document `systemctl restart discord-bot` as the quick fix for when the HTTP API becomes unresponsive.

---

## Risks & Mitigations

- **Heartbeat blocking**: The discord-bot process is currently in a degraded state (HTTP API unresponsive). The guide should document how to detect (check `/health`) and fix (`systemctl restart discord-bot`).
- **Session discovery ambiguity**: If multiple OpenCode sessions exist for the same CWD, the plugin uses the first one returned. Users should be aware of this and kill old sessions to avoid confusion.
- **Bot token expiry**: If the Discord bot token expires, the bot will silently fail to relay messages. The service will restart but keep failing. `journalctl -fu discord-bot` reveals this.
- **OpenCode server down**: If `opencode-serve` is not running, message relay will fail with "OpenCode server unavailable". Both services must be healthy.

---

## Context Extension Recommendations

- **Topic**: Discord/OpenCode mobile workflow patterns
- **Gap**: No documentation in `.claude/context/` about the existing Discord bot integration for remote monitoring
- **Recommendation**: After the guide is written, consider adding a brief entry to the neovim extension context about the Discord keybindings (`<leader>ar`, `<leader>as`) as part of the AI tool integration patterns.

---

## Appendix

### Key File Paths

| File | Purpose |
|------|---------|
| `/home/benjamin/.dotfiles/docs/discord-bot.md` | NixOS infrastructure documentation |
| `/home/benjamin/.dotfiles/configuration.nix` | Systemd service definitions |
| `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` | Nextcord bot entry point |
| `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/api.py` | HTTP API routes |
| `/home/benjamin/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/opencode_client.py` | OpenCode REST client |
| `/home/benjamin/.dotfiles/opencode-discord-bot/data/sessions.json` | Session persistence store |
| `lua/neotex/plugins/ai/opencode/discord-link.lua` | Neovim link command |
| `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` | Telescope session picker |
| `lua/neotex/plugins/ai/opencode.lua` | Command registrations and keybindings |

### Live System State

- `opencode-serve.service`: Active, running, port 4096, 4 days uptime
- `discord-bot.service`: Active, but event loop blocked (heartbeat warnings); HTTP API on port 8080 not responding
- `opencode session list`: Returns sessions for current project (verified working)

### Service Environment Variables (Bot Side)

```
OPENCODE_SERVER_URL=http://127.0.0.1:4096
DISCORD_BOT_TOKEN=/run/credentials/discord-bot.service/discord_bot_token  # file path
OPENCODE_SERVER_PASSWORD=/run/credentials/discord-bot.service/opencode_server_password  # file path
DISCORD_CHANNEL_ID=/run/credentials/discord-bot.service/discord_channel_id  # file path
WHITELISTED_USER_IDS=  # empty = no whitelist
LINK_API_TOKEN=  # empty = no auth on HTTP API
LOG_LEVEL=info
PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot
```

### Neovim Environment Variables Required

```bash
export DISCORD_BOT_URL="http://localhost:8080"  # default, optional
export DISCORD_BOT_LINK_TOKEN="any-non-empty-string"  # required for plugin
```

### Bot HTTP API — Example curl Commands

```bash
# Health check (no auth needed)
curl -s http://localhost:8080/health | jq .

# List linked sessions (auth required if LINK_API_TOKEN is set)
curl -s -H "Authorization: Bearer mytoken" http://localhost:8080/sessions | jq .

# Link a session
curl -s -X POST \
  -H "Authorization: Bearer mytoken" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "ses_...", "session_name": "my-project"}' \
  http://localhost:8080/link | jq .

# Kill a session
curl -s -X POST \
  -H "Authorization: Bearer mytoken" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "ses_..."}' \
  http://localhost:8080/kill | jq .
```
