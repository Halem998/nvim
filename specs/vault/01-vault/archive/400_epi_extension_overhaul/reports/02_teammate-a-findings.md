# Teammate A Findings: Epidemiology Study Types and R Code Patterns

**Artifact**: 02
**Focus**: Standard epidemiology study types and R implementations for publication
**Date**: 2026-04-10

---

## Table of Contents

1. [Observational Study Designs](#1-observational-study-designs)
   - [Cohort Studies](#11-cohort-studies)
   - [Case-Control Studies](#12-case-control-studies)
   - [Cross-Sectional Studies](#13-cross-sectional-studies)
   - [Ecological Studies](#14-ecological-studies)
2. [Interventional Studies](#2-interventional-studies)
   - [Randomized Controlled Trials](#21-randomized-controlled-trials)
   - [Quasi-Experimental Designs](#22-quasi-experimental-designs)
3. [Systematic Reviews and Meta-Analysis](#3-systematic-reviews-and-meta-analysis)
   - [Pairwise Meta-Analysis](#31-pairwise-meta-analysis)
   - [Network Meta-Analysis](#32-network-meta-analysis)
4. [Key Analysis Methods](#4-key-analysis-methods)
   - [Causal Inference and DAGs](#41-causal-inference-and-dags)
   - [Propensity Score Methods](#42-propensity-score-methods)
   - [Mediation Analysis](#43-mediation-analysis)
   - [Missing Data and Multiple Imputation](#44-missing-data-and-multiple-imputation)
   - [Bayesian Approaches](#45-bayesian-approaches)
   - [Time-to-Event Analysis](#46-time-to-event-analysis)
   - [Competing Risks](#47-competing-risks)
   - [Mixed Effects and Multilevel Models](#48-mixed-effects-and-multilevel-models)
   - [Survey Methods](#49-survey-methods)
5. [Data Management Patterns](#5-data-management-patterns)
6. [CRAN Task View Summary](#6-cran-task-view-summary)

---

## 1. Observational Study Designs

### 1.1 Cohort Studies

**Confidence: High** — Well-established methodology with extensive literature.

#### Overview
Cohort studies follow exposed and unexposed individuals forward (prospective) or reconstruct follow-up from records (retrospective) to compare incidence of outcomes over time. They are the gold standard for etiological research outside of RCTs.

#### Core Packages
| Package | Role |
|---------|------|
| `survival` | `Surv()`, `survfit()`, `coxph()`, `cox.zph()`, `tmerge()` |
| `survminer` | `ggsurvplot()`, `ggforest()`, `ggcoxzph()` for publication figures |
| `ggsurvfit` | Modern ggplot2-native survival plots |
| `tidycmprsk` | Competing risks extension |
| `broom` | Tidy model output: `tidy()`, `glance()`, `augment()` |
| `gtsummary` | Publication-ready Table 1 and regression tables |

#### Typical Analysis Pipeline

**1. Data preparation**
```r
library(tidyverse)
library(survival)
library(survminer)

cohort_data <- raw_data |>
  mutate(
    # Create event indicator (1=event, 0=censored)
    event = as.integer(outcome == "death"),
    # Follow-up time in days
    follow_up_days = as.numeric(date_exit - date_entry),
    # Recode exposure and covariates
    exposure = factor(exposure_var, levels = c("unexposed", "exposed")),
    age_cat  = cut(age, breaks = c(0, 40, 60, 80, Inf),
                   labels = c("<40", "40-59", "60-79", "80+"))
  ) |>
  # Exclude impossible records
  filter(follow_up_days > 0, !is.na(exposure))
```

**2. Kaplan-Meier estimation and visualization**
```r
# Fit KM curves by exposure group
km_fit <- survfit(Surv(follow_up_days, event) ~ exposure, data = cohort_data)

# Log-rank test
survdiff(Surv(follow_up_days, event) ~ exposure, data = cohort_data)

# Publication-quality figure
ggsurvplot(
  km_fit,
  data        = cohort_data,
  risk.table  = TRUE,
  pval        = TRUE,
  conf.int    = TRUE,
  xlab        = "Follow-up time (days)",
  ylab        = "Survival probability",
  legend.labs = c("Unexposed", "Exposed"),
  ggtheme     = theme_bw()
)
```

**3. Cox proportional hazards regression**
```r
# Univariable (unadjusted)
cox_crude <- coxph(Surv(follow_up_days, event) ~ exposure, data = cohort_data)

# Multivariable (adjusted)
cox_adj <- coxph(
  Surv(follow_up_days, event) ~ exposure + age + sex + comorbidity,
  data = cohort_data
)
summary(cox_adj)

# Tidy output with hazard ratios and CIs
broom::tidy(cox_adj, exponentiate = TRUE, conf.int = TRUE)
```

**4. Diagnostics**
```r
# Test proportional hazards assumption
ph_test <- cox.zph(cox_adj)
print(ph_test)          # Statistical test (p < 0.05 suggests violation)
ggcoxzph(ph_test)       # Schoenfeld residual plots

# Check for influential observations
ggcoxdiagnostics(cox_adj, type = "deviance")

# Forest plot of adjusted HRs
ggforest(cox_adj, data = cohort_data)
```

**5. Time-varying covariates**
```r
# Restructure data using tmerge() for time-varying exposures
td_data <- tmerge(
  data1 = cohort_data[, c("id", "follow_up_days", "event")],
  data2 = covariate_changes,
  id    = id,
  event = event(follow_up_days, event),
  tv_exposure = tdc(change_date, new_value)
)

cox_tv <- coxph(Surv(tstart, tstop, event) ~ tv_exposure + age + sex,
                data = td_data)
```

**6. Publication table**
```r
library(gtsummary)

# Table 1: characteristics
tbl_summary(
  cohort_data,
  by      = exposure,
  include = c(age, sex, comorbidity, follow_up_days)
) |>
  add_p() |>
  add_overall() |>
  bold_labels()

# Regression table
tbl_regression(cox_adj, exponentiate = TRUE) |>
  bold_p(t = 0.05)
```

#### Key Pitfalls
- **Immortal time bias**: Ensure entry time is correctly defined; exposure must not overlap with time before the "at-risk" window begins.
- **Informative censoring**: Censoring should be independent of outcome probability. Assess via sensitivity analysis.
- **Violation of PH assumption**: Use stratified Cox model (`strata()`), time-interaction terms, or AFT models when assumption fails.
- **Left truncation**: Use `Surv(entry_time, exit_time, event)` for delayed entry.

#### Publication Reporting
Report STROBE checklist items; provide: n at risk at key time points (risk tables), KM curves, HRs with 95% CIs from adjusted Cox model, heterogeneity subgroup analyses, and assumption diagnostics in supplement.

---

### 1.2 Case-Control Studies

**Confidence: High** — Mature methodology with established R tooling.

#### Overview
Case-control studies compare the exposure history of cases (with disease) to controls (without disease). Matched designs require conditional analysis. Measure of association: **odds ratio (OR)**.

#### Core Packages
| Package | Role |
|---------|------|
| `survival` | `clogit()` for conditional logistic regression |
| `MatchIt` | Matching cases to controls |
| `cobalt` | Balance assessment after matching |
| `epitools` | `oddsratio()`, contingency table analysis |
| `EpiStats` | Case-control association measures |
| `gtsummary` | Publication tables |

#### Typical Analysis Pipeline

**1. Unmatched case-control: unconditional logistic regression**
```r
# Standard logistic regression
lr_model <- glm(
  case_status ~ exposure + age + sex + smoking,
  data   = cc_data,
  family = binomial(link = "logit")
)

# Tidy ORs with CIs
broom::tidy(lr_model, exponentiate = TRUE, conf.int = TRUE)
```

**2. Matched case-control: conditional logistic regression**
```r
library(survival)

# Conditional logistic regression (strata = matched set ID)
clog_model <- clogit(
  case_status ~ exposure + age_diff + strata(match_id),
  data = matched_data
)
summary(clog_model)

# CRITICAL: Do NOT include matching variables as covariates --
# this causes severe bias (OR^2 direction).
# Matching variables are accounted for by strata().
```

**3. Creating a matched dataset with MatchIt**
```r
library(MatchIt)
library(cobalt)

# Nearest-neighbor 1:2 matching on propensity score
match_obj <- matchit(
  case_status ~ age + sex + comorbidity,
  data    = cc_data,
  method  = "nearest",
  ratio   = 2,
  caliper = 0.2
)

# Check balance
summary(match_obj)
love.plot(match_obj, thresholds = c(m = 0.1))

# Extract matched data
matched_data <- match.data(match_obj)
```

**4. Publication table with ORs**
```r
tbl_regression(clog_model, exponentiate = TRUE) |>
  add_n() |>
  bold_p()
```

#### Key Pitfalls
- **Over-matching**: Matching on too many variables or matching on intermediates on the causal pathway reduces efficiency.
- **Conditional vs. unconditional**: Always use `clogit()` for matched data; unconditional logistic regression is biased in matched designs.
- **Matching variables as covariates**: Including matched variables in the conditional model biases ORs (approximately OR²).

---

### 1.3 Cross-Sectional Studies

**Confidence: High** — Standard methodology for prevalence estimation.

#### Overview
Cross-sectional studies measure exposure and outcome simultaneously in a defined population at a single time point. Primary measure: **prevalence ratio (PR)** or **prevalence odds ratio (POR)**.

#### Core Packages
| Package | Role |
|---------|------|
| `survey` | `svydesign()`, `svymean()`, `svyglm()` for complex surveys |
| `srvyr` | Tidyverse-compatible survey analysis |
| `prevalence` | Direct prevalence estimation |
| `epitools` | Cross-tabulation and rate ratios |

#### Key Analysis Patterns

**Simple prevalence estimation**
```r
# Crude prevalence
prop.table(table(cross_data$outcome))

# With confidence intervals
binom.test(sum(cross_data$outcome), nrow(cross_data))
```

**Prevalence ratio via Poisson/log-binomial regression**
```r
# Poisson regression with robust SE (preferred for common outcomes)
poisson_mod <- glm(
  outcome ~ exposure + age + sex,
  data   = cross_data,
  family = poisson(link = "log")
)

# Sandwich robust SEs to correct for variance misspecification
library(sandwich)
library(lmtest)
coeftest(poisson_mod, vcov = sandwich)

# Exponentiate for prevalence ratios
exp(coef(poisson_mod))
exp(confint(poisson_mod))
```

**Survey-weighted cross-sectional analysis**
```r
library(survey)

# Define survey design (stratified cluster sample)
svy_design <- svydesign(
  ids     = ~cluster_id,
  strata  = ~stratum,
  weights = ~survey_weight,
  data    = cross_data
)

# Weighted prevalence
svymean(~outcome, svy_design, na.rm = TRUE)

# Weighted logistic regression
svy_logit <- svyglm(
  outcome ~ exposure + age + sex,
  design = svy_design,
  family = quasibinomial(link = "logit")
)
```

#### Reporting Considerations
- Report unweighted n alongside weighted estimates.
- Provide design effects (DEFF) to show impact of complex design.
- For common outcomes (prevalence > 10%), use PR not OR (less inflated).

---

### 1.4 Ecological Studies

**Confidence: Medium** — Methodology is sound; spatial methods are specialized.

#### Overview
Ecological studies analyze aggregate data (populations, not individuals). Common outcomes: rates, counts. Typical methods: Poisson regression for counts/rates, spatial regression for geographic data.

#### Core Packages
| Package | Role |
|---------|------|
| `MASS` | `glm.nb()` for negative binomial regression (overdispersion) |
| `spdep` | Spatial neighbors and weights, Moran's I |
| `spatialreg` | Spatial lag and error models |
| `sf` | Spatial data manipulation |
| `SpatialEpi` | Cluster detection and disease mapping |

#### Key Patterns

**Poisson regression for rates with offset**
```r
# Offset = log(population) converts counts to rates
poisson_ecol <- glm(
  case_count ~ deprivation_index + pollution_level + offset(log(population)),
  data   = ecological_data,
  family = poisson(link = "log")
)

# Test for overdispersion
dispersiontest(poisson_ecol)  # from AER package

# If overdispersed, use negative binomial
library(MASS)
nb_ecol <- glm.nb(
  case_count ~ deprivation_index + pollution_level + offset(log(population)),
  data = ecological_data
)
```

**Spatial autocorrelation assessment**
```r
library(spdep)
library(sf)

# Create neighbor objects from polygon geometries
neighbors <- poly2nb(spatial_data)
weights   <- nb2listw(neighbors, style = "W")

# Moran's I test on residuals
moran.test(residuals(poisson_ecol), weights)

# If spatial autocorrelation present, use spatial models via spatialreg
```

#### Key Pitfall
**Ecological fallacy**: Associations at the aggregate level do not necessarily hold at the individual level. Always clearly state the unit of analysis is populations, not individuals.

---

## 2. Interventional Studies

### 2.1 Randomized Controlled Trials

**Confidence: High** — ITT/PP distinction is a reporting standard.

#### Overview
RCTs randomize participants to intervention or control. Primary analyses follow **intention-to-treat (ITT)** principle (analyze as randomized, regardless of protocol adherence). **Per-protocol (PP)** analysis is a sensitivity analysis.

#### Core Packages
| Package | Role |
|---------|------|
| `gtsummary` | Table 1 (baseline characteristics), regression tables |
| `survival` | Time-to-event endpoints |
| `lme4` | Repeated measures outcomes |
| `mice` | Multiple imputation for missing post-randomization outcomes |
| `gsDesign` | Group sequential designs, interim analysis boundaries |
| `rpact` | Confirmatory adaptive designs |

#### Key Analysis Patterns

**ITT analysis: binary endpoint**
```r
# All randomized participants analyzed in assigned group
itt_model <- glm(
  outcome ~ treatment + stratification_var,
  data   = rct_data,  # includes ALL randomized participants
  family = binomial(link = "logit")
)
tbl_regression(itt_model, exponentiate = TRUE)
```

**Per-protocol analysis**
```r
# Only participants who completed protocol per pre-specified criteria
pp_data  <- rct_data |> filter(protocol_compliant == TRUE)
pp_model <- glm(
  outcome ~ treatment + stratification_var,
  data   = pp_data,
  family = binomial(link = "logit")
)
```

**Baseline characteristics table (Table 1)**
```r
tbl_summary(
  rct_data,
  by      = treatment,
  include = c(age, sex, baseline_severity, comorbidities)
) |>
  add_overall() |>
  # Note: p-values for Table 1 are controversial in RCTs (randomization
  # guarantees balance in expectation -- imbalances are chance)
  bold_labels()
```

**Time-to-event primary endpoint**
```r
# Adjusted Cox model (stratify by randomization strata)
cox_rct <- coxph(
  Surv(time_to_event, event_indicator) ~ treatment + strata(stratum),
  data = rct_data
)
tbl_regression(cox_rct, exponentiate = TRUE)
```

#### Reporting Standards
- Use CONSORT checklist and flow diagram.
- Report both ITT and PP analyses; note any divergence between them.
- Pre-register primary and secondary endpoints; mark post-hoc analyses clearly.
- Report effect modification/subgroup analyses with interaction p-values.

---

### 2.2 Quasi-Experimental Designs

**Confidence: Medium** — Methods are valid but assumptions require careful justification.

#### Overview
Used when randomization is infeasible. Leverage natural or policy-induced variation to approximate counterfactuals.

#### 2.2.1 Interrupted Time Series (ITS)

**Core Packages**: `nlme`, `lmtest`, `CausalImpact`, `itsa`

```r
library(nlme)

# Segment regression: model level and slope changes at intervention
# Time points coded: time = sequential count, intervention = 0/1,
# time_after = time since intervention (0 before, sequential after)
its_model <- gls(
  outcome ~ time + intervention + time_after,
  data         = ts_data,
  correlation  = corARMA(p = 1, q = 1),  # AR(1) for autocorrelation
  method       = "ML"
)
summary(its_model)

# Visualize with counterfactual projection
```

**Bayesian structural time series via CausalImpact**
```r
library(CausalImpact)

# pre_period: time range before intervention
# post_period: time range after intervention
impact <- CausalImpact(
  data       = zoo_data,  # zoo time series object
  pre.period  = c(1, intervention_point - 1),
  post.period = c(intervention_point, nrow(zoo_data))
)
plot(impact)
summary(impact)
```

#### 2.2.2 Difference-in-Differences (DiD)

```r
# DiD: requires parallel trends assumption
# outcome = alpha + beta1*time + beta2*treated + beta3*(time*treated) + e
did_model <- lm(
  outcome ~ time_post + treated + time_post:treated,
  data = panel_data
)

# With individual fixed effects (absorbs time-invariant confounders)
library(fixest)
did_fe <- feols(
  outcome ~ time_post:treated | unit_id + time_period,
  data = panel_data
)
```

#### Key Pitfall
Both ITS and DiD require strong untestable assumptions (no concurrent interventions for ITS; parallel trends for DiD). Always include sensitivity analyses testing assumption robustness.

---

## 3. Systematic Reviews and Meta-Analysis

### 3.1 Pairwise Meta-Analysis

**Confidence: High** — `metafor` and `meta` are the standard R tools.

#### Core Packages
| Package | Role |
|---------|------|
| `metafor` | Comprehensive: `rma()`, `rma.mv()`, heterogeneity, publication bias |
| `meta` | User-friendly, excellent forest plots, JAMA/RevMan5 layouts |
| `dmetar` | Companion to "Doing Meta-Analysis in R" textbook |

#### Typical Pipeline

**1. Effect size calculation**
```r
library(metafor)

# From 2x2 table data: log odds ratios
dat <- escalc(
  measure = "OR",  # "RR", "RD", "MD", "SMD", "COR" etc.
  ai = tpos, bi = tneg,  # treatment events/non-events
  ci = cpos, di = cneg,  # control events/non-events
  data = study_data,
  slab = study_label  # study labels for plots
)
```

**2. Fit random-effects model (DerSimonian-Laird)**
```r
res <- rma(yi, vi, data = dat, method = "REML")
print(res)

# Key outputs: estimate (pooled effect), tau^2 (between-study variance),
# I^2 (% heterogeneity), Q statistic and p-value
```

**3. Forest plot**
```r
# metafor approach
forest(res,
       slab         = dat$study_label,
       order        = "obs",   # order by effect size
       header       = TRUE,
       xlab         = "Log Odds Ratio",
       mlab         = "RE Model")

# meta package approach (JAMA-formatted)
library(meta)
m_gen <- metagen(
  TE   = yi,
  seTE = sqrt(vi),
  data = dat
)
forest(m_gen, layout = "JAMA")
```

**4. Heterogeneity assessment**
```r
# I^2 and tau^2 are in the rma() output
# I^2 interpretation: 0-25% low, 25-75% moderate, >75% high

# Prediction interval (more informative than CI for future studies)
predict(res)

# Subgroup analysis / meta-regression
res_subgrp <- rma(yi, vi, mods = ~ study_design, data = dat)
```

**5. Publication bias**
```r
# Funnel plot
funnel(res, main = "Funnel Plot")

# Egger's test (regression asymmetry test)
regtest(res, model = "lm")

# Rank correlation test (Begg's)
ranktest(res)

# Trim-and-fill method
res_tf <- trimfill(res)
forest(res_tf)
```

#### Publication Standards
- Report PRISMA checklist items.
- Provide: number of studies, total N, pooled estimate with 95% CI, I², Q p-value, prediction interval.
- Sensitivity analyses: leave-one-out, influence diagnostics (`influence(res)`).

---

### 3.2 Network Meta-Analysis

**Confidence: Medium** — Methodology is established; implementation requires expertise.

#### Core Packages
| Package | Role |
|---------|------|
| `netmeta` | Frequentist NMA via graph-theoretical approach |
| `gemtc` | Bayesian NMA via MCMC (requires JAGS) |
| `BUGSnet` | Bayesian NMA with PRISMA/NICE-DSU checklist outputs |

#### Basic netmeta Workflow
```r
library(netmeta)

# Pairwise data format: study, treatment1, treatment2, TE (effect), seTE
nma_result <- netmeta(
  TE    = log_or,
  seTE  = se_log_or,
  treat1 = treatment_a,
  treat2 = treatment_b,
  studlab = study_id,
  data    = pairwise_data,
  sm      = "OR",
  reference.group = "placebo"
)

# Network plot
netgraph(nma_result)

# League table of all pairwise comparisons
netleague(nma_result)

# Inconsistency assessment
netheat(nma_result)
```

---

## 4. Key Analysis Methods

### 4.1 Causal Inference and DAGs

**Confidence: High** — `dagitty` + `ggdag` are the standard tools.

#### Core Packages
| Package | Role |
|---------|------|
| `dagitty` | DAG specification, minimal adjustment sets, testable implications |
| `ggdag` | `ggplot2`-based DAG visualization |

#### DAG Workflow
```r
library(dagitty)
library(ggdag)

# Define DAG
dag <- dagify(
  outcome   ~ exposure + confounder + mediator,
  exposure  ~ confounder + instrument,
  mediator  ~ exposure,
  labels    = list(
    outcome   = "Outcome Y",
    exposure  = "Exposure X",
    confounder = "Confounder C"
  ),
  exposure = "exposure",
  outcome  = "outcome"
)

# Find minimal adjustment set to identify causal effect
adjustmentSets(dag, effect = "total")  # -> {confounder}
adjustmentSets(dag, effect = "direct") # for NDE/NIE

# Identify instrumental variables
instrumentalVariables(dag, exposure = "exposure", outcome = "outcome")

# Visualize
ggdag(dag, text = FALSE, use_labels = "label") +
  theme_dag()

# Highlight adjustment sets
ggdag_adjustment_set(dag) + theme_dag()
```

#### Key Concepts for Publication
- DAGs encode qualitative causal assumptions; present alongside analysis.
- Report which variables were included in adjustment set and why (per DAG logic, not statistical criteria like stepwise).
- Collider bias: adjusting for a common effect of exposure and outcome opens a spurious path.

---

### 4.2 Propensity Score Methods

**Confidence: High** — `MatchIt`/`WeightIt`/`cobalt` are standard tools.

#### Core Packages
| Package | Role |
|---------|------|
| `MatchIt` | Propensity score matching (1:1, 1:N, optimal, genetic) |
| `WeightIt` | IPW, entropy balancing, CBPS, DR estimators |
| `cobalt` | Balance tables and love plots |
| `propensity` | Convenience functions for ATE/ATT/ATC weights |
| `halfmoon` | Mirrored histograms for overlap visualization |

#### Matching Workflow
```r
library(MatchIt)
library(cobalt)

# Step 1: Fit matching model
match_obj <- matchit(
  treatment ~ age + sex + bmi + smoking + comorbidity_score,
  data    = study_data,
  method  = "nearest",  # or "optimal", "genetic", "full"
  distance = "glm",     # propensity score via logistic regression
  ratio   = 1,
  caliper = 0.2,
  replace = FALSE
)

# Step 2: Assess balance
summary(match_obj, un = TRUE)  # compare pre/post balance
love.plot(match_obj,
          thresholds  = c(m = 0.1),  # SMD < 0.1 target
          var.order   = "unadjusted",
          abs         = TRUE)

# Step 3: Extract matched data
matched_data <- match.data(match_obj)

# Step 4: Outcome analysis (account for matched structure)
# For continuous outcome:
lm_matched <- lm(outcome ~ treatment, data = matched_data,
                  weights = weights)
# Use cluster-robust SE on matched pairs
library(sandwich); library(lmtest)
coeftest(lm_matched, vcov = vcovCL, cluster = ~subclass)
```

#### Weighting Workflow (IPTW)
```r
library(WeightIt)

# ATE weights via CBPS (Covariate Balancing Propensity Score)
wt_obj <- weightit(
  treatment ~ age + sex + bmi + smoking,
  data   = study_data,
  method = "cbps",       # or "ps", "ebal", "dr"
  estimand = "ATE"       # or "ATT", "ATC"
)

# Assess balance
cobalt::love.plot(wt_obj, thresholds = c(m = 0.1))

# Outcome model with stabilized weights
study_data$ipw <- wt_obj$weights

# Marginal structural model
msm_model <- glm(
  outcome ~ treatment,
  data    = study_data,
  weights = ipw,
  family  = binomial()
)
# Sandwich SE required because weights introduce correlation
coeftest(msm_model, vcov = sandwich)
```

---

### 4.3 Mediation Analysis

**Confidence: High** — `CMAverse` is the current standard for causal mediation.

#### Core Packages
| Package | Role |
|---------|------|
| `CMAverse` | `cmdag()`, `cmest()`, `cmsens()` — full causal mediation suite |
| `mediation` | Parametric/nonparametric causal mediation |

#### CMAverse Workflow
```r
library(CMAverse)

# Step 1: Visualize DAG with mediator
cmdag(
  outcome   = "Y",
  exposure  = "A",
  mediator  = "M",
  emi       = TRUE  # exposure-mediator interaction
)

# Step 2: Causal mediation estimation
# Regression-based approach (VanderWeele/Valeri 2013)
result <- cmest(
  data      = study_data,
  model     = "rb",       # regression-based
  outcome   = "Y",
  exposure  = "A",
  mediator  = "M",
  basec     = c("C1", "C2"),    # baseline confounders
  EMint     = TRUE,              # allow exposure-mediator interaction
  mreg      = list("logistic"),  # mediator regression type
  yreg      = "logistic",        # outcome regression type
  astar     = 0,                 # reference exposure level
  a         = 1,                 # comparison exposure level
  mval      = list(1),           # mediator reference value
  estimation = "imputation",
  inference  = "bootstrap",
  nboot      = 200
)
summary(result)

# Decomposed effects: NDE, NIE, TE, PM (proportion mediated)

# Step 3: Sensitivity analysis for unmeasured confounding
cmsens(object = result, sens = "uc")  # E-value approach
```

---

### 4.4 Missing Data and Multiple Imputation

**Confidence: High** — `mice` is the gold standard; workflow is well-established.

#### Missing Data Mechanisms
| Mechanism | Definition | Implication |
|-----------|------------|-------------|
| **MCAR** | Missingness independent of observed and unobserved data | Complete case analysis unbiased (but less efficient) |
| **MAR** | Missingness depends on observed data only | Multiple imputation (MI) valid |
| **MNAR** | Missingness depends on unobserved data | MI biased; requires sensitivity analysis |

*In practice, MCAR is rarely defensible; MAR is the standard working assumption for MI.*

#### Core Packages
| Package | Role |
|---------|------|
| `mice` | Primary MI: `mice()`, `with()`, `pool()` |
| `VIM` | Missing data visualization: `aggr()`, `matrixplot()` |
| `naniar` | Tidy missing data exploration |
| `Amelia2` | Bootstrap-based MI (time series and cross-sectional) |

#### mice Workflow
```r
library(mice)
library(VIM)

# Step 1: Explore missingness patterns
md.pattern(study_data)
aggr(study_data, numbers = TRUE, prop = FALSE)

# Assess MAR: is missingness predicted by observed variables?
# Test: logistic regression of missingness indicator on other variables
study_data |>
  mutate(missing_outcome = is.na(outcome)) |>
  glm(missing_outcome ~ age + sex + exposure, data = _, family = binomial()) |>
  broom::tidy()

# Step 2: Impute (m=20 imputations; more is better for high missingness)
imp <- mice(
  study_data,
  m       = 20,
  method  = "pmm",   # predictive mean matching (continuous)
  # method = "logreg" for binary, "polyreg" for nominal
  seed    = 42,
  printFlag = FALSE
)

# Inspect imputed values
densityplot(imp, ~outcome)   # imputed vs. observed distributions

# Step 3: Analyze each imputed dataset
analyses <- with(imp, lm(outcome ~ exposure + age + sex))

# Step 4: Pool results (Rubin's rules)
pooled <- pool(analyses)
summary(pooled, conf.int = TRUE, exponentiate = FALSE)

# Step 5: Sensitivity analysis for MNAR
# Fit pattern-mixture model or use tipping point analysis
```

#### Key Pitfalls
- **Imputation model must include all analysis variables** (outcome, exposure, all covariates, and auxiliary variables correlated with missingness).
- **Do not impute after transformations**: impute on the raw scale, transform afterward.
- **m = 5 is usually insufficient**: use m ≥ 20 for ≥ 10% missing data.

---

### 4.5 Bayesian Approaches

**Confidence: Medium-High** — `brms` is increasingly standard; Stan knowledge needed for complex models.

#### Core Packages
| Package | Role |
|---------|------|
| `brms` | Full Bayesian multilevel models via Stan; formula-based interface |
| `rstanarm` | Pre-compiled Stan models; faster for standard models |
| `bayesplot` | `mcmc_trace()`, `pp_check()`, posterior visualization |
| `tidybayes` | Tidy extraction of posterior draws |
| `posterior` | Posterior summaries (ESS, Rhat, HDI) |

#### brms Workflow
```r
library(brms)
library(bayesplot)
library(tidybayes)

# Step 1: Specify and fit model
# brms uses lme4-style formula syntax
bayes_model <- brm(
  formula  = outcome | trials(N) ~ exposure + age + sex + (1 | site),
  data     = study_data,
  family   = binomial(link = "logit"),
  prior    = c(
    prior(normal(0, 1.5), class = "b"),          # weakly informative for log-ORs
    prior(normal(0, 1),   class = "Intercept"),
    prior(exponential(1), class = "sd")           # half-normal for random effects SD
  ),
  chains   = 4,
  iter     = 4000,
  warmup   = 2000,
  cores    = 4,
  seed     = 42
)

# Step 2: Convergence diagnostics
# Rhat should be < 1.01; ESS > 400 for all parameters
print(bayes_model)
mcmc_trace(as.array(bayes_model), pars = c("b_exposure"))

# Step 3: Posterior predictive checks
pp_check(bayes_model, ndraws = 100)

# Step 4: Extract and summarize posterior
posterior_summary(bayes_model, pars = "b_")
# OR with tidybayes:
bayes_model |>
  gather_draws(b_exposure) |>
  median_hdi(.width = 0.95)

# Step 5: Hypothesis testing (probability of direction)
hypothesis(bayes_model, "b_exposure > 0")

# Step 6: Predictions / marginal effects
conditional_effects(bayes_model, effects = "exposure")
```

#### Prior Specification Guidance
- **Default weakly informative**: `normal(0, 1)` to `normal(0, 2.5)` for log-odds scale covariates.
- **Informative**: Based on prior studies; document sources in methods.
- **Prior sensitivity**: Refit with broader/narrower priors; report if conclusions change.

---

### 4.6 Time-to-Event Analysis

**Confidence: High** — See Section 1.1 for comprehensive Cox PH coverage.

#### Additional Methods

**Accelerated Failure Time (AFT) models**
```r
library(survival)
# AFT models time ratio rather than hazard ratio
aft_model <- survreg(
  Surv(time, event) ~ exposure + age + sex,
  data = surv_data,
  dist = "weibull"   # or "lognormal", "loglogistic", "exponential"
)
```

**Restricted Mean Survival Time (RMST)**
```r
library(survRM2)
# RMST: area under survival curve up to time tau
# Preferable when PH assumption is violated
rmst2(
  time    = surv_data$time,
  status  = surv_data$event,
  arm     = surv_data$treatment,
  tau     = 5 * 365  # restrict to 5 years
)
```

---

### 4.7 Competing Risks

**Confidence: High** — `tidycmprsk` wraps `cmprsk` with tidy interface.

#### Core Packages
| Package | Role |
|---------|------|
| `tidycmprsk` | Tidy `cuminc()` and `crr()` (Fine-Gray) |
| `cmprsk` | Underlying engine for CIF and Fine-Gray regression |
| `survival` | `survfit()` with `type = "mstate"` for cause-specific hazards |
| `ggsurvfit` | `ggcuminc()` for cumulative incidence plots |

#### Workflow
```r
library(tidycmprsk)
library(ggsurvfit)

# The outcome variable must be a factor:
#   Level 0 = censored, Level 1 = event of interest, Level 2+ = competing events
trial_data <- trial_data |>
  mutate(death_cr = factor(death_cr, levels = c(0, 1, 2),
                            labels = c("censored", "cancer", "other")))

# Step 1: Cumulative incidence function (Aalen-Johansen estimator)
cuminc_fit <- cuminc(Surv(ttdeath, death_cr) ~ trt, trial_data)
print(cuminc_fit)

# Step 2: Plot cumulative incidence curves
ggcuminc(cuminc_fit, outcome = "cancer") +
  add_risktable() +
  labs(x = "Time (months)")

# Step 3: Fine-Gray regression (models subdistribution hazard)
fg_model <- crr(Surv(ttdeath, death_cr) ~ age + trt, trial_data)
tbl_regression(fg_model, exponentiate = TRUE)

# Step 4: Cause-specific hazard model (alternative framing)
# Treats competing events as censored
cs_model <- coxph(
  Surv(ttdeath, death_cr == "cancer") ~ age + trt,
  data = trial_data
)
```

#### Fine-Gray vs. Cause-Specific Hazard
- **Fine-Gray (SHR)**: Models effect on cumulative incidence directly; appropriate for public health / prognostic questions.
- **Cause-specific hazard**: Models the biological mechanism; preferred for etiological questions.
- Always report and compare both; they can yield different conclusions.

---

### 4.8 Mixed Effects and Multilevel Models

**Confidence: High** — `lme4` is the standard; cluster-robust SE is well-supported.

#### Core Packages
| Package | Role |
|---------|------|
| `lme4` | `lmer()`, `glmer()` — linear and generalized LMMs |
| `nlme` | `lme()` — allows heterogeneous variances, more flexible correlation structures |
| `clubSandwich` | Cluster-robust SEs for `lme4` objects |
| `lmerTest` | Satterthwaite df and p-values for `lmer()` |

#### Workflow
```r
library(lme4)
library(lmerTest)
library(clubSandwich)

# Random intercept model (patients nested in hospitals)
lmm_ri <- lmer(
  outcome ~ exposure + age + sex + (1 | hospital_id),
  data = multilevel_data
)
summary(lmm_ri)

# Random slope model (exposure effect varies by hospital)
lmm_rs <- lmer(
  outcome ~ exposure + age + (1 + exposure | hospital_id),
  data = multilevel_data
)

# ICC (intraclass correlation coefficient)
performance::icc(lmm_ri)

# Cluster-robust SEs (conservative; useful when random effects structure uncertain)
coef_test(lmm_ri, vcov = "CR1S", cluster = multilevel_data$hospital_id)

# Generalized LMM for binary outcome
glmm_model <- glmer(
  binary_outcome ~ exposure + age + (1 | cluster_id),
  data   = cluster_data,
  family = binomial(link = "logit")
)
```

#### Reporting
Report: fixed effects with 95% CIs, random effects variance components, ICC, number of clusters and observations per cluster.

---

### 4.9 Survey Methods

**Confidence: High** — `survey`/`srvyr` are the standard; `srvyr` recommended for tidyverse workflows.

#### Core Packages
| Package | Role |
|---------|------|
| `survey` | `svydesign()`, `svymean()`, `svyglm()`, `svyciprop()` |
| `srvyr` | Tidyverse wrapper: `as_survey_design()`, `survey_mean()` |
| `gtsummary` | Weighted Table 1 via `tbl_svysummary()` |

#### Workflow
```r
library(survey)
library(srvyr)

# Step 1: Define complex survey design
svy <- svydesign(
  ids     = ~psu_id,      # primary sampling unit
  strata  = ~stratum,
  weights = ~sample_weight,
  nest    = TRUE,
  data    = survey_data
)

# OR: srvyr tidyverse style
svy_tidy <- survey_data |>
  as_survey_design(
    ids     = psu_id,
    strata  = stratum,
    weights = sample_weight
  )

# Step 2: Weighted estimates
# Prevalence with 95% CI
svymean(~outcome, svy, na.rm = TRUE)
svyciprop(~I(outcome == 1), svy)

# Subgroup analysis
svyby(~outcome, ~exposure, svy, svymean)

# Step 3: Weighted regression
svy_logit <- svyglm(
  outcome ~ exposure + age + sex,
  design = svy,
  family = quasibinomial()
)
summary(svy_logit)

# Step 4: Publication-ready weighted table
tbl_svysummary(
  svy,
  by      = exposure,
  include = c(age, sex, outcome)
) |>
  add_p() |>
  bold_labels()
```

---

## 5. Data Management Patterns

**Confidence: High** — Tidy data principles are universal; epi-specific tools are maturing.

### 5.1 Tidy Data for Epidemiology

```r
library(tidyverse)

# One row per observation-time unit (for longitudinal data)
# Variable types: exposure, outcome, covariate, administrative

# Standard column naming convention
# - snake_case for all variable names
# - _date suffix for date variables: enrollment_date, outcome_date
# - _flag suffix for binary indicators: dead_flag, lost_flag
# - _cat suffix for categorized versions: age_cat, bmi_cat
```

### 5.2 Date/Time Handling for Follow-Up Data

```r
library(lubridate)

# Parse dates robustly
cohort_data <- cohort_data |>
  mutate(
    enrollment_date = ymd(enrollment_date),
    outcome_date    = ymd(outcome_date),
    # Follow-up time
    follow_up_years = as.numeric(
      difftime(outcome_date, enrollment_date, units = "days")
    ) / 365.25,
    # Administrative censoring at study end
    event_date = pmin(outcome_date, study_end_date, na.rm = TRUE),
    event      = as.integer(!is.na(outcome_date) & outcome_date <= study_end_date)
  )
```

### 5.3 Variable Coding Conventions

```r
# Exposure: clearly define reference category
cohort_data <- cohort_data |>
  mutate(
    exposure = factor(exposure_raw,
                      levels = c("unexposed", "low", "high"),
                      labels = c("Unexposed", "Low exposure", "High exposure"))
  )
# Always set reference level explicitly:
cohort_data$exposure <- relevel(cohort_data$exposure, ref = "Unexposed")

# Outcome: binary indicator (1=event, 0=censored or no event)
cohort_data <- cohort_data |>
  mutate(dead = as.integer(vital_status == "deceased"))

# Confounders: check for collinearity before inclusion
cor(cohort_data[, c("age", "bmi", "comorbidity_score")], use = "pairwise")
```

### 5.4 Data Validation

```r
library(linelist)

# linelist package: tag epidemiological variables with validation
ll <- make_linelist(
  raw_data,
  date_onset    = "symptom_start",
  date_outcome  = "discharge_date",
  outcome       = "patient_outcome",
  age           = "patient_age",
  sex           = "patient_sex"
)
# validate() checks types and range constraints
validate_linelist(ll)

# naniar for missingness overview
library(naniar)
vis_miss(study_data)
miss_var_summary(study_data)
```

---

## 6. CRAN Task View Summary

The CRAN Task View: Epidemiology (updated March 2025) organizes packages into:

| Category | Key Packages |
|----------|-------------|
| **Data cleaning/management** | `cleanepi`, `linelist`, `dataquieR`, `AMR`, `diyar` |
| **Survival/time-to-event** | `survival`, `survminer`, `ggsurvfit`, `cmprsk`, `tidycmprsk` |
| **Causal inference** | `dagitty`, `ggdag`, `MatchIt`, `WeightIt`, `cobalt`, `CMAverse` |
| **Missing data** | `mice`, `VIM`, `naniar`, `Amelia2` |
| **Bayesian** | `brms`, `rstanarm`, `bayesplot`, `tidybayes` |
| **Survey analysis** | `survey`, `srvyr`, `gtsummary` |
| **Meta-analysis** | `metafor`, `meta`, `netmeta`, `gemtc` |
| **Mixed models** | `lme4`, `nlme`, `clubSandwich`, `lmerTest` |
| **Publication tables** | `gtsummary`, `gt`, `flextable`, `kableExtra` |
| **Visualization** | `ggplot2`, `survminer`, `ggdag`, `forestplot` |
| **Infectious disease** | `EpiEstim`, `EpiNow2`, `EpiModel`, `surveillance` |
| **Spatial epi** | `spdep`, `spatialreg`, `sf`, `SpatialEpi` |
| **Sensitivity analysis** | `episensr`, `EValue` |

---

## Summary: Study Type to R Package Mapping

| Study Type | Primary Packages | Key Functions |
|------------|-----------------|---------------|
| Cohort (survival) | `survival`, `survminer` | `coxph()`, `survfit()`, `ggsurvplot()` |
| Case-control | `survival`, `MatchIt` | `clogit()`, `matchit()` |
| Cross-sectional | `survey`, `srvyr` | `svyglm()`, `svymean()` |
| Ecological | `MASS`, `spdep` | `glm.nb()`, `moran.test()` |
| RCT | `gtsummary`, `survival` | `tbl_summary()`, `coxph()` |
| ITS | `nlme`, `CausalImpact` | `gls()`, `CausalImpact()` |
| DiD | `fixest` | `feols()` |
| Meta-analysis | `metafor`, `meta` | `rma()`, `forest()` |
| Network MA | `netmeta`, `gemtc` | `netmeta()`, `netgraph()` |
| Causal inference | `dagitty`, `MatchIt`, `WeightIt` | `adjustmentSets()`, `matchit()`, `weightit()` |
| Mediation | `CMAverse` | `cmest()`, `cmsens()` |
| Missing data | `mice` | `mice()`, `with()`, `pool()` |
| Bayesian | `brms`, `rstanarm` | `brm()`, `pp_check()` |
| Competing risks | `tidycmprsk` | `cuminc()`, `crr()` |
| Mixed models | `lme4` | `lmer()`, `glmer()` |
| Survey | `survey`, `srvyr` | `svydesign()`, `svyglm()` |

---

*Sources consulted: CRAN Task View: Epidemiology (2025), The Epidemiologist R Handbook, Doing Meta-Analysis in R, r-causal.org, PMC methodological papers, and package documentation for survival, metafor, mice, brms, MatchIt, WeightIt, cobalt, CMAverse, tidycmprsk, srvyr, CausalImpact.*
