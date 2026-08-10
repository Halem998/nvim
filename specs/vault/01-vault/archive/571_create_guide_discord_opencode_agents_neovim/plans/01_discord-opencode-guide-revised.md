# Implementation Plan: Discord OpenCode Agents Guide (Revised)

- **Task**: 571 - Create guide for using Discord to manage OpenCode agents from Neovim
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_discord-opencode-guide.md, reports/02_guide-additions.md
- **Artifacts**: plans/01_discord-opencode-guide-revised.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Create a comprehensive workflow guide documenting how to use Discord to manage OpenCode agents from within Neovim. This revised plan incorporates significant post-571 research findings: the relay architecture changed to a fully async single-path SSE subscriber with auto-reconnection, progress embeds were added for long-running tasks, the session picker was fixed with explicit port 3000 and idempotent startup, and several new troubleshooting scenarios were discovered. The guide targets an everyday user who already has the NixOS infrastructure running. The definition of done is a single complete guide file at `.opencode/docs/guides/discord-opencode-agents.md` and an updated `guides/README.md`.

### Research Integration

Two research reports inform this plan:

1. **reports/01_discord-opencode-guide.md** -- Primary research covering the initial system architecture, Neovim plugin implementations (`discord-link.lua`, `discord-session-picker.lua`), bot HTTP API endpoints, the everyday workflow pattern, environment variable requirements, and known issues.

2. **reports/02_guide-additions.md** -- Follow-up research from tasks 572, 574-577 documenting critical corrections and new content: async SSE relay replacing ThreadPoolExecutor, progress embed behavior, bidirectional relay with auto-reconnection, explicit port 3000, session picker fixes, CWD inheritance, extension reload drift, and five new troubleshooting entries.

### Corrections from Post-571 Research (Critical)

The following items from the original plan must be corrected:

1. **Architecture section**: Replace dual-path ThreadPoolExecutor model with single-path SSE subscriber using native async `aiohttp`. Remove all references to `ThreadPoolExecutor` and `_send_message_sync`. Add SSE auto-reconnection with exponential backoff.

2. **Troubleshooting -- Heartbeat warnings**: The original text stating "heartbeat warnings are normal" is factually wrong. The fully async relay eliminates heartbeat blocking entirely. Must state that heartbeat warnings indicate an outdated bot version.

3. **Quick Start step 2**: Update from "dynamic port" to "explicit port 3000" (`opencode --port 3000`).

4. **Port discovery in `<leader>ar` workflow**: The `discord-link.lua` workflow now uses the explicit configured port rather than dynamic `ss` discovery.

### Prior Plan Reference

The original plan (`plans/01_discord-opencode-guide.md`) established the document structure with 10 sections (Architecture through Related Resources) and a 2-phase implementation. The structure remains valid, but content corrections and additions are required throughout. Effort estimate is increased from 1.5 to 2.5 hours to account for the expanded scope.

### Roadmap Alignment

This task does not directly advance any items in ROADMAP.md. It is a standalone documentation task for the Discord/OpenCode integration workflow.

## Goals & Non-Goals

**Goals**:
- Write a complete, self-contained guide for the everyday Discord + OpenCode + Neovim workflow
- Document the single-path SSE subscriber architecture with auto-reconnection
- Cover the corrected quick-start steps (explicit port 3000, session picker workflow)
- Document progress embed behavior and bidirectional relay as user-visible features
- Include all 13 troubleshooting entries (8 original + 5 new)
- Follow the existing guide conventions (matching `tts-stt-integration.md` style)
- Update `guides/README.md` to list the new guide

**Non-Goals**:
- Do not duplicate the NixOS infrastructure setup (that lives in `~/.dotfiles/docs/discord-bot.md`)
- Do not document OpenCode server internals beyond what the user needs for troubleshooting
- Do not modify any Lua plugin code or NixOS configuration
- Do not create separate guides for setup vs. usage -- one integrated document
- Do not document task 572 (command routing in child projects) or task 574 (temp file conventions) findings

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Guide becomes stale as bot evolves | M | M | Include "last verified" date and reference canonical source files |
| Users confused by explicit port 3000 if they customized it | L | L | Document that 3000 is the default; users with custom ports should substitute their value |
| Output directory explanation causes more confusion than clarity | L | L | Keep it brief -- one sentence explaining `<leader>x` triggers session export |
| Extension reload warning discourages legitimate use of `<leader>al` | L | L | Frame it positively: "Use `.syncprotect` to preserve customizations during reloads" |
| TUI server port changes between Neovim restarts | L | H | Explain that re-linking (`<leader>ar`) is needed after restarting Neovim/OpenCode |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Write Core Workflow Sections [COMPLETED]

**Goal**: Draft the Architecture, Prerequisites, Quick Start, Everyday Workflow, Keybinding Reference, and Bot HTTP API Reference sections.

**Tasks**:
- [ ] **Task 1.1**: Create file with title and introductory overview (what the integration does, target audience: everyday users with running infrastructure)
- [ ] **Task 1.2**: Write **Architecture** section with text-based diagram showing the single-path SSE subscriber model:
  ```
  Neovim (opencode --port 3000) --[SSE]--> discord-bot.service (:8080) --[Discord Gateway]--> Mobile/Desktop
  ```
  - Explain that the bot subscribes to the TUI's SSE event stream using native async `aiohttp`
  - Messages typed in Discord are relayed to the TUI via `POST /session/{id}/message`
  - Responses flow back through the same SSE connection; no ThreadPoolExecutor is used
  - The SSE subscriber auto-reconnects with exponential backoff (2s to 60s) if the TUI restarts
  - The headless `opencode-serve` on port 4096 exists for direct API use but is not part of the relay path
  - TUI instances do not require auth; the headless server does
- [ ] **Task 1.3**: Write **Prerequisites** section covering:
  - `discord-bot.service` running (required)
  - `opencode-serve.service` running (optional; not needed for the TUI relay workflow)
  - sops-nix secrets configured: `discord_bot_token`, `opencode_server_password`, `discord_channel_id`, `link_api_token`, `ollama_api_key`
  - `DISCORD_BOT_LINK_TOKEN` set via fish shell init from `/run/secrets/link_api_token`
  - Discord app (mobile or desktop) with access to the configured channel
  - Reference `~/.dotfiles/docs/discord-bot.md` for initial NixOS setup
- [ ] **Task 1.4**: Write **Quick Start** section (5-step):
  1. Open Neovim in your project directory
  2. Press `<C-CR>` to open the AI tool picker, select OpenCode, choose "Create new session" (starts `opencode --port 3000` on the configured port)
  3. Type a message in the TUI to create a session (sessions are not created until first interaction)
  4. `<leader>ar` to link the session to Discord -- thread URL is copied to clipboard
  5. Open Discord mobile and navigate to the thread to monitor and send messages
- [ ] **Task 1.5**: Write **Everyday Workflow** section with detailed steps:
  - Starting an OpenCode session from Neovim (`<C-CR>` picker: create new, restore last, browse all)
  - Linking to Discord with `<leader>ar`: queries the TUI's API for sessions, shows Telescope picker with preview (title, ID, directory, status, age, file changes), active sessions tagged `[active]` and sorted first, capped at 20 most recent
  - Monitoring from Discord mobile: responses appear in the linked thread; progress embeds appear for long tasks
  - Sending instructions from Discord mobile (typed in thread, relayed by bot to the TUI, response posted back)
  - Bidirectional relay: messages typed in the TUI also appear in Discord
  - Managing sessions with `<leader>as` (Telescope picker: `<CR>` kills, `<C-o>` copies URL)
  - Re-linking after Neovim restart: the TUI port may change on restart, so `<leader>ar` must be run again
  - Progress embed behavior: short exchanges (<10s) post text directly; long tasks (>10s) show yellow "Processing..." embed, updates every ~15s, turns green on completion
- [ ] **Task 1.6**: Write **Keybinding Reference** table (`<leader>ar`, `<leader>as`, `<C-CR>`, Telescope picker actions)
- [ ] **Task 1.7**: Write **Bot HTTP API Reference** section with endpoint table and example curl commands:
  - `POST /link` -- accepts `session_id` and `session_name`
  - `GET /sessions` -- lists all linked sessions
  - `POST /kill` -- abort and unlink a session
  - `GET /health` -- health check

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - Create new guide file

**Verification**:
- All sections listed above are present
- Architecture diagram shows single-path SSE delivery (no ThreadPoolExecutor references)
- Quick Start references `<C-CR>` session picker and explicit port 3000
- Everyday Workflow documents bidirectional relay and progress embeds
- Keybinding table includes `<C-CR>`

---

### Phase 2: Write Reference and Troubleshooting Sections [COMPLETED]

**Goal**: Draft the Environment Variables, Service Management, Troubleshooting, Security Model, and Related Resources sections.

**Tasks**:
- [ ] **Task 2.1**: Write **Environment Variables** section covering:
  - `DISCORD_BOT_LINK_TOKEN`: set automatically by fish shell init from `/run/secrets/link_api_token`; must exactly match the bot's `link_api_token` secret
  - `DISCORD_BOT_URL`: optional, defaults to `http://localhost:8080`
  - `OPENCODE_SERVER_PORT=3000`: the default port the TUI binds to (document as default, customizable)
  - `OPENCODE_SERVER_URL`: optional, defaults to `http://127.0.0.1:4096` (used by bot for fallback health check)
  - Bot-side variables managed by systemd via LoadCredential (not user-set): `DISCORD_BOT_TOKEN`, `OPENCODE_SERVER_PASSWORD`, `DISCORD_CHANNEL_ID`, `LINK_API_TOKEN`, `OLLAMA_API_KEY`
- [ ] **Task 2.2**: Write **Service Management** section with systemctl commands (status, restart, logs via journalctl). Include note that `systemctl restart discord-bot` is required after updating bot source code (not just `nixos-rebuild switch`).
- [ ] **Task 2.3**: Write **Troubleshooting** section covering all 13 entries:
  - Port 8080 not listening: restart `discord-bot.service`
  - No response in Discord after sending a message: check `journalctl -u discord-bot` for relay errors; verify the TUI is still running on port 3000
  - `DISCORD_BOT_LINK_TOKEN mismatch` error: token must exactly match the sops `link_api_token` secret; verify with `echo $DISCORD_BOT_LINK_TOKEN` vs `cat /run/secrets/link_api_token`
  - `DISCORD_BOT_LINK_TOKEN not set` error: Neovim was launched from a shell that did not source fish init; open a new fish terminal and launch Neovim from there
  - `No OpenCode TUI found` when running `<leader>ar`: OpenCode TUI is not running -- toggle it first
  - `No sessions found` in picker: sessions are not created until you type a message in the TUI
  - Session linked but messages fail: the TUI may have been restarted; re-link with `<leader>ar`
  - OpenCode returns empty response: check that `default_agent` is not set to a non-existent agent in `opencode.json`; check that the LLM provider API key is configured
  - **(CORRECTED)** Heartbeat warnings in `journalctl -u discord-bot`: With the current fully async relay, heartbeat blocking should no longer occur. If you see heartbeat warnings, the bot may be running an outdated version -- restart `discord-bot.service` and verify `opencode_client.py` uses native `aiohttp` (not `urllib.request` in a `ThreadPoolExecutor`)
  - Credential files stale after rebuild: `sudo systemctl restart discord-bot` (`nixos-rebuild` alone does not update running credentials)
  - **(NEW)** "Responses stop appearing in Discord": TUI was restarted (port changed) or SSE subscriber lost connection. Fix: check `journalctl -u discord-bot` for reconnection logs, re-link with `<leader>ar` if port changed
  - **(NEW)** "No progress embed for a long task": SSE subscriber failed to connect. Fix: check `journalctl -u discord-bot`, verify TUI running on port 3000
  - **(NEW)** "Restore last session shows (none yet)": Session ID not captured from `session.idle` event, or session never went idle. Fix: use "Browse all sessions", wait for session to go idle after creating it
  - **(NEW)** "OpenCode runs in wrong project directory": OpenCode inherits Neovim's CWD via snacks.terminal. Fix: ensure `:pwd` matches intended project before toggling TUI
  - **(NEW)** "Commands revert after extension reload": `<leader>al` overwrites active command files with extension source. Fix: add protected files to `.syncprotect`, run `check-command-drift.sh`
- [ ] **Task 2.4**: Write **Security Model** section (brief: sops-nix pipeline, no plaintext tokens, RAM-only tmpfs; TUI instances on localhost do not use auth)
- [ ] **Task 2.5**: Write **Related Resources** section with links to `discord-bot.md`, plugin source files (`discord-link.lua`, `discord-session-picker.lua`, `ai-tool-picker.lua`), bot source code, and extension loader documentation

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - Continue guide file

**Verification**:
- Environment Variables includes `OPENCODE_SERVER_PORT=3000`
- Service Management includes bot source code restart note
- Troubleshooting covers all 13 entries (8 original + 5 new) with correct heartbeat text
- Related Resources includes session picker source files and extension loader docs

---

### Phase 3: Review, Finalize, and Update Index [COMPLETED]

**Goal**: Review the complete guide for accuracy, ensure all corrections from research are applied, and update `guides/README.md`.

**Tasks**:
- [ ] **Task 3.1**: Review full document for accuracy against both research reports
- [ ] **Task 3.2**: Verify all three critical corrections are applied:
  - Architecture shows single-path SSE (no ThreadPoolExecutor)
  - Heartbeat troubleshooting is corrected (not "normal")
  - Quick Start uses explicit port 3000
- [ ] **Task 3.3**: Verify all new content is present:
  - Progress embed behavior documented
  - Bidirectional relay documented
  - `<C-CR>` session picker documented
  - 5 new troubleshooting entries present
  - `OPENCODE_SERVER_PORT=3000` in environment variables
  - Bot restart note in service management
- [ ] **Task 3.4**: Check for broken cross-references, consistent formatting, and adherence to `tts-stt-integration.md` style
- [ ] **Task 3.5**: Update `guides/README.md` to list the new guide under "Mobile/Remote Access" or "Integrations"

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - Final review and polish
- `/home/benjamin/.config/nvim/.opencode/docs/guides/README.md` - Add guide listing

**Verification**:
- Guide file exists at the expected path
- All required sections are present (Architecture, Prerequisites, Quick Start, Everyday Workflow, Keybinding Reference, API Reference, Environment Variables, Service Management, Troubleshooting, Security Model, Related Resources)
- Architecture section documents single-path SSE subscriber with auto-reconnection
- Troubleshooting covers all 13 entries with corrected heartbeat text
- `guides/README.md` includes the new guide entry
- No broken cross-references or dead links
- Guide follows existing conventions from `tts-stt-integration.md`

## Testing & Validation

- [ ] Guide file exists at `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md`
- [ ] All required sections are present (Architecture, Prerequisites, Quick Start, Everyday Workflow, Keybinding Reference, API Reference, Environment Variables, Service Management, Troubleshooting, Security Model, Related Resources)
- [ ] Architecture section documents the single-path SSE subscriber model (not the old ThreadPoolExecutor model)
- [ ] No references to `ThreadPoolExecutor` or `_send_message_sync` remain in the guide
- [ ] Heartbeat troubleshooting entry states blocking is eliminated, not "normal"
- [ ] Quick Start references explicit port 3000 and `<C-CR>` session picker
- [ ] Everyday Workflow documents progress embeds and bidirectional relay
- [ ] `OPENCODE_SERVER_PORT=3000` is documented in Environment Variables
- [ ] Service Management includes note about restarting bot after source code updates
- [ ] Troubleshooting covers all 13 entries (8 original + 5 new)
- [ ] `guides/README.md` includes the new guide entry
- [ ] No broken cross-references or dead links
- [ ] Token setup information reflects the corrected state: auth IS enforced, `DISCORD_BOT_LINK_TOKEN` must match the sops `link_api_token` secret, fish sets it automatically
- [ ] Guide follows existing conventions from `tts-stt-integration.md` (markdown structure, table formats, code block style)

## Artifacts & Outputs

- `/home/benjamin/.config/nvim/.opencode/docs/guides/discord-opencode-agents.md` - The workflow guide
- `/home/benjamin/.config/nvim/.opencode/docs/guides/README.md` - Updated index

## Rollback/Contingency

This is a documentation-only task with no code changes. Rollback is trivial:
- Delete the guide file: `rm .opencode/docs/guides/discord-opencode-agents.md`
- Revert the README.md edit via git: `git checkout -- .opencode/docs/guides/README.md`
