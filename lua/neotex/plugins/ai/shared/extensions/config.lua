-- neotex.plugins.ai.shared.extensions.config
-- Configuration schema for extension management system
-- Parameterized to support both claude and opencode

local M = {}

--- Create configuration for an extension system
--- @param opts table Configuration options
--- @return table config Extension system configuration
function M.create(opts)
  vim.validate({
    base_dir = { opts.base_dir, "string" },
    config_file = { opts.config_file, "string" },
    section_prefix = { opts.section_prefix, "string" },
    state_file = { opts.state_file, "string" },
    global_extensions_dir = { opts.global_extensions_dir, "string" },
    merge_target_key = { opts.merge_target_key, "string", true },
    agents_subdir = { opts.agents_subdir, "string", true },
  })

  return {
    -- Base directory name (.claude or .opencode)
    base_dir = opts.base_dir,

    -- Configuration file name (CLAUDE.md or OPENCODE.md)
    config_file = opts.config_file,

    -- Section prefix for merge markers (extension_claude_ or extension_oc_)
    section_prefix = opts.section_prefix,

    -- State file name (extensions.json)
    state_file = opts.state_file,

    -- Global extensions directory (absolute path)
    global_extensions_dir = opts.global_extensions_dir,

    -- Merge target key in manifest (claudemd or opencode_md)
    merge_target_key = opts.merge_target_key or "claudemd",

    -- Agents subdirectory path (agents for Claude, agent/subagents for OpenCode)
    agents_subdir = opts.agents_subdir or "agents",
  }
end

--- Claude-specific configuration preset
--- @param global_dir string|nil Global directory (defaults to ~/.config/nvim)
--- @return table config Claude extension configuration
function M.claude(global_dir)
  global_dir = global_dir or vim.fn.expand("~/.config/nvim")
  return M.create({
    base_dir = ".claude",
    config_file = "CLAUDE.md",
    section_prefix = "extension_",
    state_file = "extensions.json",
    global_extensions_dir = global_dir .. "/agent-system/extensions",
    merge_target_key = "claudemd",
    agents_subdir = "agents",
  })
end

--- OpenCode-specific configuration preset
--- @param global_dir string|nil Global directory (defaults to ~/.config/nvim)
--- @return table config OpenCode extension configuration
function M.opencode(global_dir)
  global_dir = global_dir or vim.fn.expand("~/.config/nvim")
  return M.create({
    base_dir = ".opencode",
    config_file = "OPENCODE.md",
    section_prefix = "extension_oc_",
    state_file = "extensions.json",
    global_extensions_dir = global_dir .. "/.opencode/extensions",
    merge_target_key = "opencode_md",
    agents_subdir = "agent/subagents",
  })
end

return M
