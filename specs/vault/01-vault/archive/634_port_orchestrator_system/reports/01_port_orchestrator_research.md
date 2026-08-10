# Research Report: Port Orchestrator System

- **Task**: 634 - port_orchestrator_system
- **Started**: 2026-06-08T02:35:00Z
- **Completed**: 2026-06-08T02:45:00Z
- **Effort**: 2-3 hours
- **Dependencies**: 633 (port_core_script_infrastructure) - [COMPLETED]
- **Sources/Inputs**:
  - Codebase: `.claude/skills/skill-orchestrate/SKILL.md` (1129 lines), `.claude/skills/skill-orchestrator/SKILL.md` (160 lines), `.claude/commands/orchestrate.md` (394 lines), `.opencode/skills/skill-orchestrator/SKILL.md` (128 lines)
  - Documentation: `.claude/docs/architecture/orchestrate-state-machine.md`, `.claude/docs/architecture/handoff-schema.md`, `.claude/docs/architecture/dispatch-agent-spec.md`
  - Related: `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` (predecessor task)
  - Roadmap: `specs/ROADMAP.md` (Phase 1 priorities include documentation infrastructure)
  - State: `specs/state.json` (active projects 633-637 = sequential porting chain)
  - Memory: `.memory/10-Memories/MEM-agent-system-reload-propagation.md`
- **Artifacts**: `specs/634_port_orchestrator_system/reports/01_port_orchestrator_research.md`
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Project Context

- **Upstream Dependencies**: Task 633 (port_core_script_infrastructure) - completed; provides the shared `skill-base.sh`, `dispatch-agent.sh`, `command-gate-in/out.sh`, `parse-command-args.sh`, and `postflight-workflow.sh` infrastructure that the orchestrator system depends on
- **Downstream Dependents**: Tasks 635 (port_synthesis_domain_agents), 636 (sync_context_rules_extensions_cleanup), 637 (verification_and_drift_detection) - all depend on 634
- **Alternative Paths**: Could port only `skill-orchestrator` (the routing skill) and skip `skill-orchestrate` (the autonomous state machine); would be a partial port
- **Potential Extensions**: Multi-task mode with dependency-aware wave dispatch, drift inspection, blocker escalation, loop guard

## Executive Summary

- The **orchestrator system** in `.claude/` consists of TWO distinct components: `skill-orchestrator` (a thin **routing** skill for command dispatch) and `skill-orchestrate` (a 1129-line **autonomous state machine** driving `/orchestrate`)
- **Currently missing from `.opencode/`**: `/orchestrate` command (no `orchestrate.md` in `.opencode/commands/`), the `skill-orchestrate` skill (autonomous state machine), and the `orchestrate-state-machine.md` architecture doc
- **Already present in `.opencode/`**: `skill-orchestrator` (routing skill, 128 lines) - much smaller than `.claude/`'s version (160 lines) and lacks context-protection directives
- **Critical observation**: `.opencode/agent/orchestrator.md` (124 lines) is mislabeled - it documents a "Read-only chat agent" but uses the `orchestrator` agent name; this is a separate concern but part of the broader orchestrator system
- **Porting approach**: Three-tier classification (HIGH for command + state machine + state-machine doc; MEDIUM for orchestrator agent file; LOW for skill-orchestrator alignment); plan should follow 633's dependency-driven phasing
- **Key architectural differences to respect**: `Agent` tool -> `Task` tool, `.claude/scripts/` -> `.opencode/scripts/`, `CLAUDE.md` -> `AGENTS.md`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`, no `wezterm-notify` / `tts-notify` lifecycle notifications (use OpenCode's pipeline)

## Context & Scope

This research examines the orchestrator system in `.claude/` to determine what must be ported to `.opencode/`. The orchestrator system is the meta-coordination layer that sits above individual command/skill/agent dispatch. The `.claude/` system has two distinct orchestrator concepts:

1. **`skill-orchestrator`** - A **routing** skill (160 lines) that other skills/commands invoke to route work to the correct task-type-specific skill. It looks up task context, validates status, resolves the right skill via `task_type`, and delegates.
2. **`skill-orchestrate`** - A **lifecycle state machine** (1129 lines) that autonomously drives a task through research -> plan -> implement -> complete without user confirmation, with multi-task wave dispatch, blocker escalation, drift detection, and loop guards. Invoked by the `/orchestrate` command.

The `.opencode/` system currently has only `skill-orchestrator` (128 lines) and is missing the `/orchestrate` command, `skill-orchestrate`, and the `orchestrate-state-machine.md` architecture doc.

### Roadmap Context

From `specs/ROADMAP.md`, this task is **not directly mapped** to any specific roadmap item. It is part of a porting chain (633->634->635->636->637) that maintains parity between `.claude/` and `.opencode/` systems. The broader roadmap Phase 1 priorities focus on documentation infrastructure (manifest-driven READMEs, marketplace metadata, doc-lint CI, review integration) which align with the long-term porting work.

### Task 633 Relationship

Task 633 (port_core_script_infrastructure) was completed prior to this task and provides the **shared infrastructure** that the orchestrator system depends on:

- `skill-base.sh` (516 lines) - Provides `skill_preflight_update()`, `skill_postflight_update()`, `skill_link_artifact_from_handoff()`, `skill_validate_input()`, and `skill_write_orchestrator_handoff()` functions
- `dispatch-agent.sh` (128 lines) - Implements `dispatch_agent` function for named subagent vs fork dispatch
- `command-gate-in.sh` / `command-gate-out.sh` - Checkpoint infrastructure
- `parse-command-args.sh` (135 lines) - Argument parser including multi-task syntax
- `postflight-workflow.sh` (137 lines) - Unified postflight parameterized by operation type
- `generate-task-order.sh` (895 lines) - Used by `update-task-status.sh` for terminal status regeneration
- `update-task-status.sh` (now 410 lines) - With `revise` operation support

These scripts exist in both systems and are byte-identical or near-identical (per the 633 research report). The orchestrator system can be ported as a "consumer" of this infrastructure.

## Findings

### Inventory: Orchestrator System Components

#### `.claude/` orchestrator components (4 files)

```
.claude/commands/orchestrate.md                            394 lines
.claude/skills/skill-orchestrate/SKILL.md                 1129 lines
.claude/skills/skill-orchestrator/SKILL.md                 160 lines
.claude/docs/architecture/orchestrate-state-machine.md    (architecture doc)
```

Plus the orchestrator subagent file (used by the state machine for blocker escalation and drift inspection):

```
.claude/agents/ (no orchestrator-agent.md exists)
```

Note: The `.claude/agents/` directory does NOT contain an `orchestrator-agent.md`. The orchestrator system is purely skill+command-based; no dedicated orchestrator subagent exists in `.claude/`.

#### `.opencode/` orchestrator components (3 files)

```
.opencode/extensions/core/skills/skill-orchestrator/SKILL.md    128 lines
.opencode/extensions/core/commands/orchestrate.md               MISSING
.opencode/extensions/core/skills/skill-orchestrate/             MISSING
.opencode/docs/architecture/orchestrate-state-machine.md        MISSING
```

Plus a mislabeled orchestrator chat agent file (not the state machine, but worth noting):

```
.opencode/agent/orchestrator.md    124 lines  (defines "Read-only chat agent", not the orchestrator system)
```

#### Core extension symmetry check

Both systems have a `core` extension that holds the bulk of the system. The `.claude/extensions/core/` contains `skill-orchestrate`, `skill-orchestrator`, and the `orchestrate.md` command. The `.opencode/extensions/core/` contains only `skill-orchestrator` and is missing the state machine skill and command.

### Component Analysis

#### Component 1: `/orchestrate` command (HIGH PRIORITY)

**`.claude/commands/orchestrate.md`** (394 lines)

The command file that implements:
- Multi-task mode parsing (single, comma-separated, range, mixed)
- Dependency graph construction (intra-batch only)
- Topological wave assignment (Kahn's algorithm)
- Wave execution with parallel dispatch (up to 8 tasks per batch)
- Single-task gate-in/gate-out/commit checkpoints
- Permissive gate (does not require plan file)
- Anti-bypass constraint: All lifecycle phases MUST delegate to `skill-orchestrate`

**Path dependencies to port**:
- `.claude/scripts/parse-command-args.sh` -> `.opencode/scripts/parse-command-args.sh`
- `.claude/scripts/command-gate-in.sh` -> `.opencode/scripts/command-gate-in.sh`
- `.claude/scripts/command-gate-out.sh` -> `.opencode/scripts/command-gate-out.sh`
- `Agent` tool -> `Task` tool (OpenCode uses `Task` tool for subagent dispatch)
- `skill-orchestrate` invocation unchanged (after skill is ported)

**Porting approach**: Port with sed substitutions for paths and tool name. The dependency-graph construction (Kahn's algorithm) and wave execution logic are path-independent.

#### Component 2: `skill-orchestrate` (HIGH PRIORITY - CORE)

**`.claude/skills/skill-orchestrate/SKILL.md`** (1129 lines)

The autonomous lifecycle state machine with these stages:
- Stage 0: Multi-Task Mode Detection
- Stage 1: Input Validation
- Stage 1b: Resolve Task-Type Routing
- Stage 2: Preflight (Loop Guard)
- Stage 3: State Machine Loop
- Stage 4: State Handlers (not_started, researching, researched, planned, implementing, partial, blocked, completed, abandoned, expanded)
- Stage 5: Handoff Reading
- Stage 5a: Drift Inspection Function
- Stage 6: Blocker Escalation (5-Step Sequence)
- Stage 7: Loop Guard Update
- Stage 8: Postflight
- Multi-Task Mode (MT-1 through MT-5)

**Path dependencies to port**:
- `.claude/scripts/skill-base.sh` -> `.opencode/scripts/skill-base.sh` (already ported by task 633)
- `.claude/scripts/dispatch-agent.sh` -> `.opencode/scripts/dispatch-agent.sh` (already ported)
- `.claude/docs/architecture/orchestrate-state-machine.md` -> `.opencode/docs/architecture/orchestrate-state-machine.md` (MISSING - needs porting)
- `.claude/docs/architecture/handoff-schema.md` -> `.opencode/docs/architecture/handoff-schema.md` (MISSING - verify)
- `.claude/docs/architecture/dispatch-agent-spec.md` -> `.opencode/docs/architecture/dispatch-agent-spec.md` (MISSING - verify)
- `Agent` tool -> `Task` tool (semantic equivalence for subagent dispatch)
- `wezterm-notify.sh` / `tts-notify.sh` lifecycle notifications: REMOVE (Claude-Code-specific, OpenCode has its own notification pipeline - per task 633 decision)

**Porting approach**: This is the largest single component. The state machine logic is path-independent but has many embedded `.claude/` references. Recommend porting in sub-phases:
- Phase A: Port the single-task state machine (Stages 0-8) with path substitutions
- Phase B: Port the multi-task mode (MT-1 through MT-5)
- Phase C: Port the drift inspection and blocker escalation functions
- Phase D: Verify with task 633's shared infrastructure

#### Component 3: `skill-orchestrator` (MEDIUM PRIORITY - ALIGNMENT)

**`.claude/skills/skill-orchestrator/SKILL.md`** (160 lines) vs `.opencode/skills/skill-orchestrator/SKILL.md` (128 lines)

Both are routing skills with the same structure but different lengths. Differences:
- `.claude/` version has 160 lines with: targeted jq extraction examples, MUST NOT (Context Protection) section, references `@.claude/context/patterns/context-protective-lead.md`
- `.opencode/` version has 128 lines without: targeted extraction examples, no MUST NOT (Context Protection) section, references `@.opencode/context/standards/postflight-tool-restrictions.md`
- Both have MUST NOT (Postflight Boundary) section
- `.claude/` has more detailed task-type routing table including extension types (lean4, neovim, nix)
- `.opencode/` has simpler task-type table (general, meta, markdown only)

**Porting approach**: The `.opencode/` version is functional but lacks context protection directives. Could either:
- Option A: Leave as-is (functional parity for current needs)
- Option B: Add the context protection MUST NOT section from `.claude/`
- Option C: Add the extension task-type routing logic from `.claude/`

Recommend Option A for this port, with Option B/C deferred to a follow-up task. The skill is a thin router and the core routing logic is already equivalent.

#### Component 4: Orchestrator architecture doc (HIGH PRIORITY)

**`.claude/docs/architecture/orchestrate-state-machine.md`** exists in `.claude/docs/architecture/`. Need to check if `.opencode/docs/architecture/` has an equivalent or needs one.

**Path dependencies**: The doc is referenced by `skill-orchestrate` SKILL.md for "Complete state table and transition diagram". If porting the skill, the doc must also be ported.

**Porting approach**: Copy with path substitutions. The doc is descriptive and path-independent in content.

#### Component 5: `.opencode/agent/orchestrator.md` (LOW PRIORITY - SEPARATE CONCERN)

**`.opencode/agent/orchestrator.md`** (124 lines) is mislabeled - it documents a "Read-only chat agent" (for question answering) but uses the filename "orchestrator.md". This is a separate concept from the orchestrator system (the lifecycle state machine) and not directly related to this porting task.

**Recommendation**: Flag as a context gap / follow-up task, not part of this port. The file should either be renamed (e.g., `chat-agent.md` or `repo-assistant-agent.md`) or its contents should be updated to match its name.

#### Component 6: Handoff schema doc (HIGH PRIORITY)

**`.claude/docs/architecture/handoff-schema.md`** - referenced by `skill-orchestrate` for "Orchestrator handoff JSON schema". Need to check if this exists in `.opencode/`.

**Porting approach**: Copy with path substitutions if missing.

#### Component 7: Dispatch agent spec (MEDIUM PRIORITY)

**`.claude/docs/architecture/dispatch-agent-spec.md`** - referenced by `skill-orchestrate` for "Fork vs. named subagent dispatch spec". Need to check if this exists in `.opencode/`.

**Porting approach**: Copy with path substitutions if missing. Note: The OpenCode system uses `Task` tool while Claude Code uses `Agent` tool; the spec semantics may need adaptation.

### Architectural Differences to Respect

| Aspect | `.claude/` | `.opencode/` |
|--------|-----------|--------------|
| Subagent tool | `Agent` tool | `Task` tool |
| State tracking | `~/.claude/projects/` | `~/.opencode/projects/` |
| Lifecycle notifications | `wezterm-notify.sh` / `tts-notify.sh` | OpenCode notification pipeline |
| Team mode env | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` |
| Script paths | `.claude/scripts/` | `.opencode/scripts/` |
| Context docs | `.claude/docs/architecture/` | `.opencode/docs/architecture/` |
| Specs prefix | `specs/{NNN}_SLUG/` | `specs/OC_{NNN}_SLUG/` (per `.claude/CLAUDE.md` rule) |

### Porting Complexity Assessment

| Component | Lines | Complexity | Approach |
|-----------|-------|------------|----------|
| `commands/orchestrate.md` | 394 | Medium | Sed for paths + manual review for tool names |
| `skill-orchestrate/SKILL.md` | 1129 | High | Multi-phase port (single-task, multi-task, escalation, drift) |
| `skill-orchestrator/SKILL.md` (alignment) | 160 vs 128 | Low | Optional context-protection additions |
| `orchestrate-state-machine.md` | TBD | Low | Copy with path substitutions |
| `handoff-schema.md` | TBD | Low | Copy with path substitutions |
| `dispatch-agent-spec.md` | TBD | Medium | Copy with tool name adaptations |

### Memory Context

`.memory/10-Memories/MEM-agent-system-reload-propagation.md` notes that "Agent system changes in nvim-config propagate to child projects (ProofChecker etc.) by reloading via `<leader>al` -- no separate porting tasks needed." However, this applies to **child project propagation**, not to the `.opencode/` system itself. The `.opencode/` system is a separate installation in the same repository, not a child project, so it requires explicit porting.

## Decisions

1. **Port `skill-orchestrate` (the state machine)**: It is a critical lifecycle component; `.opencode/` users currently cannot use `/orchestrate` because both the command and the skill are missing. The state machine provides autonomous task execution that is the hallmark of the `.claude/` system.

2. **Port the `/orchestrate` command**: Without the command file, the skill is unreachable. Port with the multi-task wave dispatch and dependency-aware logic preserved.

3. **Port the architecture docs (`orchestrate-state-machine.md`, `handoff-schema.md`, `dispatch-agent-spec.md`)**: The skill SKILL.md `@-references` these docs. Porting the skill without the docs would create broken context references.

4. **Do NOT modify `.opencode/agent/orchestrator.md`**: This file is a separate concern (mislabeled chat agent), not part of the orchestrator system being ported. Flag for follow-up task, not part of this port.

5. **Leave `skill-orchestrator` (routing) as-is for now**: The `.opencode/` version is functional. Context-protection additions can be a follow-up.

6. **Strip Claude-Code-specific lifecycle notifications**: The `.claude/` version of `postflight-workflow.sh` includes `wezterm-notify.sh` / `tts-notify.sh` PHASE 5 calls. The `.opencode/` port of this script (from task 633) omits these. The orchestrator skill should not reference them either - rely on OpenCode's notification pipeline.

7. **Adapt `Agent` -> `Task` tool references**: The orchestrator skill's subagent dispatch uses `Agent` tool. In OpenCode, this becomes the `Task` tool. The semantics (named subagent, fork) are equivalent.

8. **Preserve multi-task mode functionality**: The wave-based dependency dispatch is a core value-add of the orchestrator. Port the multi-task mode (MT-1 through MT-5) along with the single-task mode.

9. **Respect MAX_TASKS guard (8 tasks per batch)**: Same limit as `.claude/`. Trimming logic for batches exceeding MAX_TASKS is portable.

## Recommendations

### Priority Tiers

**Tier 1: Critical (Must Port for /orchestrate to work)**
- `commands/orchestrate.md` - 394 lines, the entry point
- `skill-orchestrate/SKILL.md` - 1129 lines, the state machine

**Tier 2: Required Documentation (Referenced by the skill)**
- `docs/architecture/orchestrate-state-machine.md` - state table and transition diagram
- `docs/architecture/handoff-schema.md` - JSON schema for orchestrator handoffs
- `docs/architecture/dispatch-agent-spec.md` - dispatch semantics

**Tier 3: Optional Alignment (Nice to have)**
- `skill-orchestrator/SKILL.md` - add context-protection MUST NOT section (defer to follow-up)

**Tier 4: Out of Scope (Flag for follow-up)**
- `.opencode/agent/orchestrator.md` - mislabeled chat agent (separate concern)

### Porting Approach by Component

| Component | Method | Notes |
|-----------|--------|-------|
| `orchestrate.md` command | sed path substitution + manual tool name fix | Path-independent logic, can copy with `sed -i 's\|\.claude/\|\.opencode/\|g'` and `Agent tool` -> `Task tool` |
| `skill-orchestrate/SKILL.md` | Multi-phase manual port | 1129 lines, too complex for single sed pass; recommend sub-phases A-D as listed above |
| Architecture docs | sed path substitution | Descriptive content, low complexity |
| `skill-orchestrator` (alignment) | Manual additions | Add `MUST NOT (Context Protection)` section |

### Verification Plan

After porting:
1. **Syntax check**: Ensure all SKILL.md files have valid frontmatter
2. **Path audit**: `grep -r '\.claude/' .opencode/` (should return no orchestrator-related matches)
3. **Tool name audit**: `grep -r 'Agent tool' .opencode/skills/skill-orchestrate/ .opencode/commands/orchestrate.md` (should be empty)
4. **Reference integrity**: All `@-references` in ported files must resolve in `.opencode/`
5. **Behavioral test**: Run `/orchestrate` on a simple task in `.opencode/` to verify end-to-end

### Phased Implementation

**Phase 1: Architecture docs** (foundation, no dependencies)
- Port `orchestrate-state-machine.md`, `handoff-schema.md`, `dispatch-agent-spec.md` to `.opencode/docs/architecture/`
- Estimated: 1-2 hours

**Phase 2: `skill-orchestrate` skill** (depends on Phase 1)
- Port the 1129-line skill in sub-phases A-D
- Verify each sub-phase independently
- Estimated: 3-4 hours

**Phase 3: `/orchestrate` command** (depends on Phase 2)
- Port `commands/orchestrate.md`
- Verify single-task and multi-task paths
- Estimated: 1-2 hours

**Phase 4: Verification** (depends on Phases 1-3)
- Path audit, tool name audit, reference integrity check
- End-to-end test with a simple task
- Estimated: 1 hour

**Total estimated effort**: 6-9 hours

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `skill-orchestrate` is large and complex (1129 lines); manual port may miss edge cases | High | High | Port in sub-phases A-D, verify each independently, test end-to-end |
| Multi-task wave dispatch logic has subtle Kahn's algorithm details | Medium | High | Keep the algorithm structure unchanged, only port paths and tool names |
| `.opencode/` postflight workflow differs from `.claude/` (no wezterm-notify) | Low | Low | Already addressed in task 633; ensure orchestrator skill doesn't reference the removed hooks |
| `Agent` tool -> `Task` tool semantic differences (subagent_type vs other params) | Medium | Medium | Verify with a test dispatch before completing port |
| State tracking location differs (`~/.claude/` vs `~/.opencode/`) | Low | Low | Update path references; session_id format is identical |
| `.claude/skills/skill-orchestrator/SKILL.md.archived` exists - verify `.opencode/` doesn't have a similar archival | Low | Low | Investigate during Phase 2; the archived file is a previous version, not relevant to port |
| Loop guard file location and format | Low | Low | Currently uses `${TASK_DIR}/.orchestrator-loop-guard` which is task-relative; no path change needed |
| Drift inspection threshold values (0.70 / 0.30) - confirm they work for OpenCode | Low | Low | Port unchanged; tune if needed after testing |
| MAX_BLOCKER_ESCALATIONS=2 and MAX_CYCLES=5 limits - confirm appropriate | Low | Low | Port unchanged; tune if needed after testing |

## Context Extension Recommendations

- **Topic**: Orchestrator system porting patterns
- **Gap**: No documented standard for porting the multi-stage lifecycle state machine (skill-orchestrate) between `.claude/` and `.opencode/`. The 1129-line SKILL.md has many path dependencies and tool-specific references that require careful sequencing.
- **Recommendation**: Create `.opencode/context/standards/orchestrator-porting-guide.md` documenting the multi-phase porting approach (A-D sub-phases), the path substitution patterns specific to the state machine, and the verification checklist. This would benefit future orchestrator-related work and reduce risk of drift between the two systems.

- **Topic**: Mislabeled orchestrator chat agent
- **Gap**: `.opencode/agent/orchestrator.md` documents a "Read-only chat agent" but uses the orchestrator filename. This is a separate concept from the lifecycle state machine and may cause confusion.
- **Recommendation**: Create a follow-up meta task to either rename the file (e.g., `repo-assistant-agent.md` or `chat-agent.md`) or update its content to match the orchestrator naming. This is out of scope for task 634 but should be tracked separately.

## Appendix

### Search Queries Used

- `ls .claude/agents/ .opencode/agent/ -la` for subagent inventory
- `ls .claude/skills/skill-orchestrate/ .claude/skills/skill-orchestrator/ .opencode/skills/skill-orchestrator/` for skill inventory
- `ls .claude/commands/ .opencode/commands/ -la` to identify the missing `orchestrate.md` in `.opencode/`
- `find .claude -name "*orchestrate*"` and `find .opencode -name "*orchestrate*"` for all orchestrate-related files
- `diff .claude/docs/architecture/system-overview.md .opencode/docs/architecture/system-overview.md` for system overview comparison
- `cat specs/state.json` to identify dependency chain (633->634->635->636->637)
- `cat specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` for predecessor context

### Component Line Counts

| Component | `.claude/` | `.opencode/` | Gap |
|-----------|-----------|--------------|-----|
| `orchestrate.md` command | 394 lines | 0 (missing) | -394 |
| `skill-orchestrate` skill | 1129 lines | 0 (missing) | -1129 |
| `skill-orchestrator` skill | 160 lines | 128 lines | -32 (optional alignment) |
| `orchestrate-state-machine.md` | (verify) | (missing) | TBD |
| `handoff-schema.md` | (verify) | (missing) | TBD |
| `dispatch-agent-spec.md` | (verify) | (missing) | TBD |

### Key References in `.claude/skills/skill-orchestrate/SKILL.md`

```
@.claude/docs/architecture/orchestrate-state-machine.md   - architecture doc
@.claude/docs/architecture/handoff-schema.md              - handoff schema
@.claude/docs/architecture/dispatch-agent-spec.md         - dispatch spec
source .claude/scripts/skill-base.sh                      - lifecycle functions
source .claude/scripts/dispatch-agent.sh                  - dispatch functions
```

These references are embedded in code blocks (not `@-references` in the strict sense) but the doc references at the top of the file are `@-references` and would need to be updated during port.

### Related Task Artifacts

- **Task 633 (predecessor)**: `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` - Documents 17 missing scripts ported, 5 stale scripts updated, dependency-driven approach
- **Task 633 summary**: `specs/633_port_core_script_infrastructure/summaries/01_core_script_infra-summary.md` - Implementation summary
- **Task 635 (successor)**: `specs/635_port_synthesis_domain_agents/` - Will port synthesis-agent (related to team research synthesis)
- **Task 636**: `specs/636_sync_context_rules_extensions_cleanup/` - Cleanup after all ports complete
- **Task 637**: `specs/637_verification_and_drift_detection/` - Final verification

### Architectural Standard: Dependency-Driven Porting (from task 633)

Per task 633's approach: when porting complex systems, use a dependency-driven phase ordering:
1. Port infrastructure dependencies first (in this case, architecture docs)
2. Port foundational components (the state machine skill)
3. Port dependent components (the command file)
4. Verify end-to-end

This pattern was successful for task 633 and is recommended for task 634.
