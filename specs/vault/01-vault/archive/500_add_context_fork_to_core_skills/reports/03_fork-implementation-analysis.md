# Research Report: Definitive Fork Implementation Analysis

- **Task**: 500 - Add context: fork to core delegating skills
- **Started**: 2026-04-28T16:10:00Z
- **Completed**: 2026-04-28T16:45:00Z
- **Effort**: deep research (third pass, correcting prior reports)
- **Dependencies**: None
- **Sources/Inputs**:
  - [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
  - [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
  - [GitHub Issue #16803 - context: fork doesn't work inline](https://github.com/anthropics/claude-code/issues/16803) (fixed in v2.1.101)
  - [GitHub Issue #17283 - Skill tool should honor context: fork](https://github.com/anthropics/claude-code/issues/17283) (closed as dup of #16803)
  - [Fork Subagents - Build This Now](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
  - Codebase: 10 core skills, 55 extension skills, fork-patterns.md
- **Artifacts**: `specs/500_add_context_fork_to_core_skills/reports/03_fork-implementation-analysis.md`
- **Standards**: report-format.md, artifact-management.md

## Executive Summary

- **`context: fork` + `agent:` spawns a NAMED subagent, NOT a fork** -- the skill body becomes the task, the agent definition provides the system prompt. Named subagents get a **SEPARATE prompt cache** (no cache sharing).
- **FORK_SUBAGENT only fires when `subagent_type` is OMITTED** from Agent/Task tool calls AND no named agent type is resolved. Forks inherit the parent's prompt cache (~90% input token savings).
- **These are fundamentally incompatible goals**: `context: fork` + `agent:` gives isolation but SEPARATE cache. Omitting `subagent_type` gives cache sharing but NO explicit agent routing.
- **The correct implementation for cache sharing is NOT `context: fork`** -- it is removing `subagent_type` from Task calls inside skill bodies. But this loses explicit agent routing (the skill would spawn a general-purpose fork instead of the intended specialized agent).
- **There is NO mechanism in Claude Code today** that combines both explicit agent routing AND prompt cache sharing. This is an architectural limitation.
- **Recommendation**: Task 500 should be rescoped or abandoned. The two features solve different problems and cannot be combined to achieve the desired outcome.

## Context & Scope

This is the third research pass for task 500. The first two passes had incomplete understanding of the fork mechanics. This pass answers the definitive question: **can the existing skill/agent system be modified to benefit from FORK_SUBAGENT prompt cache sharing?**

### Version Context

- Current Claude Code: v2.1.122
- FORK_SUBAGENT requires: v2.1.117+
- `context: fork` fix (for plugins): v2.1.101
- `context: fork` for local/project skills: working since v2.1.0

## Findings

### Finding 1: Two Distinct Fork Concepts (Clarified)

The term "fork" in Claude Code refers to two independent mechanisms:

**Mechanism A: `context: fork` (skill frontmatter)**

- Triggers when: Skill has `context: fork` in frontmatter and is invoked via Skill tool
- Effect: SKILL.md body becomes the TASK prompt sent to a subagent
- System prompt: From the `agent:` field's definition (defaults to `general-purpose`)
- Cache behavior: **SEPARATE cache** (named subagent, fresh context)
- Loses: Parent conversation history
- Fixed in: v2.1.101 for plugins; working since v2.1.0 for local/project skills

**Mechanism B: `CLAUDE_CODE_FORK_SUBAGENT=1` (environment variable)**

- Triggers when: Agent/Task tool is called WITHOUT `subagent_type` parameter
- Effect: Child inherits parent's entire conversation context (system prompt, history, tools)
- Cache behavior: **SHARED prompt cache** (~90% input token savings)
- Loses: Nothing (additive optimization)
- Constraint: A fork cannot spawn further forks
- When named type IS specified: Fork does NOT trigger; normal named subagent is spawned

### Finding 2: Named Subagents vs Forks (Official Docs)

From the official Claude Code subagent documentation, the "How forks differ from named subagents" table:

| Aspect | Fork | Named Subagent |
|--------|------|----------------|
| Context | Full conversation history | Fresh context with prompt |
| System prompt | Same as main session | From definition file |
| Model | Same as main session | From `model` field |
| **Prompt cache** | **Shared with main session** | **Separate cache** |

This is the crux: **prompt cache sharing is exclusive to forks**. Named subagents (including those spawned by `context: fork` + `agent:`) always get a separate cache.

### Finding 3: Current Skill Architecture (All 65 Skills)

Every skill in the system uses explicit `subagent_type` in Task tool calls:

**Core skills** (10):
- skill-researcher -> `subagent_type: "general-research-agent"`
- skill-planner -> `subagent_type: "planner-agent"`
- skill-implementer -> `subagent_type: "general-implementation-agent"`
- skill-meta -> `subagent_type: "meta-builder-agent"`
- skill-reviser -> `subagent_type: "reviser-agent"`
- skill-spawn -> `subagent_type: "spawn-agent"`
- skill-neovim-research -> `subagent_type: "neovim-research-agent"`
- skill-neovim-implementation -> `subagent_type: "neovim-implementation-agent"`
- skill-nix-research -> `subagent_type: "nix-research-agent"`
- skill-nix-implementation -> `subagent_type: "nix-implementation-agent"`

**Extension skills** (55): All follow the same pattern.

Because `subagent_type` is always specified, `CLAUDE_CODE_FORK_SUBAGENT=1` has **zero effect** on any skill invocation. Every single subagent spawned by a skill gets a fresh, separate prompt cache.

### Finding 4: GitHub Issues Status

**Issue #16803** (context: fork not working inline):
- Opened: ~Jan 8, 2026
- Closed: April 18, 2026 (Anthropic collaborator confirmed fix in v2.1.101)
- The bug was: `context: fork` in skill frontmatter was ignored; skill ran inline
- The fix was: plugin-loaded skills now honor `context: fork` and `agent:` fields
- Community testing showed: `context: fork` works for `.claude/skills/` but NOT plugins until v2.1.101

**Issue #17283** (Skill tool should honor context: fork + agent:):
- Opened: Jan 10, 2026
- Closed: Jan 10, 2026 (auto-closed as duplicate of #16803)
- Not independently fixed; the fix for #16803 covers this

**Confirmation**: Both issues are now resolved. `context: fork` + `agent:` in skill frontmatter works as documented in v2.1.101+. Our Claude Code is v2.1.122, so we're covered.

### Finding 5: Analysis of Each Proposed Implementation Path

**Option A: Add `context: fork` + `agent:` to frontmatter only**

What this does:
- When the Skill tool invokes the skill, the SKILL.md body becomes the task prompt for the named agent
- The skill's orchestration logic (preflight, status updates, memory injection, postflight) runs inside the subagent as its task
- The subagent gets the system prompt from the named agent definition

Cache benefit: **NONE**. The subagent is named (via `agent:` field), so it gets a separate cache.

Impact on current behavior:
- The skill body currently executes in the PARENT context as orchestration code
- With `context: fork`, it would execute as a task prompt INSIDE the subagent
- The subagent would interpret the SKILL.md body (all the Stage 1-10 instructions) as its task
- The subagent would ALSO load its own agent definition (e.g., general-research-agent.md)
- This creates DOUBLE delegation: Skill -> named-subagent-A (running skill orchestration as task) -> named-subagent-B (the actual research agent)
- Or worse: the first subagent might try to use the Task tool to spawn the second, but "subagents cannot spawn other subagents"

**Verdict: Option A breaks the architecture and provides zero cache benefit.**

**Option B: Remove `subagent_type` from Task calls in skill bodies**

What this does:
- Skill body still executes inline (no `context: fork`)
- When the skill calls `Task(prompt=...)` without `subagent_type`, FORK_SUBAGENT triggers
- A fork is spawned that inherits the parent's full conversation context
- The fork gets the skill's prompt as its task

Cache benefit: **YES**, ~90% input token savings.

Problem:
- The fork inherits the PARENT's system prompt and tools, NOT the specialized agent's
- The fork does NOT load `general-research-agent.md` or `planner-agent.md` as its system prompt
- The fork is a general-purpose agent with parent conversation history -- it has no specialized instructions
- The skill body currently passes the agent definition name via `subagent_type` -- removing it means the specialized agent definition is never loaded
- The `agent:` frontmatter on the skill is only relevant for `context: fork` scenarios; it does NOT affect Task tool routing

Impact:
- The subagent would receive the delegation prompt but would NOT have the specialized agent instructions (research methodology, plan format requirements, etc.)
- This would dramatically reduce output quality -- the agents carry critical process knowledge in their markdown body

**Verdict: Option B provides cache sharing but loses agent specialization.**

**Option C: Both A and B**

This is self-contradictory. Option A uses `context: fork` (skill body becomes subagent task). Option B keeps skill body inline and removes `subagent_type`. They cannot coexist.

**Option D: `context: fork` WITHOUT `agent:` field**

What this does:
- Skill body becomes the task for a `general-purpose` subagent
- When FORK_SUBAGENT is enabled, the docs say "Claude spawns a fork whenever it would otherwise use the general-purpose subagent"
- So this MIGHT trigger a fork with cache sharing

Problems:
- The skill body (orchestration instructions) becomes the fork's task prompt
- The fork inherits parent's context BUT also gets the skill body as its task
- The fork would try to execute the orchestration stages (preflight, Task call, postflight)
- But forks cannot spawn other subagents (no nesting)
- So the fork would fail at Stage 5 when it tries to call Task tool to spawn the research agent

**Verdict: Option D fails due to nesting prohibition.**

**Option E: Restructure skills to remove orchestration layer**

What this does:
- Move all preflight/postflight logic into the skill's `context: fork` body
- The skill body itself IS the research/planning/implementation prompt (no inner delegation)
- Use `agent:` to specify the agent type for tool/model configuration only
- The subagent runs the full workflow directly

Cache benefit: **NONE** -- still a named subagent via `agent:`.
Architecture impact: **MASSIVE** -- requires rewriting all 65 skills and merging skill orchestration with agent instructions. The current separation of concerns (skill = orchestration, agent = execution) would be eliminated.

**Verdict: Option E is a major architectural rewrite for zero cache benefit.**

### Finding 6: The Fundamental Incompatibility

The architectural tension is:

1. **Prompt cache sharing** requires the child to inherit the parent's system prompt and conversation. This only works with **forks** (anonymous, no agent type specified).

2. **Specialized agent behavior** requires the child to use a specific agent definition as its system prompt. This only works with **named subagents** (explicit agent type specified).

These are mutually exclusive by design. A fork uses the parent's system prompt; a named subagent uses its own definition file. There is no mechanism in Claude Code today that says "use THIS agent's system prompt BUT share the parent's prompt cache."

### Finding 7: What WOULD Enable Cache Sharing

For the existing architecture to benefit from FORK_SUBAGENT, Anthropic would need to implement one of:

1. **Named fork**: An `Agent(type="general-research-agent", fork=true)` parameter that spawns the named agent BUT inherits the parent's prompt cache prefix. This does not exist.

2. **Skills field on forks**: Inject agent instructions via `skills:` field on the fork, like preloading skills into subagents. The fork would keep cache sharing while gaining specialized instructions. The `skills:` field exists for named subagents but there's no mechanism to apply it to forks.

3. **Prompt cache persistence**: A mechanism where the prompt cache is stored and reused across separate subagent invocations, not just parent-child forks. This would make named subagents benefit from cache without forking.

None of these exist today.

## Verdict

**Given this specific agent system, there is NO correct implementation to enable FORK_SUBAGENT cache sharing for the existing skill/agent architecture.**

The task 500 description asks for "context: fork + agent: frontmatter for core delegating skills to enable CLAUDE_CODE_FORK_SUBAGENT=1 cache sharing." This cannot be achieved because:

1. `context: fork` + `agent:` spawns a **named subagent** with **separate cache** (no FORK_SUBAGENT benefit)
2. Removing `subagent_type` from Task calls triggers FORK_SUBAGENT but **loses specialized agent instructions**
3. There is no middle ground in the current Claude Code API

## Recommendations

### Recommendation 1: Rescope or Abandon Task 500

The original task premise is based on an incorrect understanding that `context: fork` enables `FORK_SUBAGENT` cache sharing. It does not. The task should be:
- **Abandoned** if the only goal was cache sharing, OR
- **Rescoped** to one of the actionable items below

### Recommendation 2: Update fork-patterns.md (Actionable Now)

The existing `fork-patterns.md` has several inaccuracies and missing information revealed by this research. Specific corrections:
- Clarify that `context: fork` + `agent:` spawns named subagent (separate cache)
- Document the named-subagent vs fork cache distinction
- Add v2.1.101 fix status for Issue #16803
- Add the v2.1.117+ requirement for FORK_SUBAGENT

### Recommendation 3: File Feature Request with Anthropic

Request a `fork: true` parameter on Agent/Task tool calls that combines named agent routing with prompt cache sharing. This is the only way to achieve what task 500 originally intended.

### Recommendation 4: Team-Mode Optimization (Task 501)

Team-mode skills already spawn agents WITHOUT `subagent_type` via Agent tool calls. These ARE eligible for FORK_SUBAGENT cache sharing. Task 501 (already created) is the correct place for this optimization.

### Recommendation 5: Context Injection Alternative

Instead of using named agents, consider restructuring skills to:
1. Omit `subagent_type` from Task calls (trigger fork)
2. Include the full agent instructions IN the Task prompt (inline the agent definition)

This would give cache sharing PLUS specialized behavior, at the cost of:
- Larger Task prompts (agent definition inlined rather than loaded as system prompt)
- Loss of the model field override from agent definitions
- Higher per-invocation prompt token count (but shared via cache)

This hybrid approach requires evaluation but may be the only practical path.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Removing `subagent_type` loses agent specialization | High | Option E inline agent instructions in prompt |
| `context: fork` breaks skill orchestration layer | High | Do not use for core skills |
| Fork cannot spawn subagents (nesting prohibition) | Blocking | Cannot use fork for skills that delegate |
| FORK_SUBAGENT is experimental (v2.1.117+) | Medium | Already past minimum version |
| Agent definition changes not reflected in cache | Low | Cache refreshes on system prompt change |

## Decisions

1. `context: fork` is NOT the mechanism for enabling FORK_SUBAGENT cache sharing
2. The current architecture's explicit `subagent_type` prevents any FORK_SUBAGENT benefit
3. The only viable path for cache sharing requires either (a) an Anthropic API change or (b) inlining agent definitions into Task prompts (Recommendation 5)
4. Task 500 should be rescoped to update fork-patterns.md with correct information, rather than implementing a nonexistent feature

## Appendix

### Search Queries Used

1. `Claude Code GitHub issue 17283 "context: fork" agent frontmatter Skill tool 2026`
2. `CLAUDE_CODE_FORK_SUBAGENT environment variable how subagent routing works omit subagent_type`
3. `Claude Code "context: fork" skill frontmatter what does it actually do 2026 official documentation`
4. `Claude Code skill "agent:" frontmatter field subagent_type routing how agent field works 2026`
5. `site:github.com/anthropics/claude-code issue 17283 closed fixed status`
6. `Claude Code changelog v2.1.101 "context: fork" plugin fix 2026`
7. `Claude Code "context: fork" "agent:" spawns named subagent OR fork subagent prompt cache`
8. `Claude Code "context: fork" without agent field general-purpose FORK_SUBAGENT cache sharing`

### GitHub Issue Timeline

| Date | Event |
|------|-------|
| Jan 8, 2026 | Issue #16803 opened (context: fork not working for plugins) |
| Jan 8, 2026 | Community member reports `context: fork` + `agent:` works for local skills |
| Jan 10, 2026 | Issue #17283 opened and auto-closed as duplicate of #16803 |
| Feb 5, 2026 | Still broken in v2.1.31 |
| Mar 7, 2026 | Still broken in v2.1.71 |
| Apr 10, 2026 | v2.1.101 released with fix |
| Apr 18, 2026 | Issue #16803 closed by Anthropic collaborator (fix confirmed) |

### References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [GitHub Issue #16803](https://github.com/anthropics/claude-code/issues/16803)
- [GitHub Issue #17283](https://github.com/anthropics/claude-code/issues/17283)
- [Fork Subagents Guide](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog)
