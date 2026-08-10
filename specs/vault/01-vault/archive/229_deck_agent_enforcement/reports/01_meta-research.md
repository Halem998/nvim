# Research Report: Task #229

**Task**: Update deck-agent with strict YC enforcement
**Date**: 2026-03-18
**Focus**: Agent modifications for YC compliance

## Summary

Analysis of the current deck-agent reveals it lacks validation for YC compliance criteria. The agent generates content without enforcing slide counts, font sizes, or content density limits, resulting in non-compliant output.

## Findings

### Current Agent Gaps

1. **No slide count validation**: Agent can generate unlimited slides (currently 12)
2. **No font size enforcement**: Generated Typst uses 17-21pt in many places
3. **No content density checks**: Multiple ideas per slide allowed
4. **Complex layout patterns**: Default templates include multi-column grids

### Required Modifications

**Stage 4 (Map Content to Slides)**:
- Add hard limit: maximum 10 slides
- Combine/merge content if source has more than 10 sections
- Flag excess content for user decision

**Stage 5 (Generate Typst Content)**:
- Enforce minimum font sizes in generated code
- Remove panel/grid complexity patterns
- Simplify default layouts to single-column

**Stage 7 (Return)**:
- Add YC compliance validation before returning
- Include compliance_score in metadata
- Warn on violations

### Font Size Enforcement

Replace current patterns:
```typst
// BEFORE (non-compliant)
#text(size: 17pt, fill: palette-text-dim)[...]

// AFTER (compliant)
#text(size: 24pt, fill: palette-text-dim)[...]
```

### Layout Simplification

Remove complex patterns:
- 3+ column grids
- Nested panels
- Multi-metric displays

Use instead:
- Single column layouts
- Simple bullet lists
- Large text blocks

## Recommendations

1. Add "YC Compliance Validation" section to agent
2. Include @-reference to yc-compliance-checklist.md
3. Add compliance_passed boolean to return metadata
4. Implement content merging for oversized decks

## Next Steps

Update `.claude/extensions/present/agents/deck-agent.md` with enforcement rules
