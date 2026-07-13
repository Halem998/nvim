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

-- Authoritative freshness check via the email-census wrapper's freshness line
-- ("INBOX freshness ... [ok|STALE]"). Used as the fallback launch barrier when
-- the sync+reindex chain did not complete cleanly. Returns true only when the
-- freshness line is present and reads [ok] for the given account.
--
-- Signal quality is owned by the external wrapper (see ~/.dotfiles
-- modules/home/email/agent-tools/census.nix): the freshness line is a
-- count-with-tolerance proxy that cannot detect flag renames or phantom
-- drift. Improving that signal is a dotfiles-side follow-up, out of scope
-- for this module.
local function census_freshness_ok(account)
  if vim.fn.executable("email-census") ~= 1 then
    return false
  end
  local out = vim.fn.systemlist({ "email-census", "--account", account })
  if vim.v.shell_error ~= 0 then
    return false
  end
  for _, line in ipairs(out) do
    if line:find("INBOX freshness", 1, true) then
      return line:find("[ok]", 1, true) ~= nil
    end
  end
  return false
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

          -- Authoritative launch barrier (decision record:
          -- ~/Mail/.claude/context/project/email/domain/index-architecture.md).
          -- Opening aerc before mbsync + notmuch new finish races notmuch's index
          -- against the maildir on disk ("could not get MessageInfo" errors), and
          -- Xapian reader-vs-writer serialization makes mid-reindex reads unsafe.
          -- The gate therefore requires an authoritative freshness signal, not
          -- just async ordering:
          --   1. the sync+reindex chain completing cleanly (exit 0 on both
          --      mbsync -a and notmuch new) is the primary barrier marker; else
          --   2. the email-census freshness line must read [ok] for BOTH
          --      accounts (fallback authoritative check, reusing the wrapper's
          --      freshness-line contract).
          -- If neither holds, the open is REFUSED with remediation guidance --
          -- never a fail-open launch onto a possibly-stale index.
          sync_all_mail(function(ok)
            if ok then
              open_aerc()
              return
            end
            vim.notify(
              "Sync/reindex did not complete cleanly -- checking index freshness via email-census...",
              vim.log.levels.WARN
            )
            if census_freshness_ok("gmail") and census_freshness_ok("logos") then
              vim.notify("Index freshness [ok] on both accounts -- opening aerc", vim.log.levels.INFO)
              open_aerc()
            else
              vim.notify(
                "aerc launch blocked: sync failed and index freshness is not [ok].\n"
                  .. "Remediate: fix the sync (<leader>mN or mbsync <group>), run email-reindex "
                  .. "if only the index lags, then retry <leader>me.",
                vim.log.levels.ERROR
              )
            end
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
