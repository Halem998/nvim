# Research Report: Fix Extension Loader to Copy manifest.json

**Task**: 533 - fix_extension_loader_manifest  
**Agent**: neovim-research-agent  
**Date**: 2026-05-07

---

## Executive Summary

The Neovim extension loader (`lua/neotex/plugins/ai/shared/extensions/`) copies extension artifacts (agents, skills, commands, rules, context, scripts, hooks, docs, templates, systemd units, root files, and data directories) into the target project's `.opencode/` or `.claude/` directory during `manager.load()`. However, it **does not copy `manifest.json`** into the target project's extension subdirectory (e.g., `.opencode/extensions/{name}/manifest.json`).

This omission breaks agent routing in `/implement`, `/research`, and `/plan` commands. These commands contain shell scripts that scan `.opencode/extensions/*/manifest.json` (or `.claude/extensions/*/manifest.json`) to look up `task_type`-to-skill routing mappings declared in each extension's manifest.

## Root Cause Analysis

### 1. The Extension Loader Architecture

The extension system is parameterized to support both Claude (`.claude/`) and OpenCode (`.opencode/`). The shared loader lives in:

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — File copy engine
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `manager.load()` / `manager.unload()`
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — Post-load verification
- `lua/neotex/plugins/ai/shared/extensions/state.lua` — `extensions.json` state tracking

The OpenCode facade is at:
- `lua/neotex/plugins/ai/opencode/extensions/init.lua` — Creates manager with OpenCode config
- `lua/neotex/plugins/ai/opencode/extensions/config.lua` — Returns `shared_config.opencode(global_dir)`

### 2. Current Copy Logic in `manager.load()`

Inside `manager.load()` (`init.lua`, lines 395–490), the loader calls a series of `loader_mod.copy_*()` functions:

1. `copy_simple_files` — agents, commands, rules
2. `copy_skill_dirs` — skills (recursive)
3. `copy_context_dirs` — context (recursive)
4. `copy_scripts` — scripts
5. `copy_hooks` — hooks
6. `copy_docs` — docs
7. `copy_templates` — templates
8. `copy_systemd` — systemd units
9. `copy_root_files` — root-level files (settings.json, .gitignore)
10. `copy_data_dirs` — data directories (merge-copy semantics)

**There is no `copy_manifest()` call.**

### 3. Why `manifest.json` Is Excluded

`manifest.json` is not listed in any `provides` category, and there is no dedicated copy function for it. The loader was designed to copy only the artifacts declared in `manifest.provides.*` and the special-case merge targets. The manifest itself was considered a source-only file, not a runtime artifact.

However, the command system treats `manifest.json` as a runtime artifact. The following command files contain shell loops that scan for it:

- `.opencode/commands/implement.md` (line 375)
- `.opencode/commands/research.md` (line 340)
- `.opencode/commands/plan.md` (line 344)
- `.claude/commands/implement.md` (line 374)
- `.claude/commands/research.md` (line 339)
- `.claude/commands/plan.md` (line 343)

Example snippet from `.opencode/commands/implement.md`:

```bash
for manifest in .opencode/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.implement[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done
```

Because `manifest.json` is never copied, these loops find no extension manifests in the target project, and routing always falls back to the default skills (`skill-researcher`, `skill-planner`, `skill-implementer`).

### 4. `installed_files` Tracking

`manager.load()` tracks every copied file in `all_files` and every created directory in `all_dirs`. These arrays are converted to relative paths and persisted in `extensions.json` via `state_mod.mark_loaded()`.

`manager.unload()` reads these arrays back, converts them to absolute paths, and passes them to `loader_mod.remove_installed_files()`, which deletes files and then removes empty directories.

Because `manifest.json` is not in `all_files`, it is:
- Not persisted in state
- Not removed on unload
- Left as an orphaned file if manually created

## Files Requiring Modification

### 1. `lua/neotex/plugins/ai/shared/extensions/loader.lua`

**Change**: Add a new `copy_manifest()` function.

```lua
--- Copy manifest.json into target project's extensions subdirectory
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param extension_name string Extension name
--- @return table copied_files Array of copied file paths
--- @return table created_dirs Array of created directory paths
function M.copy_manifest(manifest, source_dir, target_dir, extension_name)
  local copied_files = {}
  local created_dirs = {}

  local source_path = source_dir .. "/manifest.json"
  local ext_dir = target_dir .. "/extensions/" .. extension_name
  local target_path = ext_dir .. "/manifest.json"

  if vim.fn.filereadable(source_path) == 1 then
    if vim.fn.isdirectory(ext_dir) ~= 1 then
      helpers.ensure_directory(ext_dir)
      table.insert(created_dirs, ext_dir)
    end

    if copy_file(source_path, target_path, false) then
      table.insert(copied_files, target_path)
    end
  end

  return copied_files, created_dirs
end
```

Placement: After `copy_data_dirs()` and before `check_conflicts()`, or at the end of the copy-function block.

### 2. `lua/neotex/plugins/ai/shared/extensions/init.lua`

**Change**: Invoke `loader_mod.copy_manifest()` during `manager.load()`.

Inside the `pcall` block (around line 448, after `copy_root_files` and before `copy_data_dirs`, or after all other copies), add:

```lua
      -- Copy manifest.json for runtime routing
      files, dirs = loader_mod.copy_manifest(ext_manifest, source_dir, target_dir, extension_name)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
```

This ensures:
- `manifest.json` is copied to `.opencode/extensions/{name}/manifest.json`
- The `extensions/{name}/` directory is created and tracked
- The copied file is recorded in `all_files`
- The copied file is removed on `manager.unload()`

### 3. `lua/neotex/plugins/ai/shared/extensions/verify.lua`

**Change**: Add a verification step for the copied manifest.

In `M.verify_extension()` (around line 284), after reading the source manifest, add a check that the target manifest exists:

```lua
  local target_manifest_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"
  if not file_exists(target_manifest_path) then
    verification.status = "failed"
    table.insert(verification.errors, "Missing target manifest.json at " .. target_manifest_path)
  end
```

Alternatively, add a new `verify_manifest_target()` helper and include it in the verification report.

## Files NOT Requiring Modification

- `lua/neotex/plugins/ai/shared/extensions/state.lua` — No changes needed; `mark_loaded()` already accepts `installed_files` and `installed_dirs` arrays generically.
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` — No changes needed; manifest parsing and validation are unaffected.
- `lua/neotex/plugins/ai/shared/extensions/config.lua` — No changes needed; base configuration is unaffected.
- `lua/neotex/plugins/ai/opencode/extensions/init.lua` — No changes needed; it delegates to `shared.create()`.
- `lua/neotex/plugins/ai/opencode/extensions/config.lua` — No changes needed.

## Verification Plan

After implementation, the following should be verified:

1. **Load an extension** (e.g., `:lua require("neotex.plugins.ai.opencode.extensions").load("core")`)
   - Confirm `.opencode/extensions/core/manifest.json` is created in the target project.
   - Confirm `extensions.json` lists the manifest file in `installed_files`.

2. **Unload the extension**
   - Confirm `.opencode/extensions/core/manifest.json` is removed.
   - Confirm the `.opencode/extensions/core/` directory is removed if empty.

3. **Run command routing**
   - Confirm the shell loops in `/implement`, `/research`, and `/plan` find the copied manifests.

4. **Run `verify_extension`**
   - Confirm verification passes for the copied manifest.

## Expected Behavior After Fix

- `manager.load("core")` copies `manifest.json` to `{project}/.opencode/extensions/core/manifest.json`.
- The copied manifest is tracked in `installed_files` and removed on `manager.unload()`.
- Agent routing commands (`/implement`, `/research`, `/plan`) successfully scan extension manifests in the target project.
- Extension-specific skills (e.g., `skill-nix-research`, `skill-neovim-implementation`) are correctly resolved by task type.
