# Research Report: Task #607

**Task**: Improve research agents with multi-angle team research strategy
**Date**: 2026-05-22
**Mode**: Team Research (4 teammates)
**Session**: sess_1748000000_607abc

## Summary

Team research uncovered strong consensus on three high-value improvements (domain-aware teammates, Wave 2 critic, exploit/explore modes) along with critical structural issues in the current system (dead `team_size` parameter, synthesis bottleneck, missing domain context). The literature strongly validates the exploit/explore framework and permanent critic role but warns against pure multi-agent debate. The critic's finding that team research currently bypasses domain expertise -- making it *worse* than single-agent for domain tasks -- is the most urgent fix.

## Key Findings

### Primary Approach (Teammate A)

**Domain-aware team research** is the single biggest gap. When `--team` routes to `skill-team-research`, domain extensions are bypassed entirely -- lean tasks lose MCP tools, search decision trees, and zero-debt policy. The fix: inject domain context and tools into teammate prompts based on `task_type`.

**Exploit/Explore/Mixed modes** map to well-studied exploration-exploitation tradeoffs in multi-agent systems. Literature shows single-agent approaches suffer cognitive overload when managing both; splitting into specialized agents performs better.

**Dynamic team sizing** should default to 3 (Primary + Alternatives + Critic), with effort flags controlling range: `--fast` = 2, `--hard` = 4. The critic is always present per user request.

Concrete 6-phase implementation plan provided with specific file paths.

**Confidence**: High (architecture), Medium (specific heuristics)

### Alternative Approaches (Teammate B)

**CrewAI's three process types** (Sequential, Hierarchical, Consensual) map directly to the proposed modes: default single-agent (sequential), exploit (hierarchical manager coordinates deep-dives), explore (consensual parallel search).

**MAD debate warning** (ICLR 2025): Pure multi-agent debate *fails to outperform* single-agent Chain-of-Thought. However, heterogeneous role-based collaboration with confidence gating works. The current A/B/C/D role separation is the right approach.

**APOLLO decomposition** (NeurIPS 2025): For Lean proofs, decompose into sub-goals with `sorry`, solve each with controlled sampling budget. Directly maps to exploit mode.

**LeanHammer portfolio**: Pipeline of aesop -> lean-auto -> zipperposition -> duper with configurable premise budgets. Research agents should survey and recommend specific tactics from this pipeline.

**Confidence**: High (three-mode architecture, Lean tactics), Medium-Low (confidence gating)

### Gaps and Shortcomings (Critic)

**`team_size` is dead code**: Parameter declared as 2-4 with default 2, but hardcoded to 4 on line 74 of SKILL.md. The `--team-size` flag is a no-op. Must fix before building dynamic sizing.

**No evidence more agents = better**: Zero measurement infrastructure. No A/B comparison, no quality scoring, no tracking of whether teammate findings influence final recommendations. Dynamic sizing without measurement is "faith-based engineering."

**Exploit/explore flags may be over-engineering**: The focus prompt already controls direction. `--team "Focus deeply on X"` is effectively exploit mode. More flags = more parser complexity, user cognitive load, and test surface.

**Synthesis is the real bottleneck**: Adding more teammates makes synthesis harder, not easier. The current synthesis spec is 12 lines of hand-waving with no structured conflict detection schema.

**Critic role is structurally broken**: Running in parallel, it can't actually critique other teammates' findings -- only the task description. Must move to Wave 2.

**Two tasks conflated**: Lean tactic quality improvements are orthogonal to team infrastructure changes.

**Confidence**: High

### Strategic Horizons (Teammate D)

**Roadmap alignment is indirect but strong**: Task 607 advances "agent runtime quality" -- a natural next phase after the current roadmap focus on static quality (linting, validation). Recommend adding "Phase 3: Agent Runtime Quality" to ROADMAP.md.

**Exploit/explore is cross-cutting**: Should propagate beyond team-research to team-plan, team-implement, and /orchestrate. Not just a team-research feature.

**Domain-specialized teammate roles**: For lean tasks, specialized roles (Tactic Hunter, Library Scout, Structure Analyst, Verification Agent) would outperform generic Primary/Alternatives roles. Enabled via extension manifest profiles.

**Team profiles**: Named configurations in `.claude/context/team-profiles/` (default.json, exploit.json, explore.json, lean-proof.json) auto-selected by task type.

**Wave 2 critic is the lowest-effort, highest-impact change** and should be prioritized.

**Confidence**: High (exploit/explore, Wave 2 critic), Medium (domain teammates, auto-detection)

## Synthesis

### Conflicts Resolved

**1. Exploit/Explore flags vs focus prompt flexibility**
- **Conflict**: Critic argues flags are over-engineering; A, B, D support explicit flags
- **Resolution**: Both are valid. Implement flags as *optional* mode hints that shape teammate prompts, but the focus prompt remains the primary directional input. When neither flag is given, the system uses the focus prompt to infer direction. This gives power users explicit control without requiring flags.
- **Rationale**: Flags provide discoverability and documentation; the focus prompt provides flexibility. They're complementary, not competing.

**2. Dynamic sizing: measure first or build first?**
- **Conflict**: Critic wants measurement before optimization; others propose heuristics now
- **Resolution**: Fix the `team_size` dead code first (making the parameter actually work), then implement conservative defaults (3 by default, 2 with `--fast`, 4 with `--hard`). Defer complexity-based auto-sizing until measurement exists. This satisfies both positions: the infrastructure works, but we don't over-optimize without data.

**3. Separate lean tactic task vs combined**
- **Conflict**: Critic argues lean tactic quality should be a separate task
- **Resolution**: Agree. The plan should separate infrastructure changes (team orchestration improvements) from domain changes (lean-research-agent tactic discovery enhancements). Both are in scope for this task's *research*, but implementation should be phased: infrastructure first, lean tactic enhancements as a follow-up task or later phase.

### Gaps Identified

1. **Measurement infrastructure**: No way to compare team vs single-agent research quality. Should be addressed but doesn't block the architectural improvements.
2. **Structured findings format**: No schema for teammate outputs enabling automatic conflict detection. Would significantly improve synthesis quality.
3. **Cost controls for auto-routing**: Auto-escalation to team research needs circuit breakers (max escalations per task, user confirmation threshold). Not addressed in any teammate's concrete recommendations.
4. **Memory integration**: How should team research interact with the memory vault? Should teammate prompts include relevant memories? Currently memory retrieval happens at the skill level but doesn't flow to individual teammates.

### Recommendations

#### Tier 1: Do Now (High Value, Low Risk)
1. **Fix `team_size` dead code** -- make the parameter actually functional
2. **Move Critic to Wave 2** -- let it read A/B/D findings before critiquing
3. **Add domain context injection** -- when task_type has an extension, inject domain agent context and MCP tools into teammate prompts

#### Tier 2: Do Carefully (Medium Value, Moderate Risk)
4. **Add `--exploit` and `--explore` flags** -- optional mode hints that shape teammate role assignment
5. **Dynamic sizing via effort flags** -- `--fast` = 2, default = 3, `--hard` = 4, with `--team-size N` override
6. **Enhance lean-research-agent** -- add tactic discovery survey protocol (LeanHammer pipeline, APOLLO decomposition)
7. **Prototype-first pattern** -- add guidance for agents to describe minimal prototypes before committing to approaches

#### Tier 3: Defer (High Value, Higher Risk, Needs More Data)
8. **Domain-specialized teammate roles** via extension manifest profiles
9. **Team profiles** for named configurations (default, exploit, explore, lean-proof)
10. **Auto-routing** with cost controls and circuit breakers
11. **Structured decision matrices** replacing prose synthesis
12. **Measurement infrastructure** for team vs single-agent quality comparison

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary | completed | high | 6-phase implementation plan, domain-aware architecture |
| B | Alternatives | completed | high | CrewAI mapping, MAD warning, APOLLO/LeanHammer patterns |
| C | Critic | completed | high | Dead code bug, synthesis bottleneck, measurement gap |
| D | Horizons | completed | high | Cross-cutting framework, Wave 2 critic, team profiles |

## References

- AORCHESTRA: Multi-agent orchestration model (+16.28% improvement), Feb 2026
- Captain Agent: Adaptive team building for dynamic agent scaling
- CrewAI Process Types: Sequential, Hierarchical, Consensual workflows
- ICLR 2025: MAD frameworks fail to outperform single-agent strategies
- DebateCoder: Adaptive Confidence Gating (70.12% Pass@1 on HumanEval)
- APOLLO (NeurIPS 2025): Recursive decomposition for Lean proof generation (84.9% on miniF2F)
- LeanHammer: Portfolio-based automated proof search for Lean 4
- ProofAug: Portfolio prompting with diverse proof templates
- Google/MIT: "Towards a Science of Scaling Agent Systems" (2025)
- Multi-Agent Critique and Revision: EmergentMind 2025-2026 survey
- MACI Controllers: Evidence quality dials reducing calibration error 20-30%
- Exploration-Exploitation in Multi-Agent Systems (arxiv 2505.09901, 2502.16565)
