-----------------------------------------------------------
-- Email Integration for Neovim
--
-- Provides keybindings for email workflow integration:
-- - Open aerc in toggleterm floating window
-- - Quick mail sync (mbsync + notmuch)
-- - notmuch search from within Neovim
--
-- This module works alongside the existing himalaya plugin
-- for a comprehensive email workflow.
--
-- Keybindings:
--   <leader>me - Open aerc email client (also triggers a background sync of all accounts)
--   <leader>mN - Sync all accounts (mbsync -a + notmuch new)
--   <leader>mn - Search mail with notmuch (telescope)
--
-- Note: the <leader>m* prefix is shared with the himalaya plugin (see
-- neotex/plugins/editor/which-key.lua). aerc/notmuch bindings use e/n/N to
-- avoid colliding with himalaya's f (change folder) and S (full sync).
--
-- Dependencies:
--   - aerc (terminal email client)
--   - notmuch (email indexer)
--   - mbsync (IMAP sync)
--   - toggleterm.nvim (terminal integration)
-----------------------------------------------------------

-- Sync all accounts (mbsync -a) and reindex notmuch, with progress notifications.
-- Shared by <leader>me (open aerc) and <leader>mS (explicit sync).
local function sync_all_mail(on_done)
  vim.notify("Syncing all accounts...", vim.log.levels.INFO)
  vim.fn.jobstart({ "mbsync", "-a" }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.fn.jobstart({ "notmuch", "new" }, {
          on_exit = function(_, notmuch_code)
            if notmuch_code == 0 then
              vim.notify("All accounts synced", vim.log.levels.INFO)
            else
              vim.notify("notmuch indexing failed", vim.log.levels.ERROR)
            end
            if on_done then on_done(notmuch_code == 0) end
          end,
        })
      else
        vim.notify("mbsync failed with code " .. code, vim.log.levels.ERROR)
        if on_done then on_done(false) end
      end
    end,
  })
end

return {
  -- Toggleterm for aerc integration
  {
    "akinsho/toggleterm.nvim",
    keys = {
      {
        "<leader>me",
        function()
          local Terminal = require("toggleterm.terminal").Terminal
          local function open_aerc()
            local aerc = Terminal:new({
              cmd = "aerc",
              direction = "float",
              float_opts = {
                border = "curved",
                width = function()
                  return math.floor(vim.o.columns * 0.9)
                end,
                height = function()
                  return math.floor(vim.o.lines * 0.85)
                end,
              },
              on_open = function(term)
                vim.cmd("startinsert!")
                -- Close with q in normal mode
                vim.keymap.set("n", "q", function()
                  term:close()
                end, { buffer = term.bufnr, noremap = true, silent = true })
              end,
            })
            aerc:toggle()
          end

          -- Task 34 (decouple aerc/himalaya stacks, F2): gate the aerc open on sync
          -- completion instead of firing immediately. Opening aerc before mbsync +
          -- notmuch new finish races notmuch's index against the maildir on disk,
          -- producing "could not get MessageInfo" errors. The sync itself stays
          -- asynchronous (non-blocking); only the *open* is gated on its on_done
          -- callback. Bounded fallback: on sync error, sync_all_mail already
          -- surfaces an ERROR notice -- still open aerc afterward rather than
          -- leaving the keymap hanging with no window.
          sync_all_mail(function(_)
            open_aerc()
          end)
        end,
        desc = "Open aerc email client (opens after sync completes)",
      },
      {
        "<leader>mN",
        function()
          sync_all_mail()
        end,
        desc = "Sync all accounts (mbsync -a + notmuch)",
      },
    },
  },

  -- Telescope notmuch integration (optional)
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>mn",
        function()
          -- Simple notmuch search using Telescope's grep_string as template
          local pickers = require("telescope.pickers")
          local finders = require("telescope.finders")
          local conf = require("telescope.config").values
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          local notmuch_search = function(opts)
            opts = opts or {}
            pickers
              .new(opts, {
                prompt_title = "Notmuch Search",
                finder = finders.new_async_job({
                  command_generator = function(prompt)
                    if not prompt or prompt == "" then
                      return { "notmuch", "search", "--format=text", "tag:inbox" }
                    end
                    return { "notmuch", "search", "--format=text", prompt }
                  end,
                  entry_maker = function(entry)
                    -- Parse notmuch search output
                    -- Format: thread:XXX date subject
                    local thread_id = entry:match("^thread:([%w]+)")
                    return {
                      value = entry,
                      display = entry,
                      ordinal = entry,
                      thread_id = thread_id,
                    }
                  end,
                }),
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(prompt_bufnr, map)
                  actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection and selection.thread_id then
                      -- Open aerc with the thread
                      vim.notify("Selected: " .. selection.value, vim.log.levels.INFO)
                    end
                  end)
                  return true
                end,
              })
              :find()
          end

          notmuch_search()
        end,
        desc = "Search mail with notmuch",
      },
    },
  },
}
