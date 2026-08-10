# Research Report: Port Synthesis Domain Agents

- **Task**: 635 - port_synthesis_domain_agents
- **Started**: 2026-06-08T03:00:00Z
- **Completed**: 2026-06-08T03:25:00Z
- **Effort**: 2-3 hours (synthesis-agent + 3 domain agents + skill integration touch-ups)
- **Dependencies**: 633 (port_core_script_infrastructure) - [COMPLETED], 634 (port_orchestrator_system) - [RESEARCHED/PLANNED]
- **Sources/Inputs**:
  - Codebase: `.claude/agents/synthesis-agent.md` (218 lines), `.claude/extensions/present/agents/slides-research-agent.md` (303 lines), `.claude/extensions/founder/agents/deck-research-agent.md`, `.claude/extensions/present/agents/slide-critic-agent.md`
  - Codebase (target): `.opencode/agent/subagents/` (8 files, no synthesis-agent), `.opencode/extensions/present/agents/` (9 files), `.opencode/extensions/founder/agents/` (15 files)
  - Related: `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` (predecessor), `specs/634_port_orchestrator_system/reports/01_port_orchestrator_research.md` (predecessor)
  - Standards: `.claude/docs/reference/standards/agent-frontmatter-standard.md`, `.opencode/docs/reference/standards/agent-frontmatter-standard.md` (model field NOT supported in OpenCode)
  - Reference: `.claude/context/patterns/context-protective-lead.md`, `.claude/context/reference/team-wave-helpers.md` (synthesis dispatch template)
  - Roadmap: `specs/ROADMAP.md`
  - State: `specs/state.json` (active projects 633-637 = sequential porting chain)
- **Artifacts**: `specs/635_port_synthesis_domain_agents/reports/01_synthesis_domain_agents_research.md`
- **Standards**: report-format.md, status-markers.md, artifact-management.md, agent-frontmatter-standard.md

## Project Context

- **Upstream Dependencies**: Task 633 (port_core_script_infrastructure) - [COMPLETED]; provides `dispatch-agent.sh` and `skill-base.sh` shared infrastructure. Task 634 (port_orchestrator_system) - [RESEARCHED/PLANNED]; provides the team skill orchestrator infrastructure that the synthesis-agent is forked from.
- **Downstream Dependents**: Task 636 (sync_context_rules_extensions_cleanup) - depends on 635; Task 637 (verification_and_drift_detection) - depends on 635
- **Alternative Paths**: (a) Port only the core `synthesis-agent` and skip domain-specific synthesis agents (slides-research, deck-research, slide-critic) since they already exist with same content; (b) Port synthesis-agent AND rewire the three .opencode/ team skills to use the synthesis-agent dispatch pattern (full feature parity with .claude/)
- **Potential Extensions**: Add `synthesis_failed` postflight metadata in .opencode/ team skills; port `patterns/context-protective-lead.md` to .opencode/ context; port `team-wave-helpers.md` synthesis dispatch template

## Executive Summary

- **"Synthesis domain agents" in this context has two layers**: (1) the **core `synthesis-agent`** — a single subagent that reads multiple teammate outputs and produces a unified artifact (used by `.claude/` team-research, team-plan, team-implement), and (2) **domain-specific synthesis agents** in the `present` and `founder` extensions (slides-research-agent, deck-research-agent, slide-critic-agent) that perform material synthesis for a specific output format
- **The core `synthesis-agent` is MISSING from `.opencode/`** — it does not exist in `.opencode/agent/subagents/` nor in `.opencode/extensions/core/agents/`. This is the primary porting deliverable for this task
- **The domain-specific synthesis agents ALREADY EXIST in `.opencode/`** — `slides-research-agent.md`, `deck-research-agent.md`, `slide-critic-agent.md` are present in `.opencode/extensions/present/agents/` and `.opencode/extensions/founder/agents/` and are content-equivalent to their `.claude/` counterparts (only differences: `model: sonnet` line, `Agent tool` -> `Task tool`, `.claude/context/` -> `.opencode/context/` path references)
- **The `.opencode/` team skills do NOT use a synthesis-agent** — `skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md` all do synthesis INLINE in the lead. This is a major architectural gap relative to `.claude/` and is the key reason the lead context grows by 7-21k tokens per team run (vs ~250 tokens in `.claude/`)
- **Required porting actions** are: (a) port `synthesis-agent.md` to `.opencode/agent/subagents/` with model field stripped and `Agent` -> `Task` tool name change; (b) update the three `.opencode/` team skills to dispatch the synthesis-agent instead of doing inline synthesis; (c) sweep `.claude/context/` -> `.opencode/context/` path references; (d) add `synthesis_failed` postflight metadata pattern
- **Domain synthesis agents (slides/deck/critic) need only minor frontmatter cleanup** — strip the `model:` line per OpenCode's frontmatter standard (model field causes "Model not found" errors), verify the `Task tool` references, and confirm path references use `.opencode/context/`. Their semantic content is already ported

## Context & Scope

This research examines the "synthesis domain agents" in `.claude/` that need to be ported to `.opencode/`. The term "synthesis domain agents" in this task's context encompasses TWO distinct concepts that the porting work must address:

### 1. Core Synthesis Subagent (`.claude/agents/synthesis-agent.md`)

A **generic, cross-domain synthesis subagent** that operates on any number of teammate finding files. It reads each file in its own fresh context, detects conflicts, identifies gaps, performs evidence-based resolution, and writes a unified output (research report, plan, or implementation summary). It is the cornerstone of the **context-protective-lead pattern**: the lead skill never reads teammate outputs directly — it forks the synthesis-agent and receives only a ~200-word summary.

### 2. Domain-Specific Synthesis Agents (present, founder extensions)

Agents whose PURPOSE is to perform material synthesis for a specific output format:
- **`slides-research-agent`** (`present` extension) — material synthesis into slide-mapped research reports for academic talks
- **`deck-research-agent`** (`founder` extension) — material synthesis for pitch deck content extraction
- **`slide-critic-agent`** (`present` extension) — critique synthesis against a 6-category rubric

These are not generic — they apply domain knowledge (talk structure, pitch deck patterns, critique rubrics) and produce format-specific outputs. They are **forked by the `skill-slides` and `skill-deck-research` skills** via the standard `Task` tool dispatch pattern (not via the team-mode synthesis flow).

### Roadmap Context

From `specs/ROADMAP.md`, this task is **not directly mapped** to any specific roadmap item. It is part of the porting chain (633->634->635->636->637) that maintains parity between `.claude/` and `.opencode/` systems. The broader roadmap Phase 1 priorities focus on documentation infrastructure (manifest-driven READMEs, marketplace metadata, doc-lint CI, review integration).

### Task 633 & 634 Relationship

- **Task 633 (port_core_script_infrastructure) - COMPLETED** provides `dispatch-agent.sh` (used for synthesis-agent forking) and `skill-base.sh` (provides handoff schema functions used by the synthesis agent)
- **Task 634 (port_orchestrator_system) - RESEARCHED/PLANNED** provides the `skill-orchestrator` and `skill-orchestrate` orchestration skills. The synthesis-agent is invoked FROM the team-mode skills (which are sub-mode of skill-orchestrator). Task 634's research explicitly notes this dependency in its downstream list

The synthesis-agent is the **terminal dispatch step** in the team-mode flow: teammates run, write finding files, lead collects paths, lead forks synthesis-agent, synthesis-agent writes unified artifact, lead receives summary.

## Findings

### Core Synthesis Subagent Analysis

#### `.claude/agents/synthesis-agent.md` (218 lines)

| Field | Value |
|-------|-------|
| Name | `synthesis-agent` |
| Description | Multi-output synthesis for team skills |
| Model | `sonnet` (per frontmatter) |
| Allowed tools | `Read, Write` |
| Invoked by | `skill-team-research` (line 369), `skill-team-plan` (line 331), `skill-team-implement` (line 421) |
| Purpose | Read all teammate finding files in fresh context, resolve conflicts, identify gaps, write unified report/plan/summary |
| Return format | Compact ~200-word text summary: top 3 findings, conflict count, gap count, confidence, report path |
| Output context | `<200 words` for lead; full report in file system |

**Key architectural features**:
1. **Fresh context per invocation** — the synthesis-agent runs in a new context with full visibility into all teammate outputs
2. **Multi-format support** — same agent can write research reports, plans, or implementation summaries (format differs based on `workflow_type` parameter)
3. **Conflict resolution logic** — explicit Stage 4 in the agent's execution flow handles inter-teammate conflicts
4. **Gap analysis** — explicit Stage 5 identifies coverage gaps; does NOT fabricate findings to fill gaps
5. **Critic assessment integration** — explicit Stage 6 downgrades confidence based on Teammate C critiques
6. **Graceful degradation** — missing teammate files do not abort synthesis; gaps are noted
7. **Write-failure handling** — partial synthesis on write failure, error summary returned

#### Synthesis-agent in `.opencode/` - **MISSING**

The `.opencode/` system has NO `synthesis-agent`:
- Not in `.opencode/agent/subagents/` (which has 8 files, none of them synthesis-agent)
- Not in `.opencode/extensions/core/agents/` (which has 8 files, none of them synthesis-agent)
- Not in `.opencode/agent/` (only `orchestrator.md` and `subagents/`)

This is the PRIMARY porting deliverable.

#### How `.opencode/` Currently Does Synthesis (Inline)

The three `.opencode/` team skills perform synthesis INLINE in the lead:

- **`skill-team-research/SKILL.md`** Stage 7 ("Collect Teammate Results") and Stage 8 ("Synthesize Findings") — the LEAD reads each teammate file, extracts findings, detects conflicts, and writes the unified report
- **`skill-team-research/SKILL.md`** Stage 9 ("Create Unified Report") — the LEAD writes the report directly using the same context as the orchestration loop
- **`skill-team-plan/SKILL.md`** Stage 8 and Stage 9 — same pattern: lead reads candidate plan files, synthesizes, writes unified plan
- **`skill-team-implement/SKILL.md`** Stage 11 — lead collects phase result file paths and writes summary directly

This violates the **context-protective-lead pattern** that `.claude/` enforces. The lead context grows by 7-21k tokens per team run (the size of all teammate files combined) instead of ~250 tokens (the synthesis summary).

#### Inline Synthesis Helpers in `.opencode/context/reference/team-wave-helpers.md`

The `.opencode/` synthesis helper documentation (lines 232-281) describes the synthesis pattern as something the LEAD does:

```python
# Synthesis procedure
1. Initialize synthesis object
   - conflicts_found: 0
   - conflicts_resolved: 0
   - gaps_identified: 0
2. For each teammate result:
   a. Extract key findings
   ...
```

The corresponding `.claude/context/reference/team-wave-helpers.md` (lines 571-665) describes the synthesis pattern as a DISPATCH to the synthesis-agent with template prompts.

**This is a fundamental architectural difference** that must be addressed when porting synthesis-agent — the `.opencode/` skills must be updated to dispatch the agent rather than doing inline synthesis.

### Domain-Specific Synthesis Agents Analysis

#### Present Extension Synthesis Agents

| Agent | Purpose | Frontmatter | Status in .opencode/ |
|-------|---------|-------------|----------------------|
| `slides-research-agent.md` | Research talk material synthesis for academic presentations | `name`, `description`, `model: sonnet` | PRESENT (303 lines) |
| `slide-critic-agent.md` | Review presentation materials against critique rubric | `name`, `description`, `model: sonnet` | PRESENT (450 lines) |
| `slide-planner-agent.md` | Create slide-by-slide implementation plans | `name`, `description`, `model: sonnet` | PRESENT |
| `pptx-assembly-agent.md` | PowerPoint assembly from slide-mapped reports | `name`, `description`, `model: sonnet` | PRESENT (330 lines) |
| `slidev-assembly-agent.md` | Slidev assembly from slide-mapped reports | `name`, `description`, `model: sonnet` | PRESENT |
| `budget-agent.md` | Grant budget spreadsheet generation | `name`, `description`, `model: sonnet` | PRESENT |
| `funds-agent.md` | Funding landscape analysis | `name`, `description`, `model: sonnet` | PRESENT |
| `grant-agent.md` | Grant proposal research and writing | `name`, `description`, `model: sonnet` | PRESENT |
| `timeline-agent.md` | Medical research project timelines | `name`, `description`, `model: sonnet` | PRESENT |

#### Founder Extension Synthesis Agents

| Agent | Purpose | Frontmatter | Status in .opencode/ |
|-------|---------|-------------|----------------------|
| `deck-research-agent.md` | Pitch deck content research through material synthesis | `name`, `description`, `model: sonnet` | PRESENT |
| `deck-planner-agent.md` | Create slide-by-slide deck plans | `name`, `description`, `model: sonnet` | PRESENT |
| `deck-builder-agent.md` | Assemble pitch decks | `name`, `description`, `model: sonnet` | PRESENT |
| `analyze-agent.md` | Market/business analysis | `name`, `description`, `model: sonnet` | PRESENT |
| `finance-agent.md`, `financial-analysis-agent.md` | Financial analysis | `name`, `description`, `model: sonnet` | PRESENT |
| `founder-implement-agent.md`, `founder-plan-agent.md` | Implementation/plan agents | `name`, `description`, `model: sonnet` | PRESENT |
| `founder-spreadsheet-agent.md` | Founder spreadsheet generation | `name`, `description`, `model: sonnet` | PRESENT |
| `legal-analysis-agent.md`, `legal-council-agent.md` | Legal analysis | `name`, `description`, `model: sonnet` | PRESENT |
| `market-agent.md`, `meeting-agent.md`, `project-agent.md`, `strategy-agent.md` | Business operations | `name`, `description`, `model: sonnet` | PRESENT |

#### Diff Example: `slides-research-agent.md`

```diff
- model: sonnet
- - **Invoked By**: skill-slides (via Agent tool)
+ - **Invoked By**: skill-slides (via Task tool)
- - `@.claude/context/formats/return-metadata-file.md` - Metadata file schema
+ - `@.opencode/context/formats/return-metadata-file.md` - Metadata file schema
- - `@.claude/extensions/present/context/project/present/talk/index.json`
+ - `@.opencode/extensions/present/context/project/present/talk/index.json`
```

The diffs are **systematic and minimal**:
1. Remove `model: sonnet` line (OpenCode rejects this per agent-frontmatter-standard.md)
2. Change `Agent tool` references to `Task tool` (OpenCode uses Task tool)
3. Change `.claude/context/` to `.opencode/context/` in @-references
4. Change `.claude/extensions/` to `.opencode/extensions/` in @-references
5. Change `Agent(...)` dispatch examples to `Task(...)`

These changes are already in the `.opencode/` versions of the domain agents. **No semantic content porting is required for the domain synthesis agents** — only verification that the existing ported versions conform to current OpenCode standards.

### OpenCode Synthesis-Agent Porting Plan (Derived)

The port of `synthesis-agent.md` from `.claude/agents/synthesis-agent.md` (218 lines) to `.opencode/agent/subagents/synthesis-agent.md` requires:

1. **Strip `model: sonnet`** from frontmatter (OpenCode standard: "The `model` field is NOT supported in OpenCode frontmatter")
2. **Remove `allowed-tools: Read, Write`** OR adapt to OpenCode tool naming (Read/Write are valid in OpenCode too, but check allowed-tools syntax)
3. **Update Context References** to point to `.opencode/context/`:
   - `.claude/context/formats/report-format.md` -> `.opencode/context/formats/report-format.md`
   - `.claude/context/formats/return-metadata-file.md` -> `.opencode/context/formats/return-metadata-file.md`
4. **Adapt Task Tool references** (e.g., if any `Agent(` -> `Task(` examples exist; currently the agent file does not have any)
5. **Verify handoff schema references** align with `.opencode/docs/architecture/handoff-schema.md` (if exists) or `.opencode/context/formats/handoff-artifact.md` (which DOES exist in .opencode/ at `extensions/core/context/formats/handoff-artifact.md`)
6. **Verify report-format.md and return-metadata-file.md** are available in `.opencode/context/formats/` (verified: both exist)

### Team Skill Update Requirements

The three `.opencode/` team skills need updates to dispatch the synthesis-agent:

1. **`skill-team-research/SKILL.md`** — replace Stage 7 (Collect Teammate Results) and Stage 8 (Synthesize Findings) inline loops with synthesis-agent dispatch
2. **`skill-team-plan/SKILL.md`** — replace Stage 8/9 inline synthesis with synthesis-agent dispatch
3. **`skill-team-implement/SKILL.md`** — replace Stage 11 inline summary with synthesis-agent dispatch

The `.claude/` versions of these skills include the synthesis-agent dispatch template (lines 354-405 of `skill-team-research/SKILL.md` in `.claude/`). This template can be ported with the same `Task(` -> `Task(` substitution, the `.claude/context/` -> `.opencode/context/` path updates, and the `synthesis-agent` subagent_type reference.

### Inventory Summary

#### Missing from `.opencode/` (Must Port)

| Component | Lines | Source | Target |
|-----------|-------|--------|--------|
| `synthesis-agent.md` | 218 | `.claude/agents/synthesis-agent.md` | `.opencode/agent/subagents/synthesis-agent.md` |
| Synthesis dispatch template | ~50 | `.claude/context/reference/team-wave-helpers.md` (Synthesis Agent Dispatch section) | `.opencode/context/reference/team-wave-helpers.md` (extend) |

#### Required Updates to Existing `.opencode/` Skills

| File | Updates | Source reference |
|------|---------|------------------|
| `.opencode/extensions/core/skills/skill-team-research/SKILL.md` | Replace inline synthesis (Stages 7-8) with synthesis-agent dispatch | `.claude/skills/skill-team-research/SKILL.md` (lines 354-405) |
| `.opencode/extensions/core/skills/skill-team-plan/SKILL.md` | Replace inline synthesis (Stage 8-9) with synthesis-agent dispatch | `.claude/skills/skill-team-plan/SKILL.md` (lines 327-385) |
| `.opencode/extensions/core/skills/skill-team-implement/SKILL.md` | Replace inline summary (Stage 11) with synthesis-agent dispatch | `.claude/skills/skill-team-implement/SKILL.md` (lines 417-475) |
| `.opencode/context/reference/team-wave-helpers.md` | Add "Synthesis Agent Dispatch" section (line 232 onward) | `.claude/context/reference/team-wave-helpers.md` (lines 571-665) |

#### Domain Synthesis Agents - Frontmatter Sweep Required

All 9 present extension agents and 15 founder extension agents need their frontmatter swept to remove the `model:` line. This is a small mechanical change.

#### Files Already Ported (Verification Only)

All 9 present agents and 15 founder agents exist in `.opencode/` and appear to have been correctly ported in earlier work (likely task OC_512). They use `Task tool` references and `.opencode/context/` paths. The only systematic porting work needed is:
- Remove `model: sonnet` from frontmatter
- Verify `Task tool` references (not `Agent tool`)
- Verify `.opencode/context/` path references

## Decisions

1. **Port synthesis-agent to `.opencode/agent/subagents/`** (not `.opencode/extensions/core/agents/`). The system root is the primary agent location per the existing pattern (where `general-research-agent.md`, `planner-agent.md`, etc. live). The `extensions/core/agents/` directory contains a parallel set of agents that is somewhat redundant with the system root; placing the synthesis-agent at the system root maintains the .claude/ parity.

2. **Do NOT create a domain-specific "synthesis" agent for present/founder**. The existing `slides-research-agent`, `deck-research-agent`, and `slide-critic-agent` are already domain-synthesis agents and are already ported. Adding additional synthesis agents would be redundant and could cause routing confusion.

3. **Do NOT update the three .opencode/ team skills to use the synthesis-agent in this porting pass**. This is a follow-up task. The synthesis-agent file must exist first (port deliverable). The skill rewiring is a separate task that depends on having a working synthesis-agent and a verified team-skill dispatch pattern. This keeps the porting scope manageable and follows the dependency-driven phasing used in tasks 633-634.

4. **Port the synthesis-agent's context references to `.opencode/context/`** rather than leaving them as `.claude/context/`. The synthesis-agent is generic and should reference the opencode system directly (it will be invoked from .opencode/ skills).

5. **Strip the `model: sonnet` line from the synthesis-agent frontmatter**. Per OpenCode's agent-frontmatter-standard.md, the model field causes "Model not found" errors. OpenCode uses session model selection via the TUI model picker.

6. **Domain synthesis agent frontmatter sweep should be a separate sweep task**. The 24 domain agents (9 present + 15 founder) all have `model: sonnet` in their frontmatter and may have other minor issues. This should be a single mechanical pass, possibly combined with task 636 (sync_context_rules_extensions_cleanup).

7. **Preserve synthesis-agent's allowed-tools: Read, Write restriction**. The synthesis-agent is intentionally narrow — it only reads teammate outputs and writes the unified artifact. This is a key design feature that prevents the agent from drifting into other work. The restriction should be preserved verbatim in the port.

## Recommendations

### Priority Tiers for Implementation

**Tier 1: Core Synthesis-Agent Port (Primary Deliverable)**
- Port `.claude/agents/synthesis-agent.md` -> `.opencode/agent/subagents/synthesis-agent.md`
- Remove `model: sonnet` from frontmatter
- Verify `allowed-tools: Read, Write` syntax for OpenCode
- Update all `.claude/context/` references to `.opencode/context/` references
- Verify the file follows OpenCode agent-frontmatter-standard.md

**Tier 2: Team Skill Rewiring (Out of Scope for This Task)**
- Update `.opencode/extensions/core/skills/skill-team-research/SKILL.md` to dispatch synthesis-agent
- Update `.opencode/extensions/core/skills/skill-team-plan/SKILL.md` to dispatch synthesis-agent
- Update `.opencode/extensions/core/skills/skill-team-implement/SKILL.md` to dispatch synthesis-agent
- These changes require the synthesis-agent to exist AND the dispatch pattern to be verified

**Tier 3: Synthesis Dispatch Template (Optional, Out of Scope)**
- Add "Synthesis Agent Dispatch" section to `.opencode/context/reference/team-wave-helpers.md`
- Port from `.claude/context/reference/team-wave-helpers.md` (lines 571-665)

**Tier 4: Domain Agent Frontmatter Sweep (Out of Scope)**
- Strip `model: sonnet` from 9 present extension agents
- Strip `model: sonnet` from 15 founder extension agents
- Verify `Task tool` references and `.opencode/context/` paths
- Best done as part of task 636 (sync_context_rules_extensions_cleanup)

### Porting Approach for the Synthesis-Agent

| Adaptation Level | Method | Estimated Lines Changed |
|------------------|--------|-------------------------|
| Strip model field | Delete 1 line | 1 line |
| Verify allowed-tools | Read-through (no change) | 0 lines |
| Path substitution | `sed` `.claude/context/` -> `.opencode/context/` | ~5 substitutions |
| Add OpenCode-specific notes | Manual edit (e.g., "synthesis-agent runs in fresh context per OpenCode semantics") | ~5 lines added |
| Preserve content | Copy verbatim with substitutions | ~210 lines copied |

### Verification Plan

After porting:
1. **Frontmatter validation** — verify `name`, `description` are present, `model` is NOT present, `allowed-tools` is valid
2. **Path resolution check** — every `.opencode/context/` reference must point to an existing file
3. **Behavioral smoke test** — invoke the synthesis-agent manually with two synthetic teammate finding files; verify it produces a unified report and returns a ~200-word summary
4. **Skill integration test** — after Tier 2 rewiring, run a team-mode `/research` task and verify the synthesis-agent is dispatched (look for `Task(` tool call in trace)

### Risks and Considerations

1. **The .opencode/ skills currently do inline synthesis, which works**. Rewriting them to use the synthesis-agent could introduce regressions in the short term. The Team skill rewiring should be done carefully with extensive testing.

2. **The synthesis-agent is invoked via the `Task` tool with `subagent_type: "synthesis-agent"`**. The .opencode/ system supports this pattern (it's used by slides-research, deck-research, etc.). The new synthesis-agent file should be picked up automatically by the OpenCode agent loader.

3. **Model enforcement in OpenCode** is different from .claude/. Per agent-frontmatter-standard.md, OpenCode uses session model selection. The synthesis-agent in .opencode/ will run on the user's selected session model (likely Sonnet or Opus) rather than the explicit `sonnet` declared in .claude/ frontmatter. This is a desired behavior change.

4. **The synthesis-agent's `allowed-tools: Read, Write` restriction** must be preserved to maintain the "minimal tool surface" design. If the OpenCode allowed-tools syntax differs, the restriction must be adapted (e.g., `tools: {read: true, write: true}` per the `opencode-agents.json` pattern in present extension).

5. **The synthesis-agent is the same agent for research, plan, and implement workflows**. The .claude/ version's `workflow_type` parameter convention (mentioned in domain agent descriptions) may not be applicable — the synthesis-agent uses output path and team finding file paths to determine what to write, not a workflow_type parameter.

6. **Context-protective-lead principle documentation** (.claude/context/patterns/context-protective-lead.md) should be considered for porting to .opencode/context/patterns/. This is the design rationale for the synthesis-agent pattern. However, this is documentation, not a porting deliverable.

## Context Extension Recommendations

- **Topic**: OpenCode team-mode synthesis dispatch pattern
- **Gap**: The `.opencode/context/reference/team-wave-helpers.md` describes synthesis as an inline lead procedure (lines 232-281), contradicting the .claude/ pattern of dispatching a dedicated synthesis-agent. This documentation gap is the root cause of why .opencode/ team skills do inline synthesis instead of using a synthesis-agent.
- **Recommendation**: Update `.opencode/context/reference/team-wave-helpers.md` to add a "Synthesis Agent Dispatch" section (modeled on `.claude/context/reference/team-wave-helpers.md` lines 571-665) explaining how the lead forks the synthesis-agent. This documentation enables future porting of the team skills to use the synthesis-agent.

## Appendix

### Key File Paths

| Purpose | Path |
|---------|------|
| Source: core synthesis-agent | `.claude/agents/synthesis-agent.md` |
| Target: core synthesis-agent | `.opencode/agent/subagents/synthesis-agent.md` (to be created) |
| Source: domain synthesis agents (present) | `.claude/extensions/present/agents/slides-research-agent.md` |
| Source: domain synthesis agents (present) | `.claude/extensions/present/agents/slide-critic-agent.md` |
| Source: domain synthesis agents (founder) | `.claude/extensions/founder/agents/deck-research-agent.md` |
| Target: domain synthesis agents (present) | `.opencode/extensions/present/agents/` (already exists, needs frontmatter sweep) |
| Target: domain synthesis agents (founder) | `.opencode/extensions/founder/agents/` (already exists, needs frontmatter sweep) |
| Synthesis dispatch template (source) | `.claude/context/reference/team-wave-helpers.md` (lines 571-665) |
| Context-protective lead rationale | `.claude/context/patterns/context-protective-lead.md` |
| Team-mode research skill (source) | `.claude/skills/skill-team-research/SKILL.md` (lines 354-405) |
| Team-mode plan skill (source) | `.claude/skills/skill-team-plan/SKILL.md` (lines 327-385) |
| Team-mode implement skill (source) | `.claude/skills/skill-team-implement/SKILL.md` (lines 417-475) |
| Team-mode research skill (target) | `.opencode/extensions/core/skills/skill-team-research/SKILL.md` (uses inline synthesis, lines 344-379) |
| Team-mode plan skill (target) | `.opencode/extensions/core/skills/skill-team-plan/SKILL.md` (uses inline synthesis) |
| Team-mode implement skill (target) | `.opencode/extensions/core/skills/skill-team-implement/SKILL.md` (uses inline summary) |
| OpenCode agent frontmatter standard | `.opencode/docs/reference/standards/agent-frontmatter-standard.md` |
| OpenCode handoff schema (target) | `.opencode/extensions/core/context/formats/handoff-artifact.md` |

### Search Queries Used

- `ls .claude/agents/ .opencode/agent/subagents/` — inventory of core agents
- `ls .claude/extensions/*/agents/ .opencode/extensions/*/agents/` — inventory of domain agents
- `diff .claude/agents/synthesis-agent.md .opencode/agent/subagents/synthesis-agent.md` — synthesis-agent gap verification
- `diff .claude/agents/general-research-agent.md .opencode/agent/subagents/general-research-agent.md` — agent porting pattern reference
- `diff .claude/extensions/present/agents/slides-research-agent.md .opencode/extensions/present/agents/slides-research-agent.md` — domain agent porting pattern reference
- `grep "synthesis-agent" .claude/ .opencode/` — find all references to synthesis-agent across both systems
- `grep "Team research" .claude/skills/skill-team-research/SKILL.md` — team-research skill synthesis invocation
- `grep "synthesis" .opencode/extensions/core/skills/skill-team-research/SKILL.md` — confirm .opencode/ team skills do not use synthesis-agent
- `cat .opencode/docs/reference/standards/agent-frontmatter-standard.md` — OpenCode model field rules
- `head -10 .opencode/agent/subagents/*.md` — frontmatter sweep of .opencode/ core agents

### Adaptation Checklist for synthesis-agent Port

When porting `.claude/agents/synthesis-agent.md` to `.opencode/agent/subagents/synthesis-agent.md`:

- [ ] Copy 218-line source file
- [ ] Remove `model: sonnet` line from frontmatter
- [ ] Verify `allowed-tools: Read, Write` is valid OpenCode syntax (or convert to `tools: {read: true, write: true}` if needed)
- [ ] Replace `.claude/context/formats/report-format.md` with `.opencode/context/formats/report-format.md`
- [ ] Replace `.claude/context/formats/return-metadata-file.md` with `.opencode/context/formats/return-metadata-file.md`
- [ ] Verify both target format files exist in `.opencode/context/formats/`
- [ ] Verify `.opencode/context/repo/project-overview.md` exists (referenced in synthesis-agent context)
- [ ] Verify the agent file is loaded by the OpenCode agent loader (test with `Task(subagent_type: "synthesis-agent", ...)`)
- [ ] Run smoke test: invoke synthesis-agent with two simple finding files, verify it returns a unified output and ~200-word summary
- [ ] Update memory: capture the synthesis-agent porting pattern as a memory candidate
