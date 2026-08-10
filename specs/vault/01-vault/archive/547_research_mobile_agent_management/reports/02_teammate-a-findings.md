# Teammate A -- Primary Approach: Discord Bot Orchestration Patterns

- **Task**: 547 - Research mobile agent management
- **Teammate**: A (Primary Implementation Approach)
- **Artifact Number**: 02
- **Focus**: Implementation approaches and patterns for bot-to-bot orchestration on Discord
- **Sources/Inputs**:
  - Codebase: `.opencode/skills/skill-team-research/SKILL.md`, `.opencode/skills/skill-team-implement/SKILL.md`, `.opencode/skills/skill-spawn/SKILL.md`
  - Codebase: `specs/547_.../plans/01_discord-bot-neovim-setup.md` (existing implementation plan)
  - Web: Nextcord API docs, Discord Gateway docs, Nextcord ext.tasks, Nextcord Cogs docs
  - Web: Discord developer documentation (intents, webhook, gateway events)
- **Confidence Level**: HIGH

## Key Findings

### 1. The Existing Plan Architecture Is Already a Strong Foundation

The existing implementation plan (`01_discord-bot-neovim-setup.md`) designs the bot as a **thin relay** between Discord threads and `opencode serve`. This is the right approach for a single-user scenario, but it doesn't address multi-agent orchestration because it wasn't in scope. The foundation it builds (Cogs for session/task/system management, `SessionStore` for 1:1 session-to-thread mapping, `MessageRelay` for bidirectional forwarding) is directly extensible.

**Key insight**: The current plan treats the bot as a *passive relay* -- it only forwards messages. For orchestration, the bot needs to become an *active coordinator* that can spawn, monitor, and kill sub-agent processes, route messages between them, and make decisions about which agent handles which request.

### 2. Discord Cogs Are the Natural Orchestration Unit

Each Cog in a Nextcord bot is an isolated Python class with:
- Its own state (instance attributes)
- Its own lifecycle (`cog_unload()` for cleanup)
- Inter-cog communication via `bot.get_cog('Name')`
- Dynamic loading/unloading at runtime

**Pattern**: Each sub-agent can be implemented as a **Cog** that manages its own OpenCode process/thread. The orchestrator Cog can:
```python
class OrchestratorCog(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.sub_agents: dict[str, SubAgentCog] = {}

    async def spawn_agent(self, name: str, session_id: str):
        cog = SubAgentCog(self.bot, name=name, session_id=session_id)
        await self.bot.add_cog(cog)
        self.sub_agents[name] = cog

    async def kill_agent(self, name: str):
        if name in self.sub_agents:
            await self.sub_agents[name].shutdown()
            await self.bot.remove_cog(name)
```

**Evidence**: The Nextcord Cogs documentation explicitly demonstrates `bot.get_cog('Economy')` for inter-cog communication, confirming this pattern is first-class. The `.opencode/` skill system uses Cogs-like isolation (skill-team-research spawns 4 teammates; skill-team-implement manages waves of parallel phase implementers).

### 3. Three Viable Architectural Patterns Emerge

**Pattern A -- Single Bot, Multi-Cog (Recommended for < 10 agents)**

One Discord bot token, one WebSocket connection. Each sub-agent is a Cog with its own slash command group and thread. The orchestrator Cog manages spawning, monitoring, and inter-agent routing.

- Pros: Simple, single token, no extra infra, Cogs share event loop naturally
- Cons: All agents share one rate limit (120 events/60s); if the bot crashes, all agents die
- Best for: Single-user scenarios with 2-5 sub-agents

**Pattern B -- Multi-Bot Federation (For > 10 agents or HA)**

Each sub-agent is a separate Discord bot application with its own token, process, and WebSocket. An orchestrator bot communicates with sub-agent bots via:
- Discord message passing (threads, DMs, or guild channels)
- A shared message bus (Redis pub/sub, NATS)
- Direct HTTP webhook calls

- Pros: Isolation, independent scaling, different permissions per agent
- Cons: Complex token management, inter-bot latency, harder to coordinate state
- Best for: Production deployments with many agents or high reliability needs

**Pattern C -- Manager-Worker via Threads (Optimal for this task)**

A single bot manages all channels/threads. The orchestrator doesn't need to be a separate bot -- it's a *role* within the same bot. Each "sub-agent" is really a managed OpenCode process that communicates through its dedicated Discord thread. The orchestrator switches context by reading from different threads.

- Pros: No multi-token complexity, threads provide natural isolation, iPhone user sees everything in one Discord server
- Cons: Requires careful in-memory state management; threads are ephemeral (auto-archive after inactivity)
- Best for: **The iPhone mobile agent scenario described in this task**

**Evidence from codebase**: The `.opencode/` team-mode skills use Pattern A (single process, multiple sub-agents). The `skill-spawn` skill demonstrates parent-child task relationships that map directly to orchestrator-agent relationships. The existing plan already uses threads for session isolation.

### 4. Discord Threads + Webhooks Enable Bot-to-Bot Communication Without Additional Tokens

Discord Threads provide the ideal communication channel for bot-to-bot orchestration:
- **Threads are messageable**: A bot can send messages to any thread it created (no special permissions)
- **Webhook per-thread**: Each thread/channel can have its own webhook URL for message-level granularity
- **Thread membership**: `THREAD_MEMBERS_UPDATE` event (requires `GUILD_MEMBERS` intent) tracks who joins/leaves threads
- **Message references**: `MessageReference` can link responses to specific messages for conversation threading

**Key capability**: A single bot token can:
1. Create a thread per sub-agent (as the existing plan does)
2. Send messages to any of its threads (standard `channel.send()`)
3. Listen to `on_message` events in all threads it can see
4. Use `bot.get_channel(thread_id)` to reference any known thread

**What this means**: You don't need multiple bot tokens. One bot monitoring multiple threads IS the orchestration. The Discord API supports this natively.

### 5. `nextcord.ext.tasks` Provides Built-in Health Monitoring

Nextcord's `ext.tasks` module handles all the complexity of background loops:
- Automatic reconnection after errors (exponential backoff)
- `before_loop` for initialization (e.g., `await bot.wait_until_ready()`)
- `after_loop` for cleanup
- `error` handler for unhandled exceptions
- `change_interval()` for dynamic polling frequency

**Implementation example** for agent heartbeat monitoring:
```python
from nextcord.ext import tasks

class AgentMonitor(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.agent_heartbeats: dict[str, float] = {}
        self.monitor.start()

    @tasks.loop(seconds=30)
    async def monitor(self):
        now = time.time()
        for agent_id, last_beat in list(self.agent_heartbeats.items()):
            if now - last_beat > 120:
                await self.mark_agent_dead(agent_id)

    @monitor.before_loop
    async def before_monitor(self):
        await self.bot.wait_until_ready()
```

**Evidence**: The Nextcord docs explicitly advertise this pattern with `add_exception_type()` for third-party library errors, `is_being_cancelled()` for graceful shutdown, and `failed()` for status checking. This is production-tested infrastructure.

### 6. Gateway Intents Enable Full Orchestration Awareness

Discord intents that matter for orchestration:

| Intent | Purpose | Required? |
|--------|---------|-----------|
| `GUILDS (1<<0)` | Channel/thread lifecycle events | Yes (essential) |
| `GUILD_MESSAGES (1<<9)` | Messages in guild channels/threads | Yes (essential) |
| `MESSAGE_CONTENT (1<<15)` | Read message content (privileged) | Yes (essential) |
| `GUILD_MEMBERS (1<<1)` | Thread membership tracking | Optional (nice-to-have) |
| `DIRECT_MESSAGES (1<<12)` | DM-based agent communication | Optional (Pattern B only) |

**Important**: `MESSAGE_CONTENT` is a privileged intent that requires explicit approval from Discord for verified apps (>100 guilds). For a single-user bot in <100 guilds, it's auto-granted. The existing plan already uses this intent implicitly.

### 7. State Management: Beyond JSON Store

The existing plan uses a JSON file (`sessions.json`) for session-to-thread mapping. For orchestration, the state model needs these additional tables:

```python
# Current (from existing plan)
SessionStore:
    session_id -> thread_id, channel_id

# Extended for orchestration
AgentRegistry:
    agent_id -> {session_id, thread_id, status, spawned_at, last_heartbeat, role}
    - status: idle | busy | dead | stopping

TaskRouter:
    task_id -> assigned_agent_id
    - Tracks which agent is handling which task

MessageQueue (optional, for Pattern B):
    agent_id -> deque[maxlen=100] of pending messages
    - Buffers messages when target agent is busy
```

**Critical design decision**: State should be stored in a SQLite database (via aiosqlite), not JSON. Reasons:
- Atomic transactions (no risk of corrupted state on crash)
- Concurrent access safe (multiple Cogs reading/writing simultaneously)
- Queryable (find all busy agents, count tasks by agent, etc.)
- Already available on NixOS (python3Packages.aiosqlite)

**Challenge to the existing plan**: The JSON file store is fine for a simple 1:1 relay but insufficient for orchestration where multiple agents, routing decisions, and race conditions exist. Recommend upgrading from JSON to SQLite in a future iteration.

### 8. Channel-Switching Is Implicit in Thread Architecture

The task mentions "switching between channels when needed." With Discord threads:
- The iPhone user doesn't "switch channels" -- they tap on different threads in Discord
- The orchestrator bot doesn't "switch" -- it listens to all threads simultaneously via the event loop
- Context is preserved per-thread (Discord keeps message history)

This means the orchestration is **event-driven**, not polling-based. The bot's `on_message` handler routes incoming messages to the correct agent based on which thread they arrived in:

```python
@bot.event
async def on_message(message):
    if message.author == bot.user:
        return  # Don't respond to self

    agent = registry.lookup_by_thread(message.channel.id)
    if agent is None:
        # Message in unmanaged channel -- maybe route to orchestrator
        await orchestrator.handle_unrouted_message(message)
        return

    await agent.handle_message(message)
```

## Recommended Approach

For the specific scenario (iPhone user -> Discord -> orchestrator bot manages sub-agents):

1. **Use Pattern C (Manager-Worker via Threads)** with a single bot token
2. **Extend the existing plan's SessionStore** with AgentRegistry capabilities
3. **Implement agent lifecycle as Cogs** that manage their own OpenCode subprocess
4. **Use `nextcord.ext.tasks`** for health monitoring, not custom loops
5. **Upgrade state storage to SQLite** when you need concurrent agent coordination
6. **Channel context switching is implicit** -- the bot listens to all threads, iPhone user taps between them

## Evidence/Examples

### Example: Orchestrator Command Flow
```
iPhone user: /rc agent spawn "code review agent"
Bot creates: new thread #subagent-code-review
Bot spawns: OpenCode process with session code-review-001
Bot stores: agent_id, thread_id, session_id in registry
Bot responds: "Agent 'code review agent' ready in #subagent-code-review"

iPhone user: [switches to #subagent-code-review thread]
iPhone user: "Review the changes in src/bot.py"
Bot routes: message to code-review-001 session via opencode run
OpenCode responds: [review output]
Bot posts: response in #subagent-code-review thread

iPhone user: /rc agent list
Bot responds: "Active agents: code-review (busy), task-runner (idle)"
```

### Pattern from .opencode/ team skills (adapted)

The `skill-team-research` spawns 4 teammates with letters (a, b, c, d), each writing to a scoped path. This is isomorphic to Discord orchestration:
- Teammate = Sub-agent Cog
- Teammate letter = Agent ID
- `run_padded` = Artifact number (shared across teammates)
- Output files = Discord threads with per-agent messages
- Lead synthesis = Orchestrator Cog aggregating results

The wave-based execution in `skill-team-implement` (independent phases in parallel, dependent phases sequential) maps directly to agent task assignment: assign independent tasks to idle agents in parallel, queue dependent tasks.

## Confidence Level

**HIGH** (0.9/1.0)

The patterns described are backed by:
1. Live Nextcord API documentation (v3.1.1, current as of May 2026)
2. Discord Gateway docs confirming thread, webhook, and intent capabilities
3. Existing `.opencode/` skills already implementing isomorphic orchestration patterns
4. The existing implementation plan providing a compatible foundation

The primary uncertainty is how well SQLite performs under concurrent Cog access (mitigated by aiosqlite's async design and WAL mode), and whether the `MESSAGE_CONTENT` intent approval process poses any friction (unlikely for single-user bots).
