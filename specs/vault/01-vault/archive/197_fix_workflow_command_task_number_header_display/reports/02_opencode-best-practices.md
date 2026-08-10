# Research Report: Task #197 - OpenCode Best Practices

**Task**: OC_197 - Fix workflow command task number header display
**Started**: 2026-03-13T00:00:00Z
**Completed**: 2026-03-13T01:00:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Web research (OpenCode docs, CLI UX guides), codebase analysis
**Artifacts**: - This research report (supplemental to research-001.md)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

Web research reveals that OpenCode does NOT have built-in framework-level header display mechanisms. The existing implementation plan's approach of adding explicit "Display header" steps to preflight sections is appropriate and aligns with CLI UX best practices.

**Key Findings:**
- OpenCode commands rely on prompt-level templates, not framework-level display mechanisms
- CLI UX best practices emphasize immediate feedback and status communication
- The proposed fix (adding "Display header" steps) is the correct approach
- Consider enhancing the header format to include action context (e.g., "[Researching]")

**Recommendation**: Proceed with the implementation plan as designed, with one minor enhancement: use action-prefixed headers for better visual clarity.

## Context & Scope

This supplemental research investigates:
1. How OpenCode CLI handles dynamic header display in commands
2. Best practices for command preflight output formatting in CLI tools
3. Whether there are better approaches than the current plan proposes
4. Whether OpenCode has built-in mechanisms for dynamic header/status display

## Findings

### 1. OpenCode Command Architecture

OpenCode commands are defined as prompt templates that get sent to LLMs. Key characteristics:

**No Built-in Header Mechanisms:**
- OpenCode does NOT provide framework-level header rendering
- Commands use "semantic integration" - content flows into prompts rather than displaying separately
- Status information must be handled through prompt-level documentation

**Command Template Features:**
- `$ARGUMENTS` placeholder for passing arguments
- `@filename` syntax for file content injection
- Shell output injection via backtick syntax
- YAML frontmatter for metadata (description, agent, model)

**Sources:**
- [OpenCode Commands Documentation](https://opencode.ai/docs/commands/)
- [OpenCode CLI Documentation](https://opencode.ai/docs/cli/)

### 2. CLI UX Best Practices for Status Display

Research into CLI UX patterns reveals consistent guidance:

**Immediate Feedback (clig.dev):**
- "Print something to the user in <100ms"
- Programs appearing unresponsive damage user confidence
- When state changes occur, inform users about actions

**Progress Communication (Evil Martians):**
- Use gerund forms during execution ("downloading", "creating")
- Switch to past tense upon completion ("downloaded", "created")
- Avoid silence - display meaningful status updates

**Output Clarity:**
- Use green colors and checkmarks for successful outcomes
- "Humans come first, machines second"
- Git's approach demonstrates effective status communication

**Sources:**
- [Command Line Interface Guidelines](https://clig.dev/)
- [CLI UX Best Practices: Progress Displays](https://evilmartians.com/chronicles/cli-ux-best-practices-3-patterns-for-improving-progress-displays)

### 3. Existing Project Standards

The project already defines clear header format standards in `command-output.md`:

**Task-Based Commands:**
```
Task: {task_number}

{summary}
```

**Command Responsibilities:**
- Orchestrator (Stage 5: PostflightCleanup) adds headers based on command type
- Headers are added based on command type detected in Stage 1
- Subagents do NOT add headers or conclusions

**Gap Identified:**
The standard specifies output format for COMPLETION but not for PREFLIGHT start. The commands reference "Display header" in Critical Notes but lack explicit instructions.

### 4. Analysis of Current Implementation Plan

The implementation plan proposes adding "Display header" steps to preflight sections:

```markdown
**Display header**:
```
[Researching] task OC_{N}: {project_name}
```
```

**Assessment: This approach is correct.**

Rationale:
1. No OpenCode framework-level alternative exists
2. Aligns with CLI UX best practices (immediate feedback)
3. Uses gerund form ("[Researching]") per progress display patterns
4. Matches existing project header format standards

### 5. Alternative Approaches Considered

**Alternative 1: Modify frontmatter `description` field**
- Not viable - frontmatter is static metadata, doesn't support dynamic values
- Would require OpenCode framework changes

**Alternative 2: Add header display to command-lifecycle.md standard**
- Possible but overly complex - requires updating all workflow command documentation
- Current approach (explicit step in each command) is simpler and clearer

**Alternative 3: Create reusable skill for header display**
- Overkill for a simple display operation
- Would add unnecessary complexity and latency

**Recommendation**: Proceed with explicit "Display header" steps as planned.

## Recommendations

### 1. Proceed with Implementation Plan

The existing plan is sound. Add explicit "Display header" steps to:
- `.opencode/commands/research.md` (Section 3. Execute Preflight)
- `.opencode/commands/plan.md` (Section 3. Execute Preflight)
- `.opencode/commands/implement.md` (Section 4. Execute Preflight)

### 2. Enhanced Header Format

Consider using action-prefixed format for visual clarity:

```
[Researching] task OC_197: fix_workflow_command_task_number_header_display
```

Instead of just:
```
Researching task OC_197: fix_workflow_command_task_number_header_display
```

The bracket notation provides clearer visual separation and matches status marker conventions used elsewhere in the project.

### 3. Update implement.md Critical Notes

As noted in research-001.md, `implement.md` is missing "Display header" from its Critical Notes section. This should be fixed as part of the implementation.

### 4. Consider Future Enhancement

For future consideration (not part of this task):
- Add a "Preflight Header Format" section to `command-output.md` standard
- This would formalize the header display requirement for all workflow commands

## Decisions

1. **Approach**: Use explicit "Display header" steps in preflight sections (confirmed as best approach)
2. **Format**: Use `[Action]` prefix for visual clarity (e.g., `[Researching]`)
3. **Scope**: Fix all three workflow commands plus implement.md Critical Notes
4. **No Framework Changes**: Do not attempt to modify OpenCode core (not needed)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Header display inconsistency | Low | Use identical format pattern across all commands |
| Placeholder substitution failure | Medium | Use actual values extracted from state.json, not static placeholders |
| Display timing issues | Low | Place header display FIRST in preflight, before status updates |

## Context Extension Recommendations

**None** - This task is meta-focused and the research confirms the existing approach is correct. No new context documentation is needed.

## Appendix

### Web Research Sources

1. [OpenCode Commands](https://opencode.ai/docs/commands/) - Command template structure
2. [OpenCode CLI](https://opencode.ai/docs/cli/) - CLI patterns and output formatting
3. [Command Line Interface Guidelines](https://clig.dev/) - CLI UX best practices
4. [CLI UX Progress Displays](https://evilmartians.com/chronicles/cli-ux-best-practices-3-patterns-for-improving-progress-displays) - Status display patterns

### Codebase Files Reviewed

- `.opencode/commands/research.md` - Current preflight implementation
- `.opencode/commands/plan.md` - Current preflight implementation
- `.opencode/commands/implement.md` - Current preflight implementation
- `.opencode/context/core/formats/command-output.md` - Header format standard
- `.opencode/context/core/orchestration/preflight-pattern.md` - Preflight pattern
- `.opencode/context/core/workflows/command-lifecycle.md` - Command lifecycle

### Key Finding from OpenCode Documentation

> "OpenCode does not explicitly define built-in mechanisms for dynamic header/status display in custom commands... Status information appears to be handled through prompt-level documentation rather than framework-level display mechanisms."

This confirms the implementation plan's approach is the only viable option within the current OpenCode architecture.

## Next Steps

Run `/implement 197` to execute the implementation plan.
