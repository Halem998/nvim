# Research Report: Task #330

**Task**: Create /finance command, skill, and agent
**Date**: 2026-03-31
**Language**: meta
**Focus**: Pattern analysis and design specification

## Summary

Comprehensive analysis of existing founder extension patterns to design the /finance command, skill-finance skill, and finance-agent. Examined all 6 existing commands, 8 skills, and 8 agents in the founder extension to extract the canonical structure.

## Findings

### Existing Pattern Analysis

All founder commands follow an identical structure:

1. **Frontmatter**: description, allowed-tools (Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion), argument-hint
2. **Input Types**: 4 input types (description string, task number, file path, --quick)
3. **Modes**: 4 modes per command (e.g., LAUNCH/SCALE/PIVOT/EXPAND for strategy)
4. **STAGE 0**: Pre-task forcing questions (4-5 questions, one at a time)
5. **CHECKPOINT 1: GATE IN**: Session ID, input detection, task creation, TODO.md update, git commit, display summary, STOP for new tasks
6. **STAGE 2: DELEGATE**: Legacy mode (--quick) and task workflow mode (existing task)
7. **CHECKPOINT 2: GATE OUT**: Verify research, get artifact, display result
8. **Error handling**: Task not found, file not found, research incomplete, user abandonment

### Finance Command Design

**Modes** (as specified):
| Mode | Posture | Focus |
|------|---------|-------|
| AUDIT | Verify numbers | Cross-check existing financials, find discrepancies |
| MODEL | Build models | Revenue/cost models, unit economics, scenarios |
| FORECAST | Project forward | Cash flow projection, runway, growth modeling |
| VALIDATE | Stress test | Sensitivity analysis, assumption testing, break-even |

**5 Forcing Questions**:
1. **Financial Document**: What financial document or data do you want analyzed? (existing spreadsheet, P&L, cap table, projections)
2. **Primary Objective**: What is the primary question you need answered? (verify numbers, build model, project runway, test assumptions)
3. **Time Horizon**: What time period are we analyzing? (historical quarter, fiscal year, 12-month projection, 3-year forecast)
4. **Key Assumptions**: What are your critical assumptions? (growth rate, churn rate, pricing, cost structure)
5. **Decision Context**: What decision does this analysis inform? (fundraise, hire, pivot, scale, cut costs)

### Skill Pattern (11-stage)

All founder skills follow this pattern:
1. Input Validation
2. Preflight Status Update (researching)
3. Create Postflight Marker
4. Prepare Delegation Context
5. Invoke Agent (via Task tool)
6. Parse Subagent Return
7. Update Task Status (postflight - researched)
8. Link Artifacts
9. Git Commit
10. Cleanup
11. Return Brief Summary

### Agent Pattern

All founder agents follow this pattern:
- Stage 0: Initialize Early Metadata
- Stage 1: Parse Delegation Context
- Stage 2: Mode Selection (if not pre-selected)
- Stages 3-5: Forcing Questions (grouped by topic)
- Stage 6+: Generate artifacts (report, XLSX if applicable, JSON metrics)
- Final stages: Write metadata file, return brief text summary

### Finance Agent Unique Capabilities

The finance agent differs from other founder agents in that it:
1. **Reads existing financial documents** - Analyzes uploaded spreadsheets, P&L statements, projections
2. **Creates verification spreadsheets** - XLSX with formulas that cross-check source numbers (similar to spreadsheet-agent pattern)
3. **Extracts and validates numbers** - Parses financial data, identifies discrepancies
4. **Builds models** - Revenue models, unit economics, scenario analysis

This combines patterns from:
- **legal-council-agent**: Document analysis + forcing questions
- **spreadsheet-agent**: XLSX generation with openpyxl + JSON metrics export

### Routing Integration

The finance command needs:
- `task_type: "finance"` in state.json
- Routing entry: `"founder:finance": "skill-finance"` in manifest.json
- Plan/implement routing uses shared `skill-founder-plan` and `skill-founder-implement`

### Files to Create

| File | Template Source | Key Adaptations |
|------|---------------|-----------------|
| `.claude/extensions/founder/commands/finance.md` | `legal.md` pattern | AUDIT/MODEL/FORECAST/VALIDATE modes, 5 forcing questions, financial-specific input detection |
| `.claude/extensions/founder/skills/skill-finance/SKILL.md` | `skill-legal/SKILL.md` pattern | Route to finance-agent, finance-specific validation |
| `.claude/extensions/founder/agents/finance-agent.md` | `spreadsheet-agent.md` + `legal-council-agent.md` | Document analysis, XLSX verification, JSON metrics export |

### Files to Modify

| File | Change |
|------|--------|
| `manifest.json` | Add finance-agent.md to agents, skill-finance to skills, finance.md to commands, routing entries |
| `EXTENSION.md` | Add skill-finance -> finance-agent row, /finance command row |
| `index-entries.json` | Add context entries for finance-agent (load financial-frameworks context) |

## Data Quality Assessment

| Aspect | Quality | Notes |
|--------|---------|-------|
| Command pattern | High | 6 commands analyzed, pattern is completely consistent |
| Skill pattern | High | All skills follow identical 11-stage pattern |
| Agent pattern | High | All agents follow early-metadata + forcing + artifacts pattern |
| Integration points | High | manifest.json, EXTENSION.md, index-entries.json all documented |
| Finance domain | Medium | Modes and questions designed based on task description; will need context files in task 331 |

## Recommendations

1. Follow the legal.md command pattern exactly (most recent and cleanest)
2. Follow skill-legal/SKILL.md for the skill (11-stage pattern)
3. Combine spreadsheet-agent (XLSX generation) and legal-council-agent (document analysis) patterns for the agent
4. Finance agent should reference context files that will be created in task 331 (financial-frameworks.md, financial-verification.md)
5. XLSX generation should use the same openpyxl color conventions as spreadsheet-agent

## Next Steps

Run `/plan 330` to create implementation plan using this research.
