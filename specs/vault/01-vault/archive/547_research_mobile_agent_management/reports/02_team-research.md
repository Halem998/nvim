# Research Report: Discord Bot Orchestration Patterns for Multi-Agent Management

- **Task**: 547 - research_mobile_agent_management
- **Started**: 2026-05-08T04:00:00Z
- **Completed**: 2026-05-08T05:30:00Z
- **Effort**: 1.5 hours (synthesis)
- **Dependencies**: None
- **Sources/Inputs**:
  - Teammate A: specs/547_research_mobile_agent_management/reports/02_teammate-a-findings.md (Primary approach)
  - Teammate B: specs/547_research_mobile_agent_management/reports/02_teammate-b-findings.md (Alternatives)
  - Teammate C: specs/547_research_mobile_agent_management/reports/02_teammate-c-findings.md (Critic)
  - Teammate D: specs/547_research_mobile_agent_management/reports/02_teammate-d-findings.md (Horizons)
  - Codebase: `.opencode/skills/skill-team-research/SKILL.md`, `.opencode/agent/subagents/`
  - Prior report: specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md
  - Prior plan: specs/547_research_mobile_agent_management/plans/01_discord-bot-neovim-setup.md
- **Artifacts**:
  - specs/547_research_mobile_agent_management/reports/02_team-research.md
- **Standards**: report-format.md, return-metadata-file.md, status-markers.md

## Executive Summary

- **Single bot token suffices**: One Discord bot can manage all channels/threads with a single token and WebSocket connection. No multi-bot federation needed for single-user scale (Teammates A, B, D agree).
- **Two architectural forks identified**: (1) Thin relay -- bot forwards messages between threads and `opencode serve` (MVP-friendly, ~300 lines). (2) Channel-Oriented Agent Teams (COAT) -- channels map to agent roles, bot dispatches team-mode waves across channels (strategic, leverages existing `.opencode/` team skills). The plan should accommodate both.
- **Three P0 blockers surfaced by Critic (C)**: MESSAGE_CONTENT privileged intent requires Discord approval; `opencode run --command` blocking behavior is unverified for long tasks; Discord bot permission inventory (especially `SEND_MESSAGES_IN_THREADS`) must be specified at installation. None were in the prior plan.
- **Discord threads have operational constraints**: Auto-archive (60min min), 2000-char message limit, gateway disconnect message loss -- all require explicit handling the prior plan omits.
- **Existing platforms reviewed**: n8n (closest off-the-shelf solution, overkill for MVP), CrewAI (Flow+Crew pattern worth borrowing conceptually), Temporal (right for scale, wrong for now). None recommended as dependency.
- **Pi deployment should be concurrent, not Phase 3**: Always-on hosting is a dependency for mobile access; Pi infrastructure should develop in parallel with bot code (Teammate D, elevated by synthesis).

## Context & Scope

This is the synthesis report for the second round of team research on task 547. The user requested investigation of bot-to-bot orchestration patterns for managing multiple agent bots across Discord channels from an iPhone, with the orchestrator able to switch between agents.

Four teammates investigated complementary angles:
- **A**: Primary architecture patterns (Cogs, threads, state management)
- **B**: Alternative platforms and prior art (n8n, CrewAI, AutoGen, CLI approaches)
- **C**: Platform constraints and gaps (Discord API limits, policies, failure modes)
- **D**: Strategic alignment and long-term vision (roadmap synergy, Pi priority, message bus)

## Findings

### 1. Architecture: Thin Relay vs. Channel-Oriented Agent Teams

**Teammate A** recommends **Pattern C (Manager-Worker via Threads)** -- a single bot token with one Cog per managed agent, threads providing per-agent isolation. Each "sub-agent" is a managed OpenCode process communicating through its dedicated Discord thread.

**Teammate D** challenges this as "strategically insufficient" and proposes **Channel-Oriented Agent Teams (COAT)** -- Discord channels map to agent *roles* not sessions. `#research-wave` hosts 4 parallel research agents, `#implementation-wave` hosts parallel implementers, `#orchestrator` is mission control. This mirrors the existing `skill-team-research` pattern (wave-based parallel agents + synthesis) but exposed through Discord.

**Synthesis**: These are not conflicting -- they represent two stages. The thin relay model (A) is the correct MVP. The channel-oriented model (D) is the correct strategic target. The architecture should:
1. Use a single bot token with Cog-based agent management (A)
2. Design the `SessionStore`/`AgentRegistry` abstraction to support both 1:1 thread-to-session and channel-to-team mappings (A + D)
3. Implement `/rc` commands that can address multiple agents simultaneously -- `/rc research N --team` spawning a full wave (D)
4. Keep the current plan's Phase 1-3 (scaffolding, commands, OpenCode integration) intact as foundation

### 2. Discord Platform Constraints (from Critic C)

Teammate C surfaced critical constraints absent from both the research report and implementation plan:

| Constraint | Impact | Required Action |
|------------|--------|-----------------|
| **MESSAGE_CONTENT intent** (privileged, needs approval) | Bot cannot read thread messages without it | File for approval immediately; document fallback (slash-command-only mode) |
| **2000-char message limit** | OpenCode responses routinely exceed this | Implement pagination/splitting in `MessageRelay`; file attachment fallback for large outputs |
| **Thread auto-archive** (60min min) | Session paused >60min auto-archives the thread | Set max archive duration (7 days) at thread creation; handle re-unarchive on message send |
| **Gateway disconnect message loss** | In-flight relayed responses silently dropped | Add outbound message queue; reconstruct state from `sessions.json` + `opencode session list` on reconnect |
| **`SEND_MESSAGES_IN_THREADS` permission** | `SEND_MESSAGES` has no effect in threads | Include in bot invite URL; verify at bot startup |
| **10,000 invalid-request Cloudflare ban** | Token expiration + retry storms could trigger | Monitor 401/403 rates; halt retries above threshold |
| **`opencode run` blocking behavior unverified** | Plan's async task ID mitigation assumes fire-and-forget support | Test actual durations and output format before designing background execution model |

These are not blockers to the architecture but are prerequisites that must be resolved before Phase 3-4 implementation.

### 3. State Management: JSON vs. SQLite

**Teammate A** recommends upgrading from the plan's JSON `sessions.json` to SQLite (aiosqlite) for concurrent multi-agent coordination, citing atomic transactions, concurrent access safety, and queryability.

**Synthesis**: Keep JSON for the MVP thin-relay phase (adequate for single-session management). Plan the SQLite migration as a Phase 4+ task when multi-agent orchestration is needed. Design the `SessionStore` interface to abstract the storage backend so migration is a backend swap.

Extended state model for orchestration:
```
AgentRegistry:
    agent_id -> {session_id, thread_id, channel_id, status, spawned_at, last_heartbeat, role}

TaskRouter:
    task_id -> assigned_agent_id

MessageQueue (future):
    agent_id -> deque[maxlen=100] of pending messages
```

### 4. Existing Platforms and Patterns

Teammate B evaluated 6 categories of alternatives:

**Recommended to borrow conceptually (no dependency)**:
- **CrewAI's Flow+Crew**: Orchestrator = Flow (state machine), agent bots = Crews (worker teams). Direct architectural model.
- **AutoGen's SelectorGroupChat**: Centralized selector decides which agent speaks. Maps to bot routing.
- **Kubernetes operator pattern**: Reconciliation loop (desired state vs actual state) is implementable in ~200 lines of Python + systemd.

**Evaluated and deferred**:
- **n8n**: Closest off-the-shelf solution (native Discord node + LLM integration). Overkill for single-user MVP; keep as scaling option.
- **Temporal**: Right for durability (survives machine crashes) but operational overhead outweighs benefits at MVP scale.
- **Prefect/Airflow**: Wrong paradigm (batch-oriented, not event-driven).
- **RabbitMQ/Redis**: Overengineered for single-machine, single-user coordination. Discord itself serves as the inter-agent message bus.

### 5. Raspberry Pi Priority (from Horizons D)

**Teammate D** argues the Pi agent host should be Phase 1 infrastructure, not Phase 3 future, because:
- Always-on hosting is a dependency for mobile access (can't reach agents at a coffee shop if desktop is asleep)
- Pi costs ~5W vs 65W+ for desktop -- important for 24/7 availability
- Dedicated capacity means agent work doesn't compete with desktop workloads

**Synthesis**: The Pi is not a blocker for bot code development -- the bot can be built and tested with local `opencode serve` instances. However, Pi deployment should proceed concurrently with bot development, not after. The bot architecture should assume multiple agent hosts from Phase 1 (even if only one host exists initially).

### 6. iPhone UX: Implicit Channel Switching

**Teammate A** notes channel switching is implicit in Discord's thread model: the iPhone user taps between Discord threads, the bot listens to all threads simultaneously via the event loop. No explicit "switch" mechanism is needed. This is an architectural simplification -- the bot's `on_message` handler routes incoming messages to the correct agent based on which thread they arrived in.

### 7. Roadmap Synergy

**Teammate D** identifies that this task can accelerate 4 ROADMAP.md Phase 1 items simultaneously by mapping each to a `/rc` command that dispatches agents:
- Manifest-driven README generation -> `/rc generate-readme extension-name`
- CI doc-lint enforcement -> bot monitors CI status, alerts `#alerts`
- Slim standard enforcement -> `/rc lint-extension extension-name`
- Agent frontmatter validation -> `/rc validate-agents`

## Decisions

1. **Single bot token architecture**: Use Pattern C (Manager-Worker via Threads) with one Discord bot token for MVP. No multi-bot federation needed at single-user scale.

2. **Graduated architecture path**: Phase 1-3 as thin relay (current plan). Phase 4+ introduce Channel-Oriented Agent Teams leveraging existing `.opencode/` team-mode patterns. The `SessionStore`/`AgentRegistry` abstractions should support both from the start.

3. **P0 prerequisite resolution**: Before Phase 1 implementation begins, resolve: MESSAGE_CONTENT intent approval, `opencode run --command` blocking behavior testing, and bot permission inventory creation.

4. **Message relay hardening**: Add pagination/splitting for 2000-char responses, gateway disconnect queue, and thread auto-archive handling. These are not MVP blockers but should be in Phase 3-4.

5. **JSON store for MVP, SQLite for orchestration**: Keep JSON `sessions.json` for the thin-relay phase. Plan SQLite migration when multi-agent coordination is needed.

6. **Pi concurrent development**: Pi deployment proceeds in parallel with bot development. Bot architecture assumes multiple agent hosts from day one.

7. **Conceptual patterns from CrewAI/AutoGen**: Borrow Flow+Crew and SelectorGroupChat patterns conceptually. Do not depend on these libraries.

## Recommendations

### Immediate (before Phase 1 implementation)

1. **File for MESSAGE_CONTENT privileged intent**: Create Discord application, request the intent, document timeline. This gates the bot's ability to read thread messages.

2. **Test `opencode run --command` behavior**: Measure actual durations for `/research`, `/implement`, `/plan`. Determine if `--format json` returns events as a stream or only final result. This determines the background execution model.

3. **Create bot invite URL with exact permissions**: Include `SEND_MESSAGES_IN_THREADS`, `CREATE_PUBLIC_THREADS`, `MANAGE_THREADS`, `READ_MESSAGE_HISTORY`, `USE_APPLICATION_COMMANDS`.

### Architecture adjustments to existing plan

4. **Add pagination to `MessageRelay`** (Phase 3-4): Split responses exceeding 2000 characters across multiple messages or attach as `.txt` file.

5. **Add gateway reconnect handler** (Phase 4): Outbound message queue, state reconstruction from `sessions.json` + `opencode session list`.

6. **Set thread auto-archive to 7 days** (Phase 4): At thread creation, explicitly set `auto_archive_duration` to 10080 minutes.

7. **Add systemd security hardening** (Phase 6): `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=read-only`, `PrivateTmp=yes`.

### Strategic expansions (post-MVP)

8. **Channel-Oriented Agent Teams**: Restructure Phase 4+ to support channel-to-agent-role mapping with team-mode wave spawning.

9. **Pi agent host deployment**: Concurrent with bot development. Run `opencode serve` as systemd service on Pi.

10. **Message bus abstraction**: Design internal bus interface so switching from local subprocess to distributed agents is a backend change.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MESSAGE_CONTENT intent denied by Discord | Low | Critical | Fallback to slash-command-only mode (type `/rc relay <message>` each time); reduced UX but functional |
| `opencode run` blocks for 30+ minutes | High | High | Spawn as background subprocess; poll `opencode session list` for completion; stream JSON events incrementally |
| Thread auto-archive disrupts paused sessions | Medium | Medium | Set 7-day archive at creation; auto-unarchive on message send; heartbeat messages on `ext.tasks` loop |
| Gateway disconnect drops in-flight responses | Medium | Medium | Outbound message queue with retry; state reconstruction on reconnect |
| Pi hardware unavailable or underpowered | Low | Medium | Bot development proceeds independently on local machine; Pi is scaling target, not MVP blocker |

## Conflict Resolution

**Conflict: Thin relay (A, B) vs. Channel-Oriented Agent Teams (D)**
Resolved as: Graduated path. Thin relay for MVP (current plan Phase 1-3). COAT introduced in Phase 4+. Architecture supports both through abstracted agent/channel mappings.

**Conflict: JSON store (plan) vs. SQLite (A)**
Resolved as: JSON for MVP (adequate for single-session), SQLite migration planned for multi-agent phase. Store interface abstracts backend.

**Conflict: Pi Phase 3 (plan) vs. Pi Phase 1 (D)**
Resolved as: Pi is concurrent infrastructure, not a sequential phase. Bot code development doesn't depend on Pi, but Pi deployment proceeds in parallel. Bot architecture assumes multiple hosts from start.

No other conflicts identified -- teammate findings were largely complementary.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary architecture patterns | completed | high |
| B | Alternative platforms and prior art | completed | high |
| C | Platform constraints and gaps (Critic) | completed | high |
| D | Strategic alignment (Horizons) | completed | high |

## Appendix

### A. Key Discord API Constraints

| Constraint | Value |
|-----------|-------|
| Message content limit | 2000 characters |
| Min thread auto-archive | 60 minutes |
| Max thread auto-archive | 10080 minutes (7 days) |
| Global REST rate limit | 50 requests/second |
| Invalid request ban threshold | 10,000 per 10 minutes |

### B. Required Bot Permissions

| Permission | Purpose |
|------------|---------|
| `SEND_MESSAGES_IN_THREADS` | Sending LLM responses in threads |
| `CREATE_PUBLIC_THREADS` | Creating threads from `:OpenCodeLinkDiscord` |
| `MANAGE_THREADS` | Archiving/unarchiving, renaming threads |
| `READ_MESSAGE_HISTORY` | Seeing thread history after reconnect |
| `USE_APPLICATION_COMMANDS` | `/rc` slash commands |

### C. Required Gateway Intents

| Intent | Bit | Privileged? |
|--------|-----|-------------|
| `GUILDS` | `1 << 0` | No |
| `GUILD_MESSAGES` | `1 << 9` | No |
| `MESSAGE_CONTENT` | `1 << 15` | **Yes** |
