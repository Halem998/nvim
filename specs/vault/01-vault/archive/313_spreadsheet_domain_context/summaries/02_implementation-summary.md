# Implementation Summary: Task #313

**Completed**: 2026-03-27
**Duration**: ~45 minutes
**Session**: sess_1774668600_a7e4c3

## Changes Made

Created complete `/sheet` command-skill-agent system for the founder extension to generate cost breakdown spreadsheets with native Excel formulas. The system follows existing founder extension patterns and includes:

1. **Domain context files** for spreadsheet/cost modeling knowledge
2. **spreadsheet-agent** for cost research with forcing questions
3. **skill-spreadsheet** as thin routing wrapper
4. **/sheet command** with pre-task forcing questions
5. **Typst template** for cost breakdown PDF generation with JSON data loading
6. **Manifest and index updates** for routing and context discovery

## Files Created

- `.claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md` (288 lines)
  - Cost breakdown structure, financial modeling conventions
  - Formula patterns (SUM, AVERAGE, conditionals)
  - openpyxl code examples for XLSX generation
  - JSON export schema for Typst integration

- `.claude/extensions/founder/context/project/founder/patterns/cost-forcing-questions.md` (315 lines)
  - Mode selection (ESTIMATE, BUDGET, FORECAST, ACTUALS)
  - 8 forcing questions for cost data collection
  - Push-back patterns for vague answers
  - Data quality assessment framework

- `.claude/extensions/founder/agents/spreadsheet-agent.md` (578 lines)
  - 11-stage execution flow
  - Forcing questions for scope, personnel, infrastructure, marketing, operations
  - XLSX generation with Python/openpyxl
  - JSON export for Typst integration
  - Research report output

- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md` (339 lines)
  - skill-internal postflight pattern
  - Task tool invocation of spreadsheet-agent
  - Artifact linking for spreadsheet, metrics, and report

- `.claude/extensions/founder/commands/sheet.md` (506 lines)
  - Input types: description, task number, file path, --quick
  - STAGE 0 pre-task forcing questions
  - Task workflow and legacy standalone modes

- `.claude/extensions/founder/context/project/founder/templates/typst/cost-breakdown.typ` (414 lines)
  - JSON data loading via `#json()` function
  - Cost summary cards, category tables, line item tables
  - Category percentage bar visualization
  - Contingency block, runway calculator
  - Data quality indicators

## Files Modified

- `.claude/extensions/founder/manifest.json`
  - Added spreadsheet-agent.md to provides.agents
  - Added skill-spreadsheet to provides.skills
  - Added sheet.md to provides.commands
  - Added founder:sheet routing for research, plan, implement

- `.claude/extensions/founder/index-entries.json`
  - Added entries for spreadsheet-frameworks.md, cost-forcing-questions.md, cost-breakdown.typ
  - Configured load_when for spreadsheet-agent, /sheet command

- `.claude/extensions/founder/EXTENSION.md`
  - Added skill-spreadsheet to skill-agent mapping table
  - Added /sheet to commands table
  - Added spreadsheet-frameworks.md to context list

- `.claude/extensions/founder/context/project/founder/README.md`
  - Updated directory structure with new files
  - Added /sheet to related commands table

## Verification

- All 8 files created successfully
- JSON files validated (jq empty passes)
- Routing entries follow existing patterns
- Index entries include correct load_when conditions

## System Design

The /sheet system follows the established founder extension pattern:

```
/sheet "description"   -> STAGE 0: forcing questions -> create task -> [NOT STARTED]
/research {N}          -> skill-spreadsheet -> spreadsheet-agent -> [RESEARCHED]
                          - Generates: cost-breakdown.xlsx, cost-metrics.json, research report
/plan {N}              -> skill-founder-plan -> founder-plan-agent -> [PLANNED]
/implement {N}         -> skill-founder-implement -> founder-implement-agent -> [COMPLETED]
                          - Generates: strategy/cost-analysis-*.pdf using cost-breakdown.typ
```

## Notes

- openpyxl is required for XLSX generation (`pip install openpyxl`)
- JSON export preserves number types for Typst math operations
- Typst template imports strategy-template.typ for consistent styling
- Financial modeling color conventions applied (blue=inputs, black=formulas)
