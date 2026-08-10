# Seed Research Report: Task #594

**Task**: 594 — Refactor workflow skills to shared base pattern
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to skill base refactoring

## Overview

Task 594 refactors the 4 core workflow skills (skill-researcher 558L, skill-planner 490L, skill-implementer 629L, skill-reviser 489L) to use a shared base pattern. This task depends on both task 593 (shared utilities) and task 598 (progressive disclosure / context budget architecture) because the shared base must know about context tiers and budget caps. This task also formally resolves task 500 (add_context_fork_to_core_skills).

## Critical Design Constraint: Task 500 Resolution

**Finding (Teammate C, citing task 500's research)**: "Fork cache sharing is fundamentally incompatible with named agent routing."

**Resolution for task 594**: The shared skill base must use forks ONLY for same-turn re-dispatch (blocker escalation in /orchestrate), and fresh named subagents for all core skill dispatch. The `dispatch_agent()` abstraction (from task 593/592) encapsulates this decision.

**Implication**: Task 500's plan (add `context: fork` to core skills for cache sharing) should NOT be implemented. Task 594 supersedes task 500's findings by establishing the correct pattern.

## Skill Duplication Analysis

### What IS Safe to Share (Teammates A, B)

**~8 of ~11 stages are structurally identical** across the 4 core skills:
1. Input validation
2. Preflight status update
3. Artifact number calculation
4. Memory retrieval
5. Format injection
6. Agent spawning
7. Metadata reading
8. Postflight status update
9. Artifact linking
10. Git commit
11. Cleanup and return summary

**Target reduction**: Each skill from ~500L down to ~100-150L of unique logic.

### What MUST Remain Skill-Specific (Teammate C)

**Critical caution**: The structural similarity is partially intentional. Evidence:
1. `skill-lifecycle.md` explicitly records prior 3-skill pattern as "Legacy Pattern (Deprecated)" — single-skill-per-workflow was chosen to reduce halt risk
2. Each skill's Stage 2 (Preflight) differs in the target status string and what it says in its note
3. The skills' stage numbering is already inconsistent (researcher has Stage 4a/4b/4c/4d; implementer has 5a/5b/5c; reviser has Stage 4 with no sub-stages)

**Context-collection stages (MUST stay skill-specific)**:
- skill-researcher: Stages 4a (memory), 4b (roadmap), 4c (prior context), 4d (format)
- skill-planner: Stage 4a only
- skill-implementer: Stage 4a only
- skill-reviser: Stage 4 (combined context collection)

**Implication for shared base design**: The shared base needs conditional inclusion for context-collection stages. The abstraction complexity must be validated to actually reduce token cost before committing.

### Shared Base Implementation Pattern (Teammate A)

**Proposed**: `.claude/scripts/skill-base.sh` as a sourced shell library. Each skill:
1. Sources the shared base library
2. Provides skill-specific parameters:
   - Agent type (which agent to invoke)
   - Operation type (research|plan|implement|revise)
   - Context collection function (skill-specific stage)
   - Completion status (researched|planned|implemented|revised)

```bash
# skill-researcher/SKILL.md excerpt (after refactoring):
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/skill-base.sh"

# Skill-specific configuration
OPERATION_TYPE="research"
AGENT_TYPE="general-research-agent"
COMPLETION_STATUS="researched"
CONTEXT_TIER="3"  # sonnet worker context budget

# Skill-specific context collection
collect_skill_context() {
  # Stage 4a: Memory retrieval
  # Stage 4b: Roadmap injection
  # Stage 4c: Prior context
  # Stage 4d: Format injection
}

# Delegate to shared base lifecycle
run_skill_lifecycle
```

## Context Budget Integration (Task 598 Dependency)

**Why task 594 depends on task 598**: The shared skill base must know each skill's context tier and budget cap. Designing the base before task 598 defines the tier system would require redesigning the base.

From task 598's findings (Teammate A):
- Sonnet worker agents (researcher, implementer): ~8K tokens context budget
- Opus planning agents (planner): ~15K tokens context budget
- Haiku utility agents: ~2K tokens context budget

The shared base must include budget enforcement:
```bash
CONTEXT_BUDGET="${SKILL_CONTEXT_BUDGET:-8000}"  # tokens
check_context_budget() {
  local current_context_size="$1"
  [[ "$current_context_size" -gt "$CONTEXT_BUDGET" ]] && \
    log_warning "Context budget exceeded: $current_context_size > $CONTEXT_BUDGET"
}
```

## Extension Lifecycle Hooks (Teammate D)

Task 594 must implement the extension lifecycle hook interface designed in task 592. Extension skills should participate in the lifecycle through hooks, not through full skill duplication.

**Hook execution in shared base**:
```bash
run_skill_lifecycle() {
  # Check for extension hooks
  local preflight_hook="${EXTENSION_PREFLIGHT_HOOK:-}"
  local context_hook="${EXTENSION_CONTEXT_HOOK:-}"
  local postflight_hook="${EXTENSION_POSTFLIGHT_HOOK:-}"
  
  # Execute preflight hook if defined
  [[ -n "$preflight_hook" ]] && bash "$preflight_hook" "$TASK_NUM"
  
  # ... standard lifecycle stages ...
  
  # Execute postflight hook if defined  
  [[ -n "$postflight_hook" ]] && bash "$postflight_hook" "$TASK_NUM" "$ARTIFACT_PATH"
}
```

**Evidence from current system (Teammate C)**: "nix-implementation uses non-standard stage format" — this is the silent divergence that lifecycle hooks prevent. When the core changes, extensions currently break silently.

## Team Skills Coverage

Team skills (skill-team-research 616L, skill-team-plan 598L, skill-team-implement 677L) should also use the shared base where possible. Key difference:
- Team skills spawn multiple parallel agents (teammates 2-N)
- With `FORK_SUBAGENT=1`, teammates 2-N share the parent's cached prefix (~60% total cost reduction)
- Team skill orchestration stage (spawning N teammates) is unique and cannot be shared

**Cost profile (Teammate B)**: "Each teammate spawns a fresh context. At ~48,500 shared prefix tokens × 3 teammates = ~145,500 tokens. With FORK_SUBAGENT: ~58,200 tokens (~60% reduction)."

## Validation Requirement (Teammate C)

Before committing to the full skill base refactoring, validate that the abstraction actually reduces total token cost. Suggested validation approach:

1. Refactor ONE skill (start with skill-researcher as the simplest)
2. Run baseline tests and compare token costs
3. If token cost increases (due to abstraction overhead), reconsider scope
4. Only proceed with remaining skills if cost is neutral or better

**Risk assessment** (Teammate C): "The most dangerous assumption is that a shared utility layer will actually reduce token consumption at the point of use; the system already uses lazy-loading and scripted delegation patterns that may make the duplication cheaper to keep than the abstraction overhead to eliminate."

## Compatibility Gates

Extension compatibility must be verified at each skill refactoring step, NOT only at task 599. After each skill is refactored:
1. Test that extension skills (skill-neovim-research, skill-neovim-implementation, skill-nix-research, skill-nix-implementation) still work
2. Verify that the extension hook interface is respected
3. If any extension breaks, fix before proceeding

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 5 (Practical deduplication targets: shared skill base), Section 6 (Extension system evolution)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Recommended Approach section 1 (Shared skill base)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 6 (FORK_SUBAGENT cache sharing architecture)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 1 (Duplication may be intentional), Finding 7 (task 500 conflict)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 2 (Extension system evolution), Finding 3 (dispatch_agent abstraction)
- `specs/500_add_context_fork_to_core_skills/reports/` — Prior fork research (subsumed by this task)
