# Research Report: Task #246

**Task**: 246 - upgrade_founder_typst_templates_professional
**Started**: 2026-03-19T12:00:00Z
**Completed**: 2026-03-19T12:30:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**:
- Reference template: `/home/benjamin/Projects/Logos/Vision/strategy/market-sizing-condensed.typ` (564 lines)
- Existing templates in `.claude/extensions/founder/context/project/founder/templates/typst/`
**Artifacts**:
- This report: `specs/246_upgrade_founder_typst_templates_professional/reports/01_typst-template-upgrade.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The reference template uses a professional navy/blue color palette (#0a2540, #1a4a7a, #2a5a9a) with Libertinus Serif font, while existing founder templates use generic gray styling with New Computer Modern font
- Key components to extract: `metric()` pill function, `callout()` box function, professional heading styles with colored underlines, alternating row tables, and nested market visualization diagram
- Implementation requires complete rewrite of `strategy-template.typ` plus updates to all dependent templates
- The reference template is self-contained (no imports), which aligns well with the founder-implement-agent's inline generation pattern

## Context & Scope

This research analyzes the styling system used in a professional market-sizing document and compares it against the existing founder extension templates. The goal is to upgrade the founder templates to produce professional PDF reports matching the reference quality.

### Reference Template Location
`/home/benjamin/Projects/Logos/Vision/strategy/market-sizing-condensed.typ` (564 lines)

### Existing Templates
- `strategy-template.typ` (480 lines) - Base template with generic styling
- `market-sizing.typ` (207 lines) - Market sizing document wrapper
- `competitive-analysis.typ` (247 lines) - Competitive analysis wrapper
- `gtm-strategy.typ` (297 lines) - GTM strategy wrapper

## Findings

### 1. Color Palette Comparison

**Reference Template (Professional)**:
| Purpose | Color | Hex Code |
|---------|-------|----------|
| Primary (headings, pills) | Dark Navy | `#0a2540` |
| Secondary (subheadings) | Medium Navy | `#1a4a7a` |
| Tertiary (H3) | Blue | `#2a5a9a` |
| Body text | Near Black | `#1a1a1a` |
| Muted text | Gray | `#888888` |
| Light muted | Light Gray | `#aaaaaa` |
| Table header fill | Light Blue | `#e8eef5` |
| Table alt row | Off White | `#f8f9fb` |
| Callout fill | Light Blue | `#e8f0fb` |
| Warning callout | Light Orange | `#fff8e8` |
| Warning border | Orange | `#c87800` |

**Existing Templates (Generic)**:
| Purpose | Color | Hex Code |
|---------|-------|----------|
| Heading text | Default black | (no override) |
| Table header | Slate | `#f1f5f9` |
| Highlight box | Blue border | `#2563eb` |
| Warning box | Red border | `#dc2626` |
| Success box | Green border | `#16a34a` |
| Metric callout fill | Teal | `#e8f4f8` |

**Gap**: Existing templates use a generic blue/red/green scheme with no cohesive brand palette. The reference uses a consistent navy-to-blue gradient creating professional visual hierarchy.

### 2. Typography Comparison

**Reference Template**:
```typst
#set text(
  font: "Libertinus Serif",
  size: 10.5pt,
  fill: rgb("#1a1a1a"),
  hyphenate: false,
)

#set par(
  justify: true,
  leading: 0.65em,
  spacing: 0.85em,
)
```

**Existing Templates**:
```typst
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.65em)
```

**Gap**: Missing font color specification, smaller body size, and no paragraph spacing configuration.

### 3. Heading Styles

**Reference Template** - Professional headings with colored underlines:

**Level 1**:
```typst
#show heading.where(level: 1): it => {
  v(1.4em)
  block[
    #set text(size: 16pt, weight: "bold", fill: rgb("#0a2540"))
    #it.body
    #v(0.15em)
    #line(length: 100%, stroke: 1.5pt + rgb("#0a2540"))
  ]
  v(0.5em)
}
```

**Level 2**:
```typst
#show heading.where(level: 2): it => {
  v(1.1em)
  block[
    #set text(size: 13pt, weight: "bold", fill: rgb("#1a4a7a"))
    #it.body
    #v(0.1em)
    #line(length: 100%, stroke: 0.7pt + rgb("#1a4a7a"))
  ]
  v(0.35em)
}
```

**Level 3**:
```typst
#show heading.where(level: 3): it => {
  v(0.9em)
  block[
    #set text(size: 11pt, weight: "bold", fill: rgb("#2a5a9a"))
    #it.body
  ]
  v(0.25em)
}
```

**Existing Templates**:
```typst
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(0.5em)
  text(size: 18pt, weight: "bold")[#it]
  v(0.5em)
}
```

**Gap**: Existing templates use default black headings with no underlines, forced pagebreaks, and heading numbers. Reference uses colored headings with elegant underlines and no numbering.

### 4. Table Styling

**Reference Template** - Professional tables with header emphasis and alternating rows:
```typst
#set table(
  stroke: (x, y) => {
    if y == 0 { (bottom: 1.2pt + rgb("#1a4a7a")) }
    else { (bottom: 0.4pt + rgb("#cccccc")) }
  },
  fill: (x, y) => {
    if y == 0 { rgb("#e8eef5") }
    else if calc.odd(y) { rgb("#f8f9fb") }
    else { white }
  },
  inset: (x: 0.7em, y: 0.55em),
)

#show table: it => {
  set text(size: 9.5pt)
  it
}
```

**Existing Templates**:
```typst
#set table(
  stroke: 0.5pt + gray,
  inset: 8pt,
)
#show table.cell.where(y: 0): strong
```

**Gap**: Existing tables use uniform gray strokes without alternating rows or header styling. Reference uses conditional strokes and fills for professional appearance.

### 5. Helper Functions

#### metric() - Pill Display

**Reference Template**:
```typst
#let metric(label, value) = box(
  fill: rgb("#0a2540"),
  radius: 3pt,
  inset: (x: 0.6em, y: 0.3em),
)[
  #set text(fill: white, size: 9pt)
  #strong[#label:] #value
]
```
Usage: `#metric("TAM", "$16.2B")` displays as dark navy pill with white text.

**Existing Templates**:
```typst
#let metric-callout(label, value, subtitle: none) = {
  rect(
    width: 100%,
    fill: rgb("#e8f4f8"),
    inset: 12pt,
    radius: 4pt,
  )[
    #align(center)[
      #text(size: 10pt, fill: gray)[#label]
      #v(0.2em)
      #text(size: 24pt, weight: "bold")[#value]
      ...
    ]
  ]
}
```

**Gap**: Existing uses large centered callout boxes. Reference uses compact inline pills suitable for key metrics row.

#### callout() - Highlighted Box

**Reference Template**:
```typst
#let callout(body, color: rgb("#e8f0fb"), border: rgb("#1a4a7a")) = block(
  fill: color,
  stroke: (left: 3pt + border),
  radius: (right: 4pt),
  inset: (x: 1em, y: 0.7em),
  width: 100%,
  body,
)
```

**Existing Templates** (`highlight-box`):
```typst
#let highlight-box(title: "Key Insight", content) = {
  rect(
    width: 100%,
    stroke: (left: 3pt + rgb("#2563eb")),
    fill: rgb("#f0f7ff"),
    inset: 12pt,
  )[
    #text(weight: "bold", fill: rgb("#2563eb"))[#title]
    #v(0.3em)
    #content
  ]
}
```

**Gap**: Similar structure but different colors. Existing has forced title; reference is more flexible.

### 6. Block Quote Style

**Reference Template**:
```typst
#show quote: it => {
  pad(left: 1.4em)[
    #line(start: (-1.4em, 0pt), length: 3pt, stroke: 2.5pt + rgb("#1a4a7a"))
    #set text(style: "italic", fill: rgb("#333333"))
    #it
  ]
}
```

**Existing Templates**: No custom quote styling.

### 7. Page Header/Footer

**Reference Template**:
```typst
#set page(
  paper: "us-letter",
  margin: (top: 1.1in, bottom: 1.0in, left: 1.1in, right: 1.1in),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 8pt, fill: rgb("#888888"))
      #grid(
        columns: (1fr, auto),
        [Logos Laboratories - Market Sizing (Condensed)],
        align(right)[#counter(page).display()],
      )
      #line(length: 100%, stroke: 0.4pt + rgb("#cccccc"))
    ]
  },
  footer: context {
    set text(size: 7.5pt, fill: rgb("#aaaaaa"))
    align(center)[Confidential - Logos Laboratories #sym.dot 2026-03-18]
  },
)
```

**Existing Templates**:
```typst
header: context {
  if counter(page).get().first() > 1 [
    #set text(size: 9pt, fill: gray)
    #project #h(1fr) #title
  ]
},
footer: context {
  set text(size: 9pt, fill: gray)
  h(1fr)
  counter(page).display("1 / 1", both: true)
  h(1fr)
},
```

**Gap**: Existing header lacks divider line. Footer uses page count format instead of confidentiality statement.

### 8. Nested Market Visualization (TAM/SAM/SOM)

**Reference Template** - Professional nested box diagram (lines 326-389):
```typst
#figure(
  block(width: 100%)[
    // Outer box: TAM
    #block(
      fill: rgb("#e8eef5"),
      stroke: 1.2pt + rgb("#1a4a7a"),
      radius: 6pt,
      inset: (x: 1.4em, y: 1.1em),
      width: 100%,
    )[
      // TAM content...
      // Middle box: SAM
      #block(
        fill: rgb("#d0dcea"),
        stroke: 1pt + rgb("#1a4a7a"),
        radius: 5pt,
        ...
      )[
        // SAM content...
        // Inner box: SOM
        #block(
          fill: rgb("#b8cce0"),
          stroke: 0.8pt + rgb("#1a4a7a"),
          ...
        )[...]
      ]
    ]
  ],
  caption: [TAM / SAM / SOM market sizing - nested view],
)
```

**Existing Templates** (`market-circles`): Uses colored circles with blue/green/yellow scheme. More complex positioning with negative vertical offsets.

**Gap**: Reference uses cleaner nested boxes with consistent navy palette. Existing circles are harder to render correctly.

### 9. Valuation Comparable Block

**Reference Template** (lines 441-466) - Dark navy comparison block:
```typst
#block(
  fill: rgb("#0a2540"),
  radius: 6pt,
  inset: (x: 1.4em, y: 1.0em),
  width: 100%,
)[
  #set text(fill: white, size: 10pt)
  #grid(
    columns: (0.5fr, 0.5fr),
    column-gutter: 2em,
    [
      #block[#set text(size: 12pt, weight: "bold"); Harvey AI (Dec 2025)]
      #v(0.3em)
      ARR: \$195M #linebreak()
      Valuation: \$8B #linebreak()
      Multiple: ~41x revenue
    ],
    [...]
  )
]
```

**Existing Templates**: No equivalent. Would need new helper function.

### 10. Document Structure

**Reference Template Sections**:
1. Title Page (centered, metrics pills, value proposition callout)
2. Executive Summary (with metrics table)
3. Revenue Model (multi-table with unit economics)
4. Market Sizing (TAM/SAM/SOM with nested diagram)
5. Valuation and Funding (dark comparison block)
6. Competitive Position (quote styling, technical assets table)
7. Key Risks (warning callout)
8. Document footer

**Existing Market-Sizing Template Sections**:
1. Title Page
2. Executive Summary (with metric row)
3. Market Definition
4. TAM Section
5. SAM Section
6. SOM Section
7. Market Visualization (circles)
8. Key Assumptions
9. Red Flags & Validation
10. Investor One-Pager
11. Appendices

**Gap**: Reference is more compact (8-12 pages vs comprehensive). Structure is content-driven rather than section-template-driven.

## Recommendations

### Implementation Strategy

#### File 1: `strategy-template.typ` - Complete Rewrite

Replace all styling with professional palette:

1. **Color Constants** (add at top):
```typst
// Professional color palette
#let navy-dark = rgb("#0a2540")
#let navy-medium = rgb("#1a4a7a")
#let navy-light = rgb("#2a5a9a")
#let text-primary = rgb("#1a1a1a")
#let text-muted = rgb("#888888")
#let text-light = rgb("#aaaaaa")
#let fill-header = rgb("#e8eef5")
#let fill-alt-row = rgb("#f8f9fb")
#let fill-callout = rgb("#e8f0fb")
#let border-light = rgb("#cccccc")
```

2. **Typography**:
```typst
#set text(
  font: "Libertinus Serif",
  size: 10.5pt,
  fill: text-primary,
  hyphenate: false,
)
```

3. **Heading Styles**: Use reference patterns with colored underlines

4. **Table Styling**: Use conditional stroke/fill pattern

5. **New Helper Functions**:
   - `metric(label, value)` - Inline pill (dark navy)
   - `callout(body, color: fill-callout, border: navy-medium)` - Flexible callout
   - `comparison-block(left, right)` - Dark navy side-by-side
   - `nested-market-diagram(tam, sam, som)` - Professional nested boxes

6. **Replace/Update Existing Functions**:
   - `metric-callout` -> Keep for large displays, update colors
   - `highlight-box` -> Update to navy palette
   - `warning-box` -> Keep orange for warnings
   - `market-circles` -> Replace with `nested-market-diagram`

#### File 2: `market-sizing.typ` - Structure Update

Update section structure to match condensed reference:
- Move TAM/SAM/SOM summary table to Executive Summary
- Consolidate Market Definition sections
- Add Revenue Model section template
- Use new nested diagram for visualization

#### Files 3-4: `competitive-analysis.typ`, `gtm-strategy.typ`

Apply color palette updates:
- Replace `#2563eb` (blue) with `#1a4a7a` (navy-medium)
- Replace `#f0f7ff` (light blue) with `#e8f0fb` (fill-callout)
- Update table styling to use alternating rows

#### File 5: `founder-implement-agent.md`

Update Phase 5 inline generation example:
- Replace "New Computer Modern" with "Libertinus Serif"
- Add color constants at top
- Update heading show rules
- Update table styling
- Show metric() pill usage in title section

### Shared vs Template-Specific

| Component | Shared (strategy-template) | Template-Specific |
|-----------|---------------------------|-------------------|
| Color palette | Yes | - |
| Typography | Yes | - |
| Heading styles | Yes | - |
| Table styling | Yes | - |
| metric() pill | Yes | - |
| callout() | Yes | - |
| nested-market-diagram() | Yes | - |
| comparison-block() | Yes | - |
| market-sizing-doc wrapper | - | market-sizing.typ |
| competitive-analysis-doc wrapper | - | competitive-analysis.typ |
| gtm-strategy-doc wrapper | - | gtm-strategy.typ |
| battle-card | - | competitive-analysis.typ |
| timeline | - | gtm-strategy.typ |

## Decisions

1. **Font Choice**: Use Libertinus Serif (matches reference, professional appearance, widely available)
2. **Color Palette**: Adopt full navy gradient from reference
3. **Heading Style**: Use colored underlines without numbering (cleaner, more modern)
4. **Market Diagram**: Replace circles with nested boxes (easier to render, cleaner appearance)
5. **Inline Generation**: Continue self-contained pattern (no imports), but use consistent style constants

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Libertinus Serif font not installed | Compilation fails | Add fallback: `font: ("Libertinus Serif", "Linux Libertine", "Georgia")` |
| Breaking changes to helper functions | Existing generated docs fail | Templates are generated per-task; no persistent docs to break |
| Color palette too dark for some displays | Readability issues | Test on multiple displays; ensure sufficient contrast |
| Complex nested diagram rendering | Layout issues | Thoroughly test with various content lengths |

## Code Snippets to Use

### Professional Page Setup
```typst
#set page(
  paper: "us-letter",
  margin: (top: 1.1in, bottom: 1.0in, left: 1.1in, right: 1.1in),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 8pt, fill: rgb("#888888"))
      #grid(
        columns: (1fr, auto),
        [#project_name - #title],
        align(right)[#counter(page).display()],
      )
      #line(length: 100%, stroke: 0.4pt + rgb("#cccccc"))
    ]
  },
  footer: context {
    set text(size: 7.5pt, fill: rgb("#aaaaaa"))
    align(center)[Confidential - #project_name #sym.dot #date]
  },
)
```

### Title Page with Metrics Pills
```typst
#v(2em)
#align(center)[
  #block[
    #set text(size: 22pt, weight: "bold", fill: rgb("#0a2540"))
    Market Sizing Analysis
  ]
  #v(0.3em)
  #block[
    #set text(size: 14pt, weight: "regular", fill: rgb("#1a4a7a"))
    Revenue-First Narrative - #project_name
  ]
  #v(1.2em)
  #line(length: 60%, stroke: 1.5pt + rgb("#0a2540"))
  #v(1.2em)
  #grid(
    columns: (auto, auto),
    column-gutter: 2em,
    row-gutter: 0.5em,
    align: (right, left),
    strong[Date:], [#date],
    strong[Version:], [#version],
    strong[Focus:], [#focus],
  )
]

#v(1.5em)

// Key metrics pills
#align(center)[
  #metric("TAM", tam_value) #h(0.8em)
  #metric("SAM", sam_value) #h(0.8em)
  #metric("SOM Y3", som_y3_value) #h(0.8em)
  #metric("Seed Ask", funding_ask)
]

#v(1.5em)

#callout[
  *Value Proposition:* #value_proposition
]
```

### Nested Market Diagram
```typst
#let nested-market-diagram(tam, sam, som, tam-breakdown: none, som-years: none) = {
  figure(
    block(width: 100%)[
      #block(
        fill: rgb("#e8eef5"),
        stroke: 1.2pt + rgb("#1a4a7a"),
        radius: 6pt,
        inset: (x: 1.4em, y: 1.1em),
        width: 100%,
      )[
        #set text(size: 9.5pt)
        #block[
          #set text(size: 11pt, weight: "bold", fill: rgb("#0a2540"))
          FILTERED TAM: #tam
        ]
        #if tam-breakdown != none [
          #set text(size: 9pt, fill: rgb("#333333"))
          #tam-breakdown
        ]
        #v(0.8em)
        #block(
          fill: rgb("#d0dcea"),
          stroke: 1pt + rgb("#1a4a7a"),
          radius: 5pt,
          inset: (x: 1.2em, y: 0.9em),
          width: 88%,
        )[
          #block[
            #set text(size: 10.5pt, weight: "bold", fill: rgb("#0a2540"))
            SAM: #sam
          ]
          #set text(size: 8.5pt, fill: rgb("#333333"))
          Serviceable market with geographic and segment filters
          #v(0.7em)
          #block(
            fill: rgb("#b8cce0"),
            stroke: 0.8pt + rgb("#1a4a7a"),
            radius: 4pt,
            inset: (x: 1em, y: 0.8em),
            width: 85%,
          )[
            #block[
              #set text(size: 10pt, weight: "bold", fill: rgb("#0a2540"))
              SOM (Conservative - Aggressive)
            ]
            #set text(size: 8.5pt, fill: rgb("#1a1a1a"))
            #if som-years != none [
              #grid(
                columns: (auto, auto),
                column-gutter: 2em,
                row-gutter: 0.25em,
                ..som-years.flatten()
              )
            ] else [
              #som
            ]
          ]
        ]
      ]
    ],
    caption: [TAM / SAM / SOM market sizing - nested view],
  )
}
```

## Appendix

### Full Reference Template Analysis

The reference template (`market-sizing-condensed.typ`) demonstrates a mature, production-ready style system. Key design principles observed:

1. **Consistent Visual Hierarchy**: Navy gradient creates clear information hierarchy
2. **Restrained Color Use**: Only navy/blue for emphasis; no competing accent colors
3. **Professional Typography**: Serif font with careful spacing
4. **Functional Styling**: Every style choice serves readability or information architecture
5. **Self-Contained**: No external dependencies; all styles defined inline

### Font Availability

Libertinus Serif is available in:
- NixOS: `pkgs.libertinus`
- macOS: Install via Homebrew or download
- Linux: `fonts-libertinus` package
- Windows: Download from CTAN

Fallback chain should be: `"Libertinus Serif", "Linux Libertine", "Georgia", serif`
