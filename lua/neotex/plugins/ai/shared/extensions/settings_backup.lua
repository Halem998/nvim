-- neotex.plugins.ai.shared.extensions.settings_backup
-- Backup/restore wrapper for the two settings files that cannot relocate out of
-- base_dir: Claude Code hardcodes `.claude/settings.json` and
-- `.claude/settings.local.json` as read paths (OpenCode mirrors this for its own
-- base_dir), so a literal path move is infeasible. This module instead provides
-- true zero-loss across a full `base_dir` wipe: snapshot to a project-root
-- staging directory immediately before `rm -rf base_dir`, then restore
-- immediately after `manager.regenerate` (or any other rebuild) recreates
-- `base_dir` from the surviving extension manifest.
--
-- Also snapshots every `.syncprotect`-listed path alongside the two settings files, in the
-- same staging directory and lifecycle. `.syncprotect`'s own overwrite-protection semantics
-- (never overwrite a protected path during a normal copy) are unchanged by this -- this module
-- is purely additive: a `.syncprotect` entry surviving `rm -rf base_dir` requires an actual
-- snapshot/restore, since overwrite-protection alone cannot protect a path that no longer
-- exists to be protected.
--
-- Intended sequence for a lossless wipe:
--   settings_backup.backup(project_dir, config, protected_paths)
--   rm -rf {project_dir}/{config.base_dir}
--   manager.regenerate({ project_dir = project_dir })
--   settings_backup.restore(project_dir, config)  -- also clears staging on success

local M = {}

local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Files backed up/restored by this module. Mirrors loader.lua's
--- INSTALL_ONCE_ROOT_FILES set -- these are the same two files Claude Code (or
--- OpenCode) hardcodes the read path for.
local BACKUP_FILES = { "settings.json", "settings.local.json" }

--- Subdirectory of the staging directory holding snapshotted `.syncprotect`-listed paths,
--- mirrored under their own relative-path structure (so nested paths like
--- "context/repo/project-overview.md" round-trip correctly).
local PROTECTED_STAGING_SUBDIR = "protected"

--- Default staging directory name, used only if config.settings_backup_dir is
--- not set (config.claude()/config.opencode() always set it).
local DEFAULT_STAGING_DIR = ".settings-backup"

--- Resolve the project-root staging directory path for a given config.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration
--- @return string path Absolute path to the staging directory
local function staging_path(project_dir, config)
  local dirname = (config and config.settings_backup_dir) or DEFAULT_STAGING_DIR
  return project_dir .. "/" .. dirname
end

--- Recursively scan a directory for files, returning paths relative to `dir`.
--- Local to this module (mirrors loader.lua's private helper of the same shape) rather than a
--- shared dependency, to avoid a settings_backup -> loader require cycle (loader depends on
--- nothing here, but keeping this module dependency-free of loader.lua keeps the backup/restore
--- lifecycle usable independent of the copy engine).
--- @param dir string Directory path
--- @return table files Array of relative file paths
local function scan_directory_recursive(dir)
  local files = {}

  if vim.fn.isdirectory(dir) ~= 1 then
    return files
  end

  local all_files = vim.fn.glob(dir .. "/**/*", false, true)
  for _, filepath in ipairs(all_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      table.insert(files, filepath:sub(#dir + 2))
    end
  end

  local top_files = vim.fn.glob(dir .. "/*", false, true)
  for _, filepath in ipairs(top_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      local rel_path = filepath:sub(#dir + 2)
      local found = false
      for _, f in ipairs(files) do
        if f == rel_path then
          found = true
          break
        end
      end
      if not found then
        table.insert(files, rel_path)
      end
    end
  end

  return files
end

--- Snapshot base_dir's settings.json/settings.local.json, plus every `.syncprotect`-listed
--- path, to a project-root staging directory. Safe to call when nothing exists yet (a
--- from-scratch project): returns success with an empty backed_up list, not an error.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration (base_dir, settings_backup_dir)
--- @param protected_paths table|nil Set of `.syncprotect`-listed relative paths
---   {[path] = true}, base_dir-relative (as returned by loader.load_syncprotect). Optional --
---   when omitted, only the two settings files are snapshotted (the pre-existing behavior).
--- @return boolean success True unless a read/write actually failed
--- @return table backed_up Array of filenames/paths actually backed up (protected paths are
---   prefixed "protected:" to distinguish them from the two settings files in the list)
function M.backup(project_dir, config, protected_paths)
  local base_dir = project_dir .. "/" .. config.base_dir
  local staging_dir = staging_path(project_dir, config)
  local backed_up = {}

  for _, filename in ipairs(BACKUP_FILES) do
    local source_path = base_dir .. "/" .. filename
    if vim.fn.filereadable(source_path) == 1 then
      helpers.ensure_directory(staging_dir)
      local content = helpers.read_file(source_path)
      if not content then
        return false, backed_up
      end
      local ok = helpers.write_file(staging_dir .. "/" .. filename, content)
      if not ok then
        return false, backed_up
      end
      table.insert(backed_up, filename)
    end
  end

  if protected_paths then
    local protected_staging_dir = staging_dir .. "/" .. PROTECTED_STAGING_SUBDIR
    for rel_path, _ in pairs(protected_paths) do
      local source_path = base_dir .. "/" .. rel_path
      if vim.fn.filereadable(source_path) == 1 then
        local staged_path = protected_staging_dir .. "/" .. rel_path
        helpers.ensure_directory(vim.fn.fnamemodify(staged_path, ":h"))
        local content = helpers.read_file(source_path)
        if not content then
          return false, backed_up
        end
        local ok = helpers.write_file(staged_path, content)
        if not ok then
          return false, backed_up
        end
        table.insert(backed_up, "protected:" .. rel_path)
      end
    end
  end

  return true, backed_up
end

--- Restore settings.json/settings.local.json and every snapshotted `.syncprotect`-listed path
--- from the project-root staging directory into base_dir, if a backup exists. No-op-safe when
--- no staging directory (or no staged files) exist: returns success with an empty restored
--- list, not an error. Clears the staging directory on success (see `M.clear_staging`), so a
--- second restore immediately after a successful one is a no-op rather than re-applying stale
--- content on a later regenerate.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration (base_dir, settings_backup_dir)
--- @return boolean success True unless a read/write actually failed
--- @return table restored Array of filenames/paths actually restored (protected paths prefixed
---   "protected:", matching M.backup's `backed_up` labeling)
function M.restore(project_dir, config)
  local base_dir = project_dir .. "/" .. config.base_dir
  local staging_dir = staging_path(project_dir, config)
  local restored = {}

  if vim.fn.isdirectory(staging_dir) ~= 1 then
    return true, restored
  end

  for _, filename in ipairs(BACKUP_FILES) do
    local staged_path = staging_dir .. "/" .. filename
    if vim.fn.filereadable(staged_path) == 1 then
      helpers.ensure_directory(base_dir)
      local content = helpers.read_file(staged_path)
      if not content then
        return false, restored
      end
      local ok = helpers.write_file(base_dir .. "/" .. filename, content)
      if not ok then
        return false, restored
      end
      table.insert(restored, filename)
    end
  end

  local protected_staging_dir = staging_dir .. "/" .. PROTECTED_STAGING_SUBDIR
  if vim.fn.isdirectory(protected_staging_dir) == 1 then
    local staged_files = scan_directory_recursive(protected_staging_dir)
    for _, rel_path in ipairs(staged_files) do
      local staged_path = protected_staging_dir .. "/" .. rel_path
      local target_path = base_dir .. "/" .. rel_path
      local content = helpers.read_file(staged_path)
      if not content then
        return false, restored
      end
      helpers.ensure_directory(vim.fn.fnamemodify(target_path, ":h"))
      local ok = helpers.write_file(target_path, content)
      if not ok then
        return false, restored
      end
      table.insert(restored, "protected:" .. rel_path)
    end
  end

  -- Close the staging leak: a stale staging dir left in place would silently re-apply on every
  -- later regenerate. Only clear after every staged file above restored successfully -- an
  -- early `return false` never reaches this line, so a failed restore leaves staging intact for
  -- diagnosis/retry rather than losing the snapshot.
  M.clear_staging(project_dir, config)

  return true, restored
end

--- Explicitly clear the staging directory. Called automatically by `M.restore` on success;
--- exposed separately so a caller can clear staging without a matching restore (e.g. abandoning
--- a wipe sequence before it reaches the restore step).
--- @param project_dir string Project directory path
--- @param config table Extension system configuration (base_dir, settings_backup_dir)
--- @return boolean success True unless the staging directory could not be removed
function M.clear_staging(project_dir, config)
  local staging_dir = staging_path(project_dir, config)
  if vim.fn.isdirectory(staging_dir) ~= 1 then
    return true
  end
  local result = vim.fn.delete(staging_dir, "rf")
  return result == 0
end

--- @return boolean exists True if a staged backup exists for this project/config
function M.has_backup(project_dir, config)
  return vim.fn.isdirectory(staging_path(project_dir, config)) == 1
end

M.staging_path = staging_path

return M
