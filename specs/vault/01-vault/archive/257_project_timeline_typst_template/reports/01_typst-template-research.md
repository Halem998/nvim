# Research Report: Task #257

**Task**: 257 - project_timeline_typst_template
**Started**: 2026-03-23T00:00:00Z
**Completed**: 2026-03-23T00:15:00Z
**Effort**: Medium (research complexity)
**Dependencies**: None - self-contained template
**Sources/Inputs**: Codebase analysis, Web documentation
**Artifacts**: specs/257_project_timeline_typst_template/reports/01_typst-template-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Founder extension already has comprehensive Typst strategy templates with navy color palette
- Two Gantt chart packages available: `timeliney` (coordinate-based) and `gantty` (date-based)
- Fletcher diagrams ideal for dependency arrows; existing patterns in typst extension
- Three-point PERT estimation requires custom visualization (formula: `E = (O + 4M + P) / 6`)
- WBS hierarchy achievable via Fletcher tree diagrams or nested boxes
- Risk matrix pattern already exists in contract-analysis.typ template

## Context & Scope

This research investigates how to create a self-contained Typst template for project timelines, following established founder extension patterns. The template must include:

1. Color palette (reuse navy theme from strategy-template.typ)
2. Page setup (consistent with existing templates)
3. Gantt chart visualization with milestones and dependencies
4. Resource allocation tables
5. Three-point estimation display (PERT formula)
6. WBS hierarchy visualization
7. Risk matrix

## Findings

### Codebase Patterns

#### 1. Navy Color Palette (strategy-template.typ)

The founder extension already defines a professional navy gradient palette:

```typst
#let navy-dark = rgb("#0a2540")
#let navy-medium = rgb("#1a4a7a")
#let navy-light = rgb("#2a5a9a")
#let text-primary = rgb("#1a1a1a")
#let text-muted = rgb("#888888")
#let text-light = rgb("#aaaaaa")
#let fill-header = rgb("#e8eef5")
#let fill-alt-row = rgb("#f8f9fb")
#let fill-callout = rgb("#e8f0fb")
#let fill-warning = rgb("#fff8e8")
#let border-light = rgb("#cccccc")
#let border-warning = rgb("#c87800")
```

**Location**: `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ`

#### 2. Page Setup Pattern

Existing templates use this standard setup:

```typst
set page(
  paper: "us-letter",
  margin: (top: 1.1in, bottom: 1.0in, left: 1.1in, right: 1.1in),
  header: context { ... },
  footer: context { ... },
)

set text(
  font: ("Libertinus Serif", "Linux Libertine", "Georgia"),
  size: 10.5pt,
  fill: text-primary,
)
```

#### 3. Timeline Component (strategy-template.typ:632-676)

A basic timeline visualization already exists:

```typst
#let timeline(phases: ()) = {
  // Numbered circles with connecting lines
  // Shows phase name, duration, description
  // Supports complete/incomplete status
}
```

However, this is a vertical milestone list, not a horizontal Gantt chart.

#### 4. Risk Matrix (contract-analysis.typ:108-167)

A 2x2 risk matrix visualization already exists:

```typst
#let risk-matrix(must-fix: (), negotiate: (), monitor: (), accept: ()) = {
  // Grid layout with colored quadrants
  // High/Low Likelihood vs High/Low Severity
  // Items listed in each quadrant
}
```

This pattern can be adapted for project risk management.

#### 5. Table Patterns

Alternating row styling with header emphasis:

```typst
set table(
  stroke: (x, y) => {
    if y == 0 { (bottom: 1.2pt + navy-medium) }
    else { (bottom: 0.4pt + border-light) }
  },
  fill: (x, y) => {
    if y == 0 { fill-header }
    else if calc.odd(y) { fill-alt-row }
    else { white }
  },
  inset: (x: 0.7em, y: 0.55em),
)
```

### External Resources

#### 1. Gantt Chart Packages

**Timeliney** (`@preview/timeliney:0.4.0`)
- Coordinate-based Gantt charts
- Functions: `timeline()`, `headerline()`, `group()`, `taskgroup()`, `task()`, `milestone()`
- Milestone markers with dashed stroke support
- Good for relative timelines (week 1, week 2, etc.)

```typst
#import "@preview/timeliney:0.4.0"

timeliney.timeline(
  show-grid: true,
  {
    headerline(group(([*Q1*], 3)), group(([*Q2*], 3)))
    taskgroup(
      title: [Development],
      task("Backend", (from: 0, to: 2)),
      task("Frontend", (from: 1, to: 3)),
    )
    milestone(at: 2, style: (stroke: (dash: "dashed")))
  }
)
```

**Gantty** (`@preview/gantty:0.5.1`)
- Real date-based Gantt charts
- YAML configuration for tasks
- Dependencies via task IDs
- Multiple header levels (year, month, week, day)
- Better for actual project schedules

```typst
#import "@preview/gantty:0.5.1": gantt

#gantt(yaml(
  show-today: true,
  headers: [year, month],
  tasks: [
    { name: "Planning", intervals: [{ start: "2026-01-01", end: "2026-01-15" }] },
    { name: "Development", id: "dev", intervals: [{ start: "2026-01-16", end: "2026-03-01" }] },
    { name: "Testing", dependencies: ["dev"], intervals: [{ start: "2026-03-01", end: "2026-03-15" }] }
  ],
  milestones: [
    { name: "MVP Release", date: "2026-02-15", show-date: true }
  ]
))
```

**Recommendation**: Use `gantty` for full-featured Gantt charts with dependencies. Use `timeliney` for simpler relative timelines.

#### 2. Three-Point PERT Estimation

The PERT formula for weighted average estimation:

```
E = (O + 4M + P) / 6

Where:
- O = Optimistic estimate
- M = Most Likely estimate
- P = Pessimistic estimate
- E = Expected value
```

**Standard Deviation**: `SD = (P - O) / 6`

**Visualization approach**: Create a custom component showing:
- Three input values in labeled boxes
- Formula breakdown
- Expected value prominently displayed
- Optional: confidence interval (E +/- 2*SD for 95%)

#### 3. Fletcher for Dependency Arrows

For dependency visualization and WBS trees, Fletcher provides arrow/edge capabilities:

```typst
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Dependency diagram
#fletcher.diagram(
  node((0, 0), [Task A], name: <a>),
  node((1, 0), [Task B], name: <b>),
  node((2, 0), [Task C], name: <c>),
  edge(<a>, <b>, "->"),
  edge(<b>, <c>, "->"),
)
```

#### 4. WBS Hierarchy

Work Breakdown Structure as tree diagram using Fletcher:

```typst
#fletcher.diagram(
  spacing: (12pt, 20pt),
  // Level 0: Project
  node((0, 1), [*Project Name*], name: <root>, fill: navy-dark, stroke: none),
  // Level 1: Phases
  node((1, 0), [Phase 1], name: <p1>, fill: fill-header),
  node((1, 2), [Phase 2], name: <p2>, fill: fill-header),
  // Level 2: Tasks
  node((2, 0), [Task 1.1], name: <t11>),
  node((2, 1), [Task 2.1], name: <t21>),
  // Edges
  edge(<root>, <p1>, "->"),
  edge(<root>, <p2>, "->"),
  edge(<p1>, <t11>, "->"),
  edge(<p2>, <t21>, "->"),
)
```

Alternatively, use nested boxes similar to the `nested-market-diagram` pattern in strategy-template.typ.

### Recommendations

#### Implementation Approach

1. **Base Template**: Import and extend `strategy-template.typ` for color palette, typography, and page setup

2. **Gantt Chart**: Create a wrapper function around `gantty` with:
   - Navy-themed styling
   - Critical path highlighting (red/orange for critical tasks)
   - Milestone markers in navy-dark
   - Dependency arrows auto-rendered by gantty

3. **Three-Point Estimation**: Custom component:
   ```typst
   #let pert-estimate(
     optimistic: 0,
     likely: 0,
     pessimistic: 0,
     label: "Duration"
   ) = {
     let expected = (optimistic + 4 * likely + pessimistic) / 6
     let stddev = (pessimistic - optimistic) / 6
     // Render visualization
   }
   ```

4. **Resource Allocation Table**: Use existing table patterns with:
   - Person column (left)
   - Task assignments per period (colored cells)
   - Capacity percentage row

5. **WBS Hierarchy**: Fletcher-based tree or collapsible nested boxes

6. **Risk Matrix**: Adapt `risk-matrix` from contract-analysis.typ with:
   - Project-specific terminology (Impact vs Likelihood)
   - Color-coded quadrants (red/orange/yellow/green)

#### File Structure

```
.claude/extensions/founder/context/project/founder/templates/typst/
  strategy-template.typ         # Base (already exists)
  project-timeline.typ          # NEW - Project timeline template
```

#### Template Structure

```typst
// project-timeline.typ

#import "strategy-template.typ": *
#import "@preview/gantty:0.5.1": gantt
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Additional timeline-specific colors
#let critical-path = rgb("#dc2626")
#let milestone-marker = navy-dark
#let progress-complete = rgb("#16a34a")

// PERT three-point estimate component
#let pert-estimate(...) = { ... }

// Resource allocation matrix
#let resource-matrix(...) = { ... }

// WBS tree diagram
#let wbs-tree(...) = { ... }

// Project risk matrix (extends contract risk-matrix)
#let project-risk-matrix(...) = { ... }

// Main document wrapper
#let project-timeline-doc(...) = { ... }
```

## Decisions

1. **Use gantty over timeliney**: Real date support and built-in dependency tracking are essential for project timelines
2. **Extend strategy-template.typ**: Reuse existing color palette and typography rather than duplicating
3. **Fletcher for WBS**: Provides more flexibility than nested boxes for arbitrary tree structures
4. **Custom PERT component**: No existing package - must build from scratch
5. **Adapt existing risk-matrix**: Modify contract-analysis pattern for project context

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Gantty may not support critical path highlighting natively | Medium | Add post-processing overlay or use custom task styling |
| Fletcher + Gantty may conflict | Low | Test import compatibility early; they use different rendering |
| PERT formula rounding | Low | Use calc.round() for display while keeping full precision internally |
| WBS with many levels may overflow | Medium | Add horizontal scrolling or page-break support |

## Context Extension Recommendations

None for meta tasks - context updates happen through task implementation.

## Appendix

### Search Queries Used

1. "Typst Gantt chart package timeline visualization 2026"
2. "PERT three-point estimation formula visualization project management"
3. "Typst WBS work breakdown structure tree diagram"

### References

- [Timeliney - Typst Universe](https://typst.app/universe/package/timeliney/)
- [Gantty - Typst Universe](https://typst.app/universe/package/gantty/)
- [GitHub - typst-timeliney](https://github.com/pta2002/typst-timeliney)
- [Three-Point Estimation - Wikipedia](https://en.wikipedia.org/wiki/Three-point_estimation)
- [PERT Estimation - Project Management Academy](https://projectmanagementacademy.net/resources/blog/a-three-point-estimating-technique-pert/)
- [WBS Diagram Syntax - PlantUML](https://plantuml.com/wbs-diagram)

### Codebase Files Examined

- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ`
- `.claude/extensions/typst/context/project/typst/patterns/fletcher-diagrams.md`
- `.claude/extensions/typst/context/project/typst/patterns/tables-and-figures.md`
- `.claude/extensions/typst/context/project/typst/patterns/styling-patterns.md`
- `.claude/extensions/typst/context/project/typst/typst-packages.md`
