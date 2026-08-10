# Supplementary Research Report: Task #118

**Task**: 118 - Redesign leader ao picker: Load All Artifacts -> Load Core Agent System
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T01:00:00Z
**Effort**: Supplementary (included in original 3-5 hour estimate)
**Dependencies**: None
**Sources/Inputs**: Claude picker codebase analysis, shared picker config, extension system architecture
**Artifacts**: - specs/118_redesign_leader_ao_load_core_agent_system/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The `<leader>ac` Claude picker uses an entirely shared infrastructure that is also used by `<leader>ao` OpenCode picker -- there is no separate Claude-specific loading logic to examine
- The core/extension separation must be implemented once in the shared `sync.lua` code and will automatically benefit both pickers
- The previewer (`previewer.lua`) has a **hardcoded `.claude`-only preview** that does not respect the `config.base_dir` parameter -- this is a gap that needs fixing as part of this task
- The extension system is cleanly separated: manifests define `provides` declaratively, and `manifest.list_extensions(config)` returns all available extensions parameterized by base_dir
- Three improvements needed for the Claude Code loading path are identified: (1) config-aware previewer, (2) extension exclusion in scan, (3) label rename

## Context & Scope

This supplementary research examines the `<leader>ac` Claude Code picker to understand how extensions and core content interact during loading. The goal is to identify patterns applicable to the `<leader>ao` OpenCode picker redesign, and to determine if the Claude picker itself needs improvements.

## Findings

### 1. Shared Architecture: Both Pickers Use Identical Code

The OpenCode picker (`lua/neotex/plugins/ai/opencode/commands/picker.lua`) is a thin facade:

```lua
local internal = require("neotex.plugins.ai.claude.commands.picker.init")
local shared_config = require("neotex.plugins.ai.shared.picker.config")

function M.show_commands_picker(opts)
  local config = shared_config.opencode()
  return internal.show_commands_picker(opts, config)
end
```

Both `<leader>ac` and `<leader>ao` call the same `picker/init.lua:show_commands_picker(opts, config)`. The `config` object (from `shared.picker.config`) controls:

| Field | Claude Value | OpenCode Value |
|-------|-------------|----------------|
| `base_dir` | `.claude` | `.opencode` |
| `label` | `"Claude"` | `"OpenCode"` |
| `agents_subdir` | `"agents"` | `"agent/subagents"` |
| `hooks_subdir` | `"hooks"` | `nil` |
| `settings_file` | `"settings.local.json"` | `"settings.json"` |
| `root_config_file` | `"CLAUDE.md"` | `"OPENCODE.md"` |
| `extensions_module` | `"neotex.plugins.ai.claude.extensions"` | `"neotex.plugins.ai.opencode.extensions"` |

**Implication**: Any filtering logic added to `scan_all_artifacts()` or `entries.create_special_entries()` automatically works for both systems since the `config` parameter already carries `base_dir` for extension directory discovery.

### 2. Load All Flow Analysis

When a user selects "[Load All Artifacts]" in either picker:

```
picker/init.lua (line 93-94):
  if selection.value.is_load_all then
    local loaded = sync.load_all_globally(config)
```

This calls `sync.load_all_globally(config)` which:

1. Gets `project_dir` (cwd) and `global_dir` (~/.config/nvim)
2. Calls `scan_all_artifacts(global_dir, project_dir, config)` (line 279)
3. Counts total files, shows confirmation dialog
4. Calls `execute_sync(project_dir, all_artifacts, merge_only, base_dir)` (line 351)

The `config` parameter flows through the entire chain. The `scan_all_artifacts()` function (lines 159-261) already receives config with `base_dir` and `agents_subdir`. The extension config needs `global_extensions_dir` which can be derived from `base_dir` + `global_dir`.

### 3. Previewer Gap: Hardcoded .claude Path

**File**: `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`

The `preview_load_all()` function (lines 181-266) is **not config-aware**. It hardcodes `.claude` paths:

```lua
local function preview_load_all(self)
  local project_dir = vim.fn.getcwd()
  local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
  local global_dir = scan.get_global_dir()

  local commands = scan_directory_for_sync(global_dir, project_dir, "commands", "*.md")
  -- ... all scan_directory_for_sync calls use hardcoded ".claude" internally
```

The local `scan_directory_for_sync` helper (lines 18-38) hardcodes `.claude`:

```lua
local function scan_directory_for_sync(global_dir, project_dir, subdir, extension)
  local global_path = global_dir .. "/.claude/" .. subdir
  local local_path = project_dir .. "/.claude/" .. subdir
```

**Impact**: When the OpenCode picker shows the "Load All" preview, the counts displayed are for `.claude` artifacts, not `.opencode` artifacts. This is an existing bug that the user may not have noticed because the Load All entry description is generic and the preview is informational only.

**Similarly**, the `preview_help()` function (lines 116-176) references `.claude` specifically:

```lua
"  *       - Artifact defined locally in project (.claude/)",
"            Otherwise a global artifact from " .. global_dir .. "/.claude/",
```

### 4. Extension Discovery Architecture

The extension system is well-parameterized:

```
shared/extensions/config.lua
  M.claude(global_dir) -> { global_extensions_dir: "~/.config/nvim/.claude/extensions" }
  M.opencode(global_dir) -> { global_extensions_dir: "~/.config/nvim/.opencode/extensions" }

shared/extensions/manifest.lua
  M.list_extensions(config) -> scans config.global_extensions_dir for */manifest.json
```

Each manifest has a `provides` field:
```json
{
  "provides": {
    "agents": ["lean-research-agent.md"],
    "skills": ["skill-lean-research"],
    "commands": ["lake.md"],
    "rules": ["lean4.md"],
    "context": ["project/lean4"],
    "scripts": ["setup-lean-mcp.sh"],
    "hooks": []
  }
}
```

**Key insight**: The `provides` field uses consistent naming conventions that match what `scan_all_artifacts()` returns:
- **agents**: filenames with `.md` extension (match against `file.name`)
- **skills**: directory names like `skill-lean-research` (match against path segments)
- **commands**: filenames with `.md` extension
- **rules**: filenames with `.md` extension
- **context**: relative directory paths under `context/` (match as path prefix)
- **scripts**: filenames with `.sh` extension
- **hooks**: filenames with `.sh` extension

### 5. Claude vs OpenCode Extension State

Both systems have independent extension state:

| State File | Location | Tracked By |
|-----------|----------|------------|
| Claude | `{project}/.claude/extensions.json` | `shared/extensions/state.lua` |
| OpenCode | `{project}/.opencode/extensions.json` | `shared/extensions/state.lua` |

The global source directories are separate:
- Claude: `~/.config/nvim/.claude/extensions/` (9 extensions)
- OpenCode: `~/.config/nvim/.opencode/extensions/` (may differ)

The `.claude` global directory is currently clean (no extension content mixed in), but the architecture supports both systems identically. Filtering should still be applied to `.claude` for future-proofing.

### 6. Config Threading Through Picker Entry Creation

The `entries.create_special_entries()` function (lines 658-686) does **not** receive `config`:

```lua
function M.create_special_entries()
  local entries = {}
  table.insert(entries, {
    is_load_all = true,
    name = "~~~load_all",
    display = string.format("%-40s %s", "[Load All Artifacts]", "Sync commands, hooks, ..."),
    ...
  })
```

But `create_picker_entries(structure, config)` (line 693) calls it without passing config:

```lua
local special = M.create_special_entries()
```

To make the label configurable per-system ("Load Core Agent System" vs some other label), the config should be threaded through:

```lua
-- entries.lua
function M.create_special_entries(config)
  local label = config and config.label or "Claude"
  -- Use label in display text
end

-- In create_picker_entries:
local special = M.create_special_entries(config)
```

### 7. The Previewer Does Not Receive Config

The `create_command_previewer()` (lines 750-787) creates a previewer closure that has no access to `config`. The `preview_load_all()` function is called without any config context:

```lua
elseif entry.value.is_load_all then
  preview_load_all(self)  -- No config parameter
```

To make the previewer config-aware, options include:

**Option A**: Store config in the entry value
```lua
-- In create_special_entries:
table.insert(entries, {
  is_load_all = true,
  config = config,  -- Attach config to entry
  ...
})

-- In previewer:
preview_load_all(self, entry.value.config)
```

**Option B**: Pass config to create_command_previewer
```lua
function M.create_command_previewer(config)
  -- Closure captures config
  return previewers.new_buffer_previewer({
    define_preview = function(self, entry, status)
      ...
      elseif entry.value.is_load_all then
        preview_load_all(self, config)
```

**Option A is simpler** and keeps the previewer generic. The entry already carries metadata.

### Recommendations

#### For the "Load Core Agent System" Implementation

1. **Shared exclusion builder**: Add a function to `sync.lua` that calls `manifest.list_extensions(ext_config)` and builds per-category exclusion sets. This function takes the `base_dir` from config and derives the extension config:

   ```lua
   local function build_extension_exclusions(global_dir, config)
     local ext_config_mod = require("neotex.plugins.ai.shared.extensions.config")
     local base_dir = (config and config.base_dir) or ".claude"
     local ext_config
     if base_dir == ".opencode" then
       ext_config = ext_config_mod.opencode(global_dir)
     else
       ext_config = ext_config_mod.claude(global_dir)
     end
     local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")
     local extensions = manifest_mod.list_extensions(ext_config)
     -- Build exclusion sets from provides fields
   end
   ```

2. **Fix the previewer gap**: Thread config through to `preview_load_all()` and `preview_help()` so they use `config.base_dir` instead of hardcoded `.claude`. This is a bug fix that should be included in this task.

3. **Thread config to special entries**: Pass config to `create_special_entries(config)` for system-appropriate labeling.

#### Improvements Needed for Claude Code System

1. **Previewer config-awareness** (bug): `preview_load_all()` and `preview_help()` hardcode `.claude` paths. When called from the OpenCode picker, they show incorrect information. Fix: accept config parameter and use `config.base_dir`.

2. **Preview count accuracy**: Once extension filtering is added to `scan_all_artifacts()`, the preview in `preview_load_all()` should also show filtered counts (core only). Currently it shows all files. The previewer uses its own local `scan_directory_for_sync` helper (not the shared one), so it needs to either: (a) reuse the shared scan + filter, or (b) show a note that counts include all files.

3. **Help text genericity**: The help text in `preview_help()` references `.claude/` literally. It should use `config.base_dir` for accuracy.

## Decisions

1. **One implementation serves both systems**: Since both pickers share the same code, the exclusion logic goes in `sync.lua` once and benefits both `<leader>ac` and `<leader>ao`.

2. **Fix previewer as part of this task**: The hardcoded `.claude` in the previewer is a related bug that should be fixed while implementing the label rename.

3. **Use entry-based config passing (Option A)**: Attach config to the load_all entry value rather than refactoring the previewer constructor. This is less invasive.

4. **Build exclusions from manifest.list_extensions()**: Reuse the existing manifest infrastructure rather than manual file scanning.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Previewer fix is scope creep | The fix is simple (pass base_dir), directly related to the rename task, and prevents showing wrong data |
| Extension config derivation from base_dir | Use the existing `shared.extensions.config.claude()` / `.opencode()` presets -- already parameterized |
| Previewer uses local scan helper, not shared scan | For preview accuracy, either delegate to shared scan or add a "counts may include extensions" note |

## Context Extension Recommendations

None -- this task is focused on Neovim plugin code, not context documentation.

## Appendix

### Complete File Inventory for Modification

Files identified across both research reports:

1. **`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`**
   - Add `build_extension_exclusions()` function
   - Add `filter_extension_files()` utility
   - Modify `scan_all_artifacts()` to apply filtering

2. **`lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`**
   - Modify `create_special_entries()` to accept config
   - Rename "[Load All Artifacts]" to "[Load Core Agent System]"
   - Update `create_picker_entries()` to pass config to special entries

3. **`lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`**
   - Fix `preview_load_all()` to accept and use config (base_dir aware)
   - Fix `preview_help()` to use config.base_dir instead of hardcoded `.claude`
   - Update title from "Load All Artifacts" to "Load Core Agent System"

4. **`lua/neotex/plugins/ai/claude/commands/picker/init.lua`**
   - No changes needed (config already flows to `sync.load_all_globally(config)`)

### Architecture Diagram: Config Flow

```
<leader>ac                              <leader>ao
    |                                       |
    v                                       v
shared_config.claude()              shared_config.opencode()
    |                                       |
    +-----------> config <------------------+
                    |
                    v
          picker/init.lua
          show_commands_picker(opts, config)
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
  entries.lua   previewer.lua  sync.lua
  (config)      (config)       (config)
```

### Comparison: How Extension Loading Works

| Operation | Current Behavior | After Implementation |
|-----------|-----------------|---------------------|
| `[Load All]` select | Copies ALL files from global/{base_dir}/ | Copies only NON-extension files |
| Preview counts | Shows ALL files (hardcoded .claude) | Shows CORE-ONLY files (config-aware) |
| Help text | References `.claude/` literally | References `config.base_dir` |
| Label | "[Load All Artifacts]" | "[Load Core Agent System]" |
| Extension toggle | Separate in [Extensions] section | Unchanged (separate toggle) |

### Search Queries Used

- Local file analysis: Read, Glob, Grep on picker module tree
- Extension manifest structure analysis
- Shared infrastructure tracing (config -> picker -> entries -> sync)
- OpenCode facade analysis
