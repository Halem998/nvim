# Research Report: Task #208

**Task**: 208 - Create grant context files for domain knowledge
**Started**: 2026-03-15T00:00:00Z
**Completed**: 2026-03-15T01:00:00Z
**Effort**: 1-2 hours
**Dependencies**: Task 204 (grant extension scaffold)
**Sources/Inputs**:
- Codebase analysis of `.claude/context/` structure
- Extension context patterns from lean, latex, and filetypes extensions
- Web research on grant writing best practices
**Artifacts**:
- This report: `specs/208_create_grant_context_files/reports/01_grant-context-patterns.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Context files should follow the established pattern: `domain/`, `patterns/`, `templates/`, `tools/`, `standards/` subdirectories
- Grant domain requires 12-15 context files covering funder types, proposal structure, budget formats, and evaluation plans
- Progressive loading should prioritize README and domain files for research, templates and patterns for implementation
- Index entries must specify `grant-agent` in `load_when.agents` for automatic context discovery

## Context & Scope

This research analyzes existing context file patterns in the `.claude/` system and determines the optimal structure for grant writing domain knowledge. The grant extension (created in task 204) provides the scaffold; this task identifies the specific context files needed to support grant-agent operations.

## Findings

### Codebase Patterns

#### Directory Structure Convention

All extension context files follow a consistent structure under `context/project/{domain}/`:

```
context/project/{domain}/
├── README.md              # Overview and navigation
├── domain/                # Core concepts and terminology
├── patterns/              # Reusable structure patterns
├── standards/             # Style guides and conventions
├── templates/             # Ready-to-use templates
└── tools/                 # Tool integration guides
```

Examples from existing extensions:
- **lean**: `domain/mathlib-overview.md`, `patterns/tactic-patterns.md`, `tools/mcp-tools-guide.md`
- **latex**: `patterns/document-structure.md`, `templates/subfile-template.md`, `standards/latex-style-guide.md`
- **filetypes**: `patterns/pitch-deck-structure.md`, `tools/dependency-guide.md`

#### Content Format Standards

Context files follow consistent formatting:
1. **Header**: Title with H1, brief purpose statement
2. **Structure section**: Table or list of key concepts
3. **Examples**: Code blocks or formatted examples
4. **Best practices**: Bulleted guidance
5. **Navigation**: Links to related files

Line count targets (from existing files):
- README.md: 20-50 lines (overview only)
- Domain files: 50-100 lines (reference material)
- Pattern files: 80-150 lines (examples included)
- Template files: 100-200 lines (full templates with comments)
- Tool guides: 100-150 lines (step-by-step)

#### Index Entry Schema

From `index-entries.json` examples:

```json
{
  "path": "project/grant/domain/funder-types.md",
  "description": "Grant funder categories and application patterns",
  "tags": ["grant", "funders", "research"],
  "load_when": {
    "languages": ["grant"],
    "agents": ["grant-agent"]
  }
}
```

### External Resources

#### Grant Proposal Structure (2026 Best Practices)

Research confirms the following essential proposal components:

| Component | Purpose | Character Limits (typical) |
|-----------|---------|---------------------------|
| Executive Summary | 1-page overview of who/what/where/when/why/how | 2,000-5,000 chars |
| Statement of Need | Problem definition with data | 3,000-8,000 chars |
| Project Description | Goals, objectives, methodology | 10,000-25,000 chars |
| Budget | Line-item breakdown with justification | Varies by funder |
| Evaluation Plan | Success metrics and measurement methods | 2,000-5,000 chars |
| Timeline | Visual or tabular project schedule | N/A (tables) |
| Sustainability | Post-grant continuation plan | 1,000-3,000 chars |
| Key Personnel | Team qualifications and roles | 2,000-5,000 chars |

#### Budget Justification Formats

**NSF Format**:
- Maximum 5 pages (or 3 pages per program solicitation)
- Required for proposer AND sub-awardees
- Categories: Senior/Key Personnel, Other Personnel, Equipment, Travel, Other Direct Costs

**NIH Format**:
- Modular: Up to $250K/year in $25K modules (no detailed budget required)
- Detailed R&R: Over $250K/year requires full budget form
- Personnel justification: Name, role, person-months (no salary in justification)

**Foundation Format** (typical):
- 1-2 page narrative justification
- Connect each expense to project activities
- Explain calculation methodology

#### AI Safety Research Grants

**Open Philanthropy RFP**:
- First step: 300-word expression of interest
- Response within 2 weeks for strong applicants
- Emphasis on prior ML experience and understanding of prior work
- Grants range from API credits to seed funding for new organizations
- Median grant: $257K

**LTFF (Long-Term Future Fund)**:
- Smaller grants (median $25K)
- Suitable for upskilling, career transitions, smaller projects
- Less formal requirements than Open Phil

**SBIR/STTR**:
- Phase I: $150K-$275K (6-12 months)
- Phase II: $750K-$1.5M (2 years)
- 51% U.S. ownership required
- STTR requires research institution partnership (30% minimum allocation)

#### Logic Models and Evaluation Plans

Grant evaluation plans include:
- **Formative evaluation**: During project (process assessment)
- **Summative evaluation**: After project (outcome assessment)
- **Logic model**: Visual representation connecting inputs -> activities -> outputs -> outcomes -> impact

### Recommendations

#### Recommended Context Files Structure

```
.claude/extensions/grant/context/project/grant/
├── README.md                          # Already exists (update with file links)
│
├── domain/
│   ├── funder-types.md               # AI Safety, SBIR, Foundation, Academic
│   ├── proposal-components.md        # Standard sections and their purposes
│   └── grant-terminology.md          # Key terms and definitions
│
├── patterns/
│   ├── proposal-structure.md         # Section organization patterns
│   ├── budget-patterns.md            # Budget format patterns by funder type
│   ├── evaluation-patterns.md        # Logic models and evaluation plans
│   └── narrative-patterns.md         # Writing patterns for impact statements
│
├── standards/
│   ├── writing-standards.md          # Grant writing style guide
│   └── character-limits.md           # Funder-specific limits reference
│
├── templates/
│   ├── executive-summary.md          # Executive summary template
│   ├── budget-justification.md       # Budget justification templates
│   ├── evaluation-plan.md            # Evaluation plan template
│   └── submission-checklist.md       # Pre-submission checklist
│
└── tools/
    ├── funder-research.md            # How to research funders
    └── web-resources.md              # Useful grant writing resources
```

**Total: 14 context files** (including README update)

#### Content Outlines for Each File

**domain/funder-types.md** (~80 lines)
- AI Safety funders (Open Phil, SFF, LTFF)
- Federal funders (NSF, NIH, DOE)
- SBIR/STTR programs
- Private foundations
- State/local programs
- Funder-specific requirements summary table

**domain/proposal-components.md** (~100 lines)
- Executive Summary structure
- Statement of Need requirements
- Project Description elements
- Budget components
- Evaluation plan structure
- Personnel section format
- Sustainability considerations

**domain/grant-terminology.md** (~60 lines)
- Common grant terms (direct costs, indirect costs, F&A, etc.)
- Funder-specific terminology
- Budget categories
- Compliance terms

**patterns/proposal-structure.md** (~120 lines)
- Standard proposal outline
- Section ordering by funder type
- Cross-reference patterns
- Narrative flow patterns

**patterns/budget-patterns.md** (~150 lines)
- NSF budget format
- NIH modular vs detailed
- Foundation budget format
- Line-item justification patterns
- Cost calculation examples

**patterns/evaluation-patterns.md** (~100 lines)
- Logic model template
- Formative vs summative evaluation
- Metrics and KPIs by project type
- Data collection methods

**patterns/narrative-patterns.md** (~80 lines)
- Impact statement formats
- Storytelling techniques
- Data presentation patterns
- Funder alignment language

**standards/writing-standards.md** (~100 lines)
- Active voice guidelines
- Specificity requirements
- Avoiding jargon
- Measurable objectives format
- Technical clarity principles

**standards/character-limits.md** (~60 lines)
- NSF limits by section
- NIH limits by section
- Common foundation limits
- Word count estimation

**templates/executive-summary.md** (~120 lines)
- Template structure
- Fill-in sections
- Example summaries
- Checklist

**templates/budget-justification.md** (~150 lines)
- Personnel justification template
- Equipment justification template
- Travel justification template
- Other direct costs template
- Sub-award justification template

**templates/evaluation-plan.md** (~100 lines)
- Evaluation plan template
- Logic model diagram
- Metrics table template
- Timeline template

**templates/submission-checklist.md** (~80 lines)
- Pre-submission checklist
- Common errors to avoid
- Final review steps
- Submission platforms

**tools/funder-research.md** (~100 lines)
- How to identify funders
- Analyzing funder priorities
- Reading past awarded grants
- Building funder relationships

**tools/web-resources.md** (~60 lines)
- Grant databases
- Funder websites
- Writing resources
- Template repositories

#### Progressive Loading Recommendations

**Stage 1: Research (grant-agent doing funder analysis)**
- Load: README.md, domain/funder-types.md, tools/funder-research.md
- Total: ~240 lines (~12KB)

**Stage 2: Planning (structuring proposal)**
- Load: domain/proposal-components.md, patterns/proposal-structure.md, standards/writing-standards.md
- Total: ~320 lines (~16KB)

**Stage 3: Implementation (writing sections)**
- Load: Relevant templates/, patterns/, standards/character-limits.md
- Total: ~400-600 lines depending on section (~20-30KB)

**Context Budget**: All grant context files combined: ~1,460 lines (~73KB)
- Within Tier 3 budget (60-80% context window for agents)

#### Index Entries Update

The existing `index-entries.json` has only the README entry. Add entries for all new files:

```json
{
  "entries": [
    {
      "path": "project/grant/README.md",
      "description": "Grant writing domain overview and extension capabilities",
      "tags": ["grant", "proposal", "funding"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/domain/funder-types.md",
      "description": "Grant funder categories: AI Safety, SBIR, Foundation, Academic",
      "tags": ["grant", "funders", "eligibility"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/domain/proposal-components.md",
      "description": "Standard grant proposal sections and requirements",
      "tags": ["grant", "proposal", "structure"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/patterns/budget-patterns.md",
      "description": "Budget formats for NSF, NIH, foundations, and SBIR",
      "tags": ["grant", "budget", "justification"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/templates/executive-summary.md",
      "description": "Executive summary template with fill-in sections",
      "tags": ["grant", "template", "summary"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/templates/budget-justification.md",
      "description": "Budget justification templates by category",
      "tags": ["grant", "template", "budget"],
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    }
  ]
}
```

## Decisions

1. **Directory structure**: Follow established pattern with domain/, patterns/, standards/, templates/, tools/ subdirectories
2. **File count**: 14 context files provides comprehensive coverage without overloading context window
3. **Loading strategy**: Three-stage progressive loading based on grant workflow phase
4. **Funder coverage**: Focus on AI Safety, SBIR/STTR, Foundation, and Academic grant types as specified in README

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Context files too large for agent window | Low | High | Target 60-150 lines per file; split if needed |
| Funder requirements change | Medium | Medium | Include version dates; tools/web-resources.md for current info |
| Missing funder-specific details | Medium | Low | Focus on patterns over specifics; link to official guides |
| Template examples outdated | Low | Medium | Use generic examples; note that specifics vary by funder |

## Context Extension Recommendations

This is a meta task for context file creation, so context gap detection does not apply.

## Appendix

### Search Queries Used

1. "grant proposal writing best practices structure templates 2026"
2. "NSF NIH grant budget justification format guidelines"
3. "AI safety research grant Open Philanthropy LTFF proposal requirements"
4. "SBIR STTR grant proposal format small business innovation research requirements"
5. "foundation grant proposal nonprofit evaluation plan logic model"

### References

- [Grant Proposal Templates Guide 2026](https://www.grantbite.com/en/blog/grant-proposal-templates-free-downloads)
- [Planning and Writing a Grant Proposal](https://writing.wisc.edu/handbook/grants/)
- [NSF Preparing Your Proposal Budget](https://www.nsf.gov/funding/proposal-budget)
- [NIH R&R Budget Form Guide](https://grants.nih.gov/grants/how-to-apply-application-guide/forms-i/general/g.300-r&r-budget-form.htm)
- [Open Philanthropy Technical AI Safety RFP](https://www.openphilanthropy.org/request-for-proposals-technical-ai-safety-research/)
- [SBIR/STTR Apply Guide](https://www.sbir.gov/apply)
- [How to Write an Effective Grant Evaluation Plan](https://www.instrumentl.com/blog/how-to-write-effective-grant-evaluation-plan)
- [W.K. Kellogg Foundation Logic Model Development Guide](https://www.naccho.org/uploads/downloadable-resources/Programs/Public-Health-Infrastructure/KelloggLogicModelGuide_161122_162808.pdf)

### Codebase Files Analyzed

- `.claude/context/README.md` - Context organization overview
- `.claude/extensions/grant/manifest.json` - Grant extension manifest
- `.claude/extensions/grant/context/project/grant/README.md` - Existing grant README
- `.claude/extensions/grant/index-entries.json` - Existing index entries
- `.claude/extensions/lean/context/project/lean4/README.md` - Lean context pattern
- `.claude/extensions/lean/index-entries.json` - Lean index pattern
- `.claude/extensions/latex/context/project/latex/` - LaTeX context patterns
