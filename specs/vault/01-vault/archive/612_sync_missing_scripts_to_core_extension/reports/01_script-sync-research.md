# Research Report: Task #612

**Task**: 612 - sync_missing_scripts_to_core_extension
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:00:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (`.claude/scripts/`, `.claude/extensions/core/scripts/`, `manifest.json`, `loader.lua`, `sync.lua`)
**Artifacts**: `specs/612_sync_missing_scripts_to_core_extension/reports/01_script-sync-research.md`
**Standards**: report-format.md

---

## Executive Summary

- **18 scripts** exist in `.claude/scripts/` but are missing from both `.claude/extensions/core/scripts/` (the extension source) and the `provides.scripts` array in `manifest.json`
- All 18 missing scripts are core infrastructure or utility scripts — **none should be excluded**
- The sync mechanism (`<leader>al`) reads from `.claude/extensions/core/scripts/` as the global source; scripts absent there are never deployed to other projects like ProofChecker
- **Fix**: Copy all 18 scripts to `.claude/extensions/core/scripts/` and add their names to the `provides.scripts` array in `manifest.json`
- `rename-session.sh` is the only potentially environment-specific script (OpenCode TUI), but it already contains a no-op guard for non-OpenCode contexts and should still be included

---

## Context & Scope

The core extension (`extensions/core/`) serves as the canonical source for deployment to other projects. The Neovim picker sync (`<leader>al`) reads from `.claude/extensions/core/scripts/` and copies to target project `.claude/scripts/`. The `provides.scripts` array in `manifest.json` governs which files the loader copies during an `extension install` operation. Any script absent from `extensions/core/scripts/` and not listed in `provides.scripts` is invisible to both deployment paths.

---

## Findings

### Complete Inventory

**Total scripts in `.claude/scripts/`**: 44 (43 top-level `.sh` files + 1 lint subdirectory containing 1 file)

**Already in `extensions/core/scripts/` and `manifest.json`** (26 entries):

| Script | Notes |
|--------|-------|
| `check-extension-docs.sh` | Present |
| `check-vault-threshold.sh` | Present |
| `claude-cleanup.sh` | Present |
| `claude-project-cleanup.sh` | Present |
| `claude-refresh.sh` | Present |
| `export-to-markdown.sh` | Present |
| `install-aliases.sh` | Present |
| `install-extension.sh` | Present |
| `install-systemd-timer.sh` | Present |
| `link-artifact-todo.sh` | Present |
| `memory-retrieve.sh` | Present |
| `migrate-directory-padding.sh` | Present |
| `postflight-implement.sh` | Present |
| `postflight-plan.sh` | Present |
| `postflight-research.sh` | Present |
| `setup-lean-mcp.sh` | Present |
| `uninstall-extension.sh` | Present |
| `update-plan-status.sh` | Present |
| `update-task-status.sh` | Present |
| `validate-artifact.sh` | Present |
| `validate-context-index.sh` | Present |
| `validate-extension-index.sh` | Present |
| `validate-index.sh` | Present |
| `validate-wiring.sh` | Present |
| `verify-lean-mcp.sh` | Present |
| `lint/lint-postflight-boundary.sh` | Present (nested path) |

**Missing from `extensions/core/scripts/` and `manifest.json`** (18 scripts):

| Script | Category | References in skills/commands | Verdict |
|--------|----------|-------------------------------|---------|
| `archive-task.sh` | Core infrastructure | 4 | MUST include |
| `command-gate-in.sh` | Core infrastructure (CHECKPOINT 1: session + task lookup) | 11 | MUST include |
| `command-gate-out.sh` | Core infrastructure (CHECKPOINT 2: status correction) | 11 | MUST include |
| `command-route-skill.sh` | Core infrastructure (task_type -> skill routing) | 3 | MUST include |
| `dispatch-agent.sh` | Core infrastructure (orchestrate state machine) | 3 | MUST include |
| `generate-task-order.sh` | Core infrastructure (TODO.md generation) | 26 | MUST include |
| `issue-grouping.sh` | Utility (/review workflow) | 7 | SHOULD include |
| `memory-harvest.sh` | Utility (memory vault harvest on task complete) | 3 | SHOULD include |
| `orphan-detection.sh` | Utility (/refresh orphan detection) | 2 | SHOULD include |
| `parse-command-args.sh` | Core infrastructure (arg parser for all commands) | 4 | MUST include |
| `postflight-workflow.sh` | Core infrastructure (unified postflight wrapper) | sourced by postflight-*.sh | MUST include |
| `rename-session.sh` | Utility (OpenCode TUI session rename; no-op outside OpenCode) | 1 (in update-task-status.sh) | SHOULD include |
| `roadmap-integration.sh` | Utility (/review + /todo ROADMAP.md annotation) | 5 | SHOULD include |
| `roadmap-sync.sh` | Utility (/todo ROADMAP.md completion sync) | 6 | SHOULD include |
| `skill-base.sh` | Core infrastructure (shared skill lifecycle functions) | 22 | MUST include |
| `tier-selection.sh` | Utility (/review interactive tier selection) | 6 | SHOULD include |
| `validate-context-budgets.sh` | Utility (context index tier validation) | 0 direct (standalone validator) | SHOULD include |
| `vault-operation.sh` | Utility (task number > 1000 vault archival) | 3 | SHOULD include |

### Script Categorization Detail

**MUST include (core infrastructure — commands/skills break without these):**
- `command-gate-in.sh` — Sourced by every command as CHECKPOINT 1 (11 direct references)
- `command-gate-out.sh` — Sourced by every command as CHECKPOINT 2 (11 direct references)
- `skill-base.sh` — Sourced by all skills for shared lifecycle functions (22 references)
- `parse-command-args.sh` — Sourced by /research, /plan, /implement, /orchestrate (4 references)
- `generate-task-order.sh` — Called by /task, /todo, /implement (26 references, most-referenced missing script)
- `command-route-skill.sh` — Task-type routing for /research, /plan, /implement
- `archive-task.sh` — Called by /todo workflow
- `dispatch-agent.sh` — State machine dispatch for /orchestrate skill
- `postflight-workflow.sh` — The actual implementation that `postflight-implement.sh`, `postflight-plan.sh`, and `postflight-research.sh` (already in extension) exec-delegate to

**SHOULD include (workflow utilities — specific features degrade without these):**
- `memory-harvest.sh` — Called by /todo for memory candidate harvesting
- `roadmap-sync.sh` / `roadmap-integration.sh` — ROADMAP.md annotation in /todo and /review
- `tier-selection.sh` / `issue-grouping.sh` — /review task creation workflow
- `orphan-detection.sh` — /refresh orphan detection
- `vault-operation.sh` — /todo vault archival when task numbers exceed 1000
- `rename-session.sh` — Called by `update-task-status.sh` (already in extension); contains no-op guard for non-OpenCode environments
- `validate-context-budgets.sh` — Standalone validator; useful for maintenance

**EXCLUDE**: None. All 18 scripts are general-purpose core infrastructure or workflow utilities with no project-specific content. `rename-session.sh` is the closest to environment-specific but contains a safe no-op guard.

### Dependency Analysis

Critical dependency chains:

```
All commands (/research, /plan, /implement, /task, /orchestrate, etc.)
  ├── command-gate-in.sh  [MISSING]
  ├── parse-command-args.sh  [MISSING - for /research, /plan, /implement, /orchestrate]
  └── command-gate-out.sh  [MISSING]

All skills (skill-researcher, skill-planner, skill-implementer, etc.)
  └── skill-base.sh  [MISSING]

/orchestrate command
  └── dispatch-agent.sh  [MISSING]

postflight-implement.sh, postflight-plan.sh, postflight-research.sh  [present in extension]
  └── postflight-workflow.sh  [MISSING — these 3 exec-delegate to it]

/todo command
  ├── archive-task.sh  [MISSING]
  ├── generate-task-order.sh  [MISSING]
  ├── memory-harvest.sh  [MISSING]
  ├── roadmap-sync.sh  [MISSING]
  └── vault-operation.sh  [MISSING]

/review command
  ├── roadmap-integration.sh  [MISSING]
  ├── issue-grouping.sh  [MISSING]
  └── tier-selection.sh  [MISSING]

/refresh command
  └── orphan-detection.sh  [MISSING]

update-task-status.sh  [present in extension]
  └── rename-session.sh  [MISSING]
```

**Critical observation**: `postflight-implement.sh`, `postflight-plan.sh`, and `postflight-research.sh` are all present in `extensions/core/scripts/` and listed in `manifest.json` — but they all exec-delegate to `postflight-workflow.sh` which is NOT present. This means the three "present" wrappers are currently broken when deployed to other projects.

### Loader Mechanism Verification

**`provides.scripts` array in `manifest.json`** → read by `copy_scripts()` in `loader.lua`:
- Function iterates each entry in `manifest.provides.scripts`
- Constructs `source_path = source_dir/scripts/{script_name}`
- Constructs `target_path = target_dir/scripts/{script_name}`
- Calls `copy_file()` which: checks `.syncprotect`, creates parent directory (`vim.fn.fnamemodify(target_path, ":h")`), then copies with permission preservation

**Nested script handling** (e.g., `lint/lint-postflight-boundary.sh`):
- The `copy_file()` helper calls `helpers.ensure_directory(parent_dir)` before writing
- So `lint/lint-postflight-boundary.sh` in the manifest correctly creates `target/scripts/lint/` if needed
- This pattern works for any depth of nesting

**Sync mechanism (`<leader>al`)** in `sync.lua`:
- Uses `sync_scan("scripts", "*.sh", true, nil, "scripts")`
- For `.claude` projects, `core_source_base = ".claude/extensions/core"` is set
- Source directory becomes `{global_dir}/.claude/extensions/core/scripts/`
- **Any script not in `extensions/core/scripts/` is invisible to sync** — this confirms the gap

### Cross-Project Validation

**ProofChecker** (`/home/benjamin/Projects/ProofChecker/.claude/scripts/`) contains exactly the 26 scripts currently listed in the manifest — no more, no less. This confirms:
1. The sync mechanism works correctly for scripts that ARE in `extensions/core/scripts/`
2. The 18 missing scripts have never been deployed to ProofChecker
3. ProofChecker's commands and skills that reference `command-gate-in.sh`, `skill-base.sh`, etc. are currently broken

### Recommendations

**Implementation approach** (straightforward copy + manifest update):

1. **Copy all 18 scripts** from `.claude/scripts/` to `.claude/extensions/core/scripts/`
2. **Add all 18 script names** to the `provides.scripts` array in `.claude/extensions/core/manifest.json`
3. **No ordering requirements** — manifest scripts are iterated independently; order only affects display, not correctness

**Recommended manifest addition** (alphabetical order within existing list):
```
"archive-task.sh",
"command-gate-in.sh",
"command-gate-out.sh",
"command-route-skill.sh",
"dispatch-agent.sh",
"generate-task-order.sh",
"issue-grouping.sh",
"memory-harvest.sh",
"orphan-detection.sh",
"parse-command-args.sh",
"postflight-workflow.sh",
"rename-session.sh",
"roadmap-integration.sh",
"roadmap-sync.sh",
"skill-base.sh",
"tier-selection.sh",
"validate-context-budgets.sh",
"vault-operation.sh"
```

---

## Decisions

- All 18 scripts should be included — none are deprecated or project-specific
- `rename-session.sh` included despite OpenCode focus: it has a no-op guard and is called by `update-task-status.sh` which IS already in the extension
- No subdirectory nesting needed for the 18 new scripts (all are flat `.sh` files at the top level of `.claude/scripts/`)
- The `lint/` entry already in the manifest is correctly handled by the loader's parent-directory creation

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Copy overwrites newer version in extensions/core/ | Scripts are absent — no overwrite risk |
| Manifest JSON becomes invalid | Validate JSON after edit with `jq empty manifest.json` |
| Script already exists in extensions/core/ but wasn't caught | `comm` comparison was definitive; ProofChecker state confirms |
| ProofChecker needs manual sync after fix | User runs `<leader>al` sync after fix is committed |

---

## Context Extension Recommendations

- **Topic**: Script sync gap detection
- **Gap**: No automated check that all `.claude/scripts/*.sh` files are mirrored in `extensions/core/scripts/` and listed in `manifest.json`
- **Recommendation**: Consider adding a lint check (e.g., in `check-extension-docs.sh`) that diffs `.claude/scripts/` against `extensions/core/scripts/` and fails if scripts are missing

---

## Appendix

**Key files examined:**
- `/home/benjamin/.config/nvim/.claude/scripts/` — 43 top-level + 1 nested script
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/` — 25 top-level + 1 nested script
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json` — `provides.scripts` array (26 entries)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` — `copy_scripts()` function
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — `sync_scan()` for `<leader>al`
- `/home/benjamin/Projects/ProofChecker/.claude/scripts/` — Cross-project validation (26 scripts match manifest exactly)

**Commands used:**
- `comm -23 <(ls .claude/scripts/ | sort) <(ls .claude/extensions/core/scripts/ | sort)` — gap detection
- `grep -r "script-name" .claude/skills/ .claude/commands/` — reference counting
- `jq '.provides.scripts | length' manifest.json` — manifest count verification
