# Teammate B Findings: Alternative Approaches and Prior Art

**Task**: 607 - Improve research agents with multi-angle team research strategy
**Angle**: Alternative patterns, prior art, and formal methods parallelization
**Date**: 2026-05-22

## Key Findings

### 1. Multi-Agent Framework Landscape (Prior Art)

Three dominant architectures have emerged in the multi-agent AI space, each mapping to a distinct collaboration pattern:

| Framework | Architecture | Key Pattern | Relevance |
|-----------|-------------|-------------|-----------|
| **CrewAI** | Role-based with 3 process types | Sequential, Hierarchical, Consensual | Closest to current system; consensual = critic pattern |
| **AutoGen** | Conversational group chat | Debate and group decision-making | Best for deliberation scenarios |
| **LangGraph** | State machine with reducer logic | Branching, persistence, human-in-loop | Best for complex state control |

**CrewAI's Three Process Types** are particularly instructive:
- **Sequential**: Linear pipeline (current default single-agent mode). Lowest cost, easiest to debug.
- **Hierarchical**: Manager agent dispatches to specialists dynamically. 30-50% overhead but better task routing. Maps well to the proposed `--exploit` mode where a manager coordinates deep dives into a fixed idea.
- **Consensual**: All agents collaborate on decisions, iteratively refining. Highest cost, best for multi-perspective synthesis. Maps to `--explore` mode and the critic pattern.

**Recommendation**: The current wave-based model is essentially a simplified hierarchical process. The three process types from CrewAI directly map to the user's desired modes: sequential (default), hierarchical (exploit/deep-dive), consensual (explore/debate).

### 2. Multi-Agent Debate (MAD): Cautionary Findings

ICLR 2025 research reveals an important warning: **current MAD frameworks fail to consistently outperform simple single-agent strategies**. Key findings:

- Most MAD methods underperform Chain-of-Thought and Self-Consistency on standard benchmarks
- Increasing debate rounds and agent counts does **not** reliably improve accuracy
- Methods are "overly aggressive" -- frequently converting correct answers to incorrect ones
- **Exception**: Multi-model combinations (pairing different model strengths) showed promise (88.2% vs 84.2% on MMLU)

**However**, the **DebateCoder** framework (2025) achieved positive results for code generation specifically:
- User, Technical, and QA agents with Adaptive Confidence Gating (95% threshold)
- 70.12% Pass@1 on HumanEval, surpassing MapCoder
- 35% reduction in API overhead vs prior approaches

**Takeaway**: Pure debate between homogeneous agents is wasteful. But heterogeneous role-based collaboration with confidence gating works. The current Teammate A/B/C/D role separation is the right approach; the wrong approach would be multiple agents debating the same question.

### 3. Formal Methods Parallelization Patterns

#### LeanHammer: Portfolio-Based Proof Search

LeanHammer provides the most directly relevant architectural pattern for the Lean research agents. It combines multiple proof strategies in a pipeline:

1. **Preprocessing**: Optional Aesop or simp
2. **Tactic Portfolio**: Aesop with selected premises → Lean-auto → Zipperposition → Duper
3. **Premise Selection**: Cloud-based and MePo algorithm
4. **Output**: Generates human-readable tactic scripts (transferable proofs)

Key design decisions:
- Tactics run **sequentially** (not parallel) with configurable disable flags
- Each tactic has separate premise budgets (`aesopPremises`, `autoPremises`)
- Users control which approaches activate via options

#### APOLLO: Recursive Decomposition for Proof Generation

APOLLO (NeurIPS 2025) is the strongest prior art for how AI agents should handle formal proofs:

1. **Syntax Refiner**: Corrects superficial errors (regex-based)
2. **Sorrifier**: Parses failed proof into tree, inserts `sorry` at failure points
3. **Auto Solver**: Applies `nlinarith`, `ring`, `simp` combinations automatically
4. **Recursive Reasoning**: Re-invokes LLM on remaining goals with controlled sampling budget (@32 candidates per goal)
5. **Proof Assembler**: Recombines and reverifies

Key insight: APOLLO achieves 84.9% on miniF2F with sub-8B models by **decomposing and conquering** rather than generating complete proofs. This maps directly to the user's desire for agents to "focus in with many agents studying different parts of a single idea."

#### Portfolio Prompting (ProofAug)

ProofAug (Jan 2025) uses diverse prompt templates: few-shot, zero-shot, legacy, and proof sketches. This is essentially the explore pattern -- multiple angles on the same problem.

### 4. Explore/Exploit Framework

Research on exploration-exploitation in multi-agent systems yields several applicable insights:

**Probing Strategy**: "Pairing known-good agents with unknowns is only optimal when high-skill agents are scarce." This suggests:
- In exploit mode: pair the critic with one deep-dive agent (known-good + focused)
- In explore mode: all agents take independent angles (maximize coverage)

**Self-Motivated Multi-Agent Exploration (SMMAE)**: Agents adaptively balance self-exploration vs team cooperation. Translates to: agents should be able to request more teammates or deeper exploration when they detect their angle is insufficient.

**Dynamic Architecture Adaptation**: Research advocates "dynamically routed architectures that adapt their collaborative structures to real-time task complexity." This supports the user's desire for variable team sizes.

### 5. Dynamic Team Sizing Approaches

| Approach | How It Works | Viability |
|----------|-------------|-----------|
| **Complexity heuristic** | Score task by description length, dependency count, prior failure count | Medium -- simple but crude |
| **Adaptive expansion** | Start with 2, spawn more if early results show gaps | High -- matches SMMAE research |
| **Budget-based** | User sets token budget, system calculates max agents | Medium -- requires cost estimation |
| **History-based** | Similar past tasks (by topic/type) determine team size | Low -- requires significant history data |
| **Blocker-based** | Count prior research/plan attempts on same task; more failures = more agents | High -- already partially implemented in task description |

**Recommended approach**: Combine blocker-based (automatic escalation) with explicit flags (user control). Default to 2 agents, auto-escalate to 3-4 if prior attempts exist on the same task, allow `--team-size N` override.

## Recommended Approach

### Alternative Architecture: Hybrid Mode Selection

Rather than the current fixed 4-teammate wave, implement three selectable modes that map to the user's explore/exploit language:

#### Mode 1: `--exploit` (Deep Dive)
- **Architecture**: Hierarchical (CrewAI-style)
- **Team**: 2-3 agents subdividing a fixed approach + 1 critic
- **Use case**: "Focus in with many agents studying different parts of a single idea"
- **Pattern**: APOLLO-style decomposition -- break the idea into sub-problems, assign each to an agent

#### Mode 2: `--explore` (Wide Search)
- **Architecture**: Consensual/parallel (portfolio approach)
- **Team**: 2-4 agents each trying independent angles + 1 critic
- **Use case**: "Search for new ideas"
- **Pattern**: ProofAug-style portfolio -- diverse approaches to same problem

#### Mode 3: `--team` (Balanced, current default)
- **Architecture**: Wave-based (current model, refined)
- **Team**: Primary + Alternatives + Critic + Horizons
- **Use case**: Default when no specific strategy indicated

### Lean-Specific Tactic Guidance

Research agents should be instructed to look for and recommend specific tactics during research:
- **Automation tactics**: `aesop`, `omega`, `simp`, `decide`, `norm_num`, `ring`, `linarith`, `nlinarith`, `positivity`
- **Search tactics**: `exact?`, `apply?`, `rw?` (interactive search)
- **Pipeline tools**: LeanHammer (`hammer`), Lean-auto
- **Decomposition**: `have` steps with `sorry` for incremental proof, `calc` blocks for chains
- **Proof quality indicators**: absence of `sorry`, minimal `simp` lemma sets, use of named lemmas over anonymous proofs

### Confidence Gating (from DebateCoder)

Add a confidence threshold mechanism to the synthesis stage:
- If all teammates agree (high confidence): accept without further debate
- If teammates conflict but one has strong evidence: weight toward evidence
- If no clear winner: flag for human review or trigger Wave 2

## Evidence/Examples

### CrewAI Process Selection Guidance
> "Start with sequential. Move to hierarchical when you need dynamic task routing. Use consensual only when multi-perspective synthesis genuinely improves your output."

### MAD Performance Warning
> "Current MAD frameworks fail to consistently outperform simple single-agent test-time computation strategies... increasing test-time computation does not always improve accuracy."

### APOLLO Decomposition Success
> APOLLO achieves 84.9% accuracy on miniF2F among sub-8B models while keeping sampling budget below 100, by decomposing into sub-goals and solving each with controlled budgets.

### Dynamic Architecture Research
> "The optimal multi-agent coordination framework for autonomous agents remains largely unexplored. Dynamically routed architectures that adapt their collaborative structures to real-time task complexity" are advocated.

## Confidence Level

**High** for the three-mode architecture (explore/exploit/balanced) -- well-supported by both prior art and the user's stated needs.

**Medium** for dynamic team sizing -- the blocker-based escalation is sound but the complexity heuristic needs empirical tuning.

**High** for Lean tactic guidance additions -- LeanHammer and APOLLO provide clear, proven patterns.

**Medium-Low** for confidence gating -- DebateCoder shows promise but MAD research suggests caution about over-engineering agent interaction.

## Sources

- [ICLR 2025: Multi-LLM-Agents Debate Performance](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/)
- [APOLLO: Automated LLM and Lean Collaboration](https://arxiv.org/html/2505.05758v5)
- [LeanHammer GitHub](https://github.com/JOSHCLUNE/LeanHammer)
- [CrewAI Process Types: Sequential, Hierarchical, Consensual](https://callsphere.ai/blog/crewai-process-types-sequential-hierarchical-consensual-workflows)
- [DebateCoder: Adaptive Confidence Gating](https://arxiv.org/pdf/2601.21469)
- [Explore-Exploit Tradeoff in Multi-Agent Systems](https://dev.to/drcarlosruizviquez/taming-the-exploration-exploitation-tradeoff-in-multi-agen-5h0h)
- [Multi-Agent Frameworks Compared 2026](https://pecollective.com/blog/ai-agent-frameworks-compared/)
- [Aesop: White-Box Best-First Proof Search for Lean](https://github.com/leanprover-community/aesop)
- [Lean-auto: Interface Between Lean 4 and ATPs](https://arxiv.org/html/2505.14929v1)
- [Empirical Study of Multi-Agent Collaboration for Automated Research](https://arxiv.org/pdf/2603.29632)
