# Implementation Plan: Task #372

- **Task**: 372 - Create financial-analysis.typ template
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (strategy-template.typ exists)
- **Research Inputs**: specs/372_create_financial_analysis_typst_template/reports/01_financial-analysis-template.md
- **Artifacts**: plans/01_financial-analysis-template.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `financial-analysis.typ` in the founder extension templates directory, following the established pattern of importing `strategy-template.typ` and defining a document wrapper plus domain-specific components. The template mirrors the 12-section structure of `financial-analysis.md` while leveraging typst's professional styling. Research identified approximately 15 custom components needed (badges, tables, blocks) that compose base components from strategy-template.typ. The template is complete when it compiles without errors and covers all sections from the markdown template.

### Research Integration

The research report mapped all 12 markdown template sections to typst approaches, identified all reusable base components from strategy-template.typ, cataloged patterns from cost-breakdown.typ and contract-analysis.typ (conditional fill coloring, badge patterns, runway blocks), and recommended approximately 15 custom components. Key decisions: import only strategy-template.typ (no cross-template imports), use pure-parameter approach (no JSON data loading), and support both parameter-driven and inline-content usage modes.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create a complete `financial-analysis.typ` template with all 12 sections from the markdown template
- Follow the established template architecture (import strategy-template, document wrapper, domain components)
- Define approximately 15 custom components for financial health assessment, verification, ratio analysis, and scenario modeling
- Include example usage comment block

**Non-Goals**:
- Modifying strategy-template.typ or any other existing template
- Creating JSON data schemas or data loading mechanisms
- Implementing mode-conditional rendering logic (that is the agent's responsibility when populating)
- Adding new base components to strategy-template.typ

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Template exceeds 500 lines, becomes unwieldy | M | M | Keep components focused; reuse base components rather than rebuilding |
| Complex conditional fill coloring causes compile errors | M | L | Follow proven patterns from contract-analysis.typ and cost-breakdown.typ exactly |
| Badge color mappings miss edge cases | L | L | Use fallback colors for unknown values; document expected values in comments |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create template structure and core components [NOT STARTED]

**Goal**: Create the financial-analysis.typ file with document wrapper, badge components, and the first half of section components (sections 1-6: executive summary through ratio analysis).

**Tasks**:
- [ ] Create file with header comment block, import statement, and any additional color definitions
- [ ] Define `financial-analysis-doc` document wrapper with financial-specific parameters (project, date, mode, document-type) and title page metric pills
- [ ] Define `health-badge(level)` for financial health status (Healthy/Adequate/Concerning/Critical)
- [ ] Define `verification-badge(status)` for verification status (Verified/Supported/Unverified/Match/Discrepancy)
- [ ] Define `document-inventory-table(documents)` and `completeness-table(items)` for document inventory section
- [ ] Define `revenue-table(metrics)` for revenue analysis with trend indicators
- [ ] Define `expense-table(categories)` for expense breakdown
- [ ] Define `cash-position-block(...)` adapting runway-block pattern for cash position display
- [ ] Define `ratio-table(ratios)` with benchmark comparison and conditional coloring

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ` - Create new file

**Verification**:
- File exists with correct import statement
- Document wrapper follows market-sizing.typ pattern
- All components for sections 1-6 are defined
- Badge components use conditional coloring

---

### Phase 2: Complete remaining components and example usage [NOT STARTED]

**Goal**: Add components for sections 7-12 (verification through appendices) and include example usage comment block.

**Tasks**:
- [ ] Define `verification-matrix(items)` for cross-reference verification with match/discrepancy coloring
- [ ] Define `discrepancy-table(items)` for discrepancies with magnitude and status
- [ ] Define `scenario-comparison(scenarios)` for upside/base/downside scenarios, adapting scenario-table pattern
- [ ] Define `assumption-table(assumptions)` with confidence and sensitivity ratings
- [ ] Define `monitoring-table(metrics)` for monitoring plan with frequency and threshold triggers
- [ ] Define `interconnection-check(connections)` for statement interconnection checks with Pass/Fail badges
- [ ] Add example usage comment block showing both parameter-driven and inline-content patterns
- [ ] Add optional JSON data schema reference comment block
- [ ] Review complete file for consistency in naming, parameter patterns, and color usage

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ` - Add remaining components

**Verification**:
- All 12 markdown template sections have corresponding typst components
- Approximately 15 custom components defined
- Example usage block is present and demonstrates key patterns
- File follows same organizational structure as cost-breakdown.typ and market-sizing.typ

## Testing & Validation

- [ ] All 15 custom components are defined with correct parameter signatures
- [ ] Badge components handle all documented status values with appropriate colors
- [ ] Table components use conditional fill coloring following proven patterns
- [ ] Document wrapper accepts mode parameter and passes it to strategy-doc
- [ ] File follows established template architecture (header, import, colors, wrapper, components, example)
- [ ] Component naming is consistent (kebab-case, descriptive)

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/financial-analysis.typ` - The complete template file

## Rollback/Contingency

Since this creates a new file with no modifications to existing files, rollback is simply deleting the created file. No existing functionality is affected.
