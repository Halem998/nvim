# Research Report: Task #264

**Task**: 264 - Add legal support to founder-plan-agent
**Generated**: 2026-03-24
**Status**: Researched
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of founder-plan-agent.md and legal-council-agent.md
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- The founder-plan-agent currently supports 3 report types (market-sizing, competitive-analysis, gtm-strategy) but has NO support for legal/contract-review tasks
- Legal tasks that complete research via legal-council-agent will fail at `/plan` because no keyword detection or phase structure exists
- The fix requires adding keyword detection for legal terms and a new 5-phase contract-review plan structure
- A planning context file may be needed to guide the planner on legal-specific implementation plans

## Context and Scope

### Problem Statement

The founder-plan-agent reads research reports and determines report type by keyword matching. It then generates a phase structure appropriate for that report type. Currently only three types are supported:

| Keywords | Report Type |
|----------|-------------|
| `market`, `sizing`, `TAM`, `SAM`, `SOM` | market-sizing |
| `competitive`, `competitor`, `analysis` | competitive-analysis |
| `GTM`, `go-to-market`, `strategy`, `launch` | gtm-strategy |

When a legal task completes research (via legal-council-agent), the resulting research report contains contract-related terminology that matches NONE of these keyword sets. The agent falls back to market-sizing, which produces an incorrect plan structure for a legal task.

### Scope

- Primary file: `.claude/extensions/founder/agents/founder-plan-agent.md`
- Possible new file: `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md`
- Possible update: `.claude/extensions/founder/index-entries.json`

## Findings

### Codebase Patterns

#### founder-plan-agent.md Structure (Stage 4: Determine Report Type)

The agent uses a keyword-to-type mapping table at Stage 4 (lines 175-185). The table has three rows. The fallback behavior is: "Default to market-sizing if unclear." This fallback is wrong for legal tasks.

The agent also has report-type-specific parsing at Stage 3 (lines 107-173) with three sections:
- "For market-sizing reports" - extracts Problem Definition, Market Data, Geographic Scope, Capture Assumptions, Competitive Landscape
- "For competitive-analysis reports" - extracts Direct/Indirect Competitors, Positioning Dimensions, Strategic Observations
- "For gtm-strategy reports" - extracts Positioning Context, Channel Research, Launch Context, Metrics Framework

A fourth section is needed for contract-review reports.

#### founder-plan-agent.md Structure (Stage 5: Phase Structure by Report Type)

Lines 279-306 define the phase structures per report type. Each type has 5 phases with Phase 4 always being "Report Generation" and Phase 5 always being "Typst Document Generation". A fourth phase structure is needed for contract-review.

#### legal-council-agent.md Output Format

The legal-council-agent produces research reports (Stage 6, lines 200-276) with these sections that the plan agent needs to parse:

| Section | Key Data Points |
|---------|----------------|
| Contract Context | Contract Type, Parties, Primary Concerns |
| Negotiating Position | Position Assessment, Specific Focus Areas |
| Financial and Exit | Financial Exposure, Walk-Away Conditions, Governing Law, Precedent/Standard |
| Mode-Specific Guidance | REVIEW/NEGOTIATE/TERMS/DILIGENCE focus areas |
| Escalation Assessment | Financial Threshold, Recommended Escalation level |
| Red Flags to Investigate | Contract-type-specific red flags |
| Data Quality Assessment | Per-data-point quality ratings |

The research report also includes a `**Mode**` field (REVIEW, NEGOTIATE, TERMS, or DILIGENCE) that the plan agent should carry forward into the plan.

### Keyword Detection for Contract-Review

Recommended keywords for detecting legal/contract research reports:

| Keyword | Rationale |
|---------|-----------|
| `contract` | Appears in all legal-council-agent reports ("Contract Type", "Contract Context") |
| `legal` | Common descriptor for legal tasks |
| `review` | Part of "contract review" mode |
| `clause` | Appears in red flags and analysis sections |
| `liability` | Common legal concern term |
| `indemnification` | Contract-specific term unlikely to appear in business reports |
| `negotiat` | Covers "negotiating", "negotiation" - appears in Position section |

### Proposed Contract-Review Phase Structure

Based on analysis of what legal-council-agent produces and what a contract analysis implementation needs:

**Phase 1: Clause-by-Clause Analysis**
- Inputs: Contract Context, Primary Concerns, Specific Focus Areas from research
- Objectives: Identify all material clauses, categorize by type (IP, liability, termination, data rights, non-compete, etc.), map each clause to the stated concerns
- Outputs: Categorized clause inventory

**Phase 2: Risk Assessment Matrix**
- Inputs: Clause inventory, Financial Exposure, Walk-Away Conditions, Red Flags
- Objectives: Score each clause by likelihood x impact, identify dealbreakers based on walk-away conditions, flag clauses exceeding financial exposure threshold
- Outputs: Risk matrix with severity ratings

**Phase 3: Negotiation Strategy**
- Inputs: Negotiating Position, Mode-Specific Guidance, Escalation Assessment
- Objectives: BATNA/ZOPA analysis based on position assessment, define redline priorities (non-negotiable items), establish fallback positions for negotiable items
- Outputs: Negotiation playbook

**Phase 4: Report Generation**
- Inputs: All previous phase outputs
- Objectives: Synthesize into final contract analysis markdown report
- Outputs: `strategy/contract-review-{slug}.md`

**Phase 5: Typst Document Generation**
- Inputs: Markdown report from Phase 4
- Objectives: Generate professional PDF contract analysis
- Template: `.claude/extensions/founder/context/project/founder/templates/typst/contract-review.typ`
- Outputs: `founder/contract-review-{slug}.typ`, `founder/contract-review-{slug}.pdf`

### Research Report Parsing for Contract-Review

The plan agent Stage 3 needs a new section for parsing contract-review research reports:

```markdown
**For contract-review reports:**

### Contract Context
- **Contract Type**: {extract}
- **Parties**: {extract}
- **Primary Concerns**: {extract}

### Negotiating Position
- **Position Assessment**: {extract}
- **Specific Focus Areas**: {extract}

### Financial and Exit
- **Financial Exposure**: {extract}
- **Walk-Away Conditions**: {extract}
- **Governing Law**: {extract}
- **Precedent/Standard**: {extract}

### Escalation Assessment
- **Financial Threshold**: {extract}
- **Recommended Escalation**: {extract}

### Red Flags to Investigate
{extract list}
```

### Context File Consideration

A planning context file at `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md` would help the planner understand:
- How contract analysis differs from business analysis
- What makes a good clause-by-clause analysis
- BATNA/ZOPA framework definitions
- Risk scoring methodology (likelihood x impact matrix)
- Escalation thresholds and attorney referral criteria

This is optional for the initial implementation but recommended for quality output.

## Required Changes

### File 1: `.claude/extensions/founder/agents/founder-plan-agent.md`

1. **Stage 3** - Add contract-review report parsing section (after the gtm-strategy section)
2. **Stage 4** - Add keyword detection row to the table:
   - Keywords: `contract`, `legal`, `review`, `clause`, `liability`, `indemnification`, `negotiat`
   - Report Type: `contract-review`
3. **Stage 5** - Add contract-review phase structure:
   - Phase 1: Clause-by-Clause Analysis
   - Phase 2: Risk Assessment Matrix
   - Phase 3: Negotiation Strategy
   - Phase 4: Report Generation
   - Phase 5: Typst Document Generation
4. **Stage 5** - Update metadata report_type union to include `contract-review`
5. **Context References** - Add legal-frameworks.md or legal-planning.md if created

### File 2 (optional): `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md`

New context file with:
- Contract analysis methodology
- Risk scoring framework
- BATNA/ZOPA definitions
- Phase-specific guidance for the planner

### File 3 (conditional): `.claude/extensions/founder/index-entries.json`

If File 2 is created, add an index entry with:
- `load_when.agents: ["founder-plan-agent"]`
- `load_when.task_types: ["contract-review", "legal"]`
- Topics: contract analysis, legal planning, risk assessment

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Keyword collision with business reports | Low | Medium | Legal keywords (clause, liability, indemnification) are unlikely in market/competitive reports |
| Missing Typst template for contract-review | Medium | Low | Phase 5 already handles missing templates gracefully (skip with warning) |
| Escalation level not carried through to plan | Medium | Medium | Ensure plan includes escalation assessment from research report |
| Mode (REVIEW/NEGOTIATE/TERMS/DILIGENCE) not influencing phases | Low | Low | All modes use same phase structure; mode affects phase emphasis, not structure |

## Decisions

- Keyword detection should use the same pattern as existing types (substring matching in report content)
- Phase structure should follow the 5-phase convention with Phase 4 = Report Generation and Phase 5 = Typst Document Generation
- The fallback behavior ("Default to market-sizing if unclear") should remain but is acceptable since legal keywords are distinctive enough to match correctly
- Context file creation is recommended but not strictly required for the plan agent changes to work

---

*Research completed by codebase analysis of founder-plan-agent.md and legal-council-agent.md.*
