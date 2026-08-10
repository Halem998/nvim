# Research Report: Port Core Script Infrastructure

- **Task**: 633 - port_core_script_infrastructure
- **Started**: 2026-06-07T00:00:00Z
- **Completed**: 2026-06-07T00:15:00Z
- **Effort**: 2-3 hours
- **Dependencies**: None (infrastructure port, no upstream task dependencies)
- **Sources/Inputs**:
  - Codebase: `.claude/scripts/` (41 scripts + lint/), `.opencode/scripts/` (37 scripts + lint/)
  - Standards: `.claude/context/formats/report-format.md`
  - References: CLAUDE.md (agent system docs), AGENTS.md (.opencode/ system docs)
  - State: specs/ROADMAP.md
- **Artifacts**: `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md`
- **Standards**: report-format.md

## Executive Summary

- **17 scripts are missing** from `.opencode/scripts/` that exist in `.claude/scripts/` — these must be ported
- **5 scripts in `.opencode/` are stale/outdated** compared to their `.claude/` counterparts — these need updating
- **The 26 shared scripts are identical** (or nearly so) — the shared codebase is well-maintained
- **The `.opencode/` system has 15 unique scripts** not present in `.claude/` — these should be preserved
- **Architectural differences** center on directory naming (`.claude/` vs `.opencode/`), task numbering conventions, and tool names (Agent vs Task)
- **Porting approach**: Tier 1 (copy+sed path substitutions for simple scripts), Tier 2 (adaptations for moderate scripts), Tier 3 (merge/update stale scripts)

## Context & Scope

The `.claude/` agent system has undergone significant upgrades (tasks 594-599+) which introduced new scripts and modified existing ones. The `.opencode/` system needs to catch up with these improvements while respecting its distinct architectural conventions.

### Roadmap Context

From `specs/ROADMAP.md` Phase 1 priorities, this task is **not directly mapped** to any specific roadmap item but supports the broader system quality goals. It is infrastructure work that unblocks further `.opencode/` development.

### System Architecture Differences

| Aspect | `.claude/` | `.opencode/` |
|--------|-----------|--------------|
| Configuration root | `.claude/` | `.opencode/` |
| System doc | `CLAUDE.md` | `AGENTS.md` |
| Agent dir | `.claude/agents/` | `.opencode/agent/subagents/` |
| Skill dir | `.claude/skills/` (SKILL.md within) | `.opencode/skills/` |
| Extension dir | `.claude/extensions/` | `.opencode/extensions/` |
| Context index | `.claude/context/index.json` | `.opencode/context/index.json` |
| Task dir prefix | None (`specs/{NNN}_SLUG/`) | None (same, but OC_ prefix used elsewhere) |
| Temp files | `.tmp` suffix pattern | `specs/tmp/` directory |
| Subagent tool | `Agent` tool, `subagent_type` | `Task` tool, `subagent_type` |
| Cleanup cache | `~/.claude/` | `~/.opencode/` |
| Task order system | `generate-task-order.sh` (waves/DAG) | `update-recommended-order.sh` (topological) |
| Postflight pattern | Thin wrappers -> postflight-workflow.sh | Standalone implementations (stale) |
| Revise command | Supported | Not supported |
| Team mode env | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` |

## Findings

### Inventory: Both Systems

26 scripts exist in **both** `.claude/scripts/` and `.opencode/scripts/`:

```
check-extension-docs.sh        check-vault-threshold.sh        claude-cleanup.sh
claude-project-cleanup.sh      claude-refresh.sh               export-to-markdown.sh
install-aliases.sh             install-extension.sh            install-systemd-timer.sh
link-artifact-todo.sh          memory-retrieve.sh              migrate-directory-padding.sh
postflight-implement.sh        postflight-plan.sh              postflight-research.sh
rename-session.sh              setup-lean-mcp.sh               uninstall-extension.sh
update-plan-status.sh          update-task-status.sh           validate-artifact.sh
validate-context-index.sh      validate-extension-index.sh     validate-index.sh
validate-wiring.sh             verify-lean-mcp.sh
```

All 26 are **byte-identical or nearly so** between the two systems, except for:
- **`lint/lint-postflight-boundary.sh`**: One line differs (`Agent tool` vs `Task tool`)
- **`postflight-*.sh`**: `.opencode/` versions are **stale standalone implementations** (69 lines each), while `.claude/` versions are **thin wrappers** (12 lines) that delegate to `postflight-workflow.sh`
- **`update-task-status.sh`**: `.opencode/` version is older (353 lines) lacking `revise` support and full tree regeneration via `generate-task-order.sh`; `.claude/` version (410 lines) has both
- **`update-plan-status.sh`**: `.opencode/` version is older lacking `PLANNED` status normalization

### Category 1: Scripts Missing from `.opencode/` (17 scripts)

These scripts exist only in `.claude/scripts/` and must be ported.

#### High Complexity (500+ lines)

| Script | Lines | Purpose | `.claude/` Dependencies |
|--------|-------|---------|-------------------------|
| `generate-task-order.sh` | 895 | Generates Task Order section for TODO.md using Kahn's algorithm (dependency waves, topic-grouped trees) | References `.claude/context/formats/task-order-format.md`, depends on state.json structure |
| `skill-base.sh` | 516 | Shared skill lifecycle functions: preflight/postflight, context budget management, artifact validation, extension hook invocation, handoff schema | References `.claude/extensions.json`, `.claude/docs/architecture/handoff-schema.md`, calls `update-task-status.sh`, `validate-artifact.sh`, `link-artifact-todo.sh` |

#### Medium Complexity (200-500 lines)

| Script | Lines | Purpose | `.claude/` Dependencies |
|--------|-------|---------|-------------------------|
| `roadmap-integration.sh` | 466 | `/review` component: Parse ROADMAP.md, cross-reference with state, annotate completed items | Relatively path-independent, references ROADMAP.md and state.json |
| `issue-grouping.sh` | 401 | `/review` component: Cluster review/roadmap issues into coherent task proposals | Pure data processing, no hardcoded paths |
| `roadmap-sync.sh` | 331 | `/todo` component: Scan ROADMAP.md for task matches, apply completion annotations | References ROADMAP.md and state.json |
| `tier-selection.sh` | 306 | `/review` component: Interactive tiered issue selection, generates AskUserQuestion JSON | Pure data processing |
| `vault-operation.sh` | 247 | Execute vault archival when task numbering exceeds 1000 | Depends on `generate-task-order.sh`, references `specs/vault/` |
| `validate-context-budgets.sh` | 226 | Validates agent context budgets against tier caps | Hardcodes `.claude/context/index.json` default path |

#### Low Complexity (<200 lines)

| Script | Lines | Purpose | `.claude/` Dependencies |
|--------|-------|---------|-------------------------|
| `memory-harvest.sh` | 190 | Harvest memory candidates from state.json into memory vault (`.memory/`) | References `.memory/10-Memories/`, `.memory/memory-index.json` |
| `archive-task.sh` | 179 | Archive single task: move from active state to archive state, move directory to `specs/archive/` | References `specs/state.json`, `specs/archive/state.json`, `specs/TODO.md` |
| `orphan-detection.sh` | 142 | Detect orphaned/misplaced task directories not tracked in any state file | Pure filesystem scanning |
| `postflight-workflow.sh` | 137 | Unified postflight for research/plan/implement (parameterized replacement for 3 standalone scripts) | Uses `specs/tmp/` temp files, references `.claude/context/patterns/jq-escaping-workarounds.md` |
| `parse-command-args.sh` | 135 | Superset CLI argument parser (task numbers, ranges, `--team`, `--fast`, `--hard`, `--clean`, `--force`, `--exploit`, `--explore`) | Must be sourced |
| `dispatch-agent.sh` | 128 | Dispatch functions for orchestrator: named subagent vs fork dispatch | References `.claude/docs/architecture/dispatch-agent-spec.md` |
| `command-gate-out.sh` | 82 | Defensive status correction after skill delegation, artifact validation | Calls `update-task-status.sh`, `validate-artifact.sh` |
| `command-gate-in.sh` | 73 | Session generation, task lookup, terminal status guard | Must be sourced |
| `command-route-skill.sh` | 66 | Resolve task_type to skill_name via extension manifest `.routing` lookup | References `.claude/extensions/*/manifest.json` |

### Category 2: Stale Scripts in `.opencode/` Needing Updates (5 scripts)

These scripts exist in `.opencode/` but are outdated compared to `.claude/`:

| Script | Issue | Action |
|--------|-------|--------|
| `postflight-research.sh` | Old standalone 69-line implementation. `.claude/` has 12-line thin wrapper around `postflight-workflow.sh` | Replace with thin wrapper calling `postflight-workflow.sh` |
| `postflight-plan.sh` | Same as above | Replace with thin wrapper |
| `postflight-implement.sh` | Same as above | Replace with thin wrapper |
| `update-task-status.sh` | Missing `revise` operation support; uses old simpler Task Order update instead of full tree regeneration | Port the 410-line `.claude/` version (or update in-place) |
| `update-plan-status.sh` | Missing `PLANNED` status normalization; less informative error messages | Port the `.claude/` version |

### Category 3: `.opencode/`-Unique Scripts to Preserve (15 scripts)

These scripts exist only in `.opencode/` and should NOT be overwritten:

| Script | Lines | Purpose |
|--------|-------|---------|
| `check-command-drift.sh` | 126 | Detect drift between active commands and extension source |
| `execute-command.sh` | 88 | Execute `.opencode/command/` scripts |
| `merge-extensions.sh` | 208 | Merge extension index entries into `.opencode/context/index.json` |
| `opencode-cleanup.sh` | ~277 | Cleanup `~/.opencode/` directory |
| `opencode-project-cleanup.sh` | ~248 | Cleanup `~/.opencode/projects/` |
| `opencode-refresh.sh` | ~227 | Refresh `.opencode/` configuration |
| `sync-core-commands.sh` | 173 | Sync core commands to child projects |
| `update-recommended-order.sh` | 708 | `.opencode/` alternative to `generate-task-order.sh` |
| `validate-docs.sh` | 175 | Validate `.opencode/` documentation integrity |
| `validate-routing-tables.sh` | 202 | Validate extension manifest routing |
| `test-command.sh` | ~10 | Test harness |
| `test-execution.sh` | ~10 | Test harness |
| `test-execution-system.sh` | ~32 | System-level test harness |
| `test-results.md` | ~43 | Test results documentation |
| `README.md` | ~5 | Scripts directory documentation |

## Decisions

1. **Do NOT delete `update-recommended-order.sh`**: The `.opencode/` system uses a different task ordering approach (topological sort with action hints) vs `.claude/`'s `generate-task-order.sh` (Kahn's algorithm with dependency waves). Port `generate-task-order.sh` but keep `update-recommended-order.sh` as the active system until a decision is made on convergence.

2. **Port `skill-base.sh` with path substitution**: This is the critical shared infrastructure. Must replace `.claude/` paths with `.opencode/` equivalents, adjust extension discovery, and verify all function signatures.

3. **Use thin-wrapper pattern for postflight**: Port `postflight-workflow.sh` and update the 3 postflight scripts to be thin wrappers (matching `.claude/` pattern).

4. **Merge `update-task-status.sh` changes**: The `.claude/` version (with revise support, full tree regeneration, and generate-task-order.sh integration) should replace the `.opencode/` version. The `.opencode/` version must retain its `update-recommended-order.sh` integration path.

5. **Conditional port for `/review` scripts**: `roadmap-integration.sh`, `issue-grouping.sh`, and `tier-selection.sh` are path-independent data processors — they can be copied with minimal changes.

6. **Vault-operation.sh depends on generate-task-order.sh**: Porting `vault-operation.sh` requires `generate-task-order.sh` to also be ported (or the dependency adapted to `update-recommended-order.sh`).

## Recommendations

### Priority Tiers

**Tier 1: Critical Infrastructure (Must Port)**
- `skill-base.sh` — shared lifecycle for all skills
- `command-gate-in.sh` + `command-gate-out.sh` + `command-route-skill.sh` — command checkpoint infrastructure
- `parse-command-args.sh` — argument parsing for all commands
- `dispatch-agent.sh` — orchestrator dispatch functions
- `postflight-workflow.sh` — unified postflight (replaces stale standalone scripts)

**Tier 2: Important Workflow Scripts (Should Port)**
- `update-task-status.sh` — centralized status updates (merge `.claude/` improvements)
- `generate-task-order.sh` — task ordering (coexists with `update-recommended-order.sh`)
- `vault-operation.sh` — vault archival (depends on `generate-task-order.sh`)
- `archive-task.sh` — single task archival
- `orphan-detection.sh` — orphan detection for `/todo`
- `memory-harvest.sh` — memory vault harvesting

**Tier 3: `/review` Command Components (Port When Needed)**
- `roadmap-integration.sh` — mostly path-independent
- `issue-grouping.sh` — pure data processing
- `tier-selection.sh` — pure data processing

**Tier 4: Validation Scripts (Nice to Have)**
- `validate-context-budgets.sh` — context budget enforcement (adapt to `.opencode/` convention)

### Porting Approach by Category

| Adaptation Level | Scripts | Method |
|-----------------|---------|--------|
| Copy with `sed` substitutions | command-route-skill.sh, validate-context-budgets.sh, archive-task.sh, orphan-detection.sh | `sed` for `.claude/` -> `.opencode/` path changes, `Agents/` -> `agent/subagents/` dir changes |
| Copy with manual adaptation | skill-base.sh, command-gate-in.sh, command-gate-out.sh, dispatch-agent.sh, postflight-workflow.sh, parse-command-args.sh | Manual review of all `.claude/` references, tool name changes, skill directory adjustments |
| Merge/update (stale scripts) | postflight-*.sh, update-task-status.sh, update-plan-status.sh | Apply `.claude/` improvements while preserving `.opencode/` conventions (temp dir, task order system) |
| Conditional port | generate-task-order.sh, vault-operation.sh, roadmap-sync.sh | Port but adapt to coexist with `.opencode/` equivalents (update-recommended-order.sh) |

### Post-Porting Verification

After porting, run the existing `.opencode/` validation scripts:
- `validate-routing-tables.sh` — ensure extension routing is intact
- `validate-docs.sh` — ensure no stale `.claude/` references leak into `.opencode/` docs
- `check-command-drift.sh` — ensure commands haven't drifted

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `skill-base.sh` adaptation is complex and introduces bugs | Medium | High | Port incrementally, test each function independently, keep `.claude/` version as reference |
| `.opencode/` temp file conventions (`specs/tmp/`) differ from `.claude/` (`.tmp` suffixes) | High | Medium | Audit all ported scripts for temp file handling, enforce `specs/tmp/` convention |
| `generate-task-order.sh` may conflict with `update-recommended-order.sh` | Medium | Low | Port both, document which is active for each system |
| Stale `.opencode/` scripts (postflight-*.sh) have inline logic that must be preserved | Low | Medium | Thin-wrapper replacement is safe — same API, same behavior |
| Path substitution misses edge cases | Medium | Medium | Use `grep -r '\.claude/'` post-port to catch all references |
| `dispatch-agent.sh` tool names differ (`Agent` vs `Task`) | High | High | Verify dispatch semantics, check if `.opencode/` uses same Agent tool API |
| 26 shared scripts have `.claude/` hardcoded paths but are byte-identical | Low | Medium | These run fine in both systems (path references are to `.claude/` which exists as the original system) |

## Context Extension Recommendations

- **Topic**: Script porting conventions for .claude/ to .opencode/ migration
- **Gap**: No documented standard for path substitutions, temp file conventions, or system-specific adaptations when porting scripts between the two systems
- **Recommendation**: Create `.opencode/context/standards/script-porting-guide.md` documenting the canonical substitution rules, verification checklist, and known architectural differences. This would benefit future porting tasks and reduce risk of drift between the two systems.

## Appendix

### Full Script Inventory (by line count)

**`.claude/` only (17 scripts, descending by size):**
895 generate-task-order.sh, 516 skill-base.sh, 466 roadmap-integration.sh, 401 issue-grouping.sh, 331 roadmap-sync.sh, 306 tier-selection.sh, 247 vault-operation.sh, 226 validate-context-budgets.sh, 190 memory-harvest.sh, 179 archive-task.sh, 142 orphan-detection.sh, 137 postflight-workflow.sh, 135 parse-command-args.sh, 128 dispatch-agent.sh, 82 command-gate-out.sh, 73 command-gate-in.sh, 66 command-route-skill.sh

**`.opencode/` only (15 scripts, descending by size):**
708 update-recommended-order.sh, 208 merge-extensions.sh, 202 validate-routing-tables.sh, 175 validate-docs.sh, 173 sync-core-commands.sh, 126 check-command-drift.sh, 88 execute-command.sh, 43 test-results.md, 32 test-execution-system.sh, 10 test-execution.sh, 10 test-command.sh, 5 README.md
(opencode-cleanup.sh, opencode-project-cleanup.sh, opencode-refresh.sh at ~277, ~248, ~227 lines)

### Key Path Substitutions Required

```
.claude/ -> .opencode/
.claude/skills/ -> .opencode/skills/
.claude/agents/ -> .opencode/agent/subagents/
.claude/extensions/ -> .opencode/extensions/
.claude/context/ -> .opencode/context/
~/.claude/ -> ~/.opencode/
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -> OPENCODE_EXPERIMENTAL_AGENT_TEAMS
Agent tool -> Task tool
```

### Search Queries Used

- `ls -la .claude/scripts/` and `ls -la .opencode/scripts/` for full inventory
- `comm -23/13/12` for diff computation between the two directories
- `diff` for byte-level comparison of shared scripts
- `grep -r '\.claude/'` for hardcoded path detection in both systems
- `grep -r '\.opencode/'` for `.opencode/` path detection
