# Research Report: Task #118

**Task**: 118 - Redesign leader ao picker: Load All Artifacts -> Load Core Agent System
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T00:30:00Z
**Effort**: 3-5 hours
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis, extension manifests
**Artifacts**: - specs/118_redesign_leader_ao_load_core_agent_system/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The `.claude` global directory is already clean (no extension content mixed in), but `.opencode` has extension-owned content in agents/, skills/, commands/, rules/, context/, scripts/ directories
- All 9 extension manifests define `provides` fields that enumerate exactly which files/directories they own in each category
- The `scan_all_artifacts()` function in sync.lua needs a filtering step that reads all extension manifests and builds an exclusion set, then skips files matching that set
- The picker entry label in entries.lua and preview text in previewer.lua need renaming from "Load All Artifacts" to "Load Core Agent System"

## Context & Scope

The `<leader>ao` picker triggers the Claude/OpenCode artifacts picker. The "[Load All Artifacts]" entry calls `sync.load_all_globally()` which invokes `scan_all_artifacts()` to discover every file in the global directory and copy it to the current project. The problem is that the global `.opencode/` directory (and potentially `.claude/` as extensions are loaded) contains extension-specific files mixed with core system files.

## Findings

### 1. Current scan_all_artifacts() Implementation

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (lines 159-261)

The function takes `global_dir`, `project_dir`, and an optional `config` table. It scans these artifact categories:

| Category | Pattern | Recursive | Notes |
|----------|---------|-----------|-------|
| commands | `*.md` | true | via `sync_scan()` |
| agents | `*.md` | true | Uses `config.agents_subdir` |
| skills | `*.md`, `*.yaml` | true | Multiple file types |
| hooks | `*.sh` | true | |
| templates | `*.yaml` | true | |
| docs | `*.md` | true | |
| scripts | `*.sh` | true | |
| rules | `*.md` | true | |
| context | `*.md`, `*.json`, `*.yaml` | true | Has CONTEXT_EXCLUDE_PATTERNS |
| systemd | `*.service`, `*.timer` | true | |
| lib | `*.sh` | true | .claude only |
| tests | `test_*.sh` | true | .claude only |
| settings | `settings.json` | false | .claude only |
| root_files | specific list | false | CLAUDE.md, .gitignore, etc. |

The function delegates to `scan.scan_directory_for_sync()` which uses `vim.fn.glob()` to find files. Each file gets a `name` (filename only, no path) and `global_path`/`local_path` fields.

**Key insight**: The scanning uses `global_dir .. "/" .. base_dir .. "/" .. subdir` as the path. For example, for .opencode agents it scans `~/.config/nvim/.opencode/agent/subagents/*.md`. This means ALL agent files (core + extension) in that directory get picked up.

### 2. Extension Manifest "provides" Structure

All 9 extensions define a `provides` field with these categories:

```json
{
  "provides": {
    "agents": ["filename.md", ...],     // Agent definition files
    "skills": ["skill-name", ...],       // Skill directory names (not files)
    "commands": ["filename.md", ...],    // Command files
    "rules": ["filename.md", ...],       // Rule files
    "context": ["project/subdir", ...],  // Context directory paths
    "scripts": ["filename.sh", ...],     // Script files
    "hooks": []                          // Hook files (currently empty for all)
  }
}
```

**Complete extension-owned inventory across all 9 manifests**:

#### Agents (filenames, .md extension)
| Extension | Files |
|-----------|-------|
| lean | lean-research-agent.md, lean-implementation-agent.md |
| latex | latex-implementation-agent.md, latex-research-agent.md |
| python | python-research-agent.md, python-implementation-agent.md |
| formal | formal-research-agent.md, logic-research-agent.md, math-research-agent.md, physics-research-agent.md |
| z3 | z3-research-agent.md, z3-implementation-agent.md |
| document-converter | document-converter-agent.md |
| web | web-implementation-agent.md, web-research-agent.md |
| nix | nix-research-agent.md, nix-implementation-agent.md |
| typst | typst-research-agent.md, typst-implementation-agent.md |

#### Skills (directory names)
| Extension | Directories |
|-----------|-------------|
| lean | skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version |
| latex | skill-latex-implementation, skill-latex-research |
| python | skill-python-research, skill-python-implementation |
| formal | skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research |
| z3 | skill-z3-research, skill-z3-implementation |
| document-converter | skill-document-converter |
| web | skill-web-implementation, skill-web-research |
| nix | skill-nix-research, skill-nix-implementation |
| typst | skill-typst-research, skill-typst-implementation |

#### Commands (filenames, .md extension)
| Extension | Files |
|-----------|-------|
| lean | lake.md, lean.md |
| document-converter | convert.md |
| (others) | (empty) |

#### Rules (filenames, .md extension)
| Extension | Files |
|-----------|-------|
| lean | lean4.md |
| latex | latex.md |
| web | web-astro.md |
| nix | nix.md |
| (others) | (empty) |

#### Context (directory paths relative to context/)
| Extension | Directories |
|-----------|-------------|
| lean | project/lean4 |
| latex | project/latex |
| python | project/python |
| formal | project/logic, project/math, project/physics |
| z3 | project/z3 |
| web | project/web |
| nix | project/nix |
| typst | project/typst |

#### Scripts (filenames, .sh extension)
| Extension | Files |
|-----------|-------|
| lean | setup-lean-mcp.sh, verify-lean-mcp.sh |
| (others) | (empty) |

### 3. Current State of Global Directories

**.claude directory** (CORE ONLY -- already clean):
- agents/: general-implementation-agent.md, general-research-agent.md, meta-builder-agent.md, neovim-implementation-agent.md, neovim-research-agent.md, planner-agent.md
- skills/: skill-git-workflow, skill-implementer, skill-learn, skill-meta, skill-neovim-implementation, skill-neovim-research, skill-orchestrator, skill-planner, skill-refresh, skill-researcher, skill-status-sync
- commands/: errors.md, implement.md, learn.md, meta.md, plan.md, refresh.md, research.md, review.md, revise.md, task.md, todo.md
- rules/: artifact-formats.md, error-handling.md, git-workflow.md, neovim-lua.md, state-management.md, workflows.md
- context/project/: hooks/, meta/, neovim/, processes/, repo/
- scripts/: claude-cleanup.sh, claude-project-cleanup.sh, claude-refresh.sh, export-to-markdown.sh, install-aliases.sh, install-systemd-timer.sh, migrate-directory-padding.sh, postflight-implement.sh, postflight-plan.sh, postflight-research.sh, update-plan-status.sh, validate-context-index.sh

**.opencode directory** (MIXED -- extension content present):
- agent/subagents/: Includes core agents PLUS lean-*, latex-*, logic-*, math-*, physics-*, typst-*, document-converter-*, web-* agents
- skills/: Includes core skills PLUS skill-lean-*, skill-latex-*, skill-logic-*, skill-math-*, skill-lake-*, skill-document-converter, skill-lean-version
- commands/: Includes core commands PLUS lake.md, lean.md, convert.md
- rules/: Includes core rules PLUS lean4.md, latex.md, web-astro.md
- context/project/: Includes core context PLUS lean4/, latex/, logic/, math/, typst/, web/
- scripts/: No obvious extension scripts visible (lean scripts may not be in .opencode)

### 4. Picker Entry Configuration

**entries.lua** (lines 656-686) - `create_special_entries()`:
```lua
table.insert(entries, {
  is_load_all = true,
  name = "~~~load_all",
  display = string.format(
    "%-40s %s",
    "[Load All Artifacts]",
    "Sync commands, hooks, skills, agents, docs, lib"
  ),
  command = nil,
  entry_type = "special"
})
```

**previewer.lua** (lines 227-231):
```lua
local lines = {
  "Load All Artifacts",
  "",
  "This action will sync all artifacts from " .. global_dir .. "/.claude/ to your",
  "local project's .claude/ directory.",
```

**init.lua** (line 93):
```lua
if selection.value.is_load_all then
  local loaded = sync.load_all_globally(config)
```

### 5. Architecture of the Extension System

Extensions are managed through:
1. `shared/extensions/manifest.lua` -- reads/validates manifest.json
2. `shared/extensions/config.lua` -- config presets for claude/opencode
3. `shared/extensions/loader.lua` -- copies files to project directories
4. `shared/extensions/state.lua` -- tracks loaded extensions per project

The `manifest.list_extensions(config)` function reads all `{base_dir}/extensions/*/manifest.json` from the global directory. Each returns a structured manifest with `provides` field.

**The existing manifest infrastructure can be directly reused** to build the exclusion list. The function `manifest_mod.list_extensions(config)` is already available and returns all extension manifests.

### Recommendations

#### Implementation Approach

**Step 1: Build exclusion list from extension manifests**

Create a new function in sync.lua (or a utility function) that:
1. Uses the existing `manifest.list_extensions(config)` to get all extension manifests
2. Iterates over each manifest's `provides` field
3. Builds a set of filenames/directory names to exclude per category:
   - `agents_exclude`: Set of filenames (e.g., "lean-research-agent.md")
   - `skills_exclude`: Set of directory names (e.g., "skill-lean-research")
   - `commands_exclude`: Set of filenames
   - `rules_exclude`: Set of filenames
   - `context_exclude`: Set of directory prefixes (e.g., "project/lean4")
   - `scripts_exclude`: Set of filenames
   - `hooks_exclude`: Set of filenames

**Step 2: Modify scan_all_artifacts() to accept and apply exclusion list**

Two design options:

**Option A (Recommended): Filter after scanning**
After each `sync_scan()` call, filter the returned files array against the exclusion set. This is simpler because `scan_directory_for_sync` returns arrays with `name` and `global_path` fields that can be matched against the exclusion set.

```lua
local function filter_extension_files(files, exclude_set, match_field)
  if not exclude_set or vim.tbl_isempty(exclude_set) then
    return files
  end
  local filtered = {}
  for _, file in ipairs(files) do
    if not exclude_set[file[match_field or "name"]] then
      table.insert(filtered, file)
    end
  end
  return filtered
end
```

For agents and commands, the match is on filename (e.g., "lean-research-agent.md").
For skills, the match is on the directory name (skill files are in subdirectories like `skills/skill-lean-research/`).
For context, the match is on a path prefix (e.g., paths under `context/project/lean4/` should be excluded).

**Option B: Pass exclusion patterns to scan_directory_for_sync**
Extend the existing `exclude_patterns` parameter (already used for context). This requires more changes to the scan utility.

**Option A is recommended** because it keeps the scan utility generic and handles the different matching strategies (filename, directory, path prefix) at the sync layer.

**Step 3: Rename picker entry**

In `entries.lua`, change `create_special_entries()`:
- Display: `"[Load Core Agent System]"` instead of `"[Load All Artifacts]"`
- Description: `"Sync core commands, hooks, skills, agents, docs, lib (excludes extensions)"`

In `previewer.lua`, update `preview_load_all()`:
- Title: `"Load Core Agent System"` instead of `"Load All Artifacts"`
- Description: Update to mention extension exclusion

In `previewer.lua` help text (line 169):
- Update from `"[Load All]"` to `"[Load Core]"`

**Step 4: Thread the config through for extension discovery**

The `scan_all_artifacts()` function already receives `config` with `base_dir`. The extension config needs `global_extensions_dir` to find manifests. The function can derive this:
```lua
local ext_config = require("neotex.plugins.ai.shared.extensions.config")
local extensions_config
if base_dir == ".opencode" then
  extensions_config = ext_config.opencode(global_dir)
else
  extensions_config = ext_config.claude(global_dir)
end
```

#### Skills Exclusion Strategy

Skills require special handling. The `provides.skills` array contains directory names (e.g., `"skill-lean-research"`), not filenames. The scan collects files from `skills/*.md` and `skills/*.yaml` using glob patterns. To exclude extension skills, the filter needs to check if a file's path contains an extension-owned skill directory name:

```lua
-- For skills, check if the file is inside an extension-owned skill directory
local function is_extension_skill(file, skill_dirs_exclude)
  for dir_name, _ in pairs(skill_dirs_exclude) do
    if file.global_path:match("/" .. dir_name .. "/") then
      return true
    end
  end
  return false
end
```

#### Context Exclusion Strategy

Context directories in `provides` are like `"project/lean4"`. The scan for context already uses recursive patterns. Files under `context/project/lean4/**` need to be excluded. The filter checks if the file's relative path starts with any excluded prefix:

```lua
-- For context, check if the file's relative path starts with an excluded prefix
-- The existing CONTEXT_EXCLUDE_PATTERNS uses exact string match on rel_path
-- Extension context exclusion needs prefix matching
```

#### Lazy Loading Opportunity

The exclusion list computation (reading all manifest.json files) should be done once at the start of `scan_all_artifacts()` and cached for the duration of the call. It does not need persistent caching since the manifests are small JSON files and the operation is triggered by user action (not a hot path).

#### Keymap/Picker Changes

No keymap changes needed. The `<leader>ao` binding is unchanged. Only the display label, preview text, and sync behavior change.

## Decisions

1. **Use post-scan filtering (Option A)** rather than modifying scan_directory_for_sync. This keeps the scan utility generic and handles category-specific matching at the sync layer.
2. **Reuse existing manifest infrastructure** (`shared/extensions/manifest.list_extensions`) rather than reading JSON files manually. This ensures consistency with the extension system.
3. **Both .claude and .opencode systems get the filtering** since `scan_all_artifacts()` is shared code. For .claude this is currently a no-op (no extension files in global dir), but it future-proofs the system.
4. **The `is_load_all` flag in init.lua remains unchanged** -- only the display text and sync behavior change.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Skills matching by directory name could miss files | Use path-based matching (`global_path:match("/" .. dir_name .. "/")`) instead of filename matching |
| Context prefix matching could be too aggressive | Use exact prefix match on the relative path after `context/` |
| Extension manifests could be malformed | Already handled by `manifest.validate()` -- invalid manifests return nil and are skipped |
| Performance of reading 9 manifest.json files | Negligible -- small JSON files, user-initiated action |
| .claude global dir has no extension content now but might later | The filtering handles both systems uniformly, so it is future-proof |

## Context Extension Recommendations

None -- this task is focused on Neovim plugin code, not context documentation.

## Appendix

### Files That Need Modification

1. **`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`**
   - Add `build_extension_exclusion_set()` function
   - Add `filter_extension_files()` utility function
   - Modify `scan_all_artifacts()` to apply exclusion filtering

2. **`lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`**
   - Update `create_special_entries()` display text (line 664-668)

3. **`lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`**
   - Update `preview_load_all()` title and description (lines 228-231)
   - Update help text (line 169)

### Core Agents (should always be synced)
- general-implementation-agent.md
- general-research-agent.md
- meta-builder-agent.md
- neovim-implementation-agent.md
- neovim-research-agent.md
- planner-agent.md

### Core Skills (should always be synced)
- skill-git-workflow
- skill-implementer
- skill-learn
- skill-meta
- skill-neovim-implementation
- skill-neovim-research
- skill-orchestrator
- skill-planner
- skill-refresh
- skill-researcher
- skill-status-sync

### Core Commands (should always be synced)
- errors.md, implement.md, learn.md, meta.md, plan.md, refresh.md, research.md, review.md, revise.md, task.md, todo.md

### Core Rules (should always be synced)
- artifact-formats.md, error-handling.md, git-workflow.md, neovim-lua.md, state-management.md, workflows.md

### Core Context Directories (should always be synced)
- project/hooks, project/meta, project/neovim, project/processes, project/repo

### Search Queries Used
- Local file analysis via Glob, Grep, Read
- Extension manifest inspection (all 9 .claude and .opencode manifests)
- Code flow tracing through picker -> sync -> scan modules
