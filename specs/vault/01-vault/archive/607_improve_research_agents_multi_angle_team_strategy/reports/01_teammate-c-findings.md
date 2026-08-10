# Teammate C Findings: Critic Analysis

**Task**: 607 - Improve research agents with multi-angle team research strategy
**Date**: 2026-05-22
**Role**: Critic
**Confidence Level**: High

---

## Key Findings

### 1. The `team_size` Parameter Is Already Dead Code

The SKILL.md declares `team_size` as a parameter (2-4, default 2) but then hardcodes `team_size=4` on line 74, ignoring whatever was passed. This means:

- The `--team-size N` flag on `/research` does nothing
- The proposal to add "dynamic team sizing" is building on a parameter that has never actually worked
- Any design that relies on the existing `team_size` plumbing will inherit this bug

**Implication**: Before adding dynamic sizing, fix or remove the dead code. Otherwise the new feature will be confused by two competing team-size declarations.

### 2. No Evidence That More Agents = Better Research

The task description and user prompt assume that spawning more agents for harder problems produces better results. There is zero measurement infrastructure for this claim. Specifically:

- No A/B comparison between single-agent and team research on the same task
- No quality scoring of synthesized reports vs. single-agent reports
- No tracking of whether teammate findings actually influenced the final recommendation
- The synthesis step is a single read-and-merge by the lead agent, with no structured conflict resolution beyond "make judgment call based on evidence strength"

**Risk**: The proposal to dynamically increase team count based on "difficulty" could easily result in paying 5-8x token cost for marginal or zero quality improvement. Without measurement, this is faith-based engineering.

### 3. The Exploit/Explore Dichotomy Is Poorly Defined

The user's prompt proposes:
- **Exploit**: Many agents studying different parts of a single idea
- **Explore**: Searching for new ideas
- Mixed mode: both

But the current 4-role structure (Primary, Alternatives, Critic, Horizons) already attempts both. The roles aren't cleanly exploiting or exploring:
- "Primary" exploits a single approach
- "Alternatives" explores new approaches
- "Critic" meta-analyzes
- "Horizons" explores strategic directions

**Problem**: Adding `--exploit` / `--explore` flags on top of this creates a semantic conflict. Would `--exploit` suppress Alternatives and Horizons (reducing team size)? Would `--explore` suppress Primary? The task description doesn't address this, and the existing role structure doesn't cleanly decompose along this axis.

**Simpler alternative**: Instead of new flags, the focus prompt already controls direction. `--team "Focus deeply on approach X"` effectively becomes exploit mode. `--team "Survey different approaches to Y"` becomes explore mode. The natural language prompt is more flexible than rigid flags.

### 4. The Synthesis Bottleneck Is the Real Quality Problem

When 4 teammates each produce ~200 lines of findings, the lead must:
1. Read ~800 lines of teammate output
2. Detect conflicts
3. Resolve conflicts
4. Identify gaps
5. Write a unified 300+ line report

This all happens in a single agent's context window. The synthesis quality is constrained by:
- **Context pressure**: 800 lines of input + skill definition + system instructions
- **No structured conflict detection**: "Compare findings across teammates" is hand-waving. There's no schema for findings that enables automatic comparison.
- **No iterative refinement**: The lead writes the report once. No Wave 2 (documented as "not implemented in v1").

**Critical gap**: Adding more teammates (via dynamic sizing) makes synthesis harder, not easier. The proposal addresses the input side (more research angles) without addressing the output bottleneck (synthesis quality).

### 5. Domain-Specific Team Research Routing Is Missing

The current `skill-team-research` is domain-agnostic. It spawns general-purpose teammates with generic prompts (Primary, Alternatives, Critic, Horizons). For Lean 4 tasks:

- No teammate gets MCP lean-lsp tools in their prompt
- No teammate is told about the search decision tree (leansearch, loogle, leanfinder)
- No teammate knows about the zero-debt policy or sorry constraints
- The lean-research-agent's 226 lines of specialized knowledge are completely bypassed

The current team-research skill spawns teammates using the Agent tool with no `subagent_type`, meaning they're generic forks. They don't inherit the lean extension's agent definition. This means **team research on lean tasks is currently lower quality than single-agent research**, because the single agent gets the full lean-research-agent prompt while teammates get nothing.

### 6. Lean-Specific Tactic Quality Research Is Orthogonal

The user wants "lean research agents to look for tactics that might help improve proof quality." This is a research question about Lean tactics, not about the team research infrastructure. These are two different tasks being conflated:

- **Infrastructure task**: Improve how team research orchestrates multiple agents
- **Domain task**: Improve what the lean-research-agent actually searches for

Mixing them risks under-delivering on both. The lean tactic quality improvement should be a separate enhancement to `lean-research-agent.md` and the search flow, independent of team orchestration changes.

### 7. The Critic Role Has a Structural Problem

Currently (as evidenced by this very analysis), the Critic runs in parallel with the other teammates. This means the Critic can't actually critique the other teammates' findings - it can only critique the task description and general approach. To be useful, the Critic should either:

- Run in Wave 2 (after reading teammate A, B, D outputs)
- Or be given a different mandate entirely (like pre-mortem analysis)

The proposal doesn't address this. The user specifically says "A critic is generally very helpful" but the current architecture prevents the Critic from doing what critics actually do: evaluate other people's work.

### 8. Flag Proliferation Risk

Current research command flags: `--team`, `--team-size N`, `--fast`, `--hard`, `--haiku`, `--sonnet`, `--opus`, `--clean`

Proposed additions: `--exploit`, `--explore` (and possibly `--team-size` actually working)

That's 10+ flags on a single command. The argument parser is already 60+ lines of bash. Each new flag increases:
- Parser complexity and bug surface
- User cognitive load (which flags combine with which?)
- Documentation burden
- Test matrix size (flag combinations)

### 9. Auto-Routing to Team Research Is a Cost Bomb

The proposal includes: "Update research agents to auto-route to multi-angle team research when multiple handoffs indicate the same blocker."

This means a blocked task could automatically trigger 4x agent spawning without user consent. At 5x token cost per team invocation, this could be expensive. The "repeated blockers" heuristic is undefined:
- How many handoffs constitute "repeated"?
- What prevents a task from re-triggering team research every time it's re-run?
- Is there a circuit breaker?

---

## Recommended Approach

### Do First (High Value, Low Risk)

1. **Fix `team_size` dead code** - Make the parameter actually work
2. **Add domain context to team teammates** - When task_type is lean4, give teammates the lean-research-agent's MCP tools and search decision tree
3. **Move Critic to Wave 2** - Let the Critic actually read other teammates' outputs before critiquing

### Do Carefully (Medium Value, Higher Risk)

4. **Lean tactic quality improvements** - Enhance lean-research-agent to search for useful tactics, but as a separate task from team infrastructure
5. **Structured findings format** - Define a schema for teammate outputs that enables automatic conflict detection during synthesis

### Defer or Avoid

6. **`--exploit`/`--explore` flags** - The focus prompt already provides this flexibility. More flags add complexity without clear benefit.
7. **Dynamic team sizing** - Without measurement of team research quality, we can't know if more agents help. Add measurement first, then optimize.
8. **Auto-routing to team research** - Needs cost controls and circuit breakers before deployment. The risk of runaway spending is real.

---

## Evidence/Examples

### Dead Code Evidence

```
# SKILL.md line 54:
| `team_size` | integer | No | Number of teammates (2-4, default 2) |

# SKILL.md line 74:
team_size=4  # Hardcoded, ignores input
```

### Missing Domain Context Evidence

The teammate prompts in SKILL.md (lines 204-298) contain zero lean-specific content. Compare to `lean-research-agent.md` which has:
- 15 MCP tool definitions with usage guidance
- A search decision tree (6 branches)
- Zero-debt policy compliance rules
- Rate limit handling
- Error recovery patterns

None of this reaches the team teammates.

### Synthesis Bottleneck Evidence

SKILL.md Stage 8 (Synthesize Findings) is 12 lines of pseudo-description:
- "Extract key findings from each teammate"
- "Detect conflicts between findings"
- "Resolve conflicts with evidence-based judgment"

There is no specification of how conflict detection works, what constitutes evidence, or how to weight disagreements. The lead agent is left to improvise.

---

## Questions That Should Be Asked

1. Has team research ever produced a meaningfully better outcome than single-agent research on a specific task? Can we identify one?
2. What percentage of team research time is spent on synthesis vs. parallel research? Is the bottleneck where we think it is?
3. Would a simpler model (single agent + self-critique loop) achieve similar quality at lower cost?
4. Should the Critic be a post-hoc reviewer rather than a parallel teammate?
5. Is the real problem with lean research quality about team orchestration, or about the lean-research-agent's search strategy being too narrow?

---

## Confidence Level

**High** - The structural issues identified (dead code, missing domain context, synthesis bottleneck, Critic timing) are observable in the codebase. The risk assessments (flag proliferation, cost bomb) follow from the architecture. The main uncertainty is whether team research provides value at all, which is precisely the measurement gap identified.
