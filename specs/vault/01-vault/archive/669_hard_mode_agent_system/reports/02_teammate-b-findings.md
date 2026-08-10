# Teammate B Findings: Alternative Approaches and Prior Art

**Task**: 669 - hard_mode_agent_system
**Angle**: Alternative patterns, prior art, and architectural alternatives
**Date**: 2026-06-12
**Confidence**: High (codebase analysis), Medium (web patterns), Medium (auto-escalation)

## Key Findings

### 1. The Duplication Problem is Real and Measurable

The existing --team precedent demonstrates the cost of "full variant" skills:

| Skill Pair | Base Lines | Team Lines | Shared Structure |
|------------|-----------|------------|------------------|
| skill-researcher / skill-team-research | 465 | 633 | ~60% (preflight, postflight, cleanup, metadata, git) |
| skill-planner / skill-team-plan | 506 | 616 | ~55% (preflight, postflight, status update, artifact linking) |
| skill-implementer / skill-team-implement | 638 | 695 | ~50% (preflight, postflight, git, status) |

The stage structure is *completely different* between base and team variants (e.g., researcher has 10 stages vs team-research has 14 stages with different names). They share boilerplate (preflight status update, postflight patterns, git commit, cleanup) but diverge entirely in the core execution flow.

**If hard-mode follows this pattern**, it would create:
- Core: skill-researcher-hard, skill-planner-hard, skill-implementer-hard, skill-orchestrate-hard (4 skills)
- Per-extension: skill-lean-implementation-hard, skill-lean-research-hard, skill-nix-implementation-hard, skill-nix-research-hard, skill-neovim-implementation-hard, skill-neovim-research-hard (~6+ skills)
- Agents: lean-implementation-hard-agent, planner-hard-agent, etc. (~4-10 agents)
- **Total: ~14-20 new files, ~7,000-12,000 new lines**

Every time the base skill changes (new postflight pattern, new metadata field, new stage), ALL variants must be updated. The team skills already demonstrate this maintenance burden exists.

### 2. Progressive Complexity Escalation is a Recognized Pattern

The ["Progressive Complexity Escalation" pattern](https://agentic-patterns.com/patterns/progressive-complexity-escalation/) (from Awesome Agentic Patterns, 2026) identifies three capability tiers with promotion gates. Key insight: **the escalation trigger can be automatic (metrics-based) rather than manual (flag-based)**. This aligns with the auto-escalation idea: track churn counters and escalate when thresholds are crossed.

However, the pattern notes a critical trade-off: "added tier management complexity" and "maintenance overhead for multiple pathways." This validates the concern about file proliferation.

### 3. Middleware/Decorator Approach (Template Composition)

**Concept**: Instead of separate skill files, hard-mode is implemented as a **prompt contract injection** layer that transforms the standard skill's agent prompt before delegation.

```
/implement 273 --hard
  └─ skill-orchestrator reads EFFORT_FLAG="hard"
       └─ skill-implementer (same file as normal)
            └─ Stage 4.5: Load Hard-Mode Contracts
                 └─ Read .claude/context/contracts/anti-analysis.md
                 └─ Read .claude/context/contracts/prior-art-grounding.md
                 └─ Read .claude/context/contracts/territory.md
                 └─ Inject into agent prompt as ## Hard-Mode Rules section
            └─ general-implementation-agent (same agent, enriched prompt)
```

**Advantages**:
- Zero new skill files for core workflows
- Zero new agent files for workers
- Contracts are composable and testable independently
- Single maintenance point for each contract (H2, H3, H7, H9)
- Graceful: if no contract file exists, skill runs normally

**Disadvantages**:
- Doesn't address per-phase dispatch (H1) — that requires a different orchestration loop
- Hard to enforce structural differences (e.g., hard plans need different phase format)
- The orchestrate skill IS structurally different in hard mode (per-phase loop vs whole-plan dispatch)

**Verdict**: Works for research and implementation agents (H2, H3, H7, H9 are prompt-level changes), but NOT for orchestration (H1, H5, H6 are loop-level changes). This suggests a **hybrid approach**.

### 4. Profile-Based Approach

**Concept**: Task profiles stored in state.json that compose behaviors:

```json
{
  "project_number": 273,
  "task_profile": "hard",
  "hard_mode_config": {
    "per_phase_dispatch": true,
    "anti_analysis_contract": true,
    "prior_art_grounding": true,
    "adversarial_verification": true,
    "churn_detection": true,
    "max_defect_claims": 3,
    "territory_contracts": true
  }
}
```

**Advantages**:
- Persistent across sessions (task stays in hard mode once set)
- Configurable per-technique (user could enable H1 without H3)
- Auto-escalation can set the profile without user intervention
- Could be combined with --hard flag (flag sets the profile)

**Disadvantages**:
- Schema complexity in state.json
- Over-engineering for the initial implementation
- Skill still needs conditional logic to read and act on profile

**Verdict**: Good long-term architecture, premature for v1. But the schema extension (adding `effort_mode` or `task_profile` to state.json) is cheap and future-proofs.

### 5. Hybrid Architecture: Contracts + Orchestrator Variant

The highest-feasibility approach combines insights from all alternatives:

**Layer 1 — Prompt Contracts (for workers)**:
- `.claude/context/contracts/hard-anti-analysis.md` (H2 block)
- `.claude/context/contracts/hard-prior-art.md` (H3 block)
- `.claude/context/contracts/hard-territory.md` (H7 block)
- `.claude/context/contracts/hard-wrapup.md` (H9 block)
- Skills load these when `effort_flag == "hard"` and inject into the agent prompt
- **Zero new skill files or agent files needed for workers**

**Layer 2 — Orchestrator Variant (for the loop)**:
- `skill-orchestrate-hard` — the ONLY new skill file (or a hard-mode branch within skill-orchestrate)
- Encodes H1 (per-phase dispatch), H5 (divergence audit), H6 (convergence policing)
- This is where the structural difference lives; it can't be a prompt injection

**Layer 3 — Plan Format Enforcement (for the planner)**:
- `.claude/context/contracts/hard-plan-format.md` (H8 requirements)
- Loaded by planner-agent when effort_flag is "hard"
- Extends plan-format-enforcement.md rule, NOT a new skill

**Layer 4 — Schema Extension**:
- Add `effort_mode: "hard"` to state.json task entry (set by --hard flag, persists across sessions)
- Existing churn counters in loop guard extend naturally for auto-escalation

**File count**: ~5 new contract files + 1 new skill (or 0 if branching within skill-orchestrate) + schema additions. Compared to 14-20 files in the full-variant approach.

### 6. Auto-Escalation is Complementary, Not a Replacement

skill-orchestrate already has:
- `cycle_count` / `MAX_CYCLES` loop guard
- `blocker_escalation_count` / `MAX_BLOCKER_ESCALATIONS`
- `drift_inspection_count` / `MAX_DRIFT_INSPECTIONS`
- Drift detection with `DRIFT_COMPLETION_THRESHOLD` and `DRIFT_REVISION_THRESHOLD`

Adding churn detection (from H5/H6) is natural:
```json
// In .orchestrator-loop-guard:
{
  "defect_claims": 0,
  "sorry_relocations": 0,
  "churn_threshold": 3
}
```

When `defect_claims >= churn_threshold`, the orchestrator:
1. Triggers divergence audit (H5) instead of another implementation dispatch
2. Sets `effort_mode: "hard"` in state.json
3. Subsequent dispatches automatically load hard-mode contracts

This makes --hard the manual trigger and auto-escalation the automatic one. They're complementary: --hard says "I know this will be hard", auto-escalation says "the system detected this became hard."

### 7. Real-World Patterns from Claude Code Ecosystem (June 2026)

From web research on current best practices:

**Cost-Routing Layer** (from Firecrawl blog): "If you are running skills at volume, adding a cost-routing layer to your dispatch skill can meaningfully reduce spend without touching quality." This is essentially effort-based routing — the same principle as --hard, applied to model selection.

**Control Stack** (from ObviousWorks architecture): "The winning pattern in 2026 is a control stack: project rules, reusable skills, bounded sub-agents, and deterministic tools around the model." Hard-mode contracts fit naturally as a layer in this control stack.

**SkillTool vs AgentTool** (from Anthropic docs): "SkillTool injects into current context (cheap), while AgentTool spawns isolated context (expensive)." This confirms that prompt contracts (injected via skill context) are cheaper than new agent variants.

**Multi-Agent Orchestra** (Addy Osmani): The quality-gate escalation pattern — "Plan approval catches bad architecture before code exists" — maps directly to H4 (adversarial verification before implementation). The pattern is recognized in the broader ecosystem.

## Alternative Approaches (Ranked by Feasibility)

### Rank 1: Hybrid Contracts + Orchestrator Variant (RECOMMENDED)

**Feasibility**: High | **Complexity**: Low-Medium | **Maintenance**: Low

- Prompt contracts for workers (H2, H3, H7, H9) — 4-5 new context files
- skill-orchestrate-hard (or branched) for loop changes (H1, H5, H6) — 1 new skill or 0
- Plan format extension (H8) — 1 new context file
- Schema extension — minor state.json changes
- **Total new files: ~6-7** vs 14-20 for full variants

### Rank 2: Full Variant Skills (Report 01's Proposal)

**Feasibility**: High | **Complexity**: High | **Maintenance**: High

- Separate skill-X-hard files for every workflow
- Separate agent-hard files where needed
- Maximum control, maximum duplication
- 14-20 new files, 7,000-12,000 new lines
- Every base skill change requires parallel update

### Rank 3: Profile-Based with Auto-Escalation

**Feasibility**: Medium | **Complexity**: Medium | **Maintenance**: Medium

- State.json profiles control behavior
- Auto-escalation from churn detection
- More configurable but more complex schema
- Better as a v2 evolution of Rank 1

### Rank 4: Pure Middleware/Decorator

**Feasibility**: Low | **Complexity**: Low | **Maintenance**: Low

- All hard-mode as prompt injection
- Cannot handle structural differences (per-phase loop)
- Insufficient for the orchestrate skill
- Only viable for simple prompt-level changes

## Evidence/Examples

### From This Codebase

1. **Team skill duplication**: skill-team-research is 633 lines vs skill-researcher at 465 lines. They share ~60% boilerplate but have completely different core execution flows. This is the maintenance cost of full variants.

2. **Lean extension skills**: skill-lean-implementation (317 lines) is thinner than general-implementation (638 lines) because it delegates to a domain-specific agent with domain-specific prompts but reuses the same overall lifecycle. Hard-mode contracts would follow this "thin overlay" pattern.

3. **parse-command-args.sh already exports EFFORT_FLAG**: The flag plumbing is complete. The missing piece is what happens AFTER the flag is parsed — currently nothing beyond passing it as "prompt context" to skills.

4. **skill-orchestrate's drift detection**: Lines 358-487 already implement a primitive form of auto-escalation (drift → revision). Adding churn detection follows the same pattern.

5. **Extension routing via manifest.json**: The existing routing pattern (`routing.research["lean4"] = "skill-lean-research"`) could be extended with effort-mode variants (`routing.research_hard["lean4"] = "skill-lean-research-hard"`) but this is overkill if contracts handle most of the work.

### From Web Research

- [Progressive Complexity Escalation](https://agentic-patterns.com/patterns/progressive-complexity-escalation/) — validates tiered capability approach but warns about tier management overhead
- [Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/) — quality gates as escalation, not difficulty routing
- [Claude Code Skills Best Practices](https://www.firecrawl.dev/blog/best-claude-code-skills) — cost-routing layer pattern
- [CLAUDE.md Architecture 2026](https://www.obviousworks.ch/en/designing-claude-md-right-the-2026-architecture-that-finally-makes-claude-code-work/) — control stack pattern, advisory vs deterministic separation
- [Claude Code Subagent Docs](https://code.claude.com/docs/en/sub-agents) — SkillTool (inject context) vs AgentTool (spawn context) cost distinction
- [Multi-Agent Orchestration Guide](https://www.codebridge.tech/articles/mastering-multi-agent-orchestration-coordination-is-the-new-scale-frontier) — supervisor model with tiered effort

## Confidence Assessment

| Finding | Confidence | Basis |
|---------|-----------|-------|
| Duplication cost of full variants is 14-20 files | High | Direct line count analysis of existing codebase |
| Hybrid approach minimizes files to ~6-7 | High | Architecture analysis against Report 01's H1-H9 |
| Prompt contracts work for H2/H3/H7/H9 | High | These are prompt-level changes, confirmed by codebase structure |
| skill-orchestrate needs structural variant for H1/H5/H6 | High | Per-phase loop is fundamentally different from whole-plan dispatch |
| Auto-escalation is feasible within existing loop guard | Medium | Drift detection exists but churn detection is untested |
| Profile-based approach is better for v2 | Medium | Architecturally sound but premature complexity for v1 |
| Web patterns support tiered effort routing | Medium | Multiple sources describe the pattern but none in identical context |
