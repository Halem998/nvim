# Implementation Plan: Task #676

- **Task**: 676 - cslib_extension_hard_mode_variants
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 669 (hard_mode_agent_system) -- completed
- **Research Inputs**: specs/676_cslib_extension_hard_mode_variants/reports/01_cslib-hard-mode-research.md
- **Artifacts**: plans/01_cslib-hard-mode-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add hard-mode routing to the cslib extension, making it the first extension to use the `routing_hard` manifest key. This involves creating 2 hard-mode agent files and 2 hard-mode skill directories within the cslib extension, then updating the manifest, EXTENSION.md, and index-entries.json to register them. The hard agents extend the base cslib agents with H-technique contracts (H2 anti-analysis, H3 reference grounding with citation conventions, H4 adversarial verification, H7 territory, H9 wrap-up with sorry_inventory), while the hard skills are thin wrappers that dispatch to the new agents and pass effort_flag and phase context.

### Research Integration

Key findings from the research report integrated into this plan:

1. **7 behavioral gaps justify cslib-specific hard agents** -- the domain gap between generic hard agents and cslib-aware hard agents is substantial (Reuse Check Protocol, zero-debt gate, lean_local_search, CI pipeline, citation conventions, Init imports, blocked tools).
2. **3 of 9 H-techniques need cslib-specific overrides** -- H2 (domain bar), H3 (BibKey/references.bib citation enforcement), H9 (sorry_inventory in handoff JSON). The remaining 6 are fully reusable from core contracts.
3. **No cslib contract override files needed** -- base contracts in `.claude/context/contracts/` are adequate; cslib hard agents @-reference them and add domain guidance in their own system prompts.
4. **`pr` task type routes to core hard skills** -- no domain gap for PR preparation tasks.
5. **`provides.skills` and `provides.agents` arrays in manifest.json must be updated** -- the loader copies files only from manifest entries; omitting these causes silent load failure.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. The task falls under general agent system quality improvements but is not explicitly listed.

## Goals & Non-Goals

**Goals**:
- Create cslib-research-hard-agent.md with H2+H3+H4 contracts and cslib domain knowledge
- Create cslib-implementation-hard-agent.md with H2+H7+H9 contracts and cslib domain knowledge
- Create skill-cslib-research-hard wrapper that dispatches to the hard research agent
- Create skill-cslib-implementation-hard wrapper that dispatches to the hard implementation agent
- Add `routing_hard` block to manifest.json with cslib and pr task-type entries
- Update `provides.agents` and `provides.skills` arrays in manifest.json
- Update EXTENSION.md with hard-mode skill-agent mapping rows and usage guidance
- Update index-entries.json with load conditions for hard agents

**Non-Goals**:
- Creating hard-mode variants for the lean4 extension (separate follow-up task)
- Modifying core contract files in `.claude/context/contracts/`
- Creating a cslib-specific planner-hard variant (core planner-hard suffices)
- Adding hard-mode support for the `pr` task type within cslib (routes to core hard skills)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `provides.skills`/`provides.agents` arrays not updated | H | M | Phase 1 explicitly includes manifest array updates; verify with jq after writing |
| Hard agents call blocked tools (lean_diagnostic_messages, lean_file_outline) | H | L | Carry forward BLOCKED TOOLS section verbatim from base cslib agents |
| EXTENSION.md hard-mode rows out of sync with agent files | M | L | Phase 2 writes agents, Phase 3 updates EXTENSION.md -- verify consistency |
| index-entries.json format mismatch with existing entries | M | L | Copy exact schema from existing cslib index-entries.json entries |
| Hard agents grow stale relative to base agents (maintenance drift) | M | M | Add explicit maintenance notes in each hard skill referencing base skill |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update manifest.json with routing_hard and provides arrays [COMPLETED]

**Goal**: Register the new hard-mode skills and agents in manifest.json so the extension loader and command router can discover them.

**Tasks**:
- [x] Add `routing_hard` block to manifest.json with research/plan/implement entries for both `cslib` and `pr` task types *(completed)*
- [x] Add `cslib-research-hard-agent.md` and `cslib-implementation-hard-agent.md` to `provides.agents` array *(completed)*
- [x] Add `skill-cslib-research-hard` and `skill-cslib-implementation-hard` to `provides.skills` array *(completed)*
- [x] Verify resulting JSON is valid with `jq empty manifest.json` *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - Add routing_hard block, update provides.agents and provides.skills arrays

**Verification**:
- `jq empty .claude/extensions/cslib/manifest.json` exits 0
- `jq '.routing_hard' .claude/extensions/cslib/manifest.json` shows research/plan/implement entries
- `jq '.provides.agents | length' .claude/extensions/cslib/manifest.json` returns 4
- `jq '.provides.skills | length' .claude/extensions/cslib/manifest.json` returns 5

---

### Phase 2: Create hard-mode agent files [COMPLETED]

**Goal**: Create the two cslib-specific hard-mode agent definition files that combine base cslib agent domain knowledge with hard-mode behavioral contracts.

**Tasks**:
- [x] Create `cslib-research-hard-agent.md` (~200 lines) extending base cslib-research-agent with:
  - Frontmatter: name, description, model: opus
  - @-references to anti-analysis.md (H2), reference-grounding.md (H3) contracts
  - Adversarial self-verification pass (H4): re-examine 3 most load-bearing claims
  - CSLib-specific H3 enrichment: BibKey verification against references.bib
  - All base agent constraints carried forward: blocked tools, reuse check, zero-debt, Lean MCP tools, rate limits *(completed)*
- [x] Create `cslib-implementation-hard-agent.md` (~280 lines) extending base cslib-implementation-agent with:
  - Frontmatter: name, description, model: sonnet
  - @-references to anti-analysis.md (H2), wrap-up.md (H9), territory.md (H7) contracts
  - Per-phase focus: expects phase_number in delegation context
  - Settled-Design Preamble Protocol from H2 contract
  - All base agent constraints carried forward: blocked tools, zero-debt, CI pipeline, escalation protocol *(completed)*
- [x] Verify both agent files reference the same base contracts (no divergence from lean4 formulation) *(completed)*
- [x] Verify BLOCKED TOOLS sections are present in both agent files *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to create**:
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` - Hard-mode research agent with H2+H3+H4
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` - Hard-mode implementation agent with H2+H7+H9

**Verification**:
- Both files exist and contain required frontmatter (name, description, model)
- Both files contain @-references to relevant contracts
- Both files carry forward BLOCKED TOOLS sections from base agents
- `grep -c "sorry" cslib-implementation-hard-agent.md` confirms sorry_inventory is mentioned

---

### Phase 3: Create hard-mode skill wrapper files [COMPLETED]

**Goal**: Create thin skill wrappers that dispatch to the new hard-mode agents and pass hard-mode delegation context.

**Tasks**:
- [x] Create `skill-cslib-research-hard/SKILL.md` (~90 lines) following skill-researcher-hard pattern:
  - Frontmatter: name, description, allowed-tools
  - Dispatches to cslib-research-hard-agent instead of cslib-research-agent
  - Passes effort_flag: "hard" in delegation context
  - Postflight logs adversarial_verification_triggered
  - Maintenance note referencing base skill-cslib-research *(completed)*
- [x] Create `skill-cslib-implementation-hard/SKILL.md` (~110 lines) following skill-implementer-hard pattern:
  - Frontmatter: name, description, allowed-tools
  - Dispatches to cslib-implementation-hard-agent instead of cslib-implementation-agent
  - Passes effort_flag: "hard" and phase_number in delegation context
  - Single-phase dispatch context (H1): reads .orchestrator-handoff.json
  - Includes territory params when non-null
  - Maintenance note referencing base skill-cslib-implementation *(completed)*
- [x] Verify both skill directories contain SKILL.md files *(completed)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to create**:
- `.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - Hard-mode research skill wrapper
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - Hard-mode implementation skill wrapper

**Verification**:
- Both SKILL.md files exist with correct frontmatter
- Both reference the correct hard-mode agent in their dispatch section
- Both include effort_flag: "hard" in delegation context
- `skill-cslib-implementation-hard` includes phase_number and territory handling

---

### Phase 4: Update EXTENSION.md and index-entries.json [COMPLETED]

**Goal**: Update documentation and context index to register the new hard-mode agents and skills for discovery and loading.

**Tasks**:
- [x] Add hard-mode rows to EXTENSION.md Skill-Agent Mapping table:
  - skill-cslib-research-hard -> cslib-research-hard-agent -> opus
  - skill-cslib-implementation-hard -> cslib-implementation-hard-agent -> sonnet *(completed)*
- [x] Add "When to use --hard for CSLib tasks" guidance section to EXTENSION.md *(completed)*
- [x] Add 2 new entries to index-entries.json for hard agent load conditions:
  - cslib-research-hard-agent.md with agents and task_types load conditions
  - cslib-implementation-hard-agent.md with agents and task_types load conditions *(completed)*
- [x] Verify index-entries.json is valid JSON after modification *(completed: 13 entries)*
- [x] Verify EXTENSION.md table alignment is correct *(completed)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` - Add hard-mode skill-agent rows and --hard usage guidance
- `.claude/extensions/cslib/index-entries.json` - Add load conditions for hard agents

**Verification**:
- `jq empty .claude/extensions/cslib/index-entries.json` exits 0
- `jq '.entries | length' .claude/extensions/cslib/index-entries.json` returns 13 (11 existing + 2 new)
- EXTENSION.md contains skill-cslib-research-hard and skill-cslib-implementation-hard rows
- EXTENSION.md contains "--hard" usage guidance section

## Testing & Validation

- [ ] `jq empty .claude/extensions/cslib/manifest.json` -- valid JSON
- [ ] `jq empty .claude/extensions/cslib/index-entries.json` -- valid JSON
- [ ] `jq '.routing_hard.research.cslib' .claude/extensions/cslib/manifest.json` returns "skill-cslib-research-hard"
- [ ] `jq '.routing_hard.implement.cslib' .claude/extensions/cslib/manifest.json` returns "skill-cslib-implementation-hard"
- [ ] `jq '.routing_hard.plan.cslib' .claude/extensions/cslib/manifest.json` returns "skill-planner-hard"
- [ ] All 4 new files exist in expected locations
- [ ] All 3 modified files preserve existing content while adding new entries
- [ ] Hard agents reference correct contract files via @-references
- [ ] Hard agents carry forward BLOCKED TOOLS from base agents
- [ ] Hard skills reference correct hard agents in dispatch sections
- [ ] citation-conventions.md (BibKey format) is referenced in research hard agent

## Artifacts & Outputs

- `.claude/extensions/cslib/manifest.json` (modified)
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (new)
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` (new)
- `.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` (new)
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` (new)
- `.claude/extensions/cslib/EXTENSION.md` (modified)
- `.claude/extensions/cslib/index-entries.json` (modified)

## Rollback/Contingency

All changes are within the `.claude/extensions/cslib/` directory. Rollback via:
1. `git checkout -- .claude/extensions/cslib/manifest.json .claude/extensions/cslib/EXTENSION.md .claude/extensions/cslib/index-entries.json` -- revert modifications
2. `rm -rf .claude/extensions/cslib/agents/cslib-*-hard-agent.md .claude/extensions/cslib/skills/skill-cslib-*-hard/` -- remove new files
3. No other files in the repository are affected; no schema migrations or state changes required.
