# Research Report: Task #161

**Task**: 161 - fix_opencode_source_missing_files_and_scan_bugs
**Started**: 2026-03-07T00:00:00Z
**Completed**: 2026-03-07T00:05:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis, sync.lua source code
**Artifacts**: - specs/161_fix_opencode_source_missing_files_and_scan_bugs/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All 9 listed files confirmed present in `.claude/` and absent from `.opencode/`
- The templates scan bug on line 199 of sync.lua uses `*.yaml` but `settings.json` is JSON
- The 4 `.sh` files in `.opencode/context/core/patterns/` are orphaned artifacts with NO counterparts in `.claude/` -- they should be deleted, not synced

## Context & Scope

This research covers three fixes for the `<leader>ao` Load Core Agent System picker, which syncs files from `~/.config/nvim/.claude/` to `~/.config/nvim/.opencode/` (and to project directories).

## Findings

### 1. Missing Files to Copy

All 9 files exist in `.claude/` and are absent from `.opencode/`:

| # | Path | Exists in .claude | In .opencode |
|---|------|:-:|:-:|
| 1 | `context/core/patterns/early-metadata-pattern.md` | Yes | No |
| 2 | `context/core/troubleshooting/workflow-interruptions.md` | Yes | No |
| 3 | `context/index.schema.json` | Yes | No |
| 4 | `docs/reference/standards/agent-frontmatter-standard.md` | Yes | No |
| 5 | `docs/reference/standards/multi-task-creation-standard.md` | Yes | No |
| 6 | `docs/templates/agent-template.md` | Yes | No |
| 7 | `docs/templates/command-template.md` | Yes | No |
| 8 | `scripts/update-plan-status.sh` | Yes | No |
| 9 | `scripts/validate-context-index.sh` | Yes | No |

**Root Cause**: These files were added to `.claude/` after the last sync operation. The sync mechanism itself works correctly -- it just has not been run since these files were added.

**Fix**: Simply run the sync operation (`<leader>ao` -> "Sync all") to copy them, OR manually copy using `cp`. No code change needed for this issue -- it is a data sync gap, not a code bug.

**Additional Missing Files**: Beyond the 9 listed, there are additional files in `.claude/` not in `.opencode/` (found via diff):

| Path | Notes |
|------|-------|
| `context/project/repo/update-project.md` | Project guidance doc |
| `docs/architecture/extension-system.md` | Architecture doc |
| `docs/examples/learn-flow-example.md` | Example doc |
| `docs/examples/research-flow-example.md` | Example doc |
| `docs/guides/adding-domains.md` | Guide |
| `docs/guides/copy-claude-directory.md` | Guide |
| `docs/guides/creating-extensions.md` | Guide |
| `docs/guides/development/context-index-migration.md` | Development guide |
| `docs/guides/neovim-integration.md` | Guide |
| `docs/guides/permission-configuration.md` | Guide |
| `docs/templates/README.md` | Template README |
| `scripts/claude-cleanup.sh` | Cleanup script |
| `scripts/claude-project-cleanup.sh` | Project cleanup |
| `scripts/claude-refresh.sh` | Refresh script |
| `scripts/export-to-markdown.sh` | Export script |
| `scripts/migrate-directory-padding.sh` | Migration script |

These are legitimately missing from `.opencode/` but may or may not be needed there. The sync operation should handle them automatically.

### 2. Templates Scan Bug

**Location**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, line 199

**Current code**:
```lua
artifacts.templates = sync_scan("templates", "*.yaml")
```

**Problem**: The only file in `.claude/templates/` is `settings.json`. The `*.yaml` pattern misses it entirely. The `.opencode/templates/` also has `settings.json` (plus a `README.md`).

**Fix**: Change to scan both `*.yaml` and `*.json`, following the same multi-extension pattern used for skills (lines 186-194) and context (lines 206-214):

```lua
-- Templates (multiple file types)
local templates_yaml = sync_scan("templates", "*.yaml")
local templates_json = sync_scan("templates", "*.json")
artifacts.templates = {}
for _, file in ipairs(templates_yaml) do
  table.insert(artifacts.templates, file)
end
for _, file in ipairs(templates_json) do
  table.insert(artifacts.templates, file)
end
```

**Also update**: The `update_artifact_from_global` function (line 391) hardcodes `template = { dir = "templates", ext = ".yaml" }`. This should be updated to handle `.json` files too, or the extension detection should be dynamic based on the actual file extension.

### 3. Context Shell Scripts

**Finding**: The 4 `.sh` files mentioned in the task description do NOT exist in `.claude/context/`:
- `command-execution.sh` -- NOT in `.claude/context/`
- `command-integration.sh` -- NOT in `.claude/context/`
- `core-command-execution.sh` -- NOT in `.claude/context/`
- `lean-command-execution.sh` -- NOT in `.claude/context/`

These files exist ONLY in `.opencode/context/core/patterns/` and appear to be orphaned artifacts. Examination of their content shows they are documentation files (markdown-like content) with `.sh` extensions, likely created by an earlier agent that mistakenly used `.sh` for documentation about shell patterns.

**Evidence they are orphans**:
1. No counterpart exists in `.claude/context/` (the source of truth)
2. No agent or skill references these files (searched with Grep)
3. Content is documentation, not executable shell code
4. The `test-results.md` file in `.opencode/scripts/` lists them as validated, but this appears to be from an automated sync validation that ran before these were identified as orphans

**Recommendation**: Do NOT add `.sh` scanning to the context sync. Instead, **delete** the 4 orphaned `.sh` files from `.opencode/context/core/patterns/`:
```bash
rm .opencode/context/core/patterns/command-execution.sh
rm .opencode/context/core/patterns/command-integration.sh
rm .opencode/context/core/patterns/core-command-execution.sh
rm .opencode/context/core/patterns/lean-command-execution.sh
```

No code change is needed for the context scanner.

## Decisions

1. **File copy approach**: Use the existing sync mechanism rather than manual cp for the 9 missing files -- this ensures proper directory creation and reporting
2. **Templates fix**: Follow the existing multi-extension pattern (used by skills and context scans) for consistency
3. **Context .sh files**: Delete as orphans rather than adding .sh scanning -- they have no source in `.claude/`

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Templates fix breaks backward compat | Low risk -- adding JSON scan is additive; existing YAML scan unchanged |
| Orphaned .sh files might be referenced | Verified via Grep -- no references found in agents, skills, or commands |
| Additional missing files not addressed | The sync operation handles all files; the 9 listed are the critical ones |

## Context Extension Recommendations

None -- this is a bug fix task with no new domain knowledge to document.

## Appendix

### Key File Locations

- **Sync module**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- **Scan utility**: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- **Config (global_source_dir)**: `lua/neotex/plugins/ai/claude/config.lua` (line 41: `~/.config/nvim`)
- **Templates dir (.claude)**: `.claude/templates/` (contains only `settings.json`)
- **Templates dir (.opencode)**: `.opencode/templates/` (contains `settings.json` and `README.md`)

### Search Queries Used

1. File existence verification: checked all 9 paths in both `.claude/` and `.opencode/`
2. Glob search for `.sh` files in `.claude/context/` -- returned no results
3. Glob search for `.sh` files in `.opencode/context/` -- found 4 orphaned files
4. Grep for references to the `.sh` files across entire codebase
5. Diff between `.claude/` and `.opencode/` file trees
