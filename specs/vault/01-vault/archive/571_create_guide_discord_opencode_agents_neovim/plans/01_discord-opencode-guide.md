# Implementation Plan: Discord OpenCode Agents Guide

- **Task**: 571 - Create guide for using Discord to manage OpenCode agents from Neovim
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_discord-opencode-guide.md, reports/02_link-api-token-setup.md
- **Artifacts**: plans/01_discord-opencode-guide.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Create a comprehensive workflow guide documenting how to use Discord to manage OpenCode agents from within Neovim. The guide targets an everyday user who already has the NixOS infrastructure running (services deployed, sops-nix secrets configured). It covers the per-session dynamic architecture (Neovim TUI -> Discord bot -> per-session OpenCode server), the Neovim keybindings for linking and managing sessions, the environment variable requirements (secured via sops-nix), service management commands, and known issues with troubleshooting steps. The definition of done is a single complete guide file at `.opencode/docs/guides/discord-opencode-agents.md` and an updated `guides/README.md`.

### Research Integration

Two research reports inform this plan:

1. **reports/01_discord-opencode-guide.md** -- Primary research covering the initial system architecture, Neovim plugin implementations (`discord-link.lua`, `discord-session-picker.lua`), bot HTTP API endpoints, the everyday workflow pattern, environment variable requirements, and known issues (heartbeat blocking, LINK_API_TOKEN quirk, session discovery).

2. **reports/02_link-api-token-setup.md** -- Documents the completed sops-nix wiring of `link_api_token` through the full pipeline: `secrets.yaml` -> sops-nix decryption -> `/run/secrets/link_api_token` -> both the discord-bot service (via LoadCredential) and fish shell init (for Neovim). This supersedes the "empty token" issue described in report 01.

### Corrections from Debug Sessions (post-research)

Eight bugs were discovered and fixed during bring-up; the guide must reflect the corrected state:

1. **`setup_hook` never called**: This version of nextcord does not implement `setup_hook()`, so the HTTP API server (port 8080) was silently never started. Fixed by overriding `start()` in `bot.py`. Symptom: `ss -tlnp | grep 8080` shows nothing despite the service being "active".

2. **`link_api_token` loaded as file path**: `config.py` used `os.environ.get("LINK_API_TOKEN")` instead of `read_credential()`, so the bot compared the Bearer token against the credential file path string, not its contents. Fixed in `config.py`. Auth IS enforced -- `DISCORD_BOT_LINK_TOKEN` must match the sops secret exactly, not "any non-empty string".

3. **`DISCORD_CHANNEL_ID` loaded as file path**: Same bug -- `config.py` tried to `int()` the file path, failed, and defaulted to 0. Fixed in `config.py`. The channel must also be a **TextChannel** (not VoiceChannel); threads cannot be created in voice channels.

4. **Credential files require service restart**: After `sudo nixos-rebuild switch`, the `/run/credentials/discord-bot.service/*` files are only updated when the service restarts. `nixos-rebuild` alone is not sufficient.

5. **opencode-serve password mismatch**: `OPENCODE_SERVER_PASSWORD=%d/opencode_server_password` set the env var to the credential file PATH, but OpenCode used it as the literal password. Fixed with a bash wrapper: `OPENCODE_SERVER_PASSWORD=$(cat %d/opencode_server_password) exec opencode serve ...`

6. **Missing default_agent**: `config/opencode.json` had `"default_agent": "logos-coder"` referencing a non-existent agent, causing all messages to fail silently with no SSE response events. Fixed by removing the `default_agent` setting so OpenCode uses its built-in default.

7. **Missing OLLAMA_API_KEY**: The LLM provider (Ollama) returned 401 because the API key was not available in the service environment. Fixed by adding `ollama_api_key` to sops secrets and injecting via LoadCredential + the same bash wrapper pattern.

8. **Heartbeat blocking**: The bot's synchronous POST to `POST /session/{id}/message` blocked the asyncio event loop for minutes during long AI operations (e.g., `/implement`), starving the Discord gateway heartbeat. Fixed by running `send_message` in a `ThreadPoolExecutor` via `loop.run_in_executor()`, completely decoupling it from the event loop.

### Architecture Revision (post-research)

The original plan assumed a fixed three-tier architecture: Neovim -> Discord bot -> single headless `opencode-serve` on port 4096. This was replaced during debugging with a **per-session dynamic architecture**:

- **Neovim TUI** runs `opencode --port` (standalone), which starts an embedded HTTP server on a dynamic port. Each Neovim instance (per project directory) gets its own OpenCode server.
- **Discord bot** (`discord-bot.service`) runs on port 8080. When a session is linked, the bot stores the TUI's `server_url` alongside the session ID. For relaying messages, the bot creates a per-URL `OpenCodeClient` instance that connects directly to the TUI's embedded server.
- **Headless server** (`opencode-serve.service` on port 4096) still exists for direct API access and fallback, but is **not required** for the Discord relay. The headless server is locked to its `WorkingDirectory` and cannot serve sessions for other project directories.
- **TUI instances do not require auth**. The bot creates no-auth HTTP clients for TUI ports. The headless server on port 4096 uses password auth via `OPENCODE_SERVER_PASSWORD`.
- **`discord-link.lua`** was rewritten to discover the TUI's port dynamically (via `ss -tlnp`), query the TUI's API (`GET /session`, `GET /session/status`), and present a Telescope picker with preview pane showing session metadata. Active/busy sessions are tagged `[active]` and sorted first. The `server_url` is passed to the bot's `POST /link` endpoint.
- **`opencode_client.py`** was rewritten so `send_message` runs in a `ThreadPoolExecutor` (via `urllib.request`), never blocking the asyncio event loop.
- **`store.py`** session entries now include a `server_url` field.
- **`api.py`** `/link` endpoint accepts `server_url` from Neovim.
- **`bot.py`** maintains a dict of per-URL clients via `_get_client_for_url()` and runs relays as background tasks via `asyncio.create_task`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any items in ROADMAP.md. It is a standalone documentation task for the Discord/OpenCode integration workflow.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Write a complete, self-contained guide for the everyday Discord + OpenCode + Neovim workflow
- Document the per-session dynamic architecture at a level sufficient for troubleshooting
- Cover prerequisites, quick-start steps, detailed workflow, keybinding reference, and troubleshooting
- Follow the existing guide conventions (matching `tts-stt-integration.md` style)
- Update `guides/README.md` to list the new guide

**Non-Goals**:
- Do not duplicate the NixOS infrastructure setup (that lives in `~/.dotfiles/docs/discord-bot.md`)
- Do not document OpenCode server internals beyond what the user needs for troubleshooting
- Do not modify any Lua plugin code or NixOS configuration
- Do not create separate guides for setup vs. usage -- one integrated document

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Guide becomes stale as bot evolves | M | M | Include "last verified" date and reference canonical source files |
| Dynamic port discovery changes (ss output format, process naming) | L | M | Document the discovery mechanism so users can debug manually |
| Token setup changes (sops-nix path or fish init location) | L | L | Reference `configuration.nix` as the source of truth rather than hardcoding paths |
| TUI server port changes between Neovim restarts | L | H | Explain that re-linking (`<leader>ar`) is needed after restarting Neovim/OpenCode |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Write the Guide Document [NOT STARTED]

**Goal**: Create the complete guide file at `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md`.

**Tasks**:
- [ ] Create file with title and introductory overview (what the integration does, target audience: everyday users with running infrastructure)
- [ ] Write **Architecture** section with text-based diagram showing the per-session dynamic model:
  ```
  Neovim (opencode --port :NNNNN) --[HTTP]--> discord-bot.service (:8080) --[HTTP]--> OpenCode TUI server (:NNNNN)
                                                      |
                                                      v
                                               Discord Gateway --> Mobile/Desktop
  ```
  - Explain that each Neovim instance runs its own OpenCode server on a dynamic port
  - The bot stores the `server_url` per linked session and routes messages to the correct instance
  - The headless `opencode-serve` on port 4096 exists for direct API use but is not part of the relay path
  - TUI instances do not require auth; the headless server does
- [ ] Write **Prerequisites** section covering:
  - `discord-bot.service` running (required)
  - `opencode-serve.service` running (optional; not needed for the TUI relay workflow)
  - sops-nix secrets configured: `discord_bot_token`, `opencode_server_password`, `discord_channel_id`, `link_api_token`, `ollama_api_key`
  - `DISCORD_BOT_LINK_TOKEN` set via fish shell init from `/run/secrets/link_api_token`
  - Discord app (mobile or desktop) with access to the configured channel
  - Reference `~/.dotfiles/docs/discord-bot.md` for initial NixOS setup
- [ ] Write **Quick Start** section (4-step):
  1. Open Neovim in your project directory
  2. Toggle OpenCode TUI (starts `opencode --port` on a dynamic port)
  3. Type a message to create a session (sessions are not created until first interaction)
  4. `<leader>ar` to link the session to Discord -- select it from the picker, thread URL is copied to clipboard
- [ ] Write **Everyday Workflow** section with detailed steps:
  - Starting an OpenCode session from Neovim (toggle TUI, type first message)
  - Linking to Discord with `<leader>ar`: discovers TUI port via `ss`, queries API for sessions, shows Telescope picker with preview (title, ID, directory, status, age, file changes), active sessions tagged `[active]` and sorted first, capped at 20 most recent
  - Monitoring from Discord mobile (responses appear in the linked thread)
  - Sending instructions from Discord mobile (typed in thread, relayed by bot to the TUI's server, response posted back)
  - Managing sessions with `<leader>as` (Telescope picker: `<CR>` kills, `<C-o>` copies URL)
  - Re-linking after Neovim restart: the TUI port changes on restart, so `<leader>ar` must be run again for the new session
- [ ] Write **Keybinding Reference** table (`<leader>ar`, `<leader>as`, Telescope picker actions)
- [ ] Write **Bot HTTP API Reference** section with endpoint table and example curl commands:
  - `POST /link` -- now accepts `server_url` parameter alongside `session_id` and `session_name`
  - `GET /sessions` -- lists all linked sessions (includes `server_url` field)
  - `POST /kill` -- abort and unlink a session
  - `GET /health` -- health check
- [ ] Write **Environment Variables** section covering:
  - `DISCORD_BOT_LINK_TOKEN`: set automatically by fish shell init from `/run/secrets/link_api_token`; must exactly match the bot's `link_api_token` secret
  - `DISCORD_BOT_URL`: optional, defaults to `http://localhost:8080`
  - `OPENCODE_SERVER_URL`: optional, defaults to `http://127.0.0.1:4096` (used by bot for fallback health check)
  - Bot-side variables managed by systemd via LoadCredential (not user-set): `DISCORD_BOT_TOKEN`, `OPENCODE_SERVER_PASSWORD`, `DISCORD_CHANNEL_ID`, `LINK_API_TOKEN`, `OLLAMA_API_KEY` -- all read via `read_credential()` in `config.py`; the `opencode-serve` service reads `OPENCODE_SERVER_PASSWORD` and `OLLAMA_API_KEY` from credential files via a bash wrapper
- [ ] Write **Service Management** section with systemctl commands (status, restart, logs via journalctl)
- [ ] Write **Troubleshooting** section covering:
  - Port 8080 not listening: restart `discord-bot.service`
  - No response in Discord after sending a message: check `journalctl -u discord-bot` for relay errors; verify the TUI is still running (port may have changed if Neovim was restarted -- re-link with `<leader>ar`)
  - `DISCORD_BOT_LINK_TOKEN mismatch` error: token must exactly match the sops `link_api_token` secret; verify with `echo $DISCORD_BOT_LINK_TOKEN` vs `cat /run/secrets/link_api_token`
  - `DISCORD_BOT_LINK_TOKEN not set` error: Neovim was launched from a shell that did not source fish init; open a new fish terminal and launch Neovim from there
  - `No OpenCode TUI found` when running `<leader>ar`: OpenCode TUI is not running -- toggle it first
  - `No sessions found` in picker: sessions are not created until you type a message in the TUI
  - Session linked but messages fail: the TUI may have been restarted (port changed); re-link with `<leader>ar`
  - OpenCode returns empty response: check that `default_agent` is not set to a non-existent agent in `opencode.json`; check that the LLM provider API key is configured
  - Heartbeat warnings in `journalctl -u discord-bot`: these are normal during long AI operations and do not indicate a problem; the thread pool executor prevents them from blocking the bot
  - Credential files stale after rebuild: `sudo systemctl restart discord-bot` (nixos-rebuild alone does not update running credentials)
- [ ] Write **Security Model** section (brief: sops-nix pipeline, no plaintext tokens, RAM-only tmpfs; TUI instances on localhost do not use auth)
- [ ] Write **Related Resources** section with links to `discord-bot.md`, plugin source files, bot source code
- [ ] Review full document for accuracy against research reports and the post-debug corrections

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - Create new guide file

**Verification**:
- Guide file exists at the expected path
- All sections listed above are present
- Architecture diagram reflects the per-session dynamic model (not the old three-tier model)
- Keybinding table matches the actual plugin implementations
- Troubleshooting covers all 8 known issues from the debug sessions
- No duplicated NixOS setup content (references `discord-bot.md` instead)

---

### Phase 2: Update Guides README [NOT STARTED]

**Goal**: Add the new guide to the `guides/README.md` index so it is discoverable.

**Tasks**:
- [ ] Add a new subsection or entry under an appropriate category in `guides/README.md`
- [ ] Use category "Mobile/Remote Access" or "Integrations" (whichever fits best with existing structure)
- [ ] Entry format: `discord-opencode-agents.md` with a short description

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/guides/README.md` - Add guide listing

**Verification**:
- README.md contains the new guide entry
- Entry description accurately reflects guide content
- Category placement is logical within the existing structure

## Testing & Validation

- [ ] Guide file exists at `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md`
- [ ] All required sections are present (Architecture, Prerequisites, Quick Start, Everyday Workflow, Keybinding Reference, API Reference, Environment Variables, Service Management, Troubleshooting, Security Model, Related Resources)
- [ ] Architecture section documents the per-session dynamic model with TUI port discovery
- [ ] `guides/README.md` includes the new guide entry
- [ ] No broken cross-references or dead links
- [ ] Token setup information reflects the corrected state: auth IS enforced, `DISCORD_BOT_LINK_TOKEN` must match the sops `link_api_token` secret, fish sets it automatically
- [ ] Troubleshooting covers all 8 corrections from the debug sessions
- [ ] Guide follows existing conventions from `tts-stt-integration.md` (markdown structure, table formats, code block style)

## Artifacts & Outputs

- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - The workflow guide
- `/home/benjamin/.config/nvim/.opencode/docs/guides/README.md` - Updated index

## Rollback/Contingency

This is a documentation-only task with no code changes. Rollback is trivial:
- Delete the guide file: `rm .opencode/docs/guides/discord-opencode-agents.md`
- Revert the README.md edit via git: `git checkout -- .opencode/docs/guides/README.md`
