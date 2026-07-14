## Epidemiology Extension

Epidemiology research and implementation support using R. Covers study design, statistical modeling, causal inference, missing data, and Bayesian analysis.

### Task Type Routing

| Task Type Key | Research | Plan | Implement |
|---------------|----------|------|-----------|
| `epi` | skill-epi-research | skill-planner | skill-epi-implement |
| `epi:study` | skill-epi-research | skill-planner | skill-epi-implement |
| `epidemiology` | skill-epi-research | skill-planner | skill-epi-implement |

### Command

`/epi` -- Stage 0 interactive routing. Presents study design options and routes to appropriate task type (`epi` or `epi:study`).

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-epi-research | epi-research-agent | Study design, analysis planning, causal inference, literature review |
| skill-epi-implement | epi-implement-agent | R code implementation, statistical modeling, data analysis |

### Context Files

**Domain** (research agent):
- `project/epidemiology/domain/study-designs.md` -- Study design reference
- `project/epidemiology/domain/causal-inference.md` -- DAGs, propensity scores, mediation
- `project/epidemiology/domain/missing-data.md` -- MICE, sensitivity analysis
- `project/epidemiology/domain/data-management.md` -- Tidyverse workflows, validation
- `project/epidemiology/domain/reporting-standards.md` -- STROBE, CONSORT, PRISMA
- `project/epidemiology/domain/r-workflow.md` -- renv, targets, Quarto

**Patterns** (both agents):
- `project/epidemiology/patterns/statistical-modeling.md` -- GLM, mixed effects, Bayesian
- `project/epidemiology/patterns/observational-methods.md` -- Bias control, confounding
- `project/epidemiology/patterns/analysis-phases.md` -- Descriptive to sensitivity
- `project/epidemiology/patterns/strobe-checklist.md` -- STROBE reporting checklist

**Templates** (implement agent):
- `project/epidemiology/templates/analysis-plan.md` -- Study protocol template
- `project/epidemiology/templates/findings-report.md` -- Results reporting template

**Tools** (both agents):
- `project/epidemiology/tools/r-packages.md` -- R package documentation
- `project/epidemiology/tools/mcp-guide.md` -- Optional rmcp MCP server integration
