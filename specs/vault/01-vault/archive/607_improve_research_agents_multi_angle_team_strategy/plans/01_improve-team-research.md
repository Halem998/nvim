# Implementation Plan: Improve Research Agents with Multi-Angle Team Research Strategy

- **Task**: 607 - Improve research agents with multi-angle team research strategy
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md (team research, 4 teammates)
- **Artifacts**: plans/01_improve-team-research.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan improves the team research infrastructure by fixing structural bugs (dead `team_size` parameter, misplaced Critic wave), adding domain context injection so team research is no longer worse than single-agent for domain tasks, and introducing optional `--exploit`/`--explore` mode hints and dynamic team sizing. It also adds prototype-first research guidance to general-research-agent and tactic discovery protocols to lean-research-agent. The plan covers Tiers 1 and 2 from the team research findings, deferring Tier 3 items (domain-specialized teammate roles, team profiles, auto-routing, structured decision matrices, measurement infrastructure) to future tasks.

### Research Integration

Team research report (4 teammates: Primary, Alternatives, Critic, Horizons) identified critical structural issues and validated the exploit/explore framework:
- **Critic found** `team_size` is dead code (hardcoded to 4 on line 73, ignoring input parameter)
- **Critic found** Critic role runs in Wave 1 alongside other teammates, so it cannot actually critique their findings
- **All teammates agreed** domain context injection is the single biggest gap -- team research bypasses domain extensions entirely
- **Literature validated** exploit/explore modes map to well-studied multi-agent exploration-exploitation tradeoffs
- **Critic warned** against over-engineering: flags should be optional hints, not mandatory workflow changes

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances "Agent System Quality" in Phase 1 of ROADMAP.md. While no specific roadmap items map directly, it improves agent runtime quality -- a natural progression after the current roadmap focus on static quality (linting, validation). The research recommends adding "Phase 3: Agent Runtime Quality" to ROADMAP.md, but that is deferred (Tier 3).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix `team_size` dead code so the parameter actually controls teammate count
- Move Critic to Wave 2 so it can read and critique Wave 1 findings
- Inject domain agent context and MCP tools into teammate prompts when task_type has an extension
- Add `--exploit` and `--explore` flags as optional mode hints for teammate role assignment
- Implement dynamic team sizing via effort flags (`--fast` = 2, default = 3, `--hard` = 4)
- Add `--team-size N` override support in the parser
- Add prototype-first research pattern guidance to general-research-agent
- Add tactic discovery survey protocol to lean-research-agent

**Non-Goals**:
- Domain-specialized teammate roles via extension manifest profiles (Tier 3)
- Named team profile configurations (Tier 3)
- Auto-routing with cost controls and circuit breakers (Tier 3)
- Structured decision matrices replacing prose synthesis (Tier 3)
- Measurement infrastructure for team vs single-agent quality comparison (Tier 3)
- Propagating exploit/explore beyond team-research to team-plan/team-implement (Tier 3)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wave 2 Critic adds latency to team research | M | H | Critic runs after Wave 1 completes; total time increases by one agent run (~2 min). Acceptable tradeoff for significantly better critique quality |
| Domain context injection bloats teammate prompts | M | M | Only inject relevant domain agent context, not entire extension tree. Use index.json filtering by task_type |
| New flags add parser complexity and test surface | L | L | Flags are optional hints with no behavioral change when absent. Parser already handles similar flags |
| Lean tactic changes are orthogonal to team infra | L | M | Separated into distinct phases (Phase 5 vs Phases 1-4). Can be deferred without blocking team improvements |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix Structural Bugs in SKILL.md [COMPLETED]

**Goal**: Fix `team_size` dead code and implement dynamic sizing via effort flags.

**Tasks**:
- [ ] Remove the hardcoded `team_size=4` on line 73 of SKILL.md that overrides the input parameter
- [ ] Implement dynamic sizing logic: if `effort_flag` is "fast" set `team_size=2`; if "hard" set `team_size=4`; otherwise default to `team_size=3`
- [ ] Honor `--team-size N` override from delegation context when explicitly provided (takes precedence over effort-derived size)
- [ ] Clamp final `team_size` to valid range [2, 4]
- [ ] Update the SKILL.md documentation header to reflect new defaults (default 3, not 2)
- [ ] Update conditional teammate spawning: only spawn Teammate D (Horizons) when `team_size >= 3`; only spawn Teammate B (Alternatives) when `team_size >= 2`
- [ ] Verify Critic (Teammate C) is always spawned regardless of team_size (moved to Wave 2 in Phase 3)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Fix dead code, add dynamic sizing logic, update conditional spawning

**Verification**:
- Reading SKILL.md shows no hardcoded `team_size=4`
- Dynamic sizing logic correctly maps effort flags to team sizes
- `--team-size N` override is documented and respected

---

### Phase 2: Add --exploit and --explore Flags to Parser [COMPLETED]

**Goal**: Add new flag parsing for `--exploit` and `--explore` mode hints.

**Tasks**:
- [ ] Add `EXPLOIT_FLAG` and `EXPLORE_FLAG` boolean variables (default "false") to parse-command-args.sh initialization block
- [ ] Add regex matching for `--exploit` and `--explore` flags in the flag scanning section
- [ ] Add `--exploit` and `--explore` to the sed strip chain that produces FOCUS_PROMPT
- [ ] Add both variables to the `export` statement
- [ ] Update the script header comment to document the new exported variables

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/parse-command-args.sh` - Add flag parsing for --exploit and --explore

**Verification**:
- Sourcing the script with `--exploit` sets `EXPLOIT_FLAG="true"`
- Sourcing the script with `--explore` sets `EXPLORE_FLAG="true"`
- Both flags are stripped from `FOCUS_PROMPT`
- Existing flags continue to work unchanged

---

### Phase 3: Wave 2 Critic and Domain Context Injection [COMPLETED]

**Goal**: Move Critic to Wave 2 (after reading other findings) and inject domain-specific agent context into teammate prompts.

**Tasks**:
- [ ] Restructure SKILL.md Stage 5 to spawn only Wave 1 teammates (A, B, D) in the initial spawn
- [ ] Add a new Stage 6a between current Stages 6 and 7: "Wait for Wave 1, Spawn Wave 2 Critic"
- [ ] In Stage 6a, after Wave 1 completes, collect teammate A/B/D output file paths
- [ ] Update Critic prompt (Teammate C) to include instruction: "Read the following teammate findings before critiquing:" followed by the file paths from Wave 1
- [ ] Spawn Critic as a Wave 2 agent with access to Wave 1 findings
- [ ] Update Stage 7 (Collect Results) to handle the two-wave pattern
- [ ] Add domain context injection logic to Stage 5b: when `task_type` matches a loaded extension, query `index.json` for domain agent context paths and available MCP tools
- [ ] Inject discovered domain context references and tool lists into each teammate prompt as a "Domain Context" section
- [ ] Update team-orchestration.md pattern documentation to reflect the two-wave model and domain injection

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Wave 2 Critic, domain context injection in Stage 5b
- `.claude/context/patterns/team-orchestration.md` - Update wave diagram and documentation

**Verification**:
- SKILL.md shows Critic spawning after Wave 1 completion
- Critic prompt includes paths to Wave 1 teammate findings
- Domain context injection logic queries index.json for matching task_type entries
- team-orchestration.md reflects updated wave model

---

### Phase 4: Exploit/Explore Mode Integration in SKILL.md [COMPLETED]

**Goal**: Wire the parsed `--exploit`/`--explore` flags into teammate prompt generation to shape role assignment.

**Tasks**:
- [ ] In SKILL.md Stage 5b, add mode detection: read `EXPLOIT_FLAG` and `EXPLORE_FLAG` from delegation context
- [ ] When `--exploit` is active: modify Teammate A prompt to emphasize "deep-dive into the most promising approach"; modify Teammate B prompt to "validate and stress-test the primary approach" rather than seeking alternatives; adjust Teammate D to "assess implementation feasibility"
- [ ] When `--explore` is active: modify Teammate A prompt to emphasize "breadth-first survey of all possible approaches"; modify Teammate B prompt to "investigate unconventional or creative alternatives"; adjust Teammate D to "identify approaches we haven't considered"
- [ ] When neither flag is set (default/mixed mode): keep current prompts unchanged
- [ ] Add mode information to the synthesis report header (e.g., "Mode: exploit" or "Mode: explore" or "Mode: default")
- [ ] Update team-orchestration.md with mode descriptions and usage guidance

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Mode-aware prompt generation
- `.claude/context/patterns/team-orchestration.md` - Document exploit/explore modes

**Verification**:
- With `--exploit`, teammate prompts emphasize depth and validation
- With `--explore`, teammate prompts emphasize breadth and creativity
- Without flags, prompts remain unchanged from current behavior
- Synthesis report includes mode designation

---

### Phase 5: Agent Prompt Enhancements (Prototype-First and Tactic Discovery) [COMPLETED]

**Goal**: Add prototype-first research guidance to general-research-agent and tactic discovery survey protocol to lean-research-agent.

**Tasks**:
- [ ] Add a "Prototype-First Research Pattern" section to general-research-agent.md after the Research Strategy Decision Tree
- [ ] The section should instruct agents to: (1) describe a minimal prototype or proof-of-concept before committing to an approach, (2) verify prototypes compile/work when feasible, (3) include prototype results in findings with clear pass/fail status
- [ ] Add a "Tactic Discovery Survey Protocol" section to lean-research-agent.md
- [ ] The protocol should instruct the agent to: (1) survey available tactics from the LeanHammer pipeline (aesop, lean-auto, zipperposition, duper) when investigating proof approaches, (2) use `lean_multi_attempt` to test candidate tactics against the proof goal, (3) report which tactics succeeded and with what premise budgets, (4) reference APOLLO decomposition pattern for recursive sub-goal decomposition
- [ ] Ensure the lean tactic survey is advisory guidance, not a mandatory step that blocks research progress

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Add prototype-first pattern section
- `.claude/extensions/lean/agents/lean-research-agent.md` - Add tactic discovery survey protocol

**Verification**:
- general-research-agent.md contains a "Prototype-First Research Pattern" section with clear instructions
- lean-research-agent.md contains a "Tactic Discovery Survey Protocol" section referencing LeanHammer and APOLLO
- Both additions are guidance sections that do not break existing agent flow

---

### Phase 6: Integration Testing and Documentation [COMPLETED]

**Goal**: Verify all changes work together and update cross-cutting documentation.

**Tasks**:
- [ ] Read all modified files end-to-end to verify internal consistency
- [ ] Verify SKILL.md flow: Stage 5b domain injection -> Wave 1 spawn (A, B, D) -> Wave 1 wait -> Wave 2 Critic spawn -> Collect all -> Synthesize
- [ ] Verify parse-command-args.sh exports `EXPLOIT_FLAG` and `EXPLORE_FLAG` alongside existing flags
- [ ] Verify dynamic sizing: no `--fast`/`--hard` -> team_size=3; `--fast` -> team_size=2; `--hard` -> team_size=4
- [ ] Update `.claude/CLAUDE.md` team mode table if default team size changed (currently says "Default team_size=2")
- [ ] Verify team-orchestration.md reflects: two-wave model, domain injection, exploit/explore modes
- [ ] Add a "Future Work (Tier 3)" section to team-orchestration.md listing deferred items: domain-specialized teammate roles, team profiles, auto-routing, structured decision matrices, measurement infrastructure

**Timing**: 30 minutes

**Depends on**: 3, 4, 5

**Files to modify**:
- `.claude/context/patterns/team-orchestration.md` - Add future work section
- `.claude/CLAUDE.md` - Update team mode documentation if defaults changed (auto-generated, may need merge-source update instead)

**Verification**:
- All modified files pass a consistency review
- No references to old defaults (team_size=2 as default, Wave 1 Critic) remain
- Future work section documents all Tier 3 items

## Testing & Validation

- [ ] Verify SKILL.md has no hardcoded `team_size=4` line
- [ ] Verify parse-command-args.sh correctly parses `--exploit`, `--explore`, `--team-size 3`
- [ ] Verify SKILL.md Wave 2 Critic spawns after Wave 1 collection
- [ ] Verify domain context injection queries index.json for task_type-matched entries
- [ ] Verify general-research-agent.md has prototype-first section
- [ ] Verify lean-research-agent.md has tactic discovery section
- [ ] Verify team-orchestration.md reflects all changes (two-wave, modes, domain injection)

## Artifacts & Outputs

- `specs/607_improve_research_agents_multi_angle_team_strategy/plans/01_improve-team-research.md` (this plan)
- Modified: `.claude/scripts/parse-command-args.sh`
- Modified: `.claude/skills/skill-team-research/SKILL.md`
- Modified: `.claude/context/patterns/team-orchestration.md`
- Modified: `.claude/agents/general-research-agent.md`
- Modified: `.claude/extensions/lean/agents/lean-research-agent.md`

## Rollback/Contingency

All changes are to markdown specification files and one bash script. If changes cause issues:
1. Revert individual files via `git checkout HEAD -- <path>` for any file that introduces problems
2. Phase 5 (agent prompt enhancements) is fully independent of Phases 1-4 and can be reverted without affecting team infrastructure
3. Phase 2 (parser flags) can be reverted independently since the flags are optional hints with no downstream hard dependencies
4. If Wave 2 Critic introduces unacceptable latency, revert Phase 3 Critic changes only (keep domain injection)
