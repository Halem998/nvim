# Research Report: Alternative Orchestration Patterns for Discord Bot Agent Management

**Task**: 547 - research_mobile_agent_management
**Started**: 2026-05-07T17:35:00Z
**Completed**: 2026-05-07T18:30:00Z
**Effort**: 55 minutes
**Dependencies**: Teammate A report (01_mobile-agent-management-research.md)
**Sources/Inputs**:
  - Web: n8n workflows and Discord integration (n8n.io, blog.n8n.io)
  - Web: Prefect workflow orchestration docs (docs.prefect.io)
  - Web: Apache Airflow 3.2.1 docs (airflow.apache.org)
  - Web: Temporal Python SDK developer guide (docs.temporal.io)
  - Web: Kubernetes operator pattern (kubernetes.io)
  - Web: RabbitMQ messaging tutorial (rabbitmq.com)
  - Web: Redis pub/sub docs (redis.io)
  - Web: Discord Channels Resource (developers docs), Stage Instance Resource, Forum Channels FAQ
  - Web: AutoGPT platform docs (github.com/Significant-Gravitas/AutoGPT)
  - Web: Microsoft AutoGen AgentChat architecture (microsoft.github.io/autogen)
  - Web: CrewAI docs -- Crews, Flows, orchestration patterns (docs.crewai.com)
  - CLI: `opencode run --help` verified on system
**Artifacts**:
  - specs/547_research_mobile_agent_management/reports/02_teammate-b-findings.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- **n8n is the standout existing platform** for Discord bot orchestration -- it has a native Discord node, ships a self-hostable open-source version, and already has a "ChatGPT Discord bot" workflow template demonstrating the exact bot-to-LLM relay pattern needed, with zero custom code
- **Three mature workflow engines** (Prefect, Airflow, Temporal) offer robust orchestration primitives (retry, state tracking, DAG execution, scheduling) that could be adapted -- but their operational overhead outweighs benefits for a single-user bot system
- **CrewAI's Flow + Crew architecture** is the closest existing multi-agent orchestration pattern: a "Flow" (event-driven state machine) delegates work to "Crews" (agent teams), mirroring exactly what a Discord bot orchestrator would do
- **Microsoft AutoGen's Team + SelectorGroupChat pattern** provides a battle-tested model for multi-agent coordination via a centralized selector -- directly applicable to a Discord bot dispatching across channels
- **Discord Forum Channels as agent workspaces** and **Stage Channels for agent briefings** are genuinely creative, under-exploited patterns that could provide native-structured orchestration without building custom state management
- **Systemd as an orchestration backbone** (for `opencode serve` lifecycle) maps well: the existing timer/service pattern in `.opencode/systemd/` is a proven template for managing agent daemons
- **The simplest viable approach** is `opencode run --command research --attach http://localhost:4096 --format json --dangerously-skip-permissions` -- a thin Discord relay bot that delegates to the already-mature OpenCode CLI, avoiding any custom orchestration protocol entirely
- **Event-driven architectures (RabbitMQ, Redis pub/sub) add operational complexity** disproportionate to a single-user system -- they solve distributed coordination problems that don't yet exist here

## Context & Scope

This research is Teammate B's contribution to task 547 -- focused on **alternative patterns, prior art, and creative angles** that complement Teammate A's research on primary approaches (OpenCode CLI capabilities, Nextcord bot library, systemd patterns, Pi hosting).

The six investigation angles were:

1. Existing bot frameworks/orchestration platforms that could be adapted (n8n, Temporal, Prefect, Airflow)
2. DevOps/infrastructure orchestration patterns (Kubernetes operator, process supervisors)
3. Discord's built-in features used creatively (forum channels, stage channels)
4. Event-driven architectures (message queues, WebSocket-based coordination)
5. Multi-agent system orchestration patterns (AutoGPT, CrewAI, AutoGen)
6. Simpler CLI-based orchestration approaches

## Findings

### 1. Existing Orchestration Platforms: What Can Be Adapted

#### 1a. n8n -- The Standout Platform (Confidence: HIGH)

**What it is**: n8n is a self-hostable, open-source (184k+ GitHub stars) workflow automation platform with 9500+ community templates. It has a native Discord node and a native OpenAI/LLM node.

**Why it matters for bot orchestration**:
- n8n already ships a **native Discord integration** that can both receive messages and post to channels via webhooks
- It already has a documented tutorial: "How to create a ChatGPT Discord bot" (blog.n8n.io, July 2023) demonstrating the exact pattern: Discord webhook → GPT analysis → route to different Discord channels based on classification
- The pattern shown in that tutorial is: receive a message, have GPT classify it, then route it to different Discord channels (success-story channel, urgent-issue channel, ticket channel). This is **exactly** the agent-dispatch pattern we need
- n8n's visual workflow builder means you could configure agent routing rules without writing custom orchestration code
- Self-hosted n8n runs on Node.js -- same runtime as OpenCode
- Discord node in n8n can be both a trigger (receive messages) and an action (post results)

**Adaptation opportunity**: Instead of building a custom Discord bot with Nextcord, you could run n8n as the orchestration layer. Each agent bot maps to a Discord output node. GPT classification replaces custom command parsing. The n8n workflow IS the orchestration logic.

**Limitations**:
- n8n adds operational overhead (another service to maintain)
- For a single-user system, n8n's enterprise features are overkill
- The visual workflow paradigm may be less flexible than Python for complex agent routing logic

#### 1b. Prefect -- DAG-Based Bot Orchestration (Confidence: LOW)

**What it is**: Prefect is a Python workflow orchestration tool (DAGs, tasks, flows, scheduling, retries, state tracking).

**Why it's relevant**:
- Prefect's `@flow` and `@task` decorators provide automatic state tracking, retries, and scheduling
- Prefect's deployment model (`flow.serve()`) lets you run workflows as persistent services
- Its state machine (Scheduled → Pending → Running → Completed/Failed) maps cleanly to bot task lifecycles
- Prefect's `@task` with `return_state=True` allows for graceful failure handling without crashing the orchestrator

**Why it's a poor fit**:
- Prefect is designed for data pipelines, not real-time chat interactions
- The overhead of Prefect's server (even in open-source mode) adds complexity disproportionate to a single-user bot system
- Prefect expects batch-oriented workflows; Discord bot messages are event-driven and interactive
- You'd be fighting the framework's paradigm constantly

#### 1c. Apache Airflow -- Explicitly Wrong for This (Confidence: HIGH)

Airflow's own documentation states: *"Airflow is not intended for continuously running, event-driven, or streaming workloads."* Discord bot orchestration is fundamentally event-driven. Airflow is designed for scheduled batch DAGs -- it would require constant polling or unnatural hacks to work with real-time Discord messages. This is a clear non-starter.

#### 1d. Temporal -- Durable Execution for Agent Workflows (Confidence: MEDIUM)

**What it is**: Temporal is a durable execution platform -- workflows survive crashes, retry indefinitely, and maintain state across failures.

**Why it's relevant**:
- Workflows can run for days/weeks -- useful for long-running agent tasks
- Temporal's Activity model handles external API calls (like Discord message sending) with automatic retries
- Child Workflows map conceptually to "delegating a subtask to another agent bot"
- Temporal's Signal pattern allows external events (e.g., a Discord message) to interrupt or guide a running workflow

**Why it's overkill for now**:
- Temporal requires running a Temporal Server (another service), plus Workers
- Setup complexity is substantial -- designed for distributed systems with dozens of services
- For a single-user system, Temporal's durability guarantees solve problems that don't exist yet
- **However**: if this system ever grows to dozens of agent bots running long, multi-hour tasks, Temporal becomes the right answer. Keep it in mind as a scaling target

**Verdict**: Temporal is the right tool for "agent bot runs a 3-hour task and must not lose state if the Pi crashes" -- but that's a future problem. For MVP, skip it.

### 2. DevOps/Infrastructure Patterns for Bot Orchestration

#### 2a. Kubernetes Operator Pattern -- Conceptual Map (Confidence: MEDIUM)

The Kubernetes operator pattern has a useful conceptual mapping to bot orchestration:

| K8s Concept | Bot Orchestration Analog |
|-------------|--------------------------|
| Custom Resource (CR) | Agent bot definition (what it does, what tools it has) |
| Operator reconciler loop | Orchestrator bot continuously checks agent state |
| Desired state vs actual state | Desired: "agent X should analyze this PR" / Actual: "agent X is idle" |
| Status subresource | Agent bot reports back status |
| Finalizers | Cleanup hooks when agent bot session ends |

The core insight: **the operator pattern is a reconciliation loop** -- constantly comparing desired state (what tasks need doing) to actual state (what agents are doing) and taking corrective action. A Discord orchestrator bot could use the same pattern: poll agent bots for status, assign new tasks to idle agents, retry failed tasks.

**Practical takeaway**: You don't need K8s -- you can implement the operator reconciliation pattern in ~200 lines of Python using systemd as the "container runtime" and a SQLite database as the "etcd store."

#### 2b. Systemd as Process Supervisor -- Already Proven (Confidence: HIGH)

Teammate A already identified this, but it's worth reinforcing: the existing systemd timer/service pattern at `.opencode/systemd/` is the right foundation:

```
.opencode/systemd/
├── claude-refresh.service + claude-refresh.timer   # Periodic cleanup
├── opencode-refresh.service + opencode-refresh.timer # OpenCode-specific
```

Adding:
```
opencode-discord-bot.service    # The Discord bot (persistent daemon)
opencode-agent-server.service   # opencode serve instances per agent
```

Systemd handles: auto-restart on crash, dependency ordering (network → bot → agent servers), logging (journald), resource limits, and credential injection (via `LoadCredential` from sops-nix). This is battle-tested infrastructure -- no need to reinvent it.

**The supervisord comparison**: supervisord (Python process supervisor) offers similar functionality but systemd is already native to NixOS and already proven in this codebase. Don't add supervisord.

### 3. Discord's Built-in Features Used Creatively

This is potentially the most under-explored angle. Discord's channel types have matured significantly in 2024-2026.

#### 3a. Forum Channels as Agent Task Boards (Confidence: MEDIUM)

Discord Forum Channels (type 15, available on Community servers since 2022) are purpose-built for organized, tagged discussions. Each "post" in a forum is a thread with tags.

**Creative application to bot orchestration**:
- Each **forum post** = one agent task (e.g., "research task 547")
- Forum **tags** = task status (`[TODO]`, `[IN_PROGRESS]`, `[DONE]`, `[BLOCKED]`)
- The primary orchestrator bot creates new forum posts for new tasks
- Agent bots claim tasks by posting in the thread ("Agent X starting work")
- Tags are updated as tasks progress
- Completed tasks get auto-archived (Discord's "Hide After Inactivity" feature -- configurable 1h/24h/3d/1w)
- Forum's built-in search lets you find past tasks
- The "pin post" feature acts as a "current priority" indicator
- Users browse tasks via Discord's native forum UI -- **zero custom UI needed**

**Why this is clever**:
- You get persistent task history (Discord stores message history, not you)
- You get threaded discussions per task (agents discuss in-thread)
- You get native filtering by tags
- You get native search
- No custom database needed -- Discord IS your task database

**Limitations**:
- Discord forum channels are user-facing features, not designed for bot-to-bot API usage
- Bots can create forum posts via the API (POST /channels/{channel.id}/threads with `type: 15`), but the API was designed for user interaction
- Rate limits on thread creation could bottleneck high-frequency task creation
- Forum channels require the server to be a Community server (minor overhead)
- Reliance on Discord as a "database" for task state is brittle -- if Discord has an outage, you lose visibility into task state

#### 3b. Stage Channels for Agent Briefings (Confidence: LOW-to-MEDIUM)

Discord Stage Channels (type 13) are designed for "one person speaking, audience listening" -- like a podcast or presentation.

**Creative (if whimsical) application**:
- When the orchestrator bot needs to "brief" multiple agent bots simultaneously, it could open a Stage Channel with the topic set to the briefing subject
- The orchestrator "speaks" (posts the briefing as a text message pinned to the stage)
- Agent bots join as "audience" and acknowledge via reactions
- After the briefing, the stage closes

**Why this is mostly impractical**:
- Stage Channels are audio-focused -- their text capabilities are secondary
- Bots can't meaningfully "speak" or "listen" in a stage channel
- The stage instance API (POST /stage-instances) requires moderator permissions
- This is a clever metaphor but an awkward technical fit
- **However**: the "Stage Channel as briefing room" could work as a Voice Channel alternative if you want to verbally brief an agent (e.g., "Agent, here's what I need you to do") via TTS output

**Verdict**: Stage Channels are a creative metaphor but not a practical orchestration primitive. Forum Channels, however, are genuinely interesting.

#### 3c. Discord Threads for Session Isolation (Already Identified by Teammate A)

Teammate A already correctly identified Discord threads as session isolation. Reinforcing: Discord's thread model (private threads for agent-to-agent conversations, public threads for user-visible agent output) is the right isolation primitive.

### 4. Event-Driven Architectures for Bot Coordination

#### 4a. RabbitMQ -- Robust but Heavy (Confidence: LOW for MVP)

RabbitMQ provides pub/sub, work queues, routing keys, and topic exchanges. In theory:
- Each agent bot subscribes to a queue named after its capability
- The orchestrator publishes tasks to the appropriate exchange with routing keys
- Agent bots consume from their queues

**Why this is overengineered for a single-user system**:
- RabbitMQ is a separate service requiring installation, configuration, and monitoring
- For 2-3 agent bots on a single machine, the coordination problem is trivial -- you don't need a message broker
- Local inter-process communication (HTTP to `opencode serve`, Unix sockets, or even Python's `multiprocessing.Queue`) is simpler
- RabbitMQ solves distributed coordination at scale -- not relevant yet

#### 4b. Redis Pub/Sub -- Lighter but Still Unnecessary (Confidence: LOW)

Redis pub/sub is lighter than RabbitMQ but still adds operational complexity:
- Redis server needs to be running
- Pub/sub messages are fire-and-forget (no guaranteed delivery)
- For bot-to-bot communication on a single machine, it's overkill

#### 4c. WebSocket-Based Coordination (Confidence: LOW)

Some multi-agent systems use WebSocket connections for real-time coordination between agents. Discord's Gateway API already uses WebSocket connections -- each bot maintains a persistent WebSocket to Discord.

**Insight**: If you need agent-to-agent real-time messaging, you already have the Discord WebSocket connection -- agent bots can communicate via Discord channels (post messages) rather than a separate coordination protocol. Discord IS the message bus.

#### 4d. The Discord-as-Message-Bus Pattern (Confidence: MEDIUM)

The simplest event-driven pattern: agent bots communicate by posting messages to designated Discord channels, and the orchestrator bot listens to those channels. This is:
- Zero additional infrastructure (Discord provides the message delivery)
- Naturally persistent (Discord stores message history)
- Naturally observable (you can scroll up and see what agents said to each other)
- Naturally rate-limited (Discord's built-in rate limiting prevents agent spam)

The downside: latency. Discord message delivery has ~200-500ms latency vs. ~1ms for local IPC. But for agent coordination (tasks taking minutes to hours), this latency is negligible.

### 5. Multi-Agent System Orchestration Patterns (2026)

#### 5a. CrewAI -- Flow + Crew Architecture (Confidence: HIGH for pattern inspiration)

CrewAI (2026) has a two-layer architecture that maps perfectly to Discord bot orchestration:

| CrewAI Concept | Discord Bot Analog |
|----------------|--------------------|
| **Flow** (event-driven state machine, manages state, decides what to do next) | **Orchestrator bot** -- receives user requests, manages task state, routes to agents |
| **Crew** (team of agents with roles and tools, autonomous collaboration) | **Agent bots** -- specialized bots (research agent, implement agent) in different channels |
| Flow delegates to Crew → Crew returns result → Flow continues | Orchestrator posts task to agent channel → Agent works → Agent reports back → Orchestrator routes result to user |

CrewAI's specific patterns worth borrowing:
- **Role-playing agents**: Each agent has a `role`, `goal`, and `backstory` -- this maps to defining agent bot personalities in Discord
- **Sequential vs. Hierarchical process**: Crews can execute tasks sequentially (one agent after another) or hierarchically (a manager agent delegates)
- **Memory**: Crews have short-term, long-term, and entity memory -- useful for agent bots that need context across sessions
- **Checkpointing**: Crews can save/resume state -- useful for long-running agent tasks
- **Streaming output**: Real-time visibility into agent execution -- maps to Discord messages streaming agent progress

**Key architectural insight from CrewAI**:
> "Start with a Flow. Use a Flow to define the overall structure, state, and logic of your application. Use a Crew within a Flow step when you need a team of agents."
>
> Translation for Discord: the orchestrator bot IS the Flow. Individual agent bots are Crew members. The Flow pattern provides the right separation of concerns.

#### 5b. Microsoft AutoGen -- SelectorGroupChat Pattern (Confidence: MEDIUM)

AutoGen (Microsoft, 2024-2026) has a `SelectorGroupChat` pattern where:
- Multiple agents share a **common conversation context**
- A **centralized selector** (could be LLM-based or rule-based) decides which agent speaks next
- Agents can be specialized (researcher, coder, reviewer)

**Direct Discord mapping**:
- The Discord channel IS the shared conversation context
- The orchestrator bot IS the centralized selector
- Agent bots post when selected, then yield

AutoGen's specific insights:
- The **Swarm pattern** (vs. Selector Group Chat): agents use tool-based handoffs rather than a central selector. "Agent A finishes, decides Agent B should handle the next step, hands off." This is more autonomous but harder to control.
- **Magentic-One**: AutoGen's multi-agent system for complex tasks uses a Orchestrator agent that plans, delegates, and tracks progress -- directly applicable

#### 5c. AutoGPT -- Platform Pattern (Confidence: MEDIUM)

AutoGPT has evolved from a single agent to a **platform** with blocks, marketplace, and deployment controls. In 2026, it's positioned as "build, deploy, and manage AI agents."

**Relevant pattern**: AutoGPT's **Agent Builder** uses "blocks" (single-action components) connected in workflows. This is a visual orchestration metaphor.

**What to borrow**: The concept of agent agents as composable blocks -- define an agent by composing capabilities (can research, can write code, can review PRs), then the orchestrator routes to the right agent based on capability matching.

### 6. The CLI-Based Simpler Approach

#### 6a. opencode run as Orchestration Layer (Confidence: HIGH)

The simplest viable approach, validated by examining the actual CLI:

```bash
opencode run --command research --attach http://localhost:4096 \
  --agent general-research-agent --format json \
  --dangerously-skip-permissions "Research task 547: ..."
```

This approach uses:
- `--command` for named commands (research, plan, implement, etc.)
- `--attach` to connect to a specific agent server (each agent bot on a different port)
- `--agent` for agent selection
- `--format json` for machine-parseable output
- `--dangerously-skip-permissions` for unattended operation
- `--session` / `--continue` for multi-turn conversations

**Architecture for the CLI-based approach**:

```
┌──────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  iPhone/Discord  │────▶│  Orchestrator Bot    │────▶│  opencode serve   │
│  User types msg  │     │  (Nextcord Python)   │     │  :4096 (research) │
└──────────────────┘     │                      │     └──────────────────┘
                         │  Parses user intent  │
                         │  Routes to agent     │     ┌──────────────────┐
                         │  Calls opencode run  │────▶│  opencode serve   │
                         │  Returns result      │     │  :4097 (implement)│
                         └─────────────────────┘     └──────────────────┘
```

**Why this is the right MVP approach**:
1. **Zero custom agent protocol**: OpenCode already has a mature CLI and server-client model. Don't build a new one.
2. **Battle-tested**: The `opencode run` command already handles LLM interaction, tool execution, permissions, and output formatting. It's been tested across thousands of interactions.
3. **Thin Discord bot**: The bot only needs to parse user intent from Discord messages (slash commands or natural language), route to the right `opencode run --attach` call, and relay the JSON output back.
4. **Simple NixOS deployment**: A single Python script + systemd service. No additional infrastructure.
5. **Gradual complexity**: Start with CLI orchestration. If it becomes limiting, add a message queue or Temporal later.

**The key constraint**: `opencode run` is **synchronous** by default -- it blocks until the agent completes. For long-running tasks, the bot would need to:
- Option A: Run `opencode run` in a background subprocess, poll for completion, then relay results
- Option B: Use `opencode run --fork --session <id>` for async workflows
- Option C: Run `opencode run` with a timeout, report partial results

Teammate A's linking flow (`:OpenCodeLinkDiscord` → Discord thread bound to session) already solves this for interactive sessions. But for fire-and-forget "agent X do task Y" commands, the bot needs a background execution model.

## Decisions

1. **n8n as orchestration layer**: Not recommended for MVP -- operational overhead exceeds benefit for a single-user system. But keep it in mind if the system ever needs visual workflow configuration for non-technical users.

2. **Systemd as process supervisor**: Strongly endorse. It's already proven in this codebase and is the native NixOS service manager. No need for supervisord or Docker.

3. **Discord Forum Channels for task tracking**: Intriguing but not recommended as the primary task store. Use it as a complementary "task dashboard" view. The primary task store should remain `specs/TODO.md` + `state.json` (what OpenCode already manages).

4. **Message queues (RabbitMQ, Redis)**: Not recommended for MVP. They solve distributed coordination problems that don't exist at single-user scale. Discord itself can serve as the inter-agent message bus.

5. **CLI-based orchestration** (`opencode run --command`): **Recommended as the primary orchestration approach for MVP.** The orchestrator bot is a thin relay: Discord message → parse intent → `opencode run --command <cmd> --attach <server>` → relay JSON output to Discord.

6. **CrewAI/AutoGen patterns to borrow conceptually** (not as dependencies): The Flow+Crew separation (orchestrator as state machine, agent bots as workers) and the SelectorGroupChat pattern (centralized selector decides who speaks) are valuable architectural metaphors even if we don't use the libraries.

## Recommendations

### Approach A (Recommended for MVP): Thin Discord Bot + opencode CLI

The orchestrator bot is a ~300-line Python script using Nextcord that:
1. Receives `/rc` slash commands or natural language messages in Discord
2. Maps commands to `opencode run --command` invocations with appropriate `--attach` targets
3. Streams JSON events back to Discord as messages
4. Tracks active sessions via `opencode session list`

**Pros**: Minimal code, leverages mature CLI, zero custom orchestration protocol.
**Cons**: Synchronous `opencode run` blocks the bot; need background execution for long tasks.

### Approach B (Future scaling): CrewAI-inspired Flow Orchestrator

If CLI-based becomes limiting, build a Python-based "Flow" (inspired by CrewAI) that:
1. Manages agent bot state in a SQLite database
2. Dispatches tasks to agent bots via `opencode run --attach`
3. Implements the Kubernetes operator reconciliation loop: poll agents, detect stalled tasks, retry failures
4. Uses Discord threads as the user-facing interface (already designed by Teammate A)

**Pros**: More robust for long-running tasks, supports agent health monitoring.
**Cons**: ~1000 lines of new code, more complex state management.

### Approach C (Maximum Scale): Temporal Durable Execution

If the system grows to dozens of agents running multi-hour tasks across multiple machines (Pi cluster), adopt Temporal. The orchestrator becomes a Temporal Workflow, and each agent bot is a Temporal Activity.

**Pros**: Battle-tested durability guarantees, survives machine crashes, automatic retry with backoff.
**Cons**: Significant operational complexity, new infrastructure dependency.

**Phasing**: Approach A for Phase 1 (MVP), Approach B for Phase 2 (multi-agent expansion), Approach C for Phase 3 (Pi cluster at scale).

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `opencode run --command` is too slow for real-time Discord interaction | Medium | Medium | Use `--format json` for streaming progress; show "Agent working..." status messages |
| Discord Forum Channels API changes break agent task boards | Low | Low | Forum channels are complementary, not primary; task state lives in `state.json` |
| CLI-based approach doesn't handle concurrent agent tasks | Medium | Medium | Run multiple `opencode serve` instances on different ports; the orchestrator manages concurrency via subprocess |
| Growing beyond single-user makes CLI approach brittle | Medium | High | Plan the upgrade path to Approach B (Flow Orchestrator) from the start -- keep orchestrator logic modular |

## Context Extension Recommendations

- **Topic**: Discord as infrastructure -- using Discord's native features (channels, threads, forums) as orchestration primitives rather than building custom infrastructure
- **Gap**: No documentation exists on Discord-as-infrastructure patterns
- **Recommendation**: If Forum Channels or Threads-as-sessions prove valuable, document the "Discord-native orchestration" pattern in `.opencode/context/patterns/discord-infrastructure.md`

## Appendix

### A. n8n Discord Bot Tutorial Workflow (reference)
From blog.n8n.io (July 2023): Webhook → OpenAI (GPT-4 classification) → Switch node (by category) → Discord nodes (separate channels per category). This is the closest existing implementation to what we need.

### B. OpenCode CLI Orchestration Command Template
```bash
# Research agent on port 4096
opencode run --command research --attach http://localhost:4096 \
  --agent general-research-agent --format json \
  --dangerously-skip-permissions "Research task N: <description>"

# Implementation agent on port 4097
opencode run --command implement --attach http://localhost:4097 \
  --agent general-implementation-agent --format json \
  --dangerously-skip-permissions "Implement phase X of task N"

# Continue an existing session
opencode run --session <session-id> --attach http://localhost:4096 \
  --format json --dangerously-skip-permissions "Continue with..."
```

### C. Discord Channel Types Relevant to Orchestration
| Type | ID | Orchestration Use |
|------|----|--------------------|
| GUILD_TEXT | 0 | Agent output channels, command channels |
| GUILD_CATEGORY | 4 | Group agent channels by team/function |
| GUILD_STAGE_VOICE | 13 | Agent briefings (creative, low practicality) |
| GUILD_FORUM | 15 | Agent task boards (genuinely interesting pattern) |
| PUBLIC_THREAD | 11 | Per-task discussion threads |
| PRIVATE_THREAD | 12 | Agent-to-agent private coordination |

### D. Multi-Agent Orchestration Pattern Summary Table

| System | Orchestration Model | Discord Applicability | Adoption Complexity |
|--------|---------------------|----------------------|---------------------|
| CrewAI | Flow (state machine) + Crews (agent teams) | HIGH -- Flow = orchestrator, Crew = agent bots | Pattern only (not dependency) |
| AutoGen | SelectorGroupChat (centralized) / Swarm (decentralized) | HIGH -- centralized selector maps to orchestrator bot | Pattern only |
| AutoGPT | Blocks + marketplace + deployment | MEDIUM -- block composition pattern useful | Pattern only |
| n8n | Visual workflow with native Discord node | HIGH -- could replace custom bot entirely | Medium (new service) |
| Temporal | Durable workflows + activities | MEDIUM -- right for scale, overkill for MVP | High (new infrastructure) |
| Prefect | DAG-based flows + tasks + scheduling | LOW -- batch-oriented, wrong paradigm | Low (but wrong fit) |
| Airflow | Scheduled batch DAGs | NONE -- explicitly event-averse | n/a |
