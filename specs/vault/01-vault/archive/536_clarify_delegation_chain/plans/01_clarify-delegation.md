# Plan: Clarify Delegation Chain (Task 536)

## Overview

Add explicit documentation of the two-step Skill→Task delegation chain to the DELEGATE sections of `/research`, `/plan`, and `/implement` command docs, plus their `.claude/` mirrors. The delegation chain exists but is currently undocumented in command specs, causing agents to hesitate and second-guess the mechanics.

---

## Context

**Research Report**: [01_delegation-chain-research.md](../reports/01_delegation-chain-research.md)

**Current Pattern**:
1. **Step 1 (Skill)**: Command invokes `Skill(skill-name)` to load the skill's instructions
2. **Step 2 (Task)**: Skill instructions direct the orchestrator to invoke `Task(subagent_type="agent-name")` to spawn the actual subagent

**Problem**: Command docs say "invoke the Skill tool" and then "The skill will spawn the appropriate agent(s)" without clarifying the second step or warning against `Skill(agent-name)`.

**Solution**: Insert a **Delegation Chain Note** into each command's STAGE 2: DELEGATE section, immediately after the "Invoke the Skill tool NOW" code block and before the sentence "The skill will spawn...".

---

## Phases

### Phase 1: Update `/implement` DELEGATE Section

**File**: `.opencode/commands/implement.md`

**Location**: STAGE 2: DELEGATE, line ~438 (after skill invocation code block, before "The skill will spawn...")

**Action**: Insert the Delegation Chain Note block.

**Agent Mapping for /implement**:
| Mode | Skill Invoked | Agent Spawned (via Task) |
|------|--------------|--------------------------|
| Single-agent | `skill-implementer` | `general-implementation-agent` |
| Team | `skill-team-implement` | Multiple `general-implementation-agent` |

---

### Phase 2: Update `/research` DELEGATE Section

**File**: `.opencode/commands/research.md`

**Location**: STAGE 2: DELEGATE, line ~398 (after skill invocation code block, before "The skill will spawn...")

**Action**: Insert the Delegation Chain Note block.

**Agent Mapping for /research**:
| Mode | Skill Invoked | Agent Spawned (via Task) |
|------|--------------|--------------------------|
| Single-agent | `skill-researcher` | `general-research-agent` |
| Team | `skill-team-research` | Multiple `general-research-agent` |

---

### Phase 3: Update `/plan` DELEGATE Section

**File**: `.opencode/commands/plan.md`

**Location**: STAGE 2: DELEGATE, line ~404 (after skill invocation code block, before "The skill spawns agent(s)...")

**Action**: Insert the Delegation Chain Note block.

**Agent Mapping for /plan**:
| Mode | Skill Invoked | Agent Spawned (via Task) |
|------|--------------|--------------------------|
| Single-agent | `skill-planner` | `planner-agent` |
| Team | `skill-team-plan` | Multiple `planner-agent` |

---

### Phase 4: Explain WHY Two-Step Exists

**Content to include in the note** (all three commands):

> **Why two steps?** Skills are thin wrappers with preflight/postflight logic (status updates, artifact validation, git commit). Agents live in `.opencode/agent/subagents/` and do the actual work. The Skill tool loads instructions from `.opencode/skills/`; the Task tool spawns agents.

This explanation is included in the Delegation Chain Note block inserted in Phases 1-3.

---

### Phase 5: Add `Skill(agent-name)` Warning

**Content to include in the note** (all three commands):

> **WARNING**: Do NOT use `Skill(agent-name)` directly. Agents are not skills. The skill file contains the CRITICAL instruction to use `Task`, not `Skill`, for spawning the agent.

This warning is included in the Delegation Chain Note block inserted in Phases 1-3.

**Rationale**: 39 existing warnings exist but only inside skill files. Agents reading the command doc first will now see the warning before loading the skill.

---

### Phase 6: Update `.claude/` Mirrors

**Files to update**:
- `.claude/commands/implement.md` — STAGE 2: DELEGATE section
- `.claude/commands/research.md` — STAGE 2: DELEGATE section
- `.claude/commands/plan.md` — STAGE 2: DELEGATE section

**Action**: Apply the exact same Delegation Chain Note insertions as Phases 1-3.

**Note**: The `.claude/` commands are structural mirrors of `.opencode/` commands. They use the same delegation chain (Skill→Task) and the same agent names. The note text is identical except for path references (`.claude/` vs `.opencode/`).

**Also check** (if they exist and differ):
- `.opencode/extensions/core/commands/implement.md`
- `.claude/extensions/core/commands/implement.md`
- Corresponding research.md and plan.md in extensions/core/commands/

---

## Exact Text to Insert

Insert the following block after the "Invoke the Skill tool NOW" code block and before "The skill will spawn..." in each command doc:

```markdown
**Delegation Chain Note**: This is a two-step delegation:

1. **Step 1 (Skill)**: You invoke `Skill(skill-name)` above to load the skill's instructions.
2. **Step 2 (Task)**: The loaded skill instructions will direct you to invoke `Task(subagent_type="agent-name")` to spawn the actual subagent.

**Why two steps?** Skills are thin wrappers with preflight/postflight logic (status updates, artifact validation, git commit). Agents live in `.opencode/agent/subagents/` and do the actual work. The Skill tool loads instructions from `.opencode/skills/`; the Task tool spawns agents.

**WARNING**: Do NOT use `Skill(agent-name)` directly. Agents are not skills. The skill file contains the CRITICAL instruction to use `Task`, not `Skill`, for spawning the agent.
```

**Command-specific agent name substitutions**:
- `/implement`: `agent-name` → `general-implementation-agent`
- `/research`: `agent-name` → `general-research-agent`
- `/plan`: `agent-name` → `planner-agent`

For `.claude/` mirrors, use `.claude/agent/subagents/` and `.claude/skills/` in the path references.

---

## Files Modified

### Primary (.opencode/)
1. `.opencode/commands/implement.md`
2. `.opencode/commands/research.md`
3. `.opencode/commands/plan.md`

### Mirrors (.claude/)
4. `.claude/commands/implement.md`
5. `.claude/commands/research.md`
6. `.claude/commands/plan.md`

### Extension mirrors (if applicable)
7. `.opencode/extensions/core/commands/implement.md`
8. `.opencode/extensions/core/commands/research.md`
9. `.opencode/extensions/core/commands/plan.md`
10. `.claude/extensions/core/commands/implement.md`
11. `.claude/extensions/core/commands/research.md`
12. `.claude/extensions/core/commands/plan.md`

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Redundancy with skill-internal warnings | **Intentional** — command doc is the first thing agents read |
| Path references differ between `.opencode/` and `.claude/` | Use correct path prefix per system in the note text |
| Extension command files may be auto-generated | Verify manually; skip if marked auto-generated |
| Inconsistent insertion points | Use "after skill invocation block, before 'The skill will spawn'" as anchor |

---

## Verification

1. Read the DELEGATE section of each modified file
2. Confirm the Delegation Chain Note appears after the Skill invocation code block
3. Confirm the note appears before "The skill will spawn..."
4. Confirm agent name matches the command (general-implementation-agent, general-research-agent, planner-agent)
5. Confirm `.claude/` mirrors use `.claude/` paths

---

## Post-Implementation

- Update task status to `[COMPLETED]`
- Run `/todo` to archive if all phases complete
- No new artifacts created (documentation update only)
