# Implementation Plan: Task #232

- **Task**: 232 - Update example templates to be YC compliant
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: Task #229 (deck-agent enforcement - COMPLETED), Task #230 (template simplification - COMPLETED), Task #231 (pitch-deck-structure update - COMPLETED)
- **Research Inputs**: [02_example-analysis.md](../reports/02_example-analysis.md)
- **Artifacts**: plans/01_yc-compliance-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-03-18
- **Version**: 001
- **Estimated Hours**: 3-4 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

All 4 example pitch deck files contain identical YC compliance violations: decorative blocks with fill/radius/stroke styling, 3-4 column grids, nested circles for market sizing, and font sizes below 28pt (ranging from 12pt to 22pt). This plan applies consistent simplification changes across all files by change type rather than by file, enabling efficient batch updates. The goal is to transform complex, visually heavy examples into clean, YC-compliant demonstrations that match the updated template patterns from Task #230.

### Research Integration

Key findings from research report 02_example-analysis.md:
- All 4 files have base text at 30pt (should be 32pt)
- 3-column grids appear 4 times per file (Solution, Traction, Market, one other)
- Decorative blocks range from 6-12 instances per file
- TAM/SAM/SOM nested circles present in all 4 Market slides
- Font sizes as small as 12pt found in Market slide captions

## Goals & Non-Goals

**Goals**:
- Remove all decorative blocks (fill, radius, stroke styling)
- Eliminate all grids with more than 2 columns
- Convert non-Team 2-column grids to single-column layouts
- Replace nested circle market visualizations with plain text
- Update all font sizes to minimum 28pt (32pt for body text)
- Preserve each theme's color identity (blue, dark/gold, light/charcoal, green)
- Create clean, readable examples that demonstrate YC principles

**Non-Goals**:
- Redesigning the content structure (slide order, message hierarchy)
- Creating new example files
- Adding new slide types or content
- Modifying the shared-config.typ file

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing too much styling makes themes indistinguishable | Medium | Keep heading colors and accent colors; only remove decorative elements |
| Font size increases cause text overflow | Medium | Condense bullet text where needed; rely on concision principles |
| Market slide becomes too sparse without circles | Low | Use clear header formatting for TAM/SAM/SOM; add brief methodology note |
| Breaking Typst syntax during edits | Medium | Compile each file after changes; verify no syntax errors |

## Implementation Phases

### Phase 1: Font Size Updates [COMPLETED]

**Goal**: Update all font sizes to meet YC minimums (28pt body, 40pt+ titles, 32pt base text)

**Estimated effort**: 0.5 hours

**Objectives**:
1. Update base text size from 30pt to 32pt in all 4 files
2. Increase all small fonts (12-22pt) to minimum 28pt
3. Verify heading sizes remain at 40pt+ (already compliant)

**Files to modify**:
- `.claude/extensions/present/examples/professional-blue-pitch.typ` - Update base text, card content, metric labels, bios
- `.claude/extensions/present/examples/premium-dark-pitch.typ` - Same pattern
- `.claude/extensions/present/examples/minimal-light-pitch.typ` - Same pattern
- `.claude/extensions/present/examples/growth-green-pitch.typ` - Same pattern

**Steps**:
1. In each file, find `#set text(size: 30pt)` and change to `#set text(size: 32pt)`
2. Find all `#text(size: 22pt)`, `#text(size: 20pt)`, `#text(size: 18pt)`, `#text(size: 16pt)`, `#text(size: 14pt)`, `#text(size: 13pt)`, `#text(size: 12pt)` and update to `#text(size: 28pt)`
3. Compile each file to verify no overflow issues

**Verification**:
- [ ] All 4 files compile without errors
- [ ] No text size below 28pt in any file
- [ ] Base text is 32pt in all files

---

### Phase 2: Remove Decorative Blocks [COMPLETED]

**Goal**: Remove all block elements with fill, radius, or stroke styling that serve decorative purposes

**Estimated effort**: 1 hour

**Objectives**:
1. Remove `block(fill: ...)` decorative cards
2. Remove `block(radius: ...)` rounded panels
3. Remove `block(stroke: ...)` bordered elements
4. Convert content to simple bullet lists or plain text

**Files to modify**:
- `.claude/extensions/present/examples/professional-blue-pitch.typ` - ~6 decorative blocks
- `.claude/extensions/present/examples/premium-dark-pitch.typ` - ~7 decorative blocks
- `.claude/extensions/present/examples/minimal-light-pitch.typ` - ~4 blocks + tables
- `.claude/extensions/present/examples/growth-green-pitch.typ` - ~12 decorative blocks

**Steps**:
1. Problem slide: Remove "Real Example" decorative cards; keep bullet list content
2. Solution slide: Remove card wrappers; convert to numbered list or bullets
3. Traction slide: Remove metric cards; use plain text metrics
4. Why Us/Why Now slide: Remove section cards; use heading + bullets
5. Business Model slide: Remove tables/cards; use simple bullets
6. Ask slide: Remove decorative cards; use plain layout
7. Thank You slide: Simplify to plain text

**Verification**:
- [ ] No `block(fill:` patterns remain (except page fill for dark theme)
- [ ] No `block(radius:` patterns remain
- [ ] No `block(stroke:` patterns remain (except necessary borders)
- [ ] All content remains visible and readable

---

### Phase 3: Simplify Grid Layouts [COMPLETED]

**Goal**: Convert all 3+ column grids to maximum 2 columns; convert non-Team 2-column grids to single-column

**Estimated effort**: 1 hour

**Objectives**:
1. Remove all 3-column and 4-column grid layouts
2. Convert Solution, Traction, Market slides to single-column or 2-column max
3. Convert Why Us/Why Now, Business Model, Ask slides to single-column
4. Keep Team slide as 2-column (only allowed exception)

**Files to modify**:
- All 4 example files have identical grid patterns to fix

**Steps**:
1. Solution slide: Convert `grid(columns: (1fr, 1fr, 1fr))` to numbered bullet list
2. Traction slide: Convert `grid(columns: (1fr, 1fr, 1fr))` or 4-column to 2-column or stacked metrics
3. Why Us/Why Now slide: Convert 2-column to single-column with section headings
4. Business Model slide: Convert 2-column grid to single-column bullets
5. Market slide: Remove 3-column grid (handled in Phase 4 with circles removal)
6. Ask slide: Convert 2-column to single-column format
7. Team slide: Keep 2-column but remove decorative wrappers

**Verification**:
- [ ] No `grid(columns: (1fr, 1fr, 1fr` patterns remain
- [ ] No `grid(columns: (1fr, 1fr, 1fr, 1fr` patterns remain
- [ ] Only Team slides use 2-column grids
- [ ] All slides compile and display correctly

---

### Phase 4: Replace Market Slide Circles [COMPLETED]

**Goal**: Replace TAM/SAM/SOM nested circle visualizations with plain text format

**Estimated effort**: 0.5 hours

**Objectives**:
1. Remove nested `block(radius: 50%, ...)` circle patterns
2. Replace with simple text: "**TAM**: $X B" format
3. Add brief methodology note for credibility

**Files to modify**:
- All 4 example files have identical Market slide patterns

**Steps**:
1. Remove entire nested circle structure (typically 3 blocks with radius: 50%)
2. Replace with:
   ```typst
   *Total Addressable Market (TAM)*: $XXX B

   *Serviceable Addressable Market (SAM)*: $XX B

   *Serviceable Obtainable Market (SOM)*: $X M

   #v(1em)

   Bottom-up calculation based on [brief methodology]
   ```
3. Ensure font size is 32pt for body text, 28pt minimum for any labels

**Verification**:
- [ ] No `radius: 50%` or circular block patterns remain
- [ ] Market slides show clean text-based TAM/SAM/SOM
- [ ] Methodology note is present
- [ ] All files compile successfully

---

### Phase 5: Theme Identity Preservation and Final Verification [COMPLETED]

**Goal**: Verify each theme maintains its color identity and passes YC compliance checklist

**Estimated effort**: 0.5 hours

**Objectives**:
1. Verify professional-blue keeps navy/blue heading colors
2. Verify premium-dark keeps dark background with gold accents
3. Verify minimal-light keeps charcoal/blue accents
4. Verify growth-green keeps emerald green accents
5. Run final YC compliance checklist on all files

**Files to modify**:
- All 4 files - final review and any cleanup

**Steps**:
1. Review each file's color scheme definitions
2. Ensure heading `#text(fill: ...)` colors are preserved
3. Compile all 4 files and visually inspect output
4. Run through YC compliance checklist for each:
   - [ ] Font sizes >= 28pt (32pt body)
   - [ ] No grids > 2 columns
   - [ ] No decorative blocks
   - [ ] No nested circles
   - [ ] No screenshots or complex graphics
   - [ ] Single idea per slide maintained

**Verification**:
- [ ] professional-blue-pitch.typ: Compiles, distinct blue theme visible
- [ ] premium-dark-pitch.typ: Compiles, dark theme with gold accents visible
- [ ] minimal-light-pitch.typ: Compiles, clean light theme visible
- [ ] growth-green-pitch.typ: Compiles, green accent theme visible
- [ ] All 4 files pass YC compliance checklist

---

## Testing & Validation

- [ ] All 4 files compile without Typst errors
- [ ] No font sizes below 28pt in any file (grep verification)
- [ ] No 3+ column grids in any file (grep verification)
- [ ] No `block(fill:` decorative patterns (grep verification)
- [ ] No nested circles (`radius: 50%`) in any file (grep verification)
- [ ] Each theme maintains distinct visual identity
- [ ] Market slides use text-based TAM/SAM/SOM
- [ ] Team slides are only slides with 2-column layouts

## Artifacts & Outputs

- plans/01_yc-compliance-plan.md (this file)
- Modified files:
  - `.claude/extensions/present/examples/professional-blue-pitch.typ`
  - `.claude/extensions/present/examples/premium-dark-pitch.typ`
  - `.claude/extensions/present/examples/minimal-light-pitch.typ`
  - `.claude/extensions/present/examples/growth-green-pitch.typ`
- summaries/02_yc-compliance-summary.md (after implementation)

## Rollback/Contingency

If changes break file compilation or visual appearance:
1. Use `git diff` to identify specific breaking changes
2. Revert individual files with `git checkout -- <file>`
3. Re-apply changes incrementally with compilation verification after each step
4. If fundamental approach fails, consider keeping minimal decorative elements that don't violate hard limits (e.g., single-color backgrounds)
