# Research Report: Task #256

**Task**: 256 - project_timeline_context
**Started**: 2026-03-23T00:00:00Z
**Completed**: 2026-03-23T00:15:00Z
**Effort**: Low
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (founder extension domain files), Web research (PMI, Atlassian, Wrike, Asana, monday.com)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Existing domain knowledge files in founder extension follow consistent structure: H1 title, brief intro, H2 sections with tables/diagrams, practical examples, references
- Project management best practices identified: WBS (100% rule), PERT three-point estimation, critical path method, milestone types, dependency mapping, resource allocation, risk matrices
- Recommended timeline-frameworks.md structure mirrors existing patterns with 6-8 sections covering PM fundamentals

## Context & Scope

Research conducted to inform creation of `context/project/founder/domain/timeline-frameworks.md` for a future project-agent. The file will provide domain knowledge for project management capabilities similar to how `business-frameworks.md` provides market sizing knowledge.

**Goal**: Document project management best practices including WBS, milestones, dependencies, estimation, critical path, resources, and risk assessment.

## Findings

### Codebase Patterns

**Existing Domain Knowledge File Structure** (from business-frameworks.md, legal-frameworks.md, strategic-thinking.md):

1. **H1 Title**: Single line describing domain
2. **Brief Intro**: 1-2 sentences describing purpose
3. **Major H2 Sections**: Each covering a distinct framework or concept
4. **Tables**: Comparison tables with 3-4 columns for quick reference
5. **ASCII Diagrams**: Unicode box-drawing characters for visualizations
6. **Practical Examples**: Code-block formatted calculations or scenarios
7. **References**: External links for further reading

**Line Count Targets**: 214-276 lines (strategic-thinking: 214, business-frameworks: 240, legal-frameworks: 245)

**Index Entry Pattern**:
```json
{
  "path": "project/founder/domain/timeline-frameworks.md",
  "summary": "WBS structure, milestone types, PERT estimation, critical path, risk matrices",
  "line_count": ~250,
  "load_when": {
    "agents": ["project-agent", "founder-plan-agent"],
    "languages": ["founder"],
    "commands": ["/project", "/plan"]
  }
}
```

### External Resources

#### Work Breakdown Structure (WBS)

**Definition**: A deliverable-oriented hierarchical decomposition of project work (PMI).

**The 100% Rule** (most important WBS principle):
- Include 100% of work defined by project scope
- Sum of work at lower levels must equal 100% of level above
- No gaps, no overlaps

**Best Practices**:
| Practice | Description |
|----------|-------------|
| Use nouns | WBS describes deliverables (what), not actions (how) |
| Maintain hierarchy | Consistent naming conventions, clear parent-child |
| Be thorough | Dictionary descriptions at work package level |
| Avoid over-decomposition | Too much detail creates management overhead |

**WBS Types**:
- Deliverable-Based (preferred): Organizes by project outputs
- Phase-Based: Organizes by project phases

**Sources**: [PMI WBS Principles](https://www.pmi.org/learning/library/work-breakdown-structure-basic-principles-4883), [Atlassian WBS Guide](https://www.atlassian.com/work-management/project-management/work-breakdown-structure)

#### Milestone Types

Five milestone types covering project lifecycle:

| Type | Purpose | Examples |
|------|---------|----------|
| **Initiation** | Formal authorization/setup | Charter approval, team assembly, kickoff |
| **Approval** | External stakeholder decisions | Requirements sign-off, budget authorization |
| **Execution** | Tangible progress markers | Prototype delivery, beta launch, integration points |
| **Delivery** | Output release to stakeholders | Product launch, feature release, go-live |
| **Review** | Post-delivery assessment | Lessons learned, benefits realization, retrospective |

**Key Characteristic**: Milestones are zero-duration events marking completion, not tasks themselves.

**Sources**: [monday.com Milestones Guide](https://monday.com/blog/project-management/project-milestones/), [Smartsheet Milestone Examples](https://www.smartsheet.com/content/project-milestone-examples)

#### Dependency Mapping

**Four Dependency Types**:

| Type | Notation | Meaning | Example |
|------|----------|---------|---------|
| **Finish-to-Start** | FS | B cannot start until A finishes | Design -> Development |
| **Start-to-Start** | SS | B cannot start until A starts | Testing -> Documentation |
| **Finish-to-Finish** | FF | B cannot finish until A finishes | Electrical -> Drywall |
| **Start-to-Finish** | SF | B cannot finish until A starts | Guard shift handoff |

**Usage Frequency**: FS is most common (~90% of dependencies). SF is rare but useful for handoff scenarios.

**Sources**: [Atlassian Dependencies](https://www.atlassian.com/agile/project-management/project-management-dependencies), [Tactical PM FS Guide](https://www.tacticalprojectmanager.com/finish-to-start-dependency/)

#### Three-Point Estimation (PERT)

**PERT Formula** (Beta Distribution):
```
E = (O + 4M + P) / 6
```

Where:
- O = Optimistic estimate (best-case)
- M = Most Likely estimate (realistic)
- P = Pessimistic estimate (worst-case)
- E = Expected value

**Standard Deviation**:
```
SD = (P - O) / 6
```

**Alternative** (Triangular Distribution):
```
E = (O + M + P) / 3
```

**Example**:
```
Task: API Integration
  O = 3 days (everything goes perfectly)
  M = 5 days (realistic expectation)
  P = 12 days (complications arise)

PERT: E = (3 + 4*5 + 12) / 6 = 35/6 = 5.8 days
SD = (12 - 3) / 6 = 1.5 days

Expected duration: 5.8 +/- 1.5 days (95% confidence: 2.8 - 8.8 days)
```

**Benefits**: Captures uncertainty early, enables risk-aware planning.

**Sources**: [Project Management Academy PERT](https://projectmanagementacademy.net/resources/blog/a-three-point-estimating-technique-pert/), [Wikipedia Three-Point Estimation](https://en.wikipedia.org/wiki/Three-point_estimation)

#### Critical Path Analysis

**Definition**: Identifies the sequence of tasks determining minimum project completion time.

**Key Concepts**:
- **Critical Path**: Longest sequence of dependent tasks
- **Critical Tasks**: Zero float; any delay extends project
- **Non-Critical Tasks**: Have float; can slip without project impact
- **Float/Slack**: Time task can slip without affecting project end

**CPM Steps**:
1. Define all project activities
2. Identify task dependencies
3. Estimate task durations
4. Construct network diagram
5. Calculate early start/finish (forward pass)
6. Calculate late start/finish (backward pass)
7. Identify critical path (zero float tasks)

**Historical Note**: Developed 1950s by Kelley & Walker; used for World Trade Center construction (1966).

**Limitations**: Best for well-defined projects with predictable durations. Less effective for high-uncertainty or frequently-changing projects.

**Sources**: [Wrike CPM Guide 2026](https://www.wrike.com/blog/critical-path-is-easy-as-123/), [Asana CPM Guide 2026](https://asana.com/resources/critical-path-method)

#### Resource Allocation Patterns

**Two Primary Techniques**:

| Technique | Constraint | Result | Use When |
|-----------|------------|--------|----------|
| **Resource Leveling** | Resources fixed | Timeline extends | Resource shortage |
| **Resource Smoothing** | Timeline fixed | Workload redistributed | Deadline non-negotiable |

**Resource Leveling**:
- Adjusts schedule to match resource availability
- May extend project duration
- Question answered: "When will work finish with available resources?"

**Resource Smoothing**:
- Works within existing timeline
- Redistributes tasks to avoid peaks/troughs
- Question answered: "How do we meet deadline with even workload?"

**Decision Matrix**:
```
               Deadline Flexible?
                  Yes          No
              ┌───────────┬───────────┐
Resource  Yes │  Either   │ Smoothing │
Flexible?     ├───────────┼───────────┤
          No  │  Leveling │  Problem  │
              └───────────┴───────────┘
```

**Sources**: [APM Resource Comparison](https://www.apm.org.uk/resources/find-a-resource/difference-between-resource-smoothing-and-resource-levelling/), [Asana Resource Leveling](https://asana.com/resources/resource-leveling)

#### Risk Assessment Matrices

**Structure**: 2D grid with Probability on one axis, Impact on other.

**Common Sizes**: 3x3, 4x4, or 5x5 matrices.

**5x5 Matrix Example**:

```
           │ Negligible │   Minor   │  Moderate │   Major   │  Severe   │
           │     1      │     2     │     3     │     4     │     5     │
───────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Almost     │            │           │           │           │           │
Certain 5  │     5      │    10     │    15     │    20     │    25     │
───────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Likely 4   │     4      │     8     │    12     │    16     │    20     │
───────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Possible 3 │     3      │     6     │     9     │    12     │    15     │
───────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Unlikely 2 │     2      │     4     │     6     │     8     │    10     │
───────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Rare 1     │     1      │     2     │     3     │     4     │     5     │
───────────┴────────────┴───────────┴───────────┴───────────┴───────────┘
```

**Risk Score**: Probability x Impact

**Color Coding**:
| Score Range | Color | Action |
|-------------|-------|--------|
| 15-25 | Red | Immediate attention, active mitigation |
| 8-14 | Yellow | Monitor closely, develop contingency |
| 1-7 | Green | Accept or track with minimal resources |

**Sources**: [Asana Risk Matrix Template](https://asana.com/resources/risk-matrix-template), [SafetyCulture 5x5 Matrix](https://safetyculture.com/topics/risk-assessment/5x5-risk-matrix)

### Recommendations

**Recommended Structure for timeline-frameworks.md**:

```markdown
# Timeline Frameworks

Domain knowledge for project planning, estimation, and risk management.

## Work Breakdown Structure (WBS)
- 100% rule explanation
- WBS types (deliverable vs phase)
- Decomposition best practices table
- Example hierarchical diagram

## Milestone Types
- Five milestone categories table
- Lifecycle placement diagram
- Examples for each type

## Dependency Mapping
- Four dependency types table
- Network diagram basics
- Lag and lead concepts

## Three-Point Estimation (PERT)
- PERT and triangular formulas
- Standard deviation calculation
- Practical example with calculation

## Critical Path Analysis
- CPM steps checklist
- Float/slack concepts
- Critical vs non-critical tasks

## Resource Allocation
- Leveling vs smoothing comparison
- Decision matrix
- Application scenarios

## Risk Assessment Matrix
- 5x5 matrix visualization
- Score calculation
- Color coding and actions

## References
- Links to PMI, Atlassian, Asana resources
```

**Target Line Count**: ~250 lines (matching existing domain files)

**Index Entry to Add**:
```json
{
  "path": "project/founder/domain/timeline-frameworks.md",
  "summary": "WBS structure, milestone types, PERT estimation, critical path, resource allocation, risk matrices",
  "line_count": 250,
  "load_when": {
    "agents": ["project-agent", "founder-plan-agent", "founder-implement-agent"],
    "languages": ["founder"],
    "commands": ["/project", "/plan", "/implement"]
  }
}
```

## Decisions

1. **Structure mirrors existing domain files**: Same H1 -> H2 -> Tables/Diagrams pattern for consistency
2. **Include all seven sections**: WBS, milestones, dependencies, PERT, CPM, resources, risk - comprehensive coverage
3. **Target ~250 lines**: Matches existing domain file density
4. **Use Unicode box-drawing**: Consistent with project documentation standards
5. **Focus on practical formulas**: Include actual PERT formula, risk score calculation - actionable reference

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Too long/verbose | Low readability | Target 250 lines, use tables over prose |
| Too academic | Low practical value | Include calculation examples, decision matrices |
| Missing project-agent context | Incomplete integration | Note: project-agent doesn't exist yet; design for future agent |

## Context Extension Recommendations

None - this task is creating the recommended context extension.

## Appendix

### Search Queries Used

1. "Work Breakdown Structure WBS best practices project management 2025"
2. "PERT three-point estimation formula project management"
3. "critical path analysis project management methodology"
4. "project milestone types initiation approval execution delivery review"
5. "project risk assessment matrix probability impact severity"
6. "project resource allocation patterns leveling smoothing"
7. "project dependency types finish-to-start finish-to-finish start-to-start start-to-finish"

### Codebase Files Analyzed

- `.claude/extensions/founder/context/project/founder/domain/business-frameworks.md` (240 lines)
- `.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md` (245 lines)
- `.claude/extensions/founder/context/project/founder/domain/strategic-thinking.md` (214 lines)
- `.claude/extensions/founder/context/project/founder/README.md` (81 lines)
- `.claude/extensions/founder/index-entries.json` (165 lines)
- `.claude/extensions/founder/agents/strategy-agent.md` (467 lines)

### References

- [PMI WBS Basic Principles](https://www.pmi.org/learning/library/work-breakdown-structure-basic-principles-4883)
- [Atlassian WBS Guide](https://www.atlassian.com/work-management/project-management/work-breakdown-structure)
- [Wrike WBS Guide](https://www.wrike.com/project-management-guide/faq/what-is-work-breakdown-structure-in-project-management/)
- [Project Management Academy PERT](https://projectmanagementacademy.net/resources/blog/a-three-point-estimating-technique-pert/)
- [Wikipedia Three-Point Estimation](https://en.wikipedia.org/wiki/Three-point_estimation)
- [Wrike Critical Path 2026](https://www.wrike.com/blog/critical-path-is-easy-as-123/)
- [Asana Critical Path 2026](https://asana.com/resources/critical-path-method)
- [monday.com Project Milestones 2026](https://monday.com/blog/project-management/project-milestones/)
- [Smartsheet Milestone Examples](https://www.smartsheet.com/content/project-milestone-examples)
- [Atlassian Project Dependencies](https://www.atlassian.com/agile/project-management/project-management-dependencies)
- [APM Resource Leveling vs Smoothing](https://www.apm.org.uk/resources/find-a-resource/difference-between-resource-smoothing-and-resource-levelling/)
- [Asana Risk Matrix Template 2026](https://asana.com/resources/risk-matrix-template)
- [SafetyCulture 5x5 Risk Matrix](https://safetyculture.com/topics/risk-assessment/5x5-risk-matrix)
