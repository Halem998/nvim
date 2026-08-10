# Research Report: Task #129

**Task**: OC_129 - Fix .opencode agent system context loading
**Date**: 2026-03-04
**Language**: meta
**Focus**: context-loading-best-practices

## Summary

The current `.opencode` agent system relies on a "Pull" model where agents are instructed to load critical context files (like `plan-format.md`) via `@` references in their system prompts. This approach is prone to failure if the agent overlooks the instruction or hallucinates the file content. To ensure strict format compliance, a "Push" model or a hybrid approach is recommended, where critical schemas are injected into the agent's context by the invoking skill or orchestrator.

## Findings

### 1. Current Context Loading Mechanism (Pull)
- **Agent Definitions**: `planner-agent.md` lists files under `**Always Load**` using `@path` syntax.
- **Skill Execution**: `skill-planner/SKILL.md` delegates to `planner-agent` but explicitly advises against eager loading (`Reference (do not load eagerly)`).
- **Execution Flow**: The agent (LLM) receives the `planner-agent.md` content as its system prompt. It is expected to recognize the `@` references and call the `Read` tool to load them.
- **Failure Mode**: If the model decides it "knows" the format (from training data or hallucination) and skips the `Read` call, the output deviates from the project's specific standards (e.g., missing "Goals & Non-Goals" section).

### 2. Validation Gaps
- **Orchestrator Validation**: `orchestration-validation.md` explicitly excludes artifact content validation ("Low-Value Checks... Artifact format | Domain-specific | Agent").
- **Agent Self-Validation**: Agents are instructed to validate their own output, but this is circular if they haven't loaded the correct schema.

### 3. Best Practices for Context Loading
- **Critical Context (Formats, Rules)**: **Push**. Injected directly into the system prompt or user message. The cost of tokens is justified by the prevention of structural errors.
- **Reference Context (Docs, Research)**: **Pull**. Loaded on-demand via tools (`Read`, `Search`).
- **Validation Context (Schemas)**: **Hybrid**. Used by a separate validation step (e.g., a lightweight script or a second LLM call) to verify output.

## Recommendations

1.  **Implement "Push" Loading in Skills**: Modify `skill-planner/SKILL.md` to require the *invoking agent* (the skill executor) to read `plan-format.md` and include its content in the `prompt` passed to `planner-agent`. This ensures the subagent *always* sees the format rules in its initial context.
    *   *Mechanism*: Update `Execution Flow` in `SKILL.md` to add a "Read Context" step before "Delegate".
2.  **Enhance Validation**: Add a validation step in `skill-planner` that checks the generated plan against key structural requirements (e.g., "Does it have a Goals section?") before completing the task.
3.  **Standardize Context Injection**: Create a `context-loading-best-practices.md` guide (referenced in `index.md` but missing) to formalize the distinction between "Push" (critical) and "Pull" (reference) context.

## Risks & Considerations

- **Token Usage**: Pushing large format files increases token consumption per call. `plan-format.md` is ~140 lines, which is negligible compared to the cost of a failed plan and subsequent revision.
- **Complexity**: Moving logic from "agent autonomy" to "skill orchestration" increases the complexity of the skill definitions.

## Next Steps

Run `/plan OC_129` to create an implementation plan to:
1.  Create `docs/guides/context-loading-best-practices.md`.
2.  Modify `skill-planner/SKILL.md` to implement "Push" loading for `plan-format.md`.
3.  (Optional) Update `planner-agent.md` to reflect that context is provided.
