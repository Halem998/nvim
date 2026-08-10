# Research Report: Mobile Agent Management via Discord Bot on NixOS

**Task**: 547 - research_mobile_agent_management
**Started**: 2026-05-07T12:00:00Z
**Completed**: 2026-05-07T17:30:00Z
**Effort**: 5.5 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.opencode/` directory structure, `lua/neotex/plugins/ai/`
- Codebase: OpenCode CLI help output (`opencode serve`, `run`, `session`, `attach`, `web`, `debug`, `agent`)
- Codebase: Systemd service files, hook scripts, skill definitions, orchestration patterns
- Platform: `nixpkgs` package evaluation, `nix eval` for version checks
- Platform: `/etc/nixos/configuration.nix` inspection
- External: PyPI nextcord 3.1.1 project page
**Artifacts**:
  - specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md
**Standards**: report-format.md, return-metadata-file.md, status-markers.md

## Executive Summary

- **Session linking flow**: Start a session in Neovim → trigger `:OpenCodeLinkDiscord` → Discord bot opens a thread bound to that session → continue the conversation from iPhone via Discord. The bot is a thin relay, not an agent -- it forwards text to the existing `opencode serve` backend the Neovim session already uses
- **Zero cost to link**: The Discord bot is a persistent daemon with negligible overhead. Linking sessions costs nothing extra -- only the active conversation consumes LLM tokens, same as if you were typing in Neovim. Having 10 linked sessions costs the same as 1
- **`/rc` slash command group**: Short for "remote code" -- all bot commands live under `/rc` (e.g. `/rc session join`, `/rc task status`) to minimize typing on mobile
- Nextcord 3.1.1 is the best Discord bot library for 2026: actively maintained (Aug 2025 release), slash-command-native, async
- Mosh + Blink Shell on iPhone serves as fallback raw terminal access; Discord bot is the primary mobile interface
- NixOS-specific prerequisites (SSH, Mosh, sops-nix secrets, Pi tooling) are factored out -- handled separately from bot implementation
- Raspberry Pi can run `opencode serve` as a headless agent host, accessed by the bot via `opencode run --attach`

## Context & Scope

This research covers designing a mobile agent management system for an iPhone user on NixOS 26.05 (Yarara). The user wants to manage OpenCode agent sessions via Discord on their iPhone, with future expansion to a Raspberry Pi coding agent. The system scope includes:

- **OpenCode programmability**: Whether current tooling supports headless/CLI invocation
- **Discord bot library**: Best library available in nixpkgs for 2026
- **iPhone remote access**: Mosh + SSH client options
- **Raspberry Pi agent host**: NixOS on Pi for running headless OpenCode
- **Secrets management**: Encrypted storage for Discord tokens and SSH keys
- **Systemd integration**: Service management patterns already in the codebase

The current infrastructure is limited: the NixOS config is essentially stock (no SSH, no secrets management, no remote access), and all agent interaction is via the Neovim TUI. This represents a greenfield project for remote/mobile access.

## Findings

### 1. OpenCode Headless/CLI Capabilities

**Discovery**: OpenCode has extensive headless and CLI support that is far more capable than previously assumed.

**`opencode serve`** -- Persistent headless server:
- Starts a server listening on configurable hostname/port (default 127.0.0.1, random port)
- Supports `--mdns` for mDNS service discovery (broadcasts `opencode.local`)
- Supports `--cors` for cross-origin web access
- Provides basic auth via `OPENCODE_SERVER_PASSWORD` environment variable

**`opencode run`** -- One-shot message/command execution:
- Accepts a message string and executes with full agent capabilities
- `--command` flag runs named commands (e.g., `--command research` for `/research`)
- `--session`/`--continue` for session continuation across runs
- `--fork` to fork sessions before continuing (safe experimentation)
- `--agent` to select specific agent for the task
- `--format json` for machine-parseable JSON event stream output
- `--attach` to connect to a remote OpenCode server (e.g., `http://pi:4096`)
- `--dangerously-skip-permissions` auto-approves permissions (required for unattended operation)
- `--model` for model selection, `--file` for file attachments

**`opencode attach`** -- Remote session connection:
- Connect to any running `opencode serve` instance via URL
- Supports `--continue`, `--session`, `--fork` for session management
- `--dir` to specify working directory on remote

**`opencode web`** -- Web interface:
- Starts server and opens a built-in web UI
- Same options as `serve` with web-specific defaults

**`opencode session`** -- Session management:
- `list` and `delete` subcommands for session lifecycle
- Enables programmatic cleanup and status checking

**`opencode agent`** -- Agent management:
- `create` and `list` subcommands for agent lifecycle

**Available commands** (without slash prefix for `--command` flag):
`init`, `review`, `fix-it`, `implement`, `todo`, `plan`, `meta`, `errors`, `revise`, `refresh`, `merge`, `project-overview`, `spawn`, `tag`, `task`, `learn`, `research`, `distill`

**Current state**: Multiple `opencode --port` processes are running as active Neovim sessions. The `OPENCODE_SERVER_PASSWORD`-based auth model is already present.

**Key architectural insight**: OpenCode uses a client-server model already. The TUI in Neovim connects via `opencode --port`. This same server can be accessed headlessly via `opencode run --attach`, making the Discord-bot-to-agent bridge architecturally clean.

### 2. Discord Bot Library Comparison

**Package availability in nixpkgs (verified)**:

| Library | Package | Version | Status |
|---------|---------|---------|--------|
| **Nextcord** | `python3Packages.nextcord` | 3.1.1 | Active fork of discord.py, Aug 2025 |
| **discord.py** | `python3Packages.discordpy` | 2.6.4 | Original, maintained |
| discord.py (alt) | `python3Packages.discordpy` | 2.6.4 | Same as above |
| agenix | N/A | Not found | Use flake input instead |

**Recommendation: Nextcord 3.1.1**

Nextcord is the best choice for this project because:
1. **Active maintenance**: Last release Aug 2025, supports Python >= 3.12 (matches NixOS 26.05)
2. **Slash command native**: `@bot.slash_command(description="...")` decorator pattern
3. **Full async support**: Built on aiohttp with async/await
4. **Modern features**: Embeds, threads, modals, buttons, select menus
5. **Speed optimizations**: Optional `nextcord[speed]` extras (orjson, aiodns)
6. **Production stable**: Marked "5 - Production/Stable" on PyPI

discord.py 2.6.4 is also available but is less actively maintained and lacks some Nextcord enhancements.

**Bot command structure design**:

```
/rc session join [ID]     -- Join an active session (primary mobile entry point)
/rc session list          -- List active sessions with IDs
/rc session leave         -- Leave current session thread

/rc task status [N]       -- Show status of task(s)
/rc task create "desc"    -- Create new task
/rc task research N       -- Trigger /research on task N
/rc task plan N           -- Trigger /plan on task N
/rc task implement N      -- Trigger /implement on task N

/rc status                -- Overall system status (CPU, sessions, tasks)
/rc refresh               -- Trigger /refresh cleanup
```

**Linking flow**: The user starts a session in Neovim, runs `:OpenCodeLinkDiscord`, and the bot creates a Discord thread bound to that session ID. From iPhone, the user opens that thread and continues the conversation. The bot forwards each Discord message to `opencode serve` and relays the response back. The thread IS the session -- closing the thread archives it.

**Command group name**: Use `/rc` (short for "remote code") for the bot's slash command group to reduce typing on mobile.

### 3. Mosh + iPhone Setup (Fallback Terminal Access)

**iPhone clients**:
- **Blink Shell** (paid, $20): Best-in-class Mosh + SSH client for iOS. Native terminal with full keyboard support. Supports mosh natively with excellent latency handling.
- **Termius** (freemium): Cross-platform SSH/Mosh client. Free tier supports basic SSH; Mosh requires subscription.
- **Shelly** (free): Open-source SSH client, Mosh support via integration.

**Recommendation**: Blink Shell is the gold standard for iPhone Mosh access. Its Mosh integration handles network changes (WiFi->cellular) seamlessly.

**NixOS-specific prerequisites** (handled separately from bot implementation):
- SSH and Mosh server setup (currently disabled on this system)
- Firewall port rules for SSH (22) and Mosh UDP (60000-61000)

### 4. Raspberry Pi Agent Host (Future)

**Architecture for Pi agent host**:
1. Run OpenCode on Pi with minimal OS configuration
2. Run `opencode serve` as a systemd service with `--hostname 0.0.0.0 --port 4096`
3. The Discord bot (on main machine) connects to Pi via `opencode run --attach http://pi:4096`
4. Pi-specific development tasks routed to Pi; research/coordination tasks stay on main machine

**Systemd service template for Pi**:
```ini
[Unit]
Description=OpenCode Agent Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=OPENCODE_SERVER_PASSWORD=<from-secrets>
ExecStart=opencode serve --hostname 0.0.0.0 --port 4096
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Lightweight requirements**:
- OpenCode needs Node.js runtime
- No X11/GUI needed -- headless server mode
- Minimal RAM footprint when idle; spikes when processing
- Pi 4 with 4GB+ RAM recommended, Pi 5 ideal

**NixOS-specific prerequisites** (handled separately):
- `nixos-hardware` for Pi-specific kernel/firmware, `sd-image` builders for bootable images, cross-compilation from x86_64 to aarch64

### 5. Security Considerations

**Secrets management**:
- Discord bot token must be stored encrypted, never hardcoded
- OpenCode server password for `OPENCODE_SERVER_PASSWORD` auth
- Recommended approach: sops for encrypting secret files (3.12.2)

**NixOS-specific prerequisites** (handled separately):
- sops-nix integration for NixOS secrets management (`.sops.yaml` with age keys, systemd `LoadCredential`)

**Discord bot token management**:
- Store token encrypted; inject into systemd service via environment or credential path
- NEVER hardcode tokens in bot source

**Permission scoping**:
- Discord commands should require explicit user authorization
- Whitelist of Discord user IDs allowed to invoke agent commands
- `/rc task implement N` should require confirmation for destructive operations
- The `--dangerously-skip-permissions` flag should only be used for automated, scoped tasks

**Rate limiting**:
- Discord has built-in rate limits (50 requests/second for most endpoints)
- Nextcord handles rate limiting automatically
- Additional application-level rate limits recommended for agent commands (max N concurrent tasks)

**Network security**:
- OpenCode serve should use `127.0.0.1` locally, not `0.0.0.0` unless behind firewall
- Pi-to-main communication over Tailscale/WireGuard recommended
- Mosh uses SSH for authentication, then UDP for session data (encrypted)

### 6. Existing Infrastructure Inventory

**Systemd services** (already defined at `.opencode/systemd/`):
- `claude-refresh.service` + `claude-refresh.timer` -- Periodic orphaned process cleanup
- `opencode-refresh.service` + `opencode-refresh.timer` -- OpenCode-specific cleanup
- Both are oneshot services with timer activation

**Hook scripts** (`.opencode/hooks/`):
- `post-command.sh` -- Logs session end
- `log-session.sh` -- Logs session start
- `subagent-postflight.sh` -- Prevents premature workflow termination (loop guard)
- `tts-notify.sh` -- TTS notifications
- `wezterm-*.sh` -- WezTerm integration hooks (task number, notifications, clear)

**Plugin system** (`wezterm-hooks.js`):
- Event-based hook architecture: `session.idle`, `session.status`, `permission.asked`, `question.asked`, `command.execute.before`
- Same event model can be extended for Discord notifications

**Scripts** (`.opencode/scripts/`):
- `postflight-research.sh` -- Updates state.json after research (pattern reference)
- `opencode-refresh.sh` -- Process cleanup with safety measures
- `execute-command.sh` -- Command routing for slash commands
- Multiple validation scripts (`validate-*.sh`)

**Key insight**: The existing systemd timer pattern (`claude-refresh.timer`) provides a proven template for adding new services (Discord bot, OpenCode serve). The hook architecture shows how to wire notification side effects.

## Decisions

1. **Discord bot library**: Use Nextcord 3.1.1 over discord.py for its active maintenance (Aug 2025 release), slash command support, and async design

2. **Agent invocation pattern**: Use `opencode run --command <cmd> --attach <server> --dangerously-skip-permissions --format json` for Discord bot to agent communication. The Discord bot is a thin relay -- it forwards text between Discord threads and the OpenCode server, consuming zero additional LLM tokens beyond what the active session would use anyway

3. **Command group name**: Use `/rc` (short for "remote code") for the bot's Discord slash command group to minimize typing on mobile

4. **Session linking trigger**: Create a Neovim `:OpenCodeLinkDiscord` command as the primary user-facing entry point. It notifies the Discord bot (via HTTP to the bot's local API or a unix socket) to open a Discord thread bound to the current OpenCode session. From that point, the user continues the session conversation from Discord on iPhone. This automates the manual "note session ID, switch to Discord, type `/rc session join`" flow

5. **iPhone access**: Discord bot is the primary agent management interface; Discord threads map 1:1 to OpenCode sessions. Mosh + Blink Shell is the fallback for raw terminal access when needed

6. **Pi architecture**: Run Pi as a headless `opencode serve` host, accessed via Discord bot commands that use `opencode run --attach` for task routing

7. **Phased implementation**: Phase 1: Discord bot + `:OpenCodeLinkDiscord` command + `opencode serve` systemd service on main machine. Phase 2: Mosh + SSH for fallback terminal access. Phase 3: Raspberry Pi agent host (future)

8. **NixOS prerequisites factored out**: SSH, Mosh, firewall rules, sops-nix secrets management, and Pi-specific NixOS tooling are all handled as separate NixOS system configuration tasks, not part of the bot implementation

## Recommendations

### Bot Implementation (primary focus)

1. **Create Discord bot Python application** (priority: high): Write the bot using Nextcord with `/rc` slash commands mapped to `opencode run` invocations

2. **Add `:OpenCodeLinkDiscord` Neovim command** (priority: high): Create a Neovim command in `lua/neotex/plugins/ai/` that notifies the Discord bot (via local HTTP or unix socket) to open a Discord thread for the current OpenCode session

3. **Wire bot to OpenCode server** (priority: high): The bot needs to discover running `opencode serve` instances, authenticate via `OPENCODE_SERVER_PASSWORD`, and relay messages between Discord threads and the OpenCode session API

4. **Test end-to-end iPhone flow** (priority: medium): Start session in Neovim, run `:OpenCodeLinkDiscord`, open Discord on iPhone, verify conversation relay works

### NixOS Prerequisites (handled separately)

5. **Enable SSH and Mosh** (priority: deferred): SSH server, Mosh package, firewall ports (22 TCP, 60000-61000 UDP) -- needed before Phase 2 fallback terminal access

6. **Set up secrets management** (priority: deferred): sops-nix for Discord bot token and OpenCode server password encryption -- needed before bot deployment

7. **Pi deployment** (priority: low, future): `nixos-hardware` configuration, `sd-image` build, network topology (Tailscale/WireGuard)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `opencode run --command` doesn't work for complex workflows | Medium | High | Test with simple commands first; fallback to raw message strings with agent routing |
| Discord bot token exposure | Low | Critical | Use sops-nix + restricted Unix permissions (0600); never log tokens |
| OpenCode server crashes leave orphaned state | Medium | Medium | Leverage existing `opencode-refresh.service` timer; add health checks |
| iPhone connectivity unreliable | Medium | Medium | Mosh handles intermittent connections; Discord bot is the primary interface |
| Pi has insufficient resources for OpenCode | Medium | Low | Start with Pi 4 (4GB); monitor with htop; fallback to main machine only |

## Context Extension Recommendations

This is a meta task; the Context Extension Recommendations section is omitted per report format standards.

## Appendix

### A. OpenCode CLI Subcommands (verified on system)

```
opencode serve     -- Headless server (port, hostname, mDNS, CORS, auth)
opencode run       -- One-shot execution (--command, --session, --attach, --agent, --model, --format json)
opencode attach    -- Connect to remote server (URL, --continue, --session, --fork)
opencode web       -- Server + web UI
opencode session   -- List/delete sessions
opencode agent     -- Create/list agents
opencode debug     -- Show config, LSP, skills, agents, paths, startup timing
opencode providers -- Manage AI credentials
opencode models    -- List available models
opencode plugin    -- Install npm plugins
```

### B. Available Models (configured on system)
```
opencode/big-pickle
opencode/claude-haiku-4-5
opencode/claude-opus-4-1 through claude-opus-4-7
opencode/claude-sonnet-4 through claude-sonnet-4-6
opencode/gemini-3-flash
```

### C. Nixpkgs Package Summary
```
python3Packages.nextcord  -- 3.1.1
python3Packages.discordpy -- 2.6.4
mosh                      -- 1.4.0
sops                      -- 3.12.2
agenix                    -- NOT in nixpkgs (use flake input)
discord                   -- Discord client (unfree license)
```

### D. NixOS System State
- **Version**: 26.05.20260430.15f4ee4 (Yarara)
- **Desktop**: GNOME with GDM
- **SSH**: Disabled (commented out)
- **Firewall**: Default (no custom port rules)
- **Secrets**: No sops/agenix configured
- **OpenCode processes**: Multiple active TUI sessions via `opencode --port`
