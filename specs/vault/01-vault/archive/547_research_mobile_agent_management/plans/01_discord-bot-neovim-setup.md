# Implementation Plan: Discord Bot and Neovim Integration for Mobile Agent Management

- **Task**: 547 - research_mobile_agent_management
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: None (NixOS prerequisites handled separately)
- **Research Inputs**: specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md
- **Artifacts**: plans/01_discord-bot-neovim-setup.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown

## Overview

Build a production-quality Discord bot application and Neovim integration that bridges OpenCode agent sessions to Discord threads for mobile (iPhone) access. The bot runs as a persistent daemon on NixOS, forwards messages between Discord threads and the `opencode serve` backend, and exposes a local HTTP API that the Neovim `:OpenCodeLinkDiscord` command (`<leader>ar`) calls to link the current session to a Discord thread. The bot is a thin relay, not an agent itself -- it consumes zero additional LLM tokens beyond what the active session would use anyway. Cutting no corners: includes whitelisting, token encryption, rate limiting, structured logging, health checks, and systemd integration.

### Research Integration

The plan incorporates all findings from the research report (01_mobile-agent-management-research.md): OpenCode headless CLI (`opencode serve`, `opencode run --command`, `opencode session`), Nextcord 3.1.1 as the Discord library, `/rc` slash command group design, session-to-thread 1:1 mapping, `:OpenCodeLinkDiscord` as the linking trigger, and the systemd service pattern modeled on existing `opencode-refresh.service`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan does not directly advance current ROADMAP.md items (documentation infrastructure and agent system quality), but enables the mobile agent management workflow that will indirectly accelerate all roadmap work by allowing task management from iPhone.

## Goals & Non-Goals

**Goals**:
- Discord bot Python application using Nextcord 3.1.1 with `/rc` slash command group
- `/rc session join/list/leave` for session management from Discord
- `/rc task status/create/research/plan/implement` for task lifecycle from Discord
- `/rc status` for system health overview
- `/rc refresh` for cleanup operations
- Bot-to-OpenCode communication via `opencode run --command` and `opencode run`
- 1:1 session-to-Discord-thread mapping with persistent state store
- Neovim `:OpenCodeLinkDiscord` command with `<leader>ar` keymap
- Local HTTP API on the bot for the Neovim command to call
- Systemd service definition with proper dependency ordering
- Discord user ID whitelisting for authorization
- Bot token stored via environment variable, never hardcoded
- Structured JSON logging to journald
- Health check endpoint and self-monitoring

**Non-Goals**:
- NixOS SSH/Mosh/firewall setup (handled separately)
- sops-nix secrets management (handled separately)
- Raspberry Pi agent host (future Phase 3)
- Discord bot for anything beyond OpenCode relay (no general-purpose bot)
- Mobile client other than Discord (Discord on iPhone is the target)
- Multi-user bot (single-user whitelist for initial deployment)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `opencode run --command` blocks indefinitely on long tasks | High | Medium | Set subprocess timeout (120s default); long tasks return async task ID; status polling via `/rc task status` |
| OpenCode server crashes leave orphaned session state | Medium | Medium | Leverage existing `opencode-refresh.timer`; add heartbeat check in bot health endpoint; auto-clean stale sessions on startup |
| Discord bot token exposure | Critical | Low | Token via `DISCORD_BOT_TOKEN` env var only; never logged; systemd service runs as dedicated user with restricted permissions |
| Session ID discovery unreliable (multiple OpenCode processes) | Medium | Medium | `opencode session list` provides authoritative listing; bot queries on startup and periodically; Neovim command passes explicit session ID |
| `/rc` command group name conflicts with other bots | Low | High | `/rc` is a unique namespace unlikely to conflict; if needed, configurable via env var |
| `<leader>ar` keymap collision | Low | Low | `<leader>ar` is currently unused in which-key (autolist uses `<leader>Lr`, not `<leader>ar`); verified free |
| Bot-to-OpenCode auth fails on server restart | Medium | Low | Retry with exponential backoff; health check endpoint surfaces auth status; reconnect on `OPENCODE_SERVER_PASSWORD` change |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Bot Project Scaffolding [NOT STARTED]

**Goal**: Establish the Python project structure, dependencies, configuration management, logging, and a minimal Nextcord bot that connects to Discord and responds to a ping command.

**Tasks**:
- [ ] **Task 1.1**: Create project directory structure at `~/.dotfiles/opencode-discord-bot/` with `src/`, `config/`, `tests/`, and `README.md`
- [ ] **Task 1.2**: Write `requirements.txt` (or `pyproject.toml`) pinning nextcord>=3.1.1 and anyio for structured concurrency
- [ ] **Task 1.3**: Implement `config/settings.py` -- load `DISCORD_BOT_TOKEN` from env, `WHITELISTED_USER_IDS` from env (comma-separated), `OPENCODE_SERVER_URL` (default `http://127.0.0.1:4096`), `OPENCODE_SERVER_PASSWORD` from env
- [ ] **Task 1.4**: Implement `src/logging_config.py` -- structured JSON logger writing to stdout (captured by journald); log levels configurable via `LOG_LEVEL` env var
- [ ] **Task 1.5**: Implement `src/bot.py` -- minimal Nextcord bot with `on_ready` handler that logs bot user info, guild count, and registered commands; add a `/rc ping` command that responds with latency and uptime
- [ ] **Task 1.6**: Verify bot starts, connects to Discord, and `/rc ping` responds correctly

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `~/.dotfiles/opencode-discord-bot/src/__init__.py` - package init (new)
- `~/.dotfiles/opencode-discord-bot/src/bot.py` - main bot entry point (new)
- `~/.dotfiles/opencode-discord-bot/src/logging_config.py` - structured logging (new)
- `~/.dotfiles/opencode-discord-bot/config/settings.py` - configuration (new)
- `~/.dotfiles/opencode-discord-bot/config/example.env` - env var template (new)
- `~/.dotfiles/opencode-discord-bot/requirements.txt` - dependencies (new)

**Verification**:
- Bot starts without errors; logs show successful Discord connection
- `/rc ping` in Discord returns bot latency and uptime
- `DISCORD_BOT_TOKEN` not logged or printed anywhere
- JSON log lines appear in stdout with timestamp, level, message fields

---

### Phase 2: Core `/rc` Slash Commands [NOT STARTED]

**Goal**: Implement all Discord slash commands under the `/rc` group with proper input validation, error handling, and user-facing feedback. Commands should be fully functional end-to-end (returning mock/simulated data before Phase 3 connects to OpenCode).

**Tasks**:
- [ ] **Task 2.1**: Implement command registration structure -- a `commands/` package with `__init__.py` that registers all command cogs; each command group (session, task, system) as a separate cog
- [ ] **Task 2.2**: Implement `src/commands/session_cog.py` -- `/rc session join [session_id]` (accepts optional session ID, lists available if omitted), `/rc session list` (shows all active sessions with status), `/rc session leave` (closes the Discord thread linked to current session)
- [ ] **Task 2.3**: Implement `src/commands/task_cog.py` -- `/rc task status [task_number]` (shows task state from TODO.md/state.json), `/rc task create "description"` (creates a new task), `/rc task research [N]`, `/rc task plan [N]`, `/rc task implement [N]` (trigger respective commands)
- [ ] **Task 2.4**: Implement `src/commands/system_cog.py` -- `/rc status` (system overview: CPU, memory, active sessions, running tasks), `/rc refresh` (triggers orphaned process cleanup via existing `opencode-refresh.sh`)
- [ ] **Task 2.5**: Add authorization check decorator -- before every command, verify `ctx.user.id` is in `WHITELISTED_USER_IDS`; return ephemeral "unauthorized" message for non-whitelisted users
- [ ] **Task 2.6**: Add command-level rate limiting -- max 10 commands per minute per user; configurable via `RATE_LIMIT_PER_MINUTE` env var; use an in-memory sliding window

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `~/.dotfiles/opencode-discord-bot/src/commands/__init__.py` - cog registration (new)
- `~/.dotfiles/opencode-discord-bot/src/commands/session_cog.py` - session commands (new)
- `~/.dotfiles/opencode-discord-bot/src/commands/task_cog.py` - task commands (new)
- `~/.dotfiles/opencode-discord-bot/src/commands/system_cog.py` - system commands (new)
- `~/.dotfiles/opencode-discord-bot/src/auth.py` - whitelist decorator (new)
- `~/.dotfiles/opencode-discord-bot/src/rate_limit.py` - rate limiter (new)
- `~/.dotfiles/opencode-discord-bot/config/settings.py` - add rate limit config (modify)

**Verification**:
- All `/rc` commands appear in Discord with correct names, descriptions, and parameter schemas
- Commands return appropriate ephemeral or channel messages
- Non-whitelisted users receive "unauthorized" messages
- Rate limit exceeded produces a 429-style ephemeral response
- Commands work from iPhone Discord client (slash command autocomplete, mobile-friendly responses)

---

### Phase 3: OpenCode Server Integration [NOT STARTED]

**Goal**: Build the bridge layer that discovers running OpenCode server instances, authenticates via `OPENCODE_SERVER_PASSWORD`, and executes commands via `opencode run --command`. This is the core infrastructure that all `/rc` commands will call.

**Tasks**:
- [ ] **Task 3.1**: Implement `src/opencode/client.py` -- `OpenCodeClient` class that wraps `opencode session list` (to discover active sessions/ports), `opencode run --command <cmd> --format json` (for command execution), and `opencode run <message> --continue --session <id>` (for message relay)
- [ ] **Task 3.2**: Implement server discovery -- parse output of `opencode session list` to find active server URLs and session IDs; cache results with 30-second TTL; support explicit `OPENCODE_SERVER_URL` override for single-server deployments
- [ ] **Task 3.3**: Implement authentication -- set `OPENCODE_SERVER_PASSWORD` env var before `opencode run` calls; handle auth failures with clear error messages; retry once on auth error in case server just restarted
- [ ] **Task 3.4**: Implement `src/opencode/executor.py` -- async subprocess runner for `opencode` CLI with timeout (default 120s), stdout/stderr capture, and JSON output parsing; handle `--format json` streaming for long-running tasks
- [ ] **Task 3.5**: Wire Phase 2 commands to use the client -- replace mock responses in session/task/system cogs with real OpenCode client calls; handle errors gracefully (server down, command timeout, parse failure) with user-friendly Discord messages
- [ ] **Task 3.6**: Add concurrency control -- max 3 concurrent `opencode run` processes; queue additional requests; expose queue depth in `/rc status`

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `~/.dotfiles/opencode-discord-bot/src/opencode/__init__.py` - package init (new)
- `~/.dotfiles/opencode-discord-bot/src/opencode/client.py` - OpenCode client wrapper (new)
- `~/.dotfiles/opencode-discord-bot/src/opencode/executor.py` - subprocess executor (new)
- `~/.dotfiles/opencode-discord-bot/src/commands/session_cog.py` - wire to real client (modify)
- `~/.dotfiles/opencode-discord-bot/src/commands/task_cog.py` - wire to real client (modify)
- `~/.dotfiles/opencode-discord-bot/src/commands/system_cog.py` - wire to real client (modify)
- `~/.dotfiles/opencode-discord-bot/config/settings.py` - add timeout/concurrency config (modify)

**Verification**:
- `OpenCodeClient.list_sessions()` returns correct list of active sessions from `opencode session list`
- `opencode run --command status --format json` executes and returns parsed JSON
- Commands timeout after 120s and return partial results
- Authentication failures produce clear error messages
- Server-down state is handled gracefully (commands return "OpenCode server unavailable")
- Concurrent execution respects the max-3-processes limit

---

### Phase 4: Session-to-Thread Mapping and Message Relay [NOT STARTED]

**Goal**: Build the persistent mapping store that ties OpenCode session IDs to Discord thread IDs, implement the core message relay loop (Discord message -> OpenCode session -> Discord reply), and add the local HTTP API that the Neovim `:OpenCodeLinkDiscord` command will call.

**Tasks**:
- [ ] **Task 4.1**: Implement `src/state/store.py` -- `SessionStore` class backed by a JSON file at `~/.dotfiles/opencode-discord-bot/data/sessions.json`; operations: `link(session_id, thread_id, channel_id)`, `unlink(session_id)`, `lookup_by_session(session_id)`, `lookup_by_thread(thread_id)`, `list_all()`; file is read on startup and written on every mutation with atomic write (write to temp file, then rename)
- [ ] **Task 4.2**: Implement `src/relay.py` -- `MessageRelay` class with `relay_to_openode(thread_id, message_content)` (looks up session by thread, calls `opencode run <message> --continue --session <id>`, returns response) and `relay_to_discord(session_id, response_text)` (looks up thread by session, sends message to that thread via Nextcord)
- [ ] **Task 4.3**: Implement Discord `on_message` handler -- intercept messages in linked threads (check store); ignore bot's own messages; forward content to `relay_to_opencode`; relay response back to thread; add typing indicator while processing
- [ ] **Task 4.4**: Implement the local HTTP API using aiohttp -- `POST /link` (body: `{"session_id": "...", "session_name": "..."}`) creates a Discord thread in a designated channel and stores the mapping; returns thread ID and jump URL; `GET /health` returns bot status and linked session count; `GET /sessions` lists all linked sessions
- [ ] **Task 4.5**: Wire `/rc session join` to use the store -- when user specifies a session ID, create a thread and store the mapping; `/rc session list` shows both linked and unlinked sessions; `/rc session leave` removes mapping and archives thread
- [ ] **Task 4.6**: Add thread lifecycle management -- auto-archive threads when session ends (detected via `opencode session list` no longer showing the session ID); cleanup logic runs every 5 minutes; log archive events

**Timing**: 2 hours

**Depends on**: 2, 3

**Files to modify**:
- `~/.dotfiles/opencode-discord-bot/src/state/__init__.py` - package init (new)
- `~/.dotfiles/opencode-discord-bot/src/state/store.py` - JSON-backed session store (new)
- `~/.dotfiles/opencode-discord-bot/src/relay.py` - message relay logic (new)
- `~/.dotfiles/opencode-discord-bot/src/api.py` - local HTTP API (new)
- `~/.dotfiles/opencode-discord-bot/src/bot.py` - add on_message handler, start HTTP API, startup store load, periodic cleanup (modify)
- `~/.dotfiles/opencode-discord-bot/src/commands/session_cog.py` - wire to store and HTTP API (modify)
- `~/.dotfiles/opencode-discord-bot/data/.gitkeep` - ensure data dir exists (new)

**Verification**:
- Linking a session via the HTTP API creates a Discord thread and stores the mapping
- Sending a message in a linked Discord thread triggers `opencode run` with the stored session ID
- OpenCode response appears in the same Discord thread
- Unlinking a session archives the thread and removes the store entry
- Store survives bot restart (sessions.json is loaded on startup)
- `/rc session list` shows correct linked/unlinked status for all sessions
- HTTP API returns correct health data and session listing

---

### Phase 5: Neovim `:OpenCodeLinkDiscord` Command and `<leader>ar` Keymap [NOT STARTED]

**Goal**: Create the Neovim user command `:OpenCodeLinkDiscord` that discovers the current OpenCode session, calls the bot's HTTP API to link it to a Discord thread, and displays the Discord jump URL to the user. Bind it to `<leader>ar`. Update which-key with the new mapping.

**Tasks**:
- [ ] **Task 5.1**: Determine the current OpenCode session ID within Neovim -- inspect the running `opencode --port` process; extract the port number; use `opencode session list` (filtered to current working directory) to find the matching session ID; handle the case where no session is active
- [ ] **Task 5.2**: Implement `lua/neotex/plugins/ai/opencode/discord-link.lua` -- module with `link_current_session()` function that calls the bot's HTTP `POST /link` endpoint with the session ID, directory name, and optional description; parse the response to get the Discord thread jump URL
- [ ] **Task 5.3**: Register `:OpenCodeLinkDiscord` user command -- `vim.api.nvim_create_user_command("OpenCodeLinkDiscord", ...)` with `{ desc = "Link current OpenCode session to Discord thread" }`; command calls `link_current_session()` and displays the thread URL with a `vim.notify` (level INFO) and copies it to clipboard
- [ ] **Task 5.4**: Add `<leader>ar` keymap -- in `lua/neotex/plugins/ai/opencode.lua`, add to the `keys = {}` table: `{ "<leader>ar", "<cmd>OpenCodeLinkDiscord<CR>", desc = "Link session to Discord" }`; ensure it registers in the `<leader>a` (ai) group in which-key
- [ ] **Task 5.5**: Update `lua/neotex/plugins/editor/which-key.lua` -- add the `<leader>ar` entry in the `<leader>a` group section with `desc = "link discord session"` and `icon = "󰙯"` (Discord icon)
- [ ] **Task 5.6**: Handle error cases -- no active OpenCode session (notify user to start one first), bot HTTP API unreachable (notify user to start the bot), session already linked (notify with existing thread URL), linking fails (show error from API response)

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/discord-link.lua` - link logic (new)
- `lua/neotex/plugins/ai/opencode.lua` - add keymap and command registration (modify)
- `lua/neotex/plugins/editor/which-key.lua` - add `<leader>ar` entry (modify)

**Verification**:
- `:OpenCodeLinkDiscord` in a Neovim instance with an active OpenCode session calls the bot API successfully
- Discord thread URL is displayed in a notification and copied to clipboard
- Pressing `<leader>ar` triggers the same behavior
- `<leader>a` which-key popup shows `ar` with "link discord session" label
- Error messages are clear and actionable for all failure cases
- Running the command when no session is active shows "No active OpenCode session"

---

### Phase 6: Security Hardening, Systemd Service, and Production Readiness [NOT STARTED]

**Goal**: Lock down the bot for production use -- systemd service definition, proper user isolation, token protection, structured journald logging, health checks, startup ordering, and end-to-end testing from iPhone.

**Tasks**:
- [ ] **Task 6.1**: Create `~/.dotfiles/opencode-discord-bot/systemd/opencode-discord-bot.service` -- systemd service file following the pattern from existing `opencode-refresh.service`; Type=simple, EnvironmentFile for secrets, Restart=always, RestartSec=10, After=network-online.target; log to journald via StandardOutput=journal
- [ ] **Task 6.2**: Create `~/.dotfiles/opencode-discord-bot/systemd/opencode-discord-bot.socket` -- optional socket activation for the local HTTP API (so the API is available even before the bot starts); or alternatively, just ensure the bot binds to 127.0.0.1 only
- [ ] **Task 6.3**: Lock down the HTTP API -- bind to `127.0.0.1` only (no external access); add a shared secret token (`LINK_API_TOKEN` env var) that the Neovim command must include in `Authorization: Bearer <token>` header; reject requests without valid token with 401
- [ ] **Task 6.4**: Add health check endpoint enhancements -- `/health` returns JSON with bot uptime, Discord connection status, OpenCode server connectivity, linked session count, active task count, and last error; systemd can use `ExecStartPost` to curl the health endpoint
- [ ] **Task 6.5**: Create `~/.dotfiles/opencode-discord-bot/config/env.production` -- template showing all required env vars (`DISCORD_BOT_TOKEN`, `WHITELISTED_USER_IDS`, `OPENCODE_SERVER_PASSWORD`, `LINK_API_TOKEN`, `LOG_LEVEL=info`); document each variable
- [ ] **Task 6.6**: End-to-end verification -- start OpenCode session in Neovim, run `:OpenCodeLinkDiscord`, open Discord on iPhone, send a message in the thread, verify response appears, test `/rc session list`, `/rc task status`, `/rc status` from iPhone; test error recovery (kill OpenCode server, verify bot handles gracefully)
- [ ] **Task 6.7**: Write `~/.dotfiles/opencode-discord-bot/README.md` -- setup instructions, env var reference, systemd install commands, troubleshooting, and iPhone usage guide

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `~/.dotfiles/opencode-discord-bot/systemd/opencode-discord-bot.service` - service definition (new)
- `~/.dotfiles/opencode-discord-bot/systemd/opencode-discord-bot.socket` - optional socket (new)
- `~/.dotfiles/opencode-discord-bot/src/api.py` - add auth token check, enhance health endpoint (modify)
- `~/.dotfiles/opencode-discord-bot/src/bot.py` - add graceful shutdown, startup health check (modify)
- `~/.dotfiles/opencode-discord-bot/config/env.production` - env var template (new)
- `~/.dotfiles/opencode-discord-bot/README.md` - documentation (new)
- `lua/neotex/plugins/ai/opencode/discord-link.lua` - add auth token to API calls (modify)
- `~/.dotfiles/opencode-discord-bot/config/settings.py` - add LINK_API_TOKEN (modify)

**Verification**:
- `systemctl start opencode-discord-bot` starts the service without errors
- `journalctl -u opencode-discord-bot -f` shows structured JSON log lines
- Bot reconnects to Discord within 10 seconds of Discord API disruption
- HTTP API rejects requests without valid `Authorization: Bearer` header
- Health endpoint returns accurate status including OpenCode server connectivity
- Full end-to-end flow works from iPhone: session linking, message relay, command execution
- Bot survives OpenCode server restart (detects and reconnects)

## Testing & Validation

- [ ] Unit tests for `SessionStore` (link, unlink, lookup, atomic write) using pytest with temp files
- [ ] Unit tests for `OpenCodeClient.list_sessions()` parsing (mock subprocess output)
- [ ] Unit tests for `rate_limit` sliding window logic (fast-forward time in test)
- [ ] Unit tests for `auth` whitelist decorator (authorized and unauthorized paths)
- [ ] Integration test: bot startup, Discord connection, `/rc ping` response
- [ ] Integration test: HTTP API `POST /link` -> Discord thread creation -> store mapping verification
- [ ] Integration test: message relay from Discord thread to OpenCode (with mock server)
- [ ] Manual test: full iPhone end-to-end flow (Neovim link -> Discord thread -> message -> response)
- [ ] Manual test: error recovery scenarios (kill OpenCode, restart bot, verify graceful degradation)
- [ ] Manual test: rate limit enforcement produces correct ephemeral messages

## Artifacts & Outputs

- `~/.dotfiles/opencode-discord-bot/src/bot.py` - main bot entry point
- `~/.dotfiles/opencode-discord-bot/src/commands/` - slash command cogs (session, task, system)
- `~/.dotfiles/opencode-discord-bot/src/opencode/client.py` - OpenCode CLI wrapper
- `~/.dotfiles/opencode-discord-bot/src/opencode/executor.py` - subprocess executor
- `~/.dotfiles/opencode-discord-bot/src/state/store.py` - session-to-thread mapping store
- `~/.dotfiles/opencode-discord-bot/src/relay.py` - message relay logic
- `~/.dotfiles/opencode-discord-bot/src/api.py` - local HTTP API
- `~/.dotfiles/opencode-discord-bot/src/logging_config.py` - structured JSON logging
- `~/.dotfiles/opencode-discord-bot/src/auth.py` - authorization decorator
- `~/.dotfiles/opencode-discord-bot/src/rate_limit.py` - rate limiter
- `~/.dotfiles/opencode-discord-bot/config/settings.py` - configuration
- `~/.dotfiles/opencode-discord-bot/config/env.production` - env var template
- `~/.dotfiles/opencode-discord-bot/config/example.env` - env var template (dev)
- `~/.dotfiles/opencode-discord-bot/systemd/opencode-discord-bot.service` - systemd service
- `~/.dotfiles/opencode-discord-bot/data/sessions.json` - persistent state (runtime)
- `~/.dotfiles/opencode-discord-bot/requirements.txt` - Python dependencies
- `~/.dotfiles/opencode-discord-bot/README.md` - setup and usage guide
- `lua/neotex/plugins/ai/opencode/discord-link.lua` - Neovim link module
- `lua/neotex/plugins/ai/opencode.lua` - updated with command and keymap
- `lua/neotex/plugins/editor/which-key.lua` - updated with `<leader>ar` entry

## Rollback/Contingency

- Stop the bot: `systemctl stop opencode-discord-bot` (no persistent side effects beyond sessions.json, which is safe to delete)
- Remove Neovim integration: delete `discord-link.lua`, revert `opencode.lua` and `which-key.lua` changes from git
- The bot writes only to `~/.dotfiles/opencode-discord-bot/data/sessions.json` and log output (journald); no other filesystem modifications
- Discord threads created by the bot are standard Discord threads; they can be manually archived or deleted in the Discord client
- No database migrations or schema changes -- the JSON file is self-describing
- If the bot is removed, Neovim `:OpenCodeLinkDiscord` will fail with a clear "bot unreachable" error; no cascading failures
