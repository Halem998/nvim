# Research Report: Task #232

**Task**: Update example templates to be YC compliant
**Date**: 2026-03-18
**Focus**: Example file analysis for YC compliance

## Summary

All 4 example pitch deck files contain multiple YC compliance violations, primarily related to complex multi-column layouts, decorative panels with fill colors, and font sizes below the 28pt minimum. The issues are consistent across all files, indicating they were created before the YC compliance standards were established. The template file (touying-pitch-deck-template.md) was updated in Task #230, but the example files were not updated to match.

## Current State Analysis

### professional-blue-pitch.typ

**Font Sizes**:
- Base text: 30pt (FAIL - below 32pt recommended)
- Headings: 48pt/40pt (PASS - meets 40pt minimum)
- Solution slide cards: 22pt (FAIL - well below 28pt minimum)
- Traction slide labels: 20pt (FAIL - below 28pt minimum)
- Market slide text: 18pt, 14pt, 13pt, 12pt (FAIL - multiple violations)
- Team slide bios: 22pt (FAIL - below 28pt minimum)
- Thank you slide: 22pt (FAIL - below 28pt minimum)

**Layout Patterns**:
- Problem slide: Uses `block(fill:...)` decorative card (FAIL - prohibited)
- Solution slide: 3-column grid with decorative cards (FAIL - max 2 columns, no decorative panels)
- Traction slide: 3-column grid with decorative cards (FAIL)
- Why Us/Why Now: 2-column grid for content (FAIL - only Team slide should use 2-column)
- Business Model: 2-column grid for content (FAIL)
- Market slide: 3-column grid with nested circles, complex radius/height styling (FAIL - nested circles prohibited)
- Team slide: 2-column grid (PASS - appropriate for Team)
- Ask slide: 2-column grid with decorative card (FAIL)

**Content Density**:
- Problem slide: Combines bullet list + decorative "Real Example" card (multiple ideas)
- Most slides within 5 bullet limit (PASS)

**Prohibited Patterns Found**:
1. `block(fill: rgb("#fef3c7"), radius: 8pt, ...)` - decorative cards (6 instances)
2. `grid(columns: (1fr, 1fr, 1fr), ...)` - 3-column grids (4 instances)
3. `block(radius: 50%, width: 200pt, height: 200pt)` - nested circles for TAM/SAM/SOM
4. Font sizes: 22pt, 20pt, 18pt, 14pt, 13pt, 12pt (all below 28pt minimum)

---

### premium-dark-pitch.typ

**Font Sizes**:
- Base text: 30pt (FAIL - below 32pt recommended)
- Headings: 48pt/40pt (PASS)
- Solution slide cards: 22pt (FAIL)
- Traction slide labels: 20pt (FAIL)
- Market slide text: 18pt, 14pt, 13pt, 12pt (FAIL - multiple violations)
- Team slide bios: 22pt (FAIL)
- Thank you slide: 22pt (FAIL)

**Layout Patterns**:
- Nearly identical structure to professional-blue-pitch.typ
- Problem slide: `block(fill: secondary-bg, ...)` decorative card (FAIL)
- Solution slide: 3-column grid with `stroke` borders (FAIL)
- Traction slide: 3-column grid with `stroke` borders (FAIL)
- Why Us/Why Now: 2-column grid for content (FAIL)
- Business Model: 2-column grid for content (FAIL)
- Market slide: 3-column grid with nested circles and `stroke` (FAIL)
- Team slide: 2-column grid (PASS)
- Ask slide: 2-column grid with decorative card (FAIL)

**Prohibited Patterns Found**:
1. `block(fill: card-bg, ..., stroke: 1pt + gold.lighten(60%))` - decorative cards with borders (7 instances)
2. 3-column grids (4 instances)
3. Nested circles for TAM/SAM/SOM with stroke borders
4. Font sizes below 28pt (same pattern as professional-blue)

---

### minimal-light-pitch.typ

**Font Sizes**:
- Base text: 30pt (FAIL)
- Headings: 48pt/40pt (PASS)
- Problem slide statistics: 56pt metric + 20pt label (20pt FAIL)
- Traction slide: 44pt metrics + 18pt labels (18pt FAIL)
- Market slide: 44pt metrics + 18pt/14pt text (FAIL)
- Business model: Uses `table()` with inset styling (non-standard)
- Team slide bios: 22pt (FAIL)
- Thank you slide: 20pt (FAIL)

**Layout Patterns**:
- Problem slide: 3-column grid for statistics (FAIL)
- Solution slide: 2-column grid for content (FAIL - not Team slide)
- Traction slide: 4-column grid (FAIL - exceeds 2 column max)
- Why Us/Why Now: 2-column grid for content (FAIL)
- Business Model: 2-column grid with `table()` elements (FAIL - tables are complex)
- Market slide: 3-column grid with `block()` cards (FAIL)
- Team slide: 2-column grid (PASS)
- Ask slide: 2-column grid with nested `grid()` (FAIL)

**Prohibited Patterns Found**:
1. `grid(columns: (1fr, 1fr, 1fr, 1fr), ...)` - 4-column grid (Traction slide)
2. `table(columns: ..., stroke: ...)` - tables are visually complex
3. `line(length: 100%, stroke: ...)` - decorative line separators
4. Font sizes: 20pt, 18pt, 14pt (multiple violations)

---

### growth-green-pitch.typ

**Font Sizes**:
- Base text: 30pt (FAIL)
- Headings: 48pt/40pt (PASS)
- Problem slide cards: 18pt labels (FAIL)
- Solution slide: 22pt descriptions (FAIL)
- Traction slide: 40pt metrics + 16pt labels (16pt FAIL)
- Market slide: 40pt metrics + 18pt/14pt text (FAIL)
- Team slide bios: 20pt (FAIL)
- Thank you slide: 20pt (FAIL)

**Layout Patterns**:
- Problem slide: 3-column grid with decorative `block(fill: emerald.lighten(85%))` cards (FAIL)
- Solution slide: 3-column grid with `stroke: 2pt + emerald` borders (FAIL)
- Traction slide: 4-column grid with decorative cards (FAIL - 4 columns)
- Why Us/Why Now: 2-column grid with decorative `block(fill: white, stroke: ...)` cards (FAIL)
- Business Model: 2-column grid for content (FAIL)
- Market slide: 3-column grid with decorative rounded blocks (FAIL)
- Team slide: 2-column grid with decorative cards (partially FAIL - cards unnecessary)
- Ask slide: 2-column grid with decorative cards (FAIL)

**Prohibited Patterns Found**:
1. `block(fill: emerald.lighten(85%), radius: 8pt, ...)` - decorative cards (12+ instances)
2. 3-column grids (4 instances)
3. 4-column grid (Traction slide)
4. `block(stroke: 2pt + emerald)` - bordered cards
5. `block(radius: 12pt, inset: 20pt)` - rounded decorative panels
6. Font sizes: 20pt, 18pt, 16pt, 14pt (multiple violations)

---

## YC Compliance Gap Analysis

### Universal Issues (All 4 Files)

| Issue | Severity | Count | Required Fix |
|-------|----------|-------|--------------|
| Base text 30pt (should be 32pt) | WARN | 4 files | Update to 32pt |
| 3-column grids | FAIL | 4 per file | Reduce to max 2 columns or use single-column |
| Decorative blocks with fill | FAIL | 6-12 per file | Remove fill/radius/stroke styling |
| Metric label text < 28pt | FAIL | 3-5 per file | Increase to 28pt minimum |
| TAM/SAM/SOM nested circles | FAIL | 1 per file | Replace with simple text |
| 2-column grids for non-Team slides | FAIL | 3-4 per file | Convert to single-column |
| Team slide bios < 28pt | FAIL | 4 files | Increase to 28pt |

### Slide-by-Slide Fix Summary

| Slide | Current Pattern | Required Change |
|-------|-----------------|-----------------|
| Title | PASS | No changes needed |
| Problem | Decorative card + 3-col (some) | Remove block(fill), use bullet list |
| Solution | 3-column grid with cards | Single-column bullet list or reduce to 2-col max |
| Traction | 3-4 column grid with cards | 2-column max, remove decorative styling |
| Why Us/Why Now | 2-column content grid | Single-column or bullet list format |
| Business Model | 2-column grid | Single-column format |
| Market | 3-column nested circles | Simple text: TAM/SAM/SOM as bullet points |
| Team | 2-column grid (OK) | Keep 2-column, increase font to 28pt |
| Ask | 2-column grid with cards | Single-column, remove decorative blocks |
| Thank You | OK structure | Increase font to 28pt minimum |

### Font Size Requirements

**Current vs Required**:

| Element | Current | Required | Gap |
|---------|---------|----------|-----|
| Body text | 30pt | 32pt | +2pt |
| Card descriptions | 22pt | 28pt | +6pt |
| Metric labels | 16-20pt | 28pt | +8-12pt |
| Team bios | 20-22pt | 28pt | +6-8pt |
| Small captions | 12-14pt | 28pt | +14-16pt |

---

## Recommendations

### Priority 1: Remove Prohibited Patterns

1. **Remove all decorative blocks**: Delete `block(fill: ..., radius: ..., stroke: ...)` patterns
2. **Remove nested circles**: Replace Market slide TAM/SAM/SOM circles with plain text
3. **Remove tables**: Replace Business Model tables with bullet lists
4. **Remove 3+ column grids**: Convert to single-column or 2-column maximum

### Priority 2: Fix Font Sizes

1. **Update base text**: Change `#set text(size: 30pt)` to `#set text(size: 32pt)`
2. **Update card content**: All `#text(size: 22pt)` must become 28pt minimum
3. **Update labels**: All metric labels (16-20pt) must become 28pt minimum
4. **Update captions**: All 12-14pt text must become 28pt minimum

### Priority 3: Simplify Layouts

1. **Solution slide**: Convert 3-column "Monitor/Verify/Intervene" to numbered bullet list
2. **Traction slide**: Convert grid to 2-column or stacked format
3. **Why Us/Why Now**: Convert to single-column with two sections
4. **Business Model**: Convert to single-column bullet list format
5. **Ask slide**: Convert to single-column format

### Priority 4: Preserve Theme Identity

Each file should maintain its color scheme while simplifying:
- professional-blue: Keep navy/blue accent colors in headings
- premium-dark: Keep dark background, gold accents in headings
- minimal-light: Keep charcoal/blue accent colors
- growth-green: Keep emerald/green accent colors

---

## Next Steps

1. **Planning phase** should create a consistent simplification approach for all 4 files
2. **Implementation** should modify files in parallel since changes are similar
3. **Verification** should check each file against YC compliance checklist
4. Reference Task #230 template patterns for compliant examples
