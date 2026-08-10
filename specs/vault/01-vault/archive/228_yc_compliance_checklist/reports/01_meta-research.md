# Research Report: Task #228

**Task**: Add YC Compliance Checklist context file
**Date**: 2026-03-18
**Focus**: YC pitch deck design guidelines enforcement

## Summary

Research into Y Combinator pitch deck guidelines reveals three core principles (Legibility, Simplicity, Obviousness) with specific measurable criteria. The current /deck command generates decks that violate these principles through excessive content density and small font sizes.

## Findings

### Kevin Hale's Three Design Principles

1. **Legibility**: Content readable by "old people in the back row with bad eyesight"
   - Minimum 24pt body text
   - Minimum 40pt titles
   - High contrast colors
   - No fine print or small labels

2. **Simplicity**: Each slide communicates ONE idea
   - 5-7 key ideas across entire deck
   - No animations or distracting design
   - Deliberate use of whitespace

3. **Obviousness**: Understood at a glance without explanation
   - 3-second comprehension test
   - Familiar formats and conventions
   - Clear labels, no inside references

### Measurable Enforcement Criteria

| Rule | Threshold | Current Violation |
|------|-----------|-------------------|
| Slide count | Max 10 | Generated 12 |
| Body font | Min 24pt | Uses 17-21pt |
| Title font | Min 40pt | Inconsistent |
| Ideas per slide | Max 1 | Multiple panels |
| Bullets per slide | Max 5 | 10+ on some slides |
| Grid columns | Max 2 | Uses 3-7 columns |

### Anti-Patterns to Prohibit

- Screenshots (break all three rules)
- Multi-column text layouts (>2 columns)
- Nested panels/boxes
- Font sizes below 24pt
- Information overload

## Recommendations

1. Create `yc-compliance-checklist.md` with hard enforcement rules
2. Include pass/fail validation criteria
3. Provide pre-flight checklist for deck validation
4. Document specific Typst patterns to avoid

## References

- [YC: How to build your seed round pitch deck](https://www.ycombinator.com/library/2u-how-to-build-your-seed-round-pitch-deck)
- [YC: How to design a better pitch deck](https://www.ycombinator.com/library/4T-how-to-design-a-better-pitch-deck)
- Kevin Hale's YC design principles

## Next Steps

Create the compliance checklist context file at `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md`
