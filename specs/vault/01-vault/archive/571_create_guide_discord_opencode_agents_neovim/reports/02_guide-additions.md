# Research Report: Task #571 Follow-up -- Guide Additions from Post-571 Fixes

**Task**: 571 - Create guide for using Discord to manage OpenCode agents from Neovim
**Started**: 2026-05-14T18:00:00Z
**Completed**: 2026-05-14T18:30:00Z
**Effort**: 30 minutes
**Dependencies**: 572, 574, 575, 576, 577
**Sources/Inputs**:
- `specs/571_create_guide_discord_opencode_agents_neovim/reports/03_relay-fixes-progress-embed.md` -- Task 571 follow-up: async relay, progress embeds, SSE reconnection
- `specs/575_audit_opencode_session_picker_failure/reports/01_session-picker-audit.md` -- Session picker race conditions and fixes
- `specs/576_fix_opencode_session_picker/reports/01_fix_opencode_session_picker.md` -- Session picker autocmd and stale-server fixes
- `specs/576_fix_opencode_session_picker/summaries/01_fix-opencode-session-picker-summary.md` -- Implementation summary
- `specs/577_investigate_opencode_output_path_corruption/reports/01_output-path-corruption.md` -- Extension loader drift, output directory, CWD inheritance
- `specs/577_investigate_opencode_output_path_corruption/summaries/01_output-path-fix-summary.md` -- Implementation summary
- `specs/571_create_guide_discord_opencode_agents_neovim/plans/01_discord-opencode-guide.md` -- Existing plan to be amended
**Artifacts**:
- `specs/571_create_guide_discord_opencode_agents_neovim/reports/02_guide-additions.md` (this file)
**Standards**: report-format.md, artifact-management.md, tasks.md

---

## Executive Summary

- **Relay architecture changed fundamentally**: The bot no longer uses a dual-path response model with ThreadPoolExecutor. It now uses a single SSE subscriber path with native async aiohttp, auto-reconnection, and delayed progress embeds. The existing plan's troubleshooting note about heartbeat warnings being "normal" is factually incorrect and must be removed.
- **OpenCode session picker gained explicit port 3000 and idempotency fixes**: Tasks 575 and 576 fixed duplicate terminal creation on cold start, corrected session ID extraction from event data, added stale-server disconnect guards, and implemented a fallback to session browse when no last session exists. These behaviors should be documented in the workflow and troubleshooting sections.
- **CWD inheritance and extension reload risks discovered**: Task 577 revealed that OpenCode inherits Neovim's CWD via snacks.terminal, that `<leader>x` writes session exports to `.opencode/output/`, and that extension reloads (`<leader>al`) can overwrite improved active commands unless protected by `.syncprotect`. The guide should warn users about CWD context and explain the output directory.
- **Five new practical troubleshooting entries identified**: "Responses stop appearing in Discord" (port change / SSE reconnect), "Restore last session shows (none yet)", "No embed for long task" (SSE connection failure), "OpenCode runs in wrong project directory" (CWD mismatch), and "Commands revert after extension reload" (drift).
- **Three corrections required to the existing plan**: Remove the outdated heartbeat warning reassurance, update the architecture diagram to show single-path SSE relay, and update the `<leader>ar` workflow to reflect that TUI port discovery now uses explicit port 3000 rather than dynamic discovery.

---

## Context & Scope

**What was evaluated**: The reports, plans, and implementation summaries from tasks completed after task 571 (572, 574, 575, 576, 577) were reviewed to identify new findings, issues, fixes, and workflow improvements that should be added to the Discord/OpenCode/Neovim guide.

**Scope boundaries**: Only findings with practical impact on the end-user workflow guide are included. Meta-level findings (e.g., command routing in child projects from task 572, temp file conventions from task 574) were evaluated but deemed out of scope for this user-facing guide.

**Constraint**: The guide additions must fit within the existing plan structure (`plans/01_discord-opencode-guide.md`) without requiring a rewrite of completed sections.

---

## Findings

### Task 571 Follow-up -- Relay Fixes (Report 03)

**Finding 1**: The bot's response delivery architecture was replaced in its entirety. The original dual-path model (`_relay_and_respond` with blocking `urllib.request.urlopen` in a `ThreadPoolExecutor` + SSE subscriber with dedup guard) was replaced with a single-path SSE subscriber that uses native `aiohttp` async POST for message sending.

**Finding 2**: Heartbeat blocking is eliminated, not mitigated. The ThreadPoolExecutor was completely removed. The existing plan's troubleshooting item stating "heartbeat warnings are normal during long AI operations and do not indicate a problem; the thread pool executor prevents them from blocking the bot" is factually wrong and must be deleted or corrected.

**Finding 3**: Progress embeds use a delayed 10-second threshold. For short exchanges (< 10s), only the response text is posted. For long-running tasks, a yellow "Processing..." embed appears after 10 seconds, updates every ~15 seconds with activity snippets, and turns green on completion. This is a user-visible feature that should be documented.

**Finding 4**: The relay is now bidirectional. Messages typed directly in the OpenCode TUI also appear in the linked Discord thread, not just Discord-to-OpenCode messages. The SSE subscriber reconnects automatically with exponential backoff (2s to 60s) if the TUI restarts.

### Tasks 575 & 576 -- Session Picker Fixes

**Finding 5**: The OpenCode TUI now runs on explicit port 3000 (`opencode --port 3000`). The `opts.server.port = 3000` configuration bypasses the slow `pgrep/lsof` discovery path, making cold-start discovery fast and deterministic. The existing plan's architecture section references dynamic port discovery via `ss` -- this should be updated to reflect the explicit port.

**Finding 6**: Duplicate terminal creation on cold start was fixed. The `start()` function now uses `snacks.terminal.get()` with a dedup guard before calling `open()`. The restore and browse paths no longer call `toggle()` redundantly before session API invocations. This prevents the race where two opencode processes would start.

**Finding 7**: The `OpencodeEvent:session.idle` autocmd in `ai-tool-picker.lua` was fixed to correctly extract session IDs from the nested event data structure (`event.data.event.properties.sessionID`). Previously the file `opencode-last-session.json` was never written, causing "Restore last session" to always show "(none yet)" and do nothing.

**Finding 8**: Stale `connected_server` cache mitigation was added. Both restore and browse paths now call `require("opencode.events").disconnect()` before server-dependent operations to force fresh discovery instead of returning a cached dead server object.

**Finding 9**: Fallback behavior added. When no last session exists, selecting "Restore last session" now opens the session browser instead of doing nothing.

### Task 577 -- Output Path Corruption Investigation

**Finding 10**: The `.opencode/output/` directory is OpenCode's session export location. Pressing `<leader>x` in the TUI triggers `session_export` and writes the conversation to `.opencode/output/{command-name}.md`. This is not a corrupted artifact path -- it is an intentional feature. Users may see `output/implement.md` and think it is a malformed artifact.

**Finding 11**: OpenCode inherits Neovim's current working directory via snacks.terminal. The `cwd` defaults to `vim.fn.getcwd(0)`. If the user opens the TUI while editing files in `~/.config/nvim/`, OpenCode operates in that directory, causing session exports and state lookups to target the nvim config repo instead of the intended project.

**Finding 12**: Extension reloads (`<leader>al`) overwrite active command files with extension source files. If the extension source is outdated, active commands lose improvements such as the `COMMAND EXECUTION MODE` preamble and absolute-path routing fixes. The `.syncprotect` mechanism now applies to the extension loader (fixed in task 577), preventing accidental overwrites of protected files.

**Finding 13**: A `check-command-drift.sh` script was created to detect when active commands diverge from extension source. It exits 0 for no drift, 1 for drift detected.

---

## Decisions

1. **Task 572 and 574 findings are out of scope** for this user-facing guide. Task 572 (lean routing in child projects) and task 574 (temp file conventions) are maintenance/meta concerns that do not affect the everyday Discord/OpenCode/Neovim workflow.
2. **The heartbeat troubleshooting note must be corrected, not merely updated**. The original plan text says heartbeat warnings are normal -- this is false after the async rewrite. It should state that heartbeat blocking has been eliminated entirely.
3. **The architecture diagram must be updated** to show single-path SSE delivery instead of the old dual-path model with ThreadPoolExecutor.
4. **Port 3000 should be documented as the default** rather than dynamic discovery, since this is the current running configuration.
5. **The `<C-CR>` OpenCode session picker is relevant enough to mention** in the Quick Start or Everyday Workflow sections, since it is the primary way users create/restore OpenCode sessions before linking them to Discord.

---

## Recommendations

### Priority 1: Corrections to Existing Plan Content

1. **Architecture section**: Replace the dual-path response description with the single-path SSE subscriber model. Remove all references to `ThreadPoolExecutor` and `_send_message_sync`. Add that the subscriber auto-reconnects with exponential backoff.

2. **Troubleshooting -- Heartbeat warnings**: Change the existing entry from:
   > "Heartbeat warnings in journalctl -u discord-bot: these are normal during long AI operations and do not indicate a problem; the thread pool executor prevents them from blocking the bot."
   
   To:
   > "Heartbeat warnings in journalctl -u discord-bot: With the current fully async relay, heartbeat blocking should no longer occur. If you see heartbeat warnings, the bot may be running an outdated version -- restart discord-bot.service and verify `opencode_client.py` uses native `aiohttp` (not `urllib.request` in a `ThreadPoolExecutor`)."

3. **Quick Start step 2**: Update "Toggle OpenCode TUI (starts opencode --port on a dynamic port)" to "Toggle OpenCode TUI (starts `opencode --port 3000` on the configured port)."

### Priority 2: New Workflow Content

4. **Progress embed behavior** (add to Everyday Workflow or a new "Discord Thread Behavior" subsection):
   - Short exchanges (< 10s): response text posted directly, no embed
   - Long tasks (> 10s): yellow "Processing..." embed appears, live timestamp, updates every ~15s with latest activity snippet, turns green on completion
   - Full response text is always posted below the embed (or standalone for short exchanges)

5. **Bidirectional relay** (add to Everyday Workflow):
   - Messages typed directly in the OpenCode TUI also appear in the linked Discord thread
   - The bot automatically reconnects to the TUI's event stream if the connection drops (e.g., TUI restart)
   - Re-linking with `<leader>ar` is only needed if Neovim is restarted (which changes the TUI port)

6. **OpenCode session picker** (add to Prerequisites or Quick Start):
   - Press `<C-CR>` to open the AI tool picker, select OpenCode
   - "Create new session" opens the TUI
   - "Restore last session" restores the previously active session (requires the TUI to have been idle at least once for the session file to be written)
   - "Browse all sessions" opens a picker to select from all available sessions
   - If "Restore last session" shows "(none yet)", the session browser opens as a fallback

### Priority 3: New Troubleshooting Entries

7. **"Responses stop appearing in Discord"**:
   - Cause: TUI was restarted (port changed) or SSE subscriber lost connection
   - Fix: Check `journalctl -u discord-bot` for reconnection logs. If the port changed, re-link with `<leader>ar`. The bot auto-reconnects, but re-linking ensures the new port is registered.

8. **"No progress embed for a long task"**:
   - Cause: SSE subscriber failed to connect to the TUI's event stream
   - Fix: Check `journalctl -u discord-bot` for connection errors. Verify the TUI is running on port 3000 (`ss -tlnp | grep 3000`).

9. **"Restore last session shows (none yet)"**:
   - Cause: The session ID was not captured from the `session.idle` event (fixed in task 576), or the session has never gone idle
   - Fix: Use "Browse all sessions" instead. Ensure you have waited for the session to go idle at least once after creating it.

10. **"OpenCode runs in the wrong project directory"**:
    - Cause: OpenCode inherits Neovim's CWD. If you opened the TUI while editing `~/.config/nvim/` files, OpenCode operates in that directory.
    - Fix: Ensure Neovim's CWD matches your intended project (`:pwd`) before toggling the TUI. Session exports and state files will be written relative to that directory.

11. **"Commands revert after extension reload"**:
    - Cause: Reloading the core extension via `<leader>al` overwrites active command files with extension source files.
    - Fix: Add files you do not want overwritten to `.syncprotect` at the project root. Run `check-command-drift.sh` to detect divergence.

### Priority 4: Minor Additions

12. **Environment Variables**: Add `OPENCODE_SERVER_PORT=3000` as a documented default (currently only `DISCORD_BOT_URL` and `DISCORD_BOT_LINK_TOKEN` are listed).

13. **Service Management**: Add a note that `systemctl restart discord-bot` is required after updating bot source code (not just after `nixos-rebuild switch`).

14. **Related Resources**: Add links to the session picker source files and the extension loader documentation.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Guide becomes stale if more bot changes occur | Medium | Include "last verified" date and reference canonical source files |
| Users confused by explicit port 3000 if they customized it | Low | Document that 3000 is the default; users with custom ports should substitute their value |
| Output directory explanation causes more confusion than clarity | Low | Keep it brief -- one sentence explaining `<leader>x` triggers session export |
| Extension reload warning discourages legitimate use of `<leader>al` | Low | Frame it positively: "Use `.syncprotect` to preserve customizations during reloads" |

---

## Context Extension Recommendations

- **Topic**: OpenCode Neovim plugin event data structure
- **Gap**: The exact structure of `OpencodeEvent:*` event properties is not documented in `.opencode/context/`
- **Recommendation**: Add a brief context file documenting the event wrapper structure (`event.data = { event = { type, properties }, port = N }`) and common property paths for different event types. This would help future debugging of session tracking and similar autocmd issues.

---

## Appendix

### Task-to-Guide Mapping

| Task | Key Finding | Guide Section Affected |
|------|-------------|------------------------|
| 571 Report 03 | Async relay, no heartbeat blocking | Architecture, Troubleshooting |
| 571 Report 03 | Delayed progress embed (10s threshold) | Everyday Workflow |
| 571 Report 03 | Bidirectional relay, SSE reconnection | Everyday Workflow |
| 575 | Explicit port 3000, idempotent start | Prerequisites, Quick Start |
| 575 | Duplicate terminal race fixed | Troubleshooting (resolved issue) |
| 576 | Session ID extraction fix | Troubleshooting |
| 576 | Stale server disconnect | Troubleshooting |
| 576 | Fallback to browse when no last session | Everyday Workflow |
| 577 | `output/` is session export | Troubleshooting |
| 577 | CWD inheritance from Neovim | Troubleshooting |
| 577 | Extension reload overwrites commands | Troubleshooting |
| 577 | `.syncprotect` now protects extension reloads | Troubleshooting |

### File Paths Referenced

| Path | Purpose |
|------|---------|
| `specs/571_create_guide_discord_opencode_agents_neovim/reports/03_relay-fixes-progress-embed.md` | Relay architecture changes |
| `specs/575_audit_opencode_session_picker_failure/reports/01_session-picker-audit.md` | Session picker race conditions |
| `specs/576_fix_opencode_session_picker/reports/01_fix_opencode_session_picker.md` | Session ID extraction and stale server fixes |
| `specs/577_investigate_opencode_output_path_corruption/reports/01_output-path-corruption.md` | Extension loader drift and CWD inheritance |
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | Session picker implementation |
| `lua/neotex/plugins/ai/opencode.lua` | OpenCode plugin config (port 3000, idempotent start) |
| `.opencode/extensions/core/scripts/check-command-drift.sh` | Drift detection script |
