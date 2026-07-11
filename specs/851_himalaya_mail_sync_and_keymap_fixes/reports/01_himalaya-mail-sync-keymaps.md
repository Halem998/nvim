# Research Report: Task #851 - Himalaya/aerc Mail Sync + Keymap Fixes

**Task**: 851 - himalaya_mail_sync_and_keymap_fixes
**Started**: 2026-07-11
**Completed**: 2026-07-11T14:03:46Z
**Effort**: ~1 interactive debugging session (changes already implemented and committed)
**Task Type**: neovim (himalaya plugin + which-key + aerc integration, Lua)
**Dependencies**: None
**Related**: `.dotfiles` task 105 (`aerc_keybindings_nvim_himalaya_alignment`) covered the
nix/aerc side; this task is the nvim side (himalaya plugin + which-key + mail.lua).

**Sources/Inputs**:
- `lua/neotex/plugins/tools/himalaya/ui/main.lua` (sync_inbox / sync_all / new sync_all_accounts_inbox)
- `lua/neotex/plugins/tools/himalaya/sync/manager.lua` (update_folder_counts)
- `lua/neotex/plugins/tools/himalaya/commands/sync.lua` (command registry)
- `lua/neotex/plugins/tools/himalaya/config/accounts.lua` / `config/init.lua` (account API)
- `lua/neotex/plugins/tools/mail.lua` (aerc + notmuch, lazy `keys`)
- `lua/neotex/plugins/editor/which-key.lua` (`<leader>m` mail group)
- `~/.mbsyncrc` (home-manager generated from `.dotfiles/modules/home/email/mbsync.nix`)

**Artifacts**: this report

**Standards**: report-format.md; repo CLAUDE.md documentation policy (no emojis, ASCII markers)

---

## Executive Summary

A sequence of user-reported mail issues were root-caused and fixed. All code changes are
**already implemented, runtime-verified, and committed** on `master` in two commits:

- `bcb662549` - mail: sync all accounts, fix account fallback, resolve keymap conflicts
- `a1c64151b` - mail: fix sync_all_accounts_inbox nil get_all_accounts crash

This report exists as a durable record and to scope the one **remaining** item: live
end-to-end verification that both accounts actually reconcile against their servers
(headless tests could not exercise live IMAP/Bridge). See "Remaining Work".

---

## Issues Reported (chronological)

1. `<leader>ms` -> `No email account configured` even though accounts exist.
2. After fixing (1): `<leader>ms` printed `Cannot update count: missing account/folder`
   as an ERROR, and there was no visible "sync is running" notification.
3. `<leader>ms` should sync ALL accounts (gmail + logos), not just the current one.
4. `<leader>me` (opens aerc) did not sync any accounts; only himalaya synced (on `<leader>mm`).
5. Latent keymap collision: `mail.lua` and `which-key.lua` both bound `<leader>mS` and
   `<leader>mf` to different actions.
6. Regression during (3): `<leader>ms` crashed with
   `attempt to call field 'get_all_accounts' (a nil value)`.

## Root Causes

- **(1)** `main.sync_inbox()`/`sync_all()` read the UI-runtime account
  `state.get_current_account()` (`ui.current_account`), which is `nil` until the Himalaya
  sidebar is opened. Pressing `<leader>ms` in a fresh session hit the nil branch.
- **(2)** `manager.update_folder_counts()` runs after every sync to refresh the count of the
  *currently displayed* folder. With the sidebar closed there is no current folder, so it
  hit an `else` branch mislabeled as `notify.categories.ERROR`. The "start" notice used
  `STATUS` (debug-only), so it never displayed.
- **(3/4)** No multi-account sync path existed; himalaya sync was single-account, and aerc
  (`mail.lua`) opened without any sync trigger.
- **(5)** The `<leader>m` prefix is shared by two independent systems (himalaya via
  `which-key.lua`; aerc/notmuch via `mail.lua` lazy `keys`). `mS`/`mf` were double-claimed;
  load order decided the winner.
- **(6)** `get_all_accounts` is defined only on the `config.accounts` submodule and is NOT
  re-exported by `core/config` (`config/init.lua`), so `config.get_all_accounts()` was nil.

## Changes Implemented (committed)

`ui/main.lua`
- `sync_inbox()` / `sync_all()`: fall back to `config.get_current_account_name()` when the UI
  account is unset (fixes issue 1).
- New `sync_all_accounts_inbox()`: enumerates accounts via the `config.accounts` submodule,
  syncs each account's `mbsync.inbox_channel` sequentially (the sync manager tracks only one
  sync at a time; chained via `_perform_sync`'s completion callback), reports "All accounts
  synced" (fixes 3; fixes 6 by requiring the submodule directly).

`commands/sync.lua`
- New `HimalayaSyncAllInbox` command -> `main.sync_all_accounts_inbox()`. Existing
  `HimalayaSyncInbox` (single account) retained.

`sync/manager.lua`
- `update_folder_counts()` "missing account/folder" notice downgraded ERROR -> BACKGROUND
  (still `logger.warn`'d) (fixes 2a).

`mail.lua`
- Shared `sync_all_mail()` helper (`mbsync -a` + `notmuch new`, with notifications).
- `<leader>me` now fires `sync_all_mail()` in the background and opens aerc (fixes 4).
- Relocated notmuch search `<leader>mf` -> `<leader>mn`, full notmuch sync `<leader>mS` ->
  `<leader>mN` (fixes 5, aerc/notmuch side).

`which-key.lua`
- `<leader>ms` repointed to `HimalayaSyncAllInbox` ("sync all inboxes"); `<leader>mS` "start"
  notice now `USER_ACTION` (visible) (fixes 2b via main.lua's `_perform_sync`).
- Added annotation-only entries (`desc`, no `rhs`) for `me`/`mn`/`mN` so they show in the
  mail menu without overriding the real `mail.lua` mappings.

## Post-fix keymap ownership (each key -> exactly one action)

| Key | Action | Owner |
|-----|--------|-------|
| `<leader>me` | open aerc + background `mbsync -a && notmuch new` | mail.lua |
| `<leader>mn` | notmuch telescope search | mail.lua |
| `<leader>mN` | `mbsync -a && notmuch new` | mail.lua |
| `<leader>mf` | HimalayaFolder (change folder) | which-key/himalaya |
| `<leader>ms` | HimalayaSyncAllInbox (sync all inboxes) | which-key/himalaya |
| `<leader>mS` | HimalayaSyncFull (full sync, current account) | which-key/himalaya |

## Verification Performed

- Parse checks (`loadfile`) on all five files: PASS.
- Runtime keymap dump (headless, plugins force-loaded): all six keys resolve to exactly one
  target with correct rhs/desc; `:HimalayaSyncAllInbox` / `:HimalayaSyncFull` register.
- End-to-end call of `sync_all_accounts_inbox()` with `_perform_sync` stubbed:
  enumerates `gmail,logos`; resolves `gmail-inbox` then `logos-inbox` in order; no error.

### Verification gaps / limitations

- Headless mode cannot fire `UIEnter`/`VeryLazy`, so which-key/himalaya had to be
  force-loaded to inspect their maps (done).
- **Live IMAP/Bridge sync was NOT exercised** - the stub replaced real `mbsync`. Whether both
  accounts actually reconcile against Gmail and Proton/Bridge servers is unconfirmed.

## Context: mbsync channel validity

`~/.mbsyncrc` (home-manager, source `.dotfiles/modules/home/email/mbsync.nix`) defines
`Group gmail` and `Group logos` with `gmail-inbox` / `logos-inbox` channels, so both the
himalaya per-account path and `mbsync -a` are valid. `mbsync -a` is already the documented
trigger for aerc's `$` keybind and notmuch's preNew hook, so `<leader>me`/`<leader>mN` match
existing behavior. Known limitation baked into the nix config: Gmail Trash/Spam are excluded
from `Group gmail` (server returns `[NONEXISTENT]` unless "Show in IMAP" is enabled), so local
deletes do not propagate to Gmail's server-side trash. No `.dotfiles` change is warranted.

## Remaining Work

1. **Live end-to-end sync verification** (primary): run `<leader>ms` in a real nvim with the
   sidebar open and confirm both `gmail-inbox` and `logos-inbox` reconcile without error
   against the live servers (Gmail app-password + Proton Bridge on 127.0.0.1:1143). Confirm
   `<leader>me` opens aerc and the background `mbsync -a && notmuch new` completes.
2. **Optional hardening**: consider applying the same UI-account fallback to any other himalaya
   entry points that read `state.get_current_account()` before the sidebar opens (audit
   `sync_current_folder`, count paths).
3. **Optional**: consider re-exporting `get_all_accounts` from `core/config` for API
   consistency (currently only `config.accounts.get_all_accounts()` works).

## Acceptance Criteria

- `<leader>ms` syncs both accounts' inboxes against live servers with no error notification.
- `<leader>me` opens aerc and refreshes all accounts (mbsync -a + notmuch new) in background.
- `<leader>m` menu shows `me`, `mn`, `mN`, `ms`, `mS`, `mf` each with a distinct description
  and no collision, regardless of plugin load order.
