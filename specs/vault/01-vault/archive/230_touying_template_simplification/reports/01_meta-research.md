# Research Report: Task #230

**Task**: Update touying-pitch-deck-template with simpler layouts
**Date**: 2026-03-18
**Focus**: Template pattern simplification

## Summary

The current touying template provides complex layout patterns that encourage non-compliant deck generation. Templates need simplification to enforce YC principles by default.

## Findings

### Current Template Issues

1. **Complex grid patterns**: Template shows 2-column grids that agents copy
2. **Small font defaults**: Example code uses 24pt (minimum) rather than larger
3. **Panel/box patterns**: Provides card/panel helpers that create clutter
4. **Traction chart placeholder**: Encourages complex visual elements

### Simplified Patterns Needed

**Slide Structure**:
```typst
== Slide Title

#text(size: 32pt)[
  Single main message goes here.
]

- Key point one
- Key point two
- Key point three
```

**Font Size Defaults**:
- Body text: 32pt (not 24pt - gives margin)
- Titles: 48pt+
- Bullet items: 28pt+

### Patterns to Remove

1. Grid layouts (except simple 2-column for Team slide)
2. Metric cards/panels
3. Complex nested blocks
4. Small label text (<24pt)

### Patterns to Add

1. "DO NOT USE" section with anti-patterns
2. Simple slide templates for each of 10 slides
3. Large-font-first examples
4. Whitespace-focused layouts

## Recommendations

1. Replace complex examples with simple versions
2. Add explicit "DO NOT USE" section
3. Increase all font size examples
4. Remove panel/card helper patterns

## Next Steps

Update `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md`
