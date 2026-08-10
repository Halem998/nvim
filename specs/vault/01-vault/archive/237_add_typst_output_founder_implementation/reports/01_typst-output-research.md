# Research Report: Task #237

**Task**: 237 - add_typst_output_founder_implementation
**Started**: 2026-03-18
**Completed**: 2026-03-18
**Effort**: 2-4 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration (.claude/extensions/founder/, .claude/extensions/typst/)
- Existing templates, agents, and skills
- typst extension patterns for reference
**Artifacts**:
- `specs/237_add_typst_output_founder_implementation/reports/01_typst-output-research.md` (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder extension needs typst templates and a typst generation phase added to founder-implement-agent
- Templates should be self-contained in `.claude/extensions/founder/context/project/founder/templates/typst/` to maintain independence from the typst extension
- The implementation plan should specify typst output in a new Phase 5, with template selection based on report type (market-sizing, competitive-analysis, gtm-strategy)
- Output location should be `founder/` directory at repository root for professional PDF deliverables

## Context & Scope

The goal is to enable `/implement` on founder tasks (language: founder) to generate professionally formatted typst documents in addition to the existing markdown reports. This should:

1. Maintain modularity - founder extension should not depend on typst extension
2. Use templates stored within the founder extension
3. Generate output in `founder/` directory (not `strategy/`)
4. Be specified in the plan so founder-implement-agent knows exactly what to produce

## Findings

### Current Founder Extension Structure

```
.claude/extensions/founder/
+-- manifest.json                 # Extension manifest
+-- EXTENSION.md                  # Documentation
+-- index-entries.json            # Context discovery entries
+-- agents/
|   +-- founder-implement-agent.md   # Implementation agent
|   +-- founder-plan-agent.md        # Planning agent
|   +-- market-agent.md              # Market sizing agent
|   +-- analyze-agent.md             # Competitive analysis agent
|   +-- strategy-agent.md            # GTM strategy agent
+-- skills/
|   +-- skill-founder-implement/     # Implementation skill
|   +-- skill-founder-plan/          # Planning skill
|   +-- skill-market/                # Market command skill
|   +-- skill-analyze/               # Analyze command skill
|   +-- skill-strategy/              # Strategy command skill
+-- commands/
|   +-- market.md
|   +-- analyze.md
|   +-- strategy.md
+-- context/project/founder/
    +-- domain/
    |   +-- business-frameworks.md
    |   +-- strategic-thinking.md
    +-- patterns/
    |   +-- forcing-questions.md
    |   +-- decision-making.md
    |   +-- mode-selection.md
    +-- templates/
        +-- market-sizing.md       # Markdown template
        +-- competitive-analysis.md # Markdown template
        +-- gtm-strategy.md        # Markdown template
```

### Current Report Output Flow

1. `/market`, `/analyze`, `/strategy` commands create tasks with `language: founder`
2. `/plan N` routes to `skill-founder-plan` -> `founder-plan-agent`
3. `/implement N` routes to `skill-founder-implement` -> `founder-implement-agent`
4. founder-implement-agent generates markdown reports to `strategy/{report-type}-{slug}.md`

### Typst Extension Patterns (For Reference)

The typst extension provides excellent patterns to follow:

**Template Structure** (from typst/templates/report-template.md):
```typst
#set document(title: "...", author: "...")
#set page(paper: "a4", margin: ...)
#set text(font: "New Computer Modern", size: 11pt)
// ... setup rules

// Title page
#align(center)[...]

// Content
= Introduction
...
```

**Key Features**:
- Document metadata via `#set document()`
- Page setup via `#set page()`
- Typography via `#set text()`
- Show rules for custom heading styles
- Professional title page layout

### Recommended Typst Templates for Founder

Three templates needed, corresponding to the three report types:

#### 1. Market Sizing Typst Template

Should include:
- Executive title page with TAM/SAM/SOM summary
- Concentric circle visualization (rendered in Typst)
- Tables for methodology comparison
- Key assumptions section with highlighting
- Investor one-pager as final page

#### 2. Competitive Analysis Typst Template

Should include:
- Executive title page with positioning statement
- 2x2 positioning map visualization
- Competitor profile cards
- Feature comparison table
- Battle cards formatted for printing

#### 3. GTM Strategy Typst Template

Should include:
- Executive title page with positioning statement
- 90-day timeline visualization
- Channel prioritization matrix
- Metrics dashboard layout
- Action item checklist

### Implementation Requirements

#### 1. New Template Directory

Create: `.claude/extensions/founder/context/project/founder/templates/typst/`

Files needed:
```
templates/typst/
+-- strategy-template.typ        # Base template with shared styles
+-- market-sizing.typ            # Market sizing document template
+-- competitive-analysis.typ     # Competitive analysis template
+-- gtm-strategy.typ             # GTM strategy template
+-- shared-notation.typ          # Common notation/macros (optional)
```

#### 2. Template Content Structure

Each template should:
- Import shared styles from strategy-template.typ
- Define report-specific sections matching markdown template
- Include placeholders for dynamic content
- Use Typst tables and figures for visualizations

Example structure for market-sizing.typ:
```typst
#import "strategy-template.typ": *

// Document metadata
#let report-meta = (
  title: "{project_name} Market Sizing",
  date: "{date}",
  mode: "{mode}",
  author: "Claude",
)

#show: strategy-doc.with(..report-meta)

// Executive Summary
= Executive Summary
{executive_summary}

// Market Definition
= Market Definition
== Problem Statement
{problem_statement}

== Target Customer
{target_customer_table}

// TAM Section with visualization
= TAM: Total Addressable Market
...
```

#### 3. founder-implement-agent Modifications

Add Phase 5 to the agent:

```markdown
### Phase 5: Typst Document Generation [NOT STARTED]

**Objectives**:
1. Generate typst document from markdown report
2. Compile to PDF
3. Verify PDF exists and is non-empty

**Inputs**:
- Markdown report from Phase 4
- Report type (market-sizing, competitive-analysis, gtm-strategy)
- Typst template from founder extension

**Steps**:
1. Select appropriate typst template based on report type
2. Transform markdown content to typst format
3. Write .typ file to `founder/{report-type}-{slug}.typ`
4. Run `typst compile` to generate PDF
5. Verify PDF exists

**Outputs**:
- `founder/{report-type}-{slug}.typ` - Typst source file
- `founder/{report-type}-{slug}.pdf` - Compiled PDF
```

#### 4. Content Transformation Approach

Two options for markdown-to-typst conversion:

**Option A: Direct Generation (Recommended)**
- Agent generates typst directly from gathered context
- Uses template as structural guide
- More control over formatting
- Cleaner typst output

**Option B: Markdown Parsing**
- Agent reads markdown report
- Transforms sections to typst equivalents
- Risk of parsing complexity

Recommendation: **Option A** - Generate typst directly from the same context used for markdown.

#### 5. founder-plan-agent Modifications

Update plan template to include Phase 5:

```markdown
### Phase 5: Typst Document Generation [NOT STARTED]

**Objectives**:
1. Generate professional typst document
2. Compile to PDF

**Template**: @.claude/extensions/founder/context/project/founder/templates/typst/{report-type}.typ

**Output**: founder/{report-type}-{slug}.pdf
```

#### 6. Output Location

Change from current `strategy/` to `founder/` directory:

| Output Type | Path |
|-------------|------|
| Markdown Report | `strategy/{report-type}-{slug}.md` |
| Typst Source | `founder/{report-type}-{slug}.typ` |
| PDF Output | `founder/{report-type}-{slug}.pdf` |

This separates:
- `strategy/` - Machine-readable markdown for task tracking
- `founder/` - Professional deliverables for presentation

#### 7. Extension Manifest Update

Add typst templates to manifest.json:

```json
{
  "provides": {
    "context": ["project/founder", "project/founder/templates/typst"]
  }
}
```

#### 8. Index Entries Update

Add index entries for typst templates in index-entries.json:

```json
{
  "path": ".claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ",
  "type": "template",
  "topics": ["typst", "founder", "strategy"],
  "line_count": 100,
  "load_when": {
    "agents": ["founder-implement-agent"],
    "languages": ["founder"]
  }
}
```

### Utility Functions Needed

#### 1. Markdown-to-Typst Content Helpers

For tables:
```lua
-- Convert markdown table to typst table
function md_table_to_typst(md_content)
  -- Parse pipe-delimited table
  -- Return #table(...) typst syntax
end
```

For code blocks:
```lua
-- Convert ```blocks to raw(block: true)
function md_code_to_typst(md_content)
  -- Return #raw(block: true)[...]
end
```

#### 2. Template Selection

```bash
# In founder-implement-agent
case "$report_type" in
  market-sizing)
    template=".claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ"
    ;;
  competitive-analysis)
    template=".claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ"
    ;;
  gtm-strategy)
    template=".claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ"
    ;;
esac
```

### Verification Requirements

The plan should specify these verification criteria for Phase 5:

1. `.typ` file exists and is non-empty
2. `typst compile` returns exit code 0
3. PDF file exists and is non-empty
4. PDF has expected page count (approximate)

### Error Handling

If typst compilation fails:
- Mark Phase 5 as [PARTIAL]
- Keep .typ file for manual debugging
- Return partial status with compilation errors
- Recommend: "Fix .typ syntax and run /implement to resume"

## Decisions

1. **Template Independence**: Founder extension will have its own typst templates, not depend on typst extension
2. **Output Directory**: Use `founder/` for typst output (professional deliverables)
3. **Generation Approach**: Generate typst directly from context (Option A), not by parsing markdown
4. **Phase Structure**: Add Phase 5 to existing 4-phase plan structure

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Typst not installed | Medium | High | Check typst availability at Phase 5 start, skip with warning if unavailable |
| Complex visualizations | Medium | Medium | Use simple ASCII-compatible Typst patterns, avoid external packages |
| Template maintenance burden | Low | Medium | Use shared strategy-template.typ for common styles |
| PDF quality issues | Low | Low | Test templates with real data before release |

## Context Extension Recommendations

**Topic**: Typst template patterns for business documents
**Gap**: No existing founder-specific typst templates
**Recommendation**: Create `.claude/extensions/founder/context/project/founder/templates/typst/` with three report-type templates

## Appendix

### Search Queries Used

1. Codebase exploration:
   - `Glob: .claude/extensions/founder/**/*`
   - `Glob: .claude/extensions/typst/**/*`

2. Pattern discovery:
   - `Grep: markdown.*typst|typst.*markdown|convert.*typst|pandoc`
   - `Grep: founder.*typst|typst.*founder`

### Key Files Examined

| File | Purpose | Key Insight |
|------|---------|-------------|
| founder/manifest.json | Extension definition | Routing to skill-founder-implement |
| founder/agents/founder-implement-agent.md | Implementation agent | Current 4-phase structure |
| founder/agents/founder-plan-agent.md | Planning agent | Research Integration pattern |
| founder/templates/market-sizing.md | MD template | Structure to replicate in typst |
| typst/templates/report-template.md | Typst reference | Professional document patterns |
| typst/agents/typst-implementation-agent.md | Typst agent | Compilation patterns |
| commands/implement.md | Command routing | Extension-based skill routing |
| filetypes/commands/convert.md | Conversion patterns | Markdown to PDF patterns |

### References

- Typst Documentation: https://typst.app/docs/
- Typst Universe (packages): https://typst.app/universe/
- Existing markdown templates in founder extension
- typst-implementation-agent compilation patterns
