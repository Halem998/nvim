# Research Report: Two-Step Skill-then-Task Delegation Chain

**Task**: 536 - clarify_delegation_chain  
**Date**: 2026-05-07  
**Status**: researched

---

## Summary

The `/research`, `/plan`, and `/implement` commands all use a two-step delegation chain:

1. **Step 1**: The command invokes `Skill(skill-name)` to load the skill's instructions
2. **Step 2**: The loaded skill instructions direct the orchestrator to invoke `Task(subagent_type="agent-name")` to spawn the actual subagent

This pattern is **not explicitly documented** in the command docs. The command DELEGATE sections say "invoke the Skill tool" and then state "The skill will spawn the appropriate agent(s)" without clarifying the mechanics of the second step. This causes agents to hesitate and second-guess the chain.

---

## Current State Analysis

### Command DELEGATE Sections (Current Text)

#### `/research` (STAGE 2: DELEGATE, line 320)

```markdown
**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

[... routing logic ...]

**Invoke the Skill tool NOW** with:
```
skill: "skill-researcher"
args: "task_number={N} focus={focus_prompt} session_id={session_id} ..."
```

The skill will spawn the appropriate agent(s) to conduct research and create a report.
```

**Missing**: No mention of the Task tool invocation, no explanation of the two-step pattern, no warning about `Skill(agent-name)`.

#### `/plan` (STAGE 2: DELEGATE, line 324)

```markdown
**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

[... routing logic ...]

**Invoke the Skill tool NOW** with:
```
skill: "skill-planner"
args: "task_number={N} research_path={...} session_id={session_id} ..."
```

The skill spawns agent(s) which analyze task requirements and research findings, decompose into logical phases, identify risks and mitigations, and create a plan in `specs/{NNN}_{SLUG}/plans/`.
```

**Missing**: Same gaps as `/research`.

#### `/implement` (STAGE 2: DELEGATE, line 355)

```markdown
**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

[... routing logic ...]

**Invoke the Skill tool NOW** with:
```
skill: "skill-implementer"
args: "task_number={N} plan_path={...} session_id={session_id} ..."
```

The skill will spawn the appropriate agent(s) which execute plan phases (in parallel for team mode), update phase markers, create commits per phase, and return a structured result.
```

**Missing**: Same gaps as `/research` and `/plan`.

---

### Skill Documentation (Current Text)

#### `skill-researcher` (SKILL.md, line 9)

```markdown
Thin wrapper that delegates general research to `general-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (status update, artifact linking, git commit) before returning. This eliminates the "continue" prompt issue between skill return and orchestrator.
```

**Stage 5** (line 246):
```markdown
**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-research-agent"
  - prompt: [Include task_context, delegation_context, ...]
  - description: "Execute research for task {N}"
```

**DO NOT** use `Skill(general-research-agent)` - this will FAIL.
```

#### `skill-planner` (SKILL.md, line 14)

Same pattern: "Thin wrapper that delegates plan creation to `planner-agent` subagent." With the skill-internal postflight pattern note.

**Stage 5** (line 221):
```markdown
**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "planner-agent"
  - prompt: [Include task_context, delegation_context, ...]
  - description: "Execute planning for task {N}"
```

**DO NOT** use `Skill(planner-agent)` - this will FAIL.
```

#### `skill-implementer` (SKILL.md, line 9)

Same pattern: "Thin wrapper that delegates general implementation to `general-implementation-agent` subagent." With the skill-internal postflight pattern note.

**Stage 5** (line 208):
```markdown
**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-implementation-agent"
  - prompt: [Include task_context, delegation_context, ...]
  - description: "Execute implementation for task {N}"
```

**DO NOT** use `Skill(general-implementation-agent)` - this will FAIL.
```

---

### Existing Warnings About `Skill(agent-name)`

The warning "**DO NOT** use `Skill({agent-name})` - this will FAIL." appears in:

- All core skills: `skill-researcher`, `skill-planner`, `skill-implementer`, `skill-meta`, `skill-reviser`, `skill-spawn`
- All extension skills: `skill-nix-implementation`, `skill-lean-research`, `skill-lean-implementation`, `skill-filetypes`, `skill-slide-planning`, `skill-timeline`, `skill-funds`, `skill-grant`, `skill-slides`, `skill-slide-critic`, `skill-logic-research`, `skill-formal-research`, `skill-math-research`, `skill-physics-research`, `skill-web-implementation`, etc.
- Pattern documentation: `thin-wrapper-skill.md` (line 94)
- Template documentation: `thin-wrapper-skill.md` templates (lines 127, 257)
- Architecture docs: `generation-guidelines.md` (line 174)

**Total occurrences**: 39 across the codebase.

**However**: These warnings exist ONLY inside the skill files themselves. They are **NOT present** in the command docs that invoke the skills. An agent reading only the command doc would not see the warning until AFTER it had already loaded the skill.

---

### Why the Two-Step Pattern Exists

From the skill documentation and `thin-wrapper-skill.md`:

1. **Skills are thin wrappers** — They validate inputs, prepare delegation context, and handle preflight/postflight. They do NOT load heavy context or execute business logic.

2. **Agents do the actual work** — Subagents load their own context, perform research/planning/implementation, and create artifacts.

3. **Skill-internal postflight** — After the subagent returns, the skill handles all postflight operations (status update, artifact linking, git commit) BEFORE returning to the orchestrator. This eliminates the "continue" prompt issue between skill return and orchestrator.

4. **Separation of concerns** — The command (orchestrator) decides WHICH skill to invoke based on task type and flags. The skill decides WHICH agent to spawn and prepares the structured delegation context.

5. **Agents live in `.opencode/agent/subagents/`, not `.opencode/skills/`** — This is why `Skill(agent-name)` fails: the Skill tool only loads files from `.opencode/skills/`.

---

## Exact Text to Add to Each Command Doc

The following text block should be inserted into the DELEGATE section of each command doc, immediately after the "Invoke the Skill tool NOW" code block and before the sentence "The skill will spawn...".

### Proposed Addition (for all three commands)

```markdown
**Delegation Chain Note**: This is a two-step delegation:

1. **Step 1 (Skill)**: You invoke `Skill(skill-name)` above to load the skill's instructions.
2. **Step 2 (Task)**: The loaded skill instructions will direct you to invoke `Task(subagent_type="agent-name")` to spawn the actual subagent.

**Why two steps?** Skills are thin wrappers with preflight/postflight logic (status updates, artifact validation, git commit). Agents live in `.opencode/agent/subagents/` and do the actual work. The Skill tool loads instructions from `.opencode/skills/`; the Task tool spawns agents.

**WARNING**: Do NOT use `Skill(agent-name)` directly. Agents are not skills. The skill file contains the CRITICAL instruction to use `Task`, not `Skill`, for spawning the agent.
```

### Command-Specific Agent Names

| Command | Skill Invoked | Agent Spawned (via Task) |
|---------|--------------|--------------------------|
| `/research` | `skill-researcher` | `general-research-agent` |
| `/plan` | `skill-planner` | `planner-agent` |
| `/implement` | `skill-implementer` | `general-implementation-agent` |

For team mode:
| Command | Skill Invoked | Agent Spawned (via Task) |
|---------|--------------|--------------------------|
| `/research --team` | `skill-team-research` | Multiple `general-research-agent` |
| `/plan --team` | `skill-team-plan` | Multiple `planner-agent` |
| `/implement --team` | `skill-team-implement` | Multiple `general-implementation-agent` |

---

## Files to Modify

1. `.opencode/commands/research.md` — STAGE 2: DELEGATE section
2. `.opencode/commands/plan.md` — STAGE 2: DELEGATE section
3. `.opencode/commands/implement.md` — STAGE 2: DELEGATE section

---

## Risks and Considerations

- **Redundancy**: The warning about `Skill(agent-name)` will now appear in both the command doc and the skill doc. This is intentional — the command doc is the first thing the agent reads, so the warning should appear there too.
- **Consistency**: The same text pattern should be used across all three commands for maintainability.
- **Future-proofing**: If new commands follow this pattern (e.g., `/review`, `/meta`), they should include the same delegation chain note.

---

## Recommendations

1. **Add the delegation chain note** to all three command DELEGATE sections as proposed above.
2. **Consider adding** a brief reference to `thin-wrapper-skill.md` in the command docs for agents that want to understand the pattern in depth.
3. **Standardize** future command docs to include this note whenever they use the Skill→Task delegation pattern.
