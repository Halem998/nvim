-- neotex.plugins.ai.shared.extensions
-- Shared extension management public API (parameterized)

local M = {}

-- Dependencies
local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")
local state_mod = require("neotex.plugins.ai.shared.extensions.state")
local loader_mod = require("neotex.plugins.ai.shared.extensions.loader")
local merge_mod = require("neotex.plugins.ai.shared.extensions.merge")
local verify_mod = require("neotex.plugins.ai.shared.extensions.verify")
local settings_backup = require("neotex.plugins.ai.shared.extensions.settings_backup")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Convert absolute path to relative (from project_dir)
--- @param abs_path string Absolute file path
--- @param project_dir string Project directory
--- @return string rel_path Relative path
local function to_relative_path(abs_path, project_dir)
  if abs_path:sub(1, #project_dir) == project_dir then
    local rel = abs_path:sub(#project_dir + 2)  -- +2 to skip trailing /
    return rel
  end
  return abs_path
end

--- Convert array of absolute paths to relative paths
--- @param abs_paths table Array of absolute paths
--- @param project_dir string Project directory
--- @return table rel_paths Array of relative paths
local function paths_to_relative(abs_paths, project_dir)
  local rel_paths = {}
  for _, abs_path in ipairs(abs_paths) do
    table.insert(rel_paths, to_relative_path(abs_path, project_dir))
  end
  return rel_paths
end

--- Read file contents as string
--- @param filepath string Path to file
--- @return string|nil content File contents or nil
local function read_file_string(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

--- Read JSON file
--- @param filepath string Path to JSON file
--- @return table|nil data Parsed JSON or nil
local function read_json(filepath)
  local content = read_file_string(filepath)
  if not content then
    return nil
  end
  local ok, result = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return result
end

--- Process merge targets for an extension
--- @param ext_manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param project_dir string Target project directory
--- @param config table Extension system configuration
--- @return table merged_sections Tracking data for unmerge
local function process_merge_targets(ext_manifest, source_dir, project_dir, config)
  local merged_sections = {}

  if not ext_manifest.merge_targets then
    return merged_sections
  end

  local target_dir = project_dir .. "/" .. config.base_dir

  -- Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact.
  -- Section injection is skipped here; generate_claudemd() regenerates the file
  -- from all loaded extensions after each load/unload operation.
  -- The merge_key entry in merged_sections is intentionally left empty so that
  -- reverse_merge_targets has nothing to remove (generation handles removal by
  -- regenerating without the unloaded extension's content).

  -- Process settings merge
  if ext_manifest.merge_targets.settings then
    local mt_config = ext_manifest.merge_targets.settings
    local source_path = source_dir .. "/" .. mt_config.source
    local target_path = project_dir .. "/" .. mt_config.target

    local fragment = read_json(source_path)
    if fragment then
      local success, tracked = merge_mod.merge_settings(target_path, fragment)
      if success then
        merged_sections.settings = tracked
      end
    end
  end

  -- Process index.json entries
  if ext_manifest.merge_targets.index then
    local mt_config = ext_manifest.merge_targets.index
    local source_path = source_dir .. "/" .. mt_config.source
    local target_path = project_dir .. "/" .. mt_config.target

    local entries_data = read_json(source_path)
    if entries_data then
      -- Handle both {entries: [...]} object format and bare [...] array format
      local entries = entries_data.entries or (vim.isarray(entries_data) and entries_data) or nil
      if entries then
        local success, tracked = merge_mod.append_index_entries(target_path, entries)
        if success then
          merged_sections.index = tracked
        end
      end
    end
  end

  -- opencode.json is now a computed artifact regenerated after state update.
  -- generate_opencode_json() rebuilds the file from the base template + all
  -- loaded extension fragments. Per-extension merge/unmerge is no longer used.

  return merged_sections
end

--- Reverse merge operations for an extension
--- @param ext_manifest table Extension manifest
--- @param merged_sections table Tracking data from process_merge_targets
--- @param project_dir string Target project directory
--- @param config table Extension system configuration
local function reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
  if not ext_manifest or not merged_sections then
    return
  end

  local merge_key = config.merge_target_key

  -- Config markdown section removal is skipped: CLAUDE.md is now a computed artifact.
  -- generate_claudemd() is called after state is updated (extension removed from state)
  -- so regeneration naturally excludes the unloaded extension's content.

  -- Reverse settings merge
  if merged_sections.settings and ext_manifest.merge_targets and ext_manifest.merge_targets.settings then
    local mt_config = ext_manifest.merge_targets.settings
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.unmerge_settings(target_path, merged_sections.settings)
  end

  -- Reverse index entries
  if merged_sections.index and ext_manifest.merge_targets and ext_manifest.merge_targets.index then
    local mt_config = ext_manifest.merge_targets.index
    local target_path = project_dir .. "/" .. mt_config.target
    merge_mod.remove_index_entries_tracked(target_path, merged_sections.index)
  end

  -- opencode.json is now a computed artifact regenerated after state update.
  -- generate_opencode_json() rebuilds the file without the unloaded extension's
  -- content. Per-extension unmerge is no longer used.
end

--- Detect whether a project has legacy core files without extensions.json entry.
--- A "legacy core" repo is one where core agent files exist directly under .claude/
--- (e.g., .claude/agents/ contains .md files) but extensions.json does not list
--- core as loaded. This indicates a pre-migration repo that has not yet been updated
--- to the real-extension model.
--- @param project_dir string Project root directory
--- @param config table Extension system configuration
--- @param core_manifest table|nil Core extension manifest (used to filter out extension-managed agents)
--- @return boolean is_legacy True when legacy core files are detected
--- @return string|nil detail Human-readable description of what was found
local function detect_legacy_core(project_dir, config, core_manifest)
  local target_dir = project_dir .. "/" .. config.base_dir

  -- Check whether core is already tracked in extensions.json
  local state = state_mod.read(project_dir, config)
  if state_mod.is_loaded(state, "core") then
    -- Core is already managed by the extension system; no legacy detection needed
    return false, nil
  end

  -- Build a set of agent filenames declared by the core manifest.
  -- Only files in this set are considered "legacy core" indicators.
  -- Extension-managed agents (nvim, nix, etc.) live in the same agents/ dir
  -- and must not be flagged as legacy.
  local core_agents = {}
  if core_manifest
    and core_manifest.provides
    and core_manifest.provides.agents
  then
    for _, agent_file in ipairs(core_manifest.provides.agents) do
      -- agent_file is a basename like "general-research-agent.md"
      core_agents[agent_file] = true
    end
  end

  -- Check for the most reliable indicator: agent files in the base .claude/agents/ dir.
  -- In the new architecture these live in extensions/core/ and are installed by the loader.
  -- Their presence in the root agents/ dir without an extensions.json entry is the telltale.
  local agents_dir = target_dir .. "/agents"
  if vim.fn.isdirectory(agents_dir) == 1 then
    local handle = vim.loop.fs_scandir(agents_dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "file" and name:match("%.md$") and name ~= ".gitkeep" and core_agents[name] then
          return true, string.format(
            "Legacy core detected: '%s/%s' exists without extensions.json entry",
            agents_dir, name
          )
        end
      end
    end
  end

  return false, nil
end

--- Create an extension manager instance with the given configuration
--- @param config table Extension system configuration from config.lua
--- @return table manager Extension manager with load, unload, reload, etc.
function M.create(config)
  local manager = {}

  --- Load an extension into the current project
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil, force = false}
  --- @return boolean success True if load succeeded
  --- @return string|nil error Error message if load failed
  function manager.load(extension_name, opts)
    opts = opts or {}
    local confirm = opts.confirm ~= false  -- Default to true
    local project_dir = opts.project_dir or vim.fn.getcwd()
    local target_dir = project_dir .. "/" .. config.base_dir

    -- Find extension
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return false, "Extension not found: " .. extension_name
    end

    local ext_manifest = extension.manifest
    local source_dir = extension.path

    -- Check if already loaded. `opts.force` bypasses ONLY this abort -- everything downstream
    -- (the copy sequence, merge-target processing, state update) is already idempotent/
    -- overwrite-safe given the install-once root-files guard, so no further special-casing is
    -- needed to make a forced re-run of an already-loaded extension safe.
    --
    -- Dual effect of `opts.force`, deliberate rather than an accidental name collision: this
    -- same field is also threaded to recursive dependency loads below ("Resolve dependencies"),
    -- so forcing a resync of an extension also force-resyncs any of its dependencies that are
    -- already loaded, rather than short-circuiting them as already-satisfied. This is the
    -- desired effect for `manager.resync_all` (every active extension gets fresh files,
    -- transitively) and is harmless for a plain single-extension force-load (dependencies that
    -- were not already active are loaded normally regardless of `force`).
    local state = state_mod.read(project_dir, config)
    if state_mod.is_loaded(state, extension_name) and not opts.force then
      return false, "Extension already loaded: " .. extension_name
    end

    -- Migration detection: when loading core into a repo that has legacy-style core
    -- files (pre-migration repos with files directly under .claude/ without an
    -- extensions.json entry), notify the user. The loader will still proceed and
    -- overwrite conflicts as usual -- the conflict count in the confirmation dialog
    -- communicates this to the user. This is not an error condition.
    if extension_name == "core" then
      local is_legacy, legacy_detail = detect_legacy_core(project_dir, config, ext_manifest)
      if is_legacy then
        vim.schedule(function()
          vim.notify(
            "Migration notice: This repo has legacy core files (pre-extension-system).\n"
              .. "Loading core will migrate them to extension-managed files.\n"
              .. (legacy_detail or ""),
            vim.log.levels.INFO
          )
        end)
      end
    end

    -- Dependency resolution: auto-load declared dependencies before proceeding
    local loading_stack = opts._loading_stack or {}
    local max_depth = 5

    -- Circular dependency detection
    for _, stack_name in ipairs(loading_stack) do
      if stack_name == extension_name then
        local cycle = table.concat(loading_stack, " -> ") .. " -> " .. extension_name
        return false, "Circular dependency detected: " .. cycle
      end
    end

    -- Depth limit check
    if #loading_stack >= max_depth then
      return false, string.format(
        "Dependency depth limit (%d) exceeded while loading '%s'",
        max_depth, extension_name
      )
    end

    -- Resolve dependencies
    local deps = ext_manifest.dependencies or {}
    local deps_to_load = {}
    for _, dep_name in ipairs(deps) do
      -- Re-read state each iteration (previous dep may have changed it)
      state = state_mod.read(project_dir, config)
      if not state_mod.is_loaded(state, dep_name) then
        table.insert(deps_to_load, dep_name)
      end
    end

    -- Load unloaded dependencies recursively
    if #deps_to_load > 0 then
      local child_stack = vim.list_extend({}, loading_stack)
      table.insert(child_stack, extension_name)

      for _, dep_name in ipairs(deps_to_load) do
        local dep_ok, dep_err = manager.load(dep_name, {
          confirm = false,  -- dependencies load silently
          project_dir = project_dir,
          force = opts.force,
          _loading_stack = child_stack,
        })
        if not dep_ok then
          return false, string.format(
            "Failed to load dependency '%s' for '%s': %s",
            dep_name, extension_name, dep_err or "unknown error"
          )
        end
      end
    end

    -- Check for conflicts (used in confirmation dialog)
    local conflicts = loader_mod.check_conflicts(ext_manifest, target_dir, project_dir)

    -- Single merged confirmation dialog
    if confirm then
      local provides_summary = ""
      if ext_manifest.provides then
        for category, files in pairs(ext_manifest.provides) do
          if type(files) == "table" and #files > 0 then
            provides_summary = provides_summary .. "  " .. category .. ": " .. #files .. "\n"
          end
        end
      end

      -- Include conflict info in the message if conflicts exist
      local conflict_note = ""
      local overwrite_count = 0
      local merge_count = 0
      for _, conflict in ipairs(conflicts) do
        if conflict.merge then
          merge_count = merge_count + 1
        else
          overwrite_count = overwrite_count + 1
        end
      end
      if overwrite_count > 0 then
        conflict_note = string.format("\n\nNote: %d existing file(s) will be overwritten.", overwrite_count)
      end
      if merge_count > 0 then
        conflict_note = conflict_note .. string.format("\n%d data director%s will be merged (existing files preserved).",
          merge_count, merge_count > 1 and "ies" or "y")
      end

      -- Include dependency info in message
      local dep_note = ""
      if #deps_to_load > 0 then
        dep_note = "\nDependencies loaded: " .. table.concat(deps_to_load, ", ")
      elseif #deps > 0 then
        dep_note = "\nDependencies (already loaded): " .. table.concat(deps, ", ")
      end

      local message = string.format(
        "Load extension '%s' v%s?\n\n%s\n%s%s%s",
        extension_name,
        ext_manifest.version,
        ext_manifest.description,
        provides_summary ~= "" and "\nFiles to install:\n" .. provides_summary or "",
        dep_note,
        conflict_note
      )

      local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
      if choice ~= 1 then
        helpers.notify("Extension load cancelled", "INFO")
        return false, "Cancelled by user"
      end
    end

    -- Ensure base directory exists
    helpers.ensure_directory(target_dir)

    -- Load .syncprotect to skip protected files during copy operations
    local protected_paths = loader_mod.load_syncprotect(project_dir, config.base_dir)

    -- Track all installed files, directories, merged sections, and data skeleton files
    -- Declared before pcall so rollback can access them
    local all_files = {}
    local all_dirs = {}
    local merged_sections = {}
    local data_skeleton_files = {}
    local total_skipped = 0
    local total_symlink_skipped = 0

    -- Wrap copy+merge in pcall for atomic rollback on failure
    local load_ok, load_err = pcall(function()
      local skipped, symlink_skipped
      -- Shared opts for every category copy this load performs: project_dir/extension_name are
      -- needed by the `data`/`manifest` special-cased categories respectively; agents_subdir
      -- resolves the one category (agents) whose target directory name varies by config.
      local copy_opts = {
        project_dir = project_dir,
        extension_name = extension_name,
        agents_subdir = config.agents_subdir,
      }

      local files, dirs
      -- Copy agents (use configured agents_subdir for target path)
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("agents", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy commands
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("commands", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy rules
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("rules", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy skills
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("skills", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy context
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("context", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy scripts
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("scripts", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy hooks (flat .sh files with execute permissions)
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("hooks", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy docs
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("docs", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy templates
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("templates", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy systemd unit files
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("systemd", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy root files (settings.json, .gitignore, etc.)
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("root_files", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy manifest.json to extensions/{name}/
      files, dirs, skipped, symlink_skipped = loader_mod.copy_category("manifest", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_files, files)
      vim.list_extend(all_dirs, dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped

      -- Copy data directories (merge-copy semantics - preserves existing files)
      -- Data skeleton files are tracked separately for safe unload
      local data_files, data_dirs
      data_files, data_dirs, skipped, symlink_skipped = loader_mod.copy_category("data", ext_manifest, source_dir, target_dir, protected_paths, copy_opts)
      vim.list_extend(all_dirs, data_dirs)
      total_skipped = total_skipped + skipped
      total_symlink_skipped = total_symlink_skipped + symlink_skipped
      -- Track data files separately - they go into data_skeleton_files, not all_files
      -- This allows unload to only remove skeleton files, not user-created data
      for _, f in ipairs(data_files) do
        table.insert(data_skeleton_files, f)
      end

      -- Pre-load cleanup: remove stale index entries before appending fresh ones.
      -- Excludes the current extension from valid prefixes so its stale entries
      -- are removed. Fresh entries are then added by process_merge_targets()
      -- and properly tracked for future unload.
      local index_path = target_dir .. "/context/index.json"
      if vim.fn.filereadable(index_path) == 1 then
        local updated_state = state_mod.read(project_dir, config)
        local loaded_names = state_mod.list_loaded(updated_state)
        -- Do NOT include the current extension -- its stale entries must be
        -- removed so fresh entries from process_merge_targets() are added
        -- and tracked (append_index_entries deduplicates, so stale entries
        -- would prevent tracking and survive unload)
        local valid_prefixes = {}
        for _, ext_name in ipairs(loaded_names) do
          local ext = manifest_mod.get_extension(ext_name, config)
          if ext and ext.manifest and ext.manifest.provides and ext.manifest.provides.context then
            for _, prefix in ipairs(ext.manifest.provides.context) do
              table.insert(valid_prefixes, prefix)
            end
          end
        end
        -- Always run cleanup, even with empty valid_prefixes.
        -- When no extensions are loaded yet, all project/ entries are stale.
        local context_dir = target_dir .. "/context"
        merge_mod.remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)
      end

      -- Process merge targets
      merged_sections = process_merge_targets(ext_manifest, source_dir, project_dir, config)
    end)

    -- Rollback on failure
    if not load_ok then
      -- Filter out any .syncprotect-protected path before rollback removal,
      -- symmetric with copy_file's own protection check (defense in depth:
      -- copy_file already excludes protected paths from all_files/all_dirs
      -- under normal operation, so this filter is a belt-and-suspenders
      -- guard rather than the primary protection mechanism here).
      local rollback_files = {}
      for _, path in ipairs(all_files) do
        local key = path:sub(#target_dir + 2)
        if not protected_paths[key] then
          table.insert(rollback_files, path)
        end
      end
      local rollback_dirs = {}
      for _, path in ipairs(all_dirs) do
        local key = path:sub(#target_dir + 2)
        if not protected_paths[key] then
          table.insert(rollback_dirs, path)
        end
      end
      loader_mod.remove_installed_files(rollback_files, rollback_dirs, { project_dir = project_dir })
      reverse_merge_targets(ext_manifest, merged_sections, project_dir, config)
      return false, "Extension load failed: " .. tostring(load_err)
    end

    -- Re-read state from disk to pick up changes from dependency loads
    -- (dependency loads write their own state entries; using stale in-memory
    -- state here would overwrite those entries)
    state = state_mod.read(project_dir, config)

    -- Update state (convert to relative paths for portability)
    local rel_files = paths_to_relative(all_files, project_dir)
    local rel_dirs = paths_to_relative(all_dirs, project_dir)
    local rel_data_files = paths_to_relative(data_skeleton_files, project_dir)
    state = state_mod.mark_loaded(state, extension_name, ext_manifest, rel_files, rel_dirs, merged_sections, rel_data_files)
    state_mod.write(project_dir, state, config)

    -- Regenerate CLAUDE.md (computed artifact) after state is updated so the
    -- newly loaded extension's content is included. Errors are non-fatal.
    local gen_ok, gen_err = merge_mod.generate_claudemd(project_dir, config)
    if not gen_ok then
      vim.schedule(function()
        vim.notify("Warning: CLAUDE.md regeneration failed: " .. tostring(gen_err), vim.log.levels.WARN)
      end)
    end

    -- Regenerate opencode.json (computed artifact) after state is updated.
    -- This rebuilds the file from base template + all loaded extension fragments.
    local json_ok, json_err = merge_mod.generate_opencode_json(project_dir, config)
    if not json_ok then
      vim.schedule(function()
        vim.notify("Warning: opencode.json regeneration failed: " .. tostring(json_err), vim.log.levels.WARN)
      end)
    end

    local load_skip_parts = {}
    if total_skipped > 0 then
      table.insert(load_skip_parts, string.format("%d skipped (.syncprotect)", total_skipped))
    end
    if total_symlink_skipped > 0 then
      table.insert(load_skip_parts, string.format("%d skipped (symlinked, preserved)", total_symlink_skipped))
    end
    local load_skip_note = #load_skip_parts > 0 and (", " .. table.concat(load_skip_parts, ", ")) or ""
    helpers.notify(
      string.format("Loaded extension '%s' (%d files%s)", extension_name, #all_files, load_skip_note),
      "INFO"
    )

    -- Run post-load verification
    local verification = verify_mod.verify_extension(extension_name, source_dir, target_dir, config, protected_paths)
    if verification.status ~= "passed" then
      verify_mod.notify_results(verification)
    end

    return true, nil
  end

  --- Unload an extension from the current project
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil}
  --- @return boolean success True if unload succeeded
  --- @return string|nil error Error message if unload failed
  function manager.unload(extension_name, opts)
    opts = opts or {}
    local confirm = opts.confirm ~= false
    local project_dir = opts.project_dir or vim.fn.getcwd()

    -- Check if loaded
    local state = state_mod.read(project_dir, config)
    if not state_mod.is_loaded(state, extension_name) then
      return false, "Extension not loaded: " .. extension_name
    end

    -- Get installed files, data skeleton files, and merged sections
    local installed_files = state_mod.get_installed_files(state, extension_name)
    local installed_dirs = state_mod.get_installed_dirs(state, extension_name)
    local merged_sections = state_mod.get_merged_sections(state, extension_name)
    local data_skeleton_files = state_mod.get_data_skeleton_files(state, extension_name)

    -- Get extension manifest for reverse merge
    local extension = manifest_mod.get_extension(extension_name, config)

    -- Check if any loaded extensions depend on this one
    local dependents = {}
    local loaded_names = state_mod.list_loaded(state)
    for _, loaded_name in ipairs(loaded_names) do
      if loaded_name ~= extension_name then
        local loaded_ext = manifest_mod.get_extension(loaded_name, config)
        if loaded_ext and loaded_ext.manifest and loaded_ext.manifest.dependencies then
          for _, dep in ipairs(loaded_ext.manifest.dependencies) do
            if dep == extension_name then
              table.insert(dependents, loaded_name)
            end
          end
        end
      end
    end

    -- Hard block: prevent unloading core (or any extension) when dependents are loaded.
    -- This is a hard error, not just a warning, to prevent orphaned dependent extensions.
    if #dependents > 0 then
      local dep_list = table.concat(dependents, ", ")
      local msg = string.format(
        "Cannot unload extension '%s': required by loaded extension(s): %s\n"
          .. "Unload dependent extension(s) first.",
        extension_name,
        dep_list
      )
      helpers.notify(msg, "ERROR")
      return false, msg
    end

    -- Confirmation dialog
    if confirm then
      local total_files = #installed_files + #data_skeleton_files
      local data_note = ""
      if #data_skeleton_files > 0 then
        data_note = "\n(User-created data files will be preserved)"
      end

      local message = string.format(
        "Unload extension '%s'?\n\nThis will remove %d files.%s",
        extension_name,
        total_files,
        data_note
      )

      local choice = vim.fn.confirm(message, "&Unload\n&Cancel", 2)
      if choice ~= 1 then
        helpers.notify("Extension unload cancelled", "INFO")
        return false, "Cancelled by user"
      end
    end

    -- Reverse merge operations
    if extension and extension.manifest then
      reverse_merge_targets(extension.manifest, merged_sections, project_dir, config)
    end

    -- Load .syncprotect so removal honors the same protection as copy
    -- (manager.load does this at load time; unload never did until now).
    local protected_paths = loader_mod.load_syncprotect(project_dir, config.base_dir)
    local protected_skip_count = 0
    local install_once_skip_count = 0

    -- Convert relative paths back to absolute for file removal, filtering
    -- out any path protected by .syncprotect. installed_files/installed_dirs
    -- are project-root-relative (e.g. ".claude/agents/foo.md"), while
    -- .syncprotect keys are base-dir-relative (e.g. "agents/foo.md"), so the
    -- base_dir prefix is stripped before checking protected_paths.
    local abs_files = {}
    for _, rel_path in ipairs(installed_files) do
      local syncprotect_key = rel_path:sub(#config.base_dir + 2)
      if protected_paths[syncprotect_key] then
        protected_skip_count = protected_skip_count + 1
      elseif loader_mod.INSTALL_ONCE_ROOT_FILES[syncprotect_key] then
        -- Never remove settings.json/settings.local.json on unload: without
        -- this, a subsequent load (e.g. manager.reload's unload-then-load)
        -- would find the target absent and copy fresh regardless of
        -- copy_root_files' install-once guard, silently clobbering any
        -- in-place edits on every unload+load cycle.
        install_once_skip_count = install_once_skip_count + 1
      else
        table.insert(abs_files, project_dir .. "/" .. rel_path)
      end
    end
    -- Also add data skeleton files (these are safe to remove - they're extension-provided)
    for _, rel_path in ipairs(data_skeleton_files) do
      local syncprotect_key = rel_path:sub(#config.base_dir + 2)
      if protected_paths[syncprotect_key] then
        protected_skip_count = protected_skip_count + 1
      else
        table.insert(abs_files, project_dir .. "/" .. rel_path)
      end
    end
    local abs_dirs = {}
    for _, rel_path in ipairs(installed_dirs) do
      local syncprotect_key = rel_path:sub(#config.base_dir + 2)
      if protected_paths[syncprotect_key] then
        protected_skip_count = protected_skip_count + 1
      else
        table.insert(abs_dirs, project_dir .. "/" .. rel_path)
      end
    end

    -- Remove files (includes both regular files and data skeleton files)
    -- User-created files in data directories are NOT in the abs_files list,
    -- so they will be preserved. The remove_installed_files function only
    -- removes empty directories, so user data directories will also be preserved.
    -- project_dir bounds the symlink-ancestor walk (see loader.lua).
    local removed_count, symlink_skip_count = loader_mod.remove_installed_files(
      abs_files, abs_dirs, { project_dir = project_dir }
    )

    -- Update state
    state = state_mod.mark_unloaded(state, extension_name)
    state_mod.write(project_dir, state, config)

    -- Regenerate CLAUDE.md (computed artifact) after state is updated so the
    -- unloaded extension's content is excluded from the output. Errors are non-fatal.
    local gen_ok, gen_err = merge_mod.generate_claudemd(project_dir, config)
    if not gen_ok then
      vim.schedule(function()
        vim.notify("Warning: CLAUDE.md regeneration failed: " .. tostring(gen_err), vim.log.levels.WARN)
      end)
    end

    -- Regenerate opencode.json (computed artifact) after state is updated.
    -- This rebuilds the file without the unloaded extension's agents.
    local json_ok, json_err = merge_mod.generate_opencode_json(project_dir, config)
    if not json_ok then
      vim.schedule(function()
        vim.notify("Warning: opencode.json regeneration failed: " .. tostring(json_err), vim.log.levels.WARN)
      end)
    end

    local skip_notes = {}
    if protected_skip_count > 0 then
      table.insert(skip_notes, string.format("%d protected (.syncprotect)", protected_skip_count))
    end
    if install_once_skip_count > 0 then
      table.insert(skip_notes, string.format(
        "%d preserved (settings install-once)", install_once_skip_count
      ))
    end
    if symlink_skip_count and symlink_skip_count > 0 then
      table.insert(skip_notes, string.format(
        "%d symlinked (left in place; use uninstall-extension.sh to remove)",
        symlink_skip_count
      ))
    end
    local skip_note = #skip_notes > 0 and (" (" .. table.concat(skip_notes, ", ") .. " skipped)") or ""

    helpers.notify(
      string.format("Unloaded extension '%s' (%d files removed%s)", extension_name, removed_count, skip_note),
      "INFO"
    )

    return true, nil
  end

  --- Reload an extension (unload then load)
  --- @param extension_name string Extension name
  --- @param opts table|nil Options {confirm = true, project_dir = nil}
  --- @return boolean success True if reload succeeded
  --- @return string|nil error Error message if reload failed
  function manager.reload(extension_name, opts)
    opts = opts or {}
    local project_dir = opts.project_dir or vim.fn.getcwd()

    -- Check if loaded
    local state = state_mod.read(project_dir, config)
    if not state_mod.is_loaded(state, extension_name) then
      return false, "Extension not loaded: " .. extension_name
    end

    -- Unload without confirmation
    local success, err = manager.unload(extension_name, { confirm = false, project_dir = project_dir })
    if not success then
      return false, "Failed to unload: " .. (err or "unknown error")
    end

    -- Load without confirmation
    success, err = manager.load(extension_name, { confirm = false, project_dir = project_dir })
    if not success then
      return false, "Failed to load: " .. (err or "unknown error")
    end

    helpers.notify(string.format("Reloaded extension '%s'", extension_name), "INFO")
    return true, nil
  end

  --- Non-destructive force-resync of every currently active extension, in dependency order.
  ---
  --- This is the single `manager`-level bulk-resync entry point shared by the picker's
  --- "Reload All" and (via `deploy-headless.sh`'s default invocation) headless callers. It
  --- promotes the topological ordering (Kahn's algorithm) formerly duplicated in the picker's
  --- "Reload All" handler (`picker/init.lua`) rather than writing a third ordering
  --- implementation -- the same shape `manager.regenerate`'s load loop also needs, and which it
  --- gets for free by building on this function (see `manager.regenerate`).
  ---
  --- Never unloads: each extension is re-loaded in place via `manager.load(..., {force = true})`,
  --- so there is no destructive intermediate "everything unloaded" state -- unlike the former
  --- picker-local unload-all/load-all reimplementation this function replaces.
  --- @param opts table|nil Options: { project_dir = string|nil }
  --- @return table result { succeeded = {name, ...}, failed = {{name=, error=}, ...}, total = N }
  function manager.resync_all(opts)
    opts = opts or {}
    local project_dir = opts.project_dir or vim.fn.getcwd()

    local loaded = manager.list_loaded(project_dir)
    local result = { succeeded = {}, failed = {}, total = #loaded }

    if #loaded == 0 then
      return result
    end

    -- Build a dependency graph restricted to the currently-loaded set (a dependency outside it
    -- is already satisfied and does not participate in the ordering).
    local loaded_set = {}
    for _, name in ipairs(loaded) do
      loaded_set[name] = true
    end
    local deps_of = {}
    for _, name in ipairs(loaded) do
      local extension = manifest_mod.get_extension(name, config)
      local deps = {}
      if extension and extension.manifest and extension.manifest.dependencies then
        for _, dep in ipairs(extension.manifest.dependencies) do
          if loaded_set[dep] then
            table.insert(deps, dep)
          end
        end
      end
      deps_of[name] = deps
    end

    -- Topological sort (Kahn's algorithm): resync_order has roots first (e.g. core, which
    -- nothing else depends on being loaded before), leaves last.
    local in_degree = {}
    for _, name in ipairs(loaded) do
      in_degree[name] = 0
    end
    for _, name in ipairs(loaded) do
      for _ in ipairs(deps_of[name]) do
        in_degree[name] = in_degree[name] + 1
      end
    end
    local resync_order = {}
    local queue = {}
    for _, name in ipairs(loaded) do
      if in_degree[name] == 0 then
        table.insert(queue, name)
      end
    end
    while #queue > 0 do
      local name = table.remove(queue, 1)
      table.insert(resync_order, name)
      for _, other in ipairs(loaded) do
        for _, dep in ipairs(deps_of[other]) do
          if dep == name then
            in_degree[other] = in_degree[other] - 1
            if in_degree[other] == 0 then
              table.insert(queue, other)
            end
          end
        end
      end
    end

    for _, name in ipairs(resync_order) do
      local ok, err = manager.load(name, { confirm = false, project_dir = project_dir, force = true })
      if ok then
        table.insert(result.succeeded, name)
      else
        table.insert(result.failed, { name = name, error = err })
      end
    end

    return result
  end

  --- Get extension status
  --- @param extension_name string Extension name
  --- @param project_dir string|nil Project directory
  --- @return string status "active", "inactive", or "update-available"
  function manager.get_status(extension_name, project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)

    if not state_mod.is_loaded(state, extension_name) then
      return "inactive"
    end

    -- Check for updates
    local extension = manifest_mod.get_extension(extension_name, config)
    if extension then
      if state_mod.needs_update(state, extension_name, extension.manifest.version) then
        return "update-available"
      end
    end

    return "active"
  end

  --- List all available extensions
  --- @return table extensions Array of {name, version, description, status}
  function manager.list_available()
    local project_dir = vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    local extensions = manifest_mod.list_extensions(config)

    local result = {}
    for _, ext in ipairs(extensions) do
      local status = "inactive"
      if state_mod.is_loaded(state, ext.name) then
        if state_mod.needs_update(state, ext.name, ext.manifest.version) then
          status = "update-available"
        else
          status = "active"
        end
      end

      table.insert(result, {
        name = ext.name,
        version = ext.manifest.version,
        description = ext.manifest.description,
        language = ext.manifest.language,
        status = status,
        path = ext.path,
      })
    end

    return result
  end

  --- List extensions loaded in current project
  --- @param project_dir string|nil Project directory
  --- @return table extensions Array of extension names
  function manager.list_loaded(project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    return state_mod.list_loaded(state)
  end

  --- Get extension details
  --- @param extension_name string Extension name
  --- @return table|nil details Extension details or nil if not found
  function manager.get_details(extension_name)
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return nil
    end

    local project_dir = vim.fn.getcwd()
    local state = state_mod.read(project_dir, config)
    local ext_info = state_mod.get_extension_info(state, extension_name)

    return {
      name = extension.name,
      version = extension.manifest.version,
      description = extension.manifest.description,
      language = extension.manifest.language,
      dependencies = extension.manifest.dependencies or {},
      provides = extension.manifest.provides,
      merge_targets = extension.manifest.merge_targets,
      mcp_servers = extension.manifest.mcp_servers,
      status = manager.get_status(extension_name, project_dir),
      loaded_at = ext_info and ext_info.loaded_at or nil,
      installed_files = ext_info and ext_info.installed_files or {},
    }
  end

  --- Verify a loaded extension
  --- @param extension_name string Extension name
  --- @param project_dir string|nil Project directory
  --- @return table verification Verification report
  function manager.verify(extension_name, project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local target_dir = project_dir .. "/" .. config.base_dir

    -- Get extension source directory
    local extension = manifest_mod.get_extension(extension_name, config)
    if not extension then
      return {
        extension = extension_name,
        status = "failed",
        errors = { "Extension not found: " .. extension_name },
      }
    end

    local protected_paths = loader_mod.load_syncprotect(project_dir, config.base_dir)
    return verify_mod.verify_extension(extension_name, extension.path, target_dir, config, protected_paths)
  end

  --- Verify all loaded extensions
  --- @param project_dir string|nil Project directory
  --- @return table results Array of verification reports
  function manager.verify_all(project_dir)
    project_dir = project_dir or vim.fn.getcwd()
    local loaded = manager.list_loaded(project_dir)
    local results = {}

    for _, ext_name in ipairs(loaded) do
      local verification = manager.verify(ext_name, project_dir)
      table.insert(results, verification)
    end

    return results
  end

  --- Regenerate `base_dir` (`.claude/`/`.opencode/`) from the surviving project-root
  --- extension manifest, without re-picking any extensions.
  ---
  --- This is the crux of "one-keystroke regenerable": the manifest written by
  --- `state_mod.write` lives at the project root (`config.root_state_file`), outside
  --- `base_dir`, so it survives a `rm -rf base_dir` wipe. Calling this after such a
  --- wipe re-reads that surviving manifest's `status == "active"` extensions and
  --- reloads each one via `manager.load`, reconstructing an identical `base_dir`.
  ---
  --- Implementation note: the surviving manifest's per-extension tracking data
  --- (`installed_files`/`installed_dirs`/`merged_sections`) all point into `base_dir`,
  --- which is gone after a wipe, so it is stale -- and `manager.load` itself refuses
  --- to act on an extension its state already marks `status == "active"` (see
  --- `manager.load`'s "Check if already loaded" guard). To make regeneration work
  --- despite that guard, the in-memory/on-disk state is first reset to empty, then
  --- each formerly-active extension is (re)loaded via `manager.load`, whose own
  --- recursive dependency resolution (see `manager.load`'s "Resolve dependencies"
  --- section) transparently handles any ordering requirements -- a dependency pulled
  --- in by an earlier iteration is detected via a fresh state read and counted as
  --- loaded rather than re-invoked (which would otherwise surface a harmless
  --- "already loaded" as a spurious failure).
  ---
  --- No-op-safe: a missing or empty manifest yields `{ loaded = {}, failed = {} }`
  --- with no error and no state reset. Each individual extension load is guarded by
  --- `manager.load`'s own error return, so one failure does not abort the rest.
  --- @param opts table|nil Options: { project_dir = string|nil }
  --- @return table result { loaded = {name, ...}, failed = {{name=, error=}, ...},
  ---   settings_restored = {filename, ...} } -- settings_restored lists which of
  ---   settings.json/settings.local.json were restored from a staged backup, if any
  function manager.regenerate(opts)
    opts = opts or {}
    local project_dir = opts.project_dir or vim.fn.getcwd()

    local result = { loaded = {}, failed = {} }

    local ok, surviving_state = pcall(state_mod.read, project_dir, config)
    if not ok then
      table.insert(result.failed, { name = "<manifest>", error = tostring(surviving_state) })
      return result
    end

    local active_names = state_mod.list_loaded(surviving_state)
    if #active_names == 0 then
      return result
    end

    local reset_ok = state_mod.write(project_dir, { version = "1.0.0", extensions = {} }, config)
    if not reset_ok then
      table.insert(result.failed, {
        name = "<manifest>",
        error = "Failed to reset extension state before regenerate",
      })
      return result
    end

    for _, extension_name in ipairs(active_names) do
      -- A prior iteration may already have (re)loaded this extension as a
      -- dependency; re-check current state instead of calling manager.load
      -- again, which would otherwise report a harmless "already loaded" as a
      -- failure.
      local current_state = state_mod.read(project_dir, config)
      if state_mod.is_loaded(current_state, extension_name) then
        table.insert(result.loaded, extension_name)
      else
        local load_ok, load_err = manager.load(extension_name, {
          confirm = false,
          project_dir = project_dir,
        })
        if load_ok then
          table.insert(result.loaded, extension_name)
        else
          table.insert(result.failed, { name = extension_name, error = load_err })
        end
      end
    end

    -- Restore settings.json/settings.local.json from a project-root backup
    -- staged before the wipe, if one exists. This is what makes the wipe
    -- sequence (backup -> rm -rf base_dir -> regenerate -> restore) truly
    -- lossless for the two files that install-once semantics (Phase 4) alone
    -- cannot protect across a full base_dir deletion. No-op-safe when no
    -- backup was staged (e.g. regenerate called outside a wipe sequence).
    local restore_ok, restored = settings_backup.restore(project_dir, config)
    result.settings_restored = restored
    if not restore_ok then
      table.insert(result.failed, {
        name = "<settings-restore>",
        error = "Failed to restore settings backup after regenerate",
      })
    end

    return result
  end

  return manager
end

return M
