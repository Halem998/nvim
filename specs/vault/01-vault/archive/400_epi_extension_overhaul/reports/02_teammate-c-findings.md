# Teammate C: Critical Gaps in Epidemiology Extension Domain Knowledge

**Task**: 400 — Epidemiology Extension Overhaul
**Role**: Critic — evaluate missing or incomplete domain knowledge
**Date**: 2026-04-10
**Output**: `specs/400_epi_extension_overhaul/reports/02_teammate-c-findings.md`

---

## Executive Summary

The epidemiology extension has a **domain knowledge crisis, not just a routing crisis**. The previous research round (01_team-research.md) correctly identified the infrastructure gaps (routing, skills, agents). This report focuses on what the extension would need to say once the routing works — what knowledge must agents have to be genuinely useful to an epidemiologist, not just a generic R programmer who knows the word "cohort."

**The fundamental problem**: the four existing context files (~248 lines total) cover only the surface of infectious disease modeling. An epidemiologist asking about competing risks, spatial clustering, propensity score overlap, or quantitative bias analysis would receive no meaningful guidance beyond what any statistics-aware agent already knows. The extension provides label-matching ("this is an epi task") without domain expertise.

**Comparison**: The `present` extension has 44 context files with domain-specific writing formulas, funder-specific templates, quantified specificity ladders, and anti-pattern tables. The epi extension has 4 files with basic package names and generic model descriptions. The gap is roughly 10:1 in domain knowledge depth.

---

## Gap Analysis by Dimension

### A. R Package Coverage — Rating: INADEQUATE

**What exists**: EpiModel, epidemia, EpiNow2, EpiEstim, epiparameter, survival, survminer, epitools, Epi.

**What is missing**:

#### A1. Observational Study Packages (HIGH impact — these are more common than infectious disease modeling)
The extension reads as if epidemiology = infectious disease modeling. Most epidemiologists work in chronic disease, pharmacoepidemiology, or health services. None of these are covered:

| Package | Purpose | Missing? |
|---------|---------|---------|
| `MatchIt` | Propensity score matching | Yes |
| `WeightIt` | IPW / IPTW weighting | Yes |
| `cobalt` | Balance assessment after matching/weighting | Yes |
| `Hmisc` | Data description, multiple imputation support | Yes |
| `mice` | Multiple imputation by chained equations | Yes |
| `tableone` | Table 1 generation (ubiquitous in epi papers) | Yes |
| `gtsummary` | Publication-quality Table 1 and regression tables | Yes |
| `rms` | Regression Modeling Strategies — calibration, validation, NNT | Yes |
| `cmprsk` | Competing risks regression (Fine-Gray model) | Yes |
| `tidycmprsk` | Tidy interface to competing risks | Yes |
| `episensr` | Quantitative bias analysis / sensitivity analysis | Yes |
| `EValue` | E-value computation for unmeasured confounding | Yes |

**Confidence**: High. These are standard packages cited in any epidemiology methods textbook (Rothman, Greenland, Lash; Hernan & Robins).

#### A2. Spatial Epidemiology Packages (MEDIUM impact — growing field)
Zero spatial coverage in current extension:

| Package | Purpose |
|---------|---------|
| `spdep` | Spatial dependence, Moran's I, spatial regression |
| `sf` | Simple features for spatial data handling |
| `SpatialEpi` | Kulldorff spatial scan statistic, disease mapping |
| `sparr` | Spatial relative risk, kernel density estimation |

#### A3. Genetic / Molecular Epidemiology Packages (LOW impact — niche)
Missing but low priority given user profile uncertainty:
- `ape`, `ggtree`, `phangorn` for phylogenetic epidemiology
- `SNPassoc` for genetic association studies

#### A4. Infectious Disease Packages — Partially Covered but Gaps Remain
The existing coverage of EpiModel/EpiNow2/EpiEstim is reasonable but misses:
- `pomp` — partially observed Markov process models (gold standard for complex dynamics)
- `SimInf` — stochastic disease transmission in large populations
- `odin` / `odin2` — ODE-based compartmental models (EpiEstim team's successor tooling)
- `R0` — classic R0 estimation (Wallinga-Lipsitch)
- `earlyR` — early outbreak R estimation (Bpagnou)
- `outbreaker2` — outbreak reconstruction via sequence + epi data

---

### B. Methodological Gaps — Rating: CRITICAL

These are the gaps most likely to cause an AI assistant to give actively wrong guidance.

#### B1. Causal Inference Methods (HIGH impact — agents will get this wrong without guidance)

The README mentions "Directed Acyclic Graphs (DAGs)" in one line. An agent given a causal question without this context will:
- Suggest adjustment for colliders (wrong)
- Recommend adjustment for mediators when the question is total effect (wrong)
- Not distinguish between total effect and direct effect estimands
- Not know when to use IPW vs. outcome regression vs. doubly robust estimation

**What's missing**:
- DAG construction conventions (backdoor criterion, frontdoor criterion)
- Collider bias — what it is, why conditioning on a collider opens a path
- Selection bias through DAGs
- Mediation: natural direct/indirect effects, controlled direct effects
- `dagitty` package (web tool + R package for DAG analysis)
- `ggdag` package (ggplot2 DAG visualization)
- When propensity score matching is appropriate vs. not
- Overlap (positivity) violation: how to detect and handle

**Confidence**: High. Missing DAG guidance is a known failure mode for LLMs doing epidemiology (they confuse confounding and mediation, and over-adjust).

#### B2. Missing Data (HIGH impact — every real dataset has missing data)

Not mentioned at all in current extension. An agent without this context will default to complete-case analysis, which is almost never appropriate.

**What's missing**:
- MCAR / MAR / MNAR framework (definitions and how to assess)
- When complete-case analysis is valid (MCAR only, with caveats)
- Multiple imputation with `mice`: how to pool results (`pool()`), how to impute predictors only, how to handle passive imputation
- Sensitivity analysis for MNAR (pattern mixture models, tipping point analysis)
- Missing data visualization: `naniar`, `VIM` packages
- The "10% rule" myth: why small missingness % doesn't justify complete-case

**Confidence**: High. Missing data handling is one of the most common questions epidemiologists have for any coding assistant.

#### B3. Competing Risks (HIGH impact — survival analysis without this is incomplete)

Not mentioned. When an agent sees a survival analysis question, it will suggest Cox regression. If the outcome can be prevented by a competing event (e.g., death from other causes when studying cancer-specific mortality), Cox is incorrect.

**What's missing**:
- When competing risks matter vs. when they don't
- Cause-specific hazard vs. subdistribution hazard (Fine-Gray) — different estimands, different interpretations
- `cmprsk::crr()` and `tidycmprsk` syntax
- Cumulative incidence function (CIF) vs. 1 - Kaplan-Meier (the latter overestimates in competing risks settings)
- Competing risks interpretation: "the probability of event X in the presence of competing event Y"

**Confidence**: High.

#### B4. Effect Modification and Interaction (HIGH impact — agents routinely confuse these)

The statistical-modeling.md file has no coverage of interaction. This matters because:
- Additive interaction (RERI) and multiplicative interaction are different estimands
- In epidemiology, additive interaction is usually the public health relevant measure
- Most agents default to multiplicative interaction terms in regression models

**What's missing**:
- RERI (Relative Excess Risk due to Interaction) — formula and interpretation
- Difference between statistical interaction and biological interaction
- How to compute RERI from logistic regression coefficients (non-obvious formula)
- `interactionR` package for RERI computation
- When to report on additive vs. multiplicative scale

**Confidence**: High. RERI computation is a specific, non-obvious task where an agent without this knowledge will give wrong formulas.

#### B5. Sensitivity Analysis Frameworks (MEDIUM-HIGH impact)

README mentions "Sensitivity analysis" in one line. No operational guidance exists.

**What's missing**:
- E-value framework (VanderWeele & Ding 2017): what it is, how to compute, how to interpret
- `EValue` package usage
- Quantitative bias analysis: unmeasured confounding, selection bias, misclassification
- `episensr` package: bias analysis workflow
- Tipping point analysis for unmeasured confounders
- When to report E-values vs. full QBA

**Confidence**: High. E-values are now expected in many epi journals and an agent won't know this.

#### B6. Propensity Score Methods (MEDIUM-HIGH impact)

Not mentioned at all. These are the dominant method in pharmacoepidemiology and health services research.

**What's missing**:
- Propensity score estimation (logistic regression, machine learning variants)
- Matching vs. weighting vs. stratification — when each is appropriate
- Balance assessment: standardized mean differences (not p-values)
- `MatchIt`, `WeightIt`, `cobalt` workflow
- Overlap (positivity) violation detection: propensity score distribution plots
- IPW / IPTW: stabilized vs. unstabilized weights, extreme weights handling
- ATE vs. ATT vs. ATC estimands

**Confidence**: High.

#### B7. Pharmacoepidemiology Study Designs (MEDIUM impact — specialized but important)

No coverage. These designs are commonly misunderstood and an agent without guidance will suggest standard cohort/case-control when a more appropriate design exists.

**What's missing**:
- New user / incident user design (why prevalent user bias matters)
- Active comparator design (why comparator choice is critical)
- Self-controlled case series (SCCS): when to use, the exposure risk window
- Case-crossover design: matching structure, conditional logistic regression
- `SCCS` R package

#### B8. Time Series for Disease Surveillance (MEDIUM impact)

EpiEstim and EpiNow2 are covered (Rt estimation), but population-level surveillance analytics are missing:

**What's missing**:
- `surveillance` package: aberration detection (Farrington, CUSUM), STS objects
- Interrupted time series analysis (ITS): when to use, segmented regression
- Seasonality adjustment methods
- `tscount` for count time series
- ARIMA for disease counts (overdispersion, zero inflation)

---

### C. Data Management Patterns — Rating: POOR

The extension has no data management guidance at all. This is a severe gap because data preparation consumes 60-80% of real epidemiology analysis time.

#### C1. REDCap Integration (HIGH impact — dominant data collection tool in academic epi)

REDCap is the most commonly used data collection platform in academic epidemiology and clinical research. Not mentioned.

**What's missing**:
- `REDCapR` package: `redcap_read()`, API token management
- Long vs. wide format for longitudinal REDCap data
- Handling REDCap branching logic in R
- Data dictionary import and variable labeling

**Confidence**: High. A researcher asking "how do I import my REDCap data" will get no useful guidance.

#### C2. Data Confidentiality and PHI in Code Repos (HIGH impact — legal/ethical risk)

Not mentioned. An agent without this guidance might help a user accidentally commit PHI to a git repository.

**What's missing**:
- `.gitignore` patterns for common sensitive file types (`.csv`, `.xlsx`, `.dta`, `.sas7bdat`, data directories)
- The principle: code goes in git, data never does
- Environment variables for API tokens (REDCap, database credentials)
- `usethis::edit_r_environ()` for local credential storage
- IRB data use agreement implications for cloud storage

**Confidence**: High. This is an ethics/legal issue where wrong guidance has real consequences.

#### C3. Common Data Models (MEDIUM impact)

No coverage of OMOP CDM, PCORnet, Sentinel — these are increasingly used for multi-site research.

#### C4. Codebook and Data Dictionary Patterns (MEDIUM impact)

Real epidemiology analysis requires mapping variable names to labels. No coverage of:
- `labelled` package for value labels
- `codebook` package for automated codebook generation
- Variable naming conventions (SAS-inherited 8-char limits in some datasets)

---

### D. Statistical Validation — Rating: INADEQUATE

#### D1. Model Diagnostics (HIGH impact — agents skip these)

The Cox model section correctly mentions `cox.zph()` for PH assumption. That's the only diagnostic mentioned anywhere. Missing:
- Logistic regression diagnostics: Hosmer-Lemeshow test (and its limitations), calibration curves, ROC/AUC
- Influential observations: Cook's distance, DFBETAs for logistic/Cox
- Overdispersion testing in Poisson models
- VIF / multicollinearity assessment
- Residual plots and what patterns indicate

#### D2. Prediction Modeling and Validation (MEDIUM-HIGH impact)

The extension covers association (etiologic) modeling but not prediction modeling. These have different analytical goals and different validation requirements.

**What's missing**:
- `rms` package: `lrm()`, `validate()`, calibration
- Apparent vs. internal validation (bootstrap, cross-validation)
- LASSO / elastic net for variable selection: `glmnet`
- `nomogram()` for clinical risk scores
- C-statistic / Harrell's C-index for discrimination
- Calibration: O:E ratio, calibration plot

#### D3. Multiple Testing (MEDIUM impact)

Not mentioned. Epidemiologists are often confused about when to adjust for multiple comparisons.

**What's missing**:
- When FDR correction is appropriate (exploratory gene association studies) vs. not (confirmatory epi)
- The Bonferroni correction and its conservatism in correlated tests
- `p.adjust()` in R
- The "primary analysis + secondary analyses" framework that avoids the multiple testing problem by pre-specification

#### D4. Power Analysis (MEDIUM impact)

Not mentioned.

**What's missing**:
- `pwr` package for basic power calculations
- `powerSurvEpi` for survival studies
- `epiR` for epidemiologic sample size (case-control, cohort)
- Sample size calculation philosophy: why you need it before data collection, and what to do when you have existing data

---

### E. What Epidemiologists Actually Ask (Practical Perspective)

Based on the nature of epidemiology research in R, here are the most frequent questions an AI coding assistant receives. None of these have adequate coverage:

| Frequency | Question | Current Coverage |
|-----------|----------|-----------------|
| Very high | "How do I make a Table 1 in R?" | None |
| Very high | "How do I handle missing data in my covariates?" | None |
| Very high | "How do I check my Cox model assumptions?" | 1 line (cox.zph) |
| High | "How do I do propensity score matching?" | None |
| High | "How do I interpret the odds ratio vs. risk ratio?" | None (only mentions these exist) |
| High | "My outcome is rare — should I use logistic or Poisson?" | None |
| High | "How do I report my results per STROBE?" | None |
| Medium | "How do I compute an E-value?" | None |
| Medium | "How do I handle competing risks in my survival analysis?" | None |
| Medium | "How do I load my REDCap data?" | None |
| Medium | "Should I adjust for the mediator?" | None |

**The most dangerous gap**: An agent will confidently answer all of these questions — but without domain knowledge, it will give correct-sounding but methodologically wrong answers (e.g., adjusting for a collider, using 1 - KM instead of CIF for competing risks, using complete-case analysis for MAR data).

---

### F. Comparison to `present` Extension Depth

The `present` extension demonstrates what domain depth looks like:

| Dimension | `present` | `epidemiology` | Gap |
|-----------|-----------|----------------|-----|
| Context files | 44 | 4 | 11x |
| Templates | 4 (with fill-in-the-blank slots) | 0 | - |
| Anti-patterns documented | Yes (weak vs. strong writing) | None | - |
| Domain-specific checklists | 1 (STROBE-like submission checklist) | 0 | - |
| Specific formulas/computations | Yes (impact statement formula) | None | - |
| Funder/journal-specific conventions | Yes | None | - |
| Workflow stages with concrete steps | 4 stages, each with bullet lists | 1 generic 7-step workflow | - |

The `present` extension tells an agent *exactly what to write and how to write it*. The epi extension tells an agent *what topics exist*.

---

## Prioritized Recommendations

### Priority 1 — HIGH impact, HIGH frequency, HIGH risk of wrong output

1. **`domain/causal-inference.md`** — DAG conventions, collider/mediator/confounder distinctions, `dagitty` / `ggdag` packages, backdoor criterion. Without this, agents will over-adjust.

2. **`domain/missing-data.md`** — MCAR/MAR/MNAR framework, `mice` workflow, complete-case assumptions, `naniar` visualization. Without this, agents default to listwise deletion.

3. **`domain/observational-methods.md`** — Propensity scores (MatchIt, WeightIt, cobalt), competing risks (cmprsk, tidycmprsk), RERI for additive interaction. Without this, the extension has no coverage of 80% of modern epi methods.

4. **`tools/r-packages.md` — EXPAND** — Add `tableone`/`gtsummary`, `mice`, `MatchIt`/`WeightIt`/`cobalt`, `cmprsk`/`tidycmprsk`, `episensr`/`EValue`, `rms`, `dagitty`/`ggdag`. The current package list is biased toward infectious disease to the near-exclusion of observational epidemiology.

5. **`patterns/statistical-modeling.md` — EXPAND** — Add: competing risks workflow, propensity score workflow, missing data workflow. The current file has only 4 patterns.

### Priority 2 — MEDIUM impact, but prevents legal/ethical failures

6. **`domain/data-ethics.md`** — PHI handling, `.gitignore` for data files, REDCap API patterns, credential management. An agent without this could instruct a user to commit PHI.

7. **`tools/r-packages.md` — REDCAP** — Add `REDCapR` with basic usage. REDCap is ubiquitous in academic epi.

### Priority 3 — HIGH methodological value, MEDIUM frequency

8. **`domain/sensitivity-analysis.md`** — E-value framework, `episensr` for quantitative bias analysis, tipping point analysis for unmeasured confounders.

9. **`domain/prediction-modeling.md`** — `rms` calibration/validation workflow, LASSO via `glmnet`, C-statistic vs. R-squared, cross-validation pattern.

10. **`patterns/reporting-checklists.md`** — STROBE checklist (22 items), CONSORT CONSORT (25 items), with R-specific annotations ("item 14a: provide SD for continuous variables, use `tbl_summary()` for this").

### Priority 4 — MODERATE impact, specialized audience

11. **`domain/spatial-epidemiology.md`** — `spdep`, `sf`, `SpatialEpi`, Kulldorff scan statistic, Moran's I.

12. **`domain/surveillance-methods.md`** — `surveillance` package, aberration detection, interrupted time series.

13. **`domain/pharma-epi.md`** — New user design, active comparator design, SCCS.

---

## Critical Risks (what an agent gets wrong without this knowledge)

| Risk | Scenario | Consequence |
|------|----------|-------------|
| Collider bias | User has mediator or collider in dataset, agent recommends adjusting for it | Invalid causal estimate, wrong scientific conclusion |
| Competing risks ignored | User has cancer-specific mortality outcome, agent uses KM/Cox | 1-KM overestimates CIF; KM is biased upward for cause-specific incidence |
| Complete-case default | User has MAR missing data (common), agent drops missing observations | Biased estimates if data not MCAR |
| PHI in git | User asks agent to save data to a file for later analysis, agent writes raw data to project directory | HIPAA/IRB violation if committed |
| E-value not mentioned | User submits to NEJM/Lancet without E-value, reviewer requests it | Revision delay; reviewer may reject |
| RERI ignored | User asks about interaction between two binary exposures, agent returns multiplicative interaction only | Wrong public health interpretation; RERI is usually the reported measure |

---

## Structural Observations (about gaps in extension architecture)

### O1. No Templates at All

The `present` extension has 4 templates with fill-in-the-blank slots that agents populate. The epi extension has zero. An agent implementing a survival analysis report has no template for what the output should look like. For a domain with rigid reporting standards (STROBE, CONSORT), this is a significant omission.

**Needed**: `templates/table1.md`, `templates/cox-results-table.md`, `templates/strobe-checklist.md`, `templates/findings-report.md`.

### O2. No Anti-patterns

The `present` extension explicitly lists "WEAK: / CLEAR:" pairs to guide writing. The epi extension has no comparable "WRONG: / CORRECT:" pairs for statistical methods. An agent will not know which approaches are considered outdated or methodologically problematic.

**Needed**: Anti-pattern section in `statistical-modeling.md` covering: unadjusted OR without propensity score when confounding is substantial, 1-KM for competing risks, complete-case analysis for MAR, Bonferroni in non-confirmatory settings.

### O3. No Interpretation Guidance

The existing modeling patterns show code but give minimal interpretation guidance. For example, the logistic regression pattern shows `exp(coef(model))` but does not say:
- When OR ≈ RR (rare disease assumption)
- Why OR is not the same as RR and when it overcorrects
- How to decide whether to report OR or RR (modified Poisson / log-binomial)

Interpretation is what separates an epidemiologically literate AI from a generic statistics AI.

### O4. Skew Toward Infectious Disease

Of the 73 lines in `r-packages.md`, 58 (79%) cover infectious disease packages (EpiModel, epidemia, EpiNow2, EpiEstim, epiparameter). These are important but represent a minority of epidemiology research output. Chronic disease, pharmacoepidemiology, and health services research are the dominant subfields by volume of publications and funding.

**Recommended split**: 40% infectious disease / 60% observational methods.

---

## Summary Scorecard

| Domain | Current State | Required State | Priority |
|--------|--------------|----------------|----------|
| Infectious disease modeling | Adequate (EpiModel, EpiNow2) | Add pomp, odin, R0, outbreaker2 | Low |
| Observational methods | Missing | Add propensity scores, competing risks, RERI | P1 |
| Causal inference / DAGs | 1 line | Add full DAG workflow document | P1 |
| Missing data | Missing | Add MCAR/MAR/MNAR, mice workflow | P1 |
| Data ethics / PHI | Missing | Add .gitignore, REDCap, credentials | P2 |
| Reporting standards | Missing | Add STROBE, CONSORT checklists | P3 |
| Sensitivity analysis | 1 line | Add E-value, episensr workflow | P3 |
| Prediction modeling | Missing | Add rms, glmnet workflow | P3 |
| Spatial epidemiology | Missing | Add spdep, SpatialEpi | P4 |
| Surveillance methods | Missing | Add surveillance package | P4 |
| R package list completeness | ~40% | Expand to include observational tools | P1 |
| Templates | 0 | Add 3-4 output templates | P3 |
| Anti-patterns | 0 | Add to statistical-modeling.md | P2 |
| Interpretation guidance | Minimal | Add OR vs. RR, estimand framing | P1 |

**Overall assessment**: The extension provides ~20% of the domain knowledge an epidemiologist actually needs. The missing 80% is weighted toward the most common analytical tasks (observational methods, causal inference, missing data), not niche topics. The infrastructure work (routing, skills, agents) is necessary but insufficient — a routed, well-structured agent that loads these four files will still give methodologically naive answers.
