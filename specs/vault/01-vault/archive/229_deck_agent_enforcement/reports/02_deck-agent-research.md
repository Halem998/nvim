# Research Report: Task #229

**Task**: Update deck-agent with strict YC enforcement
**Date**: 2026-03-18
**Focus**: Detailed deck-agent modification points for YC compliance

## Executive Summary

The deck-agent (409 lines) has clear modification points for YC compliance enforcement. Task 228 created `yc-compliance-checklist.md` with hard limits that must be enforced. This report identifies exact line numbers, code changes, and a validation approach using a `compliance_passed` boolean in return metadata.

## Context Files Analyzed

1. **deck-agent.md** (409 lines) - Current agent definition
2. **yc-compliance-checklist.md** (290 lines) - Hard enforcement rules (Task 228 output)
3. **pitch-deck-structure.md** (254 lines) - YC design principles
4. **touying-pitch-deck-template.md** (397 lines) - Typst patterns
5. **return-metadata-file.md** (503 lines) - Metadata schema for compliance_passed

## Current deck-agent Structure

### Stage Overview

| Stage | Lines | Purpose | Modification Needed |
|-------|-------|---------|---------------------|
| Stage 1 | 80-97 | Parse delegation context | None |
| Stage 2 | 99-114 | Validate inputs | None |
| Stage 3 | 116-125 | Gather content | None |
| Stage 4 | 127-149 | Map content to slides | **Add slide count limit** |
| Stage 5 | 151-216 | Generate Typst content | **Add font size enforcement** |
| Stage 6 | 218-229 | Write output file | None |
| Stage 7 | 231-259 | Return structured JSON | **Add compliance validation** |

### Existing Context References (Lines 33-42)

```markdown
**Always Load**:
- `@context/project/present/patterns/pitch-deck-structure.md`
- `@context/project/present/patterns/touying-pitch-deck-template.md`
```

**Required Addition**: Add yc-compliance-checklist.md to "Always Load".

## Modification Points

### 1. Context References (Line 38-39)

**Current**:
```markdown
**Always Load**:
- `@context/project/present/patterns/pitch-deck-structure.md`
- `@context/project/present/patterns/touying-pitch-deck-template.md`
```

**Modified**:
```markdown
**Always Load**:
- `@context/project/present/patterns/pitch-deck-structure.md`
- `@context/project/present/patterns/touying-pitch-deck-template.md`
- `@context/project/present/patterns/yc-compliance-checklist.md`
```

### 2. Stage 4: Slide Count Enforcement (Lines 127-149)

**Current behavior**: Maps content to 10 slides without validation.

**Insert after line 149** (new section before Stage 5):

```markdown
### Stage 4.5: Enforce Slide Limit

**Hard Limit**: Maximum 10 slides (excluding appendix).

1. Count slides mapped from source content
2. If count > 10:
   - Identify lowest-priority content (typically: closing, business model details)
   - Merge related slides (e.g., combine "Why Us" with "Solution" if thin)
   - Prioritize: Title, Problem, Solution, Traction, Ask (must keep)
3. If count < 10 after merging, proceed
4. If cannot reduce below 10, log violation for compliance check

**Merging Priority**:
| Priority | Slides to Preserve |
|----------|-------------------|
| Critical | 1. Title, 2. Problem, 3. Solution, 4. Traction, 9. The Ask |
| Important | 5. Why Us/Now, 8. Team |
| Mergeable | 6. Business Model, 7. Market, 10. Closing |
```

### 3. Stage 5: Font Size Enforcement (Lines 151-216)

**Current problematic patterns** in template (lines 186-196):

```typst
#set text(size: 30pt, fill: palette-text)
#show heading.where(level: 1): set text(size: 48pt, weight: "bold", fill: palette-primary)
#show heading.where(level: 2): set text(size: 40pt, weight: "bold", fill: palette-primary)
```

These are compliant. However, the touying-pitch-deck-template.md contains violations:

**Non-compliant patterns from template** (referenced by agent):
- Line 85: `#text(size: 24pt)` - borderline (acceptable)
- Lines 154, 161: `#text(size: 20pt)`, `#text(size: 18pt)` - FAIL (below 24pt)
- Lines 188, 199: `#text(size: 22pt)` - FAIL (below 24pt)

**Insert after line 196** (within Stage 5):

```markdown
### Font Size Rules (YC Compliance)

All generated Typst code MUST follow these minimums:

| Element | Minimum | Generated Pattern |
|---------|---------|-------------------|
| Title text | 40pt | `#set text(size: 48pt)` for `heading.where(level: 1)` |
| Slide headers | 40pt | `#set text(size: 40pt)` for `heading.where(level: 2)` |
| Body text | 24pt | `#set text(size: 30pt)` default, never below 24pt |
| Captions/labels | 24pt | `#text(size: 24pt)` minimum for all annotations |

**Prohibited Patterns**:
```typst
// NEVER generate these
#text(size: 20pt)[...]  // Below 24pt minimum
#text(size: 18pt)[...]  // Below 24pt minimum
#text(size: 22pt)[...]  // Below 24pt minimum
```

**Required Patterns**:
```typst
// Always use these or larger
#text(size: 24pt)[...]  // Minimum for any text
#text(size: 28pt)[...]  // Preferred for emphasis
#text(size: 30pt)[...]  // Default body
```
```

### 4. Stage 5: Layout Simplification (Insert after font rules)

```markdown
### Layout Rules (YC Compliance)

**Maximum columns**: 2 (HARD LIMIT)

**Prohibited Patterns**:
```typst
// NEVER generate 3+ column grids
#grid(columns: (1fr, 1fr, 1fr), ...)
#grid(columns: (1fr, 1fr, 1fr, 1fr), ...)
```

**Allowed Patterns**:
```typst
// Single column (preferred)
#block[Content here]

// Two columns (maximum)
#grid(columns: (1fr, 1fr), gutter: 2em, [...], [...])
```

**Maximum bullets per slide**: 5

**Prohibited Patterns**:
```typst
// NEVER generate lists with 6+ items
#list([1], [2], [3], [4], [5], [6])
```

**Content Density Rule**: One main idea per slide. If slide has multiple ideas, split into separate slides (respecting 10-slide limit by merging elsewhere).
```

### 5. Stage 7: Compliance Validation (Lines 231-259)

**Current return structure** (lines 235-259):
```json
{
  "status": "generated",
  "summary": "...",
  "artifacts": [...],
  "metadata": {
    "session_id": "...",
    "theme": "simple",
    "palette": "professional-blue",
    "slide_count": 10,
    "slides_with_todos": 3,
    "input_type": "prompt_only|file_only|prompt_and_file"
  }
}
```

**Insert new Stage 6.5: YC Compliance Validation** (before Stage 7):

```markdown
### Stage 6.5: YC Compliance Validation

Before returning, validate generated deck against yc-compliance-checklist.md.

**Validation Checklist**:

1. **Slide Count**: `slide_count <= 10` (HARD FAIL if exceeded)
2. **Font Sizes**: Scan generated Typst for patterns below 24pt (HARD FAIL)
3. **Column Count**: No `grid(columns: (1fr, 1fr, 1fr+))` patterns (HARD FAIL)
4. **Bullet Count**: No lists with 6+ items (HARD FAIL)
5. **Content Density**: One idea per slide (soft check)

**Validation Implementation**:
```bash
# Count slides (== pattern count)
slide_count=$(grep -c '^==' "$output_path" | head -1)
[ "$slide_count" -le 10 ] || compliance_failed="slide_count"

# Check for small fonts (violations)
if grep -E 'size:\s*(1[0-9]|2[0-3])pt' "$output_path" >/dev/null 2>&1; then
  compliance_failed="font_size"
fi

# Check for 3+ columns
if grep -E 'columns:\s*\([^)]*1fr[^)]*1fr[^)]*1fr' "$output_path" >/dev/null 2>&1; then
  compliance_failed="column_count"
fi
```

**Compliance Result**:
- `compliance_passed: true` - All HARD checks passed
- `compliance_passed: false` - One or more HARD checks failed
- `compliance_violations: ["slide_count", "font_size"]` - List of failures
```

**Modify Stage 7 return structure** to include compliance:

```json
{
  "status": "generated",
  "summary": "Generated 10-slide pitch deck...",
  "artifacts": [...],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 5,
    "agent_type": "deck-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "deck", "skill-deck", "deck-agent"],
    "theme": "simple",
    "palette": "professional-blue",
    "slide_count": 10,
    "slides_with_todos": 3,
    "input_type": "prompt_only|file_only|prompt_and_file",
    "yc_compliance": {
      "compliance_passed": true,
      "violations": [],
      "checks_performed": ["slide_count", "font_size", "column_count", "bullet_count"]
    }
  },
  "next_steps": "Review generated deck and fill in TODO placeholders. Compile with: typst compile pitch-deck.typ"
}
```

### 6. Critical Requirements Update (Lines 389-409)

**Add to MUST DO** (after line 399):

```markdown
9. Enforce 10-slide maximum (excluding appendix)
10. Enforce 24pt minimum body font, 40pt minimum title font
11. Enforce 2-column maximum layout
12. Include compliance_passed boolean in return metadata
13. Reference @context/project/present/patterns/yc-compliance-checklist.md for validation rules
```

**Add to MUST NOT** (after line 408):

```markdown
8. Generate font sizes below 24pt for body text
9. Generate font sizes below 40pt for titles
10. Generate 3+ column grids
11. Generate lists with more than 5 bullets
12. Return compliance_passed: true if any HARD check fails
```

## Implementation Summary

| Change | Location | Impact |
|--------|----------|--------|
| Add context reference | Line 39 | Load yc-compliance-checklist.md |
| Add Stage 4.5 | After line 149 | Slide count enforcement |
| Add font size rules | After line 196 | Prevent small fonts |
| Add layout rules | After font rules | Prevent complex layouts |
| Add Stage 6.5 | Before Stage 7 | Compliance validation |
| Modify metadata schema | Lines 235-259 | Add yc_compliance object |
| Update MUST DO/NOT | Lines 389-409 | Document enforcement |

## Validation Approach

The `yc_compliance` object in return metadata provides:

1. **Binary pass/fail**: `compliance_passed` boolean for quick checks
2. **Detailed violations**: `violations` array for debugging
3. **Audit trail**: `checks_performed` array shows what was validated

This allows skill postflight to:
- Reject non-compliant decks automatically
- Report specific violations to user
- Track compliance rates across generations

## References

- `.claude/extensions/present/agents/deck-agent.md` - Agent to modify
- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` - Enforcement rules (Task 228)
- `.claude/context/core/formats/return-metadata-file.md` - Metadata schema

## Next Steps

Create implementation plan for modifying deck-agent.md with the changes identified above.
