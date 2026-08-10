# Research Report: Format Specification Injection into Delegation Prompts

- **Task**: 370 - Inject artifact format specifications into skill delegation prompts
- **Started**: 2026-04-07T00:00:00Z
- **Completed**: 2026-04-07T00:00:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase exploration of skill definitions and agent definitions
  - Format specification files in `.claude/context/formats/`
- **Artifacts**: specs/370_inject_format_specs_delegation_prompts/reports/01_format-injection-research.md
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- All three artifact-producing skills (skill-planner, skill-researcher, skill-implementer) use identical delegation patterns: they construct a JSON delegation context object in Stage 4 and pass it to the Task tool in Stage 5. None currently read or inject format file content.
- The corresponding agents (planner-agent, general-research-agent, general-implementation-agent) rely on advisory `@` references in their Context References sections to discover format files. These references are not auto-resolved; the subagent must actively Read them.
- The format files are small enough (59-169 lines, ~360 total) to inject directly into delegation prompts without significant token overhead. A new Stage 4a in each skill can Read the format file and include it as a `format_specification` field in the delegation context.

## Findings

### Current Delegation Architecture

All three skills follow the same structural pattern:

**Stage 4: Prepare Delegation Context** -- Constructs a JSON object with fields like `session_id`, `delegation_depth`, `delegation_path`, `timeout`, `task_context`, `artifact_number`, and operation-specific paths (`research_path`, `plan_path`, `metadata_file_path`).

**Stage 5: Invoke Subagent** -- Calls the Task tool with `subagent_type` and a `prompt` parameter that includes the delegation context. The prompt instructions say to "Include task_context, delegation_context, [operation-specific fields]" but never mention format content.

Skill-to-agent-to-format mapping:

| Skill | Agent | Format File | Agent `@` Reference |
|-------|-------|-------------|-------------------|
| skill-planner | planner-agent | `plan-format.md` | `@.claude/context/formats/plan-format.md` (marked "always load") |
| skill-researcher | general-research-agent | `report-format.md` | `@.claude/context/formats/report-format.md` (marked "when creating report") |
| skill-implementer | general-implementation-agent | `summary-format.md` | `@.claude/context/formats/summary-format.md` (marked "when creating summary") |

The `@` references in agent definitions are advisory comments intended to guide the subagent to load them. However, these are not automatically resolved by the Claude Code runtime -- the spawned agent must choose to Read the file, which it may skip under token pressure or when focused on complex domain content.

### Format File Sizes

| File | Lines | Estimated Tokens |
|------|-------|-----------------|
| `plan-format.md` | 169 | ~1,200 |
| `report-format.md` | 131 | ~900 |
| `summary-format.md` | 59 | ~400 |

All files are well within acceptable injection size. Even plan-format.md at ~1,200 tokens is negligible compared to the typical delegation prompt size and agent context window.

### Injection Points

For each skill, the injection should occur between the existing Stage 4 (Prepare Delegation Context) and Stage 5 (Invoke Subagent). A new **Stage 4b** would:

1. Read the appropriate format file using the Read tool
2. Add the content as a `format_specification` field in the delegation context JSON
3. Update Stage 5's prompt instructions to reference the injected format

**skill-planner (SKILL.md)**:
- **Current Stage 4** (lines 142-165): Constructs delegation JSON with `research_path`, `roadmap_path`, `metadata_file_path`
- **Insert after Stage 4** (before Stage 5 at line 169): New stage reads `.claude/context/formats/plan-format.md`
- **Update Stage 5** (line 178): Add `format_specification` to the prompt inclusion list

**skill-researcher (SKILL.md)**:
- **Current Stage 4** (lines 124-147): Constructs delegation JSON with `focus_prompt`, `roadmap_path`, `metadata_file_path`
- **Insert after Stage 4** (before Stage 5 at line 151): New stage reads `.claude/context/formats/report-format.md`
- **Update Stage 5** (line 160): Add `format_specification` to the prompt inclusion list

**skill-implementer (SKILL.md)**:
- **Current Stage 4** (lines 137-159): Constructs delegation JSON with `plan_path`, `metadata_file_path`
- **Insert after Stage 4** (before Stage 5 at line 163): New stage reads `.claude/context/formats/summary-format.md`
- **Update Stage 5** (line 172): Add `format_specification` to the prompt inclusion list

### Existing Patterns

No existing skill currently reads a context file and injects its content into the delegation prompt. All skills rely exclusively on the advisory `@` reference pattern in agent definitions. This task would establish a new pattern.

However, there is a related precedent: the `roadmap_path` field in delegation contexts tells the agent where to find the roadmap, but the agent is still responsible for reading it. The proposed change goes one step further by including the actual content rather than just a path.

The closest existing pattern is how each skill's SKILL.md itself lists "Context References" with `@` paths and "(do not load eagerly)" annotations -- these document files the skill might need but delegates reading to runtime judgment. The proposed change replaces this judgment with deterministic inclusion for format files specifically.

### Extension Skills Impact

Extension skills (e.g., `skill-neovim-research`, `skill-neovim-implementation`, `skill-latex-research`) follow the exact same Stage 4/Stage 5 delegation pattern as the core skills. They share the same format files:
- Extension research skills -> `report-format.md`
- Extension implementation skills -> `summary-format.md`

The implementation should also update extension skills, or alternatively, create a shared helper pattern that all skills can reference. Given there are ~20+ extension skills, a systematic approach would be valuable.

### Agent-Side Considerations

Once format content is injected into the delegation prompt, the agent definitions could optionally be updated to:
1. Remove the `@` reference for the injected format file (since it is now provided)
2. Add a note that format specification is received via delegation context
3. Reference `delegation_context.format_specification` instead of the `@` path

However, keeping the `@` reference as a fallback is harmless and provides documentation value.

## Recommendations

### Implementation Approach

**Option A: Inline Injection (Recommended)**

Add a new stage (Stage 4b) to each of the three core skills that:
1. Uses the Read tool to load the format file
2. Adds a `format_specification` key to the delegation context JSON containing the full file content
3. Updates Stage 5 prompt instructions to include `format_specification`

The delegation context JSON would gain one new field:
```json
{
  "session_id": "...",
  "task_context": { ... },
  "format_specification": "<contents of the format file>"
}
```

And the Stage 5 prompt would be updated from:
```
prompt: [Include task_context, delegation_context, research_path, metadata_file_path]
```
To:
```
prompt: [Include task_context, delegation_context, research_path, metadata_file_path, format_specification]
```

**Option B: Separate Prompt Section**

Instead of embedding in the JSON object, include the format content as a separate clearly-delimited section in the Task tool prompt:

```
## Format Specification

The following format MUST be used for the output artifact:

<format_specification>
{contents of format file}
</format_specification>
```

This approach makes the format more visually prominent in the prompt and harder for the agent to overlook. It adds approximately the same token count but with clearer semantic separation.

**Recommendation**: Option B is preferred because:
- Format specifications are instructions, not data -- they belong in the prompt, not in a JSON payload
- The XML-delimited section is more salient to the LLM than a JSON string value
- It mirrors how system prompts typically provide format instructions

### Scope and Phasing

- **Phase 1**: Update the three core skills (skill-planner, skill-researcher, skill-implementer)
- **Phase 2**: Update extension skills that produce artifacts (optional, can be a follow-up task)
- **Phase 3**: Optionally update agent definitions to note that format specs are now injected (documentation only)

### Files to Modify

Phase 1 (required):
1. `.claude/skills/skill-planner/SKILL.md` -- Add Stage 4b, update Stage 5
2. `.claude/skills/skill-researcher/SKILL.md` -- Add Stage 4b, update Stage 5
3. `.claude/skills/skill-implementer/SKILL.md` -- Add Stage 4b, update Stage 5

Phase 2 (optional follow-up):
- All extension research/implementation skills in `.claude/extensions/*/skills/`

Phase 3 (optional documentation):
- `.claude/agents/planner-agent.md`
- `.claude/agents/general-research-agent.md`
- `.claude/agents/general-implementation-agent.md`

## Risks and Mitigations

- **Risk**: Injecting format content increases prompt size. **Mitigation**: Format files are small (59-169 lines, ~400-1200 tokens). This is negligible relative to typical agent context windows.
- **Risk**: Format content in delegation prompt may conflict with agent's own reading of the same file. **Mitigation**: Duplicate content is harmless (reinforces the format) and agents can skip their own Read if content is already provided.
- **Risk**: Extension skills are not updated, creating inconsistency. **Mitigation**: Phase 2 addresses this; extension skills currently have the same problem as core skills.

## References

- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (Stage 4: lines 142-165, Stage 5: lines 169-193)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (Stage 4: lines 124-147, Stage 5: lines 151-174)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (Stage 4: lines 137-159, Stage 5: lines 163-186)
- `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md` (Context References: line 16)
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` (Context References: line 16)
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (Context References: line 15)
- `/home/benjamin/.config/nvim/.claude/context/formats/plan-format.md` (169 lines)
- `/home/benjamin/.config/nvim/.claude/context/formats/report-format.md` (131 lines)
- `/home/benjamin/.config/nvim/.claude/context/formats/summary-format.md` (59 lines)
