# Implementation Plan: Hard-Mode Routing and Agent System

- **Task**: 669 - hard_mode_agent_system
- **Status**: [NOT STARTED]
- **Effort**: 10.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md, specs/669_hard_mode_agent_system/reports/02_team-research.md
- **Artifacts**: plans/02_hard-mode-implementation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Plan Version**: 2 (revised 2026-06-12; incorporated user decisions on all 4 open design items, added Phase 7 for follow-up task creation)

## Overview

This plan implements the `--hard` flag as a behavioral routing mode that diverts `/research`, `/plan`, `/implement`, and `/orchestrate` to hard-mode skills calling hard-mode agents. Hard mode encodes nine techniques (H1-H9) distilled from the task-273 BimodalLogic session, organized as composable prompt-contract fragments in `.claude/context/contracts/` referenced by thin hard-mode skill wrappers and hard-mode agent variants. The routing infrastructure extends `command-route-skill.sh` with a fourth `effort_flag` argument and refactors the inline routing loops in research.md and plan.md to use the centralized script. The definition of done: `--hard` routes correctly to hard-mode skills for all four commands, graceful fallback operates when no hard variant exists, `--hard + --team` composes correctly (team skills inject hard-mode contracts into teammate prompts), a "when to use --hard" decision framework is documented, and follow-up tasks are created for extension-specific hard variants and testing.

### Research Integration

Two research reports inform this plan:

- **01_hard-mode-orchestration-approach.md**: The evidence base. Documents nine H-techniques derived from live orchestration of BimodalLogic task 273 (Lean 4). Provides the exact prompt contracts (H2 anti-analysis, H3 prior-art grounding, H7 territory, H9 wrap-up discipline) and structural patterns (H1 per-phase dispatch, H5 divergence audit, H6 convergence policing) to implement. Measured outcomes: per-phase dispatch + contracts moved implementation from 0 lines across 3 dispatches to 2,400+ lines across 13 dispatches.

- **02_team-research.md**: Architecture synthesis from 4 teammates. Key decisions: thin skill wrappers over shared contract fragments (not duplicated prompt text), 5 contracts + 4 hard skills + 3 hard agents = ~12 new files, phased rollout targeting H1+H2 first for ~80% value. Confirmed `effort_flag` plumbing is complete everywhere but is a total no-op -- no skill branches on it.

### Prior Plan Reference

No prior plan. This is plan version 2 (revision of version 1 incorporating user design decisions).

### Roadmap Alignment

No current ROADMAP.md items directly correspond to hard-mode routing. This is new infrastructure that may generate future roadmap items (e.g., extension-specific hard variants for lean4, z3).

## Settled Decisions

The following design decisions have been resolved by the user (revision of 2026-06-12):

1. **No sticky hard mode (per-invocation only)**: `--hard` must be passed explicitly each invocation. There is no `effort_mode` field in state.json and no per-task persistence of the hard flag. This is an explicit user decision: hard mode is a per-invocation behavioral modifier, not a task attribute.

2. **skill-orchestrate-hard is a full structural variant**: Confirmed. The ~600-800 line full variant encodes H1 (per-phase dispatch), H4 (adversarial verification gate), H5 (divergence audit), H6 (convergence policing). This is NOT a thin wrapper -- loop-level changes cannot be expressed as prompt injection into the existing skill-orchestrate.

3. **Token cost documentation in scope**: Confirmed. Document 3-5x hard-mode cost and ~15-25x `--team --hard` cost in CLAUDE.md (Phase 6).

4. **`routing_hard` manifest key infrastructure only**: This plan creates the infrastructure for extensions to declare hard-mode routing via a `routing_hard` sibling key in manifests. No extension uses it in this task -- lean4/cslib hard variants are deferred to follow-up tasks (created in Phase 7).

## Goals & Non-Goals

**Goals**:
- Implement `--hard` routing in all four commands (research, plan, implement, orchestrate)
- Create 5 composable prompt-contract files encoding H-techniques
- Create 4 thin hard-mode skill wrappers
- Create 3 hard-mode agent variants with @-referenced contracts
- Refactor inline routing in research.md and plan.md to use centralized command-route-skill.sh
- Enable `--hard + --team` composability (team skills inject hard-mode contracts when effort_flag="hard")
- Implement graceful fallback (no hard variant exists -> silent degradation to standard)
- Document "when to use --hard" decision framework in CLAUDE.md
- Document token cost multipliers (3-5x hard, 15-25x team+hard) in CLAUDE.md
- Update context index with new contract files
- Create follow-up tasks for extension hard variants, contract testing, and auto-escalation advisory

**Non-Goals**:
- Extension-specific hard variants (lean4, nix, neovim, cslib) -- deferred to follow-up tasks created in Phase 7
- Sticky `effort_mode` in state.json -- explicitly rejected by user decision; hard mode is per-invocation only
- Adaptive auto-escalation (churn detection -> auto --hard suggestion) -- deferred to follow-up task (v2 trajectory)
- Contract lint or automated testing of hard-mode behavioral correctness -- deferred to follow-up task
- Modifying the `--fast` flag behavior (remains as-is)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| skill-orchestrate-hard diverges from skill-orchestrate over time | H | M | Both files share @-references to handoff schema and state machine docs; add a comment header noting the relationship |
| Hard-mode contracts are too Lean-specific for general tasks | M | M | Write all contracts in domain-agnostic language first, with domain-specific sections clearly labeled for extension override |
| --hard + --team token cost surprises users | M | H | Document cost multiplier in CLAUDE.md and emit a one-time note when --hard is first used in a session |
| Routing refactor in research.md/plan.md breaks existing extension routing | H | L | The centralized script already handles the exact same logic; test with `jq` manifest queries before and after |
| Hard agent files accumulate duplication with base agents | M | M | Hard agents reference contracts via @-syntax (~10-20 lines of references) rather than duplicating contract text; maintenance point is the contract file |
| Follow-up tasks created with stale report references | L | L | Phase 7 embeds absolute report paths and task 669 dependency; reports are immutable once task completes |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

This plan is fully sequential due to the layered dependency chain: routing infrastructure -> contracts -> agents -> skills -> team composability -> documentation -> follow-up task creation.

---

### Phase 1: Routing Infrastructure and Command Refactoring [COMPLETED]

**Goal**: Extend `command-route-skill.sh` with hard-mode routing logic and refactor all four commands to use it, establishing the plumbing so that `--hard` correctly resolves to hard-mode skill names (even though those skills do not exist yet -- the graceful fallback will fire).

**Tasks**:
- [x] Extend `.claude/scripts/command-route-skill.sh` to accept a 4th argument `$4 = effort_flag` *(completed)* (default empty for backward compatibility). When `effort_flag="hard"`: (a) check `routing_hard.$operation.$task_type` in each extension manifest before standard routing; (b) if no extension hard variant found, construct candidate name by appending `-hard` to the resolved skill name (e.g., `skill-researcher` -> `skill-researcher-hard`); (c) check if `.claude/skills/${candidate}/SKILL.md` exists; (d) if it exists, use it; if not, fall back to the standard skill with a stderr note: `[route] No hard variant for $skill_name; using standard skill`
- [x] Refactor `.claude/commands/research.md` STAGE 2: Replace the inline routing loop (lines 333-366) *(completed)* with: `source .claude/scripts/command-route-skill.sh "research" "$TASK_TYPE" "skill-researcher" "$EFFORT_FLAG"` followed by `skill_name="$SKILL_NAME"`. This removes ~35 lines of inline routing. Preserve the team-mode check above this block (team-mode takes precedence). Add a guard: if `TEAM_MODE="true"` AND `EFFORT_FLAG="hard"`, set a `hard_team_mode=true` variable and pass it through to the team skill invocation
- [x] Refactor `.claude/commands/plan.md` STAGE 2: Same pattern as research.md -- replace inline routing loop (lines 337-370) *(completed)* with `source command-route-skill.sh "plan" "$TASK_TYPE" "skill-planner" "$EFFORT_FLAG"`. Preserve team-mode precedence. Add the `hard_team_mode` pass-through for --team --hard
- [x] Update `.claude/commands/implement.md` STAGE 2 (line 125): Add `"$EFFORT_FLAG"` as 4th argument *(completed)* to the existing `command-route-skill.sh` call. Add the `hard_team_mode` pass-through for --team --hard
- [x] Update `.claude/commands/orchestrate.md` STAGE 0: Source `parse-command-args.sh` *(completed)* (currently not sourced -- orchestrate does its own parsing). Extract `EFFORT_FLAG`. In STAGE 1b routing, when `EFFORT_FLAG="hard"`, append `-hard` to resolved agent names (e.g., `general-research-agent` -> `general-research-hard-agent`) and set a flag to route to `skill-orchestrate-hard` for the implementation loop
- [x] Add `effort_flag` pass-through in all four commands' Skill tool invocation args strings *(completed)* (e.g., `effort_flag={EFFORT_FLAG}`)

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/command-route-skill.sh` -- Add $4 effort_flag, routing_hard manifest lookup, -hard suffix construction, fallback logic (~40 new lines)
- `.claude/commands/research.md` -- Replace lines 333-366 with 5-line routing call, add hard_team_mode pass-through (~net -25 lines)
- `.claude/commands/plan.md` -- Replace lines 337-370 with 5-line routing call, add hard_team_mode pass-through (~net -25 lines)
- `.claude/commands/implement.md` -- Add $EFFORT_FLAG to line 125 call, add hard_team_mode pass-through (~3 lines changed)
- `.claude/commands/orchestrate.md` -- Source parse-command-args.sh, extract EFFORT_FLAG, add hard-mode agent name suffix logic in Stage 1b (~15 new lines)

**Verification**:
- Manually trace: `command-route-skill.sh "research" "general" "skill-researcher" "hard"` should resolve to `skill-researcher-hard` if `.claude/skills/skill-researcher-hard/SKILL.md` exists, else fall back to `skill-researcher` with stderr note
- Verify existing routing unchanged: `command-route-skill.sh "research" "general" "skill-researcher" ""` produces `skill-researcher`
- Verify existing 3-argument calls still work (backward compat): `command-route-skill.sh "research" "general" "skill-researcher"` produces `skill-researcher`

---

### Phase 2: Prompt Contract Files [COMPLETED]

**Goal**: Create the 5 composable prompt-contract fragments that encode the H-techniques as domain-agnostic context files. These are the shared behavioral building blocks that hard-mode agents and skills reference via @-syntax.

**Tasks**:
- [x] Create `.claude/context/contracts/anti-analysis.md` (~60-80 lines): H2 anti-analysis contract. *(completed)* Sections: Read Budget (<=15-20% of effort on reading, first file edit must happen early), Forbidden Conclusions (list of analysis-paralysis signatures: "the approach is wrong", "a different representation is needed", "estimated N lines" as final answer), Defect Bar (agent may claim design is defective ONLY with a concrete counterexample stated verbatim), Sub-Sorry Policy (tightly-scoped documented leaf sub-sorries acceptable; main target is not), Settled-Design Preamble Protocol (restate decided design; name ruled-out alternatives). Write in domain-agnostic language. Include a "Domain Specialization" section at the end noting that formal verification domains (lean4, z3) may override with stricter versions
- [x] Create `.claude/context/contracts/reference-grounding.md` (~60-80 lines): Domain-agnostic reformulation of H3. *(completed)* Three tiers: (1) Literature-backed domains -- mandatory source-to-implementation mapping table (source, proposition/page -> local identifier), transcription discipline (source wins over instinct), PDF-level reading for load-bearing claims; (2) Documentation-backed domains -- official docs, API specs, changelogs as authoritative references, link-to-implementation mapping; (3) Implementation-backed domains -- reference code and test suites as specifications. Include guidance on when each tier applies
- [x] Create `.claude/context/contracts/convergence.md` (~40-50 lines): H6 convergence policing. *(completed)* Sections: Progress Criterion Declaration (orchestrator states the criterion before dispatch), Churn Signatures (same target moved, repeated "wrong approach" verdicts, inflating estimates), Three-Strikes Rule (3 churn signatures -> divergence audit H5 instead of another implement dispatch), User-Authorization Requirement (architectural pivots require explicit user decision via AskUserQuestion, presented with options)
- [x] Create `.claude/context/contracts/territory.md` (~40-50 lines): H7 territory contract for parallel dispatch. *(completed)* Sections: File Territory (explicit file list per agent, read-only references to other files), Plan-Section Territory (edit only your phase's checkboxes), Commit Protocol (on non-fast-forward: rebase onto HEAD, re-verify build, then commit), Handoff Merge Rule (read-merge-write for shared state files like .orchestrator-handoff.json, never clobber)
- [x] Create `.claude/context/contracts/wrap-up.md` (~50-60 lines): H9 handoff and commit discipline. *(completed)* Sections: Orchestrator Handoff JSON Schema (<=400 tokens; fields: status, phases_completed, sorry_inventory, blockers with verbatim goals, continuation_path), Continuation Handoff Markdown (verbatim remaining goals, what was tried, next-steps list), Incremental Commit Discipline (commit at every green-build milestone, never one commit at end), Build-Green Invariant (module builds at every commit, regressions in completed work are forbidden)
- [x] Update `.claude/context/index.json`: Add entries for all 5 contract files. *(completed)* Set `load_when.agents` to the hard-mode agent names (to be created in Phase 3). Set `load_when.always` to false. Use category "contracts" and appropriate line counts

**Timing**: 1.5 hours

**Depends on**: Phase 1 (contracts need to know the exact agent names that will reference them, determined by routing conventions established in Phase 1)

**Files to create**:
- `.claude/context/contracts/anti-analysis.md` (~70 lines)
- `.claude/context/contracts/reference-grounding.md` (~70 lines)
- `.claude/context/contracts/convergence.md` (~45 lines)
- `.claude/context/contracts/territory.md` (~45 lines)
- `.claude/context/contracts/wrap-up.md` (~55 lines)

**Files to modify**:
- `.claude/context/index.json` -- Add 5 new entries (~30 lines of JSON)

**Verification**:
- Each contract file is self-contained, has clear section headings, uses domain-agnostic language
- Index entries are valid JSON (run `jq '.' .claude/context/index.json` to validate)
- Contracts reference H-technique numbers for traceability (e.g., "This contract implements H2")

---

### Phase 3: Hard-Mode Agent Variants [COMPLETED]

**Goal**: Create the 3 hard-mode agent files that bake in contract references via @-syntax and add agent-level behavioral modifications. These are the agents that hard-mode skills will dispatch to.

**Tasks**:
- [x] Create `.claude/agents/general-research-hard-agent.md` (~200-230 lines): *(completed)* Copy the structure (not verbatim content) of `general-research-agent.md` (282 lines). Add Context References: `@.claude/context/contracts/reference-grounding.md`, `@.claude/context/contracts/anti-analysis.md`. Behavioral additions: (1) After report creation, mandatory adversarial verification pass (H4) -- agent re-reads its own report with an adversarial mandate, appends a `## Adversarial Self-Verification` section flagging uncertain claims; (2) Reference grounding requirement (H3 general form) -- all load-bearing claims must cite a specific source; (3) Divergence-audit mode when `focus_prompt` contains "divergence" or "audit" (H5) -- outputs divergence table, postmortem, corrected target. Model: sonnet (same as base). Frontmatter: `name: general-research-hard-agent`, `model: sonnet`
- [x] Create `.claude/agents/planner-hard-agent.md` (~250-280 lines): *(completed)* Use `planner-agent.md` (340 lines) as structural reference. Add Context References: `@.claude/context/contracts/reference-grounding.md`, `@.claude/context/formats/plan-format.md`. Behavioral additions: (1) Phase sizing constraint (H8) -- each phase must be completable in one agent run, ~100-500 lines of output; large phases must be split into sub-phases; (2) Postmortem-constraints section in the plan -- hard "do not" rules distilled from prior failures, binding on all implementers; (3) Preserved-assets accounting -- list what is complete and must not regress; (4) Source-to-implementation mapping table when reference materials exist (H3/H8); (5) Dependency wave declarations with explicit parallel opportunities (H7 enabler). Model: opus (plan quality benefits from deeper reasoning). Frontmatter: `name: planner-hard-agent`, `model: opus`
- [x] Create `.claude/agents/general-implementation-hard-agent.md` (~250-280 lines): *(completed)* Use `general-implementation-agent.md` (476 lines) as structural reference. Add Context References: `@.claude/context/contracts/anti-analysis.md`, `@.claude/context/contracts/wrap-up.md`, `@.claude/context/contracts/territory.md`. Behavioral additions: (1) Anti-analysis contract baked in (H2) -- the highest single-dispatch value change from Report 01; (2) Wrap-up contract for handoff discipline (H9) -- every run ends with orchestrator handoff JSON and incremental commits; (3) Territory awareness (H7) -- when dispatch context includes territory parameters, honor file boundaries and commit protocol; (4) Single-phase focus -- agent expects to receive exactly one phase (or sub-phase) and completes it, not the whole plan. Model: sonnet (same as base). Frontmatter: `name: general-implementation-hard-agent`, `model: sonnet`
- [x] Update `.claude/context/index.json`: Verify the agent names in contract load_when.agents arrays match the created agent filenames *(completed — agent names match)*

**Timing**: 2 hours

**Depends on**: Phase 2 (agents reference contracts via @-syntax; contract files must exist first)

**Files to create**:
- `.claude/agents/general-research-hard-agent.md` (~220 lines)
- `.claude/agents/planner-hard-agent.md` (~270 lines)
- `.claude/agents/general-implementation-hard-agent.md` (~270 lines)

**Files to modify**:
- `.claude/context/index.json` -- Verify/update agent name references (~5 lines changed)

**Verification**:
- Each agent file has correct frontmatter (name, description, model)
- Each agent's Context References section lists the correct contract @-references
- The Research Strategy Decision Tree / Execution Flow from base agents is preserved (not lost)
- Agent names match the naming convention used in Phase 1's routing logic (e.g., `general-research-agent` -> `general-research-hard-agent`)

---

### Phase 4: Hard-Mode Skill Wrappers [COMPLETED]

**Goal**: Create the 4 thin hard-mode skill files that serve as routing targets. Each is a thin wrapper that dispatches to the corresponding hard-mode agent, with the contracts composed via @-references in the agent prompt. The orchestrate-hard skill is the exception -- it is a full structural variant encoding H1, H4, H5, and H6 (confirmed by user decision).

**Tasks**:
- [x] Create `.claude/skills/skill-researcher-hard/SKILL.md` (~150-170 lines): Thin wrapper. *(completed)* Frontmatter: `name: skill-researcher-hard`, `allowed-tools: Agent, Bash, Read`. Context References: contracts/anti-analysis.md, contracts/reference-grounding.md. Execution: same preflight lifecycle as skill-researcher (parse delegation context, validate task, create early metadata). Delegate to `general-research-hard-agent` via Agent tool. Postflight: after agent returns, log whether adversarial verification was triggered (present in report as `## Adversarial Self-Verification`). Standard postflight metadata write
- [x] Create `.claude/skills/skill-planner-hard/SKILL.md` (~130-150 lines): Thin wrapper. *(completed)* Frontmatter: `name: skill-planner-hard`, `allowed-tools: Agent, Bash, Read, Edit`. Delegate to `planner-hard-agent`. Pass H8 plan requirements in delegation context (phase sizing constraint, postmortem-constraints requirement). Standard lifecycle
- [x] Create `.claude/skills/skill-implementer-hard/SKILL.md` (~150-170 lines): Thin wrapper. *(completed)* Frontmatter: `name: skill-implementer-hard`, `allowed-tools: Agent, Bash, Read, Edit, Write`. Key difference from standard: when `orchestrator_mode=true`, passes single-phase dispatch context (reads from handoff JSON or plan to identify the next incomplete phase) rather than whole-plan context. When territory parameters are present (from orchestrate-hard parallel dispatch), includes them in the agent prompt. Delegates to `general-implementation-hard-agent`
- [x] Create `.claude/skills/skill-orchestrate-hard/SKILL.md` (~600-800 lines): Full structural variant *(completed)* (confirmed by settled decision 2). This is NOT a thin wrapper -- it encodes the hard-mode orchestration loop. Frontmatter: `name: skill-orchestrate-hard`, `allowed-tools: Agent, Bash, Read, Edit`. Core differences from skill-orchestrate: (1) **Per-phase dispatch loop (H1)**: Read plan phase markers + handoff -> dispatch next incomplete phase (or parallel wave) -> process handoff -> commit -> repeat. Cycle = one phase attempt, not one whole-plan attempt; (2) **Prompt assembly with contract slots**: Mission (one phase), Settled Design preamble (H2), Foundations Available (completed work to cite not reprove), Literature Anchors (H3 if applicable), Anti-Analysis Rules (H2 contract @-ref), Territory (H7 contract @-ref when parallel), Wrap-up Contract (H9 @-ref); (3) **Churn detection state (H6)**: Track `defect_claims` and `sorry_relocations` counters per target. Three strikes triggers divergence audit (H5 research dispatch) instead of another implement dispatch; (4) **Adversarial verification gate (H4)**: Research -> adversarial verify -> then plan/implement. Never implement off an unverified load-bearing report; (5) **Escalation ladder update**: existing continuation -> blocker research -> plan revision -> re-dispatch ladder, plus audit (H5) between "escalation cap reached" and "give up", plus architectural pivots require AskUserQuestion; (6) **Agent routing**: Use hard-mode agents for all dispatches within the loop (research-hard-agent, planner-hard-agent, implementation-hard-agent)

**Timing**: 3 hours (skill-orchestrate-hard accounts for 2 hours; the 3 thin wrappers account for 1 hour)

**Depends on**: Phase 2 (contracts must exist for @-references), Phase 3 (agents must exist to be dispatched to)

**Files to create**:
- `.claude/skills/skill-researcher-hard/SKILL.md` (~160 lines)
- `.claude/skills/skill-planner-hard/SKILL.md` (~140 lines)
- `.claude/skills/skill-implementer-hard/SKILL.md` (~160 lines)
- `.claude/skills/skill-orchestrate-hard/SKILL.md` (~700 lines)

**Verification**:
- Each skill directory contains a SKILL.md with correct frontmatter
- Thin wrappers delegate to the correct hard agent by name
- skill-orchestrate-hard contains per-phase dispatch loop (not whole-plan dispatch)
- skill-orchestrate-hard references churn counters (defect_claims, sorry_relocations)
- skill-orchestrate-hard includes adversarial verification gate before implementation dispatch
- All four skills have standard preflight/postflight lifecycle patterns (early metadata, final metadata)

---

### Phase 5: Team-Mode Hard Composability and Graceful Fallback [COMPLETED]

**Goal**: Enable `--hard + --team` composability so that team skills inject hard-mode contracts into teammate prompts when `effort_flag="hard"`. Also verify and document the graceful fallback behavior for commands that have no hard variant.

**Tasks**:
- [x] Update `.claude/skills/skill-team-research/SKILL.md`: When `effort_flag="hard"`, *(completed)* modify the teammate dispatch prompt to include: (1) a preamble line "This is a HARD-MODE research dispatch. The following contracts are mandatory:" (2) inline the essential contract requirements from anti-analysis.md and reference-grounding.md (not the full files -- a 10-line summary of the key rules); (3) set `subagent_type` to `general-research-hard-agent` for each teammate if that agent exists, otherwise use standard agent
- [x] Update `.claude/skills/skill-team-plan/SKILL.md`: Same pattern -- when `effort_flag="hard"`, *(completed)* modify teammate prompts to enforce H8 plan requirements (phase sizing, postmortem-constraints, preserved-assets), use `planner-hard-agent` for teammates
- [x] Update `.claude/skills/skill-team-implement/SKILL.md`: When `effort_flag="hard"`, *(completed)* inject anti-analysis contract summary into teammate prompts, use `general-implementation-hard-agent` for teammates, pass territory contract awareness for parallel phases
- [x] Verify graceful fallback: Test that commands without hard variants *(completed — verified by routing script test in Phase 1)* (e.g., `/todo --hard`, `/review --hard`, `/refresh --hard`) silently ignore the flag. Since `--hard` is parsed into `EFFORT_FLAG` by `parse-command-args.sh` but only acts when `command-route-skill.sh` is called with it, commands that don't call the routing script naturally ignore it. Document this behavior
- [x] Add a one-time note emission: When `--hard` is first detected *(completed — added to each hard skill's Stage 1.5 via session flag file)* in a session by any command, emit a note to stderr: `[hard-mode] Hard mode active. Cost: ~3-5x standard. Use --hard for deflection-prone or formally complex tasks.` This note fires once per session (track via a session-scoped flag or temp file)

**Timing**: 1.5 hours

**Depends on**: Phase 4 (hard skills and agents must exist for the team skills to reference)

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` -- Add effort_flag="hard" branch in teammate dispatch (~20 lines added)
- `.claude/skills/skill-team-plan/SKILL.md` -- Add effort_flag="hard" branch (~15 lines added)
- `.claude/skills/skill-team-implement/SKILL.md` -- Add effort_flag="hard" branch (~20 lines added)
- One of: `.claude/scripts/command-route-skill.sh` or a new helper for the one-time note (~10 lines)

**Verification**:
- `/research N --team --hard` routes to skill-team-research with effort_flag="hard", and each teammate uses hard-mode agent/prompts
- `/implement N --team --hard` routes to skill-team-implement with hard-mode injection
- `/todo --hard` silently runs as `/todo` (graceful fallback -- no error, no behavioral change)
- The one-time cost note appears on first --hard usage, not on subsequent uses in the same session

---

### Phase 6: Documentation and CLAUDE.md Updates [COMPLETED]

**Goal**: Update all documentation to reflect the new hard-mode system: CLAUDE.md skill-to-agent mapping, command reference, routing tables, token cost documentation, and a "when to use --hard" decision framework.

**Tasks**:
- [x] Update `.claude/CLAUDE.md` Skill-to-Agent Mapping table: Add 4 new rows for hard-mode skills (skill-researcher-hard -> general-research-hard-agent, skill-planner-hard -> planner-hard-agent, skill-implementer-hard -> general-implementation-hard-agent, skill-orchestrate-hard -> (direct execution)) *(completed)*
- [x] Update `.claude/CLAUDE.md` Agents table: Add 3 new rows for hard-mode agents *(completed)*
- [x] Update `.claude/CLAUDE.md` Command Reference: Note that --hard routes to hard-mode skills when available, with graceful fallback when not *(deviation: altered — command ref already shows --hard in usage; Hard Mode section covers routing and fallback)*
- [x] Add a new section to `.claude/CLAUDE.md`: "## Hard Mode (`--hard`)" with: (a) What hard mode does (behavioral contracts, per-phase dispatch, convergence policing); (b) When to use --hard (decision framework): use when the task has 2+ plan versions, when previous attempts produced analysis-only output with no code, when the task involves formal verification (lean4, z3), when working from a literature base requiring faithful transcription, when a task has been stuck in IMPLEMENTING for 3+ dispatch cycles; (c) Cost impact (~3-5x standard, ~15-25x with --team --hard); (d) Composability: --hard works with --team (each teammate gets hard-mode contracts), works with model flags (--hard --opus), works with extension routing (routing_hard manifest key); (e) Graceful fallback: commands without hard variants silently use standard behavior; (f) Explicit note: --hard is per-invocation only, not sticky per-task *(completed)*
- [x] Update `.claude/context/guides/extension-development.md`: Document the optional `routing_hard` key in extension manifests. Same structure as `routing` but activated when effort_flag="hard". Extensions that don't provide `routing_hard` automatically fall back to core hard-mode skills *(completed)*
- [x] Regenerate `.claude/CLAUDE.md` if it is generated from merge sources (check the generation mechanism) *(completed: merge-sources/claudemd.md was already updated in previous phases; applied diff to CLAUDE.md directly)*

**Timing**: 1 hour

**Depends on**: Phase 5 (all behavioral changes must be complete before documenting)

**Files to modify**:
- `.claude/CLAUDE.md` -- Add hard-mode skill/agent/command documentation, cost documentation (~60 lines added)
- `.claude/context/guides/extension-development.md` -- Document `routing_hard` manifest key (~20 lines added)

**Verification**:
- CLAUDE.md Skill-to-Agent Mapping table includes all 4 hard skills
- CLAUDE.md Agents table includes all 3 hard agents
- "When to use --hard" section has 5 clear bullet-point heuristics
- Token cost documentation explicitly states 3-5x hard and 15-25x team+hard
- Hard Mode section notes per-invocation-only behavior (no sticky mode)
- extension-development.md documents routing_hard with a manifest.json example

---

### Phase 7: Follow-Up Task Creation [COMPLETED]

**Goal**: Create follow-up task entries in `specs/state.json` for deferred work identified during this task. Each follow-up task references task 669 and its research reports as inputs, enabling implementing agents to consult the hard-mode evidence base.

**Tasks**:
- [x] Create follow-up task A in state.json: **lean4 extension hard-mode variants**. Description: "Add hard-mode routing to the lean4 extension: `routing_hard` manifest entries, skill-lean-research-hard, skill-lean-implementation-hard, lean hard agents with H3 strict transcription mandate, H5 formal divergence audit, H8 lemma-to-source mapping, H9 sorry inventory. Research inputs: specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md, specs/669_hard_mode_agent_system/reports/02_team-research.md." Set status "not_started", task_type "meta", add dependency on task 669 *(completed: task 675)*
- [x] Create follow-up task B in state.json: **cslib extension hard-mode variants**. Description: "Add hard-mode routing to the cslib extension following the same pattern as lean4: routing_hard manifest entries, skill-cslib-research-hard, skill-cslib-implementation-hard, cslib hard agents with domain-specific H-technique overrides. Research inputs: specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md, specs/669_hard_mode_agent_system/reports/02_team-research.md." Set status "not_started", task_type "meta", add dependency on task 669 *(completed: task 676)*
- [x] Create follow-up task C in state.json: **contract lint and testing strategy**. Description: "Design and implement a testing strategy for hard-mode behavioral correctness: contract lint rules that verify agents honor anti-analysis budgets, reference grounding requirements, and convergence policing thresholds. May include test harnesses that replay known deflection-prone prompts against hard-mode agents and check for contract violations. Research inputs: specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md, specs/669_hard_mode_agent_system/reports/02_team-research.md." Set status "not_started", task_type "meta", add dependency on task 669 *(completed: task 677)*
- [x] Create follow-up task D in state.json: **adaptive auto-escalation advisory (v2)**. Description: "Implement churn detection that emits a 'consider --hard' warning when repeated deflection patterns are observed: 2+ plan revisions on a single task, 3+ implement dispatches with no phase completion, or analysis-only output in implementation phases. This is advisory only -- does not auto-escalate. v2 trajectory item. Research inputs: specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md, specs/669_hard_mode_agent_system/reports/02_team-research.md." Set status "not_started", task_type "meta", add dependency on task 669 *(completed: task 678)*
- [x] For each follow-up task: allocate project_number from `next_project_number` (increment sequentially), set `project_name` to a descriptive slug, create the task directory `specs/{NNN}_{SLUG}/` *(completed: dirs created, next_project_number now 679)*
- [x] Regenerate TODO.md: Run `bash .claude/scripts/generate-todo.sh` to reflect the new tasks *(completed)*

**Timing**: 0.5 hours

**Depends on**: Phase 6 (documentation must be complete so follow-up descriptions can reference the finalized system)

**Files to modify**:
- `specs/state.json` -- Add 4 new task entries to `active_projects`, increment `next_project_number` by 4
- `specs/TODO.md` -- Regenerated via `generate-todo.sh`

**Directories to create**:
- `specs/{NNN}_lean4_hard_mode_variants/`
- `specs/{NNN}_cslib_hard_mode_variants/`
- `specs/{NNN}_contract_lint_testing/`
- `specs/{NNN}_auto_escalation_advisory/`

(Exact NNN values determined at execution time from `next_project_number`.)

**Verification**:
- `jq '.active_projects | length' specs/state.json` shows 4 more entries than before this phase
- Each new task has `status: "not_started"`, `task_type: "meta"`, `dependencies: [669]`
- Each new task's description references both research report paths
- `next_project_number` is incremented by exactly 4
- TODO.md includes all 4 new tasks after regeneration
- Each task directory exists under `specs/`

## Testing & Validation

- [ ] **Routing correctness**: `command-route-skill.sh "research" "general" "skill-researcher" "hard"` resolves to `skill-researcher-hard` when the skill directory exists
- [ ] **Graceful fallback**: `command-route-skill.sh "implement" "neovim" "skill-neovim-implementation" "hard"` falls back to `skill-neovim-implementation` (no hard variant exists for neovim) with stderr note
- [ ] **Backward compatibility**: `command-route-skill.sh "research" "general" "skill-researcher"` (3 args, no effort_flag) returns `skill-researcher` unchanged
- [ ] **Contract file completeness**: All 5 contract files exist, are valid markdown, reference their H-technique numbers
- [ ] **Agent @-references valid**: Each hard agent's Context References section lists only files that exist in `.claude/context/contracts/`
- [ ] **Index.json valid**: `jq '.' .claude/context/index.json` parses without error, new entries have correct paths
- [ ] **Skill frontmatter valid**: Each hard skill SKILL.md has correct `name:`, `description:`, `allowed-tools:` fields
- [ ] **CLAUDE.md completeness**: Hard mode section exists with decision framework, cost documentation (3-5x, 15-25x), composability notes, per-invocation-only note
- [ ] **Follow-up tasks valid**: 4 new tasks in state.json with correct dependencies, descriptions, and report references

## Artifacts & Outputs

- `specs/669_hard_mode_agent_system/plans/02_hard-mode-implementation.md` (this file)
- `.claude/context/contracts/anti-analysis.md` (H2)
- `.claude/context/contracts/reference-grounding.md` (H3)
- `.claude/context/contracts/convergence.md` (H6)
- `.claude/context/contracts/territory.md` (H7)
- `.claude/context/contracts/wrap-up.md` (H9)
- `.claude/skills/skill-researcher-hard/SKILL.md`
- `.claude/skills/skill-planner-hard/SKILL.md`
- `.claude/skills/skill-implementer-hard/SKILL.md`
- `.claude/skills/skill-orchestrate-hard/SKILL.md`
- `.claude/agents/general-research-hard-agent.md`
- `.claude/agents/planner-hard-agent.md`
- `.claude/agents/general-implementation-hard-agent.md`
- Modified: `.claude/scripts/command-route-skill.sh`
- Modified: `.claude/commands/research.md`, `plan.md`, `implement.md`, `orchestrate.md`
- Modified: `.claude/skills/skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md`
- Modified: `.claude/context/index.json`
- Modified: `.claude/CLAUDE.md`
- Modified: `.claude/context/guides/extension-development.md`
- Modified: `specs/state.json` (4 follow-up tasks added)
- Created: 4 follow-up task directories under `specs/`

## Rollback/Contingency

All changes are additive (new files + small edits to existing files). Rollback:
1. Delete the 4 new skill directories: `rm -rf .claude/skills/skill-{researcher,planner,implementer,orchestrate}-hard`
2. Delete the 3 new agent files: `rm .claude/agents/{general-research-hard,planner-hard,general-implementation-hard}-agent.md`
3. Delete the contracts directory: `rm -rf .claude/context/contracts/`
4. Revert `command-route-skill.sh` to 3-argument version (git checkout)
5. Revert inline routing in research.md and plan.md (git checkout -- this is the only destructive change, but the refactor is a strict improvement)
6. Revert team skill modifications (git checkout)
7. Revert CLAUDE.md and index.json additions (git checkout)
8. Remove follow-up tasks from state.json and regenerate TODO.md (or git checkout both files)

The refactoring of inline routing in research.md/plan.md to use command-route-skill.sh is independently valuable and could be kept even if the rest of hard mode is reverted. Follow-up tasks (Phase 7) are independently valuable as they capture deferred scope regardless of hard-mode implementation status.
