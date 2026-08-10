# Horizons Research: Strategic Analysis of Agent Orchestration via Discord

**Task**: 547 - research_mobile_agent_management
**Teammate**: D (Horizons)
**Model**: Claude Sonnet 4.6
**Date**: 2026-05-07

## Key Findings

### Finding 1: The "Thin Relay" Architecture Is Strategically Insufficient

The existing plan (01_discord-bot-neovim-setup.md) proposes a Discord bot that acts as a thin relay between Discord threads and a single `opencode serve` instance. While technically sound for MVP, this architecture fundamentally misses the strategic opportunity: **the Discord bot should be a multi-agent orchestrator, not a session relay**.

Evidence from the codebase:

- `.opencode/skills/skill-team-research/SKILL.md` already implements wave-based parallel agent execution with 4 teammates (Primary, Alternatives, Critic, Horizons) and a synthesis phase. This is the proven pattern.
- `.opencode/skills/skill-team-implement/SKILL.md` parallelizes implementation phases across teammates with dependency-aware wave scheduling.
- `.opencode/agent/` defines 8 subagent types (general-research, general-implement, planner, meta-builder, code-reviewer, reviser, spawn, orchestrator) -- all ready to be invoked programmatically.

The current architecture would limit the user to one session per Discord thread, manually switching contexts. The strategic architecture should be: **one Discord server = one agent fleet, with channels mapping to agent teams and roles**.

### Finding 2: Discord Channels Should Map to Agent Roles, Not Sessions

The current plan maps "1 Discord thread = 1 OpenCode session." This is a tactical mapping that misses the strategic fit. Discord's native structure is already an agent coordination UI:

| Discord Channel | Agent Team Role | OpenCode Mapping |
|----------------|-----------------|------------------|
| `#orchestrator` (iPhone primary) | Mission Control | Lead agent dispatches teams and synthesizes |
| `#research` | Research Team | 2-4 research agents running in parallel |
| `#planning` | Planning Team | Planner agents producing phased plans |
| `#implementation` | Build Team | Implementer agents executing phases |
| `#review` | Quality Team | Code-reviewer agent checking output |
| `#alerts` | Monitoring | Agent status, errors, timeouts, health |

This channel-to-role mapping means from an iPhone, the user opens `#orchestrator` and types `/rc research task 548`, and the bot spawns a full research wave across 4 agents, with results synthesized back to `#orchestrator`. This is the team-mode pattern from skill-team-research, but exposed through Discord instead of internal process spawning.

**This is not a speculative idea -- the team orchestration infrastructure already exists in the codebase.** The Discord bot just needs to invoke the same patterns that skill-team-research and skill-team-implement already use.

### Finding 3: A Unified Message Bus Architecture Solves Mobile + Pi + Local Agents Simultaneously

The current plan treats mobile access (Discord bot), Pi agent hosts, and local Neovim sessions as three separate concerns connected by ad-hoc bridges (HTTP API for Neovim link, `opencode run --attach` for Pi). This is architecturally fragile.

**Recommendation: A message bus architecture where all agent hosts (local, Pi, future hosts) and all UIs (Discord, Neovim, web) connect to a shared bus.**

```
┌─────────────────────────────────────────────────────────────┐
│                      Message Bus (NATS/Redis)               │
│                                                             │
│  Channels: orchestrator.*, research.*, impl.*, health.*     │
└──────┬──────────┬──────────┬──────────┬─────────────────────┘
       │          │          │          │
   ┌───┴───┐  ┌───┴───┐  ┌───┴───┐  ┌───┴───┐
   │ Discord│  │Neovim │  │  Pi   │  │ Local │
   │  Bot   │  │  UI   │  │ Agent │  │ Agents│
   │ (Pub)  │  │(Pub)  │  │ Host  │  │ (Sub) │
   └───────┘  └───────┘  └───────┘  └───────┘
```

Benefits of this architecture:

1. **Any UI can publish commands** -- Discord bot, Neovim, web interface, REST API, SSH
2. **Any agent host can subscribe** -- local process, Pi, Docker container, cloud VM
3. **Health monitoring is built-in** -- agents publish heartbeats, bus handles timeouts
4. **Scaling is natural** -- add more agent hosts by connecting them to the bus
5. **The Discord bot becomes the orchestrator, not a bridge** -- it publishes commands and agent hosts pick them up based on capability/capacity
6. **Roadmap items become autonomous agents** -- a "doc-gen agent" subscribes to `docs.generate.*` and publishes to `docs.output.*`

### Finding 4: This Task Can Simultaneously Advance 4 Roadmap Items

The ROADMAP.md lists 7 items in Phase 1. Task 547's bot architecture can directly advance at least 4 of them:

| Roadmap Item | How Bot Orchestration Accelerates It |
|-------------|--------------------------------------|
| **Manifest-driven README generation** | `/rc generate-readme extension-name` dispatches a research agent to read the manifest, produce a README, and publish it |
| **CI enforcement of doc-lint** | The bot can monitor CI status via GitHub webhooks, alerting the `#alerts` channel on doc-lint failures and auto-creating fix tasks |
| **Extension slim standard enforcement** | `/rc lint-extension extension-name` dispatches a validation agent that checks the standard and reports violations |
| **Agent frontmatter validation** | `/rc validate-agents` scans all agent/skill files and reports frontmatter compliance status |

The Discord bot doesn't just *access* the agent system -- it **becomes the primary interface for executing roadmap tasks**, which accelerates the roadmap itself.

### Finding 5: The Discord Bot Should Replace the Read-Only Orchestrator

The current orchestrator (`.opencode/agent/orchestrator.md`) is explicitly read-only -- it answers questions but cannot dispatch work. This was a deliberate safety choice, but it creates a gap: **there is no active orchestrator in the system**. The `/research`, `/plan`, `/implement` commands each do their own coordination via the skill system, with no central coordination layer.

The Discord bot should fill this gap:

```
Current:  command files → skills → agents (decentralized, no central view)
Proposed: Discord bot → message bus → skills → agents (centralized, observable)
```

The Discord bot becomes **Mission Control** -- it knows what every agent is doing, tracks task state across the fleet, and can re-prioritize or cancel work. From an iPhone, the user sees the full fleet status in one `#orchestrator` channel.

### Finding 6: The Raspberry Pi Host Is Not "Phase 3 Future" -- It's the Strategic Direction

The current plan defers Pi agent host to Phase 3 (future). This is backwards. The **Raspberry Pi agent host is the strategic driver** for the entire architecture:

1. **Energy efficiency**: A Pi 5 running `opencode serve` costs ~5W of power vs. 65W+ for a desktop. For always-on agent availability, this matters enormously.
2. **Dedicated capacity**: The Pi handles background agent work without competing with desktop workloads (gaming, video editing, 20 Neovim buffers).
3. **Network isolation**: Pi agents on a separate subnet with Tailscale/WireGuard create a security boundary between agent operations and the primary workstation.
4. **Physical distribution**: Multiple Pis in different locations (home, office, cloud) creates a distributed agent mesh that survives individual node failures.
5. **The mobile use case requires always-on**: You can't access agents from iPhone at a coffee shop if your desktop is asleep. The Pi is the always-on bridge.

**Revised strategic priority**: Pi Agent Host → Message Bus → Mobile UI, not Mobile UI → Bot → Pi.

If the Pi is always running `opencode serve` and connected to the message bus, the Discord bot can dispatch work at any time. The desktop can join or leave the bus without affecting availability. This is infrastructure, not a feature.

## Recommended Approach

### Architecture: Channel-Oriented Agent Teams (COAT)

**Core principle**: Discord channels are agent team workspaces. Each channel hosts one type of agent team with a specific role. The bot (orchestrator) dispatches work across channels, collects results, and synthesizes.

```
Discord Server "OpenCode Fleet"
├── #orchestrator          [iPhone user commands from here]
├── #research-wave         [4 research agents spawned per task]
├── #planning              [planner agents working in parallel]
├── #implementation-wave   [implementer agents executing phases]
├── #review                [code-reviewer quality checks]
├── #alerts                [health, errors, status changes]
└── #docs                  [documentation generation agents]
```

**Phase 1 (MVP aligned with current plan)**: Implement the `/rc` command system as a unified command group that can be invoked from any channel. This matches the existing plan but prepares for multi-channel.

**Phase 2 (Strategic pivot)**: Implement the Channel-Oriented Agent Team pattern. `/rc research N --team` spawns 4 research agents, each posting to `#research-wave`, with results synthesized to `#orchestrator`.

**Phase 3 (Infrastructure)**: Deploy Pi agent hosts and connect them to the message bus. Agents now run on Pi, posting results to Discord channels via the bus.

### Unified Protocol: AGENTBUS

Rather than building multiple bridges (Discord↔OpenCode, Neovim↔OpenCode, Pi↔OpenCode), define a single AGENTBUS protocol:

```json
{
  "topic": "research.execute.547",
  "message": {
    "task_id": 547,
    "agent_type": "general-research-agent",
    "focus": "alternative patterns",
    "timeout": 600,
    "model": "sonnet-4-6"
  },
  "sender": "discord-bot",
  "correlation_id": "req_abc123"
}
```

Any agent host subscribed to `research.execute.*` picks up the task, executes it, and publishes to:

```json
{
  "topic": "research.complete.547",
  "correlation_id": "req_abc123",
  "result": {
    "report_path": "specs/547/reports/02_teammate-d-findings.md",
    "confidence": "high",
    "artifacts": [...]
  }
}
```

The Discord bot intercepts these results and posts them to the appropriate channel. Neovim, web UI, and other interfaces can subscribe to the same topics for their own display.

### Scoping Recommendation

**Keep the current plan's Phase 1-3** (bot scaffolding, commands, OpenCode integration) but restructure Phase 4+:

| Phase | Current Plan | Strategic Revision |
|-------|-------------|-------------------|
| 1-3 | Bot scaffold, commands, OpenCode integration | **Keep as-is** -- solid foundation |
| 4 | Session-to-thread mapping, message relay | **Replace with** Channel-based agent team spawning (team patterns from codebase) |
| 5 | Neovim `:OpenCodeLinkDiscord` command | **Keep** but extend to publish to bus, not just HTTP API |
| 6 | Systemd, hardening, production | **Add** Pi agent host deployment, message bus infrastructure, health monitoring channels |
| 7 | (none) | **Add** Documentation agent team that auto-generates READMEs per roadmap item 1 |

## Long-Term Vision: Three Horizons

### Horizon 1 (0-3 months): "The Phone Is Mission Control"
- Discord bot with full `/rc` command group
- Channel-based agent team spawning
- iPhone is the primary interface for task management, research, and monitoring
- Desktop Neovim is one of several agent hosts

### Horizon 2 (3-12 months): "The Fleet Is Autonomous"
- Pi agent hosts on dedicated hardware (always-on)
- Message bus with automatic load balancing across agent hosts
- Agents self-organize -- the Discord bot dispatches high-level goals, agents negotiate who executes what
- Health monitoring channels with auto-recovery (dead agent → respawn on another host)

### Horizon 3 (12+ months): "The Agents Are Extensions of the Developer"
- The agent fleet runs continuously, not per-task
- Background agents proactively scan for issues (lint drift, outdated deps, stale docs)
- The orchestrator maintains a model of the codebase state and the developer's intent
- Interaction from iPhone is lightweight ("check in on things" rather than "execute task N")

## Confidence Level: High

This analysis is grounded in concrete evidence from the codebase:

1. **Team orchestration patterns exist** (skill-team-research, skill-team-implement) -- the Discord bot reuses proven patterns, not invents new ones.
2. **The subagent fleet exists** (8 agent types defined) -- the Discord bot dispatches to existing agents, not creates new ones.
3. **OpenCode's headless API is mature** (`opencode serve`, `run --command`, `attach`) -- the infrastructure for remote agent execution is already tested.
4. **The channel mapping is a natural fit** -- Discord was built for team coordination, and agent teams mirror human team coordination.
5. **The roadmap synergy is real** -- the bot can accelerate documentation tasks because those tasks are already defined and scoped; the bot just automates their execution.

**The strategic risk is NOT that this approach is too ambitious -- it's that the current plan (thin relay, single session) is too timid and will need to be rewritten when the user inevitably wants team orchestration from mobile.** Build for teams now, even if the first deployment is single-session. The architecture should accommodate teams from the start.

## Challenge to Current Assumptions

### Assumption Challenged #1: "The Discord bot is a thin relay"
**Better**: The Discord bot is the orchestrator. It dispatches work, monitors progress, synthesizes results. The thin relay approach duplicates the Neovim TUI on a phone; the orchestrator approach creates a new capability that doesn't exist in any UI today.

### Assumption Challenged #2: "One Discord thread = One session"
**Better**: Discord channels = agent teams (multiple agents working in parallel). Threads within channels = individual agent sessions. The thread is a detailed view; the channel is the team view.

### Assumption Challenged #3: "Pi is a Phase 3 future concern"
**Better**: Pi is the strategic infrastructure. The Discord bot's primary value is accessing agents when away from the desktop, which requires always-on hosting. Pi should be Phase 1 infrastructure, even if agents initially run locally. The bot architecture should assume multiple agent hosts from day one.

### Assumption Challenged #4: "The bot consumes zero extra LLM tokens"
**Better**: The bot enables team-mode orchestration (5x token cost for 4 agents), which is exactly the right use case for mobile. The user can't effectively manage 4 agent sessions from the Neovim TUI, but Discord's channel structure makes it natural. The "cost" of team mode is a *feature* enabled by the mobile interface.

### Assumption Challenged #5: "This is a meta/systems task disconnected from the roadmap"
**Better**: This task is the roadmap accelerator. Every documentation, validation, and quality task on the ROADMAP becomes automatable once the orchestrator exists. Task 547 is not a distraction from Phase 1 goals -- it's the engine that achieves them.

## Strategic Recommendations

1. **Restructure the implementation plan after Phase 3** to adopt Channel-Oriented Agent Teams instead of session-to-thread mapping.
2. **Prioritize Pi agent host deployment** concurrently with bot development -- the Pi is not dependent on the bot (it runs `opencode serve` independently), and having it ready when the bot deploys eliminates the "desktop must be running" bottleneck.
3. **Design for the message bus from Phase 1** -- even if Phase 1 uses direct subprocess calls, use a bus interface internally so switching to distributed agents is a backend change, not a rewrite.
4. **Map roadmap items to agent tasks** -- each TODO in ROADMAP.md should have a corresponding `/rc` command the bot can dispatch.
5. **Consider the Discord server a permanent asset, not a temporary bridge** -- name channels, configure roles, and design the server structure as if it will be the primary developer interface for years.

## Appendix: Codebase Evidence

### Team orchestration patterns already implemented:
- `.opencode/skills/skill-team-research/SKILL.md` -- Wave-based parallel research with 4 teammates and synthesis (lines 147-308)
- `.opencode/skills/skill-team-implement/SKILL.md` -- Wave-based parallel implementation with phase dependency analysis
- `.opencode/skills/skill-team-plan/SKILL.md` -- Multi-planner synthesis

### Agent fleet available for orchestration:
- `.opencode/agent/subagents/` -- 7 execution agents + 1 orchestrator
- Types: research (general, lean, logic, math, latex, typst), implementation (general, lean, latex, typst), planning, meta-building, code-review, revision, spawning

### CLI infrastructure ready for remote dispatch:
- `opencode serve` with `--hostname`, `--port`, `--mdns`, `--cors`, auth via `OPENCODE_SERVER_PASSWORD`
- `opencode run --command` with `--attach`, `--format json`, `--dangerously-skip-permissions`
- `opencode session list/delete` for lifecycle management

### Roadmap tasks automatable by agents:
- ROADMAP.md lines 7-16: Documentation generation, marketplace metadata, CI doc-lint, /review integration, slim standard enforcement, frontmatter validation, reference cleanup

All pieces exist. The Discord bot is the missing **coordination layer** that ties them together into a unified agent fleet accessible from any device.
