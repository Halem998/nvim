# Fork Patterns Reference Guide

**Created**: 2026-04-28
**Purpose**: Document fork mechanisms, prompt cache sharing, and delegation decision criteria
**Audience**: Skill authors, /meta agent, system maintainers

---

## Mechanism Overview

Two distinct "fork" concepts exist in Claude Code. They solve opposite problems.

### `context: fork` (skill frontmatter field)

**What it does**: Signals the Claude Code executor NOT to load CLAUDE.md context files or other
context-building steps before invoking the skill. The subagent loads its own context on demand.

**When it fires**: On every skill invocation where the frontmatter contains `context: fork`.

**Benefit**: Token efficiency — avoids loading context into the skill's conversation when the
subagent will load it fresh anyway.

**Typical users**: Extension skills (`skill-{ext}-research`, `skill-{ext}-implementation`),
`skill-meta` (uses `agent:` but not `context: fork`).

---

### `subagent_type: "fork"` (Agent tool parameter — current pattern)

**What it does**: Passing `subagent_type: "fork"` to the Agent tool spawns a forked subprocess
that inherits the parent's prompt cache. This is the **current, preferred** fork mechanism used
by `skill-orchestrate` for blocker research and drift inspection.

**Current state**: `skill-orchestrate` uses `subagent_type: "fork"` for its two fork dispatch
points (Stage 5a drift inspection, Stage 6 blocker research). This pattern was confirmed working
in `skill-researcher` and is now unified across all fork dispatch sites.

**When to use**: Lightweight analysis tasks that benefit from cache sharing (e.g., reading a
plan file, researching a specific blocker). The fork inherits the parent's context without
requiring a specialized agent type.

---

### `CLAUDE_CODE_FORK_SUBAGENT=1` (environment variable — legacy)

**What it does**: When set, Agent/Agent tool invocations that **omit `subagent_type`** spawn a
forked subprocess that inherits the parent's prompt cache. This can reduce input token costs by
~90% for the child compared to a fresh session.

**Critical constraint**: Only fires when `subagent_type` is OMITTED. If `subagent_type` is
specified explicitly, the env var has no effect — a fresh agent is always launched.

**Current state**: Core skills always specify `subagent_type` explicitly (e.g.,
`subagent_type: "general-implementation-agent"`), so they are unaffected by this env var.
The `FORK_SUBAGENT` env var mechanism (referenced in the old `dispatch-agent.sh`) is no longer
used. Use `subagent_type: "fork"` instead.

---

## Prompt Cache Sharing Mechanics

### How cache sharing works

When `CLAUDE_CODE_FORK_SUBAGENT=1` and `subagent_type` is omitted:
1. The child inherits the parent's cached prompt prefix.
2. The child pays near-zero input tokens for the shared prefix.
3. Each child generates its own output tokens and any unique context.

### Cost implications

| Scenario | Input token cost | Notes |
|----------|------------------|-------|
| Fresh agent (`subagent_type` specified) | Full cost | No cache sharing |
| Forked agent (no `subagent_type`) | ~10% of fresh | ~90% reduction via cache |
| Team mode with 3 teammates | 3x fresh (no fork) | Each teammate is fresh |
| Team mode with FORK_SUBAGENT | ~1.2x fresh | Teammates 2-N share cache |

### Why core skills don't benefit today

Core skills (skill-researcher, skill-planner, skill-implementer, etc.) always pass
`subagent_type` explicitly to ensure the correct specialized agent is invoked. This is
intentional: structured context injection (session_id, delegation_depth, memory_context) requires
a known agent type. The trade-off is no FORK_SUBAGENT cache sharing.

---

## Decision Matrix: Which Delegation Pattern to Use

### Pattern A: Explicit Agent tool with `subagent_type` (core skill pattern)

```yaml
---
name: skill-implementer
description: Execute implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

**Use when**:
- Skill needs to inject structured context (session_id, delegation_depth, memory_context)
- Skill has multi-stage postflight (status update, artifact linking, git commit)
- Agent type must be explicitly controlled
- Skill is a core workflow skill (research, plan, implement, revise, spawn)

**How delegation works**:
```
Tool: Agent
Parameters:
  subagent_type: "general-implementation-agent"
  prompt: [full structured context JSON + instructions]
```

---

### Pattern B: `context: fork` + `agent:` frontmatter (extension skill pattern)

```yaml
---
name: skill-lean-research
description: Research Lean4 patterns. Invoke for lean research tasks.
allowed-tools: Agent
context: fork
agent: lean-research-agent
---
```

**Use when**:
- Skill is a simple thin wrapper with minimal or no postflight
- No structured context injection needed (or handled inside the skill body)
- Extension skills where the agent carries all the logic
- Simpler delegation where the skill body only validates inputs and calls the agent

**How delegation works**:
```
Tool: Agent (implicitly routed via `agent:` frontmatter)
Prompt: simple task instructions (no structured context JSON required)
```

---

## Constraints and Incompatibilities

| Constraint | Details |
|------------|---------|
| Headless mode | `context: fork` may behave differently in `--headless` invocations |
| No recursive forks | A forked subagent cannot itself fork; nesting is not supported |
| `subagent_type` blocks FORK_SUBAGENT | Explicitly specifying `subagent_type` disables fork inheritance |
| `context: fork` ≠ FORK_SUBAGENT | These are independent mechanisms; one does not imply the other |
| `agent:` frontmatter | Works with or without `context: fork`; `skill-meta` uses `agent:` alone |

---

## Team-Mode Optimization Opportunity (Future Work)

Team-mode skills (skill-team-research, skill-team-plan, skill-team-implement) spawn multiple
teammates via Agent tool calls without specifying `subagent_type`. This means they ARE eligible
for `CLAUDE_CODE_FORK_SUBAGENT=1` cache sharing.

**Potential impact**: With `FORK_SUBAGENT=1`, teammates 2-N could inherit the parent's prompt
cache, reducing per-teammate input token cost by ~90%. For a 3-teammate team, total input cost
would be ~1.2x instead of ~3x.

**Current status**: Not yet implemented. Task 501 tracks this optimization.

**What's needed**:
- Verify teammate spawning dispatch order for maximum cache overlap
- Update team orchestration metadata to report estimated cache savings
- Reconsider default `team_size=2` given reduced per-teammate cost

---

## Related Documentation

- @.claude/context/architecture/system-overview.md - System architecture overview
- @.claude/context/patterns/thin-wrapper-skill.md - Thin wrapper pattern reference
- @.claude/context/templates/thin-wrapper-skill.md - Full skill template
- @.claude/docs/guides/creating-skills.md - Step-by-step skill creation guide
