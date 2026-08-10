# Research Report: Task #231

**Task**: Update pitch-deck-structure with stricter guidelines
**Date**: 2026-03-18
**Focus**: Content density and typography enforcement

## Summary

The pitch-deck-structure.md file documents YC guidelines but lacks enforcement language and specific validation criteria. Updates needed to make guidelines prescriptive rather than advisory.

## Findings

### Current Documentation Gaps

1. **Design Principles section**: Documents principles but doesn't mandate
2. **Anti-Patterns section**: Lists issues but allows flexibility
3. **No validation checklist**: No pass/fail criteria
4. **Missing density rules**: Content per slide not specified

### Sections to Add/Update

**New Section: Content Density Rules**
- Maximum 1 main idea per slide
- Maximum 5 bullet points per slide
- Maximum 30 words of body text per slide
- No nested lists

**New Section: Typography Enforcement**
- Minimum body: 24pt (HARD LIMIT)
- Minimum titles: 40pt (HARD LIMIT)
- Minimum bullets: 24pt
- No text below 20pt for any element

**Updated Anti-Patterns Section**
- Strengthen from "avoid" to "PROHIBITED"
- Add specific Typst patterns that violate rules
- Include regex patterns for validation

**New Section: Validation Checklist**
- Pre-generation checklist
- Post-generation verification
- Pass/fail criteria

## Recommendations

1. Convert guidelines from advisory to mandatory
2. Add specific numeric thresholds
3. Include validation patterns
4. Cross-reference yc-compliance-checklist.md

## Next Steps

Update `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md`
