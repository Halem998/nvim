# Implementation Plan: Task #675

- **Task**: 675 - lean4_extension_hard_mode_variants
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 669 (hard_mode_agent_system) - completed
- **Research Inputs**: specs/675_lean4_extension_hard_mode_variants/reports/01_lean4-hard-mode-research.md
- **Artifacts**: plans/01_lean4-hard-mode-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add hard-mode routing to the lean4 extension by creating 2 lean-specific hard agents, 2 hard skills, 2 lean-specific contract overrides, and updating the manifest/docs. The core hard-mode infrastructure from task 669 provides the behavioral contracts (H2, H3, H4, H5, H7, H9); this task layers lean4-specific overrides (lemma-to-source mapping, sorry inventory, divergence audit format) on top. No lean4 planner hard agent is needed -- the core planner-hard-agent handles lean4 tasks via the research agent's lemma-to-source table output.

### Research Integration

Key findings from the research report:
- 6 new files needed: 2 agents, 2 skills, 2 lean4-specific contracts
- 3 files to modify: manifest.json, EXTENSION.md, index-entries.json
- Lean4 hard agents inherit lean-specific rules (blocked tools, zero-debt, escalation) from base agents by including them inline, not via @-references to the base agent files
- Contract overrides go in `.claude/extensions/lean/context/contracts/` (new directory)
- Both hard agents use model: opus, consistent with base lean agents
- `routing_hard` only needs research and implement entries (no plan entry)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is internal agent system infrastructure supporting hard-mode lean4 development.

## Goals & Non-Goals

**Goals**:
- Create lean-research-hard-agent with H2, H3 (lean4 strict), H4, H5 (divergence audit)
- Create lean-implementation-hard-agent with H2, H9 (sorry inventory), single-phase focus
- Create lean4-specific reference-grounding and anti-analysis contract overrides
- Create skill-lean-research-hard and skill-lean-implementation-hard as thin wrappers
- Add `routing_hard` to the lean extension manifest.json
- Update EXTENSION.md and index-entries.json for discoverability

**Non-Goals**:
- Creating a lean4 planner hard agent (core planner-hard-agent is sufficient)
- Modifying the core hard-mode contracts (they already have lean4 specialization notes)
- Adding hard variants for utility skills (skill-lake-repair, skill-lean-version)
- Modifying the base lean agents or skills

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hard agents duplicate lean rules from base agents, creating maintenance burden | M | H | Include full lean-specific sections inline per research decision 4; document "mirror from base" in comments |
| H2 formal proof line bar too strict (20 tool calls may not be enough for lean4) | M | M | Anti-analysis override uses "first 30% of tool calls" instead of fixed count |
| Sorry inventory pollution (leaf sub-sorries misread as blockers by orchestrator) | M | L | H9 handoff schema distinguishes sorry_inventory from blockers; document in contracts |
| Contract override files not discovered by agents | M | L | Add load_when.agents entries in index-entries.json for both hard agents |
| provides.context and provides.skills omission | L | M | Explicitly add both in manifest.json modifications |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Lean4 Contract Overrides [COMPLETED]

**Goal**: Create the lean4-specific contract override files that hard agents will reference.

**Tasks**:
- [x] Create directory `.claude/extensions/lean/context/contracts/` *(completed)*
- [x] Create `reference-grounding.md` (~80 lines): lean4 Tier 1 override with lemma-level mapping table format (columns: Source | Prop/Location | Lean Identifier | Type Signature | Status), strict transcription discipline, sorry-inventory cross-reference, PDF section citation requirement *(completed)*
- [x] Create `anti-analysis.md` (~50 lines): lean4 H2 override adding formal proof line bar ("first sorry-free lemma within the first 30% of tool calls"), tightened forbidden conclusions for proof contexts (e.g., "this theorem needs a different approach" without a concrete type-mismatch), sub-sorry policy enforcement for leaf-only sorries *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to create**:
- `.claude/extensions/lean/context/contracts/reference-grounding.md` - Lean4-specific H3 override
- `.claude/extensions/lean/context/contracts/anti-analysis.md` - Lean4-specific H2 override

**Verification**:
- Both files exist and follow the format pattern from core contracts
- reference-grounding.md defines the lemma-level mapping table with all 5 columns
- anti-analysis.md defines the formal proof line bar and lean-specific forbidden conclusions

---

### Phase 2: Lean4 Hard Agents [COMPLETED]

**Goal**: Create the two lean4 hard agent definition files.

**Tasks**:
- [x] Create `lean-research-hard-agent.md` (~200 lines) in `.claude/extensions/lean/agents/`:
  - Frontmatter: name, description, model: opus
  - Overview: extends lean-research-agent with H2, H3 (lean4 strict), H4, H5
  - Context references: lean4 contract overrides via @-references, core reference-grounding.md for fallback
  - Blocked tools section (mirror from lean-research-agent: lean_diagnostic_messages, lean_file_outline)
  - Allowed tools section (mirror from lean-research-agent: all MCP tools, file ops, search tools)
  - Search decision tree (mirror from lean-research-agent)
  - Rate limit handling (mirror from lean-research-agent)
  - H2 anti-analysis enforcement section (lean4-specific: first MCP search yielding lemma candidate within 30% of tool calls)
  - H3 reference grounding section: Tier 1 mandatory for literature-backed tasks; output format is lemma-level mapping table
  - H4 adversarial self-verification section: mandatory post-research verification pass; ## Adversarial Self-Verification section in report
  - H5 divergence audit mode: triggered by focus_prompt containing "divergence" or "audit"; outputs sorry inventory table, type-mismatch analysis, divergence table (MATCHES/STRONGER/WEAKER/DIFFERENT), corrected Lean-ready targets, postmortem
  - Zero-debt policy for recommendations (mirror from lean-research-agent)
  - Execution flow stages (mirror structure from lean-research-agent, adding H-contract enforcement stages)
  *(completed)*
- [x] Create `lean-implementation-hard-agent.md` (~250 lines) in `.claude/extensions/lean/agents/`:
  - Frontmatter: name, description, model: opus
  - Overview: extends lean-implementation-agent with H2, H9, single-phase focus
  - Context references: lean4 contract overrides, core wrap-up.md contract
  - Blocked tools section (mirror from lean-implementation-agent)
  - Allowed tools section (mirror from lean-implementation-agent)
  - H2 anti-analysis section: formal proof line bar (first sorry-free lemma within 30% of tool calls); settled-design preamble protocol
  - Single-phase focus: when phase_number is set, implement only that phase
  - H9 sorry inventory tracking: populate sorry_inventory in handoff with leaf sub-sorries; each entry: {file, line, statement, assumption, why_deferred, next_dispatch}
  - H9 incremental commits: commit at each green-build milestone (aligns with existing phase-granular commit protocol)
  - Phase checkpoint protocol (mirror from lean-implementation-agent)
  - Escalation protocol (mirror from lean-implementation-agent)
  - Zero-debt policy (mirror from lean-implementation-agent: NO sorry in implemented status)
  - Final verification section: sorry/axiom/vacuous check with sorry_inventory population
  - Execution flow stages
  *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to create**:
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` - Lean4 hard research agent
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` - Lean4 hard implementation agent

**Verification**:
- Both files have correct frontmatter (name, description, model: opus)
- Both reference lean4 contract overrides via @-references
- Both include all lean-specific sections (blocked tools, zero-debt, search decision tree/phase checkpoint)
- lean-research-hard-agent includes H2, H3, H4, H5 sections
- lean-implementation-hard-agent includes H2, H9 sections with sorry_inventory schema
- Neither file @-references the base agent files (fully self-contained)

---

### Phase 3: Lean4 Hard Skills [COMPLETED]

**Goal**: Create the two lean4 hard skill wrappers.

**Tasks**:
- [x] Create directory `.claude/extensions/lean/skills/skill-lean-research-hard/` *(completed)*
- [x] Create `SKILL.md` in skill-lean-research-hard/ (~150 lines):
  - Frontmatter: name: skill-lean-research-hard, description, allowed-tools: Agent, Bash, Edit, Read, Write
  - Overview: thin wrapper delegating to lean-research-hard-agent; mirrors skill-lean-research postflight
  - Trigger conditions: /research N --hard for lean4 tasks, routed by command-route-skill.sh
  - Stage 1: Input validation (task_number, task_type check for lean4/lean)
  - Stage 1.5: Hard-mode cost note (session flag)
  - Stage 2: Preflight status update (researching)
  - Stage 3: Delegation context construction (task info, focus_prompt, session_id, effort_flag: hard)
  - Stage 4: Agent spawn (lean-research-hard-agent via Agent tool, subagent_type: lean-research-hard-agent, model: opus)
  - Stage 5: Postflight (read metadata, check adversarial_verification_triggered, status update, artifact linking, git commit)
  - MUST NOT section (mirror from skill-lean-research: no re-doing agent work in postflight)
  *(completed)*
- [x] Create directory `.claude/extensions/lean/skills/skill-lean-implementation-hard/` *(completed)*
- [x] Create `SKILL.md` in skill-lean-implementation-hard/ (~180 lines):
  - Frontmatter: name: skill-lean-implementation-hard, description, allowed-tools: Agent, Bash, Edit, Read, Write
  - Overview: thin wrapper delegating to lean-implementation-hard-agent with per-phase dispatch context; mirrors skill-lean-implementation postflight
  - Trigger conditions: /implement N --hard for lean4 tasks, or dispatched from skill-orchestrate-hard
  - Stage 1: Input validation (task_number, task_type check, terminal state check)
  - Stage 1.5: Hard-mode cost note
  - Stage 2: Preflight status update (implementing)
  - Stage 3: Plan resolution and phase identification (find latest plan, identify next incomplete phase; read handoff for per-phase dispatch context including territory)
  - Stage 4: Delegation context construction (plan_path, phase_number, territory, continuation_context)
  - Stage 5: Agent spawn (lean-implementation-hard-agent via Agent tool, model: opus)
  - Stage 6: Postflight (read metadata, read verification results from metadata, plan compliance check from metadata, sorry_inventory propagation to handoff, status update, artifact linking, git commit)
  - MUST NOT section (mirror from skill-lean-implementation)
  *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to create**:
- `.claude/extensions/lean/skills/skill-lean-research-hard/SKILL.md` - Hard research skill
- `.claude/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - Hard implementation skill

**Verification**:
- Both files have correct frontmatter (name, description, allowed-tools)
- skill-lean-research-hard dispatches to lean-research-hard-agent with model: opus
- skill-lean-implementation-hard dispatches to lean-implementation-hard-agent with model: opus
- Both skills include hard-mode cost note (Stage 1.5)
- skill-lean-implementation-hard includes per-phase dispatch logic (reading handoff for phase_number)
- Both skills include MUST NOT sections mirroring their base skill counterparts

---

### Phase 4: Manifest, Index, and Documentation Updates [COMPLETED]

**Goal**: Wire up routing, context discovery, and user-facing documentation for the new hard-mode artifacts.

**Tasks**:
- [x] Update `manifest.json`: add `routing_hard` key with research and implement entries for lean4; add new agents to `provides.agents` array; add new skills to `provides.skills` array; add `"contracts"` to `provides.context` array *(completed)*
- [x] Update `index-entries.json`: add 2 entries for the new contract files with `load_when.agents` pointing to `["lean-research-hard-agent", "lean-implementation-hard-agent"]` *(completed)*
- [x] Update `EXTENSION.md`: add "Lean Hard Mode" subsection with routing table, skill-agent mapping rows for the 2 hard agents (skill-lean-research-hard -> lean-research-hard-agent, skill-lean-implementation-hard -> lean-implementation-hard-agent), and note that /plan --hard uses core planner-hard-agent *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/lean/manifest.json` - Add routing_hard, provides entries
- `.claude/extensions/lean/index-entries.json` - Add contract context entries
- `.claude/extensions/lean/EXTENSION.md` - Add hard mode documentation section

**Verification**:
- `jq '.routing_hard' manifest.json` returns research and implement entries for lean4
- `jq '.provides.agents | length' manifest.json` shows 4 agents (2 base + 2 hard)
- `jq '.provides.skills | length' manifest.json` shows 6 skills (4 base + 2 hard)
- `jq '.entries | length' index-entries.json` shows original count + 2
- EXTENSION.md contains "Lean Hard Mode" section with routing table

## Testing & Validation

- [ ] Verify all 6 new files exist at their expected paths
- [ ] Verify manifest.json is valid JSON with correct routing_hard structure
- [ ] Verify index-entries.json is valid JSON with new entries
- [ ] Verify both agent files have valid frontmatter (name, description, model fields)
- [ ] Verify both skill files have valid frontmatter (name, description, allowed-tools fields)
- [ ] Verify contract files reference correct H-technique numbers
- [ ] Verify no @-references to base agent files in hard agent files (self-containment check)
- [ ] Verify EXTENSION.md hard mode section has correct skill-agent mapping

## Artifacts & Outputs

- `.claude/extensions/lean/context/contracts/reference-grounding.md` (new)
- `.claude/extensions/lean/context/contracts/anti-analysis.md` (new)
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` (new)
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` (new)
- `.claude/extensions/lean/skills/skill-lean-research-hard/SKILL.md` (new)
- `.claude/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` (new)
- `.claude/extensions/lean/manifest.json` (modified)
- `.claude/extensions/lean/index-entries.json` (modified)
- `.claude/extensions/lean/EXTENSION.md` (modified)

## Rollback/Contingency

All changes are within the `.claude/extensions/lean/` directory. Rollback by reverting the commit:
```bash
git revert <commit-hash>
```
No existing functionality is modified -- only new files are created and existing files receive additive changes. The base lean agents and skills remain untouched.
