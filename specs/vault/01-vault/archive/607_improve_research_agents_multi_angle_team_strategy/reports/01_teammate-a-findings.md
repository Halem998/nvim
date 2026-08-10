# Teammate A Findings: Primary Implementation Approach

**Task**: 607 - Improve research agents with multi-angle team research strategy
**Role**: Primary Angle (implementation patterns and architecture)
**Date**: 2026-05-22

## Key Findings

### 1. Current System Architecture

The team research system (`skill-team-research/SKILL.md`) currently:
- Hardcodes 4 teammates (Primary, Alternatives, Critic, Horizons) regardless of task complexity
- Has no exploit/explore mode distinction — all teammates get generic role assignments
- Routes through `skill-team-research` as a monolithic skill; domain-specific extensions (lean, formal) are bypassed entirely in team mode
- The `parse-command-args.sh` script (lines 71-112) parses `--team` and `--team-size` flags but has no `--exploit`/`--explore` flags
- Domain-specific agents (e.g., `lean-research-agent.md`) have rich tool access (MCP lean-lsp tools, search decision trees) that team mode teammates never use

### 2. Critical Gap: Team Mode Bypasses Domain Expertise

When `--team` is passed to `/research`, routing goes directly to `skill-team-research`, which spawns generic teammates with no access to domain-specific tools, context, or agent definitions. For a `lean4` task, this means:
- No MCP lean-lsp tools (lean_goal, lean_leansearch, lean_loogle, etc.)
- No zero-debt policy enforcement
- No literature extraction protocol
- No Lean-specific search decision tree

This is the single biggest problem. The team research skill must route domain-aware teammates when the task type has a domain extension.

### 3. Exploit vs Explore: Research-Backed Framework

From web research, the exploration-exploitation tradeoff in multi-agent systems is well-studied:

- **Exploit mode** (deep-dive): Multiple agents decompose a single known approach into sub-problems. Useful when the user has identified a promising direction and wants thorough coverage. Analogous to "tactical candidate generation" — agents work on different facets of the same strategy.
- **Explore mode** (breadth-first): Agents independently search for alternative approaches, casting a wide net. Useful early in research or when current approaches are blocked. Analogous to "strategic policy mediation" — diversity of search is maximized.
- **Mixed mode** (default): Combines both — some agents exploit a known direction while others explore alternatives. The current A/B/C/D roles already approximate this loosely.

A key insight from the literature: "Single-agent LLM approaches that jointly perform strategy selection and candidate generation suffer from cognitive overload." Decomposing into specialized explore/exploit agents reduces this overload.

**Temperature metaphor**: An "exploration temperature" parameter can control the balance. High temperature = more explore agents; low temperature = more exploit agents. This maps naturally to the `--exploit` / `--explore` flags.

### 4. Dynamic Team Sizing Heuristics

Research from Google/MIT ("Towards a Science of Scaling Agent Systems", 2025) shows:
- More agents often hits a ceiling and can degrade performance
- Task-architecture alignment matters more than agent count
- Coordination overhead scales superlinearly with team size

**Proposed heuristics for team size**:

| Signal | Team Size | Rationale |
|--------|-----------|-----------|
| Simple/focused task + `--fast` | 2 | Minimal: Primary + Critic |
| Default task | 3 | Primary + Alternatives + Critic |
| Complex/multi-faceted task | 4 | Full: Primary + Alternatives + Critic + Horizons |
| `--hard` flag | 4 | Maximum coverage |
| `--exploit` flag | 3-4 | Multiple sub-problem agents + Critic |
| `--explore` flag | 3-4 | Multiple independent searchers + Critic |
| Repeated blocker (auto-route) | 4 | Maximum diversity to break deadlock |

The Critic should always be present (minimum team = 2 includes Critic). This aligns with the user's explicit request.

### 5. Critic as Permanent Fixture

The literature strongly supports a permanent critic role:
- "A critic-equipped LLM planner can verify the correctness of subtasks, mitigating the hallucination problem" (arxiv 2501.06322)
- ACC-Collab's actor-critic framework shows the critic specializes in quality assessment
- Debate frameworks (defender + critic + judge) improve robustness

**However, the adversarial critic must be carefully bounded**: A "strategically designed adversarial agent can significantly influence group outcomes through coherent, confident, and misleading arguments, potentially lowering system accuracy by 10-40%." The critic's role should be constructive gap-finding, not adversarial opposition.

Current critic prompt is well-designed for this — it focuses on gaps, assumptions, and blind spots, not on opposing findings.

### 6. Lean-Specific Tactic Discovery

For Lean tasks, team research teammates should:
- Use `lean_multi_attempt` to test multiple tactics at proof positions
- Use `lean_hammer_premise` to find premises for simp/aesop
- Use `lean_state_search` to find closing lemmas for specific goals
- Survey `lean_leansearch`/`lean_loogle`/`lean_leanfinder` for alternative lemma approaches
- Report discovered tactics alongside research findings

This requires teammates to have access to the lean-lsp MCP tools, which means the team research skill needs domain-aware teammate spawning.

## Recommended Approach

### Architecture: Domain-Aware Team Research

**Phase 1: New flags in parse-command-args.sh**

Add `--exploit`, `--explore`, and `--mixed` flags:

```bash
# In parse-command-args.sh, after existing flag parsing:
RESEARCH_MODE=""   # "exploit", "explore", "mixed", or "" (auto)

if [[ "$remaining" =~ --exploit ]]; then
  RESEARCH_MODE="exploit"
fi
if [[ "$remaining" =~ --explore ]]; then
  RESEARCH_MODE="explore"
fi
if [[ "$remaining" =~ --mixed ]]; then
  RESEARCH_MODE="mixed"
fi
```

Strip from FOCUS_PROMPT:
```bash
| sed 's/--exploit//g' \
| sed 's/--explore//g' \
| sed 's/--mixed//g' \
```

Export: `export RESEARCH_MODE`

**Phase 2: Dynamic team sizing in skill-team-research**

Replace the hardcoded `team_size=4` with dynamic calculation:

```bash
# Dynamic team sizing
if [ "$EFFORT_FLAG" = "fast" ]; then
  team_size=2  # Primary + Critic only
elif [ "$EFFORT_FLAG" = "hard" ]; then
  team_size=4  # Full team
elif [ -n "$RESEARCH_MODE" ] && [ "$RESEARCH_MODE" = "exploit" ]; then
  team_size=3  # Sub-problem decomposition + Critic
elif [ -n "$RESEARCH_MODE" ] && [ "$RESEARCH_MODE" = "explore" ]; then
  team_size=3  # Independent searchers + Critic
else
  # Default: check task complexity signals
  team_size=3  # Primary + Alternatives + Critic (skip Horizons for cost)
fi

# --team-size override still takes precedence
if [ "$user_team_size" -gt 0 ]; then
  team_size="$user_team_size"
fi
```

**Phase 3: Mode-aware teammate role assignment**

Instead of fixed A/B/C/D roles, dynamically assign roles based on mode:

```
Exploit mode (team_size=3-4):
  A: Deep-dive on approach X, sub-problem 1
  B: Deep-dive on approach X, sub-problem 2
  C: Critic (always)
  D: (optional) Deep-dive on approach X, sub-problem 3

Explore mode (team_size=3-4):
  A: Search direction 1 (e.g., backward from problem sites)
  B: Search direction 2 (e.g., literature/documentation review)
  C: Critic (always)
  D: (optional) Search direction 3 (e.g., infrastructure inventory)

Mixed mode (team_size=3-4):
  A: Primary approach (exploit the current best idea)
  B: Alternative approaches (explore new ideas)
  C: Critic (always)
  D: (optional) Horizons (strategic alignment)
```

**Phase 4: Domain-aware teammate spawning**

The key architectural change: when spawning teammates for a domain-specific task type, inject domain context and tools:

```bash
# In skill-team-research, Stage 5b:
case "$task_type" in
  "lean4"|"lean4:*")
    # Load lean-specific agent context
    domain_context="Read the lean-research-agent.md for search decision tree and tool usage.
Use MCP lean-lsp tools: lean_leansearch, lean_loogle, lean_leanfinder, lean_state_search,
lean_hammer_premise, lean_multi_attempt.
When surveying approaches, look for tactics that could help improve proof quality.
Follow the zero-debt policy: never recommend sorry deferral."
    domain_agent_ref=".claude/extensions/lean/agents/lean-research-agent.md"
    ;;
  "formal"|"formal:*")
    domain_context="Focus on formal reasoning patterns..."
    domain_agent_ref=".claude/extensions/formal/agents/formal-research-agent.md"
    ;;
  *)
    domain_context=""
    domain_agent_ref=""
    ;;
esac
```

Then inject `domain_context` into each teammate prompt.

**Phase 5: Auto-route to team research on repeated blockers**

Add blocker detection in single-agent research skills:

```bash
# In skill-researcher (and domain variants), after research completes:
# Check if the same blocker pattern appears in previous research
blocker_count=$(jq -r --arg task "$task_number" \
  '[.active_projects[] | select(.status == "blocked") | 
   select(.blocker_description | test("PATTERN"))] | length' \
  specs/state.json)

if [ "$blocker_count" -ge 2 ]; then
  # Recommend team research in report
  echo "NOTE: This blocker has appeared $blocker_count times. Consider /research $task_number --team for multi-angle investigation."
fi
```

**Phase 6: Prototype-first research pattern**

Add guidance in research agent prompts:

```
When evaluating implementation approaches:
1. For each candidate approach, describe a minimal prototype that could validate it
2. Estimate prototype effort (minutes, not hours)
3. Recommend which prototype to try first
4. If a lean-lsp tool like lean_multi_attempt can validate a tactic, use it as a prototype
```

### Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `.claude/scripts/parse-command-args.sh` | Add `--exploit`, `--explore`, `--mixed` flags + `RESEARCH_MODE` export | High |
| `.claude/skills/skill-team-research/SKILL.md` | Dynamic team sizing, mode-aware roles, domain-aware context injection | High |
| `.claude/context/patterns/team-orchestration.md` | Document exploit/explore/mixed modes, dynamic sizing heuristics | Medium |
| `.claude/agents/general-research-agent.md` | Add prototype-first pattern guidance | Medium |
| `.claude/extensions/lean/agents/lean-research-agent.md` | Add tactic discovery survey protocol | Medium |
| `.claude/skills/skill-researcher/SKILL.md` | Add auto-route recommendation on repeated blockers | Low |
| `.claude/CLAUDE.md` | Update command reference with new flags | Low |

## Evidence/Examples

### AORCHESTRA Model (Feb 2026)
Models every subagent as a 4-tuple (INSTRUCTION, CONTEXT, TOOLS, MODEL), spawned on demand. Reports +16.28% improvement against strongest baseline. Our system already follows this pattern via Agent tool parameters.

### Captain Agent (Adaptive Team Building)
"Static team building necessitates maintaining teams with all required expertise for the whole task cycle, and as task complexity increases, the total number of team members may grow significantly." This validates the need for dynamic sizing rather than always spawning 4.

### Multi-Agent Decomposition (Exploration-Exploitation)
"A multi-agent framework decomposes exploration-exploitation control into strategic policy mediation and tactical candidate generation." This maps directly to our exploit/explore mode proposal.

### Google/MIT Scaling Study
"More agents often hits a ceiling and can even degrade performance if not aligned with task properties." This argues for conservative defaults (team_size=3, not 4) with explicit override flags.

## Confidence Level

**High** for the overall architecture (domain-aware team research, dynamic sizing, exploit/explore modes).

**Medium** for the specific implementation details (exact heuristics, prompt wording, blocker detection thresholds). These would benefit from iterative testing.

**High** for the critic-as-permanent-fixture recommendation — strongly supported by literature and user preference.
