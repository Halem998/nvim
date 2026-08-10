# Research Report: Task #637

**Task**: 637 - verification_and_drift_detection
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Tasks 633, 634, 635, 636 (all completed)
**Sources/Inputs**: Codebase (find, diff, grep, comm, jq analysis of both `.claude/` and `.opencode/`)
**Artifacts**: `specs/637_verification_and_drift_detection/reports/01_parity-audit.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

The `.opencode/` port from tasks 633-636 is **substantially complete** with full structural parity across commands, extension manifests, settings, and context. However, **2 critical bugs and 3 high-severity drift issues** require remediation before the port can be considered production-ready.

| Category | Status | Notes |
|----------|--------|-------|
| Commands | PASS | 19/19 commands present in both |
| Skills | PASS | Core skills match; domain skills correctly in extensions |
| Agents | PARTIAL | Domain agent path mismatch in opencode-agents.json |
| Rules | PASS | Extension rules correctly in extension dirs |
| Context Index | PASS | .opencode has 8 extra entries (extensions merged in, intentional) |
| Extensions | PASS | All 16 extension manifests present |
| Settings | PASS | Identical hook categories (7 types, 9 entries) |
| Path References | FAIL | 3 hooks + 5 scripts still hardcode `.claude/` paths |
| Dependency Chain | PASS | Tasks 633-636 complete with correct dependency edges |

**Overall**: PARTIAL PASS — Critical issues require a fix task before the port is complete.

---

## Context & Scope

Tasks 633-636 ported the following from `.claude/` to `.opencode/`:
- **633**: 14+ core infrastructure scripts
- **634**: Orchestrator system (commands, skills, orchestrator skill)
- **635**: Synthesis and domain agents (neovim, nix, lean agents)
- **636**: Context files (95 synced), missing files (11 copied), hook scripts (3 added), index.json merge (106→150 entries), settings.json backport

This audit compares every component category for parity, identifying residual drift.

---

## Findings

### 1. Commands Parity — PASS

Both systems contain identical command sets: `distill`, `errors`, `fix-it`, `implement`, `learn`, `merge`, `meta`, `orchestrate`, `plan`, `project-overview`, `refresh`, `research`, `review`, `revise`, `spawn`, `tag`, `task`, `todo`, `README.md`.

File count: 19 commands in both directories (plus README.md in each).

The `.opencode/` versions include a `> **COMMAND EXECUTION MODE** —` preamble not present in `.claude/`, which is an intentional OpenCode adaptation.

### 2. Skills Parity — PASS (with intentional differences)

**Core skills (`.opencode/skills/`)**: All 22 `.claude/` core skills are present. `.opencode/` adds `skill-learn` (not present in `.claude/`), which is an OpenCode-specific addition.

**Domain skills** (neovim, nix): Present in `.opencode/extensions/nvim/skills/` and `.opencode/extensions/nix/skills/` respectively. This is the correct extension-based architecture.

Missing from `.claude/` skill listing (intentional, OpenCode-only): `skill-learn`.

### 3. Agents Parity — CRITICAL BUG

**Core agents**: `.claude/agents/` has 12 agents; `.opencode/agent/subagents/` has 9 core agents. The 3 "missing" agents (neovim-implementation, neovim-research, nix-implementation, nix-research — actually 4) are correctly located in their respective extensions:
- `.opencode/extensions/nvim/agents/neovim-{implementation,research}-agent.md`
- `.opencode/extensions/nix/agents/nix-{implementation,research}-agent.md`

**CRITICAL BUG**: The `opencode-agents.json` files for nvim and nix extensions reference the wrong paths:

```json
// .opencode/extensions/nvim/opencode-agents.json
"prompt": "{file:.opencode/agent/subagents/neovim-implementation-agent.md}"  // FILE DOES NOT EXIST
"prompt": "{file:.opencode/agent/subagents/neovim-research-agent.md}"        // FILE DOES NOT EXIST

// .opencode/extensions/nix/opencode-agents.json  
"prompt": "{file:.opencode/agent/subagents/nix-implementation-agent.md}"     // FILE DOES NOT EXIST
"prompt": "{file:.opencode/agent/subagents/nix-research-agent.md}"           // FILE DOES NOT EXIST
```

Actual file locations:
```
.opencode/extensions/nvim/agents/neovim-implementation-agent.md  ✓ exists
.opencode/extensions/nvim/agents/neovim-research-agent.md        ✓ exists
.opencode/extensions/nix/agents/nix-implementation-agent.md      ✓ exists
.opencode/extensions/nix/agents/nix-research-agent.md            ✓ exists
```

**Impact**: Any neovim or nix task routed through OpenCode will fail to load the agent, resulting in task execution failures.

**Fix**: Update the 4 prompt paths in both `opencode-agents.json` files to reference the actual extension-relative paths.

**Also noted**: `synthesis-agent.md` exists in `.opencode/agent/subagents/` but is not registered in any `opencode-agents.json`. This agent was added in task 635 but the registration step was missed.

### 4. Rules Parity — PASS (with stale documentation)

`.claude/rules/` has 9 rules including `neovim-lua.md` and `nix.md`.
`.opencode/rules/` has 8 rules — `neovim-lua.md` and `nix.md` are absent from the top-level directory.

**This is correct behavior**: Both rules exist in the extension directories:
- `.opencode/extensions/nvim/rules/neovim-lua.md`
- `.opencode/extensions/nix/rules/nix.md`

Both extension `manifest.json` files declare these rules in their `provides.rules` arrays. The extension loader correctly resolves them.

**Minor Issue**: `.opencode/rules/README.md` lists `neovim-lua.md` as a file in that directory (it's not there). This is stale documentation.

### 5. Context Index Parity — PASS (with duplicate entries)

| System | Entry Count |
|--------|-------------|
| `.claude/context/index.json` | 142 |
| `.opencode/context/index.json` | 150 |

The 8 extra `.opencode/` entries are files that exist under both `checkpoints/*` and `core/checkpoints/*` (and similar `core/` prefixed paths). These duplicates result from the extension merge process adding `core/` prefixed paths in addition to the already-present flat paths.

Specifically, 8 files are indexed twice:
- `core/checkpoints/checkpoint-gate-in.md` (also at `checkpoints/checkpoint-gate-in.md`)
- `core/checkpoints/checkpoint-gate-out.md` (also at `checkpoints/checkpoint-gate-out.md`)
- `core/formats/plan-format.md` (also at `formats/plan-format.md`)
- `core/formats/return-metadata-file.md` (also at `formats/return-metadata-file.md`)
- `core/orchestration/routing.md` (also at `orchestration/routing.md`)
- `core/patterns/anti-stop-patterns.md` (also at `patterns/anti-stop-patterns.md`)
- `core/patterns/metadata-file-return.md` (also at `patterns/metadata-file-return.md`)
- `core/routing.md` (also at `routing.md`)

These files are not missing from `.claude/` — they exist at the non-prefixed paths. No content is lost; agents will simply get offered the same context twice if they query by path.

### 6. Extension Parity — PASS (with divergence in non-critical extensions)

All 16 extensions have manifests in both systems. Key extensions have full file parity:
- `nix`: 24 files (MATCH)
- `nvim`: 34 files (MATCH)
- `latex`: 20 files (MATCH)
- `present`: 95 files (MATCH)
- `python`, `slidev`, `typst`, `z3`: MATCH

Divergences in non-core extensions reflect intentional evolution:
- `epidemiology`: `.opencode/` has renamed agents (`epidemiology-*` vs `epi-*`) and consolidated context; `.claude/` retains older structure
- `filetypes`: `.opencode/` has new `deck` and `spreadsheet` agents/skills; `.claude/` retains older `docx-edit` and `scrape` agents
- `web`: `.opencode/` has an extra `skill-tag` and `commands/tag.md`
- `core`: `.opencode/` has additional test infrastructure scripts (`test-execution.sh`, etc.)

These are forward-evolution differences in `.opencode/` that should be ported back to `.claude/` eventually, but are not blocking.

### 7. Settings.json Parity — PASS

Both files have identical hook structure: 7 hook types (Notification, PostToolUse, PreToolUse, SessionStart, Stop, SubagentStop, UserPromptSubmit) with 9 total hook entries. All hook commands in `.opencode/settings.json` correctly reference `.opencode/hooks/*` paths.

**One ordering difference** (not functional): In `UserPromptSubmit`, `.claude/` has `wezterm-task-number.sh` before `wezterm-preflight-status.sh`; `.opencode/` has them swapped. This does not affect functionality.

### 8. Path Reference Audit — HIGH SEVERITY DRIFT

**3 hooks writing to `.claude/logs` instead of `.opencode/logs`**:

```
.opencode/hooks/log-session.sh:5:    LOG_DIR=".claude/logs"
.opencode/hooks/post-command.sh:5:   LOG_DIR=".claude/logs"
.opencode/hooks/subagent-postflight.sh:35: local LOG_DIR=".claude/logs"
```

These hooks ARE configured in `.opencode/settings.json` and will execute when OpenCode runs, writing session logs to `.claude/logs` instead of `.opencode/logs`. This is a **runtime bug** — OpenCode session activity will pollute the Claude Code log directory.

**5 utility/validation scripts with hardcoded `.claude/` paths**:

| Script | Stale Reference | Impact |
|--------|----------------|--------|
| `validate-context-index.sh` | `INDEX_FILE="$PROJECT_ROOT/.claude/context/index.json"` | Validates `.claude/` index when run from `.opencode/` |
| `validate-index.sh` | `INDEX_FILE="${1:-.claude/context/index.json}"` | Same issue |
| `check-extension-docs.sh` | `EXT_DIR="$REPO_ROOT/.claude/extensions"` | Scans `.claude/` extensions |
| `lint-postflight-boundary.sh` | `find "$PROJECT_ROOT/.claude/skills" "$PROJECT_ROOT/.claude/extensions"` | Scans `.claude/` skills |
| `validate-extension-index.sh` | `for file in "$PROJECT_DIR"/.claude/extensions/*/index-entries.json` | Scans `.claude/` extension indexes |

These affect maintenance workflows — running `validate-context-index.sh` from `.opencode/scripts/` will validate the wrong index. The same scripts also exist in `.opencode/extensions/core/scripts/` with identical bugs.

### 9. Dependency Integrity — PASS

All dependency edges for tasks 633-637 are correctly declared and reflect actual work sequence:

```
633 (core scripts)     → completed [no deps]
634 (orchestrator)     → completed [deps: 633]
635 (domain agents)    → completed [deps: 633]
636 (context/rules)    → completed [deps: 633, 634, 635]
637 (verification)     → researching [deps: 633, 634, 635, 636]
```

The DAG is acyclic and correctly models the actual dependency relationships.

---

## Decisions

- Rules parity for `neovim-lua.md` and `nix.md` is **correct by design** — they belong in extension subdirectories, not in the top-level `.opencode/rules/`
- `skill-learn` being OpenCode-exclusive is **intentional** — the `.claude/` system uses `skill-memory` for the `/learn` command
- Context index duplication of `core/*` paths is a **minor cosmetic issue**, not a functional problem
- The diverged extensions (epidemiology, filetypes, web) represent **forward evolution** in `.opencode/` and do not block completion of this porting effort

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Neovim/nix agent path bug causes task failures | CRITICAL | Fix opencode-agents.json to use extension-relative paths |
| Hooks log to wrong directory, polluting .claude/logs | HIGH | Update LOG_DIR in 3 hook files |
| Validation scripts operate on wrong system | HIGH | Update hardcoded paths in 5 scripts (plus core extension copies) |
| synthesis-agent not registered in OpenCode | MEDIUM | Add to core opencode-agents.json or team-research extension config |
| Stale README in .opencode/rules/ confuses future contributors | LOW | Update README to reflect extension-based rule loading |

---

## Context Extension Recommendations

**None** — this is a meta task verifying system parity. No new context documentation needed.

---

## Appendix

### Files Analyzed

- `/home/benjamin/.config/nvim/.claude/` — full directory tree
- `/home/benjamin/.config/nvim/.opencode/` — full directory tree
- Both `context/index.json` files (142 and 150 entries)
- Both `settings.json` files
- All `opencode-agents.json` manifests in extensions

### Search Commands Used

- `find .claude/ -type f | sort` / `find .opencode/ -type f | sort`
- `comm -23` / `diff` for file list comparisons
- `grep -rn "\.claude/"` for stale path reference audit
- `jq '.entries | length'` for index entry counts
- `diff <(jq -S '.hooks' ...)` for settings comparison
- Direct file count comparison per extension directory

### Summary Table

| Gap # | Type | Files Affected | Fix Effort |
|-------|------|---------------|------------|
| 1 | CRITICAL path bug | 2 opencode-agents.json files (4 lines) | 5 min |
| 2 | HIGH log dir | 3 hook files (3 lines) | 5 min |
| 3 | HIGH script paths | 5 scripts × 2 (main + core ext) = 10 files | 15 min |
| 4 | MEDIUM agent registration | Add synthesis-agent to opencode-agents.json | 5 min |
| 5 | LOW stale README | 1 file | 2 min |
| 6 | LOW index duplicates | opencode context/index.json | 5 min |
