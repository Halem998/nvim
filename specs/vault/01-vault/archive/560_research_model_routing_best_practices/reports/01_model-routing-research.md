# Research Report: Task #560

**Task**: 560 - Research Model Routing Best Practices
**Started**: 2026-05-13T12:00:00Z
**Completed**: 2026-05-13T12:45:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase audit of `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.claude/extensions/`
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config)
- [Create Custom Subagents](https://code.claude.com/docs/en/sub-agents)
- [Anthropic Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Choosing the Right Model](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model)
- [Claude Opus 4.7 vs Sonnet 4.6 vs Haiku 4.5 Comparison](https://tech-insider.org/claude-opus-vs-sonnet-vs-haiku-2026/)
- [Claude Code opusplan Mode](https://claudelab.net/en/articles/claude-code/claude-code-model-selection-opusplan-strategy)
**Artifacts**:
- `specs/560_research_model_routing_best_practices/reports/01_model-routing-research.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The system currently hardcodes `model: opus` in 10/11 core agents, 15/15 core commands, and most extension agents -- a uniform policy that Anthropic's own documentation discourages for cost optimization.
- Claude Code's official subagent model resolution order is: (1) `CLAUDE_CODE_SUBAGENT_MODEL` env var, (2) per-invocation `model` parameter, (3) frontmatter `model` field, (4) main conversation model. The `inherit` value (and omitting the field entirely) both default to the parent session's model.
- Sonnet 4.6 scores 79.6% on SWE-bench Verified vs Opus 4.6's 80.8% (1.2 point gap), making it suitable for most implementation and pattern-execution tasks. Opus 4.7 scores 87.6%, an 8-point jump, making it genuinely superior for complex reasoning.
- Anthropic's official model selection matrix recommends Haiku 4.5 explicitly for "sub-agent tasks," Sonnet 4.6 for "code generation, agentic tool use," and Opus 4.7 for "long-horizon agentic coding, complex systems engineering."
- A tiered model assignment could reduce per-session costs by 40-60% while preserving quality where it matters, with `--opus` override flags already available for edge cases.

## Context & Scope

This research evaluates the model assignment strategy across the `.claude/` agent orchestration system. The current policy -- `model: opus` everywhere -- was established when the system was first built, treating Opus as a quality baseline. With Opus 4.7 now at $5/$25 per MTok, Sonnet 4.6 at $3/$15, and Haiku 4.5 at $1/$5, there is significant cost optimization potential without sacrificing quality for most agent roles.

The scope covers:
1. Complete inventory of model specifications across agents, commands, skills, and extensions
2. Current 2026 model capabilities, pricing, and official guidance
3. Per-role cognitive complexity analysis
4. Recommended model assignment matrix with cost projections

## Findings

### Current Model Inventory

#### Core Agents (`.claude/agents/`)

| Agent | Current Model | Notes |
|-------|---------------|-------|
| general-research-agent | opus | Web search + codebase exploration |
| general-implementation-agent | opus | File editing from plans |
| planner-agent | opus | Creates phased implementation plans |
| meta-builder-agent | opus | Interactive system builder, reference implementation |
| code-reviewer-agent | opus | Code quality assessment |
| reviser-agent | opus | Plan revision with research synthesis |
| spawn-agent | opus | Blocker analysis and task decomposition |
| neovim-research-agent | opus | Plugin/config research |
| neovim-implementation-agent | (not set) | Config implementation (inherits) |
| nix-research-agent | opus | NixOS/HM research |
| nix-implementation-agent | opus | Nix config implementation |

**Summary**: 10 of 11 core agents explicitly set `model: opus`. Only `neovim-implementation-agent` omits it (inheriting from parent session).

#### Core Commands (`.claude/commands/`)

All 15 commands with model fields set `model: opus`: errors, fix-it, implement, merge, meta, plan, project-overview, refresh, research, review, revise, spawn, tag, task, todo.

Note: The `distill` and `learn` commands do not set a model field (they are direct-execution skills, not subagent dispatchers).

#### Extension Agents

| Extension | Agents with `model: opus` | Agents with model not set |
|-----------|---------------------------|---------------------------|
| core | 7/7 | 0 |
| epidemiology | 2/2 | 0 |
| filetypes | 0/7 | 7 |
| formal | 4/4 | 0 |
| founder | 2/16 | 14 |
| latex | 1/2 | 1 |
| lean | 2/2 | 0 |
| nix | 2/2 | 0 |
| nvim | 1/2 | 1 |
| present | 9/9 | 0 |
| python | 0/2 | 2 |
| typst | 0/2 | 2 |
| web | 0/2 | 2 |
| z3 | 0/2 | 2 |

**Summary**: 30 extension agents set `model: opus`, 31 extension agents omit it (inheriting). The split is inconsistent -- some extensions (present, formal, lean) hardcode opus everywhere, while others (python, typst, web, z3, filetypes) omit it entirely.

#### Team Mode Skills

Team skills (skill-team-research, skill-team-plan, skill-team-implement) default teammates to Sonnet when no model_flag is provided, which is the one existing cost optimization in the system.

#### Standards and Templates

- `agent-frontmatter-standard.md` states: "All agents default to Opus" as policy
- `agent-template.md` shows `model: opus` as the template default
- `core/agents/README.md` contains a contradictory note: "Research and planning agents typically use opus; implementation agents typically omit the field"

### 2026 Model Capabilities and Pricing

#### Pricing (Per Million Tokens)

| Model | Input | Output | Cache Hits | Ratio vs Opus |
|-------|-------|--------|------------|---------------|
| Opus 4.7 | $5.00 | $25.00 | $0.50 | 1.0x |
| Opus 4.6 | $5.00 | $25.00 | $0.50 | 1.0x |
| Sonnet 4.6 | $3.00 | $15.00 | $0.30 | 0.6x |
| Haiku 4.5 | $1.00 | $5.00 | $0.10 | 0.2x |

**Note**: Opus 4.7's new tokenizer uses up to 35% more tokens for the same text, making its effective cost higher than the raw price ratio suggests.

#### Performance Benchmarks

| Model | SWE-bench Verified | SWE-bench Pro |
|-------|-------------------|---------------|
| Opus 4.7 | 87.6% | 64.3% |
| Opus 4.6 | 80.8% | 53.4% |
| Sonnet 4.6 | 79.6% | - |
| Haiku 4.5 | - | - |

Key insight: Sonnet 4.6 is only 1.2 points behind Opus 4.6 on SWE-bench Verified. Opus 4.7 represents a genuine capability jump of ~8 points over both.

#### Official Anthropic Guidance

From the "Choosing the Right Model" documentation:

| Capability Need | Recommended Model | Example Use Cases |
|-----------------|-------------------|-------------------|
| Most capable complex reasoning | Opus 4.7 | Long-horizon agentic coding, large-scale refactoring, complex systems engineering |
| Frontier intelligence at scale | Sonnet 4.6 | Code generation, data analysis, agentic tool use |
| Near-frontier with speed | Haiku 4.5 | Real-time applications, high-volume processing, **sub-agent tasks** |

Anthropic explicitly recommends Haiku 4.5 for "sub-agent tasks" in their model selection matrix.

### Claude Code Model Resolution Order

When a subagent is invoked, the model is resolved in this priority order:

1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable (highest)
2. Per-invocation `model` parameter (passed by the Task/Agent tool)
3. Subagent definition's `model` frontmatter field
4. Main conversation's model (lowest / default)

The `model: inherit` value (or omitting the field entirely) means "use the main conversation's model." Critically, `CLAUDE_CODE_SUBAGENT_MODEL` does NOT override agents that have an explicit `model` set in frontmatter -- it only affects agents that inherit.

This means the current system where nearly every agent has `model: opus` hardcoded is actually **blocking** the `CLAUDE_CODE_SUBAGENT_MODEL` optimization path. Users cannot use this env var to globally set a cheaper default because every agent overrides it with its own explicit `opus` declaration.

### The `opusplan` Pattern

The `opusplan` model alias uses Opus during plan mode and automatically switches to Sonnet for execution. This is Anthropic's officially supported hybrid approach for cost optimization.

This pattern maps well to the system's existing architecture:
- Research/planning agents = "plan mode" (need deep reasoning)
- Implementation agents = "execution mode" (mostly pattern application)

### Built-in Subagent Precedent

Claude Code's own built-in subagents already use tiered models:
- **Explore** agent: Uses Haiku (fast, read-only codebase exploration)
- **Plan** agent: Inherits from main conversation
- **General-purpose** agent: Inherits from main conversation
- **claude-code-guide**: Uses Haiku
- **statusline-setup**: Uses Sonnet

This demonstrates that Anthropic themselves tier their subagent models rather than using Opus everywhere.

### Cognitive Complexity Analysis Per Agent Role

#### Tier 1: Deep Reasoning Required (Opus recommended)

- **planner-agent**: Creates multi-phase implementation plans with dependency analysis, risk assessment, and architectural decisions. This is the highest-reasoning task.
- **meta-builder-agent**: Designs system architecture, dependency DAGs, topological sorting. Reference implementation for complex multi-task creation.
- **reviser-agent**: Synthesizes existing plans with new research findings, requires deep analytical comparison.
- **formal-research-agent / logic-research-agent / math-research-agent / physics-research-agent**: Formal reasoning, mathematical proofs, domain expertise.
- **lean-research-agent / lean-implementation-agent**: Lean 4 formal verification requires deep mathematical reasoning.
- **legal-analysis-agent**: Complex legal reasoning and risk assessment.

#### Tier 2: Moderate Reasoning (Sonnet suitable)

- **general-research-agent**: Web search + codebase exploration. Primarily information gathering and synthesis, not deep architectural reasoning.
- **spawn-agent**: Analyzes blockers and decomposes into subtasks. Moderate reasoning complexity.
- **code-reviewer-agent**: Pattern matching, style checking, security scanning. Well within Sonnet's capabilities.
- **general-implementation-agent**: Follows plans to edit files. Mostly pattern execution.
- **nix-research-agent / nix-implementation-agent**: Configuration research and implementation. Pattern-heavy.
- **neovim-research-agent / neovim-implementation-agent**: Plugin research, Lua config. Pattern-heavy.
- **grant-agent / budget-agent / funds-agent**: Financial analysis, structured document creation.
- **slides-research-agent / slide-planner-agent**: Content research and presentation planning.
- **epi-research-agent / epi-implement-agent**: Epidemiological modeling, data analysis.

#### Tier 3: Pattern Execution (Sonnet or Haiku suitable)

- **All implementation agents** (python, typst, web, z3, latex, founder): Follow established plans to modify files. Structured, mechanical work.
- **pptx-assembly-agent / slidev-assembly-agent**: Template-driven document assembly.
- **filetypes agents** (document, docx-edit, spreadsheet, scrape, sheet, presentation, router): Format conversion and file manipulation.

#### Direct Execution (No model field needed)

- skill-status-sync, skill-refresh, skill-todo, skill-orchestrator, skill-git-workflow, skill-fix-it, skill-project-overview, skill-memory: These execute directly without spawning subagents.

### Model Assignment Matrix

| Agent | Current | Recommended | Rationale | Risk Level |
|-------|---------|-------------|-----------|------------|
| **planner-agent** | opus | opus | Architectural reasoning, dependency analysis | Low (keep best) |
| **meta-builder-agent** | opus | opus | System design, DAG construction | Low (keep best) |
| **reviser-agent** | opus | opus | Plan synthesis requires deep comparison | Low (keep best) |
| **general-research-agent** | opus | sonnet | Information gathering, not deep reasoning. Override with `--opus` for complex tasks | Medium |
| **general-implementation-agent** | opus | sonnet | Follows plans, pattern execution | Low |
| **code-reviewer-agent** | opus | sonnet | Pattern matching, style checking | Low |
| **spawn-agent** | opus | sonnet | Task decomposition, moderate reasoning | Low-Medium |
| **neovim-research-agent** | opus | sonnet | Plugin/config research | Low |
| **neovim-implementation-agent** | (not set) | sonnet | Config editing, pattern work | Low |
| **nix-research-agent** | opus | sonnet | NixOS option lookup, configuration research | Low |
| **nix-implementation-agent** | opus | sonnet | Nix config editing | Low |
| **lean-research-agent** | opus | opus | Formal verification needs deep reasoning | Low (keep best) |
| **lean-implementation-agent** | opus | opus | Proof construction is deeply reasoning-intensive | Low (keep best) |
| **formal-research-agent** | opus | opus | Formal logic, mathematical reasoning | Low (keep best) |
| **logic-research-agent** | opus | opus | Logic proofs, deep reasoning | Low (keep best) |
| **math-research-agent** | opus | opus | Mathematical reasoning | Low (keep best) |
| **physics-research-agent** | opus | opus | Physics modeling, deep analysis | Low (keep best) |
| **latex-research-agent** | opus | sonnet | LaTeX package research | Low |
| **latex-implementation-agent** | (not set) | sonnet | LaTeX editing, template work | Low |
| **epi-research-agent** | opus | sonnet | Data analysis, model research | Low-Medium |
| **epi-implement-agent** | opus | sonnet | Model implementation | Low |
| **python-research-agent** | (not set) | sonnet | Python library/API research | Low |
| **python-implementation-agent** | (not set) | sonnet | Python code implementation | Low |
| **typst-research-agent** | (not set) | sonnet | Typst documentation research | Low |
| **typst-implementation-agent** | (not set) | sonnet | Typst document editing | Low |
| **web-research-agent** | (not set) | sonnet | Web tech research | Low |
| **web-implementation-agent** | (not set) | sonnet | Frontend/backend implementation | Low |
| **z3-research-agent** | (not set) | sonnet | Z3/SMT research | Medium |
| **z3-implementation-agent** | (not set) | sonnet | Z3 formula construction | Medium |
| **legal-analysis-agent** | opus | opus | Legal reasoning complexity | Low (keep best) |
| **deck-planner-agent** | opus | sonnet | Presentation planning | Low |
| **deck-research-agent** | (not set) | sonnet | Content research | Low |
| **deck-builder-agent** | (not set) | sonnet | Slide construction | Low |
| **All present/ agents** | opus | sonnet | Structured content creation | Low |
| **All filetypes/ agents** | (not set) | inherit | File conversion, routing | Low |
| **All founder/ agents (non-legal)** | varies | sonnet | Business analysis, document creation | Low |

#### Commands

| Command | Current | Recommended | Rationale |
|---------|---------|-------------|-----------|
| /research, /plan, /implement | opus | inherit | These dispatch to skills which dispatch to agents. The agent's model takes precedence anyway. Command model is only used if no skill/agent is involved |
| /task, /todo, /review, /errors, /fix-it | opus | opus | Direct execution commands that do complex work in-session. Keep opus for quality |
| /meta | opus | opus | System architecture design |
| /merge, /tag, /refresh, /revise, /spawn | opus | opus | These run in the main session context |
| /project-overview | opus | sonnet | Repository scanning, lower complexity |

### Cost Projection

Assumptions for a typical development session:
- ~5 agent invocations per session (mix of research, plan, implement)
- Average ~80K input tokens + ~20K output tokens per agent invocation
- Based on standard (non-batch, non-cached) pricing

#### Scenario A: Current (All Opus)

| Invocation | Model | Input Cost | Output Cost | Total |
|------------|-------|------------|-------------|-------|
| Research | Opus | $0.40 | $0.50 | $0.90 |
| Plan | Opus | $0.40 | $0.50 | $0.90 |
| Implement (phase 1) | Opus | $0.40 | $0.50 | $0.90 |
| Implement (phase 2) | Opus | $0.40 | $0.50 | $0.90 |
| Review | Opus | $0.40 | $0.50 | $0.90 |
| **Total** | | | | **$4.50** |

#### Scenario B: Tiered (Recommended)

| Invocation | Model | Input Cost | Output Cost | Total |
|------------|-------|------------|-------------|-------|
| Research | Sonnet | $0.24 | $0.30 | $0.54 |
| Plan | Opus | $0.40 | $0.50 | $0.90 |
| Implement (phase 1) | Sonnet | $0.24 | $0.30 | $0.54 |
| Implement (phase 2) | Sonnet | $0.24 | $0.30 | $0.54 |
| Review | Sonnet | $0.24 | $0.30 | $0.54 |
| **Total** | | | | **$3.06** |

**Projected savings: ~32% per session**

With prompt caching (typical 60% cache hit rate on subsequent invocations), both scenarios benefit equally, so the relative savings remain ~32%.

#### Scenario C: Aggressive Tiered (More Haiku)

If simpler tasks like file-conversion agents use Haiku:

| Invocation | Model | Input Cost | Output Cost | Total |
|------------|-------|------------|-------------|-------|
| Research | Sonnet | $0.24 | $0.30 | $0.54 |
| Plan | Opus | $0.40 | $0.50 | $0.90 |
| Implement (phase 1) | Sonnet | $0.24 | $0.30 | $0.54 |
| Implement (phase 2) | Haiku | $0.08 | $0.10 | $0.18 |
| Review | Sonnet | $0.24 | $0.30 | $0.54 |
| **Total** | | | | **$2.70** |

**Projected savings: ~40% per session**

### Implementation Approaches

#### Approach 1: Change Frontmatter Defaults (Recommended)

Change agent frontmatter `model:` field for each agent according to the matrix above. Users keep `--opus` override for when they need it.

**Pros**: Granular control per agent, works with existing `--opus`/`--sonnet`/`--haiku` flags, no env var management needed.

**Cons**: Many files to update across core + extensions.

#### Approach 2: Remove Explicit Model and Use CLAUDE_CODE_SUBAGENT_MODEL

Remove `model: opus` from all non-critical agents (letting them inherit), then set `CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6` globally. Keep `model: opus` only on agents that truly need it (planner, meta-builder, formal reasoning).

**Pros**: Simple global override, easy to change. Critical agents are protected by their explicit frontmatter.

**Cons**: All-or-nothing for non-critical agents (cannot tier some to Sonnet and some to Haiku via env var alone).

#### Approach 3: Adopt `model: inherit` Pattern

Set most agents to `model: inherit` (or omit the field) and control model selection at the session level. Users who run `/model opus` get Opus everywhere; users who run `/model sonnet` get Sonnet for all inherited agents.

**Pros**: Maximum user control, simplest configuration.

**Cons**: Loses the benefit of automatic tiering -- all agents get the same model unless overridden per-invocation by the skill.

#### Recommended: Hybrid of Approach 1 + 2

1. Set `model: opus` explicitly only on agents that need deep reasoning (planner, meta-builder, reviser, formal/lean/legal agents)
2. Set `model: sonnet` explicitly on agents where Sonnet is the right default (research, implementation, review agents)
3. Omit model field (inherit) on utility/simple agents (filetypes, routing agents)
4. Document that users can use `CLAUDE_CODE_SUBAGENT_MODEL` to globally override non-explicit agents, and `--opus` flag to override any specific invocation

## Decisions

- **Sonnet 4.6 is the appropriate default for most agents.** The 1.2-point SWE-bench gap vs Opus 4.6 is negligible for pattern-execution tasks, and the 40% cost reduction is significant.
- **Opus should be reserved for architectural/reasoning agents.** Planner, meta-builder, reviser, and formal reasoning agents genuinely benefit from Opus's deeper reasoning.
- **The `inherit` pattern is appropriate for simple utility agents** that do file conversion, routing, or mechanical work.
- **Commands should mostly inherit** since they dispatch to skills/agents anyway. The command's model field primarily affects the command's own parsing logic, not the subagent.
- **The frontmatter standard document and templates need updating** to reflect tiered defaults rather than uniform Opus.

## Recommendations

1. **Update agent frontmatter** for all core agents and extension agents per the Model Assignment Matrix above. Highest priority: core agents (11 files), then extensions.
2. **Update `agent-frontmatter-standard.md`** to document the tiered model policy instead of "all agents default to Opus."
3. **Update `agent-template.md` and `creating-commands.md`** to show appropriate model selection guidance.
4. **Update command frontmatter** for dispatch commands (research, plan, implement) to use `inherit` or remove the model field, since the agent's model takes precedence.
5. **Resolve the README contradiction** in `core/agents/README.md` which already suggests implementation agents should omit the model field -- align all documentation to this tiered approach.
6. **Consider adding `opusplan` documentation** to the system, noting it as an alternative cost optimization for users who prefer session-level control.
7. **Document `CLAUDE_CODE_SUBAGENT_MODEL`** in the system's configuration guide as an override mechanism for users who want global subagent model control.

## Risks & Mitigations

- **Quality regression on complex research tasks**: Sonnet handles most research well, but edge cases with deeply cross-referenced architectural analysis may produce shallower findings. **Mitigation**: The existing `--opus` flag lets users override per-invocation. Document when to use it.
- **Inconsistent behavior across extensions**: Some extensions already omit model (inherit), others hardcode opus. A mixed state could confuse developers. **Mitigation**: Standardize all extensions in a single implementation pass.
- **Breaking CLAUDE_CODE_SUBAGENT_MODEL expectations**: If users currently set this env var expecting it to apply globally, and some agents have explicit opus, they may be confused. **Mitigation**: After removing explicit opus from non-critical agents, this env var works as expected.
- **Opus 4.7 tokenizer incompatibility**: Opus 4.7 uses up to 35% more tokens than previous models for the same text. Users expecting uniform token counts across models will see variation. **Mitigation**: Document this in model selection guidance.

## Appendix

### Search Queries Used

- "Claude Code model selection subagent 2026 opus sonnet haiku best practices"
- "Claude Code opusplan mode how it works 2026"
- "Claude Code CLAUDE_CODE_SUBAGENT_MODEL environment variable 2026"
- "Claude model pricing 2026 opus sonnet haiku cost per token"
- "Claude Sonnet 4.6 vs Opus 4.7 SWE-bench coding performance comparison 2026"
- "Claude Code subagent model frontmatter model: inherit documentation 2026"
- "Claude Sonnet 4.6 code implementation quality good enough replace Opus agent tasks 2026"

### Key Documentation References

- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config) - Official model config docs
- [Create Custom Subagents](https://code.claude.com/docs/en/sub-agents) - Subagent frontmatter reference
- [Anthropic API Pricing](https://platform.claude.com/docs/en/about-claude/pricing) - Current token pricing
- [Choosing the Right Model](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model) - Official model selection guide
- [Claude Opus 4.7 Benchmarks](https://www.vellum.ai/blog/claude-opus-4-7-benchmarks-explained) - SWE-bench comparison data

### Model Resolution Priority (Official)

```
1. CLAUDE_CODE_SUBAGENT_MODEL env var  (highest)
2. Per-invocation model parameter      (from Task/Agent tool call)
3. Subagent definition model field     (frontmatter)
4. Main conversation model             (lowest / fallback)
```

### Files Requiring Modification (Implementation Scope)

Core agents (11 files):
- `.claude/agents/general-research-agent.md` (opus -> sonnet)
- `.claude/agents/general-implementation-agent.md` (opus -> sonnet)
- `.claude/agents/code-reviewer-agent.md` (opus -> sonnet)
- `.claude/agents/spawn-agent.md` (opus -> sonnet)
- `.claude/agents/neovim-research-agent.md` (opus -> sonnet)
- `.claude/agents/nix-research-agent.md` (opus -> sonnet)
- `.claude/agents/nix-implementation-agent.md` (opus -> sonnet)
- `.claude/agents/planner-agent.md` (keep opus)
- `.claude/agents/meta-builder-agent.md` (keep opus)
- `.claude/agents/reviser-agent.md` (keep opus)
- `.claude/agents/neovim-implementation-agent.md` (add sonnet)

Extension agents (30+ files in `.claude/extensions/`):
- Mirror changes for extension copies of core agents
- Update extension-specific agents per matrix

Documentation (4 files):
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- `.claude/docs/templates/agent-template.md`
- `.claude/docs/guides/creating-commands.md`
- `.claude/extensions/core/agents/README.md`

CLAUDE.md regeneration:
- `.claude/CLAUDE.md` (auto-generated; update merge-sources)
- `.claude/extensions/core/merge-sources/claudemd.md`
