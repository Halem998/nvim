-- Tests for neotex.plugins.ai.shared.extensions.manifest: M.list_extensions
-- Run with: nvim --headless -c "PlenaryBustedFile %"
--
-- Isolated from live on-disk extension state (never reads agent-system/extensions/):
-- uses the vim.fn.tempname()/mkdir/after_each(delete) pattern from
-- lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua.

local manifest = require("neotex.plugins.ai.shared.extensions.manifest")

describe("shared.extensions.manifest", function()
  describe("list_extensions", function()
    local temp_dir
    local config

    before_each(function()
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      config = { global_extensions_dir = temp_dir }
    end)

    after_each(function()
      if temp_dir and vim.fn.isdirectory(temp_dir) == 1 then
        vim.fn.delete(temp_dir, "rf")
      end
    end)

    local function write_manifest(dir, name)
      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({
        string.format('{"name":"%s","version":"1.0.0","description":"test"}', name),
      }, dir .. "/manifest.json")
    end

    it("skips dot-prefixed directories and does not warn", function()
      vim.fn.mkdir(temp_dir .. "/.stray", "p")

      local notify_count = 0
      local orig_notify = vim.notify
      vim.notify = function(...)
        notify_count = notify_count + 1
      end

      local extensions = manifest.list_extensions(config)
      vim.wait(10)

      vim.notify = orig_notify

      assert.equals(0, #extensions)
      assert.equals(0, notify_count)
    end)

    it("excludes a malformed non-dot extension and warns exactly once across two calls", function()
      vim.fn.mkdir(temp_dir .. "/badext", "p")
      -- No manifest.json written: M.read fails validation for badext.

      local notify_count = 0
      local orig_notify = vim.notify
      vim.notify = function(...)
        notify_count = notify_count + 1
      end

      local first = manifest.list_extensions(config)
      vim.wait(10)
      local second = manifest.list_extensions(config)
      vim.wait(10)

      vim.notify = orig_notify

      assert.equals(0, #first)
      assert.equals(0, #second)
      assert.equals(1, notify_count)
    end)

    it("still returns a valid extension alongside a dot directory (filter does not over-match)", function()
      vim.fn.mkdir(temp_dir .. "/.stray", "p")
      write_manifest(temp_dir .. "/goodext", "goodext")

      local extensions = manifest.list_extensions(config)
      vim.wait(10)

      assert.equals(1, #extensions)
      assert.equals("goodext", extensions[1].name)
    end)
  end)
end)
