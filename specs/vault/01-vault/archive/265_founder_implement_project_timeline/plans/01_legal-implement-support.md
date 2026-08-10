# Implementation Plan: Add legal support to founder-implement-agent

- **Task**: 265 - Add legal support to founder-implement-agent
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task #264 (legal support for founder-plan-agent)
- **Research Inputs**: specs/265_founder_implement_project_timeline/reports/01_meta-research.md
- **Artifacts**: plans/01_legal-implement-support.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add contract-review type support to founder-implement-agent.md so that legal tasks researched via legal-council-agent and planned via founder-plan-agent (task #264) can be executed through the standard /implement workflow. The work involves extending the existing type detection, template mapping, phase flow dispatch, summary, and metadata sections to handle a new contract-review report type with a 5-phase flow. All changes are confined to a single agent specification file and follow the established patterns from the existing market-sizing, competitive-analysis, and gtm-strategy flows.

### Research Integration

Key findings from the research report (01_meta-research.md):

- The implement agent has 7 integration points that need contract-review additions: Stage 2 type detection, Stage 4 template mapping, Stage 5 phase flow, Stage 6 summary, Stage 7 metadata, context references, and resume support.
- The contract-analysis.md template and contract-analysis.typ template already exist, so no new template files are needed.
- Phase 5 (Typst) must use the self-contained generation pattern (inline all functions, no imports), consistent with other report types.
- The legal-council-agent produces structured output with sections for Contract Context, Negotiating Position, Financial and Exit, Mode-Specific Guidance, Escalation Assessment, and Red Flags.

## Goals & Non-Goals

**Goals**:
- Add contract-review to the report type detection logic in Stage 2
- Add contract-analysis template reference to Stage 4 mapping table
- Add a complete 5-phase contract-review flow in Stage 5
- Add contract-review key results pattern to Stage 6 summary
- Add contract-review metadata fields to Stage 7
- Add context references for contract-analysis templates
- Ensure resume support handles contract-review phases

**Non-Goals**:
- Modifying the legal-council-agent (research phase, already functional)
- Modifying the founder-plan-agent (handled by task #264)
- Creating new template files (contract-analysis.md and contract-analysis.typ already exist)
- Adding new legal modes beyond the existing 4 (REVIEW/NEGOTIATE/TERMS/DILIGENCE)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase names mismatch with plan agent (task 264) | High | Medium | Coordinate phase names: use identical names from research report phase flow table |
| Self-contained typst generation is complex | Medium | Low | Follow existing market-sizing self-contained pattern; reference contract-analysis.typ for helper functions |
| Research report structure varies by legal mode | Medium | Low | Phase 1 instructions must handle all 4 modes gracefully; use conditional language |
| Task 264 not yet implemented | High | Known | This plan can be created now but implementation must wait for task 264 completion |

## Implementation Phases

### Phase 1: Type Detection and Template Mapping [COMPLETED]

**Goal**: Wire up contract-review as a recognized report type with its template reference.

**Tasks**:
- [ ] Add `contract-review` to Stage 2 report type detection list (alongside market-sizing, competitive-analysis, gtm-strategy)
- [ ] Add contract-review row to Stage 4 template mapping table: `contract-review` -> `@.claude/extensions/founder/context/project/founder/templates/contract-analysis.md`
- [ ] Add context references for contract-analysis template (markdown) and typst template
- [ ] Verify the keyword detection pattern matches what task 264 uses in the plan agent

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Stage 2, Stage 4, Context References sections

**Verification**:
- Stage 2 lists 4 report types including contract-review
- Stage 4 template table has 4 entries
- Context References section includes both contract-analysis templates

---

### Phase 2: Contract Review Phase Flow (Phases 1-3) [COMPLETED]

**Goal**: Add the analysis-focused phases of the contract-review flow (Clause-by-Clause Analysis, Risk Assessment Matrix, Negotiation Strategy).

**Tasks**:
- [ ] Add "Contract Review Phase Flow" section after the GTM Strategy Phase Flow section
- [ ] Write Phase 1 (Clause-by-Clause Analysis): parse contract from research report, identify material clauses, categorize by type (financial, liability, IP, termination, data rights, governing law, indemnification, force majeure, confidentiality), quote problematic language, note missing clauses
- [ ] Write Phase 2 (Risk Assessment Matrix): score clauses by likelihood x impact, classify into MUST FIX / NEGOTIATE / MONITOR / ACCEPT quadrants, identify dealbreakers from walk-away conditions, create risk heat map summary, flag escalation items
- [ ] Write Phase 3 (Negotiation Strategy): BATNA analysis, ZOPA mapping, prioritized redline list with proposed alternative language, fallback positions, trade-off opportunities (give/get pairs), escalation triggers
- [ ] Include references to which research report sections each phase consumes (Contract Context, Negotiating Position, Financial and Exit, Red Flags, Escalation Assessment)
- [ ] Include mode-aware behavior notes (REVIEW/NEGOTIATE/TERMS/DILIGENCE affect emphasis)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - New section in Stage 5

**Verification**:
- Three analysis phases are documented with clear instructions
- Each phase references specific research report sections as input
- Mode-aware behavior is described

---

### Phase 3: Contract Review Phase Flow (Phases 4-5) [COMPLETED]

**Goal**: Add the output-generation phases: Report Generation and Typst/PDF compilation.

**Tasks**:
- [ ] Write Phase 4 (Report Generation): generate contract analysis report using contract-analysis.md template, include executive summary with overall risk level, clause-by-clause analysis table, risk matrix visualization, negotiation position summary with BATNA/ZOPA, recommended modifications (must-have/should-have/nice-to-have), walk-away conditions, action items, escalation recommendation; output path: `strategy/contract-analysis-{slug}.md`
- [ ] Write Phase 5 (Typst Document Generation): generate self-contained typst file (inline all functions, no imports), include risk badges, clause cards, risk matrix visualization, BATNA/ZOPA display, modification tables; compile to PDF; output paths: `founder/contract-analysis-{slug}.typ` and `founder/contract-analysis-{slug}.pdf`
- [ ] Reference the typst self-contained pattern used by existing report types
- [ ] List the typst helper functions to inline: `contract-analysis-doc()`, `risk-badge()`, `clause-card()`, risk matrix visualization, BATNA/ZOPA display components

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Continue Stage 5 section

**Verification**:
- Phase 4 references the contract-analysis.md template structure
- Phase 5 uses self-contained typst pattern (no imports)
- Output paths are specified for both markdown report and typst/PDF

---

### Phase 4: Summary, Metadata, and Resume Support [COMPLETED]

**Goal**: Add contract-review patterns to the summary, metadata, and resume sections.

**Tasks**:
- [ ] Add contract-review key results pattern to Stage 6 (Summary): Overall Risk Level, Clauses Reviewed count, Must-Fix Issues count, Escalation recommendation
- [ ] Add contract-review metadata fields to Stage 7: `risk_level`, `clauses_reviewed`, `must_fix_count`, `escalation_level`
- [ ] Verify resume support section handles contract-review phases (the existing resume logic should work generically, but confirm contract-review is listed in any type-specific resume handling)
- [ ] Verify the phase numbering and naming is consistent across all sections (type detection, phase flow, summary, metadata, resume)

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Stage 6, Stage 7, resume sections

**Verification**:
- Stage 6 has contract-review key results with 4 metrics
- Stage 7 has contract-review metadata with 4 fields
- Resume support handles contract-review phases
- All sections use consistent phase names and numbering

---

### Phase 5: Validation and Consistency Check [COMPLETED]

**Goal**: Verify all changes are internally consistent, match the plan agent output from task 264, and follow existing patterns.

**Tasks**:
- [ ] Read the complete modified agent file and verify all 7 integration points are covered
- [ ] Cross-reference phase names with task 264 plan agent output (if available) to ensure alignment
- [ ] Verify all 4 report types (market-sizing, competitive-analysis, gtm-strategy, contract-review) are listed consistently across all sections
- [ ] Check that the contract-review flow follows the same structural pattern as existing flows (section headings, phase numbering, instruction format)
- [ ] Verify template paths are correct: `contract-analysis.md` and `contract-analysis.typ` exist at referenced locations
- [ ] Write implementation summary

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Any corrections from validation
- `specs/265_founder_implement_project_timeline/summaries/01_legal-implement-summary.md` - Summary

**Verification**:
- All 7 integration points confirmed present
- No inconsistencies between sections
- Pattern matches existing report type flows
- Template file paths verified

## Testing & Validation

- [ ] All 7 integration points in founder-implement-agent.md include contract-review support
- [ ] Stage 2 type detection lists 4 report types
- [ ] Stage 4 template table has 4 entries with correct paths
- [ ] Contract review phase flow has 5 phases with clear instructions
- [ ] Each analysis phase (1-3) references specific research report sections
- [ ] Phase 4 references contract-analysis.md template structure
- [ ] Phase 5 uses self-contained typst pattern (no imports)
- [ ] Stage 6 summary has contract-review key results (4 metrics)
- [ ] Stage 7 metadata has contract-review fields (4 fields)
- [ ] Resume support covers contract-review phases
- [ ] Phase names are consistent across all sections
- [ ] Template paths reference existing files

## Artifacts & Outputs

- `plans/01_legal-implement-support.md` (this plan)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (modified agent spec)
- `summaries/01_legal-implement-summary.md` (implementation summary)

## Rollback/Contingency

The only file modified is `.claude/extensions/founder/agents/founder-implement-agent.md`. If changes need to be reverted, use `git checkout` on that single file. Since all additions are new sections or appended list items (no modifications to existing logic), partial rollback is also straightforward by removing the added content.
