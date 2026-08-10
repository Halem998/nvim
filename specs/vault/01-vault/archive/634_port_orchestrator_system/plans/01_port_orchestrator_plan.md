# Implementation Plan: Port Orchestrator System

- **Task**: 634 - port_orchestrator_system
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: 633 (port_core_script_infrastructure) - [COMPLETED]
- **Research Inputs**: specs/634_port_orchestrator_system/reports/01_port_orchestrator_research.md
- **Artifacts**: plans/01_port_orchestrator_plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Port the `.claude/` orchestrator system to `.opencode/`, enabling OpenCode users to invoke `/orchestrate` with the same autonomous lifecycle state machine, multi-task wave dispatch, and drift inspection capabilities. The port follows a dependency-driven phase order: architecture docs first (referenced by the skill), then the 1129-line `skill-orchestrate` skill in four sub-phases (single-task, multi-task, escalation, drift), then the `/orchestrate` command, then end-to-end verification. The work respects architectural differences (Agent -> Task tool, no `wezterm-notify`, `~/.opencode/` paths, `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` env var).

### Research Integration

The research report (`reports/01_port_orchestrator_research.md`) provided:

- **Inventory of 4 source components**: `commands/orchestrate.md` (394 lines), `skill-orchestrate/SKILL.md` (1129 lines), `skill-orchestrator/SKILL.md` (160 lines), `orchestrate-state-machine.md` (architecture doc)
- **3 missing architecture docs**: `orchestrate-state-machine.md`, `handoff-schema.md`, `dispatch-agent-spec.md` -- all must be ported because the skill SKILL.md @-references them
- **3-tier priority classification**: HIGH (command + state machine skill + 3 docs), MEDIUM (skill-orchestrator alignment), LOW (mislabeled `.opencode/agent/orchestrator.md` -- flagged for follow-up, not part of this port)
- **4-phase plan** with the skill split into 4 sub-phases (A: single-task state machine, B: multi-task mode, C: drift + escalation, D: verify with shared infrastructure)
- **Architectural differences table** mapping `.claude/` -> `.opencode/` (tool names, paths, env vars, notification pipelines)
- **Risk register** with 9 items, highest priority being the 1129-line skill complexity and Kahn's algorithm preservation
- **Verification plan**: path audit, tool name audit, reference integrity check, end-to-end test

### Prior Plan Reference

No prior plan exists for this task. The research report's phased approach follows the same dependency-driven pattern as task 633 (port_core_script_infrastructure) which ported 17 shared scripts: infrastructure first, then dependent components, then verification.

### Roadmap Alignment

This task is part of a sequential porting chain (633->634->635->636->637) maintaining parity between `.claude/` and `.opencode/` systems. The roadmap (`specs/ROADMAP.md`) does not have a direct entry for this port; it falls under the broader Phase 1 "Documentation Infrastructure" and "Agent System Quality" priorities (subagent-return reference cleanup, extension slim standard enforcement, etc.) since the orchestrator system is core agent-system infrastructure.

## Goals & Non-Goals

**Goals**:
- Port `orchestrate-state-machine.md`, `handoff-schema.md`, and `dispatch-agent-spec.md` to `.opencode/docs/architecture/` with path substitutions
- Port the 1129-line `skill-orchestrate` state machine in 4 sub-phases (single-task stages 0-8, multi-task MT-1 through MT-5, drift + blocker escalation, integration verification)
- Port `commands/orchestrate.md` (394 lines) with multi-task wave dispatch logic preserved
- Adapt all `.claude/` path references to `.opencode/` and `Agent` tool references to `Task` tool
- Strip Claude-Code-specific lifecycle notifications (`wezterm-notify.sh`, `tts-notify.sh`) -- rely on OpenCode's notification pipeline
- Preserve Kahn's algorithm for topological wave assignment and MAX_TASKS=8 batch limit
- Verify end-to-end: path audit, tool name audit, reference integrity, behavioral test

**Non-Goals**:
- Modify `.opencode/agent/orchestrator.md` (mislabeled chat agent, separate concern -- flag as follow-up)
- Add context-protection MUST NOT section to `.opencode/skills/skill-orchestrator/SKILL.md` (defer to follow-up; functional parity is sufficient)
- Add extension task-type routing to `skill-orchestrator` (defer to follow-up)
- Port synthesis-agent or other domain agents (task 635 scope)
- Refactor the state machine algorithm or change MAX_BLOCKER_ESCALATIONS / MAX_CYCLES thresholds (port unchanged; tune later if needed)
- Create a dedicated `orchestrator-agent.md` in `.claude/agents/` (no such file exists in `.claude/`; the system is purely skill+command-based)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `skill-orchestrate` is 1129 lines with subtle state machine logic; manual port may miss edge cases | H | H | Port in 4 sub-phases with independent verification gates; preserve algorithmic structure (only change paths and tool names) |
| Kahn's algorithm for wave dispatch has subtle ordering dependencies | H | M | Keep algorithm structure unchanged; only port paths and tool names; verify with multi-task end-to-end test |
| `Agent` tool -> `Task` tool semantic differences (subagent_type vs other params) | M | M | Verify with a test dispatch before completing Phase 3; the Task tool in OpenCode has equivalent semantics |
| `~/.claude/projects/` vs `~/.opencode/projects/` state tracking location | L | L | Update path references; session_id format is identical |
| Postflight workflow differs (no `wezterm-notify` in `.opencode/`) | L | L | Task 633 already addressed this; ensure orchestrator skill does not reference the removed hooks |
| Drift inspection thresholds (0.70 / 0.30) and loop guard limits (MAX_BLOCKER_ESCALATIONS=2, MAX_CYCLES=5) may need tuning | L | L | Port unchanged; tune if behavioral tests reveal issues |
| Loop guard file path `${TASK_DIR}/.orchestrator-loop-guard` is task-relative and portable | L | L | No change needed; verify during Phase 2D |
| 32-line `skill-orchestrator` alignment gap (missing context-protection directives) | L | M | Defer to follow-up; current routing logic is functionally equivalent |
| `.claude/skills/skill-orchestrator/SKILL.md.archived` exists -- verify `.opencode/` has no analogous archival | L | L | Check during Phase 2D; archived file is a previous version, not relevant to port |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2A, 2B, 2C | 1 |
| 3 | 2D | 2A, 2B, 2C |
| 4 | 3 | 2D |
| 5 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Port Architecture Documentation [COMPLETED]

**Goal**: Port the three architecture documentation files that the orchestrator skill `@`-references, establishing the documentation foundation.

**Tasks**:
- [ ] Read `.claude/docs/architecture/orchestrate-state-machine.md` to understand structure and content
- [ ] Read `.claude/docs/architecture/handoff-schema.md` to understand the JSON schema
- [ ] Read `.claude/docs/architecture/dispatch-agent-spec.md` to understand the fork vs named subagent dispatch spec
- [ ] Copy `orchestrate-state-machine.md` to `.opencode/docs/architecture/orchestrate-state-machine.md`
- [ ] Copy `handoff-schema.md` to `.opencode/docs/architecture/handoff-schema.md`
- [ ] Copy `dispatch-agent-spec.md` to `.opencode/docs/architecture/dispatch-agent-spec.md`
- [ ] Apply path substitutions: `.claude/` -> `.opencode/`, `~/.claude/` -> `~/.opencode/`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- [ ] Update `dispatch-agent-spec.md` to describe `Task` tool instead of `Agent` tool where applicable (semantic equivalence)
- [ ] Verify no `.claude/` path references remain in the three ported docs

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.opencode/docs/architecture/orchestrate-state-machine.md` (create)
- `.opencode/docs/architecture/handoff-schema.md` (create)
- `.opencode/docs/architecture/dispatch-agent-spec.md` (create)

**Verification**:
- All three files exist at the target paths
- `grep -l '\.claude/' .opencode/docs/architecture/orchestrate-state-machine.md .opencode/docs/architecture/handoff-schema.md .opencode/docs/architecture/dispatch-agent-spec.md` returns empty
- Frontmatter (if any) is valid markdown

### Phase 2A: Port skill-orchestrate - Single-Task State Machine [COMPLETED]

**Goal**: Port Stages 0-8 of the single-task state machine from `.claude/skills/skill-orchestrate/SKILL.md` to `.opencode/skills/skill-orchestrate/SKILL.md`. Stages cover input validation, routing resolution, preflight, state machine loop, all state handlers, handoff reading, and postflight.

**Tasks**:
- [ ] Read `.claude/skills/skill-orchestrate/SKILL.md` end-to-end to map all sections
- [ ] Create `.opencode/skills/skill-orchestrate/` directory
- [ ] Copy the SKILL.md content to `.opencode/skills/skill-orchestrate/SKILL.md` (full 1129-line file)
- [ ] Update frontmatter (name, description) to reflect OpenCode context
- [ ] Apply path substitutions: `.claude/scripts/` -> `.opencode/scripts/`, `.claude/docs/architecture/` -> `.opencode/docs/architecture/`, `~/.claude/` -> `~/.opencode/`
- [ ] Update tool references: `Agent tool` -> `Task tool` (preserve all semantics)
- [ ] Update env var: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- [ ] Strip `wezterm-notify.sh` / `tts-notify.sh` lifecycle notification references (OpenCode has its own pipeline)
- [ ] Update CLAUDE.md references to AGENTS.md where context docs are referenced
- [ ] Verify Stages 0-8 (single-task path) is complete and internally consistent

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-orchestrate/SKILL.md` (create)

**Verification**:
- File exists and is the full 1129 lines (or close, accounting for stripped notification hooks)
- All `@-references` to architecture docs resolve to files in `.opencode/docs/architecture/`
- `grep 'Agent tool' .opencode/skills/skill-orchestrate/SKILL.md` returns no matches (or only in cases where Agent is a noun, not the tool name)
- `grep 'wezterm-notify\|tts-notify' .opencode/skills/skill-orchestrate/SKILL.md` returns no matches

### Phase 2B: Port skill-orchestrate - Multi-Task Mode [COMPLETED]

**Goal**: Port the multi-task mode (MT-1 through MT-5) sections of `skill-orchestrate`, which handle batch task input parsing, dependency graph construction, topological wave assignment, and wave execution.

**Tasks**:
- [ ] Locate the multi-task mode section in the partially-ported `.opencode/skills/skill-orchestrate/SKILL.md` (from Phase 2A)
- [ ] Cross-reference with `.claude/skills/skill-orchestrate/SKILL.md` for the MT-1 through MT-5 sections
- [ ] Verify all path substitutions from Phase 2A are consistent in the multi-task sections
- [ ] Verify Kahn's algorithm implementation is preserved unchanged
- [ ] Verify MAX_TASKS=8 batch limit and trimming logic is preserved
- [ ] Verify wave execution with parallel dispatch logic is preserved
- [ ] Update any multi-task-specific path or tool references missed in Phase 2A

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-orchestrate/SKILL.md` (refine multi-task sections from Phase 2A port)

**Verification**:
- MT-1 through MT-5 sections are present and complete
- Kahn's algorithm structure is identical to `.claude/` version (logic unchanged)
- Multi-task syntax examples in comments use `.opencode/` paths and `Task` tool

### Phase 2C: Port skill-orchestrate - Drift Inspection and Blocker Escalation [COMPLETED]

**Goal**: Port Stage 5a (drift inspection function) and Stage 6 (5-step blocker escalation sequence) of the state machine.

**Tasks**:
- [ ] Locate drift inspection and blocker escalation sections in the partially-ported `.opencode/skills/skill-orchestrate/SKILL.md`
- [ ] Cross-reference with `.claude/skills/skill-orchestrate/SKILL.md` for Stage 5a and Stage 6
- [ ] Verify drift thresholds (0.70 / 0.30) are ported unchanged
- [ ] Verify MAX_BLOCKER_ESCALATIONS=2 limit is preserved
- [ ] Verify the 5-step escalation sequence is preserved unchanged
- [ ] Update any path or tool references missed in Phase 2A for these specific sections
- [ ] Verify the `dispatch_agent` calls (now Task tool calls) are semantically equivalent for the escalation and drift functions

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-orchestrate/SKILL.md` (refine drift and escalation sections)

**Verification**:
- Stage 5a (drift inspection) is present with 0.70 / 0.30 thresholds
- Stage 6 (5-step escalation) is present with MAX_BLOCKER_ESCALATIONS=2
- All escalation steps use `Task` tool (not `Agent`)

### Phase 2D: Verify skill-orchestrate Integration with Shared Infrastructure [COMPLETED]

**Goal**: Verify the ported `skill-orchestrate` works with the task 633 shared infrastructure (`skill-base.sh`, `dispatch-agent.sh`, `command-gate-in/out.sh`, `parse-command-args.sh`, `postflight-workflow.sh`).

**Tasks**:
- [ ] Run `bash -n .opencode/scripts/skill-base.sh` to verify shell syntax
- [ ] Run `bash -n .opencode/scripts/dispatch-agent.sh` to verify shell syntax
- [ ] Verify all `source .opencode/scripts/...` calls in `skill-orchestrate/SKILL.md` resolve to existing files
- [ ] Verify all `@-references` to `.opencode/docs/architecture/...` resolve to files created in Phase 1
- [ ] Check that `.claude/skills/skill-orchestrator/SKILL.md.archived` is not relevant to the port (verify)
- [ ] Run path audit: `grep -rn '\.claude/' .opencode/skills/skill-orchestrate/` should return no matches (or only intentional shared references)
- [ ] Run tool name audit: `grep -n 'Agent tool' .opencode/skills/skill-orchestrate/SKILL.md` should return no matches
- [ ] Verify loop guard file path `${TASK_DIR}/.orchestrator-loop-guard` is task-relative (no path change needed)

**Timing**: 0.5 hours

**Depends on**: 2A, 2B, 2C

**Files to modify**:
- `.opencode/skills/skill-orchestrate/SKILL.md` (refinements based on audit findings)

**Verification**:
- All shell script source calls resolve
- All `@-references` resolve
- No `.claude/` path references remain in the ported skill
- No `Agent tool` references remain

### Phase 3: Port /orchestrate Command [COMPLETED]

**Goal**: Port `.claude/commands/orchestrate.md` (394 lines) to `.opencode/commands/orchestrate.md`, preserving multi-task wave dispatch, dependency-aware topological sort, and gate-in/gate-out checkpoints.

**Tasks**:
- [ ] Read `.claude/commands/orchestrate.md` end-to-end to map all sections
- [ ] Create `.opencode/commands/orchestrate.md` with ported content
- [ ] Update frontmatter (description, argument-hint) to reflect OpenCode context
- [ ] Apply path substitutions: `.claude/scripts/` -> `.opencode/scripts/`, `~/.claude/` -> `~/.opencode/`
- [ ] Update tool references: `Agent tool` -> `Task tool` (semantic equivalence for subagent dispatch)
- [ ] Update env var: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- [ ] Update `skill-orchestrate` invocation (no change to skill name; only the path context changes)
- [ ] Verify multi-task mode parsing (single, comma-separated, range, mixed) is preserved
- [ ] Verify dependency graph construction (intra-batch only) is preserved
- [ ] Verify topological wave assignment (Kahn's algorithm) is preserved
- [ ] Verify wave execution with parallel dispatch (up to 8 tasks per batch) is preserved
- [ ] Verify single-task gate-in/gate-out/commit checkpoints are preserved
- [ ] Verify permissive gate (does not require plan file) is preserved
- [ ] Verify anti-bypass constraint: All lifecycle phases MUST delegate to `skill-orchestrate`

**Timing**: 1.5 hours

**Depends on**: 2D

**Files to modify**:
- `.opencode/commands/orchestrate.md` (create)

**Verification**:
- File exists and is ~394 lines (or close, accounting for path substitutions)
- All script references resolve to files in `.opencode/scripts/`
- `grep 'Agent tool' .opencode/commands/orchestrate.md` returns no matches
- Kahn's algorithm structure is identical to `.claude/` version
- Anti-bypass constraint is present and explicit

### Phase 4: End-to-End Verification [COMPLETED]

**Goal**: Verify the ported orchestrator system works end-to-end with a simple task.

**Tasks**:
- [ ] Run path audit: `grep -rn '\.claude/' .opencode/skills/skill-orchestrate/ .opencode/commands/orchestrate.md .opencode/docs/architecture/orchestrate-state-machine.md .opencode/docs/architecture/handoff-schema.md .opencode/docs/architecture/dispatch-agent-spec.md` should return no matches
- [ ] Run tool name audit: `grep -rn 'Agent tool' .opencode/skills/skill-orchestrate/ .opencode/commands/orchestrate.md` should return no matches
- [ ] Run env var audit: `grep -rn 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' .opencode/skills/skill-orchestrate/ .opencode/commands/orchestrate.md` should return no matches
- [ ] Run notification audit: `grep -rn 'wezterm-notify\|tts-notify' .opencode/skills/skill-orchestrate/ .opencode/commands/orchestrate.md` should return no matches
- [ ] Verify all `@-references` in ported files resolve in `.opencode/`
- [ ] Verify frontmatter in all ported SKILL.md and command files is valid
- [ ] Verify file line counts match expectations (within reason for substitutions)
- [ ] Run a simple `/orchestrate` test on a stub task to verify end-to-end execution
- [ ] Document any test failures or behavioral anomalies for follow-up
- [ ] Create a summary artifact at `specs/634_port_orchestrator_system/summaries/01_port_orchestrator-summary.md` describing what was ported, line counts, verification results, and any deviations

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `specs/634_port_orchestrator_system/summaries/01_port_orchestrator-summary.md` (create)

**Verification**:
- All four audits return no matches (or only intentional shared references)
- End-to-end test passes (or anomalies are documented)
- Summary artifact captures the port outcome

## Testing & Validation

- [ ] All three architecture docs created at `.opencode/docs/architecture/`
- [ ] `skill-orchestrate/SKILL.md` ported with all sections intact (Stages 0-8, MT-1 to MT-5, Stage 5a, Stage 6)
- [ ] `commands/orchestrate.md` ported with multi-task wave dispatch preserved
- [ ] Path audit passes: no `.claude/` references in ported files
- [ ] Tool name audit passes: no `Agent tool` references in ported files
- [ ] Env var audit passes: no `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` references
- [ ] Notification audit passes: no `wezterm-notify` or `tts-notify` references
- [ ] All `@-references` in ported files resolve to existing files in `.opencode/`
- [ ] Shell script syntax checks pass for all `source`-d scripts
- [ ] End-to-end test: `/orchestrate` on a simple task completes successfully
- [ ] Summary artifact created at `summaries/01_port_orchestrator-summary.md`

## Artifacts & Outputs

- `.opencode/docs/architecture/orchestrate-state-machine.md` (create)
- `.opencode/docs/architecture/handoff-schema.md` (create)
- `.opencode/docs/architecture/dispatch-agent-spec.md` (create)
- `.opencode/skills/skill-orchestrate/SKILL.md` (create, ~1129 lines)
- `.opencode/commands/orchestrate.md` (create, ~394 lines)
- `specs/634_port_orchestrator_system/plans/01_port_orchestrator_plan.md` (this file)
- `specs/634_port_orchestrator_system/summaries/01_port_orchestrator-summary.md` (post-implementation)

## Rollback/Contingency

If the port introduces issues that block task 635 (port_synthesis_domain_agents):

1. **Revert specific files**: Each ported file is independent. Revert by deleting the ported file and restoring from git history.
2. **Partial port acceptable**: If only the command or skill fails, the other may still be usable. Document partial completion in the summary.
3. **Reference integrity fallback**: If `@-references` break, update them to point back to `.claude/docs/architecture/` as a temporary measure, then re-port the docs in a follow-up task.
4. **Behavioral test failure**: If end-to-end test fails, document the failure mode and revert the command file (Phase 3) first, then the skill (Phase 2) if needed. The architecture docs (Phase 1) are low-risk and can remain.

The port is a "consumer" of task 633's shared infrastructure, so a partial port does not break the broader system. The `.claude/` orchestrator continues to function independently while the `.opencode/` port is being completed.
