# Implementation Plan: Port Core Script Infrastructure

- **Task**: 633 - port_core_script_infrastructure
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: None (infrastructure port, no upstream task dependencies)
- **Research Inputs**: specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md
- **Artifacts**: plans/01_core_script_infra_plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Port 17 missing scripts from `.claude/scripts/` to `.opencode/scripts/` and update 5 stale `.opencode/` scripts, respecting the architectural differences between the two systems. Scripts are organized into complexity tiers (critical infrastructure, workflow, review components, validation) with dependency-driven phase ordering: foundational scripts like `skill-base.sh` must be ported first since other scripts depend on them, and `update-task-status.sh` must be updated before any script that calls it. The 26 byte-identical shared scripts between the two systems require no action, and the 15 `.opencode/`-unique scripts must be preserved untouched.

### Research Integration

The research report (01_core_script_infra_research.md) identifies: 17 missing scripts organized into 4 complexity tiers, 5 stale `.opencode/` scripts needing updates, 6 architectural differences requiring path substitutions (directory naming, tool names, temp file conventions, env vars), and dependency chains (`skill-base.sh` -> gateway scripts -> postflight wrappers; `generate-task-order.sh` -> `vault-operation.sh`). Key path substitutions: `.claude/` -> `.opencode/`, `.claude/agents/` -> `.opencode/agent/subagents/`, `Agent tool` -> `Task tool`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is infrastructure work that supports the broader system quality goals (Phase 1: Agent System Quality) by ensuring both agent systems share a consistent script foundation, reducing drift and unblocking future `.opencode/` development.

## Goals & Non-Goals

**Goals**:
- Port all 17 missing scripts from `.claude/scripts/` to `.opencode/scripts/` with correct path substitutions
- Update 5 stale `.opencode/` scripts (3 postflight wrappers, update-task-status.sh, update-plan-status.sh) to match current `.claude/` standards
- Replace standalone postflight implementations with thin-wrapper pattern (call `postflight-workflow.sh`)
- Preserve all 15 `.opencode/`-unique scripts untouched
- Run `.opencode/` validation scripts post-port and confirm zero regressions

**Non-Goals**:
- Change `.opencode/` task ordering system (keep `update-recommended-order.sh` as active; `generate-task-order.sh` is ported but coexists)
- Modify `.claude/` scripts (source of truth, read-only)
- Delete `update-recommended-order.sh` (`.opencode/` uses different topological approach)
- Port `/review` command infrastructure (the review scripts are data processors ported for future use; the `/review` slash command itself is not in scope)
- Modify byte-identical shared scripts (26 scripts require no work)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `skill-base.sh` adaptation is complex (516 lines) and introduces bugs | High | Medium | Port incrementally: verify each function independently. Keep `.claude/` version as reference during implementation. Test with a dry-run invocation. |
| `update-task-status.sh` merge breaks `.opencode/` task ordering integration with `update-recommended-order.sh` | High | Medium | Apply `.claude/` improvements line-by-line rather than wholesale replacement. Preserve `.opencode/`'s `update-recommended-order.sh` integration path. |
| Path substitution misses edge cases (e.g., nested `.claude/` references in variable names) | Medium | Medium | Run `grep -rn '\.claude/' .opencode/scripts/` post-port in Phase 6 verification. Also check for `~/.claude/`, `agents/` (standalone), and `CLAUDE_CODE` references. |
| `dispatch-agent.sh` tool name incompatibility (`Agent` vs `Task`) | High | High | Verify `.opencode/` subagent dispatch API before porting. If `Task` tool semantics differ materially, flag as BLOCKED and document the gap. |
| Temp file convention conflict (`.tmp` suffix vs `specs/tmp/` directory) | Medium | Medium | Audit all ported scripts for temp file usage in Phase 6. Enforce `specs/tmp/` convention for `.opencode/`. |
| Stale `.opencode/` postflight scripts have inline logic lost during thin-wrapper replacement | Low | Medium | Thin-wrapper replacement is architecturally safe (same API, same behavior). Diff the old implementations as a record before replacement. |
| 895-line `generate-task-order.sh` conflicts with existing 708-line `update-recommended-order.sh` | Low | Low | Port both, document which is active. `generate-task-order.sh` coexists unused until a future decision on convergence. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Stale Dependency Scripts [COMPLETED]

**Goal**: Update the two stale scripts that other ported scripts depend on (`update-task-status.sh` and `update-plan-status.sh`). This phase must complete before any other porting work begins.

**Tasks**:
- [ ] Diff `.opencode/scripts/update-task-status.sh` against `.claude/scripts/update-task-status.sh` to identify gaps (revise support, full tree regeneration, generate-task-order.sh integration)
- [ ] Apply `.claude/` improvements to `.opencode/scripts/update-task-status.sh` line-by-line, preserving `.opencode/`'s `update-recommended-order.sh` integration path
- [ ] Verify the updated `update-task-status.sh` handles all status transitions: RESEARCHED, PLANNED, IMPLEMENTING, COMPLETED, BLOCKED, PARTIAL, ABANDONED, and the new `revise` operation
- [ ] Diff `.opencode/scripts/update-plan-status.sh` against `.claude/scripts/update-plan-status.sh` to identify gaps (PLANNED status normalization, better error messages)
- [ ] Apply `.claude/` improvements to `.opencode/scripts/update-plan-status.sh`
- [ ] Verify both scripts are executable (`chmod +x`)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.opencode/scripts/update-task-status.sh` - Add revise support, full tree regeneration, improved status transition handling
- `.opencode/scripts/update-plan-status.sh` - Add PLANNED status normalization, improved error messages

**Verification**:
- `bash .opencode/scripts/update-task-status.sh --help` shows revise option
- `bash .opencode/scripts/update-plan-status.sh --help` shows PLANNED handling
- Both scripts pass shellcheck (`shellcheck .opencode/scripts/update-*-status.sh`)
- Dry-run status transitions succeed without modifying actual state.json

---

### Phase 2: Port Critical Foundational Scripts [COMPLETED]

**Goal**: Port the 5 sourceable/standalone scripts that form the core infrastructure foundation. `skill-base.sh` is the most critical -- it provides the shared lifecycle functions that all skills use. The other 4 scripts (`command-gate-in.sh`, `command-route-skill.sh`, `parse-command-args.sh`, `postflight-workflow.sh`) form the command checkpoint infrastructure.

**Tasks**:
- [ ] Port `.claude/scripts/skill-base.sh` (516 lines) -- the most complex adaptation:
  - Run `sed` for path substitutions: `.claude/` -> `.opencode/`, `.claude/skills/` -> `.opencode/skills/`, `.claude/agents/` -> `.opencode/agent/subagents/`, `.claude/extensions/` -> `.opencode/extensions/`, `.claude/context/` -> `.opencode/context/`, `~/.claude/` -> `~/.opencode/`
  - Manually review all function signatures for `.claude/` hardcoded references in extension discovery, context budget management, and handoff schema paths
  - Verify `update-task-status.sh` calls use the Phase 1 version with revised interface
  - Adjust `Agent` tool references to `Task` tool where present
- [ ] Port `.claude/scripts/command-gate-in.sh` (73 lines):
  - `sed` path substitutions, adjust session cleanup cache from `~/.claude/` to `~/.opencode/`
  - Verify task directory prefix conventions (both systems use unpadded `{NNN}_SLUG/`)
- [ ] Port `.claude/scripts/command-route-skill.sh` (66 lines):
  - `sed` for `.claude/extensions/` -> `.opencode/extensions/` path, adjust extension manifest lookup
- [ ] Port `.claude/scripts/parse-command-args.sh` (135 lines):
  - Pure argument parsing, minimal changes. Adjust `--team` env var from `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- [ ] Port `.claude/scripts/postflight-workflow.sh` (137 lines):
  - `sed` path substitutions, adjust temp file handling from `.tmp` suffix to `specs/tmp/` directory convention
  - Verify `.opencode/context/patterns/jq-escaping-workarounds.md` exists (referenced by the script)

**Timing**: 2 hours

**Depends on**: 1

**Files to create**:
- `.opencode/scripts/skill-base.sh` - Port from `.claude/scripts/skill-base.sh`
- `.opencode/scripts/command-gate-in.sh` - Port from `.claude/scripts/command-gate-in.sh`
- `.opencode/scripts/command-route-skill.sh` - Port from `.claude/scripts/command-route-skill.sh`
- `.opencode/scripts/parse-command-args.sh` - Port from `.claude/scripts/parse-command-args.sh`
- `.opencode/scripts/postflight-workflow.sh` - Port from `.claude/scripts/postflight-workflow.sh`

**Verification**:
- `bash -n .opencode/scripts/skill-base.sh` (syntax check)
- `source .opencode/scripts/skill-base.sh && type -t preflight` returns `function`
- `source .opencode/scripts/command-gate-in.sh && type -t generate_session_id` returns `function`
- `bash -n .opencode/scripts/postflight-workflow.sh`
- All scripts pass `shellcheck` (or document intentional exceptions)
- Grep for any remaining `.claude/` hardcoded paths: `grep -rn '\.claude/' .opencode/scripts/skill-base.sh`

---

### Phase 3: Port Gateway Scripts and Update Postflight Wrappers [COMPLETED]

**Goal**: Port the gateway scripts (`command-gate-out.sh`, `dispatch-agent.sh`) that depend on the foundational scripts from Phase 2, and update the 3 stale postflight scripts to thin wrappers around `postflight-workflow.sh`.

**Tasks**:
- [ ] Port `.claude/scripts/command-gate-out.sh` (82 lines):
  - `sed` path substitutions, verify calls to `update-task-status.sh` and `validate-artifact.sh` point to `.opencode/` equivalents
- [ ] Port `.claude/scripts/dispatch-agent.sh` (128 lines):
  - Critical: verify `.opencode/` subagent dispatch API matches `.claude/`'s `Agent` tool. If `Task` tool has different semantics, adapt or flag as BLOCKED
  - `sed` for `.claude/docs/architecture/dispatch-agent-spec.md` -> `.opencode/docs/architecture/dispatch-agent-spec.md`
  - Adjust tool name references from `Agent` to `Task`
- [ ] Update `.opencode/scripts/postflight-research.sh` (69 lines -> thin wrapper ~12 lines):
  - Backup the current 69-line implementation to `.opencode/scripts/postflight-research.sh.bak`, replace with thin wrapper calling `postflight-workflow.sh research`
- [ ] Update `.opencode/scripts/postflight-plan.sh` (same pattern):
  - Backup to `.opencode/scripts/postflight-plan.sh.bak`, replace with thin wrapper calling `postflight-workflow.sh plan`
- [ ] Update `.opencode/scripts/postflight-implement.sh` (same pattern):
  - Backup to `.opencode/scripts/postflight-implement.sh.bak`, replace with thin wrapper calling `postflight-workflow.sh implement`

**Timing**: 1.5 hours

**Depends on**: 2

**Files to create**:
- `.opencode/scripts/command-gate-out.sh` - Port from `.claude/scripts/command-gate-out.sh`
- `.opencode/scripts/dispatch-agent.sh` - Port from `.claude/scripts/dispatch-agent.sh`

**Files to modify**:
- `.opencode/scripts/postflight-research.sh` - Replace stale standalone with thin wrapper
- `.opencode/scripts/postflight-plan.sh` - Replace stale standalone with thin wrapper
- `.opencode/scripts/postflight-implement.sh` - Replace stale standalone with thin wrapper

**Verification**:
- `bash -n .opencode/scripts/command-gate-out.sh` (syntax check)
- `bash -n .opencode/scripts/dispatch-agent.sh` (syntax check)
- Postflight thin wrappers are syntactically valid: `bash -n .opencode/scripts/postflight-*.sh`
- Thin wrappers call `postflight-workflow.sh` with correct argument (`research`, `plan`, `implement`)
- Backup files preserve the original implementations: `ls .opencode/scripts/postflight-*.sh.bak`

---

### Phase 4: Port Tier 2 Workflow Scripts [COMPLETED]

**Goal**: Port the workflow infrastructure scripts that depend on the foundational scripts from Phase 2 and the gateway scripts from Phase 3. Includes task ordering, archival, orphan detection, and memory harvesting.

**Tasks**:
- [ ] Port `.claude/scripts/generate-task-order.sh` (895 lines):
  - `sed` path substitutions, adjust `.claude/context/formats/task-order-format.md` -> `.opencode/context/formats/task-order-format.md`
  - Verify the generated TODO.md Task Order section format matches `.opencode/` conventions
  - Note: this script coexists with `.opencode/scripts/update-recommended-order.sh`; both should work but `update-recommended-order.sh` remains active
- [ ] Port `.claude/scripts/archive-task.sh` (179 lines):
  - `sed` for `specs/state.json` and `specs/archive/state.json` paths (both systems use same paths)
  - `sed` for `specs/archive/` and `specs/TODO.md` paths
  - Verify task directory convention (both systems use unpadded `{NNN}_SLUG/`)
- [ ] Port `.claude/scripts/orphan-detection.sh` (142 lines):
  - Pure filesystem scanning, minimal changes. Verify `specs/` directory scanning works with `.opencode/` task directory conventions
- [ ] Port `.claude/scripts/memory-harvest.sh` (190 lines):
  - `sed` for `.memory/10-Memories/` and `.memory/memory-index.json` paths (both systems share `.memory/`)
  - Verify `memory-retrieve.sh` integration uses `.opencode/scripts/memory-retrieve.sh`

**Timing**: 1.5 hours

**Depends on**: 3

**Files to create**:
- `.opencode/scripts/generate-task-order.sh` - Port from `.claude/scripts/generate-task-order.sh`
- `.opencode/scripts/archive-task.sh` - Port from `.claude/scripts/archive-task.sh`
- `.opencode/scripts/orphan-detection.sh` - Port from `.claude/scripts/orphan-detection.sh`
- `.opencode/scripts/memory-harvest.sh` - Port from `.claude/scripts/memory-harvest.sh`

**Verification**:
- `bash -n` passes on all 4 scripts
- `shellcheck` passes on all 4 scripts (or document exceptions)
- `grep -rn '\.claude/' .opencode/scripts/generate-task-order.sh` returns 0 results
- `grep -rn '\.claude/' .opencode/scripts/archive-task.sh` returns 0 results
- `grep -rn '\.claude/' .opencode/scripts/orphan-detection.sh` returns 0 results
- `grep -rn '\.claude/' .opencode/scripts/memory-harvest.sh` returns 0 results

---

### Phase 5: Port Tier 3/4 Review and Validation Scripts [COMPLETED]

**Goal**: Port the remaining 5 scripts: `/review` components (path-independent data processors) and the validation script. `vault-operation.sh` in this wave depends on `generate-task-order.sh` from Phase 4.

**Tasks**:
- [ ] Port `.claude/scripts/roadmap-integration.sh` (466 lines):
  - Mostly path-independent (references ROADMAP.md and state.json), `sed` for any `.claude/` references
- [ ] Port `.claude/scripts/issue-grouping.sh` (401 lines):
  - Pure data processing, minimal changes needed
- [ ] Port `.claude/scripts/tier-selection.sh` (306 lines):
  - Pure data processing, minimal changes needed
- [ ] Port `.claude/scripts/roadmap-sync.sh` (331 lines):
  - `sed` for ROADMAP.md and state.json paths, verify `.opencode/` conventions
- [ ] Port `.claude/scripts/validate-context-budgets.sh` (226 lines):
  - `sed` for `.claude/context/index.json` -> `.opencode/context/index.json`
  - Verify agent token budget caps are appropriate for `.opencode/` agents
- [ ] Port `.claude/scripts/vault-operation.sh` (247 lines):
  - `sed` path substitutions, adjust `generate-task-order.sh` dependency to point to `.opencode/scripts/generate-task-order.sh`
  - Verify `specs/vault/` path conventions (both systems use same directory)

**Timing**: 1.5 hours

**Depends on**: 4

**Files to create**:
- `.opencode/scripts/roadmap-integration.sh` - Port from `.claude/scripts/roadmap-integration.sh`
- `.opencode/scripts/issue-grouping.sh` - Port from `.claude/scripts/issue-grouping.sh`
- `.opencode/scripts/tier-selection.sh` - Port from `.claude/scripts/tier-selection.sh`
- `.opencode/scripts/roadmap-sync.sh` - Port from `.claude/scripts/roadmap-sync.sh`
- `.opencode/scripts/validate-context-budgets.sh` - Port from `.claude/scripts/validate-context-budgets.sh`
- `.opencode/scripts/vault-operation.sh` - Port from `.claude/scripts/vault-operation.sh`

**Verification**:
- `bash -n` passes on all 6 scripts
- `shellcheck` passes on all 6 scripts (or document exceptions)
- `grep -rn '\.claude/' .opencode/scripts/validate-context-budgets.sh` returns 0 results (critical: references index.json correctly)
- `grep -rn '\.claude/' .opencode/scripts/vault-operation.sh` returns 0 results
- `vault-operation.sh` correctly references `.opencode/scripts/generate-task-order.sh` (not `.claude/`)

---

### Phase 6: Verification and Cleanup [COMPLETED]

**Goal**: Run comprehensive verification across all 22 ported/updated scripts (17 new + 5 updated), ensure zero regressions, and run `.opencode/` validation scripts.

**Tasks**:
- [ ] Global grep for stale `.claude/` references across all `.opencode/scripts/`:
  - `grep -rn '\.claude/' .opencode/scripts/` -- verify only intentional references remain (e.g., shared scripts that reference the source .claude/ system, or doc comments)
  - `grep -rn '~/.claude/' .opencode/scripts/` -- should return 0 results
  - `grep -rn 'CLAUDE_CODE_EXPERIMENTAL' .opencode/scripts/` -- verify only `.opencode/` scripts that truly need this env var
  - `grep -rn 'Agents/' .opencode/scripts/` -- check for bare agent directory references that should be `agent/subagents/`
- [ ] Verify all 17 new scripts are executable: `find .opencode/scripts/ -name '*.sh' -newer .opencode/scripts/update-task-status.sh -exec chmod +x {} \;`
- [ ] Verify the 5 updated scripts are executable
- [ ] Verify `.opencode/`-unique scripts are untouched: diff original inventory against current state
- [ ] Run `.opencode/` validation scripts:
  - `bash .opencode/scripts/validate-routing-tables.sh` -- ensure extension routing is intact
  - `bash .opencode/scripts/validate-docs.sh` -- ensure no stale `.claude/` references leak into `.opencode/` docs
  - `bash .opencode/scripts/check-command-drift.sh` -- ensure commands haven't drifted
- [ ] Verify temp file conventions: audit all ported scripts for `specs/tmp/` usage where `.opencode/` convention requires it
- [ ] Verify `update-recommended-order.sh` is preserved and unchanged (`.opencode/` active task ordering system)
- [ ] Confirm 26 shared scripts are unchanged: `diff` against `.claude/` counterparts where possible

**Timing**: 0.5 hours

**Depends on**: 5

**Files to verify (no modifications needed for these)**:
- `.opencode/scripts/update-recommended-order.sh` - Must be UNCHANGED
- All 26 shared scripts - Must be UNCHANGED
- All 15 `.opencode/`-unique scripts - Must be UNCHANGED

**Verification**:
- Global grep returns 0 unexpected `.claude/` references
- All 3 `.opencode/` validation scripts pass
- All 22 ported/updated scripts are executable and pass syntax check
- Inventory diff confirms no accidental overwrites of `.opencode/`-unique or shared scripts

## Testing & Validation

- [ ] All 17 new scripts pass `bash -n` syntax check
- [ ] All 5 updated scripts pass `bash -n` syntax check
- [ ] All scripts pass `shellcheck` (or document intentional exceptions)
- [ ] `skill-base.sh` functions load correctly (`preflight`, `postflight`, etc.)
- [ ] Postflight thin wrappers correctly delegate to `postflight-workflow.sh`
- [ ] `dispatch-agent.sh` tool name (`Task`) is validated against `.opencode/` subagent API
- [ ] `.opencode/scripts/validate-routing-tables.sh` passes (extension routing intact)
- [ ] `.opencode/scripts/validate-docs.sh` passes (no stale `.claude/` references)
- [ ] `.opencode/scripts/check-command-drift.sh` passes (no command drift)
- [ ] Global grep for `.claude/` references shows only intentional references
- [ ] `update-recommended-order.sh` is preserved unchanged
- [ ] All 15 `.opencode/`-unique scripts are preserved unchanged
- [ ] All 26 shared scripts remain byte-identical to `.claude/` counterparts (except intentional differences)

## Artifacts & Outputs

- `plans/01_core_script_infra_plan.md` - This implementation plan
- `.opencode/scripts/skill-base.sh` - Ported foundational skill lifecycle
- `.opencode/scripts/command-gate-in.sh` - Ported command preflight
- `.opencode/scripts/command-gate-out.sh` - Ported command postflight
- `.opencode/scripts/command-route-skill.sh` - Ported task-type routing
- `.opencode/scripts/parse-command-args.sh` - Ported argument parser
- `.opencode/scripts/dispatch-agent.sh` - Ported agent dispatch
- `.opencode/scripts/postflight-workflow.sh` - Ported unified postflight
- `.opencode/scripts/generate-task-order.sh` - Ported task order generator
- `.opencode/scripts/archive-task.sh` - Ported single-task archival
- `.opencode/scripts/orphan-detection.sh` - Ported orphan detector
- `.opencode/scripts/memory-harvest.sh` - Ported memory harvester
- `.opencode/scripts/roadmap-integration.sh` - Ported roadmap cross-reference
- `.opencode/scripts/issue-grouping.sh` - Ported issue clusterer
- `.opencode/scripts/tier-selection.sh` - Ported tiered issue selector
- `.opencode/scripts/roadmap-sync.sh` - Ported roadmap annotator
- `.opencode/scripts/validate-context-budgets.sh` - Ported context budget validator
- `.opencode/scripts/vault-operation.sh` - Ported vault archiver
- `.opencode/scripts/update-task-status.sh` - Updated with revise support
- `.opencode/scripts/update-plan-status.sh` - Updated with PLANNED normalization
- `.opencode/scripts/postflight-research.sh` - Updated thin wrapper
- `.opencode/scripts/postflight-plan.sh` - Updated thin wrapper
- `.opencode/scripts/postflight-implement.sh` - Updated thin wrapper
- `.opencode/scripts/postflight-*.sh.bak` - Backups of old standalone implementations

## Rollback/Contingency

If implementation fails or introduces regressions:
1. **Restore the 5 updated scripts from git**: `git checkout -- .opencode/scripts/update-task-status.sh update-plan-status.sh postflight-*.sh`
2. **Remove the 17 new scripts**: `rm .opencode/scripts/skill-base.sh command-gate-*.sh command-route-skill.sh parse-command-args.sh dispatch-agent.sh postflight-workflow.sh generate-task-order.sh archive-task.sh orphan-detection.sh memory-harvest.sh roadmap-*.sh issue-grouping.sh tier-selection.sh validate-context-budgets.sh vault-operation.sh`
3. **Verify `.opencode/` system still works**: Run validation scripts to confirm original state
4. **If `dispatch-agent.sh` proves incompatible with `.opencode/`'s `Task` tool**: Remove it, document the gap, and create a follow-up task for `.opencode/`-native dispatch

The `.claude/` system is the source of truth and remains untouched throughout this task. All work is additive or in-place update in `.opencode/` only.
