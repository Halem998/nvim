# Implementation Summary: Task #851

**Completed**: 2026-07-11 (Phases 1-2 of 3; Phase 3 remains a human-action blocker)
**Duration**: ~30 minutes

## Overview

This was a verification task, not an implementation task: all six code fixes for himalaya/aerc
mail sync and the `<leader>mS`/`<leader>mf` keymap conflict were already implemented and
committed on `master` (commits `bcb662549`, `a1c64151b`) prior to this dispatch. This dispatch
statically re-verified every per-file claim in report `01_himalaya-mail-sync-keymaps.md` against
the committed code (Phase 1) and ran headless `nvim` probes to confirm module loading, keymap
ownership, and command registration (Phase 2). No code was modified.

## What Changed

No source files were modified. Verification-only artifacts were produced:
- `specs/851_himalaya_mail_sync_and_keymap_fixes/plans/01_mail-sync-keymap-verification.md` --
  annotated with per-task verification evidence; Phases 1-2 marked `[COMPLETED]`.
- `specs/851_himalaya_mail_sync_and_keymap_fixes/handoffs/phase-2-handoff-20260711T215308Z.md`
- `specs/851_himalaya_mail_sync_and_keymap_fixes/.orchestrator-handoff.json`

## Decisions

- Reproduced the report's headless force-load technique by firing
  `vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })` under `nvim --headless -u
  init.lua`, since headless mode never fires `UIEnter`/real `VeryLazy` on its own. Confirmed via
  `lazy.core.config` that `himalaya-email`, `which-key.nvim`, and `toggleterm.nvim` all loaded.
- Matched `<leader>m*` keymaps by literal `mapleader .. "m"` (space + m) rather than the string
  `"<leader>m"`, since Neovim substitutes `<leader>` into the actual mapleader character at
  registration time.

## Plan Deviations

- None (implementation followed plan). Phase 3 was correctly NOT attempted, per the plan's
  explicit HUMAN-ONLY designation, and is recorded as a blocker rather than falsely marked done.

## Verification

**Phase 1 (static code-vs-report verification)** -- all PASS, zero discrepancies:
- `git status --short` on the five target files (`ui/main.lua`, `commands/sync.lua`,
  `sync/manager.lua`, `mail.lua`, `which-key.lua`) returned no output (clean).
- `ui/main.lua`: `sync_inbox()` (line 688) and `sync_all()` (line 756) both fall back to
  `config.get_current_account_name()`; `sync_all_accounts_inbox()` (lines 708-751) enumerates via
  `require('...config.accounts')` directly (not `config.get_all_accounts()`) and chains via
  `_perform_sync`'s completion callback.
- `commands/sync.lua`: `HimalayaSyncAllInbox` -> `main.sync_all_accounts_inbox()` (lines 31-39);
  `HimalayaSyncInbox` retained (lines 21-29).
- `sync/manager.lua`: line 283 "Cannot update count: missing account/folder" is
  `notify.categories.BACKGROUND`, preceded by `logger.warn` at line 282.
- `mail.lua`: `sync_all_mail()` helper (lines 30-51, `mbsync -a` + `notmuch new`); `<leader>me`
  (lines 58-87) fires it in the background before opening aerc; `<leader>mn` (notmuch search) and
  `<leader>mN` (`mbsync -a && notmuch new`) present; no `<leader>mf`/`<leader>mS` in this file
  (relocation confirmed by absence).
- `which-key.lua`: `<leader>ms` -> `HimalayaSyncAllInbox` (line 637); `<leader>mS` -> full sync,
  whose start notice (`main.lua:552`) is `USER_ACTION`; `me`/`mn`/`mN` entries (lines 629, 635,
  636) are annotation-only (`desc`/`icon`, no `rhs`).

**Phase 2 (headless load + keymap registration)** -- all PASS:
- `loadfile()` PASS on all five modified files.
- Headless keymap dump (post-VeryLazy force-load) found exactly one binding per key across the
  full six-key matrix, matching the report precisely: `me`, `mn`, `mN` owned by `mail.lua`
  (callback-based); `mf`, `ms`, `mS` owned by `which-key.lua` (`<Cmd>...<CR>` rhs). 17 total
  `<leader>m*` keymaps dumped, all with distinct `lhs` -- no collisions anywhere in the group.
- `:HimalayaSyncAllInbox`, `:HimalayaSyncFull`, `:HimalayaSyncInbox` all confirmed registered.
- Stubbed end-to-end call: `main.sync_all_accounts_inbox()` with `_perform_sync` replaced by a
  recording stub returned `pcall` ok=true and produced order `gmail inbox (gmail-inbox) -> logos
  inbox (logos-inbox)` -- matches the report's stubbed verification exactly.
- Neovim startup: `nvim --headless -u init.lua -c "lua print('STARTUP_OK')"` succeeds cleanly.

## Notes

**Phase 3 is a live human-action blocker, not a failure.** It requires a human at an interactive
`nvim` session with real Gmail app-password credentials and Proton Bridge listening on
`127.0.0.1:1143` -- none of which a headless agent can provide. The reproduction steps and pass
criteria are documented verbatim in the plan's Phase 3 section and mirrored in
`.orchestrator-handoff.json`. Until a human runs and reports that step, this task should remain
`[PARTIAL]` rather than `[COMPLETED]`.
