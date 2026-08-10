# Teammate B Research Findings: Epidemiology Publication Outputs & Reporting

**Task**: 400 — Epi Extension Overhaul
**Artifact**: 02
**Scope**: Publication tables, figures, reporting guidelines, reproducibility tools, journal requirements

---

## Executive Summary

Epidemiological publication in R has converged on a coherent ecosystem:
- **Tables**: `gtsummary` dominates descriptive and regression tables; `modelsummary` excels at multi-model comparison
- **Figures**: `survminer`, `ggdag`, `forestploter`, `ggplot2` + `patchwork`/`cowplot` are the core stack
- **Reporting**: STROBE/CONSORT/PRISMA are the most required; TRIPOD+AI is rising for prediction models
- **Reproducibility**: `targets` + `renv` + Quarto is the current gold standard pipeline
- **Manuscripts**: Quarto journal templates eliminate manual copy-paste of statistics

Confidence levels are indicated per section: **HIGH** (authoritative docs/official packages), **MEDIUM** (well-documented practice, may vary by journal), **LOW** (evolving/niche).

---

## 1. Publication Tables

### 1.1 Table 1: Descriptive/Baseline Characteristics

**Confidence: HIGH**

#### Primary Package: `gtsummary`

Since 2020, `gtsummary` has become the dominant package for Table 1 in medical/epidemiological research. The canonical citation is Sjoberg et al., *The R Journal* 2021.

**Core workflow:**
```r
library(gtsummary)

# Basic Table 1 stratified by treatment group
trial |>
  tbl_summary(
    by = trt,
    include = c(age, grade, stage, marker),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = all_continuous() ~ 1,
    label = list(age ~ "Age (years)", grade ~ "Tumor Grade"),
    missing = "ifany"         # Show missing as row if present
  ) |>
  add_overall() |>            # Add total column
  add_p() |>                  # Comparison p-values
  add_difference() |>         # Difference with 95% CI
  bold_labels() |>
  modify_caption("**Table 1. Baseline Characteristics**") |>
  modify_spanning_header(c("stat_1", "stat_2") ~ "**Treatment Group**")
```

**Key features:**
- Auto-detects continuous, categorical, and dichotomous variables
- Reports missing data per variable
- Calculates standardized mean differences (SMD) with `add_difference()`
- Exports to Word (`as_flex_table()`), HTML, PDF, or gt format

**Conventions enforced by `gtsummary`:**
- Continuous: `mean (SD)` or `median [IQR]` (user-selectable)
- Categorical: `N (%)`
- Missing: shown as row with N and %

#### Legacy Alternative: `tableone`

`tableone::CreateTableOne()` remains in use, particularly in older codebases and some biostatistics programs. Less flexible formatting than `gtsummary` but faster for quick checks.

```r
library(tableone)
vars <- c("age", "sex", "bmi", "chol")
tab1 <- CreateTableOne(vars = vars, strata = "group", data = df)
print(tab1, smd = TRUE, showAllLevels = TRUE, quote = FALSE, noSpaces = TRUE)
```

#### Formatting Packages

| Package | Use Case |
|---------|----------|
| `flextable` | Word/PowerPoint export from any data frame; used in the Epi R Handbook |
| `gt` | HTML/PDF output, programmable styling |
| `kableExtra` | LaTeX/PDF tables in Rmd/Quarto |
| `huxtable` | Excel-compatible output |

---

### 1.2 Regression Result Tables

**Confidence: HIGH**

#### `gtsummary::tbl_regression()` — Primary Tool

```r
library(gtsummary)

# Logistic regression — Odds Ratios
m_logistic <- glm(response ~ age + stage + grade, trial, family = binomial)

tbl_regression(
  m_logistic,
  exponentiate = TRUE,                     # Report OR instead of log-odds
  conf.level = 0.95,
  label = list(stage ~ "Cancer Stage")
) |>
  add_global_p() |>                        # Global p-value for categorical vars
  bold_p(t = 0.05) |>
  bold_labels() |>
  italicize_levels() |>
  modify_caption("**Table 2. Logistic Regression Results**")
```

**Supported model types** (via `broom` tidiers):
- `glm()` — logistic, Poisson, negative binomial
- `survival::coxph()` — Cox proportional hazards (auto-reports HR)
- `survival::survreg()` — parametric survival
- `lme4` mixed models, `survey` weighted regression

**`tbl_uvregression()`** for screening univariate associations:
```r
trial |>
  tbl_uvregression(
    method = glm,
    y = response,
    method.args = list(family = binomial),
    exponentiate = TRUE
  ) |>
  add_global_p()
```

#### `broom` — Model Tidying Infrastructure

`gtsummary` internally calls `broom::tidy()`. Direct use:
```r
library(broom)

# Extract tidy coefficients
tidy(m_logistic, conf.int = TRUE, exponentiate = TRUE)
# -> data frame with: term, estimate, conf.low, conf.high, p.value

# Model fit statistics
glance(m_logistic)
# -> AIC, BIC, deviance, df.residual

# Augmented predictions
augment(m_logistic, type.predict = "response")
```

#### `modelsummary` — Multi-Model Comparison

Best for presenting multiple models side by side (e.g., unadjusted vs. adjusted, or sensitivity analyses):

```r
library(modelsummary)

m1 <- glm(outcome ~ exposure, data = df, family = binomial)
m2 <- glm(outcome ~ exposure + age + sex, data = df, family = binomial)
m3 <- glm(outcome ~ exposure + age + sex + comorbidity, data = df, family = binomial)

modelsummary(
  list("Unadjusted" = m1, "Minimally Adjusted" = m2, "Fully Adjusted" = m3),
  exponentiate = TRUE,
  statistic = "conf.int",
  gof_omit = "AIC|BIC|Log|F|RMSE",
  output = "table.docx"         # Direct to Word
)
```

#### `stargazer` — LaTeX/HTML Output

Still widely used in economics-adjacent epidemiology and for journal LaTeX submissions:
```r
library(stargazer)
stargazer(m1, m2, m3, type = "latex",
          apply.coef = exp, apply.se = exp,   # Exponentiate
          ci = TRUE, ci.level = 0.95,
          title = "Regression Results")
```

**Note**: `stargazer` is no longer actively maintained. `modelsummary` is the modern replacement.

---

### 1.3 Other Standard Epidemiology Tables

**Confidence: MEDIUM**

#### Incidence/Prevalence Tables

```r
library(epiR)

# 2x2 table with RR, OR, RD, person-time
epi.2by2(dat = matrix(c(cases, noncases, pop1, pop2), nrow=2),
         method = "cohort.count",
         conf.level = 0.95)

# Person-time incidence rates
library(epitools)
ratetable(count, person_time, exposure)
```

#### Mantel-Haenszel Stratified Analysis

```r
# Stratified 2x2 tables with MH pooled OR
mantelhaen.test(table(exposure, outcome, stratum))

# Or with epiR for more output
epi.2by2(dat = stratified_table, method = "cohort.count")
```

#### Sensitivity Analysis Summary Tables

```r
# episensr for unmeasured confounding sensitivity
library(episensr)
confounders.ext(crude.or = 2.5, exposed.cf = 0.3, prev.exposure = 0.4)
```

---

## 2. Publication Figures

### 2.1 Kaplan-Meier Survival Curves

**Confidence: HIGH**

`survminer::ggsurvplot()` is the standard for publication-ready KM curves:

```r
library(survival)
library(survminer)

fit <- survfit(Surv(time, status) ~ treatment, data = df)

ggsurvplot(
  fit,
  data = df,
  pval = TRUE,                       # Log-rank p-value
  conf.int = TRUE,
  risk.table = TRUE,                 # Number at risk table
  risk.table.col = "strata",
  surv.median.line = "hv",           # Median survival lines
  legend.labs = c("Control", "Treatment"),
  xlab = "Time (months)",
  ylab = "Survival Probability",
  palette = c("#E7B800", "#2E9FDF"),
  ggtheme = theme_bw(),
  tables.height = 0.2,
  tables.theme = theme_cleantable()
)
```

**Key features:**
- `risk.table`: adds number at risk below curve
- `cumevents`: cumulative events table
- `cumcensor`: cumulative censored table
- `pval.method`: shows log-rank or Breslow test
- `surv.median.line`: annotates median survival

For multiple KM plots: `arrange_ggsurvplots()`.

---

### 2.2 Forest Plots

**Confidence: HIGH**

Multiple packages serve different needs:

#### `forestploter` — Flexible Custom Forest Plots

Best for subgroup analysis tables with custom columns:
```r
library(forestploter)

# Create data frame with estimates and CI
df_forest <- data.frame(
  Subgroup = c("Overall", "Age < 65", "Age >= 65", "Female", "Male"),
  HR = c(0.75, 0.68, 0.82, 0.71, 0.79),
  Lower = c(0.60, 0.50, 0.62, 0.55, 0.58),
  Upper = c(0.94, 0.92, 1.08, 0.92, 1.07),
  N = c(500, 250, 250, 240, 260)
)

forest(df_forest,
       est = "HR", lower = "Lower", upper = "Upper",
       ref_line = 1)
```

#### `metafor` + `meta` — Meta-Analysis Forest Plots

```r
library(meta)

# Meta-analysis forest plot
metagen(TE = log_rr, seTE = se_log_rr, data = studies,
        studlab = study_id, sm = "RR") |>
  forest(sortvar = TE)

# Funnel plot for publication bias
funnel(meta_result, studlab = TRUE)
```

#### `ggforestplot` — ggplot2-based Forest Plots

```r
library(ggforestplot)
forestplot(
  df = df_forest,
  name = Subgroup, estimate = HR,
  se = SE, logodds = TRUE
)
```

---

### 2.3 DAG Visualizations

**Confidence: HIGH**

`ggdag` and `dagitty` are the standard tools:

```r
library(ggdag)
library(dagitty)

# Define DAG
dag <- dagify(
  outcome ~ exposure + confounder + mediator,
  exposure ~ confounder,
  mediator ~ exposure,
  exposure = "exposure",
  outcome = "outcome",
  labels = list(
    exposure = "Smoking",
    outcome = "Lung Cancer",
    confounder = "Age",
    mediator = "Inflammation"
  )
)

# Visualize
ggdag(dag, use_labels = "label", text = FALSE) +
  theme_dag()

# Identify adjustment sets
ggdag_adjustment_set(dag, shadow = TRUE) +
  theme_dag()

# Identify backdoor paths
ggdag_paths(dag) + theme_dag()
```

**Specialized visualizations:**
```r
# Confounding triangle
confounder_triangle(x = "Exposure", y = "Outcome", z = "Confounder") |>
  ggdag_dconnected(controlling_for = "z") +
  theme_dag()

# Collider bias
ggdag_butterfly_bias() + theme_dag()
```

---

### 2.4 Epidemic Curves

**Confidence: HIGH**

```r
library(incidence2)

# Create incidence object
incid <- incidence(df, date_index = "onset_date",
                   interval = "week",
                   groups = "district")

# Plot
plot(incid, fill = "district",
     title = "Weekly Incidence by District",
     date_format = "%b %d")
```

For `EpiCurve` package (simpler syntax):
```r
library(EpiCurve)
EpiCurve(df, date = "onset_date", period = "week",
         cutvar = "case_type")
```

---

### 2.5 Dose-Response and Other Figures

**Confidence: MEDIUM**

#### Dose-Response Curves (Restricted Cubic Splines)

```r
library(rms)

# Fit with splines
dd <- datadist(df)
options(datadist = "dd")

m_spline <- lrm(outcome ~ rcs(exposure, 4) + age + sex, data = df)

# Plot dose-response
ggplot(Predict(m_spline, exposure, fun = plogis),
       ylab = "Probability of Outcome") +
  theme_bw()
```

#### ROC Curves / Discrimination

```r
library(pROC)

roc_obj <- roc(outcome ~ predicted_prob, data = df)
plot(roc_obj, print.auc = TRUE, col = "#2C77BF")

# Multiple ROC comparison
roc_list <- list(
  "Model 1" = roc(outcome ~ prob1, data = df),
  "Model 2" = roc(outcome ~ prob2, data = df)
)
ggroc(roc_list) + theme_bw() + geom_abline(slope = 1, intercept = 1)
```

#### Calibration Plots

```r
library(rms)

# Calibration for logistic regression
m <- lrm(outcome ~ predictors, data = df, x = TRUE, y = TRUE)
cal <- calibrate(m, B = 200)
plot(cal)
```

#### Nomograms

```r
library(rms)
nom <- nomogram(m, fun = plogis, funlabel = "Risk",
                fun.at = c(0.1, 0.25, 0.5, 0.75, 0.9))
plot(nom)
```

#### Funnel Plots

```r
library(meta)
meta_result <- metagen(TE, seTE, data = df, sm = "OR")
funnel(meta_result, studlab = TRUE, level = 0.95)

# Egger's test for asymmetry
metabias(meta_result, method = "linreg")
```

---

### 2.6 Figure Best Practices

**Confidence: HIGH**

#### Theme Standardization

```r
library(ggplot2)

# Recommended base theme for journals
theme_pub <- function(base_size = 11) {
  theme_bw(base_size = base_size) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey90"),
    strip.background = element_rect(fill = "grey95"),
    legend.position = "bottom"
  )
}
```

#### Color-Blind Friendly Palettes

```r
library(ggplot2)
# Okabe-Ito palette (recommended for accessibility)
scale_color_manual(values = c("#E69F00", "#56B4E9", "#009E73",
                               "#F0E442", "#0072B2", "#D55E00", "#CC79A7"))

# Or use viridis
scale_color_viridis_d(option = "plasma")
```

#### Multi-Panel Figures

```r
library(patchwork)

p1 + p2 + p3 + plot_layout(ncol = 2) +
  plot_annotation(tag_levels = "A",
                  title = "Figure 1. Study Results",
                  theme = theme(plot.title = element_text(size = 14, face = "bold")))
```

#### Publication Export

```r
# TIFF for most journals (300 DPI minimum, 600 preferred)
ggsave("figure1.tiff", plot = p, dpi = 600,
       width = 180, height = 120, units = "mm",
       compression = "lzw")

# Vector PDF for journals accepting it
ggsave("figure1.pdf", plot = p, width = 180, height = 120, units = "mm")

# EPS for LaTeX submissions
ggsave("figure1.eps", plot = p, width = 7, height = 5)
```

**Journal dimension conventions (MEDIUM confidence):**
- Single column: ~85 mm (3.35 in)
- Double column: ~170–180 mm (6.7–7 in)
- Full page: 240 mm tall maximum
- Most journals: 300 DPI minimum for raster; vector preferred

---

## 3. Reporting Guidelines

**Confidence: HIGH** (guideline content); **MEDIUM** (R tool compliance support)

### 3.1 STROBE — Observational Studies

**When to use**: Cohort, case-control, cross-sectional studies

**22-item checklist** covering:
- Title/abstract: study design identifier
- Introduction: scientific background, objectives
- Methods: study design, setting, participants, variables, bias, sample size, statistical methods
- Results: participants, descriptive data, outcome data, main results, other analyses
- Discussion: key results, limitations, generalizability
- Other: funding

**R tools that help**:
- `gtsummary` — Items 14 (descriptive), 17 (outcome data), 16 (main results)
- `ggdag`/`dagitty` — Item 16 (DAG for confounders)
- `episensr` — Item 12e (sensitivity analyses for bias)
- No dedicated R package for checklist generation; use the EQUATOR Network checklist

**STROBE-Equity** (2024): Extension for health equity reporting in observational studies.

---

### 3.2 CONSORT — Randomized Controlled Trials

**When to use**: RCTs and quasi-experimental designs

**Key R support:**
- CONSORT flow diagrams: `ggconsort` package
  ```r
  library(ggconsort)
  study_cohorts |>
    consort_box_add("full", 0, 50, cohort_count_adorn(study_cohorts, full)) |>
    consort_box_add("eligible", 0, 40, cohort_count_adorn(study_cohorts, eligible)) |>
    consort_arrow_add(end = "eligible", end_side = "top", start_side = "bottom") |>
    ggconsort()
  ```
- Baseline tables: `gtsummary::tbl_summary(by = arm)`
- Outcome tables: `gtsummary::tbl_regression(exponentiate = TRUE)`

---

### 3.3 PRISMA — Systematic Reviews and Meta-Analyses

**When to use**: Systematic reviews, meta-analyses, scoping reviews

**R package support:**
- `PRISMA2020`: Most up-to-date (PRISMA 2020) flow diagram generator with Shiny app
  ```r
  library(PRISMA2020)
  PRISMA_data <- PRISMA_data(
    database_results = 3000,
    register_results = 150,
    duplicates = 500,
    excluded_automatic = 200,
    excluded_other = 100,
    records_screened = 2450,
    records_excluded = 1800,
    reports_sought = 650,
    reports_not_retrieved = 50,
    reports_assessed = 600,
    reports_excluded = 450,
    new_studies = 150
  )
  PRISMA_flowdiagram(PRISMA_data)
  ```
- `PRISMAstatement`: Older package, PRISMA 2009, less flexible
- `meta`, `metafor`: Statistical analysis and forest plots for meta-analyses

**27-item checklist** including: protocol registration, search strategy, eligibility criteria, risk of bias assessment, synthesis methods, heterogeneity.

---

### 3.4 RECORD — Routinely Collected Data Studies

**When to use**: Administrative data, electronic health records, registries

**Extension of STROBE** with additional items:
- Data sources and linkage methods
- Validation of variables
- Data governance and access

**R tools**: No dedicated package; `linelist` and `cleanepi` help with data quality documentation.

---

### 3.5 TRIPOD / TRIPOD+AI — Prediction Models

**When to use**: Development or validation of clinical prediction models

**Updated 2024** (TRIPOD+AI): covers both regression and machine learning methods.

**22-item checklist** key areas:
- Model development: predictor selection, missing data handling, internal validation
- Model validation: sample description, discrimination (AUC/C-statistic), calibration
- Presentation: regression equation, nomogram, web calculator

**R tools:**
```r
library(rms)
library(pROC)

# C-statistic / AUC
roc(outcome ~ predicted, data = df)$auc

# Calibration
cal <- calibrate(lrm_model, B = 500)
plot(cal)

# Decision curve analysis (clinical utility)
library(dcurves)
dca(outcome ~ predicted_prob, data = df) |> plot()
```

---

### 3.6 CHEERS — Health Economic Evaluations

**When to use**: Cost-effectiveness, cost-utility, cost-benefit analyses

**CHEERS 2022** (updated from 2013): 28-item checklist covering:
- Modelling approaches
- Perspective and time horizon
- Uncertainty analysis (PSA, DSA)

**R tools:**
```r
# BCEA for health economic analysis
library(BCEA)
he <- bcea(e, c, ref = 1, interventions = c("Standard", "New"))
plot(he)  # CEA plane, CEAC, EVPI

# DAMPACK for decision tree/Markov models
library(dampack)
```

---

### 3.7 GATHER — Global Health Estimates

**When to use**: GBD-style estimates, disease burden modeling, country-level health estimates

**18-item checklist**: data sources, systematic review methods, modelling approach, uncertainty.

**R tools**: GBD Collaborator-style workflows; no dedicated package but typically uses:
- `INLA` for spatial/temporal Bayesian modeling
- `ggplot2` with `rnaturalearth` for choropleth maps

---

## 4. Reproducibility and Manuscript Tools

### 4.1 Environment Management

**Confidence: HIGH**

#### `renv` — Project-Level Package Management

The current standard for R project reproducibility:

```r
# Initialize renv in a project
renv::init()

# Snapshot current package versions
renv::snapshot()

# Restore environment from lockfile
renv::restore()

# Check status
renv::status()
```

`renv.lock` records package versions, sources, and R version. Commit to version control.

**Key workflow**: `renv::init()` at project start → `renv::snapshot()` after installing packages → commit `renv.lock` to git.

#### Docker for Full Computational Reproducibility

```dockerfile
FROM rocker/verse:4.4.0
COPY renv.lock renv.lock
RUN R -e "renv::restore()"
```

Use `rocker/r-ver`, `rocker/tidyverse`, or `rocker/verse` base images.

---

### 4.2 Pipeline Management with `targets`

**Confidence: HIGH**

`targets` is the successor to `drake` and the current standard for managing complex epidemiological analysis pipelines:

```r
# _targets.R (pipeline definition file)
library(targets)
library(tarchetypes)

list(
  # Data loading
  tar_target(raw_data, read_csv("data/cohort.csv")),

  # Data cleaning
  tar_target(clean_data, clean_cohort(raw_data)),

  # Analysis
  tar_target(survival_model, fit_cox(clean_data)),
  tar_target(km_curves, plot_km(clean_data)),

  # Tables
  tar_target(table1, make_table1(clean_data)),
  tar_target(regression_table, make_reg_table(survival_model)),

  # Manuscript (Quarto integration)
  tar_quarto(manuscript, "manuscript.qmd")
)
```

**Run pipeline:**
```r
targets::tar_make()        # Run outdated targets
targets::tar_visnetwork()  # Visualize pipeline DAG
targets::tar_read(table1)  # Load specific output
```

**Key benefit**: Only reruns steps whose inputs have changed — critical for time-consuming models.

---

### 4.3 Manuscript Authoring

**Confidence: HIGH**

#### Quarto — Current Standard

```yaml
# manuscript.qmd YAML header
---
title: "Cohort Study of X and Y"
format:
  html: default
  pdf:
    keep-tex: true
  docx: default
bibliography: references.bib
execute:
  echo: false
  warning: false
---
```

**Inline R results** (no copy-paste):
```r
# In Quarto/Rmd text:
The median follow-up time was `r round(median_followup, 1)` months
(IQR: `r round(iqr_low, 1)` -- `r round(iqr_high, 1)`).

The hazard ratio for the primary outcome was
`r sprintf("%.2f (95%% CI: %.2f--%.2f)", hr, ci_low, ci_high)`.
```

**Quarto journal templates** (available via `quarto use template`):
- `quarto-journals/jss` — Journal of Statistical Software
- `quarto-journals/plos` — PLOS journals
- `quarto-journals/elsevier` — Elsevier journals (many epidemiology journals)
- `quarto-journals/acs` — American Chemical Society

**Figure and table cross-references:**
```r
#| label: fig-km
#| fig-cap: "Kaplan-Meier survival curves stratified by treatment group."
ggsurvplot(fit, data = df, pval = TRUE)
```
Then in text: `@fig-km shows...`

#### RMarkdown / papaja

```r
# papaja for APA format manuscripts
library(papaja)
# Creates .docx or PDF conforming to APA 7th edition
apa_table(regression_results)
apa_print(m_logistic)  # Formatted inline statistics
```

---

### 4.4 Supplementary Materials

**Confidence: MEDIUM**

#### Code Repositories

Standard practice: publish analysis code on GitHub/OSF with:
- `README.md` explaining how to reproduce
- `renv.lock` for package versions
- `_targets.R` for pipeline
- Raw data (or synthetic equivalent) under `data/`

#### Interactive Supplementary

```r
# Shiny app embedded in Quarto
library(shiny)
# Or use crosstalk for client-side interactivity
library(crosstalk)
library(DT)
```

#### Data Availability Statements

Journals increasingly require specific language:
- Code: "Analysis code is available at [DOI/URL]"
- Data: "Data are available upon reasonable request" or open data DOI

---

## 5. Journal-Specific Patterns

**Confidence: MEDIUM** (varies by journal and changes over time)

### 5.1 Major Epidemiology Journals

| Journal | Publisher | Impact | LaTeX | Word | Notes |
|---------|-----------|--------|-------|------|-------|
| American Journal of Epidemiology (AJE) | Oxford | High | PDF initial; LaTeX/Word on acceptance | Yes | AMA style references |
| International Journal of Epidemiology (IJE) | Oxford | High | PDF initial; editable on acceptance | Yes | IJE reference style |
| Epidemiology | Wolters Kluwer | High | No specific template | Yes | Relatively flexible |
| JAMA / JAMA Network Open | AMA | Very High | Word preferred | Yes | Structured abstract required |
| The Lancet | Elsevier | Very High | Word preferred | Yes | Strict word limits |
| BMJ | BMJ | Very High | Word | Yes | Open access options |
| NEJM | NEJM Group | Very High | Word | Yes | Highly selective |
| Journal of Clinical Epidemiology | Elsevier | High | Word | Yes | Methods focus |
| European Journal of Epidemiology | Springer | High | LaTeX or Word | Yes | Springer template |

### 5.2 Output Format Strategy

**For Word-submitting journals (most):**
```r
# gtsummary -> Word via flextable
tbl_summary(...) |>
  as_flex_table() |>
  flextable::save_as_docx(path = "table1.docx")

# modelsummary -> Word
modelsummary(models, output = "table2.docx")

# Figures: TIFF 300–600 DPI
ggsave("figure1.tiff", dpi = 600, units = "mm", width = 170)
```

**For LaTeX-accepting journals (IJE, some Springer):**
```r
# gtsummary -> LaTeX
tbl_regression(...) |>
  as_kable_extra(format = "latex", booktabs = TRUE)

# modelsummary -> LaTeX
modelsummary(models, output = "latex")

# stargazer (if legacy workflow)
stargazer(model_list, type = "latex")
```

### 5.3 Reference Management

```r
# In Quarto: BibTeX native
# bibliography: references.bib

# From Zotero: Better BibTeX plugin -> export .bib
# From R: citr package for RMarkdown
# From R: rbbt package for Zotero integration
library(rbbt)
bbt_write_bib("references.bib")
```

---

## 6. Key Package Reference Summary

### Publication Tables

| Package | Primary Use | Output Formats | Status |
|---------|-------------|----------------|--------|
| `gtsummary` | Table 1 + regression tables | HTML, Word, PDF, gt | Active, dominant |
| `tableone` | Quick Table 1 | Console, CSV | Maintained, legacy |
| `modelsummary` | Multi-model comparison | HTML, Word, LaTeX, PDF | Active, modern |
| `stargazer` | LaTeX regression tables | LaTeX, HTML, text | Unmaintained, widespread |
| `flextable` | Custom formatted tables | Word, PowerPoint, HTML | Active |
| `gt` | Programmatic HTML/PDF tables | HTML, PDF, LaTeX | Active |
| `broom` | Model tidying infrastructure | data frames | Active, foundational |

### Visualization

| Package | Primary Use | Status |
|---------|-------------|--------|
| `survminer` | Kaplan-Meier curves | Active |
| `forestploter` | Custom forest plots | Active |
| `meta` / `metafor` | Meta-analysis forest/funnel | Active |
| `ggdag` | Causal DAGs | Active |
| `dagitty` | DAG analysis engine | Active |
| `incidence2` | Epidemic curves | Active |
| `pROC` | ROC curves and AUC | Active |
| `rms` | Calibration, nomograms, splines | Active |
| `dcurves` | Decision curve analysis | Active |
| `patchwork` | Multi-panel figures | Active |
| `cowplot` | Publication themes, alignment | Active |

### Reproducibility

| Package/Tool | Purpose | Status |
|---------|---------|--------|
| `renv` | Package environment management | Active, standard |
| `targets` | Pipeline management | Active, successor to `drake` |
| Quarto | Manuscript authoring | Active, successor to Rmd |
| `rmarkdown` | Document generation | Active |
| `papaja` | APA manuscripts | Active |
| `PRISMA2020` | PRISMA flow diagrams | Active |
| `ggconsort` | CONSORT flow diagrams | Active |

---

## 7. Gaps and Areas Needing Caution

1. **`stargazer` maintenance**: No updates since 2022. Projects starting fresh should use `modelsummary`.

2. **`survminer` updates**: Package has been relatively static. Complex customization sometimes requires falling back to direct `ggplot2`.

3. **TRIPOD+AI (2024)**: Very new; R tooling for ML prediction model reporting is underdeveloped. Mostly manual checklist.

4. **PRISMA2020 vs PRISMAstatement**: The older `PRISMAstatement` package (PRISMA 2009) is still on CRAN but outdated. Use `PRISMA2020`.

5. **Incidence package**: The `incidence` package (original) has been superseded by `incidence2`. Code using `incidence` needs migration.

6. **Journal template coverage**: Quarto journal templates exist for major publishers but not all epidemiology-specific journals have official templates.

---

## Sources Consulted

- [gtsummary tbl_summary tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html)
- [gtsummary tbl_regression tutorial](https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html)
- [modelsummary documentation](https://modelsummary.com/)
- [survminer documentation](https://rpkgs.datanovia.com/survminer/)
- [ggdag documentation](https://r-causal.github.io/ggdag/)
- [CRAN Task View: Epidemiology](https://cran.r-project.org/web/views/Epidemiology.html)
- [The Epidemiologist R Handbook](https://epirhandbook.com/en/new_pages/epicurves.html)
- [forestploter introduction](https://cran.r-project.org/web/packages/forestploter/vignettes/forestploter-intro.html)
- [STROBE Statement (EQUATOR Network)](https://www.equator-network.org/reporting-guidelines/strobe/)
- [TRIPOD+AI Statement (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11019967/)
- [PRISMA 2020 Statement (EQUATOR Network)](https://www.equator-network.org/reporting-guidelines/prisma/)
- [Quarto article templates](https://quarto.org/docs/journals/templates.html)
- [targets for reproducible epidemiology](https://carpentries-incubator.github.io/targets-workshop/quarto.html)
- [renv for version control (PharmaSUG 2025)](https://pharmasug.org/proceedings/2025/SD/PharmaSUG-2025-SD-220.pdf)
- [ggplot2 for publications (GitHub)](https://github.com/CerrenRichards/ggplot2-for-publications)
- [patchwork documentation](https://patchwork.data-imaginist.com/)
- [cowplot documentation](https://wilkelab.org/cowplot/)
- [PRISMA2020 R package](https://onlinelibrary.wiley.com/doi/full/10.1002/cl2.1230)
- [Reproducible Summary Tables (gtsummary paper)](https://digitalcommons.unl.edu/cgi/viewcontent.cgi?article=1110&context=r-journal)
