# Research Report: Task #186 (Unified Extension Loader Design)

**Task**: 186 - filter_extension_artifacts_from_core_sync
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T02:00:00Z
**Effort**: 4-6 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of shared extensions system, picker infrastructure, sync operations, both .claude and .opencode configurations, extension manifests
**Artifacts**: specs/186_filter_extension_artifacts_from_core_sync/reports/research-003.md
**Standards**: report-format.md

## Executive Summary

- The system already has a well-designed unified extension architecture via `shared/extensions/` -- both .claude and .opencode use the same loader, state, merge, manifest, and verify modules, parameterized via config objects
- The core sync operation (`sync.lua`) already supports both systems via `config.base_dir`, but lacks extension artifact filtering -- this is the single missing piece
- The two pickers (extension picker + core sync "Load All") are nearly identical between .claude and .opencode (differing only in module imports and prompt titles), presenting a consolidation opportunity
- A unified solution requires three changes: (1) manifest-based blocklist in core sync, (2) self-loading guard in the extension manager, (3) a single parameterized picker replacing the two duplicate files
- The existing infrastructure makes this implementation straightforward -- no new modules are needed, only enhancements to existing ones

## Context & Scope

Reports 001 and 002 identified the problem (extension artifacts leaking into core sync) and proposed solutions (symlink filtering, manifest-based blocklist, clean global directory). This report focuses on the unified design for BOTH .claude/ and .opencode/ systems, emphasizing:

1. How to produce identical, predictable sync results regardless of loaded extensions
2. How the two agent systems can share more code
3. Concrete implementation patterns that work for both systems

### Key Requirement

The system must produce identical results regardless of what extensions are currently loaded in the global directories. This means:
- Core sync always copies the same set of files (core only)
- Extension loading is always explicit and on-demand
- The global directory state does not affect sync output

## Findings

### 1. Current Architecture Assessment

#### Shared Infrastructure (Already Unified)

The following modules are fully shared between .claude and .opencode:

| Module | Path | Functions |
|--------|------|-----------|
| Extensions API | `shared/extensions/init.lua` | `create(config)` returns parameterized manager |
| Loader | `shared/extensions/loader.lua` | Copy engine (files, skills, context, scripts, data) |
| State | `shared/extensions/state.lua` | Extension tracking via extensions.json |
| Merge | `shared/extensions/merge.lua` | Section injection, settings merge, index entries, opencode.json agents |
| Manifest | `shared/extensions/manifest.lua` | Manifest parsing, validation, listing |
| Verify | `shared/extensions/verify.lua` | Post-load integrity checks |
| Config | `shared/extensions/config.lua` | Config schema with `claude()` and `opencode()` presets |
| Picker Config | `shared/picker/config.lua` | Picker config with `claude()` and `opencode()` presets |

#### System-Specific Wrappers (Thin Delegation)

Each system has thin wrapper modules that delegate to the shared infrastructure:

**Claude wrappers** (4 files):
- `claude/extensions/init.lua` -- 13 lines, creates manager with claude config
- `claude/extensions/config.lua` -- 15 lines, calls `shared_config.claude()`
- `claude/extensions/loader.lua` -- 7 lines, re-exports shared loader
- `claude/extensions/state.lua` -- 102 lines, wraps shared state (could be simplified)
- `claude/extensions/picker.lua` -- 245 lines, Telescope picker

**OpenCode wrappers** (3 files):
- `opencode/extensions/init.lua` -- 13 lines, creates manager with opencode config
- `opencode/extensions/config.lua` -- 15 lines, calls `shared_config.opencode()`
- `opencode/extensions/picker.lua` -- 245 lines, Telescope picker (near-identical to Claude's)

#### Not Yet Shared

The following are NOT shared and represent duplication:

| Component | Claude | OpenCode | Difference |
|-----------|--------|----------|------------|
| Extension picker | `claude/extensions/picker.lua` | `opencode/extensions/picker.lua` | Module import, prompt title, error message |
| Core sync | `claude/commands/picker/operations/sync.lua` | (reused via facade) | Already shared |
| Commands picker | `claude/commands/picker/init.lua` | `opencode/commands/picker.lua` (facade) | OpenCode already delegates to Claude's picker |
| State wrapper | `claude/extensions/state.lua` | (none, uses shared directly) | Claude has unnecessary wrapper |

### 2. Extension Picker Duplication Analysis

The two extension picker files are 245 lines each and differ only in:

**Line 15** -- module import:
```lua
-- Claude:
local extensions = require("neotex.plugins.ai.claude.extensions")
-- OpenCode:
local extensions = require("neotex.plugins.ai.opencode.extensions")
```

**Line 117/120** -- prompt title and error message:
```lua
-- Claude:
prompt_title = "Claude Extensions"
helpers.notify("No extensions found in global directory", "WARN")
-- OpenCode:
prompt_title = "OpenCode Extensions"
helpers.notify("No OpenCode extensions found", "WARN")
```

Everything else is identical: entry formatting, previewer, key mappings (Enter to toggle, Ctrl-r to reload, Ctrl-d for details, Tab for multi-select), floating window for file lists.

**Recommendation**: Create `shared/extensions/picker.lua` that accepts a config table, replacing both files.

### 3. Manifest-Based Blocklist Design

To filter extension artifacts from core sync, the blocklist must:

1. Read all extension manifests from the global extensions directory
2. Aggregate all `provides` entries by category
3. Convert to exclude patterns compatible with `scan_directory_for_sync()`

#### Blocklist Structure

```lua
{
  agents = {"lean-research-agent.md", "neovim-research-agent.md", ...},
  skills = {"skill-lean-research", "skill-neovim-research", ...},
  commands = {"lake.md", "lean.md", ...},
  rules = {"neovim-lua.md", "lean4.md", ...},
  scripts = {},
  hooks = {},
  context = {"project/neovim", "project/lean", ...},
}
```

#### Integration with scan_directory_for_sync()

The `exclude_patterns` parameter currently does exact string matching against relative paths. For most categories (agents, commands, rules), the manifest provides filenames that match directly. For skills (directories) and context (directory prefixes), prefix matching is needed.

**Current exclude check** (scan.lua line 96):
```lua
if rel_path == pattern then
  should_exclude = true
end
```

**Required for skills/context** -- prefix matching:
```lua
if rel_path == pattern or rel_path:sub(1, #pattern + 1) == pattern .. "/" then
  should_exclude = true
end
```

This change is backward-compatible because exact matches still work, and existing `CONTEXT_EXCLUDE_PATTERNS` use full relative paths.

### 4. Invariant-Based Design: Predictable Sync Output

The core invariant is: **sync output depends only on the contents of core directories, not on loaded extensions**.

#### Design Pattern: "Clean Source" Guarantee

Three mechanisms enforce this invariant:

**Mechanism 1: Self-loading guard** (prevents contamination)
```lua
-- In shared/extensions/init.lua:manager.load()
local scan_mod = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local global_dir = scan_mod.get_global_dir()
if project_dir == global_dir then
  return false, "Cannot load extensions into source directory"
end
```

**Mechanism 2: Manifest blocklist** (filters contamination if it exists)
```lua
-- In manifest.lua (new function)
function M.aggregate_extension_artifacts(config)
  local blocklist = {}
  for _, cat in ipairs({"agents", "skills", "commands", "rules", "scripts", "hooks", "context"}) do
    blocklist[cat] = {}
  end
  for _, ext in ipairs(M.list_extensions(config)) do
    if ext.manifest.provides then
      for category, files in pairs(ext.manifest.provides) do
        if blocklist[category] then
          for _, f in ipairs(files) do
            blocklist[category][f] = true  -- Use set for O(1) lookup
          end
        end
      end
    end
  end
  return blocklist
end
```

**Mechanism 3: Symlink skip** (defense in depth)
```lua
-- In scan.lua:scan_directory_for_sync()
if opts.skip_symlinks and vim.fn.resolve(global_file) ~= global_file then
  goto continue
end
```

All three mechanisms are independent and any one of them prevents extension leakage. Together they provide defense in depth.

### 5. Unified Extension System Configuration

The existing config schema (`shared/extensions/config.lua`) already captures all system-specific differences:

| Config Field | Claude | OpenCode |
|-------------|--------|----------|
| `base_dir` | `.claude` | `.opencode` |
| `config_file` | `CLAUDE.md` | `OPENCODE.md` |
| `section_prefix` | `extension_` | `extension_oc_` |
| `state_file` | `extensions.json` | `extensions.json` |
| `global_extensions_dir` | `~/.config/nvim/.claude/extensions` | `~/.config/nvim/.opencode/extensions` |
| `merge_target_key` | `claudemd` | `opencode_md` |
| `agents_subdir` | `agents` | `agent/subagents` |

The picker config (`shared/picker/config.lua`) adds UI-specific settings:

| Config Field | Claude | OpenCode |
|-------------|--------|----------|
| `label` | `Claude` | `OpenCode` |
| `extensions_module` | `neotex.plugins.ai.claude.extensions` | `neotex.plugins.ai.opencode.extensions` |
| `root_config_file` | `CLAUDE.md` | `OPENCODE.md` |
| `on_load_all` | nil | installs base opencode.json |

### 6. Manifest Schema Alignment

Current manifests for .claude and .opencode extensions are structurally identical:

```json
{
  "name": "string",
  "version": "semver",
  "description": "string",
  "language": "string|null",
  "dependencies": [],
  "provides": {
    "agents": ["filename.md"],
    "skills": ["skill-name"],
    "commands": ["command.md"],
    "rules": ["rule.md"],
    "context": ["path/prefix"],
    "scripts": ["script.sh"],
    "hooks": ["hook.sh"],
    "data": ["directory-name"]
  },
  "merge_targets": {
    "claudemd|opencode_md": { "source": "EXTENSION.md", "target": "path", "section_id": "id" },
    "index": { "source": "index-entries.json", "target": "path" },
    "settings": { "source": "settings-fragment.json", "target": "path" },
    "opencode_json": { "source": "opencode-agents.json", "target": "path" }
  },
  "mcp_servers": {}
}
```

The only difference is which `merge_targets` keys are present:
- Claude extensions use `claudemd` for CLAUDE.md injection
- OpenCode extensions use `opencode_md` for AGENTS.md injection
- OpenCode extensions may include `opencode_json` for opencode.json agent definitions
- Both use `index` for context index merging

The manifest module already handles all these variants. No schema changes are needed.

### 7. Idempotent Copy Operations

The current copy semantics in `loader.lua`:

| Category | Semantics | Idempotent? |
|----------|-----------|-------------|
| agents, commands, rules | Overwrite always | Yes (same content) |
| skills | Overwrite always (recursive) | Yes |
| context | Overwrite always (recursive) | Yes |
| scripts | Overwrite always (preserves perms) | Yes |
| data | Merge-copy (skip existing) | Yes |
| merge_targets.claudemd | Replace section between markers | Yes |
| merge_targets.settings | Deep merge (no overwrite scalars) | Yes |
| merge_targets.index | Deduplicate by path | Yes |
| merge_targets.opencode_json | Add keys if not exist | Yes |

All operations are idempotent. Repeating an extension load produces the same result. This is crucial for the "predictable results" requirement.

### 8. Core vs Extension Identification Without Symlinks

Three patterns for identifying core vs extension artifacts without relying on symlinks:

**Pattern A: Manifest Enumeration (Recommended)**

Core = everything in the global directory that is NOT listed in any extension manifest.

```
Core artifacts = All files in global/{base_dir}/{category}/
                 MINUS union of all manifest.provides.{category} entries
```

Pros: Definitive, works with any file type (regular, copy, whatever).
Cons: Must scan ~12 manifests (fast -- small JSON files).

**Pattern B: Core Manifest**

Create a `core-manifest.json` that explicitly lists core artifacts:
```json
{
  "agents": ["general-research-agent.md", "planner-agent.md", ...],
  "skills": ["skill-researcher", "skill-planner", ...],
  "commands": ["research.md", "plan.md", ...]
}
```

Pros: Explicit allow-list, no need to read extension manifests.
Cons: Must be maintained manually, can drift from reality.

**Pattern C: File Marker Convention**

Add a comment marker to core artifact files:
```markdown
<!-- core-artifact -->
```

Pros: Self-documenting.
Cons: Invasive, requires modifying all core files, brittle.

**Recommendation: Pattern A** -- it uses existing infrastructure and is always correct.

### 9. Unified Picker Action Design

Currently, the picker has two separate entry points for extension management:
1. "Load Core Agent System" in the main commands picker (loads core sync)
2. Dedicated extension picker (via `:ClaudeExtensions` or `:OpencodeExtensions`)

These can remain separate but should share more code:

**Proposed: Shared extension picker**

Replace both `claude/extensions/picker.lua` and `opencode/extensions/picker.lua` with a single `shared/extensions/picker.lua`:

```lua
-- shared/extensions/picker.lua
function M.create(ext_config, picker_config)
  return {
    show = function(opts)
      -- Use ext_config to get extension manager
      -- Use picker_config for label, prompt title
      -- All key mappings, previewer, entry formatting are shared
    end
  }
end
```

The system-specific wrapper becomes:
```lua
-- claude/extensions/picker.lua
local shared_picker = require("neotex.plugins.ai.shared.extensions.picker")
local ext_config = require("neotex.plugins.ai.claude.extensions.config").get()
local picker_config = require("neotex.plugins.ai.shared.picker.config").claude()
return shared_picker.create(ext_config, picker_config)
```

### 10. Implementation Architecture Summary

```
                    Unified Extension System
                    ========================

    shared/extensions/
    ├── config.lua          # Config schema (claude/opencode presets)
    ├── init.lua            # Manager factory with self-loading guard
    ├── loader.lua          # Copy engine (unchanged)
    ├── manifest.lua        # + aggregate_extension_artifacts()
    ├── merge.lua           # Merge strategies (unchanged)
    ├── state.lua           # State tracking (unchanged)
    ├── verify.lua          # Post-load verification (unchanged)
    └── picker.lua          # NEW: shared extension picker

    shared/picker/
    └── config.lua          # Picker config (unchanged)

    claude/commands/picker/
    ├── utils/scan.lua      # + prefix matching in exclude_patterns
    │                       # + skip_symlinks option
    └── operations/sync.lua # + manifest blocklist integration

    claude/extensions/
    ├── init.lua            # unchanged (thin wrapper)
    ├── config.lua          # unchanged (thin wrapper)
    ├── loader.lua          # can be removed (just re-exports)
    ├── state.lua           # can be simplified (remove method-by-method delegation)
    └── picker.lua          # simplified to delegate to shared picker

    opencode/extensions/
    ├── init.lua            # unchanged (thin wrapper)
    ├── config.lua          # unchanged (thin wrapper)
    └── picker.lua          # simplified to delegate to shared picker
```

### 11. Concrete Changes Required

**Change 1: Add `aggregate_extension_artifacts()` to manifest.lua**
- Read all extension manifests
- Build a blocklist keyed by category
- Return set-based structure for O(1) lookup

**Change 2: Enhance scan.lua exclude matching**
- Support prefix matching for skills (directory names) and context (path prefixes)
- Add optional `skip_symlinks` parameter as defense in depth
- Backward-compatible with existing exact-match patterns

**Change 3: Apply blocklist in sync.lua**
- Build blocklist at start of `scan_all_artifacts()` using the appropriate config
- Pass category-specific excludes to each `sync_scan()` call
- Works identically for both `.claude` and `.opencode` base_dir values

**Change 4: Add self-loading guard to shared/extensions/init.lua**
- Check `project_dir == global_dir` before extension load
- Return error with clear message
- Prevents future contamination of global directories

**Change 5: Create shared/extensions/picker.lua**
- Factor out the common picker logic (245 lines of 248 are identical)
- Accept extension manager and picker config as parameters
- Reduce each system-specific picker to ~10 lines

**Change 6: Simplify claude/extensions/state.lua** (optional)
- The 102-line wrapper that delegates method-by-method can be replaced with a simpler pattern
- Either pass config on each call or use the same factory pattern as init.lua

**Change 7: Clean existing symlinks** (one-time migration)
- Remove symlinks from global `.claude/agents/`, `.claude/skills/`, `.claude/commands/`
- Verify core artifacts are still regular files
- Update sync.lua module comment

## Decisions

1. **Manifest-based blocklist** is the primary filtering mechanism (Pattern A)
2. **Self-loading guard** prevents future contamination
3. **Symlink skip** is defense in depth, not primary mechanism
4. **Shared extension picker** replaces two duplicate 245-line files
5. **No manifest schema changes** are needed -- the current schema already supports both systems
6. **All copy operations remain idempotent** -- the design preserves this property
7. **The blocklist is computed per-sync**, not cached, to ensure correctness after extension installs/removals

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Manifest blocklist misses files not in any manifest | Very Low | Medium | Symlink skip as backup; clean global dir removes root cause |
| Self-loading guard breaks a workflow | Low | Medium | Clear error message; `opts.force` override available |
| Shared picker introduces regressions | Low | Low | Both pickers are already nearly identical; changes are minimal |
| Prefix matching in exclude_patterns causes over-filtering | Low | Medium | Prefix matching only activates for patterns containing `/` |
| Extension manifest changes break blocklist | Very Low | Low | validate() already enforces schema; blocklist is defensive only |

## Appendix

### Files Analyzed

**Shared infrastructure** (6 files):
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Manager factory
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Copy engine
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Manifest handling
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Merge strategies
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - State tracking
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - Verification
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - Config schema
- `lua/neotex/plugins/ai/shared/picker/config.lua` - Picker config

**Claude-specific** (6 files):
- `lua/neotex/plugins/ai/claude/extensions/init.lua` - Thin wrapper
- `lua/neotex/plugins/ai/claude/extensions/config.lua` - Config wrapper
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` - Re-export (unnecessary)
- `lua/neotex/plugins/ai/claude/extensions/state.lua` - Method wrapper (oversized)
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Extension picker (duplicate)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Core sync
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Main picker

**OpenCode-specific** (4 files):
- `lua/neotex/plugins/ai/opencode/extensions/init.lua` - Thin wrapper
- `lua/neotex/plugins/ai/opencode/extensions/config.lua` - Config wrapper
- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Extension picker (duplicate)
- `lua/neotex/plugins/ai/opencode/commands/picker.lua` - Picker facade
- `lua/neotex/plugins/ai/opencode/core/init.lua` - OpenCode core setup

**Extension manifests examined** (6 files):
- `.claude/extensions/nvim/manifest.json` - Standard claude manifest
- `.claude/extensions/latex/manifest.json` - Claude manifest with hooks
- `.opencode/extensions/nvim/manifest.json` - OpenCode manifest (compare merge_targets)
- `.opencode/extensions/memory/manifest.json` - OpenCode-only extension with data, mcp_servers, settings
- `.opencode/extensions/lean/manifest.json` - OpenCode lean manifest
- `.claude/extensions/web/manifest.json` - Claude web manifest

### Key Measurements
- Shared modules: 7 files, ~1200 lines total
- Claude wrappers: 6 files, ~640 lines (picker alone is 245)
- OpenCode wrappers: 3 files, ~275 lines (picker alone is 245)
- Extension picker duplication: 490 lines across 2 files, ~3 lines differ
- Extension manifests: 11 (.claude), 12 (.opencode), all valid JSON
- Categories in blocklist: 7 (agents, skills, commands, rules, scripts, hooks, context)
- Config parameters: 7 in extension config, 11 in picker config
