# Implementation Plan: Financial Analysis Typst Template with Spreadsheet Integration

- **Task**: 372 - Create financial-analysis.typ template
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None (strategy-template.typ, cost-breakdown.typ, spreadsheet-agent already exist)
- **Research Inputs**: specs/372_create_financial_analysis_typst_template/reports/01_financial-analysis-template.md, specs/372_create_financial_analysis_typst_template/reports/02_financial-spreadsheet-integration.md
- **Artifacts**: plans/02_financial-spreadsheet-integration.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/formats/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a complete financial analysis pipeline for the founder extension: a Typst template that loads financial-metrics.json at compile time for all numerical data, a forcing questions pattern for the spreadsheet agent to gather real numbers, and routing integration via manifest.json. The template follows cost-breakdown.typ's proven JSON-consumption pattern while covering the 12 sections of the existing financial-analysis.md markdown template (revenue, expenses, cash, ratios, verification, red flags, scenarios, recommendations). All numerical values come from JSON data, eliminating hallucinated figures.

### Research Integration

- Report 01 identified 15 custom components needed, mapped all 12 markdown template sections to Typst approaches, and catalogued reusable base components from strategy-template.typ
- Report 02 confirmed the cost-breakdown.typ JSON-loading pattern (`let data = json(data-file)`) as the model, designed the financial-metrics.json schema, and recommended Option C (separate financial-analysis agent/skill) for routing
- Report 01 Decision 4 originally said "No JSON data loading" but Report 02 explicitly overrides this: the template MUST load JSON at compile time to prevent hallucinated numbers

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create financial-analysis.typ that loads financial-metrics.json and renders all sections using strategy-template.typ base components
- Define a complete financial-metrics.json schema covering revenue, expenses, cash position, ratios, and scenarios
- Create financial-analysis forcing questions pattern for structured data gathering
- Add `founder:financial-analysis` routing key to manifest.json with supporting skill and agent files
- Follow cost-breakdown.typ architectural pattern exactly (JSON at compile time, parameterized doc wrapper)

**Non-Goals**:
- Building the XLSX spreadsheet generation logic (reuses existing spreadsheet-agent pattern)
- Implementing conditional section rendering based on mode (agent responsibility, not template responsibility)
- Creating actual financial analysis reports (template only)
- Modifying existing skills or agents (cost-breakdown, finance, spreadsheet)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Template exceeds 500 lines, becoming hard to maintain | M | M | Keep components focused; reuse base components rather than rebuilding |
| Typst compilation errors from complex conditional fill logic | M | L | Follow exact patterns proven in cost-breakdown.typ and contract-analysis.typ |
| financial-metrics.json schema doesn't cover all template sections | H | L | Design schema bottom-up from markdown template sections; validate coverage before implementation |
| Forcing questions too numerous (12+ sections vs 8 for cost-breakdown) | M | M | Group questions by domain; use ESTIMATE mode with fewer required fields |
| Routing integration breaks existing founder extension routes | H | L | Only add new keys; never modify existing routing entries |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create financial-analysis.typ Template [NOT STARTED]

**Goal**: Build the Typst template file with document wrapper, all custom components, and JSON data consumption following cost-breakdown.typ pattern.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ`
- [ ] Import strategy-template.typ and define additional color constants for financial analysis (health-green, warning-amber, critical-red, etc.)
- [ ] Implement `financial-doc` document wrapper function accepting `title`, `project`, `date`, `mode`, `data-file` parameters; load JSON via `let data = json(data-file)` inside wrapper
- [ ] Implement badge components: `health-badge(level)` for Healthy/Adequate/Concerning/Critical, `verification-badge(status)` for Verified/Supported/Unverified/Match/Discrepancy
- [ ] Implement `financial-summary-cards(data)` for executive summary metric display (ARR, MRR, cash balance, runway)
- [ ] Implement `document-inventory-table(documents)` and `completeness-table(items)` for document inventory section
- [ ] Implement `revenue-table(metrics)` with trend indicators and verification source column
- [ ] Implement `expense-table(categories)` for expense breakdown (monthly, annual, % of total, trend)
- [ ] Implement `cash-position-block(data)` adapting runway-block pattern for broader cash position display
- [ ] Implement `ratio-table(ratios)` with benchmark comparison and conditional coloring (healthy/watch/concerning)
- [ ] Implement `startup-metrics-table(metrics)` for Rule of 40, Magic Number, LTV:CAC, etc.
- [ ] Implement `verification-matrix(items)` for cross-reference verification with match/discrepancy coloring
- [ ] Implement `discrepancy-table(items)` for discrepancies with magnitude and status
- [ ] Implement `scenario-comparison(scenarios)` for upside/base/downside with key driver column
- [ ] Implement `assumption-table(assumptions)` with confidence and sensitivity ratings
- [ ] Implement `monitoring-table(metrics)` for monitoring plan with frequency and threshold triggers
- [ ] Add example usage comment block showing how to use template with JSON data
- [ ] Add JSON data schema reference comment block documenting expected financial-metrics.json structure

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ` - Create new file (~400-500 lines)

**Verification**:
- File exists and follows cost-breakdown.typ structural pattern (import, colors, doc wrapper, components, example, schema reference)
- All 15 custom components from research report 01 are implemented
- Document wrapper loads JSON via `json(data-file)` call
- All numerical display components read from data parameter, not hardcoded values
- Example usage section shows complete template invocation with JSON data access

---

### Phase 2: Create Financial Analysis Forcing Questions Pattern [NOT STARTED]

**Goal**: Create a structured forcing questions document for the spreadsheet agent to gather real financial data via AskUserQuestion, covering all sections of the financial analysis template.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/patterns/financial-analysis-forcing-questions.md`
- [ ] Define mode selection question (REVIEW/DILIGENCE/AUDIT/FORECAST) following cost-forcing-questions.md pattern
- [ ] Define scope questions: time period, entity, currency, document type
- [ ] Define revenue forcing questions: ARR/annual revenue, MRR, growth rate YoY, revenue concentration (top customer %), recurring vs one-time split, revenue quality assessment
- [ ] Define expense forcing questions: personnel costs by role (reuse Q2 from cost-forcing-questions), infrastructure costs (reuse Q3), marketing/sales spend by channel with CAC, operations/overhead line items
- [ ] Define cash position forcing questions: current cash balance with date, monthly net burn, gross burn, restricted cash, recent funding events
- [ ] Define ratio/metric inputs: gross margin %, operating margin %, current ratio, quick ratio, debt-to-equity, net dollar retention, CAC payback months, LTV estimate
- [ ] Define scenario questions: upside/base/downside revenue assumptions, expense assumptions, key drivers for each scenario
- [ ] Define verification questions: available source documents, known discrepancies, cross-reference data
- [ ] Add push-back patterns table for vague financial answers (following cost-forcing-questions.md pattern)
- [ ] Add smart routing by mode table (REVIEW = key metrics only; DILIGENCE = full detail; AUDIT = verification focus; FORECAST = scenarios + assumptions)
- [ ] Add data quality assessment criteria per section
- [ ] Document the financial-metrics.json output schema inline (canonical schema definition)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/patterns/financial-analysis-forcing-questions.md` - Create new file (~300 lines)

**Verification**:
- File follows cost-forcing-questions.md structural pattern (mode selection, core questions, push-back patterns, data quality, output format)
- All numerical sections from financial-analysis.md template are covered by forcing questions
- JSON output schema matches the data structure consumed by financial-analysis.typ
- Push-back patterns cover common vague financial answers
- Mode routing table defines which questions to skip/minimize per mode

---

### Phase 3: Create financial-analysis.typ Example JSON Data File [NOT STARTED]

**Goal**: Create a sample financial-metrics.json file that validates the schema and can be used for template testing/demonstration.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/templates/typst/financial-metrics-example.json` with realistic sample data
- [ ] Include all top-level sections: metadata, revenue, expenses, cash, ratios, scenarios, verification, documents
- [ ] Populate with realistic but clearly fictional startup data (e.g., "Acme SaaS" with $2.4M ARR)
- [ ] Ensure all fields referenced by financial-analysis.typ components are present
- [ ] Validate JSON syntax

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/financial-metrics-example.json` - Create new file (~120 lines)

**Verification**:
- Valid JSON that parses without errors
- All fields referenced in financial-analysis.typ are present
- Numerical values are numbers (not strings)
- Data is internally consistent (e.g., expense percentages sum to ~100%, runway = cash / burn)

---

### Phase 4: Routing Integration - Manifest, Skill, and Agent [NOT STARTED]

**Goal**: Add `founder:financial-analysis` routing to manifest.json and create the supporting skill and agent files so `/research` on financial analysis tasks produces XLSX + JSON metrics.

**Tasks**:
- [ ] Create `.claude/extensions/founder/agents/financial-analysis-agent.md` following spreadsheet-agent.md pattern but with financial-analysis-specific forcing questions, JSON export schema, and dual output (XLSX + financial-metrics.json)
- [ ] Create `.claude/extensions/founder/skills/skill-financial-analysis/SKILL.md` following skill-spreadsheet pattern: thin wrapper that routes to financial-analysis-agent via Task tool, handles preflight/postflight status updates
- [ ] Update `.claude/extensions/founder/manifest.json`:
  - Add `"founder:financial-analysis": "skill-financial-analysis"` to `routing.research`
  - Add `"founder:financial-analysis": "skill-founder-plan"` to `routing.plan`
  - Add `"founder:financial-analysis": "skill-founder-implement"` to `routing.implement`
  - Add `"financial-analysis-agent.md"` to `provides.agents`
  - Add `"skill-financial-analysis"` to `provides.skills`
- [ ] In the agent file, reference the financial-analysis-forcing-questions.md pattern as always-load context
- [ ] In the agent file, define the JSON export stage that produces financial-metrics.json matching the schema consumed by financial-analysis.typ
- [ ] In the agent file, define the XLSX generation stage using Python/openpyxl with financial analysis worksheets (Revenue, Expenses, Cash Flow, Ratios, Scenarios)

**Timing**: 2 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/founder/agents/financial-analysis-agent.md` - Create new file (~400 lines)
- `.claude/extensions/founder/skills/skill-financial-analysis/SKILL.md` - Create new file (~250 lines)
- `.claude/extensions/founder/manifest.json` - Add routing entries, agent, and skill to provides lists

**Verification**:
- manifest.json remains valid JSON after edits
- All three routing sections (research, plan, implement) have `founder:financial-analysis` entries
- Agent file references financial-analysis-forcing-questions.md and defines complete execution flow (forcing questions -> XLSX -> JSON -> report)
- Skill file follows skill-spreadsheet pattern with preflight/postflight lifecycle
- Agent and skill are listed in manifest.json provides arrays
- No existing routing entries are modified

---

## Testing & Validation

- [ ] financial-analysis.typ follows cost-breakdown.typ structural pattern (import, doc wrapper with JSON load, components, example)
- [ ] All 12 sections from financial-analysis.md markdown template have corresponding Typst components
- [ ] financial-metrics-example.json contains all fields referenced by template components
- [ ] manifest.json is valid JSON with correct routing for `founder:financial-analysis`
- [ ] financial-analysis-forcing-questions.md covers all numerical sections of the template
- [ ] JSON schema in forcing questions matches the structure consumed by the Typst template
- [ ] No existing files are broken (only new files created + manifest.json additive edits)

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ` - Typst template
- `.claude/extensions/founder/context/project/founder/templates/typst/financial-metrics-example.json` - Example JSON data
- `.claude/extensions/founder/context/project/founder/patterns/financial-analysis-forcing-questions.md` - Forcing questions pattern with JSON schema
- `.claude/extensions/founder/agents/financial-analysis-agent.md` - Spreadsheet-style agent for financial analysis
- `.claude/extensions/founder/skills/skill-financial-analysis/SKILL.md` - Routing skill wrapper
- `.claude/extensions/founder/manifest.json` - Updated routing table (additive changes only)

## Rollback/Contingency

All changes are additive (new files + manifest.json additions). To rollback:
1. Delete the five new files listed in Artifacts
2. Remove the three `founder:financial-analysis` routing entries from manifest.json
3. Remove `financial-analysis-agent.md` from `provides.agents` and `skill-financial-analysis` from `provides.skills` in manifest.json
