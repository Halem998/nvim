# Implementation Plan: Fix founder-plan-agent plan format conformance

- **Task**: 319 - Fix founder-plan-agent to conform to plan-format.md standard
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/319_founder_plan_format_conformance/reports/01_meta-research.md
- **Artifacts**: plans/01_plan-format-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The founder-plan-agent creates plans that do not conform to the plan-format.md standard. The agent defines its own custom plan structure without referencing the standard format file. This task fixes the agent by: (1) adding plan-format.md to context references, (2) rewriting Stage 5 to use the standard template structure, and (3) updating the index to ensure proper context loading.

### Research Integration

Research report identified:
- **8 missing required metadata fields** in generated plans (Status, Effort, Research Inputs, Artifacts, Standards, Type)
- **4 missing required sections** (Goals and Non-Goals, Testing and Validation, Artifacts and Outputs, Rollback/Contingency)
- **Wrong section names and locations** (Phases vs Implementation Phases, Objectives vs Goal, Success Criteria vs Testing and Validation)
- **Root cause**: Agent does not load plan-format.md and defines its own template in Stage 5

## Goals & Non-Goals

**Goals**:
- Make founder-plan-agent generate plans conforming to plan-format.md standard
- Preserve founder-specific content (report type, mode, typst generation phases)
- Ensure plan-format.md is loaded via index for the agent

**Non-Goals**:
- Changing the founder-specific phase structures (TAM/SAM/SOM, contract analysis, etc.)
- Modifying how forcing questions work in research phase
- Altering the metadata file output format

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing founder workflows | High | Medium | Test with existing research reports before merging |
| Template too rigid for all report types | Medium | Low | Keep report-type-specific phase content while standardizing structure |
| Missing founder-specific fields after conversion | Medium | Medium | Map founder fields to standard format (Report Type to Type, Mode to metadata) |

## Implementation Phases

### Phase 1: Update Context References [COMPLETED]

**Goal**: Add plan-format.md to agent's context loading

**Tasks**:
- [ ] Add `@.claude/context/formats/plan-format.md` to Always Load section in founder-plan-agent.md
- [ ] Update extension index-entries.json to include plan-format.md for founder-plan-agent

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Add context reference (lines 33-41)
- `.claude/extensions/founder/index-entries.json` - Add plan-format entry (if exists) OR verify core index.json includes founder-plan-agent

**Verification**:
- Agent definition includes plan-format.md in Always Load section

---

### Phase 2: Rewrite Stage 5 Template [COMPLETED]

**Goal**: Replace custom plan template with standard-conforming structure

**Tasks**:
- [ ] Replace metadata block (lines 254-265) with standard format including all required fields
- [ ] Rename "## Phases" to "## Implementation Phases"
- [ ] Change phase format from Objectives/Inputs/Outputs to Goal/Tasks/Timing
- [ ] Add missing sections: Goals and Non-Goals, Risks and Mitigations, Testing and Validation, Artifacts and Outputs, Rollback/Contingency
- [ ] Move founder-specific content (Report Type, Mode) into standard Type field and Overview section
- [ ] Keep Research Integration section as subsection of Overview per standard

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Rewrite Stage 5 (lines 250-345)

**Verification**:
- Template includes all 8 required metadata fields (Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type)
- Template includes all 7 required sections (Overview, Goals and Non-Goals, Risks and Mitigations, Implementation Phases, Testing and Validation, Artifacts and Outputs, Rollback/Contingency)
- Phase format uses Goal/Tasks/Timing structure

---

### Phase 3: Adapt Phase Structures [COMPLETED]

**Goal**: Convert report-type-specific phases to standard format while preserving content

**Tasks**:
- [ ] Convert market-sizing phases (TAM, SAM, SOM, Report Gen, Typst) to standard format
- [ ] Convert competitive-analysis phases to standard format
- [ ] Convert gtm-strategy phases to standard format
- [ ] Convert contract-review phases to standard format
- [ ] Convert project-timeline phases to standard format
- [ ] Ensure each phase has: Goal (single statement), Tasks (bullet checklist), Timing (duration)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Update Phase Structure by Report Type sections (lines 346-420)

**Verification**:
- All 5 report types have phase structures with Goal/Tasks/Timing format
- Phase headings use `### Phase N: {name} [NOT STARTED]` format

---

### Phase 4: Verification and Testing [COMPLETED]

**Goal**: Ensure changes work correctly with existing workflows

**Tasks**:
- [ ] Read a sample existing research report (if available in Vision specs)
- [ ] Manually verify template produces valid plan structure
- [ ] Check that all required metadata fields are present in template
- [ ] Verify section order matches plan-format.md standard
- [ ] Ensure Status field is present (critical for postflight detection)

**Timing**: 30 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- Template generates plans with all required metadata fields
- Plans have correct section structure per plan-format.md
- Status field is present for postflight consumption

## Testing & Validation

- [ ] Template includes `- **Status**: [NOT STARTED]` in metadata block
- [ ] Template includes all 8 required metadata fields
- [ ] Template includes all 7 required sections in correct order
- [ ] Phase format uses `### Phase N: {name} [STATUS]` heading
- [ ] Phase content uses Goal/Tasks/Timing structure
- [ ] Founder-specific content (report type, mode) preserved in appropriate locations

## Artifacts & Outputs

- plans/01_plan-format-fix.md (this plan)
- Modified: .claude/extensions/founder/agents/founder-plan-agent.md

## Rollback/Contingency

If changes break founder workflows:
1. Revert founder-plan-agent.md to previous version via git
2. Keep core plan-format.md unchanged
3. Consider creating founder-specific plan format extension instead of conforming to core standard
