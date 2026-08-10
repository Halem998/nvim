# Research Report: Task #400 — Epidemiology R Best Practices for Publication

**Task**: 400 - Overhaul epidemiology extension
**Date**: 2026-04-10
**Mode**: Team Research (4 teammates: Primary / Alternatives / Critic / Horizons)
**Session**: sess_1775857423_78e857
**Round**: 2 (domain knowledge focus — round 1 covered infrastructure)

---

## Executive Summary

This second research round systematically studied R best practices for epidemiology publication, complementing round 1's infrastructure analysis. Four teammates investigated: (A) study types and R code patterns, (B) publication outputs and reporting standards, (C) gaps in the existing extension's domain knowledge, and (D) strategic architecture for building a pattern library.

**Core finding**: The epidemiology extension needs ~1,400–1,700 lines of new context files across a hybrid directory structure (domain/patterns/templates/tools) to give agents the domain knowledge required for competent epidemiology assistance. The current 248 lines cover ~20% of what's needed, skewed 80% toward infectious disease while the majority of epidemiology research is observational/chronic disease.

**Three highest-risk gaps** (where agents give actively wrong answers without new context):
1. **Causal inference / DAGs** — agents will adjust for colliders and mediators inappropriately
2. **Missing data** — agents default to complete-case analysis (invalid for MAR, the most common mechanism)
3. **Competing risks** — agents use 1-KM instead of CIF, overestimating cumulative incidence

**Recommended architecture**: Hybrid structure with `domain/` (workflow-phase knowledge), `patterns/` (recurring analysis logic), `templates/` (fill-in artifacts), `tools/` (package reference). 12–14 index.json entries with agent-scoped loading.

---

## Key Findings

### 1. Study Types and R Code Patterns (Teammate A)

Teammate A produced comprehensive coverage of every major epidemiology study design with working R code:

| Study Design | Primary Packages | Key Output |
|-------------|-----------------|------------|
| **Cohort** (prospective/retrospective) | `survival`, `survminer`, `gtsummary` | KM curves, Cox PH (HR with 95% CI), risk tables |
| **Case-control** (matched/unmatched) | `survival::clogit`, `MatchIt`, `epitools` | Conditional logistic regression, OR with 95% CI |
| **Cross-sectional** | `survey`, `srvyr`, `sandwich` | Prevalence ratios via modified Poisson, survey-weighted estimates |
| **Ecological** | `MASS::glm.nb`, `spdep`, `sf` | Poisson with offset, Moran's I for spatial autocorrelation |
| **RCT** | `gtsummary`, `survival`, `mice` | ITT vs PP analysis, CONSORT flow, baseline Table 1 |
| **Quasi-experimental** | `nlme`, `CausalImpact`, `fixest` | ITS (segmented regression), DiD with fixed effects |
| **Meta-analysis** | `metafor`, `meta`, `netmeta` | Random effects, forest/funnel plots, I², publication bias |

**Key analysis methods** documented with full code pipelines:
- **Causal inference**: `dagitty`/`ggdag` for DAGs, `adjustmentSets()`, collider identification
- **Propensity scores**: `MatchIt` (matching) + `WeightIt` (IPTW/CBPS) + `cobalt` (balance assessment)
- **Mediation**: `CMAverse` for causal mediation with NDE/NIE decomposition
- **Missing data**: `mice` full workflow (4-step: inspect → impute → analyze → pool), MCAR/MAR/MNAR assessment with `naniar`
- **Bayesian**: `brms` with R formula syntax, prior specification, `pp_check()`, `loo` comparison
- **Competing risks**: `tidycmprsk` for CIF estimation, Fine-Gray vs cause-specific hazard distinction
- **Mixed effects**: `lme4` + `clubSandwich` for cluster-robust SEs
- **Survey methods**: `survey`/`srvyr` with complex design specification

**Confidence**: High across all major study types. Medium for network meta-analysis and spatial methods.

### 2. Publication Outputs and Reporting Standards (Teammate B)

Teammate B mapped the complete publication toolkit:

**Tables**:
| Tool | Use Case | Status |
|------|----------|--------|
| `gtsummary` | Table 1 + regression tables (dominant) | Active, recommended |
| `modelsummary` | Multi-model comparison | Active, modern |
| `tableone` | Quick Table 1 | Maintained, legacy |
| `stargazer` | LaTeX regression tables | **Unmaintained** — use `modelsummary` |
| `flextable`/`gt` | Custom formatting, Word/HTML export | Active |

**Figures**:
| Type | Package | Notes |
|------|---------|-------|
| Kaplan-Meier curves | `survminer::ggsurvplot` | Risk tables, median survival, log-rank p |
| Forest plots | `forestploter`, `meta::forest` | Subgroup and meta-analysis |
| DAG visualizations | `ggdag`, `dagitty` | Adjustment sets, backdoor paths |
| Epidemic curves | `incidence2` | Supersedes `incidence` |
| ROC/Calibration | `pROC`, `rms` | Prediction model validation |
| Dose-response | `rms` + restricted cubic splines | Non-linear exposure-response |
| Decision curves | `dcurves` | Clinical utility assessment |
| Multi-panel | `patchwork`, `cowplot` | Tag levels, alignment |

**Reporting guidelines** mapped to study types:
| Guideline | Study Type | R Tool Support |
|-----------|-----------|---------------|
| **STROBE** (22 items) | Observational | `gtsummary`, `ggdag`, `episensr` |
| **CONSORT** (25 items) | RCTs | `ggconsort`, `gtsummary` |
| **PRISMA** (27 items) | Systematic reviews | `PRISMA2020` (not `PRISMAstatement`) |
| **RECORD** | EHR/admin data | `linelist`, `cleanepi` |
| **TRIPOD/+AI** (22 items) | Prediction models | `rms`, `pROC`, `dcurves` |
| **CHEERS 2022** (28 items) | Health economics | `BCEA`, `dampack` |
| **GATHER** (18 items) | Global health estimates | `INLA`, `rnaturalearth` |

**Reproducibility stack**: `renv` (environment) + `targets` (pipeline) + Quarto (manuscript authoring) is the 2025 gold standard. Inline R results eliminate manual copy-paste of statistics.

**Journal format strategy**: Most epi journals (JAMA, Lancet, BMJ, NEJM) prefer Word — use `gtsummary::as_flex_table()` + `ggsave("figure.tiff", dpi=600)`. LaTeX-accepting journals (IJE, Springer) — use `as_kable_extra(format="latex")`.

### 3. Domain Knowledge Gaps (Teammate C — Critic)

**Overall assessment**: The extension provides ~20% of needed domain knowledge. The missing 80% is weighted toward the most common tasks.

**Priority 1 gaps** (HIGH impact, HIGH frequency, HIGH risk of wrong output):

| Gap | Risk Without Coverage | Affected Studies |
|-----|----------------------|-----------------|
| **Causal inference / DAGs** | Agents adjust for colliders, confuse mediation/confounding | All observational |
| **Missing data** | Agents default to complete-case (invalid for MAR) | Nearly all |
| **Observational methods** | No propensity scores, no competing risks, no RERI | 80% of epi |
| **R package list** | Biased 80% infectious disease; missing gtsummary, mice, MatchIt | All |

**Priority 2 gaps** (prevent legal/ethical failures):

| Gap | Risk | Consequence |
|-----|------|-------------|
| **Data ethics / PHI** | Agent helps commit PHI to git | HIPAA/IRB violation |
| **REDCap integration** | No guidance on dominant data platform | Unusable for academic epi |

**Priority 3 gaps** (high methodological value):
- Sensitivity analysis (E-values, quantitative bias analysis with `episensr`)
- Prediction modeling (`rms`, `glmnet`, C-statistic, calibration)
- Reporting checklists (STROBE/CONSORT with R annotations)

**Priority 4 gaps** (specialized):
- Spatial epidemiology (`spdep`, `SpatialEpi`)
- Surveillance methods (`surveillance` package, aberration detection)
- Pharmacoepidemiology (new user design, SCCS, case-crossover)

**Structural observations**:
- Zero templates (vs. present's 4 fill-in templates)
- Zero anti-patterns (no "WRONG/CORRECT" pairs for methods)
- No interpretation guidance (e.g., when OR ≈ RR, when to use PR instead)
- Skewed 80% infectious disease / 20% everything else (should be 40/60)

### 4. Strategic Architecture (Teammate D — Horizons)

**Recommended directory structure** (hybrid — evaluated against 4 alternatives):

```
.claude/extensions/epidemiology/context/project/epidemiology/
├── README.md                          # existing — expand to 80 lines
├── domain/
│   ├── study-designs.md              # NEW — 150-200 lines
│   ├── causal-inference.md           # NEW — 120-150 lines
│   ├── missing-data.md               # NEW — 100-120 lines
│   ├── data-management.md            # NEW — 120-160 lines
│   ├── data-ethics.md                # NEW — 60-80 lines
│   ├── r-workflow.md                 # NEW — 80-100 lines
│   └── reporting-standards.md        # NEW — 80-100 lines
├── patterns/
│   ├── statistical-modeling.md       # existing — expand significantly
│   ├── analysis-phases.md            # NEW — 80-100 lines
│   ├── observational-methods.md      # NEW — 120-150 lines
│   ├── sensitivity-analysis.md       # NEW — 80-100 lines
│   └── strobe-checklist.md           # NEW — 60-80 lines
├── templates/
│   ├── study-protocol.md             # NEW — 100-130 lines
│   ├── analysis-plan.md              # NEW — 120-150 lines
│   └── findings-report.md            # NEW — 100-120 lines
└── tools/
    ├── r-packages.md                  # existing — expand significantly
    └── mcp-guide.md                   # existing — minor update
```

**Total**: ~1,400–1,700 lines across all context files (up from 248). Proportionate to present's ~3,200 lines.

**index.json design** (12–14 entries):
- `domain/` files → load for research agent + `/epi` command
- `patterns/` files → load for both agents (research + implement)
- `templates/` files → load for implement agent only
- `tools/` files → load for both agents + `/epi` command

**Scope boundaries** (hard):
- No Quarto rendering pipeline
- No PubMed search automation
- No general R extension
- No federated analysis
- No peer review response workflow

**Emerging trends to incorporate now** (low effort):
- Target trial emulation — reference in study-designs.md (no package commitment)
- `brms` — add to r-packages.md immediately (practical Bayesian entry point)
- TMLE/causal forests — brief mention in study-designs.md (defer full coverage)

---

## Synthesis

### Conflicts Resolved

1. **Package list scope** — Teammates A and C both flagged the infectious disease bias in r-packages.md. No conflict; both agree on expanding to cover observational epi packages. Teammate D confirmed via CRAN Task View analysis that the extension should go beyond the task view's infectious-disease-only scope.

2. **Architecture choice** — Teammate D evaluated 4 options (by phase, by study type, by analysis domain, hybrid). No teammate disagreed with the hybrid recommendation. The hybrid structure avoids the duplication problem of study-type-based organization while maintaining workflow coherence.

3. **Template vs. no-template debate** — Teammate C noted the present extension has 4 templates while epi has 0. Teammate D proposed 3 templates (study-protocol, analysis-plan, findings-report). Teammate A's code patterns provide the content that would populate these templates. Resolved: templates are needed, but defer study-protocol until /epi command stabilizes.

4. **Causal inference file placement** — Teammate C recommended `domain/causal-inference.md` as a standalone file. Teammate D's architecture placed DAG content within `domain/study-designs.md`. Resolved: causal inference is large enough and high-risk enough to warrant its own file in `domain/`. Study-designs.md references it for cross-linking.

### Gaps Identified

1. **Pharmacoepidemiology** — Teammate C identified new user design, SCCS, and case-crossover as P4 gaps. These are specialized but increasingly important. Recommend deferring to a future `epi:pharma` sub-type.

2. **Genetic/molecular epidemiology** — Low priority per Teammate C (niche), confirmed by Teammate D (out of scope for task 400). Defer indefinitely.

3. **Power analysis** — Teammate C flagged `pwr`, `powerSurvEpi`, `epiR` for sample size. Not covered by any other teammate. Include brief section in study-designs.md under each design type.

4. **Model diagnostics** — Teammate C noted only cox.zph is documented. Teammate A's report includes diagnostics for each model type. Recommend consolidating diagnostic patterns into the expanded statistical-modeling.md.

### Recommendations

**File creation priority order** (synthesized from all teammates):

| Priority | File | Source | Est. Lines |
|----------|------|--------|-----------|
| P1 | `domain/study-designs.md` | D (must), C (P1), A (content source) | 150-200 |
| P1 | `domain/causal-inference.md` | C (P1 risk), A (code patterns) | 120-150 |
| P1 | `domain/missing-data.md` | C (P1 risk), A (mice workflow) | 100-120 |
| P1 | `patterns/observational-methods.md` | C (P1), A (PS/CR code) | 120-150 |
| P1 | `tools/r-packages.md` (expand) | C (P1), D (must), A/B (content) | expand by ~200 |
| P1 | `patterns/analysis-phases.md` | D (must), C (process gap) | 80-100 |
| P2 | `domain/data-ethics.md` | C (P2 legal risk) | 60-80 |
| P2 | `domain/reporting-standards.md` | D (should), B (content source) | 80-100 |
| P2 | `patterns/strobe-checklist.md` | D (must zero-cost), B (content) | 60-80 |
| P2 | `patterns/statistical-modeling.md` (expand) | C (expand), A (code patterns) | expand by ~150 |
| P3 | `templates/analysis-plan.md` | D (should) | 120-150 |
| P3 | `templates/findings-report.md` | D (should), B (format guidance) | 100-120 |
| P3 | `domain/data-management.md` | D (should), C (P3) | 120-160 |
| P3 | `patterns/sensitivity-analysis.md` | C (P3) | 80-100 |
| P4 | `domain/r-workflow.md` | D (can defer) | 80-100 |
| P4 | `templates/study-protocol.md` | D (defer until /epi stabilizes) | 100-130 |

**R package additions** (consolidated from all teammates):

Must add immediately:
- `gtsummary`, `tableone`, `modelsummary` (tables)
- `mice`, `naniar`, `Amelia` (missing data)
- `MatchIt`, `WeightIt`, `cobalt` (propensity scores)
- `cmprsk`, `tidycmprsk` (competing risks)
- `dagitty`, `ggdag` (causal inference)
- `episensr`, `EValue` (sensitivity analysis)
- `brms` (Bayesian — practical entry point)
- `rms` (regression modeling strategies)
- `CMAverse` (mediation analysis)
- `epiR`, `epitools` (basic epidemiology)
- `REDCapR` (data collection)
- `incidence2` (epidemic curves — replaces `incidence`)
- `PRISMA2020` (replaces `PRISMAstatement`)

Should add:
- `targets`, `renv` (reproducibility)
- `flextable`, `gt` (table formatting)
- `patchwork`, `cowplot` (multi-panel figures)
- `forestploter` (forest plots)
- `pROC`, `dcurves` (prediction model validation)
- `interactionR` (RERI computation)
- `cleanepi`, `linelist` (data cleaning)
- `survey`, `srvyr` (survey methods)

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | Study types & R code | completed | high | Comprehensive code patterns for all study designs |
| B | Publication outputs & reporting | completed | high | Full table/figure/guideline/reproducibility toolkit |
| C | Critic: domain knowledge gaps | completed | high | Prioritized gap analysis with risk assessment |
| D | Horizons: strategic architecture | completed | high | Directory structure, index.json design, scope boundaries |

---

## References

### External Sources (cited by teammates)
- [The Epidemiologist R Handbook](https://www.epirhandbook.com/) — structure model and code reference
- [R4Epi](https://www.r4epi.com/) — teaching-oriented R for epidemiology
- [CRAN Task View: Epidemiology](https://cran.r-project.org/web/views/Epidemiology.html) — package inventory (March 2025)
- [STROBE Statement](https://www.strobe-statement.org/) — observational study reporting
- [EQUATOR Network](https://www.equator-network.org/) — reporting guideline hub
- [Target Trial Emulation — Annals of Internal Medicine 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC11936718/)
- [TRIPOD+AI Statement 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11019967/)
- [gtsummary documentation](https://www.danieldsjoberg.com/gtsummary/)
- [modelsummary documentation](https://modelsummary.com/)
- [brms package](https://paulbuerkner.com/brms/)
- [MatchIt documentation](https://kosukeimai.github.io/MatchIt/)
- [dagitty web tool](http://www.dagitty.net/)
- [Quarto journal templates](https://quarto.org/docs/journals/templates.html)
- [targets for reproducible analysis](https://docs.ropensci.org/targets/)

### Teammate Reports
- `specs/400_epi_extension_overhaul/reports/02_teammate-a-findings.md` — Study types and R code patterns
- `specs/400_epi_extension_overhaul/reports/02_teammate-b-findings.md` — Publication outputs and reporting
- `specs/400_epi_extension_overhaul/reports/02_teammate-c-findings.md` — Domain knowledge gaps critique
- `specs/400_epi_extension_overhaul/reports/02_teammate-d-findings.md` — Strategic horizons
