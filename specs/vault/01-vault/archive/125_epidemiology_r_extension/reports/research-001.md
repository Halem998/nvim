# Research Report: Task #125

**Task**: OC_125 - Add epidemiology research extension for R and related tooling
**Date**: 2026-03-03
**Language**: meta
**Focus**: Extension architecture and epidemiology research tooling

## Summary

This research identifies the complete structure required for an epidemiology extension supporting R-based research workflows. The extension must be created in both `.opencode/extensions/` and `.claude/extensions/` following the established pattern. Key findings include: (1) standard extension structure with EXTENSION.md, manifest.json, agents/, skills/, and context/ directories; (2) two viable R MCP servers available - rmcp (33 statistical tools) and mcptools (CRAN package); (3) epidemiology-specific workflows require data manipulation, statistical modeling, survival analysis, and visualization capabilities. The recommended approach integrates R MCP tooling with domain-specific agents for epidemiological research.

## Findings

### Extension Structure Pattern

All extensions follow a consistent directory structure:

```
extensions/{extension-name}/
├── EXTENSION.md          # Documentation for OPENCODE.md integration
├── manifest.json         # Extension metadata and merge targets
├── index-entries.json    # Context index entries
├── agents/              # Agent definitions (*.md files)
├── skills/              # Skill definitions (skill-*/SKILL.md)
├── context/             # Domain knowledge (project/{domain}/)
├── commands/            # Extension-specific slash commands (optional)
├── rules/               # Auto-applied rules (optional)
├── scripts/             # Utility scripts (optional)
└── settings-fragment.json  # Settings additions (optional)
```

**Key files analyzed:**
- `formal/EXTENSION.md`: 60 lines, includes language routing tables, skill-agent mapping, domain routing
- `nix/manifest.json`: Declares merge_targets for opencode_md, settings, and index integration
- `python/skills/skill-python-research/SKILL.md`: Frontmatter format with name, description, allowed_tools, context

### R MCP Server Options

Two primary R MCP servers are available for integration:

**1. rmcp (finite-sample/rmcp)**
- 33 statistical tools across 8 categories
- Features: Linear/logistic regression, time series analysis, panel data, instrumental variables
- Installation: `pip install rmcp`
- Command: `rmcp start`
- Best for: Econometric and statistical modeling workflows

**2. mcptools (CRAN package)**
- Official Posit/CRAN package
- Enables R functions as MCP tools
- Supports custom tool definitions via R functions
- Best for: Custom epidemiology-specific analysis tools

**Recommendation**: Use both - rmcp for standard statistical operations, mcptools for custom epidemiology functions.

### Epidemiology Research Workflow Requirements

Standard epidemiology research requires:

1. **Data Management**: Data cleaning, variable transformation, missing data handling
2. **Descriptive Statistics**: Summary statistics, cross-tabulations, stratified analysis
3. **Statistical Modeling**: 
   - Linear regression (continuous outcomes)
   - Logistic regression (binary outcomes)
   - Cox proportional hazards (survival analysis)
   - Poisson regression (count data)
4. **Epidemiology-Specific Analysis**:
   - Odds ratios, risk ratios, hazard ratios
   - Confidence intervals
   - Interaction and stratification
   - Sensitivity/specificity analysis
5. **Visualization**: Forest plots, survival curves, epidemic curves
6. **Reporting**: R Markdown/Quarto integration for reproducible research

### Integration Points

Extensions integrate with the system through:

1. **OPENCODE.md**: Extension adds a section via `merge_targets.opencode_md`
2. **Context Index**: Entries added to `.opencode/context/index.json`
3. **Skills**: Register with orchestrator for language routing
4. **Settings**: MCP server configuration in `settings.local.json`

### Existing Extension Comparison

| Extension | Agents | Skills | Commands | MCP | Context |
|-----------|--------|--------|----------|-----|---------|
| formal | 4 | 4 | 0 | No | logic, math, physics |
| lean | 2 | 2 | 2 | Yes (lean-lsp) | lean4 |
| nix | 2 | 2 | 0 | Yes (nixos) | nix |
| python | 2 | 2 | 0 | No | python |
| web | 2 | 2 | 0 | Yes (astro, playwright) | web |

## Recommendations

1. **Create dual extensions** in both `.opencode/extensions/epidemiology/` and `.claude/extensions/epidemiology/`

2. **Extension structure**:
   - `EXTENSION.md`: Document R language routing and epidemiology-specific workflows
   - `manifest.json`: Declare merge targets for index.json and OPENCODE.md
   - `agents/`: epidemiology-research-agent.md, epidemiology-implementation-agent.md
   - `skills/`: skill-epidemiology-research, skill-epidemiology-implementation
   - `context/project/epidemiology/`: README, data-management, statistical-methods, visualization

3. **MCP Server Configuration**:
   ```json
   "mcp_servers": {
     "rmcp": {
       "command": "rmcp",
       "args": ["start"]
     }
   }
   ```

4. **Language routing** in EXTENSION.md:
   | Language | Research Tools | Implementation Tools |
   |----------|----------------|---------------------|
   | `r` | rmcp, WebSearch | Rscript, Read, Write |
   | `epidemiology` | skill-epi-research | skill-epi-implementation |

5. **Skill-agent mapping**:
   | Skill | Agent | Purpose |
   |-------|-------|---------|
   | skill-epi-research | epi-research-agent | Study design, analysis planning |
   | skill-epi-impl | epi-impl-agent | R code implementation |

6. **Context categories**:
   - Domain: Epidemiology concepts (study designs, bias, confounding)
   - Patterns: R analysis patterns (dplyr, ggplot2, survival)
   - Tools: rmcp tools guide, R Markdown workflow
   - Standards: Epidemiology reporting (STROBE, CONSORT)

## Risks & Considerations

- **R Installation**: Requires R to be installed on the system; extension should document prerequisites
- **Package Dependencies**: R packages (tidyverse, survival, etc.) must be installed separately
- **MCP Server Availability**: rmcp requires Python/pip; mcptools requires R installation
- **Data Privacy**: Epidemiology often involves sensitive health data; ensure workflow guidance includes de-identification practices
- **Extension Size**: Balance between comprehensive coverage and focused utility

## Next Steps

Run `/plan OC_125` to create an implementation plan with phased approach:
1. Phase 1: Create extension structure and manifest
2. Phase 2: Implement agents and skills
3. Phase 3: Create context documentation
4. Phase 4: Configure MCP integration
5. Phase 5: Test and document workflows

## References

- Extension examples: `.opencode/extensions/formal/`, `.opencode/extensions/nix/`
- rmcp: https://github.com/finite-sample/rmcp
- mcptools: https://cran.r-project.org/web/packages/mcptools/
- MCP spec: https://modelcontextprotocol.io/
