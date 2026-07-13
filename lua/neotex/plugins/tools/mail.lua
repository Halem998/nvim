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

-- Run `notmuch new` asynchronously and report success to cb(boolean).
local function run_notmuch_new(cb)
  vim.fn.jobstart({ "notmuch", "new" }, {
    on_exit = function(_, code)
      cb(code == 0)
    end,
  })
end

-- Reconcile the notmuch index with the maildir on disk, without running any
-- pre/post hooks (so no server sync is triggered). This is the launch gate:
-- it completes in ~0.2 s on a settled maildir and reports success to
-- cb(boolean). Files first indexed here carry only tag:new until the
-- background hook-ful pass retags them (safety-neutral; see background
-- pipeline notes).
local function reconcile_index(cb)
  vim.fn.jobstart({ "notmuch", "new", "--no-hooks" }, {
    on_exit = function(_, code)
      cb(code == 0)
    end,
  })
end

-- Sync all accounts (mbsync -a) and reindex notmuch, with progress notifications.
-- Shared by <leader>me (open aerc) and <leader>mN (explicit sync).
--
-- notmuch new runs on BOTH mbsync outcomes: an aborted mbsync -a may have fully
-- synced some mailboxes before failing, and those messages must be indexed
-- before any freshness decision reads the notmuch database. A failed mbsync
-- still reports on_done(false) -- reindexing reconciles the index with what
-- landed on disk, but it never certifies the sync itself as clean.
local function sync_all_mail(on_done)
  vim.notify("Syncing all accounts...", vim.log.levels.INFO)
  vim.fn.jobstart({ "mbsync", "-a" }, {
    on_exit = function(_, code)
      if code == 0 then
        run_notmuch_new(function(indexed)
          if indexed then
            vim.notify("All accounts synced", vim.log.levels.INFO)
          else
            vim.notify("notmuch indexing failed", vim.log.levels.ERROR)
          end
          if on_done then on_done(indexed) end
        end)
      else
        vim.notify(
          "mbsync failed with code " .. code .. " -- reindexing notmuch anyway",
          vim.log.levels.ERROR
        )
        run_notmuch_new(function(indexed)
          if indexed then
            vim.notify(
              "notmuch index refreshed (mbsync still failed -- sync is not clean)",
              vim.log.levels.WARN
            )
          else
            vim.notify("notmuch indexing failed after mbsync failure", vim.log.levels.ERROR)
          end
          if on_done then on_done(false) end
        end)
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

          -- Launch barrier (decision record:
          -- ~/Mail/.claude/context/project/email/domain/index-architecture.md).
          -- The gate marker is "foreground index reconcile completed": a
          -- hook-free `notmuch new --no-hooks` run to completion before aerc
          -- opens. That is exactly the invariant aerc needs -- a notmuch index
          -- reconciled with the maildir on disk (Xapian reader-vs-writer
          -- serialization makes mid-reindex reads unsafe, so the reconcile is
          -- foreground and completes first).
          -- The gate is explicitly DECOUPLED from server-sync health: it never
          -- consults sync exit codes and never shells out to external
          -- freshness checkers. Those signals can be permanently wedged by
          -- faults orthogonal to read-safety (e.g. a duplicate-UID collision
          -- on one channel, or a false-STALE freshness reading), and a launch
          -- gate keyed to them refuses the client forever while the index
          -- itself is perfectly readable.
          -- Server syncing happens after the open, in the background pipeline.
          reconcile_index(function(ok)
            if not ok then
              vim.notify(
                "aerc launch deferred: notmuch reindex failed (another indexer may be mid-write). "
                  .. "Retry <leader>me in a moment.",
                vim.log.levels.WARN
              )
              return
            end
            open_aerc()
          end)
        end,
        desc = "Open aerc email client (fast index reconcile, sync in background)",
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
