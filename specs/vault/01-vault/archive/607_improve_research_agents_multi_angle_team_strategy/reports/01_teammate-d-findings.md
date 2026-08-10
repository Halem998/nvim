# Teammate D: Horizons — Strategic Analysis

**Task**: 607 - Improve research agents with multi-angle team research strategy
**Date**: 2026-05-22
**Role**: Horizons (long-term alignment and strategic direction)

---

## Key Findings

### 1. Roadmap Alignment Is Strong But Indirect

The current roadmap (specs/ROADMAP.md) focuses on documentation infrastructure and agent system quality. Task 607 doesn't directly advance any open roadmap items, but it does advance the *implicit* priority of making the agent system more effective at its core job: producing high-quality research, plans, and implementations.

The roadmap's "Agent System Quality" section currently covers linting and validation of static artifacts (frontmatter, READMEs). Task 607 addresses a deeper quality dimension: the *runtime behavior* of agents under complex conditions. This is a natural next phase — after ensuring agents are correctly structured, ensure they produce excellent results.

**Recommendation**: Add a "Phase 3: Agent Runtime Quality" section to ROADMAP.md capturing the exploit/explore framework, dynamic sizing, and critic-as-standard-practice. This legitimizes the work as a roadmap item rather than a one-off enhancement.

### 2. The Exploit/Explore Framework Is a Cross-Cutting Innovation

The user's insight about exploit (deep-dive on a fixed idea) vs. explore (search for new ideas) maps directly to a well-studied tradeoff in multi-agent systems research. Recent work (arxiv 2505.09901, 2603.28959) shows that:

- **Single-agent approaches suffer from cognitive overload** when jointly managing exploration and exploitation. Splitting into multiple agents with distinct mandates performs better.
- **A strategy agent should control the explore/exploit balance**, while generation agents execute under that policy. This maps naturally to the lead/teammate model.
- **Partial deviation from group norms boosts exploration** — having one "maverick" teammate that deliberately diverges improves system-level performance (arxiv 2502.16565).

This framework shouldn't be confined to team research. It could inform:
- **team-plan**: Exploit = refine a known good approach; Explore = generate radically different architectures
- **team-implement**: Exploit = parallelize known phases; Explore = try alternative implementations of tricky phases
- **/orchestrate**: When a task keeps hitting the same blocker, auto-escalate from exploit to explore mode

### 3. The Critic Role Is Validated by Strong Research Evidence

Recent multi-agent critique research shows:

- **Multi-agent critique and revision yields substantial improvements** beyond naive ensembles or self-refinement (EmergentMind, multiple 2025-2026 papers)
- **Structured critique schemas** (ISSUE, CLAIM, SUPPORT, REBUT, QUESTION) outperform free-form criticism (arxiv 2604.19049)
- **MACI controllers** using dials over evidence quality and contentiousness reduce calibration error by 20-30% (arxiv 2603.28813)

The current critic teammate runs in parallel with others, which means it critiques the *task* rather than the *findings*. Running the critic in a Wave 2 — after reading Teammates A and B — would allow it to critique actual outputs, dramatically increasing its value.

### 4. Dynamic Sizing Should Follow Capability-Based Selection

The user wants "the right number of agents." Fixed sizing (always 2, always 4) is suboptimal. Research on adaptive coordination (Nature Scientific Reports 2025, arxiv 2508.12683) shows the best pattern is:

- **Capability registry**: Each potential teammate role has a relevance score for the current task
- **Threshold-based activation**: Only spawn teammates whose relevance exceeds a threshold
- **Budget awareness**: More agents = more tokens. Let the user set a budget constraint

For this system, a practical approach: instead of a `--team-size N` flag, use **task complexity signals** to determine team size:

| Signal | Interpretation | Team Size |
|--------|---------------|-----------|
| Simple task, no prior research | Quick survey | 2 (Primary + Critic) |
| Complex task, no prior research | Broad exploration | 4 (full team) |
| Blocked task, specific blocker | Deep exploit | 3 (2 Exploit angles + Critic) |
| Repeated blockers on same issue | Radical exploration | 4 (3 Explore angles + Critic) |

### 5. Domain-Specialized Teammates Are the Next Frontier

The lean extension already has rich MCP tooling (lean_leansearch, lean_loogle, lean_state_search, lean_hammer_premise, lean_multi_attempt). Currently, team research uses generic teammate roles (Primary, Alternatives, Critic, Horizons) regardless of domain.

For formal/lean tasks, domain-specialized teammates would be far more effective:

| Specialized Role | Focus | Key Tools |
|-----------------|-------|-----------|
| **Tactic Hunter** | Search for tactics that close specific goals | lean_state_search, lean_hammer_premise, lean_multi_attempt |
| **Library Scout** | Find relevant Mathlib lemmas and patterns | lean_leansearch, lean_loogle, lean_leanfinder |
| **Structure Analyst** | Analyze proof architecture, suggest decomposition | lean_goal, lean_hover_info, lean_local_search |
| **Verification Agent** | Compile-test every proposed approach before reporting | lean_multi_attempt, lake build |

This aligns with the VulnSage pattern from security research: decompose a complex task into specialist sub-agents, each with expertise in one aspect.

---

## Recommended Approach

### Short-Term (Task 607 Scope)

1. **Add `--exploit` and `--explore` flags** to `/research --team`:
   - `--exploit`: Spawn multiple teammates all investigating different facets of a *specified* approach. Critic evaluates depth and rigor.
   - `--explore`: Spawn teammates with maximally diverse search strategies. Critic evaluates coverage and novelty.
   - Default (neither flag): Current balanced behavior (Primary + Alternatives + Critic + Horizons)

2. **Make the Critic a Wave 2 agent**: After Teammates A/B/D complete, spawn Critic with access to their findings. This transforms the critic from "skeptical independent researcher" to "informed adversarial reviewer," which research shows is far more effective.

3. **Add dynamic sizing heuristics**: Parse task description and history to suggest team size, but let the user override with `--team-size N`.

### Medium-Term (Subsequent Tasks)

4. **Create domain-specific teammate role templates** in extension manifests. The lean extension would define `lean-tactic-hunter`, `lean-library-scout`, etc. The team research skill would query the extension manifest for available specialized roles and use them instead of generic roles when the task type matches.

5. **Unify team mode configuration**: Create a `.claude/context/team-profiles/` directory with named profiles:
   ```
   default.json     # Primary + Alternatives + Critic + Horizons
   exploit.json     # Deep-dive-A + Deep-dive-B + Verification + Critic
   explore.json     # Broad-A + Broad-B + Maverick + Critic
   lean-proof.json  # Tactic Hunter + Library Scout + Structure Analyst + Critic
   ```
   Invoked as `--team-profile lean-proof` or auto-selected by task type.

6. **Propagate exploit/explore to team-plan and team-implement**: The same framework applies. Exploit-plan = refine one approach in detail; Explore-plan = generate 3 radically different architectures and synthesize.

### Long-Term (6+ Months)

7. **Auto-detect exploit vs. explore**: When `/orchestrate` encounters repeated blockers on the same issue (detectable from errors.json), it should auto-escalate: first retry with exploit (focused deep-dive), then if still blocked, switch to explore (broad search for alternatives). This removes the need for manual flag selection in autonomous mode.

8. **Structured decision matrices**: Instead of prose synthesis reports, team research could produce a structured comparison matrix: approaches as rows, evaluation criteria as columns, with scores and evidence. This feeds directly into planning as a quantified trade-off analysis.

9. **Memory-augmented team composition**: Query the memory vault before spawning teammates to inject relevant past findings. Currently memory retrieval happens at the skill level; it should flow into individual teammate prompts so each teammate can build on prior knowledge rather than starting fresh.

---

## Evidence/Examples

### Exploit/Explore in Practice

Consider a Lean proof task where `simp` isn't closing a goal:

- **Exploit mode** (3 teammates + critic):
  - Teammate A: Try `simp` with different lemma sets (`simp only [...]`, `simp [extra_lemma]`)
  - Teammate B: Try related tactics (`norm_num`, `ring`, `omega`, `decide`)
  - Teammate C: Decompose the goal and try `simp` on sub-goals
  - Critic: Reviews all attempts, identifies which came closest and why

- **Explore mode** (3 teammates + critic):
  - Teammate A: Search Mathlib for existing proofs of similar statements
  - Teammate B: Try a completely different proof strategy (induction, contraposition, etc.)
  - Teammate C: Question whether the theorem statement itself needs reformulation
  - Critic: Evaluates novelty and coverage across all approaches

### Wave 2 Critic Advantage

Current (Wave 1 parallel):
```
Wave 1: [A: Primary] [B: Alternatives] [C: Critic] [D: Horizons]
         ↓            ↓                 ↓            ↓
         findings     findings          (generic      findings
                                        skepticism)
```

Proposed (Wave 1 + Wave 2):
```
Wave 1: [A: Primary] [B: Alternatives] [D: Horizons]
         ↓            ↓                 ↓
         findings     findings          findings
                      ↓
Wave 2: [C: Critic — reads A+B+D findings]
         ↓
         targeted critique of specific claims,
         identifies contradictions, gaps in evidence,
         challenges strongest-looking conclusion
```

### Cross-System Applicability

The team-profiles pattern (medium-term recommendation) generalizes across extensions:

| Extension | Exploit Profile | Explore Profile |
|-----------|----------------|-----------------|
| lean | tactic-hunter + verification-agent | library-scout + structure-analyst |
| python | debugging-specialist + profiler | alternative-library-scout + architecture-reviewer |
| nix | option-validator + module-tester | package-searcher + pattern-researcher |
| web | component-debugger + a11y-checker | framework-scout + ux-researcher |

---

## Confidence Level

- **Exploit/Explore framework**: **High** — well-validated in multi-agent research literature, maps cleanly to existing system architecture
- **Wave 2 Critic**: **High** — research evidence strongly supports informed critique over parallel independent critique
- **Dynamic sizing heuristics**: **Medium** — the signals are real but tuning thresholds will require iteration
- **Domain-specialized teammates**: **Medium** — architecturally sound but significant implementation effort; should be a separate task
- **Auto-detection in /orchestrate**: **Low-Medium** — desirable but complex; requires robust blocker pattern detection from errors.json history

---

## Strategic Summary

Task 607 is positioned at a critical leverage point: the team research system is the foundation for all parallel agent work, and improvements here cascade through team-plan, team-implement, and /orchestrate. The exploit/explore framework is the single highest-value addition because it addresses the fundamental question users face: "should I go deeper or go wider?" Making that choice explicit (via flags) and eventually automatic (via blocker detection) would significantly improve the system's ability to handle diverse task complexities.

The critic-in-Wave-2 change is the lowest-effort, highest-impact improvement and should be prioritized within this task's scope.
