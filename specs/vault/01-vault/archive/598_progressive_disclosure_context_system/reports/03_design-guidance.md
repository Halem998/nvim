# Design Guidance: Task 598 — Progressive Disclosure Context System

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` cross-cutting context section
**Depends on**: Task 593 (shared utilities)
**Blocks**: Tasks 594, 595, 596

---

## Overview

Task 598 is **elevated in the dependency chain**: context budget design must be established before
task 594 (skill base) to ensure shared lifecycle functions respect budget constraints. The task
audits 97 existing context index entries, classifies them into 4 tiers, and establishes budget
caps per agent type.

---

## Four-Tier Loading Model

| Tier | Load Trigger | Budget | Content |
|------|-------------|--------|---------|
| **1** Always | Every invocation (no condition) | ~500 lines | Anti-stop patterns, return-metadata schema, checkpoint-execution |
| **2** Command | On command detection | ~500 lines | Routing tables, argument docs, anti-bypass PROHIBITION |
| **3** Agent | At agent spawn time | ~3-5K lines | Workflow patterns, domain context, format specifications |
| **4** On-demand | Via `@`-ref inside agent | Unbounded | Detailed guides, templates, examples, appendices |

### Tier Classification Criteria

| Indicator | Tier |
|-----------|------|
| Agent MUST have this to function at all | 1 |
| Command needs this to route correctly | 2 |
| Agent needs this to execute correctly but can function without it | 3 |
| Reference material an agent may occasionally need | 4 |

---

## Budget Caps Per Agent Type

| Agent Class | Context Budget | Examples |
|-------------|---------------|---------|
| Haiku utilities | ≤ 2K tokens | Helper scripts, quick queries |
| Sonnet workers | ≤ 8K tokens | research-agent, implementation-agent |
| Opus planners | ≤ 15K tokens | planner-agent, meta-builder-agent |

These caps apply to Tier 3 content loaded at agent spawn. Tier 4 (on-demand) is not capped.

---

## Context Index Audit

The `.claude/context/index.json` has 97 entries. For each entry, determine:
1. Which tier does this belong to?
2. Which agents actually use it?
3. Is it currently loaded at the wrong tier?

### Audit Query

```bash
# Count entries by load_when pattern
jq '{
  always: [.entries[] | select(.load_when.always == true)] | length,
  agents: [.entries[] | select(.load_when.agents | length > 0)] | length,
  commands: [.entries[] | select(.load_when.commands | length > 0)] | length,
  task_types: [.entries[] | select(.load_when.task_types | length > 0)] | length,
  never: [.entries[] | select(.load_when.always == false and (.load_when.agents | length) == 0 and (.load_when.commands | length) == 0 and (.load_when.task_types | length) == 0)] | length
}' .claude/context/index.json
```

### Key Questions Per Entry

1. Is this entry loaded as `always: true` but only needed by specific agents? → Move to Tier 3
2. Is this entry loaded for commands but contains agent-level detail? → Move to Tier 3 or 4
3. Is this entry referenced by 0 agents (dead)? → Prune
4. Does this entry have a missing `line_count` field? → Add it

---

## index.json Schema Additions

Add `tier` and `token_cost` metadata to each entry:

```json
{
  "path": ".claude/context/patterns/fork-patterns.md",
  "description": "Fork vs. subagent decision patterns",
  "line_count": 95,
  "tier": 3,
  "token_cost_estimate": 800,
  "load_when": {
    "always": false,
    "agents": ["general-implementation-agent", "planner-agent"],
    "task_types": [],
    "commands": []
  }
}
```

Fields to add:
- `tier`: integer 1-4 (see four-tier model)
- `token_cost_estimate`: estimated tokens when loaded (line_count * ~8 tokens/line as rough estimate)

---

## Critical Finding: Commands Loading Tier 3 Content

Currently, research.md, plan.md, and implement.md embed agent-level content directly. This violates
the four-tier model. After tasks 593 and 595, these command files should be ≤ 200 lines. If they
are still loading Tier 3 content inline, task 598 must identify and move that content.

### Steps

1. After task 595 completes, audit research.md, plan.md, implement.md for Tier 3 content
2. For each Tier 3 block found in a command file:
   - Create a new Tier 3 context file: `.claude/context/{category}/{name}.md`
   - Add to index.json with `tier: 3` and `load_when.agents: [...]`
   - Remove from command file

### Common Tier 3 Content Found in Commands

- State machine logic for agents (→ agent context)
- Format specifications (→ Tier 3 or 4 context)
- Detailed workflow steps for agents (→ agent context)
- Anti-patterns and common mistakes (→ Tier 3 or 4)

---

## load_when Pattern Updates

After tier classification, update `load_when` to match:

```json
// Tier 1: always: true, agents: [], commands: [], task_types: []
{"always": true}

// Tier 2: loaded for command entries
{"always": false, "commands": ["/research", "/plan", "/implement"]}

// Tier 3: loaded for specific agents
{"always": false, "agents": ["general-research-agent", "planner-agent"]}

// Tier 4: never auto-loaded (accessed via @-ref)
{"always": false, "agents": [], "commands": [], "task_types": []}
```

---

## Pruning Dead Entries

An entry is "dead" if:
- `load_when.agents` is empty AND `load_when.always = false` AND no command/task_type match
- File does not exist on disk
- No agent has referenced this file in recent task history

```bash
# Find potential dead entries
jq '.entries[] | select(
  .load_when.always == false and
  (.load_when.agents | length) == 0 and
  (.load_when.commands | length) == 0 and
  (.load_when.task_types | length) == 0
) | .path' .claude/context/index.json
```

Review each candidate before pruning. Some may be Tier 4 (intentionally not auto-loaded).

---

## Verification

```bash
# Verify no command file loads Tier 3 content after refactoring
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md
# Each: ≤ 200 lines

# Verify index.json has tier field on all entries
jq '.entries | map(select(.tier == null)) | length' .claude/context/index.json
# Expected: 0 (all entries classified)

# Verify always-true entries are Tier 1 budget
jq '.entries[] | select(.load_when.always == true) | .line_count' .claude/context/index.json | awk '{sum+=$1} END {print "Total Tier 1 lines:", sum}'
# Expected: ≤ 500 lines

# Verify no dead entries
jq '.entries[] | select(
  .load_when.always == false and
  (.load_when.agents | length) == 0 and
  (.load_when.commands | length) == 0 and
  (.load_when.task_types | length) == 0
) | .path' .claude/context/index.json
# Should be empty or only intentional Tier 4 entries
```
