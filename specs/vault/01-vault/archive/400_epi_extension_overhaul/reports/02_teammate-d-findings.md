# Teammate D Findings: Strategic Horizons
## Task 400 — Epidemiology Extension Overhaul

**Role**: Horizons researcher — long-range strategic analysis
**Date**: 2026-04-10
**Artifact**: 02 (parallel with teammates A, B, C)

---

## Executive Summary

This report answers three strategic questions about the epidemiology extension:

1. **What directory architecture should the context files use?** — Hybrid: lifecycle phases at top level, methods as domain/, study types surfaced via templates. This maps cleanly onto the `load_when` system and mirrors how The Epidemiologist R Handbook organizes its own 40+ chapters.

2. **Which template and context files provide the most leverage per line?** — Reporting checklists (STROBE/CONSORT/PRISMA), the analysis-phases pattern, and the study-design domain file are the three highest-ROI additions because they resolve agent ambiguity at the earliest decision points in every study.

3. **What should the extension explicitly NOT try to do?** — Do not build Quarto rendering pipelines, PubMed search automation, or a general R-language extension inside this epidemiology extension. The scope boundary is: study design through findings report, in R, for a single study. Everything else is a separate extension or a future task.

---

## Section A: External Resources Survey

### The Epidemiologist R Handbook (epirhandbook.com)

**Structure**: 40+ chapters organized into five macro-sections: Basics → Data Management → Analysis → Data Visualization → Reports and Dashboards.

**Key observations for extension design**:
- The handbook is task-centered, not method-centered. Each chapter answers "how do I do X" rather than "what is method Y." This is the right model for agent context files — agents need decision trees, not textbook expositions.
- The Analysis section's organization is directly applicable: Descriptive tables → Simple statistical tests → Regression → Missing data → Standardized rates → Time series → Epidemic modeling → Survival analysis → GIS. This is the natural sequence of a study analysis, not an alphabetical list.
- The handbook's missing data chapter covers MCAR/MAR/MNAR with practical R code. The current epidemiology extension has zero coverage of this — a significant gap since missing data decisions affect every analysis.
- The handbook treats epidemic curves, Kaplan-Meier curves, and forest plots as first-class visualization objects with their own chapters. The extension's current `tools/r-packages.md` lists `survminer` but provides no guidance on when to use which visualization.
- Reports/dashboards section covers R Markdown and Shiny. For the extension's scope (findings report as `.md` output), this can be deferred, but an `rmarkdown` integration note in the findings template would help.

**Relationship to the extension**: The handbook is reference material for the user; the extension's context files should be decision-support material for the agent. The agent already has access to WebSearch and can retrieve handbook pages; the extension need not duplicate handbook content — it should distill the decision logic that the handbook spreads across 40 chapters.

**Confidence**: High — the handbook's structure directly informs the recommended analysis-phases pattern file.

### R4Epi (r4epi.com)

**Structure**: University of Texas Health Science Center course textbook. Task-oriented teaching of R for epidemiology students. Covers R fundamentals, data management, linear regression, logistic regression, introduction to epidemiology concepts.

**Key observations**:
- R4Epi teaches the _why_ behind epidemiology concepts alongside R code. Its approach is more pedagogical than the Epi R Handbook's reference style.
- Logistic regression, linear regression, and the epidemiology introduction chapter are the main substantive contributions relevant to the extension.
- R4Epi does not cover survival analysis, spatial epidemiology, or Bayesian methods — it is introductory. The extension should not use R4Epi as a content model for its context files; the Epi R Handbook is more appropriate for the range of methods an agent will encounter.

**Confidence**: Medium — useful teaching framing but not the primary structural model.

### CRAN Task View: Epidemiology

**Organization**: Five categories — Data cleaning/management, Data visualization, Infectious disease modeling, Environmental epidemiology, Helper tools/data packages. Cross-references Spatial and Survival task views.

**Packages the current extension context is missing**:

| Package | Domain | Current coverage |
|---------|--------|-----------------|
| `cleanepi` | Epidemiological data cleaning | None |
| `linelist` | Case linelist class | None |
| `epiR` | Sample size, contingency tables, standardization | None |
| `epitools` | Elementary epi analysis | None |
| `powerSurvEpi` | Survival study power calculations | None |
| `outbreaker2` | Bayesian outbreak reconstruction | None |
| `surveillance` | Aberration detection, spatio-temporal | None |
| `episensr` | Sensitivity analysis for unmeasured confounding | None |
| `brms` | Bayesian multilevel models via Stan | None (only `rstan`/`cmdstanr`) |
| `tmle` | Targeted maximum likelihood estimation | None |
| `grf` | Causal forests (generalized random forests) | None |

**Notable**: The CRAN task view's scope is infectious disease epidemiology — it explicitly excludes clinical epidemiology and environmental epidemiology. The extension spans both. `r-packages.md` should be expanded to cover clinical/observational epi packages that are outside the CRAN task view's scope.

**Confidence**: High for package inventory.

### Emerging Trends (web research synthesis)

**1. Target trial emulation**
Hernán and colleagues' framework for designing observational studies to emulate RCTs has become the dominant paradigm for causal inference from EHR data (Annals of Internal Medicine 2025). The framework has a 7-component protocol (eligibility, treatment strategies, assignment, follow-up, outcomes, causal contrast, statistical analysis). The extension should reference this framework in `domain/study-designs.md` under a "causal observational studies" entry. No dedicated R package yet; analyses use `survival`, `MatchIt`, `WeightIt`, and custom code.

**2. Bayesian workflow**
The `brms` package (Bayesian regression via Stan) has matured to be the standard interface for applied Bayesian epidemiology, with explicit prior specification, `loo` cross-validation for model comparison, and posterior predictive checks. The current extension only lists `rstan`/`cmdstanr`. Adding `brms` to `r-packages.md` with a note on when to prefer it over direct Stan is a high-value, low-effort addition.

**3. ML for causal inference**
TMLE (`tmle` package), doubly-robust estimators, and causal forests (`grf` package) are standard tools in modern epidemiology for average treatment effect estimation with high-dimensional confounders. These are distinct from prediction ML and require different agent guidance. The extension should note these in a "causal inference" subsection of `domain/study-designs.md` rather than treating them as generic ML.

**4. Reproducibility infrastructure**
`renv` (package version locking) + `targets` (pipeline orchestration) is the 2025 standard for reproducible R epidemiology. `renv` is now analogous to Python's `pyproject.toml` / `uv.lock`. The extension's `domain/r-workflow.md` should document both as standard boilerplate for any new study project.

**5. Real-world evidence (RWE) from EHR**
Active 2025 development area. The `TrialEmulation` package (2024) and associated workflows bridge EHR data → target trial emulation → causal effect estimation. Worth a brief mention in `domain/study-designs.md` as emerging infrastructure rather than stable guidance.

---

## Section B: Context File Architecture Options

Four architectural options were evaluated against four criteria: agent context discovery, knowledge growth trajectory, `load_when` system mapping, and maintenance burden.

### Option 1: By Study Phase
```
context/project/epidemiology/
├── design/         # study design, protocol, IRB, power
├── data/           # acquisition, cleaning, management
├── analysis/       # EDA, modeling, sensitivity
├── reporting/      # tables, figures, report assembly
└── dissemination/  # manuscript, response to reviewers
```

**Strengths**: Maps directly onto how agents and users think about study progress. Phase-based loading is natural for the `load_when` system — the agent loads design context during research phase, analysis context during implementation. Mirrors the EpiR Handbook's Analysis → Visualization → Reports flow.

**Weaknesses**: A "survival analysis" context file doesn't fit cleanly into one phase — it spans design (sample size), analysis (model fitting), and reporting (Kaplan-Meier). Forces artificial splits.

**load_when mapping**: Excellent. Phase context maps directly to task status (research → load design/data, implement → load analysis/reporting).

**Growth trajectory**: New content has a clear home (except method-spanning topics). Mild duplication risk for packages used across phases.

**Maintenance burden**: Low — phase boundaries are stable.

### Option 2: By Study Type
```
context/project/epidemiology/
├── cohort/
├── case-control/
├── rct/
├── meta-analysis/
├── surveillance/
└── modeling/
```

**Strengths**: Clean compound key alignment — `epi:cohort` loads `cohort/`, `epi:case-control` loads `case-control/`.

**Weaknesses**: Forces duplication. Regression analysis guidance for cohort and case-control studies is nearly identical. With a single `epi:study` task type (per team synthesis), study-type subdirectories cannot be loaded selectively — all would load or none.

**load_when mapping**: Good if compound keys are study-type-specific, but team synthesis chose a single `epi:study` type for now. This architecture is premature.

**Growth trajectory**: Each subdirectory grows independently but with duplication.

**Maintenance burden**: High — regression guide updated in `cohort/` must also be updated in `case-control/`.

### Option 3: By Analysis Domain
```
context/project/epidemiology/
├── survival/
├── regression/
├── causal/
├── spatial/
├── temporal/
└── bayesian/
```

**Strengths**: No duplication across study types. Survival analysis guidance lives in one place.

**Weaknesses**: Loses the workflow narrative — an agent designing a cohort study doesn't think in "what domain am I in?" but "what phase am I in?" Context discovery requires more complex query patterns. Domain boundaries are fuzzy (causal inference vs. regression vs. Bayesian all overlap).

**load_when mapping**: Requires keyword-based loading which is less reliable than command/agent triggers.

**Growth trajectory**: Good for method depth, poor for workflow coherence.

**Maintenance burden**: Medium — clear method boundaries but no natural workflow entry point.

### Option 4: Hybrid (Recommended)
```
context/project/epidemiology/
├── README.md               # domain overview (existing, expand)
├── domain/                 # workflow-phase knowledge
│   ├── study-designs.md    # all design types with decision logic
│   ├── r-workflow.md       # renv, targets, project structure
│   ├── data-management.md  # cleaning, codebooks, missing data
│   └── reporting-standards.md  # STROBE/CONSORT/PRISMA overview
├── patterns/               # recurring analysis patterns
│   ├── statistical-modeling.md  # existing, expand
│   ├── analysis-phases.md       # EDA → primary → sensitivity → reporting
│   ├── strobe-checklist.md      # 22 STROBE items (reference)
│   └── epi-scoping-questions.md # /epi Stage 0 Q&A documentation
├── templates/              # fill-in artifacts
│   ├── study-protocol.md
│   ├── analysis-plan.md
│   └── findings-report.md
└── tools/                  # package and tooling reference
    ├── r-packages.md        # existing, expand
    └── mcp-guide.md         # existing
```

**Strengths**: Phase-based `domain/` gives workflow coherence. `patterns/` holds recurring templates-as-logic (checklists, question banks). `templates/` holds fill-in documents. `tools/` is a pure reference layer. No duplication. Study-type variation lives within `domain/study-designs.md` as sections, not as separate directories — appropriate when there is one `epi:study` task type.

**load_when mapping**: Excellent and precise.
- `/epi` command trigger → load all four `domain/` files + `README.md` (always needed for scoping)
- `epi-research-agent` → load `domain/`, `patterns/analysis-phases.md`, `patterns/statistical-modeling.md`
- `epi-implement-agent` → load `domain/data-management.md`, `patterns/analysis-phases.md`, `templates/findings-report.md`
- `epi:study` task type → load `domain/reporting-standards.md`, `patterns/strobe-checklist.md`

**Growth trajectory**: New study types → sections in `study-designs.md`. New methods → sections in `statistical-modeling.md` or new `patterns/` file. New templates → `templates/`. New packages → `tools/r-packages.md`. Clear home for everything.

**Maintenance burden**: Low. The `domain/` / `patterns/` / `templates/` / `tools/` split is stable and meaningful.

**Confidence**: High — this is the recommended architecture.

---

## Section C: Template Library (Value Analysis)

Ranked by value-per-effort ratio (high value = resolves major agent ambiguity; low effort = < 150 lines of content):

### Tier 1: Non-Negotiable (high value, low effort)

**1. `patterns/analysis-phases.md`** (estimated 80–100 lines)
Documents the standard EDA → primary analysis → sensitivity analyses → subgroup analyses → reporting sequence, with decision points at each transition. Agents currently have no structured guide for what order to do things in. This resolves the most common agent failure mode in statistical work: jumping to modeling before understanding the data.
*Confidence: High*

**2. `patterns/strobe-checklist.md`** (estimated 60–80 lines)
The 22 STROBE items as a reference checklist, annotated with R implementation notes (e.g., "Item 13 — Address missing data: see mice package"). Zero-risk addition; STROBE is a stable, widely-cited standard. Every observational study agent invocation should reference this.
*Confidence: High*

**3. `domain/study-designs.md`** (estimated 150–200 lines)
Single-file coverage of: cohort (prospective/retrospective), case-control (hospital/population-based), cross-sectional, RCT, meta-analysis, surveillance, compartmental modeling, target trial emulation. Each entry: definition, typical sample size methods, primary R packages, canonical analysis approach, reporting guideline. This is the decision-tree entry point for the research agent's Stage 2 (load study-design context).
*Confidence: High*

### Tier 2: High Value (resolve specific gaps, moderate effort)

**4. `domain/data-management.md`** (estimated 120–160 lines)
Missing data (MCAR/MAR/MNAR, `mice` for multiple imputation), variable transformation, codebook documentation, `cleanepi`/`linelist` usage. The current extension has zero missing data coverage. This is a gap that will appear in nearly every real study.
*Confidence: High*

**5. `domain/reporting-standards.md`** (estimated 80–100 lines)
Overview of STROBE (observational), CONSORT (RCT), PRISMA (systematic review/meta-analysis), TRIPOD (prediction models), RECORD (EHR-based studies). Maps each guideline to its target study design. Agents need to know which guideline applies before they start writing a report.
*Confidence: High*

**6. `templates/analysis-plan.md`** (estimated 120–150 lines)
Statistical analysis plan (SAP) template: primary outcome, secondary outcomes, covariates, statistical methods, sample size justification, missing data handling, sensitivity analyses, subgroup analyses. The SAP is the deliverable from the planning phase and the contract for the implementation phase. Without a template, agents produce inconsistent planning artifacts.
*Confidence: High*

### Tier 3: Useful (add before first real use)

**7. `templates/findings-report.md`** (estimated 100–120 lines)
Standard findings report structure: Executive Summary, Study Overview, Methods, Results (Table 1, primary analysis, sensitivity analyses), Discussion, Limitations, STROBE/CONSORT compliance checklist. This is what `epi-implement-agent` Phase 5 writes.
*Confidence: Medium — the exact format depends on study type, but a general template is better than none.*

**8. `domain/r-workflow.md`** (estimated 80–100 lines)
Standard R project structure, `renv` initialization, `targets` pipeline basics, `.gitignore` for data files, directory conventions (`data/raw/`, `data/clean/`, `analysis/`, `output/`). Ensures every study starts with reproducibility infrastructure.
*Confidence: Medium — standard but not critical for first study.*

**9. `templates/study-protocol.md`** (estimated 100–130 lines)
Study protocol template: background, objectives, study design, population, exposure/outcome definitions, data sources, analysis approach, ethics status, limitations. Used by the `/epi` scoping flow to produce a structured output.
*Confidence: Medium — `/epi` produces task metadata, not necessarily a document; may be overkill for task 400 but correct for a mature extension.*

### Tier 4: Defer

**10. `patterns/epi-scoping-questions.md`**
Documents the 10 forcing questions from the `/epi` Stage 0 flow. Value as agent-readable context is low (the command itself embeds the questions); value as human documentation is medium. Defer until the command is built and questions stabilize.
*Confidence: Low for task 400 scope.*

---

## Section D: Full Lifecycle Support Map

The extension should have a position statement on each study lifecycle phase:

| Phase | Current coverage | Recommended action |
|-------|-----------------|-------------------|
| 1. Study design & protocol | README brief mention | `domain/study-designs.md` covers all types |
| 2. IRB/ethics | Zero | `domain/study-designs.md` includes ethics section; forcing Q7 captures status |
| 3. Data acquisition & management | Zero | `domain/data-management.md` covers cleaning, codebooks, missing data |
| 4. Exploratory data analysis | `patterns/statistical-modeling.md` mentions it | `patterns/analysis-phases.md` documents full EDA phase |
| 5. Primary analysis | `patterns/statistical-modeling.md` good but incomplete | Expand with sample size justification, model diagnostics |
| 6. Sensitivity & subgroup analyses | Brief README mention | `patterns/analysis-phases.md` documents as required Phase 4 |
| 7. Results presentation | `tools/r-packages.md` lists `ggplot2`, `survminer` | `templates/findings-report.md` gives table/figure guidance |
| 8. Manuscript preparation | Zero | `domain/reporting-standards.md` + `patterns/strobe-checklist.md` |
| 9. Peer review response | Zero | Explicitly out of scope (separate task type needed) |
| 10. Reproducibility packaging | Zero | `domain/r-workflow.md` covers `renv`, `targets`, `.gitignore` |

**Phases 9 (peer review response) is explicitly out of scope** for task 400 and should not be addressed. It is a separate workflow with distinct artifacts and a different user mental model.

---

## Section E: Emerging Trends — What the Extension Should Anticipate

### 1. Target Trial Emulation (incorporate now — low effort)
The framework is mature enough to reference in `domain/study-designs.md`. Agents asked to design observational studies of treatment effects should know to ask "can this be framed as a target trial?" The `TrialEmulation` R package exists but is experimental; recommend noting framework without committing to a specific package.
*Confidence: High that this belongs in study-designs.md; Medium for timing of package reference.*

### 2. Bayesian Workflow with brms (add to r-packages.md now)
`brms` is the practical entry point for Bayesian epidemiology. The current extension lists only `rstan`/`cmdstanr` — the Stan-direct interfaces that require writing Stan code. `brms` uses R formula syntax and is appropriate for 90% of Bayesian epi use cases. Add a `brms` entry to `r-packages.md` with a "prefer brms over rstan for standard regression models" note.
*Confidence: High.*

### 3. ML for Causal Inference (reference in study-designs.md, defer full coverage)
TMLE (`tmle` package), double machine learning (`DoubleML`), and causal forests (`grf`) are increasingly standard for high-dimensional confounding. The extension should name-check these in `domain/study-designs.md` under a "causal inference methods" section. Full context file for ML-epi is a separate task (requires its own agent context to be useful).
*Confidence: Medium — relevant but complex enough to defer full treatment.*

### 4. Real-World Evidence / EHR Data
Structurally different from survey/cohort data: irregular observation times, healthcare-driven censoring, immeasurable confounders. The extension should note EHR-specific considerations in `domain/data-management.md` as a subsection ("EHR data special considerations") without claiming to fully support this workflow.
*Confidence: Medium.*

### 5. LLMs as Research Tools
Literature search via web, coding assistance, and data documentation (auto-generating codebooks from column names) are legitimate 2025 workflows. The agent itself is an LLM tool. No infrastructure needed — the agent already does this. Not a gap.
*Confidence: High that this is already handled.*

### 6. Federated Analysis
Multi-site non-sharing analyses (`DataSHIELD`, `OSDR`) are active development areas but not relevant to single-study workflows. Explicitly out of scope.
*Confidence: High — defer indefinitely.*

---

## Section F: How This Extension Relates to Field Resources

| Resource | Relationship |
|----------|-------------|
| **Epidemiologist R Handbook** | The handbook is reference material; the extension distills decision logic the handbook spreads across 40 chapters. Agents can WebSearch the handbook for specific code; context files should not duplicate it. |
| **Applied Epi community** | The `appliedepi` organization (maintainers of both the handbook and R4Epi) represents the practitioner community. The extension's study-designs taxonomy and analysis-phases sequence should align with Applied Epi's field epidemiology framing (outbreak response, surveillance, outbreak investigation). |
| **CRAN Task View: Epidemiology** | The task view covers infectious disease epidemiology only. The extension is broader (clinical/observational epidemiology). `r-packages.md` should expand beyond the task view's scope to cover `MatchIt`, `WeightIt`, `episensr`, `epiR`, `tableone`, `gtsummary`. |
| **R-Ladies / R in Medicine** | Community best practices (reproducibility, documentation, `gtsummary` for Table 1) should inform the `r-workflow.md` and `findings-report.md` template. No formal dependency. |

---

## Section G: Concrete Recommendations

### G1. Recommended Directory Structure

```
.claude/extensions/epidemiology/context/project/epidemiology/
├── README.md                          # existing — expand to 80 lines
├── domain/
│   ├── study-designs.md              # NEW — 150-200 lines
│   ├── r-workflow.md                 # NEW — 80-100 lines
│   ├── data-management.md            # NEW — 120-160 lines
│   └── reporting-standards.md        # NEW — 80-100 lines
├── patterns/
│   ├── statistical-modeling.md       # existing — expand
│   ├── analysis-phases.md            # NEW — 80-100 lines
│   ├── strobe-checklist.md           # NEW — 60-80 lines
│   └── epi-scoping-questions.md      # NEW but low priority — defer
├── templates/
│   ├── study-protocol.md             # NEW — 100-130 lines
│   ├── analysis-plan.md              # NEW — 120-150 lines
│   └── findings-report.md            # NEW — 100-120 lines
└── tools/
    ├── r-packages.md                  # existing — expand significantly
    └── mcp-guide.md                   # existing — minor update
```

**Total estimated line count**: ~1,400–1,700 lines across all context files (up from current ~248 lines). This is proportionate to `present/`'s ~3,200 lines across 27 files, scaled for a single-command vs. 5-command extension.

### G2. Prioritized File Creation List

**Must create (unblock agent reasoning in task 400)**:
1. `domain/study-designs.md` — Without this, the research agent cannot make study-design-specific decisions
2. `patterns/analysis-phases.md` — Without this, implementation agent has no workflow scaffold
3. `patterns/strobe-checklist.md` — Zero-cost addition; every observational study benefits
4. `domain/reporting-standards.md` — Maps guideline to study type; needed for forcing Q8

**Should create (complete the lifecycle)**:
5. `domain/data-management.md` — Missing data is ubiquitous; the current coverage gap is significant
6. `templates/analysis-plan.md` — The SAP is the planning phase artifact
7. `templates/findings-report.md` — The findings report is the implementation phase artifact

**Can create later (improve reproducibility guidance)**:
8. `domain/r-workflow.md` — renv/targets setup; defer if task 400 scope is tight
9. `templates/study-protocol.md` — Defer until /epi command is stable

**Explicitly defer (separate tasks)**:
10. `patterns/epi-scoping-questions.md` — Document the forcing questions after the command stabilizes
11. Any ML/causal-forest deep-dive — Needs its own context subsystem

### G3. index.json Structure for Optimal Agent Context Loading

Each entry should follow the `present` extension pattern with `task_types` (not `languages`). The key insight from `present/index-entries.json`: entries are scoped by *agent* AND *command*, not just task type. This allows selective loading — the research agent loads study-design and analysis context; the implement agent loads data-management and template context.

**Loading design**:
```json
// Pattern: domain/ files → load for research agent + /epi command
{
  "path": "project/epidemiology/domain/study-designs.md",
  "load_when": {
    "task_types": ["epi", "epi:study"],
    "agents": ["epi-research-agent"],
    "commands": ["/epi"]
  }
}

// Pattern: patterns/ files → load for both agents (needed in research AND implement)
{
  "path": "project/epidemiology/patterns/analysis-phases.md",
  "load_when": {
    "task_types": ["epi", "epi:study"],
    "agents": ["epi-research-agent", "epi-implement-agent"],
    "commands": ["/epi"]
  }
}

// Pattern: templates/ files → load for implement agent only
{
  "path": "project/epidemiology/templates/findings-report.md",
  "load_when": {
    "task_types": ["epi", "epi:study"],
    "agents": ["epi-implement-agent"],
    "commands": []
  }
}

// Pattern: tools/ files → load for both agents + /epi command
{
  "path": "project/epidemiology/tools/r-packages.md",
  "load_when": {
    "task_types": ["epi", "epi:study"],
    "agents": ["epi-research-agent", "epi-implement-agent"],
    "commands": ["/epi"]
  }
}
```

**Target: 12–14 index entries** (up from current 4), distributed as:
- 4 domain/ entries (research agent + /epi)
- 3 patterns/ entries (both agents + /epi)
- 3 templates/ entries (implement agent only)
- 2 tools/ entries (both agents + /epi)
- 1 README.md entry (both agents + /epi, always)

### G4. What the Extension Should NOT Try to Do (Scope Boundaries)

**Hard out-of-scope (never build here)**:
- **General R extension**: R is used by many domains. If an `r` alias is kept in routing, it should immediately redirect to `epi` — no general R data analysis support.
- **Quarto/Rmarkdown rendering pipeline**: Produces rendered documents, not findings-report.md. A separate `present:epi-talk` or `latex:report` extension is the right home.
- **PubMed/literature search automation**: The research agent can WebSearch. A dedicated literature review workflow belongs in a future `epi:review` sub-type, not in the core extension.
- **Federated analysis / DataSHIELD**: Multi-site non-sharing analysis is a specialty workflow with no general agent patterns yet.
- **General ML prediction models**: TMLE and causal forests deserve a brief mention in `study-designs.md`; a full ML-epi context system is a separate extension or a future `epi:prediction` sub-type.

**Soft out-of-scope (note but don't build)**:
- **Docker containerization**: `domain/r-workflow.md` can mention Docker as an option beyond `renv`, but building Docker support is out of scope.
- **Peer review response workflow**: Different artifacts, different mental model. Future `epi:revision` sub-type.
- **Multi-country / WHO-standard surveillance**: ECDC/WHO data formats and surveillance protocols are specialized; the extension's surveillance support should be limited to compartmental modeling (what it already covers) and outbreak curve analysis.

---

## Section H: 6–12 Month Trajectory

Assuming task 400 completes the core infrastructure, the natural next evolution of the extension is:

**Months 1–3 (after task 400)**: First real study uses the extension. The forcing questions and agent flows will reveal gaps. Expect: missing package guidance, analysis-phases ordering issues, template format mismatches with actual output. Fix via targeted mini-tasks.

**Months 3–6**: If the extension is used for ≥ 2 different study types, a `epi:survival` or `epi:meta` compound key may become justified. The team synthesis correctly defers this — wait for real usage to drive the split.

**Months 6–12**: The `epi:study` → research → plan → implement cycle will stabilize. At that point, the right next investment is either: (a) adding Bayesian workflow depth (`brms` examples, prior elicitation guide) or (b) adding a `epi:prediction` sub-type for ML-based prediction models. The Bayesian path is lower-risk because `brms` is stable; the ML path requires more agent scaffolding.

**Long-term**: Target trial emulation will likely become important enough to justify a `epi:tte` sub-type. The `TrialEmulation` package ecosystem is developing rapidly. Monitor and create a tracking task when the package hits CRAN stable.

---

## Teammate D Summary for Synthesis

| Recommendation | Confidence | Priority |
|---------------|------------|----------|
| Hybrid directory structure (domain/patterns/templates/tools) | High | Must |
| `domain/study-designs.md` as first-file-to-create | High | Must |
| `patterns/analysis-phases.md` as agent workflow scaffold | High | Must |
| `patterns/strobe-checklist.md` as zero-cost addition | High | Must |
| Fix `r-packages.md`: add brms, cleanepi, linelist, epiR, epitools, episensr, tableone, gtsummary | High | Must |
| `domain/reporting-standards.md` for guideline-to-design mapping | High | Should |
| `domain/data-management.md` for missing data coverage | High | Should |
| `templates/analysis-plan.md` for planning phase artifact | High | Should |
| `templates/findings-report.md` for implementation phase artifact | Medium | Should |
| `domain/r-workflow.md` for renv/targets setup | Medium | Can defer |
| Target trial emulation mention in study-designs.md | High | Should |
| brms addition to r-packages.md | High | Must |
| index.json: 12–14 entries with agent-scoped loading | High | Must |
| Scope boundary: no Quarto, no PubMed automation, no general R extension | High | Must (enforce) |

---

*Sources consulted*:
- [The Epidemiologist R Handbook](https://www.epirhandbook.com/en/) — chapter structure and content organization
- [R 4 Epidemiology](https://www.r4epi.com/) — teaching curriculum topics
- [CRAN Task View: Epidemiology](https://cran.r-project.org/web/views/Epidemiology.html) — package inventory (updated March 2025)
- [STROBE Statement](https://www.strobe-statement.org/) — 22-item observational study checklist
- [Target Trial Emulation — Annals of Internal Medicine 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC11936718/) — framework components
- [Reproducible Epidemiology in R — renv](https://www.reproducible-epi-workshop.louisahsmith.com/renv) — renv/targets workflow
- [brms package](https://paulbuerkner.com/brms/) — Bayesian multilevel models via Stan
- [Machine Learning in Causal Inference for Epidemiology — PMC 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11599438/) — TMLE, causal forests overview
- `specs/400_epi_extension_overhaul/reports/01_team-research.md` — team synthesis
- `.claude/extensions/present/index-entries.json` — structural reference for 27-file mature extension
- `.claude/extensions/present/manifest.json` — compound routing reference
