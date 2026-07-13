# Implementation Plan: Task #851 - Himalaya/aerc Mail Sync + Keymap Verification

- **Task**: 851 - Himalaya/aerc mail sync + keymap fixes (multi-account sync, account fallback, mS/mf conflict)
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours (agent-automatable) + ~15 min human live-server verification
- **Dependencies**: None
- **Research Inputs**: specs/851_himalaya_mail_sync_and_keymap_fixes/reports/01_himalaya-mail-sync-keymaps.md
- **Artifacts**: plans/01_mail-sync-keymap-verification.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

All six code changes for this task (account fallback, `sync_all_accounts_inbox` /
`HimalayaSyncAllInbox`, the `get_all_accounts` nil-crash fix, notification-category
adjustments, aerc-open background sync, and the `<leader>mS`/`<leader>mf` keymap-conflict
resolution) are **already implemented and committed** on `master` in commits `bcb662549` and
`a1c64151b`. This is therefore a **verification task, not an implementation task**. The
definition of done is: (a) confirm the committed code still matches the report's per-file claims
and remains loadable/keymap-clean via automated headless checks, and (b) obtain the one
outstanding confirmation the research flagged as unverifiable by any headless agent -- a live
end-to-end sync against real Gmail and Proton Bridge servers, which requires a human at an
interactive nvim with real credentials.

### Research Integration

The plan is built directly on report `01_himalaya-mail-sync-keymaps.md`:
- The "Changes Implemented (committed)" section supplies the exact per-file claims to
  statically re-verify (Phase 1).
- The "Post-fix keymap ownership" table supplies the six-key registration matrix to assert
  headlessly (Phase 2).
- The "Verification gaps / limitations" and "Remaining Work" sections establish that live
  IMAP/Bridge sync was NOT exercised (stub replaced `mbsync`) and is the sole remaining item,
  scoped here as a human-only manual step (Phase 3).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap flag set. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Confirm the committed code on `master` matches every per-file change claimed in the report.
- Confirm all five modified modules still parse/load and the six mail keymaps each resolve to
  exactly one action with no collision, using `nvim --headless`.
- Confirm `:HimalayaSyncAllInbox` and `:HimalayaSyncFull` commands register.
- Clearly hand the one truly-manual step (live send/receive against Gmail + Proton Bridge) to
  the human user, with an exact reproduction procedure and pass criteria.

**Non-Goals**:
- Re-implementing or modifying any of the already-committed code (the code is correct; do not
  invent rework).
- Exercising live IMAP/Bridge servers from an agent -- this requires live network, real Gmail
  app-password + Proton Bridge on 127.0.0.1:1143, and interactive observation, none of which a
  headless agent can perform.
- The report's "Optional hardening" items (auditing other `state.get_current_account()` entry
  points; re-exporting `get_all_accounts` from `core/config`). These are explicitly optional and
  out of scope for verification; capture as follow-ups only if a defect surfaces.
- Any `.dotfiles`/nix changes (the Gmail Trash/Spam exclusion is a known, accepted nix-config
  limitation per the report).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Static checks pass but live sync fails against real servers | H | M | Phase 3 manual step is the explicit gate; if it fails, task goes [BLOCKED] with the failing account/error captured, not marked complete |
| Headless mode cannot fire `UIEnter`/`VeryLazy`, so which-key/himalaya maps are not registered | M | H | Force-load the plugins in the headless probe exactly as the report did; assert against the force-loaded state |
| Agent over-reaches and "fixes" already-correct committed code | M | M | Non-Goals forbid code changes; Phase 1/2 are read-only assertions; any discrepancy is reported, not silently patched |
| Live verification blocked indefinitely on human availability | M | M | Split status: agent-automatable phases can reach [COMPLETED]; Phase 3 recorded as a human-action blocker so the task can be honestly marked partial/blocked rather than falsely complete |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Static verification of committed code vs report claims [COMPLETED]

**Goal**: Confirm the code on `master` matches every per-file change the report claims, with no
uncommitted drift.

**Tasks**:
- [x] Confirm commits `bcb662549` and `a1c64151b` are present on `master` and `git status` shows
  the five target files clean (no uncommitted changes to `ui/main.lua`, `commands/sync.lua`,
  `sync/manager.lua`, `mail.lua`, `which-key.lua`). *(verified: both commits present via git log;
  `git status --short` on all five files returned no output = clean)*
- [x] In `ui/main.lua`: confirm `sync_inbox()`/`sync_all()` fall back to
  `config.get_current_account_name()` when the UI account is unset, and that
  `sync_all_accounts_inbox()` exists, enumerates accounts via the `config.accounts` submodule
  (not `config.get_all_accounts()`), and chains per-account syncs via `_perform_sync`'s
  completion callback. *(verified: main.lua:688 `sync_inbox`, main.lua:756 `sync_all` both use
  `state.get_current_account() or config.get_current_account_name()`; main.lua:708-751
  `sync_all_accounts_inbox` requires `config.accounts` submodule directly at line 710 and chains
  via `M._perform_sync(channel, account .. ' inbox', function() sync_next() end)` at line 745)*
- [x] In `commands/sync.lua`: confirm `HimalayaSyncAllInbox` -> `main.sync_all_accounts_inbox()`
  is registered and `HimalayaSyncInbox` (single account) is retained. *(verified: sync.lua:31-39
  registers `HimalayaSyncAllInbox` -> `main.sync_all_accounts_inbox()`; sync.lua:21-29 retains
  `HimalayaSyncInbox` -> `main.sync_inbox()`)*
- [x] In `sync/manager.lua`: confirm the "missing account/folder" notice is category BACKGROUND
  (not ERROR) and still `logger.warn`'d. *(verified: manager.lua:282-283 —
  `logger.warn('Cannot update folder count: missing account or folder')` followed by
  `notify.himalaya('Cannot update count: missing account/folder', notify.categories.BACKGROUND)`)*
- [x] In `mail.lua`: confirm the shared `sync_all_mail()` helper (`mbsync -a` + `notmuch new`),
  `<leader>me` firing it in the background while opening aerc, and the relocations
  `<leader>mf`->`<leader>mn` (notmuch search) and `<leader>mS`->`<leader>mN` (notmuch full sync).
  *(verified: mail.lua:30-51 `sync_all_mail` jobstarts `mbsync -a` then `notmuch new`;
  mail.lua:58-87 `<leader>me` calls `sync_all_mail()` then opens the aerc terminal;
  mail.lua:88-95 binds `<leader>mN` to `sync_all_mail()`; mail.lua:103-156 binds `<leader>mn` to
  notmuch search; mail.lua contains no `<leader>mf` or `<leader>mS` binding at all — relocation
  confirmed by absence)*
- [x] In `which-key.lua`: confirm `<leader>ms` -> `HimalayaSyncAllInbox`, the `<leader>mS` start
  notice is `USER_ACTION`, and `me`/`mn`/`mN` are annotation-only (`desc`, no `rhs`). *(verified:
  which-key.lua:637 `<leader>ms` -> `<cmd>HimalayaSyncAllInbox<CR>`; which-key.lua:638 `<leader>mS`
  -> `<cmd>HimalayaSyncFull<CR>` which calls `main.sync_all()` -> `M._perform_sync`, whose start
  notice at main.lua:552 is `notify.categories.USER_ACTION`; which-key.lua:629,635,636 `me`/`mn`/
  `mN` entries have only `desc`/`icon` fields, no command/rhs)*
- [x] Record any discrepancy between code and report as a finding (do NOT modify code).
  *(no discrepancies found; zero code modifications made during this phase)*

**Timing**: 45 min

**Depends on**: none

**Files to inspect** (read-only):
- `lua/neotex/plugins/tools/himalaya/ui/main.lua`
- `lua/neotex/plugins/tools/himalaya/commands/sync.lua`
- `lua/neotex/plugins/tools/himalaya/sync/manager.lua`
- `lua/neotex/plugins/tools/mail.lua`
- `lua/neotex/plugins/editor/which-key.lua`

**Verification**:
- All six report claims map to code found on `master`; `git status` clean for the five files;
  zero code modifications made.

---

### Phase 2: Headless load + keymap registration checks [COMPLETED]

**Goal**: Prove the modules load and the six mail keymaps resolve to exactly one action each with
no collision, using automated `nvim --headless` probes.

**Tasks**:
- [x] Run `loadfile`/parse checks on all five modified files headlessly; assert PASS for each.
  *(all five: `nvim --headless -c "lua local ok,err = loadfile(...); print(ok and 'PASS' or 'FAIL')"` -> PASS x5)*
- [x] Force-load the himalaya and mail/notmuch plugins headlessly (headless cannot fire
  `UIEnter`/`VeryLazy`, so force-load as the report did), then dump the `<leader>m*` keymaps.
  *(fired `vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })` under `-u init.lua`;
  confirmed via `lazy.core.config` that `himalaya-email`, `which-key.nvim`, and `toggleterm.nvim`
  all transition to `loaded=true`; dumped `nvim_get_keymap("n")` filtered to lhs starting with
  `mapleader .. "m"` (mapleader=" ", so literal `" m*"`))*
- [x] Assert the six-key ownership matrix from the report resolves with no double-binding:
  `me` (aerc + background `mbsync -a && notmuch new`, mail.lua), `mn` (notmuch search, mail.lua),
  `mN` (`mbsync -a && notmuch new`, mail.lua), `mf` (HimalayaFolder, which-key), `ms`
  (HimalayaSyncAllInbox, which-key), `mS` (HimalayaSyncFull, which-key) -- each key -> exactly one
  target with correct rhs/desc. *(headless dump confirmed exactly one keymap per key, all six
  matching the report's matrix exactly: `me`->desc "Open aerc email client" callback=true;
  `mn`->desc "Search mail with notmuch" callback=true; `mN`->desc "Sync all accounts (mbsync -a +
  notmuch)" callback=true; `mf`->rhs `<Cmd>HimalayaFolder<CR>`; `ms`->rhs
  `<Cmd>HimalayaSyncAllInbox<CR>`; `mS`->rhs `<Cmd>HimalayaSyncFull<CR>`. 17 total `<leader>m*`
  keymaps dumped, all with distinct lhs -- no duplicates/collisions anywhere in the group)*
- [x] Assert `:HimalayaSyncAllInbox` and `:HimalayaSyncFull` are registered commands. *(confirmed
  via `vim.api.nvim_get_commands({})` after VeryLazy fire: both `true`, plus `HimalayaSyncInbox`
  also `true`)*
- [x] Optionally (safe/offline): call `sync_all_accounts_inbox()` with `_perform_sync` stubbed and
  confirm it enumerates `gmail,logos` and resolves `gmail-inbox` then `logos-inbox` in order with
  no error (reproduces the report's stubbed end-to-end check). *(executed: stubbed
  `main._perform_sync` to record calls and invoke its completion callback instead of running real
  mbsync; `pcall(main.sync_all_accounts_inbox)` returned `ok=true`; recorded order = "gmail inbox
  (gmail-inbox) -> logos inbox (logos-inbox)" -- matches report exactly, no error)*

**Timing**: 30 min

**Depends on**: none

**Files to inspect** (read-only; execution via `nvim --headless`):
- Same five files as Phase 1, plus plugin bootstrap under `lua/neotex/`.

**Verification**:
- All five parse checks PASS; six keymaps resolve one-to-one with no collision regardless of load
  order; both commands register; optional stubbed enumeration yields `gmail-inbox` then
  `logos-inbox` with no error.

---

### Phase 3: Live end-to-end sync verification (HUMAN-ONLY manual step) [NOT STARTED]

**Goal**: Confirm both accounts actually reconcile against live Gmail and Proton Bridge servers
and that aerc opens with a completing background sync -- the one item no headless agent can
perform.

**MANUAL / BLOCKER**: This phase CANNOT be completed by an implementation agent. It requires
live network access, real Gmail app-password + Proton Bridge listening on 127.0.0.1:1143, and
interactive observation inside a real nvim session. An agent reaching this phase MUST record it
as a human-action blocker (status `blocked`, or `partial` if Phases 1-2 completed) rather than
attempting it or marking it done.

**Tasks (for the human user to run in a real interactive nvim)**:
- [ ] Open the Himalaya sidebar, press `<leader>ms`, and confirm both `gmail-inbox` and
  `logos-inbox` reconcile sequentially against the live servers with a visible "Starting
  sync"/"All accounts synced" notification and **no error notification**.
- [ ] Press `<leader>me`; confirm aerc opens AND the background `mbsync -a && notmuch new`
  completes (check for the completion notification and refreshed mail).
- [ ] Open the `<leader>m` menu and visually confirm `me`, `mn`, `mN`, `ms`, `mS`, `mf` each show
  a distinct description with no collision.
- [ ] Report result back: PASS -> task can be marked complete; FAIL -> capture the failing account
  and exact error text so the task is set [BLOCKED] with that context (do not mark complete).

**Timing**: ~15 min human time (not agent time)

**Depends on**: 1, 2

**Verification**:
- Acceptance criteria from the report satisfied against live servers: `<leader>ms` syncs both
  inboxes error-free; `<leader>me` opens aerc and refreshes all accounts in background; the
  `<leader>m` menu shows all six keys with distinct descriptions and no collision.

## Testing & Validation

- [x] Phase 1: five files clean on `master`; all six report claims located in committed code; no
  code modified.
- [x] Phase 2: `loadfile` PASS on all five files; six `<leader>m*` keymaps resolve one-to-one;
  `:HimalayaSyncAllInbox` and `:HimalayaSyncFull` register; stubbed enumeration yields
  `gmail-inbox` then `logos-inbox`.
- [ ] Phase 3 (human): live `<leader>ms` two-account sync error-free; `<leader>me` opens aerc with
  completing background sync; menu shows six distinct, collision-free entries. *(BLOCKED on human
  action -- requires live Gmail + Proton Bridge servers and interactive nvim; not attempted by
  this agent per plan Non-Goals)*

## Artifacts & Outputs

- plans/01_mail-sync-keymap-verification.md (this file)
- summaries/01_mail-sync-keymap-verification-summary.md (on implementation)
- specs/851_himalaya_mail_sync_and_keymap_fixes/.orchestrator-handoff.json (handoff for the
  next dispatch)

## Rollback/Contingency

- No code changes are planned, so there is nothing to roll back for Phases 1-2. If a Phase 1/2
  discrepancy reveals a real defect in the committed code, capture it as a new finding/follow-up
  task rather than editing under this verification plan.
- If Phase 3 fails against live servers, set the task [BLOCKED] with the failing account and the
  verbatim error text; the committed code stays as-is pending a targeted follow-up fix task. The
  two commits (`bcb662549`, `a1c64151b`) remain the baseline either way.
