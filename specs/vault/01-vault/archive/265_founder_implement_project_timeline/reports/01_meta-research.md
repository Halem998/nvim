# Research Report: Task #265

**Task**: 265 - Add legal support to founder-implement-agent
**Generated**: 2026-03-24
**Source**: Codebase analysis of founder extension agents and templates
**Status**: Researched

---

## Context Summary

**Purpose**: Add contract-review type support to founder-implement-agent
**Scope**: .claude/extensions/founder/agents/founder-implement-agent.md
**Affected Components**: founder-implement-agent phase flow dispatch
**Domain**: founder extension
**Language**: meta

## Task Requirements

Add contract-review type support to founder-implement-agent:

1. Add `contract-review` to the report type detection logic (Stage 2)
2. Add contract-review phase flow (5 phases, parallel to existing market-sizing/competitive-analysis/gtm-strategy flows)
3. Add contract-analysis template reference (Stage 4)
4. Add typst template reference for contract-analysis (Phase 5)
5. Ensure resume support works for contract-review phases
6. Update summary and metadata patterns to include legal-specific fields

### Phase Flow: Contract Review

| Phase | Name | Description |
|-------|------|-------------|
| 1 | Clause-by-Clause Analysis | Parse contract from research report, identify all material clauses, categorize by type (financial, liability, IP, termination, data rights, governing law, etc.) |
| 2 | Risk Assessment Matrix | Score each clause by likelihood x impact, identify dealbreakers, classify into MUST FIX / NEGOTIATE / MONITOR / ACCEPT quadrants |
| 3 | Negotiation Strategy | BATNA/ZOPA analysis, prioritized redline list with proposed alternative language, fallback positions, escalation triggers |
| 4 | Report Generation | Generate `strategy/contract-analysis-{slug}.md` using contract-analysis template |
| 5 | Typst Document Generation | Generate `founder/contract-analysis-{slug}.typ` and compile PDF |

## Integration Points

- **Component Type**: agent specification (markdown)
- **Affected Area**: .claude/extensions/founder/agents/
- **Action Type**: extend (add new phase flow section)
- **Related Files**:
  - `.claude/extensions/founder/agents/founder-implement-agent.md` - Agent to modify
  - `.claude/extensions/founder/agents/legal-council-agent.md` - Research agent that produces input
  - `.claude/extensions/founder/context/project/founder/templates/contract-analysis.md` - Markdown report template
  - `.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ` - Typst template (exists)

## Findings

### Codebase Patterns

**Current implement agent structure** (from founder-implement-agent.md):

1. **Stage 2** detects report type from plan file. Currently supports: `market-sizing`, `competitive-analysis`, `gtm-strategy`. Need to add `contract-review`.

2. **Stage 4** loads report template by type. Current mapping table has 3 entries. Need to add:
   - `contract-review` -> `@.claude/extensions/founder/context/project/founder/templates/contract-analysis.md`

3. **Stage 5** executes phases by type. Each type has its own section with 3 type-specific phases + Phase 4 (Report Generation) + Phase 5 (Typst/PDF). Need to add a "Contract Review Phase Flow" section.

4. **Context References** section lists templates loaded. Need to add contract-analysis template and typst template.

5. **Phase 5 (Typst)** uses self-contained generation pattern (no imports). The existing `contract-analysis.typ` template file uses `#import "strategy-template.typ": *`, but the agent inlines all functions. Need to follow the same self-contained pattern for contract-review typst generation.

6. **Stage 6 (Summary)** uses report-type-specific key results. For market-sizing it shows TAM/SAM/SOM. For contract-review, key results should be: overall risk level, clause count, must-fix count, escalation recommendation.

7. **Stage 7 (Metadata)** includes report-type-specific fields. For contract-review: `risk_level`, `clauses_reviewed`, `must_fix_count`, `escalation_level`.

### Legal-Council-Agent Output Structure

The legal-council-agent (research phase) produces a report with these sections that the implement agent will consume:

- **Contract Context**: Contract type, parties, primary concerns (from Q1, Q2)
- **Negotiating Position**: Position assessment, specific focus areas (from Q3, Q4)
- **Financial and Exit**: Financial exposure, walk-away conditions, governing law, precedent (from Q5-Q8)
- **Mode-Specific Guidance**: REVIEW/NEGOTIATE/TERMS/DILIGENCE focus areas
- **Escalation Assessment**: Financial threshold, recommended escalation level
- **Red Flags to Investigate**: Contract-type-specific red flags

### Contract-Analysis Template Structure

The existing markdown template (`contract-analysis.md`) provides the output structure:

- Executive Summary (overall risk level, key concerns, recommended action)
- Contract Overview (parties, key terms summary)
- Clause-by-Clause Analysis (risk level per section, issues, recommendations)
- Risk Assessment Matrix (MUST FIX / NEGOTIATE / MONITOR / ACCEPT quadrants)
- Negotiation Position Summary (interests, BATNA, ZOPA, trade-offs)
- Recommended Modifications (must-have, should-have, nice-to-have)
- Walk-Away Conditions
- Action Items
- Escalation Recommendation

### Typst Template

The `contract-analysis.typ` file exists at `.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ`. It uses `#import "strategy-template.typ": *` but the implement agent should inline all functions (self-contained pattern, consistent with other report types).

The typst template defines:
- `contract-analysis-doc()` entry point (wraps `strategy-doc`)
- `risk-badge()` helper for risk level indicators
- `clause-card()` helper for clause analysis display
- Risk matrix visualization
- BATNA/ZOPA display components

## Dependencies

- **Task #264**: Add legal support to founder-plan-agent. The planner must know how to create contract-review plans before the implementer can execute them. Task 264 adds keyword detection and phase structure for contract-review to the plan agent.

The implementation agent needs:
1. The plan agent to produce properly structured contract-review plans (task #264)
2. Research reports from legal-council-agent (already functional)

## Implementation Outline

### Changes to founder-implement-agent.md

**1. Context References section** - Add 2 entries:
```
- `@.claude/extensions/founder/context/project/founder/templates/contract-analysis.md` - Contract analysis template
```
And in Phase 5 context:
```
- `@.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ` - Contract analysis typst template
```

**2. Stage 2 description** - Update report type list to include `contract-review`:
```
Report type (market-sizing, competitive-analysis, gtm-strategy, contract-review)
```

**3. Stage 4 template table** - Add row:
```
| contract-review | `@.../templates/contract-analysis.md` |
```

**4. New section: Contract Review Phase Flow** - Add after GTM Strategy Phase Flow:

```markdown
## Contract Review Phase Flow

### Phase 1: Clause-by-Clause Analysis
- Parse contract details from research report (### Contract Context, ### Negotiating Position)
- Identify all material clauses from the contract
- Categorize each clause: financial, liability, IP, termination, data rights, governing law, indemnification, force majeure, confidentiality
- Quote specific language for problematic clauses
- Note clauses missing from the contract that should be present

### Phase 2: Risk Assessment Matrix
- Score each identified clause by likelihood x impact
- Classify into quadrants: MUST FIX / NEGOTIATE / MONITOR / ACCEPT
- Identify dealbreakers based on walk-away conditions (from research: ### Financial and Exit)
- Create risk heat map summary
- Flag escalation items (from research: ### Escalation Assessment)

### Phase 3: Negotiation Strategy
- Develop BATNA analysis (from research: ### Negotiating Position)
- Map ZOPA for key negotiation dimensions
- Create prioritized redline list with proposed alternative language
- Define fallback positions for each must-have change
- Identify trade-off opportunities (give/get pairs)
- Set escalation triggers based on financial exposure

### Phase 4: Report Generation
- Full contract analysis report using contract-analysis.md template
- Include executive summary with overall risk level
- Include clause-by-clause analysis table
- Include risk matrix visualization
- Include negotiation position summary with BATNA/ZOPA
- Include recommended modifications (must-have, should-have, nice-to-have)
- Include walk-away conditions and action items
- Write to: `strategy/contract-analysis-{slug}.md`

### Phase 5: Typst Document Generation
- Generate self-contained typst file (inline all functions, no imports)
- Include risk badges, clause cards, risk matrix visualization
- Include BATNA/ZOPA display, modification tables
- Compile to PDF in founder/ directory
- Write to: `founder/contract-analysis-{slug}.typ` and `founder/contract-analysis-{slug}.pdf`
```

**5. Stage 6 (Summary)** - Add contract-review key results pattern:
```markdown
## Key Results

- Overall Risk Level: {Low|Medium|High|Critical}
- Clauses Reviewed: {count}
- Must-Fix Issues: {count}
- Escalation: {Self-serve|Attorney review|Attorney required}
```

**6. Stage 7 (Metadata)** - Add contract-review metadata fields:
```json
"risk_level": "{overall_risk}",
"clauses_reviewed": {count},
"must_fix_count": {count},
"escalation_level": "{self-serve|attorney-review|attorney-required}"
```

### Phase Data Flow

```
legal-council-agent (research)
  -> Research report with contract context, concerns, position, financials
    -> founder-plan-agent (planning, task #264)
      -> Plan with 5 phases for contract-review
        -> founder-implement-agent (this task)
          -> Phase 1: Clause analysis (uses research: Contract Context)
          -> Phase 2: Risk matrix (uses research: Red Flags, Financial Exposure)
          -> Phase 3: Negotiation (uses research: Negotiating Position, Walk-Away)
          -> Phase 4: Report generation (uses contract-analysis.md template)
          -> Phase 5: Typst/PDF (uses self-contained pattern)
```

## Effort Assessment

- **Estimated Effort**: 2-3 hours (Medium)
- **Complexity Notes**: Follows established patterns from existing phase flows. The contract-analysis template and typst template already exist. Main work is adding the new phase flow section and wiring up type detection. Parallel structure to existing flows reduces risk.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Phase flow doesn't match plan structure from task 264 | Medium | High | Coordinate phase names between plan agent (264) and implement agent (265) |
| Self-contained typst for contract analysis is complex | Low | Medium | Follow existing self-contained pattern from market-sizing; contract-analysis.typ has helpers to reference |
| Research report structure varies by legal-council-agent mode | Low | Medium | Phase 1 should handle all 4 modes (REVIEW/NEGOTIATE/TERMS/DILIGENCE) gracefully |

## Recommendations

1. **Implement after task 264** to ensure plan structure alignment
2. **Follow existing phase flow patterns exactly** - the competitive-analysis and gtm-strategy flows provide proven templates
3. **Reference contract-analysis.md template** for Phase 4 output structure
4. **Use self-contained typst pattern** (inline functions, no imports) consistent with other report types
5. **Include mode-aware behavior** - the 4 legal modes (REVIEW/NEGOTIATE/TERMS/DILIGENCE) should influence which sections are emphasized in the output

---

*This research report was rewritten to reflect the updated task scope: legal support instead of project timeline generation.*
*For deeper investigation, run `/research 265 [focus]` with a specific focus prompt.*
