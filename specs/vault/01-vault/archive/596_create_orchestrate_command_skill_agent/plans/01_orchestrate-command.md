# Implementation Plan: Task #596

- **Task**: 596 - Create /orchestrate command, skill-orchestrate, and dispatch-agent.sh
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Tasks 593 (shared utilities), 594 (skill base), 595 (orchestrator_mode plumbing)
- **Research Inputs**: specs/596_create_orchestrate_command_skill_agent/reports/01_seed-research.md, specs/596_create_orchestrate_command_skill_agent/reports/02_auto-flag-analysis.md, specs/596_create_orchestrate_command_skill_agent/reports/03_design-guidance.md
- **Artifacts**: plans/01_orchestrate-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `/orchestrate` command -- a fire-and-forget autonomous loop that drives a task through its full lifecycle (research, plan, implement, complete) without user confirmation between phases. The implementation consists of three new files: the command entry point (`orchestrate.md`), the state machine skill (`skill-orchestrate/SKILL.md`), and the dispatch function (`dispatch-agent.sh`). The existing vestigial `skill-orchestrator` is replaced. Integration points include the existing `orchestrator_mode` plumbing in `skill-implementer` and `skill_write_orchestrator_handoff()` in `skill-base.sh`, plus CLAUDE.md command and skill-to-agent table updates.

### Research Integration

Three research reports inform this plan:
- **Report 01 (Seed Research)**: Established the fire-and-forget design directive, state machine architecture, blocker escalation as highest-value capability, fork-vs-fresh dispatch matrix, and nested loop resolution via `orchestrator_mode` flag.
- **Report 02 (--auto Flag Analysis)**: Confirmed standalone `/orchestrate` is correct architecture (not `--auto` on `/implement`). Found existing `orchestrator_mode` infrastructure already plumbed in `skill-implementer` (Stage 4, Stage 5c, Stage 7) and `skill_write_orchestrator_handoff()` in `skill-base.sh`. Current `skill-orchestrator` (128L, routing-only) is vestigial.
- **Report 03 (Design Guidance)**: Provided complete state table (10 states), loop guard file schema, `dispatch_agent()` function spec, `.orchestrator-handoff.json` schema, blocker escalation 5-step implementation, and context flatness guarantee (~450 tokens/cycle).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are directly advanced by this task. However, this task is part of the broader agent system refactoring suite (tasks 592-599) and builds on infrastructure established by tasks 593-595.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Create `.claude/commands/orchestrate.md` entry point with argument parsing, gate-in (permissive -- no plan required), skill delegation, gate-out, and commit
- Create `.claude/skills/skill-orchestrate/SKILL.md` implementing the 10-state state machine with MAX_CYCLES=5 loop guard, blocker escalation (5-step), and continuation handling
- Create `.claude/scripts/dispatch-agent.sh` encapsulating the fork-vs-named-subagent decision with `dispatch_agent()` function
- Replace the vestigial `skill-orchestrator` routing-only skill with the new `skill-orchestrate` state machine
- Update CLAUDE.md command tables, skill-to-agent mappings, and documentation references
- Ensure `orchestrator_mode=true` propagation through all dispatch cycles

**Non-Goals**:
- Modifying `skill-implementer` (orchestrator_mode is already plumbed in Stages 4, 5c, 7)
- Modifying `skill-base.sh` (`skill_write_orchestrator_handoff()` already exists)
- Implementing the architecture docs themselves (already created by task 592)
- Adding `--auto` flag to `/implement` (explicitly rejected by report 02)
- Context budget tier enforcement (deferred to task 598)
- Extension hooks (deferred to task 599)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blocker escalation infinite loop (research-revise-implement-block cycle) | H | M | Cap at 2 blocker escalation attempts per invocation; on 3rd block, exit with human escalation message |
| Naming confusion: `skill-orchestrator` (old) vs `skill-orchestrate` (new) | M | H | Rename old to archive or remove entirely; update all references in CLAUDE.md; clear naming in skill frontmatter |
| Fork dispatch unavailable (FORK_SUBAGENT env var not set) | M | L | Graceful degradation in `dispatch-agent.sh`: fall back to named research agent with warning |
| orchestrator_mode flag contract changes in skill-implementer | H | L | Add cross-reference comment in skill-implementer Stage 4 noting dependency from skill-orchestrate |
| State machine stale read after dispatch (state.json race) | M | L | Read state.json at top of each loop iteration; accept single-source-of-truth latency |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create dispatch-agent.sh [COMPLETED]

**Goal**: Create the `dispatch_agent()` function that encapsulates the fork-vs-named-subagent decision, following the specification in `.claude/docs/architecture/dispatch-agent-spec.md`.

**Tasks**:
- [ ] Create `.claude/scripts/dispatch-agent.sh` with `dispatch_agent()` function signature: `dispatch_agent agent_type prompt context_json is_blocker_escalation`
- [ ] Implement fork path (`is_blocker_escalation=true`): omit `subagent_type`, use `FORK_SUBAGENT=1` if set, inherit parent cache prefix
- [ ] Implement named subagent path (`is_blocker_escalation=false`): use `agent_type` as `subagent_type`, fresh context window
- [ ] Implement graceful degradation: if fork path fails (no `FORK_SUBAGENT` env var), fall back to named `general-research-agent`
- [ ] Add helper functions: `invoke_agent_fork()`, `invoke_named_agent()`
- [ ] Add file header with sourcing semantics documentation (matching `skill-base.sh` pattern)
- [ ] Note: actual Agent tool invocation is conceptual in the script -- the skill reads these functions as dispatch instructions and uses the Agent tool directly

**Timing**: 45 min

**Depends on**: none

**Files to modify**:
- `.claude/scripts/dispatch-agent.sh` - NEW: dispatch function (~60 lines)

**Verification**:
- File exists and is syntactically valid bash (`bash -n dispatch-agent.sh`)
- Function signature matches spec: `dispatch_agent "$agent_type" "$prompt" "$context_json" "$is_blocker_escalation"`
- Fork path and named subagent path are distinct code paths
- Graceful degradation handles missing `FORK_SUBAGENT`

---

### Phase 2: Create skill-orchestrate/SKILL.md [COMPLETED]

**Goal**: Create the state machine skill that drives the autonomous orchestration loop, implementing the 10-state table from the architecture spec with blocker escalation and continuation handling.

**Tasks**:
- [ ] Create `.claude/skills/skill-orchestrate/` directory
- [ ] Create `SKILL.md` with skill frontmatter (`name: skill-orchestrate`, `description`, `allowed-tools: Agent, Bash, Read, Edit`)
- [ ] Implement Stage 1: Input validation via `skill_validate_input` (source `skill-base.sh`)
- [ ] Implement Stage 2: Preflight -- read state.json to determine current task status; create/read `.orchestrator-loop-guard` file (JSON: session_id, cycle_count, max_cycles=5, current_state, timestamps)
- [ ] Implement Stage 3: State machine loop (`while cycle_count < MAX_CYCLES`)
- [ ] Implement state handlers for all 10 states from the architecture spec:
  - `not_started` -> dispatch research (named)
  - `researching` -> warn and exit (in-flight)
  - `researched` -> dispatch plan (named)
  - `planning` -> warn and exit (in-flight)
  - `planned` -> dispatch implement (orchestrator_mode=true)
  - `implementing` -> dispatch implement resume (orchestrator_mode=true)
  - `partial` + continuation -> re-dispatch implement with continuation_context
  - `partial` + blockers -> invoke blocker escalation sequence
  - `partial` + no handoff + cycle limit -> report and exit
  - `blocked` -> read blockers, invoke blocker escalation
  - `completed`/`abandoned`/`expanded` -> report status and exit
- [ ] Implement blocker escalation 5-step sequence as `blocker_escalation()` function:
  - Step 1: Extract blocker description from `.orchestrator-handoff.json`
  - Step 2: Fork research (`dispatch_agent "" "$prompt" "$context" "true"`)
  - Step 3: Read research findings from handoff
  - Step 4: Dispatch reviser-agent (named)
  - Step 5: Re-dispatch implement (named, orchestrator_mode=true)
- [ ] Add blocker escalation cap: max 2 escalation attempts per invocation; on 3rd, exit with user notification
- [ ] Implement handoff reading after each dispatch (read only `.orchestrator-handoff.json`, never full artifacts)
- [ ] Implement loop guard file update after each cycle (increment cycle_count, update current_state and last_updated)
- [ ] Implement prompt construction for each dispatch type (research, plan, implement, blocker research, revise)
- [ ] Implement `orchestrator_mode=true` in all delegation contexts passed to implement dispatches
- [ ] Add context references section pointing to architecture docs
- [ ] Implement postflight: update loop guard, report final status, cleanup loop guard on success

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - NEW: state machine skill (~200 lines)

**Verification**:
- Skill frontmatter is valid (name, description, allowed-tools)
- All 10 states from the state table have explicit handlers
- Blocker escalation sequence has 5 steps matching the architecture spec
- MAX_CYCLES=5 enforcement is present
- Loop guard file is created, updated, and cleaned up
- `orchestrator_mode=true` appears in all implement dispatch contexts
- Context flatness: skill never reads full research reports, plan files, or summaries -- only handoff JSON

---

### Phase 3: Create orchestrate.md Command Entry Point [COMPLETED]

**Goal**: Create the command entry point that follows the standard GATE IN -> DELEGATE -> GATE OUT -> COMMIT lifecycle, adapted for orchestration (permissive gate-in, no plan required).

**Tasks**:
- [ ] Create `.claude/commands/orchestrate.md` with command frontmatter (`description`, `allowed-tools`, `argument-hint: TASK_NUMBER`, `model: opus`)
- [ ] Implement argument parsing: single task number only (no multi-task, no `--team` for v1)
- [ ] Implement GATE IN via `source .claude/scripts/command-gate-in.sh "$task_number" "orchestrate"`
  - Permissive: does NOT require a plan (unlike `/implement`)
  - Only blocks on terminal states (completed, abandoned, expanded)
- [ ] Implement DELEGATE: invoke `skill-orchestrate` via Skill tool with delegation context:
  - `orchestrator_mode: true`
  - `session_id`, `task_number`, `task_type`, `task_name`, `description`
  - No `plan_path` (state machine determines what to dispatch)
- [ ] Implement GATE OUT via `bash .claude/scripts/command-gate-out.sh "$task_number" "orchestrate" "$SESSION_ID"`
- [ ] Implement COMMIT: git commit with message format `task {N}: complete orchestration`
- [ ] Add output format: report final task status, cycle count, phases completed
- [ ] Add error handling section

**Timing**: 45 min

**Depends on**: 1

**Files to modify**:
- `.claude/commands/orchestrate.md` - NEW: command entry point (~50-60 lines)

**Verification**:
- Command frontmatter has required fields (description, allowed-tools, argument-hint, model)
- Gate-in does not require plan file (unlike `/implement`)
- Delegation context includes `orchestrator_mode: true`
- Gate-out and commit follow standard patterns
- Output section documents both success and partial outcomes

---

### Phase 4: Replace Vestigial skill-orchestrator [COMPLETED]

**Goal**: Retire the vestigial routing-only `skill-orchestrator` (128 lines) and ensure all references point to the new `skill-orchestrate`. The routing function it performed is already handled by `command-route-skill.sh`.

**Tasks**:
- [ ] Archive `skill-orchestrator/SKILL.md` by moving to `.claude/skills/skill-orchestrator/SKILL.md.archived` (preserve for history, do not delete)
- [ ] Verify `command-route-skill.sh` handles all routing currently done by `skill-orchestrator` -- no functionality loss
- [ ] Update `.claude/CLAUDE.md` command reference table: add `/orchestrate` entry
- [ ] Update `.claude/CLAUDE.md` skill-to-agent mapping table: replace `skill-orchestrator` row with `skill-orchestrate` row
- [ ] Update `.claude/CLAUDE.md` agents table: no new agent needed (orchestrate runs as main session, dispatches existing agents)
- [ ] Add cross-reference comment in `skill-implementer/SKILL.md` Stage 4 noting the `orchestrator_mode` dependency from `/orchestrate`
- [ ] Verify no other files reference `skill-orchestrator` that need updating (grep for `skill-orchestrator` across `.claude/`)

**Timing**: 45 min

**Depends on**: 2, 3

**Files to modify**:
- `.claude/skills/skill-orchestrator/SKILL.md` - ARCHIVE (rename to .archived)
- `.claude/CLAUDE.md` - UPDATE: command table, skill-to-agent mappings (auto-generated, update merge sources)
- `.claude/skills/skill-implementer/SKILL.md` - UPDATE: add cross-reference comment in Stage 4
- Other files referencing `skill-orchestrator` as found by grep

**Verification**:
- `grep -r "skill-orchestrator" .claude/` returns only the archived file and any intentional history references
- CLAUDE.md command table includes `/orchestrate` entry
- CLAUDE.md skill-to-agent table has `skill-orchestrate` replacing `skill-orchestrator`
- `skill-implementer` Stage 4 has cross-reference comment

---

### Phase 5: Integration Testing and Verification [COMPLETED]

**Goal**: Verify the complete implementation works end-to-end by checking file existence, syntax validity, cross-references, and structural correctness.

**Tasks**:
- [ ] Verify all three new files exist: `orchestrate.md`, `skill-orchestrate/SKILL.md`, `dispatch-agent.sh`
- [ ] Run `bash -n .claude/scripts/dispatch-agent.sh` to verify bash syntax
- [ ] Verify `skill-orchestrate/SKILL.md` references `dispatch-agent.sh` via source
- [ ] Verify `orchestrate.md` invokes `skill-orchestrate` via Skill tool
- [ ] Verify `orchestrator_mode=true` appears in all implement delegation contexts within `skill-orchestrate`
- [ ] Verify MAX_CYCLES=5 is enforced in the state machine loop
- [ ] Verify blocker escalation cap (max 2 attempts) is present
- [ ] Verify handoff reading pattern: skill-orchestrate reads only `.orchestrator-handoff.json`, never full artifacts
- [ ] Verify loop guard file path matches spec: `specs/{NNN}_{SLUG}/.orchestrator-loop-guard`
- [ ] Verify CLAUDE.md updates are consistent (command table, skill table, agent table)
- [ ] Run `grep -r "skill-orchestrator" .claude/ --include="*.md"` to confirm no stale references (except archived file)
- [ ] Verify `dispatch-agent.sh` graceful degradation path is implemented

**Timing**: 45 min

**Depends on**: 4

**Files to modify**:
- None (verification only; minor fixes if issues found)

**Verification**:
- All verification tasks above pass
- No syntax errors in any created files
- No stale references to vestigial `skill-orchestrator`
- Architecture spec cross-references are correct

## Testing & Validation

- [ ] `bash -n .claude/scripts/dispatch-agent.sh` passes (syntax check)
- [ ] `.claude/commands/orchestrate.md` has valid frontmatter (description, allowed-tools, argument-hint, model)
- [ ] `.claude/skills/skill-orchestrate/SKILL.md` has valid frontmatter (name, description, allowed-tools)
- [ ] `grep -c "MAX_CYCLES" .claude/skills/skill-orchestrate/SKILL.md` returns >= 1
- [ ] `grep -c "orchestrator_mode" .claude/skills/skill-orchestrate/SKILL.md` returns >= 3
- [ ] `grep -c "dispatch_agent" .claude/skills/skill-orchestrate/SKILL.md` returns >= 4 (research, plan, implement, blocker)
- [ ] `grep -c "blocker_escalation" .claude/skills/skill-orchestrate/SKILL.md` returns >= 1
- [ ] `grep -r "skill-orchestrator" .claude/ --include="*.md" -l` returns only archived file(s)
- [ ] CLAUDE.md contains `/orchestrate` in command table
- [ ] CLAUDE.md contains `skill-orchestrate` in skill-to-agent table

## Artifacts & Outputs

- `.claude/commands/orchestrate.md` -- command entry point (~50-60 lines)
- `.claude/skills/skill-orchestrate/SKILL.md` -- state machine skill (~200 lines)
- `.claude/scripts/dispatch-agent.sh` -- dispatch function (~60 lines)
- `.claude/skills/skill-orchestrator/SKILL.md.archived` -- archived vestigial skill
- Updated `.claude/CLAUDE.md` -- command and skill-to-agent tables

## Rollback/Contingency

If implementation fails or causes regressions:
1. Delete the three new files: `orchestrate.md`, `skill-orchestrate/SKILL.md`, `dispatch-agent.sh`
2. Restore `skill-orchestrator/SKILL.md` from the `.archived` copy
3. Revert CLAUDE.md changes via git
4. The existing `/research`, `/plan`, `/implement` commands are unaffected -- `/orchestrate` is purely additive
5. `orchestrator_mode` infrastructure in `skill-implementer` and `skill-base.sh` remains safe (guarded by `orchestrator_mode=true` check, which is only set by `/orchestrate`)
