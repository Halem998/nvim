# Research Report: Task #373

**Task**: 373 - Make typst primary output in founder-implement-agent
**Started**: 2026-04-07T00:00:00Z
**Completed**: 2026-04-07T00:05:00Z
**Effort**: Small (single file rewrite with well-defined changes)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` (1559 lines)
- `.claude/extensions/founder/context/project/founder/templates/typst/` (8 .typ files)
- `.claude/extensions/founder/context/project/founder/templates/` (5 .md files)
**Artifacts**:
- `specs/373_typst_primary_output_founder_implement/reports/01_typst-primary-output.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The founder-implement-agent already generates Typst as primary output in Phase 4, but its **Context References** and **Stage 4 template table** still point to markdown templates as the primary lookup
- Four specific sections need restructuring: Context References "Always Load", Stage 4 template table, Phase 4 generation order, and output path documentation
- Eight typst templates exist; only six are referenced in the agent. `cost-breakdown.typ` and `financial-analysis.typ` are unreferenced
- The markdown templates should move to a "Load for Markdown Fallback" section, with typst templates promoted to "Always Load"
- Changes are straightforward text edits within a single file

## Context & Scope

The task is to rewrite `founder-implement-agent.md` so that typst is unambiguously the primary output format across all sections, not just in the Phase 4/5 execution logic. Currently the overview and Phase 4 logic already treat typst as primary, but the context references and template loading table still foreground markdown templates.

### Constraints
- Only one file to modify: `.claude/extensions/founder/agents/founder-implement-agent.md`
- The `/deck` pipeline (deck-builder-agent) is unaffected
- Must maintain backward compatibility with existing plan files
- Markdown remains as a fallback, not removed entirely

## Findings

### Current State of Context References (Lines 36-57)

The "Always Load" section (lines 36-41) lists four markdown templates as primary references:

| Current "Always Load" Reference | Type |
|-------------------------------|------|
| `templates/market-sizing.md` | Markdown |
| `templates/competitive-analysis.md` | Markdown |
| `templates/gtm-strategy.md` | Markdown |
| `templates/contract-analysis.md` | Markdown |
| `domain/business-frameworks.md` | Domain knowledge (keep) |

The "Load for Typst Generation (Phase 4)" section (lines 47-53) lists six typst templates as conditional loads:

| Current "Load for Typst" Reference | Type |
|-----------------------------------|------|
| `templates/typst/strategy-template.typ` | Base template |
| `templates/typst/market-sizing.typ` | Typst |
| `templates/typst/competitive-analysis.typ` | Typst |
| `templates/typst/gtm-strategy.typ` | Typst |
| `templates/typst/contract-analysis.typ` | Typst |
| `templates/typst/project-timeline.typ` | Typst |

### Current State of Stage 4 Template Table (Lines 188-194)

The "Load Report Template" table maps report types to markdown templates:

| Report Type | Current Template Path |
|-------------|----------------------|
| market-sizing | `templates/market-sizing.md` |
| competitive-analysis | `templates/competitive-analysis.md` |
| gtm-strategy | `templates/gtm-strategy.md` |
| contract-review | `templates/contract-analysis.md` |
| project-timeline | `domain/timeline-frameworks.md` |

### Available Typst Templates (8 total)

Found in `.claude/extensions/founder/context/project/founder/templates/typst/`:

| Template File | Has Markdown Equivalent | Referenced in Agent |
|--------------|------------------------|-------------------|
| `strategy-template.typ` | No (base template) | Yes (Phase 4 load) |
| `market-sizing.typ` | Yes (`market-sizing.md`) | Yes |
| `competitive-analysis.typ` | Yes (`competitive-analysis.md`) | Yes |
| `gtm-strategy.typ` | Yes (`gtm-strategy.md`) | Yes |
| `contract-analysis.typ` | Yes (`contract-analysis.md`) | Yes |
| `project-timeline.typ` | No | Yes |
| `cost-breakdown.typ` | No | **No** |
| `financial-analysis.typ` | Yes (`financial-analysis.md`) | **No** |

### Available Markdown Templates (5 total)

Found in `.claude/extensions/founder/context/project/founder/templates/`:

| Template File | Has Typst Equivalent |
|--------------|---------------------|
| `market-sizing.md` | Yes |
| `competitive-analysis.md` | Yes |
| `gtm-strategy.md` | Yes |
| `contract-analysis.md` | Yes |
| `financial-analysis.md` | Yes |

### Phase 4 Current Structure (Lines 265-304)

Phase 4 "Report and Typst Generation" already generates typst first (step 2-3) then markdown fallback (step 4). The generation order is correct; only the section heading emphasis and template loading need updating.

### Report-Type-Specific Phase Flows

Each report type (competitive-analysis, gtm-strategy, contract-review, project-timeline) has its own Phase 4 section that already describes generating typst first, markdown second. These are already consistent with the desired state.

## Decisions

1. **Promote typst templates to "Always Load"**: The typst templates should be the primary reference since they are always generated in Phase 4
2. **Create "Load for Markdown Fallback" section**: Move markdown templates to a secondary section
3. **Rewrite Stage 4 table**: Map all report types to their `.typ` template paths
4. **Do not add cost-breakdown or financial-analysis**: These report types are not yet wired into the agent's phase flows; adding them to the template table alone would be incomplete. They should be added in a separate task that also adds their phase flows.
5. **Keep domain knowledge references unchanged**: `business-frameworks.md`, `timeline-frameworks.md`, and `strategic-thinking.md` are domain knowledge, not templates, and remain in "Always Load"

## Recommendations

### Change 1: Context References - "Always Load" Section (Lines 36-41)

Replace the four markdown template references with typst template references:

**New "Always Load"**:
- `domain/business-frameworks.md` (unchanged)
- `templates/typst/strategy-template.typ` (base template -- always needed)
- `templates/typst/market-sizing.typ`
- `templates/typst/competitive-analysis.typ`
- `templates/typst/gtm-strategy.typ`
- `templates/typst/contract-analysis.typ`

**New "Load for Markdown Fallback"** (new section, replaces "Load for Typst Generation"):
- `templates/market-sizing.md`
- `templates/competitive-analysis.md`
- `templates/gtm-strategy.md`
- `templates/contract-analysis.md`

Remove the "Load for Typst Generation (Phase 4)" section since its contents have been promoted.

### Change 2: Stage 4 Template Table (Lines 188-194)

Replace the table to map report types to typst templates as primary:

| Report Type | Primary Template (Typst) | Fallback Template (Markdown) |
|-------------|--------------------------|------------------------------|
| market-sizing | `templates/typst/market-sizing.typ` | `templates/market-sizing.md` |
| competitive-analysis | `templates/typst/competitive-analysis.typ` | `templates/competitive-analysis.md` |
| gtm-strategy | `templates/typst/gtm-strategy.typ` | `templates/gtm-strategy.md` |
| contract-review | `templates/typst/contract-analysis.typ` | `templates/contract-analysis.md` |
| project-timeline | `templates/typst/project-timeline.typ` | `domain/timeline-frameworks.md` |

### Change 3: Phase 4 Section Restructuring (Lines 265-304)

Currently Phase 4 is titled "Report and Typst Generation". Rename to "Typst and Markdown Generation" or similar to emphasize typst-first. Reorder the steps so that:
1. Load typst template (primary)
2. Generate self-contained typst content
3. Write typst file
4. Load markdown template (fallback)
5. Generate markdown fallback report

The current step order is already close (typst in steps 2-3, markdown in step 4), but the step descriptions should make the primary/fallback distinction explicit.

### Change 4: Output Path Documentation

The output paths are already correct (`founder/{type}-{slug}.typ` for primary). Verify the Stage 6 summary and Stage 7 metadata list typst first, markdown second. Current state already does this (lines 944-948, 1006-1019).

## Risks & Mitigations

- **Risk**: Existing plans reference markdown templates in their phase descriptions. **Mitigation**: The agent reads templates by report type, not by plan references. Backward compatibility is maintained.
- **Risk**: Removing "Load for Typst Generation" section could cause confusion if agents reference it by name. **Mitigation**: No other agents reference this section name; it is internal to founder-implement-agent.

## Appendix

### File Structure Summary

```
founder-implement-agent.md sections:
  Lines 1-4: Frontmatter
  Lines 6-17: Overview and metadata
  Lines 19-57: Context References (CHANGE TARGET)
  Lines 60-80: Stage 0 (no change)
  Lines 82-104: Stage 1 (no change)
  Lines 106-151: Stage 2 + 2.5 (no change)
  Lines 153-183: Stage 3 + 3.5 (no change)
  Lines 184-196: Stage 4 template table (CHANGE TARGET)
  Lines 198-304: Stage 5 phase execution + Phase 4 (CHANGE TARGET)
  Lines 306-614: Phase 5 + examples (no change)
  Lines 927-1061: Stage 6-8 (no change)
  Lines 1079-1251: Report-specific phase flows (minor review)
  Lines 1438-1559: Error handling + critical requirements (no change)
```

### Templates Not Yet Wired

Two typst templates exist without corresponding agent routing:
- `cost-breakdown.typ` -- no phase flow, no markdown equivalent with matching name
- `financial-analysis.typ` -- has `financial-analysis.md` equivalent but no phase flow in agent

These could be added in a future task.
