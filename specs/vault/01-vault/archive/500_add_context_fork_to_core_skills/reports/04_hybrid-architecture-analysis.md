# Research Report: Hybrid Architecture Analysis

**Task**: 500 - Add context: fork to core delegating skills
**Started**: 2026-04-28T18:15:00Z
**Completed**: 2026-04-28T18:50:00Z
**Effort**: deep research (fourth pass, architecture alternatives)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: 10 core skills, 4 extension skills (present: slide-planning, slide-critic)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Fork Subagents - Build This Now](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
- Prior reports: 01, 02, 03 for task 500
- Prior plan: 03_context-fork-refactor.md (v3 plan draft)
**Artifacts**:
- `specs/500_add_context_fork_to_core_skills/reports/04_hybrid-architecture-analysis.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- **The hybrid inline-agent approach proposed in plan v3 has no precedent** in Claude Code's ecosystem. The official docs describe two clean patterns (named subagent vs fork), but no "inline the agent definition into a fork's task prompt" pattern exists anywhere.
- **An existing precedent DOES exist for `context: fork` + `agent:` with multi-stage orchestration**: the `skill-slide-planning` and `skill-slide-critic` extension skills already use this combination AND still call `Task(subagent_type=...)` explicitly. The `context: fork` there provides context isolation (not cache sharing).
- **The fundamental incompatibility confirmed by report 03 is correct**: prompt cache sharing requires forks (anonymous, no agent type); specialized behavior requires named subagents (separate cache). There is no API mechanism to combine them.
- **The inline-agent approach (plan v3 Phase 2) would work mechanically but is unprecedented, fragile, and loses model override capability**. It inlines ~400-800 lines of agent instructions into every Task prompt, which may partially negate cache benefits due to per-invocation prompt bloat.
- **Two better alternative architectures exist**: (A) collapsing the skill+agent layers into a single `context: fork` skill (eliminating the agent), or (B) using the `skills` field on agent definitions to preload orchestration knowledge. Both avoid the inline-instructions hack but neither solves the cache-sharing problem.
- **Recommendation: rescope task 500 to documentation corrections only** (fork-patterns.md accuracy), abandon the implementation phases, and document this analysis as the rationale.

## Context & Scope

### What Was Investigated

This research addresses two questions posed before proceeding with the v3 plan:

1. **Is there precedent for the hybrid inline-agent approach?** The v3 plan proposes omitting `subagent_type` from Task calls and inlining the agent definition into the Task prompt to get fork cache sharing while preserving specialized behavior. Is this pattern used anywhere?

2. **Is there a better alternative architecture?** Could the skill/agent architecture be refactored to achieve the same goals more simply?

### Prior Research Summary

- **Report 01**: Codebase audit. Found all skills use Pattern A (explicit `subagent_type`). Recommended abandoning task 500.
- **Report 02**: Web research. Corrected mechanics -- `context: fork` makes skill body the subagent prompt, not "breaks orchestration". Proposed investigation paths.
- **Report 03**: Definitive analysis. Established that `context: fork` + `agent:` spawns named subagent (separate cache), not a fork (shared cache). Identified inline-agent approach as the only viable path. This was the basis for the v3 plan.

## Findings

### Finding 1: No Precedent for Hybrid Inline-Agent Approach

The v3 plan proposes: omit `subagent_type` from Task calls inside skill bodies, inline the full agent definition (~400-800 lines) into the Task prompt, triggering a fork that inherits the parent's cache while receiving specialized instructions via the prompt.

**Search results**: No Claude Code documentation, blog post, GitHub issue, or community example demonstrates this pattern. The official docs present a clean binary:
- Fork: inherits everything, no agent type, shared cache
- Named subagent: fresh context, agent definition as system prompt, separate cache

**Why it is unprecedented**: The pattern requires manually embedding an agent definition file's content as prose instructions inside a Task prompt. This bypasses the agent resolution system entirely. The fork receives the instructions but:
- Uses the parent's system prompt (not the agent's)
- Uses the parent's model (cannot override to a different model)
- Has the parent's full conversation history (may confuse the instructions)

**Risk assessment**: High. No one has validated that fork subagents correctly follow detailed multi-stage instructions embedded in the Task prompt when they also have the full parent conversation history in context. The agent instructions were written assuming a fresh context window.

### Finding 2: Existing Precedent for `context: fork` + `agent:` WITH Orchestration

The `present` extension contains two skills that use `context: fork` + `agent:` AND have multi-stage orchestration:

**skill-slide-planning** (SKILL.md frontmatter):
```yaml
name: skill-slide-planning
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-planner-agent
```

**skill-slide-critic** (SKILL.md frontmatter):
```yaml
name: skill-slide-critic
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-critic-agent
```

Both skills:
- Have 7-8 stage orchestration flows (validation, status updates, interactive Q&A, delegation, postflight)
- Use `context: fork` AND `agent:` in frontmatter
- ALSO specify `subagent_type` explicitly in their Task call (e.g., `subagent_type: "slide-planner-agent"`)
- Have multiple `allowed-tools` (not just Task)

**Key insight**: In these skills, `context: fork` + `agent:` in the frontmatter and `subagent_type` in the Task call coexist. This means `context: fork` is being used for its context-isolation effect (the SKILL.md body runs as a subagent prompt without parent conversation history), while the explicit `subagent_type` in the Task call controls agent routing. The `agent:` field in the frontmatter may be redundant/declarative when `subagent_type` is also specified.

**What this proves**: `context: fork` with multi-stage orchestration is a proven pattern. The skill body's orchestration instructions (preflight, status updates, interactive Q&A, delegation to another agent, postflight) work correctly when run as a subagent prompt. However, this pattern does NOT provide cache sharing -- it provides context isolation.

### Finding 3: The Fundamental Incompatibility is Confirmed

From the official Claude Code subagents documentation:

| | Fork | Named subagent |
|---|---|---|
| Context | Full conversation history | Fresh context with the prompt you pass |
| System prompt and tools | Same as main session | From the subagent's definition file |
| Model | Same as main session | From the subagent's `model` field |
| Prompt cache | **Shared with main session** | **Separate cache** |

This confirms report 03's finding: prompt cache sharing is exclusive to forks, and forks cannot use custom agent definitions. There is no middle ground in the current API.

Additionally, from the Build This Now guide:
> "The fork path is the most cache-efficient mode... prioritize fork caching over named types when parallelism matters. If you need specialized routing logic, encode it in the task prompt itself rather than relying on agent type names."

This is the only external source suggesting the inline-instructions approach, but it frames it as a general heuristic, not a tested pattern for complex multi-stage orchestration.

### Finding 4: Alternative Architecture A -- Collapse Skill+Agent into Single Fork Skill

Instead of the three-layer architecture (command -> skill -> agent), collapse the skill and agent into a single skill with `context: fork`:

**Current architecture**:
```
/research -> skill-researcher (orchestration) -> Task(general-research-agent)
```

**Collapsed architecture**:
```
/research -> skill-researcher-v2 (context: fork, full research instructions + orchestration)
```

The single skill would contain:
- The orchestration stages from skill-researcher (preflight, status update, context preparation)
- The research methodology from general-research-agent (search strategy, report format, etc.)
- Postflight operations (metadata reading, status update, artifact linking, git commit)

**Pros**:
- Eliminates one delegation layer (no double agent spawn)
- `context: fork` provides context isolation (no parent history leaking)
- Simpler architecture (two layers instead of three)
- The `present` extension already proves `context: fork` with multi-stage orchestration works

**Cons**:
- **Still no cache sharing**: `context: fork` + `agent:` spawns a named subagent with separate cache
- **Loses model override**: Agent definitions can specify `model: opus` or `model: haiku`; fork skills inherit the parent's model
- **Large SKILL.md files**: Merging skill orchestration (200-400 lines) with agent instructions (200-500 lines) creates 400-900 line SKILL.md files
- **Breaks separation of concerns**: Currently, skills handle orchestration and agents handle domain execution
- **Cannot use `agent:` with model override**: When `context: fork` uses a named agent, the model comes from the agent definition. But the skill body becomes the TASK prompt, not the system prompt. The agent definition provides the system prompt. This works, but the agent instructions must not conflict with the skill body's orchestration instructions.
- **Major refactor**: All 10+ skills and their corresponding agents would need to be merged

**Verdict**: Architecturally viable (proven by slide-planning), but does NOT solve the cache-sharing problem and requires a massive refactor with unclear benefits.

### Finding 5: Alternative Architecture B -- Use `skills` Field on Agent Definitions

The official docs reveal that agent definitions support a `skills` field:
> "Use the `skills` field to inject skill content into a subagent's context at startup. This gives the subagent domain knowledge without requiring it to discover and load skills during execution."

This is described as "the inverse of `context: fork`":
> "With `skills` in a subagent, the subagent controls the system prompt and loads skill content. With `context: fork` in a skill, the skill content is injected into the agent you specify. Both use the same underlying system."

**Potential pattern**: Instead of inlining agent instructions into the Task prompt, use the `skills` field on agent definitions to preload orchestration skills:

```yaml
# general-research-agent.md
---
name: general-research-agent
description: Research general tasks
model: opus
skills:
  - orchestration-patterns
  - report-format
---
Research methodology instructions...
```

**Pros**:
- Clean, documented mechanism
- Agent retains its system prompt and model override
- Skill content is injected at startup (not at invocation time)
- No changes to the skill-agent delegation pattern

**Cons**:
- **Still no cache sharing**: This is a named subagent, not a fork
- **Does not address the core problem**: The `skills` field improves agent context loading, but the issue is cache sharing, not context availability
- **Complexity**: Adding skills to agent definitions adds another layer of configuration
- **`disable-model-invocation: true` blocks preloading**: Skills with this flag cannot be preloaded into subagents

**Verdict**: Useful for context management improvements but completely orthogonal to the cache-sharing problem.

### Finding 6: What the v3 Plan Would Actually Achieve

Re-evaluating the v3 plan's Phase 2 (pilot inline-agent approach on skill-researcher):

**Mechanical feasibility**: A fork receiving inlined agent instructions in the Task prompt WOULD execute those instructions. The fork has the parent's tools, conversation history, and model. It would read the research methodology, create reports, update metadata, etc.

**Cache benefit calculation**:
- Shared prefix (parent's system prompt + conversation): ~48,500 tokens (cached)
- Per-fork addition (inlined agent instructions + delegation context): ~3,000-5,000 tokens (not cached)
- Named subagent approach (current): ~48,500 tokens (all fresh, separate cache)
- Net savings: ~43,500-45,500 tokens per invocation

**But**:
- The fork inherits the parent's FULL conversation history. For a fresh `/research` call, this includes all of CLAUDE.md, the command parsing, the skill routing, the preflight operations. This is a lot of irrelevant context.
- The agent definition (general-research-agent.md) is ~400 lines. Inlining this into every Task prompt adds ~2,000-3,000 tokens that are NOT part of the shared cache prefix (they are per-invocation).
- The fork cannot override the model. If general-research-agent specifies `model: opus` but the parent session is running Sonnet, the fork runs Sonnet.
- Fork children cannot spawn further forks. If the research agent needs to use Explore or another subagent, it can only spawn named subagents (separate cache).

**Net assessment**: The cache sharing benefit is real but the trade-offs are significant. The inline approach is a hack that works around the API limitation rather than solving it cleanly.

### Finding 7: The Real Question -- Is Cache Sharing Worth the Complexity?

The core skills are invoked ~1-3 times per task lifecycle (research once, plan once, implement once). Each invocation spawns a single subagent that runs for 5-30 minutes. The cache sharing benefit applies to the FIRST request of the subagent only (subsequent requests within the subagent already benefit from their own cache).

**Where cache sharing matters most**: Team mode, where 2-4 parallel teammates each spawn simultaneously from the same parent. Here the savings multiply: teammates 2-N get ~90% input token reduction on their first request.

**Where cache sharing matters least**: Single-agent operations (the standard case for core skills), where only one subagent is spawned per invocation. The first-request savings are real but are amortized over the full multi-turn subagent session.

Team mode (task 501) already spawns agents WITHOUT `subagent_type`, making it eligible for FORK_SUBAGENT cache sharing without any changes to core skills. This is the correct place for the optimization.

## Decisions

1. **The hybrid inline-agent approach is unprecedented and fragile.** No external source validates this pattern for complex multi-stage orchestration. It should not be implemented without a Claude Code API change that enables "named fork" (cache sharing + agent routing).

2. **The `context: fork` + orchestration pattern IS proven** by the slide-planning and slide-critic skills, but it does NOT provide cache sharing -- only context isolation.

3. **Neither alternative architecture (A: collapse skill+agent, B: `skills` field on agents) solves the cache-sharing problem.** Both are orthogonal improvements that could be pursued independently.

4. **Cache sharing matters most for team mode** (task 501), not for single-agent core skill invocations. The optimization effort should be directed there.

5. **Task 500 should be rescoped to Phase 1 only** (documentation corrections to fork-patterns.md), with Phases 2-4 of the v3 plan abandoned.

## Recommendations

### Recommendation 1: Rescope Task 500 to Documentation Only

Keep Phase 1 of the v3 plan (correct fork-patterns.md with definitive findings from reports 03 and 04). Abandon Phases 2-4 (prototype, rollout, decision record for hybrid approach). The documentation corrections have standalone value regardless of the cache-sharing decision.

Specific corrections for fork-patterns.md:
- Clarify that `context: fork` + `agent:` spawns named subagent (separate cache, not shared)
- Add the official Named Subagent vs Fork comparison table
- Document that slide-planning/slide-critic prove `context: fork` + orchestration works
- Add version requirements (v2.1.101 for `context: fork` fix, v2.1.117+ for FORK_SUBAGENT)
- Note the `skills` field on agents as an alternative for context injection

### Recommendation 2: Defer Cache Sharing to Task 501 (Team Mode)

Team mode is the correct optimization target for FORK_SUBAGENT cache sharing. Team skills already spawn agents without `subagent_type`, making them naturally eligible.

### Recommendation 3: Consider Architecture A (Collapse) as a Separate Future Task

Collapsing the skill+agent layers into single `context: fork` skills is architecturally interesting but orthogonal to cache sharing. It would simplify the delegation chain and reduce agent spawn overhead. If pursued, it should be its own task with proper research into the trade-offs (model override loss, SKILL.md size, separation of concerns).

### Recommendation 4: Monitor Claude Code for "Named Fork" API

The fundamental limitation is that no API mechanism combines agent routing with cache sharing. If Anthropic introduces a `fork: true` parameter on Agent/Task calls or a similar mechanism, task 500's original goal becomes achievable. Monitor the Claude Code changelog and GitHub issues.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| v3 plan is implemented despite this analysis | High | This report documents why each alternative fails; link from plan |
| fork-patterns.md remains inaccurate | Medium | Recommendation 1 addresses this as standalone work |
| Cache sharing benefits are overestimated | Low | Finding 7 shows single-agent cache savings are minor vs multi-turn session cost |
| Anthropic adds "named fork" API | Positive risk | Would unblock the original task goal; monitor changelog |

## Appendix

### Search Queries Used

1. `Claude Code FORK_SUBAGENT named subagent cache sharing combine agent routing 2026`
2. `Claude Code "context: fork" skill agent architecture refactor inline agent instructions prompt 2026`
3. Official docs: `https://code.claude.com/docs/en/sub-agents` (full page)
4. Official docs: `https://code.claude.com/docs/en/skills` (full page)
5. Build This Now: `https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent`

### Key Codebase Files Examined

- `.claude/skills/skill-researcher/SKILL.md` - Core skill orchestration pattern (Pattern A)
- `.claude/skills/skill-meta/SKILL.md` - Hybrid pattern (agent: yes, context: fork: no)
- `.claude/extensions/present/skills/skill-slide-planning/SKILL.md` - Proven `context: fork` + orchestration
- `.claude/extensions/present/skills/skill-slide-critic/SKILL.md` - Proven `context: fork` + orchestration
- `.claude/agents/general-research-agent.md` - Agent definition that would need inlining
- `.claude/context/patterns/fork-patterns.md` - Current fork documentation (needs corrections)
- `.claude/context/architecture/system-overview.md` - Three-layer architecture reference

### Architecture Decision Summary

| Approach | Cache Sharing | Agent Routing | Precedent | Verdict |
|----------|--------------|---------------|-----------|---------|
| Current (Pattern A) | No | Yes | Proven | Keep for correctness |
| `context: fork` + `agent:` (Pattern B) | No | Yes | Proven (slide skills) | Context isolation only |
| Inline agent in fork prompt (v3 plan) | Yes | Partial | None | Fragile, unprecedented |
| Collapse skill+agent (Alt A) | No | Partial | Proven concept | Orthogonal to problem |
| `skills` field on agents (Alt B) | No | Yes | Documented | Orthogonal to problem |
| Team mode fork (task 501) | Yes | No (general fork) | Eligible | Correct optimization target |

### References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Fork Subagents Guide - Build This Now](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
- [Claude Code Advanced Patterns - Trensee](https://www.trensee.com/en/blog/explainer-claude-code-skills-fork-subagents-2026-03-31)
- [Forked Subagents Analysis - Mejba Ahmed](https://www.mejba.me/blog/forked-subagents-claude-code-anthropic)
