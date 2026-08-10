# Research Report: Task #232

**Task**: Update example templates to be YC compliant
**Date**: 2026-03-18
**Focus**: Example file simplification

## Summary

The four example pitch deck files in the present/ extension serve as reference patterns for the deck-agent. Currently they include complex layouts that get replicated in generated output. All examples need simplification to demonstrate YC-compliant design.

## Findings

### Current Example Files

Located at `.claude/extensions/present/examples/`:
1. `professional-blue-pitch.typ`
2. `premium-dark-pitch.typ`
3. `minimal-light-pitch.typ`
4. `growth-green-pitch.typ`

### Common Issues Across Examples

1. **Multi-column grids**: Most slides use 2-3 column layouts
2. **Panel/card patterns**: Heavy use of boxed content
3. **Small font sizes**: Text as low as 17-18pt
4. **Metric displays**: Complex metric card layouts
5. **Dense content**: Multiple ideas per slide

### Required Simplifications

**Per-Slide Changes**:
- Title slide: Name + one-liner only
- Problem: Single statement, 1-3 bullets max
- Solution: One paragraph, 1-3 benefits
- Traction: Single chart or 1-3 large metrics
- Why Us/Now: 2-3 bullets
- Business Model: Simple 2-column or list
- Market: TAM/SAM/SOM with large numbers
- Team: 2-column for founders only
- Ask: Single amount + 3-4 use items
- Closing: Contact info only

**Font Size Requirements**:
- All body text: 28pt minimum
- All titles: 44pt minimum
- No decorative small text

**Layout Requirements**:
- Remove all 3+ column grids
- Remove nested panels
- Use whitespace over boxes

## Recommendations

1. Rewrite all 4 example files following simplified patterns
2. Ensure each demonstrates one-idea-per-slide
3. Use large fonts consistently
4. Test compilation after changes

## Dependencies

Requires Tasks 229-231 to complete first so examples reflect updated guidelines.

## Next Steps

Update all files in `.claude/extensions/present/examples/`
