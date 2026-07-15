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
-- Intended sequence for a lossless wipe:
--   settings_backup.backup(project_dir, config)
--   rm -rf {project_dir}/{config.base_dir}
--   manager.regenerate({ project_dir = project_dir })
--   settings_backup.restore(project_dir, config)

local M = {}

local helpers = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")

--- Files backed up/restored by this module. Mirrors loader.lua's
--- INSTALL_ONCE_ROOT_FILES set -- these are the same two files Claude Code (or
--- OpenCode) hardcodes the read path for.
local BACKUP_FILES = { "settings.json", "settings.local.json" }

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

--- Snapshot base_dir's settings.json/settings.local.json to a project-root
--- staging directory. Safe to call when neither file exists yet (a from-scratch
--- project): returns success with an empty backed_up list, not an error.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration (base_dir, settings_backup_dir)
--- @return boolean success True unless a read/write actually failed
--- @return table backed_up Array of filenames actually backed up
function M.backup(project_dir, config)
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

  return true, backed_up
end

--- Restore settings.json/settings.local.json from the project-root staging
--- directory into base_dir, if a backup exists. No-op-safe when no staging
--- directory (or no staged files) exist: returns success with an empty
--- restored list, not an error.
--- @param project_dir string Project directory path
--- @param config table Extension system configuration (base_dir, settings_backup_dir)
--- @return boolean success True unless a read/write actually failed
--- @return table restored Array of filenames actually restored
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

  return true, restored
end

--- @return boolean exists True if a staged backup exists for this project/config
function M.has_backup(project_dir, config)
  return vim.fn.isdirectory(staging_path(project_dir, config)) == 1
end

M.staging_path = staging_path

return M
