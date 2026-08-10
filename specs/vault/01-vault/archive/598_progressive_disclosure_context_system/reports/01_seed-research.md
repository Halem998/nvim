# Seed Research Report: Task #598

**Task**: 598 — Progressive disclosure context system
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to progressive disclosure implementation

## Overview

Task 598 is ELEVATED in the dependency chain — it depends only on task 592 (design) and is placed in Wave 3 alongside task 593. This elevation is intentional: the context budget architecture designed in task 598 informs what the shared skill base (task 594) and command refactoring (task 595) need to support. Designing those tasks before task 598 would require redesigning them.

## Four-Tier Context Loading Architecture (Teammates A, D)

The current system has 97+ context index entries (~22K lines) loaded based on `load_when` conditions, but with no tier metadata, no budget caps, and no validation that files are actually used.

**Target architecture**:

| Tier | When Loaded | Budget | Examples |
|------|-------------|--------|---------|
| 1 (always) | Every invocation | ~500 lines | `anti-stop-patterns.md`, `return-metadata-file.md`, `checkpoint-execution.md` |
| 2 (command) | On command detection | ~1-2K lines | Command-specific routing tables, argument docs |
| 3 (agent) | At agent spawn | ~2-5K lines | Full workflow patterns, domain context |
| 4 (on-demand) | Via explicit @-ref | Unbounded | Detailed guides, templates, examples |

**Key principle** (Teammate A): "Commands should NOT load agent-level context. The agent loads its own context. The command's job is routing only."

## Budget Caps by Agent Type (Teammate A)

| Agent Type | Context Budget | Examples |
|------------|----------------|---------|
| Sonnet worker agents | ~8K tokens | general-research-agent, general-implementation-agent |
| Opus planning agents | ~15K tokens | planner-agent, meta-builder-agent |
| Haiku utility agents | ~2K tokens | (future) status checkers, validators |

**Budget enforcement in shared skill base**: The skill declares its context tier at initialization. The skill base enforces the cap during context collection.

## Current Waste Profile (Teammate A)

| Waste Source | Estimated Token Cost | Frequency |
|---|---|---|
| Full 500L command file loaded for validation-only paths | ~2K tokens | Every command invocation |
| All 11 stages of skill-researcher loaded for simple tasks | ~4K tokens | Every research task |
| Duplicate GATE IN/OUT logic in 4 workflow skills (~80% identical) | ~3K tokens duplicated | Every skill invocation |
| Team skill size (616-677L each) loaded without selective loading | ~5K tokens | Every team operation |

## index.json Schema Extension

Add to each `context/index.json` entry:
```json
{
  "path": "patterns/fork-patterns.md",
  "tier": 3,
  "estimated_tokens": 1200,
  "load_when": {
    "agents": ["general-research-agent", "general-implementation-agent"],
    "always": false
  }
}
```

**New fields**:
- `tier`: Integer 1-4 indicating when this file should be loaded
- `estimated_tokens`: Approximate token cost for budget enforcement

The agent queries the index for tier ≤ N files, checks running budget, and defers tier-4 files to explicit `@-reference` only.

## Audit Methodology (Teammate A)

**Goal**: Audit which of the 97 (or current count) entries are actually used by which agents.

**Approach**:
1. Search agent files for explicit @-references — these are definite uses
2. Check `load_when` conditions — count which conditions are actually triggered per invocation
3. Look for entries with empty `load_when.agents` and `load_when.commands` arrays (never loaded)
4. Mark dead entries as `"tier": 0` (disabled)

**Expected output**: 
- ~20-30% of entries are likely dead (never actually loaded)
- ~40% are Tier 3 (agent-specific)
- ~20% are Tier 2 (command-specific)
- ~10% are Tier 1 (always)

## Budget Cap Implementation

**In shared skill base** (connects to task 594):
```bash
load_tier_context() {
  local tier_limit="$1"
  local budget="$2"
  local current_cost=0
  
  while IFS= read -r entry; do
    local tier=$(echo "$entry" | jq -r '.tier')
    local cost=$(echo "$entry" | jq -r '.estimated_tokens')
    local path=$(echo "$entry" | jq -r '.path')
    
    [[ "$tier" -gt "$tier_limit" ]] && continue
    
    if [[ $((current_cost + cost)) -gt "$budget" ]]; then
      log_warning "Context budget exhausted at $path (cost: $cost, remaining: $((budget - current_cost)))"
      break
    fi
    
    # Load the context file
    load_context_file "$path"
    current_cost=$((current_cost + cost))
  done < <(jq -c '.entries[] | select(.tier <= '"$tier_limit"')' .claude/context/index.json)
}
```

## load_when Tier System Design

Update `load_when` patterns to support tiers:
```json
{
  "load_when": {
    "always": false,
    "tier_max": 3,
    "agents": ["general-research-agent"],
    "task_types": ["meta", "general"],
    "commands": ["/implement"]
  }
}
```

The `tier_max` field specifies the maximum tier at which this file is eligible for auto-loading. Files can still be @-referenced explicitly at any tier.

## RAG Alternative Assessment (Teammate B)

Teammate B evaluated a vector-search retrieval alternative ("RAG-style context loading"):
- **Pro**: Avoids loading irrelevant context; future tasks in new domains don't require index updates
- **Con**: Requires embedding infrastructure; adds latency; current `load_when` filters already achieve similar targeting with zero infrastructure
- **Verdict**: "The current tiered system with `load_when` selectors is already close to optimal for a static context corpus. RAG only adds value if the context corpus becomes dynamic or very large (>500 files)."

**Conclusion**: Stay with the static index + tier system; don't implement RAG. The memory vault (`.memory/` with MCP-backed retrieval) handles the dynamic case.

## Teammate C's Caution on Context Budget Caps

"The 'context budget caps' proposal is interesting but unvalidated. If a sonnet worker agent regularly needs more than 8K tokens of context to complete its task correctly, imposing a cap will silently degrade output quality. There is no mechanism described for detecting or alerting on context budget violations."

**Mitigation**: Budget caps should log warnings, not hard errors, when exceeded. Track actual context usage per invocation and compare to caps after implementing. Adjust caps based on empirical data.

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 4 (Progressive disclosure), Synthesis (Task 598 priority elevated)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Finding 2 (Progressive disclosure context loading), full tier architecture
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 7 (Progressive disclosure, RAG alternative)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 2 (Token economics), Finding 8 (Progressive disclosure may add latency)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 4 (Scaling considerations, context loading), Finding 5 (Alternative B: dynamic retrieval)
