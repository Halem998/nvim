# Research Report: Task #204 (Supplemental)

**Task**: Create grant extension scaffold
**Date**: 2026-03-15
**Focus**: Grant application best practices and workflow support requirements

## Summary

Analyzed the SFF (Survival and Flourishing Fund) example grant application and researched best practices in AI research, tech startup, and nonprofit grant writing. This supplemental research informs the design of the grant/ extension's context files, templates, and workflow support. Key findings include standard proposal components, funder-specific requirements, and progressive context needs for different grant types.

## Findings

### SFF Grant Application Analysis

The example grant application (`specs/tmp/example-grant-app.md`) reveals a comprehensive philanthropic funding application with these major sections:

#### Application Structure (29 distinct sections)

1. **General Information** (lines 1-28)
   - Entity type classification (nonprofit, for-profit, social welfare)
   - Theme round selection (Main, Climate Change, Animal Welfare, Human Self-Enhancement)
   - Value alignment declarations (fairness, freedom)

2. **Basic Information** (lines 29-56)
   - Contact person details
   - Legal entity type

3. **Organization Information** (lines 80-171)
   - Entity-specific branches (nonprofit vs for-profit)
   - Long-form application attachment (external Google Doc template)
   - Organization chart requirement
   - Compensation information (anonymized)
   - Plan for impact statement (1000 character limit)
   - Receiving charity details (for nonprofits)
   - Corporate documents (for for-profits)

4. **Funding Request** (lines 254-341)
   - Base request with spending plan
   - Minimum grant amount
   - Ambitious request (optional)
   - Maximum grant amount
   - Funding period dates (start/end)
   - Budget documentation

5. **Other Funding Context** (lines 343-363)
   - Public fundraising page
   - Concurrent fundraising sources
   - Recent significant funding
   - Unsuccessful funding attempts
   - Conspicuously absent funders

6. **Matching Pledge Request** (lines 364-419)
   - Matching rate selection (0.25x to 4x)
   - Maximum standard grant amount
   - Deadline selection
   - Excluded donation sources

7. **Key Individuals** (lines 421-469)
   - Up to 4 key personnel
   - Title, contribution description, contact info

8. **Links of Interest** (lines 471-500)
   - Up to 3 supplementary links with descriptions

9. **Speculation Grant Request** (lines 502-547)
   - Expedited funding request
   - Matching funds option

10. **Required Acknowledgements** (lines 548-617)
    - Data privacy and LLM usage
    - Variance in funding amount
    - Full application disclosure
    - Numerical evaluation disclosure
    - Functional link confirmation
    - Matching pledge documentation

#### Key Observations

| Aspect | SFF Requirement | Extension Implication |
|--------|-----------------|----------------------|
| Long-form attachment | External Google Doc template | Template file needed |
| Character limits | 500-1000 chars typical | Validation/counting support |
| Budget format | 1-page summary | Budget template needed |
| Impact statement | 1-3 sentences | Concise writing patterns |
| Timeline | Funding period dates | Timeline template |
| Org chart | Required for all | Org chart guidance |

### Grant Proposal Best Practices (Web Research)

#### Universal Proposal Components

Based on comprehensive web research, successful grant proposals contain these core components:

| Component | Description | Priority |
|-----------|-------------|----------|
| **Executive Summary/Abstract** | Concise overview (who, what, where, when, why, how) | Essential |
| **Organization Background** | History, mission, capacity | Essential |
| **Statement of Need** | Problem definition with data | Essential |
| **Project Description** | Goals, objectives, methodology | Essential |
| **Budget** | Line-item breakdown with justification | Essential |
| **Timeline** | Visual or tabular project schedule | Essential |
| **Evaluation Plan** | Success metrics and measurement | Essential |
| **Sustainability** | Post-grant continuation plan | Important |
| **Key Personnel** | Team qualifications | Important |
| **Letters of Support** | External endorsements | Varies |

#### AI/Tech Research Grant Specifics

For AI safety and tech research proposals (per EA Forum and Open Philanthropy patterns):

1. **Technical Clarity**
   - Describe technology in straightforward terms
   - Avoid unnecessary jargon
   - If reviewers do not understand in two passes, they move on

2. **Alignment with Funder Mission**
   - SFF: "improving humanity's long term prospects for survival and flourishing"
   - Open Phil: Focus on existential risk reduction
   - LTFF: Effective altruism impact

3. **Team Credibility**
   - Why you are passionate and motivated
   - Skill sets and experiences relevant to execution
   - Track record evidence

4. **Measurable Outcomes**
   - Key Performance Indicators (KPIs)
   - Quantitative success criteria
   - Evaluation methodology

5. **Funding Landscape Awareness**
   - Other sources being pursued
   - Why previous attempts failed (if applicable)
   - Coordination with other funders

#### Common Grant Application Pitfalls

| Pitfall | Description | Prevention |
|---------|-------------|------------|
| Vague proposals | Unclear objectives or methodology | Use specific, measurable language |
| Unclear budgets | Missing justification or errors | Line-item breakdown with rationale |
| Weak documentation | Missing required attachments | Checklist before submission |
| Generic language | Boilerplate not tailored to funder | Funder-specific customization |
| Technical opacity | Jargon without explanation | Plain language with technical precision |
| Missing impact | No clear path to outcomes | Theory of change narrative |

#### Success Rates and Context

- National average grant success rate: approximately 10% (1 in 10)
- AI safety funding landscape: Open Phil median grant ~$257k, average ~$1.67M
- Preparation timeline: Start at least 90 days before deadline

### Progressive Context Loading Requirements

Based on the grant writing workflow, context should be loaded progressively:

#### Stage 1: Initial Research (Funder Discovery)
- Funder mission and priorities
- Eligibility requirements
- Deadline information
- Application format requirements

#### Stage 2: Proposal Development
- Proposal structure templates
- Budget templates
- Character limit guidance
- Writing style patterns

#### Stage 3: Specific Components
- Organization description template
- Impact statement patterns
- Evaluation plan frameworks
- Timeline visualization

#### Stage 4: Final Review
- Submission checklist
- Required acknowledgements
- Link verification
- Character count validation

### Recommended Context Files for grant/ Extension

Based on analysis of SFF application and best practices:

```
context/project/grant/
  README.md                    # Domain overview, workflow summary
  domain/
    grant-fundamentals.md      # Core grant concepts and terminology
    funder-types.md            # Nonprofit, for-profit, foundation differences
  patterns/
    proposal-structure.md      # Universal proposal sections
    impact-statement.md        # How to write compelling impact statements
    budget-justification.md    # Budget line-item patterns
    evaluation-plan.md         # Metrics and measurement frameworks
  templates/
    budget-template.md         # Budget worksheet template
    timeline-template.md       # Project timeline template
    checklist-template.md      # Pre-submission checklist
  tools/
    sff-guide.md               # SFF-specific application guide
    open-phil-guide.md         # Open Philanthropy patterns (optional)
    ltff-guide.md              # Long-Term Future Fund patterns (optional)
  standards/
    writing-standards.md       # Character limits, clarity requirements
```

### Workflow Support Recommendations

The grant/ extension should support these workflows:

1. **Funder Research**
   - WebSearch for funder priorities and past grants
   - WebFetch for application guidelines
   - Context loading for funder-specific templates

2. **Proposal Drafting**
   - Template-based section generation
   - Character count tracking
   - Section-by-section review

3. **Budget Development**
   - Line-item template
   - Justification patterns
   - Total calculation verification

4. **Review and Submission**
   - Checklist validation
   - Link functionality verification
   - Required acknowledgements

### Grant Types to Consider

| Grant Type | Primary Funders | Key Differences |
|------------|-----------------|-----------------|
| AI Safety Research | Open Phil, SFF, LTFF | Technical clarity, existential risk framing |
| Tech Startup | SBIR, state programs | Commercialization path, market analysis |
| Nonprofit Project | Foundations, government | Mission alignment, community impact |
| Academic Research | NSF, NIH, private | Peer review, methodology rigor |

The extension should initially focus on **AI Safety Research** grants given the SFF example, with extensibility for other types.

## Decisions

1. **Focus Area**: Initial context files will target AI safety/EA philanthropic grants (SFF, Open Phil patterns)
2. **Template Priority**: Budget and impact statement templates are highest priority
3. **Funder-Specific Guides**: Create modular funder guides that can be loaded as needed
4. **Workflow Integration**: Extension should support research -> drafting -> review workflow stages

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Funder requirements change | Templates become outdated | Use patterns over rigid templates |
| Context files too specialized | Limited applicability | Focus on universal components first |
| Character limit variability | Validation errors | Configurable limit patterns |

## References

### Web Sources

- [Stanford Medicine: 10 Rules for AI in Grant Writing](https://med.stanford.edu/medicine/news/current-news/standard-news/10-rules-for-ai-in-grant-writing.html)
- [VentureWell: Nine Ways to Help Startups Write Winning Grant Applications](https://venturewell.org/winning-grant-application/)
- [FreeWill: Nonprofit Grant Writing 101](https://www.nonprofits.freewill.com/resources/blog/nonprofit-grant-writing)
- [UNC Writing Center: Grant Proposals](https://writingcenter.unc.edu/tips-and-tools/grant-proposals-or-give-me-the-money/)
- [EA Forum: Overview of AI Safety Funding Situation](https://forum.effectivealtruism.org/posts/XdhwXppfqrpPL2YDX/an-overview-of-the-ai-safety-funding-situation)
- [University of Southern Indiana: Common Components of Grant Proposals](https://www.usi.edu/sponsored-projects/grants-and-sponsored-projects/grant-proposal-and-federal-contract-development/common-components-of-grant-proposals)
- [Instrumentl: How to Write Grant Proposals](https://www.instrumentl.com/blog/how-to-write-grant-proposals)
- [fundsforNGOs: How to Build a Strong Grant Proposal Abstract](https://www2.fundsforngos.org/articles-searching-grants-and-donors/how-to-build-a-strong-grant-proposal-abstract/)

### Local Sources

- `/home/benjamin/.config/nvim/specs/tmp/example-grant-app.md` - SFF application form
- `/home/benjamin/.config/nvim/specs/204_create_grant_extension_scaffold/reports/01_extension-scaffold-patterns.md` - Extension scaffold research

## Next Steps

Run `/plan 204` to create implementation plan for the grant extension scaffold, incorporating both scaffold patterns (report 01) and grant best practices (this report).
