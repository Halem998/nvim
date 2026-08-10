# Task 536: Clarify Two-Step Delegation Chain in Command Docs

## Problem

The delegation chain in `/implement` (and similar commands) involves two steps:
1. The **orchestrator** uses the `Skill` tool to load skill instructions
2. The loaded skill instructions then direct the orchestrator to use the `Task` tool to spawn a subagent

This is not explicitly documented in the command specifications. The `/implement` DELEGATE section says "Invoke the Skill tool NOW" without explaining that the skill's instructions will then direct a `Task` tool invocation. This caused the agent to hesitate and second-guess the chain.

## Impact

- Agents hesitate between Skill and Task tool
- Some agents may incorrectly try to invoke `Skill(skill-name)` directly on the agent name, which will fail
- The two-step pattern is fundamental to the architecture but undocumented

## Solution

Update the DELEGATE sections in `/implement`, `/research`, and `/plan` to explicitly document:
1. Step 1: Use `Skill` tool to load the selected skill's instructions
2. Step 2: Follow the loaded instructions, which will direct you to use `Task` tool with `subagent_type` to spawn the actual agent
3. Include a note: "DO NOT use `Skill(agent-name)` — agents are not skills"

Add a brief architecture note explaining WHY this two-step exists: skills are thin wrappers with preflight/postflight; agents do the actual work.

## Acceptance Criteria

- [ ] All three command docs explicitly document the two-step delegation chain
- [ ] Each includes the warning about not using `Skill(agent-name)`
- [ ] A brief rationale for the two-step pattern is included

## Effort

< 1 hour

## Type

meta

## Dependencies

None

## Key Files

- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`
