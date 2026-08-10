# Research Report: Task #132

**Task**: OC_132 - Create context loading best practices guide
**Date**: 2026-03-04
**Language**: meta
**Focus**: Document "Push vs Pull" context loading strategies

## Summary

This report documents the findings on the "Push vs Pull" context loading strategy that was implemented in Task 128. The research analyzed existing SKILL.md files, context patterns, and the skill-structure.md standard to understand: (1) the Push model using `<context_injection>` blocks for critical context, (2) the Pull model via @-references for optional context, and (3) implementation patterns from skill-planner, skill-researcher, and skill-implementer. The goal is to create a comprehensive guide at `docs/guides/context-loading-best-practices.md` that helps skill developers understand and apply these patterns correctly.

## Findings

### Existing Documentation Gap

**Current State**: A comprehensive context loading guide exists at `.claude/docs/guides/context-loading-best-practices.md` (896 lines) but it focuses on the deprecated "Pull" model with lazy/eager/conditional loading strategies using frontmatter configuration. The guide does NOT cover the new "Push" model implemented in Task 128.

**Gap Identified**: The OpenCode `.opencode/docs/guides/` directory lacks documentation on the Push Context model, even though all 11 core skills have been migrated to use it.

### Push Model: Critical Context Injection

**Definition**: The Push model injects critical context files directly into agent prompts via `<context_injection>` XML blocks in SKILL.md files.

**Structure** (from `skill-structure.md` v2.0):

```xml
<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Delegate">
    <action>Use {variable_name} in operations</action>
  </stage>
</execution>
```

**Examples from Core Skills**:

1. **skill-planner**: Injects `plan-format.md`, `status-markers.md`, `task-breakdown.md`
2. **skill-researcher**: Injects `report-format.md`, `status-markers.md`
3. **skill-implementer**: Injects `return-metadata-file.md`, `postflight-control.md`, `file-metadata-exchange.md`, `jq-escaping-workarounds.md`
4. **skill-orchestrator**: Injects `orchestration-core.md`, `state-management.md`

**Execution Flow**:
1. Skill executor reads files defined in `<context_injection>`
2. Content stored in specified variables (e.g., `{plan_format}`)
3. Variables injected into agent prompt via `<system_context>` block
4. Agent uses injected context without additional Read calls

### Pull Model: On-Demand Context Loading

**Definition**: The Pull model loads context on-demand via @-references in agent prompts or skill files.

**When Used**:
- Optional documentation
- Code examples
- Large reference files that are not always needed
- Files that change frequently

**Example from `context/index.md`**:
```markdown
Load for: Artifact creation
- **plan-format.md** - Implementation plan structure
- **report-format.md** - Research report structure
```

**Pattern**:
```markdown
## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
```

### When to Use Each Approach

**Push Model (Critical Context)**:
1. **Strict formats** that MUST be followed (plan-format.md, report-format.md)
2. **Status markers** that control workflow state (status-markers.md)
3. **Standards** that affect output quality (lean4-style-guide.md for Lean tasks)
4. **Delegation patterns** that ensure safety (orchestration-core.md)
5. **Workflow control** mechanisms (postflight-control.md, file-metadata-exchange.md)

**Pull Model (Optional Context)**:
1. **Documentation** that provides background but isn't strictly required
2. **Code examples** that illustrate patterns but don't enforce them
3. **Reference guides** that are consulted as needed
4. **Project-specific context** that varies by task type
5. **Large files** (>500 lines) that would bloat the context window

### Implementation in Skills

**Step 1: Define context_injection block**:
```xml
<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>
```

**Step 2: Read context in Stage 1**:
```xml
<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
```

**Step 3: Inject into agent prompt**:
```markdown
Call `Task` tool with prompt:
"""
Create implementation plan for task {N}.

<system_context>
Using the following format standards:
{plan_format}
{status_markers}
</system_context>
"""
```

**Migration Pattern** (from Task 128):
- 11 skills migrated: orchestrator, planner, researcher, implementer, meta, learn, refresh, status-sync, git-workflow, neovim-research, neovim-implementation
- All migrated skills follow the v2.0 skill-structure.md standard
- Each skill declares 2-5 context files in `<context_injection>`
- Context variables referenced using `{variable_name}` syntax in execution stages

### Benefits and Trade-offs

**Push Model Benefits**:
1. **Reliability**: Agents cannot "forget" to load context - it's injected automatically
2. **Consistency**: All agents receive the exact same version of standards
3. **Performance**: Reduces tool calls (no Read calls needed by agents)
4. **Maintainability**: Context dependencies explicitly declared in skill files
5. **Debugging**: Clear visibility into what context each skill requires

**Pull Model Benefits**:
1. **Context efficiency**: Only load what's needed, when needed
2. **Flexibility**: Easy to reference different files for different scenarios
3. **Lower latency**: Smaller initial context for faster startup

**Hybrid Approach** (Recommended):
- Push for critical standards and formats (must-follow rules)
- Pull for documentation and examples (reference material)
- Skills use Push for workflow-critical context
- Agents use Pull for task-specific research

## Recommendations

1. **Create the guide at `.opencode/docs/guides/context-loading-best-practices.md`**
   - Focus on Push vs Pull distinction
   - Provide concrete examples from existing skills
   - Include decision tree for when to use each approach

2. **Structure the guide with these sections**:
   - Introduction: Why context loading matters
   - Push Model: Critical context injection via `<context_injection>`
   - Pull Model: On-demand loading via @-references
   - Decision Framework: When to use each approach
   - Implementation Guide: Step-by-step for skill developers
   - Examples: Real patterns from skill-planner, skill-researcher, skill-implementer
   - Migration Guide: How to migrate existing skills from Pull to Push

3. **Include these concrete examples**:
   - Skill-planner: 3 injected files (plan-format.md, status-markers.md, task-breakdown.md)
   - Skill-researcher: 2 injected files (report-format.md, status-markers.md)
   - Skill-implementer: 4 injected files (return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md)

4. **Reference existing standards**:
   - Link to `skill-structure.md` v2.0 for the Push Context standard
   - Link to `context/index.md` for the Pull Context catalog
   - Cross-reference `.claude/docs/guides/context-loading-best-practices.md` for historical context

5. **Add a decision checklist**:
   - Is this context required for correct operation? (Yes -> Push)
   - Is this context a strict format/standard? (Yes -> Push)
   - Is this context optional reference material? (Yes -> Pull)
   - Is this context >500 lines? (Yes -> Consider Pull)

## Risks & Considerations

- **Duplication risk**: The new guide must not duplicate the deprecated `.claude/docs/guides/context-loading-best-practices.md` but should focus specifically on the Push model
- **Maintenance**: The guide must be kept in sync with `skill-structure.md` as the standard evolves
- **Clarity**: Developers may be confused by having two context loading guides; the new one must clearly distinguish itself by focusing on Push patterns
- **Migration fatigue**: Teams may resist migrating more skills to Push model if not clearly documented; the guide should make the benefits explicit

## Next Steps

Run `/plan OC_132` to create an implementation plan for the guide.
