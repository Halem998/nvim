# Implementation Plan: Spreadsheet Domain Context

- **Task**: 313 - spreadsheet_domain_context
- **Status**: [COMPLETED]
- **Effort**: 4-5 hours
- **Dependencies**: None (founder extension v3.0.0 exists)
- **Research Inputs**: specs/313_spreadsheet_domain_context/reports/02_team-research.md
- **Artifacts**: plans/02_sheet-system-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-formats.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a complete `/sheet` command-skill-agent system for the founder extension to generate cost breakdown spreadsheets with native Excel formulas. The system uses openpyxl for XLSX generation, exports metrics to JSON for Typst integration, and follows existing founder extension patterns for routing and context loading. Research confirms best approach: generate XLSX with formulas -> export key metrics to JSON -> Typst templates use `json()` for inline adaptive values.

### Research Integration

Integrated findings from `reports/02_team-research.md`:
- Use openpyxl for XLSX generation with native formulas
- Export summary metrics to JSON (preserves number types)
- Typst reads JSON at compile time via `#json()` function
- Financial modeling color conventions: blue=inputs, black=formulas

## Goals & Non-Goals

**Goals**:
- Create `/sheet` command with file path input support
- Build `skill-spreadsheet` skill following skill-market patterns
- Build `spreadsheet-agent` agent with forcing questions for cost categories
- Add context files for financial modeling domain knowledge
- Create Typst template for cost breakdown visualization with JSON integration
- Update manifest.json with routing entries for `founder:sheet` task type
- Update index-entries.json with context file discovery

**Non-Goals**:
- MCP server integration (defer to future task)
- Google Sheets support (XLSX only for v1)
- Formula validation via LibreOffice (manual verification acceptable)
- Live spreadsheet editing (generate-only workflow)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| openpyxl not installed | High | Low | Document pip install requirement; detect and warn |
| Complex formula errors | Medium | Medium | Use simple SUM/AVERAGE; avoid nested formulas |
| JSON export breaks Typst | Medium | Low | Test with sample data; validate JSON structure |
| Pattern drift from existing agents | Low | Medium | Follow market-agent structure exactly |

## Implementation Phases

### Phase 1: Domain Context Files [COMPLETED]

**Goal**: Create domain knowledge files for spreadsheet/cost modeling

**Tasks**:
- [ ] Create `context/project/founder/domain/spreadsheet-frameworks.md`
  - Cost breakdown structure (Categories, Line Items, Subtotals)
  - Financial modeling conventions (blue=inputs, black=formulas)
  - Common cost categories (Personnel, Infrastructure, Marketing, Operations, Legal)
  - Formula patterns (SUM, AVERAGE, percentage calculations)
- [ ] Create `context/project/founder/patterns/cost-forcing-questions.md`
  - Mode selection (ESTIMATE, BUDGET, FORECAST, ACTUALS)
  - Cost category forcing questions
  - Data quality assessment patterns

**Timing**: 1 hour

**Files to create**:
- `.claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md`
- `.claude/extensions/founder/context/project/founder/patterns/cost-forcing-questions.md`

**Verification**:
- Context files exist and are non-empty
- Follow existing domain/*.md structure

---

### Phase 2: Agent Definition [COMPLETED]

**Goal**: Create spreadsheet-agent following market-agent patterns

**Tasks**:
- [ ] Create `agents/spreadsheet-agent.md` with:
  - Allowed tools: AskUserQuestion, Read, Write, Glob, Bash
  - Context references to spreadsheet-frameworks.md and cost-forcing-questions.md
  - 8-stage execution flow matching market-agent
  - Mode selection (ESTIMATE, BUDGET, FORECAST, ACTUALS)
  - Forcing questions for cost categories and line items
  - XLSX generation using Python/openpyxl
  - JSON export for Typst integration
  - Research report output format

**Timing**: 1 hour

**Files to create**:
- `.claude/extensions/founder/agents/spreadsheet-agent.md`

**Verification**:
- Agent follows market-agent structure
- Includes all 9 stages (0-8) plus return format
- Context references are correct paths

---

### Phase 3: Skill Definition [COMPLETED]

**Goal**: Create skill-spreadsheet following skill-market patterns

**Tasks**:
- [ ] Create `skills/skill-spreadsheet/SKILL.md` with:
  - skill-internal postflight pattern
  - Input validation for task_number
  - Preflight status update to "researching"
  - Delegation context with forcing_data support
  - Task tool invocation of spreadsheet-agent
  - Postflight artifact linking and git commit

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md`

**Verification**:
- Skill follows skill-market structure exactly
- Uses Task tool (not Skill tool) for agent invocation
- Includes all 11 stages matching skill-market

---

### Phase 4: Command Definition [COMPLETED]

**Goal**: Create /sheet command following /market patterns

**Tasks**:
- [ ] Create `commands/sheet.md` with:
  - Input types: description, task number, file path, --quick flag
  - STAGE 0: Pre-task forcing questions (mode, cost categories, time period)
  - GATE IN: Session ID, input detection, task creation
  - STAGE 2: Delegate to skill-spreadsheet
  - GATE OUT: Verify research completed, display result
  - Error handling for missing files, abandoned questions

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/founder/commands/sheet.md`

**Verification**:
- Command follows /market structure
- Pre-task forcing questions before task creation
- Clear workflow: /sheet creates task -> /research -> /plan -> /implement

---

### Phase 5: Typst Template [COMPLETED]

**Goal**: Create Typst template for cost breakdown visualization with JSON data loading

**Tasks**:
- [ ] Create `templates/typst/cost-breakdown.typ` with:
  - JSON data loading via `#json("metrics.json")`
  - Cost breakdown table with categories and subtotals
  - Summary statistics section (total cost, category percentages)
  - Visual pie chart or bar representation
  - Inline adaptive values using `#variable` syntax
  - Integration with strategy-template.typ base styles

**Timing**: 45 minutes

**Files to create**:
- `.claude/extensions/founder/context/project/founder/templates/typst/cost-breakdown.typ`

**Verification**:
- Template compiles with sample JSON data
- Follows strategy-template.typ conventions
- Adaptive values work with `#json()` function

---

### Phase 6: Manifest and Index Updates [COMPLETED]

**Goal**: Register new components in manifest.json and index-entries.json

**Tasks**:
- [ ] Update `manifest.json`:
  - Add "spreadsheet-agent.md" to provides.agents
  - Add "skill-spreadsheet" to provides.skills
  - Add "sheet.md" to provides.commands
  - Add routing entries for founder:sheet in research, plan, implement
- [ ] Update `index-entries.json`:
  - Add entry for spreadsheet-frameworks.md
  - Add entry for cost-forcing-questions.md
  - Add entry for cost-breakdown.typ

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json`
- `.claude/extensions/founder/index-entries.json`

**Verification**:
- JSON files are valid
- New entries follow existing patterns
- Routing correctly maps founder:sheet -> skill-spreadsheet

---

### Phase 7: Testing and Documentation [COMPLETED]

**Goal**: Verify integration and document usage

**Tasks**:
- [ ] Test command parsing: `/sheet "Q1 cost breakdown"`
- [ ] Test forcing question flow (mode, categories, period)
- [ ] Test XLSX generation with openpyxl script
- [ ] Test JSON export structure
- [ ] Verify Typst template compiles with exported JSON
- [ ] Update EXTENSION.md with /sheet command documentation
- [ ] Add example usage to context/project/founder/README.md

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md`
- `.claude/extensions/founder/context/project/founder/README.md`

**Verification**:
- End-to-end workflow completes: /sheet -> /research -> /plan -> /implement
- XLSX file contains formulas (not computed values)
- JSON contains typed numbers (not strings)
- Typst PDF renders with correct values

## Testing & Validation

- [ ] `/sheet "test cost breakdown"` creates task with forcing_data
- [ ] Task routing uses skill-spreadsheet for research
- [ ] spreadsheet-agent asks forcing questions and creates research report
- [ ] XLSX output has native Excel formulas (verify with `openpyxl.load_workbook`)
- [ ] JSON export preserves number types (not strings)
- [ ] Typst template compiles and renders JSON values
- [ ] Context discovery finds new entries via jq query

## Artifacts & Outputs

Phase 1:
- `.claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md`
- `.claude/extensions/founder/context/project/founder/patterns/cost-forcing-questions.md`

Phase 2:
- `.claude/extensions/founder/agents/spreadsheet-agent.md`

Phase 3:
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md`

Phase 4:
- `.claude/extensions/founder/commands/sheet.md`

Phase 5:
- `.claude/extensions/founder/context/project/founder/templates/typst/cost-breakdown.typ`

Phase 6:
- `.claude/extensions/founder/manifest.json` (modified)
- `.claude/extensions/founder/index-entries.json` (modified)

Phase 7:
- `.claude/extensions/founder/EXTENSION.md` (modified)
- `.claude/extensions/founder/context/project/founder/README.md` (modified)

## Rollback/Contingency

If implementation fails:
1. Remove newly created files (agents/, skills/, commands/, context/ additions)
2. Revert manifest.json and index-entries.json to pre-modification state
3. No cleanup needed for EXTENSION.md or README.md (additions only)

Files are additive only; no existing functionality is modified. Safe to remove new files without affecting existing founder extension behavior.
