# Implementation Plan: Add legal support to founder-plan-agent

- **Task**: 264 - Add legal support to founder-plan-agent
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/264_project_planning_context/reports/01_meta-research.md
- **Artifacts**: plans/01_legal-plan-support.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The founder-plan-agent currently supports three report types (market-sizing, competitive-analysis, gtm-strategy) but has no support for legal/contract-review tasks. Legal tasks that complete research via legal-council-agent fail at the planning stage because no keyword detection or phase structure exists. This plan adds contract-review as a fourth report type with keyword detection, research report parsing, and a 5-phase plan structure.

### Research Integration

Research report `01_meta-research.md` provided:
- Complete keyword list for contract-review detection (7 keywords)
- Proposed 5-phase structure aligned with existing Phase 4/5 conventions
- Research report parsing template for legal-council-agent output sections
- Risk analysis showing low keyword collision risk with existing report types

## Goals & Non-Goals

**Goals**:
- Add contract-review keyword detection to Stage 4 keyword table
- Add contract-review research report parsing to Stage 3
- Add contract-review 5-phase plan structure to Stage 5
- Optionally create a legal-planning context file for plan quality guidance

**Non-Goals**:
- Modifying legal-council-agent output format
- Adding Typst template for contract-review (separate concern)
- Changing the fallback behavior (default to market-sizing)
- Adding mode-specific phase structures (REVIEW/NEGOTIATE/TERMS/DILIGENCE all use the same structure)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Keyword collision with business reports | Medium | Low | Legal keywords (clause, liability, indemnification) are distinctive |
| Missing Typst template at runtime | Low | Medium | Phase 5 already handles missing templates gracefully |
| Escalation level lost during planning | Medium | Medium | Ensure plan includes escalation assessment extraction |
| Incorrect parsing of legal-council-agent output | Medium | Low | Template based directly on agent Stage 6 output format |

## Implementation Phases

### Phase 1: Add keyword detection and report parsing [COMPLETED]

**Goal**: Enable founder-plan-agent to recognize contract-review research reports and extract structured data from them.

**Tasks**:
- [ ] Add contract-review row to Stage 4 keyword detection table with keywords: `contract`, `legal`, `review`, `clause`, `liability`, `indemnification`, `negotiat`
- [ ] Add "For contract-review reports" parsing section to Stage 3 after the gtm-strategy section
- [ ] Include extraction fields: Contract Context (Type, Parties, Primary Concerns), Negotiating Position (Assessment, Focus Areas), Financial and Exit (Exposure, Walk-Away Conditions, Governing Law, Precedent), Escalation Assessment (Threshold, Recommended level), Red Flags to Investigate
- [ ] Update metadata report_type union to include `contract-review`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Stage 3 parsing section, Stage 4 keyword table, metadata union

**Verification**:
- Keyword table has 4 rows (market-sizing, competitive-analysis, gtm-strategy, contract-review)
- Stage 3 has 4 parsing sections matching the 4 report types
- Metadata type union includes contract-review

---

### Phase 2: Add contract-review phase structure [COMPLETED]

**Goal**: Define the 5-phase plan structure that founder-plan-agent generates for contract-review tasks.

**Tasks**:
- [ ] Add contract-review phase structure to Stage 5 after existing report types
- [ ] Phase 1: Clause-by-Clause Analysis - inputs from Contract Context and Focus Areas, outputs categorized clause inventory
- [ ] Phase 2: Risk Assessment Matrix - inputs from clause inventory, Financial Exposure, Walk-Away Conditions, Red Flags; outputs risk matrix with severity ratings
- [ ] Phase 3: Negotiation Strategy - inputs from Negotiating Position, Mode-Specific Guidance, Escalation Assessment; outputs negotiation playbook with BATNA/ZOPA analysis
- [ ] Phase 4: Report Generation - synthesize into contract analysis markdown report at `strategy/contract-review-{slug}.md`
- [ ] Phase 5: Typst Document Generation - generate PDF using `contract-review.typ` template at `founder/contract-review-{slug}.typ`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Stage 5 phase structures section

**Verification**:
- Stage 5 has 4 report-type phase structures
- Contract-review follows the Phase 4 = Report Generation, Phase 5 = Typst convention
- Each phase has clear inputs, objectives, and outputs

---

### Phase 3: Create legal-planning context file [COMPLETED]

**Goal**: Provide domain knowledge for the plan agent to generate higher-quality contract analysis plans.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md` with:
  - Contract analysis methodology overview
  - BATNA/ZOPA framework definitions for Phase 3
  - Risk scoring methodology (likelihood x impact matrix) for Phase 2
  - Escalation thresholds and attorney referral criteria
  - Clause categorization taxonomy (IP, liability, termination, data rights, non-compete)
- [ ] Add index entry to `.claude/extensions/founder/index-entries.json` with:
  - `load_when.agents: ["founder-plan-agent"]`
  - `load_when.task_types: ["contract-review", "legal"]`
  - Topics: contract analysis, legal planning, risk assessment
- [ ] Add context reference to founder-plan-agent.md pointing to the new file

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md`

**Files to modify**:
- `.claude/extensions/founder/index-entries.json` - new index entry
- `.claude/extensions/founder/agents/founder-plan-agent.md` - context references section

**Verification**:
- Context file exists and covers all listed topics
- Index entry correctly targets founder-plan-agent and legal task types
- Agent references the context file in its context loading section

## Testing & Validation

- [ ] Verify founder-plan-agent.md has 4 keyword detection rows in Stage 4
- [ ] Verify Stage 3 has contract-review parsing section with all legal-council-agent output fields
- [ ] Verify Stage 5 has contract-review phase structure with 5 phases
- [ ] Verify Phase 4 and Phase 5 follow the existing convention (Report Generation, Typst Generation)
- [ ] Verify legal-planning.md context file contains BATNA/ZOPA definitions and risk scoring methodology
- [ ] Verify index-entries.json has valid entry for the new context file
- [ ] Verify no syntax errors in modified markdown files

## Artifacts & Outputs

- `plans/01_legal-plan-support.md` (this file)
- `.claude/extensions/founder/agents/founder-plan-agent.md` (modified - 3 sections updated)
- `.claude/extensions/founder/context/project/founder/patterns/legal-planning.md` (new)
- `.claude/extensions/founder/index-entries.json` (modified - new entry)

## Rollback/Contingency

All changes are additive (new table rows, new sections, new files). Rollback by removing:
1. The contract-review row from Stage 4 keyword table
2. The "For contract-review reports" section from Stage 3
3. The contract-review phase structure from Stage 5
4. The `legal-planning.md` context file and its index entry
5. The context reference from the agent file

No existing functionality is modified, so rollback carries no risk of breaking current report types.
