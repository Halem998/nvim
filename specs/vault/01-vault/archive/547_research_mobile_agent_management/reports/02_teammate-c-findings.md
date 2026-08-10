# Teammate C (Critic) Findings: Discord Bot Orchestration Gaps

**Task**: 547 - research_mobile_agent_management
**Teammate Role**: Critic -- identifying research gaps, unvalidated assumptions, and Discord platform constraints
**Reviewed Artifacts**: 
- specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md
- specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md
**Started**: 2026-05-07T21:00:00Z
**Completed**: 2026-05-07T23:30:00Z

## 1. Executive Summary

The existing research is thorough on the OpenCode side but has **critical gaps** in Discord-specific platform analysis. Most critically: the research never validates that Discord's API can reliably sustain a message relay pattern for LLM conversations. Six areas demand investigation before implementation proceeds.

**Highest priority gaps** (see sections below for full analysis):

1. **Message Content Intent requirement** -- The bot cannot read thread messages without this privileged gateway intent, which requires Discord's manual approval. This is a **blocker** that the research omits entirely.
2. **Message size ceilings** -- Discord's 2000-character limit per message means OpenCode responses must be split, paginated, or truncated. The research assumes messages "just flow through."
3. **Thread lifecycle constraints** -- Auto-archive timers (60min minimum), active thread caps, and archived-thread gateway event loss all threaten the core "thread = session" binding the design depends on.
4. **Gateway reconnect data loss** -- Discord can (and routinely does) send opcode 7 (Reconnect) forcing gateway reconnection. In-flight relayed messages are silently lost with no queue/retry mechanism discussed.
5. **Developer Policy exposure** -- Using `--dangerously-skip-permissions` for unattended agent tasks, and auto-unarchiving threads by sending messages, both touch Discord's Developer Policy in ways the research doesn't examine.
6. **The 10,000 invalid requests trap** -- Rapid auth failures or 401 responses (if the bot token expires or OpenCode is down) can trigger automatic Cloudflare-level bans within minutes. The research notes "Nextcord handles rate limiting" but this addresses REST rate limits, not the invalid-request threshold.

**Confidence in these findings**: High. All constraints are verified against the current (2026) Discord Developer Documentation, Developer Terms of Service, and Developer Policy.

## 2. Context & Scope

This critique examines the two existing artifacts against Discord's documented API constraints, developer policies, and real-world failure modes. It does **not** duplicate implementation risk analysis (which the plan covers adequately for the risks it identifies). Instead, it surfaces constraints and failure modes the research and plan do not address at all.

Sources consulted:
- Discord Developer Documentation (rate limits, channels, messages, webhooks, threads, gateway events) -- fetched live 2026-05-07
- Discord Developer Terms of Service (effective July 8, 2024, last updated June 6, 2024)
- Discord Developer Policy (effective July 8, 2024, last updated June 6, 2024)
- Codebase: `.opencode/systemd/`, `.opencode/agent/`, `.opencode/hooks/`, `.opencode/scripts/`

## 3. Key Findings

### 3.1 BLOCKER: Message Content Intent Not Addressed

The bot must read message content in threads to relay it to OpenCode. Discord gates message content behind the **`MESSAGE_CONTENT` privileged gateway intent** (`1 << 15`). Without this intent, all `content`, `embeds`, `attachments`, and `components` fields in `MESSAGE_CREATE` events come back **empty**.

Per Discord's [Message Content Intent Review Policy](https://support-dev.discord.com/hc/en-us/articles/5324827539479), applications must:
- Submit for manual review and approval
- Demonstrate that reading message content is essential to the application's core functionality
- Pass when they reach 100 servers

For a single-server, single-user bot this is **probably approvable** (the relay use case is well-defined and legitimate), but it is not guaranteed and it adds deployment latency. Neither the research report nor the implementation plan mentions this requirement.

**Confidence**: High. The Discord documentation explicitly states: "An app will receive empty values in the `content`, `embeds`, `attachments`, and `components` fields [...] if they have not configured (or been approved for) the MESSAGE_CONTENT privileged intent."

**Alternative paths if denied**: The bot could use slash commands to capture user input (interaction-based, which does not need MESSAGE_CONTENT), but this requires the user to type `/rc relay <session_id> <message>` every time, defeating the natural conversation UX.

### 3.2 GAP: Message Size Limits Will Require Splitting Logic

Discord messages are limited to **2000 characters**. OpenCode agent responses routinely exceed this (a typical research report or plan output is 3000-15000 characters). The existing artifacts treat the bot as a "thin relay" but this relay must implement:

- **Pagination**: Split long responses across multiple Discord messages
- **Truncation with continuation**: Offer a summary view with a link to the full output
- **File attachment**: Upload the full response as a `.txt` file attachment and post a summary with context

None of these are mentioned. The closest is Phase 4's `MessageRelay` class, which has `relay_to_discord(session_id, response_text)` with no splitting logic described.

**Secondary constraint**: Embeds have their own limits -- 6000 characters total across all embed fields, 256-character cap on field names, and per-field value limits. If responses are formatted as embeds, these bite sooner.

**Confidence**: High. The Discord message object documentation confirms the 2000-character content limit.

### 3.3 GAP: Thread Auto-Archive and Active Thread Limits

The design binds Discord threads 1:1 to OpenCode sessions. Threads have lifecycle constraints the research does not analyze:

| Constraint | Value | Impact |
|------------|-------|--------|
| Min auto-archive duration | 60 minutes | An LLM session paused for >60min auto-archives. Bot must detect and unarchive. |
| Max auto-archive duration | 7 days (10080 min) | Must be explicitly set on thread creation, otherwise defaults to 1440 (24h). |
| Active thread cap per guild | Undocumented but enforced | Too many concurrent linked sessions could hit this limit. |
| Archived thread gateway behavior | Gateway only syncs active threads | On bot restart, archived threads are invisible -- the bot's sessions.json may reference threads that don't appear in gateway sync. |

**Critical operational scenario**: The user starts a session in Neovim, links it to Discord, then puts their phone down for 90 minutes. The Discord thread auto-archives. When they return and send a message, the API helpfully unarchives the thread (Discord's behavior) and delivers the message. But the bot has been receiving no gateway events for that thread during the archived period. If the OpenCode session also ended or changed state during that time, the bot has stale information.

The research mentions thread archiving in the context of cleanup ("auto-archive threads when session ends"), not as an operational disruption during active-but-paused sessions.

Note: Discord's documentation states "The API will helpfully automatically unarchive a thread when sending a message in that thread." The bot can rely on this, but it means the first message after a long pause incurs an extra API call and slight latency.

**Confidence**: High. All constraints are from Discord's Threads documentation.

### 3.4 GAP: Gateway Disconnect / Reconnect and Message Loss

Discord gateways can disconnect at any time via:

- **Opcode 7 (Reconnect)**: Discord instructs the client to disconnect and resume. "A few seconds after the reconnect event is dispatched, the connection may be closed by the server."
- **Network disruption**: WiFi drop, ISP hiccup, NixOS systemd restart
- **Discord maintenance**: Routine server-side maintenance cycles

The `RESUME` opcode replays missed gateway events, but **REST API calls** (like sending messages) that were in-flight during the disconnect window are **not replayed**. The bot's `MessageRelay` sends a message to OpenCode, waits for the response, then sends it to Discord -- if the gateway disconnects between those steps, the response is lost.

The plan addresses "Bot-to-OpenCode auth fails on server restart" but not Discord-side disconnection. Specifically missing:
- **Outbound message queue**: Buffer responses while reconnecting
- **Idempotency**: Don't resend the same Discord message twice after reconnect
- **State reconstruction**: Rebuild active thread/session mappings from `sessions.json` + `opencode session list` after reconnect

**Confidence**: Medium-high. Gateway disconnects are documented behavior, but the frequency depends on Discord's infrastructure stability and the user's network. For a single-user bot, the impact window is small (seconds), but without handling, even a brief disconnect drops relayed LLM responses.

### 3.5 GAP: Developer Policy Exposure Points

Several aspects of the design touch Discord's Developer Policy in ways worth surfacing:

**Policy #3 (Safety/Security circumvention)**:
> "Do not enable your Application to bypass or circumvent Discord's privacy, safety, and/or security features."

OpenCode's `--dangerously-skip-permissions` flag auto-approves all permissions. The Discord bot, acting unattended, invokes OpenCode with this flag. A Discord moderator reviewing the bot's behavior could interpret unattended permission-skipping as circumvention of safety features, since the bot is effectively auto-approving its own tool calls without human review.

**Policy #13 (Engagement manipulation)**:
> "Do not [...] automate messages to be sent for the purpose of maintaining activity in a Discord server."

Auto-unarchiving a thread by sending a message is a legitimate Discord API behavior, but a pattern of the bot auto-unarchiving dozens of threads by sending "session still active" heartbeat messages could look like engagement inflation.

**Mitigation**: Neither is likely to trigger enforcement for a single-user, private-server bot. But the research mentions "production-quality" and the plan includes "production readiness" (Phase 6) -- if the bot is ever deployed at scale or made discoverable, these become real concerns. The research should at minimum document the tradeoffs and mitigation strategies (e.g., replace `--dangerously-skip-permissions` with a permission allowlist model, use explicit unarchive API calls instead of implicit via message sending).

**Confidence**: Medium. The policies are real, but enforcement risk for a single-user bot is low. The concern is forward-looking (scale/ discoverability).

### 3.6 GAP: The 10,000 Invalid Requests Cloudflare Ban

Discord's Invalid Request Limit is **10,000 invalid HTTP responses per 10 minutes**. An "invalid" response is any 401, 403, or 429. This is a **sustained 16-17 invalid requests/second**.

For normal operation this isn't an issue. But consider this sequence:
1. Bot token expires (Discord rotates tokens periodically, or the user regenerates it)
2. Bot attempts to send ~50 messages across linked threads
3. Each message gets a 401 response
4. Nextcord's automatic retry fires for each failed message
5. Within seconds, the bot accumulates hundreds of 401 responses
6. If the bot is also polling `opencode session list` (every 30 seconds per the plan's cache TTL) or running health checks that also auth with Discord, the count compounds

The plan's error handling for "Bot-to-OpenCode auth fails" (Phase 3, Task 3.3) covers OpenCode authentication but not Discord authentication failure modes.

**Confidence**: High for the constraint's existence; medium for likelihood of hitting it (depends on token lifecycle and retry behavior). Worth documenting as a deployment consideration.

### 3.7 GAP: No Bot Permission Inventory

The bot needs specific Discord permissions to function. The research and plan do not enumerate these:

| Permission | Required For |
|------------|-------------|
| `SEND_MESSAGES_IN_THREADS` | Sending LLM responses in threads. Note: `SEND_MESSAGES` has *no effect* in threads per Discord docs. |
| `CREATE_PUBLIC_THREADS` or `CREATE_PRIVATE_THREADS` | Creating threads from the `:OpenCodeLinkDiscord` command |
| `MANAGE_THREADS` | Archiving/unarchiving threads, renaming threads, managing thread lifecycle |
| `READ_MESSAGE_HISTORY` | Seeing previous messages in threads after reconnect |
| `USE_APPLICATION_COMMANDS` | Slash commands (`/rc` group) |

The Discord application invite URL generator requires these permissions to be set at installation time. If the bot is installed without `SEND_MESSAGES_IN_THREADS`, it silently fails to relay responses in threads (messages appear to send but never arrive).

**Confidence**: High. The Discord Threads documentation explicitly states: "The `SEND_MESSAGES` permission has no effect in threads; users must have `SEND_MESSAGES_IN_THREADS` to talk in a thread."

### 3.8 GAP: `opencode run` Blocking Duration Mismatch

The plan sets a 120-second subprocess timeout for `opencode run --command`. The research did not test actual run durations. Real-world OpenCode commands:

| Command | Typical Duration |
|---------|-----------------|
| `/research` | 15-45 minutes (web search + analysis) |
| `/implement` | 10-120 minutes (multi-file edits + verification) |
| `/plan` | 5-20 minutes (reading research + generating phased plan) |
| Simple relay message | 5-120 seconds (LLM response latency) |

A 120-second timeout works for simple relay but fails for every named command. The plan acknowledges this in the risks table ("`opencode run --command` blocks indefinitely on long tasks") but the mitigation ("long tasks return async task ID; status polling") presumes `opencode run --command` supports async fire-and-forget -- **this has not been validated**.

The research should determine:
- Does `opencode run --command research --format json` return immediately with a task ID, or block until completion?
- If it blocks, can the bot spawn it as a background subprocess and poll `opencode session list` for completion?
- What is the `opencode run --format json` output format for long-running commands? (Event stream? Final result only?)

**Confidence**: Medium. The plan correctly identifies the risk but the research hasn't provided the data needed to design the mitigation.

### 3.9 GAP: No "Thinking" / Streaming UX Design

OpenCode agents produce internal reasoning (tool calls, status updates, streaming output) before providing final responses. The Discord bot currently has no design for how to represent this to the mobile user:

- **Raw streaming**: Mirror every event to Discord. Produces dozens of messages (tool calls, intermediate outputs) that clutter the thread.
- **Periodic status**: Send a "Working..." message, update it every 30 seconds with progress. Requires Discord message editing.
- **Black box**: Show typing indicator, send only the final response. Clean UX but user has no visibility into progress for 30+ minute commands.

The plan mentions "typing indicator while processing" (Phase 4, Task 4.3) which addresses the sub-10-seconds relay case, not the 30-minute research case.

**Confidence**: High that this is a UX gap. Medium that it's a blocker (depends on user expectations).

### 3.10 Minor Gaps (collectively significant)

- **Webhook vs bot message rates**: The research mentions "50 requests/second" (the global rate limit) without noting that webhook endpoints have separate limits and interaction endpoints are exempt from the global limit. The relay is purely bot REST API calls, so all 50/sec apply.
- **Mosh client update**: Blink Shell remains the best option, but Termius now includes free Mosh in its free tier (as of 2025). Worth noting as a zero-cost alternative.
- **Systemd hardening**: The systemd service template uses `Type=simple` with no security directives (`NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=read-only`, `PrivateTmp=yes`). For a service holding a Discord bot token, these are baseline hardening options available on all systemd versions in NixOS 26.05.
- **Gateway intents beyond MESSAGE_CONTENT**: The bot also needs `GUILDS` (1<<0) for guild info, and `GUILD_MESSAGES` (1<<9) for message events. These are non-privileged but must be explicitly declared in the Identify payload. Nextcord likely sets defaults, but it should be verified.

## 4. What Questions Should Be Asked But Aren't

1. **"What happens to a relayed conversation when Discord has an outage?"** Discord has partial outages 1-3 times per year. During an outage, the bot can't relay messages at all. Is there a fallback path? (The Mosh/SSH fallback covers terminal access but not session continuity.)

2. **"How does the bot handle the OpenCode session producing output faster than Discord rate limits allow?"** If OpenCode streams 10 messages/second and Discord limits to 5 messages/second per channel, the bot must buffer and throttle.

3. **"Can the Discord thread model survive multiple days of inactivity?"** A Pi-based agent session might run for days with occasional check-ins. Threads auto-archive after 7 days max. After archiving, the bot must explicitly unarchive -- requiring `MANAGE_THREADS` permission and an API call.

4. **"What authentication model does `opencode run --attach` use for remote Pi servers?"** The research mentions attaching to Pi but doesn't explore the auth mechanism for remote `opencode serve` instances (is it the same `OPENCODE_SERVER_PASSWORD`? TLS? Something else?).

5. **"Is there a maximum number of active threads per channel/guild, and what happens when exceeded?"** Discord enforces limits. If 10 concurrent agent sessions each create a thread, and the user also has other active threads in the server, the cap may be reached. New threads would fail to create, breaking `:OpenCodeLinkDiscord`.

## 5. Recommended Approach

The core architecture (Discord bot as thin relay, `opencode serve` as backend, 1:1 thread-to-session mapping) is sound. The gaps above are resolvable with targeted follow-up research. In priority order:

### P0 (Must resolve before Phase 1 implementation):
1. **Verify MESSAGE_CONTENT intent approval pathway**: Create a Discord application, request the intent, document the approval process and timeline.
2. **Test `opencode run --command` blocking behavior**: Run `time opencode run --command research "test" --format json` and `time opencode run --command implement "test"` to measure actual durations.
3. **Inventory required Discord permissions** and create the bot invite URL with exact scopes.

### P1 (Must resolve before Phase 3-4):
4. **Design message splitting/pagination** for responses exceeding 2000 characters.
5. **Test thread auto-archive behavior** with OpenCode sessions: Start a session, link to Discord, wait 65 minutes (beyond 60min min archive), verify the bot can still send and receive.
6. **Design gateway reconnect/resume logic** with an outbound message queue.

### P2 (Nice to have before production):
7. **Document Developer Policy considerations** (especially `--dangerously-skip-permissions` usage).
8. **Design progress/status UX** for long-running commands.
9. **Add systemd security hardening directives** to the service template.

## 6. Confidence Level Summary

| Finding | Confidence | Impact if Correct |
|---------|-----------|-------------------|
| 3.1 MESSAGE_CONTENT intent requirement | **High** | Blocker -- bot cannot read messages without it |
| 3.2 Message size limits | **High** | Requires significant relay logic not yet designed |
| 3.3 Thread lifecycle constraints | **High** | Operational reliability risk for paused sessions |
| 3.4 Gateway reconnect message loss | **Medium-High** | Data loss risk for in-flight relayed responses |
| 3.5 Developer Policy exposure | **Medium** | Low risk for single-user; escalates with scale |
| 3.6 Invalid request Cloudflare ban | **High** (constraint exists) / **Medium** (likelihood) | Operational risk on token/auth failures |
| 3.7 Bot permission inventory | **High** | Prevents silent failures on bot installation |
| 3.8 `opencode run` blocking | **Medium** | May invalidate the plan's async task ID mitigation |
| 3.9 Streaming UX | **High** (gap) / **Medium** (blocker) | UX quality issue; not a correctness blocker |
| 3.10 Minor gaps | **Medium-High** (individually) | Collectively impact production readiness |

## 7. Appendix

### A. Discord API Constraints (current as of 2026-05-07)

| Constraint | Value | Source |
|-----------|-------|--------|
| Message content limit | 2000 characters | Message Resource docs |
| Embed total character limit | 6000 across all fields | Embed Object docs |
| Max embeds per message | 10 | Message Resource docs |
| Global REST rate limit | 50 requests/second | Rate Limits docs |
| Invalid request ban threshold | 10,000 per 10 minutes | Rate Limits docs |
| Min thread auto-archive | 60 minutes | Threads docs |
| Max thread auto-archive | 10080 minutes (7 days) | Threads docs |
| Thread name length | 1-100 characters | Channel Resource docs |
| Max guild channels (threads exempt) | 500 (default) | Discord limits |
| Gateway heartbeat interval | ~45 seconds (varies) | Hello event docs |
| Webhook message content limit | 2000 characters | Webhook Resource docs |

### B. Gateway Intents Required

| Intent | Bit | Privileged? | Purpose |
|--------|-----|-------------|---------|
| `GUILDS` | `1 << 0` | No | Guild info for slash commands |
| `GUILD_MESSAGES` | `1 << 9` | No | Message events in channels |
| `MESSAGE_CONTENT` | `1 << 15` | **Yes** | Read message content (blocker) |

### C. Discord Developer Policy -- Relevant Sections

- **Policy #3**: "Do not enable your Application to bypass or circumvent Discord's privacy, safety, and/or security features."
- **Policy #13**: "Do not [...] automate messages to be sent for the purpose of maintaining activity in a Discord server."
- **Policy #15**: "Do not use API Data for any purpose outside of what is necessary to provide your stated functionality." (The bot's relay is its stated functionality -- this is fine.)

### D. Discord Developer Terms -- Key Provision

> Section 2(b): "You will not [...] access or use the APIs in any way that [...] exceeds any API rate, call, or other usage limits we set in our sole discretion [...] or that we believe constitutes excessive or abusive usage."

Discord retains the right to determine "excessive or abusive usage" unilaterally. A bot that auto-unarchives 20 threads simultaneously during a reconnect storm could trigger this.
