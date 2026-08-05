-- neotex.plugins.ai.claude.commands.picker.operations.sync
-- Per-artifact and manifest-scan sync helpers backing the picker's Ctrl-u
-- ("update artifact from global") flow and the extension loader's declared-
-- vs-deployed scan utility. Extension artifacts are filtered via
-- aggregate_extension_artifacts() to ensure only core artifacts are treated
-- as updatable, regardless of what extensions are loaded globally.
--
-- The former bulk "Load Core Agent System" glob+allow-list sync engine that
-- once lived in this module has been retired: bulk load/resync/regenerate is
-- now handled entirely by the manifest-driven extension loader
-- (neotex.plugins.ai.shared.extensions -- see manager.load, manager.resync_all,
-- manager.wipe), reachable via the picker's [Regenerate] entry and
-- deploy-headless.sh. M.scan_all_artifacts below is retained as a tested
-- utility (see operations/sync_spec.lua) even though its own bulk-sync caller
-- is gone.

local M = {}

-- Dependencies
local scan = require("neotex.plugins.ai.claude.commands.picker.utils.scan")
local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")
local manifest = require("neotex.plugins.ai.shared.extensions.manifest")
local ext_config = require("neotex.plugins.ai.shared.extensions.config")

-- Files to exclude from context sync (repository-specific and generated files that should not be copied)
-- Note: update-project.md is intentionally NOT excluded as it is a guide/template
-- index.json and index.json.backup are generated per-repo by the extension loader
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
  "index.json",
  "index.json.backup",
}

--- Load .sync-exclude file from source (global) directory
--- Parses path exclusions and audit-pattern directives.
--- @param global_dir string Global directory path (source repo root)
--- @return table exclude_set Set of paths to exclude {[path] = true}
--- @return table audit_patterns Array of Lua pattern strings for content auditing
local function load_sync_exclude(global_dir)
  local exclude_set = {}
  local audit_patterns = {}

  local filepath = global_dir .. "/.sync-exclude"
  local file = io.open(filepath, "r")
  if not file then
    return exclude_set, audit_patterns
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
      goto continue
    end

    -- Check for audit-pattern directive
    local pattern = line:match("^# audit%-pattern:%s*(.+)$")
    if pattern then
      table.insert(audit_patterns, pattern:match("^%s*(.-)%s*$"))
      goto continue
    end

    -- Skip regular comments
    if line:sub(1, 1) == "#" then
      goto continue
    end

    -- Non-comment, non-empty line is a path exclusion
    exclude_set[line] = true

    ::continue::
  end
  file:close()

  return exclude_set, audit_patterns
end

--- Convert set-based blocklist to array for exclude_patterns parameter
--- @param set table Set table {[key] = true}
--- @return table array Array of keys
local function set_to_array(set)
  local arr = {}
  for k, _ in pairs(set) do
    table.insert(arr, k)
  end
  return arr
end

--- Load .syncprotect file from target repository
--- Reads from project root first ({project_dir}/.syncprotect), falling back to
--- the legacy location ({project_dir}/{base_dir}/.syncprotect) with a deprecation warning.
--- Protected files will not be overwritten during sync operations.
--- @param project_dir string Project directory path
--- @param base_dir string|nil Base directory name for legacy fallback (".claude" or ".opencode")
--- @return table protected_paths Set of relative paths {[path] = true}
local function load_syncprotect(project_dir, base_dir)
  local protected = {}

  -- Try project root first (new canonical location)
  local filepath = project_dir .. "/.syncprotect"
  local file = io.open(filepath, "r")

  -- Fall back to legacy location inside base_dir
  if not file and base_dir then
    local legacy_path = project_dir .. "/" .. base_dir .. "/.syncprotect"
    file = io.open(legacy_path, "r")
    if file then
      helpers.notify(
        ".syncprotect found at legacy location (" .. base_dir .. "/.syncprotect). "
          .. "Please move it to the project root (.syncprotect).",
        "WARN"
      )
    end
  end

  if not file then
    return protected
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    -- Skip empty lines and comments
    if line ~= "" and line:sub(1, 1) ~= "#" then
      protected[line] = true
    end
  end
  file:close()

  return protected
end

--- Get extension config for the given base_dir
--- @param base_dir string Base directory (".claude" or ".opencode")
--- @param global_dir string Global directory path
--- @return table ext_cfg Extension system configuration
local function get_extension_config(base_dir, global_dir)
  if base_dir == ".opencode" then
    return ext_config.opencode(global_dir)
  end
  return ext_config.claude(global_dir)
end

--- Scan all artifact types from global directory
--- Filters extension artifacts via manifest-driven allow-list (preferred) or blocklist (fallback)
--- to ensure only core artifacts are synced.
--- @param global_dir string Global directory path
--- @param project_dir string Project directory path
--- @param config table|nil Picker config with base_dir field (defaults to .claude config)
--- @return table Map of artifact type -> array of files
function M.scan_all_artifacts(global_dir, project_dir, config)
  local base_dir = (config and config.base_dir) or ".claude"
  local artifacts = {}

  -- Self-load: project_dir and global_dir are the same repo (e.g. running the
  -- sync picker from inside the global source repo itself). Core-sourced
  -- categories still resolve to distinct read/write paths in this case (source
  -- is agent-system/extensions/core/, destination is base_dir), so self-load is
  -- safe for them. lib/tests are the exception -- see the base_dir == ".claude"
  -- branch below.
  local is_self_load = project_dir == global_dir

  -- Load source-side exclusions from .sync-exclude (if present)
  local sync_exclude_set, audit_patterns = load_sync_exclude(global_dir)
  local sync_exclude_array = set_to_array(sync_exclude_set)

  -- Build filtering strategy: prefer allow-list from core manifest, fall back to blocklist
  local extension_cfg = get_extension_config(base_dir, global_dir)
  local core_provides = manifest.get_core_provides(extension_cfg)
  local allow_list = core_provides and manifest.build_allow_list(core_provides) or nil
  local blocklist = manifest.aggregate_extension_artifacts(extension_cfg)

  -- For .claude base_dir, core artifact categories (agents, commands, rules, skills, etc.)
  -- are now physically located under the global source store (agent-system/extensions/core/,
  -- relocated out of any deployed .claude/ tree). We read from
  -- {global_dir}/agent-system/extensions/core/{subdir} but write to
  -- {project_dir}/.claude/{subdir} to maintain the standard project layout.
  -- Derived from extension_cfg.global_extensions_dir (the single canonical config value,
  -- config.lua's M.claude preset) rather than a duplicated literal, so this path can never
  -- drift from the canonical default.
  -- For .opencode, no core extension migration has occurred, so paths are unchanged.
  local core_source_base
  if base_dir == ".claude" then
    local global_prefix = global_dir .. "/"
    local global_extensions_dir = extension_cfg.global_extensions_dir
    local relative_extensions_dir = global_extensions_dir:sub(1, #global_prefix) == global_prefix
        and global_extensions_dir:sub(#global_prefix + 1)
      or global_extensions_dir
    core_source_base = relative_extensions_dir .. "/core"
  else
    core_source_base = nil
  end

  -- Helper to scan with base_dir and filtering threaded through.
  -- When an allow-list exists for the category, files are post-filtered to only
  -- include those in the allow-list. Otherwise, falls back to blocklist exclusion.
  -- @param subdir string Subdirectory to scan
  -- @param ext string File extension pattern
  -- @param recursive boolean|nil Recursive scanning (default true)
  -- @param extra_exclude table|nil Additional exclude patterns to merge
  -- @param filter_category string|nil Which category to filter (e.g., "agents", "skills")
  -- @param use_core_source boolean|nil Read from extensions/core/ instead of base_dir root (default: true for .claude)
  local function sync_scan(subdir, ext, recursive, extra_exclude, filter_category, use_core_source)
    local exclude = extra_exclude and vim.deepcopy(extra_exclude) or {}

    -- Merge source-side exclusions from .sync-exclude
    for _, entry in ipairs(sync_exclude_array) do
      table.insert(exclude, entry)
    end

    -- Blocklist fallback: when no allow-list exists for this category
    if not allow_list or (filter_category and not allow_list[filter_category]) then
      if filter_category and blocklist[filter_category] then
        local blocklist_entries = set_to_array(blocklist[filter_category])
        for _, entry in ipairs(blocklist_entries) do
          table.insert(exclude, entry)
        end
      end
    end

    -- Determine source base: core categories use extensions/core/ as the global source
    -- (use_core_source defaults to true when core_source_base is set, false when nil)
    local source_base
    if use_core_source == false then
      source_base = nil  -- Use standard base_dir for source
    else
      source_base = core_source_base  -- nil for .opencode (no override), path for .claude
    end

    local results = scan.scan_directory_for_sync(global_dir, project_dir, subdir, ext, recursive, exclude, base_dir, nil, source_base)

    -- Allow-list post-filter: only keep files that appear in the core provides.
    --
    -- Anchor invariant: the directory-name match below is built from `subdir` (the
    -- directory actually passed to this scan), never from `filter_category` (the
    -- logical category name). The two are equal at every call site except OpenCode
    -- agents, where `agents_subdir` resolves to "agent/subagents" while
    -- `filter_category` stays "agents" -- anchoring on `filter_category` there would
    -- build a pattern that can never match the real path, silently dropping every
    -- OpenCode agent (a new instance of the very defect this filter fixes). This
    -- single rule replaces the former `filter_category == "context"` special case:
    -- context's directory-shaped entries and skills' directory-shaped entries (the
    -- prior mismatch: `provides.skills` names directories like "skill-orchestrate"
    -- while every scanned file's basename is the literal "SKILL.md") are both
    -- handled by extracting the first path segment after `subdir`. Flat categories
    -- (agents, commands, rules, hooks, scripts) still match correctly because their
    -- first path segment IS the basename when the file sits directly under `subdir`.
    if allow_list and filter_category and allow_list[filter_category] then
      local allowed = allow_list[filter_category]
      local filtered = {}
      for _, file_info in ipairs(results) do
        local admitted = false
        local rel_path = file_info.global_path:match("/" .. vim.pesc(subdir) .. "/(.+)$")
        local top_dir = rel_path and rel_path:match("^([^/]+)")
        if top_dir and allowed[top_dir] then
          admitted = true
        elseif not top_dir and allowed[file_info.name] then
          -- Basename fallback: `subdir` did not appear in the scanned path (or
          -- matched with no trailing segment). Degrades to the pre-generalization
          -- behavior instead of silently wiping the category, so a future call
          -- site whose path shape doesn't match this pattern still gets a chance.
          admitted = true
        end
        if admitted then
          table.insert(filtered, file_info)
        end
      end

      -- Zero-result wipeout detector: a working allow-list still passes some
      -- declared files through, so a TOTAL wipeout (results existed, none survived
      -- the filter) means the lookup key almost certainly does not match the
      -- provides.<category> entries -- exactly the defect this filter fixes. This
      -- check is report-only: it never mutates `filtered`, never blocks the scan,
      -- and never changes the returned value.
      if #results > 0 and #filtered == 0 then
        helpers.notify(
          string.format(
            "Sync allow-list dropped ALL %d '%s' file(s) found under '%s' -- a working "
              .. "allow-list still passes some declared files through, so a total wipeout "
              .. "usually means the lookup key (directory name vs. basename) does not match "
              .. "the provides.%s entries in the core manifest.",
            #results, filter_category, subdir, filter_category
          ),
          "WARN"
        )
      end

      return filtered
    end

    return results
  end

  -- Core artifacts common to both systems (with blocklist filtering)
  -- These categories are sourced from extensions/core/ in the global .claude directory
  artifacts.commands = sync_scan("commands", "*.md", true, nil, "commands")

  -- Use config-provided agents_subdir (different for .claude vs .opencode)
  local agents_subdir = (config and config.agents_subdir) or "agents"
  artifacts.agents = sync_scan(agents_subdir, "*.md", true, nil, "agents")

  -- For OpenCode, also sync orchestrator.md from agent/ root (outside subagents/)
  if base_dir == ".opencode" then
    local orchestrator_files = sync_scan("agent", "orchestrator.md", false)
    for _, file in ipairs(orchestrator_files) do
      table.insert(artifacts.agents, file)
    end
  end

  -- Skills (multiple file types) with blocklist filtering
  local skills_md = sync_scan("skills", "*.md", true, nil, "skills")
  local skills_yaml = sync_scan("skills", "*.yaml", true, nil, "skills")
  artifacts.skills = {}
  for _, file in ipairs(skills_md) do
    table.insert(artifacts.skills, file)
  end
  for _, file in ipairs(skills_yaml) do
    table.insert(artifacts.skills, file)
  end

  -- Shared artifacts: scanned unconditionally for both .claude and .opencode
  -- (scan_directory_for_sync returns empty array for non-existent directories)
  artifacts.hooks = sync_scan("hooks", "*.sh", true, nil, "hooks")

  -- Templates (multiple file types: yaml, json)
  local templates_yaml = sync_scan("templates", "*.yaml")
  local templates_json = sync_scan("templates", "*.json")
  artifacts.templates = {}
  for _, file in ipairs(templates_yaml) do
    table.insert(artifacts.templates, file)
  end
  for _, file in ipairs(templates_json) do
    table.insert(artifacts.templates, file)
  end

  artifacts.docs = sync_scan("docs", "*.md")
  artifacts.scripts = sync_scan("scripts", "*.sh", true, nil, "scripts")
  artifacts.rules = sync_scan("rules", "*.md", true, nil, "rules")

  -- Context (multiple file types: md, json, yaml) - shared by both systems
  -- CONTEXT_EXCLUDE_PATTERNS filters repository-specific files (project-overview.md, etc.)
  -- Blocklist context entries use prefix matching for directory-based filtering
  local ctx_md = sync_scan("context", "*.md", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  local ctx_json = sync_scan("context", "*.json", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  local ctx_yaml = sync_scan("context", "*.yaml", true, CONTEXT_EXCLUDE_PATTERNS, "context")
  artifacts.context = {}
  for _, files in ipairs({ ctx_md, ctx_json, ctx_yaml }) do
    for _, file in ipairs(files) do
      table.insert(artifacts.context, file)
    end
  end

  -- Systemd: core extension category; read from extensions/core/
  local systemd_service = sync_scan("systemd", "*.service", true)
  local systemd_timer = sync_scan("systemd", "*.timer", true)
  artifacts.systemd = {}
  for _, file in ipairs(systemd_service) do
    table.insert(artifacts.systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(artifacts.systemd, file)
  end

  -- .claude-specific artifacts (directories that don't exist in .opencode/)
  -- lib and tests are not core extension categories; read from base_dir root
  if base_dir == ".claude" then
    -- lib/tests pass use_core_source=false above, so their source path is
    -- {global_dir}/.claude/{lib,tests} -- the exact same location sync_scan
    -- writes back to under a self-load (project_dir == global_dir). There is no
    -- durable core-store source for these two categories, so a self-load would
    -- only ever copy a file onto itself. Skip them on self-load rather than
    -- perform that degenerate copy, and record the skip so callers (the sync
    -- summary notification, the picker preview) can surface it non-silently
    -- instead of it reading as a completed "Lib: 0 | Tests: 0" regeneration.
    if is_self_load then
      artifacts._self_load_skipped = { "lib", "tests" }
    else
      artifacts.lib = sync_scan("lib", "*.sh", true, nil, nil, false)
      artifacts.tests = sync_scan("tests", "test_*.sh", true, nil, nil, false)
    end
    -- Settings: now in extensions/core/root-files/, copied by loader on extension load
    -- For .opencode, settings may still be at root
    if not core_source_base then
      artifacts.settings = sync_scan("", "settings.json", true, nil, nil, false)
    end
  end

  -- Root files vary by system
  -- For .claude: all root files (settings, .gitignore, CLAUDE.md) are now managed
  -- by the extension loader (root_files provides + generate_claudemd), not synced.
  local root_file_names
  if base_dir == ".opencode" then
    root_file_names = { "AGENTS.md", "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md", "opencode.json", "package.json" }
  else
    root_file_names = {}
  end

  artifacts.root_files = {}
  for _, filename in ipairs(root_file_names) do
    local global_path = global_dir .. "/" .. base_dir .. "/" .. filename
    -- opencode.json lives at project root, not inside base_dir
    local local_path
    if filename == "opencode.json" then
      local_path = project_dir .. "/" .. filename
    else
      local_path = project_dir .. "/" .. base_dir .. "/" .. filename
    end
    if vim.fn.filereadable(global_path) == 1 then
      -- Use install-only for config and dependency files (never overwrite
      -- existing project versions — these contain project-specific hooks,
      -- permissions, MCP servers, and package dependencies that must not be
      -- clobbered by sync)
      local action
      if filename == "opencode.json" or filename == "settings.json" or filename == "package.json" then
        if vim.fn.filereadable(local_path) ~= 1 then
          action = "copy"
        elseif vim.fn.filereadable(local_path .. ".managed") == 1 then
          action = "replace"
        else
          action = "skip"
        end
      else
        action = vim.fn.filereadable(local_path) == 1 and "replace" or "copy"
      end
      if action ~= "skip" then
        table.insert(artifacts.root_files, {
          name = filename,
          global_path = global_path,
          local_path = local_path,
          action = action,
          is_subdir = false,
        })
      end
    end
  end

  -- NOTE: Root-level CLAUDE.md (outside .claude/) is intentionally NOT synced.
  -- The global CLAUDE.md contains Neovim-specific coding standards that are irrelevant
  -- to non-Neovim projects. The .claude/CLAUDE.md (synced via root_file_names above)
  -- contains the agent system configuration which IS appropriate for all projects.

  -- Store audit patterns for post-sync content audit (Phase 3)
  artifacts._audit_patterns = audit_patterns

  return artifacts
end

--- Update local artifact from global version
--- @param artifact table Artifact data with filepath and name
--- @param artifact_type string Type of artifact (for directory determination)
--- @param silent boolean Don't show notifications
--- @param picker_config table|nil Picker configuration with base_dir field
--- @return boolean success
function M.update_artifact_from_global(artifact, artifact_type, silent, picker_config)
  if not artifact or not artifact.name then
    if not silent then
      helpers.notify("No artifact selected", "ERROR")
    end
    return false
  end

  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()
  local base_dir = (picker_config and picker_config.base_dir) or ".claude"

  -- Don't update if we're in the global directory
  if project_dir == global_dir then
    if not silent then
      helpers.notify("Cannot update artifacts in the global directory", "WARN")
    end
    return false
  end

  -- Check blocklist: block individual updates of extension-provided artifacts
  local extension_cfg = get_extension_config(base_dir, global_dir)
  local blocklist = manifest.aggregate_extension_artifacts(extension_cfg)

  -- Map singular artifact_type to plural blocklist category
  local type_to_category = {
    agent = "agents",
    skill = "skills",
    command = "commands",
    rule = "rules",
    script = "scripts",
    hook = "hooks",
    hook_event = "hooks",
  }
  local blocklist_category = type_to_category[artifact_type]
  if blocklist_category and blocklist[blocklist_category] then
    -- Check if the artifact name (with extension) is in the blocklist
    local check_name = artifact.name
    -- For types where the name doesn't include the extension, add it
    local ext_map = {
      agent = ".md", skill = ".md", command = ".md",
      rule = ".md", script = ".sh", hook = ".sh", hook_event = ".sh",
    }
    local suffix = ext_map[artifact_type] or ""
    -- Check both with and without extension suffix
    if blocklist[blocklist_category][check_name]
        or blocklist[blocklist_category][check_name .. suffix] then
      if not silent then
        helpers.notify(
          string.format(
            "Blocked: '%s' is provided by an extension and cannot be individually updated from global. "
              .. "Use the extension system to manage this artifact.",
            artifact.name
          ),
          "WARN"
        )
      end
      return false
    end
  end

  -- Also block context artifacts that match extension context directories
  if artifact_type == "context" and blocklist.context then
    for ctx_prefix, _ in pairs(blocklist.context) do
      if artifact.name:sub(1, #ctx_prefix) == ctx_prefix then
        if not silent then
          helpers.notify(
            string.format(
              "Blocked: '%s' is provided by an extension and cannot be individually updated from global.",
              artifact.name
            ),
            "WARN"
          )
        end
        return false
      end
    end
  end

  -- Check syncprotect: skip protected files with a warning
  local protected_paths = load_syncprotect(project_dir, base_dir)
  if next(protected_paths) then
    -- Build the relative path that would be checked against syncprotect
    -- For root_files: just the filename; for others: subdir/filename.ext
    local rel_check
    if artifact_type == "root_file" then
      rel_check = artifact.name
    else
      local subdir_map_check = {
        command = { dir = "commands", ext = ".md" },
        hook = { dir = "hooks", ext = ".sh" },
        hook_event = { dir = "hooks", ext = ".sh" },
        lib = { dir = "lib", ext = ".sh" },
        doc = { dir = "docs", ext = ".md" },
        template = { dir = "templates", ext = "" },
        script = { dir = "scripts", ext = ".sh" },
        test = { dir = "tests", ext = ".sh" },
        skill = { dir = "skills", ext = ".md" },
        agent = { dir = "agents", ext = ".md" },
        systemd = { dir = "systemd", ext = "" },
      }
      local tc = subdir_map_check[artifact_type]
      if tc then
        rel_check = tc.dir .. "/" .. artifact.name .. tc.ext
      end
    end
    if rel_check and protected_paths[rel_check] then
      if not silent then
        helpers.notify(
          string.format("Skipped protected file: %s (listed in .syncprotect)", rel_check),
          "WARN"
        )
      end
      return false
    end
  end

  -- Determine directory and extension based on artifact type
  local subdir_map = {
    command = { dir = "commands", ext = ".md" },
    hook = { dir = "hooks", ext = ".sh" },
    hook_event = { dir = "hooks", ext = ".sh" },
    lib = { dir = "lib", ext = ".sh" },
    doc = { dir = "docs", ext = ".md" },
    template = { dir = "templates", ext = "" },  -- Templates: name includes extension (.yaml/.json)
    script = { dir = "scripts", ext = ".sh" },
    test = { dir = "tests", ext = ".sh" },
    skill = { dir = "skills", ext = ".md" },
    agent = { dir = "agents", ext = ".md" },
    systemd = { dir = "systemd", ext = "" },  -- Systemd files have full extension in name
    root_file = { dir = "", ext = "" },  -- Root files have no subdir, name includes extension
  }

  local type_config = subdir_map[artifact_type]
  if not type_config then
    if not silent then
      helpers.notify("Unknown artifact type: " .. artifact_type, "ERROR")
    end
    return false
  end

  -- Find the global version
  local global_filepath
  if artifact_type == "root_file" then
    -- Root files: name already includes extension, no subdirectory
    global_filepath = global_dir .. "/" .. base_dir .. "/" .. artifact.name
  else
    global_filepath = global_dir .. "/" .. base_dir .. "/" .. type_config.dir .. "/" .. artifact.name .. type_config.ext
  end

  -- Check if global version exists
  if not helpers.is_file_readable(global_filepath) then
    if not silent then
      helpers.notify(string.format("Global version not found: %s", artifact.name), "ERROR")
    end
    return false
  end

  -- Create local directory if needed
  local local_dir
  local local_filepath
  if artifact_type == "root_file" then
    -- Root files go directly in base_dir/
    local_dir = project_dir .. "/" .. base_dir
    local_filepath = local_dir .. "/" .. artifact.name
  else
    local_dir = project_dir .. "/" .. base_dir .. "/" .. type_config.dir
    local_filepath = local_dir .. "/" .. vim.fn.fnamemodify(global_filepath, ":t")
  end
  helpers.ensure_directory(local_dir)
  local content = helpers.read_file(global_filepath)
  if not content then
    if not silent then
      helpers.notify("Failed to read global file", "ERROR")
    end
    return false
  end

  local write_success = helpers.write_file(local_filepath, content)
  if not write_success then
    if not silent then
      helpers.notify("Failed to write local file", "ERROR")
    end
    return false
  end

  -- Preserve permissions for shell scripts
  if type_config.ext == ".sh" then
    helpers.copy_file_permissions(global_filepath, local_filepath)
  end

  if not silent then
    helpers.notify(string.format("Updated %s from global version", artifact.name), "INFO")
  end

  return true
end

--- Public wrapper for load_syncprotect, used by previewer to display protected files.
--- @param project_dir string Project directory path
--- @param base_dir string|nil Base directory name (".claude" or ".opencode")
--- @return table protected_paths Set of relative paths {[path] = true}
function M.load_syncprotect_for_preview(project_dir, base_dir)
  return load_syncprotect(project_dir, base_dir)
end

return M
