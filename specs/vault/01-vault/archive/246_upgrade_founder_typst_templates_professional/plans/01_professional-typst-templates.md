# Implementation Plan: Task #246

- **Task**: 246 - upgrade_founder_typst_templates_professional
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_typst-template-upgrade.md](../reports/01_typst-template-upgrade.md)
- **Artifacts**: plans/01_professional-typst-templates.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Upgrade the founder extension typst templates from generic styling (New Computer Modern font, gray color scheme) to professional styling based on the reference template at `/home/benjamin/Projects/Logos/Vision/strategy/market-sizing-condensed.typ`. The professional styling uses Libertinus Serif font, a navy/blue color palette (#0a2540, #1a4a7a, #2a5a9a), colored heading underlines, metric pills, callout boxes, and alternating row tables.

### Research Integration

Key findings from the research report:
- Complete color palette extracted: navy-dark (#0a2540), navy-medium (#1a4a7a), navy-light (#2a5a9a), text colors, and fill colors
- Typography settings: Libertinus Serif at 10.5pt with specific paragraph spacing
- Professional heading styles with colored underlines at each level
- New helper functions needed: `metric()` pill, `callout()` flexible box, `nested-market-diagram()`, `comparison-block()`
- Table styling with conditional stroke/fill for alternating rows and header emphasis
- Page header/footer with divider line and confidentiality statement

## Goals & Non-Goals

**Goals**:
- Upgrade `strategy-template.typ` with professional color palette, typography, and helper functions
- Update heading styles to use colored underlines without numbering
- Replace generic blue/green/yellow colors with consistent navy gradient across all templates
- Add new helper functions: `metric()`, `callout()`, `nested-market-diagram()`, `comparison-block()`
- Update `founder-implement-agent.md` Phase 5 example to use new styling
- Maintain backward compatibility for template wrapper functions

**Non-Goals**:
- Creating new template types
- Changing the document structure or section ordering
- Adding new parameters to existing wrapper functions
- Modifying the markdown templates

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Libertinus Serif font not installed | Compilation fails | Medium | Add fallback font chain: `("Libertinus Serif", "Linux Libertine", "Georgia")` |
| Breaking changes to helper functions | Existing inline generation breaks | Low | Templates are generated per-task; no persistent docs to break |
| Color palette too dark | Readability issues | Low | Use exact colors from tested reference template |
| Nested diagram layout issues | Visual artifacts | Medium | Test with various content lengths |

## Implementation Phases

### Phase 1: Upgrade strategy-template.typ Foundation [COMPLETED]

**Goal**: Establish professional color palette, typography, and base styling in the shared template.

**Tasks**:
- [ ] Add color constant definitions at top of file
- [ ] Update typography to Libertinus Serif with fallback chain
- [ ] Update paragraph settings (justify, leading, spacing)
- [ ] Replace heading styles with colored underlines (remove numbering)
- [ ] Update table styling with alternating rows and header emphasis
- [ ] Add block quote styling
- [ ] Update page header with divider line
- [ ] Update page footer with confidentiality statement

**Timing**: 45-60 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` - Complete styling rewrite

**Verification**:
- Color constants defined for all palette colors
- Typography uses Libertinus Serif with fallback
- Headings have colored underlines matching reference
- Tables use conditional stroke/fill pattern

---

### Phase 2: Add New Helper Functions [COMPLETED]

**Goal**: Create new helper functions that match the professional reference template.

**Tasks**:
- [ ] Add `metric(label, value)` function - dark navy pill with white text
- [ ] Add `callout(body, color, border)` function - flexible left-bordered callout
- [ ] Add `nested-market-diagram(tam, sam, som, ...)` function - professional nested boxes
- [ ] Add `comparison-block(left, right)` function - dark navy side-by-side block
- [ ] Update existing `metric-callout` to use navy palette
- [ ] Update existing `highlight-box` to use navy palette
- [ ] Update existing `warning-box` to use orange warning palette
- [ ] Update `market-circles` to use `nested-market-diagram` style

**Timing**: 45-60 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` - Add/update helper functions

**Verification**:
- `metric()` creates compact dark navy pills
- `callout()` creates left-bordered boxes with flexible colors
- `nested-market-diagram()` renders properly with 3 nested levels
- Existing helper functions updated to navy palette

---

### Phase 3: Upgrade market-sizing.typ [COMPLETED]

**Goal**: Update market-sizing template with professional styling and condensed structure.

**Tasks**:
- [ ] Update title page to use metric pills row
- [ ] Add value proposition callout to title page
- [ ] Update executive summary styling
- [ ] Consolidate TAM/SAM/SOM into summary section
- [ ] Replace `market-circles` with `nested-market-diagram`
- [ ] Update table styling to use professional patterns
- [ ] Add Revenue Model section template

**Timing**: 30-45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ` - Professional styling and structure

**Verification**:
- Title page displays metric pills in row
- Market visualization uses nested boxes
- All colors follow navy palette
- Executive summary uses new callout style

---

### Phase 4: Upgrade competitive-analysis.typ and gtm-strategy.typ [COMPLETED]

**Goal**: Apply professional color palette to remaining templates.

**Tasks**:
- [ ] Update `competitive-analysis.typ` colors from blue (#2563eb) to navy-medium (#1a4a7a)
- [ ] Update callout fills from #f0f7ff to #e8f0fb
- [ ] Update competitor-card styling to navy palette
- [ ] Update battle-card styling to navy palette
- [ ] Update `gtm-strategy.typ` colors to navy palette
- [ ] Update positioning-statement box styling
- [ ] Update timeline styling
- [ ] Update metrics dashboard styling

**Timing**: 30-45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ` - Navy palette
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ` - Navy palette

**Verification**:
- No blue (#2563eb) or generic colors remaining
- Battle cards use navy styling
- Positioning map uses navy gradient
- All highlight boxes use navy palette

---

### Phase 5: Update founder-implement-agent.md [COMPLETED]

**Goal**: Update the Phase 5 inline generation example to use professional styling.

**Tasks**:
- [ ] Replace "New Computer Modern" with "Libertinus Serif" and fallback
- [ ] Add color constant definitions to example
- [ ] Update heading show rules to include colored underlines
- [ ] Update table styling example with alternating rows
- [ ] Add metric() pill usage in title page section
- [ ] Update metric-callout and highlight-box to navy colors
- [ ] Add callout() function definition

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Update Phase 5 example

**Verification**:
- Example shows professional color palette
- Font updated to Libertinus Serif with fallback
- Heading styles include underlines
- metric() pill function demonstrated

---

### Phase 6: Verification and Testing [COMPLETED]

**Goal**: Verify all templates compile correctly and produce professional output.

**Tasks**:
- [ ] Verify strategy-template.typ syntax is valid
- [ ] Verify market-sizing.typ compiles with sample data
- [ ] Verify competitive-analysis.typ compiles with sample data
- [ ] Verify gtm-strategy.typ compiles with sample data
- [ ] Test that self-contained inline pattern from agent still works
- [ ] Verify font fallback works when Libertinus Serif unavailable
- [ ] Review visual output matches reference template style

**Timing**: 30 minutes

**Verification Commands**:
```bash
# Check typst syntax
typst compile --root . .claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ /dev/null 2>&1 || echo "Syntax check only"

# Test with sample market sizing document
echo '#import "strategy-template.typ": *
#show: strategy-doc.with(title: "Test", project: "Test Project", date: "2026-03-19", mode: "SIZE")
= Test Section
Hello world.' > /tmp/test.typ
typst compile /tmp/test.typ /tmp/test.pdf && echo "Compilation successful"
```

**Verification**:
- All templates compile without errors
- Visual output uses navy color palette
- Headings have colored underlines
- Tables have alternating row fills
- Metric pills display correctly

## Testing & Validation

- [ ] All typst files compile without syntax errors
- [ ] Color constants match reference values exactly
- [ ] Typography uses Libertinus Serif with proper fallbacks
- [ ] Heading styles include colored underlines
- [ ] Table styling includes alternating rows
- [ ] New helper functions (metric, callout, nested-market-diagram) work correctly
- [ ] Existing helper functions updated to navy palette
- [ ] founder-implement-agent.md example is syntactically valid typst

## Artifacts & Outputs

- `plans/01_professional-typst-templates.md` (this file)
- Modified: `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ`
- Modified: `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ`
- Modified: `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ`
- Modified: `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ`
- Modified: `.claude/extensions/founder/agents/founder-implement-agent.md`
- `summaries/01_professional-typst-templates-summary.md` (upon completion)

## Rollback/Contingency

If implementation causes issues:
1. Revert typst template changes using git checkout
2. The original generic styling will be restored
3. founder-implement-agent.md example can be reverted independently
4. No state.json or TODO.md changes required for rollback (meta task)
